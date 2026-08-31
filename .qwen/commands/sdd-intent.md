---
description: "Analytics: author a master intent - the business context a developer feeds into the standard OpenSpec workflow"
---

Author a **master intent**: the business source of truth for one Jira story,
and the prepared context that every affected repository feeds into the standard
OpenSpec workflow.

## What this is, and what it is not

The master intent is a **meta layer above OpenSpec**, not a variant of it.

```
     ANALYTICS                      DEVELOPER, in their own repo
  ┌──────────────┐              ┌────────────────────────────────┐
  │ master intent│ ──────────▶  │ /opsx-propose  ← the intent is │
  │ intent.md    │   input to   │ /opsx-apply       its input    │
  │ specs/       │   propose    │ /opsx-archive                  │
  └──────────────┘              └────────────────────────────────┘
   business need                  proposal, specs, design, tasks
   whole-system context           all written and owned by the developer
```

You write the business need and the whole-system context. The developer writes
`proposal.md`, their repository's `specs/`, `design.md` and `tasks.md` — all
four, themselves, with the unmodified OpenSpec workflow. **Never write any of
them here**, and never write an intent that reads like the first half of one.
Splitting a single OpenSpec workflow across two roles is exactly what this
layer exists to avoid.

**Input**: `/sdd-intent <JIRA-KEY>` and/or a description. If you have only a
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

```
1 Epic  = N stories                 too big for one intent
1 Story = 1 master intent           <- the SDD label lives here
1 Task  = 1 repo = 1 branch = 1 PR  <- one standard OpenSpec change per repo
```

Repositories are **not** the reason to split a story. One intent spanning
backend and frontend is normal and correct — that is the whole point of the
System context and Repositories sections.

### 2. Establish the baseline, unless you already have

If you have not just run `/opsx-explore` on this area, establish the current
truth now. An intent written without reading the current business rules
contradicts behaviour the system already has.

| Question | Source |
|---|---|
| What are the business rules today? | `openspec list --specs --store specifications` |
| Why are they like that? | `specifications/openspec/changes/archive/` |
| What is being changed right now? | `./scripts/intent-status.sh` |
| How is it actually built? | the repositories under `src/` |
| How does one repo behave at its own boundary? | `src/<repo>/openspec/specs/` |

An open intent touching the same area changes everything: either this work is
part of it, or it must be sequenced against it. Say which, explicitly.

### 3. Create the intent

Derive a kebab-case id from the intent itself, not from the Jira key
(`add-sso-login`, not `proj-123`). If the story already records an id, use it.

```bash
openspec new change "<intent-id>" --store specifications
```

The store's default schema is `master-intent`, which defines exactly two
artifacts — `intent.md` and `specs/` — and refuses `proposal.md`, `design.md`
and `tasks.md`.

### 4. Link it to Jira — do not skip this

Edit `specifications/openspec/changes/<intent-id>/.openspec.yaml`:

```yaml
schema: master-intent
created: <date>
jira: PROJ-123        # the Story, not a task
```

`scripts/check-sdd.sh` fails the intent without it, and `scripts/intent-gate.sh`
refuses to archive it. If you do not know the key, ask.

### 5. Write the two artifacts

```bash
openspec status --change "<intent-id>" --store specifications --json
openspec instructions <artifact> --change "<intent-id>" --store specifications --json
```

Follow the returned `instruction`, `rules` and `template` exactly — they carry
the altitude rules this store enforces.

1. **`intent.md`** — Business need · Today · What must be true afterwards ·
   System context · Repositories · Constraints · Open questions · Fan-out.

   **System context is the section that justifies this whole layer.** It
   carries what a developer sitting in one repository could not work out alone:
   the external API contracts involved — including shapes an outside party has
   already fixed — the user interface that is needed in terms of what a user
   must see and do, the data that must be captured or retained, and the events
   other parties depend on. Attach or link the external contract documents
   themselves where they exist. State what the outside world requires; never
   how this system should be built to meet it.

   In **Repositories**, say what each one contributes in business terms, and
   name the ones ruled out. Do not specify what any repository should build —
   its own `propose` decides that.

   Leave every **Fan-out** checkbox unticked.

2. **`specs/<capability>/spec.md`** — the delta to the **business rules**. This
   is what folds into `openspec/specs/` on archive, so the store keeps
   describing the business rather than accumulating documents. It is also what
   the tester writes scenarios from and what each developer's `propose` derives
   their repository's requirements from.

   Business altitude only: rules a user, a customer or another organisation can
   observe, and rules more than one repository must agree on. Scenarios use
   **exactly four hashtags**; three parses as nothing, silently. Every
   requirement needs at least one unhappy path.

   An intent that changes no observable business rule legitimately has none —
   set `skip_specs: true` rather than inventing one.

### 6. Check it can actually be picked up

Before reporting, read `intent.md` as each developer will: **from their
repository, with nothing else open**. Ask, per repository:

- Do they know what business outcome they are responsible for?
- Do they know every external contract and UI requirement that constrains them?
- Could they run `/opsx-propose` from this document without asking you a
  question?

Anything that fails those three is a gap in the intent, not something for the
developer to work out. Every requirement in `specs/` must be plainly the
responsibility of at least one repository in the Repositories table.

### 7. Report

```bash
openspec validate "<intent-id>" --store specifications
./scripts/check-sdd.sh --change "<intent-id>" --store specifications
```

Tell the user:

- where the intent lives and which Jira story it is linked to
- which repositories will implement it, and which may go in parallel
- the open questions that still need an owner
- next step: **team lead reviews and merges it** (`/sdd-review`), and
  **no branch may be cut in any repository before that merge** — the metric
  checks the ordering and it cannot be fixed after the fact
- after the merge each developer works in their own repository with the
  standard commands, giving this intent to `/opsx-propose` as its input, then
  `/opsx-apply` and `/opsx-archive`

## Guardrails

- **Never write `proposal.md`, `design.md` or `tasks.md`.** All three are the
  developer's, written in the developer's repository. The store's config
  refuses them.
- **Never name a class, function, library, framework or file.** If you cannot
  state the requirement without one, you are describing a solution.
- **Never invent an answer to close an open question.** An unknown surfaced now
  costs a sentence; found during implementation it costs a re-opened story.
- **Never tick a Fan-out checkbox when authoring.** They are ticked only as
  each repository archives its work, and `scripts/intent-gate.sh --tick`
  verifies them independently.
- **Never proceed past an oversized story.** Escalate it as an Epic.
