# Temporary accessibility build; remove this file and its reference in ghostty.nix to revert.
{...}: {
  perSystem = {pkgs, ...}: let
    revision = "25a63fe692030278142c80e7b18289ede1b978ae";
    source = builtins.fetchTarball {
      url = "https://github.com/alex19EP/ghostty/archive/${revision}.tar.gz";
      sha256 = "sha256-FewNPST0wG6ItdCTXJ9diYLgrGk8PZzrLb5oDZME68Y=";
    };
  in {
    packages.ghostty-a11y = pkgs.callPackage "${source}/nix/package.nix" {
      inherit revision;
      optimize = "ReleaseFast";
    };
  };
}
