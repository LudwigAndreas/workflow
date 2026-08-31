# Team lead

🇬🇧 English | [🇷🇺 Русский](./team-lead.ru.md)

You own **intake, sizing and the merge decision**. Your approval is the moment
several people start building in parallel from one document.

## Your loop

```
intake        route the work to its lane, size it, label it SDD,
              reserve an intent id, cut the per-repo tasks
/sdd:review   review the intent, approve or send it back
merge         → this is the ordering gate
/sdd:status   watch the fan-out, unblock it
```

## Intake

For each new item:

1. **Route it.** Which lane in [work types](../work-types.md)? Not everything
   needs an intent — a bug fix, a refactor or a chore does not, and forcing it
   through the full flow is how a process gets abandoned.
2. **Size it.** Can it be reviewed and approved as one decision, describing one
   capability change? If not, it is an Epic. Several repositories is *not* a
   reason to split.
3. **Label it `SDD`** if it is a story following the flow. The metric reads
   this label.
4. **Reserve an intent id** — kebab-case, derived from the intent, not from the
   Jira key: `add-sso-login`, not `proj-123`.
5. **Cut the per-repo tasks** once the intent's affected-repositories table
   exists, one per repository, each carrying its own key for the branch.

## The review

This is the decision gate of the whole workflow. After you merge, a tester and
several developers build against this document **without coordinating**. A
vague contract is resolved differently in each repository, and the mismatch
appears at integration, days later.

`/sdd:review` walks the full checklist. The items that catch the most:

- **Coverage.** Every requirement in `specs/` owned by at least one repository
  repository in the intent's Repositories table. Compute the union yourself.
- **Contract precision.** Could a developer build against each contract
  obligation *before the other side exists*? If not, send it back — this is the
  single highest-value thing you check.
- **Unhappy paths.** Every requirement has at least one.
- **Four hashtags** on scenarios. Three parses as nothing, silently.
- **MODIFIED requirements** copied whole, scenarios included. Check against
  `openspec/specs/<capability>/spec.md` yourself; a partial copy deletes
  scenarios at archive time.
- **Rollout order** agrees with each repository's `Depends on`, and producers
  land before consumers.
- **Blocking unknowns.** An open question that would change the specs blocks
  the merge. "We will work it out during implementation" means each repository
  works it out differently.

Request changes; do not fix the intent yourself. Analytics owns it, and a
silent fix teaches nobody.

## The ordering gate

**No branch may exist in any repository before the intent merges.**

The metric records whether the spec landed before the first commit, and it is
**not fixable afterwards**. In Jira, the story cannot enter *Ready for Dev*
before the merge — that transition is the gate, because it is the moment
developers are allowed to start.

If a branch already exists, say so plainly. The story did not follow SDD.
Rewriting history to make the check pass defeats the point of measuring it.

## Watching the fan-out

```bash
make status                 # every intent, read from the repositories
make gate INTENT=<id>       # may this one be archived yet?
make check                  # the SDD metric
```

`intent-status.sh` reads the repositories rather than the checkboxes, so it
flags three specific lies: work archived but not ticked, a box ticked while the
change is still open, and a box ticked with no derived change at all.

What to act on:

- a repository **not started** while others are finishing — it will become the
  critical path
- a repository **blocked** on a producer that has not published
- a **contract correction** raised by a developer — this is urgent, because the
  other side is building against the old version right now

## Your two boards

`Team <name> — Discovery` (Kanban, Stories) and `Team <name> — Delivery`
(Scrum, Tasks). Split by track, not by role — a board per role hides the
bottleneck and creates per-role backlogs.

Two settings you own, and both matter more than they look:

- **WIP limits on Discovery.** They are what holds discovery to *one* sprint
  ahead of delivery. Further ahead and intents go stale, because the shared
  baseline moves underneath them.
- **The `Ready for Dev` transition is yours alone.** It is the ordering gate.
  Sprint planning may pull only stories already sitting there — pull one that is
  not, and the metric breaks unfixably.

Full setup, filters and columns: [boards](../boards.md).

## Your two dashboards

You own both, and they run on different cadences on purpose.

**`Team <name> — Delivery`**, daily, in standup. Blocked work, stalled statuses,
merged intents nobody has started. Everything on it should be actionable before
lunch.

**`Team <name> — Quality`**, **monthly**, with the tester. Escaped defects, open
bugs by priority, average age of open bugs. These numbers cannot move
meaningfully in a day — checking them daily produces reaction to noise and
teaches the team that dashboards are for ignoring.

The monthly review has one question that matters, asked of every escaped defect:
*which scenario was missing, and was it missing because the intent never had
it?* In this workflow an escaped defect nearly always traces back to an absent
unhappy-path scenario in a master intent, which makes it a defect in
`/sdd:review` — yours — rather than in testing.

Neither dashboard carries the SDD metric or the fan-out. Both live outside Jira:
`make check` reads git, `make status` reads the repositories. Run them alongside
the board.

Setup, gadgets and JQL: [dashboards](../dashboards.md).

## What you do not own

- the requirements themselves — analytics
- technical design and task breakdown — the implementing developer
- test strategy — the tester

Your leverage is sizing, the review, and keeping the fan-out unblocked.

## Common mistakes

| Mistake | Consequence |
|---|---|
| splitting a story per repository | two specs to keep in agreement; the decision is lost |
| approving a vague contract | integration failure days later |
| letting a branch precede the merge | the story cannot count toward the metric |
| fixing the intent yourself in review | analytics learns nothing; you own it now |
| forcing a chore through the full flow | the process gets abandoned |
