#!/usr/bin/env python3
"""Render Markdown charts from AutoLog binary/build impact history."""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path


CORE_SCENARIO = "autolog"
BASELINE_SCENARIO = "baseline"
THROWING_SCENARIO = "autolog-throwing"
SWIFTUI_SCENARIO = "autolog-swiftui"
POLICY_SCENARIOS = [
    ("failures output", "autolog-failures-only-output"),
    ("type filtered", "autolog-type-filtered-output"),
    ("success emit", "autolog-compile-successes-only"),
    ("failure emit", "autolog-compile-failures-only"),
    ("diagnostics", "autolog-compile-diagnostics"),
]
BUILD_SCENARIOS = [
    ("baseline", "baseline"),
    ("direct OSLog", "direct-oslog"),
    ("AutoLog", "autolog"),
    ("throwing", "autolog-throwing"),
    ("SwiftUI", "autolog-swiftui"),
]
FAILURES_SCENARIOS = [
    ("throwing all", "autolog-throwing", CORE_SCENARIO),
    ("runtime failures", "autolog-failures-only-output", THROWING_SCENARIO),
    ("compile failures", "autolog-compile-failures-only", THROWING_SCENARIO),
    ("diagnostics", "autolog-compile-diagnostics", THROWING_SCENARIO),
]
MANY_SCENARIOS = [
    ("many throwing", "autolog-many-throwing", THROWING_SCENARIO),
    (
        "many compile failures",
        "autolog-many-compile-failures-only",
        "autolog-many-throwing",
    ),
]


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def cell(row: dict[str, str] | None, key: str) -> str:
    if row is None:
        return ""
    return row.get(key) or ""


def number(row: dict[str, str] | None, key: str) -> float | None:
    value = cell(row, key)
    return float(value) if value else None


def bytes_to_kb(value: float) -> float:
    return value / 1000


def run_aliases(rows: list[dict[str, str]]) -> dict[str, str]:
    aliases: dict[str, str] = {}
    for row in rows:
        run_id = row["run_id"]
        if run_id not in aliases:
            aliases[run_id] = f"I{len(aliases) + 1}"
    return aliases


def rows_by_run_and_scenario(rows: list[dict[str, str]]) -> dict[str, dict[str, dict[str, str]]]:
    grouped: dict[str, dict[str, dict[str, str]]] = defaultdict(dict)
    for row in rows:
        grouped[row["run_id"]][row["scenario"]] = row
    return grouped


def run_rows(rows: list[dict[str, str]]) -> list[tuple[str, list[dict[str, str]]]]:
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[row["run_id"]].append(row)
    return list(grouped.items())


def delta(
    grouped: dict[str, dict[str, dict[str, str]]],
    run_id: str,
    scenario: str,
    baseline: str,
    field: str,
) -> float | None:
    scenario_value = number(grouped[run_id].get(scenario), field)
    baseline_value = number(grouped[run_id].get(baseline), field)
    if scenario_value is None or baseline_value is None:
        return None
    return scenario_value - baseline_value


def chart(
    title: str,
    labels: list[str],
    values: list[float],
    *,
    unit: str,
    chart_type: str = "line",
) -> str:
    if not values:
        return ""

    max_value = max(values)
    min_value = min(values)
    lower = min(0, int(min_value * 1.2))
    upper = max(1, int(max_value * 1.2) + 1)
    label_text = ", ".join(f'"{label}"' for label in labels)
    value_text = ", ".join(f"{value:.2f}" for value in values)

    return f"""```mermaid
xychart-beta
  title "{title}"
  x-axis [{label_text}]
  y-axis "{unit}" {lower} --> {upper}
  {chart_type} [{value_text}]
```"""


def core_delta_charts(
    rows: list[dict[str, str]],
    aliases: dict[str, str],
    grouped: dict[str, dict[str, dict[str, str]]],
) -> list[str]:
    labels: list[str] = []
    raw_values: list[float] = []
    stripped_values: list[float] = []
    text_values: list[float] = []

    for run_id, _ in run_rows(rows):
        labels.append(aliases[run_id])
        raw_values.append(bytes_to_kb(delta(grouped, run_id, CORE_SCENARIO, BASELINE_SCENARIO, "executable_bytes") or 0))
        stripped_values.append(bytes_to_kb(delta(grouped, run_id, CORE_SCENARIO, BASELINE_SCENARIO, "stripped_executable_bytes") or 0))
        text_values.append(bytes_to_kb(delta(grouped, run_id, CORE_SCENARIO, BASELINE_SCENARIO, "text_segment_bytes") or 0))

    return [
        "### Core AutoLog Delta",
        "",
        chart("Core AutoLog raw executable delta vs baseline", labels, raw_values, unit="KB"),
        "",
        chart("Core AutoLog stripped executable delta vs baseline", labels, stripped_values, unit="KB"),
        "",
        chart("Core AutoLog __TEXT delta vs baseline", labels, text_values, unit="KB"),
        "",
    ]


def swiftui_delta_chart(
    rows: list[dict[str, str]],
    aliases: dict[str, str],
    grouped: dict[str, dict[str, dict[str, str]]],
) -> list[str]:
    labels: list[str] = []
    values: list[float] = []

    for run_id, _ in run_rows(rows):
        value = delta(grouped, run_id, SWIFTUI_SCENARIO, CORE_SCENARIO, "executable_bytes")
        if value is None:
            continue
        labels.append(aliases[run_id])
        values.append(bytes_to_kb(value))

    return [
        "### SwiftUI Product Increment",
        "",
        chart("AutoLogSwiftUI raw executable delta vs core AutoLog", labels, values, unit="KB"),
        "",
    ]


def latest_run_id(rows: list[dict[str, str]]) -> str:
    return rows[-1]["run_id"]


def latest_policy_chart(
    aliases: dict[str, str],
    grouped: dict[str, dict[str, dict[str, str]]],
    run_id: str,
) -> list[str]:
    labels: list[str] = []
    values: list[float] = []

    for label, scenario in POLICY_SCENARIOS:
        value = delta(grouped, run_id, scenario, CORE_SCENARIO, "executable_bytes")
        if value is None:
            continue
        labels.append(label)
        values.append(bytes_to_kb(value))

    return [
        "### Latest Policy Variant Deltas",
        "",
        chart(
            f"Policy/runtime variant raw delta vs core AutoLog ({aliases[run_id]})",
            labels,
            values,
            unit="KB",
            chart_type="bar",
        ),
        "",
    ]


def latest_failures_chart(
    aliases: dict[str, str],
    grouped: dict[str, dict[str, dict[str, str]]],
    run_id: str,
) -> list[str]:
    labels: list[str] = []
    values: list[float] = []

    for label, scenario, baseline in FAILURES_SCENARIOS:
        value = delta(grouped, run_id, scenario, baseline, "executable_bytes")
        if value is None:
            continue
        labels.append(label)
        values.append(bytes_to_kb(value))

    if not values:
        return []

    return [
        "### Latest Failures-Only Deltas",
        "",
        chart(
            f"Failures-oriented raw executable deltas ({aliases[run_id]})",
            labels,
            values,
            unit="KB",
            chart_type="bar",
        ),
        "",
    ]


def latest_build_chart(
    aliases: dict[str, str],
    grouped: dict[str, dict[str, dict[str, str]]],
    run_id: str,
) -> list[str]:
    labels: list[str] = []
    values: list[float] = []

    for label, scenario in BUILD_SCENARIOS:
        value = number(grouped[run_id].get(scenario), "build_seconds")
        if value is None:
            continue
        labels.append(label)
        values.append(value)

    return [
        "### Latest Clean Build Seconds",
        "",
        chart(f"Clean build seconds ({aliases[run_id]})", labels, values, unit="seconds", chart_type="bar"),
        "",
    ]


def latest_many_callsite_charts(
    aliases: dict[str, str],
    grouped: dict[str, dict[str, dict[str, str]]],
    run_id: str,
) -> list[str]:
    labels: list[str] = []
    raw_values: list[float] = []
    text_values: list[float] = []

    for label, scenario, baseline in MANY_SCENARIOS:
        raw_value = delta(grouped, run_id, scenario, baseline, "executable_bytes")
        text_value = delta(grouped, run_id, scenario, baseline, "text_segment_bytes")
        if raw_value is None or text_value is None:
            continue
        labels.append(label)
        raw_values.append(bytes_to_kb(raw_value))
        text_values.append(bytes_to_kb(text_value))

    if not labels:
        return []

    return [
        "### Latest Many-Call-Site Deltas",
        "",
        chart(
            f"Many-call-site raw executable deltas ({aliases[run_id]})",
            labels,
            raw_values,
            unit="KB",
            chart_type="bar",
        ),
        "",
        chart(
            f"Many-call-site __TEXT deltas ({aliases[run_id]})",
            labels,
            text_values,
            unit="KB",
            chart_type="bar",
        ),
        "",
    ]


def latest_second_build_chart(
    aliases: dict[str, str],
    grouped: dict[str, dict[str, dict[str, str]]],
    run_id: str,
) -> list[str]:
    labels: list[str] = []
    first_values: list[float] = []
    second_values: list[float] = []

    for label, scenario in BUILD_SCENARIOS:
        first = number(grouped[run_id].get(scenario), "build_seconds")
        second = number(grouped[run_id].get(scenario), "second_build_seconds")
        if first is None or second is None:
            continue
        labels.append(label)
        first_values.append(first)
        second_values.append(second)

    if not labels:
        return []

    max_value = max(first_values + second_values)
    upper = max(1, int(max_value * 1.2) + 1)
    label_text = ", ".join(f'"{label}"' for label in labels)
    first_text = ", ".join(f"{value:.2f}" for value in first_values)
    second_text = ", ".join(f"{value:.2f}" for value in second_values)

    return [
        "### Latest First Vs Second Build Seconds",
        "",
        f"""```mermaid
xychart-beta
  title "First vs second build seconds ({aliases[run_id]})"
  x-axis [{label_text}]
  y-axis "seconds" 0 --> {upper}
  line [{first_text}]
  line [{second_text}]
```""",
        "",
    ]


def summary_table(
    rows: list[dict[str, str]],
    aliases: dict[str, str],
    grouped: dict[str, dict[str, dict[str, str]]],
) -> list[str]:
    lines = [
        "## Delta Summary",
        "",
        "| Key | Core raw delta | Core stripped delta | Core `__TEXT` delta | SwiftUI raw increment | AutoLog first build | AutoLog second build |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]

    for run_id, _ in run_rows(rows):
        core_raw = delta(grouped, run_id, CORE_SCENARIO, BASELINE_SCENARIO, "executable_bytes")
        core_stripped = delta(grouped, run_id, CORE_SCENARIO, BASELINE_SCENARIO, "stripped_executable_bytes")
        core_text = delta(grouped, run_id, CORE_SCENARIO, BASELINE_SCENARIO, "text_segment_bytes")
        swiftui_raw = delta(grouped, run_id, SWIFTUI_SCENARIO, CORE_SCENARIO, "executable_bytes")
        build_seconds = number(grouped[run_id].get(CORE_SCENARIO), "build_seconds")
        second_build_seconds = number(grouped[run_id].get(CORE_SCENARIO), "second_build_seconds")
        lines.append(
            "| "
            + " | ".join(
                [
                    aliases[run_id],
                    format_kb(core_raw),
                    format_kb(core_stripped),
                    format_kb(core_text),
                    format_kb(swiftui_raw),
                    format_seconds(build_seconds),
                    format_seconds(second_build_seconds),
                ]
            )
            + " |"
        )

    lines.append("")
    return lines


def format_kb(value: float | None) -> str:
    if value is None:
        return ""
    return f"{bytes_to_kb(value):.1f} KB"


def format_seconds(value: float | None) -> str:
    if value is None:
        return ""
    return f"{value:.3f}s"


def data_table(rows: list[dict[str, str]], aliases: dict[str, str]) -> list[str]:
    lines = [
        "## Data",
        "",
        "| Key | Scenario | Executable | Stripped | `__TEXT` | Linked dylibs | First build | Second build |",
        "|---|---|---:|---:|---:|---:|---:|---:|",
    ]

    for row in rows:
        lines.append(
            "| "
            + " | ".join(
                [
                    aliases[row["run_id"]],
                    row["scenario"],
                    cell(row, "executable_bytes"),
                    cell(row, "stripped_executable_bytes"),
                    cell(row, "text_segment_bytes"),
                    cell(row, "linked_dylib_count"),
                    cell(row, "build_seconds"),
                    cell(row, "second_build_seconds"),
                ]
            )
            + " |"
        )

    lines.append("")
    return lines


def markdown(rows: list[dict[str, str]]) -> str:
    aliases = run_aliases(rows)
    grouped = rows_by_run_and_scenario(rows)
    latest = latest_run_id(rows)

    lines = [
        "# AutoLog Binary And Build Impact History",
        "",
        "This file tracks release-mode fixed-cost impact probes over time.",
        "Compare runs by key first, then inspect the raw data table when a probe",
        "configuration changes.",
        "",
        "## Runs",
        "",
        "| Key | Run | Mode | Commit | Notable change |",
        "|---|---|---|---|---|",
    ]

    for run_id, run_rows_for_id in run_rows(rows):
        first = run_rows_for_id[0]
        lines.append(
            "| "
            + " | ".join(
                [
                    aliases[run_id],
                    first["label"] or run_id,
                    cell(first, "mode"),
                    cell(first, "commit"),
                    cell(first, "notable_change"),
                ]
            )
            + " |"
        )

    lines.extend(["", *summary_table(rows, aliases, grouped)])
    lines.extend(["## Charts", ""])
    lines.extend(core_delta_charts(rows, aliases, grouped))
    lines.extend(swiftui_delta_chart(rows, aliases, grouped))
    lines.extend(latest_policy_chart(aliases, grouped, latest))
    lines.extend(latest_failures_chart(aliases, grouped, latest))
    lines.extend(latest_many_callsite_charts(aliases, grouped, latest))
    lines.extend(latest_build_chart(aliases, grouped, latest))
    lines.extend(latest_second_build_chart(aliases, grouped, latest))
    lines.extend(data_table(rows, aliases))
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
