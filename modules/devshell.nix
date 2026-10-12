{
  perSystem = {
    pkgs,
    system,
    ...
  }: {
    # Devshells
    devShells.default = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        age
        disko
        sops
        nixd
      ];
    };
  };
}
