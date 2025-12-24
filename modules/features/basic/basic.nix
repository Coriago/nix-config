{self, ...}: {
  # Bundle of basic modules and settings
  flake.nixosModules.basic = {config, ...}: {
    imports = [
      self.nixosModules.nix
      self.nixosModules.home-manager
    ];

    users.users.${config.variables.user.name} = {
      isNormalUser = true;
    };
  };
}
