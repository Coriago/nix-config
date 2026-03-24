{
  flake.modules.nixos.self-hosting = {
    pkgs,
    config,
    ...
  }: let
    image = pkgs.dockerTools.pullImage {
      imageName = "nginx";
      imageDigest = "sha256:b3c656d55d7ad751196f21b7fd2e8d4da9cb430e32f646adcf92441b72f82b14";
      hash = "sha256-qrQIBp2EbKw3Aicu424rbu26v2T1LZgHVQ+hJKKZQxE=";
      finalImageTag = "1.29.3-alpine";
      arch = "amd64";
    };
  in {
    services.k3s = {
      # images = [image];
      autoDeployCharts.kyverno = {
        name = "kyverno";
        repo = "https://kyverno.github.io/kyverno/";
        version = "3.7.1";
        hash = "sha256-cc3U1SSSb8LxWHAzSAz5d97rTfL7cDfxc+qOjm8c3CA=";
        createNamespace = true;
        targetNamespace = "kyverno";
        # values = {};
      };
    };
  };
}
