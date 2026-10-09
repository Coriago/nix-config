# This is config for flake-parts.
{
  inputs,
  lib,
  ...
}: {
  _module.args.SyncSnapWrapperModule = ../lib/sync-snap;

  # Flake parts addon modules
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.wrapper-modules.flakeModules.wrappers
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
