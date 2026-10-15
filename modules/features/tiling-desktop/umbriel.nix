{
  self,
  config,
  ...
}: let
  local = config;
in {
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    noctalia = lib.getExe self'.packages.mynoctalia;
    qtengineConfig = (pkgs.formats.json {}).generate "qtengine-config.json" {
      theme = {
        colorScheme = "~/.local/share/color-schemes/noctalia.colors";
        style = "Fusion";
      };
    };
  in {
    apps.myumbriel = {
      type = "app";
      program = lib.getExe self'.packages.myumbriel;
    };
    packages.myumbriel = local.flake.wrappers.umbriel.wrap ({config, ...}: {
      inherit pkgs;
      configDir = "\${XDG_CONFIG_HOME}/syncumbriel";
      snapshot.enable = true;
      settings = {
        general.autostart = [noctalia];
        include.optional.files = [
          "$XDG_CONFIG_HOME/umbriel/noctalia.toml" # automatic noctalia theming
          "$XDG_CONFIG_HOME/umbriel/outputs.toml" # display plugin
        ];
        include.files = [config.constructFiles.umbrielExtraConfig.path];
        keybinds = {
          "Mod+G" = "spawn:${lib.getExe self'.packages.myghostty}";
          "Mod+B" = "spawn:${lib.getExe self'.packages.mybrave}";
          "Mod+S" = "spawn:${noctalia} msg panel-toggle launcher";
        };
        environment = {
          # Enable Chromium's native accessibility bridge for caret reporting.
          ACCESSIBILITY_ENABLED = "1";
          GTK_DATA_PREFIX = "${pkgs.adw-gtk3}";
          QT_QPA_PLATFORMTHEME = "qtengine";
          QT_PLUGIN_PATH = "${pkgs.qtengine}/${pkgs.kdePackages.qtbase.qtPluginPrefix}";
          QTENGINE_CONFIG = toString qtengineConfig;
        };
      };
      passthru.generatedQtengineConfig = qtengineConfig;

      # Read the include directly so a NixOS liveConfig link stays live.
      constructFiles.umbrielExtraConfig = {
        relPath = "configExtras.toml";
        content = builtins.readFile ./umbriel/configExtras.toml;
      };
      sync.files.umbrielExtraConfig.enable = false;
      # Old merged preferences in the main file would override the include.
      sync.files.umbrielConfig.policy = "replace";
    });
  };

  flake.modules.nixos.umbriel = {
    config,
    lib,
    liveConfig,
    pkgs,
    ...
  }: {
    programs.umbriel = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.myumbriel.wrap {
        # Session startup remains owned by the existing Noctalia service.
        settings.general.autostart = lib.mkForce [];
        constructFiles.umbrielExtraConfig = lib.mkIf config.liveConfig.enable {
          content = lib.mkForce "";
          builder = ''ln -s ${lib.escapeShellArg (liveConfig.link ./umbriel/configExtras.toml)} "$2"'';
        };
      };
    };
    # allows for accessability acces in applications
    services.gnome.at-spi2-core.enable = true;

    # The upstream session unit embeds its original package path.
    systemd.user.services.umbriel.serviceConfig.ExecStart = [
      ""
      (lib.getExe config.programs.umbriel.package)
    ];
    services.displayManager.defaultSession = lib.mkForce "umbriel";
  };
}
