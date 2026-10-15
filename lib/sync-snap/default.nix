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
  syncFileType = types.submodule (args @ {name, ...}: let
    entry = args.config;
  in {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Include this file in sync.";
      };
      sources = mkOption {
        type = types.listOf sourceType;
        default = [];
        description = "Ordered sources, later values win. Override generated defaults with an ordinary assignment.";
      };
      destinationDir = mkOption {
        type = types.str;
        default = config.sync.defaultDir;
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
      policy = mkOption {
        type = types.enum ["seed" "fill-missing" "merge" "replace"];
        default = "merge";
        description = "How the baseline updates existing runtime contents. Raw files require seed or replace.";
      };
      trigger = mkOption {
        type = types.enum ["onInputsChanged" "onEveryStart" "onEveryBoot" "onEveryLogin" "onDuration"];
        default = "onInputsChanged";
        description = "Automatic sync trigger; by default, preserve runtime edits until declarative inputs change. Manual sync ignores it.";
      };
      duration = mkOption {
        type = types.nullOr (types.strMatching "[1-9][0-9]*(s|m|min|h|hr|d)");
        default = null;
        example = "1h";
        description = "Interval for onDuration, such as 30m or 1hr. Required only for onDuration.";
      };
    };
  });
  snapshotFileType = types.submodule (args @ {name, ...}: let
    entry = args.config;
  in {
    options = {
      content = mkOption {
        type = types.either (types.attrsOf types.anything) (types.listOf types.anything);
        readOnly = true;
        default = (savedSnapshot name).content;
        description = "Parsed saved JSON/TOML at snapshot.sourceDir/destinationPath, before declared settings. Empty attribute set for missing files, raw files, or directories. Independent of export and autoMerge flags; never reads live runtime files.";
      };
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Include this file in snapshot export.";
      };
      sources = mkOption {
        type = types.listOf sourceType;
        default = [];
        description = "Ordered sources, later values win. Override generated defaults with an ordinary assignment.";
      };
      destinationDir = mkOption {
        type = types.str;
        default = config.snapshot.defaultDir;
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
      autoMerge = mkOption {
        type = types.bool;
        default = true;
        description = "Import this snapshot as a baseline when snapshot.autoMerge is also enabled. Does not disable export.";
      };
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
    };
  });
  destination = entry: "${lib.removeSuffix "/" entry.destinationDir}/${entry.destinationPath}";
  sourceArgs = value:
    if builtins.isString value
    then ["--source" value]
    else
      ["--source" value.path]
      ++ lib.optionals (value.format != null) ["--source-format" value.format]
      ++ lib.optionals value.optional ["--source-optional" "true"];
  fileArgs = entry:
    ["--destination" (destination entry)]
    ++ lib.concatMap sourceArgs entry.sources
    ++ lib.optionals (entry.format != null) ["--format" entry.format]
    ++ lib.optionals entry.directory ["--directory" "true"];
  syncArgs = entry:
    if (entry.trigger == "onDuration") != (entry.duration != null)
    then throw "sync-snap: duration must be supplied exactly when trigger is onDuration"
    else
      fileArgs entry
      ++ ["--policy" entry.policy "--trigger" entry.trigger]
      ++ lib.optionals (entry.duration != null) ["--duration" entry.duration];
  snapshotArgs = entry:
    fileArgs entry
    ++ lib.concatMap (v: ["--prune-key-contains" v]) entry.pruneKeyContains
    ++ lib.concatMap (v: ["--prune-value-contains" v]) entry.pruneValueContains
    ++ lib.concatMap (v: ["--transform" v]) entry.transform;
  # Internal helper commands are not application configuration.
  generated = lib.filterAttrs (name: _: !(lib.hasPrefix "_syncSnap" name)) config.constructFiles;
  savedSnapshot = name: let
    entry = config.snapshot.files.${name};
    source = "${config.snapshot.sourceDir}/${entry.destinationPath}";
    format =
      if entry.format != null
      then entry.format
      else if lib.hasSuffix ".json" source
      then "json"
      else if lib.hasSuffix ".toml" source
      then "toml"
      else "raw";
    contents = builtins.readFile source;
    parsed =
      if format == "json"
      then builtins.fromJSON contents
      else builtins.fromTOML contents;
    available = !entry.directory && builtins.elem format ["json" "toml"] && builtins.pathExists source;
    content =
      if !available
      then {}
      else
        builtins.addErrorContext "while reading snapshot ${source}: " (
          builtins.deepSeq parsed (
            if builtins.isAttrs parsed || builtins.isList parsed
            then parsed
            else throw "snapshot must contain an object or array"
          )
        );
  in {inherit available content contents format;};
  snapshotSource = name: let
    entry = config.snapshot.files.${name};
    saved = savedSnapshot name;
  in
    lib.optionals (config.snapshot.autoMerge
      && entry.autoMerge
      && entry.enable
      && saved.available) [
      {
        path = builtins.deepSeq saved.content (pkgs.writeText "snapshot-${name}.${saved.format}" saved.contents);
        inherit (saved) format;
      }
    ];
  invocation = operation: entryArgs: files: let
    entries = lib.filterAttrs (_: entry: entry.enable) files;
  in
    if entries == {}
    then "${pkgs.coreutils}/bin/true"
    else
      lib.escapeShellArgs (["${lib.getExe tool}" operation "--program" config.binName]
        ++ lib.concatMap entryArgs (lib.attrValues entries));
  syncCommand = invocation "sync" syncArgs config.sync.files;
  snapshotCommand = invocation "snapshot" snapshotArgs config.snapshot.files;
  commandFile = operation: command: {
    relPath = "bin/${config.binName}-${operation}";
    content = ''
      #!${pkgs.bash}/bin/bash
      ${lib.optionalString (operation == "sync") ''
        if ! ( ${config.sync.condition} ); then
          echo 'sync-snap: sync deferred by application guard' >&2
          exit 1
        fi
      ''}
      exec ${command} "$@"
    '';
    builder = ''cp "$1" "$2" && chmod +x "$2"'';
  };
in {
  imports = [wlib.modules.default];
  options = {
    sync = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable sync for this wrapper. Importing the addon alone does not enable it.";
      };
      startupCondition = mkOption {
        type = types.lines;
        default = "true";
        description = "Shell predicate evaluated with the original application arguments. Automatic sync runs only on success; manual sync is unaffected. Adapters can exclude IPC and inspection commands.";
      };
      condition = mkOption {
        type = types.lines;
        default = "true";
        description = "Application safety predicate for both automatic and manual sync. False defers automatic sync without blocking launch, and makes manual sync fail. Snapshot is unaffected.";
      };
      defaultDir = mkOption {
        type = types.str;
        default = "\${XDG_CONFIG_HOME}/${config.binName}";
        description = "Default destination directory for sync files.";
      };
      files = mkOption {
        type = types.attrsOf syncFileType;
        default = {};
        description = "Named sync entries, processed in name order.";
      };
    };
    snapshot = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable snapshot export for this wrapper. Importing the addon alone does not enable it.";
      };
      defaultDir = mkOption {
        type = types.str;
        default = "/home/helios/.config/nix-config/snapshot/${config.snapshot.name}";
        description = "Default destination directory for snapshot files.";
      };
      files = mkOption {
        type = types.attrsOf snapshotFileType;
        default = {};
        description = "Named snapshot entries, processed in name order.";
      };
      name = mkOption {
        type = relativePath;
        default = config.binName;
        description = "Snapshot directory name. Flake integration supplies the configured package name.";
      };
      autoMerge = mkOption {
        type = types.bool;
        default = true;
        description = "Embed existing JSON/TOML snapshots as lower-priority sources for generated sync files.";
      };
      sourceDir = mkOption {
        type = pathType;
        default = "${../..}/snapshot/${config.snapshot.name}";
        description = "Evaluation-time snapshot directory in the flake source. Separate from the writable export location.";
      };
    };
  };
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
        lib.mapAttrs (name: file: {
          sources = mkDefault (snapshotSource name
            ++ [
              {
                path = file.path;
                # Generated config shares its declared format with the destination,
                # including native extensionless names such as Brave's Preferences.
                format = config.sync.files.${name}.format;
              }
            ]);
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
      constructFiles._syncSnapSync = commandFile "sync" syncCommand;
      runShell = [
        {
          name = "SYNC_SNAP";
          before = ["NIX_RUN_MAIN_PACKAGE"];
          data =
            if config.wrapperImplementation != "nix"
            then throw "sync-snap addon requires wrapperImplementation = nix for its startup hook"
            else ''
              if ( ${config.sync.startupCondition} ); then
                if ( ${config.sync.condition} ); then
                  ${syncCommand} --startup || echo 'sync-snap: sync failed; launching anyway' >&2
                else
                  echo 'sync-snap: sync deferred by application guard; launching anyway' >&2
                fi
              fi
            '';
        }
      ];
    })
    (lib.mkIf config.snapshot.enable {
      constructFiles._syncSnapSnapshot = commandFile "snapshot" snapshotCommand;
      constructFiles._syncSnapRegistration =
        (commandFile "snapshot" snapshotCommand)
        // {
          relPath =
            if builtins.match "[A-Za-z0-9][A-Za-z0-9._+-]*" config.binName == null
            then throw "snapshot registration requires a simple executable binName"
            else "share/sync-snap/snapshots/${config.binName}";
        };
    })
  ];
}
