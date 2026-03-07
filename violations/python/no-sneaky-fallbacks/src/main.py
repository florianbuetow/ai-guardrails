"""Test CLI application."""


def main() -> None:
    provided_name: str | None = None
    name = provided_name or "test_cli_project"
    print(f"Hello from {name}!")


if __name__ == "__main__":
    main()
