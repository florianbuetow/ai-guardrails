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
# 7. Targets must be shown in groups separated by empty newlines in the help section.
#    - init/destory/clean/help on top, ci and other tests on the bottom, between other groups
# =============================================================================

# Default recipe: list all available recipes
_default:
    @just help

# Show help message
help:
	@clear
	@echo ""
	@printf "  just help                              - Show this help message\n"
	@printf "  just init                              - Install templates and set up aliases\n"
	@echo ""
	@printf "  just update                            - Update templates to latest version\n"
	@printf "  just create <template> <target-dir>    - Create new project from template\n"
	@echo ""
	@printf "  For <template> choose one of:\n"
	@printf "    python-cli-base                        - Python CLI application\n"
	@printf "    java-cli-base                          - Java CLI application\n"
	@printf "    elixir-otp-base                        - Elixir OTP application\n"
	@printf "    go-cli-base                            - Go CLI application\n"
	@printf "    cpp-cli-base                           - C++ CLI application\n"
	@printf "    rust-cli-base                          - Rust CLI application\n"
	@echo ""
	@printf "  just test                              - Run all baseline + violation tests\n"
	@printf "  just test-python                       - Run Python baseline + violation tests\n"
	@printf "  just test-java                         - Run Java baseline + violation tests\n"
	@printf "  just test-go                           - Run Go baseline + violation tests\n"
	@printf "  just test-elixir                       - Run Elixir baseline + violation tests\n"
	@printf "  just test-cpp                          - Run C++ baseline + violation tests\n"
	@printf "  just test-rust                         - Run Rust baseline + violation tests\n"
	@echo ""

# Install templates and set up aliases
init:
	@echo ""
	@echo "Checking prerequisites..."
	@echo ""
	@# Check for git
	@if ! command -v git >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: git is not installed\033[0m\n"; \
		echo "  Please install git first: https://git-scm.com/downloads"; \
		echo ""; \
		exit 1; \
	fi
	@printf "\033[32m✓ git is installed\033[0m\n"
	@# Check for python
	@if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: python is not installed\033[0m\n"; \
		echo "  Please install Python 3.12 or higher: https://www.python.org/downloads/"; \
		echo ""; \
		exit 1; \
	fi
	@printf "\033[32m✓ python is installed\033[0m\n"
	@# Check for uv
	@if ! command -v uv >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: uv is not installed\033[0m\n"; \
		echo "  Please install uv: https://docs.astral.sh/uv/getting-started/installation/"; \
		echo "  Quick install: curl -LsSf https://astral.sh/uv/install.sh | sh"; \
		echo ""; \
		exit 1; \
	fi
	@printf "\033[32m✓ uv is installed\033[0m\n"
	@# Check for just
	@if ! command -v just >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: just is not installed\033[0m\n"; \
		echo "  Please install just: https://github.com/casey/just#installation"; \
		echo ""; \
		exit 1; \
	fi
	@printf "\033[32m✓ just is installed\033[0m\n"
	@# Check for claude CLI
	@if ! command -v claude >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: claude CLI is not installed\033[0m\n"; \
		echo "  Please install Claude Code: https://claude.com/claude-code"; \
		echo ""; \
		exit 1; \
	fi
	@printf "\033[32m✓ claude CLI is installed\033[0m\n"
	@# Check for elixir (optional, for Elixir templates)
	@if command -v elixir >/dev/null 2>&1; then \
		printf "\033[32m✓ elixir is installed\033[0m\n"; \
	else \
		printf "\033[33m⚠ elixir is not installed (needed for Elixir templates)\033[0m\n"; \
	fi
	@echo ""
	@echo "All prerequisites met! Installing AI Templates..."
	@echo ""
	@./project-setup/setup_aliases.sh && printf "\033[32m✓ init completed successfully\033[0m\n" || { printf "\033[31m✗ init failed\033[0m\n"; exit 1; }
	@echo ""

# Update templates to latest version
update:
	@echo ""
	@echo "Updating AI Templates to latest version..."
	@echo ""
	@if ! command -v git >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: git is not installed\033[0m\n"; \
		echo ""; \
		exit 1; \
	fi
	@git pull && { \
		printf "\033[32m✓ Templates updated successfully!\033[0m\n"; \
	} || { \
		printf "\033[31m✗ Failed to update templates\033[0m\n"; \
		exit 1; \
	}
	@echo ""

# Create new project from template
create template-name target-dir=".":
	@echo ""
	@./project-setup/setup-project.sh --template {{template-name}} --target {{target-dir}} && printf "\033[32m✓ project created successfully\033[0m\n" || { printf "\033[31m✗ project creation failed\033[0m\n"; exit 1; }
	@echo ""

# Test all templates (baseline + violations)
test:
	@echo ""
	@./tests/run-tests.sh all && printf "\033[32m✓ all tests passed\033[0m\n" || { printf "\033[31m✗ tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test the Python template (baseline + violations)
test-python:
	@echo ""
	@./tests/run-tests.sh python && printf "\033[32m✓ python tests passed\033[0m\n" || { printf "\033[31m✗ python tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test the Java template (baseline + violations)
test-java:
	@echo ""
	@./tests/run-tests.sh java && printf "\033[32m✓ java tests passed\033[0m\n" || { printf "\033[31m✗ java tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test the Go template (baseline + violations)
test-go:
	@echo ""
	@./tests/run-tests.sh go && printf "\033[32m✓ go tests passed\033[0m\n" || { printf "\033[31m✗ go tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test the Elixir template (baseline + violations)
test-elixir:
	@echo ""
	@./tests/run-tests.sh elixir && printf "\033[32m✓ elixir tests passed\033[0m\n" || { printf "\033[31m✗ elixir tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test the C++ template (baseline + violations)
test-cpp:
	@echo ""
	@./tests/run-tests.sh cpp && printf "\033[32m✓ cpp tests passed\033[0m\n" || { printf "\033[31m✗ cpp tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test the Rust template (baseline + violations)
test-rust:
	@echo ""
	@./tests/run-tests.sh rust && printf "\033[32m✓ rust tests passed\033[0m\n" || { printf "\033[31m✗ rust tests failed\033[0m\n"; exit 1; }
	@echo ""
