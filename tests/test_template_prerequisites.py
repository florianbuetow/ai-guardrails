#!/usr/bin/env python3
"""Enforce prerequisite checks in every generated template workflow."""

from __future__ import annotations

from pathlib import Path
import re
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
BLUEPRINTS = REPO_ROOT / "blueprints"
RECIPE_PATTERN = re.compile(r"^(?P<name>[A-Za-z0-9_-]+):(?P<deps>.*)$", re.MULTILINE)
JUST_INVOCATION_PATTERN = re.compile(r"^\s*@?just\s+(?P<recipe>[A-Za-z0-9_-]+)", re.MULTILINE)


def recipe_sections(text: str) -> dict[str, tuple[str, str]]:
    matches = list(RECIPE_PATTERN.finditer(text))
    sections: dict[str, tuple[str, str]] = {}
    for index, match in enumerate(matches):
        body_end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        sections[match.group("name")] = (match.group("deps").strip(), text[match.end() : body_end])
    return sections


class TemplatePrerequisiteTests(unittest.TestCase):
    def test_every_template_checks_prerequisites_before_initialization_and_ci(self) -> None:
        justfiles = sorted(BLUEPRINTS.glob("*/template/justfile.template"))
        self.assertTrue(justfiles, "No template Justfiles found")

        for justfile in justfiles:
            with self.subTest(template=justfile.parents[1].name):
                sections = recipe_sections(justfile.read_text(encoding="utf-8"))
                self.assertIn("check", sections, "Missing check recipe")
                self.assertIn("init", sections, "Missing init recipe")
                self.assertIn("ci", sections, "Missing ci recipe")

                init_dependencies, _init_body = sections["init"]
                self.assertIn("check", init_dependencies.split(), "init must depend on check")

                _ci_dependencies, ci_body = sections["ci"]
                ci_invocations = JUST_INVOCATION_PATTERN.findall(ci_body)
                self.assertTrue(ci_invocations, "ci must invoke Just recipes")
                self.assertEqual("check", ci_invocations[0], "ci must run check before every other Just recipe")


if __name__ == "__main__":
    unittest.main()
