#!/usr/bin/env bash
# Pull the latest shared specifications and report where every repo stands.
#
#   scripts/sync.sh [--no-pull]
#
# The `specifications` submodule tracks its branch and is meant to be bumped
# often - it is the baseline everyone writes intents against, so a stale copy
# means authoring against behaviour that has already changed.

set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

PULL=1
for arg in "$@"; do
  case "$arg" in
    --no-pull) PULL=0 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

need_cmd git
cd "$WORKFLOW_ROOT" || die "cannot cd to $WORKFLOW_ROOT"

head1 "Shared specifications"
if [ ! -d "$SPEC_STORE_DIR/.git" ] && [ ! -f "$SPEC_STORE_DIR/.git" ]; then
  die "$SPEC_STORE_DIR is not a git checkout - run scripts/setup-openspec.sh"
fi

before=$(git -C "$SPEC_STORE_DIR" rev-parse --short HEAD 2>/dev/null)
if [ "$PULL" = "1" ]; then
  if git -C "$SPEC_STORE_DIR" pull --ff-only 2>&1 | sed 's/^/  /'; then
    after=$(git -C "$SPEC_STORE_DIR" rev-parse --short HEAD 2>/dev/null)
    if [ "$before" = "$after" ]; then
      ok "already up to date ($after)"
    else
      ok "updated $before -> $after"
      git -C "$SPEC_STORE_DIR" log --oneline "$before..$after" 2>/dev/null | sed 's/^/    /'
    fi
  else
    warn "could not fast-forward - resolve it by hand in $SPEC_STORE_DIR"
  fi
else
  info "skipping pull (--no-pull); at $before"
fi

if ! git -C "$SPEC_STORE_DIR" diff --quiet 2>/dev/null; then
  warn "you have uncommitted changes in specifications/"
  git -C "$SPEC_STORE_DIR" status --short 2>/dev/null | sed 's/^/    /'
fi

head1 "Specs baseline"
n=$(find "$SPEC_STORE_DIR/openspec/specs" -name spec.md 2>/dev/null | wc -l | tr -d ' ')
info "$n capability spec(s) in the shared baseline"
n=$(find "$SPEC_STORE_DIR/openspec/changes" -maxdepth 1 -mindepth 1 -type d ! -name archive 2>/dev/null | wc -l | tr -d ' ')
info "$n master intent(s) in flight"

head1 "Application repositories"
any=0
for repo in $(repo_list); do
  any=1
  root=$(repo_path "$repo")
  if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    br=$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null)
    dirty=""
    git -C "$root" diff --quiet 2>/dev/null || dirty=" ${C_YELLOW}(dirty)${C_OFF}"
    printf '  %-18s %s%s\n' "$repo" "$br" "$dirty"
  else
    printf '  %-18s %s\n' "$repo" "$(dim 'not a git checkout yet')"
  fi
done
[ "$any" = "1" ] || info "no repositories wired up under src/ yet"

printf '\n'
dim "  scripts/intent-status.sh   where every intent has got to"
