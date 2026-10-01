{
  flake.modules.nixos.umbriel = {lib, ...}: {
    programs.umbriel.enable = true;
    services.displayManager.defaultSession = lib.mkForce "umbriel";
  };
}
