#!/usr/bin/env python3
"""Render a small Markdown report from AutoLog benchmark history CSV."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path


TRACKED_SCENARIOS = [
    "Logged without tags",
    "Logged with routing tags",
    "Logged with visible tags",
    "Logged with mixed tags",
    "Logged task group",
]


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def run_label(row: dict[str, str]) -> str:
    label = row["label"] or row["run_id"]
    mode = row["mode"]
    load = row["load_profile"]
    return f"{label}\\n{mode}\\n{load}"


def cell(row: dict[str, str], key: str) -> str:
    return row.get(key) or ""


def chart_for(rows: list[dict[str, str]], scenario: str) -> str:
    scenario_rows = [row for row in rows if row["scenario"] == scenario]
    labels = [run_label(row) for row in scenario_rows]
    values = [float(row["overhead_us"]) for row in scenario_rows]
    if not values:
        return ""

    max_value = max(values)
    y_max = max(1, int(max_value * 1.2) + 1)
    label_text = ", ".join(f'"{label}"' for label in labels)
    value_text = ", ".join(f"{value:.2f}" for value in values)

    return f"""```mermaid
xychart-beta
  title "{scenario} overhead per call"
  x-axis [{label_text}]
  y-axis "us" 0 --> {y_max}
  line [{value_text}]
```"""


def markdown(rows: list[dict[str, str]]) -> str:
    rows_by_run: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        rows_by_run[row["run_id"]].append(row)

    lines = [
        "# AutoLog Benchmark History",
        "",
        "This file tracks benchmark runs that are useful for spotting performance",
        "movement over time. Compare runs with the same `mode` and similar",
        "`load_profile` first; cross-mode comparisons are directional only.",
        "",
        "## Runs",
        "",
        "| Run | Mode | Load | Commit | Notable change |",
        "|---|---|---|---|---|",
    ]

    for run_id, run_rows in rows_by_run.items():
        first = run_rows[0]
        lines.append(
            "| "
            + " | ".join(
                [
                    run_id,
                    cell(first, "mode"),
                    cell(first, "load_profile"),
                    cell(first, "commit"),
                    cell(first, "notable_change"),
                ]
            )
            + " |"
        )

    lines.extend(["", "## Charts", ""])
    for scenario in TRACKED_SCENARIOS:
        chart = chart_for(rows, scenario)
        if chart:
            lines.extend([f"### {scenario}", "", chart, ""])

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
