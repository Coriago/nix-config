use super::*;
fn state() -> Layers {
    let mut layout = vec![vec![vec![serde_json::json!("KC_TRNS"); 12]; 4]; 4];
    layout[0][3][5] = serde_json::json!("LT1(KC_TAB)");
    layout[0][3][6] = serde_json::json!("LT2(KC_BSPACE)");
    layout[0][3][11] = serde_json::json!("OSL(3)");
    layout[0][0][1] = serde_json::json!("KC_Q");
    layout[1][0][1] = serde_json::json!("KC_1");
    layout[2][3][5] = serde_json::json!("KC_NO");
    Layers::new(Layout { uid: UID, layout }, Duration::from_millis(200))
}
fn step(s: &mut Layers, keys: &[Position], ms: u64) {
    s.update(&keys.iter().copied().collect(), Duration::from_millis(ms));
}
#[test]
fn threshold_and_release() {
    let mut s = state();
    step(&mut s, &[(3, 5)], 0);
    step(&mut s, &[(3, 5)], 199);
    assert_eq!(s.active, Active::from([0]));
    step(&mut s, &[(3, 5)], 200);
    assert_eq!(s.active, Active::from([0, 1]));
    step(&mut s, &[], 201);
    assert_eq!(s.active, Active::from([0]));
}
#[test]
fn quick_tap_never_activates() {
    let mut s = state();
    step(&mut s, &[(3, 5)], 0);
    step(&mut s, &[], 100);
    step(&mut s, &[], 300);
    assert_eq!(s.active, Active::from([0]));
}
#[test]
fn overlapping_layers_preserve_press_bindings_and_transparency() {
    let mut s = state();
    step(&mut s, &[(3, 5)], 0);
    step(&mut s, &[(3, 5), (3, 6)], 210);
    step(&mut s, &[(3, 5), (3, 6)], 420);
    assert_eq!(s.active, Active::from([0, 1, 2]));
    assert_eq!(s.layout.key((0, 1), &s.active), "KC_1");
    step(&mut s, &[(3, 5)], 430);
    assert_eq!(s.active, Active::from([0, 1]));
}
#[test]
fn disabled_key_does_not_activate_lower_layer_binding() {
    let mut s = state();
    step(&mut s, &[(3, 6)], 0);
    step(&mut s, &[(3, 6)], 210);
    step(&mut s, &[(3, 5), (3, 6)], 220);
    step(&mut s, &[(3, 5), (3, 6)], 440);
    assert_eq!(s.active, Active::from([0, 2]));
}
#[test]
fn oneshot_is_intentionally_hold_only() {
    let mut s = state();
    step(&mut s, &[(3, 11)], 0);
    assert_eq!(s.active, Active::from([0, 3]));
    step(&mut s, &[], 10);
    assert_eq!(s.active, Active::from([0]));
}
