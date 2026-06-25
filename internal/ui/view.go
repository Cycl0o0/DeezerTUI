package ui

import (
	"fmt"
	"strings"

	"github.com/cyclolysis/deezertui/internal/audio"

	"github.com/charmbracelet/lipgloss"
)

var (
	accent    = lipgloss.NewStyle().Foreground(lipgloss.Color("213")).Bold(true)
	dim       = lipgloss.NewStyle().Foreground(lipgloss.Color("241"))
	barFill   = lipgloss.NewStyle().Foreground(lipgloss.Color("213"))
	barEmpty  = lipgloss.NewStyle().Foreground(lipgloss.Color("238"))
	footerBox = lipgloss.NewStyle().Border(lipgloss.NormalBorder(), true, false, false, false).
			BorderForeground(lipgloss.Color("238"))
	statusSty = lipgloss.NewStyle().Foreground(lipgloss.Color("220"))
)

// View renders the whole screen.
func (m *Model) View() string {
	if !m.ready {
		return "starting…"
	}
	var body string
	if m.screen == screenSearch {
		body = m.searchView()
	} else {
		body = m.list.View()
	}
	return body + "\n" + m.footer()
}

func (m *Model) searchView() string {
	lines := []string{
		accent.Render("Search Deezer"),
		"",
		m.search.View(),
		"",
		dim.Render("enter to search · esc to go back"),
	}
	// Pad to roughly fill the list area.
	for len(lines) < max(1, m.height-footerHeight) {
		lines = append(lines, "")
	}
	return strings.Join(lines, "\n")
}

func (m *Model) footer() string {
	st := m.player.State()
	var now string
	if m.qIndex >= 0 && m.qIndex < len(m.queue) && (m.playing || st == audio.Playing || st == audio.Paused) {
		t := m.queue[m.qIndex]
		icon := "▶"
		if st == audio.Paused {
			icon = "⏸"
		} else if st == audio.Loading {
			icon = "…"
		}
		now = fmt.Sprintf("%s %s %s",
			icon, accent.Render(t.Name), dim.Render("· "+t.ArtistLine()))
	} else if e := m.player.LastError(); e != "" {
		now = dim.Render("⏹ stopped — " + e)
	} else {
		now = dim.Render("⏹ nothing playing")
	}

	bar := m.progressBar()

	shuf := "off"
	if m.shuffle {
		shuf = "on"
	}
	help := dim.Render(fmt.Sprintf(
		"space pause · n/p next/prev · z shuffle:%s · r repeat:%s · +/- vol:%d%% · / search · s stop · q quit",
		shuf, m.repeat.String(), int(m.player.Volume()*100+0.5)))

	status := ""
	if m.status != "" {
		s := m.status
		if m.loading {
			s = m.spinner.View() + s
		}
		status = statusSty.Render(s)
	}

	content := now + "\n" + bar + "\n" + help
	if status != "" {
		content = status + "\n" + content
	}
	return footerBox.Width(max(10, m.width)).Render(content)
}

func (m *Model) progressBar() string {
	pos := m.player.PositionMS()
	dur := m.player.DurationMS()
	width := max(10, m.width-20)
	filled := 0
	if dur > 0 {
		filled = int(int64(width) * pos / dur)
		if filled > width {
			filled = width
		}
	}
	bar := barFill.Render(strings.Repeat("━", filled)) +
		barEmpty.Render(strings.Repeat("━", width-filled))
	return fmt.Sprintf("%s %s / %s", bar, fmtMS(pos), fmtMS(dur))
}

func fmtMS(ms int64) string {
	if ms < 0 {
		ms = 0
	}
	s := ms / 1000
	return fmt.Sprintf("%d:%02d", s/60, s%60)
}
