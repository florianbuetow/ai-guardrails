# Python Project Setup Template

This directory contains a complete setup system for bootstrapping new Python projects using Claude Code.

## Contents

### Files in This Directory

- **`setup-project-python.md`** - The Python project template and guide
  - Contains comprehensive instructions for creating Python projects with AI agents
  - Includes project structure requirements, dependency management rules, and conventions
  - Defines what should go in `AGENTS.md` and `CLAUDE.md` files for generated projects
  - Emphasizes using `uv` exclusively for package management (never pip or python directly)
  - Serves as the "blueprint" that AI agents follow when creating new projects

- **`setup-project-python-cli-base-claude.sh`** - Automated project creation script
  - Bash script that automates the entire project creation process
  - Takes a project name/path as an argument
  - Uses the locally cloned template (no download needed)
  - Invokes Claude Code to set up the project according to the template
  - Cleans up temporary files after completion

- **`setup_aliases.sh`** - Automated alias installation script
  - Automatically detects your shell (zsh, bash, fish)
  - Creates ~/scripts directory
  - Clones this repository to ~/scripts/ai-guardrails (or updates if already exists)
  - Adds the 'newpy' alias to create new projects
  - Adds the 'update-templates' alias to update the templates
  - Handles duplicate detection to avoid conflicts (idempotent)

## Quick Start

### Option 1: Automated Setup (Recommended)

Run the automated setup script to install the `newpy` alias:

```bash
./setup_aliases.sh
```

This script will:
- Automatically detect your shell (zsh, bash, or fish)
- Create the `~/scripts` directory
- Clone this repository to `~/scripts/ai-guardrails` (or update if it already exists)
- Add the `newpy` alias to your shell configuration file (for creating projects)
- Add the `update-templates` alias to your shell configuration file (for updating templates)
- The script is idempotent - safe to run multiple times without creating duplicates

After running the setup script:

```bash
# Reload your shell configuration
source ~/.zshrc  # or ~/.bashrc, depending on your shell

# Create a new Python project
newpy my-awesome-project

# Update templates to the latest version (optional)
update-templates
```

### Option 2: Direct Usage

Run the project creation script directly without installing an alias:

```bash
./setup-project-python-cli-base-claude.sh my-new-project
```

Or use it in the current directory:

```bash
./setup-project-python-cli-base-claude.sh .
```

### Option 3: Manual Alias Setup

If you prefer to set up the alias manually:

#### For Zsh (macOS default):

1. Clone the repository to your scripts directory:
```bash
mkdir -p ~/scripts
cd ~/scripts
git clone https://github.com/florianbuetow/ai-guardrails.git
```

2. Add these aliases to your `~/.zshrc`:
```bash
# Aliases for AI project templates
alias newpy='~/scripts/ai-guardrails/project-setup/setup-project-python-cli-base-claude.sh'
alias update-templates='cd ~/scripts/ai-guardrails && git pull && cd - > /dev/null'
```

3. Reload your shell configuration:
```bash
source ~/.zshrc
```

#### For Bash:

1. Clone the repository to your scripts directory:
```bash
mkdir -p ~/scripts
cd ~/scripts
git clone https://github.com/florianbuetow/ai-guardrails.git
```

2. Add these aliases to your `~/.bashrc` or `~/.bash_profile`:
```bash
# Aliases for AI project templates
alias newpy='~/scripts/ai-guardrails/project-setup/setup-project-python-cli-base-claude.sh'
alias update-templates='cd ~/scripts/ai-guardrails && git pull && cd - > /dev/null'
```

3. Reload your shell configuration:
```bash
source ~/.bashrc  # or source ~/.bash_profile
```

## How It Works

### Setup Phase (run once)

When you run `./setup_aliases.sh`:

1. Creates `~/scripts` directory if it doesn't exist
2. Clones this repository to `~/scripts/ai-guardrails` (or updates it if already exists)
3. Detects your shell and adds aliases to the appropriate configuration file
4. Sets up two aliases:
   - `newpy` - creates new Python projects
   - `update-templates` - updates the templates to the latest version

### Project Creation Phase (run anytime)

When you run `newpy my-project-name`:

1. The script creates a new directory with the specified name (or uses the current directory if you pass `.`)
2. It copies `setup-project-python.md` from `~/scripts/ai-guardrails/project-setup/` to your project directory
3. It invokes Claude Code with the instruction: "Follow the setup instructions in setup-project-python.md to the teeth."
4. Claude Code reads the template and creates:
   - Complete project structure (`src/`, `scripts/`, `data/`, etc.)
   - `pyproject.toml` with Python 3.12+ requirements
   - `justfile` with `init`, `run`, and `help` recipes
   - `README.md` with project documentation
   - `AGENTS.md` with AI agent development rules
   - `CLAUDE.md` as a redirect to AGENTS.md
   - `src/main.py` with a working example
5. The script cleans up the template file
6. Your project is ready to use with `just init` and `just run`

### Updating Templates

When you run `update-templates`:

1. Navigates to `~/scripts/ai-guardrails`
2. Runs `git pull` to fetch the latest templates
3. Returns to your previous directory

## Project Template Features

Projects created with this template follow these principles:

- **Python 3.12+** as the minimum version
- **uv exclusively** for package management (never `pip` or `python` directly)
- **Strict directory structure**: `src/` for code, `scripts/` for utilities, `data/` for files
- **Justfile workflow**: `just init`, `just run`, `just help`
- **No placeholders**: Everything is immediately runnable
- **AGENTS.md rules**: AI-specific development guidelines for all AI agents working on the project

## Requirements

- Python 3.12 or higher
- `uv` package manager installed
- `claude` CLI tool (Claude Code) installed
- `git` (for cloning and updating templates)
- Internet connection (for initial setup and template updates)

## Examples

Create a new data analysis project:
```bash
newpy data-analysis-tool
cd data-analysis-tool
just init
just run
```

Create a project in the current directory:
```bash
mkdir my-project && cd my-project
newpy .
just init
just run
```
