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
      options.localLLM = mkOption {
        description = "Shared local inference server and client settings.";
        type = types.submodule {
          options = {
            host = mkOption {type = hostMetaType;};
            port = mkOption {type = types.port;};
            model = mkOption {type = types.str;};
            contextLength = mkOption {type = types.ints.positive;};
            outputLength = mkOption {type = types.ints.positive;};
            baseURL = mkOption {type = types.str;};
          };
        };
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
      localLLM = {
        host = config.meta.primaryHost;
        port = 11434;
        # Q4 weights (~5.2 GB) leave room for KV cache and the desktop on 12 GiB.
        model = "qwen3:8b-q4_K_M";
        contextLength = 32768;
        outputLength = 8192;
        baseURL = "http://${config.meta.localLLM.host.hostname}.${config.meta.tailscaleDomain}:${toString config.meta.localLLM.port}/v1";
      };
    };

    # Generic module to be inherited by any submodules to define the metadata for that host
    flake.modules.generic.meta = {lib, ...}: {
      options.hostmeta = lib.mkOption {
        type = hostMetaType;
      };
    };
  };
}
