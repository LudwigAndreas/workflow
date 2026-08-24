#!/usr/bin/env bash
# Map a git tag onto a Jira version and stamp Fix Version on every issue in the
# release range. Runs from CI right after the tag is created.
#
#   git tag backend-1.5.0
#     -> Jira version "backend 1.5.0" (created if missing, unreleased)
#     -> Fix Version added to every PROJ-nnn found in backend-1.4.3..backend-1.5.0
#
# Usage:
#   scripts/jira-release.sh --service <name> --version <semver> [options]
#
#   --range <a..b>   commit range to scan. Default: previous <service>-* tag..<tag>
#   --keys "A B C"   explicit issue keys, skipping the git scan
#   --notes-file <f> put the generated release notes on the Jira version
#   --release        also mark the Jira version Released (use on production deploy)
#   --dry-run        print what would happen, change nothing
#
# Environment: JIRA_URL, JIRA_TOKEN, JIRA_PROJECT (+ JIRA_EMAIL on Cloud).
# See docs/release.md#layer-1--fix-version-set-at-tag-time

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
# shellcheck source=lib/jira.sh
. "$(dirname "$0")/lib/jira.sh"

SERVICE="" VERSION="" RANGE="" KEYS="" NOTES_FILE="" DO_RELEASE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --service) SERVICE="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --range)   RANGE="$2"; shift 2 ;;
    --keys)    KEYS="$2"; shift 2 ;;
    --notes-file) NOTES_FILE="$2"; shift 2 ;;
    --release) DO_RELEASE=1; shift ;;
    --dry-run) JIRA_DRY_RUN=1; export JIRA_DRY_RUN; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$SERVICE" ] && [ -n "$VERSION" ] || {
  echo "error: --service and --version are required" >&2; exit 2; }
jira_require JIRA_URL JIRA_TOKEN JIRA_PROJECT || exit 2
command -v jq >/dev/null 2>&1 || { echo "error: jq not found on PATH" >&2; exit 2; }

TAG="${SERVICE}-${VERSION}"
VERSION_NAME="${SERVICE} ${VERSION}"

# ------------------------------------------------------------------ the range
if [ -z "$KEYS" ]; then
  if [ -z "$RANGE" ]; then
    prev="$(git tag --list "${SERVICE}-*" --sort=-v:refname \
      | grep -E "^${SERVICE}-[0-9]+\.[0-9]+\.[0-9]+$" \
      | grep -vFx "$TAG" | head -1)"
    if [ -n "$prev" ]; then
      RANGE="${prev}..${TAG}"
    else
      RANGE="$TAG"
    fi
  fi
  KEYS="$(git_keys_in_range "$RANGE" | tr '\n' ' ')"
fi

echo "release:  $VERSION_NAME"
echo "tag:      $TAG"
echo "range:    ${RANGE:-explicit keys}"
echo "issues:   ${KEYS:-none}"

# ---------------------------------------------------------------- the version
version_id="$(jira_version_ensure "$VERSION_NAME" "Git tag ${TAG}")" || {
  echo "error: could not create or find Jira version '$VERSION_NAME'" >&2; exit 1; }
echo "version:  id ${version_id:-?}"

# Release notes live on the Jira version - Bitbucket has no Releases feature,
# and the version is what non-engineers actually open.
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
  if jira_version_describe "$VERSION_NAME" "$(cat "$NOTES_FILE")"; then
    echo "notes:    written to the Jira version"
  else
    echo "notes:    could not write release notes" >&2
  fi
fi

if [ -z "${KEYS// /}" ]; then
  echo "no issue keys in the range - version created, nothing to stamp"
  [ "$DO_RELEASE" -eq 1 ] && jira_version_release "$VERSION_NAME"
  exit 0
fi

# ------------------------------------------------------------- fix versions
failed=0 stamped=0
for key in $KEYS; do
  if jira_add_fix_version "$key" "$VERSION_NAME"; then
    stamped=$((stamped+1))
    printf '  + %s  fixVersion=%s\n' "$key" "$VERSION_NAME"
  else
    failed=$((failed+1))
    printf '  ! %s  could not set fixVersion\n' "$key" >&2
  fi
done

if [ "$DO_RELEASE" -eq 1 ]; then
  if jira_version_release "$VERSION_NAME"; then
    echo "version:  marked Released"
  else
    failed=$((failed+1))
  fi
fi

echo "done: ${stamped} issue(s) stamped, ${failed} failure(s)"
[ "$failed" -eq 0 ]
