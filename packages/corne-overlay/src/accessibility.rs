//! AT-SPI ownership and C calls stay on the tracking worker thread.
use crate::geometry::{normalize, Rect};
use std::{
    ffi::c_void,
    ptr::{null_mut, NonNull},
    time::{Duration, Instant},
};

pub(super) fn initialize() -> bool {
    unsafe {
        atspi_set_timeout(100, 100);
        matches!(atspi_init(), 0 | 1)
    }
}
pub(super) fn dispatch_pending() {
    for _ in 0..100 {
        if unsafe { g_main_context_iteration(null_mut(), 0) } == 0 {
            break;
        }
    }
}

const STATE_ACTIVE: i32 = 1;
const STATE_FOCUSED: i32 = 12;
const STATE_SHOWING: i32 = 25;
const STATE_VISIBLE: i32 = 30;
const ROLE_FRAME: i32 = 23;
const ROLE_WINDOW: i32 = 69;
const COORD_SCREEN: i32 = 0;
const COORD_WINDOW: i32 = 1;
const MAX_DEPTH: usize = 48;

pub(super) struct FocusedText(Object);
impl FocusedText {
    pub fn is_focused(&self) -> bool {
        unsafe { self.0.state(STATE_FOCUSED) }
    }
    pub fn caret(&self, window: Rect) -> Option<Rect> {
        unsafe { self.0.caret(window) }
    }
}
pub(super) fn find_focused(pid: u32) -> Option<FocusedText> {
    unsafe { find_object(pid).map(FocusedText) }
}

// Signatures and full-transfer ownership follow Atspi-2.0.gir (2.60).
struct Object(NonNull<c_void>);
impl Object {
    unsafe fn take(p: *mut c_void) -> Option<Self> {
        NonNull::new(p).map(Self)
    }
    fn p(&self) -> *mut c_void {
        self.0.as_ptr()
    }
    unsafe fn state(&self, state: i32) -> bool {
        atspi_accessible_clear_cache(self.p());
        Self::take(atspi_accessible_get_state_set(self.p()))
            .is_some_and(|s| atspi_state_set_contains(s.p(), state) != 0)
    }
    unsafe fn children(&self) -> Vec<Object> {
        (0..atspi_accessible_get_child_count(self.p(), null_mut()).clamp(0, 512))
            .filter_map(|i| {
                Self::take(atspi_accessible_get_child_at_index(self.p(), i, null_mut()))
            })
            .collect()
    }
    unsafe fn caret(&self, window: Rect) -> Option<Rect> {
        if !self.state(STATE_FOCUSED) || !self.state(STATE_SHOWING) || !self.state(STATE_VISIBLE) {
            return None;
        }
        let text = Self::take(atspi_accessible_get_text_iface(self.p()))?;
        let offset = atspi_text_get_caret_offset(text.p(), null_mut());
        if offset < 0 {
            return None;
        }
        let screen_rect =
            rect_call(|err| atspi_text_get_character_extents(text.p(), offset, COORD_SCREEN, err));
        // GTK on Wayland can reject SCREEN while Chromium accepts it with a
        // synthetic origin. Prefer SCREEN relative to the frame; use WINDOW
        // only when the toolkit cannot provide SCREEN coordinates.
        let rect = screen_rect.or_else(|| {
            rect_call(|err| atspi_text_get_character_extents(text.p(), offset, COORD_WINDOW, err))
        })?;
        let mut parent = Self::take(atspi_accessible_get_parent(self.p(), null_mut()));
        for _ in 0..MAX_DEPTH {
            let node = parent?;
            let role = atspi_accessible_get_role(node.p(), null_mut());
            if role == ROLE_FRAME || role == ROLE_WINDOW {
                if !node.state(STATE_ACTIVE) {
                    return None;
                }
                let component = Self::take(atspi_accessible_get_component_iface(node.p()))?;
                let mut frame =
                    rect_call(|err| atspi_component_get_extents(component.p(), COORD_SCREEN, err))?;
                if screen_rect.is_none() {
                    frame.x = 0.0;
                    frame.y = 0.0;
                }
                return normalize(rect, frame, window);
            }
            parent = Self::take(atspi_accessible_get_parent(node.p(), null_mut()));
        }
        None
    }
}
impl Drop for Object {
    fn drop(&mut self) {
        unsafe { g_object_unref(self.p()) }
    }
}
unsafe fn find_object(pid: u32) -> Option<Object> {
    let desktop = Object::take(atspi_get_desktop(0))?;
    let deadline = Instant::now() + Duration::from_millis(250);
    let mut stack: Vec<_> = desktop
        .children()
        .into_iter()
        .filter(|o| atspi_accessible_get_process_id(o.p(), null_mut()) == pid)
        .map(|o| (o, 0))
        .collect();
    let mut count = 0;
    while let Some((o, depth)) = stack.pop() {
        count += 1;
        if count > 3000 || Instant::now() > deadline {
            break;
        }
        if o.state(STATE_FOCUSED) && Object::take(atspi_accessible_get_text_iface(o.p())).is_some()
        {
            return Some(o);
        }
        if depth < MAX_DEPTH {
            let role = atspi_accessible_get_role(o.p(), null_mut());
            if (role == ROLE_FRAME || role == ROLE_WINDOW) && !o.state(STATE_ACTIVE) {
                continue;
            }
            stack.extend(o.children().into_iter().rev().map(|c| (c, depth + 1)));
        }
    }
    None
}

#[repr(C)]
struct AtspiRect {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
}
unsafe fn rect_call(call: impl FnOnce(*mut *mut c_void) -> *mut AtspiRect) -> Option<Rect> {
    let mut error = null_mut();
    let p = call(&mut error);
    // libatspi can return an allocated, uninitialized rectangle on a D-Bus
    // error. Check GError before touching the rectangle, even when non-null.
    if !error.is_null() {
        g_error_free(error);
        g_free(p.cast());
        return None;
    }
    let p = NonNull::new(p)?;
    let r = p.as_ref();
    let result = Rect {
        x: r.x.into(),
        y: r.y.into(),
        w: r.width.into(),
        h: r.height.into(),
    };
    g_free(p.as_ptr().cast());
    result.valid().then_some(result)
}
#[link(name = "atspi")]
extern "C" {
    fn atspi_init() -> i32;
    fn atspi_set_timeout(timeout: i32, startup: i32);
    fn atspi_get_desktop(index: i32) -> *mut c_void;
    fn atspi_accessible_clear_cache(o: *mut c_void);
    fn atspi_accessible_get_child_count(o: *mut c_void, err: *mut *mut c_void) -> i32;
    fn atspi_accessible_get_child_at_index(
        o: *mut c_void,
        i: i32,
        err: *mut *mut c_void,
    ) -> *mut c_void;
    fn atspi_accessible_get_parent(o: *mut c_void, err: *mut *mut c_void) -> *mut c_void;
    fn atspi_accessible_get_process_id(o: *mut c_void, err: *mut *mut c_void) -> u32;
    fn atspi_accessible_get_role(o: *mut c_void, err: *mut *mut c_void) -> i32;
    fn atspi_accessible_get_state_set(o: *mut c_void) -> *mut c_void;
    fn atspi_state_set_contains(o: *mut c_void, state: i32) -> i32;
    fn atspi_accessible_get_text_iface(o: *mut c_void) -> *mut c_void;
    fn atspi_accessible_get_component_iface(o: *mut c_void) -> *mut c_void;
    fn atspi_text_get_caret_offset(o: *mut c_void, err: *mut *mut c_void) -> i32;
    fn atspi_text_get_character_extents(
        o: *mut c_void,
        offset: i32,
        coords: i32,
        err: *mut *mut c_void,
    ) -> *mut AtspiRect;
    fn atspi_component_get_extents(
        o: *mut c_void,
        coords: i32,
        err: *mut *mut c_void,
    ) -> *mut AtspiRect;
}
#[link(name = "gobject-2.0")]
extern "C" {
    fn g_object_unref(o: *mut c_void);
}
#[link(name = "glib-2.0")]
extern "C" {
    fn g_free(p: *mut c_void);
    fn g_error_free(p: *mut c_void);
    fn g_main_context_iteration(context: *mut c_void, may_block: i32) -> i32;
}

#[cfg(test)]
#[path = "../checks/accessibility.rs"]
mod tests;
