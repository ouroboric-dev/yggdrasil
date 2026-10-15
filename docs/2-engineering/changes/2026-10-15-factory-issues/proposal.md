---
title: Operators' projects stay theirs; the factories accept issues
status: accepted
date: 2026-10-15
related: [../../specs/2026-10-11-yggdrasil-v0-spec.md, delta.md, tasks.md, ../../plans/2026-10-15-yggdrasil-v0-phase-2/tasks.md]
style: spec
---

# Operators' projects stay theirs; the factories accept issues

**Decided 2026-10-15 (founder):** an operator's projects live only in the operator's own repos, and
no factory run ever writes to a factory repo. What flows back to the factories is issues, raised by
hand on `yggdrasil` and `asgard`. In v0 nothing works on those issues automatically, and there is no
triage process yet.

## Why

- The spec separates the source umbrella from the operator's instance (§1), but doesn't say outright
  that the factory keeps no trace of an operator's projects, or that building software never pushes
  to the factory. Phase 2 makes the instance tree real, so the rule has to be explicit.
- The spec lets the operator choose hosting per project (§3.1), without a default. The default is git
  as usual: commits, pushes and pull requests to the project's own repos. Keeping a project local is
  the operator's choice.
- Ouroboric's factories improve from use (spec §15.4, self-hosting). The more people use them, the
  more problems and ideas they find. Today every `ouroboric-dev` repo has issues turned off, so there
  is nowhere to report them.

## What changes

- **No reference to operators' projects.** `yggdrasil` and its component repos never record an
  operator's projects. A factory run never commits, pushes or opens a pull request against them. Odin
  writes only to the operator's own tree: the project, its leaves, and any umbrella the operator
  keeps above it (change project-is-its-own-tree).
- **Git as usual is the default** for the instance tree, with each project's repos hosted where the
  operator chooses. In v0 Odin commits locally only. Odin pushing and opening pull requests comes
  with the `github` remote (spec §15.1, iteration 2); until then an operator pushes their tree with
  git.
- **Issues are open on the two factories**, `yggdrasil` and `asgard` (the company factory), raised
  by hand through issue forms: a bug, or an improvement. The forms ask for the factory version and
  config hash, and warn against pasting a private project's code, data or secrets. Every other
  `ouroboric-dev` repo keeps issues off.
- **No automation works on the issues in v0**, and there is no triage process. Spec §15.1's rule
  stays: a private run files nothing to a public factory repo automatically. Triage, and moving an
  issue to the component it concerns, come with a later change.

## Impact

- **Spec:** §1 gains the no-reference rule; §3.1 the git-as-usual default; §15.4 the issues.
- **Repo scripts** (`ouroboric/scripts`): `setup-repo.sh` turns issues on for the factory repos and
  keeps them off elsewhere, and `check-repos.sh` expects exactly that.
- **Company docs:** the docs standard's §9 and the legal page's "Contributions" section say that
  issues are open on the factories, while outside pull requests stay closed until a contributor
  licence agreement is in place.
- **Phase 2:** its plan states the no-reference rule and the default.
- **v0 plan:** the tasks below are not tied to a phase.
