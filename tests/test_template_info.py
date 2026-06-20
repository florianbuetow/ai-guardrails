#!/usr/bin/env python3
"""Tests for the template dependency inventory script."""

from __future__ import annotations

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

    def test_npm_parser_excludes_scaffold_package(self) -> None:
        manifest = REPO_ROOT / "blueprints/react-vite-typescript-base/template/scripts/bootstrap-vite.sh.template"

        dependencies = template_info.parse_npm_bootstrap(manifest)

        dependency_names = names(dependencies)
        self.assertIn("eslint", dependency_names)
        self.assertIn("prettier", dependency_names)
        self.assertIn("@playwright/test", dependency_names)
        self.assertNotIn("vite", dependency_names)
        self.assertNotIn("npm scaffold packages", groups(dependencies))


if __name__ == "__main__":
    unittest.main()
