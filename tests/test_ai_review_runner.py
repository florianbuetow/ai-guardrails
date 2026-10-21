#!/usr/bin/env python3
"""Behavioral tests for the additive AI review runner."""

from __future__ import annotations

import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
RUNNER_SOURCE = REPO_ROOT / "blueprints/ai-review/template/scripts/ai-review/review.py"
# Import the template without leaving bytecode that Copier would install.
sys.dont_write_bytecode = True
SPEC = importlib.util.spec_from_file_location("ai_review_runner", RUNNER_SOURCE)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Cannot load the AI review runner")
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)

DOMAINS = ("correctness", "security", "performance", "architecture", "tests")
PROVIDERS = ("claude", "codex", "grok", "agy")

FAKE_REVIEWER = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import sys
import time

provider = Path(sys.argv[0]).name
prompt = sys.stdin.read()
if provider == "agy":
    input_event = json.loads(prompt)
    if input_event.get("event") != "user" or set(input_event.get("message", {})) != {"content"}:
        print("fake agy received invalid stream-json input", file=sys.stderr)
        sys.exit(8)
    prompt = input_event["message"]["content"]
if not prompt and (Path.cwd() / "prompt.txt").is_file():
    prompt = (Path.cwd() / "prompt.txt").read_text(encoding="utf-8")
match = re.search(r"Review domain: ([a-z]+)", prompt)
if match is None:
    print("fake reviewer could not find domain", file=sys.stderr)
    sys.exit(6)
domain = match.group(1)
with Path(os.environ["FAKE_REVIEW_LOG"]).open("a", encoding="utf-8") as output:
    output.write(json.dumps({"provider": provider, "domain": domain, "argv": sys.argv[1:], "prompt": prompt}) + "\n")

mode = os.environ.get("FAKE_REVIEW_MODE", "clean")
if mode == "failure":
    print("intentional reviewer failure", file=sys.stderr)
    sys.exit(7)
if mode == "timeout":
    time.sleep(5)
if mode == "missing-result":
    sys.exit(0)
if mode == "invalid-json":
    print("{invalid json")
    sys.exit(0)
if mode == "claude-error":
    print(json.dumps({"is_error": True}))
    sys.exit(0)
if mode == "agy-failure":
    print(json.dumps({"event": "result", "result": {"status": "FAILURE"}}))
    sys.exit(0)

findings = []
if mode in ("warning", "error"):
    findings.append({
        "severity": mode,
        "file": "reviewed.txt",
        "line": 1,
        "title": "Supported fake finding",
        "scenario": "A concrete scenario exercises the finding.",
        "evidence": "The committed first line provides evidence.",
    })
result = {"domain": domain, "complete": True, "findings": findings}
if mode == "incomplete":
    result["complete"] = False
elif mode == "wrong-domain":
    result["domain"] = "security" if domain != "security" else "correctness"
elif mode == "out-of-range":
    result["findings"] = [{
        "severity": "error",
        "file": "reviewed.txt",
        "line": 999,
        "title": "Invalid location",
        "scenario": "The line does not exist.",
        "evidence": "The line number is beyond the snapshot.",
    }]
elif mode == "malformed":
    result = {"domain": domain, "complete": True}

if provider == "codex":
    option = sys.argv.index("--output-last-message")
    Path(sys.argv[option + 1]).write_text(json.dumps(result), encoding="utf-8")
elif provider == "claude":
    print(json.dumps({"is_error": False, "structured_output": result}))
elif provider == "agy":
    print(json.dumps({"event": "result", "result": {"status": "SUCCESS", "structured_output": result}}))
else:
    print(json.dumps(result))
'''

ISOLATION_WRAPPER = r'''#!/usr/bin/env python3
import os
import sys
os.execvp(sys.argv[1], sys.argv[1:])
'''


def run(*arguments: str, cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(arguments, cwd=cwd, env=env, check=False, capture_output=True, text=True)


class GitRepositoryTestCase(unittest.TestCase):
    def setUp(self) -> None:
        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        self.temporary_root = Path(temporary_directory.name).resolve()

    def initialize_repository(self, root: Path) -> None:
        root.mkdir(parents=True, exist_ok=True)
        result = run("git", "init", "--quiet", cwd=root)
        self.assertEqual(0, result.returncode, result.stderr)
        for key, value in (("user.name", "AI Review Tests"), ("user.email", "ai-review@example.invalid")):
            result = run("git", "config", key, value, cwd=root)
            self.assertEqual(0, result.returncode, result.stderr)

    def commit(self, root: Path, message: str, *paths: str) -> str:
        self.assertTrue(paths, "Fixture commits must enumerate their paths")
        result = run("git", "add", "--", *paths, cwd=root)
        self.assertEqual(0, result.returncode, result.stderr)
        result = run("git", "commit", "--quiet", "-m", message, cwd=root)
        self.assertEqual(0, result.returncode, result.stderr)
        result = run("git", "rev-parse", "HEAD", cwd=root)
        self.assertEqual(0, result.returncode, result.stderr)
        return result.stdout.strip()


class SnapshotTests(GitRepositoryTestCase):
    def new_repository_with_change(self) -> tuple[Path, str, str]:
        root = self.temporary_root / "project"
        self.initialize_repository(root)
        (root / "reviewed.txt").write_text("old committed content\n", encoding="utf-8")
        base = self.commit(root, "base", "reviewed.txt")
        (root / "reviewed.txt").write_text("new committed content\n", encoding="utf-8")
        head = self.commit(root, "head", "reviewed.txt")
        return root, base, head

    def test_snapshot_uses_explicit_commits_and_ignores_worktree_changes(self) -> None:
        root, base, head = self.new_repository_with_change()
        (root / "reviewed.txt").write_text("uncommitted content must not be reviewed\n", encoding="utf-8")

        payload, lines = runner.snapshot(root, base, head, 100_000)

        self.assertEqual(base, payload["base"])
        self.assertEqual(head, payload["head"])
        self.assertEqual("new committed content\n", payload["files_at_head"]["reviewed.txt"])
        self.assertIn("-old committed content", payload["diff"])
        self.assertIn("+new committed content", payload["diff"])
        self.assertNotIn("uncommitted", json.dumps(payload))
        self.assertEqual(1, lines["reviewed.txt"])

    def test_snapshot_rejects_no_diff(self) -> None:
        root, base, _head = self.new_repository_with_change()
        with self.assertRaisesRegex(ValueError, "No changes"):
            runner.snapshot(root, base, base, 100_000)

    def test_snapshot_refuses_installation_in_a_repository_subdirectory(self) -> None:
        root, base, head = self.new_repository_with_change()
        nested = root / "nested-project"
        nested.mkdir()
        with self.assertRaisesRegex(ValueError, "Git repository root"):
            runner.snapshot(nested, base, head, 100_000)

    def test_snapshot_rejects_changed_binary_file(self) -> None:
        root = self.temporary_root / "binary-project"
        self.initialize_repository(root)
        (root / "artifact.bin").write_bytes(b"old\0bytes")
        base = self.commit(root, "base", "artifact.bin")
        (root / "artifact.bin").write_bytes(b"new\0bytes")
        head = self.commit(root, "head", "artifact.bin")
        with self.assertRaisesRegex(ValueError, "Changed binary file cannot be reviewed"):
            runner.snapshot(root, base, head, 100_000)

    def test_snapshot_rejects_added_binary_file(self) -> None:
        root = self.temporary_root / "added-binary-project"
        self.initialize_repository(root)
        (root / "reviewed.txt").write_text("base\n", encoding="utf-8")
        base = self.commit(root, "base", "reviewed.txt")
        (root / "artifact.bin").write_bytes(b"new\0bytes")
        head = self.commit(root, "head", "artifact.bin")
        with self.assertRaisesRegex(ValueError, "Changed binary file cannot be reviewed"):
            runner.snapshot(root, base, head, 100_000)

    def test_snapshot_rejects_changed_and_deleted_symlinks(self) -> None:
        for change in ("changed", "deleted"):
            with self.subTest(change=change):
                root = self.temporary_root / f"{change}-symlink-project"
                self.initialize_repository(root)
                (root / "target-a.txt").write_text("target a\n", encoding="utf-8")
                (root / "target-b.txt").write_text("target b\n", encoding="utf-8")
                (root / "linked.txt").symlink_to("target-a.txt")
                base = self.commit(root, "base", "target-a.txt", "target-b.txt", "linked.txt")
                (root / "linked.txt").unlink()
                if change == "changed":
                    (root / "linked.txt").symlink_to("target-b.txt")
                head = self.commit(root, "head", "linked.txt")
                with self.assertRaisesRegex(ValueError, "Changed symlink/submodule cannot be reviewed"):
                    runner.snapshot(root, base, head, 100_000)

    def test_snapshot_enforces_byte_limit(self) -> None:
        root, base, head = self.new_repository_with_change()
        with self.assertRaisesRegex(ValueError, "exceeds max_snapshot_bytes"):
            runner.snapshot(root, base, head, 1)

    def test_snapshot_includes_unchanged_nested_sibling_context(self) -> None:
        root = self.temporary_root / "nested-project"
        self.initialize_repository(root)
        nested = root / "package/nested"
        nested.mkdir(parents=True)
        (nested / "changed.txt").write_text("before\n", encoding="utf-8")
        (nested / "sibling.txt").write_text("unchanged supporting context\n", encoding="utf-8")
        base = self.commit(root, "base", "package/nested/changed.txt", "package/nested/sibling.txt")
        (nested / "changed.txt").write_text("after\n", encoding="utf-8")
        head = self.commit(root, "head", "package/nested/changed.txt")

        payload, lines = runner.snapshot(root, base, head, 100_000)

        self.assertEqual("unchanged supporting context\n", payload["files_at_head"]["package/nested/sibling.txt"])
        self.assertEqual(1, lines["package/nested/sibling.txt"])


class ConfigurationAndValidationTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(temporary_directory.cleanup)
        self.config_path = Path(temporary_directory.name) / "config.json"
        self.valid_config = {
            "models": {provider: f"explicit-{provider}-model" for provider in PROVIDERS},
            "timeout_seconds": 10,
            "max_snapshot_bytes": 100_000,
            "isolation_commands": {provider: (["isolate"] if provider == "agy" else []) for provider in PROVIDERS},
        }

    def write_config(self, config: dict) -> None:
        self.config_path.write_text(json.dumps(config), encoding="utf-8")

    def test_config_requires_models_and_an_explicit_provider_model(self) -> None:
        missing_models = copy.deepcopy(self.valid_config)
        del missing_models["models"]
        self.write_config(missing_models)
        with self.assertRaisesRegex(ValueError, "Missing configuration: models"):
            runner.load_config(self.config_path, "codex")

        empty_model = copy.deepcopy(self.valid_config)
        empty_model["models"]["codex"] = "  "
        self.write_config(empty_model)
        with self.assertRaisesRegex(ValueError, "explicit models.codex"):
            runner.load_config(self.config_path, "codex")

        missing_provider_model = copy.deepcopy(self.valid_config)
        del missing_provider_model["models"]["codex"]
        self.write_config(missing_provider_model)
        with self.assertRaises(KeyError):
            runner.load_config(self.config_path, "codex")

    def test_agy_requires_an_isolation_wrapper(self) -> None:
        config = copy.deepcopy(self.valid_config)
        config["isolation_commands"]["agy"] = []
        self.write_config(config)
        with self.assertRaisesRegex(ValueError, "agy requires"):
            runner.load_config(self.config_path, "agy")

    def test_validate_rejects_malformed_wrong_incomplete_and_out_of_range_results(self) -> None:
        valid = {"domain": "correctness", "complete": True, "findings": []}
        cases = {
            "malformed": {"domain": "correctness", "complete": True},
            "wrong domain": {**valid, "domain": "security"},
            "incomplete": {**valid, "complete": False},
            "out of range": {
                **valid,
                "findings": [{
                    "severity": "error",
                    "file": "reviewed.txt",
                    "line": 2,
                    "title": "Bad line",
                    "scenario": "The location is invalid.",
                    "evidence": "The file contains one line.",
                }],
            },
        }
        for name, result in cases.items():
            with self.subTest(name=name), self.assertRaises(ValueError):
                runner.validate(result, "correctness", {"reviewed.txt": 1})


class RunnerIntegrationTests(GitRepositoryTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.project = self.temporary_root / "project with spaces"
        self.bin_dir = self.temporary_root / "bin"
        self.bin_dir.mkdir()
        self.initialize_repository(self.project)
        scripts = self.project / "scripts/ai-review"
        scripts.mkdir(parents=True)
        shutil.copy2(RUNNER_SOURCE, scripts / "review.py")
        just_dir = self.project / "just"
        just_dir.mkdir()
        shutil.copy2(REPO_ROOT / "blueprints/ai-review/template/just/ai-review.just", just_dir / "ai-review.just")
        (self.project / "Justfile").write_text("import 'just/ai-review.just'\n", encoding="utf-8")
        config_dir = self.project / "config/ai-review"
        prompts = config_dir / "prompts"
        prompts.mkdir(parents=True)
        self.models = {provider: f"explicit-{provider}-model" for provider in PROVIDERS}
        self.config_path = config_dir / "config.json"
        self.config_path.write_text(
            json.dumps({
                "models": self.models,
                "timeout_seconds": 2,
                "max_snapshot_bytes": 1_000_000,
                "isolation_commands": {
                    provider: (["isolate"] if provider == "agy" else []) for provider in PROVIDERS
                },
            }),
            encoding="utf-8",
        )
        (config_dir / "schema.json").write_text(
            json.dumps({"type": "object", "required": ["domain", "complete", "findings"]}),
            encoding="utf-8",
        )
        (prompts / "common.md").write_text("Review the supplied immutable snapshot.\n", encoding="utf-8")
        for domain in DOMAINS:
            (prompts / f"{domain}.md").write_text(f"Act as the {domain} specialist.\n", encoding="utf-8")
        (self.project / "reviewed.txt").write_text("old committed content\n", encoding="utf-8")
        fixture_paths = sorted(
            path.relative_to(self.project).as_posix()
            for path in self.project.rglob("*")
            if path.is_file() and ".git" not in path.relative_to(self.project).parts
        )
        self.base = self.commit(self.project, "base", *fixture_paths)
        (self.project / "reviewed.txt").write_text("new committed content\n", encoding="utf-8")
        self.head = self.commit(self.project, "head", "reviewed.txt")
        (self.project / "reviewed.txt").write_text("dirty content must not be reviewed\n", encoding="utf-8")
        for executable in PROVIDERS:
            self.make_executable(executable, FAKE_REVIEWER)
        self.make_executable("isolate", ISOLATION_WRAPPER)
        self.log = self.temporary_root / "review.log"

    def make_executable(self, name: str, content: str) -> None:
        path = self.bin_dir / name
        path.write_text(content, encoding="utf-8")
        path.chmod(0o755)

    def environment(self, mode: str = "clean") -> dict[str, str]:
        env = dict(os.environ)
        env["PATH"] = str(self.bin_dir) + os.pathsep + env["PATH"]
        env["FAKE_REVIEW_LOG"] = str(self.log)
        env["FAKE_REVIEW_MODE"] = mode
        return env

    def invoke(self, provider: str, report: Path, mode: str = "clean") -> subprocess.CompletedProcess[str]:
        return run(
            sys.executable,
            str(self.project / "scripts/ai-review/review.py"),
            provider,
            "--base",
            self.base,
            "--head",
            self.head,
            "--report",
            str(report),
            cwd=self.project,
            env=self.environment(mode),
        )

    def logged_invocations(self) -> list[dict]:
        return [json.loads(line) for line in self.log.read_text(encoding="utf-8").splitlines()]

    def test_all_four_fake_clis_run_five_distinct_specialists(self) -> None:
        for provider in PROVIDERS:
            with self.subTest(provider=provider):
                self.log.unlink(missing_ok=True)
                report_path = self.temporary_root / f"{provider}-report.json"
                result = self.invoke(provider, report_path)
                self.assertEqual(0, result.returncode, result.stdout + result.stderr)
                report = json.loads(report_path.read_text(encoding="utf-8"))
                self.assertTrue(report["complete"])
                self.assertEqual(provider, report["provider"])
                self.assertEqual(self.models[provider], report["model"])
                self.assertEqual(self.base, report["base"])
                self.assertEqual(self.head, report["head"])
                self.assertEqual(list(DOMAINS), [review["domain"] for review in report["reviews"]])
                invocations = self.logged_invocations()
                self.assertEqual(list(DOMAINS), [entry["domain"] for entry in invocations])
                self.assertEqual({provider}, {entry["provider"] for entry in invocations})
                for entry in invocations:
                    self.assertIn(self.models[provider], entry["argv"])
                    self.assertIn("new committed content", entry["prompt"])
                    self.assertNotIn("dirty content must not be reviewed", entry["prompt"])

    def test_warning_findings_allow_success_and_error_findings_block(self) -> None:
        warning_report = self.temporary_root / "warning-report.json"
        warning = self.invoke("grok", warning_report, "warning")
        self.assertEqual(0, warning.returncode, warning.stdout + warning.stderr)
        warning_data = json.loads(warning_report.read_text(encoding="utf-8"))
        self.assertEqual(5, sum(len(review["findings"]) for review in warning_data["reviews"]))
        self.assertIn("5 findings (0 blocking)", warning.stdout)

        self.log.unlink()
        error_report = self.temporary_root / "error-report.json"
        error = self.invoke("codex", error_report, "error")
        self.assertEqual(1, error.returncode, error.stdout + error.stderr)
        error_data = json.loads(error_report.read_text(encoding="utf-8"))
        self.assertTrue(error_data["complete"])
        self.assertEqual(5, sum(len(review["findings"]) for review in error_data["reviews"]))
        self.assertIn("5 findings (5 blocking)", error.stdout)

    def test_existing_report_is_not_overwritten_or_reviewed(self) -> None:
        report = self.temporary_root / "existing-report.json"
        report.write_text("preserve this report exactly\n", encoding="utf-8")

        result = self.invoke("codex", report)

        self.assertEqual(1, result.returncode, result.stdout + result.stderr)
        self.assertIn("Report destination already exists", result.stderr)
        self.assertEqual("preserve this report exactly\n", report.read_text(encoding="utf-8"))
        self.assertFalse(self.log.exists())

    def test_provider_transport_results_fail_closed(self) -> None:
        cases = (
            ("codex", "missing-result", "result.json"),
            ("grok", "invalid-json", "Expecting property name"),
            ("claude", "claude-error", "CLI reported an error"),
            ("agy", "agy-failure", "agy did not finish successfully"),
        )
        for index, (provider, mode, expected) in enumerate(cases):
            with self.subTest(provider=provider, mode=mode):
                self.log.unlink(missing_ok=True)
                report = self.temporary_root / f"transport-failed-{index}.json"
                result = self.invoke(provider, report, mode)
                self.assertEqual(1, result.returncode, result.stdout + result.stderr)
                self.assertIn(expected, result.stderr)
                self.assertFalse(report.exists())

    def test_imported_just_target_runs_in_path_with_spaces(self) -> None:
        self.assertIsNotNone(shutil.which("just"), "just is required for the imported recipe test")
        report = self.temporary_root / "report with spaces.json"

        result = run(
            "just",
            "ci-ai-grok",
            self.base,
            self.head,
            str(report),
            cwd=self.project,
            env=self.environment(),
        )

        self.assertEqual(0, result.returncode, result.stdout + result.stderr)
        self.assertTrue(json.loads(report.read_text(encoding="utf-8"))["complete"])
        self.assertIn("grok review passed", result.stdout)

    def test_cli_failure_timeout_and_incomplete_result_fail_without_report(self) -> None:
        config = json.loads(self.config_path.read_text(encoding="utf-8"))
        config["timeout_seconds"] = 1
        self.config_path.write_text(json.dumps(config), encoding="utf-8")
        cases = (
            ("failure", "Reviewer exited 7"),
            ("timeout", "Reviewer timed out"),
            ("incomplete", "Incomplete or wrong-domain review"),
            ("malformed", "Review must contain exactly"),
            ("wrong-domain", "Incomplete or wrong-domain review"),
            ("out-of-range", "outside the reviewed snapshot"),
        )
        for index, (mode, expected) in enumerate(cases):
            with self.subTest(mode=mode):
                self.log.unlink(missing_ok=True)
                report = self.temporary_root / f"failed-{index}.json"
                result = self.invoke("claude", report, mode)
                self.assertEqual(1, result.returncode, result.stdout + result.stderr)
                self.assertIn(expected, result.stderr)
                self.assertFalse(report.exists())


if __name__ == "__main__":
    unittest.main()
