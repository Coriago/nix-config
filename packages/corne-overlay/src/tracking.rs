//! Poll caret geometry without blocking the Wayland event loop.
use crate::{
    accessibility::{self, FocusedText},
    compositor,
    geometry::Rect,
};
use std::{
    sync::{
        mpsc::{self, RecvTimeoutError},
        Arc, Mutex,
    },
    time::{Duration, Instant},
};

const POLL_INTERVAL: Duration = Duration::from_millis(100);
const SEARCH_INTERVAL: Duration = Duration::from_secs(1);
const SAMPLE_LIFETIME: Duration = Duration::from_millis(600);

#[derive(Clone, Debug)]
pub struct Sample {
    pub caret: Option<Rect>,
    pub output: String,
    pub at: Instant,
}
impl Sample {
    pub fn fresh_caret(&self) -> Option<Rect> {
        self.caret.filter(|_| self.at.elapsed() < SAMPLE_LIFETIME)
    }
}

pub struct Tracker {
    control: mpsc::Sender<bool>,
    enabled: bool,
    sample: Arc<Mutex<Sample>>,
}
impl Tracker {
    pub fn spawn() -> Self {
        let (control, commands) = mpsc::channel();
        let sample = Arc::new(Mutex::new(Sample {
            caret: None,
            output: String::new(),
            at: Instant::now(),
        }));
        let shared = sample.clone();
        std::thread::spawn(move || {
            let mut enabled = false;
            let mut reader = None;
            loop {
                // A disabled tracker sleeps until enabled. Dropping the sender
                // stops the worker; no detached polling continues after its owner.
                let command = if enabled {
                    commands.recv_timeout(POLL_INTERVAL)
                } else {
                    commands.recv().map_err(|_| RecvTimeoutError::Disconnected)
                };
                match command {
                    Ok(value) => enabled = value,
                    Err(RecvTimeoutError::Disconnected) => break,
                    Err(RecvTimeoutError::Timeout) => {}
                }
                if enabled {
                    let reader = reader.get_or_insert_with(CaretReader::new);
                    let next = reader.read();
                    *shared.lock().unwrap() = next;
                }
            }
        });
        Self {
            control,
            enabled: false,
            sample,
        }
    }
    pub fn set_enabled(&mut self, enabled: bool) {
        if self.enabled != enabled {
            self.enabled = enabled;
            let _ = self.control.send(enabled);
        }
    }
    pub fn sample(&self) -> Sample {
        self.sample.lock().unwrap().clone()
    }
}

struct CaretReader {
    available: bool,
    focused: Option<FocusedText>,
    window_id: String,
    last_search: Option<Instant>,
}
impl CaretReader {
    fn new() -> Self {
        Self {
            available: accessibility::initialize(),
            focused: None,
            window_id: String::new(),
            last_search: None,
        }
    }
    fn read(&mut self) -> Sample {
        accessibility::dispatch_pending();
        let window = compositor::focused_window();
        let id = window.as_ref().map(|w| w.id.as_str()).unwrap_or_default();
        if self.window_id != id {
            self.window_id = id.to_owned();
            self.focused = None;
            self.last_search = None;
        }
        let mut caret = None;
        if let Some(window) = &window {
            if self.available {
                if self.focused.as_ref().is_some_and(|o| !o.is_focused()) {
                    self.focused = None;
                }
                if self.focused.is_none()
                    && self
                        .last_search
                        .is_none_or(|t| t.elapsed() >= SEARCH_INTERVAL)
                {
                    self.last_search = Some(Instant::now());
                    self.focused = accessibility::find_focused(window.pid);
                }
                caret = self.focused.as_ref().and_then(|o| o.caret(window.bounds()));
            }
        }
        // A focus change during a slow accessibility call invalidates its result.
        if caret.is_some()
            && compositor::focused_window().as_ref().map(|w| &w.id)
                != window.as_ref().map(|w| &w.id)
        {
            caret = None;
            self.focused = None;
        }
        Sample {
            caret,
            output: compositor::focused_output().unwrap_or_default(),
            at: Instant::now(),
        }
    }
}
