#!/bin/bash
# Promote a src/<name> placeholder into a real git submodule.
#
# Usage: scripts/add-repo.sh <name> <git-url>
# Example: scripts/add-repo.sh frontend ssh://git@bitbucket.acme.com/plat/frontend.git

set -euo pipefail

name="${1:?Usage: scripts/add-repo.sh <name> <git-url>}"
url="${2:?Usage: scripts/add-repo.sh <name> <git-url>}"
dir="src/${name}"

if [ ! -d "$dir" ]; then
  echo "error: $dir does not exist" >&2
  exit 1
fi

if [ -d "$dir/.git" ] || git config -f .gitmodules --get "submodule.${dir}.url" >/dev/null 2>&1; then
  echo "error: $dir is already a git repo / submodule" >&2
  exit 1
fi

echo "Promoting placeholder $dir -> $url"
git rm -r --cached "$dir" >/dev/null
rm -rf "$dir"
git submodule add "$url" "$dir"

cat <<MSG

Done. The placeholder's openspec/config.yaml and README.md are gone along
with the rest of the placeholder content — carry over the local openspec/
shape (specs/, changes/, and the "references: specifications" block in
config.yaml) into the real repo if it doesn't already have one.

Then commit here to record the pin:
  git add .gitmodules "$dir"
  git commit -m "Promote $name to real submodule"
MSG
