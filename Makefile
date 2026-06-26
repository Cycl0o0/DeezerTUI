BIN     := opendeezer
PKG     := ./cmd/opendeezer
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
LDFLAGS := -s -w -X main.version=$(VERSION)
DIST    := dist

.PHONY: build run test vet tidy clean cross

build:
	go build -ldflags "$(LDFLAGS)" -o $(BIN) $(PKG)

run: build
	./$(BIN)

test:
	go test -race ./...

vet:
	go vet ./...

tidy:
	go mod tidy

clean:
	rm -rf $(BIN) $(DIST)

# Cross-compile the cgo-free targets (macOS + Windows). Linux needs cgo+ALSA,
# so it's built natively in CI (.github/workflows/release.yml).
cross:
	@mkdir -p $(DIST)
	CGO_ENABLED=0 GOOS=darwin  GOARCH=arm64 go build -ldflags "$(LDFLAGS)" -o $(DIST)/$(BIN)-darwin-arm64  $(PKG)
	CGO_ENABLED=0 GOOS=darwin  GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o $(DIST)/$(BIN)-darwin-amd64  $(PKG)
	CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -ldflags "$(LDFLAGS)" -o $(DIST)/$(BIN)-windows-amd64.exe $(PKG)
	@echo "built: $(DIST)/"
