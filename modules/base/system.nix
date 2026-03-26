# Git configuration
{
  # NixOS
  flake.modules.nixos.base = {config, ...}: {
    # Version
    system.stateVersion = config.vars.stateVersion;

    # Time and Locale
    time.timeZone = config.vars.timeZone;
    i18n.defaultLocale = config.vars.locale;
    i18n.extraLocaleSettings = {
      LC_ADDRESS = config.vars.locale;
      LC_IDENTIFICATION = config.vars.locale;
      LC_MEASUREMENT = config.vars.locale;
      LC_MONETARY = config.vars.locale;
      LC_NAME = config.vars.locale;
      LC_NUMERIC = config.vars.locale;
      LC_PAPER = config.vars.locale;
      LC_TELEPHONE = config.vars.locale;
      LC_TIME = config.vars.locale;
    };
  };

  # Home Manager
  flake.modules.homeManager.base = {config, ...}: {
    # Version
    home.stateVersion = config.vars.stateVersion;
  };
}
