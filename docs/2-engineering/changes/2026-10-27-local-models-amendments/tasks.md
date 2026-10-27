---
title: Tasks for the local models corrections
status: draft
date: 2026-10-27
related: [proposal.md, delta.md]
style: spec
---

# Local models corrections: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first. One pull request per repo, in the order below; the founder merges.

**Goal:** an `args` value may hold quotes, and the model server's tag changes with a non-default CUDA
architecture.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `gungnir`:** `plainValue` takes whether quotes are allowed, or `args` gets its own check; `file` keeps
  today's rule. Tests in `schema/models_test.go`: `{"enable_thinking":false}` and `'x'` pass in `args`; `#`, `;`,
  a line break, edge space and an empty value are still refused; a quote in `file` is still refused. The preset
  writes the value unchanged.
- [ ] **T2 `gleipnir`:** `ModelsImage(cudaArch string)`: the default (`""` or `"89"`) gives today's tag; any
  other valid value gives another tag; an invalid value is refused as `BuildModels` refuses it. `BuildModels`
  tags with the same function. Tests in `sandbox/models_test.go`, with today's tag pinned so the default never
  moves by accident.
- [ ] **T3 `odin`:** `ygg models image [--cuda-arch N]`; same value, same tag as `build`. Test in
  `internal/cli/models_test.go`.
- [ ] **T4 `yggdrasil`:** fold the delta, mark B-211 done and the tag part of B-215, move the pointers, archive
  this folder.
