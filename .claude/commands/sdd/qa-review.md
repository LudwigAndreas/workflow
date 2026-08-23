---
name: "SDD: QA review"
description: "Harden a proposal's scenarios before code exists"
allowed-tools: Bash(openspec:*)
category: "SDD"
tags: ["sdd", "qa", "specs"]
---

Review a proposal's `#### Scenario:` blocks and close the gaps. This is
**gate 3** — the tester's gate, before the tech lead approves and before any
code exists.

The scenarios in `specs/*.md` **are** the acceptance criteria. A missing edge
case found here costs a sentence; the same case found at gate 9 costs a
re-opened story, a new branch, another review and another deploy.

**Input**: `/sdd:qa-review <change-id>` (add `--store specifications` for a
shared cross-repo change).

## Steps

### 1. Read the proposal

```bash
openspec show "<change-id>" [--store specifications]
```

Read `proposal.md` for intent, then every `specs/*.md` in full.

If the change declares `skip_specs: true` in `.openspec.yaml`, there is nothing
to review here — say so and stop. A pure refactor has no observable behavior
change by definition.

### 2. Check every requirement

Walk them one at a time. For each, report ✓ or a specific defect:

- **Has at least one scenario.** A requirement with no `#### Scenario:` is
  untestable, and `openspec validate` rejects it.
- **`WHEN` is a concrete, reachable trigger.** "WHEN the user is interested in
  exporting" is not testable. "WHEN the user clicks Export with no rows
  selected" is.
- **`THEN` is observable from outside.** A response, a status code, a rendered
  state, a stored record. Not "the service handles it correctly".
- **Unhappy paths exist.** Invalid input, expired or missing credentials,
  insufficient permissions, empty collections, downstream dependency
  unavailable, concurrent modification. Most proposals arrive happy-path only —
  this is where most of the value is.
- **Boundaries are covered.** If a limit exists, put a scenario on each side of
  it.
- **No implementation leakage.** Scenarios naming classes, functions or
  libraries are over-specified and break on harmless refactors. Flag them.
- **Unambiguous.** If you cannot tell how to execute it, neither can the two
  developers about to implement it independently — and they will pick different
  readings. This is the highest-value defect class to catch.

### 3. Write the missing scenarios

Add them directly to the delta spec files, in the existing style. Keep them
observable and implementation-free. Preserve the `## ADDED Requirements` /
`## MODIFIED Requirements` delta headers exactly — don't restructure the file.

### 4. Validate

```bash
openspec validate "<change-id>" [--store specifications]
```

### 5. Report

Give the user:

- a per-requirement verdict table
- the scenarios you added, and why each one matters
- anything **ambiguous that you could not fix yourself** — these are questions
  for analytics, not things to guess at. List them explicitly as blocking.
- your gate verdict: **pass** (ready for tech-lead approval) or **needs work**

## Guardrails

- **Never approve a scenario you can't tell how to execute.**
- **Never add implementation detail** to a scenario to make it concrete —
  concrete means observable, not internal.
- **Never invent requirements.** You harden what's proposed; new requirements
  are analytics' call.
- **Never rewrite the delta headers.**
