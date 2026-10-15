use anyhow::{ensure, Result};
use serde::Deserialize;
use std::{
    collections::{BTreeMap, BTreeSet},
    path::Path,
    time::Duration,
};

pub const UID: u64 = 3904610095205992439;
pub type Position = (usize, usize);
pub type Active = BTreeSet<usize>;
pub type Pressed = BTreeSet<Position>;

#[derive(Clone, Deserialize)]
pub struct Layout {
    pub uid: u64,
    pub layout: Vec<Vec<Vec<serde_json::Value>>>,
}
impl Layout {
    pub fn load(path: &Path) -> Result<Self> {
        let layout: Self = serde_json::from_slice(&std::fs::read(path)?)?;
        ensure!(layout.uid == UID, "Only the Pilot W-CORNE is supported");
        ensure!(
            !layout.layout.is_empty()
                && layout
                    .layout
                    .iter()
                    .all(|l| l.len() == 4 && l.iter().all(|r| r.len() == 12)),
            "Expected a 4 × 12 matrix"
        );
        Ok(layout)
    }
    pub fn key(&self, pos: Position, active: &Active) -> &str {
        for layer in active.iter().rev() {
            let code = self.layout[*layer][pos.0][pos.1]
                .as_str()
                .unwrap_or("KC_NO");
            if code != "KC_TRNS" {
                return code;
            }
        }
        "KC_NO"
    }
}

fn action(code: &str) -> Option<(usize, bool)> {
    if let Some(rest) = code.strip_prefix("LT") {
        return Some((rest.split_once('(')?.0.parse().ok()?, true));
    }
    for prefix in ["MO(", "OSL("] {
        if let Some(rest) = code.strip_prefix(prefix) {
            return Some((rest.strip_suffix(')')?.parse().ok()?, false));
        }
    }
    None
}

struct HeldKey {
    action: Option<(usize, bool)>,
    pressed_at: Duration,
}

pub struct Layers {
    pub layout: Layout,
    pub active: Active,
    pub term: Duration,
    held: BTreeMap<Position, HeldKey>,
}
impl Layers {
    pub fn new(layout: Layout, term: Duration) -> Self {
        Self {
            layout,
            term,
            active: Active::from([0]),
            held: BTreeMap::new(),
        }
    }
    pub fn update(&mut self, pressed: &Pressed, now: Duration) {
        self.held.retain(|pos, _| pressed.contains(pos));
        self.activate(now);
        // Resolve at press time; later layer changes must not reinterpret a held key.
        let additions: Vec<_> = pressed
            .iter()
            .filter(|p| !self.held.contains_key(p))
            .map(|p| {
                (
                    *p,
                    HeldKey {
                        action: action(self.layout.key(*p, &self.active)),
                        pressed_at: now,
                    },
                )
            })
            .collect();
        self.held.extend(additions);
        self.activate(now);
    }
    fn activate(&mut self, now: Duration) {
        self.active = Active::from([0]);
        for key in self.held.values() {
            if let Some((layer, delayed)) = key.action {
                if layer < self.layout.layout.len()
                    && (!delayed || now.saturating_sub(key.pressed_at) >= self.term)
                {
                    self.active.insert(layer);
                }
            }
        }
    }
}

#[cfg(test)]
#[path = "../checks/layers.rs"]
mod tests;
