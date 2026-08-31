# Tester

🇬🇧 English | [🇷🇺 Русский](./tester.ru.md)

You own **scenario quality and verification**. You start the moment the intent
merges — not when the code is ready.

## Your loop

```
/sdd:review    (with the team lead) harden the scenarios before merge
/sdd:tests     derive the test plan from the intent — before any code exists
               → implement tests while developers implement features
verify         exercise every scenario against the deployed environment
```

You are the one role that appears on **both** boards: `Discovery` at `In Review`,
hardening scenarios before the intent merges, and `Delivery` at `In Testing`,
verifying them against a deployed environment. If you only ever appear on the
second, the team has quietly reverted to testing at the end. See
[boards](../boards.md).

## You do not wait for the implementation

This is the part people find hardest to believe. The scenarios in an intent's
`specs/` are already written in WHEN/THEN form **precisely so they can be
executed as tests before anything is built**. You work from the same contract
the developers do, at the same time.

If you find yourself reading code to work out what to assert, the workflow has
inverted: the contract is in the intent, and if it is not clear enough to test
against, *that is the finding* — report it rather than inferring the answer.

## Deriving cases

For each `### Requirement:` in the intent's `specs/`:

- **one case per `#### Scenario:`**, named after it, mapped 1:1 so a failing
  test names the requirement it violates
- **regression cases** the scenarios do not mention — existing behaviour in the
  same area that must survive. `analysis.md` and the archived specs are where
  these come from, because the specs only describe the *delta*
- **boundary cases** a scenario implies but does not spell out: empty
  collections, maximum lengths, concurrent submissions, repeated retries, clock
  skew, partial failures
- **integration cases** that no single repository can verify alone — wherever
  `handoff.md` shows one repository producing a contract and another consuming
  it

That last category is the one only you are positioned to write, and the one
that catches what parallel work gets wrong.

## Contract tests earn their keep

A test that the backend's response matches the shape in `handoff.md`, and a
test that the frontend renders that exact shape, together catch the integration
failure **before** the two are ever deployed together. Since both sides are
built in parallel from a written contract, this is where the mismatch will be —
and it is cheap to catch here and expensive to catch in staging.

## Reporting defects in the intent

While deriving cases you will find scenarios that cannot be tested as written.
Each is a defect in the intent, and finding it now is worth far more than any
test you write:

| Symptom | What it means |
|---|---|
| a `THEN` not observable from outside | nothing to assert on |
| a `WHEN` that cannot be triggered | the scenario cannot run |
| a requirement with no scenario, or only a happy path | untestable, or untested |
| two scenarios that contradict each other | the intent is ambiguous |
| a contract in `handoff.md` too vague to assert on | both repos will guess, differently |

If the intent is still open, this feeds straight into `/sdd:review`. If it has
merged, it needs a correction in the store — say so, rather than quietly
writing a test for what you assume was meant.

## Verification

Verify against the **deployed** environment, not a local build: the point is
that the scenario holds in the system as it actually runs, after Argo CD has
reconciled it.

Walk the intent's `handoff.md` Acceptance sections. A story is verified when
every scenario in the intent's `specs/` has been exercised — including the
unhappy paths, which is where verification usually stops short.

## The monthly quality review

Once a month you sit with the team lead over `Team <name> — Quality`: escaped
defects, open bugs by priority, average age of open bugs. Monthly, not daily —
these numbers move over weeks, and a single month's figures mean very little
next to the trend across three or four.

Your contribution is the diagnosis. For each escaped defect, answer:

> Which scenario would have caught this, and why did it not exist?

Almost always the answer is that the master intent never had that unhappy path,
which means the fix is upstream — a tighter `/sdd:review` for that class of
scenario — not "test harder". That makes escaped defects the outcome measure for
scenario quality, which is the thing you own.

Watch the escaped : found-in-test **ratio** rather than the raw count; the count
moves with team size, release frequency and traffic, and tells you little.

Details and JQL: [dashboards](../dashboards.md).

## Guardrails

- **Never weaken a case to match what was built.** If the code and the intent
  disagree, one of them is wrong; either way it is a conversation, not a silent
  edit to your assertion.
- **Never invent a requirement.** A missing scenario is reported, not filled in
  from your own judgement.
- **Do not sign off on unhappy paths you did not exercise.** They are the ones
  that matter in production, and they are the ones the intent most often gets
  sent back for.

## Common mistakes

| Mistake | Consequence |
|---|---|
| waiting for the code before writing tests | you become the critical path |
| testing only the happy paths | the failures ship |
| skipping contract tests | integration failures found in staging, not locally |
| adjusting an assertion to make a test pass | the defect ships with a green build |
