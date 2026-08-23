---
name: "SDD: Plan"
description: "Write design.md and tasks.md with Jira-keyed per-repo sections"
allowed-tools: Bash(openspec:*), Bash(git:*)
category: "SDD"
tags: ["sdd", "jira", "tasks"]
---

Write `design.md` (how) and `tasks.md` (the step-by-step plan) for an approved
change. This is **gate 5** — the implementing developer's job, always, whether
the proposal came from them or from analytics.

**Input**: `/sdd:plan <change-id>` (add `--store specifications` for a shared
cross-repo change).

**Precondition**: the spec delta is already merged. If it isn't, stop — planning
against an unapproved proposal wastes the work and cutting a branch now fails
the metric permanently.

## Steps

### 1. Read the approved proposal

```bash
openspec show "<change-id>" [--store specifications]
openspec status --change "<change-id>" [--store specifications] --json
```

Re-read `proposal.md` and every `specs/*.md` from disk. Do not plan from memory
of the conversation — they may have changed during review.

### 2. design.md — only when warranted

Get the instructions first:

```bash
openspec instructions design --change "<change-id>" [--store specifications] --json
```

Write it when the change is cross-cutting, adds a dependency, involves a
migration, or has a non-obvious approach. Skip it for a small local change and
say you skipped it — don't manufacture ceremony.

### 3. tasks.md — one section per affected repo, each with its Jira key

```bash
openspec instructions tasks --change "<change-id>" [--store specifications] --json
```

The section convention is mandatory and machine-checked:

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

Rules:

- **One section per affected repo. Nothing else.** Sections are repo slices,
  never work slices. If you are about to write "## 4. Backend part two", the
  story was oversized — say so and escalate rather than encoding it here.
- **Every heading carries its Jira task key** in parentheses.
  `scripts/check-sdd.sh` fails otherwise.
- **Ask the user for the task keys** if you don't have them. For a single-repo
  story with no child tasks, use the story key itself.
- **Gate the consumers.** If `common` or any shared contract is involved, its
  section must land and publish before the consuming sections start, and the
  gate must be written as a comment so it survives review.
- Tasks must be concrete and verifiable — informed by the repo's real code and
  conventions, not generic scaffolding.

### 4. Verify

```bash
openspec validate "<change-id>" [--store specifications]
./scripts/check-sdd.sh --change "<change-id>" [--store specifications]
```

### 5. Report

Tell the user:

- whether you wrote `design.md`, and if not, why not
- the section → Jira task mapping you used
- where the contract gate sits
- the branch name to use next:
  `PROJ-123/PROJ-125-backend-<slug>` (multi-repo) or `PROJ-140-<slug>`
  (single-repo)
- next step: push the planning commit for tech-lead review before coding

## Guardrails

- **Never plan against an unmerged proposal.**
- **Never omit a Jira key from a section heading.**
- **Never let a consuming section start before the contract section publishes.**
- **Never invent task keys** — ask.
