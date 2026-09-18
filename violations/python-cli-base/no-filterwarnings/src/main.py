"""Test CLI application."""

import warnings

import pytest


@pytest.mark.filterwarnings("ignore::DeprecationWarning")
def process() -> None:
    """Process data with suppressed warnings."""
    warnings.warn("old behavior", DeprecationWarning, stacklevel=2)


def main() -> None:
    """Main entry point."""
    print("Hello from test_cli_project!")


if __name__ == "__main__":
    main()
