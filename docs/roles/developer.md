# Developer

🇬🇧 English | [🇷🇺 Русский](./developer.ru.md)

You own your repository's **derived change**: `proposal.md`, `specs/`,
`design.md`, `tasks.md`, and the code.

**You work in one repository.** You do not need the `workflow` superproject or
any other team's repo checked out. Your repo's own `openspec/` is
self-sufficient, and `--store specifications` reaches the intent from wherever
you are.

## Your loop — the standard OpenSpec commands

There is nothing custom on your side of this workflow. No forked schema, no
repo-local `/sdd:*` command: you use stock OpenSpec, and what makes it fit this
team is your repository's `openspec/config.yaml`.

```
git checkout -b PROJ-123/PROJ-124-<slug>   only after the intent is merged
/opsx:propose             proposal.md + specs/ + design.md + tasks.md,
                          recording jira: + intent: in .openspec.yaml
/opsx:apply               work the checklist
                          → review, merge, deploy, verify
/opsx:archive             fold your specs into this repo's openspec/specs/
```

Qwen Code: `/opsx-propose`, `/opsx-apply`, `/opsx-archive`.

Start `/opsx:propose` by naming the intent — *"derive this repo's change from
`add-sso-login`"* — and it will read the intent from the store first, because
`openspec/config.yaml` tells it to. That config carries this team's rules into
the default commands: read the intent, record the backlink, keep to this
repository's altitude, remember that rollback is an image revert. It is worth
reading once, and it is short.

Your board is `Team <name> — Delivery` (Scrum), swimlaned by parent story so you
can see which other repositories are still outstanding on the same intent. Your
card is a Task; the Story above it belongs to the Discovery board. See
[boards](../boards.md).

## Start by reading the intent — all of it

```bash
openspec list --store specifications
openspec show <intent-id> --store specifications --json
```

In this order:

1. **`handoff.md`**, your repository's section — what you own, the contract you
   must produce or consume, what you depend on, how acceptance is judged. The
   most important thing you will read.
2. **`specs/`** — the requirements you implement. Your acceptance is these
   scenarios, not your reading of the ticket.
3. **`proposal.md`**, the **Rollout order** — may you start now, or are you
   waiting on a producer?
4. **`analysis.md`** — why the system is as it is. Usually where the constraint
   that makes the obvious approach wrong is recorded.

Do not skip this because someone described the ticket in standup.

## You are working in parallel

Another repository is implementing its half **right now**, against the contract
published in `handoff.md`. That is what makes this fast, and it is the
constraint that comes with it:

- **You cannot change a shared contract locally.** If you cannot meet it as
  published — wrong shape, missing field, impossible ordering, conflicts with
  something deployed — **stop and raise it against the intent**. It is
  corrected in the store, once, for everyone. Implementing something different
  surfaces as an integration failure days later, and the other team will have
  built the published version.
- **Say when your side is available.** If someone is blocked on you, record it
  in `design.md` under Contract conformance. They are waiting on that date.
- **Build against the contract, not against the other repo's code.** You should
  be able to finish before it exists. If you cannot, the contract is
  underspecified — that is a finding, raise it.

## Altitude — what goes where

| Artifact | Holds |
|---|---|
| intent `specs/` | system-boundary behaviour, cross-repo contracts (not yours) |
| your `specs/` | behaviour at **your repo's** boundary |
| `design.md` | how — classes, libraries, schemas, file layout |
| `tasks.md` | the checklist |

Test for your component specs: if another repository would have to change
because a requirement changed, it belongs in the intent, not here. If your repo
could be rewritten in another language and the requirement would still hold, it
belongs here.

Having **no** component specs is legitimate — set `skip_specs: true` rather
than inventing a requirement to satisfy validation.

`design.md` is the first place implementation detail is allowed, and the only
place. Skip it entirely for a trivial change and say why in one line; writing
one anyway trains everyone to stop reading them.

## The links that must be recorded

In `openspec/changes/<intent-id>/.openspec.yaml`, before you write anything
else:

```yaml
schema: spec-driven
jira: PROJ-124              # THIS repo's Task, not the Story
intent: <intent-id>         # the master intent
intent_store: specifications
```

Without them your work is invisible to the fan-out and blocks the intent's
archive.

Branch: `<STORY-KEY>/<TASK-KEY>-<slug>`, e.g.
`PROJ-123/PROJ-124-sso-token-endpoint`. It resolves to the labelled story *and*
your task, which is what the metric needs.

**The intent must be merged before you cut the branch.** The metric records the
ordering and it is not fixable afterwards.

## Tasks and tests

The intent's scenarios and your own component scenarios **are** the test cases.
A `tasks.md` with no test tasks does not satisfy the intent's Acceptance
section — and the tester is already writing against those same scenarios, so
you will find out.

Put work blocked on another repository in its own group, naming the blocker in
the heading, so it is obvious why it is not started:

```markdown
## 4. Blocked on backend publishing the token endpoint
```

## Deployment and rollback

Deployment is Argo CD reconciling the GitOps repository: a pipeline writes an
image reference and Argo rolls it out. Nothing applies manifests directly.

**Rollback means reverting an image reference.** Any schema change must stay
compatible with the previously deployed image for as long as rollback is
possible. Say in `design.md` how long that window is — this is the detail most
often missed, and it is the one that makes a rollback impossible at 2am.

## Finishing

`/opsx:archive` archives your change into your repo's `openspec/specs/`. It does
**not** archive the master intent — that happens once every repository is done,
and is gated separately.

Before you archive, check the intent's Acceptance criteria are genuinely met —
the scenarios pass against a deployed environment, not just that the code was
written. An unmet requirement here becomes a false tick on the fan-out, and the
intent gets archived describing behaviour that does not exist.

Never edit the intent's `handoff.md` by hand. Ticking is done by
`scripts/intent-gate.sh --tick`, which only ticks what it verified.

## Common mistakes

| Mistake | Consequence |
|---|---|
| starting before the intent merged | the story cannot count toward the metric |
| reinterpreting a contract locally | integration failure; the other team built the published version |
| copying the intent's business case into your proposal | two copies that drift |
| putting system-level behaviour in your component specs | duplicated truth, two places to update |
| `tasks.md` with no test tasks | acceptance not satisfied; the tester finds out |
| archiving unmerged work | archives something nobody else can see |
