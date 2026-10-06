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
    synced = builtins.fromTOML (builtins.readFile ./noctalia-v5/synced.toml);
    generated = toml.generate "config.toml" (lib.recursiveUpdate synced config.settings);
    configHome = pkgs.runCommand "noctalia-config" {} ''
      mkdir -p "$out/noctalia"
      ln -s ${generated} "$out/noctalia/config.toml"
    '';
    sync = pkgs.writeShellScript "noctalia-sync-preferences" ''
      exec ${python}/bin/python ${./noctalia-sync.py} \
        "''${XDG_STATE_HOME:-$HOME/.local/state}/mynoctalia/noctalia/settings.toml" \
        ${wlib.escapeShellArgWithEnv config.syncFile}
    '';
  in {
    imports = [wlib.modules.default];
    options = {
      settings = lib.mkOption {
        type = toml.type;
        default = {};
        description = "Settings deep-merged over synced.toml. Local GUI overrides still take precedence at runtime.";
      };
      syncFile = lib.mkOption {
        type = lib.types.str;
        default = "\${HOME}/.config/nix-config/modules/features/tiling-desktop/noctalia-v5/synced.toml";
        description = "Writable checkout destination for preference exports; HOME is expanded at runtime.";
      };
    };
    config = {
      package = lib.mkDefault pkgs.noctalia;
      env.NOCTALIA_CONFIG_HOME = configHome;
      env.NOCTALIA_STATE_HOME = {
        data = "\${XDG_STATE_HOME:-$HOME/.local/state}/mynoctalia";
        esc-fn = wlib.escapeShellArgWithEnv;
      };
      # Preserve exported templates while adding the Qt6/KDE color output.
      settings.theme.templates.builtin_ids = lib.mkDefault (
        lib.unique ((synced.theme.templates.builtin_ids or []) ++ ["kcolorscheme"])
      );
      settings.hooks =
        lib.genAttrs ["logging_out" "rebooting" "shutting_down" "colors_changed" ]
        (_: lib.mkBefore ["${sync}"]);
      constructFiles.syncPreferences = {
        relPath = "bin/noctalia-sync-preferences";
        content = ''
          #!${pkgs.bash}/bin/bash
          exec ${sync} "$@"
        '';
        builder = ''cp "$1" "$2" && chmod +x "$2"'';
      };

      settings.wallpaper.default = pkgs.fetchurl {
        url = "https://github.com/it-is-zane/wallpapers/blob/main/NixOS/NixOS_Black.png?raw=true";
        hash = "sha256-zO5ggrxgCocLSfAHd8xDa4PVkIN/DElNCN2MLi6qrP8=";
      };
    };
  };

  flake.modules.nixos.noctalia = {config, pkgs, ...}: {
    programs.dconf.enable = true;
    # Set the initial theme on activation, without locking Noctalia's mode sync.
    home-manager.users.${config.hostmeta.username}.dconf.settings = {
      "org/gnome/desktop/interface".gtk-theme = "adw-gtk3";
    };

    # https://docs.noctalia.dev/noctalia/templates/official/gtk-qt/
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.mynoctalia
      pkgs.adw-gtk3
    ];
  };
}
