"""Test CLI application."""


def _untyped(x):
    return x


def greet(name: str) -> str:
    """Return greeting."""
    return f"Hello, {name}!"


def main() -> None:
    """Main entry point."""
    value = _untyped("test")
    print(greet(value))


if __name__ == "__main__":
    main()
