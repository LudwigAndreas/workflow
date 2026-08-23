# Analytics / architecture

🇬🇧 English | [🇷🇺 Русский](./analytics.ru.md)

You turn a story's intent into an agreed, reviewable statement of behavior. You
work in **Mode A** — this `workflow` repo, every application repo checked out as
a submodule side by side — so a change spanning several repos can be scoped with
full context. You **never** touch `src/*` code.

Read [the pipeline](../pipeline.md) and [Jira ↔ SDD mapping](../jira-sdd-mapping.md)
once first. You own **gate 2**, and usually drive **gate 11**.

## What you own

`proposal.md` (**why**) and `specs/*.md` (**what** — observable behavior,
requirements, scenarios). That is your entire output.

You do **not** write `design.md` or `tasks.md`. This isn't status — it's that
they require knowledge of the target codebase's patterns and conventions that
you don't have in front of you, so a draft from you gets rewritten by the
implementing developer anyway. It's also enforced: `openspec/config.yaml`
declares `rules:` for both artifacts telling any agent to stop after `specs`
during initial proposal drafting.

## Setup

```bash
git clone --recurse-submodules <this-repo-url> workflow
cd workflow
make init      # submodules + register the shared "specifications" store
make doctor
make sync      # before starting any new work
```

## What belongs in `specifications` — and what doesn't

The shared store holds **only cross-cutting capabilities**: contracts more than
one repo must agree on — the API between frontend and backend, shared events,
anything `common` publishes. It is kept deliberately small.

If a story turns out to be single-repo, it is **not yours to propose**. Hand it
to that repo's developer; they propose and apply entirely inside their own repo
and you have no role in that path at all.

## Gate 2 — writing the proposal

**1. Pick up the story.** It arrives from the team lead already sized, labelled
`SDD`, and carrying a `change-id`. If it isn't sized — if it reads like several
independent capability changes — send it back rather than proposing something
no one can plan.

**2. Pull the affected repos into one view** instead of juggling directories:

```bash
openspec workset create <name>
openspec context --code-workspace ws.code-workspace
```

**3. Create the change** using the `change-id` the team lead reserved:

```bash
openspec new change <change-id>          # local repo
openspec new change <change-id> --store specifications   # cross-repo
```

Record the story key in `openspec/changes/<change-id>/.openspec.yaml`:

```yaml
schema: spec-driven
created: 2026-08-21
jira: PROJ-123
```

**4. Draft.** Run `/sdd:intake` (or `/opsx-propose`) against the store. It
generates `proposal.md` and `specs/*.md`. **Stop there** — let the config rules
halt it before `design.md` and `tasks.md`.

**5. Write scenarios like a tester will read them**, because one will, at gate
3. Each requirement needs at least one `#### Scenario:` with `WHEN`/`THEN`. Keep
them observable — no class names, no library choices, no implementation steps.

**6. Open a PR** against `specifications` (or the local repo). A change with
only `proposal.md` + `specs/` passes `openspec validate` and is mergeable;
`design`/`tasks` show as "blocked"/"ready", not errors, so there is no need to
fake them to get merged.

## Gate 3 handoff

The tester reviews your scenarios before the tech lead approves. Expect edge
cases to come back — that is the cheapest possible moment to find them, and a
scenario added here costs minutes instead of a re-opened story.

## Gate 5 handoff

Once merged, tell the affected repos' developers the change is ready to plan.
**They** write `design.md` and `tasks.md`. You don't chase them; they can
discover the change themselves:

```bash
openspec list --store specifications
openspec instructions design --change <id> --store specifications --json
```

## Tracking progress

```bash
openspec list   --store specifications
openspec show   <change-id> --store specifications
openspec status --change <change-id> --store specifications --json
```

`isComplete: false` is **expected** until a developer adds `tasks.md`. It means
"not ready for apply yet", not "something is wrong".

## Gate 11 — archiving

Once **every** consuming repo has merged and deployed its side:

```bash
/opsx-archive <change-id> --store specifications
```

This moves the change to `changes/archive/` and syncs
`specifications/openspec/specs/*` to the new canonical truth — the thing future
proposals build on. Confirm all sides have shipped, not just the fast one;
archiving early makes the canonical spec claim something that isn't true
everywhere yet.

## Commands

| Command | When |
|---|---|
| `/opsx-explore` | think through a story before committing to anything — writes nothing |
| `/sdd:intake` | story description → proposal + spec deltas, stops before design/tasks |
| `/opsx-update` | revise proposal/specs after review feedback, keeping them coherent |
| `/opsx-archive` | close out a shipped change |

## What you must not do

- **Don't write `design.md` or `tasks.md`**, even when you're sure of the
  approach. It's the implementing developer's call.
- **Don't touch `src/*` code.**
- **Don't put repo-internal specs into `specifications`.** Repo-local concerns
  belong in that repo's own `openspec/specs/`.
- **Don't archive before every consuming repo has shipped.**
