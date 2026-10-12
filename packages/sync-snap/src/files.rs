use anyhow::{Context, Result, bail, ensure};
use std::{
    fs::{self, File, OpenOptions, TryLockError},
    io::{ErrorKind, Write},
    os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt},
    path::{Path, PathBuf},
    thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};
use tempfile::NamedTempFile;

pub fn mkdir(path: &Path) -> Result<()> {
    fs::DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(path)
        .with_context(|| format!("create directory {}", path.display()))
}

/// Resolve parent aliases for consistent cache/destination identity, but never
/// follow the destination leaf: replacing HM symlinks is an ownership mistake.
pub fn destination(path: &Path) -> Result<PathBuf> {
    let parent = path
        .parent()
        .context("destination needs a parent directory")?;
    let name = path.file_name().context("destination needs a filename")?;
    fn real_parent(path: &Path) -> Result<PathBuf> {
        match fs::canonicalize(path) {
            Ok(p) => Ok(p),
            Err(e) if e.kind() == ErrorKind::NotFound => {
                // A dangling symlink is not a missing directory to create.
                ensure!(
                    !fs::symlink_metadata(path).is_ok_and(|m| m.file_type().is_symlink()),
                    "dangling parent symlink: {}",
                    path.display()
                );
                Ok(
                    real_parent(path.parent().context("cannot resolve parent")?)?
                        .join(path.file_name().context("missing parent name")?),
                )
            }
            Err(e) => Err(e).with_context(|| format!("resolve {}", path.display())),
        }
    }
    let dst = real_parent(parent)?.join(name);
    check_leaf(&dst)?;
    Ok(dst)
}

pub fn check_leaf(path: &Path) -> Result<()> {
    match fs::symlink_metadata(path) {
        Ok(m) => ensure!(
            m.is_file() && !m.file_type().is_symlink(),
            "destination must be a regular file, not a symlink/directory: {}",
            path.display()
        ),
        Err(e) if e.kind() == ErrorKind::NotFound => (),
        Err(e) => return Err(e).with_context(|| format!("inspect {}", path.display())),
    }
    Ok(())
}

pub fn read_optional(path: &Path) -> Result<Option<Vec<u8>>> {
    match fs::metadata(path) {
        Ok(m) => ensure!(
            m.is_file(),
            "source is not a regular file: {}",
            path.display()
        ),
        Err(e) if e.kind() == ErrorKind::NotFound => return Ok(None),
        Err(e) => return Err(e).with_context(|| format!("inspect {}", path.display())),
    }
    fs::read(path)
        .map(Some)
        .with_context(|| format!("read {}", path.display()))
}

pub fn digest(bytes: &[u8]) -> String {
    blake3::hash(bytes).to_hex().to_string()
}

pub fn stage(path: &Path, bytes: &[u8]) -> Result<NamedTempFile> {
    check_leaf(path)?;
    let parent = path.parent().context("missing parent")?;
    mkdir(parent)?;
    let mut temp = tempfile::Builder::new()
        .prefix(".sync-snap-")
        .tempfile_in(parent)
        .with_context(|| format!("stage {}", path.display()))?;
    if let Ok(m) = fs::metadata(path) {
        temp.as_file()
            .set_permissions(fs::Permissions::from_mode(m.permissions().mode() & 0o777))?;
    }
    temp.write_all(bytes)
        .with_context(|| format!("write staged {}", path.display()))?;
    temp.as_file()
        .sync_all()
        .with_context(|| format!("flush staged {}", path.display()))?;
    Ok(temp)
}

pub fn publish(temp: NamedTempFile, path: &Path) -> Result<()> {
    check_leaf(path)?;
    temp.persist(path)
        .map_err(|e| e.error)
        .with_context(|| format!("publish {}", path.display()))?;
    File::open(path.parent().context("missing parent")?)?
        .sync_all()
        .with_context(|| {
            format!(
                "flush parent of {} (file was already published)",
                path.display()
            )
        })
}

pub fn atomic_write(path: &Path, bytes: &[u8]) -> Result<()> {
    publish(stage(path, bytes)?, path)
}

pub fn sidecar(dst: &Path, operation: &str) -> PathBuf {
    let mut name = std::ffi::OsString::from(".");
    name.push(dst.file_name().unwrap_or_default());
    name.push(format!(".{operation}-error.log"));
    dst.with_file_name(name)
}

pub fn report(dst: &Path, operation: &str, error: &anyhow::Error) {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs();
    let text = format!(
        "unix_time={stamp}\noperation={operation}\ndestination={}\nerror={error:#}\n",
        dst.display()
    );
    eprintln!("sync-snap: {operation} {}: {error:#}", dst.display());
    if let Err(e) = atomic_write(&sidecar(dst, operation), text.as_bytes()) {
        eprintln!("sync-snap: could not write error sidecar: {e:#}");
    }
}

pub fn clear_error(dst: &Path, operation: &str) {
    if let Err(e) = fs::remove_file(sidecar(dst, operation))
        && e.kind() != ErrorKind::NotFound
    {
        eprintln!(
            "sync-snap: could not clear error sidecar for {}: {e}",
            dst.display()
        );
    }
}

pub fn lock(state: &Path, program: &str, timeout: Duration) -> Result<File> {
    mkdir(state)?;
    let path = state.join(format!("{}.lock", digest(program.as_bytes())));
    check_leaf(&path)?;
    let f = OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .mode(0o600)
        .open(&path)
        .with_context(|| format!("open lock {}", path.display()))?;
    let start = Instant::now();
    loop {
        match f.try_lock() {
            Ok(()) => return Ok(f),
            Err(TryLockError::WouldBlock) if start.elapsed() < timeout => {
                thread::sleep(Duration::from_millis(10))
            }
            Err(TryLockError::WouldBlock) => {
                bail!("program lock busy for {} ms", timeout.as_millis())
            }
            Err(TryLockError::Error(e)) => return Err(e).context("acquire program lock"),
        }
    }
    // The stable lock file stays on disk; closing the handle releases the lock.
}
