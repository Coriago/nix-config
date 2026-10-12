{inputs}: {
  flake.modules.nixos.nixmox = {
    imports = [inputs.nixmox.nixosModules.default];
    services.nixmox = {
      enable = true;
      discovery = true;
      enablePower = true;
      allowConfigWrite = true;
      # enableProvision = true; # permits destructive installation over SSH
      gitops.repoUrl = "https://example.org/your/nixos-config.git";
      autoApply = false;
    };
  };
}
