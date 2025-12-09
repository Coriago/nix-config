{
  # https://github.com/anotherhadi/nixy
  description = ''
    Nixy simplifies and unifies the Hyprland ecosystem with a modular, easily customizable setup.
    It provides a structured way to manage your system configuration and dotfiles with minimal effort.
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    # hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    # hyprpanel.url = "github:Jas-SinghFSU/HyprPanel";
    stylix.url = "github:danth/stylix";
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    nixcord.url = "github:kaylorben/nixcord";
    # sops-nix.url = "github:Mic92/sops-nix";
    nixarr.url = "github:rasmus-kirk/nixarr";
    nvf.url = "github:notashelf/nvf";
    # vicinae.url = "github:vicinaehq/vicinae";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    eleakxir.url = "github:anotherhadi/eleakxir";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs = inputs @ {
    nixpkgs,
    nix-flatpak,
    ...
  }: let
    # Overlay to use gamescope from git master
    # Fetch gamescope from GitHub master branch
    gamescope-overlay = final: prev: {
      gamescope = prev.gamescope.overrideAttrs (oldAttrs: {
        # Fetch gamescope from GitHub with the specific commit
        src = prev.fetchFromGitHub {
          owner = "ValveSoftware";
          repo = "gamescope";
          # rev = "f980684487ab1849d0f02d8952831725d0825541";
          rev = "9416ca9334da7ff707359e5f6aa65dcfff66aa01";
          fetchSubmodules = true;
          # hash = "sha256-VTeJO47cEFc9T89PMYEI0AaSJV1HUY8RWX5H5kVksx0=";
          hash = "sha256-bZXyNmhLG1ZcD9nNKG/BElp6I57GAwMSqAELu2IZnqA=";
        };
        version = "git-9416ca9";
      });
    };
  in {
    nixosConfigurations = {
      heliosdesk = nixpkgs.lib.nixosSystem {
        modules = [
          {
            nixpkgs.overlays = [gamescope-overlay];
            _module.args = {
              inherit inputs;
            };
          }
          inputs.home-manager.nixosModules.home-manager
          inputs.stylix.nixosModules.stylix
          inputs.nix-flatpak.nixosModules.nix-flatpak
          ./hosts/heliosdesk/configuration.nix
        ];
      };
      # jack = nixpkgs.lib.nixosSystem {
      #   modules = [
      #     {_module.args = {inherit inputs;};}
      #     inputs.home-manager.nixosModules.home-manager
      #     inputs.stylix.nixosModules.stylix
      #     inputs.sops-nix.nixosModules.sops
      #     inputs.nixarr.nixosModules.default
      #     inputs.eleakxir.nixosModules.eleakxir
      #     ./hosts/server/configuration.nix
      #   ];
      # };
    };
  };
}
