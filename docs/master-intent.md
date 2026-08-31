# The master intent

🇬🇧 English | [🇷🇺 Русский](./master-intent.ru.md)

A **master intent** is the complete business description of one change: one
Jira story, one OpenSpec change in the `specifications` store, four artifacts.

It exists so that a tester and several developers can all start work at the
same time, from the same document, without coordinating with each other. That
is a demanding bar: anything a developer needs but cannot find here becomes a
question in chat, and a question answered in chat is a decision nobody else
sees.

## Anatomy

```
specifications/openspec/changes/<intent-id>/
├── .openspec.yaml     schema, jira: PROJ-123
├── analysis.md        what is true today
├── proposal.md        why, what changes, rollout order
├── specs/
│   └── <capability>/spec.md    the behaviour contract
└── handoff.md         per-repo obligations + the fan-out checklist
```

### `analysis.md` — what is true today

Strictly descriptive. The moment you write what the system *should* do, you
have moved into `proposal.md`.

| Section | Holds |
|---|---|
| Scope | which capability is under examination, and the question to answer |
| Current behaviour | what happens today, cited to specs and file paths |
| Components involved | every repo that participates — **including those that do not change** |
| Contracts in play | every interface >1 repo depends on, with producer and all consumers |
| Constraints | what limits the solution and is not negotiable, with its source |
| Unknowns | what you could not answer, each with an owner and what it blocks |

Two rules that carry most of the value:

- **Cite everything.** A claim without a spec name or file path is a guess, and
  a guess here is repeated as fact by every developer downstream.
- **Never invent an answer to close an unknown.** An unknown surfaced here
  costs a sentence. The same unknown found during implementation costs a
  re-opened story.

Listing repositories that will *not* change matters more than it looks: it
tells a developer the area was considered and ruled out, rather than forgotten.

### `proposal.md` — why, and what changes

The **Rollout order** section is the one that only this document can hold. The
shared store is the only root that sees every repository at once, so it is the
only place the ordering between them can be written down. It must say:

- which repository produces a changed contract, and therefore lands and
  publishes **first**
- which repositories are independent of each other and therefore proceed **in
  parallel** — typically backend and frontend once the contract is agreed

The **Affected repositories** table drives `handoff.md`. If you change one,
change the other.

### `specs/` — the behaviour contract

The most-read artifact in the workflow. The tester writes tests from it before
any code exists; every developer implements against it.

**Altitude.** Include behaviour observable at the system boundary, and
contracts more than one repository must agree on. Exclude anything only
observable inside a single repository — that is the developer's component spec.

> Quick test: if the implementation could change freely without changing
> anything externally visible, it does not belong here.

**Mechanics that fail silently** — these are worth checking by hand:

- Scenarios use **exactly four hashtags** (`#### Scenario:`). Three hashtags,
  or a bullet list, parses as *nothing at all*, with no error, and the
  requirement looks scenario-less to every tool downstream.
- New capabilities open with `## Purpose`, 50+ characters. Without it, archive
  leaves a `TBD ... Update Purpose after archive` placeholder in the permanent
  spec.
- For `MODIFIED` requirements, copy the **entire** existing block including
  every scenario, then edit. A partial copy silently deletes the scenarios you
  left out when the intent is archived.

**Scenario quality.** `WHEN` is a concrete external trigger — "when the user
submits the form with an expired token", not "when the user is unauthorised".
`THEN` is observable from outside: a status code, a rendered message, a stored
record, an emitted event. Never "the service knows".

Every requirement needs at least one **unhappy path**. An intent whose
scenarios are all happy-path is not ready for review, and this is the single
most common reason one is sent back.

### `handoff.md` — who implements which part

What makes parallel work possible. For each repository:

| Field | Must contain |
|---|---|
| Requirements owned | the exact `### Requirement:` names from `specs/` |
| Contract obligations | precise enough to build against **before the other side exists** |
| Depends on | which repos must publish first, or "nothing — may start immediately" |
| Acceptance | how the developer knows they are done, checkable without reading code |
| Guidance | only what a competent developer there could not work out alone |

Then the checklist:

```markdown
## Fan-out

- [ ] backend (PROJ-124) - derived change archived
- [ ] frontend (PROJ-125) - derived change archived
```

**Two invariants.**

1. Every requirement in `specs/` is owned by at least one repository. Compute
   the union and check it — a requirement owned by nobody is how a story ships
   half-implemented.
2. Every box starts unticked, and is ticked only by
   `scripts/intent-gate.sh --tick`, which verifies the repository actually
   archived its work. A hand-ticked box is precisely what the gate exists to
   catch.

"Returns user data" is not a contract obligation. Field names, types, status
codes and error cases are. Over-specify here: the developer on the other side
cannot ask you, because they are working at the same time as you.

## Altitude, in one table

| Where | Holds | Written by |
|---|---|---|
| intent `specs/` | system-boundary behaviour, cross-repo contracts | analytics |
| intent `handoff.md` | who owns what, contract obligations | analytics |
| repo `specs/` | behaviour at one repo's own boundary | developer |
| repo `design.md` | how — classes, libraries, schemas, layout | developer |
| repo `tasks.md` | the checklist | developer |

`design.md` is the first place implementation detail is allowed, and the only
place. The store's config actively refuses `design.md` and `tasks.md`, and will
tell the agent to stop rather than create them.

This split is deliberate: an analyst can legitimately write *why* and *what*,
but not *how* — that needs codebase and convention knowledge they do not have.

## Lifecycle

```
authored ──▶ reviewed ──▶ merged ──▶ fanned out ──▶ all repos archived ──▶ archived
   │            │            │                                                │
analytics   team lead   ordering gate:                        specs fold into
                        no branch may                    specifications/openspec/specs/
                        exist before this                = the new source of truth
```

Once archived, the intent's specs *are* the description of the system. The next
intent's `analysis.md` will cite them. Archiving early — before every
repository is finished — publishes a description of behaviour that does not
exist, and every intent authored afterwards inherits the error. Hence the gate.

## Checking an intent

```bash
openspec validate <intent-id> --store specifications --strict
scripts/check-sdd.sh --change <intent-id> --store specifications
scripts/intent-status.sh <intent-id>      # where the fan-out has got to
scripts/intent-gate.sh <intent-id>        # may it be archived yet?
```
