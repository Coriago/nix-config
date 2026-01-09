{
  flake.modules.nixos.development = {config, ...}: {
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };
    users.users.${config.vars.username}.extraGroups = ["docker"];
  };
}
