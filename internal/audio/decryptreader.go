// Package audio streams a Deezer CDN track, BF_CBC_STRIPE-decrypts it on the
// fly, MP3-decodes it, and plays PCM. Ported from DiizerU audio/.
package audio

import (
	"io"

	"github.com/Cycl0o0/DeezerTUI/internal/deezer"
)

// decryptReader wraps an encrypted CDN body and yields decrypted MP3 bytes.
type decryptReader struct {
	src     io.Reader
	dec     *deezer.StripeDecryptor
	in      []byte // scratch for raw reads
	out     []byte // decrypted bytes not yet returned
	srcDone bool
}

func newDecryptReader(src io.Reader, trackID string) (*decryptReader, error) {
	d, err := deezer.NewStripeDecryptor(trackID)
	if err != nil {
		return nil, err
	}
	return &decryptReader{src: src, dec: d, in: make([]byte, 32*1024)}, nil
}

func (r *decryptReader) Read(p []byte) (int, error) {
	// Refill the decrypted buffer until we have something or the source ends.
	for len(r.out) == 0 && !r.srcDone {
		n, err := r.src.Read(r.in)
		if n > 0 {
			r.out = r.dec.Feed(r.in[:n], r.out)
		}
		if err == io.EOF {
			r.srcDone = true
			r.out = r.dec.Finish(r.out)
		} else if err != nil {
			return 0, err
		}
	}
	if len(r.out) == 0 {
		return 0, io.EOF
	}
	n := copy(p, r.out)
	r.out = r.out[n:]
	return n, nil
}
