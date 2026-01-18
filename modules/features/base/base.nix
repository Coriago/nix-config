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
      xdg-utils
      wget
      curl
      zip
      unzip
      jq
      yq
      gnumake
    ];

    # User
    users.users.${config.vars.username} = {
      isNormalUser = true;
      description = "${config.vars.username} account";
      extraGroups = ["wheel" "networkmanager" "video"];
      openssh.authorizedKeys.keys = [
        config.vars.sshPublicKey
      ];
    };

    security.sudo.wheelNeedsPassword = false; # Passwordless sudo for wheel group
    services.getty.autologinUser = config.vars.username; # Autologin
    security.polkit.enable = true; # Don't require sudo for reboot or

    # SSH
    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };
    users.users.root.openssh.authorizedKeys.keys = [
      config.vars.sshPublicKey
    ];
  };

  # Home Manager
  flake.modules.homeManager.base = {
    config,
    pkgs,
    lib,
    ...
  }: {
    # Version
    home.stateVersion = config.vars.stateVersion;

    # Basic Packages for User
    home.packages = with pkgs; [
      btop
      dnsutils
    ];

    # User
    home.username = config.vars.username;
    home.homeDirectory = lib.mkDefault (
      if pkgs.stdenvNoCC.isDarwin
      then "/Users/${config.vars.username}"
      else "/home/${config.vars.username}"
    );
  };
}
