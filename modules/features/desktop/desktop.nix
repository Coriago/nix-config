{
  # NixOS
  flake.modules.nixos.desktop = {config, ...}: {
    # Uses KDE Plasma for Desktop
    services.xserver.enable = true;
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;

    # Enable x11 for backwards compatibility
    services.xserver = {
      xkb.layout = config.vars.keyLayout;
      xkb.variant = "";
    };
  };

  # Home Manager - Plasma Manager configuration
  # flake.modules.homeManager.desktop = {
  #   config,
  #   lib,
  #   ...
  # }: let
  #   # Generate kwinoutputconfig entries for each monitor by serial
  #   kwinOutputConfigs =
  #     lib.concatMapAttrs (
  #       name: mon:
  #         lib.optionalAttrs (mon.serial != "") {
  #           "kwinoutputconfig.${mon.serial}" = {
  #             mode = "${toString mon.width}x${toString mon.height}@${toString (builtins.floor (mon.refreshRate * 1000))}";
  #             scale = 1;
  #             transform = "normal";
  #             overscan = 0;
  #             vrrpolicy = 0;
  #             rgbrange = 0;
  #             sdrBrightness = 200;
  #             wideColorGamut = false;
  #             autoRotation = false;
  #             maxBrightness = 0;
  #             brightness = 1;
  #             colorprofilecreator = "";
  #             iccProfilePath = "";
  #             sdrGamutWideness = 0;
  #             colorDescription = "";
  #           };
  #         }
  #     )
  #     config.vars.monitors;
  # in {
  #   programs.plasma = {
  #     enable = true;

  #     # Write monitor configurations via configFile
  #     # kwinoutputconfig stores per-output settings by serial number
  #     configFile = lib.mkIf (config.vars.monitors != {}) kwinOutputConfigs;
  #   };
  # };
}
