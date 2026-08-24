# DevOps / platform

🇬🇧 English | [🇷🇺 Русский](./devops.ru.md)

You own the machinery that turns a merged PR into verified production, and the
Jira feedback that makes it visible. You work in **Mode B** — inside the
`gitops_*` and application repos, one at a time.

Read [the pipeline](../pipeline.md) and [release](../release.md) once first.
You own **gates 7 and 8**, and you build the machinery for gate 10.

## What you own

- The release pipeline: version computation, tagging, image build, release
  notes.
- The GitOps repos: overlays, Argo applications, sync and health definitions.
- The Jira feedback loop: Fix Versions, deployment comments, the
  `Deployed Environments` field.
- Rollback: that it works, that it is rehearsed, that anyone on call can run it.
- The pipeline's own reliability — which is a product, with users, who are your
  team.

You do **not** own the decision to promote to production. That is
[the tech lead's gate 10](./tech-lead.md#gate-10--approving-a-production-promotion).
You own the fact that it takes one click and is reversible.

## The measure of the job

> **A developer's last action on a story is merging a PR.** A tester's is
> moving one card. A tech lead's is one approval.

Anything else anybody has to do — chase a build, edit a version, ask where a
change is, run a deploy command — is work for you, on the pipeline.

Two numbers say whether you are winning:

| Number | Target | Why it matters |
|---|---|---|
| merge → running in `dev` | **< 15 min** | past that, developers test on laptops and the loop dies |
| deploys per developer per week that needed a human step | **0** | any nonzero value is a manual step you have not automated yet |

## Gates 7 and 8 — the automated half

Both are workflows, not activities. Your job is that they are true.

| Gate | Pipeline | What it must guarantee |
|---|---|---|
| 7 Release | [`sddRelease`](../../vars/sddRelease.groovy) | one merge → one version, one tag, one immutable image, Fix Versions stamped |
| 8 Deploy | [`sddPromote`](../../vars/sddPromote.groovy) + [`sddObserve`](../../vars/sddObserve.groovy) | the overlay is written, Argo is healthy, the ticket says so |
| — PR gate | [`sddPrChecks`](../../vars/sddPrChecks.groovy) | conventional titles, branch names, the SDD metric, a Bitbucket build status |

**This repo is the Jenkins shared library.** `vars/` is the library; each
application and Argo CD repo carries a five-line `Jenkinsfile` from
[`examples/`](../../examples). A pipeline fix is one commit here — which is the
whole reason for the shared-library layout, and why you should resist anyone
pasting a pipeline into a single repo "just this once".

The scripts underneath are deliberately plain bash so they can be run by hand
when a pipeline is down:

```bash
scripts/release-version.sh --service backend --json     # what would the version be?
scripts/release-version.sh --service backend --notes    # what would the notes say?
scripts/jira-release.sh --service backend --version 1.5.0 --dry-run
scripts/jira-deploy.sh  --service backend --version 1.5.0 --env dev --dry-run
scripts/promote.sh --service backend --from staging --to prod --pr
```

**Every one of them supports `--dry-run` or a read-only mode. Use it.** These
scripts write to Jira, and a script that writes to a hundred tickets wrongly is
an afternoon of cleanup.

## Non-negotiables

These are the design decisions that make the rest work. They will each be
questioned; the answers are in [release.md](../release.md).

1. **Build once, promote the digest.** Never rebuild between environments. A
   rebuild means the thing you verified is not the thing you shipped.
2. **Overlays pin digests, not tags.** A tag can be moved. "What is running in
   prod" must have exactly one answer.
3. **`main` only, squash merges only.** Both are load-bearing: version
   computation and Fix Version extraction both read the commit range.
4. **Git is the deployment truth.** No `kubectl apply` from a laptop, ever, by
   anyone, including you at 3am. If the pipeline can't do it, fix the pipeline —
   that outage is exactly when the fix gets prioritised.
5. **Health means serving, not started.** A readiness probe returning 200 while
   the workload cannot serve makes automatic rollback both useless and
   frightening.
6. **The Jira bot is a bot.** Automation running as a person breaks when they
   leave and attributes every comment to them.

## Rollback

Your responsibility is that it is boring.

| Situation | What happens | Who |
|---|---|---|
| health check fails inside the window | overlay commit reverted automatically | pipeline |
| bad behavior found minutes later | `scripts/promote.sh --to prod --digest <previous>` | anyone on call |
| data already written in a new shape | roll **forward** with a hotfix | tech lead |

**Rehearse it quarterly, in working hours, with the team watching.** A rollback
path nobody has exercised does not exist — you will discover that at the worst
possible moment.

The migration rule that keeps rollback possible: **expand, migrate, contract.**
Every schema change is backward-compatible for at least one release. Renaming a
column in place is what converts a two-minute rollback into a four-hour
incident.

## Owning the pipeline as a product

- **A broken automation is an incident, not a chore.** If the board stops
  reflecting reality for a day, people start keeping status in their heads and
  in Slack, and winning that back costs far more than the fix.
- **Publish the failure modes.**
  [The troubleshooting table](../automation.md#when-automation-breaks) is yours
  to keep accurate; every new failure mode you debug belongs in it.
- **Version and share the workflows.** They live in this repo and are copied
  into each app repo. When you change one, change it here and open the PRs.
- **Keep the setup reproducible.** Everything the pipeline needs is in
  [the configuration inventory](../automation.md#configuration-inventory). A
  variable that exists only in one repo's settings and in your memory is an
  outage waiting for your holiday.

## Commands

```bash
make check                                   # SDD metric, local root
make check-shared                            # SDD metric, shared store

scripts/release-version.sh --service <s>     # what would release?
scripts/promote.sh --service <s> --from dev --to staging
scripts/promote.sh --service <s> --from staging --to prod --pr

openspec list --store specifications         # what contracts are in flight
```

## What you must not do

- **Don't deploy outside GitOps.** Not once, not as an exception. The exception
  becomes the habit and then git stops being the truth.
- **Don't let anyone bypass branch protection**, including admins. A bypass is
  used exactly once and then permanently.
- **Don't add environments.** Three is enough to promote; a fourth is
  maintained by nobody and diverges within a month.
- **Don't make the pipeline clever.** Every conditional is a thing that
  surprises someone at 3am. Boring beats optimal.
- **Don't own the promotion decision.** Build the button; let the tech lead
  press it, so the accountability sits with the person who owns the risk.
