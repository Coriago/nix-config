local: let
  inherit (local.config) meta;
in {
  flake.modules.nixos.base = {
    config,
    lib,
    pkgs,
    ...
  }: {
    system.stateVersion = config.hostmeta.stateVersion;
    networking.hostName = config.hostmeta.hostname;

    # Time and Locale
    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";

    # User setup
    users.users.${config.hostmeta.username} = {
      isNormalUser = true;
      description = "${config.hostmeta.username} account";
      extraGroups = ["wheel" "networkmanager" "video" "dialout"];
      openssh.authorizedKeys.keys = [
        meta.sshPublicKey
      ];
    };

    security.sudo.wheelNeedsPassword = false; # Passwordless sudo for wheel group
    services.getty.autologinUser = config.hostmeta.username; # Autologin
    security.polkit.enable = true; # Don't require sudo for reboot or

    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };
    users.users.root.openssh.authorizedKeys.keys = [
      meta.sshPublicKey
    ];
    programs.ssh.startAgent = true;
    programs.git.enable = true;
    programs.zsh = {
      enable = true;
      enableCompletion = true;
    };
    users.defaultUserShell = pkgs.zsh;
    environment.systemPackages = with pkgs; [
      wget
      curl
      zip
      unzip
      jq
      yq
    ];
  };
}
