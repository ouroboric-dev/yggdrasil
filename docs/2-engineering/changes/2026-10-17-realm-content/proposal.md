---
title: The realms' content: stacks built from the realm, a snapshot sandbox, mock e2e
status: accepted
date: 2026-10-17
related: [../../specs/2026-10-11-yggdrasil-v0-spec.md, ../2026-10-17-realm-engine/proposal.md, ../2026-10-17-realm-leaf-naming/proposal.md, delta.md, ../../plans/2026-10-17-yggdrasil-v0-phase-5b/tasks.md]
style: spec
---

# The realms' content: stacks built from the realm, a snapshot sandbox, mock e2e

**Decided 2026-10-17:** Phase 5b builds the content of the two web realms (`midgard-react`, the lead
realm, and `helheim-go`): their packs, graph, prompts, stack images, templates and the check ladder's
rungs 1 to 6, and what the engine needs for them. The spec says what the web realm's ladder and
stack are, but is silent on how a realm's tools get into a sandbox, how a web leaf's end-to-end rung
gets an API, how acceptance checks run once a sandbox is on, and what the design-conformance reviewer
hands the `spec` gate. This change records the choices the phase had to make, so that the spec and the
code do not drift apart. Four of them differ from the letter of the spec; they are marked **differs**.

## Why

The ladder needs about fifteen tools (golangci-lint, sqlc, oasdiff, vacuum, govulncheck, osv-scanner,
Prism, Playwright and its browser, the Go toolchain for the acceptance run). Phase 3's stack was an
upstream image pinned by digest, which holds none of them. The ladder's scripts must also be out of the
agent's reach (a weakened check is a passed check), and a run must not need the network for tools. And two
parts of spec §9 cannot be done as written once the engine of Phase 5a exists: the web leaf's sandbox holds
the web leaf only, so it cannot "run the API as a read-only service" (§9.2), and acceptance checks run over
several leaves, so no leaf's sandbox holds them (Phase 3, decision 11).

## What changes

- **A realm's stack is a pinned image or a build context in the realm** (differs from §6.1, §9.4, which
  say the stack layer is the pack's `devcontainer/` and name `checks/` as a folder of the realm). `pack.yaml`
  names `sandbox.stack` (an image pinned by digest, as before) or `sandbox.build` (a folder with a
  Containerfile, and optionally `target`, a stage of it). `ygg sandbox build` builds the context with the
  isolated registry auth, from bases pinned by digest and its own stages only, and tags the image with a hash
  of the context and the stage. The ladder's scripts live in the context (`devcontainer/checks/`) and the
  Containerfile bakes them into `/opt/ygg/checks`, owned by root and not writable by the agent. A realm can
  move to registry-published images later by naming the image: both forms are in the schema.
- **Acceptance checks run in a snapshot sandbox** (differs from Phase 3 decision 11, which refused them with a
  sandbox on). A pointer move's acceptance checks run in a scratch sandbox over a snapshot of the project:
  the committed files of the umbrella and of each leaf, at the commits they are on (the leaf being moved at the
  commit it moves to), with no git directory and none of a working copy's ignored files, on the lead realm's
  `sandbox.acceptance` stack, with the services of every leaf's realm.
- **A web leaf's end-to-end rung runs against a mock of the contract** (differs from §9.2). In a task's loop,
  Playwright runs against the built app with Prism, made from the leaf's copy of the API contract
  (`contracts/api.openapi.yaml`), behind it. The real API runs only in the acceptance run: it is built from
  the snapshot's API leaf and started against Postgres, and the web leaf's specs run against it. The copy of
  the contract may lag behind the API, but the API may not break what the copy promises (`oasdiff`), so the
  API's task can land before the web task that uses it.
- **A service may name its command** (differs from Phase 5a decision 12, "the image's own command"), as an
  argument vector with no shell, for an image that does nothing without one (SeaweedFS).
- **The design-conformance review hands the `spec` gate a verdict.** A scratch reviewer (`reviews:`) finds the
  output of the agent it reviews as `reviewed/` and writes `out/conformance.json`
  (`{"deviation": bool, "amendment": text}`). The gate (`deviation_from:`) reads it: a deviation stops the gate
  in every mode with the amendment in the gate file. A verdict that cannot be read is asked for once more and
  then stops the run; it is never a pass (§4.6).
- **The TDD check** (§9.5 rung 2) compares the commit the task started from (the leaf's `main`) with the
  branch: the test files a change adds or changes are put on a copy of that commit and run, and they must
  fail. Code without a new or changed test is refused. Integration-tagged tests and Playwright specs need
  services or a browser, so a change that only has those passes with a note, and the reviewers look.
- **Ponytail's `ponytail-review` is vendored** through Havamal at a pinned commit and loaded explicitly by the
  reuse review of the plan and by the simplicity reviewer (spec-driven development §8).
- **Go 1.26.9 is the Go stack's toolchain.** `govulncheck` (rung 4) flags the standard library of 1.26.7 for
  vulnerabilities fixed in 1.26.9, so rung 4 could never pass. The image is nine days old, under the two
  weeks Phase 3 asked for: the founder's waiver for CI's 1.26.9 applies here too.

## Not in this change

Rung 7 and the isolated grader, the two-tenant authorisation harness, the routing indexes and the impact
index (so `pointer-contract` is not in the graph), the dependency policy's canary-first bumps (5c); Vale
prose rules in the docs rung and a shared home for the scripts both realms copy (backlog); an initializer
agent that customizes each leaf's `AGENTS.md` after `init`; the project's design documents reaching an
implementer (a task states what it needs).

## Impact

- **Components:** Gungnir (schemas), Gleipnir (`BuildStack`, a service's command), Odin (stack refs, the
  snapshot, the verdict), Havamal (a vendored skill), and the two realms.
- **Approval points:** the `spec` gate now reads a fact (§7.1 already says it should).
- **Operators:** `pack.yaml` may say `sandbox.build`, `target` and `acceptance`; `ygg sandbox build` builds
  realms' contexts; the factory needs the roles `planner`, `implementer` and `reviewer`.
- **v0 plan:** Phase 5b's `tasks.md` implements it; 5c follows.
