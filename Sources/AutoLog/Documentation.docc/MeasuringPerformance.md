# Measuring AutoLog Performance

Use the package performance tests when you want comparable numbers for the
runtime cost of `@Log` with different tag profiles.

## What the benchmark measures

`AutoLogPerformanceTests` compares the same control-flow-heavy function body in
five tag-focused scenarios:

- a plain baseline with no logging
- `@Log` without tags
- `@Log` with visible string tags
- `@Log` with routing tags such as `.splunk` and `.firebase`
- `@Log` with mixed visible and routing tags

That shared body deliberately exercises `guard`, `if`/`else`, and `do`/`catch`
paths so the benchmark covers more than a straight arithmetic hot loop. The
suite also includes a baseline and logged async `TaskGroup` scenario to show
how the macro behaves once structured concurrency is part of the call path.

The test runtime installs a benchmark logger that mirrors the production
formatter and route-filtering decisions while discarding final output. That
keeps the results stable enough to compare tag profiles and async wrapper cost
without console I/O dominating the measurement.

The current compact-formatter hot path also includes a few lightweight guards
that keep the benchmark focused on real formatting cost instead of avoidable
bookkeeping: route and visible-tag filtering are cached on `AutoLogEvent`,
single-parameter calls skip dictionary sorting, and async detection uses direct
string checks instead of regex matching on every emit.
Tag classification now also has an empty-tag fast path and a single-pass
non-empty path, so no-tag calls avoid route and visible-tag allocation work and
mixed tag calls do not scan the same array twice.
The default compact layout now also uses a dedicated body-rendering fast path
instead of walking the generic element list for every event, which trims work
from the benchmark's `Logged without tags`, `Logged with visible tags`, and
`Logged with mixed tags` scenarios while keeping custom `LogFormat` handling on
the existing generic path.
Outside the synthetic benchmark logger, `AutoLogLogger` now also resolves
output profiles in one pass and reuses the first console render as the rolling
failure-context snapshot, which removes an extra formatter call from the common
console path without changing the emitted first line.
`AutoLogEvent` now also caches parsed call-site metadata such as inferred type
name, source line, short location, function name, and async presence so the
formatter and output-profile matching do not keep re-splitting the same
`location` and `declaration` strings within a single emit.
`AutoLogOutput` now also trims and drops empty type-name filters at
construction, decode time, and direct mutation so `matches(_:)` can reuse the
normalized list without doing extra cleanup work on every emit.
`CompactFormatter` also keeps formatted parameter text in a per-event cache
while rendering, so custom formats that include `.parameters` more than once
reuse the same sorted and stringified parameter payload.
Multi-parameter formatting now sorts only parameter labels before looking up
values and returns clearly value-like `CustomStringConvertible` descriptions
before the type-only reflection fallback, reducing tuple copying and avoidable
reflection for common payload wrappers.
Custom format rendering now also uses a compact format plan so a single pass
classifies leading metadata columns, inline elements, and dependent flags. When
callers install a fixed formatter-level `LogFormat`, that plan is prepared once
at formatter initialization instead of rebuilt on each emitted event.
The default runtime `LogFormat` now also uses a shared precomputed plan, so
callers that rely on live configuration avoid rebuilding the stock column and
inline-element classification for every emitted event.
`AutoLogEvent` also specializes single-tag construction, so route-only events
such as `.splunk` and single visible tags avoid the mixed-tag classification
loop and visible-tag reserve path.
Macro expansion now also omits explicit `parameters: [:]` and `tags: []`
arguments when a logged function has no captured parameters or tags, letting
`AutoLogEvent` use its defaults instead of constructing empty literals in the
generated wrapper.
Macro-generated wrappers now also use runtime-based `AutoLogger` helpers for
start emission, completion emission, and timing checks. The captured
`AutoLogRuntime` still supplies the same entry-time logger, configuration, and
deduplicator, but the generated call sites no longer repeat those fields.
Function-level timing suppression is available on custom logger overloads too:
`@Log(using: logger, measure: false)` skips `ContinuousClock` capture and
duration assignment while still emitting the start and completion events.
Default `@Log` timing capture now also checks the entry runtime configuration
before sampling the clock, so `measureTimingDefault: false` avoids duration
capture work unless a function explicitly opts back in with `measure: true`.
`AutoLogEvent` now also caches a deterministic parameter-label order when it is
constructed and refreshes that cache when parameters are replaced, so repeated
formatter passes for the same event do not re-sort multi-parameter labels.
Failure events now also snapshot the logger's recent-context buffer once per
emit and derive each output profile's context limit from that snapshot, avoiding
repeated lock reads when a failure fans out to multiple outputs.
Filtered events now also avoid capturing execution context before output and
deduplication checks pass.

## Current performance TODOs

The next hot-path targets worth exploring are:

- measure logical call-depth propagation separately from formatting and output
  work; the current macro-generated wrappers always read
  `AutoLogSource.nextCallSiteDepth` and scope the body with
  `AutoLogSource.withCallSiteDepth(...)`
- avoid generated start calls entirely when build policy guarantees no `.start`
  events
- add benchmarks for start-disabled wrappers, output fan-out, parameter privacy,
  custom formats, failure-context-heavy paths, and many-call-site app-style
  mixes beyond the current throwing failures-only scale probe
- continue looking for macro-generation opportunities that reduce work without
  making expansion snapshots harder to audit

## Latest local evaluation

The 2026-06-19 follow-up pass removed the legacy string-literal `emit:` macro
overloads and singular/error aliases, kept the typed case API
(`@AutoLog(emit: .failures)` and
`@AutoLog(emit: [.failures, .warnings])`), and reran the impact probe with
isolated first/second build paths per scenario.

The retained emission representation is a trimmed `RawRepresentable` value:
it keeps the typed macro syntax while measuring smaller than the enum and
static-value alternatives. The rejected emission-shape experiments are worth
remembering: a public enum was semantically tidy but pushed the core probe over
an extra `__TEXT` page, while static `String` and `UInt8` wrappers measured
larger for the production failures-only probe.

The final follow-up probe reported:

| Scenario | Executable bytes | Stripped bytes | `__TEXT` bytes | First build | Second build |
|---|---:|---:|---:|---:|---:|
| `autolog` | `897,056` | `498,600` | `327,680` | `19.097s` | `1.112s` |
| `autolog-throwing` | `934,696` | `532,360` | `344,064` | `16.698s` | `1.191s` |
| `autolog-failures-only-output` | `935,624` | `532,368` | `344,064` | `16.892s` | `1.210s` |
| `autolog-compile-failures-only` | `919,008` | `515,872` | `327,680` | `17.155s` | `1.242s` |
| `autolog-compile-diagnostics` | `935,424` | `532,384` | `344,064` | `16.986s` | `1.494s` |

Against the default throwing baseline, runtime-filtered failures-only added
`928` raw bytes, `8` stripped bytes, and no `__TEXT` growth. Compile-time
`@AutoLog(emit: .failures)` was smaller than the throwing baseline by
`15,688` raw bytes, `16,488` stripped bytes, and one `16,384` byte `__TEXT`
page. `@AutoLog(emit: [.failures, .warnings])` stayed close to the throwing
baseline, adding `728` raw bytes, `24` stripped bytes, and no `__TEXT` growth.

The next repeated run added a many-call-site impact probe with 64 throwing
methods. Against the single throwing fixed-cost probe, 64 default throwing
call sites added `150,176` raw bytes and `131,904` stripped bytes. Switching
that many-call-site target to `@AutoLog(emit: .failures)` saved `14,392` raw
bytes, `16,464` stripped bytes, and one `16,384` byte `__TEXT` page against
the many default throwing target. This confirms compile-time pruning scales
with annotated call sites, but it also confirms the dominant first-order
production lever is still avoiding or splitting the fixed runtime payload.

The practical production guidance is to use compile-time `emit:` pruning for
targets that only need failure diagnostics, while treating runtime output
filters as log-volume, routing, and privacy policy rather than binary-size
reduction. A runtime fast path that tried to collapse duplicate output matching
was measured and rejected because it added roughly `30 KB` and another
`__TEXT` page to the release probes. The remaining large binary-size lever is a
smaller product/logger split that avoids linking the full default formatter,
live configuration store, route fan-out, and rolling failure-context machinery
when an app only needs minimal failure telemetry.

The 2026-06-18 main-branch review reran the release benchmark helper and
appended normal and loaded runs to the project history. On that machine, the
normal release helper reported roughly `17-20us` of added sync overhead per
logged call with the benchmark logger depending on tag shape. The normal
`AutoLogLogger` no-tag path added roughly `23us` per sync call, the complex
normal logger path added roughly `28us`, and the logged `TaskGroup` scenario
added roughly `49us` per measured call against the async baseline.

Those numbers are higher than the 2026-05-18 release baseline, where the same
benchmark logger scenarios were roughly `8-11us`, the normal logger no-tag path
was roughly `15us`, and the logged `TaskGroup` scenario was roughly `32us`.
Plain baseline and direct OSLog timings stayed close, so the current working
hypothesis is added AutoLog wrapper/runtime work rather than machine-wide
noise. The strongest suspects are always-on logical call-depth propagation,
runtime-filtered start emission, and additional output-profile matching.

The same review also ran a stress profile with seven CPU workers, `2048 MB` of
memory pressure, and one I/O worker. That loaded run roughly doubled stable
sync logging overhead and pushed the logged `TaskGroup` scenario to about
`125us`. Treat loaded rows as sensitivity data and repeat them before making a
regression call.

Those numbers support the same practical guidance as the benchmark design:
`@Log` is appropriate for interaction workflows, service boundaries,
architecture traces, and demo scenarios, while hot loops, per-frame work, and
large-volume polling should use omission, deduplication, route filtering, or a
more targeted manual event. Treat exact timings as machine-local; use the
relative deltas and rerun the release helper before judging regressions.

## Run the benchmark in Xcode

1. Open the `swift-autolog` package in Xcode.
2. Run the `AutoLogPerformanceTests` test case from the Test navigator.
3. Compare the per-test wall-clock metrics across the five scenarios.
4. Check the end of the suite output for a summary table that lists each
   scenario's average runtime, absolute added time, per-call overhead, `RSD`
   (relative standard deviation), and a short note describing what work is
   responsible for the extra cost in that scenario.

Because each test uses the same loop count, logger configuration, and function
body, the relative deltas are the signal to focus on rather than any absolute
time from one machine to another.

## Run the benchmark from the command line

```bash
swift test \
  --package-path AutoLogSourceCode/swift-autolog \
  --filter AutoLogPerformanceTests
```

The suite prints the same comparison table at the end of the run, which makes
it easier to copy a single summary into notes or pull requests. The table uses
family-specific baselines, so sync scenarios are compared against the plain
sync body and `TaskGroup` scenarios are compared against the plain async
`TaskGroup` body rather than against each other.

For lower-noise numbers, prefer the release-mode helper from the package root:

```bash
AutoLogSourceCode/swift-autolog/scripts/benchmark.sh
```

That script runs the same performance suite with `--configuration release` so
formatter, event construction, routing, and timing-capture changes are easier
to compare between commits.

## Measure binary and build impact

Runtime benchmarks do not answer the whole adoption question. To compare fixed
binary footprint and clean build cost, run the impact probe:

```bash
AutoLogSourceCode/swift-autolog/scripts/measure-impact.sh
```

The probe builds release executables with equivalent control flow: a plain
Swift baseline, a direct `OSLog.Logger` variant, a core `@AutoLog` variant, a
default throwing `@AutoLog` variant, an `AutoLogSwiftUI` opt-in helper variant,
runtime-filtered output variants, and compile-time `emit:` variants such as
`@AutoLog(emit: .failures)` and `@AutoLog(emit: [.failures, .warnings])`.
It writes `summary.csv`,
`summary.md`, build logs, and linked-dylib lists under `.build/impact-runs/`.
Each scenario uses its own build path, so first-build timings are comparable
across products. The probe immediately repeats the same build to capture
second-build/no-op timing for that scenario.

Treat this as a small-probe fixed-cost measurement. It is useful for spotting
package-level footprint movement, but production apps should still measure
their own app binary because SwiftUI, Foundation, and OSLog may already be
linked before AutoLog is added.
Runtime output filters are expected to reduce emitted log volume and sink work,
not the linked footprint: the AutoLog runtime and macro-generated wrapper code
are already present before output matching runs.
Use the default throwing `@AutoLog` scenario as the baseline for failures-only
production analysis, because failures-only probes necessarily include throwing
control flow that the simple core `@AutoLog` probe does not.
Use the many-call-site throwing scenarios when judging whether compile-time
`emit:` pruning pays off across an app-scale number of annotated throwing
functions.
The stripped executable column applies `strip -x` to a copy of each local SwiftPM
probe binary. Use it as a closer release-style size signal than the raw
executable bytes when comparing SwiftPM command-line probes.

To keep a project-level history, append a completed probe and regenerate the
charts:

```bash
AutoLogSourceCode/swift-autolog/scripts/append-impact-summary.py \
  /tmp/autolog-impact-run/summary.csv \
  --output docs/performance/impact-history.csv \
  --append \
  --run-id "$(date -u +%Y%m%dT%H%M%SZ)" \
  --label "release impact" \
  --notable-change "describe the measured change"

AutoLogSourceCode/swift-autolog/scripts/render-impact-history.py \
  docs/performance/impact-history.csv \
  --output docs/performance/impact-history.md
```

## Profile the benchmark with Instruments

Start with **Time Profiler**. It is the best first-pass Instruments template for
this benchmark because it shows where time is spent inside the logged function
path, including:

- macro-generated wrapper work
- `AutoLogEvent` construction
- `CompactFormatter.format(event:configuration:)`
- tag filtering and route checks

You can record the benchmark directly from the command line:

```bash
xcrun xctrace record \
  --template 'Time Profiler' \
  --output /tmp/AutoLogPerformance.trace \
  --launch -- \
  swift test \
    --package-path AutoLogSourceCode/swift-autolog \
    --filter AutoLogPerformanceTests/testLoggedFunctionWithMixedTags
```

If you want to inspect actual OSLog delivery cost after that, the **Logging**
template is a useful second pass. Use it only after Time Profiler, because log
delivery volume can hide the cheaper in-process work you are trying to compare.
