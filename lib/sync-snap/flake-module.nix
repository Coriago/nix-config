# Assign export directory names without constructing snapshot flake apps.
{lib, ...}: {
  perSystem = {...}: {
    options.packages = lib.mkOption {
      apply = lib.mapAttrs (name: package:
        if package ? configuration && package.configuration ? snapshot
        then package.wrap {snapshot.name = lib.mkDefault name;}
        else package);
    };
  };
}
