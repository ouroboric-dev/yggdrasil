---
title: Delta for operators' projects staying theirs, and the factories accepting issues
status: accepted
date: 2026-10-15
related: [proposal.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §1, §3.1, §15.4

## Added

- §1: the source umbrella and its component repos MUST NOT record an operator's projects. A factory
  run MUST NOT commit, push or open a pull request against them. Odin MUST write only to the
  operator's instance tree.
- §3.1: by default an instance tree uses git as usual: its repos are committed, and pushed and
  reviewed through pull requests where the operator hosts them. Keeping a project on one host is the
  operator's choice. In v0 Odin commits locally only; pushing and pull requests come with the
  `github` remote (§15.1).
- §15.4: the factory repos, `yggdrasil` and `asgard`, MUST accept GitHub issues through issue forms,
  for bugs and improvements. The forms MUST ask for the factory version and config hash, and MUST
  warn against pasting a private project's code, data or secrets. Other `ouroboric-dev` repos keep
  issues off. In v0 nothing MAY work on these issues automatically, and there is no triage process;
  triage comes with a later change. §15.1's rule stands: a private run MUST NOT file anything
  automatically to a public factory repo.

## Modified

None.

## Removed

None.
