---
title: Tasks for disputed findings
status: draft
date: 2026-10-20
related: [proposal.md, delta.md]
style: spec
---

# Disputed findings: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first in every task. One pull request per repo; the founder merges.

**Goal:** a disputed finding is settled by a named check that passed, or stops the run with both sides recorded.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `gungnir`:** the `overruled` finding status and its `Validate` rule; the `disputes` document and its
  parser (strict, like `ParseReport`, with a JSON schema); the `finding-overruled` event; the `finding-disputed`
  reason. Test: a valid dispute parses; a missing field, an unknown field and a second document fail.
- [ ] **T2 `jormungandr`:** `Book.Dispute` applies a verified dispute: the finding closes as `overruled`. A
  reviewer report that repeats an overruled claim does not reopen it, and one that cites a later failing check
  does. `Steps` gains the way to read the attempt's disputes. Tests: the `findIndex` scenario ends as `passed`,
  not `attempts-exhausted`; a dispute that does not hold leaves the finding open; a dispute no check can settle
  ends as `Escalated` with `finding-disputed`.
- [ ] **T3 `odin`:** read the disputes from the implementer's last answer; after the checks, verify each one (the
  check passed in this attempt, its output contains the test id); write the ledger events; put both sides in the
  escalation text and in `ygg report`. Test: a stand-in implementer that disputes with a real passing check.
- [ ] **T4 prompts:** the implementer prompt explains the `disputes` document. The reviewer prompt says a blocker
  repeated after a dispute needs proof. Test: the prompt tests of `jormungandr`.
- [ ] **T5 `yggdrasil`:** fold the delta into the spec, mark B-104 done, move the pointers, archive this folder.

## Open for the builder

- Whether the implementer's last answer is where Odin reads the disputes from today. If the session result does
  not keep the last answer, the smallest channel that does is a file the implementer writes outside the leaf's
  tracked files. State the choice in the pull request.
