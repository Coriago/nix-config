use anyhow::{Context, Result, ensure};
use clap::{ArgMatches, Args, CommandFactory, FromArgMatches, Parser, Subcommand};
mod direct;
use std::{
    ffi::OsString,
    fs,
    os::unix::process::CommandExt,
    path::PathBuf,
    process::{Command, ExitCode},
    time::Duration,
};
use sync_snap::{
    config::{Manifest, Program, resolve, variable},
    engine::{self, Event, Operation, Options},
};

#[derive(Parser)]
#[command(version, about)]
struct Cli {
    #[command(subcommand)]
    command: Action,
}
#[derive(Subcommand)]
enum Action {
    /// Synchronize configuration; return nonzero if any program fails.
    Sync {
        #[command(flatten)]
        selection: Selection,
        /// Honor per-file startup triggers. Without this, bypass trigger schedules.
        #[arg(long)]
        startup: bool,
    },
    /// Export each snapshot independently; return nonzero if any file fails.
    Snapshot {
        #[command(flatten)]
        selection: Selection,
    },
    /// Attempt startup sync, then exec the application even when sync fails.
    Run {
        #[command(flatten)]
        selection: Selection,
        #[arg(last = true, required = true, num_args = 1..)]
        command: Vec<OsString>,
    },
}
#[derive(Args)]
#[command(group(clap::ArgGroup::new("selection").required(true).args(["program", "all"])))]
struct Selection {
    /// JSON or TOML manifest (version 1).
    #[arg(long)]
    config: Option<PathBuf>,
    #[command(flatten)]
    direct: direct::Direct,
    #[arg(long, conflicts_with = "all")]
    program: Option<String>,
    #[arg(long, requires = "config")]
    all: bool,
    /// Override the shared lock/hash directory; default: $XDG_STATE_HOME/sync-snap.
    #[arg(long)]
    state_dir: Option<PathBuf>,
    /// Maximum wait for another sync/snapshot invocation of this program.
    #[arg(long, default_value_t = 2000)]
    lock_timeout_ms: u64,
    /// jq executable used only for explicitly configured snapshot transforms.
    #[arg(long, default_value = "jq")]
    jq: String,
}

fn perform(
    selection: &Selection,
    op: Operation,
    event: Event,
    matches: &ArgMatches,
) -> Result<bool> {
    let (manifest, base) = if let Some(config) = &selection.config {
        let path = fs::canonicalize(config).context("locate manifest")?;
        let base = path.parent().context("manifest has no parent directory")?;
        let input = fs::read_to_string(&path).context("read manifest")?;
        let manifest: Manifest = if path.extension().is_some_and(|e| e == "toml") {
            toml::from_str(&input).context("invalid TOML manifest")?
        } else {
            serde_json::from_str(&input).context("invalid JSON manifest")?
        };
        ensure!(
            manifest.version == 1,
            "unsupported manifest version {}",
            manifest.version
        );
        if let Some(name) = &selection.program {
            ensure!(
                manifest.programs.contains_key(name),
                "unknown program: {name}"
            );
        }
        (manifest, base.to_path_buf())
    } else {
        let entries = direct::entries(matches)?;
        let name = selection
            .program
            .clone()
            .context("direct arguments require --program")?;
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
        (
            Manifest {
                version: 1,
                programs: [(name, program)].into(),
            },
            std::env::current_dir()?,
        )
    };
    let state = match &selection.state_dir {
        Some(path) => resolve(
            path.to_str().context("non-UTF-8 state path")?,
            &std::env::current_dir()?,
        )?,
        None => PathBuf::from(variable("XDG_STATE_HOME")?).join("sync-snap"),
    };
    let options = Options {
        base: &base,
        state: &state,
        event,
        timeout: Duration::from_millis(selection.lock_timeout_ms),
        jq: &selection.jq,
        trigger_context: None,
    };
    let mut success = true;
    for (name, program) in &manifest.programs {
        if selection.program.as_ref().is_some_and(|n| n != name) {
            continue;
        }
        let stats = engine::execute(name, program, op, &options);
        eprintln!(
            "sync-snap: {name}: written={}, skipped={}, cache_hits={}, failed={}",
            stats.written, stats.skipped, stats.cached, stats.failed
        );
        success &= stats.failed == 0;
    }
    Ok(success)
}

fn report(result: Result<bool>) -> ExitCode {
    match result {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(e) => {
            eprintln!("sync-snap: {e:#}");
            ExitCode::FAILURE
        }
    }
}
fn main() -> ExitCode {
    let matches = Cli::command().get_matches();
    let cli = Cli::from_arg_matches(&matches).unwrap_or_else(|error| error.exit());
    let (_, arguments) = matches.subcommand().expect("required subcommand");
    match cli.command {
        Action::Sync { selection, startup } => report(perform(
            &selection,
            Operation::Sync,
            if startup { Event::Start } else { Event::Manual },
            arguments,
        )),
        Action::Snapshot { selection } => report(perform(
            &selection,
            Operation::Snapshot,
            Event::Manual,
            arguments,
        )),
        Action::Run { selection, command } => {
            let _ = report(perform(
                &selection,
                Operation::Sync,
                Event::Start,
                arguments,
            ));
            // perform's file handles, locks, and temporary files have been dropped.
            // Exec preserves application signals, arguments, and exit status.
            let e = Command::new(&command[0]).args(&command[1..]).exec();
            eprintln!("sync-snap: could not launch application: {e}");
            ExitCode::from(127)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::CommandFactory;
    #[test]
    fn cli_definition_is_valid() {
        Cli::command().debug_assert();
    }
}
