package audio

import (
	"math"
	"testing"
)

func TestDBToFactor(t *testing.T) {
	cases := []struct {
		db   float64
		want float64
	}{
		{0, 1},         // unknown / no change
		{-6.0206, 0.5}, // −6 dB ≈ half amplitude
		{-20, 0.1},     // −20 dB = 0.1
		{6, 1},         // positive gain clamped to 1 (attenuate-only)
	}
	for _, c := range cases {
		got := dbToFactor(c.db)
		if math.Abs(got-c.want) > 1e-3 {
			t.Errorf("dbToFactor(%v) = %v, want ~%v", c.db, got, c.want)
		}
		if got < 0 || got > 1 {
			t.Errorf("dbToFactor(%v) = %v out of [0,1]", c.db, got)
		}
	}
}
