#!/usr/bin/env python3
"""Enforce C++ layer boundaries using dependencies emitted by the configured compiler."""

from __future__ import annotations

import json
import shlex
import subprocess
import sys
from collections.abc import Iterable
from pathlib import Path
from typing import NoReturn


LAYERS = {"cli", "application", "domain", "simd"}
ALLOWED = {
    "domain": {"domain"},
    "application": {"application", "domain", "simd"},
    "simd": {"simd", "domain"},
    "cli": {"cli", "application"},
}
SOURCE_SUFFIXES = {".cpp", ".cc", ".cxx", ".c", ".C"}


def fail(message: str) -> NoReturn:
    print(f"architecture failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_database(path: Path) -> list[dict[str, object]]:
    if not path.is_file():
        fail(f"compilation database does not exist: {path}")
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read {path}: {error}")
    if not isinstance(value, list) or not value:
        fail(f"compilation database is empty or invalid: {path}")
    if not all(isinstance(entry, dict) for entry in value):
        fail("every compilation database entry must be a JSON object")
    return value


def entry_argv(entry: dict[str, object]) -> list[str]:
    arguments = entry.get("arguments")
    command = entry.get("command")
    if isinstance(arguments, list) and all(isinstance(item, str) for item in arguments):
        return list(arguments)
    if isinstance(command, str):
        try:
            return shlex.split(command)
        except ValueError as error:
            fail(f"invalid command in compilation database: {error}")
    fail("compilation entry must contain arguments or command")


def entry_path(entry: dict[str, object]) -> Path:
    directory = entry.get("directory")
    filename = entry.get("file")
    if not isinstance(directory, str) or not isinstance(filename, str):
        fail("compilation entry is missing directory or file")
    path = Path(filename)
    return (Path(directory) / path if not path.is_absolute() else path).resolve()


def dependency_command(entry: dict[str, object], target: Path) -> tuple[list[str], Path]:
    argv = entry_argv(entry)
    directory_value = entry.get("directory")
    if not isinstance(directory_value, str):
        fail("compilation entry is missing directory")
    directory = Path(directory_value)
    original = entry_path(entry)
    result: list[str] = []
    skip_next = False
    options_with_values = {"-o", "-MF", "-MT", "-MQ", "-MJ", "--serialize-diagnostics"}
    for index, argument in enumerate(argv):
        if skip_next:
            skip_next = False
            continue
        if argument in options_with_values:
            skip_next = True
            continue
        if argument == "-c" or argument in {"-M", "-MM", "-MD", "-MMD", "-MP"}:
            continue
        if argument.startswith(("-MF", "-MT", "-MQ", "-MJ", "-o")):
            continue
        candidate = Path(argument)
        if argument == str(original) or (
            index > 0
            and candidate.suffix in SOURCE_SUFFIXES
            and (directory / candidate).resolve() == original
        ):
            continue
        result.append(argument)
    if not result:
        fail("compiler command became empty while preparing dependency scan")
    result.extend(["-MM", "-MT", "dependency-target", str(target)])
    return result, directory


def parse_dependencies(output: str, directory: Path) -> set[Path]:
    logical = output.replace("\\\n", " ")
    if ":" not in logical:
        fail("compiler dependency output has no target separator")
    dependency_text = logical.split(":", 1)[1]
    try:
        tokens = shlex.split(dependency_text)
    except ValueError as error:
        fail(f"cannot parse compiler dependency output: {error}")
    dependencies: set[Path] = set()
    for token in tokens:
        path = Path(token.replace("\\ ", " "))
        dependencies.add((directory / path if not path.is_absolute() else path).resolve())
    return dependencies


def scan(entry: dict[str, object], target: Path) -> set[Path]:
    command, directory = dependency_command(entry, target)
    result = subprocess.run(
        command,
        cwd=directory,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "compiler returned no diagnostics"
        fail(f"compiler dependency scan failed for {target}: {detail}")
    if result.stderr.strip():
        fail(f"compiler emitted diagnostics while scanning {target}: {result.stderr.strip()}")
    return parse_dependencies(result.stdout, directory)


def layer(path: Path) -> str | None:
    for part in path.parts:
        if part in LAYERS:
            return part
    return None


def find_cycle(graph: dict[Path, set[Path]]) -> list[Path] | None:
    visited: set[Path] = set()
    active: list[Path] = []
    active_set: set[Path] = set()

    def visit(node: Path) -> list[Path] | None:
        if node in active_set:
            start = active.index(node)
            return active[start:] + [node]
        if node in visited:
            return None
        active.append(node)
        active_set.add(node)
        for dependency in graph.get(node, set()):
            cycle = visit(dependency)
            if cycle is not None:
                return cycle
        active.pop()
        active_set.remove(node)
        visited.add(node)
        return None

    for node in graph:
        cycle = visit(node)
        if cycle is not None:
            return cycle
    return None


def relative_list(paths: Iterable[Path], root: Path) -> str:
    return ", ".join(str(path.relative_to(root)) for path in sorted(paths))


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: check-architecture.py COMPILE_COMMANDS_JSON")
    database_path = Path(sys.argv[1]).resolve()
    entries = load_database(database_path)
    root = next((parent for parent in database_path.parents if (parent / "src").is_dir()), None)
    if root is None:
        fail(f"cannot locate project root above {database_path}")
    project_files = {
        path.resolve()
        for base in (root / "src", root / "include")
        for path in base.rglob("*")
        if path.is_file() and path.suffix in SOURCE_SUFFIXES | {".h", ".hh", ".hpp", ".hxx"}
    }
    if not project_files:
        fail("no production C++ source or header files found")
    unclassified = {path for path in project_files if layer(path.relative_to(root)) is None}
    if unclassified:
        fail("production files outside cli/application/domain/simd: " + relative_list(unclassified, root))

    production_entries = [entry for entry in entries if entry_path(entry).is_relative_to(root / "src")]
    if not production_entries:
        fail("compilation database contains no production source entries")
    by_source = {entry_path(entry): entry for entry in production_entries}
    representative = production_entries[0]
    graph: dict[Path, set[Path]] = {}
    violations: list[str] = []
    for source in sorted(project_files):
        dependencies = scan(by_source.get(source, representative), source)
        project_dependencies = {path for path in dependencies if path in project_files and path != source}
        graph[source] = project_dependencies
        source_layer = layer(source.relative_to(root))
        if source_layer is None:
            fail(f"cannot classify {source.relative_to(root)}")
        for dependency in sorted(project_dependencies):
            dependency_layer = layer(dependency.relative_to(root))
            if dependency_layer not in ALLOWED[source_layer]:
                violations.append(
                    f"{source.relative_to(root)} ({source_layer}) depends on "
                    f"{dependency.relative_to(root)} ({dependency_layer})"
                )
        test_dependencies = {
            path for path in dependencies if path.is_relative_to(root / "tests")
        }
        if test_dependencies:
            violations.append(
                f"{source.relative_to(root)} depends on test files: "
                + relative_list(test_dependencies, root)
            )
    if violations:
        fail("; ".join(violations))
    cycle = find_cycle(graph)
    if cycle is not None:
        fail("dependency cycle: " + " -> ".join(str(path.relative_to(root)) for path in cycle))
    print(f"architecture passed: compiler resolved dependencies for {len(project_files)} files")


if __name__ == "__main__":
    main()
