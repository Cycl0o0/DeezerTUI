# DeezerTUI

A terminal Deezer client. Log in with your Deezer ARL, browse your liked songs,
playlists and search, and stream — the track is downloaded, Blowfish
stripe-decrypted, MP3-decoded and played **locally**. Your ARL never leaves your
machine except in the requests it makes to Deezer.

Go port of [DiizerU](../DiizerU), a Deezer client for the Wii U. Same on-device
model, a Bubble Tea TUI instead of SDL/GamePad.

## Requirements

- Go 1.24+
- A Deezer **Premium** account
- A working audio output device

## Setup

```sh
go build -o deezertui ./cmd/deezertui
./deezertui -save-arl <your-arl>   # writes ~/.config/deezertui/arl.txt (0600)
./deezertui
```

Or pass it inline: `DEEZER_ARL=<your-arl> ./deezertui`.

Your ARL is the `arl` cookie from an authenticated `deezer.com` browser session.
Treat it like a password — it grants access to your account.

## Controls

| Key | Action |
|-----|--------|
| ↑/↓ | move |
| enter | open / play |
| esc / backspace | back to menu |
| space | play / pause |
| n / p | next / previous |
| r | cycle repeat (off → all → one) |
| s | stop |
| / | search |
| q | quit |

## How it works

```
ARL ─login (gw-light)→ browse (gw + public REST)
                     → resolve track → encrypted CDN URL
                     → HTTP GET → Blowfish BF_CBC_STRIPE decrypt
                     → MP3 decode (go-mp3) → PCM out (oto)
```

- `internal/deezer` — login, browse, track→URL resolve, and the stripe decryptor.
- `internal/audio` — streaming decrypt + decode + playback.
- `internal/ui` — the Bubble Tea TUI and config.

## The fine print

Personal/educational use, your own Premium account, your own risk. It reaches
Deezer the unofficial way and decrypts your own entitled content locally, which
almost certainly breaks Deezer's terms for third-party apps. Not affiliated with
Deezer. AGPL-3.0, like the original DiizerU.
