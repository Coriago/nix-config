{
  flake.modules.nixos.development = {...}: {
    programs.git = {
      enable = true;
    };
  };
}
