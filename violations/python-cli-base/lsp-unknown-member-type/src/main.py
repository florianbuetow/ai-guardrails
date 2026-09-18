"""Test CLI application."""


def process(obj) -> None:
    """Process object."""
    result = obj.name
    print(result)


def main() -> None:
    """Main entry point."""
    process("test_cli_project")


if __name__ == "__main__":
    main()
