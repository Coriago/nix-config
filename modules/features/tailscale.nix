local: let
  inherit (local.config) meta;
in {
  flake.modules.nixos.tailscale = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      tailscale
    ];
    services.tailscale.enable = true;
    networking.nameservers = ["100.100.100.100" "1.1.1.1"];
    networking.search = [meta.tailscaleDomain];
  };
}
