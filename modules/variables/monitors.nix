{
  # Common variables used across modules and hosts.
  # Each configuration should set these variables accordingly.
  flake.modules.generic.variables = {lib, ...}: let
    inherit (lib) mkOption types;
  in {
    options.vars.monitors = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          primary = mkOption {
            type = types.bool;
            default = false;
          };

          width = mkOption {
            type = types.int;
            example = 1920;
          };

          height = mkOption {
            type = types.int;
            example = 1080;
          };

          refreshRate = mkOption {
            type = types.float;
            default = 60;
          };

          x = mkOption {
            type = types.int;
            default = 0;
          };

          y = mkOption {
            type = types.int;
            default = 0;
          };

          serial = mkOption {
            type = types.str;
            default = "";
          };

          replicaOf = mkOption {
            type = types.str;
            default = "";
            description = "If set, this monitor will mirror the monitor specified by this key.";
          };

          enabled = mkOption {
            type = types.bool;
            default = true;
          };
        };
      });
      default = {};
    };
  };
}
