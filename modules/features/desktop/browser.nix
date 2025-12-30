{
  flake.modules.homeManager.desktop = {...}: {
    programs.brave = {
      enable = true;
    };
  };
}
