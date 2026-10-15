use crate::geometry::Rect;
use std::time::{Duration, Instant};

const AVOID_GAP: f64 = 48.0;
const RETURN_GAP: f64 = 112.0;
const RETURN_DELAY: Duration = Duration::from_millis(650);

pub struct Area {
    pub output: Rect,
    pub size: (f64, f64),
    pub margin: f64,
}
pub struct Motion {
    started: Instant,
    from: f64,
    to: f64,
}

impl Motion {
    pub fn exit(from: f64, output_height: f64, height: f64, now: Instant) -> Self {
        Self {
            started: now,
            from,
            to: if from + height / 2.0 < output_height / 2.0 {
                -height
            } else {
                output_height
            },
        }
    }
    pub fn sample(&self, now: Instant, duration: Duration) -> (f64, bool) {
        let t = if duration.is_zero() {
            1.0
        } else {
            (now.duration_since(self.started).as_secs_f64() / duration.as_secs_f64()).min(1.0)
        };
        (
            self.from + (self.to - self.from) * (1.0 - (1.0 - t).powi(3)),
            t >= 1.0,
        )
    }
}

#[derive(Default)]
pub struct Placement {
    bottom: bool,
    entering: bool,
    clear_since: Option<Instant>,
    motion: Option<Motion>,
    y: Option<f64>,
}
impl Placement {
    pub fn reset(&mut self) {
        *self = Self::default();
    }
    pub fn enter_output(&mut self) {
        self.reset();
        self.entering = true;
    }
    pub fn update(
        &mut self,
        area: Area,
        caret: Option<Rect>,
        duration: Duration,
        now: Instant,
        visible: bool,
    ) -> i32 {
        let Area {
            output,
            size,
            margin,
        } = area;
        let top = margin.min(((output.h - size.1) / 2.0).max(0.0));
        let bottom = (output.h - size.1 - top).max(top);
        let top_box = Rect {
            x: output.x + (output.w - size.0) / 2.0,
            y: output.y + top,
            w: size.0,
            h: size.1,
        };
        let bottom_box = Rect {
            y: output.y + bottom,
            ..top_box
        };
        let blocked = |r: Rect, gap| caret.is_some_and(|c| c.valid() && c.near(r, gap));
        let previous = self.bottom;
        if !self.bottom && blocked(top_box, AVOID_GAP) && !blocked(bottom_box, AVOID_GAP) {
            self.bottom = true;
            self.clear_since = None;
        } else if self.bottom {
            // Return only after sustained extra clearance; small cursor movements
            // near the boundary must not make the overlay bounce between sides.
            if !blocked(top_box, RETURN_GAP) {
                let since = *self.clear_since.get_or_insert(now);
                if now.duration_since(since) >= RETURN_DELAY {
                    self.bottom = false;
                }
            } else {
                self.clear_since = None;
            }
        }
        let target = if self.bottom { bottom } else { top };
        let entering = std::mem::take(&mut self.entering);
        if entering && visible && !duration.is_zero() {
            // Output changes require a new layer surface. Slide into the chosen
            // destination from its nearest edge instead of carrying old coordinates.
            let from = if self.bottom { output.h } else { -size.1 };
            self.y = Some(from);
            self.motion = Some(Motion {
                started: now,
                from,
                to: target,
            });
        } else if !visible || self.y.is_none() || duration.is_zero() {
            self.y = Some(target);
            self.motion = None;
        } else if previous != self.bottom
            || self
                .motion
                .as_ref()
                .is_some_and(|motion| motion.to != target)
        {
            self.motion = Some(Motion {
                started: now,
                from: self.y.unwrap(),
                to: target,
            });
        } else if self.motion.is_none() {
            self.y = Some(target);
        }
        if let Some(motion) = &self.motion {
            let (y, finished) = motion.sample(now, duration);
            self.y = Some(y);
            if finished {
                self.motion = None;
            }
        }
        self.y.unwrap_or(target).round() as i32
    }
}
#[cfg(test)]
#[path = "../checks/placement.rs"]
mod tests;
