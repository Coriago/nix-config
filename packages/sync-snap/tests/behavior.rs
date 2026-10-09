use serde_json::{Value, json};
use std::{
    fs,
    os::unix::fs::{PermissionsExt, symlink},
    path::Path,
    process::Command,
    time::Duration,
};
use sync_snap::{
    config::{Entry, Format, Program},
    data,
    engine::{self, Event, Operation, Options},
    files, triggers,
};
use tempfile::TempDir;

fn entry(value: Value) -> Entry {
    serde_json::from_value(value).unwrap()
}
fn write(base: &Path, name: &str, content: &str) {
    fs::create_dir_all(base.join(name).parent().unwrap()).unwrap();
    fs::write(base.join(name), content).unwrap();
}
fn read(base: &Path, name: &str) -> Value {
    serde_json::from_slice(&fs::read(base.join(name)).unwrap()).unwrap()
}
fn execute(base: &Path, entries: Vec<Entry>, op: Operation, event: Event) -> engine::Stats {
    execute_at(base, entries, op, event, None)
}
fn execute_at(
    base: &Path,
    entries: Vec<Entry>,
    op: Operation,
    event: Event,
    trigger_context: Option<&triggers::Context>,
) -> engine::Stats {
    let state = base.join("state");
    let options = Options {
        base,
        state: &state,
        event,
        timeout: Duration::from_millis(20),
        jq: "jq",
        trigger_context,
    };
    let program = match op {
        Operation::Sync => Program {
            sync: entries,
            snapshot: vec![],
        },
        Operation::Snapshot => Program {
            sync: vec![],
            snapshot: entries,
        },
    };
    engine::execute("test-app", &program, op, &options)
}
fn sync(base: &Path, entries: Vec<Entry>) -> engine::Stats {
    execute(base, entries, Operation::Sync, Event::Manual)
}
fn standard(policy: &str) -> Entry {
    entry(json!({"destination":"runtime.json", "sources":["source.json"], "policy":policy}))
}

#[test]
fn root_array_key_paths_and_unknown_source_options() {
    let pruner = data::Pruner::new(&[r"^0\.password$".into()], &[]).unwrap();
    assert_eq!(
        pruner.apply(json!([{"password":"private"},{"keep":true}])),
        json!([])
    );
    let invalid =
        json!({"destination":"out.json","sources":[{"path":"source.json","optionl":true}]});
    assert!(serde_json::from_value::<Entry>(invalid).is_err());
}

#[test]
fn policies_arrays_type_changes_and_source_order() {
    for (policy, expected) in [
        (
            "seed",
            json!({"obj":{"user":1,"both":2},"arr":[],"kind":false}),
        ),
        (
            "fill-missing",
            json!({"obj":{"user":1,"both":2,"new":3},"arr":[],"kind":false}),
        ),
        (
            "merge",
            json!({"obj":{"user":1,"both":9,"new":3},"arr":[{"id":"a","x":4}],"kind":{"nested":true}}),
        ),
        (
            "replace",
            json!({"obj":{"both":9,"new":3},"arr":[{"id":"a","x":4}],"kind":{"nested":true}}),
        ),
    ] {
        let t = TempDir::new().unwrap();
        let p = t.path();
        write(
            p,
            "source.json",
            r#"{"obj":{"both":9,"new":3},"arr":[{"id":"a","x":4}],"kind":{"nested":true}}"#,
        );
        write(
            p,
            "runtime.json",
            r#"{"obj":{"user":1,"both":2},"arr":[],"kind":false}"#,
        );
        assert_eq!(sync(p, vec![standard(policy)]).failed, 0);
        assert_eq!(read(p, "runtime.json"), expected, "policy {policy}");
    }
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "one.json", r#"{"x":1,"a":[1],"o":{"a":1}}"#);
    write(p, "two.json", r#"{"x":2,"a":[2],"o":{"b":2}}"#);
    assert_eq!(
        sync(
            p,
            vec![entry(
                json!({"destination":"out.json","sources":["one.json","two.json"]})
            )]
        )
        .written,
        1
    );
    assert_eq!(
        read(p, "out.json"),
        json!({"x":2,"a":[2],"o":{"a":1,"b":2}})
    );
}

#[test]
fn invalid_source_aborts_all_sync_outputs_and_logs_then_recovers() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", r#"{"new":true}"#);
    write(p, "invalid.json", r#"{"token":"DO_NOT_LOG_ME", invalid}"#);
    write(p, "runtime.json", r#"{"old":true}"#);
    let bad = entry(
        json!({"destination":"other.json","sources":["source.json","invalid.json"],"policy":"replace"}),
    );
    let es = vec![standard("replace"), bad];
    assert_eq!(sync(p, es.clone()).failed, 1);
    assert_eq!(read(p, "runtime.json"), json!({"old":true}));
    assert!(!p.join("other.json").exists());
    let sidecar = files::sidecar(&p.join("other.json"), "sync");
    let log = fs::read_to_string(&sidecar).unwrap();
    assert!(log.contains("invalid.json") && log.contains("line"));
    assert!(!log.contains("DO_NOT_LOG_ME"));
    assert!(files::sidecar(&p.join("runtime.json"), "sync").exists());
    write(p, "invalid.json", r#"{"fixed":true}"#);
    assert_eq!(sync(p, es).written, 2);
    assert!(!sidecar.exists());
    assert!(!files::sidecar(&p.join("runtime.json"), "sync").exists());
}

#[test]
fn cache_checks_inputs_policy_and_destination_and_avoids_rewrites() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", r#"{"theme":"dark"}"#);
    assert_eq!(sync(p, vec![standard("merge")]).written, 1);
    let mtime = fs::metadata(p.join("runtime.json"))
        .unwrap()
        .modified()
        .unwrap();
    assert_eq!(sync(p, vec![standard("merge")]).cached, 1);
    assert_eq!(
        fs::metadata(p.join("runtime.json"))
            .unwrap()
            .modified()
            .unwrap(),
        mtime
    );
    write(p, "runtime.json", r#"{"theme":"light","local":1}"#);
    assert_eq!(sync(p, vec![standard("merge")]).written, 1);
    assert_eq!(read(p, "runtime.json"), json!({"theme":"dark","local":1}));
    write(p, "source.json", r#"{"theme":"blue"}"#);
    assert_eq!(sync(p, vec![standard("merge")]).cached, 0);
    assert_eq!(read(p, "runtime.json")["theme"], "blue");
    assert_eq!(sync(p, vec![standard("replace")]).written, 1);
    assert_eq!(read(p, "runtime.json"), json!({"theme":"blue"}));
    // A corrupt cache is a miss, never permission to skip validation.
    write(
        p,
        &format!("state/{}.json", files::digest(b"test-app")),
        "broken",
    );
    assert_eq!(sync(p, vec![standard("replace")]).cached, 0);
    write(p, "source.json", "broken JSON");
    assert_eq!(sync(p, vec![standard("replace")]).failed, 1);
}

#[test]
fn missing_optional_sources_never_erase_and_required_sources_fail() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "runtime.json", r#"{"keep":true}"#);
    let optional = entry(
        json!({"destination":"runtime.json","policy":"replace","sources":[{"path":"absent.json","optional":true}]}),
    );
    assert_eq!(sync(p, vec![optional]).failed, 0);
    assert_eq!(read(p, "runtime.json"), json!({"keep":true}));
    assert_eq!(sync(p, vec![standard("replace")]).failed, 1);
    assert_eq!(
        sync(
            p,
            vec![entry(json!({"destination":"runtime.json","sources":[]}))]
        )
        .failed,
        0
    ); // seed no-op
    assert_eq!(
        sync(
            p,
            vec![entry(
                json!({"destination":"absent-output.json","sources":[]})
            )]
        )
        .failed,
        1
    );
}

#[test]
fn startup_triggers_and_manual_override() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", r#"{"new":1}"#);
    let e = entry(
        json!({"destination":"runtime.json","sources":["source.json"],"policy":"replace","trigger":"onEveryBoot"}),
    );
    assert_eq!(start_at(p, vec![e.clone()], "boot", None, 100).written, 1);
    write(p, "runtime.json", r#"{"edited":1}"#);
    assert_eq!(start_at(p, vec![e.clone()], "boot", None, 101).written, 0);
    assert_eq!(sync(p, vec![e]).written, 1);
}

#[test]
fn invalid_destination_blocks_merge_but_explicit_replace_repairs_it() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", "{}");
    write(p, "runtime.json", "broken");
    assert_eq!(sync(p, vec![standard("merge")]).failed, 1);
    assert_eq!(sync(p, vec![standard("seed")]).failed, 0);
    assert_eq!(sync(p, vec![standard("replace")]).written, 1);
    assert_eq!(read(p, "runtime.json"), json!({}));
}

#[test]
fn pruning_drops_whole_arrays_including_nested_arrays_and_preserves_false() {
    let pruner = data::Pruner::new(&["password".into()], &["(?i)hdmi".into()]).unwrap();
    let result = pruner.apply(json!({
        "normal":{"password":"secret","color":"red"},
        "objects":[{"id":1,"password":"secret"},{"id":2}],
        "nested":[[1,2],["HDMI-1"]], "tuple":[1,"hdmi2"],
        "keep":[false,0,""], "flag":false, "empty":[], "o":{}
    }));
    assert_eq!(
        result,
        json!({"normal":{"color":"red"},"keep":[false,0,""],"flag":false,"empty":[],"o":{}})
    );
    assert_eq!(pruner.apply(json!([{"password":"x"}])), json!([]));
}

#[test]
fn key_paths_escape_literal_dots() {
    let pruner = data::Pruner::new(&[r"^a\.b$".into()], &[]).unwrap();
    assert_eq!(
        pruner.apply(json!({"a":{"b":1},"a.b":2})),
        json!({"a":{},"a.b":2})
    );
}

#[test]
fn snapshot_is_incremental_and_jq_requires_one_document_without_leaking_errors() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(
        p,
        "source.json",
        r#"{"meta":{"login":"x"},"servers":[{"role":"frontend"},{"role":"backend"}],"password":"secret"}"#,
    );
    let good = entry(
        json!({"destination":"snapshot.json","sources":["source.json"],"prune_key_contains":["password"],"transform":["del(.meta.login)",".servers |= map(select(.role != \"backend\"))"]}),
    );
    let bad = entry(
        json!({"destination":"bad.json","sources":["source.json"],"transform":["error(\"SECRET_RUNTIME_VALUE\")"]}),
    );
    let stats = execute(p, vec![good, bad], Operation::Snapshot, Event::Manual);
    assert_eq!((stats.written, stats.failed), (1, 1));
    assert_eq!(
        read(p, "snapshot.json"),
        json!({"meta":{},"servers":[{"role":"frontend"}]})
    );
    assert!(
        !fs::read_to_string(files::sidecar(&p.join("bad.json"), "snapshot"))
            .unwrap()
            .contains("SECRET_RUNTIME_VALUE")
    );
    for filter in ["empty", "., .", ".password", "not valid jq"] {
        assert!(data::transform(json!({"password":"secret"}), &[filter.into()], "jq").is_err());
    }
}

#[test]
fn json_toml_conversion_and_unrepresentable_values() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "input.toml", "[ui]\nsize = 12\nenabled = false\n");
    let e = entry(json!({"destination":"extensionless","sources":["input.toml"],"format":"json"}));
    assert_eq!(sync(p, vec![e]).written, 1);
    assert_eq!(
        read(p, "extensionless"),
        json!({"ui":{"size":12,"enabled":false}})
    );
    let parsed = data::parse(br#"{"large":123456789012345678901234567890}"#, Format::Json).unwrap();
    assert!(
        String::from_utf8(data::encode(&parsed, Format::Json).unwrap())
            .unwrap()
            .contains("123456789012345678901234567890")
    );
    assert!(data::encode(&parsed, Format::Toml).is_err());
    assert!(data::parse(b"date = 2026-10-08", Format::Toml).is_err());
    assert!(data::parse(b"number = nan", Format::Toml).is_err());
    assert!(data::encode(&json!({"x":null}), Format::Toml).is_err());
}

#[test]
fn raw_directory_overlay_keeps_runtime_files_and_rejects_overlap_cycles() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "lua/init.lua", "return 1\n");
    write(p, "lua/sub/config.lua", "return {}\n");
    write(p, "runtime/local.lua", "local state = true\n");
    let e = entry(
        json!({"destination":"runtime","sources":["lua"],"directory":true,"policy":"replace"}),
    );
    assert_eq!(sync(p, vec![e.clone()]).written, 2);
    assert_eq!(
        fs::read_to_string(p.join("runtime/init.lua")).unwrap(),
        "return 1\n"
    );
    assert!(p.join("runtime/local.lua").exists());
    fs::remove_file(p.join("lua/init.lua")).unwrap();
    assert_eq!(sync(p, vec![e.clone()]).cached, 1);
    assert!(p.join("runtime/init.lua").exists());
    symlink(p.join("lua"), p.join("lua/sub/loop")).unwrap();
    assert_eq!(sync(p, vec![e]).failed, 1);
}

#[test]
fn symlink_destinations_duplicates_and_same_source_are_rejected() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", "{}");
    write(p, "other.json", r#"{"private":true}"#);
    symlink(p.join("other.json"), p.join("runtime.json")).unwrap();
    assert_eq!(sync(p, vec![standard("replace")]).failed, 1);
    assert_eq!(read(p, "other.json"), json!({"private":true}));
    fs::remove_file(p.join("runtime.json")).unwrap();
    assert_eq!(
        sync(p, vec![standard("replace"), standard("replace")]).failed,
        1
    );
    assert!(!p.join("runtime.json").exists());
    let e =
        entry(json!({"destination":"source.json","sources":["source.json"],"policy":"replace"}));
    assert_eq!(sync(p, vec![e]).failed, 1);
}

#[test]
fn new_files_are_private_existing_permissions_survive_and_failed_stages_do_not_publish() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", r#"{"new":true}"#);
    assert_eq!(sync(p, vec![standard("replace")]).written, 1);
    assert_eq!(
        fs::metadata(p.join("runtime.json"))
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o600
    );
    fs::set_permissions(p.join("runtime.json"), fs::Permissions::from_mode(0o640)).unwrap();
    write(p, "source.json", r#"{"new":false}"#);
    assert_eq!(sync(p, vec![standard("replace")]).written, 1);
    assert_eq!(
        fs::metadata(p.join("runtime.json"))
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o640
    );
    write(p, "block-parent", "a regular file");
    write(p, "source.json", r#"{"new":123}"#);
    let bad = entry(json!({"destination":"block-parent/file.json","sources":["source.json"]}));
    assert!(sync(p, vec![standard("replace"), bad]).failed > 0);
    assert_eq!(read(p, "runtime.json"), json!({"new":false}));
}

fn manifest(p: &Path) {
    write(p,"manifest.json", &json!({"version":1,"programs":{"test-app":{"sync":[{"destination":"runtime.json","sources":["source.json"],"policy":"merge"}]}}}).to_string());
}
fn cli(p: &Path, action: &str) -> Command {
    let mut cmd = Command::new(env!("CARGO_BIN_EXE_sync-snap"));
    cmd.arg(action).args([
        "--config",
        p.join("manifest.json").to_str().unwrap(),
        "--program",
        "test-app",
        "--state-dir",
        p.join("state").to_str().unwrap(),
    ]);
    cmd
}

#[test]
fn run_launches_after_invalid_config_or_busy_lock_and_preserves_exit_status() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    manifest(p);
    write(p, "source.json", "invalid");
    let output = cli(p, "run")
        .args(["--", "sh", "-c", "exit 23"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(23));
    assert!(files::sidecar(&p.join("runtime.json"), "sync").exists());
    write(p, "source.json", "{}");
    let lock = files::lock(&p.join("state"), "test-app", Duration::ZERO).unwrap();
    let output = cli(p, "run")
        .args(["--lock-timeout-ms", "10", "--", "sh", "-c", "exit 24"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(24));
    assert!(
        String::from_utf8(output.stderr)
            .unwrap()
            .contains("lock busy")
    );
    drop(lock);
    assert!(cli(p, "sync").output().unwrap().status.success());
    write(p, "manifest.json", "invalid manifest");
    assert_eq!(
        cli(p, "run")
            .args(["--", "sh", "-c", "exit 25"])
            .output()
            .unwrap()
            .status
            .code(),
        Some(25)
    );
}

#[test]
fn concurrent_startups_serialize_and_release_locks() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    manifest(p);
    write(p, "source.json", r#"{"a":[1,2,3],"b":true}"#);
    let one = cli(p, "sync")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .unwrap();
    let two = cli(p, "sync")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .unwrap();
    let a = one.wait_with_output().unwrap();
    let b = two.wait_with_output().unwrap();
    assert!(a.status.success() && b.status.success());
    let logs = format!(
        "{}{}",
        String::from_utf8_lossy(&a.stderr),
        String::from_utf8_lossy(&b.stderr)
    );
    assert!(logs.contains("cache_hits=1"), "{logs}");
    assert_eq!(read(p, "runtime.json"), json!({"a":[1,2,3],"b":true}));
    assert!(files::lock(&p.join("state"), "test-app", Duration::ZERO).is_ok());
}

#[test]
fn direct_arguments_batch_sources_snapshot_and_fail_open() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    let direct = |action: &str| {
        let mut cmd = Command::new(env!("CARGO_BIN_EXE_sync-snap"));
        cmd.current_dir(p)
            .arg(action)
            .args(["--program", "direct-test", "--state-dir", "state"]);
        cmd
    };
    write(p, "source with spaces", r#"{"a":1,"secret":"remove"}"#);
    write(p, "override.json", r#"{"a":2}"#);
    write(p, "second.toml", "enabled = true");
    let args = [
        "--destination=first.json",
        "--source",
        "source with spaces",
        "--source-format",
        "json",
        "--source",
        "override.json",
        "--policy",
        "merge",
        "--destination",
        "second.json",
        "--source",
        "second.toml",
        "--policy",
        "merge",
    ];
    assert!(direct("sync").args(args).output().unwrap().status.success());
    assert_eq!(read(p, "first.json")["a"], 2);
    assert_eq!(read(p, "second.json"), json!({"enabled":true}));
    assert!(
        direct("snapshot")
            .args([
                "--destination",
                "snapshot.json",
                "--source",
                "first.json",
                "--prune-key-contains",
                "^secret$",
                "--transform",
                ".captured = true"
            ])
            .output()
            .unwrap()
            .status
            .success()
    );
    assert_eq!(read(p, "snapshot.json"), json!({"a":2,"captured":true}));
    write(p, "override.json", r#"{"a":3}"#);
    write(p, "second.json", "broken");
    assert!(!direct("sync").args(args).output().unwrap().status.success());
    assert_eq!(read(p, "first.json")["a"], 2);
    assert_eq!(
        direct("run")
            .args(args)
            .args(["--", "sh", "-c", "exit 23"])
            .output()
            .unwrap()
            .status
            .code(),
        Some(23)
    );
    assert!(
        !direct("sync")
            .args(["--source", "override.json", "--destination", "bad.json"])
            .output()
            .unwrap()
            .status
            .success()
    );
    assert!(!p.join("bad.json").exists());
    // A source modifier belongs to the preceding source, never the next file.
    assert!(
        !direct("sync")
            .args([
                "--destination",
                "bad.json",
                "--source-format",
                "json",
                "--source",
                "override.json"
            ])
            .output()
            .unwrap()
            .status
            .success()
    );
    assert!(
        direct("sync")
            .args([
                "--destination",
                "optional.json",
                "--source",
                "missing.json",
                "--source-optional",
                "true"
            ])
            .output()
            .unwrap()
            .status
            .success()
    );
    assert!(!p.join("optional.json").exists());
}

fn start_at(
    base: &Path,
    entries: Vec<Entry>,
    boot: &str,
    session: Option<&str>,
    epoch: u64,
) -> engine::Stats {
    let context = triggers::Context {
        boot_id: Some(boot.into()),
        session_id: session.map(str::to_owned),
        epoch,
    };
    execute_at(base, entries, Operation::Sync, Event::Start, Some(&context))
}
fn scheduled(trigger: &str) -> Entry {
    entry(
        json!({"destination":"runtime.json","sources":["source.json"],"policy":"replace","trigger":trigger}),
    )
}

#[test]
fn boot_gate_preserves_edits_but_inputs_missing_destinations_and_lost_state_override_it() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", r#"{"baseline":1}"#);
    let e = scheduled("onEveryBoot");
    assert_eq!(start_at(p, vec![e.clone()], "boot1", None, 100).written, 1);
    let state = fs::read(p.join("state/test-app.trigger")).unwrap();
    // Even invalid runtime JSON is untouched while the trigger is closed.
    write(p, "runtime.json", "user editing");
    let skipped = start_at(p, vec![e.clone()], "boot1", None, 200);
    assert_eq!(
        (skipped.failed, skipped.written, skipped.skipped),
        (0, 0, 1)
    );
    assert_eq!(fs::read(p.join("state/test-app.trigger")).unwrap(), state);
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 300).written, 1);
    write(p, "source.json", r#"{"baseline":2}"#);
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 301).written, 1);
    fs::remove_file(p.join("runtime.json")).unwrap();
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 302).written, 1);
    write(p, "runtime.json", "{}");
    fs::remove_file(p.join("state/test-app.trigger")).unwrap();
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 303).written, 1);
    write(p, "runtime.json", "{}");
    write(p, "state/test-app.trigger", "corrupt");
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 304).written, 1);
    let record =
        &read(p, "state/test-app.trigger")["files"][p.join("runtime.json").to_str().unwrap()];
    assert!(record["input_fingerprint"].is_string());
    assert!(record.get("destination_hash").is_none());
    // Relevant arguments also invalidate the fingerprint, independently of destination bytes.
    let mut changed = e;
    changed.policy = sync_snap::config::Policy::Merge;
    assert_eq!(start_at(p, vec![changed], "boot2", None, 305).cached, 0);
    assert_eq!(
        read(p, "state/test-app.trigger")["files"][p.join("runtime.json").to_str().unwrap()]["last_success_epoch"],
        305
    );
}

#[test]
fn login_gate_tracks_sessions_within_a_boot_and_falls_back_without_an_id() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", r#"{"baseline":1}"#);
    let e = scheduled("onEveryLogin");
    assert_eq!(
        start_at(p, vec![e.clone()], "boot1", Some("a"), 100).written,
        1
    );
    write(p, "runtime.json", "{}");
    assert_eq!(
        start_at(p, vec![e.clone()], "boot1", Some("a"), 101).written,
        0
    );
    assert_eq!(
        start_at(p, vec![e.clone()], "boot1", Some("b"), 102).written,
        1
    );
    write(p, "runtime.json", "{}");
    assert_eq!(
        start_at(p, vec![e.clone()], "boot1", Some("a"), 103).written,
        0
    );
    assert_eq!(start_at(p, vec![e.clone()], "boot1", None, 104).written, 0);
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 105).written, 1);
    write(p, "runtime.json", "{}");
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 106).written, 0);
    assert_eq!(start_at(p, vec![e], "boot2", Some("a"), 107).written, 1);
}

#[test]
fn duration_uses_epoch_across_reboots_and_cache_hits_advance_the_schedule() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", r#"{"baseline":1}"#);
    let mut e = scheduled("onDuration");
    e.duration = Some("1hr".into());
    assert_eq!(start_at(p, vec![e.clone()], "boot1", None, 100).written, 1);
    write(p, "runtime.json", "{}");
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 3699).written, 0);
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 3700).written, 1);
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 7300).cached, 1);
    write(p, "runtime.json", "{}");
    assert_eq!(start_at(p, vec![e.clone()], "boot2", None, 7301).written, 0);
    assert_eq!(start_at(p, vec![e], "boot2", None, 10900).written, 1);
}

#[test]
fn file_schedules_are_independent_and_validation_failures_do_not_advance_state() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", r#"{"baseline":1}"#);
    write(p, "other.json", r#"{"other":1}"#);
    let boot = scheduled("onEveryBoot");
    let timed = entry(
        json!({"destination":"second.json","sources":["other.json"],"policy":"replace","trigger":"onDuration","duration":"1m"}),
    );
    let entries = vec![boot, timed];
    assert_eq!(start_at(p, entries.clone(), "boot1", None, 100).written, 2);
    write(p, "runtime.json", "{}");
    write(p, "second.json", "{}");
    assert_eq!(start_at(p, entries.clone(), "boot1", None, 160).written, 1);
    assert_eq!(read(p, "runtime.json"), json!({}));
    let state = fs::read(p.join("state/test-app.trigger")).unwrap();
    write(p, "other.json", "broken");
    for _ in 0..2 {
        let failed = start_at(p, entries.clone(), "boot2", None, 161);
        assert_eq!((failed.failed, failed.written), (1, 0));
        assert_eq!(read(p, "runtime.json"), json!({}));
        assert_eq!(fs::read(p.join("state/test-app.trigger")).unwrap(), state);
    }
    write(p, "other.json", r#"{"other":2}"#);
    assert_eq!(start_at(p, entries, "boot2", None, 162).written, 2);
}

#[test]
fn duration_validation_and_direct_cli_trigger_arguments() {
    for duration in [
        None,
        Some("0s"),
        Some("1"),
        Some("1week"),
        Some("-1h"),
        Some("18446744073709551615d"),
    ] {
        let mut e = scheduled("onDuration");
        e.duration = duration.map(str::to_owned);
        assert!(triggers::duration_seconds(&e).is_err());
    }
    let mut e = scheduled("onEveryBoot");
    e.duration = Some("1h".into());
    assert!(triggers::duration_seconds(&e).is_err());
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", r#"{"baseline":1}"#);
    let run = || {
        Command::new(env!("CARGO_BIN_EXE_sync-snap"))
            .current_dir(p)
            .args([
                "sync",
                "--program",
                "cli-app",
                "--state-dir",
                "state",
                "--startup",
                "--destination",
                "runtime.json",
                "--source",
                "source.json",
                "--policy",
                "replace",
                "--trigger",
                "onDuration",
                "--duration",
                "1h",
            ])
            .output()
            .unwrap()
    };
    assert!(run().status.success());
    write(p, "runtime.json", "{}");
    assert!(run().status.success());
    assert_eq!(read(p, "runtime.json"), json!({}));
    assert!(p.join("state/cli-app.trigger").exists());
    assert_eq!(
        triggers::state_path(p, "../escape"),
        p.join("..%2fescape.trigger")
    );
}

#[test]
fn concurrent_scheduled_startups_share_one_trigger_file() {
    let t = TempDir::new().unwrap();
    let p = t.path();
    write(p, "source.json", r#"{"baseline":1}"#);
    let spawn = || {
        Command::new(env!("CARGO_BIN_EXE_sync-snap"))
            .current_dir(p)
            .args([
                "sync",
                "--program",
                "scheduled-app",
                "--state-dir",
                "state",
                "--startup",
                "--destination",
                "runtime.json",
                "--source",
                "source.json",
                "--policy",
                "replace",
                "--trigger",
                "onDuration",
                "--duration",
                "1h",
            ])
            .stderr(std::process::Stdio::piped())
            .spawn()
            .unwrap()
    };
    let first = spawn();
    let second = spawn();
    let first = first.wait_with_output().unwrap();
    let second = second.wait_with_output().unwrap();
    assert!(first.status.success() && second.status.success());
    let logs = format!(
        "{}{}",
        String::from_utf8_lossy(&first.stderr),
        String::from_utf8_lossy(&second.stderr)
    );
    assert!(
        logs.contains("written=1") && logs.contains("written=0, skipped=1"),
        "{logs}"
    );
    assert_eq!(
        read(p, "state/scheduled-app.trigger")["files"]
            .as_object()
            .unwrap()
            .len(),
        1
    );
}
