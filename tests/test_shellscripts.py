#!/usr/bin/env python3
"""Regression tests for the generated portable shell-scripts project."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_DIR = REPO_ROOT / "blueprints" / "shellscripts-base"


class ShellscriptsTemplateTests(unittest.TestCase):
    """Exercise generated Just recipes rather than duplicating their logic."""

    def setUp(self) -> None:
        self.require_commands("copier")
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.project_directory = Path(self.temporary_directory.name) / "contract"

        result = subprocess.run(
            [
                "copier",
                "copy",
                "--trust",
                "--defaults",
                "--data",
                "project_name=contract",
                str(TEMPLATE_DIR),
                str(self.project_directory),
            ],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.assertEqual(
            0,
            result.returncode,
            f"Copier generation failed:\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}",
        )

    def require_commands(self, *commands: str) -> None:
        missing = [command for command in commands if shutil.which(command) is None]
        self.assertFalse(
            missing,
            "Required test fixture commands are unavailable: " + ", ".join(missing),
        )

    def require_full_ci_toolchain(self) -> None:
        commands = [
            "just",
            "git",
            "sh",
            "bash",
            "dash",
            "ksh",
            "zsh",
            "shfmt",
            "shellcheck",
            "checkbashisms",
            "semgrep",
            "codespell",
            "bats",
            "shellspec",
            "kcov",
        ]
        if os.uname().sysname == "Linux":
            commands.append("busybox")
        self.require_commands(*commands)
        bash_version = subprocess.run(
            ["bash", "-c", 'printf "%s\\n" "${BASH_VERSINFO[0]}"'],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.assertEqual(
            0,
            bash_version.returncode,
            f"Could not determine the Bash fixture version:\n{bash_version.stderr}",
        )
        self.assertTrue(
            bash_version.stdout.strip().isdigit() and int(bash_version.stdout.strip()) >= 4,
            "The full CI fixture requires Bash 4 or newer; put the intended Bash on PATH.",
        )

    def run_just(self, recipe: str, environment: dict[str, str]) -> subprocess.CompletedProcess[str]:
        command_environment = os.environ.copy()
        command_environment.update(environment)
        return subprocess.run(
            ["just", recipe],
            check=False,
            cwd=self.project_directory,
            env=command_environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

    def write_file(self, relative_path: str, contents: str, executable: bool) -> Path:
        destination = self.project_directory / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(contents, encoding="utf-8")
        if executable:
            destination.chmod(destination.stat().st_mode | 0o111)
        return destination

    def assert_success(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertEqual(
            0,
            result.returncode,
            f"Recipe unexpectedly failed:\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}",
        )

    def assert_failure(self, result: subprocess.CompletedProcess[str]) -> None:
        self.assertNotEqual(
            0,
            result.returncode,
            f"Recipe unexpectedly passed:\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}",
        )

    def initialize_project(self) -> None:
        self.require_full_ci_toolchain()
        self.assert_success(self.run_just("init", {}))

    def test_init_marks_nested_shell_scripts_executable_but_not_python(self) -> None:
        nested_shell = self.write_file(
            "src/nested directory/extensionless shell\nscript",
            "#!/bin/sh\nset -eu\nprintf 'nested shell script\\n'\n",
            executable=False,
        )
        nested_sh = self.write_file(
            "scripts/nested directory/with spaces.sh",
            "#!/bin/sh\nset -eu\nprintf 'nested .sh script\\n'\n",
            executable=False,
        )
        named_shell = self.write_file(
            "src/script.custom-extension",
            "#!/bin/sh\nset -eu\nprintf 'named shell script\\n'\n",
            executable=False,
        )
        python_program = self.write_file(
            "tools/extensionless-python",
            "#!/usr/bin/env python3\nprint('python')\n",
            executable=False,
        )

        self.assertFalse(os.access(nested_shell, os.X_OK))
        self.assertFalse(os.access(nested_sh, os.X_OK))
        self.assertFalse(os.access(python_program, os.X_OK))

        self.initialize_project()

        self.assertTrue(os.access(nested_shell, os.X_OK))
        self.assertTrue(os.access(nested_sh, os.X_OK))
        self.assertTrue(os.access(named_shell, os.X_OK))
        self.assertFalse(os.access(python_program, os.X_OK))

    def test_direct_tests_recurse_into_extensionless_files_and_ignore_unrelated_files(self) -> None:
        marker = self.project_directory / "test-results.txt"
        self.write_file(
            "test/nested directory/test extensionless\nscript",
            "#!/bin/sh\nset -eu\nprintf '%s\\n' \"$TEST_SHELL\" >> \"$MARKER\"\n",
            executable=True,
        )
        self.write_file(
            "test/nested directory/test with spaces.sh",
            "#!/bin/sh\nset -eu\nprintf 'spaces\\n' >> \"$MARKER\"\n",
            executable=True,
        )
        self.write_file(
            "test/support.sh",
            "#!/bin/sh\nset -eu\nprintf 'unrelated\\n' >> \"$MARKER\"\nexit 23\n",
            executable=True,
        )
        self.write_file(
            "test/test-extra.bash",
            "#!/usr/bin/env bash\nset -eu\nprintf 'bash extension\\n' >> \"$MARKER\"\n",
            executable=True,
        )

        self.initialize_project()
        self.assert_success(self.run_just("test", {"MARKER": str(marker)}))

        results = marker.read_text(encoding="utf-8").splitlines()
        self.assertIn("sh", results)
        self.assertIn("spaces", results)
        self.assertIn("bash extension", results)
        self.assertNotIn("unrelated", results)

    def test_direct_tests_report_an_explicit_exit_23(self) -> None:
        self.write_file(
            "test/test-exit-23.sh",
            "#!/bin/sh\nset -eu\nexit 23\n",
            executable=True,
        )

        self.initialize_project()
        result = self.run_just("test", {})

        self.assert_failure(result)

    def test_direct_tests_stop_before_commands_after_false_with_set_e(self) -> None:
        marker = self.project_directory / "unreachable.txt"
        self.write_file(
            "test/test-fail-fast.sh",
            "#!/bin/sh\nset -eu\nfalse\nprintf 'unreachable\\n' > \"$MARKER\"\n",
            executable=True,
        )

        self.initialize_project()
        result = self.run_just("test", {"MARKER": str(marker)})

        self.assert_failure(result)
        self.assertFalse(marker.exists(), "set -e must prevent the command after false")

    def test_direct_tests_fail_when_no_matching_tests_exist(self) -> None:
        self.initialize_project()
        shutil.rmtree(self.project_directory / "test")
        (self.project_directory / "test").mkdir()

        result = self.run_just("test", {})

        self.assert_failure(result)
        self.assertIn("No executable shell tests", result.stderr)

    def test_code_syntax_rejects_a_second_malformed_shell_file(self) -> None:
        commands = ["just", "sh", "bash", "dash", "ksh", "zsh"]
        if os.uname().sysname == "Linux":
            commands.append("busybox")
        self.require_commands(*commands)
        malformed_file = self.write_file(
            "src/second-malformed.sh",
            "#!/bin/sh\nif then\n  printf 'broken\\n'\nfi\n",
            executable=False,
        )

        result = self.run_just("code-syntax", {})

        self.assert_failure(result)
        self.assertIn(str(malformed_file.relative_to(self.project_directory)), result.stderr)

    def test_code_portability_rejects_a_posix_bashism(self) -> None:
        self.require_commands("just", "checkbashisms")
        bashism_file = self.write_file(
            "src/posix-bashism.sh",
            "#!/bin/sh\nif [[ -n \"$1\" ]]; then\n  printf 'value\\n'\nfi\n",
            executable=False,
        )

        result = self.run_just("code-portability", {})

        self.assert_failure(result)
        self.assertIn(str(bashism_file.relative_to(self.project_directory)), result.stderr)

    def test_ci_quiet_runs_ci_and_replays_its_failed_test_output(self) -> None:
        self.require_full_ci_toolchain()
        failing_test = self.write_file(
            "test/test-ci-quiet-failure.sh",
            "#!/bin/sh\nset -eu\nexit 23\n",
            executable=True,
        )

        result = self.run_just("ci-quiet", {})

        self.assert_failure(result)
        self.assertIn("Running CI Checks (Quiet Mode)", result.stdout)
        self.assertIn("Running CI Checks", result.stderr)
        self.assertIn(str(failing_test.relative_to(self.project_directory)), result.stderr)


if __name__ == "__main__":
    unittest.main()
