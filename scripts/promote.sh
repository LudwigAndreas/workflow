#!/usr/bin/env bash
# Promote an image between GitOps overlays, or into the first one.
#
# Promotion copies a digest — it never rebuilds. The artifact running in
# production is byte-identical to the one verified in dev.
#
# Run inside a gitops_* repo checkout.
#
# Usage:
#   scripts/promote.sh --service backend --to dev     --digest sha256:… --version 1.5.0
#   scripts/promote.sh --service backend --from dev   --to staging
#   scripts/promote.sh --service backend --from staging --to prod --pr
#
#   --from <env>     read the digest/version from this overlay
#   --to <env>       write it into this overlay (required)
#   --digest <sha>   explicit digest, instead of --from
#   --version <ver>  explicit version, instead of --from
#   --push           commit on the current branch and push (dev/staging)
#   --pr             commit on a new branch, push, open a pull request (prod)
#   --overlays <dir> overlay root. Default: apps/<service>/overlays
#
# A promotion PR changes exactly one digest and one version. If it wants to
# change anything else, that is a config change and needs its own review.

set -uo pipefail

SERVICE="" FROM="" TO="" DIGEST="" VERSION="" OVERLAYS=""
DO_PUSH=0 DO_PR=0

while [ $# -gt 0 ]; do
  case "$1" in
    --service)  SERVICE="$2"; shift 2 ;;
    --from)     FROM="$2"; shift 2 ;;
    --to)       TO="$2"; shift 2 ;;
    --digest)   DIGEST="$2"; shift 2 ;;
    --version)  VERSION="$2"; shift 2 ;;
    --overlays) OVERLAYS="$2"; shift 2 ;;
    --push)     DO_PUSH=1; shift ;;
    --pr)       DO_PUSH=1; DO_PR=1; shift ;;
    -h|--help)  sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$SERVICE" ] && [ -n "$TO" ] || {
  echo "error: --service and --to are required" >&2; exit 2; }
command -v yq >/dev/null 2>&1 || {
  echo "error: yq (mikefarah v4) not found on PATH" >&2; exit 2; }

[ -n "$OVERLAYS" ] || OVERLAYS="apps/${SERVICE}/overlays"
TARGET="${OVERLAYS}/${TO}/kustomization.yaml"
[ -f "$TARGET" ] || { echo "error: no overlay at $TARGET" >&2; exit 2; }

# ------------------------------------------------------- resolve what to write
if [ -n "$FROM" ]; then
  SOURCE="${OVERLAYS}/${FROM}/kustomization.yaml"
  [ -f "$SOURCE" ] || { echo "error: no overlay at $SOURCE" >&2; exit 2; }
  DIGEST="$(yq -r ".images[] | select(.name | test(\"${SERVICE}\$\")) | .digest // \"\"" "$SOURCE")"
  VERSION="$(yq -r ".images[] | select(.name | test(\"${SERVICE}\$\")) | .newTag // \"\"" "$SOURCE")"
fi

[ -n "$DIGEST" ] || { echo "error: no digest to promote (use --from or --digest)" >&2; exit 2; }

previous="$(yq -r ".images[] | select(.name | test(\"${SERVICE}\$\")) | .digest // \"\"" "$TARGET")"
if [ "$previous" = "$DIGEST" ]; then
  echo "${TO} already runs ${SERVICE} ${VERSION:-$DIGEST} - nothing to promote"
  exit 0
fi

# ------------------------------------------------------------------- the edit
export SERVICE DIGEST VERSION
yq -i '
  (.images[] | select(.name | test(strenv(SERVICE) + "$"))) |=
    (.digest = strenv(DIGEST) | .newTag = strenv(VERSION))
' "$TARGET"

echo "promoted ${SERVICE} ${VERSION:-} -> ${TO}"
echo "  from: ${previous:-none}"
echo "  to:   ${DIGEST}"

[ "$DO_PUSH" -eq 1 ] || { echo "(not pushed - pass --push or --pr)"; exit 0; }

# --------------------------------------------------------------- commit & push
# --pr cuts a branch so the digest change is reviewable; --push lands directly,
# which is what dev and staging want.
if [ "$DO_PR" -eq 1 ]; then
  branch="promote/${SERVICE}-${VERSION:-$(date -u +%Y%m%d%H%M)}-to-${TO}"
  git switch -c "$branch" >/dev/null 2>&1 || git switch "$branch"
fi
git add "$TARGET"
git commit -m "chore(${SERVICE}): promote ${VERSION:-$DIGEST} to ${TO}

Promoted from ${FROM:-build} by scripts/promote.sh.

Promote-Service: ${SERVICE}
Promote-Version: ${VERSION:-unknown}
Promote-Env: ${TO}
Promote-Digest: ${DIGEST}"

if [ "$DO_PR" -eq 1 ]; then
  git push -u origin "$branch"
else
  git push
  echo "pushed to $(git rev-parse --abbrev-ref HEAD)"
  exit 0
fi

command -v gh >/dev/null 2>&1 || { echo "error: gh not found on PATH" >&2; exit 2; }

gh pr create \
  --title "Promote ${SERVICE} ${VERSION:-$DIGEST} to ${TO}" \
  --body "$(cat <<EOF
Promotes the **already-built** ${SERVICE} image to \`${TO}\`.

| | |
|---|---|
| Version | \`${VERSION:-unknown}\` |
| Digest | \`${DIGEST}\` |
| Previously on ${TO} | \`${previous:-none}\` |
| Source | \`${FROM:-build}\` |

This PR changes one digest and one tag. Approving it is a decision about
*when*, not *what* — the what was verified at gate 9.
EOF
)" \
  --label promotion
