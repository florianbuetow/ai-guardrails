"""Test CLI application."""


def main() -> None:
    """Main entry point."""
    config = {}
    name = config.get("name")
    if name is None:
        name = "test_cli_project"
    print(f"Hello from {name}!")


if __name__ == "__main__":
    main()
