#!/usr/bin/env python3
"""Validate that a CTest JUnit report exists and represents a complete passing run."""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import NoReturn


def fail(message: str) -> NoReturn:
    print(f"test report failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: check-test-report.py CTEST_JUNIT_XML")
    report = Path(sys.argv[1])
    if not report.is_file() or report.stat().st_size == 0:
        fail(f"missing or empty report: {report}")
    try:
        root = ET.parse(report).getroot()
    except (OSError, ET.ParseError) as error:
        fail(f"cannot parse {report}: {error}")
    if root.tag not in {"testsuite", "testsuites"}:
        fail(f"unexpected root element {root.tag!r}")

    cases = root.findall(".//testcase")
    if not cases:
        fail("the report contains no discovered tests")
    suites = [root] if root.tag == "testsuite" else root.findall("./testsuite")
    if not suites:
        fail("the report contains no test suites")
    for suite in suites:
        for attribute in ("failures", "errors", "skipped", "disabled"):
            raw_count = suite.attrib.get(attribute, "0")
            try:
                count = int(raw_count)
            except ValueError:
                fail(f"invalid {attribute} count {raw_count!r}")
            if count != 0:
                fail(f"suite declares {attribute}={count}")
    failed = [case for case in cases if case.find("failure") is not None]
    errored = [case for case in cases if case.find("error") is not None]
    skipped = [case for case in cases if case.find("skipped") is not None]
    if failed or errored or skipped:
        fail(
            f"report has failures={len(failed)}, errors={len(errored)}, "
            f"skipped={len(skipped)}"
        )
    declared_tests = root.attrib.get("tests")
    if declared_tests is None:
        fail("the report does not declare a tests count")
    try:
        declared_count = int(declared_tests)
    except ValueError:
        fail(f"invalid tests count {declared_tests!r}")
    if declared_count != len(cases):
        fail(f"declared {declared_count} tests but found {len(cases)} test cases")
    print(f"test report passed: {len(cases)} tests, no failures, errors, or skips")


if __name__ == "__main__":
    main()
