# General/Common settings
{
  # NixOS
  flake.modules.nixos.base = {
    config,
    pkgs,
    ...
  }: {
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

    # Basic Packages
    environment.systemPackages = with pkgs; [
      gcc
      xdg-utils
      wget
      curl
      zip
      unzip
      jq
      yq
      git
    ];
  };

  # Home Manager
  flake.modules.homeManager.base = {
    config,
    pkgs,
    ...
  }: {
    # Version
    home.stateVersion = config.vars.stateVersion;

    # Basic Packages for User
    home.packages = with pkgs; [
      btop
      dnsutils
    ];
  };
}
