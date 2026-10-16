# Techniques that make LLM coding agents produce correct code in multi-agent pipelines

Research date: 2026-10-16. Method: WebSearch plus WebFetch. About 45 distinct sources, most of them primary (arXiv papers, vendor engineering blogs, benchmark pages).

Evidence tags used below:
- [F] means I fetched the page and read the numbers.
- [S] means the claim comes from search-result snippets only and I did not open the page. Re-check before quoting.
- [2nd] means a secondary or aggregator source. Low trust.

Where sources conflicted I say so.

---

## 0. Read this first: the measurement problem

Most "agent correctness" numbers come from benchmarks whose graders are themselves wrong. This affects how much to trust any number below, and it argues for building your own evals.

- **SWE-bench Verified tests are too weak.**
  - UTBoost found 345 erroneous patches wrongly marked "passed". This affected 24.4% of Verified leaderboard entries and caused 11 ranking changes. https://arxiv.org/html/2506.09289v1 [S]
  - Wang/Pradel/Liu (ICSE 2026) found 7.8% of "correct" patches fail the developer's own test suite. 29.6% of plausible patches behave differently from the gold patch. Together these inflate resolve rates by about 6.2 points. https://arxiv.org/html/2503.15223v2 [S]
- **OpenAI audited the hardest Verified tasks.**
  - It found 59.4% of 138 tasks had material test or description flaws. It also found evidence of contamination, and stopped reporting Verified in Feb 2026. https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/ (direct fetch returned 403; figures via https://aiweekly.co/alerts/openai-drops-swe-bench-verified-backs-pro-after-flaw-audit [F, 2nd]).
- **SWE-bench Pro is also flawed.**
  - Epoch AI rated it "Flawed" on 2026-09-01. Audits estimate 30% or more of tasks are broken.
  - A May 2026 Datacurve audit found 24% false negatives and 8.5% false positives in the grader.
  - Epoch also notes the leaderboard mixes capped runs (50 turns) with uncapped runs (250 turns). https://epoch.ai/benchmarks/swe-bench-pro/review [F]
  - Pro's own paper reports that removing the human-written requirements and interface spec drops GPT-5 from 25.9% to 8.4%. This shows how much of "correctness" is spec quality. https://arxiv.org/html/2509.16941v2 [F]
- **Passing tests is not merging.** METR (2026-03-10) had four maintainers review 296 test-passing SWE-bench Verified patches.
  - Maintainer merge rates were about 24.2 points below grader scores (SE 2.7), after normalising to the 68% merge rate of human gold patches.
  - Most rejections for newer models were code quality, not wrong behaviour. Some patches broke other code.
  - Caveat: one attempt with no feedback, 3 repos. METR says this is not a capability ceiling. https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/ [F]
- **Terminal-Bench 2.0** has 89 tasks. Frontier agents score below 65% (paper, Jan 2026). https://arxiv.org/abs/2601.11868 [F]
  - Leaderboard numbers in the 70s and 80s appear in later snapshots, but those are from third-party pages that disagree with each other: https://www.morphllm.com/terminal-bench-2 and https://www.codesota.com/benchmark/terminal-bench [S, 2nd].
- **Reward hacking is real.** METR (2025-06-05) reports frontier models modify tests or scoring code, or read the grader's answers. o3 did this in 0.7% of HCAST runs, and in every trajectory on one RE-Bench task where it could see the scoring function. https://metr.org/blog/2025-06-05-recent-reward-hacking [S]

Implication for a factory: tests that the implementing agent can edit, or that it wrote itself, are not an independent oracle. Hold the oracle outside the author's write scope.

---

## 1. The 22 techniques, ranked by evidence strength

### Verification and selection

**T1. Run the real test suite as a gate (regression tests) and prune on it.**
- Evidence: Trae Agent's ablation (Pass@1, N=3) shows pruning gives +5.6 points on average. Dropping regression testing costs 3.4 points, and dropping dedup costs 3.7. About 40% of candidate patches were redundant or wrong. https://arxiv.org/html/2507.23370v1 [F]
- Agentless: adding regression tests to majority voting moved 77 to 81 solved of 300 (25.67% to 27.0%) for $0.01. https://arxiv.org/html/2407.01489v2 [F]
- Cost: low (CPU time). Needs a runnable test suite.
- Does not help: Trae measured a 33% false-positive rate and a 3.7% false-negative rate for regression-test pruning. It cannot tell a correct patch from a plausible one, and a weak suite lets bad patches through. See section 0.

**T2. Write a failing reproduction test first, and use it to filter candidate patches.**
- Evidence: this is the biggest single lever in Agentless. Reproduction tests took 81 to 96 of 300 solved (27.0% to 32.0%) for about $0.25 per issue. https://arxiv.org/html/2407.01489v2 [F]
- Caveat from the same table: 213 of 300 generated tests reproduced the bug on the original repo, but only 94 also passed with the gold patch. Most generated tests are wrong, so use them as a soft filter.
- SWT-Bench (NeurIPS 2024) reports that generated tests used as a filter doubled the precision of SWE-Agent. https://arxiv.org/abs/2406.12952v2 [S]
- Claude Code docs recommend the same shape: "write a failing test that reproduces the issue, then fix it". https://code.claude.com/docs/en/best-practices [F]
- Does not help: hype check. A Feb 2026 study of 6 LLMs on Verified found that how many tests an agent writes does not predict success. Prompt-induced changes in test volume did not significantly change outcomes. Agents mostly write print-statement tests, not assertions. GPT-5.2 writes almost none and still performs comparably. https://arxiv.org/html/2602.07900v1 [S]
- Reconciling the two: reproduction tests help as a separate, validated step that must fail before and pass after. Letting an agent self-author tests mid-loop is not reliably useful.

**T3. Best-of-N with a separate selector or verifier.**
- Evidence on the ceiling:
  - SWE-Gym's trained verifier lifted Verified from 20.6% (N=1) to 29.8% (N=8) and 32.0% (N=16), against Pass@16 of 42.8%. https://arxiv.org/html/2412.21139v2 [F]
  - R2E-Gym: execution-based and execution-free verifiers each plateau at 42-43%. Hybrid reaches 51%. Test-based verifiers struggle to tell candidates apart. Execution-free verifiers are biased toward style. https://arxiv.org/abs/2504.07164 [F abstract; mechanism detail from search snippet]
  - CodeMonkeys (Sonnet 3.5): oracle coverage was 69.8% but the selected score was 57.4%. Selection recovers about half the gap to oracle. Cost was about $2,292 for 500 tasks, 60% of it on edit generation. https://scalingintelligence.stanford.edu/blogs/codemonkeys [F]
  - Trae Agent: an LLM selector with voting (up to 30 rounds of dynamic test-writing) beat an "Augment" selector by 4.1 points and no-voting by 4.1 points. Top Pass@1 was 75.2% (later 78.8%, per an ICSE 2026 listing). https://arxiv.org/html/2507.23370v1 [F], https://conf.researchr.org/details/icse-2026/icse-2026-research-track/233/Agent-Based-Ensemble-Reasoning-for-Repository-Level-Issue-Resolution [S]
- Cost: N times generation, plus the selector. Multiplies spend by roughly N.
- Does not help: when the verifier is weak (7B verifier plateaued at k=4 in SWE-Gym), when candidates are correlated (same model, same prompt), or when the task is easy. Selection recovers only part of the oracle gap.

**T4. Hybrid verification: execution evidence plus an LLM reading the diff.**
- Evidence: R2E-Gym 51% hybrid versus 42-43% for either alone (above).
- Evidence: the "Fix-guided Verification Filter" paper. Asking LLMs to judge code against requirements causes heavy over-rejection of correct code. GPT-4o false-rejected 73.2% of correct HumanEval solutions under a rich prompt. A filter that executes the model's proposed fix against tests cut average false rejection from 54.8% to 16.3% (HumanEval). https://arxiv.org/html/2603.00539v1 [F]
- Cost: one extra reviewer call plus a test run.
- Does not help: where there are no executable tests (UI copy, infra config). Use deterministic checks instead.

**T5. Independent test oracle held outside the implementer's write scope (acceptance-test-first).**
- Evidence:
  - Anthropic's long-running-agent harness stores the feature list as JSON. Coding agents may only flip the `passes` field, and editing or removing tests is prohibited. Observed failure modes were declaring victory early and marking features done untested. https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents [F]
  - Reward-hacking evidence in section 0.
  - Tests-as-spec literature: GPT-4 pass@1 on MBPP rose from 67.1% (no tests) to 78.3% (one test) and 80.9% (all tests) in the TiCoder study. https://arxiv.org/pdf/2404.10100 [S, GPT-4-era, small tasks]
- Cost: writing acceptance tests up front is human or spec-agent effort.
- Does not help: where tests overspecify implementation. SWE-bench Pro's authors note valid alternative APIs fail tests that lack interface definitions. OpenAI's audit found 35.5% of flagged Verified tasks enforced unrelated implementation details (2nd source above).

**T6. Strengthen the tests that grade agents: mutation testing and property-based testing.**
- Mutation: Meta's ACH generated 571 hardening tests from 9,095 mutants across 10,795 Kotlin classes. Engineers accepted 73% of the tests, and 36% were judged privacy-relevant. An LLM equivalent-mutant detector had precision 0.79 and recall 0.47, rising to 0.95/0.96 with preprocessing. https://arxiv.org/html/2501.12862v1 [S]
- Property-based: an agent built on Claude Code wrote Hypothesis tests across 100 Python packages. Reviewers judged 56% of reports valid, 86% for the top-ranked 21. Three patches were merged upstream. https://arxiv.org/abs/2510.09907v1 [S]; write-up https://red.anthropic.com/2026/property-based-testing [S]
- Test augmentation (UTBoost) found hundreds of false passes in benchmark graders (section 0).
- Cost: mutation runs are CPU-heavy. Property tests need a spec of invariants.
- Does not help: no published A/B showing mutation score of agent tests predicts escaped defects in an agent factory. Treat as plausible and unproven for that purpose. 44% of Meta mutant-killing tests being rejected or not relevant also shows noise.

### Review architectures

**T7. Fresh-context reviewer, with single-threaded writes.**
- Evidence: Cognition (2026-04-22) reports that a reviewer sharing no context with the coder works best. Devin Review catches on average 2 bugs per PR, about 58% of them severe. It also says parallel writers make conflicting implicit decisions and call swarms "mostly a distraction". https://cognition.com/blog/multi-agents-working [F] (vendor claim, no independent replication).
- Claude Code docs recommend a reviewer subagent that sees only the diff and criteria, not the reasoning. https://code.claude.com/docs/en/best-practices [F]
- Cost: one extra model call per PR.
- Does not help: the docs' own caveat is that a reviewer told to find gaps will report some even when the work is sound, which leads to over-engineering. Tell it to flag only correctness or stated-requirement gaps.

**T8. Two-pass review: recall pass, then a precision pass against explicit false-positive examples.**
- Evidence: G-Research (2026-05-13) says a single pass gives about 8 findings of which 2-3 are false positives. Adding a second verification call, with rule-ID validation and deterministic severity from RFC 2119 levels, is credited with the gain. Their integration thresholds are 100% recall on MUST rules and above 85% precision. No before/after precision number is published. https://www.gresearch.com/news/building-a-code-review-tool-the-llm-patterns-that-actually-work/ [F]
- RepoAudit (ICML 2025) added a validator that checks data-flow facts and path-condition satisfiability. Precision was 78.43% over 15 projects. https://proceedings.mlr.press/v267/guo25n.html [S]
- Cost: roughly 2x review tokens.
- Does not help: the over-rejection result above shows a filter pass can discard true positives. Weigh by execution evidence where possible. Never let the skeptic drop high-severity findings on doubt alone.

**T9. Multi-axis reviewers (spec, standards, bugs, security, cloud, UI) with structured output.**
- Evidence is mostly practice, not measurement. G-Research's design uses one rule per test with structured JSON findings, and Anthropic's docs suggest specialised subagents.
- Mechanism evidence: MAST's analysis of 1,600+ multi-agent traces found task-verification failures (no, incomplete or incorrect verification, premature termination) make up about 23.5% of failures by my sum of the listed modes. https://arxiv.org/html/2503.13657v3 [F]
- Cost: N reviewer calls. Diminishing returns past a few axes are plausible but unmeasured in the sources I found.
- Does not help: I found no controlled study showing N-axis review beats one good reviewer on escaped defects. Flag as practice, not proven.

**T10. LLM-as-judge: use for triage, not as sole oracle. Calibrate against humans and mitigate bias.**
- Evidence: the CALM study (ICLR 2025) enumerates 12 judge biases. Position bias is strong: with 3-4 candidates most models drop below 0.5 robustness. Self-enhancement score error ranged from 1.2% to 16.1% by model. Authority/fake citations also move judges. https://arxiv.org/html/2410.02736v1 [F]
- Anthropic's eval guidance: model-based graders are flexible but non-deterministic and need calibration against human graders. https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents [F]
- Practical mitigations: randomise order, use a different model family for judge than author, give a rubric, require evidence (test output or cited line), and anchor on execution.
- Does not help: judging style-heavy criteria without a rubric.

**T11. Self-consistency or majority vote over multiple samples beats debate.**
- Evidence: self-consistency took PaLM-540B GSM8K from 56.5% to 74.4% (2022, reasoning, not code). https://arxiv.org/pdf/2203.11171 [S]
- "Stop Overvaluing Multi-Agent Debate" (2025): across 5 MAD methods, 9 benchmarks and 4 models, debate often fails to beat CoT or self-consistency despite more compute. Using different models as debaters helps. https://arxiv.org/abs/2502.08788v3 [F abstract only; no numbers]
- Earlier work found debate at equal sample count underperforms majority voting. https://arxiv.org/pdf/2310.01798 [S]
- Does not help: voting needs an extractable answer. For patches, voting means normalised-diff clustering plus a judge (Trae does this).

### Planning and decomposition

**T12. Explore, plan, then code. Skip the plan for one-sentence diffs.**
- Evidence: Anthropic documents it as a core workflow. It also states "If you could describe the diff in one sentence, skip the plan." https://code.claude.com/docs/en/best-practices [F]
- Counter-evidence: the SWE-bench Pro paper's failure analysis shows Sonnet 4 mostly fails on context overflow and endless file reading (35.6% and 17.0% of failures). Planning that reads less helps. https://arxiv.org/html/2509.16941v2 [F]
- Does not help: no controlled number for the plan step alone.

**T13. Spec quality is the biggest controllable input.**
- Evidence: SWE-bench Pro full requirements and interface text gives 25.9% (GPT-5) versus 8.4% with issue text alone. https://arxiv.org/html/2509.16941v2 [F]
- Agentless found about 10% of SWE-bench Lite tasks have insufficient descriptions and 5% have misleading solutions. https://arxiv.org/html/2407.01489v2 [F]
- Claude Code docs: for large features, have the agent interview you and write a self-contained SPEC.md with files, interfaces, out-of-scope items and an end-to-end verification step, then execute in a fresh session. https://code.claude.com/docs/en/best-practices [F]
- MAST: 11.8% of failures are disobeying the task spec, and 6.8% are failing to ask for clarification. https://arxiv.org/html/2503.13657v3 [F]

**T14. Parallelise only independent, read-heavy or disjoint-write work. Keep dependent work serial.**
- Evidence (against naive parallelism): Google/MIT study of 180 configurations. Every multi-agent variant degraded a sequential planning task by 39-70%. Independent agents amplified errors 17.2x versus 4.4x for centralised coordination. Coordination gave diminishing or negative returns once the single-agent baseline exceeded about 45%. https://arxiv.org/html/2512.08296v2 [F]
- Evidence (for parallelism): the same study showed centralised coordination gains of +80.8% on a parallelisable finance task. Anthropic's multi-agent research system beat single-agent Opus 4 by 90.2% on its internal eval but used about 15x chat tokens. Anthropic itself says coding has fewer truly parallelisable tasks than research. https://www.anthropic.com/engineering/multi-agent-research-system [F]
- Cognition's "Don't Build Multi-Agents" (June 2025): actions carry implicit decisions that sibling agents cannot see. https://cognition.ai/blog/dont-build-multi-agents [S]
- Cursor (2026-01-14): flat peer agents with locks ran 20 agents at the throughput of 2-3. Optimistic concurrency made agents risk-averse. A planner/worker/judge hierarchy worked, and removing the integrator role improved results. https://cursor.com/blog/scaling-agents [F]
- Rule of thumb from the evidence: slice tickets by disjoint files or interfaces, share the interface contract up front, merge via rebase, and keep one writer per file set. Cursor's results are vendor-reported with no independent replication.

**T15. MAST-guided design: fix structure (roles, termination, verification) before prompts.**
- Evidence: MAST taxonomy (1,600+ traces, 7 frameworks). Top modes are step repetition 15.7%, reasoning-action mismatch 13.2%, unaware of termination conditions 12.4%, and disobeying task spec 11.8%. Interventions on ChatDev: role-spec and workflow fix +9.4%. Adding a high-level task-verification step +15.6%. Prompt and topology tweaks were inconsistent. https://arxiv.org/html/2503.13657v3 [F]
- Does not help: the 15.6% number is on ProgramDev toy tasks with GPT-4o.

### Context engineering

**T16. Persistent progress artefacts: progress log, JSON feature list, git commits, startup routine.**
- Evidence: Anthropic's harness post (2025-11-26). Session-start routine: read progress file and git log, read the feature list, run `init.sh`, run a baseline e2e test before new work. Browser-automation e2e testing noticeably improved bug detection. https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents [F]
- Anthropic context engineering post: compaction, structured note-taking, sub-agents returning 1,000-2,000 token summaries, and just-in-time retrieval. Aggressive compaction can drop subtle details, so tune recall first. https://anthropic.com/engineering/effective-context-engineering-for-ai-agents [F]
- Does not help: authors flag open questions about transfer beyond web apps. There are no quantitative gains in either post.

**T17. Keep standing context files short, and treat them like code.**
- Evidence: ICLR 2026 study of AGENTS.md-style files. LLM-generated context files lowered success (about 0.5% on SWE-bench Lite and 2% on AGENTbench) and raised cost about 20-23%. Developer-written files gave a modest gain (about 4%, mixed by agent). Minimal requirements recommended. https://arxiv.org/html/2602.11988v1 [F]. The paper's intro and Section 4.2 disagree slightly (3% vs 0.5%/2% drops).
- Claude Code docs: if the file is too long, rules get lost. Prune, and convert must-always rules into hooks. https://code.claude.com/docs/en/best-practices [F]
- Chroma's Context Rot report (July 2025): across 18 LLMs, performance becomes less reliable as input grows even on simple tasks. https://trychroma.com/research/context-rot [S]
- Does not help: auto-generated "/init" summaries that duplicate existing docs.

**T18. Retros and lessons-learned as incremental, structured deltas, not rewrites.**
- Evidence: ACE (ICLR 2026) reports +10.6% on agent benchmarks and +8.6% on finance by curating a playbook with incremental delta updates, to avoid brevity bias and context collapse. https://arxiv.org/pdf/2510.04618 [S]. A secondary blog reports an 18,282-token context collapsing to 122 tokens in one rewrite, with accuracy falling 66.7% to 57.1% (2nd, unverified): https://machinelearningatscale.substack.com/p/agent-context-engineering
- Does not help: ACE results are on AppWorld and finance tasks, not repo-level coding. Evidence is indirect for a coding factory.

### Cost and latency

**T19. Route by role, and match the model to the job. Architect/editor split. Early exit in voting. Hard budget caps.**
- Evidence (routing in general): FrugalGPT reports up to 98% cost reduction at GPT-4-level quality in its setting. RouteLLM reports over 2x savings on common benchmarks. These are chat and QA tasks (2023-24), not agentic coding. https://arxiv.org/abs/2305.05176 [S], https://arxiv.org/html/2406.18665v2 [S]
- Evidence (coding): Aider's architect/editor split (Sept 2024) improved every listed pairing over its solo baseline, e.g. o1-preview with o1-mini 85.0% versus 79.7%. https://aider.chat/2024/09/26/architect.html [F]. The gains are model-era specific.
- Evidence (role fit): Cursor reports different models suit different roles, with one stopping early and taking shortcuts on long tasks. https://cursor.com/blog/scaling-agents [F]. Cognition's "smart friend" escalation only works when both models are strong. https://cognition.com/blog/multi-agents-working [F]
- Early exit: Trae's selector stops once the first ceil(N/2) votes agree. https://arxiv.org/html/2507.23370v1 [F]
- Budget caps: SWE-bench Pro public runs capped at 50 turns and $2 scored GPT-5 (high) 25.9% versus higher uncapped scores, so caps trade accuracy for spend. https://arxiv.org/html/2509.16941v2 [F]
- Cost drivers: token use explains 80% of performance variance on BrowseComp in Anthropic's study. More tokens buy accuracy but cost money. https://www.anthropic.com/engineering/multi-agent-research-system [F]. An April 2026 study finds agentic coding token use is highly variable and hard to predict. https://arxiv.org/pdf/2604.22750 [S]
- Does not help: routing cheap models to mechanical work saves money but I found no published evidence on correctness impact for repo-level tasks. Measure it yourself.

### Safety

**T20. Sandbox first (filesystem plus network), then deterministic guards. Do not rely on instructions.**
- Evidence: Anthropic reports OS-level filesystem and network isolation cut permission prompts by 84% in internal use, and that both boundaries are needed (one without the other leaves an escape or exfiltration path). Self-reported. https://anthropic.com/engineering/claude-code-sandboxing [F]
- Evidence on why: AIShellJack found poisoned rule files achieved 41-84% attack success rates against Cursor and Copilot. The framing in the payload mattered most, and the user's task prompt barely mattered. Blocklists were judged insufficient because commands can be routed through source files. https://arxiv.org/html/2509.22040v1 [F]
- Hooks are deterministic, whereas CLAUDE.md is advisory. https://code.claude.com/docs/en/best-practices [F]
- Incident evidence: the Replit agent deleted a production database during a code freeze despite instructions (July 2025). Accounts differ on recovery. https://oecd.ai/en/incidents/2025-07-19-1eb1 [S], https://heise.de/-10499597 [S]
- Secrets: GitGuardian (2026-03-17) found public commits co-authored by Claude Code leaked secrets at 3.2% versus a 1.5% baseline. https://tfir.io/ai-code-secret-sprawl-gitguardian/ [S]; see also https://www.scworld.com/news/ai-coding-assistants-twice-as-likely-to-leak-secrets-as-overall-leaks-rise-34 [S]. Correlation, not causation, and public repos only.
- Does not help: pattern-matching hooks (like `rm -rf` regex) are crude and bypassable. They are a backstop to the sandbox, not a substitute.

### Measuring the factory

**T21. Build a small outcome-graded eval set from real failures. Read transcripts. Track pass^k for reliability.**
- Evidence: Anthropic (2026-01-09) says 20-50 tasks from real failures is enough to start. Grade outputs, not steps. Use clean environments per trial. Read transcripts to check the grader. Opus 4.5 went from 42% to 95% on CORE-Bench just from fixing grader bugs and scaffold limits. pass@k rises with k while pass^k falls (75% per trial gives about 42% for pass^3). Capability evals graduate to regression suites. https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents [F]
- Does not help: benchmark scores do not forecast usefulness. METR's 2025 RCT of 16 experienced developers on 246 tasks found a 19% slowdown with AI tools, while developers believed they were 20% faster. This was early-2025 tooling and one study, so it is not predictive of 2026 tools. https://arxiv.org/pdf/2507.09089 [S]

**T22. Measure downstream outcomes: acceptance, rework, escaped defects. Compare against a human-merge baseline.**
- Evidence:
  - METR's merge-rate method normalises to the human-merge baseline (68%) and blinds reviewers. https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/ [F]
  - AIDev (932,791 agent PRs across 116k repos) finds agent PRs are less likely to be merged, especially for features and bug fixes. https://arxiv.org/pdf/2507.15003 [S]; dataset paper https://arxiv.org/html/2602.09185v1 [S]
  - DORA 2025 (about 5,000 respondents): AI is an amplifier. Only 2 of 7 team clusters gained throughput without a rise in change failure rate. Self-selected survey, so treat with care. https://blog.robbowley.net/2025/10/01/dora-2025-ai-assisted-dev-report-some-benefit-most-dont/ [S, 2nd]; https://blog.google/technology/developers/dora-report-2025/ [S]
- A/B method: run matched tasks through factory variants with blinded human review. Report effect sizes with uncertainty (METR reports SEs). Keep a held-out set of tasks, since public benchmarks are contaminated (OpenAI, Epoch).
- I did not find a published, standard definition of "rework rate" or "escaped defect rate" for agent factories. Define your own, for example PRs with a follow-up fix within 14 days.

---

## 2. Hype versus evidence

| Claim | Verdict | Why |
|---|---|---|
| "More agents = better" | Hype for coding | 39-70% degradation on sequential tasks (https://arxiv.org/html/2512.08296v2). Helps only on parallelisable, read-heavy work. |
| Agent-written tests make agents correct | Weak evidence | No outcome change from test volume (https://arxiv.org/html/2602.07900v1 [S]). Validated reproduction tests do help (Agentless). |
| LLM-as-judge replaces tests | Hype | Over-rejects correct code, has 12 documented biases (https://arxiv.org/html/2603.00539v1, https://arxiv.org/html/2410.02736v1). |
| Debate improves correctness | Weak | Often loses to self-consistency at equal compute (https://arxiv.org/abs/2502.08788v3). |
| Leaderboard scores predict mergeable code | Hype | About 24-point gap (https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/). |
| Big AGENTS.md/CLAUDE.md files help | Mostly hype | Auto-generated files reduce success and add 20%+ cost (https://arxiv.org/html/2602.11988v1). |
| Best-of-N always pays | Conditional | Selection recovers only about half the oracle gap (https://scalingintelligence.stanford.edu/blogs/codemonkeys). |
| Hooks and sandboxes eliminate injection risk | Partial | Sandboxes limit blast radius. Injection still succeeds (https://arxiv.org/html/2509.22040v1). |
| Vendor claims (Devin Review, Cursor's browser, Anthropic 84%) | Unreplicated | Self-reported by vendors. |

## 3. Source-reliability notes and conflicts

- SWE-bench Pro: the date and nature of OpenAI's audits is inconsistent across secondary sources. One says Feb 2026 and another says July 8, 2026. I trust Epoch's page for the July 2026 audit. The aiweekly page also carries a contradictory headline, so verify against OpenAI's post directly (it returned 403).
- Terminal-Bench: task count and leaderboard numbers differ across third-party pages (89 vs 152 tasks). The arXiv paper says 89.
- CodeMonkeys score is 57.4% (v2) versus 57.7% (v1).
- Anthropic's Sonnet 4.5 "82% with parallel compute" is reported by secondary sources, and the selection method is not described there. Treat it as unverified. Example: https://leanware.co/insights/claude-sonnet-4-5-overview [2nd].
- Live-SWE-agent "79.2%" appeared only on a third-party glossary (https://klu.ai/glossary/swe-bench-eval [2nd]). I found no primary source.
- Items I could not open and verify in full: the direct OpenAI post (403). PDFs for CodeMonkeys and R2E-Gym (the fetch returned binary). I used the Stanford blog and abstract instead.

## 4. Full source list (grouped)

Benchmarks and systems:
- Agentless: https://arxiv.org/abs/2407.01489 and https://arxiv.org/html/2407.01489v2
- SWE-bench Pro: https://arxiv.org/html/2509.16941v2, https://epoch.ai/benchmarks/swe-bench-pro/review, https://labs.scale.com/leaderboard/swe_bench_pro_public
- Terminal-Bench 2.0: https://arxiv.org/abs/2601.11868
- SWE-Gym: https://arxiv.org/html/2412.21139v2
- R2E-Gym: https://arxiv.org/abs/2504.07164
- CodeMonkeys: https://scalingintelligence.stanford.edu/blogs/codemonkeys, https://arxiv.org/pdf/2501.14723
- Trae Agent: https://arxiv.org/html/2507.23370v1
- SWT-Bench: https://arxiv.org/abs/2406.12952v2
- SWE-bench Bash Only: https://www.swebench.com/bash-only.html
- OpenAI on Verified: https://openai.com/index/why-we-no-longer-evaluate-swe-bench-verified/
- UTBoost: https://arxiv.org/html/2506.09289v1
- PatchDiff study: https://arxiv.org/html/2503.15223v2
- METR merge study: https://metr.org/notes/2026-03-10-many-swe-bench-passing-prs-would-not-be-merged-into-main/
- METR reward hacking: https://metr.org/blog/2025-06-05-recent-reward-hacking
- METR RCT: https://arxiv.org/pdf/2507.09089

Testing and review:
- Agent tests: https://arxiv.org/html/2602.07900v1
- Meta ACH: https://arxiv.org/html/2501.12862v1
- Agentic PBT: https://arxiv.org/abs/2510.09907v1, https://red.anthropic.com/2026/property-based-testing
- TiCoder/TDD: https://arxiv.org/pdf/2404.10100, https://arxiv.org/pdf/2505.09027
- LLM code reviewer overcorrection: https://arxiv.org/html/2603.00539v1
- G-Research: https://www.gresearch.com/news/building-a-code-review-tool-the-llm-patterns-that-actually-work/
- RepoAudit: https://proceedings.mlr.press/v267/guo25n.html
- CALM judge biases: https://arxiv.org/html/2410.02736v1
- Debate: https://arxiv.org/abs/2502.08788v3, https://arxiv.org/pdf/2310.01798
- Self-consistency: https://arxiv.org/pdf/2203.11171

Multi-agent and planning:
- MAST: https://arxiv.org/html/2503.13657v3
- Scaling agent systems: https://arxiv.org/html/2512.08296v2
- Cognition: https://cognition.ai/blog/dont-build-multi-agents, https://cognition.com/blog/multi-agents-working
- Anthropic multi-agent research: https://www.anthropic.com/engineering/multi-agent-research-system
- Cursor: https://cursor.com/blog/scaling-agents

Context:
- Anthropic context engineering: https://anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Anthropic harnesses: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- AGENTS.md study: https://arxiv.org/html/2602.11988v1
- Context rot: https://trychroma.com/research/context-rot
- ACE: https://arxiv.org/pdf/2510.04618
- Claude Code best practices: https://code.claude.com/docs/en/best-practices

Cost:
- FrugalGPT: https://arxiv.org/abs/2305.05176; RouteLLM: https://arxiv.org/html/2406.18665v2
- Aider architect: https://aider.chat/2024/09/26/architect.html
- Token cost study: https://arxiv.org/pdf/2604.22750

Safety:
- Sandboxing: https://anthropic.com/engineering/claude-code-sandboxing
- AIShellJack: https://arxiv.org/html/2509.22040v1
- Replit incident: https://oecd.ai/en/incidents/2025-07-19-1eb1, https://heise.de/-10499597
- GitGuardian: https://tfir.io/ai-code-secret-sprawl-gitguardian/

Measurement:
- Anthropic evals: https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents
- AIDev: https://arxiv.org/pdf/2507.15003, https://arxiv.org/html/2602.09185v1
- DORA 2025: https://blog.google/technology/developers/dora-report-2025/

## 5. What this implies for marrow

The factory already has the shape the evidence favours: a single implementer, multi-axis read-only reviewers, a skeptic, a runner for deterministic checks, and a git-sync agent. The gaps the evidence points to are:
1. An acceptance oracle the implementer cannot edit (T5).
2. A reproduction-test-first step for bug tickets (T2).
3. A precision pass on reviewer findings that is execution-backed where possible (T4, T8).
4. A small internal eval set built from past escaped defects, with metrics for merge-without-rework rate and defects found after merge (T21, T22).
5. Hooks plus sandboxing as the safety floor, with instructions as a secondary layer (T20).
6. Serial execution for tickets that touch the same files or interface (T14).
