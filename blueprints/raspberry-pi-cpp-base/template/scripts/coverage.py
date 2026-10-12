#!/usr/bin/env python3
"""Enforce LLVM source coverage for every project production source."""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path
from typing import NoReturn


def fail(message: str) -> NoReturn:
    print(f"coverage failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_threshold(raw: str) -> float:
    try:
        value = float(raw)
    except ValueError:
        fail(f"threshold is not a number: {raw!r}")
    if not math.isfinite(value) or value < 0.0 or value > 100.0:
        fail("threshold must be between 0 and 100")
    return value


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: coverage.py LLVM_COV_EXPORT_JSON THRESHOLD_PERCENT")
    report_path = Path(sys.argv[1]).resolve()
    threshold = parse_threshold(sys.argv[2])
    if not report_path.is_file() or report_path.stat().st_size == 0:
        fail(f"missing or empty report: {report_path}")
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot parse {report_path}: {error}")
    data = report.get("data") if isinstance(report, dict) else None
    if not isinstance(data, list) or len(data) != 1 or not isinstance(data[0], dict):
        fail("expected exactly one llvm-cov export data object")
    files = data[0].get("files")
    if not isinstance(files, list) or not files:
        fail("llvm-cov report contains no files")

    root = Path.cwd().resolve()
    expected = {
        path.resolve() for path in (root / "src").rglob("*")
        if path.is_file() and path.suffix in {".c", ".cc", ".cpp", ".cxx", ".C"}
    }
    if not expected:
        fail("src contains no production C/C++ files")
    covered: dict[Path, dict[str, object]] = {}
    for entry in files:
        if not isinstance(entry, dict) or not isinstance(entry.get("filename"), str):
            fail("invalid file entry in llvm-cov report")
        filename = Path(entry["filename"])
        if not filename.is_absolute():
            filename = root / filename
        filename = filename.resolve()
        if filename in expected or filename.is_relative_to(root / "include"):
            summary = entry.get("summary")
            if not isinstance(summary, dict):
                fail(f"missing summary for {filename}")
            covered[filename] = summary
    missing = sorted(expected - set(covered))
    if missing:
        fail("production sources absent from coverage: " + ", ".join(str(path.relative_to(root)) for path in missing))

    totals = {"lines": [0, 0], "functions": [0, 0], "branches": [0, 0]}
    for filename, summary in covered.items():
        for metric, values in totals.items():
            detail = summary.get(metric)
            if not isinstance(detail, dict):
                fail(f"missing {metric} coverage for {filename.relative_to(root)}")
            count = detail.get("count")
            hit = detail.get("covered")
            if not isinstance(count, int) or not isinstance(hit, int) or count < 0 or hit < 0 or hit > count:
                fail(f"invalid {metric} counts for {filename.relative_to(root)}")
            values[0] += hit
            values[1] += count

    failures: list[str] = []
    for metric, (hit, count) in totals.items():
        if count == 0:
            if metric != "branches":
                fail(f"{metric} denominator is zero; coverage was not measured")
            print(f"{metric}: not applicable (no instrumented {metric})")
            continue
        percent = 100.0 * hit / count
        print(f"{metric}: {hit}/{count} ({percent:.2f}%)")
        if percent + 1e-9 < threshold:
            failures.append(f"{metric} {percent:.2f}% is below {threshold:.2f}%")
    if failures:
        fail("; ".join(failures))
    print(f"coverage passed for {len(covered)} production sources")


if __name__ == "__main__":
    main()
