{
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
    connect-timeout = 5;
  };

  # Declares flake inputs
  inputs = {
    # Primary
    ################################
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Secrets Management
    ################################
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # Secondary
    ################################
    nixos-cli.url = "github:nix-community/nixos-cli"; # Better cli for nixos
    import-tree.url = "github:vic/import-tree"; # Recursive import of nix files in a directory
    nix-flatpak.url = "github:gmodena/nix-flatpak"; # Flatpak app management
    stylix.url = "github:nix-community/stylix"; # Styling for desktop
    plasma-manager = {
      url = "github:nix-community/plasma-manager"; # More options for managing plasma desktop
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # RPI
    ################################
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main"; # RPI Support
    disko = {
      url = "github:nix-community/disko"; # Disk management tool
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
    home-manager-rpi = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixos-raspberrypi/nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
