local: {
  flake.modules.nixos.nvidia-laptop = {lib, ...}: {
    imports = [local.config.flake.modules.nixos.nvidia];

    hardware.nvidia = {
      powerManagement.finegrained = true;
      prime.offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      # Avoid a small tmpfs when preserving VRAM across suspend.
      moduleParams.nvidia.NVreg_TemporaryFilePath = lib.mkDefault "/var/tmp";
    };
  };
}
