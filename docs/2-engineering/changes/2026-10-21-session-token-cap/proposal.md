---
title: A session can be given a token limit
status: draft
date: 2026-10-21
related: [delta.md, tasks.md, ../../backlog.md]
style: spec
---

# A session can be given a token limit

**Proposed 2026-10-21.** It fixes backlog [B-080](../../backlog.md).

## Why

- The budget caps (spec §7.4) count a whole run and a whole day. They are checked between sessions. One session can
  spend most of a run's tokens before the next one starts, and nothing stops it while it runs.
- A session already has two bounds: `max_turns` (the adapter's own flag) and `timeout`. Neither bounds tokens. A
  model that writes a lot per turn (GLM 5.3 Flash wrote up to 18.5k tokens in one session) spends far more per turn
  than the turn count says, and the run caps are in tokens.
- Unattended proof runs leave a flaky session alone for a long time. A bound per session limits what one bad session
  can take.

## What changes

- **A node setting `max_tokens`** (agent and loop nodes, as `max_turns`): the most tokens one session of the node
  may use, input plus output, not counting cache reads. `0` or absent: no per-session limit (today's behaviour).
- **The adapters stop a session that crosses it.** Both adapters read the tool's usage lines as the session streams.
  When the running total passes `max_tokens`, the adapter stops the tool, keeps what it wrote to the workdir and the
  transcript, and ends the session as failed with a new failure kind, `token-limit`.
- **What the engine does with `token-limit`:** the session counts as an attempt of the agent that used it. A loop
  spends one attempt on it and goes on with the next, as it does for any failed attempt. A node outside a loop
  fails. It is not a hard stop: the run's `budget-cap` stays the only hard stop for money and quota.
- **The run caps still count what the stopped session used**, from the usage it reported before it stopped.

## Decisions taken here (change them in review)

- **A limit per node, not per node kind.** The graph already holds `max_turns` per node, and Voluspa writes the
  graphs. A factory-wide default is not added: one more place to set the same number.
- **Tokens counted: input plus output.** Input is what the session sent, which grows with every turn, so a long
  session crosses the limit through its context too. That is the wanted effect.
- **A stopped session is a failure that costs an attempt**, not an escalation: an attempt that ran out of tokens is
  the same kind of event as one that ran out of turns.

## Not in this change

- **A limit in dollars per session.** The run caps cover dollars. A token limit is the unit both adapters report.
- **Setting `max_tokens` in a Voluspa graph.** The setting exists after this change. Which numbers the graphs carry
  is for the proof runs to show.

## Impact

- **Repos:** `gungnir` (the node field, the failure kind, `Task.MaxTokens`), `gleipnir` (both adapters),
  `odin` (pass it through, treat the failure kind), `yggdrasil` (spec, backlog, pointers).
- **Order:** `gungnir` merges first. `gleipnir` and `odin` then bump their pin of it.
- **Approval points:** none new.
- **Risk:** a limit set too low ends every attempt of a node. The stop is visible: the failure names the limit and
  the tokens used.
