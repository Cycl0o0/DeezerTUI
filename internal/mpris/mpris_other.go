//go:build !linux

package mpris

// New returns a no-op controller on non-Linux platforms (MPRIS is D-Bus/Linux).
func New(Commands) Controller { return noop{} }
