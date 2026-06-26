// OpenDeezer (KDE) entry point. Qt6 Widgets follows the system Breeze QStyle on
// Plasma with zero effort, so the window looks native; only the accent widgets
// are restyled Deezer-purple (see MainWindow::buildTransport).
#include <QApplication>
#include <QIcon>

#include "mainwindow.h"

int main(int argc, char **argv) {
    QApplication app(argc, argv);
    QApplication::setApplicationName("OpenDeezer");
    QApplication::setApplicationDisplayName("OpenDeezer");
    QApplication::setOrganizationName("OpenDeezer");
    QApplication::setDesktopFileName("org.opendeezer.OpenDeezer");

    // App/window icon: prefer the theme (when installed), else the PNG shipped
    // next to the binary (build.sh copies opendeezer.png into the build dir).
    QIcon icon = QIcon::fromTheme("org.opendeezer.OpenDeezer");
    if (icon.isNull())
        icon = QIcon(QCoreApplication::applicationDirPath() + "/opendeezer.png");
    QApplication::setWindowIcon(icon);

    // Background playback: hiding the window to the tray must not quit the app.
    // Exit happens only on an explicit Quit (MainWindow::quitApp / closeEvent).
    QApplication::setQuitOnLastWindowClosed(false);

    MainWindow w;
    w.resize(1100, 720);
    w.show();
    return app.exec();
}
