{inputs, ...}: {
  # Setup Home Manager
  flake.nixosModules.home-manager = {config, ...}: {
    imports = [inputs.home-manager.nixosModules.home-manager];

    programs.home-manager.enable = true;

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
    };

    home-manager.users.${config.variables.user.name}.home = {
      stateVersion = config.variables.stateVersion;
    };
  };
}
