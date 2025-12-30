{
  flake.modules.nixos.desktop = {...}: {
    services.xserver = {
      enable = true;
      xkb.layout = "us";
      xkb.variant = "";
    };

    services.psd = {
      enable = true;
    };
  };
}
