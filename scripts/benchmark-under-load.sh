#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$PACKAGE_DIR/.build/performance-runs"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
LABEL="under-load"
CPU_WORKERS=""
MEMORY_MB=0
IO_WORKERS=0
APPEND_CSV=""
NOTABLE_CHANGE=""

usage() {
  cat <<'USAGE'
Usage: benchmark-under-load.sh [options]

Runs the release AutoLogPerformanceTests suite while background load workers
consume CPU, optional memory, and optional temporary disk I/O.

Options:
  --cpu-workers N       CPU workers to spawn. Default: logical CPUs - 1.
  --memory-mb N         Approximate memory pressure in MB. Default: 0.
  --io-workers N        Temporary disk I/O workers. Default: 0.
  --output-dir PATH     Directory for logs and extracted CSV. Default: .build/performance-runs.
  --append-csv PATH     Append parsed rows to an existing history CSV.
  --run-id ID           Run identifier. Default: UTC timestamp.
  --label TEXT          Human-readable label. Default: under-load.
  --notable-change TEXT Note stored with parsed CSV rows.
  -h, --help            Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cpu-workers)
      CPU_WORKERS="$2"
      shift 2
      ;;
    --memory-mb)
      MEMORY_MB="$2"
      shift 2
      ;;
    --io-workers)
      IO_WORKERS="$2"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --append-csv)
      APPEND_CSV="$2"
      shift 2
      ;;
    --run-id)
      RUN_ID="$2"
      shift 2
      ;;
    --label)
      LABEL="$2"
      shift 2
      ;;
    --notable-change)
      NOTABLE_CHANGE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$CPU_WORKERS" ]]; then
  if command -v sysctl >/dev/null 2>&1; then
    LOGICAL_CPUS="$(sysctl -n hw.logicalcpu)"
  else
    LOGICAL_CPUS="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
  fi
  CPU_WORKERS=$(( LOGICAL_CPUS > 1 ? LOGICAL_CPUS - 1 : 1 ))
fi

mkdir -p "$OUTPUT_DIR"
LOG_FILE="$OUTPUT_DIR/$RUN_ID.log"
CSV_FILE="$OUTPUT_DIR/$RUN_ID.csv"
LOAD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/autolog-load.XXXXXX")"
PIDS=()

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" >/dev/null 2>&1 || true
  done
  wait >/dev/null 2>&1 || true
  rm -rf "$LOAD_DIR"
}
trap cleanup EXIT INT TERM

start_cpu_load() {
  for _ in $(seq 1 "$CPU_WORKERS"); do
    yes > /dev/null &
    PIDS+=("$!")
  done
}

start_memory_load() {
  [[ "$MEMORY_MB" -gt 0 ]] || return 0
  python3 - "$MEMORY_MB" <<'PY' &
import sys
import time

megabytes = int(sys.argv[1])
chunks = [bytearray(1024 * 1024) for _ in range(megabytes)]
for index, chunk in enumerate(chunks):
    chunk[0] = index % 255
while True:
    time.sleep(1)
PY
  PIDS+=("$!")
}

start_io_load() {
  for index in $(seq 1 "$IO_WORKERS"); do
    (
      file="$LOAD_DIR/io-$index.bin"
      while :; do
        dd if=/dev/zero of="$file" bs=1m count=64 conv=notrunc >/dev/null 2>&1
        rm -f "$file"
      done
    ) &
    PIDS+=("$!")
  done
}

{
  echo "AutoLog under-load benchmark"
  echo "run_id=$RUN_ID"
  echo "label=$LABEL"
  echo "cpu_workers=$CPU_WORKERS"
  echo "memory_mb=$MEMORY_MB"
  echo "io_workers=$IO_WORKERS"
  echo "package_dir=$PACKAGE_DIR"
  echo "commit=$(git -C "$PACKAGE_DIR" rev-parse --short HEAD 2>/dev/null || true)"
  echo
} | tee "$LOG_FILE"

start_cpu_load
start_memory_load
start_io_load
sleep 2

"$SCRIPT_DIR/benchmark.sh" 2>&1 | tee -a "$LOG_FILE"

python3 "$SCRIPT_DIR/extract-benchmark-summary.py" "$LOG_FILE" \
  --output "$CSV_FILE" \
  --run-id "$RUN_ID" \
  --label "$LABEL" \
  --mode release \
  --load-profile "cpu=$CPU_WORKERS;memory_mb=$MEMORY_MB;io=$IO_WORKERS" \
  --notable-change "$NOTABLE_CHANGE"

if [[ -n "$APPEND_CSV" ]]; then
  python3 "$SCRIPT_DIR/extract-benchmark-summary.py" "$LOG_FILE" \
    --output "$APPEND_CSV" \
    --append \
    --run-id "$RUN_ID" \
    --label "$LABEL" \
    --mode release \
    --load-profile "cpu=$CPU_WORKERS;memory_mb=$MEMORY_MB;io=$IO_WORKERS" \
    --notable-change "$NOTABLE_CHANGE"
fi

echo "Log: $LOG_FILE"
echo "CSV: $CSV_FILE"
