"""Layer A module — VIOLATION: imports from layer_b (forbidden by architecture rules)."""

from test_cli_project.layer_b import helper_function


def process() -> str:
    """Process using forbidden dependency."""
    return helper_function()
