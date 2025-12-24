{inputs, ...}: {
  # Setup Home Manager
  flake.nixosModules.basic = {config, ...}: {
    imports = [inputs.home-manager.nixosModules.home-manager];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = {inherit inputs;};
    };

    home-manager.users.${config.vars.user.name}.home = {
      stateVersion = config.vars.stateVersion;
    };
  };
}
