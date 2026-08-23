# Tech lead

🇬🇧 English | [🇷🇺 Русский](./tech-lead.ru.md)

You are the approval gate on shared contracts and on technical approach. You
work in **Mode A** — this `workflow` repo, all application repos checked out
side by side — because approving a contract requires seeing every side of it.

Read [the pipeline](../pipeline.md) once first. You own **gates 4 and 10**,
and you review at **gate 5**.

## What you own

- Approving proposals in `specifications` — especially the contract delta.
- Enforcing the ordering rule: spec merged before any code branch exists.
- Reviewing `design.md` and the gating in `tasks.md` before code starts.
- Deciding when a change is cross-repo (shared store) vs. repo-local.
- **Approving production promotions** (gate 10) and owning the rollback call.
- The [20% tech-debt slice](../scrum.md#capacity-and-the-20-rule) of every
  sprint — yours to spend without arguing for it story by story.

## Setup

```bash
git clone --recurse-submodules <this-repo-url> workflow
cd workflow
make init      # submodules + register the shared "specifications" store
make doctor    # sanity-check the OpenSpec root/store relationship
make sync      # pull latest shared specs before reviewing anything
```

## Gate 4 — approving a proposal

A proposal reaching you has `proposal.md` + `specs/*.md` and nothing else. That
is correct and mergeable; `design`/`tasks` showing as "blocked"/"ready" are not
errors.

```bash
openspec show <change-id> --store specifications
openspec validate <change-id> --store specifications
```

Review for these, in order of how expensive they are to get wrong:

1. **Contract ambiguity.** Frontend and backend will build against this
   independently, without talking to each other again. Any sentence that could
   be read two ways becomes two incompatible implementations and a late,
   expensive integration failure. This is the single highest-value thing you do
   in the whole pipeline.
2. **Scope of the shared store.** Does this genuinely need to be shared? If
   nothing outside one repo consumes it, it belongs in that repo's local
   `openspec/specs/`, not in `specifications`. The shared store is kept small
   on purpose — every spec in it is one more thing that can drift.
3. **Sizing.** If the proposal covers several independent capability changes,
   send it back to the team lead as an Epic rather than approving a change no
   single developer can plan.
4. **Scenario coverage.** The tester has already passed at gate 3; you are
   confirming, not redoing it.

Merging to `main` is the approval. **Nothing may branch before this merge** —
that ordering is item 8 of the metric and is checked mechanically.

## Gate 5 — reviewing the plan

The implementing developer writes `design.md` and `tasks.md`. You review them
before code starts, because a wrong technical approach caught here costs an
hour and caught at PR review costs a sprint.

Check:

- **`design.md` exists when it should.** Warranted for a cross-cutting change,
  a new dependency, a migration, or anything with a non-obvious approach. Not
  warranted for a small local change — don't demand ceremony.
- **One section per affected repo, each with its Jira task key:**
  `## 2. Backend (PROJ-125)`.
- **Contract gating is explicit.** The `## Common` section must land and
  publish before the consuming sections start, and the gate must be written
  down, not assumed:

  ```markdown
  ## 2. Backend (PROJ-125)

  <!-- gated: do not start until 1.2 has published -->
  ```

- **No task depends on another repo's unpublished code.** If it does, the
  gating is wrong.

## Gate 10 — approving a production promotion

By the time a promotion PR reaches you, the build has been verified on `dev`
(gate 9) and has been running on `staging`. **Your approval is a decision about
*when*, never about *what*.**

The PR changes exactly one image digest and one version. Check three things,
and it should take two minutes:

1. **The diff is one digest.** If a promotion PR touches anything else, that is
   a config change riding along where nobody will read it. Send it back.
2. **The timing.** Not into a demo, not at 17:55 on Friday, not during a
   migration window someone else owns.
3. **Rollback is available.** The previous digest is in the PR body. If the
   release contains a non-backward-compatible migration, there is no rollback —
   [roll forward instead](../release.md#rollback), and know that before you
   approve rather than after.

You do not re-verify the build. That was gate 9, and redoing it here means
nobody owns either gate.

**Rollback is your call and it is not an escalation.** A rollback within the
health-check window is automatic; after that,
`scripts/promote.sh --service <s> --to prod --digest <previous>` is a normal
operation you should be comfortable running. Practising it quarterly is part
of the job.

## Where a change belongs

| The change… | Authored in | Reached with |
|---|---|---|
| touches only one repo's internals | that repo's `openspec/changes/` | no flag |
| touches a contract another repo consumes | `specifications` | `--store specifications` |

When in doubt: does another repo have to change its code because of this? If
no, it's local.

## Why `common` is a package, not a submodule

Submoduling `common` into both `frontend` and `backend` forces them into
lockstep — every `common` change requires both to bump a pointer before either
can build, which defeats parallel development entirely. Instead `common` is
versioned and published to an internal registry, and each side upgrades
deliberately. It is a submodule *of this workflow repo* only, for read context
while reviewing.

Expect to defend this one repeatedly; it looks like unnecessary indirection
until the first time two teams are blocked on each other.

## What you must not do

- **Don't approve a contract you had to guess at.** Ambiguity here is the
  most expensive defect class in this pipeline.
- **Don't let repo-internal specs into `specifications`.** A large shared store
  stops being reviewed and starts being wrong.
- **Don't approve a proposal after code has started.** It fails the metric, and
  the approval was theatre.
- **Don't write `tasks.md` for the developer.** Review it; don't author it.
