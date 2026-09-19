{inputs, ...}: {
  flake.modules.nixos.base = {
    pkgs,
    config,
    ...
  }: {
    nixpkgs.config.allowUnfree = true;

    # Set nix path for lsp
    nix.nixPath = ["nixpkgs=${inputs.nixpkgs}"];

    nix.settings = {
      auto-optimise-store = true;

      # Enable flakes
      experimental-features = ["nix-command" "flakes"];

      # Additional nix caches to fetch from
      trusted-users = ["${config.hostmeta.username}" "@wheel"]; # Required to allow for more caches
      substituters = [
        "https://cache.nixos.org?priority=10"
        "https://nix-community.cachix.org"
        "https://numtide.cachix.org"
        "https://cache.numtide.com"
        "https://nixos-raspberrypi.cachix.org"
        "https://watersucks.cachix.org"
        "https://ros.cachix.org"
        "https://nixpkgs-python.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
        "watersucks.cachix.org-1:6gadPC5R8iLWQ3EUtfu3GFrVY7X6I4Fwz/ihW25Jbv8="
        "myhomelab.net:xtVVBYntb5zLFB4eUUkLIe8OpDNwvDI20i8sDehE9ck=%"
        "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
        "nixpkgs-python.cachix.org-1:hxjI7pFxTyuTHn2NkvWCrAUcNZLNS3ZAvfYNuYifcEU="
      ];
    };

    # Allows nixos rebuild without password
    security.sudo.extraRules = [
      {
        users = [config.hostmeta.username];
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

    # Nix tooling
  };
}
