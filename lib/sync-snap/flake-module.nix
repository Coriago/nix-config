# Discover enabled snapshot commands on configured package outputs.
{lib, ...}: {
  perSystem = {
    config,
    pkgs,
    ...
  }: let
    hasAddon = package: package ? configuration && package.configuration ? snapshot;
    registered = lib.filterAttrs (_: package:
      hasAddon package && package.configuration.snapshot.enable)
    config.packages;
    commands = lib.mapAttrs (name: package:
      if name == "all" || builtins.match "[A-Za-z0-9][A-Za-z0-9_-]*" name == null
      then throw "snapshot package names must use letters, digits, hyphens or underscores; 'all' is reserved"
      else "${package}/bin/${package.configuration.binName}-snapshot")
    registered;
    all = pkgs.writeShellScript "snapshot-all" ''
      status=0
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: command: ''
          echo ${lib.escapeShellArg "snapshot-${name}"} >&2
          if ! ${lib.escapeShellArg command} "$@"; then
            echo ${lib.escapeShellArg "snapshot-${name}: failed"} >&2
            status=1
          fi
        '')
        commands)}
      exit "$status"
    '';
  in {
    # Give the addon the actual package attribute name, rather than its binName.
    options.packages = lib.mkOption {
      apply = lib.mapAttrs (name: package:
        if hasAddon package
        then package.wrap {snapshot.name = lib.mkDefault name;}
        else package);
    };
    config.apps =
      lib.mapAttrs' (name: command:
        lib.nameValuePair "snapshot-${name}" {
          type = "app";
          program = command;
          meta.description = "Snapshot runtime preferences for ${name}";
        })
      commands
      // {
        snapshot-all = {
          type = "app";
          program = toString all;
          meta.description = "Snapshot every enabled package, continuing after failures";
        };
      };
  };
}
