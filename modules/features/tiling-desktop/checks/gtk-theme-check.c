#include <gtk/gtk.h>
#include <string.h>

int main(int argc, char **argv) {
  gtk_init(&argc, &argv);
  const char *names[] = {"adw-gtk3", "adw-gtk3-dark"};
  for (unsigned i = 0; i < G_N_ELEMENTS(names); i++) {
    GtkCssProvider *named = gtk_css_provider_get_named(names[i], NULL);
    GtkCssProvider *direct = gtk_css_provider_new();
    char *path = g_build_filename(g_getenv("GTK_DATA_PREFIX"), "share",
                                 "themes", names[i], "gtk-3.0", "gtk.css", NULL);
    GError *error = NULL;
    g_assert_true(gtk_css_provider_load_from_path(direct, path, &error));
    g_assert_no_error(error);
    char *actual = gtk_css_provider_to_string(named);
    char *expected = gtk_css_provider_to_string(direct);
    // A missing theme silently falls back to Adwaita: compare parsed CSS.
    g_assert_cmpstr(actual, ==, expected);
    g_assert_cmpuint(strlen(actual), >, 1000);
    g_free(actual);
    g_free(expected);
    g_free(path);
    g_object_unref(direct);
  }
  return 0;
}
