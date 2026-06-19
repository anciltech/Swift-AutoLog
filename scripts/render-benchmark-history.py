#!/usr/bin/env python3
"""Render a small Markdown report from AutoLog benchmark history CSV."""

from __future__ import annotations

import argparse
import csv
import html
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

HIGH_RSD_PERCENT = 20.0
TEN_PERCENT_SLOWDOWN = 1.10
RED = "#d32f2f"
AMBER = "#f59e0b"
BLUE = "#2563eb"
BAR = "#6d8fb3"
TEXT = "#111827"
MUTED = "#6b7280"
GRID = "#e5e7eb"
BACKGROUND = "#ffffff"
PREVIOUS = "#374151"

SIMPLE_DASHBOARD_SCENARIOS = [
    ("direct OSLog simple", "Direct OSLog"),
    ("benchmark logger", "Logged without tags"),
    ("normal logger", "Logged without tags (normal logger)"),
    ("routing tags", "Logged with routing tags"),
    ("visible tags", "Logged with visible tags"),
    ("mixed tags", "Logged with mixed tags"),
]
COMPLEX_DASHBOARD_SCENARIOS = [
    ("direct OSLog complex", "Direct OSLog complex"),
    ("AutoLog normal", "AutoLog complex (normal logger)"),
]
TASK_GROUP_DASHBOARD_SCENARIOS = [
    ("logged task group", "Logged task group"),
]


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def run_label(row: dict[str, str]) -> str:
    return row["label"] or row["run_id"]


def cell(row: dict[str, str], key: str) -> str:
    return row.get(key) or ""


def rsd(row: dict[str, str]) -> float | None:
    value = cell(row, "rsd_percent")
    return float(value) if value else None


def signal(row: dict[str, str]) -> str:
    value = rsd(row)
    if value is None:
        return "legacy/no RSD"
    if value > HIGH_RSD_PERCENT:
        return "high variance"
    return "ok"


def run_aliases(rows: list[dict[str, str]]) -> dict[str, str]:
    aliases: dict[str, str] = {}
    for row in rows:
        run_id = row["run_id"]
        if run_id not in aliases:
            aliases[run_id] = f"R{len(aliases) + 1}"
    return aliases


def latest_normal_row(rows: list[dict[str, str]], scenario: str) -> dict[str, str] | None:
    return latest_row(rows, scenario, load_contains="normal-load") or latest_row(rows, scenario)


def reference_rows(rows: list[dict[str, str]], scenario: str) -> list[tuple[str, dict[str, str]]]:
    if scenario == "Logged task group":
        baseline = latest_normal_row(rows, "Baseline task group")
        return [("no logging", baseline)] if baseline else []

    if "complex" in scenario.lower():
        baseline = latest_normal_row(rows, "Baseline complex")
        oslog = latest_normal_row(rows, "Direct OSLog complex")
    else:
        baseline = latest_normal_row(rows, "Baseline")
        oslog = latest_normal_row(rows, "Direct OSLog")

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
        f"{name} {aliases[row['run_id']]}={float(row['overhead_us']):.2f}us"
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


def xml(value: str) -> str:
    return html.escape(value, quote=True)


def svg_number(value: float) -> str:
    if abs(value) >= 100:
        return f"{value:.0f}"
    if abs(value) >= 10:
        return f"{value:.1f}"
    return f"{value:.2f}"


def write_bar_svg(
    path: Path,
    *,
    title: str,
    labels: list[str],
    values: list[float],
    references: list[tuple[str, float, str]],
    previous_values: list[float | None] | None = None,
) -> None:
    if not labels or not values:
        return

    previous_values = previous_values or [None] * len(values)
    previous_numeric = [value for value in previous_values if value is not None]
    max_value = max(values + [value for _, value, _ in references] + previous_numeric + [TEN_PERCENT_SLOWDOWN])
    y_max = max_value * 1.15
    width = max(760, 140 + len(labels) * 108)
    height = 500
    left = 76
    right = 34
    top = 76
    plot_height = 270
    plot_width = width - left - right
    bottom = top + plot_height
    slot = plot_width / len(labels)
    bar_width = min(50, slot * 0.54)

    def y(value: float) -> float:
        return bottom - (value / y_max) * plot_height

    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f'<rect width="{width}" height="{height}" fill="{BACKGROUND}"/>',
        f'<text x="{left}" y="34" fill="{TEXT}" font-family="Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, sans-serif" font-size="20" font-weight="700">{xml(title)}</text>',
    ]
    legend_x = left
    legend_y = 56
    for name, value, color in references:
        dash = ' stroke-dasharray="6 5"' if "10%" in name or "direct" in name.lower() else ""
        parts.append(f'<line x1="{legend_x}" x2="{legend_x + 24}" y1="{legend_y}" y2="{legend_y}" stroke="{color}" stroke-width="3"{dash}/>')
        parts.append(f'<text x="{legend_x + 30}" y="{legend_y + 4}" fill="{TEXT}" font-size="12" font-family="Inter, ui-sans-serif, system-ui">{xml(name)} {xml(svg_number(value))}x</text>')
        legend_x += 168
    parts.append(f'<line x1="{legend_x}" x2="{legend_x + 24}" y1="{legend_y}" y2="{legend_y}" stroke="{PREVIOUS}" stroke-width="3"/>')
    parts.append(f'<text x="{legend_x + 30}" y="{legend_y + 4}" fill="{TEXT}" font-size="12" font-family="Inter, ui-sans-serif, system-ui">previous implementation</text>')

    for tick in range(6):
        value = y_max * tick / 5
        yy = y(value)
        parts.append(f'<line x1="{left}" x2="{width - right}" y1="{yy:.1f}" y2="{yy:.1f}" stroke="{GRID}" stroke-width="1"/>')
        parts.append(f'<text x="{left - 10}" y="{yy + 4:.1f}" text-anchor="end" fill="{MUTED}" font-size="11" font-family="Inter, ui-sans-serif, system-ui">{xml(svg_number(value))}x</text>')

    baseline = next((value for name, value, _ in references if "baseline" in name.lower()), None)
    budget = next((value for name, value, _ in references if "10%" in name), None)
    if baseline is not None and budget is not None:
        y1 = min(y(baseline), y(budget))
        y2 = max(y(baseline), y(budget))
        parts.append(f'<rect x="{left}" y="{y1:.1f}" width="{plot_width}" height="{max(1, y2 - y1):.1f}" fill="{AMBER}" opacity="0.12"/>')

    for name, value, color in references:
        yy = y(value)
        dash = ' stroke-dasharray="6 5"' if "10%" in name or "direct" in name.lower() else ""
        parts.append(f'<line x1="{left}" x2="{width - right}" y1="{yy:.1f}" y2="{yy:.1f}" stroke="{color}" stroke-width="2.5"{dash}/>')

    for index, (label, value) in enumerate(zip(labels, values)):
        center = left + slot * index + slot / 2
        yy = y(value)
        parts.append(f'<rect x="{center - bar_width / 2:.1f}" y="{yy:.1f}" width="{bar_width:.1f}" height="{max(1, bottom - yy):.1f}" rx="4" fill="{BAR}"/>')
        parts.append(f'<text x="{center:.1f}" y="{yy - 7:.1f}" text-anchor="middle" fill="{TEXT}" font-size="11" font-family="Inter, ui-sans-serif, system-ui">{xml(svg_number(value))}x</text>')
        previous = previous_values[index]
        if previous is not None:
            py = y(previous)
            parts.append(f'<line x1="{center - bar_width * 0.65:.1f}" x2="{center + bar_width * 0.65:.1f}" y1="{py:.1f}" y2="{py:.1f}" stroke="{PREVIOUS}" stroke-width="3"/>')
        parts.append(f'<text x="{center:.1f}" y="{bottom + 48:.1f}" text-anchor="end" transform="rotate(-35 {center:.1f} {bottom + 48:.1f})" fill="{TEXT}" font-size="11" font-family="Inter, ui-sans-serif, system-ui">{xml(label)}</text>')

    parts.append(f'<line x1="{left}" x2="{left}" y1="{top}" y2="{bottom}" stroke="{MUTED}" stroke-width="1"/>')
    parts.append(f'<line x1="{left}" x2="{width - right}" y1="{bottom}" y2="{bottom}" stroke="{MUTED}" stroke-width="1"/>')
    parts.append(f'<text x="{left}" y="{height - 22}" fill="{MUTED}" font-size="12" font-family="Inter, ui-sans-serif, system-ui">Red = no-logging baseline. Amber band/line = +10% budget. Blue = direct OSLog reference. Gray tick = previous implementation.</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts) + "\n")


def previous_normal_row(rows: list[dict[str, str]], current: dict[str, str]) -> dict[str, str] | None:
    matches = [
        row for row in rows
        if row["scenario"] == current["scenario"]
        and "normal-load" in row["load_profile"]
        and row is not current
    ]
    previous_rows = [row for row in matches if row["run_id"] != current["run_id"]]
    return previous_rows[-1] if previous_rows else None


def slowdown(row: dict[str, str] | None) -> float | None:
    if row is None:
        return None
    value = cell(row, "slowdown_x")
    return float(value) if value else None


def format_delta_us(value: float | None) -> str:
    if value is None:
        return ""
    prefix = "+" if value > 0 else ""
    return f"{prefix}{value:.3f}"


def format_slowdown(value: float | None) -> str:
    if value is None:
        return ""
    return f"{value:.2f}x"


def format_impact_percent(value: float | None) -> str:
    if value is None:
        return ""
    return f"{(value - 1) * 100:+.1f}%"


def runtime_budget_status(value: float | None) -> str:
    if value is None:
        return ""
    return "ok" if value <= TEN_PERCENT_SLOWDOWN else "over"


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
    return (
        f"| {profile} | {row['run_id']} | {overhead:.3f} | "
        f"{cell(row, 'rsd_percent')} | {signal(row)} | {delta:+.3f} |"
    )


def runtime_dashboard_chart(
    output: Path,
    rows: list[dict[str, str]],
    *,
    title: str,
    filename: str,
    scenarios: list[tuple[str, str]],
    direct_scenario: str | None,
) -> str | None:
    asset_dir = output.parent / "assets"
    asset_dir.mkdir(parents=True, exist_ok=True)

    labels: list[str] = []
    values: list[float] = []
    previous_values: list[float | None] = []
    for label, scenario in scenarios:
        row = latest_normal_row(rows, scenario)
        row_slowdown = slowdown(row)
        if row is None or row_slowdown is None:
            continue
        labels.append(label)
        values.append(row_slowdown)
        previous_values.append(slowdown(previous_normal_row(rows, row)))

    if not values:
        return None

    references = [
        ("baseline", 1.0, RED),
        ("10% budget", TEN_PERCENT_SLOWDOWN, AMBER),
    ]
    if direct_scenario is not None:
        direct = slowdown(latest_normal_row(rows, direct_scenario))
        if direct is not None:
            references.append(("direct OSLog", direct, BLUE))

    path = asset_dir / filename
    write_bar_svg(
        path,
        title=title,
        labels=labels,
        values=values,
        references=references,
        previous_values=previous_values,
    )
    return f"![{title}](assets/{filename})"


def runtime_dashboard_table(rows: list[dict[str, str]]) -> list[str]:
    scenarios = [
        *SIMPLE_DASHBOARD_SCENARIOS,
        *COMPLEX_DASHBOARD_SCENARIOS,
        *TASK_GROUP_DASHBOARD_SCENARIOS,
    ]
    lines = [
        "### Latest Runtime Comparison",
        "",
        "| Scenario | Slowdown vs no logging | Impact vs no logging | Overhead (us) | Delta vs direct OSLog (us) | Delta vs previous implementation (us) | RSD (%) | 10% budget |",
        "|---|---:|---:|---:|---:|---:|---:|---|",
    ]

    for label, scenario in scenarios:
        row = latest_normal_row(rows, scenario)
        if row is None:
            continue
        row_slowdown = slowdown(row)
        overhead = float(cell(row, "overhead_us") or 0)
        if scenario == "Logged task group":
            direct = None
        elif "complex" in scenario.lower():
            direct = latest_normal_row(rows, "Direct OSLog complex")
        else:
            direct = latest_normal_row(rows, "Direct OSLog")
        direct_overhead = float(cell(direct, "overhead_us") or 0) if direct else None
        previous = previous_normal_row(rows, row)
        previous_overhead = float(cell(previous, "overhead_us") or 0) if previous else None
        lines.append(
            "| "
            + " | ".join(
                [
                    label,
                    format_slowdown(row_slowdown),
                    format_impact_percent(row_slowdown),
                    f"{overhead:.3f}",
                    format_delta_us(overhead - direct_overhead) if direct_overhead is not None else "",
                    format_delta_us(overhead - previous_overhead) if previous_overhead is not None else "",
                    cell(row, "rsd_percent"),
                    runtime_budget_status(row_slowdown),
                ]
            )
            + " |"
        )

    lines.append("")
    return lines


def runtime_dashboard(rows: list[dict[str, str]], output: Path) -> list[str]:
    lines = [
        "## Comparison Dashboard",
        "",
        "Use this section first. Red is the matching no-logging baseline, amber",
        "is the `+10%` slowdown budget, blue is the matching direct",
        "`OSLog.Logger` reference, and the gray tick on each bar is the previous",
        "normal-load implementation for the same scenario.",
        "",
    ]

    for chart in [
        runtime_dashboard_chart(
            output,
            rows,
            title="Latest simple-control slowdown vs no logging",
            filename="benchmark-latest-simple-slowdown.svg",
            scenarios=SIMPLE_DASHBOARD_SCENARIOS,
            direct_scenario="Direct OSLog",
        ),
        runtime_dashboard_chart(
            output,
            rows,
            title="Latest complex-control slowdown vs no logging",
            filename="benchmark-latest-complex-slowdown.svg",
            scenarios=COMPLEX_DASHBOARD_SCENARIOS,
            direct_scenario="Direct OSLog complex",
        ),
        runtime_dashboard_chart(
            output,
            rows,
            title="Latest task-group slowdown vs no logging",
            filename="benchmark-latest-task-group-slowdown.svg",
            scenarios=TASK_GROUP_DASHBOARD_SCENARIOS,
            direct_scenario=None,
        ),
    ]:
        if chart:
            lines.extend([chart, ""])

    lines.extend(runtime_dashboard_table(rows))
    return lines


def logger_profile_comparison(rows: list[dict[str, str]]) -> list[str]:
    benchmark_rows = [
        row for row in rows
        if row["scenario"] == "Logged without tags"
        and "benchmark-logger" in row["load_profile"]
        and "normal-load" in row["load_profile"]
    ]
    simple_baseline = latest_normal_row(rows, "Baseline")
    simple_oslog = latest_normal_row(rows, "Direct OSLog")
    simple_autolog = latest_normal_row(rows, "Logged without tags (normal logger)")
    complex_baseline = latest_normal_row(rows, "Baseline complex")
    complex_oslog = latest_normal_row(rows, "Direct OSLog complex")
    complex_autolog = latest_normal_row(rows, "AutoLog complex (normal logger)")

    lines = [
        "## Logging Profile Comparison",
        "",
        "These tables compare no logging, direct `OSLog.Logger`, and the",
        "default `AutoLogLogger` path. The benchmark logger remains useful for",
        "isolating formatter/routing work, but the normal logger rows are the",
        "real-world baseline. These comparisons use the latest normal-load rows",
        "so stress-run data does not replace the stable baseline.",
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
            "| Profile | Run | Overhead (us) | RSD (%) | Signal | Delta vs no logging |",
            "|---|---|---:|---:|---|---:|",
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
            "| Profile | Run | Overhead (us) | RSD (%) | Signal | Delta vs no logging |",
            "|---|---|---:|---:|---|---:|",
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
            "| Profile | Run | Overhead (us) | RSD (%) | Signal | Delta vs benchmark logger |",
            "|---|---|---:|---:|---|---:|",
            f"| Benchmark logger | {benchmark['run_id']} | {benchmark_overhead:.3f} | {cell(benchmark, 'rsd_percent')} | {signal(benchmark)} | 0.000 |",
            f"| Normal AutoLogLogger | {normal['run_id']} | {normal_overhead:.3f} | {cell(normal, 'rsd_percent')} | {signal(normal)} | {delta:+.3f} ({multiplier:.2f}x) |",
            "",
        ])

    return lines


def signal_notes(rows: list[dict[str, str]], aliases: dict[str, str]) -> list[str]:
    high_variance_rows = [row for row in rows if signal(row) == "high variance"]
    missing_rsd_runs = sorted({
        aliases[row["run_id"]]
        for row in rows
        if rsd(row) is None
    })

    lines = [
        "## Signal Notes",
        "",
        f"Rows above `{HIGH_RSD_PERCENT:.0f}%` RSD are high variance and should be rerun before treating them as regressions.",
    ]
    if missing_rsd_runs:
        lines.append(
            "Legacy runs without RSD are directional only: "
            + ", ".join(missing_rsd_runs)
            + "."
        )
    lines.append("")

    if high_variance_rows:
        lines.extend([
            "| Key | Scenario | Overhead (us) | RSD (%) | Suggested read |",
            "|---|---|---:|---:|---|",
        ])
        for row in high_variance_rows:
            lines.append(
                "| "
                + " | ".join(
                    [
                        aliases[row["run_id"]],
                        cell(row, "scenario"),
                        cell(row, "overhead_us"),
                        cell(row, "rsd_percent"),
                        "repeat before regression call",
                    ]
                )
                + " |"
            )
        lines.append("")

    return lines


def markdown(rows: list[dict[str, str]], output: Path) -> str:
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

    lines.extend(["", *runtime_dashboard(rows, output)])
    lines.extend(signal_notes(rows, aliases))

    lines.extend([
        "## Charts",
        "",
        "Each chart uses short run keys from the table above to keep labels readable.",
        "The first line is the scenario. Additional horizontal lines are references:",
        "`no logging` and, when available, direct `OSLog.Logger`. Reference",
        "labels include the run key that supplied the value.",
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
            "| Run | Scenario | Average (s) | Added (s) | Overhead (us) | RSD (%) | Signal |",
            "|---|---|---:|---:|---:|---:|---|",
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
                    signal(row),
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
    args.output.write_text(markdown(read_rows(args.csv), args.output))
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
