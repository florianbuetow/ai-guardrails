#!/usr/bin/env python3
"""Tests for the template dependency inventory script."""

from __future__ import annotations

import contextlib
import io
import importlib.util
from pathlib import Path
import sys
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = REPO_ROOT / "project-setup" / "template-info.py"


def load_template_info_module():
    spec = importlib.util.spec_from_file_location("template_info", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load module from {MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


template_info = load_template_info_module()


def names(dependencies) -> set[str]:
    return {dependency.name for dependency in dependencies}


def groups(dependencies) -> set[str]:
    return {dependency.group for dependency in dependencies}


def dependency_by_name(dependencies, name: str):
    for dependency in dependencies:
        if dependency.name == name:
            return dependency
    raise AssertionError(f"Dependency not found: {name}")


class TemplateInfoTests(unittest.TestCase):
    def test_python_parser_reports_direct_dependencies_only(self) -> None:
        manifest = REPO_ROOT / "blueprints/python-cli-base/template/pyproject.toml.template"

        dependencies = template_info.parse_python_manifest(manifest)

        dependency_names = names(dependencies)
        self.assertIn("pytest", dependency_names)
        self.assertIn("semgrep", dependency_names)
        self.assertNotIn("hatchling", dependency_names)
        self.assertNotIn("pyjwt", dependency_names)
        self.assertNotIn("Python build-system requirements", groups(dependencies))
        bandit = dependency_by_name(dependencies, "bandit[toml]")
        self.assertEqual("pypi", bandit.latest_registry)
        self.assertEqual("bandit", bandit.latest_identifier)

    def test_gradle_parser_excludes_plugins_tool_versions_and_platforms(self) -> None:
        manifest = REPO_ROOT / "blueprints/java-cli-base/template/build.gradle.kts.template"

        dependencies = template_info.parse_gradle_manifest(manifest)

        dependency_names = names(dependencies)
        self.assertIn("org.assertj:assertj-core", dependency_names)
        self.assertIn("org.junit.jupiter:junit-jupiter-api", dependency_names)
        self.assertNotIn("org.junit:junit-bom", dependency_names)
        self.assertNotIn("com.diffplug.spotless", dependency_names)
        self.assertNotIn("checkstyle.toolVersion", dependency_names)
        self.assertNotIn("jacoco.toolVersion", dependency_names)
        self.assertNotIn("Gradle plugins", groups(dependencies))
        self.assertNotIn("Gradle tool versions", groups(dependencies))
        assertj = dependency_by_name(dependencies, "org.assertj:assertj-core")
        self.assertEqual("maven", assertj.latest_registry)
        self.assertEqual("org.assertj:assertj-core", assertj.latest_identifier)

    def test_cmake_parser_uses_fetchcontent_repository_for_latest_lookup(self) -> None:
        manifest = REPO_ROOT / "blueprints/cpp-cli-base/template/CMakeLists.txt.template"

        dependencies = template_info.parse_cmake_manifest(manifest)

        googletest = dependency_by_name(dependencies, "googletest")
        self.assertEqual("github-tags", googletest.latest_registry)
        self.assertEqual("https://github.com/google/googletest.git", googletest.latest_identifier)

    def test_npm_parser_excludes_scaffold_package(self) -> None:
        manifest = REPO_ROOT / "blueprints/react-vite-typescript-base/template/scripts/bootstrap-vite.sh.template"

        dependencies = template_info.parse_npm_bootstrap(manifest)

        dependency_names = names(dependencies)
        self.assertIn("eslint", dependency_names)
        self.assertIn("prettier", dependency_names)
        self.assertIn("@playwright/test", dependency_names)
        self.assertNotIn("vite", dependency_names)
        self.assertNotIn("npm scaffold packages", groups(dependencies))

    def test_dependency_output_uses_box_table_with_requested_columns(self) -> None:
        dependency = template_info.Dependency(
            "Python optional dependencies [dev]",
            "pytest",
            "8.4.2",
            "pyproject.toml.template",
            "pypi",
            "pytest",
        )
        latest_request = template_info.latest_version.LatestVersionRequest("pypi", "pytest")
        output = io.StringIO()

        with contextlib.redirect_stdout(output):
            template_info.print_dependencies([("python-cli-base", dependency)], {latest_request: "8.4.7"})

        text = output.getvalue()
        top_border = text.splitlines()[0]
        self.assertNotIn("+", top_border)
        self.assertNotIn("-", top_border)
        self.assertIn("┌", text)
        self.assertIn("┬", text)
        self.assertIn("└", text)
        self.assertIn("│ Template", text)
        self.assertIn("Used version", text)
        self.assertIn("Latest version", text)
        self.assertIn("Library", text)
        self.assertIn("python-cli-base", text)
        self.assertIn(f"{template_info.GREEN_COLOR}8.4.2{template_info.RESET_COLOR}", text)
        self.assertIn("8.4.7", text)
        self.assertIn("pytest", text)

    def test_version_color_matches_major_minor_rules(self) -> None:
        self.assertEqual(template_info.GREEN_COLOR, template_info.version_color("1.2.3", "1.2.9"))
        self.assertEqual(template_info.BLUE_COLOR, template_info.version_color("^1", "1.9.0"))
        self.assertEqual(template_info.BLUE_COLOR, template_info.version_color("1.2.3", "1.3.0"))
        self.assertEqual(template_info.RED_COLOR, template_info.version_color("1.2.3", "2.0.0"))
        self.assertEqual(template_info.RED_COLOR, template_info.version_color("(unpinned)", "2.0.0"))


if __name__ == "__main__":
    unittest.main()
