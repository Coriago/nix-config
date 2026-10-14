use super::*;
#[test]
fn palette_and_position_from_noctalia() {
    let config: Appearance = serde_json::from_str(
        r##"{"position":"top_right","margin":24,"palette":{"primary":"#a6e22e"}}"##,
    )
    .unwrap();
    assert_eq!(config.position.anchor(), Anchor::TOP | Anchor::RIGHT);
    assert_eq!(config.palette.primary, Color([166, 226, 46]));
    assert_eq!(config.palette.on_surface, Palette::default().on_surface);
}
#[test]
fn malformed_values_are_rejected() {
    assert!(serde_json::from_str::<Appearance>(r##"{"palette":{"primary":"#gggggg"}}"##).is_err());
    assert!(serde_json::from_str::<Appearance>(r#"{"position":"typo"}"#).is_err());
}
#[test]
fn center_reserves_no_edges() {
    assert!(Position::Center.anchor().is_empty());
}
