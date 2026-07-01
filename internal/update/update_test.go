package update

import "testing"

func TestNewer(t *testing.T) {
	cases := []struct {
		a, b string
		want bool
	}{
		{"1.5.1", "1.5.0", true},
		{"1.5.0", "1.5.0", false},
		{"1.5.0", "1.5.1", false},
		{"2.0.0", "1.9.9", true},
		{"1.10.0", "1.9.0", true}, // numeric, not lexical
		{"1.5.1", "1.5.0", true},
		{"1.5.1-rc1", "1.5.0", true}, // pre-release suffix stripped
		{"v1.5.1", "v1.5.0", true},   // (parts strips no 'v'; caller trims — test the numeric path)
	}
	for _, c := range cases {
		if got := newer(c.a, c.b); got != c.want {
			t.Errorf("newer(%q,%q)=%v want %v", c.a, c.b, got, c.want)
		}
	}
}
