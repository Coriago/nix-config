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
      storageMode = "local";
      localStorageDir = ./. + "/secrets/rekeyed/${config.networking.hostName}";
      # Master identity - run `make setup-age-key` to create
      masterIdentities = [
        {
          identity = "/home/helios/.config/age/keys.txt";
          pubkey = "age1z6h46h4vqeayqete44sm9sqx0vt8d4fg2mnfck7svfvssgnu3f2qeh8n2u";
        }
      ];
      hostPubkey = lib.mkDefault "dummy";
    };
  };
}
