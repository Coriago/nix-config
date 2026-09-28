{inputs, ...}: {
  flake.modules.nixos.development = {
    pkgs,
    config,
    ...
  }: {
    nixpkgs.overlays = [
      inputs.llm-agents.overlays.shared-nixpkgs
    ];

    environment.systemPackages = with pkgs; [
      llm-agents.opencode
    ];
  };
}
