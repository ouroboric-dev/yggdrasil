---
title: Tasks for the remote creates and protects repos
status: accepted
date: 2026-10-12
related: [proposal.md, delta.md]
style: spec
---

# Tasks

## remote-creates-repos-T001: the local remote creates leaves (v0, Phase 2)

- **Acceptance criteria:**
  - [ ] Gungnir's `Remote` has `Create` and `Protect`, and `repo-admin` is a known hard approval
        point that config can't override.
  - [ ] The `local` remote's `Create` makes a git repo at the leaf's path, with one commit holding
        the realm's first-commit files and nothing else.
  - [ ] `Create` refuses a path that exists, and creates nothing.
  - [ ] The `local` remote's `Protect` reports that it doesn't apply, and changes nothing.
  - [ ] `init` creates each new leaf through `Remote` before scaffolding it.
- **Named test:** `odin/internal/remote/local_test.go`, `TestLocalCreateMakesLeafWithFirstCommit`
  and `TestLocalCreateRefusesExistingPath`; `gungnir/gate_test.go`, `TestRepoAdminIsHard`.
- **Layer:** `gungnir` (interface, approval point) and `odin` (local remote, `init`).
- **Size:** S.
- **Depends on:** Phase 2's tree walker.

## remote-creates-repos-T002: the github remote creates and protects repos (iteration 2)

- **Acceptance criteria:**
  - [ ] The `github` remote's `Create` and `Protect` pass every case of
        `ouroboric/scripts/tests/create-repo.test.sh`. Settings and rulesets match `setup-repo.sh`,
        and the check matches `check-repos.sh`'s `settings`, `security` and `ruleset` checks.
  - [ ] Odin stops at `repo-admin` before any request that needs admin rights, and the gate file
        lists each repo with its first-commit files.
  - [ ] `ygg approve <run> repo-admin` reads the credential without echo. The credential never
        appears in the ledger, gate files, reports, logs, process arguments, or a sandbox's
        environment.
  - [ ] If any named repo exists, nothing is created.
  - [ ] Neither bot's manifest asks for Administration write.
  - [ ] `ouroboric/scripts/create-repo.sh` and `setup-repo.sh` are removed, with their tests, and
        the docs standard's §9 points to `ygg`.
- **Named test:** `odin/internal/remote/github/create_test.go`, `TestCreateMatchesScriptCases`;
  `odin/internal/gate/repo_admin_test.go`, `TestRepoAdminStopsBeforeAdminRequests` and
  `TestAdminCredentialNeverRecorded`.
- **Layer:** `odin` (github remote, approve) and `ouroboric` (script removal).
- **Size:** M.
- **Depends on:** remote-creates-repos-T001 and the `github` remote of spec §15.1.
