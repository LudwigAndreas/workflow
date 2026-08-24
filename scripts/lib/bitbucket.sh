#!/usr/bin/env bash
# Bitbucket Data Center / Server REST helpers.
#
# Bitbucket DC exposes /rest/api/1.0 and authenticates with an HTTP access
# token as a bearer header. (Bitbucket Cloud's /2.0 API is a different shape
# entirely - if you migrate, this is the file to fork.)
#
# Environment:
#   BITBUCKET_URL      required, e.g. https://bitbucket.acme.com
#   BITBUCKET_TOKEN    required, an HTTP access token with repo write
#   BITBUCKET_PROJECT  required, the project KEY (upper-case, not the name)
#   BITBUCKET_REPO     required, the repository slug
#   BITBUCKET_DRY_RUN  set to 1 to log calls instead of making them
#
# All functions return non-zero on HTTP failure and print the body to stderr.

set -uo pipefail

bb_require() {
  local missing=0
  for var in "$@"; do
    if [ -z "${!var:-}" ]; then
      echo "error: \$$var is not set" >&2
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || return 2
}

# bb_rest <METHOD> <rest-path> [json-body]
# rest-path is everything after /rest/ - Bitbucket DC spreads its API over
# several bases (api/1.0, default-reviewers/1.0, build-status/1.0), so the
# transport has to be able to reach all of them.
bb_rest() {
  local method="$1" path="$2" body="${3:-}"
  bb_require BITBUCKET_URL BITBUCKET_TOKEN || return 2

  local url="${BITBUCKET_URL%/}/rest/${path#/}"

  if [ "${BITBUCKET_DRY_RUN:-0}" = "1" ]; then
    printf 'DRY-RUN %s %s %s\n' "$method" "$url" "${body:-}" >&2
    echo '{}'
    return 0
  fi

  local out status
  out="$(curl -sS -w $'\n%{http_code}' -X "$method" \
    -H "Authorization: Bearer ${BITBUCKET_TOKEN}" \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    ${body:+--data "$body"} \
    "$url" 2>&1)" || { echo "$out" >&2; return 1; }

  status="$(printf '%s' "$out" | tail -1)"
  body="$(printf '%s' "$out" | sed '$d')"

  case "$status" in
    2*) printf '%s' "$body"; return 0 ;;
    404) printf '%s' "$body"; return 44 ;;
    409) echo "bitbucket: conflict (a pull request for this branch probably already exists)" >&2
         printf '%s' "$body"; return 9 ;;
    *)   echo "bitbucket: HTTP $status on $method $path" >&2
         echo "$body" >&2
         return 1 ;;
  esac
}

# bb_api <METHOD> <path> [json-body] — the common case, relative to api/1.0,
# e.g. "projects/FOO/repos/bar/pull-requests"
bb_api() { bb_rest "$1" "api/1.0/${2#/}" "${3:-}"; }

bb_repo_path() {
  bb_require BITBUCKET_PROJECT BITBUCKET_REPO || return 2
  printf 'projects/%s/repos/%s' "$BITBUCKET_PROJECT" "$BITBUCKET_REPO"
}

# bb_default_reviewers
# Bitbucket DC computes default reviewers from per-repo conditions. Asking it
# rather than hard-coding names keeps the CODEOWNERS-equivalent config in
# Bitbucket, where the admins can see and change it.
#
# Note the REST base: default reviewers are *not* under api/1.0.
bb_default_reviewers() {
  bb_require BITBUCKET_PROJECT BITBUCKET_REPO || return 2
  bb_rest GET "default-reviewers/1.0/projects/${BITBUCKET_PROJECT}/repos/${BITBUCKET_REPO}/conditions" \
    2>/dev/null \
    | jq -c '[ .[]?.reviewers[]? | {user: {name: .name}} ] | unique' 2>/dev/null \
    || echo '[]'
}

# bb_pr_create <from-branch> <to-branch> <title> <description>
# Prints the pull request URL on success.
bb_pr_create() {
  local from="$1" to="$2" title="$3" desc="$4" reviewers payload out
  bb_require BITBUCKET_PROJECT BITBUCKET_REPO || return 2

  reviewers="$(bb_default_reviewers)"
  [ -n "$reviewers" ] || reviewers='[]'

  payload="$(jq -n \
    --arg title "$title" --arg desc "$desc" \
    --arg from "refs/heads/$from" --arg to "refs/heads/$to" \
    --arg proj "$BITBUCKET_PROJECT" --arg repo "$BITBUCKET_REPO" \
    --argjson reviewers "$reviewers" \
    '{
       title: $title,
       description: $desc,
       state: "OPEN",
       open: true,
       closed: false,
       fromRef: {id: $from, repository: {slug: $repo, project: {key: $proj}}},
       toRef:   {id: $to,   repository: {slug: $repo, project: {key: $proj}}},
       locked: false,
       reviewers: $reviewers
     }')"

  out="$(bb_api POST "$(bb_repo_path)/pull-requests" "$payload")" || return 1
  printf '%s' "$out" | jq -r '.links.self[0].href // empty'
}

# bb_pr_get <pr-id> — the raw pull request object.
bb_pr_get() { bb_api GET "$(bb_repo_path)/pull-requests/$1"; }

# bb_pr_set_description <pr-id> <description>
# Bitbucket requires the current version number for an update, so read first.
bb_pr_set_description() {
  local id="$1" desc="$2" version
  version="$(bb_pr_get "$id" | jq -r '.version // empty')"
  [ -n "$version" ] || { echo "bitbucket: could not read version of PR $id" >&2; return 1; }
  bb_api PUT "$(bb_repo_path)/pull-requests/${id}" \
    "$(jq -n --arg d "$desc" --argjson v "$version" '{version: $v, description: $d}')" >/dev/null
}

# bb_pr_comment <pr-id> <text>
bb_pr_comment() {
  bb_api POST "$(bb_repo_path)/pull-requests/$1/comments" \
    "$(jq -n --arg t "$2" '{text: $t}')" >/dev/null
}

# bb_build_status <commit-sha> <SUCCESSFUL|FAILED|INPROGRESS> <key> <name> <url> [description]
# Feeds Bitbucket's "required builds" merge check.
bb_build_status() {
  bb_rest POST "build-status/1.0/commits/$1" \
    "$(jq -n --arg s "$2" --arg k "$3" --arg n "$4" --arg u "$5" --arg d "${6:-}" \
       '{state: $s, key: $k, name: $n, url: $u, description: $d}')" >/dev/null
}
