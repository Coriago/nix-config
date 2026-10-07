local: {
  flake.modules.nixos.base = {config, ...}: {
    imports = [
      local.inputs.home-manager.nixosModules.home-manager
    ];
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      sharedModules = [
        # Passes host metadata to home-manager modules
        local.config.flake.modules.generic.meta
        {hostmeta = config.hostmeta;}
      ];
      backupCommand = ''
        TIMESTAMP=$(date +%Y%m%d%H%M%S)
        # Move the conflicting file to a dated backup
        mv "$1" "$1.$TIMESTAMP.bak"
      '';
      users.${config.hostmeta.username} = {
        imports = [
          local.config.flake.modules.homeManager.base
        ];
      };
    };
  };

  flake.modules.homeManager.base = {config, ...}: {
    home.stateVersion = config.hostmeta.stateVersion;
  };
}
