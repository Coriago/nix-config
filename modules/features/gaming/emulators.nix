{pkgs, ...}: {
  flake.modules.nixos.gaming = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      retroarch-full
      # Citron Nintendo Switch emulator
      # (pkgs.callPackage ../../../packages/citron.nix {})
    ];
  };
}
