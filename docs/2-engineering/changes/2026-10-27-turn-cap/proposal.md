---
title: A session that reaches its turn cap says so, and is told its budget
status: draft
date: 2026-10-27
related: [delta.md, tasks.md, ../../backlog.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# A session that reaches its turn cap says so, and is told its budget

**Proposed 2026-10-27.** It fixes backlog [B-207](../../backlog.md). The shape below is a proposal; the founder
has not decided it.

## Why

- Proof run 1 (`20261025-113131-8e9cb7`) logged 18 `output_refused` events. Every one was a reviewer session that
  used 20 to 22 turns against `max_turns: 20` (`voluspa/software/graph.yaml`): 3 on OpenRouter's Qwen (T010), 15 on
  the local Qwen (T013 to T020). The backlog counted 3. In 4 nodes the repair session hit the cap too, and the node
  failed after being asked twice.
- At its step limit, OpenCode makes the last step text-only, with the tools turned off. The model writes
  "Maximum steps for this agent have been reached." and a summary of its work (seen in the run's ledger). It cannot
  call `submit` on that step. So "keep the last turn for the submit" is not possible in OpenCode, and the summary is
  then refused as "not a valid `ygg.review/v1`", which hides the real cause.
- `claude-code` at its turn limit ends as `error_max_turns`, which the adapter reports as a failed session of kind
  `agent` (`gleipnir/claudecode/claudecode.go`). The two adapters hand Odin different things for the same event,
  which v0 spec §5 forbids ("swapping one adapter for another cannot change what Odin receives").
- No prompt tells a session its turn budget. The answer instructions (`jormungandr.AnswerInstructions`) say how to
  hand back the answer, not by when.
- The repair session is a new session with the first prompt and the errors. After a cap it has none of the first
  session's reading, and it answered in 1 to 3 turns. Two of those repaired quality reviews (T013, T014) report no
  finding. A review written without reading is a weak pass, and v0 spec §4.6 says malformed output must not count
  as a pass.

## What changes

1. **A turn limit is its own failure kind.** `gungnir` gets the failure kind `turn-limit`, beside `token-limit`.
   An adapter MUST report a session that reached its turn cap without handing back its output as failed with
   `turn-limit`:
   - `opencode`: the session's steps reach `MaxTurns` and it called `submit` with nothing that validates. Its last
     text stays in `Result.Output`, as the session's notes.
   - `claude-code`: `error_max_turns` without a valid `submit` call.
   A session that submitted a valid output before its cap is not a failure.
2. **Odin logs the cause.** A `turn-limit` session of a node with a contract is logged as `output_refused` with the
   result "the session reached its turn cap (N turns) before handing back its output", and goes to the one repair
   session, as an invalid output does today. `ygg metrics` counts these apart from invalid outputs.
3. **The repair after a cap gets the notes.** Its prompt says the earlier session ran out of turns, quotes the
   earlier session's last text as data (clipped, made Markdown-safe like other inputs), and asks for the output
   from the work the notes describe, reading only what it must to confirm a finding. A repair that hits its cap
   too fails the node as an agent failure, as today.
4. **Every session that hands back a contract is told its budget.** The answer instructions name the cap: "You
   have N turns; each model step is one. Hand back your answer before turn N-2: a session that runs out of turns
   hands back nothing." The number comes from the node's `max_turns` in the graph, so no voluspa prompt changes and
   none can drift from the graph. A node without `max_turns` gets no budget line.

## Not in this change

- A new value for the reviewers' `max_turns`. It is measured with the reviewer bench once this change is in, and
  changed in `voluspa` on that evidence.
- A turn cap for the run or the day; those exist (§7.4).
- Changing OpenCode's own step-limit text.

## Impact

- **Repos:** `gungnir` (the failure kind), `gleipnir` (`opencode` and `claudecode` report it; the adapter contract
  suite covers it), `jormungandr` (the budget line in the answer instructions), `odin` (the log line, the repair
  prompt, the prompt wiring, `ygg metrics`), `yggdrasil` (spec, backlog, pointers).
- **Approval points:** none. The cap still ends the session.
- **Risk:** a model that obeys the budget line too well may cut its review short. The bench run after this change
  shows whether reviews got shorter or weaker.
