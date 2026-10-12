#!/usr/bin/env python3
"""Regression tests for trustworthy Raspberry Pi violation injection."""

from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


RUNNER = Path(__file__).with_name("test_raspberry_pi_cpp.py")
SPEC = importlib.util.spec_from_file_location("pi_runner", RUNNER)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Cannot load Raspberry Pi template runner")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class RunnerRegressionTests(unittest.TestCase):
    def test_old_fixture_invalidates_a_newer_build_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            violation = root / "violation"
            project = root / "project"
            (violation / "src").mkdir(parents=True)
            project.mkdir()
            source = violation / "src/main.cpp"
            source.write_text("int main() { return 1; }\n", encoding="utf-8")
            os.utime(source, (1, 1))
            (violation / "check").write_text("test\n", encoding="utf-8")
            (violation / "expected").write_text("failure\n", encoding="utf-8")
            built = project / "old-build.o"
            built.write_bytes(b"previous clean object")
            os.utime(built, (2, 2))

            overlaid = runner.overlay_violation(project, violation)

            self.assertEqual(overlaid, ["src/main.cpp"])
            self.assertEqual((project / "src/main.cpp").read_text(), source.read_text())
            self.assertGreater((project / "src/main.cpp").stat().st_mtime_ns, built.stat().st_mtime_ns)
            self.assertFalse((project / "check").exists())
            self.assertFalse((project / "expected").exists())

    def test_existing_project_cannot_receive_destructive_violation_overlays(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            sentinel = Path(directory) / "keep.txt"
            sentinel.write_text("keep this work\n", encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(RUNNER), "--generated-project", directory],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("requires --baseline", result.stderr)
            self.assertEqual(sentinel.read_text(), "keep this work\n")
            self.assertEqual(list(Path(directory).iterdir()), [sentinel])


if __name__ == "__main__":
    unittest.main()
