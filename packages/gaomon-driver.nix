{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libx11,
  libxrandr,
  libxtst,
  libxcb,
  libxext,
  libxi,
  libxrender,
  libxfixes,
  libXinerama,
  libxkbcommon,
  libGL,
  fontconfig,
  freetype,
  glib,
  dbus,
  libusb1,
  systemd,
  gcc-unwrapped,
}:
stdenv.mkDerivation rec {
  pname = "gaomon-driver";
  version = "16.0.0.37";

  src = fetchurl {
    url = "https://driver.gaomon.net/Driver/Linux/GaomonTablet_LinuxDriver_v${version}.x86_64.tar.xz";
    hash = "sha256-09s8rRUgSeaROudE9JdoaoxLYe+R/mZMhP/lXryWvQE=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # Runtime dependencies that autoPatchelfHook will resolve against.
  # The driver bundles its own Qt5 and custom libs (libhuionhid, libhnusb, etc.),
  # so we only need to provide the system libraries it links against.
  buildInputs = [
    libx11
    libxrandr
    libxtst
    libxcb
    libxext
    libxi
    libxrender
    libxfixes
    libXinerama
    libxkbcommon
    libGL
    fontconfig
    freetype
    glib
    dbus
    gcc-unwrapped.lib # libstdc++
    libusb1
    systemd # libsystemd (needed by libTabletSession.so)
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    local driverDir="$out/lib/gaomontablet"

    # Install the driver tree
    mkdir -p "$driverDir"
    cp -r gaomon/gaomontablet/* "$driverDir/"

    # Ensure binaries are executable
    chmod +x "$driverDir/gaomontablet" "$driverDir/huionCore"

    # Make bundled libs discoverable by autoPatchelfHook
    addAutoPatchelfSearchPath "$driverDir/libs"

    # Install udev rules
    mkdir -p "$out/lib/udev/rules.d"
    cp gaomon/gaomontablet/res/rule/20-gaomon.rules "$out/lib/udev/rules.d/"

    # Install icon
    mkdir -p "$out/share/icons"
    cp gaomon/icon/gaomontablet.png "$out/share/icons/"

    # Create wrapped launcher scripts
    mkdir -p "$out/bin"

    makeWrapper "$driverDir/huionCore" "$out/bin/gaomon-core" \
      --prefix LD_LIBRARY_PATH : "$driverDir/libs"

    makeWrapper "$driverDir/gaomontablet" "$out/bin/gaomon-tablet" \
      --prefix LD_LIBRARY_PATH : "$driverDir/libs" \
      --set QT_QPA_PLATFORM_PLUGIN_PATH "$driverDir/platforms" \
      --set QML2_IMPORT_PATH "$driverDir/qml" \
      --set QT_PLUGIN_PATH "$driverDir"

    # Install desktop entry with corrected paths
    mkdir -p "$out/share/applications"
    cat > "$out/share/applications/gaomontablet.desktop" <<EOF
    [Desktop Entry]
    Name=GaoMonTablet
    Comment=Gaomon tablet driver
    Exec=$out/bin/gaomon-tablet
    Icon=$out/share/icons/gaomontablet.png
    Terminal=false
    Type=Application
    Categories=Utility;
    StartupNotify=true
    EOF

    runHook postInstall
  '';

  # The driver bundles its own Qt5/QML plugins and some proprietary .so files.
  # autoPatchelfHook patches the system deps via buildInputs above, while these
  # bundled Qt modules are resolved via LD_LIBRARY_PATH/QML2_IMPORT_PATH at runtime.
  autoPatchelfIgnoreMissingDeps = [
    "libQt5*"
    "libQtSessionLib*"
    "libicu*"
  ];

  meta = {
    description = "Official Gaomon tablet driver for Linux (supports M10K 2018 and other models)";
    homepage = "https://www.gaomon.net/";
    # license = lib.licenses.unfree;
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    mainProgram = "gaomon-tablet";
  };
}
