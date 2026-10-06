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
    defaults = (builtins.fromTOML (builtins.readFile ./umbriel/config.toml)) // {
      general.autostart = [noctalia];
      # Umbriel also publishes these to the managed session's user services.
      environment = {
        # Theme assets only: GSettings/Noctalia still select light/dark at runtime.
        GTK_DATA_PREFIX = "${pkgs.adw-gtk3}";
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
      configPath = lib.mkOption {
        type = lib.types.str;
        default = toString settings;
        description = "Configuration path used when starting Umbriel. NixOS supplies a stable managed file for live reload; standalone runs use the generated store file. Validation always checks the generated settings.";
      };
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
            ""|-*) set -- -c ${lib.escapeShellArg config.configPath} "$@" ;;
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
        configPath = "/etc/umbriel/config.toml";
        # The NixOS user service owns Noctalia startup. The standalone package
        # retains compositor autostart for package testing.
        settings.general.autostart = lib.mkForce [];
      };
    };
    environment.etc."umbriel/config.toml" = {
      source = config.programs.umbriel.package.generatedConfig;
      # A real file is atomically replaced during activation. Umbriel's native
      # watcher sees that replacement, without following /etc/static indirection.
      mode = "0644";
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
