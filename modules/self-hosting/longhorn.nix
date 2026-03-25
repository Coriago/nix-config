{
  flake.modules.nixos.self-hosting = {
    pkgs,
    config,
    ...
  }: let
    image = pkgs.dockerTools.pullImage {
      imageName = "postgres";
      imageDigest = "sha256:c635fa3e3b7421a659d34abdfd6d492f679cbe8149e261a501237b55c5a94212";
      hash = "sha256-xVc6v9GDce3LbyRVDBc03pBJoNyXLo/eGcJQ3OODvGE=";
      finalImageTag = "15";
      arch = "arm64";
    };

    fromYAML = path:
      builtins.fromJSON (
        builtins.readFile (
          pkgs.runCommand "from-yaml.json" {
            nativeBuildInputs = [pkgs.yq-go];
          } "yq ea '[.]' ${path} -o=json > $out"
        )
      );
  in {
    # Required for Longhorn
    environment.systemPackages = [pkgs.nfs-utils];
    services.openiscsi = {
      enable = true;
      name = "${config.networking.hostName}-initiatorhost";
    };

    # services.k3s.autoDeployCharts.hello-world.enable = false;
    # services.k3s.autoDeployCharts.longhorn.enable = false;

    networking.extraHosts = "127.0.0.1 longhorn.local";

    # Add K3s
    services.k3s = {
      images = [image];
      autoDeployCharts.hello-world.enable = false;
      autoDeployCharts.longhorn = {
        name = "longhorn";
        repo = "https://charts.longhorn.io";
        version = "1.8.1";
        hash = "sha256-cc3U1SSSb8LxWHAzSAz5d97rTfL7cDfxc+qOjm8c3CA=";
        createNamespace = true;
        targetNamespace = "longhorn-system";
        # configure the chart values like you would do in values.yaml
        values = {
        };
        extraDeploy = fromYAML ./longhorn.yaml;
      };
    };
  };
}
