# Jira ↔ SDD mapping

🇬🇧 English | [🇷🇺 Русский](./jira-sdd-mapping.ru.md)

How Jira issues, OpenSpec changes, branches and the company's SDD metric line
up. Getting this right is not bookkeeping: the metric is measured, and the
mapping is what makes it measurable without a parallel tracking system.

## The model

```
1 Epic  = N Stories                      a feature too big for one intent
1 Story = 1 master intent                ← the SDD label lives here
1 Task  = 1 repo = 1 derived change      ← one branch, one pull request
        = 1 handoff section
```

**Tasks slice the landing, never the intent.** A story's tasks are its
repository slices. The fix for a too-big story is an **Epic**, not more tasks.

## The metric: "story followed SDD"

A story counts when:

1. the story carries the label **`SDD`**, and
2. a **git branch is named after the story key** — satisfied either by the
   story itself, or by a task nested inside it, so a child task's branch counts

That is the company's definition. Satisfying it *mechanically* takes a little
more, and `scripts/check-sdd.sh` asserts all of it:

| Check | Why |
|---|---|
| the intent records `jira: PROJ-123` | links the intent to the labelled story |
| a repo change records `intent:` + `intent_store:` | links the code back to the intent |
| a repo change records `jira: PROJ-124` | links the code to the task |
| `openspec validate` passes | the spec is well-formed, not just present |
| branch matches the naming pattern | Jira can resolve the branch to the issue |
| **the intent merged before the first commit** | the spec led the code |

That last one is what separates *followed SDD* from *labelled SDD*, and it
**cannot be fixed after the fact**. If a branch was cut before the intent
merged, the honest answer is that this story did not follow SDD. Rewriting
history to make the check pass defeats the point of measuring it.

```bash
make check                              # everything in this checkout
JIRA_URL=... JIRA_TOKEN=... make check  # also assert the SDD label via Jira
```

Without `JIRA_URL`/`JIRA_TOKEN` the label checks are **skipped, not passed** —
the script says so rather than reporting a clean bill of health.

## Branch naming

```
<STORY-KEY>/<TASK-KEY>-<slug>      PROJ-123/PROJ-124-sso-token-endpoint
<STORY-KEY>-<slug>                 PROJ-123-sso-login      (single-repo story)
```

The first form resolves to the labelled **story** *and* the **task**, which is
what makes a child task's branch count toward the story. Use it whenever tasks
own the branches — which is the normal case, since most stories span more than
one repository.

## Sizing: story, task, or epic?

The question that decides it:

> Can `proposal.md` + `specs/` for this be reviewed and approved as a **single
> decision**, and does it describe **one** user-facing capability change?

| Answer | Unit |
|---|---|
| Yes | **one Story** = one master intent |
| Yes, but it lands in several repositories | still **one Story**; each repo is a **Task** |
| No — several independent capability changes | an **Epic** of several Stories |

**Repositories are not a reason to split a story.** One intent spanning backend
and frontend is normal and correct — that is exactly what `handoff.md` is for.
Splitting "users can sign in with SSO" into a backend story and a frontend
story loses the decision that was actually made, and gives you two specs to
keep in agreement.

Symptoms you should have used an Epic:

- the specs describe two capabilities that could ship independently
- reviewers keep approving one half and objecting to the other
- the rollout order has more than about three ordered stages
- `handoff.md` runs to five or more repository sections

Symptoms you split too far:

- a story's spec delta is a single scenario
- two stories' specs must be read together to make sense
- one story cannot be verified without the other being deployed

## Issue lifecycle and who moves the card

| Jira state | Means | Moved by |
|---|---|---|
| To Do | intent not written | — |
| In Analysis | intent being authored | analytics |
| In Review | intent up for approval | team lead |
| Ready for Dev | intent merged; branches may be cut | team lead, on merge |
| In Progress | at least one task in flight | developers |
| In Testing | deployed; scenarios being verified | tester |
| Done | all tasks done, intent archived | whoever archives |

These statuses are the columns of the two team boards — Stories run across the
Discovery board, Tasks across the Delivery board. See [boards](./boards.md).

The story cannot enter **Ready for Dev** before its intent is merged. That
transition *is* the ordering gate — enforcing it in Jira is what keeps the
metric honest, because it is the moment developers are allowed to start.

## Fields worth setting

| Field | Value | Why |
|---|---|---|
| Label | `SDD` | the metric reads it |
| Story: a custom `Intent ID` field | the kebab-case intent id | lets Jira link to the intent |
| Task: parent | the story | the branch resolves upward to the labelled story |
| Fix Version | `<service> <semver>` | ties the release back to the story |

If a custom field is not available, put the intent id in the story description
on its own line as `intent: <intent-id>` — `check-sdd.sh` does not read Jira for
this, but humans and reviewers do.

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| metric fails, everything looks right | no `jira:` in `.openspec.yaml` | add it |
| repo change invisible to the fan-out | no `intent:` key | add `intent:` and `intent_store:` |
| gate refuses although work is done | change not archived in its repo | `/opsx:archive` there |
| gate says "the checklist is lying" | a box was ticked by hand | untick it; use `intent-gate.sh --tick` |
| ordering check fails | branch cut before the intent merged | not fixable — report it honestly |
