{config, ...}: {
  meta.hosts.heliosdesk = {
    username = "helios";
  };

  flake.configurations.nixos.heliosdesk = {
    imports = with config.flake.modules.nixos; [
      base
      kde
      nvidia
    ];

    system.stateVersion = "26.05";

    # Disable integrated AMD iGPU
    boot.blacklistedKernelModules = ["amdgpu"];
    boot.kernelParams = ["module_blacklist=amdgpu"];
  };
}
