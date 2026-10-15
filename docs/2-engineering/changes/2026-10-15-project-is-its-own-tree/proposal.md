---
title: A project is its own tree
status: accepted
date: 2026-10-15
related: [../../specs/2026-10-11-yggdrasil-v0-spec.md, delta.md, tasks.md, ../2026-10-15-factory-issues/proposal.md, ../../plans/2026-10-15-yggdrasil-v0-phase-2/tasks.md]
style: spec
---

# A project is its own tree

**Decided 2026-10-15 (founder):** an operator has no instance umbrella (L0) above their projects. By
default a project umbrella is the root of its own tree, with its leaves below. A company umbrella
that holds products, which is the shape Asgard's company trees have, is the nested case.

## Why

- The spec gives each operator one private L0 above all their projects (§1, §3.1). That L0 pinned
  the factory version, held the private benchmarks, and listed the projects. In review of the
  Phase 2 plan it was clear that, for Yggdrasil, a project is the natural unit: an operator thinks of
  "my client gallery project", not of a home repo that holds it.
- The change "factory issues" makes each operator's project theirs alone. A tree that is the project
  itself fits that, with nothing above it that the factory needs.
- For Asgard, the company factory, a company umbrella above the company's products is the right shape,
  and the tree walker already handles any depth. The two are the same mechanism: the tree's root is
  whichever umbrella says `root: true`.

## What changes

- **The default tree is a project**: the project umbrella is the root, its leaves below it. A company
  umbrella above projects is allowed, for Asgard and for any operator who wants one.
- **What L0 held goes elsewhere:**
  - **The factory version** a project runs with is recorded on every run's report (spec §10.2), and
    pinned at the project's root once there are releases to pin. A version, not a `yggdrasil`
    submodule: a project doesn't carry the factory's source, and self-hosting doesn't make the
    `yggdrasil` repo reference itself.
  - **The hidden benchmarks** belong to the bench, in `huldra` (change benchmark-split), never to an
    operator's tree.
  - **The list of an operator's projects**, for `ygg board --all`, is local configuration on the
    operator's machine.
  - **Private skills, privacy settings and private lessons** sit with the project, or a company
    umbrella above it.
- **Self-hosting:** in stage 1 the `yggdrasil` umbrella is the project being built, as its own tree,
  built by a released factory pinned at its root.

## Impact

- **Spec:** §1, §2's diagram, §3.1, §3.3 rule 6, §5, §5.1, §10.5, §11 and §15.4 (see the delta).
- **Phase 2:** no founder task to create an L0; the test fixtures put a project at the root by
  default, and keep a company umbrella for the nested case and the deeper tree.
- **Later phases:** Phase 5 creates the client gallery's project as its own tree. Phase 6's
  `ygg board --all` reads the local list of projects, and its reports record the factory version.
