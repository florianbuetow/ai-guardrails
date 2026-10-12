#!/usr/bin/env python3
"""Render and test the Raspberry Pi C++ template in a Linux ARM64 container."""

from __future__ import annotations

import argparse
import os
from collections.abc import Sequence
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import Optional


REPO_ROOT = Path(__file__).resolve().parents[1]
BLUEPRINT = REPO_ROOT / "blueprints" / "raspberry-pi-cpp-base"
VIOLATIONS = REPO_ROOT / "violations" / "raspberry-pi-cpp-base"
IMAGE_TAG = "ai-guardrails-raspberry-pi-cpp-test:trixie-arm64"
RUNTIME_IMAGE_TAG = "ai-guardrails-raspberry-pi-cpp-runtime-test:trixie-arm64"
PROJECT_NAME = "test-raspberry-pi-cpp"
COPIER_DATA = (
    f"project_name={PROJECT_NAME}",
    "project_description=Test Raspberry Pi C++ application",
    "author_name=Test Author",
    "author_email=test@example.com",
    "coverage_threshold=80",
)
EXPECTED_RECIPES = {"check", "init", "build", "run", "test", "test-artifact", "ci", "ci-quiet"}
TEMPLATE_TOKEN = re.compile(r"({[{%#]\s*[A-Za-z_]|[%#]})")


class TestFailure(RuntimeError):
    """A template contract or execution check failed."""


def run(
    command: Sequence[str],
    *,
    cwd: Optional[Path] = None,
    capture: bool = False,
    expected_success: bool = True,
    separate_stderr: bool = False,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=(subprocess.PIPE if separate_stderr else subprocess.STDOUT) if capture else None,
    )
    if expected_success and result.returncode != 0:
        output = (result.stdout or "") + (result.stderr or "")
        raise TestFailure(f"Command failed ({result.returncode}): {' '.join(command)}\n{output}")
    return result


def require_command(command: str) -> None:
    if shutil.which(command) is None:
        raise TestFailure(f"Required command is unavailable: {command}")


def render_project(parent: Path) -> Path:
    require_command("copier")
    project = parent / PROJECT_NAME
    command = ["copier", "copy", "--trust", "--defaults"]
    for entry in COPIER_DATA:
        command.extend(("--data", entry))
    command.extend((str(BLUEPRINT), str(project)))
    run(command)
    return project


def recipe_names(justfile: Path) -> set[str]:
    pattern = re.compile(r"^([A-Za-z0-9_-]+)(?:\s+[^:]*)?:", re.MULTILINE)
    return set(pattern.findall(justfile.read_text(encoding="utf-8")))


def validate_contracts(project: Path) -> None:
    required = (
        "Dockerfile",
        "CMakeLists.txt",
        "CMakePresets.json",
        "justfile",
        "README.md",
        "AGENTS.md",
        "src/cli/main.cpp",
        "tests",
        "scripts",
    )
    missing = [path for path in required if not (project / path).exists()]
    if missing:
        raise TestFailure("Rendered project is missing: " + ", ".join(missing))

    empty_directories = sorted(
        str(path.relative_to(project))
        for path in project.rglob("*")
        if path.is_dir() and path.name != ".git" and ".git" not in path.parts and not any(path.iterdir())
    )
    if empty_directories:
        raise TestFailure("Rendered project has empty directories: " + ", ".join(empty_directories))

    unresolved: list[str] = []
    for path in sorted(project.rglob("*")):
        if not path.is_file() or ".git" in path.parts:
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        if TEMPLATE_TOKEN.search(content):
            unresolved.append(str(path.relative_to(project)))
    if unresolved:
        raise TestFailure("Rendered files contain Copier syntax: " + ", ".join(unresolved))

    missing_recipes = EXPECTED_RECIPES - recipe_names(project / "justfile")
    if missing_recipes:
        raise TestFailure("Generated justfile is missing recipes: " + ", ".join(sorted(missing_recipes)))

    dockerfile = (project / "Dockerfile").read_text(encoding="utf-8")
    for stage in ("AS development", "AS runtime"):
        if stage not in dockerfile:
            raise TestFailure(f"Generated Dockerfile is missing the {stage!r} stage")
    if "debian:trixie" not in dockerfile:
        raise TestFailure("Generated Dockerfile must use Debian Trixie")

    validate_violation_contracts(project)


def validate_violation_contracts(project: Path) -> None:
    if not VIOLATIONS.is_dir():
        raise TestFailure(f"Violation directory is missing: {VIOLATIONS}")
    available_recipes = recipe_names(project / "justfile")
    violation_directories = sorted(path for path in VIOLATIONS.iterdir() if path.is_dir())
    if not violation_directories:
        raise TestFailure("No Raspberry Pi C++ violations were defined")
    for violation in violation_directories:
        check_file = violation / "check"
        expected_file = violation / "expected"
        if not check_file.is_file() or not expected_file.is_file():
            raise TestFailure(f"Violation is missing its check or expected file: {violation.name}")
        recipe = check_file.read_text(encoding="utf-8").strip()
        expected = expected_file.read_text(encoding="utf-8").strip()
        if not recipe or "\n" in recipe or recipe not in available_recipes:
            raise TestFailure(f"Violation has an invalid check recipe: {violation.name}")
        if not expected or "\n" in expected:
            raise TestFailure(f"Violation has an invalid expected marker: {violation.name}")
        overlays = [
            path for path in violation.rglob("*") if path.is_file() and path.name not in {"check", "expected"}
        ]
        if not overlays:
            raise TestFailure(f"Violation has no overlay files: {violation.name}")


def initialize_git(project: Path) -> None:
    if not (project / ".git").is_dir():
        run(("git", "init", "-q"), cwd=project)
    run(("git", "config", "user.email", "template-tests@example.invalid"), cwd=project)
    run(("git", "config", "user.name", "Template Tests"), cwd=project)
    rendered_files = sorted(
        str(path.relative_to(project)) for path in project.rglob("*") if path.is_file() and ".git" not in path.parts
    )
    if not rendered_files:
        raise TestFailure("Rendered project has no files to stage")
    run(("git", "add", "--", *rendered_files), cwd=project)
    staged = run(("git", "diff", "--cached", "--quiet"), cwd=project, expected_success=False)
    if staged.returncode == 1:
        run(("git", "commit", "-q", "-m", "init"), cwd=project)
    elif staged.returncode != 0:
        raise TestFailure("Unable to inspect the rendered project's staged files")


def require_docker() -> None:
    require_command("docker")
    result = run(("docker", "info"), capture=True, expected_success=False)
    if result.returncode != 0:
        raise TestFailure("Docker is required and its daemon must be running\n" + (result.stdout or ""))


def build_development_image(project: Path) -> None:
    run(
        (
            "docker",
            "build",
            "--platform",
            "linux/arm64",
            "--target",
            "development",
            "--tag",
            IMAGE_TAG,
            ".",
        ),
        cwd=project,
    )


def in_development_container(
    project: Path, *command: str, expected_success: bool = True
) -> subprocess.CompletedProcess[str]:
    return run(
        (
            "docker",
            "run",
            "--platform",
            "linux/arm64",
            "--rm",
            "--user",
            f"{os.getuid()}:{os.getgid()}",
            "--env",
            "XDG_CONFIG_HOME=/tmp/guardrails-config",
            "--env",
            "XDG_CACHE_HOME=/tmp/guardrails-cache",
            "--volume",
            f"{project.resolve()}:/src",
            "--workdir",
            "/src",
            IMAGE_TAG,
            *command,
        ),
        capture=not expected_success,
        expected_success=expected_success,
    )


def test_baseline(project: Path) -> None:
    require_docker()
    build_development_image(project)
    in_development_container(project, "just", "init")
    hook = project / ".git" / "hooks" / "pre-commit"
    if not hook.is_file() or not os.access(hook, os.X_OK):
        raise TestFailure("Generated pre-commit hook is missing or not executable after just init")
    in_development_container(project, "just", "ci")

    run(
        (
            "docker",
            "build",
            "--platform",
            "linux/arm64",
            "--target",
            "runtime",
            "--tag",
            RUNTIME_IMAGE_TAG,
            ".",
        ),
        cwd=project,
    )
    result = run(
        ("docker", "run", "--platform", "linux/arm64", "--rm", RUNTIME_IMAGE_TAG),
        capture=True,
        separate_stderr=True,
    )
    if result.stdout != "Hello, world!\n" or result.stderr:
        raise TestFailure(f"Runtime image output differs from the CLI contract: stdout={result.stdout!r}, stderr={result.stderr!r}")


def overlay_violation(project: Path, violation: Path) -> list[str]:
    overlaid: list[str] = []
    for source in sorted(violation.rglob("*")):
        if not source.is_file() or source.name in {"check", "expected"}:
            continue
        destination = project / source.relative_to(violation)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        # An old fixture timestamp must not let Ninja reuse the clean object.
        destination.touch()
        overlaid.append(str(destination.relative_to(project)))
    return overlaid


def test_violations(project: Path) -> None:
    if not VIOLATIONS.is_dir():
        raise TestFailure(f"Violation directory is missing: {VIOLATIONS}")
    violation_directories = sorted(path for path in VIOLATIONS.iterdir() if path.is_dir())
    if not violation_directories:
        raise TestFailure("No Raspberry Pi C++ violations were defined")

    for violation in violation_directories:
        check_file = violation / "check"
        expected_file = violation / "expected"
        if not check_file.is_file() or not expected_file.is_file():
            raise TestFailure(f"Violation is missing its check or expected file: {violation.name}")
        recipe = check_file.read_text(encoding="utf-8").strip()
        expected = expected_file.read_text(encoding="utf-8").strip()
        if not recipe or "\n" in recipe:
            raise TestFailure(f"Violation has an invalid check recipe: {violation.name}")
        if not expected or "\n" in expected:
            raise TestFailure(f"Violation has an invalid expected marker: {violation.name}")

        if recipe not in recipe_names(project / "justfile"):
            raise TestFailure(f"Violation {violation.name!r} selects missing recipe: {recipe}")

        overlaid = overlay_violation(project, violation)
        if not overlaid:
            raise TestFailure(f"Violation has no overlay files: {violation.name}")
        run(("git", "add", "--", *overlaid), cwd=project)
        result = in_development_container(project, "just", recipe, expected_success=False)
        if result.returncode == 0:
            raise TestFailure(
                f"Violation {violation.name!r} was not detected by 'just {recipe}'\n{result.stdout or ''}"
            )
        if expected not in (result.stdout or ""):
            raise TestFailure(
                f"Violation {violation.name!r} failed without its expected marker {expected!r}\n"
                f"{result.stdout or ''}"
            )
        print(f"PASS violation {violation.name}: just {recipe}", flush=True)
        run(("git", "reset", "-q", "--hard", "HEAD"), cwd=project)
        run(("git", "clean", "-qfd"), cwd=project)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", action="store_true", help="Skip violation overlays")
    parser.add_argument("--contracts", action="store_true", help="Run render and repository contracts only")
    parser.add_argument("--generated-project", type=Path, help="Test an already-rendered project")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    if arguments.generated_project is not None and (arguments.contracts or not arguments.baseline):
        raise TestFailure("--generated-project requires --baseline and cannot run destructive violation overlays")

    temporary_directory: Optional[tempfile.TemporaryDirectory] = None
    try:
        if arguments.generated_project is None:
            temporary_directory = tempfile.TemporaryDirectory(prefix="raspberry-pi-cpp-")
            project = render_project(Path(temporary_directory.name))
        else:
            project = arguments.generated_project.resolve()
            if not project.is_dir():
                raise TestFailure(f"Generated project does not exist: {project}")

        validate_contracts(project)
        print("PASS rendered Raspberry Pi C++ project contracts")
        if arguments.contracts:
            return 0

        if not arguments.baseline:
            initialize_git(project)
        test_baseline(project)
        print("PASS Raspberry Pi C++ container baseline")
        if not arguments.baseline:
            test_violations(project)
        return 0
    finally:
        if temporary_directory is not None:
            temporary_directory.cleanup()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except TestFailure as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1) from error
