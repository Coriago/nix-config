{
  config,
  inputs,
  ...
}: {
  flake.modules.nixos.development = {pkgs, ...}: {
    imports = with config.flake.modules.nixos; [
      direnv
      neovim
      lazygit
      pi-agent
    ];

    environment.systemPackages = with pkgs; [
      # nix
      nixd
      statix
      alejandra
      nvd
      nix-diff
      nix-inspect
      nix-output-monitor

      # general
      gh
      fzf
      bubblewrap
      herdr

      # python
      python314
      uv

      # Go
      go

      # JS
      nodejs-slim


      # inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    ];
  };
}
