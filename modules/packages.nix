{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    isaacsimPackages = pkgs.callPackage ../packages/isaacsim.nix {};
  in {
    packages.comment-checker = pkgs.callPackage ../packages/comment-checker.nix {};
    packages.keypeek = pkgs.callPackage ../packages/keypeek.nix {};
    packages.isaacsim = isaacsimPackages.isaacsim;
    packages.isaacsim-fhs = isaacsimPackages.isaacsim-fhs;
  };
}
