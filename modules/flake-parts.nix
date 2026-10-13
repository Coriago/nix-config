# This is flake-parts config
{
  inputs,
  ...
}: {
  # Flake parts addon modules
  imports = [
    ../lib/sync-snap/flake-module.nix
    inputs.flake-parts.flakeModules.modules
    inputs.wrapper-modules.flakeModules.wrappers
    inputs.home-manager.flakeModules.home-manager
  ];

  perSystem = {...}: {
    # Disables automatic package creation in flake.wrappers
    # flake.wrappers used for wrapperModules; features export their configured packages explicitly.
    wrappers = {
      control_type = "build";
      packages = {};
    };
  };

  # Debug for better intellisense
  debug = true;

  # Supported systems
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
}
