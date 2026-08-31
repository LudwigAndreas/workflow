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

### 1. Read all four artifacts, in full

```bash
openspec show <intent-id> --store specifications --json
openspec validate <intent-id> --store specifications --strict
./scripts/check-sdd.sh --change <intent-id> --store specifications
```

Read `analysis.md`, `proposal.md`, every file under `specs/`, and `handoff.md`.
Do not review from the proposal alone — the errors that hurt are in the specs
and the handoff.

### 2. Work the checklist

Report each as pass or fail, with the specific line at fault.

**Sizing and linkage**
- One capability change, reviewable as a single decision? If it is really two,
  send it back to be split into an Epic.
- `jira:` records a **Story** key, and that story carries the `SDD` label.

**Analysis**
- Every claim cited to a spec name or a real file path — no uncited assertions.
- Repositories that were considered and ruled out are named as such.
- Open questions have owners, and none of them would change the specs. An
  unanswered question that *would* change the specs blocks the merge.

**Specs — the contract**
- Scenarios use exactly four hashtags. Three parses as nothing, silently, and
  the requirement will look scenario-less to every tool downstream.
- Every requirement has at least one **unhappy path**. All-happy-path specs are
  the most common reason to send an intent back.
- Every `WHEN` is a concrete external trigger; every `THEN` is observable from
  outside the system. "The service knows", "the state is correct" — send back.
- Nothing is at implementation altitude: no class, function, library or
  framework names.
- For MODIFIED requirements, the **entire** original block was copied before
  editing. A partial copy silently deletes scenarios at archive time — check
  this against `openspec/specs/<capability>/spec.md` yourself.

**Handoff — the thing that makes parallel work possible**
- Every requirement in `specs/` is owned by at least one repository section.
  Compute the union and check it. A requirement owned by nobody ships half a
  feature.
- Contract obligations are precise enough to build against **before the other
  side exists**: field names, types, status codes, error cases. "Returns user
  data" is not reviewable and not buildable — send it back.
- `Depends on` for each repository agrees with the proposal's rollout order.
- Every repository section has a Jira task key, or the team lead assigns one
  now.
- All Fan-out checkboxes are unticked.

**Rollout order**
- A repository that produces a changed contract lands and publishes before its
  consumers start.
- Repositories with no dependency between them are explicitly allowed to
  proceed in parallel.
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
- **Do not approve while a blocking open question is unanswered.** "We will
  work it out during implementation" means each repository works it out
  differently.
- **The merge is the ordering gate.** If a branch already exists for this
  story, say so plainly — the metric records that the spec followed the code,
  and that is not fixable by rewriting history.
