{
  flake.module.nixos.nvidia = {...}: {
    # Video drivers configuration for Xorg and Wayland
    services.xserver.videoDrivers = ["nvidia"];

    # Blacklist nouveau to avoid conflicts
    boot.blacklistedKernelModules = ["nouveau"];

    hardware.nvidia = {
      open = true;
    };
    hardware.graphics = {
      enable = true;
    };

    # Accept NVIDIA license
    nixpkgs.config.nvidia.acceptLicense = true;

    # Nix cache for CUDA
    nix.settings = {
      substituters = ["https://cuda-maintainers.cachix.org"];
      trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    };
  };
}
