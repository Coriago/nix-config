mod accessibility;
mod app;
mod appearance;
mod compositor;
mod geometry;
mod keyboard;
mod layers;
mod placement;
mod render;
mod tracking;

use anyhow::{ensure, Result};
use appearance::Appearance;
use clap::Parser;
use keyboard::Snapshot;
use layers::Layout;
use render::{Renderer, HEIGHT, WIDTH};
use std::{path::PathBuf, time::Duration};

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
    /// Print caret geometry for ten seconds, without opening USB or an overlay
    #[arg(long)]
    probe_caret: bool,
    /// Live appearance JSON supplied by the Noctalia plugin
    #[arg(long)]
    appearance: Option<PathBuf>,
}
fn main() -> Result<()> {
    let args = Args::parse();
    let layout = Layout::load(&args.layout)?;
    if args.probe_caret {
        let mut tracker = tracking::Tracker::spawn();
        tracker.set_enabled(true);
        for _ in 0..20 {
            std::thread::sleep(Duration::from_millis(500));
            let sample = tracker.sample();
            println!(
                "Caret: {:?} ({} ms old)",
                sample.caret,
                sample.at.elapsed().as_millis()
            );
        }
        return Ok(());
    }
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
    let appearance = args
        .appearance
        .as_deref()
        .map(|p| Appearance::load(p, layout.layout.len()))
        .transpose()?
        .unwrap_or_default();
    let mut renderer = Renderer::new()?;
    if let Some(path) = &appearance.font_file {
        renderer.set_font(path)?;
    }
    let mut snapshot = Snapshot::default();
    if let Some(layer) = args.preview {
        snapshot.active.insert(layer);
    }
    if let Some(path) = args.render {
        let mut encoder = png::Encoder::new(std::fs::File::create(path)?, WIDTH, HEIGHT);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        encoder.write_header()?.write_image_data(&renderer.render(
            &layout,
            &snapshot,
            1,
            &appearance,
        ))?;
        return Ok(());
    }
    app::run(
        layout,
        appearance,
        renderer,
        snapshot,
        app::Options {
            preview: args.preview,
            hold_ms: args.hold_ms,
            appearance: args.appearance,
        },
    )
}
