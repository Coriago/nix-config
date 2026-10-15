//! Read-only Umbriel IPC. Requests and replies are bounded and time out.
use crate::geometry::Rect;
use serde::Deserialize;
use serde_json::{json, Value};
use std::{
    io::{BufRead, BufReader, Read, Write},
    os::unix::net::UnixStream,
    time::Duration,
};

fn query(command: &str) -> Option<Value> {
    let path = std::env::var("UMBRIEL_SOCKET").ok().or_else(|| {
        Some(format!(
            "{}/umbriel-{}.sock",
            std::env::var("XDG_RUNTIME_DIR").ok()?,
            std::env::var("WAYLAND_DISPLAY").ok()?
        ))
    })?;
    let mut stream = UnixStream::connect(path).ok()?;
    stream
        .set_read_timeout(Some(Duration::from_millis(100)))
        .ok()?;
    stream
        .set_write_timeout(Some(Duration::from_millis(100)))
        .ok()?;
    writeln!(stream, "{}", json!({"cmd": command})).ok()?;
    let mut line = String::new();
    BufReader::new(stream.take(1_048_576))
        .read_line(&mut line)
        .ok()?;
    serde_json::from_str::<Value>(&line)
        .ok()?
        .get("ok")
        .cloned()
}
#[derive(Deserialize)]
pub(super) struct Window {
    pub id: String,
    pub pid: u32,
    active: bool,
    x: f64,
    y: f64,
    w: f64,
    h: f64,
}
pub(super) fn focused_window() -> Option<Window> {
    // `focused` is per workspace; `active` is the actual keyboard focus.
    query("windows")?
        .as_array()?
        .iter()
        .filter_map(|v| serde_json::from_value::<Window>(v.clone()).ok())
        .find(|w| w.active && w.pid > 0 && w.w > 0.0 && w.h > 0.0)
}

pub(super) fn focused_output() -> Option<String> {
    query("workspaces")?
        .as_array()?
        .iter()
        .find(|w| w.get("focused").and_then(Value::as_bool) == Some(true))?
        .get("output")?
        .as_str()
        .map(str::to_owned)
}

impl Window {
    pub fn bounds(&self) -> Rect {
        Rect {
            x: self.x,
            y: self.y,
            w: self.w,
            h: self.h,
        }
    }
}
