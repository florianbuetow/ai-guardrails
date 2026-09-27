# Architecture

This file maps the code of this project for anyone about to change it: where things
live, how the parts depend on each other, and which rules must never be broken. It
describes the project's code only; the documentation layout is described in
`AGENTS.md`.

Keep it short and stable. Update it when a module, layer, boundary, or invariant
changes, not on every commit. Name files, modules, and types instead of linking to
them, so readers search for the names and the map survives refactors.

## Bird's-eye view

<!-- What problem the project solves, and how a request, command, or job flows
through the system, in a few paragraphs. -->

## Codemap

<!-- One entry per important directory or module: what it owns, what it must not
do, and the names of its key types or entry points. -->

## Layers and boundaries

<!-- The allowed dependency directions between layers, for example
types -> config -> repository -> service -> runtime -> interface; where
cross-cutting concerns such as authentication, telemetry, and feature flags enter;
and which test or linter enforces each boundary. -->

## Invariants

<!-- Rules that must always hold, especially things that must never happen, such as
"the domain layer never imports the command-line layer". Name the check that
enforces each one. -->

## Cross-cutting concerns

<!-- How errors, logging, configuration, and testing work across all modules. -->
