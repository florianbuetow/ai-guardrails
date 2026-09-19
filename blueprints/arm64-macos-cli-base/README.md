# ARM64 macOS Assembly CLI Base Template

A Copier template for command-line tools written entirely in hand-written ARM64 assembly for Apple Silicon macOS.

The generated project contains no C, C++ or any other compiled language. Clang acts only as assembler and linker driver over `.S` sources, and the binary links `libSystem` through the standard dynamic linker — it issues no raw syscalls. The build target is fixed at `arm64-apple-macos11` with generic `arm64` tuning.

Because assembly has no semantic source analyser, the guardrails are layered differently from the other blueprints: constrained source discipline through ABI macros, Semgrep generic textual policy, Clang integrated-assembler validation, object-file import layering, Mach-O and signature validation, FileCheck assertions over real disassembly, and runtime tests.

## Generate a project

```bash
copier copy --trust blueprints/arm64-macos-cli-base ./my-cli
cd ./my-cli
just init
just test
```

Run `just run -- sum -` to pipe integers through the CLI, and `just help` to see every recipe.

## Prerequisites

- Xcode Command Line Tools — `clang`, `otool`, `nm`, `lipo`, `codesign`, `lldb`
- Homebrew LLVM (`brew install llvm`) — `FileCheck`, `llvm-objdump`, `llvm-readobj`, `llvm-mca`
- `just`, `semgrep`, `codespell`, `shellcheck`, `shfmt`

ArmLS and `xctrace` are useful for development but are deliberately not CI gates.
