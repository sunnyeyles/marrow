#!/usr/bin/env bash
# List UI files with ui-files.sh in a scratch repo: which extensions count,
# deleted files, an empty list and bad arguments.
#
# Usage: ./test-ui-files.sh
set -uo pipefail

S="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

R="$TMP/repo"
git init -q "$R"
git -C "$R" config user.email t@t
git -C "$R" config user.name t
mkdir -p "$R/src"
touch "$R/src/old.tsx" "$R/src/api.ts"
git -C "$R" add -A
git -C "$R" commit -q -m base
BASE="$(git -C "$R" rev-parse HEAD)"

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
files() { "$S/ui-files.sh" "$R" "$BASE" "$1" | jq -c .files; }

echo x >>"$R/src/api.ts"
git -C "$R" commit -q -am "server only"
SERVER="$(git -C "$R" rev-parse HEAD)"
ok "a diff with no UI files lists none" is "$(files "$SERVER")" '[]'
ok "and says ok" is "$("$S/ui-files.sh" "$R" "$BASE" "$SERVER" | jq .ok)" true

touch "$R/src/Page.tsx" "$R/src/Card.JSX" "$R/src/app.vue" "$R/src/site.scss" "$R/src/util.js"
git -C "$R" rm -q "$R/src/old.tsx"
git -C "$R" add -A
git -C "$R" commit -q -m ui
UI="$(git -C "$R" rev-parse HEAD)"
ok "it lists the UI files, any case, and not .ts or .js" is "$(files "$UI")" '["src/Card.JSX","src/Page.tsx","src/app.vue","src/site.scss"]'

ok "it refuses missing arguments" not "$S/ui-files.sh" "$R" "$BASE"
ok "it fails on a bad revision" not "$S/ui-files.sh" "$R" "$BASE" nope

echo
if [[ $FAILS -eq 0 ]]; then echo "all passed"; else echo "$FAILS failed"; fi
[[ $FAILS -eq 0 ]]
