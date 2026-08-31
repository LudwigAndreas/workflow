---
description: "Tester: turn a merged master intent into a test plan, before any code exists"
---

Turn a merged master intent into a test plan and test skeletons.

The point of spec-driven development is that this can start the moment the
intent merges — **before any implementation exists**. The scenarios in the
intent's `specs/` are already written in WHEN/THEN form precisely so they can
be executed as tests. You are not waiting for developers; you are working from
the same contract they are, at the same time.

**Input**: `/sdd-tests <intent-id>`. With no argument, list merged intents that
have no test plan yet.

## Steps

### 1. Read the contract

```bash
openspec show <intent-id> --store specifications --json
```

Read `specs/` in full — those business rules are your test cases — and
`intent.md`, which tells you what business outcome must be true afterwards,
which repositories are involved, and what external contracts and UI the change
has to satisfy.

`intent.md`'s **Today** section tells you what the system did *before*, which is
where regression cases come from: behaviour that must **not** change is rarely
written in the specs, because the specs only describe the delta.

### 2. Derive the cases

For each `### Requirement:` in `specs/`, produce:

- one case per `#### Scenario:`, named after it, mapped 1:1 so that a failing
  test names the requirement it violates
- the **regression cases** the scenarios do not mention: existing behaviour in
  the same area, from the intent's Today section and the archived specs, that
  must survive
- the **boundary cases** a scenario implies but does not spell out: empty
  collections, maximum lengths, concurrent submissions, repeated retries,
  clock skew, partial failures
- the **integration cases** that no single repository can verify alone —
  anywhere the intent shows one repository producing something another
  consumes, and anywhere an external API contract is involved. These catch the
  mismatch parallel work creates, and nobody else is positioned to write them

### 3. Say which layer each case belongs to

For each case, state where it runs: unit inside one repository, contract test
at a repository boundary, or end-to-end against a deployed environment. Say
which repository owns it. A case with no owner does not get written.

Contract tests deserve particular attention: a test that the backend's response
matches the shape the intent's System context fixes, and a test that the
frontend renders that exact shape, together catch the integration failure
**before** the two are ever deployed together.

### 4. Report gaps in the intent — this is the valuable part

While deriving cases you will find scenarios that cannot be tested as written.
Each is a defect in the intent, and it is far cheaper to fix now than after
implementation:

- a `THEN` that is not observable from outside — nothing to assert on
- a `WHEN` that cannot actually be triggered
- a requirement with no scenario, or only a happy path
- two scenarios that contradict each other
- an external contract in the intent's System context too vague to write an
  assertion against

List them explicitly and tell the user to raise them against the intent. If the
intent is still open, this feeds straight back into `/sdd-review`. If it has
already merged, it needs a correction in the store — say so, rather than
quietly writing a test for what you assume was meant.

### 5. Write the plan

Put the test plan where the tests will live — normally in the owning
repository, alongside its existing tests. Reference the intent id and the
requirement names in the test names, so a failure points back at the contract.

Where the tooling allows, write the skeletons now, failing or pending. A
pending test named after a requirement is a far better tracker of "not built
yet" than a checklist, because it goes green by itself.

## Guardrails

- **Do not wait for the implementation.** If you are reading code to work out
  what to assert, you have inverted the workflow — the contract is in the
  intent, and if it is not clear enough to test, that is the finding.
- **Do not weaken a case to match what was built.** If the code and the intent
  disagree, the code is wrong or the intent is wrong; either way it is a
  conversation, not a silent edit to your assertion.
- **Do not invent requirements.** A missing scenario is reported, not filled in
  from your own judgement.
