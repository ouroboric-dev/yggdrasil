---
title: Tasks for realm leaf naming
status: accepted
date: 2026-10-17
related: [proposal.md, delta.md]
style: spec
---

# Tasks

## realm-leaf-naming-T001: the repos (founder, before Phase 5)

- **Acceptance criteria:**
  - [ ] `realm-web` is renamed `midgard-react` on GitHub, with the description "The Midgard realm's
        React flavor: graph, prompts, devcontainer stack layer, templates and checks for web
        frontends." Its history is kept.
  - [ ] `helheim-go` exists, created with `ouroboric/scripts/create-repo.sh` and the description "The
        Helheim realm's Go flavor: prompts, devcontainer stack layer and services, templates and
        checks for backends."
  - [ ] The pr-bot reaches both (`helheim-go` added to its selected list).
- **Named test (agent-run):**
  `as-bot.sh --read all scripts/check-repos.sh --check settings --check security --check ruleset midgard-react helheim-go`
  exits 0.
- **Layer:** GitHub org.
- **Size:** S.
- **Depends on:** this proposal merged.

## realm-leaf-naming-T002: the leaves and the umbrella (before Phase 5)

- **Acceptance criteria:**
  - [ ] `midgard-react`'s `go.mod` module path, README, `AGENTS.md`, `docs/architecture.md`,
        `templates/README.md` and devcontainer name say `midgard-react` and the Midgard realm.
  - [ ] `helheim-go` holds the same scaffold, from `ouroboric/scripts/scaffold-component.sh
        --mit-templates`, with the Go devcontainer image that `realm-web` used.
  - [ ] The umbrella's `.gitmodules`, `go.work` and submodule paths name `midgard-react` and
        `helheim-go`; the pointers are on each leaf's merged `main`.
  - [ ] `ouroboric/scripts/check-repos.sh` lists both leaves in `LEAVES`; the `scaffold-component.sh`
        test's example name is `midgard-react`.
- **Named test (agent-run):** in `yggdrasil`, `go build` of every module through `go.work` passes;
  `ouroboric/scripts/tests/scaffold-component.test.sh` passes;
  `as-bot.sh --read all scripts/check-repos.sh` with the new `LEAVES` exits 0; and
  `grep -rn realm-web` in `yggdrasil` and `ouroboric` finds only records (past plans, SDD ledgers,
  journal entries, this change, the backlog's B-038).
- **Layer:** `midgard-react`, `helheim-go`, `yggdrasil`, `ouroboric`.
- **Size:** S.
- **Depends on:** T001.

## realm-leaf-naming-T003: the living docs (before Phase 5)

- **Acceptance criteria:**
  - [ ] The delta is folded into the v0 spec, and §2's architecture diagram is redrawn and rendered
        (`ouroboric/scripts/diagrams.sh`).
  - [ ] `yggdrasil/README.md`, the roadmap and the Asgard v0 design say `midgard-react` (or Midgard)
        where they mean the realm, and keep "web" where they mean the kind of product.
  - [ ] B-038 moves to Done in the backlog, with this change's PR links.
- **Named test:** review of the diff against the delta.
- **Layer:** `yggdrasil`.
- **Size:** S.
- **Depends on:** T002.

## realm-leaf-naming-T004: a lead realm and each leaf's realm (v0, Phase 5)

- **Acceptance criteria:**
  - [ ] A run with `--realm midgard-react` walks `midgard-react`'s graph.
  - [ ] The spec stage names the leaves and each leaf's realm; after the `spec` gate, `init` creates
        `api` from `helheim-go`'s template and `web` from `midgard-react`'s, and records each leaf's
        realm and version in the project.
  - [ ] The graph's implement and check nodes name roles (`implementer`, the leaf's checks), and Odin
        resolves them in the task's leaf's realm.
  - [ ] The client gallery's `api` sandbox gets `helheim-go`'s stack layer and services, and its loop
        gets `helheim-go`'s implementer prompt and checks; the `web` leaf gets `midgard-react`'s.
  - [ ] Each realm loads once, at the version the project pins; a realm that can't be loaded at its
        pinned version, or two pins of one realm that disagree, stop the run before any sandbox comes
        up.
  - [ ] `web`'s sandbox gets `helheim-go`'s services because `web` consumes `api`.
  - [ ] `run.json` and the status line record the lead realm with its graph version and each leaf's
        realm with its version.
- **Named test:** to be named in Phase 5's plan.
- **Layer:** `gungnir` (where a leaf names its realm; the pack's roles), `odin`, `gleipnir` (services
  per sandbox).
- **Size:** within Phase 5's tasks.
- **Depends on:** Phase 5's design of loading a realm at a pinned version (shared with B-035).

## realm-leaf-naming-T005: the brand and company docs (with this proposal)

- **Acceptance criteria:**
  - [ ] `ouroboric/docs/7-branding/story/naming-and-mythology.md` holds the convention (a naming
        rule), the map with each realm's myth, and glossary rows for the nine realms. The story says
        each kind of work is a realm, and a product is a combination of leaves. Midgard leaves "names
        not yet used".
  - [ ] The long-term map (`ouroboric-long-term-map.d2`) shows the nine realms, solid for those on
        the roadmap and dashed for the rest, and is rendered.
  - [ ] The company charter lists research and art as Yggdrasil realms (Vanaheim, Alfheim), named
        but not committed, instead of separate illustrative factories.
- **Named test:** review of the diff against this proposal.
- **Layer:** `ouroboric`.
- **Size:** S.
- **Depends on:** nothing.
