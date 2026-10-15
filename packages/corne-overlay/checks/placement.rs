use super::*;
use crate::geometry::normalize;
fn output() -> Rect {
    Rect {
        x: 2560.,
        y: 0.,
        w: 1920.,
        h: 1080.,
    }
}
fn caret(y: f64) -> Option<Rect> {
    Some(Rect {
        x: 3500.,
        y,
        w: 10.,
        h: 20.,
    })
}
fn step(p: &mut Placement, c: Option<Rect>, t: Instant) -> i32 {
    p.update(
        Area {
            output: output(),
            size: (750., 296.),
            margin: 36.,
        },
        c,
        Duration::ZERO,
        t,
        true,
    )
}
#[test]
fn avoids_caret_and_returns_with_hysteresis() {
    let mut p = Placement::default();
    let t = Instant::now();
    assert_eq!(step(&mut p, caret(700.), t), 36);
    assert_eq!(step(&mut p, caret(100.), t), 748);
    assert_eq!(step(&mut p, caret(400.), t), 748);
    assert_eq!(step(&mut p, caret(400.), t + Duration::from_secs(2)), 748);
    assert_eq!(step(&mut p, caret(700.), t + Duration::from_secs(3)), 748);
    assert_eq!(step(&mut p, caret(700.), t + Duration::from_secs(4)), 36);
}
#[test]
fn unrelated_monitor_and_missing_caret_prefer_top() {
    let mut p = Placement::default();
    let t = Instant::now();
    assert_eq!(
        step(
            &mut p,
            Some(Rect {
                x: 100.,
                y: 100.,
                w: 10.,
                h: 20.
            }),
            t
        ),
        36
    );
    assert_eq!(step(&mut p, caret(100.), t), 748);
    step(&mut p, None, t);
    assert_eq!(step(&mut p, None, t + Duration::from_secs(1)), 36);
}
#[test]
fn movement_is_animated_and_disabling_animation_snaps() {
    let mut p = Placement::default();
    let t = Instant::now();
    let mut update = |c, now, duration| {
        p.update(
            Area {
                output: output(),
                size: (750., 296.),
                margin: 36.,
            },
            c,
            duration,
            now,
            true,
        )
    };
    let d = Duration::from_millis(180);
    assert_eq!(update(None, t, d), 36);
    assert_eq!(update(caret(100.), t, d), 36);
    let middle = update(caret(100.), t + Duration::from_millis(90), d);
    assert!(middle > 36 && middle < 748);
    assert_eq!(
        update(caret(100.), t + Duration::from_millis(100), Duration::ZERO),
        748
    );
}
#[test]
fn coordinates_use_frame_origin_and_compositor_scale() {
    let frame = Rect {
        x: 0.,
        y: 0.,
        w: 1000.,
        h: 800.,
    };
    let window = Rect {
        x: 2560.,
        y: 44.,
        w: 500.,
        h: 400.,
    };
    let caret = Rect {
        x: 40.,
        y: 100.,
        w: 10.,
        h: 20.,
    };
    assert_eq!(
        normalize(caret, frame, window),
        Some(Rect {
            x: 2580.,
            y: 94.,
            w: 5.,
            h: 10.
        })
    );
    assert!(normalize(Rect { x: -100., ..caret }, frame, window).is_none());
    assert!(normalize(caret, Rect { w: 0., ..frame }, window).is_none());
}

#[test]
fn caret_beside_overlay_does_not_trigger_a_move() {
    let mut p = Placement::default();
    assert_eq!(
        step(
            &mut p,
            Some(Rect {
                x: 2700.,
                y: 100.,
                w: 10.,
                h: 20.
            }),
            Instant::now()
        ),
        36
    );
}

#[test]
fn output_entry_animates_to_destination_and_respects_animation_setting() {
    let t = Instant::now();
    let d = Duration::from_millis(180);
    for (caret, target) in [(None, 36), (caret(100.), 748)] {
        let mut p = Placement::default();
        let update = |p: &mut Placement, now, duration, visible| {
            p.update(
                Area {
                    output: output(),
                    size: (750., 296.),
                    margin: 36.,
                },
                caret,
                duration,
                now,
                visible,
            )
        };
        p.enter_output();
        let start = update(&mut p, t, d, true);
        assert_ne!(start, target);
        let middle = update(&mut p, t + d / 2, d, true);
        assert!(middle > start.min(target) && middle < start.max(target));
        assert_eq!(update(&mut p, t + d, d, true), target);
        p.enter_output();
        assert_eq!(update(&mut p, t, Duration::ZERO, true), target);
        p.enter_output();
        assert_eq!(update(&mut p, t, d, false), target);
    }
}

#[test]
fn output_exit_uses_nearest_edge_and_finishes_offscreen() {
    let t = Instant::now();
    let d = Duration::from_millis(180);
    for (start, end) in [(36., -296.), (748., 1080.)] {
        let motion = Motion::exit(start, 1080., 296., t);
        assert_eq!(motion.sample(t, d), (start, false));
        let (middle, finished) = motion.sample(t + d / 2, d);
        assert!(!finished);
        assert!(middle > start.min(end) && middle < start.max(end));
        assert_eq!(motion.sample(t + d, d), (end, true));
        assert_eq!(motion.sample(t, Duration::ZERO), (end, true));
    }
}
