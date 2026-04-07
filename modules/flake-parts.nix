# This is config for flake-parts.
{inputs, ...}: {
  # Flake parts addon modules
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.flake-parts.flakeModules.easyOverlay
    inputs.home-manager.flakeModules.home-manager
  ];

  # Debug for better intellisense
  debug = true;

  # Supported systems
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  perSystem = {pkgs, ...}: {
    # Devshells
    devShells.default = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        age
        disko
        sops
      ];
    };
  };
}
