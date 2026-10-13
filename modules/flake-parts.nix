# This is flake-parts config and global scope settings
{
  inputs,
  ...
}: {
  # Exposes library modules/functions under global scope
  _module.args.locallib = {
    sync-snap = ../lib/sync-snap;
    directory-mappings = ../lib/directory-mappings;
  };

  # Flake parts addon modules
  imports = [
    ../lib/sync-snap/flake-module.nix
    inputs.flake-parts.flakeModules.modules
    inputs.wrapper-modules.flakeModules.wrappers
    inputs.home-manager.flakeModules.home-manager
  ];

  perSystem = {pkgs, ...}: {
    # Disables automatic package creation in flake.wrappers
    # flake.wrappers used for wrapperModules; features export their configured packages explicitly.
    wrappers = {
      control_type = "build";
      packages = {};
    };

    checks.sync-snap-addon = import ../lib/sync-snap/check.nix {
      inherit pkgs;
      wlib = inputs.wrapper-modules.lib;
    };
    checks.directory-mappings = import ../lib/directory-mappings/check.nix {
      inherit pkgs;
      wlib = inputs.wrapper-modules.lib;
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
