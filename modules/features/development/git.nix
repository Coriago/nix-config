{
  flake.modules.homeManager.development = {config, ...}: {
    programs.git = {
      enable = true;
      settings = {
        user.name = config.vars.username;
        user.email = config.vars.email;
      };
    };
  };
}
