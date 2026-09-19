{config, ...}: {
  meta.hosts.heliosdesk = {
    username = "helios";
  };

  configurations.nixos.heliosdesk = {
    imports = with config.flake.modules.nixos; [
      base
      kde
      nvidia
      cachyos-kernel
    ];

    system.stateVersion = "26.05";

    # Disable integrated AMD iGPU
    boot.blacklistedKernelModules = ["amdgpu"];
    boot.kernelParams = ["module_blacklist=amdgpu"];
  };
}
