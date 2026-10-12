#!/usr/bin/env python3
"""Focused regression tests for the project validation scripts."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS = Path(__file__).resolve().parent


class CheckerTests(unittest.TestCase):
    def run_checker(
        self, script: str, *arguments: str, cwd: Path | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPTS / script), *arguments],
            cwd=cwd,
            check=False,
            capture_output=True,
            text=True,
        )

    def test_source_inventory_rejects_an_uncompiled_test(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "src/domain").mkdir(parents=True)
            (root / "tests").mkdir()
            (root / "build").mkdir()
            source = root / "src/domain/value.cpp"
            source.write_text("int value() { return 1; }\n", encoding="utf-8")
            (root / "tests/value_test.cpp").write_text("int test_value;\n", encoding="utf-8")
            database = [{"directory": str(root), "file": str(source), "arguments": ["c++", "-c", str(source)]}]
            path = root / "build/compile_commands.json"
            path.write_text(json.dumps(database), encoding="utf-8")
            result = self.run_checker("check-source-inventory.py", str(path))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("uncompiled source files", result.stderr)

    def test_test_report_rejects_empty_and_skipped_suites(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            empty = root / "empty.xml"
            empty.write_text('<testsuite tests="0"/>', encoding="utf-8")
            self.assertNotEqual(self.run_checker("check-test-report.py", str(empty)).returncode, 0)
            skipped = root / "skipped.xml"
            skipped.write_text(
                '<testsuite tests="1"><testcase name="x"><skipped/></testcase></testsuite>',
                encoding="utf-8",
            )
            result = self.run_checker("check-test-report.py", str(skipped))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("skipped=1", result.stderr)

    def test_coverage_rejects_malformed_and_below_threshold_reports(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "src/domain").mkdir(parents=True)
            source = root / "src/domain/value.cpp"
            source.write_text("int value() { return 1; }\n", encoding="utf-8")
            malformed = root / "malformed.json"
            malformed.write_text("{}", encoding="utf-8")
            self.assertNotEqual(
                self.run_checker("coverage.py", str(malformed), "80", cwd=root).returncode, 0
            )
            report = root / "coverage.json"
            report.write_text(
                json.dumps(
                    {
                        "data": [
                            {
                                "files": [
                                    {
                                        "filename": str(source),
                                        "summary": {
                                            "lines": {"count": 10, "covered": 7},
                                            "functions": {"count": 1, "covered": 1},
                                            "branches": {"count": 0, "covered": 0},
                                        },
                                    }
                                ]
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            result = self.run_checker("coverage.py", str(report), "80", cwd=root)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("lines 70.00%", result.stderr)
            self.assertIn("branches: not applicable", result.stdout)
            self.assertNotEqual(
                self.run_checker("coverage.py", str(report), "nan", cwd=root).returncode, 0
            )

    def test_coverage_requires_cc_sources_and_real_instrumentation(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "src").mkdir()
            source = root / "src/main.cc"
            source.write_text("int main() { return 0; }\n", encoding="utf-8")
            report = root / "coverage.json"
            summary = {metric: {"count": 0, "covered": 0} for metric in ("lines", "functions", "branches")}
            report.write_text(json.dumps({"data": [{"files": [{"filename": str(source), "summary": summary}]}]}))
            result = self.run_checker("coverage.py", str(report), "80", cwd=root)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("coverage was not measured", result.stderr)
            summary["lines"] = {"count": 1, "covered": 1}
            summary["functions"] = {"count": 1, "covered": 1}
            report.write_text(json.dumps({"data": [{"files": [{"filename": str(source), "summary": summary}]}]}))
            (root / "src/omitted.cxx").write_text("int value() { return 2; }\n")
            result = self.run_checker("coverage.py", str(report), "80", cwd=root)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("omitted.cxx", result.stderr)

    def test_architecture_uses_compiler_dependencies_to_reject_reverse_dependency(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "src/domain").mkdir(parents=True)
            (root / "src/application").mkdir(parents=True)
            (root / "include/project/domain").mkdir(parents=True)
            (root / "include/project/application").mkdir(parents=True)
            (root / "build").mkdir()
            application_header = root / "include/project/application/service.hpp"
            application_header.write_text("#pragma once\nint service();\n", encoding="utf-8")
            domain_header = root / "include/project/domain/value.hpp"
            domain_header.write_text(
                '#pragma once\n#include "project/application/service.hpp"\nint value();\n',
                encoding="utf-8",
            )
            domain_source = root / "src/domain/value.cpp"
            domain_source.write_text('#include "project/domain/value.hpp"\nint value() { return 1; }\n', encoding="utf-8")
            application_source = root / "src/application/service.cpp"
            application_source.write_text('#include "project/application/service.hpp"\nint service() { return 1; }\n', encoding="utf-8")
            compiler = shutil.which("c++")
            self.assertIsNotNone(compiler, "a C++ compiler is required")
            entries = [
                {
                    "directory": str(root),
                    "file": str(source),
                    "arguments": [compiler, "-std=c++20", "-I", str(root / "include"), "-c", str(source)],
                }
                for source in (domain_source, application_source)
            ]
            database = root / "build/compile_commands.json"
            database.write_text(json.dumps(entries), encoding="utf-8")
            result = self.run_checker("check-architecture.py", str(database))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("(domain) depends on", result.stderr)


if __name__ == "__main__":
    unittest.main()
