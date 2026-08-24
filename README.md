# workflow

🇬🇧 English | [🇷🇺 Русский](./README.ru.md)

Reference/starter configuration for enterprise, spec-driven development across
a multirepo application, using [OpenSpec](https://github.com/Fission-AI/OpenSpec)
and mapped onto an Agile/Scrum Jira board.

Built for **Bitbucket Data Center + Jenkins + Argo CD**. The Jenkins pipelines
live here as a shared library (`vars/`); each repo carries a five-line
`Jenkinsfile`.

**Start here: [`docs/pipeline.md`](./docs/pipeline.md)** — one diagram, six
roles, eleven gates in three phases, and the answer to "where is the source of
truth".

It covers the whole loop, not just the specs: intent → proposal → approval →
code → **version, tag, image, deploy, Jira Fix Version, deploy comment,
promotion, archive**. Everything from the merge onward is automated; a
developer's last action on a story is merging a PR.

**If you're a frontend/backend/etc. developer**, you probably don't need this
repo at all — clone your own app repo and read
[`docs/roles/developer.md`](./docs/roles/developer.md). This repo is for
authoring proposals that span multiple repos, and for pinning which combination
of repo versions ships together.

## The model in nine lines

```
1 Epic  = N stories                    a feature too big for one spec delta
1 Story = 1 OpenSpec change            = 1 spec delta   <- SDD label + change-id
1 Task  = 1 repo = 1 branch = 1 PR     = 1 tasks.md section
```

Tasks slice the *landing*, never the *spec*. The fix for a too-big story is an
Epic, not more tasks. Branches are `PROJ-123-slug`, or
`PROJ-123/PROJ-124-slug` when tasks own them — so the branch resolves to the
labelled Story *and* the Task.

## Quick start (this repo)

```bash
git clone --recurse-submodules <this-repo-url> workflow
cd workflow
make init      # submodule update + register the shared "specifications" store
make doctor    # sanity-check the OpenSpec root/store relationship
make sync      # pull the latest shared specifications
make check     # does the current checkout satisfy the SDD metric?
```

## Documentation

Read in this order the first time.

| | |
|---|---|
| [Pipeline](./docs/pipeline.md) ([RU](./docs/pipeline.ru.md)) | **start here** — gates, owners, source-of-truth map |
| [Work types](./docs/work-types.md) ([RU](./docs/work-types.ru.md)) | the lane for *every* kind of work: bug, hotfix, tech debt, chore, spike |
| [Scrum layer](./docs/scrum.md) ([RU](./docs/scrum.ru.md)) | dual-track sprints, the two boards, DoR/DoD, capacity, ceremonies |
| [Release](./docs/release.md) ([RU](./docs/release.ru.md)) | versioning, tags, images, promotion, the Jira feedback loop |
| [Automation](./docs/automation.md) ([RU](./docs/automation.ru.md)) | every trigger → action, every secret, and what humans still do |
| [Build guide](./docs/build-guide.md) ([RU](./docs/build-guide.ru.md)) | **how to construct all of this**, nine phases, step by step |
| [Jira ↔ SDD mapping](./docs/jira-sdd-mapping.md) ([RU](./docs/jira-sdd-mapping.ru.md)) | Epic/Story/Task ↔ OpenSpec, branch naming, the metric |

Role pipelines — read your own, skim the two either side of it:

| Role | | You own |
|---|---|---|
| Team lead | [EN](./docs/roles/team-lead.md) · [RU](./docs/roles/team-lead.ru.md) | sizing, labelling, sprint scope, the metric |
| Tech lead | [EN](./docs/roles/tech-lead.md) · [RU](./docs/roles/tech-lead.ru.md) | contract approval, technical approach, prod promotion |
| Analytics | [EN](./docs/roles/analytics.md) · [RU](./docs/roles/analytics.ru.md) | `proposal.md` + `specs/*.md` |
| Developer | [EN](./docs/roles/developer.md) · [RU](./docs/roles/developer.ru.md) | `design.md` + `tasks.md` + the code |
| Tester | [EN](./docs/roles/tester.md) · [RU](./docs/roles/tester.ru.md) | scenario quality, verification |
| DevOps | [EN](./docs/roles/devops.md) · [RU](./docs/roles/devops.ru.md) | the pipeline, promotion, rollback |

[`AGENTS.md`](./AGENTS.md) is the full architecture reference behind all of it.

## Layout

```
docs/               pipeline, work types, scrum, release, automation, roles
specifications/     shared spec store (submodule) — cross-cutting contracts only
src/
  common/           shared contracts/types, published as a package
  frontend/         placeholder — real remote not wired up yet
  backend/          placeholder
  gitops_frontend/  placeholder
  gitops_backend/   placeholder
  nginx/            placeholder
scripts/
  setup-openspec.sh  registers the specifications store locally (idempotent)
  add-repo.sh        promotes a src/<name> placeholder to a real submodule
  sync.sh            pulls latest specifications + reports submodule status
  check-sdd.sh       checks the "story followed SDD" metric
  release-version.sh next semver from conventional commits; tags; release notes
  jira-release.sh    creates the Jira version, stamps Fix Versions
  jira-deploy.sh     deploy comment + "Deployed Environments" field
  promote.sh         copies an image digest between Argo CD overlays
vars/                Jenkins shared library — the pipelines
  sddRelease.groovy  gate 7 — version, tag, image, Fix Version
  sddPromote.groovy  gate 10 — overlay write, Bitbucket PR for prod
  sddObserve.groovy  gate 8 — Argo health, Jira feedback, rollback
  sddPrChecks.groovy conventional PR titles, branch names, Jira key survival
examples/            thin Jenkinsfiles each repo copies in
```

Promote a placeholder once its real repo exists:

```bash
scripts/add-repo.sh frontend ssh://git@bitbucket.acme.com/plat/frontend.git
```

## The SDD metric

A story counts as "followed SDD" when it is a Story labelled `SDD`, linked to
an OpenSpec change, whose `tasks.md` sections carry Jira keys, whose branches
match the naming pattern — and **whose spec delta was merged before the first
commit on any branch**. That last condition is what separates *followed SDD*
from *labelled SDD*.

```bash
make check                                   # local root
make check-shared                            # shared store
JIRA_URL=... JIRA_TOKEN=... make check       # also assert the label via Jira
```

## The release loop

Merge a PR and nothing else is asked of you:

```
squash merge to main in Bitbucket
  -> Jenkins sddRelease
  -> version from conventional commits      backend 1.4.2 -> 1.5.0
  -> annotated tag + immutable image        backend-1.5.0
  -> Jira version "backend 1.5.0" created, Fix Version stamped on PROJ-123
  -> Argo CD repo dev overlay updated, Argo syncs
  -> 🚀 "Deployed to dev — backend 1.5.0" commented on the ticket
  -> story rolls up to Verifying, the tester is notified
  -> tester passes -> staging automatically
  -> prod: one Bitbucket pull request, one approval, one merge
  -> Jira version marked Released, story Done
```

Details in [release.md](./docs/release.md), wiring in
[automation.md](./docs/automation.md), and the order to build it in
[build-guide.md](./docs/build-guide.md).

```bash
scripts/release-version.sh --service backend --json    # what would release?
scripts/jira-release.sh --service backend --version 1.5.0 --dry-run
```

## AI commands

`/sdd:intake` · `/sdd:plan` · `/sdd:qa-review` · `/sdd:gate` — role-scoped
wrappers that enforce the sizing rule, the Jira link and the section
convention. They sit on top of the raw OpenSpec commands (`/opsx:propose`,
`/opsx:apply`, `/opsx:archive`, `/opsx:sync`, `/opsx:explore`, `/opsx:update`).
