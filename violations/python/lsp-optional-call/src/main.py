"""Test CLI application."""

from typing import Callable, Optional


def main() -> None:
    """Main entry point."""
    callback: Optional[Callable[[], str]] = None
    result = callback()
    print(f"Hello from test_cli_project! {result}")


if __name__ == "__main__":
    main()
