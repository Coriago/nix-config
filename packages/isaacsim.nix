{
  pkgs ? import <nixpkgs> {},
  fetchurl,
  buildPythonPackage,
}: let
  # 1. Define the Python Package derivation
  # Replace values with your actual package details
  myPythonPackage = buildPythonPackage rec {
    pname = "isaacsim";
    version = "6.0.0.0";
    format = "wheel"; # change to "pyproject" if using pyproject.toml

    # src = pkgs.fetchPypi {
    #   inherit pname version;
    #   hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Provide actual hash
    # };

    src = fetchurl {
      url = "https://pypi.nvidia.com/${pname}/${pname}-${version}-cp312-none-manylinux_2_35_x86_64.whl";
      hash = "sha256-YzlFj3Bd8nlPsbvqaspzmlG/bIBLGGSP5BN6mbEWheM=";
    };

    # Dependencies required for this python package
    propagatedBuildInputs = with pkgs.python3.pkgs; [
      requests
    ];

    meta = {
      description = "A custom Python package downloaded via Nix";
    };
  };

  # Combine our package into a custom Python interpreter environment
  myPythonEnv = pkgs.python312.withPackages (ps: [
    myPythonPackage
  ]);
in
  # 2. Wrap the Python environment inside an FHS sandbox
  pkgs.buildFHSEnv {
    name = "my-python-fhs-wrapper";

    # targetPkgs populates /lib, /bin, etc. inside the sandbox
    targetPkgs = pkgs: [
      myPythonEnv # Drops our python interpretter with our package into /bin
      pkgs.stdenv.cc.cc.lib # Often useful for packages needing standard C libraries (glibc)
      pkgs.zlib # Common native dependency
    ];

    # The exact script/command that runs when the wrapper is executed
    # "bash" opens an interactive shell. To execute a script directly, use "python3 script.py"
    runScript = "bash";
  }
