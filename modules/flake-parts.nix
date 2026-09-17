# This is config for flake-parts.
{
  inputs,
  lib,
  ...
}: {
  # Flake parts addon modules
  imports = [
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
