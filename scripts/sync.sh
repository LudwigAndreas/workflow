#!/bin/bash
# Pull the latest shared specifications store and report submodule status.
#
# The specifications submodule tracks its branch and is meant to be bumped
# often (it's the fast-moving shared contract source of truth). Real dev-repo
# submodules, once added via scripts/add-repo.sh, stay pinned to explicit
# commits and are bumped deliberately via PR — this script only fetches for
# them, it never moves their pointer.

set -euo pipefail

echo "Updating specifications to latest..."
tracked_branch="$(git config -f .gitmodules submodule.specifications.branch || echo main)"
if git -C specifications ls-remote --exit-code --heads origin "$tracked_branch" >/dev/null 2>&1; then
  git submodule update --remote --merge specifications
else
  echo "  origin has no '$tracked_branch' branch yet (nothing pushed there?) - skipping update, keeping local commit."
fi

echo
echo "Fetching latest for all other submodules (pointers stay pinned; bump deliberately)..."
git submodule foreach --quiet 'git fetch --quiet || true'

echo
echo "Submodule status:"
git submodule status
