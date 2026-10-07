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
    settings.keybind = [
      "clear"

      # Configuration.
      "ctrl+,=open_config"
      "ctrl+shift+,=reload_config"
      "ctrl+shift+p=toggle_command_palette"

      # Clipboard and selection.
      "copy=copy_to_clipboard:mixed"
      "paste=paste_from_clipboard"
      "ctrl+insert=copy_to_clipboard:mixed"
      "shift+insert=paste_from_selection"
      "ctrl+shift+c=copy_to_clipboard:mixed"
      "ctrl+shift+v=paste_from_clipboard"
      "ctrl+shift+a=select_all"
      "shift+arrow_left=adjust_selection:left"
      "shift+arrow_right=adjust_selection:right"
      "shift+arrow_up=adjust_selection:up"
      "shift+arrow_down=adjust_selection:down"

      # Font size.
      "ctrl+==increase_font_size:1"
      "ctrl++=increase_font_size:1"
      "ctrl+-=decrease_font_size:1"
      "ctrl+0=reset_font_size"

      # Scrollback and search.
      "shift+page_up=scroll_page_up"
      "shift+page_down=scroll_page_down"
      "shift+home=scroll_to_top"
      "shift+end=scroll_to_bottom"
      "ctrl+shift+page_up=jump_to_prompt:-1"
      "ctrl+shift+page_down=jump_to_prompt:1"
      "ctrl+shift+f=start_search"
      "escape=end_search"
      "super+ctrl+shift+j=write_screen_file:copy,plain"
      "ctrl+shift+j=write_screen_file:paste,plain"
      "ctrl+alt+shift+j=write_screen_file:open,plain"

      # Windows and diagnostics.
      "ctrl+shift+n=new_window"
      "ctrl+shift+q=quit"
      "alt+f4=close_window"
      "ctrl+enter=toggle_fullscreen"
      "ctrl+shift+i=inspector:toggle"
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
