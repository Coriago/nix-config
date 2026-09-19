{
  flake.modules.nixos.development = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      rustc
      cargo
      rust-analyzer
    ];
  };
}
