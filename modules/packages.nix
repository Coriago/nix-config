# Custom packages for the repo
{
  perSystem = {
    pkgs,
    self',
    ...
  }: {
    packages.sync-snap = pkgs.callPackage ../packages/sync-snap {};
    packages.corne-overlay = pkgs.callPackage ../packages/corne-overlay {};
    packages.nuvio = pkgs.callPackage ../packages/nuvio {};
    packages.fritchii = pkgs.callPackage ../packages/fritchii {};
    checks.sync-snap = self'.packages.sync-snap;
  };
}
