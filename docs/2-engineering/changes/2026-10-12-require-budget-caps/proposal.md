---
title: Require budget caps before any run
status: accepted
date: 2026-10-12
related: [../../specs/2026-10-11-yggdrasil-v0-spec.md, delta.md, tasks.md]
style: spec
---

# Require budget caps before any run

**Decided 2026-10-12:** the factory refuses to run until the operator sets budget caps. It ships no
default caps.

## Why

The v0 spec (§7.4) defines how caps stop a run. It does not say what happens when no caps are set.
Operators own their budgets and are responsible for what they build, so each operator must choose
their limits consciously. Without this rule, a new operator's first run could have no limits. A
flaky check that re-runs the implementer could then use up a subscription's weekly quota overnight,
or run up an API bill, before the operator notices. This follows the charter principle "Safe by
default".

## What changes

- `ygg run` and `ygg resume` refuse to start when `factory.yaml` has no complete caps. They print how
  to set them.
- `ygg doctor` reports missing caps as an error.
- The `factory.yaml` schema in `gungnir` marks the caps as required.
- The factory ships no default caps. Example values in documentation are marked as examples.

## Impact

- **Components:** Odin (run start, resume, doctor) and Gungnir (the `factory.yaml` schema).
- **Approval points:** none change. `budget-cap` still stops a run that reaches a cap.
- **Operators:** must add caps to `factory.yaml` before their first run.
- **v0 plan:** includes the task in `tasks.md`.
