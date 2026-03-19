"""Test CLI application."""

import flask


def main() -> None:
    """Main entry point."""
    print(flask.__name__)
    print("Hello from test_cli_project!")


if __name__ == "__main__":
    main()
