#!/usr/bin/env bash
# Prepare this checkout for spec-driven work. Idempotent - safe to re-run.
#
#   scripts/setup-openspec.sh [--repos]
#
# Without arguments: check out submodules and register the shared
# `specifications` store on this machine, so `--store specifications` works
# from any directory afterwards.
#
# With --repos: additionally run scripts/setup-repo.sh for every placeholder
# under src/ that is not wired up yet.

set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

DO_REPOS=0
for arg in "$@"; do
  case "$arg" in
    --repos) DO_REPOS=1 ;;
    -h|--help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

need_cmd git
need_cmd openspec

cd "$WORKFLOW_ROOT" || die "cannot cd to $WORKFLOW_ROOT"

head1 "Submodules"
if [ -f .gitmodules ]; then
  git submodule update --init --recursive || die "submodule update failed"
  ok "submodules checked out"
else
  info "no .gitmodules - nothing to check out"
fi

head1 "Shared specification store"
if [ ! -d "$SPEC_STORE_DIR/openspec" ]; then
  die "$SPEC_STORE_DIR has no openspec/ root. Is the submodule checked out?"
fi

# `store register` is not idempotent in the sense of being silent: registering
# an already-registered id is fine, but we only want the noise once.
if store_registered; then
  ok "store '$STORE_ID' already registered"
else
  if openspec store register "$SPEC_STORE_DIR" --id "$STORE_ID" --yes >/dev/null 2>&1; then
    ok "registered store '$STORE_ID' -> $SPEC_STORE_DIR"
  else
    die "could not register store '$STORE_ID'. Try: openspec store register '$SPEC_STORE_DIR' --id $STORE_ID --yes"
  fi
fi

current_root=$(openspec store list --json 2>/dev/null \
  | sed -n "s/.*\"id\":[[:space:]]*\"$STORE_ID\"[^}]*\"root\":[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1)
if [ -n "$current_root" ] && [ "$current_root" != "$SPEC_STORE_DIR" ]; then
  warn "store '$STORE_ID' points at $current_root, not $SPEC_STORE_DIR"
  warn "re-register it if this checkout should own the id:"
  dim "  openspec store unregister $STORE_ID && openspec store register '$SPEC_STORE_DIR' --id $STORE_ID --yes"
fi

head1 "Application repositories"
found=0
for repo in $(repo_list); do
  found=$((found + 1))
  ok "$repo is wired up"
done

pending=""
if [ -d "$SRC_DIR" ]; then
  for d in "$SRC_DIR"/*/; do
    [ -d "$d" ] || continue
    [ -f "${d}openspec/config.yaml" ] && continue
    pending="$pending $(basename "$d")"
  done
fi

if [ -n "$pending" ]; then
  for repo in $pending; do
    if [ "$DO_REPOS" = "1" ]; then
      info "setting up $repo"
      "$WORKFLOW_ROOT/scripts/setup-repo.sh" "$repo" || warn "setup-repo.sh failed for $repo"
    else
      warn "$repo is not wired up yet"
    fi
  done
  [ "$DO_REPOS" = "1" ] || dim "  run scripts/setup-openspec.sh --repos to wire them up"
fi

[ "$found" = "0" ] && [ -z "$pending" ] && info "no repositories under src/ yet"

head1 "Doctor"
openspec doctor --store "$STORE_ID" 2>&1 | sed 's/^/  /' || true

printf '\n'
ok "setup complete"
dim "  next: make status      see what is in flight"
dim "        make check       does this checkout satisfy the SDD metric?"
