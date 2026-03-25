{pkgs ? import <nixpkgs> {}}: let
  fromYAML = path:
    builtins.fromJSON (
      builtins.readFile (
        pkgs.runCommand "from-yaml.json" {
          nativeBuildInputs = [pkgs.yq-go];
        } "yq ea '[.]' ${path} -o=json > $out"
      )
    );

  result = fromYAML ./modules/self-hosting/longhorn.yaml;
in
  # This returns the result so the CLI can "print" it
  result
