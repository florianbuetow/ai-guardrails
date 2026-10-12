#!/usr/bin/env python3
"""Prove that every project C++ source is present in the compilation database."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import NoReturn

SOURCE_SUFFIXES = {".c", ".cc", ".cpp", ".cxx"}


def fail(message: str) -> NoReturn:
    print(f"source inventory failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_database(path: Path) -> list[dict[str, object]]:
    if not path.is_file():
        fail(f"compilation database does not exist: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read {path}: {error}")
    if not isinstance(value, list) or not value:
        fail(f"compilation database is empty or is not a JSON array: {path}")
    if not all(isinstance(entry, dict) for entry in value):
        fail("every compilation database entry must be a JSON object")
    return value


def resolve_entry_file(entry: dict[str, object]) -> Path:
    directory = entry.get("directory")
    filename = entry.get("file")
    if not isinstance(directory, str) or not isinstance(filename, str):
        fail("each compilation entry must contain string directory and file fields")
    candidate = Path(filename)
    if not candidate.is_absolute():
        candidate = Path(directory) / candidate
    return candidate.resolve()


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: check-source-inventory.py COMPILE_COMMANDS_JSON")
    database_path = Path(sys.argv[1]).resolve()
    entries = load_database(database_path)
    project_root = next(
        (parent for parent in database_path.parents if (parent / "src").is_dir()), None
    )
    if project_root is None:
        fail(f"cannot locate project root above {database_path}")

    production = {
        path.resolve()
        for path in (project_root / "src").rglob("*")
        if path.is_file() and path.suffix in SOURCE_SUFFIXES
    }
    tests = {
        path.resolve()
        for path in (project_root / "tests").rglob("*")
        if path.is_file() and path.suffix in SOURCE_SUFFIXES
    }
    if not production:
        fail("src contains no C++ source files")
    if not tests:
        fail("tests contains no C++ source files")

    compiled = {resolve_entry_file(entry) for entry in entries}
    project_compiled = {
        path for path in compiled if path.is_relative_to(project_root / "src")
        or path.is_relative_to(project_root / "tests")
    }
    expected = production | tests
    missing = sorted(expected - project_compiled)
    unexpected = sorted(project_compiled - expected)
    if missing:
        fail("uncompiled source files: " + ", ".join(str(path.relative_to(project_root)) for path in missing))
    if unexpected:
        fail("compiled project files outside the source inventory: " + ", ".join(str(path.relative_to(project_root)) for path in unexpected))

    print(f"source inventory passed: {len(production)} production and {len(tests)} test sources")


if __name__ == "__main__":
    main()
