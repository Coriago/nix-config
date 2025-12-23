{inputs, ...}: {
  imports = [
    # https://flake.parts/options/flake-parts-modules.html
    # inputs.flake-parts.flakeModules.modules
  ];
  debug = true;
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
}
