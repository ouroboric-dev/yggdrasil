---
title: Tasks for operators' projects staying theirs, and the factories accepting issues
status: accepted
date: 2026-10-15
related: [proposal.md, delta.md]
style: spec
---

# Tasks

None of these tasks is tied to a phase of the v0 plan.

## factory-issues-T001: the repo scripts turn issues on for the factories

- **Acceptance criteria:**
  - [ ] `setup-repo.sh` sets `has_issues` true for `yggdrasil` and `asgard`, and false for every
        other repo.
  - [ ] `check-repos.sh --check settings` passes a factory repo only with issues on, and any other
        repo only with issues off.
  - [ ] The docs standard's §9 and the legal page's "Contributions" section say issues are open on
        the factories, while outside pull requests stay closed until a contributor licence agreement
        is in place.
- **Named test:** `ouroboric/scripts/tests/setup-repo.test.sh` and `check-repos.test.sh` cover a
  factory repo and another repo, and fail before the change.
- **Layer:** `ouroboric`.
- **Size:** S.
- **Depends on:** this change merged.

## factory-issues-T002: the issue forms

- **Acceptance criteria:**
  - [ ] `yggdrasil` and `asgard` each have `.github/ISSUE_TEMPLATE/bug.yml` and `improvement.yml`,
        GitHub issue forms that ask for the factory version and config hash, and warn against pasting
        a private project's code, data or secrets. `config.yml` turns off blank issues.
  - [ ] No workflow, app or bot acts on a new issue.
- **Named test:** the forms are valid YAML with the fields GitHub's issue-form schema requires
  (`name`, `description`, `body`), checked by a test in `ouroboric/scripts/tests/`.
- **Layer:** `yggdrasil`, `asgard`.
- **Size:** S.
- **Depends on:** this change merged.

## factory-issues-H01 (founder): issues on

- **Acceptance criteria:**
  - [ ] Issues are on in `yggdrasil` and `asgard`.
- **Named test (agent-run):** `as-bot.sh --read all scripts/check-repos.sh --check settings` passes
  for every repo.
- **Layer:** GitHub.
- **Size:** S.
- **Depends on:** factory-issues-T001 and T002 merged. Run `scripts/setup-repo.sh yggdrasil` and
  `scripts/setup-repo.sh asgard` with the short-lived admin token.
