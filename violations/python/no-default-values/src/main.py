"""Test CLI application."""


def format_message(name: str = "world") -> str:
    return f"Hello, {name}!"


def main() -> None:
    print(format_message("test_cli_project"))


if __name__ == "__main__":
    main()
