{
  flake.modules.nixos.noctalia-greeter = {hostmeta, ...}: {
    services.displayManager.noctalia-greeter = {
      enable = true;
      # Upstream limits this to appearance sync from an active local session.
      passwordlessSyncUsers = [hostmeta.username];
    };
  };
}
