"""Test CLI application."""

import subprocess


def main() -> None:
    """Main entry point."""
    cmd = "echo Hello from test_cli_project!"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)  # nosec B602
    print(result.stdout)


if __name__ == "__main__":
    main()
