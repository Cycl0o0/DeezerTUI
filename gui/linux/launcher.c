/*
 * OpenDeezer — unified Linux launcher.
 *
 * One `opendeezer` command that auto-selects the native toolkit for the running
 * desktop (LibreOffice-style): Qt/Breeze on KDE-family desktops, GTK4/libadwaita
 * elsewhere. It dlopen()s the matching backend shared library and calls its
 * exported opendeezer_run(); if the preferred toolkit's libraries aren't
 * installed (dlopen fails), it falls back to the other backend.
 *
 * The backends (libopendeezer-qt.so / libopendeezer-gtk.so) sit next to this
 * binary; it is linked with rpath $ORIGIN so they resolve without an install.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>

typedef int (*run_fn)(int, char **);

/* case-insensitive "does env var s contain needle" */
static int env_has(const char *name, const char *needle) {
    const char *v = getenv(name);
    return v && strcasestr(v, needle) != NULL;
}

static int prefers_qt(void) {
    static const char *vars[] = {"XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP",
                                 "DESKTOP_SESSION", NULL};
    static const char *qt_des[] = {"KDE", "plasma", "lxqt", "deepin",
                                   "razor", "ukui", NULL};
    for (int i = 0; vars[i]; i++)
        for (int j = 0; qt_des[j]; j++)
            if (env_has(vars[i], qt_des[j]))
                return 1;
    return 0;
}

static int try_backend(const char *lib, int argc, char **argv) {
    void *h = dlopen(lib, RTLD_NOW | RTLD_LOCAL);
    if (!h)
        return -1; /* toolkit libs missing — caller tries the fallback */
    run_fn run = (run_fn)dlsym(h, "opendeezer_run");
    if (!run) {
        dlclose(h);
        return -1;
    }
    return run(argc, argv);
}

int main(int argc, char **argv) {
    const char *qt = "libopendeezer-qt.so";
    const char *gtk = "libopendeezer-gtk.so";
    const char *first = prefers_qt() ? qt : gtk;
    const char *second = prefers_qt() ? gtk : qt;

    int rc = try_backend(first, argc, argv);
    if (rc != -1)
        return rc;
    rc = try_backend(second, argc, argv);
    if (rc != -1)
        return rc;

    fprintf(stderr,
            "OpenDeezer: no usable GUI backend found.\n"
            "Install GTK4 + libadwaita (GNOME) or Qt6 (KDE) runtime libraries.\n");
    return 1;
}
