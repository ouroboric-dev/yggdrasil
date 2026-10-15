---
title: Tasks for a project being its own tree
status: accepted
date: 2026-10-15
related: [proposal.md, delta.md]
style: spec
---

# Tasks

## project-is-its-own-tree-T001: a project as its own root (v0, Phase 2)

- **Acceptance criteria:**
  - [ ] A project umbrella with `root: true` is a tree on its own: a run starts in it, and its leaves
        resolve below it.
  - [ ] A company umbrella above projects, and a deeper tree, still walk.
  - [ ] A run in a sub-project finds the root above it and works in its own leaves.
  - [ ] No task creates an operator L0.
- **Named test:** the Phase 2 plan's run tests (v0-T051 to v0-T055) on `treetest.Project`, a project
  that is its own root, and its tree tests (v0-T044, v0-T045) on a company umbrella.
- **Layer:** `odin`.
- **Size:** within the Phase 2 tasks.
- **Depends on:** the Phase 2 plan.

## project-is-its-own-tree-T002: the local list of projects (v0, Phase 6)

- **Acceptance criteria:**
  - [ ] `ygg board --all` reads the operator's projects from local configuration, and refuses a path
        that isn't a project umbrella.
- **Named test:** to be named in Phase 6's plan.
- **Layer:** `odin`.
- **Size:** S.
- **Depends on:** Phase 6's `ygg board`.

## project-is-its-own-tree-T003: pin the factory version at a project's root (after v0)

- **Acceptance criteria:**
  - [ ] A project's root records the factory version it runs with, and `ygg` refuses to run a project
        pinned to another version.
- **Named test:** to be named with the first release.
- **Layer:** `gungnir` (the field), `odin` (the check).
- **Size:** S.
- **Depends on:** the first tagged release of the factory, and self-hosting stage 1.

## project-is-its-own-tree-T004: the spec's text and diagrams

- **Acceptance criteria:**
  - [ ] When this delta is folded into the living spec (`../system/`), the instance-tree and
        architecture diagrams show a project as the root, with a company umbrella as the nested case.
- **Named test:** the docs build renders both diagrams; no page says the operator has an L0.
- **Layer:** `yggdrasil` (docs).
- **Size:** S.
- **Depends on:** this change merged.
