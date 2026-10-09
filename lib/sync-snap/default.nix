# Optional helper module for custom nix-wrapper-modules wrappers.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}: let
  inherit (lib) mkOption mkDefault types;
  tool = pkgs.callPackage ../../packages/sync-snap {};
  formatType = types.nullOr (types.enum ["json" "toml" "raw"]);
  pathType = types.coercedTo types.path (p: "${p}") types.str;
  relativePath = types.addCheck types.str (p:
    p
    != ""
    && !(lib.hasPrefix "/" p)
    && lib.all (part: part != ".." && part != "." && part != "") (lib.splitString "/" p));
  sourceType = types.either pathType (types.submodule {
    options = {
      path = mkOption {
        type = pathType;
        description = "Source file or directory.";
      };
      format = mkOption {
        type = formatType;
        default = null;
        description = "Source format override; null infers from its suffix.";
      };
      optional = mkOption {
        type = types.bool;
        default = false;
        description = "Allow a missing source (invalid contents still fail).";
      };
    };
  });
  entryType = operation:
    types.submodule (args @ {name, ...}: let
      entry = args.config;
    in {
      options =
        {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Include this file in the operation.";
          };
          sources = mkOption {
            type = types.listOf sourceType;
            default = [];
            description = "Ordered sources, later values win. Override generated defaults with an ordinary assignment.";
          };
          destinationDir = mkOption {
            type = types.str;
            default = config.${operation}.defaultDir;
            description = "Runtime output directory; supports sync-snap's HOME/XDG expansion.";
          };
          destinationPath = mkOption {
            type = relativePath;
            default = name;
            description = "Relative output path within destinationDir.";
          };
          path = mkOption {
            type = types.str;
            readOnly = true;
            default = destination entry;
            description = "Computed destinationDir/destinationPath; HOME/XDG placeholders remain for runtime expansion.";
          };
          format = mkOption {
            type = formatType;
            default = null;
            description = "Output format override; null infers from destination suffix.";
          };
          directory = mkOption {
            type = types.bool;
            default = false;
            description = "Copy a raw directory overlay instead of one file.";
          };
        }
        // (
          if operation == "sync"
          then {
            policy = mkOption {
              type = types.enum ["seed" "fill-missing" "merge" "replace"];
              default = "merge";
              description = "How the baseline updates existing runtime contents. Raw files require seed or replace.";
            };
            trigger = mkOption {
              type = types.enum ["on-init" "on-start" "never"];
              default = "on-start";
              description = "Automatic sync trigger; manual sync ignores it.";
            };
          }
          else {
            pruneKeyContains = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Regexes matching preference paths to remove.";
            };
            pruneValueContains = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Regexes matching values to remove.";
            };
            transform = mkOption {
              type = types.listOf types.str;
              default = [];
              description = "Ordered jq snapshot filters.";
            };
          }
        );
    });
  destination = entry: "${lib.removeSuffix "/" entry.destinationDir}/${entry.destinationPath}";
  sourceArgs = value:
    if builtins.isString value
    then ["--source" value]
    else
      ["--source" value.path]
      ++ lib.optionals (value.format != null) ["--source-format" value.format]
      ++ lib.optionals value.optional ["--source-optional" "true"];
  entryArgs = operation: entry:
    ["--destination" (destination entry)]
    ++ lib.concatMap sourceArgs entry.sources
    ++ lib.optionals (entry.format != null) ["--format" entry.format]
    ++ lib.optionals entry.directory ["--directory" "true"]
    ++ (
      if operation == "sync"
      then ["--policy" entry.policy "--trigger" entry.trigger]
      else
        lib.concatMap (v: ["--prune-key-contains" v]) entry.pruneKeyContains
        ++ lib.concatMap (v: ["--prune-value-contains" v]) entry.pruneValueContains
        ++ lib.concatMap (v: ["--transform" v]) entry.transform
    );
  entries = operation: lib.filterAttrs (_: entry: entry.enable) config.${operation}.files;
  # Internal helper commands are not application configuration.
  generated = lib.filterAttrs (name: _: !(lib.hasPrefix "_syncSnap" name)) config.constructFiles;
  invocation = operation:
    if entries operation == {}
    then "${pkgs.coreutils}/bin/true"
    else
      lib.escapeShellArgs (["${lib.getExe tool}" operation "--program" config.binName]
        ++ lib.concatMap (entryArgs operation) (lib.attrValues (entries operation)));
  commandFile = operation: {
    relPath = "bin/${config.binName}-${operation}";
    content = ''
      #!${pkgs.bash}/bin/bash
      exec ${invocation operation} "$@"
    '';
    builder = ''cp "$1" "$2" && chmod +x "$2"'';
  };
in {
  imports = [wlib.modules.default];
  options = lib.genAttrs ["sync" "snapshot"] (operation: {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable ${operation} for this wrapper. Importing the addon alone does not enable it.";
    };
    defaultDir = mkOption {
      type = types.str;
      default =
        if operation == "sync"
        then "\${XDG_CONFIG_HOME}/${config.binName}"
        else "/home/helios/.config/nix-config/snapshot";
      description = "Default destination directory for ${operation} files.";
    };
    files = mkOption {
      type = types.attrsOf (entryType operation);
      default = {};
      description = "Named ${operation} entries, processed in name order.";
    };
  });
  config = lib.mkMerge [
    {
      # Expand runtime config paths after providing the standard XDG fallback.
      envDefault.XDG_CONFIG_HOME = {
        data = mkDefault "\${HOME}/.config";
        esc-fn = mkDefault wlib.escapeShellArgWithEnv;
        before =
          lib.filter (name: name != "XDG_CONFIG_HOME")
          (lib.unique (lib.attrNames config.env ++ lib.attrNames config.envDefault));
      };
      sync.files =
        lib.mapAttrs (_: file: {
          sources = mkDefault [file.path];
          destinationPath = mkDefault file.relPath;
        })
        generated;
      # Derive the reverse mapping from final sync entries, including overridden paths.
      snapshot.files =
        lib.mapAttrs (_: entry: {
          enable = mkDefault entry.enable;
          sources = mkDefault [
            {
              path = destination entry;
              inherit (entry) format;
            }
          ];
          destinationPath = mkDefault entry.destinationPath;
          format = mkDefault entry.format;
          directory = mkDefault entry.directory;
        })
        config.sync.files;
    }
    (lib.mkIf config.sync.enable {
      constructFiles._syncSnapSync = commandFile "sync";
      runShell = [
        {
          name = "SYNC_SNAP";
          before = ["NIX_RUN_MAIN_PACKAGE"];
          data =
            if config.wrapperImplementation != "nix"
            then throw "sync-snap addon requires wrapperImplementation = nix for its startup hook"
            else ''${invocation "sync"} --startup || echo 'sync-snap: sync failed; launching anyway' >&2'';
        }
      ];
    })
    (lib.mkIf config.snapshot.enable {
      constructFiles._syncSnapSnapshot = commandFile "snapshot";
    })
  ];
}
