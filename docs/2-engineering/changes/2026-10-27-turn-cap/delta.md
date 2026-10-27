---
title: Delta for the turn cap
status: draft
date: 2026-10-27
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §5, §7.4 and §12

## Added

- §5, **The output channel**, after the item "An output that does not validate MUST be asked for once more …":
  **Turn cap.** A session that reaches its node's `max_turns` without a valid `submit` call MUST end as failed with
  the failure kind `turn-limit`, from every adapter, and its last text MUST be kept as its notes. Odin MUST treat
  it as an output that does not validate, with the cause named in the ledger, and the session that asks once more
  MUST be told the earlier session ran out of turns and be given its notes as data.
- §5, **The output channel**, a new item: the instructions for handing back an output MUST name the node's
  `max_turns` when it has one, and MUST say that a session that runs out of turns hands back nothing.
- §7.4, after the `max_tokens` paragraph: a session stopped by `max_turns` before it hands back a contract's output
  ends as `turn-limit` (§5). It counts against the run's caps.
- §12, a row after "Agent failure": "Turn limit (a session at `max_turns` with no valid output) | asked once
  more with the session's notes (§5); then an agent failure".

## Modified

- §12, the row "Agent failure (non-zero exit, timeout, malformed output)": a turn limit is no longer an agent
  failure on its first occurrence.

## Removed

None.
