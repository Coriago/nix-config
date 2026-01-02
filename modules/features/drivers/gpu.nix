{
  flake.modules.nixos.gpu = {
    config,
    lib,
    ...
  }: {
    # Video drivers configuration for Xorg and Wayland
    services.xserver.videoDrivers = ["nvidia"];

    # Enable NVIDIA-specific options
    hardware.nvidia = {
      open = false;
      modesetting.enable = true;
      nvidiaPersistenced = true;
      powerManagement.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
    };

    # Accept NVIDIA license
    nixpkgs.config = lib.mkMerge [{nvidia = {acceptLicense = true;};}];

    # Debugging
    powerManagement.enable = true;

    # Nix cache for CUDA (optional)
    nix.settings = {
      substituters = ["https://cuda-maintainers.cachix.org"];
      trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    };
  };
}
