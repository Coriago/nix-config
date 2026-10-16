local: let
  inherit (local.config) meta;
in {
  flake.modules.nixos.nixmox = {
    imports = [local.inputs.nixmox.nixosModules.default];
    services.nixmox = {
      enable = true;
      enableMedia = true;
      allowConfigWrite = true;
      gitops.repoUrl = meta.repoUrl;
      autoApply = false;
    };
  };
}
