{lib, config, options, ...}: let
  hostMetaType = lib.types.submodule ({name, ...}: {
    freeformType = lib.types.lazyAttrsOf lib.types.anything;
    options.hostname = lib.mkOption {
      type = lib.types.str;
      default = name;
    };
  });
  # Include host schema extensions declared by the consuming flake.
  mergedHostMetaType = (options.meta.type.getSubOptions []).hosts.type.nestedTypes.elemType;
in {
  options.meta = lib.mkOption {
    description = "Shared flake metadata.";
    default = {};
    type = lib.types.submodule {
      freeformType = lib.types.lazyAttrsOf lib.types.anything;
      options.hosts = lib.mkOption {
        default = {};
        type = lib.types.lazyAttrsOf hostMetaType;
      };
    };
  };

  config = {
    _module.args.meta = config.meta;
    flake.modules.generic.meta = {config, ...}: {
      options.hostmeta = lib.mkOption {
        type = mergedHostMetaType;
      };
      config._module.args.hostmeta = config.hostmeta;
    };
  };
}
