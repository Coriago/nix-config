{
  # NixOS
  flake.modules.nixos.base = {config, ...}: {
    users.users.${config.vars.username} = {
      isNormalUser = true;
      description = "${config.vars.username} account";
      extraGroups = ["wheel" "networkmanager" "video" "dialout"];
    };
    security.sudo.wheelNeedsPassword = false; # Passwordless sudo for wheel group
    services.getty.autologinUser = config.vars.username; # Autologin
    security.polkit.enable = true; # Don't require sudo for reboot or
  };

  # Home Manager
  flake.modules.homeManager.base = {
    pkgs,
    config,
    lib,
    ...
  }: {
    # User
    home.username = config.vars.username;
    home.homeDirectory = lib.mkDefault (
      if pkgs.stdenvNoCC.isDarwin
      then "/Users/${config.vars.username}"
      else "/home/${config.vars.username}"
    );
  };
}
