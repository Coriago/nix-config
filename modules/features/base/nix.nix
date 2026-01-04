{inputs, ...}: {
  # Typical nix configuration
  flake.modules.nixos.base = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      inputs.nixos-cli.nixosModules.nixos-cli
    ];

    # Allow unfree packages
    nixpkgs.config.allowUnfree = true;

    # Set nix path for lsp
    nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];

    nix.settings = {
      auto-optimise-store = true;

      # Enable flakes
      experimental-features = ["nix-command" "flakes"];

      # Additional nix caches to fetch from
      trusted-users = ["root" "${config.vars.username}" "@wheel"]; # Required to allow for more caches
      substituters = [
        "https://cache.nixos.org?priority=10"
        "https://nix-community.cachix.org"
        "https://numtide.cachix.org"
        "https://nixos-raspberrypi.cachix.org"
        "https://install.determinate.systems"
        "https://watersucks.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
        "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
        "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
        "watersucks.cachix.org-1:6gadPC5R8iLWQ3EUtfu3GFrVY7X6I4Fwz/ihW25Jbv8="
      ];
    };

    # Allows nixos rebuild without password
    security.sudo.extraRules = [
      {
        users = [config.vars.username];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = ["NOPASSWD"];
          }
          {
            command = "/run/current-system/sw/bin/nixos";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    # Allow for dynamic libraries in nix
    programs.nix-ld.enable = true;

    # Nix tooling
    environment.systemPackages = with pkgs; [
      nil
      nixd
      statix
      alejandra
      nvd
      nix-diff
      nix-inspect
      nix-output-monitor
    ];

    # Nixos cli
    services.nixos-cli = {
      enable = true;
      config = {
        use_nvd = true;
        apply.use_nom = true;
        config_location = "/home/${config.vars.username}/.config/nixos";
      };
    };
  };
}
