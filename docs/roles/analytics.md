# Analytics

🇬🇧 English | [🇷🇺 Русский](./analytics.ru.md)

You own the **master intent**: `intent.md` and `specs/`. Everything the team
builds starts from what you write — but you do not write any of it.

## Your loop

```
/opsx:explore <area>     understand what is true today   (standard OpenSpec)
/sdd:intent <JIRA-KEY>   write the four artifacts        (the one custom step)
                         → team lead reviews (/sdd:review)
                         → merged, and only then do branches appear
```

`/sdd:intent` is the only command in this workflow that replaces nothing
standard — it exists because a master intent spans every repository at once,
which no stock command does. Exploration before it is the ordinary
`/opsx:explore`; implementation after it is the ordinary `/opsx:propose`,
`/opsx:apply` and `/opsx:archive`, run by developers in their own repositories.

Your board is `Team <name> — Discovery` (Kanban): `To Do` → `In Analysis` →
`In Review` → `Ready for Dev`. Respect its WIP limits — they exist to keep you
exactly one sprint ahead of delivery, because an intent written months early
goes stale as the shared baseline moves underneath it. See
[boards](../boards.md).

You work in the `workflow` repo, where the shared store and every application
repository are checked out side by side. That cross-repo view is the point:
you are the only role that sees the whole system at once while authoring.

## What you own, and what you must not write

| Artifact | Yours? |
|---|---|
| `intent.md`, `specs/` | **yes** |
| `proposal.md`, `design.md`, `tasks.md` | **no** — all three belong to the developer, in their own repository |

Your intent is the **input** to each developer's `/opsx:propose`, not the first
half of it. They decide what their repository builds; you establish what the
business needs and what the outside world requires. The store's schema defines
only `intent` and `specs`, so asking for a proposal here is a hard error, not a
matter of discipline.

The split is not a slight. Deciding what to build needs knowledge of the
codebase and its conventions, and the person who has it is the person who will
write the code.

Your boundary is: **business outcomes, external contracts and the repositories
that take part — never classes, functions, libraries or frameworks, and never
"repo X should build Y".**

## The bar to clear

Your intent must let a tester and several developers start **at the same time,
without talking to each other**. Concretely:

- a backend developer can build the endpoint without asking what the frontend
  expects
- a frontend developer can build the screen before the endpoint exists
- a tester can write assertions before either exists

Anything a developer needs but cannot find in your intent becomes a question in
chat, and an answer given in chat is a decision nobody else sees.

## Doing it well

**Cite everything in Today.** A claim without a business rule or file path is a
guess, and a guess here is repeated as fact by everyone downstream.

**Name the repositories that will not change**, and say so. It tells a
developer the area was considered and ruled out rather than forgotten.

**Never invent an answer to close an unknown.** An unknown you surface costs a
sentence. The same unknown found during implementation costs a re-opened story
and, usually, a wasted sprint.

**Over-specify System context.** This is the section that justifies your whole
layer: the external API contracts in play — field names, types, status codes,
error cases, and anything a partner has already fixed — the user interface
needed, the data obligations, the events others depend on. "Returns user data"
cannot be built against and cannot be tested. The developer on the other side
cannot ask you, because they are working at the same time as you.

**But stop short of saying what to build.** The Repositories table says what
each one contributes in business terms. The moment you write "backend adds an
endpoint that…", you have written someone else's proposal for them.

**Write the unhappy paths.** Every requirement needs at least one. Invalid
input, expired credentials, missing permissions, empty collections, duplicate
submissions, dependency down. An all-happy-path intent is the most common
reason one comes back from review.

**Check the coverage invariant before you submit.** Every `### Requirement:` in
`specs/` must plainly be the responsibility of at least one repository in your
Repositories table. Compute the union by hand. A requirement owned by nobody is
exactly how a story ships half-implemented.

**Then read it as a developer would** — from one repository, with nothing else
open. Could they run `/opsx:propose` from this document without asking you a
question? If not, that missing fact is yours to add.

## Sizing

One intent = one capability change, reviewable as a single decision.

Several repositories is **not** a reason to split. One intent spanning backend
and frontend is normal — that is what the Repositories table and System context
are for. Several *independent capability changes* is an Epic of several stories.

Full rules: [Jira ↔ SDD](../jira-sdd-mapping.md).

## Mechanics that fail silently

Worth checking by hand every time, because nothing will error:

- scenarios use **exactly four hashtags** — three parses as nothing at all
- new capabilities open with `## Purpose`, 50+ characters
- `MODIFIED` requirements copy the **entire** original block, scenarios
  included — a partial copy silently deletes the rest at archive time

## After the merge

You are not finished. Two things remain yours:

- **Answer contract questions fast.** A developer blocked on an ambiguity is
  blocked for the whole team, because the other repository is building against
  the same sentence.
- **Own the correction.** If a developer finds the contract cannot be met,
  the intent is wrong and it is corrected in the store — by you, before either
  side implements something different.

You usually also archive the intent, once every repository is done:

```bash
make gate INTENT=<intent-id>          # refuses while any repo is outstanding
scripts/intent-gate.sh <id> --tick    # ticks only what it verified
openspec archive <id> --store specifications
```

Archiving is the plain OpenSpec command, deliberately — the store's config
carries the procedure and the gate is what enforces it. Never reach for
`--yes`: that flag skips exactly the warning the gate exists to make binding.

## Common mistakes

| Mistake | Consequence |
|---|---|
| implementation detail in `specs/` | developers cannot choose a sane approach; review stalls |
| writing what a repository should build | you have written the developer's proposal; two documents now disagree |
| vague external contract in System context | each repo interprets it differently; fails at integration |
| all-happy-path scenarios | tester rejects it, or worse, does not |
| a requirement owned by nobody | ships half-implemented |
| unknowns silently resolved | wrong assumption baked into two repositories |
| ticking a Fan-out box | the gate catches it and says the checklist is lying |
