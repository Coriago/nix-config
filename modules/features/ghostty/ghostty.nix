{config, ...}: let
  local = config;
in {
  flake.wrappers.myghostty = {
    config,
    lib,
    wlib,
    ...
  }: {
    imports = [wlib.wrapperModules.ghostty];
    # Preserve upstream defaults and their flags. Escape's search action is
    # performable-only; +list-keybinds/+show-config omit that flag. Recreating
    # their listing would consume Escape even when no terminal search is active.
    settings.keybind = [
      # Tabs: creation, closing, navigation, and numbered selection.
      "ctrl+shift+t=unbind"
      "ctrl+shift+w=unbind"
      "ctrl+shift+tab=unbind"
      "ctrl+tab=unbind"
      "ctrl+shift+arrow_left=unbind"
      "ctrl+shift+arrow_right=unbind"
      "ctrl+page_up=unbind"
      "ctrl+page_down=unbind"
      "alt+digit_1=unbind"
      "alt+1=unbind"
      "alt+digit_2=unbind"
      "alt+2=unbind"
      "alt+digit_3=unbind"
      "alt+3=unbind"
      "alt+digit_4=unbind"
      "alt+4=unbind"
      "alt+digit_5=unbind"
      "alt+5=unbind"
      "alt+digit_6=unbind"
      "alt+6=unbind"
      "alt+digit_7=unbind"
      "alt+7=unbind"
      "alt+digit_8=unbind"
      "alt+8=unbind"
      "alt+9=unbind"

      # Splits: creation, navigation, resizing, and zoom.
      "ctrl+shift+o=unbind"
      "ctrl+shift+e=unbind"
      "super+ctrl+[=unbind"
      "super+ctrl+]=unbind"
      "ctrl+alt+arrow_up=unbind"
      "ctrl+alt+arrow_down=unbind"
      "ctrl+alt+arrow_left=unbind"
      "ctrl+alt+arrow_right=unbind"
      "super+ctrl+shift+arrow_up=unbind"
      "super+ctrl+shift+arrow_down=unbind"
      "super+ctrl+shift+arrow_left=unbind"
      "super+ctrl+shift+arrow_right=unbind"
      "ctrl+shift+enter=unbind"
    ];

    # The upstream wrapper disables host config by default. Keep it writable
    # for Noctalia's theme hook, then apply our keybinding policy afterward.
    addFlag = lib.mkForce [
      "--config-default-files=true"
      "--config-file=${config.constructFiles.ghosttyConfig.path}"
    ];
  };

  flake.modules.nixos.ghostty = {...}: {
    imports = [local.flake.wrappers.myghostty.install];
    wrappers.myghostty.enable = true;
  };

  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: {
    checks.myghostty =
      pkgs.runCommand "ghostty-config-theme-check" {
        nativeBuildInputs = [pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.bash];
      } ''
        export HOME="$TMPDIR/home"
        export XDG_CONFIG_HOME="$HOME/config"
        mkdir -p "$XDG_CONFIG_HOME/ghostty/themes" stubs
        # Never signal terminals or contact the real session during this check.
        for command in systemctl gdbus pgrep; do
          printf '#!${pkgs.bash}/bin/bash\nexit 1\n' > "stubs/$command"
          chmod +x "stubs/$command"
        done
        export PATH="$PWD/stubs:$PATH"
        ${pkgs.python3.withPackages (p: [p.tomli-w])}/bin/python ${./theme-check.py} \
          ${lib.getExe self'.packages.myghostty} \
          ${self'.packages.myghostty}/ghostty-config \
          ${lib.getExe pkgs.noctalia} \
          ${pkgs.noctalia}/share/noctalia/assets/templates
        touch "$out"
      '';
  };
}
