#!/usr/bin/env python3
"""Append a measure-impact.sh summary.csv to a long-lived impact history."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
from pathlib import Path


FIELDNAMES = [
    "recorded_at",
    "run_id",
    "label",
    "mode",
    "commit",
    "scenario",
    "product",
    "executable_bytes",
    "stripped_executable_bytes",
    "text_segment_bytes",
    "data_const_segment_bytes",
    "data_segment_bytes",
    "linkedit_segment_bytes",
    "linked_dylib_count",
    "build_seconds",
    "notable_change",
]


def timestamp() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def run_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def read_summary(path: Path) -> list[dict[str, str]]:
    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def read_existing(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []

    with path.open(newline="") as handle:
        return list(csv.DictReader(handle))


def write_rows(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDNAMES, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def history_row(
    summary_row: dict[str, str],
    *,
    recorded_at: str,
    run_id_value: str,
    label: str,
    mode: str,
    commit: str,
    notable_change: str,
) -> dict[str, str]:
    return {
        "recorded_at": recorded_at,
        "run_id": run_id_value,
        "label": label,
        "mode": mode,
        "commit": commit,
        "scenario": summary_row["scenario"],
        "product": summary_row["product"],
        "executable_bytes": summary_row["executable_bytes"],
        "stripped_executable_bytes": summary_row["stripped_executable_bytes"],
        "text_segment_bytes": summary_row["text_segment_bytes"],
        "data_const_segment_bytes": summary_row.get("data_const_segment_bytes", ""),
        "data_segment_bytes": summary_row.get("data_segment_bytes", ""),
        "linkedit_segment_bytes": summary_row.get("linkedit_segment_bytes", ""),
        "linked_dylib_count": summary_row["linked_dylib_count"],
        "build_seconds": summary_row["build_seconds"],
        "notable_change": notable_change,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("summary_csv", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--run-id", default=run_id())
    parser.add_argument("--recorded-at", default=timestamp())
    parser.add_argument("--label", default="")
    parser.add_argument("--mode", default="release")
    parser.add_argument("--commit", default="")
    parser.add_argument("--notable-change", default="")
    parser.add_argument("--append", action="store_true")
    parser.add_argument("--replace-run", action="store_true")
    args = parser.parse_args()

    existing_rows = read_existing(args.output)
    if args.replace_run:
        existing_rows = [row for row in existing_rows if row["run_id"] != args.run_id]

    summary_rows = read_summary(args.summary_csv)
    appended_rows = [
        history_row(
            row,
            recorded_at=args.recorded_at,
            run_id_value=args.run_id,
            label=args.label,
            mode=args.mode,
            commit=args.commit,
            notable_change=args.notable_change,
        )
        for row in summary_rows
    ]

    write_rows(args.output, existing_rows + appended_rows)
    print(f"Appended {len(appended_rows)} impact rows to {args.output}")


if __name__ == "__main__":
    main()
