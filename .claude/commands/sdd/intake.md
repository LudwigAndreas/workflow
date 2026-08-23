---
name: "SDD: Intake"
description: "Turn a Jira story's intent into an OpenSpec proposal, sized and linked correctly"
allowed-tools: Bash(openspec:*), Bash(git:*)
category: "SDD"
tags: ["sdd", "jira", "proposal"]
---

Turn a story's free-text intent into `proposal.md` + `specs/*.md`, correctly
sized, in the correct OpenSpec root, linked to its Jira story.

This is **gate 2** of the pipeline (`docs/pipeline.md`). It stops before
`design.md` and `tasks.md` — those are the implementing developer's job at
gate 5 (`/sdd:plan`).

**Input**: `/sdd:intake <JIRA-KEY>` and/or a description of the intent. If the
user gives only a key, ask them to paste the story description.

## Steps

### 1. Apply the sizing rule — before writing anything

Ask yourself, and tell the user your answer:

> Can `proposal.md` + `specs/*.md` for this be reviewed and approved as a
> **single decision**?

- **Yes, one repo** → one change, authored in that repo's local `openspec/`.
- **Yes, several repos** → one change, authored in the shared store
  (`--store specifications`), because it changes a contract others consume.
- **No — several independent capability changes** → **STOP.** Tell the user
  this should be a Jira Epic split into several stories, each getting its own
  change. Propose the split as a list. Do not proceed until they choose.

Never split one change across several stories, and never bundle several
capability changes into one change to avoid the conversation.

### 2. Decide the OpenSpec root

| Intent | Root | Flag |
|---|---|---|
| only this repo's internals change | the local repo | none |
| another repo must change its code because of this | shared store | `--store specifications` |

If a store is needed, run `openspec store list --json` to confirm the id is
registered. Keep the flag on every subsequent command that takes it.

### 3. Explore before proposing

Run the `openspec-explore` skill (or `/opsx:explore`) on the intent first when
anything is ambiguous. Ambiguity resolved here costs a sentence; resolved at
gate 9 it costs a re-opened story. Do not invent requirements to fill gaps —
ask the user.

### 4. Create the change

Derive a kebab-case change id from the intent (`add-sso-login`). If the story
already records a `change-id`, use that exact one.

```bash
openspec new change "<change-id>" [--store specifications]
```

### 5. Link it to Jira — do not skip this

Add the story key to `openspec/changes/<change-id>/.openspec.yaml`:

```yaml
schema: spec-driven
created: <date>
jira: PROJ-123
```

`scripts/check-sdd.sh` fails the change without it. If you don't know the key,
ask — don't guess and don't leave it out.

### 6. Generate proposal.md and specs/*.md — and stop

Follow the `openspec-propose` skill's artifact loop, but create **only**
`proposal` and `specs`. The repo's `openspec/config.yaml` declares `rules:`
that instruct you to stop there; honour them.

Write scenarios a tester will review at gate 3:

- every requirement has at least one `#### Scenario:` with `WHEN` / `THEN`
- `WHEN` is a concrete trigger, not a state of mind
- `THEN` is observable from outside the system
- include the unhappy paths — invalid input, expired credentials, missing
  permissions, empty collections, dependency down
- no class names, function names or library choices

If the change has no observable behavior change (pure refactor, tooling, docs),
do **not** invent a requirement. Set `skip_specs: true` in `.openspec.yaml` and
write `proposal.md` only.

### 7. Report

```bash
openspec validate "<change-id>" [--store specifications]
openspec status --change "<change-id>" [--store specifications] --json
```

Then tell the user:

- where the change lives and which root it's in
- the Jira story it's linked to
- that `design`/`tasks` showing `blocked`/`ready` is **expected**, not an error
- next step: tester reviews scenarios (gate 3), then tech lead approves and
  merges (gate 4), and **only then** may anyone cut a branch

## Guardrails

- **Never write `design.md` or `tasks.md` here.** Different role, different gate.
- **Never skip the `jira:` key.**
- **Never proceed past an oversized story** — escalate it as an Epic instead.
- **Never put repo-internal specs in the shared store.** If no other repo has
  to change its code, it belongs in the local repo.
