{
  flake.modules.nixos.desktop = {pkgs, ...}: {
    programs.kdeconnect.enable = true;
    services.printing = {
      enable = true;
      drivers = [pkgs.hplip];
    };
    environment.systemPackages = [pkgs.kdePackages.print-manager];
  };
}
