{self, ...}: {
  flake.modules.nixos.base = {pkgs, ...}: {
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.sync-snap];
    environment.pathsToLink = ["/share/sync-snap"];
  };
}
