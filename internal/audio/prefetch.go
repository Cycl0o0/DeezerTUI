package audio

import (
	"io"
	"sync"
)

// prefetchReader decouples a slow producer (network → decrypt → MP3 decode)
// from the audio-output pull. A goroutine reads ahead from src into a bounded
// queue of blocks; Read drains that queue. A transient network stall drains the
// cushion instead of immediately starving the audio device (the skip bug the
// C++ client fought on weak Wi-Fi).
type prefetchReader struct {
	blocks chan []byte
	rem    []byte // partially-consumed front block

	mu     sync.Mutex
	err    error
	closed bool
	done   chan struct{}
}

const (
	prefetchBlock   = 16 * 1024
	prefetchDepth   = 256 // ~4 MB of decoded PCM ≈ 24 s cushion @176400 B/s
)

func newPrefetchReader(src io.Reader) *prefetchReader {
	p := &prefetchReader{
		blocks: make(chan []byte, prefetchDepth),
		done:   make(chan struct{}),
	}
	go p.fill(src)
	return p
}

func (p *prefetchReader) fill(src io.Reader) {
	defer close(p.blocks)
	for {
		buf := make([]byte, prefetchBlock)
		n, err := src.Read(buf)
		if n > 0 {
			select {
			case p.blocks <- buf[:n]:
			case <-p.done:
				return
			}
		}
		if err != nil {
			p.mu.Lock()
			if err != io.EOF {
				p.err = err
			}
			p.mu.Unlock()
			return
		}
	}
}

func (p *prefetchReader) Read(out []byte) (int, error) {
	if len(p.rem) == 0 {
		b, ok := <-p.blocks
		if !ok {
			p.mu.Lock()
			err := p.err
			p.mu.Unlock()
			if err != nil {
				return 0, err
			}
			return 0, io.EOF
		}
		p.rem = b
	}
	n := copy(out, p.rem)
	p.rem = p.rem[n:]
	return n, nil
}

// Close stops the fill goroutine.
func (p *prefetchReader) Close() {
	p.mu.Lock()
	defer p.mu.Unlock()
	if !p.closed {
		p.closed = true
		close(p.done)
	}
}
