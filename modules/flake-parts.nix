# Top level flake parts config
{inputs, ...}: {
  # Flake parts addon modules
  imports = [
    # https://flake.parts/options/flake-parts-modules.html
    inputs.flake-parts.flakeModules.modules
    inputs.home-manager.flakeModules.home-manager
  ];

  # Debug for better intellisense
  debug = true;

  # Supported systems
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
}
