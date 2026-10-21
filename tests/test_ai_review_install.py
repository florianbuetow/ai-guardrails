#!/usr/bin/env python3
"""Integration tests for the additive ai-review installer."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALLER = REPO_ROOT / "project-setup" / "setup-project-ai-review-claude.sh"
BLUEPRINT = REPO_ROOT / "blueprints" / "ai-review"
OWNED_PATHS = (
    Path("scripts/ai-review"),
    Path("config/ai-review"),
    Path("docs/ai-review.md"),
    Path("just/ai-review.just"),
)
REQUIRED_RECIPES = {
    "ci-ai",
    "ci-ai-agy",
    "ci-ai-claude",
    "ci-ai-codex",
    "ci-ai-grok",
    "ci-ai-help",
}
EXPECTED_TEMPLATE_FILES = {
    Path("config/ai-review/config.json"),
    Path("config/ai-review/prompts/architecture.md"),
    Path("config/ai-review/prompts/common.md"),
    Path("config/ai-review/prompts/correctness.md"),
    Path("config/ai-review/prompts/performance.md"),
    Path("config/ai-review/prompts/security.md"),
    Path("config/ai-review/prompts/tests.md"),
    Path("config/ai-review/schema.json"),
    Path("docs/ai-review.md"),
    Path("just/ai-review.just"),
    Path("scripts/ai-review/review.py"),
}


def relative_files(root: Path) -> set[Path]:
    return {path.relative_to(root) for path in root.rglob("*") if path.is_file()}


class AiReviewInstallerTests(unittest.TestCase):
    def setUp(self) -> None:
        missing = [command for command in ("uv", "copier", "just") if shutil.which(command) is None]
        self.assertFalse(missing, "Required test commands are unavailable: " + ", ".join(missing))
        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        self.root = Path(temporary_directory.name).resolve()

    def new_workdir(self, name: str = "project") -> Path:
        workdir = self.root / name
        workdir.mkdir()
        return workdir

    def install(
        self, workdir: Path, expected_exit: int = 0, arguments: tuple[str, ...] = (), env: dict[str, str] | None = None
    ) -> str:
        result = subprocess.run(
            [str(INSTALLER), *arguments],
            cwd=workdir,
            env=env,
            check=False,
            capture_output=True,
            text=True,
        )
        output = result.stdout + result.stderr
        self.assertEqual(
            expected_exit,
            result.returncode,
            f"installer exited {result.returncode}, expected {expected_exit}:\n{output}",
        )
        return output

    def just(self, workdir: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(["just", *arguments], cwd=workdir, check=False, capture_output=True, text=True)

    def assert_owned_paths_absent(self, workdir: Path) -> None:
        for relative in OWNED_PATHS:
            self.assertFalse((workdir / relative).exists(), relative.as_posix())

    def assert_required_recipes(self, workdir: Path) -> None:
        result = self.just(workdir, "--summary")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertTrue(REQUIRED_RECIPES <= set(result.stdout.split()), result.stdout)

    def test_blueprint_has_the_installed_layout(self) -> None:
        template = BLUEPRINT / "template"
        self.assertEqual(EXPECTED_TEMPLATE_FILES, relative_files(template))
        for relative in OWNED_PATHS:
            self.assertTrue((template / relative).exists(), relative.as_posix())

    def test_installs_into_project_without_justfile(self) -> None:
        workdir = self.new_workdir()
        output = self.install(workdir)
        self.assertIn("Installed AI review commands", output)
        self.assertTrue((workdir / "Justfile").is_file())
        for relative in OWNED_PATHS:
            self.assertTrue((workdir / relative).exists(), relative.as_posix())
        self.assert_required_recipes(workdir)
        default_result = self.just(workdir)
        self.assertEqual(0, default_result.returncode, default_result.stderr)
        self.assertIn("AI review commands", default_result.stdout)
        help_result = self.just(workdir, "help")
        self.assertEqual(0, help_result.returncode, help_result.stderr)
        self.assertIn("ci-ai-help", help_result.stdout)

    def test_installs_in_a_path_with_spaces(self) -> None:
        workdir = self.new_workdir("project with spaces")
        self.install(workdir)
        self.assert_required_recipes(workdir)

    def test_appends_import_and_preserves_existing_default_recipe(self) -> None:
        workdir = self.new_workdir()
        justfile = workdir / "justfile"
        justfile.write_text("first:\n    @printf 'original\\n'\n\nother:\n    @printf 'other\\n'\n", encoding="utf-8")
        before = self.just(workdir)
        self.assertEqual(0, before.returncode, before.stderr)
        self.install(workdir)
        after = self.just(workdir)
        self.assertEqual(0, after.returncode, after.stderr)
        self.assertEqual(before.stdout, after.stdout)
        self.assertIn("import 'just/ai-review.just'", justfile.read_text(encoding="utf-8"))
        self.assert_required_recipes(workdir)

    def test_preserves_existing_crlf_bytes(self) -> None:
        workdir = self.new_workdir()
        justfile = workdir / "Justfile"
        original = b"_default:\r\n    @just help\r\n\r\nhelp:\r\n    @printf 'existing\\n'\r\n"
        justfile.write_bytes(original)
        self.install(workdir)
        installed = justfile.read_bytes()
        self.assertTrue(installed.startswith(original))
        self.assertIn(b"import 'just/ai-review.just'\n", installed)

    def test_recognizes_case_insensitive_dot_justfile(self) -> None:
        workdir = self.new_workdir()
        justfile = workdir / ".JUSTFILE"
        justfile.write_text("original:\n    @printf 'original\\n'\n", encoding="utf-8")
        self.install(workdir)
        self.assertFalse((workdir / "Justfile").exists())
        self.assertIn("ai-review.just", justfile.read_text(encoding="utf-8"))
        result = subprocess.run(
            ["just", "--justfile", str(justfile), "--working-directory", str(workdir), "--summary"],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(0, result.returncode, result.stderr)

    def test_refuses_multiple_justfiles_without_changes(self) -> None:
        workdir = self.new_workdir()
        (workdir / "Justfile").write_text("one:\n    @:\n", encoding="utf-8")
        (workdir / ".justfile").write_text("two:\n    @:\n", encoding="utf-8")
        before = relative_files(workdir)
        output = self.install(workdir, expected_exit=1)
        self.assertIn("multiple justfiles found", output)
        self.assertEqual(before, relative_files(workdir))
        self.assert_owned_paths_absent(workdir)

    def test_refuses_symlinked_or_nonregular_justfile(self) -> None:
        source = self.root / "shared"
        source.write_text("keep\n", encoding="utf-8")
        for index, kind in enumerate(("symlink", "directory")):
            with self.subTest(kind=kind):
                workdir = self.new_workdir(f"justfile-{index}")
                justfile = workdir / "Justfile"
                if kind == "symlink":
                    justfile.symlink_to(source)
                else:
                    justfile.mkdir()
                output = self.install(workdir, expected_exit=1)
                self.assertIn("is a symlink" if kind == "symlink" else "is not a regular file", output)
                self.assert_owned_paths_absent(workdir)
        self.assertEqual("keep\n", source.read_text(encoding="utf-8"))

    def test_refuses_each_owned_destination(self) -> None:
        for index, relative in enumerate(OWNED_PATHS):
            with self.subTest(path=relative.as_posix()):
                workdir = self.new_workdir(f"collision-{index}")
                destination = workdir / relative
                destination.parent.mkdir(parents=True)
                destination.write_text("keep\n", encoding="utf-8")
                output = self.install(workdir, expected_exit=1)
                self.assertIn(f"{relative.as_posix()} already exists", output)
                self.assertEqual("keep\n", destination.read_text(encoding="utf-8"))

    def test_refuses_unsafe_parent_components(self) -> None:
        outside = self.root / "outside"
        outside.mkdir()
        for index, kind in enumerate(("symlink", "file")):
            with self.subTest(kind=kind):
                workdir = self.new_workdir(f"unsafe-{index}")
                scripts = workdir / "scripts"
                if kind == "symlink":
                    scripts.symlink_to(outside)
                else:
                    scripts.write_text("keep\n", encoding="utf-8")
                output = self.install(workdir, expected_exit=1)
                self.assertIn("scripts is a symlink" if kind == "symlink" else "scripts is not a directory", output)
                self.assertEqual([], list(outside.iterdir()))

    def test_refuses_conflicting_recipe_or_import_before_installing(self) -> None:
        cases = (
            ("ci-ai-security:\n    @:\n", "existing AI review recipe conflicts"),
            ("import 'custom/ai-review.just'\n", "an ai-review import already exists"),
        )
        for index, (content, expected) in enumerate(cases):
            with self.subTest(content=content):
                workdir = self.new_workdir(f"conflict-{index}")
                justfile = workdir / "Justfile"
                justfile.write_text(content, encoding="utf-8")
                output = self.install(workdir, expected_exit=1)
                self.assertIn(expected, output)
                self.assertEqual(content, justfile.read_text(encoding="utf-8"))
                self.assert_owned_paths_absent(workdir)

    def test_refuses_recipes_and_aliases_from_existing_imports(self) -> None:
        cases = (
            ("ci-ai-security:\n    @:\n", "set allow-duplicate-recipes\n\nimport 'existing.just'\n"),
            ("build:\n    @:\n\nalias ci-ai := build\n", "set allow-duplicate-recipes\n\nimport 'existing.just'\n"),
        )
        for index, (imported, root_content) in enumerate(cases):
            with self.subTest(index=index):
                workdir = self.new_workdir(f"import-conflict-{index}")
                justfile = workdir / "Justfile"
                imported_file = workdir / "existing.just"
                justfile.write_text(root_content, encoding="utf-8")
                imported_file.write_text(imported, encoding="utf-8")
                output = self.install(workdir, expected_exit=1)
                self.assertIn("existing AI review recipe conflicts", output)
                self.assertEqual(root_content, justfile.read_text(encoding="utf-8"))
                self.assertEqual(imported, imported_file.read_text(encoding="utf-8"))
                self.assert_owned_paths_absent(workdir)

    def test_repeated_install_refuses_without_changing_first_install(self) -> None:
        workdir = self.new_workdir()
        self.install(workdir)
        snapshots = {path: path.read_bytes() for path in workdir.rglob("*") if path.is_file()}
        output = self.install(workdir, expected_exit=1)
        self.assertIn("already exists", output)
        self.assertEqual(snapshots, {path: path.read_bytes() for path in workdir.rglob("*") if path.is_file()})

    def test_rejects_an_invalid_existing_justfile_without_changes(self) -> None:
        workdir = self.new_workdir()
        justfile = workdir / "Justfile"
        original = "this is not valid just syntax\n"
        justfile.write_text(original, encoding="utf-8")
        output = self.install(workdir, expected_exit=1)
        self.assertIn("existing justfile is invalid", output)
        self.assertEqual(original, justfile.read_text(encoding="utf-8"))
        self.assert_owned_paths_absent(workdir)
        self.assertFalse(any(path.name.startswith(".ai-review-justfile-") for path in workdir.iterdir()))
        self.assertFalse((workdir / "scripts").exists())
        self.assertFalse((workdir / "config").exists())
        self.assertFalse((workdir / "docs").exists())
        self.assertFalse((workdir / "just").exists())

    def test_failing_copier_leaves_the_project_unchanged(self) -> None:
        workdir = self.new_workdir()
        justfile = workdir / "Justfile"
        original = "_default:\n    @:\n"
        justfile.write_text(original, encoding="utf-8")
        fake_bin = self.root / "fake-bin"
        fake_bin.mkdir()
        copier = fake_bin / "copier"
        copier.write_text("#!/bin/sh\nprintf 'injected copier failure\\n' >&2\nexit 9\n", encoding="utf-8")
        copier.chmod(0o755)
        env = {**os.environ, "PATH": f"{fake_bin}{os.pathsep}{os.environ['PATH']}"}
        output = self.install(workdir, expected_exit=1, env=env)
        self.assertIn("copier could not render", output)
        self.assertIn("injected copier failure", output)
        self.assertEqual(original, justfile.read_text(encoding="utf-8"))
        self.assert_owned_paths_absent(workdir)

    def test_midcopy_failure_rolls_back_only_new_paths(self) -> None:
        workdir = self.new_workdir()
        justfile = workdir / "Justfile"
        original = "_default:\n    @:\n"
        justfile.write_text(original, encoding="utf-8")
        docs = workdir / "docs"
        docs.mkdir()
        keep = docs / "keep.md"
        keep.write_text("keep\n", encoding="utf-8")
        docs.chmod(0o500)
        try:
            output = self.install(workdir, expected_exit=1)
        finally:
            docs.chmod(0o700)
        self.assertIn("installation failed and was rolled back", output)
        self.assertEqual(original, justfile.read_text(encoding="utf-8"))
        self.assertEqual("keep\n", keep.read_text(encoding="utf-8"))
        self.assert_owned_paths_absent(workdir)
        self.assertFalse((workdir / "scripts").exists())
        self.assertFalse((workdir / "config").exists())
        self.assertFalse((workdir / "just").exists())

    def test_rejects_arguments_without_changes(self) -> None:
        workdir = self.new_workdir()
        output = self.install(workdir, expected_exit=1, arguments=("unexpected",))
        self.assertIn("takes no arguments", output)
        self.assertEqual(set(), relative_files(workdir))


if __name__ == "__main__":
    unittest.main()
