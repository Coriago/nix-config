{
  flake.modules.nixos.noctalia-greeter = {config, ...}: {
    services.displayManager.noctalia-greeter = {
      enable = true;
      # Upstream limits this to appearance sync from an active local session.
      passwordlessSyncUsers = [config.hostmeta.username];
    };
  };
}
