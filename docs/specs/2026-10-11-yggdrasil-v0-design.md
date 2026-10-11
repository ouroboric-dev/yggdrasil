# Yggdrasil v0 — design spec

| | |
|---|---|
| **Status** | Draft for review |
| **Date** | 2026-10-11 |
| **Author** | Bruno Valério, with Claude Code (Opus 5.5), from a brainstorming session held 2026-10-10 and 2026-10-11 |
| **Scope** | Spec 1 of 3: the factory core, the web realm and metrics. Spec 2 is the game realm; spec 3 is the benchmark kit (Mimir) |
| **Research** | [`docs/research/`](../research/): harness engineering, loops/graphs/factories, orchestrator stack, web stack, hosting |
| **Naming** | [`docs/naming-and-mythology.md`](../naming-and-mythology.md) |

## 1. Summary

Yggdrasil is a software factory: a Go program that turns a written brief into working, verified
software by running coding agents (Claude Code, OpenCode and others) inside sandboxes. It runs them
through a graph of steps, with loops that check and fix work and approval points where a human
decides. It is built to **learn the discipline** of harness, loop and graph engineering. Shipping
real products and benchmarking the factory against other factories are how success is measured.

v0 builds the core (Odin, Gleipnir, Jormungandr, Gungnir), one domain recipe (the web realm), and
the metrics needed to compare runs. It proves itself by building **client gallery lite**, a small
Pixieset-style SaaS, from a one-page brief, at least once with a different model or agent tool.

## 2. Goals, non-goals and success criteria

### 2.1 Goals

- Learn harness, loop and graph engineering by building them, not by adopting a framework.
- No lock-in: models, agent CLIs, sandboxes, state stores, git remotes and trackers are swappable.
- Modularity: a factory is a composition of components that honour the Gungnir contract, so
  specialised factories can be assembled per use case.
- Measurable: every run produces metrics usable as benchmarks against other runs and other
  factories.
- Safe by default: agents run sandboxed with no access to secrets they don't need, and a few
  approval points can never be switched off.
- Shareable journey: the project will eventually be promoted through a blog or a series of posts
  that walks readers through the learning journey and the factory-building process. From v0 on, the
  factory keeps the raw material for that: a journal of challenges, the solutions tried and their
  measured results (§13.5).

### 2.2 Non-goals for v0

- Parallel agents (features run one at a time).
- A dashboard or terminal UI (v0 has a live status view and a board command).
- Pushing to GitHub, bot identities and the GitHub tracker (specified here, built in iteration 2).
- Production deployment (the web realm is deploy-ready; deploying is outside v0).
- The game realm (spec 2) and the full benchmark kit (spec 3).
- Mobile.
- Promotion and content: no posts, no blog, no content-generation component (future module Bragi).
  v0 only keeps the journal those will be written from.

### 2.3 v0 success criteria

1. The factory builds **client gallery lite** from its frozen brief, and the result passes rungs 1–6
   of the check ladder (§12.5). The hidden suite (rung 7) is run and its score recorded; v0 sets no
   pass threshold, because the score is a benchmark result, not a gate.
2. The same brief is built at least once with a different agent tool or model for at least one role,
   for example the implementer on OpenCode with an OpenRouter model.
3. Every run produces a complete, hash-chained ledger, and `ygg metrics` reports the metrics in §13.2,
   including the hidden acceptance score.
4. All three autonomy modes (§10) complete a run with the `scripted` adapter, and at least one
   real-agent run completes in key-points mode.
5. The escape-attempt tests (§16) pass.
6. Every significant challenge met during v0 has a journal entry (§13.5) with its evidence links, and
   every factory change made in response to a run cites before/after runs from `ygg metrics --compare`.

## 3. Context and constraints

- **Purpose:** learning comes first. The operator expects several iterations before output quality
  is high, and wants eventually to build factories specialised per use case.
- **Targets:** web SaaS first (this spec), browser games next (spec 2), mobile later.
- **Models:** start on a Claude subscription; OpenRouter and other providers must work through the
  same adapters.
- **Runtime:** local first (WSL2, rootless Podman), cloud later. Cloud readiness comes from the
  swappable interfaces, not from the language.
- **Language:** Go for all factory code.
- **Open source:** the factory will become open source. Products it builds may be public or
  private, at the operator's choice, and hosted anywhere (GitHub first).

## 4. Naming and repository layout

Names follow [`naming-and-mythology.md`](../naming-and-mythology.md). The factory's source code is an
umbrella of repos in the `ouroboric-dev` GitHub org:

| Repo | Role |
|---|---|
| `yggdrasil` | umbrella: AGENTS.md, docs (specs, research, naming), `go.work`, submodule pointers. Holds no code |
| `gungnir` | the contract: Go interface types and JSON schemas (ledger events, `graph.yaml`, `pack.yaml`, `factory.yaml`) |
| `odin` | the orchestrator: graph engine and the `ygg` CLI. Routing (§11) and the ledger (§13) start as packages here |
| `gleipnir` | the harness: agent adapters, the devcontainer sandbox driver, policies, the check runner |
| `jormungandr` | the loop: build→check→fix semantics, attempts, backoff, budgets, feedback, escalation |
| `realm-web` | the web realm: graph, prompts, devcontainer stack layer, templates, checks |

All modules are developed together through a Go workspace (`go.work`) in the umbrella. Versions are
tagged only when an interface settles. Interfaces live only in `gungnir`, so an interface change is
one PR in `gungnir` plus the affected components.

This source umbrella is not the operator's instance. Each operator has a private **instance
umbrella** (L0, §6) that pins a Yggdrasil version and lists their projects.

## 5. Architecture

```
                 ygg CLI  (run · resume · approve · reject · status · board · report · metrics · doctor)
                                   │
                         ┌─────────▼──────────┐
 realm (web, game…) ───► │  Odin graph engine │ ◄── factory.yaml (mode, caps, roles, privacy)
 graph.yaml, prompts,    │ exec · agent ·     │
 checks, templates       │ loop · gate nodes  │
                         └──┬────┬────┬────┬──┘
              Agent (Gleipnir) Sandbox  StateStore  Remote / Tracker
              claude-code     devcontainer files+git  local (v0)
              opencode        (k8s, hosted later)     github (iteration 2)
              scripted (tests)
                                   │
              instance tree: L0 → L1 project umbrella → L2 leaf repos
```

### 5.1 Component responsibilities

| Component | Does | Depends on |
|---|---|---|
| **Odin** | loads realm graphs and `factory.yaml`; walks the graph; runs exec, agent, loop and gate nodes; checkpoints and resumes; walks the repo tree and moves pointers; writes the ledger; serves the CLI | Gungnir interfaces |
| **Gleipnir** | turns a task into an agent session (context assembly, adapter call, usage capture); runs commands in sandboxes; applies policies (devcontainer hardening, managed settings, firewall); runs checks | Gungnir; Podman and the devcontainer CLI on the host |
| **Jormungandr** | runs a bounded loop: implement → check ladder → feed failures back → retry, up to N attempts; then escalates; enforces per-loop budgets | Gungnir; called by Odin |
| **Gungnir** | defines the interfaces and schemas; validates configs | nothing |
| **realm-web** | the web recipe (§12) | Gungnir schemas |

### 5.2 Core interfaces (Gungnir)

```go
type Agent interface {
    Name() string
    Run(ctx context.Context, t Task) (Result, error)
}
// Task:   role, prompt, workdir, model, readOnly, maxTurns, timeout, envAllowlist
// Result: status, summary, usage{inTok, outTok, cacheTok, turns, costUSD, costEstimated}, transcriptPath

type Sandbox interface {
    Up(ctx context.Context, spec SandboxSpec) (Env, error)  // spec: leaf path, config path, services
    Exec(ctx context.Context, env Env, cmd Cmd) (ExecResult, error)
    Down(ctx context.Context, env Env) error                // stops everything, kills process groups
}

type StateStore interface { /* run.json, features.json, gate files, ledger append */ }
type Remote     interface { /* commit, branch, push, open PR, merge, move pointer */ }
type Tracker    interface { /* project issues/milestones/board from factory state */ }
```

The exact method sets are settled in the implementation plan. These are the boundaries.

## 6. Repository topology and isolation

### 6.1 The instance tree

The operator's instance is a **tree of nodes**. Each node is either:

- an **umbrella**: has children, holds no product code; or
- a **leaf**: product code; the only thing an agent ever mounts.

```
L0  instance umbrella (private, per operator)
    ├─ yggdrasil/          (submodule: pinned factory version)
    ├─ benchmarks/         (submodule, PRIVATE: frozen briefs + hidden suites)
    ├─ docs/
    └─ projects/<name>/    (submodules → L1, in any org)
L1  project umbrella
    ├─ AGENTS.md, docs/ (brief, spec.md, plan.md, tasks.md), REPOS.md (routing)
    ├─ .factory/ (features.json authoritative; runs/<id>/{run.json, ledger.jsonl, gates/, report.md})
    ├─ acceptance/ (cross-repo end-to-end tests)
    └─ repos/<name>/       (submodules → leaves)
L2  leaf repos (e.g. api, web)
```

Deeper trees are allowed: an umbrella's child may be another umbrella. The engine walks the tree
recursively and never assumes a fixed depth. v0 projects use L0→L1→L2, and a test fixture with an
extra umbrella level proves deeper trees work. Add a level only when a subtree has its own contract
and its own acceptance tests.

Every node records `owner` (org or account) and `visibility`. Visibility and hosting are the
operator's choice per project. The factory only applies the consequences: no secrets or hidden tests
in any repo, and an operator warning if a public L0 lists private projects (their names leak through
`.gitmodules`).

### 6.2 Per-umbrella responsibilities

| Each umbrella owns | for |
|---|---|
| `AGENTS.md` invariants | its subtree; children may tighten them, never loosen them |
| routing for its direct children | a generated `REPOS.md` and a routing bundle (§11) |
| integration and acceptance tests | contracts between its children, run at their pinned SHAs |
| pointer gates | moving a child's pointer only after its tests pass |

### 6.3 Isolation rules

1. **Agents never mount an umbrella.** An implementer mounts one leaf. A planner gets a scratch
   directory with the brief; Odin commits its output into L1 after the `spec` approval point.
2. **Odin is the only writer** of umbrellas, `features.json` (agents get a read-only copy refreshed
   before each session, and their edits are ignored), the ledger, gate files and reports.
3. **Agents don't commit.** Odin commits at checkpoints, from the host.
4. **Leaf git data is out of reach.** A leaf's git directory lives in its parent's
   `.git/modules/<name>/`. At most it is mounted read-only (so agents can read `git log` and
   `git diff`).
5. **Host git runs with hooks disabled** (`-c core.hooksPath=/dev/null`), and never runs
   `submodule update --recursive` inside a leaf.
6. **Path-only checkout:** Odin initialises only the submodules on the path from the root to the
   target leaf, never `--recursive` from L0.

### 6.4 Pointer moves are the validation record

A pointer move in an umbrella means "this child, at this SHA, passed this level's checks". Rules:

- One level per move; each move requires that level's own tests to pass.
- A move that changes a contract (per the impact index, §11) is the `pointer-contract` approval
  point.
- A move never propagates automatically more than one level in a single step, unless the operator
  raises that limit explicitly.
- Pointers are never auto-merged by a sync job.

## 7. Run execution

### 7.1 Starting a run

`ygg run --project <path> --realm web --brief <brief.md> [--mode …]`:

1. Resolve the project's L1 umbrella; create its leaves from the realm templates if they don't exist.
2. Write `run.json`: run id, realm and graph version, config hash, agent and model per role, graph
   position.
3. Bring up sandboxes per leaf (§9) and start walking the graph.

### 7.2 The web realm graph

```
plan ─► DoR check ─► [gate: spec] ─► init ─► [gate: plan] ─► for each ready task:
agent     exec                       agent+exec               implement ⇄ check ladder  (loop, max N)
                                                              └─► checkpoint ─► [gate: feature] ─► [gate: merge]
                                                              ─► pointer move ─► [gate: pointer | pointer-contract]
                                     ─► final acceptance (hidden suite) ─► report
```

- **plan** (agent): writes Spec Kit-layout artifacts (`spec.md`, `plan.md`, `tasks.md`; constitution
  principles go into `AGENTS.md`), with decisions recorded as `**Decided YYYY-MM-DD:** …` lines.
  Odin derives `features.json` from `tasks.md`.
- **DoR check** (exec): every task must have acceptance criteria, a named test, a `layer/*` (which
  leaf) and a size (S < 100 changed lines, M 100–400, L means split: back to the planner), and no open
  blocker.
- **init** (agent + exec): scaffolds leaves from templates, writes `init.sh` and a short `AGENTS.md`
  (about 100 lines, pointing into `docs/`), first commit.
- **implement ⇄ check ladder** (Jormungandr loop): one fresh agent session per task; the ladder (§12.5)
  runs as exec nodes plus two read-only reviewer agents; failures go back into the next attempt;
  after N attempts (default 3) it escalates (§10.3).

### 7.3 Checkpoints and resume

- After each node, Odin commits the workspace and records the node as done in `run.json` and the
  ledger. A checkpoint is a commit plus a state line.
- `ygg resume <run-id>` resets the leaf to the last checkpoint commit and restarts the interrupted
  node from scratch. Nodes are designed to be safe to re-run.
- Mid-session resume is not attempted; agent sessions are not reliably resumable across vendors.
- Odin refuses to run on anything outside the instance tree, because a reset discards uncommitted
  work.

### 7.4 Fresh context per session

Every agent session starts clean and reads `AGENTS.md`, `progress.md`, the current task from its
read-only `features.json` and the routing summary (§11). Nothing depends on one vendor's session
memory, which is what makes swapping models mid-run possible.

## 8. Agent adapters (Gleipnir)

v0 ships three adapters:

| Adapter | Invokes | Notes |
|---|---|---|
| `claude-code` | `claude -p` with streaming JSON output | read-only roles get read/search tools only |
| `opencode` | `opencode run` | OpenRouter models; proves the swap |
| `scripted` | replays canned actions | tests only (§16) |

Roles map to agents in `factory.yaml`:

```yaml
mode: key-points
roles:
  planner:          { agent: claude-code, model: opus }
  implementer:      { agent: claude-code, model: sonnet }
  reviewer-spec:    { agent: opencode,    model: openrouter/<another-vendor> }
  reviewer-quality: { agent: opencode,    model: openrouter/<another-vendor> }
budget: { per_run: { tokens: 20000000, turns: 2000 }, per_day: { tokens: 40000000 } }  # example values
privacy: standard   # strict → only providers with no training and no retention
```

- **Usage:** tokens and turns are the primary benchmark numbers. On a subscription, reported cost is
  what the run would cost on the API. When a CLI reports only tokens, the adapter estimates cost from
  a price table and sets `costEstimated: true`.
- **Privacy:** `privacy: strict` restricts the OpenRouter adapter to providers with no training and no
  retention through OpenRouter's provider data-policy settings (exact options verified when the
  adapter is built). Policy tightens only, going down: factory defaults → L0 → L1 → leaf.

## 9. Sandbox (Gleipnir devcontainer driver)

### 9.1 How it works

- The driver uses the devcontainer CLI with Podman (`devcontainer up --docker-path podman`, then
  `devcontainer exec`). The host needs only Podman, the devcontainer CLI and the `ygg` binary.
- One rootless container per leaf per run, plus the realm's services (§12.3) via compose.
- **Two layers per image:** the realm's stack layer, and the factory layer (agent CLIs pinned to exact
  versions with auto-update off, `/etc/claude-code/managed-settings.json`, an egress firewall adapted
  from Anthropic's reference `init-firewall.sh`, a non-root user).
- Each leaf also gets a clean `.devcontainer/` with only the stack, so a human can open it in an
  editor.

### 9.2 Hardening

- **Factory-owned config:** the hardened devcontainer config lives outside the leaf, is passed with
  `--config`, and is never mounted. Before every `up`, Odin refuses a config containing
  `initializeCommand` (it runs on the host), extra mounts, `--privileged`, or a container-engine socket.
- **Mounts:** only the leaf working tree (and its git directory read-only, §6.3). No home directory,
  no `~/.ssh`, no `~/.aws`, no Podman socket.
- **Egress:** default deny; allowlist for the model APIs and package registries the realm needs.
- **Repo-level agent config:** managed settings block repo hooks and project MCP servers. (Open
  item: whether `claude -p --bare` works with subscription auth, §19.)
- **Shutdown:** cancelling kills the exec's process group and stops the containers; `ygg doctor`
  finds leftovers.

### 9.3 Credentials

- A model credential must be in the sandbox, so it is dedicated and revocable: a
  `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token` passed as an environment variable, and a separate
  OpenRouter key with a hard credit limit. Never the operator's main login files.
- No git or GitHub credentials in any sandbox. Odin does all git operations from the host.

## 10. Approval points and autonomy modes

### 10.1 The approval points

| Approval point | When | step-by-step | key-points (default) | unattended |
|---|---|---|---|---|
| `spec` | planner output passed DoR | stop | stop | auto |
| `plan` | init done | stop | stop | auto |
| `feature` | a task passed its loop | stop | auto | auto |
| `merge` | feature branch → leaf `main` | stop | stop | auto |
| `pointer` | umbrella pointer move, no contract change | stop | auto | auto |
| `pointer-contract` | pointer move that changes a contract | stop | stop | auto |
| **hard** (below) | — | stop | stop | **stop** |

Hard approval points: `deploy-prod`, `store-submit`, `real-secrets-or-user-data`, `budget-cap`,
`external-input` (work not from a human-approved source), `policy-violation` (sandbox rule broken or
config tampered with), `shrink-guard` (§11.3).

### 10.2 Mechanics

- **Stop:** Odin writes `gates/<name>.md` (what happened, diff, check results, cost so far), logs
  `gate_pending`, saves state and exits. Approvals can wait for days.
- **Decide:** `ygg approve <run> <gate> [--note …]` continues. `ygg reject <run> <gate> --reason …`
  sends the reason back into the previous node as input.
- **Auto-pass:** still writes the gate file and logs `gate_auto_passed`, so unattended decisions can
  be audited.
- **Config:** `mode:` in `factory.yaml`, overridable per run with `--mode`; per-gate overrides such as
  `gates: { plan: stop }`. A config that tries to override a hard approval point is rejected at
  startup. Mode switches are allowed at any pause; a switch to a looser mode is logged.
- **Metrics:** rejections, approvals with notes and escalations count as interventions. Time waiting
  at approval points is recorded separately and excluded from factory time.

### 10.3 Exhausted loops

- step-by-step and key-points: stop and ask.
- unattended: mark the task `blocked`, continue with tasks that don't depend on it, list it first in
  the run report.

### 10.4 Budget cap

Per run and per day, in tokens and turns (dollars on the API). Hitting a cap stops the run with
everything resumable. It is a hard approval point because the operator's subscription is shared with
their daily work: a flaky check that keeps re-running the implementer would otherwise burn the weekly
quota overnight.

## 11. Routing (package in Odin; future module Ratatoskr)

Following marola's
[MIP-0084](https://github.com/marola-dev/marola/blob/main/docs/MIPs/MIP-0084-zero-setup-routing.md) and
[MIP-0085](https://github.com/marola-dev/marola/blob/main/docs/MIPs/MIP-0085-routing-index-family.md).

### 11.1 Bundles and descent

- Each umbrella has a **routing bundle**: a set of indexes over its direct children, built by
  deterministic exec nodes (no model calls), stored outside the agent's mount.
- Routing is hierarchical: Odin reads the root's bundle, picks a child, reads that child's bundle,
  and so on. Each hop reads a small table.
- Agents need no setup: Odin injects a short routing summary into each session's context.

### 11.2 v0 indexes

| Index | Answers | Used by |
|---|---|---|
| wiring / contracts | who produces, consumes or pins each artifact or contract file (`REPOS.md` block) | Odin, agents |
| impact | what a change to a file or contract affects (reverse references + contract readers); always labelled "lower bound" | Odin: which acceptance tests run, and whether a pointer move is `pointer-contract` |
| doc↔code | which code implements which task or acceptance criterion, and the reverse | spec-compliance reviewer |
| decisions | `**Decided …**` lines from spec and plan, ranked by BM25 (`route why`) | planner, implementer |

Symbol and meaning indexes come later, each only if it beats the bench.

### 11.3 Measurement and guards

- **Bench:** each project umbrella has a routing bench (questions with expected answers). An index
  ships only if it raises the right-first score; new questions come from misses recorded in the
  ledger.
- **Usage:** the ledger counts routing lookups vs grep per session.
- **Shrink guard:** any generated file committed at a pointer move (indexes, `REPOS.md`) is refused
  if it has fewer than 50% of the previous version's rows. That stops the move for a person.
- **Model files** (if a meaning index ever ships): pinned by hash, loaded only as `safetensors`.

## 12. The web realm

### 12.1 Benchmark brief #1: client gallery lite

A Pixieset Client Gallery–style SaaS.

- **Photographer:** sign up and log in; create galleries; upload many large photos (resumable, sent
  straight to storage); thumbnails and web sizes; cover photo; per-gallery password, download PIN and
  downloads on/off.
- **Client:** opens a private link; enters the password if set; responsive grid and full-screen
  viewer; favourites (no account, identified by email); single downloads (PIN if set) and
  download-all as a zip.
- **Photographer dashboard:** each client's favourites and download activity (who downloaded what,
  when).
- **Out of scope:** watermarks, comments, branding themes, video, translations, Lightroom sync, print
  store and payments, email campaigns.

### 12.2 Stack

| Leaf | Stack |
|---|---|
| `api` | Go `net/http` (deployable with Vercel's Go preset; listens on `PORT`), sqlc, Postgres. Owns `openapi.yaml` |
| `web` | React, Vite, TypeScript, Tailwind, shadcn/ui, TanStack Router and Query; Uppy for presigned resumable uploads; API client generated from `openapi.yaml` |

A consumer never builds its producer from source: Odin builds `api` at the SHA pinned in L1 and runs
it as a read-only service in `web`'s sandbox.

### 12.3 Infrastructure target

| Concern | Development (in the sandbox) | Production target (deployment is outside v0) |
|---|---|---|
| Web | Vite dev server | Vercel (static build) |
| API | Go server | Vercel Go preset (beta) |
| Database | Postgres container | Neon (free tier; suspends when idle, keeps data) |
| Photos | SeaweedFS (S3 API) | Cloudflare R2 (no egress fees) |

Design rules:

- **Photo bytes never pass through the API or Vercel.** Viewing and downloads use short-lived
  presigned URLs. Download-all zips are built in the browser from presigned URLs and streamed to disk,
  falling back to per-photo downloads in browsers that can't stream.
- **Thumbnails are generated in the browser at upload time.** The server never decodes images. It
  accepts JPEG and WebP only, enforces size and pixel limits, and serves derivatives from the storage
  domain with fixed content types. Originals are stored untouched.
- **The server builds every storage key** from the logged-in user and gallery; client-supplied keys
  are ignored.
- **Previews never see production:** production secrets exist only in Vercel's Production
  environment; previews use a Neon preview branch and a separate R2 bucket with separate keys.
  Promotion to production is the `deploy-prod` hard approval point.
- **Storage keys:** bucket-scoped, with object versioning on.

### 12.4 Pack layout

```
realm-web/
  pack.yaml        name, version, default roles/models, check commands
  graph.yaml       the graph in §7.2
  prompts/         planner, initializer, implementer, reviewer-spec, reviewer-quality
  devcontainer/    stack layer (Dockerfile, devcontainer.json, compose services)
  templates/       api and web leaf starters: lint/test/e2e config, AGENTS.md, init.sh
  checks/          the check ladder scripts
```

### 12.5 The check ladder

Fast to slow; each rung's failure output goes back to the implementer.

1. **Static:** gofmt, golangci-lint, go vet; eslint, tsc.
2. **Unit tests + TDD check:** new tests must fail on the parent commit.
3. **Contract:** OpenAPI lint; generated client up to date; `oasdiff` breaking-change detection
   (feeds the impact index and `pointer-contract`).
4. **Security:**
   - `gitleaks` before every checkpoint commit;
   - `govulncheck`, `npm audit`;
   - **two-tenant authorisation harness**: every OpenAPI route that takes a resource ID must have a
     registered test where user B requests user A's resource and gets 403/404, including "a client of
     gallery A can't open gallery B";
   - client-supplied storage keys are ignored;
   - the bucket refuses anonymous reads; signed URLs expire;
   - web-size images carry no GPS EXIF data; oversized ("decompression bomb") images are rejected;
   - PIN attempts are rate-limited.
5. **End-to-end:** Playwright against the running app, one spec per acceptance criterion (written by
   the implementer, visible to it).
6. **Reviewers** (read-only agents): spec compliance (using doc↔code and `tasks.md`), then code
   quality.
7. **Final acceptance at L1:** the hidden benchmark suite (§14), run by Odin, results to the ledger
   only, never to agents. It includes gallery ID enumeration attempts.

### 12.6 Dependency policy (all realms)

- Pin the minor version line with a minimum patched version.
- Gate on `govulncheck` and OSV.
- Roll version bumps to one canary product first, run its suite, then roll out in batches.
- Never rely on middleware alone for authorisation.

## 13. Observability (packages in Odin; future module Norns)

### 13.1 The ledger

- One append-only JSONL file per run in `L1/.factory/runs/<id>/ledger.jsonl`, written only by Odin,
  schema-versioned, flushed to disk per line.
- Each line: time, run, node, event, attempt, agent (adapter, model, CLI version), usage, duration,
  result, refs (commit SHA, gate file), and the hash of the previous line (tamper-evident).
- Events: run and node start/finish, check results, approval points (pending, approved, rejected,
  auto-passed), loop attempts, escalations, routing lookups, budget warnings, policy violations,
  pointer moves.
- Field names follow OpenTelemetry's `gen_ai.*` conventions, so an OTel exporter is a mapping.

### 13.2 Metrics (`ygg metrics <run|range>`)

Tokens, turns and cost per task and run; wall time excluding approval waits; first-pass rate;
average loop attempts; reviewer veto rate; interventions; escalations and blocked tasks; hidden
acceptance score; escaped defects (hidden tests failing where visible tests passed); routing usage and
bench right-first score.

`ygg metrics --compare <runA> <runB>` prints the deltas between two runs, along with what differed
between them (factory version, config hash, agents and models per role, realm version). This is the
"result" evidence for journal entries. Every run report records the factory version and config hash,
so any number quoted later can be traced back to the exact setup that produced it.

### 13.3 Progress views

- **Live:** `ygg status --watch` (current node, loop attempt, cost so far).
- **Backlog:** `ygg board` — a terminal kanban per project (Ready, In progress, Verifying, Blocked,
  Needs you, Done) built from `features.json` and the ledger; `ygg board --all` across projects.
- **History:** `ygg report <run>` writes `report.md` into the run directory in L1, committed.

### 13.4 Tracker model

The `Tracker` interface projects factory state one way, following marola's
[MIP-0063](https://github.com/marola-dev/marola/blob/main/docs/MIPs/MIP-0063-github-issue-tracking-standard.md):

- milestone = a project deliverable (one brief); issue = a task; sub-issues mirror the repo tree
  (GitHub's 8-level cap bounds tree depth for tracking);
- issues own status, files own the plan; Odin is the only writer; agents never touch issues;
- the only inputs read back: human-approved work (through `external-input`), and later approvals;
- board views: Needs you, Now, Agent queue, Blocked, Triage;
- boards are per product org; the factory's own org board tracks improving the factory itself.

v0 ships the `local` tracker (the views above). The `github` tracker is iteration 2 (§18).

### 13.5 Journey journal

The journal is the source material for later promotion. In the story, its entries are the **sagas**,
and the future content component that turns them into posts is **Bragi**, the god of poetry.

- **Where:** `docs/journal/` in the `yggdrasil` umbrella for the factory's own journey, with an index
  in `docs/journal/README.md`. Lessons from private product runs are recorded in the private L0
  instance first, and only distilled, anonymised versions move to the public journal.
- **One entry per challenge:** `docs/journal/YYYY-MM-DD-<slug>.md`, from a template:

  ```markdown
  ---
  date: 2026-10-11
  tags: [harness, loop, graph, routing, security, cost, naming, …]
  status: open | resolved | abandoned
  post-candidate: yes | no
  evidence: [run ids, commits, spec sections, research briefs]
  ---
  ## Challenge      what went wrong or what had to be decided
  ## Context        what we knew, constraints
  ## Options        what we considered, with trade-offs
  ## Decision       what we chose and why
  ## Result         measured outcome: metrics deltas (`ygg metrics --compare`), or "pending"
  ## Lessons        what we would tell someone building their own factory
  ```

- **When:** at every design decision, every surprising failure, every harness change made in
  response to a run, and every benchmark milestone. Entries with `status: open` are updated when the
  result arrives; a decision whose result is still pending is worth recording at once.
- **Seed:** the first entries come from the design sessions of 2026-10-10 and 2026-10-11 (the decision
  log in §21 and the research briefs), with results marked pending.
- **Scrubbing before anything is public:** the journal lives in a repo that will be public, and a
  blog post is effectively permanent (search engines and archives keep copies). Entries never include
  secrets, private product names or code, client data, or raw transcripts and ledger excerpts from
  private runs. Example: a pasted ledger line that shows an OpenRouter key, or a client's private
  gallery URL, would stay readable in archives long after the post is edited. Private evidence is
  linked from L0, and only aggregate numbers are quoted publicly. `gitleaks` runs on the umbrella like
  any other repo.

## 14. Benchmark format (full kit in spec 3)

```
benchmarks/<brief-id>/
  benchmark.yaml   id, version, budget and time limits, scoring weights
  brief.md         frozen; any change is a new version
  hidden/          black-box Playwright suite + fixtures, run against a URL
  rubric.md        optional human-judged items
```

- Black-box only: hidden tests use what the brief describes (UI and public API), so any factory's
  output can be scored.
- Output: `score.json` (pass/fail per scenario, by category) joined with the run's metrics.
- Hidden suites live in a private submodule of L0, never in a public repo: published tests leak to
  other factories and eventually into model training data.
- The v0 hidden suite for client gallery lite is written before the first factory run, from the brief
  alone, by the operator (optionally with a separate agent session that never sees factory runs or
  their code).

## 15. Error handling

| Failure | Response |
|---|---|
| Transient (HTTP 429, network, CLI crash at start) | retry with backoff, up to 3 times; not a loop attempt |
| Provider quota exhausted | pause the run, resumable, reason recorded |
| Agent failure (non-zero exit, timeout, malformed output) | counts as a loop attempt |
| Check failure | output fed back into the loop |
| Infra failure (sandbox won't start) | stop the run; no retry loop |
| Policy violation | hard stop and quarantine: workspace kept for investigation, never auto-resumed |

`run.json` is written atomically (temp file, then rename). `ygg doctor` finds and stops orphaned
containers and processes.

## 16. Testing the factory

- **Unit tests** (Go): graph traversal; the mode × approval-point table; config validation rejecting
  hard-gate overrides; pointer propagation over tree fixtures, including the deeper-tree fixture; DoR
  check; shrink guard; ledger hash chain.
- **Deterministic end-to-end:** the `scripted` adapter runs whole graphs with zero model cost; this is
  what CI runs.
- **Escape-attempt tests:** a scripted agent tries to write `.git/hooks/pre-commit`, add
  `initializeCommand` to the devcontainer config, edit `features.json` or the ledger, add a nested
  submodule with a malicious URL, and read `~/.ssh`. Each test asserts Odin blocks or ignores it.
- **Smoke run:** a one-feature brief with real agents, run before benchmark runs and after any model
  or CLI version bump.
- **Integration tests** for the devcontainer driver behind a build tag.
- Each factory repo has a Go devcontainer and a short `AGENTS.md`, and is built test-first.

## 17. Security model

The adversaries are named in the [naming record](../naming-and-mythology.md#the-adversaries):
**Loki** (prompt injection), **Nidhogg** (entropy), **Ragnarok** (the cascade).

| Threat | Example | Control |
|---|---|---|
| Prompt injection steals credentials (Loki) | a poisoned README makes the agent post `~/.aws` to a server | sandbox with no home mount, egress allowlist, dedicated revocable model tokens, no git credentials in sandboxes |
| Sandbox escape through config | agent adds `initializeCommand` to `devcontainer.json`; next `up` runs it on the host | factory-owned config outside the mount, validated before every `up` |
| Sandbox escape through git | agent plants `.git/hooks/pre-commit`; host commit runs it | git dir out of the mount or read-only; host git with hooks disabled |
| Gamed metrics | agent marks its own task passing or edits the ledger | Odin sole writer; read-only copies; hash-chained ledger |
| Gamed tests | agent writes `return true` to pass visible tests | TDD-fails-on-parent check, reviewers, hidden suite never shown to agents |
| Data leak that passes tests | endpoint returns other tenants' data | mechanical two-tenant authorisation harness |
| Leaked secrets in history | `.env` with a live key committed | `gitleaks` before every checkpoint commit |
| Cascade through pointers (Ragnarok) | a bad contract change certified at every level | one level per move, `pointer-contract` approval point, no auto-merge |
| Cascade through generated files | a buggy generator empties an index, every move merges the loss | shrink guard |
| Cascade through previews | an unreviewed branch's preview runs a migration on the production DB | preview/production separation of secrets, DB and bucket |
| Quota burn | a flaky check loops the implementer overnight | hard budget cap |
| Supply chain | a pinned framework version gets a critical CVE; every product inherits it | dependency policy (§12.6), canary rollout |
| Third-party skills | a compromised skill update reaches every run | vendored, pinned, reviewed copies only |
| Hidden-test leakage | public hidden tests end up in training data | private benchmark submodule |

## 18. Iteration 2 and later (specified, not built in v0)

### 18.1 GitHub remote and identities

- `Remote` implementation `github`. Agents hold no GitHub credentials; Odin pushes and opens PRs on
  their behalf.
- Two operator-owned GitHub Apps, created from a manifest shipped with the factory:
  `<operator>-pr-bot` (push branches, open PRs, comment; never lands on `main`) and
  `<operator>-merge-bot` (merges; the only bot in the ruleset bypass list). Installations are per org;
  optionally one App pair per product org.
- Rulesets on every `main`: PR required, checks required, one human approval; bypass for admins and
  the merge bot. External contributors always need a human review.
- Tokens minted per operation, limited to one repo and minimal permissions, valid one hour.
- Merges happen from the factory host, never from CI. The merge key never appears in a public repo's
  Actions (a `pull_request_target` workflow could expose it).
- Only human-approved work (an `agent-ready`-style label or the brief) becomes factory work
  (`external-input`).
- No automatic filing to the public factory repo from private runs.

### 18.2 GitHub tracker

The `github` Tracker per §13.4. Lessons carried from MIP-0063: sub-issue and dependency APIs take the
issue's database id, not its number; the board's built-in "item closed" workflow is unreliable, so a
sync step is the fallback; `Closes #N` must be in the squash-merge commit body. Approval from GitHub,
if added, accepts only the operator's account (author association), never comment text alone.

### 18.3 Other planned work

- Terminal UI (Bubble Tea); OpenTelemetry export.
- Next.js full-stack comparison realm on the same brief and hidden suite.
- Spec Kit as a swappable planning strategy, benchmarked against native planning.
- Symbol and meaning routing indexes (bench-gated).
- Parallel agents with concurrency caps.
- Deployment to Vercel / Neon / R2 behind `deploy-prod`.
- Game realm (spec 2), benchmark kit (spec 3), mobile.

## 19. Open items and first spike

The first implementation task is a throwaway spike that answers:

1. Does the devcontainer CLI work with rootless Podman for this setup: `--userns=keep-id` file
   ownership, compose services (Postgres, SeaweedFS), the egress firewall needing `NET_ADMIN`, and a
   read-only mount of a submodule's git directory?
2. Does `claude -p --bare` work with subscription auth? If not, do managed settings block repo hooks
   and project MCP servers well enough?
3. Which OpenRouter data-policy settings implement `privacy: strict`?

Fallback if (1) fails: a plain Podman sandbox driver behind the same interface.

## 20. Prior art

| Project | What we take |
|---|---|
| Anthropic, long-running agent harnesses | initializer vs coding sessions, progress files, JSON feature lists, browser verification, separate evaluators |
| OpenAI, harness engineering | short AGENTS.md as a map, mechanical enforcement, cleanup work against entropy |
| StrongDM software factory | hidden scenario tests, digital-twin services |
| Stripe blueprints | deterministic steps vs agent steps, capped CI rounds then a human |
| Gas Town (Go) | closest relative: an orchestrator over coding-agent CLIs; fan-out caps |
| MetaGPT, ChatDev | role pipelines and their known weaknesses; published metrics |
| Spec Kit | artifact layout (`spec.md`, `plan.md`, `tasks.md`) |
| Superpowers | fresh session per task, two-stage review, TDD, verification before completion |
| container-use | candidate future sandbox driver |
| OpenHands | candidate future agent adapter |
| marola (MIP-0063, 0070, 0076, 0084, 0085) | umbrella and polyrepo, pointer discipline, issue standard and DoR, routing bundles and index family, shrink guard |

## 21. Decision log

| Decision | Chosen | Main alternatives |
|---|---|---|
| Orchestrator approach | own orchestrator | LangGraph.js; Claude Code native features |
| Language | Go | TypeScript, Python, Rust, Elixir, Java + Pekko |
| Frameworks | none as core | CrewAI, LangGraph, AutoGen, ADK |
| Spec Kit / Superpowers | borrow now, plug in later | use live; nest as-is |
| Sandbox | devcontainer driver on rootless Podman | plain Podman |
| Topology | recursive umbrella/leaf tree | single workspace folder |
| Autonomy | three configurable modes, hard approval points | fixed mode |
| Visualisation | event stream + status view; TUI next | TUI or OTel in v0 |
| Web product stack | React/Vite + Go API | Next.js full-stack; Next.js + Go; TanStack Start; SvelteKit; Rails/Laravel; Supabase |
| Hosting target | Vercel + Neon + R2 | VPS + SQLite + R2; Cloud Run + Neon + R2 |
| Thumbnails | browser-side at upload | imgproxy; Go libvips worker |
| GitHub + identities | iteration 2 | in v0 |
| Factory repo layout | umbrella from day one | one repo first |
| Names | Norse set (Yggdrasil, Odin, Gleipnir, Jormungandr, Gungnir) | Greek set |
| Journey records | journal of challenges, solutions and measured results from v0; posting later | start records when promotion begins |
