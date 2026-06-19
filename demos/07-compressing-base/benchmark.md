# Compression benchmark

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

## Quick run (fewer hyperfine iterations)

```bash
HYPERFINE_WARMUP=1 HYPERFINE_MIN_RUNS=5 \
  ./demos/07-compressing-base/src/compress-benchmark.sh
```

## View results

```bash
column -s, -t demos/07-compressing-base/assets/compression-stats.csv
```
