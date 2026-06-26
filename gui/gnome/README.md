# OpenDeezer (GNOME)

Native GNOME front-end for OpenDeezer — a GTK4 + libadwaita desktop client with a
Deezer-purple accent. The whole engine (login, browse, Blowfish decrypt, MP3
decode, ALSA playback) is the Go core compiled to a C static archive
(`lib/libdeezercore.a`) and linked in-process; this directory is UI only.

## Look & layout

- **AdwNavigationSplitView:** a `navigation-sidebar` listing **Liked Songs** and
  your **playlists**, beside a `GtkColumnView` track table (Title · Artist ·
  Album · Time).
- **Now-playing bar** pinned to the bottom: cover art, title/artist,
  prev/play-pause/next, a seek scrubber, position/duration, and a volume slider.
- **Search** lives in the content header bar — press Enter to search Deezer.
- **Theme:** Deezer "Electric Violet" `#A238FF` accent via a `GtkCssProvider`
  (libadwaita 1.6 accent variables with a pre-1.6 named-color fallback), forced
  dark color scheme.
- **About** (menu button, top-left) credits **Cycl0o0**, AGPL-3.0.

All blocking engine calls (login, browse, play, cover fetch) run on `GTask`
worker threads; cheap player state is polled from a 300 ms `g_timeout` that also
drives the scrubber and auto-advances when a track ends.

## Build & run

```sh
cd gui/gnome
chmod +x build.sh        # first time only
./build.sh               # builds the Go archive, then meson + ninja
./opendeezer-gnome
```

`build.sh` always rebuilds `lib/libdeezercore.a` from `../../corelib` first, so
the app and the engine never drift.

### Dependencies (Debian/Ubuntu)

```sh
sudo apt install \
  golang gcc pkg-config meson ninja-build \
  libgtk-4-dev libadwaita-1-dev libjson-glib-dev libasound2-dev
```

`libasound2-dev` is required at build/link time (the engine's `oto/v3` audio
backend hard-links ALSA via `#cgo pkg-config: alsa`); at runtime the host needs
`libasound.so.2`. The Go core uses pure-Go crypto/HTTP, so **no** libssl/libcurl
is needed.

### ARL / login

The ARL is read from `$DEEZER_ARL`, falling back to
`~/.config/opendeezer/arl.txt` (same as the TUI). Without one, the app shows a
toast and stays on an empty library.

## Files

```
src/main.c   the whole app (DzTrack model, sidebar, column view, player bar,
             async browse/play/cover, polling, About, theme)
meson.build  links lib/libdeezercore.a + -lasound -lpthread -ldl -lm
build.sh     builds the Go archive, then configures + compiles with meson
data/        .desktop entry
lib/         generated libdeezercore.{a,h} (git-ignored, produced by build.sh)
```

The C API is defined in `../../corelib/deezercore.go`
(`go build -buildmode=c-archive`).
