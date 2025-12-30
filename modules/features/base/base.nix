{
  # General/Common settings

  # NixOS
  flake.modules.nixos.base = {config, ...}: {
    # User
    users.users.${config.username} = {
      isNormalUser = true;
      extraGroups = ["wheel"];
    };

    # Version
    system.stateVersion = config.stateVersion;

    # Time and Locale
    time.timeZone = config.timeZone;
    i18n.defaultLocale = config.locale;
    i18n.extraLocaleSettings = {
      LC_ADDRESS = config.locale;
      LC_IDENTIFICATION = config.locale;
      LC_MEASUREMENT = config.locale;
      LC_MONETARY = config.locale;
      LC_NAME = config.locale;
      LC_NUMERIC = config.locale;
      LC_PAPER = config.locale;
      LC_TELEPHONE = config.locale;
      LC_TIME = config.locale;
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
    home.stateVersion = config.stateVersion;

    # User
    home.username = config.username;
    home.homeDirectory = lib.mkDefault (
      if pkgs.stdenvNoCC.isDarwin
      then "/Users/${config.username}"
      else "/home/${config.username}"
    );
  };
}
