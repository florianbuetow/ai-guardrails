# How This Knowledge Base Works

This layout comes from OpenAI's article "Harness engineering: leveraging Codex in an
agent-first world" (https://openai.com/index/harness-engineering/). The article
describes a team that shipped a product whose code was written entirely by coding
agents, and how it organized the repository's knowledge so those agents could work
reliably. This file explains that organization: what each part is for, and how to use
it.

## Principles

- **The repository is the system of record.** An agent can use only what it can read
  while it works. Decisions that live in chat threads, external documents, or people's
  heads do not exist for it until someone writes them down here, versioned with the
  code.
- **A map, not a manual.** `AGENTS.md` stays short and works as a table of contents
  that points into `docs/`. One giant instruction file fails: it crowds the task out of
  the agent's context, makes every rule look equally important, goes stale without
  anyone noticing, and cannot be checked mechanically.
- **Progressive disclosure.** An agent starts from the small, stable map and is shown
  where to look next, instead of being handed everything at once.
- **Checked, not hoped for.** Continuous integration verifies that the knowledge base is
  current, cross-linked, and correctly structured, and a recurring doc-gardening pass
  finds documents that no longer match the code and fixes them.
- **Taste becomes documentation or tooling.** Lessons from reviews, refactors, and bugs
  are written down here. When a written rule is not enough, it becomes a linter or a
  test.
- **Debt is paid continuously.** Known debt is tracked next to the plans and paid down in
  small, frequent changes, like garbage collection, instead of in painful bursts.

## Layout

    AGENTS.md                       Short map loaded into every agent's context
    ARCHITECTURE.md                 Top-level map of the code's domains and layering
    docs/
    ├── README.md                   This file
    ├── design-docs/
    │   ├── index.md                Catalog of design docs with verification status
    │   └── core-beliefs.md         Agent-first operating principles
    ├── exec-plans/
    │   ├── active/                 Execution plans in progress
    │   ├── completed/              Finished execution plans
    │   └── tech-debt-tracker.md    Known technical debt
    ├── generated/                  Documents generated from the code
    ├── product-specs/
    │   └── index.md                Catalog of product specs
    ├── references/                 External reference material, such as llms.txt files
    ├── DESIGN.md                   Design guidance for the product
    ├── FRONTEND.md                 Frontend conventions
    ├── PLANS.md                    How to write and maintain execution plans
    ├── PRODUCT_SENSE.md            Product principles and taste
    ├── QUALITY_SCORE.md            Quality grade per product domain and layer
    ├── RELIABILITY.md              Reliability requirements
    └── SECURITY.md                 Security rules

## What each part is for

- **`AGENTS.md`** is the entry point. Its Documentation section lists every document
  here with when to read and update it.
- **`ARCHITECTURE.md`** maps the project's code: its domains, how packages are layered,
  and which dependency directions are allowed. It does not describe this documentation.
- **`design-docs/`** holds design documentation, catalogued in `index.md` with each
  document's verification status so readers can tell current decisions from history.
  `core-beliefs.md` defines the agent-first operating principles behind every decision.
- **`exec-plans/`** treats plans as first-class artifacts. A small change needs only a
  lightweight plan in the task or pull request; complex work gets an execution plan
  with progress and decision logs. Plans in progress live in `active/`, finished plans
  move to `completed/`, and known debt is recorded in `tech-debt-tracker.md`. Keeping
  all three versioned next to the code lets an agent continue work without outside
  context.
- **`generated/`** holds documents that tools produce from the code, such as a database
  schema in `db-schema.md`, so agents read exact facts instead of reconstructing them.
- **`product-specs/`** holds product specifications, such as `new-user-onboarding.md`,
  catalogued in `index.md`. Specs turn user feedback into acceptance criteria.
- **`references/`** stores external reference material in the repository, such as the
  `llms.txt` files that tools publish for language models (`uv-llms.txt`) or a design
  system reference, so agents do not depend on outside sources.
- **`DESIGN.md`, `FRONTEND.md`, `PRODUCT_SENSE.md`, `RELIABILITY.md`, and `SECURITY.md`**
  record the team's standing guidance on design, frontend engineering, product
  judgment, reliability, and security: what you would teach a new teammate during
  onboarding. Reliability requirements are measurable, for example "service startup
  completes in under 800 ms".
- **`PLANS.md`** explains when an execution plan is needed and how to write one.
- **`QUALITY_SCORE.md`** grades each product domain and architectural layer and tracks
  the gaps over time, so cleanup goes where it matters most.

## How to use it

1. Start from the Documentation section in `AGENTS.md`, and open only the documents
   your task needs.
2. For complex work, write an execution plan in `exec-plans/active/` as `PLANS.md`
   describes, keep it current while you work, and move it to `exec-plans/completed/`
   when you finish.
3. Change documents in the same commit as the code they describe. A document that
   disagrees with the code is a bug.
4. List every new design doc, product spec, generated document, and reference in its
   folder's `index.md`.
5. Regenerate generated documents from their source; never edit them by hand.
6. Record debt you do not fix in `exec-plans/tech-debt-tracker.md`, and update
   `QUALITY_SCORE.md` when a review or cleanup changes a grade.
7. Keep the knowledge base checkable: add checks to the project's continuous
   integration that every document is listed in its index and that relative links
   resolve, and run a doc-gardening pass regularly.
