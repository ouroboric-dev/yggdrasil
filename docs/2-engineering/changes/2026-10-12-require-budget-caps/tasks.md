---
title: Tasks for require budget caps
status: accepted
date: 2026-10-12
related: [proposal.md, delta.md]
style: spec
---

# Tasks

## require-budget-caps-T001: refuse to run without complete caps

- **Acceptance criteria:**
  - [ ] `ygg run` with no caps in `factory.yaml` exits non-zero, starts no run and names the missing fields.
  - [ ] `ygg run` with a per-run cap but no per-day cap behaves the same way.
  - [ ] `ygg run` with a paid-API role and no spend limit behaves the same way.
  - [ ] `ygg resume` refuses in the same cases.
  - [ ] `ygg doctor` reports missing or incomplete caps as an error.
  - [ ] The `factory.yaml` schema rejects a file without caps.
  - [ ] With complete caps, `ygg run` starts normally.
- **Named test:** `odin/internal/run/caps_test.go`, `TestRunRefusesWithoutCompleteCaps`; schema case in
  `gungnir/schema/factory_test.go`, `TestFactorySchemaRequiresCaps`.
- **Layer:** `odin` (run, resume, doctor) and `gungnir` (schema).
- **Size:** S.
- **Depends on:** the v0 plan's tasks that load `factory.yaml` and add `ygg run`, `ygg resume` and
  `ygg doctor`.
