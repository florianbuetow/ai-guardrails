---
name: doc-gardening
description: Check that the repository's knowledge base (AGENTS.md, ARCHITECTURE.md, and docs/) still matches the code, and fix documentation that drifted. Use when asked to garden, audit, or check the documentation, after finishing an execution plan or a larger change, or when documents may be stale.
---

# Doc Gardening

Keep the knowledge base true to the code. The Documentation section of `AGENTS.md` maps
it, and `docs/README.md` explains how it works. Work through the four checks below in
order. Change documentation only: record code that breaks a rule as debt instead of
changing the code in this run.

## 1. Structure

- `AGENTS.md` is a regular file, not a symlink, and there is no `CLAUDE.md` anywhere in
  the repository.
- The Documentation section of `AGENTS.md` lists every document in `docs/`, and every
  path it lists exists.
- Every file in `docs/design-docs/`, `docs/product-specs/`, `docs/generated/`, and
  `docs/references/` is listed in that folder's `index.md`, and every listed file exists.
- Every relative link in `AGENTS.md`, `ARCHITECTURE.md`, and `docs/` resolves.

Fix what is missing or wrong: add index rows and map entries, remove entries for deleted
files, and repair links.

## 2. Freshness

- Every module, directory, type, and invariant that `ARCHITECTURE.md` names still exists
  and still holds.
- Compare each design doc marked Accepted or Verified with the code. If it matches, set
  its Verified date in `docs/design-docs/index.md` to today. If the code has moved on,
  update the doc, or mark it Superseded and name its replacement.
- Each product spec marked Shipped still describes how the product behaves.
- Each generated document matches a fresh run of the command listed for it in
  `docs/generated/index.md`; regenerate any that differ.
- Each reference in `docs/references/index.md` matches the version of the dependency the
  project uses; list the ones that do not.
- Plans in `docs/exec-plans/active/` whose work is finished get their Outcomes &
  Retrospective written and move to `docs/exec-plans/completed/`. Report active plans
  whose latest Progress entry is more than two weeks old.

## 3. Drift from the core beliefs

- Read `docs/design-docs/core-beliefs.md` and the invariants in `ARCHITECTURE.md`, then
  look for code that breaks them.
- Add each violation to `docs/exec-plans/tech-debt-tracker.md`, naming the file and the
  rule it breaks.
- Update the affected grades and their Last reviewed dates in `docs/QUALITY_SCORE.md`.

## 4. Missing capabilities

- Read the Surprises & Discoveries and Decision Log sections of the plans in
  `docs/exec-plans/`, and the tech debt tracker.
- Look for problems that recur or that had to be worked around. Each one points to a
  missing tool, guardrail, test, or document.
- Propose each one as a concrete addition, saying what to add and where. Do not add it in
  this run.

## Report

Make each fix a small change with one concern. Finish with a report that lists, with file
paths, the documentation you fixed, the debt you recorded, the grades you changed, and
the capabilities you propose.
