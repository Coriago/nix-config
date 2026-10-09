//! Ordered, manifest-free file declarations. Each --destination starts an entry.
use anyhow::{Context, Result, ensure};
use clap::{ArgMatches, Args};
use sync_snap::config::{Entry, Source};

#[derive(Args)]
#[group(multiple = true)]
pub struct Direct {
    /// Start a file entry; following file options apply until the next destination.
    #[arg(long, conflicts_with = "config")]
    destination: Vec<String>,
    /// Append a source to the current file entry (repeat for layered inputs).
    #[arg(long, requires = "destination")]
    source: Vec<String>,
    /// Format of the most recent source: json, toml, raw.
    #[arg(long, requires = "destination")]
    source_format: Vec<String>,
    /// Whether the most recent source may be absent: true or false.
    #[arg(long, requires = "destination")]
    source_optional: Vec<String>,
    /// Current file's output format: json, toml, raw; otherwise inferred.
    #[arg(long, requires = "destination")]
    format: Vec<String>,
    /// Current file's sync policy: seed (CLI default), fill-missing, merge, replace.
    #[arg(long, requires = "destination")]
    policy: Vec<String>,
    /// Current file's startup trigger: on-start (default), on-init, never.
    #[arg(long, requires = "destination")]
    trigger: Vec<String>,
    /// Current entry is a raw directory overlay: true or false.
    #[arg(long, requires = "destination")]
    directory: Vec<String>,
    /// Append a snapshot key-path pruning regex to the current entry.
    #[arg(long, requires = "destination", allow_hyphen_values = true)]
    prune_key_contains: Vec<String>,
    /// Append a snapshot value pruning regex to the current entry.
    #[arg(long, requires = "destination", allow_hyphen_values = true)]
    prune_value_contains: Vec<String>,
    /// Append a jq snapshot filter to the current entry.
    #[arg(long, requires = "destination", allow_hyphen_values = true)]
    transform: Vec<String>,
}

pub fn entries(matches: &ArgMatches) -> Result<Vec<Entry>> {
    let mut ordered = Vec::new();
    for key in [
        "destination",
        "source",
        "source_format",
        "source_optional",
        "format",
        "policy",
        "trigger",
        "directory",
        "prune_key_contains",
        "prune_value_contains",
        "transform",
    ] {
        if let Some(indices) = matches.indices_of(key) {
            let values = matches
                .get_many::<String>(key)
                .expect("values have indices");
            ordered.extend(
                indices
                    .zip(values)
                    .map(|(index, value)| (index, key, value)),
            );
        }
    }
    ordered.sort_by_key(|(index, _, _)| *index);
    let mut result: Vec<Entry> = Vec::new();
    for (_, key, value) in ordered {
        if key == "destination" {
            result.push(serde_json::from_value(
                serde_json::json!({"destination": value, "sources": []}),
            )?);
            continue;
        }
        let entry = result
            .last_mut()
            .context("file options must follow --destination")?;
        let parsed = || serde_json::Value::String(value.clone());
        match key {
            "source" => entry.sources.push(Source::Options {
                path: value.clone(),
                format: None,
                optional: false,
            }),
            "source_format" | "source_optional" => {
                let Source::Options {
                    format, optional, ..
                } = entry
                    .sources
                    .last_mut()
                    .context("source options must follow --source")?
                else {
                    unreachable!()
                };
                if key == "source_format" {
                    *format =
                        Some(serde_json::from_value(parsed()).context("invalid source format")?);
                } else {
                    *optional = value
                        .parse()
                        .context("source-optional requires true or false")?;
                }
            }
            "format" => {
                entry.format =
                    Some(serde_json::from_value(parsed()).context("invalid output format")?)
            }
            "policy" => {
                entry.policy = serde_json::from_value(parsed()).context("invalid policy")?
            }
            "trigger" => {
                entry.trigger = serde_json::from_value(parsed()).context("invalid trigger")?
            }
            "directory" => {
                entry.directory = value.parse().context("directory requires true or false")?
            }
            "prune_key_contains" => entry.prune_key_contains.push(value.clone()),
            "prune_value_contains" => entry.prune_value_contains.push(value.clone()),
            "transform" => entry.transform.push(value.clone()),
            _ => unreachable!(),
        }
    }
    ensure!(
        !result.is_empty(),
        "supply --destination and --source, or --config"
    );
    Ok(result)
}
