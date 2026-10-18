local: let
  inherit (local.config) meta;
in {
  flake.modules.nixos.nixmox = {
    imports = [local.inputs.nixmox.nixosModules.default];
    services.nixmox = {
      enable = true;
      enableMedia = true;
      discovery = true;
      openFirewall = true;
      allowConfigWrite = true;
      gitops.repoUrl = meta.repoUrl;
      gitops.sshKeyPath = "/home/helios/.ssh/id_rsa";
      autoApply = false;
      addHost = {
        ageKeyFile = "/etc/sops/age/keys.txt";
        sops = {
          rulesFile = ".sops.yaml";
          files = ["secrets/secrets.yaml"];
          rulePathRegex = "secrets/secrets.yaml";
        };
      };
    };
  };
}
