---
title: The remote creates and protects repos, behind a hard approval point
status: accepted
date: 2026-10-12
related: [../../specs/2026-10-11-yggdrasil-v0-spec.md, delta.md, tasks.md, ../../plans/2026-10-12-yggdrasil-v0/plan.md]
style: spec
---

# The remote creates and protects repos, behind a hard approval point

**Decided 2026-10-12:** Yggdrasil creates and protects repos itself, through `Remote`. Every action
that needs admin rights on a hosted repo stops at a new hard approval point, `repo-admin`. The admin
credential is supplied when a human approves, and it is never stored.

## Why

- A factory creates repos again and again: a leaf for each new component, and the repos of every
  company Asgard builds. Creating each one by hand doesn't scale.
- The spec's `Remote` (§2.2) commits, branches, pushes, opens PRs, merges and moves pointers. It
  doesn't create a repo or protect one. The `init` node (§4.2) scaffolds leaves, but doesn't say
  where their repos come from.
- Creating a repo and setting its rules need admin rights. The two bots in §15.1 deliberately don't
  have them. A credential with that power within an agent's reach would let a hijacked session create
  repos or switch off the rules of every repo it reaches.
- Ouroboric already does this with two founder-run scripts, `ouroboric/scripts/create-repo.sh` and
  `setup-repo.sh`. They are tested and work, but they belong to the company, not the factory.
  Operators should get the same thing from `ygg`.

## What changes

- `Remote` gains two operations:
  - **Create** a repo from an owner, a name, a visibility and a description. The new repo is empty
    until Yggdrasil gives it a first commit from the realm's templates (its licence files).
  - **Protect** a repo: apply the settings and the `protect-main` ruleset, fixing drift.
- New repos are always created, then given their first commit, then protected. Agents only ever get
  a protected repo.
- Every `Remote` action that needs admin rights on a hosted repo (create, protect) stops at
  `repo-admin`, a new hard approval point. The gate file lists the owner, the name, the visibility,
  the description and the first commit's files.
- `ygg approve <run> repo-admin` reads a short-lived admin credential from the terminal. Odin uses it
  for that action only, and never stores, logs or passes it on.
- The `local` remote (v0) creates a leaf as a new git repo in the instance tree. It needs no admin
  rights, so it needs no approval beyond the plan's.
- When the `github` remote ships (§15.1), it ports both scripts and their tests. Then the scripts are
  removed, and Ouroboric creates its own repos with `ygg`.

## Impact

- **Components:** Gungnir (the `Remote` interface, the approval point's name) and Odin (both remotes,
  `init`, `ygg approve`).
- **Approval points:** adds the hard `repo-admin`.
- **Operators:** approve each new hosted repo, and keep a way to make short-lived admin tokens.
- **Security:** neither bot ever gets Administration write. The admin credential exists only for
  the length of an approved action.
- **v0 plan:** task T001 joins Phase 2. Task T002 is iteration 2 work, listed in the plan so the
  scripts move once the `github` remote exists.
