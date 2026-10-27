---
title: Tasks for the turn cap
status: draft
date: 2026-10-27
related: [proposal.md, delta.md]
style: spec
---

# Turn cap: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first. One pull request per repo, in the order below; the founder merges. A leaf bumps its `go.mod` only
> after its dependency merged; build across leaves with a scratch `go.work` meanwhile.

**Goal:** a session at its turn cap is reported as `turn-limit` by every adapter, logged as such, repaired with
its notes, and every session that hands back a contract is told its budget.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `gungnir`:** add `FailureTurnLimit FailureKind = "turn-limit"`; `Result.Validate` accepts it; the
  comment of `FailureAgent` drops "a turn limit". Tests in `agent_test.go`: a failed result with `turn-limit`
  validates; the list of kinds in the error message names it.
- [ ] **T2 `gleipnir`:** `opencode.parse` reports `turn-limit` when its steps reach the task's `MaxTurns` and no
  `submit` call validated, keeping the last text as `Output`; `claudecode` maps `error_max_turns` without a valid
  submit to `turn-limit`. A session that submitted a valid output before its cap stays `ok`. Fixtures: the run 1
  shape ("Maximum steps for this agent have been reached." as the last text, 20 steps) and a `claude -p` stream
  with `error_max_turns`. The adapter contract suite gets the case, so both adapters return the same thing.
- [ ] **T3 `jormungandr`:** `AnswerInstructions` and `ReviewRequest` take the turn cap (0 for none) and write the
  budget line (proposal, item 4). Tests: the line with N set, none with 0, N-2 never below 1.
- [ ] **T4 `odin`:**
  - pass the node's `max_turns` to the answer instructions (`internal/engine/prompt.go`);
  - in `sessionWithOutput`, a `turn-limit` result is logged as `output_refused` with the cap named, and the repair
    prompt gets a "## Your earlier session ran out of turns" section with its notes (clipped, through `mdsafe`)
    instead of the validation errors;
  - `ygg metrics` counts turn-limit refusals apart from invalid outputs.
  Tests next to the existing `sessionWithOutput` tests with the `scripted` adapter: a capped first session, a
  repaired second; a capped repair fails the node; the budget line is in the prompt of a node with `max_turns`.
- [ ] **T5 `yggdrasil`:** fold the delta into the v0 spec, mark B-207 done, move the pointers, archive this
  folder. Then run the reviewer bench (`scripts/ygg-reviewer-bench.sh`, `--dry-run` first, it costs money) on the
  local model and record the turns it takes; a new `max_turns` for the reviewers is a separate `voluspa` change.

## Open for the builder

- How a loop counts a `turn-limit` reviewer today with `claude-code` (a failed session of kind `agent`): check
  `jormungandr`'s reviewer path and state in the pull request whether T4 changes a loop attempt's count.
- Whether OpenCode's step count can exceed `MaxTurns` (run 1 shows 21 and 22): `>=` is the test, and the pull
  request says why the count goes over.
