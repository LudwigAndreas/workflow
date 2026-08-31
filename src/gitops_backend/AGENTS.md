# gitops_backend — spec-driven workflow

`gitops_backend` is Argo CD desired state for the backend, one repository of a multirepo application.

**You work in this repository alone.** You do not need any other team's repo
checked out, and you do not need the `workflow` superproject. Everything you
need is here, plus the shared specification store, which you reach with a flag.

## Where truth lives

| Question | Source |
|---|---|
| Why are we building this, and what must be true for the business? | the **master intent** in the `specifications` store |
| What does the outside world require — APIs, UI, data? | that intent's **System context** |
| Which repositories take part? | that intent's **Repositories** table |
| What does `gitops_backend` build about it? | **you decide**, in this change's `proposal.md` |
| How does **this** repo behave today? | `openspec/specs/` |
| Who does it, and when? | Jira |

The master intent is written by analytics and approved by a team lead **before**
any branch is cut here. It is a meta layer that sits *before* propose: it gives
you the business need and the whole-system context, and you decide what this
repository does about it. Every artifact of your change — proposal, specs,
design, tasks — is yours.

Read an intent without leaving this repo:

```bash
openspec list --store specifications
openspec show <intent-id> --store specifications --json
```

## The loop — the standard OpenSpec commands, nothing custom

```bash
git checkout -b PROJ-123/PROJ-124-<slug>   # only after the intent is merged
```

```
/opsx:propose   proposal.md + specs/ + design.md + tasks.md for THIS repo
/opsx:apply     work the checklist
                ... review, merge, deploy, verify ...
/opsx:archive   fold this repo's specs into openspec/specs/
```

Qwen Code: `/opsx-propose`, `/opsx-apply`, `/opsx-archive`.

There is no repo-local `/sdd:*` command and no custom schema here, on purpose.
Everything this team needs on top of the standard workflow — read the intent
first, record the backlink, keep to this repository's altitude — lives in
`openspec/config.yaml` as `context`, `rules` and `operations` guidance, which
the CLI injects into those default commands. Read it once; it is short.

Give the intent to `/opsx:propose` as its input, e.g. *"propose this repo's
change from the master intent `add-sso-login`"*, and it will read the intent
from the store before writing anything.

## Working in parallel

Other repositories are implementing their half of the same intent right now,
against the business rules and the external contracts it publishes. That is
what makes this fast, and it is also the constraint:

- **A shared contract cannot be changed here.** If you cannot meet it as
  published — wrong shape, missing field, impossible ordering — stop and raise
  it against the intent. Do not implement something different; the other side
  is building against the document, and the mismatch surfaces at integration.
- **Check what has to land first.** The intent says whether you may start now
  or are waiting on another repository to publish something.
- **Say when your side is available.** If someone is blocked on you, your
  `design.md` records when they can start.

## Altitude — what belongs where

| Artifact | Holds | Written by |
|---|---|---|
| `intent.md` | business need, whole-system context, who takes part | analytics |
| intent `specs/` | the **business rules** — what a user or another organisation observes | analytics |
| `proposal.md` | what **this repo** does about it | you |
| this repo's `specs/` | behaviour at **this repo's** boundary | you |
| `design.md` | how — classes, libraries, schemas, layout | you |
| `tasks.md` | the checklist | you |

Test: if another repository would have to change because a requirement changed,
it belongs in the intent. If this repo could be rewritten in another language
and the requirement would still hold, it belongs in this repo's specs.

`design.md` is the first place implementation detail is allowed — and the only
place. Nothing upstream of it names a class or a library.

## Jira and the SDD metric

```
1 Story = 1 master intent           <- carries the SDD label
1 Task  = 1 repo = 1 branch = 1 PR  <- yours
```

Branch: `<STORY-KEY>/<TASK-KEY>-<slug>`, e.g. `PROJ-123/PROJ-124-sso-endpoint`.

Record both links in `openspec/changes/<intent-id>/.openspec.yaml`:

```yaml
schema: spec-driven
jira: PROJ-124              # this repo's Task
intent: <intent-id>         # the master intent
intent_store: specifications
```

Without them your work is invisible to the fan-out and blocks the intent's
archive.

**The intent must be merged before you cut a branch.** The metric records
whether the spec landed before the first commit, and that is not fixable
afterwards.

## CI/CD

Bitbucket Data Center + Jenkins + Argo CD. There is no GitHub here: no Actions,
no `gh` CLI, no CODEOWNERS. Pull requests go through the Bitbucket REST API, and
merge control is Bitbucket branch permissions plus required builds.

Deployment goes through the Argo CD repositories: a pipeline writes an image
reference and Argo rolls it out. Nothing applies manifests directly, so
**rollback means reverting an image reference** — any schema change must stay
compatible with the previously deployed image for as long as rollback is
possible.
