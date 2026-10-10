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
  parentFixture = wlib.evalPackage {
    inherit pkgs;
    imports = [./default.nix];
    package = pkgs.writeShellScriptBin "mapping-parent-fixture" ''
      set -eu
      cmp /etc/passwd "$HOME/passwd"
      test "$(cat /etc/nix-wrapper-directory-mappings-check/settings)" = baseline
      printf updated > /etc/nix-wrapper-directory-mappings-check/settings
      test "$(cat "$HOME/parent tree/.hidden")" = hidden
      test "$(readlink "$HOME/parent tree/dangling")" = absent
      test "$(cat "$HOME/parent tree/sibling/file")" = sibling
      test "$(cat "$HOME/parent tree/nested/mapped/settings")" = updated
      touch "$HOME/parent tree/transient"
    '';
    directoryMappingParentDirs = [
      "/etc"
      "\${HOME}/parent tree"
      "\${HOME}/parent tree/nested"
    ];
    directoryMappings = [
      {
        source = "\${HOME}/actual dir";
        target = "/etc/nix-wrapper-directory-mappings-check";
      }
      {
        source = "\${HOME}/actual dir";
        target = "\${HOME}/parent tree/nested/mapped";
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

    # Missing mount targets beneath root-owned parents must work without host writes.
    test ! -e /etc/nix-wrapper-directory-mappings-check
    cp /etc/passwd "$HOME/passwd"
    mkdir -p "$HOME/parent tree/sibling"
    printf hidden > "$HOME/parent tree/.hidden"
    printf sibling > "$HOME/parent tree/sibling/file"
    ln -s absent "$HOME/parent tree/dangling"
    printf baseline > "$HOME/actual dir/settings"
    ${parentFixture}/bin/mapping-parent-fixture
    test "$(cat "$HOME/actual dir/settings")" = updated
    test ! -e /etc/nix-wrapper-directory-mappings-check
    test ! -e "$HOME/parent tree/transient"
    test ! -e "$HOME/parent tree/nested"
    test "$(cat "$HOME/parent tree/.hidden")" = hidden
    touch "$out"
  ''
