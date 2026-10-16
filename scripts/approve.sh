#!/usr/bin/env bash
# Record, or check, the human approval of a feature's spec and plan.
#
# Usage:
#   approve.sh <feature-dir> spec    # after the user approves spec.md
#   approve.sh <feature-dir> plan    # after the user approves plan.json
#   approve.sh <feature-dir> check   # both approved and unchanged since
#
# Approvals go in <feature-dir>/approvals.json as sha256 hashes, so an edit
# after approval is caught. spec needs at least one ACn criterion and an
# empty "Open questions" section; plan needs plan-check.sh to pass against
# the approved spec. Exit 0 ok, 1 not approved or changed, 2 on misuse.
set -euo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
FDIR="${1:-}"
WHAT="${2:-}"
if [[ -z "$FDIR" || ! -d "$FDIR" || ! "$WHAT" =~ ^(spec|plan|check)$ ]]; then
  echo "usage: approve.sh <feature-dir> spec|plan|check" >&2
  exit 2
fi
FDIR="$(cd -P "$FDIR" && pwd)"
APPROVALS="$FDIR/approvals.json"
[[ -f "$APPROVALS" ]] || echo '{}' >"$APPROVALS"

sha() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1
}
fail() { echo "approve.sh: $1" >&2; exit 1; }

check_spec() {
  local spec="$FDIR/spec.md"
  [[ -f "$spec" ]] || fail "no spec.md in $FDIR"
  grep -qE '\bAC[0-9]+\b' "$spec" || fail "spec.md has no acceptance criteria (AC1, AC2, ...)"
  # The open-questions section must be empty or say None.
  local open
  open="$(awk '/^## +Open questions/{f=1; next} /^## /{f=0} f' "$spec" | grep -vE '^\s*$|^\s*[-*]?\s*None\.?\s*$' || true)"
  [[ -z "$open" ]] || fail "spec.md still has open questions:"$'\n'"$open"
}

case "$WHAT" in
  spec)
    check_spec
    jq --arg s "$(sha "$FDIR/spec.md")" --arg at "$(date -u +%FT%TZ)" '.spec = {sha: $s, at: $at} | del(.plan)' \
      "$APPROVALS" >"$APPROVALS.tmp" && mv "$APPROVALS.tmp" "$APPROVALS"
    echo "spec approved: $(sha "$FDIR/spec.md" | cut -c1-12)"
    ;;
  plan)
    [[ "$(jq -r '.spec.sha // ""' "$APPROVALS")" == "$(sha "$FDIR/spec.md")" ]] || fail "approve the current spec first"
    "$HERE/plan-check.sh" "$FDIR" >/dev/null || fail "plan-check.sh fails; run it to see why"
    jq --arg s "$(sha "$FDIR/plan.json")" --arg at "$(date -u +%FT%TZ)" '.plan = {sha: $s, at: $at}' \
      "$APPROVALS" >"$APPROVALS.tmp" && mv "$APPROVALS.tmp" "$APPROVALS"
    echo "plan approved: $(sha "$FDIR/plan.json" | cut -c1-12)"
    ;;
  check)
    [[ -f "$FDIR/spec.md" && -f "$FDIR/plan.json" ]] || fail "spec.md and plan.json are both needed"
    [[ "$(jq -r '.spec.sha // ""' "$APPROVALS")" == "$(sha "$FDIR/spec.md")" ]] || fail "spec.md is not approved, or changed since"
    [[ "$(jq -r '.plan.sha // ""' "$APPROVALS")" == "$(sha "$FDIR/plan.json")" ]] || fail "plan.json is not approved, or changed since"
    echo "spec and plan approved"
    ;;
esac
