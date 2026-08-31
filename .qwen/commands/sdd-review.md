---
description: "Team lead: review a master intent and decide whether it may be merged"
---

Review a master intent before it is merged into the `specifications` store.

This is the decision gate of the whole workflow. Once this intent merges, a
tester starts writing tests from it and several developers start implementing
against it **in parallel, without talking to each other**. Everything they
build assumes this document is right. A contract error found here costs a
comment; found after three repositories have implemented it, it costs the
sprint.

**Input**: `/sdd-review <intent-id>`. With no argument, list open intents and
ask which one.

## Steps

### 1. Read both artifacts, in full

```bash
openspec show <intent-id> --store specifications --json
openspec validate <intent-id> --store specifications --strict
./scripts/check-sdd.sh --change <intent-id> --store specifications
```

Read `intent.md` in full and every file under `specs/`. Do not review from
`intent.md` alone — the errors that hurt are in the specs and in the System
context section.

Remember what you are reviewing. The intent is the **input** to each
developer's `/opsx-propose`; it is not a proposal itself. If it reads like one
— if it says what to build rather than what must be true — that is a finding,
and so is a `proposal.md`, `design.md` or `tasks.md` appearing in the store at
all.

### 2. Work the checklist

Report each as pass or fail, with the specific line at fault.

**Sizing and linkage**
- One capability change, reviewable as a single decision? If it is really two,
  send it back to be split into an Epic.
- `jira:` records a **Story** key, and that story carries the `SDD` label.

**intent.md — business need and current state**
- Every claim about today cited to a business rule in `openspec/specs/` or a
  real file path — no uncited assertions.
- "What must be true afterwards" is a business outcome, observable to a user or
  another organisation, not a description of a mechanism.
- Nothing at solution altitude: no class, function, library, framework or file
  name anywhere in the document.
- Repositories that were considered and ruled out are named as such.
- Open questions have owners, and none of them would change the specs. An
  unanswered question that *would* change the specs blocks the merge.

**intent.md — System context, the section this layer exists for**
- Every external API contract in play is named, with the shape an outside party
  has already fixed, and the document itself attached or linked where one
  exists.
- The user interface needed is stated in terms of what a user must see and do.
- Data obligations — what is captured, retained, removed — are stated where
  they apply.
- The test: could a developer, in one repository, with nothing else open, run
  `/opsx-propose` from this document without asking analytics a question? If
  not, name the specific missing fact.

**specs/ — the business rules**
- Scenarios use exactly four hashtags. Three parses as nothing, silently, and
  the requirement will look scenario-less to every tool downstream.
- Every requirement has at least one **unhappy path**. All-happy-path specs are
  the most common reason to send an intent back.
- Every `WHEN` is a concrete external trigger; every `THEN` is observable from
  outside the system. "The service knows", "the state is correct" — send back.
- Business altitude: rules a user, a customer or another organisation can
  observe, or that more than one repository must agree on. Anything only
  observable inside a single repository belongs in that repository's own change.
- For MODIFIED requirements, the **entire** original block was copied before
  editing. A partial copy silently deletes scenarios at archive time — check
  this against `openspec/specs/<capability>/spec.md` yourself.

**Repositories and fan-out**
- Every requirement in `specs/` is plainly the responsibility of at least one
  repository in the table. A requirement owned by nobody ships half a feature.
- Each row says what that repository contributes **in business terms** and does
  not specify what it should build — that is its own `propose`'s job.
- Every row has a Jira task key, or the team lead assigns one now.
- The Fan-out checklist has one unticked box per repository in the table.

**Ordering and breakage**
- Where one repository must publish something before another can finish, the
  intent says so, and says who may start immediately.
- Breaking changes name every consumer that breaks, and say what happens to
  clients already deployed.

### 3. Decide, and say so plainly

- **Approve** — state that it may be merged, and that branches may be cut in
  the named repositories **only after the merge lands**.
- **Request changes** — a numbered list of specific, actionable items, each
  pointing at a file and a line. Do not rewrite the intent yourself; the author
  learns nothing from a silent fix, and analytics owns this artifact.

### 4. After merge

Tell the user what happens next, in parallel:

- the **tester** starts writing tests from `specs/` (`/sdd-tests`)
- each **developer** cuts their branch — now, and not before — and derives
  their repository's change with the standard `/opsx-propose`, naming this
  intent, then `/opsx-apply` and `/opsx-archive`

## Guardrails

- **Do not approve an intent whose contracts are vague.** Vagueness here is
  resolved independently in each repository, differently, and the mismatch
  surfaces at integration.
- **Do not fix the intent yourself.** Request the change.
- **Do not accept a developer artifact in the store.** A `proposal.md`,
  `design.md` or `tasks.md` here means the two layers have been collapsed;
  send it back rather than tidying it away.
- **Do not approve while a blocking open question is unanswered.** "We will
  work it out during implementation" means each repository works it out
  differently.
- **The merge is the ordering gate.** If a branch already exists for this
  story, say so plainly — the metric records that the spec followed the code,
  and that is not fixable by rewriting history.
