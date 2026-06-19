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

`gzip` and `awk` are required by the bash benchmark scripts and are included in a default install on all three platforms.

**Windows (Scoop)**

```powershell
scoop install hyperfine brotli zstd nodejs gzip
```

**Windows (winget)**

```powershell
winget install sharkdp.hyperfine
winget install Meta.Zstandard
winget install OpenJS.NodeJS.LTS
```

Install `brotli` and `gzip` separately (for example via [Scoop](https://scoop.sh) or [Git for Windows](https://git-scm.com/download/win), which adds `gzip` under `Git\usr\bin`).

## Run

From the repository root.

**macOS / Linux**

```bash
./demos/07-compressing-base/src/compress-benchmark.sh
```

**Windows (PowerShell)**

Run from the repository root in PowerShell 5.1 or later. If script execution is blocked, run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once.

```powershell
.\demos\07-compressing-base\src\compress-benchmark.ps1
```

Results are written to `demos/07-compressing-base/assets/compression-stats.csv`.

### Decompression

**macOS / Linux**

```bash
./demos/07-compressing-base/src/decompress-benchmark.sh
```

**Windows (PowerShell)**

```powershell
.\demos\07-compressing-base\src\decompress-benchmark.ps1
```

Results are written to `demos/07-compressing-base/assets/decompression-stats.csv`.

The decompression benchmark pre-compresses artifacts at each level, then measures decode time. Size columns (`input_bytes`, `compressed_bytes`, `compression_ratio`, `savings_percent`) describe the compressed payload being decoded and match the compression benchmark schema.

## Quick run (fewer hyperfine iterations)

**macOS / Linux**

```bash
HYPERFINE_WARMUP=1 HYPERFINE_MIN_RUNS=5 \
  ./demos/07-compressing-base/src/compress-benchmark.sh
```

```bash
HYPERFINE_WARMUP=1 HYPERFINE_MIN_RUNS=5 \
  ./demos/07-compressing-base/src/decompress-benchmark.sh
```

**Windows (PowerShell)**

```powershell
$env:HYPERFINE_WARMUP = 1
$env:HYPERFINE_MIN_RUNS = 5
.\demos\07-compressing-base\src\compress-benchmark.ps1
```

```powershell
$env:HYPERFINE_WARMUP = 1
$env:HYPERFINE_MIN_RUNS = 5
.\demos\07-compressing-base\src\decompress-benchmark.ps1
```

## View results

**macOS / Linux**

```bash
column -s, -t demos/07-compressing-base/assets/compression-stats.csv
column -s, -t demos/07-compressing-base/assets/decompression-stats.csv
```

**Windows (PowerShell)**

```powershell
Import-Csv demos/07-compressing-base/assets/compression-stats.csv | Format-Table -AutoSize
Import-Csv demos/07-compressing-base/assets/decompression-stats.csv | Format-Table -AutoSize
```

The benchmark scripts also print a formatted table when they finish.

## Machines

| OS | Specs |
| --- | --- |
| MacOS | Macbook M3 Pro 18GB |
| Windows | i7 13700KF @ 5.5GHz @ P-cores / DDR4 @ 4000MHz @ Single-rank @ 14/15/15/35 @ CR: 1T / MSI M480 2TB @ PHISON E18 |
| Linux | i7-9750H @ 4.5GHz turbo / DDR4 @ 2667MHz @ Dual-rank @ 19/19/19/43 / WDC PC SN520 512GB NVMe + Kingston SA400S3 1TB @ Dell G3 3590 |
