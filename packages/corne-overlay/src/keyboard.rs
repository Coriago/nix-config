use crate::layers::{Active, Layers, Layout, Pressed, UID};
use anyhow::{bail, ensure, Context, Result};
use std::{
    fs::{self, File, OpenOptions},
    io::{Read, Write},
    os::{fd::AsRawFd, unix::fs::OpenOptionsExt},
    sync::{Arc, Mutex},
    thread,
    time::{Duration, Instant},
};

pub struct Keyboard {
    file: File,
    pub term: Duration,
}
impl Keyboard {
    pub fn open() -> Result<Self> {
        for entry in fs::read_dir("/sys/class/hidraw")? {
            let entry = entry?;
            let device = entry.path().join("device");
            let event = fs::read_to_string(device.join("uevent"))?;
            if !event.contains("Pilot W-CORNE") {
                continue;
            }
            if !fs::read(device.join("report_descriptor"))?.starts_with(&[0x06, 0x60, 0xff]) {
                continue;
            }
            let file = OpenOptions::new()
                .read(true)
                .write(true)
                .custom_flags(libc::O_NONBLOCK)
                .open(std::path::Path::new("/dev").join(entry.file_name()))?;
            // Advisory lock avoids two overlay instances racing for the same reports.
            ensure!(
                unsafe { libc::flock(file.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } == 0,
                "Another overlay is using this keyboard"
            );
            let mut keyboard = Self {
                file,
                term: Duration::ZERO,
            };
            let reply = keyboard.query(&[0xfe, 0])?;
            ensure!(
                u64::from_le_bytes(reply[4..12].try_into()?) == UID,
                "Unexpected Vial keyboard UID"
            );
            keyboard.check_unlocked()?;
            let reply = keyboard.query(&[0xfe, 10, 7, 0])?;
            ensure!(reply[0] == 0, "Cannot read live tapping term");
            let ms = u16::from_le_bytes([reply[1], reply[2]]);
            ensure!(
                ms > 0 && ms <= 10000,
                "Invalid tapping term; close other Vial clients"
            );
            keyboard.term = Duration::from_millis(ms.into());
            return Ok(keyboard);
        }
        bail!("W-CORNE raw HID interface not connected")
    }
    fn query(&mut self, payload: &[u8]) -> Result<[u8; 32]> {
        let mut report = [0u8; 33];
        report[1..1 + payload.len()].copy_from_slice(payload);
        self.file.write_all(&report)?;
        let mut poll = libc::pollfd {
            fd: self.file.as_raw_fd(),
            events: libc::POLLIN,
            revents: 0,
        };
        ensure!(
            unsafe { libc::poll(&mut poll, 1, 300) } > 0,
            "Vial query timed out"
        );
        let mut reply = [0; 32];
        ensure!(self.file.read(&mut reply)? == 32, "Incomplete Vial reply");
        Ok(reply)
    }
    fn check_unlocked(&mut self) -> Result<()> {
        ensure!(
            self.query(&[0xfe, 5])?[0] == 1,
            "Matrix access locked; unlock in Vial first"
        );
        Ok(())
    }
    pub fn pressed(&mut self) -> Result<Pressed> {
        let data = self.query(&[2, 3])?;
        ensure!(
            data[..2] == [2, 3],
            "Unexpected reply; close other Vial clients"
        );
        let mut result = Pressed::new();
        for r in 0..4 {
            let bits = u16::from_be_bytes([data[2 + r * 2], data[3 + r * 2]]);
            for c in 0..12 {
                if ![(2, 6), (3, 2)].contains(&(r, c)) && bits & (1 << c) != 0 {
                    result.insert((r, c));
                }
            }
        }
        Ok(result)
    }
}

#[derive(Clone, PartialEq, Eq)]
pub struct Snapshot {
    pub active: Active,
    pub pressed: Pressed,
}
impl Default for Snapshot {
    fn default() -> Self {
        Self {
            active: Active::from([0]),
            pressed: Pressed::new(),
        }
    }
}
pub fn spawn(layout: Layout, hold_ms: Option<u64>, shared: Arc<Mutex<Snapshot>>) {
    thread::spawn(move || {
        let mut previous_error = String::new();
        loop {
            let result = (|| -> Result<()> {
                let mut keyboard = Keyboard::open().context("Connecting keyboard")?;
                let term = hold_ms.map(Duration::from_millis).unwrap_or(keyboard.term);
                eprintln!(
                    "Connected W-CORNE; display hold threshold {} ms",
                    term.as_millis()
                );
                previous_error.clear();
                let mut state = Layers::new(layout.clone(), term);
                let start = Instant::now();
                let mut checked = Instant::now();
                loop {
                    if checked.elapsed() >= Duration::from_secs(1) {
                        keyboard.check_unlocked()?;
                        checked = Instant::now();
                    }
                    let pressed = keyboard.pressed()?;
                    state.update(&pressed, start.elapsed());
                    *shared.lock().unwrap() = Snapshot {
                        active: state.active.clone(),
                        pressed,
                    };
                    thread::sleep(Duration::from_millis(25));
                }
            })();
            *shared.lock().unwrap() = Snapshot::default();
            if let Err(error) = result {
                let message = format!("{error:#}");
                if message != previous_error {
                    eprintln!("{message}");
                    previous_error = message;
                }
            }
            thread::sleep(Duration::from_secs(2));
        }
    });
}
