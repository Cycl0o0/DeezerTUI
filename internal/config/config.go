// Package config centralizes OpenDeezer's user configuration (env vars +
// ~/.config/opendeezer files) for the bits shared between the TUI and the GUI
// engine (corelib): the control API and Discord Rich Presence settings.
package config

import (
	"net"
	"os"
	"path/filepath"
	"strings"
)

// Dir is ~/.config/opendeezer (platform UserConfigDir + "opendeezer").
func Dir() (string, error) {
	base, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, "opendeezer"), nil
}

func readFile(name string) string {
	// Primary: the platform config dir (macOS: ~/Library/Application Support).
	if dir, err := Dir(); err == nil {
		if b, err := os.ReadFile(filepath.Join(dir, name)); err == nil {
			return strings.TrimSpace(string(b))
		}
	}
	// Fallback: ~/.config/opendeezer (Linux-style), so a file placed there still
	// works on macOS where UserConfigDir differs.
	if home, err := os.UserHomeDir(); err == nil {
		if b, err := os.ReadFile(filepath.Join(home, ".config", "opendeezer", name)); err == nil {
			return strings.TrimSpace(string(b))
		}
	}
	return ""
}

// Control holds the control-API settings (remote control + MCP).
type Control struct {
	Enabled     bool
	Addr        string // host:port; "" -> 127.0.0.1:7654
	Token       string // bearer token ("" = no auth, localhost only)
	SameAccount bool   // require a matching Deezer account when no token (LAN)
}

// LoadControl reads the control-API config from $OPENDEEZER_CONTROL ("1"/addr) +
// $OPENDEEZER_CONTROL_TOKEN, else ~/.config/opendeezer/{control.txt,control-token.txt}.
func LoadControl() Control {
	c := Control{Addr: "127.0.0.1:7654"}
	v := strings.TrimSpace(os.Getenv("OPENDEEZER_CONTROL"))
	if v == "" {
		v = readFile("control.txt")
	}
	switch {
	case v == "":
		return c
	case v == "1" || strings.EqualFold(v, "on") || strings.EqualFold(v, "true"):
		c.Enabled = true
	case v == "0" || strings.EqualFold(v, "off"):
		c.Enabled = false
	default:
		c.Enabled = true
		c.Addr = v // an explicit host:port
	}
	c.Token = strings.TrimSpace(os.Getenv("OPENDEEZER_CONTROL_TOKEN"))
	if c.Token == "" {
		c.Token = readFile("control-token.txt")
	}
	// LAN bind + no token => default to same-account auth.
	if c.Enabled && c.Token == "" && !isLoopbackAddr(c.Addr) {
		c.SameAccount = true
	}
	if v := strings.TrimSpace(os.Getenv("OPENDEEZER_CONTROL_SAMEACCOUNT")); v != "" {
		c.SameAccount = v == "1" || strings.EqualFold(v, "on") || strings.EqualFold(v, "true")
	}
	return c
}

// writeFile writes contents to a file under Dir(), creating the directory if
// needed. Unlike readFile it only ever targets the primary (platform) config
// dir — there's exactly one place a setting should be written to.
func writeFile(name, contents string) error {
	dir, err := Dir()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, name), []byte(contents), 0600)
}

// SaveControlEnabled persists whether the control API starts automatically, so
// a Settings UI can flip it without editing env vars or config files by hand.
// addr is the bind address to remember while enabled (typically the current
// LoadControl().Addr); pass "" to disable.
func SaveControlEnabled(enabled bool, addr string) error {
	v := ""
	if enabled {
		v = strings.TrimSpace(addr)
	}
	return writeFile("control.txt", v)
}

// SaveControlToken persists the control-API bearer token. "" clears it, which
// falls back to same-account auth on a LAN bind.
func SaveControlToken(token string) error {
	return writeFile("control-token.txt", strings.TrimSpace(token))
}

// IsLoopbackAddr reports whether a host:port binds only the loopback interface.
func IsLoopbackAddr(addr string) bool { return isLoopbackAddr(addr) }

// isLoopbackAddr reports whether a host:port binds only the loopback interface.
func isLoopbackAddr(addr string) bool {
	host, _, err := net.SplitHostPort(addr)
	if err != nil {
		host = addr
	}
	switch host {
	case "", "0.0.0.0", "::":
		return false // wildcard = all interfaces
	case "localhost":
		return true
	}
	if ip := net.ParseIP(host); ip != nil {
		return ip.IsLoopback()
	}
	return false
}

// LoadPeers returns manually-configured Connect peer addresses (host[:port]),
// from $OPENDEEZER_CONNECT_PEERS (comma-separated) and
// ~/.config/opendeezer/connect-peers.txt (one per line). These are merged into
// the device picker alongside LAN discovery, so Connect works over networks that
// carry no multicast/broadcast (e.g. Tailscale/VPN — unicast-only meshes).
func LoadPeers() []string {
	var out []string
	seen := map[string]bool{}
	add := func(s string) {
		s = strings.TrimSpace(s)
		if s != "" && !strings.HasPrefix(s, "#") && !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	for _, p := range strings.Split(os.Getenv("OPENDEEZER_CONNECT_PEERS"), ",") {
		add(p)
	}
	for _, line := range strings.Split(readFile("connect-peers.txt"), "\n") {
		add(line)
	}
	return out
}

// NormalizePeer turns user input ("host", "host:port", "http://host:port") into
// a base URL + host:port, defaulting the port to 7654. Returns ("","") if empty.
func NormalizePeer(addr string) (base, hostport string) {
	addr = strings.TrimSpace(addr)
	addr = strings.TrimPrefix(addr, "http://")
	addr = strings.TrimPrefix(addr, "https://")
	addr = strings.TrimRight(addr, "/")
	if addr == "" {
		return "", ""
	}
	if !strings.Contains(addr, ":") {
		addr += ":7654"
	}
	return "http://" + addr, addr
}

// LoadDiscordAppID returns the Discord application id for Rich Presence, from
// $OPENDEEZER_DISCORD_APP_ID or ~/.config/opendeezer/discord-app-id.txt. Empty
// disables the feature.
func LoadDiscordAppID() string {
	if v := strings.TrimSpace(os.Getenv("OPENDEEZER_DISCORD_APP_ID")); v != "" {
		return v
	}
	return readFile("discord-app-id.txt")
}
