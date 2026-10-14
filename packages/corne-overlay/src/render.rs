use crate::appearance::{Appearance, Color};
use crate::{
    keyboard::Snapshot,
    layers::{Layout, Position},
};
use anyhow::Result;
use fontdue::{Font, FontSettings};
pub const WIDTH: u32 = 750;
pub const HEIGHT: u32 = 296;

pub fn label(code: &str) -> String {
    if let Some(inner) = code.strip_prefix("LSFT(").and_then(|s| s.strip_suffix(')')) {
        let base = label(inner);
        let shifted = "1234567890-=[]\\;',./`"
            .chars()
            .zip("!@#$%^&*()_+{}|:\"<>?~".chars())
            .find(|(a, _)| base == a.to_string())
            .map(|(_, b)| b.to_string());
        return shifted.unwrap_or_else(|| format!("Shift+{base}"));
    }
    if let Some(rest) = code.strip_prefix("LT") {
        if let Some((layer, inner)) = rest.split_once('(') {
            return format!("{}\nL{}", label(inner.trim_end_matches(')')), layer);
        }
    }
    for (prefix, modifier) in [("LGUI_T(", "Super"), ("LCTL_T(", "Ctrl")] {
        if let Some(inner) = code.strip_prefix(prefix).and_then(|s| s.strip_suffix(')')) {
            return format!("{}\n{modifier}", label(inner));
        }
    }
    if code.starts_with("OSM(") {
        for (suffix, name) in [
            ("SFT)", "Shift"),
            ("CTL)", "Ctrl"),
            ("ALT)", "Alt"),
            ("GUI)", "Super"),
        ] {
            if code.ends_with(suffix) {
                return name.into();
            }
        }
    }
    for prefix in ["MO(", "OSL("] {
        if let Some(inner) = code.strip_prefix(prefix).and_then(|s| s.strip_suffix(')')) {
            return format!("L{inner}{}", if prefix == "OSL(" { " once" } else { "" });
        }
    }
    let short = code.strip_prefix("KC_").unwrap_or(code);
    match short {
        "TAB" => "Tab",
        "BSPACE" => "Bksp",
        "ENTER" => "Enter",
        "SPACE" => "Space",
        "ESCAPE" => "Esc",
        "DELETE" => "Del",
        "LGUI" => "Super",
        "SCOLON" => ";",
        "QUOTE" => "'",
        "COMMA" => ",",
        "DOT" => ".",
        "SLASH" => "/",
        "BSLASH" => "\\",
        "LBRACKET" => "[",
        "RBRACKET" => "]",
        "GRAVE" => "`",
        "MINUS" => "-",
        "EQUAL" => "=",
        "LEFT" => "←",
        "DOWN" => "↓",
        "UP" => "↑",
        "RIGHT" => "→",
        "HOME" => "Home",
        "END" => "End",
        "PGUP" => "PgUp",
        "PGDOWN" => "PgDn",
        "APPLICATION" => "Menu",
        "COPY" => "Copy",
        "PSTE" => "Paste",
        "MPLY" => "Play",
        "MPRV" => "Prev",
        "MNXT" => "Next",
        "VOLD" => "Vol−",
        "VOLU" => "Vol+",
        "CAPSLOCK" => "Caps",
        "NO" => "",
        other => other,
    }
    .into()
}

pub fn positions() -> Vec<(Position, i32, i32)> {
    // Matrix coordinates from the W-CORNE Vial definition, including four inner keys.
    let mut result = Vec::new();
    for r in 0..3 {
        for c in 0..6 {
            result.push((
                (r, c),
                20 + c as i32 * 49,
                65 + r as i32 * 48 + [15, 15, 5, 0, 5, 10][c],
            ));
            let pos = if c < 5 { (r, c + 7) } else { (3, r + 9) };
            result.push((
                pos,
                440 + c as i32 * 49,
                65 + r as i32 * 48 + [10, 5, 0, 5, 15, 15][c],
            ));
        }
    }
    result.extend([
        ((3, 0), 314, 95),
        ((3, 1), 314, 143),
        ((0, 6), 391, 95),
        ((1, 6), 391, 143),
    ]);
    for c in 0..3 {
        result.push(((3, 3 + c), 167 + c as i32 * 49, 223 + c as i32 * 6));
        result.push(((3, 6 + c), 440 + c as i32 * 49, 235 - c as i32 * 6));
    }
    result
}

pub struct Renderer {
    font: Font,
}
impl Renderer {
    pub fn set_font(&mut self, path: &str) -> Result<()> {
        self.font = Font::from_bytes(std::fs::read(path)?, FontSettings::default())
            .map_err(anyhow::Error::msg)?;
        Ok(())
    }
    pub fn new() -> Result<Self> {
        let bytes = std::fs::read(env!("CORNE_OVERLAY_FONT"))?;
        let font = Font::from_bytes(bytes, FontSettings::default()).map_err(anyhow::Error::msg)?;
        Ok(Self { font })
    }
    fn text(
        &self,
        pixels: &mut [u8],
        scale: usize,
        text: &str,
        x: f32,
        baseline: f32,
        size: f32,
        center: bool,
        color: Color,
    ) {
        let size = size * scale as f32;
        let width: f32 = text
            .chars()
            .map(|c| self.font.metrics(c, size).advance_width)
            .sum();
        let mut x = x * scale as f32 - if center { width / 2.0 } else { 0.0 };
        let baseline = (baseline * scale as f32) as i32;
        let stride = WIDTH as usize * scale;
        for ch in text.chars() {
            let (m, bitmap) = self.font.rasterize(ch, size);
            let top = baseline - m.ymin - m.height as i32;
            for row in 0..m.height {
                for col in 0..m.width {
                    let px = x as i32 + m.xmin + col as i32;
                    let py = top + row as i32;
                    if px < 0 || py < 0 || px >= stride as i32 || py >= HEIGHT as i32 * scale as i32
                    {
                        continue;
                    }
                    let index = (py as usize * stride + px as usize) * 4;
                    let a = bitmap[row * m.width + col] as u32;
                    for (i, color) in color.0.iter().enumerate() {
                        pixels[index + i] = ((*color as u32 * a
                            + pixels[index + i] as u32 * (255 - a))
                            / 255) as u8;
                    }
                }
            }
            x += m.advance_width;
        }
    }
    pub fn render(
        &self,
        layout: &Layout,
        state: &Snapshot,
        scale: usize,
        appearance: &Appearance,
    ) -> Vec<u8> {
        let palette = &appearance.palette;
        let mut pixels = vec![0; WIDTH as usize * HEIGHT as usize * scale * scale * 4];
        rounded(
            &mut pixels,
            scale,
            (0, 0, WIDTH as i32, HEIGHT as i32),
            appearance.radius,
            palette.outline,
        );
        rounded(
            &mut pixels,
            scale,
            (1, 1, WIDTH as i32 - 2, HEIGHT as i32 - 2),
            (appearance.radius - 1.0).max(0.0),
            palette.surface,
        );
        let layer = *state.active.last().unwrap_or(&0);
        let title = match layer {
            0 => "QWERTY".into(),
            1 => "Numbers / Symbols".into(),
            2 => "Navigation / Media".into(),
            3 => "Function".into(),
            n => format!("Layer {n}"),
        };
        self.text(
            &mut pixels,
            scale,
            &title,
            22.0,
            32.0,
            18.0,
            false,
            palette.primary,
        );
        self.text(
            &mut pixels,
            scale,
            "W-CORNE · estimated layer",
            555.0,
            30.0,
            11.0,
            false,
            palette.on_surface_variant,
        );
        for (pos, x, y) in positions() {
            let color = if state.pressed.contains(&pos) {
                palette.primary
            } else {
                palette.surface_variant
            };
            rounded(
                &mut pixels,
                scale,
                (x, y, 44, 42),
                appearance.radius * 0.5,
                color,
            );
            let text = label(layout.key(pos, &state.active));
            let lines: Vec<_> = text.lines().collect();
            for (i, line) in lines.iter().enumerate() {
                let mut size = if lines.len() > 1 { 11.0f32 } else { 15.0f32 };
                let width: f32 = line
                    .chars()
                    .map(|c| self.font.metrics(c, size).advance_width)
                    .sum();
                if width > 38.0 {
                    size *= 38.0 / width;
                }
                let baseline = if lines.len() > 1 { 17 + i * 15 } else { 26 };
                self.text(
                    &mut pixels,
                    scale,
                    line,
                    (x + 22) as f32,
                    (y + baseline as i32) as f32,
                    size,
                    true,
                    if state.pressed.contains(&pos) {
                        palette.on_primary
                    } else {
                        palette.on_surface
                    },
                );
            }
        }
        pixels
    }
}
fn rounded(pixels: &mut [u8], scale: usize, rect: (i32, i32, i32, i32), radius: f32, color: Color) {
    let (x, y, w, h) = rect;
    let radius = radius.min(w as f32 / 2.0).min(h as f32 / 2.0);
    for py in y as usize * scale..(y + h) as usize * scale {
        for px in x as usize * scale..(x + w) as usize * scale {
            let lx = (px as f32 + 0.5) / scale as f32 - x as f32;
            let ly = (py as f32 + 0.5) / scale as f32 - y as f32;
            let dx = (radius - lx).max(lx - (w as f32 - radius)).max(0.0);
            let dy = (radius - ly).max(ly - (h as f32 - radius)).max(0.0);
            let alpha = if radius == 0.0 {
                1.0
            } else {
                ((radius - (dx * dx + dy * dy).sqrt()) * scale as f32 + 0.5).clamp(0.0, 1.0)
            };
            let i = (py * WIDTH as usize * scale + px) * 4;
            let old = pixels[i + 3] as f32 / 255.0;
            let total = alpha + old * (1.0 - alpha);
            if total > 0.0 {
                for c in 0..3 {
                    pixels[i + c] = ((color.0[c] as f32 * alpha
                        + pixels[i + c] as f32 * old * (1.0 - alpha))
                        / total)
                        .round() as u8;
                }
                pixels[i + 3] = (total * 255.0).round() as u8;
            }
        }
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn geometry_covers_every_physical_key_once() {
        let positions = positions();
        let unique: std::collections::BTreeSet<_> = positions.iter().map(|p| p.0).collect();
        assert_eq!(positions.len(), 46);
        assert_eq!(unique.len(), 46);
        assert!(!unique.contains(&(2, 6)));
        assert!(!unique.contains(&(3, 2)));
    }
    #[test]
    fn shifted_symbols() {
        assert_eq!(label("LSFT(KC_SCOLON)"), ":");
        assert_eq!(label("LSFT(KC_BSLASH)"), "|");
        assert_eq!(label("LSFT(KC_MINUS)"), "_");
        assert_eq!(label("LSFT(KC_1)"), "!");
    }
}
