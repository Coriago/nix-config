{self, ...}: {
  flake.modules.nixos.sync-snap = {pkgs, ...}: {
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.sync-snap];
    environment.pathsToLink = ["/share/sync-snap"];
  };
}
