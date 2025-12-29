{inputs, ...}: {
  # Setup Home Manager
  flake.modules.nixos.home-manager = {...}: {
    imports = [inputs.home-manager.nixosModules.home-manager];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
    };
  };
}
