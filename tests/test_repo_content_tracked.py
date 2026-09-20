#!/usr/bin/env python3
"""Ensure blueprint and violation content survives a git clone.

Copier renders templates from the working tree, and the violation runner
copies overlays from the working tree, so both are blind to files that
exist locally but were never committed. A single unanchored `.gitignore`
entry (`lib/`) once hid four template modules and thirty violation
overlays: every local test passed while a fresh clone received a template
that could not build.

These tests close that gap by comparing what is on disk against what git
actually tracks.
"""

from __future__ import annotations

from pathlib import Path
import subprocess
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
CONTENT_DIRS = ("blueprints", "violations")
CHECK_FILE = "check"


def tracked_paths() -> set[Path]:
    result = subprocess.run(
        ["git", "ls-files", "-z", *CONTENT_DIRS],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return {Path(entry) for entry in result.stdout.split("\0") if entry}


def disk_paths() -> set[Path]:
    paths: set[Path] = set()
    for directory in CONTENT_DIRS:
        root = REPO_ROOT / directory
        if not root.is_dir():
            raise AssertionError(f"Missing content directory: {root}")
        for path in root.rglob("*"):
            if path.is_file() and ".git" not in path.parts:
                paths.add(path.relative_to(REPO_ROOT))
    return paths


class RepoContentTrackedTests(unittest.TestCase):
    def test_every_blueprint_and_violation_file_is_tracked(self) -> None:
        untracked = sorted(disk_paths() - tracked_paths())
        self.assertEqual(
            [],
            untracked,
            "These files exist locally but are not tracked by git, so a fresh "
            "clone will not receive them. Check .gitignore for an unanchored "
            "pattern that matches them:\n  " + "\n  ".join(str(p) for p in untracked),
        )

    def test_every_violation_declares_a_check_recipe(self) -> None:
        violations_root = REPO_ROOT / "violations"
        missing = []
        for language_dir in sorted(violations_root.iterdir()):
            if not language_dir.is_dir():
                continue
            for violation_dir in sorted(language_dir.iterdir()):
                if not violation_dir.is_dir():
                    continue
                if not (violation_dir / CHECK_FILE).is_file():
                    missing.append(violation_dir.relative_to(REPO_ROOT))
        self.assertEqual([], missing, f"Violations without a 'check' file: {missing}")

    def test_every_violation_ships_overlay_files(self) -> None:
        """A violation with only a 'check' file injects nothing.

        The runner would then see the targeted recipe pass and report the
        violation as undetected, so an empty fixture is always a defect.
        """
        violations_root = REPO_ROOT / "violations"
        tracked = tracked_paths()
        empty = []
        for language_dir in sorted(violations_root.iterdir()):
            if not language_dir.is_dir():
                continue
            for violation_dir in sorted(language_dir.iterdir()):
                if not violation_dir.is_dir():
                    continue
                relative = violation_dir.relative_to(REPO_ROOT)
                overlays = [
                    path
                    for path in tracked
                    if path.is_relative_to(relative) and path.name != CHECK_FILE
                ]
                if not overlays:
                    empty.append(relative)
        self.assertEqual(
            [],
            empty,
            "These violations track no overlay files, so they inject nothing "
            f"and can never fail their recipe: {empty}",
        )


if __name__ == "__main__":
    unittest.main()
