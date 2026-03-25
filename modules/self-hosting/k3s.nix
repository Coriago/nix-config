local: {
  flake.modules.nixos.self-hosting = {config, ...}: {
    # Add K3s
    services.k3s = {
      enable = true;
      tokenFile = config.sops.secrets.k3s_token.path;
      gracefulNodeShutdown = {
        enable = true;
      };
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
  };

  flake.modules.nixos.self-hosting-agent = {lib, ...}: {
    services.k3s = {
      role = lib.mkDefault "agent";
      serverAddr = "https://192.168.8.104:6443";
    };
  };
}
