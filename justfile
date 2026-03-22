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
#    - init/destroy/clean/help on top, ci and other tests on the bottom, between other groups
# =============================================================================

# Default recipe: list all available recipes
_default:
    @just help

# Show help message
help:
	@clear
	@echo ""
	@printf "\033[0;34m=== ai-guardrails ===\033[0m\n"
	@echo ""
	@printf "\033[0;33mSetup & Lifecycle:\033[0m\n"
	@printf "  %-40s %s\n" "init" "Install templates and set up aliases"
	@printf "  %-40s %s\n" "check" "Check if all required tools are installed"
	@printf "  %-40s %s\n" "help" "Show this help message"
	@echo ""
	@printf "\033[0;33mProject Scaffolding:\033[0m\n"
	@printf "  %-40s %s\n" "create <template> <target-dir>" "Create new project from template"
	@printf "  %-40s %s\n" "update" "Update templates to latest version"
	@echo ""
	@printf "  Available templates:\n"
	@printf "    %-36s %s\n" "python-cli-base" "Python CLI application"
	@printf "    %-36s %s\n" "java-cli-base" "Java CLI application"
	@printf "    %-36s %s\n" "go-cli-base" "Go CLI application"
	@printf "    %-36s %s\n" "elixir-otp-base" "Elixir OTP application"
	@printf "    %-36s %s\n" "cpp-cli-base" "C++ CLI application"
	@printf "    %-36s %s\n" "rust-cli-base" "Rust CLI application"
	@echo ""
	@printf "\033[0;33mCode Quality:\033[0m\n"
	@printf "  %-40s %s\n" "code-spell" "Check spelling across the repository"
	@printf "  %-40s %s\n" "code-semgrep" "Run semgrep rules against repo scripts"
	@printf "  %-40s %s\n" "code-shellcheck" "Lint shell scripts with ShellCheck"
	@echo ""
	@printf "\033[0;33mBaseline Tests:\033[0m\n"
	@printf "  %-40s %s\n" "baseline" "Generate all templates and run just ci"
	@printf "  %-40s %s\n" "baseline-python" "Generate Python template and run just ci"
	@printf "  %-40s %s\n" "baseline-java" "Generate Java template and run just ci"
	@printf "  %-40s %s\n" "baseline-go" "Generate Go template and run just ci"
	@printf "  %-40s %s\n" "baseline-elixir" "Generate Elixir template and run just ci"
	@printf "  %-40s %s\n" "baseline-cpp" "Generate C++ template and run just ci"
	@printf "  %-40s %s\n" "baseline-rust" "Generate Rust template and run just ci"
	@echo ""
	@printf "\033[0;33mCI & Testing:\033[0m\n"
	@printf "  %-40s %s\n" "test" "Run all baseline + violation tests"
	@printf "  %-40s %s\n" "test-python" "Run Python baseline + violation tests"
	@printf "  %-40s %s\n" "test-java" "Run Java baseline + violation tests"
	@printf "  %-40s %s\n" "test-go" "Run Go baseline + violation tests"
	@printf "  %-40s %s\n" "test-elixir" "Run Elixir baseline + violation tests"
	@printf "  %-40s %s\n" "test-cpp" "Run C++ baseline + violation tests"
	@printf "  %-40s %s\n" "test-rust" "Run Rust baseline + violation tests"
	@printf "  %-40s %s\n" "ci" "Run all checks + all template tests"
	@echo ""

# Install templates and set up aliases
init:
	@echo ""
	@printf "Checking prerequisites...\n"
	@echo ""
	@# Check for git
	@if ! command -v git >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: git is not installed\033[0m\n"; \
		printf "  Please install git first: https://git-scm.com/downloads\n"; \
		echo ""; \
		exit 1; \
	fi
	@printf "\033[32m✓ git is installed\033[0m\n"
	@# Check for python
	@if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: python is not installed\033[0m\n"; \
		printf "  Please install Python 3.12 or higher: https://www.python.org/downloads/\n"; \
		echo ""; \
		exit 1; \
	fi
	@printf "\033[32m✓ python is installed\033[0m\n"
	@# Check for uv
	@if ! command -v uv >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: uv is not installed\033[0m\n"; \
		printf "  Please install uv: https://docs.astral.sh/uv/getting-started/installation/\n"; \
		printf "  Quick install: curl -LsSf https://astral.sh/uv/install.sh | sh\n"; \
		echo ""; \
		exit 1; \
	fi
	@printf "\033[32m✓ uv is installed\033[0m\n"
	@# Check for just
	@if ! command -v just >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: just is not installed\033[0m\n"; \
		printf "  Please install just: https://github.com/casey/just#installation\n"; \
		echo ""; \
		exit 1; \
	fi
	@printf "\033[32m✓ just is installed\033[0m\n"
	@# Check for claude CLI
	@if ! command -v claude >/dev/null 2>&1; then \
		printf "\033[31m✗ Error: claude CLI is not installed\033[0m\n"; \
		printf "  Please install Claude Code: https://claude.com/claude-code\n"; \
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
	@printf "All prerequisites met! Installing AI Templates...\n"
	@echo ""
	@./project-setup/setup_aliases.sh && printf "\033[32m✓ init completed successfully\033[0m\n" || { printf "\033[31m✗ init failed\033[0m\n"; exit 1; }
	@echo ""

# Check if all required tools are installed
check:
	@echo ""
	@missing=0; \
	for tool in git just copier codespell semgrep shellcheck; do \
		if command -v "$tool" >/dev/null 2>&1; then \
			printf "\033[32m  ✓ %s\033[0m\n" "$tool"; \
		else \
			printf "\033[31m  ✗ %s not found\033[0m\n" "$tool"; \
			missing=$((missing + 1)); \
		fi; \
	done; \
	echo ""; \
	if [ "$missing" -gt 0 ]; then \
		printf "\033[31m✗ %d required tool(s) missing\033[0m\n" "$missing"; \
		exit 1; \
	fi; \
	printf "\033[32m✓ all required tools are installed\033[0m\n"
	@echo ""

# Create new project from template
create template-name target-dir=".":
	@echo ""
	@./project-setup/setup-project.sh --template {{template-name}} --target {{target-dir}} && printf "\033[32m✓ project created successfully\033[0m\n" || { printf "\033[31m✗ project creation failed\033[0m\n"; exit 1; }
	@echo ""

# Update templates to latest version
update:
	@echo ""
	@printf "Updating AI Templates to latest version...\n"
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

# Check spelling across the repository
code-spell:
	@echo ""
	@printf "\033[0;34m=== Running Codespell ===\033[0m\n"
	@codespell --ignore-words config/codespell/ignore.txt \
		--skip=".git,blueprints,violations,.beads,docs,scratch,*.yml,*.yaml" \
		. \
		&& printf "\033[32m✓ codespell passed\033[0m\n" \
		|| { printf "\033[31m✗ codespell found spelling errors\033[0m\n"; exit 1; }
	@echo ""

# Run semgrep rules against repo scripts
code-semgrep:
	@echo ""
	@printf "\033[0;34m=== Running Semgrep Static Analysis ===\033[0m\n"
	@semgrep --config config/semgrep/ --error \
		tests/ project-setup/ justfile \
		&& printf "\033[32m✓ semgrep passed\033[0m\n" \
		|| { printf "\033[31m✗ semgrep found violations\033[0m\n"; exit 1; }
	@echo ""

# Lint shell scripts with ShellCheck
code-shellcheck:
	@echo ""
	@printf "\033[0;34m=== Running ShellCheck ===\033[0m\n"
	@find tests/ project-setup/ -name '*.sh' -print0 \
		| xargs -0 shellcheck \
		&& printf "\033[32m✓ shellcheck passed\033[0m\n" \
		|| { printf "\033[31m✗ shellcheck found issues\033[0m\n"; exit 1; }
	@echo ""

# Generate all templates and run just ci (no violation tests)
baseline:
	@echo ""
	@./tests/run-tests.sh all baseline && printf "\033[32m✓ all baselines passed\033[0m\n" || { printf "\033[31m✗ baseline tests failed\033[0m\n"; exit 1; }
	@echo ""

# Generate Python template and run just ci
baseline-python:
	@echo ""
	@./tests/run-tests.sh python baseline && printf "\033[32m✓ python baseline passed\033[0m\n" || { printf "\033[31m✗ python baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate Java template and run just ci
baseline-java:
	@echo ""
	@./tests/run-tests.sh java baseline && printf "\033[32m✓ java baseline passed\033[0m\n" || { printf "\033[31m✗ java baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate Go template and run just ci
baseline-go:
	@echo ""
	@./tests/run-tests.sh go baseline && printf "\033[32m✓ go baseline passed\033[0m\n" || { printf "\033[31m✗ go baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate Elixir template and run just ci
baseline-elixir:
	@echo ""
	@./tests/run-tests.sh elixir baseline && printf "\033[32m✓ elixir baseline passed\033[0m\n" || { printf "\033[31m✗ elixir baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate C++ template and run just ci
baseline-cpp:
	@echo ""
	@./tests/run-tests.sh cpp baseline && printf "\033[32m✓ cpp baseline passed\033[0m\n" || { printf "\033[31m✗ cpp baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate Rust template and run just ci
baseline-rust:
	@echo ""
	@./tests/run-tests.sh rust baseline && printf "\033[32m✓ rust baseline passed\033[0m\n" || { printf "\033[31m✗ rust baseline failed\033[0m\n"; exit 1; }
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

# Run all checks and all template tests
ci: check code-spell code-semgrep code-shellcheck test
	@echo ""
	@printf "\033[32m✓ ci passed\033[0m\n"
	@echo ""
