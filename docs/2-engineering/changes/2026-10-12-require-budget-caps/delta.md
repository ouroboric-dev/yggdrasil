---
title: Delta for require budget caps
status: accepted
date: 2026-10-12
related: [proposal.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §7.4 Budget cap

## Added

- `factory.yaml` MUST set a per-run cap and a per-day cap.
- Each cap MUST set a turn limit and a token limit.
- If any role uses a paid API, each cap MUST also set a spend limit in dollars.
- If the caps are missing or incomplete, `ygg run` MUST NOT start a run.
- If the caps are missing or incomplete, `ygg resume` MUST NOT resume a run.
- In both cases, the command MUST name the missing fields and show how to set them.
- `ygg doctor` MUST report missing or incomplete caps as an error.
- The `factory.yaml` schema in `gungnir` MUST mark the caps as required.
- The factory MUST NOT ship default cap values.

## Modified

None.

## Removed

None.
