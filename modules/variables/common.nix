{
  # Common variables used across modules and hosts.
  # Each configuration should set these variables accordingly.
  flake.modules.generic.variables = {lib, ...}: {
    options.vars = {
      username = lib.mkOption {
        type = lib.types.str;
        description = "The name of the primary user.";
      };

      stateVersion = lib.mkOption {
        type = lib.types.str;
        description = "The state version of the system.";
      };

      timeZone = lib.mkOption {
        type = lib.types.str;
        description = "The time zone for the system.";
        default = "America/New_York";
      };

      locale = lib.mkOption {
        type = lib.types.str;
        description = "The locale for the system.";
        default = "en_US.UTF-8";
      };
    };
  };
}
