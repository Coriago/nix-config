# Git configuration
{
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
