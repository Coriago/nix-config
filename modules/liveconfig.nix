# This global helper module allows for an easy method to symlink configuration files into the nix store.
# By using symlinks, nixos rebuilds are not required for every update for faster iteration.
# The trade off is that this must be configured on the desired host with an absolute path to files in this repo.
{
  lib,
  self,
  ...
}: let
  mkLiveConfig = {
    enable,
    pkgs,
    root,
  }: let
    sourceRoot = toString self.outPath + "/";
    forceLink = path: let
      source = toString path;
      relative = builtins.unsafeDiscardStringContext (lib.removePrefix sourceRoot source);
      target = lib.removeSuffix "/" root + "/" + relative;
    in
      assert lib.assertMsg (lib.hasPrefix "/" root) "liveConfig.root must be an absolute checkout path";
      assert lib.assertMsg (lib.hasPrefix sourceRoot source) "liveConfig.link requires a path inside this flake";
        pkgs.runCommand "live-config-${baseNameOf path}" {} ''
          ln -s ${lib.escapeShellArg target} "$out"
        '';
    link = path:
      if !enable
      then path
      else forceLink path;
  in {
    inherit link forceLink;
  };
in {
  config.flake.modules.nixos.live-config = {
    config,
    lib,
    pkgs,
    ...
  }: {
    options.liveConfig = {
      enable = lib.mkEnableOption "runtime config symlinks into the local checkout";
      root = lib.mkOption {
        type = lib.types.str;
        description = "Absolute checkout path on the machine running the wrappers.";
      };
    };

    config._module.args.liveConfig = mkLiveConfig {
      inherit pkgs;
      inherit (config.liveConfig) enable root;
    };
  };
}
