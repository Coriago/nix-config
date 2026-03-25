{
  flake.modules.nixos.self-hosting = {
    pkgs,
    config,
    ...
  }: {
    services.k3s = {
      # images = [image];
      autoDeployCharts.kyverno = {
        name = "kyverno";
        repo = "https://kyverno.github.io/kyverno/";
        version = "3.7.1";
        hash = "sha256-sNdFEupwfnYSo2iGqKwTadPtXfcbyM1kuisavpiGUyU=";
        createNamespace = true;
        targetNamespace = "kyverno";
        # values = {};
      };
    };
  };
}
