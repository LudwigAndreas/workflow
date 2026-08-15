#!/bin/bash
# Registers the shared "specifications" store locally (per-machine, not
# committed to git). Safe to re-run: skips registration if already present.

set -e

if openspec store list --json 2>/dev/null | grep -q '"id"[[:space:]]*:[[:space:]]*"specifications"'; then
  echo "OpenSpec store 'specifications' already registered, skipping"
else
  echo "Registering OpenSpec store 'specifications'"
  openspec store register \
      "$(pwd)/specifications" \
      --id specifications
fi

echo "OpenSpec ready"
