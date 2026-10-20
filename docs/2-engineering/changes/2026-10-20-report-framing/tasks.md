---
title: Tasks for the report framing
status: draft
date: 2026-10-20
related: [proposal.md, delta.md]
style: spec
---

# Report framing: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first. One pull request per repo; the founder merges.

**Goal:** `ParseReport` ignores prose before the report and refuses everything else it refuses today.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `gungnir`:** change `unfence`/`ParseReport`. Failing tests first: a sentence then a fence parses; a
  sentence then a bare document parses; text after the fence fails; two fences fail; an unclosed fence fails; no
  document fails and is not an empty report; the existing strict cases still fail.
- [ ] **T2 `jormungandr`:** change the `ReportFormat` text and its test.
- [ ] **T3 `yggdrasil`:** fold the delta into the spec, mark B-105 done, move the pointers, archive this folder.
