# GPU Nvidia Drivers
{
  flake.modules.nixos.gpu = {
    config,
    pkgs,
    ...
  }: let
    # Prefer a stable NVIDIA driver
    nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.stable;
  in {
    # Video drivers configuration for Xorg and Wayland
    services.xserver.videoDrivers = ["nvidia"];

    # Enable NVIDIA-specific options
    hardware.nvidia = {
      open = false; # Use proprietary driver - open driver has DRM atomic commit issues
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
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

    environment.variables = {
      # wayland/gpu env var fixes
      QT_QPA_PLATFORM = "wayland;xcb";
      KWIN_DRM_DEVICES = "/dev/dri/card1"; # KWin DRM device
      # LIBVA_DRIVER_NAME = "nvidia"; # Hardware video acceleration
      # GBM_BACKEND = "nvidia-drm"; # Graphics backend for Wayland
      # __GLX_VENDOR_LIBRARY_NAME = "nvidia"; # Use Nvidia driver for GLX
      # NIXOS_OZONE_WL = "1"; # Wayland support for Electron apps
    };

    # Nix cache for CUDA (optional)
    nix.settings = {
      substituters = ["https://cuda-maintainers.cachix.org"];
      trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    };
    environment.systemPackages = with pkgs; [
      vulkan-tools
      mesa-demos
      libva-utils # VA-API debugging tools
    ];
  };
}
