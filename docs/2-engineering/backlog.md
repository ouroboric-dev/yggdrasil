---
title: Engineering backlog
status: accepted
date: 2026-10-16
related: [plans/README.md, changes/README.md, plans/2026-10-15-yggdrasil-v0-phase-2/tasks.md]
---

# Engineering backlog

Small defects and gaps that a review found and the team chose not to fix yet. Nothing here blocks a
phase, with one exception: [B-061](#b-061-since-odin-15-the-first-tasks-acceptance-run-sees-the-other-new-leaf-without-its-template)
blocks real runs of the client gallery, and Phase 5c's real runs, until it is fixed. Each other item is graded
**Minor** by its effect on a person using the factory.

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
- **Status:** reasoned. Phase 5a (2026-10-17) leaves `Prepare` as it was; still open. Phase 5b (2026-10-18) leaves it as it was too.

### B-006: a parent project's graph can bypass a sub-project's locks

- **Where:** `internal/run/run.go` (`LockFile`, `RunsLock`).
- **Problem:** lock names are keyed by the path from the project. A parent project's graph can name a
  leaf inside a sub-project (`repo: projects/sub/repos/app`). That run and a run in the sub-project
  use different `runs.lock`, `repo-*.lock` and pointer locks for the same leaf and umbrella.
- **Fix:** key the leaf and umbrella locks by the canonical git dir. Or refuse a repo path that
  crosses a child umbrella with its own `.factory/`.
- **Status:** reasoned. Phase 5a (2026-10-17) leaves the lock names as they were; still open. Phase 5b (2026-10-18) leaves them as they were too.

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

### B-011: `doctor` reports a live run's half-written ledger line as an error

- **Where:** `internal/cli/doctor.go` (`ledger.Verify` at line 67 runs before the `run.Locked` check
  at line 71).
- **Problem:** while a run appends to its ledger, `doctor` can read a torn last line and print ERROR.
- **Why it is here:** it was a Phase 1 deferred minor. Phase 2 decision 16 did not list it.
- **Fix:** skip the verify, or print WARN instead, when `run.Locked(dir)` is true.
- **Status:** reasoned.

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
- **Status:** reasoned. Phase 5b (2026-10-18): the work container's DNS is now answered by the firewall's
  sidecar (dnsmasq) from the allowed hosts and the services, and nothing else. This closes the channel to the
  container's own resolver. Two gaps remain, from Phase 5b's final review: `server=/<service>/` forwards a
  service name's whole subtree to the podman resolver (M-3), and an address refresh leaves the old addresses
  answerable for a moment (M-2; see B-048).

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

### B-034: minor findings of Phase 4's final review

- **Where:** the list is in `.superpowers/sdd/tasks-2026-10-16-yggdrasil-v0-phase-4/final-review/review.md`
  (M1 to M10); it is kept there until the founder consolidates the ledgers.
- **Problem:** M1 `run.json` saved late after `Spend`; M2 a result that fails `Validate` counts zero usage;
  M3 a session with no turns left gets no turn bound; M4 a cut-short journal line merges with the next append;
  M5 a severity downgrade lets a loop pass without proof; M6 approving a read-only violation keeps the ignored
  file; M7 a check's log and a gate file can be overwritten; M8 `Tidy` resets to HEAD, not to the checkpoint;
  M9 `Retrier.Do` treats a failed `infra` result with no error as a success; M10 the day's dollar cap counts
  subscription estimates.
- **Fix:** each finding's Fix line in that file.
- **Status:** reasoned. M3 and M5 are fixed (the cleanup before Phase 5): M3 a session the caps leave no
  turns for doesn't start, [odin#10](https://github.com/ouroboric-dev/odin/pull/10); M5 an open finding
  keeps its highest severity, [jormungandr#6](https://github.com/ouroboric-dev/jormungandr/pull/6). M1, M2,
  M4 and M6 to M10 are open.

Source of items B-035 to B-039: the
[Asgard v0 design doc §10](../1-product/design/2026-10-17-asgard-v0-design.md#10-what-yggdrasil-needs-later)
(accepted 2026-10-17). They are not review findings: they are what Yggdrasil must support before the
`kickstart` graph (named Ginnungagap until 2026-10-18) can run on Odin. None is Yggdrasil v0 work. Pick them up with the Asgard realm's
graph, or earlier when a phase touches the code they name.

### B-037: gate nodes assume an operator at a terminal

- **Where:** `odin` gate nodes, `ygg approve` and `ygg reject`.
- **Problem:** In the Asgard realm the founder approves direction (`charter`, `brand`, readiness), and
  the founder may never use a terminal. The design doc's v0 answer is a merge of a pull request in the
  GitHub web page from the founder's own account.
- **Fix:** Let a gate be approved by a recorded action outside the CLI, such as a merged pull request,
  and record who approved it in the ledger.
- **Status:** requirement. Phase 5a (2026-10-17) still stops at a gate for an operator at a terminal; open
  (Phase 5b/5c or later). Phase 5b (2026-10-18) adds no change here.

### B-039: the factory runs on WSL2 only

- **Where:** `gleipnir/sandbox` (the Podman socket and the bind-mount path), `ygg doctor`.
- **Problem:** The photographer may run the factory on a shared MacBook with Podman. Yggdrasil v0
  targets WSL2, with the instance tree bind-mounted under `/mnt/wsl`.
- **Fix:** Support the Podman machine on macOS: its socket, its mount paths, and `ygg doctor` checks.
- **Status:** requirement. Phase 5a (2026-10-17) still runs on WSL2 only; open (Phase 5b/5c or later). Phase 5b (2026-10-18) adds no change here.

### B-040: admin actions on repos need the founder at a computer

- **Where:** `ouroboric/scripts` (`create-repo.sh`, `setup-repo.sh`), `ouroboric/.github/workflows`, the
  pr-bot's permissions.
- **Problem:** Creating and renaming a repo needs an admin token that the founder types into a terminal
  (`create-repo.sh`, `setup-repo.sh`). From the phone the founder can't run them, and the agents must never
  hold Administration rights: the same permission changes and deletes rulesets, including the rule that a
  push needs someone else's approval.
- **Fix (decided 2026-10-17, variant A):** a `workflow_dispatch` workflow in `ouroboric` that creates a repo
  (`create-repo.sh`, then `setup-repo.sh`), renames one, or adds one to the pr-bot, and does nothing else (no
  delete, no weaker ruleset). Its admin credential (a small separate GitHub App with Administration write,
  so it does not expire) is a secret of an environment that only `main` may use and that names the founder
  as required reviewer. The pr-bot gets `Actions: write` on `ouroboric` only, so an agent starts a run and
  the founder approves it with one tap in GitHub mobile. The founder adds the workflow file (the bot can't
  push workflows); the script changes go in an `ouroboric` PR with tests.
- **Update (2026-10-18, change `repo-bootstrap`):** the workflow runs `new-repo.sh --org ouroboric-dev`,
  which replaces `create-repo.sh` then `setup-repo.sh`. The App also needs Contents and Workflows write,
  because the first push holds `.github/workflows/lint.yml`.
- **Status:** requirement (the founder follows up later).

Source of item B-041: the final review of Phase 5a (2026-10-17), one fresh Opus reviewer over `gungnir`,
`gleipnir`, `jormungandr` and `odin` on the Phase 5a branches, and a scoped re-review of its fix wave. The
review found one Critical and six Important findings; all were fixed before merge. The Minor findings are
left. The two reports are in the SDD workspace (`final-review/review.md` and `re-review.md`).

### B-041: minor findings of Phase 5a's final review

- **Where:** as listed; `odin` is `internal/...`, `gungnir` is `schema/...`, `gleipnir` is `sandbox/...`.
- **Problem and fix, one line each (all Minor; M-1 to M-12 are from the review, N-1 to N-6 from the re-review):**
  - M-5 a `publish` target at or under a leaf writes into the leaf before the umbrella's `git add` fails: refuse it at prepare.
  - M-6 `run/sandbox.go` keys a scratch sandbox `scratch/<node>`, which can also be a leaf path: use a key a repo path cannot be. Phase 5b adds the snapshot sandbox's `snapshot/<node>` key, which has the same problem: fix both.
  - M-9 `engine/returns.go` logs `node_returned` before `run.json` is saved: save first, or tolerate the duplicate on resume.
  - M-10 `plan/expand.go`: an expanded id that clashes with a graph node id fails the foreach node instead of sending the plan back: check it in the tasks node.
  - M-11 (unverified) `cli/cli.go` (`blockedTasks`) prints a task's `Why` to the terminal as is: strip control characters.
  - M-12 `schema/tasks.go` recognises only backtick fences, so a heading inside a `~~~` fence reads as a task.
  - N-2 `run.Unexpand` leaves state keyed by the old task node ids: a new plan that reuses a task id inherits it (for example, a node that spent its returns).
  - N-3 test gaps: the I-1 test would also pass if `main` were reset to the run's base; gleipnir's render passes every test if it stops calling `literalEnv`; no test covers an Odin failure on the pointer path or a Tidy failure not being sent back.
  - N-4 if a task's pointer has moved and a later loop of the same task gives up, `mainBack` moves `main` below the commit the umbrella points at (the current graph shapes cannot do it).
  - N-6 (before Phase 5a) compose still expands `$` in rendered volume paths and labels.
  - M-13 (from the pre-5b cleanup's review) a `run.json` written before `new_leaves` existed loads with an empty record: a leaf an older run created before a crash never gets its template, and the run can still finish `done`. Bump the `run.json` schema or fail the resume.
  - M-14 a `new_leaves` entry stays after a failed create and could send the template into a repository someone later puts at that path: drop the entry when the create fails.
  - M-15 `engine/publish.go` leaves the `<scratch>/.publish` staging folder after the scan: remove it.
  - M-16 (defence in depth) `os.OpenRoot` follows a symlink at `out/` itself and links between folders inside the root if something swaps them while Odin reads; the driver kills every process after each exec today, so nothing can. It becomes Important if a later phase leaves a process running.
- **Status:** reasoned (M-11 unverified).

Source of items B-042 to B-047: the Phase 5b plan (2026-10-17), where each was left out on purpose.

### B-042: the docs rung has no Vale prose rules

- **Problem:** the docs rung checks structure and links but not prose style.
- **Fix:** add Vale with the factory's rules to `docs.sh` in both realms. **Status:** requirement.

### B-043: the scripts both realms copy

- **Problem:** `helheim-go` and `midgard-react` each hold a copy of `docs.sh` and other shared scripts, and they drift.
- **Fix:** one home for them (a realm both depend on, or a vendored directory with a drift check). **Status:** requirement.
- **Interim fix (2026-10-18):** helheim-go's copy is the source. midgard-react's `docs.sh` is the same file byte
  for byte (midgard-react #9), and `check-repos.sh --check shared` fails when a realm's copy differs (ouroboric #48).
  The readiness assessments of 2026-10-18 find RR-09 met in both realms.
- **Not run in CI (2026-10-19):** nothing runs `check-repos.sh --check shared` on a schedule or on a change. See
  [B-068](#b-068-nothing-in-ci-runs-check-repossh---check-shared).
- **Full fix:** Ginnungagap's shared base stage (Ginnungagap design §7). Every realm's Containerfile starts from
  it, so the shared check scripts have one source. **Status:** narrowed to the full fix.

### B-044: packages in the stack images are not pinned

- **Problem:** the images pin their bases and downloads but install apt packages (and Chromium through
  `playwright install --with-deps`, with no hash) at whatever version the mirror serves.
- **Fix:** pin apt packages by version, and the browser download by hash. **Status:** requirement.
- **Readiness (2026-10-18):** this is midgard-react RR-14 (`partial`). The web stage installs `ca-certificates`,
  `curl` and `git` with `apt-get` at the mirror's version, and `playwright install --with-deps chromium` adds
  Chromium's system libraries the same way. `npm install -g` names exact versions of Prism and Playwright, but
  their own dependencies have no lock file. The realm's own CI (`.github/workflows/ci.yml`, step `apt`) installs
  six packages with `apt-get` at the mirror's version too. helheim-go's stack installs no packages: RR-14 is
  `met` there.

### B-045: TypeScript is held at 5.9 by `openapi-typescript`

- **Problem:** `openapi-typescript` 7 asks for TypeScript 5, so the web template cannot move to 6.
- **Fix:** move when `openapi-typescript` supports it. **Status:** requirement.

### B-046: no initializer agent customizes a leaf's `AGENTS.md`

- **Problem:** a new leaf starts with the template's `AGENTS.md` and only the first task may change it.
- **Fix:** an initializer agent in the realm's graph. **Status:** requirement.

### B-047: an implementer cannot read the project's design documents

- **Problem:** a task states what it needs, and the design documents live outside the leaf.
- **Fix:** a way for a task to name the documents it needs and have them copied into the scratch input. **Status:** requirement.
- **Note (2026-10-19):** Phase 5c did not change this. The real-agent run (v0-H17) is the place to watch it: see
  whether an implementer of the smoke task misses a document the brief cites.

Source of item B-048: the final review of Phase 5b (2026-10-18), one fresh Opus reviewer over the six repos and
two scoped re-reviews of its fix wave. The review found 2 Critical and 6 Important findings. The Critical ones
and the Important ones were fixed before merge (helheim-go #3, midgard-react #7, odin #14). The reports are in the
SDD workspace (`final-review/review.md`, `re-review.md`, `re-review2.md`).

### B-048: config protection is a path list, and minors of Phase 5b's final review

- **Where:** as listed; `odin` is `internal/...`, `gleipnir` is `sandbox/...`.
- **Problem and fix, one line each:**
  - The parked Important finding (config protection is a path list) is B-049.
  - **Fixed (odin #15, 2026-10-18).** M-1 `run/sandbox.go`: the snapshot takes each other leaf at its working copy's `HEAD`, not the commit the
    umbrella records, and skips a leaf that is not checked out silently: use the gitlink, refuse an absent leaf.
  - M-2 `egress.sh`: on a refresh, old addresses leave the rules before dnsmasq gets the HUP: keep both for a cycle.
  - M-3 `egress.sh`: `server=/<service>/` forwards a service name's subtree to the podman resolver: write the
    resolved addresses into the hosts file and drop the `server=` lines.
  - M-4 `sandbox/stackbuild.go`: the Containerfile parser does not know `# escape=` or heredocs, so an unpinned
    `FROM` can hide: refuse parser directives and `<<`.
  - M-5 `engine/conformance.go`: `os.OpenRoot` follows a symlinked `out`: open the root at the scratch dir.
  - M-6 `web-tdd.sh`: only `.ts`/`.tsx` under `src/` count as code: count `.js`, `.jsx`, `.mjs` and code outside `src/`.
  - M-7 see B-044 (Chromium download with no hash).
  - M-8 `ponytail-review/SKILL.md`: a `shortcut:` comment the task's own diff adds turns a finding into a
    decision: say in `reviewer-simplicity.md` that it does not count.
  - M-9 `accept-e2e.sh` reports an oasdiff parse error as a broken contract; `web-e2e.sh` runs `mktemp -d`
    before the busy-port check and leaks the folder; a `snapshot/<node>` sandbox keeps its Postgres and
    SeaweedFS up until `Advance` returns, and the database's state carries over between attempts.
  - Residual (re-review 2): the scripts honour a `YGG_CHECKS_PATH` override that the engine never sets; keep it
    out of the images or drop it once the stubs have another seam.
- **Status:** reasoned.

### B-049: the check ladder protects its lint and build configs by a list of paths, which is incomplete

- **Where:** `helheim-go/devcontainer/checks/go-static.sh`, `go-tdd.sh` and `.golangci.yml`;
  `midgard-react/devcontainer/checks/web-protected.sh`. Found by Phase 5b's final review (2026-10-18), parked
  after two fix rounds (`final-review/re-review.md`, `re-review2.md` in the SDD workspace).
- **Problem:** the agent can edit the config files the ladder reads, and the checks refuse changes to a list of
  paths. The list is incomplete: a Go config replaced by a symlink, or hidden by `.gitignore`, passes; ESLint 10
  obeys an added `src/eslint.config.js`; a handwritten `internal/store/querier.go` with a forged sqlc header
  gets no test, lint or sqlc check (the lint path list skips it).
- **Why it matters:** rung 1 (and the TDD check) can be turned green by an agent that tampers with its own
  config. The reviewers still read the diff, which is the only net left.
- **Fix:** run the linters with configs baked into `/opt/ygg/checks`, where the agent cannot write, and pass them
  explicitly (`golangci-lint --config`, `eslint --no-config-lookup -c`, and so on); recompute sqlc's output path
  from the generator (`sqlc diff`) instead of a path list. Test: each of the three bypasses above fails its rung.
- **Status:** fixed (helheim-go #4, midgard-react #8, 2026-10-18). Each ladder now uses the lint and build configs
  baked into `/opt/ygg/checks/config` and passes them explicitly; the template copies are pinned to them by a test.
  helheim-go decides what sqlc owns by regenerating from the base commit's `sqlc.yaml` (`sqlc-owned.sh`) and
  comparing bytes. Open consequence: in midgard-react an edit to a tool config is now ignored, not refused, and the
  template's `AGENTS.md` does not say so. Not run: the image build and `web-e2e.sh`/`accept-e2e.sh` end to end.
  (Was: proved, the re-reviewer reproduced the symlink, `.gitignore` and `src/eslint.config.js` cases.)

Source of items B-050 and B-051: the founder's runs v0-H14 and v0-H15 on a real engine (2026-10-18).

### B-050: a realm is loaded from its working folder, so ignored build output breaks the run

- **Where:** `odin/internal/realm/realm.go` (the loader that refuses a symlink in a realm), `midgard-react/templates/web`.
- **Problem:** the loader reads whatever is in the realm's folder. `npm ci` in a template leaves `node_modules`
  (242 MB, full of `.bin` symlinks) and `dist`, both git-ignored. v0-H15 stopped at once: `…/templates/web/node_modules/.bin/acorn is a symlink; a realm holds its own files and folders`.
  Anyone who builds a template in place breaks every run until they clean up by hand.
- **Fix:** load a realm from its committed files (`git ls-tree` and `git cat-file`, as the snapshot export does)
  when the realm folder is a git repository, so ignored and untracked files are not part of it; keep the symlink
  refusal for the committed files. Test: a realm folder with an ignored `node_modules/.bin/x` symlink loads, and a committed symlink is still refused.
  Until then, the tests of a template must build in a copy (v0-T225's build test does; the in-place `vitest` runs of v0-T224 did not).
- **Status:** fixed (odin #15, 2026-10-18). A realm folder that is a git repository is hashed from `HEAD`; a
  committed symlink is still refused. Added with it: a tracked file that differs from `HEAD` is refused, because a
  run reads the folder but the hash is of the commit. Not tested: a realm that is a submodule (`.git` is a file).
  (Was: proved, v0-H15 stopped on it.)

### B-051: the first `devcontainer up` of a run hangs about half the time, cause unknown

- **Where:** `gleipnir/sandbox/driver.go` (`Up`), the devcontainer CLI 0.89.0 on rootless Podman 5.7.1, WSL2.
- **Problem:** `devcontainer up` hangs after `podman compose up -d` has started the containers, until
  `UpTimeout` kills it. First seen in the sandbox spike (item 1: "the next `devcontainer up` succeeded in
  seconds"). In v0-H14 `TestSandboxBuildsARealmsStackAndStartsALeafOnIt` hung in at least 5 of 9 runs; the other two engine
  tests, which start later in the same process, never did. Gleipnir #10 limits the damage (an attempt gets two
  minutes, then `Down` and one retry; the retried run passed).
- **What was observed at a hang:** both containers were `Up`, and the engine's event log held both `start`
  events, but the `podman events --filter event=start` process the CLI had started was still waiting
  (`futex_do_wait`) and the CLI sat in `epoll_wait`, using no CPU. No memory pressure (8 GB free, PSI 0), no OOM kill; WSL2 distros share one VM, so the
  machine's "2 GB" setting is not a limit. Twenty trials of starting `podman events` and a container together
  missed no event, so a plain subscribe race is not it.
- **Not known:** whether the CLI does not read the events or podman does not write them (the bytes-written
  probe was armed after the hang). Next step: catch a hang with `/proc/<pid>/io` (`wchar`) of the events process
  and the unread bytes of its stdout pipe, and try a newer devcontainer CLI or `--docker-compose-path` with `podman compose` itself.
- **What the CLI does (read from the 0.89.0 source, 2026-10-18):** `devcontainer up` starts
  `podman events --format json --filter event=start` before the compose build, then waits for one `start` event
  whose container carries the compose project and service labels (the labels come from the event's
  `Actor.Attributes`, or from an inspect of the container). Nothing else ends that wait: if the event is not
  delivered or not matched, the CLI waits until `UpTimeout`.
- **Session of 2026-10-18 (time-box of two hours, used about 1.5):** `ouroboric/scripts/ygg-events-watch.sh`
  (ouroboric #44) samples the events process from before the run. 23 trials of `TestSandboxBuildsARealmsStackAndStartsALeafOnIt`:
  one hang (trial 1 of the first batch, 140 s: the 120 s wait, `Down`, a retry that took 2 s), 22 passes of about 15 s.
  - At the hang the events process sat in `futex_do_wait` for 118 s with `unread=0` (nothing waiting in its stdout).
    So the CLI had left no bytes unread: either podman delivered nothing, or the CLI read the lines and did not
    accept them (not matched, or an inspect that threw: its `catch` only calls `console.error`). `/proc/PID/io` does not
    exist on this kernel, so `wchar` could not tell the two apart.
  - Ruled out: a plain subscribe race (earlier, 20 trials); an engine that was idle for 15 min (one cold trial: 16 s);
    an events stream that was idle for 13 min before the next container start (an independent subscriber got both
    `start` events 5 s after the trial began).
  - The rate was about 1 in 23 here, against about 5 in 9 in v0-H14. What differed in H14 is not known; the hang may
    need the full run of the three engine tests, or a first build of the images.
- **Next step:** catch another hang with a second, independent subscriber running (`podman events` with a time
  stamp per line, as in this session) so that its log shows whether podman delivered the events; run the CLI with
  `--log-level trace` (it then logs `startEventSeen#data`); try a newer devcontainer CLI. Try the first run after
  building the images, and the three engine tests together.
- **Status:** proved (a hang, not its cause); not reproduced at the H14 rate on 2026-10-18. The retry of gleipnir #10
  still limits it to a two-minute delay.

Source of items B-052 to B-054: the base-CI rollout ([change](changes/2026-10-18-base-ci-rollout/proposal.md)),
its tooling review and its final steps (2026-10-18). Lines are at `ouroboric` `7508c77`.

### B-052: a global git URL rewrite can send the repo scripts' pushes over SSH, around the token

- **Where:** `ouroboric/scripts/new-repo.sh` (the credential-helper push), `ouroboric/scripts/as-bot.sh`, and
  `ouroboric/scripts/rollout-ci.sh` (`cred_git`).
- **Problem:** the founder's global git config has `url.git@github.com:.insteadOf https://github.com/`. A script
  that pushes to `https://github.com/…` with the token in a credential helper then goes over SSH with whatever key
  ssh-agent holds, and may prompt for a passphrase on `/dev/tty`, which `exec </dev/null` does not stop.
  - `rollout-ci.sh` overrides `insteadOf` for its org (`-c url.$GIT/$RC_ORG/.insteadOf=$GIT/$RC_ORG/`), so its
    pushes keep to the token. It does not override `pushInsteadOf`, which git applies to push URLs first.
  - `new-repo.sh` overrides neither. `as-bot.sh` overrides `insteadOf` but not `pushInsteadOf`.
- **Fix:** give every git call that carries the token both overrides for the org's base URL (`insteadOf` and
  `pushInsteadOf`), in one shared helper if the scripts can share it. Test: a `GIT_CONFIG_GLOBAL` that rewrites the
  base URL, once with `insteadOf` and once with `pushInsteadOf`, to a wrong path; the push must still land in the
  right bare repo. `rollout-ci.test.sh` has the `insteadOf` case to copy.
- **Status:** proved for `insteadOf` (the tooling review: `git ls-remote --get-url` returned the `git@` URL on the
  founder's machine). Reasoned for `pushInsteadOf`, which no config uses today.

### B-053: `md-same-text.py` copies the plan tools' fence pattern, and nothing catches a drift

- **Where:** `ouroboric/scripts/md-same-text.py` (the copy of the fence regex) and `ouroboric/scripts/plan-blocks.py:16`.
- **Problem:** md-same-text proves a Markdown change is formatting only. For plan code, it compares blocks as the plan
  tools find them, with a copy of their regex (`` ^(`{3,4})(\w*)\n(.*?)\n\1$ ``). The copy is needed because
  `plan-blocks.py` has a hyphen and cannot be imported. If one of the two changes alone, md-same-text checks blocks the
  plan tools do not see, and a change to plan code can pass as formatting, which is the gap the rollout found once.
  Also untested: that a bare plan fence given `text` (the one allowed info change) still reads `same`.
- **Fix:** a test in `md-same-text.test.sh` that the pattern in both files is the same string; or move the pattern
  into a module both import (`plan_fence.py`). Add the `text` case for a plan-style block.
- **Status:** reasoned (the follow-up's review, ouroboric #53).

### B-054: `huldra` has no base CI

- **Where:** the private repo `huldra` (the hidden benchmark suite).
- **Problem:** the rollout covered the ten public non-realm repos. Agents must never read `huldra`, so it was left out,
  and it still has only the gitleaks pre-commit hook, with no `lint` check and nothing required.
- **Fix (founder only):** in a clone, on a branch, run `scripts/add-ci.sh --org ouroboric-dev --ci reuse,markdown,shell,actions,yaml --upgrade .`
  and fix what the hooks flag. Push the branch and open the pull request with the founder's own token, not with
  `rollout-ci.sh push`: that opens pull requests as the pr-bot, which must never have access to `huldra`. After the
  merge, run `scripts/rollout-ci.sh --org ouroboric-dev protect huldra`, which uses the founder's token only.
- **Status:** open, by design.

Source of items B-055 to B-062: the realm readiness assessments of 2026-10-18 (`readiness/2026-10-18-*.md`),
over `helheim-go` `60731f6`, `midgard-react` `26ca85e` and `asgard` `3e614b4`. Each item names the realm and the
checklist item ([realm-readiness.md](realm-readiness.md)).

### B-056: the leaf templates carry no "Built with Ouroboric" notice

- **Where:** `helheim-go/templates/api`, `midgard-react/templates/web`. Readiness: helheim-go and midgard-react,
  RR-18.
- **Problem:** each template has the MIT `LICENSE`, but no file carries the notice that the
  [licence map](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/1-company/legal/README.md) promises:
  "Templates include a 'Built with Ouroboric' notice by default". `grep -ri 'built with ouroboric'` finds it in
  neither template.
- **Fix:** add the notice where a product shows it (for example the template's `README.md` or the web app's
  footer), and a template test that finds it. **Status:** proved (the grep).

### B-057: helheim-go's own CI skips the tests that need sqlc and golangci-lint

- **Where:** `helheim-go/.github/workflows/ci.yml` (the plain `golang` image). Readiness: helheim-go, RR-04.
- **Problem:** five tests of the check ladder skip in CI, because the image has neither tool:
  `TestTDDExemptsOnlyWhatSqlcGeneratesAndCountsItsSQLAsCode`, `TestSqlcOwnedListsOnlyFilesThatAreByteForByteWhatSqlcGenerates`,
  `TestStaticLintsWithTheBakedConfigAndSkipsOnlyVerifiedSqlcOutput`, `TestStaticLintsWhatTheLeafTriedToHide` and
  `TestTheUnchangedTemplatePassesStaticAndTDDAndItsSqlcOutputIsOwned`. The run on `main` (39166450363) shows
  `--- SKIP` for each. They pass on a machine with sqlc 1.31.1 and golangci-lint 2.14.0, the stack's pins.
- **Why it matters:** these tests guard B-049's fix (the sqlc and lint bypasses). The required check `test` passes
  without them, so a change that breaks that fix can merge.
- **Fix:** run the realm CI in the built stack image, or install sqlc and golangci-lint at the stack's pins and
  hashes in the job. Then make the five tests fail, not skip, when `YGG_REQUIRE_TEMPLATES` (or a new variable) is
  set. **Status:** proved (the CI log).
- **Amended (2026-10-19, the realm-readiness final review):** one of the five, `TestTheUnchangedTemplatePassesStaticAndTDDAndItsSqlcOutputIsOwned`,
  is a template test (`-run Template` matches it). It skips in CI through `needTools` (`checks_test.go`), which
  ignores `YGG_REQUIRE_TEMPLATES`. So the change's delta §9.4 ("the template tests MUST NOT skip") is not met in
  helheim-go until this item lands. Also, helheim-go's `docs/architecture.md` does not say that five tests skip in
  CI: it says only that `YGG_REQUIRE_TEMPLATES` makes the template tests fail instead of skipping. Say it there.

### B-058: helheim-go's product CI has no SeaweedFS, and its test does not check the steps

- **Where:** `helheim-go/templates/api/.github/workflows/ci.yml`, `helheim-go/ci_test.go` (`TestTemplateCI`).
  Readiness: helheim-go, RR-18.
- **Problem and fix, one line each:**
  - The pack gives the leaf Postgres and SeaweedFS. The product CI starts only Postgres, because a GitHub service
    container cannot take SeaweedFS's `command`. Today's template has no S3 test, so nothing fails yet. A product
    that adds S3 integration tests fails in CI. Fix: start SeaweedFS in a step (`docker run` with the pinned digest
    and its command), or say in the template's `AGENTS.md` that S3 tests stay out of the product CI.
  - `TestTemplateCI` checks the image, the services, the pins and the permissions, but not the step commands.
    midgard-react's test checks each `run:` line. Inside the realm, `templates/api/.github/` is not under rung 1, so
    the test is the only guard: a change that drops the lint or the integration step passes. Fix: check each step's
    command, as midgard-react's test does.
  - **Widened (2026-10-19, the realm-readiness final review):** align `TestTemplateCI` with midgard-react's test in
    these gaps:
    - It does not read govulncheck's version from the Containerfile (the Containerfile pins `v1.8.0`, and the
      template's `ci.yml` repeats it).
    - The Postgres env and `YGG_DATABASE_URL` are literals checked with `strings.Contains`. Read them as whole lines
      from `pack.yaml` and `go-integration.sh`.
    - The `uses:` regex misses `-   uses:` (more than one space after the dash), and the pin regex is not anchored
      to the value.
    - It checks no triggers, no `timeout-minutes` and no step commands.
    - The hash is not tied to the `sha256sum -c` line.
- **Status:** reasoned.

### B-059: two base images were pinned when they were less than two weeks old, and no check reads an image's age

- **Where:** `midgard-react/devcontainer/Containerfile` and both realms' CI (`node@sha256:efd0ab57…`);
  `helheim-go` and `midgard-react` (`golang:1.26.9-bookworm@sha256:d9c68c2c…`). Readiness: midgard-react, RR-13.
- **Problem:** the registry gives the Node image's creation time as 2026-10-06. Phase 3's plan (2026-10-16) took
  it from spike B and says it was more than two weeks old when pinned. It was at most 10 days old then, and 11 days
  old when midgard-react pinned it on 2026-10-17. The Go image was made on 2026-10-08 and pinned at 9 days old, under the founder's waiver (Phase 5b
  plan, decision 12), because 1.26.9 fixes standard-library vulnerabilities. Both are older than two weeks from
  2026-10-22. The checklist asks for each digest's age, and no script reads it: the assessment read the image
  config from the registry by hand.
- **Amended (2026-10-19):** the Node digest was first pinned in the sandbox spike
  (`docs/5-research/2026-10-12-sandbox-spike.md`, the `FROM` line at about line 489), at about 6 days old, not in
  Phase 3.
- **Fix:** a script in `ouroboric/scripts`, with a test, that prints each digest's creation time from its registry
  and fails under two weeks unless a waiver is named. RR-13 then runs it. **Status:** proved (the registry's
  creation times).

### B-060: asgard is not a realm leaf yet

- **Where:** the `asgard` repo, `yggdrasil/.gitmodules`, `ouroboric/scripts/check-repos.sh` (the lists).
  Readiness: asgard, RR-04, RR-05, RR-07, RR-08, RR-10 and RR-22.
- **Problem:** asgard is still a product umbrella. It has no `pack.yaml` (RR-08, RR-22) and no `ci.yml` (RR-04).
  Its `AGENTS.md` has its own invariants and links the company's, not the `yggdrasil` umbrella's (RR-05: the agents
  check passes because `check-repos.sh` lists asgard as an umbrella). It holds a charter in `docs/1-product/` and
  has no `docs/architecture.md` (RR-07). It is not a submodule of the umbrella (RR-10).
- **Why it is so:** this is the plan, not drift. The Asgard v0 design (§5.2) makes asgard a leaf and waits to wire
  it in until Yggdrasil v0 ships. Asgard v0 (roadmap step 2) builds the pack, with no stack and document checks.
- **Fix:** in Asgard v0, the pack and a `ci.yml` with a job `test`; the leaf layout of the docs standard; an
  `AGENTS.md` that links the `yggdrasil` invariants (decide where Asgard's three principles go, because a leaf must
  not define its own); a decision whether its document checks use the shared `docs.sh` (then asgard joins
  `REALMS` in `check-repos.sh`, and RR-09 applies); then the wiring pull request (submodule, and asgard moved to
  `LEAVES` in `check-repos.sh`). **Status:** requirement.

### B-061: since odin #15, the first task's acceptance run sees the other new leaf without its template

- **Where:** `odin/internal/engine/init.go` (`initLeaf`, `mainToTemplate`), `odin/internal/run/sandbox.go`
  (`snapshotSources`, `recordedCommit`). Readiness: helheim-go and midgard-react, RR-21.
- **Problem:** `initLeaf` creates a leaf with its first commit (the pack's `first_commit`, here only `LICENSE`),
  and the project's umbrella records that commit. Then it commits the template and moves the leaf's `main` to it,
  but the umbrella's gitlink stays on the first commit. Since odin #15 (B-048 M-1), a snapshot takes each other leaf at its
  gitlink. So the acceptance run of the first task's pointer move sees the other leaf as `LICENSE` alone.
- **Proved:** the content smoke run (v0-H15's mode) at odin `6829cfb`, gleipnir `f362ea2`, helheim-go `60731f6` and
  midgard-react `26ca85e`, on 2026-10-18. Task 1 (the API leaf) passed its loop and its landing. Its pointer move
  failed: `accept: the web leaf has no repos/web/contracts/api.openapi.yaml`. The snapshot's `repos/web` held only
  `LICENSE`, and the umbrella's gitlink for `repos/web` was the first commit, `454b811`. The run gave up both tasks
  (exit 5).
- **Control (v0-H15):** v0-H15 ran on 2026-10-18 at 09:37 UTC, before odin #15 (`6829cfb`) merged at 11:28 UTC.
  In its project (`~/ygg-it/content/smoke-realms-20261018-113734`), `repos/web` was also recorded at its first
  commit (`d2a944d`) when `version-t1-move` ran, and that move's `accept` passed (exit 0). So the change is odin
  #15's, not the realms'.
- **Why it matters:** it fails any run whose first pointer move runs an acceptance check that reads another new
  leaf. The client gallery's order is such a run: the API task is first, and midgard-react's `accept-e2e.sh` reads
  the web leaf beside the API leaf. **It blocks real runs of the gallery, and Phase 5c's real runs, until it is
  fixed.**
- **Fix:** when `initLeaf` moves `main` to the template, move the umbrella's gitlink to it too; or let the snapshot
  take a leaf that this run created, and that has had no pointer move yet, at its `main`. Test: the content smoke
  run passes, and a unit test of `snapshotSources` on a new leaf finds its template. **Status:** proved.

### B-062: the build realms' packs give no reason for each egress host

- **Where:** `helheim-go/pack.yaml` and `midgard-react/pack.yaml` (`sandbox.egress`). Readiness: helheim-go and
  midgard-react, RR-19.
- **Problem:** each pack lists its egress hosts and nothing else. The reason for each host is only in the check
  scripts that use it, so a person who reviews the list, or a later change to it, must find the reasons again.
  The founder judged both lists minimal (2026-10-19).
- **Fix:** a reason per host. Gungnir's schema (`schema/pack.go` at `cb1dc0e`) has `egress` as a plain list of host
  names, and it decodes a pack with `KnownFields(true)`, so a reason field would be refused. Write each reason as a
  YAML comment beside its host in `pack.yaml`, or add a reason field to the schema in Gungnir first (a schema
  change) if the reasons should be checked. **Status:** requirement.

Source of items B-063 to B-070: the final review of the realm-readiness plan (2026-10-19), one fresh reviewer
over the checklist, the three assessments, `helheim-go` and `midgard-react`. Each item is a realm-side fix that this
documentation pass does not make. B-055, B-057, B-058, B-059 and B-043 were widened by the same review. The code
facts were read at each realm's `main` after Phase 5c's first commits.

### B-064: no test pins either realm's own root `ci.yml` to its stack

- **Where:** `helheim-go/.github/workflows/ci.yml` (the Go image) and `midgard-react/.github/workflows/ci.yml` (the
  Node image, and `go-version: 1.26.9`). Their tests read the template's `ci.yml`, not these.
- **Problem:** a digest bump in a Containerfile leaves the realm's own CI on the old image, and nothing fails.
- **Fix:** a test in each realm that the root `ci.yml` image (and midgard-react's Go version) equals the
  Containerfile's. **Status:** reasoned.

### B-065: midgard-react skips tests without honouring `YGG_REQUIRE_TEMPLATES`

- **Where:** `midgard-react/checks_test.go` (`realLeaf`, `skipOffline`) and `e2e_test.go` (`needPython`).
- **Problem:** each skips when its tool or network is missing, and none checks `YGG_REQUIRE_TEMPLATES`. If `python3`
  is ever dropped from the root `ci.yml`, the e2e tests skip and `test` stays green.
- **Fix:** fail, not skip, when `YGG_REQUIRE_TEMPLATES` is set. Test: run with the variable set and the tool absent.
  **Status:** reasoned.

### B-067: the realms' base CI never actionlints the templates' workflows

- **Where:** `helheim-go` and `midgard-react`, `.pre-commit-config.yaml` (the `actionlint` hook, which has
  no `files:` of its own and so takes the hook's default, `^\.github/workflows/`), `templates/*/.github/workflows/ci.yml`.
- **Problem:** the default matches only the realm's own `.github/workflows/`, so the template workflows that every
  product receives are not linted.
- **Fix:** set the hook's `files` to `^(templates/[^/]+/)?\.github/workflows/`, and fix what it then flags.
  **Status:** reasoned.

### B-068: nothing in CI runs `check-repos.sh --check shared`

- **Where:** `ouroboric/scripts/check-repos.sh`, the CI of `ouroboric` and `yggdrasil`.
- **Problem:** the `shared` check (RR-09, ouroboric #48) runs only when a person runs it. A realm's copy of `docs.sh`
  can drift without a failing check. This is the interim fix of B-043.
- **Fix:** run it in the `yggdrasil` CI over the submodules, or on a schedule. **Status:** reasoned.

### B-069: a documentation pass in each build realm

- **Where:** `helheim-go` and `midgard-react`: `README.md`, `docs/architecture.md`, `prompts/implementer.md`.
- **Problem and fix, one line each:**
  - Both READMEs ("The required check `test`…", line 16 and 17) and both `docs/architecture.md` pages call `test`
    "the required check". `lint` is required too.
  - Both READMEs say "so `gitleaks` checks each commit". The pre-commit config runs six tools (gitleaks, reuse, markdownlint, shellcheck, actionlint, yamllint): say so.
  - Neither implementer prompt names `.github/` as refused.
  - helheim-go's `docs/architecture.md` lacks the B-055 caveat that midgard-react's has (its line about the
    leaf's tool configs, which the ladder ignores).
- **Status:** proved (the greps).

Source of items B-071 to B-089: Phase 5c (2026-10-19), the task reviews and the final review. The reports are in the
SDD workspace (`.superpowers/sdd/tasks-2026-10-18-yggdrasil-v0-phase-5c/`). Each is **Open**, except B-071, now in [Done](#done). The pull requests are
gungnir#14, gleipnir#12, helheim-go#8, midgard-react#13, mimir#4, odin#17 and #18, ouroboric#59.

### B-072: an unattended run stops at a contract change

- **Where:** `odin/internal/gate` (`Decide`), `odin/internal/engine` (`reachGate`).
- **Problem:** `gate.Decide` returns `Block` for a contract change in unattended mode, and `reachGate` stops the
  run. The `pointer-contract` gate needs a person to say yes, so an unattended run that changes a contract ends there.
- **Fix:** decide with the founder whether unattended mode should escalate to a named person and wait, or end
  `blocked` with a clear line in the report. Test: the chosen behaviour.
- **Status:** proved (the gate tests).

### B-073: `.factory/runs/` is untracked but not ignored in a project

- **Where:** the umbrella template (`odin/internal/engine/init.go`, the files `ygg init` writes).
- **Problem:** the run folder shows in `git status` of the project. Compare B-001.
- **Fix:** the umbrella template writes `.factory/` into `.gitignore`. Test: after `ygg init`, `git check-ignore .factory/runs` succeeds.
- **Status:** proved (v0-T262's smoke).

### B-074: `ygg doctor` and `ygg status` do not list `.factory/deps/` or leftover bump sandboxes

- **Where:** `odin/internal/cli/doctor.go`, `odin/internal/deps`.
- **Problem:** a bump killed halfway leaves a ledger and a sandbox that nothing reports. A bump that stopped
  before it restored the leaf leaves the leaf changed, and `doctor` says nothing.
- **Fix:** both commands list an unfinished bump ledger and the containers of a bump sandbox, and say what to run.
- **Status:** reasoned.

### B-075: the indexes are built from the leaves' working copies, not from their pointers

- **Where:** `odin/internal/routing`.
- **Problem:** the wiring and impact indexes read the files on disk. A leaf with uncommitted or newer commits
  than the umbrella's pointer gives an index for a tree no one can check out.
- **Fix:** read the files at the commit the umbrella records (`git ls-tree`, `git cat-file`, as the snapshot export does).
- **Status:** reasoned.

### B-076: `ygg routing build|bench` does not exist

- **Where:** `odin/internal/cli`.
- **Problem:** the indexes are built and benched inside a run. A person cannot build or bench them by hand.
- **Fix:** add the two verbs, with the same shrink guard and the same exit codes as the run.
- **Status:** requirement.

### B-077: the first routing bench of a project has no author

- **Where:** `odin/internal/routing` (the bench).
- **Problem:** the bench needs questions with known answers. The first run of a project has none, so the bench
  compares two empty lists and passes.
- **Fix:** a first-run rule: the bench writes the questions from the extracted graph and a person confirms them; until then routing does not ship.
- **Status:** proved (the engine bench is two `[]` questions).

### B-078: the grader's `/app` needs a `start.sh` that a real project does not yet provide

- **Where:** `gleipnir/sandbox/grade.go`, the leaf templates of both realms.
- **Problem:** the grader starts the product with a `start.sh` at the root. The smoke project has one. A real
  project made from a template has none, so `ygg grade` on it fails to start the app.
- **Fix:** the templates ship a `start.sh` and the realms' prompts name it. Decide who writes it for a new leaf.
- **Status:** reasoned (the first real run is where to see it).

### B-079: the real version floors of the two policy files

- **Where:** `helheim-go` (`go-deps.sh`), `midgard-react` (`web-deps.sh`, the policy file).
- **Problem:** the floors in the policy files were written to test the rungs. A real policy needs the lines the
  factory supports today.
- **Fix:** the founder names the minimum minor of each pinned toolchain package; set them and add a test per floor.
- **Status:** requirement.

### B-080: no per-agent token cap

- **Where:** `gungnir` (the factory file's caps), `odin/internal/engine`.
- **Problem:** the caps count the whole run. One agent can spend the run's tokens before the next starts.
- **Fix:** a `max_tokens` per node kind, counted from the usage lines. Needed before v0-H17 runs at scale.
- **Status:** requirement.

### B-081: `oasdiff` is not proven against 1.33.0 on the host

- **Where:** `odin/internal/gate` (the `oasdiff diff --fail-on-diff` mapping), the realm images.
- **Problem:** the exit codes and output were modelled on the real output of an older run, and the stand-in
  in the tests copies them. The realm images do not pin `oasdiff`.
- **Fix:** pin `oasdiff` in both realm images, and run the gate tests once against the real binary in CI.
- **Status:** reasoned.

### B-082: `govulncheck` and `osv-scanner` were not run for the policy rungs

- **Where:** `helheim-go/devcontainer/checks/go-deps.sh`, `midgard-react/devcontainer/checks/web-deps.sh`.
- **Problem:** the tests use stubs for both tools. Nothing has run the real ones on a real module.
- **Fix:** one test per realm that runs the real tool against a known-vulnerable fixture, behind `YGG_REQUIRE_TEMPLATES`.
- **Status:** reasoned.

### B-083: the realm folder is hashed into a run, so editing a realm mid-run breaks `ygg grade`

- **Where:** `odin/internal/realm`, `odin/internal/engine/grade.go`.
- **Problem:** `ygg grade` checks the realm hash the run recorded. A fix to a realm between the run and the grade
  refuses the grade.
- **Fix:** say so in the refusal, or let `grade` accept a realm whose changes do not touch the grader's inputs.
- **Status:** proved (v0-T262's smoke).

### B-084: the decisions parked in odin#18, decided by the founder on 2026-10-20

- **Where:** `odin/internal/deps`, `odin/internal/gate`, `odin/internal/engine/grade.go`.
- **Decided, one line each:**
  - `ygg deps bump` without a `sandbox:` section runs on the host with the full network and the operator's uid.
    **Decision:** refuse (exit 2) unless `--host` is given.
  - A contract split across files, or behind a symlink, passes the `pointer-contract` gate unseen. **Decision:**
    escalate on a changed YAML or JSON under a listed contract's folder, and on a mode-120000 file there.
  - The graded app can overwrite `results.json`. **Decision:** the grader reads the scores from the suite's stdout,
    and the app has no path to forge it.
  - Treat every path variable as a resource id: done in [odin#18](https://github.com/ouroboric-dev/odin/pull/18) (the founder asked for it).
- **Next:** the first and the third change behavior the spec states, so each goes through a
  [change proposal](changes/README.md) before the code. The second changes the plan's decision 15 ("acceptance tests
  catch the rest"); say so in its proposal.
- **Status:** decided; not built.

### B-085: gleipnir's grader, minors

- **Where:** `gleipnir/sandbox/grade.go`, `driver.go`.
- **Problem and fix, one line each:**
  - Output of the grader is buffered in host memory without a bound (as B-021 was for sessions): bound it.
  - `TestGradeNeverMountsAnythingButTheThreePaths` misses `--flag=value` spellings: use an allow-list of flags.
  - The grader does not pass `--pull=never`: pass it.
- **Status:** reasoned.

### B-086: odin's Phase 5c minors

- **Where:** `odin/internal/{task,score,engine,routing,gate,deps,cli}`.
- **Problem and fix, one line each:**
  - `grader.suite_dir` is not checked to lie outside the project: refuse a suite folder inside it.
  - `hostExec` is duplicated in two packages: one copy.
  - A run without a `Judged` entry skip the contract check silently: fail closed when the task has a `pointer-contract` gate before the pointer.
  - The refusal "run the gate again" names no such command: rewind to the gate and judge again.
  - An empty contract file reads as no contract (`Old == nil`): treat it as a change.
  - The docs say "refusal before building", but a `bad_manifest` can follow `grade_started`: say so.
  - A refused pointer move leaves a thinned index on disk: restore it.
  - A bare-repo-shaped folder (`HEAD`, `objects`, `refs`, `config`) planted under `node_modules` passes `checkNested`.
  - A product-caused FIFO or over-cap file after the ladder ends as exit 1, not a failing verdict.
  - The vacuous `none` answers of the routing bench are not checked against a real leaf.
  - Tests ignore the errors of `os.WriteFile` and `os.Symlink`, and the `LimitReader` and `SameFile` branches have no test.
  - A leftover `.impact-*.tmp` stays after a kill, a FIFO can hang the open, `chmod` ignores the umask and the directory is not synced.
- **Status:** reasoned (from the reviews).

### B-087: realm scripts' minors

- **Where:** `helheim-go`, `midgard-react`, `mimir`.
- **Problem and fix, one line each:**
  - The user's or global npm config (`~/.npmrc`, the environment) can change what `npm audit` reports, in `web-deps.sh` and `web-security.sh`: run with `--userconfig` and `--globalconfig` pointing at an empty file.
  - The error "no package-lock.json" is misleading when the cause is a bad path.
  - `mimir`'s `check-task.sh` and the smoke notes have loose test assertions.
- **Status:** reasoned.

### B-088: the Phase 5c scripts in `ouroboric`, minors

- **Where:** `ouroboric/scripts/ygg-smoke-grade.sh`, `ygg-smoke-real.sh`, `ygg-cost.sh` and their test.
- **Problem and fix, one line each:**
  - The credentials check accepts `NAME=abc def` and `NAME=""`: use a strict pattern.
  - `score.json` is searched only in the case folder: search the run folder.
  - A mount of the parent folder is not flagged: flag it.
  - The default paths do not exist in every workspace: say so in the usage line.
  - Two runs in one second share a folder: add the process id.
  - Weak assertions: "the first doctor is not preceded by `loaded:`" (line 1 is the args line); the `bash -x` test has no positive control; the count of two source lines does not prove both are in subshells.
  - `ygg-cost.sh` fails on a number that arrives as a string.
- **Status:** reasoned.

### B-089: the plan tools, kept in the workspace

- **Where:** `.superpowers/sdd/tasks-2026-10-18-yggdrasil-v0-phase-5c/tools/{check.py,shrun.py}`.
- **Problem:** the checker that applies a plan's blocks to fresh clones lives only in the workspace.
- **Fix:** move both into `ouroboric/scripts` with tests and a pull request (as `plan-*` were).
- **Status:** requirement.

Source of items B-090 to B-093: the final review, the re-review and the task reviews of the protected-configs
change (2026-10-19), over `helheim-go` `7ab0751` and `midgard-react` `62d3de6` (after the fix wave, helheim-go #10 and
midgard-react #16). Line numbers are at those commits.

### B-090: the protected-path rungs trust the leaf's `.git`

- **Where:** `helheim-go/devcontainer/checks/go-static.sh` (the `git merge-base HEAD refs/heads/main` at line 24 and
  the `git diff`, `git ls-files` calls at lines 61 to 68); `midgard-react/devcontainer/checks/web-protected.sh` (line
  14 and lines 51 to 58).
- **Problem:** both rungs ask the leaf's own git what changed. A task can run `git branch -f main HEAD`, so the
  merge-base is the task's own commit and its changes are hidden. It can also run
  `git update-index --assume-unchanged <file>` on a tracked config, so `git diff` skips it. Every rung stays green.
- **Fixed in part:** the tag variant (`git tag main HEAD`) no longer hides a change from the protected step: it reads
  `refs/heads/main`, and a tag with no branch fails closed (helheim-go #10, midgard-react #16). The other rungs still
  read a plain `main`: see B-093.
- **Why it matters:** the protection is only as strong as the `.git` that the agent can write. Only the reviewers
  would see it.
- **Fix:** the factory passes in the task's base commit, so no branch in the leaf is read, and the rung compares the
  tree, not the index flags. Test: a leaf where `main` was moved, and one with an assumed-unchanged config, must be
  refused.
- **Status:** reasoned.

### B-091: the protected-path guard trusts its environment

- **Where:** the `:(glob)` entries of `devcontainer/checks/protected-common` and the `git diff`, `git ls-files`
  calls in `helheim-go/devcontainer/checks/go-static.sh` (lines 61 to 68) and
  `midgard-react/devcontainer/checks/web-protected.sh` (lines 51 to 58).
- **Problem:** with `GIT_LITERAL_PATHSPECS=1` in the rung's environment, git reads `:(glob)**/.yamllint` as a
  literal name, so the match-anywhere names stop matching and a change to them passes.
- **Why it matters:** fine while the factory, not the agent, sets the rung's environment. It stops being fine if a
  task can set a variable that the rung inherits.
- **Fix:** the scripts set `GIT_LITERAL_PATHSPECS=0` (or `unset` it, and `GIT_GLOB_PATHSPECS`,
  `GIT_NOGLOB_PATHSPECS`, `GIT_ICASE_PATHSPECS`) before the git calls. Test: run a rung with the variable set.
- **Status:** reasoned.

### B-092: minor findings of the protected-configs reviews

- **Where:** `helheim-go` `7ab0751` and `midgard-react` `62d3de6`, as each finding says.
- **Problem:**
  - `templates/api/AGENTS.md` line 38 (helheim-go), `templates/web/AGENTS.md` lines 39 and 40 (midgard-react) and
    both `prompts/implementer.md` (helheim-go lines 55 and 56, midgard-react line 51) name broader patterns
    (`.yamllint*`, `.gitleaks*`) than the exact names that `protected-common` refuses (`.yamllint`,
    `.yamllint.yaml`, `.yamllint.yml`, `.gitleaks.toml`, `.gitleaksignore`).
  - helheim-go `checks_test.go` line 848: the comment on `commonProtected` says the test reads the file for its
    cases. It reads the file only to compare it with this list.
  - midgard-react: no test makes `ls-files` alone fail. `set -e` still fails closed, so this is only a gap in the
    tests.
  - midgard-react: the refusal test is heavy, about 112 s at `-parallel 4`; its CI job takes about 5 to 6 minutes of
    the 15 allowed.
  - midgard-react `web-protected.sh` line 63: when `main` has no `package.json`,
    `git show "$base:package.json" | scripts` fails under `pipefail` and `set -e` ends the rung with no message.
    This predates the change.
  - `go-static.sh` line 65 and `web-protected.sh` line 55: the `-gt 0` test on `globs` is always true, because the
    stack's own names are always added. It is harmless, and misleading to read.
  - helheim-go's Go protected step (`go-static.sh`, from line 14) runs after `go mod download && go mod verify`
    (line 9), while delta §9.5 says the refusal comes "before it installs or runs anything". This predates the
    change. No leaf code runs there, and the downloads are checked against the checksum database.
  - delta §9.5 says every rung refuses a protected change, but in helheim-go only rung 1 (`go-static.sh`) does. It has
    no effect today: jormungandr reruns the ladder from rung 1 on every attempt and stops at the first failure
    (`jormungandr/loop.go:177-200`).
- **Fix:** one line per finding, as above.
- **Status:** reasoned.

### B-093: the TDD and contract rungs find the task's base with a plain `main`

Small, and worth doing soon: one word in each script, and one test per rung.

- **Where:** helheim-go `devcontainer/checks/go-tdd.sh` (line 22), `go-contract.sh` (line 12) and `sqlc-owned.sh`
  (line 11, which also ends in `|| exit 0`); midgard-react `devcontainer/checks/web-tdd.sh` (line 12) and
  `web-contract.sh` (line 23), and the text `git diff $(git merge-base HEAD main) HEAD` in midgard-react's
  `prompts/reviewer-spec.md` (line 9), `reviewer-quality.md` (line 8) and `reviewer-simplicity.md` (line 6).
- **Problem:** with both a branch and a tag named `main` (a task can create the tag), `git merge-base HEAD main`
  resolves the tag, so these rungs see no change, while the protected step reads `refs/heads/main` and passes.
- **Fix:** `refs/heads/main` in each script and prompt, with a test per rung (a tag `main` on the task's HEAD must
  not hide its change).
- **Status:** reasoned (the re-review found it, and git resolves tags before branches).

Source of items B-094 to B-103: the voluspa change (2026-10-19, [proposal](changes/2026-10-19-voluspa/proposal.md)):
its proposal's Backlog, the real runs H02 and H03, and the reviews of `odin`, `gungnir` and `gleipnir`.

### B-094: a schema version in every pack

- **Where:** `gungnir` (the pack schema), every `pack.yaml` in the realms.
- **Problem:** a graph states the Gungnir schema version it needs (`schema` in `graph.yaml`). A realm pack does not.
- **Fix:** add the integer `schema` to realm packs too, once a second schema version exists.
- **Status:** requirement.

### B-095: the routing threshold in the project

- **Where:** `umbrella.yaml`, beside `.ygg/routing-bench.yaml`.
- **Problem:** the routing threshold is not a setting of the project.
- **Fix:** put it in `umbrella.yaml`, once a project writes its own bench (5c plan question 8).
- **Status:** requirement.

### B-096: ygg's resume and approve hints don't carry the engine environment

- **Where:** `odin/internal/cli` (the stop hint), `ouroboric/scripts/ygg-smoke-realms.sh`.
- **Problem:** after a stop, ygg prints `run: ygg resume <id>` or `ygg approve …`. On the founder's machine, run from
  a plain shell, that failed in 334 ms at the move's sandbox (`devcontainer up … exit status 1`). Only
  `ygg-engine.sh run --folder DIR -- ygg …` sets `CONTAINER_HOST`, the devcontainer CLI on `PATH`, and the empty
  registry auth (H02, 2026-10-19).
- **Fix:** two parts. The smoke scripts print the wrapped commands when a run stops. Odin's stop hint names the
  engine wrapper when `factory.yaml` has a sandbox section.
- **Status:** proved (H02).

### B-098: odin review leftovers (voluspa-F1 re-review, parked)

- **Where:** `odin/internal/cli/doctor.go:104`, `odin/internal/realm/subfolder_test.go:115`, `hashLimited`,
  `initAhead`.
- **Problem:**
  - two comment lines are over 120 columns (`doctor.go:104`, `subfolder_test.go:115`);
  - `hashLimited`'s "not a git repository" match runs on the whole error string, which includes `(in <dir>)`, so a
    folder path holding that phrase would turn a refusal into a disk hash (contrived);
  - no test covers `initAhead`'s fallback for a resume whose nodes don't expand. The code returns false (strict).
- **Fix:** wrap the two comments; match git's stderr only; add the test.
- **Status:** reasoned.

### B-099: gungnir's `schema.Node.Realm` comment says "empty is the graph pack"

- **Where:** `gungnir` `schema.Node.Realm`.
- **Problem:** Odin's `NodeRealm` takes an empty `Realm` to mean the leaf's pinned realm, as the plan says. The
  comment on `RealmFrom` (`schema/graph.go:~52`, "the graph pack's (the default)") is wrong in the same way. For
  checks, an empty value means the realm of the node's repo.
- **Fix:** correct both comments, or rename the fields for clarity.
- **Status:** proved (the reading of both).

### B-100: gleipnir `BuildFactory` has no unit test of its failure paths

- **Where:** `gleipnir` `BuildFactory`.
- **Problem:** for example, when the stack build fails, no layer is built; no test says so. Deferred at T002.
  `git` from apt is unpinned in that image, which belongs to B-023 and B-044, not to this item.
- **Fix:** a unit test per failure path.
- **Status:** requirement.

### B-101: "lead realm" and "no graph in v0" wording left in the merged repos

- **Where:**
  - `helheim-go`: `pack_test.go:122` ("the lead realm's graph holds the pointer-contract gate…"); `pack_test.go:20`
    and `docs/architecture.md:22` ("has no graph in v0");
  - `odin`: `testdata/realms/helheim-toy/pack.yaml:1` ("never lead a run");
  - `gungnir`: `docs/architecture.md:23`;
  - `ouroboric`: `scripts/ygg-engine.sh:16,60`; `scripts/ygg-smoke-realms.sh`.
- **Problem:**
  - there is no lead realm any more, and "has no graph in v0" is now a MUST NOT (§9.4) in the helheim-go lines;
  - gungnir's line says a build realm's pack "may have no graph", which is weaker than §9.4, and the line is 142
    columns wide;
  - `ygg-engine.sh` still says the bind mount "is there";
  - the message of `ygg-smoke-realms.sh` for a missing `factory.yaml` names only the smoke-realms example, not
    smoke-content's, which `--graph software` needs;
  - the T012 and T017 greps covered only `.go` files of `odin`, `gungnir` and `gleipnir`.
- **Fix:** reword each line; grep every file type in every repo.
- **Status:** proved (the final review's reading).

### B-102: the journal entry overstates two things

- **Where:** `ouroboric` `docs/6-journal/2026-10-19-one-graph-for-every-run.md:50,60`.
- **Problem:**
  - "on the same project" is wrong: H02 and H03 ran in different projects with the same brief;
  - "The run's behaviour did not change" is not quite right: the scratch sandboxes' image and egress changed, as
    decided.
- **Fix:** correct both sentences.
- **Status:** proved (the final review's reading).

### B-103: guards nobody owns since the move

- **Where:** `midgard-react` CI, `voluspa` `software/`, the smoke scripts, `odin` realm checks.
- **Problem:**
  - (a) midgard-react's CI no longer catches a version bump that Voluspa's `spec.md` does not follow (it hard-codes
    `midgard-react` 0.1.0). Only odin's umbrella-only real-realms test compares the two, and odin's CI skips it;
  - (b) no test checks that `software/graph.yaml`'s `name` and `version` equal `pack.yaml`'s. The pin and `run.json`
    use the pack's version;
  - (c) a missing `mountpoint` binary makes the smoke scripts exit 127, not 2;
  - (d) a realm's `routing:` block is silently ignored. Should a pack check refuse it?
- **Fix:** give each guard an owner and a test; decide (d).
- **Status:** reasoned.

Source of items B-104 to B-111: the real-agent smoke (v0-H17) and the reviewer experiments of 2026-10-20
(gleipnir pull requests 14 to 16, odin pull requests 21 to 23, and the journal entry
`2026-10-20-choosing-the-reviewer-model`). The smoke passed in the end (run 20261020-205528-86a693, reward 1.0).
These eight are what it left.

### B-104: a loop has no way to settle a disputed finding

- **Where:** `jormungandr` (the loop), `odin/internal/engine/loop.go`.
- **Problem:** one false blocker from a reviewer ends the run. In run 20261020-190818-5b02ff the reviewer said
  `findIndex` is not a JavaScript method. The implementer showed with `curl` that it works, and changed nothing. The
  reviewer repeated the claim in its next two sessions, and the run stopped at `attempts-exhausted` (exit 3). Nothing
  checks who is right.
- **Fix:** decide between a second reviewer that must agree, a reviewer that must show proof for a blocker (as a
  `fixed` finding already must), or a founder gate on a finding the implementer disputes. It changes the loop's
  contract, so it needs a [change proposal](changes/README.md).
- **Status:** proved (the run's ledger).

### B-105: `ParseReport` refuses an answer with prose around the JSON

- **Where:** `gungnir/schema/event.go` (`ParseReport`), the reviewer prompt's last paragraph.
- **Problem:** the report must be one JSON document, alone or in one code fence. `deepseek-v4-flash` wrote a sentence
  before the fence in the smoke run (and in 2 of 8 bake-off sessions), and the engine treated it as unreadable. A
  strict parser is a safe default, but every unreadable answer costs a try, and two in a row stop the run.
- **Fix:** decide. Accept the last JSON document or fence in the answer and ignore the text before it, or keep it
  strict and rely on the second try. Accepting more is a change to the report format the spec states, so it needs a
  change proposal.
- **Status:** proved (the smoke ledger and the bake-off files).

### B-106: the reasoning effort is `high` for every OpenCode session

- **Where:** `gleipnir/opencode/opencode.go` (`ConfigJSON`), the role settings in `factory.yaml`.
- **Problem:** gleipnir#16 names `effort: high` on every request, because `deepseek-v4-flash` took its prompt for an
  empty message when no effort was named. The value is the same for every model and every role. A model that thinks
  a lot (GLM 5.3 Flash wrote up to 18.5k tokens in a session) may do better with less, and a model that rejects the
  setting has no way out.
- **Fix:** an optional `reasoning:` setting on a role (`low`, `medium`, `high`, `off`), with `high` as the default.
- **Status:** reasoned.

### B-107: a model that OpenRouter reports no cost for counts as zero dollars

- **Where:** `gleipnir/opencode` (the cost of a session), `odin` `doctor` and the budget meter.
- **Problem:** the Claude Haiku 5.5 and Sonnet 5.5 sessions of the bake-off came back from OpenRouter with `cost: 0`
  on every step. A reviewer on such a model would add nothing to the dollar caps (`per_run.usd`, `per_day.usd`), while
  its tokens count. The role's `Price` setting is the way out, and nothing says to set it.
- **Fix:** a session with tokens and a cost of 0 and no `Price` is an error or a `doctor` warning, so the caps are
  never silently weaker than they look.
- **Status:** proved (the step files); the effect on the caps is reasoned.

### B-108: the reviewer bake-off scripts are in a scratch folder

- **Where:** a session's scratchpad (`bake.sh`, the planted-fault leaves, the scorer); to move to
  `ouroboric/scripts`.
- **Problem:** the scripts that compared five reviewer models, and the three planted-fault leaves, were written for
  one session and a restart of the PC deleted part of them. The next model change needs the same bench. It is
  reusable tooling.
- **Fix:** move them to `ouroboric/scripts` as one script with a test and a pull request. It takes a model, a leaf
  (a folder), the number of sessions and a pattern for the fault, and prints the table of the journal entry: valid
  reports, findings, tokens, cost. Add a planted fault that needs reading two files (one user reaching another's
  notes).
- **Status:** requirement.

### B-109: the repair path of a loop is not proved with a cheap reviewer

- **Where:** the real-agent smoke (`scripts/ygg-smoke-real.sh`), the smoke pack.
- **Problem:** the passing smoke never used the repair path. The reviewer found nothing, so the implementer was not
  sent back. Planted-fault tests show that Qwen3.8 27B reports a real fault. They do not show that the implementer
  fixes it and that the reviewer then closes the finding.
- **Fix:** a smoke variant whose brief makes the implementer likely to make one mistake, or a run that starts from the
  planted-fault leaf, with the pass condition "one finding raised, fixed, and closed". Report it in the journal
  entry.
- **Status:** requirement.

### B-110: Qwen as the implementer is not tried

- **Where:** `factory.real.example.yaml`, the OpenCode adapter with write permissions.
- **Problem:** the implementer is Claude Code on the founder's subscription, which costs nothing per run. A
  factory without that subscription needs an implementer on a per-token model. `qwen3.8-27b` costs about 1 cent
  for a reviewer session, and is the model the founder runs locally. Nobody has measured it as an implementer.
- **Fix:** run the grader smoke with the implementer on `qwen/qwen3.8-27b` through OpenCode, and compare the
  reward, the turns, the time and the cost with the Sonnet run. Change one role at a time.
- **Status:** requirement.

### B-111: the real-agent smoke runs a `ygg` from `PATH` without saying which

- **Where:** `ouroboric/scripts/ygg-smoke-real.sh` (the lines that choose `ygg`).
- **Problem:** the script uses `ygg` from `PATH` when there is one, and builds odin only when there is none. A stale
  binary would run the old code, and the run would give no sign. The smoke of 2026-10-20 built from source, so it
  was safe, but only because `PATH` held no `ygg`.
- **Fix:** print the commit and path of the `ygg` that runs, or always build from `--odin`. Add a test.
- **Status:** reasoned.

## Done

### B-071: `Advance` has no default case, so an unknown node kind passes silently

- **Where:** `odin/internal/engine` (`Advance`).
- **Problem:** a graph node of a kind the engine does not know is skipped as if it had passed.
- **Fix:** a `default` case that stops the run with `bad_manifest`. Test: a graph with a made-up kind stops.
- **Fixed** in [odin#20](https://github.com/ouroboric-dev/odin/pull/20): a `default` case fails the node as
  `bad_manifest`, with a `node_failed` event. Test: a graded run whose last node has a made-up kind stops `failed`.
- **Status:** proved (the reading of `Advance`).

### B-097: the plan's H02 and H03 steps omitted three things

- **Where:** the voluspa plan's H02 and H03 steps; `docs/3-using/operations/README.md`.
- **Problem:** found while running them on 2026-10-19. The steps did not say:
  - that `--build` is needed the first time, and when the images are gone;
  - that an unattended content run stops at `version-t1-contract-gate` (B-072) and needs an approve;
  - that the approve and resume steps must run under `ygg-engine.sh`.
- **Fixed** in the voluspa change's pull request (the T017 branch): the runbook says all three, in "Name a graph".
  Its approve and resume commands carry `--project <project>`, and work without `ygg` on `PATH`.
- **Status:** proved.

### The Phase 5b notes that Phase 5c closed

- **Rung 7 and the isolated grader** (5b "Not here"): `gungnir` schemas and events (v0-T245),
  `gleipnir` `Grade` (v0-T246), `odin` `ygg grade` (v0-T247 to T250, T262). The grade node runs last, the hidden suite is mounted
  read-only in its own container with no network, and the score is in the run folder only.
- **The two-tenant authorisation harness:** `helheim-go` and `midgard-react` (v0-T260), with the
  decision that every path variable is a resource id.
- **The routing indexes and bench:** `odin/internal/routing` (v0-T251 to T253, T255), gated by the bench before they ship.
  The verbs and the first bench are open: see B-076 and B-077.
- **The `pointer-contract` gate:** `odin/internal/gate` (v0-T254) and the realm graphs (v0-T256); see B-072, B-081 and B-084 for what is open.
- **The dependency policy:** `go-deps.sh` and `web-deps.sh` (v0-T257, T258) and `ygg deps bump` with a canary (v0-T259); see B-079, B-082 and B-084.
- The grader smoke and the real-agent smoke: `ouroboric` `ygg-smoke-grade.sh` and `ygg-smoke-real.sh` (v0-T262, T263,
  [ouroboric#59](https://github.com/ouroboric-dev/ouroboric/pull/59)). Whether the real run happened is in the pull request.

### B-041, first part: file handling, engine environment and service egress (Phase 5a's final review)

- **Fixed 2026-10-17** by the pre-5b cleanup, each with a test that failed first:
  - M-1, M-2, M-3, M-4, M-7 and M-8 in [odin#13](https://github.com/ouroboric-dev/odin/pull/13): a large scratch input is refused before it is read in full; files are opened without following symlinks and must be the file the listing found; publish scans exactly the bytes it publishes; one checked read of the leaves file for `init` and the tasks node; no `.factory` or `.git` in a scratch workspace; symlinks (root included) are refused in a realm; init applies a realm's template only to a leaf it created.
  - M-4 also in [gungnir#11](https://github.com/ouroboric-dev/gungnir/pull/11): `.` is refused as a scratch input.
  - N-5 in [gleipnir#8](https://github.com/ouroboric-dev/gleipnir/pull/8): the engine tools keep proxy, podman config and CA variables, from an allow-list.
  - N-1 in [gleipnir#8](https://github.com/ouroboric-dev/gleipnir/pull/8): `TestASandboxServiceHasNoRouteOut` passed on a real engine: the service has only its subnet route and no probe out succeeded.

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
- **Status:** fixed 2026-10-17 in Phase 5a (v0-T179: a pointer move's ledger lines close the attempts they
  open, and a waiver lasts one move), [odin#12](https://github.com/ouroboric-dev/odin/pull/12).

### B-015: two leaves can share a sandbox

- **Where:** `gleipnir/sandbox/config.go, driver.go`.
- **Problem:** `Project()` and the config folder name collapse punctuation, so `repos/web-app` and `repos/webapp` share a compose project; one leaf's `Up` or `Down` tears down the other's sandbox.
- **Fix:** Keep punctuation distinct (hash the path). Test: `TestTwoLeavesNeverShareASandboxProject`.
- **Status:** fixed 2026-10-17 in Phase 5a (v0-T157),
  [gleipnir#7](https://github.com/ouroboric-dev/gleipnir/pull/7).

### B-035: Odin loads a realm only from inside the `yggdrasil` tree

- **Where:** `odin` (realm loading behind `ygg run --realm`), `gungnir/schema` (`pack.yaml`).
- **Problem:** The web realm is a leaf of the `yggdrasil` umbrella. The `asgard` leaf becomes one after
  Yggdrasil v0, and Odin must then load its pack the same way.
- **Fix:** Resolve `--realm asgard` to the `asgard` leaf's pack at a pinned version.
- **Status:** fixed 2026-10-17 in Phase 5a (v0-T168 to v0-T171: realms load from a store by name, at the
  version the project pins, with a hash of what a run could read),
  [odin#12](https://github.com/ouroboric-dev/odin/pull/12) with the pins in
  [gungnir#10](https://github.com/ouroboric-dev/gungnir/pull/10).

### B-036: a realm must have code leaves, a stack layer and a code check ladder

- **Where:** `odin` (run start, sandbox bring-up), `gungnir/schema` (`pack.yaml`), the check ladder.
- **Problem:** The Asgard realm's output is documentation in a company umbrella: no code leaves, no
  devcontainer stack layer, and checks that are document checks (docs standard, readiness, brand).
- **Fix:** Let a pack declare no stack layer and a check ladder of document checks; let a run work in
  an umbrella with no leaves.
- **Status:** fixed 2026-10-17 in Phase 5a (v0-T145 for the schema, v0-T193 for a run in an umbrella with
  no leaves), [gungnir#10](https://github.com/ouroboric-dev/gungnir/pull/10) and
  [odin#12](https://github.com/ouroboric-dev/odin/pull/12). The document checks themselves are Asgard's.

### B-038: realm leaves have no naming convention

- **Where:** the `yggdrasil` umbrella's leaves, `ouroboric/scripts/check-repos.sh`.
- **Problem:** The web realm's leaf is `realm-web`; the founder does not want to keep that name. The
  Asgard leaf is `asgard` until a convention exists.
- **Fix:** Decide one convention for every realm leaf, and rename both at once.
- **Status:** fixed 2026-10-17 by the change proposal
  [realm leaf naming](changes/2026-10-17-realm-leaf-naming/proposal.md)
  ([yggdrasil#36](https://github.com/ouroboric-dev/yggdrasil/pull/36)): the nine realms are domains and a
  leaf is `<realm>-<flavor>`; `realm-web` became `midgard-react`
  ([midgard-react#3](https://github.com/ouroboric-dev/midgard-react/pull/3)) beside the new `helheim-go`
  ([helheim-go#1](https://github.com/ouroboric-dev/helheim-go/pull/1)); scripts in
  [ouroboric#40](https://github.com/ouroboric-dev/ouroboric/pull/40), brand in
  [ouroboric#39](https://github.com/ouroboric-dev/ouroboric/pull/39); the umbrella in this PR. The engine
  part (a lead realm and each leaf's realm) is the proposal's task T004, in Phase 5.

### B-032: a failed journal append does not stop the run at the cap

- **Where:** `internal/run/run.go` (`Spend`), `internal/engine/session.go`, `internal/cli/doctor.go`.
- **Problem:** Phase 4's final review (I4) was fixed in part: the usage now counts in the run and `run.json`
  is saved before the journal error returns. Three parts are left: the run ends with an error instead of
  stopping at `budget-cap` (the leaf holds uncommitted work after an implementer session, and the gate file's
  text says to raise the cap); the usage the journal missed is kept nowhere, so the day's cap misses that
  session; `ygg doctor` checks the journal folder, not whether today's file can be opened for appending.
- **Fix:** keep a pending entry in `run.json` that the next `Spend` or `Open` appends first; stop at
  `budget-cap` with `CapJournal` and set the work aside as a gate does; make `doctor` open the file.
- **Status:** fixed in the cleanup before Phase 5 (pending entries, the stop with the work set aside,
  `doctor`'s append check, and four review fixes), [odin#10](https://github.com/ouroboric-dev/odin/pull/10).

### B-033: a reviewer's id may equal a check's name in the schema

- **Where:** `gungnir/schema/graph.go` (`checkLoop`).
- **Problem:** Phase 4's final review (I3) was fixed in `jormungandr` (#4): the book guards each finding's
  source and `Review` refuses the `check-` prefix. The schema still accepts a reviewer id equal to a check name.
- **Fix:** refuse it in `checkLoop`.
- **Status:** fixed in the cleanup before Phase 5, [gungnir#9](https://github.com/ouroboric-dev/gungnir/pull/9),
  pinned in [odin#11](https://github.com/ouroboric-dev/odin/pull/11).

### B-004: check output in a leaf blocks the next run

- **Where:** `internal/engine/land.go` (`runMerge` and `runPointer` run pack checks in the leaf).
- **Problem:** nothing checkpoints the leaf after those checks. Any non-ignored file a check writes
  stays in the leaf. The next run's `StartBranch` then refuses with "uncommitted changes".
- **Fix:** run `git clean -fd` in the leaf after the checks, or run the checks in a fresh worktree.
  Phase 3's sandbox may change where checks run, so decide there.
- **Status:** fixed by Phase 3 v0-T090 (the leaf is put back to the checks' commit after a node's checks), [odin#7](https://github.com/ouroboric-dev/odin/pull/7).

### B-012: the output after a hard stop suggests `ygg reject`

- **Where:** `internal/cli/cli.go` (the message for `run.StatusStopped`, line 237).
- **Problem:** the message always prints both `ygg approve` and `ygg reject`. A hard stop that a node
  raised (`policy-violation`, `shrink-guard`) refuses `reject`.
- **Fix:** when the pending approval point is hard, print only `approve`, plus "start a new run to
  drop the work".
- **Status:** fixed by Phase 4, [odin#8](https://github.com/ouroboric-dev/odin/pull/8).

### B-016: a probe that could not run counts as a closed network

- **Where:** `gleipnir/sandbox/driver.go`.
- **Problem:** The closed-network check accepts exit 125 (podman or `timeout` could not run the probe) as closed, against decision 5's "or can't be tried".
- **Fix:** Refuse exit 125. Test: `TestUpRefusesAProbeThatCouldNotRun`.
- **Status:** fixed by Phase 4, [gleipnir#6](https://github.com/ouroboric-dev/gleipnir/pull/6).

### B-017: podman's own failure reads as the command's exit code

- **Where:** `gleipnir/sandbox/driver.go`.
- **Problem:** Exit 125 from podman comes back as the command's exit code, so an infrastructure failure reads as a check or node failure (spec §12).
- **Fix:** Return an error for a missing container. Test: `TestExecReportsAMissingContainerAsAnError`.
- **Status:** fixed by Phase 4, [gleipnir#6](https://github.com/ouroboric-dev/gleipnir/pull/6).

### B-018: a read-only role's change to an ignored file is not caught

- **Where:** `odin/internal/engine/engine.go`.
- **Problem:** The read-only check uses `git status --porcelain` without `--ignored` (decision 11: "any change").
- **Fix:** Add `--ignored`. Test: `TestAReadOnlyRoleThatWritesAnIgnoredFileIsAHardStop`.
- **Status:** fixed by Phase 4, [odin#8](https://github.com/ouroboric-dev/odin/pull/8).

### B-019: a failed session with tokens and no cost passes as $0

- **Where:** `gleipnir/opencode/opencode.go`.
- **Problem:** Decision 10's refusal is skipped when the session failed.
- **Fix:** Refuse it too. Test: `TestAFailedSessionWithTokensAndNoCostIsRefused`.
- **Status:** fixed by Phase 4, [gleipnir#6](https://github.com/ouroboric-dev/gleipnir/pull/6).

### B-020: a session killed by its timeout reports no usage

- **Where:** `gleipnir/claudecode, gleipnir/opencode, odin/internal/engine/engine.go`.
- **Problem:** The caps never count what a timed-out session spent.
- **Fix:** Parse the partial stream. Test: `TestATimedOutSessionStillCountsItsUsage`.
- **Status:** fixed by Phase 4, [gleipnir#6](https://github.com/ouroboric-dev/gleipnir/pull/6).

### B-021: session output is buffered in host memory without a bound

- **Where:** `gleipnir/claudecode/claudecode.go, opencode.go`.
- **Problem:** A chatty session can exhaust the host's memory.
- **Fix:** Bound the buffer. Test: `TestSessionOutputIsBounded`.
- **Status:** fixed by Phase 4, [gleipnir#6](https://github.com/ouroboric-dev/gleipnir/pull/6).

### B-028: a hung engine hangs `ygg` in `Down`

- **Where:** `gleipnir/sandbox/driver.go, odin/internal/engine/engine.go`.
- **Problem:** `Down` runs under `context.WithoutCancel` with no timeout.
- **Fix:** Add a bounded timeout. Test: `TestDownGivesUpOnAHungEngine`.
- **Status:** fixed by Phase 4, [gleipnir#6](https://github.com/ouroboric-dev/gleipnir/pull/6).

### B-063: the web ladder does not protect `.devcontainer/`

- **Where:** `midgard-react/devcontainer/checks/web-protected.sh` (`files=('.npmrc' '.github/')`),
  `midgard-react/templates/web/.devcontainer/devcontainer.json`, `midgard-react/prompts/implementer.md`.
  Compare `helheim-go/devcontainer/checks/go-static.sh` (`protected=('.devcontainer/' '.github/')`).
- **Problem:** the Go ladder refuses a change to `.devcontainer/`. The web ladder does not. The web template's
  `devcontainer.json` reaches every web product, and the implementer prompt tells the agent not to change it, but
  nothing enforces that. `go-static.sh` says why it matters: the dev container is what a person's editor runs. This
  predates the plan, but the plan's decision ("protected like the dev container") assumed parity.
- **Fix:** add `'.devcontainer/'` to `files` in `web-protected.sh`, with one refusal-test case. Fold in the deferred
  minors: the header of `web-protected.sh` does not name `.github/`; no test covers a deleted or gitignored
  workflow; `hasLine` in `ci_test.go` (a closure in `TestTemplateCI`) does not check parent keys.
- **Timing:** a guardrail gap, not a blocker. It should land before Phase 5c adds more web changes.
- **Status:** proved (the file list, read at `main`). Fixed 2026-10-19 in
  [midgard-react#14](https://github.com/ouroboric-dev/midgard-react/pull/14), with tests that failed first:
  `TestEveryRungRefusesADevContainerOrWorkflowChange` (both folders, every rung, a deleted and an ignored file
  included) and `TestMisplacedFindsALineUnderTheWrongKey` (the template CI's lines count only under their keys). The rest of the
  plan's list (the shared list, a rung that fails with no list) followed in
  [midgard-react#15](https://github.com/ouroboric-dev/midgard-react/pull/15).

### B-055: a product's own CI reads the tool configs that the ladder ignores, and the lint config files that no rung protects

- **Where:** `helheim-go/templates/api/.github/workflows/ci.yml` (`golangci-lint run --config .golangci.yml`);
  `midgard-react/templates/web/.github/workflows/ci.yml` (`npm run lint`, `typecheck`, `test` and `build` read
  `eslint.config.js`, `tsconfig.json` and `vite.config.ts`). Readiness: helheim-go and midgard-react, RR-15 and
  RR-18.
- **Problem:** since B-049, the ladder runs the configs baked into `/opt/ygg/checks/config` and ignores the leaf's
  copies. It does not refuse a change to them. The product's CI runs the leaf's copies. So a factory run can
  weaken a product's own CI config, for example an ESLint rule turned off, and every rung stays green. Only the
  reviewers would see it. A test pins the template's copies to the baked ones, but only in the realm, not in a
  product.
- **Why it matters:** the product CI is the second line of defence (Ginnungagap design §8.1). It is only as strong
  as the configs an agent may edit.
- **Fix:** one founder decision for both realms. Either the ladder refuses a change to the tool configs (as it
  refuses a change to `.github/`), or the product CI runs the factory's configs, not the leaf's. Then say it in each
  template's `AGENTS.md` (B-049's open consequence).
- **Widened (2026-10-19, the realm-readiness final review):** the same hole covers the files of the base CI that
  every product gets. The repo-bootstrap `init` (change `repo-bootstrap`, delta §4.2) gives each product a
  `.github/workflows/lint.yml` and a `.pre-commit-config.yaml`. `go-static.sh` (helheim-go, `devcontainer/checks`)
  and `web-protected.sh` (midgard-react, `devcontainer/checks`) protect `.github/`, which covers `lint.yml`. But
  `lint.yml` runs whatever `.pre-commit-config.yaml` says, and no rung refuses a change to that file. The same holds
  for `.gitleaksignore` and `.gitleaks.toml`, `.markdownlint*.yaml`, `.yamllint*`, `.shellcheckrc`, `REUSE.toml`,
  `LICENSES/` and `LICENSE`. So a factory run could neuter the product's required `lint` check, gitleaks included,
  with every rung green. The decision above covers this whole set: it is one founder decision. Only the reviewers
  would see it.
- **Status:** reasoned. Fixed 2026-10-19 by the change `protected-configs`
  ([proposal](changes/2026-10-19-protected-configs/proposal.md)): the ladder refuses a change to the tool configs
  and to the base-CI, licence and lint files, in both realms. One shared list, `devcontainer/checks/protected-common`,
  is read by `go-static.sh` ([helheim-go#9](https://github.com/ouroboric-dev/helheim-go/pull/9)) and
  `web-protected.sh` ([midgard-react#15](https://github.com/ouroboric-dev/midgard-react/pull/15)), plus each stack's
  own config names. `check-repos.sh --check shared` keeps the two copies equal
  ([ouroboric#60](https://github.com/ouroboric-dev/ouroboric/pull/60)). A task's change to a protected file is
  refused when it is added, changed, deleted, moved, swapped for a symlink, untracked or ignored. Tests that failed
  first are in both realms. A fix wave after the final review ([helheim-go#10](https://github.com/ouroboric-dev/helheim-go/pull/10),
  [midgard-react#16](https://github.com/ouroboric-dev/midgard-react/pull/16)) closed three holes: a root folder
  added as a symlink, a tag named `main`, and a config force-added under `node_modules`. The leaks left are B-090
  and B-091.

### B-066: midgard-react's workflow refusal test lists its rungs by hand

- **Where:** `midgard-react/checks_test.go` (`TestEveryRungRefusesAWorkflowChange`).
- **Problem:** the test names its rungs in a list. Phase 5c's `web-deps.sh` went into the `.npmrc` test and not into
  this one.
- **Fix:** derive the rungs from `pack.yaml` `leaf.checks`, in both tests. **Status:** proved (the diff of Phase 5c's
  #13). Fixed 2026-10-19 in [midgard-react#15](https://github.com/ouroboric-dev/midgard-react/pull/15): the rungs of
  the refusal tests come from `pack.yaml` `leaf.checks`.

### B-070: helheim-go's `go-static.sh` protects less than midgard-react's `web-protected.sh`

- **Where:** `helheim-go/devcontainer/checks/go-static.sh` (the `== protected paths` block),
  `helheim-go/checks_test.go` (`TestStaticRefusesAWorkflowChange`).
- **Problem:** four differences, all in the weaker direction:
  - With no `main`, `go-static.sh` skips the protection (`if base="$(git merge-base HEAD main …)"`). The web script
    fails closed.
  - `--diff-filter=AMD` drops a type change, so a symlink swap is not listed.
  - `git ls-files --others --exclude-standard` ignores gitignored files.
  - The test has no delete case and no untracked case, and the script's comment names only the dev container.
- **Fix:** copy the web script's behaviour (fail closed, no diff filter, untracked files including ignored ones),
  with a test case for each. **Status:** proved (the reading of both scripts).
  Fixed 2026-10-19 in [helheim-go#9](https://github.com/ouroboric-dev/helheim-go/pull/9): `go-static.sh` fails closed
  with no `main`, no diff filter, untracked files including ignored ones, and a test case for each. The fix wave
  [helheim-go#10](https://github.com/ouroboric-dev/helheim-go/pull/10) made the refusal tests assert the refusal line
  and the message indent every path.
