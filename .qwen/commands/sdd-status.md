---
description: "Where every master intent has got to, and what the SDD metric says"
---

Report where work stands across the shared store and every application
repository, and whether it satisfies the "story followed SDD" metric.

**Input**: `/sdd-status [<intent-id>]`. With no argument, report everything in
flight.

## Steps

### 1. Read the real state

```bash
./scripts/intent-status.sh [<intent-id>]
```

This reads the repositories themselves rather than trusting the intent's
Fan-out checkboxes, so it is the honest answer. It flags three specific lies:

- a repository whose work is archived but whose box is not ticked
- a box ticked while the repository's change is still open
- a box ticked with no derived change existing at all

### 2. Check the metric

```bash
./scripts/check-sdd.sh --all
```

With `JIRA_URL` and `JIRA_TOKEN` exported it also asserts the `SDD` label and
issue type against Jira. Without them those checks are **skipped, not passed** —
say which happened rather than reporting a clean bill of health.

### 3. Locate each intent in the lifecycle

| State | Phase | Who acts next |
|---|---|---|
| no `intent.md` | exploring | analytics — `/opsx-explore` |
| `intent.md` incomplete, or no `specs/` | authoring | analytics — `/sdd-intent` |
| complete, not merged | review | team lead — `/sdd-review` |
| merged, no derived changes | fan-out | testers and developers start, in parallel (`/opsx-propose` in each repo) |
| some repositories archived | building | the repositories still open |
| all archived, intent open | ready to archive | `make gate INTENT=<id>`, then `openspec archive <id> --store specifications` |

`isComplete: false` on an intent between merge and full fan-out is expected and
is not an error — it means implementation is under way in the repositories.

### 4. Report

- per intent: its Jira story, how many repositories are done out of how many,
  and which specific ones are outstanding
- any inconsistency between the checkboxes and reality, quoted exactly
- metric pass or fail, and for each failure the concrete fix:

  | Failure | Fix |
  |---|---|
  | no `jira:` key | add `jira: PROJ-123` to `.openspec.yaml` |
  | no `intent:` key on a repo change | add `intent: <intent-id>` and `intent_store: specifications` |
  | branch pattern | rename to `PROJ-123/PROJ-124-<slug>` |
  | intent not merged before the branch | **not fixable after the fact** — say so plainly |

## Guardrails

- **Report the ordering failure honestly.** When the spec landed after the
  code, the story did not follow SDD. Rewriting history to make the metric pass
  defeats the point of measuring it — never suggest it.
- **Do not tick checkboxes to tidy the report.** This command reads; it does
  not write. `scripts/intent-gate.sh --tick` is the only thing that ticks, and
  only what it has verified.
