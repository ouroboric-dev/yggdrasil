---
title: Delta for splitting benchmarks into a public kit and a private hidden suite
status: accepted
date: 2026-10-14
related: [proposal.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §11 and §15.1

## Added

- §11: a benchmark's public part MUST live in a public repo: briefs, `task.toml`, the grader
  environment, an optional `solution/` and `rubric.md`, sample suites and results. For Ouroboric it is
  `ouroboric-dev/mimir`.
- §11: a hidden suite MUST be versioned. A scored run MUST use a hidden version that no agent of
  any factory run, and no factory-building session, has read.
- §11: a hidden version MAY be retired once the runs that use it are scored. A retired version MUST be
  published to the public repo, and MUST NOT score any run after that. A new hidden version MUST be in
  place before the next scored run.
- §15.1: every bot installation MUST name its repos explicitly. It MUST NOT include a hidden repo.
  A check MUST fail if any bot can reach a hidden repo. The check MUST fail closed when it can't read
  the bot's repos.

## Modified

- §11, the task layout: the public part is `<public repo>/<task-id>/`; the hidden suite is
  `<hidden repo>/<task-id>/<version>/tests/`.
- §11: "Hidden suites MUST live in a private submodule of L0. They MUST NOT live in a public repo"
  becomes: hidden suites MUST live in a private repo that no factory agent can reach (for Ouroboric,
  `ouroboric-dev/huldra`, with no bot installed on it), included in L0 as a private submodule. They
  MUST NOT be public until retired.

## Removed

None.
