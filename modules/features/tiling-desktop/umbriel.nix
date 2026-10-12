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
    packages.myumbriel = local.flake.wrappers.umbriel.wrap {
      inherit pkgs;
      configDir = "\${XDG_CONFIG_HOME}/syncumbriel";
      snapshot.enable = true;
      settings = lib.recursiveUpdate (builtins.fromTOML (builtins.readFile ./umbriel/config.toml)) {
        general.autostart = [noctalia];
        include.optional.files = ["$XDG_CONFIG_HOME/umbriel/noctalia.toml"];
        keybinds = {
          "Mod+G" = "spawn:${lib.getExe self'.packages.myghostty}";
          "Mod+B" = "spawn:${lib.getExe self'.packages.mybrave}";
          "Mod+S" = "spawn:${noctalia} msg panel-toggle launcher";
        };
        environment = {
          GTK_DATA_PREFIX = "${pkgs.adw-gtk3}";
          QT_QPA_PLATFORMTHEME = "qtengine";
          QT_PLUGIN_PATH = "${pkgs.qtengine}/${pkgs.kdePackages.qtbase.qtPluginPrefix}";
          QTENGINE_CONFIG = toString qtengineConfig;
        };
      };
      passthru.generatedQtengineConfig = qtengineConfig;
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
        # Session startup remains owned by the existing Noctalia service.
        settings.general.autostart = lib.mkForce [];
      };
    };
    # The upstream session unit embeds its original package path.
    systemd.user.services.umbriel.serviceConfig.ExecStart = [
      ""
      (lib.getExe config.programs.umbriel.package)
    ];
    services.displayManager.defaultSession = lib.mkForce "umbriel";
  };
}
