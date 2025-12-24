{
  # General/Common settings
  flake.nixosModules.basic = {config, ...}: {
    users.users.${config.vars.user.name} = {
      isNormalUser = true;
      extraGroups = ["wheel"];
    };

    system.stateVersion = config.vars.stateVersion;

    time.timeZone = config.vars.timeZone;
    i18n.defaultLocale = config.vars.locale;
    i18n.extraLocaleSettings = {
      LC_ADDRESS = config.vars.timeZone;
      LC_IDENTIFICATION = config.vars.timeZone;
      LC_MEASUREMENT = config.vars.timeZone;
      LC_MONETARY = config.vars.timeZone;
      LC_NAME = config.vars.timeZone;
      LC_NUMERIC = config.vars.timeZone;
      LC_PAPER = config.vars.timeZone;
      LC_TELEPHONE = config.vars.timeZone;
      LC_TIME = config.vars.timeZone;
    };

    networking.networkmanager.enable = true;
  };
}
