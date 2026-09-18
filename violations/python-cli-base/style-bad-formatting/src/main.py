"""Test CLI application."""


def main() -> None:
    """Main entry point."""
    print("Hello from test_cli_project!")


def helper(name: str) -> str:
        """Format a greeting."""
        return f"Hello, {name}!"


if __name__ == "__main__":
    main()
