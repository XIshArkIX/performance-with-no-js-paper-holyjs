// QUIC HTTP/3 client that performs a 1-RTT warm-up, then issues a 0-RTT GET
// using quic-go's http3.MethodGet0RTT (see https://quic-go.net/docs/http3/client/#using-0-rtt).
package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/quic-go/quic-go/http3"
)

const maxBodyPrint = 16 * 1024

func main() {
	if len(os.Args) != 2 {
		log.Fatalf("usage: %s <https-url>", os.Args[0])
	}
	raw := os.Args[1]
	u, err := url.Parse(raw)
	if err != nil {
		log.Fatalf("parse url: %v", err)
	}
	if u.Scheme != "https" {
		log.Fatalf("only https:// is supported (HTTP/3), got scheme %q", u.Scheme)
	}
	if u.Host == "" {
		log.Fatalf("url must include a host (e.g. https://example.com:443/path)")
	}
	if u.Path == "" {
		u.Path = "/"
	}
	target := u.String()

	tlsConfig := &tls.Config{
		ClientSessionCache: tls.NewLRUClientSessionCache(100),
	}
	if keyLogPath := os.Getenv("SSLKEYLOGFILE"); keyLogPath != "" {
		keyLog, err := os.OpenFile(keyLogPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			log.Fatalf("open SSLKEYLOGFILE %q: %v", keyLogPath, err)
		}
		defer func() { _ = keyLog.Close() }()
		tlsConfig.KeyLogWriter = keyLog
		fmt.Fprintf(os.Stderr, "SSLKEYLOGFILE: appending key material to %q for Wireshark TLS decryption\n", keyLogPath)
	}
	tr := &http3.Transport{
		TLSClientConfig: tlsConfig,
	}
	defer func() { _ = tr.Close() }()

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	client := &http.Client{
		Transport: tr,
		Timeout:   60 * time.Second,
		// Avoid redirect following so the same URL is used for session + 0-RTT.
		CheckRedirect: func(_ *http.Request, _ []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}

	// 1) Full handshake: cache TLS session for resumption.
	warm, err := http.NewRequestWithContext(ctx, http.MethodGet, target, nil)
	if err != nil {
		log.Fatalf("build warm-up request: %v", err)
	}
	wResp, err := client.Do(warm)
	if err != nil {
		log.Fatalf("warm-up request failed: %v", err)
	}
	_, _ = io.Copy(io.Discard, wResp.Body)
	_ = wResp.Body.Close()
	fmt.Fprintf(os.Stderr, "warm-up: %s (session cached for 0-RTT)\n", wResp.Status)

	// New QUIC connection will call DialEarly; with a ticket, early data is possible.
	tr.CloseIdleConnections()

	// 2) 0-RTT GET: must use http3.MethodGet0RTT and a ClientSessionCache (see quic-go docs).
	req0rtt, err := http.NewRequestWithContext(ctx, http3.MethodGet0RTT, target, nil)
	if err != nil {
		log.Fatalf("build 0-RTT request: %v", err)
	}
	resp, err := client.Do(req0rtt)
	if err != nil {
		log.Fatalf("0-RTT request failed: %v", err)
	}
	defer resp.Body.Close()

	chunk, err := io.ReadAll(io.LimitReader(resp.Body, maxBodyPrint+1))
	if err != nil {
		log.Fatalf("read body: %v", err)
	}
	fmt.Printf("0-RTT: %s\n", resp.Status)
	trim := chunk
	if len(chunk) > maxBodyPrint {
		trim = chunk[:maxBodyPrint]
	}
	os.Stdout.Write(trim)
	if len(chunk) > maxBodyPrint {
		fmt.Print("\n... (output truncated) ...\n")
	}
}
