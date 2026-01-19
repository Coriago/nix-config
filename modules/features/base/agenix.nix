# Agenix-rekey module for secret management
# This module sets up agenix with automatic rekeying support
{inputs, ...}: {
  # Expose agenix as a NixOS module
  flake.modules.nixos.base = {
    config,
    lib,
    ...
  }: {
    # Import agenix modules
    imports = [
      inputs.agenix.nixosModules.default
      inputs.agenix-rekey.nixosModules.default
    ];

    age.rekey = {
      # Storage mode: "local" stores rekeyed secrets in your repo
      # This allows building without access to master key
      storageMode = "local";

      # Directory for rekeyed secrets (must be per-host)
      localStorageDir =
        inputs.self.outPath + "/secrets/rekeyed/${config.networking.hostName}";

      # Master identity - your existing age key
      # masterIdentities = [
      #   {
      #     # Path to your age private key
      #     identity = "/home/helios/.config/sops/age/keys.txt";
      #     # Public key (avoids needing to read the private key during encryption)
      #     pubkey = "age1kd45hh4rg8kravq8qa4fsqjdndd85j67jj326pksqukgf0rzsacspgfs0r";
      #   }
      # ];

      # Host public key for this system
      # For existing hosts, override this in the host configuration
      # For new hosts, this dummy key allows initial deployment
      # hostPubkey = lib.mkDefault "age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqs3290gq";
    };
  };
}
