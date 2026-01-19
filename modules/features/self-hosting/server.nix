{
  flake.modules.nixos.self-hosting = {config, ...}: {
    services.k3s = {
      enable = true;
      tokenFile = config.age.secrets.k3s.path;
    };

    boot.kernelParams = [
      "cgroup_enable=memory"
      "cgroup_memory=1"
    ];

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

  flake.modules.nixos.self-hosting-agent = {config, ...}: {
    services.k3s = {
      role = "agent";
      serverAddr = "https://${config.flake.modules.generic.rpiserver1.vars.local_ip}:6443";
    };
  };
}
