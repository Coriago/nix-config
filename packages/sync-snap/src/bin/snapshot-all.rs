use clap::Parser;
use std::{
    collections::BTreeMap,
    env,
    ffi::OsString,
    fs,
    path::PathBuf,
    process::{Command, ExitCode},
    time::Instant,
};

/// Capture preferences for wrappers installed in active Nix profiles.
#[derive(Parser)]
struct Args {
    /// Override profile discovery; repeat in highest-to-lowest priority order.
    #[arg(long)]
    profile: Vec<PathBuf>,
    /// Show selected registrations without executing them.
    #[arg(long)]
    list: bool,
    /// Arguments forwarded to every snapshot command (after --).
    #[arg(last = true)]
    arguments: Vec<OsString>,
}

fn default_profiles() -> Vec<PathBuf> {
    let mut profiles = Vec::new();
    if let Some(home) = env::var_os("HOME").map(PathBuf::from) {
        profiles.push(home.join(".nix-profile"));
        let state = env::var_os("XDG_STATE_HOME")
            .map(PathBuf::from)
            .filter(|p| p.is_absolute())
            .unwrap_or_else(|| home.join(".local/state"));
        profiles.push(state.join("nix/profile"));
    }
    if let Ok(user) = env::var("USER") {
        if !user.is_empty() && !user.contains('/') && user != "." && user != ".." {
            profiles.push(PathBuf::from("/etc/profiles/per-user").join(user));
        }
    }
    profiles.extend(
        [
            "/nix/profile",
            "/nix/var/nix/profiles/default",
            "/run/current-system/sw",
        ]
        .map(PathBuf::from),
    );
    profiles
}

fn discover(profiles: &[PathBuf]) -> anyhow::Result<BTreeMap<OsString, PathBuf>> {
    let mut entries = BTreeMap::new();
    for profile in profiles {
        // Resolve once: commands from one profile use the same generation.
        let root = match fs::canonicalize(profile) {
            Ok(root) => root,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => continue,
            Err(e) => return Err(anyhow::anyhow!("{}: {e}", profile.display())),
        };
        let directory = root.join("share/sync-snap/snapshots");
        let files = match fs::read_dir(&directory) {
            Ok(files) => files,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => continue,
            Err(e) => return Err(anyhow::anyhow!("{}: {e}", directory.display())),
        };
        for file in files {
            let file = file?;
            entries
                .entry(file.file_name())
                .or_insert_with(|| file.path());
        }
    }
    Ok(entries)
}

fn main() -> ExitCode {
    let args = Args::parse();
    let profiles = if args.profile.is_empty() {
        default_profiles()
    } else {
        args.profile
    };
    let entries = match discover(&profiles) {
        Ok(entries) => entries,
        Err(error) => {
            eprintln!("snapshot-all: {error:#}");
            return ExitCode::FAILURE;
        }
    };
    if entries.is_empty() {
        eprintln!("snapshot-all: no installed snapshot registrations");
    }
    let mut failed = false;
    for (name, path) in entries {
        if args.list {
            println!("{}\t{}", name.to_string_lossy(), path.display());
            continue;
        }
        let start = Instant::now();
        let result = Command::new(&path).args(&args.arguments).status();
        let success = matches!(&result, Ok(status) if status.success());
        failed |= !success;
        eprintln!(
            "snapshot-all: {} {} elapsed_ms={:.3}",
            name.to_string_lossy(),
            if success { "completed" } else { "failed" },
            start.elapsed().as_secs_f64() * 1000.0
        );
        match result {
            Err(error) => eprintln!("snapshot-all: {}: {error}", path.display()),
            Ok(status) if !status.success() => eprintln!("snapshot-all: {status}"),
            _ => {}
        }
    }
    if failed {
        ExitCode::FAILURE
    } else {
        ExitCode::SUCCESS
    }
}
