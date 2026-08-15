# Developer workflow: from Jira ticket to production

🇬🇧 English | [🇷🇺 Русский](./developer-workflow.ru.md)

This is the day-to-day guide for **frontend, backend, common, gitops, and
nginx engineers**. You work in **Mode B**: cloned into exactly one
application repo, with your IDE/agent rooted there. You do **not** need this
`workflow` repo, and you do not need any other team's repo checked out on
disk.

If you haven't yet, read your own repo's `README.md` and the root
[`AGENTS.md`](../AGENTS.md) § "Two roles" once — this doc assumes that
model and only adds the practical, step-by-step version of it.

## One-time machine setup

Clone only your own repo — not this workflow repo:

```bash
git clone git@github.com:your-org/<frontend|backend|...>.git
cd <your-repo>
```

Register the shared `specifications` store once per machine (not per repo,
not committed to git):

```bash
git clone git@github.com:LudwigAndreas/specifications.git ~/dev/specifications
openspec store register ~/dev/specifications --id specifications
```

Verify it's visible from anywhere:

```bash
openspec store list --json
```

From now on, plain `openspec` commands (no flag) resolve to *your repo's
own* `openspec/specs` + `openspec/changes`. Adding `--store specifications`
reaches the shared cross-repo store instead, from inside your repo, without
checking out anything else.

## Two shapes of work

Every Jira ticket you pick up falls into one of two buckets. Work out which
one **before** touching OpenSpec:

| | Touches only your repo | Touches a contract another repo consumes |
|---|---|---|
| Example | Refactor internal service, fix a bug, add a repo-local feature | New/changed API between frontend and backend, a shared event, anything `common` publishes |
| Where it's proposed | Your repo, no `--store` flag | `specifications` store — authored by analytics/architecture, not you |
| Who writes `proposal.md` + `specs/*.md` | You | Analytics (see the [analytics workflow](./analytics-workflow.md)) |
| Who writes `design.md` + `tasks.md` | You | You — always, regardless of who wrote the proposal |

If a ticket turns out to need a new or changed contract and no proposal for
it exists yet in `specifications`, don't write the contract spec yourself —
ask analytics/architecture to author it first (they hold the cross-repo
context to negotiate it correctly). Jumping straight to `design.md`/`tasks.md`
against a contract that isn't agreed yet just means redoing it later.

## Lifecycle: Jira ticket → production

**1. Triage the ticket.** Decide which bucket above it falls in. For a
   contract change, check whether analytics has already proposed it:
   ```bash
   openspec list --store specifications
   ```
   If nothing matches your ticket, loop in analytics before starting.

**2. Propose** *(local-only tickets only — skip this for contract changes,
   analytics already did it)*:
   ```bash
   openspec new change <name>
   ```
   Run `/opsx-propose` (or the guided artifact flow) to generate
   `proposal.md` and `specs/*.md` for your own repo. The repo's
   `openspec/config.yaml` rules will stop the agent before `design.md`/
   `tasks.md` — that's expected, not a bug; you write those next, right
   before you implement.

**3. Plan.** Always your job, whether the proposal came from you (local) or
   from analytics (shared contract):
   ```bash
   openspec instructions design --change <id> [--store specifications] --json
   openspec instructions tasks  --change <id> [--store specifications] --json
   ```
   Use `/opsx-apply`'s sibling flow or your agent to draft `design.md` (if
   the change is complex enough to warrant one) and `tasks.md`, informed by
   your repo's actual code and conventions.

   **For a cross-repo/contract change**, split `tasks.md` into per-repo
   sections — `## Common`, `## Backend`, `## Frontend`, `## GitOps` — and
   gate it so the `## Common` section lands and its package is published
   *before* the `## Backend`/`## Frontend` sections start. Push this
   planning commit to `specifications` for a lightweight review before
   anyone writes code — it catches a wrong technical approach or wrong
   gating early.

**4. Apply.**
   - If your task depends on a `common` contract, wait for the `common`
     developer to publish the new package version first, then bump your
     dependency to it.
   - Run `/opsx-apply` (the `openspec-apply-change` skill) to work through
     `tasks.md` top to bottom with the agent. It marks each task `[x]` as
     it's completed and pauses on anything ambiguous — don't let it guess
     past unclear requirements.
   - From here, follow your repo's normal engineering process: feature
     branch, PR against **your own repo**, code review, CI, merge. This
     workflow repo doesn't prescribe that part — it's whatever your team
     already does.

**5. Deploy.** Merged code ships to production through your repo's normal
   CI/CD and the `gitops_frontend` / `gitops_backend` repos (deployment
   manifests and pipelines). Once those repos are real (see
   `scripts/add-repo.sh`), they carry their own local `openspec/` the same
   way your repo does, for any deployment-behavior specs worth capturing.

**6. Archive.** Once the change is merged and deployed:
   ```bash
   /opsx-archive <change-id>          # local-only change
   /opsx-archive <change-id> --store specifications   # shared contract
   ```
   This moves the change to `changes/archive/` and, for shared changes,
   syncs `specifications`' main `specs/*` to reflect the new canonical
   truth. **For a contract change, wait until every consuming repo
   (frontend and backend) has shipped its side** before archiving — don't
   archive the moment your own half is done.

**7. Check status any time, without leaving your repo:**
   ```bash
   openspec list   --store specifications
   openspec show   <change-id> --store specifications
   openspec status --change <change-id> --store specifications --json
   ```
   `isComplete: false` on a shared change just means `tasks.md` isn't
   written yet somewhere — not an error.

## Using AI in your day-to-day

Both Claude Code (`.claude/commands/opsx-*`) and Qwen
(`.qwen/commands/opsx-*`) expose the same slash commands — use whichever
your IDE/agent is wired to:

| Command | When to use it |
|---|---|
| `/opsx-explore` | Think through requirements or a technical approach before committing to a plan — no artifacts written yet |
| `/opsx-propose` | Start a local-only change (proposal + specs); for a shared contract, read the one analytics already proposed |
| `/opsx-update` | Revise proposal/design/tasks after a decision changes, keeping the artifacts coherent with each other |
| `/opsx-apply` | Work `tasks.md` end-to-end with the agent, one task at a time |
| `/opsx-sync` | Merge delta specs into main specs (runs automatically inside `/opsx-archive`; can be run standalone too) |
| `/opsx-archive` | Close out a finished, deployed change |

## What you must not do

- **Don't author `proposal.md`/`specs/*.md` for a cross-repo contract
  yourself.** Analytics owns that scope — loop them in instead of guessing
  at the contract.
- **Don't submodule `common` into frontend or backend.** Depend on its
  published package version and upgrade deliberately — submoduling it would
  force both sides into lockstep on every `common` change.
- **Don't let a consuming `tasks.md` section (frontend/backend) start before
  the `## Common` section has landed and published.** That gate exists so
  you're never building against an API that's still moving.
- **Don't move the `specifications` submodule pointer inside this workflow
  repo casually** — that pin is release/gitops tooling's concern, separate
  from your own repo's package-version bump.

## Troubleshooting

- `openspec doctor` — sanity-checks your OpenSpec root/store setup.
- Store not found / commands not resolving to `specifications`: re-run the
  one-time registration above — it's per-machine and isn't tracked in git,
  so a new laptop or a fresh clone needs it again.
