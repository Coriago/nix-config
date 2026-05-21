# This is config for flake-parts.
{
  inputs,
  lib,
  ...
}: {
  # Flake parts addon modules
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.flake-parts.flakeModules.easyOverlay
    inputs.home-manager.flakeModules.home-manager
    # inputs.clan-core.flakeModules.default
  ];

  # Debug for better intellisense
  debug = true;

  # Supported systems
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  perSystem = {
    pkgs,
    system,
    ...
  }: {
    # Devshells
    devShells.default = pkgs.mkShell {
      nativeBuildInputs = with pkgs;
        [
          age
          disko
          sops
          nixd
        ];
    };

    # ++ [inputs.clan-core.packages.${system}.clan-cli];
  };
}
