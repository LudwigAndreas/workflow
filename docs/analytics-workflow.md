# Analytics / architecture workflow: from Jira ticket to a merged contract

🇬🇧 English | [🇷🇺 Русский](./analytics-workflow.ru.md)

This is the day-to-day guide for **analysts, architects, and product/business
proposal authors** working across a multirepo application. You work in
**Mode A**: cloned into *this* `workflow` repo, with every application repo
checked out as a submodule side by side, so you can scope a change that
spans several repos with full context. You **never** touch `src/*` code
directly — that's the implementing developer's job.

Read the root [`AGENTS.md`](../AGENTS.md) once first, especially § "Where a
change gets authored" and § "Propose vs. plan: who writes what" — this doc
is the practical walkthrough of that model.

## One-time setup

```bash
git clone --recurse-submodules <this-repo-url> workflow
cd workflow
make init      # submodule update + register the shared "specifications" store locally
make doctor    # sanity-check the OpenSpec root/store relationship
```

Before starting any new work, pull the latest shared specs:

```bash
make sync      # pulls specifications to latest, reports submodule status
```

## What belongs in `specifications` — and what doesn't

The shared store holds **only cross-cutting capabilities**: contracts more
than one repo must agree on (the API between frontend and backend, shared
events, anything `common` publishes). It's kept deliberately small.

If a Jira ticket turns out to be single-repo (nothing another repo consumes
changes), it's **not yours to propose** — hand it directly to that repo's
developer. They'll propose and apply it entirely inside their own repo; you
have no role in that path at all.

## Lifecycle: Jira ticket → merged, ready-to-plan contract

**1. Triage the ticket.** Confirm it actually introduces or changes
   something more than one repo must agree on. Pull the affected repos into
   one working view instead of juggling directories manually:
   ```bash
   openspec workset create <name>                       # saved view of the affected src/* repos
   openspec context --code-workspace ws.code-workspace   # combined VS Code workspace for the change
   ```

**2. Propose.** From this workflow repo (full cross-repo read context):
   ```bash
   openspec new change <name>
   ```
   Run `/opsx-propose` against `specifications`. It generates `proposal.md`
   (why) and `specs/*.md` (what — the observable contract delta).
   **Stop there.** Do not let it continue into `design.md` or `tasks.md`.

   This isn't just a convention — `specifications/openspec/config.yaml`
   declares `rules:` for `design` and `tasks` that tell any agent working
   here to stop after `specs` during initial proposal drafting. The reason
   is practical, not bureaucratic: you don't have the target codebase's
   patterns and conventions in front of you, so a `design.md`/`tasks.md`
   draft from you would just get rewritten by the implementing developer
   anyway. `proposal.md` + `specs/*.md` — the *why* and the observable
   *what* — is legitimately your scope; the schema's own instructions for
   `specs` explicitly say to avoid class/function names, library choices,
   and implementation steps.

**3. Open a PR.** Push a branch, open a PR against the `specifications`
   repo.

**4. Review and approve.** Tech lead / product reviews the PR, with extra
   scrutiny on the contract delta specifically — frontend and backend will
   each build against it independently afterward, so any ambiguity here
   becomes two teams solving the same problem two different ways. Merge to
   `main`.

**5. Hand off.** Tell the affected repos' developers the change is ready to
   plan. From here, **they** write `design.md` and `tasks.md` — see the
   [developer workflow](./developer-workflow.md) § "Plan". You don't
   write those, and you don't need to chase them; they can discover the
   change themselves:
   ```bash
   openspec instructions design --change <id> --store specifications --json
   openspec instructions tasks  --change <id> --store specifications --json
   ```

**6. Track progress**, from this repo, without waiting on status updates:
   ```bash
   openspec list   --store specifications
   openspec show   <change-id> --store specifications
   openspec status --change <change-id> --store specifications --json
   ```
   `isComplete: false` is **expected** until a developer adds `tasks.md` —
   that only means "not ready for apply yet," not that anything is wrong.

**7. Archive**, once every consuming repo has merged and deployed its side:
   ```bash
   /opsx-archive <change-id> --store specifications
   ```
   This moves the change to `changes/archive/` and runs `/opsx-sync`
   (agent-driven intelligent merge) to update `specifications/openspec/
   specs/*` to the new canonical truth — the point future proposals build
   on. This step is often triggered by whichever developer finishes last,
   but you can drive it too; either way, confirm **all** sides have shipped
   first, not just one.

## Confirming a proposal is mergeable with only two artifacts

`openspec validate` passes on a change containing just `proposal.md` +
`specs/` — `design`/`tasks` show as `"blocked"`/`"ready"`, not errors. That
means you can safely open and merge a PR against `specifications` with
nothing more than the business proposal; there's no need to wait for or
fake a `design.md`/`tasks.md` to get it merged.

## Using AI in your day-to-day

Both Claude Code (`.claude/commands/opsx-*`) and Qwen
(`.qwen/commands/opsx-*`) expose the same slash commands from this repo's
root:

| Command | When to use it |
|---|---|
| `/opsx-explore` | Think out loud with the agent while scoping a ticket — no artifacts written yet, safe to use before you're sure of anything |
| `/opsx-propose` | Generate `proposal.md` + the contract `specs/*.md` delta from a description; let it stop before `design`/`tasks` |
| `/opsx-update` | Revise the proposal/specs after review feedback, keeping `proposal.md` and `specs/*.md` internally coherent |
| `/opsx-sync` | Merge delta specs into main specs — runs automatically inside `/opsx-archive`, or standalone if you want main specs to reflect an in-flight change early |

## What you must not do

- **Don't write `design.md` or `tasks.md`**, even when you're confident you
  know the right technical approach — it's explicitly the implementing
  developer's call, and `specifications/openspec/config.yaml`'s rules
  instruct any agent here to stop before those artifacts.
- **Don't touch `src/*` code directly.** Your output is `proposal.md` +
  `specs/*.md`; everything after that is a developer's job.
- **Don't put repo-internal (non-contract) specs into `specifications`.**
  Keep the shared store small — repo-local concerns belong in that repo's
  own `openspec/specs/`, not here.
- **Don't archive a shared change until every consuming repo has shipped.**
  Archiving early updates the canonical spec before the contract is
  actually true everywhere.

## Cheat sheet

```bash
# setup (once)
make init && make doctor

# before starting new work
make sync

# scope a cross-repo change
openspec workset create <name>
openspec context --code-workspace ws.code-workspace

# propose (stop after specs)
openspec new change <name>
/opsx-propose

# track
openspec list   --store specifications
openspec show   <change-id> --store specifications
openspec status --change <change-id> --store specifications --json

# close out (after all sides ship)
/opsx-archive <change-id> --store specifications
```
