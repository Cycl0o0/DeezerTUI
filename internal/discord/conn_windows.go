//go:build windows

package discord

import "net"

// dialIPC is unsupported on Windows for now: Discord uses a named pipe
// (\\?\pipe\discord-ipc-0) which needs a winio dependency. Rich Presence is a
// no-op here until that's added.
func dialIPC() (net.Conn, error) { return nil, errNoIPC }
