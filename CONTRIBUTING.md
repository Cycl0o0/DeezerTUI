# Contributing to OpenDeezer

Thanks for your interest in OpenDeezer.

## Development

The engine and TUI are pure Go (cgo only for ALSA on Linux and the c-archive
used by the native GUIs).

```sh
go build ./...                       # build everything
go test ./...                        # run tests
go test -race ./...                  # race detector (what CI runs)
go vet ./...                         # static checks
golangci-lint run                    # lint (see .golangci.yml)
```

Build the shared engine for the native GUIs:

```sh
CGO_ENABLED=1 go build -buildmode=c-archive -o libdeezercore.a ./corelib
```

Run the TUI (needs a Deezer Premium ARL — see the README):

```sh
go run ./cmd/opendeezer
OPENDEEZER_LOG=debug go run ./cmd/opendeezer   # with debug logging to opendeezer.log
```

## Architecture

- `internal/deezer` — API client (ARL login, gw-light + REST browse, lyrics,
  charts, artist profiles) and Blowfish stream decryption.
- `internal/audio` — oto-backed player (MP3 + FLAC, seek, ReplayGain).
- `internal/queue` — shared playback queue (shuffle/repeat/history).
- `internal/ui` — Bubble Tea TUI.
- `internal/log` — leveled file logging.
- `corelib` — the `DZ*` C API consumed by the native GUIs.
- `gui/*` — native frontends (macOS SwiftUI, GNOME GTK, KDE Qt, Windows WinUI,
  unified Linux launcher).

## Pull requests

- Keep the build, `go vet`, and `go test -race ./...` green.
- Match the surrounding style; add tests for new logic where practical.
- New `DZ*` exports must also be added to `gui/windows/libdeezercore.def`.
- Commits are authored by the project owner only — do not add co-author trailers.

## Scope & legality

OpenDeezer is a **Premium-only streaming client** — no downloads, no piracy. It
does not bypass Deezer's DRM beyond what an authenticated client already streams,
and is not affiliated with Deezer. Please keep contributions within that scope.
