---
title: Delta for a project being its own tree
status: accepted
date: 2026-10-15
related: [proposal.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §1, §2, §3.1, §3.3, §5, §5.1, §10.5, §11, §15.4

## Added

- §3.1: a tree's root is the umbrella whose `umbrella.yaml` sets `root: true`. By default it is a
  project umbrella. A company umbrella MAY hold projects, and a project MAY hold sub-projects; the
  engine walks every shape the same way. For company-shaped work the docs SHOULD point to Asgard.
- §3.1: the list of an operator's projects, for `ygg board --all`, is local configuration on the
  operator's machine, not a repo.
- §10.2: a run's report records the factory version it ran with (already required), and a project's
  root pins it once there are releases to pin.

## Modified

- §1: "Each operator has a private instance umbrella (L0, §3) that pins a Yggdrasil version and lists
  their projects" becomes: each project is its own tree (§3); an operator MAY keep a company
  umbrella above their projects.
- §2: the diagram's tree is "project umbrella → leaf repos (a company umbrella MAY sit above)".
- §3.1: the tree drawing starts at the project umbrella (`AGENTS.md`, `docs/`, `REPOS.md`,
  `.factory/`, `acceptance/`, `repos/<name>/`), with an optional company umbrella above it holding
  `projects/<name>/`. The `yggdrasil/` and `benchmarks/` submodules leave the tree. "v0 projects use
  L0→L1→L2" becomes "v0 projects are a project umbrella over its leaves". The visibility warning
  applies to any public umbrella that lists private children.
- §3.3 rule 6: Odin MUST NOT initialise submodules with `--recursive` from the tree's root.
- §5: privacy MUST only tighten going down: factory defaults → company umbrella, if any → project →
  leaf.
- §5.1: operators MAY add private skills through their factory configuration.
- §10.5: lessons from private product runs MUST be recorded in the private project first, and private
  evidence MUST be linked from it.
- §11: hidden suites MUST live in a private repo (`huldra`, change benchmark-split), never in an
  operator's tree.
- §15.4: in stage 1, the `yggdrasil` umbrella is the project being built, as its own tree. The
  running factory MUST always be the last released version, pinned at the project's root.

## Removed

- §1, §3.1: the operator's instance umbrella (L0), with its `yggdrasil/` and `benchmarks/`
  submodules.
