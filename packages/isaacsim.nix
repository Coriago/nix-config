{
  pkgs ? import <nixpkgs> {},
  rosDistro ? "jazzy",
  rmwImplementation ? "rmw_fastrtps_cpp",
}: let
  pname = "isaacsim";
  version = "5.1.0";

  unwrapped = pkgs.stdenv.mkDerivation {
    pname = "${pname}-unwrapped";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://downloads.isaacsim.nvidia.com/isaac-sim-standalone-${version}-linux-x86_64.zip";
      sha256 = "sha256-arAQknjEhotteW1eQ1oBFodM1Qo5Lt+nzDNQ3r+3oYc=";
    };
    dontBuild = true;
    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;
    nativeBuildInputs = [pkgs.unzip];
    unpackPhase =
      # bash
      ''
        runHook preUnpack

        unzip -q "$src" -d isaacsim_src
        shopt -s nullglob
        dirs=(isaacsim_src/*/);
        if [ ''${#dirs[@]} -eq 1 ]; then
          mv "''${dirs[0]}" isaac-sim
        else
          mv isaacsim_src isaac-sim
        fi

        runHook postUnpack
      '';

    installPhase =
      # bash
      ''
        runHook preInstall

        mkdir -p "$out/opt/isaacsim"
        cp -r isaac-sim/* "$out/opt/isaacsim/"
        mkdir -p "$out/opt/isaacsim/extscache"

        runHook postInstall
      '';
  };
  isaac = "${unwrapped}/opt/isaacsim";
  rosBridgePrefix = "${isaac}/exts/isaacsim.ros2.bridge/${rosDistro}";

  launcher = pkgs.writeShellScript "${pname}-launcher" ''
    export ROS_DISTRO=${rosDistro}
    export RMW_IMPLEMENTATION=${rmwImplementation}
    export LD_LIBRARY_PATH="${rosBridgePrefix}/lib:$LD_LIBRARY_PATH"
    export AMENT_PREFIX_PATH="${rosBridgePrefix}:$AMENT_PREFIX_PATH"
    export COLCON_PREFIX_PATH="${rosBridgePrefix}:$COLCON_PREFIX_PATH"
    export CARB_APP_PATH=${isaac}/kit
    export ISAAC_PATH=${isaac}/
    export EXP_PATH=${isaac}/apps
    export PATH="${rosBridgePrefix}/bin:$PATH"

    # extscache is a tmpfs (writable) — seed it from the store's seed copy
    # so bundled extensions are found without re-downloading. Extensions Kit
    # pulls from the registry land here too and persist via their targets in
    # ~/.local/share/ov/data/exts/v2/ even though the symlinks are recreated
    # each launch.
    for src in "${unwrapped}/opt/isaacsim-extscache-seed"/*/; do
      [ -e "$src" ] || continue
      name="$(basename "$src")"
      [ -e "${isaac}/extscache/$name" ] || ln -s "$src" "${isaac}/extscache/$name"
    done

    script="''${ISAACSIM_SCRIPT:-${isaac}/isaac-sim.sh}"
    exec "$script" "$@"
  '';

  entryPoints = [
    {
      bin = "isaac-sim.selector.sh";
      script = "isaac-sim.selector.sh";
    }
    {
      bin = "isaac-sim.streaming.sh";
      script = "isaac-sim.streaming.sh";
    }
    {
      bin = "isaac-sim.fabric.sh";
      script = "isaac-sim.fabric.sh";
    }
    {
      bin = "isaac-sim.xr.vr.sh";
      script = "isaac-sim.xr.vr.sh";
    }
    {
      bin = "isaac-sim.compatibility_check.sh";
      script = "isaac-sim.compatibility_check.sh";
    }
    {
      bin = "isaac-sim.action_and_event_data_generation.sh";
      script = "isaac-sim.action_and_event_data_generation.sh";
    }
    {
      bin = "python.sh";
      script = "python.sh";
    }
    # WARN: broken
    # {
    #   bin = "isaac-sim-jupyter";
    #   script = "jupyter_notebook.sh";
    # }
    # WARN: broken
    # {
    #   bin = "warmup.sh";
    #   script = "warmup.sh";
    # }
    {
      bin = "clear-caches.sh";
      script = "clear_caches.sh";
    }
  ];

  wrappers =
    pkgs.lib.concatMapStrings (
      {
        bin,
        script,
      }: ''
        printf '#!/bin/sh\nexec env ISAACSIM_SCRIPT="${isaac}/%s" "%s/bin/isaac-sim.sh" "$@"\n' \
          '${script}' "$out" \
          > "$out/bin/${bin}"
        chmod +x "$out/bin/${bin}"
      ''
    )
    entryPoints;

  # TODO: test with systemwide install
  desktopItem = pkgs.makeDesktopItem {
    name = pname;
    desktopName = "IsaacSim";
    comment = "NVIDIA robotics simulation platform built on Omniverse";
    exec = "isaac-sim.sh %U";
    icon = "${isaac}/exts/isaacsim.app.setup/data/omni.isaac.sim.png";
    categories = [
      "Science"
      "Simulation"
      "3DGraphics"
    ];
    startupWMClass = "IsaacSim";
    terminal = false;
  };
in
  pkgs.buildFHSEnv {
    name = "isaac-sim.sh";
    inherit version;

    targetPkgs = pkgs:
      with pkgs; [
        gsettings-desktop-schemas
        libGL
        libGLU
        libx11
        libxcursor
        libxext
        libxrandr
        libglvnd
        libxcb
        libxml2_13
        libxt
        lsb-release
        util-linux
        vulkan-loader
        xdg-utils
        xterm
        zenity
        xterm
      ];

    multiPkgs = pkgs:
      with pkgs; [
        alsa-lib
        libpulseaudio
        openssl
        libnotify
        libsecret
        udev
        wayland
        icu
        glib
        zlib
        harfbuzz
      ];
    extraBwrapArgs = [
      "--tmpfs"
      "${isaac}/extscache"
    ];
    extraInstallCommands =
      wrappers
      +
      #bash
      ''
        mkdir -p "$out/share/applications"
        cp ${desktopItem}/share/applications/*.desktop "$out/share/applications/"
        ln -s ${isaac} $out/sim
      '';

    runScript = launcher;

    meta = {
      description = "NVIDIA Isaac Sim – robotics simulation platform built on Omniverse";
      homepage = "https://developer.nvidia.com/isaac-sim";
      downloadPage = "https://docs.isaacsim.omniverse.nvidia.com/${version}/installation/download.html";
      changelog = "https://docs.isaacsim.omniverse.nvidia.com/${version}/overview/release_notes.html";
      license = pkgs.lib.licenses.gpl3;
      maintainers = [];
      # TODO: add & test aarch64-linux support
      # https://docs.isaacsim.omniverse.nvidia.com/latest/installation/download.html
      platforms = ["x86_64-linux"];
      sourceProvenance = with pkgs.lib.sourceTypes; [binaryNativeCode];
    };
  }
