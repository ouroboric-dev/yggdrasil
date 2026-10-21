---
title: Delta for the dependency bump sandbox
status: draft
date: 2026-10-21
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §9.6

## Added

- §9.6: a dependency bump MUST run its package manager, its scripts and the realm's checks in the product's
  sandbox (§6). `ygg deps bump` MUST refuse with exit code 2 when `factory.yaml` has no `sandbox:` section and
  `--host` is not given. It MUST refuse before it takes the runs lock, creates a folder or writes a ledger line.
- §9.6: with `--host`, a bump MAY run on the host, with no sandbox. The ledger of the bump MUST then hold a line,
  before any product is touched, that says it ran on the host.
- §14: the threat table's supply-chain row (dependency policy, canary rollout) gains the sandbox for the bump as
  a control, next to §9.6.

## Modified

None.

## Removed

None.
