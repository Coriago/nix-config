{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.heliosdesk = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.heliosdeskHost
    ];
  };

  flake.nixosModules.heliosdeskHost = {
    pkgs,
    lib,
    ...
  }: {
    imports = [
      self.nixosModules.base
      # self.nixosModules.basic
      # # disko
      # inputs.disko.nixosModules.disko
      # self.diskoConfigurations.hostMain
    ];
    # variables.user.name = "helios";
    # variables.stateVersion = "25.05";

    system.stateVersion = "25.05";

    boot.loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      grub.enable = lib.mkForce false;
    };
  };
}
