{
  flake.modules.nixos.noctalia-greeter = {lib, pkgs, ...}: {
    services.greetd = {
      enable = true;
      settings.default_session.command = lib.getExe pkgs.noctalia-greeter;
    };
  };
}
