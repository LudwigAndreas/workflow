# frontend

**Placeholder.** User-facing web/app client.

This is a reference scaffold, not a real repository yet — it has no git
remote of its own. When the real `frontend` repository exists, promote this
placeholder from the workflow repo root:

```bash
scripts/add-repo.sh frontend <git-url>
```

That replaces this directory with a real `git submodule` pointing at the
real repo. Carry the `openspec/` shape below over into the real repo as-is.

## OpenSpec (Mode B — work here, not in the workflow repo)

This repo owns its own specs: `openspec/specs/` and `openspec/changes/`.
Open your IDE/agent directly in this repo for day-to-day work — `openspec`
commands run here resolve to *this repo's own* specs automatically, no flags
needed.

`openspec/config.yaml` also declares a **reference** to the shared
`specifications` store, for cross-cutting contracts only (things another
repo must agree on, e.g. the API between frontend and backend). To use it:

1. Once per machine, clone `specifications` somewhere and register it:
   ```bash
   git clone git@github.com:LudwigAndreas/specifications.git ~/dev/specifications
   openspec store register ~/dev/specifications --id specifications
   ```
2. From inside this repo, reach a shared cross-repo change directly, without
   leaving this repo or checking out any other:
   ```bash
   openspec list --store specifications
   openspec show <change-id> --store specifications
   openspec status --change <change-id> --store specifications --json
   ```

See the workflow repo's `AGENTS.md` for the full model (when a change
belongs here locally vs. in the shared store, and how frontend/backend stay
in sync without submoduling each other).
