# Common bootloader configuration
{inputs, ...}: {
  flake.modules.nixos.cachyos = {pkgs, ...}: {
    # nixpkgs.overlays = [inputs.nix-cachyos-kernel.overlays.pinned];
    # boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

    # # Binary cache
    # nix.settings.substituters = ["https://attic.xuyh0120.win/lantian"];
    # nix.settings.trusted-public-keys = ["lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="];
  };
}
