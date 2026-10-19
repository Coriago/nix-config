{
  flake.modules.nixos.keyboard = {
    hostmeta,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      vial
    ];
    hardware.keyboard.qmk.enable = true;
    services.udev.packages = [pkgs.vial];
    services.udev.extraRules = ''
      # Vial's packaged MODE=0600 can mask the logged-in user's ACL on a later udev event.
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="55d4", ATTRS{idProduct}=="0461", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="plugdev", TAG+="uaccess"
    '';
    users.users.${hostmeta.username}.extraGroups = ["plugdev"];
  };
}
