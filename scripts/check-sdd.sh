#!/usr/bin/env bash
# Check that in-flight changes satisfy the "story followed SDD" metric.
#
# Usage:
#   scripts/check-sdd.sh [--store <id>] [--change <id>] [--base <ref>] [--no-branch]
#
# Checks, per non-archived change:
#   1. .openspec.yaml carries a jira: key             (Story <-> change link)
#   2. openspec validate passes                       (spec delta is well-formed)
#   3. every tasks.md section heading carries a Jira key
#   4. the current branch matches the naming pattern  (skipped on main/detached)
#   5. proposal.md was merged before the branch was cut (spec-before-code)
#   6. optional: Jira says the story is a Story labelled SDD
#      (only when JIRA_URL and JIRA_TOKEN are exported)
#
# Exits non-zero if any check fails. See docs/jira-sdd-mapping.md.

set -uo pipefail

STORE_FLAG=()
ONLY_CHANGE=""
BASE_REF="${SDD_BASE_REF:-origin/main}"
CHECK_BRANCH=1

while [ $# -gt 0 ]; do
  case "$1" in
    --store)     STORE_FLAG=(--store "$2"); shift 2 ;;
    --change)    ONLY_CHANGE="$2"; shift 2 ;;
    --base)      BASE_REF="$2"; shift 2 ;;
    --no-branch) CHECK_BRANCH=0; shift ;;
    -h|--help)   sed -n '2,18p' "$0"; exit 0 ;;
    *)           echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

KEY_RE='[A-Z][A-Z0-9]+-[0-9]+'
BRANCH_RE="^(${KEY_RE}/)?${KEY_RE}-[a-z0-9][a-z0-9-]*$"

failures=0
checks=0

pass() { checks=$((checks+1)); printf '  \033[32m/\033[0m %s\n' "$1"; }
fail() { checks=$((checks+1)); failures=$((failures+1)); printf '  \033[31mX\033[0m %s\n' "$1"; }
skip() { printf '  \033[90m-\033[0m %s\n' "$1"; }
info() { printf '\033[90m%s\033[0m\n' "$1"; }

for dep in openspec jq; do
  command -v "$dep" >/dev/null 2>&1 || { echo "error: '$dep' not found on PATH" >&2; exit 2; }
done

listing="$(openspec list "${STORE_FLAG[@]+"${STORE_FLAG[@]}"}" --json 2>/dev/null)" || {
  echo "error: 'openspec list' failed - is there an OpenSpec root here?" >&2
  exit 2
}

root="$(printf '%s' "$listing" | jq -r '.root.path // empty')"
if [ -z "$root" ]; then
  echo "error: could not resolve the OpenSpec root" >&2
  exit 2
fi
changes_dir="$root/openspec/changes"

change_names=()
while IFS= read -r line; do
  [ -n "$line" ] && change_names+=("$line")
done < <(printf '%s' "$listing" | jq -r '.changes[].name')

if [ -n "$ONLY_CHANGE" ]; then
  change_names=("$ONLY_CHANGE")
fi

echo "SDD metric check"
info "root: $root"

# ---------------------------------------------------------------- branch name
branch=""
if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  branch="$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
fi

if [ "$CHECK_BRANCH" -eq 1 ] && [ -n "$branch" ]; then
  echo
  echo "branch"
  case "$branch" in
    main|master|HEAD)
      skip "on '$branch' - branch naming is checked on feature branches only" ;;
    *)
      if printf '%s' "$branch" | grep -Eq "$BRANCH_RE"; then
        pass "'$branch' matches the required pattern"
      else
        fail "'$branch' does not match ${BRANCH_RE}
      expected PROJ-123-slug, or PROJ-123/PROJ-124-slug for a multi-repo story"
      fi ;;
  esac
fi

if [ "${#change_names[@]}" -eq 0 ]; then
  echo
  info "no in-flight changes to check"
fi

# -------------------------------------------------------------- per-change
for name in "${change_names[@]+"${change_names[@]}"}"; do
  [ -n "$name" ] || continue
  dir="$changes_dir/$name"
  echo
  echo "change: $name"

  if [ ! -d "$dir" ]; then
    fail "directory not found at $dir"
    continue
  fi

  # 1. jira: key present and well-formed
  meta="$dir/.openspec.yaml"
  jira_key=""
  if [ -f "$meta" ]; then
    jira_key="$(grep -Eo "^jira:[[:space:]]*${KEY_RE}" "$meta" 2>/dev/null | grep -Eo "${KEY_RE}" || true)"
  fi
  if [ -n "$jira_key" ]; then
    pass "linked to Jira story $jira_key"
  else
    fail "no valid 'jira:' key in .openspec.yaml
      add e.g.  jira: PROJ-123"
  fi

  # 2. openspec validate
  if validate_out="$(openspec validate "$name" "${STORE_FLAG[@]+"${STORE_FLAG[@]}"}" 2>&1)"; then
    pass "openspec validate passes"
  else
    first="$(printf '%s' "$validate_out" | grep -m1 'ERROR' || printf '%s' "$validate_out" | head -1)"
    first="$(printf '%s' "$first" | cut -c1-160)"
    fail "openspec validate fails
      ${first}...
      run: openspec validate $name${STORE_FLAG[1]+ --store ${STORE_FLAG[1]}}"
  fi

  # 3. tasks.md sections carry Jira keys
  tasks="$dir/tasks.md"
  if [ ! -f "$tasks" ]; then
    skip "no tasks.md yet (expected between gate 4 and gate 5)"
  else
    bad_sections=()
    while IFS= read -r heading; do
      [ -n "$heading" ] || continue
      printf '%s' "$heading" | grep -Eq "\(${KEY_RE}\)" || bad_sections+=("$heading")
    done < <(grep -E '^##[[:space:]]' "$tasks" || true)

    if [ "${#bad_sections[@]}" -eq 0 ]; then
      n="$(grep -cE '^##[[:space:]]' "$tasks" || true)"
      pass "all ${n} tasks.md section(s) carry a Jira key"
    else
      for h in "${bad_sections[@]}"; do
        fail "tasks.md section missing a Jira key: '${h}'
      expected e.g.  ## 2. Backend (PROJ-125)"
      done
    fi
  fi

  # 5. spec-before-code ordering
  proposal="$dir/proposal.md"
  if [ -z "$branch" ]; then
    skip "not a git repo - skipping spec-before-code check"
  elif [ ! -f "$proposal" ]; then
    skip "no proposal.md yet - skipping spec-before-code check"
  elif ! git -C "$root" rev-parse --verify --quiet "$BASE_REF" >/dev/null 2>&1; then
    skip "base ref '$BASE_REF' not found - skipping spec-before-code check"
  else
    rel="${proposal#"$root"/}"
    add_commit="$(git -C "$root" log --diff-filter=A --format=%H -- "$rel" | tail -1)"
    if [ -z "$add_commit" ]; then
      skip "proposal.md not committed yet - skipping spec-before-code check"
    elif [ "$branch" = "main" ] || [ "$branch" = "master" ] || [ "$branch" = "HEAD" ]; then
      if git -C "$root" merge-base --is-ancestor "$add_commit" "$BASE_REF" 2>/dev/null; then
        pass "proposal.md is merged into $BASE_REF"
      else
        fail "proposal.md is not merged into $BASE_REF"
      fi
    else
      mb="$(git -C "$root" merge-base "$BASE_REF" HEAD 2>/dev/null || echo '')"
      if [ -n "$mb" ] && git -C "$root" merge-base --is-ancestor "$add_commit" "$mb" 2>/dev/null; then
        pass "proposal.md was merged before this branch was cut"
      else
        fail "proposal.md was NOT merged before this branch was cut
      the spec must land on $BASE_REF before any code branch starts"
      fi
    fi
  fi

  # 6. optional Jira assertion
  if [ -n "${JIRA_URL:-}" ] && [ -n "${JIRA_TOKEN:-}" ] && [ -n "$jira_key" ]; then
    issue="$(curl -sS -f \
      -H "Authorization: Bearer ${JIRA_TOKEN}" \
      -H "Accept: application/json" \
      "${JIRA_URL%/}/rest/api/2/issue/${jira_key}?fields=labels,issuetype" 2>/dev/null || true)"
    if [ -z "$issue" ]; then
      skip "could not reach Jira for $jira_key"
    else
      itype="$(printf '%s' "$issue" | jq -r '.fields.issuetype.name // empty')"
      if printf '%s' "$issue" | jq -e '(.fields.labels // []) | index("SDD")' >/dev/null 2>&1; then
        pass "$jira_key carries the SDD label"
      else
        fail "$jira_key does not carry the SDD label"
      fi
      if [ "$itype" = "Story" ]; then
        pass "$jira_key is a Story"
      else
        fail "$jira_key is a '${itype:-unknown}', expected Story
      only Stories map 1:1 to an OpenSpec change"
      fi
    fi
  elif [ -n "$jira_key" ]; then
    skip "JIRA_URL/JIRA_TOKEN unset - not checking the SDD label"
  fi
done

echo
if [ "$failures" -eq 0 ]; then
  printf '\033[32mPASS\033[0m  %d check(s), 0 failures\n' "$checks"
  exit 0
else
  printf '\033[31mFAIL\033[0m  %d check(s), %d failure(s)\n' "$checks" "$failures"
  echo "see docs/jira-sdd-mapping.md"
  exit 1
fi
