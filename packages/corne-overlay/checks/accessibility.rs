use super::*;
#[link(name = "glib-2.0")]
extern "C" {
    fn g_malloc(size: usize) -> *mut c_void;
    fn g_error_new_literal(domain: u32, code: i32, message: *const libc::c_char) -> *mut c_void;
}
#[test]
fn failed_geometry_query_is_rejected_even_with_a_nonnull_rectangle() {
    unsafe {
        let result = rect_call(|error| {
            let rect = g_malloc(std::mem::size_of::<AtspiRect>()).cast::<AtspiRect>();
            rect.write(AtspiRect {
                x: 10,
                y: 20,
                width: 8,
                height: 16,
            });
            *error = g_error_new_literal(1, 1, c"Unsupported coordinate space".as_ptr());
            rect
        });
        assert_eq!(result, None);
    }
}
