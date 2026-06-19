#!/usr/bin/env python3
"""Render Markdown charts from AutoLog binary/build impact history."""

from __future__ import annotations

import argparse
import csv
import html
from collections import defaultdict
from pathlib import Path


CORE_SCENARIO = "autolog"
BASELINE_SCENARIO = "baseline"
DIRECT_OSLOG_SCENARIO = "direct-oslog"
THROWING_SCENARIO = "autolog-throwing"
SWIFTUI_SCENARIO = "autolog-swiftui"
TEN_PERCENT_BUDGET = 1.10
RED = "#d32f2f"
AMBER = "#f59e0b"
BLUE = "#2563eb"
BAR = "#6d8fb3"
TEXT = "#111827"
MUTED = "#6b7280"
GRID = "#e5e7eb"
BACKGROUND = "#ffffff"
PREVIOUS = "#374151"
POLICY_SCENARIOS = [
    ("failures output", "autolog-failures-only-output"),
    ("type filtered", "autolog-type-filtered-output"),
    ("success emit", "autolog-compile-successes-only"),
    ("failure emit", "autolog-compile-failures-only"),
    ("failure no timing", "autolog-compile-failures-no-measure"),
    ("diagnostics", "autolog-compile-diagnostics"),
]
BUILD_SCENARIOS = [
    ("baseline", "baseline"),
    ("direct OSLog", "direct-oslog"),
    ("AutoLog", "autolog"),
    ("throwing", "autolog-throwing"),
    ("SwiftUI", "autolog-swiftui"),
]
DASHBOARD_SCENARIOS = [
    ("direct OSLog", "direct-oslog"),
    ("AutoLog", "autolog"),
    ("throwing", "autolog-throwing"),
    ("SwiftUI", "autolog-swiftui"),
    ("runtime failures", "autolog-failures-only-output"),
    ("compile failures", "autolog-compile-failures-only"),
    ("failure no timing", "autolog-compile-failures-no-measure"),
    ("diagnostics", "autolog-compile-diagnostics"),
    ("many throwing", "autolog-many-throwing"),
    ("mixed failures", "autolog-mixed-failures-no-measure"),
]
FAILURES_SCENARIOS = [
    ("throwing all", "autolog-throwing", CORE_SCENARIO),
    ("runtime failures", "autolog-failures-only-output", THROWING_SCENARIO),
    ("compile failures", "autolog-compile-failures-only", THROWING_SCENARIO),
    ("compile failures no timing", "autolog-compile-failures-no-measure", THROWING_SCENARIO),
    ("diagnostics", "autolog-compile-diagnostics", THROWING_SCENARIO),
]
MANY_SCENARIOS = [
    ("many throwing", "autolog-many-throwing", THROWING_SCENARIO),
    (
        "many compile failures",
        "autolog-many-compile-failures-only",
        "autolog-many-throwing",
    ),
    (
        "mixed failures no timing",
        "autolog-mixed-failures-no-measure",
        "autolog-many-compile-failures-only",
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


def xml(value: str) -> str:
    return html.escape(value, quote=True)


def svg_number(value: float) -> str:
    if abs(value) >= 100:
        return f"{value:.0f}"
    if abs(value) >= 10:
        return f"{value:.1f}"
    return f"{value:.2f}"


def nice_unit(value: float, unit: str) -> str:
    return f"{svg_number(value)} {unit}".strip()


def write_bar_svg(
    path: Path,
    *,
    title: str,
    labels: list[str],
    values: list[float],
    unit: str,
    references: list[tuple[str, float, str]],
    previous_values: list[float | None] | None = None,
) -> None:
    if not labels or not values:
        return

    previous_values = previous_values or [None] * len(values)
    reference_values = [value for _, value, _ in references]
    previous_numeric = [value for value in previous_values if value is not None]
    max_value = max(values + reference_values + previous_numeric + [1])
    y_max = max_value * 1.15
    if y_max <= 0:
        y_max = 1

    width = max(860, 120 + len(labels) * 96)
    height = 500
    left = 78
    right = 36
    top = 76
    plot_height = 270
    plot_width = width - left - right
    bottom = top + plot_height
    slot = plot_width / len(labels)
    bar_width = min(48, slot * 0.54)

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
        parts.append(f'<text x="{legend_x + 30}" y="{legend_y + 4}" fill="{TEXT}" font-size="12" font-family="Inter, ui-sans-serif, system-ui">{xml(name)} {xml(nice_unit(value, unit))}</text>')
        legend_x += 178
    parts.append(f'<line x1="{legend_x}" x2="{legend_x + 24}" y1="{legend_y}" y2="{legend_y}" stroke="{PREVIOUS}" stroke-width="3"/>')
    parts.append(f'<text x="{legend_x + 30}" y="{legend_y + 4}" fill="{TEXT}" font-size="12" font-family="Inter, ui-sans-serif, system-ui">previous implementation</text>')

    tick_count = 5
    for tick in range(tick_count + 1):
        value = y_max * tick / tick_count
        yy = y(value)
        parts.append(f'<line x1="{left}" x2="{width - right}" y1="{yy:.1f}" y2="{yy:.1f}" stroke="{GRID}" stroke-width="1"/>')
        parts.append(f'<text x="{left - 10}" y="{yy + 4:.1f}" text-anchor="end" fill="{MUTED}" font-size="11" font-family="Inter, ui-sans-serif, system-ui">{xml(svg_number(value))}</text>')

    baseline_reference = next((value for name, value, _ in references if "baseline" in name.lower()), None)
    budget_reference = next((value for name, value, _ in references if "10%" in name), None)
    if baseline_reference is not None and budget_reference is not None:
        y1 = min(y(baseline_reference), y(budget_reference))
        y2 = max(y(baseline_reference), y(budget_reference))
        parts.append(f'<rect x="{left}" y="{y1:.1f}" width="{plot_width}" height="{max(1, y2 - y1):.1f}" fill="{AMBER}" opacity="0.12"/>')

    for name, value, color in references:
        yy = y(value)
        dash = ' stroke-dasharray="6 5"' if "10%" in name or "direct" in name.lower() else ""
        parts.append(f'<line x1="{left}" x2="{width - right}" y1="{yy:.1f}" y2="{yy:.1f}" stroke="{color}" stroke-width="2.5"{dash}/>')

    for index, (label, value) in enumerate(zip(labels, values)):
        center = left + slot * index + slot / 2
        yy = y(value)
        height_value = max(1, bottom - yy)
        parts.append(f'<rect x="{center - bar_width / 2:.1f}" y="{yy:.1f}" width="{bar_width:.1f}" height="{height_value:.1f}" rx="4" fill="{BAR}"/>')
        parts.append(f'<text x="{center:.1f}" y="{yy - 7:.1f}" text-anchor="middle" fill="{TEXT}" font-size="11" font-family="Inter, ui-sans-serif, system-ui">{xml(nice_unit(value, unit))}</text>')
        previous = previous_values[index]
        if previous is not None:
            py = y(previous)
            parts.append(f'<line x1="{center - bar_width * 0.65:.1f}" x2="{center + bar_width * 0.65:.1f}" y1="{py:.1f}" y2="{py:.1f}" stroke="{PREVIOUS}" stroke-width="3"/>')
        parts.append(f'<text x="{center:.1f}" y="{bottom + 48:.1f}" text-anchor="end" transform="rotate(-35 {center:.1f} {bottom + 48:.1f})" fill="{TEXT}" font-size="11" font-family="Inter, ui-sans-serif, system-ui">{xml(label)}</text>')

    axis_label = f"{unit}"
    parts.append(f'<line x1="{left}" x2="{left}" y1="{top}" y2="{bottom}" stroke="{MUTED}" stroke-width="1"/>')
    parts.append(f'<line x1="{left}" x2="{width - right}" y1="{bottom}" y2="{bottom}" stroke="{MUTED}" stroke-width="1"/>')
    parts.append(f'<text x="{left}" y="{height - 22}" fill="{MUTED}" font-size="12" font-family="Inter, ui-sans-serif, system-ui">Red = no-logging baseline. Amber band/line = +10% budget. Blue = direct OSLog reference. Gray tick = previous implementation.</text>')
    parts.append(f'<text x="{left}" y="{top - 22}" fill="{MUTED}" font-size="12" font-family="Inter, ui-sans-serif, system-ui">{xml(axis_label)}</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts) + "\n")


def previous_run_id(rows: list[dict[str, str]], run_id: str) -> str | None:
    run_ids = [candidate for candidate, _ in run_rows(rows)]
    try:
        index = run_ids.index(run_id)
    except ValueError:
        return None
    if index == 0:
        return None
    return run_ids[index - 1]


def percent_over(value: float | None, baseline: float | None) -> float | None:
    if value is None or baseline in (None, 0):
        return None
    return ((value - baseline) / baseline) * 100


def format_delta(value: float | None, formatter) -> str:
    if value is None:
        return ""
    prefix = "+" if value > 0 else ""
    return f"{prefix}{formatter(value)}"


def format_percent(value: float | None) -> str:
    if value is None:
        return ""
    return f"{value:+.1f}%"


def budget_status(value: float | None, baseline: float | None) -> str:
    if value is None or baseline in (None, 0):
        return ""
    return "ok" if value <= baseline * TEN_PERCENT_BUDGET else "over"


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


def latest_reference_table(
    aliases: dict[str, str],
    grouped: dict[str, dict[str, dict[str, str]]],
    latest: str,
    previous: str | None,
    *,
    field: str,
    title: str,
    value_formatter,
) -> list[str]:
    baseline = number(grouped[latest].get(BASELINE_SCENARIO), field)
    direct = number(grouped[latest].get(DIRECT_OSLOG_SCENARIO), field)
    lines = [
        f"### {title}",
        "",
        "| Scenario | Latest | vs no logging | vs direct OSLog | vs previous implementation | Impact vs no logging | 10% budget |",
        "|---|---:|---:|---:|---:|---:|---|",
    ]

    for label, scenario in DASHBOARD_SCENARIOS:
        latest_value = number(grouped[latest].get(scenario), field)
        if latest_value is None:
            continue
        previous_value = number(grouped[previous].get(scenario), field) if previous else None
        lines.append(
            "| "
            + " | ".join(
                [
                    label,
                    value_formatter(latest_value),
                    format_delta(latest_value - baseline, value_formatter) if baseline is not None else "",
                    format_delta(latest_value - direct, value_formatter) if direct is not None else "",
                    format_delta(latest_value - previous_value, value_formatter) if previous_value is not None else "",
                    format_percent(percent_over(latest_value, baseline)),
                    budget_status(latest_value, baseline),
                ]
            )
            + " |"
        )

    lines.append("")
    return lines


def latest_dashboard_charts(
    output: Path,
    aliases: dict[str, str],
    grouped: dict[str, dict[str, dict[str, str]]],
    latest: str,
    previous: str | None,
) -> list[str]:
    asset_dir = output.parent / "assets"
    asset_dir.mkdir(parents=True, exist_ok=True)

    def chart_for_field(
        *,
        filename: str,
        title: str,
        field: str,
        unit: str,
        scenarios: list[tuple[str, str]],
        scale: float = 1,
    ) -> str | None:
        baseline = number(grouped[latest].get(BASELINE_SCENARIO), field)
        direct = number(grouped[latest].get(DIRECT_OSLOG_SCENARIO), field)
        if baseline is None:
            return None

        labels: list[str] = []
        values: list[float] = []
        previous_values: list[float | None] = []
        for label, scenario in scenarios:
            latest_value = number(grouped[latest].get(scenario), field)
            if latest_value is None:
                continue
            labels.append(label)
            values.append(latest_value / scale)
            previous_value = number(grouped[previous].get(scenario), field) if previous else None
            previous_values.append(previous_value / scale if previous_value is not None else None)

        if not values:
            return None

        references = [
            ("baseline", baseline / scale, RED),
            ("10% budget", (baseline * TEN_PERCENT_BUDGET) / scale, AMBER),
        ]
        if direct is not None:
            references.append(("direct OSLog", direct / scale, BLUE))

        path = asset_dir / filename
        write_bar_svg(
            path,
            title=title,
            labels=labels,
            values=values,
            unit=unit,
            references=references,
            previous_values=previous_values,
        )
        return f"![{title}](assets/{filename})"

    executable_chart = chart_for_field(
        filename="impact-latest-raw-executable.svg",
        title=f"Latest raw executable size vs baseline ({aliases[latest]})",
        field="executable_bytes",
        unit="KB",
        scenarios=DASHBOARD_SCENARIOS,
        scale=1000,
    )
    first_build_chart = chart_for_field(
        filename="impact-latest-first-build.svg",
        title=f"Latest first build seconds vs baseline ({aliases[latest]})",
        field="build_seconds",
        unit="seconds",
        scenarios=BUILD_SCENARIOS[1:],
    )
    second_build_chart = chart_for_field(
        filename="impact-latest-second-build.svg",
        title=f"Latest second build seconds vs baseline ({aliases[latest]})",
        field="second_build_seconds",
        unit="seconds",
        scenarios=BUILD_SCENARIOS[1:],
    )

    lines = [
        "## Comparison Dashboard",
        "",
        "Use this section first. Red is the no-logging baseline, amber is the",
        "`+10%` budget over that baseline, blue is direct `OSLog.Logger`, and the",
        "gray tick on each bar is the previous implementation for the same",
        "scenario when that scenario existed in the prior run.",
        "",
    ]
    for chart_markup in [executable_chart, first_build_chart, second_build_chart]:
        if chart_markup:
            lines.extend([chart_markup, ""])

    lines.extend(
        latest_reference_table(
            aliases,
            grouped,
            latest,
            previous,
            field="executable_bytes",
            title="Latest Raw Executable Comparison",
            value_formatter=format_bytes,
        )
    )
    lines.extend(
        latest_reference_table(
            aliases,
            grouped,
            latest,
            previous,
            field="build_seconds",
            title="Latest First Build Comparison",
            value_formatter=format_seconds,
        )
    )
    lines.extend(
        latest_reference_table(
            aliases,
            grouped,
            latest,
            previous,
            field="second_build_seconds",
            title="Latest Second Build Comparison",
            value_formatter=format_seconds,
        )
    )
    return lines


def format_bytes(value: float | None) -> str:
    if value is None:
        return ""
    return f"{value:,.0f} B"


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


def markdown(rows: list[dict[str, str]], output: Path) -> str:
    aliases = run_aliases(rows)
    grouped = rows_by_run_and_scenario(rows)
    latest = latest_run_id(rows)
    previous = previous_run_id(rows, latest)

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

    lines.extend(["", *latest_dashboard_charts(output, aliases, grouped, latest, previous)])
    lines.extend(summary_table(rows, aliases, grouped))
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
    args.output.write_text(markdown(read_rows(args.csv), args.output))
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
