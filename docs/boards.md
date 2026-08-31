# Jira boards

🇬🇧 English | [🇷🇺 Русский](./boards.ru.md)

**Short answer: two boards per team, split by _track_ — not one board, and not
a board per role.**

```
Team <name> — Discovery   Kanban, WIP-limited, Stories    analytics + team lead
Team <name> — Delivery    Scrum, sprints, Tasks           developers + tester
```

The split is not a preference. It is forced by the ordering gate: **no branch
may exist before the intent is merged.** A single board cannot satisfy that,
because a story that enters a sprint and is picked up immediately has no room
for its intent to be written and approved first. So discovery runs **one sprint
ahead** of delivery, and a track running ahead of another needs its own board.

## Why not a board per role

Tempting, and wrong for four reasons.

- **Work flows through roles; it does not belong to them.** One story passes
  analytics → team lead → tester and developers. Split across four boards,
  nobody sees the whole path, and every handoff becomes invisible at exactly the
  moment it needs to be visible.
- **A role is a filter, not a board.** "My work" is `assignee = currentUser()`.
  That is a quick filter or a swimlane — you get it for free without
  fragmenting the flow.
- **Per-role boards create per-role backlogs, and local optimisation follows.**
  Analytics "finishes" ten intents while developers are drowning; each board
  looks healthy and the system is not.
- **The bottleneck disappears.** The point of a board is to show where work is
  piling up. Per-role boards guarantee each queue looks short.

## Why not one board for everything

Also wrong, for a reason specific to this workflow: discovery and delivery are
genuinely different work.

| | Discovery | Delivery |
|---|---|---|
| unit | Story (= one master intent) | Task (= one repo, one branch, one PR) |
| duration | a day or two | most of a sprint |
| done means | intent merged | change archived, scenarios verified |
| rhythm | irregular arrival, flow | planned, sprint-shaped |

Forcing both onto one board produces a column set that is a meaningless
superset for both, and discovery items clog the delivery board for a sprint
before anyone touches them.

There is also a hierarchy argument. You already have:

```
1 Story = 1 master intent            ← Discovery board
1 Task  = 1 repo = 1 branch = 1 PR   ← Delivery board
```

The boards fall straight out of the model. Nothing has to be invented.

## `Team <name> — Discovery`

**Board type: Kanban.** Intents arrive irregularly and do not fit sprint
boxes — flow suits them, sprints do not.

**Filter**

```sql
project = PROJ AND issuetype = Story
  AND status IN ("To Do", "In Analysis", "In Review", "Ready for Dev")
  ORDER BY Rank ASC
```

The status clause matters: once a story moves to `In Progress` (rolled up from
its tasks) it leaves this board automatically and lives on Delivery. No manual
move, no story sitting on two boards.

**Columns** — the story statuses from
[Jira ↔ SDD](./jira-sdd-mapping.md), unchanged:

| Column | Means | WIP limit | Who |
|---|---|---|---|
| To Do | sized, labelled `SDD`, intent id reserved | — | team lead |
| In Analysis | `/opsx:explore` then `/sdd:intent` | **3** | analytics |
| In Review | `/sdd:review`; tester hardens scenarios | **2** | team lead + tester |
| Ready for Dev | **intent merged** — branches may now be cut | ≈ one sprint | — |

**The WIP limits are the point of this board.** Discovery should run one sprint
ahead of delivery and *no further*. Run further ahead and intents go stale: the
shared baseline moves underneath them, and analysis gets redone. The limit on
`Ready for Dev` is the important one — when it is full, analytics stops writing
intents and helps elsewhere.

`Ready for Dev` is this board's Done column, and the ordering gate. A story
arriving there is what makes its tasks eligible for the next sprint.

## `Team <name> — Delivery`

**Board type: Scrum.** Implementation is planned and sprint-shaped.

**Filter**

```sql
project = PROJ AND (
  (issuetype = Task AND parent IN (project = PROJ AND issuetype = Story))
  OR (issuetype IN (Bug, Chore) AND sprint IS NOT EMPTY)
)
ORDER BY Rank ASC
```

Tasks under stories, **plus** standalone bugs and chores — which per
[work types](./work-types.md) skip discovery entirely and enter here directly.
That is the consistency check that the two-board model handles every lane, not
just features.

**Columns**

| Column | Means | Who |
|---|---|---|
| To Do | task cut, branch not started | — |
| In Progress | `/opsx:propose` → `/opsx:apply` | developer |
| In Review | pull request open in Bitbucket | reviewer |
| In Testing | deployed to dev, scenarios being exercised | tester |
| Done | verified, derived change archived (`/opsx:archive`) | developer |

**Swimlanes: by parent story.** This is the single most valuable setting on
either board. It makes the fan-out visible:

```
▾ PROJ-123  Sign in with SSO
    backend  PROJ-124  ██ Done
    frontend PROJ-125  ██ In Progress      ← the story is not done
▾ PROJ-140  Export to CSV
    backend  PROJ-141  ██ In Review
```

A story is finished when its whole lane is finished. Without swimlanes you see
twelve unrelated tasks and cannot tell which story is one task from shipping.

Note this is the *Jira* view of the fan-out. The authoritative one is
`make status`, which reads the repositories rather than the cards — a task can
be marked Done while its OpenSpec change is unarchived, and only the script
catches that.

## Roles are quick filters, not boards

Add these to both boards:

| Quick filter | JQL |
|---|---|
| My work | `assignee = currentUser()` |
| Unassigned | `assignee IS EMPTY` |
| Blocked | `status = Blocked OR labels = blocked` |
| Backend / Frontend / GitOps | `component = <name>` |
| Escaped bugs | `labels = escaped` |

That covers every "board per role" need without fragmenting anything. A
developer opens Delivery and clicks *My work*; an analyst opens Discovery.

## The tester spans both boards

The one role that appears on both, deliberately:

- **Discovery, `In Review`** — hardening scenarios before the intent merges
  (`/sdd:review`, `/sdd:tests`). Cheap fixes.
- **Delivery, `In Testing`** — verifying scenarios against the deployed
  environment.

If your tester only appears on the second, the workflow has quietly reverted to
test-at-the-end and `/sdd:tests` is not being used.

## Where each work type enters

| Work | Enters at | Skips discovery? |
|---|---|---|
| Feature, improvement, experiment | Discovery `To Do` | no |
| Bug (spec already correct) | Delivery `To Do` | yes |
| Hotfix | Delivery `In Progress` directly | yes — retro-spec follows |
| Tech debt, chore, dependency bump | Delivery `To Do` | yes |
| Spike | Discovery `In Analysis`, output is an `analysis.md` | n/a — produces no code |
| Infrastructure | Delivery `To Do` (GitOps task) | usually |

Full rules in [work types](./work-types.md).

## Sprint rhythm

```
Sprint N        Discovery: author intents for N+1
                Delivery:  implement intents merged during N-1

Sprint planning pulls only Stories already in Ready for Dev.
```

That is the whole trick. By the time a developer picks up a task, its intent has
been merged for a week — so the ordering gate is satisfied without anyone
waiting, and `make check` passes because the spec genuinely led the code.

If planning ever pulls a story that is *not* in `Ready for Dev`, stop. That is
the moment the metric gets broken, and it cannot be repaired afterwards.

## Multiple squads

Give each squad its own **pair**. A story is owned by one squad's Discovery
board — the squad that owns the capability, not the repository.

When an intent's tasks span squads, the tasks land on each squad's own Delivery
board while the story stays on the owning squad's Discovery board. The
cross-squad view is not a Jira board at all; it is
`scripts/intent-status.sh <intent-id>`, which reads every repository regardless
of who owns it. Do not build a third board for this — it will drift.

## Relationship to the dashboards

Boards are for moving work; [dashboards](./dashboards.md) are for noticing
patterns.

`Team <name> — Delivery` exists as **both** a board and a daily dashboard, and
they share a name deliberately: same scope, two views. The board shows what to
move today; the dashboard shows what has been stuck for three days.

Discovery has no dashboard. A WIP-limited Kanban board already *is* its
dashboard — if a column is at its limit, that is the whole signal.

## Setup checklist

1. **One workflow scheme for both issue types.** Stories use all seven statuses;
   tasks use five and simply never enter `In Analysis` or `Ready for Dev`. Two
   schemes is unnecessary administration.
2. Create the Discovery board (Kanban) with the status-scoped filter above.
3. Set the WIP limits. A board without them will not hold discovery to one
   sprint ahead, which is the only reason it exists.
4. Create the Delivery board (Scrum), **swimlanes by parent story**.
5. Add the quick filters to both.
6. Restrict the `Ready for Dev` transition to the team lead — it is the ordering
   gate, and it should take a deliberate act.

## Common mistakes

| Mistake | Consequence |
|---|---|
| a board per role | flow invisible, per-role backlogs, bottleneck hidden |
| one board for both tracks | meaningless columns; discovery clogs delivery |
| no WIP limit on discovery | intents written months early go stale before use |
| no swimlanes on delivery | cannot see which story is one task from shipping |
| pulling a story not in `Ready for Dev` | breaks the ordering gate, unfixably |
| trusting Delivery `Done` as truth | a card can be Done with the change unarchived — use `make status` |
| a third, cross-squad board | drifts immediately; `intent-status.sh` is the real view |
