# Common lifecycle adapter. Entry values use sync-snap's existing manifest schema.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}: let
  cfg = config.syncSnap;
  json = pkgs.formats.json {};
  tool = pkgs.callPackage ../../packages/sync-snap {};
  manifest = json.generate "${cfg.program}-sync-snap.json" {
    version = 1;
    programs.${cfg.program} = {
      sync = lib.optionals cfg.enableSync (lib.attrValues cfg.sync);
      snapshot = lib.optionals cfg.enableSnapshot (lib.attrValues cfg.snapshot);
    };
  };
  runner = pkgs.writeShellApplication {
    name = "${cfg.program}-config";
    runtimeInputs = [pkgs.coreutils pkgs.jq tool];
    text =
      ''
        program=${lib.escapeShellArg cfg.program}
        template=${manifest}
        default_snapshot=${wlib.escapeShellArgWithEnv (
          if cfg.snapshotFile == null
          then ""
          else cfg.snapshotFile
        )}
        sync_marker=${lib.escapeShellArg (
          if cfg.skipSyncIfExists == null
          then ""
          else cfg.skipSyncIfExists
        )}
        snapshot_enabled=${lib.boolToString cfg.enableSnapshot}
        declare -A values=() flags=() kinds=()
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: binding: ''
            values[${lib.escapeShellArg name}]=${wlib.escapeShellArgWithEnv binding.value}
            kinds[${lib.escapeShellArg name}]=${lib.escapeShellArg binding.kind}
            ${lib.optionalString (binding.flag != null) "flags[${lib.escapeShellArg binding.flag}]=${lib.escapeShellArg name}"}
          '')
          cfg.variables)}
      ''
      + builtins.readFile ./sync-snap.sh;
  };
  helper = action: {
    relPath = "bin/${cfg.commandPrefix}-${action}";
    content = ''
      #!${pkgs.bash}/bin/bash
      exec ${lib.getExe runner} ${action} "$@"
    '';
    builder = ''cp "$1" "$2" && chmod +x "$2"'';
  };
in {
  imports = [wlib.modules.default];
  options.syncSnap = {
    program = lib.mkOption {
      type = lib.types.str;
      description = "Stable sync-snap program/lock identity.";
    };
    commandPrefix = lib.mkOption {
      type = lib.types.str;
      default = config.binName;
      description = "Prefix for generated -sync and -snapshot commands.";
    };
    enableSync = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the declared sync entries.";
    };
    enableSnapshot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the declared snapshot entries.";
    };
    sync = lib.mkOption {
      type = lib.types.attrsOf json.type;
      default = {};
      description = "Named entries using the sync-snap sync schema; emitted in name order.";
    };
    snapshot = lib.mkOption {
      type = lib.types.attrsOf json.type;
      default = {};
      description = "Named entries using the sync-snap snapshot schema; emitted in name order. An empty destination requires a snapshot output argument or snapshotFile.";
    };
    snapshotFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default output override for a single snapshot entry; runtime environment expansion is supported.";
    };
    skipSyncIfExists = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional app-owned running marker, with @variable@ expansion. Skip automatic sync and refuse manual sync while it exists (including dangling symlinks).";
    };
    variables = lib.mkOption {
      default = {};
      description = "Optional @name@ path bindings, with runtime defaults and app CLI flag overrides. Most wrappers need none.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          value = lib.mkOption {
            type = lib.types.str;
            description = "Default value, with runtime environment expansion.";
          };
          flag = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "App flag that overrides this binding, accepting --flag=value or --flag value.";
          };
          kind = lib.mkOption {
            type = lib.types.enum ["string" "path" "segment"];
            default = "string";
            description = "Optional validation: absolute-normalized path or one directory-name segment.";
          };
        };
      });
    };
  };
  config = {
    argv0type = lib.mkDefault (command: "exec ${lib.getExe runner} launch ${command}");
    constructFiles.syncConfig = helper "sync";
    constructFiles.snapshotConfig = helper "snapshot";
    passthru.syncSnap = {inherit runner manifest;};
  };
}
