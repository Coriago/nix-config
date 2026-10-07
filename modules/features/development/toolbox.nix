{inputs, ...}: {
  flake.modules.nixos.development = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      gh
      fzf
      bubblewrap
      lazygit

      herdr
      # TODO: Do not keep here, just for testing out codex vs pi
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    ];
  };
}
