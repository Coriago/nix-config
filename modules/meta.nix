{
  lib,
  meta,
  ...
}: {
  imports = [../lib/meta];

  config.meta = {
    email = "gagemiller155@gmail.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBYVacUQ/B11m2ycolJnoIKn4TS1alZKDbe1ssRnWZE2";
    primaryHost = meta.hosts.heliosdesk;
    tailscaleDomain = "li-taipan.ts.net";
    repoUrl = "https://github.com/Coriago/nix-config.git";
    repoPath = ".config/nix-config";
    localLLM = {
      host = meta.primaryHost;
      port = 11434;
      # Q4 weights (~5.2 GB) leave room for KV cache and the desktop on 12 GiB.
      model = "qwen3:8b-q4_K_M";
      contextLength = 32768;
      outputLength = 8192;
      baseURL = "http://${meta.localLLM.host.hostname}.${meta.tailscaleDomain}:${toString meta.localLLM.port}/v1";
    };
  };

  options.meta = lib.mkOption {
    type = lib.types.submodule {
      options.hosts = lib.mkOption {
        type = lib.types.lazyAttrsOf (lib.types.submodule ({config, ...}: {
          options = {
            # Define host meta options and defaults here
            username = lib.mkOption {
              type = lib.types.str;
              default = "helios";
            };
            stateVersion = lib.mkOption {
              type = lib.types.str;
              default = "26.05";
            };
            flakePath = lib.mkOption {
              type = lib.types.str;
              default = "/home/${config.username}/${meta.repoPath}";
            };
          };
        }));
      };

      options.localLLM = lib.mkOption {
        description = "Shared local inference server and client settings.";
        type = lib.types.lazyAttrsOf lib.types.anything;
      };
    };
  };
}
