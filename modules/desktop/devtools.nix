{inputs, ...}: {
  # NixOS
  flake.modules.nixos.desktop = {config, ...}: {
    # Docker
    virtualisation.docker = {
      enable = true;
      autoPrune.enable = true;
    };
    users.users.${config.vars.username}.extraGroups = ["docker"];

    # Direnv
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
      silent = true;
    };

    # Nixos cli
    imports = [
      inputs.nixos-cli.nixosModules.nixos-cli
    ];
    programs.nixos-cli = {
      enable = true;
      settings = {
        differ.tool = "command";
        differ.command = ["nvd" "diff"];
        apply.use_nom = true;
        config_location = "/home/${config.vars.username}/.config/nixos";
        apply.reexec_as_root = true;
      };
    };
  };

  # Home Manager
  flake.modules.homeManager.desktop = {...}: {
    programs.uv.enable = true;
  };
}
