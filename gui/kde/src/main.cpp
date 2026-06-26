// OpenDeezer (KDE) entry point. Qt6 Widgets follows the system Breeze QStyle on
// Plasma with zero effort, so the window looks native; only the accent widgets
// are restyled Deezer-purple (see MainWindow::buildTransport).
#include <QApplication>

#include "mainwindow.h"

int main(int argc, char **argv) {
    QApplication app(argc, argv);
    QApplication::setApplicationName("OpenDeezer");
    QApplication::setApplicationDisplayName("OpenDeezer");
    QApplication::setOrganizationName("OpenDeezer");
    QApplication::setDesktopFileName("org.opendeezer.OpenDeezer");

    MainWindow w;
    w.resize(1100, 720);
    w.show();
    return app.exec();
}
