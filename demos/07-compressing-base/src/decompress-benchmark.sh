#!/usr/bin/env bash
set -euo pipefail

# Benchmark gzip, brotli, zstd, and dictionary-based brotli (DCB) / zstd (DCZ)
# decompression on pre-compressed public/index.html artifacts using hyperfine
# parameter scans. Writes a readable CSV with size ratios and timing stats.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

INPUT_FILE="${INPUT_FILE:-$REPO_ROOT/public/index.html}"
OUTPUT_CSV="${OUTPUT_CSV:-$DEMO_DIR/assets/decompression-stats.csv}"
DICT_DIR="${DICT_DIR:-$DEMO_DIR/dictionaries}"
TRAIN_FILES="${TRAIN_FILES:-$REPO_ROOT/public/index-v2.html}"
DICT_MAX_BYTES="${DICT_MAX_BYTES:-32768}"
ZSTD_TRAIN_BLOCK_BYTES="${ZSTD_TRAIN_BLOCK_BYTES:-4096}"

GZIP_LEVEL_MIN="${GZIP_LEVEL_MIN:-1}"
GZIP_LEVEL_MAX="${GZIP_LEVEL_MAX:-9}"
BROTLI_LEVEL_MIN="${BROTLI_LEVEL_MIN:-1}"
BROTLI_LEVEL_MAX="${BROTLI_LEVEL_MAX:-11}"
ZSTD_LEVEL_MIN="${ZSTD_LEVEL_MIN:-1}"
ZSTD_LEVEL_MAX="${ZSTD_LEVEL_MAX:-19}"

HYPERFINE_WARMUP="${HYPERFINE_WARMUP:-3}"
HYPERFINE_MIN_RUNS="${HYPERFINE_MIN_RUNS:-10}"

DCB_DICT="$DICT_DIR/dcb.dict"
DCZ_DICT="$DICT_DIR/dcz.dict"

command -v hyperfine >/dev/null || { echo "hyperfine not found"; exit 1; }
command -v gzip >/dev/null || { echo "gzip not found"; exit 1; }
command -v brotli >/dev/null || { echo "brotli not found"; exit 1; }
command -v zstd >/dev/null || { echo "zstd not found"; exit 1; }
command -v node >/dev/null || { echo "node not found"; exit 1; }
command -v awk >/dev/null || { echo "awk not found"; exit 1; }

PREPARE_DCB_SCRIPT="$SCRIPT_DIR/prepare-dcb-dict.js"

[[ -f "$INPUT_FILE" ]] || { echo "Input file not found: $INPUT_FILE"; exit 1; }

read -r -a TRAIN_FILE_LIST <<< "$(printf '%s\n' $TRAIN_FILES | tr ',' ' ')"
for train_file in "${TRAIN_FILE_LIST[@]}"; do
  [[ -f "$train_file" ]] || { echo "Training file not found: $train_file"; exit 1; }
done

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

INPUT_BYTES="$(wc -c < "$INPUT_FILE" | tr -d ' ')"
INPUT_BASENAME="$(basename "$INPUT_FILE")"

echo "Input:  $INPUT_FILE ($INPUT_BYTES bytes)"
echo "Train:  ${TRAIN_FILE_LIST[*]}"
echo "Output: $OUTPUT_CSV"
echo

prepare_dcz() {
  mkdir -p "$DICT_DIR"

  local -a train_args=()
  for train_file in "${TRAIN_FILE_LIST[@]}"; do
    train_args+=("$train_file")
  done

  echo "Preparing DCZ dictionary -> $DCZ_DICT"
  zstd --train \
    --maxdict="$DICT_MAX_BYTES" \
    -B"$ZSTD_TRAIN_BLOCK_BYTES" \
    -o "$DCZ_DICT" \
    "${train_args[@]}"
  echo "  DCZ dictionary size: $(wc -c < "$DCZ_DICT" | tr -d ' ') bytes"
  echo
}

prepare_dcb() {
  [[ -f "$PREPARE_DCB_SCRIPT" ]] || {
    echo "Missing Node prepare script: $PREPARE_DCB_SCRIPT"
    exit 1
  }

  echo "Preparing DCB dictionary -> $DCB_DICT"
  echo "  Using Node zlib API (training-file template, zstd-dict reuse fallback)"

  DCZ_DICT="$DCZ_DICT" node "$PREPARE_DCB_SCRIPT" \
    "$DCB_DICT" \
    "$DICT_MAX_BYTES" \
    "$INPUT_FILE" \
    "${TRAIN_FILE_LIST[@]}"

  echo "  DCB dictionary size: $(wc -c < "$DCB_DICT" | tr -d ' ') bytes"
  echo
}

compressed_artifact_path() {
  local algo="$1"
  local level="$2"

  echo "$TMPDIR/${algo}-${level}.bin"
}

prepare_compressed_artifacts() {
  local algo="$1"
  local min="$2"
  local max="$3"
  local level artifact

  echo "Preparing compressed artifacts for $algo (levels $min..$max)..."

  for level in $(seq "$min" "$max"); do
    artifact="$(compressed_artifact_path "$algo" "$level")"

    case "$algo" in
      gzip)
        gzip "-$level" -c "$INPUT_FILE" > "$artifact"
        ;;
      brotli)
        brotli -q "$level" -c "$INPUT_FILE" > "$artifact"
        ;;
      zstd)
        zstd "-$level" -c "$INPUT_FILE" > "$artifact"
        ;;
      dcb)
        brotli -q "$level" -D "$DCB_DICT" -c "$INPUT_FILE" > "$artifact"
        ;;
      dcz)
        zstd "-$level" -D "$DCZ_DICT" -c "$INPUT_FILE" > "$artifact"
        ;;
      *)
        echo "Unknown algorithm: $algo" >&2
        return 1
        ;;
    esac
  done
}

run_hyperfine_scan() {
  local algo="$1"
  local min="$2"
  local max="$3"
  local cmd_template="$4"
  local name_template="$5"
  local export_csv="$TMPDIR/${algo}.csv"

  echo "Benchmarking $algo decompression (levels $min..$max)..."
  hyperfine \
    --warmup "$HYPERFINE_WARMUP" \
    --min-runs "$HYPERFINE_MIN_RUNS" \
    --shell=none \
    --parameter-scan level "$min" "$max" \
    --export-csv "$export_csv" \
    --command-name "$name_template" \
    "$cmd_template"
}

measure_compressed_bytes() {
  local algo="$1"
  local level="$2"
  local artifact

  artifact="$(compressed_artifact_path "$algo" "$level")"
  wc -c < "$artifact" | tr -d ' '
}

append_csv_rows() {
  local algo="$1"
  local csv="$TMPDIR/${algo}.csv"

  tail -n +2 "$csv" | while IFS=, read -r _command mean stddev median user sys_time min max level; do
    compressed_bytes="$(measure_compressed_bytes "$algo" "$level")"

    awk -v algo="$algo" \
        -v level="$level" \
        -v input_bytes="$INPUT_BYTES" \
        -v compressed_bytes="$compressed_bytes" \
        -v input_file="$INPUT_BASENAME" \
        -v mean="$mean" \
        -v stddev="$stddev" \
        -v median="$median" \
        -v min="$min" \
        -v max="$max" \
        -v user="$user" \
        -v sys_time="$sys_time" \
        'BEGIN {
      ratio = (compressed_bytes > 0) ? input_bytes / compressed_bytes : 0
      savings = (input_bytes > 0) ? (1 - compressed_bytes / input_bytes) * 100 : 0
      printf "%s,%s,%s,%s,%.4f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%s\n",
        algo, level, input_bytes, compressed_bytes, ratio, savings,
        mean * 1000, median * 1000, stddev * 1000, min * 1000, max * 1000,
        user * 1000, sys_time * 1000, input_file
    }'
  done
}

prepare_dcz
prepare_dcb

for algo in gzip brotli zstd dcb dcz; do
  case "$algo" in
    gzip)
      prepare_compressed_artifacts gzip "$GZIP_LEVEL_MIN" "$GZIP_LEVEL_MAX"
      ;;
    brotli|dcb)
      prepare_compressed_artifacts "$algo" "$BROTLI_LEVEL_MIN" "$BROTLI_LEVEL_MAX"
      ;;
    zstd|dcz)
      prepare_compressed_artifacts "$algo" "$ZSTD_LEVEL_MIN" "$ZSTD_LEVEL_MAX"
      ;;
  esac
done

echo

run_hyperfine_scan gzip "$GZIP_LEVEL_MIN" "$GZIP_LEVEL_MAX" \
  "gzip -dc '$(compressed_artifact_path gzip '{level}')'" \
  "gzip -{level}"

run_hyperfine_scan brotli "$BROTLI_LEVEL_MIN" "$BROTLI_LEVEL_MAX" \
  "brotli -dc '$(compressed_artifact_path brotli '{level}')'" \
  "brotli -q {level}"

run_hyperfine_scan zstd "$ZSTD_LEVEL_MIN" "$ZSTD_LEVEL_MAX" \
  "zstd -dc '$(compressed_artifact_path zstd '{level}')'" \
  "zstd -{level}"

run_hyperfine_scan dcb "$BROTLI_LEVEL_MIN" "$BROTLI_LEVEL_MAX" \
  "brotli -D '$DCB_DICT' -dc '$(compressed_artifact_path dcb '{level}')'" \
  "dcb -q {level}"

run_hyperfine_scan dcz "$ZSTD_LEVEL_MIN" "$ZSTD_LEVEL_MAX" \
  "zstd -D '$DCZ_DICT' -dc '$(compressed_artifact_path dcz '{level}')'" \
  "dcz -{level}"

echo
echo "Writing results..."

{
  echo "algorithm,level,input_bytes,compressed_bytes,compression_ratio,savings_percent,mean_ms,median_ms,stddev_ms,min_ms,max_ms,user_ms,system_ms,input_file"

  for algo in gzip brotli zstd dcb dcz; do
    append_csv_rows "$algo"
  done
} > "$OUTPUT_CSV"

echo "Done."
echo "Results: $OUTPUT_CSV"
echo "Dictionaries: $DCB_DICT, $DCZ_DICT"
echo
column -s, -t "$OUTPUT_CSV" 2>/dev/null || cat "$OUTPUT_CSV"
