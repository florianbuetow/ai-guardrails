# Python Project Bootstrapping Guide

This file contains instructions for creating a new Python project using AI agents and AI-assisted development tools. After running these instructions and setting up your project, **delete this file**.

---

## How to Use This Guide

1. Copy the **Project Setup Prompt** below
2. Paste it into your AI assistant with your project name and description
3. The AI will generate all necessary files
4. Run `just init` to initialize the project
5. **Delete this INIT.md file**

---

## Project Setup Prompt

Copy and customize this prompt when asking an AI assistant to create a new Python project:

```text
You are an experienced Python developer and build engineer. Create a new Python project skeleton with the following requirements:

==================================================
ROLE
==================================================
Produce a minimal but clean project skeleton:
- Complete directory tree structure
- Full contents of all files (pyproject.toml, justfile, AGENTS.md, src/main.py)
- No placeholders - everything must be directly runnable
- All instructions are strict requirements, especially regarding "uv" usage

==================================================
LANGUAGE & PYTHON VERSION
==================================================
- All content must be in **English**
- Target **Python 3.12 or higher**
- `pyproject.toml` must declare: `requires-python = ">=3.12"`

==================================================
PACKAGE MANAGEMENT
==================================================
- Use **uv** exclusively for package management and execution
- **NEVER** use: `pip install`, `python -m pip`, `uv pip`, `python`, or `python3`
- Virtual environment: create/update with `uv sync` only
- Python execution: **always** use `uv run <script>` to ensure venv is used
- Dependencies: manage only through `uv` and `pyproject.toml`

==================================================
PROJECT STRUCTURE
==================================================
Required structure:

project-name/
├── pyproject.toml
├── justfile
├── README.md
├── AGENTS.md
├── src/
│   └── main.py
├── scripts/        # Optional utility scripts
├── prompts/        # Optional LLM prompt templates
└── data/
    ├── input/
    └── output/

Rules:
- All source code in `src/`
- Utility scripts in `scripts/`
- Input data in `data/input/`
- Output data in `data/output/`
- **Never** create Python files in project root

==================================================
pyproject.toml
==================================================
Must include:
- Project name, version, description
- `requires-python = ">=3.12"`
- Dependencies list (can be empty initially)
- Build system configuration:
  ```toml
  [build-system]
  requires = ["hatchling"]
  build-backend = "hatchling.build"

  [tool.hatch.build.targets.wheel]
  packages = ["src"]
  ```
- Must work with `uv sync` without errors
- No mention of pip anywhere

==================================================
JUSTFILE
==================================================
Configuration:
- Set the default recipe to `--list` by adding at the top:
  ```
  _default:
      @just --list
  ```

Required recipes:

1. **help**:
   - Clear screen with `@clear`
   - Print blank line
   - Display custom help information or call `just --list`
   - Print blank line at end
   - Only recipe that may clear screen

2. **init**:
   - Create all necessary directories
   - Run `uv sync` to set up environment
   - Install any system dependencies (if applicable)
   - Never use `python` or `pip`

3. **run**:
   - Execute main program with `uv run src/main.py`
   - Never use `python` directly

Optional recipes (clean, test, etc.):
- Add descriptive comments above each recipe
- Use `uv run` for Python execution
- Follow blank-line convention

Conventions:
- Every recipe: start and end with `@echo ""`
- All descriptions in English
- Use `@` prefix for silent commands
- Add comments above recipes to document what they do

==================================================
src/main.py
==================================================
- Simple "Hello World" or minimal working example
- Executable via `uv run src/main.py`

==================================================
README.md
==================================================
Must include:

1. **Project title and description**:
   - Clear, concise description of what the project does

2. **Repository structure** (REQUIRED):
   - Directory tree showing all folders and key files
   - Short description for each folder explaining its purpose
   - Short description for each file explaining what it's for
   - Use code blocks with proper formatting

Example:
```
project-name/
├── pyproject.toml          # Project dependencies and metadata
├── justfile                # Build and run commands
├── AGENTS.md               # AI agent development rules
├── README.md               # This file
├── src/                    # Source code
│   └── main.py            # Main entry point
├── scripts/                # Utility scripts
├── prompts/                # LLM prompt templates
└── data/                   # Data files
    ├── input/             # Input data files
    └── output/            # Generated output files
```

3. **Setup instructions**:
   - How to initialize: `just init`
   - How to run: `just run`
   - Prerequisites (Python 3.12+, uv installed, just installed)

4. **Usage** (if applicable):
   - Basic usage examples
   - Command-line options

==================================================
AGENTS.md
==================================================
Create **AGENTS.md**, the AI agent development rules file, with:

Required sections:
1. **Testing rules**:
   - Test after every code change
   - Verify with `just run` after modifications

2. **Python execution rules**:
   - Execute only via `uv run <script>`
   - Create/update venv only via `uv sync`
   - Manage dependencies only through `uv` and `pyproject.toml`
   - FORBIDDEN: `python`, `python3`, `pip install`, `uv pip`

3. **Justfile rules**:
   - All Python execution uses `uv run`
   - Reference `just init`, `just run`

4. **Project structure rules**:
   - Where code belongs (src/, scripts/, etc.)
   - Input/output conventions
   - File organization patterns

5. **Error handling** (if applicable):
   - How to handle failures
   - Error reporting conventions

6. **Optimization guidelines** (if applicable):
   - When to skip processing
   - Performance considerations

Format:
- Use Markdown with clear headings
- Bullet lists for easy scanning
- Be explicit about forbidden patterns

==================================================
OUTPUT FORMAT
==================================================
Return in this order:

1. Brief summary (1-2 sentences)
2. Directory tree
3. Complete file contents:
   - pyproject.toml
   - justfile
   - README.md
   - AGENTS.md
   - src/main.py
   - Any other files

Use proper code blocks with language hints.
```

---

## What to Write in AGENTS.md

AGENTS.md is read by AI agents and AI-assisted development tools (such as Claude Code, Cursor IDE, GitHub Copilot, Windsurf, etc.) to understand project-specific rules. It should contain:

### Required Content

**1. General Coding Principles**
- Project-specific principles that override defaults
- Explicit value handling (never assume defaults)
- Domain-specific rules

**2. Git Commit Guidelines**
- Never include AI attribution in commit messages
- Keep commits professional and focused on changes
- No "Generated with" or "Co-Authored-By: [AI name]" messages

**3. Testing Rules**
- When to run tests (after every change)
- How to verify changes work
- Required test commands

**4. Python Execution Rules**
```markdown
- Python execution: **only** via `uv run ...`
- Virtual environment: **only** via `uv sync`
- Dependencies: manage through `uv` and `pyproject.toml`
- **FORBIDDEN**: `python`, `python3`, `pip install`, `uv pip`
```

**5. Justfile Rules**
- All Python execution uses `uv run`
- Reference key just recipes

**6. File Handling**
- How to read/write specific file types
- Libraries to use for each format
- File processing rules

**7. Project Structure**
- Where code belongs (src/, scripts/, prompts/)
- Input/output organization
- Forbidden locations

**8. Directory Organization Pattern**
- Input file organization logic
- Output file organization logic
- Subdirectory mirroring rules
- Error file handling

**9. Error Handling**
- How to handle failures gracefully
- Where to place failed outputs
- Success/failure reporting
- Exit code conventions

**10. Optimization**
- When to skip processing
- Performance considerations

### AGENTS.md Template

```markdown
# Development Rules for [Project Name]

This file provides guidance to AI agents and AI-assisted development tools when working with this project.

## General Coding Principles
- **Never assume any default values anywhere**
- Always be explicit about values, paths, and configurations
- If a value is not provided, handle it explicitly (raise error, use null, or prompt for input)

## Git Commit Guidelines
- **NEVER include AI attribution in commit messages**
- **NEVER add "Generated with [AI tool name]" or similar phrases**
- **NEVER add "Co-Authored-By: [AI name]" or similar attribution**
- **NEVER run `git add -A` or `git add .` - always stage files explicitly**
- Keep commit messages professional and focused on the changes made
- Commit messages should describe what changed and why, without mentioning AI assistance

## Testing
- After **every change** to the code, the tests must be executed
- Always verify the program runs correctly with `just run` after modifications

## Python Execution Rules
- Python code must be executed **only** via `uv run ...`
  - Example: `uv run src/main.py`
  - **Never** use: `python src/main.py` or `python3 src/main.py`
- The virtual environment must be created and updated **only** via `uv sync`
  - **Never** use: `pip install`, `python -m pip`, or `uv pip`
- All dependencies must be managed through `uv` and declared in `pyproject.toml`

## Justfile Rules
- All Python execution in the justfile uses `uv run`, never `python` directly
- Use `just init` to set up the project
- Use `just run` to execute the main program
- Use `just help` to see all available recipes with descriptions
- Use `just` (with no arguments) to see a list of all recipes

## File Handling
- **[File Type 1]**: Read using [Library] with [specific configuration]
- **[File Type 2]**: Read using [Library]
- **[File Type 3]**: Extract using CLI tools ([command])

## Project Structure
- All source code lives in `src/`
- Test scripts and utilities go in `scripts/`
- Prompt templates go in `prompts/`
- **Input data is organized by file type**: `data/input/[type]/`
- **Output data is organized by data type**: `data/output/[type]/`
- **Never create Python files in the project root directory**
  - Wrong: `./test.py`, `./helper.py`
  - Correct: `./src/helper.py`, `./scripts/test.py`

## Directory Organization Pattern
- **Input files are organized by source file type**:
  - `data/input/[type1]/` - Description
  - `data/input/[type2]/` - Description
- **Output files are organized by result data type**:
  - `data/output/[type1]/` - Description
  - `data/output/[type2]/` - Description
- **Subdirectories within input types are mirrored in output**:
  - Input: `data/input/[type]/2024/january/file.ext`
  - Output: `data/output/[type]/2024/january/file.ext`
- **Invalid or failed outputs go to type-specific error directories**:
  - Failed outputs: `data/output/[type]/error/`

## Error Handling
- Scripts should continue processing other files even if one fails
- Failed/invalid outputs must be moved to an `error/` subdirectory
- Scripts should track and report success/failure counts
- Exit with code 1 if any files failed, 0 if all succeeded

## Optimization
- **Skip processing if output already exists** - Don't reprocess files unnecessarily
- Check if output file exists before starting expensive operations
- Track skipped files separately in summary reports
- Allow users to force reprocessing by deleting output files
```

---

## What NOT to Put in AGENTS.md

- ❌ General Python best practices (AI agents already know these)
- ❌ How to use standard libraries
- ❌ Basic syntax rules
- ❌ User documentation (belongs in README.md)
- ❌ Setup instructions (belongs in README.md)

---

## Key Principles

1. **Never assume defaults** - Be explicit about all values, paths, and configurations
2. **Always use uv** - Never use python, python3, or pip directly
3. **Test after changes** - Verify functionality after every modification
4. **Organize by type** - Input by source type, output by result type
5. **Handle errors gracefully** - Continue processing, track failures, report clearly
6. **Skip unnecessary work** - Don't reprocess existing outputs
7. **Document for your audience** - AGENTS.md for AI agents, README.md for humans (must include directory tree with descriptions)

---

## After Project Creation

1. Run `just init` to initialize
2. Run `just run` to verify setup (should print "Hello World")
3. Customize AGENTS.md with project-specific rules
4. **Delete this INIT.md file**
5. Start developing following AGENTS.md rules
