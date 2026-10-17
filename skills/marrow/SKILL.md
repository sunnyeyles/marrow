---
name: marrow
description: Marrow software factory for the current repo. `setup` walks you through fitting marrow to the repo. `new <feature>` starts with a conversation, then a critiqued spec and plan you approve, then builds in a Claude Code cloud session. `build`, `status`, `publish` (opens the PR after you approve), `review <branch>`, `runs` (an overview of every run) and `retro` cover the rest.
argument-hint: setup | runs | new <feature> | plan <feature> | build <feature> [--here] [--lite] | status <feature> | publish <feature> | review <branch> [spec-path] | retro <feature>
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
```

Stop if you're not in a git repo. The Workflow tool only loads a `scriptPath` from the working directory or an added directory: if `$MARROW` is neither, stop before planning and tell me to re-run `install.sh` in the marrow checkout (it adds `$MARROW` to `permissions.additionalDirectories`) and restart, or start this session with `claude --add-dir "$MARROW"`. Never copy or retype a workflow script to get round this. Feature names are slugs, `[A-Za-z0-9._-]+`, not starting with `review-`.

Everything marrow writes in the repo goes in `$REPO/.marrow/`, one dated folder per run (the layout is in `run-dir.sh`'s header). `run-dir.sh` makes and finds those folders; never make or name one by hand. For a subcommand on an existing feature:

```bash
FDIR="$("$MARROW/scripts/run-dir.sh" find "$REPO" <feature>)"
```

If it fails, there's no run for that feature: say so, point at `/marrow runs`, and stop.

The overview, `.marrow/README.md`, is refreshed by the scripts that move a run on. After writing a run file yourself (`spec.md`, `plan.json` and `plan.md`, `build-args.json` and a build's outputs here, `published.json`, a review's report), refresh it: `"$MARROW/scripts/runs.sh" "$REPO" >/dev/null`.

Ask the user questions in chat, one at a time. Don't use AskUserQuestion or plan mode.

## `setup`: fit marrow to this repo

A walkthrough, once per repo and again whenever something it settled changes. It ends with two files every build depends on, proven on a clean copy of the base branch: `.marrow/checks`, which every ticket and the final branch must pass, and `.marrow/notes.md`, what every marrow agent should know about the repo. It writes only in `.marrow/`, plus a temporary worktree it removes and any git setting the user agrees to, and commits and pushes nothing.

### 1. Survey before asking

Find out, without asking:

- **Marrow:** `$MARROW` resolves, `~/.claude/agents/marrow-*.md` link into it, and `$MARROW` is in `permissions.additionalDirectories` in `~/.claude/settings.json`. If not, tell the user to run `install.sh` in their marrow checkout, and stop.
- **Tools:** `git`, `jq`, `python3`, `perl`, `claude`, and `gh` with `gh auth status`.
- **Git:** an `origin` remote and whether it's on GitHub (cloud builds and `/marrow publish` need that); `origin/HEAD`, which names the base branch (unset, the scripts assume `main`); `git config user.name` and `user.email`.
- **The repo:** `CLAUDE.md`, `AGENTS.md`, README, CONTRIBUTING and convention docs; languages and package managers; how tests are laid out, with a real test file and the command that runs just that file; CI config (`.github/workflows/` and the like), the best source for the real check commands and the services tests need.
- **Marrow here:** `.marrow/checks`, `.marrow/notes.md`, `.marrow/.gitignore`, any `.marrow/` line in `$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)/info/exclude` (older marrow wrote one), and the runs (`runs.sh`). With no `.marrow/checks`, what `checks.sh` would detect (its header has the rules).

If `.marrow/notes.md` exists, this is a re-run: show the user what it says and ask what changed, rather than starting over. Otherwise tell them in a few lines what's ready, what's missing (install what's missing themselves), and what you'll ask about.

### 2. The conversation

One question per message, each with your recommended answer and why, as in `new`. Skip what the survey settled.

1. **Base branch**, only if `origin/HEAD` is unset: offer `git -C "$REPO" remote set-head origin --auto`, so builds start from the real default branch.
2. **Checks.** Propose the `.marrow/checks` lines (format in `checks.sh`'s header): setup steps first (`!install: ...`), then lint, typecheck, tests and build, taken from CI rather than guessed. They run in a fresh worktree with `CI=true`, after every ticket, and a check that leaves files behind fails. Ask what's missing, and what's too slow to run that often.
3. **Services.** If tests need a database, queue or emulator, how does a fresh checkout get one: a `!` step such as `docker compose up -d --wait`, or something already running on this machine? A cloud session starts from a bare VM, so a service no check step can start means building here.
4. **Parallel tickets.** Up to three tickets run their tests at once, in separate worktrees. One test database the tests truncate, fixed ports or a shared emulator rules that out: lanes 1, or 2 if only some tests share it.
5. **Where builds run.** Cloud (the default) needs a GitHub origin, the Claude GitHub app on the repo (ask; you can't check it) and a claude.ai login. Recommend here when any is missing or the checks need local services.
6. **Conventions.** Name the standards docs you found; the Standards reviewer holds code to them. Ask what else a reviewer should know that isn't written down: patterns to follow, code not to touch, generated files.
7. **Sharing.** Keep `.marrow/` out of git (the default, right for one person), or commit the setup, `.marrow/.gitignore`, `checks` and `notes.md`, so teammates and every cloud session start from it? Runs stay local either way.

### 3. Write it

- `.marrow/checks`: the agreed lines, with a `#` comment over any that needs one.
- `.marrow/notes.md`: from `$MARROW/templates/notes.md`, every section filled in briefly from the survey and the answers, since agents read all of it on every run. On a re-run, keep `## Lessons` as it is.
- `.marrow/.gitignore`: `*` keeps it all local. To share the setup:

  ```
  # Marrow: runs and the overview stay local; the setup is shared.
  */
  README.md
  ```

  and delete the `.marrow/` line from `info/exclude` if there is one, since it hides the whole folder from git. Tell the user which three files to commit; you don't commit them.

### 4. Prove the checks

Run them on a clean copy of the base branch, which is where every build starts. `MARROW_CHECKS_FILE` points `checks.sh` at your draft, which a committed `.marrow/checks` would otherwise override.

```bash
git -C "$REPO" fetch origin --quiet
WT="$(mktemp -d "${TMPDIR:-/tmp}/marrow-setup.XXXXXX")"
git -C "$REPO" worktree add -q --detach "$WT" "origin/$BASE_BRANCH"
MARROW_CHECKS_FILE="$REPO/.marrow/checks" "$MARROW/scripts/run-checks.sh" start "$WT"   # prints <run dir>
"$MARROW/scripts/run-checks.sh" wait <run dir>     # again while it exits 75
```

Then `git -C "$REPO" worktree remove --force "$WT"`.

Green: on to the finish. Red: show the failing steps (the `failures` file in the JSON). A check that's red on the base branch fails every build, so fix the command with the user, or drop the check with their agreement and say why in `notes.md`, and run the checks again. Don't finish setup on red.

### 5. Finish

Tell the user in a few lines: the checks and that they're green, where builds run, the lanes, what was written and whether they need to commit it. When the setup is shared, builds use the `checks` committed on the base branch (cloud builds the committed `notes.md` too), so changes count once they're pushed. Then: "Start a feature with `/marrow new <feature>`."

## `runs`: every run at a glance

Run `"$MARROW/scripts/runs.sh" "$REPO"` and show the table it prints. It also rewrites `.marrow/README.md`, so the same overview is there to browse. Point at `/marrow status <feature>` for detail on one.

## `new <feature>`: conversation, spec, plan, build

### 1. Understand before asking

If `run-dir.sh find` already finds a run for this feature, tell the user its stage (from `runs.sh`) and ask whether to carry on with it or pick another name. To carry on, take `FDIR` from `find` and pick up where `"$MARROW/scripts/approve.sh" "$FDIR" status` points: `none` at step 3 (finish the draft), `spec changed` at step 4, `spec approved` at step 6, `plan changed` at step 6 (show the plan as it now is), `plan approved` at `build`. If `$REPO/.marrow/notes.md` doesn't exist, say in one line that `/marrow setup` fits marrow to this repo first (its checks, test layout and conventions), and carry on unless they want to do that now.

Read the repo's `CLAUDE.md`, `AGENTS.md`, README and the code the feature will touch. Find how tests are written and run. Anything the code can answer, don't ask.

### 2. The conversation

Open by asking what they want built and why, in their words. Then interview until you share an understanding a stranger could build from:

- One question per message. Each comes with your recommended answer and why, so the user can just say yes.
- Walk the decision tree depth-first: resolve a branch before moving on, because later answers depend on earlier ones.
- Cover: who it's for and the outcome; the main flow; edge cases, errors, empty and limit states; permissions; data and migrations; contracts other code relies on; non-goals; rollout and human steps.
- Push back on scope that's too big for one feature, and suggest the split.
- Stop when you could write every acceptance criterion as a test. Usually 5 to 15 questions.

### 3. Draft the spec

Unless you're carrying on an existing run, start the run folder, `FDIR="$("$MARROW/scripts/run-dir.sh" new "$REPO" <feature>)"`, then copy `$MARROW/templates/spec.md` to `$FDIR/spec.md` and fill it in. Acceptance criteria are `AC1`, `AC2`, ...; each is a Given/When/Then an automated test can check, or is marked `(manual)`. Leave `Open questions` as `None` only when there are none.

### 4. Cold critique

Spawn the `marrow-spec-critic` agent (Agent tool) with the repo path, `$FDIR/spec.md`, `Marrow dir: $MARROW` and `Repo notes: $REPO/.marrow/notes.md`. Show the user the spec's acceptance criteria and the critic's findings together, briefly. Resolve each finding with them (edit the spec, or agree to leave it). Repeat the critique only if the spec changed a lot.

### 5. Spec approval

Ask: "Approve this spec?" Only an explicit yes counts. Then `"$MARROW/scripts/approve.sh" "$FDIR" spec`. If it refuses (no criteria, open questions), fix that with the user first.

### 6. Plan

Call the Workflow tool with `scriptPath` `$MARROW/workflows/plan.js` and `args` `{ "feature": "<feature>", "repoPath": "$REPO", "featureDir": "$FDIR", "specPath": "$FDIR/spec.md", "marrowDir": "$MARROW" }` (absolute paths, a JSON object). Write `plan_markdown` to `$FDIR/plan.md`.

Show the user the plan: waves, each ticket's title, criteria, owned paths and difficulty, plus any open critic findings and warnings. Point them at `$FDIR/plan.md` for detail. Take their changes by editing `$FDIR/plan.json` directly (re-run `plan-check.sh "$FDIR"` and regenerate `plan.md` with `--markdown`), or re-run the plan workflow for big changes.

### 7. Plan approval

Ask: "Approve the plan and start the build?" Only an explicit yes counts. Then `"$MARROW/scripts/approve.sh" "$FDIR" plan` and go straight to `build`.

## `plan <feature>`

Steps 6 and 7 of `new`, for a feature whose spec is already approved. If `"$MARROW/scripts/approve.sh" "$FDIR" status` says `none` or `spec changed`, go back to step 5 first.

## `build <feature> [--here] [--lite]`

`"$MARROW/scripts/approve.sh" "$FDIR" check` must pass; if not, say which approval is missing and stop.

### Cloud (default)

Without `--here`, build in the cloud, unless `.marrow/notes.md` says this repo builds here: then build here, as below.

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
rm -f "$FDIR/cloud.json"   # a build here now, not a cloud one
"$MARROW/scripts/build-args.sh" "$REPO" <feature> "$MARROW" --no-push [--lite] > "$FDIR/build-args.json.tmp" &&
  mv "$FDIR/build-args.json.tmp" "$FDIR/build-args.json"
```

Call the Workflow tool with `scriptPath` `$MARROW/workflows/build.js` and `args` set to that JSON (an object). Resume a killed run with `resumeFromRunId`. Write the outputs as `CLOUD.md` step 4 describes (`report.md`, `agent-log.md`, `pr.md`, `ledger.json`, `result.json`, all in `$FDIR`), skipping its git commands. Then do `status`.

## `status <feature>`

It's a cloud build when `$FDIR/cloud.json` exists (a cloud launch and a build here each remove the other's start file). For a cloud build, run `"$MARROW/scripts/cloud-status.sh" "$REPO" <feature>` (exit 3 means still running: say so with the session URL and stop). Then read `$FDIR/result.json`, `ledger.json` and `report.md`, and tell the user in a few lines:

- status and why; which criteria pass, fail or weren't built;
- checks; open high findings by title; tickets not merged and why;
- human steps;
- the proposed PR title from `pr.md`, and: "Run `/marrow publish <feature>` to open the PR."

## `publish <feature>`: open the PR

Running this is the user's approval to publish. If `result.json` status isn't `green`, show why and ask for an explicit yes before going on.

1. Make sure the branch is on origin (cloud or local build as `status` tells them apart):
   - Cloud build: `git -C "$REPO" fetch origin marrow/<feature>`. If origin doesn't have it (the cloud push was refused), restore it from the bundle and push it: `git -C "$REPO" fetch "$FDIR/feature.bundle" "marrow/<feature>:marrow/<feature>"`, then `git -C "$REPO" push -u origin marrow/<feature>`.
   - Local build: `git -C "$REPO/.claude/worktrees/marrow-<feature>" push -u origin marrow/<feature>`.
2. Split `$FDIR/pr.md` into the title (its `# ` line) and the body (the rest, written to a temp file).
3. `"$MARROW/scripts/pr-guard.sh" "$REPO" "<title>" <body file> "origin/$BASE_BRANCH" "origin/marrow/<feature>"`. Exit 1: fix the title or body and re-run; a hit in a commit stops publishing, and you name the commit.
4. `gh pr create --base "$BASE_BRANCH" --head marrow/<feature> --title "<title>" --body-file <body file>`. If one is already open for that head, `gh pr edit` it instead.
5. Label it with the deploy risks: `"$MARROW/scripts/pr-labels.sh" "$REPO" <url> "origin/$BASE_BRANCH" "origin/marrow/<feature>"`. It creates any label the GitHub repo lacks and only ever adds labels. If it fails, say so and go on: the PR is already open.
6. Write `{"pr": "<url>", "at": "<date -u>", "labels": <its labels, or []>}` to `$FDIR/published.json`. For a cloud build, delete the run branch: `git -C "$REPO" push origin --delete marrow-run/<feature>`.
7. Give the user the PR link and its labels. Mention `/marrow retro <feature>` once the PR has had review.

Never merge the PR.

## `review <branch> [spec-path]`

Reviews one branch, read-only. Nothing is pushed or opened.

1. A spec path, if given, must be absolute and exist. With none, the Spec reviewer is skipped.
2. `git -C "$REPO" fetch origin --prune --quiet`. Use the local branch if it exists, else `origin/<branch>`; record `HEAD_SHA`.
3. Slug: the branch with every character outside `A-Za-z0-9._-` replaced by `-`. Make or reuse two detached worktrees at `HEAD_SHA`, `$REPO/.claude/worktrees/marrow-review-<slug>` (read by reviewers) and `marrow-checks-<slug>` (builds and tests), each with `"$MARROW/scripts/lane.sh" detach "$REPO" <path> "$HEAD_SHA"`. It refuses a dirty one; stop then.
4. `BASE="$(git -C <review worktree> merge-base "origin/$BASE_BRANCH" HEAD)"`. An empty diff stops here. List its UI files with `"$MARROW/scripts/ui-files.sh" <review worktree> "$BASE" "$HEAD_SHA"`; with none, the UI reviewer is skipped.
5. Start the run folder, `RDIR="$("$MARROW/scripts/run-dir.sh" review "$REPO" "<branch>")"`, then the workflow: `scriptPath` `$MARROW/workflows/review.js`, `args` `{ "repoPath", "branch", "worktree", "checksWorktree", "base", "head", "baseBranch", "specPath" (or null), "marrowDir", "uiFiles" (its `files` array) }`.
6. Write `markdown` to `$RDIR/report.md` (first line `Reviewed <branch> <date>, run <runId>.`) and `agentLogMarkdown` beside it; append `checks.failures` with `cat` if set. Tell the user: report path, checks, open findings by severity with the high ones named, incomplete reviewers.

## `retro <feature>`

Learn from a published build, so the next one is better.

1. Read `$FDIR/report.md`, `agent-log.md` and `published.json`. With `gh`, read the PR's review comments and conversation, and the commits pushed to the branch after marrow's (human fixes).
2. Find what went wrong or needed a human: findings reviewers missed that humans caught, false positives, tickets that failed or needed retries, plan or spec gaps, wasted rounds.
3. Propose at most five lessons, each one line, starting with the agent it applies to (`implementer:`, `planner:`, `review-bugs:` ...), specific enough to change behaviour, and citing the evidence.
4. Ask the user which to keep. Lessons about this repo (its code, tests, conventions) go under `## Lessons` in `$REPO/.marrow/notes.md`, made from `$MARROW/templates/notes.md` if missing; lessons about how a marrow agent works in any repo go under the heading in `$MARROW/lessons.md`. Each is a `- <agent>: ...` bullet, newest first.
5. Every agent reads both lists in full, so each holds at most 20. A new lesson that repeats an old one merges into it, and the merged line moves to the top. Past 20, propose which of the oldest to drop and drop them once the user agrees. Then tell the user to commit `lessons.md` in marrow, and `notes.md` too if the setup is shared.
