{inputs, ...}: {
  flake.lib.wrapperModules = {
    sync-snap = ../lib/wrappers/sync-snap.nix;
    brave = import ../lib/wrappers/brave.nix {home-manager = inputs.home-manager;};
  };
}
