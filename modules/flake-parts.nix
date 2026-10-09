# This is config for flake-parts.
{
  inputs,
  lib,
  ...
}: {
  _module.args.locallib = {
    sync-snap = ../lib/sync-snap;
    directory-mappings = ../lib/directory-mappings;
  };

  perSystem = {pkgs, ...}: {
    checks.directory-mappings = import ../lib/directory-mappings/check.nix {
      inherit pkgs;
      wlib = inputs.wrapper-modules.lib;
    };
  };

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
