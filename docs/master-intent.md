# The master intent

🇬🇧 English | [🇷🇺 Русский](./master-intent.ru.md)

A **master intent** is the business description of one change — one Jira story,
one OpenSpec change in the `specifications` store, two artifacts — and it is a
**meta layer above the standard OpenSpec workflow**, not a variant of it.

That distinction is the whole design. Analytics writes the intent; each
developer then feeds it into the *unmodified* OpenSpec workflow in their own
repository and writes their own `proposal.md`, `specs/`, `design.md` and
`tasks.md` from it.

```
     ANALYTICS                        DEVELOPER, in one repository
  ┌────────────────┐              ┌──────────────────────────────────┐
  │ master intent  │  input to    │ /opsx:propose                    │
  │   intent.md    │ ───────────▶ │ /opsx:apply                      │
  │   specs/       │   propose    │ /opsx:archive                    │
  └────────────────┘              └──────────────────────────────────┘
   business need                    proposal.md, specs/, design.md,
   whole-system context             tasks.md — all written and owned
   business rules                   by the developer
```

The intent is the **input** to propose. It is never half of one. Splitting a
single OpenSpec workflow across two roles — the analyst writing the proposal,
the developer writing the tasks — is the thing this layer exists to avoid: it
changes a workflow that is already coherently designed, and leaves each role
holding a fragment of a document neither of them owns.

It exists so that a tester and several developers can all start at the same
time, from the same document, without coordinating with each other. That is a
demanding bar: anything a developer needs but cannot find here becomes a
question in chat, and a question answered in chat is a decision nobody else
sees.

## Anatomy

```
specifications/openspec/changes/<intent-id>/
├── .openspec.yaml     schema: master-intent, jira: PROJ-123
├── intent.md          business need, whole-system context, fan-out
└── specs/
    └── <capability>/spec.md    the business rules this change adds or modifies
```

### `intent.md` — the business need and the whole-system context

| Section | Holds |
|---|---|
| Business need | why this is worth doing, whose problem it solves, what happens if it is not done |
| Today | how the capability behaves for the business now, cited |
| What must be true afterwards | the business outcome, observable to a user or another organisation |
| System context | external API contracts, the UI needed, data obligations, events others depend on |
| Repositories | who takes part and what each contributes — **including those ruled out** |
| Constraints | what limits the solution and is not negotiable, with its source |
| Open questions | what you could not answer, each with an owner and what it blocks |
| Fan-out | one unticked checkbox per repository |

**System context is the section that justifies this layer.** Everything else in
the intent could arguably be written by a developer in one repository; this
cannot. It carries what the outside world requires: the external API contracts
this system exposes or consumes — including shapes a partner has already fixed
— what a user must be able to see and do, what data must be captured or
retained, and what events other parties depend on. Attach or link the external
contract documents themselves where they exist.

It is context, not design. State what the outside world requires; never how
this system should be built to meet it.

Three rules carry most of the value:

- **Cite everything in Today.** A claim without a business rule or file path is
  a guess, and a guess here is repeated as fact by every developer downstream.
- **Never invent an answer to close an open question.** An unknown surfaced
  here costs a sentence. The same unknown found during implementation costs a
  re-opened story.
- **Never say what a repository should build.** The Repositories table says
  what each one *contributes*, in business terms. What it builds is decided by
  its own `propose`, by the developer who owns it.

Listing repositories that will *not* change matters more than it looks: it
tells a developer the area was considered and ruled out, rather than forgotten.

### `specs/` — the business rules

The most-read artifact in the workflow. The tester writes tests from it before
any code exists; every developer's `propose` derives their repository's
requirements from it. On archive it folds into `specifications/openspec/specs/`
and becomes the standing description of the business.

**Altitude.** Include rules a user, a customer or another organisation can
observe, and rules more than one repository must agree on. Exclude anything
only observable inside a single repository — that is the developer's component
spec, written in their repo during `propose`.

> Quick test: if the implementation could change freely without changing
> anything externally visible, it does not belong here.

**Mechanics that fail silently** — worth checking by hand:

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

An intent that changes no observable business rule legitimately has no specs at
all — set `skip_specs: true` rather than inventing a requirement to satisfy
validation.

### The fan-out checklist

```markdown
## Fan-out

- [ ] `backend` (`PROJ-124`) - change archived
- [ ] `frontend` (`PROJ-125`) - change archived
```

**Two invariants.**

1. Every requirement in `specs/` is plainly the responsibility of at least one
   repository in the Repositories table. A requirement owned by nobody is how a
   story ships half-implemented.
2. Every box starts unticked, and is ticked only by
   `scripts/intent-gate.sh --tick`, which verifies the repository actually
   archived its work. A hand-ticked box is precisely what the gate exists to
   catch.

## Altitude, in one table

| Where | Holds | Written by |
|---|---|---|
| intent `intent.md` | business need, whole-system context, who takes part | analytics |
| intent `specs/` | the business rules — what a user or another organisation observes | analytics |
| repo `proposal.md` | what **this** repository does about it | developer |
| repo `specs/` | behaviour at one repo's own boundary | developer |
| repo `design.md` | how — classes, libraries, schemas, layout | developer |
| repo `tasks.md` | the checklist | developer |

The store's schema defines exactly two artifacts, so asking for a third is a
hard error rather than a convention:

```
$ openspec instructions proposal --change <id> --store specifications
Artifact 'proposal' not found in schema 'master-intent'. Valid artifacts:
  intent
  specs
```

`design.md` is the first place implementation detail is allowed, and the only
place. This split is deliberate: an analyst can legitimately establish the
business need and the external constraints, but not *what to build* — that
needs codebase and convention knowledge they do not have, and it is the
developer's own proposal that decides it.

## Lifecycle

```
authored ──▶ reviewed ──▶ merged ──▶ fanned out ──▶ all repos archived ──▶ archived
   │            │            │                                                │
analytics   team lead   ordering gate:                    business rules fold into
                        no branch may                specifications/openspec/specs/
                        exist before this             = the new source of truth
```

Once archived, the intent's specs *are* the business rules of record. The next
intent's **Today** section will cite them. Archiving early — before every
repository is finished — publishes a description of behaviour that does not
exist, and every intent authored afterwards inherits the error. Hence the gate.

## Checking an intent

```bash
openspec validate <intent-id> --store specifications --strict
scripts/check-sdd.sh --change <intent-id> --store specifications
scripts/intent-status.sh <intent-id>      # where the fan-out has got to
scripts/intent-gate.sh <intent-id>        # may it be archived yet?
```
