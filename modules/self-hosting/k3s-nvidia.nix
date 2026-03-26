{self, ...}: {
  flake.modules.nixos.self-hosting = {...}: {
    # Add K3s
    services.k3s = {
      manifests = self.mylib.fromYAML ./nvidia.yaml;
    };
  };
}
