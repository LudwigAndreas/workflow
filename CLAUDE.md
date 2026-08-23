# CLAUDE.md

Architecture, conventions and the reasoning behind them live in
[`AGENTS.md`](./AGENTS.md). Read it before changing anything structural.
This file is only the short list of things that are easy to get wrong when
working unattended.

## Working rules

- **Every document has a Russian twin.** `docs/foo.md` requires
  `docs/foo.ru.md`, cross-linked at the top with flag links. A new doc is not
  finished until both exist and both are in the README tables (EN and RU).

- **Gate numbering is the spine.** The eleven gates are defined in
  [`docs/pipeline.md`](./docs/pipeline.md) and referenced by number across
  every role page, both languages, and `.claude/commands/sdd/*`. Renumbering
  is never a local edit — grep for `gate <n>` and `шлюз <n>` and update all of
  them in the same change.

- **`scripts/jira-release.sh` and `scripts/jira-deploy.sh` write to real Jira
  tickets.** Both stamp Fix Versions and post comments across every issue in a
  release range. Always run `--dry-run` first; these are deliberately left out
  of the permission allowlist so they prompt.

- **`scripts/promote.sh --push` / `--pr` pushes to a GitOps repo**, which
  deploys. Not allowlisted either, for the same reason.

- **Verify links after editing docs.** Many pages cross-reference each other by
  anchor, including Cyrillic anchors. Broken anchors are silent — check them
  rather than assuming.

- **Shell scripts:** `bash -n` every script after editing, and keep them
  POSIX-ish bash with `set -uo pipefail`. They are meant to be runnable by hand
  when a pipeline is down, so avoid dependencies beyond `git`, `curl`, `jq`
  and `yq`.

## Layout reminders

- `docs/` — pipeline, work types, scrum, release, automation, build guide, roles
- `scripts/` — the metric check plus the release/Jira/GitOps automation
- `.github/workflows/` — **templates** the application and GitOps repos copy in;
  they do not run usefully in this repo
- `src/*` — placeholders until promoted with `scripts/add-repo.sh`
- `specifications/` — submodule; the shared spec store, kept deliberately small
