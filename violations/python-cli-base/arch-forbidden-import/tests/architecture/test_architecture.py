"""Architecture import rule tests for test-cli-project.

VIOLATION OVERLAY: Adds a rule that layer_a must not import layer_b.
"""

from __future__ import annotations

import pytest
from pytestarch import EvaluableArchitecture, Rule

pytestmark = pytest.mark.architecture


def test_evaluable_is_configured(evaluable: EvaluableArchitecture) -> None:
    """Verify the evaluable architecture graph was built successfully."""
    assert evaluable is not None


def test_layer_a_must_not_import_layer_b(evaluable: EvaluableArchitecture) -> None:
    """Layer A must not depend on Layer B."""
    (
        Rule()
        .modules_that()
        .are_named("test_cli_project.layer_a")
        .should_not()
        .import_modules_that()
        .are_named("test_cli_project.layer_b")
        .assert_applies(evaluable)
    )
