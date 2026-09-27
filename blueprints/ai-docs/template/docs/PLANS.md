# Plans

How work is planned in this repository. Execution plans are checked in, so any agent can
pick up complex work from the repository alone.

## Choosing a plan

- **Small changes**, done in one sitting with an obvious approach, need only a short
  plan in the task or pull request description.
- **Complex work**, spanning several steps or sessions, involving design decisions, or
  carrying risk, gets an execution plan in [exec-plans/active/](exec-plans/active/).

## Lifecycle of an execution plan

1. Before writing code, create `exec-plans/active/YYYY-MM-DD-<short-slug>.md` from the
   skeleton below.
2. Keep the plan current while working: update Progress at every stopping point, and
   record decisions and surprises when they happen.
3. When the work is done, write Outcomes & Retrospective and move the file to
   [exec-plans/completed/](exec-plans/completed/) in the same commit as the final
   change.
4. Record debt you discover but do not fix in the
   [tech debt tracker](exec-plans/tech-debt-tracker.md).

## Writing rules

- **Self-contained.** Someone with only the plan and the repository must be able to
  finish the work. Name files by their full path, define every term, and do not depend
  on links, chats, or earlier sessions.
- **Living.** The plan always reflects the current state. Split a partly finished step
  instead of leaving it ambiguous, and record why whenever you change course.
- **Outcome-focused.** Describe what a user can do afterwards and how to observe it, not
  only which code changes.
- **Concrete.** Give exact commands, the directory to run them in, and the output to
  expect.
- **Safe to resume.** Say which steps can be repeated safely and how to recover from a
  failed step.
- **Prose first.** Explain in sentences; use lists only where they are clearer.

## Skeleton

    # <Short, action-oriented title>

    ## Purpose / Big Picture
    What someone can do after this change that they cannot do now, and how to see it
    working.

    ## Progress
    - [x] (YYYY-MM-DD HH:MMZ) A finished step.
    - [ ] A remaining step.

    ## Surprises & Discoveries
    Unexpected behavior, bugs, or insights found while working, with brief evidence.

    ## Decision Log
    - Decision: what was decided. Rationale: why. Date: YYYY-MM-DD.

    ## Outcomes & Retrospective
    What was achieved, what remains, and lessons learned. Written at milestones and at
    completion.

    ## Context and Orientation
    The current state of the relevant code for a reader who knows nothing about it:
    key files by full path, and the terms they need.

    ## Plan of Work
    The sequence of changes in prose: which files change, and how.

    ## Concrete Steps
    Exact commands with their working directory and expected output.

    ## Validation and Acceptance
    How to exercise the change, and the observable behavior that proves it works.

    ## Idempotence and Recovery
    Which steps are safe to repeat, and how to roll back or retry after a failure.

    ## Artifacts and Notes
    Short transcripts, diffs, or snippets that support the plan.

    ## Interfaces and Dependencies
    The modules, types, function signatures, and libraries the change adds or relies
    on, named by full path.
