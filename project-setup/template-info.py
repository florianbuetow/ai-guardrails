#!/usr/bin/env python3
"""List direct library dependency specs declared by each template."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
BLUEPRINTS_DIR = ROOT / "blueprints"
UNPINNED = "(unpinned)"
MANAGED = "(managed/no direct version)"


@dataclass(frozen=True)
class Dependency:
    group: str
    name: str
    spec: str
    source: str


def main() -> int:
    template_dirs = discover_template_dirs()
    for index, template_dir in enumerate(template_dirs):
        if index > 0:
            print()
        print(template_dir.parent.name)
        dependencies = collect_dependencies(template_dir)
        if not dependencies:
            print("  No library dependencies declared.")
            continue
        print_dependencies(dependencies)
    return 0


def discover_template_dirs() -> list[Path]:
    if not BLUEPRINTS_DIR.is_dir():
        print(f"Error: missing blueprints directory: {BLUEPRINTS_DIR}", file=sys.stderr)
        raise SystemExit(1)

    template_dirs = sorted(path / "template" for path in BLUEPRINTS_DIR.iterdir() if (path / "template").is_dir())
    if not template_dirs:
        print(f"Error: no template directories found in {BLUEPRINTS_DIR}", file=sys.stderr)
        raise SystemExit(1)
    return template_dirs


def collect_dependencies(template_dir: Path) -> list[Dependency]:
    dependencies: list[Dependency] = []
    manifest_parsers = (
        ("pyproject.toml.template", parse_python_manifest),
        ("build.gradle.kts.template", parse_gradle_manifest),
        ("go.mod.template", parse_go_manifest),
        ("mix.exs.template", parse_elixir_manifest),
        ("Cargo.toml.template", parse_rust_manifest),
        ("CMakeLists.txt.template", parse_cmake_manifest),
        ("scripts/bootstrap-vite.sh.template", parse_npm_bootstrap),
    )

    for relative_path, parser in manifest_parsers:
        manifest_path = template_dir / relative_path
        if manifest_path.is_file():
            dependencies.extend(parser(manifest_path))
    return dependencies


def print_dependencies(dependencies: list[Dependency]) -> None:
    groups: dict[str, list[Dependency]] = {}
    for dependency in dependencies:
        if dependency.group not in groups:
            groups[dependency.group] = []
        groups[dependency.group].append(dependency)

    for group, group_dependencies in groups.items():
        print(f"  {group}:")
        for dependency in group_dependencies:
            print(f"    {dependency.name:<48} {dependency.spec:<24} {dependency.source}")


def has_closing_array_bracket(text: str) -> bool:
    in_quote = False
    escaped = False

    for char in text:
        if escaped:
            escaped = False
            continue
        if char == "\\":
            escaped = True
            continue
        if char == '"':
            in_quote = not in_quote
            continue
        if char == "]" and not in_quote:
            return True
    return False


def parse_python_manifest(path: Path) -> list[Dependency]:
    dependencies: list[Dependency] = []
    section = ""
    active_array = ""
    active_group = ""

    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        section_match = re.fullmatch(r"\[([^\]]+)\]", stripped)
        if section_match:
            section = section_match.group(1)
            active_array = ""
            active_group = ""
            continue

        if active_array:
            for spec in quoted_strings(stripped):
                name, version_spec = split_python_requirement(spec)
                dependencies.append(Dependency(active_group, name, version_spec, path.name))
            if has_closing_array_bracket(stripped):
                active_array = ""
                active_group = ""
            continue

        assignment_match = re.match(r"([A-Za-z0-9_.-]+)\s*=\s*\[(.*)", stripped)
        if not assignment_match:
            continue

        key = assignment_match.group(1)
        remainder = assignment_match.group(2)
        group = python_dependency_group(section, key)
        if not group:
            continue

        for spec in quoted_strings(remainder):
            name, version_spec = split_python_requirement(spec)
            dependencies.append(Dependency(group, name, version_spec, path.name))

        if not has_closing_array_bracket(remainder):
            active_array = key
            active_group = group

    return dependencies


def python_dependency_group(section: str, key: str) -> str:
    if section == "project" and key == "dependencies":
        return "Python project dependencies"
    if section == "project.optional-dependencies":
        return f"Python optional dependencies [{key}]"
    return ""


def split_python_requirement(requirement: str) -> tuple[str, str]:
    match = re.match(r"([^<>=!~;\s]+)\s*(.*)", requirement)
    if not match:
        return requirement, UNPINNED
    name = match.group(1)
    spec = match.group(2).strip()
    if not spec:
        spec = UNPINNED
    return name, spec


def parse_gradle_manifest(path: Path) -> list[Dependency]:
    dependencies: list[Dependency] = []
    in_dependencies = False
    dependency_depth = 0

    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue

        if in_dependencies:
            dependency_depth += stripped.count("{") - stripped.count("}")
            dependencies.extend(parse_gradle_dependency_line(path, stripped))
            if dependency_depth <= 0:
                in_dependencies = False
            continue

        if re.match(r"dependencies\s*\{", stripped):
            in_dependencies = True
            dependency_depth = 1

    return dependencies


def parse_gradle_dependency_line(path: Path, stripped: str) -> list[Dependency]:
    dependency_match = re.match(r'([A-Za-z][A-Za-z0-9_]*)\((platform\()?\"([^\"]+)\"', stripped)
    if not dependency_match:
        return []

    configuration = dependency_match.group(1)
    if dependency_match.group(2):
        return []

    coordinate = dependency_match.group(3)
    name, spec = split_colon_coordinate(coordinate)
    return [Dependency(f"Gradle dependencies [{configuration}]", name, spec, path.name)]


def split_colon_coordinate(coordinate: str) -> tuple[str, str]:
    parts = coordinate.split(":")
    if len(parts) >= 3:
        return ":".join(parts[:-1]), parts[-1]
    return coordinate, MANAGED


def parse_go_manifest(path: Path) -> list[Dependency]:
    dependencies: list[Dependency] = []
    in_require_block = False

    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue

        if stripped == "require (":
            in_require_block = True
            continue
        if in_require_block and stripped == ")":
            in_require_block = False
            continue

        if in_require_block:
            dependencies.extend(parse_go_requirement(path, stripped))
            continue

        if stripped.startswith("require "):
            dependencies.extend(parse_go_requirement(path, stripped.removeprefix("require ").strip()))

    return dependencies


def parse_go_requirement(path: Path, stripped: str) -> list[Dependency]:
    clean = stripped.split("//", 1)[0].strip()
    parts = clean.split()
    if len(parts) != 2:
        return []
    return [Dependency("Go module requirements", parts[0], parts[1], path.name)]


def parse_elixir_manifest(path: Path) -> list[Dependency]:
    dependencies: list[Dependency] = []
    dep_pattern = re.compile(r"\{:(?P<name>[A-Za-z0-9_]+),\s+\"(?P<spec>[^\"]+)\"")

    for line in path.read_text(encoding="utf-8").splitlines():
        match = dep_pattern.search(line.strip())
        if match:
            dependencies.append(Dependency("Mix deps", match.group("name"), match.group("spec"), path.name))

    return dependencies


def parse_rust_manifest(path: Path) -> list[Dependency]:
    dependencies: list[Dependency] = []
    section = ""

    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        section_match = re.fullmatch(r"\[([^\]]+)\]", stripped)
        if section_match:
            section = section_match.group(1)
            continue

        if section not in {"dependencies", "dev-dependencies", "build-dependencies"}:
            continue

        dependency_match = re.match(r'([A-Za-z0-9_-]+)\s*=\s*"([^"]+)"', stripped)
        if dependency_match:
            dependencies.append(Dependency(f"Cargo {section}", dependency_match.group(1), dependency_match.group(2), path.name))
            continue

        table_match = re.match(r'([A-Za-z0-9_-]+)\s*=\s*\{.*version\s*=\s*"([^"]+)".*\}', stripped)
        if table_match:
            dependencies.append(Dependency(f"Cargo {section}", table_match.group(1), table_match.group(2), path.name))

    return dependencies


def parse_cmake_manifest(path: Path) -> list[Dependency]:
    dependencies: list[Dependency] = []
    active_name = ""
    awaiting_name = False

    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        declare_match = re.match(r"FetchContent_Declare\(\s*([A-Za-z0-9_-]+)", stripped)
        if declare_match:
            active_name = declare_match.group(1)
            continue

        if stripped == "FetchContent_Declare(":
            awaiting_name = True
            continue

        if awaiting_name:
            active_name = stripped.rstrip(",")
            awaiting_name = False
            continue

        if active_name:
            tag_match = re.match(r"GIT_TAG\s+(.+)", stripped)
            if tag_match:
                dependencies.append(Dependency("CMake FetchContent", active_name, tag_match.group(1), path.name))
                continue

            if stripped == ")":
                active_name = ""

    return dependencies


def parse_npm_bootstrap(path: Path) -> list[Dependency]:
    dependencies: list[Dependency] = []

    for line in shell_logical_lines(path):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        for name, spec in re.findall(r"devDependencies\.([A-Za-z0-9_@./-]+)=\"([^\"]+)\"", stripped):
            dependencies.append(Dependency("npm pinned devDependencies", name, spec, path.name))

        if stripped.startswith("npm install ") and "--save-dev" in stripped:
            for token in stripped.split():
                if token in {"npm", "install", "--save-dev"} or token.startswith("-"):
                    continue
                name, spec = split_npm_package(token)
                dependencies.append(Dependency("npm unpinned devDependencies", name, spec, path.name))

    return dependencies


def shell_logical_lines(path: Path) -> list[str]:
    logical_lines: list[str] = []
    active_parts: list[str] = []

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.rstrip()
        if stripped.endswith("\\"):
            active_parts.append(stripped[:-1].strip())
            continue
        active_parts.append(stripped.strip())
        logical_lines.append(" ".join(part for part in active_parts if part))
        active_parts = []

    if active_parts:
        print(f"Error: unterminated shell continuation in {path}", file=sys.stderr)
        raise SystemExit(1)

    return logical_lines


def split_npm_package(package_spec: str) -> tuple[str, str]:
    if package_spec.startswith("@"):
        slash_index = package_spec.find("/")
        at_index = package_spec.rfind("@")
        if slash_index != -1 and at_index > slash_index:
            return package_spec[:at_index], package_spec[at_index + 1 :]
        return package_spec, UNPINNED

    if "@" in package_spec:
        name, spec = package_spec.rsplit("@", 1)
        return name, spec
    return package_spec, UNPINNED


def quoted_strings(text: str) -> list[str]:
    return re.findall(r'"([^"]+)"', text)


if __name__ == "__main__":
    raise SystemExit(main())
