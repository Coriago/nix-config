# Top level flake parts config
{inputs, ...}: {
  imports = [
    # https://flake.parts/options/flake-parts-modules.html
    # inputs.flake-parts.flakeModules.modules
    inputs.home-manager.flakeModules.home-manager
  ];
  debug = true;
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
}
