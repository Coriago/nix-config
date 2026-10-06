#include <QApplication>
#include <QColor>
#include <QPalette>
#include <QString>
#include <QVariant>

int main(int argc, char **argv) {
  QApplication app(argc, argv);
  app.processEvents();
  const QString expected = qEnvironmentVariable("HOME")
      + "/.local/share/color-schemes/noctalia.colors";
  if (app.property("KDE_COLOR_SCHEME_PATH").toString() != expected)
    return 1;
  if (app.palette().color(QPalette::Window) != QColor(17, 34, 51))
    return 2;
  return 0;
}
