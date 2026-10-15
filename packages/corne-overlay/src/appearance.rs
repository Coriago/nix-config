use anyhow::{ensure, Result};
use serde::{Deserialize, Deserializer};
use smithay_client_toolkit::shell::wlr_layer::Anchor;
use std::{io::Read, path::Path};

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Color(pub [u8; 3]);
impl<'de> Deserialize<'de> for Color {
    fn deserialize<D: Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        let text = String::deserialize(d)?;
        let hex = text.strip_prefix('#').unwrap_or("");
        if hex.len() != 6 || !hex.is_ascii() {
            return Err(serde::de::Error::custom("Expected #RRGGBB"));
        }
        let value = u32::from_str_radix(hex, 16).map_err(serde::de::Error::custom)?;
        Ok(Self([(value >> 16) as u8, (value >> 8) as u8, value as u8]))
    }
}

#[derive(Clone, Debug, PartialEq, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Palette {
    pub surface: Color,
    pub on_surface: Color,
    pub surface_variant: Color,
    pub on_surface_variant: Color,
    pub primary: Color,
    pub on_primary: Color,
    pub outline: Color,
}
impl Default for Palette {
    fn default() -> Self {
        Self {
            surface: Color([15, 18, 25]),
            on_surface: Color([225, 235, 250]),
            surface_variant: Color([31, 39, 51]),
            on_surface_variant: Color([157, 172, 193]),
            primary: Color([114, 179, 223]),
            on_primary: Color([12, 30, 44]),
            outline: Color([65, 77, 94]),
        }
    }
}
#[derive(Clone, Copy, Debug, Default, PartialEq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Position {
    TopLeft,
    TopCenter,
    TopRight,
    CenterLeft,
    Center,
    CenterRight,
    BottomLeft,
    #[default]
    BottomCenter,
    BottomRight,
}
impl Position {
    pub fn anchor(self) -> Anchor {
        use Position::*;
        match self {
            TopLeft => Anchor::TOP | Anchor::LEFT,
            TopCenter => Anchor::TOP,
            TopRight => Anchor::TOP | Anchor::RIGHT,
            CenterLeft => Anchor::LEFT,
            Center => Anchor::empty(),
            CenterRight => Anchor::RIGHT,
            BottomLeft => Anchor::BOTTOM | Anchor::LEFT,
            BottomCenter => Anchor::BOTTOM,
            BottomRight => Anchor::BOTTOM | Anchor::RIGHT,
        }
    }
}
#[derive(Clone, Debug, PartialEq, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Appearance {
    pub position: Position,
    pub output: String,
    pub margin: i32,
    pub preview: Option<usize>,
    pub always_visible: bool,
    pub avoid_caret: bool,
    pub animation_ms: u64,
    pub background_opacity: f32,
    pub key_opacity: f32,
    pub palette: Palette,
    pub radius: f32,
    pub font_file: Option<String>,
}
impl Default for Appearance {
    fn default() -> Self {
        Self {
            position: Position::default(),
            output: String::new(),
            margin: 36,
            preview: None,
            always_visible: false,
            avoid_caret: true,
            animation_ms: 180,
            background_opacity: 1.0,
            key_opacity: 1.0,
            palette: Palette::default(),
            radius: 12.0,
            font_file: None,
        }
    }
}
impl Appearance {
    pub fn load(path: &Path, layers: usize) -> Result<Self> {
        let mut raw = String::new();
        std::fs::File::open(path)?
            .take(65537)
            .read_to_string(&mut raw)?;
        ensure!(raw.len() <= 65536, "Appearance file is too large");
        let value: Self = serde_json::from_str(&raw)?;
        ensure!((0..=500).contains(&value.margin), "Margin must be 0–500");
        ensure!(value.animation_ms <= 2000, "Animation must be 0–2000 ms");
        ensure!(
            [value.background_opacity, value.key_opacity]
                .iter()
                .all(|v| v.is_finite() && (0.0..=1.0).contains(v)),
            "Opacity must be 0–1"
        );
        ensure!(
            value.radius.is_finite() && (0.0..=24.0).contains(&value.radius),
            "Radius must be 0–24"
        );
        ensure!(
            value.preview.is_none_or(|n| n < layers),
            "Preview layer outside layout"
        );
        Ok(value)
    }
}
#[cfg(test)]
#[path = "../checks/appearance.rs"]
mod tests;
