//! Startup eligibility, separate from the destination-sensitive sync cache.
use crate::config::{Entry, Trigger};
use anyhow::{Context as _, Result, bail, ensure};
use serde::{Deserialize, Serialize};
use std::{
    collections::{BTreeMap, BTreeSet},
    env, fs,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

#[derive(Clone, Debug)]
pub struct Context {
    pub boot_id: Option<String>,
    pub session_id: Option<String>,
    pub epoch: u64,
}
impl Context {
    pub fn current() -> Self {
        Self {
            boot_id: fs::read_to_string("/proc/sys/kernel/random/boot_id")
                .ok()
                .map(|s| s.trim().to_owned())
                .filter(|s| !s.is_empty()),
            session_id: env::var("XDG_SESSION_ID").ok().filter(|s| !s.is_empty()),
            epoch: Self::epoch_now(),
        }
    }

    pub fn epoch_now() -> u64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs()
    }
}

#[derive(Debug, Deserialize, Serialize)]
pub struct Record {
    pub input_fingerprint: String,
    pub boot_id: Option<String>,
    pub session_ids: BTreeSet<String>,
    pub last_success_epoch: u64,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct State {
    version: u32,
    pub files: BTreeMap<String, Record>,
}
impl Default for State {
    fn default() -> Self {
        Self {
            version: 1,
            files: BTreeMap::new(),
        }
    }
}
impl State {
    pub fn record_success(
        &mut self,
        destination: String,
        input_fingerprint: String,
        now: &Context,
    ) {
        let mut session_ids = self
            .files
            .get(&destination)
            .filter(|record| {
                record.input_fingerprint == input_fingerprint && record.boot_id == now.boot_id
            })
            .map(|record| record.session_ids.clone())
            .unwrap_or_default();
        if let Some(id) = &now.session_id {
            session_ids.insert(id.clone());
        }
        self.files.insert(
            destination,
            Record {
                input_fingerprint,
                boot_id: now.boot_id.clone(),
                session_ids,
                last_success_epoch: now.epoch,
            },
        );
    }
    pub fn read(path: &Path) -> Self {
        fs::read(path)
            .ok()
            .and_then(|bytes| serde_json::from_slice::<Self>(&bytes).ok())
            .filter(|state| state.version == 1)
            .unwrap_or_default()
    }
}

pub fn state_path(directory: &Path, program: &str) -> PathBuf {
    // Keep ordinary binary names readable without allowing path traversal.
    let name: String = program
        .bytes()
        .map(|b| {
            if b.is_ascii_alphanumeric() || matches!(b, b'-' | b'_' | b'.') {
                char::from(b).to_string()
            } else {
                format!("%{b:02x}")
            }
        })
        .collect();
    directory.join(format!("{name}.trigger"))
}

pub fn duration_seconds(entry: &Entry) -> Result<Option<u64>> {
    if entry.trigger != Trigger::OnDuration {
        ensure!(
            entry.duration.is_none(),
            "duration requires trigger onDuration"
        );
        return Ok(None);
    }
    let text = entry
        .duration
        .as_deref()
        .context("onDuration requires duration (for example 1h)")?;
    let split = text
        .find(|c: char| !c.is_ascii_digit())
        .unwrap_or(text.len());
    let amount: u64 = text[..split]
        .parse()
        .context("duration requires a positive integer and unit")?;
    let unit = match &text[split..] {
        "s" => 1,
        "m" | "min" => 60,
        "h" | "hr" => 3600,
        "d" => 86400,
        _ => bail!("duration unit must be s, m/min, h/hr, or d"),
    };
    ensure!(amount > 0, "duration must be positive");
    Ok(Some(
        amount.checked_mul(unit).context("duration is too large")?,
    ))
}

pub fn due(
    trigger: Trigger,
    duration: Option<u64>,
    record: Option<&Record>,
    input_fingerprint: &str,
    destination_exists: bool,
    now: &Context,
) -> bool {
    if !destination_exists {
        return true;
    }
    let Some(record) = record else {
        return true;
    };
    if record.input_fingerprint != input_fingerprint {
        return true;
    }
    match trigger {
        Trigger::OnEveryStart => true,
        Trigger::OnEveryBoot => now.boot_id.is_none() || now.boot_id != record.boot_id,
        Trigger::OnEveryLogin => {
            now.boot_id.is_none()
                || now.boot_id != record.boot_id
                || now
                    .session_id
                    .as_ref()
                    .is_some_and(|id| !record.session_ids.contains(id))
        }
        Trigger::OnDuration => {
            now.epoch.saturating_sub(record.last_success_epoch)
                >= duration.expect("validated duration")
        }
    }
}
