#!/usr/bin/env bash
# Generate the Qwen Code commands from the Claude Code ones.
#
#   scripts/gen-qwen-commands.sh [--check]
#
# The two CLIs take the same instructions but package them differently:
#
#   Claude   .claude/commands/sdd/intent.md   invoked as /sdd:intent
#            full frontmatter (name, description, allowed-tools, ...)
#   Qwen     .qwen/commands/sdd-intent.md     invoked as /sdd-intent
#            frontmatter carrying description only
#
# Maintaining two copies by hand guarantees they drift, and a drifted command
# is worse than a missing one because nobody notices. So Claude's copy is the
# source and Qwen's is generated. Edit .claude/, then re-run this.
#
#   --check   exit non-zero if anything is out of date, changing nothing.
#             Suitable for a pull-request build.

set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

CHECK=0
for arg in "$@"; do
  case "$arg" in
    --check) CHECK=1 ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

STALE=0
WROTE=0

# render <src.md> -> stdout
render() {
  awk '
    BEGIN { fm = 0; done_fm = 0 }
    NR == 1 && $0 == "---" { fm = 1; print "---"; next }
    fm && $0 == "---" {
      fm = 0; done_fm = 1; print "---"; next
    }
    fm {
      # Qwen frontmatter carries description only.
      if ($0 ~ /^description:/) print $0
      next
    }
    { print }
  ' "$1" \
  | sed -E 's#/sdd:([a-z-]+)#/sdd-\1#g; s#/opsx:([a-z-]+)#/opsx-\1#g'
}

# sync_dir <claude-commands-dir> <qwen-commands-dir>
sync_dir() {
  local src=$1 dst=$2 f base out tmp
  [ -d "$src" ] || return 0
  mkdir -p "$dst"

  for f in "$src"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .md)
    out="$dst/sdd-$base.md"
    tmp="$out.tmp.$$"

    render "$f" > "$tmp" || { rm -f "$tmp"; die "could not render $f"; }

    if [ -f "$out" ] && cmp -s "$tmp" "$out"; then
      rm -f "$tmp"
      dim "  up to date  ${out#$WORKFLOW_ROOT/}"
      continue
    fi

    if [ "$CHECK" = "1" ]; then
      rm -f "$tmp"
      fail "out of date  ${out#$WORKFLOW_ROOT/}"
      STALE=$((STALE + 1))
    else
      mv "$tmp" "$out" || die "could not write $out"
      ok "generated   ${out#$WORKFLOW_ROOT/}"
      WROTE=$((WROTE + 1))
    fi
  done

  # Remove Qwen commands whose Claude source is gone.
  for f in "$dst"/sdd-*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .md); base=${base#sdd-}
    [ -f "$src/$base.md" ] && continue
    if [ "$CHECK" = "1" ]; then
      fail "orphaned    ${f#$WORKFLOW_ROOT/} (no .claude source)"
      STALE=$((STALE + 1))
    else
      rm -f "$f" && warn "removed     ${f#$WORKFLOW_ROOT/} (no .claude source)"
    fi
  done
}

head1 "Workflow repo commands"
sync_dir "$WORKFLOW_ROOT/.claude/commands/sdd" "$WORKFLOW_ROOT/.qwen/commands"

head1 "Repo kit commands"
sync_dir "$WORKFLOW_ROOT/templates/repo-kit/.claude/commands/sdd" \
         "$WORKFLOW_ROOT/templates/repo-kit/.qwen/commands"

printf '\n'
if [ "$CHECK" = "1" ]; then
  if [ "$STALE" = "0" ]; then
    ok "Qwen commands are in sync with Claude"
    exit 0
  fi
  fail "$STALE Qwen command(s) out of sync - run scripts/gen-qwen-commands.sh"
  exit 1
fi
ok "$WROTE command(s) generated"
dim "  re-run after editing anything under .claude/commands/sdd/"
