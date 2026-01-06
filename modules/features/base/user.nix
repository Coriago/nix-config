{
  # General/Common settings

  # NixOS
  flake.modules.nixos.base = {config, ...}: {
    users.users.${config.vars.username} = {
      isNormalUser = true;
      description = "${config.vars.username} account";
      extraGroups = ["wheel" "networkmanager"];
    };
  };

  # Home Manager
  flake.modules.homeManager.base = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.username = config.vars.username;
    home.homeDirectory = lib.mkDefault (
      if pkgs.stdenvNoCC.isDarwin
      then "/Users/${config.vars.username}"
      else "/home/${config.vars.username}"
    );
  };
}
