package ui

import (
	"image"
	"image/color"
	"strings"
	"testing"
)

func TestRenderCoverDimensions(t *testing.T) {
	img := image.NewRGBA(image.Rect(0, 0, 16, 16))
	for y := 0; y < 16; y++ {
		for x := 0; x < 16; x++ {
			img.Set(x, y, color.RGBA{uint8(x * 16), uint8(y * 16), 128, 255})
		}
	}
	const cols, rows = 8, 4
	out := renderCover(img, cols, rows)
	if got := strings.Count(out, "\n") + 1; got != rows {
		t.Fatalf("rows: got %d want %d", got, rows)
	}
	if strings.Count(out, "▀") != cols*rows {
		t.Errorf("expected %d half-block cells", cols*rows)
	}
}
