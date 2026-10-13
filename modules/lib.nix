# Sets up locallib and global helper modules
{inputs, ...}: {
  # Exposes library modules/functions under global scope
  _module.args.locallib = {
    sync-snap = ../lib/sync-snap;
    directory-mappings = ../lib/directory-mappings;
    live-config = ../lib/live-config;
  };

  perSystem = {pkgs, ...}: {
    checks.sync-snap-addon = import ../lib/sync-snap/check.nix {
      inherit pkgs;
      wlib = inputs.wrapper-modules.lib;
    };
    checks.directory-mappings = import ../lib/directory-mappings/check.nix {
      inherit pkgs;
      wlib = inputs.wrapper-modules.lib;
    };
  };
}
