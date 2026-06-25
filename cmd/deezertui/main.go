// Command deezertui is a terminal Deezer client: log in with your ARL, browse
// liked songs / playlists / search, and stream — decrypt + decode + play all
// locally. Your ARL never leaves your machine except in requests to Deezer.
//
// Ported from the DiizerU Wii U client.
package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/Cycl0o0/DeezerTUI/internal/audio"
	"github.com/Cycl0o0/DeezerTUI/internal/deezer"
	"github.com/Cycl0o0/DeezerTUI/internal/ui"

	tea "github.com/charmbracelet/bubbletea"
)

// version is set at build time via -ldflags "-X main.version=...".
var version = "dev"

func main() {
	saveARL := flag.String("save-arl", "", "save this ARL to ~/.config/deezertui/arl.txt and exit")
	showVer := flag.Bool("version", false, "print version and exit")
	flag.Parse()

	if *showVer {
		fmt.Println("deezertui", version)
		return
	}

	if *saveARL != "" {
		if err := ui.SaveARL(*saveARL); err != nil {
			fmt.Fprintln(os.Stderr, "save-arl:", err)
			os.Exit(1)
		}
		fmt.Println("ARL saved.")
		return
	}

	arl := ui.LoadARL()
	if arl == "" {
		fmt.Fprintln(os.Stderr, "No ARL found. Set $DEEZER_ARL or run:")
		fmt.Fprintln(os.Stderr, "  deezertui -save-arl <your-arl>")
		fmt.Fprintln(os.Stderr, "\nYour ARL is the 'arl' cookie from an authenticated deezer.com session.")
		os.Exit(1)
	}

	player, err := audio.NewPlayer()
	if err != nil {
		fmt.Fprintln(os.Stderr, "audio:", err)
		os.Exit(1)
	}

	ui.Version = version
	client := deezer.New(arl)
	model := ui.New(client, player)

	p := tea.NewProgram(model, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
