{inputs, ...}: {
  # Typical nix configuration
  flake.modules.nixos.basic = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      inputs.determinate.nixosModules.default
    ];

    nixpkgs.config.allowUnfree = true;
    nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];
    nix.settings = {
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "${config.vars.user.name}" "@wheel"];
      substituters = [
        "https://cache.nixos.org?priority=10"
        "https://nix-community.cachix.org"
        "https://numtide.cachix.org"
        "https://nixos-raspberrypi.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
        "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      ];
    };

    security.sudo.extraRules = [
      {
        users = [config.vars.user.name];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    programs.nix-ld.enable = true;

    environment.systemPackages = with pkgs; [
      # Nix tooling
      nil
      nixd
      statix
      alejandra
    ];
  };
}
