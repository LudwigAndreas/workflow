# workflow

🇬🇧 English | [🇷🇺 Русский](./README.ru.md)

Reference configuration for enterprise **spec-driven development** across a
multirepo application, using [OpenSpec](https://github.com/Fission-AI/OpenSpec),
mapped onto a Jira board, and driveable from **both Claude Code and Qwen Code**.

Built for **Bitbucket Data Center + Jenkins + Argo CD**.

**Start here: [`docs/workflow.md`](./docs/workflow.md)** — one diagram, five
stages, and the answer to "where is the source of truth".

## The idea in one picture

```
analytics writes ONE master intent  ──▶  team lead merges it
                                              │
                         ┌────────────────────┼────────────────────┐
                         ▼                    ▼                    ▼
                    tester writes         backend             frontend
                    tests from it         implements          implements
                         └────────────────────┴────────────────────┘
                                              │  all repos archived
                                              ▼
                              intent archived → its specs ARE the
                                                system's source of truth
```

One Jira story becomes one **master intent** in the shared `specifications`
store: what is true today, why it must change, what the system must then do,
and which repository owns which part. A team lead merges it — and that merge is
the gate: no branch may exist before it.

Then everyone works **at the same time**. The tester writes tests from the
intent's scenarios before any code exists. Each repository derives its own
OpenSpec change from the intent and runs its own `propose → apply → archive`.
Backend and frontend never coordinate directly; they build against the contract
the intent published.

When every repository has archived its work, the intent itself is archived and
its specs fold into `specifications/openspec/specs/` — the baseline the next
intent is written against.

## Quick start

```bash
git clone --recurse-submodules <this-repo-url> workflow
cd workflow
make init          # submodules + register the shared "specifications" store
make init-repos    # also wire every placeholder under src/
make status        # what is in flight
make check         # does this checkout satisfy the SDD metric?
```

**If you are a backend/frontend developer**, you probably do not need this repo
at all. Clone your own application repo and read
[`docs/roles/developer.md`](./docs/roles/developer.md). This repo is for
authoring intents that span repositories.

## Documentation

Read in this order the first time.

| | |
|---|---|
| [Workflow](./docs/workflow.md) ([RU](./docs/workflow.ru.md)) | **start here** — the five stages, source-of-truth map |
| [Master intent](./docs/master-intent.md) ([RU](./docs/master-intent.ru.md)) | what goes in each artifact, and the altitude rules |
| [Work types](./docs/work-types.md) ([RU](./docs/work-types.ru.md)) | the lane for *every* kind of work: bug, hotfix, tech debt, chore, spike |
| [Jira ↔ SDD](./docs/jira-sdd-mapping.md) ([RU](./docs/jira-sdd-mapping.ru.md)) | sizing, branch naming, and the metric |
| [Boards](./docs/boards.md) ([RU](./docs/boards.ru.md)) | two boards per team, split by track — and why not one per role |
| [Dashboards](./docs/dashboards.md) ([RU](./docs/dashboards.ru.md)) | the daily delivery board, and an optional monthly quality board |

Role pages — read your own, skim the ones either side of it:

| Role | | You own |
|---|---|---|
| Analytics | [EN](./docs/roles/analytics.md) · [RU](./docs/roles/analytics.ru.md) | the master intent |
| Team lead | [EN](./docs/roles/team-lead.md) · [RU](./docs/roles/team-lead.ru.md) | sizing, review, the merge |
| Developer | [EN](./docs/roles/developer.md) · [RU](./docs/roles/developer.ru.md) | your repo's derived change + code |
| Tester | [EN](./docs/roles/tester.md) · [RU](./docs/roles/tester.ru.md) | scenario quality, verification |

[`AGENTS.md`](./AGENTS.md) is the architecture reference behind all of it.

## Commands

Every command exists for both CLIs. Claude uses `/sdd:intent`, Qwen `/sdd-intent`.

Only four commands are custom, and none of them replaces a standard OpenSpec
one. **Developers use stock OpenSpec, unchanged.**

| Stage | Command | Who |
|---|---|---|
| understand the current system | `/opsx:explore` | analytics |
| write the master intent | **`/sdd:intent`** | analytics |
| review and approve it | **`/sdd:review`** | team lead |
| test plan, before any code | **`/sdd:tests`** | tester |
| derive this repo's change | `/opsx:propose` | developer |
| implement | `/opsx:apply` | developer |
| finish this repo's change | `/opsx:archive` | developer |
| where is everything? | **`/sdd:status`** | anyone |
| archive the intent | `make gate INTENT=<id>` then `openspec archive <id> --store specifications` | analytics |

What makes the stock commands behave like this team's workflow is each
repository's `openspec/config.yaml`: its `context`, `rules` and `operations`
guidance are injected into the default commands by the CLI. Local knowledge
travels as configuration, not as a forked command that drifts from upstream.

The Qwen copies are **generated** from the Claude ones — edit
`.claude/commands/sdd/`, then run `make commands`. `make commands-check` fails
a build if they have drifted.

## Layout

```
docs/                    workflow, master intent, work types, Jira mapping, roles
specifications/          submodule — the shared store; business source of truth
  openspec/specs/          how the system behaves today
  openspec/changes/        master intents in flight
  openspec/schemas/        the master-intent workflow definition
src/
  backend/               each: own openspec specs + changes, own .claude/.qwen
  frontend/
  gitops_backend/
  gitops_frontend/
templates/repo-kit/      what scripts/setup-repo.sh installs into a repo
scripts/
  setup-openspec.sh        register the store; check out submodules
  setup-repo.sh            install the SDD kit into an application repo
  intent-status.sh         where every intent has got to, read from the repos
  intent-gate.sh           the hard gate before archiving an intent
  check-sdd.sh             the "story followed SDD" metric
  sync.sh                  pull the latest shared specifications
  gen-qwen-commands.sh     regenerate the Qwen commands from the Claude ones
```

## The SDD metric

A story counts as "followed SDD" when it carries the `SDD` label and a branch
names its key. Satisfying that mechanically takes a little more, and
`check-sdd.sh` asserts all of it — including the one condition that cannot be
faked: **the intent was merged before the first commit on any branch**.

```bash
make check
JIRA_URL=... JIRA_TOKEN=... make check   # also assert the label via Jira
```

Without the Jira variables the label checks are *skipped, not passed*, and the
script says so.

## The archive gate

`openspec archive --yes` only **warns** when a fan-out is incomplete, and a
checkbox is just a character someone typed. So archiving a master intent goes
through a gate that reads the repositories themselves:

```bash
make gate INTENT=<intent-id>
```

It fails if any repository named in the intent's Fan-out checklist has not
archived a change
linking back to the intent, and it names the specific lie when a checkbox
claims more than reality.

## Adding a repository

```bash
scripts/setup-repo.sh <name> [path]
```

Installs the stock `opsx` commands for both CLIs, a rendered
`openspec/config.yaml` carrying this team's context and rules, and the agent
guides. No custom schema and no custom command: the repository uses the default
`spec-driven` workflow. Point it at any path to set up a developer's own clone
— the normal case in daily use.
