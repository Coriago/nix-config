{
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    python = pkgs.python3.withPackages (p: [p.tomli-w]);
    umbriel = self'.packages.myumbriel;
    wrapper = self'.packages.mynoctalia;
  in {
    checks.mynoctalia = pkgs.runCommand "noctalia-config-check" {} ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      ${wrapper}/bin/noctalia-sync
      ${lib.getExe wrapper} config validate
      ${python}/bin/python ${./noctalia-feature-check.py} ${lib.getExe wrapper}
      touch "$out"
    '';
    checks.noctalia-gtk = pkgs.runCommand "noctalia-gtk-check" {} ''
      export HOME="$TMPDIR/home"
      export XDG_CONFIG_HOME="$HOME/config"
      export XDG_DATA_HOME="$HOME/data"
      export XDG_RUNTIME_DIR="$TMPDIR/runtime"
      mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_RUNTIME_DIR"
      chmod 700 "$XDG_RUNTIME_DIR"
      cat > bus.conf <<'BUS'
      <busconfig>
        <type>session</type>
        <listen>unix:tmpdir=/tmp</listen>
        <servicedir>${pkgs.dconf}/share/dbus-1/services</servicedir>
        <policy context="default">
          <allow send_destination="*"/>
          <allow receive_sender="*"/>
          <allow own="*"/>
        </policy>
      </busconfig>
      BUS
      ${pkgs.dbus}/bin/dbus-run-session --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon --config-file=bus.conf -- \
        ${python}/bin/python ${./gtk-hook-check.py} \
        ${lib.getExe wrapper} ${pkgs.noctalia}/share/noctalia/assets/templates \
        ${pkgs.dconf}/bin/dconf ${lib.getExe umbriel}
      touch "$out"
    '';
  };
}
