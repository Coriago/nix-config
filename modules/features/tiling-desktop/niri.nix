{
  inputs,
  self,
  ...
}: {
  perSystem = {
    lib,
    pkgs,
    self',
    ...
  }: {
    packages.myniri = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      settings = {
        spawn-at-startup = [
          (lib.getExe self'.packages.mynoctalia)
        ];

        binds = {
          "Mod+Return".spawn-sh = lib.getExe pkgs.ghostty;
          "Mod+Q".close-window = _: {};
          "Mod+S".spawn-sh = "${lib.getExe self'.packages.mynoctalia} ipc call launcher toggle";
        };
      };
    };
  };

  flake.modules.nixos.niri = {lib, pkgs, ...}: {
    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.myniri;
    };

    services.displayManager.defaultSession = lib.mkForce "niri";
    services.gnome.gnome-keyring.enable = lib.mkForce false;
  };
}
