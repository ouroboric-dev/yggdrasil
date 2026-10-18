---
title: Delta for one command that creates, lints and protects a repo
status: proposed
date: 2026-10-18
related: [proposal.md, tasks.md, ../2026-10-12-remote-creates-repos/delta.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §4.2, §15.1 (as changed by `remote-creates-repos`)

## Added

- §4.2 `init`: a new repo's first commit MUST hold its licence files and its base CI.
- §4.2 `init`: the base CI MUST be `.github/workflows/lint.yml`, with one required job, `lint`.
- §4.2 `init`: the base CI MUST run the repo's pre-commit hooks, and gitleaks over the whole history.
- §4.2 `init`: language CI MUST be `.github/workflows/ci.yml`, with one required job, `test`.
- §15.1: the org, the licences, the copyright holder and the defaults MUST come from a config per
  owner. In `ouroboric/scripts`, this is `scripts/orgs/<org>.json`.

## Modified

- §15.1 (`remote-creates-repos`): the `github` remote MUST pass the cases of
  `ouroboric/scripts/new-repo.sh`, `create-repo.sh`, `add-licences.sh`, `add-ci.sh` and
  `setup-repo.sh`'s tests. When it ships, those scripts MUST be removed. The org config MUST become
  part of the operator's instance config.
- §15.1 (`remote-creates-repos`): protecting a repo MUST require `lint` when `lint.yml` exists, and
  `test` when `ci.yml` exists.

## Removed

None.
