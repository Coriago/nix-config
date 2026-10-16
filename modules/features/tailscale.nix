local: let
  inherit (local.config) meta;
in {
  flake.modules.nixos.tailscale = {config, pkgs, ...}: {
    imports = [local.config.flake.modules.nixos.sops];

    sops.secrets.tailscale_key = {};

    environment.systemPackages = with pkgs; [
      tailscale
    ];
    services.tailscale = {
      enable = true;
      authKeyFile = config.sops.secrets.tailscale_key.path;
    };
    networking.nameservers = ["100.100.100.100" "1.1.1.1"];
    networking.search = [meta.tailscaleDomain];
  };
}
