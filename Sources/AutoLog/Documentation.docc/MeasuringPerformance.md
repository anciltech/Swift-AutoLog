# Measuring AutoLog Performance

Use the package performance tests when you want comparable numbers for the
runtime cost of `@Log` with different tag profiles.

## What the benchmark measures

`AutoLogPerformanceTests` compares the same function body in five scenarios:

- a plain baseline with no logging
- `@Log` without tags
- `@Log` with visible string tags
- `@Log` with routing tags such as `.splunk` and `.firebase`
- `@Log` with mixed visible and routing tags

The test runtime installs a benchmark logger that mirrors the production
formatter and route-filtering decisions while discarding final output. That
keeps the results stable enough to compare tag profiles without console I/O
dominating the measurement.

## Run the benchmark in Xcode

1. Open the `swift-autolog` package in Xcode.
2. Run the `AutoLogPerformanceTests` test case from the Test navigator.
3. Compare the reported wall-clock metrics across the five scenarios.

Because each test uses the same loop count, logger configuration, and function
body, the relative deltas are the signal to focus on rather than any absolute
time from one machine to another.

## Run the benchmark from the command line

```bash
swift test \
  --package-path AutoLogSourceCode/swift-autolog \
  --filter AutoLogPerformanceTests
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
