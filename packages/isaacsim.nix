{
  pkgs,
  fetchurl,
  python312Packages,
  buildFHSEnv,
}: let
  # Build derivation: Downloads and installs the Isaac Sim Python wheel
  isaacsim = python312Packages.buildPythonPackage rec {
    pname = "isaacsim";
    version = "6.0.0.0";
    format = "wheel";

    src = fetchurl {
      url = "https://pypi.nvidia.com/${pname}/${pname}-${version}-cp312-none-manylinux_2_35_x86_64.whl";
      hash = "sha256-OQUqkLpZKMl0ULZxq3Ty8lGU168f3suNmwAio/rzeHU=";
    };

    propagatedBuildInputs = with python312Packages; [
      requests
    ];

    # Disable Python runtime dependency checking — Isaac Sim wheels declare
    # many deps (isaacsim-kernel, etc.) that aren't in nixpkgs
    dontCheckRuntimeDeps = true;

    # Manylinux wheels contain precompiled binaries that need patching
    # for Nix store paths. Uncomment when moving past download to runtime:
    # nativeBuildInputs = with pkgs; [
    #   autoPatchelfHook
    # ];
    # buildInputs = with pkgs; [
    #   stdenv.cc.cc.lib
    # ];

    meta = {
      description = "NVIDIA Isaac Sim robotics simulation platform";
      homepage = "https://developer.nvidia.com/isaac-sim";
      # license = pkgs.lib.licenses.unfree;
      license = pkgs.lib.licenses.agpl3Only;
      platforms = ["x86_64-linux"];
    };
  };

  # FHS derivation: Wraps Isaac Sim in a filesystem hierarchy standard environment
  # This is useful for binaries that expect a traditional Linux filesystem layout
  isaacsim-fhs = buildFHSEnv {
    name = "isaacsim-fhs";

    targetPkgs = pkgs: [
      (pkgs.python312.withPackages (_: [isaacsim]))
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
    ];

    runScript = "bash";
  };
in {
  inherit isaacsim isaacsim-fhs;
}
