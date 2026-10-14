---
title: Split benchmarks into a public kit and a private hidden suite
status: accepted
date: 2026-10-14
related: [../../specs/2026-10-11-yggdrasil-v0-spec.md, delta.md, tasks.md, ../../plans/2026-10-12-yggdrasil-v0/tasks.md]
style: spec
---

# Split benchmarks into a public kit and a private hidden suite

**Decided 2026-10-14 (founder):** a benchmark has two parts in two `ouroboric-dev` repos.

- **`mimir`**, public, holds what others can use: the briefs, the task format (`task.toml`, the grader
  environment), sample suites and results.
- **`huldra`**, private, holds only the hidden suites. The pr-bot is never installed on it, so no
  agent can read it.

A hidden suite is published to `mimir` once it is retired, and a new hidden version replaces it.

## Why

- **A benchmark is worth more when others can use it.** Other factories can run our tasks, and
  people can check our results.
- **The tests that produce the score must stay unseen,** or the score proves nothing. A factory, or
  a model trained on public code, that has seen the tests can learn to pass them without building a
  good product. Success criterion 7, improving a metric without lowering the hidden score, would be
  meaningless.
- **Retiring and publishing makes every test shareable in time,** once it can't be used for scoring
  any more.
- **The org is the company's place.** The founder prefers company ownership over a personal account.
  The pr-bot was installed on "All repositories", which would include a private org repo, so its
  installation moves to selected repos only.

## What changes

- **The task layout of spec §11 is split.**
  - `mimir/<task-id>/` holds `instruction.md`, `task.toml`, `environment/`, an optional `solution/`
    and `rubric.md`, and the sample suite.
  - `huldra/<task-id>/<version>/tests/` holds the hidden suite.
- **The grader combines them at grading time,** in its own container, after the agent containers
  have stopped (spec §11, unchanged).
- **The pr-bot is installed on selected repos only,** never on `huldra` or any later hidden repo.
  A check fails if it can reach one.
- **A hidden version is retired only after the runs that use it are scored.** Then it moves to
  `mimir`, and a new version takes its place before the next scored run.
- **L0 keeps both as submodules:** `mimir` public, `huldra` private.

## Impact

- **Spec:** §11 changes as in `delta.md`; §15.1 gains the rule about the bots' installations.
- **Tooling:**
  - `ouroboric/scripts/create-repo.sh --private` creates hidden repos.
  - `check-repos.sh`'s `bot` check guards them. It verifies that every public repo is on the
    installation and no hidden repo is.
- **Founder:** adds each new public repo to the pr-bot's installation, as `create-repo.sh` says.
- **v0 plan:**
  - v0-H02 creates both repos.
  - v0-H03's installation moves to selected repos.
  - The grader task (Phase 5) reads from both repos.
  - Retiring the v0 suite comes after Phase 6's proof runs.
