{
  flake.modules.nixos.go = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
    ];
  };

  flake.modules.nixos.rust = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
    ];
  };

  flake.modules.nixos.python = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
    ];
  };
}
