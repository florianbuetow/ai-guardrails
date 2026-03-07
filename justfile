# =============================================================================
# Justfile Rules (follow these when editing justfile):
#
# 1. Use printf (not echo) to print colors — some terminals won't render
#    colors with echo.
#
# 2. Always add an empty `@echo ""` line before and after each target's
#    command block.
#
# 3. Always add new targets to the help section and update it when targets
#    are added, modified or removed.
#
# 4. Target ordering in help (and in this file) matters:
#    - Setup targets first (init, setup, install, etc.)
#    - Start/stop/run targets next
#    - Code generation / data tooling targets next
#    - Checks, linting, and tests next (ordered fastest to slowest)
#    Group related targets together and separate groups with an empty
#    `@echo ""` line in the help output.
#
# 5. Composite targets (e.g. ci) that call multiple sub-targets must fail
#    fast: exit 1 on the first error. Never skip over errors or warnings.
#    Use `set -e` or `&&` chaining to ensure immediate abort with the
#    appropriate error message.
#
# 6. Every target must end with a clear short status message:
#    - On success: green (\033[32m) message confirming completion.
#      E.g. printf "\033[32m✓ init completed successfully\033[0m\n"
#    - On failure: red (\033[31m) message indicating what failed, then exit 1.
#      E.g. printf "\033[31m✗ ci failed: tests exited with errors\033[0m\n"
# =============================================================================

# Default recipe: list all available recipes
_default:
    @just --list

# Show help message
help:
	@clear
	@echo ""
	@echo "Available recipes:"
	@echo "  just help                              - Show this help message"
	@echo "  just init                              - Install templates and set up aliases"
	@echo "  just update                            - Update templates to latest version"
	@echo "  just create <template> <target-dir>    - Create new project from template"
	@echo "  just test                              - Run Python baseline + violation tests"
	@echo "  just test-java                         - Run Java baseline + violation tests"
	@echo "  just test-go                           - Run Go baseline + violation tests"
	@echo "  just test-elixir                       - Run Elixir baseline + violation tests"
	@echo "  just test-cpp                          - Run C++ baseline + violation tests"
	@echo "  just test-rust                         - Run Rust baseline + violation tests"
	@echo "  just test-all                          - Run all baseline + violation tests"
	@echo ""
	@echo "Available templates:"
	@echo "  python-cli-base                        - Python CLI application"
	@echo "  java-cli-base                          - Java CLI application"
	@echo "  elixir-otp-base                        - Elixir OTP application"
	@echo "  go-cli-base                            - Go CLI application"
	@echo "  cpp-cli-base                           - C++ CLI application"
	@echo "  rust-cli-base                          - Rust CLI application"
	@echo ""

# Install templates and set up aliases
init:
	@echo ""
	@echo "Checking prerequisites..."
	@echo ""
	@# Check for git
	@if ! command -v git >/dev/null 2>&1; then \
		echo "✗ Error: git is not installed"; \
		echo "  Please install git first: https://git-scm.com/downloads"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✓ git is installed"
	@# Check for python
	@if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then \
		echo "✗ Error: python is not installed"; \
		echo "  Please install Python 3.12 or higher: https://www.python.org/downloads/"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✓ python is installed"
	@# Check for uv
	@if ! command -v uv >/dev/null 2>&1; then \
		echo "✗ Error: uv is not installed"; \
		echo "  Please install uv: https://docs.astral.sh/uv/getting-started/installation/"; \
		echo "  Quick install: curl -LsSf https://astral.sh/uv/install.sh | sh"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✓ uv is installed"
	@# Check for just
	@if ! command -v just >/dev/null 2>&1; then \
		echo "✗ Error: just is not installed"; \
		echo "  Please install just: https://github.com/casey/just#installation"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✓ just is installed"
	@# Check for claude CLI
	@if ! command -v claude >/dev/null 2>&1; then \
		echo "✗ Error: claude CLI is not installed"; \
		echo "  Please install Claude Code: https://claude.com/claude-code"; \
		echo ""; \
		exit 1; \
	fi
	@echo "✓ claude CLI is installed"
	@# Check for elixir (optional, for Elixir templates)
	@if command -v elixir >/dev/null 2>&1; then \
		echo "✓ elixir is installed"; \
	else \
		echo "⚠ elixir is not installed (needed for Elixir templates)"; \
	fi
	@echo ""
	@echo "All prerequisites met! Installing AI Templates..."
	@echo ""
	@./project-setup/setup_aliases.sh

# Update templates to latest version
update:
	@echo ""
	@echo "Updating AI Templates to latest version..."
	@echo ""
	@if ! command -v git >/dev/null 2>&1; then \
		echo "✗ Error: git is not installed"; \
		echo ""; \
		exit 1; \
	fi
	@git pull && { \
		echo ""; \
		printf "\033[32m✓ Templates updated successfully!\033[0m\n"; \
		echo ""; \
	} || { \
		echo ""; \
		printf "\033[31m✗ Failed to update templates\033[0m\n"; \
		echo ""; \
		exit 1; \
	}

# Create new project from template
create template-name target-dir=".":
	@./project-setup/setup-project.sh --template {{template-name}} --target {{target-dir}}

# Test the Python template (baseline + violations)
test:
	@./tests/run-tests.sh python

# Test the Java template (baseline + violations)
test-java:
	@./tests/run-tests.sh java

# Test the Go template (baseline + violations)
test-go:
	@./tests/run-tests.sh go

# Test the Elixir template (baseline + violations)
test-elixir:
	@./tests/run-tests.sh elixir

# Test the C++ template (baseline + violations)
test-cpp:
	@./tests/run-tests.sh cpp

# Test the Rust template (baseline + violations)
test-rust:
	@./tests/run-tests.sh rust

# Test all templates (baseline + violations)
test-all:
	@./tests/run-tests.sh all
