{
  pkgs,
  wlib,
}: let
  fixture = wlib.evalPackage {
    inherit pkgs;
    imports = [./default.nix];
    package = pkgs.writeShellScriptBin "mapping-fixture" ''
      set -eu
      test "$1" = 'argument with spaces'
      test "$(cat "$HOME/visible dir/settings")" = baseline
      test ! -e "$HOME/visible dir/host-only"
      # Exercise the atomic save used by OpenCode and many GUI applications.
      printf updated > "$HOME/visible dir/settings.tmp"
      mv "$HOME/visible dir/settings.tmp" "$HOME/visible dir/settings"
      ${pkgs.bash}/bin/bash -c 'test "$(cat "$HOME/visible dir/settings")" = updated'
      exit 23
    '';
    directoryMappings = [
      {
        source = "\${HOME}/actual dir";
        target = "\${HOME}/visible dir";
      }
    ];
  };
in
  pkgs.runCommand "directory-mappings-check" {} ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME/actual dir" "$HOME/visible dir"
    printf baseline > "$HOME/actual dir/settings"
    printf original > "$HOME/visible dir/settings"
    touch "$HOME/visible dir/host-only"
    status=0
    ${fixture}/bin/mapping-fixture 'argument with spaces' || status=$?
    test "$status" = 23
    test "$(cat "$HOME/actual dir/settings")" = updated
    test "$(cat "$HOME/visible dir/settings")" = original
    test -e "$HOME/visible dir/host-only"
    touch "$out"
  ''
