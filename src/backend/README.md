# backend

the service layer and its HTTP/event APIs — one repository of a multirepo, spec-driven application.

## Getting started

```bash
openspec list --store specifications      # master intents in flight
openspec show <intent-id> --store specifications --json
```

Work always derives from an approved **master intent** in the shared
`specifications` store. Its `handoff.md` says exactly what this repository
owns, the contract it must produce or consume, what it depends on, and how
acceptance is judged.

Then cut the branch and use the **standard** OpenSpec commands — this
repository defines no commands of its own:

```
git checkout -b PROJ-123/PROJ-124-<slug>
/opsx:propose              proposal + specs + design + tasks  (/opsx-propose on Qwen)
/opsx:apply                implement                          (/opsx-apply)
/opsx:archive              fold specs into openspec/specs/    (/opsx-archive)
```

## Layout

```
openspec/
  specs/            how this repository behaves today
  changes/          work in flight, each linked to a master intent
  config.yaml       repo context + the rules the default commands follow
.claude/ .qwen/     the stock opsx commands for both CLIs
```

See [`AGENTS.md`](./AGENTS.md) for the full workflow, the altitude rules, and
the Jira/branch conventions the SDD metric depends on.
