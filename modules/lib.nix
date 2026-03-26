{...}: let
  mylib = {
    fromYAML = pkgs: path:
      builtins.fromJSON (
        builtins.readFile (
          pkgs.runCommand "from-yaml.json" {
            nativeBuildInputs = [pkgs.yq-go];
          } "yq ea '[.]' ${path} -o=json > $out"
        )
      );
  };
in {
  flake = {
    inherit mylib;
  };
}
