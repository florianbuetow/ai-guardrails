# C++ 3D Game Base Template

Production-ready Copier template for C++ CLI applications with full validation infrastructure.

## Features

- **C++20/C++23** with CMake build system (Ninja generator)
- **Conan 2 dependency management** — full 3D-game library stack with exact version pins, one smoke test per library
- **Just task runner** for all commands
- **Pre-commit hooks** with CI checks
- **Comprehensive AGENTS.md** for AI-assisted development
- **Git worktree workflow** support

### Validation Tools

| Tool | Purpose | Why It's Used |
|------|---------|---------------|
| **clang-format** | Formatting | Industry-standard formatter, auto-fix, C++23 support |
| **clang-tidy** | Linting/static analysis | Massive check catalog (bugprone, modernize, cert, cppcoreguidelines). WarningsAsErrors |
| **cppcheck** | Deep static analysis | Finds bugs compilers miss: null derefs, memory leaks, UB. Low false positives |
| **flawfinder** | Security scanning | C/C++ vulnerability scanner (buffer overflows, format strings, race conditions) |
| **include-what-you-use** | Dependency hygiene | Detects unused and missing `#include` directives (advisory) |
| **semgrep** | Custom static analysis | Pattern-based rules banning unsafe patterns (raw new/delete, C casts, warning suppression) |
| **codespell** | Spell checking | Catches typos in code, comments, and documentation |
| **GoogleTest + lcov** | Testing and coverage | Unit testing with coverage thresholds |
| **ASan + UBSan** | Runtime sanitizers | Catches memory errors and undefined behavior at runtime |

## Template Structure

```
blueprints/cpp-3dgame-base/
├── copier.yml                          # Template configuration
├── README.md                           # This file
└── template/                           # Template files
    ├── .clang-format
    ├── .clang-tidy
    ├── .gitignore.template
    ├── .pre-commit-config.yaml.template
    ├── .semgrepignore.template
    ├── AGENTS.md.template
    ├── CLAUDE.md -> AGENTS.md          # Symlink (created via _tasks)
    ├── CMakeLists.txt.template
    ├── CMakePresets.json.template
    ├── conanfile.py.template           # Conan 2 dependency manifest (pinned)
    ├── justfile.template
    ├── README.md.template
    ├── src/
    │   ├── main.cpp.template
    │   └── app.cpp.template
    ├── include/
    │   └── {{project_name}}/
    │       └── app.hpp.template
    ├── tests/
    │   ├── app_test.cpp.template
    │   └── deps/                       # One smoke test per library (jinja-free)
    ├── scripts/
    ├── data/
    │   ├── input/
    │   └── output/
    └── config/
        ├── semgrep/
        │   ├── no-unsafe-patterns.yml
        │   ├── no-suppression.yml
        │   └── no-sneaky-fallbacks.yml
        └── codespell/
            └── ignore.txt
```

## Library Stack (Conan 2)

All third-party libraries are declared in `conanfile.py` with exact pins and
installed by `just init` (first run compiles from source for the local
LLVM/Clang toolchain). Each library has a headless-safe smoke test in
`tests/deps/`.

| Requested | Delivered as (pin) |
|-----------|--------------------|
| SDL3 | `sdl/3.4.8` |
| Vulkan SDK | `vulkan-headers/1.4.313.0` + `vulkan-loader/1.4.313.0` |
| MoltenVK | brew `molten-vk` (ConanCenter recipe requires apple-clang, incompatible with the LLVM/Clang policy) |
| volk | `volk/1.4.313.0` |
| vk-bootstrap | `vk-bootstrap/1.4.350` |
| Vulkan Memory Allocator | `vulkan-memory-allocator/3.3.0` |
| DXC or shaderc/glslang | `shaderc/2025.3` (bundles glslang) |
| SPIRV-Tools | `spirv-tools/1.4.313.0` |
| SPIRV-Cross | `spirv-cross/1.4.313.0` |
| GLM | `glm/1.0.3` |
| EnTT | `entt/3.16.0` |
| Jolt Physics | `joltphysics/5.2.0` |
| Recast/Detour | `recastnavigation/1.6.0` |
| GameNetworkingSockets | `gamenetworkingsockets/1.4.1` |
| bitsery | `bitsery/5.2.5` |
| Opus | `opus/1.6.1` |
| miniaudio | `miniaudio/0.11.22` |
| glTF 2.0 | format — covered by tinygltf |
| tinygltf | `tinygltf/2.9.7` |
| meshoptimizer | `meshoptimizer/1.0` |
| gltfpack | prebuilt CLI installed by `just init` into `~/.local/bin` (GitHub release v1.0, pinned to the meshoptimizer library version; mac/linux/windows) |
| KTX2 / Basis Universal | `ktx/4.4.2` (tools disabled) |
| ozz-animation | `ozz-animation/0.14.1` |
| MikkTSpace | `mikktspace/cci.20200325` |
| Dear ImGui | `imgui/1.90.5-docking` |
| ImGuizmo | `imguizmo/cci.20231114` |
| RmlUi | `rmlui/6.2` |
| spdlog | `spdlog/1.17.0` |
| fmt | `fmt/12.1.0` |
| Tracy | `tracy/0.13.1` (on_demand) |
| GoogleTest | `gtest/1.17.0` (test_requires) |
| SQLite | `sqlite3/3.53.3` |
| PostgreSQL/libpqxx | `libpqxx/8.0.1` |
| zstd | `zstd/1.5.7` |
| xxHash | `xxhash/0.8.3` |

Version-alignment notes: the Vulkan/SPIR-V stack is pinned to the 1.4.313 SDK
line (shaderc 2025.3 and ConanCenter's MoltenVK-free graph resolve there);
imgui stays on 1.90.5-docking because ImGuizmo cci.20231114 uses APIs removed
in imgui 1.92.

## Usage

### Via just create

```bash
cd /path/to/ai-guardrails
just create cpp-3dgame-base my-project
```

### Direct Copier usage

```bash
copier copy blueprints/cpp-3dgame-base my-project
cd my-project
just init
just run
```

## Template Questions

The template will ask:

- **project_name**: Project name (e.g., my-cli-tool)
- **project_description**: Short description
- **cpp_standard**: C++ standard version (20 or 23)
- **author_name**: Author name
- **author_email**: Author email
- **coverage_threshold**: Code coverage threshold (0-100, default 80)

## Generated Project Features

Projects created from this template include:

- **CMake build system**: Modern CMake with presets (debug, release, coverage, sanitize)
- **Complete validation suite**: clang-format, clang-tidy, cppcheck, flawfinder, IWYU, Infer, semgrep, codespell
- **Runtime sanitizers**: AddressSanitizer and UndefinedBehaviorSanitizer
- **Just recipes**: init, run, destroy, code-*, test, test-coverage, ci, ci-quiet
- **Pre-commit hooks**: Runs `just ci-quiet` on commit
- **AI agent rules**: AGENTS.md with strict development guidelines
- **Git commit rules**: No AI attribution, explicit file staging
- **Semgrep rules**: Ban raw new/delete, C-style casts, goto, malloc/free, warning suppression
- **Directory structure**: src/, include/, tests/, scripts/, data/

The generated `just code-style` recipe runs `clang-tidy` with `--quiet` so
passing CI logs focus on project-owned diagnostics. Remove `--quiet` from that
recipe when investigating non-user, system, or dependency warning context.

## Semgrep Rules

| Rule | Purpose |
|------|---------|
| `no-unsafe-patterns` | Bans raw `new`/`delete`, `reinterpret_cast`, C-style casts, `goto`, `malloc`/`free`, `using namespace` in headers |
| `no-suppression` | Bans `NOLINT`, `NOLINTNEXTLINE`, `#pragma` diagnostic suppression -- fix issues instead of suppressing |
| `no-sneaky-fallbacks` | Bans empty `catch` blocks and `catch(...)` without rethrow -- handle exceptions explicitly |

## Requirements

- **cmake 3.25+** - Build system
- **ninja** - CMake generator (`brew install ninja`)
- **conan 2.x** - Dependency manager (`brew install conan`)
- **C++ compiler** - LLVM/Clang (`brew install llvm`; AppleClang is rejected)
- **MoltenVK** - macOS Vulkan driver (`brew install molten-vk`, macOS only)
- **clang-format** - Code formatter (`brew install clang-format`)
- **clang-tidy** - Static analysis (`brew install llvm`)
- **cppcheck** - Deep static analysis (`brew install cppcheck`)
- **flawfinder** - Security scanner (`brew install flawfinder`)
- **codespell** - Spell checker (`brew install codespell`)
- **semgrep** - Pattern-based analysis (`brew install semgrep`)
- **lcov** - Coverage reporting (`brew install lcov`)
- **just** - Command runner
- **copier** - Template engine
- **git** - Version control

Optional:
- **include-what-you-use** - Include hygiene (advisory, does not fail CI)

## Testing the Template

To verify the template generates correctly:

```bash
cd /path/to/ai-guardrails
just test-cpp-3dgame
```

This will:
1. Generate a test project in a temp directory
2. Verify all expected files are created
3. Verify CLAUDE.md symlink is correct
4. Run `just init`, `just run`, `just ci`, `just ci-quiet`, and `just destroy`
5. Clean up temp directory

## Updating Generated Projects

Projects can be updated when the template changes:

```bash
cd my-project/main
copier update
```

## Development

To modify this template:

1. Edit files in `template/` directory
2. Test with: `just test-cpp-3dgame` (from repository root)
3. Verify generated project works
4. Commit changes

## Sources

Based on:
- [C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)
- ai-guardrails/blueprints/python-cli-base
