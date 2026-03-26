{self, ...}: {
  flake.modules.nixos.self-hosting = {pkgs, ...}: {
    # Add K3s
    services.k3s = {
      # manifests = self.mylib.fromYAML pkgs ./nvidia.yaml;
    };
  };
}
