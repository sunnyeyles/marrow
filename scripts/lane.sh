#!/usr/bin/env bash
# Deterministic git plumbing for marrow worktrees, run by marrow-runner.
# Every subcommand prints JSON on stdout.
#
# Usage:
#   lane.sh create <main-checkout> <start-ref> <worktree> <branch> [--fresh]
#       Make (or reuse, when clean and on <branch>) a worktree on <branch>,
#       starting it at <start-ref>, then run checks.sh --setup-only in it.
#       --fresh discards any existing worktree and branch first (ticket lanes
#       are disposable; merged work lives on the integration branch).
#       "base" is the merge-base of <start-ref> and the worktree's HEAD.
#   lane.sh lock <worktree> <lock-json>
#       Write the file lock guard.sh reads: {"owns": [...], "tests": [...],
#       "test_helpers": [...], "locked": [...]}. "{}" clears it.
#   lane.sh merge <into-worktree> <branch> <message>
#       Merge <branch> into the worktree's branch with --no-ff. On conflict
#       the merge is left in progress and the conflicted files are listed.
#   lane.sh settle <worktree>
#       After a conflict resolution: ok when no merge or rebase is in
#       progress; otherwise abort it and report that.
#   lane.sh merged <worktree>
#       Ticket ids already merged on the worktree's branch ("Merge ticket NN:").
#   lane.sh remove <main-checkout> <worktree> [branch]
#       Remove a marrow worktree, and delete its marrow/* branch if given.
#
# Exit 0 ok, 1 failed (see "error"), 2 on misuse.
set -uo pipefail

HERE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

out() { jq -n "$@"; }
die() { out --arg e "$1" '{ok: false, error: $e}'; exit 1; }
usage() { echo "usage: lane.sh create|lock|merge|settle|merged|remove ... (see the header)" >&2; exit 2; }

marrow_wt() { [[ "$1" == */.claude/worktrees/marrow-* ]]; }

case "${1:-}" in
  create)
    [[ $# -eq 5 || ( $# -eq 6 && "$6" == --fresh ) ]] || usage
    MAIN="$2" START="$3" WT="$4" BRANCH="$5"
    marrow_wt "$WT" || die "worktree must be under .claude/worktrees/marrow-*"
    [[ "$BRANCH" == marrow/* ]] || die "branch must be marrow/*"
    git -C "$MAIN" worktree prune
    if [[ "${6:-}" == --fresh ]]; then
      [[ -e "$WT" ]] && { git -C "$MAIN" worktree remove --force "$WT" >&2 || die "could not remove the old $WT"; }
      git -C "$MAIN" branch -D "$BRANCH" >/dev/null 2>&1 || true
    fi
    git -C "$MAIN" check-ignore -q --no-index .claude/worktrees/ ||
      echo ".claude/worktrees/" >>"$(git -C "$MAIN" rev-parse --git-common-dir)/info/exclude"
    reused=false
    if [[ -e "$WT" ]]; then
      [[ "$(git -C "$WT" rev-parse --abbrev-ref HEAD 2>/dev/null)" == "$BRANCH" ]] || die "$WT exists but is not on $BRANCH"
      [[ -z "$(git -C "$WT" status --porcelain)" ]] || die "$WT has uncommitted changes; not touching it"
      reused=true
    elif git -C "$MAIN" show-ref --verify -q "refs/heads/$BRANCH"; then
      git -C "$MAIN" worktree add -q "$WT" "$BRANCH" >&2 || die "worktree add failed"
      reused=true
    else
      git -C "$MAIN" worktree add -q -b "$BRANCH" "$WT" "$START" >&2 || die "worktree add -b $BRANCH from $START failed"
    fi
    setup="$("$HERE/checks.sh" --setup-only "$WT" 2>/dev/null)"
    rc=$?
    base="$(git -C "$WT" merge-base "$START" HEAD 2>/dev/null || git -C "$WT" rev-parse HEAD)"
    out --arg wt "$WT" --arg b "$BRANCH" --arg head "$(git -C "$WT" rev-parse HEAD)" --arg base "$base" --argjson reused "$reused" \
      --argjson rc "$rc" --arg setup "$setup" \
      '{ok: ($rc == 0 or $rc == 2), worktree: $wt, branch: $b, head: $head, base: $base, reused: $reused,
        setup: (try ($setup | fromjson) catch $setup)}'
    [[ $rc -eq 0 || $rc -eq 2 ]]
    ;;
  lock)
    [[ $# -eq 3 ]] || usage
    WT="$2"
    jq -e 'type == "object"' <<<"$3" >/dev/null 2>&1 || die "lock must be a JSON object"
    gitdir="$(git -C "$WT" rev-parse --absolute-git-dir 2>/dev/null)" || die "not a worktree: $WT"
    [[ "$gitdir" == */worktrees/* ]] || die "refusing to lock a main checkout"
    if [[ "$3" == "{}" ]]; then rm -f "$gitdir/marrow-lock.json"; else jq . <<<"$3" >"$gitdir/marrow-lock.json"; fi
    out --arg f "$gitdir/marrow-lock.json" '{ok: true, lock_file: $f}'
    ;;
  merge)
    [[ $# -eq 4 ]] || usage
    WT="$2" BRANCH="$3" MSG="$4"
    [[ -z "$(git -C "$WT" status --porcelain --untracked-files=no)" ]] || die "$WT has uncommitted changes"
    if git -C "$WT" merge --no-ff -q -m "$MSG" "$BRANCH" >&2; then
      out --arg head "$(git -C "$WT" rev-parse HEAD)" '{ok: true, conflict: false, head: $head}'
    else
      files="$(git -C "$WT" diff --name-only --diff-filter=U | jq -R . | jq -s .)"
      if [[ "$files" == "[]" ]]; then
        git -C "$WT" merge --abort 2>/dev/null
        die "merge of $BRANCH failed without conflicts"
      fi
      out --argjson f "$files" '{ok: false, conflict: true, files: $f, error: "merge conflict; the merge is left in progress"}'
      exit 1
    fi
    ;;
  settle)
    [[ $# -eq 2 ]] || usage
    WT="$2"
    gitdir="$(git -C "$WT" rev-parse --absolute-git-dir 2>/dev/null)" || die "not a worktree: $WT"
    if [[ -e "$gitdir/MERGE_HEAD" ]]; then
      git -C "$WT" merge --abort >&2 2>/dev/null
      out '{ok: false, aborted: "merge", error: "a merge was still in progress; aborted it"}'
      exit 1
    fi
    if [[ -d "$gitdir/rebase-merge" || -d "$gitdir/rebase-apply" ]]; then
      git -C "$WT" rebase --abort >&2 2>/dev/null
      out '{ok: false, aborted: "rebase", error: "a rebase was still in progress; aborted it"}'
      exit 1
    fi
    [[ -z "$(git -C "$WT" status --porcelain --untracked-files=no)" ]] || die "uncommitted changes after the resolution"
    out --arg head "$(git -C "$WT" rev-parse HEAD)" '{ok: true, head: $head}'
    ;;
  merged)
    [[ $# -eq 2 ]] || usage
    ids="$(git -C "$2" log --format=%s 2>/dev/null | sed -nE 's/^Merge ticket ([0-9]+):.*/\1/p' | sort -u | jq -R . | jq -s .)"
    out --argjson ids "$ids" '{ok: true, merged: $ids}'
    ;;
  remove)
    [[ $# -ge 3 ]] || usage
    MAIN="$2" WT="$3" BRANCH="${4:-}"
    marrow_wt "$WT" || die "only .claude/worktrees/marrow-* worktrees are removed"
    git -C "$MAIN" worktree prune
    [[ -e "$WT" ]] && { git -C "$MAIN" worktree remove --force "$WT" >&2 || die "worktree remove failed"; }
    if [[ -n "$BRANCH" ]]; then
      [[ "$BRANCH" == marrow/* ]] || die "only marrow/* branches are deleted"
      git -C "$MAIN" branch -D "$BRANCH" >&2 2>/dev/null || true
    fi
    out '{ok: true}'
    ;;
  *) usage ;;
esac
