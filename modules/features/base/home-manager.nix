{inputs, ...}: {
  # Home manager for nixos
  flake.modules.nixos.base = {...}: {
    imports = [inputs.home-manager.nixosModules.home-manager];
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      sharedModules = [inputs.plasma-manager.homeModules.plasma-manager];
      backupCommand = ''
        TIMESTAMP=$(date +%Y%m%d%H%M%S)
        # Move the conflicting file to a dated backup
        mv "$1" "$1.$TIMESTAMP.bak"
      '';
    };
  };
}
