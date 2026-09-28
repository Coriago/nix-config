{
  flake.modules.nixos.desktop = {pkgs, ...}: {
    services.printing = {
      enable = true;
      drivers = [pkgs.hplip];
    };
    environment.systemPackages = [pkgs.kdePackages.print-manager];
  };
}
