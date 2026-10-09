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
        exec ${pkgs.bubblewrap}/bin/bwrap --dev-bind / / \
          ${lib.concatMapStringsSep " " (entry: "--bind ${escape entry.source} ${escape entry.target}") mappings} \
          -- ${command}
      '';
  };
}
