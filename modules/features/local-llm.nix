local: let
  inherit (local.config.meta) localLLM;
in {
  flake.modules.nixos.local-llm = {
    config,
    lib,
    pkgs,
    ...
  }: {
    imports = [local.config.flake.modules.nixos.tailscale];

    assertions = [
      {
        assertion = config.hostmeta.hostname == localLLM.host.hostname;
        message = "The local-llm feature must run on meta.localLLM.host.";
      }
      {
        assertion = builtins.elem "nvidia" config.services.xserver.videoDrivers;
        message = "The local-llm CUDA backend requires the nvidia feature.";
      }
      {
        assertion = config.networking.firewall.enable;
        message = "The local-llm listener requires the firewall to restrict access to Tailscale.";
      }
    ];

    services.ollama = {
      enable = true;
      package = pkgs.ollama-cuda;
      host = "0.0.0.0";
      inherit (localLLM) port;
      openFirewall = false;
      loadModels = [localLLM.model];
      environmentVariables = {
        OLLAMA_CONTEXT_LENGTH = toString localLLM.contextLength;
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q8_0";
        # Serialize requests from all clients to bound VRAM usage.
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_KEEP_ALIVE = "5m";
      };
    };

    networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [localLLM.port];
  };
}
