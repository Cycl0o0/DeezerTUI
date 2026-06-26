package deezer

import "strings"

// Artist is a track/album credit.
type Artist struct {
	ID   string
	Name string
}

// Track mirrors the C++ core::Track.
type Track struct {
	ID         string
	Name       string
	DurationMS int64
	Artists    []Artist
	AlbumName  string
	ArtworkURL string
}

// ArtistLine joins artist names: "Artist A, Artist B".
func (t Track) ArtistLine() string {
	names := make([]string, len(t.Artists))
	for i, a := range t.Artists {
		names[i] = a.Name
	}
	return strings.Join(names, ", ")
}

// Album is a search/browse result.
type Album struct {
	ID         string
	Name       string
	Artists    []Artist
	ArtworkURL string
}

// Playlist is a search/browse result.
type Playlist struct {
	ID         string
	Name       string
	Owner      string
	TrackCount int
	ArtworkURL string
}

// SearchResults groups the three searched entity kinds.
type SearchResults struct {
	Tracks    []Track
	Albums    []Album
	Playlists []Playlist
}

// FormatLabel turns a raw Deezer media format into a human label for the UI.
func FormatLabel(raw string) string {
	switch strings.ToUpper(raw) {
	case "":
		return ""
	case "FLAC":
		return "FLAC · lossless"
	case "MP3_320":
		return "MP3 · 320 kbps"
	case "MP3_256":
		return "MP3 · 256 kbps"
	case "MP3_128":
		return "MP3 · 128 kbps"
	case "MP3_64":
		return "MP3 · 64 kbps"
	default:
		return raw
	}
}
