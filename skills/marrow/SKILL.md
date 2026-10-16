---
name: marrow
description: Marrow software factory for the current repo. `new <feature>` starts with a conversation, then a critiqued spec and plan you approve, then builds in a Claude Code cloud session. `build`, `status`, `publish` (opens the PR after you approve), `review <branch>` and `retro` cover the rest.
argument-hint: new <feature> | plan <feature> | build <feature> [--here] [--lite] | status <feature> | publish <feature> | review <branch> [spec-path] | retro <feature>
disable-model-invocation: true
---

# /marrow

Arguments: `$ARGUMENTS`

Marrow turns a conversation into a merged-ready branch. The human approves three things: the spec, the plan, and the PR. Everything between plan approval and the PR runs unattended, by default in a Claude Code cloud session.

## Every subcommand: resolve paths

```bash
MARROW="$(cd -P "$HOME/.claude/marrow" && pwd)"
REPO="$(git rev-parse --show-toplevel)"
BASE_BRANCH="$(git -C "$REPO" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')"
BASE_BRANCH="${BASE_BRANCH:-main}"
FDIR="$REPO/.marrow/<feature>"
```

Stop if you're not in a git repo. If `git -C "$REPO" check-ignore -q --no-index .marrow/` fails, append `.marrow/` to `$(git -C "$REPO" rev-parse --git-common-dir)/info/exclude`. Feature names are slugs: `[A-Za-z0-9._-]+`.

Ask the user questions in chat, one at a time. Don't use AskUserQuestion or plan mode.

## `new <feature>`: conversation, spec, plan, build

### 1. Understand before asking

Read the repo's `CLAUDE.md`, `AGENTS.md`, README and the code the feature will touch. Find how tests are written and run. Anything the code can answer, don't ask.

### 2. The conversation

Open by asking what they want built and why, in their words. Then interview until you share an understanding a stranger could build from:

- One question per message. Each comes with your recommended answer and why, so the user can just say yes.
- Walk the decision tree depth-first: resolve a branch before moving on, because later answers depend on earlier ones.
- Cover: who it's for and the outcome; the main flow; edge cases, errors, empty and limit states; permissions; data and migrations; contracts other code relies on; non-goals; rollout and human steps.
- Push back on scope that's too big for one feature, and suggest the split.
- Stop when you could write every acceptance criterion as a test. Usually 5 to 15 questions.

### 3. Draft the spec

Copy `$MARROW/templates/spec.md` to `$FDIR/spec.md` and fill it in. Acceptance criteria are `AC1`, `AC2`, ...; each is a Given/When/Then an automated test can check, or is marked `(manual)`. Leave `Open questions` as `None` only when there are none.

### 4. Cold critique

Spawn the `marrow-spec-critic` agent (Agent tool) with the repo path, `$FDIR/spec.md` and `Marrow dir: $MARROW`. Show the user the spec's acceptance criteria and the critic's findings together, briefly. Resolve each finding with them (edit the spec, or agree to leave it). Repeat the critique only if the spec changed a lot.

### 5. Spec approval

Ask: "Approve this spec?" Only an explicit yes counts. Then `"$MARROW/scripts/approve.sh" "$FDIR" spec`. If it refuses (no criteria, open questions), fix that with the user first.

### 6. Plan

Call the Workflow tool with `scriptPath` `$MARROW/workflows/plan.js` and `args` `{ "feature": "<feature>", "repoPath": "$REPO", "featureDir": "$FDIR", "specPath": "$FDIR/spec.md", "marrowDir": "$MARROW" }` (absolute paths, a JSON object). Write `plan_markdown` to `$FDIR/plan.md`.

Show the user the plan: waves, each ticket's title, criteria, owned paths and difficulty, plus any open critic findings and warnings. Point them at `$FDIR/plan.md` for detail. Take their changes by editing `$FDIR/plan.json` directly (re-run `plan-check.sh "$FDIR"` and regenerate `plan.md` with `--markdown`), or re-run the plan workflow for big changes.

### 7. Plan approval

Ask: "Approve the plan and start the build?" Only an explicit yes counts. Then `"$MARROW/scripts/approve.sh" "$FDIR" plan` and go straight to `build`.

## `plan <feature>`

Steps 6 and 7 of `new`, for a feature whose spec is already approved. If the spec changed since approval, go back to step 5.

## `build <feature> [--here] [--lite]`

`"$MARROW/scripts/approve.sh" "$FDIR" check` must pass; if not, say which approval is missing and stop.

### Cloud (default)

```bash
"$MARROW/scripts/cloud-launch.sh" "$REPO" <feature> [--lite]
```

It pushes a throwaway run branch, `marrow-run/<feature>`, carrying marrow and the approved spec and plan, and starts a cloud session on it. If origin already has that branch it stops: ask whether to `--replace` it or check `status`. If the launch prints the "start it by hand" fallback, give the user that command to run with `!`.

Then start the watcher with Bash and `run_in_background: true`, so you hear when it's done:

```bash
"$MARROW/scripts/cloud-status.sh" "$REPO" <feature> --wait
```

Tell the user in two lines: the session URL from `$FDIR/cloud.json`, and that they'll be told when the report lands. When the watcher exits 0, do `status`.

### Here (`--here`)

Runs on this machine instead: for repos whose origin isn't on GitHub, or to watch it run. The repo still needs an `origin` remote with the base branch. Then:

```bash
"$MARROW/scripts/build-args.sh" "$REPO" <feature> "$MARROW" --no-push [--lite] > "$FDIR/build-args.json"
```

Call the Workflow tool with `scriptPath` `$MARROW/workflows/build.js` and `args` set to that JSON (an object). Resume a killed run with `resumeFromRunId`. Write the outputs as `CLOUD.md` step 4 describes (`report.md`, `agent-log.md`, `pr.md`, `ledger.json`, `result.json`, all in `$FDIR`), skipping its git commands. Then do `status`.

## `status <feature>`

For a cloud build, run `"$MARROW/scripts/cloud-status.sh" "$REPO" <feature>` (exit 3 means still running: say so with the session URL and stop). Then read `$FDIR/result.json`, `ledger.json` and `report.md`, and tell the user in a few lines:

- status and why; which criteria pass, fail or weren't built;
- checks; open high findings by title; tickets not merged and why;
- human steps;
- the proposed PR title from `pr.md`, and: "Run `/marrow publish <feature>` to open the PR."

## `publish <feature>`: open the PR

Running this is the user's approval to publish. If `result.json` status isn't `green`, show why and ask for an explicit yes before going on.

1. Make sure the branch is on origin:
   - Cloud build: `git -C "$REPO" fetch origin marrow/<feature>`. If origin doesn't have it (the cloud push was refused), restore it from the bundle and push it: `git -C "$REPO" fetch "$FDIR/feature.bundle" "marrow/<feature>:marrow/<feature>"`, then `git -C "$REPO" push -u origin marrow/<feature>`.
   - Local build: `git -C "$REPO/.claude/worktrees/marrow-<feature>" push -u origin marrow/<feature>`.
2. Split `$FDIR/pr.md` into the title (its `# ` line) and the body (the rest, written to a temp file).
3. `"$MARROW/scripts/pr-guard.sh" "$REPO" "<title>" <body file> "origin/$BASE_BRANCH" "origin/marrow/<feature>"`. Exit 1: fix the title or body and re-run; a hit in a commit stops publishing, and you name the commit.
4. `gh pr create --base "$BASE_BRANCH" --head marrow/<feature> --title "<title>" --body-file <body file>`. If one is already open for that head, `gh pr edit` it instead.
5. Write `{"pr": "<url>", "at": "<date -u>"}` to `$FDIR/published.json`. For a cloud build, delete the run branch: `git -C "$REPO" push origin --delete marrow-run/<feature>`.
6. Give the user the PR link. Mention `/marrow retro <feature>` once the PR has had review.

Never merge the PR.

## `review <branch> [spec-path]`

Reviews one branch, read-only. Nothing is pushed or opened.

1. A spec path, if given, must be absolute and exist. With none, the Spec reviewer is skipped.
2. `git -C "$REPO" fetch origin --prune --quiet`. Use the local branch if it exists, else `origin/<branch>`; record `HEAD_SHA`.
3. Slug: the branch with every character outside `A-Za-z0-9._-` replaced by `-`. Make or reuse two detached worktrees, `$REPO/.claude/worktrees/marrow-review-<slug>` (read by reviewers) and `marrow-checks-<slug>` (builds and tests): `git -C "$REPO" worktree add --detach <path> "$HEAD_SHA"`, or for an existing clean one `git -C <path> checkout --detach --quiet "$HEAD_SHA"`. Never clean a dirty one; stop instead. Exclude `.claude/worktrees/` as for `.marrow/`.
4. `BASE="$(git -C <review worktree> merge-base "origin/$BASE_BRANCH" HEAD)"`. An empty diff stops here.
5. Workflow: `scriptPath` `$MARROW/workflows/review.js`, `args` `{ "repoPath", "branch", "worktree", "checksWorktree", "base", "head", "baseBranch", "specPath" (or null), "marrowDir" }`.
6. Write `markdown` to `$REPO/.marrow/review/<slug>/report.md` (first line `Reviewed <date>, run <runId>.`) and `agentLogMarkdown` beside it; append `checks.failures` with `cat` if set. Tell the user: report path, checks, open findings by severity with the high ones named, incomplete reviewers.

## `retro <feature>`

Learn from a published build, so the next one is better.

1. Read `$FDIR/report.md`, `agent-log.md` and `published.json`. With `gh`, read the PR's review comments and conversation, and the commits pushed to the branch after marrow's (human fixes).
2. Find what went wrong or needed a human: findings reviewers missed that humans caught, false positives, tickets that failed or needed retries, plan or spec gaps, wasted rounds.
3. Propose at most five lessons, each one line, starting with the agent it applies to (`implementer:`, `planner:`, `review-bugs:` ...), specific enough to change behaviour, and citing the evidence.
4. Ask the user which to keep. Append the kept ones, newest first, under the heading in `$MARROW/lessons.md`. Every agent reads that file.
