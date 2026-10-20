---
title: Delta for the role reasoning setting
status: draft
date: 2026-10-20
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §5

## Added

- §5, after the `factory.yaml` example and the **Usage** and **Privacy** items: **Reasoning.** A role MAY set
  `reasoning:` to `low`, `medium`, `high` or `off`. The default is `high`. A `factory.yaml` with another value
  MUST be refused when it loads. The `opencode` adapter MUST pass the value to the model as the reasoning effort of
  every request of the role, and with `off` MUST pass none.

## Modified

- §5, the roles example: one role MAY show `reasoning: medium`, so the setting is visible where roles are
  introduced.

## Removed

None.
