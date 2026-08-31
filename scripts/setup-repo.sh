#!/usr/bin/env bash
# Install the spec-driven kit into an application repository.
#
#   scripts/setup-repo.sh <name> [path]
#
# <name> is the repository name (backend, frontend, gitops_backend, ...).
# [path] defaults to src/<name>; pass a real path to set up a repository that
# is checked out somewhere else entirely - a developer's own clone, for
# instance, which is the normal case in day-to-day use.
#
# Installs, idempotently:
#   .claude/ and .qwen/     the stock opsx commands and skills (openspec init)
#   openspec/config.yaml    repo context + the rules the default commands follow
#   AGENTS.md, CLAUDE.md, QWEN.md, README.md
#
# A repository gets NO custom schema and NO custom command: developers use the
# default spec-driven workflow - /opsx:propose, /opsx:apply, /opsx:archive -
# and everything this team adds on top of it travels as `context`, `rules` and
# `operations` guidance inside openspec/config.yaml, which the CLI injects into
# those default commands.
#
# Re-running is safe: it overwrites the generated kit and leaves specs, changes
# and anything you wrote by hand alone.

set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

[ $# -ge 1 ] || { sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
case "$1" in -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

NAME=$1
TARGET=${2:-$SRC_DIR/$NAME}
KIT="$WORKFLOW_ROOT/templates/repo-kit"

need_cmd openspec
[ -d "$KIT" ] || die "repo kit missing at $KIT"

case "$NAME" in
  backend)          ROLE="the service layer and its HTTP/event APIs" ;;
  frontend)         ROLE="the user-facing web client" ;;
  gitops_backend)   ROLE="Argo CD desired state for the backend" ;;
  gitops_frontend)  ROLE="Argo CD desired state for the frontend" ;;
  gitops_*)         ROLE="Argo CD desired state for ${NAME#gitops_}" ;;
  *)                ROLE="application repository" ;;
esac

mkdir -p "$TARGET" || die "cannot create $TARGET"
TARGET=$(cd "$TARGET" && pwd)

head1 "$NAME  ->  $TARGET"

# --- 1. opsx commands and skills, for both CLIs --------------------------
if [ -d "$TARGET/.claude/commands/opsx" ] && [ -d "$TARGET/.qwen/commands" ]; then
  ok "opsx commands present for Claude and Qwen"
else
  info "installing opsx commands and skills"
  ( cd "$TARGET" && openspec init . --tools claude,qwen --force --no-animation </dev/null ) >/dev/null 2>&1 \
    || die "openspec init failed in $TARGET"
  ok "opsx commands and skills installed"
fi

# --- 2. config.yaml, rendered for this repository ------------------------
sed -e "s#__REPO__#$NAME#g" -e "s#__REPO_ROLE__#$ROLE#g" \
  "$KIT/openspec/config.yaml.tmpl" > "$TARGET/openspec/config.yaml" \
  || die "could not render openspec/config.yaml"
ok "openspec/config.yaml written"

# An earlier version of this kit installed a forked `component-change` schema
# here. Remove it, or the CLI keeps resolving the old workflow.
if [ -d "$TARGET/openspec/schemas/component-change" ]; then
  rm -rf "$TARGET/openspec/schemas/component-change"
  rmdir "$TARGET/openspec/schemas" 2>/dev/null || true
  warn "removed the obsolete component-change schema"
fi
if [ -d "$TARGET/.claude/commands/sdd" ] || ls "$TARGET/.qwen/commands"/sdd-*.md >/dev/null 2>&1; then
  rm -rf "$TARGET/.claude/commands/sdd"
  rm -f "$TARGET/.qwen/commands"/sdd-*.md
  warn "removed the obsolete repo-local /sdd commands - use /opsx:propose, /opsx:apply, /opsx:archive"
fi

# --- 3. agent guides ------------------------------------------------------
if [ -f "$KIT/AGENTS.md.tmpl" ]; then
  sed -e "s#__REPO__#$NAME#g" -e "s#__REPO_ROLE__#$ROLE#g" \
    "$KIT/AGENTS.md.tmpl" > "$TARGET/AGENTS.md"
  for f in CLAUDE.md QWEN.md; do
    printf '# %s\n\nSee [`AGENTS.md`](./AGENTS.md) - the spec-driven workflow for `%s`.\n' \
      "${f%.md}" "$NAME" > "$TARGET/$f"
  done
  ok "AGENTS.md, CLAUDE.md and QWEN.md written"
fi

# --- 4. README ------------------------------------------------------------
if [ -f "$KIT/README.md.tmpl" ]; then
  sed -e "s#__REPO__#$NAME#g" -e "s#__REPO_ROLE__#$ROLE#g" \
    "$KIT/README.md.tmpl" > "$TARGET/README.md"
  ok "README.md written"
fi

mkdir -p "$TARGET/openspec/specs" "$TARGET/openspec/changes/archive"
[ -f "$TARGET/openspec/specs/.gitkeep" ] || : > "$TARGET/openspec/specs/.gitkeep"
[ -f "$TARGET/openspec/changes/archive/.gitkeep" ] || : > "$TARGET/openspec/changes/archive/.gitkeep"

printf '\n'
if ( cd "$TARGET" && openspec schema which spec-driven >/dev/null 2>&1 ); then
  ok "$NAME is ready - developers use /opsx:propose, /opsx:apply, /opsx:archive"
else
  warn "$NAME installed, but the default spec-driven schema did not resolve - check $TARGET/openspec/config.yaml"
fi
