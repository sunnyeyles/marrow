#!/usr/bin/env bash
# List the UI files a branch's diff adds or changes, so the workflows run the
# UI reviewer only when there are some.
#
# Usage:
#   ui-files.sh <worktree> <base> <head>
#
# UI files are .jsx .tsx .vue .svelte .astro .html .css .scss .sass .less;
# deleted files don't count. Prints {"ok": true, "files": [...]} with paths
# relative to the repo root. Exit 0 listed (the list may be empty), 1 failed.
set -euo pipefail

WT="${1:-}" BASE="${2:-}" HEAD="${3:-}"
if [[ -z "$WT" || -z "$BASE" || -z "$HEAD" ]]; then
  echo "usage: ui-files.sh <worktree> <base> <head>" >&2
  exit 1
fi

names="$(git -C "$WT" diff --name-only --diff-filter=d "$BASE...$HEAD")"
{ grep -iE '\.(jsx|tsx|vue|svelte|astro|html|css|scss|sass|less)$' <<<"$names" || true; } |
  jq -R -s -c '{ok: true, files: (split("\n") | map(select(length > 0)))}'
