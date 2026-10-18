---
title: Delta for the base CI on every existing non-realm repo
status: proposed
date: 2026-10-18
related: [proposal.md, tasks.md, ../2026-10-18-repo-bootstrap/delta.md]
style: spec
---

# Delta: v0 spec §15.1 (as changed by `repo-bootstrap`)

## Added

- §15.1: every existing repo MUST have the base CI that `new-repo.sh` gives a new repo, with `lint`
  required, except a hidden repo, which the founder sets up by hand.
- §15.1: a shared lint config MAY depart from a linter's default only with a reason, written as a
  comment beside the setting.
- §15.1: a repo MAY exclude a folder of test inputs from markdownlint and yamllint, in a repo-owned
  file of its own. No file MAY be excluded from gitleaks or reuse.

## Modified

None.

## Removed

None.
