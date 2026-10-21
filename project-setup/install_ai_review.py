#!/usr/bin/env python3
"""Transactionally add the ai-review blueprint to the current project."""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from typing import NoReturn
import uuid


BLUEPRINT = Path(__file__).resolve().parents[1] / "blueprints" / "ai-review"
OWNED_PATHS = (
    Path("scripts/ai-review"),
    Path("config/ai-review"),
    Path("docs/ai-review.md"),
    Path("just/ai-review.just"),
)
JUSTFILE_NAMES = {"justfile", ".justfile"}
RECIPE_PATTERN = re.compile(r"^(ci-ai(?:-[A-Za-z0-9_-]+)?)(?:\s+[^:]*)?:", re.MULTILINE)
IMPORT_PATTERN = re.compile(
    r"^\s*(?:import\??\s+|mod\??\s+\S+\s+)['\"][^'\"]*ai-review(?:\.just)?['\"](?:\s*#.*)?$",
    re.MULTILINE,
)
IMPORT_BLOCK = (
    "# AI review commands: run `just ci-ai-help` to list providers and review domains.\n"
    "import 'just/ai-review.just'\n"
)


class InstallError(Exception):
    """A user-facing installation refusal or failure."""


def fail(message: str) -> NoReturn:
    raise InstallError(message)


def require_command(name: str) -> None:
    if shutil.which(name) is None:
        fail(f"{name} is required but was not found on PATH; nothing was changed")


def find_justfile(root: Path) -> Path | None:
    matches = [entry for entry in root.iterdir() if entry.name.casefold() in JUSTFILE_NAMES]
    if len(matches) > 1:
        names = ", ".join(sorted(entry.name for entry in matches))
        fail(f"multiple justfiles found ({names}); nothing was changed")
    if not matches:
        return None
    justfile = matches[0]
    if justfile.is_symlink():
        fail(f"{justfile.name} is a symlink; nothing was changed")
    if not justfile.is_file():
        fail(f"{justfile.name} is not a regular file; nothing was changed")
    if not os.access(justfile, os.W_OK):
        fail(f"{justfile.name} is not writable; nothing was changed")
    return justfile


def ensure_safe_destination(root: Path, relative: Path) -> None:
    destination = root / relative
    if destination.exists() or destination.is_symlink():
        fail(f"{relative.as_posix()} already exists; nothing was changed")
    current = root
    for component in relative.parent.parts:
        current /= component
        if current.is_symlink():
            fail(f"{current.relative_to(root).as_posix()} is a symlink; nothing was changed")
        if current.exists() and not current.is_dir():
            fail(f"{current.relative_to(root).as_posix()} is not a directory; nothing was changed")


def existing_candidate(text: str) -> str:
    recipes = sorted(set(RECIPE_PATTERN.findall(text)))
    if recipes:
        fail(f"existing AI review recipe conflicts with this installer: {', '.join(recipes)}; nothing was changed")
    if IMPORT_PATTERN.search(text):
        fail("an ai-review import already exists; nothing was changed")
    separator = "\n\n" if text.endswith("\n") else "\n\n\n"
    if not text:
        separator = ""
    return f"{text}{separator}{IMPORT_BLOCK}"


def preflight_existing_justfile(root: Path, justfile: Path) -> None:
    result = subprocess.run(
        ["just", "--justfile", str(justfile), "--working-directory", str(root), "--json"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        fail(f"the existing justfile is invalid: {detail}; nothing was changed")
    try:
        manifest = json.loads(result.stdout)
        names = set(manifest["recipes"]) | set(manifest["aliases"])
    except (json.JSONDecodeError, KeyError, TypeError) as error:
        fail(f"just returned an invalid recipe manifest: {error}; nothing was changed")
    conflicts = sorted(name for name in names if name == "ci-ai" or name.startswith("ci-ai-"))
    if conflicts:
        fail(f"existing AI review recipe conflicts with this installer: {', '.join(conflicts)}; nothing was changed")


def new_justfile() -> str:
    return """_default:
    @just help

help:
    @echo ""
    @printf "AI review commands:\\n"
    @printf "  %-28s %s\\n" "ci-ai-help" "List providers, review domains, and configuration"
    @echo ""
    @printf "\\033[32m✓ Help displayed\\033[0m\\n"
    @echo ""

# AI review commands: run `just ci-ai-help` to list providers and review domains.
import 'just/ai-review.just'
"""


def render_blueprint(staging: Path) -> None:
    if not BLUEPRINT.is_dir():
        fail(f"template not found: {BLUEPRINT}")
    result = subprocess.run(
        ["copier", "copy", "--defaults", "--trust", str(BLUEPRINT), str(staging)],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        fail(f"copier could not render the ai-review template: {detail}")
    missing = [path.as_posix() for path in OWNED_PATHS if not (staging / path).exists()]
    if missing:
        fail(f"rendered template is missing required paths: {', '.join(missing)}")


def make_parent_directories(root: Path, relative: Path, created: list[Path]) -> None:
    current = root
    for component in relative.parent.parts:
        current /= component
        if not current.exists():
            current.mkdir()
            created.append(current)


def remove_created(paths: list[Path]) -> None:
    for path in reversed(paths):
        if path.is_symlink() or path.is_file():
            path.unlink(missing_ok=True)
        elif path.is_dir():
            shutil.rmtree(path)


def validate_candidate(root: Path, candidate: Path) -> None:
    result = subprocess.run(
        ["just", "--justfile", str(candidate), "--working-directory", str(root), "--summary"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        fail(f"the resulting justfile is invalid: {detail}")
    required = {"ci-ai", "ci-ai-claude", "ci-ai-codex", "ci-ai-grok", "ci-ai-agy", "ci-ai-help"}
    available = set(result.stdout.split())
    missing = sorted(required - available)
    if missing:
        fail(f"the resulting justfile does not expose required recipes: {', '.join(missing)}")


def install() -> None:
    root = Path.cwd()
    require_command("copier")
    require_command("just")
    justfile = find_justfile(root)
    for path in OWNED_PATHS:
        ensure_safe_destination(root, path)

    if justfile:
        with justfile.open("r", encoding="utf-8", newline="") as source:
            existing_text = source.read()
    else:
        existing_text = None
    candidate_text = existing_candidate(existing_text) if existing_text is not None else new_justfile()
    if justfile:
        preflight_existing_justfile(root, justfile)
    target_justfile = justfile if justfile else root / "Justfile"
    candidate = root / f".ai-review-justfile-{uuid.uuid4().hex}"
    created: list[Path] = []

    with tempfile.TemporaryDirectory(prefix="ai-review-render-") as temporary_directory:
        staging = Path(temporary_directory)
        render_blueprint(staging)
        try:
            for relative in OWNED_PATHS:
                make_parent_directories(root, relative, created)
                source = staging / relative
                destination = root / relative
                created.append(destination)
                if source.is_symlink():
                    fail(f"rendered path must not be a symlink: {relative.as_posix()}")
                if source.is_dir():
                    shutil.copytree(source, destination)
                elif source.is_file():
                    shutil.copy2(source, destination)
                else:
                    fail(f"rendered path is not a regular file or directory: {relative.as_posix()}")

            with candidate.open("w", encoding="utf-8", newline="") as output:
                output.write(candidate_text)
            created.append(candidate)
            if justfile:
                shutil.copystat(justfile, candidate)
            validate_candidate(root, candidate)
            os.replace(candidate, target_justfile)
            created.remove(candidate)
        except BaseException:
            remove_created(created)
            raise

    print(f"\033[32m✓ Installed AI review commands in {root}\033[0m")
    print("Run `just ci-ai-help` to list providers and review domains.")


def main() -> int:
    if len(sys.argv) != 1:
        print("\033[31m✗ Error: install_ai_review.py takes no arguments\033[0m", file=sys.stderr)
        return 1
    try:
        install()
    except InstallError as error:
        print(f"\033[31m✗ Error: {error}\033[0m", file=sys.stderr)
        return 1
    except (OSError, UnicodeError) as error:
        print(f"\033[31m✗ Error: installation failed and was rolled back: {error}\033[0m", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
