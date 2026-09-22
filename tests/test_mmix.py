"""End-to-end lifecycle and violation tests for the MMIX blueprint."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = REPO_ROOT / "blueprints" / "mmix-cli-base"
VIOLATIONS = REPO_ROOT / "violations" / "mmix-cli-base"
PROJECT_NAME = "test-mmix-cli"


def run(command: list[str], cwd: Path, *, expect: int = 0) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True, check=False)
    if result.returncode != expect:
        message = (
            f"command returned {result.returncode}, expected {expect}: {' '.join(command)}\n"
            f"stdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
        raise AssertionError(message)
    return result


def render(destination: Path) -> Path:
    project = destination / PROJECT_NAME
    run(
        [
            "copier",
            "copy",
            "--trust",
            "--defaults",
            "--data",
            f"project_name={PROJECT_NAME}",
            "--data",
            "project_description=MMIX lifecycle test",
            "--data",
            "author_name=Template Test",
            "--data",
            "author_email=test@example.invalid",
            str(TEMPLATE),
            str(project),
        ],
        REPO_ROOT,
    )
    return project


class Overlay:
    def __init__(self, fixture: Path, project: Path) -> None:
        self.fixture = fixture
        self.project = project
        self.originals: dict[Path, bytes | None] = {}
        self.created_directories: set[Path] = set()

    def _make_parent(self, target: Path) -> None:
        missing: list[Path] = []
        parent = target.parent
        while parent != self.project and not parent.exists():
            missing.append(parent)
            parent = parent.parent
        target.parent.mkdir(parents=True, exist_ok=True)
        self.created_directories.update(missing)

    def _remember(self, relative: Path) -> None:
        if relative in self.originals:
            return
        target = self.project / relative
        self.originals[relative] = target.read_bytes() if target.is_file() else None

    def apply(self) -> None:
        deletion_file = self.fixture / ".delete"
        if deletion_file.is_file():
            for raw_line in deletion_file.read_text(encoding="utf-8").splitlines():
                relative_text = raw_line.strip()
                if not relative_text or relative_text.startswith("#"):
                    continue
                relative = Path(relative_text)
                self._remember(relative)
                target = self.project / relative
                if not target.is_file():
                    raise AssertionError(f"deletion target does not exist: {relative}")
                target.unlink()
        hex_file = self.fixture / ".write-hex"
        if hex_file.is_file():
            for raw_line in hex_file.read_text(encoding="utf-8").splitlines():
                relative_text, separator, encoded = raw_line.partition("|")
                if not separator or not relative_text or not encoded:
                    raise AssertionError(f"malformed .write-hex line: {raw_line}")
                relative = Path(relative_text)
                self._remember(relative)
                target = self.project / relative
                self._make_parent(target)
                target.write_bytes(bytes.fromhex(encoded))
        for source in sorted(self.fixture.rglob("*")):
            if not source.is_file() or source.name in {
                "check", ".delete", ".write-hex"
            }:
                continue
            relative = source.relative_to(self.fixture)
            self._remember(relative)
            target = self.project / relative
            self._make_parent(target)
            shutil.copyfile(source, target)

    def restore(self) -> None:
        for relative, content in self.originals.items():
            target = self.project / relative
            if content is None:
                target.unlink(missing_ok=True)
            else:
                self._make_parent(target)
                target.write_bytes(content)
        for directory in sorted(self.created_directories, key=lambda path: len(path.parts), reverse=True):
            try:
                directory.rmdir()
            except OSError:
                pass


class MmixTemplateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temporary = tempfile.TemporaryDirectory(prefix="mmix-template-")
        cls.project = render(Path(cls.temporary.name))

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temporary.cleanup()

    def test_01_generated_lifecycle(self) -> None:
        project = self.project
        self.assertTrue((project / ".git").is_dir())
        self.assertTrue((project / ".copier-answers.yml").is_file())
        self.assertTrue((project / ".git" / "hooks" / "pre-commit").is_file())
        self.assertTrue(os.access(project / ".git" / "hooks" / "pre-commit", os.X_OK))
        self.assertTrue((project / "CLAUDE.md").is_symlink())
        self.assertEqual(os.readlink(project / "CLAUDE.md"), "AGENTS.md")

        for command in (
            ["just", "build"],
            ["just", "assemble"],
            ["just", "test-unit"],
            ["just", "test-state"],
            ["just", "test-cli"],
            ["just", "test"],
            ["just", "coverage"],
            ["just", "ci"],
            ["just", "ci-quiet"],
        ):
            run(command, project)

        success = run(["just", "run", "4"], project)
        self.assertEqual(success.stdout, "5\n")
        self.assertEqual(success.stderr, "")
        simulator = project / "build" / "bin" / (
            "mmix.exe" if os.name == "nt" else "mmix"
        )
        application = project / "build" / "app" / f"{PROJECT_NAME}.mmo"
        invalid = run([str(simulator), "-q", str(application), "9"], project, expect=1)
        self.assertEqual(invalid.stdout, "")
        self.assertEqual(invalid.stderr, "error: expected a digit from 0 to 8\n")

        shutil.rmtree(project / "build")
        run(["just", "ci"], project)
        hook = run(["git", "hook", "run", "pre-commit"], project)
        hook_output = hook.stdout + hook.stderr
        self.assertIn("Running CI Checks (Quiet Mode)", hook_output)
        self.assertIn("All CI checks passed", hook_output)

    def test_02_validation_code_has_no_fetch_commands(self) -> None:
        forbidden = (
            "curl ", "wget ", "git clone", "git pull", "npm ", "npx ",
            "pip ", "pipx ", "uv ", "cargo install", "brew install",
            "apt install", "winget ", "choco ", "docker pull",
        )
        tools = self.project / "tools"
        files = [self.project / "justfile"] + sorted(
            path for path in tools.rglob("*")
            if path.is_file() and path.suffix.lower() in {".c", ".h", ".sh", ".ps1"}
        )
        for path in files:
            text = path.read_text(encoding="utf-8", errors="strict").lower()
            for token in forbidden:
                self.assertNotIn(token, text, f"network command in {path}: {token}")

    def test_03_violations_fail_their_declared_stage(self) -> None:
        fixtures = sorted(
            path for path in VIOLATIONS.iterdir()
            if path.is_dir()
        )
        self.assertGreaterEqual(len(fixtures), 18)
        recipes = set(run(["just", "--summary"], self.project).stdout.split())
        for fixture in fixtures:
            with self.subTest(violation=fixture.name):
                self.assertTrue((fixture / "check").is_file(), f"missing recipe metadata: {fixture}")
                check = (fixture / "check").read_text(encoding="utf-8").strip()
                self.assertTrue(check)
                self.assertIn(check, recipes, f"unknown just recipe in {fixture.name}")
                overlay = Overlay(fixture, self.project)
                overlay.apply()
                try:
                    result = subprocess.run(
                        ["just", check], cwd=self.project, text=True,
                        capture_output=True, check=False,
                    )
                    self.assertNotEqual(
                        result.returncode,
                        0,
                        f"{fixture.name} passed just {check}\n{result.stdout}\n{result.stderr}",
                    )
                    combined = result.stdout + result.stderr
                    self.assertIn(
                        "mmix-guard:",
                        combined,
                        f"{fixture.name} failed outside the intended guardrail\n{combined}",
                    )
                finally:
                    overlay.restore()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", action="store_true")
    arguments, remaining = parser.parse_known_args()
    if arguments.baseline:
        suite = unittest.TestSuite(
            MmixTemplateTest(name) for name in (
                "test_01_generated_lifecycle",
                "test_02_validation_code_has_no_fetch_commands",
            )
        )
        outcome = unittest.TextTestRunner().run(suite)
        raise SystemExit(0 if outcome.wasSuccessful() else 1)
    unittest.main(argv=[__file__, *remaining])
