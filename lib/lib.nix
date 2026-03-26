{
  inputs,
  lib,
}: {
  # Convert a YAML file to a Nix value.
  # Usage: lib.my.fromYAML pkgs ./file.yaml
  fromYAML = pkgs: path:
    builtins.fromJSON (
      builtins.readFile (
        pkgs.runCommand "from-yaml.json" {
          nativeBuildInputs = [pkgs.yq-go];
        } "yq ea '[.]' ${path} -o=json > $out"
      )
    );
}
