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
Outside the synthetic benchmark logger, `AutoLogLogger` now also resolves
output profiles in one pass and reuses the first console render as the rolling
failure-context snapshot, which removes an extra formatter call from the common
console path without changing the emitted first line.
`AutoLogEvent` now also caches parsed call-site metadata such as inferred type
name, source line, short location, function name, and async presence so the
formatter and output-profile matching do not keep re-splitting the same
`location` and `declaration` strings within a single emit.

## Current performance TODOs

The next hot-path targets worth exploring are:

- make parameter rendering lazy so `CompactFormatter` only formats
  `event.parameters` when the active `LogFormat` actually includes
  `.parameters`
- reduce multi-parameter overhead further by avoiding repeated sorting and
  reflection-heavy formatting work where possible
- move `AutoLogOutput.typeNameFilters` normalization out of `matches(_:)` and
  into configuration-update time so emit-time routing does less trimming and
  filtering work
- look at macro-generated event construction for no-tag and route-only cases to
  see whether `[String: Any]` / `[any Taggable]` setup can be specialized
  further without hurting readability

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
