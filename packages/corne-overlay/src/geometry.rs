#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Rect {
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64,
}
impl Rect {
    pub fn valid(self) -> bool {
        [self.x, self.y, self.w, self.h]
            .iter()
            .all(|v| v.is_finite())
            && self.w > 0.0
            && self.h > 0.0
    }
    pub fn near(self, other: Self, gap: f64) -> bool {
        self.x < other.x + other.w + gap
            && self.x + self.w > other.x - gap
            && self.y < other.y + other.h + gap
            && self.y + self.h > other.y - gap
    }
}

pub fn normalize(caret: Rect, frame: Rect, window: Rect) -> Option<Rect> {
    if !caret.valid() || !frame.valid() || !window.valid() {
        return None;
    }
    let r = Rect {
        x: window.x + (caret.x - frame.x) * window.w / frame.w,
        y: window.y + (caret.y - frame.y) * window.h / frame.h,
        w: caret.w * window.w / frame.w,
        h: caret.h * window.h / frame.h,
    };
    // Wayland apps may report synthetic screen origins. Normalize to their frame,
    // then use compositor geometry. Reject offscreen/stale/insertion sentinels.
    (r.valid()
        && r.x >= window.x
        && r.y >= window.y
        && r.x + r.w <= window.x + window.w + 2.0
        && r.y + r.h <= window.y + window.h + 2.0)
        .then_some(r)
}
