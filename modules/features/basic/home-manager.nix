{inputs, ...}: {
  # Setup Home Manager
  flake.nixosModules.basic = {config, ...}: {
    imports = [inputs.home-manager.nixosModules.home-manager];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
    };

    home-manager.users.${config.vars.user.name}.home = {
      stateVersion = config.vars.stateVersion;
    };
  };
}
