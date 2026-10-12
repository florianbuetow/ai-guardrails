# Raspberry Pi C++ Base Template

A minimal C++20 Hello World application for Raspberry Pi OS 64-bit (Debian Trixie),
with native ARM64 Linux validation and a command-line Docker workflow for Apple
Silicon Macs. No Docker Desktop application is required: any compatible ARM64
Linux Docker daemon, including Colima, works.

```sh
just create raspberry-pi-cpp-base my-pi-project
cd my-pi-project
just container-init
just container-ci
just container-run
just container-artifact
```

On a Raspberry Pi with the required tools installed, use `just init`, `just ci`,
and `just run`. The generated README explains toolchain provisioning and every
validation layer. The application prints exactly `Hello, world!` and exits zero.
It contains no SIMD demonstration, hardware access, parser, or benchmark.

The template includes GCC and Clang debug/release builds, GoogleTest unit and
header tests, CLI and installed-artifact tests, ASan/UBSan, LLVM line/function/
branch coverage, compiler-resolved dependency boundaries, source/test inventory
checks, clang-format, clang-tidy, cppcheck, Flawfinder, Semgrep, Gitleaks,
ShellCheck, shfmt, codespell, and ELF hardening checks. Valgrind is an explicit
additional command. Required CI never formats files, ignores failures, or skips
missing tools. Every policy has a corresponding repository violation fixture
where applicable.

The baseline architecture is ARMv8-A, which includes NEON. A CMake compile probe
verifies intrinsic support without adding NEON instructions to Hello World.
Real Raspberry Pi testing remains necessary for peripherals and performance.
Mutation testing, fuzzing, and benchmarks are deliberately deferred until the
application has meaningful targets. Infer is not required on Linux ARM64;
CodeQL and Mull are not installed speculatively.

Run `just test-raspberry-pi-cpp-base` in this repository for the generated-project
baseline and violation suite. Docker must be running and must be able to bind
mount the test directory. Set `TMPDIR` to a shared directory when using Colima.
