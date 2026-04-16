{inputs, ...}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    packages.comment-checker = pkgs.callPackage ../packages/comment-checker.nix {};
    packages.gaomon-driver = pkgs.callPackage ../packages/gaomon-driver.nix {};

    # overlayAttrs = {
    #   inherit (config.packages) comment-checker;
    # };
  };

  # Add local packages as overlays to nixpkgs
  # flake.modules.nixos.base = {...}: {
  #   nixpkgs.overlays = [
  #     inputs.self.overlays.default
  #   ];
  # };
}
