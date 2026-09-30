{self, ...}: {
  flake.modules.nixos.niri = {pkgs, ...}: {
    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.myniri;
    };
    security.pam.services.swaylock = {};
    # The base profile already starts the OpenSSH agent.
    services.gnome.gcr-ssh-agent.enable = false;
  };

  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    editNixConfig = pkgs.writeShellApplication {
      name = "edit-nix-config";
      text = ''
        cd "''${NIX_CONFIG_DIR:-$HOME/.config/nix-config}"
        exec ${lib.getExe pkgs.ghostty} --working-directory="$PWD" -e ${lib.getExe' self'.packages.myneovim "nvim"} .
      '';
    };
    barConfig = pkgs.writeText "niri-waybar.json" (builtins.toJSON {
      layer = "top";
      position = "top";
      modules-left = ["niri/workspaces" "niri/window"];
      modules-right = ["pulseaudio" "network" "clock" "tray"];
      "niri/window".max-length = 50;
      clock.format = "{:%a %d %b  %H:%M}";
      pulseaudio.format = "Volume {volume}%";
      pulseaudio.format-muted = "Muted";
      network.format-wifi = "{essid}";
      network.format-ethernet = "Ethernet";
      network.format-disconnected = "Offline";
    });
    barStyle = pkgs.writeText "niri-waybar.css" ''
      * { font-family: sans-serif; font-size: 13px; }
      window#waybar { background: #1a1b26; color: #c0caf5; }
      #workspaces button { color: #c0caf5; padding: 0 8px; }
      #workspaces button.active { background: #414868; }
      #window, #pulseaudio, #network, #clock, #tray { padding: 0 12px; }
    '';
    niriConfig = pkgs.writeText "niri-config.kdl" (lib.replaceStrings
      ["@terminal@" "@launcher@" "@browser@" "@editor@" "@lock@" "@volume@" "@brightness@" "@notifications@" "@bar@" "@barConfig@" "@barStyle@"]
      [(lib.getExe pkgs.ghostty) (lib.getExe pkgs.fuzzel) (lib.getExe pkgs.brave) (lib.getExe editNixConfig) (lib.getExe pkgs.swaylock) "${pkgs.wireplumber}/bin/wpctl" (lib.getExe pkgs.brightnessctl) (lib.getExe pkgs.mako) (lib.getExe pkgs.waybar) (toString barConfig) (toString barStyle)]
      (builtins.readFile ./niri/config.kdl));
  in {
    packages.myniri = pkgs.symlinkJoin {
      name = "niri-wrapped-${pkgs.niri.version}";
      paths = [pkgs.niri];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram "$out/bin/niri" \
          --set-default NIRI_CONFIG ${niriConfig} \
          --suffix PATH : ${lib.makeBinPath [pkgs.xwayland-satellite]}

        # nixpkgs' systemd unit embeds the original executable's absolute path.
        # Route both login-session entry points through this wrapper.
        rm "$out/lib/systemd/user/niri.service"
        substitute ${pkgs.niri}/lib/systemd/user/niri.service "$out/lib/systemd/user/niri.service" \
          --replace-fail '${pkgs.niri}/bin/niri' "$out/bin/niri"
        rm "$out/share/wayland-sessions/niri.desktop"
        substitute ${pkgs.niri}/share/wayland-sessions/niri.desktop "$out/share/wayland-sessions/niri.desktop" \
          --replace-fail 'Exec=niri-session' "Exec=$out/bin/niri-session"
      '';
      passthru = {
        providedSessions = ["niri"];
        configFile = niriConfig;
      };
      meta = pkgs.niri.meta;
    };
    apps.myniri = {
      type = "app";
      program = lib.getExe self'.packages.myniri;
      meta.description = "Niri with starter keybindings and the packaged Neovim";
    };
    checks.myniri = pkgs.runCommand "niri-config-check" {} ''
      ${lib.getExe self'.packages.myniri} validate
      grep -F '${self'.packages.myniri}/bin/niri --session' ${self'.packages.myniri}/lib/systemd/user/niri.service
      touch "$out"
    '';
  };
}
