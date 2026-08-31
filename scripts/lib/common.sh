#!/usr/bin/env bash
# Shared helpers for the workflow scripts.
#
# Deliberately bash 3.2 compatible (no associative arrays, no mapfile) so the
# same scripts run on a stock macOS laptop and on a Linux Jenkins agent, and
# depends on nothing beyond git, sed, grep and awk. jq is used only where JSON
# is genuinely involved, and is checked for at that point.
#
# Source it, do not execute it:
#   . "$(dirname "$0")/lib/common.sh"

# ---------------------------------------------------------------- output ----

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_OFF=$'\033[0m'
else
  C_RED=; C_GREEN=; C_YELLOW=; C_BLUE=; C_DIM=; C_BOLD=; C_OFF=
fi

ok()    { printf '%s✓%s %s\n' "$C_GREEN" "$C_OFF" "$*"; }
fail()  { printf '%s✗%s %s\n' "$C_RED" "$C_OFF" "$*"; }
warn()  { printf '%s!%s %s\n' "$C_YELLOW" "$C_OFF" "$*"; }
info()  { printf '%s-%s %s\n' "$C_BLUE" "$C_OFF" "$*"; }
dim()   { printf '%s%s%s\n' "$C_DIM" "$*" "$C_OFF"; }
head1() { printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_OFF"; }
die()   { fail "$*"; exit 1; }

# ------------------------------------------------------------------ paths ---

# Absolute path to the workflow repo root, regardless of where we were invoked.
workflow_root() {
  local here
  here=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
  printf '%s\n' "$here"
}

WORKFLOW_ROOT=${WORKFLOW_ROOT:-$(workflow_root)}
SRC_DIR="$WORKFLOW_ROOT/src"
SPEC_STORE_DIR="$WORKFLOW_ROOT/specifications"
STORE_ID=${STORE_ID:-specifications}

# ------------------------------------------------------------------- yaml ---

# yaml_get <file> <key> - read a top-level scalar from a small, flat YAML file.
# Handles `key: value`, quoted values and trailing comments. Returns empty and
# status 1 if absent. This is not a YAML parser; it is only ever pointed at
# .openspec.yaml, which is flat by construction.
yaml_get() {
  local file=$1 key=$2 line
  [ -f "$file" ] || return 1
  line=$(grep -E "^[[:space:]]*${key}[[:space:]]*:" "$file" 2>/dev/null | head -1) || true
  [ -n "$line" ] || return 1
  printf '%s\n' "$line" \
    | sed -E "s/^[[:space:]]*${key}[[:space:]]*:[[:space:]]*//" \
    | sed -E 's/[[:space:]]+#.*$//' \
    | sed -E 's/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/' \
    | sed -E 's/[[:space:]]*$//'
}

# ------------------------------------------------------------------ repos ---

# repo_list - names of the application repositories, one per line.
# A directory under src/ counts as a repository once it has an openspec/ root.
# Placeholders that have not been set up yet are skipped, so the scripts stay
# usable while the skeleton is only partly wired.
repo_list() {
  local d
  [ -d "$SRC_DIR" ] || return 0
  for d in "$SRC_DIR"/*/; do
    [ -d "$d" ] || continue
    [ -d "${d}openspec" ] || continue
    basename "$d"
  done
}

# repo_path <name>
repo_path() { printf '%s/%s\n' "$SRC_DIR" "$1"; }

# ---------------------------------------------------------------- changes ---

# find_derived_change <repo> <intent-id>
# Print "<state> <change-dir>" for the change in <repo> that derives from
# <intent-id>, where state is "active" or "archived". Prints nothing if there
# is none. A repo may legitimately have both if work was re-opened; archived
# wins, and both are printed so the caller can report the anomaly.
find_derived_change() {
  local repo=$1 intent=$2 root d got
  root=$(repo_path "$repo")
  got=""

  for d in "$root"/openspec/changes/*/; do
    [ -d "$d" ] || continue
    case "$d" in */archive/) continue ;; esac
    [ -f "${d}.openspec.yaml" ] || continue
    if [ "$(yaml_get "${d}.openspec.yaml" intent)" = "$intent" ]; then
      printf 'active %s\n' "${d%/}"
      got=yes
    fi
  done

  for d in "$root"/openspec/changes/archive/*/; do
    [ -d "$d" ] || continue
    [ -f "${d}.openspec.yaml" ] || continue
    if [ "$(yaml_get "${d}.openspec.yaml" intent)" = "$intent" ]; then
      printf 'archived %s\n' "${d%/}"
      got=yes
    fi
  done

  [ -n "$got" ]
}

# intent_dir <intent-id> - path to the master intent, active or archived.
intent_dir() {
  local intent=$1 d
  d="$SPEC_STORE_DIR/openspec/changes/$intent"
  if [ -d "$d" ]; then printf '%s\n' "$d"; return 0; fi
  for d in "$SPEC_STORE_DIR"/openspec/changes/archive/*-"$intent"/; do
    [ -d "$d" ] || continue
    printf '%s\n' "${d%/}"
    return 0
  done
  return 1
}

# intent_fanout_file <intent-id>
# Path to the file carrying the intent's "## Fan-out" checklist. That is
# intent.md; handoff.md is accepted as a fallback so intents authored under
# version 1 of the master-intent schema still gate correctly.
intent_fanout_file() {
  local intent=$1 dir
  dir=$(intent_dir "$intent") || return 1
  if [ -f "$dir/intent.md" ]; then printf '%s\n' "$dir/intent.md"; return 0; fi
  if [ -f "$dir/handoff.md" ]; then printf '%s\n' "$dir/handoff.md"; return 0; fi
  return 1
}

# intent_fanout_repos <intent-id>
# Print "<repo> <jira-key>" for each entry in the "## Fan-out" list. The
# checklist is the declared set of implementing repositories; the gate checks
# reality against it rather than trusting the ticks.
intent_fanout_repos() {
  local intent=$1 fanout
  fanout=$(intent_fanout_file "$intent") || return 1

  awk '
    /^##[[:space:]]+Fan-out/ { infan=1; next }
    infan && /^##[[:space:]]/ { infan=0 }
    infan && /^[[:space:]]*-[[:space:]]*\[[ xX]\]/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*\[[ xX]\][[:space:]]*/, "", line)
      # Backticks are decoration; the checklist is written both ways.
      gsub(/`/, "", line)
      key = ""
      if (match(line, /\(([A-Z][A-Z0-9_]*-[0-9]+)\)/)) {
        key = substr(line, RSTART+1, RLENGTH-2)
      }
      repo = line
      sub(/[[:space:]]*\(.*$/, "", repo)
      sub(/[[:space:]]*-.*$/, "", repo)
      gsub(/[`*]/, "", repo)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", repo)
      if (repo != "") print repo, (key == "" ? "-" : key)
    }
  ' "$fanout"
}

# intent_fanout_ticked <intent-id> <repo> - is that repo's box ticked?
intent_fanout_ticked() {
  local intent=$1 repo=$2 fanout
  fanout=$(intent_fanout_file "$intent") || return 1
  awk -v want="$repo" '
    /^##[[:space:]]+Fan-out/ { infan=1; next }
    infan && /^##[[:space:]]/ { infan=0 }
    infan && /^[[:space:]]*-[[:space:]]*\[[xX]\]/ {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*\[[xX]\][[:space:]]*/, "", line)
      repo = line
      sub(/[[:space:]]*\(.*$/, "", repo)
      sub(/[[:space:]]*-.*$/, "", repo)
      gsub(/[`*]/, "", repo)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", repo)
      if (repo == want) { found=1 }
    }
    END { exit(found ? 0 : 1) }
  ' "$fanout"
}

# ------------------------------------------------------------------- misc ---

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' is required but not installed."
}

store_registered() {
  openspec store list --json 2>/dev/null | grep -q "\"$STORE_ID\"" 2>/dev/null
}
