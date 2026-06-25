package audio

import (
	"bytes"
	"io"
	"testing"

	"github.com/Cycl0o0/DeezerTUI/internal/deezer"
)

// oddReader hands out data in deliberately awkward, sub-block sizes to exercise
// the decryptReader's chunk-boundary handling.
type oddReader struct {
	data []byte
	pos  int
	step int
}

func (r *oddReader) Read(p []byte) (int, error) {
	if r.pos >= len(r.data) {
		return 0, io.EOF
	}
	n := r.step
	if n > len(p) {
		n = len(p)
	}
	if r.pos+n > len(r.data) {
		n = len(r.data) - r.pos
	}
	copy(p, r.data[r.pos:r.pos+n])
	r.pos += n
	return n, nil
}

// Streaming decrypt through decryptReader must equal a whole-buffer decrypt,
// regardless of read chunking across the 2048-byte stripe boundaries.
func TestDecryptReaderMatchesWhole(t *testing.T) {
	const id = "3135556"
	data := make([]byte, 2048*7+513) // several stripes + a partial tail
	for i := range data {
		data[i] = byte((i*7 + 3) % 251)
	}
	want, err := deezer.DecryptTrack(id, data)
	if err != nil {
		t.Fatal(err)
	}

	for _, step := range []int{1, 7, 100, 2048, 5000} {
		dr, err := newDecryptReader(&oddReader{data: data, step: step}, id)
		if err != nil {
			t.Fatal(err)
		}
		got, err := io.ReadAll(dr)
		if err != nil {
			t.Fatalf("step %d: %v", step, err)
		}
		if !bytes.Equal(got, want) {
			t.Errorf("step %d: streamed output != whole-buffer decrypt", step)
		}
	}
}
