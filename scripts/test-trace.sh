#!/usr/bin/env bash
# Copy transcripts with trace.sh from a fake HOME: by session id (argument and
# environment), across project folders, subagents and meta files, a rerun,
# two sessions side by side, the newest-transcript fallback, and the cases
# that must warn and still exit 0.
#
# Usage: ./test-trace.sh
set -uo pipefail

S="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0
unset CLAUDE_CONFIG_DIR CLAUDE_SESSION_ID
export HOME="$TMP/home" CLAUDE_CODE_SESSION_ID=
P="$HOME/.claude/projects"

REPO="$TMP/repo"
RUN="$REPO/.marrow/2026-01-01-auth"
mkdir -p "$RUN"
echo spec >"$RUN/spec.md"
touch -t 202601010000 "$RUN/spec.md"

# session <slug> <id> <cwd> [agent...]: a fake transcript with those subagents.
session() {
  local d="$P/$1" id="$2" cwd="$3" a
  shift 3
  mkdir -p "$d"
  printf '{"type":"user","sessionId":"%s","cwd":"%s"}\n' "$id" "$cwd" >"$d/$id.jsonl"
  for a in "$@"; do
    mkdir -p "$d/$id/subagents"
    printf '{"sessionId":"%s","cwd":"%s","agentId":"%s"}\n' "$id" "$cwd" "$a" >"$d/$id/subagents/agent-$a.jsonl"
    echo '{"agentType":"marrow-runner"}' >"$d/$id/subagents/agent-$a.meta.json"
  done
}

# ok <description> <command...>: passes when the command succeeds.
ok() {
  local what="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS $what"
  else
    echo "FAIL $what"
    FAILS=$((FAILS + 1))
  fi
}
not() { ! "$@"; }
is() { [[ "$1" == "$2" ]]; }
same() { cmp -s "$1" "$2"; }

ok "it refuses no arguments" not "$S/trace.sh"
out="$("$S/trace.sh" "$RUN" 2>"$TMP/err")"
ok "with no transcripts it exits 0" is $? 0
ok "with no transcripts it says why" is "$(jq -r .ok <<<"$out")" false
ok "the warning goes to stderr" grep -q 'trace.sh:' "$TMP/err"
ok "with no transcripts it writes nothing" not test -e "$RUN/trace"

session "-x-repo" s1 "$REPO" a1 a2
echo '{"title":"main"}' >"$P/-x-repo/s1.meta.json"
session "-x-repo--claude-worktrees-marrow-auth-t1" s1 "$REPO/.claude/worktrees/marrow-auth-t1" a3
touch -t 202601020000 "$P/-x-repo/s1.jsonl"
session "-x-other" s9 "$TMP/other"

out="$("$S/trace.sh" "$RUN" s1 2>/dev/null)"
ok "by id it copies" is "$(jq -c '[.ok, .session, .files]' <<<"$out")" '[true,"s1",8]'
ok "the main transcript is copied" same "$RUN/trace/s1.jsonl" "$P/-x-repo--claude-worktrees-marrow-auth-t1/s1.jsonl"
ok "sibling meta files are copied" test -f "$RUN/trace/s1.meta.json"
ok "subagents keep their layout" same "$RUN/trace/s1/subagents/agent-a1.jsonl" "$P/-x-repo/s1/subagents/agent-a1.jsonl"
ok "subagent meta files are copied" test -f "$RUN/trace/s1/subagents/agent-a2.meta.json"
ok "subagents from every project folder are merged" test -f "$RUN/trace/s1/subagents/agent-a3.jsonl"
ok "other sessions are left out" not test -e "$RUN/trace/s9.jsonl"
ok "no staging folder is left" is "$(ls -A "$RUN/trace" | grep -c '^\.stage')" 0

rm "$P/-x-repo/s1/subagents/agent-a2.jsonl"
echo '{"more":1}' >>"$P/-x-repo--claude-worktrees-marrow-auth-t1/s1.jsonl"
"$S/trace.sh" "$RUN" s1 >/dev/null 2>&1
ok "a rerun refreshes the transcript" same "$RUN/trace/s1.jsonl" "$P/-x-repo--claude-worktrees-marrow-auth-t1/s1.jsonl"
ok "a rerun drops files the session no longer has" not test -e "$RUN/trace/s1/subagents/agent-a2.jsonl"

out="$(CLAUDE_CODE_SESSION_ID=s9 "$S/trace.sh" "$RUN" 2>/dev/null)"
ok "the id comes from CLAUDE_CODE_SESSION_ID" is "$(jq -r .session <<<"$out")" s9
ok "a second session sits beside the first" test -f "$RUN/trace/s9.jsonl"
ok "the first session is kept" test -f "$RUN/trace/s1/subagents/agent-a3.jsonl"
out="$(CLAUDE_SESSION_ID=s9 "$S/trace.sh" "$RUN" 2>/dev/null)"
ok "or from CLAUDE_SESSION_ID" is "$(jq -r .session <<<"$out")" s9

out="$("$S/trace.sh" "$RUN" nope 2>/dev/null)"
ok "an unknown id warns and exits 0" is "$?:$(jq -r .ok <<<"$out")" 0:false
out="$("$S/trace.sh" "$RUN" '../x' 2>/dev/null)"
ok "a bad id warns and exits 0" is "$?:$(jq -r .ok <<<"$out")" 0:false
out="$("$S/trace.sh" "$TMP/nowhere" s1 2>/dev/null)"
ok "a missing run folder warns and exits 0" is "$?:$(jq -r .ok <<<"$out")" 0:false

# Fallback: the newest transcript from this repo since the run started.
rm -rf "$RUN/trace"
session "-x-repo" old "$REPO"
touch -t 202512310000 "$P/-x-repo/old.jsonl"
session "-x-repo" s2 "$REPO"
session "-x-repo2" s3 "${REPO}2"
touch -t 202601030000 "$P/-x-repo/s2.jsonl"
touch -t 202512300000 "$P/-x-repo--claude-worktrees-marrow-auth-t1/s1.jsonl"
touch -t 202601040000 "$P/-x-repo2/s3.jsonl" "$P/-x-other/s9.jsonl"
out="$("$S/trace.sh" "$RUN" 2>/dev/null)"
ok "with no id it takes the newest transcript from the repo" is "$(jq -r .session <<<"$out")" s2
mkdir -p "$TMP/elsewhere/.marrow/2026-01-01-x"
echo spec >"$TMP/elsewhere/.marrow/2026-01-01-x/spec.md"
out="$("$S/trace.sh" "$TMP/elsewhere/.marrow/2026-01-01-x" 2>/dev/null)"
ok "with no id and no transcript since the run started it warns" is "$?:$(jq -r .ok <<<"$out")" 0:false

out="$(CLAUDE_CONFIG_DIR="$TMP/none" "$S/trace.sh" "$RUN" s1 2>/dev/null)"
ok "CLAUDE_CONFIG_DIR moves where it looks" is "$(jq -r .ok <<<"$out")" false

echo
if [[ $FAILS -eq 0 ]]; then echo "all passed"; else echo "$FAILS failed"; fi
[[ $FAILS -eq 0 ]]
