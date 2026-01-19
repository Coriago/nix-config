# This is config for flake-parts.
{inputs, ...}: {
  # Flake parts addon modules
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.home-manager.flakeModules.home-manager
    inputs.agenix-rekey.flakeModule
  ];

  # Debug for better intellisense
  debug = true;

  # Supported systems
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  # agenix-rekey configuration
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    # DevShell with agenix available
    devShells.default = pkgs.mkShell {
      nativeBuildInputs = [
        config.agenix-rekey.package
        pkgs.age
      ];
    };
  };
}
