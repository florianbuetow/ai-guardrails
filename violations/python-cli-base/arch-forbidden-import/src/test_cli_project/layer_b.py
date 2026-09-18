"""Layer B module — exists to be imported by layer_a as a forbidden dependency."""


def helper_function() -> str:
    """Return a helper string."""
    return "helper"
