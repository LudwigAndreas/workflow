# Developer

🇬🇧 English | [🇷🇺 Русский](./developer.ru.md)

For frontend, backend, common, gitops and nginx engineers. You work in **Mode
B**: cloned into exactly one application repo, IDE and agent rooted there. You
do **not** need this `workflow` repo, and you do not need any other team's repo
checked out on disk.

Read [the pipeline](../pipeline.md) and [Jira ↔ SDD mapping](../jira-sdd-mapping.md)
once first. You own **gates 5 and 6**.

## What you own

`design.md` (**how**), `tasks.md` (the step-by-step plan), and the code. You
write `design.md` and `tasks.md` **always** — whether the proposal came from you
(local change) or from analytics (shared contract).

## One-time machine setup

Clone only your own repo:

```bash
git clone ssh://git@bitbucket.acme.com/plat/<frontend|backend|...>.git
cd <your-repo>
```

Register the shared `specifications` store once per machine — not per repo, and
not tracked in git, so a new laptop needs it again:

```bash
git clone git@github.com:LudwigAndreas/specifications.git ~/dev/specifications
openspec store register ~/dev/specifications --id specifications
openspec store list --json      # verify
```

From now on, plain `openspec` commands resolve to *your repo's own*
`openspec/specs` + `openspec/changes`. Adding `--store specifications` reaches
the shared store from inside your repo without checking out anything else.

## Two shapes of work

Work out which one **before** touching OpenSpec.

| | Touches only your repo | Touches a contract another repo consumes |
|---|---|---|
| Example | internal refactor, bug fix, repo-local feature | new/changed API between FE and BE, a shared event, anything `common` publishes |
| Proposed in | your repo, no `--store` flag | `specifications` — authored by analytics, not you |
| Who writes `proposal.md` + `specs/*.md` | you | analytics |
| Who writes `design.md` + `tasks.md` | **you** | **you** |

If your story needs a contract that nobody has proposed yet, don't write the
contract spec yourself — ask analytics. They hold the cross-repo context needed
to negotiate it correctly, and planning against an unagreed contract just means
redoing the work.

## Gate 5 — plan

Your story's spec delta is already merged (gate 4). Now:

```bash
openspec instructions design --change <id> [--store specifications] --json
openspec instructions tasks  --change <id> [--store specifications] --json
```

Or just run `/sdd:plan <change-id>`, which wraps both and enforces the section
convention.

**`design.md`** — write it when the change is cross-cutting, adds a dependency,
involves a migration, or has a non-obvious approach. Skip it for a small local
change; don't manufacture ceremony.

**`tasks.md`** — one numbered section per affected repo, each carrying its Jira
task key:

```markdown
## 1. Common (PROJ-124)

- [ ] 1.1 Add `SsoAssertion` type and export it
- [ ] 1.2 Publish package version 2.4.0

## 2. Backend (PROJ-125)

<!-- gated: do not start until 1.2 has published -->
- [ ] 2.1 Bump common to 2.4.0
- [ ] 2.2 Implement POST /auth/sso callback
```

The Jira key in the heading is not decoration — `scripts/check-sdd.sh` asserts
it, and it's what makes the story's Jira progress and `openspec status` agree.

Push the planning commit and have the tech lead look at it before you start
coding. A wrong approach caught here costs an hour; caught at PR review it
costs a sprint.

## Gate 6 — apply

**Branch naming** — this is part of the metric, not a style preference:

```
single-repo story (no tasks):   PROJ-140-fix-session-expiry
multi-repo story (your task):   PROJ-123/PROJ-125-backend-sso-endpoint
```

Both keys in the multi-repo form, so the branch links to the Story *and* your
Task.

Then:

- If your task depends on a `common` contract, **wait for it to publish**, then
  bump your dependency. Don't start against unpublished code — that's what the
  gate comment in `tasks.md` means.
- Run `/opsx-apply` to work `tasks.md` top to bottom with the agent. It marks
  each task `[x]` as it completes and pauses on anything ambiguous. Don't let it
  guess past unclear requirements — an ambiguous spec is a gate-3 failure worth
  reporting, not something to improvise around.
- Feature branch → PR against **your own repo** → review → CI → **squash
  merge**. The PR title is a conventional commit — `feat(auth): add SSO
  callback` — because it becomes the only commit on `main`, and the release
  pipeline reads it.

Run `make check` before opening the PR to confirm you'll pass the metric.

## Gate 9 handoff

The tester verifies every scenario in `specs/*.md` against the **deployed dev
environment**, not against your branch — and Jira tells them it is ready
without anyone asking. If a
scenario can't be exercised, that's a real finding — either the code doesn't
match the spec or the spec was wrong. Both are worth knowing before archive.

## After the merge — gates 7–11

**Merging your PR is your last action on the story.** Everything after it is
automated; see [release.md](../release.md).

| Gate | What happens | You |
|---|---|---|
| 7 | version computed, tag + image built, Jira Fix Version stamped | nothing |
| 8 | GitOps rolls `dev`, the ticket comments itself | nothing |
| 9 | tester verifies against `dev` | answer questions |
| 10 | staging automatically; prod on the tech lead's approval | nothing |
| 11 | archive | below |

The one thing this puts on you: **your commit type decides the version.**
`fix:` is a patch, `feat:` a minor, `feat!:` a major that every consumer must
react to. There is no later place to correct it — a wrong type ships a version
number that lies.

Once the change is running **in production** in every affected repo:

```bash
/opsx:archive <change-id>                          # local-only change
/opsx:archive <change-id> --store specifications   # shared contract
```

**For a contract change, wait until every consuming repo is in production**
before archiving — not the moment your own half is merged.

## Status, without leaving your repo

```bash
openspec list   --store specifications
openspec show   <change-id> --store specifications
openspec status --change <change-id> --store specifications --json
```

## Commands

| Command | When |
|---|---|
| `/opsx-explore` | think through requirements or an approach before committing |
| `/sdd:intake` | start a local-only change (proposal + specs) |
| `/sdd:plan` | write `design.md` + `tasks.md` with Jira-keyed sections |
| `/opsx-apply` | work `tasks.md` end-to-end, one task at a time |
| `/sdd:gate` | check metric readiness before opening a PR |
| `/opsx-archive` | close out a shipped change |

## What you must not do

- **Don't author `proposal.md`/`specs/*.md` for a cross-repo contract.** Loop in
  analytics rather than guessing at the contract.
- **Don't start a branch before the spec delta is merged.** It fails the metric
  and can't be fixed afterwards.
- **Don't submodule `common` into frontend or backend.** Depend on its published
  package version; submoduling forces both sides into lockstep.
- **Don't start a consuming section before `## Common` has published.**
- **Don't move the `specifications` submodule pointer in the workflow repo
  casually** — that pin is release tooling's concern.

## Troubleshooting

- `openspec doctor` — sanity-checks your OpenSpec root/store setup.
- Store not found: re-run the one-time registration. It's per-machine and isn't
  tracked in git.
- `make check` fails on branch pattern: rename the branch; see
  [Jira ↔ SDD mapping](../jira-sdd-mapping.md#branch-naming).
