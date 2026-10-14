---
title: Tasks for splitting benchmarks into a public kit and a private hidden suite
status: accepted
date: 2026-10-14
related: [proposal.md, delta.md]
style: spec
---

# Tasks

## benchmark-split-T001: the grader reads the task from mimir and the suite from huldra (Phase 5)

- **Acceptance criteria:**
  - [ ] The isolated grader builds from `mimir/<task-id>/environment/`, and gets the hidden suite from
        `huldra/<task-id>/<version>/tests/` only inside its own container.
  - [ ] `score.json` names the task, the brief's SHA-256 and the hidden version.
  - [ ] A run whose `task.toml` names a retired hidden version is refused before grading.
  - [ ] No agent container, and no path an agent can mount, ever holds the hidden suite.
- **Named test:** `realm-web/grader/grader_test.go`, `TestGraderCombinesPublicTaskAndHiddenSuite`
  and `TestGraderRefusesRetiredVersion`.
- **Layer:** `realm-web` (grader) and `odin` (run setup).
- **Size:** M.
- **Depends on:** the v0 plan's Phase 5 grader.

## benchmark-split-T002: retire and publish the v0 hidden suite (after Phase 6)

- **Acceptance criteria:**
  - [ ] After the proof runs are scored, the v0 hidden version is copied to `mimir`, with a note
        naming the runs it scored.
  - [ ] A new hidden version exists in `huldra` before the next scored run.
  - [ ] `huldra` keeps only versions that haven't been retired.
- **Named test (founder-run):** the retired version's tests in `mimir` match its last commit in
  `huldra` (`git diff --no-index` prints nothing), and the next run's `score.json` names the new
  version.
- **Layer:** `mimir`, `huldra` (founder).
- **Size:** S.
- **Depends on:** the v0 plan's Phase 6 proof runs.
