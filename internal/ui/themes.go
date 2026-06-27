package ui

import (
	"github.com/charmbracelet/bubbles/list"
	"github.com/charmbracelet/lipgloss"
)

// palette is a named color scheme for the TUI.
type palette struct {
	name   string
	accent lipgloss.Color // titles, progress fill, now-playing
	dim    lipgloss.Color // secondary text
	empty  lipgloss.Color // progress remainder
	border lipgloss.Color // footer border
	status lipgloss.Color // status line
}

// palettes are cycled with the "t" key; the first is the default.
var palettes = []palette{
	{"deezer", "213", "241", "238", "238", "220"},
	{"ocean", "39", "245", "237", "24", "51"},
	{"sunset", "208", "245", "237", "166", "214"},
	{"mono", "252", "243", "238", "240", "250"},
	{"matrix", "46", "240", "236", "238", "82"},
}

var themeIndex int

// applyTheme restyles the shared style vars and the list delegate for palette i.
func (m *Model) applyTheme(i int) {
	if i < 0 || i >= len(palettes) {
		i = 0
	}
	themeIndex = i
	p := palettes[i]

	accent = lipgloss.NewStyle().Foreground(p.accent).Bold(true)
	dim = lipgloss.NewStyle().Foreground(p.dim)
	barFill = lipgloss.NewStyle().Foreground(p.accent)
	barEmpty = lipgloss.NewStyle().Foreground(p.empty)
	footerBox = lipgloss.NewStyle().Border(lipgloss.NormalBorder(), true, false, false, false).
		BorderForeground(p.border)
	statusSty = lipgloss.NewStyle().Foreground(p.status)

	d := list.NewDefaultDelegate()
	d.Styles.SelectedTitle = d.Styles.SelectedTitle.Foreground(p.accent).BorderForeground(p.accent)
	d.Styles.SelectedDesc = d.Styles.SelectedDesc.Foreground(p.dim).BorderForeground(p.accent)
	m.list.SetDelegate(d)
}

// applyThemeByName applies a saved theme name (no-op fallback to default).
func (m *Model) applyThemeByName(name string) {
	for i, p := range palettes {
		if p.name == name {
			m.applyTheme(i)
			return
		}
	}
	m.applyTheme(0)
}

// cycleTheme advances to the next palette, persists it, and returns its name.
func (m *Model) cycleTheme() string {
	next := (themeIndex + 1) % len(palettes)
	m.applyTheme(next)
	name := palettes[next].name
	_ = SaveTheme(name)
	return name
}
