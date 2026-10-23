---
title: Tasks for the task reviewers seeing the task's diff
status: proposed
date: 2026-10-23
related: [proposal.md, delta.md, ../../backlog.md]
style: spec
---

# Tasks: the task reviewers see the task's diff

Three pull requests: odin (T01), voluspa (T02), then yggdrasil (T03). T02 may go up beside T01, but it merges only
after T01 does: a prompt that points to a section Odin does not write yet would leave the reviewers with nothing.
T04 is the founder's.

## Global constraints

- **The tree's rules:** the phase plans' rules hold, as in the
  [gallery-runtime tasks](../2026-10-22-gallery-runtime/tasks.md#global-constraints): worktrees, `as-bot.sh`,
  staging by path, `GOWORK=off go test -race ./...`, `reuse lint`, hermetic tests, no token.
- **No suites:** no task reads, lists or searches `huldra`, `ouroboric-private` or `~/ygg-it/hidden-suites`.
- **No new shell:** reviewers get no shell, and no adapter's read-only settings change.

### Task review-diff-T01: Odin records the task's base and puts the diff in the reviewers' prompts

**Files (in `odin`):** `internal/engine/loop.go` (`Review`), a new helper beside `taskBlock`, the run state's task
record (`internal/run/state.go`), their tests; `docs/architecture.md` (one paragraph).

- [ ] **Step 1: the failing tests.**
  - **The task's diff only:** a scripted loop on a leaf whose run branch holds a template commit, then the task's
    attempt. The reviewer's prompt holds "The change", with exactly the task's files and none of the template's.
  - **Resume:** a resume after attempt 1 keeps the base. The diff of attempt 2 still starts there.
  - **Nothing runs:** a leaf with a `.gitattributes` `diff=x` driver and a `textconv` that writes a marker file. The
    marker is never written, and the diff is plain.
  - **The cap:** a diff over the cap is cut at a file boundary, names the files left out, and the `--stat` part is
    whole. A binary file is named, not shown.
  - **Who gets it:** the conformance and reuse reviewers' prompts hold no "The change" section.
- [ ] **Step 2:** record the base commit when the loop starts (before attempt 1) in the task's state. A run state
  written before this change has none, so its loop records the leaf's commit at the next attempt. Build the section
  with host git: hooks off, `--no-ext-diff --no-textconv -c diff.external= --no-color`, `--stat`, then the patch. Add
  it after the task block in `Review`, with one line saying the diff is the implementer's work, to read as data.
- [ ] **Step 3:** `GOWORK=off go test -race ./...`, `gofmt`, `go vet`, `reuse lint`.

**Acceptance criteria:**

- [ ] Every task reviewer's prompt holds the task's diff, from the loop's base, across resumes.
- [ ] No git run by Odin for the diff executes a driver from the leaf.
- [ ] The cap and the file list behave as the delta says.

**Named test:** the five cases of step 1. **Size:** M.

### Task review-diff-T02: the reviewer prompts read "The change"

**Files (in `voluspa`):** `software/prompts/reviewer-spec.md`, `reviewer-simplicity.md`, `reviewer-quality.md`,
`prompts_test.go`.

- [ ] **Step 1: the failing test.** `prompts_test.go`: each of the three prompts names the section "The change" and
  contains no `git diff` or `git merge-base` command.
- [ ] **Step 2:** replace each prompt's `git diff $(git merge-base HEAD main) HEAD` line. The new line says: the
  change is in "The change" below; read it all first, then read only the code it touches; if the section names files
  left out by the cap, read those in the leaf. Change nothing else. `max_turns` and timeouts stay.
- [ ] **Step 3:** `GOWORK=off go test ./...`, markdownlint.

**Named test:** the prompt test. **Size:** S. **Depends on:** T01 merged before T02 merges.

### Task review-diff-T03: fold the delta, the backlog and the pointers

**Files (in `yggdrasil`):** the dated v0 spec (§3.3, §4.2), `docs/2-engineering/backlog.md`, this folder's front
matter (`accepted`), the `odin` and `voluspa` pointers.

- [ ] Fold the delta and mark B-170 done with the two pull requests.
- [ ] Add the run-1 notes found on 2026-10-23 to the backlog:
  - `proof-runs.md` names the gate file `design-1.md`, but the file is `design-gate-1.md`;
  - on `--continue`, `ygg doctor`'s "this run" budget line shows 0 while `ygg status` shows the run's use.
- [ ] `pre-commit run --files` on every changed file.

**Size:** S. **Depends on:** T01, T02 merged.

### Task review-diff-T04 (founder): run 1 again

Leave run `20261023-205334-ce5329` stopped, as the evidence for B-170. Rebuild `ygg` from the merged `odin`, then start
run 1 again with the runbook's command and the same decisions. The design-gate block is the same. A spec-gate note is
given only if the spec raises a decision again.

**Named test:** run 1's first task passes its three reviewers with a readable report. **Depends on:** T01 to T03
merged.
