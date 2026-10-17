#!/usr/bin/env bash
# Run plan-check.sh on scratch feature dirs and check its scout.json
# warnings: unowned will_change paths warn, never fail, and --markdown shows
# them in a Scout section.
#
# Usage: ./test-plan-check.sh
set -uo pipefail

S="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

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

# feature <name> [scout.json text]: a feature dir with one ticket owning src/users/**.
feature() {
  local d="$TMP/$1"
  mkdir -p "$d"
  echo '- AC1: Given a user, when they sign in, then they see the dashboard.' >"$d/spec.md"
  cat >"$d/plan.json" <<'JSON'
{ "feature": "f",
  "criteria": [{"id": "AC1", "text": "sign in", "verify": "auto"}],
  "tickets": [{"id": "01", "title": "Sign in", "goal": "Sign in.", "criteria": ["AC1"],
               "blocked_by": [], "owns": ["src/users/**", "src/api/routes.ts"],
               "tests": {"paths": ["src/users/users.test.ts"], "helpers": [], "command": "true"},
               "difficulty": "normal", "steps": [], "human_steps": [], "notes": ""}] }
JSON
  [[ $# -lt 2 ]] || printf '%s' "$2" >"$d/scout.json"
  echo "$d"
}
# passes <dir>: plan-check exits 0.
passes() { "$S/plan-check.sh" "$1"; }
# warns <dir> <text>: a warning contains the text.
warns() { "$S/plan-check.sh" "$1" | jq -e --arg t "$2" 'any(.warnings[]; contains($t))'; }
# quiet <dir>: no warnings at all.
quiet() { "$S/plan-check.sh" "$1" | jq -e '.warnings == []'; }
# md_has <dir> <text>: the --markdown plan has the text.
md_has() { "$S/plan-check.sh" "$1" --markdown | grep -qF -- "$2"; }

D="$(feature none)"
ok "no scout.json: passes" passes "$D"
ok "no scout.json: no warnings" quiet "$D"
ok "no scout.json: no Scout section" not md_has "$D" "## Scout"

D="$(feature owned '{"will_change": [{"path": "src/users/service.ts"}, {"path": "src/api/routes.ts"}],
  "entry_points": [{"path": "src/api/routes.ts", "line": 42, "why": "the login route"}], "unknowns": ["session store"]}')"
ok "every path owned (glob and exact): passes" passes "$D"
ok "every path owned: no warnings" quiet "$D"
ok "markdown lists the entry point" md_has "$D" '- Entry point: `src/api/routes.ts:42` (the login route)'
ok "markdown lists the unknowns" md_has "$D" "- Unknown: session store"
ok "markdown lists nothing as unowned" not md_has "$D" "Unowned"

D="$(feature test-path '{"will_change": [{"path": "src/users/users.test.ts"}]}')"
ok "a path covered by a ticket's tests: no warnings" quiet "$D"

D="$(feature unowned '{"will_change": [{"path": "src/billing/plan.ts", "new": true}, {"path": "src/users/service.ts"}]}')"
ok "an unowned path: still passes" passes "$D"
ok "an unowned path: warns" warns "$D" "src/billing/plan.ts will change, but no ticket owns it"
ok "an unowned path: one warning only" bash -c "'$S/plan-check.sh' '$D' | jq -e '.warnings | length == 1'"
ok "markdown lists the unowned path" md_has "$D" '- Unowned: `src/billing/plan.ts`'

D="$(feature malformed '{"will_change": [')"
ok "malformed scout.json: still passes" passes "$D"
ok "malformed scout.json: warns" warns "$D" "cannot read scout.json"

D="$(feature odd '{"will_change": ["src/x.ts", {"why": "no path"}]}')"
ok "will_change entries without a path: ignored" quiet "$D"

D="$(feature array '[]')"
ok "scout.json that isn't an object: warns" warns "$D" "cannot read scout.json"

if ((FAILS)); then
  echo "$FAILS failed"
  exit 1
fi
echo "all passed"
