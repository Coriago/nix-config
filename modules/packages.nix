{
  perSystem = {
    pkgs,
    self',
    ...
  }: {
    packages.sync-snap = pkgs.callPackage ../packages/sync-snap {};
    checks.sync-snap = self'.packages.sync-snap;
  };
}
