{
  config,
  inputs,
  lib,
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
          hostModule
        ];

        hostmeta = config.meta.hosts.${name};
      }
    );
  };
  config.flake = {
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

    # Output configurations for every configurations.nixos.${name} defined in the flake.
    nixosConfigurations =
      lib.mapAttrs (
        _name: module:
          inputs.nixpkgs.lib.nixosSystem {
            modules = [module];
          }
      )
      config.configurations.nixos;
  };
}
