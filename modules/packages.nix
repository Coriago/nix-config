# Custom packages for the repo
{
  perSystem = {
    pkgs,
    self',
    ...
  }: {
    packages.sync-snap = pkgs.callPackage ../packages/sync-snap {};
    packages.corne-overlay = pkgs.callPackage ../packages/corne-overlay {};
    checks.sync-snap = self'.packages.sync-snap;
  };
}
