#!/usr/bin/env python3
"""Structural and rendering contracts for the Swift macOS blueprint."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = REPO_ROOT / "blueprints" / "switftmac"
VIOLATIONS = REPO_ROOT / "violations" / "switftmac"
REQUIRED_RECIPES = {
    "bootstrap-check",
    "init",
    "check",
    "build",
    "run",
    "code-format",
    "code-style",
    "code-analyze",
    "code-architecture",
    "code-semgrep",
    "code-security",
    "code-secrets",
    "code-shell",
    "code-spell",
    "code-dependencies",
    "code-docs",
    "code-package",
    "test",
    "test-ui",
    "test-accessibility",
    "test-snapshots",
    "test-coverage",
    "test-sanitize",
    "test-performance",
    "performance-baseline",
    "coverage-export",
    "debug",
    "profile",
    "memory",
    "release",
    "ci",
}


def run(
    command: list[str],
    cwd: Path,
    environment: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        env=environment,
        text=True,
        capture_output=True,
        check=False,
    )


class SwiftMacTemplateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        missing = [command for command in ("copier", "just", "xcrun") if shutil.which(command) is None]
        if missing:
            raise AssertionError("Required test commands are unavailable: " + ", ".join(missing))
        cls.verifier_directory = tempfile.TemporaryDirectory(prefix="switftmac-verifier-binary-")
        cls.addClassCleanup(cls.verifier_directory.cleanup)
        verifier_root = Path(cls.verifier_directory.name)
        module_cache = verifier_root / "module-cache"
        module_cache.mkdir()
        environment = os.environ.copy()
        environment["SWIFT_MODULECACHE_PATH"] = str(module_cache)
        environment["CLANG_MODULE_CACHE_PATH"] = str(module_cache)
        source = TEMPLATE / "template" / "scripts" / "verify.swift"
        cls.verifier_executable = verifier_root / "verify"
        compilation = run(
            ["xcrun", "swiftc", str(source), "-o", str(cls.verifier_executable)],
            REPO_ROOT,
            environment,
        )
        if compilation.returncode != 0:
            raise AssertionError(compilation.stdout + compilation.stderr)
        performance_source = TEMPLATE / "template" / "scripts" / "performance.swift"
        cls.performance_executable = verifier_root / "performance"
        compilation = run(
            ["xcrun", "swiftc", str(performance_source), "-o", str(cls.performance_executable)],
            REPO_ROOT,
            environment,
        )
        if compilation.returncode != 0:
            raise AssertionError(compilation.stdout + compilation.stderr)

    def render(self, destination: Path) -> subprocess.CompletedProcess[str]:
        return run(
            [
                "copier",
                "copy",
                "--trust",
                "--skip-tasks",
                "--defaults",
                "--data",
                "project_name=fixture-app",
                "--data",
                "bundle_identifier=com.example.fixtureapp",
                "--data",
                "project_description=Fixture native macOS application",
                str(TEMPLATE),
                str(destination),
            ],
            REPO_ROOT,
        )

    def run_verifier(
        self,
        mode: str,
        report: dict[str, object],
        quality: dict[str, object] | None = None,
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory(prefix="switftmac-verifier-") as temporary_directory:
            working_directory = Path(temporary_directory)
            report_path = working_directory / "report.json"
            report_path.write_text(json.dumps(report), encoding="utf-8")
            if quality is not None:
                config = working_directory / "config"
                config.mkdir()
                (config / "quality.json").write_text(json.dumps(quality), encoding="utf-8")
            return run(
                [str(self.verifier_executable), mode, str(report_path)],
                working_directory,
            )

    def graph_report(self, targets: dict[str, object]) -> dict[str, object]:
        return {
            "settings": {
                "base": {
                    "SWIFT_VERSION": "6.0",
                    "SWIFT_STRICT_CONCURRENCY": "complete",
                    "SWIFT_TREAT_WARNINGS_AS_ERRORS": True,
                    "MACOSX_DEPLOYMENT_TARGET": "26.0",
                    "OTHER_SWIFT_FLAGS": ["$(inherited)", "-strict-memory-safety"],
                }
            },
            "targets": {
                **targets,
                "AppTests": {"dependencies": []},
                "AppUITests": {"dependencies": [{"target": "App"}]},
                "PerformanceTests": {"dependencies": [{"target": "App"}]},
            },
        }

    def performance_report(
        self,
        measurements: list[float],
        device_id: str = "runner-1",
    ) -> list[dict[str, object]]:
        return [
            {
                "testIdentifier": "PerformanceTests/AppLaunchPerformanceTests/testLaunchPerformance()",
                "testRuns": [
                    {
                        "testPlanConfiguration": {
                            "configurationId": "performance",
                            "configurationName": "Performance",
                        },
                        "device": {"deviceId": device_id, "deviceName": "Review Mac"},
                        "metrics": [
                            {
                                "displayName": "Application Launch",
                                "unitOfMeasurement": "s",
                                "measurements": measurements,
                                "identifier": "com.apple.XCTPerformanceMetric_ApplicationLaunch",
                            }
                        ],
                    }
                ],
            }
        ]

    def run_performance(
        self,
        mode: str,
        report: object,
        baseline: object | None = None,
    ) -> tuple[subprocess.CompletedProcess[str], Path | None]:
        temporary = tempfile.TemporaryDirectory(prefix="switftmac-performance-")
        self.addCleanup(temporary.cleanup)
        working_directory = Path(temporary.name)
        config = working_directory / "config"
        config.mkdir()
        (config / "quality.json").write_text(
            json.dumps({"performanceIterations": 10, "performanceRegressionPercent": 20}),
            encoding="utf-8",
        )
        metrics_path = working_directory / "metrics.json"
        metrics_path.write_text(json.dumps(report), encoding="utf-8")
        baseline_path = config / "performance-baseline.json"
        if baseline is not None:
            baseline_path.write_text(json.dumps(baseline), encoding="utf-8")
        result = run(
            [str(self.performance_executable), mode, str(metrics_path), str(baseline_path)],
            working_directory,
        )
        return result, baseline_path if baseline_path.exists() else None

    def test_rendered_project_exposes_the_complete_guardrail_surface(self) -> None:
        with tempfile.TemporaryDirectory(prefix="switftmac-contract-") as temporary_directory:
            project = Path(temporary_directory) / "fixture-app"
            result = self.render(project)
            self.assertEqual(0, result.returncode, result.stdout + result.stderr)

            summary = run(["just", "--summary"], project)
            self.assertEqual(0, summary.returncode, summary.stdout + summary.stderr)
            recipes = set(summary.stdout.split())
            self.assertTrue(REQUIRED_RECIPES <= recipes, sorted(REQUIRED_RECIPES - recipes))

            self.assertTrue((project / "project.yml").is_file())
            self.assertTrue((project / "Tools" / "Guardrails" / "Package.swift").is_file())
            self.assertTrue((project / "README.md").is_file())
            self.assertTrue((project / "AGENTS.md").is_file())
            self.assertTrue((project / "scripts" / "bootstrap.sh").is_file())
            self.assertTrue((project / "scripts" / "check-tools.sh").is_file())
            self.assertTrue((project / "config" / "performance.schema.json").is_file())
            self.assertFalse((project / "fixture-app").exists(), "Copier rendered a duplicate project tree")

            native_tools = {
                line.split("\t", 1)[0]
                for line in (project / "config" / "tools.lock.tsv").read_text(encoding="utf-8").splitlines()
                if line
            }
            self.assertEqual(
                {"uv", "xcodegen", "swiftlint", "shellcheck", "shfmt", "gitleaks", "osv-scanner"},
                native_tools,
            )
            python_tools = (project / "config" / "python-tools.in").read_text(encoding="utf-8")
            self.assertIn("semgrep==", python_tools)
            self.assertIn("codespell==", python_tools)
            performance_schema = json.loads(
                (project / "config" / "performance.schema.json").read_text(encoding="utf-8")
            )
            self.assertEqual(1, performance_schema["properties"]["schemaVersion"]["const"])

            rendered_files = [path for path in project.rglob("*") if path.is_file()]
            self.assertTrue(rendered_files)
            empty_directories = [
                path.relative_to(project)
                for path in project.rglob("*")
                if path.is_dir() and not any(path.iterdir())
            ]
            self.assertFalse(empty_directories, f"empty rendered directories: {empty_directories}")
            for path in rendered_files:
                if path.is_symlink():
                    continue
                contents = path.read_bytes()
                for just_parameter in (b"{{pid}}", b"{{profile}}", b"{{binary}}"):
                    contents = contents.replace(just_parameter, b"")
                self.assertNotIn(b"{{", contents, f"unrendered template expression in {path}")
                self.assertNotIn(b"{%", contents, f"unrendered template statement in {path}")

    def test_host_preflight_pins_the_approved_platform_and_toolchain(self) -> None:
        check_host = (TEMPLATE / "template" / "scripts" / "check-host.sh").read_text(encoding="utf-8")
        for required_text in ("Darwin", "arm64", "26.6", "27A266a", "6.4"):
            self.assertIn(required_text, check_host)

    def test_performance_test_uses_the_configured_iteration_count(self) -> None:
        quality = json.loads(
            (TEMPLATE / "template" / "config" / "quality.json").read_text(encoding="utf-8")
        )
        performance_test = (
            TEMPLATE
            / "template"
            / "UITests"
            / "PerformanceTests"
            / "AppLaunchPerformanceTests.swift.template"
        ).read_text(encoding="utf-8")
        self.assertIn(
            f"iterationCount = {quality['performanceIterations']}",
            performance_test,
        )

    def test_violation_fixtures_exercise_distinct_guardrail_layers(self) -> None:
        self.assertTrue(VIOLATIONS.is_dir(), "missing Swift macOS violation suite")
        fixtures = sorted(path for path in VIOLATIONS.iterdir() if path.is_dir())
        self.assertGreaterEqual(len(fixtures), 5)
        recipes = set()
        for fixture in fixtures:
            check_file = fixture / "check"
            self.assertTrue(check_file.is_file(), f"missing check metadata: {fixture.name}")
            recipe = check_file.read_text(encoding="utf-8").strip()
            self.assertTrue(recipe, f"empty check metadata: {fixture.name}")
            recipes.add(recipe)
        self.assertTrue(
            {"code-style", "code-architecture", "code-semgrep", "code-security", "code-secrets"}
            <= recipes,
            f"missing guardrail fixture coverage: {recipes}",
        )

    def test_invalid_answers_are_rejected_before_rendering(self) -> None:
        invalid_cases = (
            ("project_name=Fixture App", "bundle_identifier=com.example.fixtureapp"),
            ("project_name=fixture-app", "bundle_identifier=not-a-bundle-identifier"),
        )
        for project_name, bundle_identifier in invalid_cases:
            with self.subTest(project_name=project_name, bundle_identifier=bundle_identifier):
                with tempfile.TemporaryDirectory(prefix="switftmac-invalid-") as temporary_directory:
                    destination = Path(temporary_directory) / "invalid"
                    result = run(
                        [
                            "copier",
                            "copy",
                            "--trust",
                            "--skip-tasks",
                            "--defaults",
                            "--data",
                            project_name,
                            "--data",
                            bundle_identifier,
                            str(TEMPLATE),
                            str(destination),
                        ],
                        REPO_ROOT,
                    )
                    self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)
                    self.assertFalse(destination.exists(), "invalid answers left a generated project")

    def test_shared_runner_stops_when_prerequisites_fail(self) -> None:
        with tempfile.TemporaryDirectory(prefix="runner-prerequisite-") as temporary_directory:
            language_config = Path(temporary_directory) / "failure.sh"
            language_config.write_text(
                """LANG_NAME='Failing fixture'
TEMPLATE_DIR='switftmac'
PROJECT_NAME='must-not-generate'
COPIER_DATA=()
check_prerequisites() { return 23; }
""",
                encoding="utf-8",
            )
            script = f"""set -euo pipefail
source tests/lib/helpers.sh
source tests/lib/runner.sh
LANG_CONFIG_FILE={shlex.quote(str(language_config))}
LANG_SLUG=failing-fixture
run_language_tests
"""

            result = run(["bash", "-c", script], REPO_ROOT)

        self.assertNotEqual(0, result.returncode)
        self.assertIn("prerequisites failed", result.stdout + result.stderr)
        self.assertNotIn("project setup", result.stdout + result.stderr)

    def test_project_generator_propagates_copier_failure_before_git_setup(self) -> None:
        with tempfile.TemporaryDirectory(prefix="runner-copier-") as temporary_directory:
            script = f"""set -euo pipefail
source tests/lib/helpers.sh
copier() {{ return 19; }}
git() {{ printf 'git must not run after Copier failure\\n' >&2; return 91; }}
TEMPLATE_DIR=switftmac
PROJECT_NAME=must-not-generate
COPIER_DATA=()
generate_project {shlex.quote(temporary_directory)}
"""

            result = run(["bash", "-c", script], REPO_ROOT)

        self.assertNotEqual(0, result.returncode)
        self.assertNotIn("git must not run", result.stdout + result.stderr)

    def test_result_verifier_rejects_empty_skipped_and_failed_test_reports(self) -> None:
        invalid_reports = (
            {
                "totalTestCount": 0,
                "passedTests": 0,
                "failedTests": 0,
                "skippedTests": 0,
                "expectedFailures": 0,
                "result": "Passed",
            },
            {
                "totalTestCount": 2,
                "passedTests": 1,
                "failedTests": 0,
                "skippedTests": 1,
                "expectedFailures": 0,
                "result": "Passed",
            },
            {
                "totalTestCount": 1,
                "passedTests": 0,
                "failedTests": 1,
                "skippedTests": 0,
                "expectedFailures": 0,
                "result": "Failed",
            },
        )
        for report in invalid_reports:
            with self.subTest(report=report):
                result = self.run_verifier("tests", report)
                self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)

    def test_result_verifier_rejects_missing_and_low_coverage_targets(self) -> None:
        quality = {"coveragePercent": 80.0, "coverageTargets": ["AppDomain", "AppApplication"]}
        invalid_reports = (
            {"targets": [{"name": "AppDomain", "executableLines": 10, "coveredLines": 10}]},
            {
                "targets": [
                    {"name": "AppDomain", "executableLines": 10, "coveredLines": 7},
                    {"name": "AppApplication", "executableLines": 10, "coveredLines": 10},
                ]
            },
        )
        for report in invalid_reports:
            with self.subTest(report=report):
                result = self.run_verifier("coverage", report, quality)
                self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)

    def test_result_verifier_rejects_missing_and_forbidden_graph_edges(self) -> None:
        valid_targets: dict[str, object] = {
            "AppDomain": {"dependencies": []},
            "AppApplication": {"dependencies": [{"target": "AppDomain"}]},
            "AppInfrastructure": {
                "dependencies": [{"target": "AppDomain"}, {"target": "AppApplication"}]
            },
            "AppUI": {"dependencies": [{"target": "AppApplication"}]},
            "App": {
                "dependencies": [
                    {"target": "AppDomain"},
                    {"target": "AppApplication"},
                    {"target": "AppInfrastructure"},
                    {"target": "AppUI"},
                ]
            },
        }
        missing = dict(valid_targets)
        missing.pop("AppDomain")
        forbidden = dict(valid_targets)
        forbidden["AppDomain"] = {"dependencies": [{"target": "AppUI"}]}
        extra = dict(valid_targets)
        extra["UnscannedModule"] = {"dependencies": []}
        malformed = dict(valid_targets)
        malformed["AppDomain"] = {"dependencies": [{"framework": "Unexpected.framework"}]}

        for report in (
            self.graph_report(missing), self.graph_report(forbidden),
            self.graph_report(extra), self.graph_report(malformed),
        ):
            with self.subTest(report=report):
                result = self.run_verifier("graph", report)
                self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)

    def test_scanner_report_requires_actual_successful_scanning(self) -> None:
        valid = {"paths": {"scanned": ["Sources/AppDomain/Workspace.swift"]}, "results": [], "errors": []}
        result = self.run_verifier("scanner", valid)
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        reports = (
            {"paths": {"scanned": []}, "results": [], "errors": []},
            {"paths": {"scanned": ["file.swift"]}, "results": [], "errors": ["parse error"]},
            {"paths": {"scanned": ["file.swift"]}, "results": ["finding"], "errors": []},
            {"paths": {}, "results": [], "errors": []},
        )
        for report in reports:
            with self.subTest(report=report):
                result = self.run_verifier("scanner", report)
                self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)

    def test_result_verifier_rejects_unsafe_or_malformed_transport_policy(self) -> None:
        invalid_reports = (
            {"NSAppTransportSecurity": "invalid"},
            {"NSAppTransportSecurity": {"NSAllowsArbitraryLoads": True}},
            {"NSAppTransportSecurity": {"NSAllowsArbitraryLoadsInWebContent": "false"}},
            {"NSAppTransportSecurity": {"NSExceptionDomains": {"example.com": {}}}},
        )
        for report in invalid_reports:
            with self.subTest(report=report):
                result = self.run_verifier("bundle", report)
                self.assertNotEqual(0, result.returncode, result.stdout + result.stderr)

    def test_result_verifier_accepts_complete_reports(self) -> None:
        tests = self.run_verifier(
            "tests",
            {
                "totalTestCount": 2,
                "passedTests": 2,
                "failedTests": 0,
                "skippedTests": 0,
                "expectedFailures": 0,
                "result": "Passed",
            },
        )
        self.assertEqual(0, tests.returncode, tests.stdout + tests.stderr)

        coverage = self.run_verifier(
            "coverage",
            {"targets": [{"name": "AppDomain", "executableLines": 10, "coveredLines": 8}]},
            {"coveragePercent": 80.0, "coverageTargets": ["AppDomain"]},
        )
        self.assertEqual(0, coverage.returncode, coverage.stdout + coverage.stderr)

        graph = self.run_verifier(
            "graph",
            self.graph_report(
                {
                    "AppDomain": {"dependencies": []},
                    "AppApplication": {"dependencies": [{"target": "AppDomain"}]},
                    "AppInfrastructure": {
                        "dependencies": [{"target": "AppDomain"}, {"target": "AppApplication"}]
                    },
                    "AppUI": {"dependencies": [{"target": "AppApplication"}]},
                    "App": {
                        "dependencies": [
                            {"target": "AppDomain"},
                            {"target": "AppApplication"},
                            {"target": "AppInfrastructure"},
                            {"target": "AppUI"},
                        ]
                    },
                }
            ),
        )
        self.assertEqual(0, graph.returncode, graph.stdout + graph.stderr)

        bundle = self.run_verifier(
            "bundle",
            {"NSAppTransportSecurity": {"NSAllowsArbitraryLoads": False}},
        )
        self.assertEqual(0, bundle.returncode, bundle.stdout + bundle.stderr)

    def test_performance_calibration_and_reviewed_baseline_gate(self) -> None:
        calibration, baseline_path = self.run_performance(
            "calibrate",
            self.performance_report([1.0] * 10),
        )
        self.assertEqual(0, calibration.returncode, calibration.stdout + calibration.stderr)
        self.assertIsNotNone(baseline_path)
        assert baseline_path is not None
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))

        verification, _ = self.run_performance(
            "verify",
            self.performance_report([1.19] * 10),
            baseline,
        )
        self.assertEqual(0, verification.returncode, verification.stdout + verification.stderr)

    def test_performance_gate_rejects_missing_or_unusable_evidence(self) -> None:
        calibration, baseline_path = self.run_performance(
            "calibrate",
            self.performance_report([1.0] * 10),
        )
        self.assertEqual(0, calibration.returncode, calibration.stdout + calibration.stderr)
        assert baseline_path is not None
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))

        invalid_cases = (
            (self.performance_report([1.0] * 10), None),
            ([], baseline),
            (self.performance_report([1.0] * 9), baseline),
            (self.performance_report([1.0] * 10, device_id="other-runner"), baseline),
            (self.performance_report([1.21] * 10), baseline),
        )
        for report, candidate_baseline in invalid_cases:
            with self.subTest(report=report, baseline=candidate_baseline):
                verification, _ = self.run_performance("verify", report, candidate_baseline)
                self.assertNotEqual(
                    0,
                    verification.returncode,
                    verification.stdout + verification.stderr,
                )


if __name__ == "__main__":
    unittest.main()
