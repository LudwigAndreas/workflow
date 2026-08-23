# Team lead

🇬🇧 English | [🇷🇺 Русский](./team-lead.ru.md)

You own the boundary between "someone wants something" and "there is a
correctly-shaped story". Nobody downstream can fix a badly-sized story, so this
gate matters more than it looks.

Read [the pipeline](../pipeline.md) once first. You own **gate 1**, and you are
accountable for the **"story followed SDD"** metric across the board.

## What you own

- Applying the sizing rule at triage — Story vs. Epic vs. Story-with-Tasks.
- The `SDD` label and the `change-id` on every story.
- Creating the per-repo Tasks for a cross-repo story.
- Sprint scope and priority.
- The metric: knowing which stories pass and why the failures fail.

You do **not** write `proposal.md`, `specs/*.md`, `design.md` or `tasks.md`.

## Triage: the only decision you make

For each incoming intent, ask one question:

> **Can `proposal.md` + `specs/*.md` for this be reviewed and approved as a
> single decision?**

| Answer | What you create |
|---|---|
| Yes, and it touches one repo | **Story**, no children. It owns the branch. |
| Yes, but it touches several repos | **Story** + one **Task** per affected repo. Tasks own the branches. |
| No — several independent capability changes | **Epic**, split into Stories, each sized by re-running this test. |

The third row is the one people get wrong. When a story feels too big to
follow, the instinct is to add more tasks under it. **Don't.** Tasks are repo
slices, never work slices. If you are writing "Task 4: second half of the
backend work", you needed an Epic. Adding tasks to an oversized story is
exactly what makes it untrackable, because task count stops meaning anything.

A correctly-sized story always satisfies: **number of tasks == number of
affected repos** (plus at most one QA task).

## Creating a story

1. Capture the intent in the story description in plain language. This is the
   input to `/sdd:intake` — write it for a person, not for a parser.
2. Apply the sizing rule above.
3. Add the label **`SDD`**.
4. Reserve a `change-id` — kebab-case, matching what the change directory will
   be called (`add-sso-login`, `fix-session-expiry`). Record it on the story.
5. For a cross-repo story, create one Task per affected repo, named for the
   repo: `common`, `backend`, `frontend`, `gitops_backend`, `qa`.

Since frontend, backend and QA share one board, all of a story's tasks land in
the same sprint. That makes the contract gate a within-sprint ordering problem:
sequence the `common` task first, and don't let the FE/BE tasks start until it
has published.

## Sprint mechanics

- **A story is sprint-ready only after gate 4** — its spec delta is merged.
  Pulling an unapproved story into a sprint is how spec-after-code happens, and
  it fails the metric.
- **Plan the proposal work too.** Gates 2–4 (analytics writing the proposal,
  tester reviewing scenarios, tech lead approving) are real work with real
  duration. If they are invisible on the board, they will be skipped under
  pressure. Either carry them as their own story or budget them explicitly.
- **Sequence the contract task first** whenever `common` or a shared contract
  is involved.

## Watching the metric

```bash
make check                             # full metric check over in-flight changes
openspec list --json                   # local changes and progress
openspec list --store specifications   # shared cross-repo changes
```

With `JIRA_URL` and `JIRA_TOKEN` exported, `make check` also asserts the `SDD`
label and issue type directly against Jira. Without them it checks everything
that lives in git, which is most of it.

The common failure modes, in the order you will actually hit them:

| Symptom | Cause | Fix |
|---|---|---|
| `no jira: key` | change created without a story key | add `jira: PROJ-123` to `.openspec.yaml` |
| `section missing Jira key` | `tasks.md` heading is `## 2. Backend` | make it `## 2. Backend (PROJ-125)` |
| `branch does not match pattern` | branch named `feature/sso` | rename to `PROJ-123/PROJ-125-backend-sso` |
| `proposal not merged before branch` | code started before approval | genuine process miss — the story cannot pass this sprint |

The last one is not fixable after the fact, by design. That is the point of the
metric.

## What you must not do

- **Don't split a story into tasks to make it feel smaller.** Split it into an
  Epic of stories. Tasks are repo slices.
- **Don't let a story into a sprint before its spec delta is merged.**
- **Don't add the `SDD` label to make a number go up.** A labelled story with
  no change-id fails the check anyway, and now it fails loudly.
- **Don't write specs yourself.** Sizing is your gate; content is analytics'.
