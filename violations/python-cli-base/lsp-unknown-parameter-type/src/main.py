"""Test CLI application."""


def greet(name) -> str:
    """Return greeting."""
    return f"Hello, {name}!"


def main() -> None:
    """Main entry point."""
    print(greet("test_cli_project"))


if __name__ == "__main__":
    main()
