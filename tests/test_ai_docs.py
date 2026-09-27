#!/usr/bin/env python3
"""Behavior tests for the ai-docs installer, which adds agent documentation to the current directory."""

from __future__ import annotations

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
BLUEPRINT_DIR = REPO_ROOT / "blueprints" / "ai-docs"
TEMPLATE_DIR = BLUEPRINT_DIR / "template"
AGENTS_SECTION = (BLUEPRINT_DIR / "agents-section.md").read_text(encoding="utf-8")
INSTALLER = REPO_ROOT / "project-setup" / "setup-project-ai-docs-claude.sh"
SETUP_PROJECT = REPO_ROOT / "project-setup" / "setup-project.sh"
DOCS_IGNORED_WARNING = "docs/ is git-ignored. None of your documentation would ever be committed to git."
PARTIALLY_IGNORED_WARNING = "files in docs/ are git-ignored and would never be committed to git"
ARCHITECTURE_IGNORED_WARNING = "ARCHITECTURE.md is git-ignored. It would never be committed to git."
LINK_TARGET = re.compile(r"\]\(([^)]+)\)")
# The knowledge-base layout from OpenAI's "Harness engineering" article.
EXPECTED_LAYOUT = {
    Path(path)
    for path in (
        "ARCHITECTURE.md",
        "docs/README.md",
        "docs/design-docs/index.md",
        "docs/design-docs/core-beliefs.md",
        "docs/exec-plans/active/.gitkeep",
        "docs/exec-plans/completed/.gitkeep",
        "docs/exec-plans/tech-debt-tracker.md",
        "docs/generated/index.md",
        "docs/product-specs/index.md",
        "docs/references/index.md",
        "docs/DESIGN.md",
        "docs/FRONTEND.md",
        "docs/PLANS.md",
        "docs/PRODUCT_SENSE.md",
        "docs/QUALITY_SCORE.md",
        "docs/RELIABILITY.md",
        "docs/SECURITY.md",
    )
}
DOCS_FILE_COUNT = sum(1 for path in EXPECTED_LAYOUT if path.parts[0] == "docs")
# Every meaningful path the AGENTS.md section must map; .gitkeep stands for its directory.
MAPPED_PATHS = {
    f"{path.parent.as_posix()}/" if path.name == ".gitkeep" else path.as_posix() for path in EXPECTED_LAYOUT
}


def relative_files(root: Path) -> set[Path]:
    return {path.relative_to(root) for path in root.rglob("*") if path.is_file()}


def empty_directories(root: Path) -> list[Path]:
    return sorted(path.relative_to(root) for path in root.rglob("*") if path.is_dir() and not any(path.iterdir()))


class AiDocsInstallerTests(unittest.TestCase):
    def setUp(self) -> None:
        missing = [command for command in ("copier", "git") if shutil.which(command) is None]
        self.assertFalse(missing, "Required test commands are unavailable: " + ", ".join(missing))

        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        self.root = Path(temporary_directory.name).resolve()
        self.global_excludes = self.root / "global-excludes"
        self.global_excludes.write_text("", encoding="utf-8")
        # Stop git from finding a repository above the temporary directory and
        # from applying the developer's own configuration, ignore rules, or
        # repository variables such as GIT_DIR.
        self.env = {
            **{key: value for key, value in os.environ.items() if not key.startswith("GIT_")},
            "GIT_CEILING_DIRECTORIES": str(self.root),
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_COUNT": "1",
            "GIT_CONFIG_KEY_0": "core.excludesFile",
            "GIT_CONFIG_VALUE_0": str(self.global_excludes),
        }

    def new_workdir(self, name: str) -> Path:
        workdir = self.root / name
        workdir.mkdir()
        return workdir

    def git(self, workdir: Path, *arguments: str) -> None:
        result = subprocess.run(
            ["git", *arguments], cwd=workdir, env=self.env, check=False, capture_output=True, text=True
        )
        self.assertEqual(0, result.returncode, f"git {' '.join(arguments)} failed:\n{result.stderr}")

    def install(self, workdir: Path, arguments: list[str], env: dict[str, str], expected_exit: int) -> str:
        result = subprocess.run(
            [str(INSTALLER), *arguments], cwd=workdir, env=env, check=False, capture_output=True, text=True
        )
        output = result.stdout + result.stderr
        self.assertEqual(
            expected_exit, result.returncode, f"installer exited {result.returncode}, expected {expected_exit}:\n{output}"
        )
        return output

    def path_without_git(self) -> str:
        bin_dir = self.root / "bin-without-git"
        bin_dir.mkdir()
        for directory in os.environ["PATH"].split(os.pathsep):
            if not directory or not Path(directory).is_dir():
                continue
            for entry in sorted(Path(directory).iterdir()):
                link = bin_dir / entry.name
                if entry.name == "git" or link.is_symlink():
                    continue
                if entry.is_file() and os.access(entry, os.X_OK):
                    link.symlink_to(entry)
        self.assertIsNone(shutil.which("git", path=str(bin_dir)))
        return str(bin_dir)

    def test_template_matches_the_article_layout(self) -> None:
        self.assertEqual(EXPECTED_LAYOUT, relative_files(TEMPLATE_DIR))

    def test_installs_the_layout_and_creates_agents_md_outside_git(self) -> None:
        workdir = self.new_workdir("project")
        output = self.install(workdir, [], self.env, 0)
        self.assertEqual(EXPECTED_LAYOUT | {Path("AGENTS.md")}, relative_files(workdir))
        self.assertEqual([], empty_directories(workdir))
        self.assertEqual(f"# AGENTS.md\n\n{AGENTS_SECTION}", (workdir / "AGENTS.md").read_text(encoding="utf-8"))
        self.assertIn("Wrote AGENTS.md with the Documentation section", output)
        self.assertIn("not inside a git work tree; skipped the git-ignore check", output)

    def test_fills_an_empty_agents_md_like_a_missing_one(self) -> None:
        workdir = self.new_workdir("project")
        (workdir / "AGENTS.md").write_text("", encoding="utf-8")
        output = self.install(workdir, [], self.env, 0)
        self.assertEqual(f"# AGENTS.md\n\n{AGENTS_SECTION}", (workdir / "AGENTS.md").read_text(encoding="utf-8"))
        self.assertIn("Wrote AGENTS.md with the Documentation section", output)

    def test_appends_the_section_to_an_existing_agents_md(self) -> None:
        for index, existing in enumerate(("# Rules\n\nBe precise.\n", "# Rules\n\nBe precise.")):
            with self.subTest(trailing_newline=existing.endswith("\n")):
                workdir = self.new_workdir(f"agents-{index}")
                (workdir / "AGENTS.md").write_text(existing, encoding="utf-8")
                output = self.install(workdir, [], self.env, 0)
                self.assertEqual(
                    f"# Rules\n\nBe precise.\n\n{AGENTS_SECTION}",
                    (workdir / "AGENTS.md").read_text(encoding="utf-8"),
                )
                self.assertIn("Added the Documentation section to AGENTS.md", output)

    def test_agents_section_maps_every_installed_path(self) -> None:
        self.assertEqual(MAPPED_PATHS, set(LINK_TARGET.findall(AGENTS_SECTION)))

    def test_docs_readme_describes_every_installed_path(self) -> None:
        readme = (TEMPLATE_DIR / "docs" / "README.md").read_text(encoding="utf-8")
        undescribed = sorted(
            path for path in MAPPED_PATHS if f"{Path(path).name}{'/' if path.endswith('/') else ''}" not in readme
        )
        self.assertEqual([], undescribed)

    def test_relative_links_resolve(self) -> None:
        workdir = self.new_workdir("project")
        self.install(workdir, [], self.env, 0)
        broken = []
        for document in sorted(workdir.rglob("*.md")):
            for target in LINK_TARGET.findall(document.read_text(encoding="utf-8")):
                if target.startswith(("http://", "https://", "#")):
                    continue
                if not (document.parent / target.split("#", 1)[0]).exists():
                    broken.append(f"{document.relative_to(workdir)} -> {target}")
        self.assertEqual([], broken)

    def test_refuses_an_existing_docs_directory_without_changes(self) -> None:
        workdir = self.new_workdir("project")
        docs = workdir / "docs"
        docs.mkdir()
        (docs / "notes.md").write_text("keep\n", encoding="utf-8")
        output = self.install(workdir, [], self.env, 1)
        self.assertIn("docs already exists; nothing was changed", output)
        self.assertEqual({Path("docs/notes.md")}, relative_files(workdir))

    def test_refuses_an_existing_docs_file(self) -> None:
        workdir = self.new_workdir("project")
        (workdir / "docs").write_text("keep\n", encoding="utf-8")
        output = self.install(workdir, [], self.env, 1)
        self.assertIn("docs already exists; nothing was changed", output)
        self.assertEqual({Path("docs")}, relative_files(workdir))

    def test_refuses_a_dangling_docs_symlink(self) -> None:
        workdir = self.new_workdir("project")
        missing_target = self.root / "missing-target"
        (workdir / "docs").symlink_to(missing_target)
        output = self.install(workdir, [], self.env, 1)
        self.assertIn("docs already exists; nothing was changed", output)
        self.assertEqual(["docs"], [entry.name for entry in workdir.iterdir()])
        self.assertFalse(missing_target.exists())

    def test_refuses_an_existing_architecture_md_without_changes(self) -> None:
        workdir = self.new_workdir("project")
        (workdir / "ARCHITECTURE.md").write_text("keep\n", encoding="utf-8")
        (workdir / "AGENTS.md").write_text("keep\n", encoding="utf-8")
        output = self.install(workdir, [], self.env, 1)
        self.assertIn("ARCHITECTURE.md already exists; nothing was changed", output)
        self.assertEqual({Path("AGENTS.md"), Path("ARCHITECTURE.md")}, relative_files(workdir))
        self.assertEqual("keep\n", (workdir / "ARCHITECTURE.md").read_text(encoding="utf-8"))
        self.assertEqual("keep\n", (workdir / "AGENTS.md").read_text(encoding="utf-8"))

    def test_refuses_an_agents_md_that_is_not_a_file(self) -> None:
        workdir = self.new_workdir("project")
        (workdir / "AGENTS.md").mkdir()
        output = self.install(workdir, [], self.env, 1)
        self.assertIn("AGENTS.md is not a regular file; nothing was changed", output)
        self.assertEqual(["AGENTS.md"], [entry.name for entry in workdir.iterdir()])

    def test_refuses_a_symlinked_agents_md_without_changes(self) -> None:
        shared = self.root / "shared-agents.md"
        shared.write_text("keep\n", encoding="utf-8")
        missing = self.root / "missing-agents.md"
        for index, target in enumerate((shared, missing)):
            with self.subTest(target=target.name):
                workdir = self.new_workdir(f"symlink-{index}")
                (workdir / "AGENTS.md").symlink_to(target)
                output = self.install(workdir, [], self.env, 1)
                self.assertIn("AGENTS.md is a symlink; nothing was changed", output)
                self.assertEqual(["AGENTS.md"], [entry.name for entry in workdir.iterdir()])
        self.assertEqual("keep\n", shared.read_text(encoding="utf-8"))
        self.assertFalse(missing.exists())

    def test_refuses_a_claude_md_without_changes(self) -> None:
        for index, linked in enumerate((False, True)):
            with self.subTest(symlink=linked):
                workdir = self.new_workdir(f"claude-{index}")
                (workdir / "AGENTS.md").write_text("keep\n", encoding="utf-8")
                claude = workdir / "CLAUDE.md"
                if linked:
                    claude.symlink_to("AGENTS.md")
                else:
                    claude.write_text("keep\n", encoding="utf-8")
                output = self.install(workdir, [], self.env, 1)
                self.assertIn("CLAUDE.md exists; agent instructions belong in AGENTS.md only", output)
                self.assertEqual(["AGENTS.md", "CLAUDE.md"], sorted(entry.name for entry in workdir.iterdir()))
                self.assertEqual("keep\n", (workdir / "AGENTS.md").read_text(encoding="utf-8"))

    def test_refuses_a_read_only_agents_md_without_changes(self) -> None:
        workdir = self.new_workdir("project")
        agents = workdir / "AGENTS.md"
        agents.write_text("keep\n", encoding="utf-8")
        agents.chmod(0o444)
        output = self.install(workdir, [], self.env, 1)
        self.assertIn("AGENTS.md is not writable; nothing was changed", output)
        self.assertEqual({Path("AGENTS.md")}, relative_files(workdir))

    def test_rolls_back_when_copier_fails(self) -> None:
        workdir = self.new_workdir("project")
        (workdir / "AGENTS.md").write_text("keep\n", encoding="utf-8")
        fake_bin = self.root / "fake-bin"
        fake_bin.mkdir()
        fake_copier = fake_bin / "copier"
        fake_copier.write_text("#!/bin/sh\nmkdir docs\n: > docs/partial.md\n: > ARCHITECTURE.md\nexit 7\n", encoding="utf-8")
        fake_copier.chmod(0o755)
        output = self.install(workdir, [], {**self.env, "PATH": f"{fake_bin}{os.pathsep}{self.env['PATH']}"}, 7)
        self.assertIn("the changes were rolled back", output)
        self.assertEqual(["AGENTS.md"], [entry.name for entry in workdir.iterdir()])
        self.assertEqual("keep\n", (workdir / "AGENTS.md").read_text(encoding="utf-8"))

    def test_rolls_back_when_agents_md_cannot_be_written(self) -> None:
        workdir = self.new_workdir("project")
        (workdir / "AGENTS.md").write_text("keep\n", encoding="utf-8")
        real_copier = shutil.which("copier", path=self.env["PATH"])
        self.assertIsNotNone(real_copier)
        fake_bin = self.root / "fake-bin"
        fake_bin.mkdir()
        # Render for real, then make AGENTS.md read-only before the installer appends to it.
        wrapper = fake_bin / "copier"
        wrapper.write_text(f'#!/bin/sh\n"{real_copier}" "$@" || exit $?\nchmod 444 AGENTS.md\n', encoding="utf-8")
        wrapper.chmod(0o755)
        output = self.install(workdir, [], {**self.env, "PATH": f"{fake_bin}{os.pathsep}{self.env['PATH']}"}, 1)
        self.assertIn("the changes were rolled back", output)
        self.assertEqual(["AGENTS.md"], [entry.name for entry in workdir.iterdir()])
        self.assertEqual("keep\n", (workdir / "AGENTS.md").read_text(encoding="utf-8"))

    def test_rejects_arguments(self) -> None:
        workdir = self.new_workdir("project")
        output = self.install(workdir, ["my-project"], self.env, 1)
        self.assertIn("Usage:", output)
        self.assertEqual([], sorted(workdir.iterdir()))

    def test_succeeds_when_git_does_not_ignore_the_documentation(self) -> None:
        workdir = self.new_workdir("project")
        self.git(workdir, "init", "-q")
        output = self.install(workdir, [], self.env, 0)
        self.assertIn("docs/ and ARCHITECTURE.md are not git-ignored", output)
        self.assertNotIn(DOCS_IGNORED_WARNING, output)
        self.assertNotIn(ARCHITECTURE_IGNORED_WARNING, output)

    def test_warns_and_fails_when_gitignore_ignores_the_documentation(self) -> None:
        # (pattern, ignored files in docs/, ARCHITECTURE.md ignored); *.md leaves the two .gitkeep files.
        cases = (
            ("docs/", DOCS_FILE_COUNT, False),
            ("/docs", DOCS_FILE_COUNT, False),
            ("docs/*", DOCS_FILE_COUNT, False),
            ("docs/**", DOCS_FILE_COUNT, False),
            ("*.md", DOCS_FILE_COUNT - 2, True),
            ("ARCHITECTURE.md", 0, True),
        )
        for index, (pattern, ignored_docs, architecture_ignored) in enumerate(cases):
            with self.subTest(pattern=pattern):
                workdir = self.new_workdir(f"ignored-{index}")
                self.git(workdir, "init", "-q")
                (workdir / ".gitignore").write_text(f"{pattern}\n", encoding="utf-8")
                output = self.install(workdir, [], self.env, 1)
                partial_warning = f"{ignored_docs} of {DOCS_FILE_COUNT} {PARTIALLY_IGNORED_WARNING}"
                self.assertEqual(ignored_docs == DOCS_FILE_COUNT, DOCS_IGNORED_WARNING in output, output)
                self.assertEqual(0 < ignored_docs < DOCS_FILE_COUNT, partial_warning in output, output)
                self.assertEqual(architecture_ignored, ARCHITECTURE_IGNORED_WARNING in output, output)
                self.assertIn(f".gitignore:1:{pattern}", output)
                self.assertTrue((workdir / "docs" / "PLANS.md").is_file(), output)

    def test_lists_partially_ignored_documentation(self) -> None:
        cases = (
            ("docs/PLANS.md\n", 1, "  docs/PLANS.md", "  docs/SECURITY.md"),
            ("docs/*\n!docs/PLANS.md\n", DOCS_FILE_COUNT - 1, "  docs/SECURITY.md", "  docs/PLANS.md"),
        )
        for index, (rules, ignored_docs, listed, not_listed) in enumerate(cases):
            with self.subTest(rules=rules):
                workdir = self.new_workdir(f"partial-{index}")
                self.git(workdir, "init", "-q")
                (workdir / ".gitignore").write_text(rules, encoding="utf-8")
                output = self.install(workdir, [], self.env, 1)
                lines = output.splitlines()
                self.assertIn(f"{ignored_docs} of {DOCS_FILE_COUNT} {PARTIALLY_IGNORED_WARNING}", output)
                self.assertNotIn(DOCS_IGNORED_WARNING, output)
                self.assertIn(listed, lines)
                self.assertNotIn(not_listed, lines)

    def test_git_trace_output_does_not_skip_the_ignore_check(self) -> None:
        workdir = self.new_workdir("project")
        self.git(workdir, "init", "-q")
        (workdir / ".gitignore").write_text("docs/\n", encoding="utf-8")
        output = self.install(workdir, [], {**self.env, "GIT_TRACE": "1"}, 1)
        self.assertIn(DOCS_IGNORED_WARNING, output)

    def test_fails_when_git_cannot_read_the_repository(self) -> None:
        workdir = self.new_workdir("project")
        self.git(workdir, "init", "-q")
        (workdir / ".git" / "config").write_text("[core\n", encoding="utf-8")
        output = self.install(workdir, [], self.env, 1)
        self.assertIn("bad config line 1", output)
        self.assertIn("git rev-parse failed", output)

    def test_warns_and_fails_when_global_excludes_ignore_docs(self) -> None:
        workdir = self.new_workdir("project")
        self.git(workdir, "init", "-q")
        self.global_excludes.write_text("docs/\n", encoding="utf-8")
        output = self.install(workdir, [], self.env, 1)
        self.assertIn(DOCS_IGNORED_WARNING, output)
        self.assertIn(f"{self.global_excludes}:1:docs/", output)

    def test_skips_the_ignore_check_when_git_is_not_installed(self) -> None:
        workdir = self.new_workdir("project")
        self.git(workdir, "init", "-q")
        (workdir / ".gitignore").write_text("docs/\n", encoding="utf-8")
        output = self.install(workdir, [], {**self.env, "PATH": self.path_without_git()}, 0)
        self.assertIn("git is not installed; skipped the git-ignore check", output)
        self.assertTrue((workdir / "docs" / "PLANS.md").is_file(), output)

    def test_setup_project_rejects_ai_docs_without_creating_the_target(self) -> None:
        target = self.root / "target"
        result = subprocess.run(
            [str(SETUP_PROJECT), "--template", "ai-docs", "--target", str(target)],
            cwd=self.root,
            env=self.env,
            check=False,
            capture_output=True,
            text=True,
        )
        output = result.stdout + result.stderr
        self.assertEqual(1, result.returncode, output)
        self.assertIn(INSTALLER.name, output)
        self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
