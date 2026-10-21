---
title: Tasks for the leaf run contract
status: draft
date: 2026-10-21
related: [proposal.md, delta.md]
style: spec
---

# Leaf run contract: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first. One pull request per repo; the founder merges.

**Goal:** both build realms' templates ship a `run.sh` that starts the leaf on `PORT`, with a test, and the
readiness checklist asks for it.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `helheim-go`:** `templates/api/run.sh` (build the binary into a temporary folder, run it on `PORT`).
  Test `TestRunScriptStarts` (name it so `-run RunScript` finds it): copy the template, run `run.sh` with a free
  port, wait for the port, stop it. Skip without a toolchain; fail with `YGG_REQUIRE_TEMPLATES=1`. Update the
  implementer prompt and `docs/architecture.md`.
- [ ] **T2 `midgard-react`:** `templates/web/run.sh` (build the bundle if the leaf needs it, serve it on `PORT`).
  Same test and docs. The leaf's dependencies are installed by `init.sh`, not by `run.sh`.
- [ ] **T3 `yggdrasil`:** add RR-23 to `realm-readiness.md`; fold the delta into spec §9.4; mark B-078 done; add
  B-116 (the per-software and project grades); move the pointers.

## Open for the builder

- The simplest server the `web` leaf can use to serve a built bundle with no extra package. If it needs one, say
  so: no package is to be fetched at start.
- Whether `run.sh` for the Go leaf may run `go build` when the module cache is empty and there is no network. If
  the template's dependencies are standard library only, yes. Otherwise state what the leaf needs.
