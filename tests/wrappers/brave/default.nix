{
  pkgs,
  brave,
}: let
  capturedFixture = pkgs.runCommand "mybrave-roundtrip-snapshot.json" {} ''
    export HOME="$TMPDIR/home" XDG_STATE_HOME="$TMPDIR/state"
    mkdir -p "$HOME" "$TMPDIR/profile/Default"
    cat > "$TMPDIR/profile/Default/Preferences" <<'JSON'
    {"credentials_enable_service":true,"bookmark_bar":{"show_on_all_tabs":true},"extensions":{"settings":{"private":"discard"}}}
    JSON
    ${brave}/bin/brave-snapshot "$out" --user-data-dir "$TMPDIR/profile"
  '';
  roundtrip = brave.wrap {
    snapshotSource = capturedFixture;
    syncSnap.sync.preferences.policy = "seed";
    homeManager.programs.brave = {
      commandLineArgs = ["--no-default-browser-check"];
      nativeMessagingHosts = [
        (pkgs.writeTextDir "etc/chromium/native-messaging-hosts/org.example.test.json" (builtins.toJSON {
          name = "org.example.test";
          description = "Integration-test fixture";
          path = "${pkgs.coreutils}/bin/false";
          type = "stdio";
          allowed_origins = ["chrome-extension://nngceckbapebfimnlniiiahkandclblb/"];
        }))
      ];
    };
  };
in
  pkgs.runCommand "mybrave-sync-snap-check" {
    nativeBuildInputs = [pkgs.jq pkgs.coreutils];
    inherit brave;
    braveRoundtrip = roundtrip;
  } (builtins.readFile ./check.sh)
