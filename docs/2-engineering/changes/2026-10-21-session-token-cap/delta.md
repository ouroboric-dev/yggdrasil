---
title: Delta for the session token limit
status: draft
date: 2026-10-21
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §7.4, and the graph node fields

## Added

- §7.4: a node MAY set `max_tokens`. A session of the node MUST be stopped when its tokens (input plus output, not
  cache reads) pass the limit. The session ends as failed with the failure kind `token-limit`, and its usage counts
  against the run's caps. A loop treats it as a failed attempt. Outside a loop the node fails. It is not a hard
  approval point.
- The graph node fields (agent and loop, and a loop's reviewers): `max_tokens`, next to `max_turns`.

## Modified

None.

## Removed

None.
