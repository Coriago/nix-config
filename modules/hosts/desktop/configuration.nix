{config, ...}: {
  meta.hosts.heliosdesk = {
    username = "helios";
    stateVersion = "26.05";
  };

  configurations.nixos.heliosdesk = {
    imports = with config.flake.modules.nixos; [
      workstation
      nvidia
      cachyos-kernel
    ];

    # Disable integrated AMD iGPU
    boot.blacklistedKernelModules = ["amdgpu"];
    boot.kernelParams = ["module_blacklist=amdgpu"];
  };
}
