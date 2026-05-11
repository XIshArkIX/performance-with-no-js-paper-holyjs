# Build the QUIC 0-RTT HTTP/3 client (requires Go toolchain).
BINARY := quic-0rtt-client

.PHONY: all build clean tidy

all: build

build:
	go build -trimpath -ldflags "-s -w" -o $(BINARY) .

tidy:
	go mod tidy

clean:
	rm -f $(BINARY)
