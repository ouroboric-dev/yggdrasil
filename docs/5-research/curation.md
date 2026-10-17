---
title: Curated open-source learning sources
status: draft
date: 2026-10-11
related: []
style: research
---

# Yggdrasil learning sources: curated list

> Accessed 2026-10-11. Stars, push dates, licences and archive flags come from the GitHub REST API (`gh api repos/<owner>/<repo>`) on that day. "Pushed" is the last push to any branch. "Rel" is the latest GitHub release, where one exists. Repos that moved show their new home; GitHub redirects the old URL. Items marked **[ANALYSIS]** are the author's judgement, recommendations or inferences, not sourced facts.
>
> **A note on stars [ANALYSIS].** In 2026, star counts for agent tooling are inflated and tell you little about quality. `obra/superpowers` has about 297k, `mattpocock/skills` about 285k, and `Graphify-Labs/graphify` gained about 125k in six months. Use stars to judge reach. To judge substance, look at code, tests and evals, release cadence and issue hygiene. Treat any README claim like "120x fewer tokens" as marketing until you can reproduce it.

Yggdrasil layer key: **Odin** (graph engine), **Gleipnir** (harness: adapters, sandbox, policies, checks), **Jormungandr** (build→check→fix loop with caps), **Gates** (approval gates and autonomy modes), **Tree** (umbrella/leaf submodule tree and routing indexes), **Ledger** (hash-chained JSONL metrics), **Bench** (hidden black-box Playwright suites), **Spec** (Spec Kit artifacts), **Tracker** (GitHub issue projection), **Realms** (web, games, mobile).

---

## 1. Evaluation: EricTechPro/super-board

| Field | Value |
|---|---|
| URL | https://github.com/EricTechPro/super-board |
| What it is | A Claude Code skill/plugin pack (Codex also supported). It drains a GitHub Project board through **Build → QA → Review** lanes and merges when checks are green. It has 8 skills, 9 commands and 6 Python guard hooks. |
| Stars / forks | 167 / 53 |
| Created | 2026-05-24 (about 4.5 months old) |
| Activity | Last push 2026-10-08. Last release v3.0.4 (2026-10-04); the README says v3.1.1. Three releases in 2 days in early October. |
| Licence | MIT |
| Archived | No |
| Contributors | `EricTechService` (26) and `EricTechPro` (23). In practice this is **one author with two accounts** **[ANALYSIS]**. |
| Shape | Bash and Python scripts plus Markdown skills. GitHub calls it "HTML" because of the docs site. It ships behavioural evals in `evals/`, run with `claude plugin eval`. |

**Maturity verdict [ANALYSIS]: a thoughtful single-author project. It is young, not popular, and not something to depend on. It is still worth reading closely, because several files hold operational lessons, written down with dates and incident numbers.** Much of it is prompt contract (SKILL.md and references) rather than code. The model ladder in the README (Haiku → Sonnet → Opus, plus Codex models) will go stale fast **[ANALYSIS]**.

### Ideas worth borrowing (concrete)

1. **A merge gate that re-verifies against the current base, inside a lock, pinned to the reviewed SHA.** See `scripts/super-board-merge-gate.sh`. The header documents a real failure: a PR showed `MERGEABLE/CLEAN` but failed `tsc`, because another PR had merged in the meantime and added an interface member. The gate:
   - takes an atomic `mkdir` lock;
   - merges the current base into the branch;
   - runs `verify_commands`;
   - merges with `gh pr merge --match-head-commit <reviewed sha>`.

   → **[ANALYSIS]** **Gleipnir checks and the Gates merge node.** This is a Bors-style "not rocket science" rule. Gas Town's Refinery does the same with a bisecting queue.
2. **One worker per lane, downstream first.** At most one Builder, one Tester and one Reviewer run at a time. Review is dispatched before QA, and QA before Build, so finished work closes before new work starts. Thirty Ready cards do not start thirty agents. → **[ANALYSIS]** **Odin scheduling policy.** It is a simple, defensible default for concurrency caps.
3. **"Review remembers."** The reviewer loads its last `<!-- super-review:report -->` PR comment. It re-checks each finding by stable ID (R1, R2…) with file:line proof before its own fresh pass. It forms its own hypotheses *before* reading the builder's summary, to resist anchoring. → **[ANALYSIS]** **Jormungandr fix loop.** Persist structured findings between iterations and require proof of closure, so the loop cannot "resolve" a thread without a fix.
4. **Fail closed on missing evidence.** `super-board-github-read.py` retries a read at most twice, then exits with code 79 and pauses the run. The rule is "never substitute an empty board, OPEN issue, full quota, or empty diff". Mutations are never blindly retried, because a lost response may hide a write that succeeded. → **[ANALYSIS]** **Gleipnir adapters and Tracker projection.** Make missing data a typed error, never a default value.
5. **Behavioural evals for the harness itself.** Each case has `case.yaml`, `seed.sh` and `graders/` (code checks plus an LLM judge), with stubbed `gh` and `git` that log calls. A grader can then assert, for example, "never called `pr merge`". → **[ANALYSIS]** **Bench**, applied to the factory rather than the product. Write regression evals for Yggdrasil's own agents.
6. **Preflight guards that come from incidents.** For example: "orphan-worker scan (added 2026-05-22 after #381 worker storm)", a production auto-merge refusal, a GraphQL rate-limit guard, and a DB-reach check before a wave. → **[ANALYSIS]** **Gates.** Each guard is a testable precondition with an exact halt message.
7. **A cheap router grades difficulty.** A small model labels each card easy, medium or hard, and that label picks the model tier. → **[ANALYSIS]** **Odin node config and Ledger.** Record the cost and outcome for each tier.

### Risks

- **Maintenance (bus factor of 1).** It moves fast (major v2→v3 in about 4 months, with a migration script), and has 16 open issues. Pin a commit if you copy anything **[ANALYSIS]**.
- **Licence.** MIT, so copying is fine. It credits `obra/superpowers`, `mattpocock/skills`, `BuilderIO/skills` and `tt-a1i/archify`, and `skills/visual/THIRD_PARTY_NOTICES.md` exists. Check those notices before you copy the `visual` skill **[ANALYSIS]**.
- **Security: what can go wrong.**
  - *`curl … get.sh | bash` install.* If the repo or the author's account is compromised, every new install runs the attacker's script with your user rights. That includes your `gh` token, which has `repo` and `project` scopes. The plugin route is no safer if you do not read the skills; a skill is code that runs with your permissions **[ANALYSIS]**.
  - *Autonomous merge.* The README pitch is "add tasks, walk away, get merged PRs". One bad card or poisoned issue body can put an agent-written change on your base branch. This cascades: every lane after it rebases onto the broken base, and the board keeps draining. super-board defends against this with a production-merge guard and an opt-in `guard-protected-push`. Yggdrasil's Gates should make human approval the default for production branches **[ANALYSIS]**.
  - *Prompt injection through intake.* `/super-collect` turns Sentry, PostHog and issue text into Backlog cards. An attacker who can write an issue or trigger an error message can plant instructions that a later Build agent reads. For example: "also add this webhook URL to the config". Treat intake text as untrusted data **[ANALYSIS]**.
  - *Hooks are guardrails, not a sandbox.* `guard-secrets.py` pattern-matches commands. An agent can still read `.env` through a path or tool the regex does not expect. Yggdrasil's rootless Podman sandbox is the real boundary; hooks are a second layer **[ANALYSIS]**.

**Tier [ANALYSIS]: worth watching, and a must-read for 4 files:** `scripts/super-board-merge-gate.sh`, `skills/super-board/references/run.md`, `skills/super-review/SKILL.md` and `evals/README.md`. Do not adopt it as a dependency.

---

## 2. Curated list by category

Tier legend: **MUST** = study and borrow from now. **WATCH** = useful, check back later. **SKIP** = not worth your time, with the reason given. The Tier and "Informs → what to borrow" columns are **[ANALYSIS]**; stars, activity and licence come from the GitHub API as described above.

### 2.1 Agent orchestrators over CLIs and multi-agent coding

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [gastownhall/gastown](https://github.com/gastownhall/gastown) (was steveyegge/gastown) | Go multi-agent workspace manager: Mayor, Rigs, Polecats, Witness, Refinery | 18.3k | push 2026-10-08, rel v1.2.1 (2026-06-06) | MIT | **Odin, Gates, Tree.** Several pieces: the **Refinery** (a per-rig Bors-style bisecting merge queue); a **three-tier watchdog** (Witness per rig, Deacon patrol, Dogs) for stuck-agent detection; **persistent identity with ephemeral sessions**; "molecules" (TOML formula → instantiated step workflow) as a model for graph templates. It is Go, so the code is directly readable for you. | MUST |
| [gastownhall/gascity](https://github.com/gastownhall/gascity) | Gas Town rewritten as an orchestration-builder SDK (Go): `city.toml`, runtime providers (tmux, subprocess, exec, **ACP**, Kubernetes), a reconcile loop | 1.4k | push 2026-10-11 | MIT | **Odin, Gleipnir.** A **declarative desired state plus a controller reconcile loop** for agents, and a pluggable runtime provider interface. This is the closest existing design to Odin plus Gleipnir, in Go. | MUST |
| [gastownhall/beads](https://github.com/gastownhall/beads) (bd) | Dependency-graph issue tracker for agents, on Dolt (versioned SQL) | 27.8k | push 2026-10-11, rel v1.3.1 (2026-09-30) | MIT | **Tracker, Ledger.** The commands `bd ready` (unblocked work), `--claim` (atomic claim) and `bd remember`. The rule "no markdown TODOs" works well as an agent instruction. Consider a beads-like local graph as the source of truth, with GitHub Issues as a *projection*. | MUST |
| [smtg-ai/claude-squad](https://github.com/smtg-ai/claude-squad) | Go TUI that runs several CLI agents in tmux plus git worktrees | 8.6k | rel v1.0.20 (2026-08-20) | **AGPL-3.0** | **Gleipnir adapter.** Simple, readable Go for driving tmux sessions per agent (Bubble Tea UI). Read it, but do not copy code into Yggdrasil unless you accept AGPL. | WATCH |
| [BloopAI/vibe-kanban](https://github.com/BloopAI/vibe-kanban) | Kanban plus workspaces for 10+ CLI agents (Rust/TS) | 28.3k | **sunsetting**, announced 2026-04-10 ([post](https://www.vibekanban.com/blog/shutdown)); push 2026-09-19, last rel 2026-04-24 | Apache-2.0 | **Gleipnir adapters.** Its per-agent executor adapters (Claude, Codex, Gemini, OpenCode…) are a good catalogue of CLI flags and quirks. The company stopped; the community edition is local-only. | WATCH (reference only) |
| Conductor (conductor.build) | Mac app for parallel Claude Code/Codex in worktrees | n/a | n/a | **Closed source** | UX reference only. | SKIP (not OSS) |
| [imbue-ai/sculptor](https://github.com/imbue-ai/sculptor) | Desktop app, parallel agents in isolated workspaces (containers) | 238 | rel v0.48.0 (2026-09-21) | MIT | **Gleipnir sandbox.** Container workspace sync ("pairing mode"). It is a research preview and not open to contributions. | WATCH |
| [stravu/crystal](https://github.com/stravu/crystal) | Parallel Claude/Codex sessions in worktrees | 3.1k | push 2026-02-26; **renamed to Nimbalyst**, the repo is effectively frozen | MIT | Nothing that others do not do better. | SKIP (superseded) |
| [devflowinc/uzi](https://github.com/devflowinc/uzi) | CLI for many agents in parallel worktrees | 582 | **push 2025-06-04** (dormant 16 months) | MIT | Dead. | SKIP |
| [ruvnet/ruflo](https://github.com/ruvnet/ruflo) (was claude-flow) | "Agent meta-harness": swarms, MCP tools, plugins | 74.3k | push and rel daily (v3.56.5, 2026-10-11) | MIT | Very large surface area and heavy marketing ("hive-mind", "ruOS"). Hard to find a small idea you can verify. **Hype is higher than substance.** | SKIP |
| [dagger/container-use](https://github.com/dagger/container-use) | MCP server: each agent gets a container plus a git branch | 4.1k | push 2026-09-21, **last rel v0.4.2 (2025-08-19)** | Apache-2.0 | **Gleipnir sandbox.** The pairing of **container and branch** per agent, an audit log of commands, and "drop into the agent's terminal". Releases have stalled; borrow the idea, not the dependency. | WATCH |
| [OpenHands/OpenHands](https://github.com/OpenHands/OpenHands) | Full open agent platform (SDK, runtime, GUI) | 90.5k | push 2026-10-11 | MIT (core) | **Gleipnir and Bench.** Its event-stream architecture (actions and observations as typed events), its sandboxed runtime, and its SWE-bench harness integration. A good model for typing the events that feed your Ledger. | MUST (read) |
| [SWE-agent/mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent) | About 100-line agent: bash only, linear history | 8.4k | push 2026-10-06 | MIT | **Jormungandr baseline.** It proves a tiny loop scores well. Use it as Yggdrasil's **control baseline** in Bench: if your graph does not beat mini-swe-agent, the graph is overhead. | MUST |
| [bmad-code-org/bmad-loop](https://github.com/bmad-code-org/bmad-loop) | Deterministic Python orchestrator for BMAD stories: pick → implement → adversarial review → verify → commit, in tmux sessions | 160 (2026-10-17) | rel v0.13.2 (2026-10-10), "early open beta" | MIT | **Odin, Jormungandr.** Added 2026-10-17; see [research-bmad](research-bmad.md). The closest design to Odin plus Jormungandr found so far: "no LLM in the control loop"; completion only on an agent event or session death, "never on model prose"; verification after every session; fresh-context review on another CLI or model, capped; one board writer; a deferred-work ledger with `sweep`; six CLIs as TOML profiles with cost-weighted budgets. No container sandbox: agents run on the host, with optional worktrees. | MUST (read) |
| [SWE-agent/SWE-agent](https://github.com/SWE-agent/SWE-agent) | The original ACI (agent-computer interface) research agent | 20.5k | push 2026-10-06 | MIT | **Gleipnir tools.** The ACI paper's lesson: tool *design* (linted edits, windowed file viewer) moves scores more than prompts do. | WATCH |
| [Aider-AI/aider](https://github.com/Aider-AI/aider) | Terminal pair programmer | 49.5k | **push 2026-05-22** (slowing) | Apache-2.0 | **Tree.** The **repo-map** (tree-sitter tags plus PageRank, budgeted to N tokens) is the canonical small code-routing idea. Also its edit formats and polyglot benchmark. | MUST (repo-map only) |
| [aaif-goose/goose](https://github.com/aaif-goose/goose) (was block/goose) | Extensible open agent (Rust), now under the Agentic AI Foundation | 55.1k | push 2026-10-09 | Apache-2.0 | **Spec and Gleipnir.** "Recipes" (shareable, parameterised agent runs as YAML) and its MCP-first extension model. | WATCH |
| [anomalyco/opencode](https://github.com/anomalyco/opencode) (was sst/opencode) | Open coding agent (TS), client/server | 212.6k | rel v1.19.0 (2026-10-11) | MIT | **Gleipnir adapter.** `opencode serve` exposes an HTTP API plus an SDK. This is the cleanest headless contract among the CLIs. Use it as a first-class adapter target. | MUST |
| [charmbracelet/crush](https://github.com/charmbracelet/crush) | Go TUI coding agent | 28.6k | rel v0.98.1 (2026-10-09) | **FSL-1.1-MIT** (source-available; becomes MIT after 2 years) | Go idioms for an agent loop, LSP integration, permission prompts. Read only: FSL forbids competing uses until a version converts. | WATCH |
| [openai/codex](https://github.com/openai/codex) | Codex CLI (Rust) | 128.6k | rel rust-v0.162.1 (2026-10-09) | Apache-2.0 | **Gleipnir.** These crates are worth reading: `codex exec --json` (headless JSONL), **`app-server` (JSON-RPC protocol)**, `execpolicy` (rule-based command policy), `linux-sandbox` (bwrap/landlock), `network-proxy`, `otel`, `worktree`. `execpolicy` is a ready-made design for Gleipnir policies. | MUST |
| [plandex-ai/plandex](https://github.com/plandex-ai/plandex) | Agent for large projects; Go; sandboxed diff review | 15.7k | **push 2025-10-03** (dormant 12 months) | MIT | The cumulative diff sandbox idea (changes stay pending until applied) is good, but the project is dead. | SKIP |
| [RooCodeInc/Roo-Code](https://github.com/RooCodeInc/Roo-Code) | VS Code agent | 24.3k | **ARCHIVED** 2026-05-15 (moved to roomote.dev) | Apache-2.0 | It is an IDE extension and archived. | SKIP |
| [cline/cline](https://github.com/cline/cline) | Agent as SDK, IDE extension or CLI | 70.2k | push 2026-10-11 | Apache-2.0 | Plan/Act mode split, as a reference for autonomy modes. Mostly IDE-centric. | SKIP for now |
| [coder/agentapi](https://github.com/coder/agentapi) | HTTP API wrapping Claude Code, Goose, Aider… by screen-scraping a TTY | 1.5k | **ARCHIVED and deprecated** | MIT | It was the closest prior art to a uniform CLI adapter. Read *why* TTY-scraping was abandoned in favour of native protocols (ACP, app-server, SDKs). | SKIP (lesson only) |
| [agentclientprotocol/agent-client-protocol](https://github.com/agentclientprotocol/agent-client-protocol) | ACP: JSON-RPC protocol between clients and agents (Zed-originated) | 4.4k | push 2026-10-11 | Apache-2.0 | **Gleipnir adapters.** Gas City already has an ACP runtime provider. Make **ACP one of Gleipnir's adapter protocols** next to native `claude -p --output-format stream-json`, `codex app-server` and `opencode serve`. | MUST |
| [agent-dance/agent-adaptor](https://github.com/agent-dance/agent-adaptor) | Go SDK that standardises local execution of `codex`, `claude`, `cursor`… | 64 | push 2026-10-04 | Apache-2.0 | **Gleipnir.** Small Go prior art for exactly your adapter layer. Compare its interface with yours. | WATCH |
| [mikeyobrien/ralph-orchestrator](https://github.com/mikeyobrien/ralph-orchestrator) | Rust Ralph loop with "hats" (roles), PDD planning, completion token | 3.2k | rel v2.10.1 (2026-06-23) | MIT | **Jormungandr.** Explicit `LOOP_COMPLETE` sentinel plus an iteration cap, specs under `.ralph/specs/<feature>/`, and role "hats" on one loop. | WATCH |
| [frankbria/ralph-claude-code](https://github.com/frankbria/ralph-claude-code) | Ralph loop for Claude Code with "intelligent exit detection" and rate limiting | 9.7k | push 2026-10-10 | MIT | **Jormungandr caps.** Exit heuristics (no progress for N loops, a circuit breaker) are a useful list of stop conditions. | WATCH |
| [snarktank/ralph](https://github.com/snarktank/ralph) | Minimal PRD-driven Ralph loop | 21.9k | push 2026-02-02 | MIT | Read once in 10 minutes; nothing beyond the essay. | SKIP |
| [ClaytonFarr/ralph-playbook](https://github.com/ClaytonFarr/ralph-playbook) | Guide to Ralph loops | 1.0k | push 2026-03-06 | MIT | A concise write-up of "backpressure" (tests, types, lints) as the loop governor. | WATCH |
| [umputun/ralphex](https://github.com/umputun/ralphex) | Go extended Ralph loop for plan execution | 1.5k | push 2026-10-05 | MIT | Go reference for a plan-driven loop with review phases. | WATCH |
| Claude Code `plugins/ralph-wiggum` ([link](https://github.com/anthropics/claude-code/tree/main/plugins)) | Official Ralph plugin using a Stop hook | (in claude-code) | active | see repo | **Jormungandr.** It shows how a **Stop hook** can re-inject the prompt to keep a headless session looping, which is an alternative to an outer bash loop. | WATCH |
| [automazeio/ccpm](https://github.com/automazeio/ccpm) | PM skill system: PRD → epic → GitHub Issues plus worktrees | 8.4k | push 2026-03-18 | MIT | **Tracker.** Its mapping of PRD to epic to issues, with sub-issues, is close to your GitHub projection. | WATCH |
| [humanlayer/humanlayer](https://github.com/humanlayer/humanlayer) | Started as human-approval SDK; now "CodeLayer" agent IDE | 11.7k | push 2026-06-19 | Apache-2.0 | **Gates.** Its original `require_approval` / human-as-tool idea is worth knowing. The current product is less relevant. | WATCH |
| [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) | Ghostty-based macOS terminal for agent sessions | 28.1k | push 2026-10-11 | GPL-3.0+ (client) | Mac terminal UX; not relevant to a headless Linux factory. | SKIP |

### 2.2 Harness-engineering learning resources

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [walkinglabs/learn-harness-engineering](https://github.com/walkinglabs/learn-harness-engineering) | Course: five subsystems (instructions, tools, environment, state, feedback); lectures on loop engineering (L13) and graph engineering (L14); breakdowns of Claude Code, Codex, Pi and DeepSeek harnesses | 19.7k | push 2026-10-01 | MIT | **All layers.** L14 ("a loop is a graph with one node") is the *exact* thesis behind Odin plus Jormungandr. `skills/harness-creator/` scaffolds AGENTS.md, a feature list, init.sh and verification steps. Also the maker/checker templates. | MUST |
| [walkinglabs/awesome-harness-engineering](https://github.com/walkinglabs/awesome-harness-engineering) | Curated list | 4.4k | push 2026-08-19 | CC0 | A discovery index. | WATCH |
| [ai-boost/awesome-harness-engineering](https://github.com/ai-boost/awesome-harness-engineering) | Curated list: tools, patterns, evals, memory, permissions | 4.8k | push 2026-10-11 | CC0 | A fresher discovery index than walkinglabs'. | WATCH |
| [bradAGI/awesome-cli-coding-agents](https://github.com/bradAGI/awesome-cli-coding-agents) | Directory of terminal agents and orchestrators | 1.3k | push 2026-10-05 | none stated | Lists the adapter targets for Gleipnir. | WATCH |
| [humanlayer/12-factor-agents](https://github.com/humanlayer/12-factor-agents) | Principles for production LLM software | 26.6k | push 2025-09-21 | Apache-2.0 (code) | **Odin.** Factors such as "own your control flow", "unify execution state and business state", "pause/resume via simple APIs" and "small focused agents" back up Odin owning the graph rather than delegating to one big agent session. | MUST |
| [anthropics/claude-code](https://github.com/anthropics/claude-code) | Claude Code repo: `plugins/` (code-review, feature-dev, hookify, ralph-wiggum, security-guidance), `.devcontainer/`, CHANGELOG | 150.1k | push 2026-10-10 | proprietary (no OSS licence) | **Gleipnir.** The reference `.devcontainer` with its firewall script is directly relevant to rootless Podman devcontainers. Plugins show the hook patterns. Read only; no OSS licence. | MUST (read) |
| [anthropics/claude-agent-sdk-python](https://github.com/anthropics/claude-agent-sdk-python) / [-typescript](https://github.com/anthropics/claude-agent-sdk-typescript) | Official Agent SDKs (drive Claude Code programmatically) | 8.2k / 1.8k | push 2026-10-09 | MIT / none stated | **Gleipnir.** The SDK's message types and hook/permission callbacks show the *official* contract that the CLI's `stream-json` mode exposes. No official Go SDK exists; see `severity1/claude-agent-sdk-go` (unofficial, 176 stars). | MUST |
| [anthropics/claude-agent-sdk-demos](https://github.com/anthropics/claude-agent-sdk-demos) | Demo agents | 2.8k | push 2026-08-27 | none stated | Small examples; skim. | WATCH |
| [anthropics/claude-cookbooks](https://github.com/anthropics/claude-cookbooks) | Notebooks (tool use, agents, evals) | 53.3k | push 2026-10-10 | MIT | The "agents" patterns notebooks implement the five workflows from *Building effective agents*. | WATCH |
| [anthropics/skills](https://github.com/anthropics/skills) | Agent Skills repo | 180.4k | push 2026-10-09 | mixed, no top-level licence | **Realms.** The skill packaging format is a good container for realm knowledge (web SaaS, games). | WATCH |
| [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action) | GitHub Action running Claude Code | 9.5k | push 2026-10-09 | MIT | **Tracker.** How to trigger from issue and PR events and post results back. | WATCH |
| [obra/superpowers](https://github.com/obra/superpowers) | Skills methodology: brainstorm → plan → TDD → subagent-driven development → review | 297.4k | rel v7.0.0 (2026-10-10) | MIT | **Spec and Jormungandr.** Shows how to encode a process (TDD, verification before completion, review) as composable skills. super-board builds on it. | MUST |
| [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | Curated Claude Code resources | 55.4k | push 2026-10-11 | **CC BY-NC-ND 4.0** | Discovery only. Do not copy content: NoDerivatives. | WATCH |
| [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) | All hook events demonstrated | 3.9k | push 2026-03-04 | none stated | **Gleipnir policies.** A complete example of every hook (PreToolUse, Stop, SubagentStop…). No licence, so read only. | WATCH |

### 2.3 Spec-driven development

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [github/spec-kit](https://github.com/github/spec-kit) | `specify` CLI: constitution → spec → plan → tasks → implement, under `.specify/` and `specs/NNN-feature/` | 140.8k | rel v1.1.3 (2026-10-09) | MIT | **Spec (your chosen layout).** Track its template changes. The **constitution** maps to umbrella-level policy, and `tasks.md` with `[P]` parallel markers maps to Odin fan-out. | MUST |
| [Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec) | Lightweight SDD: `openspec/specs` (current truth) plus `openspec/changes/<id>` (proposals as deltas) | 71.6k | rel v1.14.1 (2026-10-06) | MIT | **Spec and Tree.** The **change-as-delta** model (ADDED, MODIFIED, REMOVED requirements, archived on merge) fits brownfield leaf repos better than Spec Kit's per-feature folders. Consider it for changes to existing leaves. | MUST |
| [bmad-code-org/BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) | Agile AI-driven development. v6 was a persona pipeline (analyst, PM, architect, SM, dev, QA). The v7 preview on `main` is a set of right-sized skills: `bmad-spec` → `bmad-ticket` → `bmad-build`, with optional personas | 54.3k (2026-10-17) | rel v6.12.4 (2026-10-14); v7 preview alpha, breaking changes | MIT; "BMad" in any casing is a trademark | **Odin, Gleipnir, Havamal.** Re-read 2026-10-17; see [research-bmad](research-bmad.md). Borrow: `bmad-build-auto`'s worker contract (one unit per run, typed `blocked` reasons, `risk`, deferred findings "not a backlog", a patch saved on an intent gap); `bmad-retrospective`'s "what would prevent the next one" and its follow-through check on the last retro; `bmad-eval`'s baseline/variant/quality/trigger modes, clean rooms, three runs, one change per round with revert on regression; the theory of project context. Skills render at run time through `uv`, which fits Havamal's pinned copies poorly. | MUST (concepts) |
| [buildermethods/agent-os](https://github.com/buildermethods/agent-os) | Standards injection plus spec shaping | 5.5k | push 2026-10-07, rel v3.0.0 (2026-01) | MIT | Standards files per stack, similar to "realm" conventions. | WATCH |
| [eyaltoledano/claude-task-master](https://github.com/eyaltoledano/claude-task-master) | PRD → dependency-aware task graph (MCP) | 28.2k | push 2026-04-28 (slowing) | **MIT + Commons Clause** | Its complexity analysis and dependency graph of tasks. The Commons Clause bans selling it as a service, so **do not vendor its code** into an OSS factory that someone might host. | WATCH |
| [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd) | Kiro-style SDD for many CLIs (requirements → design → tasks, EARS) | 3.7k | push 2026-09-23 | MIT | **Spec.** EARS-format acceptance criteria are testable and map cleanly to hidden Playwright checks. | WATCH |
| [kirodotdev/Kiro](https://github.com/kirodotdev/Kiro) | Kiro IDE issue tracker and docs (the IDE is closed) | 4.4k | push 2026-09-15 | none | Read the docs for spec and steering formats only. | SKIP (not OSS) |

### 2.4 Sandboxing

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [devcontainers/cli](https://github.com/devcontainers/cli) | Reference implementation of devcontainer.json (`devcontainer up/exec`) | 3.0k | push 2026-10-08 | MIT | **Gleipnir sandbox (core dependency).** Supports `--docker-path podman`. Learn its features, lifecycle hooks and `remoteUser` behaviour under rootless Podman. | MUST |
| [podman-container-tools/podman](https://github.com/podman-container-tools/podman) (was containers/podman) | Rootless OCI engine | 33.0k | push 2026-10-10 | Apache-2.0 | **Gleipnir.** `--userns=keep-id`, `--network=none` or pasta, and the `podman machine` / socket API. Note the org move. | MUST |
| [anthropics/sandbox-runtime](https://github.com/anthropics/sandbox-runtime) (srt) | OS-level filesystem and network sandbox (bubblewrap on Linux, sandbox-exec on macOS) plus a domain-allowlist proxy | 5.5k | rel v0.0.79 (2026-10-07), beta | Apache-2.0 | **Gleipnir policies.** A **second layer inside the container**: an egress allowlist proxy and denial of reads to `~/.ssh`. Its config schema is a good model for Yggdrasil's per-node policy files. | MUST |
| [containers/bubblewrap](https://github.com/containers/bubblewrap) | Unprivileged namespace sandbox | 9.0k | push 2026-09-25 | LGPL-2.0+ | Underlies srt and Codex `linux-sandbox`. Know what it can and cannot block. | WATCH |
| [dagger/container-use](https://github.com/dagger/container-use) | (see 2.1) container plus branch per agent | 4.1k | stalled releases | Apache-2.0 | The audit trail of every command. | WATCH |
| [e2b-dev/E2B](https://github.com/e2b-dev/E2B) / [e2b-dev/runtime](https://github.com/e2b-dev/runtime) | Firecracker microVM sandboxes (SDK plus self-hostable runtime in Go) | 14.3k / 1.7k | push 2026-10-09 / 10-11 | Apache-2.0 | **Gleipnir (future remote backend).** A Go runtime with snapshot/resume of microVMs. | WATCH |
| [superradcompany/microsandbox](https://github.com/superradcompany/microsandbox) (was zerocore-ai) | Local-first microVM runtime (libkrun) | 8.6k | rel v0.7.8 (2026-10-09) | Apache-2.0 | A stronger-isolation local option if containers stop being enough. Pre-1.0. | WATCH |
| [kubernetes-sigs/agent-sandbox](https://github.com/kubernetes-sigs/agent-sandbox) | K8s CRD for isolated, stateful, singleton agent workloads (gVisor/Kata) | 4.2k | push 2026-10-09 | Apache-2.0 | **Gleipnir (cluster mode, later).** Its Sandbox / SandboxTemplate / warm-pool API design. | WATCH |
| [google/gvisor](https://github.com/google/gvisor) | User-space kernel (runsc) | 19.6k | push 2026-10-10 | Apache-2.0 | `runsc` can run under Podman as an OCI runtime for untrusted realms. | WATCH |
| [firecracker-microvm/firecracker](https://github.com/firecracker-microvm/firecracker) | microVM VMM | 37.3k | push 2026-10-09 | Apache-2.0 | Background reading behind E2B. | WATCH |
| [kata-containers/kata-containers](https://github.com/kata-containers/kata-containers) | VM-isolated OCI runtime | 8.9k | push 2026-10-11 | Apache-2.0 | An alternative to gVisor. | WATCH |
| [daytonaio/daytona](https://github.com/daytonaio/daytona) | Agent sandbox infra | 71.6k | **ARCHIVED** (core moved private, June 2026) | AGPL-3.0 at v0.190.0 | Closed now. | SKIP |
| [abshkbh/arrakis](https://github.com/abshkbh/arrakis) | Self-hosted microVM sandbox | 886 | push 2025-06-02 (dormant) | AGPL-3.0 | Dormant. | SKIP |

**Security: why two layers.** Rootless Podman stops a container escape from becoming root on the host. It does *not* stop an agent with network access from sending the repo's `.env` to a paste site after reading a prompt-injected README. That is a single `curl` call, and the container allows it. **[ANALYSIS]** Add an egress allowlist (srt proxy or Podman `--network=none` plus a proxy) and do not mount host credentials. Then a poisoned dependency README cannot quietly turn every leaf repo build into a credential leak.

### 2.5 Evals and benchmarks

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [harbor-framework/harbor](https://github.com/harbor-framework/harbor) | Eval framework from the Terminal-Bench team: runs Claude Code, Codex, OpenHands… against containerised tasks, locally or in the cloud | 6.0k | rel v0.24.0 (2026-10-05) | Apache-2.0 | **Bench (format).** The task layout: instruction plus `task.toml`, `environment/Dockerfile`, `tests/`, and an oracle `solution/`. It already has **agent adapters for the same CLIs** Gleipnir drives. Make Yggdrasil's benchmark format Harbor-compatible, or at least exportable to it. | MUST |
| [harbor-framework/terminal-bench-2](https://github.com/harbor-framework/terminal-bench-2) / [terminal-bench-1](https://github.com/harbor-framework/terminal-bench-1) | Terminal task benchmark | 425 / 2.6k | push 2026-04-30 / 07-11 | Apache-2.0 | Example tasks with hidden tests: a model for your hidden Playwright suites. | MUST (with Harbor) |
| [SWE-bench/SWE-bench](https://github.com/SWE-bench/SWE-bench) | Issue → patch benchmark (Full, Lite, Verified, Multimodal) | 6.0k | push 2026-09-18 | MIT | **Bench.** FAIL_TO_PASS and PASS_TO_PASS test splits are the right grading model: hidden tests that must flip, plus regression tests that must stay green. Multimodal is the visual front-end variant. | MUST (concepts) |
| [scaleapi/SWE-bench_Pro-os](https://github.com/scaleapi/SWE-bench_Pro-os) | Long-horizon, contamination-resistant SWE tasks | 541 | push 2026-09-22 | MIT | Shows how a held-out commercial set limits contamination. Mirror this with **private hidden suites per realm**. | WATCH |
| [Aider-AI/polyglot-benchmark](https://github.com/Aider-AI/polyglot-benchmark) | Exercism problems in 6 languages | 224 | **push 2024-12-22** | none stated | Saturated and stale. | SKIP |
| [vercel/next-evals-oss](https://github.com/vercel/next-evals-oss) | Next.js competency evals | 324 | push 2026-10-10 | MIT | **Bench (web SaaS realm).** Closest public analogue to your web realm; use the tasks as seeds. | MUST |
| WebDev Arena (lmarena.ai) | Human-preference leaderboard for web apps | n/a | n/a | not OSS | Read the methodology only. | SKIP (not OSS) |
| [UKGovernmentBEIS/inspect_ai](https://github.com/UKGovernmentBEIS/inspect_ai) / [inspect_evals](https://github.com/UKGovernmentBEIS/inspect_evals) | Eval framework: Task / Solver / Scorer, sandboxes, log viewer | 3.0k / 698 | push 2026-10-10 / 10-11 | MIT | **Bench and Ledger.** Clean concepts (dataset → solver → scorer), a structured eval log format, and Docker sandboxes. METR moved to it from Vivaria. | MUST |
| [METR/vivaria](https://github.com/METR/vivaria) | METR's old eval platform | 144 | **ARCHIVED** (METR moved to Inspect) | MIT | Superseded. | SKIP |
| [openai/evals](https://github.com/openai/evals) | Early eval registry | 19.6k | push 2026-04-14 (slow) | MIT | Historic; superseded by Inspect and promptfoo. | SKIP |
| [promptfoo/promptfoo](https://github.com/promptfoo/promptfoo) | Prompt, agent and RAG tests plus red-teaming | 25.9k | push 2026-10-11 | MIT | **Gleipnir checks.** Its **red-team plugins** (prompt injection, data exfiltration) can attack Yggdrasil's own agents. | WATCH |
| [openai/SWELancer-Benchmark](https://github.com/openai/SWELancer-Benchmark) | Freelance-task benchmark with E2E tests | 1.4k | **ARCHIVED** | none | Its idea of grading with **end-to-end browser tests written by engineers** matches your hidden Playwright suites. Read the paper only. | SKIP (lesson only) |
| [microsoft/playwright](https://github.com/microsoft/playwright) / [playwright-mcp](https://github.com/microsoft/playwright-mcp) | Browser automation; MCP for agents | 97.5k / 38.0k | push 2026-10-10 / 10-08 | Apache-2.0 | **Bench and Jormungandr.** Hidden suites use Playwright test. Agents use playwright-mcp for *visible* self-checks. Keep the two strictly separate so agents cannot see the grader. | MUST |

**Security: protecting hidden suites.** If the hidden Playwright suite is mounted anywhere the agent's container can read, or its results leak into the agent's context, the agent will learn to pass the test rather than build the feature **[ANALYSIS]**. A real example from Anthropic's eval write-up: an agent read git history from earlier trials. Run graders in a separate container after the agent's container has stopped, and only give back pass/fail plus coarse failure categories **[ANALYSIS]**.

### 2.6 Observability and tracing for agents

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [open-telemetry/semantic-conventions-genai](https://github.com/open-telemetry/semantic-conventions-genai) | GenAI semantic conventions (moved out of the main semconv repo): agent spans, events, metrics, MCP | 424 | push 2026-10-10 | Apache-2.0 | **Ledger.** Name ledger fields after `gen_ai.*` attributes (e.g. `gen_ai.usage.input_tokens`, `gen_ai.agent.name`, `gen_ai.operation.name`) so you can export to any OTel backend later. Most of the spec is still **Development** status (about 305 Development, 20 Stable markers in the agent-spans doc), so expect churn. | MUST |
| [traceloop/openllmetry](https://github.com/traceloop/openllmetry) | OTel instrumentation for LLM SDKs | 7.5k | push 2026-10-11 | Apache-2.0 | Reference for how GenAI spans are emitted in practice. | WATCH |
| [langfuse/langfuse](https://github.com/langfuse/langfuse) | Tracing, evals and prompt management; OTel ingest | 35.6k | push 2026-10-11 | MIT core plus a commercial `ee/` folder (now owned by ClickHouse) | **Ledger viewer.** Self-host it as the UI over OTel exports from your ledger. Its trace → observation → score model is worth copying. | MUST |
| [Arize-ai/phoenix](https://github.com/Arize-ai/phoenix) | Tracing and evals, OTel-native | 11.8k | push 2026-10-11 | **Elastic License 2.0** | A good UI, but ELv2 bans offering it as a managed service. Fine for local use. | WATCH |
| [lmnr-ai/lmnr](https://github.com/lmnr-ai/lmnr) (Laminar) | Agent-focused observability, browser session replay | 3.4k | push 2026-10-09 | Apache-2.0 | Syncing browser agent replays with traces could help debug Playwright-driven realms. | WATCH |
| [Helicone/helicone](https://github.com/Helicone/helicone) | Proxy-based LLM observability | 6.2k | push 2026-10-10 | Apache-2.0 | The proxy approach does not fit CLI agents with their own auth. | SKIP |
| [AgentOps-AI/agentops](https://github.com/AgentOps-AI/agentops) | Python agent monitoring SDK | 5.9k | push 2026-06-25 (slowing) | MIT | Python SDK-centric. | SKIP |
| [disler/claude-code-hooks-multi-agent-observability](https://github.com/disler/claude-code-hooks-multi-agent-observability) | Hook events → server → live dashboard | 1.5k | push 2026-02-08 | none stated | **Ledger.** The hook-to-event-stream pattern for CLIs that lack native OTel. Read only. | WATCH |
| [gastownhall/gascity-otel](https://github.com/gastownhall/gascity-otel) | OTel stack for Gas City (VictoriaMetrics, VictoriaLogs, Grafana) | 6 | push 2026-03-13 | Apache-2.0 | A worked example of an orchestrator emitting OTel. | WATCH |

Also: Claude Code and Codex both ship native OpenTelemetry export (Codex has `otel` crates). Gleipnir can turn that on per run and ingest it into the ledger, so you need less custom parsing **[ANALYSIS]**.

### 2.7 Code-graph routing and context

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) | Codebase → knowledge graph (tree-sitter for code, LLM pass for docs); `graph.json`, `GRAPH_REPORT.md`, `explain` / `path` / `query` | 125.4k | rel v0.9.85 (2026-10-10) | Apache-2.0 | **Tree (your "graphify-like" index).** Borrow: an **EXTRACTED vs INFERRED** confidence tag on every edge; `graph.schema_version`; community detection to get module boundaries; the `GRAPH_REPORT.md` digest as the per-umbrella routing summary. Python, with a cloud upsell; the star count is inflated, but the core ideas are sound. | MUST |
| [DeusData/codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) | Native (C) tree-sitter knowledge graph in SQLite, 162 languages, 17 MCP tools (trace, impact analysis, Cypher, dead code, cross-service HTTP links) | 46.3k | rel v0.11.0 (2026-09-15) | MIT | **Tree (impact analysis and wiring tables).** Its **cross-service HTTP route linking** and IaC (Dockerfile, K8s) nodes map to your umbrella "wiring tables". It ships a [preprint](https://arxiv.org/abs/2603.27277). Claims like "120x fewer tokens" are self-reported. | MUST |
| [Aider repo-map](https://github.com/Aider-AI/aider) (`aider/repomap.py`) | tree-sitter tags plus PageRank, budgeted to tokens | (aider) | — | Apache-2.0 | **Tree.** The cheapest working routing index. Port it to Go as the baseline ranking for leaf selection. | MUST |
| [oraios/serena](https://github.com/oraios/serena) | LSP-backed semantic retrieval and editing MCP | 30.2k | push 2026-10-09 | **GPL-3.0+ (app) / MIT (SolidLSP)** | **Gleipnir tools.** Symbol-level tools (find_symbol, find_referencing_symbols, replace_symbol_body). Note the **licence change**: only the SolidLSP part is MIT now. Run it as an MCP tool inside the sandbox, which is fine; do not vendor the app code. | WATCH |
| [tree-sitter/tree-sitter](https://github.com/tree-sitter/tree-sitter) / [go-tree-sitter](https://github.com/tree-sitter/go-tree-sitter) | Incremental parser; official Go bindings | 27.2k / 300 | push 2026-10-11 / 2025-11-16 | MIT | **Tree.** The foundation for your Go indexer. `tags.scm` queries give definitions and references per language. | MUST |
| [scip-code/scip](https://github.com/scip-code/scip) (was sourcegraph/scip) | Precise code intelligence index format (protobuf) | 827 | push 2026-10-10 | Apache-2.0 | **Tree.** A good *storage format* for precise symbol graphs if tree-sitter heuristics are not enough. Per-language indexers exist (scip-go, scip-typescript). | WATCH |
| [ast-grep/ast-grep](https://github.com/ast-grep/ast-grep) | Structural search, lint and rewrite | 16.2k | push 2026-10-11 | MIT | **Gleipnir checks.** Cheap structural lint rules per realm (e.g. "no raw SQL in handlers"). | WATCH |
| [yamadashy/repomix](https://github.com/yamadashy/repomix) / [mufeedvh/code2prompt](https://github.com/mufeedvh/code2prompt) | Pack a repo into one prompt | 28.8k / 7.7k | active | MIT | Packing a whole repo is the opposite of routing. Only useful for small leaves. | SKIP |
| [zilliztech/claude-context](https://github.com/zilliztech/claude-context) | Vector-search MCP | 12.6k | push 2026-07-14 | MIT | Embedding-based search, less explainable than a graph. | SKIP |
| [vitali87/code-graph-rag](https://github.com/vitali87/code-graph-rag) | Graph RAG over monorepos (Memgraph) | 5.2k | push 2026-10-11 | MIT | Overlaps the two MUSTs above. | SKIP |
| [github/stack-graphs](https://github.com/github/stack-graphs) | Name-resolution graphs | 874 | **ARCHIVED** | Apache-2.0 | Archived. | SKIP |
| [sourcegraph/zoekt](https://github.com/sourcegraph/zoekt) | Trigram code search (Go) | 2.0k | push 2026-10-09 | Apache-2.0 | Go full-text index across all leaves, if grep becomes slow. | WATCH |

### 2.8 Durable workflow and graph engines (learn from them, even if you do not adopt them)

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [temporalio/temporal](https://github.com/temporalio/temporal) | Durable execution (Go server) | 23.6k | push 2026-10-10 | MIT | **Odin.** Event-sourced history plus deterministic replay, activity retries/timeouts/heartbeats, signals for **human approval**. Odin's run log should be a replayable event history, not mutable state. | MUST (concepts) |
| [dbos-inc/dbos-transact-golang](https://github.com/dbos-inc/dbos-transact-golang) | Durable workflows as a Go library on Postgres (or SQLite) | 851 | push 2026-10-08 | MIT | **Odin.** The lightest "durable steps in-process" model in Go: checkpoint every step's output and resume after a crash. The closest fit for an embedded engine. | MUST |
| [langchain-ai/langgraph](https://github.com/langchain-ai/langgraph) | Graph of nodes over shared state, with checkpoints and `interrupt()` | 43.1k | push 2026-10-11 | MIT | **Odin and Gates.** `interrupt()`/resume for human-in-the-loop, per-node checkpoints, time travel. The API shape for approval gates. | MUST (concepts) |
| [hatchet-dev/hatchet](https://github.com/hatchet-dev/hatchet) | Go task orchestration: DAGs, concurrency keys, rate limits | 8.1k | push 2026-10-10 | MIT | **Odin scheduling.** **Concurrency keys** (e.g. one job per leaf repo) and fair queuing. | WATCH |
| [restatedev/restate](https://github.com/restatedev/restate) | Durable execution with a journal | 4.5k | push 2026-10-10 | **BSL 1.1** | Journaled RPC is a nice design; the licence rules out embedding. | WATCH |
| [inngest/inngest](https://github.com/inngest/inngest) | Event-driven step functions (Go server) | 5.9k | push 2026-10-11 | **SSPL** (Apache future licence) | The `step.waitForEvent` pattern fits approvals. The licence rules out embedding. | WATCH |
| [dagger/dagger](https://github.com/dagger/dagger) | Container-based programmable pipelines (Go SDK) | 16.3k | push 2026-10-10 | Apache-2.0 | **Gleipnir checks.** Content-addressed caching of check steps. Re-running unchanged checks wastes loop iterations. | WATCH |
| [riverqueue/river](https://github.com/riverqueue/river) | Postgres job queue (Go) | 5.8k | push 2026-10-11 | MPL-2.0 | Transactional enqueue, if Odin ever needs a durable queue. | WATCH |

### 2.9 Go agent libraries

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [modelcontextprotocol/go-sdk](https://github.com/modelcontextprotocol/go-sdk) | Official MCP Go SDK (with Google) | 5.2k | push 2026-10-11 | MIT → Apache-2.0 (in transition) | **Gleipnir.** Use it to expose Yggdrasil tools (index queries, ledger writes, gate requests) to agents as an MCP server. | MUST |
| [anthropics/anthropic-sdk-go](https://github.com/anthropics/anthropic-sdk-go) | Official Anthropic Go SDK | 1.2k | push 2026-10-09 | MIT | For Odin's own small LLM calls (routing, grading, summaries) outside the CLIs. | MUST |
| [openai/openai-go](https://github.com/openai/openai-go) | Official OpenAI Go SDK | 3.5k | push 2026-10-11 | Apache-2.0 | Same role, for an OpenAI-compatible judge model. | WATCH |
| [mark3labs/mcp-go](https://github.com/mark3labs/mcp-go) | Community MCP Go library | 9.2k | push 2026-10-09 | MIT | Widely used before the official SDK. Prefer the official one for new code. | SKIP |
| [cloudwego/eino](https://github.com/cloudwego/eino) | ByteDance's Go LLM framework (graph, compose, callbacks) | 13.3k | push 2026-10-10 | Apache-2.0 | **Odin.** Read its **typed graph compose API** (type-checked edges between nodes) and callback aspects. Don't adopt it; Odin is not an LLM-call graph. | WATCH |
| [google/adk-go](https://github.com/google/adk-go) | Google Agent Development Kit for Go | 8.9k | push 2026-10-10 | Apache-2.0 | Its evaluation and session abstractions in Go. | WATCH |
| [genkit-ai/genkit](https://github.com/genkit-ai/genkit) (Go in `go/`) | Google's multi-language AI framework | 6.5k | push 2026-10-11 | Apache-2.0 | Its flow tracing dev UI. | SKIP |
| [tmc/langchaingo](https://github.com/tmc/langchaingo) | LangChain port | 9.7k | push 2026-10-11 | MIT | Abstraction-heavy. You need SDKs, not chains. | SKIP |
| [charmbracelet/bubbletea](https://github.com/charmbracelet/bubbletea) | Elm-style Go TUI framework | 45.4k | push 2026-10-08 | MIT | **Gates UX.** A TUI for approvals and run monitoring (claude-squad and crush use it). | MUST (when you build the UI) |
| [severity1/claude-agent-sdk-go](https://github.com/severity1/claude-agent-sdk-go) | Unofficial Go wrapper for Claude Code CLI (stream-json) | 176 | push 2026-10-05 | MIT | **Gleipnir.** Compare it with your adapter; maybe borrow the message types. | WATCH |
| [dolthub/dolt](https://github.com/dolthub/dolt) | Git-versioned SQL database (Go) | 24.6k | push 2026-10-10 | Apache-2.0 | **Ledger and Tracker.** Beads chose it for branch and merge of work state. Compare it with your hash-chained JSONL. | WATCH |

### 2.10 Game-dev agent tooling (future game realm)

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [hi-godot/godot-ai](https://github.com/hi-godot/godot-ai) | MCP server plus tools for Godot (GDScript) | 2.9k | push 2026-10-10 | MIT | **Realms (games).** The most active Godot MCP. Covers scene, node and script ops, and running the game. | WATCH (MUST when the realm starts) |
| [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) | Godot MCP: launch editor, run project, capture debug output | 6.0k | push 2026-04-16 (slowing) | MIT | Simple design: run headless and capture stdout as feedback. | WATCH |
| [ee0pdt/Godot-MCP](https://github.com/ee0pdt/Godot-MCP) | Early Godot MCP | 618 | push 2025-03-19 (dormant) | MIT | Dormant. | SKIP |
| [phaserjs/phaser](https://github.com/phaserjs/phaser) | HTML5 2D game framework | 40.5k | push 2026-08-21 | MIT | **Realms (browser games).** It runs in the browser, so **your existing Playwright Bench works unchanged**. Expose game state on `window` for assertions. The fastest route to a game realm. | MUST (for the game realm) |
| [phaserjs/editor-mcp-server](https://github.com/phaserjs/editor-mcp-server) | MCP for Phaser Editor | 36 | push 2025-09-19 | none stated | Tiny, and tied to a paid editor. | SKIP |
| [godot-gdunit-labs/gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) / [bitwes/Gut](https://github.com/bitwes/Gut) | Godot unit testing (headless CLI runs) | 1.3k / 2.8k | push 2026-10-10 / 08-18 | MIT / none stated | **Gleipnir checks for Godot.** Headless test runs give the loop its signal. gdUnit4 also has scene-runner input simulation. | WATCH |
| [gua-project/gua](https://github.com/gua-project/gua) | "Playwright-style" UI testing for Godot and Unity | 19 | push 2026-10-10 | MIT | **Bench for engine games.** Exactly the idea of hidden black-box suites, but very new. | WATCH |
| [CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp) | Unity Editor bridge for agents | 14.8k | push 2026-10-08 | MIT | Unity is not on your roadmap; skim for the editor-bridge pattern. | SKIP |

### 2.11 Learning stores and self-improvement

Added 2026-10-17; the GitHub API data in this section is from that day. The full analysis is in
[research-compounding](research-compounding.md).

> **Highlight [ANALYSIS]: Compound Engineering is the closest existing design for the middle of the
> Ouroboros loop**, the step between the ledger and a factory change. It distils one solved problem
> into one typed, searchable lesson, keeps the store honest with a refresh pass, and promotes lessons
> into prescriptive rules. It does not measure whether a lesson helped; Yggdrasil's criterion 7 and
> `ygg metrics --compare` would supply that half.

| Project | What it is | Stars | Activity | Licence | Informs → what to borrow | Tier |
|---|---|---|---|---|---|---|
| [EveryInc/compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin) | Skill pack (36 skills, 14 hosts): brainstorm → plan → work → simplify → review → **compound**; learnings go to `docs/solutions/` as markdown with typed YAML frontmatter | 25.6k | push 2026-10-17, rel v3.31.0 (2026-10-16) | MIT | **Ledger, Odin (change graph), Gleipnir (skills).** Borrow: the "durable bar" counterfactual for whether a lesson is worth writing; the schema (bug vs knowledge track, `applies_when`, `retire_when`); grep-first retrieval over frontmatter; the refresh outcomes (Keep, Update, Consolidate, Replace, Delete) with "age alone is not staleness" and "unverifiable is not false"; the promotion ladder learning → pattern → Compound Pack; `ce-retune`'s refusal to tune without an A/B harness. Do not install it whole: it is tied to its own skills and host UIs, and it releases almost daily. | MUST (concepts) |
| [iwe-org/memory-bench](https://github.com/iwe-org/memory-bench) | Benchmark of a markdown knowledge graph as agent memory (LOCOMO, HotPotQA) with Claude Code | 3 | push 2026-07-19 | none stated | **Tree, Bench.** On sealed LOCOMO data, grep over raw transcripts (0.812) beat grep over curated notes (0.764); the graph won on cost, not accuracy. A ready-made reason to gate any lessons graph behind the routing bench. Conversational recall, not coding. No licence, so read only. | WATCH |

---

## 3. Start here: top 10, in order

**[ANALYSIS]** This ordering is the author's recommendation.

1. **walkinglabs/learn-harness-engineering (L13 and L14 plus the Claude Code and Codex breakdowns).** It gives you the vocabulary (instructions, tools, environment, state, feedback; loop → graph) to check Odin, Gleipnir and Jormungandr against.
2. **Anthropic, "Effective harnesses for long-running agents" and "Harness design for long-running application development"** (non-OSS but essential). The planner → generator → Playwright-evaluator pattern *is* your web-realm loop. The feature-list JSON where only `passes` can change is the model for loop caps and honesty.
3. **mini-swe-agent.** Read all of it in an hour, then make it Bench's control baseline, so every Odin graph has to beat it.
4. **openai/codex crates (`exec`, `app-server-protocol`, `execpolicy`, `linux-sandbox`, `network-proxy`).** The most complete open reference for a headless protocol plus a policy engine plus a sandbox, which is all of Gleipnir.
5. **gastownhall/gascity, then gastown (Refinery, Witness).** Go code for reconcile-loop orchestration, merge queues and stuck-agent detection, at the scale you are aiming for.
6. **harbor-framework/harbor plus terminal-bench-2 tasks.** Adopt or align with its task format and agent adapters, so your hidden suites are portable and comparable.
7. **Temporal concepts plus dbos-transact-golang.** Event-sourced, replayable run history and durable steps in Go. Odin's crash-safety model and gate signals come from here.
8. **Aider repo-map, then graphify, then codebase-memory-mcp.** Three levels of the routing index: PageRank tags, an explained graph with confidence tags, and impact analysis with cross-service wiring.
9. **github/spec-kit, compared with Fission-AI/OpenSpec.** Keep Spec Kit for greenfield features, and borrow OpenSpec's change-delta model for brownfield leaves.
10. **EricTechPro/super-board's merge gate, plus anthropics/sandbox-runtime.** One closes the "green PR, red base" gap. The other adds the egress allowlist that rootless Podman alone does not give you.

---

## 4. Key non-OSS reading (8)

The "Why it matters" column is **[ANALYSIS]**.

| # | Reading | Date | Why it matters to the OSS list |
|---|---|---|---|
| 1 | Anthropic, [Building effective agents](https://www.anthropic.com/research/building-effective-agents) | 2024-12-19 | The five workflow patterns (chaining, routing, parallelization, orchestrator-workers, evaluator-optimizer) are the node types Odin composes. |
| 2 | Anthropic, [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 2025-09-29 | Just-in-time context, compaction and sub-agents. This is the reason for the routing indexes. |
| 3 | Anthropic, [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) | 2025-11-26 | Initializer agent, feature list JSON, one feature per session, browser E2E checks. |
| 4 | Anthropic, [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) | 2026-03-24 | Planner / generator / skeptical evaluator with Playwright. Also: drop harness parts as models improve (about $200 vs $9 per run). |
| 5 | Anthropic, [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) | 2026-01-09 | Capability vs regression evals, pass@k vs pass^k, grade transcript *and* outcome, start with 20–50 tasks from real failures. This is the design brief for Bench. |
| 6 | OpenAI, [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/index/harness-engineering/) | 2026 (the page returned 403 to automated fetch; it is cited as a core reference by walkinglabs) | Repo as source of truth, AGENTS.md as a table of contents, mechanical enforcement of architecture. |
| 7 | Geoffrey Huntley, [Ralph Wiggum as a "software engineer"](https://ghuntley.com/ralph/) | 2025-07-14 | Origin of every Ralph repo above. "Backpressure" (tests, types, lints) as the loop governor. The author warns against using it on existing codebases. |
| 8 | Steve Yegge's Gas Town series on [Medium](https://steve-yegge.medium.com/) ("Welcome to Gas Town", Jan 2026; "Gas Town: from Clown Show to v1.0", 2026-04-03; "Welcome to Gas City") | 2026 | Design reasoning behind Gas Town, Beads and Gas City. It is frank about what failed at 20–30 agents. |

---

## 5. Licence quick-reference (borrowing ideas vs code)

**[ANALYSIS]** This grouping is the author's reading of each licence.

- **Safe to copy code (permissive):** MIT, Apache-2.0, CC0. This covers most entries.
- **Read only. Copying code makes your project inherit the terms:** claude-squad (AGPL-3.0), serena app (GPL-3.0+), cmux (GPL-3.0+), Daytona (AGPL-3.0).
- **Source-available. Do not embed in an OSS factory others may host:** crush (FSL-1.1, converts to MIT after 2 years), Phoenix (ELv2), Restate (BSL 1.1), Inngest (SSPL), claude-task-master (Commons Clause), langfuse `ee/` folders.
- **No licence, so all rights reserved (read only):** anthropics/claude-code, disler repos, polyglot-benchmark, Gut (no SPDX detected; check the file), iwe-org/memory-bench.
- **Content you may not adapt:** awesome-claude-code (CC BY-NC-ND).

**What goes wrong if you ignore this [ANALYSIS]:** copy a 200-line AGPL helper from claude-squad into Gleipnir, and anyone who runs Yggdrasil as a hosted service must publish their full source under AGPL. That can block every company that would otherwise adopt it. Removing the code later means a clean-room rewrite plus a history audit.
