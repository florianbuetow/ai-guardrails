# Design Docs

Design docs record how a part of the system works and why it was built that way. This
catalog lists every design doc with its status, so readers can tell current decisions
from history.

## Status

- **Draft**: proposed, not yet agreed.
- **Accepted**: agreed; the implementation may still be in progress.
- **Verified**: checked against the current code on the date in the Verified column.
- **Superseded**: replaced; the summary names the replacement.

## Catalog

| Document | Status | Verified | Summary |
|----------|--------|----------|---------|
| [core-beliefs.md](core-beliefs.md) | Accepted | | Agent-first operating principles for this repository |

## Adding a design doc

Create `design-docs/<topic>.md` covering the context, the decision, the alternatives
considered, and the consequences. Add its row to the catalog in the same commit. When
code changes make a design doc wrong, update it or mark it Superseded.
