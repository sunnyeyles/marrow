# Marrow

A software factory for Claude Code. You talk through a feature, approve a spec and a plan, and marrow builds it unattended in a Claude Code cloud session. It writes tests first, keeps them locked, checks every ticket outside the agent that did it, and reviews the result adversarially. You approve the PR at the end.

```
/marrow new <feature>        conversation → spec (approve) → plan (approve) → cloud build
/marrow status <feature>     the build's report, acceptance ledger and proposed PR
/marrow publish <feature>    open the PR (your approval)
/marrow build <feature> [--here] [--lite]    start or restart a build
/marrow plan <feature>       re-plan an approved spec
/marrow review <branch> [spec]               review any branch, read-only
/marrow retro <feature>      turn a PR's review into lessons for every agent
```

## The pipeline

```
 you ── conversation ──▶ spec.md ──▶ spec critic ──▶ ✋ approve spec
                                                        │
        planner ⇄ plan-check.sh ⇄ plan critic ◀─────────┘
                       │
                  ✋ approve plan
                       │   cloud-launch.sh pushes marrow-run/<feature>, starts `claude --cloud`
                       ▼
 ┌─ cloud session ────────────────────────────────────────────────────────────┐
 │ waves of tickets, up to 3 lanes at once, each in its own worktree:         │
 │   test writer → red check (tests must fail) → lock tests                   │
 │   implementer (hard tickets: two attempts + judge) → green check           │
 │   merge into marrow/<feature>; integration checks between waves            │
 │ checks ∥ standards, spec, bugs reviewers → skeptic → up to 2 fix rounds    │
 │ merge in origin/<base> → acceptance ledger → push marrow/<feature> → PR    │
 │ report pushed to marrow-run/<feature>                                      │
 └────────────────────────────────────────────────────────────────────────────┘
                       │   cloud-status.sh notices the report
                       ▼
                 ✋ /marrow publish ──▶ PR (never merged by marrow)
```

## Why it's built this way

Each choice follows the research in `docs/research/` (three reports, about 130 sources, every claim linked):

| Choice | Evidence |
| --- | --- |
| Start with a conversation and an approved spec | Spec quality is the biggest lever: SWE-bench Pro solve rate drops from 25.9% to 8.4% without full requirements. Factory, Jules, Kiro and spec-kit all gate on an approved plan. |
| Acceptance tests written first, must fail, then locked | A reproduction test that fails before and passes after was Agentless's largest gain. Agents do edit or special-case tests (METR, Spotify), so the oracle sits outside the implementer: a guard blocks edits and `verify-ticket.sh` compares the files byte for byte. |
| Deterministic steps around bounded agent loops | Stripe, Spotify and Copilot's "blueprint" pattern. Git, locks, checks and verification are scripts run by a cheap runner; models only do judgement. |
| Owned paths per ticket, parallel only when disjoint (and `"lanes": 1` in the plan for repos whose tests share a database or ports) | Parallel agents help only on independent work; one study measured 39–70% worse results on sequential tasks, and Cursor's peer agents stalled on locks. `plan-check.sh` serialises overlapping tickets. |
| Two attempts plus a judge, only for hard tickets | Best-of-N with a separate verifier is one of the strongest SWE-bench techniques, and a hybrid execution-plus-LLM verifier beats either alone. It costs real tokens, so marrow spends them only where the planner flags risk. |
| Fresh-context reviewers, then a skeptic that must cite code | Cognition, Factory and Anthropic converged on clean-context review plus a verify pass; LLM judges over-reject correct code, so refutation needs a citation and high findings survive doubt. |
| A spec reviewer that hunts unwired features and weak tests | Practitioners report reviewers approving features that were built but never connected; the plan critic and spec reviewer both look for it. |
| Cloud sessions, PR approval stays local | Disposable per-task VMs (Codex, Devin, Factory), agents that can't merge their own work, and human review as the real bottleneck. |
| Lessons file fed by retros | Short, curated context beats auto-generated context, which lowered success and added over 20% cost in one study. |

## Install

```bash
./install.sh
```

It symlinks `~/.claude/marrow` to this folder, `agents/*.md` into `~/.claude/agents/`, and `skills/*` into `~/.claude/skills/`. Re-running is safe; it never replaces a real file. The agents' hooks call `~/.claude/marrow/scripts/guard.sh`, and a missing guard blocks every Bash call, so install before use.

Needs `git`, `jq`, `python3`, `perl`, and for cloud builds and publishing: a GitHub origin, the Claude GitHub app on the repo, a claude.ai login (`claude --cloud` works), and `gh`.

## Files in the target repo

`.marrow/<feature>/` holds everything for one feature. It's kept out of git through `.git/info/exclude`:

| File | Written by |
| --- | --- |
| `spec.md` | you and Claude, in the conversation |
| `plan.json`, `plan.md` | the plan workflow |
| `approvals.json` | `approve.sh`: sha256 of the approved spec and plan; any later edit blocks the build |
| `cloud.json`, `cloud.log` | `cloud-launch.sh` |
| `report.md`, `agent-log.md`, `pr.md`, `ledger.json`, `result.json` | the build |
| `published.json` | `/marrow publish` |

Optional and committed: `.marrow/checks`, the repo's check commands, one `name: command` per line; a leading `!` marks a setup step. Without it, checks are detected (package.json scripts after an install, Go, Cargo, uv, `make test`).

## Branches

- `marrow/<feature>`: the feature. The cloud session pushes it; `/marrow publish` opens the PR from it.
- `marrow/<feature>-tNN` (and `-b`): ticket lanes, local to the build, deleted after merging.
- `marrow-run/<feature>`: throwaway. It carries marrow, the approved spec and plan, and your git identity into the cloud session, and brings the report back, with a git bundle of the feature branch in case the cloud couldn't push it. `/marrow publish` deletes it.

## Guards

`scripts/guard.sh` is a PreToolUse hook on every marrow agent, and a repo-level hook in cloud runs:

- No agent pushes, except `marrow-git-sync`, and only `git -C <.claude/worktrees/marrow-*> push (-u | --force-with-lease=…) origin marrow/<f>`.
- No agent merges a PR, opens one, or writes through `gh`. `reset --hard`, `clean -f` and deleting non-marrow branches or worktrees are blocked.
- The test writer may edit only its ticket's test paths. The implementer may not edit locked tests or anything outside its owned paths.

The guard is a fast path against mistakes, not a sandbox. The real gates run outside the agents: `verify-ticket.sh` after every attempt, the checks, and `ledger.sh`, which reruns every ticket's acceptance tests at the end and marks a criterion `tampered` if its test files changed after they were locked. `scripts/test-guard.sh` holds the guard's regression tests.

## Commit diffs in cmux

When a build runs in a [cmux](https://cmux.com) terminal (`--here`), each commit the test writer or implementer makes opens in `cmux diff`, titled with its short SHA and subject. The first opens a new "Commit diffs" workspace in the sidebar; each later one is a new tab in it. Close the workspace and the next commit starts a fresh one. `scripts/commit-diff.sh` is a PostToolUse hook on those two agents. Outside cmux, including cloud sessions, it does nothing. `scripts/test-commit-diff.sh` tests it against a fake `cmux`.

## Layout

| Path | What |
| --- | --- |
| `skills/marrow/SKILL.md` | the `/marrow` command |
| `agents/` | spec critic, planner, plan critic, test writer, implementer, judge, three reviewers, skeptic, git-sync, runner; the Spec and Standards reviewers are adapted from mattpocock's `code-review` skill |
| `workflows/plan.js`, `build.js`, `review.js` | the Workflow scripts |
| `CLOUD.md` | what the cloud session does |
| `templates/spec.md` | the spec skeleton |
| `scripts/` | `approve`, `plan-check`, `build-args`, `lane`, `verify-ticket`, `ledger`, `checks`, `run-checks`, `cloud-launch`, `cloud-status`, `guard`, `pr-guard`, `test-guard`, `commit-diff`, `test-commit-diff` |
| `skills/codebase-design/` | mattpocock's deep-module skill (MIT), preloaded by the planner, implementer and Standards reviewer |
| `lessons.md` | lessons from `/marrow retro`, read by every agent |
| `docs/research/` | the research behind the design |

## Untested edges

These rest on Claude Code docs rather than a live run, so check them on the first real build:

- what `claude --cloud` prints and whether it returns (`cloud-launch.sh` times out at 180 s, then prints a manual fallback);
- whether agent frontmatter hooks fire in cloud sessions (the repo-level `guard.sh auto` hook covers it if they don't);
- custom `agentType`s and the Workflow tool inside a cloud session (the docs imply both work);
- whether the cloud session may push `marrow/<feature>` (if not, `/marrow publish` restores it from the bundle).
