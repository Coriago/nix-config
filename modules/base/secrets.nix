{inputs, ...}: {
  flake.modules.nixos.base = {...}: {
    imports = [
      inputs.sops-nix.nixosModules.sops
    ];

    sops.defaultSopsFile = ../../secrets/secrets.yaml;
    sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    sops.age.keyFile = "/etc/sops/age/keys.txt";
    sops.age.generateKey = true;

    sops.secrets = {
      k3s_token = {};
      nix_sigining_key = {};
    };
  };
}
