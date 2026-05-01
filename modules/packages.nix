{inputs, ...}: {
  perSystem = {pkgs, ...}: {
    packages.comment-checker = pkgs.callPackage ../packages/comment-checker.nix {};
  };
}
