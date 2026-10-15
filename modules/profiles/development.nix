{
  config,
  inputs,
  ...
}: {
  flake.modules.nixos.development = {pkgs, ...}: {
    imports = with config.flake.modules.nixos; [
      direnv
      neovim
      pi-agent
    ];

    environment.systemPackages = with pkgs; [
      nixd
      statix
      alejandra
      nvd
      nix-diff
      nix-inspect
      nix-output-monitor

      gh
      fzf
      bubblewrap
      lazygit
      herdr

      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    ];
  };
}
