{inputs, config, ...}: {
  flake.modules.nixos.base = {hostmeta, ...}: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      sharedModules = [
        # Passes host metadata to home-manager modules
        config.flake.modules.generic.meta
        {inherit hostmeta;}
      ];
      backupCommand = ''
        TIMESTAMP=$(date +%Y%m%d%H%M%S)
        # Move the conflicting file to a dated backup
        mv "$1" "$1.$TIMESTAMP.bak"
      '';
      users.${hostmeta.username} = {
        imports = [
          config.flake.modules.homeManager.base
        ];
      };
    };
  };

  flake.modules.homeManager.base = {hostmeta, ...}: {
    home.stateVersion = hostmeta.stateVersion;
  };
}
