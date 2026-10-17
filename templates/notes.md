# Marrow notes

What every marrow agent should know about this repo. `/marrow setup` writes it and `/marrow retro` adds lessons; edit it freely. Agents read all of it on every run, so keep it short.

## Builds

Where builds run by default, `cloud` or `here`, and why.

## Checks

What `.marrow/checks` runs, and what a check needs that a fresh checkout doesn't have (services, env vars, a running server).

## Tests

How tests are laid out, the command that runs a single test file, and where fixtures and shared helpers live.

## Parallel tickets

Whether two copies of the test suite can run at once, and if not, what they share (a test database, fixed ports, an emulator). The `lanes` the planner should set: 3, 2 or 1.

## Conventions

Where this repo's coding standards are written down, and what a reviewer should know that isn't: patterns to follow, code not to touch, generated files.

## Lessons

From `/marrow retro`: at most 20, newest first, each a `- <agent>: ...` bullet.
