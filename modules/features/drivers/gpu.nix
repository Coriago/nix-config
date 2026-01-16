# GPU Nvidia Drivers
{
  flake.modules.nixos.gpu = {
    config,
    pkgs,
    ...
  }: let
    # Prefer a stable NVIDIA driver to reduce Xid/Wayland crash incidence.
    nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.stable;
  in {
    # Video drivers configuration for Xorg and Wayland
    services.xserver.videoDrivers = ["nvidia"];

    # Enable NVIDIA-specific options
    hardware.nvidia = {
      open = false; # Use proprietary driver - open driver has DRM atomic commit issues
      modesetting.enable = true;
      nvidiaPersistenced = true;
      powerManagement.enable = true;
      package = nvidiaPackage;
    };
    hardware.nvidia-container-toolkit.enable = true;

    # Early KMS loading - critical for preventing atomic commit failures
    boot.initrd.kernelModules = ["nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    # Accept NVIDIA license
    nixpkgs.config.nvidia.acceptLicense = true;

    # Nix cache for CUDA (optional)
    nix.settings = {
      substituters = ["https://cuda-maintainers.cachix.org"];
      trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    };
  };
}
