{inputs, ...}: {
  flake.modules.nixos.cachyos-kernel = {pkgs, ...}: {
    # Use latest kernel
    boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
    nix.settings.substituters = [
      "https://cache.lantian.pub/lantian"
      "https://cache.xinux.uz"
    ];
    nix.settings.trusted-public-keys = [
      "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
      "cache.xinux.uz:BXCrtqejFjWzWEB9YuGB7X2MV4ttBur1N8BkwQRdH+0="
    ];
    nixpkgs.overlays = [inputs.nix-cachyos-kernel.overlays.default];
  };
}
