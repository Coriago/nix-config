{
  config,
  lib,
  self,
  ...
}: {
  options.liveConfig = {
    enable = lib.mkEnableOption "runtime config symlinks into the local checkout";
    root = lib.mkOption {
      type = lib.types.str;
      description = "Absolute checkout path on the machine running the wrappers.";
    };
  };

  config.liveConfig = {
    enable = true;
    # Keep this a string: a Nix path literal would be copied into the store.
    root = "/home/helios/.config/nix-config";
  };

  # Only the symlink is built in the sandbox. Its target is read by the
  # application on the host at runtime.
  config.perSystem = {
    pkgs,
    lib,
    ...
  }: let
    inherit (config.liveConfig) enable root;
    sourceRoot = toString self.outPath + "/";
    link = path:
      if !enable
      then path
      else let
        source = toString path;
        relative = builtins.unsafeDiscardStringContext (lib.removePrefix sourceRoot source);
        target = lib.removeSuffix "/" root + "/" + relative;
      in
        assert lib.assertMsg (lib.hasPrefix "/" root) "liveConfig.root must be an absolute checkout path";
        assert lib.assertMsg (lib.hasPrefix sourceRoot source) "liveConfig.link requires a path inside this flake";
          pkgs.runCommand "live-config-${builtins.baseNameOf path}" {} ''
            ln -s ${lib.escapeShellArg target} "$out"
          '';
  in {
    _module.args.liveConfig = {
      inherit link;
    };
  };
}
