{
  self,
  config,
  ...
}: let
  local = config;
in {
  perSystem = {pkgs, ...}: {
    packages.mynoctalia = local.flake.wrappers.noctalia.wrap {
      inherit pkgs;
      configHome = "\${XDG_CONFIG_HOME}/syncnoctalia";
      stateHome = "\${XDG_STATE_HOME}/syncnoctalia";
      snapshot.enable = true;
      # Keep machine-specific plugin integration out of the portable baseline.
      snapshot.files.noctaliaConfig.pruneKeyContains = ["^plugin_settings\\..*\\.nixos_configuration$"];
      settings = {
        shell.launch_apps_as_systemd_services = true;
        plugin_settings."mindnbytes/nix-status".nixos_configuration = "heliosdesk";
        wallpaper.default.path = pkgs.fetchurl {
          name = "NixOS_Black.png";
          url = "https://github.com/it-is-zane/wallpapers/blob/main/NixOS/NixOS_Black.png?raw=true";
          hash = "sha256-zO5ggrxgCocLSfAHd8xDa4PVkIN/DElNCN2MLi6qrP8=";
        };
      };
      # Dependencies of the chosen GTK/Umbriel template integrations.
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
    };
  };

  flake.modules.nixos.noctalia = {pkgs, ...}: {
    programs.noctalia = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.mynoctalia;
      systemd.enable = true;
      systemd.target = "umbriel-session.target";
    };
    programs.dconf.enable = true;
  };
}
