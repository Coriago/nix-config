{
  # Declares flake inputs
  inputs = {
    # Primary
    ################################
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # Secondary
    ################################
    nixos-cli.url = "github:nix-community/nixos-cli"; # Better cli for nixos
    import-tree.url = "github:vic/import-tree"; # Recursive import of nix files in a directory
    nix-flatpak.url = "github:gmodena/nix-flatpak"; # Flatpak app management
    stylix.url = "github:nix-community/stylix/release-25.11"; # Styling for desktop
    plasma-manager = {
      url = "github:nix-community/plasma-manager"; # More options for managing plasma desktop
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
