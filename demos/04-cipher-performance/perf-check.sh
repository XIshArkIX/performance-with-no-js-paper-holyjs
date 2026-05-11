#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config (можно переопределить через env)
# =========================
RSA_BITS="${RSA_BITS:-3072}"          # 2048 или 3072
KEYGEN_ITERS="${KEYGEN_ITERS:-30}"
SIGN_ITERS="${SIGN_ITERS:-200}"
VERIFY_ITERS="${VERIFY_ITERS:-200}"
WARMUP_ITERS="${WARMUP_ITERS:-5}"
MSG_SIZE_BYTES="${MSG_SIZE_BYTES:-1024}"

RAW_CSV="${RAW_CSV:-results_raw.csv}"
SUMMARY_CSV="${SUMMARY_CSV:-results_summary.csv}"

# =========================
# Checks
# =========================
command -v openssl >/dev/null || { echo "openssl not found"; exit 1; }
command -v awk >/dev/null || { echo "awk not found"; exit 1; }
command -v sort >/dev/null || { echo "sort not found"; exit 1; }
command -v date >/dev/null || { echo "date not found"; exit 1; }

OPENSSL_VER="$(openssl version || true)"
echo "Using: $OPENSSL_VER"

# =========================
# Work dir
# =========================
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

MSG_FILE="$TMPDIR/msg.bin"

RSA_PRIV="$TMPDIR/rsa_priv.pem"
RSA_PUB="$TMPDIR/rsa_pub.pem"
RSA_SIG="$TMPDIR/rsa.sig"

ED_PRIV="$TMPDIR/ed_priv.pem"
ED_PUB="$TMPDIR/ed_pub.pem"
ED_SIG="$TMPDIR/ed.sig"

# =========================
# Helpers
# =========================
now_ns() {
  date +%s%N
}

record_time() {
  # $1 alg, $2 op, $3 iter, $4 ns
  local alg="$1" op="$2" iter="$3" ns="$4"
  local ms
  ms="$(awk -v n="$ns" 'BEGIN { printf "%.6f", n/1000000 }')"
  echo "${alg},${op},${iter},${ns},${ms}" >> "$RAW_CSV"
}

run_timed() {
  # $1 alg, $2 op, $3 iter, command...
  local alg="$1" op="$2" iter="$3"
  shift 3

  local start end ns
  start="$(now_ns)"
  "$@" >/dev/null 2>&1
  end="$(now_ns)"
  ns=$((end - start))
  record_time "$alg" "$op" "$iter" "$ns"
}

warmup_cmd() {
  # $1 count, command...
  local count="$1"
  shift
  for _ in $(seq 1 "$count"); do
    "$@" >/dev/null 2>&1 || true
  done
}

# =========================
# Prepare message + fixed keys for sign/verify
# =========================
head -c "$MSG_SIZE_BYTES" /dev/urandom > "$MSG_FILE"

# Keys for sign/verify phase
openssl genpkey -algorithm RSA -pkeyopt "rsa_keygen_bits:${RSA_BITS}" -out "$RSA_PRIV" >/dev/null 2>&1
openssl pkey -in "$RSA_PRIV" -pubout -out "$RSA_PUB" >/dev/null 2>&1

openssl genpkey -algorithm ED25519 -out "$ED_PRIV" >/dev/null 2>&1
openssl pkey -in "$ED_PRIV" -pubout -out "$ED_PUB" >/dev/null 2>&1

# Precompute signatures for verify phase
openssl dgst -sha256 -sign "$RSA_PRIV" -out "$RSA_SIG" "$MSG_FILE" >/dev/null 2>&1
openssl pkeyutl -sign -inkey "$ED_PRIV" -rawin -in "$MSG_FILE" -out "$ED_SIG" >/dev/null 2>&1

# =========================
# CSV header
# =========================
echo "algorithm,operation,iteration,time_ns,time_ms" > "$RAW_CSV"

echo "Benchmark config:"
echo "  RSA_BITS=$RSA_BITS"
echo "  KEYGEN_ITERS=$KEYGEN_ITERS, SIGN_ITERS=$SIGN_ITERS, VERIFY_ITERS=$VERIFY_ITERS"
echo "  WARMUP_ITERS=$WARMUP_ITERS"
echo "  MSG_SIZE_BYTES=$MSG_SIZE_BYTES"
echo

# =========================
# 1) KEYGEN
# =========================
echo "[1/3] KEYGEN..."

# Warmup
warmup_cmd "$WARMUP_ITERS" openssl genpkey -algorithm RSA -pkeyopt "rsa_keygen_bits:${RSA_BITS}" -out "$TMPDIR/warm_rsa.pem"
warmup_cmd "$WARMUP_ITERS" openssl genpkey -algorithm ED25519 -out "$TMPDIR/warm_ed.pem"

for i in $(seq 1 "$KEYGEN_ITERS"); do
  run_timed "RSA" "keygen" "$i" \
    openssl genpkey -algorithm RSA -pkeyopt "rsa_keygen_bits:${RSA_BITS}" -out "$TMPDIR/rsa_kg_${i}.pem"
done

for i in $(seq 1 "$KEYGEN_ITERS"); do
  run_timed "ED25519" "keygen" "$i" \
    openssl genpkey -algorithm ED25519 -out "$TMPDIR/ed_kg_${i}.pem"
done

# =========================
# 2) SIGN
# =========================
echo "[2/3] SIGN..."

# Warmup
warmup_cmd "$WARMUP_ITERS" openssl dgst -sha256 -sign "$RSA_PRIV" -out /dev/null "$MSG_FILE"
warmup_cmd "$WARMUP_ITERS" openssl pkeyutl -sign -inkey "$ED_PRIV" -rawin -in "$MSG_FILE" -out /dev/null

for i in $(seq 1 "$SIGN_ITERS"); do
  run_timed "RSA" "sign" "$i" \
    openssl dgst -sha256 -sign "$RSA_PRIV" -out /dev/null "$MSG_FILE"
done

for i in $(seq 1 "$SIGN_ITERS"); do
  run_timed "ED25519" "sign" "$i" \
    openssl pkeyutl -sign -inkey "$ED_PRIV" -rawin -in "$MSG_FILE" -out /dev/null
done

# =========================
# 3) VERIFY
# =========================
echo "[3/3] VERIFY..."

# Warmup
warmup_cmd "$WARMUP_ITERS" openssl dgst -sha256 -verify "$RSA_PUB" -signature "$RSA_SIG" "$MSG_FILE"
warmup_cmd "$WARMUP_ITERS" openssl pkeyutl -verify -pubin -inkey "$ED_PUB" -rawin -in "$MSG_FILE" -sigfile "$ED_SIG"

for i in $(seq 1 "$VERIFY_ITERS"); do
  run_timed "RSA" "verify" "$i" \
    openssl dgst -sha256 -verify "$RSA_PUB" -signature "$RSA_SIG" "$MSG_FILE"
done

for i in $(seq 1 "$VERIFY_ITERS"); do
  run_timed "ED25519" "verify" "$i" \
    openssl pkeyutl -verify -pubin -inkey "$ED_PUB" -rawin -in "$MSG_FILE" -sigfile "$ED_SIG"
done

# =========================
# Summary CSV
# =========================
echo "algorithm,operation,n,mean_ms,median_ms,min_ms,max_ms,ops_per_sec_from_mean" > "$SUMMARY_CSV"

tail -n +2 "$RAW_CSV" | awk -F, '{print $1","$2}' | sort -u | while IFS=, read -r alg op; do
  group_vals="$(awk -F, -v a="$alg" -v o="$op" '$1==a && $2==o {print $5}' "$RAW_CSV" | sort -n)"
  n="$(printf "%s\n" "$group_vals" | awk 'NF{c++} END{print c+0}')"

  if [[ "$n" -eq 0 ]]; then
    continue
  fi

  mean="$(printf "%s\n" "$group_vals" | awk '{s+=$1} END{printf "%.6f", s/NR}')"
  median="$(printf "%s\n" "$group_vals" | awk '{arr[NR]=$1} END{
    if (NR%2==1) printf "%.6f", arr[(NR+1)/2];
    else printf "%.6f", (arr[NR/2]+arr[NR/2+1])/2
  }')"
  min="$(printf "%s\n" "$group_vals" | head -n1)"
  max="$(printf "%s\n" "$group_vals" | tail -n1)"
  ops="$(awk -v m="$mean" 'BEGIN{ if(m>0) printf "%.2f", 1000/m; else print "inf" }')"

  echo "${alg},${op},${n},${mean},${median},${min},${max},${ops}" >> "$SUMMARY_CSV"
done

echo
echo "Done."
echo "Raw results:     $RAW_CSV"
echo "Summary results: $SUMMARY_CSV"
echo
column -s, -t "$SUMMARY_CSV" || cat "$SUMMARY_CSV"