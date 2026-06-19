# Compression and decompression benchmarks

Benchmarks **gzip**, **brotli**, **zstd**, **DCB** (dictionary Brotli), and **DCZ** (dictionary zstd) on `public/index.html` using [hyperfine](https://github.com/sharkdp/hyperfine) parameter scans.

## Prerequisites

**macOS (Homebrew)**

```bash
brew install hyperfine brotli zstd node
```

**Ubuntu / Debian**

```bash
sudo apt update
sudo apt install hyperfine brotli zstd nodejs
```

**Arch Linux**

```bash
sudo pacman -S hyperfine brotli zstd nodejs
```

`gzip` and `awk` are required by the benchmark script and are included in a default install on all three platforms.

## Run

From the repository root:

```bash
./demos/07-compressing-base/src/compress-benchmark.sh
```

Results are written to `demos/07-compressing-base/assets/compression-stats.csv`.

### Decompression

```bash
./demos/07-compressing-base/src/decompress-benchmark.sh
```

Results are written to `demos/07-compressing-base/assets/decompression-stats.csv`.

The decompression benchmark pre-compresses artifacts at each level, then measures decode time. Size columns (`input_bytes`, `compressed_bytes`, `compression_ratio`, `savings_percent`) describe the compressed payload being decoded and match the compression benchmark schema.

## Quick run (fewer hyperfine iterations)

```bash
HYPERFINE_WARMUP=1 HYPERFINE_MIN_RUNS=5 \
  ./demos/07-compressing-base/src/compress-benchmark.sh
```

```bash
HYPERFINE_WARMUP=1 HYPERFINE_MIN_RUNS=5 \
  ./demos/07-compressing-base/src/decompress-benchmark.sh
```

## View results

```bash
column -s, -t demos/07-compressing-base/assets/compression-stats.csv
column -s, -t demos/07-compressing-base/assets/decompression-stats.csv
```
