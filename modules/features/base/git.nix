{config, ...}: let
  inherit (config) meta;
in {
  flake.modules.nixos.base = {...}: {
    programs.git.enable = true;
  };

  flake.modules.homeManager.base = {config, ...}: {
    programs.git = {
      enable = true;
      settings.user = {
        name = config.hostmeta.username;
        email = meta.email;
      };
    };
  };
}
