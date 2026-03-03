{
  # Declares flake inputs
  inputs = {
    # Primary
    ################################
    nixpkgs.url = "github:nixos/nixpkgs/d96e0ef24ca99ed535f54a5d4a31e94419bdfc82"; # nixos-unstable as of 2026-02-05
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
