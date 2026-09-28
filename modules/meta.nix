{
  lib,
  config,
  ...
}: let
  inherit (lib) mkOption types;
  hostMetaType = types.submodule ({name, ...}: {
    freeformType = types.lazyAttrsOf types.anything;

    options = {
      username = mkOption {
        type = types.str;
        default = "helios";
      };

      hostname = mkOption {
        type = types.str;
        default = name;
      };

      stateVersion = mkOption {
        type = types.str;
        default = "26.05";
      };
    };
  });
in {
  options.meta = mkOption {
    description = "Top Level Metadata storage";
    type = types.submodule {
      freeformType = types.lazyAttrsOf types.anything;
      options.hosts = mkOption {
        default = {};
        type = types.lazyAttrsOf hostMetaType;
      };
      options.email = mkOption {
        type = types.str;
        description = "Email address used for the primary user's Git identity.";
      };
    };
    default = {};
  };

  config = {
    # meta.hosts = lib.genAttrs (lib.attrNames config.configurations.nixos) (_name: {});

    # Central metadata used across flake
    meta = {
      email = "gagemiller155@gmail.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYVacUQ/B11m2ycolJnoIKn4TS1alZKDbe1ssRnWZE2";
      primaryHost = config.meta.hosts.heliosdesk;
      tailscaleDomain = "li-taipan.ts.net";
    };

    # Generic module to be inherited by any submodules to define the metadata for that host
    flake.modules.generic.meta = {lib, ...}: {
      options.hostmeta = lib.mkOption {
        type = hostMetaType;
      };
    };
  };
}
