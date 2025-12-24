{inputs, ...}: {
  # Typical nix configuration
  flake.nixosModules.basic = {
    pkgs,
    config,
    ...
  }: {
    # imports = [
    #   inputs.nix-index-database.nixosModules.nix-index
    #   inputs.determinate.nixosModules.default
    # ];
    # programs.nix-index-database.comma.enable = true;

    nix.settings = {
      auto-optimise-store = true;
      experimental-features = ["nix-command" "flakes"];
      trusted-users = ["root" "${config.vars.user.name}" "@wheel"];
    };

    programs.nix-ld.enable = true;
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      # Nix tooling
      nil
      nixd
      statix
      alejandra
    ];
  };
}
