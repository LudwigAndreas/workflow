# Workflow repo — agent & architecture guide

This repo is the **cross-repo authoring view** of a multirepo application: the
shared specification store plus every application repository, checked out
together, so an intent can be authored with full cross-repo context.

Developers do **not** work here day to day — see "Two working modes".

**Start here:** [`docs/workflow.md`](./docs/workflow.md).

## Repo map

```
docs/
  workflow.md            the whole flow: five stages, source-of-truth map
  master-intent.md       what goes in each artifact, altitude rules
  work-types.md          the lane for every kind of work, not just features
  jira-sdd-mapping.md    Epic/Story/Task ↔ OpenSpec, branches, the metric
  boards.md              two boards per team, split by track; sprint rhythm
  dashboards.md          the daily delivery board + optional monthly quality board
  roles/                 analytics, team-lead, developer, tester
specifications/          submodule — the shared store (see below)
src/
  backend/ frontend/     each: own openspec specs + changes + .claude/.qwen
  gitops_backend/ gitops_frontend/
templates/repo-kit/      what setup-repo.sh installs into an application repo
scripts/                 setup, fan-out status, the archive gate, the metric
.claude/ .qwen/          commands and skills for both CLIs
```

Every document has a Russian twin, `<name>.ru.md`, cross-linked at the top with
flag links. A new document is not finished until both exist and both are in the
README tables.

## Three OpenSpec roots

1. **The shared store** (`specifications/`) — the business source of truth.
   `openspec/specs/` is how the system behaves today; `openspec/changes/` holds
   master intents in flight. Registered once per machine:
   ```bash
   openspec store register <path-to-specifications> --id specifications
   ```
   Reachable from anywhere afterwards via `--store specifications`.
2. **Each application repo** (`src/<name>/openspec/`) — its own `specs/` and
   `changes/`, committed and reviewed with that repo's code. No registration
   needed; it is just the nearest `openspec/` when you are cd'd into it.
3. **This repo** — has no specs of its own. Its `openspec/config.yaml` sets
   `store: specifications` and delegates entirely.

## One custom schema, one custom step

The only thing this workflow adds to stock OpenSpec is the **master intent**,
and it is added in exactly one place.

**`master-intent`** (in `specifications/openspec/schemas/`) —
`analysis → proposal → specs → handoff`. It is the store's default schema, so
`openspec new change <id> --store specifications` scaffolds an intent. Its
`apply` block tracks `handoff.md`, so the fan-out checklist *is* the intent's
completion state. The store's config declares `rules` for `design` and `tasks`
that tell the agent to **stop** and explain rather than create them.

**The application repositories have no custom schema at all.** They use the
stock `spec-driven` workflow — `proposal → specs → design → tasks` — driven by
the stock `/opsx:propose`, `/opsx:apply` and `/opsx:archive`. Everything this
team adds on top of it lives in `openspec/config.yaml` as `context`, `rules`
and `operations` guidance, which the CLI injects into those default commands
through `openspec instructions`. That is deliberate: a developer learns the
standard workflow, and the local knowledge travels as configuration rather than
as a forked command that has to be kept in sync with upstream.

Check what a repository actually injects:

```bash
(cd src/backend && openspec instructions proposal --change <id> --json)
```

Validate the schema — the `schema` command is experimental and **does not
accept `--store`**, so it runs from inside the root that owns it:

```bash
(cd specifications && openspec schema validate master-intent)
make schemas
```

Commands that *do* take `--store` — `new change`, `status`, `instructions`,
`list`, `show`, `validate`, `archive`, `doctor`, `context`, `view` — resolve the
schema through the store correctly, so `openspec new change <id> --store
specifications` works from anywhere.

## The links that hold it together

```yaml
# specifications/openspec/changes/<intent-id>/.openspec.yaml
schema: master-intent
jira: PROJ-123              # the Story

# src/<repo>/openspec/changes/<intent-id>/.openspec.yaml
schema: spec-driven
jira: PROJ-124              # this repo's Task
intent: <intent-id>         # ← the backlink the fan-out reads
intent_store: specifications
```

`scripts/intent-status.sh` and `scripts/intent-gate.sh` discover derived
changes by scanning `src/*/openspec/changes/**/.openspec.yaml` for a matching
`intent:`. A change without that key is invisible to the fan-out.

## Why the archive gate is a script, not the CLI

`openspec archive --yes` prints `Warning: N incomplete task(s) found. Continuing
due to --yes flag.` and archives anyway. A checkbox is also just a character
someone typed. So `scripts/intent-gate.sh` verifies against the **repositories
themselves** that each one named in `handoff.md` has an archived change linking
back, and refuses otherwise. It also detects three specific inconsistencies:

- work archived but the box not ticked
- a box ticked while the change is still open
- a box ticked with no derived change at all

`--tick` ticks only what it has verified. Never hand-edit `handoff.md`.

## Commands: what is custom and what is not

Four `/sdd:*` commands exist, and none of them shadows an OpenSpec verb:

| Command | Role | Why it is not stock |
|---|---|---|
| `/sdd:intent` | analytics | authors a change that spans four repositories, with the Epic/Story sizing rule and the Jira link the metric needs |
| `/sdd:review` | team lead | the approval gate before any branch is cut |
| `/sdd:tests` | tester | derives a test plan from an intent before code exists |
| `/sdd:status` | anyone | fan-out state across every repository, and the metric |

Everything else is stock: `/opsx:explore` before the intent, and
`/opsx:propose` → `/opsx:apply` → `/opsx:archive` inside each repository after
it. Archiving the intent itself is `openspec archive <id> --store
specifications`, behind `make gate INTENT=<id>`; the store's `operations.archive`
guidance carries the procedure.

`.claude/commands/sdd/*.md` is the **source**. `.qwen/commands/sdd-*.md` is
generated from it by `scripts/gen-qwen-commands.sh`, which reduces the
frontmatter to `description` and rewrites `/sdd:x` → `/sdd-x` and
`/opsx:x` → `/opsx-x`.

Edit the Claude copy, then `make commands`. `make commands-check` fails if they
have drifted — wire it into a pull-request build.

The `opsx` commands and skills in both directories come from `openspec init
--tools claude,qwen` and are not hand-maintained.

## Two working modes

**Mode A — cross-repo authoring.** Analytics and team leads work here, with
everything checked out side by side, and author in `specifications`. They never
touch `src/*` code.

**Mode B — implementation.** Developers and testers work inside **one**
application repo, agent rooted there. That repo's `openspec/` is self-sufficient;
`--store specifications` reaches the intent without leaving it.

## Working rules

- **`openspec init` refuses to run when `store:` is set** in `openspec/config.yaml`.
  To reinstall commands here, temporarily replace the config with
  `schema: spec-driven`, run init, then restore it. `setup-repo.sh` avoids the
  problem by initialising before writing the config.
- **Local knowledge goes in `openspec/config.yaml`, not in a new command.** If
  an application repository needs the agent to know something, add it to
  `context`, `rules` or `operations` guidance in
  `templates/repo-kit/openspec/config.yaml.tmpl` and re-run `setup-repo.sh`.
  Forking a schema or adding a repo-local `/sdd:*` command puts the team on a
  workflow that drifts from upstream OpenSpec — that was tried and removed.
- **Scripts are bash 3.2 compatible** — no associative arrays, no `mapfile` —
  so they run on a stock macOS laptop and a Linux Jenkins agent alike.
  Dependencies are limited to `git`, `sed`, `grep`, `awk`, and `jq` only where
  JSON is genuinely involved. `bash -n` every script after editing.
- **`yaml_get` in `scripts/lib/common.sh` is not a YAML parser.** It is only
  ever pointed at `.openspec.yaml`, which is flat by construction. Do not reach
  for it elsewhere.
- **CI/CD is Bitbucket Data Center + Jenkins + Argo CD.** There is no GitHub
  here: no Actions, no `gh` CLI, no CODEOWNERS. Pull requests go through the
  Bitbucket REST API; merge control is Bitbucket branch permissions plus
  required builds. Deployment always goes through the Argo CD repositories — a
  pipeline writes an image reference and Argo rolls it out.
- **Verify links after editing docs.** Pages cross-reference each other,
  including Cyrillic anchors. Broken anchors are silent.

## Silent failure modes worth knowing

| What | Consequence |
|---|---|
| `### Scenario:` instead of `####` | parses as nothing; the requirement looks scenario-less |
| new capability delta without `## Purpose` | archive leaves a `TBD` placeholder in the permanent spec |
| partial copy of a `MODIFIED` requirement | archive silently deletes the omitted scenarios |
| repo change missing `intent:` | invisible to the fan-out; blocks the intent's archive |
| `openspec init` re-run in a repo | overwrites `.claude/`, not `openspec/config.yaml` — the local rules survive |
| branch cut before the intent merged | the metric fails, and it is not fixable afterwards |

## Submodule policy

`specifications` tracks its branch and is bumped often (`make sync`) — it is the
baseline everyone authors against, so a stale copy means writing intents against
behaviour that has already changed.

Application-repo submodules, once real, are pinned to explicit commits and
bumped deliberately by pull request; that pinned combination is what release
tooling reads, separate from what developers do day to day.
