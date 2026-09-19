{
  # Optimizations for building and caching packages.
  flake.modules.nixos.nix-builds = {config, ...}: {
    sops.secrets.nix_sigining_key = {};
    nix.extraOptions = ''
      builders-use-substitutes = true
      secret-key-files = ${config.sops.secrets.nix_sigining_key.path}
    '';
    documentation.enable = false;
    # nix.distributedBuilds = true;
    # nix.buildMachines = [
    #   {
    #     hostName = "localhost";
    #     systems = ["x86_64-linux" "aarch64-linux"];
    #     sshUser = "root";
    #     maxJobs = 8; # Number of local cores
    #     speedFactor = 50; # Much higher than the remote
    #     protocol = "ssh-ng";
    #     supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    #   }
    #   {
    #     hostName = "192.168.8.104";
    #     systems = ["aarch64-linux"];
    #     sshUser = "root";
    #     maxJobs = 2;
    #     speedFactor = 1;
    #     protocol = "ssh-ng";
    #     supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    #   }
    # ];
  };
}
