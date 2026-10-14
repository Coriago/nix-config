mod keyboard;
mod layers;
mod render;

use anyhow::{ensure, Result};
use clap::Parser;
use keyboard::Snapshot;
use layers::{Active, Layout};
use render::{Renderer, HEIGHT, WIDTH};
use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_layer, delegate_output, delegate_registry, delegate_shm,
    output::{OutputHandler, OutputState},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    shell::{
        wlr_layer::{
            Anchor, KeyboardInteractivity, Layer, LayerShell, LayerShellHandler, LayerSurface,
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
};
use wayland_client::{
    globals::registry_queue_init,
    protocol::{wl_output, wl_shm, wl_surface},
    Connection, QueueHandle,
};

/// W-CORNE overlay inferred from physical layer-key holds. Does not modify firmware or keymaps.
#[derive(Parser)]
#[command(
    after_help = "Close Vial before starting. Reads the live tapping term unless overridden.\nOne-shot layers are shown only while held. Modifier one-shots and early\npermissive-hold decisions are not tracked. Restart after saving a new export."
)]
struct Args {
    /// Saved Vial .vil export, read only
    layout: PathBuf,
    /// Override the display hold threshold in milliseconds
    #[arg(long)]
    hold_ms: Option<u64>,
    /// Display a fixed layer without opening USB
    #[arg(long)]
    preview: Option<usize>,
    /// Render the preview layer to PNG and exit
    #[arg(long)]
    render: Option<PathBuf>,
    /// Check the read-only USB connection and print its tapping term
    #[arg(long)]
    probe: bool,
}
fn main() -> Result<()> {
    let args = Args::parse();
    let layout = Layout::load(&args.layout)?;
    ensure!(args.hold_ms != Some(0), "--hold-ms must be positive");
    if let Some(layer) = args.preview {
        ensure!(layer < layout.layout.len(), "Preview layer outside layout");
    }
    if args.probe {
        let mut keyboard = keyboard::Keyboard::open()?;
        keyboard.pressed()?;
        println!(
            "W-CORNE matrix readable; tapping term {} ms",
            keyboard.term.as_millis()
        );
        return Ok(());
    }
    let renderer = Renderer::new()?;
    let mut snapshot = Snapshot::default();
    if let Some(layer) = args.preview {
        snapshot.active.insert(layer);
    }
    if let Some(path) = args.render {
        let mut encoder = png::Encoder::new(std::fs::File::create(path)?, WIDTH, HEIGHT);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        encoder
            .write_header()?
            .write_image_data(&renderer.render(&layout, &snapshot, 1))?;
        return Ok(());
    }
    let shared = Arc::new(Mutex::new(snapshot.clone()));
    if args.preview.is_none() {
        keyboard::spawn(layout.clone(), args.hold_ms, shared.clone());
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
        exit: false,
    };
    loop {
        events.dispatch_pending(&mut app)?;
        if app.exit {
            break;
        }
        let next = shared.lock().unwrap().clone();
        if next != app.snapshot {
            app.snapshot = next;
            app.dirty = true;
        }
        let visible = args.preview.is_some() || app.snapshot.active != Active::from([0]);
        if visible && app.layer.is_none() {
            app.show(&qh)?;
        }
        if !visible && app.layer.is_some() {
            app.layer = None;
            app.configured = false;
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
    Ok(())
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
    exit: bool,
}
impl App {
    fn show(&mut self, qh: &QueueHandle<Self>) -> Result<()> {
        let surface = self.compositor.create_surface(qh);
        let region = self.compositor.wl_compositor().create_region(qh, ());
        surface.set_input_region(Some(&region));
        region.destroy();
        let layer = self.shell.create_layer_surface(
            qh,
            surface,
            Layer::Overlay,
            Some("corne-overlay"),
            None,
        );
        layer.set_size(WIDTH, HEIGHT);
        layer.set_anchor(Anchor::BOTTOM);
        layer.set_margin(0, 0, 36, 0);
        layer.set_exclusive_zone(0);
        layer.set_keyboard_interactivity(KeyboardInteractivity::None);
        layer.commit();
        self.layer = Some(layer);
        self.configured = false;
        self.scale = 1;
        self.dirty = true;
        Ok(())
    }
    fn draw(&mut self) -> Result<()> {
        let layer = self.layer.as_ref().unwrap();
        let scale = self.scale.max(1) as usize;
        let width = WIDTH as usize * scale;
        let height = HEIGHT as usize * scale;
        let pixels = self.renderer.render(&self.layout, &self.snapshot, scale);
        let (buffer, canvas) = self.pool.create_buffer(
            width as i32,
            height as i32,
            width as i32 * 4,
            wl_shm::Format::Argb8888,
        )?;
        for (dest, src) in canvas.chunks_exact_mut(4).zip(pixels.chunks_exact(4)) {
            dest.copy_from_slice(
                &u32::from_be_bytes([src[3], src[0], src[1], src[2]]).to_ne_bytes(),
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
        _: &wl_surface::WlSurface,
        factor: i32,
    ) {
        self.scale = factor.max(1);
        self.dirty = true;
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
        _: &wl_surface::WlSurface,
        _: &wl_output::WlOutput,
    ) {
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
    fn update_output(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
    fn output_destroyed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: wl_output::WlOutput) {}
}
impl LayerShellHandler for App {
    fn closed(&mut self, _: &Connection, _: &QueueHandle<Self>, _: &LayerSurface) {
        self.exit = true;
    }
    fn configure(
        &mut self,
        _: &Connection,
        _: &QueueHandle<Self>,
        _: &LayerSurface,
        _: LayerSurfaceConfigure,
        _: u32,
    ) {
        self.configured = true;
        self.dirty = true;
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
