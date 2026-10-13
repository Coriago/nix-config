{
  # NixOS
  flake.modules.nixos.development = {
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      nixd
      statix
      alejandra
      nvd
      nix-diff
      nix-inspect
      nix-output-monitor
    ];
  };
}
