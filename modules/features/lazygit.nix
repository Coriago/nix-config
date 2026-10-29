{
  config,
  self,
  ...
}: let
  local = config;
in {
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: {
    packages.mylazygit = local.flake.wrappers.lazygit.wrap {
      inherit pkgs;
      configDir = "\${XDG_CONFIG_HOME}/synclazygit";
      runtimePkgs = [pkgs.delta];
      # YAML snapshots cannot be pruned or automatically merged by sync-snap.
      snapshot.enable = false;
      settings = {
        gui.showNumstatInFilesView = true;
        git.diffRenderers = [
          {command = "delta --{{colorScheme}} --paging=never";}
        ];
      };
    };
    apps.mylazygit = {
      type = "app";
      program = lib.getExe self'.packages.mylazygit;
    };
  };

  flake.modules.nixos.lazygit = {pkgs, ...}: {
    environment.systemPackages = [self.packages.${pkgs.stdenv.hostPlatform.system}.mylazygit];
  };
}
