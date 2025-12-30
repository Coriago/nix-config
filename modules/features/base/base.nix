{
  # General/Common settings

  # NixOS
  flake.modules.nixos.base = {config, ...}: {
    # User
    users.users.${config.vars.username} = {
      isNormalUser = true;
      extraGroups = ["wheel"];
    };

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

    # Basic Networking
    networking.networkmanager.enable = true;
  };

  # Home Manager
  flake.modules.homeManager.base = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # Version
    home.stateVersion = config.vars.stateVersion;

    # User
    home.username = config.vars.username;
    home.homeDirectory = lib.mkDefault (
      if pkgs.stdenvNoCC.isDarwin
      then "/Users/${config.vars.username}"
      else "/home/${config.vars.username}"
    );
  };
}
