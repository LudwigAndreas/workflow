# Workflow repo — agent & developer guide

This repo is the **analytics/architecture view** of a multirepo application:
a shared spec store plus every application repo, checked out together as git
submodules, so proposals can be authored with full cross-repo context.
Developers do **not** work out of this repo day to day — see "Two roles"
below.

## Repo map

```
specifications/        shared OpenSpec store (submodule) — cross-cutting specs only
src/
  common/               shared contracts/types, published as a package
  frontend/             \
  backend/               |  each: own local openspec/specs + openspec/changes,
  gitops_frontend/       |  plus a `references:` link to specifications/
  gitops_backend/        |
  nginx/                /
```

`src/*` are currently **placeholders** (plain directories, no remote yet).
Promote one to a real submodule with `scripts/add-repo.sh <name> <git-url>`
once the real repo exists.

## Three kinds of OpenSpec root

1. **Local repo root** (`src/<name>/openspec/`) — each app repo owns its own
   `specs/` and `changes/`, committed and reviewed as part of that repo's
   normal history. This is where repo-internal specs live: always current,
   because they're in the same commits as the code they describe. No
   registration needed — it's just the nearest `openspec/` when you're cd'd
   into that repo.
2. **Shared store** (`specifications/`) — holds **only** cross-cutting
   capabilities: contracts/interfaces more than one repo must agree on
   (the API between frontend and backend, shared events, etc). Deliberately
   kept small. Registered once per machine:
   ```bash
   openspec store register <path-to-specifications-clone> --id specifications
   ```
   Reachable from anywhere afterward via `--store specifications`, regardless
   of current directory.
3. **This workflow repo** — has no specs of its own; its
   `openspec/config.yaml` (`store: specifications`) delegates entirely to the
   shared store. Used for authoring proposals that need to read multiple real
   repos at once.

## Two roles

**Analytics / architects** work in *this* repo (Mode A): all submodules
checked out side by side, so a proposal that spans frontend + backend +
common can be scoped correctly. They author in `specifications` and never
touch `src/*` code directly.

**Developers** work inside **one single app repo** (Mode B) — clone just
`frontend`, or just `backend`, open your IDE/agent rooted there. You do not
need this workflow repo or any other team's repo present on disk. Your repo's
own `openspec/` is self-sufficient for anything local; `--store
specifications` reaches shared/cross-repo changes without leaving your repo.

## Where a change gets authored

- **Touches only this repo's internals** (nothing another repo consumes
  changes): propose and apply entirely inside the local repo —
  `openspec change propose` with no `--store` flag. Never touches
  `specifications`.
- **Touches a contract another repo consumes** (frontend+backend, or
  anything+common): the proposal (`proposal.md` + spec deltas, including the
  contract delta) is authored in `specifications` — either from this workflow
  repo (full read context across affected repos) or directly with `--store
  specifications` from a single repo. Once approved, `tasks.md` is written
  during the **Plan** step below (by a developer, not analytics) and split
  into per-repo sections (`## Common`, `## Backend`, `## Frontend`, `##
  GitOps`), gated so the contract section lands and is published *before* the
  consuming sections start. Each affected repo's own local
  `openspec/changes/` stays untouched by it — implementers reach the shared
  change via `--store specifications`, never by duplicating it locally.

## Propose vs. plan: who writes what

`openspec propose` (and the bundled `/opsx-propose` flow) generates four
artifacts by default: `proposal.md`, `specs/*.md`, `design.md`, `tasks.md`.
Analytics should only ever produce the first two:

- `proposal.md` (**why**) and `specs/*.md` (**what** — observable behavior,
  requirements, scenarios) are the business change proposal. This is
  legitimately analytics' scope — the schema's own instructions for `specs`
  explicitly say to avoid class/function names, library choices, and
  implementation steps.
- `design.md` (**how** — architecture/technical decisions) and `tasks.md`
  (the step-by-step implementation checklist, gated on `design`) require
  knowledge of the actual codebase, its patterns, and its conventions.
  Analytics doesn't have that context, so writing tasks.md themselves
  produces a plan a developer would have to rewrite anyway. These are
  authored by **the developer who will implement the change**, as
  implementation prep, immediately before running apply.

This isn't just a convention to remember — `specifications/openspec/
config.yaml` declares `rules:` for `design` and `tasks` that tell the agent
to stop after `specs` when drafting the initial proposal, and to treat
design/tasks as the implementing developer's job. It's also mechanically
safe to split this way: `openspec validate` passes on a change containing
only `proposal.md` + `specs/` (verified — `design`/`tasks` just show as
"blocked"/"ready", not errors), so analytics can open and merge a PR against
`specifications` with nothing more than the business proposal. `openspec
status --change <id> --json` reports `isComplete: false` until tasks.md
exists — that's expected and correct; it only means "not ready for apply
yet," not "invalid."

## Lifecycle

1. **Propose** (analytics, this repo): `/opsx-propose` (or `openspec new
   change <name>` + guided artifacts) against `specifications` — creates
   `proposal.md` and spec deltas (including a contract delta if cross-repo).
   Stop there — do not let it continue into `design.md`/`tasks.md` (see
   "Propose vs. plan" above). Push a branch, open a PR against
   `specifications`.
2. **Review/approve**: tech lead / product reviews the PR in
   `specifications`, with extra scrutiny on the contract delta — frontend and
   backend will build against it independently afterward. Merge to `main`.
3. **Plan** (developer, before touching code): whoever will implement the
   change creates `design.md` (if warranted — cross-cutting change, new
   dependency, migration complexity) and `tasks.md`, informed by the real
   codebase and its conventions:
   ```bash
   openspec instructions design --change <change-id> --store specifications --json
   openspec instructions tasks  --change <change-id> --store specifications --json
   ```
   For a cross-repo change, `tasks.md` is split into per-repo sections (`##
   Common`, `## Backend`, `## Frontend`, `## GitOps`), gated so the contract
   section lands and is published *before* the consuming sections start.
   Push this planning commit to `specifications` (a lightweight review here
   catches a wrong technical approach, or wrong per-repo task gating, before
   anyone starts coding).
4. **Apply — common first, if a contract is involved**: the `common`
   developer implements and publishes the contract per its `tasks.md`
   section. Ships as a versioned package release.
5. **Apply — frontend & backend in parallel**: each developer, inside their
   own single repo, pulls the new `common` package version and implements
   their `tasks.md` section. To check shared status without leaving their
   repo:
   ```bash
   openspec list --store specifications
   openspec show <change-id> --store specifications
   openspec status --change <change-id> --store specifications --json
   ```
   Their repo's `references:` entry also surfaces the contract's current spec
   summary ambiently during `apply`.
6. **Archive** (once merged/deployed): `/opsx-archive <change-id>` (or
   `openspec archive <change-id> --store specifications`) — moves the change
   to `changes/archive/` and updates `specifications/openspec/specs/*` to
   reflect new canonical truth. PR against `specifications`.

## Why `common` is a package, not a submodule of frontend/backend

Submoduling `common` into both `frontend` and `backend` would force them into
lockstep — every `common` change would require both to bump a pointer before
either could build, defeating parallel development. Instead, `common` is
versioned and published to an internal package registry; frontend and backend
depend on it as an ordinary pinned package version, upgraded independently
and deliberately on each side. `common` is still a submodule *of this
workflow repo*, for visibility while authoring proposals — just not of
frontend or backend.

## Cross-repo working views (Mode A tooling)

While authoring a proposal that spans repos, use the CLI's own composition
tools instead of manually juggling directories:

```bash
openspec workset create <name>        # compose a saved view of the affected src/* repos
openspec context --code-workspace ws.code-workspace   # combined VS Code workspace for a change
```

## Submodule update policy

- `specifications`: tracked branch, bumped often (`make sync` /
  `scripts/sync.sh`, wraps `git submodule update --remote --merge`).
- Real dev-repo submodules (once added via `scripts/add-repo.sh`): pinned to
  explicit commits, bumped deliberately via PR — this pinned combination is
  what release/gitops tooling reads, separate from what individual
  developers are doing day to day in their own repos.

## AI tool commands

Both Qwen (`.qwen/commands/opsx-*`) and Claude Code
(`.claude/commands/opsx-*`) slash commands are available in `specifications/`
and at this repo's root: `/opsx-propose`, `/opsx-apply`, `/opsx-archive`,
`/opsx-sync`, `/opsx-explore`, `/opsx-update`.
