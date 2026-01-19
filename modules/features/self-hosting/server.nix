{
  flake.modules.nixos.self-hosting = {...}: {
    services.k3s = {
      enable = true;
    };
  };

  flake.modules.homeManager.self-hosting = {
  };
}
