#!/usr/bin/env bash
# Does this work satisfy the company's "story followed SDD" metric?
#
#   scripts/check-sdd.sh                      check the nearest openspec root
#   scripts/check-sdd.sh --store specifications
#   scripts/check-sdd.sh --change <id> [--store <id>]
#   scripts/check-sdd.sh --all                every repo under src/, plus the store
#
# The metric requires, for a story to count:
#   * the Jira story carries the label `SDD`
#   * a git branch is named after the story key (a child task's branch counts)
#
# Satisfying it mechanically needs more than that, so this also asserts the
# things that make the link real rather than nominal:
#   * the change records `jira:`
#   * a derived change records `intent:` and that intent exists
#   * `openspec validate` passes
#   * the branch name resolves to the story (and task, when tasks own branches)
#   * the intent was merged BEFORE the branch was cut - this is what separates
#     "followed SDD" from "labelled SDD", and it is not fixable after the fact
#
# Export JIRA_URL and JIRA_TOKEN to additionally assert the `SDD` label and the
# issue type against Jira itself. Without them those checks are skipped, not
# silently passed.
#
# Exit 0 = the metric is satisfied.

set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

STORE=""
CHANGE=""
ALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --store)  STORE=${2:-}; shift 2 ;;
    --change) CHANGE=${2:-}; shift 2 ;;
    --all)    ALL=1; shift ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

FAILED=0
CHECKED=0
note_fail() { fail "$*"; FAILED=$((FAILED + 1)); }

KEY_RE='[A-Z][A-Z0-9_]*-[0-9]+'

# ------------------------------------------------------------------ jira ----

jira_issue_json() {
  local key=$1
  [ -n "${JIRA_URL:-}" ] && [ -n "${JIRA_TOKEN:-}" ] || return 1
  command -v curl >/dev/null 2>&1 || return 1
  curl -sS -f -H "Authorization: Bearer $JIRA_TOKEN" \
    -H "Accept: application/json" \
    "${JIRA_URL%/}/rest/api/2/issue/${key}?fields=labels,issuetype,parent" 2>/dev/null
}

check_jira_label() {
  local key=$1 json labels type
  json=$(jira_issue_json "$key") || { dim "    jira: not checked (JIRA_URL/JIRA_TOKEN unset or unreachable)"; return 0; }
  command -v jq >/dev/null 2>&1 || { dim "    jira: not checked (jq not installed)"; return 0; }

  labels=$(printf '%s' "$json" | jq -r '.fields.labels // [] | join(",")' 2>/dev/null)
  type=$(printf '%s' "$json" | jq -r '.fields.issuetype.name // "?"' 2>/dev/null)

  case ",$labels," in
    *,SDD,*) ok "    jira $key is labelled SDD (type: $type)" ;;
    *)
      # A task inherits the metric from its parent story, so check upward.
      local parent
      parent=$(printf '%s' "$json" | jq -r '.fields.parent.key // empty' 2>/dev/null)
      if [ -n "$parent" ]; then
        local pjson plabels
        pjson=$(jira_issue_json "$parent") || pjson=""
        plabels=$(printf '%s' "$pjson" | jq -r '.fields.labels // [] | join(",")' 2>/dev/null)
        case ",$plabels," in
          *,SDD,*) ok "    jira $key inherits SDD from parent $parent" ; return 0 ;;
        esac
      fi
      note_fail "    jira $key is not labelled SDD (type: $type)"
      ;;
  esac
}

# --------------------------------------------------------------- checking ---

# check_change <change-dir> <label> [store-id]
check_change() {
  local dir=$1 label=$2 store=${3:-} id jira intent branch store_flag
  id=$(basename "$dir")
  CHECKED=$((CHECKED + 1))
  head1 "$label  $id"

  # -- the Jira link
  jira=$(yaml_get "$dir/.openspec.yaml" jira)
  if [ -n "$jira" ] && printf '%s' "$jira" | grep -Eq "^$KEY_RE$"; then
    ok "  jira: $jira"
    check_jira_label "$jira"
  else
    note_fail "  no valid 'jira:' key in .openspec.yaml (found: '${jira:-}')"
  fi

  # -- the intent backlink, for derived changes
  intent=$(yaml_get "$dir/.openspec.yaml" intent)
  if [ -n "$intent" ]; then
    if intent_dir "$intent" >/dev/null 2>&1; then
      ok "  derives from intent: $intent"
    else
      note_fail "  declares intent '$intent', which does not exist in the store"
    fi
  elif [ -n "$store" ]; then
    : # a master intent has no parent; correct
  else
    note_fail "  no 'intent:' key - a repository change must derive from an approved master intent"
  fi

  # -- validation
  store_flag=""
  [ -n "$store" ] && store_flag="--store $store"
  if ( cd "$(dirname "$(dirname "$dir")")/.." 2>/dev/null || cd "$WORKFLOW_ROOT"; \
       openspec validate "$id" $store_flag >/dev/null 2>&1 ); then
    ok "  openspec validate passes"
  else
    note_fail "  openspec validate fails - run: openspec validate $id $store_flag"
  fi

  # -- the branch
  branch=$(git -C "$(dirname "$dir")" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch=""
  if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
    dim "  branch: not on a named branch - skipping branch checks"
  elif [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    dim "  branch: on $branch - branch checks apply to feature branches only"
  else
    if printf '%s' "$branch" | grep -Eq "^$KEY_RE/$KEY_RE-.+$"; then
      ok "  branch '$branch' names both story and task"
    elif printf '%s' "$branch" | grep -Eq "^$KEY_RE-.+$"; then
      ok "  branch '$branch' names the story"
    else
      note_fail "  branch '$branch' does not match <STORY>-<slug> or <STORY>/<TASK>-<slug>"
    fi

    if [ -n "$jira" ]; then
      case "$branch" in
        *"$jira"*) ok "  branch carries $jira" ;;
        *) note_fail "  branch '$branch' does not carry the change's key $jira" ;;
      esac
    fi
  fi
}

# check_ordering <repo> <intent>
# The spec must have been merged before the code branch was cut.
check_ordering() {
  local repo=$1 intent=$2 first_commit intent_merge repo_root
  repo_root=$(repo_path "$repo")
  git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$SPEC_STORE_DIR" rev-parse --git-dir >/dev/null 2>&1 || return 0

  intent_merge=$(git -C "$SPEC_STORE_DIR" log --diff-filter=A --format=%ct -1 \
    -- "openspec/changes/$intent" "openspec/changes/archive/*-$intent" 2>/dev/null | head -1)
  [ -n "$intent_merge" ] || return 0

  first_commit=$(git -C "$repo_root" log --format=%ct --reverse \
    "$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null)" \
    --not main master 2>/dev/null | head -1)
  [ -n "$first_commit" ] || return 0

  if [ "$first_commit" -ge "$intent_merge" ]; then
    ok "  intent landed before the first commit on this branch"
  else
    note_fail "  the first commit predates the intent landing - the spec followed the code, not the other way round. This is not fixable after the fact; report it honestly."
  fi
}

# -------------------------------------------------------------- dispatch ----

if [ -n "$CHANGE" ]; then
  if [ -n "$STORE" ]; then
    d="$SPEC_STORE_DIR/openspec/changes/$CHANGE"
    [ -d "$d" ] || d=$(intent_dir "$CHANGE") || die "no change '$CHANGE' in store '$STORE'"
    check_change "$d" "master intent" "$STORE"
  else
    d="openspec/changes/$CHANGE"
    [ -d "$d" ] || die "no change '$CHANGE' in $(pwd)/openspec/changes"
    check_change "$(cd "$d" && pwd)" "change"
  fi
elif [ "$ALL" = "1" ]; then
  for d in "$SPEC_STORE_DIR"/openspec/changes/*/; do
    [ -d "$d" ] || continue
    case "$d" in */archive/) continue ;; esac
    check_change "${d%/}" "master intent" "$STORE_ID"
  done
  for repo in $(repo_list); do
    for d in "$(repo_path "$repo")"/openspec/changes/*/; do
      [ -d "$d" ] || continue
      case "$d" in */archive/) continue ;; esac
      check_change "${d%/}" "$repo"
      i=$(yaml_get "${d%/}/.openspec.yaml" intent)
      [ -n "$i" ] && check_ordering "$repo" "$i"
    done
  done
elif [ -n "$STORE" ]; then
  for d in "$SPEC_STORE_DIR"/openspec/changes/*/; do
    [ -d "$d" ] || continue
    case "$d" in */archive/) continue ;; esac
    check_change "${d%/}" "master intent" "$STORE"
  done
else
  [ -d openspec/changes ] || die "no openspec/changes here. Run inside a repository, or pass --store $STORE_ID / --all."
  for d in openspec/changes/*/; do
    [ -d "$d" ] || continue
    case "$d" in */archive/) continue ;; esac
    check_change "$(cd "${d%/}" && pwd)" "change"
  done
fi

printf '\n'
if [ "$CHECKED" = "0" ]; then
  warn "nothing in flight to check"
  exit 0
fi
if [ "$FAILED" = "0" ]; then
  ok "SDD metric satisfied ($CHECKED change(s) checked)"
  exit 0
fi
fail "SDD metric NOT satisfied - $FAILED problem(s) across $CHECKED change(s)"
exit 1
