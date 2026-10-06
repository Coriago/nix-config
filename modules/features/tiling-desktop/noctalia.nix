{self, ...}: {
  flake.wrappers.mynoctalia = {
    config,
    lib,
    pkgs,
    wlib,
    ...
  }: let
    toml = pkgs.formats.toml {};
    python = pkgs.python3.withPackages (p: [p.tomli-w]);
    snapshot = builtins.fromTOML (builtins.readFile ./noctalia/snapshot.toml);
    generated = toml.generate "config.toml" (lib.recursiveUpdate snapshot config.settings);
    configHome = pkgs.runCommand "noctalia-config" {} ''
      mkdir -p "$out/noctalia"
      ln -s ${generated} "$out/noctalia/config.toml"
    '';
    # Hooks inherit these roots from the running shell, avoiding a dependency
    # cycle between the generated config and its own snapshot hook.
    saveSnapshot = pkgs.writeShellScript "noctalia-snapshot-preferences" ''
      exec ${python}/bin/python ${./noctalia-snapshot.py} \
        "''${NOCTALIA_CONFIG_HOME:?}/noctalia/config.toml" \
        "''${NOCTALIA_STATE_HOME:?}/noctalia/settings.toml" \
        ${wlib.escapeShellArgWithEnv config.snapshotFile} "$@"
    '';
  in {
    imports = [wlib.modules.default];
    options = {
      settings = lib.mkOption {
        type = toml.type;
        default = {};
        description = "Settings deep-merged over snapshot.toml. Local GUI overrides still take precedence at runtime.";
      };
      snapshotFile = lib.mkOption {
        type = lib.types.str;
        default = "\${HOME}/.config/nix-config/modules/features/tiling-desktop/noctalia/snapshot.toml";
        description = "Writable checkout destination for config.toml merged with pruned GUI overrides, excluding Nix store paths; HOME is expanded at runtime.";
      };
    };
    config = {
      package = lib.mkDefault pkgs.noctalia;
      # The shipped GTK/Umbriel template hooks call these tools; package runs must not
      # depend on them being installed in the host profile.
      runtimePkgs = [pkgs.systemd pkgs.bash pkgs.coreutils pkgs.gawk pkgs.glib pkgs.dconf];
      suffixVar = [
        {
          name = "gtk-theme-data";
          data = ["XDG_DATA_DIRS" ":" "${pkgs.adw-gtk3}/share:${pkgs.glib.getSchemaDataDirPath pkgs.gsettings-desktop-schemas}"];
        }
        {
          name = "gtk-settings-backend";
          data = ["GIO_EXTRA_MODULES" ":" "${pkgs.dconf.lib}/lib/gio/modules"];
        }
      ];
      env.NOCTALIA_CONFIG_HOME = configHome;
      env.NOCTALIA_STATE_HOME = {
        data = "\${XDG_STATE_HOME:-$HOME/.local/state}/mynoctalia";
        esc-fn = wlib.escapeShellArgWithEnv;
      };
      # Keep launcher applications alive when the shell service restarts.
      settings.shell.launch_apps_as_systemd_services = lib.mkDefault true;
      settings.hooks =
        lib.genAttrs ["logging_out" "rebooting" "shutting_down" "colors_changed" "session_locked"]
        (_: lib.mkBefore ["${saveSnapshot}"]);
      constructFiles.snapshotPreferences = {
        relPath = "bin/noctalia-snapshot-preferences";
        content = ''
          #!${pkgs.bash}/bin/bash
          export NOCTALIA_CONFIG_HOME=${configHome}
          export NOCTALIA_STATE_HOME="''${XDG_STATE_HOME:-$HOME/.local/state}/mynoctalia"
          exec ${saveSnapshot} "$@"
        '';
        builder = ''cp "$1" "$2" && chmod +x "$2"'';
      };
      constructFiles.resetOverrides = {
        relPath = "bin/noctalia-reset-overrides";
        content = ''
          #!${pkgs.bash}/bin/bash
          exec ${python}/bin/python ${./noctalia-reset.py} \
            "''${XDG_STATE_HOME:-$HOME/.local/state}/mynoctalia/noctalia/settings.toml" \
            ${generated} "$@"
        '';
        builder = ''cp "$1" "$2" && chmod +x "$2"'';
      };

      settings.wallpaper.default.path = pkgs.fetchurl {
        # Greeter sync preserves the extension and rejects URL query characters.
        name = "NixOS_Black.png";
        url = "https://github.com/it-is-zane/wallpapers/blob/main/NixOS/NixOS_Black.png?raw=true";
        hash = "sha256-zO5ggrxgCocLSfAHd8xDa4PVkIN/DElNCN2MLi6qrP8=";
      };
    };
  };

  flake.modules.nixos.noctalia = {
    config,
    lib,
    pkgs,
    ...
  }: let
    package = self.packages.${pkgs.stdenv.hostPlatform.system}.mynoctalia;
  in {
    options.programs.noctalia.resetOverridesOnStart = lib.mkEnableOption "resetting GUI overrides to the packaged baseline before starting the Noctalia service";

    config = {
      programs.noctalia = {
        enable = true;
        inherit package;
        systemd.enable = true;
        systemd.target = "umbriel-session.target";
      };
      systemd.user.services.noctalia = {
        restartIfChanged = true;
        serviceConfig = {
          ExecStartPre = lib.mkIf config.programs.noctalia.resetOverridesOnStart "${package}/bin/noctalia-reset-overrides";
          # During migration, leave the old compositor-started shell running
          # until logout. Do not start a duplicate or reset its live settings.
          ExecCondition = pkgs.writeShellScript "noctalia-service-available" ''
            if ${lib.getExe package} msg status >/dev/null 2>&1; then
              echo "Noctalia is already running outside this service; log out and back in once to complete the service migration."
              exit 1
            fi
          '';
        };
      };
      programs.dconf.enable = true;
    };
  };
}
