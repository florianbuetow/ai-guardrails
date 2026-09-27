# Core Beliefs

These principles describe how humans and agents work in this repository. They apply to
every task and settle questions that other documents leave open.

1. **The repository is the system of record.** Agents see only what is in the
   repository. Write decisions, specs, plans, and lessons down here, not in chats or
   meetings.
2. **Humans steer; agents execute.** Humans set priorities, acceptance criteria, and
   taste. Agents do the work and keep the documentation true.
3. **A struggling agent signals a missing capability.** Add the missing tool,
   guardrail, or document instead of retrying harder.
4. **Entry points are maps, not manuals.** `AGENTS.md` maps the documentation and
   points to deeper documents, so an agent's context holds only what its task needs.
5. **Invariants are enforced mechanically.** A rule that matters belongs in a test,
   linter, or CI check whose error message explains the fix. When documentation is not
   enough, move the rule into code.
6. **Data is parsed at the boundary.** External input is validated once, where it
   enters, into precise types. Code never builds on guessed data shapes.
7. **Boring technology wins.** Prefer stable, composable, well-understood
   dependencies, and shared utilities over one-off helpers.
8. **Errors fail fast.** No silent fallbacks, no default values that hide missing
   input, and no suppressed checks.
9. **Plans are artifacts.** Complex work gets an execution plan in the repository, as
   [PLANS.md](../PLANS.md) describes.
10. **Debt is paid continuously.** Record debt in the
    [tech debt tracker](../exec-plans/tech-debt-tracker.md) and pay it down in small,
    frequent changes.
