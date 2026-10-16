local: let
  inherit (local) lib;
  inherit (local.config) meta;
  cache = meta.binaryCache;
in {
  configurations.nixos = lib.optionalAttrs cache.enable {
    ${cache.host.hostname}.imports = [local.config.flake.modules.nixos.harmonia];
  };

  flake.modules.nixos.harmonia = {config, ...}: {
    imports = with local.config.flake.modules.nixos; [
      sops
      tailscale
    ];

    config = lib.mkIf cache.enable {
      sops.secrets.nix_signing_key.restartUnits = ["harmonia.service"];

      services.harmonia.cache = {
        enable = true;
        signKeyPaths = [config.sops.secrets.nix_signing_key.path];
        settings.bind = "[::]:${toString cache.port}";
      };

      networking.firewall.interfaces.${config.services.tailscale.interfaceName}.allowedTCPPorts = [cache.port];
    };
  };
}
