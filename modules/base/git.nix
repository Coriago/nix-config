# Git configuration
{
  # NixOS
  flake.modules.nixos.base = {...}: {
    programs.git.enable = true;
  };

  # Home Manager
  flake.modules.homeManager.base = {config, ...}: {
    programs.git = {
      enable = true;
      settings = {
        user.name = config.vars.username;
        user.email = config.vars.email;
      };
    };
  };
}
