---
title: Tasks for the role reasoning setting
status: draft
date: 2026-10-20
related: [proposal.md, delta.md]
style: spec
---

# Role reasoning: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first. One pull request per repo; the founder merges.

**Goal:** a role can set `reasoning:` and the OpenCode adapter sends that effort, with `high` when nothing is set.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `gungnir`:** add `reasoning` (enum `low`, `medium`, `high`, `off`) to the `role` definition in
  `schema/factory.schema.json` and a `Reasoning string` field to `schema.Role`. Tests in `schema/factory_test.go`:
  each of the four loads; a fifth value (`max`, an empty string) is refused; a role without it loads with the field
  empty.
- [ ] **T2 `gleipnir`:** add `Reasoning string` to `opencode.Config`; `ConfigJSON` writes
  `reasoning.effort` from it, `high` when empty, and no `reasoning` option for `off`. `New` refuses any other
  value. Tests next to `TestEverySessionNamesAReasoningEffort`: one per value, the default, `off` writes no
  `reasoning` key, and the privacy `strict` options are still written with each value.
- [ ] **T3 `odin`:** `agents.New` copies `role.Reasoning` into `opencode.Config`, as it does `Price`. Test in
  `internal/agents/agents_test.go`: a role with `reasoning: low` reaches the adapter.
- [ ] **T4 `yggdrasil`:** fold the delta into the spec, mark B-106 done, move the pointers, archive this folder.

## Open for the builder

- What `off` does on OpenRouter. Omitting the option gives the model its own default, which is the case that made
  `deepseek-v4-flash` answer "What would you like help with?" (gleipnir#16). Whether OpenRouter or opencode has a
  value that turns reasoning off (as opposed to omitting it) is not in the code. Check it against a real request
  and state the result in the pull request; if only omitting works, `off` means "the model's default", and the
  proposal and the spec text say so.
- Whether OpenRouter accepts `low` and `medium` for every model, or rejects an effort a model does not support.
  Only `high` has been tried (16 of 16 calls). A refusal would show as a failed session, so say whether the adapter
  should let it surface as it is.
- What `claude-code` does with the setting. Today `price` on a `claude-code` role passes the schema and the adapter
  ignores it, which is the precedent for ignoring. `claudecode.Agent` takes no config and passes no effort flag
  (only `--model` and `--max-turns`). Whether to ignore, or to refuse with a message when a `claude-code` role sets
  it (silent ignoring hides a setting that does nothing), is the builder's call after checking `claude -p`; state
  it in the pull request. `scripted` has the same question.
- Where to refuse for `claude-code`, if it refuses: the schema (an `if`/`then` on `agent`, like the `script` rule)
  fails at load with the file named; `agents.New` fails at run start.
