# Optional process-local writable directory mappings, independent of sync-snap.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}: let
  mappings = config.directoryMappings;
  escape = wlib.escapeShellArgWithEnv;
  parentDirs = config.directoryMappingParentDirs;
in {
  imports = [wlib.modules.default];

  options.directoryMappings = lib.mkOption {
    default = [];
    type = lib.types.listOf (lib.types.submodule {
      options = {
        source = lib.mkOption {
          type = lib.types.str;
          description = "Actual writable directory. Created if missing. Supports runtime shell environment expansion.";
        };
        target = lib.mkOption {
          type = lib.types.str;
          description = "Absolute directory the application sees. Its original contents are hidden in the wrapped process.";
        };
      };
    });
    description = ''
      Ordered writable directory bind mounts for the application and its children.
      Empty disables mapping. Requires Linux user namespaces and the nix wrapper
      implementation. This changes filesystem layout, not application permissions.
    '';
  };

  options.directoryMappingParentDirs = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = ''
      Parent directories to recreate in process-local tmpfs before applying
      mappings, in parent-before-child order. Existing immediate children are
      bound back, except children recreated here or replaced by a mapping.
      Symlinks are preserved. Allows missing targets beneath root-owned paths
      without writing to the host. Supports shell environment expansion.
      Changes to the recreated directory entries do not persist.
    '';
  };

  config = lib.mkIf (mappings != []) {
    # The upstream function receives the complete command, including flags/argv.
    # Environment setup and sync-snap's startup hook run before this entry.
    argv0type = command:
      if config.wrapperImplementation != "nix" || !pkgs.stdenv.hostPlatform.isLinux
      then throw "directoryMappings requires Linux and wrapperImplementation = nix"
      else ''
        ${lib.concatMapStringsSep "\n" (entry: ''
            mapping_source=${escape entry.source}
            mapping_target=${escape entry.target}
            if [[ "$mapping_source" != /* || "$mapping_target" != /* ]]; then
              echo 'directoryMappings: source and target must expand to absolute paths' >&2
              exit 1
            fi
            ${pkgs.coreutils}/bin/mkdir -p -- "$mapping_source" || exit 1
            if [[ ! -d "$mapping_source" ]]; then
              echo 'directoryMappings: source must be a directory' >&2
              exit 1
            fi
          '')
          mappings}
        ${lib.optionalString (parentDirs != []) ''
          mapping_parent_args=()
          mapping_replaced_paths=(${lib.concatMapStringsSep " " escape (parentDirs ++ map (entry: entry.target) mappings)})
          shopt -s nullglob dotglob
          for mapping_parent in ${lib.concatMapStringsSep " " escape parentDirs}; do
            if [[ "$mapping_parent" != /* || "$mapping_parent" == / ]]; then
              echo 'directoryMappings: parent directories must be absolute and cannot be /' >&2
              exit 1
            fi
            mapping_parent_args+=(--tmpfs "$mapping_parent")
            for mapping_child in "$mapping_parent"/*; do
              mapping_skip=false
              for mapping_replaced in "''${mapping_replaced_paths[@]}"; do
                if [[ "$mapping_child" == "$mapping_replaced" ]]; then
                  mapping_skip=true
                  break
                fi
              done
              if "$mapping_skip"; then continue; fi
              if [[ -L "$mapping_child" ]]; then
                mapping_parent_args+=(--symlink "$( ${pkgs.coreutils}/bin/readlink -- "$mapping_child" )" "$mapping_child")
              else
                mapping_parent_args+=(--dev-bind "$mapping_child" "$mapping_child")
              fi
            done
          done
          shopt -u nullglob dotglob
        ''}
        exec ${pkgs.bubblewrap}/bin/bwrap --dev-bind / / \
          ${lib.optionalString (parentDirs != []) ''"''${mapping_parent_args[@]}" ''}${lib.concatMapStringsSep " " (entry: "--bind ${escape entry.source} ${escape entry.target}") mappings} \
          -- ${command}
      '';
  };
}
