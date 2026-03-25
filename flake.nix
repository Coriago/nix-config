{
  # Declares flake inputs
  inputs = {
    # Primary
    ################################
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; # nixos-unstable as of 2026-02-05
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
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secondary
    ################################
    nixos-cli.url = "github:nix-community/nixos-cli"; # Better cli for nixos
    import-tree.url = "github:vic/import-tree"; # Recursive import of nix files in a directory
    nix-flatpak.url = "github:gmodena/nix-flatpak"; # Flatpak app management
    stylix.url = "github:nix-community/stylix"; # Styling for desktop
    disko = {
      url = "github:nix-community/disko"; # Disk management tool
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # RPI
    ################################
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main"; # RPI Support
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree [./modules ./hosts]);
}
