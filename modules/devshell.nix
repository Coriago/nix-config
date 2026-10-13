# Devshell for repo tools
{
  perSystem = {
    pkgs,
    ...
  }: {
    # Devshells
    devShells.default = pkgs.mkShell {
      nativeBuildInputs = with pkgs; [
        age
        disko
        sops
        nixd
        just
      ];
    };
  };
}
