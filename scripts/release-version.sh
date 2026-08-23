#!/usr/bin/env bash
# Compute the next release version for a service from conventional commits,
# and optionally create the tag. Nobody edits a version number by hand.
#
# Usage:
#   scripts/release-version.sh [--service <name>] [--tag] [--notes] [--json]
#
#   --service <name>  service/tag prefix. Defaults to the repo directory name.
#   --tag             create the annotated tag <service>-<version> at HEAD.
#   --notes           print a markdown changelog for the range to stdout.
#   --json            machine-readable output (default is human-readable).
#
# Bump rules (see docs/release.md#versioning):
#   feat!: / BREAKING CHANGE:  -> major
#   feat:                      -> minor
#   anything else              -> patch
#   no commits since last tag  -> no release, exits 0 with version ""
#
# Exit codes: 0 ok (including "no release"), 2 usage/environment error.

set -uo pipefail

SERVICE=""
DO_TAG=0
DO_NOTES=0
AS_JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --service) SERVICE="$2"; shift 2 ;;
    --tag)     DO_TAG=1; shift ;;
    --notes)   DO_NOTES=1; shift ;;
    --json)    AS_JSON=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "error: jq not found on PATH" >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "error: not a git repository" >&2; exit 2; }

[ -n "$SERVICE" ] || SERVICE="$(basename "$(git rev-parse --show-toplevel)")"

KEY_RE='[A-Z][A-Z0-9]+-[0-9]+'

# ------------------------------------------------------------- current version
last_tag="$(git tag --list "${SERVICE}-*" --sort=-v:refname \
  | grep -E "^${SERVICE}-[0-9]+\.[0-9]+\.[0-9]+$" | head -1)"

if [ -n "$last_tag" ]; then
  current="${last_tag#"${SERVICE}"-}"
  range="${last_tag}..HEAD"
else
  current="0.0.0"
  range="HEAD"
fi

IFS='.' read -r major minor patch <<<"$current"

# ------------------------------------------------------------------ the bump
commit_count="$(git rev-list --count "$range" 2>/dev/null || echo 0)"
if [ "$commit_count" -eq 0 ]; then
  if [ "$AS_JSON" -eq 1 ]; then
    jq -n --arg s "$SERVICE" --arg c "$current" \
      '{service: $s, current: $c, next: "", bump: "none", release: false, keys: []}'
  else
    echo "no commits since ${last_tag:-the beginning} - nothing to release"
  fi
  exit 0
fi

bump="patch"
while IFS= read -r line; do
  case "$line" in
    BREAKING\ CHANGE:*|BREAKING-CHANGE:*) bump="major"; break ;;
  esac
  # subject line: type(scope)!: ... or type!: ...
  if printf '%s' "$line" | grep -qE '^[a-z]+(\([^)]*\))?!:'; then
    bump="major"; break
  fi
  if [ "$bump" = "patch" ] && printf '%s' "$line" | grep -qE '^feat(\([^)]*\))?:'; then
    bump="minor"
  fi
done < <(git log --format='%s%n%b' "$range")

case "$bump" in
  major) major=$((major+1)); minor=0; patch=0 ;;
  minor) minor=$((minor+1)); patch=0 ;;
  patch) patch=$((patch+1)) ;;
esac
next="${major}.${minor}.${patch}"
next_tag="${SERVICE}-${next}"

# --------------------------------------------------------------- jira keys
keys="$(git log --format='%s%n%b' "$range" | grep -oE "$KEY_RE" | sort -u || true)"

# --------------------------------------------------------------- changelog
render_notes() {
  echo "## ${SERVICE} ${next}"
  echo
  local type label found
  for pair in "feat:New features" "fix:Fixes" "perf:Performance" \
              "refactor:Internal changes" "docs:Documentation" \
              "build:Build" "ci:Pipeline" "chore:Chores"; do
    type="${pair%%:*}"; label="${pair#*:}"
    found="$(git log --format='%s|%h' "$range" \
      | grep -E "^${type}(\([^)]*\))?!?:" || true)"
    [ -n "$found" ] || continue
    echo "### ${label}"
    echo
    while IFS='|' read -r subject short; do
      [ -n "$subject" ] || continue
      printf -- '- %s (`%s`)\n' "${subject#*: }" "$short"
    done <<<"$found"
    echo
  done
  if [ -n "$keys" ]; then
    echo "### Jira"
    echo
    while IFS= read -r k; do
      [ -n "$k" ] && printf -- '- %s\n' "$k"
    done <<<"$keys"
    echo
  fi
}

# ------------------------------------------------------------------- tagging
if [ "$DO_TAG" -eq 1 ]; then
  if git rev-parse -q --verify "refs/tags/${next_tag}" >/dev/null; then
    echo "error: tag ${next_tag} already exists" >&2
    exit 2
  fi
  git tag -a "$next_tag" -m "$(render_notes)"
  echo "tagged ${next_tag}" >&2
fi

# -------------------------------------------------------------------- output
if [ "$DO_NOTES" -eq 1 ]; then
  render_notes
  exit 0
fi

if [ "$AS_JSON" -eq 1 ]; then
  jq -n \
    --arg s "$SERVICE" --arg c "$current" --arg n "$next" --arg t "$next_tag" \
    --arg b "$bump" --arg r "$range" --arg lt "${last_tag:-}" \
    --argjson k "$(printf '%s' "$keys" | jq -R -s 'split("\n") | map(select(length > 0))')" \
    '{service: $s, current: $c, next: $n, tag: $t, bump: $b,
      range: $r, previous_tag: $lt, release: true, keys: $k}'
else
  echo "service:  $SERVICE"
  echo "current:  $current (${last_tag:-no previous tag})"
  echo "bump:     $bump  ($commit_count commit(s))"
  echo "next:     $next  -> tag $next_tag"
  echo "jira:     $(printf '%s' "$keys" | tr '\n' ' ')"
fi
