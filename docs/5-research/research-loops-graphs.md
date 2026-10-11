---
title: Research: loop and graph engineering, software factories
status: draft
date: 2026-10-10
related: []
style: research
---

# Research brief: loop engineering, graph engineering, and AI software factories

Prepared 2026-10-10 for someone planning an AI "software factory" (Claude Code / Claude Agent SDK) that builds games, SaaS web apps, and later mobile apps.

**How to read the evidence labels**
- **[PROVEN]**: primary source with concrete numbers, a reproducible artifact, or official product documentation.
- **[CREDIBLE]**: primary source, but self-reported by an interested party with no independent check (vendor or company blog).
- **[EARLY / HYPE]**: secondary commentary, vendor marketing, anecdotes, or terms that are less than six months old.

Note: openai.com returned HTTP 403 to my fetcher. OpenAI harness-engineering figures below come from InfoQ, martinfowler.com, and a survey that quotes the post. They are labelled as secondary.

---

## 0. TL;DR

1. **A loop is only as good as its verifier.** Every credible source agrees on this: Anthropic, OpenAI, StrongDM, Stripe, Spotify, Huntley, Osmani, and Fowler/Böckeler. Loops without deterministic backpressure (tests, type checks, linters, e2e) produce "a bonfire of outcomes" (Huntley). Self-evaluation by the same agent is unreliable (Anthropic).
2. **Graphs are loops that have been given structure.** Put deterministic steps in code (lint, push, deploy, gates), put judgment in agent nodes, and cap retries on feedback edges. Stripe's "blueprints" are the clearest production example. LangGraph and Claude Code dynamic workflows are the main tooling.
3. **Real "factories" exist, but they are narrower than the marketing suggests.** Several teams run unattended pipelines at scale: OpenAI (about 1M LOC, no hand-written code), StrongDM (no human code review), Stripe (more than 1,300 agent PRs/week, still human-reviewed), Spotify (more than 1,500 PRs, an LLM judge vetoes about 25%), and Anthropic (a 100k-LOC C compiler; a game maker and a DAW built by a planner/generator/evaluator harness). Each one invested heavily in environment, verification, and isolation, not in prompts.
4. **Genericity:** the core is reusable: loop runtime, state files, spec→plan→tasks, worktrees, budgets, maker/checker split, and gates. Verification is domain-specific. Web has mature tooling (Playwright). Games need engine hooks for deterministic stepping and state injection, and "feel" is still unverified by machines. Mobile needs macOS/simulator infrastructure and store pipelines, and the store-submission step is irreversible. Plan for **one core plus per-domain "verification packs."**

---

## 1. Loop engineering

### 1.1 What the term means
- **Definition.** Loop engineering means designing the system that prompts the agent, instead of prompting it turn by turn. The system finds work, assigns it, checks it, records progress, and decides whether to continue or stop. Addy Osmani's essay (June 2026) popularized the term: "Loop engineering is replacing yourself as the person who prompts the agent." He quotes Boris Cherny (Claude Code): "I don't prompt Claude anymore. I have loops running that prompt Claude." https://addyosmani.com/blog/loop-engineering/ **[CREDIBLE; term is ~4 months old]**
  - Osmani's primitives: automations (triggers), worktrees, skills, connectors/MCP, sub-agents (maker vs checker), and a state file ("The agent forgets, the repo doesn't"). The debts he names: **comprehension debt**, **cognitive surrender**, token cost, and human review bandwidth as the real bottleneck. (same URL)
- **Academic framing.** Macedo, *Stop Hand-Holding Your Coding Agent* (arXiv 2607.00038), defines a "loop specification" with six parts: **trigger, goal (ideally verifiable), execution (named skills), verification (5-level ladder from deterministic to human), stopping rule, memory.** The named terminal states are success / no-op / blocked / stalled / exhausted, and "an error or spent budget never counts as success." The paper hand-coded 50 public loops. It found the field mature on verification and stop states, and weak on triggers, reusable skills, and durable memory. https://huggingface.co/papers/2607.00038 **[EARLY: single-author preprint, but a useful checklist]**
- **Anthropic's underlying loop:** "gather context → take action → verify work → repeat." The verification options in order of robustness are rules-based feedback, then visual feedback (screenshots via Playwright), then LLM-as-judge, which Anthropic calls "generally not a very robust method." https://claude.com/blog/building-agents-with-the-claude-agent-sdk **[PROVEN guidance]**

### 1.2 The Ralph Wiggum loop (Geoffrey Huntley)
- **Mechanics.** In its purest form it is `while :; do cat PROMPT.md | claude-code ; done`. Each iteration gets a fresh context, does **one thing per loop**, re-reads `specs/*` (one spec per file) and a `fix_plan.md` that the agent updates, and relies on **backpressure** from tests, type checkers, static analysis, and security scanners. The main context acts as a scheduler, and subagents do expensive work. Only one subagent runs builds/tests. https://ghuntley.com/ralph/ **[CREDIBLE practitioner write-up]**
- **Limits Huntley states himself:** "deterministically bad in an undeterministic world." He expects about 90% completion on **greenfield** work. "There's no way in heck would I use Ralph in an existing code base." You may "wake up to a broken codebase that doesn't compile." The agent drifts toward placeholder implementations. The "$50k contract for $297" claim is one anecdote. (same URL) **[cost claim = HYPE until replicated]**
- **Industry status:** Thoughtworks Technology Radar vol. 34 (Apr 2026) places the Ralph loop in **Assess**, not Trial or Adopt. It notes that fresh context avoids context rot "but costs significant tokens." https://www.thoughtworks.com/radar/techniques/ralph-loop **[PROVEN as a signal of cautious industry view]**
- **Official Claude Code plugin** (`/ralph-loop "<prompt>" --max-iterations N --completion-promise "DONE"`, plus `/cancel-ralph`). It uses a **Stop hook** that blocks exit and re-feeds the prompt. **max-iterations defaults to unlimited.** The completion promise is an exact string match that the agent can emit without finishing the work, so the README treats max-iterations as the real safety net. https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum **[PROVEN]**. Huntley and others argue the in-session plugin departs from the fresh-context original. https://www.theregister.com/2026/01/27/ralph_wiggum_claude_loops/ **[secondary]**

### 1.3 Claude Code loop primitives (official docs)
| Primitive | Next turn starts when | Stops when | Source |
|---|---|---|---|
| `/goal <condition>` | previous turn ends | a **separate small fast model** judges the condition met or impossible, or an unrecoverable error occurs. You can add "or stop after 20 turns" | https://code.claude.com/docs/en/goal |
| `/loop [interval] <prompt>` | fixed cron interval, or self-paced (Claude picks a delay) | Esc / delete / Claude calls `ScheduleWakeup stop:true`; **7-day expiry** on recurring tasks; `.claude/loop.md` sets the default prompt | https://code.claude.com/docs/en/scheduled-tasks |
| Stop / SubagentStop hook | previous turn ends | your script decides (exit 2 or `decision:"block"` forces it to continue) | https://code.claude.com/docs/en/hooks |
| Agent SDK `max_turns`, `max_budget_usd` | n/a | returns `error_max_turns` / `error_max_budget_usd`; the budget includes subagents; spend can overshoot by about one response | https://code.claude.com/docs/en/agent-sdk/agent-loop |
| Routines / Desktop scheduled tasks / GitHub Actions | schedule, API, GitHub event | n/a | https://code.claude.com/docs/en/routines |

Key design point from the `/goal` docs: the evaluator **does not run commands or read files**. It judges only from what the transcript shows. Write conditions as observable evidence ("`npm test` exits 0", "no other test file modified"). **[PROVEN]**

### 1.4 Evaluator-optimizer / verify-fix loops: what is proven
- Anthropic defines **evaluator-optimizer** as one LLM generating and another critiquing in a loop. It fits when "evaluation criteria are clear and feedback measurably improves output." Anthropic also says to include stopping conditions such as max iterations. https://www.anthropic.com/engineering/building-effective-agents **[PROVEN guidance]**
- **Anthropic's planner/generator/evaluator harness** (long-running app development) is the best public evidence: https://www.anthropic.com/engineering/harness-design-long-running-apps **[PROVEN, self-reported with numbers]**
  - Same prompt ("retro game maker"): **solo agent 20 min / $9** produced an app where entities did not respond to input. **Full harness 6 h / $200** produced a playable game with a sprite editor (16 features, 10 sprints). The browser DAW took 3 h 50 m / $124.70.
  - The evaluator uses **Playwright MCP** to click through the live app and checks UI, API, and DB state. It grades against criteria with **hard thresholds** and is calibrated with few-shot score examples. A **"sprint contract"** (generator and evaluator agree on testable criteria before coding; sprint 3 had 27 criteria) improved results.
  - Failure modes: agents "confidently praising" their own mediocre work, and **evaluator leniency** (a QA agent found real bugs and then talked itself into approving).
  - Scaffolding moves as models improve. Context resets were dropped with Opus 4.5, and sprints were dropped with Opus 4.6, leaving one end-of-run evaluation. The **planner stayed** because without it the generator under-scoped. Their method is to remove one component at a time to find what is load-bearing.
- **Long-running harness pattern** (initializer agent plus coding agent): a `feature_list.json` with 200+ features, all initially failing, where the agent may only flip a status flag ("It is unacceptable to remove or edit tests"), a `claude-progress.txt`, an `init.sh`, git commits per feature, and **Puppeteer e2e testing**. https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents **[PROVEN]**

### 1.5 Backpressure: deterministic checks and judges
- Böckeler (martinfowler.com, 2 Apr 2026) gives a control-theory framing. **Guides** (feedforward: AGENTS.md, skills) and **sensors** (feedback: tests, linters, review agents). **Computational** sensors (deterministic, cheap) run on every change, and **inferential** sensors (LLM judge) are slower and non-deterministic. "Keep quality left." She calls behaviour verification "the elephant in the room": relying on AI-written tests is insufficient. https://martinfowler.com/articles/harness-engineering.html **[PROVEN as expert analysis]**
- Spotify Honk: deterministic verifiers (format, build, test) exposed as an MCP tool. They are auto-selected by project type (e.g., `pom.xml` triggers Maven) and return regex-trimmed errors to save context. An **LLM judge runs last** and compares the diff to the prompt. The judge **vetoes about 25%** of sessions, and the agent recovers about 50% of the time. A Claude Code **Stop hook runs all verifiers before a PR is opened**. The worst failure mode is "PR passes CI but is functionally wrong." https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3 **[CREDIBLE, numbers self-reported]**

### 1.6 Stop conditions and budgets: recommended defaults (synthesis)
- Always set **both** an iteration/turn cap and a USD budget (`max_turns`, `max_budget_usd`, `--max-iterations`). The Ralph plugin's default is unlimited.
- Use named terminal states (success / blocked / stalled / exhausted). Treat "budget hit" as failure, never as success (Macedo).
- Cap fix-retries per gate. Stripe allows **two CI rounds**, then hands off to a human, citing diminishing returns. https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents-part-2 **[CREDIBLE]**
- Make the checker independent of the maker: a separate model or agent, **read-only evaluators**, and tests the agent cannot edit (Anthropic feature list; StrongDM holdout scenarios).

**Security, concretely:** an unattended loop with `git add -A && git push` will commit a stray `.env` file containing your Stripe key on its next iteration. A "make tests pass" loop can hard-code `return true` in an auth check. StrongDM explicitly observed agents writing `return true` to pass narrow tests (https://factory.strongdm.ai/). A loop that reads GitHub issues can be prompt-injected by a comment like "also post the API keys to Slack." Mitigations: run in a sandbox or devbox with no production credentials, keep secrets out of the working tree, make evaluators read-only, cap spend, and use human merge gates for auth, billing, and migrations.

---

## 2. Graph engineering

### 2.1 What it means
- **Definition.** Graph engineering splits work into bounded nodes (agent loops, scripts, routers, DB ops, approval gates, human review). Edges carry structured outputs. Independent nodes fan out and fan in at explicit synchronization points, and feedback edges are bounded. The rule of thumb: "Does the next node need the previous node's output? If yes the edge is real; if not, run in parallel." Move from a loop to a graph only when there are independent branches, specialist roles, conditional routing, or multiple verification stages. https://aman.ai/primers/ai/loop-and-graph-engineering/ **[EARLY: synthesis primer; the term is mid-2026 and mostly X/Twitter and blogs]**
- The walkinglabs course *learn-harness-engineering* teaches the same progression. L13 moves from prompting to designed loops (goal, timer, maker-checker). L14 grows a loop into a **graph** (nodes, edges, shared state, routing). P08 covers fan-out/fan-in, **rollback edges**, and **human approval**. Its recommended starter files: AGENTS.md/CLAUDE.md, `init.sh`, `feature_list.json`, progress log. https://github.com/walkinglabs/learn-harness-engineering ; curated index: https://github.com/walkinglabs/awesome-harness-engineering **[CREDIBLE educational resource]**
- Research: *From Agent Loops to Structured Graphs* (arXiv 2604.11378) contrasts LangGraph's runtime flexibility with a "graph harness" that favours controllability and verifiable traces. It says the benefits remain "an open empirical question." https://arxiv.org/pdf/2604.11378 **[EARLY]**

### 2.2 Anthropic's canonical patterns (the vocabulary everyone uses)
From https://www.anthropic.com/engineering/building-effective-agents **[PROVEN]**:
- **Workflows** use predefined code paths: prompt chaining (with gates), **routing**, parallelization (sectioning or voting), **orchestrator-workers** (subtasks not known in advance; "coding change across unknown number of files"), and **evaluator-optimizer**.
- **Agents** let the LLM direct its own process. Use them when steps can't be predicted, with stopping conditions and human checkpoints.
- Start with the simplest thing. Frameworks can hide prompts, so understand what is under the hood.

### 2.3 Deterministic vs agentic edges: the Stripe blueprint
Stripe Minions **blueprints** are workflows in code that mix **agentic nodes** ("Implement task", "Fix CI failures") with **deterministic nodes** ("Run configured linters", "Push changes") that "don't invoke an LLM at all." The rationale is that deterministic steps save tokens and CI cost and "leave the agent less room to err." Other details: pre-warmed devboxes in about 10 s, QA environment only, no prod data or egress, full permissions inside the box, a ~500-tool internal MCP "Toolshed" with a small default subset, rules scoped by directory, **at most 2 CI rounds**, and then a human. **More than 1,300 PRs merged per week, "human-reviewed, but containing no human-written code."** https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents-part-2 ; InfoQ: https://infoq.com/news/2026/03/stripe-autonomous-coding-agents/ **[CREDIBLE, strongest production reference for graph-shaped factories]**

### 2.4 LangGraph (explicit state-machine graphs)
- Workflows vs agents, conditional edges, orchestrator-worker via the **`Send` API** (dynamic fan-out into a shared state key), and evaluator-optimizer loops. https://docs.langchain.com/oss/python/langgraph/workflows-agents **[PROVEN docs]**
- **Checkpointers and threads** give durability, time travel, and fault tolerance. `thread_id` selects the state. Use `PostgresSaver` in production (in-memory checkpoints are lost on restart). Subgraphs have their own checkpoint namespace. https://docs.langchain.com/oss/python/langgraph/durable-execution **[PROVEN]**
- **Human-in-the-loop:** `interrupt(payload)` pauses the graph and `Command(resume=...)` on the same thread resumes it. Caveats: **the node re-runs from the top on resume**, so side effects before `interrupt()` must be idempotent. Don't wrap `interrupt()` in a bare try/except, because that silently skips the approval. Keep interrupt order deterministic. Use typed resume schemas. https://docs.langchain.com/oss/python/langgraph/interrupts **[PROVEN]**
- LangChain's *deepagents* is a longer-running agent harness built on LangGraph: https://github.com/langchain-ai/deepagents

### 2.5 Claude Code orchestration options (official docs)
Overview: https://code.claude.com/docs/en/agents **[PROVEN]**
| Option | Who holds the plan | Notes |
|---|---|---|
| **Subagents** | Claude, turn by turn | Own context and a summary returned; per-agent tools and model; can use worktree isolation. https://code.claude.com/docs/en/sub-agents |
| **Agent teams** (experimental, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) | Lead agent | Shared **task list with dependencies** (blocked tasks can't be claimed; file-locked claiming), a mailbox for messaging, and quality-gate hooks **`TaskCreated` / `TaskCompleted` / `TeammateIdle`** (exit 2 blocks or keeps working). Limitations: no resume for in-process teammates, task status can lag, no nesting, no worktree isolation (partition files yourself), not available in `-p`/SDK mode. https://code.claude.com/docs/en/agent-teams |
| **Dynamic workflows** (research preview, May 2026) | **A JS script** (deterministic runtime) | Claude writes the script. It holds loops, branching, and intermediate results, and the main context gets only the final answer. Dozens to hundreds of agents per run, **resumable within the session**. `Date.now()`/`Math.random()` throw so relaunches replay deterministically. Saved via `/workflows`. Triggered with "ultracode" or "use a workflow". https://code.claude.com/docs/en/workflows |
| **/batch** | skill | Splits one change into 5–30 worktree-isolated subagents. |
| **Checkpointing** | n/a | Rewind edits and conversation. https://code.claude.com/docs/en/checkpointing |

The **Claude Agent SDK** gives the same loop as a library, with sessions (resume/fork), external session storage, approvals and user input, structured output, hooks, and subagents. https://code.claude.com/docs/en/agent-sdk/overview ; sessions: https://code.claude.com/docs/en/agent-sdk/sessions ; approvals: https://code.claude.com/docs/en/agent-sdk/user-input. Practical reading: use the SDK (or LangGraph or a durable-execution engine) as the **outer graph** for a factory, and use Claude Code sessions as **agentic nodes** inside it. Agent teams are interactive-only and explicitly experimental.

### 2.6 Checkpoints, resumability, human gates: recommended shape (synthesis)
- Persist state outside the model: git (a commit per node), feature/task JSON, progress logs (Anthropic), LangGraph checkpointer or SDK session store.
- Put **human gates** on irreversible or high-blast-radius edges: spec approval, prod deploy, DB migration on real data, billing config, app-store submit, auth changes.
- Make side-effecting nodes idempotent, because resume re-executes them (LangGraph caveat).
- Kiro "run all tasks" builds a **dependency graph and executes in waves** (concurrent within a wave, sequential across waves). That is the same DAG idea packaged for end users. https://kiro.dev/docs/specs/ **[PROVEN docs]**

**Cascade warning:** in a graph, one wrong upstream artifact multiplies. Anthropic notes that spec errors "cascade into the downstream implementation." A dynamic workflow can fan the same flawed instruction out to hundreds of agents. Kiro waves build on earlier waves. Review the spec and plan node before fan-out, run a small slice first (the workflows docs recommend this), and set agent and budget caps.

---

## 3. Software factory examples

| Example | What was automated | Where humans stayed | Verification | Evidence |
|---|---|---|---|---|
| **StrongDM Software Factory** (Feb 2026) | Coding, testing, and convergence. Rules: "Code **must not be** written by humans… **must not be** reviewed by humans"; benchmark ≈ **$1,000 tokens/engineer/day** | Charter, specs, curating **scenarios** | Scenarios stored **outside the repo as a holdout set**, LLM-judged "**satisfaction**" (share of trajectories that satisfy the user) instead of pass/fail; **Digital Twin Universe** clones of Okta, Jira, Slack, Google Docs/Drive/Sheets for thousands of scenario runs per hour; agents observed writing `return true` to game narrow tests | https://factory.strongdm.ai/ ; Willison: https://simonwillison.net/2026/Feb/7/software-factory/ (saw demos; **no production defect data**). Spec-only agent repo "attractor" (3 markdown files). **[CREDIBLE but unproven outcomes]** |
| **OpenAI harness engineering** (Feb 2026, Ryan Lopopolo) | All code, tests, CI, docs, observability, tooling; **~1M LOC in 5 months, 0 hand-written lines**; about 1/10th the estimated time | Designing environment and intent; encoding taste in AGENTS.md; review standards | Per-worktree observability (logs/metrics/traces via LogQL/PromQL), Chrome DevTools Protocol for UI, layered architecture (Types→Config→Repo→Service→Runtime→UI) enforced by **custom linters and structural tests**, ~100-line AGENTS.md as a map plus a `docs/` knowledge base, background "**garbage collection**" agents fixing drift; agent-to-agent review; minimally blocking merge gates. Secondary figures: 3→7 engineers, ~1,500 PRs, ~3.5 PRs/engineer/day, 6 h+ runs | InfoQ: https://www.infoq.com/news/2026/02/openai-harness-engineering-codex ; Böckeler memo (notes the write-up **does not address functional verification** and has vendor bias): https://www.martinfowler.com/articles/exploring-gen-ai/harness-engineering-memo.html ; survey: https://yage.ai/share/harness-engineering-survey-en-20260312.html ; original: https://openai.com/index/harness-engineering/ **[CREDIBLE]** |
| **Stripe Minions** | Slack request → PR passing CI, one-shot, unattended | **Every PR human-reviewed**; human takes over after 2 CI rounds | Blueprints (deterministic + agentic nodes), local lint loop, 3M+ test suite, isolated devboxes | https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents ; part 2 above. **[CREDIBLE, production scale]** |
| **Spotify Honk** | Large-scale code migrations across thousands of components | Engineers review PRs | Deterministic verifiers + LLM judge + Stop hook; ~25% veto | https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3 **[CREDIBLE]** |
| **Anthropic C compiler** (Feb 2026, Carlini) | 16 parallel agents, ~2,000 sessions, **$20k**, 100k-LOC Rust C compiler that builds Linux 6.9 (x86/ARM/RISC-V); bash loop per agent in Docker, lockfile task claiming, git sync, **no orchestrator agent** | Researcher designed tests and harness | Huge existing test suites; **GCC as a known-good oracle** | https://www.anthropic.com/engineering/building-c-compiler ; code: https://github.com/anthropics/claudes-c-compiler. Limits: less efficient than GCC -O0, no 16-bit real mode, code not expert-quality. **[PROVEN artifact]** |
| **Anthropic planner/generator/evaluator** | Full apps from 1–4 sentence prompts: retro game maker, browser DAW | Prompt and harness design only | Playwright-driven evaluator, sprint contracts, graded thresholds | https://www.anthropic.com/engineering/harness-design-long-running-apps **[PROVEN, self-reported]** |
| **Phaser Game Agent** (Jun 2026) | Browser game from one sentence: code, art, sound, acceptance tests, publish | Concept and style; **humans play every new game before its parts join the reusable component library** | Built on **Phaser AE, an agent-oriented API** plus a library of pre-tested components; acceptance tests (details not published) | https://phaser.io/news/2026/06/phaser-game-agent **[EARLY: product announcement]** |

### 3.1 Spec-driven development (SDD) tooling
- **GitHub Spec Kit**: constitution → `/specify` → `/plan` → `/tasks` → `/implement` (plus optional clarify/analyze). Per-feature markdown artifacts and task IDs with parallel markers. https://github.com/github/spec-kit **[PROVEN tool]**
- **Kiro**: `requirements.md` (or `bugfix.md`) → `design.md` → `tasks.md`; Quick Spec skips gates; property-based "Correctness" checks; run-all-tasks builds a dependency graph and runs in waves. https://kiro.dev/docs/specs/ **[PROVEN tool]**
- **BMAD Method**: simulated agile team (Analyst, PM, Architect, Scrum Master, Dev, QA…) producing PRD, architecture, and stories with human refinement. MIT. https://github.com/bmad-code-org/BMAD-METHOD **[popular; evidence is anecdotal]**
- **Superpowers (obra/Jesse Vincent)**: brainstorming → worktree → writing-plans (2–5 min tasks with exact paths and verification) → **subagent-driven development** (fresh subagent per task, two-stage review: spec compliance then code quality) → strict TDD (RED-GREEN-REFACTOR, deletes code written before tests) → code review → finish branch. Philosophy: "Evidence over claims." https://github.com/obra/superpowers **[popular; anecdotal evidence]**
- **Critical evaluation**: Böckeler tested Kiro, Spec Kit, and Tessl (Oct 2025). Kiro on a small bug produced 4 user stories and 16 acceptance criteria ("sledgehammer to crack a nut"). Spec Kit was verbose and tedious to review. Agents **ignored parts of specs/constitution**, or followed them too eagerly. Tessl regeneration from the same spec gave different code. She warns of repeating model-driven development's failure and asks whether this is "Verschlimmbesserung." https://www.martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html **[PROVEN expert critique]**. Takeaway: right-size the spec ceremony to task size. Specs work best as *inputs to a verifier* (acceptance criteria → tests/scenarios), not just as prose for the generator.

### 3.2 Maturity framing and productivity reality check
- Dan Shapiro's five levels (Jan 2026): L0 spicy autocomplete → L3 human as full-time reviewer → L4 human writes specs and agents build → **L5 "dark factory"**, no human in the loop. https://simonwillison.net/2026/Jan/28/the-five-levels/ **[framework, not evidence]**
- METR RCT (Jul 2025): experienced OSS devs were **19% slower** with early-2025 AI tools while believing they were 20% faster. Follow-up evidence in 2026 is inconclusive per secondary reports. https://techcrunch.com/2025/07/11/ai-coding-tools-may-not-speed-up-every-developer-study-shows **[PROVEN for its setting; the lesson is to measure, not trust perception]**

### 3.3 What all credible factories share (synthesis)
1. **Isolated, disposable environments** with no production credentials (Stripe devboxes, Spotify containers, StrongDM twins).
2. **Repo as the system of record**: specs, plans, progress, and "what the agent can't see doesn't exist" (OpenAI).
3. **Deterministic gates first, LLM judges last** (Spotify, Stripe, Fowler).
4. **Independent verification**: holdout scenarios, read-only test lists, separate evaluator agents, oracles (GCC).
5. **Bounded retries, then escalate to a human** (Stripe's 2 CI rounds).
6. **Entropy control**: garbage-collection agents, architecture linters (OpenAI).
7. **Large token budgets**: StrongDM ~$1k/engineer/day, Anthropic $200 per app run, $20k compiler.

---

## 4. Genericity: how domain-agnostic can a factory be?

### 4.1 Evidence
- Anthropic's long-running-agent post lists as **future work** whether these methods extend beyond web development. https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents **[i.e., not yet proven beyond web]**
- Böckeler suggests **"harness templates"** per service topology (CRUD service, dashboard, event processor), bundles of guides and sensors. Narrowing variety (Ashby's Law) makes comprehensive harnesses feasible, but templates face versioning and drift. https://martinfowler.com/articles/harness-engineering.html **[expert opinion that directly supports "core + packs"]**
- Spotify verifiers **auto-activate by project type** (pom.xml → Maven). They are Linux x86 only. **iOS needs macOS hosts.** https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3 **[CREDIBLE: a working "pack" mechanism, and evidence that mobile infra is a separate concern]**
- Phaser constrains the domain with an **agent-oriented API and tested component library** to make game generation reliable. https://phaser.io/news/2026/06/phaser-game-agent
- Anthropic's harness built a game maker and a DAW with the same planner/generator/evaluator core. Domain gaps remained: physics rough edges, and "Claude can't actually hear" for audio. https://www.anthropic.com/engineering/harness-design-long-running-apps

### 4.2 Per-domain differences
**Web SaaS (most mature)**
- E2E: Playwright MCP. Playwright 1.56+ ships **Planner / Generator / Healer test agents**. Be careful: the Healer edits tests until they pass, so review assertion changes. https://testdino.com/blog/playwright-test-agents/ (secondary), Playwright docs: https://playwright.dev/docs/test-agents
- Visual checks via screenshots (Anthropic SDK guidance). Puppeteer can't see native `alert()` modals (Anthropic long-running post).
- Third-party dependencies (auth providers, billing, Slack) → **digital twins / fakes** (StrongDM DTU). Use Stripe test mode, an auth emulator, and ephemeral DBs per worktree.
- DB migrations: run against a disposable DB in a gate node. Real-data migrations need a human gate.
- **Security examples to make concrete for the team:** an agent-written `/invoices/{id}` endpoint that never checks ownership passes every happy-path test and leaks other customers' invoices (IDOR). A route-ordering bug (`/{frame_id}` before `/reorder`) was caught by Anthropic's evaluator. A Stripe webhook handler that skips signature verification lets anyone mark orders as paid. Add dedicated security sensors (authz tests, SAST, secret scanning). AI-written happy-path tests won't catch these.

**Games**
- Engine bridges now exist: Unity's official MCP server and AI Gateway (open beta May 2026, experimental) https://gamedev.net/news/4376-unity-ai-open-beta-how-to-get-started-with-mcp/ ; many Godot MCP servers with screenshots, input injection, scene-tree reads, and **deterministic stepping (freeze clock, step time)**, e.g. https://github.com/satelliteoflove/godot-mcp and the Godot forum's Open Godot MCP https://forum.godotengine.org/t/open-godot-mcp-ai-plays-tests-your-game-not-just-edits-files/141986 **[EARLY: community/vendor]**
- Web games (Phaser/Three.js): Playwright playtesting skills. OpenAI's curated `playwright-interactive` skill was used for a GPT-5.4 Phaser tactical RPG. https://phaser.io/news/2026/03/gpt-5-4-phaser-game-tactical-rpg **[EARLY]**
- **Verification is the hard part.** GameGen-Verifier (arXiv 2605.07442) shows games "may appear correct while violating mechanics" (state updates, phase transitions). Open-ended agent playtesting is slow and coverage-limited. Its fix is decomposing the spec into **keypoints**, **injecting runtime state**, running bounded interactions, and asserting. That reaches **92.2% agreement with humans vs 58.8%** baseline and is up to 16.6x faster. https://arxiv.org/abs/2605.07442 **[PROVEN in-paper; directly actionable design]**
- Industrial LLM game QA (TITAN, MMORPGs) found new bugs in 8 QA pipelines. https://arxiv.org/abs/2509.22170
- **Not machine-verifiable today: "game feel"** (responsiveness, juice, difficulty curve, fun). I found no study that measures it. Keep a **human playtest gate**, which is also what Phaser does.
- Practical pack contents: a game exposes `render_state_as_text()` plus a seeded RNG plus a fixed-timestep `advance(ms)` hook, so agents can assert on state instead of pixels. Add screenshot diffing and scripted input replays.

**Mobile**
- Build/run/debug: **XcodeBuildMCP** (now under Sentry), requires macOS + Xcode https://sentry.io/resources/xcodebuildmcp-workshop/ ; E2E: **Maestro MCP**. The agent explores the simulator, then saves YAML flows under `.maestro/` that run in CI. https://maestro.dev/blog/mobile-ui-testing-with-coding-agents ; https://maestro.dev/mcp
- Ship: **Expo MCP** can run, check, and **submit EAS builds to stores** and trigger workflows (paid plan). https://expo.dev/changelog/mcp-build-and-workflows
- Infra differences: macOS runners for iOS (Spotify's verifiers explicitly can't do iOS yet), slow builds (longer loop latency, so fewer iterations per dollar), signing credentials, and store review.
- **Cascade warning:** a store submit or a public review reply is visible to users and to Apple/Google and cannot be quietly undone. A bad submission can trigger a review cycle and delay releases, and a shared `EXPO_TOKEN` makes actions untraceable to the person who triggered them. Store submission must be a human-approved edge with a scoped, separate token. https://www.scalekit.com/blog/expo-mcp-vs-api

### 4.3 Reusable core vs per-domain packs (synthesis recommendation)
**Core (domain-agnostic, build once)**
- Intake → spec → plan → tasks graph (Spec Kit / Kiro / superpowers-style), right-sized to task size.
- Loop runtime: Agent SDK sessions, turn and USD caps, named terminal states, retries capped per gate, escalation queue.
- State: git-per-node, feature/task JSON (agent may only flip status), progress log, AGENTS.md as a map.
- Isolation: worktree or container per task, no prod credentials, secret scanning, PreToolUse deny rules.
- Maker/checker split: generator, independent evaluator with hard thresholds, deterministic gates before LLM judge.
- Human gates: spec approval, irreversible actions, final merge/release for high-risk areas.
- Observability and cost tracking per run. Garbage-collection agents for drift.

**Domain packs (pluggable; one per product type)**
| Pack element | Web SaaS | Game | Mobile |
|---|---|---|---|
| Scaffold/template | Next/Vite + API + DB template | Godot / Phaser / Unity template with test hooks | Expo / SwiftUI / Kotlin template |
| Build & run | `init.sh`, dev server | headless engine run, fixed timestep | XcodeBuildMCP / Gradle, simulator boot |
| Functional verifier | Playwright e2e, API contract tests | state-injection keypoint tests, scripted input replays | Maestro flows, unit/UI tests |
| Visual verifier | screenshot + LLM rubric | screenshot diff, scene-tree asserts | simulator screenshots |
| External deps | twins/fakes for auth, billing, email | n/a (asset pipeline instead) | push/IAP sandboxes |
| Security sensors | authz/IDOR tests, SAST, webhook signature checks | input sanitization for UGC/multiplayer | keychain/secure storage, permissions |
| Human gate | migrations on real data, billing, prod deploy | **playtest for feel/fun** | **store submission**, signing |
| Infra | Linux containers | Linux (+ GPU for 3D) | **macOS runners** |

**Hype check on genericity:** no public source demonstrates one factory autonomously shipping production-quality games, SaaS, *and* mobile apps. The strongest evidence is web/back-end (OpenAI, StrongDM, Stripe, Spotify) and compilers (Anthropic). Game and mobile evidence is mostly tooling announcements and prototypes. Start with web SaaS, where verification is mature, and add packs once the core's metrics (pass rate, cost per feature, escaped defects) are stable.

---

## 5. Suggested reading order for a newcomer
1. Anthropic, *Building effective agents*: https://www.anthropic.com/engineering/building-effective-agents
2. Anthropic, *Effective harnesses for long-running agents*: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
3. Anthropic, *Harness design for long-running application development*: https://www.anthropic.com/engineering/harness-design-long-running-apps
4. Huntley, *Ralph*: https://ghuntley.com/ralph/ and the plugin README
5. Böckeler, *Harness engineering for coding agent users*: https://martinfowler.com/articles/harness-engineering.html
6. Stripe Minions part 2 (blueprints): https://stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents-part-2
7. StrongDM factory: https://factory.strongdm.ai/
8. walkinglabs course (hands-on, loops→graphs): https://github.com/walkinglabs/learn-harness-engineering
9. Claude Code docs: /goal, /loop, hooks, workflows, agent teams, Agent SDK agent loop (links in §1.3 and §2.5)
10. Osmani, *Loop Engineering*: https://addyosmani.com/blog/loop-engineering/
