{inputs, ...}: {
  flake.modules.nixos.cachyos-kernel = {pkgs, ...}: {
    # Use latest kernel
    boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
    nix.settings.substituters = [
      "https://attic.xuyh0120.win/lantian"
      "https://cache.xinux.uz"
    ];
    nix.settings.trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
    ];
    nixpkgs.overlays = [inputs.nix-cachyos-kernel.overlays.default];
  };
}
