# Application Guide

@Metadata {
    @TechnologyRoot
}

Build and validate a native macOS application from the terminal.

## Overview

### Development

Run `just init` to install the complete pinned toolchain, `just ci` to validate
the project, and `just run` to open the application. SwiftUI owns presentation;
application services coordinate domain behavior and infrastructure interfaces.

### Validation

The template combines compiler checks, custom policies, security scanning, native
UI testing, accessibility audits, snapshot tests, coverage and runtime sanitizers.
Each command fails on missing prerequisites. Use the generated README for the
complete command reference and release credential requirements.
