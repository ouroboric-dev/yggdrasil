---
title: Yggdrasil v0 implementation plan
status: accepted
date: 2026-10-12
related: [tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../../1-product/design/2026-10-11-yggdrasil-v0-design.md, ../../changes/2026-10-12-require-budget-caps/proposal.md, ../../changes/2026-10-12-remote-creates-repos/proposal.md, ../../changes/2026-10-14-benchmark-split/proposal.md, ../../changes/2026-10-15-factory-issues/proposal.md, ../../changes/2026-10-15-project-is-its-own-tree/proposal.md]
style: spec
---

# Yggdrasil v0 implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement each phase's `tasks.md` task by task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** build v0 of Yggdrasil, the software factory that turns a frozen brief into verified
software, and prove it by building client gallery lite (design doc §2.3, criteria 1–7).

**Architecture:** six Go modules (`gungnir`, `odin`, `gleipnir`, `jormungandr`, `realm-web`,
`havamal`) in the `ouroboric-dev` org, developed together through a `go.work` in the `yggdrasil`
umbrella, which holds them as submodules (spec §1). Odin walks realm graphs and is the only writer of the
instance tree; Gleipnir runs agents in hardened devcontainers; Jormungandr runs bounded fix loops;
Gungnir holds every interface and schema (spec §2).

**Tech stack:** Go (factory), Podman with the devcontainer CLI (sandbox), `claude -p` and
`opencode run` (agents), the web realm's stack for the product (spec §9.2).

**Spec:** [v0 engineering spec](../../specs/2026-10-11-yggdrasil-v0-spec.md), implementing the
[v0 design doc](../../../1-product/design/2026-10-11-yggdrasil-v0-design.md), plus the accepted change
[require budget caps](../../changes/2026-10-12-require-budget-caps/proposal.md).

## How this plan works

The plan is split into phases. **Phase 0's tasks are written in full in [tasks.md](tasks.md).** Each
later phase gets its own `tasks.md` (in a dated folder next to this one) when the phase before it is
done: Phase 1's is [2026-10-15-yggdrasil-v0-phase-1/tasks.md](../2026-10-15-yggdrasil-v0-phase-1/tasks.md),
Phase 2's [2026-10-15-yggdrasil-v0-phase-2/tasks.md](../2026-10-15-yggdrasil-v0-phase-2/tasks.md).
Two reasons:

- **The spike can change the design.** Phase 0 answers the open items of spec §16. If the
  devcontainer driver fails on rootless Podman, the fallback is a plain Podman driver (spec §16), and
  Phase 3's tasks change. Writing them now would mean writing them twice.
- **Each phase produces working, tested software on its own**, so each phase's tasks can be reviewed
  and approved as one unit.

**Decided 2026-10-12:** phases get detailed tasks just in time; this plan fixes their order,
scope, dependencies and exit criteria now.

**Status:** this plan is `accepted` when the founder merges the pull request that adds it. The merge
is the `plan` approval; no agent changes the status.

## Phases

| Phase | Builds | Repos | Exit criterion |
|---|---|---|---|
| **0. Readiness** | the spike; repo checks; the existing repos brought to standard; `AGENTS.md` invariants; the component repos; `gitleaks`; the founder's tokens, accounts and hidden suite; Harbor on Podman and the Harbor agent adapter (v0-T016 to v0-T019) | all | **the readiness gate below** |
| **1. Contract and walking skeleton** | Gungnir types and schemas (`factory.yaml`, `graph.yaml`, `pack.yaml`, ledger events with OpenTelemetry `gen_ai.*` field names, findings); the `Agent` interface and the `scripted` adapter; Odin's graph engine with exec, agent and gate nodes, the mode × approval-point table, config validation, `run.json`, the hash-chained ledger; `ygg run`, `resume`, `approve`, `reject`, `status`, `doctor`; change task `require-budget-caps-T001` (all its cases: per-run and per-day caps, the spend limit for paid-API roles, refusing `resume`, the `doctor` error); CI that runs the deterministic end-to-end tests, made a required check in each ruleset | `gungnir`, `odin`, `gleipnir` | a scripted toy graph runs end to end in all three modes, stops at gates, resumes, and refuses to run without complete caps; CI is green and required |
| **2. Instance tree and git** | the tree walker (any depth), path-only checkout, host git with hooks off, checkpoints and resume, one-level pointer moves, the merge gate with locks, the shrink guard, the warning when a public umbrella lists private children (spec §3.1); change task `remote-creates-repos-T001` (the local remote creates leaves; the `repo-admin` approval point); a project is its own tree, with no operator L0 (change `project-is-its-own-tree`) | `gungnir`, `odin` | tree fixtures (including the deeper one) pass; both merge-gate tests from spec §13 pass; the git escape tests pass with the `scripted` adapter |
| **3. Harness and sandbox** | the sandbox driver chosen by the spike, config validation before every `up`, mounts, the egress firewall, managed settings; the `claude-code` and `opencode` adapters with usage and cost capture; privacy policy; Havamal with `skills.lock`, drift check, explicit loading, and the eval harness our own skills must pass before they ship (spec §5.1) | `gleipnir`, `havamal` | the sandbox escape tests pass; one real `claude-code` session and one `opencode` session run in a sandbox and report usage |
| **4. Loop, findings and caps** | Jormungandr's bounded loop, typed findings with proof, escalation per mode, budget caps as a hard approval point, the check runner, error handling (spec §12: retries with backoff, quota pause, infra stop, policy-violation quarantine) | `jormungandr`, `gleipnir`, `odin` | a malformed reviewer output stops the loop; a run that hits a cap stops resumable; findings close only with proof |
| **5. Web realm** | `realm-web`: `pack.yaml`, `graph.yaml`, prompts, stack layer, templates (with each leaf's clean `.devcontainer/`), check ladder rungs 1–7 (with the two-tenant harness), the isolated grader writing `score.json` with fail-to-pass and pass-to-pass results reported separately (spec §11), reading the task from `mimir` and the hidden suite from `huldra` (change task `benchmark-split-T001`), routing indexes and bench; the dependency policy: pinned minor lines, `govulncheck` and OSV gating, canary-first bumps (spec §9.6) | `realm-web`, `odin` | the realm builds a one-feature smoke brief end to end with real agents |
| **6. Metrics and proof runs** | `ygg metrics` and `--compare`, `ygg board`, `ygg report`, the local tracker, Yggdrasil's side of the Harbor bridge (v0-T018); then the runs that meet the design doc's success criteria; after they are scored, the v0 hidden suite is retired to `mimir` and replaced (change task `benchmark-split-T002`) | `odin`; runs in their projects | design doc criteria 1–7 met (table below) |

Dependencies: each phase depends on the one before it. Phase 3 can start once Phase 1 is done, in
parallel with Phase 2, because the sandbox doesn't need the tree walker; Phase 4 needs both.

## The readiness gate (end of Phase 0)

Building starts only when the readiness assessment
(`ouroboric/docs/1-company/readiness/2026-10-11-ready-to-build.md`) is re-run and **all 21 items are
met**. Phase 0 closes the open ones:

| Item | Closed by |
|---|---|
| RB-05 `AGENTS.md` invariants | v0-T006 |
| RB-12 component repos | v0-H04 (founder creates them), v0-T005, v0-T007 to v0-T013 |
| RB-13 budget and caps | v0-H01 (founder) |
| RB-14 credentials and secret scanning | v0-H01 and v0-H03 (tokens, founder) and v0-T014 (`gitleaks`) |
| RB-18 implementation plan | the founder's merge of this plan |
| RB-19 technical risks tested first | v0-T001 to v0-T003 (the spike) |
| RB-20 success measure fixed in advance | v0-H02 (founder: frozen brief and hidden suite) |

v0-T015 re-runs the assessment and records the gate.

## Success criteria → phases

| Design doc criterion | Met in |
|---|---|
| 1. builds client gallery lite; rungs 1–6 pass; hidden suite scored | Phase 6 benchmark run |
| 2. same brief with another agent tool or model for one role | Phase 6 cross-model run |
| 3. complete hash-chained ledger; `ygg metrics` reports everything | Phases 1 and 6 |
| 4. all three modes complete with `scripted`; one real run in key-points | Phases 1 and 6 |
| 5. escape-attempt tests pass | Phases 2 and 3 |
| 6. journal entries with evidence; factory changes cite `--compare` | throughout; checked in Phase 6 |
| 7. one factory change improves a metric without lowering the hidden score | Phase 6 improvement run |

## Carried beyond v0

Work that v0 sets up but can't finish, because it needs iteration 2 (spec §15). Each item names the
task that closes it, so it isn't lost when v0 ends. Reusable tooling lives in `ouroboric/scripts/`,
with a test, until a row here moves it.

| Item | Why it waits | Closed by |
|---|---|---|
| Move repo creation and protection from `ouroboric/scripts/create-repo.sh` and `setup-repo.sh` into the `github` remote, then delete the scripts | the `github` remote is iteration 2 (spec §15.1) | `remote-creates-repos-T002` |
| Require the founder's review on every PR, with `CODEOWNERS` and `require_code_owner_review`, so a bot's approval never counts | the pr-bot can approve PRs other people open; external contributions are rare in v0 | a reviewed change to `setup-repo.sh`, before the first external contribution is accepted |
| Move the component scaffold from `ouroboric/scripts/scaffold-component.sh` and `scripts/templates/go-component/` into Odin's `init`, as a Go component template set, then delete the script | `init` scaffolds leaves from realm templates (spec §4.2); scaffolding Yggdrasil's own components with it is self-hosting (spec §15.4) | a task in the first self-hosting stage's plan, which passes `scaffold-component.test.sh`'s cases |
| Per-container resource limits (memory, processes, CPU) in the sandbox | the Podman machine's rootless engine has no cgroup controllers, because the machine runs without systemd (sandbox spike, decided 2026-10-14); v0 relies on the token and turn caps, plus a `.wslconfig` limit for WSL as a whole | the sandbox driver's move to a host with systemd or Kubernetes (spec §2: "k8s, hosted later"), with a test that a run over its memory limit is stopped |

## Risks

| Risk | Effect | Mitigation |
|---|---|---|
| The devcontainer CLI doesn't work with rootless Podman here (spec §16, items 1 and 5) | Phase 3 changes | v0-T001 decides; fallback is a plain Podman driver behind the same interface |
| The Podman VM can't mount WSL paths (§16, item 6) | the sandbox can't see the leaf | v0-T001 tests native Podman in WSL, a VM-visible path, and copy-in with `podman cp` (shown to work on 2026-10-12) |
| `claude -p --bare` doesn't work with a subscription token (§16, item 2) | repo hooks and project MCP servers must be blocked another way | v0-T002 tests managed settings as the fallback |
| OpenRouter's privacy settings don't map to `privacy: strict` (§16, item 3) | strict privacy can't be promised | v0-T003 records what exists; the adapter refuses `strict` if it can't enforce it |
| The hidden suite leaks to the factory-building agent | the benchmark measures nothing | v0-H02 keeps it in the private `ouroboric-dev/huldra`, which the pr-bot is never installed on, and `check-repos.sh`'s `bot` check fails closed if it ever is; v0-H03 removes every other GitHub login and SSH key from the agent environment, so agents reach GitHub only as `ouroboric-pr-bot` |
| An agent session (buggy or hijacked by prompt injection) changes repo guardrails | rulesets, push protection or whole repos lost, repeated across the org | v0-H03: the pr-bot has no Administration write; the founder runs `setup-repo.sh` with a short-lived admin token |
| The pr-bot merges, or pushes after the founder approves | an unreviewed change lands on `main` | the bot isn't in the ruleset's bypass list, so it can merge only an approved PR; the ruleset dismisses approvals on push and requires approval of the last push; agents never merge (invariants); the founder's merge hook. A separate merge bot in iteration 2 (spec §15.1) takes merging off the founder |
| Building the factory uses up the founder's quota | work stalls | building and factory runs share the Ouroboric subscription (budget doc, 2026-10-13), so the per-run and per-day caps apply from Phase 1 on; cheap roles run on open-weight models through OpenRouter |
| Scope creep inside phases | v0 never finishes | iteration 2 items (spec §15) stay out; a phase's tasks change only through a reviewed update of its `tasks.md` |

Deferred, not a v0 risk: spec §16 item 4 (humanizer's upstream and licence) matters only for
human-published marketing text, which is out of v0's scope (design doc §2.2).

## Conventions for every phase

- Task ids are `v0-T###` (factory work) and `v0-H##` (founder work), numbered across phases.
- Every task passes the Definition of Ready: acceptance criteria, a named test, a layer, a size
  (S < 100 changed lines, M 100–400; L must be split) and dependencies.
- Test first: the named test fails before the change and passes after it.
- Commits stage explicit paths, never `git add -A`; every repo runs `gitleaks` before commits.
- Each repo's `main` is protected; every change lands through a pull request the founder merges.
