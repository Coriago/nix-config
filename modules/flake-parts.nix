# This is config for flake-parts.
{inputs, ...}: {
  # Flake parts addon modules
  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.home-manager.flakeModules.home-manager
    inputs.agenix-rekey.flakeModule
  ];

  # Debug for better intellisense
  debug = true;

  # Supported systems
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  # agenix-rekey configuration
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    # agenix-rekey.nixosConfigurations = inputs.self.nixosConfigurations;

    # Devshells
    devShells.default = pkgs.mkShell {
      nativeBuildInputs = [
        pkgs.age
        pkgs.disko
        config.agenix-rekey.package
      ];
      env.AGENIX_REKEY_ADD_TO_GIT = true;
    };
  };
}
