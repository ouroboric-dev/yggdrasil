# Software factory — brainstorming progress (paused 2026-10-10)

Status: brainstorming (architectural path). No spec written yet, no code. Resume at **Section 3 approval**, then Sections 4–6, then write the spec.

## Agreed decisions
- **Purpose:** learn to build software factories (incl. specialised ones). Shipping own products / selling the factory = success measure.
- **Targets:** web SaaS + browser game, side by side; mobile later.
- **Models:** start on Claude subscription; hard requirement: no lock-in (swappable models/agent CLIs, incl. OpenRouter).
- **Autonomy:** configurable modes: step-by-step / key-points (default) / unattended. Some gates can never be turned off: prod deploy, store submit, real secrets/user data, budget cap.
- **v0 success:** two small builds (login+CRUD SaaS, arcade browser game) passing checks, with at least one model/agent swap; plus factory metrics (tokens, turns, cost, time, interventions, first-pass rate, hidden acceptance score) usable as benchmarks against other factories (frozen briefs + hidden tests).
- **Approach A:** own orchestrator. Split into 3 specs: (1) core + web pack + metrics + first benchmark brief, (2) game pack, (3) benchmark kit.
- **Stack: Go.** Cloud later doesn't favour Pekko; cloud-readiness comes from 3 swappable interfaces: AgentAdapter, Sandbox driver, StateStore.
- **Visualisation:** v0 = structured event stream (ledger.jsonl) + `factory status --watch`; Bubble Tea TUI in iteration 2; OpenTelemetry export later.
- **Frameworks:** don't build on CrewAI/LangGraph etc. Study Gas Town, MetaGPT/ChatDev; OpenHands = future adapter; container-use = candidate sandbox driver. Spec gets a "prior art" section.
- **Spec Kit / Superpowers:** "borrow, then plug in". v0 uses Spec Kit's artifact layout (spec.md/plan.md/tasks.md; features.json derived) and Superpowers' disciplines as graph structure (fresh session per task, two read-only reviewers: spec compliance then code quality, mechanical TDD check). Iteration 2: real Spec Kit as a swappable planning strategy, benchmarked vs native. Third-party skills pinned/vendored, never fetched live.

## Design sections
1. Architecture overview: **approved**
2. Run execution, checkpoints, resume: **approved** (high level), with Spec Kit layout and two-reviewer verify loop added
3. Agent adapters + sandbox + topology: **approved** (2026-10-11 session)
   - Adapters: claude-code + opencode; per-role agent/model config; tokens/turns primary metrics, cost marked estimated.
   - Sandbox = **devcontainer driver** (devcontainer CLI + rootless Podman). Pack stack layer + factory layer (pinned agent CLIs, auto-update off, managed-settings.json, Anthropic-style egress firewall pulled into v0, non-root user). Factory-owned hardened config used via `--config`, never mounted; refuse initializeCommand/extra mounts/privileged/socket. Product repo gets a clean human `.devcontainer/`.
   - **Topology = recursive umbrella/leaf tree.** L0 factory-home (engine as pinned submodule, benchmarks w/ hidden tests, docs) → L1 project umbrella (AGENTS.md, spec/plan/tasks, REPOS.md, .factory state, acceptance tests) → L2 leaf repos. Deeper levels allowed; v0 runs L0→L1→L2 plus a deeper-tree test fixture. Path-only submodule init, never --recursive from L0.
   - **Agents never mount an umbrella**: implementer mounts one leaf; planner gets a scratch dir; factory is sole writer of umbrellas, features.json, ledger.
   - Leaf git dir (parent's .git/modules) mounted read-only at most; host git runs with hooks disabled (`-c core.hooksPath=/dev/null`); agents don't commit; never recursive submodule update inside leaves.
   - **Pointer move = validation record**: one level per move, needs that level's tests; contract changes (per impact index) = approval point in key-points; no auto-chained propagation unless explicitly raised. No marola-style auto-merge of pointers.
   - **Routing** (MIP-0084/0085 style): per-umbrella routing bundle built by deterministic exec nodes, summary injected into agent context; hierarchical descent. v0 indexes: wiring/contracts, impact, doc↔code, decisions (symbol + meaning later, bench-gated). Routing bench per project; ledger counts route vs grep usage and misses. Shrink guard (<50% rows → stop for a person) on every generated artifact. Models only as pinned safetensors.
   - **Remote/identities** (MIP-0086 pattern): `Remote` interface (local | github). v0 = local git only; **github impl in iteration 2** but fully specified in spec 1: agents hold no GitHub creds (factory pushes/opens PRs on their behalf); pr-bot App (propose only) + merge-bot App (only bypass actor besides admins); rulesets on every main (PR + checks + 1 human review); per-operation, per-repo minted 1h tokens; merge from host never CI; only human-approved (`agent-ready`-style) work becomes factory work — non-disableable gate.
   - Open item: does `claude -p --bare` work with subscription auth? (managed-settings.json may cover it). Spike: devcontainer CLI + rootless Podman (userns keep-id, NET_ADMIN firewall, read-only gitdir mount); fallback plain Podman driver.
4. Gates & autonomy modes: **approved**. Soft gates (spec, plan, feature, merge, pointer, pointer-contract) per mode table; hard gates always stop (deploy-prod, store-submit, real-secrets-or-user-data, budget-cap, external-input, policy-violation, shrink-guard). Gate = approval file in L1/.factory/runs/<id>/gates/ + exit; `factory approve|reject` (reject reason feeds previous node). Auto-passes logged. Exhausted loop: stop (step/key-points) or mark feature `blocked` and continue (unattended). Hard gates not overridable (config rejected). Mode switch at pauses, loosening logged. Budget cap per run/day in tokens/turns ($ on API).
5. Web pack & verification: **approved**.
   - Product (benchmark brief #1): **client gallery lite** (Pixieset-like): photographer upload/galleries/password/PIN/download toggle; client grid+viewer, favourites (email), single + zip downloads; favourites & download-activity dashboard. Later: watermarks, comments, branding, payments, etc.
   - Stack (option c): leaves `api` = Go net/http + sqlc + Postgres, owns openapi.yaml; `web` = React+Vite+TS+Tailwind+shadcn/ui+TanStack Router/Query, Uppy presigned resumable uploads, generated client. Consumer tests against producer built at L1-pinned SHA.
   - Infra: **Vercel** (static Vite site + Go server via Go preset, beta), **Neon** Postgres (local Postgres container in dev), **R2** (SeaweedFS in dev; MinIO archived). Photo bytes never through API/Vercel: presigned URLs; browser-side zip streaming (fallback per-photo); **browser-side thumbnails** at upload (server never decodes images; JPEG/WebP only, size/pixel caps). Separate Preview vs Production env/DB (Neon branch)/bucket; promotion = deploy-prod hard gate. Deployment itself out of v0.
   - Check ladder: static → unit + TDD-fails-on-parent → contract (OpenAPI lint, client fresh, oasdiff) → security (gitleaks every checkpoint, govulncheck/npm audit, mechanical two-tenant authz harness incl. gallery A↔B, client-supplied storage key ignored, bucket anon read refused, signed URL expiry, no GPS EXIF in web sizes, size/pixel caps, PIN rate limit) → Playwright e2e → reviewers (spec, quality) → hidden benchmark suite at L1 (results never fed to agents; incl. gallery ID enumeration).
   - Pack dependency policy: pin minor line + patched minimum, govulncheck/OSV gate, canary product then batches, never middleware-only auth.
   - Iteration 2: Next.js full-stack comparison pack, same brief + hidden tests.
   - Spike adds: devcontainer CLI + compose services on rootless Podman.
6. Metrics ledger, benchmark kit format, error handling, testing the factory: **approved**.
   - Ledger: append-only JSONL per run in L1/.factory/runs/<id>/, factory-only writer, schema-versioned, OTel gen_ai.* naming, hash-chained lines (tamper-evident). `factory metrics`: tokens/turns/cost per feature+run, wall time excl. gate wait, first-pass rate, loop attempts, reviewer veto rate, interventions, escalations/blocked, hidden acceptance score, escaped defects, routing usage + bench right-first.
   - Benchmark kit format: benchmarks/<id>/{benchmark.yaml, brief.md (frozen, versioned), hidden/ (black-box Playwright vs URL), rubric.md}; score.json; hidden suites in a PRIVATE submodule of L0.
   - Errors: transient → 3 retries w/ backoff (not a loop attempt); provider quota → pause, resumable; agent failure → loop attempt; check failure → feedback; infra failure → stop (no retry loop); policy violation → hard stop + quarantine. Atomic run.json, fsync'd ledger, `factory doctor` for orphans.
   - Testing the factory: Go unit tests (traversal, mode×gate table, hard-gate override rejection, pointer propagation incl. deeper tree); `scripted` fake agent adapter for deterministic zero-cost e2e; escape-attempt tests (.git/hooks, initializeCommand, features.json/ledger edits, nested malicious submodule, ~/.ssh read); real-agent smoke brief before benchmark runs and after model/CLI bumps; factory repo has Go devcontainer + short AGENTS.md, built test-first.

## Progress tracking (approved)
- Two kinds: live (status --watch, TUI in iteration 2) and backlog (issue tracking).
- MIP-0063 model as a **one-way projection** of factory state (factory sole writer; agents never touch issues; ledger = metrics truth). Milestone = project deliverable/brief; issue = task; sub-issues mirror repo tree (GitHub 8-level cap). "Issues own status, files own the plan."
- **Definition of Ready as a mechanical check after the planner** (acceptance criteria, named test, layer/size labels, size L → split, no open blocker), before the spec gate.
- Board views: Needs you, Now, Agent queue, Blocked, Triage. Approvals stay CLI; future `/approve` via GitHub only from operator's account (author association), never trusting comment text.
- MIP-0063 gotchas for spec: sub-issue/dependency APIs take database id not issue number; built-in "item closed" workflow unreliable → sync fallback; `Closes #N` in squash-merge commit body.
- `Tracker` interface (local | github). v0: `factory board` terminal kanban + committed `factory report <run>` markdown in L1. GitHub tracker in iteration 2 with Remote + identities. Beads considered, rejected (agents as writers).

## Multi-org / open source (approved)
- `ouroboric-dev` GitHub org created (repo name pending). Factory repo = public eventually (engine, packs, public briefs; never hidden tests). L0 = operator's own instance (each operator has their own); L1 + leaves live in product orgs (e.g. `photografy`).
- **Project visibility and hosting are the operator's choice** (public/private, any host; GitHub first via Remote). Factory just applies consequences. Advice: a public L0 with private projects leaks repo names via .gitmodules.
- Tree nodes carry owner/visibility metadata; credentials per org. Operator-owned GitHub Apps via shipped App manifest; per-org installations; optionally one App pair per product org.
- Boards per product org; cross-project view local (`factory board --all`). **The factory org's board tracks improving the factory itself** (harness bugs, benchmark regressions, ideas) — second loop. No auto-filing upstream from private runs.
- Project `privacy` setting (e.g. strict → restrict OpenRouter providers via data-policy settings; verify options when building adapter). Policy hierarchy tightens only: factory defaults → L0 → L1 → leaf.
- v0 impact: only node owner/visibility metadata + project privacy setting; org work lands in iteration 2.

## Next step
Design complete. Waiting on repo name in `ouroboric-dev`, then: create local repo (no push), move notes into its docs/, write spec 1 (core + web pack + metrics) to docs/specs/2026-10-11-<topic>-design.md, self-review, commit, user review, then writing-plans.

Research briefs added: research-web-stack.md, research-hosting.md. Branding prompts: branding-prompts.md.

## Research briefs
See `research/`: harness engineering, loops/graphs/factories, stack comparison.
