use anyhow::{Context, Result, bail, ensure};
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeMap,
    env,
    path::{Component, Path, PathBuf},
};

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub version: u32,
    pub programs: BTreeMap<String, Program>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Program {
    #[serde(default)]
    pub sync: Vec<Entry>,
    #[serde(default)]
    pub snapshot: Vec<Entry>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(deny_unknown_fields)]
pub struct Entry {
    pub destination: String,
    pub sources: Vec<Source>,
    #[serde(default)]
    pub policy: Policy,
    #[serde(default)]
    pub trigger: Trigger,
    #[serde(default)]
    pub duration: Option<String>,
    #[serde(default)]
    pub format: Option<Format>,
    #[serde(default)]
    pub directory: bool,
    #[serde(default)]
    pub prune_key_contains: Vec<String>,
    #[serde(default)]
    pub prune_value_contains: Vec<String>,
    #[serde(default)]
    pub transform: Vec<String>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(untagged, deny_unknown_fields)]
pub enum Source {
    Path(String),
    Options {
        path: String,
        #[serde(default)]
        format: Option<Format>,
        #[serde(default)]
        optional: bool,
    },
}
impl Source {
    pub fn parts(&self) -> (&str, Option<Format>, bool) {
        match self {
            Self::Path(p) => (p, None, false),
            Self::Options {
                path,
                format,
                optional,
            } => (path, *format, *optional),
        }
    }
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub enum Policy {
    #[default]
    Seed,
    FillMissing,
    Merge,
    Replace,
}
#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum Trigger {
    #[default]
    OnEveryStart,
    OnEveryBoot,
    OnEveryLogin,
    OnDuration,
}
#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Format {
    Json,
    Toml,
    Raw,
}
impl Format {
    pub fn infer(path: &Path) -> Self {
        match path.extension().and_then(|s| s.to_str()) {
            Some("json") => Self::Json,
            Some("toml") => Self::Toml,
            _ => Self::Raw,
        }
    }
}

pub fn variable(name: &str) -> Result<String> {
    let suffix = match name {
        "HOME" => return env::var("HOME").context("HOME is unset"),
        "XDG_CONFIG_HOME" => ".config",
        "XDG_STATE_HOME" => ".local/state",
        "XDG_CACHE_HOME" => ".cache",
        "XDG_DATA_HOME" => ".local/share",
        _ => bail!("unsupported path variable: {name}"),
    };
    if let Ok(v) = env::var(name)
        && Path::new(&v).is_absolute()
    {
        return Ok(v);
    }
    Ok(format!("{}/{}", variable("HOME")?, suffix))
}

pub fn resolve(input: &str, base: &Path) -> Result<PathBuf> {
    let mut rest = input;
    let mut expanded = String::new();
    if let Some(p) = rest.strip_prefix("~/") {
        expanded.push_str(&variable("HOME")?);
        expanded.push('/');
        rest = p;
    }
    while let Some((prefix, tail)) = rest.split_once("${") {
        expanded.push_str(prefix);
        let (name, after) = tail.split_once('}').context("unclosed path variable")?;
        expanded.push_str(&variable(name)?);
        rest = after;
    }
    expanded.push_str(rest);
    ensure!(!expanded.is_empty(), "empty path");
    let path = Path::new(&expanded);
    let abs = if path.is_absolute() {
        path.to_path_buf()
    } else {
        base.join(path)
    };
    // Reject parent traversal instead of guessing its meaning across symlinks.
    ensure!(
        !abs.components().any(|c| c == Component::ParentDir),
        "paths cannot contain '..'"
    );
    let clean: PathBuf = abs
        .components()
        .filter(|c| *c != Component::CurDir)
        .collect();
    Ok(clean)
}
