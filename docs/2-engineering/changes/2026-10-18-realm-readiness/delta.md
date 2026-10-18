---
title: Delta for the realm readiness checklist and the first assessments
status: accepted
date: 2026-10-18
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../2026-10-18-repo-bootstrap/delta.md]
style: spec
---

# Delta: v0 spec §9.4, §9.5

## Added

- §9.4: a realm repo MUST have `.github/workflows/ci.yml`, with one required job, `test`.
- §9.4: the `test` job MUST run the realm's own tests, and the template tests MUST NOT skip.
- §9.4: a build realm's leaf template MUST hold `.github/workflows/ci.yml`, with one job, `test`.
- §9.4: the template's `test` job MUST run on the images that the realm's stack pins.
- §9.4: every realm MUST have a readiness assessment against `docs/2-engineering/realm-readiness.md`.
- §9.4: the shared check scripts of the realms MUST be the same files. `check-repos.sh --check shared`
  MUST fail when they differ.

## Modified

- §9.5 rung 1: the paths that the ladder refuses to let a task change MUST include `.github/`.

## Removed

None.
