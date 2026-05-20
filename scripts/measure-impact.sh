#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)"
OUTPUT_DIR="$PACKAGE_DIR/.build/impact-runs/$RUN_ID"
KEEP_WORKDIR=0

usage() {
  cat <<'USAGE'
Usage: measure-impact.sh [--output DIR] [--keep-workdir]

Builds equivalent release executables and records binary-size impact:
  - BaselineProbe: plain Swift control-flow probe
  - DirectOSLogProbe: same probe with manual OSLog calls
  - AutoLogProbe: same probe using @AutoLog from this checkout
  - AutoLogFailuresOnlyProbe: @AutoLog with output configured for failures only
  - AutoLogTypeFilteredProbe: @AutoLog with output filtered to another type

The output directory receives summary.csv, summary.md, per-build logs, and
linked-dylib lists.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --keep-workdir)
      KEEP_WORKDIR=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$OUTPUT_DIR"
WORK_ROOT="$OUTPUT_DIR/work"
rm -rf "$WORK_ROOT"
mkdir -p "$WORK_ROOT"

timestamp() {
  perl -MTime::HiRes=time -e 'printf "%.6f\n", time'
}

elapsed_seconds() {
  awk -v start="$1" -v end="$2" 'BEGIN { printf "%.3f", end - start }'
}

write_probe_package() {
  local dir="$1"
  local name="$2"
  local dependencies="$3"
  local target_dependencies="$4"

  mkdir -p "$dir/Sources/$name"
  cat > "$dir/Package.swift" <<EOF
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "$name",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "$name", targets: ["$name"]),
  ],
  dependencies: [
$dependencies
  ],
  targets: [
    .executableTarget(
      name: "$name",
      dependencies: [
$target_dependencies
      ]
    ),
  ]
)
EOF
}

write_autolog_probe_package() {
  local dir="$1"

  mkdir -p \
    "$dir/Sources/AutoLogProbe" \
    "$dir/Sources/AutoLogFailuresOnlyProbe" \
    "$dir/Sources/AutoLogTypeFilteredProbe"

  cat > "$dir/Package.swift" <<EOF
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AutoLogImpactProbes",
  platforms: [.macOS(.v15)],
  products: [
    .executable(name: "AutoLogProbe", targets: ["AutoLogProbe"]),
    .executable(name: "AutoLogFailuresOnlyProbe", targets: ["AutoLogFailuresOnlyProbe"]),
    .executable(name: "AutoLogTypeFilteredProbe", targets: ["AutoLogTypeFilteredProbe"]),
  ],
  dependencies: [
    .package(path: "$PACKAGE_DIR"),
  ],
  targets: [
    .executableTarget(
      name: "AutoLogProbe",
      dependencies: [
        .product(name: "AutoLog", package: "Swift-AutoLog"),
      ]
    ),
    .executableTarget(
      name: "AutoLogFailuresOnlyProbe",
      dependencies: [
        .product(name: "AutoLog", package: "Swift-AutoLog"),
      ]
    ),
    .executableTarget(
      name: "AutoLogTypeFilteredProbe",
      dependencies: [
        .product(name: "AutoLog", package: "Swift-AutoLog"),
      ]
    ),
  ]
)
EOF
}

write_baseline_source() {
  local file="$1"
  cat > "$file" <<'EOF'
struct ImpactWorker {
  func compute(_ value: Int) -> Int {
    if value.isMultiple(of: 2) {
      return value / 2
    }
    return value * 3 + 1
  }
}

let worker = ImpactWorker()
let result = (0..<100).reduce(0) { total, value in
  total + worker.compute(value)
}
print(result)
EOF
}

write_direct_oslog_source() {
  local file="$1"
  cat > "$file" <<'EOF'
import OSLog

struct ImpactWorker {
  static let logger = Logger(subsystem: "ImpactProbe", category: "DirectOSLog")

  func compute(_ value: Int) -> Int {
    if value.isMultiple(of: 2) {
      Self.logger.info("even value: \(value)")
      return value / 2
    }
    Self.logger.info("odd value: \(value)")
    return value * 3 + 1
  }
}

let worker = ImpactWorker()
let result = (0..<100).reduce(0) { total, value in
  total + worker.compute(value)
}
print(result)
EOF
}

write_autolog_source() {
  local file="$1"
  cat > "$file" <<'EOF'
import AutoLog

@AutoLog
struct ImpactWorker {
  func compute(_ value: Int) -> Int {
    if value.isMultiple(of: 2) {
      return value / 2
    }
    return value * 3 + 1
  }
}

let worker = ImpactWorker()
let result = (0..<100).reduce(0) { total, value in
  total + worker.compute(value)
}
print(result)
EOF
}

write_autolog_failures_only_source() {
  local file="$1"
  cat > "$file" <<'EOF'
import AutoLog

AutoLog.start(
  configuration: AutoLogConfiguration(
    outputs: [
      AutoLogOutput(
        name: "Failures",
        route: .console,
        eventTypes: [.failure],
        measureTiming: false,
        errorContextLimit: 0
      )
    ]
  )
)

enum ImpactError: Error {
  case oddValue
}

@AutoLog
struct ImpactWorker {
  func compute(_ value: Int) throws -> Int {
    if value.isMultiple(of: 2) {
      return value / 2
    }
    throw ImpactError.oddValue
  }
}

let worker = ImpactWorker()
let result = (0..<100).reduce(0) { total, value in
  total + ((try? worker.compute(value)) ?? 0)
}
print(result)
EOF
}

write_autolog_type_filtered_source() {
  local file="$1"
  cat > "$file" <<'EOF'
import AutoLog

AutoLog.start(
  configuration: AutoLogConfiguration(
    outputs: [
      AutoLogOutput(
        name: "Filtered",
        route: .console,
        typeNameFilters: ["OtherType"],
        measureTiming: false,
        errorContextLimit: 0
      )
    ]
  )
)

@AutoLog
struct ImpactWorker {
  func compute(_ value: Int) -> Int {
    if value.isMultiple(of: 2) {
      return value / 2
    }
    return value * 3 + 1
  }
}

let worker = ImpactWorker()
let result = (0..<100).reduce(0) { total, value in
  total + worker.compute(value)
}
print(result)
EOF
}

segment_bytes() {
  local exe="$1"
  local segment="$2"

  size -m "$exe" | awk -v segment="$segment:" '
    $1 == "Segment" && $2 == segment {
      print $3
      found = 1
    }
    END {
      if (!found) {
        print ""
      }
    }
  '
}

build_and_measure() {
  local scenario="$1"
  local product="$2"
  local dir="$3"
  local log_file="$OUTPUT_DIR/${scenario}-build.log"
  local dylib_file="$OUTPUT_DIR/${scenario}-dylibs.txt"

  local start
  local end
  start="$(timestamp)"
  swift build \
    --package-path "$dir" \
    --configuration release \
    --product "$product" \
    > "$log_file" \
    2>&1
  end="$(timestamp)"

  local exe="$dir/.build/release/$product"
  local executable_bytes
  local text_bytes
  local data_const_bytes
  local data_bytes
  local linkedit_bytes
  local dylib_count
  local elapsed

  executable_bytes="$(stat -f%z "$exe")"
  text_bytes="$(segment_bytes "$exe" "__TEXT")"
  data_const_bytes="$(segment_bytes "$exe" "__DATA_CONST")"
  data_bytes="$(segment_bytes "$exe" "__DATA")"
  linkedit_bytes="$(segment_bytes "$exe" "__LINKEDIT")"
  otool -L "$exe" | sed '1d' > "$dylib_file"
  dylib_count="$(wc -l < "$dylib_file" | tr -d ' ')"
  elapsed="$(elapsed_seconds "$start" "$end")"

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$scenario" \
    "$product" \
    "$executable_bytes" \
    "$text_bytes" \
    "$data_const_bytes" \
    "$data_bytes" \
    "$linkedit_bytes" \
    "$dylib_count" \
    "$elapsed" \
    >> "$OUTPUT_DIR/summary.csv"
}

baseline_dir="$WORK_ROOT/BaselineProbe"
direct_dir="$WORK_ROOT/DirectOSLogProbe"
autolog_dir="$WORK_ROOT/AutoLogImpactProbes"

write_probe_package "$baseline_dir" "BaselineProbe" "" ""
write_baseline_source "$baseline_dir/Sources/BaselineProbe/main.swift"

write_probe_package "$direct_dir" "DirectOSLogProbe" "" ""
write_direct_oslog_source "$direct_dir/Sources/DirectOSLogProbe/main.swift"

write_autolog_probe_package "$autolog_dir"
write_autolog_source "$autolog_dir/Sources/AutoLogProbe/main.swift"
write_autolog_failures_only_source "$autolog_dir/Sources/AutoLogFailuresOnlyProbe/main.swift"
write_autolog_type_filtered_source "$autolog_dir/Sources/AutoLogTypeFilteredProbe/main.swift"

cat > "$OUTPUT_DIR/summary.csv" <<'EOF'
scenario,product,executable_bytes,text_segment_bytes,data_const_segment_bytes,data_segment_bytes,linkedit_segment_bytes,linked_dylib_count,build_seconds
EOF

build_and_measure "baseline" "BaselineProbe" "$baseline_dir"
build_and_measure "direct-oslog" "DirectOSLogProbe" "$direct_dir"
build_and_measure "autolog" "AutoLogProbe" "$autolog_dir"
build_and_measure "autolog-failures-only-output" "AutoLogFailuresOnlyProbe" "$autolog_dir"
build_and_measure "autolog-type-filtered-output" "AutoLogTypeFilteredProbe" "$autolog_dir"

awk -F, '
  NR == 1 { next }
  {
    rows[NR - 1] = $0
    executable[$1] = $3
    text[$1] = $4
    dylibs[$1] = $8
    build[$1] = $9
  }
  END {
    print "# AutoLog Impact Probe"
    print ""
    print "| Scenario | Executable bytes | __TEXT bytes | Linked dylibs | Build seconds |"
    print "|---|---:|---:|---:|---:|"
    for (i = 1; i <= length(rows); i++) {
      split(rows[i], fields, ",")
      printf "| %s | %d | %d | %d | %.3f |\n", fields[1], fields[3], fields[4], fields[8], fields[9]
    }
    print ""
    printf "- AutoLog vs baseline executable delta: %+d bytes\n", executable["autolog"] - executable["baseline"]
    printf "- AutoLog vs direct OSLog executable delta: %+d bytes\n", executable["autolog"] - executable["direct-oslog"]
    printf "- AutoLog vs baseline __TEXT delta: %+d bytes\n", text["autolog"] - text["baseline"]
    printf "- AutoLog vs direct OSLog __TEXT delta: %+d bytes\n", text["autolog"] - text["direct-oslog"]
    printf "- AutoLog failures-only output vs AutoLog executable delta: %+d bytes\n", executable["autolog-failures-only-output"] - executable["autolog"]
    printf "- AutoLog type-filtered output vs AutoLog executable delta: %+d bytes\n", executable["autolog-type-filtered-output"] - executable["autolog"]
  }
' "$OUTPUT_DIR/summary.csv" > "$OUTPUT_DIR/summary.md"

if [[ "$KEEP_WORKDIR" -eq 0 ]]; then
  rm -rf "$WORK_ROOT"
fi

echo "Impact measurements written to $OUTPUT_DIR"
cat "$OUTPUT_DIR/summary.md"
