#!/usr/bin/env bash
# Copy a Claude Code session's transcripts into a run folder, so a viewer
# (lintcat's run-trace viewer) can replay the run.
#
# Usage:
#   trace.sh <run-dir> [session-id]
#
# Claude Code keeps a session's transcript at
# ~/.claude/projects/<slug>/<id>.jsonl and its subagents' (workflow agents
# included) under ~/.claude/projects/<slug>/<id>/subagents/. Builds run in
# worktrees, so the slug isn't guessed: every project folder is searched for
# the id. The id is the argument, else $CLAUDE_CODE_SESSION_ID (set in every
# Bash call Claude Code makes, subagents' too), else $CLAUDE_SESSION_ID, else
# the newest transcript whose cwd is in the run's repo (or its worktrees) and
# that changed since the run folder's oldest file.
#
# <run-dir>/trace/ mirrors a project folder, so several sessions (a local plan,
# then a cloud build) sit side by side:
#   trace/<id>.jsonl, trace/<id>.* and trace/<id>/subagents/agent-*.jsonl ...
# Rerunning replaces that session's copy with the current one and leaves other
# sessions alone. $CLAUDE_CONFIG_DIR moves ~/.claude, as it does for Claude Code.
#
# Prints {"ok": true, "session", "dir", "files"}, or {"ok": false, "warning"}
# with the warning on stderr too. Never fails a run: exit 0 copied or nothing
# to copy, 2 on misuse.
set -uo pipefail

RUN="${1:-}"
if [[ -z "$RUN" || $# -gt 2 ]]; then
  echo "usage: trace.sh <run-dir> [session-id]" >&2
  exit 2
fi

warn() {
  echo "trace.sh: $1" >&2
  jq -cn --arg w "$1" '{ok: false, warning: $w}' 2>/dev/null || echo '{"ok": false}'
  exit 0
}

[[ -d "$RUN" ]] || warn "no run folder at $RUN"
RUN="$(cd "$RUN" && pwd -P)"
PROJECTS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
[[ -d "$PROJECTS" ]] || warn "no transcripts at $PROJECTS"

SID="${2:-${CLAUDE_CODE_SESSION_ID:-${CLAUDE_SESSION_ID:-}}}"
if [[ -n "$SID" && ! "$SID" =~ ^[A-Za-z0-9_-]+$ ]]; then
  warn "not a session id: $SID"
fi

# The newest transcript of a session in this repo since the run started.
if [[ -z "$SID" ]]; then
  # Run folders are <repo>/.marrow/<name>; worktrees sit inside <repo> too.
  REPO="$(dirname "$(dirname "$RUN")")"
  SINCE="$(ls -tr "$RUN" 2>/dev/null | grep -vx trace | head -1)"
  SINCE="$RUN${SINCE:+/$SINCE}"
  while IFS= read -r f; do
    if grep -m1 -qF -e "\"cwd\":\"$REPO\"" -e "\"cwd\":\"$REPO/" "$f" 2>/dev/null; then
      SID="$(basename "$f" .jsonl)"
      break
    fi
  done < <(ls -t "$PROJECTS"/*/*.jsonl 2>/dev/null | while IFS= read -r f; do [[ "$f" -nt "$SINCE" ]] && echo "$f"; done)
  [[ -n "$SID" ]] || warn "no session id given and no transcript in $PROJECTS from $REPO since the run started"
fi

# Every project folder holding this session, oldest first so the newest wins.
HOMES="$(ls -dtr "$PROJECTS"/*/"$SID".jsonl "$PROJECTS"/*/"$SID"/ 2>/dev/null | while IFS= read -r p; do dirname "${p%/}"; done | awk '!seen[$0]++')"
[[ -n "$HOMES" ]] || warn "no transcript for session $SID in $PROJECTS"

OUT="$RUN/trace"
STAGE="$OUT/.stage-$$"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE" || warn "can't write $OUT"
while IFS= read -r h; do
  for f in "$h/$SID".*; do
    [[ -f "$f" ]] && cp -p "$f" "$STAGE/"
  done
  if [[ -d "$h/$SID" ]]; then
    mkdir -p "$STAGE/$SID"
    cp -Rp "$h/$SID/." "$STAGE/$SID/"
  fi
done <<<"$HOMES"
N="$(find "$STAGE" -type f | wc -l | tr -d ' ')"
[[ "$N" -gt 0 ]] || warn "session $SID has no files to copy"

# Swap in the new copy of this session only.
rm -rf "${OUT:?}/$SID" "$OUT/$SID".*
mv "$STAGE"/* "$OUT/" 2>/dev/null || warn "can't move the copy into $OUT"
jq -cn --arg s "$SID" --arg d "$OUT" --argjson n "$N" '{ok: true, session: $s, dir: $d, files: $n}'
