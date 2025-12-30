{
  # General/Common settings

  # NixOS
  flake.modules.nixos.base = {config, ...}: {
    # User
    users.users.${config.vars.user.name} = {
      isNormalUser = true;
      extraGroups = ["wheel"];
    };

    # Version
    system.stateVersion = config.vars.stateVersion;

    # Time and Locale
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
      then "/Users/${config.vars.user.name}"
      else "/home/${config.vars.user.name}"
    );
  };
}
