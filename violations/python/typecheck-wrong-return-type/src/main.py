"""Test CLI application."""


def greet() -> str:
    """Return a greeting."""
    return 42


def main() -> None:
    """Main entry point."""
    print(greet())


if __name__ == "__main__":
    main()
