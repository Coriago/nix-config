use super::*;
#[test]
fn text_remains_opaque_over_translucent_background() {
    let mut pixel = [20, 30, 40, 140];
    blend(&mut pixel, Color([230, 240, 250]), 1.0);
    assert_eq!(pixel, [230, 240, 250, 255]);
    let mut pixel = [0, 0, 0, 0];
    blend(&mut pixel, Color([230, 240, 250]), 0.5);
    assert_eq!(pixel, [230, 240, 250, 128]);
}
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
