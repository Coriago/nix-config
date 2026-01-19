# Agenix module for secret management
{inputs, ...}: {
  # Expose agenix as a NixOS module
  flake.modules.nixos.base = {
    imports = [
      inputs.agenix.nixosModules.default
    ];

    # Default age identity location for decryption on host
    age.identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];
  };
}
