# The workflow

🇬🇧 English | [🇷🇺 Русский](./workflow.ru.md)

One story, one **master intent**, many repositories implementing it in
parallel. This page is the spine: read it first, then your
[role page](./roles/).

## The shape of it

```
                    ┌─────────────────────────────────────────┐
                    │  specifications  (business truth)        │
   analytics ──1──▶ │  master intent: analysis, proposal,      │
                    │  specs, handoff                          │
   team lead ──2──▶ │  reviewed, merged  ◀── the ordering gate │
                    └───────────────┬─────────────────────────┘
                                    │  fan-out, in parallel
              ┌─────────────────────┼─────────────────────┐
              ▼                     ▼                     ▼
        3  tester              4  backend            4  frontend
        writes tests           derive → plan         derive → plan
        from specs             → apply → archive     → apply → archive
              │                     │                     │
              └─────────────────────┴─────────────────────┘
                                    │  all repos archived
                                    ▼
                    ┌─────────────────────────────────────────┐
                    │  5  intent archived                      │
                    │  its specs become openspec/specs/ —      │
                    │  the baseline every future intent is     │
                    │  written against                         │
                    └─────────────────────────────────────────┘
```

## The five stages

### 1. Analytics writes the master intent

Analytics explores the current source of truth with the standard
`/opsx:explore`, then authors one master intent in the `specifications` store
with `/sdd:intent`. That authoring step is the **only** custom command in the
whole flow: it spans every repository at once, which nothing standard does.
It produces one OpenSpec change with four artifacts:

| Artifact | Answers | Altitude |
|---|---|---|
| `analysis.md` | What is true **today**? | descriptive only, everything cited |
| `proposal.md` | Why, what changes, in what order | system: repos, capabilities, contracts |
| `specs/` | What must the system **do**? | observable behaviour + cross-repo contracts |
| `handoff.md` | Who implements which part? | per-repo obligations + the fan-out checklist |

Analytics never writes `design.md` or `tasks.md`. The store's config refuses
them: technical design needs codebase knowledge an analyst does not have, and
it belongs to the developer who will implement it.

### 2. Team lead reviews and merges

`/sdd:review`. This is the decision gate of the whole workflow, because after
it several people build against this document **without talking to each other**.
A vague contract here is resolved differently in each repository, and the
mismatch appears at integration.

**No branch may exist in any repository before this merge.** The SDD metric
records whether the spec landed before the first commit, and that is not
fixable afterwards.

### 3. Tester writes tests — immediately, not later

`/sdd:tests`. The scenarios in `specs/` are already in WHEN/THEN form so they
can be executed as tests before any implementation exists. The tester is not
waiting for developers; they work from the same contract at the same time.

Testing also finds contract defects while they are still cheap: a `THEN` that
is not observable, a requirement with only a happy path, a contract too vague
to assert on.

### 4. Developers implement, in parallel — with the standard commands

Each affected repository does its own full OpenSpec cycle, in its own repo,
using the **stock** OpenSpec workflow. There is no custom command and no custom
schema on this side:

```
git checkout -b PROJ-123/PROJ-124-<slug>    only after the intent merged
/opsx:propose             proposal.md + specs/ + design.md + tasks.md,
                          recording jira: + intent: in .openspec.yaml
/opsx:apply               work the checklist
/opsx:archive             fold this repo's specs into openspec/specs/
```

What makes those stock commands behave like this team's workflow is the
repository's `openspec/config.yaml`: its `context`, `rules` and `operations`
guidance are injected into the default commands by `openspec instructions`, so
the agent reads the master intent first, records the backlink, and keeps to
this repository's altitude — without anyone forking a command that then drifts
from upstream OpenSpec.

Backend and frontend proceed **simultaneously**, against the contract published
in `handoff.md`. That is the point of specifying the contract precisely enough
to build against before the other side exists.

The intent's `proposal.md` rollout order says who may start immediately and who
waits for a producer to publish first.

### 5. The intent is archived, and becomes the source of truth

Once **every** repository has archived its derived change, the master intent is
archived with `openspec archive <intent-id> --store specifications`. Its specs
fold into `specifications/openspec/specs/`, which is the baseline every future
intent is written against and the first thing exploration reads.

This is gated, and the gate is not the CLI's:

```bash
scripts/intent-gate.sh <intent-id>
```

It verifies against the repositories themselves that each one named in
`handoff.md` has an **archived** change linking back. `openspec archive --yes`
only *warns* about an incomplete fan-out and proceeds — which is exactly why
the gate exists.

## Source of truth — six questions, six answers

| Question | Single source | Location |
|---|---|---|
| What does the system do **today**? | shared specs | `specifications/openspec/specs/` |
| What are we changing **next**, and why? | master intent | `specifications/openspec/changes/<id>/` |
| Which part is **mine**? | handoff | that intent's `handoff.md` |
| How does **one repo** behave? | component specs | `src/<repo>/openspec/specs/` |
| **How** is it built here? | design + tasks | `src/<repo>/openspec/changes/<id>/` |
| **Who** does it, when? | Jira | Story / Task |

Jira never holds requirement text; specs never hold assignees or sprints. The
only references crossing the boundary are `jira:` and `intent:` in
`.openspec.yaml`.

Behaviour truth is deliberately **not** fully centralised. Cross-repo contracts
live in the shared store because more than one team must agree on them.
Everything else lives next to the code it describes, so it is reviewed in the
same pull request and cannot drift.

## The two working modes

**Mode A — cross-repo authoring.** Analytics, team leads and architects work in
the `workflow` repo, with the store and every application repository checked
out side by side, so an intent spanning backend and frontend can be scoped
correctly.

**Mode B — implementation.** Developers and testers work inside **one**
application repository, with their IDE and agent rooted there. You do not need
the workflow repo or any other team's repo on disk. `--store specifications`
reaches the intent from wherever you are.

## Why a master intent, rather than a change per repo

Three problems it solves at once:

1. **Parallel work needs an agreed contract.** If backend and frontend each
   write their own proposal, the contract is agreed twice, differently. Here it
   is agreed once, before either starts.
2. **Business intent is not per-repository.** "Users can sign in with SSO" is
   one decision. Splitting it across repositories loses the thing that was
   actually decided.
3. **The story is the unit the company measures.** One story, one intent, one
   `SDD` label — see [Jira ↔ SDD](./jira-sdd-mapping.md).

And why per-repo changes still exist: technical design is repository-specific,
must be reviewed by the people who own that code, and belongs in the same pull
request as the code. A single central store holding every repository's design
stops being reviewed alongside the code and drifts within weeks.

## Where a change gets authored

| The work | Where |
|---|---|
| Another repo must change because of this | master intent in `specifications` |
| Only this repo's internals change, no observable system behaviour | a local change in that repo, no intent |

The test: **does another repository have to change its code because of this?**
If no, it is local — see [work types](./work-types.md), which has a lane for
every kind of work, not just features.

## Commands

Both CLIs, same instructions:

| | Claude Code | Qwen Code | Where |
|---|---|---|---|
| Explore current truth | `/opsx:explore` | `/opsx-explore` | stock |
| Author an intent | `/sdd:intent` | `/sdd-intent` | **custom** |
| Review an intent | `/sdd:review` | `/sdd-review` | **custom** |
| Test plan from an intent | `/sdd:tests` | `/sdd-tests` | **custom** |
| Derive a repo's change | `/opsx:propose` | `/opsx-propose` | stock |
| Implement | `/opsx:apply` | `/opsx-apply` | stock |
| Finish a repo's change | `/opsx:archive` | `/opsx-archive` | stock |
| Where is everything? | `/sdd:status` | `/sdd-status` | **custom** |
| Archive the intent | `openspec archive <id> --store specifications` | same | stock, behind `make gate` |

Four custom commands, and none of them replaces a stock one: they are the
cross-repo authoring step and the three role workflows around it. Inside an
application repository a developer uses nothing but the standard OpenSpec
commands — `/opsx:propose`, `/opsx:apply`, `/opsx:archive`, plus
`/opsx:explore`, `/opsx:sync` and `/opsx:update` when useful.

The Qwen copies are **generated** from the Claude ones by
`scripts/gen-qwen-commands.sh`. Edit `.claude/commands/sdd/`, then re-run it;
`make commands-check` fails a build if they have drifted.

## See also

- [Master intent anatomy](./master-intent.md) — what goes in each artifact
- [Work types](./work-types.md) — the lane for bugs, hotfixes, chores, spikes
- [Jira ↔ SDD](./jira-sdd-mapping.md) — sizing, branches, the metric
- [Boards](./boards.md) — the two-board split, and the dual-track sprint rhythm
- [Dashboards](./dashboards.md) — what to watch daily, and what to watch monthly
- [Roles](./roles/) — one page each
