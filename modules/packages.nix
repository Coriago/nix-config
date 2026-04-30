{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages.comment-checker = pkgs.callPackage ../packages/comment-checker.nix {};
    packages.gaomon-driver = pkgs.callPackage ../packages/gaomon-driver.nix {};
  };
}
