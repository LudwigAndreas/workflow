#!/usr/bin/env bash
# Tell Jira that a release reached an environment. This is the "comment or
# field on the ticket when dev is built and rolled out" half of the loop.
#
# For every issue key in the release it:
#   1. appends the environment to the "Deployed Environments" field (JQL-able)
#   2. adds a comment - once per environment per issue, never duplicated
#   3. optionally transitions the issue
#
# Usage:
#   scripts/jira-deploy.sh --service <name> --version <semver> --env <env> [options]
#
#   --keys "A B"      explicit issue keys
#   --range <a..b>    commit range to scan for keys (needs the app repo's history)
#   --digest <sha256> image digest, shown in the comment
#   --url <url>       pipeline/run URL, shown in the comment
#   --transition <s>  Jira status to move the issue to, e.g. "Deployed to dev"
#   --rollback        record a rollback: removes the env and comments accordingly
#   --dry-run         print what would happen, change nothing
#
# Environment: JIRA_URL, JIRA_TOKEN (+ JIRA_EMAIL on Cloud),
#   JIRA_FIELD_DEPLOYED_ENVS  custom field id, e.g. customfield_10042
# See docs/release.md#layer-2--deployment-records-and-the-ticket-comment

set -uo pipefail
# shellcheck source=lib/jira.sh
. "$(dirname "$0")/lib/jira.sh"

SERVICE="" VERSION="" ENV_NAME="" KEYS="" RANGE=""
DIGEST="" RUN_URL="" TRANSITION="" ROLLBACK=0
FIELD="${JIRA_FIELD_DEPLOYED_ENVS:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --service)    SERVICE="$2"; shift 2 ;;
    --version)    VERSION="$2"; shift 2 ;;
    --env)        ENV_NAME="$2"; shift 2 ;;
    --keys)       KEYS="$2"; shift 2 ;;
    --range)      RANGE="$2"; shift 2 ;;
    --digest)     DIGEST="$2"; shift 2 ;;
    --url)        RUN_URL="$2"; shift 2 ;;
    --transition) TRANSITION="$2"; shift 2 ;;
    --rollback)   ROLLBACK=1; shift ;;
    --dry-run)    JIRA_DRY_RUN=1; export JIRA_DRY_RUN; shift ;;
    -h|--help)    sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$SERVICE" ] && [ -n "$VERSION" ] && [ -n "$ENV_NAME" ] || {
  echo "error: --service, --version and --env are required" >&2; exit 2; }
jira_require JIRA_URL JIRA_TOKEN || exit 2
command -v jq >/dev/null 2>&1 || { echo "error: jq not found on PATH" >&2; exit 2; }

TAG="${SERVICE}-${VERSION}"
NOW="$(date -u '+%Y-%m-%d %H:%M UTC')"

# ------------------------------------------------------------------ the keys
# Three sources, in order of reliability:
#   1. --keys, passed through from the release pipeline
#   2. the Jira version's own issues - gate 7 stamped Fix Version on all of
#      them, so this works from a gitops repo with no application history
#   3. the local tag range, when running by hand inside the app repo
if [ -z "$KEYS" ] && [ -z "$RANGE" ] && [ -n "${JIRA_PROJECT:-}" ]; then
  KEYS="$(jira_keys_by_fix_version "${SERVICE} ${VERSION}" | tr '\n' ' ')"
  [ -n "${KEYS// /}" ] && echo "keys:       resolved from Fix Version '${SERVICE} ${VERSION}'"
fi
if [ -z "${KEYS// /}" ]; then
  if [ -z "$RANGE" ]; then
    prev="$(git tag --list "${SERVICE}-*" --sort=-v:refname \
      | grep -E "^${SERVICE}-[0-9]+\.[0-9]+\.[0-9]+$" \
      | grep -vFx "$TAG" | head -1 2>/dev/null)"
    RANGE="${prev:+${prev}..}${TAG}"
  fi
  KEYS="$(git_keys_in_range "$RANGE" 2>/dev/null | tr '\n' ' ')"
fi

if [ -z "${KEYS// /}" ]; then
  echo "no issue keys for ${TAG} - nothing to report"
  exit 0
fi

echo "deployment: ${SERVICE} ${VERSION} -> ${ENV_NAME}$([ "$ROLLBACK" -eq 1 ] && echo ' (ROLLBACK)')"
echo "issues:     ${KEYS}"

# --------------------------------------------------------------- the comment
# The marker makes the comment idempotent: one per issue per environment.
marker="[deploy:${SERVICE}:${ENV_NAME}]"
if [ "$ROLLBACK" -eq 1 ]; then
  marker="[rollback:${SERVICE}:${ENV_NAME}:${VERSION}]"
  comment="$(printf '%s\n\n' \
    "⏪ *Rolled back on ${ENV_NAME}* — ${SERVICE} ${VERSION} is no longer deployed." \
    "Tag: ${TAG}${DIGEST:+$'\n'Digest: ${DIGEST}}${RUN_URL:+$'\n'Pipeline: ${RUN_URL}}" \
    "${NOW}" \
    "${marker}")"
else
  comment="$(printf '%s\n\n' \
    "🚀 *Deployed to ${ENV_NAME}* — ${SERVICE} ${VERSION}" \
    "Tag: ${TAG}${DIGEST:+$'\n'Digest: ${DIGEST}}${RUN_URL:+$'\n'Pipeline: ${RUN_URL}}" \
    "${NOW}" \
    "${marker}")"
fi

# ------------------------------------------------------------------ per issue
failed=0
for key in $KEYS; do
  line="  ${key}"

  # 1. the field — the one thing JQL and board automation read
  if [ -n "$FIELD" ]; then
    current="$(jira_get_field "$key" "$FIELD" || true)"
    envs="$(printf '%s' "${current:-}" | tr ',' '\n' | sed 's/^ *//;s/ *$//' \
      | grep -v '^$' | grep -vFx "$ENV_NAME" | sort -u || true)"
    if [ "$ROLLBACK" -eq 0 ]; then
      envs="$(printf '%s\n%s\n' "$envs" "$ENV_NAME" | grep -v '^$' | sort -u)"
    fi
    new="$(printf '%s' "$envs" | paste -sd, - 2>/dev/null || printf '%s' "$envs" | tr '\n' ',')"
    new="${new%,}"
    if jira_set_field "$key" "$FIELD" "$new"; then
      line="${line}  envs=[${new}]"
    else
      line="${line}  field=FAILED"; failed=$((failed+1))
    fi
  fi

  # 2. the comment, once per environment
  if jira_has_comment "$key" "$marker"; then
    line="${line}  comment=already-present"
  elif jira_comment "$key" "$comment"; then
    line="${line}  comment=added"
  else
    line="${line}  comment=FAILED"; failed=$((failed+1))
  fi

  # 3. the transition, if one was asked for
  if [ -n "$TRANSITION" ] && [ "$ROLLBACK" -eq 0 ]; then
    if jira_transition "$key" "$TRANSITION"; then
      line="${line}  ->${TRANSITION}"
    else
      line="${line}  transition=FAILED"; failed=$((failed+1))
    fi
  fi

  echo "$line"
done

echo "done: ${failed} failure(s)"
[ "$failed" -eq 0 ]
