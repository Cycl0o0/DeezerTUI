package ui

import (
	"os"
	"path/filepath"
	"strings"
)

// configDir is ~/.config/opendeezer.
func configDir() (string, error) {
	base, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, "opendeezer"), nil
}

// LoadARL resolves the Deezer ARL from, in order: $DEEZER_ARL, then
// ~/.config/opendeezer/arl.txt. Returns "" if neither is set.
func LoadARL() string {
	if v := strings.TrimSpace(os.Getenv("DEEZER_ARL")); v != "" {
		return v
	}
	dir, err := configDir()
	if err != nil {
		return ""
	}
	b, err := os.ReadFile(filepath.Join(dir, "arl.txt"))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// SaveARL writes the ARL to ~/.config/opendeezer/arl.txt (0600).
func SaveARL(arl string) error {
	dir, err := configDir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, "arl.txt"), []byte(strings.TrimSpace(arl)+"\n"), 0600)
}
