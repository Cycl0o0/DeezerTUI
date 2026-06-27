package ui

import "github.com/Cycl0o0/OpenDeezer/internal/deezer"

// rowKind identifies what a list row represents.
type rowKind int

const (
	rowMenu rowKind = iota
	rowTrack
	rowPlaylist
	rowAlbum
	rowArtist
)

// menuAction is the action a rowMenu triggers.
type menuAction int

const (
	actLiked menuAction = iota
	actPlaylists
	actSearch
	actCharts
	actResume
)

// row is a single list entry. It implements bubbles/list.Item.
type row struct {
	kind     rowKind
	title    string
	desc     string
	action   menuAction        // for rowMenu
	track    deezer.Track      // for rowTrack
	playlist deezer.Playlist   // for rowPlaylist
	album    deezer.Album      // for rowAlbum
	artist   deezer.ArtistInfo // for rowArtist
}

func (r row) Title() string       { return r.title }
func (r row) Description() string { return r.desc }
func (r row) FilterValue() string { return r.title }

func trackRow(t deezer.Track) row {
	return row{kind: rowTrack, title: t.Name, desc: t.ArtistLine() + " · " + t.AlbumName, track: t}
}

func playlistRow(p deezer.Playlist) row {
	d := p.Owner
	if d == "" {
		d = "playlist"
	}
	return row{kind: rowPlaylist, title: p.Name, desc: d, playlist: p}
}

func albumRow(a deezer.Album) row {
	name := ""
	if len(a.Artists) > 0 {
		name = a.Artists[0].Name
	}
	return row{kind: rowAlbum, title: "💿 " + a.Name, desc: name, album: a}
}

func artistRow(a deezer.ArtistInfo) row {
	return row{kind: rowArtist, title: "♪ " + a.Name, desc: "artist", artist: a}
}
