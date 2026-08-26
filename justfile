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
	@printf "  %-40s %s\n" "check-clojure" "Check Clojure template prerequisites"
	@printf "  %-40s %s\n" "show-libs" "List direct library dependencies declared by all templates"
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
	@printf "    %-36s %s\n" "cpp-3dgame-base" "C++ 3D game application"
	@printf "    %-36s %s\n" "rust-cli-base" "Rust CLI application"
	@printf "    %-36s %s\n" "kotlin-cli-base" "Kotlin CLI application"
	@printf "    %-36s %s\n" "scala-cli-base" "Scala CLI application"
	@printf "    %-36s %s\n" "clojure-cli-base" "Clojure CLI application"
	@printf "    %-36s %s\n" "react-vite-typescript-base" "React + Vite + TypeScript application"
	@printf "    %-36s %s\n" "mcp-server-typescript-base" "TypeScript MCP server"
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
	@printf "  %-40s %s\n" "baseline-cpp-3dgame" "Generate C++ 3D game template and run just ci"
	@printf "  %-40s %s\n" "baseline-rust" "Generate Rust template and run just ci"
	@printf "  %-40s %s\n" "baseline-kotlin" "Generate Kotlin template and run just ci"
	@printf "  %-40s %s\n" "baseline-scala" "Generate Scala template and run just ci"
	@printf "  %-40s %s\n" "baseline-clojure" "Generate Clojure template and run just ci"
	@printf "  %-40s %s\n" "baseline-typescript" "Generate TypeScript template and run just ci"
	@printf "  %-40s %s\n" "baseline-mcp-typescript" "Generate TypeScript MCP server template and run just ci"
	@echo ""
	@printf "\033[0;33mCI & Testing:\033[0m\n"
	@printf "  %-40s %s\n" "test-info" "Test direct dependency inventory output"
	@printf "  %-40s %s\n" "test-prerequisites" "Verify every template checks prerequisites first"
	@printf "  %-40s %s\n" "test" "Run all baseline + violation tests"
	@printf "  %-40s %s\n" "test-python" "Run Python baseline + violation tests"
	@printf "  %-40s %s\n" "test-java" "Run Java baseline + violation tests"
	@printf "  %-40s %s\n" "test-go" "Run Go baseline + violation tests"
	@printf "  %-40s %s\n" "test-elixir" "Run Elixir baseline + violation tests"
	@printf "  %-40s %s\n" "test-cpp" "Run C++ baseline + violation tests"
	@printf "  %-40s %s\n" "test-cpp-3dgame" "Run C++ 3D game baseline + violation tests"
	@printf "  %-40s %s\n" "test-cpp-3dgame-linux" "Run C++ 3D game full CI in a Linux (amd64) container"
	@printf "  %-40s %s\n" "test-rust" "Run Rust baseline + violation tests"
	@printf "  %-40s %s\n" "test-kotlin" "Run Kotlin baseline + violation tests"
	@printf "  %-40s %s\n" "test-scala" "Run Scala baseline + violation tests"
	@printf "  %-40s %s\n" "test-clojure" "Run Clojure baseline + violation tests"
	@printf "  %-40s %s\n" "test-typescript" "Run TypeScript baseline + violation tests"
	@printf "  %-40s %s\n" "test-mcp-typescript" "Run TypeScript MCP server baseline + violation tests"
	@printf "  %-40s %s\n" "test-create" "Run just create for all templates"
	@printf "  %-40s %s\n" "ci" "Run all checks + all template tests (quiet)"
	@printf "  %-40s %s\n" "ci-verbose" "Run all checks + all template tests (verbose)"
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

# Check Clojure template prerequisites before generation or testing
check-clojure:
	@echo ""
	@missing=0; \
	for tool in git java clojure just copier codespell semgrep trivy timeout; do \
		if command -v "$tool" >/dev/null 2>&1; then \
			printf "\033[32m  ✓ %s\033[0m\n" "$tool"; \
		else \
			printf "\033[31m  ✗ %s not found\033[0m\n" "$tool"; \
			missing=$((missing + 1)); \
		fi; \
	done; \
	if [ "$missing" -gt 0 ]; then \
		printf "\033[31m✗ %d Clojure prerequisite(s) missing\033[0m\n" "$missing"; \
		exit 1; \
	fi; \
	java_major="$(java -XshowSettings:properties -version 2>&1 | sed -n 's/^[[:space:]]*java\.specification\.version = //p')"; \
	case "$java_major" in \
		''|*[!0-9]*) printf "\033[31m✗ unable to determine a numeric JDK version\033[0m\n"; exit 1 ;; \
	esac; \
	if [ "$java_major" -lt 21 ]; then \
		printf "\033[31m✗ JDK 21+ is required, found JDK %s\033[0m\n" "$java_major"; \
		exit 1; \
	fi; \
	printf "\033[32m✓ all Clojure prerequisites are installed\033[0m\n"
	@echo ""

# List direct library dependencies declared by all templates
show-libs:
	@echo ""
	@printf "\033[0;34m=== Template Direct Dependency Info ===\033[0m\n"
	@echo ""
	@if command -v python3 >/dev/null 2>&1; then \
		python_cmd="python3"; \
	elif command -v python >/dev/null 2>&1; then \
		python_cmd="python"; \
	else \
		printf "\033[31m✗ Error: python is not installed\033[0m\n"; \
		echo ""; \
		exit 1; \
	fi; \
	"$python_cmd" project-setup/template-info.py \
		&& printf "\033[32m✓ show-libs completed successfully\033[0m\n" \
		|| { printf "\033[31m✗ show-libs failed\033[0m\n"; exit 1; }
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
		--exclude='tests' \
		--exclude='violations' \
		. \
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

# Generate C++ 3D game template and run just ci
baseline-cpp-3dgame:
	@echo ""
	@./tests/run-tests.sh cpp-3dgame baseline && printf "\033[32m✓ cpp-3dgame baseline passed\033[0m\n" || { printf "\033[31m✗ cpp-3dgame baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate Rust template and run just ci
baseline-rust:
	@echo ""
	@./tests/run-tests.sh rust baseline && printf "\033[32m✓ rust baseline passed\033[0m\n" || { printf "\033[31m✗ rust baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate Kotlin template and run just ci
baseline-kotlin:
	@echo ""
	@./tests/run-tests.sh kotlin baseline && printf "\033[32m✓ kotlin baseline passed\033[0m\n" || { printf "\033[31m✗ kotlin baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate Scala template and run just ci
baseline-scala:
	@echo ""
	@./tests/run-tests.sh scala baseline && printf "\033[32m✓ scala baseline passed\033[0m\n" || { printf "\033[31m✗ scala baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate Clojure template and run just ci
baseline-clojure: check-clojure
	@echo ""
	@./tests/run-tests.sh clojure baseline && printf "\033[32m✓ clojure baseline passed\033[0m\n" || { printf "\033[31m✗ clojure baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate TypeScript template and run just ci
baseline-typescript:
	@echo ""
	@./tests/run-tests.sh typescript baseline && printf "\033[32m✓ typescript baseline passed\033[0m\n" || { printf "\033[31m✗ typescript baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Generate TypeScript MCP server template and run just ci
baseline-mcp-typescript:
	@echo ""
	@./tests/run-tests.sh mcp-typescript baseline && printf "\033[32m✓ typescript MCP server baseline passed\033[0m\n" || { printf "\033[31m✗ typescript MCP server baseline failed\033[0m\n"; exit 1; }
	@echo ""

# Test direct dependency inventory output
test-info:
	@echo ""
	@printf "\033[0;34m=== Testing Template Dependency Info ===\033[0m\n"
	@if command -v python3 >/dev/null 2>&1; then \
		python_cmd="python3"; \
	elif command -v python >/dev/null 2>&1; then \
		python_cmd="python"; \
	else \
		printf "\033[31m✗ Error: python is not installed\033[0m\n"; \
		echo ""; \
		exit 1; \
	fi; \
	"$python_cmd" tests/test_template_info.py \
		&& printf "\033[32m✓ template info tests passed\033[0m\n" \
		|| { printf "\033[31m✗ template info tests failed\033[0m\n"; exit 1; }
	@echo ""

# Verify every template checks prerequisites before initialization and CI
test-prerequisites:
	@echo ""
	@printf "\033[0;34m=== Testing Template Prerequisite Contracts ===\033[0m\n"
	@python3 tests/test_template_prerequisites.py \
		&& printf "\033[32m✓ template prerequisite contracts passed\033[0m\n" \
		|| { printf "\033[31m✗ template prerequisite contracts failed\033[0m\n"; exit 1; }
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

# Test the C++ 3D game template (baseline + violations)
test-cpp-3dgame:
	@echo ""
	@./tests/run-tests.sh cpp-3dgame && printf "\033[32m✓ cpp-3dgame tests passed\033[0m\n" || { printf "\033[31m✗ cpp-3dgame tests failed\033[0m\n"; exit 1; }
	@echo ""

# Run the C++ 3D game template's full CI inside a Linux amd64 container.
# amd64-only by decision: Infer, DXC, and gltfpack ship official Linux
# binaries exclusively for x86_64 (runs via Rosetta on Apple Silicon).
# Conan dependencies and installed tools persist in named Docker volumes,
# so only the first run pays the from-source dependency build.
test-cpp-3dgame-linux:
	#!/usr/bin/env bash
	set -euo pipefail
	echo ""
	if ! command -v docker >/dev/null 2>&1; then
		printf "\033[31m✗ docker is not installed\033[0m\n"
		exit 1
	fi
	if ! docker info >/dev/null 2>&1; then
		printf "\033[31m✗ docker daemon is not running (start Docker Desktop or 'colima start --vz-rosetta')\033[0m\n"
		exit 1
	fi
	printf "\033[0;34m=== Building Linux CI image ===\033[0m\n"
	docker build --platform linux/amd64 \
		-f blueprints/cpp-3dgame-base/docker/Dockerfile.linux-ci \
		-t cpp-3dgame-linux-ci \
		blueprints/cpp-3dgame-base/docker
	printf "\033[0;34m=== Running template CI in Linux container ===\033[0m\n"
	docker run --rm --platform linux/amd64 \
		-v cpp-3dgame-conan-cache:/root/.conan2 \
		-v cpp-3dgame-tools-cache:/root/.local \
		-v "$(pwd)":/repo:ro \
		cpp-3dgame-linux-ci /repo/tests/docker/cpp-3dgame-linux-ci.sh \
		&& printf "\033[32m✓ cpp-3dgame Linux container CI passed\033[0m\n" \
		|| { printf "\033[31m✗ cpp-3dgame Linux container CI failed\033[0m\n"; exit 1; }
	echo ""

# Test the Rust template (baseline + violations)
test-rust:
	@echo ""
	@./tests/run-tests.sh rust && printf "\033[32m✓ rust tests passed\033[0m\n" || { printf "\033[31m✗ rust tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test the Kotlin template (baseline + violations)
test-kotlin:
	@echo ""
	@./tests/run-tests.sh kotlin && printf "\033[32m✓ kotlin tests passed\033[0m\n" || { printf "\033[31m✗ kotlin tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test the Scala template (baseline + violations)
test-scala:
	@echo ""
	@./tests/run-tests.sh scala && printf "\033[32m✓ scala tests passed\033[0m\n" || { printf "\033[31m✗ scala tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test the Clojure template (baseline + violations)
test-clojure: check-clojure
	@echo ""
	@./tests/run-tests.sh clojure && printf "\033[32m✓ clojure tests passed\033[0m\n" || { printf "\033[31m✗ clojure tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test the TypeScript template (baseline + violations)
test-typescript:
	@echo ""
	@./tests/run-tests.sh typescript && printf "\033[32m✓ typescript tests passed\033[0m\n" || { printf "\033[31m✗ typescript tests failed\033[0m\n"; exit 1; }
	@echo ""

# Run TypeScript MCP server baseline + violation tests
test-mcp-typescript:
	@echo ""
	@./tests/run-tests.sh mcp-typescript && printf "\033[32m✓ typescript MCP server tests passed\033[0m\n" || { printf "\033[31m✗ typescript MCP server tests failed\033[0m\n"; exit 1; }
	@echo ""

# Test just create for all templates
test-create:
    #!/usr/bin/env bash
    set -euo pipefail
    echo ""
    # `just ci` wires fd 3 to its live terminal so steps can surface progress
    # past its output capture. Detect it once; when run directly (fd 3 closed)
    # this stays a no-op and only the verbose lines below are shown.
    if { true >&3; } 2>/dev/null; then
        quiet_progress=1
    else
        quiet_progress=0
    fi
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' EXIT
    for template_path in blueprints/*/; do
        template="$(basename "$template_path")"
        shortname="${template%-base}"
        target_dir="$tmp_dir/$shortname"
        if [ "$quiet_progress" = "1" ]; then
            printf "\033[0;34m  · testing %s\033[0m\n" "$template" >&3
        fi
        printf "\033[0;34mTesting: just create %s\033[0m\n" "$template"
        if ! just create "$template" "$target_dir"; then
            printf "\033[31m✗ test-create failed for %s\033[0m\n" "$template"
            exit 1
        fi
        printf "\033[0;34mRunning: just ci in %s\033[0m\n" "$shortname"
        if ! (cd "$target_dir" && just ci); then
            printf "\033[31m✗ test-create ci failed for %s\033[0m\n" "$template"
            exit 1
        fi
        if [ -z "$target_dir" ] || [ "$target_dir" = "/" ]; then
            printf "\033[31m✗ refusing to remove unsafe path: %s\033[0m\n" "$target_dir"
            exit 1
        fi
        if [ -d "$target_dir" ]; then
            rm -rf "$target_dir"
        fi
    done
    printf "\033[32m✓ test-create passed for all templates\033[0m\n"
    echo ""

# Run all checks and all template tests
ci-verbose: check test-prerequisites code-spell code-semgrep code-shellcheck test-info test test-create
	@echo ""
	@printf "\033[32m✓ ci-verbose passed\033[0m\n"
	@echo ""

# Run all checks and all template tests (quiet; details only on failure)
ci:
    #!/usr/bin/env bash
    set -uo pipefail
    # Wire fd 3 to this live terminal so individual steps can surface per-item
    # progress past the output capture below (which only prints on failure).
    exec 3>&1
    echo ""
    # Keep this list identical to ci-verbose's dependencies so both run the
    # exact same tests; only the output verbosity differs.
    steps=(check test-prerequisites code-spell code-semgrep code-shellcheck test-info test test-create)
    for step in "${steps[@]}"; do
        printf "\033[0;34m▶ starting %s\033[0m\n" "$step"
        if output="$(just "$step" 2>&1)"; then
            printf "\033[32m  ✓ %s completed\033[0m\n" "$step"
        else
            printf "%s\n" "$output"
            printf "\033[31m✗ ci failed: %s exited with errors\033[0m\n" "$step"
            exit 1
        fi
    done
    echo ""
    printf "\033[32m✓ ci passed\033[0m\n"
    echo ""
