# Jira ↔ SDD mapping

🇬🇧 English | [🇷🇺 Русский](./jira-sdd-mapping.ru.md)

This is the contract between our Jira board and our OpenSpec artifacts. It
exists to answer three questions that used to have no answer: what is a story
in SDD terms, what gets a branch, and when do you split.

It is also what makes the company's **"story followed SDD"** metric passable
by construction rather than by memory — see [The metric](#the-metric) below.

## The conflation to avoid

Two different things get confused constantly:

- A **spec delta** (one OpenSpec change: `proposal.md` + `specs/*.md`) is a
  unit of *agreed behavior*.
- A **branch / PR** is a unit of *code landing in one repo*.

They have different natural sizes. One user-facing feature is one behavior
decision but touches two or three repos, so it is two or three branches.
`1 story = 1 branch` can never hold, and forcing it is exactly what makes the
metric feel unfollowable. Don't force it. Make the **story the spec unit** and
the **task the branch unit**.

## The invariant

```
1 Epic  = N stories                    a feature too big for one spec delta
1 Story = 1 OpenSpec change            = 1 spec delta = 1 review decision
1 Task  = 1 repo = 1 branch = 1 PR     = 1 "## N. <Repo> (KEY)" section of tasks.md
```

The `SDD` label and the `change-id` live on the **Story**. Always. A task never
carries its own spec delta, and a story never has more than one.

**Tasks slice the landing, never the spec.** A story's tasks are its repo
slices — Common, Backend, Frontend, GitOps, QA — not "part 1, part 2, part 3"
of the same work.

## The sizing rule

Apply one test at triage, before anything is written:

> **Can `proposal.md` + `specs/*.md` for this be reviewed and approved as a
> single decision?**

| Answer | Shape | Who owns the branch |
|---|---|---|
| Yes, and it touches one repo | Story with **no children** | the Story |
| Yes, but it touches several repos | Story + one Task per affected repo | each Task |
| No — it is several independent capability changes | **Epic**, split into Stories, each with its own OpenSpec change | each Story or its Tasks |

The third row is the important one. **The fix for a too-big story is an Epic,
not more tasks under it.** Once tasks are only ever repo slices, a story is
always followable, because its task count equals its affected-repo count and
nothing else. If you find yourself writing "Task 4: second half of the backend
work", you have hit the third row and should have split the story.

### Worked example — cross-repo

```
Epic  PROJ-100  "Single sign-on"
 └─ Story PROJ-123  [SDD]  change-id: add-sso-login      <- 1 OpenSpec change
     ├─ Task PROJ-124  common    branch PROJ-123/PROJ-124-common-sso-types
     ├─ Task PROJ-125  backend   branch PROJ-123/PROJ-125-backend-sso-endpoint
     ├─ Task PROJ-126  frontend  branch PROJ-123/PROJ-126-frontend-sso-button
     └─ Task PROJ-127  qa        (no branch — verifies scenarios)
```

### Worked example — single repo

```
Story PROJ-140  [SDD]  change-id: fix-session-expiry     <- 1 OpenSpec change
   branch PROJ-140-fix-session-expiry
   (no tasks — one repo, so the story owns the branch directly)
```

## Branch naming

```
single-repo story:   PROJ-123-sso-login
multi-repo story:    PROJ-123/PROJ-124-backend-sso-endpoint
```

The multi-repo form carries **both keys** deliberately. Jira resolves issue
keys found anywhere in a branch name, so the branch links to the labelled Story
*and* to the Task. That means the metric passes whether or not your Jira rolls
child-task branches up onto the parent story.

> **Verify this once against the real Jira.** If the development panel already
> rolls child branches up to the parent story, you can drop the `PROJ-123/`
> prefix and use plain `PROJ-124-backend-sso-endpoint`. Keep the prefix until
> someone has actually confirmed the rollup.

Enforced pattern:

```
^([A-Z][A-Z0-9]+-[0-9]+/)?[A-Z][A-Z0-9]+-[0-9]+-[a-z0-9-]+$
```

## Linking the two systems

Exactly one pair of references crosses the boundary. Nothing else is
duplicated.

**In OpenSpec** — `openspec/changes/<change-id>/.openspec.yaml`:

```yaml
schema: spec-driven
created: 2026-08-21
jira: PROJ-123
```

**In Jira** — the Story records `change-id: add-sso-login`, either in a custom
field or on its own line in the description.

That is the whole integration. Jira never holds requirement text; specs never
hold assignees or sprint numbers.

## tasks.md section convention

The OpenSpec `tasks.md` template uses numbered groups. Our convention adds the
repo name and the Jira task key to each group heading:

```markdown
## 1. Common (PROJ-124)

- [ ] 1.1 Add `SsoAssertion` type and export it
- [ ] 1.2 Publish package version 2.4.0

## 2. Backend (PROJ-125)

<!-- gated: do not start until 1.2 has published -->
- [ ] 2.1 Bump common to 2.4.0
- [ ] 2.2 Implement POST /auth/sso callback

## 3. Frontend (PROJ-126)

<!-- gated: do not start until 1.2 has published -->
- [ ] 3.1 Bump common to 2.4.0
- [ ] 3.2 Add SSO button and redirect handling
```

Two things follow from this. `openspec status --change <id>` and the Jira story
now report the same progress numbers, because each section is a Jira task. And
CI can mechanically assert the mapping — that is what `scripts/check-sdd.sh`
does.

### Contract gating

When a change touches `common` or any shared contract, the
`## Common` section must land and publish before the consuming sections start.
Mark the gate in a comment as shown above so it survives review.

## The metric

The company measures **"story followed SDD"**: the story carries the `SDD`
label and has a branch named after its key, satisfiable by the story itself or
by tasks inside it.

A story passes when all of the following hold. `scripts/check-sdd.sh` checks
every item except the first two, and those two as well when `JIRA_URL` and
`JIRA_TOKEN` are available.

1. The Jira issue is of type **Story**.
2. It carries the label **`SDD`**.
3. It records a `change-id`, and that change exists.
4. The change's `.openspec.yaml` carries the matching `jira:` key.
5. `openspec validate <change-id>` passes.
6. Every `tasks.md` section heading carries a Jira task key.
7. Every such task key has a branch matching the pattern above.
8. **The spec delta was merged before the first commit on any branch.**

Item 8 is what separates *followed SDD* from *labelled SDD*. If the proposal
lands after the code, the metric is measuring nothing. Mechanically: the commit
that added `proposal.md` must be reachable from `origin/main` at the moment the
feature branch is created.

## Stories with no spec delta

Pure refactors, tooling, dependency bumps and docs changes have no observable
behavior change, so they have no spec delta. They must not invent a requirement
just to satisfy validation. Set the escape hatch in the change's
`.openspec.yaml`:

```yaml
schema: spec-driven
created: 2026-08-21
jira: PROJ-150
skip_specs: true
```

The story still carries the `SDD` label, still gets a `change-id`, still gets a
`tasks.md` with Jira-keyed sections, and still passes the check. It simply has
`proposal.md` without `specs/`.

## Where the change lives

The Jira mapping is identical either way; only the OpenSpec root differs.

| The story… | Change is authored in | Reached with |
|---|---|---|
| touches only one repo's internals | that repo's `openspec/changes/` | no flag |
| touches a contract another repo consumes | the shared `specifications` store | `--store specifications` |

See [`AGENTS.md`](../AGENTS.md) § "Where a change gets authored" for the full
rule and the reasoning behind keeping the shared store small.

## Quick reference

```bash
# what changes are in flight, and how far along
openspec list --json
openspec list --store specifications

# one change in detail
openspec show <change-id>
openspec status --change <change-id> --json

# does this repo pass the SDD metric right now
make check
```
