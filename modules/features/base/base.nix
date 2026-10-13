{meta, ...}:
{
  flake.modules.nixos.base = {
    pkgs,
    hostmeta,
    ...
  }: {
    system.stateVersion = hostmeta.stateVersion;
    networking.hostName = hostmeta.hostname;

    # Time and Locale
    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";

    # User setup
    users.users.${hostmeta.username} = {
      isNormalUser = true;
      description = "${hostmeta.username} account";
      extraGroups = ["wheel" "networkmanager" "video" "dialout"];
      openssh.authorizedKeys.keys = [
        meta.sshPublicKey
      ];
    };

    security.sudo.wheelNeedsPassword = false; # Passwordless sudo for wheel group
    services.getty.autologinUser = hostmeta.username; # Autologin
    security.polkit.enable = true; # Don't require sudo for reboot or

    services.openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };
    users.users.root.openssh.authorizedKeys.keys = [
      meta.sshPublicKey
    ];
    programs.ssh.startAgent = true;
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
