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
    files,
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
    let state = base.join("state");
    let options = Options {
        base,
        state: &state,
        event,
        timeout: Duration::from_millis(20),
        jq: "jq",
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
        json!({"destination":"runtime.json","sources":["source.json"],"policy":"replace","trigger":"on-init"}),
    );
    assert_eq!(
        execute(p, vec![e.clone()], Operation::Sync, Event::Start).written,
        1
    );
    write(p, "runtime.json", r#"{"edited":1}"#);
    assert_eq!(
        execute(p, vec![e.clone()], Operation::Sync, Event::Start).written,
        0
    );
    assert_eq!(sync(p, vec![e]).written, 1);
    let e = entry(json!({"destination":"never.json","sources":["source.json"],"trigger":"never"}));
    assert_eq!(
        execute(p, vec![e.clone()], Operation::Sync, Event::Start).written,
        0
    );
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
