# Testing Performance Under Load

Use the under-load benchmark when normal release numbers look acceptable but
the app feels worse while the machine is busy.

```bash
AutoLogSourceCode/swift-autolog/scripts/benchmark-under-load.sh \
  --cpu-workers 7 \
  --memory-mb 2048 \
  --io-workers 1 \
  --label "release under load"
```

The script starts background CPU workers, optional memory pressure, and optional
temporary disk I/O before running the release `AutoLogPerformanceTests` suite.
It writes the raw benchmark log plus extracted CSV rows under
`.build/performance-runs/`.

To append a run to a long-lived history file:

```bash
AutoLogSourceCode/swift-autolog/scripts/benchmark-under-load.sh \
  --append-csv docs/performance/benchmark-history.csv \
  --label "release under load" \
  --notable-change "candidate formatter optimization"
```

Then refresh the Markdown graph:

```bash
AutoLogSourceCode/swift-autolog/scripts/render-benchmark-history.py \
  docs/performance/benchmark-history.csv \
  --output docs/performance/benchmark-history.md
```

Compare runs with the same mode and similar load profile first. A loaded run is
useful because it exposes scheduler sensitivity and variance, but it is also
noisier by design, so rerun suspicious results before treating them as a
regression.

The history should keep both logger profiles visible:

- the synthetic benchmark logger isolates macro/event/formatter/routing work
  while discarding final output
- the normal logger scenario, `Logged without tags (normal logger)`, uses the
  default `AutoLogLogger` path so OSLog delivery and rolling context bookkeeping
  remain represented
- the direct OSLog scenarios call `OSLog.Logger` manually so the history can
  compare no logging, normal OSLog, and AutoLog in the same run family
- the complex scenarios measure inline early returns, branch paths, switch
  branches, and handled catches, which are more representative of macro
  instrumentation than a wrapper around a helper call
