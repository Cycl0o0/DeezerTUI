package deezer

import (
	"bytes"
	"testing"
)

// Known key vector for track 3135556 (from DiizerU deezer_decrypt_selftest).
func TestBlowfishKeyVector(t *testing.T) {
	want := []byte{108, 108, 102, 107, 57, 102, 44, 55, 101, 37, 117, 96, 60, 100, 52, 57}
	got := BlowfishKey("3135556")
	if !bytes.Equal(got, want) {
		t.Fatalf("key mismatch:\n got=%v\nwant=%v", got, want)
	}
}

// Chunks 1 and 2 (index%3 != 0) pass through; chunk 0 is transformed.
func TestStripePassthrough(t *testing.T) {
	data := make([]byte, chunkSize*3)
	for i := range data {
		data[i] = byte(i % 251)
	}
	out, err := DecryptTrack("3135556", data)
	if err != nil {
		t.Fatal(err)
	}
	if len(out) != len(data) {
		t.Fatalf("length changed: %d -> %d", len(data), len(out))
	}
	if !bytes.Equal(out[chunkSize:], data[chunkSize:]) {
		t.Error("chunks 1,2 should be unchanged")
	}
	if bytes.Equal(out[:chunkSize], data[:chunkSize]) {
		t.Error("chunk 0 should be transformed")
	}
}

// A trailing partial chunk stays plaintext and isn't dropped.
func TestStripeTrailingPartial(t *testing.T) {
	data := make([]byte, chunkSize+100)
	for i := range data {
		data[i] = byte(i % 251)
	}
	out, err := DecryptTrack("3135556", data)
	if err != nil {
		t.Fatal(err)
	}
	if len(out) != len(data) {
		t.Fatalf("length changed: %d -> %d", len(data), len(out))
	}
	if !bytes.Equal(out[chunkSize:], data[chunkSize:]) {
		t.Error("trailing partial chunk should be plaintext")
	}
}
