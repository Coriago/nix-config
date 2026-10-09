{inputs, ...}: {
  perSystem = {
    pkgs,
    self',
    ...
  }: {
    checks.mybrave-sync-snap = pkgs.callPackage ../tests/wrappers/brave {brave = self'.packages.mybrave;};
    checks.wrapper-sync-snap = pkgs.callPackage ../tests/wrappers/sync-snap {
      wlib = inputs.wrapper-modules.lib;
    };
  };
}
