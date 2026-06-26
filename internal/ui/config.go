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

// LoadQuality reads the persisted quality level: 0=Normal, 1=High, 2=HiFi.
func LoadQuality() int {
	dir, err := configDir()
	if err != nil {
		return 0
	}
	b, err := os.ReadFile(filepath.Join(dir, "quality.txt"))
	if err != nil {
		return 0
	}
	switch strings.TrimSpace(string(b)) {
	case "high":
		return 1
	case "hifi", "flac", "lossless":
		return 2
	default:
		return 0
	}
}

// SaveQuality persists the quality level (0..2).
func SaveQuality(level int) error {
	dir, err := configDir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	v := "normal"
	switch level {
	case 1:
		v = "high"
	case 2:
		v = "hifi"
	}
	return os.WriteFile(filepath.Join(dir, "quality.txt"), []byte(v+"\n"), 0600)
}
