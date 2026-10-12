local: let
  inherit (local.config) meta;
in {
  flake.modules.nixos.nixmox = {
    imports = [local.inputs.nixmox.nixosModules.default];
    services.nixmox = {
      enable = true;
      package = local.inputs.nixmox.packages.x86_64-linux.default;
      discovery = true;
      enablePower = true;
      allowConfigWrite = true;
      enableProvision = true; # permits destructive installation over SSH
      gitops.repoUrl = meta.repoUrl;
      autoApply = false;
    };
  };
}
