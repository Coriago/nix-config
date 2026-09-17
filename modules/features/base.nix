local: let
  inherit (local.config) meta;
in {
  flake.modules.nixos.base = {
    config,
    lib,
    ...
  }: {
    # Time and Locale
    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";

    users.users.${config.hostmeta.username} = {
      isNormalUser = true;
      description = "${config.hostmeta.username} account";
      extraGroups = ["wheel" "networkmanager" "video" "dialout"];
      openssh.authorizedKeys.keys = [
        meta.sshPublicKey
      ];
    };

    imports = [
      local.inputs.sops-nix.nixosModules.sops
    ];

    sops.defaultSopsFile = ../../secrets/secrets.yaml;
    sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    sops.age.keyFile = "/etc/sops/age/keys.txt";
    sops.age.generateKey = true;

    sops.secrets = {
      k3s_token = {};
      nix_sigining_key = {};
      email = {};
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
    boot.loader = {
      systemd-boot.enable = true;
      systemd-boot.consoleMode = "auto";
      efi.canTouchEfiVariables = true;
      grub.enable = lib.mkForce false;
      systemd-boot.configurationLimit = 10;
    };

    programs.git.enable = true;
  };
}
