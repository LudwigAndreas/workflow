# Build guide

🇬🇧 English | [🇷🇺 Русский](./build-guide.ru.md)

How to construct this workflow from nothing, in the order that keeps the team
working the whole time. Nine phases, roughly **two weeks of setup plus one
sprint of adoption**.

## Before you start

**Two rules about sequencing, both learned the expensive way.**

**Build the feedback loop before the ceremony.** Phases 1–7 are plumbing:
nobody's daily habits change, and at the end the board moves by itself. Only
then (phase 8) do you change how people work. Teams that introduce the process
first and the automation later spend three months doing by hand what a script
should do, decide the process is heavy, and abandon it. That is the single most
common way this fails.

**Pilot with one service and one squad.** Not the most critical service and not
the least — pick one with real traffic and a team that will tell you when it is
annoying. Roll out to the rest after the pilot has run one full sprint end to
end.

| Phase | What you get | Effort | Blocking? |
|---|---|---|---|
| [0](#phase-0--decide) | decisions written down | 2 h | yes |
| [1](#phase-1--repos-and-specs) | specs live next to code | 1 d | yes |
| [2](#phase-2--jira) | issue types, fields, statuses, boards | 1 d | yes |
| [3](#phase-3--pr-hygiene) | conventional PRs, SDD check in CI | 4 h | yes |
| [4](#phase-4--release-on-merge) | versions, tags, images, no human input | 1 d | yes |
| [5](#phase-5--gitops-and-the-dev-environment) | merge → running in dev in 15 min | 2 d | yes |
| [6](#phase-6--the-jira-feedback-loop) | Fix Versions, deploy comments | 4 h | no |
| [7](#phase-7--promotion-and-rollback) | staging, prod approval, rollback | 1 d | no |
| [8](#phase-8--the-scrum-layer) | dual-track sprints, the gates | 1 sprint | no |
| [9](#phase-9--metrics) | DORA + SDD adherence | 4 h | no |

Phases 6–9 are marked non-blocking because the pipeline works without them —
but 6 is where the workflow becomes visible to people who never open Jenkins,
which is most of the value, so do not stop at 5.

---

## Phase 0 — Decide

Two hours in a room with the team lead, tech lead and one developer. Write the
answers down in this repo; every later phase reads them.

| Decision | Our default | Why |
|---|---|---|
| Jira project key | one key for the product, e.g. `PROJ` | one board, cross-repo stories stay legible |
| Services | one per deployable, `backend` `frontend` `common` `nginx` | the version line is per service |
| Environments | `dev` `staging` `prod` | fewer is not enough to promote; more is not maintained |
| Branching | trunk-based, `main` only | [release on merge](./release.md#principles) needs it |
| Merge strategy | **squash only** | one commit, one changelog entry, reliable key extraction |
| Versioning | semver per service from conventional commits | no hand-edited version files |
| Sprint length | 2 weeks | one refinement, one planning, one review |
| Capacity split | 60 feature / 20 debt / 20 interrupt | [why](./scrum.md#capacity-and-the-20-rule) |
| Spec store | per-repo, plus a small shared one | [why](../AGENTS.md#source-of-truth) |
| Who holds each role | names, not job titles | a gate with no name is a gate nobody passes |

**Done when:** each row has an answer and a name against it, committed to this
repo. Not "we agreed" — written down. Half of these get relitigated in month
two, and the written answer is what ends the argument in a minute.

---

## Phase 1 — Repos and specs

**Goal:** every repo owns its specs; a small shared store holds cross-repo
contracts.

1. Create the shared spec store and register it once per machine:

   ```bash
   # create the repo in Bitbucket first (Projects -> your project -> Create repository)
   git clone ssh://git@bitbucket.acme.com/plat/specifications.git ~/dev/specifications
   cd ~/dev/specifications && openspec init
   openspec store register ~/dev/specifications --id specifications
   openspec store list --json     # verify
   ```

2. In **each** application repo:

   ```bash
   cd <app-repo>
   openspec init
   ```

   Then copy the `references:` and `rules:` blocks from
   [`src/backend/openspec/config.yaml`](../src/backend/openspec/config.yaml)
   into its `openspec/config.yaml`. The `rules:` blocks are what stop an agent
   generating `design.md` and `tasks.md` during a business proposal — see
   [propose vs. plan](../AGENTS.md#propose-vs-plan-who-writes-what).

3. Wire this workflow repo's submodules so proposal authors get cross-repo
   context:

   ```bash
   scripts/add-repo.sh backend  ssh://git@bitbucket.acme.com/plat/backend.git
   scripts/add-repo.sh frontend ssh://git@bitbucket.acme.com/plat/frontend.git
   make init && make doctor
   ```

4. **Seed the main specs.** Do not try to document the existing system. Write
   specs only for capabilities as you change them — the first story that
   touches checkout writes the checkout spec. A big-bang spec-writing project
   produces a document nobody reads and that is wrong within a month.

**Done when:** `openspec list` works from inside an app repo with no flags, and
`openspec list --store specifications` works from anywhere.

**Skip it and:** specs centralise, drift from the code within weeks, and the
whole model collapses into a wiki.

---

## Phase 2 — Jira

**Goal:** the board can represent the pipeline.

1. **Issue types:** Epic, Story, Task, Bug, Spike, Incident. Nothing else.
2. **Custom fields** — [exactly four](./automation.md#jira-custom-fields-to-create):
   `Change ID`, `Deployed Environments`, `Severity`, `Timebox`.
3. **Labels:** `SDD` (the metric), `feature-flag`, `tech-debt`.
4. **Statuses**, in workflow order:
   `Intake → Specifying → Scenario review → Spec approval → Ready → In progress
   → In review → Deployed to dev → Verifying → Ready to release → Done`.
5. **Two boards** over the same project — see
   [the Scrum layer](./scrum.md#the-two-boards):
   - *Discovery*, filtered to `status in (Intake, Specifying, "Scenario review",
     "Spec approval", Ready)`.
   - *Delivery*, filtered to `status in (Ready, "In progress", ...)`, swimlanes
     by Epic.
6. **Link Jira to Bitbucket.** Create an **Application Link** between the two
   (Jira → Settings → Applications → Application links), then enable the
   **DVCS accounts** sync for the project. This is what makes branch and pull
   request events move cards at all — without it, rules 1–3 never fire and you
   are back to dragging cards by hand.
7. **Create the bot account** and its API token. Grant it: transition issues,
   edit issues, add comments, manage versions. Nothing more.

**Done when:** pushing a branch named `PROJ-1-test` moves `PROJ-1` to
`In progress` on its own.

**Skip it and:** everything downstream still works, but people maintain status
by hand, so it is wrong by Thursday and the board stops being believed.

---

## Phase 3 — PR hygiene

**Goal:** the inputs the release pipeline reads are guaranteed well-formed.

1. Repo settings → **allow squash merging only**. Turn off merge commits and
   rebase merging. This is not a style preference: with merge commits, the
   tag-range key scan picks up work-in-progress messages and Fix Versions land
   on the wrong issues.
2. Set the squash commit message default to **"Pull request title and
   description"**.
3. Add the `Jenkinsfile` from
   [`examples/Jenkinsfile.app`](../examples/Jenkinsfile.app) to the repo and
   point a **Multibranch Pipeline** job at it. On a pull request it runs
   `sddPrChecks`; on `main` it runs `sddRelease` (phase 4).

4. **Branch permissions** on `main` (Repository settings → Branch permissions):
   *Prevent changes without a pull request*, one approver, no direct pushes —
   **including for admins**. An admin bypass is used exactly once at 2am and
   then permanently.

5. **Merge checks** (Repository settings → Merge checks): require the
   `sdd-pr-checks` build status to be green. `sddPrChecks` posts that status
   through the Bitbucket build-status API, which is how Jenkins gates a merge
   without GitHub-style required checks.

**Done when:** a pull request titled `wip` fails, and one titled
`feat(auth): add SSO callback` on branch `PROJ-2-sso` passes with the key
appended to its **description** automatically, and Bitbucket shows the
`sdd-pr-checks` build as required and green.

**Skip it and:** phase 4 produces wrong versions and wrong Fix Versions, and
you will not notice for weeks.

---

## Phase 4 — Release on merge

**Goal:** every merge to `main` yields a version, a tag and an image, with no
human input.

1. **Register this repo as a Jenkins shared library**: Manage Jenkins → System
   → Global Pipeline Libraries. Name it `sdd-workflow`, default version `main`,
   source = this repo in Bitbucket. Allow the default version to be overridden
   so a repo can pin `@v1` while you develop `@main`.

2. Set the Jenkins **global environment** and **credentials** from
   [the configuration inventory](./automation.md#configuration-inventory). This
   is once for the whole controller, not once per repo — the main practical
   advantage over per-repo workflow files.

3. In the app repo's `Jenkinsfile`, set the service, registry and the name of
   its Argo CD promote job:

   ```groovy
   @Library('sdd-workflow@main') _
   sddRelease(service: 'backend',
              registry: 'registry.acme.com/platform',
              gitopsJob: 'gitops/backend-promote')
   ```
4. **Seed the first tag by hand**, so version computation has a baseline:

   ```bash
   git tag -a backend-1.0.0 -m "baseline before automated releases"
   git push origin backend-1.0.0
   ```

5. Dry-run before switching it on:

   ```bash
   scripts/release-version.sh --service backend
   scripts/release-version.sh --service backend --notes
   scripts/jira-release.sh --service backend --version 1.0.1 --dry-run
   ```

**Done when:** merging a pull request titled `fix(x): y` produces tag
`backend-1.0.1`, release notes on the Jira version `backend 1.0.1`, and an
image pushed by digest — and you did not type `1.0.1` anywhere.

**The trap to avoid:** Jenkins clones shallow by default, and version
computation reads every tag. `sddRelease` forces
`CloneOption(shallow: false, noTags: false)` for exactly this reason. If your
job overrides the checkout, keep that option or every release computes
`0.0.1`.

---

## Phase 5 — GitOps and the dev environment

**Goal:** merge to running in `dev` in under fifteen minutes, with nobody
running a deploy command.

1. Structure each GitOps repo:

   ```
   gitops_backend/
     apps/backend/
       base/
       overlays/{dev,staging,prod}/kustomization.yaml
   ```

   Each overlay pins the image by **digest**, not tag —
   [why](./release.md#tags-and-images).

2. Create one Argo CD Application per service per environment, named
   `<service>-<env>` (`sddObserve` polls that name). Auto-sync **on** for `dev`
   and `staging`, **off** for `prod` — production syncs when its pull request
   merges.

3. Create **two Jenkins jobs** per service against the Argo CD repo:

   - `gitops/<service>-observe` — Multibranch over `main`, using
     [`examples/Jenkinsfile.gitops`](../examples/Jenkinsfile.gitops).
   - `gitops/<service>-promote` — a parameterised Pipeline job using
     [`examples/Jenkinsfile.promote`](../examples/Jenkinsfile.promote). Tick
     **Trigger builds remotely** so Jira can start it in phase 7.

4. Protect the production overlay with
   [Bitbucket branch permissions and merge checks](./automation.md#protecting-the-production-overlay).
   Bitbucket Data Center has no `CODEOWNERS`, so the gate is per-repo — which
   is fine, because the Argo CD repos are already split per service. `dev` and
   `staging` need no protection; they are meant to move constantly.

5. Define health honestly. A readiness probe returning 200 is not health —
   Argo must see the workload actually serving. Bad health definitions are what
   make automatic rollback either useless or terrifying.

**Done when:** merging to `main` results in the new digest running in `dev`,
with no human action, in under fifteen minutes.

**Skip it and:** there is nothing to promote and no deployment event, so phases
6 and 7 have no trigger.

---

## Phase 6 — The Jira feedback loop

**Goal:** anyone can open a ticket and see where the work is, without asking a
developer. This is the phase people actually notice.

1. Create the `Deployed Environments` field if you have not, and note its
   `customfield_` id:

   ```bash
   curl -sS -u "$JIRA_EMAIL:$JIRA_TOKEN" \
     "$JIRA_URL/rest/api/2/field" | jq -r '.[] | select(.name=="Deployed Environments") | .id'
   ```

2. Set `JIRA_FIELD_DEPLOYED_ENVS` on the GitOps repos.
3. Test against one real issue before trusting it:

   ```bash
   scripts/jira-deploy.sh --service backend --version 1.0.1 \
     --env dev --keys "PROJ-1" --dry-run
   ```

4. Add [Jira automation rules](./automation.md#jira-automation-rules) 1–7 —
   board movement first. Add 8–14 the week after, once 1–7 are trusted.
5. Verify **idempotency**: run the same deploy twice and confirm the issue gets
   one comment, not two.

**Done when:** a merged PR results, unattended, in the ticket showing
`🚀 Deployed to dev — backend 1.0.1`, the field reading `dev`, and the card in
`Deployed to dev`.

---

## Phase 7 — Promotion and rollback

**Goal:** verified work reaches production on a decision, not on a deploy
script; and reversing it is boring.

1. Add Jira automation rule 6 — the "Send web request" that starts the promote
   job when a tester moves a story to
   `Ready to release`, calling
   `https://jenkins/job/gitops/job/<service>-promote/buildWithParameters`.
   Store the Jenkins API token in Jira's automation secrets, and make sure the
   promote job has **Trigger builds remotely** enabled with a matching token.
2. Test the staging promotion by moving one real story.
3. Do a **production promotion dry run** with a no-op change, all the way
   through the approval. Do this before you need it.
4. **Rehearse a rollback deliberately**, in working hours, with the team
   watching:

   ```bash
   scripts/promote.sh --service backend --to prod --digest <previous> --version <previous> --pr
   ```

   A rollback path that has never been exercised does not exist. Rehearse it
   once a quarter after that.

5. Write down who approves production, and their backup. A single approver on
   holiday is a release freeze nobody planned.

**Done when:** a tester moving one card results in a staging deploy, and one
approval puts it in production — and you have rolled back once on purpose.

---

## Phase 8 — The Scrum layer

**Goal:** the process people follow matches the pipeline the machines run.

Only now, with the board moving by itself, change how the team works.

**Sprint 1 — run both tracks, badly, on purpose.**
- Pick **three** stories for the discovery track. Only three; the first
  proposals take twice as long as they will in a month.
- Deliver whatever is already in flight, however it was specced. Do not
  retrofit gates onto work already coded — the metric will be low this sprint
  and that is the correct reading.
- Run [refinement](./scrum.md#refinement) properly, with the sizing rule out on
  the table.

**Sprint 2 — the Ready pool exists.**
- Deliver the three stories specced in sprint 1. This is the first sprint where
  gate 4 costs nothing, and the team feels it.
- Spec five or six for sprint 3.
- Enforce the DoR: nothing enters delivery that did not come from the pool.

**Sprint 3 — steady state.**
- The pool holds ~1.5 sprints of work.
- Apply the 60/20/20 split for real, including leaving the interrupt slice
  empty.
- Start reading the SDD metric as a number that means something.

**Done when:** a sprint completes in which no branch was cut before its spec was
merged, and nobody had to be reminded.

**The failure mode to watch:** the Ready pool running dry in sprint 3, because
discovery got squeezed by delivery pressure. If that happens, the discovery
work was invisible — put it on the board with its own estimates.

---

## Phase 9 — Metrics

**Goal:** know whether any of this is working.

Build one dashboard. Not five.

| Metric | Source | Healthy |
|---|---|---|
| Deployment frequency | tags per service per week | daily+ |
| Lead time for change | gate 4 merge → prod deployment | < 5 days |
| Change failure rate | rollbacks + hotfixes ÷ promotions | < 15% |
| Time to restore | incident opened → prod deploy | < 1 h |
| SDD adherence | `make check` passes ÷ stories closed | > 90% |
| Ready pool depth | `Ready` count ÷ velocity | 1–2 sprints |
| Interrupt spend | unplanned points ÷ capacity | < 20% |

```bash
make check                              # local
make check-shared                       # the shared store
JIRA_URL=… JIRA_TOKEN=… make check      # plus the label assertion
```

**Report metrics to the team, never up the chain as a score.** The moment SDD
adherence becomes a number someone is judged on, stories get the label without
the discipline, and you have destroyed the only instrument that told you
whether the process worked.

**Done when:** the retro starts with the dashboard on screen and nobody has
prepared anything for it.

---

## The two-day minimum

If two weeks is not available, this is the subset with the best ratio of value
to effort. It is genuinely useful on its own.

1. **Phase 3** — squash-only merges, conventional PR titles, branch naming. *4 h.*
2. **Phase 4** — release on merge. *1 d.*
3. **Phase 6, layer 1 only** — Fix Version stamped at tag time. *2 h.*

You get: automatic versioning, automatic tags and release notes, and every Jira
issue showing which build contains it. That alone kills the "when does my fix
ship?" question, which is usually the loudest pain. Add the rest later, in
order.

## See also

| | |
|---|---|
| [Pipeline](./pipeline.md) | the eleven gates you are building |
| [Automation](./automation.md) | every variable, secret and rule |
| [Release](./release.md) | why the pipeline is shaped this way |
| [Scrum layer](./scrum.md) | phase 8 in detail |
