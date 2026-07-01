package audio

import (
	"math"
	"testing"
	"time"
)

// newBarePlayer builds a Player without an output device, for testing the pure
// logic (volume taper, sleep timer, fade-in) that doesn't need a real sink.
func newBarePlayer() *Player {
	p := &Player{stopMgr: make(chan struct{})}
	p.state.Store(int32(Stopped))
	p.gainFac.Store(math.Float64bits(1))
	p.sleepGain.Store(math.Float64bits(1))
	p.gapless.Store(true)
	p.setVolume(1.0)
	return p
}

func TestVolumeTaperIsPerceptual(t *testing.T) {
	// The taper must be monotonic, pinned at the endpoints, and below linear in
	// the middle (so mid-slider is quieter than half amplitude).
	if got := volumeTaper(0); got != 0 {
		t.Errorf("volumeTaper(0) = %v, want 0", got)
	}
	if got := volumeTaper(1); got != 1 {
		t.Errorf("volumeTaper(1) = %v, want 1", got)
	}
	if got := volumeTaper(0.5); got >= 0.5 {
		t.Errorf("volumeTaper(0.5) = %v, want < 0.5 (perceptual taper)", got)
	}
	prev := -1.0
	for v := 0.0; v <= 1.0; v += 0.05 {
		g := volumeTaper(v)
		if g < prev {
			t.Errorf("volumeTaper not monotonic at v=%v (%v < %v)", v, g, prev)
		}
		prev = g
	}
}

func TestSleepTimerDurationArmAndCancel(t *testing.T) {
	p := newBarePlayer()
	if p.SleepActive() {
		t.Fatal("new player should have no sleep timer armed")
	}
	p.SetSleepTimer(30*time.Minute, false)
	if !p.SleepActive() {
		t.Fatal("SetSleepTimer should arm the timer")
	}
	if p.SleepEndOfTrack() {
		t.Fatal("duration mode should not report end-of-track")
	}
	if rem := p.SleepRemainingMS(); rem <= 29*60*1000 || rem > 30*60*1000 {
		t.Errorf("SleepRemainingMS = %d, want ~30min", rem)
	}
	p.CancelSleepTimer()
	if p.SleepActive() {
		t.Fatal("CancelSleepTimer should disarm")
	}
	// Cancelling must restore full sleep gain so playback isn't left silenced.
	if sg := math.Float64frombits(p.sleepGain.Load()); sg != 1 {
		t.Errorf("sleepGain after cancel = %v, want 1", sg)
	}
}

func TestSleepTimerEndOfTrackMode(t *testing.T) {
	p := newBarePlayer()
	p.totalMS.Store(200000)
	p.played.Store(0)
	p.SetSleepTimer(0, true)
	if !p.SleepActive() || !p.SleepEndOfTrack() {
		t.Fatal("end-of-track timer should be armed in EOT mode")
	}
	// In EOT mode, remaining tracks the current track's remaining time.
	if rem := p.SleepRemainingMS(); rem <= 0 || rem > 200000 {
		t.Errorf("EOT SleepRemainingMS = %d, want ~track remaining", rem)
	}
}

func TestSetSleepTimerNonPositiveCancels(t *testing.T) {
	p := newBarePlayer()
	p.SetSleepTimer(10*time.Minute, false)
	p.SetSleepTimer(0, false) // non-positive duration, not EOT -> cancel
	if p.SleepActive() {
		t.Fatal("SetSleepTimer(0, false) should cancel")
	}
}

func TestApplyFadeInRampsUp(t *testing.T) {
	// A full-scale stereo buffer with a fresh fade (remaining == fadeInFrames)
	// should start at silence and reach unity by the end of the ramp.
	var frames int64 = fadeInFrames
	buf := make([]byte, int(frames)*frameBytes)
	for i := 0; i+1 < len(buf); i += 2 {
		// int16 max (0x7FFF) little-endian
		buf[i] = 0xFF
		buf[i+1] = 0x7F
	}
	remaining := applyFadeIn(buf, frames) // ramp exactly across the buffer
	if remaining != 0 {
		t.Errorf("remaining = %d, want 0 after ramping a full ramp-length buffer", remaining)
	}
	first := int16(uint16(buf[0]) | uint16(buf[1])<<8)
	last := int16(uint16(buf[len(buf)-2]) | uint16(buf[len(buf)-1])<<8)
	if first != 0 {
		t.Errorf("fade-in should start at silence, got first sample %d", first)
	}
	if last < 32000 {
		t.Errorf("fade-in should reach ~unity, got last sample %d", last)
	}
}
