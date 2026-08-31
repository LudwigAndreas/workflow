#!/usr/bin/env bash
# The gate that must pass before a master intent may be archived.
#
#   scripts/intent-gate.sh <intent-id> [--tick]
#
# Archiving a master intent folds its specs into the shared store's
# openspec/specs/, which becomes the baseline every future intent is written
# against. Doing that while a repository is still mid-implementation publishes
# a description of behaviour that does not exist yet.
#
# `openspec archive --yes` only WARNS about unticked boxes and proceeds, and a
# checkbox is just a character someone typed. This script checks the
# repositories themselves: an intent is finished when every repository named in
# intent.md's Fan-out checklist has an ARCHIVED change linking back to it.
#
#   --tick   after verifying, tick the Fan-out boxes for repositories that are
#            genuinely archived. Never ticks anything it could not verify.
#
# Exit 0 = safe to archive. Non-zero = do not archive.

set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

[ $# -ge 1 ] || { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
case "$1" in -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

INTENT=$1; shift
TICK=0
for arg in "$@"; do
  case "$arg" in
    --tick) TICK=1 ;;
    *) die "unknown argument: $arg" ;;
  esac
done

FAILED=0
note_fail() { fail "$*"; FAILED=$((FAILED + 1)); }

head1 "Archive gate: $INTENT"

# --- 1. the intent exists, and is still open ------------------------------
DIR=$(intent_dir "$INTENT") || die "no master intent '$INTENT' in $SPEC_STORE_DIR"
case "$DIR" in
  *"/archive/"*)
    warn "'$INTENT' is already archived at $DIR"
    exit 0
    ;;
esac
ok "intent found at ${DIR#$WORKFLOW_ROOT/}"

JIRA=$(yaml_get "$DIR/.openspec.yaml" jira)
if [ -n "$JIRA" ]; then
  ok "linked to Jira $JIRA"
else
  note_fail "no 'jira:' key in .openspec.yaml - the SDD metric needs it"
fi

# --- 2. the intent validates ----------------------------------------------
if openspec validate "$INTENT" --store "$STORE_ID" >/dev/null 2>&1; then
  ok "openspec validate passes"
else
  note_fail "openspec validate fails - run: openspec validate $INTENT --store $STORE_ID"
fi

# --- 3. the intent declares the implementing repositories -----------------
FANOUT=$(intent_fanout_file "$INTENT") || {
  note_fail "no intent.md - the intent never declared which repositories implement it"
  printf '\n'; fail "GATE FAILED ($FAILED problem(s)) - do not archive"; exit 1
}

REPOS=$(intent_fanout_repos "$INTENT")
if [ -z "$REPOS" ]; then
  note_fail "${FANOUT##*/} has no '## Fan-out' checklist - nothing to verify against"
  printf '\n'; fail "GATE FAILED ($FAILED problem(s)) - do not archive"; exit 1
fi

# --- 4. every declared repository has archived its derived change ---------
head1 "Fan-out"
VERIFIED=""
total=0
while read -r repo key; do
  [ -n "$repo" ] || continue
  total=$((total + 1))
  label=$(printf '%-18s %-10s' "$repo" "$key")

  if [ ! -d "$(repo_path "$repo")" ]; then
    note_fail "${label}no such repository under src/ - the intent names one that does not exist"
    continue
  fi

  out=$(find_derived_change "$repo" "$INTENT" 2>/dev/null) || {
    note_fail "${label}no change links back to this intent"
    continue
  }

  if printf '%s\n' "$out" | grep -q '^active '; then
    open_dir=$(printf '%s\n' "$out" | awk '/^active /{print $2; exit}')
    note_fail "${label}still has an OPEN change: ${open_dir#$WORKFLOW_ROOT/}"
    continue
  fi

  if printf '%s\n' "$out" | grep -q '^archived '; then
    ok "${label}archived"
    VERIFIED="$VERIFIED $repo"
  else
    note_fail "${label}no archived change found"
  fi
done <<EOF
$REPOS
EOF

# --- 5. no checkbox claims more than reality ------------------------------
while read -r repo key; do
  [ -n "$repo" ] || continue
  if intent_fanout_ticked "$INTENT" "$repo"; then
    case " $VERIFIED " in
      *" $repo "*) ;;
      *) note_fail "$repo is ticked in ${FANOUT##*/} but its work is not archived - the checklist is lying" ;;
    esac
  fi
done <<EOF
$REPOS
EOF

# --- 6. optionally tick what was verified ---------------------------------
if [ "$TICK" = "1" ] && [ -n "$VERIFIED" ]; then
  head1 "Ticking verified repositories"
  for repo in $VERIFIED; do
    if intent_fanout_ticked "$INTENT" "$repo"; then
      dim "  $repo already ticked"
      continue
    fi
    tmp="$FANOUT.tmp.$$"
    awk -v want="$repo" '
      /^##[[:space:]]+Fan-out/ { infan=1 }
      infan && /^[[:space:]]*-[[:space:]]*\[[ ]\]/ {
        line = $0
        probe = line
        sub(/^[[:space:]]*-[[:space:]]*\[[ ]\][[:space:]]*/, "", probe)
        sub(/[[:space:]]*\(.*$/, "", probe)
        sub(/[[:space:]]*-.*$/, "", probe)
        gsub(/[`*]/, "", probe)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", probe)
        if (probe == want) { sub(/\[[ ]\]/, "[x]", line); print line; next }
      }
      { print }
    ' "$FANOUT" > "$tmp" && mv "$tmp" "$FANOUT" \
      && ok "ticked $repo" || warn "could not tick $repo"
  done
fi

# --- verdict ---------------------------------------------------------------
printf '\n'
if [ "$FAILED" = "0" ]; then
  ok "GATE PASSED - all $total repositories have archived their work"
  dim "  archive it with:"
  dim "    openspec archive $INTENT --store $STORE_ID"
  dim "  this folds its specs into $STORE_ID/openspec/specs/, which becomes the"
  dim "  baseline every future intent is written against."
  exit 0
fi

fail "GATE FAILED ($FAILED problem(s)) - do not archive '$INTENT'"
dim "  see the full picture with: scripts/intent-status.sh $INTENT"
exit 1
