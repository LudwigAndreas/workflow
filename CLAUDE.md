# CLAUDE.md

Architecture, conventions and the reasoning behind them live in
[`AGENTS.md`](./AGENTS.md). Read it before changing anything structural. This
file is the short list of things that are easy to get wrong when working
unattended.

## Working rules

- **Every document has a Russian twin.** `docs/foo.md` requires
  `docs/foo.ru.md`, cross-linked at the top with flag links. A new doc is not
  finished until both exist and both appear in the README tables (EN and RU).

- **The master intent is a meta layer above OpenSpec, never a split of it.**
  Analytics writes `intent.md` + `specs/` — business need, whole-system
  context, business rules. The developer feeds that into the *unmodified*
  workflow in their own repo and writes `proposal.md`, `specs/`, `design.md`
  and `tasks.md` themselves. Never move a developer artifact into the store,
  and never let analytics write what a repository should build.

- **Do not override the default OpenSpec commands.** Application repositories
  use stock `/opsx:propose`, `/opsx:apply` and `/opsx:archive` with the stock
  `spec-driven` schema. Anything the agent needs to know there goes into
  `templates/repo-kit/openspec/config.yaml.tmpl` as `context`, `rules` or
  `operations` guidance — never into a forked schema or a repo-local `/sdd:*`
  command. The only custom step is `/sdd:intent`, which has no stock
  equivalent because it spans every repository at once.

- **`.claude/commands/sdd/*.md` is the source; `.qwen/` is generated.** After
  editing a command, run `make commands`. Never hand-edit a file under
  `.qwen/commands/`. `make commands-check` fails if they have drifted.

- **Never hand-tick a Fan-out checkbox** in an intent's `intent.md`. Use
  `scripts/intent-gate.sh <id> --tick`, which ticks only what it verified. The
  gate exists precisely to catch hand-ticked boxes.

- **Never archive a master intent without the gate passing**, and never reach
  for `openspec archive --yes` to get past a failing fan-out. Archiving folds
  specs into the shared baseline that every future intent is written against.

- **`openspec init` refuses to run while `store:` is set** in
  `openspec/config.yaml`. To reinstall commands in this repo, temporarily
  replace the config with `schema: spec-driven`, init, then restore it.

- **Shell scripts:** `bash -n` after every edit. Keep them bash 3.2 compatible
  and limited to `git`, `sed`, `grep`, `awk` and `jq`. They must stay runnable
  by hand when a pipeline is down.

- **Watch the sed delimiter.** Repo role strings contain `/`
  (`"the service layer and its HTTP/event APIs"`), so `setup-repo.sh` uses `#`
  as the substitution delimiter. Do not change it back.

- **Report the ordering failure honestly.** If a branch was cut before its
  intent merged, the story did not follow SDD. Never suggest rewriting history
  to make the metric pass.

## Layout reminders

- `docs/` — workflow, master intent, work types, Jira mapping, roles
- `specifications/` — submodule; the shared store and the `master-intent` schema
- `src/*` — application repos, each with its own OpenSpec root
- `templates/repo-kit/` — what `setup-repo.sh` installs; edit here, then
  re-run `scripts/setup-repo.sh <name>`, never edit `src/*` by hand
- `scripts/` — setup, fan-out status, the archive gate, the metric
