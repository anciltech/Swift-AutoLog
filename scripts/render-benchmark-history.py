#!/usr/bin/env python3
"""Render a small Markdown report from AutoLog benchmark history CSV."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path


TRACKED_SCENARIOS = [
    "Logged without tags",
    "Direct OSLog",
    "Logged without tags (normal logger)",
    "Direct OSLog complex",
    "AutoLog complex (normal logger)",
    "Logged with routing tags",
    "Logged with visible tags",
    "Logged with mixed tags",
    "Logged task group",
]


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def run_label(row: dict[str, str]) -> str:
    return row["label"] or row["run_id"]


def cell(row: dict[str, str], key: str) -> str:
    return row.get(key) or ""


def run_aliases(rows: list[dict[str, str]]) -> dict[str, str]:
    aliases: dict[str, str] = {}
    for row in rows:
        run_id = row["run_id"]
        if run_id not in aliases:
            aliases[run_id] = f"R{len(aliases) + 1}"
    return aliases


def reference_rows(rows: list[dict[str, str]], scenario: str) -> list[tuple[str, dict[str, str]]]:
    if scenario == "Logged task group":
        baseline = latest_row(rows, "Baseline task group")
        return [("no logging", baseline)] if baseline else []

    if "complex" in scenario.lower():
        baseline = latest_row(rows, "Baseline complex")
        oslog = latest_row(rows, "Direct OSLog complex")
    else:
        baseline = latest_row(rows, "Baseline")
        oslog = latest_row(rows, "Direct OSLog")

    references: list[tuple[str, dict[str, str]]] = []
    if baseline:
        references.append(("no logging", baseline))
    if oslog:
        references.append(("direct OSLog", oslog))
    return references


def chart_for(
    rows: list[dict[str, str]],
    scenario: str,
    aliases: dict[str, str],
) -> str:
    scenario_rows = [row for row in rows if row["scenario"] == scenario]
    labels = [aliases[row["run_id"]] for row in scenario_rows]
    values = [float(row["overhead_us"]) for row in scenario_rows]
    if not values:
        return ""

    references = reference_rows(rows, scenario)
    reference_values = [float(row["overhead_us"]) for _, row in references]
    max_value = max(values + reference_values)
    y_max = max(1, int(max_value * 1.2) + 1)
    label_text = ", ".join(f'"{label}"' for label in labels)
    value_text = ", ".join(f"{value:.2f}" for value in values)
    reference_lines = "\n".join(
        "  line [" + ", ".join(f"{float(row['overhead_us']):.2f}" for _ in values) + "]"
        for _, row in references
    )
    reference_summary = ", ".join(
        f"{name}={float(row['overhead_us']):.2f}us"
        for name, row in references
    )
    title = f"{scenario} overhead per call"
    if reference_summary:
        title += f" (refs: {reference_summary})"

    return f"""```mermaid
xychart-beta
  title "{title}"
  x-axis [{label_text}]
  y-axis "us" 0 --> {y_max}
  line [{value_text}]
{reference_lines}
```"""


def latest_row(rows: list[dict[str, str]], scenario: str, load_contains: str | None = None) -> dict[str, str] | None:
    matches = [
        row for row in rows
        if row["scenario"] == scenario
        and (load_contains is None or load_contains in row["load_profile"])
    ]
    return matches[-1] if matches else None


def comparison_line(
    profile: str,
    row: dict[str, str] | None,
    baseline_overhead: float,
) -> str | None:
    if row is None:
        return None

    overhead = float(row["overhead_us"])
    delta = overhead - baseline_overhead
    return f"| {profile} | {row['run_id']} | {overhead:.3f} | {delta:+.3f} |"


def logger_profile_comparison(rows: list[dict[str, str]]) -> list[str]:
    benchmark_rows = [
        row for row in rows
        if row["scenario"] == "Logged without tags"
        and "benchmark-logger" in row["load_profile"]
    ]
    simple_baseline = latest_row(rows, "Baseline")
    simple_oslog = latest_row(rows, "Direct OSLog")
    simple_autolog = latest_row(rows, "Logged without tags (normal logger)")
    complex_baseline = latest_row(rows, "Baseline complex")
    complex_oslog = latest_row(rows, "Direct OSLog complex")
    complex_autolog = latest_row(rows, "AutoLog complex (normal logger)")

    lines = [
        "## Logging Profile Comparison",
        "",
        "These tables compare no logging, direct `OSLog.Logger`, and the",
        "default `AutoLogLogger` path. The benchmark logger remains useful for",
        "isolating formatter/routing work, but the normal logger rows are the",
        "real-world baseline.",
        "",
    ]

    simple_baseline_overhead = float(simple_baseline["overhead_us"]) if simple_baseline else 0
    simple_lines = [
        comparison_line("No logging", simple_baseline, simple_baseline_overhead),
        comparison_line("Direct OSLog", simple_oslog, simple_baseline_overhead),
        comparison_line("AutoLog normal logger", simple_autolog, simple_baseline_overhead),
    ]
    simple_lines = [line for line in simple_lines if line is not None]
    if simple_lines:
        lines.extend([
            "### Simple Control Flow",
            "",
            "| Profile | Run | Overhead (us) | Delta vs no logging |",
            "|---|---|---:|---:|",
            *simple_lines,
            "",
        ])

    complex_baseline_overhead = float(complex_baseline["overhead_us"]) if complex_baseline else 0
    complex_lines = [
        comparison_line("No logging", complex_baseline, complex_baseline_overhead),
        comparison_line("Direct OSLog", complex_oslog, complex_baseline_overhead),
        comparison_line("AutoLog normal logger", complex_autolog, complex_baseline_overhead),
    ]
    complex_lines = [line for line in complex_lines if line is not None]
    if complex_lines:
        lines.extend([
            "### Complex Control Flow",
            "",
            "| Profile | Run | Overhead (us) | Delta vs no logging |",
            "|---|---|---:|---:|",
            *complex_lines,
            "",
        ])

    benchmark = benchmark_rows[-1] if benchmark_rows else None
    normal = simple_autolog
    if benchmark and normal:
        benchmark_overhead = float(benchmark["overhead_us"])
        normal_overhead = float(normal["overhead_us"])
        delta = normal_overhead - benchmark_overhead
        multiplier = normal_overhead / benchmark_overhead if benchmark_overhead else 0
        lines.extend([
            "### Benchmark Logger Reference",
            "",
            "| Profile | Run | Overhead (us) | Delta vs benchmark logger |",
            "|---|---|---:|---:|",
            f"| Benchmark logger | {benchmark['run_id']} | {benchmark_overhead:.3f} | 0.000 |",
            f"| Normal AutoLogLogger | {normal['run_id']} | {normal_overhead:.3f} | {delta:+.3f} ({multiplier:.2f}x) |",
            "",
        ])

    return lines


def markdown(rows: list[dict[str, str]]) -> str:
    rows_by_run: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        rows_by_run[row["run_id"]].append(row)
    aliases = run_aliases(rows)

    lines = [
        "# AutoLog Benchmark History",
        "",
        "This file tracks benchmark runs that are useful for spotting performance",
        "movement over time. Compare runs with the same `mode` and similar",
        "`load_profile` first; cross-mode comparisons are directional only.",
        "",
        "## Runs",
        "",
        "| Key | Run | Mode | Load | Commit | Notable change |",
        "|---|---|---|---|---|---|",
    ]

    for run_id, run_rows in rows_by_run.items():
        first = run_rows[0]
        lines.append(
            "| "
            + " | ".join(
                [
                    aliases[run_id],
                    run_id,
                    cell(first, "mode"),
                    cell(first, "load_profile"),
                    cell(first, "commit"),
                    cell(first, "notable_change"),
                ]
            )
            + " |"
        )

    lines.extend([
        "",
        "## Charts",
        "",
        "Each chart uses short run keys from the table above to keep labels readable.",
        "The first line is the scenario. Additional horizontal lines are references:",
        "`no logging` and, when available, direct `OSLog.Logger`.",
        "",
    ])
    for scenario in TRACKED_SCENARIOS:
        chart = chart_for(rows, scenario, aliases)
        if chart:
            lines.extend([f"### {scenario}", "", chart, ""])

    lines.extend(logger_profile_comparison(rows))

    lines.extend(
        [
            "## Data",
            "",
            "| Run | Scenario | Average (s) | Added (s) | Overhead (us) | RSD (%) |",
            "|---|---|---:|---:|---:|---:|",
        ]
    )

    for row in rows:
        lines.append(
            "| "
            + " | ".join(
                [
                    row["run_id"],
                    cell(row, "scenario"),
                    cell(row, "average_s"),
                    cell(row, "added_s"),
                    cell(row, "overhead_us"),
                    cell(row, "rsd_percent"),
                ]
            )
            + " |"
        )

    lines.append("")
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(markdown(read_rows(args.csv)))
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
