#!/usr/bin/env bash
# Symlink marrow into ~/.claude so it runs from any directory.
#
# Usage:
#   ./install.sh
#
# Links ~/.claude/marrow to this directory, each agents/*.md into
# ~/.claude/agents/, and each skills/* into ~/.claude/skills/, and removes
# links into this directory whose target is gone. Adds this directory to
# permissions.additionalDirectories in ~/.claude/settings.json, since the
# Workflow tool loads scripts only from the working directory and added
# directories, so /marrow works from any repo. Safe to re-run. Never
# overwrites a real file or directory; it stops instead.
set -euo pipefail

# Resolves symlinks, so a linked install.sh still finds the source.
SRC="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

# The agents' hooks hardcode $HOME/.claude/marrow, so another config dir would leave them without a guard.
if [[ -n "${CLAUDE_CONFIG_DIR:-}" && "${CLAUDE_CONFIG_DIR%/}" != "$CLAUDE_DIR" ]]; then
  echo "refusing: CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR, but the agent hooks call $CLAUDE_DIR/marrow/scripts/guard.sh" >&2
  exit 1
fi

# link <target> <link path>
link() {
  local target="$1" path="$2"
  if [[ -L "$path" ]]; then
    if [[ "$(readlink "$path")" == "$target" ]]; then
      echo "ok       $path"
      return 0
    fi
    ln -sfn "$target" "$path"
    echo "relinked $path -> $target"
  elif [[ -e "$path" ]]; then
    echo "refusing to replace $path: it is not a symlink. Move it aside and re-run." >&2
    exit 1
  else
    ln -s "$target" "$path"
    echo "linked   $path -> $target"
  fi
}

command -v jq >/dev/null || { echo "refusing: jq is needed to add $SRC to $SETTINGS" >&2; exit 1; }
if [[ -e "$SETTINGS" ]] && ! jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1; then
  echo "refusing: $SETTINGS is not a JSON object. Fix it and re-run." >&2
  exit 1
fi

# Check every path first, so a refusal leaves nothing half-installed.
for path in "$CLAUDE_DIR/marrow" \
  $(for a in "$SRC"/agents/*.md; do echo "$CLAUDE_DIR/agents/$(basename "$a")"; done) \
  $(for k in "$SRC"/skills/*/; do echo "$CLAUDE_DIR/skills/$(basename "$k")"; done); do
  if [[ -e "$path" && ! -L "$path" ]]; then
    echo "refusing to replace $path: it is not a symlink. Move it aside and re-run." >&2
    exit 1
  fi
done

mkdir -p "$CLAUDE_DIR/agents" "$CLAUDE_DIR/skills"
chmod +x "$SRC"/scripts/*.sh "$SRC"/install.sh

link "$SRC" "$CLAUDE_DIR/marrow"
for agent in "$SRC"/agents/*.md; do
  link "$agent" "$CLAUDE_DIR/agents/$(basename "$agent")"
done
for skill in "$SRC"/skills/*/; do
  skill="${skill%/}"
  link "$skill" "$CLAUDE_DIR/skills/$(basename "$skill")"
done

# Drop links into this checkout whose target is gone, such as a deleted skill.
for path in "$CLAUDE_DIR"/agents/* "$CLAUDE_DIR"/skills/*; do
  if [[ -L "$path" && ! -e "$path" && "$(readlink "$path")" == "$SRC"/* ]]; then
    rm "$path"
    echo "removed  $path (its target is gone)"
  fi
done

[[ -e "$SETTINGS" ]] || echo '{}' >"$SETTINGS"
if jq -e --arg d "$SRC" '(.permissions.additionalDirectories // []) | index($d)' "$SETTINGS" >/dev/null; then
  echo "ok       $SETTINGS has $SRC in additionalDirectories"
else
  jq --arg d "$SRC" '.permissions.additionalDirectories = ((.permissions.additionalDirectories // []) + [$d])' "$SETTINGS" >"$SETTINGS.tmp"
  # cat, not mv, so a symlinked settings file stays a symlink.
  cat "$SETTINGS.tmp" >"$SETTINGS"
  rm "$SETTINGS.tmp"
  echo "added    $SRC to additionalDirectories in $SETTINGS"
fi

echo "Done. Agent hooks call $CLAUDE_DIR/marrow/scripts/guard.sh."
