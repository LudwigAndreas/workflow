---
name: "SDD: Intent"
description: "Analytics: author a master intent - the business source of truth for one Jira story"
allowed-tools: Bash(openspec:*), Bash(git:*), Bash(./scripts/*), Read, Write, Edit, Grep, Glob
category: "SDD"
tags: ["sdd", "analytics", "intent"]
---

Author a **master intent**: the single business description of one change, from
which every repository derives its implementation.

This is the one custom step in the whole workflow, and it exists because
nothing standard fills its place: the intent spans four repositories at once,
and it must be written before any of them starts. Everything on either side of
it is the stock OpenSpec workflow — `/opsx:explore` before, and
`/opsx:propose` → `/opsx:apply` → `/opsx:archive` inside each repository after.

A master intent is one OpenSpec change in the shared `specifications` store,
with four artifacts: `analysis.md` (what is true today), `proposal.md` (why and
what), `specs/` (the behaviour contract), `handoff.md` (who implements which
part). Together they must be complete enough that a backend developer and a
frontend developer, who never speak to each other, build halves that fit.

**Input**: `/sdd:intent <JIRA-KEY>` and/or a description. If you have only a
key, ask the user to paste the story description — do not invent the intent.

## Steps

### 1. Size it first — before writing anything

Ask yourself, and tell the user your answer:

> Can this be reviewed and approved as a **single decision**, and does it
> describe **one** user-facing capability change?

- **Yes** → one master intent. Continue.
- **No — this is several independent capability changes** → **STOP.** This is
  a Jira **Epic**, split into several Stories, each getting its own intent.
  Propose the split as a list and wait for the user to choose.

The unit is fixed and is what makes the SDD metric work:

```
1 Epic  = N stories                 too big for one intent
1 Story = 1 master intent           <- the SDD label lives here
1 Task  = 1 repo = 1 branch = 1 PR  <- one derived change per repo
```

Repositories are **not** the reason to split a story. One intent spanning
backend and frontend is normal and correct; that is exactly what the handoff
artifact is for. Never split one capability change across two stories, and
never bundle two capability changes into one intent to avoid this conversation.

### 2. Establish the baseline, unless you already have

If you have not just run `/opsx:explore` on this area, establish the current
truth now. Authoring an intent without reading the current baseline produces a
proposal that contradicts behaviour the system already has.

Read in this order — later sources are more detailed, earlier ones more
authoritative about intent:

| Question | Source |
|---|---|
| How does the system behave today? | `openspec list --specs --store specifications` |
| Why is it like that? | `specifications/openspec/changes/archive/` |
| What is being changed right now? | `./scripts/intent-status.sh` |
| How is it actually built? | the repositories under `src/` |
| How does one repo behave at its own boundary? | `src/<repo>/openspec/specs/` |

Two things matter more than the rest and are most often found too late:

- **An open intent touching the same area.** Either this work is part of it, or
  it must be sequenced against it. Say which, explicitly. Never author a second
  intent that silently contradicts an open one.
- **The contracts.** For the area under examination, list every interface more
  than one repository depends on — HTTP endpoints, event payloads, shared
  types, config keys — and for each name the producer and **every** consumer.
  This determines whether the repositories can implement in parallel.

### 3. Create the intent

Derive a kebab-case id from the intent itself, not from the Jira key
(`add-sso-login`, not `proj-123`). If the story already records an id, use that
exact one.

```bash
openspec new change "<intent-id>" --store specifications
```

The store's default schema is `master-intent`, so this scaffolds the four
artifacts — and refuses `design.md` and `tasks.md`, which belong in the
implementing repositories.

### 4. Link it to Jira — do not skip this

Edit `specifications/openspec/changes/<intent-id>/.openspec.yaml`:

```yaml
schema: master-intent
created: <date>
jira: PROJ-123        # the Story, not a task
```

`scripts/check-sdd.sh` fails the intent without it, and `scripts/intent-gate.sh`
refuses to archive it. If you do not know the key, ask.

### 5. Write the four artifacts, in order

Work through them with `openspec status --change "<intent-id>" --store specifications --json`
to see what is ready, and for each one:

```bash
openspec instructions <artifact> --change "<intent-id>" --store specifications --json
```

Follow the returned `instruction`, `rules` and `template` exactly — they carry
the altitude rules this store enforces. Re-read completed artifacts from disk
before writing the next; do not work from memory of what you wrote.

1. **`analysis.md`** — strictly descriptive. What is true today, cited to a
   capability spec or a real file path. An uncited claim is a guess, and a
   guess here is repeated as fact by every developer downstream.
2. **`proposal.md`** — why, what changes, the capabilities, the affected
   repositories table, and the **rollout order**. This store is the only place
   that sees every repository at once, so it is the only place the ordering can
   be written down.
3. **`specs/<capability>/spec.md`** — the behaviour contract. This is the
   artifact the tester writes tests from and every developer implements
   against. Scenarios use **exactly four hashtags**; three parses as nothing at
   all, silently. Every requirement needs at least one unhappy path.
4. **`handoff.md`** — one section per repository, plus the `## Fan-out`
   checklist. **Leave every checkbox unticked.**

### 6. Check the handoff covers the specs

Before reporting, verify by hand: every `### Requirement:` in `specs/` is owned
by at least one repository section in `handoff.md`. A requirement owned by
nobody is the single most common way a story ships half-implemented.

Each repository section must be precise enough to build against **before the
other side exists**: field names, types, status codes, error cases. A developer
reading only their own section, in their own repository, with `/opsx:propose`,
must be able to derive their whole change from it.

### 7. Report

```bash
openspec validate "<intent-id>" --store specifications
./scripts/check-sdd.sh --change "<intent-id>" --store specifications
```

Tell the user:

- where the intent lives and which Jira story it is linked to
- which repositories will implement it, and which may go in parallel
- the open questions from `analysis.md` that still need an owner
- next step: **team lead reviews and merges it** (`/sdd:review`), and
  **no branch may be cut in any repository before that merge** — the metric
  checks the ordering and it cannot be fixed after the fact
- after the merge each developer works in their own repository with the
  standard commands: `/opsx:propose` → `/opsx:apply` → `/opsx:archive`

## Guardrails

- **Never write `design.md` or `tasks.md` here.** The store's config refuses
  them. Implementation detail belongs in the implementing repository, written
  by the developer who owns it, in their own change.
- **Never name a class, function, library or framework.** If you cannot
  describe the requirement without one, you are specifying implementation.
- **Never invent an answer to close an open question.** An unknown surfaced now
  costs a sentence; the same unknown found during implementation costs a
  re-opened story and a wasted sprint.
- **Never tick a Fan-out checkbox when authoring.** They are ticked only as
  each repository archives its work, and `scripts/intent-gate.sh --tick`
  verifies them independently.
- **Never proceed past an oversized story.** Escalate it as an Epic.
- **Do not invent requirements to satisfy validation.** If the change has no
  observable behaviour change, set `skip_specs: true` and write the proposal
  only.
