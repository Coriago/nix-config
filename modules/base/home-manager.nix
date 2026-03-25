# Home manager for nixos
{inputs, ...}: {
  # NixOS
  flake.modules.nixos.base-homemanager = {...}: {
    imports = [inputs.home-manager.nixosModules.home-manager];
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      # This should automatically create dynamic backups for any conflicting files
      backupCommand = ''
        TIMESTAMP=$(date +%Y%m%d%H%M%S)
        # Move the conflicting file to a dated backup
        mv "$1" "$1.$TIMESTAMP.bak"
      '';
    };
  };
}
