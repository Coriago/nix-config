{
  inputs,
  lib,
  ...
}: {
  perSystem = {
    config,
    pkgs,
    system,
    ...
  }: let
    # Reference base pkgs directly from inputs to avoid a circular dependency:
    # _module.args.pkgs cannot safely be derived from itself, but it CAN be
    # derived from the inputs-sourced pkgs and then extended with config.lib.
    basePkgs = inputs.nixpkgs.legacyPackages.${system};
  in {
    # Declare perSystem.lib as an extensible option. Any perSystem module can
    # contribute functions here and they will be merged by the module system.
    options.lib = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = {};
      description = "Custom lib functions merged into pkgs.lib for this system.";
    };

    config = {
      # Extend pkgs.lib with all perSystem.lib definitions so that downstream
      # modules and NixOS configs can reach them as pkgs.lib.<name>.
      _module.args.pkgs = basePkgs.extend (_: prev: {
        lib = prev.lib // config.lib;
      });

      # Convert a YAML file to a Nix value via JSON round-trip.
      lib.fromYAML = path:
        builtins.fromJSON (
          builtins.readFile (
            pkgs.runCommand "from-yaml.json" {
              nativeBuildInputs = [pkgs.yq-go];
            } "yq ea '[.]' ${path} -o=json > $out"
          )
        );
    };
  };
}
