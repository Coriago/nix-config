{
  flake.nixosModules.development = {...}: {
    programs.git = {
      enable = true;
    };
  };
}
