#!/bin/bash -eu
# Compile OpenDeezer's native Go fuzzers (testing.F) into libFuzzer targets.
# Invoked by ClusterFuzzLite and OSS-Fuzz inside the base-builder-go image.
cd "$SRC/opendeezer"

MOD=github.com/Cycl0o0/OpenDeezer

# compile_native_go_fuzzer rewrites each testing.F harness to use go-118-fuzz-
# build's shim, so that package must resolve in the module. Add it here (the
# build container is ephemeral, so this doesn't touch the committed go.mod).
# NB: do NOT `go mod tidy` after — tidy prunes this dep (nothing in the committed
# tree imports it; the import is injected by compile_native_go_fuzzer at build).
go get github.com/AdamKorcz/go-118-fuzz-build/testing

# --- pure-Go, security-critical custom code: the BF_CBC_STRIPE decryptor -------
compile_native_go_fuzzer "$MOD/internal/deezer" FuzzDecryptTrack   fuzz_decrypt_track
compile_native_go_fuzzer "$MOD/internal/deezer" FuzzStripeChunking fuzz_stripe_chunking

# --- FLAC decode of untrusted media bytes (cgo audio pkg; ALSA installed) ------
# Best-effort: if the cgo audio package can't link in the fuzzing image, keep the
# pure-Go targets above rather than failing the whole build.
compile_native_go_fuzzer "$MOD/internal/audio" FuzzFLACDecode fuzz_flac_decode || \
  echo "warning: FuzzFLACDecode (cgo) failed to compile in this image; skipping it"
