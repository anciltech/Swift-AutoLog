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
construction and decode time so `matches(_:)` can reuse the normalized list
without doing extra cleanup work on every emit.
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

## Current performance TODOs

The next hot-path targets worth exploring are:

- continue looking for macro-generation opportunities that reduce work without
  making expansion snapshots harder to audit

## Latest local evaluation

The 2026-05-09 project audit reran the benchmark suite in both debug and
release modes. On that machine, the release helper reported roughly `8-14us`
of added sync overhead per logged call depending on tag shape, with route-only
calls cheapest, no-tag calls in the middle, and visible/mixed tag output higher
because those scenarios render more user-facing text. The logged `TaskGroup`
scenario added roughly `31us` per measured call against the async baseline.

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
