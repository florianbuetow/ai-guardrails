"""Deterministic codebase quality scorer.

Runs every guardrail check in machine-readable mode without stopping at the
first violation, counts violations per rule id, applies the weight table from
config/score/weights.toml, and writes reports/score/score.json.

Exit codes: 0 when scoring completes (any grade), 1 on operational failure
(missing tool, unexpected exit code, unparsable output, unmapped rule id).
"""

import json
import shutil
import subprocess
import sys
import tempfile
import tomllib
import xml.etree.ElementTree as ElementTree
from collections import Counter
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path


class ScorerError(Exception):
    """Operational failure that must abort scoring with exit code 1."""


@dataclass(frozen=True)
class Runner:
    """One guardrail check invoked in machine-readable mode.

    Attributes:
        name: Check name used in the report and the stdout table.
        command: Full command line, executed from the project root.
        findings_exit_code: Exit code the tool uses for "violations found".
        artifact: File the tool must freshly create, or None for stdout tools.
        artifact_on_success: Whether the tool also writes the artifact when it
            finds nothing (pytest always writes JUnit XML; deptry's behavior
            is verified in the template tests).
        parse: Maps captured stdout (and the artifact, if any) to violation
            counts keyed by full rule id.
    """

    name: str
    command: tuple[str, ...]
    findings_exit_code: int
    artifact: Path | None
    artifact_on_success: bool
    parse: Callable[[str, Path | None], Counter[str]]


def parse_ruff_check(stdout: str, artifact: Path | None) -> Counter[str]:
    """Count ruff check diagnostics per rule code."""
    counts: Counter[str] = Counter()
    for item in json.loads(stdout):
        code = item["code"]
        if code is None:
            counts["ruff/syntax-error"] += 1
        else:
            counts[f"ruff/{code}"] += 1
    return counts


def parse_ruff_format(stdout: str, artifact: Path | None) -> Counter[str]:
    """Count files that ruff format would rewrite."""
    files: set[str] = set()
    for item in json.loads(stdout):
        filename = item["filename"]
        if not filename:
            raise ScorerError(f"ruff format reported a finding without a filename: {item!r}")
        files.add(filename)
    counts: Counter[str] = Counter()
    if files:
        counts["ruff-format/would-reformat"] += len(files)
    return counts


def parse_mypy(stdout: str, artifact: Path | None) -> Counter[str]:
    """Count mypy error diagnostics per error code.

    Config-level notes (e.g. unused override sections) are emitted as plain
    text even in JSON mode; they are informational, not violations.
    """
    counts: Counter[str] = Counter()
    for line in stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if not stripped.startswith("{"):
            if ": note: " in stripped:
                continue
            raise ScorerError(f"mypy produced an unrecognized line: {stripped!r}")
        item = json.loads(stripped)
        if item["severity"] != "error":
            continue
        code = item["code"]
        if code is None:
            raise ScorerError(f"mypy reported an error without a code: {item['message']!r}")
        counts[f"mypy/{code}"] += 1
    return counts


def parse_pyright(stdout: str, artifact: Path | None) -> Counter[str]:
    """Count pyright error diagnostics per rule."""
    counts: Counter[str] = Counter()
    for item in json.loads(stdout)["generalDiagnostics"]:
        if item["severity"] != "error":
            continue
        if "rule" in item:
            counts[f"pyright/{item['rule']}"] += 1
        else:
            counts["pyright/no-rule"] += 1
    return counts


def parse_bandit(stdout: str, artifact: Path | None) -> Counter[str]:
    """Count bandit results per test id."""
    counts: Counter[str] = Counter()
    for item in json.loads(stdout)["results"]:
        counts[f"bandit/{item['test_id']}"] += 1
    return counts


def parse_semgrep(stdout: str, artifact: Path | None) -> Counter[str]:
    """Count semgrep findings per short rule id (last check_id segment).

    Aborts when semgrep reports scan errors or when two distinct full check
    ids collide on the same short id.
    """
    payload = json.loads(stdout)
    if payload["errors"]:
        raise ScorerError(f"semgrep reported scan errors: {payload['errors']!r}")
    full_ids_by_short: dict[str, set[str]] = {}
    counts: Counter[str] = Counter()
    for item in payload["results"]:
        check_id = item["check_id"]
        short = check_id.rsplit(".", 1)[-1]
        full_ids_by_short.setdefault(short, set()).add(check_id)
        counts[f"semgrep/{short}"] += 1
    for short, full_ids in full_ids_by_short.items():
        if len(full_ids) > 1:
            raise ScorerError(f"semgrep short id collision on {short!r}: {sorted(full_ids)}")
    return counts


def parse_codespell(stdout: str, artifact: Path | None) -> Counter[str]:
    """Count codespell findings (one per reported line)."""
    counts: Counter[str] = Counter()
    for line in stdout.splitlines():
        if not line.strip():
            continue
        if "==>" not in line:
            raise ScorerError(f"codespell produced an unrecognized line: {line!r}")
        counts["codespell/misspelling"] += 1
    return counts


def parse_pip_audit(stdout: str, artifact: Path | None) -> Counter[str]:
    """Count known vulnerabilities across all dependencies.

    The project's own package is reported with a skip_reason (it is not on
    PyPI) and carries no vulns list; anything else without vulns is an error.
    """
    counts: Counter[str] = Counter()
    for dependency in json.loads(stdout)["dependencies"]:
        if "vulns" not in dependency:
            if "skip_reason" in dependency:
                continue
            raise ScorerError(f"pip-audit dependency entry without vulns or skip_reason: {dependency!r}")
        vulnerability_count = len(dependency["vulns"])
        if vulnerability_count > 0:
            counts["pip-audit/vulnerability"] += vulnerability_count
    return counts


def parse_deptry(stdout: str, artifact: Path | None) -> Counter[str]:
    """Count deptry issues per DEP code from its JSON report."""
    if artifact is None:
        raise ScorerError("deptry runner requires an artifact path")
    counts: Counter[str] = Counter()
    for item in json.loads(artifact.read_text(encoding="utf-8")):
        counts[f"deptry/{item['error']['code']}"] += 1
    return counts


def make_junit_parser(rule_id: str) -> Callable[[str, Path | None], Counter[str]]:
    """Build a JUnit XML parser attributing failures and errors to one rule id."""

    def parse(stdout: str, artifact: Path | None) -> Counter[str]:
        """Count JUnit failures plus errors from the XML artifact."""
        if artifact is None:
            raise ScorerError("pytest runner requires an artifact path")
        root = ElementTree.parse(artifact).getroot()
        suites = [root] if root.tag == "testsuite" else list(root)
        total = 0
        for suite in suites:
            if suite.tag != "testsuite":
                raise ScorerError(f"unexpected JUnit element: {suite.tag!r}")
            total += int(suite.attrib["failures"]) + int(suite.attrib["errors"])
        counts: Counter[str] = Counter()
        if total > 0:
            counts[rule_id] += total
        return counts

    return parse


def build_runners(root: Path, run_tmp: Path) -> tuple[Runner, ...]:
    """Define every check runner, mirroring the justfile recipes' scope."""
    deptry_json = run_tmp / "deptry.json"
    pytest_unit_xml = run_tmp / "pytest-unit.xml"
    pytest_architecture_xml = run_tmp / "pytest-architecture.xml"
    markdown_files = tuple(sorted(path.name for path in root.glob("*.md")))
    toml_files = tuple(sorted(path.name for path in root.glob("*.toml")))
    return (
        Runner("ruff-check", ("uv", "run", "ruff", "check", ".", "--output-format", "json"), 1, None, False, parse_ruff_check),
        Runner(
            "ruff-format",
            ("uv", "run", "ruff", "format", "--check", "--output-format", "json", "."),
            1,
            None,
            False,
            parse_ruff_format,
        ),
        Runner("mypy", ("uv", "run", "mypy", "src/", "--output", "json"), 1, None, False, parse_mypy),
        Runner("pyright", ("uv", "run", "pyright", "--project", "pyrightconfig.json", "--outputjson"), 1, None, False, parse_pyright),
        Runner("bandit", ("uv", "run", "bandit", "-c", "pyproject.toml", "-r", "src", "-f", "json"), 1, None, False, parse_bandit),
        Runner("deptry", ("uv", "run", "deptry", "src", "--json-output", str(deptry_json)), 1, deptry_json, True, parse_deptry),
        Runner(
            "codespell",
            ("uv", "run", "codespell", "src", "tests", "scripts", *markdown_files, *toml_files),
            65,
            None,
            False,
            parse_codespell,
        ),
        Runner(
            "semgrep",
            ("uv", "run", "semgrep", "--config", "config/semgrep/", "--error", "--json", "src", "scripts", "tests", "pyproject.toml"),
            1,
            None,
            False,
            parse_semgrep,
        ),
        Runner(
            "pip-audit",
            (
                "uv",
                "run",
                "pip-audit",
                "-f",
                "json",
                "--ignore-vuln",
                "PYSEC-2026-2132",
                "--ignore-vuln",
                "CVE-2026-52870",
                "--ignore-vuln",
                "CVE-2026-52869",
                "--ignore-vuln",
                "CVE-2026-59950",
            ),
            1,
            None,
            False,
            parse_pip_audit,
        ),
        Runner(
            "pytest-unit",
            (
                "uv",
                "run",
                "pytest",
                "tests/",
                "--ignore=tests/architecture",
                "--continue-on-collection-errors",
                "--randomly-seed=12345",
                f"--junitxml={pytest_unit_xml}",
            ),
            1,
            pytest_unit_xml,
            True,
            make_junit_parser("pytest/test-failure"),
        ),
        Runner(
            "pytest-architecture",
            (
                "uv",
                "run",
                "pytest",
                "tests/architecture/",
                "--continue-on-collection-errors",
                "--randomly-seed=12345",
                f"--junitxml={pytest_architecture_xml}",
            ),
            1,
            pytest_architecture_xml,
            True,
            make_junit_parser("pytest/architecture-failure"),
        ),
    )


def run_runner(runner: Runner, root: Path) -> Counter[str]:
    """Execute one runner and return its cross-validated violation counts."""
    if runner.artifact is not None and runner.artifact.exists():
        raise ScorerError(f"{runner.name}: artifact {runner.artifact} already exists before the run")
    proc = subprocess.run(runner.command, capture_output=True, text=True, cwd=root, check=False)
    if proc.returncode not in (0, runner.findings_exit_code):
        raise ScorerError(f"{runner.name} exited with unexpected code {proc.returncode}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}")
    if runner.artifact is not None and not runner.artifact.exists():
        if proc.returncode == runner.findings_exit_code or runner.artifact_on_success:
            raise ScorerError(f"{runner.name} did not create its expected artifact {runner.artifact}")
        return Counter()
    try:
        counts = runner.parse(proc.stdout, runner.artifact)
    except (KeyError, IndexError, ValueError, ElementTree.ParseError) as exc:
        raise ScorerError(f"{runner.name} output could not be parsed: {exc}\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}") from exc
    total = sum(counts.values())
    if proc.returncode == 0 and total != 0:
        raise ScorerError(f"{runner.name} exited 0 but its output contains {total} findings")
    if proc.returncode == runner.findings_exit_code and total == 0:
        raise ScorerError(
            f"{runner.name} exited {proc.returncode} but its output contains no findings\nstdout:\n{proc.stdout}\nstderr:\n{proc.stderr}"
        )
    return counts


def load_weights(root: Path) -> dict[str, int]:
    """Load and validate the weight table."""
    weights_path = root / "config" / "score" / "weights.toml"
    try:
        payload = tomllib.loads(weights_path.read_text(encoding="utf-8"))
        raw_weights = payload["weights"]
    except (FileNotFoundError, tomllib.TOMLDecodeError, KeyError) as exc:
        raise ScorerError(f"could not load {weights_path}: {exc}") from exc
    weights: dict[str, int] = {}
    for rule_id, weight in raw_weights.items():
        if isinstance(weight, bool) or not isinstance(weight, int) or weight < 1:
            raise ScorerError(f"weight for {rule_id!r} must be a positive integer, got {weight!r}")
        weights[rule_id] = weight
    return weights


def collect_tool_versions(root: Path) -> dict[str, str]:
    """Record each tool's version (first line of its --version output)."""
    versions: dict[str, str] = {}
    for tool in ("bandit", "codespell", "deptry", "mypy", "pip-audit", "pyright", "pytest", "ruff", "semgrep"):
        proc = subprocess.run(("uv", "run", tool, "--version"), capture_output=True, text=True, cwd=root, check=False)
        if proc.returncode != 0:
            raise ScorerError(f"{tool} --version failed with code {proc.returncode}: {proc.stderr}")
        combined = (proc.stdout + proc.stderr).strip()
        if not combined:
            raise ScorerError(f"{tool} --version produced no output")
        versions[tool] = combined.splitlines()[0].strip()
    return versions


def build_report(runner_counts: dict[str, Counter[str]], weights: dict[str, int], versions: dict[str, str]) -> dict[str, object]:
    """Assemble the deterministic report payload."""
    checks: dict[str, object] = {}
    penalty = 0
    for name in sorted(runner_counts):
        counts = runner_counts[name]
        check_penalty = sum(count * weights[rule_id] for rule_id, count in counts.items())
        checks[name] = {
            "count": sum(counts.values()),
            "penalty": check_penalty,
            "violations": {rule_id: counts[rule_id] for rule_id in sorted(counts)},
        }
        penalty += check_penalty
    return {
        "schema_version": 1,
        "grade": max(0, 100 - penalty),
        "penalty": penalty,
        "tools": dict(sorted(versions.items())),
        "checks": checks,
    }


def write_report(report: dict[str, object], report_path: Path) -> None:
    """Write the report atomically with stable formatting."""
    serialized = json.dumps(report, indent=2, sort_keys=True) + "\n"
    tmp_path = report_path.with_name(report_path.name + ".tmp")
    tmp_path.write_text(serialized, encoding="utf-8")
    tmp_path.replace(report_path)


def print_report(report: dict[str, object], runner_counts: dict[str, Counter[str]], weights: dict[str, int]) -> None:
    """Print the per-rule violation table, total penalty, and grade."""
    print(f"{'check':<22}{'rule':<45}{'count':>6}{'weight':>8}{'penalty':>9}")
    for name in sorted(runner_counts):
        for rule_id in sorted(runner_counts[name]):
            count = runner_counts[name][rule_id]
            weight = weights[rule_id]
            print(f"{name:<22}{rule_id:<45}{count:>6}{weight:>8}{count * weight:>9}")
    penalty = report["penalty"]
    grade = report["grade"]
    print(f"\nTotal penalty: {penalty}")
    if penalty == 0:
        print(f"\033[0;32mGrade: {grade}/100\033[0m")
    else:
        print(f"\033[1;33mGrade: {grade}/100\033[0m")


def main() -> int:
    """Run all checks, score the codebase, and write the report."""
    root = Path(__file__).resolve().parent.parent
    report_path = root / "reports" / "score" / "score.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    if report_path.exists():
        report_path.unlink()
    weights = load_weights(root)
    run_tmp = Path(tempfile.mkdtemp(prefix="score-"))
    try:
        runner_counts: dict[str, Counter[str]] = {}
        merged: Counter[str] = Counter()
        for runner in build_runners(root, run_tmp):
            print(f"Running {runner.name} ...")
            counts = run_runner(runner, root)
            runner_counts[runner.name] = counts
            merged.update(counts)
        unmapped = sorted(rule_id for rule_id in merged if rule_id not in weights)
        if unmapped:
            snippet = "\n".join(f'"{rule_id}" = <weight>' for rule_id in unmapped)
            raise ScorerError(
                "violations fired for rule ids missing from config/score/weights.toml.\n"
                "Add entries under [weights] with positive integer weights:\n" + snippet
            )
        versions = collect_tool_versions(root)
        report = build_report(runner_counts, weights, versions)
        write_report(report, report_path)
        print_report(report, runner_counts, weights)
        return 0
    finally:
        shutil.rmtree(run_tmp)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except ScorerError as error:
        print(f"\033[0;31m✗ score failed: {error}\033[0m", file=sys.stderr)
        sys.exit(1)
