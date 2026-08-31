# Dashboards

🇬🇧 English | [🇷🇺 Русский](./dashboards.ru.md)

Two Jira dashboards per team, deliberately on **different cadences**. Mixing
them is the most common way a dashboard stops being read.

Dashboards are for noticing patterns; [boards](./boards.md) are for moving work.
Read that page first if you have not set the boards up yet.

| Dashboard | Cadence | Answers | Owner |
|---|---|---|---|
| `Team <name> — Delivery` | daily | is anything stuck right now? | team lead |
| `Team <name> — Quality` | **monthly** | is the process actually working? | team lead + tester |

Delivery numbers move hourly and demand a response today. Quality numbers move
over weeks and demand a response to the *process*. Put a quality number on a
daily board and it becomes noise people learn to scroll past; check it monthly
and it becomes the one number that tells you whether any of this is working.

---

## `Team <name> — Delivery` (daily)

What a team lead looks at in standup. Everything here should be actionable
before lunch.

### Gadgets

| # | Gadget | Shows |
|---|---|---|
| 1 | Filter Results | stories blocked, or in a status > 3 days |
| 2 | Two Dimensional Filter Statistics | Assignee × Status, current sprint |
| 3 | Filter Results | intents merged, tasks not started |
| 4 | Sprint Health / Burndown | sprint scope and pace |
| 5 | Filter Results | `SDD`-labelled stories failing the metric |

### JQL

```sql
-- 1. blocked or stalled
project = PROJ AND sprint IN openSprints()
  AND (status = Blocked OR status CHANGED BEFORE -3d TO status)
  ORDER BY priority DESC

-- 3. merged intent, nobody started — tomorrow's critical path
project = PROJ AND issuetype = Task AND status = "To Do"
  AND parent IN (
    project = PROJ AND labels = SDD AND status = "Ready for Dev"
  )

-- 5. labelled SDD but not following it
project = PROJ AND labels = SDD AND status != Done
  AND issueFunction NOT IN hasLinkType("implements")
```

The last one is a convenience only. **The real metric check is
`make check`**, because the condition that matters — the intent merged before
the first commit — lives in git, not in Jira. Jira cannot see it. See
[Jira ↔ SDD](./jira-sdd-mapping.md).

The fan-out itself is not on this dashboard either, for the same reason:
`scripts/intent-status.sh` reads the repositories, and no Jira gadget can.
Run `make status` alongside the board.

---

## `Team <name> — Quality` (monthly) — optional

Optional, and worth it. This is the outcome measure: Delivery tells you whether
work is moving, Quality tells you whether it was worth moving.

**Review it monthly, not daily.** Once a month, in a fixed slot, with the team
lead and the tester present. A single month's numbers mean very little; the
*trend across three or four* is the signal.

### Gadgets

| # | Gadget | Shows |
|---|---|---|
| 1 | Created vs Resolved Chart | escaped defects, monthly, 6-month window |
| 2 | Two Dimensional Filter Statistics | open bugs: Priority × Component |
| 3 | Average Age Chart | average age of open bugs, in days |
| 4 | Pie Chart *(optional)* | escaped defects by root-cause label |

### 1. Escaped defects

A defect that reached production — one that verification should have caught but
did not.

Measuring it needs one team convention, because Jira cannot infer it. Cheapest
version that works:

> At triage, every bug gets **either** `found-in-test` **or** `escaped`.

One label, applied once, by whoever triages. If you already have a
"Found in Environment" custom field, use that instead and skip the label.

```sql
-- escaped defects raised this month
project = PROJ AND issuetype = Bug AND labels = escaped
  AND created >= startOfMonth(-1) AND created < startOfMonth()

-- the ratio that actually matters
project = PROJ AND issuetype = Bug AND labels IN (escaped, found-in-test)
  AND created >= startOfMonth(-6)
```

Use a **Created vs Resolved Chart** with the escaped filter, monthly periods,
six months. The absolute count is nearly meaningless — team size, release
frequency and traffic all move it. The **trend** and the **escaped : found-in-test
ratio** are the numbers to read.

**What this is really measuring.** In this workflow an escaped defect almost
always traces back to a missing *unhappy-path scenario* in a master intent.
Verification runs the scenarios in the intent's `specs/`; if the scenario was
never written, nobody was ever going to catch it. So when the escaped count
rises, the fix is upstream — in `/sdd:review` and `/sdd:tests`, not in "test
harder". This is the loop that closes the process:

```
escaped defect ──▶ which scenario was missing? ──▶ was it missing because
                                                   the intent lacked it?
                          │                                  │
                          ▼                                  ▼
                 add it to the intent            tighten the review checklist
                 (correction in the store)       for that class of scenario
```

Ask that question for **every** escaped defect at the monthly review. It takes
two minutes each and it is the entire value of the dashboard.

### 2. Open bugs by priority

```sql
project = PROJ AND issuetype = Bug AND resolution = Unresolved
  ORDER BY priority DESC, created ASC
```

Use **Two Dimensional Filter Statistics**, Priority × Component. The
per-component split is what makes it actionable: twelve open bugs spread evenly
is a backlog, twelve in one component is a design problem in that component.

Read the **shape**, not the total:

| Shape | Means |
|---|---|
| high-priority bugs present at all | the lane in [work types](./work-types.md) is not being used |
| one component dominating | that component needs a tech-debt intent, not more bug fixes |
| lots of Low, none resolved | be honest — close them as `Won't Do`, or raise their priority |

That last row matters. A permanently growing Low pile is not a backlog, it is a
list of things you have collectively decided not to do. Saying so is cheaper
than re-reading them every month.

### 3. Average age of open bugs

Use the **Average Age Chart** gadget (unresolved issues only), monthly periods,
six months.

```sql
project = PROJ AND issuetype = Bug AND resolution = Unresolved
```

The trend is the signal:

| Trend | Means |
|---|---|
| flat and low | bugs are triaged and fixed or closed promptly |
| **rising steadily** | bugs are being accepted faster than they are resolved — the usual cause is bug work never being scheduled against sprint capacity |
| sudden fall | check it is real, not a bulk-close |

Average age is easy to game and worth watching for exactly that. A month where
someone bulk-closes stale bugs shows a beautiful drop and means nothing. Read it
next to the open-bug count, never alone.

---

## Guardrails

- **Do not review Quality daily.** These numbers cannot move meaningfully in a
  day. Watching them daily produces reaction to noise, and teaches everyone that
  dashboards are for ignoring.
- **Do not turn any of these into a target.** An escaped-defect target produces
  bugs relabelled `found-in-test`; an average-age target produces bulk closes.
  Both destroy the measurement and neither improves the software.
- **Do not put the SDD metric here.** `make check` is the authority, because the
  ordering condition lives in git. A Jira gadget can only ever approximate it.
- **Two dashboards, not five.** Every additional dashboard halves the attention
  paid to the others.

## Setting them up

1. Create the two dashboards, named exactly `Team <name> — Delivery` and
   `Team <name> — Quality`, so they sort together and are obvious to find.
2. Share both with the team; make Delivery the team's default dashboard.
3. Add the `escaped` / `found-in-test` labels to the bug triage workflow — the
   Quality dashboard is worthless without that one convention.
4. Put the monthly Quality review in the calendar as a recurring 30-minute slot.
   A dashboard nobody has agreed to look at is not a dashboard.
