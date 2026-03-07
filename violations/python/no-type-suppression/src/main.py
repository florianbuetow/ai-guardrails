"""Test CLI application."""


def main() -> None:
    value: int = "42"  # type: ignore[assignment]
    print(f"Hello from test_cli_project! {value}")


if __name__ == "__main__":
    main()
