// Package update checks GitHub for a newer OpenDeezer release. Clients call it
// on startup to show a non-intrusive "update available" prompt — it never
// downloads or installs anything itself.
package update

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// Repo is the GitHub owner/name that publishes releases.
const Repo = "Cycl0o0/OpenDeezer"

// Info is the result of a check.
type Info struct {
	Current   string `json:"current"`   // running version, e.g. "1.5.0"
	Latest    string `json:"latest"`    // latest release, e.g. "1.5.1"
	HasUpdate bool   `json:"hasUpdate"` // Latest is strictly newer than Current
	URL       string `json:"url"`       // release page to open
	Notes     string `json:"notes"`     // release notes (trimmed)
}

type ghRelease struct {
	TagName string `json:"tag_name"`
	HTMLURL string `json:"html_url"`
	Body    string `json:"body"`
	Draft   bool   `json:"draft"`
	Prerel  bool   `json:"prerelease"`
}

// Check asks GitHub for the latest (non-draft, non-prerelease) release and
// compares it to current. A network/parse failure returns HasUpdate=false with
// the error, so callers can silently ignore it.
func Check(current string) (Info, error) {
	info := Info{Current: strings.TrimPrefix(current, "v")}
	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()

	url := "https://api.github.com/repos/" + Repo + "/releases/latest"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return info, err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("User-Agent", "OpenDeezer-update-check")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return info, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return info, fmt.Errorf("update check: HTTP %d", resp.StatusCode)
	}
	var rel ghRelease
	if err := json.NewDecoder(resp.Body).Decode(&rel); err != nil {
		return info, err
	}
	if rel.Draft || rel.Prerel {
		return info, nil
	}

	info.Latest = strings.TrimPrefix(strings.TrimSpace(rel.TagName), "v")
	info.URL = rel.HTMLURL
	info.Notes = strings.TrimSpace(rel.Body)
	if len(info.Notes) > 2000 {
		info.Notes = info.Notes[:2000]
	}
	info.HasUpdate = newer(info.Latest, info.Current)
	return info, nil
}

// newer reports whether version a is strictly greater than b (dotted numeric,
// e.g. "1.5.1" > "1.5.0"). Non-numeric or missing parts compare as 0.
func newer(a, b string) bool {
	pa, pb := parts(a), parts(b)
	for i := 0; i < 3; i++ {
		if pa[i] != pb[i] {
			return pa[i] > pb[i]
		}
	}
	return false
}

func parts(v string) [3]int {
	var out [3]int
	// Drop any build/pre-release suffix (e.g. "1.5.1-rc1" -> "1.5.1").
	if i := strings.IndexAny(v, "-+ "); i >= 0 {
		v = v[:i]
	}
	for i, s := range strings.SplitN(v, ".", 3) {
		if i > 2 {
			break
		}
		n, _ := strconv.Atoi(strings.TrimSpace(s))
		out[i] = n
	}
	return out
}
