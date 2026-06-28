//go:build !windows

package discord

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"time"
)

// dialIPC finds and connects to Discord's IPC socket (discord-ipc-0..9 under one
// of the runtime/temp dirs, including Flatpak/Snap nestings).
func dialIPC() (net.Conn, error) {
	for _, dir := range ipcDirs() {
		for i := 0; i < 10; i++ {
			p := filepath.Join(dir, fmt.Sprintf("discord-ipc-%d", i))
			if c, err := net.DialTimeout("unix", p, 2*time.Second); err == nil {
				return c, nil
			}
		}
	}
	return nil, errNoIPC
}

func ipcDirs() []string {
	var dirs []string
	seen := map[string]bool{}
	add := func(d string) {
		if d == "" || seen[d] {
			return
		}
		seen[d] = true
		dirs = append(dirs, d)
	}
	bases := []string{
		os.Getenv("XDG_RUNTIME_DIR"),
		os.Getenv("TMPDIR"),
		os.Getenv("TMP"),
		os.Getenv("TEMP"),
		"/tmp",
	}
	for _, b := range bases {
		add(b)
		// Flatpak / Snap place the socket in a nested app dir.
		add(filepath.Join(b, "app", "com.discordapp.Discord"))
		add(filepath.Join(b, "snap.discord"))
	}
	return dirs
}
