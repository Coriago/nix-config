{
  flake.modules.nixos.desktop = {...}: {
    security.rtkit.enable = true;
  };
}
