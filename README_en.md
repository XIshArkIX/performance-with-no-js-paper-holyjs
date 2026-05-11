[English](./README_en.md) | [Русский](./README.md)

# Performance without JavaScript (HolyJS paper materials)

Research and demo assets for a talk on **web performance gains that do not depend on client-side JavaScript**: transport, TLS, HTTP features, server I/O, compression, and lightweight HTML choices. The narrative follows the same order as the repository folders below.

### `00-tcp-fast-open`

**TCP Fast Open (TFO)** — kernel and server configuration (including Nginx `fastopen=`), three-way handshake vs. TFO, and minimal pcap / screenshot examples. Sample C++ server and client code under `src/`.

### `01-tls-false-start`

**TLS False Start** (RFC 7918) — how the client can send application data before the full handshake finishes, browser defaults (e.g. Chrome, Firefox), interaction with TFO, and packet captures for standard vs. false-start flows.

### `02-tls-early-data`

**TLS 1.3 0-RTT / early data** — resumption and “early” application data, dual flows, server-only vs. full scenarios, and minimal TLS 1.3 early-data pcap material.

### `03-quic-0-rtt`

**QUIC and 0-RTT** — QUIC stack overview, 0-RTT vs. standard first flights, default enablement in browsers, and a small Go example under `src/`.

### `04-cipher-performance`

**Cryptographic cost of cipher suites** — microbenchmarks (e.g. ED25519 vs. RSA: keygen, sign, verify), spreadsheets and CSV summaries, and visuals for EC/RSA operations.

### `05-ocsp`

**OCSP and OCSP stapling** — certificate status checks without extra client round-trips to the CA when the server staples a fresh OCSP response; diagrams and example stapling traffic.

### `06-file-read`

**Serving static files efficiently** — blocking vs. non-blocking read paths, Nginx + `sendfile`, direct I/O, io_uring–style flow diagrams, and `strace` notes. C++ demos and a syscall tracer under `src/`.

### `07-compressing-base`

**Compression of responses** (gzip, Brotli, zstd) — dictionary / dynamic compression, examples tied to “compressing the base” payload size, and summary spreadsheets.

### `08-early-hints`

**HTTP 103 Early Hints** — sending preload hints (e.g. `Link: rel=preload`) before the final response, with header/HTML tag style examples and screenshots.

### `09-speculative-rules`

**Speculation Rules API** — declarative prefetch/prerender configuration from HTML, with example screenshots of rules in action.

### `10-service-worker`

**Service Worker** — timing/ordering relative to the rest of the pipeline (e.g. timestamp/diagram material); no heavy JS app—focus is on the lifecycle and when work runs.

### `11-different-media-sources`

**Image formats and `<picture>` / `srcset`** — AVIF, WebP, JPEG, etc. as ways to cut bytes without new JS, with before/after style screenshots per format.

### `12-clear-html-attributes`

**HTML weight from attributes** — reducing redundant `data-*` and similar markup on real-world-looking pages; screenshots comparing “only needed” vs. “cleared” DOM weight.

### `98-unattached-assets`

**Loose materials** — TLS 1.2/1.3 flow diagrams, minimal example pcaps, and other assets that support several chapters but are not tied to a single demo folder.

### `99-after-all`

**Lighthouse / tooling “after all optimizations”** — screenshots of scores or reports after applying the full stack of techniques (e.g. Chrome, Firefox context).

## `public/`

A **fixed-size static HTML** sample (e.g. 32 KiB) used for repeatable size/compression or transfer experiments without scripts or images in the page itself.

---

A slide deck in Russian, **«Нефронтендерские оптимизации»** (non-frontend / non-JS-centric optimizations), sits at the repo root and aligns with the same themes.
