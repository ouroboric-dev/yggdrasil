---
title: Engineering backlog
status: accepted
date: 2026-10-16
related: [plans/README.md, changes/README.md, plans/2026-10-15-yggdrasil-v0-phase-2/tasks.md]
---

# Engineering backlog

Small defects and gaps that a review found and the team chose not to fix yet. Nothing here blocks a
phase. Each item is graded **Minor** by its effect on a person using the factory.

## How to use this file

- Pick an item when you touch the code it names, or when a phase has room.
- An item that changes behavior the spec states MUST go through a [change proposal](changes/README.md).
- Fix an item with a failing test first. Then move it to [Done](#done) with the pull request's link.
- Add new items at the end of **Open**, with the next number. Never reuse a number.
- Each item says whether the reviewer **proved** it with a probe or only **reasoned** about it.

Code locations are pinned to the commits named in each section, because lines move. Search by the
function name if a line has moved.

## Open

Source of items B-001 to B-014: the final review of Phase 2 (2026-10-16), one fresh reviewer over
`gungnir` `e5ee578..8631647` and `odin` `6bd481d..5076219`. The review found no Critical issue and
six Important issues. All six were fixed before merge. These fourteen were left.

Odin line numbers are at `odin` `5076219`. Gungnir line numbers are at `gungnir` `8631647`.

### B-001: `.factory/` can be committed by an operator

- **Where:** `internal/run/run.go` (`Start`, `record`). Run records live in `<project>/.factory/`.
- **Problem:** `.factory/` sits untracked in the project umbrella. It holds ledgers, transcripts,
  locks and each exec node's `HOME` (`.factory/runs/<id>/home`, which collects toolchain caches).
  Odin's own commits use pathspecs, so Odin never adds it. An operator's `git add -A` in the project
  adds all of it.
- **Why it matters:** decision 19 has the operator push the tree. Ledgers and caches would leave the
  machine in an ordinary commit.
- **Fix:** at the first run, add `.factory/` to the project's `.git/info/exclude`. That file is local
  and is not a commit, so it is not a write to the operator's history. Test: after `Start`,
  `git check-ignore .factory/runs` succeeds in the project.
- **Status:** reasoned.

### B-002: commits onto a detached HEAD

- **Where:** `internal/remote/local.go` (`Create`), `internal/pointer/pointer.go` (`Move`).
- **Problem:** a sub-project checked out by `git submodule update` is on a detached HEAD. Leaf
  creation and pointer moves commit in that umbrella, on the detached HEAD.
- **Why it matters:** the operator's next `git submodule update` in the root checks out the recorded
  commit and orphans the commits Odin made.
- **Fix:** refuse, or warn loudly, when an umbrella that Odin commits to has no branch checked out.
- **Status:** reasoned.

### B-003: `Local.Create` can fail halfway and leave the project hard to recover

- **Where:** `internal/remote/local.go` (`Create`, the `submodule add` and `absorbgitdirs` steps, then
  `Save` and the commit).
- **Problem:** if a step after `submodule add` fails, the gitlink and `.gitmodules` stay staged in the
  project and `.git/modules/<path>` exists. A retry is refused ("exists"). Every pointer move is
  refused too ("staged changes Odin didn't make"). The error does not say how to undo it.
  `submodule add` also stages all of `.gitmodules`, so a person's unstaged edits to it are committed.
- **Fix:** on failure after `submodule add`, run `git rm --cached -f`, restore `.gitmodules`, and
  remove the module directory. At least, print those steps in the error.
- **Status:** reasoned.

### B-005: `Prepare` writes before it takes the project lock

- **Where:** `internal/run/run.go` (`Prepare` calls `findProject`, which calls `tree.Resolve`).
- **Problem:** `Resolve` runs `git submodule update --init` before `Start` takes the locks. The
  comment on `Prepare` says "It writes nothing". Two starts at once can collide on `index.lock`.
- **Fix:** move the checkouts after the locks are taken, or change the comment and accept the race.
- **Status:** reasoned.

### B-006: a parent project's graph can bypass a sub-project's locks

- **Where:** `internal/run/run.go` (`LockFile`, `RunsLock`).
- **Problem:** lock names are keyed by the path from the project. A parent project's graph can name a
  leaf inside a sub-project (`repo: projects/sub/repos/app`). That run and a run in the sub-project
  use different `runs.lock`, `repo-*.lock` and pointer locks for the same leaf and umbrella.
- **Fix:** key the leaf and umbrella locks by the canonical git dir. Or refuse a repo path that
  crosses a child umbrella with its own `.factory/`.
- **Status:** reasoned.

### B-007: submodule names are not validated

- **Where:** `internal/tree/tree.go` (`submodule`, where `name` comes from `.gitmodules`).
- **Problem:** Odin builds `GitDir` as `<parent git dir>/modules/<name>` from the name in
  `.gitmodules`. A name with `..` points outside `.git/modules`. Git itself refuses such names, but
  Odin uses the derived path directly.
- **Fix:** apply git's `check_submodule_name` rule before building the path.
- **Status:** reasoned.

### B-008: `ParseUmbrella` can accept a child inside a child

- **Where:** `schema/umbrella.go` in `gungnir` (the sorted-neighbour check in `ParseUmbrella`).
- **Problem:** the check compares each path only with the one before it in sorted order. The
  characters `-` and `.` sort before `/`. So `a` (umbrella), `a-b` and `a/b` parse without an error.
- **Fix:** compare each path with every earlier path, or sort by path segments. This is a `gungnir`
  change: it needs its own pull request, then a new pin in `odin`.
- **Status:** proved.

### B-009: `pointer.Move` turns the shrink guard off when `git show` fails

- **Where:** `internal/pointer/pointer.go` (`Move`, the `git show HEAD:<file>` call).
- **Problem:** the code ignores the error. A file that is new in the move has no previous rows, which
  is correct. But any other failure also reads as zero rows, so the guard passes.
- **Fix:** tell "the path is not in HEAD" apart from other errors, for example with
  `git cat-file -e HEAD:<file>`. Return the other errors.
- **Status:** reasoned.

### B-010: ledger gaps around landings

- **Where:** `internal/engine/land.go` (`runPointer`).
- **Problem, three parts:**
  1. A `shrink-guard` stop returns before it logs `node_failed`, so the attempt that `node_started`
     opened never closes in the ledger.
  2. A pointer move that committed, but whose `run.json` save was lost, is skipped on resume: the
     pointer is already there, so `res.Commit` is empty and no `pointer_moved` line is written.
  3. `Waived` is cleared only when the move succeeds. A waiver therefore outlives a failed attempt.
     If the generated files change before the retry, the guard is skipped for different content.
- **Fix:** log `node_failed` before the hard stop. On resume, log `pointer_moved` when the pointer is
  already at `To` and the ledger has no such line. Clear `Waived` on any outcome other than a stop.
- **Status:** reasoned.

### B-011: `doctor` reports a live run's half-written ledger line as an error

- **Where:** `internal/cli/doctor.go` (`ledger.Verify` at line 67 runs before the `run.Locked` check
  at line 71).
- **Problem:** while a run appends to its ledger, `doctor` can read a torn last line and print ERROR.
- **Why it is here:** it was a Phase 1 deferred minor. Phase 2 decision 16 did not list it.
- **Fix:** skip the verify, or print WARN instead, when `run.Locked(dir)` is true.
- **Status:** reasoned.

### B-012: the output after a hard stop suggests `ygg reject`

- **Where:** `internal/cli/cli.go` (the message for `run.StatusStopped`, line 237).
- **Problem:** the message always prints both `ygg approve` and `ygg reject`. A hard stop that a node
  raised (`policy-violation`, `shrink-guard`) refuses `reject`.
- **Fix:** when the pending approval point is hard, print only `approve`, plus "start a new run to
  drop the work".
- **Status:** reasoned from the code. `engine.Reject` does refuse a hard stop.

### B-013: `lock.Held` can miss a held lock on some filesystems

- **Where:** `internal/lock/lock.go` (`Held`).
- **Problem:** `/proc/locks` prints the superblock's device number. On btrfs, `stat` reports the
  subvolume's anonymous device, and overlayfs with `xino` has a similar mismatch. The ids then never
  match, and `Held` returns false for a held lock.
- **Effect:** `status` and `doctor` call a live run "interrupted; ygg resume". The resume is still
  refused by `flock`, so the only harm is a misleading line.
- **Fix:** match on the inode number alone, then confirm through the listed pid's `fdinfo` or fd
  links.
- **Status:** reasoned. Not reproduced on this machine.

### B-014: one engine test always waits five seconds

- **Where:** `internal/engine/engine_test.go` (`TestRunJSONRecordsTheRunningExecProcess`, the `peek`
  script).
- **Problem:** the wait loop looks for `../.factory/...`, but the command runs in `repos/app`, so the
  path is one level short. The loop never matches and sleeps its full five seconds. The `cat` that
  follows uses the right path, so the test still checks the right file.
- **Fix:** change `../.factory` to `../../.factory` in the wait loop.
- **Status:** proved.

Source of items B-015 to B-031: the final review of Phase 3 (2026-10-16), one fresh Opus reviewer over `gungnir` `8631647..768edab`, `havamal` `0940ffe..e7b4e47`, `gleipnir` `968aee0..7653026` and `odin` `5076219..e10a881`. It found one Critical and five Important issues, all fixed before merge; these are the Minor ones, plus two follow-ups the fixer noted (B-030, B-031). Line numbers are not recorded: search by name.

### B-015: two leaves can share a sandbox

- **Where:** `gleipnir/sandbox/config.go, driver.go`.
- **Problem:** `Project()` and the config folder name collapse punctuation, so `repos/web-app` and `repos/webapp` share a compose project; one leaf's `Up` or `Down` tears down the other's sandbox.
- **Fix:** Keep punctuation distinct (hash the path). Test: `TestTwoLeavesNeverShareASandboxProject`.
- **Status:** reasoned.

### B-016: a probe that could not run counts as a closed network

- **Where:** `gleipnir/sandbox/driver.go`.
- **Problem:** The closed-network check accepts exit 125 (podman or `timeout` could not run the probe) as closed, against decision 5's "or can't be tried".
- **Fix:** Refuse exit 125. Test: `TestUpRefusesAProbeThatCouldNotRun`.
- **Status:** reasoned.

### B-017: podman's own failure reads as the command's exit code

- **Where:** `gleipnir/sandbox/driver.go`.
- **Problem:** Exit 125 from podman comes back as the command's exit code, so an infrastructure failure reads as a check or node failure (spec §12).
- **Fix:** Return an error for a missing container. Test: `TestExecReportsAMissingContainerAsAnError`.
- **Status:** reasoned.

### B-018: a read-only role's change to an ignored file is not caught

- **Where:** `odin/internal/engine/engine.go`.
- **Problem:** The read-only check uses `git status --porcelain` without `--ignored` (decision 11: "any change").
- **Fix:** Add `--ignored`. Test: `TestAReadOnlyRoleThatWritesAnIgnoredFileIsAHardStop`.
- **Status:** reasoned.

### B-019: a failed session with tokens and no cost passes as $0

- **Where:** `gleipnir/opencode/opencode.go`.
- **Problem:** Decision 10's refusal is skipped when the session failed.
- **Fix:** Refuse it too. Test: `TestAFailedSessionWithTokensAndNoCostIsRefused`.
- **Status:** reasoned.

### B-020: a session killed by its timeout reports no usage

- **Where:** `gleipnir/claudecode, gleipnir/opencode, odin/internal/engine/engine.go`.
- **Problem:** The caps never count what a timed-out session spent.
- **Fix:** Parse the partial stream. Test: `TestATimedOutSessionStillCountsItsUsage`.
- **Status:** reasoned.

### B-021: session output is buffered in host memory without a bound

- **Where:** `gleipnir/claudecode/claudecode.go, opencode.go`.
- **Problem:** A chatty session can exhaust the host's memory.
- **Fix:** Bound the buffer. Test: `TestSessionOutputIsBounded`.
- **Status:** reasoned.

### B-022: opencode may download unpinned language servers

- **Where:** `gleipnir/opencode/opencode.go`.
- **Problem:** `OPENCODE_DISABLE_LSP_DOWNLOAD` is not set, so opencode can fetch language servers through an allowed registry.
- **Fix:** Set it. Test: `TestTheOpencodeSessionDisablesLSPDownloads`.
- **Status:** reasoned.

### B-023: the factory layer does not pin npm's transitive dependencies or apt packages

- **Where:** `gleipnir/sandbox/images.go, assets/Containerfile`.
- **Problem:** The image tag claims to hash every input, but those inputs are not pinned.
- **Fix:** Pin them (lockfile, snapshot repos). Test: `TestTheFactoryLayerPinsEveryPackage`.
- **Status:** reasoned.

### B-024: IPv6 is never opened and a missing `ip6tables` is skipped

- **Where:** `gleipnir/sandbox/assets/egress.sh`.
- **Problem:** Decision 5 says IPv4 and IPv6; a missing `ip6tables` should fail closed.
- **Fix:** Fail closed without `ip6tables`; open IPv6 for listed hosts. Test: `TestEgressFailsWithoutIp6tables`.
- **Status:** reasoned.

### B-025: DNS and shared-CDN addresses leave exfiltration channels (accepted risk)

- **Where:** `gleipnir/sandbox/assets/egress.sh`.
- **Problem:** DNS to the resolver and 443 to shared CDN addresses can carry data out.
- **Fix:** Record as an accepted risk of decision 5, or tighten with a DNS allowlist.
- **Status:** reasoned.

### B-026: `CheckEvals` trusts the recorded gain and pass flag

- **Where:** `havamal/eval.go`.
- **Problem:** It does not recompute them from the arm counts.
- **Fix:** Recompute. Test: `TestCheckEvalsRecomputesTheGain`.
- **Status:** reasoned.

### B-027: an unreadable directory in a leaf wedges checkpoint and resume

- **Where:** `odin/internal/leaf/leaf.go`.
- **Problem:** `checkNested` aborts with a plain error instead of a policy stop.
- **Fix:** Return a policy violation. Test: `TestAnUnreadableDirectoryInTheLeafIsAPolicyViolation`.
- **Status:** reasoned.

### B-028: a hung engine hangs `ygg` in `Down`

- **Where:** `gleipnir/sandbox/driver.go, odin/internal/engine/engine.go`.
- **Problem:** `Down` runs under `context.WithoutCancel` with no timeout.
- **Fix:** Add a bounded timeout. Test: `TestDownGivesUpOnAHungEngine`.
- **Status:** reasoned.

### B-029: the escape test accepts ExitStopped

- **Where:** `odin/internal/cli/sandbox_e2e_test.go`.
- **Problem:** The hostile `devcontainer.json` may never reach `main`, and the `features.json` probe checks a path the agent could not reach anyway.
- **Fix:** Tighten `TestSandboxEscapes`: assert the merge landed and check probe 5's output.
- **Status:** reasoned.

### B-030: an inline `gitleaks:allow` comment hides a finding

- **Where:** `gleipnir/scan`.
- **Problem:** gitleaks 8.30.1 has no flag to turn the comment off.
- **Fix:** Check for the comment in the file list, or move to a gitleaks version with a switch.
- **Status:** reasoned.

### B-031: `/tmp` and `/go` survive between commands

- **Where:** `gleipnir/sandbox`.
- **Problem:** Only HOME and the XDG folders are emptied before each command (final review I4).
- **Fix:** Empty them too, or mount them as tmpfs.
- **Status:** reasoned.

## Done

### B-004: check output in a leaf blocks the next run

- **Where:** `internal/engine/land.go` (`runMerge` and `runPointer` run pack checks in the leaf).
- **Problem:** nothing checkpoints the leaf after those checks. Any non-ignored file a check writes
  stays in the leaf. The next run's `StartBranch` then refuses with "uncommitted changes".
- **Fix:** run `git clean -fd` in the leaf after the checks, or run the checks in a fresh worktree.
  Phase 3's sandbox may change where checks run, so decide there.
- **Status:** fixed by Phase 3 v0-T090 (the leaf is put back to the checks' commit after a node's checks), [odin#7](https://github.com/ouroboric-dev/odin/pull/7).

