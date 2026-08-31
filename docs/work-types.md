# Work types

🇬🇧 English | [🇷🇺 Русский](./work-types.ru.md)

Not every piece of work is a feature, and forcing all of them through the full
master-intent flow is the fastest way to get the process abandoned. This page
gives every kind of work its own lane.

## The routing question

Ask, in this order:

1. **Does another repository have to change its code because of this?**
   If yes → it needs a **master intent**. Stop here; the answer is decided.
2. **Does externally observable behaviour change?**
   If yes → it needs a spec somewhere. Master intent if the change is
   user-facing; a local component change if it is only visible at one
   repository's boundary.
3. **Neither?** → a local change, `skip_specs: true`, no intent.

Everything below is that question applied to each kind of work.

## The lanes

| Work type | Master intent? | Local change? | Specs? | Notes |
|---|---|---|---|---|
| **Feature** | yes | one per repo | yes | the full flow |
| **Improvement** | yes | one per repo | yes | same as a feature |
| **Bug** | usually no | yes | usually | spec only if the *correct* behaviour was never written down |
| **Hotfix** | no, then retro | yes | retro-spec | inverted order — see below |
| **Tech debt / refactor** | no | yes | `skip_specs: true` | behaviour must not change; that is the definition |
| **Chore** | no | yes | `skip_specs: true` | deps, config, tooling, formatting |
| **Spike** | no | no | no | time-boxed; output is a document, not code |
| **Infrastructure** | only if app behaviour changes | yes, in `gitops_*` | usually not | scaling, limits, alerts |
| **Security patch** | no | yes | only if behaviour changes | speed matters; follows the hotfix lane if urgent |
| **Dependency upgrade** | only if it forces an API change | yes | only if behaviour changes | a breaking upgrade that changes a contract needs an intent |
| **Experiment / A-B test** | yes | one per repo | yes | the flag and both branches are observable behaviour |
| **Documentation** | no | no | no | just a pull request |

### Feature and improvement

The full flow in [workflow.md](./workflow.md). Analytics writes the intent, a
team lead merges it, tester and developers work in parallel, the intent is
archived once every repository is done.

### Bug

A bug means the system does not do what it was already meant to do. Usually the
spec is already correct and only the code is wrong: fix it in the owning
repository, no intent, and reference the existing requirement in the pull
request so the reviewer can check the fix against it.

Write a spec delta **only** when the correct behaviour was never specified. Then
it is really a small improvement: the delta goes in the repository's own specs
if it is visible at that repository's boundary, or in a master intent if the
correction changes something another repository relies on.

If the bug reveals that the shared spec is *wrong* — the system does what the
spec says and the spec is the problem — that always needs an intent, because
other repositories have been built against it.

### Hotfix

Production is broken; the ordering rule is inverted deliberately.

```
1. fix, review, ship          — minimal change, branch PROJ-999-hotfix-<slug>
2. within one working day, write the retro-spec
3. if the spec was wrong or another repo relies on the changed behaviour,
   open a master intent for the proper correction
```

The retro-spec is not optional. A hotfix that never gets one leaves the shared
baseline describing behaviour the system no longer has, and the next intent
written against it inherits the error. Track it as a task on the incident, not
as a good intention.

Such a story will **fail** the ordering check in `check-sdd.sh`, and that is
correct — the spec followed the code. Report it honestly rather than
back-dating anything.

### Tech debt and refactoring

The defining property is that observable behaviour does **not** change. That is
what makes it safe, and it is also what makes it specless:

```yaml
skip_specs: true
```

If you find yourself wanting to write a spec delta, the work is not a refactor
— it is an improvement wearing a refactor's clothes, and it needs the
corresponding lane.

The existing specs are the safety net: the scenarios that passed before must
pass after, unchanged. Say so in the proposal, and make the test tasks explicit.

### Chore

Dependency bumps, CI config, formatting, tooling. Local change,
`skip_specs: true`, often no `design.md`. Do not manufacture a requirement to
satisfy validation.

Chores that change how the pipeline behaves belong in the repository that owns
the pipeline configuration, and deserve a line in the proposal about what could
break.

### Spike

A time-boxed investigation whose output is knowledge. It produces **no code
that ships** and no spec.

Give it a Jira task with an explicit time box and a written question. Its output
is a document — most usefully the `analysis.md` of the intent it feeds, since
that is exactly the shape a spike's findings take. Running `/opsx:explore` and
keeping the result *is* the deliverable.

A spike that produces code has become an experiment; re-route it.

### Infrastructure

Changes to `gitops_backend` / `gitops_frontend`: replica counts, resource
limits, probes, alerts, ingress.

No intent when the application's observable behaviour is unchanged — a local
change in the GitOps repository is enough. An intent **is** needed when the
change alters what a user or another system observes: a new public route, a
changed timeout that makes a previously-working request fail, a rate limit.

Remember that deployment is Argo CD reconciling the repository, so the change
*is* the deployment. Rollback means reverting the commit.

### Security patch

Follow the bug lane if it can wait for a normal cycle, the hotfix lane if it
cannot. The only difference is disclosure: keep the details out of the public
proposal text where the vulnerability is not yet patched everywhere, and
reference the security ticket instead.

If the patch changes a contract — a token format, an auth header, a permission
model — it needs an intent regardless of urgency, because other repositories
must change with it. Ship the hotfix first, then write the intent for the
proper fix.

### Dependency upgrade

A routine bump is a chore. An upgrade that forces an API change is different:
if the forced change alters a contract another repository consumes, it needs a
master intent, and the rollout order matters because the repositories cannot
upgrade independently.

### Experiment / A-B test

The feature flag, the control branch and the variant branch are all observable
behaviour, so this takes the full feature lane. Two things must be in the specs
that people routinely leave out: what happens when the flag service is
unavailable, and what the removal plan is.

An experiment with no written removal plan becomes permanent tech debt.

## What every lane still requires

Even the shortest lanes keep these, because they are what makes the repository
navigable a year later:

- a Jira issue, with a branch that carries its key
- a conventional commit message
- a pull request reviewed by someone who did not write it
- `openspec validate` passing, whether or not there are specs

## Choosing between an intent and a local change

The single test, restated: **does another repository have to change its code
because of this?**

- **No** → local change, in the owning repository. Never touches
  `specifications`.
- **Yes** → master intent, authored by analytics, merged before any branch.

When unsure, look at the contracts section of the last relevant `analysis.md`.
If the thing you are changing appears there with more than one consumer, it is
an intent.
