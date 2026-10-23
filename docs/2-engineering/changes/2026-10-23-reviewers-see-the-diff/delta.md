---
title: Delta for the task reviewers seeing the task's diff
status: accepted
date: 2026-10-23
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §3.3 and §4.2

## Modified

- **§3.3, rule 4:** "Agents can then read `git log` and `git diff`" becomes: "An agent with a shell can then read `git
  log` and `git diff`. A read-only role has no shell (§5): Odin gives it what it needs to read, as §4.2 says for the
  task reviewers."

## Added

- **§4.2, the implement ⇄ check ladder:**
  - Odin MUST record the leaf's commit when a task's loop starts, before its first attempt, and MUST keep it across
    a resume.
  - Each task reviewer's prompt MUST hold a section "The change", with the diff from that commit to the attempt's
    commit: the changed files with their line counts first, then the diff.
  - Odin MUST compute the diff on the host with hooks, external diff drivers and text conversion turned off, so
    nothing in the leaf runs.
  - A diff over the cap (about 200 KB) MUST be cut at a file boundary, and the section MUST name the files left out.
    Binary files are named, not shown.
  - The conformance and reuse reviewers do not get the section.
