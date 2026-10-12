---
title: Delta for the remote creates and protects repos
status: accepted
date: 2026-10-12
related: [proposal.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §2.2, §4.2, §7, §15.1

## Added

- §2.2: `Remote` MUST be able to create a repo from an owner, a name, a visibility and a
  description. A created repo MUST be empty until Odin gives it its first commit.
- §2.2: `Remote` MUST be able to protect a repo: apply the standard settings and the `protect-main`
  ruleset. Protecting MUST be safe to repeat, and MUST fix drift.
- §4.2 `init`: Odin MUST create each new leaf through `Remote` before scaffolding it. Its first commit
  MUST hold only the files the realm's templates name for it, such as the licence files. Odin MUST
  protect the repo after the first commit and before any agent works on it.
- §7.1: a new hard approval point, `repo-admin`. It covers every `Remote` action that needs admin
  rights on a hosted repo, which includes creating and protecting one. The gate file MUST list the
  owner, name, visibility, description and first-commit files of each repo.
- §7.2: `ygg approve <run> repo-admin` MUST read a short-lived admin credential from the terminal,
  without echo. Odin MUST use it only for the approved action. It MUST NOT store, log or write it to
  the ledger or a gate file, or pass it to a sandbox or an agent.
- §7.2: if any repo named in the gate already exists, Odin MUST create none of them.
- §15.1: the `github` remote MUST implement create and protect. It MUST pass the cases of
  `ouroboric/scripts/create-repo.sh` and `setup-repo.sh`'s tests. When it ships, those scripts MUST
  be removed, and Ouroboric MUST create its repos with `ygg`.
- §15.1: the bots MUST NOT get Administration write.

## Modified

- §2.2: `type Remote interface { /* create, protect, commit, branch, push, open PR, merge, move pointer */ }`.
- §7.1: the hard approval points are `deploy-prod`, `store-submit`, `real-secrets-or-user-data`,
  `budget-cap`, `external-input`, `policy-violation`, `shrink-guard`, `guardrail-change` and
  `repo-admin`.

## Removed

None.
