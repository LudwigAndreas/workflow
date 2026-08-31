#!/usr/bin/env bash
# Show where a master intent has got to across every application repository.
#
#   scripts/intent-status.sh                 summarise every intent in flight
#   scripts/intent-status.sh <intent-id>     detail for one intent
#
# This reads the repositories themselves rather than trusting handoff.md's
# checkboxes, so it is the honest answer to "can we archive this yet?".
# Exit status is 0 whatever it finds - use intent-gate.sh to enforce.

set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

case "${1:-}" in -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

# state_of <repo> <intent> -> archived | active | missing
state_of() {
  local repo=$1 intent=$2 out
  out=$(find_derived_change "$repo" "$intent" 2>/dev/null) || { echo missing; return; }
  case "$out" in
    *archived*) echo archived ;;
    *active*)   echo active ;;
    *)          echo missing ;;
  esac
}

report_intent() {
  local intent=$1 dir jira archived_at total done_n line repo key st ticked
  dir=$(intent_dir "$intent") || { fail "no such intent: $intent"; return 1; }

  jira=$(yaml_get "$dir/.openspec.yaml" jira); [ -n "$jira" ] || jira="(no jira key)"
  case "$dir" in *"/archive/"*) archived_at=" ${C_DIM}[archived]${C_OFF}" ;; *) archived_at="" ;; esac

  head1 "$intent  ($jira)$archived_at"

  if [ ! -f "$dir/handoff.md" ]; then
    warn "no handoff.md yet - the intent is still being authored"
    dim "  artifacts: $(ls "$dir" 2>/dev/null | tr '\n' ' ')"
    return 0
  fi

  total=0; done_n=0
  while read -r repo key; do
    [ -n "$repo" ] || continue
    total=$((total + 1))
    st=$(state_of "$repo" "$intent")
    ticked=no
    intent_fanout_ticked "$intent" "$repo" && ticked=yes

    case "$st" in
      archived)
        done_n=$((done_n + 1))
        if [ "$ticked" = yes ]; then
          ok "$(printf '%-18s %-10s' "$repo" "$key")archived, ticked"
        else
          warn "$(printf '%-18s %-10s' "$repo" "$key")archived, but its Fan-out box is NOT ticked"
        fi
        ;;
      active)
        if [ "$ticked" = yes ]; then
          fail "$(printf '%-18s %-10s' "$repo" "$key")ticked, but its change is still OPEN - the tick is wrong"
        else
          info "$(printf '%-18s %-10s' "$repo" "$key")in progress"
        fi
        ;;
      missing)
        if [ "$ticked" = yes ]; then
          fail "$(printf '%-18s %-10s' "$repo" "$key")ticked, but no derived change exists at all"
        else
          warn "$(printf '%-18s %-10s' "$repo" "$key")not started"
        fi
        ;;
    esac
  done <<EOF
$(intent_fanout_repos "$intent")
EOF

  printf '\n'
  if [ "$total" = "0" ]; then
    warn "handoff.md declares no repositories in its '## Fan-out' section"
  elif [ "$done_n" = "$total" ]; then
    ok "$done_n/$total repositories archived - ready to archive the intent"
    dim "  scripts/intent-gate.sh $intent"
  else
    info "$done_n/$total repositories archived"
  fi
}

# ---------------------------------------------------------------- dispatch --

[ -d "$SPEC_STORE_DIR/openspec/changes" ] \
  || die "no store at $SPEC_STORE_DIR - run scripts/setup-openspec.sh"

if [ $# -ge 1 ]; then
  report_intent "$1"
  exit 0
fi

found=0
for d in "$SPEC_STORE_DIR"/openspec/changes/*/; do
  [ -d "$d" ] || continue
  case "$d" in */archive/) continue ;; esac
  found=1
  report_intent "$(basename "${d%/}")"
done

if [ "$found" = "0" ]; then
  head1 "No master intents in flight"
  dim "  the store at $SPEC_STORE_DIR has no open changes"
  dim "  analytics starts one with /sdd:intent"
fi
