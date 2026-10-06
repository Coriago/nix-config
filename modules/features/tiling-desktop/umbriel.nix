{self, config, ...}: let
  local = config;
in {
  flake.wrappers.myumbriel = {
    config,
    pkgs,
    lib,
    wlib,
    ...
  }: let
    noctalia = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.mynoctalia;
    toml = pkgs.formats.toml {};
    settings = toml.generate "umbriel-config.toml" config.settings;
    json = pkgs.formats.json {};
    qtengineConfig = json.generate "qtengine-config.json" config.qtengineSettings;
    defaults = {
      general.autostart = [noctalia];
      # Umbriel also publishes these to the managed session's user services.
      environment = {
        QT_QPA_PLATFORMTHEME = "qtengine";
        QT_PLUGIN_PATH = "${pkgs.qtengine}/${pkgs.kdePackages.qtbase.qtPluginPrefix}";
        QTENGINE_CONFIG = toString qtengineConfig;
      };
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
      qtengineSettings = lib.mkOption {
        type = json.type;
        default = {
          theme = {
            colorScheme = "~/.local/share/color-schemes/noctalia.colors";
            style = "Fusion";
          };
        };
        description = "Bundled Qt6 platform-theme configuration. Override theme.colorScheme when using a custom XDG_DATA_HOME; qtengine expands ~ but not environment variables.";
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
        generatedQtengineConfig = qtengineConfig;
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
      package = local.flake.wrappers.myumbriel.wrap {
        inherit pkgs;
        # The NixOS user service owns Noctalia startup. The standalone package
        # retains compositor autostart for package testing.
        settings.general.autostart = lib.mkForce [];
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
