{
  flake.modules.nixos.development = {pkgs, ...}: {
    environment.systemPackages = [pkgs.go];
  };
}
