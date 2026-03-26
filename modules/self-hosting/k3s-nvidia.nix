{
  flake.modules.nixos.self-hosting = {lib, ...}: {
    # Add K3s
    services.k3s = {
      manifests = lib.fromYAML ./nvidia.yaml;
    };
  };
}
