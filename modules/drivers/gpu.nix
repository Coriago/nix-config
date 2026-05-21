# GPU Nvidia Drivers
{
  flake.modules.nixos.gpu = {
    config,
    pkgs,
    ...
  }: let
    # Prefer a stable NVIDIA driver
    # nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.legacy_580;
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

    # Containers
    hardware.nvidia-container-toolkit.enable = true;
    hardware.nvidia-container-toolkit.mount-nvidia-executables = true;
    # virtualisation.docker.enableNvidia = true;

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
    };

    # Nix cache for CUDA (optional)
    nix.settings = {
      substituters = ["https://cache.nixos-cuda.org"];
      trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];
    };
    environment.systemPackages = with pkgs; [
      vulkan-tools
      mesa-demos
      libva-utils # VA-API debugging tools
    ];

    # Enable GPU access in K3s
    # systemd.tmpfiles.rules = [
    #   "L /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl - - - - ${pkgs.writeText "config.toml.tmpl" ''
    #     {{ template "base" . }}

    #     [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
    #       privileged_without_host_devices = false
    #       runtime_engine = ""
    #       runtime_root = ""
    #       runtime_type = "io.containerd.runc.v2"
    #   ''}"
    # ];
    # services.k3s.nodeLabel = [
    #   "nixos-nvidia-cdi=enabled"
    # ];
  };
}
