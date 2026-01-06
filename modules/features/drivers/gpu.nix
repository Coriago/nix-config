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
      open = false;
      modesetting.enable = true;
      nvidiaPersistenced = true;
      powerManagement.enable = true;
      package = nvidiaPackage;
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        nvidia-vaapi-driver
        libva-vdpau-driver
        egl-wayland
        vulkan-loader
        libva
      ];
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
