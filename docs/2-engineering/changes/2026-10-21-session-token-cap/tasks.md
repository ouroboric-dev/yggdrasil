---
title: Tasks for the session token limit
status: draft
date: 2026-10-21
related: [proposal.md, delta.md]
style: spec
---

# Session token limit: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first. One pull request per repo; the founder merges.

**Goal:** an agent or loop node can set `max_tokens`, and a session that passes it is stopped and fails with
`token-limit`.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `gungnir`:** add `MaxTokens int` (`yaml:"max_tokens"`) to `schema.Node`, validated as not negative, for
  agent and loop nodes only; add `Task.MaxTokens`; add the failure kind `token-limit`. Tests: a graph with
  `max_tokens` loads; a negative value, and the field on a node of another kind, are refused.
- [ ] **T2 `gleipnir`:** both adapters stop the tool when the usage read from its stream passes `Task.MaxTokens`
  (`0` is no limit) and end the session `failed` with `token-limit`, keeping the transcript and the usage so far.
  Tests with a stand-in tool that streams usage lines: a session under the limit ends `ok`; one over it is stopped
  and reports the kind and the usage; `0` never stops.
- [ ] **T3 `odin`:** pass `Node.MaxTokens` into `Task.MaxTokens` (next to `MaxTurns`, `session.go`), and treat
  `token-limit` as the agent's failure (a loop attempt; a node failure outside a loop), never as a hard stop.
  Tests: a loop with a node over its limit uses one attempt and continues; a plain agent node over its limit
  fails the node; the run caps count the stopped session's usage.
- [ ] **T4 `yggdrasil`:** fold the delta into spec §7.4, mark B-080 done, move the pointers, archive this folder.

## Open for the builder

- Whether the tool reports usage often enough to stop in time. `claude -p --output-format stream-json` and
  `opencode run --format json` may give usage only at the end of a turn. If so, the stop happens at the end of the
  turn that crossed the limit: say so in the pull request, and state how far a turn can overshoot.
- How to stop the tool cleanly in the sandbox (a signal to the process in the container), and how the adapter
  keeps what the session wrote to the workdir.
