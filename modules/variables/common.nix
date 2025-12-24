{
  flake.nixosModules.variables = {lib, ...}: {
    options.vars = {
      user.name = lib.mkOption {
        type = lib.types.str;
        description = "The name of the primary user.";
        default = "helios";
      };

      stateVersion = lib.mkOption {
        type = lib.types.str;
        description = "The state version of the system.";
        default = "25.05";
      };
    };
  };
}
