// Package deezer ports DiizerU core/deezer_client.cpp: ARL login, gw-light +
// public REST browse, and track -> CDN-url resolution. The ARL never leaves
// the machine beyond the requests it makes to Deezer.
package deezer

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	gwURL    = "https://www.deezer.com/ajax/gw-light.php"
	mediaURL = "https://media.deezer.com/v1/get_url"
	restURL  = "https://api.deezer.com"

	userAgent = "Mozilla/5.0 DeezerTUI/0.1"
)

// Client holds an authenticated Deezer session.
type Client struct {
	arl          string
	apiToken     string
	licenseToken string
	sid          string
	userID       string
	http         *http.Client
}

// New builds a client for the given ARL (not yet logged in).
func New(arl string) *Client {
	return &Client{
		arl: strings.TrimSpace(arl),
		http: &http.Client{
			Timeout: 30 * time.Second,
			// Don't auto-send cookies; we set the Cookie header ourselves.
			CheckRedirect: func(*http.Request, []*http.Request) error { return nil },
		},
	}
}

// LoggedIn reports whether Login succeeded.
func (c *Client) LoggedIn() bool { return c.apiToken != "" }

// UserID returns the numeric Deezer user id (after Login).
func (c *Client) UserID() string { return c.userID }

func (c *Client) cookie() string {
	ck := "arl=" + c.arl
	if c.sid != "" {
		ck += "; sid=" + c.sid
	}
	return ck
}

// Login authenticates and fetches api_token + license_token + sid + user id.
func (c *Client) Login() error {
	u := gwURL + "?method=deezer.getUserData&input=3&api_version=1.0&api_token="
	req, err := http.NewRequest(http.MethodPost, u, strings.NewReader("{}"))
	if err != nil {
		return err
	}
	req.Header.Set("Cookie", "arl="+c.arl)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", userAgent)

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	// Pull sid from Set-Cookie.
	for _, ck := range resp.Cookies() {
		if strings.EqualFold(ck.Name, "sid") {
			c.sid = ck.Value
		}
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	var parsed struct {
		Results struct {
			CheckForm string `json:"checkForm"`
			User      struct {
				UserID  json.Number `json:"USER_ID"`
				Options struct {
					LicenseToken string `json:"license_token"`
				} `json:"OPTIONS"`
			} `json:"USER"`
		} `json:"results"`
	}
	if err := json.Unmarshal(body, &parsed); err != nil {
		return fmt.Errorf("parse getUserData: %w", err)
	}
	c.apiToken = parsed.Results.CheckForm
	c.userID = parsed.Results.User.UserID.String()
	c.licenseToken = parsed.Results.User.Options.LicenseToken
	if c.apiToken == "" || c.userID == "" || c.userID == "0" {
		return fmt.Errorf("login failed: invalid or expired ARL")
	}
	return nil
}

// gwRaw performs one gw-light call and returns the raw response body.
func (c *Client) gwRaw(method, jsonBody string) ([]byte, error) {
	if c.apiToken == "" {
		return nil, fmt.Errorf("not logged in")
	}
	u := gwURL + "?method=" + method + "&input=3&api_version=1.0&api_token=" + url.QueryEscape(c.apiToken)
	req, err := http.NewRequest(http.MethodPost, u, strings.NewReader(jsonBody))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Cookie", c.cookie())
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", userAgent)
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}

// gwError extracts a gw error message from the response envelope. gw returns
// "error":{} / "error":[] when OK, and a populated object/array otherwise
// (e.g. {"VALID_TOKEN_REQUIRED":"..."}).
func gwError(body []byte) string {
	var env struct {
		Error json.RawMessage `json:"error"`
	}
	if json.Unmarshal(body, &env) != nil {
		return ""
	}
	s := strings.TrimSpace(string(env.Error))
	if s == "" || s == "[]" || s == "{}" || s == "null" {
		return ""
	}
	return s
}

// gw calls a gw method, transparently re-logging in once if the API token has
// expired (Deezer rotates it), and returns an error on a non-empty envelope.
func (c *Client) gw(method, jsonBody string) ([]byte, error) {
	body, err := c.gwRaw(method, jsonBody)
	if err != nil {
		return nil, err
	}
	gwErr := gwError(body)
	if gwErr != "" && strings.Contains(gwErr, "TOKEN") {
		// Stale token: re-login once and retry.
		if err := c.Login(); err != nil {
			return nil, fmt.Errorf("re-login: %w", err)
		}
		body, err = c.gwRaw(method, jsonBody)
		if err != nil {
			return nil, err
		}
		gwErr = gwError(body)
	}
	if gwErr != "" {
		return nil, fmt.Errorf("deezer gw %s: %s", method, gwErr)
	}
	return body, nil
}

// restGet calls the public REST API (no auth needed).
func (c *Client) restGet(path string) ([]byte, error) {
	req, err := http.NewRequest(http.MethodGet, restURL+path, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	return io.ReadAll(resp.Body)
}

// gwCover builds a 250x250 cover URL from an md5 image hash.
func gwCover(md5 string) string {
	if md5 == "" {
		return ""
	}
	return "https://e-cdns-images.dzcdn.net/images/cover/" + md5 + "/250x250-000000-80-0-0.jpg"
}

// ---- REST DTOs ----

type restArtist struct {
	ID   json.Number `json:"id"`
	Name string      `json:"name"`
}
type restTrackDTO struct {
	ID       json.Number `json:"id"`
	Title    string      `json:"title"`
	Duration json.Number `json:"duration"`
	Artist   restArtist  `json:"artist"`
	Album    struct {
		Title       string `json:"title"`
		CoverMedium string `json:"cover_medium"`
	} `json:"album"`
}

func (r restTrackDTO) toTrack() Track {
	durSec, _ := r.Duration.Int64()
	return Track{
		ID:         r.ID.String(),
		Name:       r.Title,
		DurationMS: durSec * 1000,
		Artists:    []Artist{{ID: r.Artist.ID.String(), Name: r.Artist.Name}},
		AlbumName:  r.Album.Title,
		ArtworkURL: r.Album.CoverMedium,
	}
}

// ---- gw DTOs (mixed string/number ids; ALL-CAPS keys) ----

type gwTrackDTO struct {
	SngID      json.Number `json:"SNG_ID"`
	SngTitle   string      `json:"SNG_TITLE"`
	Duration   json.Number `json:"DURATION"`
	ArtID      json.Number `json:"ART_ID"`
	ArtName    string      `json:"ART_NAME"`
	AlbTitle   string      `json:"ALB_TITLE"`
	AlbPicture string      `json:"ALB_PICTURE"`
}

func (g gwTrackDTO) toTrack() Track {
	durSec, _ := g.Duration.Int64()
	return Track{
		ID:         g.SngID.String(),
		Name:       g.SngTitle,
		DurationMS: durSec * 1000,
		Artists:    []Artist{{ID: g.ArtID.String(), Name: g.ArtName}},
		AlbumName:  g.AlbTitle,
		ArtworkURL: gwCover(g.AlbPicture),
	}
}

// Search queries tracks, albums and playlists.
func (c *Client) Search(query string) (*SearchResults, error) {
	enc := url.QueryEscape(query)
	sr := &SearchResults{}

	if b, err := c.restGet("/search?q=" + enc + "&limit=40"); err == nil {
		var r struct {
			Data []restTrackDTO `json:"data"`
		}
		if json.Unmarshal(b, &r) == nil {
			for _, t := range r.Data {
				sr.Tracks = append(sr.Tracks, t.toTrack())
			}
		}
	}
	if b, err := c.restGet("/search/album?q=" + enc + "&limit=20"); err == nil {
		var r struct {
			Data []struct {
				ID          json.Number `json:"id"`
				Title       string      `json:"title"`
				Artist      restArtist  `json:"artist"`
				CoverMedium string      `json:"cover_medium"`
			} `json:"data"`
		}
		if json.Unmarshal(b, &r) == nil {
			for _, a := range r.Data {
				sr.Albums = append(sr.Albums, Album{
					ID:         a.ID.String(),
					Name:       a.Title,
					Artists:    []Artist{{ID: a.Artist.ID.String(), Name: a.Artist.Name}},
					ArtworkURL: a.CoverMedium,
				})
			}
		}
	}
	if b, err := c.restGet("/search/playlist?q=" + enc + "&limit=20"); err == nil {
		var r struct {
			Data []struct {
				ID            json.Number `json:"id"`
				Title         string      `json:"title"`
				User          struct{ Name string } `json:"user"`
				NbTracks      int         `json:"nb_tracks"`
				PictureMedium string      `json:"picture_medium"`
			} `json:"data"`
		}
		if json.Unmarshal(b, &r) == nil {
			for _, p := range r.Data {
				sr.Playlists = append(sr.Playlists, Playlist{
					ID:         p.ID.String(),
					Name:       p.Title,
					Owner:      p.User.Name,
					TrackCount: p.NbTracks,
					ArtworkURL: p.PictureMedium,
				})
			}
		}
	}
	return sr, nil
}

// AlbumTracks lists an album's tracks via the public REST API.
func (c *Client) AlbumTracks(id string) ([]Track, error) {
	b, err := c.restGet("/album/" + id + "/tracks?limit=100")
	if err != nil {
		return nil, err
	}
	var r struct {
		Data []restTrackDTO `json:"data"`
	}
	if err := json.Unmarshal(b, &r); err != nil {
		return nil, err
	}
	out := make([]Track, 0, len(r.Data))
	for _, t := range r.Data {
		out = append(out, t.toTrack())
	}
	return out, nil
}

// pageSize is the per-request page for paginated gw lists.
const pageSize = 200

// maxTracks caps a paginated fetch so a huge library can't run away.
const maxTracks = 5000

// gwTrackPage fetches one page of gw tracks for a method whose body is
// "<extra>,\"nb\":<n>,\"start\":<s>".
func (c *Client) gwTrackPage(method, extra string, start, nb int) ([]Track, error) {
	body := fmt.Sprintf(`{%s,"nb":%d,"start":%d}`, extra, nb, start)
	b, err := c.gw(method, body)
	if err != nil {
		return nil, err
	}
	var r struct {
		Results struct {
			Data []gwTrackDTO `json:"data"`
		} `json:"results"`
	}
	if err := json.Unmarshal(b, &r); err != nil {
		return nil, err
	}
	out := make([]Track, 0, len(r.Results.Data))
	for _, t := range r.Results.Data {
		out = append(out, t.toTrack())
	}
	return out, nil
}

// gwTrackAll pages through a gw track list until it's exhausted.
func (c *Client) gwTrackAll(method, extra string) ([]Track, error) {
	var all []Track
	for start := 0; start < maxTracks; start += pageSize {
		page, err := c.gwTrackPage(method, extra, start, pageSize)
		if err != nil {
			if len(all) > 0 {
				return all, nil // keep what we have on a mid-fetch error
			}
			return nil, err
		}
		all = append(all, page...)
		if len(page) < pageSize {
			break
		}
	}
	return all, nil
}

// PlaylistTracks lists a playlist's tracks (gw, works for private playlists).
func (c *Client) PlaylistTracks(id string) ([]Track, error) {
	return c.gwTrackAll("playlist.getSongs", fmt.Sprintf(`"playlist_id":"%s"`, id))
}

// Favorites lists the user's liked songs (gw).
func (c *Client) Favorites() ([]Track, error) {
	return c.gwTrackAll("favorite_song.getList", fmt.Sprintf(`"user_id":"%s"`, c.userID))
}

// Playlists lists the user's own playlists (gw pageProfile).
func (c *Client) Playlists() ([]Playlist, error) {
	body := fmt.Sprintf(`{"user_id":"%s","tab":"playlists","nb":100}`, c.userID)
	b, err := c.gw("deezer.pageProfile", body)
	if err != nil {
		return nil, err
	}
	var r struct {
		Results struct {
			Tab struct {
				Playlists struct {
					Data []struct {
						PlaylistID      json.Number `json:"PLAYLIST_ID"`
						Title           string      `json:"TITLE"`
						NbSong          json.Number `json:"NB_SONG"`
						PlaylistPicture string      `json:"PLAYLIST_PICTURE"`
					} `json:"data"`
				} `json:"playlists"`
			} `json:"TAB"`
		} `json:"results"`
	}
	if err := json.Unmarshal(b, &r); err != nil {
		return nil, err
	}
	var out []Playlist
	for _, p := range r.Results.Tab.Playlists.Data {
		n, _ := p.NbSong.Int64()
		out = append(out, Playlist{
			ID:         p.PlaylistID.String(),
			Name:       p.Title,
			TrackCount: int(n),
			ArtworkURL: gwCover(p.PlaylistPicture),
		})
	}
	return out, nil
}

// trackToken fetches the per-track token needed for media URL resolution.
func (c *Client) trackToken(trackID string) (string, error) {
	b, err := c.gw("song.getData", fmt.Sprintf(`{"sng_id":"%s"}`, trackID))
	if err != nil {
		return "", err
	}
	var r struct {
		Results struct {
			TrackToken string `json:"TRACK_TOKEN"`
		} `json:"results"`
	}
	if err := json.Unmarshal(b, &r); err != nil {
		return "", err
	}
	return r.Results.TrackToken, nil
}

// StreamPlan is the resolved CDN URL + track id for decryption.
type StreamPlan struct {
	CDNURL  string
	TrackID string
	Format  string
}

// resolveMediaURL turns a track token into an encrypted CDN URL.
func (c *Client) resolveMediaURL(trackToken string) (urlStr, format string, err error) {
	if c.licenseToken == "" || trackToken == "" {
		return "", "", fmt.Errorf("missing license or track token")
	}
	body := fmt.Sprintf(`{"license_token":"%s","media":[{"type":"FULL","formats":[`+
		`{"cipher":"BF_CBC_STRIPE","format":"MP3_128"},`+
		`{"cipher":"BF_CBC_STRIPE","format":"MP3_320"}]}],`+
		`"track_tokens":["%s"]}`, c.licenseToken, trackToken)

	req, err := http.NewRequest(http.MethodPost, mediaURL, bytes.NewReader([]byte(body)))
	if err != nil {
		return "", "", err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", userAgent)
	resp, err := c.http.Do(req)
	if err != nil {
		return "", "", err
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", "", err
	}
	var r struct {
		Data []struct {
			Media []struct {
				Format  string `json:"format"`
				Sources []struct {
					URL string `json:"url"`
				} `json:"sources"`
			} `json:"media"`
		} `json:"data"`
	}
	if err := json.Unmarshal(b, &r); err != nil {
		return "", "", err
	}
	if len(r.Data) == 0 || len(r.Data[0].Media) == 0 || len(r.Data[0].Media[0].Sources) == 0 {
		return "", "", fmt.Errorf("no media source (track unavailable for this account)")
	}
	m := r.Data[0].Media[0]
	return m.Sources[0].URL, m.Format, nil
}

// PrepareStream resolves a track id to a playable encrypted CDN URL.
func (c *Client) PrepareStream(trackID string) (*StreamPlan, error) {
	if !c.LoggedIn() {
		return nil, fmt.Errorf("not logged in")
	}
	tok, err := c.trackToken(trackID)
	if err != nil {
		return nil, err
	}
	u, format, err := c.resolveMediaURL(tok)
	if err != nil {
		return nil, err
	}
	return &StreamPlan{CDNURL: u, TrackID: trackID, Format: format}, nil
}

// TrackIDOf extracts a numeric id from "deezer:track:123", a URL, or "123".
func TrackIDOf(uri string) string {
	if i := strings.LastIndexAny(uri, ":/"); i >= 0 {
		uri = uri[i+1:]
	}
	var sb strings.Builder
	for _, r := range uri {
		if r >= '0' && r <= '9' {
			sb.WriteRune(r)
		}
	}
	return sb.String()
}
