use crate::{
    config::{Entry, Format, Policy, Program, Source, Trigger, resolve},
    data, files,
};
use anyhow::{Context, Result, bail, ensure};
use serde_json::Value;
use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    io::ErrorKind,
    path::{Path, PathBuf},
    time::Duration,
};
use tempfile::NamedTempFile;

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Operation {
    Sync,
    Snapshot,
}
impl Operation {
    pub fn name(self) -> &'static str {
        match self {
            Self::Sync => "sync",
            Self::Snapshot => "snapshot",
        }
    }
}
#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Event {
    Manual,
    Start,
}
pub struct Options<'a> {
    pub base: &'a Path,
    pub state: &'a Path,
    pub event: Event,
    pub timeout: Duration,
    pub jq: &'a str,
}
#[derive(Default, Debug)]
pub struct Stats {
    pub written: usize,
    pub skipped: usize,
    pub cached: usize,
    pub failed: usize,
}

struct Planned {
    destination: PathBuf,
    original: Option<String>,
    temporary: Option<NamedTempFile>,
    cache: Option<String>,
    cached: bool,
}

fn hash_field(h: &mut blake3::Hasher, bytes: &[u8]) {
    h.update(&(bytes.len() as u64).to_le_bytes());
    h.update(bytes);
}
fn fingerprint(h: &blake3::Hasher, dst: Option<&[u8]>) -> String {
    let mut h = h.clone();
    h.update(&[u8::from(dst.is_some())]);
    if let Some(bytes) = dst {
        hash_field(&mut h, bytes);
    }
    h.finalize().to_hex().to_string()
}

fn prepare(
    entry: &Entry,
    op: Operation,
    options: &Options<'_>,
    cache: &BTreeMap<String, String>,
) -> Result<Planned> {
    let dst = files::destination(&resolve(&entry.destination, options.base)?)?;
    let original = files::read_optional(&dst)?;
    let original_hash = original.as_deref().map(files::digest);
    let mut plan = Planned {
        destination: dst.clone(),
        original: original_hash,
        temporary: None,
        cache: None,
        cached: false,
    };
    if op == Operation::Sync
        && ((options.event == Event::Start
            && (entry.trigger == Trigger::Never
                || (entry.trigger == Trigger::OnInit && original.is_some())))
            || (entry.policy == Policy::Seed && original.is_some()))
    {
        return Ok(plan);
    }
    ensure!(!entry.sources.is_empty(), "source list is empty");
    if op == Operation::Sync {
        ensure!(
            entry.prune_key_contains.is_empty()
                && entry.prune_value_contains.is_empty()
                && entry.transform.is_empty(),
            "pruning/transform options belong to snapshot entries"
        );
    }
    let format = entry.format.unwrap_or_else(|| Format::infer(&dst));
    let mut hasher = blake3::Hasher::new();
    hash_field(&mut hasher, b"sync-snap-cache-v1");
    hash_field(&mut hasher, env!("CARGO_PKG_VERSION").as_bytes());
    hash_field(&mut hasher, &serde_json::to_vec(entry)?);
    hash_field(&mut hasher, dst.as_os_str().as_encoded_bytes());
    let mut inputs = Vec::new();
    for source in &entry.sources {
        let (path, input_format, optional) = source.parts();
        let path = resolve(path, options.base)?;
        hash_field(&mut hasher, path.as_os_str().as_encoded_bytes());
        match files::read_optional(&path)? {
            Some(bytes) => {
                let canonical = fs::canonicalize(&path)?;
                ensure!(
                    canonical != dst,
                    "source and destination refer to the same file: {}",
                    dst.display()
                );
                hasher.update(&[1]);
                hash_field(&mut hasher, &bytes);
                inputs.push((
                    path.clone(),
                    input_format.unwrap_or_else(|| Format::infer(&path)),
                    bytes,
                ));
            }
            None if optional => {
                hasher.update(&[0]);
            }
            None => bail!("required source is missing: {}", path.display()),
        }
    }
    // All optional sources absent: no export/reset, even when an old destination exists.
    if inputs.is_empty() {
        return Ok(plan);
    }
    let key = dst.to_string_lossy().into_owned();
    let before = fingerprint(&hasher, original.as_deref());
    if op == Operation::Sync && cache.get(&key) == Some(&before) {
        plan.cache = Some(before);
        plan.cached = true;
        return Ok(plan);
    }
    let output = if format == Format::Raw {
        ensure!(
            entry.sources.len() == 1,
            "raw copying requires exactly one source"
        );
        ensure!(
            op != Operation::Sync || matches!(entry.policy, Policy::Seed | Policy::Replace),
            "raw copying supports only seed/replace"
        );
        ensure!(
            entry.prune_key_contains.is_empty()
                && entry.prune_value_contains.is_empty()
                && entry.transform.is_empty(),
            "raw copying cannot prune or transform data"
        );
        inputs.pop().unwrap().2
    } else {
        let mut combined: Option<Value> = None;
        for (path, format, bytes) in inputs {
            let value = data::parse(&bytes, format)
                .with_context(|| format!("parse source {}", path.display()))?;
            ensure!(
                value.is_object() || value.is_array(),
                "source must contain an object/array document: {}",
                path.display()
            );
            if let Some(base) = &mut combined {
                data::merge(base, value, true);
            } else {
                combined = Some(value);
            }
        }
        let mut value = combined.unwrap();
        if op == Operation::Sync
            && matches!(entry.policy, Policy::Merge | Policy::FillMissing)
            && let Some(bytes) = &original
        {
            let mut runtime = data::parse(bytes, format).context("parse existing destination")?;
            ensure!(
                runtime.is_object() || runtime.is_array(),
                "destination must contain an object/array document"
            );
            data::merge(&mut runtime, value, entry.policy == Policy::Merge);
            value = runtime;
        }
        if op == Operation::Snapshot {
            value = data::Pruner::new(&entry.prune_key_contains, &entry.prune_value_contains)?
                .apply(value);
            value = data::transform(value, &entry.transform, options.jq)?;
        }
        data::encode(&value, format).context("serialize destination")?
    };
    plan.cache = (op == Operation::Sync).then(|| fingerprint(&hasher, Some(&output)));
    if original.as_deref() != Some(output.as_slice()) {
        plan.temporary = Some(files::stage(&dst, &output)?);
    }
    Ok(plan)
}

fn unchanged(plan: &Planned) -> Result<()> {
    files::check_leaf(&plan.destination)?;
    ensure!(
        files::read_optional(&plan.destination)?
            .as_deref()
            .map(files::digest)
            == plan.original,
        "destination changed during operation; refusing overwrite: {}",
        plan.destination.display()
    );
    Ok(())
}

fn commit(
    mut plan: Planned,
    op: Operation,
    cache: &mut BTreeMap<String, String>,
    stats: &mut Stats,
) -> Result<()> {
    unchanged(&plan)?;
    if let Some(temp) = plan.temporary.take() {
        files::publish(temp, &plan.destination)?;
        stats.written += 1;
    } else {
        stats.skipped += 1;
        stats.cached += usize::from(plan.cached);
    }
    if let Some(value) = plan.cache {
        cache.insert(plan.destination.to_string_lossy().into_owned(), value);
    }
    files::clear_error(&plan.destination, op.name());
    Ok(())
}

/// Directory mode is an overlay of raw files, never a directory replacement.
/// Runtime-only files and files removed from the source remain untouched.
fn expand(entry: &Entry, base: &Path) -> Result<Vec<Entry>> {
    if !entry.directory {
        return Ok(vec![entry.clone()]);
    }
    ensure!(
        entry.sources.len() == 1,
        "directory copying requires exactly one source"
    );
    ensure!(
        matches!(entry.policy, Policy::Seed | Policy::Replace),
        "directory copying supports seed/replace"
    );
    ensure!(
        entry.format.is_none() || entry.format == Some(Format::Raw),
        "directory copying uses raw format"
    );
    ensure!(
        entry.prune_key_contains.is_empty()
            && entry.prune_value_contains.is_empty()
            && entry.transform.is_empty(),
        "directory copying cannot apply structured filters; select files individually"
    );
    let (source, _, optional) = entry.sources[0].parts();
    let source = resolve(source, base)?;
    let target = resolve(&entry.destination, base)?;
    match fs::metadata(&source) {
        Err(e) if e.kind() == ErrorKind::NotFound && optional => return Ok(vec![]),
        Err(e) => return Err(e).with_context(|| format!("inspect directory {}", source.display())),
        Ok(m) => ensure!(
            m.is_dir(),
            "directory source is not a directory: {}",
            source.display()
        ),
    }
    let canonical = fs::canonicalize(&source)?;
    // Resolve target as a directory without following its leaf if already a link.
    ensure!(
        !fs::symlink_metadata(&target).is_ok_and(|m| m.file_type().is_symlink()),
        "directory destination is a symlink"
    );
    let target_identity = files::destination(&target.join(".sync-snap-directory-probe"))?
        .parent()
        .unwrap()
        .to_owned();
    ensure!(
        !target_identity.starts_with(&canonical) && !canonical.starts_with(&target_identity),
        "source and destination directories overlap"
    );
    fn walk(
        src: &Path,
        dst: &Path,
        template: &Entry,
        parents: &mut BTreeSet<PathBuf>,
        out: &mut Vec<Entry>,
    ) -> Result<()> {
        let real = fs::canonicalize(src)?;
        ensure!(
            parents.insert(real.clone()),
            "source directory symlink cycle: {}",
            src.display()
        );
        let mut children: Vec<_> = fs::read_dir(src)?.collect::<std::io::Result<_>>()?;
        children.sort_by_key(|e| e.file_name());
        for child in children {
            let path = child.path();
            let target = dst.join(child.file_name());
            let metadata = fs::metadata(&path)?;
            if metadata.is_dir() {
                walk(&path, &target, template, parents, out)?;
            } else {
                ensure!(
                    metadata.is_file(),
                    "directory contains a non-regular source: {}",
                    path.display()
                );
                let mut e = template.clone();
                e.destination = target
                    .to_str()
                    .context("non-UTF-8 destination filename")?
                    .to_owned();
                e.sources = vec![Source::Path(
                    path.to_str()
                        .context("non-UTF-8 source filename")?
                        .to_owned(),
                )];
                e.directory = false;
                e.format = Some(Format::Raw);
                out.push(e);
            }
        }
        parents.remove(&real);
        Ok(())
    }
    let mut out = Vec::new();
    walk(&source, &target, entry, &mut BTreeSet::new(), &mut out)?;
    Ok(out)
}

fn destinations(entries: &[Entry], base: &Path) -> Vec<PathBuf> {
    entries
        .iter()
        .filter_map(|e| resolve(&e.destination, base).ok())
        .collect()
}

pub fn execute(name: &str, program: &Program, op: Operation, options: &Options<'_>) -> Stats {
    let entries = match op {
        Operation::Sync => &program.sync,
        Operation::Snapshot => &program.snapshot,
    };
    let mut stats = Stats::default();
    if entries.is_empty() {
        return stats;
    }
    let _lock = match files::lock(options.state, name, options.timeout) {
        Ok(lock) => lock,
        Err(e) => {
            for dst in destinations(entries, options.base) {
                files::report(&dst, op.name(), &e);
            }
            stats.failed += 1;
            return stats;
        }
    };
    let cache_path = options
        .state
        .join(format!("{}.json", files::digest(name.as_bytes())));
    let mut cache: BTreeMap<String, String> = fs::read(&cache_path)
        .ok()
        .and_then(|b| serde_json::from_slice(&b).ok())
        .unwrap_or_default();
    let mut plans = Vec::new();
    let mut seen = BTreeSet::new();
    for original_entry in entries {
        if op == Operation::Sync
            && options.event == Event::Start
            && original_entry.trigger == Trigger::Never
        {
            continue;
        }
        let expanded = match expand(original_entry, options.base) {
            Ok(es) => {
                if original_entry.directory
                    && let Ok(dst) = resolve(&original_entry.destination, options.base)
                {
                    files::clear_error(&dst, op.name());
                }
                es
            }
            Err(e) => {
                if let Ok(dst) = resolve(&original_entry.destination, options.base) {
                    files::report(&dst, op.name(), &e);
                } else {
                    eprintln!("sync-snap: {e:#}");
                }
                stats.failed += 1;
                continue;
            }
        };
        for entry in expanded {
            let result = (|| {
                let dst = files::destination(&resolve(&entry.destination, options.base)?)?;
                ensure!(seen.insert(dst), "duplicate destination in program {name}");
                prepare(&entry, op, options, &cache)
            })();
            match result {
                Ok(plan) if op == Operation::Sync => plans.push(plan),
                Ok(plan) => {
                    let dst = plan.destination.clone();
                    if let Err(e) = commit(plan, op, &mut cache, &mut stats) {
                        files::report(&dst, op.name(), &e);
                        stats.failed += 1;
                    }
                }
                Err(e) => {
                    if let Ok(dst) = resolve(&entry.destination, options.base) {
                        files::report(&dst, op.name(), &e);
                    } else {
                        eprintln!("sync-snap: {e:#}");
                    }
                    stats.failed += 1;
                }
            }
        }
    }
    if op == Operation::Sync {
        let mut changed_destinations = BTreeSet::new();
        if stats.failed == 0 {
            for plan in &plans {
                if let Err(e) = unchanged(plan) {
                    files::report(&plan.destination, op.name(), &e);
                    changed_destinations.insert(plan.destination.clone());
                    stats.failed += 1;
                }
            }
        }
        if stats.failed != 0 {
            for plan in plans {
                if changed_destinations.contains(&plan.destination) {
                    continue;
                }
                files::report(
                    &plan.destination,
                    op.name(),
                    &anyhow::anyhow!("program validation failed; no configuration files published"),
                );
            }
        } else {
            for plan in plans {
                let dst = plan.destination.clone();
                if let Err(e) = commit(plan, op, &mut cache, &mut stats) {
                    files::report(&dst, op.name(), &e);
                    stats.failed += 1;
                    // Publication is per file. Do not pretend earlier renames rolled back.
                    break;
                }
            }
            if stats.failed == 0 {
                let bytes = serde_json::to_vec(&cache).expect("string map serializes");
                // Cache failure is diagnostic only: content was already synchronized.
                if fs::read(&cache_path).ok().as_deref() != Some(bytes.as_slice())
                    && let Err(e) = files::atomic_write(&cache_path, &bytes)
                {
                    eprintln!("sync-snap: could not save cache: {e:#}");
                }
            }
        }
    }
    stats
}
