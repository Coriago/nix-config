{
  flake.modules.nixos.power-usage = {pkgs, ...}: {
    environment.systemPackages = [pkgs.powertop];
  };
}
