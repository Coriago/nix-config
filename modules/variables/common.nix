{
  # Common variables used across modules and hosts.
  # Each configuration should set these variables accordingly.
  flake.modules.generic.variables = {lib, ...}: let
    inherit (lib) mkOption types;
  in {
    options.vars = {
      username = mkOption {
        type = types.str;
        description = "The name of the primary user.";
      };

      stateVersion = mkOption {
        type = types.str;
        description = "The state version of the system.";
      };

      timeZone = mkOption {
        type = types.str;
        description = "The time zone for the system.";
        default = "America/New_York";
      };

      locale = mkOption {
        type = types.str;
        description = "The locale for the system.";
        default = "en_US.UTF-8";
      };

      email = mkOption {
        type = types.str;
        description = "The email address of the primary user.";
      };

      keyLayout = mkOption {
        type = types.str;
        description = "The country keyboard layout.";
        default = "us";
      };
    };
  };
}
