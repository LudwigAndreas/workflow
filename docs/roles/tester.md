# Tester / QA

🇬🇧 English | [🇷🇺 Русский](./tester.ru.md)

Your SDD artifact is **the scenarios in `specs/*.md`**. They are not
documentation that happens to resemble test cases — they *are* the acceptance
criteria, and you co-own them. That gives you a gate before code exists, which
is the whole point.

Read [the pipeline](../pipeline.md) once first. You own **gates 3 and 9**.

## What you own

- The quality of `#### Scenario:` blocks in every proposal (gate 3).
- Verification of every scenario against merged code (gate 9).
- Test cases that reference scenarios rather than restating them.

You work in **Mode B** — inside the repo you're testing — or read shared
contracts with `--store specifications` from anywhere.

## Why you review before code

A missing edge case found at gate 3 costs a sentence in a spec. The same case
found at gate 9 costs a re-opened story, a new branch, another review and
another deploy. Gate 3 is the cheapest defect-removal point in the entire
pipeline, and it's yours.

You're also the check on ambiguity. If you can't tell what a scenario expects,
neither can the two developers about to implement it independently — and they
will each pick a different reading.

## Gate 3 — reviewing scenarios

The proposal has `proposal.md` + `specs/*.md` and nothing else. Read it:

```bash
openspec show <change-id> [--store specifications]
```

Or run `/sdd:qa-review <change-id>`, which walks the requirements and flags gaps.

For each requirement, check:

- **Every requirement has at least one scenario.** A requirement with no
  `#### Scenario:` block is untestable and `openspec validate` rejects it.
- **`WHEN` is a concrete trigger**, not a state of mind. "WHEN the user is
  interested in exporting" is not testable; "WHEN the user clicks Export with
  no rows selected" is.
- **`THEN` is observable.** Something you can see from outside the system —
  a response, a status code, a rendered state, a stored record. Not "the
  service handles it correctly".
- **The unhappy paths exist.** Invalid input, expired credentials, missing
  permissions, empty collections, the downstream dependency being down. Most
  proposals arrive with only the happy path; adding the rest is the bulk of
  your value here.
- **Boundaries are named.** If a limit exists, a scenario should sit on each
  side of it.
- **No implementation leakage.** Scenarios naming classes, functions or
  libraries are over-specified and will break on harmless refactors. Push back.

Add the missing scenarios directly — you have edit rights on the proposal at
this gate. Then approve so it can reach the tech lead.

## Writing test cases

Reference the scenario; don't restate it. Restating creates a second source of
truth that drifts.

```
Test:    SSO login rejects an expired assertion
Ref:     specs/auth/spec.md :: "SSO login" :: "expired IdP assertion"
Steps:   ...
```

When a scenario changes, the reference tells you exactly which test cases to
revisit. `openspec show <change-id>` before each regression pass tells you what
moved.

## Gate 9 — verification

Jira moves the story to `Verifying` by itself, the moment every one of its
tasks is running in `dev`. That is your cue — you never poll, and you are never
handed a half-deployed story.

1. `openspec show <change-id>` — list every scenario in the change.
2. Exercise each one **against the `dev` environment**, never against a
   developer's laptop.
3. Anything that fails is one of two findings, and it matters which:
   - **Code doesn't match the spec** → defect, goes back to the developer.
   - **Spec was wrong** → the requirement needs revising via `/opsx-update`,
     and it's worth asking why gate 3 missed it.

When every scenario passes, move the story to `Ready to release`. **That one
card move is the only manual transition in the whole delivery half of the
pipeline** — it triggers the staging promotion, which is exactly why it is
yours and not a machine's.

Only after every scenario passes does the change get archived. Archiving
updates the main specs to "this is how the system now behaves" — so archiving
unverified work writes something untrue into the canonical spec.

## Your Jira task

On a cross-repo story you get a `qa` Task alongside the repo tasks. It has no
branch, which is fine — the metric is satisfied by the story's other task
branches. Your task tracks gates 3 and 9.

For a single-repo story with no tasks, your work sits on the story itself.

## Commands

| Command | When |
|---|---|
| `/sdd:qa-review` | walk a proposal's requirements and flag scenario gaps |
| `/opsx-explore` | think through edge cases before writing them up |
| `/opsx-update` | revise a requirement whose spec turned out to be wrong |

## What you must not do

- **Don't wait for code to start reviewing.** Gate 3 is before implementation
  on purpose.
- **Don't restate scenarios in test cases.** Reference them.
- **Don't approve a scenario you can't tell how to execute.** If it's unclear
  to you it's unclear to the implementers.
- **Don't let a change archive with unverified scenarios.**
