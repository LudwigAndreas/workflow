#!/usr/bin/env bash
# Shared Jira REST helpers, sourced by scripts/jira-*.sh.
#
# Auth: everything goes through /rest/api/2, which both Jira Cloud and
# Server/Data Center support and which takes plain-text comment bodies (api/3
# requires Atlassian Document Format for the same call, for no benefit here).
#
# Environment:
#   JIRA_URL     required, e.g. https://acme.atlassian.net
#   JIRA_TOKEN   required — API token (Cloud) or personal access token (DC)
#   JIRA_EMAIL   set for Cloud: switches to basic auth (email:token).
#                Leave unset for Server/DC, which uses a bearer token.
#   JIRA_PROJECT required by version operations, e.g. PROJ
#   JIRA_DRY_RUN set to 1 to log calls instead of making them
#
# All functions return non-zero on HTTP failure and print the body to stderr.

set -uo pipefail

JIRA_KEY_RE='[A-Z][A-Z0-9]+-[0-9]+'

jira_require() {
  local missing=0
  for var in "$@"; do
    if [ -z "${!var:-}" ]; then
      echo "error: \$$var is not set" >&2
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || return 2
}

# jira_api <METHOD> <path> [json-body]
# path is relative to /rest/api/2, e.g. "issue/PROJ-123"
jira_api() {
  local method="$1" path="$2" body="${3:-}"
  jira_require JIRA_URL JIRA_TOKEN || return 2

  local url="${JIRA_URL%/}/rest/api/2/${path#/}"
  local -a auth
  if [ -n "${JIRA_EMAIL:-}" ]; then
    auth=(--user "${JIRA_EMAIL}:${JIRA_TOKEN}")
  else
    auth=(-H "Authorization: Bearer ${JIRA_TOKEN}")
  fi

  if [ "${JIRA_DRY_RUN:-0}" = "1" ]; then
    printf 'DRY-RUN %s %s %s\n' "$method" "$url" "${body:-}" >&2
    echo '{}'
    return 0
  fi

  local out status
  out="$(curl -sS -w $'\n%{http_code}' -X "$method" "${auth[@]}" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    ${body:+--data "$body"} \
    "$url" 2>&1)" || { echo "$out" >&2; return 1; }

  status="$(printf '%s' "$out" | tail -1)"
  body="$(printf '%s' "$out" | sed '$d')"

  case "$status" in
    2*) printf '%s' "$body"; return 0 ;;
    404) printf '%s' "$body"; return 44 ;;
    *)   echo "jira: HTTP $status on $method $path" >&2
         echo "$body" >&2
         return 1 ;;
  esac
}

# jira_version_id <name> — prints the id of a project version, or nothing.
jira_version_id() {
  jira_require JIRA_PROJECT || return 2
  jira_api GET "project/${JIRA_PROJECT}/versions" \
    | jq -r --arg n "$1" '.[]? | select(.name == $n) | .id' 2>/dev/null | head -1
}

# jira_version_ensure <name> [description] — creates it if missing; prints the id.
jira_version_ensure() {
  local name="$1" desc="${2:-}" id
  id="$(jira_version_id "$name")"
  if [ -n "$id" ]; then
    printf '%s' "$id"
    return 0
  fi
  jira_api POST version "$(jq -n \
    --arg name "$name" --arg project "$JIRA_PROJECT" --arg desc "$desc" \
    '{name: $name, project: $project, description: $desc, released: false}')" \
    | jq -r '.id // empty'
}

# jira_version_release <name> [iso-date] — marks a version released.
jira_version_release() {
  local name="$1" date="${2:-$(date -u +%Y-%m-%d)}" id
  id="$(jira_version_id "$name")"
  [ -n "$id" ] || { echo "jira: no version named '$name'" >&2; return 1; }
  jira_api PUT "version/${id}" \
    "$(jq -n --arg d "$date" '{released: true, releaseDate: $d}')" >/dev/null
}

# jira_add_fix_version <issue-key> <version-name> — adds, never replaces.
jira_add_fix_version() {
  jira_api PUT "issue/$1" "$(jq -n --arg v "$2" \
    '{update: {fixVersions: [{add: {name: $v}}]}}')" >/dev/null
}

# jira_comment <issue-key> <text>
jira_comment() {
  jira_api POST "issue/$1/comment" \
    "$(jq -n --arg b "$2" '{body: $b}')" >/dev/null
}

# jira_has_comment <issue-key> <marker> — 0 if a comment contains the marker.
jira_has_comment() {
  jira_api GET "issue/$1/comment?maxResults=200" \
    | jq -e --arg m "$2" '[.comments[]?.body | select(contains($m))] | length > 0' \
    >/dev/null 2>&1
}

# jira_set_field <issue-key> <field-id> <value>
jira_set_field() {
  jira_api PUT "issue/$1" \
    "$(jq -n --arg f "$2" --arg v "$3" '{fields: {($f): $v}}')" >/dev/null
}

# jira_get_field <issue-key> <field-id>
jira_get_field() {
  jira_api GET "issue/$1?fields=$2" | jq -r --arg f "$2" '.fields[$f] // empty'
}

# jira_transition <issue-key> <status-name> — no-op if the transition is absent.
jira_transition() {
  local key="$1" target="$2" id
  id="$(jira_api GET "issue/${key}/transitions" \
    | jq -r --arg t "$target" '.transitions[]? | select(.to.name == $t) | .id' \
      2>/dev/null | head -1)"
  if [ -z "$id" ]; then
    echo "jira: $key has no transition to '$target' from its current status" >&2
    return 0
  fi
  jira_api POST "issue/${key}/transitions" \
    "$(jq -n --arg i "$id" '{transition: {id: $i}}')" >/dev/null
}

# jira_keys_by_fix_version <version-name> — issue keys carrying this Fix Version.
# The gitops repos have no application git history, so this is how a deploy
# resolves "which issues are in this release": gate 7 already stamped them.
jira_keys_by_fix_version() {
  jira_require JIRA_PROJECT || return 2
  local jql="project = ${JIRA_PROJECT} AND fixVersion = \"$1\""
  jira_api GET "search?maxResults=200&fields=key&jql=$(
    printf '%s' "$jql" | jq -sRr @uri)" | jq -r '.issues[]?.key' 2>/dev/null
}

# git_keys_in_range <range> — unique Jira keys from commit subjects and bodies.
git_keys_in_range() {
  git log --format='%s%n%b' "$1" 2>/dev/null \
    | grep -oE "$JIRA_KEY_RE" \
    | sort -u
}
