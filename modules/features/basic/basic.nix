{
  # Bundle of basic modules and settings
  flake.nixosModules.basic = {config, ...}: {
    users.users.${config.vars.user.name} = {
      isNormalUser = true;
    };

    system.stateVersion = config.vars.stateVersion;
  };
}
