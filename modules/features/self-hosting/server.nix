local: {
  flake.modules.nixos.self-hosting = {config, ...}: {
    services.k3s = {
      enable = true;
      tokenFile = config.age.secrets.k3s.path;
    };

    # K3s required firewall rules
    # https://docs.k3s.io/installation/requirements#inbound-rules-for-k3s-nodes
    networking.firewall.allowedTCPPortRanges = [
      {
        from = 2379;
        to = 2380;
      }
    ];
    networking.firewall.allowedTCPPorts = [6443 10250 5001 6443];
    networking.firewall.allowedUDPPorts = [8472 51820 51821];
    # systemd.network.networks = {
    #   "99-ethernet-default-dhcp".networkConfig.MulticastDNS = "yes";
    #   "99-wireless-client-dhcp".networkConfig.MulticastDNS = "yes";
    # };
    # networking.useNetworkd = true;
    # systemd.services = {
    #   systemd-networkd.stopIfChanged = false;
    #   # Services that are only restarted might be not able to resolve when resolved is stopped before
    #   systemd-resolved.stopIfChanged = false;
    # };
  };

  flake.modules.nixos.self-hosting-agent = {...}: {
    services.k3s = {
      role = "agent";
      # serverAddr = "https://${local.config.flake.modules.generic.rpiserver1.vars.local_ip}:6443";
      serverAddr = "https://192.168.8.104:6443";
    };
  };
}
