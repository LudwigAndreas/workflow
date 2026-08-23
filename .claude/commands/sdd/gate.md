---
name: "SDD: Gate"
description: "Check metric readiness and report which pipeline gate this change is at"
allowed-tools: Bash(openspec:*), Bash(git:*), Bash(./scripts/check-sdd.sh:*), Bash(make:*)
category: "SDD"
tags: ["sdd", "jira", "metric"]
---

Report where a change stands in the pipeline and whether it will pass the
"story followed SDD" metric. Run it before opening a PR.

**Input**: `/sdd:gate [<change-id>]` — with no argument, check everything
in flight.

## Steps

### 1. Run the mechanical check

```bash
./scripts/check-sdd.sh [--change "<change-id>"] [--store specifications]
```

This asserts: the `jira:` link exists, `openspec validate` passes, every
`tasks.md` section carries a Jira key, the branch matches the naming pattern,
and the proposal was merged before the branch was cut. With `JIRA_URL` and
`JIRA_TOKEN` exported it also asserts the `SDD` label and issue type.

### 2. Locate the change in the pipeline

```bash
openspec status --change "<change-id>" [--store specifications] --json
git rev-parse --abbrev-ref HEAD
```

Map artifact state onto the gate:

| State | Gate | Next actor |
|---|---|---|
| no `proposal.md` | 1 — intake | team lead sizes and labels the story |
| `proposal` + `specs` exist, not merged | 2–4 — review | tester reviews scenarios, then tech lead approves |
| merged, no `tasks.md` | 5 — plan | developer runs `/sdd:plan` |
| `tasks.md` exists, tasks unchecked | 6 — apply | developer runs `/opsx:apply` |
| all tasks checked, not archived | 7 — verify | tester exercises every scenario |
| verified | 8 — archive | `/opsx:archive` once **all** consuming repos ship |

`isComplete: false` between gates 4 and 5 is expected, not an error.

### 3. Report

- **PASS / FAIL** on the metric, and for each failure the concrete fix:

  | Failure | Fix |
  |---|---|
  | no `jira:` key | add `jira: PROJ-123` to `.openspec.yaml` |
  | section missing Jira key | `## 2. Backend` → `## 2. Backend (PROJ-125)` |
  | branch pattern | rename to `PROJ-123/PROJ-125-<slug>` |
  | proposal not merged before branch | **not fixable after the fact** — the spec landed after the code; say so plainly rather than suggesting a workaround |

- the current gate and who acts next
- if tasks are in flight, the per-section completion counts, so Jira and
  OpenSpec can be reconciled

## Guardrails

- **Report the ordering failure honestly.** Rewriting history to make the
  metric pass defeats its purpose — never suggest it.
- **Don't mark tasks complete** to make status look better. This command reads;
  it doesn't write.
