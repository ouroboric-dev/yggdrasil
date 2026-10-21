---
title: Tasks for the dependency bump sandbox
status: draft
date: 2026-10-21
related: [proposal.md, delta.md]
style: spec
---

# Dependency bump sandbox: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first. One pull request per repo; the founder merges.

**Goal:** `ygg deps bump` refuses without a sandbox unless `--host` is given, and a host bump says so in its ledger.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `odin`:** `internal/cli/deps.go`. Add `--host` (a bool in `flags`). Refuse with exit 2, before the
  runs lock, when `cfg.Sandbox == nil` and no `--host`, with the message in the proposal. Write the host line at the start of the ledger of a host bump.
  Tests first, in `internal/cli/deps_test.go`:
  - no sandbox section and no `--host`: exit 2, the message, no `.factory/deps` folder, no lock held;
  - no sandbox section and `--host`: the bump runs as today (the existing host tests, now with `--host`);
  - a sandbox section and no `--host`: runs in the sandbox as today;
  - a sandbox section and `--host`: runs in the sandbox, and the ledger has no host line;
  - a host bump's ledger starts with the host line; a sandbox bump's ledger has none;
  - a bump that is cancelled, or whose sandbox fails to start (`bump.go`, the cancel and sandbox-error return
    paths), writes a closing line, so `FindUnfinished` (odin #29) no longer reports it. Keep `unfinished.go` and
    its round-trip test in step with any change to the started line or the host line.

  Update the existing `deps bump` tests that have no sandbox section (about 20 calls in `deps_test.go` and
  `bump_report_test.go`). Update `odin/README.md` (usage line and a sentence on `--host`) and
  `odin/docs/architecture.md` (the `deps bump` paragraph). `docs_test.go` checks the docs name `ygg deps bump`:
  keep it passing and add `--host` to its list.
- [ ] **T2 `yggdrasil`:** fold the delta into spec §9.6 and §14; mark the first bullet of B-084 done; move the
  pointers; archive this folder.

## Open for the builder

- **How the host line is written.** The ledger line type `gungnir.Event` has no field for it. A line with the
  existing event `deps_bump`, a `Verdict` of `host` and a note, needs no change in `gungnir`. But `Verdict` is
  documented as pass or fail, and `FindUnfinished` (`deps/unfinished.go`) takes the last `deps_bump` line with no
  verdict as an unfinished bump. A new event name or field is cleaner and puts `gungnir` in the order of merges. Choose
  one, and say so in the pull request. Do not put it in `Note` of the started line: `FindUnfinished` parses that
  note to get the product.
- **Where the line is written.** The ledger is created at the first `Log` call, so that a refusal leaves nothing
  (`cli/deps.go`). The host line must go in that same place, so a refusal in `Bumper.plan` still leaves no trace.
- **`--host` with a sandbox section.** The flag has no effect and the bump runs in the sandbox. Say so in the
  usage text.
- **Whether `doctor` and `status` say that a leftover bump ran on the host.** B-074 (odin #29) lists unfinished
  bumps through `FindUnfinished`; that code does not read the host line. Not part of this change.
