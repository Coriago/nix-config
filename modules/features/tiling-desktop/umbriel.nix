{self, ...}: {
  flake.wrappers.myumbriel = {
    config,
    pkgs,
    lib,
    wlib,
    ...
  }: let
    noctalia = lib.getExe config.noctaliaPackage;
    toml = pkgs.formats.toml {};
    settings = toml.generate "umbriel-config.toml" config.settings;
    defaults = {
      general.autostart = [noctalia];
      keybinds = {
        "Mod+Return" = "spawn:${lib.getExe pkgs.ghostty}";
        "Mod+Q" = "window-close";
        "Mod+S" = "spawn:${noctalia} msg panel-toggle launcher";
        "Mod+Escape" = "session-quit";
        "Mod+H" = "window-focus-left";
        "Mod+L" = "window-focus-right";
        "Mod+Shift+H" = {
          action = "workspace-move-to-output-left";
          repeat = false;
        };
        "Mod+Shift+L" = {
          action = "workspace-move-to-output-right";
          repeat = false;
        };
        "Mod+K" = "window-focus-up";
        "Mod+J" = "window-focus-down";
        "Mod+F" = "window-toggle-fullscreen";
        "Mod+O" = "overview-toggle";
      };
    };
  in {
    imports = [wlib.modules.default];
    options = {
      noctaliaPackage = lib.mkOption {
        type = lib.types.package;
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.mynoctalia;
        description = "Noctalia wrapper used for autostart and IPC keybinds.";
      };
      settings = lib.mkOption {
        type = toml.type;
        default = {};
        description = "Umbriel configuration generated as TOML.";
      };
    };
    config = {
      package = lib.mkDefault pkgs.umbriel;
      settings = defaults;
      passthru = {
        providedSessions = pkgs.umbriel.providedSessions;
        generatedConfig = settings;
      };
      # Commands such as `msg`/`validate` require the subcommand first.
      runShell = [
        ''
          case "''${1-}" in
            ""|-*) set -- -c ${settings} "$@" ;;
            validate) shift; set -- validate -c ${settings} "$@" ;;
          esac
        ''
      ];
    };
  };

  flake.modules.nixos.umbriel = {
    config,
    lib,
    pkgs,
    ...
  }: {
    programs.umbriel = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.myumbriel.wrap {
        noctaliaPackage = config.wrappers.mynoctalia.wrapper;
      };
    };
    # The upstream unit embeds its original store path, bypassing the wrapper.
    # Reset ExecStart before replacing it in the generated systemd drop-in.
    systemd.user.services.umbriel.serviceConfig.ExecStart = [
      ""
      (lib.getExe config.programs.umbriel.package)
    ];
    services.displayManager.defaultSession = lib.mkForce "umbriel";
  };
}
