use crate::{
    appearance::Appearance,
    geometry::Rect,
    keyboard::{self, Snapshot},
    layers::{Active, Layout},
    placement::{Area, Motion, Placement},
    render::{Renderer, HEIGHT, WIDTH},
    tracking::Tracker,
};
use anyhow::Result;
use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_layer, delegate_output, delegate_registry, delegate_shm,
    output::{OutputHandler, OutputState},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    shell::{
        wlr_layer::{
            KeyboardInteractivity, Layer, LayerShell, LayerShellHandler, LayerSurface,
            LayerSurfaceConfigure,
        },
        WaylandSurface,
    },
    shm::{slot::SlotPool, Shm, ShmHandler},
};
use std::{
    os::fd::AsRawFd,
    path::PathBuf,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};
use wayland_client::{
    globals::registry_queue_init,
    protocol::{wl_output, wl_shm, wl_surface},
    Connection, QueueHandle,
};

pub struct Options {
    pub preview: Option<usize>,
    pub hold_ms: Option<u64>,
    pub appearance: Option<PathBuf>,
}

pub fn run(
    layout: Layout,
    appearance: Appearance,
    renderer: Renderer,
    snapshot: Snapshot,
    options: Options,
) -> Result<()> {
    let shared = Arc::new(Mutex::new(snapshot.clone()));
    if options.preview.is_none() {
        keyboard::spawn(layout.clone(), options.hold_ms, shared.clone());
    }
    let conn = Connection::connect_to_env()?;
    let (globals, mut events) = registry_queue_init(&conn)?;
    let qh = events.handle();
    let compositor = CompositorState::bind(&globals, &qh)?;
    let shell = LayerShell::bind(&globals, &qh)?;
    let shm = Shm::bind(&globals, &qh)?;
    let pool = SlotPool::new(WIDTH as usize * HEIGHT as usize * 4, &shm)?;
    let mut app = App {
        registry: RegistryState::new(&globals),
        outputs: OutputState::new(&globals, &qh),
        compositor,
        shell,
        shm,
        pool,
        layer: None,
        configured: false,
        scale: 1,
        dirty: true,
        renderer,
        layout,
        snapshot,
        appearance,
        placement: Placement::default(),
        placed_y: None,
        output_animation_pending: false,
        output_transition: None,
        focused_output: String::new(),
        surface_output: None,
    };
    let mut tracker = Tracker::spawn();
    // Receive output names before choosing a configured connector.
    events.roundtrip(&mut app)?;
    let mut appearance_checked = Instant::now();
    let mut appearance_error = String::new();
    loop {
        events.dispatch_pending(&mut app)?;
        if appearance_checked.elapsed() >= Duration::from_millis(250) {
            if let Some(path) = &options.appearance {
                match Appearance::load(path, app.layout.layout.len()) {
                    Ok(next) => {
                        appearance_error.clear();
                        if next != app.appearance {
                            app.apply_appearance(next);
                        }
                    }
                    Err(error) => {
                        let message = error.to_string();
                        if message != appearance_error {
                            eprintln!("Appearance: {message}");
                            appearance_error = message;
                        }
                    }
                }
            }
            appearance_checked = Instant::now();
        }
        let next = shared.lock().unwrap().clone();
        if next != app.snapshot {
            app.snapshot = next;
            app.dirty = true;
        }
        let visible = options.preview.is_some()
            || app.appearance.always_visible
            || app.appearance.preview.is_some()
            || app.snapshot.active != Active::from([0]);
        tracker.set_enabled(app.appearance.avoid_caret);
        let sample = tracker.sample();
        app.follow_output(&sample.output, visible);
        app.update_placement(sample.fresh_caret(), visible);
        if visible && app.layer.is_none() {
            app.show(&qh);
        }
        if !visible {
            app.hide();
        }
        if app.dirty && app.configured {
            app.draw()?;
        }
        conn.flush()?;
        // Prepare before polling so events arriving between dispatch and read cannot be lost.
        if let Some(guard) = events.prepare_read() {
            let mut fd = libc::pollfd {
                fd: guard.connection_fd().as_raw_fd(),
                events: libc::POLLIN,
                revents: 0,
            };
            let ready = unsafe { libc::poll(&mut fd, 1, 25) };
            if ready > 0 {
                guard.read()?;
            } else if ready < 0
                && std::io::Error::last_os_error().kind() != std::io::ErrorKind::Interrupted
            {
                return Err(std::io::Error::last_os_error().into());
            }
        }
    }
}

struct App {
    registry: RegistryState,
    outputs: OutputState,
    compositor: CompositorState,
    shell: LayerShell,
    shm: Shm,
    pool: SlotPool,
    layer: Option<LayerSurface>,
    configured: bool,
    scale: i32,
    dirty: bool,
    renderer: Renderer,
    layout: Layout,
    snapshot: Snapshot,
    appearance: Appearance,
    placement: Placement,
    placed_y: Option<i32>,
    output_animation_pending: bool,
    output_transition: Option<Motion>,
    focused_output: String,
    surface_output: Option<wl_output::WlOutput>,
}
impl App {
    fn hide(&mut self) {
        self.output_transition = None;
        self.output_animation_pending = false;
        self.layer = None;
        self.configured = false;
    }
    fn reset_placement(&mut self) {
        self.placement.reset();
        self.placed_y = None;
    }
    fn reset_output(&mut self) {
        self.hide();
        self.surface_output = None;
        self.reset_placement();
    }
    fn follow_output(&mut self, output: &str, visible: bool) {
        if !self.appearance.avoid_caret || !self.appearance.output.is_empty() || output.is_empty() {
            return;
        }
        if output == self.focused_output {
            if self.output_transition.take().is_some() {
                self.reset_placement();
            }
            return;
        }
        let duration = Duration::from_millis(self.appearance.animation_ms);
        if visible && self.configured && !duration.is_zero() {
            if self.output_transition.is_none() {
                if let Some((_, height)) = self
                    .output()
                    .and_then(|o| self.outputs.info(&o))
                    .and_then(|info| info.logical_size)
                {
                    self.output_transition = Some(Motion::exit(
                        self.placed_y.unwrap_or(self.appearance.margin).into(),
                        height.into(),
                        HEIGHT.into(),
                        Instant::now(),
                    ));
                }
            }
            if let Some(transition) = &mut self.output_transition {
                let (y, finished) = transition.sample(Instant::now(), duration);
                if !finished {
                    self.placed_y = Some(y.round() as i32);
                    if let Some(layer) = &self.layer {
                        self.place(layer);
                        layer.commit();
                    }
                    return;
                }
            }
        }
        let animate = visible && (self.configured || self.output_animation_pending);
        self.focused_output = output.to_owned();
        self.reset_output();
        self.output_animation_pending = animate;
    }
    fn owns_surface(&self, surface: &wl_surface::WlSurface) -> bool {
        self.layer
            .as_ref()
            .is_some_and(|layer| layer.wl_surface() == surface)
    }

    fn output(&self) -> Option<wl_output::WlOutput> {
        let name = if self.appearance.output.is_empty() && self.appearance.avoid_caret {
            &self.focused_output
        } else {
            &self.appearance.output
        };
        self.outputs
            .outputs()
            .find(|o| {
                self.outputs
                    .info(o)
                    .is_some_and(|i| i.name.as_deref() == Some(name.as_str()))
            })
            .or_else(|| self.surface_output.clone())
    }
    fn update_placement(&mut self, caret: Option<Rect>, visible: bool) {
        if !self.appearance.avoid_caret || self.output_transition.is_some() {
            return;
        }
        let Some(info) = self.output().and_then(|o| self.outputs.info(&o)) else {
            return;
        };
        let (Some((x, y)), Some((w, h))) = (info.logical_position, info.logical_size) else {
            return;
        };
        let y = self.placement.update(
            Area {
                output: Rect {
                    x: x.into(),
                    y: y.into(),
                    w: w.into(),
                    h: h.into(),
                },
                size: (WIDTH.into(), HEIGHT.into()),
                margin: self.appearance.margin.into(),
            },
            caret,
            Duration::from_millis(self.appearance.animation_ms),
            Instant::now(),
            visible && self.layer.is_some(),
        );
        if self.placed_y != Some(y) {
            self.placed_y = Some(y);
            if let Some(layer) = &self.layer {
                self.place(layer);
                layer.commit();
            }
        }
    }
    fn place(&self, layer: &LayerSurface) {
        let m = self.appearance.margin;
        if self.appearance.avoid_caret {
            layer.set_anchor(smithay_client_toolkit::shell::wlr_layer::Anchor::TOP);
            layer.set_exclusive_zone(-1);
            layer.set_margin(self.placed_y.unwrap_or(m), 0, 0, 0);
        } else {
            layer.set_anchor(self.appearance.position.anchor());
            layer.set_exclusive_zone(0);
            layer.set_margin(m, m, m, m);
        }
    }
    fn apply_appearance(&mut self, next: Appearance) {
        if next.font_file != self.appearance.font_file {
            if let Some(path) = &next.font_file {
                if let Err(error) = self.renderer.set_font(path) {
                    eprintln!("Font: {error}");
                }
            }
        }
        if next.output != self.appearance.output {
            self.reset_output();
        }
        if next.output != self.appearance.output || next.avoid_caret != self.appearance.avoid_caret
        {
            self.output_transition = None;
            self.reset_placement();
        }
        self.appearance = next;
        if let Some(layer) = &self.layer {
            self.place(layer);
            layer.commit();
        }
        self.dirty = true;
    }
    fn show(&mut self, qh: &QueueHandle<Self>) {
        let surface = self.compositor.create_surface(qh);
        let region = self.compositor.wl_compositor().create_region(qh, ());
        surface.set_input_region(Some(&region));
        region.destroy();
        let output = self.output();
        let layer = self.shell.create_layer_surface(
            qh,
            surface,
            Layer::Overlay,
            Some("corne-overlay"),
            output.as_ref(),
        );
        layer.set_size(WIDTH, HEIGHT);
        self.place(&layer);
        layer.set_keyboard_interactivity(KeyboardInteractivity::None);
        layer.commit();
        self.layer = Some(layer);
        self.configured = false;
        self.scale = 1;
        self.dirty = true;
    }
    fn draw(&mut self) -> Result<()> {
        let layer = self.layer.as_ref().unwrap();
        let scale = self.scale.max(1) as usize;
        let width = WIDTH as usize * scale;
        let height = HEIGHT as usize * scale;
        let mut snapshot = self.snapshot.clone();
        if let Some(preview) = self.appearance.preview {
            snapshot.active = Active::from([0, preview]);
        }
        let pixels = self
            .renderer
            .render(&self.layout, &snapshot, scale, &self.appearance);
        let (buffer, canvas) = self.pool.create_buffer(
            width as i32,
            height as i32,
            width as i32 * 4,
            wl_shm::Format::Argb8888,
        )?;
        for (dest, src) in canvas.chunks_exact_mut(4).zip(pixels.chunks_exact(4)) {
            let premul = |c: u8| (c as u16 * src[3] as u16 / 255) as u8;
            dest.copy_from_slice(
                &u32::from_be_bytes([src[3], premul(src[0]), premul(src[1]), premul(src[2])])
                    .to_ne_bytes(),
            );
        }
        layer.wl_surface().set_buffer_scale(self.scale);
        layer
            .wl_surface()
            .damage_buffer(0, 0, width as i32, height as i32);
        buffer.attach_to(layer.wl_surface())?;
        layer.commit();
        self.dirty = false;
        Ok(())
    }
}
impl CompositorHandler for App {
    fn scale_factor_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        surface: &wl_surface::WlSurface,
        factor: i32,
    ) {
        if self.owns_surface(surface) {
            self.scale = factor.max(1);
            self.dirty = true;
        }
    }
    fn transform_changed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: wl_output::Transform,
    ) {
    }
    fn frame(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &wl_surface::WlSurface, _: u32) {}
    fn surface_enter(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        surface: &wl_surface::WlSurface,
        output: &wl_output::WlOutput,
    ) {
        if self.owns_surface(surface) {
            self.surface_output = Some(output.clone());
        }
    }
    fn surface_leave(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
    }
}
impl OutputHandler for App {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.outputs
    }
    fn new_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn update_output(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        output: wl_output::WlOutput,
    ) {
        if self
            .outputs
            .info(&output)
            .is_some_and(|i| i.name.as_deref() == Some(self.appearance.output.as_str()))
        {
            self.hide();
        }
    }
    fn output_destroyed(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        output: wl_output::WlOutput,
    ) {
        if self.surface_output.as_ref() == Some(&output) {
            self.reset_output();
        }
    }
}
impl LayerShellHandler for App {
    fn closed(&mut self, _: &Connection, _: &QueueHandle<Self>, layer: &LayerSurface) {
        // Output removal can close a surface; rebuild on an available output.
        if self.layer.as_ref() == Some(layer) {
            self.hide();
        }
    }
    fn configure(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        layer: &LayerSurface,
        _: LayerSurfaceConfigure,
        _: u32,
    ) {
        if self.layer.as_ref() == Some(layer) {
            self.configured = true;
            if std::mem::take(&mut self.output_animation_pending) {
                self.placement.enter_output();
            }
            self.dirty = true;
        }
    }
}
impl ShmHandler for App {
    fn shm_state(&mut self) -> &mut Shm {
        &mut self.shm
    }
}
impl ProvidesRegistryState for App {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry
    }
    registry_handlers![OutputState];
}
delegate_compositor!(App);
delegate_output!(App);
delegate_shm!(App);
delegate_layer!(App);
delegate_registry!(App);
wayland_client::delegate_noop!(App: ignore wayland_client::protocol::wl_region::WlRegion);
