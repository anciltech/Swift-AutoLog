#!/usr/bin/env python3
"""Extract AutoLogPerformanceTests summary rows into CSV."""

from __future__ import annotations

import argparse
import csv
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path


FIELDNAMES = [
    "recorded_at",
    "run_id",
    "label",
    "mode",
    "load_profile",
    "commit",
    "scenario",
    "family",
    "average_s",
    "added_s",
    "slowdown_x",
    "overhead_us",
    "rsd_percent",
    "notable_change",
]


def parse_seconds(value: str) -> float:
    return float(value.removesuffix("s"))


def parse_signed_seconds(value: str) -> float:
    return float(value.removesuffix("s"))


def parse_multiplier(value: str) -> float:
    return float(value.removesuffix("x"))


def parse_overhead(value: str) -> float:
    value = value.replace("\u00b5", "u")
    return float(value.removesuffix("us"))


def parse_percent(value: str) -> float:
    return float(value.removesuffix("%"))


def current_commit() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return ""


def parse_rows(text: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    in_table = False

    for line in text.splitlines():
        if line.startswith("Scenario") and "Overhead/call" in line:
            in_table = True
            continue

        if not in_table:
            continue

        if not line.strip() or set(line.strip()) <= {"-"}:
            continue

        parts = [part.strip() for part in line.split("|")]
        if len(parts) < 7:
            continue

        scenario, family, average, added, slowdown, overhead, rsd = parts[:7]
        if not re.search(r"\d", average):
            continue

        rows.append(
            {
                "scenario": scenario,
                "family": family,
                "average_s": f"{parse_seconds(average):.6f}",
                "added_s": f"{parse_signed_seconds(added):.6f}",
                "slowdown_x": f"{parse_multiplier(slowdown):.3f}",
                "overhead_us": f"{parse_overhead(overhead):.3f}",
                "rsd_percent": f"{parse_percent(rsd):.3f}",
            }
        )

    return rows


def write_csv(path: Path, rows: list[dict[str, str]], append: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    exists = path.exists() and path.stat().st_size > 0
    mode = "a" if append else "w"

    with path.open(mode, newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDNAMES)
        if not append or not exists:
            writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--append", action="store_true")
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--label", default="")
    parser.add_argument("--mode", default="release")
    parser.add_argument("--load-profile", default="normal")
    parser.add_argument("--commit", default=current_commit())
    parser.add_argument("--notable-change", default="")
    args = parser.parse_args()

    rows = parse_rows(args.log.read_text())
    recorded_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    for row in rows:
        row.update(
            {
                "recorded_at": recorded_at,
                "run_id": args.run_id,
                "label": args.label,
                "mode": args.mode,
                "load_profile": args.load_profile,
                "commit": args.commit,
                "notable_change": args.notable_change,
            }
        )

    write_csv(args.output, rows, append=args.append)
    print(f"Wrote {len(rows)} rows to {args.output}")


if __name__ == "__main__":
    main()
