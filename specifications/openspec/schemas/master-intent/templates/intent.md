<!-- The master intent: the business source of truth for one Jira story, and
     the prepared context a developer feeds into the STANDARD OpenSpec workflow
     in their own repository.

     This is NOT a proposal and NOT the first half of one. The developer writes
     proposal.md, specs/, design.md and tasks.md themselves, in their own repo,
     from this document. Write the business meaning and the whole-system
     context; never the solution. -->

# <!-- one line: the capability change, in business language -->

## Business need

<!-- Why this is worth doing, whose problem it solves, what happens if it is
     not done. One or two paragraphs, in the language of the business rather
     than of the system. -->

## Today

<!-- How this capability behaves for the business now, cited. Name the existing
     business rule where one applies (openspec/specs/<capability>), or a real
     path as src/<repo>/<path>. "No existing business rule covers this" is a
     finding, not a gap. -->

## What must be true afterwards

<!-- The business outcome, observable to a user or another organisation. Not
     the mechanism. If a sentence could only be written by someone who knows
     the codebase, it does not belong here. -->

## System context

<!-- The whole-system facts a developer in ONE repository could not work out
     alone. This is the reason this store exists. Cover what applies:

       External API contracts   what this system exposes to or consumes from
                                the outside world, including shapes an external
                                party has already fixed. Attach or link the
                                contract document itself where one exists.
       User interface needed    what a user must be able to see and do.
       Data                     what must be captured, retained or removed.
       Events / integrations    what other parties depend on.

     Context, not design: state what the outside world requires, never how this
     system should be built to meet it. -->

## Repositories

<!-- Rows for repositories that will do work, and rows for those considered and
     ruled out. Do NOT specify what any repository should build - their own
     `propose` decides that. -->

| Repo | Jira task | What it contributes |
|---|---|---|
| `<repo>` | `PROJ-124` | <one line, in business terms> |

## Constraints

<!-- What limits the solution space and is not negotiable by this intent -
     compliance, data retention, backward compatibility with released clients,
     a partner's timetable, performance commitments. Cite the source of each. -->

## Open questions

<!-- Each with an owner and what it blocks. Never invent an answer to close
     one. -->

| Question | Owner | Blocks |
|---|---|---|

## Fan-out

<!-- One checkbox per repository above. Leave every one unticked: a box is
     ticked only once that repository has archived its own change, and
     scripts/intent-gate.sh verifies each against the repositories themselves
     before this intent may be archived. -->

- [ ] `<repo>` (`PROJ-124`) - change archived
