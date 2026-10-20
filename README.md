# Marrow

![Marrow: from idea to a tested, reviewed pull request](docs/marrow.png)

A software factory for Claude Code. You describe a feature, approve a spec and a plan, and marrow builds it unattended in a Claude Code cloud session. You approve the PR at the end.

See the [user guide](docs/guide.md) for more detail.

## How it works

1. **Spec**: you talk through the feature with Claude; a critic reviews the spec; you approve it.
2. **Plan**: a planner splits the spec into tickets; a critic checks the plan; you approve it.
3. **Build** (in the cloud), for each ticket:
   - a test writer writes tests that must fail first, then the tests are locked;
   - an implementer makes them pass without touching the locked tests;
   - independent tickets run in parallel, each in its own worktree.
4. **Review**: fresh reviewers check standards, spec, bugs and UI; a skeptic filters their findings; up to two fix rounds.
5. **Publish**: you check the report and open the PR. Marrow never merges.

## Install

```bash
./install.sh
```

Restart Claude Code after the first install. Needs `git`, `jq`, `python3`, `perl`, and for cloud builds: a GitHub repo with the Claude GitHub app, a claude.ai login, and `gh`.

Then run `/marrow setup` once in each repo.

## Commands

```
/marrow setup                               fit marrow to this repo (checks, tests, conventions)
/marrow new <feature>                       conversation → spec → plan → cloud build
/marrow status <feature>                    the build's report and proposed PR
/marrow publish <feature>                   open the PR
/marrow build <feature> [--here] [--lite]   start or restart a build
/marrow plan <feature>                      re-plan an approved spec
/marrow review <branch> [spec]              review any branch, read-only
/marrow runs                                list every run in this repo
/marrow retro <feature>                     turn a PR's review into lessons
```

Run files live in `.marrow/` in your repo.
