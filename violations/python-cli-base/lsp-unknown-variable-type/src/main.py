"""Test CLI application."""


def _untyped(x):
    return x


def main() -> None:
    """Main entry point."""
    value = _untyped(42)
    print(f"Hello from test_cli_project! {value}")


if __name__ == "__main__":
    main()
