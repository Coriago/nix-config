# This provides the configurations.nixos option used to define nixos configs for hosts
# It also gives a centralized place to import modules that all configurations will use such as meta and liveconfig
{
  config,
  inputs,
  lib,
  locallib,
  self,
  ...
}: {
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.deferredModule;
    default = {};
    apply = lib.mapAttrs (
      name: hostModule: {
        # Automatically add hostmeta to configurations
        imports = [
          config.flake.modules.generic.meta
          (import locallib.live-config { 
            flakeRoot = self.outPath; 
          })
          hostModule
        ];

        hostmeta = config.meta.hosts.${name};
      }
    );
  };
  config.flake = {

    # Output configurations for every configurations.nixos.${name} defined in the flake.
    nixosConfigurations =
      lib.mapAttrs (
        _name: module:
          inputs.nixpkgs.lib.nixosSystem {
            modules = [module];
          }
      )
      config.configurations.nixos;

    # Checks that the nixosConfigurations above are valid
    checks = lib.mkMerge (
      lib.mapAttrsToList (
        name: nixos: let
          toplevel = nixos.config.system.build.toplevel;
        in {
          ${toplevel.system} = {
            "configurations:nixos:${name}" = toplevel;
          };
        }
      )
      config.flake.nixosConfigurations
    );
  };
}
