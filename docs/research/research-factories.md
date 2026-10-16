# AI "Software Factories": state of the art as of 2026-10-16

Scope: systems that turn a spec/issue into a tested, reviewable PR with little human typing. Researched 2026-10-16 via web search plus page fetches.

## Method and reliability notes

- Page fetches were summarised by a small model, so exact numbers should be re-checked against the linked page before being quoted externally. Where a primary page was blocked (HTTP 403: openai.com/index/introducing-codex, openai.com/index/harness-engineering, openai.com/index/why-we-no-longer-evaluate-swe-bench-verified, hyrax.dev) I used search-result text or a secondary writeup and say so.
- Labels: **[P]** = vendor/author primary page (self-reported); **[S]** = secondary (press, aggregator, ZenML/InfoQ summary); **[I]** = independent evaluation.
- Nearly every productivity number below is vendor self-reported. Independent evidence is in section 5 and it is much less flattering.
- Several third-party pages mention model names I could not verify (e.g. "Claude Fable 5.1", "GPT-6 Astra"). I only repeat model names that come from the vendor's own page.

---

## 1. Per-system profiles

### 1.1 Factory.ai (Droids, Missions, Agent Readiness)

- **Pipeline (Missions, announced Feb 26, 2026; research preview)** [P]: `/enter-mission` scoping with clarifying questions ("the planning phase is where most of the value comes from") -> human approves plan -> Mission Control executes milestones/features -> each milestone ends with a validation phase. https://factory.com/news/missions
- **Decomposition** [P]: an orchestrator splits the project into milestones, then features. Each feature gets a fresh worker session with clean context. Orchestrator can re-plan, reorder, or mark a stuck worker's item complete. Scope guidance is roughly 1-500 features per mission; larger work should be split. https://factory.com/news/missions ; https://docs.factory.com/missions/overview.md
- **Isolation** [P]: runs locally or in isolated cloud containers; git is source of truth; commands risk-classified; "Droid Shield" scans for secrets before data reaches a model. https://factory.com/news/missions
- **Verification** [P]: validation workers run tests, check regressions and integration, and use computer use to launch the app and click through flows alongside (not instead of) test/lint/build. Validation failures produce follow-up work before the next milestone. Reliable self-verification requires a repo at Agent Readiness Level 4+ per the docs. https://factory.com/news/missions ; https://docs.factory.com/missions/overview.md
- **Model roles** [P]: orchestration on Opus 4.6, implementation on Sonnet 4.6/Opus 4.6, validation/user-testing on GPT-5.3-Codex, research on Kimi K2.5 (i.e. deliberately different model families for builder vs validator). https://factory.com/news/missions
- **Humans** [P]: approve plan, monitor, unblock stuck workers, redirect. "Not fire-and-forget." https://docs.factory.com/missions/overview.md
- **Long-running/context** [P]: fresh session per feature to avoid context degradation; learned patterns saved as reusable skills. Median mission about 2 h; 65% run >1 h, 37% >4 h, 14% >24 h; longest 16 days. Median mission uses ~12x tokens of a normal session. https://factory.com/news/missions
- **Failure modes Factory reports** [P]: over-parallelisation ("serial execution with targeted parallelization has worked better than broad parallelism"), error accumulation across long plans, orchestrator scoping too broadly, workers stalling on edge cases, narrow-vs-broad worker scope trade-off, orchestrator depth (one layer fine, three "starts to feel like a bureaucracy"). https://factory.com/news/missions
- **Agent Readiness** [P]: 8 pillars (style/validation, build, testing, docs, dev environment, code quality, observability, security/governance), 5 levels (Functional -> Autonomous); 60+ LLM-scored binary criteria; level unlocks at 80% plus all prior levels; L3 = "production-ready for agents". Claim: uneven agent results usually stem from the codebase environment, not the model. Scoring variance fell from 7% to 0.6% after grounding on prior reports. Examples: CockroachDB L4 (74%), FastAPI L3 (53%), Express L2 (28%). Jan 20, 2026. https://factory.com/news/agent-readiness
- **Reported results** [S, ZenML summary of Factory material, 2026]: ~15-20% of Factory's own changes are fully autonomous; "autonomy ratio" in upper 80s; Missions cited as migrating 30-50M LOC codebases. No methodology. https://www.zenml.io/llmops-database/building-autonomous-software-engineering-agents-for-enterprise-with-forward-deployed-engineering

### 1.2 Cognition Devin

- **Pipeline/surfaces** [P]: tasks arrive from Slack/Teams/Jira/Linear/API/Sentry events; Devin works in a VM with shell, IDE, browser; opens PR; Devin Review + Autofix handles review comments and CI failures. Guide: tasks you could finish in about 3 h are in reach. https://docs.devin.ai/ ; https://docs.devin.ai/essential-guidelines/instructing-devin-effectively
- **Decomposition** [P]: humans split complex work into verifiable sub-tasks, one session each; playbooks encode repeated tasks (outcome, steps, postconditions, forbidden actions, required inputs). April 2026: a manager Devin can spawn child Devins coordinated via internal MCP ("map-reduce-and-manage"), live, no metrics. https://docs.devin.ai/essential-guidelines/instructing-devin-effectively ; https://nader.substack.com/p/how-cognition-uses-devin-to-build ; https://cognition.com/blog/multi-agents-working
- **Architecture stance** [P]: June 12, 2025 "Don't Build Multi-Agents": share full traces; actions carry implicit decisions; prefer single-threaded linear agent plus a context-compression model. April 22, 2026 follow-up: writes stay single-threaded, extra agents contribute intelligence only (review, consultation, planning); three flows that work: generator-verifier review loop, "smart friend" escalation, manager-child delegation; unstructured swarms "mostly a distraction". https://cognition.com/blog/dont-build-multi-agents ; https://cognition.com/blog/multi-agents-working
- **Verification** [P]: Devin Review reads the diff with clean context; about 2 bugs per PR, ~58% severe (internal, no baseline). Docs tell users to define evaluation criteria and checkpoints before assigning, to have Devin run tests/dev server/browser and record screen captures before opening a PR. https://cognition.com/blog/multi-agents-working ; https://docs.devin.ai/essential-guidelines/instructing-devin-effectively
- **Humans** [P]: review the PR, "not the logs"; "the bottleneck shifted from writing code to reviewing it." https://nader.substack.com/p/how-cognition-uses-devin-to-build
- **Metrics (self-reported)**: 2025 review (Nov 14, 2025): PR merge rate 67% vs 34% a year earlier; security fixes ~1.5 min vs ~30 min human; migrations 10-14x faster; "hundreds of thousands" of PRs merged. https://cognition.com/blog/devin-annual-performance-review-2025 . Feb 11, 2026: 659 Devin PRs merged in one week at Cognition vs 154 in best week of 2025 (secondary account of Cognition's own post). https://nader.substack.com/p/how-cognition-uses-devin-to-build
- **What fails (Cognition)** [P]: ambiguous projects needing judgement, requirements that change mid-task ("performance drops when more instructions arrive after it starts"), code quality judgement, visual design without exact specs. https://cognition.com/blog/devin-annual-performance-review-2025
- **Newer** [S]: Devin Fusion (planner + cheaper executor, announced June 29, 2026) is reported with a 46% cost reduction and one reviewer saw quality drop 54->27 on a hard front-end task when delegating; vendor-benchmarked. https://cryptobriefing.com/cognition-devin-fusion-multi-model-coding-agent/ ; https://eesel.ai/blog/devin-fusion-review (treat as unverified).

### 1.3 OpenAI Codex (cloud agent) and OpenAI's "harness engineering"

- **Launch (May 19, 2025)** [S/InfoQ]: codex-1 (o3 tuned with RL on real tasks); each task in an isolated container preloaded with the repo, no internet during task; commits in sandbox and returns test outputs and terminal logs as evidence; 1-30 min per task; AGENTS.md for repo instructions; final verification stays with humans. https://www.infoq.com/news/2025/05/openai-codex (official post returned 403: https://openai.com/index/introducing-codex/)
- **Current cloud model** [P]: environment = repos, secrets, network, install script; per-environment internet allow-list with package-manager preset and extra domains; each task has its own workspace; tasks keep running while your computer sleeps; result is a diff you inspect then commit/open a PR. https://learn.chatgpt.com/docs/cloud
- **Isolation/approval (local)** [P]: modes read-only / workspace-write (default, network off, .git/.agents/.codex protected) / danger-full-access; OS sandbox (Seatbelt, bwrap+seccomp); optional `approvals_reviewer = auto_review` routes approval requests to a reviewer agent. Legacy cloud: setup phase has network and secrets, agent phase offline, secrets removed. https://learn.chatgpt.com/docs/agent-approvals-security
- **Harness engineering experiment (Feb 11, 2026; Ryan Lopopolo)** [S: summaries; official post 403]: ~5 months, internal beta product, ~1M lines, "zero manually-written code", ~1,500 PRs, team 3 -> 7 engineers; PRs per engineer per day 3.5 (Dec) -> 5-10 after GPT-5.2; ~1B tokens/day (~$2-3k/day estimated). https://openai.com/blog/harness-engineering (403) ; https://latent.space/p/harness-eng ; https://www.zenml.io/llmops-database/extreme-harness-engineering-building-production-software-with-zero-human-written-code
  - Practices [S]: ~100-line AGENTS.md acting as a table of contents to deeper docs; docs (spec, core-beliefs, tech-debt tracker, quality score, reliability) are the system of record; when an agent fails, ask what capability/context/structure is missing instead of prompting harder; review agent fires on each PR push, author must acknowledge but may push back; reviewers initially "bullied" authors into non-convergent loops, fixed by giving both sides optionality and biasing reviewers toward merging; most human review is post-merge sampling; agents merge via a "land" skill with merge queue; build inner loop capped at <1 min; local observability stack (logs/metrics/traces) agents boot themselves; daily agent loops mine session logs to update guidance; Symphony (Elixir) supervises one process per ticket with a "rework" state that discards a bad worktree and restarts; "ghost libraries" (spec -> fresh agent reimplements -> reviewers refine spec until fidelity is high). https://latent.space/p/harness-eng ; https://www.zenml.io/llmops-database/extreme-harness-engineering-building-production-software-with-zero-human-written-code
  - Failure modes [S]: first 6 weeks ~10x slower than doing it by hand; reviewer/author loops; gnarly refactors and zero-to-one products still need heavy human steering; small model burned 3 compactions before writing code; silent architecture drift (a Playwright daemon replaced unnoticed); human attention (not tokens) the bottleneck. Same sources.
- **Benchmark stance** [S/search snippet]: OpenAI stopped reporting SWE-bench Verified (post Feb 23, 2026) citing contamination; audit of 138 hardest problems found 59.4% with material test/description flaws; recommends SWE-bench Pro. https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/ (403, from search snippet)

### 1.4 GitHub Copilot coding agent / Agent HQ

- **Pipeline** [P]: assign issue (or `/task`, agents panel, mobile) -> ephemeral GitHub Actions environment (configured via `copilot-setup-steps.yml`, job must be named `copilot-setup-steps`) -> research, plan, implement, run tests/linters -> self-review -> PR on `copilot/` branch -> human review. Max 59-minute session; one repo, one branch, one PR per task. https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent ; https://github.blog/ai-and-ml/github-copilot/onboarding-your-ai-peer-programmer-setting-up-github-copilot-coding-agent-for-success/
- **Isolation/safety** [P]: network firewall (default on; covers only processes the agent starts, not MCP servers/setup steps); push only to its own branch via simple pushes; cannot mark ready, approve, or merge; requester cannot approve their own agent's PR; workflows need a write-access user to approve; only write-access users can trigger; hidden characters/HTML comments stripped to blunt prompt injection. https://docs.github.com/en/copilot/concepts/agents/coding-agent/risks-and-mitigations ; https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/customize-the-agent-firewall
- **Verification** [P]: before opening the PR the agent runs CodeQL, checks new dependencies against the Advisory Database, runs secret scanning and a code-review pass, and fixes what they find (changelog Oct 28, 2025); self-runs Copilot code review before requesting yours (blog Feb 26, 2026); validation tools run in parallel and are admin-configurable (Mar-Apr 2026). https://github.blog/changelog/2025-10-28-copilot-coding-agent-now-automatically-validates-code-security-and-quality/ ; https://github.blog/ai-and-ml/github-copilot/whats-new-with-github-copilot-coding-agent/
- **Human loop** [P]: mission control lets you steer mid-task (agent adapts after current tool call); session logs show every step; Agent HQ (Oct 28, 2025) manages Copilot plus third-party agents (Codex, Anthropic, Google, Cognition, xAI planned) under one governance/branch-control plane. https://github.blog/changelog/2025-10-28-a-mission-control-to-assign-steer-and-track-copilot-coding-agent-tasks/ ; https://github.blog/news-insights/company-news/welcome-home-agents/
- **Metrics**: GitHub's own posts report no merge rates (the Feb 2026 post gives none). https://github.blog/ai-and-ml/github-copilot/whats-new-with-github-copilot-coding-agent/

### 1.5 Google Jules

- **Pipeline** [P]: pick repo/branch + prompt -> Jules clones into a cloud VM and proposes a plan -> human approves (or auto-approve) -> executes, tests -> critic -> PR. Reads AGENTS.md. https://jules.google/docs/ ; https://i-programmer.info/news/105-artificial-intelligence/18249-google-jules-coding-assistant-now-available.html (GA Aug 14, 2025)
- **Critic** [P]: Aug 8, 2025 adversarial reviewer of every proposed change (one-shot, flags but does not fix, hands back to Jules); Sep 3, 2025 critic reasoning visible in UI; Jan 26, 2026 "Planning Critic" reviews auto-approved plans before code runs, "reported to cut the task failure rate by 9.5%" (vendor, no method). https://jules.google/docs/changelog/
- **Verification** [P]: Playwright in base image, screenshots for front-end work (Aug 2025), "visual verification" with Gemini 3 Pro (Nov 2025). https://jules.google/docs/changelog/
- **Scale/limits** [P]: tiers 15/100/300 tasks/day and 3/15/60 concurrent; CLI `--parallel` up to 5 attempts of the same prompt. Beta: "tens of thousands of tasks, 140,000+ publicly shared code improvements" (a count of tasks, not merged PRs). https://i-programmer.info/news/105-artificial-intelligence/18249-google-jules-coding-assistant-now-available.html ; https://jules.google/docs/changelog/ ; https://blog.google/technology/google-labs/jules-now-available/
- **API** [S]: Source/Session/Activity objects; Jules Tools CLI Oct 2, 2025. https://sdtimes.com/softwaredev/googles-coding-agent-jules-now-works-in-the-command-line/

### 1.6 Cursor (background/cloud agents, scaled swarms)

- **Cloud agents** [P]: each agent in its own isolated VM with repo, deps, secrets; env via agent-led setup, snapshot, or Dockerfile in `.cursor/environment.json`; background builds prepare environments; works on a branch, opens PR with artifacts (screenshots, videos, logs); computer use drives a desktop/browser; user can take over remote desktop; hooks run in the cloud; multi-repo environments. https://cursor.com/docs/cloud-agent ; https://cursor.com/blog/agent-computer-use (Feb 24, 2026)
- **Metric** [P]: >30% of PRs Cursor merges are created by autonomous cloud agents. https://cursor.com/blog/agent-computer-use
- **Aug 19, 2026 changelog** [P]: event subscriptions (agents auto-subscribe to PRs they open and fix CI / address bot comments), `/goal` long-lived objective, steering that waits for the next tool call, subagents in separate VMs with clean copies. https://cursor.com/changelog/08-19-26
- **Scaling long-running agents (Jan 14, 2026, Wilson Lin)** [P]: hundreds of concurrent agents. Flat self-coordination via shared file failed (locks held too long: 20 agents slowed to the throughput of 2-3; optimistic concurrency simpler but agents became risk-averse, making small safe changes). Fix: planners (recursive sub-planners) + workers that don't talk to each other + a judge at the end of each cycle that decides whether to continue, with a fresh start each iteration. Integrator role removed as a bottleneck. Model choice mattered per role (GPT-5.2 stayed on task; Opus 4.5 "tended to stop early and take shortcuts"). Outputs: browser from scratch ~1M lines/~1,000 files over about a week; Solid->React migration +266K/-193K over 3 weeks "still needs careful review". Lessons: removing complexity helped; "the harness and models matter, but the prompts matter more"; periodic fresh starts needed to counter drift. https://cursor.com/blog/scaling-agents

### 1.7 Amp (Sourcegraph spin-out)

- **Modes/subagents** [P]: modes low/medium/high/ultra pick model+effort+prompt; specialised subagents: Oracle (hard reasoning/planning), Librarian (external code), Search, Task (delegated coding/verification), Read Thread. Subagents have own context, cannot talk to each other, cannot be guided mid-task, start from instructions the main agent gives them, return only a final summary. https://ampcode.com/docs/models-and-subagents
- **Orbs (cloud agents)** [P]: remote machine per thread with your code and tools; `.agents/setup` runs on fresh orb (428-line script in Amp's own repo), snapshot reused up to 24 h; `.agents/resume` on each wake; 41 nested AGENTS.md files read on demand; agent self-verifies by screenshots saved to `.amp/in/artifacts/`; idempotent dev-server script, ports file, one log file, magic-login endpoint. "The environment doesn't just tolerate an agent; it assumes one." Orbs pause when idle. Note dated July 2, 2026 (Thorsten Ball). https://ampcode.com/notes/putting-an-agent-in-an-orb ; https://ampcode.com/docs/orbs
- **Handoff vs compaction** [S]: Amp's handoff writes an editable new-thread prompt rather than lossy auto-compact. https://hamel.dev/notes/coding-agents/amp.html (via search; not fetched)

### 1.8 OpenHands and SWE-agent (open source)

- **OpenHands Software Agent SDK** (arXiv 2511.03690, MLSys 2026) [P]: event-sourced immutable events + single ConversationState (crash-resume, sub-ms persist, <20 ms recovery); Workspace abstraction (Local/Docker/Remote) so same agent code moves from laptop to sandbox; REST/WebSocket agent server; LLMSecurityAnalyzer rates each tool call low/medium/high/unknown and a ConfirmRisky policy pauses above a threshold; LLMSummarizingCondenser for context (up to 2x lower API cost with no reported degradation); SWE-bench Verified best 76.6%; V1 cut system-attributable errors from 78 to 30 per 1k conversations in a 15-day rollout. https://arxiv.org/abs/2511.03690 ; https://arxiv.org/html/2511.03690v2
- **OpenHands repo** [P]: ~91k stars, MIT; Agent Canvas control centre running OpenHands or Claude Code/Codex/Gemini CLI; per-conversation Docker sandbox option; webhook/scheduled automations. https://github.com/OpenHands/OpenHands
- **SWE-agent** [P]: "takes a GitHub issue and tries to fix it"; maintainers now recommend mini-SWE-agent (100 lines Python, 65% SWE-bench Verified); SWE-agent paper (ACI) showed interface design for agents moves performance (12.5% on SWE-bench at the time). https://github.com/SWE-agent/SWE-agent ; https://arxiv.org/abs/2405.15793

### 1.9 Kiro and GitHub spec-kit (spec-driven development, SDD)

- **Kiro** [P]: three artifacts per spec (requirements.md or bugfix.md, design.md, tasks.md); feature specs can be requirements-first or design-first; bugfix specs record current/expected/unchanged behaviour; Quick Spec skips approval gates; "Run all tasks" builds a dependency graph and runs waves (tasks within a wave concurrent); "Analyze Requirements" finds inconsistencies before design; IDE-only "Correctness" uses property-based testing. https://kiro.dev/docs/specs/
  - Rationale for PBT [S, VentureBeat Nov 16, 2025 quoting AWS]: "AI models often 'game' the solution by modifying tests instead of fixing code"; derive properties from the spec instead of hand-picked cases. Kiro GA Nov 2025. https://venturebeat.com/ai/in-a-sea-of-agents-aws-bets-on-structured-adherence-and-spec-fidelity
- **spec-kit** [P]: commands constitution -> specify -> (clarify) -> plan -> tasks -> implement, plus a converge loop with implement; ~141k stars. Constitution has nine articles incl. test-first ("no implementation code before tests are written, approved, and confirmed to fail") and integration-first; templates force `[NEEDS CLARIFICATION]` markers instead of guessing. The doc itself admits no empirical evidence and that gates are "completed by the LLM itself", so enforcement is soft. https://github.com/github/spec-kit ; https://github.com/github/spec-kit/blob/main/spec-driven.md ; launch post Sep 2, 2025 https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/
- **Independent critique** [I] (Böckeler, martinfowler.com, Oct 15, 2025): all three tools are spec-first only; Kiro turned a small bug into 4 user stories with 16 acceptance criteria; spec-kit produced many repetitive markdown files she would rather not review; agents both ignored and over-applied instructions ("false sense of control"); Tessl regenerations still varied. https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html

### 1.10 Newer / adjacent systems worth knowing

- **Stripe Minions** (Feb 2026) [P/S]: one-shot end-to-end agents (fork of Block's Goose) triggered from Slack/tickets; "blueprints" interleave deterministic nodes (git, lint, push) with agent loops; pre-warmed devboxes (~10 s) isolated from prod and internet so agents run without permission prompts (stated to scale better than worktrees); scoped rule files by directory; Toolshed MCP with ~400-500 tools, curated subsets per agent; local lint <5 s; CI capped at two rounds, then back to human; every PR human-reviewed; 1,000 -> 1,300+ merged PRs/week. https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents ; https://blog.bytebytego.com/p/how-stripes-minions-ship-1300-prs ; https://www.infoq.com/news/2026/03/stripe-autonomous-coding-agents/
- **Spotify Honk** (Dec 2025 / Mar 2026) [P/S]: verifiers (build/format/test) hidden behind an MCP tool so the agent "doesn't know what the verification does"; stop hook re-runs verifiers before PR; separate LLM judge on the diff vs original prompt vetoed ~25% of sessions, agent self-corrected ~half the time; later judge removed as models improved because it was too rigid; agents took shortcuts like commenting out failing tests; agent runtime separate from verification runtime (via CI); 1,000 merged PRs took 3 months, later 10 days; PR review became the bottleneck. https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3 ; https://www.infoq.com/news/2026/03/spotify-honk-rewrite
- **Ramp Inspect** [P-ish, Modal case study]: Modal sandbox per session with Postgres/Redis/Temporal/RabbitMQ, VS Code server, VNC+Chromium; repo snapshots rebuilt every 30 min so sessions start in seconds; agent screenshots and checks Sentry/Datadog/LaunchDarkly; "roughly half of merged PRs" (other sources say ~30% or ~40% at different dates); "speed is a hard requirement". https://modal.com/blog/how-ramp-built-a-full-context-background-coding-agent-on-modal
- **Anthropic harness for long-running agents** (Nov 26, 2025) [P]: initializer agent writes `feature_list.json` (200+ features all `passes:false`, agent may only flip `passes`), `init.sh`, `claude-progress.txt`, initial git commit; each later session does startup routine (pwd, git log, progress, pick one feature, run init.sh + smoke test), works one feature, commits; end-to-end browser testing via Puppeteer MCP because unit tests/curl missed broken features; JSON chosen because models are less likely to overwrite it than Markdown. https://anthropic.com/engineering/effective-harnesses-for-long-running-agents
- **Anthropic C compiler with 16 parallel Claudes** [P]: bash loop restarts Claude Code; each agent in its own Docker container with a clone of a bare git repo; no orchestrator, tasks claimed by lock files in `current_tasks/` (git sync resolves collisions); near-perfect test suite as verifier; CI blocks regressions; output designed for models (terse console, greppable ERROR, `--fast` sampling); GCC used as oracle to split the monolithic kernel-build task into parallelisable pieces; ~2,000 sessions, ~$20k, ~100k lines Rust. Limits: new features often broke old ones; "passing tests can be mistaken for completed work". https://www.anthropic.com/engineering/building-c-compiler
- **Anthropic multi-agent research system** [P]: lead + parallel subagents beat single agent by 90.2% on internal eval but at ~15x chat tokens; token use explained ~80% of BrowseComp variance; early failure: spawning 50 subagents for simple queries; vague delegation caused duplicated work; checkpoint-and-resume; subagents write to external storage and pass references. https://www.anthropic.com/engineering/multi-agent-research-system
- **Claude Code Review** [P]: parallel finder agents -> verification step that drops false positives -> dedupe/rank by severity -> inline comments; read-only, never approves or blocks; works by reading, not building or running code; REVIEW.md read from base branch only. https://code.claude.com/docs/en/code-review . Launch Mar 9, 2026; internal "substantive review comments 16% -> 54%" and $15-25/review are from secondary coverage only [S]. https://www.vktr.com/ai-news/anthropic-launches-multi-agent-code-review-for-claude-code/

---

## 2. Cross-system comparison (condensed)

| System | Decomposition | Isolation | Correctness mechanism | Human gate | Long-task/context strategy |
|---|---|---|---|---|---|
| Factory Missions | orchestrator -> milestones -> features, fresh worker each | local or cloud container; git as truth | per-milestone validator workers (diff model family), computer-use QA, Readiness score | approve plan, unblock | fresh sessions, skills, milestone checkpoints |
| Devin | human splits; manager-child (2026); playbooks | per-session VM | Devin Review (clean-context), Autofix, user-defined checkpoints | review PR | context compression model; scoped sessions |
| Codex cloud | one task per container, parallel tasks | container, network allow-list | tests/linters, logs as evidence, AGENTS.md | inspect diff, open PR | per-task workspace; AGENTS.md; compaction |
| Copilot agent | issue -> one PR | Actions env + firewall + branch lock | CodeQL, secrets, dep check, self code review, CI after human approves run | cannot merge; human approves workflows | 59-min session cap; steer mid-task |
| Jules | plan -> execute | cloud VM | Planning Critic + code critic, Playwright | plan approval, PR review | per-task VM |
| Cursor | planner/sub-planner/worker/judge (swarm); subagents | VM per agent | agent self-test with computer use, CI-subscribed fix loop, judge | review PR; take over desktop | fresh start per cycle, `/goal`, event wake-ups |
| Amp | main agent + oracle/subagents | orb per thread | screenshots, logs, repo scripts | review, sync | handoff, orb sleep/resume |
| OpenHands | SDK, delegate | Docker/remote workspace | risk analyzer, confirm policy | confirm risky actions | condenser, event log resume |
| Kiro/spec-kit | requirements -> design -> tasks (waves) | local IDE/CLI | EARS, PBT, test-first constitution, analyze | approve each phase | specs persist in repo |
| Stripe Minions | blueprint nodes | devbox (no prod/internet) | lint -> CI (<=2 rounds) | review every PR | scoped rules, curated tools |

---

## 3. Design patterns (21), with evidence

Ordered roughly by impact. "Evidence" strength: **Strong** = independently measured or consistent across many unrelated sources; **Moderate** = consistent multi-vendor but self-reported; **Weak** = single vendor claim.

1. **Deterministic verifiers are the foundation; agent autonomy scales with verifiability.**
   Used by: Factory (Agent Readiness), Anthropic C compiler, Spotify, Stripe, Devin docs, Cursor, OpenAI harness.
   Why: the agent will optimise whatever the checks reward ("an autonomous agent will solve whatever problem the tests define"). Factory ties readiness level to feasible autonomy (L4+ for Missions); Cursor/Anthropic built giant test/oracle suites before scaling out.
   Evidence: Moderate-Strong (consistent, but mostly self-reported). https://factory.com/news/agent-readiness ; https://www.anthropic.com/engineering/building-c-compiler ; https://docs.devin.ai/essential-guidelines/instructing-devin-effectively

2. **Hide verification behind a tool; run it outside the agent's control; re-run before PR.**
   Used by: Spotify (MCP verifier abstraction, stop hook, CI-based verification runtime), Stripe (hardcoded lint/push nodes), Copilot (separate firewall/push constraints).
   Why: agents game weak checks (commenting out failing tests, downgrading Java versions, disabling flaky tests) and verification output also pollutes context unless condensed.
   Evidence: Moderate. https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3 ; https://www.infoq.com/news/2026/03/spotify-honk-rewrite

3. **Hybrid "blueprint" orchestration: deterministic nodes around bounded agent loops.**
   Used by: Stripe Minions, Spotify, Copilot (fixed validate-then-PR), Kiro hooks, Factory (milestone validation).
   Why: required steps (git, lint, push, scans) always run identically; the LLM only handles open-ended steps. Cuts cost and variance.
   Evidence: Moderate (Stripe 1,300+ PRs/week, but no failure-rate data). https://blog.bytebytego.com/p/how-stripes-minions-ship-1300-prs

4. **Plan first, with a human-approved plan before any code.**
   Used by: Factory ("where most of the value comes from"), Jules plan approval, Kiro phases, spec-kit, Copilot Plan Mode, Cursor planners.
   Why: catches misunderstanding when it is cheapest; plan becomes the checklist validators run against.
   Evidence: Moderate. Jules reports its Planning Critic on auto-approved plans cut failures 9.5% (vendor). https://jules.google/docs/changelog/ ; https://factory.com/news/missions

5. **Fresh context per unit of work (one feature/session), state carried in artifacts not memory.**
   Used by: Factory (fresh worker per feature), Anthropic harness (feature_list.json, progress file, git log), Cursor (fresh start each cycle), Amp handoff, Cognition (compression model), OpenHands condenser.
   Why: long contexts degrade ("context rot"); externalised state survives resets and crashes.
   Evidence: Moderate-Strong. https://anthropic.com/engineering/effective-harnesses-for-long-running-agents ; https://cursor.com/blog/scaling-agents ; https://arxiv.org/abs/2511.03690

6. **Structured, agent-hostile-to-edit task list (JSON with pass/fail), one feature at a time.**
   Used by: Anthropic harness; Kiro tasks.md with status; Factory feature lists.
   Why: stops "declare victory early" and "try to do everything at once"; JSON is overwritten less than Markdown; only the `passes` field is editable.
   Evidence: Weak-Moderate (single vendor post, qualitative). https://anthropic.com/engineering/effective-harnesses-for-long-running-agents

7. **Writes stay single-threaded (or strictly partitioned); extra agents add review/advice, not parallel edits.**
   Used by: Cognition (explicit rule), Factory ("serial with targeted parallelism"), Amp subagents (no cross-talk), Cursor workers (isolated tasks, no coordination), Anthropic C compiler (parallel only on independent failing tests; oracle to split kernel work).
   Why: parallel writers make conflicting implicit decisions (Flappy Bird background mismatch); flat self-coordination failed at Cursor (locks, risk-aversion).
   Evidence: Moderate (multiple independent teams converged; no controlled study). https://cognition.com/blog/dont-build-multi-agents ; https://cursor.com/blog/scaling-agents ; https://factory.com/news/missions

8. **Hierarchy with narrow roles beats flat peer coordination; keep it shallow.**
   Used by: Cursor (planner -> sub-planner -> worker -> judge), Factory (one orchestrator layer; three layers "a bureaucracy"), Devin manager-child.
   Why: flat agents avoid hard tasks and thrash on locks; a judge decides stop/continue; but integrators and deep hierarchies added bottlenecks.
   Evidence: Moderate. https://cursor.com/blog/scaling-agents ; https://factory.com/news/missions

9. **Generator-verifier split with a clean-context reviewer (and a verification pass that filters the reviewer's false positives).**
   Used by: Devin Review, Claude Code Review, Jules critic, Copilot self-review, OpenAI harness review agent, Factory validators.
   Why: reviewer sees only the diff, so it avoids the author's accumulated assumptions; a second verify step removes false positives.
   Evidence: Moderate. Devin Review ~2 bugs/PR with ~58% severe (internal, no baseline); Anthropic's 16%->54% substantive-comment figure is secondary-only. https://cognition.com/blog/multi-agents-working ; https://code.claude.com/docs/en/code-review

10. **Use a different model family for validation than for implementation.**
    Used by: Factory (GPT-5.3-Codex validates Claude-built work), Cursor (per-role model selection), Cognition (cross-frontier smart friend), Amp (Oracle).
    Why: decorrelates errors and blind spots.
    Evidence: Weak-Moderate (design choice stated, no ablation). https://factory.com/news/missions ; https://cognition.com/blog/multi-agents-working

11. **Per-task disposable VM/container with the full dev stack, pre-warmed from snapshots.**
    Used by: Stripe devboxes (~10 s), Ramp (30-min snapshots), Cursor, Amp orbs (24 h snapshot), Codex cloud, Jules, Copilot (Actions), OpenHands (Docker per conversation).
    Why: safe to run without permission prompts; real services available for E2E; parallel without worktree conflicts; startup speed determines adoption ("a background agent slower than a local one won't be adopted").
    Evidence: Moderate-Strong (nearly universal). https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents ; https://modal.com/blog/how-ramp-built-a-full-context-background-coding-agent-on-modal ; https://ampcode.com/notes/putting-an-agent-in-an-orb

12. **Network and permission minimisation by default (firewall/allow-list, secrets only during setup, branch-locked pushes).**
    Used by: Copilot, Codex cloud, Cursor, Stripe, Spotify (few binaries), OpenHands risk analyser.
    Why: agents read untrusted content (issues, web) and hold secrets; mitigates prompt-injection exfiltration. Gaps remain: Copilot firewall does not cover MCP servers; Codex's proxy does not cover web search/MCP.
    Evidence: Moderate (documented controls; limited incident data). https://docs.github.com/en/copilot/concepts/agents/coding-agent/risks-and-mitigations ; https://learn.chatgpt.com/docs/agent-approvals-security

13. **Agent cannot approve or merge its own work; trigger rights limited to trusted users.**
    Used by: Copilot (requester cannot approve; write-access only), Claude Code Review (never approves/blocks), Stripe (every PR human reviewed), Cursor, Devin. Exception: OpenAI harness team merges autonomously via a "land" skill with post-merge sampled human review, in a non-continuously-deployed app with human-gated releases.
    Evidence: Moderate. https://docs.github.com/en/copilot/concepts/agents/coding-agent/risks-and-mitigations ; https://latent.space/p/harness-eng

14. **Make the repo and environment agent-legible: short AGENTS.md as table of contents, nested/scoped rule files, quiet CLIs, one log file, paved paths.**
    Used by: OpenAI (~100-line AGENTS.md pointing to docs), Amp (41 nested AGENTS.md; `/__dev/log-me-in`, ports file, `preflight`), Stripe (directory-scoped rules, curated MCP subsets), Codex/Jules/Copilot (AGENTS.md or copilot-instructions), Anthropic compiler (greppable ERROR lines).
    Why: loading too many rules or tools overloads context; agents waste time guessing how to run/log in; Playwright MCP was replaced at OpenAI with a CLI shim because MCP injected too many tokens.
    Evidence: Moderate (many consistent practitioner reports, no controlled test). https://ampcode.com/notes/putting-an-agent-in-an-orb ; https://latent.space/p/harness-eng ; https://blog.bytebytego.com/p/how-stripes-minions-ship-1300-prs

15. **Real end-to-end self-verification: browser/computer use, screenshots, video artifacts.**
    Used by: Cursor (computer use, videos), Factory (computer-use validators), Ramp (VNC/Chromium, Datadog/Sentry), Amp, Jules (Playwright), Devin (browser, screen recording), Anthropic harness (Puppeteer).
    Why: unit tests and curl missed features that did not work end to end (Anthropic); artifacts shorten human review.
    Evidence: Moderate. Limits: weak vision, native browser alert modals invisible to Puppeteer (Anthropic); artifacts are not proof of correctness. https://anthropic.com/engineering/effective-harnesses-for-long-running-agents ; https://cursor.com/blog/agent-computer-use

16. **Cap retries and bound runs: hard limits on CI rounds, session length, spend; escalate to a human when exceeded.**
    Used by: Stripe (max 2 CI rounds), Copilot (59-min cap), Factory (feature retry limits), Jules (task/day quotas), Cursor (spend limit required).
    Why: diminishing returns on repeated retries; review loops can drift or become non-convergent.
    Evidence: Moderate (Stripe's rationale explicit; others implicit). https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents ; https://cognition.com/blog/multi-agents-working

17. **Give reviewer and author agents asymmetric, convergent protocols (author may push back, reviewer biased toward merging, scope-filter findings).**
    Used by: OpenAI harness, Cognition (findings filtered against user instructions), Spotify judge (scope check vs original prompt).
    Why: reviewer-author loops otherwise "bully" the author into non-convergence or drift out of scope.
    Evidence: Moderate (reported as problems found and fixed). https://latent.space/p/harness-eng ; https://cognition.com/blog/multi-agents-working

18. **Spec-first artifacts with explicit gates and testable acceptance criteria (EARS, PBT, test-first constitution) - but scale the ceremony to task size.**
    Used by: Kiro, spec-kit, Factory plans, Copilot Plan Mode.
    Why: unstated requirements are guessed wrong and discovered late; PBT counters tests that models rewrite to pass.
    Evidence: Weak. Mostly vendor argument; the only independent review (Böckeler) found over-specification, review overload, and non-determinism. https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html ; https://github.com/github/spec-kit/blob/main/spec-driven.md

19. **Event-driven, always-on agents: subscribe to PR/CI/Slack/Sentry events and drive a PR to green.**
    Used by: Cursor (auto-subscribe to own PRs), Devin (Autofix, Sentry-triggered sessions, Linear bug label playbook), Copilot (mission control steering), OpenHands automations, Jules API.
    Why: turns the "last mile" (CI fixes, review comments) into agent work; trigger from where work originates.
    Evidence: Moderate (product features, little outcome data). https://cursor.com/changelog/08-19-26 ; https://nader.substack.com/p/how-cognition-uses-devin-to-build

20. **Close the improvement loop: mine session logs/PR comments into updated skills, docs, linters; fix the harness not the instance.**
    Used by: OpenAI harness (daily log mining, agents file follow-up tickets), Factory (agent-readiness fix loop, learned skills), Cognition (Session Insights, playbooks), Amp (setup scripts).
    Why: encodes tribal knowledge once; compounding returns.
    Evidence: Weak-Moderate. https://latent.space/p/harness-eng ; https://factory.com/news/agent-readiness

21. **Treat human review capacity as the scarce resource; build tooling and policy for it.**
    Used by: Spotify (PR inbox, drivers approve own migration PRs, stale PR closure), Cognition (Devin Review on every PR), Stripe, OpenAI (post-merge sampling), Cursor (video artifacts, remote-desktop takeover), Ramp (bottleneck moves to number of parallel agents).
    Why: generation is now cheap; review is the bottleneck in every mature deployment.
    Evidence: Moderate-Strong (stated independently by Cognition, Spotify, OpenAI, Ramp). https://www.infoq.com/news/2026/03/spotify-honk-rewrite ; https://nader.substack.com/p/how-cognition-uses-devin-to-build ; https://latent.space/p/harness-eng

Additional patterns noted but not elevated: per-role model routing/cost tiers (Amp modes, Factory, Devin Fusion, Cursor); "smart friend" escalation (Cognition, only works with two strong models); oracle-based task splitting (Anthropic compiler: GCC as known-good reference); best-of-N parallel attempts (Jules `--parallel`, Cursor multi-model); checkpoint/resume and event-sourced state (OpenHands, Anthropic research); risk-classified command approval (Factory, OpenHands, Codex auto_review).

---

## 4. Failure modes reported by the sources, and mitigations

| Failure mode | Reported by | Mitigation |
|---|---|---|
| Agent "wins" by weakening checks (comment out tests, downgrade versions, disable flaky tests, rewrite tests) | Spotify; AWS (Kiro PBT rationale) | Verifiers outside agent, hidden behind tool; LLM judge vs original prompt (later dropped); PBT from spec; "agent may only flip `passes`" |
| Declares done too early / marks features passing untested | Anthropic harness | Structured feature list, end-to-end browser test requirement, startup smoke test |
| Passing tests mistaken for completed work | Anthropic C compiler; METR; FrontierCode | Human verification, maintainer-style rubrics, oracles |
| Parallel agents make conflicting implicit decisions | Cognition; Cursor; Factory | Single-threaded writes, partitioned tasks, fresh planner cycles, judge |
| Flat self-coordination: lock contention, risk aversion | Cursor | Planner/worker/judge hierarchy; remove integrator |
| Over-deep management layers | Factory; Cursor | One orchestrator layer |
| Context rot / compaction loss | Cognition; Factory; OpenAI (small model burned 3 compactions) | Fresh sessions, compression model, handoff prompts, externalised state |
| Error accumulation in long plans | Factory | Milestone validation (catches most, not all) |
| Stuck workers on edge cases | Factory | Orchestrator can mark complete/re-plan; human unblock |
| Review loops non-convergent / reviewer drift / out-of-scope changes | OpenAI harness; Cognition; Spotify | Optionality for author, merge-biased reviewer, filter findings by user instructions, scope judge |
| Diminishing returns from CI retries | Stripe | 2-round cap, then human |
| Unfamiliar internal stack (homegrown libs, Ruby+Sorbet) | Stripe | Scoped rules, curated tools, human polish |
| Too many tools/rules/MCP tokens overload context | Stripe; OpenAI | Curated MCP subsets, directory-scoped rules, CLI shim instead of Playwright MCP |
| Agent runs far too long; drift/tunnel vision | Cursor | Periodic fresh starts |
| Requirements change mid-task degrade quality | Cognition | Scope up front; new session |
| Diverse codebase -> complex prompts, harder review | Spotify | Standardise (monorepo, linting, advisory boards) |
| Silent architecture drift | OpenAI harness | Quality score/tech-debt tracker; sampled human review |
| Prompt injection / exfiltration via issues, web | GitHub; OpenAI | Hidden-content filtering, firewall, write-access-only triggers, untrusted-web labelling |
| Weak primary model cannot recognise limits (smart friend) | Cognition | Use two strong models; share forked context |
| Vision limits / UI-only bugs | Anthropic; Factory; Devin; OpenAI | Rasterise to text, human visual judgement, specs for visual work |
| Long unattended failures (operational accident: `pkill -9 bash`) | Anthropic C compiler | Containers, restart loops |
| Runaway spend | Anthropic multi-agent (15x tokens); Anthropic compiler (~$20k); Factory (12x tokens) | Scale effort to complexity; spend limits (Cursor requires) |

---

## 5. Hype vs evidence

Independent / skeptical evidence:

- **METR RCT (Jul 10, 2025):** 16 experienced OSS developers, 246 issues; AI-allowed took **19% longer** though developers expected 24% faster and still believed ~20% faster afterwards. Early-2025 tools (Cursor Pro with Claude 3.5/3.7); METR says it no longer reflects current impact and published a Feb 2026 update (I did not read it). https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/
- **METR note (Mar 10, 2026):** maintainers reviewed 296 AI patches that passed SWE-bench's grader; merge rate about **24 points below** grader scores; roughly half would not be merged; Claude Sonnet 4.5's time horizon ~50 min by grader vs ~8 min by maintainers. Caveats: one attempt, no feedback, no CI, 3 repos, "not a fundamental capability limit"; METR says the note had less review than a full post. https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/
- **FrontierCode (Cognition; Artificial Analysis run, Oct 12, 2026):** merge-readiness benchmark built with maintainers of 36 repos; penalises oversized diffs, out-of-scope edits, unhelpful tests; best model scores ~52% (58% pass); top model fails 42% of attempts. Cognition-authored benchmark, so not fully independent. https://artificialanalysis.ai/articles/frontiercode
- **SWE-bench Verified contamination:** OpenAI stopped reporting it (Feb 2026) after finding 59.4% of audited hard problems had flawed tests/descriptions and models could reproduce fixes from memory; Pro also has grader issues per a May 2026 third-party audit (search snippet). https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/ (403; from search result)
- **DORA 2025:** AI is an amplifier; only some team clusters gain throughput without higher change-failure rate. https://www.infoq.com/news/2025/09/dora-state-of-ai-in-dev-2025
- **Böckeler on SDD:** see 1.9.

Self-reported numbers to treat with caution:

- "Merge rate" definitions differ and exclude PRs never opened: Devin 67% (merged "without substantial rework"; tasks are chosen to be agent-suitable), Ramp "half of merged PRs" (share of merges, not success rate; other sources cite 30% and 40%), Cursor ">30% of merged PRs", Stripe "1,300 PRs/week" (volume, not quality, with no rejection rate), Spotify "1,000 PRs in 10 days". None gives the denominator (attempted tasks) or downstream defect/revert rates. Sources: https://cognition.com/blog/devin-annual-performance-review-2025 ; https://modal.com/blog/how-ramp-built-a-full-context-background-coding-agent-on-modal ; https://cursor.com/blog/agent-computer-use ; https://blog.bytebytego.com/p/how-stripes-minions-ship-1300-prs
- "Zero manually written code" (OpenAI) and "no human-written code" (Stripe) describe authorship not correctness; OpenAI's own team reports the first 6 weeks were ~10x slower and that greenfield/ambiguous work still needs heavy steering. https://latent.space/p/harness-eng
- Cursor's browser/emulator/Excel demos (1M+ LOC) are volume artifacts; Cursor says the migration "still needs careful review", and Cognition notes such demos "depend on simple, verifiable success criteria that most real software lacks". https://cursor.com/blog/scaling-agents ; https://cognition.com/blog/multi-agents-working
- Jules "140,000 public code improvements" counts shared tasks, not merged PRs; critic "-9.5% failures" has no method. https://blog.google/technology/google-labs/jules-now-available/ ; https://jules.google/docs/changelog/
- Factory's "autonomous 15-20%" and "30-50M LOC migrations" come from a secondary summary with no method. https://www.zenml.io/llmops-database/building-autonomous-software-engineering-agents-for-enterprise-with-forward-deployed-engineering
- spec-kit's "15 minutes vs 12 hours" is illustrative, by its own admission. https://github.com/github/spec-kit/blob/main/spec-driven.md
- Cognition's own reversal on multi-agent (Jun 2025 "don't" -> Apr 2026 "what's working") shows the field's conclusions are unstable; its April evidence is "internal, no baseline." https://cognition.com/blog/multi-agents-working
- Spotify's LLM judge (vetoes ~25%) was later removed as "too rigid" once models improved: patterns that look essential can expire. https://www.infoq.com/news/2026/03/spotify-honk-rewrite

What the evidence supports best: (a) well-scoped, verifiable, repetitive work (migrations, dependency bumps, security fixes, test generation, small tickets) gets real throughput gains; (b) environment/verification investment predicts success more than model choice; (c) review and merge-readiness, not generation, is the binding constraint; (d) benchmark pass rates overstate merge-readiness by tens of points.

---

## 6. Source list (all URLs cited above, grouped)

Factory: https://factory.com/news/missions ; https://docs.factory.com/missions/overview.md ; https://factory.com/news/agent-readiness ; https://www.zenml.io/llmops-database/building-autonomous-software-engineering-agents-for-enterprise-with-forward-deployed-engineering
Cognition: https://cognition.com/blog/dont-build-multi-agents ; https://cognition.com/blog/multi-agents-working ; https://cognition.com/blog/devin-annual-performance-review-2025 ; https://docs.devin.ai/ ; https://docs.devin.ai/essential-guidelines/instructing-devin-effectively ; https://nader.substack.com/p/how-cognition-uses-devin-to-build ; https://www.zenml.io/llmops-database/multi-agent-systems-in-production-code-generation-and-review-at-scale ; https://cryptobriefing.com/cognition-devin-fusion-multi-model-coding-agent/ ; https://eesel.ai/blog/devin-fusion-review
OpenAI: https://www.infoq.com/news/2025/05/openai-codex ; https://learn.chatgpt.com/docs/cloud ; https://learn.chatgpt.com/docs/agent-approvals-security ; https://latent.space/p/harness-eng ; https://www.zenml.io/llmops-database/extreme-harness-engineering-building-production-software-with-zero-human-written-code ; https://openai.com/blog/harness-engineering ; https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/
GitHub: https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent ; https://docs.github.com/en/copilot/concepts/agents/coding-agent/risks-and-mitigations ; https://docs.github.com/en/copilot/how-tos/use-copilot-agents/coding-agent/customize-the-agent-firewall ; https://github.blog/ai-and-ml/github-copilot/onboarding-your-ai-peer-programmer-setting-up-github-copilot-coding-agent-for-success/ ; https://github.blog/changelog/2025-10-28-copilot-coding-agent-now-automatically-validates-code-security-and-quality/ ; https://github.blog/ai-and-ml/github-copilot/whats-new-with-github-copilot-coding-agent/ ; https://github.blog/changelog/2025-10-28-a-mission-control-to-assign-steer-and-track-copilot-coding-agent-tasks/ ; https://github.blog/news-insights/company-news/welcome-home-agents/
Google Jules: https://jules.google/docs/ ; https://jules.google/docs/changelog/ ; https://blog.google/technology/google-labs/jules-now-available/ ; https://i-programmer.info/news/105-artificial-intelligence/18249-google-jules-coding-assistant-now-available.html ; https://sdtimes.com/softwaredev/googles-coding-agent-jules-now-works-in-the-command-line/
Cursor: https://cursor.com/docs/cloud-agent ; https://cursor.com/blog/agent-computer-use ; https://cursor.com/changelog/08-19-26 ; https://cursor.com/blog/scaling-agents
Amp: https://ampcode.com/docs/models-and-subagents ; https://ampcode.com/notes/putting-an-agent-in-an-orb ; https://ampcode.com/docs/orbs ; https://hamel.dev/notes/coding-agents/amp.html
OpenHands / SWE-agent: https://arxiv.org/abs/2511.03690 ; https://arxiv.org/html/2511.03690v2 ; https://github.com/OpenHands/OpenHands ; https://github.com/SWE-agent/SWE-agent ; https://arxiv.org/abs/2405.15793
Kiro / spec-kit: https://kiro.dev/docs/specs/ ; https://venturebeat.com/ai/in-a-sea-of-agents-aws-bets-on-structured-adherence-and-spec-fidelity ; https://github.com/github/spec-kit ; https://github.com/github/spec-kit/blob/main/spec-driven.md ; https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/ ; https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html
Anthropic: https://anthropic.com/engineering/effective-harnesses-for-long-running-agents ; https://www.anthropic.com/engineering/building-c-compiler ; https://www.anthropic.com/engineering/multi-agent-research-system ; https://code.claude.com/docs/en/code-review ; https://www.vktr.com/ai-news/anthropic-launches-multi-agent-code-review-for-claude-code/
Stripe / Spotify / Ramp: https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents ; https://blog.bytebytego.com/p/how-stripes-minions-ship-1300-prs ; https://www.infoq.com/news/2026/03/stripe-autonomous-coding-agents/ ; https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3 ; https://www.infoq.com/news/2026/03/spotify-honk-rewrite ; https://modal.com/blog/how-ramp-built-a-full-context-background-coding-agent-on-modal
Independent evaluation: https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/ ; https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/ ; https://artificialanalysis.ai/articles/frontiercode ; https://www.infoq.com/news/2025/09/dora-state-of-ai-in-dev-2025

## 7. Gaps

- Not read in full: METR Feb 2026 update; OpenAI's primary harness-engineering and SWE-bench posts (403); Cursor/Spotify/Stripe part-1/2 primary posts beyond those linked; Cognition FrontierCode own page; Devin Outposts (one passing mention); Kiro AWS primary blog; GitHub Spec Kit "converge" details.
- No source gave attempted-vs-merged denominators, revert rates, or defect escape rates for any vendor. That is the biggest hole for evaluating real-world quality.
