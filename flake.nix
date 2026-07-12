{
  # Declares flake inputs
  inputs = {
    # Primary
    ################################
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    # clan-core = {
    #   url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
    #   inputs.nixpkgs.follows = "nixpkgs";
    #   inputs.flake-parts.follows = "flake-parts";
    # };

    # Secrets Management
    ################################
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secondary
    ################################
    nixos-cli.url = "github:nix-community/nixos-cli"; # Better cli for nixos
    nixos-cli.inputs.nixpkgs.follows = "nixpkgs";
    nixos-cli.inputs.flake-parts.follows = "flake-parts";
    import-tree.url = "github:vic/import-tree"; # Recursive import of nix files in a directory
    nix-flatpak.url = "github:gmodena/nix-flatpak"; # Flatpak app management
    stylix.url = "github:nix-community/stylix"; # Styling for desktop
    stylix.inputs.nixpkgs.follows = "nixpkgs";
    stylix.inputs.flake-parts.follows = "flake-parts";
    disko.url = "github:nix-community/disko"; # Disk management tool
    disko.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.url = "github:numtide/llm-agents.nix"; # LLM Agents
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.inputs.flake-parts.follows = "flake-parts";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    nix-cachyos-kernel.inputs.nixpkgs.follows = "nixpkgs";
    mcp-servers-nix.url = "github:natsukium/mcp-servers-nix";
    mcp-servers-nix.inputs.nixpkgs.follows = "nixpkgs";

    wrappers.url = "github:BirdeeHub/nix-wrapper-modules";
    wrappers.inputs.nixpkgs.follows = "nixpkgs";

    lazyvim.url = "github:pfassina/lazyvim-nix";
    lazyvim.inputs.nixpkgs.follows = "nixpkgs";

    # RPI
    ################################
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main"; # RPI Support
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree [./modules ./hosts]);
}
