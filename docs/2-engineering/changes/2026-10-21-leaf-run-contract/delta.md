---
title: Delta for the leaf run contract
status: draft
date: 2026-10-21
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../realm-readiness.md]
style: spec
---

# Delta: v0 spec §9.4, and the realm readiness checklist

## Added

- §9.4: a build realm's template MUST hold an executable `run.sh` at the leaf's root. Run in the leaf with `PORT`
  set, it MUST build what the leaf needs without fetching packages, start the leaf's service in the foreground
  on `PORT`, accept a TCP connection on `PORT` within 60 seconds, and exit non-zero with a message when it
  cannot start. It MUST NOT read a secret or write outside the leaf and the temporary folders.
- §9.4: a build realm's tests MUST start `run.sh` from a copy of the template and wait for the port.
- Realm readiness checklist: **RR-23** (build): "Does the template ship an executable `run.sh` that starts the leaf
  on `PORT`, and does a test start it from a copy of the template?" Check: auto,
  `YGG_REQUIRE_TEMPLATES=1 go test -run RunScript ./...` in the leaf.

## Modified

- §9.4's pack layout line for `templates/`: "api and web leaf starters: lint/test/e2e config, AGENTS.md, init.sh"
  gains `run.sh`.

## Removed

None.
