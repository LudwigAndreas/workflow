# Workflow repo — agent & developer guide

This repo is the **cross-repo authoring view** of a multirepo application: a
shared spec store plus every application repo, checked out together as git
submodules, so proposals can be authored with full cross-repo context.
Developers do **not** work out of this repo day to day — see "Two working
modes" below.

**Start here:** [`docs/pipeline.md`](./docs/pipeline.md) — one diagram, six
roles, eleven gates in three phases. Everything below is the reference detail
behind it.

## Repo map

```
docs/
  pipeline.md            the whole flow: gates, owners, source-of-truth map
  work-types.md          the lane for every kind of work, not just features
  scrum.md               dual-track sprints, boards, DoR/DoD, ceremonies
  release.md             versioning, tagging, promotion, the Jira feedback loop
  automation.md          every trigger -> action, and what humans still do
  build-guide.md         how to construct all of this, phase by phase
  jira-sdd-mapping.md    Epic/Story/Task <-> OpenSpec, branch naming, the metric
  roles/                 one page per role
specifications/          shared OpenSpec store (submodule) — cross-cutting specs only
src/
  common/                shared contracts/types, published as a package
  frontend/              \
  backend/                |  each: own local openspec/specs + openspec/changes,
  gitops_frontend/        |  plus a `references:` link to specifications/
  gitops_backend/         |
  nginx/                 /
scripts/
  setup-openspec.sh      registers the specifications store locally (idempotent)
  add-repo.sh            promotes a src/<name> placeholder to a real submodule
  sync.sh                pulls latest specifications + reports submodule status
  check-sdd.sh           checks the "story followed SDD" metric
  release-version.sh     next semver from conventional commits; tags; notes
  jira-release.sh        creates the Jira version, stamps Fix Versions
  jira-deploy.sh         deployment comment + Deployed Environments field
  promote.sh             copies an image digest between GitOps overlays
  lib/jira.sh            shared Jira REST helpers (Cloud and Server/DC)
  lib/bitbucket.sh       Bitbucket Data Center REST helpers
vars/                    Jenkins shared library - the pipelines themselves
  sddRelease.groovy      gate 7: version, tag, image, Fix Version
  sddPromote.groovy      gate 10 + the write half of 8: overlay, Bitbucket PR
  sddObserve.groovy      gate 8: Argo health, Jira feedback, rollback
  sddPrChecks.groovy     conventional PR titles, branch names, key survival
  sddScripts.groovy      puts scripts/ on the agent for the pipelines
examples/                thin Jenkinsfiles each repo copies in
  Jenkinsfile.app        application repos
  Jenkinsfile.gitops     the Argo CD repo, observe job
  Jenkinsfile.promote    the Argo CD repo, promote job
```

CI/CD is **Bitbucket Data Center + Jenkins + Argo CD**. This repo doubles as
the Jenkins shared library: `vars/` is at the root because that is where
Jenkins looks. Jenkins also adds `src/` to the library classpath and finds no
Groovy there, which is harmless - `src/` remains the application-repo
placeholders.

`src/*` are currently **placeholders** (plain directories, no remote yet).
Promote one with `scripts/add-repo.sh <name> <git-url>` once the real repo
exists.

## Source of truth

Six questions, six answers, no duplication.

| Question | Single source | Location |
|---|---|---|
| What does the system do **today**? | main specs | `<repo>/openspec/specs/`, `specifications/openspec/specs/` |
| What are we changing **next**, and why? | proposal + spec deltas | `openspec/changes/<change-id>/` |
| **How** will we build it? | design + tasks | same change dir |
| **Who** does it, when, in which sprint? | Jira | Epic / Story / Task |
| What is **actually built**? | code | the application repos |
| What is **actually running**, where? | GitOps + tags | `gitops_*` overlays, `<service>-<semver>` tags |

Jira never holds requirement text; specs never hold assignees or sprints. The
only reference crossing the boundary is `.openspec.yaml: jira: PROJ-123` ↔ the
Story's `change-id`.

Behavior truth is deliberately **not** centralised. Specs live next to the code
they describe so they're reviewed in the same commits; a single store holding
every repo's specs stops being reviewed alongside the code and drifts within
weeks. Only genuinely cross-cutting contracts go in the shared store.

## Jira mapping (the short version)

```
1 Epic  = N stories                    a feature too big for one spec delta
1 Story = 1 OpenSpec change            = 1 spec delta   <- SDD label + change-id here
1 Task  = 1 repo = 1 branch = 1 PR     = 1 "## N. <Repo> (KEY)" section of tasks.md
```

**Tasks slice the landing, never the spec.** A story's tasks are its repo
slices. The fix for a too-big story is an Epic, not more tasks. Full rules,
branch naming and the metric definition:
[`docs/jira-sdd-mapping.md`](./docs/jira-sdd-mapping.md).

## Three kinds of OpenSpec root

1. **Local repo root** (`src/<name>/openspec/`) — each app repo owns its own
   `specs/` and `changes/`, committed and reviewed as part of that repo's
   history. No registration needed — it's just the nearest `openspec/` when
   you're cd'd into that repo.
2. **Shared store** (`specifications/`) — holds **only** cross-cutting
   capabilities: contracts more than one repo must agree on. Deliberately
   small. Registered once per machine:
   ```bash
   openspec store register <path-to-specifications-clone> --id specifications
   ```
   Reachable from anywhere afterward via `--store specifications`.
3. **This workflow repo** — has no specs of its own; its `openspec/config.yaml`
   (`store: specifications`) delegates entirely to the shared store.

## Two working modes

**Mode A — cross-repo authoring.** Analytics, architects and tech leads work in
*this* repo, all submodules checked out side by side, so a proposal spanning
frontend + backend + common can be scoped correctly. They author in
`specifications` and never touch `src/*` code.

**Mode B — implementation.** Developers and testers work inside **one single
app repo**, IDE/agent rooted there. You do not need this workflow repo or any
other team's repo on disk. Your repo's own `openspec/` is self-sufficient for
local work; `--store specifications` reaches shared changes without leaving it.

## Where a change gets authored

- **Touches only this repo's internals** → propose and apply entirely inside
  the local repo, no `--store` flag. Never touches `specifications`.
- **Touches a contract another repo consumes** → `proposal.md` + spec deltas
  are authored in `specifications`, by analytics. Once approved, `tasks.md` is
  written by a developer at gate 5 and split into per-repo sections gated so
  the contract section lands and publishes *before* the consuming sections
  start. Each affected repo's own `openspec/changes/` stays untouched —
  implementers reach the shared change via `--store specifications`, never by
  duplicating it locally.

The test: **does another repo have to change its code because of this?** If no,
it's local.

## Propose vs. plan: who writes what

`openspec propose` generates four artifacts by default. Analytics produces only
the first two.

- `proposal.md` (**why**) and `specs/*.md` (**what** — observable behavior) are
  the business change proposal. Legitimately analytics' scope; the schema's own
  instructions for `specs` say to avoid class/function names, library choices
  and implementation steps.
- `design.md` (**how**) and `tasks.md` (the step-by-step checklist) require
  knowledge of the actual codebase and its conventions. Written by **the
  developer who will implement the change**, as implementation prep.

This is enforced, not just conventional: `openspec/config.yaml` in each repo
and in `specifications` declares `rules:` for `design` and `tasks` telling the
agent to stop after `specs` when drafting an initial proposal. It's also
mechanically safe — `openspec validate` passes on a change containing only
`proposal.md` + `specs/` (`design`/`tasks` show as "blocked"/"ready", not
errors), so analytics can merge a PR with nothing more than the business
proposal. `openspec status --change <id> --json` reports `isComplete: false`
until `tasks.md` exists; that means "not ready for apply yet," not "invalid."

## Lifecycle

The eleven gates, their owners, and their pass conditions are in
[`docs/pipeline.md`](./docs/pipeline.md). In brief — **shape** (1–4), **build**
(5–6), **ship** (7–11):

1. **Intake** (team lead) — route the work to its
   [lane](./docs/work-types.md), size the story per the rule, label `SDD`,
   reserve a `change-id`, create per-repo tasks.
2. **Propose** (analytics) — `/sdd:intake`: `proposal.md` + spec deltas. Stop
   before design/tasks. PR against the right root.
3. **Scenario review** (tester) — `/sdd:qa-review`: harden WHEN/THEN, add the
   unhappy paths.
4. **Approve** (tech lead) — extra scrutiny on the contract delta. Merge to
   `main`. **No branch may exist before this merge.**
5. **Plan** (developer) — `/sdd:plan`: `design.md` (if warranted) + `tasks.md`
   with one Jira-keyed section per repo, contract section gated first.
6. **Apply** (developer) — contract/`common` section first and published, then
   frontend and backend in parallel. `/opsx:apply`. Squash-merge.
7. **Release** (⚙ automated) — version from conventional commits, tag, image,
   release notes, Jira Fix Version stamped.
8. **Deploy to dev** (⚙ automated) — GitOps overlay updated, Argo syncs, the
   ticket comments itself and the card moves.
9. **Verify** (tester) — every scenario exercised against the **deployed dev
   environment**; one card move to `Ready to release`.
10. **Promote** (⚙ to staging, tech lead to prod) — the verified digest is
    copied between overlays. The approval is about *when*, not *what*.
11. **Archive** (analytics or last dev) — once **all** consuming repos are in
    production: `/opsx:archive <id> --store specifications`.

Gates 7, 8 and the staging half of 10 involve no human at all. See
[`docs/release.md`](./docs/release.md) and
[`docs/automation.md`](./docs/automation.md).

Not every lane uses every gate: bugs and refactors skip 2–4, hotfixes invert
the order and owe a retro-spec, chores skip almost everything. The rules are in
[`docs/work-types.md`](./docs/work-types.md).

## Checking the metric

```bash
make check           # this root
make check-shared    # the shared specifications store
```

`scripts/check-sdd.sh` asserts the `jira:` link, `openspec validate`, Jira keys
on every `tasks.md` section, the branch naming pattern, and that the proposal
was merged before the branch was cut. Export `JIRA_URL` and `JIRA_TOKEN` to
also assert the `SDD` label and issue type. It runs on every pull request via
`sddPrChecks` - see [`examples/Jenkinsfile.app`](./examples/Jenkinsfile.app).

## The Scrum layer

Gate 4 forbids a branch before the spec is merged, which plain one-track Scrum
cannot satisfy. The fix is **dual-track**: discovery (gates 1–4) runs one sprint
ahead of delivery (gates 5–11), so by the time a developer starts, the spec has
been merged for a week. Boards, DoR/DoD, estimation, capacity and ceremonies:
[`docs/scrum.md`](./docs/scrum.md).

## Release

Trunk-based, release on merge, per-service semver derived from conventional
commits, build once and promote the digest. `main` merge → Jenkins `sddRelease`
→ tag `<service>-<semver>` → image → Jira Fix Version `<service> <semver>` →
Argo CD repo → dev → verify → staging → prod on one merged Bitbucket pull
request. Every step is in
[`docs/release.md`](./docs/release.md); every trigger and secret is in
[`docs/automation.md`](./docs/automation.md); the order to build it in is
[`docs/build-guide.md`](./docs/build-guide.md).

## Why `common` is a package, not a submodule of frontend/backend

Submoduling `common` into both would force them into lockstep — every `common`
change would require both to bump a pointer before either could build,
defeating parallel development. Instead `common` is versioned and published to
an internal registry; frontend and backend depend on a pinned version and
upgrade independently. `common` is a submodule *of this workflow repo* only,
for read context while authoring proposals.

## Cross-repo working views (Mode A tooling)

```bash
openspec workset create <name>                        # saved view of the affected src/* repos
openspec context --code-workspace ws.code-workspace   # combined VS Code workspace
```

## Submodule update policy

- `specifications`: tracked branch, bumped often (`make sync`).
- Real dev-repo submodules: pinned to explicit commits, bumped deliberately via
  PR — this pinned combination is what release/gitops tooling reads, separate
  from what individual developers do day to day.

## Building this from scratch

Nine phases, roughly two weeks of setup plus one sprint of adoption, in
[`docs/build-guide.md`](./docs/build-guide.md). Two rules about order: build
the feedback loop (phases 1–7) **before** changing how people work (phase 8),
and pilot with one service and one squad before rolling out.

## AI tool commands

Role-scoped SDD commands (this repo, `.claude/commands/sdd/`):
`/sdd:intake`, `/sdd:plan`, `/sdd:qa-review`, `/sdd:gate`.

Underlying OpenSpec commands, available here and in `specifications/` for both
Claude Code and Qwen: `/opsx:propose`, `/opsx:apply`, `/opsx:archive`,
`/opsx:sync`, `/opsx:explore`, `/opsx:update`.
