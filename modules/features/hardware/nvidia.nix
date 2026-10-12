{
  flake.modules.nixos.nvidia = {config, ...}: let
    # Prefer a stable NVIDIA driver
    nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.stable;
  in {
    # Video drivers configuration for Xorg and Wayland
    services.xserver.videoDrivers = ["nvidia"];

    # Enable NVIDIA-specific options
    hardware.nvidia = {
      open = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = false;
      package = nvidiaPackage;
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    nixpkgs.config.nvidia.acceptLicense = true;
  };
}
