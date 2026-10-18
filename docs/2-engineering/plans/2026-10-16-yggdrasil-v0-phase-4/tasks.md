---
title: Yggdrasil v0, Phase 4 tasks (loop, findings and caps)
status: accepted
date: 2026-10-16
related: [../2026-10-12-yggdrasil-v0/plan.md, ../2026-10-16-yggdrasil-v0-phase-3/tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../changes/2026-10-12-require-budget-caps/proposal.md, ../../changes/2026-10-16-loop-escalation-and-spend/proposal.md, ../../backlog.md]
style: spec
---

# Yggdrasil v0, Phase 4: loop, findings and caps

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking. Tasks and steps marked **founder** are done by the founder,
> never by an agent.

**Goal:** the [plan](../2026-10-12-yggdrasil-v0/plan.md)'s Phase 4 exit criterion. A malformed
reviewer output stops the loop. A run that hits a cap stops resumable. Findings close only with proof.

**Architecture:** Gungnir gets what the other components share: how a session can fail, the budget cap
and its meter, a `loop` node in the graph, a reviewer's report, and the ledger events and approval
point they need. Gleipnir's adapters say how a failed session failed, keep a session's final answer,
count what a session that didn't finish used, and bound its output; its driver stops mistaking podman's
failures for a command's; and it gets the check runner. Jormungandr, empty until now, becomes the loop:
a state machine that runs an implementer and a ladder of checks and read-only reviewers for a bounded
number of attempts, a book of findings that only their source can close, the retry policy with its
backoff, and the text each session is told. Odin gives the loop its steps (sessions, checks, ledger
lines, `run.json`), counts every session's usage in the run and in a daily spend journal, refuses to
start a session over a cap, pauses a run when the provider's quota is used up, and stops a loop that
gave up at a new approval point for a person.

**Tech stack:** Go 1.26 and the pins of Phase 3. No new third-party dependency: Jormungandr uses
Gungnir alone.

**Spec:** [v0 engineering spec](../../specs/2026-10-11-yggdrasil-v0-spec.md) §2.1, §2.2, §4.2, §4.3,
§4.4, §4.6, §7, §10.1, §12, §13 and §14; and the accepted changes in `docs/2-engineering/changes/`
where they override it (`require-budget-caps`, `remote-creates-repos`, `benchmark-split`,
`factory-issues`, `project-is-its-own-tree`), plus the change this plan adds,
[loop-escalation-and-spend](../../changes/2026-10-16-loop-escalation-and-spend/proposal.md), which
records the places where the spec was silent and this phase had to choose.

**Status:** accepted when the founder merges the pull request that adds this file.

**Code in this plan was run.** Every Go file, script, schema and test below was built and run in a
scratch Go workspace on 2026-10-16, one commit per task, with `go test -race` on Go 1.26.4 and on
1.26.9, CI's version. Each task's end state was also built and tested on its own, and each task's
first test run was checked to fail as its step says (a task whose tests pass at once says so). The
tests also pass with `HOME` pointing at nothing and with no network; as root, all pass but the sandbox
tests that Phase 3 already limited to a normal user. Real model sessions are the one thing not run
(v0-H11: they use the founder's tokens). Copy the code as written; if a step's expected result
differs, stop and report it, because the plan is wrong.

Code blocks are of two kinds. A new file is shown whole. A change to an existing file is shown as a
git patch (`diff`); apply it with `git apply` from the repo's folder, or edit by hand: lines that
start with `+` are added, lines with `-` removed.

## Decisions for this phase

Each line is **Decided 2026-10-16** when the founder merges this plan.

1. **The original plan stands, and so does Phase 3.** The v0 plan's Phase 4 row and the spec are the
   scope. Sandcastle stays out (decided 2026-10-16): nothing here is proposed from it or borrowed
   from it. Phase 3's decisions 1 to 20 stand: the sandbox driver, the `claude-code` and `opencode`
   adapters and their auth, `privacy: strict`, secret scanning, the read-only role check, skills in the
   prompt, and Phase 2's decision 8 as amended (a resume saves what it discards to
   `refs/ygg/<run>/discarded/<n>`, except for a sandboxed leaf, whose unscanned work is discarded:
   Phase 3's ruling I5).
2. **The loop is a node kind, and Jormungandr decides what comes next.** A graph's `loop` node names a
   leaf, an implementer role and prompt, up to ten `attempts` (3 when unset), the pack `checks` that run
   after each attempt in order, and up to five `reviewers`, each a role and a prompt that run read-only
   once every check has passed (spec §4.2, §9.5). Jormungandr is a Go package that depends on Gungnir
   alone. It owns the loop's state machine, the finding book, the retry policy and the text of the
   feedback and the review request. It runs no session, no command and no git, and writes no ledger line:
   Odin gives it `Steps` that do. What both sides share lives in Gungnir (spec §1): `FailureKind` and
   `SessionError`, the budget `Meter` and `CapError`, `Report`, the `loop` node.
3. **A session's end has one of four kinds** (spec §12). *Agent*: a non-zero exit, a timeout, a turn
   limit, output that can't be used; it counts as a loop attempt. *Transient*: HTTP 408, 429 or 5xx, a
   network error, a CLI that crashed before its first event. *Quota*: a used-up plan limit, credit
   balance or key limit, whatever status carries it. *Infra*: the sandbox or the engine failing under the
   session. The adapters decide, from the HTTP status and the message, in one table
   (`failure.Classify`); a plain error and any failure the table doesn't know is an agent failure. That is
   the safe reading: the loop is bounded, so a failure we can't name costs attempts and never loops
   forever. **The words providers use are known for OpenRouter's errors (read from real output in
   Phase 3) and assumed for Claude Code's;** v0-H11 asks the founder to send back the text of any real
   failure so the table can learn it, and a wrong guess changes one line of one file. A rejected
   credential (HTTP 401) is an agent failure too: it costs the loop's attempts at once and says why.
4. **Retries, the pause and the infrastructure stop** (spec §12). A transient failure is retried up to
   three times, after 5, 10 and 20 seconds, and is not a loop attempt; the leaf goes back to its
   checkpoint before each retry, so a dropped session's half work never reaches the next try. Retries that
   run out fail the run, which a resume tries again. A used-up quota pauses the run: a new status
   `paused`, exit code 4, the reason in `run.json` and the ledger (`run_paused`); `ygg resume` starts the
   node again from its checkpoint once the quota is back. An infrastructure failure fails the run with no
   retry. A sandbox that won't start stays what Phase 3 made it. Every wait and every retry is in the
   ledger (`retry`).
5. **The day's spend is a journal outside every project.** The per-day cap counts what every run of the
   operator spent that day, in every project, because the operator's subscription is one. Every
   session's usage is appended to `<state>/ygg/spend/YYYY-MM-DD.jsonl` (the folder is
   `$XDG_STATE_HOME`, or `~/.local/state`; `budget.journal` in `factory.yaml` names another), one
   `O_APPEND` write per line, synced, mode 0600. A day is the operator's local day. A line cut short
   by a crash is ignored; any other line that isn't a spend entry makes the day's cap unreadable, and a
   cap that can't be read is treated as reached (`journal`, in the stop's message). The journal is
   written before `run.json` is, so a crash counts a session twice at worst, never not at all.
6. **What a cap counts.** Tokens are input plus output, with cache creation in input; cache reads are
   reported beside them in the ledger and are not counted, because a long session rereads its context
   every turn and would reach any cap that was fit for a day's work. (One function,
   `Usage.CapTokens`, decides it.) Dollars count only when a role bills a paid API, as the spend limit
   of `require-budget-caps` says; a subscription's dollar figure is what the run would cost. A cap is
   reached when use equals it, so a cap of zero stops everything. Turns are a cap too, and also a bound:
   a session gets the turns the caps still allow, or its own `max_turns` when that is fewer, so one
   session can't run far past a cap that is checked between sessions. Tokens can't be bounded inside a
   session, so a run can overshoot a token cap by at most one session, and two runs at once by one session
   each. Every cap is checked before every session, a retry too.
7. **A loop that gives up stops the run at a new approval point, `escalation`, in every mode.** The spec's
   §7.3 says "stop and ask" for the first two modes and "mark the task blocked, continue with the tasks
   that do not depend on it" for unattended, and its table of approval points has no row for either. A
   linear graph has no task to continue with, and the realm's `for each ready task` comes with the web
   realm (Phase 5). So `escalation` is a soft approval point that stops in all three modes; an unattended
   run's ledger says `blocked` instead of `stopped`; and the continue-with-the-rest half of §7.3 waits
   for Phase 5. It takes both decisions of a gate. *Reject* with a reason gives the loop another full set
   of attempts, with its findings and the reason in the implementer's prompt. *Approve* lets the work
   go on as it is, only after attempts ran out; the findings stay open in the ledger, since only a
   check or a reviewer can close one. A reviewer whose answer can't be read twice is not approvable
   (decision 8): nobody can take that decision for it. `escalation` can't be overridden to `auto`.
8. **Findings are the loop's only feedback, and only their source closes them** (spec §4.6). A finding's
   id is stable: a failing check's is `check-<name>`, so the same problem keeps one finding across
   attempts and a check that passes closes it, with the passing run as proof. A reviewer answers with
   one JSON document, `{"findings": [...]}`, optionally in one code fence and in nothing else;
   `ParseReport` refuses prose, a second document, an unknown field, a finding with no `file:line`, a
   `fixed` finding with no proof and an id used twice. On top of that a report must: carry only the
   reviewer's own findings; mention every finding it still held open (none may vanish); close one only
   with a proof that cites a `file:line` and names a check that passed in that attempt (the reviewer can't
   run one: Odin tells it which passed); and not close what isn't open or open one already closed
   (it reopens). An answer that breaks any of this, or a reviewer session that fails as an agent, is
   asked **once more, without a new implementer attempt**; the second time the loop escalates. The
   implementer's own claim that something is fixed is never read. A text field of a finding is bounded
   (id and source 100 characters, location 300, claim 4,000, proof 2,000), since findings go back into
   a prompt every attempt.
9. **A minor finding is recorded, shown to the implementer and never fails a loop alone.** A loop
   passes when no blocker or major finding is open. The spec doesn't say; without this, a reviewer's
   nit could cost the attempts a blocker needs.
10. **The cap stops at `budget-cap`, hard, and approving does not waive it.** The stop happens before the
    session that would start over a cap, with the work so far committed and the loop's state saved: a loop
    that stops between attempts resumes the same attempt and loses no finding. `ygg approve` lets the run
    go on, and the next session stops it again if the cap is still reached. The operator raises the cap
    in `factory.yaml` (a change the ledger records as `config_changed`), or waits for the day to turn, and
    then approves. A cap is the operator's own limit: no approval is a one-off exception to it. The
    ledger also gets a `budget_warning` once for each cap that is 80% used, `ygg status` shows the use
    of every cap, and `ygg doctor` shows them and checks the journal can be written.
11. **Every session's usage counts, whether it succeeded or not** (backlog B-019, B-020). An adapter that
    returns an error returns the usage it could read in it (`SessionError.Usage`), a lower bound: the
    `claude-code` adapter adds up the assistant messages of a session that left no result, each message
    once; the `opencode` adapter adds up the steps that finished. An `opencode` session that failed after
    it spent tokens with no cost is refused like one that succeeded, and its tokens count. A session's
    output is bounded in memory and in its transcript at 32 MiB (B-021); a longer one is an agent
    failure.
12. **Checks and the ladder** (spec §9.5). A loop's checks are pack checks, run through the check runner
    of Gleipnir in the leaf's sandbox, or on the host in a run without one, in order, each with Odin's
    ten-minute limit; the leaf goes back to the attempt's commit after each (backlog B-004). The ladder
    stops at the first check that fails, so reviewers run only on work that passed every check, and the
    slower rungs wait. A failing check's finding has its location at its log (`file:line` of
    `logs/<node>-<attempt>-<check>.log:1`) and the end of its output, up to 3,000 characters, as its claim.
    Odin's other commands (exec nodes, a merge's and a pointer's checks) run through the same runner.
    **A merge gate's refusal still fails the node and a resume runs it again;** wiring it back into the
    loop needs the web realm's graph (Phase 5).
13. **The loop's state is in `run.json`,** saved at every boundary: the attempt, its phase (`implement` or
    `ladder`), every finding with its history, the failure of the last session. A resume, an approval
    after a cap, and a crash start the loop where it was: an attempt in progress runs again from the
    leaf's last commit, the ladder runs again from its first rung, and the implementer does not run again
    when only the ladder was interrupted. A session that fails as an agent costs the attempt, and what it
    wrote is discarded (saved to a ref, except for a sandboxed leaf: decision 1). A rejection at a gate
    after a loop starts the loop over, with the reason as guidance. The ledger gets `loop_attempt`,
    `finding_raised`, `finding_closed` (with the attempts it took and how often it came back),
    `finding_reopened`, `escalation`, `retry` and `run_paused`. A session's number in the ledger
    (`ygg.attempt` on its lines) counts sessions of that node, a retry included; the loop's attempt is on
    its `loop_attempt` lines.
14. **A read-only role is checked by comparing the leaf before and after its session,** ignored files
    included (B-018, with `git status --porcelain --ignored -uall`): a file that appeared or went is a
    hard stop at `policy-violation`, and a file that was already there is not the reader's doing. A
    quarantine inside a loop is never retried and never resumed on its own (spec §12); only approving it
    puts the leaf back.
15. **Podman's own failure is an error** (B-016, B-017). `podman exec` exits 125 when podman failed, so a
    driver's `Exec` returns an error for 125 and every other exit code stays the command's; an `Up`
    whose closed-network probe exits 125 is refused. An error under a command is an infrastructure
    failure of the node, never a failed check. `Down` gives up after two minutes (B-028).
16. **Backlog.** B-016, B-017, B-018, B-019, B-020, B-021 and B-028 are fixed here, and so is B-012 (a hard
    stop offers `approve` only). The others stay open: this phase doesn't touch their code.
17. **Tests.** They write nothing under the real `HOME`: every Odin test package sets `XDG_STATE_HOME` to a
    folder of its own, and each CLI test gets a journal of its own. They need no network and no engine.
    Tests that prepare a sandbox keep Phase 3's rule, a normal user (Odin's CI runs as one); the two this
    phase adds skip as root.
18. **Documentation.** The architecture pages of Jormungandr and Odin say what they now do. The spec is
    not edited: the places where it was silent or this phase chose are a change proposal,
    `changes/2026-10-16-loop-escalation-and-spend/`, which this plan's pull request adds and the founder's
    merge accepts, and which folds into `system/` later like the others.
19. **Sizes count insertions,** as git reports them. One task that would have been L is split: the spend
    journal and the meter (v0-T126, v0-T127).
20. **Pull requests and pins.** Five pull requests, in this order, each opened once the one before is
    merged and pinned: `gungnir` (v0-T097 to v0-T105), `gleipnir` (v0-T106 to v0-T116, pinning gungnir),
    `jormungandr` (v0-T117 to v0-T124, pinning gungnir), `odin` (v0-T125 to v0-T140, pinning all three),
    and `yggdrasil` (v0-T141). Gleipnir's and Jormungandr's pull requests don't depend on each other and
    can be open together. `jormungandr` has no CI yet; the `test` check is the founder's to turn on
    (v0-H10): the pr-bot can't push workflow files.

## Global constraints

- **Local copies.** The component repos are submodules of `yggdrasil`, at
  `/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`, and `yggdrasil/go.work` builds them together.
  Each task works on a branch in the submodule it changes. The umbrella's pointers move once, in
  v0-T141.
- **GitHub.** Agents reach GitHub only as `ouroboric-pr-bot`, through
  `/home/brunogbv/brunogbv/ouroboric/ouroboric/scripts/as-bot.sh`. `as-bot.sh <repo> <command>` pushes
  and opens PRs; `as-bot.sh --read all <command>` reads. Every change lands through a PR the founder
  merges. Agents never merge and never push to `main`.
- **Commits.** Read `git status --short` first, and stage explicit paths, never `git add -A`. Commit
  messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commits and PRs carry
  no session links. Every repo runs the `gitleaks` hook.
- **Go.** `go.mod` says `go 1.26`. Code is `gofmt`-clean and `go vet`-clean. Before a PR opens, the
  repo passes `GOWORK=off go test -race ./...` in its own folder, as CI runs it. This machine has Go
  1.26.4; CI uses 1.26.9.
- **Podman.** Nothing in this phase needs the engine except v0-H11. Claude Code's sandbox blocks the
  engine's socket, so a command that reaches it runs with `dangerouslyDisableSandbox` and the founder's
  approval, as in Phase 3.
- **Credentials.** Real tokens (`CLAUDE_CODE_OAUTH_TOKEN`, `OPENROUTER_API_KEY`) belong to the
  founder's runs (v0-H11). No agent reads, prints or stores `~/.config/ouroboric/factory.env`, and
  the tests use made-up values.
- **Pins.** Phase 3's. This phase adds none.
- **Licences.** `reuse lint` (`reuse==5.0.2`) passes in every repo a task touches.
- **The hidden suite.** No agent reads, lists or searches `ouroboric-dev/huldra` or its clone under
  `~/brunogbv/ouroboric-private/`.
- **Deletions** (`rm`, `git branch -D`) are asked for first, one per command, after a read-only check.
- **Tests are hermetic.** A test never writes under the real `HOME`, never needs the network or an
  engine, and passes in any working directory. A test that opens a spend journal gives it a folder of
  its own.

## Review focus

1. **A reviewer's answer counted as a pass when it isn't one.** Prose, a second document, a finding with
   no place, a report that drops a finding or closes one with only the reviewer's word, a finding
   that belongs to another source. Expected: the reviewer is asked once more, then the loop stops for a
   person, nothing is approved on the reviewer's behalf, and no finding closes. Pinned by v0-T102
   `TestParseReport`, v0-T120 `TestAReviewerReportThatBreaksARuleChangesNothing`, v0-T123
   `TestAReviewerThatCannotBeReadIsAskedAgainOnceAndThenTheLoopEscalates`, v0-T136
   `TestAMalformedReviewerOutputStopsTheLoopAndIsNeverAPass` and v0-T138
   `TestAFindingClosesOnlyWhenItsSourceConfirmsItWithProof`.
2. **Spend that isn't counted, or a cap that can't be checked.** A session that failed or timed out, other
   runs and other projects the same day, a journal line that is not an entry, a journal that can't be
   written. Expected: the tokens count, the day's total is the journal's, and a cap that can't be read
   is a reached cap. Pinned by v0-T108 and v0-T110 `TestATimedOutSessionStillCountsItsUsage` (one in
   each adapter), v0-T109 `TestAFailedSessionWithTokensAndNoCostIsRefused`, v0-T126
   `TestACutShortLastLineIsIgnoredAndAnyOtherBadLineStopsTheCount`,
   v0-T128 `TestAFailedSessionsUsageStillCounts`, v0-T129 `TestThePerDayCapCountsWhatOtherRunsSpent` and
   `TestAJournalThatCannotBeReadStopsTheRun`.
3. **A stop that loses an attempt, a finding or work, or repeats an attempt.** A cap between attempts or
   before a reviewer, a quota in the middle of the ladder, an interrupted attempt, a rejection, a run that
   is reopened. Expected: the same attempt runs again, the findings are as they were, the implementer does
   not run again when only the ladder was interrupted, and half-written work is gone. Pinned by v0-T137
   `TestACapBetweenTwoAttemptsStopsTheRunAndTheSameAttemptGoesOnWhenItIsRaised`, `TestACapBeforeAReviewerStopsAtTheLadderAndAResumeDoesNotRunTheImplementerAgain`,
   `TestAQuotaUsedUpInTheMiddleOfTheLadderPausesTheRunAndTheLadderRunsAgain` and
   `TestARunInterruptedInAnAttemptResumesThatAttemptWithTheFindings`, and v0-T123 `TestACapOrAQuotaStopsTheLoopWhereItIsAndAResumeGoesOnFromThere`.
4. **A failure counted as the wrong kind.** A rate limit that costs loop attempts, a used-up quota that
   is retried three times and then fails the run, an agent failure that is retried, a podman failure that
   reads as a failed check. Expected: transient failures are retried and are not attempts, a quota pauses,
   infrastructure stops, everything unknown is an attempt. Pinned by v0-T106 `TestClassify`, v0-T107
   `TestAFailedSessionSaysHowItFailed` and `TestASessionThatEndedWithoutAResultSaysHowItFailed`, v0-T109
   `TestAnAPIErrorSaysHowItFailed`, v0-T112 `TestExecReportsAMissingContainerAsAnError`, and v0-T130 `TestATransientFailureIsRetriedWithABackoffAndLeavesNoTraceInTheAttempts`,
   `TestAnAgentFailureIsNotRetried` and `TestAUsedUpQuotaPausesTheRunAndAResumeStartsTheNodeAgain`.
5. **A read-only reviewer that changes the leaf, and text from a hostile repository in a finding.** A file
   a reviewer writes that `.gitignore` names, a check whose output carries instructions. Expected: the
   file is a hard stop and the leaf is kept as evidence; a finding's text is bounded and goes only into
   the next implementer's prompt, which already reads the same repository. Pinned by v0-T135
   `TestAReviewerThatWritesAnIgnoredFileIsAHardStop` and `TestAReadOnlyRoleThatWritesAnIgnoredFileIsAHardStop`,
   and v0-T105 `TestAFindingsTextsAreBounded`.

## Order

| Task | Repo | Size | Depends on |
| --- | --- | --- | --- |
| v0-T097 how a session fails, and its final answer | `gungnir` | M | Phase 3 |
| v0-T098 budget caps: the error, the meter, when a cap is reached | `gungnir` | M | v0-T097 |
| v0-T099 `factory.yaml`: where the spend journal lives | `gungnir` | S | v0-T098 |
| v0-T100 ledger events for retries, a pause and findings | `gungnir` | S | v0-T097 |
| v0-T101 the approval point `escalation` | `gungnir` | S | v0-T100 |
| v0-T102 a reviewer's report | `gungnir` | M | v0-T100 |
| v0-T103 the `loop` node | `gungnir` | M | v0-T101 |
| v0-T104 a journal that can't be read is a reached cap | `gungnir` | S | v0-T098 |
| v0-T105 a finding's texts are bounded | `gungnir` | S | v0-T102 |
| v0-T106 deciding how a failed session failed | `gleipnir` | S | v0-T097 merged |
| v0-T107 `claude-code`: failures and the final answer | `gleipnir` | M | v0-T106 |
| v0-T108 `claude-code`: unfinished sessions and a bound on output | `gleipnir` | M | v0-T107 |
| v0-T109 `opencode`: failures, the final answer, B-019 | `gleipnir` | M | v0-T108 |
| v0-T110 `opencode`: unfinished sessions and a bound | `gleipnir` | S | v0-T109 |
| v0-T111 scripted: failures, usage, answers, reports | `gleipnir` | M | v0-T097 merged |
| v0-T112 the driver: podman's failure is an error | `gleipnir` | S | v0-T111 |
| v0-T113 the driver: `Down` gives up | `gleipnir` | S | v0-T112 |
| v0-T114 the check runner | `gleipnir` | M | v0-T113 |
| v0-T115 scripted: the turns a session was given | `gleipnir` | S | v0-T111 |
| v0-T116 scripted: whether a session was read-only | `gleipnir` | S | v0-T115 |
| v0-T117 the loop's outcomes and `Classify` | `jormungandr` | M | v0-T097 merged |
| v0-T118 retries with a backoff | `jormungandr` | M | v0-T117 |
| v0-T119 the finding book: checks | `jormungandr` | M | v0-T117 |
| v0-T120 the finding book: reviewers and proof | `jormungandr` | M | v0-T119, v0-T102 merged |
| v0-T121 what the next attempt and a reviewer are told | `jormungandr` | M | v0-T120 |
| v0-T122 the bounded loop: attempts and checks | `jormungandr` | M | v0-T121 |
| v0-T123 the bounded loop: reviewers, caps, quotas | `jormungandr` | M | v0-T122 |
| v0-T124 Jormungandr's documentation | `jormungandr` | S | v0-T123 |
| v0-T125 `escalation` in the mode table | `odin` | S | v0-T101 merged |
| v0-T126 the spend journal | `odin` | M | Phase 3 |
| v0-T127 the meter | `odin` | M | v0-T126, v0-T104 merged |
| v0-T128 a session's usage is counted | `odin` | M | v0-T127; v0-T099, v0-T111, v0-T118 merged |
| v0-T129 caps stop the run | `odin` | M | v0-T128; v0-T115 merged |
| v0-T130 retries, the quota pause, infrastructure | `odin` | M | v0-T129 |
| v0-T131 warnings, `status`, `doctor` | `odin` | M | v0-T130 |
| v0-T132 commands through the check runner | `odin` | M | v0-T131, v0-T114 merged |
| v0-T133 loop nodes in a run | `odin` | M | v0-T132, v0-T103 merged |
| v0-T134 the loop in a run | `odin` | M | v0-T133, v0-T123 merged |
| v0-T135 reviewers in the loop | `odin` | M | v0-T134; v0-T116 merged |
| v0-T136 a loop that gives up | `odin` | M | v0-T135 |
| v0-T137 a loop stops and resumes | `odin` | M | v0-T136 |
| v0-T138 the exit criteria, whole stack | `odin` | M | v0-T137 |
| v0-T139 the loop smoke realm | `odin` | S | v0-T138 |
| v0-T140 Odin's documentation | `odin` | S | v0-T139 |
| v0-T141 pointers and the exit check | `yggdrasil` | S | all above, merged |
| v0-H10 (founder) `test` required on `jormungandr` | GitHub | S | v0-T124 merged |
| v0-H11 (founder) one real loop | the founder's machine | S | v0-T139 merged; Phase 3's v0-H07 |

Gungnir's nine tasks go up as one pull request, one commit per task; gleipnir's eleven as one, opened
once gungnir's is merged and pinned; jormungandr's eight as one, opened the same way; odin's sixteen as
one, opened once all three are merged and pinned. Inside a repo the tasks stack on one branch.

## Not in Phase 4

The web realm's graph and the `for each ready task` that lets an unattended run block a task and
carry on with the rest (§7.3's second half), and with it the merge gate's refusal going back into the
loop (§4.5); the check ladder's real rungs (Phase 5); the TDD check (new tests must fail on the
parent), which is a rung; the metrics that read this phase's ledger lines (`ygg metrics`, Phase 6);
a per-check timeout and a per-loop budget of its own (a loop stops at the run's and the day's caps);
an implementer's way to dispute a finding (the status exists and a reviewer may use it; nothing
produces it); parsing a retry-after header; a spend limit for the sandbox's resources (carried
beyond v0); acceptance checks with a sandbox (Phase 5); the backlog items this phase doesn't touch.

## How each task lands

Every agent task ends the same way. Run the commands in the repo's folder,
`/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`:

```bash
gofmt -l .                        # prints nothing
go vet ./...
GOWORK=off go test -race ./...    # what CI runs
uvx -q --from 'reuse==5.0.2' reuse lint -q
git status --short                # then stage the task's files by path
git commit -m "<what changed> (v0-T0xx)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

When the repo's last task is committed, push and open its pull request:

```bash
../../ouroboric/scripts/as-bot.sh <repo> git push -u origin <branch>
../../ouroboric/scripts/as-bot.sh <repo> gh pr create --repo ouroboric-dev/<repo> --title "<title>" --body-file <file>
```

The PR body names the tasks, lists their acceptance criteria with their evidence (the named tests'
output), and says which earlier PRs it needs merged first. CI's `test` check must be green before the
founder merges it. Jormungandr has none until v0-H10: its PR is checked by the commands above, and its
output goes in the PR body.

To pin a sibling, fetch it, then pin its `main`:

```bash
../../ouroboric/scripts/as-bot.sh --read all git -C ../gungnir fetch -q origin
GOWORK=off go get github.com/ouroboric-dev/gungnir@$(git -C ../gungnir rev-parse origin/main)
GOWORK=off go mod tidy
```

`gleipnir` pins `gungnir`; `jormungandr` pins `gungnir`; `odin` pins `gungnir`, `gleipnir` and
`jormungandr` (and keeps `havamal`). Until a sibling's PR is merged, develop through `yggdrasil/go.work`,
as Phase 2 and Phase 3 did, and add the pin as the last commit once it merges. Jormungandr's first pin
also writes its `require` lines: `go mod tidy` adds Gungnir's own dependencies.

---

### Task v0-T097: how a session fails, and its final answer

Gungnir's first task. The loop and the retry policy need to tell a session that failed as an agent does
from one that failed for a reason that is not the agent's (spec §12), and a reviewer's findings arrive
in its final answer, which a summary clipped to a thousand characters cannot carry (spec §4.6).
Branch `contract/loop` from `main` in `gungnir`, before step 1.

**Files (in `gungnir`):**

- Modify: `agent.go`, `gungnir_test.go`

**Interfaces:**

- Produces: `gungnir.FailureKind` with `FailureAgent`, `FailureTransient`, `FailureQuota`,
  `FailureInfra`; `gungnir.MaxOutput` (256 KiB); `Result.Failure FailureKind` (a failed result's kind; empty
  means agent) and `Result.Output string` (the session's whole final answer).
- Produces: `*gungnir.SessionError{Kind FailureKind; Err error; Usage Usage}`, an adapter's error for a
  session that ended without a usable result, and `gungnir.FailureOf(err error) FailureKind`, the kind
  of the first `*SessionError` in an error's chain, or `FailureAgent` for any other error. `Usage` is a
  lower bound: what could be read of the session before it ended.
- `Result.Validate` refuses a kind on a successful result, a kind that is not agent, transient or quota
  (infra is an error's kind, never a result's), and an output over `MaxOutput`.

**Acceptance criteria:**

- [ ] `Validate` refuses a failure kind on a success, an unknown kind, `infra` as a result's kind, and an
      answer one byte over the limit; it accepts an answer at the limit and every kind it allows.
- [ ] `FailureOf` reads a `*SessionError` through wrapping, treats a `*SessionError` with no kind and a
      plain error as an agent failure, and the usage and the message survive wrapping.

**Named test:** `go test . -run 'TestAResultNamesHowItFailed|TestFailureOfReadsASessionError'` in
`gungnir`. **Layer:** `gungnir`. **Size:** M (106). **Depends on:** Phase 3.

- [ ] **Step 1:** write the tests.

Apply to `gungnir_test.go`:

```diff
diff --git a/gungnir_test.go b/gungnir_test.go
index 068fe20..f79327a 100644
--- a/gungnir_test.go
+++ b/gungnir_test.go
@@ -1,8 +1,11 @@
 package gungnir
 
 import (
+	"errors"
+	"fmt"
 	"math"
 	"slices"
+	"strings"
 	"testing"
 )
 
@@ -97,3 +100,47 @@ func TestFindingValidate(t *testing.T) {
 		t.Errorf("fixed with proof: %v", err)
 	}
 }
+
+func TestAResultNamesHowItFailed(t *testing.T) {
+	for _, k := range []FailureKind{"", FailureAgent, FailureTransient, FailureQuota} {
+		if err := (Result{Status: StatusFailed, Failure: k}).Validate(); err != nil {
+			t.Errorf("failure %q: Validate() = %v, want nil", k, err)
+		}
+	}
+	bad := map[string]Result{
+		"a kind on a success":   {Status: StatusOK, Failure: FailureQuota},
+		"an unknown kind":       {Status: StatusFailed, Failure: "flaky"},
+		"infra is not a result": {Status: StatusFailed, Failure: FailureInfra},
+		"an answer too long":    {Status: StatusOK, Output: strings.Repeat("x", MaxOutput+1)},
+	}
+	for name, r := range bad {
+		if err := r.Validate(); err == nil {
+			t.Errorf("%s: Validate() = nil, want an error", name)
+		}
+	}
+	if err := (Result{Status: StatusOK, Output: strings.Repeat("x", MaxOutput)}).Validate(); err != nil {
+		t.Errorf("an answer at the limit: Validate() = %v, want nil", err)
+	}
+}
+
+func TestFailureOfReadsASessionError(t *testing.T) {
+	quota := fmt.Errorf("wrapped: %w", &SessionError{Kind: FailureQuota, Err: errors.New("credits used up"), Usage: Usage{Turns: 3}})
+	cases := map[string]struct {
+		err  error
+		want FailureKind
+	}{
+		"a quota error":            {quota, FailureQuota},
+		"an infra error":           {&SessionError{Kind: FailureInfra, Err: errors.New("podman")}, FailureInfra},
+		"a session error w/o kind": {&SessionError{Err: errors.New("x")}, FailureAgent},
+		"a plain error":            {errors.New("exit 1"), FailureAgent},
+	}
+	for name, c := range cases {
+		if got := FailureOf(c.err); got != c.want {
+			t.Errorf("%s: FailureOf() = %q, want %q", name, got, c.want)
+		}
+	}
+	var se *SessionError
+	if !errors.As(quota, &se) || se.Usage.Turns != 3 || !strings.Contains(quota.Error(), "credits used up") {
+		t.Errorf("the usage and the message must survive wrapping: %v", quota)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./gungnir_test.go:105:22: undefined: FailureKind
./gungnir_test.go:105:38: undefined: FailureAgent
./gungnir_test.go:105:52: undefined: FailureTransient
```

- [ ] **Step 3:** write the code.

Apply to `agent.go`:

```diff
diff --git a/agent.go b/agent.go
index aaa60b9..9d3408f 100644
--- a/agent.go
+++ b/agent.go
@@ -3,6 +3,7 @@ package gungnir
 
 import (
 	"context"
+	"errors"
 	"fmt"
 	"math"
 	"time"
@@ -60,14 +61,58 @@ func (u Usage) Add(v Usage) Usage {
 	}
 }
 
+// FailureKind says how a session failed, which decides what happens next (spec §12).
+type FailureKind string
+
+const (
+	// FailureAgent is the default: a non-zero exit, a timeout, a turn limit or output that can't be
+	// read. It counts as a loop attempt.
+	FailureAgent FailureKind = "agent"
+	// FailureTransient is an HTTP 429 or 5xx, a network error or a CLI that crashed at start. It is
+	// retried with backoff, and is not a loop attempt.
+	FailureTransient FailureKind = "transient"
+	// FailureQuota is a provider quota or credit that is used up. The run pauses until it is back.
+	FailureQuota FailureKind = "quota"
+	// FailureInfra is the sandbox or the engine failing under a session. The run stops, with no retry loop.
+	FailureInfra FailureKind = "infra"
+)
+
+// MaxOutput is the most bytes of a session's final answer a Result holds. A longer answer is an
+// agent failure, never a truncated pass.
+const MaxOutput = 256 << 10
+
 // Result is how a session ended and what it cost.
 type Result struct {
 	Status         Status
 	Summary        string
 	Usage          Usage
 	TranscriptPath string
-	Provider       string // who served the model, such as "anthropic" or "openrouter"; may be empty
-	CLIVersion     string // the agent tool's version; may be empty
+	Provider       string      // who served the model, such as "anthropic" or "openrouter"; may be empty
+	CLIVersion     string      // the agent tool's version; may be empty
+	Failure        FailureKind // a failed result: how it failed; empty means FailureAgent
+	Output         string      // the session's final answer, whole, up to MaxOutput bytes; a reviewer's findings come in it
+}
+
+// SessionError is a session that ended without a usable Result. Usage is what could be read of the
+// session before it ended: a lower bound, so the caps count at least that much. A plain error from an
+// adapter is an agent failure.
+type SessionError struct {
+	Kind  FailureKind
+	Err   error
+	Usage Usage
+}
+
+func (e *SessionError) Error() string { return e.Err.Error() }
+func (e *SessionError) Unwrap() error { return e.Err }
+
+// FailureOf returns how err failed a session: the kind of the first *SessionError in its chain, or
+// FailureAgent for any other error.
+func FailureOf(err error) FailureKind {
+	var se *SessionError
+	if errors.As(err, &se) && se.Kind != "" {
+		return se.Kind
+	}
+	return FailureAgent
 }
 
 // Validate refuses a result that could be misread as a pass. Missing or malformed data is never
@@ -83,5 +128,17 @@ func (r Result) Validate() error {
 	if u.CostUSD < 0 || math.IsNaN(u.CostUSD) || math.IsInf(u.CostUSD, 0) {
 		return fmt.Errorf("result cost %v is not a finite, non-negative number", u.CostUSD)
 	}
+	switch r.Failure {
+	case "":
+	case FailureAgent, FailureTransient, FailureQuota:
+		if r.Status != StatusFailed {
+			return fmt.Errorf("result status %q has a failure kind %q", r.Status, r.Failure)
+		}
+	default:
+		return fmt.Errorf("result failure kind %q is not agent, transient or quota", r.Failure)
+	}
+	if len(r.Output) > MaxOutput {
+		return fmt.Errorf("result output is %d bytes, over the limit of %d", len(r.Output), MaxOutput)
+	}
 	return nil
 }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T098: budget caps: the error, the meter, and when a cap is reached

Spec §7.4 stops a run that reaches a cap. Phase 1 made the caps required; this task is the contract
that lets a component ask whether one is reached, and say which.

**Files (in `gungnir`):**

- Create: `budget.go`, `budget_test.go`
- Modify: `schema/factory.go`, `schema/factory_test.go`

**Interfaces:**

- Consumes: `gungnir.Usage` (Phase 1), `schema.Cap`, `schema.Budget`, `schema.PaidAPI`.
- Produces: `gungnir.CapScope` (`CapRun`, `CapDay`), `gungnir.CapDimension` (`CapTokens`, `CapTurns`,
  `CapUSD`); `*gungnir.CapError{Scope; Dimension; Used, Limit float64}`, with an `Error()` that says the
  scope, the dimension and the figures; `gungnir.Meter`, `interface{ Check() *CapError }`, nil when every
  cap has room; `Usage.CapTokens() int64`, input plus output tokens, cache reads not counted (decision 6).
- Produces: `schema.Cap.Reached(scope CapScope, u Usage, usd bool) *CapError`, the first limit that use
  has reached (tokens, then turns, then dollars when `usd`), where reached means use equals the limit;
  `(*schema.Factory).PaysPerToken() bool`, whether any role bills a paid API.

**Acceptance criteria:**

- [ ] `CapTokens` counts input and output tokens and ignores cache reads.
- [ ] A cap is reached at its limit, not past it; a cap of zero is reached at once.
- [ ] Dollars count only when `usd` is true; a subscription's dollars never reach a cap.
- [ ] A `CapError`'s message names the scope and the dimension and shows the figures.

**Named test:** `go test ./... -run 'TestCapTokensCountsInputAndOutputNotCacheReads|TestACapErrorSaysWhatWasReached|TestCapReached|TestPaysPerToken'`
in `gungnir`. **Layer:** `gungnir`. **Size:** M (130). **Depends on:** v0-T097.

- [ ] **Step 1:** write the tests.

Write `budget_test.go`:

```go
package gungnir

import (
	"strings"
	"testing"
)

func TestCapTokensCountsInputAndOutputNotCacheReads(t *testing.T) {
	u := Usage{InTok: 100, OutTok: 20, CacheTok: 5000}
	if got := u.CapTokens(); got != 120 {
		t.Errorf("CapTokens() = %d, want 120: cache reads are reported beside the count, not in it", got)
	}
}

func TestACapErrorSaysWhatWasReached(t *testing.T) {
	e := &CapError{Scope: CapDay, Dimension: CapTokens, Used: 41, Limit: 40}
	if got := e.Error(); !strings.Contains(got, "per-day") || !strings.Contains(got, "tokens") || !strings.Contains(got, "41") || !strings.Contains(got, "40") {
		t.Errorf("Error() = %q", got)
	}
	usd := &CapError{Scope: CapRun, Dimension: CapUSD, Used: 1.5, Limit: 1}
	if got := usd.Error(); !strings.Contains(got, "$1.5000") || !strings.Contains(got, "per-run") {
		t.Errorf("Error() = %q", got)
	}
}
```

Apply to `schema/factory_test.go`:

```diff
diff --git a/schema/factory_test.go b/schema/factory_test.go
index e91e1f9..b4e2ad8 100644
--- a/schema/factory_test.go
+++ b/schema/factory_test.go
@@ -160,3 +160,38 @@ func TestFactoryNamesAnUnknownAgentBeforeAskingForASpendLimit(t *testing.T) {
 		}
 	}
 }
+
+func TestCapReached(t *testing.T) {
+	c := Cap{Tokens: 1000, Turns: 10, USD: 2}
+	cases := []struct {
+		name string
+		u    gungnir.Usage
+		usd  bool
+		want gungnir.CapDimension // "" for no cap reached
+	}{
+		{"room left", gungnir.Usage{InTok: 400, OutTok: 500, Turns: 9, CostUSD: 1.99}, true, ""},
+		{"tokens exactly at the cap", gungnir.Usage{InTok: 600, OutTok: 400}, true, gungnir.CapTokens},
+		{"cache reads don't count", gungnir.Usage{InTok: 1, CacheTok: 1 << 40}, true, ""},
+		{"turns at the cap", gungnir.Usage{Turns: 10}, true, gungnir.CapTurns},
+		{"dollars at the cap on a paid API", gungnir.Usage{CostUSD: 2}, true, gungnir.CapUSD},
+		{"dollars of a subscription never count", gungnir.Usage{CostUSD: 500}, false, ""},
+	}
+	for _, tc := range cases {
+		got := c.Reached(gungnir.CapRun, tc.u, tc.usd)
+		switch {
+		case tc.want == "" && got != nil, tc.want != "" && (got == nil || got.Dimension != tc.want):
+			t.Errorf("%s: Reached() = %+v, want %q", tc.name, got, tc.want)
+		}
+	}
+	if got := (Cap{}).Reached(gungnir.CapDay, gungnir.Usage{}, false); got == nil || got.Scope != gungnir.CapDay {
+		t.Errorf("a cap of zero: Reached() = %+v, want it reached at once", got)
+	}
+}
+
+func TestPaysPerToken(t *testing.T) {
+	sub := &Factory{Roles: map[string]Role{"a": {Agent: "claude-code"}, "b": {Agent: "scripted"}}}
+	paid := &Factory{Roles: map[string]Role{"a": {Agent: "claude-code"}, "b": {Agent: "opencode"}}}
+	if sub.PaysPerToken() || !paid.PaysPerToken() {
+		t.Errorf("PaysPerToken() = %v and %v, want false and true", sub.PaysPerToken(), paid.PaysPerToken())
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./budget_test.go:10:14: u.CapTokens undefined (type Usage has no field or method CapTokens)
./budget_test.go:16:8: undefined: CapError
./budget_test.go:16:24: undefined: CapDay
```

- [ ] **Step 3:** write the code.

Write `budget.go`:

```go
package gungnir

import "fmt"

// CapScope says which budget cap was reached (spec §7.4).
type CapScope string

const (
	CapRun CapScope = "run"
	CapDay CapScope = "day"
)

// CapDimension says what the cap limits.
type CapDimension string

const (
	CapTokens CapDimension = "tokens"
	CapTurns  CapDimension = "turns"
	CapUSD    CapDimension = "usd"
)

// CapError is a budget cap that has been reached: the run stops at the hard approval point
// budget-cap, with everything resumable (spec §7.4).
type CapError struct {
	Scope     CapScope
	Dimension CapDimension
	Used      float64
	Limit     float64
}

func (e *CapError) Error() string {
	if e.Dimension == CapUSD {
		return fmt.Sprintf("the per-%s cap is reached: $%.4f spent of $%.4f", e.Scope, e.Used, e.Limit)
	}
	return fmt.Sprintf("the per-%s %s cap is reached: %.0f used of %.0f", e.Scope, e.Dimension, e.Used, e.Limit)
}

// Meter says whether the budget lets another session start.
type Meter interface {
	// Check returns the cap that is reached, or nil when every cap still has room.
	Check() *CapError
}

// CapTokens is the number of tokens a cap counts: input and output tokens. Cache reads are reported
// beside them in the ledger and don't count (Phase 4, decision 6).
func (u Usage) CapTokens() int64 { return u.InTok + u.OutTok }
```

Apply to `schema/factory.go`:

```diff
diff --git a/schema/factory.go b/schema/factory.go
index 890277f..a8ff605 100644
--- a/schema/factory.go
+++ b/schema/factory.go
@@ -68,6 +68,31 @@ type Cap struct {
 	USD    float64 `yaml:"usd"`
 }
 
+// Reached returns the first limit of c that u has reached, or nil. A limit is reached when use equals
+// it, so a cap of zero stops everything. Dollars count only when usd is true, which is when a role
+// bills a paid API (see PaidAPI): a subscription's dollar figure is what the run would cost on the API.
+func (c Cap) Reached(scope gungnir.CapScope, u gungnir.Usage, usd bool) *gungnir.CapError {
+	switch {
+	case u.CapTokens() >= c.Tokens:
+		return &gungnir.CapError{Scope: scope, Dimension: gungnir.CapTokens, Used: float64(u.CapTokens()), Limit: float64(c.Tokens)}
+	case u.Turns >= c.Turns:
+		return &gungnir.CapError{Scope: scope, Dimension: gungnir.CapTurns, Used: float64(u.Turns), Limit: float64(c.Turns)}
+	case usd && u.CostUSD >= c.USD:
+		return &gungnir.CapError{Scope: scope, Dimension: gungnir.CapUSD, Used: u.CostUSD, Limit: c.USD}
+	}
+	return nil
+}
+
+// PaysPerToken reports whether any role of f bills a paid API, so the caps count dollars.
+func (f *Factory) PaysPerToken() bool {
+	for _, r := range f.Roles {
+		if PaidAPI(r.Agent) {
+			return true
+		}
+	}
+	return false
+}
+
 // agents are the adapters factory.schema.json accepts.
 var agents = []string{"claude-code", "opencode", "scripted"}
 
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T099: `factory.yaml`: where the spend journal lives

The per-day cap sums a journal outside every project (decision 5). Its folder defaults to the
operator's state folder, and `budget.journal` names another.

**Files (in `gungnir`):**

- Modify: `schema/factory.go`, `schema/factory.schema.json`, `schema/factory_test.go`

**Interfaces:**

- Produces: `schema.Budget.Journal string` (`budget.journal`): an absolute, clean folder, or empty for
  the default. The schema accepts the key; `ParseFactory` refuses a relative or unclean path and an empty
  string.

**Acceptance criteria:**

- [ ] A config with `budget.journal: /var/lib/ygg/spend` parses and carries the path.
- [ ] A config without it parses with an empty path.
- [ ] A relative path, an unclean path (`/var/../spend`) and an empty string are refused.

**Named test:** `go test ./schema -run TestBudgetJournal` in `gungnir`. **Layer:** `gungnir`.
**Size:** S (24). **Depends on:** v0-T098.

- [ ] **Step 1:** write the tests.

Apply to `schema/factory_test.go`:

```diff
diff --git a/schema/factory_test.go b/schema/factory_test.go
index b4e2ad8..0647047 100644
--- a/schema/factory_test.go
+++ b/schema/factory_test.go
@@ -195,3 +195,19 @@ func TestPaysPerToken(t *testing.T) {
 		t.Errorf("PaysPerToken() = %v and %v, want false and true", sub.PaysPerToken(), paid.PaysPerToken())
 	}
 }
+
+func TestBudgetJournal(t *testing.T) {
+	caps := "budget:\n  per_run: { tokens: 1, turns: 1 }\n  per_day: { tokens: 1, turns: 1 }\n  journal: "
+	f, err := ParseFactory("factory.yaml", []byte(scriptedRoles+caps+"/var/lib/ygg/spend\n"))
+	if err != nil || f.Budget.Journal != "/var/lib/ygg/spend" {
+		t.Fatalf("ParseFactory() = %+v, %v", f, err)
+	}
+	if f, err := ParseFactory("factory.yaml", []byte(scriptedRoles+strings.TrimSuffix(caps, "  journal: "))); err != nil || f.Budget.Journal != "" {
+		t.Errorf("no journal: %+v, %v; want it empty", f, err)
+	}
+	for name, j := range map[string]string{"relative": "spend", "unclean": "/var/../spend", "empty": `""`} {
+		if _, err := ParseFactory("factory.yaml", []byte(scriptedRoles+caps+j+"\n")); err == nil {
+			t.Errorf("%s journal %q: ParseFactory() = nil, want an error", name, j)
+		}
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/factory_test.go:202:28: f.Budget.Journal undefined (type Budget has no field or method Journal)
schema/factory_test.go:205:131: f.Budget.Journal undefined (type Budget has no field or method Journal)
FAIL	github.com/ouroboric-dev/gungnir/schema [build failed]
```

- [ ] **Step 3:** write the code.

Apply to `schema/factory.go`:

```diff
diff --git a/schema/factory.go b/schema/factory.go
index a8ff605..4fdef55 100644
--- a/schema/factory.go
+++ b/schema/factory.go
@@ -57,8 +57,9 @@ type Price struct {
 
 // Budget holds the caps. Both are required, and the factory ships no default values.
 type Budget struct {
-	PerRun Cap `yaml:"per_run"`
-	PerDay Cap `yaml:"per_day"`
+	PerRun  Cap    `yaml:"per_run"`
+	PerDay  Cap    `yaml:"per_day"`
+	Journal string `yaml:"journal"` // an absolute folder for the spend journal the per-day cap sums; "" means the operator's state folder
 }
 
 // Cap limits tokens and turns, and dollars when a role bills a paid API.
@@ -222,6 +223,9 @@ func (f *Factory) CheckGates(mode gungnir.Mode) error {
 // checkSandbox refuses a real agent without a sandbox: an adapter for a real tool never runs on the
 // host (spec §6), and a sandbox that names the host's root or lists a path twice is ambiguous.
 func (f *Factory) checkSandbox() error {
+	if j := f.Budget.Journal; j != "" && (!filepath.IsAbs(j) || filepath.Clean(j) != j) {
+		return fmt.Errorf("budget.journal %q must be a clean, absolute path", j)
+	}
 	if f.Skills.PrivateDir != "" && !filepath.IsAbs(f.Skills.PrivateDir) {
 		return fmt.Errorf("skills.private_dir %q must be an absolute path", f.Skills.PrivateDir)
 	}
```

Apply to `schema/factory.schema.json`:

```diff
diff --git a/schema/factory.schema.json b/schema/factory.schema.json
index bcd33b4..3c6e8b9 100644
--- a/schema/factory.schema.json
+++ b/schema/factory.schema.json
@@ -30,7 +30,8 @@
       "required": ["per_run", "per_day"],
       "properties": {
         "per_run": { "$ref": "#/$defs/cap" },
-        "per_day": { "$ref": "#/$defs/cap" }
+        "per_day": { "$ref": "#/$defs/cap" },
+        "journal": { "type": "string", "minLength": 1, "description": "an absolute folder where every run of this operator records its spend, which the per-day cap sums; empty: $XDG_STATE_HOME/ygg/spend or ~/.local/state/ygg/spend" }
       }
     },
     "privacy": { "enum": ["standard", "strict"] },
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T100: ledger events for retries, a paused run and findings

Spec §10.1 lists the events a ledger holds. A retry, a paused run and a finding's life are the ones this
phase adds, with the finding's fields (`ygg.finding.*`; OpenTelemetry has no name for them).

**Files (in `gungnir`):**

- Modify: `event.go`, `schema/event_test.go`, `schema/ledger-event.schema.json`

**Interfaces:**

- Produces: `EventRetry` (`retry`), `EventRunPaused` (`run_paused`), `EventFindingRaised`
  (`finding_raised`), `EventFindingClosed` (`finding_closed`), `EventFindingReopened`
  (`finding_reopened`), all in `gungnir.Events()` and in the ledger schema's enum.
- Produces: `Event.FindingID`, `FindingSource`, `FindingSeverity`, `FindingAttempts`, `FindingReopens`
  (`ygg.finding.id`, `.source`, `.severity`, `.attempts`, `.reopens`). `FindingAttempts` and
  `FindingReopens` are how many attempts a closed finding took and how often it came back.

**Acceptance criteria:**

- [ ] Every event name validates against the schema, and an unknown one does not.
- [ ] A `finding_closed` line with its finding fields validates; a severity of `critical` does not.

**Named test:** `go test ./schema -run 'TestRetryPauseAndFindingEvents|TestLedgerEventSchema'` in
`gungnir`. **Layer:** `gungnir`. **Size:** S (47). **Depends on:** v0-T097.

- [ ] **Step 1:** write the tests.

Apply to `schema/event_test.go`:

```diff
diff --git a/schema/event_test.go b/schema/event_test.go
index 9143d87..2b578f5 100644
--- a/schema/event_test.go
+++ b/schema/event_test.go
@@ -43,7 +43,7 @@ func TestLedgerEventSchema(t *testing.T) {
 		}
 	}
 	bad := map[string]string{
-		"an unknown event": strings.Replace(mustJSON(t, event(gungnir.EventRunStarted)), `"run_started"`, `"run_paused"`, 1),
+		"an unknown event": strings.Replace(mustJSON(t, event(gungnir.EventRunStarted)), `"run_started"`, `"run_exploded"`, 1),
 		"no prev":          strings.Replace(mustJSON(t, event(gungnir.EventRunStarted)), `,"prev":"`+zeros+`"`, "", 1),
 		"a short prev":     strings.Replace(mustJSON(t, event(gungnir.EventRunStarted)), zeros, "abc", 1),
 		"an unknown field": strings.Replace(mustJSON(t, event(gungnir.EventRunStarted)), `{`, `{"tokens":5,`, 1),
@@ -100,3 +100,28 @@ func TestSandboxEvents(t *testing.T) {
 		}
 	}
 }
+
+func TestRetryPauseAndFindingEvents(t *testing.T) {
+	for name, n := range map[string]gungnir.EventName{"retry": gungnir.EventRetry, "run_paused": gungnir.EventRunPaused,
+		"finding_raised": gungnir.EventFindingRaised, "finding_closed": gungnir.EventFindingClosed, "finding_reopened": gungnir.EventFindingReopened} {
+		if string(n) != name || !slices.Contains(gungnir.Events(), n) {
+			t.Errorf("%s isn't a ledger event", name)
+		}
+	}
+	e := event(gungnir.EventFindingClosed)
+	e.Node, e.FindingID, e.FindingSource, e.FindingSeverity, e.FindingAttempts, e.FindingReopens = "build", "check-test", "test", "blocker", 3, 1
+	line := mustJSON(t, e)
+	for _, key := range []string{`"ygg.finding.id":"check-test"`, `"ygg.finding.source":"test"`, `"ygg.finding.severity":"blocker"`,
+		`"ygg.finding.attempts":3`, `"ygg.finding.reopens":1`} {
+		if !strings.Contains(line, key) {
+			t.Errorf("line lacks %s:\n%s", key, line)
+		}
+	}
+	if err := ValidateEvent([]byte(line)); err != nil {
+		t.Errorf("ValidateEvent() = %v", err)
+	}
+	bad := strings.Replace(line, `"blocker"`, `"critical"`, 1)
+	if err := ValidateEvent([]byte(bad)); err == nil {
+		t.Error("a finding with severity critical: ValidateEvent() = nil")
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/event_test.go:105:69: undefined: gungnir.EventRetry
schema/event_test.go:105:103: undefined: gungnir.EventRunPaused
schema/event_test.go:106:29: undefined: gungnir.EventFindingRaised
```

- [ ] **Step 3:** write the code.

Apply to `event.go`:

```diff
diff --git a/event.go b/event.go
index 18cf990..cf6f7b0 100644
--- a/event.go
+++ b/event.go
@@ -32,6 +32,12 @@ const (
 	EventRepoCreated     EventName = "repo_created" // a remote created a leaf (change remote-creates-repos)
 	EventSandboxUp       EventName = "sandbox_up"   // a leaf's sandbox started (spec §6)
 	EventSandboxDown     EventName = "sandbox_down" // a leaf's sandbox stopped
+
+	EventRetry           EventName = "retry"            // a transient failure; the session runs again after a backoff (spec §12)
+	EventRunPaused       EventName = "run_paused"       // the provider's quota is used up; the run waits, resumable (spec §12)
+	EventFindingRaised   EventName = "finding_raised"   // a check or reviewer reported a finding (spec §4.6)
+	EventFindingClosed   EventName = "finding_closed"   // its source confirmed the fix, with proof
+	EventFindingReopened EventName = "finding_reopened" // a closed finding was reported again
 )
 
 // Events returns every event name, in the order above.
@@ -40,7 +46,8 @@ func Events() []EventName {
 		EventNodeStarted, EventNodeFinished, EventNodeFailed, EventCheckResult, EventGatePending,
 		EventGateApproved, EventGateRejected, EventGateAutoPassed, EventLoopAttempt, EventEscalation,
 		EventRoutingLookup, EventBudgetWarning, EventPolicyViolation, EventPointerMoved,
-		EventModeChanged, EventConfigChanged, EventRepoCreated, EventSandboxUp, EventSandboxDown}
+		EventModeChanged, EventConfigChanged, EventRepoCreated, EventSandboxUp, EventSandboxDown,
+		EventRetry, EventRunPaused, EventFindingRaised, EventFindingClosed, EventFindingReopened}
 }
 
 // Event is one ledger line. Fields follow OpenTelemetry's GenAI attribute names (gen_ai.*) where
@@ -77,6 +84,12 @@ type Event struct {
 	Commit     string `json:"ygg.ref.commit,omitempty"`
 	GateFile   string `json:"ygg.ref.gate_file,omitempty"`
 
+	FindingID       string `json:"ygg.finding.id,omitempty"`
+	FindingSource   string `json:"ygg.finding.source,omitempty"`
+	FindingSeverity string `json:"ygg.finding.severity,omitempty"`
+	FindingAttempts int    `json:"ygg.finding.attempts,omitempty"` // finding_closed: the loop attempts the finding took to close
+	FindingReopens  int    `json:"ygg.finding.reopens,omitempty"`  // finding_closed, finding_reopened: how often it came back
+
 	Prev string `json:"prev"` // hex SHA-256 of the previous line; 64 zeros on the first line
 }
 
```

Apply to `schema/ledger-event.schema.json`:

```diff
diff --git a/schema/ledger-event.schema.json b/schema/ledger-event.schema.json
index c2b09ab..e4955ac 100644
--- a/schema/ledger-event.schema.json
+++ b/schema/ledger-event.schema.json
@@ -17,7 +17,8 @@
                "node_finished", "node_failed", "check_result", "gate_pending", "gate_approved",
                "gate_rejected", "gate_auto_passed", "loop_attempt", "escalation", "routing_lookup",
                "budget_warning", "policy_violation", "pointer_moved", "mode_changed", "config_changed",
-               "repo_created", "sandbox_up", "sandbox_down"]
+               "repo_created", "sandbox_up", "sandbox_down", "retry", "run_paused", "finding_raised",
+               "finding_closed", "finding_reopened"]
     },
     "ygg.attempt": { "type": "integer", "minimum": 1 },
     "gen_ai.agent.name": { "type": "string" },
@@ -40,6 +41,11 @@
     "ygg.config.sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
     "ygg.ref.commit": { "type": "string", "pattern": "^[0-9a-f]{40,64}$" },
     "ygg.ref.gate_file": { "type": "string" },
+    "ygg.finding.id": { "type": "string", "minLength": 1 },
+    "ygg.finding.source": { "type": "string", "minLength": 1 },
+    "ygg.finding.severity": { "enum": ["blocker", "major", "minor"] },
+    "ygg.finding.attempts": { "type": "integer", "minimum": 1 },
+    "ygg.finding.reopens": { "type": "integer", "minimum": 1 },
     "prev": { "type": "string", "pattern": "^[0-9a-f]{64}$" }
   }
 }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T101: the approval point `escalation`

Decision 7: a loop that gave up stops the run for a person in every mode. It is a soft approval point,
so a graph or a config can name it, and it can't be set to `auto`.

**Files (in `gungnir`):**

- Modify: `gate.go`, `gungnir_test.go`, `schema/factory.schema.json`, `schema/factory_test.go`, `schema/graph.schema.json`

**Interfaces:**

- Produces: `gungnir.GateEscalation` (`escalation`), a known, soft approval point, in `Gates()` (now 17),
  in `graph.schema.json`'s and `factory.schema.json`'s lists.

**Acceptance criteria:**

- [ ] `GateEscalation.Known()` is true and `.Hard()` is false.
- [ ] A graph may name it in a gate node; `gates: { escalation: stop }` parses and
      `gates: { escalation: auto }` is refused, naming `gates.escalation`.

**Named test:** `go test ./... -run 'TestEscalationIsASoftApprovalPoint|TestEscalationCanBeSetToStopButNeverToAuto|TestHardGatesAreTheSpecList|TestGraphSchemaKnowsEveryApprovalPoint'`
in `gungnir`. **Layer:** `gungnir`. **Size:** S (22). **Depends on:** v0-T100.

- [ ] **Step 1:** write the tests.

Apply to `gungnir_test.go`:

```diff
diff --git a/gungnir_test.go b/gungnir_test.go
index f79327a..063de1f 100644
--- a/gungnir_test.go
+++ b/gungnir_test.go
@@ -50,8 +50,8 @@ func TestHardGatesAreTheSpecList(t *testing.T) {
 			t.Errorf("%s.Known() = false", g)
 		}
 	}
-	if len(Gates()) != 16 {
-		t.Errorf("len(Gates()) = %d, want 16", len(Gates()))
+	if len(Gates()) != 17 {
+		t.Errorf("len(Gates()) = %d, want 17", len(Gates()))
 	}
 	if Gate("nope").Known() || Gate("nope").Hard() {
 		t.Error(`Gate("nope") is known or hard`)
@@ -144,3 +144,9 @@ func TestFailureOfReadsASessionError(t *testing.T) {
 		t.Errorf("the usage and the message must survive wrapping: %v", quota)
 	}
 }
+
+func TestEscalationIsASoftApprovalPoint(t *testing.T) {
+	if GateEscalation != "escalation" || !GateEscalation.Known() || GateEscalation.Hard() {
+		t.Errorf("escalation: known %v, hard %v; want a known, soft approval point", GateEscalation.Known(), GateEscalation.Hard())
+	}
+}
```

Apply to `schema/factory_test.go`:

```diff
diff --git a/schema/factory_test.go b/schema/factory_test.go
index 0647047..0e96c78 100644
--- a/schema/factory_test.go
+++ b/schema/factory_test.go
@@ -211,3 +211,13 @@ func TestBudgetJournal(t *testing.T) {
 		}
 	}
 }
+
+func TestEscalationCanBeSetToStopButNeverToAuto(t *testing.T) {
+	if _, err := ParseFactory("factory.yaml", []byte(scriptedRoles+fullCaps+"gates:\n  escalation: stop\n")); err != nil {
+		t.Errorf("escalation: stop: %v", err)
+	}
+	_, err := ParseFactory("factory.yaml", []byte(scriptedRoles+fullCaps+"gates:\n  escalation: auto\n"))
+	if err == nil || !strings.Contains(err.Error(), "gates.escalation") {
+		t.Errorf("escalation: auto: ParseFactory() = %v, want an error naming gates.escalation", err)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./gungnir_test.go:149:5: undefined: GateEscalation
./gungnir_test.go:150:80: undefined: GateEscalation
FAIL	github.com/ouroboric-dev/gungnir [build failed]
```

- [ ] **Step 3:** write the code.

Apply to `gate.go`:

```diff
diff --git a/gate.go b/gate.go
index 96e0568..e5b3684 100644
--- a/gate.go
+++ b/gate.go
@@ -16,6 +16,7 @@ const (
 	GateMerge           Gate = "merge"
 	GatePointer         Gate = "pointer"
 	GatePointerContract Gate = "pointer-contract"
+	GateEscalation      Gate = "escalation" // a loop ran out of attempts, or its reviewer's output could not be read (spec §7.3)
 
 	// The hard approval points stop in every mode, and no config can override them.
 	GateDeployProd      Gate = "deploy-prod"
@@ -30,7 +31,7 @@ const (
 )
 
 var (
-	softGates = []Gate{GateDesign, GateSpec, GatePlan, GateFeature, GateMerge, GatePointer, GatePointerContract}
+	softGates = []Gate{GateDesign, GateSpec, GatePlan, GateFeature, GateMerge, GatePointer, GatePointerContract, GateEscalation}
 	hardGates = []Gate{GateDeployProd, GateStoreSubmit, GateRealSecrets, GateBudgetCap, GateExternalInput,
 		GatePolicyViolation, GateShrinkGuard, GateGuardrailChange, GateRepoAdmin}
 )
```

Apply to `schema/factory.schema.json`:

```diff
diff --git a/schema/factory.schema.json b/schema/factory.schema.json
index 3c6e8b9..cecebb6 100644
--- a/schema/factory.schema.json
+++ b/schema/factory.schema.json
@@ -11,7 +11,7 @@
     "gates": {
       "type": "object",
       "propertyNames": {
-        "enum": ["design", "spec", "plan", "feature", "merge", "pointer", "pointer-contract",
+        "enum": ["design", "spec", "plan", "feature", "merge", "pointer", "pointer-contract", "escalation",
                  "deploy-prod", "store-submit", "real-secrets-or-user-data", "budget-cap",
                  "external-input", "policy-violation", "shrink-guard", "guardrail-change",
                  "repo-admin"]
```

Apply to `schema/graph.schema.json`:

```diff
diff --git a/schema/graph.schema.json b/schema/graph.schema.json
index 29f7980..8700bf5 100644
--- a/schema/graph.schema.json
+++ b/schema/graph.schema.json
@@ -55,7 +55,7 @@
             "id": { "$ref": "#/$defs/id" },
             "kind": { "const": "gate" },
             "gate": {
-              "enum": ["design", "spec", "plan", "feature", "merge", "pointer", "pointer-contract",
+              "enum": ["design", "spec", "plan", "feature", "merge", "pointer", "pointer-contract", "escalation",
                        "deploy-prod", "store-submit", "real-secrets-or-user-data", "budget-cap",
                        "external-input", "policy-violation", "shrink-guard", "guardrail-change",
                        "repo-admin"]
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T102: a reviewer's report

A reviewer answers in one JSON document (spec §4.6, decision 8). Reading it is Gungnir's: a malformed
answer must never read as an empty one.

**Files (in `gungnir`):**

- Create: `schema/report.schema.json`
- Modify: `finding.go`, `schema/event.go`, `schema/event_test.go`, `schema/schema.go`

**Interfaces:**

- Produces: `gungnir.Report{Findings []Finding}`; `schema.ParseReport(answer []byte) (gungnir.Report, error)`,
  which accepts one document `{"findings": [...]}`, bare or in one code fence and nothing else, and
  refuses: prose before or after it, two fences, an unclosed fence, an empty answer, no `findings`
  key, `findings: null`, an unknown key in the report or in a finding, a finding that fails
  `Finding.Validate` (no place, a `fixed` finding without proof, an unknown status), and an id used
  twice. An empty list is a well-formed report: the reviewer found nothing.
- Produces: `report.schema.json`. Every embedded schema is now a resource of the compiler, so one can
  refer to another by file name.

**Acceptance criteria:**

- [ ] The five well-formed shapes parse (no findings, an open finding, open and fixed, in a fence, in a
      bare fence).
- [ ] Each of the fourteen malformed shapes is an error: unreadable output is never a pass.

**Named test:** `go test ./schema -run TestParseReport` in `gungnir`. **Layer:** `gungnir`.
**Size:** M (126). **Depends on:** v0-T100.

- [ ] **Step 1:** write the tests.

Apply to `schema/event_test.go`:

````diff
diff --git a/schema/event_test.go b/schema/event_test.go
index 2b578f5..32e5652 100644
--- a/schema/event_test.go
+++ b/schema/event_test.go
@@ -125,3 +125,42 @@ func TestRetryPauseAndFindingEvents(t *testing.T) {
 		t.Error("a finding with severity critical: ValidateEvent() = nil")
 	}
 }
+
+func TestParseReport(t *testing.T) {
+	open := `{"id":"spec-1","source":"spec","severity":"major","location":"api/auth.go:42","claim":"no throttle","status":"open"}`
+	fixed := `{"id":"spec-2","source":"spec","severity":"minor","location":"api/auth.go:50","claim":"no doc","status":"fixed","proof":"api/auth.go:51 adds it; check test passed"}`
+	for name, answer := range map[string]string{
+		"no findings":     `{"findings":[]}`,
+		"an open finding": `{"findings":[` + open + `]}`,
+		"open and fixed":  "\n  {\"findings\":[" + open + "," + fixed + "]}\n",
+		"in a fence":      "```json\n{\"findings\":[" + open + "]}\n```\n",
+		"in a bare fence": "```\n{\"findings\":[]}\n```",
+	} {
+		r, err := ParseReport([]byte(answer))
+		if err != nil {
+			t.Errorf("%s: ParseReport() = %v", name, err)
+		} else if name == "open and fixed" && (len(r.Findings) != 2 || r.Findings[1].Proof == "") {
+			t.Errorf("%s: findings = %+v", name, r.Findings)
+		}
+	}
+	for name, answer := range map[string]string{
+		"prose":                    "The code looks fine to me.",
+		"prose before the report":  "Here you go:\n{\"findings\":[]}",
+		"prose after a fence":      "```json\n{\"findings\":[]}\n```\nDone.",
+		"two fences":               "```json\n{\"findings\":[]}\n```\n```json\n{\"findings\":[]}\n```",
+		"an unclosed fence":        "```json\n{\"findings\":[]}",
+		"an empty answer":          "",
+		"no findings key":          `{}`,
+		"findings null":            `{"findings":null}`,
+		"an extra key":             `{"findings":[],"verdict":"pass"}`,
+		"a finding with no place":  `{"findings":[{"id":"a","source":"s","severity":"major","claim":"c","status":"open"}]}`,
+		"fixed with no proof":      `{"findings":[{"id":"a","source":"s","severity":"major","location":"a.go:1","claim":"c","status":"fixed"}]}`,
+		"an unknown status":        `{"findings":[{"id":"a","source":"s","severity":"major","location":"a.go:1","claim":"c","status":"closed"}]}`,
+		"an id used twice":         `{"findings":[` + open + `,` + open + `]}`,
+		"a finding with extra key": `{"findings":[{"id":"a","source":"s","severity":"major","location":"a.go:1","claim":"c","status":"open","fix":"x"}]}`,
+	} {
+		if r, err := ParseReport([]byte(answer)); err == nil {
+			t.Errorf("%s: ParseReport() = %+v, nil; want an error: unreadable output is never a pass", name, r)
+		}
+	}
+}
````

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/event_test.go:139:13: undefined: ParseReport
schema/event_test.go:162:16: undefined: ParseReport
FAIL	github.com/ouroboric-dev/gungnir/schema [build failed]
```

- [ ] **Step 3:** write the code.

Apply to `finding.go`:

```diff
diff --git a/finding.go b/finding.go
index 9d24067..4d5890c 100644
--- a/finding.go
+++ b/finding.go
@@ -63,3 +63,8 @@ func (f Finding) Validate() error {
 	}
 	return errors.Join(errs...)
 }
+
+// Report is a reviewer's whole answer: every finding it holds open or closes (spec §4.6).
+type Report struct {
+	Findings []Finding `json:"findings"`
+}
```

Apply to `schema/event.go`:

````diff
diff --git a/schema/event.go b/schema/event.go
index e28cfde..475777f 100644
--- a/schema/event.go
+++ b/schema/event.go
@@ -3,7 +3,9 @@ package schema
 import (
 	"bytes"
 	"encoding/json"
+	"errors"
 	"fmt"
+	"strings"
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/santhosh-tekuri/jsonschema/v6"
@@ -36,3 +38,56 @@ func ParseFinding(data []byte) (gungnir.Finding, error) {
 	}
 	return f, f.Validate()
 }
+
+// ParseReport parses a reviewer's answer: one JSON document with a findings list, which may be wrapped
+// in a single code fence and in nothing else. Prose, a second document, a finding without a location, a
+// fixed finding without proof and an id used twice are errors, never an empty report: an answer that
+// can't be read doesn't count as a pass (spec §4.6).
+func ParseReport(answer []byte) (gungnir.Report, error) {
+	var r gungnir.Report
+	data, err := unfence(string(answer))
+	if err != nil {
+		return r, err
+	}
+	doc, err := jsonschema.UnmarshalJSON(strings.NewReader(data))
+	if err != nil {
+		return r, fmt.Errorf("report: %w", err)
+	}
+	if err := validate("report", "report.schema.json", doc); err != nil {
+		return r, err
+	}
+	dec := json.NewDecoder(strings.NewReader(data))
+	dec.DisallowUnknownFields()
+	if err := dec.Decode(&r); err != nil {
+		return r, fmt.Errorf("report: %w", err)
+	}
+	seen := map[string]bool{}
+	for _, f := range r.Findings {
+		if err := f.Validate(); err != nil {
+			return gungnir.Report{}, fmt.Errorf("report: finding %q: %w", f.ID, err)
+		}
+		if seen[f.ID] {
+			return gungnir.Report{}, fmt.Errorf("report: finding id %q is used twice", f.ID)
+		}
+		seen[f.ID] = true
+	}
+	return r, nil
+}
+
+// unfence returns the JSON of an answer that is a bare document, or one document in one code fence.
+func unfence(answer string) (string, error) {
+	s := strings.TrimSpace(answer)
+	if !strings.HasPrefix(s, "```") {
+		return s, nil
+	}
+	_, body, ok := strings.Cut(s, "\n")
+	body = strings.TrimSpace(body)
+	if !ok || !strings.HasSuffix(body, "```") {
+		return "", errors.New("report: a code fence is not closed")
+	}
+	body = strings.TrimSpace(strings.TrimSuffix(body, "```"))
+	if strings.Contains(body, "```") {
+		return "", errors.New("report: more than one code fence")
+	}
+	return body, nil
+}
````

Write `schema/report.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/report.schema.json",
  "title": "a reviewer's report",
  "description": "A reviewer's whole answer: every finding it holds open or closes, and nothing else (spec §4.6). An empty list says it found nothing.",
  "type": "object",
  "additionalProperties": false,
  "required": ["findings"],
  "properties": {
    "findings": { "type": "array", "maxItems": 200, "items": { "$ref": "finding.schema.json" } }
  }
}
```

Apply to `schema/schema.go`:

```diff
diff --git a/schema/schema.go b/schema/schema.go
index 6cba8e0..2c57a93 100644
--- a/schema/schema.go
+++ b/schema/schema.go
@@ -19,19 +19,26 @@ var files embed.FS
 
 const base = "https://github.com/ouroboric-dev/gungnir/schema/"
 
-// compile compiles one embedded schema. Its $id must be base + name.
+// compile compiles one embedded schema. Its $id must be base + name. Every embedded schema is a
+// resource of the compiler, so a schema may refer to another by its file name.
 func compile(name string) (*jsonschema.Schema, error) {
-	raw, err := files.ReadFile(name)
+	entries, err := files.ReadDir(".")
 	if err != nil {
 		return nil, err
 	}
-	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(raw))
-	if err != nil {
-		return nil, fmt.Errorf("%s: %w", name, err)
-	}
 	c := jsonschema.NewCompiler()
-	if err := c.AddResource(base+name, doc); err != nil {
-		return nil, err
+	for _, e := range entries {
+		raw, err := files.ReadFile(e.Name())
+		if err != nil {
+			return nil, err
+		}
+		doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(raw))
+		if err != nil {
+			return nil, fmt.Errorf("%s: %w", e.Name(), err)
+		}
+		if err := c.AddResource(base+e.Name(), doc); err != nil {
+			return nil, err
+		}
 	}
 	return c.Compile(base + name)
 }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T103: the `loop` node

Spec §4.2's implement ⇄ check ladder loop is a node of the graph. A gate that is rejected after a loop
sends the work back to the loop.

**Files (in `gungnir`):**

- Modify: `schema/graph.go`, `schema/graph.schema.json`, `schema/graph_test.go`

**Interfaces:**

- Produces: `schema.KindLoop`; `schema.DefaultAttempts` (3); `Node.Attempts int`,
  `Node.Reviewers []Reviewer`; `schema.Reviewer{ID, Role, Prompt string; Skills []string; MaxTurns int;
  Timeout Duration}`; `Node.SessionKey(Reviewer) string`, `<loop id>-<reviewer id>`, which names a
  reviewer's sessions in the ledger, the transcripts and a script. A loop node also takes `repo`, `role`,
  `prompt`, `skills`, `max_turns`, `timeout` (each session's) and `checks`.
- `ParseGraph` sets `Attempts` to 3 when unset; refuses a loop with neither checks nor reviewers, with no
  repo or role or prompt, with attempts under 1 or over 10, with `read_only` or `run`, with a check
  twice, with more than five reviewers, a reviewer id used twice, a prompt outside the realm, or a
  reviewer's session key that is a node id or another loop's key. A gate re-runs the nearest agent *or
  loop* node before it.

**Acceptance criteria:**

- [ ] The example loop parses, with its defaults, and the gate after it re-runs it.
- [ ] Each refusal above is an error that names the cause.

**Named test:** `go test ./schema -run 'TestParseGraphLoopNodes|TestParseGraphRefusesLoops|TestParseGraphRefuses|TestParseGraphResolvesWhatARejectionReruns'`
in `gungnir`. **Layer:** `gungnir`. **Size:** M (186). **Depends on:** v0-T101.

- [ ] **Step 1:** write the tests.

Apply to `schema/graph_test.go`:

```diff
diff --git a/schema/graph_test.go b/schema/graph_test.go
index 1120300..bc6c2af 100644
--- a/schema/graph_test.go
+++ b/schema/graph_test.go
@@ -3,6 +3,7 @@ package schema
 import (
 	"os"
 	"path/filepath"
+	"slices"
 	"strings"
 	"testing"
 	"time"
@@ -46,12 +47,12 @@ func TestParseGraphRefuses(t *testing.T) {
 	const bySchema = "jsonschema validation failed"
 	cases := map[string]struct{ nodes, want string }{
 		"a duplicate id":                   {"  - { id: a, kind: exec, run: [echo] }\n  - { id: a, kind: exec, run: [echo] }\n", "used twice"},
-		"a loop node (not yet)":            {"  - { id: a, kind: loop }\n", bySchema},
-		"a gate with nothing before it":    {"  - { id: g, kind: gate, gate: design }\n", "no agent node before it"},
-		"a gate after only exec nodes":     {"  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: plan }\n", "no agent node before it"},
-		"a gate that re-runs a later node": {agent + "  - { id: g, kind: gate, gate: plan, reruns: b }\n  - { id: b, kind: agent, role: planner, prompt: p.md }\n", "must be an agent node before it"},
-		"a gate that re-runs a gate":       {agent + "  - { id: g, kind: gate, gate: plan }\n  - { id: h, kind: gate, gate: feature, reruns: g }\n", "must be an agent node before it"},
-		"a gate that re-runs an exec node": {agent + "  - { id: e, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: plan, reruns: e }\n", "must be an agent node before it"},
+		"a loop with nothing in it":        {"  - { id: a, kind: loop }\n", bySchema},
+		"a gate with nothing before it":    {"  - { id: g, kind: gate, gate: design }\n", "no agent or loop node before it"},
+		"a gate after only exec nodes":     {"  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: plan }\n", "no agent or loop node before it"},
+		"a gate that re-runs a later node": {agent + "  - { id: g, kind: gate, gate: plan, reruns: b }\n  - { id: b, kind: agent, role: planner, prompt: p.md }\n", "must be an agent or loop node before it"},
+		"a gate that re-runs a gate":       {agent + "  - { id: g, kind: gate, gate: plan }\n  - { id: h, kind: gate, gate: feature, reruns: g }\n", "must be an agent or loop node before it"},
+		"a gate that re-runs an exec node": {agent + "  - { id: e, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: plan, reruns: e }\n", "must be an agent or loop node before it"},
 		"an unknown approval point":        {"  - { id: a, kind: exec, run: [echo] }\n  - { id: g, kind: gate, gate: ship }\n", bySchema},
 		"exec without a command":           {"  - { id: a, kind: exec }\n", bySchema},
 		"agent with a command":             {"  - { id: a, kind: agent, role: planner, prompt: p.md, run: [echo] }\n", bySchema},
@@ -191,3 +192,79 @@ nodes:
 		}
 	}
 }
+
+const loopGraph = `
+name: loopy
+version: 1.0.0
+nodes:
+  - id: build
+    kind: loop
+    repo: repos/app
+    role: implementer
+    prompt: prompts/build.md
+    skills: [ponytail-review]
+    max_turns: 60
+    timeout: 20m
+    checks: [vet, test]
+    reviewers:
+      - { id: spec, role: reviewer, prompt: prompts/review-spec.md, max_turns: 20, timeout: 10m }
+      - { id: quality, role: reviewer, prompt: prompts/review-quality.md, skills: [ponytail-review] }
+  - { id: feature-gate, kind: gate, gate: feature }
+`
+
+func TestParseGraphLoopNodes(t *testing.T) {
+	g, err := ParseGraph("graph.yaml", []byte(loopGraph))
+	if err != nil {
+		t.Fatalf("ParseGraph() = %v", err)
+	}
+	n := g.Nodes[0]
+	if n.Kind != KindLoop || n.Attempts != DefaultAttempts || DefaultAttempts != 3 || !slices.Equal(n.Checks, []string{"vet", "test"}) ||
+		len(n.Reviewers) != 2 || n.Reviewers[1].ID != "quality" || time.Duration(n.Reviewers[0].Timeout) != 10*time.Minute ||
+		n.SessionKey(n.Reviewers[0]) != "build-spec" {
+		t.Errorf("the loop node = %+v", n)
+	}
+	if g.Nodes[1].Reruns != "build" {
+		t.Errorf("the gate after a loop re-runs %q, want build", g.Nodes[1].Reruns)
+	}
+	g, err = ParseGraph("graph.yaml", []byte(strings.Replace(loopGraph, "    checks: [vet, test]\n", "    checks: [vet, test]\n    attempts: 5\n", 1)))
+	if err != nil || g.Nodes[0].Attempts != 5 {
+		t.Errorf("attempts: 5: %+v, %v", g.Nodes[0].Attempts, err)
+	}
+}
+
+func TestParseGraphRefusesLoops(t *testing.T) {
+	head := "name: l\nversion: 1.0.0\nnodes:\n"
+	loop := "  - { id: build, kind: loop, repo: repos/app, role: implementer, prompt: p.md, checks: [vet] }\n"
+	rev := func(id string) string {
+		return "{ id: " + id + ", role: reviewer, prompt: r.md }"
+	}
+	const bySchema = "jsonschema validation failed"
+	cases := map[string]struct{ nodes, want string }{
+		"no checks and no reviewers":    {"  - { id: build, kind: loop, repo: repos/app, role: implementer, prompt: p.md }\n", bySchema},
+		"no repo":                       {"  - { id: build, kind: loop, role: implementer, prompt: p.md, checks: [vet] }\n", bySchema},
+		"no role":                       {"  - { id: build, kind: loop, repo: repos/app, prompt: p.md, checks: [vet] }\n", bySchema},
+		"zero attempts":                 {strings.Replace(loop, "checks:", "attempts: 0, checks:", 1), bySchema},
+		"eleven attempts":               {strings.Replace(loop, "checks:", "attempts: 11, checks:", 1), bySchema},
+		"read_only on a loop":           {strings.Replace(loop, "checks:", "read_only: true, checks:", 1), bySchema},
+		"a check twice":                 {strings.Replace(loop, "[vet]", "[vet, vet]", 1), bySchema},
+		"an empty checks list":          {strings.Replace(loop, "[vet]", "[]", 1), bySchema},
+		"a run on a loop":               {strings.Replace(loop, "checks:", "run: [echo], checks:", 1), bySchema},
+		"a loop prompt that climbs":     {strings.Replace(loop, "p.md", "../p.md", 1), "inside the realm"},
+		"a reviewer without a role":     {strings.Replace(loop, "checks: [vet]", "reviewers: [{ id: spec, prompt: r.md }]", 1), bySchema},
+		"a reviewer that climbs":        {strings.Replace(loop, "checks: [vet]", "reviewers: [{ id: spec, role: reviewer, prompt: ../r.md }]", 1), "inside the realm"},
+		"a reviewer twice":              {strings.Replace(loop, "checks: [vet]", "reviewers: ["+rev("spec")+", "+rev("spec")+"]", 1), "used twice"},
+		"six reviewers":                 {strings.Replace(loop, "checks: [vet]", "reviewers: ["+strings.Join([]string{rev("a"), rev("b"), rev("c"), rev("d"), rev("e"), rev("f")}, ", ")+"]", 1), bySchema},
+		"a reviewer key that is a node": {strings.Replace(loop, "checks: [vet]", "reviewers: ["+rev("spec")+"]", 1) + "  - { id: build-spec, kind: exec, run: [echo] }\n", "also a node id"},
+		"two loops with one key":        {strings.Replace(loop, "checks: [vet]", "reviewers: ["+rev("b")+"]", 1) + "  - { id: build-b, kind: loop, repo: repos/app, role: implementer, prompt: p.md, reviewers: [" + rev("x") + "] }\n", "also a node id"},
+	}
+	cases["two loops whose reviewers share a session key"] = struct{ nodes, want string }{
+		"  - { id: a, kind: loop, repo: repos/app, role: implementer, prompt: p.md, reviewers: [{ id: b-c, role: reviewer, prompt: r.md }] }\n" +
+			"  - { id: a-b, kind: loop, repo: repos/app, role: implementer, prompt: p.md, reviewers: [{ id: c, role: reviewer, prompt: r.md }] }\n",
+		"is also loop a's"}
+	for name, c := range cases {
+		_, err := ParseGraph("graph.yaml", []byte(head+c.nodes))
+		if err == nil || !strings.Contains(err.Error(), c.want) {
+			t.Errorf("%s: ParseGraph() = %v, want an error containing %q", name, err, c.want)
+		}
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/graph_test.go:221:15: undefined: KindLoop
schema/graph_test.go:221:29: n.Attempts undefined (type Node has no field or method Attempts)
schema/graph_test.go:221:41: undefined: DefaultAttempts
```

- [ ] **Step 3:** write the code.

Apply to `schema/graph.go`:

```diff
diff --git a/schema/graph.go b/schema/graph.go
index e065794..8775fb6 100644
--- a/schema/graph.go
+++ b/schema/graph.go
@@ -26,28 +26,47 @@ const (
 	KindGate    NodeKind = "gate"    // an approval point
 	KindMerge   NodeKind = "merge"   // lands a leaf's run branch on its main, through the merge gate
 	KindPointer NodeKind = "pointer" // moves a leaf's pointer in its parent umbrella, one level
+	KindLoop    NodeKind = "loop"    // implement, check and fix with a bounded number of attempts (spec §4.2, §4.6, §7.3)
 )
 
+// DefaultAttempts is how many times a loop runs its implementer when the node sets no attempts (spec §4.2).
+const DefaultAttempts = 3
+
 // Node is one step of a graph. Which fields apply depends on Kind.
 type Node struct {
 	ID       string       `yaml:"id"`
 	Kind     NodeKind     `yaml:"kind"`
 	Run      []string     `yaml:"run"`       // exec: the command, without a shell
-	Role     string       `yaml:"role"`      // agent: the factory.yaml role
-	Prompt   string       `yaml:"prompt"`    // agent: the prompt file, relative to the graph
+	Role     string       `yaml:"role"`      // agent, loop: the factory.yaml role (a loop's implementer)
+	Prompt   string       `yaml:"prompt"`    // agent, loop: the prompt file, relative to the graph
 	ReadOnly bool         `yaml:"read_only"` // agent
-	MaxTurns int          `yaml:"max_turns"` // agent
-	Skills   []string     `yaml:"skills"`    // agent: the skills loaded into its prompt, by name (spec §5.1)
-	Timeout  Duration     `yaml:"timeout"`   // exec, agent, merge and pointer
+	MaxTurns int          `yaml:"max_turns"` // agent, loop (the implementer)
+	Skills   []string     `yaml:"skills"`    // agent, loop: the skills loaded into its prompt, by name (spec §5.1)
+	Timeout  Duration     `yaml:"timeout"`   // exec, agent, loop (each session), merge and pointer
 	Gate     gungnir.Gate `yaml:"gate"`      // gate: the approval point
 	Reruns   string       `yaml:"reruns"`    // gate: the agent node a rejection re-runs; set by ParseGraph
 
-	Repo       string   `yaml:"repo"`       // exec, agent, merge, pointer: a repo of the project, relative to it; "." is the project umbrella
-	Checks     []string `yaml:"checks"`     // merge, pointer: pack checks run in the leaf
-	Acceptance []string `yaml:"acceptance"` // pointer: pack checks run in the leaf's parent umbrella
-	Generated  []string `yaml:"generated"`  // pointer: generated files of the parent umbrella, committed with the move under the shrink guard
+	Repo       string     `yaml:"repo"`       // exec, agent, loop, merge, pointer: a repo of the project, relative to it; "." is the project umbrella
+	Checks     []string   `yaml:"checks"`     // loop, merge, pointer: pack checks run in the leaf (a loop's, in order, after each attempt)
+	Attempts   int        `yaml:"attempts"`   // loop: how many attempts before it escalates; DefaultAttempts when unset
+	Reviewers  []Reviewer `yaml:"reviewers"`  // loop: read-only agents that review each attempt once its checks pass, in order
+	Acceptance []string   `yaml:"acceptance"` // pointer: pack checks run in the leaf's parent umbrella
+	Generated  []string   `yaml:"generated"`  // pointer: generated files of the parent umbrella, committed with the move under the shrink guard
+}
+
+// Reviewer is a read-only agent that reviews a loop's work and reports typed findings (spec §4.6, §9.5).
+type Reviewer struct {
+	ID       string   `yaml:"id"`
+	Role     string   `yaml:"role"`
+	Prompt   string   `yaml:"prompt"`
+	Skills   []string `yaml:"skills"`
+	MaxTurns int      `yaml:"max_turns"`
+	Timeout  Duration `yaml:"timeout"`
 }
 
+// SessionKey names the sessions of reviewer r of loop n in the ledger, the transcripts and a script.
+func (n Node) SessionKey(r Reviewer) string { return n.ID + "-" + r.ID }
+
 // Duration is a time.Duration written as "30s", "10m" or "1h".
 type Duration time.Duration
 
@@ -81,23 +100,31 @@ func LoadGraph(path string) (*Graph, error) {
 
 // ParseGraph parses graph.yaml. Ids must be unique, prompt files must stay inside the realm, merge
 // and pointer nodes must name a child repo, and every gate gets the node its rejection re-runs: the
-// agent node it names, which must come before it, or else the nearest agent node before it. A
+// agent or loop node it names, which must come before it, or else the nearest one before it. A
 // rejection's reason is input for an agent, so it never re-runs an exec node, which would drop it.
+// A loop's attempts default to DefaultAttempts, its reviewers' ids are unique, and a reviewer's
+// session key (the loop's id, a dash and the reviewer's id) never equals a node's id.
 func ParseGraph(file string, data []byte) (*Graph, error) {
 	var g Graph
 	if err := parseYAML(file, "graph.schema.json", data, &g); err != nil {
 		return nil, err
 	}
 	seen := map[string]int{}
+	keys := map[string]string{} // reviewer session key: the loop that owns it
 	for i := range g.Nodes {
 		n := &g.Nodes[i]
 		if _, dup := seen[n.ID]; dup {
 			return nil, fmt.Errorf("%s: node id %q is used twice", file, n.ID)
 		}
 		seen[n.ID] = i
-		if n.Kind == KindAgent && !filepath.IsLocal(n.Prompt) {
+		if (n.Kind == KindAgent || n.Kind == KindLoop) && !filepath.IsLocal(n.Prompt) {
 			return nil, fmt.Errorf("%s: node %s: prompt %q must be a path inside the realm", file, n.ID, n.Prompt)
 		}
+		if n.Kind == KindLoop {
+			if err := checkLoop(file, n, keys); err != nil {
+				return nil, err
+			}
+		}
 		if (n.Kind == KindMerge || n.Kind == KindPointer) && n.Repo == "." {
 			return nil, fmt.Errorf("%s: node %s: repo must be a child of the project, not the project itself", file, n.ID)
 		}
@@ -111,19 +138,47 @@ func ParseGraph(file string, data []byte) (*Graph, error) {
 		}
 		if n.Reruns == "" {
 			for j := i - 1; j >= 0 && n.Reruns == ""; j-- {
-				if g.Nodes[j].Kind == KindAgent {
+				if k := g.Nodes[j].Kind; k == KindAgent || k == KindLoop {
 					n.Reruns = g.Nodes[j].ID
 				}
 			}
 			if n.Reruns == "" {
-				return nil, fmt.Errorf("%s: gate %s has no agent node before it to re-run when rejected", file, n.ID)
+				return nil, fmt.Errorf("%s: gate %s has no agent or loop node before it to re-run when rejected", file, n.ID)
 			}
 			continue
 		}
 		j, ok := seen[n.Reruns]
-		if !ok || j == i || g.Nodes[j].Kind != KindAgent {
-			return nil, fmt.Errorf("%s: gate %s re-runs %q, which must be an agent node before it", file, n.ID, n.Reruns)
+		if !ok || j == i || (g.Nodes[j].Kind != KindAgent && g.Nodes[j].Kind != KindLoop) {
+			return nil, fmt.Errorf("%s: gate %s re-runs %q, which must be an agent or loop node before it", file, n.ID, n.Reruns)
+		}
+	}
+	for key, loop := range keys {
+		if _, clash := seen[key]; clash {
+			return nil, fmt.Errorf("%s: loop %s: a reviewer's session key %q is also a node id", file, loop, key)
 		}
 	}
 	return &g, nil
 }
+
+// checkLoop checks a loop node's attempts and reviewers, and records its reviewers' session keys.
+func checkLoop(file string, n *Node, keys map[string]string) error {
+	if n.Attempts == 0 {
+		n.Attempts = DefaultAttempts
+	}
+	seen := map[string]bool{}
+	for _, r := range n.Reviewers {
+		if seen[r.ID] {
+			return fmt.Errorf("%s: loop %s: reviewer id %q is used twice", file, n.ID, r.ID)
+		}
+		seen[r.ID] = true
+		if !filepath.IsLocal(r.Prompt) {
+			return fmt.Errorf("%s: loop %s: reviewer %s: prompt %q must be a path inside the realm", file, n.ID, r.ID, r.Prompt)
+		}
+		key := n.SessionKey(r)
+		if other, dup := keys[key]; dup {
+			return fmt.Errorf("%s: loop %s: reviewer session key %q is also loop %s's", file, n.ID, key, other)
+		}
+		keys[key] = n.ID
+	}
+	return nil
+}
```

Apply to `schema/graph.schema.json`:

```diff
diff --git a/schema/graph.schema.json b/schema/graph.schema.json
index 8700bf5..2bda5e1 100644
--- a/schema/graph.schema.json
+++ b/schema/graph.schema.json
@@ -2,7 +2,7 @@
   "$schema": "https://json-schema.org/draft/2020-12/schema",
   "$id": "https://github.com/ouroboric-dev/gungnir/schema/graph.schema.json",
   "title": "graph.yaml",
-  "description": "A realm's graph: nodes run in order; a gate node is an approval point (spec §4.2, §7). Exec and agent nodes work in a repo of the project, merge nodes land a leaf's run branch through the merge gate (§4.5), pointer nodes move a leaf's pointer one level (§3.4). Loop nodes come in a later schema version.",
+  "description": "A realm's graph: nodes run in order; a gate node is an approval point (spec §4.2, §7). Exec and agent nodes work in a repo of the project, merge nodes land a leaf's run branch through the merge gate (§4.5), pointer nodes move a leaf's pointer one level (§3.4), loop nodes run an implementer against a check ladder and reviewers, with a bounded number of attempts (§4.2, §4.6, §7.3).",
   "type": "object",
   "additionalProperties": false,
   "required": ["name", "version", "nodes"],
@@ -17,10 +17,23 @@
     "duration": { "type": "string", "pattern": "^[1-9][0-9]*(ms|s|m|h)$" },
     "repo": { "type": "string", "pattern": "^(\\.|[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)*)$" },
     "names": { "type": "array", "items": { "$ref": "#/$defs/id" } },
+    "reviewer": {
+      "type": "object",
+      "additionalProperties": false,
+      "required": ["id", "role", "prompt"],
+      "properties": {
+        "id": { "$ref": "#/$defs/id" },
+        "role": { "$ref": "#/$defs/id" },
+        "prompt": { "type": "string", "minLength": 1 },
+        "skills": { "$ref": "#/$defs/names", "uniqueItems": true },
+        "max_turns": { "type": "integer", "minimum": 1 },
+        "timeout": { "$ref": "#/$defs/duration" }
+      }
+    },
     "node": {
       "type": "object",
       "required": ["id", "kind"],
-      "properties": { "kind": { "enum": ["exec", "agent", "gate", "merge", "pointer"] } },
+      "properties": { "kind": { "enum": ["exec", "agent", "gate", "merge", "pointer", "loop"] } },
       "oneOf": [
         {
           "additionalProperties": false,
@@ -86,6 +99,24 @@
             "generated": { "type": "array", "items": { "type": "string", "minLength": 1 } },
             "timeout": { "$ref": "#/$defs/duration" }
           }
+        },
+        {
+          "additionalProperties": false,
+          "required": ["repo", "role", "prompt"],
+          "anyOf": [ { "required": ["checks"] }, { "required": ["reviewers"] } ],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "loop" },
+            "repo": { "$ref": "#/$defs/repo" },
+            "role": { "$ref": "#/$defs/id" },
+            "prompt": { "type": "string", "minLength": 1 },
+            "skills": { "$ref": "#/$defs/names", "uniqueItems": true },
+            "max_turns": { "type": "integer", "minimum": 1 },
+            "timeout": { "$ref": "#/$defs/duration" },
+            "attempts": { "type": "integer", "minimum": 1, "maximum": 10 },
+            "checks": { "$ref": "#/$defs/names", "minItems": 1, "uniqueItems": true },
+            "reviewers": { "type": "array", "minItems": 1, "maxItems": 5, "items": { "$ref": "#/$defs/reviewer" } }
+          }
         }
       ]
     }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T104: a journal that can't be read is a reached cap

A per-day cap that can't be checked must stop the run (decision 5). The stop needs a dimension and a
note to say why.

**Files (in `gungnir`):**

- Modify: `budget.go`, `budget_test.go`

**Interfaces:**

- Produces: `gungnir.CapJournal` (a `CapDimension` that is not a limit); `CapError.Note string`, why the
  journal can't be read. `Error()` of a `CapJournal` error says the cap can't be checked and so counts as
  reached.

**Acceptance criteria:**

- [ ] The message names the scope, says the cap can't be checked and counts as reached, and carries the
      note.

**Named test:** `go test . -run TestAJournalThatCannotBeReadCountsAsAReachedCap` in `gungnir`.
**Layer:** `gungnir`. **Size:** S (17). **Depends on:** v0-T098.

- [ ] **Step 1:** write the tests.

Apply to `budget_test.go`:

```diff
diff --git a/budget_test.go b/budget_test.go
index f1404fe..196c4f6 100644
--- a/budget_test.go
+++ b/budget_test.go
@@ -22,3 +22,13 @@ func TestACapErrorSaysWhatWasReached(t *testing.T) {
 		t.Errorf("Error() = %q", got)
 	}
 }
+
+func TestAJournalThatCannotBeReadCountsAsAReachedCap(t *testing.T) {
+	e := &CapError{Scope: CapDay, Dimension: CapJournal, Note: "line 3 of 2026-10-16.jsonl is not JSON"}
+	got := e.Error()
+	for _, want := range []string{"per-day", "can't be checked", "counts as reached", "line 3"} {
+		if !strings.Contains(got, want) {
+			t.Errorf("Error() = %q, want it to contain %q", got, want)
+		}
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./budget_test.go:27:43: undefined: CapJournal
./budget_test.go:27:55: unknown field Note in struct literal of type CapError
FAIL	github.com/ouroboric-dev/gungnir [build failed]
```

- [ ] **Step 3:** write the code.

Apply to `budget.go`:

```diff
diff --git a/budget.go b/budget.go
index ff91003..f5a8b12 100644
--- a/budget.go
+++ b/budget.go
@@ -17,6 +17,9 @@ const (
 	CapTokens CapDimension = "tokens"
 	CapTurns  CapDimension = "turns"
 	CapUSD    CapDimension = "usd"
+	// CapJournal is not a limit: the record of the day's spend can't be read, so the per-day cap
+	// can't be checked, and a cap that can't be checked is treated as reached.
+	CapJournal CapDimension = "journal"
 )
 
 // CapError is a budget cap that has been reached: the run stops at the hard approval point
@@ -26,9 +29,13 @@ type CapError struct {
 	Dimension CapDimension
 	Used      float64
 	Limit     float64
+	Note      string // CapJournal: why the record can't be read
 }
 
 func (e *CapError) Error() string {
+	if e.Dimension == CapJournal {
+		return fmt.Sprintf("the per-%s cap can't be checked, so it counts as reached: %s", e.Scope, e.Note)
+	}
 	if e.Dimension == CapUSD {
 		return fmt.Sprintf("the per-%s cap is reached: $%.4f spent of $%.4f", e.Scope, e.Used, e.Limit)
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T105: a finding's texts are bounded

A finding goes back into a prompt on every attempt, so a reviewer can't write one as long as a book.

**Files (in `gungnir`):**

- Modify: `finding.go`, `gungnir_test.go`, `schema/event_test.go`, `schema/finding.schema.json`

**Interfaces:**

- Produces: `gungnir.MaxID` and `MaxSource` (100), `MaxLocation` (300), `MaxClaim` (4,000), `MaxProof`
  (2,000), in characters; `Finding.Validate` and `finding.schema.json` refuse a longer text.

**Acceptance criteria:**

- [ ] A finding with every text at its limit validates (multi-byte characters count once).
- [ ] A longer id, source, location, claim or proof is refused, and so is a report that holds one.

**Named test:** `go test ./... -run 'TestAFindingsTextsAreBounded|TestParseReportRefusesAFindingTooLongToGoBackIntoAPrompt'`
in `gungnir`. **Layer:** `gungnir`. **Size:** S (56). **Depends on:** v0-T102.

- [ ] **Step 1:** write the tests.

Apply to `gungnir_test.go`:

```diff
diff --git a/gungnir_test.go b/gungnir_test.go
index 063de1f..bf8d25e 100644
--- a/gungnir_test.go
+++ b/gungnir_test.go
@@ -150,3 +150,23 @@ func TestEscalationIsASoftApprovalPoint(t *testing.T) {
 		t.Errorf("escalation: known %v, hard %v; want a known, soft approval point", GateEscalation.Known(), GateEscalation.Hard())
 	}
 }
+
+func TestAFindingsTextsAreBounded(t *testing.T) {
+	good := Finding{ID: "F1", Source: "spec", Severity: SeverityMajor, Location: "api/auth.go:42", Claim: strings.Repeat("é", MaxClaim), Status: FindingFixed, Proof: strings.Repeat("p", MaxProof)}
+	if err := good.Validate(); err != nil {
+		t.Fatalf("a finding at every limit: %v", err)
+	}
+	for name, change := range map[string]func(*Finding){
+		"an id too long":      func(f *Finding) { f.ID = strings.Repeat("i", MaxID+1) },
+		"a source too long":   func(f *Finding) { f.Source = strings.Repeat("s", MaxSource+1) },
+		"a location too long": func(f *Finding) { f.Location = strings.Repeat("l", MaxLocation) + ":1" },
+		"a claim too long":    func(f *Finding) { f.Claim = strings.Repeat("c", MaxClaim+1) },
+		"a proof too long":    func(f *Finding) { f.Proof = strings.Repeat("p", MaxProof+1) },
+	} {
+		f := good
+		change(&f)
+		if err := f.Validate(); err == nil {
+			t.Errorf("%s: Validate() = nil, want an error", name)
+		}
+	}
+}
```

Apply to `schema/event_test.go`:

```diff
diff --git a/schema/event_test.go b/schema/event_test.go
index 32e5652..8e41137 100644
--- a/schema/event_test.go
+++ b/schema/event_test.go
@@ -164,3 +164,14 @@ func TestParseReport(t *testing.T) {
 		}
 	}
 }
+
+func TestParseReportRefusesAFindingTooLongToGoBackIntoAPrompt(t *testing.T) {
+	long := `{"findings":[{"id":"a","source":"s","severity":"major","location":"a.go:1","claim":"` + strings.Repeat("c", gungnir.MaxClaim+1) + `","status":"open"}]}`
+	if _, err := ParseReport([]byte(long)); err == nil {
+		t.Error("ParseReport() accepted a claim over the limit")
+	}
+	ok := `{"findings":[{"id":"a","source":"s","severity":"major","location":"a.go:1","claim":"` + strings.Repeat("c", gungnir.MaxClaim) + `","status":"open"}]}`
+	if _, err := ParseReport([]byte(ok)); err != nil {
+		t.Errorf("ParseReport() = %v for a claim at the limit", err)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./gungnir_test.go:155:125: undefined: MaxClaim
./gungnir_test.go:155:185: undefined: MaxProof
./gungnir_test.go:160:72: undefined: MaxID
```

- [ ] **Step 3:** write the code.

Apply to `finding.go`:

```diff
diff --git a/finding.go b/finding.go
index 4d5890c..c44b8e6 100644
--- a/finding.go
+++ b/finding.go
@@ -4,6 +4,17 @@ import (
 	"errors"
 	"fmt"
 	"regexp"
+	"unicode/utf8"
+)
+
+// The most characters each text field of a finding may hold. A finding goes back into a prompt on every
+// attempt, so a reviewer's finding can't be as long as a book.
+const (
+	MaxID       = 100
+	MaxSource   = 100
+	MaxLocation = 300
+	MaxClaim    = 4000
+	MaxProof    = 2000
 )
 
 // Severity is how bad a finding is.
@@ -44,6 +55,15 @@ func (f Finding) Validate() error {
 	if f.ID == "" || f.Source == "" || f.Claim == "" {
 		errs = append(errs, errors.New("a finding needs an id, a source and a claim"))
 	}
+	for _, c := range []struct {
+		name string
+		text string
+		max  int
+	}{{"id", f.ID, MaxID}, {"source", f.Source, MaxSource}, {"location", f.Location, MaxLocation}, {"claim", f.Claim, MaxClaim}, {"proof", f.Proof, MaxProof}} {
+		if n := utf8.RuneCountInString(c.text); n > c.max {
+			errs = append(errs, fmt.Errorf("the %s is %d characters long, over the limit of %d", c.name, n, c.max))
+		}
+	}
 	switch f.Severity {
 	case SeverityBlocker, SeverityMajor, SeverityMinor:
 	default:
```

Apply to `schema/finding.schema.json`:

```diff
diff --git a/schema/finding.schema.json b/schema/finding.schema.json
index a6a3bdc..e94ad8f 100644
--- a/schema/finding.schema.json
+++ b/schema/finding.schema.json
@@ -7,13 +7,13 @@
   "additionalProperties": false,
   "required": ["id", "source", "severity", "location", "claim", "status"],
   "properties": {
-    "id": { "type": "string", "minLength": 1 },
-    "source": { "type": "string", "minLength": 1 },
+    "id": { "type": "string", "minLength": 1, "maxLength": 100 },
+    "source": { "type": "string", "minLength": 1, "maxLength": 100 },
     "severity": { "enum": ["blocker", "major", "minor"] },
-    "location": { "type": "string", "pattern": "^[^\\s:]+:[0-9]+(-[0-9]+)?$" },
-    "claim": { "type": "string", "minLength": 1 },
+    "location": { "type": "string", "maxLength": 300, "pattern": "^[^\\s:]+:[0-9]+(-[0-9]+)?$" },
+    "claim": { "type": "string", "minLength": 1, "maxLength": 4000 },
     "status": { "enum": ["open", "fixed", "disputed"] },
-    "proof": { "type": "string", "minLength": 1 }
+    "proof": { "type": "string", "minLength": 1, "maxLength": 2000 }
   },
   "if": { "properties": { "status": { "const": "fixed" } } },
   "then": { "required": ["proof"] }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

When `gungnir`'s last task is committed, push and open its pull request (see "How each task lands"), and
the founder merges it. Then switch the local copy to `main`, pull, and go on with `gleipnir` and
`jormungandr`, which pin it.

---

### Task v0-T106: deciding how a failed session failed

Spec §12 treats a 429 or a crash at start, a used-up quota and an agent that failed differently, and
all three adapters need the same answer. The table lives in one small package, so that a message
Gleipnir learns later is one line in one file. Gleipnir's first task. Branch `harness/failures` from
`main` in `gleipnir`, before step 1, once `gungnir`'s pull request (v0-T097 to v0-T105) is merged and
pinned (see "How each task lands").

**Files (in `gleipnir`):**

- Create: `failure/failure.go`, `failure/failure_test.go`

**Interfaces:**

- Consumes: `gungnir.FailureKind` (v0-T097).
- Produces: `failure.Classify(status int, message string) gungnir.FailureKind`. A message about a quota,
  a credit balance, a plan's usage limit or a key's limit is `FailureQuota`, whatever the status (a
  used-up quota often comes as a 429); otherwise a status of 408, 429 or any 5xx is `FailureTransient`; with
  no status, a message with the words of a rate limit, an overloaded API, a refused or reset connection
  or an unavailable service is transient too; everything else, a 401 or a 400 included, is
  `FailureAgent`. A message that merely talks about a network or a timeout (an agent's prose) is not
  transient.

**Acceptance criteria:**

- [ ] The cases of the table: a rate limit, an overloaded API, a server error, a request timeout, a
      network error with no status, a plan's usage limit with and without a 429, credits used up, a key
      over its limit, a quota, and a bad request, an unauthorised key, a missing model, an empty
      message and an agent's prose that mentions the network.

**Named test:** `go test ./failure` in `gleipnir`. **Layer:** `gleipnir`. **Size:** S (78).
**Depends on:** v0-T097 merged.

- [ ] **Step 1:** write the tests.

Write `failure/failure_test.go`:

```go
package failure

import (
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func TestClassify(t *testing.T) {
	const (
		agent     = gungnir.FailureAgent
		transient = gungnir.FailureTransient
		quota     = gungnir.FailureQuota
	)
	cases := []struct {
		name    string
		status  int
		message string
		want    gungnir.FailureKind
	}{
		{"a rate limit", 429, "Rate limit exceeded, retry in 20s", transient},
		{"overloaded", 529, "Overloaded", transient},
		{"a server error", 502, "Bad Gateway", transient},
		{"a request timeout", 408, "Request Timeout", transient},
		{"a network error with no status", 0, "fetch failed: ECONNRESET", transient},
		{"a rate limit with no status", 0, "too many requests", transient},
		{"credits used up", 402, "Insufficient credits", quota},
		{"credits used up, reported as a 429", 429, "You have insufficient credits for this request", quota},
		{"a plan's usage limit", 0, "Claude usage limit reached. Your limit will reset at 3pm", quota},
		{"a plan's usage limit, reported as a 429", 429, "5-hour limit reached, resets 3pm", quota},
		{"a quota", 429, "You exceeded your current quota", quota},
		{"a bad request", 400, "invalid request", agent},
		{"an unauthorised key", 401, "invalid api key", agent},
		{"a not found model", 404, "model not found", agent},
		{"no status and no known words", 0, "the agent gave up", agent},
		{"nothing at all", 0, "", agent},
		{"an agent that talks about a network", 0, "I could not finish: the tests need network access and a timeout", agent},
	}
	for _, c := range cases {
		if got := Classify(c.status, c.message); got != c.want {
			t.Errorf("%s: Classify(%d, %q) = %q, want %q", c.name, c.status, c.message, got, c.want)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gleipnir/failure [github.com/ouroboric-dev/gleipnir/failure.test]
failure/failure_test.go:40:13: undefined: Classify
FAIL	github.com/ouroboric-dev/gleipnir/failure [build failed]
FAIL
```

- [ ] **Step 3:** write the code.

Write `failure/failure.go`:

```go
// Package failure decides how a failed model session failed (spec §12), from what the provider or
// the tool reported. The answer decides what happens next: a transient failure is retried with a
// backoff, a used-up quota pauses the run, anything else is an agent failure that counts as a loop
// attempt. What this package can't tell is an agent failure: the loop is bounded, so the safe reading
// of an unknown failure is the one that counts against the attempts.
package failure

import (
	"regexp"

	"github.com/ouroboric-dev/gungnir"
)

// quota matches the words providers use when a quota, a credit balance or a plan's usage limit is
// used up. A plain rate limit is not here: it clears in seconds, and is transient.
var quota = regexp.MustCompile(`(?i)usage limit|limit reached|reached (?:your|the) (?:\w+ )?limit|hit your limit|quota|insufficient (?:credits|funds)|out of credits|credit balance|billing|payment required`)

// transient matches the words of a network or capacity failure that reports no status.
var transient = regexp.MustCompile(`(?i)overloaded|rate.?limit|too many requests|temporarily unavailable|ECONNRESET|ECONNREFUSED|ETIMEDOUT|EAI_AGAIN|socket hang up|fetch failed|connection (?:reset|refused|closed)|service unavailable|bad gateway|gateway time-?out`)

// Classify returns how a session failed, given the HTTP status the provider returned (0 when none was
// reported) and the message the tool printed. Quota wins over every status, since providers report a
// used-up quota with a 429.
func Classify(status int, message string) gungnir.FailureKind {
	switch {
	case status == 402 || quota.MatchString(message):
		return gungnir.FailureQuota
	case status == 408 || status == 429 || status >= 500:
		return gungnir.FailureTransient
	case status == 0 && transient.MatchString(message):
		return gungnir.FailureTransient
	}
	return gungnir.FailureAgent
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T107: `claude-code`: how a session fails, and its final answer

Spec §12 and §4.6. A failed `result` event says its API status and its message; a session that printed
nothing is a CLI that crashed at start; and the reviewer's findings arrive in the final answer, whole.

**Files (in `gleipnir`):**

- Modify: `claudecode/claudecode.go`, `claudecode/claudecode_test.go`

**Interfaces:**

- Consumes: `failure.Classify` (v0-T106), `gungnir.SessionError`, `Result.Failure`, `Result.Output`
  (v0-T097).
- Produces: a successful or failed `Result` whose `Output` is the final answer, trimmed, whole (an answer
  over `gungnir.MaxOutput` is an agent failure); `Summary` stays clipped to 1,000 characters. A failed
  result's `Failure` is `Classify(api_error_status, result)` when the event says an API error
  (`subtype: success`, `is_error: true`); a turn limit and an error inside the session are agent
  failures whatever their text says.
- Produces: `*gungnir.SessionError` for a session with no usable result: infra when the sandbox's runner
  failed and the context is alive; agent when the context ended (the session's timeout) or the session
  got going and died or printed numbers we can't read; transient when the tool printed no event and
  exited non-zero (a crash at start); quota when stderr says the quota is used up.

**Acceptance criteria:**

- [ ] The whole final answer is in `Output` and only the summary is clipped; an answer over the limit is
      an agent failure.
- [ ] A 429, an overloaded API and a 500 are transient; a usage limit, with or without a 429, is quota; a
      rejected token, a turn limit, a crash inside the session and a turn limit whose text mentions a
      usage limit are agent failures.
- [ ] Six endings without a result each get their kind: a crash at start (127), garbage and exit 139, a
      quota on stderr, a session that died after it began, a clean exit with no events, a result that
      lacks a number.
- [ ] A command the sandbox could not run is infra; the same error with a context that ended is agent.

**Named test:** `go test ./claudecode` in `gleipnir`. **Layer:** `gleipnir`. **Size:** M (145).
**Depends on:** v0-T106.

- [ ] **Step 1:** write the tests.

Apply to `claudecode/claudecode_test.go`:

```diff
diff --git a/claudecode/claudecode_test.go b/claudecode/claudecode_test.go
index 994ae5a..ecb29c6 100644
--- a/claudecode/claudecode_test.go
+++ b/claudecode/claudecode_test.go
@@ -3,6 +3,7 @@ package claudecode
 import (
 	"context"
 	"errors"
+	"fmt"
 	"os"
 	"path/filepath"
 	"strings"
@@ -20,6 +21,7 @@ const okResult = `{"type":"result","subtype":"success","is_error":false,"duratio
 
 type fake struct {
 	stdout string
+	stderr string
 	exit   int
 	err    error
 	got    gungnir.Cmd
@@ -41,6 +43,9 @@ func (f *fake) Run(_ context.Context, c gungnir.Cmd) (gungnir.ExecResult, error)
 		f.stdin = b.String()
 	}
 	c.Stdout.Write([]byte(f.stdout))
+	if c.Stderr != nil {
+		c.Stderr.Write([]byte(f.stderr))
+	}
 	return gungnir.ExecResult{ExitCode: f.exit}, f.err
 }
 
@@ -159,3 +164,101 @@ func TestTheAdapterNeverRunsOnTheHostOrWithAPerTokenKey(t *testing.T) {
 		t.Errorf("no token: %v", err)
 	}
 }
+
+func resultLine(subtype string, isError bool, status, text string) string {
+	st := "null"
+	if status != "" {
+		st = status
+	}
+	return fmt.Sprintf(`{"type":"result","subtype":%q,"is_error":%v,"api_error_status":%s,"result":%q,"num_turns":1,"total_cost_usd":0,"usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}`,
+		subtype, isError, st, text) + "\n"
+}
+
+func TestARunKeepsTheWholeFinalAnswerAndClipsOnlyTheSummary(t *testing.T) {
+	answer := `{"findings":[` + strings.Repeat(`{"id":"a"},`, 300) + `]}`
+	f := &fake{stdout: initLine + "\n" + resultLine("success", false, "", "  "+answer+"\n")}
+	tk := task(f)
+	tk.TranscriptDir = t.TempDir()
+	r, err := agent().Run(context.Background(), tk)
+	if err != nil || r.Output != answer || len(r.Summary) >= len(answer) || !strings.HasSuffix(r.Summary, "…") {
+		t.Errorf("Run() = %d-byte output, %d-byte summary, %v; want the whole answer and a clipped summary", len(r.Output), len(r.Summary), err)
+	}
+}
+
+func TestAnAnswerOverTheLimitIsAnAgentFailure(t *testing.T) {
+	f := &fake{stdout: initLine + "\n" + resultLine("success", false, "", strings.Repeat("x", gungnir.MaxOutput+1))}
+	tk := task(f)
+	tk.TranscriptDir = t.TempDir()
+	_, err := agent().Run(context.Background(), tk)
+	if err == nil || gungnir.FailureOf(err) != gungnir.FailureAgent {
+		t.Errorf("Run() = %v, want an agent failure", err)
+	}
+}
+
+func TestAFailedSessionSaysHowItFailed(t *testing.T) {
+	cases := map[string]struct {
+		line string
+		want gungnir.FailureKind
+	}{
+		"a rate limit":              {resultLine("success", true, "429", "API Error: Rate limit exceeded"), gungnir.FailureTransient},
+		"an overloaded API":         {resultLine("success", true, "529", "Overloaded"), gungnir.FailureTransient},
+		"a server error":            {resultLine("success", true, "500", "Internal server error"), gungnir.FailureTransient},
+		"a plan's usage limit":      {resultLine("success", true, "429", "Claude usage limit reached. Your limit will reset at 3pm."), gungnir.FailureQuota},
+		"a limit with no status":    {resultLine("success", true, "", "5-hour limit reached ∙ resets 3pm"), gungnir.FailureQuota},
+		"a rejected token":          {resultLine("success", true, "401", "Invalid bearer token"), gungnir.FailureAgent},
+		"the turn limit":            {resultLine("error_max_turns", false, "", ""), gungnir.FailureAgent},
+		"a crash inside the run":    {resultLine("error_during_execution", true, "", "tool failed"), gungnir.FailureAgent},
+		"the turn limit that talks": {resultLine("error_max_turns", true, "429", "usage limit reached in the test I ran"), gungnir.FailureAgent},
+	}
+	for name, c := range cases {
+		f := &fake{stdout: initLine + "\n" + c.line, exit: 1}
+		tk := task(f)
+		tk.TranscriptDir = t.TempDir()
+		r, err := agent().Run(context.Background(), tk)
+		if err != nil || r.Status != gungnir.StatusFailed || r.Failure != c.want {
+			t.Errorf("%s: %+v, %v; want a failed result of kind %q", name, r, err, c.want)
+		}
+	}
+}
+
+func TestASessionThatEndedWithoutAResultSaysHowItFailed(t *testing.T) {
+	cases := map[string]struct {
+		stdout, stderr string
+		exit           int
+		want           gungnir.FailureKind
+	}{
+		"a tool that crashed at start":    {"", "node: command not found", 127, gungnir.FailureTransient},
+		"garbage and a non-zero exit":     {"Segmentation fault\n", "", 139, gungnir.FailureTransient},
+		"a quota said on stderr":          {"", "Claude usage limit reached", 1, gungnir.FailureQuota},
+		"a session that died after start": {initLine + "\n" + assistantLine + "\n", "", 137, gungnir.FailureAgent},
+		"a clean exit with no events":     {"", "", 0, gungnir.FailureAgent},
+		"a result with a number missing":  {initLine + "\n" + `{"type":"result","subtype":"success","is_error":false,"num_turns":1,"total_cost_usd":0.1}` + "\n", "", 0, gungnir.FailureAgent},
+	}
+	for name, c := range cases {
+		f := &fake{stdout: c.stdout, exit: c.exit}
+		f.stderr = c.stderr
+		tk := task(f)
+		tk.TranscriptDir = t.TempDir()
+		_, err := agent().Run(context.Background(), tk)
+		if err == nil || gungnir.FailureOf(err) != c.want {
+			t.Errorf("%s: Run() = %v (kind %q), want an error of kind %q", name, err, gungnir.FailureOf(err), c.want)
+		}
+	}
+}
+
+func TestACommandThatCouldNotRunIsTheSandboxsFailure(t *testing.T) {
+	f := &fake{err: errors.New("podman exec: no such container")}
+	tk := task(f)
+	tk.TranscriptDir = t.TempDir()
+	if _, err := agent().Run(context.Background(), tk); gungnir.FailureOf(err) != gungnir.FailureInfra {
+		t.Errorf("Run() = %v (kind %q), want an infra failure", err, gungnir.FailureOf(err))
+	}
+	ctx, cancel := context.WithCancel(context.Background())
+	cancel()
+	f = &fake{err: ctx.Err()}
+	tk = task(f)
+	tk.TranscriptDir = t.TempDir()
+	if _, err := agent().Run(ctx, tk); gungnir.FailureOf(err) != gungnir.FailureAgent {
+		t.Errorf("a session the context ended: Run() = %v (kind %q), want an agent failure", err, gungnir.FailureOf(err))
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestARunKeepsTheWholeFinalAnswerAndClipsOnlyTheSummary (0.00s)
    claudecode_test.go:184: Run() = 0-byte output, 1003-byte summary, <nil>; want the whole answer and a clipped summary
--- FAIL: TestAnAnswerOverTheLimitIsAnAgentFailure (0.01s)
    claudecode_test.go:194: Run() = <nil>, want an agent failure
```

- [ ] **Step 3:** write the code.

Apply to `claudecode/claudecode.go`:

```diff
diff --git a/claudecode/claudecode.go b/claudecode/claudecode.go
index a5206cf..f307284 100644
--- a/claudecode/claudecode.go
+++ b/claudecode/claudecode.go
@@ -19,6 +19,7 @@ import (
 	"strings"
 	"unicode/utf8"
 
+	"github.com/ouroboric-dev/gleipnir/failure"
 	"github.com/ouroboric-dev/gungnir"
 )
 
@@ -101,17 +102,37 @@ func (a *Agent) Run(ctx context.Context, t gungnir.Task) (gungnir.Result, error)
 	res, err := t.Sandbox.Run(ctx, gungnir.Cmd{Argv: Args(t), Env: env, Stdin: strings.NewReader(t.Prompt),
 		Stdout: io.MultiWriter(&out, transcript), Stderr: &errOut})
 	if err != nil {
-		return gungnir.Result{}, fmt.Errorf("claude-code: %w", err)
+		// A session the timeout or the operator ended is the agent's; any other failure to run the
+		// command is the sandbox's (spec §12).
+		kind := gungnir.FailureInfra
+		if ctx.Err() != nil {
+			kind = gungnir.FailureAgent
+		}
+		return gungnir.Result{}, &gungnir.SessionError{Kind: kind, Err: fmt.Errorf("claude-code: %w", err)}
 	}
-	r, err := parse(&out)
+	r, seen, err := parse(&out)
 	if err != nil {
-		return gungnir.Result{}, fmt.Errorf("claude-code: %w (exit %d; stderr: %s)", err, res.ExitCode, tail(errOut.String()))
+		return gungnir.Result{}, &gungnir.SessionError{Kind: unfinished(seen, res.ExitCode, errOut.String()),
+			Err: fmt.Errorf("claude-code: %w (exit %d; stderr: %s)", err, res.ExitCode, tail(errOut.String()))}
 	}
 	r.TranscriptPath = transcriptPath(t)
 	r.Provider = "anthropic"
 	return r, nil
 }
 
+// unfinished says how a session failed that ended without a usable result. A tool that crashed before
+// it printed a single event is the transient failure of spec §12, unless its stderr says the quota is
+// used up; one that got going and then died, or printed numbers we can't read, failed as an agent does.
+func unfinished(seen bool, exit int, stderr string) gungnir.FailureKind {
+	if k := failure.Classify(0, stderr); k == gungnir.FailureQuota {
+		return k
+	}
+	if !seen && exit != 0 {
+		return gungnir.FailureTransient
+	}
+	return gungnir.FailureAgent
+}
+
 func transcriptPath(t gungnir.Task) string {
 	if t.TranscriptDir == "" {
 		return ""
@@ -160,9 +181,10 @@ type event struct {
 	} `json:"usage"`
 }
 
-// parse reads a session's stream and returns what its result event says. Anything the result event
-// should hold and doesn't is an error: missing usage is never read as zero (spec §4.6).
-func parse(r io.Reader) (gungnir.Result, error) {
+// parse reads a session's stream and returns what its result event says; seen reports whether the
+// stream held any event at all. Anything the result event should hold and doesn't is an error:
+// missing usage is never read as zero (spec §4.6).
+func parse(r io.Reader) (res gungnir.Result, seen bool, err error) {
 	sc := bufio.NewScanner(r)
 	sc.Buffer(make([]byte, 1<<20), 64<<20)
 	var version string
@@ -176,6 +198,7 @@ func parse(r io.Reader) (gungnir.Result, error) {
 		if json.Unmarshal(line, &e) != nil {
 			continue
 		}
+		seen = true
 		switch e.Type {
 		case "system":
 			if e.Subtype == "init" && e.Version != "" {
@@ -187,18 +210,19 @@ func parse(r io.Reader) (gungnir.Result, error) {
 		}
 	}
 	if err := sc.Err(); err != nil {
-		return gungnir.Result{}, err
+		return gungnir.Result{}, seen, err
 	}
 	if final == nil {
-		return gungnir.Result{}, errors.New("the session ended without a result event")
+		return gungnir.Result{}, seen, errors.New("the session ended without a result event")
 	}
 	u := final.Usage
 	if u == nil || u.Input == nil || u.Output == nil || u.CacheRead == nil || u.CacheCreation == nil || final.NumTurns == nil || final.TotalCost == nil || final.IsError == nil {
-		return gungnir.Result{}, errors.New("the result event lacks usage, turns, cost or is_error; refusing to read missing numbers as zero")
+		return gungnir.Result{}, seen, errors.New("the result event lacks usage, turns, cost or is_error; refusing to read missing numbers as zero")
 	}
 	r2 := gungnir.Result{
 		Status:     gungnir.StatusOK,
 		Summary:    clip(final.Result),
+		Output:     strings.TrimSpace(final.Result),
 		CLIVersion: version,
 		Usage: gungnir.Usage{
 			InTok: *u.Input + *u.CacheCreation, OutTok: *u.Output, CacheTok: *u.CacheRead,
@@ -206,15 +230,22 @@ func parse(r io.Reader) (gungnir.Result, error) {
 		},
 	}
 	if *final.IsError || final.Subtype != "success" {
-		r2.Status = gungnir.StatusFailed
+		r2.Status, r2.Failure = gungnir.StatusFailed, gungnir.FailureAgent
 		if r2.Summary == "" {
 			r2.Summary = final.Subtype
 		}
+		status := 0
 		if s := strings.Trim(string(final.APIErrStatus), "\" "); s != "" && s != "null" {
 			r2.Summary += " (API status " + s + ")"
+			status, _ = strconv.Atoi(s)
+		}
+		// A turn limit or a crash inside the session is the agent's; only what the API said can be
+		// transient or a used-up quota.
+		if final.Subtype == "success" {
+			r2.Failure = failure.Classify(status, final.Result)
 		}
 	}
-	return r2, r2.Validate()
+	return r2, seen, r2.Validate()
 }
 
 func clip(s string) string {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T108: `claude-code`: what a session that did not finish used, and a bound on its output

Backlog B-020 and B-021. A session killed by its timeout spent tokens, and the caps must count them; a
chatty session must not fill the host's memory.

**Files (in `gleipnir`):**

- Create: `bounded/bounded.go`, `bounded/bounded_test.go`
- Modify: `claudecode/claudecode.go`, `claudecode/claudecode_test.go`

**Interfaces:**

- Produces: package `bounded`: `NewBuffer(limit int) *Buffer` keeps the first `limit` bytes and reports
  `Truncated()`; `NewWriter(w io.Writer, limit int64) *Writer` passes on the first `limit` bytes,
  keeps the first error of `w` (`Err()`) and reports `Truncated()`. Neither ever fails a write or
  blocks: the tool writing to them goes on to its end.
- Produces: in `claudecode`, `partialUsage(stream []byte) gungnir.Usage`, which adds up the assistant
  messages of a stream that has no result: each message once, at its largest figures (the stream
  repeats a message for every content block); a message with no id counts on its own, which can only
  overcount; cost is zero and marked estimated, since it is not known. Every `*SessionError` of the
  adapter carries it as `Usage`. Output over 32 MiB (`maxStream`, a variable so a test can lower it) is
  an agent failure, and the transcript stops at the same bound.

**Acceptance criteria:**

- [ ] A session ended by its deadline reports the tokens and turns of its messages, a repeated message
      counted once.
- [ ] A session with no result reports what it printed; one that printed nothing reports nothing.
- [ ] A session over the bound is an agent failure and its transcript is at most the bound.
- [ ] `bounded`'s buffer and writer keep the first bytes, drop the rest without an error, and a failing
      destination does not stop the session.

**Named test:** `go test ./bounded ./claudecode` in `gleipnir`. **Layer:** `gleipnir`.
**Size:** M (259). **Depends on:** v0-T107.

- [ ] **Step 1:** write the tests.

Write `bounded/bounded_test.go`:

```go
package bounded

import (
	"bytes"
	"errors"
	"testing"
)

func TestABufferKeepsTheFirstBytesAndSaysItDroppedTheRest(t *testing.T) {
	b := NewBuffer(5)
	for _, s := range []string{"ab", "cdefg", "hi"} {
		if n, err := b.Write([]byte(s)); n != len(s) || err != nil {
			t.Fatalf("Write(%q) = %d, %v; a bounded writer never fails and never reports a short write", s, n, err)
		}
	}
	if string(b.Bytes()) != "abcde" || !b.Truncated() {
		t.Errorf("kept %q, truncated %v; want abcde, true", b.Bytes(), b.Truncated())
	}
	exact := NewBuffer(3)
	exact.Write([]byte("abc"))
	if string(exact.Bytes()) != "abc" || exact.Truncated() {
		t.Errorf("a write that exactly fits: kept %q, truncated %v", exact.Bytes(), exact.Truncated())
	}
}

func TestAWriterPassesOnTheFirstBytesOnly(t *testing.T) {
	var out bytes.Buffer
	w := NewWriter(&out, 4)
	w.Write([]byte("ab"))
	w.Write([]byte("cdef"))
	w.Write([]byte("g"))
	if out.String() != "abcd" || !w.Truncated() || w.Err() != nil {
		t.Errorf("passed on %q, truncated %v, err %v", out.String(), w.Truncated(), w.Err())
	}
}

type failing struct{ calls int }

func (f *failing) Write([]byte) (int, error) { f.calls++; return 0, errors.New("disk full") }

func TestAWriterKeepsTheErrorOfItsDestinationAndGoesOn(t *testing.T) {
	f := &failing{}
	w := NewWriter(f, 100)
	if n, err := w.Write([]byte("abc")); n != 3 || err != nil {
		t.Errorf("Write() = %d, %v; the session must not stop for a full disk", n, err)
	}
	w.Write([]byte("def"))
	if w.Err() == nil || f.calls != 1 {
		t.Errorf("err %v after %d calls; want the first error kept and no more writes", w.Err(), f.calls)
	}
}
```

Apply to `claudecode/claudecode_test.go`:

```diff
diff --git a/claudecode/claudecode_test.go b/claudecode/claudecode_test.go
index ecb29c6..877a56b 100644
--- a/claudecode/claudecode_test.go
+++ b/claudecode/claudecode_test.go
@@ -8,6 +8,7 @@ import (
 	"path/filepath"
 	"strings"
 	"testing"
+	"time"
 
 	"github.com/ouroboric-dev/gungnir"
 )
@@ -262,3 +263,70 @@ func TestACommandThatCouldNotRunIsTheSandboxsFailure(t *testing.T) {
 		t.Errorf("a session the context ended: Run() = %v (kind %q), want an agent failure", err, gungnir.FailureOf(err))
 	}
 }
+
+func assistant(id string, in, out, cacheNew, cacheRead int) string {
+	idField := ""
+	if id != "" {
+		idField = fmt.Sprintf(`"id":%q,`, id)
+	}
+	return fmt.Sprintf(`{"type":"assistant","message":{%s"role":"assistant","content":[{"type":"text","text":"x"}],"usage":{"input_tokens":%d,"output_tokens":%d,"cache_creation_input_tokens":%d,"cache_read_input_tokens":%d}}}`,
+		idField, in, out, cacheNew, cacheRead) + "\n"
+}
+
+// Backlog B-020: a session the timeout killed still spent what its messages reported, and the caps
+// must count it.
+func TestATimedOutSessionStillCountsItsUsage(t *testing.T) {
+	stream := initLine + "\n" +
+		assistant("m1", 3, 10, 100, 1000) + assistant("m1", 3, 40, 100, 1000) + // one message, repeated per content block
+		assistant("m2", 5, 20, 0, 2000) + assistant("", 1, 1, 0, 0)
+	ctx, cancel := context.WithTimeout(context.Background(), time.Nanosecond)
+	defer cancel()
+	<-ctx.Done()
+	f := &fake{stdout: stream, err: ctx.Err()}
+	tk := task(f)
+	tk.TranscriptDir = t.TempDir()
+	_, err := agent().Run(ctx, tk)
+	var se *gungnir.SessionError
+	if !errors.As(err, &se) || se.Kind != gungnir.FailureAgent {
+		t.Fatalf("Run() = %v, want an agent failure", err)
+	}
+	want := gungnir.Usage{InTok: (3 + 100) + 5 + 1, OutTok: 40 + 20 + 1, CacheTok: 3000, Turns: 3, CostEstimated: true}
+	if se.Usage != want {
+		t.Errorf("usage = %+v, want %+v", se.Usage, want)
+	}
+}
+
+func TestASessionWithoutAResultCountsWhatItReported(t *testing.T) {
+	f := &fake{stdout: initLine + "\n" + assistant("m1", 7, 9, 0, 11) + "not json at all\n", exit: 137}
+	tk := task(f)
+	tk.TranscriptDir = t.TempDir()
+	_, err := agent().Run(context.Background(), tk)
+	var se *gungnir.SessionError
+	if !errors.As(err, &se) || se.Usage.InTok != 7 || se.Usage.OutTok != 9 || se.Usage.CacheTok != 11 || se.Usage.Turns != 1 {
+		t.Errorf("Run() = %v, usage %+v", err, se)
+	}
+	f = &fake{stdout: "", exit: 1}
+	tk = task(f)
+	tk.TranscriptDir = t.TempDir()
+	_, err = agent().Run(context.Background(), tk)
+	if !errors.As(err, &se) || se.Usage != (gungnir.Usage{}) {
+		t.Errorf("a session that printed nothing: usage %+v, want none", se.Usage)
+	}
+}
+
+// Backlog B-021: a chatty session is stopped by the bound, and the host never holds it all.
+func TestSessionOutputIsBounded(t *testing.T) {
+	old := maxStream
+	maxStream = 200
+	defer func() { maxStream = old }()
+	f := &fake{stdout: initLine + "\n" + assistant("m1", 1, 2, 0, 0) + strings.Repeat("noise\n", 100) + okResult + "\n"}
+	tk := task(f)
+	tk.TranscriptDir = t.TempDir()
+	r, err := agent().Run(context.Background(), tk)
+	if err == nil || gungnir.FailureOf(err) != gungnir.FailureAgent || !strings.Contains(err.Error(), "more than") {
+		t.Fatalf("Run() = %+v, %v; want an agent failure that says the output was too long", r, err)
+	}
+	if fi, err := os.Stat(filepath.Join(tk.TranscriptDir, "build-1.jsonl")); err != nil || fi.Size() > 200 {
+		t.Errorf("the transcript = %v, %v; want at most 200 bytes", fi, err)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gleipnir/bounded [github.com/ouroboric-dev/gleipnir/bounded.test]
bounded/bounded_test.go:10:7: undefined: NewBuffer
bounded/bounded_test.go:19:11: undefined: NewBuffer
bounded/bounded_test.go:28:7: undefined: NewWriter
```

- [ ] **Step 3:** write the code.

Write `bounded/bounded.go`:

```go
// Package bounded holds the writers that keep a session's output from filling the host's memory or
// disk (backlog B-021). A writer never fails and never blocks: it keeps what fits and drops the rest,
// so the tool writing to it goes on to its end, and the adapter then fails the session as too chatty.
package bounded

import (
	"bytes"
	"io"
)

// Buffer keeps the first Limit bytes written to it.
type Buffer struct {
	limit   int
	buf     bytes.Buffer
	dropped bool
}

// NewBuffer returns a Buffer that keeps at most limit bytes.
func NewBuffer(limit int) *Buffer { return &Buffer{limit: limit} }

func (b *Buffer) Write(p []byte) (int, error) {
	n := len(p)
	room := b.limit - b.buf.Len()
	if room < len(p) {
		b.dropped = true
		p = p[:max(room, 0)]
	}
	b.buf.Write(p)
	return n, nil
}

// Bytes returns what was kept.
func (b *Buffer) Bytes() []byte { return b.buf.Bytes() }

// Truncated reports whether bytes were dropped.
func (b *Buffer) Truncated() bool { return b.dropped }

// Writer passes the first limit bytes written to it on to w, and drops the rest.
type Writer struct {
	w       io.Writer
	left    int64
	dropped bool
	err     error
}

// NewWriter returns a Writer that passes on at most limit bytes to w. An error from w is kept
// (see Err), and later writes are dropped, so a full disk never stops the session itself.
func NewWriter(w io.Writer, limit int64) *Writer { return &Writer{w: w, left: limit} }

func (b *Writer) Write(p []byte) (int, error) {
	n := len(p)
	if int64(len(p)) > b.left {
		b.dropped = true
		p = p[:max(b.left, 0)]
	}
	if len(p) > 0 && b.err == nil {
		if _, err := b.w.Write(p); err != nil {
			b.err = err
		}
	}
	b.left -= int64(len(p))
	return n, nil
}

// Truncated reports whether bytes were dropped.
func (b *Writer) Truncated() bool { return b.dropped }

// Err returns the first error w gave.
func (b *Writer) Err() error { return b.err }
```

Apply to `claudecode/claudecode.go`:

```diff
diff --git a/claudecode/claudecode.go b/claudecode/claudecode.go
index f307284..adcda6f 100644
--- a/claudecode/claudecode.go
+++ b/claudecode/claudecode.go
@@ -19,6 +19,7 @@ import (
 	"strings"
 	"unicode/utf8"
 
+	"github.com/ouroboric-dev/gleipnir/bounded"
 	"github.com/ouroboric-dev/gleipnir/failure"
 	"github.com/ouroboric-dev/gungnir"
 )
@@ -30,6 +31,11 @@ const TokenVar = "CLAUDE_CODE_OAUTH_TOKEN"
 // task whose allowlist names one is refused (spec §6.3; sandbox spike B).
 var refused = []string{"ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"}
 
+// maxStream is the most bytes of a session's output the adapter keeps in memory, and the most it
+// writes to the transcript. A chatty session is an agent failure, not a host that runs out of memory
+// (backlog B-021). A variable so a test can lower it.
+var maxStream = 32 << 20
+
 // Hosts are what the sandbox's firewall must open for a session.
 var Hosts = []string{"api.anthropic.com"}
 
@@ -98,9 +104,11 @@ func (a *Agent) Run(ctx context.Context, t gungnir.Task) (gungnir.Result, error)
 		return gungnir.Result{}, err
 	}
 	defer closeT()
-	var out, errOut bytes.Buffer
+	out, errOut := bounded.NewBuffer(maxStream), bounded.NewBuffer(maxStream)
+	tw := bounded.NewWriter(transcript, int64(maxStream))
 	res, err := t.Sandbox.Run(ctx, gungnir.Cmd{Argv: Args(t), Env: env, Stdin: strings.NewReader(t.Prompt),
-		Stdout: io.MultiWriter(&out, transcript), Stderr: &errOut})
+		Stdout: io.MultiWriter(out, tw), Stderr: errOut})
+	used := partialUsage(out.Bytes())
 	if err != nil {
 		// A session the timeout or the operator ended is the agent's; any other failure to run the
 		// command is the sandbox's (spec §12).
@@ -108,12 +116,16 @@ func (a *Agent) Run(ctx context.Context, t gungnir.Task) (gungnir.Result, error)
 		if ctx.Err() != nil {
 			kind = gungnir.FailureAgent
 		}
-		return gungnir.Result{}, &gungnir.SessionError{Kind: kind, Err: fmt.Errorf("claude-code: %w", err)}
+		return gungnir.Result{}, &gungnir.SessionError{Kind: kind, Err: fmt.Errorf("claude-code: %w", err), Usage: used}
+	}
+	if out.Truncated() || tw.Truncated() {
+		return gungnir.Result{}, &gungnir.SessionError{Kind: gungnir.FailureAgent, Usage: used,
+			Err: fmt.Errorf("claude-code: the session wrote more than %d MiB of output", maxStream>>20)}
 	}
-	r, seen, err := parse(&out)
+	r, seen, err := parse(bytes.NewReader(out.Bytes()))
 	if err != nil {
-		return gungnir.Result{}, &gungnir.SessionError{Kind: unfinished(seen, res.ExitCode, errOut.String()),
-			Err: fmt.Errorf("claude-code: %w (exit %d; stderr: %s)", err, res.ExitCode, tail(errOut.String()))}
+		return gungnir.Result{}, &gungnir.SessionError{Kind: unfinished(seen, res.ExitCode, string(errOut.Bytes())), Usage: used,
+			Err: fmt.Errorf("claude-code: %w (exit %d; stderr: %s)", err, res.ExitCode, tail(string(errOut.Bytes())))}
 	}
 	r.TranscriptPath = transcriptPath(t)
 	r.Provider = "anthropic"
@@ -255,3 +267,56 @@ func clip(s string) string {
 	}
 	return string([]rune(s)[:1000]) + "…"
 }
+
+// partialUsage adds up what a session's assistant messages reported before it ended, for a session
+// that left no result event (a timeout, a crash). The numbers are a lower bound: the last message may be
+// cut off, and the cost isn't known (it is zero, marked estimated). A message the stream repeats, one
+// event per content block, counts once, at its largest figures; one with no id counts on its own, which
+// can only overcount, and a cap should err that way.
+func partialUsage(stream []byte) gungnir.Usage {
+	type tokens struct{ in, out, cacheNew, cacheRead int64 }
+	byID := map[string]tokens{}
+	var anon []tokens
+	sc := bufio.NewScanner(bytes.NewReader(stream))
+	sc.Buffer(make([]byte, 1<<20), 64<<20)
+	for sc.Scan() {
+		var e struct {
+			Type    string `json:"type"`
+			Message struct {
+				ID  string `json:"id"`
+				Raw struct {
+					Input     int64 `json:"input_tokens"`
+					Output    int64 `json:"output_tokens"`
+					CacheNew  int64 `json:"cache_creation_input_tokens"`
+					CacheRead int64 `json:"cache_read_input_tokens"`
+				} `json:"usage"`
+			} `json:"message"`
+		}
+		line := bytes.TrimSpace(sc.Bytes())
+		if len(line) == 0 || line[0] != '{' || json.Unmarshal(line, &e) != nil || e.Type != "assistant" {
+			continue
+		}
+		u := tokens{e.Message.Raw.Input, e.Message.Raw.Output, e.Message.Raw.CacheNew, e.Message.Raw.CacheRead}
+		if e.Message.ID == "" {
+			anon = append(anon, u)
+			continue
+		}
+		old := byID[e.Message.ID]
+		byID[e.Message.ID] = tokens{max(old.in, u.in), max(old.out, u.out), max(old.cacheNew, u.cacheNew), max(old.cacheRead, u.cacheRead)}
+	}
+	var sum gungnir.Usage
+	add := func(t tokens) {
+		sum.InTok += t.in + t.cacheNew
+		sum.OutTok += t.out
+		sum.CacheTok += t.cacheRead
+		sum.Turns++
+	}
+	for _, t := range byID {
+		add(t)
+	}
+	for _, t := range anon {
+		add(t)
+	}
+	sum.CostEstimated = sum.Turns > 0
+	return sum
+}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T109: `opencode`: how a session fails, its final answer, and a failed session with no cost

The same for `opencode` (spec §12, §4.6), and backlog B-019: tokens with no dollar figure leave the
dollar cap blind, and that is refused for a session that failed as much as for one that succeeded.

**Files (in `gleipnir`):**

- Modify: `failure/failure.go`, `failure/failure_test.go`, `opencode/opencode.go`, `opencode/opencode_test.go`

**Interfaces:**

- Consumes: `failure.Classify`, `SessionError`, `Result.Failure`, `Result.Output`.
- Changes: `(*Agent).parse` returns the result, what the events reported as `gungnir.Usage` whether or not
  the session is usable, and whether there was any event. `Output` is the text of the last step that said
  anything, its text parts joined. A failed result's `Failure` is `Classify(statusCode, message)` of the
  `error` event. A session with tokens and no cost is refused whatever its status, as a `*SessionError`
  that carries the tokens. A session that printed no event and exited non-zero is transient; one whose
  stderr says the quota is used up is quota; the sandbox's runner failing is infra, and a context that
  ended is agent, as for `claude-code`.
- Changes `failure.Classify`: a key limit or credit limit (`Key limit exceeded (monthly limit)`) is a
  quota.

**Acceptance criteria:**

- [ ] A 429 and a 502 are transient; 402, a quota in the words and a key over its limit are quota; a 401
      and a 400 are agent failures.
- [ ] The final answer is the text of the last step that spoke, whole, across several text parts.
- [ ] A failed session with tokens and no cost is refused and carries its tokens.
- [ ] Five endings without a step each get their kind; a runner that failed is infra, a context that
      ended is agent.

**Named test:** `go test ./failure ./opencode` in `gleipnir`. **Layer:** `gleipnir`.
**Size:** M (165). **Depends on:** v0-T108.

- [ ] **Step 1:** write the tests.

Apply to `failure/failure_test.go`:

```diff
diff --git a/failure/failure_test.go b/failure/failure_test.go
index fefca94..5437f65 100644
--- a/failure/failure_test.go
+++ b/failure/failure_test.go
@@ -28,6 +28,7 @@ func TestClassify(t *testing.T) {
 		{"credits used up, reported as a 429", 429, "You have insufficient credits for this request", quota},
 		{"a plan's usage limit", 0, "Claude usage limit reached. Your limit will reset at 3pm", quota},
 		{"a plan's usage limit, reported as a 429", 429, "5-hour limit reached, resets 3pm", quota},
+		{"a key over its credit limit", 403, "Key limit exceeded (monthly limit)", quota},
 		{"a quota", 429, "You exceeded your current quota", quota},
 		{"a bad request", 400, "invalid request", agent},
 		{"an unauthorised key", 401, "invalid api key", agent},
```

Apply to `opencode/opencode_test.go`:

```diff
diff --git a/opencode/opencode_test.go b/opencode/opencode_test.go
index 270ccf5..fb703c4 100644
--- a/opencode/opencode_test.go
+++ b/opencode/opencode_test.go
@@ -4,6 +4,7 @@ import (
 	"context"
 	"encoding/json"
 	"errors"
+	"fmt"
 	"io"
 	"os"
 	"strings"
@@ -14,6 +15,8 @@ import (
 
 type fake struct {
 	stdout map[string]string // by the program's first argument: run or --version
+	stderr string
+	err    error // what the run command returns, beside its output
 	exit   int
 	calls  []gungnir.Cmd
 	prompt string
@@ -30,7 +33,10 @@ func (f *fake) Run(_ context.Context, c gungnir.Cmd) (gungnir.ExecResult, error)
 		f.prompt = string(b)
 	}
 	c.Stdout.Write([]byte(f.stdout["run"]))
-	return gungnir.ExecResult{ExitCode: f.exit}, nil
+	if c.Stderr != nil {
+		c.Stderr.Write([]byte(f.stderr))
+	}
+	return gungnir.ExecResult{ExitCode: f.exit}, f.err
 }
 
 func fixture(t *testing.T, name string) string {
@@ -206,3 +212,99 @@ func TestRefusals(t *testing.T) {
 		t.Error("a task for another model ran")
 	}
 }
+
+func apiError(status int, message string) string {
+	return fmt.Sprintf(`{"type":"error","error":{"name":"APIError","data":{"message":%q,"statusCode":%d}}}`, message, status) + "\n"
+}
+
+func TestAnAPIErrorSaysHowItFailed(t *testing.T) {
+	cases := map[string]struct {
+		status  int
+		message string
+		want    gungnir.FailureKind
+	}{
+		"a rate limit":         {429, "Rate limit exceeded: free-models-per-min", gungnir.FailureTransient},
+		"a server error":       {502, "Bad gateway", gungnir.FailureTransient},
+		"credits used up":      {402, "Insufficient credits. Add more using https://openrouter.ai/credits", gungnir.FailureQuota},
+		"a key over its limit": {403, "Key limit exceeded (monthly limit)", gungnir.FailureQuota},
+		"a quota in the words": {429, "You exceeded your current quota", gungnir.FailureQuota},
+		"a rejected key":       {401, "No auth credentials found", gungnir.FailureAgent},
+		"a bad request":        {400, "invalid model", gungnir.FailureAgent},
+	}
+	for name, c := range cases {
+		f := &fake{stdout: map[string]string{"run": apiError(c.status, c.message)}, exit: 1}
+		r, err := newAgent(t, "standard", nil).Run(context.Background(), task(f, t))
+		if err != nil || r.Status != gungnir.StatusFailed || r.Failure != c.want {
+			t.Errorf("%s: %+v, %v; want a failed result of kind %q", name, r, err, c.want)
+		}
+	}
+}
+
+func TestTheFinalAnswerIsTheTextOfTheLastStepThatSaidAnything(t *testing.T) {
+	step := func(text string, cost string) string {
+		out := `{"type":"step_start","part":{"type":"step-start"}}` + "\n"
+		for _, part := range text {
+			out += fmt.Sprintf(`{"type":"text","part":{"type":"text","text":%q}}`, string(part)) + "\n"
+		}
+		return out + `{"type":"step_finish","part":{"type":"step-finish","reason":"stop","tokens":{"input":1,"output":1,"reasoning":0,"cache":{"write":0,"read":0}},"cost":` + cost + `}}` + "\n"
+	}
+	// The second step's text comes in two parts; the third step, a tool call, says nothing.
+	two := `{"type":"step_start","part":{"type":"step-start"}}` + "\n" +
+		`{"type":"text","part":{"type":"text","text":"{\"findings\":"}}` + "\n" +
+		`{"type":"text","part":{"type":"text","text":"[]}\n"}}` + "\n" +
+		`{"type":"step_finish","part":{"type":"step-finish","tokens":{"input":1,"output":1,"reasoning":0,"cache":{"write":0,"read":0}},"cost":0.001}}` + "\n"
+	f := &fake{stdout: map[string]string{"run": step("x", "0.001") + two + step("", "0.001")}}
+	r, err := newAgent(t, "standard", nil).Run(context.Background(), task(f, t))
+	if err != nil || r.Output != `{"findings":[]}` || r.Usage.Turns != 3 {
+		t.Errorf("Run() = %+v, %v; want the output {\"findings\":[]}", r, err)
+	}
+}
+
+// Backlog B-019: a session that failed after it spent tokens, with no dollar figure, is refused like
+// one that succeeded, and the tokens it spent still count.
+func TestAFailedSessionWithTokensAndNoCostIsRefused(t *testing.T) {
+	stream := strings.Replace(fixture(t, "success.jsonl"), `"cost":0.00001005`, `"cost":0`, 1) + apiError(500, "upstream died")
+	f := &fake{stdout: map[string]string{"run": stream}, exit: 1}
+	_, err := newAgent(t, "standard", nil).Run(context.Background(), task(f, t))
+	var se *gungnir.SessionError
+	if !errors.As(err, &se) || !strings.Contains(err.Error(), "price") {
+		t.Fatalf("Run() = %v, want a refusal that names the price", err)
+	}
+	if se.Usage.InTok != 7 || se.Usage.OutTok != 5 || se.Usage.CacheTok != 80 || se.Usage.Turns != 1 {
+		t.Errorf("the refusal's usage = %+v; the tokens must still be counted", se.Usage)
+	}
+}
+
+func TestASessionThatEndedWithoutAnyStepSaysHowItFailed(t *testing.T) {
+	cases := map[string]struct {
+		stdout, stderr string
+		exit           int
+		want           gungnir.FailureKind
+	}{
+		"a tool that crashed at start": {"", "bun: command not found", 127, gungnir.FailureTransient},
+		"garbage and a bad exit":       {"panic: boom\n", "", 2, gungnir.FailureTransient},
+		"a quota said on stderr":       {"", "insufficient credits", 1, gungnir.FailureQuota},
+		"a clean exit and no events":   {"", "", 0, gungnir.FailureAgent},
+		"a step with a number missing": {strings.Replace(fixture(t, "success.jsonl"), `"cache":{"write":0,"read":80}`, `"cache":{}`, 1), "", 0, gungnir.FailureAgent},
+	}
+	for name, c := range cases {
+		f := &fake{stdout: map[string]string{"run": c.stdout}, stderr: c.stderr, exit: c.exit}
+		_, err := newAgent(t, "standard", nil).Run(context.Background(), task(f, t))
+		if err == nil || gungnir.FailureOf(err) != c.want {
+			t.Errorf("%s: Run() = %v (kind %q), want an error of kind %q", name, err, gungnir.FailureOf(err), c.want)
+		}
+	}
+}
+
+func TestACommandThatCouldNotRunIsTheSandboxsFailure(t *testing.T) {
+	f := &fake{err: errors.New("podman exec: no such container")}
+	if _, err := newAgent(t, "standard", nil).Run(context.Background(), task(f, t)); gungnir.FailureOf(err) != gungnir.FailureInfra {
+		t.Errorf("Run() = %v (kind %q), want an infra failure", err, gungnir.FailureOf(err))
+	}
+	ctx, cancel := context.WithCancel(context.Background())
+	cancel()
+	f = &fake{err: ctx.Err()}
+	if _, err := newAgent(t, "standard", nil).Run(ctx, task(f, t)); gungnir.FailureOf(err) != gungnir.FailureAgent {
+		t.Errorf("a session the context ended: Run() = %v (kind %q), want an agent failure", err, gungnir.FailureOf(err))
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestClassify (0.00s)
    failure_test.go:42: a key over its credit limit: Classify(403, "Key limit exceeded (monthly limit)") = "agent", want "quota"
FAIL
FAIL	github.com/ouroboric-dev/gleipnir/failure	0.002s
```

- [ ] **Step 3:** write the code.

Apply to `failure/failure.go`:

```diff
diff --git a/failure/failure.go b/failure/failure.go
index 742d493..f827d51 100644
--- a/failure/failure.go
+++ b/failure/failure.go
@@ -13,7 +13,7 @@ import (
 
 // quota matches the words providers use when a quota, a credit balance or a plan's usage limit is
 // used up. A plain rate limit is not here: it clears in seconds, and is transient.
-var quota = regexp.MustCompile(`(?i)usage limit|limit reached|reached (?:your|the) (?:\w+ )?limit|hit your limit|quota|insufficient (?:credits|funds)|out of credits|credit balance|billing|payment required`)
+var quota = regexp.MustCompile(`(?i)usage limit|(?:key|credit|spend|monthly|daily|weekly) limit|limit reached|reached (?:your|the) (?:\w+ )?limit|hit your limit|quota|insufficient (?:credits|funds)|out of credits|credit balance|billing|payment required`)
 
 // transient matches the words of a network or capacity failure that reports no status.
 var transient = regexp.MustCompile(`(?i)overloaded|rate.?limit|too many requests|temporarily unavailable|ECONNRESET|ECONNREFUSED|ETIMEDOUT|EAI_AGAIN|socket hang up|fetch failed|connection (?:reset|refused|closed)|service unavailable|bad gateway|gateway time-?out`)
```

Apply to `opencode/opencode.go`:

```diff
diff --git a/opencode/opencode.go b/opencode/opencode.go
index c203a54..cde140c 100644
--- a/opencode/opencode.go
+++ b/opencode/opencode.go
@@ -18,6 +18,7 @@ import (
 	"strings"
 	"unicode/utf8"
 
+	"github.com/ouroboric-dev/gleipnir/failure"
 	"github.com/ouroboric-dev/gungnir"
 )
 
@@ -156,11 +157,24 @@ func (a *Agent) Run(ctx context.Context, t gungnir.Task) (gungnir.Result, error)
 	res, err := t.Sandbox.Run(ctx, gungnir.Cmd{Argv: Args(t, a.model), Env: env, Stdin: strings.NewReader(t.Prompt),
 		Stdout: io.MultiWriter(&out, transcript), Stderr: &errOut})
 	if err != nil {
-		return gungnir.Result{}, fmt.Errorf("opencode: %w", err)
+		// A session the timeout or the operator ended is the agent's; any other failure to run the
+		// command is the sandbox's (spec §12).
+		kind := gungnir.FailureInfra
+		if ctx.Err() != nil {
+			kind = gungnir.FailureAgent
+		}
+		return gungnir.Result{}, &gungnir.SessionError{Kind: kind, Err: fmt.Errorf("opencode: %w", err)}
 	}
-	r, err := a.parse(&out, res.ExitCode)
+	r, used, seen, err := a.parse(&out, res.ExitCode)
 	if err != nil {
-		return gungnir.Result{}, fmt.Errorf("opencode: %w (exit %d; stderr: %s)", err, res.ExitCode, tail(errOut.String()))
+		kind := gungnir.FailureAgent
+		if k := failure.Classify(0, errOut.String()); k == gungnir.FailureQuota {
+			kind = k
+		} else if !seen && res.ExitCode != 0 {
+			kind = gungnir.FailureTransient // the tool crashed before it printed an event (spec §12)
+		}
+		return gungnir.Result{}, &gungnir.SessionError{Kind: kind, Usage: used,
+			Err: fmt.Errorf("opencode: %w (exit %d; stderr: %s)", err, res.ExitCode, tail(errOut.String()))}
 	}
 	r.TranscriptPath, r.Provider, r.CLIVersion = transcriptPath(t), "openrouter", version
 	return r, nil
@@ -236,16 +250,18 @@ type event struct {
 // parse reads a session's events. Each step_finish carries one step's tokens, and the session's
 // usage is their sum: cache reads stay separate from other input tokens, because they bill at
 // another rate (spike C). The cost is the tool's own figure, or the price's, and is marked
-// estimated either way: the provider's real bill isn't in the events.
-func (a *Agent) parse(r io.Reader, exit int) (gungnir.Result, error) {
+// estimated either way: the provider's real bill isn't in the events. used is what the events
+// reported, whether or not the session is usable, and seen says whether there was any event at all.
+// The final answer is the text of the last step that said anything.
+func (a *Agent) parse(r io.Reader, exit int) (res gungnir.Result, used gungnir.Usage, seen bool, err error) {
 	sc := bufio.NewScanner(r)
 	sc.Buffer(make([]byte, 1<<20), 64<<20)
-	var u gungnir.Usage
-	var text, failure string
+	var text, answer, failed string
+	status := 0
 	steps := 0
-	var price Price
-	cost := 0.0
-	var in, out, reason, cw int64
+	var cost float64
+	var in, out, reason, cw, cacheRead int64
+	broken := false // a step_finish lacked a number
 	for sc.Scan() {
 		line := bytes.TrimSpace(sc.Bytes())
 		if len(line) == 0 || line[0] != '{' {
@@ -255,54 +271,67 @@ func (a *Agent) parse(r io.Reader, exit int) (gungnir.Result, error) {
 		if json.Unmarshal(line, &e) != nil {
 			continue
 		}
+		seen = true
 		switch e.Type {
+		case "step_start":
+			text = ""
 		case "text":
-			text = e.Part.Text
+			text += e.Part.Text
 		case "error":
-			failure = "error"
+			failed = "error"
 			if e.Error != nil {
-				failure = fmt.Sprintf("%s: %s", e.Error.Name, e.Error.Data.Message)
-				if e.Error.Data.StatusCode != 0 {
-					failure += fmt.Sprintf(" (API status %d)", e.Error.Data.StatusCode)
+				failed = fmt.Sprintf("%s: %s", e.Error.Name, e.Error.Data.Message)
+				status = e.Error.Data.StatusCode
+				if status != 0 {
+					failed += fmt.Sprintf(" (API status %d)", status)
 				}
 			}
 		case "step_finish":
 			tk := e.Part.Tokens
 			if tk == nil || tk.Input == nil || tk.Output == nil || tk.Cache == nil || tk.Cache.Read == nil || tk.Cache.Write == nil || e.Part.Cost == nil {
-				return gungnir.Result{}, errors.New("a step_finish event lacks tokens or cost; refusing to read missing numbers as zero")
+				broken = true
+				continue
 			}
 			steps++
 			in += *tk.Input
 			out += *tk.Output
 			cw += *tk.Cache.Write
-			u.CacheTok += *tk.Cache.Read
+			cacheRead += *tk.Cache.Read
 			if tk.Reasoning != nil {
 				reason += *tk.Reasoning
 			}
 			cost += *e.Part.Cost
+			if strings.TrimSpace(text) != "" {
+				answer = text
+			}
 		}
 	}
 	if err := sc.Err(); err != nil {
-		return gungnir.Result{}, err
+		return gungnir.Result{}, used, seen, err
 	}
-	u.InTok, u.OutTok, u.Turns = in+cw, out+reason, int64(steps)
+	used = gungnir.Usage{InTok: in + cw, OutTok: out + reason, CacheTok: cacheRead, Turns: int64(steps)}
 	if a.cfg.Price != nil {
-		price = *a.cfg.Price
-		cost = (float64(in)*price.Input + float64(out+reason)*price.Output + float64(u.CacheTok)*price.CacheRead + float64(cw)*price.CacheWrite) / 1e6
+		p := *a.cfg.Price
+		cost = (float64(in)*p.Input + float64(out+reason)*p.Output + float64(cacheRead)*p.CacheRead + float64(cw)*p.CacheWrite) / 1e6
+	}
+	used.CostUSD, used.CostEstimated = cost, true
+	switch {
+	case broken:
+		return gungnir.Result{}, used, seen, errors.New("a step_finish event lacks tokens or cost; refusing to read missing numbers as zero")
+	case failed == "" && steps == 0:
+		return gungnir.Result{}, used, seen, errors.New("the session ended without a single step")
+	case cost == 0 && used.InTok+used.OutTok+used.CacheTok > 0:
+		// Whether the session succeeded or not: tokens with no dollars leave the dollar cap blind.
+		return gungnir.Result{}, used, seen, errors.New("opencode reported tokens but no cost for this model; set roles.<role>.price in factory.yaml so the caps can count dollars")
 	}
-	u.CostUSD, u.CostEstimated = cost, true
-	res := gungnir.Result{Status: gungnir.StatusOK, Summary: clip(text), Usage: u}
+	res = gungnir.Result{Status: gungnir.StatusOK, Summary: clip(answer), Output: strings.TrimSpace(answer), Usage: used}
 	switch {
-	case failure != "":
-		res.Status, res.Summary = gungnir.StatusFailed, failure
-	case steps == 0:
-		return gungnir.Result{}, errors.New("the session ended without a single step")
+	case failed != "":
+		res.Status, res.Summary, res.Failure = gungnir.StatusFailed, failed, failure.Classify(status, failed)
 	case exit != 0:
-		res.Status, res.Summary = gungnir.StatusFailed, fmt.Sprintf("opencode exited %d: %s", exit, res.Summary)
-	case cost == 0 && u.InTok+u.OutTok+u.CacheTok > 0:
-		return gungnir.Result{}, errors.New("opencode reported tokens but no cost for this model; set roles.<role>.price in factory.yaml so the caps can count dollars")
+		res.Status, res.Summary, res.Failure = gungnir.StatusFailed, fmt.Sprintf("opencode exited %d: %s", exit, res.Summary), gungnir.FailureAgent
 	}
-	return res, res.Validate()
+	return res, used, seen, res.Validate()
 }
 
 func clip(s string) string {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T110: `opencode`: what a session that did not finish used, and a bound on its output

Backlog B-020 and B-021, for `opencode`: the steps that finished before the session ended were spent.

**Files (in `gleipnir`):**

- Modify: `opencode/opencode.go`, `opencode/opencode_test.go`

**Interfaces:**

- Consumes: `bounded` (v0-T108).
- Produces: every `*SessionError` of the adapter carries the usage of the steps that finished, parsed
  from the partial stream. Output over 32 MiB is an agent failure; the transcript stops at the same bound.

**Acceptance criteria:**

- [ ] A session ended by its deadline, in the middle of a step, reports the step that finished.
- [ ] A session over the bound is an agent failure, and its transcript is at most the bound.

**Named test:** `go test ./opencode -run 'TestATimedOutSessionStillCountsItsUsage|TestSessionOutputIsBounded'`
in `gleipnir`. **Layer:** `gleipnir`. **Size:** S (52). **Depends on:** v0-T109.

- [ ] **Step 1:** write the tests.

Apply to `opencode/opencode_test.go`:

```diff
diff --git a/opencode/opencode_test.go b/opencode/opencode_test.go
index fb703c4..737e560 100644
--- a/opencode/opencode_test.go
+++ b/opencode/opencode_test.go
@@ -308,3 +308,36 @@ func TestACommandThatCouldNotRunIsTheSandboxsFailure(t *testing.T) {
 		t.Errorf("a session the context ended: Run() = %v (kind %q), want an agent failure", err, gungnir.FailureOf(err))
 	}
 }
+
+// Backlog B-020: a session the timeout killed still spent the steps that finished.
+func TestATimedOutSessionStillCountsItsUsage(t *testing.T) {
+	ctx, cancel := context.WithCancel(context.Background())
+	cancel()
+	cut := fixture(t, "success.jsonl") + `{"type":"step_start","part":{"type":"step-start"}}` + "\n" + `{"type":"text","part":{"type":"text","text":"half a th`
+	f := &fake{stdout: map[string]string{"run": cut}, err: ctx.Err()}
+	_, err := newAgent(t, "standard", nil).Run(ctx, task(f, t))
+	var se *gungnir.SessionError
+	if !errors.As(err, &se) || se.Kind != gungnir.FailureAgent {
+		t.Fatalf("Run() = %v, want an agent failure", err)
+	}
+	want := gungnir.Usage{InTok: 7, OutTok: 5, CacheTok: 80, Turns: 1, CostUSD: 0.00001005, CostEstimated: true}
+	if se.Usage != want {
+		t.Errorf("usage = %+v, want %+v", se.Usage, want)
+	}
+}
+
+// Backlog B-021: a chatty session is stopped by the bound, and the host never holds it all.
+func TestSessionOutputIsBounded(t *testing.T) {
+	old := maxStream
+	maxStream = 300
+	defer func() { maxStream = old }()
+	f := &fake{stdout: map[string]string{"run": fixture(t, "success.jsonl") + strings.Repeat("noise\n", 200)}}
+	tk := task(f, t)
+	_, err := newAgent(t, "standard", nil).Run(context.Background(), tk)
+	if err == nil || gungnir.FailureOf(err) != gungnir.FailureAgent || !strings.Contains(err.Error(), "more than") {
+		t.Fatalf("Run() = %v; want an agent failure that says the output was too long", err)
+	}
+	if fi, err := os.Stat(tk.TranscriptDir + "/review-1.jsonl"); err != nil || fi.Size() > 300 {
+		t.Errorf("the transcript = %v, %v; want at most 300 bytes", fi, err)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gleipnir/opencode [github.com/ouroboric-dev/gleipnir/opencode.test]
opencode/opencode_test.go:331:9: undefined: maxStream
opencode/opencode_test.go:332:2: undefined: maxStream
opencode/opencode_test.go:333:17: undefined: maxStream
```

- [ ] **Step 3:** write the code.

Apply to `opencode/opencode.go`:

```diff
diff --git a/opencode/opencode.go b/opencode/opencode.go
index cde140c..28f5bcf 100644
--- a/opencode/opencode.go
+++ b/opencode/opencode.go
@@ -18,6 +18,7 @@ import (
 	"strings"
 	"unicode/utf8"
 
+	"github.com/ouroboric-dev/gleipnir/bounded"
 	"github.com/ouroboric-dev/gleipnir/failure"
 	"github.com/ouroboric-dev/gungnir"
 )
@@ -26,6 +27,11 @@ import (
 // limit (spec §6.3).
 const KeyVar = "OPENROUTER_API_KEY"
 
+// maxStream is the most bytes of a session's output the adapter keeps in memory, and the most it
+// writes to the transcript. A chatty session is an agent failure, not a host that runs out of memory
+// (backlog B-021). A variable so a test can lower it.
+var maxStream = 32 << 20
+
 // Hosts are what the sandbox's firewall must open for a session.
 var Hosts = []string{"openrouter.ai"}
 
@@ -153,9 +159,12 @@ func (a *Agent) Run(ctx context.Context, t gungnir.Task) (gungnir.Result, error)
 	}
 	defer closeT()
 	version := a.version(ctx, t, env)
-	var out, errOut bytes.Buffer
+	out, errOut := bounded.NewBuffer(maxStream), bounded.NewBuffer(maxStream)
+	tw := bounded.NewWriter(transcript, int64(maxStream))
 	res, err := t.Sandbox.Run(ctx, gungnir.Cmd{Argv: Args(t, a.model), Env: env, Stdin: strings.NewReader(t.Prompt),
-		Stdout: io.MultiWriter(&out, transcript), Stderr: &errOut})
+		Stdout: io.MultiWriter(out, tw), Stderr: errOut})
+	// The steps that finished before the session ended were spent, whatever way it ended (backlog B-020).
+	_, spent, _, _ := a.parse(bytes.NewReader(out.Bytes()), 0)
 	if err != nil {
 		// A session the timeout or the operator ended is the agent's; any other failure to run the
 		// command is the sandbox's (spec §12).
@@ -163,18 +172,22 @@ func (a *Agent) Run(ctx context.Context, t gungnir.Task) (gungnir.Result, error)
 		if ctx.Err() != nil {
 			kind = gungnir.FailureAgent
 		}
-		return gungnir.Result{}, &gungnir.SessionError{Kind: kind, Err: fmt.Errorf("opencode: %w", err)}
+		return gungnir.Result{}, &gungnir.SessionError{Kind: kind, Err: fmt.Errorf("opencode: %w", err), Usage: spent}
+	}
+	if out.Truncated() || tw.Truncated() {
+		return gungnir.Result{}, &gungnir.SessionError{Kind: gungnir.FailureAgent, Usage: spent,
+			Err: fmt.Errorf("opencode: the session wrote more than %d MiB of output", maxStream>>20)}
 	}
-	r, used, seen, err := a.parse(&out, res.ExitCode)
+	r, used, seen, err := a.parse(bytes.NewReader(out.Bytes()), res.ExitCode)
 	if err != nil {
 		kind := gungnir.FailureAgent
-		if k := failure.Classify(0, errOut.String()); k == gungnir.FailureQuota {
+		if k := failure.Classify(0, string(errOut.Bytes())); k == gungnir.FailureQuota {
 			kind = k
 		} else if !seen && res.ExitCode != 0 {
 			kind = gungnir.FailureTransient // the tool crashed before it printed an event (spec §12)
 		}
 		return gungnir.Result{}, &gungnir.SessionError{Kind: kind, Usage: used,
-			Err: fmt.Errorf("opencode: %w (exit %d; stderr: %s)", err, res.ExitCode, tail(errOut.String()))}
+			Err: fmt.Errorf("opencode: %w (exit %d; stderr: %s)", err, res.ExitCode, tail(string(errOut.Bytes())))}
 	}
 	r.TranscriptPath, r.Provider, r.CLIVersion = transcriptPath(t), "openrouter", version
 	return r, nil
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T111: scripted: failures of every kind, usage on a failed step, a final answer or a report

Odin's tests need a scripted agent that fails the ways real ones do, spends what a failed session
spends, and answers as a reviewer answers.

**Files (in `gleipnir`):**

- Modify: `scripted/scripted.go`, `scripted/scripted_test.go`

**Interfaces:**

- Produces, in a script: on a step, `kind: agent|transient|quota|infra` for an `error` step, and
  `usage:` for an `error` or `hang` step (a `*gungnir.SessionError` when either is set; a plain error
  otherwise, an agent failure); on a `result`, `failure: agent|transient|quota` (with `status: failed`),
  `output: "<text>"` or `report: [<findings>]` (the findings document a reviewer writes, built from the
  list; at most one of the two). An empty `report: []` is a well-formed empty report.
- Changes: a step's `actions` happen before its `hang` or `error`, as before its `result`, so a session
  that fails half way leaves its work behind. A script that sets a kind on a result or a failure on a
  success, names a kind that does not exist, or puts `usage` beside a `result` is refused.

**Acceptance criteria:**

- [ ] Each kind of error step fails with its kind, an error with no kind and no usage stays a plain error,
      and the usage of a quota error survives.
- [ ] A hang ends with the context's error and carries its usage.
- [ ] A step that writes a file and then fails leaves the file.
- [ ] A result carries its `output`, or a `report` that `schema.ParseReport` reads; an empty report is
      well formed.
- [ ] Eight malformed scripts are refused.

**Named test:** `go test ./scripted` in `gleipnir`. **Layer:** `gleipnir`. **Size:** M (203).
**Depends on:** v0-T097 merged.

- [ ] **Step 1:** write the tests.

Apply to `scripted/scripted_test.go`:

```diff
diff --git a/scripted/scripted_test.go b/scripted/scripted_test.go
index be02e1d..d1763a0 100644
--- a/scripted/scripted_test.go
+++ b/scripted/scripted_test.go
@@ -10,6 +10,7 @@ import (
 	"time"
 
 	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/gungnir/schema"
 )
 
 func load(t *testing.T, script string) *Agent {
@@ -181,3 +182,119 @@ func TestScriptedReportsAProviderAndAToolVersionWhenTheScriptGivesThem(t *testin
 		t.Errorf("Run() = %+v, %v", r, err)
 	}
 }
+
+func run(t *testing.T, a *Agent, node string, attempt int) (gungnir.Result, error) {
+	t.Helper()
+	return a.Run(context.Background(), gungnir.Task{Node: node, Attempt: attempt, Workdir: t.TempDir()})
+}
+
+func TestScriptedFailsTheWayTheScriptSays(t *testing.T) {
+	a := load(t, `
+steps:
+  build:
+    - error: the CLI crashed
+      kind: transient
+    - error: out of credits
+      kind: quota
+      usage: { in: 100, out: 20, turns: 2 }
+    - error: podman is gone
+      kind: infra
+    - error: just broke
+    - result: { status: failed, summary: rate limited, failure: transient }
+    - result: { status: failed, summary: no credits, failure: quota, usage: { in: 5, out: 1, turns: 1 } }
+    - result: { status: failed, summary: tests fail }
+`)
+	want := []gungnir.FailureKind{gungnir.FailureTransient, gungnir.FailureQuota, gungnir.FailureInfra, gungnir.FailureAgent}
+	for i, k := range want {
+		_, err := run(t, a, "build", i+1)
+		if err == nil || gungnir.FailureOf(err) != k {
+			t.Errorf("attempt %d: Run() = %v (kind %q), want an error of kind %q", i+1, err, gungnir.FailureOf(err), k)
+		}
+	}
+	_, err := run(t, a, "build", 2)
+	var se *gungnir.SessionError
+	if !errors.As(err, &se) || se.Usage.InTok != 100 || se.Usage.OutTok != 20 || se.Usage.Turns != 2 {
+		t.Errorf("the quota error's usage = %+v", se)
+	}
+	if _, err := run(t, a, "build", 4); err == nil || errors.As(err, &se) {
+		t.Errorf("an error with no kind and no usage must stay a plain error, got %T %v", err, err)
+	}
+	for i, k := range []gungnir.FailureKind{gungnir.FailureTransient, gungnir.FailureQuota, ""} {
+		r, err := run(t, a, "build", i+5)
+		if err != nil || r.Status != gungnir.StatusFailed || r.Failure != k {
+			t.Errorf("result %d: %+v, %v; want a failed result of kind %q", i+5, r, err, k)
+		}
+	}
+}
+
+func TestAHangEndsWithTheContextAndItsUsage(t *testing.T) {
+	a := load(t, "steps:\n  build:\n    - hang: true\n      usage: { in: 9, out: 1, turns: 1 }\n")
+	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
+	defer cancel()
+	_, err := a.Run(ctx, gungnir.Task{Node: "build", Attempt: 1, Workdir: t.TempDir()})
+	var se *gungnir.SessionError
+	if !errors.Is(err, context.DeadlineExceeded) || !errors.As(err, &se) || se.Usage.InTok != 9 {
+		t.Errorf("Run() = %v; want the context's error carrying the usage", err)
+	}
+}
+
+func TestActionsHappenBeforeAnErrorOrAHang(t *testing.T) {
+	a := load(t, "steps:\n  build:\n    - actions: [ { write: { path: half.txt, content: \"partial\\n\" } } ]\n      error: timed out half way\n")
+	work := t.TempDir()
+	if _, err := a.Run(context.Background(), gungnir.Task{Node: "build", Attempt: 1, Workdir: work}); err == nil {
+		t.Fatal("Run() = nil, want the step's error")
+	}
+	if b, err := os.ReadFile(filepath.Join(work, "half.txt")); err != nil || string(b) != "partial\n" {
+		t.Errorf("half.txt = %q, %v; a session that fails half way leaves its work behind", b, err)
+	}
+}
+
+func TestAResultCarriesItsFinalAnswerOrAReportOfFindings(t *testing.T) {
+	a := load(t, `
+steps:
+  review:
+    - result: { status: ok, summary: reviewed, output: "LGTM, ship it" }
+    - result:
+        status: ok
+        summary: reviewed
+        report:
+          - { id: spec-1, source: spec, severity: major, location: "api/auth.go:42", claim: no throttle, status: open }
+          - { id: spec-2, source: spec, severity: minor, location: "api/auth.go:50", claim: no doc, status: fixed, proof: "api/auth.go:51; check test passed" }
+    - result: { status: ok, summary: reviewed, report: [] }
+`)
+	r, err := run(t, a, "review", 1)
+	if err != nil || r.Output != "LGTM, ship it" {
+		t.Errorf("attempt 1: %+v, %v", r, err)
+	}
+	r, err = run(t, a, "review", 2)
+	if err != nil {
+		t.Fatal(err)
+	}
+	rep, perr := schema.ParseReport([]byte(r.Output))
+	if perr != nil || len(rep.Findings) != 2 || rep.Findings[1].Proof == "" || rep.Findings[0].Location != "api/auth.go:42" {
+		t.Errorf("attempt 2: report %+v, %v from %q", rep, perr, r.Output)
+	}
+	r, err = run(t, a, "review", 3)
+	if rep, perr := schema.ParseReport([]byte(r.Output)); err != nil || perr != nil || len(rep.Findings) != 0 {
+		t.Errorf("attempt 3: an empty report must be a well-formed report with no findings: %q, %v, %v", r.Output, perr, err)
+	}
+}
+
+func TestScriptedRefusesAScriptThatNamesNoSuchFailure(t *testing.T) {
+	for name, script := range map[string]string{
+		"an unknown kind":           "steps:\n  a:\n    - error: x\n      kind: flaky\n",
+		"a kind on a hang":          "steps:\n  a:\n    - hang: true\n      kind: quota\n",
+		"a kind on a result":        "steps:\n  a:\n    - result: { status: ok }\n      kind: quota\n",
+		"usage beside a result":     "steps:\n  a:\n    - result: { status: ok }\n      usage: { in: 1 }\n",
+		"a failure on a success":    "steps:\n  a:\n    - result: { status: ok, failure: transient }\n",
+		"infra as a result failure": "steps:\n  a:\n    - result: { status: failed, failure: infra }\n",
+		"an unknown failure":        "steps:\n  a:\n    - result: { status: failed, failure: flaky }\n",
+		"output and report":         "steps:\n  a:\n    - result: { status: ok, output: x, report: [] }\n",
+	} {
+		p := filepath.Join(t.TempDir(), "s.yaml")
+		os.WriteFile(p, []byte(script), 0o644)
+		if _, err := Load(p); err == nil {
+			t.Errorf("%s: Load() = nil, want an error", name)
+		}
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestScriptedFailsTheWayTheScriptSays (0.00s)
    scripted_test.go:192: Load() = /tmp/TestScriptedFailsTheWayTheScriptSays175124457/001/script.yaml: yaml: unmarshal errors:
          line 5: field kind not found in type scripted.Step
          line 7: field kind not found in type scripted.Step
```

- [ ] **Step 3:** write the code.

Apply to `scripted/scripted.go`:

```diff
diff --git a/scripted/scripted.go b/scripted/scripted.go
index 134d5aa..050d8d2 100644
--- a/scripted/scripted.go
+++ b/scripted/scripted.go
@@ -23,10 +23,28 @@ type Script struct {
 
 // Step is one attempt. Exactly one of Result, Hang and Error is set.
 type Step struct {
-	Actions []Action `yaml:"actions"` // applied in order, inside the workdir, before the result
+	Actions []Action `yaml:"actions"` // applied in order, inside the workdir, before the result, the hang or the error
 	Result  *Outcome `yaml:"result"`
 	Hang    bool     `yaml:"hang"`  // block until the context ends: a session the factory must stop
-	Error   string   `yaml:"error"` // Run returns this error: an agent failure
+	Error   string   `yaml:"error"` // Run returns this error
+	// Kind is how an error step fails: agent (the default), transient, quota or infra (spec §12).
+	Kind gungnir.FailureKind `yaml:"kind"`
+	// Usage is what an error or hang step spent before it ended; a result step has its own.
+	Usage *Usage `yaml:"usage"`
+}
+
+// Usage is what a session consumed.
+type Usage struct {
+	In            int64   `yaml:"in"`
+	Out           int64   `yaml:"out"`
+	Cache         int64   `yaml:"cache"`
+	Turns         int64   `yaml:"turns"`
+	CostUSD       float64 `yaml:"cost_usd"`
+	CostEstimated bool    `yaml:"cost_estimated"`
+}
+
+func (u Usage) toGungnir() gungnir.Usage {
+	return gungnir.Usage{InTok: u.In, OutTok: u.Out, CacheTok: u.Cache, Turns: u.Turns, CostUSD: u.CostUSD, CostEstimated: u.CostEstimated}
 }
 
 // Action changes one file in the workdir, or runs one command in the task's sandbox. Exactly one
@@ -56,14 +74,13 @@ type Outcome struct {
 	Summary    string         `yaml:"summary"`
 	Provider   string         `yaml:"provider"`    // who served the model, as a real adapter reports it
 	CLIVersion string         `yaml:"cli_version"` // the agent tool's version, as a real adapter reports it
-	Usage      struct {
-		In            int64   `yaml:"in"`
-		Out           int64   `yaml:"out"`
-		Cache         int64   `yaml:"cache"`
-		Turns         int64   `yaml:"turns"`
-		CostUSD       float64 `yaml:"cost_usd"`
-		CostEstimated bool    `yaml:"cost_estimated"`
-	} `yaml:"usage"`
+	Usage      Usage          `yaml:"usage"`
+	// Failure is how a failed result failed: agent (the default), transient or quota.
+	Failure gungnir.FailureKind `yaml:"failure"`
+	// Output is the session's final answer, as written. Report is the same answer as a reviewer
+	// writes it: a findings document built from these findings. A step sets at most one of them.
+	Output string            `yaml:"output"`
+	Report []gungnir.Finding `yaml:"report"`
 }
 
 // Agent replays a Script.
@@ -110,6 +127,30 @@ func (st Step) check() error {
 	if st.Result != nil && st.Result.Status != gungnir.StatusOK && st.Result.Status != gungnir.StatusFailed {
 		return fmt.Errorf("result status %q is neither ok nor failed", st.Result.Status)
 	}
+	if o := st.Result; o != nil {
+		if o.Output != "" && o.Report != nil {
+			return errors.New("a result sets at most one of output and report")
+		}
+		if o.Failure != "" && o.Status != gungnir.StatusFailed {
+			return errors.New("a result with a failure kind has status failed")
+		}
+		switch o.Failure {
+		case "", gungnir.FailureAgent, gungnir.FailureTransient, gungnir.FailureQuota:
+		default:
+			return fmt.Errorf("result failure %q is not agent, transient or quota", o.Failure)
+		}
+	}
+	switch st.Kind {
+	case "", gungnir.FailureAgent, gungnir.FailureTransient, gungnir.FailureQuota, gungnir.FailureInfra:
+	default:
+		return fmt.Errorf("kind %q is not agent, transient, quota or infra", st.Kind)
+	}
+	if (st.Kind != "" || st.Usage != nil) && st.Result != nil {
+		return errors.New("kind and usage belong to an error or hang step; a result has its own")
+	}
+	if st.Kind != "" && st.Error == "" {
+		return errors.New("kind belongs to an error step")
+	}
 	for _, a := range st.Actions {
 		set := 0
 		for _, b := range []bool{a.Write != nil, a.Remove != "", a.Run != nil} {
@@ -143,13 +184,6 @@ func (a *Agent) Run(ctx context.Context, t gungnir.Task) (gungnir.Result, error)
 	if err != nil {
 		return gungnir.Result{}, err
 	}
-	if st.Hang {
-		<-ctx.Done()
-		return gungnir.Result{}, ctx.Err()
-	}
-	if st.Error != "" {
-		return gungnir.Result{}, errors.New(st.Error)
-	}
 	root, err := os.OpenRoot(t.Workdir)
 	if err != nil {
 		return gungnir.Result{}, err
@@ -166,18 +200,47 @@ func (a *Agent) Run(ctx context.Context, t gungnir.Task) (gungnir.Result, error)
 			return gungnir.Result{}, fmt.Errorf("scripted: %w", err)
 		}
 	}
+	var spent gungnir.Usage
+	if st.Usage != nil {
+		spent = st.Usage.toGungnir()
+	}
+	switch {
+	case st.Hang:
+		<-ctx.Done()
+		return gungnir.Result{}, a.fail(ctx.Err(), "", spent)
+	case st.Error != "":
+		return gungnir.Result{}, a.fail(errors.New(st.Error), st.Kind, spent)
+	}
 	o := st.Result
+	output := o.Output
+	if o.Report != nil {
+		b, err := json.Marshal(gungnir.Report{Findings: o.Report})
+		if err != nil {
+			return gungnir.Result{}, err
+		}
+		output = string(b)
+	}
 	return gungnir.Result{
-		Status:     o.Status,
-		Summary:    o.Summary,
-		Provider:   o.Provider,
-		CLIVersion: o.CLIVersion,
-		Usage: gungnir.Usage{InTok: o.Usage.In, OutTok: o.Usage.Out, CacheTok: o.Usage.Cache,
-			Turns: o.Usage.Turns, CostUSD: o.Usage.CostUSD, CostEstimated: o.Usage.CostEstimated},
+		Status:         o.Status,
+		Summary:        o.Summary,
+		Provider:       o.Provider,
+		CLIVersion:     o.CLIVersion,
+		Usage:          o.Usage.toGungnir(),
+		Failure:        o.Failure,
+		Output:         output,
 		TranscriptPath: transcript,
 	}, nil
 }
 
+// fail is an error step's error. One with no kind and no usage stays a plain error, which is an agent
+// failure; otherwise it is a *gungnir.SessionError, as a real adapter's is.
+func (a *Agent) fail(err error, kind gungnir.FailureKind, spent gungnir.Usage) error {
+	if kind == "" && spent == (gungnir.Usage{}) {
+		return err
+	}
+	return &gungnir.SessionError{Kind: kind, Err: err, Usage: spent}
+}
+
 // runInSandbox runs one command through the task's sandbox, and keeps its output beside the
 // transcript. A task without a sandbox can't run one: the scripted adapter never runs commands on the
 // host.
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T112: the driver: podman's own failure is an error

Backlog B-016 and B-017. `podman exec` exits 125 when podman itself failed, a container that is gone
for one. That is not the command's exit code: it must not read as a failed check or node (spec §12).

**Files (in `gleipnir`):**

- Modify: `sandbox/driver.go`, `sandbox/driver_test.go`

**Interfaces:**

- Changes: `(*Driver).Exec` returns an error, with no exit code, when the command's `podman exec` exits
  125, and names the program; every other exit code, 126, 127 and 137 included, stays the command's
  result. A command that itself exits 125 reads the same way, which is a cost worth paying.
  `Up`'s closed-network probe goes through `Exec`, so a probe that exits 125 (`timeout` or podman could
  not run it) refuses the sandbox and removes it, and a probe that times out (124) still shows the
  network closed.

**Acceptance criteria:**

- [ ] An exit of 125 is an error; exits 1, 2, 126, 127 and 137 are results.
- [ ] A probe that could not run refuses `Up` and the sandbox is removed; one that timed out does not.

**Named test:** `go test ./sandbox -run 'TestExecReportsAMissingContainerAsAnError|TestUpRefusesAProbeThatCouldNotRun'`
in `gleipnir`. **Layer:** `gleipnir`. **Size:** S (47). **Depends on:** v0-T111.

- [ ] **Step 1:** write the tests.

Apply to `sandbox/driver_test.go`:

```diff
diff --git a/sandbox/driver_test.go b/sandbox/driver_test.go
index 5d48ff7..b7948a5 100644
--- a/sandbox/driver_test.go
+++ b/sandbox/driver_test.go
@@ -6,6 +6,7 @@ import (
 	"errors"
 	"os"
 	"path/filepath"
+	"strconv"
 	"strings"
 	"testing"
 	"time"
@@ -358,3 +359,40 @@ func TestUpGivesUpOnADevcontainerThatHangs(t *testing.T) {
 		t.Error("a start that timed out was not cleaned up")
 	}
 }
+
+// Backlog B-017: podman's own failure is an error, never the command's exit code.
+func TestExecReportsAMissingContainerAsAnError(t *testing.T) {
+	d, _, sp := fakeEngine(t)
+	env, err := d.Up(context.Background(), sp)
+	if err != nil {
+		t.Fatal(err)
+	}
+	t.Setenv("STUB_EXEC_EXIT", "125")
+	res, err := d.Exec(context.Background(), env, gungnir.Cmd{Argv: []string{"go", "test"}})
+	if err == nil || !strings.Contains(err.Error(), "podman couldn't run go") || res.ExitCode != 0 {
+		t.Errorf("Exec() = %+v, %v; want an error and no exit code", res, err)
+	}
+	for _, code := range []string{"1", "2", "126", "127", "137"} {
+		t.Setenv("STUB_EXEC_EXIT", code)
+		if res, err := d.Exec(context.Background(), env, gungnir.Cmd{Argv: []string{"go", "test"}}); err != nil || strconv.Itoa(res.ExitCode) != code {
+			t.Errorf("exit %s: Exec() = %+v, %v; the command's own exit codes stay results", code, res, err)
+		}
+	}
+}
+
+// Backlog B-016: a probe podman or timeout could not run does not show the network closed.
+func TestUpRefusesAProbeThatCouldNotRun(t *testing.T) {
+	d, log, sp := fakeEngine(t)
+	t.Setenv("STUB_PROBE_EXIT", "125")
+	_, err := d.Up(context.Background(), sp)
+	if err == nil || !strings.Contains(err.Error(), "couldn't run") {
+		t.Fatalf("Up() = %v, want a refusal: the closed-network check could not run", err)
+	}
+	if !strings.Contains(logOf(t, log), "podman rm -f -t 2 --depend work123 fw456") {
+		t.Error("a sandbox that failed its check was left running")
+	}
+	t.Setenv("STUB_PROBE_EXIT", "124") // timeout's own status for a connect that was dropped: closed
+	if _, err := d.Up(context.Background(), sp); err != nil {
+		t.Errorf("a connect that timed out must show the network closed: %v", err)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestExecReportsAMissingContainerAsAnError (0.02s)
    driver_test.go:373: Exec() = {ExitCode:125}, <nil>; want an error and no exit code
--- FAIL: TestUpRefusesAProbeThatCouldNotRun (0.01s)
    driver_test.go:389: Up() = <nil>, want a refusal: the closed-network check could not run
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/driver.go`:

```diff
diff --git a/sandbox/driver.go b/sandbox/driver.go
index c688968..9cd51ae 100644
--- a/sandbox/driver.go
+++ b/sandbox/driver.go
@@ -226,11 +226,20 @@ func (d *Driver) Exec(ctx context.Context, env gungnir.Env, c gungnir.Cmd) (gung
 	}
 	var ee *exec.ExitError
 	if errors.As(err, &ee) {
+		if ee.ExitCode() == podmanFailed {
+			return gungnir.ExecResult{}, fmt.Errorf("podman couldn't run %s in the sandbox (exit %d): the container may be gone", c.Argv[0], podmanFailed)
+		}
 		return gungnir.ExecResult{ExitCode: ee.ExitCode()}, nil
 	}
 	return gungnir.ExecResult{}, err
 }
 
+// podmanFailed is the exit status podman exec returns when podman itself failed, such as for a
+// container that is gone. It is not the command's: an infrastructure failure must not read as a check
+// or a node that failed (spec §12; backlog B-016, B-017). A command that exits 125 on its own reads the
+// same way, which is a cost worth paying.
+const podmanFailed = 125
+
 func sortedEnv(m map[string]string) []string {
 	ks := make([]string, 0, len(m))
 	for k := range m {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T113: the driver: `Down` gives up on a hung engine

Backlog B-028. `Down` runs when a run ends, under a context that can't be cancelled, so an engine that
hangs hung `ygg` with it.

**Files (in `gleipnir`):**

- Modify: `sandbox/driver.go`, `sandbox/driver_test.go`

**Interfaces:**

- Produces: `Driver.DownTimeout time.Duration` (two minutes by default). `Down` ends, with an error, when
  the engine has not answered by then; the sandbox stays recorded in `run.json` and `ygg doctor` finds it.

**Acceptance criteria:**

- [ ] With a podman that sleeps for 30 seconds and a timeout of 300 ms, `Down` returns an error within a
      few seconds.

**Named test:** `go test ./sandbox -run TestDownGivesUpOnAHungEngine` in `gleipnir`. **Layer:**
`gleipnir`. **Size:** S (23). **Depends on:** v0-T112.

- [ ] **Step 1:** write the tests.

Apply to `sandbox/driver_test.go`:

```diff
diff --git a/sandbox/driver_test.go b/sandbox/driver_test.go
index b7948a5..05b326f 100644
--- a/sandbox/driver_test.go
+++ b/sandbox/driver_test.go
@@ -35,7 +35,8 @@ echo "env host=${CONTAINER_HOST:-} auth=${REGISTRY_AUTH_FILE:-} docker=${DOCKER_
 case "$1" in
   image) case " $STUB_MISSING " in *" $3 "*) exit 1 ;; esac; exit 0 ;;
   network) [ "$2" = exists ] && exit 0; exit 0 ;;
-  ps) case "$*" in *service=fw*) echo fw456 ;; *) echo work123; echo fw456 ;; esac; exit 0 ;;
+  ps) [ -z "$STUB_PS_SLEEP" ] || exec sleep "$STUB_PS_SLEEP"
+    case "$*" in *service=fw*) echo fw456 ;; *) echo work123; echo fw456 ;; esac; exit 0 ;;
   exec)
     case "$*" in
       *"test -f /run/ygg-fw/ready"*) exit "${STUB_READY_EXIT:-0}" ;;
@@ -396,3 +397,15 @@ func TestUpRefusesAProbeThatCouldNotRun(t *testing.T) {
 		t.Errorf("a connect that timed out must show the network closed: %v", err)
 	}
 }
+
+// Backlog B-028: a hung engine must not hang Down.
+func TestDownGivesUpOnAHungEngine(t *testing.T) {
+	d, _, sp := fakeEngine(t)
+	d.DownTimeout = 300 * time.Millisecond
+	t.Setenv("STUB_PS_SLEEP", "30")
+	began := time.Now()
+	err := d.Down(context.WithoutCancel(context.Background()), gungnir.Env{Project: Project(sp), Container: "work123"})
+	if err == nil || time.Since(began) > 10*time.Second {
+		t.Errorf("Down() = %v after %v; want an error, promptly", err, time.Since(began))
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gleipnir/sandbox [github.com/ouroboric-dev/gleipnir/sandbox.test]
sandbox/driver_test.go:404:4: d.DownTimeout undefined (type *Driver has no field or method DownTimeout)
FAIL	github.com/ouroboric-dev/gleipnir/sandbox [build failed]
FAIL
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/driver.go`:

```diff
diff --git a/sandbox/driver.go b/sandbox/driver.go
index 9cd51ae..f2e594c 100644
--- a/sandbox/driver.go
+++ b/sandbox/driver.go
@@ -26,6 +26,7 @@ type Driver struct {
 	Compose      string        // the compose provider; "podman-compose" by default
 	ReadyTimeout time.Duration // how long Up waits for the firewall; a minute by default
 	UpTimeout    time.Duration // how long devcontainer up may take; five minutes by default (a first start hung for eight in the spike)
+	DownTimeout  time.Duration // how long Down may take; two minutes by default
 
 	cfg    Config
 	engine string
@@ -54,7 +55,7 @@ func New(socket string, cfg Config, work string) (*Driver, error) {
 	if err := os.WriteFile(filepath.Join(auth, "auth.json"), []byte("{}\n"), 0o600); err != nil {
 		return nil, err
 	}
-	return &Driver{Podman: "podman", Devcontainer: "devcontainer", Compose: "podman-compose", ReadyTimeout: time.Minute, UpTimeout: 5 * time.Minute,
+	return &Driver{Podman: "podman", Devcontainer: "devcontainer", Compose: "podman-compose", ReadyTimeout: time.Minute, UpTimeout: 5 * time.Minute, DownTimeout: 2 * time.Minute,
 		cfg: cfg, engine: socket, work: work, auth: auth}, nil
 }
 
@@ -302,6 +303,13 @@ func (d *Driver) Down(ctx context.Context, env gungnir.Env) error {
 	if env.Project == "" {
 		return errors.New("no sandbox project to stop")
 	}
+	// Down runs when a run ends, with its own context: an engine that hangs must not hang ygg with it
+	// (backlog B-028). What it couldn't remove stays recorded in run.json, and ygg doctor finds it.
+	if d.DownTimeout > 0 {
+		var cancel context.CancelFunc
+		ctx, cancel = context.WithTimeout(ctx, d.DownTimeout)
+		defer cancel()
+	}
 	ids, err := d.run(ctx, d.Podman, "ps", "-a", "-q", "--filter", "label=com.docker.compose.project="+env.Project)
 	if err != nil {
 		return err
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T114: the check runner

Spec §2.1: Gleipnir runs checks. A check is one command in a leaf's sandbox, read as a pass, a fail
or a timeout; a failing one becomes a typed finding for the loop (spec §4.6, decision 12).

**Files (in `gleipnir`):**

- Create: `checks/checks.go`, `checks/checks_test.go`

**Interfaces:**

- Consumes: `gungnir.Runner`, `bounded` (v0-T108).
- Produces: `checks.Spec{Name string; Argv []string; Timeout time.Duration}`;
  `checks.Result{Name; Passed bool; ExitCode int; TimedOut bool; Tail, Log string; Duration time.Duration}`;
  `checks.Run(ctx, runner gungnir.Runner, s Spec, logPath string) (Result, error)`, which writes the
  command's whole output to `logPath` (at most `checks.MaxLog`, 8 MiB) and keeps its last
  `checks.TailBytes` (3,000) bytes, cut at a character. A command that exits non-zero, or runs past its
  timeout, is a result. An error means the check could not be judged: the runner failed, the log could not
  be written, the timeout is zero, or the context ended (then it is the context's error).
- Produces: `(Result).Finding(location string) (gungnir.Finding, bool)`: for a result that did not pass,
  a finding `check-<name>` (`checks.FindingID(name)`, stable across attempts), source the check's name,
  severity blocker, status open, whose claim is `check <name> failed: exit status N` (or `it timed out`)
  and the end of the output. A check that passed has none.

**Acceptance criteria:**

- [ ] A passing check has no finding and its log holds its output.
- [ ] A failing check's finding is valid, has the stable id and the end of the output, and is the same
      finding on the next attempt.
- [ ] A check past its timeout is a failed check; a runner that fails, a cancelled context, a missing
      timeout and a log that can't be written are errors.
- [ ] The log is bounded and the tail never cuts a character.

**Named test:** `go test ./checks` in `gleipnir`. **Layer:** `gleipnir`. **Size:** M (264).
**Depends on:** v0-T113.

- [ ] **Step 1:** write the tests.

Write `checks/checks_test.go`:

```go
package checks

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

type runner struct {
	out  string
	exit int
	err  error
	hang bool
	got  gungnir.Cmd
}

func (r *runner) Run(ctx context.Context, c gungnir.Cmd) (gungnir.ExecResult, error) {
	r.got = c
	if r.hang {
		<-ctx.Done()
		return gungnir.ExecResult{}, ctx.Err()
	}
	c.Stdout.Write([]byte(r.out))
	return gungnir.ExecResult{ExitCode: r.exit}, r.err
}

func spec() Spec {
	return Spec{Name: "test", Argv: []string{"go", "test", "./..."}, Timeout: time.Minute}
}

func TestAPassingCheckHasNoFinding(t *testing.T) {
	log := filepath.Join(t.TempDir(), "logs", "build-1-test.log")
	r, err := Run(context.Background(), &runner{out: "ok  \tpkg\t0.1s\n"}, spec(), log)
	if err != nil || !r.Passed || r.ExitCode != 0 || r.TimedOut || r.Log != log {
		t.Fatalf("Run() = %+v, %v", r, err)
	}
	if b, _ := os.ReadFile(log); string(b) != "ok  \tpkg\t0.1s\n" {
		t.Errorf("the log = %q", b)
	}
	if f, ok := r.Finding("logs/build-1-test.log:1"); ok {
		t.Errorf("a passing check reported %+v", f)
	}
}

func TestAFailingCheckReportsAStableFindingWithTheEndOfItsOutput(t *testing.T) {
	out := strings.Repeat("noise line\n", 1000) + "--- FAIL: TestThrottle (0.00s)\n    auth_test.go:42: want 429, got 200\nFAIL\n"
	r, err := Run(context.Background(), &runner{out: out, exit: 1}, spec(), filepath.Join(t.TempDir(), "t.log"))
	if err != nil || r.Passed || r.ExitCode != 1 {
		t.Fatalf("Run() = %+v, %v; a failing check is a result, not an error", r, err)
	}
	f, ok := r.Finding("logs/build-1-test.log:1")
	if !ok {
		t.Fatal("a failing check has no finding")
	}
	if err := f.Validate(); err != nil {
		t.Errorf("the finding is not a valid finding: %v", err)
	}
	if f.ID != "check-test" || f.ID != FindingID("test") || f.Source != "test" || f.Severity != gungnir.SeverityBlocker || f.Status != gungnir.FindingOpen {
		t.Errorf("finding = %+v", f)
	}
	if !strings.Contains(f.Claim, "exit status 1") || !strings.Contains(f.Claim, "want 429, got 200") || len(f.Claim) > TailBytes+200 {
		t.Errorf("the claim is %d bytes: %q", len(f.Claim), f.Claim)
	}
	// The same failure on the next attempt keeps its id: the finding is the same problem.
	r2, _ := Run(context.Background(), &runner{out: "different output\n", exit: 2}, spec(), filepath.Join(t.TempDir(), "t.log"))
	if f2, _ := r2.Finding("logs/build-2-test.log:1"); f2.ID != f.ID {
		t.Errorf("ids differ between attempts: %q and %q", f.ID, f2.ID)
	}
}

func TestACheckThatRunsTooLongIsAFailedCheck(t *testing.T) {
	s := spec()
	s.Timeout = 100 * time.Millisecond
	r, err := Run(context.Background(), &runner{hang: true}, s, filepath.Join(t.TempDir(), "t.log"))
	if err != nil || r.Passed || !r.TimedOut {
		t.Fatalf("Run() = %+v, %v; want a timed-out result", r, err)
	}
	if f, ok := r.Finding("t.log:1"); !ok || !strings.Contains(f.Claim, "timed out") {
		t.Errorf("finding = %+v, %v", f, ok)
	}
}

func TestARunnerThatFailsIsAnErrorNeverAFailedCheck(t *testing.T) {
	if r, err := Run(context.Background(), &runner{err: errors.New("podman couldn't run go")}, spec(), filepath.Join(t.TempDir(), "t.log")); err == nil {
		t.Errorf("Run() = %+v, nil; the sandbox failing is not the check failing", r)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := Run(ctx, &runner{hang: true}, spec(), filepath.Join(t.TempDir(), "t.log")); !errors.Is(err, context.Canceled) {
		t.Errorf("a cancelled context: Run() = %v, want context.Canceled", err)
	}
	s := spec()
	s.Timeout = 0
	if _, err := Run(context.Background(), &runner{}, s, filepath.Join(t.TempDir(), "t.log")); err == nil {
		t.Error("a check with no timeout ran")
	}
	if _, err := Run(context.Background(), &runner{}, spec(), filepath.Join(t.TempDir(), "log-is-a-dir", "x", "..", "..")); err == nil {
		t.Error("a log that can't be written was ignored")
	}
}

func TestTheLogIsBoundedAndTheTailKeepsWholeCharacters(t *testing.T) {
	r, err := Run(context.Background(), &runner{out: strings.Repeat("é", TailBytes), exit: 1}, spec(), filepath.Join(t.TempDir(), "t.log"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(r.Tail, "é") || len(r.Tail) > TailBytes {
		t.Errorf("the tail starts %q and is %d bytes", r.Tail[:4], len(r.Tail))
	}
	big := strings.Repeat("x", 100)
	r, err = Run(context.Background(), &bigRunner{n: MaxLog/100 + 50, line: big}, spec(), filepath.Join(t.TempDir(), "t.log"))
	if err != nil {
		t.Fatal(err)
	}
	if fi, _ := os.Stat(r.Log); fi.Size() > MaxLog {
		t.Errorf("the log is %d bytes, over the bound %d", fi.Size(), MaxLog)
	}
}

type bigRunner struct {
	n    int
	line string
}

func (b *bigRunner) Run(_ context.Context, c gungnir.Cmd) (gungnir.ExecResult, error) {
	for i := 0; i < b.n; i++ {
		c.Stdout.Write([]byte(b.line))
	}
	return gungnir.ExecResult{}, nil
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gleipnir/checks [github.com/ouroboric-dev/gleipnir/checks.test]
checks/checks_test.go:33:13: undefined: Spec
checks/checks_test.go:34:9: undefined: Spec
checks/checks_test.go:39:12: undefined: Run
```

- [ ] **Step 3:** write the code.

Write `checks/checks.go`:

```go
// Package checks runs a realm's checks (spec §2.1, §9.5): one command in a leaf's sandbox, with its
// output kept in a log and its end read as a pass, a fail or a timeout. A check that fails is a result
// and feeds a typed finding to the loop; an error is the runner's own (the sandbox, the log file), which
// is never a failed check (spec §12).
package checks

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/ouroboric-dev/gleipnir/bounded"
	"github.com/ouroboric-dev/gungnir"
)

const (
	// MaxLog is the most bytes of a check's output the log keeps.
	MaxLog = 8 << 20
	// TailBytes is how much of the end of a check's output a finding carries.
	TailBytes = 3000
)

// Spec is one check to run.
type Spec struct {
	Name    string
	Argv    []string // the command, without a shell
	Timeout time.Duration
}

// Result is how a check ended.
type Result struct {
	Name     string
	Passed   bool
	ExitCode int
	TimedOut bool
	Tail     string // the last TailBytes of the output
	Log      string // the log file: the whole output, up to MaxLog bytes
	Duration time.Duration
}

// Run runs s through runner and writes its output to logPath. A command that exits non-zero, or runs
// past its timeout, is a Result that did not pass. An error means the check could not be judged: the
// runner failed, the log could not be written, or ctx ended.
func Run(ctx context.Context, runner gungnir.Runner, s Spec, logPath string) (Result, error) {
	if s.Timeout <= 0 {
		return Result{}, fmt.Errorf("check %s has no timeout", s.Name)
	}
	if err := os.MkdirAll(filepath.Dir(logPath), 0o755); err != nil {
		return Result{}, err
	}
	f, err := os.Create(logPath)
	if err != nil {
		return Result{}, err
	}
	defer f.Close()
	log := bounded.NewWriter(f, MaxLog)
	tail := &tailWriter{max: TailBytes}
	out := io.MultiWriter(log, tail)
	cctx, cancel := context.WithTimeout(ctx, s.Timeout)
	defer cancel()
	began := time.Now()
	res, err := runner.Run(cctx, gungnir.Cmd{Argv: s.Argv, Stdout: out, Stderr: out})
	r := Result{Name: s.Name, Log: logPath, Duration: time.Since(began), Tail: tail.String()}
	switch {
	case err != nil && ctx.Err() != nil:
		return Result{}, ctx.Err()
	case err != nil && errors.Is(cctx.Err(), context.DeadlineExceeded):
		r.TimedOut = true
		return r, log.Err()
	case err != nil:
		return Result{}, err
	}
	r.ExitCode, r.Passed = res.ExitCode, res.ExitCode == 0
	return r, log.Err()
}

// Finding is the finding a check that did not pass reports (spec §4.6). Its id is stable across
// attempts, so the same failing check keeps the same finding; location is where the loop can read the
// output (a file and a line). A check that passed has no finding.
func (r Result) Finding(location string) (gungnir.Finding, bool) {
	if r.Passed {
		return gungnir.Finding{}, false
	}
	why := fmt.Sprintf("exit status %d", r.ExitCode)
	if r.TimedOut {
		why = "it timed out"
	}
	claim := fmt.Sprintf("check %s failed: %s", r.Name, why)
	if t := strings.TrimSpace(r.Tail); t != "" {
		claim += "\nthe end of its output:\n" + t
	}
	return gungnir.Finding{ID: FindingID(r.Name), Source: r.Name, Severity: gungnir.SeverityBlocker,
		Location: location, Claim: claim, Status: gungnir.FindingOpen}, true
}

// FindingID is the id of the finding a failing check of this name reports.
func FindingID(check string) string { return "check-" + check }

// tailWriter keeps the last max bytes written to it, cut at a character boundary.
type tailWriter struct {
	max int
	buf []byte
}

func (w *tailWriter) Write(p []byte) (int, error) {
	w.buf = append(w.buf, p...)
	if len(w.buf) > 2*w.max { // trim in bigger steps than one write, so a chatty check costs little
		w.buf = append([]byte(nil), w.buf[len(w.buf)-w.max:]...)
	}
	return len(p), nil
}

func (w *tailWriter) String() string {
	b := w.buf
	if len(b) > w.max {
		b = b[len(b)-w.max:]
	}
	for len(b) > 0 && !utf8.RuneStart(b[0]) {
		b = b[1:]
	}
	return string(b)
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T115: scripted: the turns a session was given

Odin bounds a session's turns by what the caps allow (decision 6); a test needs to see what the
session was given.

**Files (in `gleipnir`):**

- Modify: `scripted/scripted.go`, `scripted/scripted_test.go`

**Interfaces:**

- Changes: the scripted transcript, `<node>-<attempt>.json`, gains `max_turns`.

**Acceptance criteria:**

- [ ] The transcript of a session given 7 turns records 7.

**Named test:** `go test ./scripted -run TestTheTranscriptRecordsWhatTheSessionWasGiven` in `gleipnir`.
**Layer:** `gleipnir`. **Size:** S (19). **Depends on:** v0-T111.

- [ ] **Step 1:** write the tests.

Apply to `scripted/scripted_test.go`:

```diff
diff --git a/scripted/scripted_test.go b/scripted/scripted_test.go
index d1763a0..d076719 100644
--- a/scripted/scripted_test.go
+++ b/scripted/scripted_test.go
@@ -2,6 +2,7 @@ package scripted
 
 import (
 	"context"
+	"encoding/json"
 	"errors"
 	"os"
 	"path/filepath"
@@ -298,3 +299,20 @@ func TestScriptedRefusesAScriptThatNamesNoSuchFailure(t *testing.T) {
 		}
 	}
 }
+
+func TestTheTranscriptRecordsWhatTheSessionWasGiven(t *testing.T) {
+	a := load(t, "steps:\n  build:\n    - result: { status: ok }\n")
+	dir := t.TempDir()
+	r, err := a.Run(context.Background(), gungnir.Task{Node: "build", Attempt: 1, Workdir: t.TempDir(), TranscriptDir: dir, Prompt: "Build it.", MaxTurns: 7})
+	if err != nil {
+		t.Fatal(err)
+	}
+	b, _ := os.ReadFile(r.TranscriptPath)
+	var got struct {
+		Prompt   string `json:"prompt"`
+		MaxTurns int    `json:"max_turns"`
+	}
+	if err := json.Unmarshal(b, &got); err != nil || got.Prompt != "Build it." || got.MaxTurns != 7 {
+		t.Errorf("the transcript = %s, %v", b, err)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTheTranscriptRecordsWhatTheSessionWasGiven (0.00s)
    scripted_test.go:316: the transcript = {
          "attempt": 1,
          "model": "",
```

- [ ] **Step 3:** write the code.

Apply to `scripted/scripted.go`:

```diff
diff --git a/scripted/scripted.go b/scripted/scripted.go
index 050d8d2..c5271ab 100644
--- a/scripted/scripted.go
+++ b/scripted/scripted.go
@@ -286,7 +286,7 @@ func writeTranscript(t gungnir.Task) (string, error) {
 		return "", err
 	}
 	data, err := json.MarshalIndent(map[string]any{
-		"role": t.Role, "node": t.Node, "attempt": t.Attempt, "model": t.Model, "prompt": t.Prompt,
+		"role": t.Role, "node": t.Node, "attempt": t.Attempt, "model": t.Model, "prompt": t.Prompt, "max_turns": t.MaxTurns,
 	}, "", "  ")
 	if err != nil {
 		return "", err
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T116: scripted: whether a session was read-only

A test of the loop needs to see that a reviewer ran read-only and the implementer did not.

**Files (in `gleipnir`):**

- Modify: `scripted/scripted.go`, `scripted/scripted_test.go`

**Interfaces:**

- Changes: the scripted transcript gains `read_only`.

**Acceptance criteria:**

- [ ] The transcript of a read-only session records `read_only: true`.

**Named test:** `go test ./scripted -run TestTheTranscriptRecordsWhatTheSessionWasGiven` in `gleipnir`.
**Layer:** `gleipnir`. **Size:** S (4). **Depends on:** v0-T115.

- [ ] **Step 1:** write the tests.

Apply to `scripted/scripted_test.go`:

```diff
diff --git a/scripted/scripted_test.go b/scripted/scripted_test.go
index d076719..7d03caf 100644
--- a/scripted/scripted_test.go
+++ b/scripted/scripted_test.go
@@ -303,7 +303,7 @@ func TestScriptedRefusesAScriptThatNamesNoSuchFailure(t *testing.T) {
 func TestTheTranscriptRecordsWhatTheSessionWasGiven(t *testing.T) {
 	a := load(t, "steps:\n  build:\n    - result: { status: ok }\n")
 	dir := t.TempDir()
-	r, err := a.Run(context.Background(), gungnir.Task{Node: "build", Attempt: 1, Workdir: t.TempDir(), TranscriptDir: dir, Prompt: "Build it.", MaxTurns: 7})
+	r, err := a.Run(context.Background(), gungnir.Task{Node: "build", Attempt: 1, Workdir: t.TempDir(), TranscriptDir: dir, Prompt: "Build it.", MaxTurns: 7, ReadOnly: true})
 	if err != nil {
 		t.Fatal(err)
 	}
@@ -311,8 +311,9 @@ func TestTheTranscriptRecordsWhatTheSessionWasGiven(t *testing.T) {
 	var got struct {
 		Prompt   string `json:"prompt"`
 		MaxTurns int    `json:"max_turns"`
+		ReadOnly bool   `json:"read_only"`
 	}
-	if err := json.Unmarshal(b, &got); err != nil || got.Prompt != "Build it." || got.MaxTurns != 7 {
+	if err := json.Unmarshal(b, &got); err != nil || got.Prompt != "Build it." || got.MaxTurns != 7 || !got.ReadOnly {
 		t.Errorf("the transcript = %s, %v", b, err)
 	}
 }
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTheTranscriptRecordsWhatTheSessionWasGiven (0.00s)
    scripted_test.go:317: the transcript = {
          "attempt": 1,
          "max_turns": 7,
```

- [ ] **Step 3:** write the code.

Apply to `scripted/scripted.go`:

```diff
diff --git a/scripted/scripted.go b/scripted/scripted.go
index c5271ab..2cfe575 100644
--- a/scripted/scripted.go
+++ b/scripted/scripted.go
@@ -286,7 +286,7 @@ func writeTranscript(t gungnir.Task) (string, error) {
 		return "", err
 	}
 	data, err := json.MarshalIndent(map[string]any{
-		"role": t.Role, "node": t.Node, "attempt": t.Attempt, "model": t.Model, "prompt": t.Prompt, "max_turns": t.MaxTurns,
+		"role": t.Role, "node": t.Node, "attempt": t.Attempt, "model": t.Model, "prompt": t.Prompt, "max_turns": t.MaxTurns, "read_only": t.ReadOnly,
 	}, "", "  ")
 	if err != nil {
 		return "", err
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

When `gleipnir`'s last task is committed, push and open its pull request (see "How each task lands").
It needs `gungnir`'s merged and pinned, and nothing of Jormungandr's.

---

### Task v0-T117: the loop's outcomes, and how a session's end is classified

Jormungandr's first code. Its `go.mod` has no code yet: this task is its first file, and gives it what
every later task returns or reads. Branch `loop/core` from `main` in `jormungandr`, before step 1, once
`gungnir`'s pull request is merged and pinned (see "How each task lands"). Jormungandr depends on
Gungnir alone.

**Files (in `jormungandr`):**

- Create: `jormungandr.go`, `jormungandr_test.go`

**Interfaces:**

- Consumes: `gungnir.Result`, `gungnir.FailureOf`, `gungnir.FailureKind`, `gungnir.CapError` (v0-T097,
  v0-T098).
- Produces: `jormungandr.Classify(res gungnir.Result, err error) (kind gungnir.FailureKind, why string)`:
  an empty kind for a session that succeeded; otherwise how it failed, from the error's kind
  (`FailureOf`) or the failed result's `Failure` (agent when empty), and the text it gave. A plain error
  is an agent failure.
- Produces: `*QuotaError{Reason}` (the provider's quota is used up: the run pauses), `*ExhaustedError{Tries
  int; Last string}` (transient failures outlasted their retries), `*AgentFailure{Reason}` (a session
  that failed as an agent does: a loop attempt), `IsCap(err) (*gungnir.CapError, bool)`.

**Acceptance criteria:**

- [ ] `Classify` reads a success, a failed result with and without a kind, a plain error, and wrapped
      infra and transient errors.
- [ ] Each outcome's message says what happened; `IsCap` finds a cap through wrapping.

**Named test:** `go test . -run 'TestClassifyReadsTheEndOfASession|TestTheOutcomesSayWhatHappened'` in
`jormungandr`. **Layer:** `jormungandr`. **Size:** M (114). **Depends on:** v0-T097 merged.

- [ ] **Step 1:** write the tests.

Write `jormungandr_test.go`:

```go
package jormungandr

import (
	"errors"
	"fmt"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func TestClassifyReadsTheEndOfASession(t *testing.T) {
	cases := []struct {
		name string
		res  gungnir.Result
		err  error
		want gungnir.FailureKind
		why  string
	}{
		{"a success", gungnir.Result{Status: gungnir.StatusOK, Summary: "done"}, nil, "", ""},
		{"a failed result with no kind", gungnir.Result{Status: gungnir.StatusFailed, Summary: "tests fail"}, nil, gungnir.FailureAgent, "tests fail"},
		{"a transient result", gungnir.Result{Status: gungnir.StatusFailed, Summary: "429", Failure: gungnir.FailureTransient}, nil, gungnir.FailureTransient, "429"},
		{"a quota result", gungnir.Result{Status: gungnir.StatusFailed, Summary: "no credits", Failure: gungnir.FailureQuota}, nil, gungnir.FailureQuota, "no credits"},
		{"a plain error", gungnir.Result{}, errors.New("exit 1"), gungnir.FailureAgent, "exit 1"},
		{"an infra error", gungnir.Result{}, fmt.Errorf("wrapped: %w", &gungnir.SessionError{Kind: gungnir.FailureInfra, Err: errors.New("podman")}), gungnir.FailureInfra, "wrapped: podman"},
		{"a transient error", gungnir.Result{}, &gungnir.SessionError{Kind: gungnir.FailureTransient, Err: errors.New("crash at start")}, gungnir.FailureTransient, "crash at start"},
	}
	for _, c := range cases {
		kind, why := Classify(c.res, c.err)
		if kind != c.want || why != c.why {
			t.Errorf("%s: Classify() = %q, %q; want %q, %q", c.name, kind, why, c.want, c.why)
		}
	}
}

func TestTheOutcomesSayWhatHappened(t *testing.T) {
	for err, want := range map[error]string{
		&QuotaError{Reason: "credits used up"}:         "quota is used up: credits used up",
		&ExhaustedError{Tries: 4, Last: "HTTP 429"}:    "4 times in a row",
		&AgentFailure{Reason: "timed out after 20m0s"}: "the agent failed: timed out",
	} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("%T: Error() = %q, want it to contain %q", err, err.Error(), want)
		}
	}
	c := &gungnir.CapError{Scope: gungnir.CapRun, Dimension: gungnir.CapTurns, Used: 10, Limit: 10}
	if got, ok := IsCap(fmt.Errorf("wrapped: %w", c)); !ok || got != c {
		t.Errorf("IsCap() = %v, %v", got, ok)
	}
	if _, ok := IsCap(errors.New("x")); ok {
		t.Error("IsCap() = true for a plain error")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/jormungandr [github.com/ouroboric-dev/jormungandr.test]
./jormungandr_test.go:29:16: undefined: Classify
./jormungandr_test.go:38:4: undefined: QuotaError
./jormungandr_test.go:39:4: undefined: ExhaustedError
```

- [ ] **Step 3:** write the code.

Write `jormungandr.go`:

```go
// Package jormungandr runs Yggdrasil's bounded loop (spec §2.1, §4.2, §4.6, §7.3, §12): an
// implementer works, a ladder of checks and read-only reviewers judges the work, the findings that are
// still open go back to the next attempt, and after a fixed number of attempts the loop escalates. It
// also holds the retry policy for a session that fails for a reason that is not the agent's. It does
// none of the work itself: Odin gives it the steps (a session, a check, a ledger line), and it decides
// what comes next. It depends on Gungnir alone.
package jormungandr

import (
	"errors"
	"fmt"

	"github.com/ouroboric-dev/gungnir"
)

// QuotaError is a provider quota or credit balance that is used up. The run pauses, resumable, and
// says why (spec §12).
type QuotaError struct{ Reason string }

func (e *QuotaError) Error() string { return "the provider's quota is used up: " + e.Reason }

// ExhaustedError is a transient failure that outlasted its retries. Nothing in the work is wrong: the
// run stops failed, and a resume tries again. It is not a loop attempt (spec §12).
type ExhaustedError struct {
	Tries int
	Last  string // why the last try failed
}

func (e *ExhaustedError) Error() string {
	return fmt.Sprintf("the session failed %d times in a row for a reason that is not the agent's, the last time with: %s", e.Tries, e.Last)
}

// AgentFailure is a session that failed as an agent does: a non-zero exit, a timeout, a turn limit,
// or output that can't be used. It counts as a loop attempt (spec §12).
type AgentFailure struct{ Reason string }

func (e *AgentFailure) Error() string { return "the agent failed: " + e.Reason }

// Classify says how the end of one session went. kind is empty for a session that succeeded; otherwise
// it is how the session failed, and why is what it said. A failed result with no kind failed as an
// agent does, as does any error that is not a *gungnir.SessionError: the safe reading of an unknown
// failure is the one that counts against the loop's attempts.
func Classify(res gungnir.Result, err error) (kind gungnir.FailureKind, why string) {
	switch {
	case err != nil:
		return gungnir.FailureOf(err), err.Error()
	case res.Status == gungnir.StatusFailed:
		kind = res.Failure
		if kind == "" {
			kind = gungnir.FailureAgent
		}
		return kind, res.Summary
	}
	return "", ""
}

// IsCap reports whether err is a budget cap that is reached, and returns it.
func IsCap(err error) (*gungnir.CapError, bool) {
	var c *gungnir.CapError
	return c, errors.As(err, &c)
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T118: retries with a backoff for a failure that is not the agent's

Spec §12: a transient failure is retried with a backoff, up to three times, and is not a loop attempt; a
used-up quota pauses the run; an infrastructure failure stops it with no retry loop; the budget is asked
before every try (spec §7.4).

**Files (in `jormungandr`):**

- Create: `retry.go`, `retry_test.go`

**Interfaces:**

- Produces: `jormungandr.Backoff{Base, Max time.Duration; Retries int}`, with `Delay(n int)` (the wait
  before retry `n` from 1: `Base`, twice, four times, never over `Max`); `jormungandr.DefaultBackoff`
  (5 s, a minute at most, 3 retries).
- Produces: `jormungandr.Try`, `func(ctx, n int) (gungnir.Result, error)`, which runs the session once
  and must count what it spent, failed or not; and `jormungandr.Retrier{Backoff; Meter gungnir.Meter;
  Sleep func(ctx, d) error; OnRetry func(try int, wait time.Duration, why string) error}` with
  `Do(ctx, try Try) (gungnir.Result, error)`. `Do` returns the result and nil for a success; a
  `*gungnir.CapError` when the meter says a cap is reached, before any try; a `*QuotaError`; an
  `*ExhaustedError` after `Retries+1` transient failures; an `*AgentFailure` for anything else that is the
  agent's; the session's own error for infra; the context's error when it ends. `OnRetry` runs before each
  wait, and an error from it stops the retries. `Sleep` is a timer unless a test replaces it.

**Acceptance criteria:**

- [ ] A transient failure is retried after a doubling wait, the failed tries are told to `OnRetry`, and the
      third try succeeds.
- [ ] Transient failures that never end stop after four tries and three waits.
- [ ] An agent error, a failed result, a used-up quota and an infrastructure error are tried once and not
      waited for.
- [ ] No try starts over a cap, the first or a retry; a cancelled context is the context's error, and the
      wait ends with it; a failing `OnRetry` stops the retries.

**Named test:** `go test . -run 'TestBackoff|TestATransientFailure|TestTransientFailures|TestOtherFailures|TestNoTryStarts|TestACancelledRun|TestAFailingOnRetry'`
in `jormungandr`. **Layer:** `jormungandr`. **Size:** M (264). **Depends on:** v0-T117.

- [ ] **Step 1:** write the tests.

Write `retry_test.go`:

```go
package jormungandr

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

func TestBackoffDoublesUpToItsMaximum(t *testing.T) {
	b := Backoff{Base: 5 * time.Second, Max: 12 * time.Second, Retries: 3}
	for n, want := range map[int]time.Duration{1: 5 * time.Second, 2: 10 * time.Second, 3: 12 * time.Second, 9: 12 * time.Second} {
		if got := b.Delay(n); got != want {
			t.Errorf("Delay(%d) = %v, want %v", n, got, want)
		}
	}
	if DefaultBackoff.Retries != 3 || DefaultBackoff.Delay(1) != 5*time.Second || DefaultBackoff.Delay(3) != 20*time.Second {
		t.Errorf("DefaultBackoff = %+v", DefaultBackoff)
	}
}

type script struct {
	steps []func() (gungnir.Result, error)
	calls int
}

func (s *script) try(_ context.Context, n int) (gungnir.Result, error) {
	s.calls++
	if n != s.calls {
		panic("the try number must count from 1")
	}
	return s.steps[min(n, len(s.steps))-1]()
}

func ok() (gungnir.Result, error) { return gungnir.Result{Status: gungnir.StatusOK}, nil }
func transient() (gungnir.Result, error) {
	return gungnir.Result{}, &gungnir.SessionError{Kind: gungnir.FailureTransient, Err: errors.New("HTTP 429")}
}

type slept struct{ waits []time.Duration }

func (s *slept) sleep(_ context.Context, d time.Duration) error {
	s.waits = append(s.waits, d)
	return nil
}

func retrier(s *slept) Retrier {
	return Retrier{Backoff: Backoff{Base: time.Second, Max: time.Minute, Retries: 3}, Sleep: s.sleep}
}

func TestATransientFailureIsRetriedWithABackoffAndIsNotAnAttempt(t *testing.T) {
	sl := &slept{}
	sc := &script{steps: []func() (gungnir.Result, error){transient, transient, ok}}
	var told []string
	r := retrier(sl)
	r.OnRetry = func(try int, wait time.Duration, why string) error { told = append(told, why); return nil }
	res, err := r.Do(context.Background(), sc.try)
	if err != nil || res.Status != gungnir.StatusOK || sc.calls != 3 {
		t.Fatalf("Do() = %+v, %v after %d tries; want a success on the third", res, err, sc.calls)
	}
	if len(sl.waits) != 2 || sl.waits[0] != time.Second || sl.waits[1] != 2*time.Second || len(told) != 2 || told[0] != "HTTP 429" {
		t.Errorf("waits %v, told %v", sl.waits, told)
	}
}

func TestTransientFailuresStopAfterTheRetriesAreUsed(t *testing.T) {
	sl := &slept{}
	sc := &script{steps: []func() (gungnir.Result, error){transient}}
	_, err := retrier(sl).Do(context.Background(), sc.try)
	var ex *ExhaustedError
	if !errors.As(err, &ex) || ex.Tries != 4 || sc.calls != 4 || len(sl.waits) != 3 {
		t.Errorf("Do() = %v after %d tries and %d waits; want an ExhaustedError after 4 tries and 3 waits", err, sc.calls, len(sl.waits))
	}
}

func TestOtherFailuresAreNotRetried(t *testing.T) {
	agentErr := func() (gungnir.Result, error) { return gungnir.Result{}, errors.New("exit 1") }
	agentRes := func() (gungnir.Result, error) {
		return gungnir.Result{Status: gungnir.StatusFailed, Summary: "tests fail"}, nil
	}
	quota := func() (gungnir.Result, error) {
		return gungnir.Result{Status: gungnir.StatusFailed, Summary: "no credits", Failure: gungnir.FailureQuota}, nil
	}
	infra := func() (gungnir.Result, error) {
		return gungnir.Result{}, &gungnir.SessionError{Kind: gungnir.FailureInfra, Err: errors.New("podman is gone")}
	}
	for name, c := range map[string]struct {
		step func() (gungnir.Result, error)
		is   func(error) bool
	}{
		"an agent error":  {agentErr, func(e error) bool { var a *AgentFailure; return errors.As(e, &a) && a.Reason == "exit 1" }},
		"a failed result": {agentRes, func(e error) bool { var a *AgentFailure; return errors.As(e, &a) && a.Reason == "tests fail" }},
		"a used-up quota": {quota, func(e error) bool { var q *QuotaError; return errors.As(e, &q) && q.Reason == "no credits" }},
		"an infra error": {infra, func(e error) bool {
			var se *gungnir.SessionError
			return errors.As(e, &se) && se.Kind == gungnir.FailureInfra
		}},
	} {
		sl := &slept{}
		sc := &script{steps: []func() (gungnir.Result, error){c.step}}
		_, err := retrier(sl).Do(context.Background(), sc.try)
		if !c.is(err) || sc.calls != 1 || len(sl.waits) != 0 {
			t.Errorf("%s: Do() = %v after %d tries and %d waits; want one try and no wait", name, err, sc.calls, len(sl.waits))
		}
	}
}

type meter struct{ hit *gungnir.CapError }

func (m *meter) Check() *gungnir.CapError { return m.hit }

func TestNoTryStartsOverABudgetCap(t *testing.T) {
	cap := &gungnir.CapError{Scope: gungnir.CapRun, Dimension: gungnir.CapTokens, Used: 10, Limit: 10}
	m := &meter{hit: cap}
	sc := &script{steps: []func() (gungnir.Result, error){ok}}
	r := retrier(&slept{})
	r.Meter = m
	if _, err := r.Do(context.Background(), sc.try); err != error(cap) || sc.calls != 0 {
		t.Errorf("Do() = %v after %d tries; want the cap, before any try", err, sc.calls)
	}
	// The first try spends the last of the budget and fails transiently: the retry must not start.
	m.hit = nil
	sc = &script{steps: []func() (gungnir.Result, error){func() (gungnir.Result, error) { m.hit = cap; return transient() }, ok}}
	if _, err := r.Do(context.Background(), sc.try); err != error(cap) || sc.calls != 1 {
		t.Errorf("Do() = %v after %d tries; want the cap before the retry", err, sc.calls)
	}
}

func TestACancelledRunIsNotAnAgentFailure(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	sc := &script{steps: []func() (gungnir.Result, error){func() (gungnir.Result, error) {
		cancel()
		return gungnir.Result{}, context.Canceled
	}}}
	if _, err := retrier(&slept{}).Do(ctx, sc.try); !errors.Is(err, context.Canceled) {
		var a *AgentFailure
		t.Errorf("Do() = %v (agent failure %v); want the context's error", err, errors.As(err, &a))
	}
	// The wait between retries ends with the context too, and sleeps for real by default.
	ctx, cancel = context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	r := Retrier{Backoff: Backoff{Base: time.Hour, Max: time.Hour, Retries: 3}}
	began := time.Now()
	if _, err := r.Do(ctx, (&script{steps: []func() (gungnir.Result, error){transient}}).try); !errors.Is(err, context.DeadlineExceeded) || time.Since(began) > 5*time.Second {
		t.Errorf("Do() = %v after %v; want the deadline, promptly", err, time.Since(began))
	}
}

func TestAFailingOnRetryHookStopsTheRetries(t *testing.T) {
	r := retrier(&slept{})
	r.OnRetry = func(int, time.Duration, string) error { return errors.New("the ledger is full") }
	sc := &script{steps: []func() (gungnir.Result, error){transient, ok}}
	if _, err := r.Do(context.Background(), sc.try); err == nil || sc.calls != 1 {
		t.Errorf("Do() = %v after %d tries; a retry that can't be recorded must not happen", err, sc.calls)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/jormungandr [github.com/ouroboric-dev/jormungandr.test]
./retry_test.go:13:7: undefined: Backoff
./retry_test.go:19:5: undefined: DefaultBackoff
./retry_test.go:20:36: undefined: DefaultBackoff
```

- [ ] **Step 3:** write the code.

Write `retry.go`:

```go
package jormungandr

import (
	"context"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

// Backoff is the retry policy for a transient failure (spec §12): a session that fails for a reason
// that is not the agent's runs again after a growing wait, up to Retries times.
type Backoff struct {
	Base    time.Duration // the wait before the first retry
	Max     time.Duration // no wait is longer than this
	Retries int           // how many times a session is retried; a session therefore runs at most Retries+1 times
}

// DefaultBackoff is 5 seconds, then 10, then 20, for three retries (spec §12).
var DefaultBackoff = Backoff{Base: 5 * time.Second, Max: time.Minute, Retries: 3}

// Delay returns the wait before retry number n, counting from 1: Base, twice Base, four times Base,
// and so on, never more than Max.
func (b Backoff) Delay(n int) time.Duration {
	d := b.Base
	for i := 1; i < n && d < b.Max; i++ {
		d *= 2
	}
	return min(d, b.Max)
}

// Retrier runs one session and decides what its failure means.
type Retrier struct {
	Backoff Backoff
	// Meter, when set, is asked before every try, the first and each retry: a session never starts
	// over a budget cap (spec §7.4).
	Meter gungnir.Meter
	// Sleep waits d, or until ctx ends. It is time-based unless a test replaces it.
	Sleep func(ctx context.Context, d time.Duration) error
	// OnRetry is told about each retry before the wait: the failed try's number, the wait and why.
	OnRetry func(try int, wait time.Duration, why string) error
}

// Try runs the session once; n counts from 1. It must count what the session spent, even when it
// fails: the caps see only what the caller adds up.
type Try func(ctx context.Context, n int) (gungnir.Result, error)

// Do runs try until it succeeds or fails in a way a retry can't help. It returns:
//   - the result and nil, for a session that succeeded;
//   - a *gungnir.CapError, when a budget cap is reached before a try;
//   - a *QuotaError, when the provider's quota is used up: the run pauses;
//   - an *ExhaustedError, when transient failures outlast the retries;
//   - an *AgentFailure, when the session failed as an agent does (spec §12: a loop attempt);
//   - the session's own error, for an infrastructure failure: the run stops, with no retry loop;
//   - the context's error, when ctx ends.
func (r Retrier) Do(ctx context.Context, try Try) (gungnir.Result, error) {
	sleep := r.Sleep
	if sleep == nil {
		sleep = wait
	}
	for n := 1; ; n++ {
		if r.Meter != nil {
			if hit := r.Meter.Check(); hit != nil {
				return gungnir.Result{}, hit
			}
		}
		res, err := try(ctx, n)
		kind, why := Classify(res, err)
		switch kind {
		case "":
			return res, nil
		case gungnir.FailureQuota:
			return res, &QuotaError{Reason: why}
		case gungnir.FailureInfra:
			return res, err
		case gungnir.FailureTransient:
			if n > r.Backoff.Retries {
				return res, &ExhaustedError{Tries: n, Last: why}
			}
			d := r.Backoff.Delay(n)
			if r.OnRetry != nil {
				if err := r.OnRetry(n, d, why); err != nil {
					return res, err
				}
			}
			if err := sleep(ctx, d); err != nil {
				return res, err
			}
		default:
			if ctx.Err() != nil {
				return res, ctx.Err() // the operator stopped the run; it is no failure of the agent's
			}
			return res, &AgentFailure{Reason: why}
		}
	}
}

func wait(ctx context.Context, d time.Duration) error {
	t := time.NewTimer(d)
	defer t.Stop()
	select {
	case <-t.C:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T119: the finding book: a check's findings open and close by the check itself

Spec §4.6: a finding does not close until its source confirms the fix with proof. A check is its own
source: it reopens a finding by failing and closes it by passing.

**Files (in `jormungandr`):**

- Create: `book.go`, `book_test.go`

**Interfaces:**

- Produces: `jormungandr.Record{gungnir.Finding; Raised, Closed, Reopens int}`, with `Attempts()` (the
  attempts it took to close, counting the one that raised it and the one that closed it, or 0 while
  open); `jormungandr.Book{Records map[string]*Record}`, plain data that serialises into `run.json`;
  `jormungandr.Change{Kind ChangeKind (Raised|Closed|Reopened); Finding; Attempts, Reopens int}`.
- Produces: `(*Book).Open()`, every finding not closed, worst first and by id within a severity, so the
  order is the same every attempt; `OpenFrom(source)`; `Blocking()`, the open blockers and majors
  (decision 9); `All()`; `CheckFailed(attempt, f) []Change` (a new finding is raised; one that closed is
  reopened and its reopens counted; one that is open follows the latest output and is no change) and
  `CheckPassed(attempt, id, proof) []Change` (closes an open finding of that id with the proof; a
  finding that never failed or is closed already is no change).

**Acceptance criteria:**

- [ ] A check that keeps failing keeps one finding, which follows its output and keeps the attempt that
      raised it.
- [ ] A check closes its finding only by passing, with proof, and not twice.
- [ ] A closed finding that comes back is reopened and counted, and closes again after the right number
      of attempts.
- [ ] Open findings come worst first in a stable order; a minor finding does not block.
- [ ] A book survives a round trip through JSON and encodes the same again.

**Named test:** `go test . -run 'TestACheckThatKeepsFailing|TestACheckClosesItsFinding|TestAClosedFindingThatComesBack|TestOpenFindingsComeWorstFirst|TestABookSurvives'`
in `jormungandr`. **Layer:** `jormungandr`. **Size:** M (262). **Depends on:** v0-T117.

- [ ] **Step 1:** write the tests.

Write `book_test.go`:

```go
package jormungandr

import (
	"encoding/json"
	"slices"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func finding(id, source string, sev gungnir.Severity) gungnir.Finding {
	return gungnir.Finding{ID: id, Source: source, Severity: sev, Location: "api/auth.go:42", Claim: "claim of " + id, Status: gungnir.FindingOpen}
}

func ids(fs []gungnir.Finding) []string {
	var out []string
	for _, f := range fs {
		out = append(out, f.ID)
	}
	return out
}

func TestACheckThatKeepsFailingKeepsOneFinding(t *testing.T) {
	var b Book
	f := finding("check-test", "test", gungnir.SeverityBlocker)
	if ch := b.CheckFailed(1, f); len(ch) != 1 || ch[0].Kind != Raised || ch[0].Finding.ID != "check-test" {
		t.Fatalf("first failure: %+v", ch)
	}
	f.Claim, f.Location = "newer output", "logs/b-2-test.log:1"
	if ch := b.CheckFailed(2, f); len(ch) != 0 {
		t.Errorf("a failure that goes on is not a new finding: %+v", ch)
	}
	if got := b.Open(); len(got) != 1 || got[0].Claim != "newer output" || got[0].Location != "logs/b-2-test.log:1" {
		t.Errorf("Open() = %+v; the finding must follow the latest output", got)
	}
	if b.Records["check-test"].Raised != 1 {
		t.Errorf("the finding was raised at attempt %d, want 1", b.Records["check-test"].Raised)
	}
}

func TestACheckClosesItsFindingOnlyWhenItPasses(t *testing.T) {
	var b Book
	b.CheckFailed(1, finding("check-test", "test", gungnir.SeverityBlocker))
	if ch := b.CheckPassed(2, "check-vet", "x"); len(ch) != 0 {
		t.Errorf("a check with no finding closed something: %+v", ch)
	}
	ch := b.CheckPassed(3, "check-test", "check test: exit 0 (logs/b-3-test.log)")
	if len(ch) != 1 || ch[0].Kind != Closed || ch[0].Attempts != 3 || ch[0].Finding.Status != gungnir.FindingFixed || ch[0].Finding.Proof == "" {
		t.Fatalf("CheckPassed() = %+v; want a close after 3 attempts with proof", ch)
	}
	if len(b.Open()) != 0 || len(b.Blocking()) != 0 {
		t.Errorf("the book still holds %v", ids(b.Open()))
	}
	if ch := b.CheckPassed(4, "check-test", "again"); len(ch) != 0 {
		t.Errorf("a closed finding closed again: %+v", ch)
	}
}

func TestAClosedFindingThatComesBackIsReopenedAndCounted(t *testing.T) {
	var b Book
	f := finding("check-test", "test", gungnir.SeverityBlocker)
	b.CheckFailed(1, f)
	b.CheckPassed(2, f.ID, "exit 0")
	ch := b.CheckFailed(3, f)
	if len(ch) != 1 || ch[0].Kind != Reopened || ch[0].Reopens != 1 {
		t.Fatalf("CheckFailed() = %+v; want a reopen", ch)
	}
	r := b.Records[f.ID]
	if r.Status != gungnir.FindingOpen || r.Closed != 0 || r.Reopens != 1 || r.Raised != 1 {
		t.Errorf("record = %+v", r)
	}
	ch = b.CheckPassed(5, f.ID, "exit 0")
	if len(ch) != 1 || ch[0].Attempts != 5 || ch[0].Reopens != 1 {
		t.Errorf("CheckPassed() = %+v; want it closed after 5 attempts, having reopened once", ch)
	}
}

func TestOpenFindingsComeWorstFirstInAStableOrder(t *testing.T) {
	var b Book
	for _, f := range []gungnir.Finding{
		finding("z-minor", "r", gungnir.SeverityMinor), finding("b-major", "r", gungnir.SeverityMajor),
		finding("a-major", "s", gungnir.SeverityMajor), finding("m-blocker", "r", gungnir.SeverityBlocker),
	} {
		b.CheckFailed(1, f)
	}
	if got := ids(b.Open()); !slices.Equal(got, []string{"m-blocker", "a-major", "b-major", "z-minor"}) {
		t.Errorf("Open() = %v", got)
	}
	if got := ids(b.Blocking()); !slices.Equal(got, []string{"m-blocker", "a-major", "b-major"}) {
		t.Errorf("Blocking() = %v; a minor finding must not block", got)
	}
	if got := ids(b.OpenFrom("r")); !slices.Equal(got, []string{"m-blocker", "b-major", "z-minor"}) {
		t.Errorf("OpenFrom(r) = %v", got)
	}
}

func TestABookSurvivesARoundTripThroughRunJSON(t *testing.T) {
	var b Book
	b.CheckFailed(1, finding("check-test", "test", gungnir.SeverityBlocker))
	b.CheckPassed(2, "check-test", "exit 0")
	b.CheckFailed(3, finding("check-test", "test", gungnir.SeverityBlocker))
	raw, err := json.Marshal(b)
	if err != nil {
		t.Fatal(err)
	}
	var back Book
	if err := json.Unmarshal(raw, &back); err != nil {
		t.Fatal(err)
	}
	r := back.Records["check-test"]
	if r == nil || r.Reopens != 1 || r.Raised != 1 || r.Status != gungnir.FindingOpen {
		t.Errorf("after the round trip: %+v from %s", r, raw)
	}
	if raw2, _ := json.Marshal(back); string(raw2) != string(raw) {
		t.Errorf("the encoding is not stable:\n%s\n%s", raw, raw2)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/jormungandr [github.com/ouroboric-dev/jormungandr.test]
./book_test.go:24:8: undefined: Book
./book_test.go:26:62: undefined: Raised
./book_test.go:42:8: undefined: Book
```

- [ ] **Step 3:** write the code.

Write `book.go`:

```go
package jormungandr

import (
	"cmp"
	"slices"

	"github.com/ouroboric-dev/gungnir"
)

// Record is one finding and its history in a loop (spec §4.6, §10.1): the attempt it was first
// reported, the attempt it closed, and how often it came back.
type Record struct {
	gungnir.Finding
	Raised  int `json:"raised"`            // the attempt the finding was first reported
	Closed  int `json:"closed,omitempty"`  // the attempt its source confirmed the fix; 0 while it is open
	Reopens int `json:"reopens,omitempty"` // how many times it was reported again after it closed
}

// Attempts is how many attempts the finding took to close, counting the one that raised it and the one
// that closed it. It is 0 for a finding that is still open.
func (r Record) Attempts() int {
	if r.Closed == 0 {
		return 0
	}
	return r.Closed - r.Raised + 1
}

func (r Record) isOpen() bool { return r.Status != gungnir.FindingFixed }

// Book holds a loop's findings by id. Its only way to close a finding is the source's confirmation:
// a check that passes, or a reviewer's report with proof. An implementer's claim never closes one.
type Book struct {
	Records map[string]*Record `json:"records,omitempty"`
}

// ChangeKind says what happened to a finding.
type ChangeKind string

const (
	Raised   ChangeKind = "raised"   // first reported
	Closed   ChangeKind = "closed"   // its source confirmed the fix, with proof
	Reopened ChangeKind = "reopened" // reported again after it closed
)

// Change is one change to the book, for a ledger line (spec §10.1).
type Change struct {
	Kind    ChangeKind
	Finding gungnir.Finding
	// Attempts and Reopens are set on a Closed change (the attempts it took, and how often it came
	// back) and Reopens on a Reopened one.
	Attempts int
	Reopens  int
}

func (b *Book) put(f gungnir.Finding, attempt int) *Record {
	if b.Records == nil {
		b.Records = map[string]*Record{}
	}
	r := &Record{Finding: f, Raised: attempt}
	b.Records[f.ID] = r
	return r
}

// severityRank orders findings, worst first.
func severityRank(s gungnir.Severity) int {
	switch s {
	case gungnir.SeverityBlocker:
		return 0
	case gungnir.SeverityMajor:
		return 1
	}
	return 2
}

func (b *Book) sorted(keep func(Record) bool) []gungnir.Finding {
	var recs []Record
	for _, r := range b.Records {
		if keep(*r) {
			recs = append(recs, *r)
		}
	}
	slices.SortFunc(recs, func(x, y Record) int {
		return cmp.Or(cmp.Compare(severityRank(x.Severity), severityRank(y.Severity)), cmp.Compare(x.ID, y.ID))
	})
	out := make([]gungnir.Finding, len(recs))
	for i, r := range recs {
		out[i] = r.Finding
	}
	return out
}

// Open returns every finding not yet closed, the worst first and by id within a severity, so the
// order is the same on every attempt.
func (b *Book) Open() []gungnir.Finding { return b.sorted(Record.isOpen) }

// OpenFrom returns the open findings a source raised.
func (b *Book) OpenFrom(source string) []gungnir.Finding {
	return b.sorted(func(r Record) bool { return r.isOpen() && r.Source == source })
}

// Blocking returns the open findings that stop a loop from passing: blockers and majors. A minor
// finding is recorded, and goes back to the implementer with the others, but never fails a loop alone
// (Phase 4, decision 9).
func (b *Book) Blocking() []gungnir.Finding {
	return b.sorted(func(r Record) bool { return r.isOpen() && r.Severity != gungnir.SeverityMinor })
}

// All returns every record, closed or open, by id, for a report.
func (b *Book) All() []Record {
	var out []Record
	for _, r := range b.Records {
		out = append(out, *r)
	}
	slices.SortFunc(out, func(x, y Record) int { return cmp.Compare(x.ID, y.ID) })
	return out
}

// CheckFailed records that a check did not pass on this attempt. The same check keeps the same
// finding; its claim and location follow the latest output. A finding that had closed is reopened.
func (b *Book) CheckFailed(attempt int, f gungnir.Finding) []Change {
	r, ok := b.Records[f.ID]
	switch {
	case !ok:
		b.put(f, attempt)
		return []Change{{Kind: Raised, Finding: f}}
	case !r.isOpen():
		r.Reopens++
		r.Closed = 0
		r.Finding = f
		return []Change{{Kind: Reopened, Finding: f, Reopens: r.Reopens}}
	}
	r.Finding = f
	return nil
}

// CheckPassed closes the finding a check raised earlier, with proof that the check ran and passed. A
// check that never failed has nothing to close.
func (b *Book) CheckPassed(attempt int, id, proof string) []Change {
	r, ok := b.Records[id]
	if !ok || !r.isOpen() {
		return nil
	}
	r.Status, r.Proof, r.Closed = gungnir.FindingFixed, proof, attempt
	return []Change{{Kind: Closed, Finding: r.Finding, Attempts: r.Attempts(), Reopens: r.Reopens}}
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T120: the finding book: a reviewer's report, and proof for closing a finding

A reviewer is a source that can say a lot. The book accepts a report only if it keeps the promises of
spec §4.6 and decision 8, and a report that breaks one changes nothing.

**Files (in `jormungandr`):**

- Create: `review.go`, `review_test.go`

**Interfaces:**

- Consumes: `gungnir.Report` (v0-T102), `Book` (v0-T119).
- Produces: `jormungandr.ReportError{Reviewer, Reason}`; `(*Book).Review(attempt int, reviewer string,
  passed []string, report gungnir.Report) ([]Change, error)`. It refuses (with a `*ReportError`, and
  changes nothing) a report that: has a finding whose source is not the reviewer, or that belongs to
  another source; leaves out a finding the reviewer still held open; closes a finding that was not open
  or is new; closes one with a proof that lacks a `file:line`, or, when the loop has checks, does not
  name one of the checks that passed in this attempt as a whole word. Otherwise: new findings are
  raised, a finding reported `fixed` is closed, a closed finding reported open or disputed is reopened,
  and an open one follows the reviewer's words (location, claim, severity) and keeps its identity. A
  `disputed` finding stays open and blocks.

**Acceptance criteria:**

- [ ] A reviewer raises findings; an empty report is a pass; a finding closes with a proof that cites a
      place and a check that passed.
- [ ] Seven reports each break a rule and change nothing: a finding dropped, a close with no place, a close
      with no check, a close naming a check that did not pass, a close naming part of a check's name, a
      finding of another source, a finding born closed.
- [ ] A reviewer can't close, or take over, a check's finding.
- [ ] With no checks in the loop a place is the whole proof.
- [ ] A disputed finding stays open; a closed one that comes back is reopened; an open one may be
      reworded and keeps its identity.

**Named test:** `go test . -run 'TestAReviewer|TestAFindingClosesOnlyWithProof|TestADisputedFinding'` in
`jormungandr`. **Layer:** `jormungandr`. **Size:** M (222). **Depends on:** v0-T119;
v0-T102 merged.

- [ ] **Step 1:** write the tests.

Write `review_test.go`:

```go
package jormungandr

import (
	"errors"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func report(fs ...gungnir.Finding) gungnir.Report { return gungnir.Report{Findings: fs} }

func fixed(f gungnir.Finding, proof string) gungnir.Finding {
	f.Status, f.Proof = gungnir.FindingFixed, proof
	return f
}

var passed = []string{"vet", "test"}

func TestAReviewerRaisesFindingsAndEmptyIsAPass(t *testing.T) {
	var b Book
	ch, err := b.Review(1, "spec", passed, report(finding("spec-1", "spec", gungnir.SeverityMajor), finding("spec-2", "spec", gungnir.SeverityMinor)))
	if err != nil || len(ch) != 2 || ch[0].Kind != Raised {
		t.Fatalf("Review() = %+v, %v", ch, err)
	}
	if got := ids(b.Blocking()); len(got) != 1 || got[0] != "spec-1" {
		t.Errorf("Blocking() = %v", got)
	}
	var empty Book
	if ch, err := empty.Review(1, "spec", passed, report()); err != nil || len(ch) != 0 {
		t.Errorf("an empty report: %+v, %v; it says the reviewer found nothing", ch, err)
	}
}

func TestAFindingClosesOnlyWithProofFromItsSource(t *testing.T) {
	var b Book
	f := finding("spec-1", "spec", gungnir.SeverityMajor)
	b.Review(1, "spec", passed, report(f))
	ch, err := b.Review(2, "spec", passed, report(fixed(f, "api/auth.go:44 now limits tries; check test passed")))
	if err != nil || len(ch) != 1 || ch[0].Kind != Closed || ch[0].Attempts != 2 || ch[0].Finding.Proof == "" {
		t.Fatalf("Review() = %+v, %v; want a close after 2 attempts", ch, err)
	}
	if len(b.Open()) != 0 {
		t.Errorf("still open: %v", ids(b.Open()))
	}
}

func TestAReviewerReportThatBreaksARuleChangesNothing(t *testing.T) {
	f := finding("spec-1", "spec", gungnir.SeverityMajor)
	cases := map[string]struct {
		report gungnir.Report
		want   string
	}{
		"a finding dropped without a word":             {report(), "doesn't mention it"},
		"a close without a place":                      {report(fixed(f, "check test passed, it looks right")), "without proof"},
		"a close without a check":                      {report(fixed(f, "api/auth.go:44 limits tries")), "without proof"},
		"a close naming a check that didn't pass":      {report(fixed(f, "api/auth.go:44; check lint passed")), "without proof"},
		"a close naming a check by a part of its name": {report(fixed(f, "api/auth.go:44; the tests passed")), "without proof"},
		"a finding of another source":                  {report(f, finding("q-1", "quality", gungnir.SeverityMinor)), "says its source"},
		"a finding born closed":                        {report(f, fixed(finding("spec-9", "spec", gungnir.SeverityMinor), "api/a.go:1; check vet passed")), "was not open"},
	}
	for name, c := range cases {
		var b Book
		b.Review(1, "spec", passed, report(f))
		before := len(b.Open())
		ch, err := b.Review(2, "spec", passed, c.report)
		var re *ReportError
		if !errors.As(err, &re) || !strings.Contains(err.Error(), c.want) || ch != nil {
			t.Errorf("%s: Review() = %+v, %v; want a ReportError containing %q", name, ch, err, c.want)
		}
		if len(b.Open()) != before || b.Records["spec-1"].Status != gungnir.FindingOpen {
			t.Errorf("%s: a refused report changed the book", name)
		}
	}
}

func TestAReviewerCannotTouchAnotherSourcesFinding(t *testing.T) {
	var b Book
	b.CheckFailed(1, finding("check-test", "test", gungnir.SeverityBlocker))
	_, err := b.Review(1, "spec", passed, report(fixed(finding("check-test", "spec", gungnir.SeverityBlocker), "api/a.go:1; check test passed")))
	if err == nil || !strings.Contains(err.Error(), "was not open") && !strings.Contains(err.Error(), "belongs to") {
		t.Errorf("Review() = %v; a reviewer closed a check's finding", err)
	}
	_, err = b.Review(1, "spec", passed, report(finding("check-test", "spec", gungnir.SeverityBlocker)))
	if err == nil || !strings.Contains(err.Error(), "belongs to test") {
		t.Errorf("Review() = %v; a reviewer took over a check's finding", err)
	}
}

func TestAReviewerThatHasNoChecksToCiteNeedsOnlyAPlace(t *testing.T) {
	var b Book
	f := finding("spec-1", "spec", gungnir.SeverityMajor)
	b.Review(1, "spec", nil, report(f))
	if _, err := b.Review(2, "spec", nil, report(fixed(f, "api/auth.go:44 limits tries"))); err != nil {
		t.Errorf("Review() = %v; with no checks in the loop, a place is the whole proof", err)
	}
}

func TestADisputedFindingStaysOpenAndAClosedOneReopens(t *testing.T) {
	var b Book
	f := finding("spec-1", "spec", gungnir.SeverityMajor)
	b.Review(1, "spec", passed, report(f))
	disputed := f
	disputed.Status = gungnir.FindingDisputed
	if ch, err := b.Review(2, "spec", passed, report(disputed)); err != nil || len(ch) != 0 || len(b.Blocking()) != 1 {
		t.Errorf("a disputed finding: %+v, %v, blocking %v; it is unresolved", ch, err, ids(b.Blocking()))
	}
	b.Review(3, "spec", passed, report(fixed(f, "api/auth.go:44; check vet passed")))
	ch, err := b.Review(4, "spec", passed, report(f))
	if err != nil || len(ch) != 1 || ch[0].Kind != Reopened || ch[0].Reopens != 1 {
		t.Fatalf("Review() = %+v, %v; want a reopen", ch, err)
	}
	if r := b.Records["spec-1"]; r.Raised != 1 || r.Closed != 0 || r.Status != gungnir.FindingOpen {
		t.Errorf("record = %+v", r)
	}
}

func TestAReviewerMayRewordAnOpenFindingButNotItsIdentity(t *testing.T) {
	var b Book
	f := finding("spec-1", "spec", gungnir.SeverityMajor)
	b.Review(1, "spec", passed, report(f))
	moved := f
	moved.Location, moved.Claim, moved.Severity = "api/auth.go:60", "the throttle is per-IP, not per-PIN", gungnir.SeverityBlocker
	if ch, err := b.Review(2, "spec", passed, report(moved)); err != nil || len(ch) != 0 {
		t.Fatalf("Review() = %+v, %v", ch, err)
	}
	if got := b.Open()[0]; got.Location != "api/auth.go:60" || got.Severity != gungnir.SeverityBlocker || b.Records["spec-1"].Raised != 1 {
		t.Errorf("finding = %+v", got)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/jormungandr [github.com/ouroboric-dev/jormungandr.test]
./review_test.go:22:15: b.Review undefined (type Book has no field or method Review)
./review_test.go:30:22: empty.Review undefined (type Book has no field or method Review)
./review_test.go:38:4: b.Review undefined (type Book has no field or method Review)
```

- [ ] **Step 3:** write the code.

Write `review.go`:

```go
package jormungandr

import (
	"fmt"
	"regexp"
	"slices"
	"strings"

	"github.com/ouroboric-dev/gungnir"
)

// ReportError is a reviewer's report that parsed but does not fit the book: it drops a finding, closes
// one without proof, or speaks for another reviewer. Like an answer that does not parse, it is malformed
// output, which never counts as a pass (spec §4.6).
type ReportError struct {
	Reviewer string
	Reason   string
}

func (e *ReportError) Error() string { return fmt.Sprintf("reviewer %s: %s", e.Reviewer, e.Reason) }

// evidence matches a place in the code: a file and a line.
var evidence = regexp.MustCompile(`[^\s:]+:[0-9]+`)

// proves reports whether proof is what spec §4.6 asks for to close a finding: a file:line the reviewer
// read, and, when the loop has checks, the name of one that passed on this attempt. The reviewer can't
// run a check; Odin ran them before it asked, and tells the reviewer which passed.
func proves(proof string, passed []string) bool {
	if !evidence.MatchString(proof) {
		return false
	}
	if len(passed) == 0 {
		return true
	}
	return slices.ContainsFunc(passed, func(c string) bool {
		return regexp.MustCompile(`(^|[^A-Za-z0-9_-])` + regexp.QuoteMeta(c) + `($|[^A-Za-z0-9_-])`).MatchString(proof)
	})
}

// Review applies a reviewer's report to the book. reviewer names the source; passed lists the checks
// that passed on this attempt. The rules, from spec §4.6:
//   - every finding in the report is the reviewer's own (its source is the reviewer's id);
//   - every finding the reviewer still held open is in the report, so none disappears unmentioned;
//   - a finding closes (status fixed) only with proof: a file:line and the name of a check that passed;
//   - a finding that is not open can't be closed, and a new finding can't be born closed;
//   - a closed finding reported open again is reopened.
//
// A report that breaks a rule changes nothing and is a *ReportError.
func (b *Book) Review(attempt int, reviewer string, passed []string, report gungnir.Report) ([]Change, error) {
	bad := func(format string, a ...any) ([]Change, error) {
		return nil, &ReportError{Reviewer: reviewer, Reason: fmt.Sprintf(format, a...)}
	}
	reported := map[string]bool{}
	for _, f := range report.Findings {
		reported[f.ID] = true
		old, known := b.Records[f.ID]
		switch {
		case f.Source != reviewer:
			return bad("finding %s says its source is %q", f.ID, f.Source)
		case known && old.Source != reviewer:
			return bad("finding %s belongs to %s", f.ID, old.Source)
		case f.Status == gungnir.FindingFixed && (!known || !old.isOpen()):
			return bad("finding %s is closed in the report but was not open", f.ID)
		case f.Status == gungnir.FindingFixed && !proves(f.Proof, passed):
			return bad("finding %s is closed without proof: the proof must cite a file:line and name a check that passed (%s)", f.ID, strings.Join(passed, ", "))
		}
	}
	for _, f := range b.OpenFrom(reviewer) {
		if !reported[f.ID] {
			return bad("finding %s is still open and the report doesn't mention it", f.ID)
		}
	}
	var changes []Change
	for _, f := range report.Findings {
		r, known := b.Records[f.ID]
		switch {
		case !known:
			b.put(f, attempt)
			changes = append(changes, Change{Kind: Raised, Finding: f})
		case f.Status == gungnir.FindingFixed:
			r.Finding, r.Closed = f, attempt
			changes = append(changes, Change{Kind: Closed, Finding: f, Attempts: r.Attempts(), Reopens: r.Reopens})
		case !r.isOpen():
			r.Reopens++
			r.Closed, r.Finding = 0, f
			changes = append(changes, Change{Kind: Reopened, Finding: f, Reopens: r.Reopens})
		default:
			r.Finding = f
		}
	}
	return changes, nil
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T121: what the next attempt and a reviewer are told

Every session starts clean (spec §4.4), so the open findings, the last failure and the operator's words
are all the next attempt knows; and a reviewer must know how to answer, what it said before, and which
checks passed.

**Files (in `jormungandr`):**

- Create: `prompt.go`, `prompt_test.go`

**Interfaces:**

- Produces: `jormungandr.Feedback(open []gungnir.Finding, lastFailure, guidance string) string`: a
  section "Findings to fix" that lists each finding (id, severity, source, place, and the claim's lines)
  and says the implementer must not call any of them fixed, a section "The last attempt failed", and a
  section "Guidance from the operator"; empty when there is nothing to say.
- Produces: `jormungandr.ReportFormat`, the instructions for the one JSON document a reviewer answers
  with; `jormungandr.ReviewRequest(reviewer string, open []gungnir.Finding, passed []string) string`:
  the reviewer's id as the source, the checks that passed, and the findings it reported before as a valid
  report to copy.

**Acceptance criteria:**

- [ ] `Feedback` lists the findings in the order given, marks a disputed one, and carries the failure and
      the guidance; it is empty for nothing.
- [ ] `ReviewRequest` shows a reviewer its own findings and the checks that passed, and nothing of a first
      review's past; the findings in it parse as a report; the example in `ReportFormat` parses too.

**Named test:** `go test . -run 'TestFeedback|TestAReviewRequest|TestTheReportFormat'` in `jormungandr`.
**Layer:** `jormungandr`. **Size:** M (132). **Depends on:** v0-T120.

- [ ] **Step 1:** write the tests.

Write `prompt_test.go`:

````go
package jormungandr

import (
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

func TestFeedbackListsTheOpenFindingsAndDoesNotLetTheImplementerCloseThem(t *testing.T) {
	multi := finding("check-test", "test", gungnir.SeverityBlocker)
	multi.Claim = "check test failed: exit status 1\nthe end of its output:\n--- FAIL: TestThrottle"
	disputed := finding("spec-2", "spec", gungnir.SeverityMinor)
	disputed.Status = gungnir.FindingDisputed
	got := Feedback([]gungnir.Finding{multi, disputed}, "timed out after 20m0s", "Keep the public API unchanged.")
	for _, want := range []string{
		"## Findings to fix", "- check-test (blocker, from test) at api/auth.go:42", "  --- FAIL: TestThrottle",
		"- spec-2 (minor, from spec) at api/auth.go:42 [disputed]", "Do not say any of them is fixed",
		"## The last attempt failed", "timed out after 20m0s", "## Guidance from the operator", "Keep the public API unchanged.",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("Feedback() lacks %q:\n%s", want, got)
		}
	}
	if strings.Index(got, "check-test") > strings.Index(got, "spec-2") {
		t.Error("the findings are not in the order they were given")
	}
}

func TestFeedbackIsEmptyWhenThereIsNothingToSay(t *testing.T) {
	if got := Feedback(nil, "", ""); got != "" {
		t.Errorf("Feedback() = %q, want nothing", got)
	}
}

func TestAReviewRequestShowsTheReviewerItsOwnFindingsAndTheChecksThatPassed(t *testing.T) {
	f := finding("spec-1", "spec", gungnir.SeverityMajor)
	got := ReviewRequest("spec", []gungnir.Finding{f}, []string{"vet", "test"})
	for _, want := range []string{"Your id is spec", "The checks that passed on this work: vet, test.", "## Findings you reported before", `"id": "spec-1"`, "One you leave out is an error"} {
		if !strings.Contains(got, want) {
			t.Errorf("ReviewRequest() lacks %q:\n%s", want, got)
		}
	}
	// The findings in the request are a valid report, so a reviewer that copies them back is understood.
	start := strings.Index(got, "```json\n") + len("```json\n")
	end := strings.LastIndex(got, "\n```")
	if rep, err := schema.ParseReport([]byte(got[start:end])); err != nil || len(rep.Findings) != 1 || rep.Findings[0].ID != "spec-1" {
		t.Errorf("the findings in the request don't parse as a report: %+v, %v", rep, err)
	}
	if first := ReviewRequest("quality", nil, nil); strings.Contains(first, "Findings you reported before") || strings.Contains(first, "checks that passed") {
		t.Errorf("a first review has nothing to recall:\n%s", first)
	}
}

func TestTheReportFormatTheReviewerIsGivenIsTheOneParseReportReads(t *testing.T) {
	example := ReportFormat[strings.Index(ReportFormat, `{"findings": [ {`):]
	example = example[:strings.Index(example, "\n")]
	example = strings.NewReplacer(`"<your id>"`, `"spec"`, `"blocker|major|minor"`, `"major"`, `"path/to/file:LINE"`, `"path/to/file:12"`).Replace(example)
	if _, err := schema.ParseReport([]byte(example)); err != nil {
		t.Errorf("the example in ReportFormat does not parse: %v\n%s", err, example)
	}
}
````

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/jormungandr [github.com/ouroboric-dev/jormungandr.test]
./prompt_test.go:16:9: undefined: Feedback
./prompt_test.go:32:12: undefined: Feedback
./prompt_test.go:39:9: undefined: ReviewRequest
```

- [ ] **Step 3:** write the code.

Write `prompt.go`:

````go
package jormungandr

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/ouroboric-dev/gungnir"
)

// Feedback is the text added to an implementer's prompt after the first attempt (spec §4.6): the
// findings still open, why the last attempt failed if it did, and what an operator wrote when they sent
// the work back. Every session starts clean (spec §4.4), so this is all the next attempt knows of the
// last. The text tells the implementer it can't close a finding: the finding's source decides.
func Feedback(open []gungnir.Finding, lastFailure, guidance string) string {
	var b strings.Builder
	if len(open) > 0 {
		b.WriteString("## Findings to fix\n\nThe checks and reviewers found these problems in the work so far. Fix every one. " +
			"Do not say any of them is fixed: the check or reviewer that raised it looks again after your work and decides.\n\n")
		for _, f := range open {
			fmt.Fprintf(&b, "- %s (%s, from %s) at %s", f.ID, f.Severity, f.Source, f.Location)
			if f.Status == gungnir.FindingDisputed {
				b.WriteString(" [disputed]")
			}
			b.WriteString("\n")
			for _, line := range strings.Split(strings.TrimSpace(f.Claim), "\n") {
				fmt.Fprintf(&b, "  %s\n", line)
			}
		}
		b.WriteString("\n")
	}
	if lastFailure != "" {
		fmt.Fprintf(&b, "## The last attempt failed\n\nYour last session ended with: %s\nThe repository is as the last attempt that finished left it.\n\n", lastFailure)
	}
	if guidance != "" {
		fmt.Fprintf(&b, "## Guidance from the operator\n\n%s\n\n", strings.TrimSpace(guidance))
	}
	return b.String()
}

// ReportFormat explains to a reviewer how to answer (spec §4.6). Its answer is read by a program, and
// anything that doesn't parse stops the loop.
const ReportFormat = `Answer with one JSON document and nothing else, not even a sentence before or after it:

{"findings": [ {"id": "...", "source": "<your id>", "severity": "blocker|major|minor", "location": "path/to/file:LINE", "claim": "what is wrong", "status": "open"} ]}

- "id" names the problem and stays the same every time you report it.
- "location" is a file and a line, or a range such as path/to/file:10-20.
- "status" is "open" for a problem you still see. Say "fixed" only for a problem listed below that you checked
  is gone, and then add "proof": the file:line you read, and the name of one of the checks listed below
  that passed. A finding without both is refused.
- If you find nothing, answer {"findings": []}.`

// ReviewRequest is the text added to a reviewer's prompt: how to answer, the findings it reported
// before, and the checks that passed on the work it is about to read. Findings of other sources are not
// shown to it: a reviewer judges its own.
func ReviewRequest(reviewer string, open []gungnir.Finding, passed []string) string {
	var b strings.Builder
	b.WriteString("## Your answer\n\nYour id is " + reviewer + ". Use it as the \"source\" of every finding.\n\n" + ReportFormat + "\n\n")
	if len(passed) > 0 {
		b.WriteString("The checks that passed on this work: " + strings.Join(passed, ", ") + ".\n\n")
	}
	if len(open) > 0 {
		raw, _ := json.MarshalIndent(gungnir.Report{Findings: open}, "", "  ")
		b.WriteString("## Findings you reported before and still hold open\n\nReport each of these again, with the same id: as open if the problem is still there, or as fixed with proof if it is gone. " +
			"One you leave out is an error.\n\n```json\n" + string(raw) + "\n```\n")
	}
	return b.String()
}
````

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T122: the bounded loop: attempts, the check ladder, and escalation when the attempts run out

Spec §4.2 and §7.3. An implementer works, the checks judge, the findings that stay open go back, and
after the last attempt the loop gives up. This task is the loop without reviewers, caps and quotas.

**Files (in `jormungandr`):**

- Create: `loop.go`, `loop_test.go`

**Interfaces:**

- Produces: `jormungandr.Config{Attempts int; Checks []string}`; `jormungandr.State{Attempt, Limit int;
  Phase Phase; Passed bool; Book Book; Failure string}`, plain data that goes into `run.json`, with
  `NewState(cfg) *State` (attempt 1, phase `implement`); `Phase` (`PhaseImplement`, `PhaseLadder`);
  `jormungandr.Input{Open []gungnir.Finding; LastFailure string}`; `jormungandr.CheckOutcome{Passed bool;
  FindingID string; Finding gungnir.Finding; Proof string}`.
- Produces: `jormungandr.Steps`, which Odin implements: `Implement(ctx, attempt int, in Input) error`
  (one fresh implementer session; commits its work), `Check(ctx, attempt int, name string)
  (CheckOutcome, error)`, `Record(attempt int, changes []Change) error` (the ledger lines),
  `Save(*State) error` (run.json). An `*AgentFailure` from `Implement` costs the attempt; any other error
  ends the run of the loop as it is.
- Produces: `jormungandr.Run(ctx, cfg, st *State, steps Steps) (Outcome, error)` and `Outcome{Kind
  (Passed|Escalated); Attempts int; Reason, Detail string; Open []gungnir.Finding}`. The loop saves its
  state before every session and after every boundary. Each attempt: the implementer, then the checks in
  order, stopping at the first that fails; the loop passes when no blocker or major finding is open. When
  `Attempt` passes `Limit` it escalates with the reason `ReasonExhausted` and the open findings. A passed
  loop does not run again.

**Acceptance criteria:**

- [ ] Work that passes every check passes in the first attempt, calling nothing else.
- [ ] A failing check stops the ladder, goes back to the implementer as a finding, and closes when the
      check passes, with the attempts it took.
- [ ] A loop that never passes runs its attempts and escalates with the open findings.
- [ ] A session that failed as an agent uses up an attempt, its reason is in the next one's input, and
      when every attempt fails that way the loop escalates and says so.
- [ ] Any other error, a state that can't be saved and a cancelled context end the run of the loop
      before any session starts or as they are.

**Named test:** `go test . -run 'TestWorkThatPasses|TestAFailingCheck|TestALoopThatNeverPasses|TestASessionThatFailedAsAnAgent|TestOtherErrors|TestAFinishedLoop'`
in `jormungandr`. **Layer:** `jormungandr`. **Size:** M (375). **Depends on:** v0-T121.

- [ ] **Step 1:** write the tests.

Write `loop_test.go`:

```go
package jormungandr

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

// fakeSteps plays the steps of a loop from lists: each call takes the next entry for its kind.
type fakeSteps struct {
	implement []error           // per implementer session; nil is a success
	check     map[string][]bool // per check: passes, per attempt that reaches it
	calls     []string          // what ran, in order
	inputs    []Input           // what each implementer session was given
	changes   []Change          // everything recorded
	saved     []State           // a copy of the state at every save
	saveErr   error
	ni        int
	nc        map[string]int
}

func (f *fakeSteps) Implement(_ context.Context, attempt int, in Input) error {
	f.calls = append(f.calls, fmt.Sprintf("implement %d", attempt))
	f.inputs = append(f.inputs, in)
	var err error
	if f.ni < len(f.implement) {
		err = f.implement[f.ni]
	}
	f.ni++
	return err
}

func (f *fakeSteps) Check(_ context.Context, attempt int, name string) (CheckOutcome, error) {
	f.calls = append(f.calls, fmt.Sprintf("check %d %s", attempt, name))
	if f.nc == nil {
		f.nc = map[string]int{}
	}
	i := f.nc[name]
	f.nc[name]++
	passes := f.check[name]
	ok := i >= len(passes) || passes[i]
	id := "check-" + name
	if ok {
		return CheckOutcome{Passed: true, FindingID: id, Proof: fmt.Sprintf("check %s: exit 0", name)}, nil
	}
	return CheckOutcome{FindingID: id, Finding: gungnir.Finding{ID: id, Source: name, Severity: gungnir.SeverityBlocker,
		Location: "logs/" + name + ".log:1", Claim: "check " + name + " failed", Status: gungnir.FindingOpen}}, nil
}

func (f *fakeSteps) Record(_ int, changes []Change) error {
	f.changes = append(f.changes, changes...)
	return nil
}

func (f *fakeSteps) Save(s *State) error {
	raw, _ := json.Marshal(s)
	var c State
	json.Unmarshal(raw, &c)
	f.saved = append(f.saved, c)
	return f.saveErr
}

func (f *fakeSteps) ran(call string) bool { return slices.Contains(f.calls, call) }

var cfg = Config{Attempts: 3, Checks: []string{"vet", "test"}}

func run(t *testing.T, st *State, f *fakeSteps) Outcome {
	t.Helper()
	out, err := Run(context.Background(), cfg, st, f)
	if err != nil {
		t.Fatalf("Run() = %v", err)
	}
	return out
}

func TestWorkThatPassesEveryCheckPassesOnTheFirstAttempt(t *testing.T) {
	f := &fakeSteps{}
	st := NewState(cfg)
	out := run(t, st, f)
	if out.Kind != Passed || out.Attempts != 1 || !st.Passed {
		t.Fatalf("Run() = %+v", out)
	}
	want := []string{"implement 1", "check 1 vet", "check 1 test"}
	if !slices.Equal(f.calls, want) {
		t.Errorf("calls = %v, want %v", f.calls, want)
	}
	if len(f.inputs[0].Open) != 0 || f.inputs[0].LastFailure != "" {
		t.Errorf("the first attempt was given %+v", f.inputs[0])
	}
}

func TestAFailingCheckGoesBackToTheImplementerAndTheSlowerChecksWait(t *testing.T) {
	f := &fakeSteps{check: map[string][]bool{"test": {false, true}}}
	st := NewState(cfg)
	out := run(t, st, f)
	if out.Kind != Passed || out.Attempts != 2 {
		t.Fatalf("Run() = %+v", out)
	}
	want := []string{"implement 1", "check 1 vet", "check 1 test", "implement 2", "check 2 vet", "check 2 test"}
	if !slices.Equal(f.calls, want) {
		t.Errorf("calls = %v\nwant    %v", f.calls, want)
	}
	if got := f.inputs[1].Open; len(got) != 1 || got[0].ID != "check-test" {
		t.Errorf("attempt 2 was given %+v; it must carry the failing check's finding", f.inputs[1])
	}
	if len(f.changes) != 2 || f.changes[0].Kind != Raised || f.changes[1].Kind != Closed || f.changes[1].Attempts != 2 {
		t.Errorf("changes = %+v; want the finding raised, then closed after 2 attempts", f.changes)
	}
}

func TestALoopThatNeverPassesEscalatesAfterItsAttempts(t *testing.T) {
	f := &fakeSteps{check: map[string][]bool{"test": {false, false, false, false}}}
	st := NewState(cfg)
	out := run(t, st, f)
	if out.Kind != Escalated || out.Reason != ReasonExhausted || out.Attempts != 3 || len(out.Open) != 1 || out.Open[0].ID != "check-test" {
		t.Fatalf("Run() = %+v", out)
	}
	if got := strings.Count(strings.Join(f.calls, "\n"), "implement"); got != 3 {
		t.Errorf("the implementer ran %d times, want 3", got)
	}
	if st.Passed {
		t.Error("an escalated loop is marked passed")
	}
}

func TestASessionThatFailedAsAnAgentUsesUpAnAttemptAndSaysWhy(t *testing.T) {
	f := &fakeSteps{implement: []error{&AgentFailure{Reason: "timed out after 20m0s"}, &AgentFailure{Reason: "exit 1"}, nil}}
	out := run(t, NewState(cfg), f)
	if out.Kind != Passed || out.Attempts != 3 {
		t.Fatalf("Run() = %+v", out)
	}
	if f.inputs[1].LastFailure != "timed out after 20m0s" || f.inputs[2].LastFailure != "exit 1" {
		t.Errorf("inputs = %+v", f.inputs)
	}
	for _, c := range f.calls {
		if strings.HasPrefix(c, "check") && c != "check 3 vet" && c != "check 3 test" {
			t.Errorf("%s ran, but only the third attempt produced work to check", c)
		}
	}
	// When every attempt fails that way, the loop escalates and says so.
	f = &fakeSteps{implement: []error{&AgentFailure{Reason: "a"}, &AgentFailure{Reason: "b"}, &AgentFailure{Reason: "exit 137"}}}
	out = run(t, NewState(cfg), f)
	if out.Kind != Escalated || !strings.Contains(out.Detail, "exit 137") {
		t.Errorf("Run() = %+v", out)
	}
}

func TestOtherErrorsEndTheRunOfTheLoopAsTheyAre(t *testing.T) {
	infra := &gungnir.SessionError{Kind: gungnir.FailureInfra, Err: errors.New("podman is gone")}
	for name, f := range map[string]*fakeSteps{
		"an infrastructure failure": {implement: []error{infra}},
		"exhausted retries":         {implement: []error{&ExhaustedError{Tries: 4, Last: "429"}}},
	} {
		st := NewState(cfg)
		out, err := Run(context.Background(), cfg, st, f)
		if err == nil || out.Kind != "" {
			t.Errorf("%s: Run() = %+v, %v; want the error", name, out, err)
		}
	}
	// A state that cannot be saved stops the loop before it spends anything.
	f := &fakeSteps{saveErr: errors.New("disk full")}
	if _, err := Run(context.Background(), cfg, NewState(cfg), f); err == nil || f.ran("implement 1") {
		t.Errorf("Run() = %v; a loop that can't save its state must not start a session", err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := Run(ctx, cfg, NewState(cfg), &fakeSteps{}); !errors.Is(err, context.Canceled) {
		t.Errorf("Run() = %v with a cancelled context", err)
	}
}

func TestAFinishedLoopDoesNotRunAgain(t *testing.T) {
	st := NewState(cfg)
	run(t, st, &fakeSteps{})
	f := &fakeSteps{}
	if out := run(t, st, f); out.Kind != Passed || len(f.calls) != 0 {
		t.Errorf("Run() = %+v, calls %v; a passed loop is done", out, f.calls)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/jormungandr [github.com/ouroboric-dev/jormungandr.test]
./loop_test.go:20:14: undefined: Input
./loop_test.go:22:14: undefined: State
./loop_test.go:28:66: undefined: Input
```

- [ ] **Step 3:** write the code.

Write `loop.go`:

```go
package jormungandr

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/ouroboric-dev/gungnir"
)

// Phase is where a loop is within an attempt.
type Phase string

const (
	PhaseImplement Phase = "implement" // the attempt's implementer session has not finished
	PhaseLadder    Phase = "ladder"    // the implementer finished: the checks and reviewers judge its work
)

// Config is what a loop is made of (spec §4.2): a bound on its attempts, and the ladder of checks that
// judges each one, in order, fast to slow (spec §9.5).
type Config struct {
	Attempts int      // the most implementer attempts before the loop escalates; 3 by default in a graph
	Checks   []string // check names, in order
}

// State is everything a loop must remember to go on after it stops for a budget cap, a quota or a
// restart. Odin keeps it in run.json and saves it at every boundary, so a resume never repeats an
// attempt or loses a finding.
type State struct {
	Attempt int    `json:"attempt"`           // the attempt in progress, from 1
	Limit   int    `json:"limit"`             // the last attempt before the loop escalates
	Phase   Phase  `json:"phase"`             // where the attempt stands
	Passed  bool   `json:"passed,omitempty"`  // the loop finished: the work passed its ladder
	Book    Book   `json:"book"`              // the findings, open and closed
	Failure string `json:"failure,omitempty"` // how the last implementer session failed, for the next attempt
}

// NewState starts a loop at attempt 1.
func NewState(cfg Config) *State {
	return &State{Attempt: 1, Limit: cfg.Attempts, Phase: PhaseImplement}
}

// Input is what an implementer attempt needs besides its prompt.
type Input struct {
	Open        []gungnir.Finding // the findings to fix
	LastFailure string            // how the last implementer session ended, when it failed
}

// CheckOutcome is how one check ended on this attempt.
type CheckOutcome struct {
	Passed    bool
	FindingID string          // the id of the finding this check raises when it fails
	Finding   gungnir.Finding // when it failed: the finding
	Proof     string          // when it passed: the evidence that it ran and passed, which closes its finding
}

// Steps are the side effects of a loop, which Odin implements. A session that failed as an agent does
// returns an *AgentFailure; any other error is one the loop passes on.
type Steps interface {
	// Implement runs one implementer session, fresh, and commits what it did. The attempt counts from 1.
	Implement(ctx context.Context, attempt int, in Input) error
	// Check runs one check of the ladder on the committed work.
	Check(ctx context.Context, attempt int, name string) (CheckOutcome, error)
	// Record writes the changes to the findings to the ledger.
	Record(attempt int, changes []Change) error
	// Save keeps the loop's state, durably, before the loop goes on.
	Save(s *State) error
}

// OutcomeKind says how a run of the loop ended.
type OutcomeKind string

const (
	Passed    OutcomeKind = "passed"    // no blocking finding is open: the work may go on
	Escalated OutcomeKind = "escalated" // the loop gave up: a person decides (spec §7.3)
)

// Reasons a loop escalates.
const ReasonExhausted = "attempts-exhausted"

// Outcome is how a run of the loop ended.
type Outcome struct {
	Kind     OutcomeKind
	Attempts int // the attempt the loop ended in
	// Escalated: why, in words, and the findings still open.
	Reason string
	Detail string
	Open   []gungnir.Finding
}

// Run runs the loop from where st stands until it passes or escalates. It changes st and saves it at
// every boundary. Any other error ends the run of the loop as it is: an infrastructure failure,
// transient failures that outlasted their retries, a hard stop of Odin's, a cancelled context.
func Run(ctx context.Context, cfg Config, st *State, steps Steps) (Outcome, error) {
	if st.Passed {
		return Outcome{Kind: Passed, Attempts: st.Attempt}, nil
	}
	for {
		if err := ctx.Err(); err != nil {
			return Outcome{}, err
		}
		if st.Phase == PhaseImplement {
			if st.Attempt > st.Limit {
				return escalate(st, ReasonExhausted, exhausted(st))
			}
			if err := steps.Save(st); err != nil {
				return Outcome{}, err
			}
			err := steps.Implement(ctx, st.Attempt, Input{Open: st.Book.Open(), LastFailure: st.Failure})
			var af *AgentFailure
			switch {
			case err == nil:
				st.Failure, st.Phase = "", PhaseLadder
				if err := steps.Save(st); err != nil {
					return Outcome{}, err
				}
			case errors.As(err, &af):
				// A session that failed as an agent does is an attempt used (spec §12).
				st.Failure = af.Reason
				st.Attempt++
				continue
			default:
				return Outcome{}, err
			}
		}
		out, done, err := ladder(ctx, cfg, st, steps)
		if err != nil || done {
			return out, err
		}
		st.Attempt, st.Phase = st.Attempt+1, PhaseImplement
	}
}

// ladder judges the attempt's work. done is true when the loop ends here: it passed, escalated or
// must stop. Otherwise the work failed the ladder, and the next attempt starts.
func ladder(ctx context.Context, cfg Config, st *State, steps Steps) (out Outcome, done bool, err error) {
	var passed []string
	clear := true
	for _, name := range cfg.Checks {
		co, err := steps.Check(ctx, st.Attempt, name)
		if err != nil {
			return Outcome{}, true, err
		}
		var changes []Change
		if co.Passed {
			passed = append(passed, name)
			changes = st.Book.CheckPassed(st.Attempt, co.FindingID, co.Proof)
		} else {
			clear = false
			changes = st.Book.CheckFailed(st.Attempt, co.Finding)
		}
		// Saved with each rung, so a stop in the middle of the ladder repeats no line of the ledger.
		if err := recorded(st, steps, changes); err != nil {
			return Outcome{}, true, err
		}
		if !co.Passed {
			break // the ladder stops at the first rung that fails: the slower ones wait
		}
	}
	if clear && len(st.Book.Blocking()) == 0 {
		st.Passed = true
		if err := steps.Save(st); err != nil {
			return Outcome{}, true, err
		}
		return Outcome{Kind: Passed, Attempts: st.Attempt}, true, nil
	}
	return Outcome{}, false, nil
}

// recorded writes changes to the ledger, then saves the state that holds them.
func recorded(st *State, steps Steps, changes []Change) error {
	if err := steps.Record(st.Attempt, changes); err != nil {
		return err
	}
	return steps.Save(st)
}

func escalate(st *State, reason, detail string) (Outcome, error) {
	return Outcome{Kind: Escalated, Attempts: min(st.Attempt, st.Limit), Reason: reason, Detail: detail, Open: st.Book.Open()}, nil
}

func exhausted(st *State) string {
	var b strings.Builder
	fmt.Fprintf(&b, "%d attempts ended with %d blocking finding(s) open", st.Limit, len(st.Book.Blocking()))
	if st.Failure != "" {
		fmt.Fprintf(&b, "; the last session failed: %s", st.Failure)
	}
	return b.String()
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T123: the bounded loop: reviewers, unreadable answers, caps and quotas, and sending a loop back

The ladder's second half (spec §9.5 rung 6), the promises of spec §4.6 about a reviewer's output, and
the stops of spec §7.4 and §12 that leave the loop where it is.

**Files (in `jormungandr`):**

- Modify: `loop.go`, `loop_test.go`

**Interfaces:**

- Changes: `Config.Reviewers []string` (ids, in order); `State.Unreadable map[string]int` (answers that
  could not be used, in a row, for each reviewer); `Steps.Review(ctx, attempt int, reviewer string, open
  []gungnir.Finding, passed []string) (answer string, err error)` (one read-only session; its whole
  answer); `jormungandr.ReasonUnreadable`; `Outcome` kinds `Capped` (with `Cap`) and `Paused` (with
  `Quota`); `(*State).Extend(cfg)`, which gives an escalated loop a full set of attempts from where it
  stands and forgets the unreadable count.
- Reviewers run, in order, only when every check passed. Each answer is parsed with `ParseReport` and
  applied with `Book.Review`. An answer that does not parse, one the book refuses, and a reviewer session
  that failed as an agent are asked once more, **without a new implementer attempt**; the second time in
  a row the loop escalates with `ReasonUnreadable` and says which reviewer and why. A reviewer with a
  blocking finding stops the ladder before the next reviewer. A `*gungnir.CapError` or a `*QuotaError`
  from any step ends the run of the loop as `Capped` or `Paused`, with the state saved where it stood: a
  stop before an implementer session leaves the attempt to be done again, not used up; a stop in the
  ladder leaves the ladder to run again from its first rung and the implementer not to run.

**Acceptance criteria:**

- [ ] A reviewer's finding goes back to the next attempt and closes only when the reviewer says so, with
      proof; the next reviewer waits.
- [ ] A minor finding is recorded and does not fail the loop.
- [ ] Prose, a finding with no place, a failed session, a report that drops a finding and a close with no
      proof are each asked again once, and the second time escalate; none passes.
- [ ] A cap or a quota in an implementer session, in a reviewer session and between two asks stops the
      loop where it was, and the saved state resumes it: no attempt is used up, no finding is lost, the
      implementer does not run for a stop in the ladder, and the unreadable count survives the stop.
- [ ] An escalated loop gets attempts 4 to 6 after `Extend`, with its findings.
- [ ] A blocking finding of a source that no longer runs keeps the loop from passing.

**Named test:** `go test . -run 'TestAReviewersFinding|TestAMinorFinding|TestAReviewerThatCannot|TestAReportThatDrops|TestACapOrAQuota|TestAnEscalatedLoop|TestAnUnreadableAnswer|TestABlockingFindingFromASource'`
in `jormungandr`. **Layer:** `jormungandr`. **Size:** M (310). **Depends on:** v0-T122.

- [ ] **Step 1:** write the tests.

Apply to `loop_test.go`:

```diff
diff --git a/loop_test.go b/loop_test.go
index a4ed51d..cef7b52 100644
--- a/loop_test.go
+++ b/loop_test.go
@@ -14,15 +14,22 @@ import (
 
 // fakeSteps plays the steps of a loop from lists: each call takes the next entry for its kind.
 type fakeSteps struct {
-	implement []error           // per implementer session; nil is a success
-	check     map[string][]bool // per check: passes, per attempt that reaches it
-	calls     []string          // what ran, in order
-	inputs    []Input           // what each implementer session was given
-	changes   []Change          // everything recorded
-	saved     []State           // a copy of the state at every save
+	implement []error             // per implementer session; nil is a success
+	check     map[string][]bool   // per check: passes, per attempt that reaches it
+	review    map[string][]answer // per reviewer: its answers, in order
+	calls     []string            // what ran, in order
+	inputs    []Input             // what each implementer session was given
+	changes   []Change            // everything recorded
+	saved     []State             // a copy of the state at every save
 	saveErr   error
 	ni        int
 	nc        map[string]int
+	nr        map[string]int
+}
+
+type answer struct {
+	text string
+	err  error
 }
 
 func (f *fakeSteps) Implement(_ context.Context, attempt int, in Input) error {
@@ -53,6 +60,20 @@ func (f *fakeSteps) Check(_ context.Context, attempt int, name string) (CheckOut
 		Location: "logs/" + name + ".log:1", Claim: "check " + name + " failed", Status: gungnir.FindingOpen}}, nil
 }
 
+func (f *fakeSteps) Review(_ context.Context, attempt int, reviewer string, open []gungnir.Finding, passed []string) (string, error) {
+	f.calls = append(f.calls, fmt.Sprintf("review %d %s", attempt, reviewer))
+	if f.nr == nil {
+		f.nr = map[string]int{}
+	}
+	i := f.nr[reviewer]
+	f.nr[reviewer]++
+	as := f.review[reviewer]
+	if i >= len(as) {
+		return `{"findings":[]}`, nil
+	}
+	return as[i].text, as[i].err
+}
+
 func (f *fakeSteps) Record(_ int, changes []Change) error {
 	f.changes = append(f.changes, changes...)
 	return nil
@@ -68,7 +89,12 @@ func (f *fakeSteps) Save(s *State) error {
 
 func (f *fakeSteps) ran(call string) bool { return slices.Contains(f.calls, call) }
 
-var cfg = Config{Attempts: 3, Checks: []string{"vet", "test"}}
+func rep(fs ...gungnir.Finding) string {
+	raw, _ := json.Marshal(gungnir.Report{Findings: append([]gungnir.Finding{}, fs...)})
+	return string(raw)
+}
+
+var cfg = Config{Attempts: 3, Checks: []string{"vet", "test"}, Reviewers: []string{"spec", "quality"}}
 
 func run(t *testing.T, st *State, f *fakeSteps) Outcome {
 	t.Helper()
@@ -79,14 +105,14 @@ func run(t *testing.T, st *State, f *fakeSteps) Outcome {
 	return out
 }
 
-func TestWorkThatPassesEveryCheckPassesOnTheFirstAttempt(t *testing.T) {
+func TestWorkThatPassesTheWholeLadderPassesOnTheFirstAttempt(t *testing.T) {
 	f := &fakeSteps{}
 	st := NewState(cfg)
 	out := run(t, st, f)
 	if out.Kind != Passed || out.Attempts != 1 || !st.Passed {
 		t.Fatalf("Run() = %+v", out)
 	}
-	want := []string{"implement 1", "check 1 vet", "check 1 test"}
+	want := []string{"implement 1", "check 1 vet", "check 1 test", "review 1 spec", "review 1 quality"}
 	if !slices.Equal(f.calls, want) {
 		t.Errorf("calls = %v, want %v", f.calls, want)
 	}
@@ -95,16 +121,16 @@ func TestWorkThatPassesEveryCheckPassesOnTheFirstAttempt(t *testing.T) {
 	}
 }
 
-func TestAFailingCheckGoesBackToTheImplementerAndTheSlowerChecksWait(t *testing.T) {
+func TestAFailingCheckGoesBackToTheImplementerAndStopsTheLadder(t *testing.T) {
 	f := &fakeSteps{check: map[string][]bool{"test": {false, true}}}
 	st := NewState(cfg)
 	out := run(t, st, f)
 	if out.Kind != Passed || out.Attempts != 2 {
 		t.Fatalf("Run() = %+v", out)
 	}
-	want := []string{"implement 1", "check 1 vet", "check 1 test", "implement 2", "check 2 vet", "check 2 test"}
+	want := []string{"implement 1", "check 1 vet", "check 1 test", "implement 2", "check 2 vet", "check 2 test", "review 2 spec", "review 2 quality"}
 	if !slices.Equal(f.calls, want) {
-		t.Errorf("calls = %v\nwant    %v", f.calls, want)
+		t.Errorf("calls = %v\nwant    %v; the reviewers must not run while a check fails", f.calls, want)
 	}
 	if got := f.inputs[1].Open; len(got) != 1 || got[0].ID != "check-test" {
 		t.Errorf("attempt 2 was given %+v; it must carry the failing check's finding", f.inputs[1])
@@ -114,6 +140,40 @@ func TestAFailingCheckGoesBackToTheImplementerAndTheSlowerChecksWait(t *testing.
 	}
 }
 
+func TestAReviewersFindingIsFixedOnlyWhenTheReviewerSaysSoWithProof(t *testing.T) {
+	major := finding("spec-1", "spec", gungnir.SeverityMajor)
+	f := &fakeSteps{review: map[string][]answer{
+		"spec": {{text: rep(major)}, {text: rep(fixed(major, "api/auth.go:44 limits tries; check test passed"))}},
+	}}
+	out := run(t, NewState(cfg), f)
+	if out.Kind != Passed || out.Attempts != 2 {
+		t.Fatalf("Run() = %+v", out)
+	}
+	if got := f.inputs[1].Open; len(got) != 1 || got[0].ID != "spec-1" {
+		t.Errorf("attempt 2 was given %+v", f.inputs[1])
+	}
+	if !f.ran("review 1 spec") || f.ran("review 1 quality") {
+		t.Errorf("calls = %v; quality must wait until spec has no blocking finding", f.calls)
+	}
+	last := f.changes[len(f.changes)-1]
+	if last.Kind != Closed || last.Finding.ID != "spec-1" || last.Attempts != 2 || last.Finding.Proof == "" {
+		t.Errorf("last change = %+v", last)
+	}
+}
+
+func TestAMinorFindingIsRecordedButDoesNotFailTheLoop(t *testing.T) {
+	minor := finding("q-1", "quality", gungnir.SeverityMinor)
+	f := &fakeSteps{review: map[string][]answer{"quality": {{text: rep(minor)}}}}
+	st := NewState(cfg)
+	out := run(t, st, f)
+	if out.Kind != Passed || out.Attempts != 1 {
+		t.Fatalf("Run() = %+v", out)
+	}
+	if got := st.Book.Open(); len(got) != 1 || got[0].ID != "q-1" {
+		t.Errorf("the minor finding must stay in the book: %+v", got)
+	}
+}
+
 func TestALoopThatNeverPassesEscalatesAfterItsAttempts(t *testing.T) {
 	f := &fakeSteps{check: map[string][]bool{"test": {false, false, false, false}}}
 	st := NewState(cfg)
@@ -151,11 +211,84 @@ func TestASessionThatFailedAsAnAgentUsesUpAnAttemptAndSaysWhy(t *testing.T) {
 	}
 }
 
+func TestAReviewerThatCannotBeReadIsAskedAgainOnceAndThenTheLoopEscalates(t *testing.T) {
+	good := answer{text: `{"findings":[]}`}
+	for name, bad := range map[string]answer{
+		"prose":                   {text: "LGTM, ship it."},
+		"a finding with no place": {text: `{"findings":[{"id":"a","source":"spec","severity":"major","claim":"c","status":"open"}]}`},
+		"a failed session":        {err: &AgentFailure{Reason: "exit 1"}},
+	} {
+		f := &fakeSteps{review: map[string][]answer{"spec": {bad, good}}}
+		st := NewState(cfg)
+		out := run(t, st, f)
+		if out.Kind != Passed || f.nr["spec"] != 2 || strings.Count(strings.Join(f.calls, "\n"), "implement") != 1 {
+			t.Errorf("%s once: Run() = %+v, spec asked %d times; want a pass after asking again, without a new attempt", name, out, f.nr["spec"])
+		}
+		f = &fakeSteps{review: map[string][]answer{"spec": {bad, bad, good}}}
+		st = NewState(cfg)
+		out = run(t, st, f)
+		if out.Kind != Escalated || out.Reason != ReasonUnreadable || st.Passed || f.nr["spec"] != 2 || f.ran("review 1 quality") {
+			t.Errorf("%s twice: Run() = %+v; want an escalation: unreadable output never counts as a pass", name, out)
+		}
+		if !strings.Contains(out.Detail, "spec") {
+			t.Errorf("%s: the detail %q doesn't name the reviewer", name, out.Detail)
+		}
+	}
+}
+
+func TestAReportThatDropsAFindingIsUnreadable(t *testing.T) {
+	major := finding("spec-1", "spec", gungnir.SeverityMajor)
+	f := &fakeSteps{review: map[string][]answer{"spec": {{text: rep(major)}, {text: rep()}, {text: rep()}}}}
+	out := run(t, NewState(cfg), f)
+	if out.Kind != Escalated || out.Reason != ReasonUnreadable || !strings.Contains(out.Detail, "doesn't mention") {
+		t.Errorf("Run() = %+v; a report that makes a finding vanish must not pass", out)
+	}
+}
+
+func TestACapOrAQuotaStopsTheLoopWhereItIsAndAResumeGoesOnFromThere(t *testing.T) {
+	cap := &gungnir.CapError{Scope: gungnir.CapRun, Dimension: gungnir.CapTokens, Used: 10, Limit: 10}
+	f := &fakeSteps{implement: []error{nil, cap}, check: map[string][]bool{"test": {false}}}
+	st := NewState(cfg)
+	out := run(t, st, f)
+	if out.Kind != Capped || out.Cap != cap || out.Attempts != 2 || st.Phase != PhaseImplement || st.Attempt != 2 {
+		t.Fatalf("Run() = %+v, state %+v; want a cap during attempt 2's implementer", out, st)
+	}
+	if got := f.saved[len(f.saved)-1]; got.Attempt != 2 || got.Phase != PhaseImplement || len(got.Book.Open()) != 1 {
+		t.Errorf("the last saved state = %+v; it must hold attempt 2 and the open finding", got)
+	}
+	// The resume gets the saved state and does attempt 2 over: no attempt is used up.
+	resumed := f.saved[len(f.saved)-1]
+	g := &fakeSteps{}
+	out, err := Run(context.Background(), cfg, &resumed, g)
+	if err != nil || out.Kind != Passed || out.Attempts != 2 || g.calls[0] != "implement 2" {
+		t.Errorf("resume: %+v, %v, calls %v", out, err, g.calls)
+	}
+	if len(g.inputs[0].Open) != 1 {
+		t.Errorf("the resumed implementer lost the finding: %+v", g.inputs[0])
+	}
+
+	// A quota in the middle of the ladder: the ladder runs again from the top, and the implementer does not.
+	q := &QuotaError{Reason: "credits used up"}
+	f = &fakeSteps{review: map[string][]answer{"spec": {{err: q}}}}
+	st = NewState(cfg)
+	out = run(t, st, f)
+	if out.Kind != Paused || out.Quota != q || st.Phase != PhaseLadder {
+		t.Fatalf("Run() = %+v, state %+v", out, st)
+	}
+	resumed = f.saved[len(f.saved)-1]
+	g = &fakeSteps{}
+	out, err = Run(context.Background(), cfg, &resumed, g)
+	if err != nil || out.Kind != Passed || g.ran("implement 1") || !g.ran("check 1 vet") {
+		t.Errorf("resume: %+v, %v, calls %v; the implementer must not run again", out, err, g.calls)
+	}
+}
+
 func TestOtherErrorsEndTheRunOfTheLoopAsTheyAre(t *testing.T) {
 	infra := &gungnir.SessionError{Kind: gungnir.FailureInfra, Err: errors.New("podman is gone")}
 	for name, f := range map[string]*fakeSteps{
-		"an infrastructure failure": {implement: []error{infra}},
-		"exhausted retries":         {implement: []error{&ExhaustedError{Tries: 4, Last: "429"}}},
+		"the implementer":   {implement: []error{infra}},
+		"a reviewer":        {review: map[string][]answer{"spec": {{err: infra}}}},
+		"exhausted retries": {implement: []error{&ExhaustedError{Tries: 4, Last: "429"}}},
 	} {
 		st := NewState(cfg)
 		out, err := Run(context.Background(), cfg, st, f)
@@ -175,6 +308,25 @@ func TestOtherErrorsEndTheRunOfTheLoopAsTheyAre(t *testing.T) {
 	}
 }
 
+func TestAnEscalatedLoopGetsAFullSetOfAttemptsAfterTheOperatorSendsItBack(t *testing.T) {
+	f := &fakeSteps{check: map[string][]bool{"test": {false, false, false, false, true}}}
+	st := NewState(cfg)
+	if out := run(t, st, f); out.Kind != Escalated {
+		t.Fatalf("Run() = %+v", out)
+	}
+	st.Extend(cfg)
+	if st.Limit != 6 || st.Attempt != 4 {
+		t.Fatalf("after Extend: attempt %d, limit %d; want attempt 4, limit 6", st.Attempt, st.Limit)
+	}
+	out := run(t, st, f)
+	if out.Kind != Passed || out.Attempts != 5 {
+		t.Errorf("Run() = %+v; want a pass in attempt 5", out)
+	}
+	if got := f.inputs[len(f.inputs)-1].Open; len(got) != 1 || got[0].ID != "check-test" {
+		t.Errorf("the findings must stay across the operator's decision: %+v", got)
+	}
+}
+
 func TestAFinishedLoopDoesNotRunAgain(t *testing.T) {
 	st := NewState(cfg)
 	run(t, st, &fakeSteps{})
@@ -183,3 +335,32 @@ func TestAFinishedLoopDoesNotRunAgain(t *testing.T) {
 		t.Errorf("Run() = %+v, calls %v; a passed loop is done", out, f.calls)
 	}
 }
+
+func TestAnUnreadableAnswerIsRemembered(t *testing.T) {
+	// The count of unreadable answers survives a stop between the two asks, so a resume does not give
+	// a reviewer a third chance.
+	cap := &gungnir.CapError{Scope: gungnir.CapDay, Dimension: gungnir.CapTurns, Used: 1, Limit: 1}
+	f := &fakeSteps{review: map[string][]answer{"spec": {{text: "prose"}, {err: cap}}}}
+	st := NewState(cfg)
+	if out := run(t, st, f); out.Kind != Capped || st.Unreadable["spec"] != 1 {
+		t.Fatalf("Run() = %+v, unreadable %v", out, st.Unreadable)
+	}
+	resumed := f.saved[len(f.saved)-1]
+	g := &fakeSteps{review: map[string][]answer{"spec": {{text: "more prose"}}}}
+	out, err := Run(context.Background(), cfg, &resumed, g)
+	if err != nil || out.Kind != Escalated || out.Reason != ReasonUnreadable {
+		t.Errorf("Run() = %+v, %v; the second unreadable answer, across a stop, must escalate", out, err)
+	}
+}
+
+func TestABlockingFindingFromASourceThatNoLongerRunsKeepsTheLoopFromPassing(t *testing.T) {
+	// A state carried over from a ladder with another reviewer in it: nobody can close its finding now,
+	// and the work must not pass over it.
+	st := NewState(cfg)
+	st.Book.CheckFailed(1, finding("ghost-1", "ghost", gungnir.SeverityMajor))
+	f := &fakeSteps{}
+	out := run(t, st, f)
+	if out.Kind == Passed || st.Passed {
+		t.Errorf("Run() = %+v; a loop passed with a blocking finding open", out)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/jormungandr [github.com/ouroboric-dev/jormungandr.test]
./loop_test.go:97:64: unknown field Reviewers in struct literal of type Config
./loop_test.go:230:45: undefined: ReasonUnreadable
./loop_test.go:243:44: undefined: ReasonUnreadable
```

- [ ] **Step 3:** write the code.

Apply to `loop.go`:

```diff
diff --git a/loop.go b/loop.go
index c9afd99..bfc48cb 100644
--- a/loop.go
+++ b/loop.go
@@ -7,6 +7,7 @@ import (
 	"strings"
 
 	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/gungnir/schema"
 )
 
 // Phase is where a loop is within an attempt.
@@ -17,23 +18,25 @@ const (
 	PhaseLadder    Phase = "ladder"    // the implementer finished: the checks and reviewers judge its work
 )
 
-// Config is what a loop is made of (spec §4.2): a bound on its attempts, and the ladder of checks that
-// judges each one, in order, fast to slow (spec §9.5).
+// Config is what a loop is made of (spec §4.2): a bound on its attempts, and the ladder of checks and
+// reviewers that judge each one, in order, fast to slow (spec §9.5).
 type Config struct {
-	Attempts int      // the most implementer attempts before the loop escalates; 3 by default in a graph
-	Checks   []string // check names, in order
+	Attempts  int      // the most implementer attempts before the loop escalates; 3 by default in a graph
+	Checks    []string // check names, in order
+	Reviewers []string // reviewer ids, in order; they run only when every check passed
 }
 
 // State is everything a loop must remember to go on after it stops for a budget cap, a quota or a
 // restart. Odin keeps it in run.json and saves it at every boundary, so a resume never repeats an
 // attempt or loses a finding.
 type State struct {
-	Attempt int    `json:"attempt"`           // the attempt in progress, from 1
-	Limit   int    `json:"limit"`             // the last attempt before the loop escalates
-	Phase   Phase  `json:"phase"`             // where the attempt stands
-	Passed  bool   `json:"passed,omitempty"`  // the loop finished: the work passed its ladder
-	Book    Book   `json:"book"`              // the findings, open and closed
-	Failure string `json:"failure,omitempty"` // how the last implementer session failed, for the next attempt
+	Attempt    int            `json:"attempt"`              // the attempt in progress, from 1
+	Limit      int            `json:"limit"`                // the last attempt before the loop escalates
+	Phase      Phase          `json:"phase"`                // where the attempt stands
+	Passed     bool           `json:"passed,omitempty"`     // the loop finished: the work passed its ladder
+	Book       Book           `json:"book"`                 // the findings, open and closed
+	Failure    string         `json:"failure,omitempty"`    // how the last implementer session failed, for the next attempt
+	Unreadable map[string]int `json:"unreadable,omitempty"` // reviewer id: unreadable answers in a row
 }
 
 // NewState starts a loop at attempt 1.
@@ -41,6 +44,13 @@ func NewState(cfg Config) *State {
 	return &State{Attempt: 1, Limit: cfg.Attempts, Phase: PhaseImplement}
 }
 
+// Extend gives an escalated loop another full set of attempts, after an operator sent the work back
+// (spec §7.3). The findings stay, and a reviewer that was unreadable is asked again.
+func (s *State) Extend(cfg Config) {
+	s.Limit = max(s.Limit, s.Attempt+cfg.Attempts-1)
+	s.Unreadable = nil
+}
+
 // Input is what an implementer attempt needs besides its prompt.
 type Input struct {
 	Open        []gungnir.Finding // the findings to fix
@@ -55,13 +65,17 @@ type CheckOutcome struct {
 	Proof     string          // when it passed: the evidence that it ran and passed, which closes its finding
 }
 
-// Steps are the side effects of a loop, which Odin implements. A session that failed as an agent does
-// returns an *AgentFailure; any other error is one the loop passes on.
+// Steps are the side effects of a loop, which Odin implements. A step that stops the loop for a budget
+// cap or a quota returns a *gungnir.CapError or a *QuotaError; a session that failed as an agent does
+// returns an *AgentFailure; anything else is an error the loop passes on.
 type Steps interface {
 	// Implement runs one implementer session, fresh, and commits what it did. The attempt counts from 1.
 	Implement(ctx context.Context, attempt int, in Input) error
 	// Check runs one check of the ladder on the committed work.
 	Check(ctx context.Context, attempt int, name string) (CheckOutcome, error)
+	// Review runs one read-only reviewer and returns its whole answer. open is what it reported
+	// before and still holds open; passed lists the checks that passed on this attempt.
+	Review(ctx context.Context, attempt int, reviewer string, open []gungnir.Finding, passed []string) (string, error)
 	// Record writes the changes to the findings to the ledger.
 	Record(attempt int, changes []Change) error
 	// Save keeps the loop's state, durably, before the loop goes on.
@@ -74,10 +88,15 @@ type OutcomeKind string
 const (
 	Passed    OutcomeKind = "passed"    // no blocking finding is open: the work may go on
 	Escalated OutcomeKind = "escalated" // the loop gave up: a person decides (spec §7.3)
+	Capped    OutcomeKind = "capped"    // a budget cap is reached: the run stops at budget-cap, resumable
+	Paused    OutcomeKind = "paused"    // the provider's quota is used up: the run pauses, resumable
 )
 
 // Reasons a loop escalates.
-const ReasonExhausted = "attempts-exhausted"
+const (
+	ReasonExhausted  = "attempts-exhausted"
+	ReasonUnreadable = "reviewer-unreadable"
+)
 
 // Outcome is how a run of the loop ended.
 type Outcome struct {
@@ -87,11 +106,14 @@ type Outcome struct {
 	Reason string
 	Detail string
 	Open   []gungnir.Finding
+	// Capped: the cap. Paused: the quota.
+	Cap   *gungnir.CapError
+	Quota *QuotaError
 }
 
-// Run runs the loop from where st stands until it passes or escalates. It changes st and saves it at
-// every boundary. Any other error ends the run of the loop as it is: an infrastructure failure,
-// transient failures that outlasted their retries, a hard stop of Odin's, a cancelled context.
+// Run runs the loop from where st stands until it passes, escalates, or must stop. It changes st and
+// saves it at every boundary. Any other error ends the run of the loop as it is: an infrastructure
+// failure, transient failures that outlasted their retries, a hard stop of Odin's, a cancelled context.
 func Run(ctx context.Context, cfg Config, st *State, steps Steps) (Outcome, error) {
 	if st.Passed {
 		return Outcome{Kind: Passed, Attempts: st.Attempt}, nil
@@ -121,14 +143,14 @@ func Run(ctx context.Context, cfg Config, st *State, steps Steps) (Outcome, erro
 				st.Attempt++
 				continue
 			default:
-				return Outcome{}, err
+				return stopped(st, err)
 			}
 		}
 		out, done, err := ladder(ctx, cfg, st, steps)
 		if err != nil || done {
 			return out, err
 		}
-		st.Attempt, st.Phase = st.Attempt+1, PhaseImplement
+		st.Attempt, st.Phase, st.Unreadable = st.Attempt+1, PhaseImplement, nil
 	}
 }
 
@@ -158,6 +180,18 @@ func ladder(ctx context.Context, cfg Config, st *State, steps Steps) (out Outcom
 			break // the ladder stops at the first rung that fails: the slower ones wait
 		}
 	}
+	for _, rv := range cfg.Reviewers {
+		if !clear {
+			break
+		}
+		out, stop, err := review(ctx, st, steps, rv, passed)
+		if err != nil || stop {
+			return out, true, err
+		}
+		if blockingFrom(st, rv) {
+			clear = false
+		}
+	}
 	if clear && len(st.Book.Blocking()) == 0 {
 		st.Passed = true
 		if err := steps.Save(st); err != nil {
@@ -176,6 +210,69 @@ func recorded(st *State, steps Steps, changes []Change) error {
 	return steps.Save(st)
 }
 
+func blockingFrom(st *State, reviewer string) bool {
+	for _, f := range st.Book.Blocking() {
+		if f.Source == reviewer {
+			return true
+		}
+	}
+	return false
+}
+
+// review asks one reviewer, and asks it once more if its answer can't be used: an answer that does not
+// parse, one that drops a finding, one that closes a finding without proof, or a session that failed.
+// Neither runs the implementer again. Twice in a row, the loop escalates (spec §4.6). stop is true when
+// the loop ends here.
+func review(ctx context.Context, st *State, steps Steps, rv string, passed []string) (out Outcome, stop bool, err error) {
+	for {
+		answer, err := steps.Review(ctx, st.Attempt, rv, st.Book.OpenFrom(rv), passed)
+		var af *AgentFailure
+		var why error
+		switch {
+		case err == nil:
+			report, perr := schema.ParseReport([]byte(answer))
+			if perr == nil {
+				changes, rerr := st.Book.Review(st.Attempt, rv, passed, report)
+				if rerr == nil {
+					delete(st.Unreadable, rv)
+					return Outcome{}, false, recorded(st, steps, changes)
+				}
+				perr = rerr
+			}
+			why = perr
+		case errors.As(err, &af):
+			why = af
+		default:
+			o, err := stopped(st, err)
+			return o, true, err
+		}
+		if st.Unreadable == nil {
+			st.Unreadable = map[string]int{}
+		}
+		st.Unreadable[rv]++
+		if err := steps.Save(st); err != nil {
+			return Outcome{}, true, err
+		}
+		if st.Unreadable[rv] >= 2 {
+			o, err := escalate(st, ReasonUnreadable, fmt.Sprintf("reviewer %s gave an answer that can't be used twice in a row; the last time: %v", rv, why))
+			return o, true, err
+		}
+	}
+}
+
+// stopped turns a budget cap or a used-up quota into the loop's outcome, with the state saved; any
+// other error is the caller's.
+func stopped(st *State, err error) (Outcome, error) {
+	var q *QuotaError
+	switch c, isCap := IsCap(err); {
+	case isCap:
+		return Outcome{Kind: Capped, Attempts: st.Attempt, Cap: c}, nil
+	case errors.As(err, &q):
+		return Outcome{Kind: Paused, Attempts: st.Attempt, Quota: q}, nil
+	}
+	return Outcome{}, err
+}
+
 func escalate(st *State, reason, detail string) (Outcome, error) {
 	return Outcome{Kind: Escalated, Attempts: min(st.Attempt, st.Limit), Reason: reason, Detail: detail, Open: st.Book.Open()}, nil
 }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T124: Jormungandr's documentation

The architecture page and the README say what the module does now. A reference page (the docs
standard's `style: reference`), no test.

**Files (in `jormungandr`):**

- Modify: `README.md`, `docs/architecture.md`

**Acceptance criteria:**

- [ ] `docs/architecture.md` says what Jormungandr does, how a loop runs, and what it leaves to Odin; its
      front matter is as before, with the plan in `related`.
- [ ] `README.md` says what the module is and who calls it.

**Named test:** none: `reuse lint` passes. **Layer:** `jormungandr`. **Size:** S (34).
**Depends on:** v0-T123.

- [ ] **Step 1:** apply the files below.

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 677f625..1893582 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -2,7 +2,7 @@
 title: Jormungandr architecture
 status: draft
 date: 2026-10-12
-related: [https://github.com/ouroboric-dev/yggdrasil/blob/main/docs/2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md]
+related: [https://github.com/ouroboric-dev/yggdrasil/blob/main/docs/2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md, https://github.com/ouroboric-dev/yggdrasil/blob/main/docs/2-engineering/plans/2026-10-16-yggdrasil-v0-phase-4/tasks.md]
 style: reference
 ---
 
@@ -12,10 +12,32 @@ The loop: build, check and fix with attempts, backoff, budgets, feedback and esc
 
 ## Responsibilities
 
-- Runs a bounded loop: implement, run the check ladder, feed failures back and retry, up to N
-  attempts (default 3).
-- Escalates when the attempts run out (spec §7.3).
-- Enforces per-loop budgets.
+- Runs a bounded loop (`Run`): an implementer works, a ladder of checks and read-only reviewers judges
+  the work, the findings that are still open go back to the next attempt, and after N attempts (3 by
+  default) the loop escalates (spec §4.2, §7.3).
+- Keeps the findings (`Book`). A finding closes only when its source confirms the fix: a check that
+  passes, or a reviewer's report that carries proof, a `file:line` and the name of a check that passed.
+  The implementer's claim never closes one (spec §4.6).
+- Treats a reviewer's answer that can't be used as a failure, never a pass: it asks the reviewer once
+  more, and then escalates (spec §4.6).
+- Decides what a failed session means (`Classify`, `Retrier`): a transient failure is retried with a
+  backoff and is not a loop attempt, a used-up quota pauses the run, an infrastructure failure stops
+  it, and anything else counts as a loop attempt (spec §12).
+- Asks the budget before every session, so none starts over a cap (spec §7.4).
+
+## How a loop runs
+
+Each attempt has two phases. In `implement`, one fresh implementer session gets the open findings and
+commits its work. In `ladder`, the checks run in order and stop at the first that fails; the reviewers
+run only when every check passed, in order, and each is told what it reported before and which checks
+passed. The loop passes when no blocker or major finding is open. Its state (`State`) is plain data,
+saved at every boundary, so a stop for a cap or a quota, or a crash, repeats no attempt and loses no
+finding.
+
+## What it does not do
+
+It runs no session, no command and no git, and writes no ledger line. Odin gives it the `Steps` that
+do, and it decides what comes next.
 
 ## Depends on
 
@@ -23,4 +45,5 @@ The loop: build, check and fix with attempts, backoff, budgets, feedback and esc
 
 ## Source
 
-The v0 engineering spec, §2.1, §4.2, §7.3. When this page and the spec differ, the spec wins.
+The v0 engineering spec, §2.1, §4.2, §4.6, §7.3, §7.4, §12. When this page and the spec differ, the
+spec wins.
```

````diff
diff --git a/README.md b/README.md
index 2e69088..cf994f4 100644
--- a/README.md
+++ b/README.md
@@ -6,6 +6,11 @@ Part of [Yggdrasil](https://github.com/ouroboric-dev/yggdrasil), the software fa
 [Ouroboric](https://github.com/ouroboric-dev/ouroboric). Work on it from the Yggdrasil umbrella,
 which holds every component as a submodule and builds them together through `go.work`.
 
+## What it is
+
+A Go package, `github.com/ouroboric-dev/jormungandr`. Odin calls `jormungandr.Run` for every loop node
+of a graph, and `Retrier.Do` for every agent session.
+
 ## Build and test
 
 ```bash
````

- [ ] **Step 2:** run `uvx -q --from 'reuse==5.0.2' reuse lint -q`; it prints nothing.
- [ ] **Step 3:** commit (see "How each task lands").

When `jormungandr`'s last task is committed, push and open its pull request (see "How each task
lands"). It needs `gungnir`'s merged and pinned; `jormungandr` has no CI yet (v0-H10).

---

### Task v0-T125: `escalation` in the mode table

Odin's first task. The mode × approval-point table (spec §7.1) is a function of Odin's, and a test walks
every approval point Gungnir knows. Branch `loop/phase-4` from `main` in `odin`, before step 1, once
`gungnir`, `gleipnir` and `jormungandr` are merged and pinned (see "How each task lands"). Odin's tasks
all need those three; the *Depends on* column names what each one uses.

**Files (in `odin`):**

- Modify: `internal/gate/decide.go`, `internal/gate/decide_test.go`

**Interfaces:**

- Consumes: `gungnir.GateEscalation` (v0-T101).
- Changes: `gate.Decide` returns `Stop` for `escalation` in every mode, whatever the overrides say about
  it (decision 7). The table test, which walks `gungnir.Gates()`, gets the row.

**Acceptance criteria:**

- [ ] `escalation` stops in step-by-step, key-points and unattended mode.

**Named test:** `go test ./internal/gate -run TestModeTimesApprovalPointTable` in `odin`. **Layer:**
`odin`. **Size:** S (7). **Depends on:** v0-T101 merged.

- [ ] **Step 1:** write the tests.

Apply to `internal/gate/decide_test.go`:

```diff
diff --git a/internal/gate/decide_test.go b/internal/gate/decide_test.go
index 1c303a1..3c072d7 100644
--- a/internal/gate/decide_test.go
+++ b/internal/gate/decide_test.go
@@ -18,6 +18,7 @@ func TestModeTimesApprovalPointTable(t *testing.T) {
 		"merge":            {Stop, Auto, Auto},
 		"pointer":          {Stop, Auto, Auto},
 		"pointer-contract": {Stop, Stop, Block},
+		"escalation":       {Stop, Stop, Stop},
 	}
 	for _, g := range gungnir.Gates() {
 		want, soft := table[g]
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestModeTimesApprovalPointTable (0.00s)
    decide_test.go:34: escalation: got {stop auto auto}, want {stop stop stop}
FAIL
FAIL	github.com/ouroboric-dev/odin/internal/gate	0.002s
```

- [ ] **Step 3:** write the code.

Apply to `internal/gate/decide.go`:

```diff
diff --git a/internal/gate/decide.go b/internal/gate/decide.go
index 7a1b37b..364c379 100644
--- a/internal/gate/decide.go
+++ b/internal/gate/decide.go
@@ -25,6 +25,12 @@ func Decide(mode gungnir.Mode, g gungnir.Gate, overrides map[gungnir.Gate]string
 	if !g.Known() || g.Hard() || mode == gungnir.ModeStepByStep || overrides[g] == "stop" {
 		return Stop
 	}
+	if g == gungnir.GateEscalation {
+		// A loop that ran out of attempts waits for a person in every mode. Unattended mode would mark
+		// the task blocked and go on with the rest (spec §7.3), but a linear graph has nothing else to
+		// do, so the run stops there too (Phase 4, decision 7).
+		return Stop
+	}
 	switch g {
 	case gungnir.GateDesign:
 		if mode == gungnir.ModeUnattended && overrides[g] == "auto" {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T126: the spend journal

Decision 5. Every session's usage goes into a file outside every project, one file for each day of the
operator's, so the per-day cap can add up what every run spent.

**Files (in `odin`):**

- Create: `internal/budget/budget_test.go`, `internal/budget/journal.go`

**Interfaces:**

- Produces: package `budget`: `budget.Entry{Time; Run, Project, Node string; Usage gungnir.Usage}`;
  `budget.Journal{Dir string; Now func() time.Time; Loc *time.Location}`; `budget.DefaultDir(getenv
  func(string) string, home func() (string, error)) (string, error)` (`$XDG_STATE_HOME/ygg/spend` when
  that is absolute, else `~/.local/state/ygg/spend`, else an error that says to set `budget.journal`);
  `(*Journal).Append(Entry) error` (one `O_APPEND` write, synced, file mode 0600, folder 0700);
  `(*Journal).Day(t) (gungnir.Usage, error)` (the sum of the day `t` falls in); `File(t) string`;
  `Today()`, `Date()`.
- `Day` ignores a last line that has no newline (a write a crash cut short) and returns an error that
  names the file and the line for any other line that is not an entry, a negative or non-finite figure
  included.

**Acceptance criteria:**

- [ ] The day adds up every run's sessions; tomorrow starts at zero; the file is private.
- [ ] A day ends at the operator's midnight, not UTC's.
- [ ] Twenty goroutines appending 25 lines each give 500 whole lines.
- [ ] A torn last line is ignored; a bad line in the middle, or an entry with an unknown field, is an
      error that names the line.
- [ ] The default folder follows `XDG_STATE_HOME`, then the home; a relative `XDG_STATE_HOME` is ignored,
      and with neither there is an error.

**Named test:** `go test ./internal/budget -run 'TestTheDay|TestADayEnds|TestRunsAppending|TestACutShort|TestTheDefaultFolder'`
in `odin`. **Layer:** `odin`. **Size:** M (255). **Depends on:** Phase 3.

- [ ] **Step 1:** write the tests.

Write `internal/budget/budget_test.go`:

```go
package budget

import (
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

func journal(t *testing.T, now time.Time) *Journal {
	t.Helper()
	return &Journal{Dir: filepath.Join(t.TempDir(), "spend"), Now: func() time.Time { return now }, Loc: time.UTC}
}

var noon = time.Date(2026, 10, 16, 12, 0, 0, 0, time.UTC)

func entry(run string, in, turns int64) Entry {
	return Entry{Run: run, Project: "/p", Node: "build", Usage: gungnir.Usage{InTok: in, OutTok: 1, Turns: turns, CostUSD: 0.5}}
}

func TestTheDaySumsEverySessionOfEveryRun(t *testing.T) {
	j := journal(t, noon)
	for _, e := range []Entry{entry("20261016-090000-aaaaaa", 100, 2), entry("20261016-100000-bbbbbb", 50, 1)} {
		if err := j.Append(e); err != nil {
			t.Fatal(err)
		}
	}
	got, err := j.Day(noon)
	if err != nil || got.InTok != 150 || got.OutTok != 2 || got.Turns != 3 || got.CostUSD != 1 {
		t.Errorf("Day() = %+v, %v", got, err)
	}
	if fi, err := os.Stat(filepath.Join(j.Dir, "2026-10-16.jsonl")); err != nil || fi.Mode().Perm() != 0o600 {
		t.Errorf("the journal file = %v, %v; want 0600", fi, err)
	}
	if got, err := j.Day(noon.Add(24 * time.Hour)); err != nil || got != (gungnir.Usage{}) {
		t.Errorf("tomorrow = %+v, %v; a new day starts at zero", got, err)
	}
}

func TestADayEndsAtTheOperatorsMidnight(t *testing.T) {
	zone := time.FixedZone("UTC-3", -3*3600)
	j := &Journal{Dir: t.TempDir(), Loc: zone}
	late := time.Date(2026, 10, 16, 23, 30, 0, 0, zone) // 02:30 UTC on the 17th
	early := time.Date(2026, 10, 17, 0, 30, 0, 0, zone) // 03:30 UTC on the 17th
	for _, tm := range []time.Time{late, early} {
		e := entry("20261016-090000-aaaaaa", 10, 1)
		e.Time = tm
		if err := j.Append(e); err != nil {
			t.Fatal(err)
		}
	}
	if got, _ := j.Day(late); got.InTok != 10 {
		t.Errorf("the 16th = %+v; 23:30 local belongs to the 16th although it is the 17th in UTC", got)
	}
	if got, _ := j.Day(early); got.InTok != 10 {
		t.Errorf("the 17th = %+v", got)
	}
}

func TestRunsAppendingAtOnceNeverMixTheirLines(t *testing.T) {
	j := journal(t, noon)
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for k := 0; k < 25; k++ {
				if err := j.Append(entry("20261016-090000-aaaaaa", 1, 1)); err != nil {
					t.Error(err)
				}
			}
		}()
	}
	wg.Wait()
	if got, err := j.Day(noon); err != nil || got.InTok != 500 {
		t.Errorf("Day() = %+v, %v; want 500 tokens from 500 whole lines", got, err)
	}
}

func TestACutShortLastLineIsIgnoredAndAnyOtherBadLineStopsTheCount(t *testing.T) {
	j := journal(t, noon)
	j.Append(entry("20261016-090000-aaaaaa", 100, 1))
	f, _ := os.OpenFile(j.File(noon), os.O_APPEND|os.O_WRONLY, 0o600)
	f.WriteString(`{"time":"2026-10-16T12:00:00Z","run":"20261016-0900`) // a crash in the middle of a write
	f.Close()
	if got, err := j.Day(noon); err != nil || got.InTok != 100 {
		t.Fatalf("Day() = %+v, %v; the torn last line is ignored", got, err)
	}
	f, _ = os.OpenFile(j.File(noon), os.O_APPEND|os.O_WRONLY, 0o600)
	f.WriteString("\n" + `{"usage":{"in_tok":-5}}` + "\n")
	f.Close()
	if _, err := j.Day(noon); err == nil || !strings.Contains(err.Error(), "2026-10-16.jsonl:2") {
		t.Errorf("Day() = %v; a bad line in the middle must be an error that names it", err)
	}
	// An entry with a field Odin never writes is not Odin's.
	k := journal(t, noon)
	os.MkdirAll(k.Dir, 0o700)
	os.WriteFile(k.File(noon), []byte(`{"time":"2026-10-16T12:00:00Z","run":"r","project":"/p","node":"n","usage":{},"free":"text"}`+"\n"), 0o600)
	if _, err := k.Day(noon); err == nil {
		t.Error("an entry with an unknown field was counted")
	}
}

func TestTheDefaultFolderFollowsXDGThenHome(t *testing.T) {
	env := func(m map[string]string) func(string) string { return func(k string) string { return m[k] } }
	home := func() (string, error) { return "/home/ana", nil }
	if got, err := DefaultDir(env(map[string]string{"XDG_STATE_HOME": "/state"}), home); err != nil || got != "/state/ygg/spend" {
		t.Errorf("with XDG_STATE_HOME: %q, %v", got, err)
	}
	if got, err := DefaultDir(env(nil), home); err != nil || got != "/home/ana/.local/state/ygg/spend" {
		t.Errorf("without it: %q, %v", got, err)
	}
	if got, err := DefaultDir(env(map[string]string{"XDG_STATE_HOME": "relative"}), home); err != nil || got != "/home/ana/.local/state/ygg/spend" {
		t.Errorf("with a relative XDG_STATE_HOME: %q, %v; the XDG rule ignores it", got, err)
	}
	if _, err := DefaultDir(env(nil), func() (string, error) { return "", os.ErrNotExist }); err == nil {
		t.Error("no home and no XDG_STATE_HOME: DefaultDir() = nil error")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/budget [github.com/ouroboric-dev/odin/internal/budget.test]
internal/budget/budget_test.go:14:44: undefined: Journal
internal/budget/budget_test.go:16:10: undefined: Journal
internal/budget/budget_test.go:21:41: undefined: Entry
```

- [ ] **Step 3:** write the code.

Write `internal/budget/journal.go`:

```go
// Package budget keeps the factory's spend and decides when a cap is reached (spec §7.4). Every
// session's usage is appended to a journal, one file per day, outside any project: the per-day cap
// counts what every run of the operator spent that day, in every project, because the operator's
// subscription is one (Phase 4, decision 5).
package budget

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

// Entry is one line of the journal: one session's usage.
type Entry struct {
	Time    time.Time     `json:"time"`
	Run     string        `json:"run"`
	Project string        `json:"project"`
	Node    string        `json:"node"`
	Usage   gungnir.Usage `json:"usage"`
}

// Journal is the folder of daily spend files, YYYY-MM-DD.jsonl.
type Journal struct {
	Dir string
	// Now is the time of an entry; time.Now by default. Loc is the operator's day: a day ends at
	// midnight there, time.Local by default.
	Now func() time.Time
	Loc *time.Location
}

// DefaultDir is where the journal lives when factory.yaml sets none: $XDG_STATE_HOME/ygg/spend, or
// ~/.local/state/ygg/spend. It is an error when neither can be found, since a spend that can't be
// recorded can't be capped.
func DefaultDir(getenv func(string) string, home func() (string, error)) (string, error) {
	if x := getenv("XDG_STATE_HOME"); filepath.IsAbs(x) {
		return filepath.Join(x, "ygg", "spend"), nil
	}
	h, err := home()
	if err != nil || !filepath.IsAbs(h) {
		return "", errors.New("can't find the operator's state folder: set budget.journal in factory.yaml to an absolute folder")
	}
	return filepath.Join(h, ".local", "state", "ygg", "spend"), nil
}

func (j *Journal) now() time.Time {
	if j.Now != nil {
		return j.Now()
	}
	return time.Now()
}

func (j *Journal) loc() *time.Location {
	if j.Loc != nil {
		return j.Loc
	}
	return time.Local
}

// File returns the journal file of the day t falls in.
func (j *Journal) File(t time.Time) string {
	return filepath.Join(j.Dir, t.In(j.loc()).Format("2006-01-02")+".jsonl")
}

// Append records one session's usage, now. The line is written with one write to a file opened for
// appending, and synced, so lines from runs going at once never mix and a crash loses nothing that
// was returned.
func (j *Journal) Append(e Entry) error {
	if e.Time.IsZero() {
		e.Time = j.now().UTC()
	}
	line, err := json.Marshal(e)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(j.Dir, 0o700); err != nil {
		return err
	}
	f, err := os.OpenFile(j.File(e.Time), os.O_WRONLY|os.O_APPEND|os.O_CREATE, 0o600)
	if err != nil {
		return err
	}
	defer f.Close()
	if _, err := f.Write(append(line, '\n')); err != nil {
		return err
	}
	return f.Sync()
}

// Day adds up the usage recorded on the day t falls in. A last line cut short, which a crash leaves,
// is ignored; any other line that is not an entry is an error, because a sum that skips lines would
// under-count the spend, and a cap must err the other way.
func (j *Journal) Day(t time.Time) (gungnir.Usage, error) {
	var sum gungnir.Usage
	path := j.File(t)
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return sum, nil
	}
	if err != nil {
		return sum, err
	}
	lines := bytes.Split(data, []byte("\n"))
	if last := len(lines) - 1; len(lines[last]) > 0 {
		lines = lines[:last] // no newline after it: the write was cut short
	}
	for i, line := range lines {
		if len(line) == 0 {
			continue
		}
		dec := json.NewDecoder(bytes.NewReader(line))
		dec.DisallowUnknownFields()
		var e Entry
		if err := dec.Decode(&e); err != nil || !finite(e.Usage) {
			return sum, fmt.Errorf("%s:%d is not a spend entry; fix or remove the line", path, i+1)
		}
		sum = sum.Add(e.Usage)
	}
	return sum, nil
}

// finite reports whether u is a usage a session could have had.
func finite(u gungnir.Usage) bool {
	return u.InTok >= 0 && u.OutTok >= 0 && u.CacheTok >= 0 && u.Turns >= 0 &&
		u.CostUSD >= 0 && !math.IsNaN(u.CostUSD) && !math.IsInf(u.CostUSD, 0)
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T127: the meter

Spec §7.4. The meter answers one question for Jormungandr: is a cap reached, the run's or the day's?

**Files (in `odin`):**

- Create: `internal/budget/meter.go`, `internal/budget/meter_test.go`

**Interfaces:**

- Consumes: `schema.Cap.Reached`, `gungnir.CapError`, `gungnir.CapJournal` (v0-T098, v0-T104), `Journal`.
- Produces: `budget.Meter{Run *gungnir.Usage; Caps schema.Budget; USD bool; Journal *Journal}`,
  a `gungnir.Meter`. `Check()` is the run's cap first, then the day's from the journal; a journal that
  can't be read is a `CapJournal` error, a cap reached. `RemainingTurns() int64` is the lesser of the
  run's and the day's turns left, never below zero, and zero when the journal can't be read.
  `Near(frac) []gungnir.CapError` lists the caps at least `frac` used and not reached. `Today()`.

**Acceptance criteria:**

- [ ] The meter stops at the run's cap, then at the day's, which other runs' spending can reach; a new day
      has room again.
- [ ] Dollars count only for a paid API.
- [ ] An unreadable journal is a reached cap that says why, and leaves no turns.
- [ ] Turns left are the lesser of the run's and the day's; `Near(0.8)` lists what is over 80% and not
      reached.

**Named test:** `go test ./internal/budget -run 'TestTheMeter|TestTheDollarCap|TestAJournalThatCannotBeRead|TestTheTurnsLeft|TestNear'`
in `odin`. **Layer:** `odin`. **Size:** M (167). **Depends on:** v0-T126; v0-T104 merged.

- [ ] **Step 1:** write the tests.

Write `internal/budget/meter_test.go`:

```go
package budget

import (
	"os"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

func meter(t *testing.T, run *gungnir.Usage, usd bool) (*Meter, *Journal) {
	j := journal(t, noon)
	return &Meter{Run: run, Journal: j, USD: usd, Caps: schema.Budget{
		PerRun: schema.Cap{Tokens: 1000, Turns: 10, USD: 5}, PerDay: schema.Cap{Tokens: 3000, Turns: 30, USD: 20}}}, j
}

func TestTheMeterStopsAtTheRunsCapThenTheDays(t *testing.T) {
	run := &gungnir.Usage{}
	m, j := meter(t, run, false)
	if hit := m.Check(); hit != nil {
		t.Fatalf("Check() = %v on an empty run", hit)
	}
	run.InTok = 1000
	if hit := m.Check(); hit == nil || hit.Scope != gungnir.CapRun || hit.Dimension != gungnir.CapTokens {
		t.Errorf("Check() = %v, want the run's token cap", hit)
	}
	run.InTok = 10
	j.Append(entry("20261016-090000-aaaaaa", 2999, 5)) // other runs spent the day's tokens: 2999 and 1 out
	if hit := m.Check(); hit == nil || hit.Scope != gungnir.CapDay || hit.Dimension != gungnir.CapTokens {
		t.Errorf("Check() = %v, want the day's token cap, reached by other runs", hit)
	}
	m.Journal = journal(t, noon.Add(24*time.Hour)) // tomorrow
	if hit := m.Check(); hit != nil {
		t.Errorf("Check() = %v on a new day", hit)
	}
}

func TestTheDollarCapCountsOnlyForAPaidAPI(t *testing.T) {
	run := &gungnir.Usage{CostUSD: 5}
	m, _ := meter(t, run, false)
	if hit := m.Check(); hit != nil {
		t.Errorf("Check() = %v; a subscription's dollars are only a figure", hit)
	}
	m.USD = true
	if hit := m.Check(); hit == nil || hit.Dimension != gungnir.CapUSD {
		t.Errorf("Check() = %v, want the dollar cap", hit)
	}
}

func TestAJournalThatCannotBeReadStopsTheRunAndSaysWhy(t *testing.T) {
	m, j := meter(t, &gungnir.Usage{}, false)
	os.MkdirAll(j.Dir, 0o700)
	os.WriteFile(j.File(noon), []byte("garbage\nmore garbage\n"), 0o600)
	hit := m.Check()
	if hit == nil || hit.Dimension != gungnir.CapJournal || !strings.Contains(hit.Error(), "2026-10-16.jsonl:1") {
		t.Errorf("Check() = %v; an unreadable journal must count as a reached cap", hit)
	}
	if m.RemainingTurns() != 0 {
		t.Errorf("RemainingTurns() = %d, want 0", m.RemainingTurns())
	}
}

func TestTheTurnsLeftAreTheLesserOfTheRunsAndTheDays(t *testing.T) {
	run := &gungnir.Usage{Turns: 4}
	m, j := meter(t, run, false)
	if got := m.RemainingTurns(); got != 6 {
		t.Errorf("RemainingTurns() = %d, want 6 (the run's)", got)
	}
	j.Append(entry("20261016-090000-aaaaaa", 1, 27))
	if got := m.RemainingTurns(); got != 3 {
		t.Errorf("RemainingTurns() = %d, want 3 (the day's)", got)
	}
	run.Turns = 99
	if got := m.RemainingTurns(); got != 0 {
		t.Errorf("RemainingTurns() = %d, want 0, never negative", got)
	}
}

func TestNearListsTheCapsOverEightyPercentAndNotYetReached(t *testing.T) {
	run := &gungnir.Usage{InTok: 850, Turns: 10, CostUSD: 4.5}
	m, _ := meter(t, run, true)
	var got []string
	for _, n := range m.Near(0.8) {
		got = append(got, string(n.Scope)+"/"+string(n.Dimension))
	}
	if strings.Join(got, ",") != "run/tokens,run/usd" {
		t.Errorf("Near() = %v; turns is reached, not near, and the day's caps are far", got)
	}
	m.USD = false
	if n := m.Near(0.8); len(n) != 1 || n[0].Dimension != gungnir.CapTokens {
		t.Errorf("Near() = %+v without dollars", n)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/budget [github.com/ouroboric-dev/odin/internal/budget.test]
internal/budget/meter_test.go:13:58: undefined: Meter
internal/budget/meter_test.go:15:10: undefined: Meter
FAIL	github.com/ouroboric-dev/odin/internal/budget [build failed]
```

- [ ] **Step 3:** write the code.

Write `internal/budget/meter.go`:

```go
package budget

import (
	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

// Meter reads a run's usage and the day's journal against the caps in factory.yaml. It is a
// gungnir.Meter: Jormungandr asks it before every session.
type Meter struct {
	Run     *gungnir.Usage // the run's usage so far, which Odin keeps in run.json
	Caps    schema.Budget
	USD     bool // dollars count: a role bills a paid API (see schema.PaidAPI)
	Journal *Journal
}

var _ gungnir.Meter = (*Meter)(nil)

// Check returns the first cap that is reached, the run's before the day's, or nil. The day's
// figure comes from the journal; when the journal can't be read the per-day cap can't be checked,
// and that stops the run too (gungnir.CapJournal).
func (m *Meter) Check() *gungnir.CapError {
	if hit := m.Caps.PerRun.Reached(gungnir.CapRun, *m.Run, m.USD); hit != nil {
		return hit
	}
	day, err := m.Journal.Day(m.Journal.now())
	if err != nil {
		return &gungnir.CapError{Scope: gungnir.CapDay, Dimension: gungnir.CapJournal, Note: err.Error()}
	}
	return m.Caps.PerDay.Reached(gungnir.CapDay, day, m.USD)
}

// Today returns what the journal holds for today.
func (m *Meter) Today() (gungnir.Usage, error) { return m.Journal.Day(m.Journal.now()) }

// RemainingTurns returns how many turns the caps still allow: the lesser of the run's and the
// day's, and never below zero. It bounds the turns of a session, so one session can't run far past a
// cap that Check only sees afterwards. An unreadable journal leaves none.
func (m *Meter) RemainingTurns() int64 {
	left := m.Caps.PerRun.Turns - m.Run.Turns
	day, err := m.Today()
	if err != nil {
		return 0
	}
	return max(min(left, m.Caps.PerDay.Turns-day.Turns), 0)
}

// Near returns the caps that are at least frac of the way reached, and not yet reached, for a
// warning (spec §10.1): the usage in each CapError is the figure, the limit the cap.
func (m *Meter) Near(frac float64) []gungnir.CapError {
	var near []gungnir.CapError
	day, _ := m.Today()
	for _, s := range []struct {
		scope gungnir.CapScope
		cap   schema.Cap
		use   gungnir.Usage
	}{{gungnir.CapRun, m.Caps.PerRun, *m.Run}, {gungnir.CapDay, m.Caps.PerDay, day}} {
		dims := []gungnir.CapError{
			{Scope: s.scope, Dimension: gungnir.CapTokens, Used: float64(s.use.CapTokens()), Limit: float64(s.cap.Tokens)},
			{Scope: s.scope, Dimension: gungnir.CapTurns, Used: float64(s.use.Turns), Limit: float64(s.cap.Turns)},
		}
		if m.USD {
			dims = append(dims, gungnir.CapError{Scope: s.scope, Dimension: gungnir.CapUSD, Used: s.use.CostUSD, Limit: s.cap.USD})
		}
		for _, d := range dims {
			if d.Limit > 0 && d.Used >= frac*d.Limit && d.Used < d.Limit {
				near = append(near, d)
			}
		}
	}
	return near
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T128: a session's usage is counted whether it succeeds or not

Decision 11 and spec §12. Every agent session goes through one function that counts what it used, in
the run and in the day's journal, whatever way it ended, and classifies how it ended. Agent nodes use it
now; loops do in v0-T134.

**Files (in `odin`):**

- Create: `internal/engine/budget_test.go`, `internal/engine/session.go`
- Modify: `internal/cli/e2e_test.go`, `internal/engine/engine.go`, `internal/engine/engine_test.go`, `internal/engine/main_test.go`, `internal/run/main_test.go`, `internal/run/run.go`

**Interfaces:**

- Consumes: `jormungandr.Retrier`, `Classify`, `AgentFailure`, `ExhaustedError`, `QuotaError`
  (v0-T117, v0-T118); `gungnir.SessionError` (v0-T097); the scripted adapter's `kind` and `usage` on
  failed steps (v0-T111).
- Produces: `run.Hooks{Now; Backoff *jormungandr.Backoff; Sleep}` (tests); `Setup.Journal`, `Backoff`,
  `Sleep`; `(*Run).Spend(node string, u gungnir.Usage) error` (the journal first, then `State.Usage`; a
  usage of nothing is not recorded).
- Produces: `engine.session(ctx, r, sessionSpec) (gungnir.Result, gungnir.Event, error)` with
  `sessionSpec{key, role, repo, text string; readOnly bool; maxTurns int; timeout time.Duration}`: one
  session as spec §12 says, with `Retrier`'s retries, `startSession` counting each try, the usage of a
  failed try counted and logged on its `node_failed` line, and the successful try's event returned for
  the caller to finish. `engine.nodeError(err)` turns its errors into the engine's own: an agent
  failure, retries that ran out, an infrastructure failure or an interrupted run fails the node.
  `runAgent` goes through both.
- Changes: every Odin test package sets `XDG_STATE_HOME` to a folder of its own in `TestMain`, so no test
  writes under the real `HOME`; the engine tests get `startWith(setup{...})`, a run with its own journal.

**Acceptance criteria:**

- [ ] A run's usage is in `run.json` and in the day's journal, once.
- [ ] A session that failed after it spent tokens still counts them, on its `node_failed` line too.
- [ ] Every existing test passes unchanged in what it asserts.

**Named test:** `go test ./internal/engine -run 'TestASessionsUsageIsCounted|TestAFailedSessionsUsageStillCounts'`
in `odin`. **Layer:** `odin`. **Size:** M (344). **Depends on:** v0-T127; v0-T099, v0-T111, v0-T118 merged.

- [ ] **Step 1:** write the tests.

Apply to `internal/cli/e2e_test.go`:

```diff
diff --git a/internal/cli/e2e_test.go b/internal/cli/e2e_test.go
index 1eceb40..1730d8c 100644
--- a/internal/cli/e2e_test.go
+++ b/internal/cli/e2e_test.go
@@ -22,7 +22,19 @@ func TestMain(m *testing.M) {
 	if os.Getenv("YGG_E2E_MAIN") == "1" {
 		os.Exit(Main(context.Background(), os.Args[1:], os.Stdout, os.Stderr))
 	}
-	os.Exit(m.Run())
+	os.Exit(withStateFolder(m))
+}
+
+// withStateFolder points the operator's state folder, where the spend journal defaults to, at a
+// folder of the test's own, so no test writes under the real HOME. A ygg the tests start inherits it.
+func withStateFolder(m *testing.M) int {
+	dir, err := os.MkdirTemp("", "ygg-state-")
+	if err != nil {
+		panic(err)
+	}
+	defer os.RemoveAll(dir)
+	os.Setenv("XDG_STATE_HOME", dir)
+	return m.Run()
 }
 
 // walk starts the toy run and approves every stop. It returns the gates it stopped at, in order.
```

Write `internal/engine/budget_test.go`:

```go
package engine

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/run"
)

var twoNodes = "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n  - { id: b, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n"

const spendScript = `steps:
  a:
    - actions: [ { write: { path: a.txt, content: "a\n" } } ]
      result: { status: ok, summary: did a, usage: { in: 100, out: 20, cache: 1000, turns: 3, cost_usd: 0.25 } }
  b:
    - actions: [ { write: { path: b.txt, content: "b\n" } } ]
      result: { status: ok, summary: did b, usage: { in: 10, out: 1, turns: 1 } }
    - result: { status: ok, summary: did b again, usage: { in: 10, out: 1, turns: 1 } }
`

func caps(runTokens, runTurns, dayTokens, dayTurns int) string {
	return "budget:\n  per_run: { tokens: " + itoa(runTokens) + ", turns: " + itoa(runTurns) + " }\n  per_day: { tokens: " + itoa(dayTokens) + ", turns: " + itoa(dayTurns) + " }\n"
}

func itoa(n int) string { b, _ := json.Marshal(n); return string(b) }

// reopen closes the run and opens it again from its files, as ygg resume or approve does, so a
// change to factory.yaml takes effect.
func reopen(t *testing.T, r *run.Run) *run.Run {
	t.Helper()
	id, project := r.State.ID, r.Project
	r.Close()
	r2, err := run.Open(context.Background(), project, id, "")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { r2.Close() })
	return r2
}

func today(t *testing.T, r *run.Run) gungnir.Usage {
	t.Helper()
	u, err := r.Setup.Journal.Day(time.Now())
	if err != nil {
		t.Fatal(err)
	}
	return u
}

func TestASessionsUsageIsCountedInTheRunAndInTheDaysJournal(t *testing.T) {
	r := start(t, "key-points", "", twoNodes, spendScript)
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	want := gungnir.Usage{InTok: 110, OutTok: 21, CacheTok: 1000, Turns: 4, CostUSD: 0.25}
	if r.State.Usage != want {
		t.Errorf("run usage = %+v, want %+v", r.State.Usage, want)
	}
	if got := today(t, r); got != want {
		t.Errorf("the day's journal = %+v, want %+v", got, want)
	}
}

func TestAFailedSessionsUsageStillCounts(t *testing.T) {
	script := "steps:\n  a:\n    - error: timed out half way\n      usage: { in: 500, out: 50, turns: 4 }\n"
	r := start(t, "key-points", "", twoNodes, script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed {
		t.Fatalf("Advance() = %+v, %v; want failed", out, err)
	}
	if u := r.State.Usage; u.InTok != 500 || u.OutTok != 50 || u.Turns != 4 {
		t.Errorf("run usage = %+v; a session that timed out still spent its tokens", u)
	}
	if u := today(t, r); u.InTok != 500 || u.Turns != 4 {
		t.Errorf("the day's journal = %+v", u)
	}
	if !strings.Contains(ledgerText(t, r), `"event":"node_failed"`) || !strings.Contains(ledgerText(t, r), `"gen_ai.usage.input_tokens":500`) {
		t.Errorf("the failed session's usage is not in the ledger:\n%s", ledgerText(t, r))
	}
}
```

Apply to `internal/engine/engine_test.go`:

```diff
diff --git a/internal/engine/engine_test.go b/internal/engine/engine_test.go
index 43963ea..244bcf1 100644
--- a/internal/engine/engine_test.go
+++ b/internal/engine/engine_test.go
@@ -22,24 +22,51 @@ func start(t *testing.T, mode, gates, nodes, script string) *run.Run {
 
 // startPack is start with extra lines for the realm's pack.yaml, such as its checks.
 func startPack(t *testing.T, mode, gates, pack, nodes, script string) *run.Run {
+	t.Helper()
+	return startWith(t, setup{mode: mode, gates: gates, pack: pack, nodes: nodes, script: script})
+}
+
+// setup says how a test run is made. Unset fields have the values start uses.
+type setup struct {
+	mode, gates, pack, nodes, script string
+	budget                           string // the budget: section of factory.yaml, whole; generous by default
+	roles                            string // the roles: section, whole; one scripted planner by default
+	journal                          string // the folder of the spend journal; one of the test's own by default
+	hooks                            run.Hooks
+}
+
+// startWith makes the realm, the config and a fresh project (see start), and starts a run. It returns
+// with the config's path in r.Setup.ConfigPath, so a test can edit it before it opens the run again.
+func startWith(t *testing.T, o setup) *run.Run {
 	t.Helper()
 	realm, cfg := t.TempDir(), t.TempDir()
 	project := treetest.Project(t, "repos/app")
+	if o.mode == "" {
+		o.mode = "key-points"
+	}
+	if o.budget == "" {
+		o.budget = "budget:\n  per_run: { tokens: 100000, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\n"
+	}
+	if o.roles == "" {
+		o.roles = "roles:\n  planner: { agent: scripted, model: none, script: script.yaml }\n"
+	}
+	if o.journal == "" {
+		o.journal = filepath.Join(cfg, "spend")
+	}
+	o.budget = strings.TrimRight(o.budget, "\n") + "\n  journal: " + o.journal + "\n"
 	files := map[string]string{
-		filepath.Join(realm, "pack.yaml"):  "name: test\nversion: 0.1.0\ngraph: graph.yaml\n" + pack,
-		filepath.Join(realm, "graph.yaml"): "name: test\nversion: 1.0.0\nnodes:\n" + nodes,
+		filepath.Join(realm, "pack.yaml"):  "name: test\nversion: 0.1.0\ngraph: graph.yaml\n" + o.pack,
+		filepath.Join(realm, "graph.yaml"): "name: test\nversion: 1.0.0\nnodes:\n" + o.nodes,
 		filepath.Join(realm, "p.md"):       "Do the work.\n",
-		filepath.Join(cfg, "script.yaml"):  script,
-		filepath.Join(cfg, "factory.yaml"): "mode: " + mode + "\n" + gates +
-			"roles:\n  planner: { agent: scripted, model: none, script: script.yaml }\n" +
-			"budget:\n  per_run: { tokens: 100000, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\n",
+		filepath.Join(cfg, "script.yaml"):  o.script,
+		filepath.Join(cfg, "factory.yaml"): "mode: " + o.mode + "\n" + o.gates + o.roles + o.budget,
 	}
 	for p, body := range files {
 		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
 			t.Fatal(err)
 		}
 	}
-	r, err := run.Start(context.Background(), run.Options{Project: project, Config: filepath.Join(cfg, "factory.yaml"), Realm: realm})
+	r, err := run.Start(context.Background(), run.Options{Project: project, Config: filepath.Join(cfg, "factory.yaml"), Realm: realm, Hooks: o.hooks})
 	if err != nil {
 		t.Fatal(err)
 	}
```

Apply to `internal/engine/main_test.go`:

```diff
diff --git a/internal/engine/main_test.go b/internal/engine/main_test.go
index 2f7900d..c77b14e 100644
--- a/internal/engine/main_test.go
+++ b/internal/engine/main_test.go
@@ -14,5 +14,17 @@ func TestMain(m *testing.M) {
 	if _, _, e := syscall.RawSyscall(syscall.SYS_PRCTL, prSetChildSubreaper, 1, 0); e != 0 {
 		panic(e)
 	}
-	os.Exit(m.Run())
+	os.Exit(withStateFolder(m))
+}
+
+// withStateFolder points the operator's state folder, where the spend journal defaults to, at a
+// folder of the test's own, so no test writes under the real HOME.
+func withStateFolder(m *testing.M) int {
+	dir, err := os.MkdirTemp("", "ygg-state-")
+	if err != nil {
+		panic(err)
+	}
+	defer os.RemoveAll(dir)
+	os.Setenv("XDG_STATE_HOME", dir)
+	return m.Run()
 }
```

Apply to `internal/run/main_test.go`:

```diff
diff --git a/internal/run/main_test.go b/internal/run/main_test.go
index 512fc2d..50661d0 100644
--- a/internal/run/main_test.go
+++ b/internal/run/main_test.go
@@ -14,5 +14,17 @@ func TestMain(m *testing.M) {
 	if _, _, e := syscall.RawSyscall(syscall.SYS_PRCTL, prSetChildSubreaper, 1, 0); e != 0 {
 		panic(e)
 	}
-	os.Exit(m.Run())
+	os.Exit(withStateFolder(m))
+}
+
+// withStateFolder points the operator's state folder, where the spend journal defaults to, at a
+// folder of the test's own, so no test writes under the real HOME.
+func withStateFolder(m *testing.M) int {
+	dir, err := os.MkdirTemp("", "ygg-state-")
+	if err != nil {
+		panic(err)
+	}
+	defer os.RemoveAll(dir)
+	os.Setenv("XDG_STATE_HOME", dir)
+	return m.Run()
 }
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/budget_test.go:48:20: r.Setup.Journal undefined (type *run.Setup has no field or method Journal)
FAIL	github.com/ouroboric-dev/odin/internal/engine [build failed]
FAIL
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 3ccfad7..e87f495 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -121,11 +121,6 @@ func startAttempt(r *run.Run, n schema.Node) (int, error) {
 
 func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 	s := r.State
-	attempt, err := startAttempt(r, n)
-	if err != nil {
-		return err
-	}
-	role := r.Setup.Config.Roles[n.Role]
 	prompt, err := os.ReadFile(filepath.Join(r.Setup.RealmDir, n.Prompt))
 	if err != nil {
 		return err
@@ -145,53 +140,17 @@ func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 	if reason := s.Reasons[n.ID]; reason != "" {
 		text += "\n\n## Rejected at the approval point\n\n" + reason + "\n"
 	}
-	ev := gungnir.Event{Node: n.ID, Attempt: attempt, Role: n.Role, Adapter: role.Agent, Model: role.Model}
-	start := ev
-	start.Name = gungnir.EventNodeStarted
-	if err := r.Log(start); err != nil {
-		return err
-	}
-	runner, err := r.Runner(ctx, n.Repo)
+	res, ev, err := session(ctx, r, sessionSpec{key: n.ID, role: n.Role, repo: n.Repo, text: text, readOnly: n.ReadOnly,
+		maxTurns: n.MaxTurns, timeout: time.Duration(n.Timeout)})
 	if err != nil {
-		return sandboxStart(err)
-	}
-	task := gungnir.Task{Role: n.Role, Node: n.ID, Attempt: attempt, Prompt: text, Workdir: r.RepoDir(n.Repo),
-		Model: role.Model, ReadOnly: n.ReadOnly, MaxTurns: n.MaxTurns, Timeout: time.Duration(n.Timeout),
-		TranscriptDir: filepath.Join(r.Dir, "transcripts"), Sandbox: runner}
-	actx, cancel := ctx, context.CancelFunc(func() {})
-	if task.Timeout > 0 {
-		actx, cancel = context.WithTimeout(ctx, task.Timeout)
-	}
-	began := time.Now()
-	res, runErr := r.Setup.Agents[n.Role].Run(actx, task)
-	cancel()
-	if runErr == nil {
-		if err := res.Validate(); err != nil {
-			runErr = fmt.Errorf("the agent's result is malformed: %w", err)
-		} else {
-			// Only a well-formed result's usage counts; a malformed one is never trusted.
-			s.Usage = s.Usage.Add(res.Usage)
-			ev = ev.WithUsage(res.Usage)
-			ev.Provider, ev.CLIVersion = res.Provider, res.CLIVersion
-			if res.Status != gungnir.StatusOK {
-				runErr = fmt.Errorf("the agent reported %s: %s", res.Status, res.Summary)
-			}
-		}
-	}
-	ev.DurationMS = time.Since(began).Milliseconds()
-	if runErr != nil {
-		ev.Name, ev.Result = gungnir.EventNodeFailed, runErr.Error()
-		if err := r.Log(ev); err != nil {
-			return err
-		}
-		return &nodeFailure{runErr}
+		return nodeError(err)
 	}
 	if n.ReadOnly {
 		if err := readOnly(ctx, r, n); err != nil {
 			return failCheckpoint(r, ev, err)
 		}
 	}
-	if ev.Commit, err = checkpoint(ctx, r, n, attempt); err != nil {
+	if ev.Commit, err = checkpoint(ctx, r, n, ev.Attempt); err != nil {
 		return failCheckpoint(r, ev, err)
 	}
 	ev.Name, ev.Result = gungnir.EventNodeFinished, res.Summary
```

Write `internal/engine/session.go`:

```go
package engine

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/jormungandr"
	"github.com/ouroboric-dev/odin/internal/run"
)

// sessionSpec says what one agent session is. key names its ledger lines, its transcripts and its
// script: a node's id, or the session key of a loop's reviewer.
type sessionSpec struct {
	key      string
	role     string
	repo     string
	text     string // the whole prompt
	readOnly bool
	maxTurns int
	timeout  time.Duration
}

// startSession counts a new session under key and saves it before the session runs, so a session
// that is interrupted still counts. A retry after a transient failure is a session of its own.
func startSession(r *run.Run, key string) (int, error) {
	r.State.Attempts[key]++
	return r.State.Attempts[key], r.Save()
}

// session runs one agent session the way spec §12 says. What the session used is counted whether it succeeded or not (backlog B-019, B-020), in
// the day's journal and the run's usage. A failure that is not the agent's, a 429 or a crash at start,
// is retried with a backoff, not as a loop attempt. It returns the result of the session that
// succeeded and the ledger event for it, which the caller completes and logs. Any error is one of
// jormungandr's: a used-up quota, retries that ran out, an agent failure, or an infrastructure
// failure; or an error of Odin's own.
func session(ctx context.Context, r *run.Run, sp sessionSpec) (gungnir.Result, gungnir.Event, error) {
	role := r.Setup.Config.Roles[sp.role]
	var fatal error // an error of Odin's own, which must never read as a failure of the agent
	var done gungnir.Event
	retrier := jormungandr.Retrier{Backoff: r.Setup.Backoff, Sleep: r.Setup.Sleep,
		OnRetry: func(try int, wait time.Duration, why string) error {
			return r.Log(gungnir.Event{Name: gungnir.EventRetry, Node: sp.key, Attempt: r.State.Attempts[sp.key],
				Note: fmt.Sprintf("try %d failed for a reason that is not the agent's; it runs again in %s: %s", try, wait, why)})
		}}
	res, err := retrier.Do(ctx, func(ctx context.Context, _ int) (gungnir.Result, error) {
		stop := func(err error) (gungnir.Result, error) {
			fatal = err
			return gungnir.Result{}, &gungnir.SessionError{Kind: gungnir.FailureInfra, Err: err}
		}
		attempt, err := startSession(r, sp.key)
		if err != nil {
			return stop(err)
		}
		ev := gungnir.Event{Node: sp.key, Attempt: attempt, Role: sp.role, Adapter: role.Agent, Model: role.Model}
		begin := ev
		begin.Name = gungnir.EventNodeStarted
		if err := r.Log(begin); err != nil {
			return stop(err)
		}
		runner, err := r.Runner(ctx, sp.repo)
		if err != nil {
			// A sandbox that won't start is not a failure of the agent, and is not retried here (spec §12).
			return stop(sandboxStart(err))
		}
		task := gungnir.Task{Role: sp.role, Node: sp.key, Attempt: attempt, Prompt: sp.text, Workdir: r.RepoDir(sp.repo),
			Model: role.Model, ReadOnly: sp.readOnly, MaxTurns: sp.maxTurns, Timeout: sp.timeout,
			TranscriptDir: filepath.Join(r.Dir, "transcripts"), Sandbox: runner}
		actx, cancel := ctx, context.CancelFunc(func() {})
		if task.Timeout > 0 {
			actx, cancel = context.WithTimeout(ctx, task.Timeout)
		}
		began := time.Now()
		res, runErr := r.Setup.Agents[sp.role].Run(actx, task)
		cancel()
		var spent gungnir.Usage
		var se *gungnir.SessionError
		switch {
		case runErr == nil:
			if verr := res.Validate(); verr != nil {
				// Only a well-formed result's usage counts; a malformed one is never trusted.
				res, runErr = gungnir.Result{}, fmt.Errorf("the agent's result is malformed: %w", verr)
			} else {
				spent = res.Usage
			}
		case errors.As(runErr, &se):
			spent = se.Usage
		}
		if err := r.Spend(sp.key, spent); err != nil {
			return stop(err)
		}
		ev = ev.WithUsage(spent)
		ev.DurationMS = time.Since(began).Milliseconds()
		if runErr == nil {
			ev.Provider, ev.CLIVersion = res.Provider, res.CLIVersion
		}
		kind, _ := jormungandr.Classify(res, runErr)
		if kind != "" {
			ev.Name, ev.Result = gungnir.EventNodeFailed, fmt.Sprintf("the agent reported %s: %s", res.Status, res.Summary)
			if runErr != nil {
				ev.Result = runErr.Error()
			}
			if err := r.Log(ev); err != nil {
				return stop(err)
			}
			return res, runErr
		}
		done = ev
		return res, nil
	})
	if fatal != nil {
		return gungnir.Result{}, gungnir.Event{}, fatal
	}
	return res, done, err
}

// nodeError turns the error of a session into what the engine does with it, for a node that is not
// in a loop: everything that is the session's own, an agent failure, retries that ran out or an
// infrastructure failure, fails the node.
// An error of Odin's own stays as it is.
func nodeError(err error) error {
	var af *jormungandr.AgentFailure
	var ex *jormungandr.ExhaustedError
	var q *jormungandr.QuotaError
	switch {
	case errors.As(err, &af), errors.As(err, &ex), errors.As(err, &q):
		return &nodeFailure{err}
	case errors.Is(err, context.Canceled), errors.Is(err, context.DeadlineExceeded):
		return &nodeFailure{err} // the run was interrupted: it stops failed, and a resume starts the node again
	case gungnir.FailureOf(err) == gungnir.FailureInfra:
		return &nodeFailure{err}
	}
	return err
}
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 6bd0e6a..9f27acc 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -17,7 +17,9 @@ import (
 	"github.com/ouroboric-dev/gleipnir/skills"
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
+	"github.com/ouroboric-dev/jormungandr"
 	"github.com/ouroboric-dev/odin/internal/agents"
+	"github.com/ouroboric-dev/odin/internal/budget"
 	"github.com/ouroboric-dev/odin/internal/leaf"
 	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/lock"
@@ -35,10 +37,14 @@ type Options struct {
 	Hooks   Hooks        // tests only
 }
 
-// Hooks replace parts of a run in tests: the skill libraries, and the sandbox driver.
+// Hooks replace parts of a run in tests: the skill libraries, the sandbox driver, the clock that
+// decides which day a session's spend belongs to, and the retry policy with its wait.
 type Hooks struct {
 	Libs       *skills.Libraries
 	NewSandbox NewSandbox
+	Now        func() time.Time
+	Backoff    *jormungandr.Backoff
+	Sleep      func(ctx context.Context, d time.Duration) error
 }
 
 // Setup is everything a run needs, loaded and checked.
@@ -59,6 +65,9 @@ type Setup struct {
 	Skills       skills.Record            // every skill the graph names, with the set's hash
 	Sandbox      *SandboxSetup            // nil: no sandbox section, so leaf commands run on the host
 	newSandbox   NewSandbox
+	Journal      *budget.Journal // where every session's usage is recorded, and the per-day cap is summed
+	Backoff      jormungandr.Backoff
+	Sleep        func(ctx context.Context, d time.Duration) error // nil: wait for real
 
 	Root        string               // the tree's root: the project, or an umbrella above it
 	ProjectPath string               // the project's path from the root
@@ -114,6 +123,9 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 			return nil, err
 		}
 	}
+	if err := s.prepareBudget(o.Hooks); err != nil {
+		return nil, err
+	}
 	s.newSandbox = o.Hooks.NewSandbox
 	if err := s.prepareSandbox(); err != nil {
 		return nil, err
@@ -134,6 +146,24 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 	return s, nil
 }
 
+// prepareBudget says where the spend journal is, and the retry policy. The journal's folder is made
+// at the first session, not here: Prepare writes nothing.
+func (s *Setup) prepareBudget(h Hooks) error {
+	dir := s.Config.Budget.Journal
+	if dir == "" {
+		var err error
+		if dir, err = budget.DefaultDir(os.Getenv, os.UserHomeDir); err != nil {
+			return fmt.Errorf("%s: %w", s.ConfigPath, err)
+		}
+	}
+	s.Journal = &budget.Journal{Dir: dir, Now: h.Now}
+	s.Backoff, s.Sleep = jormungandr.DefaultBackoff, h.Sleep
+	if h.Backoff != nil {
+		s.Backoff = *h.Backoff
+	}
+	return nil
+}
+
 // findProject places the project in the instance tree: Odin runs on nothing outside it, because a
 // resume resets leaves (spec §4.3).
 func (s *Setup) findProject(ctx context.Context, project string) error {
@@ -233,6 +263,20 @@ type Run struct {
 	Sandbox gungnir.Sandbox // runs the leaves' commands; nil when the config has no sandbox section
 }
 
+// Spend counts what a session used, whether or not it succeeded: in the day's journal first, so a
+// crash between the two leaves the spend counted twice at worst, and then in the run's usage. The
+// caller saves run.json. A usage of nothing is not recorded.
+func (r *Run) Spend(node string, u gungnir.Usage) error {
+	if u == (gungnir.Usage{}) {
+		return nil
+	}
+	if err := r.Setup.Journal.Append(budget.Entry{Run: r.State.ID, Project: r.Project, Node: node, Usage: u}); err != nil {
+		return fmt.Errorf("recording the spend in %s: %w", r.Setup.Journal.Dir, err)
+	}
+	r.State.Usage = r.State.Usage.Add(u)
+	return nil
+}
+
 // Branch is the branch a run works on in every leaf.
 func Branch(id string) string { return "ygg/" + id }
 
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T129: caps stop the run, resumable

Spec §7.4 and decisions 6 and 10. No session starts over a cap, and the run stops at the hard approval
point `budget-cap` with everything resumable.

**Files (in `odin`):**

- Modify: `internal/cli/cli.go`, `internal/cli/e2e_test.go`, `internal/engine/budget_test.go`, `internal/engine/gates.go`, `internal/engine/session.go`, `internal/run/run.go`

**Interfaces:**

- Consumes: `budget.Meter` (v0-T127), `jormungandr.Retrier.Meter`, `gungnir.GateBudgetCap`.
- Produces: `(*Run).Meter() *budget.Meter`; `session` asks the meter before every try and bounds a
  session's turns by `meter.RemainingTurns()` (`turnsFor`: its own `max_turns` when that is fewer;
  otherwise what is left); `nodeError` turns a `*CapError` into a hard stop at `budget-cap`, which
  `stopHard` writes a gate file for that says what to do: raise the cap in `factory.yaml`, or wait for the
  day to turn, and then approve.
- Produces: `engine.Rejectable(r) bool`, and `ygg`'s message after a stop offers `reject` only where
  `Reject` accepts one (backlog B-012): a hard stop that a node raised offers `approve` and says that to
  drop the work you start a new run.

**Acceptance criteria:**

- [ ] A run that reaches its cap stops at `budget-cap` before the next session in every mode, with a
      ledger line that names the cap and a gate file that says what to do.
- [ ] Approving does not lift a cap that is still reached; raising it in `factory.yaml` and approving
      continues the run, and the ledger records the change.
- [ ] The day's cap counts what another run spent; an unreadable journal stops the run.
- [ ] A session is given at most the turns the caps still allow.
- [ ] Through the CLI: exit 3, the hard stop offers `approve` and no `reject`, `reject` is refused, and
      the run goes on after the cap is raised.

**Named test:** `go test ./internal/engine ./internal/cli -run 'TestARunThatReachesItsCap|TestApprovingBudgetCap|TestThePerDayCap|TestAJournalThatCannotBeReadStopsTheRun|TestASessionIsGivenOnlyTheTurns'`
in `odin`. **Layer:** `odin`. **Size:** M (190). **Depends on:** v0-T128; v0-T115 merged.

- [ ] **Step 1:** write the tests.

Apply to `internal/cli/e2e_test.go`:

```diff
diff --git a/internal/cli/e2e_test.go b/internal/cli/e2e_test.go
index 1730d8c..7ae474f 100644
--- a/internal/cli/e2e_test.go
+++ b/internal/cli/e2e_test.go
@@ -243,3 +243,35 @@ func TestToyGraphEndToEnd(t *testing.T) {
 		}
 	})
 }
+
+func TestARunThatReachesItsCapStopsAtBudgetCapAndOnlyApproveIsOffered(t *testing.T) {
+	dir, config := project(t, "script.yaml", "budget:\n  per_run: { tokens: 2500, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\n")
+	code, out, _ := ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
+	id := runID(t, dir)
+	if code != ExitStopped {
+		t.Fatalf("run: exit %d, %q", code, out)
+	}
+	code, out, errOut := ygg(t, "approve", id, "design-gate", "--project", dir)
+	if code != ExitStopped || !strings.Contains(out, "stopped at the hard approval point budget-cap") ||
+		!strings.Contains(out, "ygg approve "+id+" build") || strings.Contains(out, "ygg reject") || !strings.Contains(out, "no rejection") {
+		t.Fatalf("approve: exit %d:\n%s%s\nwant a stop at budget-cap that offers approve only", code, out, errOut)
+	}
+	if code, _, errOut := ygg(t, "reject", id, "build", "--reason", "no", "--project", dir); code != ExitRefused || !strings.Contains(errOut, "takes approve") {
+		t.Errorf("reject: exit %d, %q", code, errOut)
+	}
+	code, out, _ = ygg(t, "status", id, "--project", dir)
+	if code != ExitDone || !strings.Contains(out, "waiting:  build (budget-cap)") || !strings.Contains(out, "usage:    3000 tokens in") {
+		t.Errorf("status: exit %d:\n%s", code, out)
+	}
+	// Raise the cap, approve, and the run goes on to the end (the design gate is behind it).
+	b, _ := os.ReadFile(config)
+	os.WriteFile(config, []byte(strings.Replace(string(b), "tokens: 2500", "tokens: 50000", 1)), 0o644)
+	code, out, errOut = ygg(t, "approve", id, "build", "--project", dir)
+	for code == ExitStopped {
+		s, _ := run.LoadState(run.Dir(dir, id))
+		code, out, errOut = ygg(t, "approve", id, s.Pending, "--project", dir)
+	}
+	if code != ExitDone {
+		t.Errorf("after the cap was raised: exit %d:\n%s%s", code, out, errOut)
+	}
+}
```

Apply to `internal/engine/budget_test.go`:

```diff
diff --git a/internal/engine/budget_test.go b/internal/engine/budget_test.go
index 1533273..65dda92 100644
--- a/internal/engine/budget_test.go
+++ b/internal/engine/budget_test.go
@@ -3,11 +3,14 @@ package engine
 import (
 	"context"
 	"encoding/json"
+	"os"
+	"path/filepath"
 	"strings"
 	"testing"
 	"time"
 
 	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/odin/internal/budget"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
 
@@ -83,3 +86,110 @@ func TestAFailedSessionsUsageStillCounts(t *testing.T) {
 		t.Errorf("the failed session's usage is not in the ledger:\n%s", ledgerText(t, r))
 	}
 }
+
+func TestARunThatReachesItsCapStopsAtBudgetCapInEveryModeBeforeTheNextSession(t *testing.T) {
+	for _, mode := range []string{"key-points", "unattended", "step-by-step"} {
+		r := startWith(t, setup{mode: mode, nodes: twoNodes, script: spendScript, budget: caps(120, 100, 200000, 200)})
+		out, err := Advance(context.Background(), r)
+		if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateBudgetCap || out.Gate != "b" {
+			t.Fatalf("%s: Advance() = %+v, %v, gate %s; want a stop at budget-cap before node b", mode, out, err, r.State.PendingGate)
+		}
+		if r.State.Attempts["b"] != 0 {
+			t.Errorf("%s: node b started %d sessions over the cap", mode, r.State.Attempts["b"])
+		}
+		text := ledgerText(t, r)
+		if !strings.Contains(text, `"event":"gate_pending"`) || !strings.Contains(text, "budget-cap") || !strings.Contains(text, "per-run tokens cap is reached: 120 used of 120") {
+			t.Errorf("%s: the ledger doesn't say why:\n%s", mode, text)
+		}
+		gate, _ := os.ReadFile(filepath.Join(r.Dir, "gates", "b-0.md"))
+		if !strings.Contains(string(gate), "budget-cap") || !strings.Contains(string(gate), "factory.yaml") {
+			t.Errorf("%s: the gate file doesn't tell the operator what to do:\n%s", mode, gate)
+		}
+	}
+}
+
+func TestApprovingBudgetCapDoesNotWaiveTheCapButRaisingItDoes(t *testing.T) {
+	r := startWith(t, setup{nodes: twoNodes, script: spendScript, budget: caps(120, 100, 200000, 200)})
+	if out, _ := Advance(context.Background(), r); out.Status != run.StatusStopped {
+		t.Fatalf("Advance() = %+v", out)
+	}
+	if err := Approve(context.Background(), r, "b", "go on"); err != nil {
+		t.Fatal(err)
+	}
+	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateBudgetCap {
+		t.Fatalf("Advance() = %+v, %v; approving does not lift a cap that is still reached", out, err)
+	}
+	if err := Reject(context.Background(), r, "b", "no"); err == nil {
+		t.Error("a hard stop took a rejection")
+	}
+	// The operator raises the cap in factory.yaml; the run is opened again and approved.
+	cfg, _ := os.ReadFile(r.Setup.ConfigPath)
+	if err := os.WriteFile(r.Setup.ConfigPath, []byte(strings.Replace(string(cfg), "tokens: 120", "tokens: 1000", 1)), 0o644); err != nil {
+		t.Fatal(err)
+	}
+	r = reopen(t, r)
+	if err := Approve(context.Background(), r, "b", "raised the cap"); err != nil {
+		t.Fatal(err)
+	}
+	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v, %v; want done after the cap was raised", out, err)
+	}
+	if !strings.Contains(ledgerText(t, r), `"event":"config_changed"`) {
+		t.Error("the raised cap is not in the ledger as a config change")
+	}
+}
+
+func TestThePerDayCapCountsWhatOtherRunsSpent(t *testing.T) {
+	journal := filepath.Join(t.TempDir(), "spend")
+	j := &budget.Journal{Dir: journal}
+	if err := j.Append(budget.Entry{Run: "20261016-090000-aaaaaa", Project: "/another/project", Node: "x", Usage: gungnir.Usage{InTok: 1990, OutTok: 10, Turns: 5}}); err != nil {
+		t.Fatal(err)
+	}
+	r := startWith(t, setup{nodes: twoNodes, script: spendScript, journal: journal, budget: caps(100000, 100, 2000, 200)})
+	out, err := Advance(context.Background(), r)
+	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateBudgetCap || out.Gate != "a" || r.State.Attempts["a"] != 0 {
+		t.Fatalf("Advance() = %+v, %v; want a stop at budget-cap before the first session", out, err)
+	}
+	if !strings.Contains(ledgerText(t, r), "per-day tokens cap is reached") {
+		t.Errorf("the ledger doesn't name the day's cap:\n%s", ledgerText(t, r))
+	}
+}
+
+func TestAJournalThatCannotBeReadStopsTheRun(t *testing.T) {
+	journal := filepath.Join(t.TempDir(), "spend")
+	os.MkdirAll(journal, 0o700)
+	os.WriteFile((&budget.Journal{Dir: journal}).File(time.Now()), []byte("not json\nnot json\n"), 0o600)
+	r := startWith(t, setup{nodes: twoNodes, script: spendScript, journal: journal})
+	out, err := Advance(context.Background(), r)
+	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateBudgetCap || r.State.Attempts["a"] != 0 {
+		t.Fatalf("Advance() = %+v, %v; a cap that can't be checked is reached", out, err)
+	}
+	if !strings.Contains(ledgerText(t, r), "can't be checked") {
+		t.Errorf("the ledger doesn't say the journal is unreadable:\n%s", ledgerText(t, r))
+	}
+}
+
+func TestASessionIsGivenOnlyTheTurnsTheCapsStillAllow(t *testing.T) {
+	nodes := "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app, max_turns: 50 }\n  - { id: b, kind: agent, role: planner, prompt: p.md, repo: repos/app, max_turns: 2 }\n  - { id: c, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n"
+	script := "steps:\n  a:\n    - result: { status: ok, usage: { turns: 3 } }\n  b:\n    - result: { status: ok }\n  c:\n    - result: { status: ok }\n"
+	r := startWith(t, setup{nodes: nodes, script: script, budget: caps(100000, 10, 200000, 200)})
+	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+	turns := map[string]int{}
+	for _, n := range []string{"a", "b", "c"} {
+		b, err := os.ReadFile(filepath.Join(r.Dir, "transcripts", n+"-1.json"))
+		if err != nil {
+			t.Fatal(err)
+		}
+		var tr struct {
+			MaxTurns int `json:"max_turns"`
+		}
+		json.Unmarshal(b, &tr)
+		turns[n] = tr.MaxTurns
+	}
+	// 10 turns in the run: a is bounded by its own 50 to the 10 left; b, after a spent 3, by its own 2; c by the 7 left.
+	if turns["a"] != 10 || turns["b"] != 2 || turns["c"] != 7 {
+		t.Errorf("max turns given = %v, want a:10 b:2 c:7", turns)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestARunThatReachesItsCapStopsAtBudgetCapAndOnlyApproveIsOffered (0.63s)
    e2e_test.go:257: approve: exit 0:
        Run 20261016-213340-283524 is done.
        
```

- [ ] **Step 3:** write the code.

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 99265eb..4d98631 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -237,9 +237,15 @@ func (c *command) advance(r *run.Run) int {
 		fmt.Fprintf(c.out, "Run %s is done.\n", id)
 		return ExitDone
 	case run.StatusStopped:
-		fmt.Fprintf(c.out, "Run %s stopped at approval point %s. Read %s, then run one of:\n"+
-			"  ygg approve %s %s [--note \"...\"]\n  ygg reject %s %s --reason \"...\"\n",
-			id, out.Gate, filepath.Join(r.Dir, "gates"), id, out.Gate, id, out.Gate)
+		if engine.Rejectable(r) {
+			fmt.Fprintf(c.out, "Run %s stopped at approval point %s. Read %s, then run one of:\n"+
+				"  ygg approve %s %s [--note \"...\"]\n  ygg reject %s %s --reason \"...\"\n",
+				id, out.Gate, filepath.Join(r.Dir, "gates"), id, out.Gate, id, out.Gate)
+		} else {
+			fmt.Fprintf(c.out, "Run %s stopped at the hard approval point %s. Read %s, then run:\n"+
+				"  ygg approve %s %s [--note \"...\"]\nA hard stop takes no rejection: to drop the work, start a new run.\n",
+				id, r.State.PendingGate, filepath.Join(r.Dir, "gates"), id, out.Gate)
+		}
 		return ExitStopped
 	default:
 		fmt.Fprintf(c.err, "Run %s failed: %v\n%s", id, out.Err, resumeHint(id))
```

Apply to `internal/engine/gates.go`:

```diff
diff --git a/internal/engine/gates.go b/internal/engine/gates.go
index 2e72e38..24d0c3e 100644
--- a/internal/engine/gates.go
+++ b/internal/engine/gates.go
@@ -125,6 +125,13 @@ func Approve(ctx context.Context, r *run.Run, gateID, note string) error {
 	return r.Save()
 }
 
+// Rejectable reports whether the run's pending stop takes a rejection: a gate node does. A hard stop
+// that a node raised takes approve only, or a new run (spec §7.2).
+func Rejectable(r *run.Run) bool {
+	s := r.State
+	return s.Pending != "" && s.Position < len(r.Setup.Graph.Nodes) && r.Setup.Graph.Nodes[s.Position].Kind == schema.KindGate
+}
+
 // Reject sends reason back into the node the gate re-runs (spec §7.2). Advance re-runs it with
 // the reason in its prompt, then reaches the gate again. A hard stop a node raised takes no
 // rejection: approve it, or start a new run to drop the work.
@@ -134,7 +141,7 @@ func Reject(ctx context.Context, r *run.Run, gateID, reason string) error {
 	}
 	s := r.State
 	g := r.Setup.Graph
-	if n := g.Nodes[s.Position]; n.Kind != schema.KindGate {
+	if !Rejectable(r) {
 		return fmt.Errorf("%s stopped at the hard approval point %s, which takes approve; to drop the work, start a new run", gateID, s.PendingGate)
 	}
 	if strings.TrimSpace(reason) == "" {
@@ -171,9 +178,13 @@ func stopHard(r *run.Run, n schema.Node, h *hardStop) (Outcome, error) {
 	fmt.Fprintf(&b, "- Run: %s\n- Mode: %s\n- Time: %s\n\n## Why\n\n%v\n\n", s.ID, s.Mode,
 		time.Now().UTC().Format(time.RFC3339), h.err)
 	fmt.Fprintf(&b, "## Decide\n\n    ygg approve %s %s [--note \"...\"]\n\n", s.ID, n.ID)
-	if run.Quarantines(h.gate) {
+	switch {
+	case run.Quarantines(h.gate):
 		fmt.Fprintf(&b, "Until then the leaf %s stays as the node left it, for investigation. Approving puts it back to its last checkpoint and runs %s again; what the node wrote is not saved.\n", n.Repo, n.ID)
-	} else {
+	case h.gate == gungnir.GateBudgetCap:
+		fmt.Fprintf(&b, "Nothing is lost: the work so far is committed and the run can go on. Approving does not lift a cap that is still reached. "+
+			"Raise the cap in factory.yaml (budget: per_run or per_day), or wait until the day's spend starts over, and then approve: the run goes on with %s.\n", n.ID)
+	default:
 		b.WriteString("Approving lands this move with the generated files as they are.\n")
 	}
 	b.WriteString("A hard stop takes no rejection: to drop the work, start a new run.\n")
```

Apply to `internal/engine/session.go`:

```diff
diff --git a/internal/engine/session.go b/internal/engine/session.go
index d91dd13..574f5a0 100644
--- a/internal/engine/session.go
+++ b/internal/engine/session.go
@@ -31,17 +31,19 @@ func startSession(r *run.Run, key string) (int, error) {
 	return r.State.Attempts[key], r.Save()
 }
 
-// session runs one agent session the way spec §12 says. What the session used is counted whether it succeeded or not (backlog B-019, B-020), in
+// session runs one agent session the way spec §12 says. A budget cap that is reached stops it before
+// it starts. What the session used is counted whether it succeeded or not (backlog B-019, B-020), in
 // the day's journal and the run's usage. A failure that is not the agent's, a 429 or a crash at start,
 // is retried with a backoff, not as a loop attempt. It returns the result of the session that
 // succeeded and the ledger event for it, which the caller completes and logs. Any error is one of
-// jormungandr's: a used-up quota, retries that ran out, an agent failure, or an infrastructure
+// jormungandr's: a cap, a used-up quota, retries that ran out, an agent failure, or an infrastructure
 // failure; or an error of Odin's own.
 func session(ctx context.Context, r *run.Run, sp sessionSpec) (gungnir.Result, gungnir.Event, error) {
 	role := r.Setup.Config.Roles[sp.role]
 	var fatal error // an error of Odin's own, which must never read as a failure of the agent
 	var done gungnir.Event
-	retrier := jormungandr.Retrier{Backoff: r.Setup.Backoff, Sleep: r.Setup.Sleep,
+	meter := r.Meter()
+	retrier := jormungandr.Retrier{Backoff: r.Setup.Backoff, Meter: meter, Sleep: r.Setup.Sleep,
 		OnRetry: func(try int, wait time.Duration, why string) error {
 			return r.Log(gungnir.Event{Name: gungnir.EventRetry, Node: sp.key, Attempt: r.State.Attempts[sp.key],
 				Note: fmt.Sprintf("try %d failed for a reason that is not the agent's; it runs again in %s: %s", try, wait, why)})
@@ -67,7 +69,7 @@ func session(ctx context.Context, r *run.Run, sp sessionSpec) (gungnir.Result, g
 			return stop(sandboxStart(err))
 		}
 		task := gungnir.Task{Role: sp.role, Node: sp.key, Attempt: attempt, Prompt: sp.text, Workdir: r.RepoDir(sp.repo),
-			Model: role.Model, ReadOnly: sp.readOnly, MaxTurns: sp.maxTurns, Timeout: sp.timeout,
+			Model: role.Model, ReadOnly: sp.readOnly, MaxTurns: turnsFor(sp.maxTurns, meter.RemainingTurns()), Timeout: sp.timeout,
 			TranscriptDir: filepath.Join(r.Dir, "transcripts"), Sandbox: runner}
 		actx, cancel := ctx, context.CancelFunc(func() {})
 		if task.Timeout > 0 {
@@ -117,14 +119,26 @@ func session(ctx context.Context, r *run.Run, sp sessionSpec) (gungnir.Result, g
 	return res, done, err
 }
 
+// turnsFor bounds a session's turns by what the caps still allow, so one session can't run far past
+// a cap that is checked only between sessions. 0 means the adapter's own limit.
+func turnsFor(node int, left int64) int {
+	if node > 0 && int64(node) <= left {
+		return node
+	}
+	return int(min(left, 1<<30))
+}
+
 // nodeError turns the error of a session into what the engine does with it, for a node that is not
-// in a loop: everything that is the session's own, an agent failure, retries that ran out or an
-// infrastructure failure, fails the node.
+// in a loop: a budget cap that is reached is a hard stop at budget-cap, and everything that is the
+// session's own, an agent failure, retries that ran out or an infrastructure failure, fails the node.
 // An error of Odin's own stays as it is.
 func nodeError(err error) error {
 	var af *jormungandr.AgentFailure
 	var ex *jormungandr.ExhaustedError
 	var q *jormungandr.QuotaError
+	if c, ok := jormungandr.IsCap(err); ok {
+		return &hardStop{gate: gungnir.GateBudgetCap, err: c}
+	}
 	switch {
 	case errors.As(err, &af), errors.As(err, &ex), errors.As(err, &q):
 		return &nodeFailure{err}
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 9f27acc..3763c3f 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -263,6 +263,11 @@ type Run struct {
 	Sandbox gungnir.Sandbox // runs the leaves' commands; nil when the config has no sandbox section
 }
 
+// Meter returns the budget of this run: its caps against its own usage and the day's journal.
+func (r *Run) Meter() *budget.Meter {
+	return &budget.Meter{Run: &r.State.Usage, Caps: r.Setup.Config.Budget, USD: r.Setup.Config.PaysPerToken(), Journal: r.Setup.Journal}
+}
+
 // Spend counts what a session used, whether or not it succeeded: in the day's journal first, so a
 // crash between the two leaves the spend counted twice at worst, and then in the run's usage. The
 // caller saves run.json. A usage of nothing is not recorded.
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T130: failures that are not the agent's: retries, a quota pause, and no retry for infrastructure

Spec §12 and decision 4, in a run: the status `paused`, exit code 4, and the ledger lines for every wait.

**Files (in `odin`):**

- Create: `internal/engine/retry_test.go`, `testdata/toy/script-quota.yaml`
- Modify: `internal/cli/cli.go`, `internal/cli/e2e_test.go`, `internal/engine/engine.go`, `internal/engine/session.go`, `internal/run/run.go`, `internal/run/state.go`

**Interfaces:**

- Produces: `run.StatusPaused`; `run.Pause{Node, Reason string; Since time.Time}` in `State.Paused`;
  `engine.pause`/`pauseRun`: a `*QuotaError` pauses the run at its node with a `run_paused` line, and
  `Advance` returns `Outcome{Status: StatusPaused}`; a resume starts the node from the checkpoint (the
  restart of a failed run covers a paused one too). `Advance` clears the pause.
- Produces: `cli.ExitPaused = 4`; `ygg run` and `resume` print why the run paused and `ygg resume <id>`;
  `ygg status` prints `paused:   at <node> since <time>: <reason>`. `approve` refuses a paused run: it
  waits for the provider, not for a decision.
- Produces: `testdata/toy/script-quota.yaml`, the toy script with the quota used up the first time
  `design` runs.

**Acceptance criteria:**

- [ ] A transient failure, an error or a failed result, is retried after 1 s then 2 s (a test's backoff),
      the retries and the failed tries are in the ledger, the failed try's tokens count, and the retry is
      not a new attempt of anything.
- [ ] Transient failures that outlast the retries fail the run with the number of tries; a resume tries
      again and succeeds.
- [ ] An agent failure and an infrastructure failure are tried once and not waited for.
- [ ] A used-up quota pauses the run, the paused session's half work is gone after the resume, and the
      resume finishes.
- [ ] Through the CLI: exit 4 and a message that says why and how to resume; `status` says paused;
      `approve` is refused; `resume` goes on.

**Named test:** `go test ./internal/engine ./internal/cli -run 'TestATransientFailureIsRetried|TestTransientFailuresThatOutlast|TestAnAgentFailureIsNotRetried|TestAnInfrastructureFailure|TestAUsedUpQuota'`
in `odin`. **Layer:** `odin`. **Size:** M (213). **Depends on:** v0-T129.

- [ ] **Step 1:** write the tests.

Apply to `internal/cli/e2e_test.go`:

```diff
diff --git a/internal/cli/e2e_test.go b/internal/cli/e2e_test.go
index 7ae474f..a5b1088 100644
--- a/internal/cli/e2e_test.go
+++ b/internal/cli/e2e_test.go
@@ -275,3 +275,26 @@ func TestARunThatReachesItsCapStopsAtBudgetCapAndOnlyApproveIsOffered(t *testing
 		t.Errorf("after the cap was raised: exit %d:\n%s%s", code, out, errOut)
 	}
 }
+
+func TestAUsedUpQuotaPausesTheRunWithExitCode4AndResumeGoesOn(t *testing.T) {
+	dir, config := project(t, "script-quota.yaml", "")
+	code, out, errOut := ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
+	if code != ExitPaused || ExitPaused != 4 || !strings.Contains(errOut, "paused") || !strings.Contains(errOut, "usage limit reached") || !strings.Contains(errOut, "ygg resume") {
+		t.Fatalf("run: exit %d:\n%s%s\nwant exit 4 and a message that says why and how to resume", code, out, errOut)
+	}
+	id := runID(t, dir)
+	code, out, _ = ygg(t, "status", id, "--project", dir)
+	if code != ExitDone || !strings.Contains(out, "status:   paused") || !strings.Contains(out, "paused:   at design since") || !strings.Contains(out, "usage limit reached") {
+		t.Errorf("status: exit %d:\n%s", code, out)
+	}
+	if code, _, errOut := ygg(t, "approve", id, "design", "--project", dir); code != ExitRefused {
+		t.Errorf("approve of a paused run: exit %d, %q; it waits for the provider, not for a decision", code, errOut)
+	}
+	code, out, errOut = ygg(t, "resume", id, "--project", dir)
+	if code != ExitStopped || !strings.Contains(out, "stopped at approval point design-gate") {
+		t.Errorf("resume: exit %d:\n%s%s; want the run to go on to the design gate", code, out, errOut)
+	}
+	if _, out, _ = ygg(t, "status", id, "--project", dir); strings.Contains(out, "paused:") {
+		t.Errorf("status still says paused:\n%s", out)
+	}
+}
```

Write `internal/engine/retry_test.go`:

```go
package engine

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/jormungandr"
	"github.com/ouroboric-dev/odin/internal/run"
)

const oneNode = "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n"

// waits is a Sleep that records its waits and returns at once.
type waits struct{ got []time.Duration }

func (w *waits) sleep(_ context.Context, d time.Duration) error { w.got = append(w.got, d); return nil }

func hooks(w *waits) run.Hooks {
	return run.Hooks{Backoff: &jormungandr.Backoff{Base: time.Second, Max: time.Minute, Retries: 3}, Sleep: w.sleep}
}

func TestATransientFailureIsRetriedWithABackoffAndLeavesNoTraceInTheAttempts(t *testing.T) {
	script := `steps:
  a:
    - error: the CLI crashed at start
      kind: transient
    - result: { status: failed, summary: HTTP 429, failure: transient, usage: { in: 5, out: 1, turns: 1 } }
    - actions: [ { write: { path: a.txt, content: "a\n" } } ]
      result: { status: ok, summary: did a, usage: { in: 100, out: 10, turns: 2 } }
`
	w := &waits{}
	r := startWith(t, setup{nodes: oneNode, script: script, hooks: hooks(w)})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v; want done after two retries", out, err)
	}
	if len(w.got) != 2 || w.got[0] != time.Second || w.got[1] != 2*time.Second {
		t.Errorf("waits = %v, want 1s then 2s", w.got)
	}
	text := ledgerText(t, r)
	if strings.Count(text, `"event":"retry"`) != 2 || !strings.Contains(text, "HTTP 429") || strings.Count(text, `"event":"node_failed"`) != 2 || strings.Count(text, `"event":"node_finished"`) != 1 {
		t.Errorf("the ledger should hold two failed tries, two retries and one finish:\n%s", text)
	}
	if u := r.State.Usage; u.InTok != 105 || u.Turns != 3 {
		t.Errorf("usage = %+v; the failed try's tokens count too", u)
	}
}

func TestTransientFailuresThatOutlastTheRetriesFailTheRunAndAResumeTriesAgain(t *testing.T) {
	script := "steps:\n  a:\n    - { error: down, kind: transient }\n    - { error: down, kind: transient }\n    - { error: down, kind: transient }\n    - { error: down, kind: transient }\n    - result: { status: ok, summary: did a }\n"
	w := &waits{}
	r := startWith(t, setup{nodes: oneNode, script: script, hooks: hooks(w)})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "4 times in a row") || len(w.got) != 3 {
		t.Fatalf("Advance() = %+v, %v after %d waits; want a failed run after 3 retries", out, err, len(w.got))
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Errorf("the resume: %+v, %v; want done", out, err)
	}
}

func TestAnAgentFailureIsNotRetried(t *testing.T) {
	script := "steps:\n  a:\n    - { error: tests fail }\n    - result: { status: ok }\n"
	w := &waits{}
	r := startWith(t, setup{nodes: oneNode, script: script, hooks: hooks(w)})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || len(w.got) != 0 || r.State.Attempts["a"] != 1 {
		t.Errorf("Advance() = %+v, %v; %d waits, %d attempts; want one try and a failed run", out, err, len(w.got), r.State.Attempts["a"])
	}
}

func TestAnInfrastructureFailureStopsTheRunWithNoRetry(t *testing.T) {
	script := "steps:\n  a:\n    - { error: podman is gone, kind: infra }\n    - result: { status: ok }\n"
	w := &waits{}
	r := startWith(t, setup{nodes: oneNode, script: script, hooks: hooks(w)})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || len(w.got) != 0 || !strings.Contains(out.Err.Error(), "podman is gone") {
		t.Errorf("Advance() = %+v, %v; %d waits; want a failed run, no retry", out, err, len(w.got))
	}
}

func TestAUsedUpQuotaPausesTheRunAndAResumeStartsTheNodeAgain(t *testing.T) {
	script := `steps:
  a:
    - actions: [ { write: { path: half.txt, content: "half\n" } } ]
      error: out of credits
      kind: quota
      usage: { in: 40, out: 4, turns: 1 }
    - actions: [ { write: { path: a.txt, content: "a\n" } } ]
      result: { status: ok, summary: did a }
`
	w := &waits{}
	r := startWith(t, setup{nodes: oneNode, script: script, hooks: hooks(w)})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusPaused || len(w.got) != 0 {
		t.Fatalf("Advance() = %+v, %v; want a paused run, with no retry", out, err)
	}
	p := r.State.Paused
	if r.State.Status != run.StatusPaused || p == nil || p.Node != "a" || !strings.Contains(p.Reason, "out of credits") {
		t.Errorf("state = %s, pause %+v", r.State.Status, p)
	}
	text := ledgerText(t, r)
	if !strings.Contains(text, `"event":"run_paused"`) || !strings.Contains(text, "out of credits") {
		t.Errorf("the ledger doesn't say why the run paused:\n%s", text)
	}
	if r.State.Usage.InTok != 40 {
		t.Errorf("usage = %+v; the session that hit the quota still spent tokens", r.State.Usage)
	}
	// The resume opens the run from its files, which puts the leaf back to the checkpoint.
	r = reopen(t, r)
	if _, err := Advance(context.Background(), r); err != nil || r.State.Status != run.StatusDone || r.State.Paused != nil {
		t.Fatalf("the resume left the run %s, pause %+v, %v", r.State.Status, r.State.Paused, err)
	}
	if _, err := os.Stat(filepath.Join(r.RepoDir("repos/app"), "half.txt")); err == nil {
		t.Error("what the paused session wrote is still in the leaf; the node must start from the checkpoint")
	}
}
```

Write `testdata/toy/script-quota.yaml`:

```yaml
# The scripted agent's answers for the toy graph, with the provider's quota used up the first time design runs.
steps:
  design:
    - error: "Claude usage limit reached. Your limit will reset at 3pm."
      kind: quota
      usage: { in: 300, out: 20, turns: 1 }
    - actions: [ { write: { path: design.md, content: "# Design\n" } } ]
      result: { status: ok, summary: wrote design.md, usage: { in: 1000, out: 100, turns: 2 } }
  spec:
    - actions: [ { write: { path: spec.md, content: "# Spec\n" } } ]
      result: { status: ok, summary: wrote spec.md, usage: { in: 1000, out: 100, turns: 2 } }
    - actions: [ { write: { path: spec.md, content: "# Spec\n\nUsers: photographers and their clients.\n" } } ]
      result: { status: ok, summary: named the users in spec.md, usage: { in: 1000, out: 100, turns: 2 } }
  plan:
    - actions: [ { write: { path: plan.md, content: "# Plan\n" } } ]
      result: { status: ok, summary: wrote plan.md, usage: { in: 1000, out: 100, turns: 2 } }
  build:
    - actions: [ { write: { path: build.txt, content: "done\n" } } ]
      result: { status: ok, summary: built it, usage: { in: 2000, out: 400, cache: 1500, turns: 5 } }
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/cli [github.com/ouroboric-dev/odin/internal/cli.test]
internal/cli/e2e_test.go:282:13: undefined: ExitPaused
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/retry_test.go:99:37: undefined: run.StatusPaused
```

- [ ] **Step 3:** write the code.

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 4d98631..077e84f 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -11,6 +11,7 @@ import (
 	"path/filepath"
 	"slices"
 	"strings"
+	"time"
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/odin/internal/engine"
@@ -23,6 +24,7 @@ const (
 	ExitFailed  = 1 // a node failed; fix the cause, then resume
 	ExitRefused = 2 // bad usage or config: nothing ran
 	ExitStopped = 3 // the run waits at an approval point
+	ExitPaused  = 4 // the run waits for the provider's quota; resume it once the quota is back
 )
 
 const usage = `usage:
@@ -33,7 +35,7 @@ const usage = `usage:
   ygg status  <run-id> [--project <dir>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
   ygg sandbox build --realm <dir> [--config <factory.yaml>]
-exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point
+exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point, 4 paused: the provider's quota is used up
 `
 
 // Main runs one ygg command and returns its exit code.
@@ -247,6 +249,10 @@ func (c *command) advance(r *run.Run) int {
 				id, r.State.PendingGate, filepath.Join(r.Dir, "gates"), id, out.Gate)
 		}
 		return ExitStopped
+	case run.StatusPaused:
+		fmt.Fprintf(c.err, "Run %s paused: %v\nNothing is lost. Once the provider's quota is back, run: ygg resume %s\n"+
+			"A resume starts the node again from its last checkpoint.\n", id, out.Err, id)
+		return ExitPaused
 	default:
 		fmt.Fprintf(c.err, "Run %s failed: %v\n%s", id, out.Err, resumeHint(id))
 		return ExitFailed
@@ -282,6 +288,9 @@ func (c *command) status(args []string) int {
 	for _, p := range slices.Sorted(maps.Keys(s.Leaves)) {
 		fmt.Fprintf(c.out, "leaf:     %s on %s at %.12s\n", p, s.Leaves[p].Branch, s.Leaves[p].Checkpoint)
 	}
+	if s.Paused != nil {
+		fmt.Fprintf(c.out, "paused:   at %s since %s: %s\n", s.Paused.Node, s.Paused.Since.Format(time.RFC3339), s.Paused.Reason)
+	}
 	if s.Error != "" {
 		fmt.Fprintf(c.out, "error:    %s\n", s.Error)
 	}
```

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index e87f495..9a0ecdc 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -52,7 +52,7 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 	if s.Pending != "" {
 		return Outcome{Status: run.StatusStopped, Gate: s.Pending}, nil
 	}
-	s.Status, s.Error = run.StatusRunning, ""
+	s.Status, s.Error, s.Paused = run.StatusRunning, "", nil
 	if err := r.Save(); err != nil {
 		return Outcome{}, err
 	}
@@ -81,6 +81,10 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 		if errors.As(err, &hs) {
 			return stopHard(r, n, hs)
 		}
+		var p *pause
+		if errors.As(err, &p) {
+			return pauseRun(r, n, p)
+		}
 		if err != nil {
 			return Outcome{}, err
 		}
```

Apply to `internal/engine/session.go`:

```diff
diff --git a/internal/engine/session.go b/internal/engine/session.go
index 574f5a0..9055b27 100644
--- a/internal/engine/session.go
+++ b/internal/engine/session.go
@@ -8,6 +8,7 @@ import (
 	"time"
 
 	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/jormungandr"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
@@ -129,8 +130,9 @@ func turnsFor(node int, left int64) int {
 }
 
 // nodeError turns the error of a session into what the engine does with it, for a node that is not
-// in a loop: a budget cap that is reached is a hard stop at budget-cap, and everything that is the
-// session's own, an agent failure, retries that ran out or an infrastructure failure, fails the node.
+// in a loop: a budget cap that is reached is a hard stop at budget-cap, a used-up quota pauses the run,
+// and everything else that is the session's own, an agent failure, retries that ran out or an
+// infrastructure failure, fails the node.
 // An error of Odin's own stays as it is.
 func nodeError(err error) error {
 	var af *jormungandr.AgentFailure
@@ -139,8 +141,11 @@ func nodeError(err error) error {
 	if c, ok := jormungandr.IsCap(err); ok {
 		return &hardStop{gate: gungnir.GateBudgetCap, err: c}
 	}
+	if errors.As(err, &q) {
+		return &pause{q}
+	}
 	switch {
-	case errors.As(err, &af), errors.As(err, &ex), errors.As(err, &q):
+	case errors.As(err, &af), errors.As(err, &ex):
 		return &nodeFailure{err}
 	case errors.Is(err, context.Canceled), errors.Is(err, context.DeadlineExceeded):
 		return &nodeFailure{err} // the run was interrupted: it stops failed, and a resume starts the node again
@@ -149,3 +154,20 @@ func nodeError(err error) error {
 	}
 	return err
 }
+
+// pause is a node that ended because the provider's quota is used up: the run waits, resumable, and
+// says why (spec §12).
+type pause struct{ q *jormungandr.QuotaError }
+
+func (p *pause) Error() string { return p.q.Error() }
+
+// pauseRun saves the run as paused at node n. Nothing is lost: the node starts again from the last
+// checkpoint when the operator resumes the run.
+func pauseRun(r *run.Run, n schema.Node, p *pause) (Outcome, error) {
+	s := r.State
+	s.Status, s.Paused = run.StatusPaused, &run.Pause{Node: n.ID, Reason: p.q.Reason, Since: time.Now().UTC()}
+	if err := r.Log(gungnir.Event{Name: gungnir.EventRunPaused, Node: n.ID, Attempt: s.Attempts[n.ID], Result: p.q.Reason}.WithUsage(s.Usage)); err != nil {
+		return Outcome{}, err
+	}
+	return Outcome{Status: run.StatusPaused, Err: p.q}, r.Save()
+}
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 3763c3f..0bb3aba 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -640,7 +640,7 @@ func (r *Run) restoreLeaves(ctx context.Context) error {
 	if s.Status == StatusDone || Quarantines(s.PendingGate) {
 		return nil
 	}
-	restart := s.Status == StatusRunning || s.Status == StatusFailed
+	restart := s.Status == StatusRunning || s.Status == StatusFailed || s.Status == StatusPaused
 	for _, p := range slices.Sorted(maps.Keys(s.Leaves)) {
 		rec := s.Leaves[p]
 		l, err := r.Leaf(p)
```

Apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index 37cbb69..23920d6 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -34,6 +34,7 @@ const (
 	StatusRunning Status = "running" // a process is walking the graph, or died while it was
 	StatusStopped Status = "stopped" // waiting at an approval point
 	StatusFailed  Status = "failed"  // a node failed; resume re-runs it
+	StatusPaused  Status = "paused"  // the provider's quota is used up; resume re-runs the node once it is back
 	StatusDone    Status = "done"
 )
 
@@ -72,6 +73,7 @@ type State struct {
 	Skills       skills.Record          `json:"skills"`                 // every skill the graph names, with the set's hash (spec §5.1)
 	Sandboxes    map[string]gungnir.Env `json:"sandboxes,omitempty"`    // leaf path: its sandbox, while one is up, so a leftover can be stopped
 	Usage        gungnir.Usage          `json:"usage"`
+	Paused       *Pause                 `json:"paused,omitempty"` // why the run is paused
 	Ledger       ledger.Anchor          `json:"ledger"`
 	Error        string                 `json:"error,omitempty"`
 	Exec         *ExecProcess           `json:"exec,omitempty"` // the exec node running now, if any
@@ -79,6 +81,13 @@ type State struct {
 	Updated      time.Time              `json:"updated"`
 }
 
+// Pause is why a run waits for the provider (spec §12).
+type Pause struct {
+	Node   string    `json:"node"`
+	Reason string    `json:"reason"`
+	Since  time.Time `json:"since"`
+}
+
 // LeafRecord is where a run stands in one leaf (spec §4.3).
 type LeafRecord struct {
 	Branch     string `json:"branch"`     // the run's branch: ygg/<run id>
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T131: budget warnings in the ledger, and the caps in `ygg status` and `ygg doctor`

Spec §10.1 lists budget warnings; the operator needs to see the caps without reading `factory.yaml`.

**Files (in `odin`):**

- Modify: `internal/budget/journal.go`, `internal/budget/meter.go`, `internal/cli/cli.go`, `internal/cli/cli_test.go`, `internal/cli/doctor.go`, `internal/cli/doctor_test.go`, `internal/cli/e2e_test.go`, `internal/engine/budget_test.go`, `internal/engine/session.go`, `internal/run/run.go`, `internal/run/state.go`

**Interfaces:**

- Produces: a `budget_warning` line the first time a cap is 80% used and not reached (once for each run's
  cap, once each day for the day's), remembered in `State.Warned`; `run.BudgetJournal(cfg, now)`.
- Produces: `ygg status` prints `caps:     this run <n> of <cap> tokens, <n> of <cap> turns; today ...`
  (and dollars for a paid API), from the config as it is now, and nothing when it can't be read.
  `ygg doctor` prints `OK budget: ...` with the same figures and the journal's folder, and an `ERROR`
  when the folder can't be made or written to, or the day's file can't be read.
- Changes: each CLI test gets a journal of its own (`t.Setenv("XDG_STATE_HOME", t.TempDir())`).

**Acceptance criteria:**

- [ ] One warning when a cap passes 80%, none when it is crossed again, and it survives a resume.
- [ ] `status` and `doctor` show the figures; `doctor` reports an unreadable journal and an unwritable
      folder as errors (the second not as root).

**Named test:** `go test ./internal/engine ./internal/cli -run 'TestTheLedgerWarnsOnce|TestStatusShowsHowMuch|TestDoctorChecksTheSpendJournal'`
in `odin`. **Layer:** `odin`. **Size:** M (187). **Depends on:** v0-T130.

- [ ] **Step 1:** write the tests.

Apply to `internal/cli/cli_test.go`:

```diff
diff --git a/internal/cli/cli_test.go b/internal/cli/cli_test.go
index 68148d4..b9bc245 100644
--- a/internal/cli/cli_test.go
+++ b/internal/cli/cli_test.go
@@ -24,6 +24,8 @@ func ygg(t *testing.T, args ...string) (int, string, string) {
 // beside it. Its roles use script, a file in testdata/toy; extra is added to the config as is.
 func project(t *testing.T, script, extra string) (dir, config string) {
 	t.Helper()
+	// Each test has a spend journal of its own, so what one spends never counts against another's day.
+	t.Setenv("XDG_STATE_HOME", t.TempDir())
 	toy, err := filepath.Abs("../../testdata/toy")
 	if err != nil {
 		t.Fatal(err)
```

Apply to `internal/cli/doctor_test.go`:

```diff
diff --git a/internal/cli/doctor_test.go b/internal/cli/doctor_test.go
index e0b8c7d..eca409c 100644
--- a/internal/cli/doctor_test.go
+++ b/internal/cli/doctor_test.go
@@ -6,6 +6,7 @@ import (
 	"path/filepath"
 	"strings"
 	"testing"
+	"time"
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/odin/internal/tree/treetest"
@@ -58,3 +59,31 @@ func TestDoctorWarnsWhenAPublicUmbrellaListsAPrivateChild(t *testing.T) {
 		t.Errorf("doctor --root alone checked a config:\n%s", out)
 	}
 }
+
+func TestDoctorChecksTheSpendJournal(t *testing.T) {
+	dir, config := project(t, "script.yaml", "")
+	code, out, _ := ygg(t, "doctor", "--project", dir, "--config", config)
+	if code != ExitDone || !strings.Contains(out, "OK    budget: this run 0 of 100000 tokens, 0 of 100 turns; today 0 of 200000 tokens, 0 of 200 turns (journal ") {
+		t.Errorf("doctor: exit %d:\n%s", code, out)
+	}
+	// A journal that can't be read is an error: the day's cap can't be checked.
+	journal := filepath.Join(t.TempDir(), "spend")
+	os.MkdirAll(journal, 0o700)
+	os.WriteFile(filepath.Join(journal, time.Now().Format("2006-01-02")+".jsonl"), []byte("not json\nnot json\n"), 0o600)
+	b, _ := os.ReadFile(config)
+	os.WriteFile(config, append(b, []byte("  journal: "+journal+"\n")...), 0o644)
+	code, out, _ = ygg(t, "doctor", "--project", dir, "--config", config)
+	if code != ExitFailed || !strings.Contains(out, "ERROR budget: ") || !strings.Contains(out, ".jsonl:1 is not a spend entry") {
+		t.Errorf("doctor with a broken journal: exit %d:\n%s", code, out)
+	}
+	// A journal folder that can't be written to is an error too.
+	if os.Getuid() != 0 {
+		locked := filepath.Join(t.TempDir(), "locked")
+		os.MkdirAll(locked, 0o500)
+		b, _ = os.ReadFile(config)
+		os.WriteFile(config, []byte(strings.Replace(string(b), "  journal: "+journal, "  journal: "+filepath.Join(locked, "spend"), 1)), 0o644)
+		if code, out, _ := ygg(t, "doctor", "--project", dir, "--config", config); code != ExitFailed || !strings.Contains(out, "ERROR budget: the spend journal can't be made") {
+			t.Errorf("doctor with a folder it can't write: exit %d:\n%s", code, out)
+		}
+	}
+}
```

Apply to `internal/cli/e2e_test.go`:

```diff
diff --git a/internal/cli/e2e_test.go b/internal/cli/e2e_test.go
index a5b1088..c6c2698 100644
--- a/internal/cli/e2e_test.go
+++ b/internal/cli/e2e_test.go
@@ -298,3 +298,18 @@ func TestAUsedUpQuotaPausesTheRunWithExitCode4AndResumeGoesOn(t *testing.T) {
 		t.Errorf("status still says paused:\n%s", out)
 	}
 }
+
+func TestStatusShowsHowMuchOfTheCapsTheRunAndTheDayHaveUsed(t *testing.T) {
+	dir, config := project(t, "script.yaml", "")
+	ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t))
+	id := runID(t, dir)
+	_, out, _ := ygg(t, "status", id, "--project", dir)
+	if !strings.Contains(out, "caps:     this run 1100 of 100000 tokens, 2 of 100 turns; today 1100 of 200000 tokens, 2 of 200 turns") {
+		t.Errorf("status:\n%s", out)
+	}
+	// A config that can't be read adds nothing to status; the rest still shows.
+	os.WriteFile(config, []byte("not: [valid"), 0o644)
+	if code, out, _ := ygg(t, "status", id, "--project", dir); code != ExitDone || strings.Contains(out, "caps:") || !strings.Contains(out, "usage:") {
+		t.Errorf("status with a broken config: exit %d:\n%s", code, out)
+	}
+}
```

Apply to `internal/engine/budget_test.go`:

```diff
diff --git a/internal/engine/budget_test.go b/internal/engine/budget_test.go
index 65dda92..9ab15d8 100644
--- a/internal/engine/budget_test.go
+++ b/internal/engine/budget_test.go
@@ -193,3 +193,23 @@ func TestASessionIsGivenOnlyTheTurnsTheCapsStillAllow(t *testing.T) {
 		t.Errorf("max turns given = %v, want a:10 b:2 c:7", turns)
 	}
 }
+
+func TestTheLedgerWarnsOnceWhenACapIsEightyPercentUsed(t *testing.T) {
+	script := `steps:
+  a: [ { result: { status: ok, usage: { in: 70, out: 10, turns: 1 } } } ]
+  b: [ { result: { status: ok, usage: { in: 5, out: 0, turns: 1 } } } ]
+  c: [ { result: { status: ok, usage: { in: 4, out: 0, turns: 1 } } } ]
+`
+	nodes := twoNodes + "  - { id: c, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n"
+	r := startWith(t, setup{nodes: nodes, script: script, budget: caps(100, 100, 200000, 200)})
+	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+	text := ledgerText(t, r)
+	if n := strings.Count(text, `"event":"budget_warning"`); n != 1 || !strings.Contains(text, "per-run tokens cap is 80% used: 80 of 100") {
+		t.Errorf("want one warning, at the session that took the tokens to 80 of 100 (%d found):\n%s", n, text)
+	}
+	if !r.State.Warned["run/tokens"] {
+		t.Errorf("warned = %v; the warning must be remembered, so a resume doesn't repeat it", r.State.Warned)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/budget_test.go:212:14: r.State.Warned undefined (type *run.State has no field or method Warned)
internal/engine/budget_test.go:213:98: r.State.Warned undefined (type *run.State has no field or method Warned)
--- FAIL: TestDoctorChecksTheSpendJournal (0.05s)
```

- [ ] **Step 3:** write the code.

Apply to `internal/budget/journal.go`:

```diff
diff --git a/internal/budget/journal.go b/internal/budget/journal.go
index 3cc5c6f..bc46304 100644
--- a/internal/budget/journal.go
+++ b/internal/budget/journal.go
@@ -63,6 +63,12 @@ func (j *Journal) loc() *time.Location {
 	return time.Local
 }
 
+// Today adds up the usage recorded today.
+func (j *Journal) Today() (gungnir.Usage, error) { return j.Day(j.now()) }
+
+// Date names the day of now, such as 2026-10-16, in the operator's zone.
+func (j *Journal) Date() string { return j.now().In(j.loc()).Format("2006-01-02") }
+
 // File returns the journal file of the day t falls in.
 func (j *Journal) File(t time.Time) string {
 	return filepath.Join(j.Dir, t.In(j.loc()).Format("2006-01-02")+".jsonl")
```

Apply to `internal/budget/meter.go`:

```diff
diff --git a/internal/budget/meter.go b/internal/budget/meter.go
index 6511ceb..719ee6a 100644
--- a/internal/budget/meter.go
+++ b/internal/budget/meter.go
@@ -23,7 +23,7 @@ func (m *Meter) Check() *gungnir.CapError {
 	if hit := m.Caps.PerRun.Reached(gungnir.CapRun, *m.Run, m.USD); hit != nil {
 		return hit
 	}
-	day, err := m.Journal.Day(m.Journal.now())
+	day, err := m.Journal.Today()
 	if err != nil {
 		return &gungnir.CapError{Scope: gungnir.CapDay, Dimension: gungnir.CapJournal, Note: err.Error()}
 	}
@@ -31,7 +31,7 @@ func (m *Meter) Check() *gungnir.CapError {
 }
 
 // Today returns what the journal holds for today.
-func (m *Meter) Today() (gungnir.Usage, error) { return m.Journal.Day(m.Journal.now()) }
+func (m *Meter) Today() (gungnir.Usage, error) { return m.Journal.Today() }
 
 // RemainingTurns returns how many turns the caps still allow: the lesser of the run's and the
 // day's, and never below zero. It bounds the turns of a session, so one session can't run far past a
```

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 077e84f..be67003 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -14,6 +14,8 @@ import (
 	"time"
 
 	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/gungnir/schema"
+	"github.com/ouroboric-dev/odin/internal/budget"
 	"github.com/ouroboric-dev/odin/internal/engine"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
@@ -297,5 +299,39 @@ func (c *command) status(args []string) int {
 	u := s.Usage
 	fmt.Fprintf(c.out, "usage:    %d tokens in, %d out, %d from cache; %d turns; $%.4f\n",
 		u.InTok, u.OutTok, u.CacheTok, u.Turns, u.CostUSD)
+	if line := capsLine(s); line != "" {
+		fmt.Fprintf(c.out, "caps:     %s\n", line)
+	}
 	return ExitDone
 }
+
+// capsLine says how much of the caps the run and the day have used, from the run's config as it is now.
+// It is empty when the config can't be read: status then says nothing about caps, rather than guess.
+func capsLine(s *run.State) string {
+	cfg, err := schema.LoadFactory(s.ConfigPath)
+	if err != nil {
+		return ""
+	}
+	j, err := run.BudgetJournal(cfg, nil)
+	if err != nil {
+		return ""
+	}
+	m := &budget.Meter{Run: &s.Usage, Caps: cfg.Budget, USD: cfg.PaysPerToken(), Journal: j}
+	day, err := m.Today()
+	if err != nil {
+		return "the day's spend can't be read: " + err.Error()
+	}
+	return describeCaps(cfg, s.Usage, day)
+}
+
+// describeCaps is the run's and the day's use of each cap, in words.
+func describeCaps(cfg *schema.Factory, runUse, dayUse gungnir.Usage) string {
+	one := func(c schema.Cap, u gungnir.Usage) string {
+		out := fmt.Sprintf("%d of %d tokens, %d of %d turns", u.CapTokens(), c.Tokens, u.Turns, c.Turns)
+		if cfg.PaysPerToken() {
+			out += fmt.Sprintf(", $%.4f of $%.4f", u.CostUSD, c.USD)
+		}
+		return out
+	}
+	return "this run " + one(cfg.Budget.PerRun, runUse) + "; today " + one(cfg.Budget.PerDay, dayUse)
+}
```

Apply to `internal/cli/doctor.go`:

```diff
diff --git a/internal/cli/doctor.go b/internal/cli/doctor.go
index 19cdbc0..5a31add 100644
--- a/internal/cli/doctor.go
+++ b/internal/cli/doctor.go
@@ -9,6 +9,7 @@ import (
 	"path/filepath"
 
 	"github.com/ouroboric-dev/gleipnir/sandbox"
+	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/run"
@@ -51,6 +52,7 @@ func (c *command) doctor(args []string) int {
 		return exit(bad)
 	}
 	if factory != nil {
+		checkBudget(factory, report)
 		c.checkSandbox(f.project, factory, report)
 	}
 	runs := filepath.Join(f.project, ".factory", "runs")
@@ -111,6 +113,33 @@ func checkConfig(path string, report func(level, what, msg string)) *schema.Fact
 	return f
 }
 
+// checkBudget says what the caps are and how much of today's is used, and checks that the spend
+// journal can be read and written: a spend that can't be recorded can't be capped (spec §7.4).
+func checkBudget(f *schema.Factory, report func(level, what, msg string)) {
+	j, err := run.BudgetJournal(f, nil)
+	if err != nil {
+		report("ERROR", "budget", err.Error())
+		return
+	}
+	if err := os.MkdirAll(j.Dir, 0o700); err != nil {
+		report("ERROR", "budget", "the spend journal can't be made: "+err.Error())
+		return
+	}
+	probe, err := os.CreateTemp(j.Dir, ".doctor-*")
+	if err != nil {
+		report("ERROR", "budget", "the spend journal folder isn't writable: "+err.Error())
+		return
+	}
+	probe.Close()
+	os.Remove(probe.Name())
+	day, err := j.Today()
+	if err != nil {
+		report("ERROR", "budget", err.Error())
+		return
+	}
+	report("OK", "budget", describeCaps(f, gungnir.Usage{}, day)+" (journal "+j.Dir+")")
+}
+
 // checkSandbox checks the engine and the sandboxes of the project's runs (spec §6.2, §12): the
 // engine answers and is rootless, the devcontainer CLI is the version the factory was tested with,
 // and no container a killed ygg left is still running. It stops what it finds, because a run that no
```

Apply to `internal/engine/session.go`:

```diff
diff --git a/internal/engine/session.go b/internal/engine/session.go
index 9055b27..ff58b82 100644
--- a/internal/engine/session.go
+++ b/internal/engine/session.go
@@ -95,6 +95,9 @@ func session(ctx context.Context, r *run.Run, sp sessionSpec) (gungnir.Result, g
 		if err := r.Spend(sp.key, spent); err != nil {
 			return stop(err)
 		}
+		if err := warnBudget(r, sp.key); err != nil {
+			return stop(err)
+		}
 		ev = ev.WithUsage(spent)
 		ev.DurationMS = time.Since(began).Milliseconds()
 		if runErr == nil {
@@ -171,3 +174,27 @@ func pauseRun(r *run.Run, n schema.Node, p *pause) (Outcome, error) {
 	}
 	return Outcome{Status: run.StatusPaused, Err: p.q}, r.Save()
 }
+
+// nearCap is the share of a cap at which the ledger gets a warning (spec §10.1).
+const nearCap = 0.8
+
+// warnBudget logs a budget_warning for each cap that is at least 80% used and not yet reached, once
+// per run for a run's cap, and once per day for the day's.
+func warnBudget(r *run.Run, node string) error {
+	m := r.Meter()
+	for _, n := range m.Near(nearCap) {
+		key := string(n.Scope) + "/" + string(n.Dimension)
+		if n.Scope == gungnir.CapDay {
+			key += "/" + r.Setup.Journal.Date()
+		}
+		if r.State.Warned[key] {
+			continue
+		}
+		r.State.Warned[key] = true
+		note := fmt.Sprintf("the per-%s %s cap is %.0f%% used: %.4g of %.4g", n.Scope, n.Dimension, 100*n.Used/n.Limit, n.Used, n.Limit)
+		if err := r.Log(gungnir.Event{Name: gungnir.EventBudgetWarning, Node: node, Note: note}); err != nil {
+			return err
+		}
+	}
+	return nil
+}
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 0bb3aba..90bb22d 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -149,14 +149,10 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 // prepareBudget says where the spend journal is, and the retry policy. The journal's folder is made
 // at the first session, not here: Prepare writes nothing.
 func (s *Setup) prepareBudget(h Hooks) error {
-	dir := s.Config.Budget.Journal
-	if dir == "" {
-		var err error
-		if dir, err = budget.DefaultDir(os.Getenv, os.UserHomeDir); err != nil {
-			return fmt.Errorf("%s: %w", s.ConfigPath, err)
-		}
+	var err error
+	if s.Journal, err = BudgetJournal(s.Config, h.Now); err != nil {
+		return fmt.Errorf("%s: %w", s.ConfigPath, err)
 	}
-	s.Journal = &budget.Journal{Dir: dir, Now: h.Now}
 	s.Backoff, s.Sleep = jormungandr.DefaultBackoff, h.Sleep
 	if h.Backoff != nil {
 		s.Backoff = *h.Backoff
@@ -164,6 +160,19 @@ func (s *Setup) prepareBudget(h Hooks) error {
 	return nil
 }
 
+// BudgetJournal returns the spend journal of a config: the folder it names, or the operator's state
+// folder. now is the clock of a test; nil is the real one.
+func BudgetJournal(cfg *schema.Factory, now func() time.Time) (*budget.Journal, error) {
+	dir := cfg.Budget.Journal
+	if dir == "" {
+		var err error
+		if dir, err = budget.DefaultDir(os.Getenv, os.UserHomeDir); err != nil {
+			return nil, err
+		}
+	}
+	return &budget.Journal{Dir: dir, Now: now}, nil
+}
+
 // findProject places the project in the instance tree: Odin runs on nothing outside it, because a
 // resume resets leaves (spec §4.3).
 func (s *Setup) findProject(ctx context.Context, project string) error {
@@ -440,7 +449,7 @@ func record(project, dir, id string, setup *Setup) (*Run, error) {
 		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles(setup), Skills: setup.Skills,
 		Root: setup.Root, ProjectPath: setup.ProjectPath, Leaves: map[string]LeafRecord{},
 		Attempts: map[string]int{}, Reasons: map[string]string{}, Summaries: map[string]string{},
-		Waived: map[string]bool{}, Created: now, Updated: now,
+		Waived: map[string]bool{}, Warned: map[string]bool{}, Created: now, Updated: now,
 	}}
 	if err := r.Log(gungnir.Event{Name: gungnir.EventRunStarted, Mode: setup.Mode, ConfigHash: setup.ConfigSHA256}); err != nil {
 		r.Close()
```

Apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index 23920d6..d097d73 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -74,6 +74,7 @@ type State struct {
 	Sandboxes    map[string]gungnir.Env `json:"sandboxes,omitempty"`    // leaf path: its sandbox, while one is up, so a leftover can be stopped
 	Usage        gungnir.Usage          `json:"usage"`
 	Paused       *Pause                 `json:"paused,omitempty"` // why the run is paused
+	Warned       map[string]bool        `json:"warned,omitempty"` // the budget warnings already given, so each comes once
 	Ledger       ledger.Anchor          `json:"ledger"`
 	Error        string                 `json:"error,omitempty"`
 	Exec         *ExecProcess           `json:"exec,omitempty"` // the exec node running now, if any
@@ -178,6 +179,9 @@ func LoadState(dir string) (*State, error) {
 	if s.Waived == nil {
 		s.Waived = map[string]bool{}
 	}
+	if s.Warned == nil {
+		s.Warned = map[string]bool{}
+	}
 	if s.Leaves == nil {
 		s.Leaves = map[string]LeafRecord{}
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T132: commands run through the check runner, and a sandbox that fails under one fails the node

Backlog B-017, decision 12. Odin's commands (exec nodes, the checks of a merge and of a pointer) go
through Gleipnir's check runner, on the sandbox's runner or on the host's. An error from the runner is an
infrastructure failure of the node, not a failed command; a program that can't start on the host is a
command that failed, as in a shell.

**Files (in `odin`):**

- Create: `internal/engine/hostrun.go`
- Modify: `internal/engine/engine.go`, `internal/engine/land_test.go`, `internal/engine/sandbox_test.go`, `internal/sandboxfake/fake.go`

**Interfaces:**

- Consumes: `checks.Run` (v0-T114).
- Produces: `engine.command` and `engine.runCheck(ctx, r, node, repo, dir, checks.Spec, logPath)
  (checks.Result, error)`; `engine.hostRunner{r, node, dir}`, a `gungnir.Runner` that runs a command on the
  host in its own process group with only `PATH`, `HOME` (the run's directory) and `LANG`, records the
  group in `run.json` while it runs, exits 127 and writes the reason to the log for a program that can't
  start, and refuses a command with its own environment (credentials belong to the sandbox).
- Changes: `sandboxfake.Sandbox.Fail`, a hook that makes a command fail the way podman does; the test
  constant `checks` is renamed `packChecks`, since a package now imports `checks`.

**Acceptance criteria:**

- [ ] A sandbox that fails under a command fails the node with a message that says so, the sandbox is
      stopped, and a resume with the sandbox working finishes the run.
- [ ] A program that can't start on the host is a failed node with exit status 127 and the reason in its
      log.
- [ ] A command on the host takes no environment of its own.
- [ ] Every exec and check test of Phase 2 and Phase 3 passes unchanged.

**Named test:** `go test ./internal/engine -run 'TestASandboxThatFailsUnderACommand|TestAProgramThatCannotStart|TestACommandOnTheHostTakesNoEnvironment'`
in `odin`. **Layer:** `odin`. **Size:** M (170). **Depends on:** v0-T131; v0-T114 merged.

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/land_test.go`:

```diff
diff --git a/internal/engine/land_test.go b/internal/engine/land_test.go
index f5e6b3a..f28a032 100644
--- a/internal/engine/land_test.go
+++ b/internal/engine/land_test.go
@@ -14,14 +14,14 @@ import (
 
 var bg = context.Background()
 
-// checks are the pack checks of these tests: unit passes when the agent wrote out.txt, and e2e runs
+// packChecks are the pack checks of these tests: unit passes when the agent wrote out.txt, and e2e runs
 // in the project umbrella.
-const checks = "checks:\n  unit: [test, -f, out.txt]\n  e2e: [test, -f, umbrella.yaml]\n  broken: [\"false\"]\n"
+const packChecks = "checks:\n  unit: [test, -f, out.txt]\n  e2e: [test, -f, umbrella.yaml]\n  broken: [\"false\"]\n"
 
 const build = "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n"
 
 func TestAMergeNodeLandsTheBranchThroughTheGate(t *testing.T) {
-	r := startPack(t, "key-points", "", checks, build+"  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n", okScript)
+	r := startPack(t, "key-points", "", packChecks, build+"  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n", okScript)
 	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
 		t.Fatalf("Advance() = %+v, %v", out, err)
 	}
@@ -41,7 +41,7 @@ func TestAMergeNodeLandsTheBranchThroughTheGate(t *testing.T) {
 }
 
 func TestAMergeNodeFailsWhenTheChecksFail(t *testing.T) {
-	r := startPack(t, "key-points", "", checks, build+"  - { id: merge, kind: merge, repo: repos/app, checks: [broken] }\n", okScript)
+	r := startPack(t, "key-points", "", packChecks, build+"  - { id: merge, kind: merge, repo: repos/app, checks: [broken] }\n", okScript)
 	base := r.State.Leaves["repos/app"].Base
 	out, err := Advance(bg, r)
 	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "check broken") {
@@ -56,7 +56,7 @@ func TestAMergeNodeFailsWhenTheChecksFail(t *testing.T) {
 func TestAPointerNodeMovesTheProjectsPointer(t *testing.T) {
 	nodes := build + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
 		"  - { id: move, kind: pointer, repo: repos/app, checks: [unit], acceptance: [e2e] }\n"
-	r := startPack(t, "key-points", "", checks, nodes, okScript)
+	r := startPack(t, "key-points", "", packChecks, nodes, okScript)
 	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
 		t.Fatalf("Advance() = %+v, %v", out, err)
 	}
@@ -74,7 +74,7 @@ func TestAShrunkGeneratedFileStopsAtTheShrinkGuard(t *testing.T) {
 	nodes := build + "  - { id: index, kind: exec, run: [sh, -c, \"echo '| one |' > REPOS.md\"], repo: . }\n" +
 		"  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
 		"  - { id: move, kind: pointer, repo: repos/app, generated: [REPOS.md] }\n"
-	r := startPack(t, "unattended", "", checks, nodes, okScript)
+	r := startPack(t, "unattended", "", packChecks, nodes, okScript)
 	if err := os.WriteFile(filepath.Join(r.Project, "REPOS.md"), []byte(strings.Repeat("| row |\n", 10)), 0o644); err != nil {
 		t.Fatal(err)
 	}
@@ -147,7 +147,7 @@ func TestAPlantedRepositoryStopsAtPolicyViolation(t *testing.T) {
 func TestALeafCheckThatRewritesGitStopsTheRun(t *testing.T) {
 	nodes := build + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
 		"  - { id: move, kind: pointer, repo: repos/app, checks: [rewrite] }\n"
-	r := startPack(t, "unattended", "", checks+"  rewrite: [sh, -c, \"echo 'gitdir: /nonexistent' > .git\"]\n", nodes, okScript)
+	r := startPack(t, "unattended", "", packChecks+"  rewrite: [sh, -c, \"echo 'gitdir: /nonexistent' > .git\"]\n", nodes, okScript)
 	before, _ := git.Run(bg, r.Project, "rev-parse", "HEAD:repos/app")
 	out, err := Advance(bg, r)
 	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GatePolicyViolation {
```

Apply to `internal/engine/sandbox_test.go`:

```diff
diff --git a/internal/engine/sandbox_test.go b/internal/engine/sandbox_test.go
index 0e63d61..693d429 100644
--- a/internal/engine/sandbox_test.go
+++ b/internal/engine/sandbox_test.go
@@ -289,3 +289,51 @@ func TestAReadOnlyRoleThatChangesTheLeafIsAHardStop(t *testing.T) {
 		t.Errorf("the gate file = %s", gate)
 	}
 }
+
+// Backlog B-017: a sandbox that fails under a command is an infrastructure failure of the node. The
+// run stops failed and resumes; it is neither a failed command nor an abort of ygg.
+func TestASandboxThatFailsUnderACommandFailsTheNodeAndAResumeGoesOn(t *testing.T) {
+	if os.Getuid() == 0 {
+		t.Skip("ygg refuses to prepare a sandbox as root: the sandbox's user is the operator's own")
+	}
+	r, fake := startSandboxed(t, buildNodes+"  - { id: check, kind: exec, run: [\"true\"], repo: repos/app }\n", buildScript)
+	broken := true
+	fake.Fail = func(c gungnir.Cmd) error {
+		if broken && c.Argv[0] == "true" {
+			return errors.New("podman couldn't run true in the sandbox (exit 125): the container may be gone")
+		}
+		return nil
+	}
+	out, err := Advance(context.Background(), r)
+	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "container may be gone") {
+		t.Fatalf("Advance() = %+v, %v; want a failed run that says why", out, err)
+	}
+	if len(fake.Downs) != 1 {
+		t.Error("the sandbox of a failed run was left up")
+	}
+	broken = false
+	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
+		t.Errorf("the resume: %+v, %v; want done", out, err)
+	}
+}
+
+func TestAProgramThatCannotStartOnTheHostIsAFailedCommand(t *testing.T) {
+	r := start(t, "key-points", "", "  - { id: x, kind: exec, run: [no-such-program-anywhere], repo: repos/app }\n", "steps: {}\n")
+	out, err := Advance(context.Background(), r)
+	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "exit status 127") {
+		t.Fatalf("Advance() = %+v, %v; want a failed node, like a shell's command not found", out, err)
+	}
+	log, _ := os.ReadFile(filepath.Join(r.Dir, "logs", "x-1.log"))
+	if !strings.Contains(string(log), "no-such-program-anywhere") {
+		t.Errorf("the log = %q; it should say what could not start", log)
+	}
+}
+
+func TestACommandOnTheHostTakesNoEnvironmentOfItsOwn(t *testing.T) {
+	r := start(t, "key-points", "", oneNode, "steps: {}\n")
+	_, err := hostRunner{r: r, node: "x", dir: t.TempDir()}.Run(context.Background(),
+		gungnir.Cmd{Argv: []string{"true"}, Env: map[string]string{"CLAUDE_CODE_OAUTH_TOKEN": "x"}})
+	if err == nil {
+		t.Error("a credential reached the host through a command's environment")
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/sandbox_test.go:301:7: fake.Fail undefined (type *sandboxfake.Sandbox has no field or method Fail)
internal/engine/sandbox_test.go:334:12: undefined: hostRunner
FAIL	github.com/ouroboric-dev/odin/internal/engine [build failed]
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 9a0ecdc..f47415a 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -7,12 +7,11 @@ import (
 	"errors"
 	"fmt"
 	"os"
-	"os/exec"
 	"path/filepath"
 	"strings"
-	"syscall"
 	"time"
 
+	"github.com/ouroboric-dev/gleipnir/checks"
 	"github.com/ouroboric-dev/gleipnir/sandbox"
 	"github.com/ouroboric-dev/gleipnir/scan"
 	"github.com/ouroboric-dev/gungnir"
@@ -202,86 +201,54 @@ func runExec(ctx context.Context, r *run.Run, n schema.Node) error {
 	return nil
 }
 
-// command runs args in repo, without a shell, for node. In a leaf of a run with a sandbox it runs in
-// the leaf's sandbox, which holds no credential and no host path but the leaf (spec §6); anywhere
-// else, which is Odin's own generators in an umbrella and the whole of a run without a sandbox, it
-// runs on the host with only PATH, HOME (the run's own directory, so caches never land in a repo)
-// and LANG. Its output goes to logPath. A timeout (ExecTimeout when 0) or a cancel stops it: on the
-// host by killing its whole process group, in the sandbox by killing what it started there (spec
-// §6.2). cmdErr is the command's failure; err is Odin's, and a sandbox that won't start is a
-// *sandboxFailure or a *hardStop.
+// command runs args in repo, without a shell, for node, through the check runner (spec §2.1). In a
+// leaf of a run with a sandbox it runs in the leaf's sandbox, which holds no credential and no host
+// path but the leaf (spec §6); anywhere else, which is Odin's own generators in an umbrella and the
+// whole of a run without a sandbox, it runs on the host with only PATH, HOME (the run's own directory,
+// so caches never land in a repo) and LANG. Its output goes to logPath. A timeout (ExecTimeout when 0)
+// or a cancel stops it: on the host by killing its whole process group, in the sandbox by killing what
+// it started there (spec §6.2). cmdErr is the command's failure. err is Odin's: a sandbox that won't
+// start is a *sandboxFailure or a *hardStop, and one that fails under the command is an infrastructure
+// failure of the node, never a failed command (spec §12; backlog B-017).
 func command(ctx context.Context, r *run.Run, node, repo, dir string, args []string, timeout time.Duration, logPath string) (cmdErr, err error) {
-	if timeout == 0 {
-		timeout = ExecTimeout
-	}
-	runner, err := r.Runner(ctx, repo)
-	if err != nil {
-		return nil, sandboxStart(err)
-	}
-	if runner != nil {
-		return inSandbox(ctx, runner, args, timeout, logPath)
-	}
-	return onHost(ctx, r, node, args, dir, timeout, logPath)
-}
-
-// inSandbox runs args through runner, with no environment of its own.
-func inSandbox(ctx context.Context, runner gungnir.Runner, args []string, timeout time.Duration, logPath string) (cmdErr, err error) {
-	if err := os.MkdirAll(filepath.Dir(logPath), 0o755); err != nil {
-		return nil, err
-	}
-	out, err := os.Create(logPath)
-	if err != nil {
-		return nil, err
-	}
-	defer out.Close()
-	cctx, cancel := context.WithTimeout(ctx, timeout)
-	defer cancel()
-	res, err := runner.Run(cctx, gungnir.Cmd{Argv: args, Stdout: out, Stderr: out})
+	res, err := runCheck(ctx, r, node, repo, dir, checks.Spec{Name: node, Argv: args, Timeout: orDefault(timeout)}, logPath)
 	switch {
-	case err != nil && errors.Is(cctx.Err(), context.DeadlineExceeded):
-		return fmt.Errorf("timed out after %s", timeout), nil
-	case err != nil && ctx.Err() == nil:
-		return nil, err
 	case err != nil:
-		return nil, ctx.Err()
-	case res.ExitCode != 0:
+		return nil, err
+	case res.TimedOut:
+		return fmt.Errorf("timed out after %s", orDefault(timeout)), nil
+	case !res.Passed:
 		return fmt.Errorf("exit status %d", res.ExitCode), nil
 	}
 	return nil, nil
 }
 
-// onHost runs args in dir on the host, in its own process group.
-func onHost(ctx context.Context, r *run.Run, node string, args []string, dir string, timeout time.Duration, logPath string) (cmdErr, err error) {
-	if err := os.MkdirAll(filepath.Dir(logPath), 0o755); err != nil {
-		return nil, err
+func orDefault(timeout time.Duration) time.Duration {
+	if timeout == 0 {
+		return ExecTimeout
 	}
-	out, err := os.Create(logPath)
+	return timeout
+}
+
+// runCheck runs one command through the check runner: in repo's sandbox when it has one, on the host
+// otherwise. A failure of the sandbox, or of the log, fails the node; a context that ended is the
+// context's error.
+func runCheck(ctx context.Context, r *run.Run, node, repo, dir string, spec checks.Spec, logPath string) (checks.Result, error) {
+	runner, err := r.Runner(ctx, repo)
 	if err != nil {
-		return nil, err
+		return checks.Result{}, sandboxStart(err)
 	}
-	defer out.Close()
-	cctx, cancel := context.WithTimeout(ctx, timeout)
-	defer cancel()
-	cmd := exec.CommandContext(cctx, args[0], args[1:]...)
-	cmd.Dir = dir
-	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + r.Home(), "LANG=C.UTF-8"}
-	cmd.Stdout, cmd.Stderr = out, out
-	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
-	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
-	cmd.WaitDelay = 5 * time.Second
-	if err := cmd.Start(); err != nil {
-		return err, nil
-	}
-	pid := cmd.Process.Pid
-	r.State.Exec = &run.ExecProcess{Node: node, PGID: pid, Start: run.ProcStart(pid)}
-	if err := r.Save(); err != nil {
-		syscall.Kill(-pid, syscall.SIGKILL)
-		cmd.Wait()
-		return nil, err
+	if runner == nil {
+		runner = hostRunner{r: r, node: node, dir: dir}
+	}
+	res, err := checks.Run(ctx, runner, spec, logPath)
+	switch {
+	case err == nil:
+		return res, nil
+	case ctx.Err() != nil:
+		return checks.Result{}, ctx.Err()
 	}
-	cmdErr = cmd.Wait()
-	r.State.Exec = nil
-	return cmdErr, nil
+	return checks.Result{}, &nodeFailure{fmt.Errorf("the sandbox or its log failed while %s ran: %w", spec.Argv[0], err)}
 }
 
 // runChecks runs the pack checks names in order, for the given attempt of node n, and logs each
```

Write `internal/engine/hostrun.go`:

```go
package engine

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/run"
)

// hostRunner runs a command on the host, in dir, in a process group of its own. It is the runner of
// Odin's own generators in an umbrella, and of every command of a run without a sandbox (only
// scripted agents run there). The command gets PATH, HOME, which is the run's own directory so that
// caches never land in a repo, and LANG, and nothing else. While it runs, run.json records its process
// group, so a ygg that is killed leaves a node the next resume or ygg doctor can stop.
type hostRunner struct {
	r    *run.Run
	node string
	dir  string
}

var _ gungnir.Runner = hostRunner{}

func (h hostRunner) Run(ctx context.Context, c gungnir.Cmd) (gungnir.ExecResult, error) {
	if err := c.Validate(); err != nil {
		return gungnir.ExecResult{}, err
	}
	if len(c.Env) > 0 {
		return gungnir.ExecResult{}, errors.New("a command on the host takes no environment of its own: credentials belong to the sandbox")
	}
	cmd := exec.CommandContext(ctx, c.Argv[0], c.Argv[1:]...)
	cmd.Dir = filepath.Join(h.dir, c.Dir)
	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + h.r.Home(), "LANG=C.UTF-8"}
	cmd.Stdin, cmd.Stdout, cmd.Stderr = c.Stdin, c.Stdout, c.Stderr
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = 5 * time.Second
	if err := cmd.Start(); err != nil {
		// A program that can't start is a command that failed, as in a shell: status 127.
		fmt.Fprintf(c.Stderr, "ygg: %v\n", err)
		return gungnir.ExecResult{ExitCode: 127}, nil
	}
	pid := cmd.Process.Pid
	h.r.State.Exec = &run.ExecProcess{Node: h.node, PGID: pid, Start: run.ProcStart(pid)}
	if err := h.r.Save(); err != nil {
		syscall.Kill(-pid, syscall.SIGKILL)
		cmd.Wait()
		return gungnir.ExecResult{}, err
	}
	err := cmd.Wait()
	h.r.State.Exec = nil
	if ctx.Err() != nil {
		return gungnir.ExecResult{}, ctx.Err()
	}
	var ee *exec.ExitError
	switch {
	case err == nil:
		return gungnir.ExecResult{}, nil
	case errors.As(err, &ee):
		return gungnir.ExecResult{ExitCode: ee.ExitCode()}, nil
	}
	return gungnir.ExecResult{}, err
}
```

Apply to `internal/sandboxfake/fake.go`:

```diff
diff --git a/internal/sandboxfake/fake.go b/internal/sandboxfake/fake.go
index 4bd9228..d373ce0 100644
--- a/internal/sandboxfake/fake.go
+++ b/internal/sandboxfake/fake.go
@@ -36,6 +36,9 @@ type Sandbox struct {
 		Exit   int
 		Report string
 	}
+	// Fail, if set, is asked before every command but the secret scan. An error it returns is what Exec
+	// returns, as the real driver does when podman itself fails.
+	Fail func(gungnir.Cmd) error
 	// Intercept, if set, sees every command first. A true handled result is the command's result.
 	Intercept func(gungnir.Cmd) (res gungnir.ExecResult, handled bool)
 }
@@ -58,7 +61,7 @@ func (s *Sandbox) Exec(ctx context.Context, env gungnir.Env, c gungnir.Cmd) (gun
 		return gungnir.ExecResult{}, err
 	}
 	s.mu.Lock()
-	hook, result := s.Intercept, s.Scan
+	hook, result, fail := s.Intercept, s.Scan, s.Fail
 	isScan := slices.Equal(c.Argv, scan.Argv()) // the secret scan: gitleaks isn't on the host
 	if isScan {
 		s.Scans++
@@ -79,6 +82,11 @@ func (s *Sandbox) Exec(ctx context.Context, env gungnir.Env, c gungnir.Cmd) (gun
 		c.Stdout.Write([]byte(result.Report))
 		return gungnir.ExecResult{ExitCode: result.Exit}, nil
 	}
+	if fail != nil {
+		if err := fail(c); err != nil {
+			return gungnir.ExecResult{}, err
+		}
+	}
 	if hook != nil {
 		if res, ok := hook(c); ok {
 			return res, nil
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T133: loop nodes in a run

A graph with a `loop` node must prepare: its roles, its prompts, its checks, its skills and the hosts its
sandbox opens, and `run.json` must have a place for the loop's state. It also gives a resume its
`DiscardWork`, a leaf's reset to its checkpoint for one leaf, which a failed attempt needs. The toy loop
realm is added for the tests.

**Files (in `odin`):**

- Create: `internal/run/loop_test.go`, `testdata/toy-loop/graph.yaml`, `testdata/toy-loop/pack.yaml`, `testdata/toy-loop/prompts/build.md`, `testdata/toy-loop/prompts/review-quality.md`, `testdata/toy-loop/prompts/review-spec.md`, `testdata/toy-loop/script.yaml`, `testdata/toy-loop/templates/app/LICENSE`
- Modify: `internal/run/prepare.go`, `internal/run/run.go`, `internal/run/state.go`

**Interfaces:**

- Consumes: `schema.KindLoop`, `schema.Reviewer`, `Node.SessionKey` (v0-T103); `jormungandr.State`.
- Produces: `(*Setup).checkSession` (a prompt in the realm, a role in `factory.yaml`, one adapter for
  each role); `Prepare` refuses a loop whose reviewer or implementer role is undefined, whose prompt is
  missing, whose check the pack lacks, or whose repo is an umbrella; the roles of a loop's reviewers join
  the sandbox's egress; a reviewer's skills join the record and the drift check.
- Produces: `run.LoopRecord{State jormungandr.State; Escalation *Escalation}`, `run.Escalation{Reason,
  Detail string}`, `State.Loops map[string]*LoopRecord` (always non-nil after a load);
  `(*Run).DiscardWork(ctx, leaf string) error`, the reset a resume does for a node that restarts (saved to
  a ref, or discarded unsaved for a sandboxed leaf, decision 1), which `restoreLeaves` now calls.
- Produces: the realm `testdata/toy-loop`: an implementer, one check and two reviewers in a loop, then
  a gate and the merge; its script is the run that passes at once.

**Acceptance criteria:**

- [ ] A loop prepares, with its reviewers' roles built.
- [ ] Five loops that could not run are refused, each naming the cause.
- [ ] A reviewer's skill is in the record, and a skill nobody vendored refuses the run.
- [ ] `DiscardWork` puts the leaf back to its checkpoint, saves what it removed to the first ref and, for a
      leaf already clean, does nothing.
- [ ] A loop's state and its escalation survive `run.json`.

**Named test:** `go test ./internal/run -run 'TestPrepareAcceptsALoop|TestPrepareRefusesALoop|TestTheSkillsOfALoops|TestDiscardWork|TestALoopsState'`
in `odin`. **Layer:** `odin`. **Size:** M (284). **Depends on:** v0-T132; v0-T103 merged.

- [ ] **Step 1:** write the tests.

Write `internal/run/loop_test.go`:

```go
package run

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gleipnir/skills"
	"github.com/ouroboric-dev/odin/internal/skillfake"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

// loopRealm copies the toy loop realm into a folder of its own, and lets a test change a file of it.
func loopRealm(t *testing.T, edit map[string]func(string) string) string {
	t.Helper()
	src, err := filepath.Abs("../../testdata/toy-loop")
	if err != nil {
		t.Fatal(err)
	}
	dst := t.TempDir()
	if err := os.CopyFS(dst, os.DirFS(src)); err != nil {
		t.Fatal(err)
	}
	for name, f := range edit {
		b, err := os.ReadFile(filepath.Join(dst, name))
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dst, name), []byte(f(string(b))), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dst
}

// loopConfig is a factory.yaml whose implementer and reviewer roles are scripted with the toy loop's script.
func loopConfig(t *testing.T, roles string) string {
	t.Helper()
	script, _ := filepath.Abs("../../testdata/toy-loop/script.yaml")
	body := strings.ReplaceAll(roles, "SCRIPT", script) + fullCaps
	return writeConfig(t, t.TempDir(), body)
}

const loopRoles = "roles:\n  implementer: { agent: scripted, model: none, script: SCRIPT }\n  reviewer: { agent: scripted, model: none, script: SCRIPT }\n"

func TestPrepareAcceptsALoopAndBuildsTheRolesOfItsReviewers(t *testing.T) {
	project := treetest.Project(t, "repos/app")
	s, err := Prepare(ctx, Options{Project: project, Config: loopConfig(t, loopRoles), Realm: loopRealm(t, nil)})
	if err != nil {
		t.Fatal(err)
	}
	if s.Agents["implementer"] == nil || s.Agents["reviewer"] == nil {
		t.Errorf("agents = %v; a loop's reviewers run as roles too", s.Agents)
	}
	if got := s.Leaves(); len(got) != 1 || got[0] != "repos/app" || len(s.Create) != 0 {
		t.Errorf("leaves %v, create %v", got, s.Create)
	}
}

func TestPrepareRefusesALoopThatCouldNotRun(t *testing.T) {
	project := treetest.Project(t, "repos/app")
	cases := map[string]struct {
		roles string
		edit  map[string]func(string) string
		want  string
	}{
		"a reviewer role factory.yaml lacks": {"roles:\n  implementer: { agent: scripted, model: none, script: SCRIPT }\n", nil, "uses role reviewer"},
		"an implementer role it lacks":       {"roles:\n  reviewer: { agent: scripted, model: none, script: SCRIPT }\n", nil, "uses role implementer"},
		"a reviewer prompt that is missing": {loopRoles, map[string]func(string) string{"graph.yaml": func(s string) string {
			return strings.Replace(s, "prompts/review-quality.md", "prompts/nope.md", 1)
		}}, "nope.md"},
		"a check the pack lacks": {loopRoles, map[string]func(string) string{"graph.yaml": func(s string) string {
			return strings.Replace(s, "checks: [unit]\n    reviewers", "checks: [unit, lint]\n    reviewers", 1)
		}}, "runs check lint"},
		"a loop in a repo that is an umbrella": {loopRoles, map[string]func(string) string{"graph.yaml": func(s string) string {
			return strings.Replace(s, "kind: loop\n    repo: repos/app", "kind: loop\n    repo: .", 1)
		}}, "umbrella"},
	}
	for name, c := range cases {
		_, err := Prepare(ctx, Options{Project: project, Config: loopConfig(t, c.roles), Realm: loopRealm(t, c.edit)})
		if err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: Prepare() = %v, want an error containing %q", name, err, c.want)
		}
	}
}

func TestTheSkillsOfALoopsReviewersAreInTheRecord(t *testing.T) {
	project := treetest.Project(t, "repos/app")
	realm := loopRealm(t, map[string]func(string) string{"graph.yaml": func(s string) string {
		return strings.Replace(s, "prompts/review-quality.md }", "prompts/review-quality.md, skills: [plain-language] }", 1)
	}})
	lib := skillfake.Libraries(t, "plain-language", "Write plainly.")
	s, err := Prepare(ctx, Options{Project: project, Config: loopConfig(t, loopRoles), Realm: realm, Hooks: Hooks{Libs: lib}})
	if err != nil || strings.Join(s.Skills.Skills, ",") != "plain-language" || len(s.Skills.Hash) != 64 {
		t.Fatalf("Prepare() = %+v, %v; the reviewer's skill belongs in the record", s.Skills, err)
	}
	if _, err := Prepare(ctx, Options{Project: project, Config: loopConfig(t, loopRoles), Realm: realm, Hooks: Hooks{Libs: &skills.Libraries{Pinned: skillfake.Libraries(t, "other", "x").Pinned}}}); err == nil || !strings.Contains(err.Error(), "skill") {
		t.Errorf("Prepare() = %v; a reviewer that names a skill nobody vendored never starts", err)
	}
}

func TestDiscardWorkPutsALeafBackToItsCheckpointAndSavesWhatItRemoved(t *testing.T) {
	project := treetest.Project(t, "repos/app")
	r, err := Start(ctx, Options{Project: project, Config: loopConfig(t, loopRoles), Realm: loopRealm(t, nil)})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	dir := r.RepoDir("repos/app")
	if err := os.WriteFile(filepath.Join(dir, "half.txt"), []byte("half\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := r.DiscardWork(ctx, "repos/app"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "half.txt")); err == nil {
		t.Error("half.txt is still in the leaf")
	}
	if len(r.Saved) != 1 || !strings.Contains(r.Saved[0], "refs/ygg/"+r.State.ID+"/discarded/1") {
		t.Errorf("Saved = %v; what a reset removes is saved to a ref first", r.Saved)
	}
	// Nothing changed since: nothing to save.
	if err := r.DiscardWork(ctx, "repos/app"); err != nil || len(r.Saved) != 1 {
		t.Errorf("DiscardWork() of a clean leaf: %v, saved %v", err, r.Saved)
	}
}

func TestALoopsStateSurvivesInRunJSON(t *testing.T) {
	project := treetest.Project(t, "repos/app")
	r, err := Start(ctx, Options{Project: project, Config: loopConfig(t, loopRoles), Realm: loopRealm(t, nil)})
	if err != nil {
		t.Fatal(err)
	}
	id := r.State.ID
	r.State.Loops["build"] = &LoopRecord{Escalation: &Escalation{Reason: "attempts-exhausted", Detail: "3 attempts ended with 1 blocking finding(s) open"}}
	r.State.Loops["build"].State.Attempt = 2
	if err := r.Save(); err != nil {
		t.Fatal(err)
	}
	r.Close()
	s, err := LoadState(Dir(project, id))
	if err != nil {
		t.Fatal(err)
	}
	if rec := s.Loops["build"]; rec == nil || rec.State.Attempt != 2 || rec.Escalation == nil || rec.Escalation.Reason != "attempts-exhausted" {
		t.Errorf("loops = %+v", s.Loops)
	}
	fresh, _ := LoadState(Dir(project, id))
	if fresh.Loops == nil || fresh.Warned == nil {
		t.Error("the maps a state loads with are nil; the engine writes to them")
	}
}
```

Write `testdata/toy-loop/graph.yaml`:

```yaml
# The toy loop graph: an implementer, a check and two reviewers in a bounded loop, then a gate and the
# merge. Its sessions work in one leaf, repos/app, which the realm creates when a project lacks it.
name: toy-loop
version: 1.0.0
nodes:
  - id: build
    kind: loop
    repo: repos/app
    role: implementer
    prompt: prompts/build.md
    attempts: 3
    checks: [unit]
    reviewers:
      - { id: spec, role: reviewer, prompt: prompts/review-spec.md }
      - { id: quality, role: reviewer, prompt: prompts/review-quality.md }
  - { id: feature-gate, kind: gate, gate: feature }
  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }
```

Write `testdata/toy-loop/pack.yaml`:

```yaml
name: toy-loop
version: 0.1.0
graph: graph.yaml
checks:
  unit: [grep, -q, done, build.txt] # in the leaf
leaves:
  repos/app: { description: the toy app, template: templates/app, first_commit: [LICENSE] }
```

Write `testdata/toy-loop/prompts/build.md`:

```md
Write build.txt with the word done in it.
```

Write `testdata/toy-loop/prompts/review-quality.md`:

```md
Review the work for simplicity and quality.
```

Write `testdata/toy-loop/prompts/review-spec.md`:

```md
Review the work against the brief: does build.txt do what was asked?
```

Write `testdata/toy-loop/script.yaml`:

```yaml
# The scripted answers for the toy loop graph, for the run that passes at once. The implementer's
# sessions are steps.build, one per attempt; a reviewer's are steps.build-<reviewer id>.
steps:
  build:
    - actions: [ { write: { path: build.txt, content: "done\n" } } ]
      result: { status: ok, summary: built it, usage: { in: 2000, out: 400, cache: 1500, turns: 5 } }
  build-spec:
    - result: { status: ok, summary: reviewed, report: [], usage: { in: 800, out: 100, turns: 2 } }
  build-quality:
    - result: { status: ok, summary: reviewed, report: [], usage: { in: 800, out: 100, turns: 2 } }
```

Write `testdata/toy-loop/templates/app/LICENSE`:

```text
The toy app is a test fixture of Odin, AGPL-3.0-only.
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/run [github.com/ouroboric-dev/odin/internal/run.test]
internal/run/loop_test.go:114:14: r.DiscardWork undefined (type *Run has no field or method DiscardWork)
internal/run/loop_test.go:124:14: r.DiscardWork undefined (type *Run has no field or method DiscardWork)
internal/run/loop_test.go:136:10: r.State.Loops undefined (type *State has no field or method Loops)
```

- [ ] **Step 3:** write the code.

Apply to `internal/run/prepare.go`:

```diff
diff --git a/internal/run/prepare.go b/internal/run/prepare.go
index 003c543..bc31f3b 100644
--- a/internal/run/prepare.go
+++ b/internal/run/prepare.go
@@ -47,8 +47,8 @@ func (s *Setup) prepareSandbox() error {
 	}
 	egress := slices.Clone(s.Pack.Sandbox.Egress)
 	for _, n := range s.Graph.Nodes {
-		if n.Kind == schema.KindAgent {
-			egress = append(egress, agents.Hosts(s.Config.Roles[n.Role].Agent)...)
+		for _, role := range nodeRoles(n) {
+			egress = append(egress, agents.Hosts(s.Config.Roles[role].Agent)...)
 		}
 	}
 	sort.Strings(egress)
@@ -76,6 +76,9 @@ func (s *Setup) prepareSkills(override *skills.Libraries) error {
 	var names []string
 	for _, n := range s.Graph.Nodes {
 		names = append(names, n.Skills...)
+		for _, rv := range n.Reviewers {
+			names = append(names, rv.Skills...)
+		}
 	}
 	rec, err := s.Libs.Record(names)
 	if err != nil {
@@ -84,3 +87,19 @@ func (s *Setup) prepareSkills(override *skills.Libraries) error {
 	s.Skills = rec
 	return nil
 }
+
+// nodeRoles returns the roles a node's sessions run as: an agent node's, or a loop's implementer and
+// its reviewers.
+func nodeRoles(n schema.Node) []string {
+	switch n.Kind {
+	case schema.KindAgent:
+		return []string{n.Role}
+	case schema.KindLoop:
+		out := []string{n.Role}
+		for _, rv := range n.Reviewers {
+			out = append(out, rv.Role)
+		}
+		return out
+	}
+	return nil
+}
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 90bb22d..6f544f0 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -219,22 +219,36 @@ func (s *Setup) checkNode(ctx context.Context, graphPath string, n schema.Node)
 			return fmt.Errorf("%s: node %s runs check %s, which the pack doesn't define", graphPath, n.ID, c)
 		}
 	}
-	if n.Kind != schema.KindAgent {
+	if n.Kind != schema.KindAgent && n.Kind != schema.KindLoop {
 		return nil
 	}
-	if _, err := os.Stat(filepath.Join(s.RealmDir, n.Prompt)); err != nil {
-		return fmt.Errorf("%s: node %s: %w", graphPath, n.ID, err)
+	if err := s.checkSession(graphPath, n.ID, n.Role, n.Prompt); err != nil {
+		return err
+	}
+	for _, rv := range n.Reviewers {
+		if err := s.checkSession(graphPath, n.SessionKey(rv), rv.Role, rv.Prompt); err != nil {
+			return err
+		}
 	}
-	if s.Agents[n.Role] != nil {
+	return nil
+}
+
+// checkSession checks that a session of node (a node, or a loop's reviewer) can run: its prompt file
+// is in the realm and its role is in factory.yaml, whose adapter is built once per role.
+func (s *Setup) checkSession(graphPath, node, role, prompt string) error {
+	if _, err := os.Stat(filepath.Join(s.RealmDir, prompt)); err != nil {
+		return fmt.Errorf("%s: node %s: %w", graphPath, node, err)
+	}
+	if s.Agents[role] != nil {
 		return nil
 	}
-	role, ok := s.Config.Roles[n.Role]
+	r, ok := s.Config.Roles[role]
 	if !ok {
-		return fmt.Errorf("%s: node %s uses role %s, which %s doesn't define", graphPath, n.ID, n.Role, s.ConfigPath)
+		return fmt.Errorf("%s: node %s uses role %s, which %s doesn't define", graphPath, node, role, s.ConfigPath)
 	}
 	var err error
-	if s.Agents[n.Role], err = agents.New(role, filepath.Dir(s.ConfigPath), agents.Options{Privacy: s.Config.Privacy}); err != nil {
-		return fmt.Errorf("role %s: %w", n.Role, err)
+	if s.Agents[role], err = agents.New(r, filepath.Dir(s.ConfigPath), agents.Options{Privacy: s.Config.Privacy}); err != nil {
+		return fmt.Errorf("role %s: %w", role, err)
 	}
 	return nil
 }
@@ -449,7 +463,7 @@ func record(project, dir, id string, setup *Setup) (*Run, error) {
 		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles(setup), Skills: setup.Skills,
 		Root: setup.Root, ProjectPath: setup.ProjectPath, Leaves: map[string]LeafRecord{},
 		Attempts: map[string]int{}, Reasons: map[string]string{}, Summaries: map[string]string{},
-		Waived: map[string]bool{}, Warned: map[string]bool{}, Created: now, Updated: now,
+		Waived: map[string]bool{}, Warned: map[string]bool{}, Loops: map[string]*LoopRecord{}, Created: now, Updated: now,
 	}}
 	if err := r.Log(gungnir.Event{Name: gungnir.EventRunStarted, Mode: setup.Mode, ConfigHash: setup.ConfigSHA256}); err != nil {
 		r.Close()
@@ -639,6 +653,35 @@ func Quarantines(g gungnir.Gate) bool {
 	return g == gungnir.GatePolicyViolation || g == gungnir.GateRealSecrets
 }
 
+// DiscardWork puts leaf p back to its run's last checkpoint, as a resume does for a node that restarts
+// (spec §4.3): what the work since then changed is saved to refs/ygg/<run>/discarded/<n> first, so
+// Odin never discards work it didn't make. In a run with a sandbox that work was never scanned for
+// secrets, so it is discarded and not saved (decision 12), and only commits already in git are kept.
+// What happened is added to r.Saved.
+func (r *Run) DiscardWork(ctx context.Context, p string) error {
+	s := r.State
+	rec := s.Leaves[p]
+	l, err := r.Leaf(p)
+	if err != nil {
+		return err
+	}
+	saved, _ := l.Git(ctx, "for-each-ref", "--format=%(refname)", "refs/ygg/"+s.ID+"/discarded/")
+	ref := fmt.Sprintf("refs/ygg/%s/discarded/%d", s.ID, strings.Count(saved, "\n")+min(len(saved), 1)+1)
+	msg := "ygg: run " + s.ID + ", what resetting " + p + " to its checkpoint discarded"
+	if r.Sandbox != nil {
+		return r.discardUnscanned(ctx, l, p, ref, rec, msg)
+	}
+	if ok, err := l.Save(ctx, ref, rec.Checkpoint, msg); err != nil {
+		return fmt.Errorf("saving %s before resetting it to its checkpoint: %w", p, err)
+	} else if ok {
+		r.Saved = append(r.Saved, fmt.Sprintf("%s: the changes since its checkpoint are saved as %s (git -C %s show --stat %s)", p, ref, r.RepoDir(p), ref))
+	}
+	if err := l.Reset(ctx, rec.Branch, rec.Checkpoint); err != nil {
+		return fmt.Errorf("resetting %s to its checkpoint: %w", p, err)
+	}
+	return nil
+}
+
 // restoreLeaves puts every leaf back to its checkpoint when the run's node restarts (interrupted
 // or failed), and otherwise refuses a leaf that changed while the run waited: Odin never discards
 // work it didn't make. In a run with a sandbox, the working tree a node left is discarded unsaved,
@@ -657,25 +700,8 @@ func (r *Run) restoreLeaves(ctx context.Context) error {
 			return err
 		}
 		if restart {
-			// Odin never discards work it didn't make: save what the reset removes first.
-			saved, _ := l.Git(ctx, "for-each-ref", "--format=%(refname)", "refs/ygg/"+s.ID+"/discarded/")
-			ref := fmt.Sprintf("refs/ygg/%s/discarded/%d", s.ID, strings.Count(saved, "\n")+min(len(saved), 1)+1)
-			msg := "ygg: run " + s.ID + ", what resetting " + p + " to its checkpoint discarded"
-			if r.Sandbox != nil {
-				// A node's work in a sandbox is scanned for secrets only at its checkpoint, so what it
-				// left is discarded, never put in git (decision 12). Commits are already in git: kept.
-				if err := r.discardUnscanned(ctx, l, p, ref, rec, msg); err != nil {
-					return err
-				}
-				continue
-			}
-			if ok, err := l.Save(ctx, ref, rec.Checkpoint, msg); err != nil {
-				return fmt.Errorf("saving %s before resetting it to its checkpoint: %w", p, err)
-			} else if ok {
-				r.Saved = append(r.Saved, fmt.Sprintf("%s: the changes since its checkpoint are saved as %s (git -C %s show --stat %s)", p, ref, r.RepoDir(p), ref))
-			}
-			if err := l.Reset(ctx, rec.Branch, rec.Checkpoint); err != nil {
-				return fmt.Errorf("resetting %s to its checkpoint: %w", p, err)
+			if err := r.DiscardWork(ctx, p); err != nil {
+				return err
 			}
 			continue
 		}
```

Apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index d097d73..a4de7ac 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -20,6 +20,7 @@ import (
 
 	"github.com/ouroboric-dev/gleipnir/skills"
 	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/jormungandr"
 	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/lock"
 )
@@ -75,6 +76,7 @@ type State struct {
 	Usage        gungnir.Usage          `json:"usage"`
 	Paused       *Pause                 `json:"paused,omitempty"` // why the run is paused
 	Warned       map[string]bool        `json:"warned,omitempty"` // the budget warnings already given, so each comes once
+	Loops        map[string]*LoopRecord `json:"loops,omitempty"`  // loop node id: where its loop stands
 	Ledger       ledger.Anchor          `json:"ledger"`
 	Error        string                 `json:"error,omitempty"`
 	Exec         *ExecProcess           `json:"exec,omitempty"` // the exec node running now, if any
@@ -82,6 +84,19 @@ type State struct {
 	Updated      time.Time              `json:"updated"`
 }
 
+// LoopRecord is where one loop node stands (spec §4.2): Jormungandr's state, which holds the attempt,
+// the phase and every finding, and why the loop waits for a person, if it does.
+type LoopRecord struct {
+	State      jormungandr.State `json:"state"`
+	Escalation *Escalation       `json:"escalation,omitempty"`
+}
+
+// Escalation is why a loop gave up (spec §7.3): see the Reason constants of Jormungandr.
+type Escalation struct {
+	Reason string `json:"reason"`
+	Detail string `json:"detail"`
+}
+
 // Pause is why a run waits for the provider (spec §12).
 type Pause struct {
 	Node   string    `json:"node"`
@@ -182,6 +197,9 @@ func LoadState(dir string) (*State, error) {
 	if s.Warned == nil {
 		s.Warned = map[string]bool{}
 	}
+	if s.Loops == nil {
+		s.Loops = map[string]*LoopRecord{}
+	}
 	if s.Leaves == nil {
 		s.Leaves = map[string]LeafRecord{}
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T134: the loop in a run: an implementer, the check ladder, findings that go back, and an attempt used up by a failed session

Spec §4.2, §4.6 and decisions 2, 8, 12, 13. A `loop` node runs as Jormungandr says and Odin's steps do the
work: the implementer's session with the open findings in its prompt, a checkpoint commit (with the
secret scan of Phase 3), the checks through the check runner with the leaf put back to the commit after
each, the ledger lines, and `run.json`.

**Files (in `odin`):**

- Create: `internal/engine/loop.go`, `internal/engine/loop_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/session.go`

**Interfaces:**

- Consumes: `jormungandr.Run`, `Steps`, `Feedback`; `session`, `nodeError`, `runCheck` (v0-T128, v0-T129,
  v0-T132); `checks.Result.Finding` (v0-T114); `(*Run).DiscardWork` (v0-T133).
- Produces: `engine.runLoop(ctx, r, n)`, wired into `Advance`: it keeps the loop's record in
  `State.Loops[n.ID]`, returns at once for a loop that passed, maps `Capped` to a hard stop at
  `budget-cap` and `Paused` to the pause, and, until v0-T136, an escalation to a failed node that carries
  the reason. A pass writes the summary and a `loop_attempt` line.
- Produces: `loopSteps{r, n, st}` implementing `jormungandr.Steps`. `Implement` logs a `loop_attempt` line
  ("attempt k of N starts with m finding(s) open"), builds the prompt (the prompt file, the node's
  skills, the brief, `Feedback(open, lastFailure, State.Reasons[node])`), runs `session` under the node's
  id, and commits; when the session failed as an agent it discards the leaf's work first. `Check` runs the
  pack check named, in the leaf's sandbox or on the host, with a ten-minute limit, tidies the leaf
  (a planted repository is a hard stop at `policy-violation`), logs a `check_result` line, and returns the
  outcome whose finding's place is `logs/<node>-<attempt>-<check>.log:1`. `Record` writes
  `finding_raised`, `finding_closed` (with the attempts it took and the reopens) and `finding_reopened`
  lines. `Save` is `Run.Save`. `Review` is the next task's.
- Changes `session`: before a retry the leaf goes back to its checkpoint (`OnRetry` calls `DiscardWork`),
  so a dropped session's half work never reaches the next try.

**Acceptance criteria:**

- [ ] Work that passes its checks is one attempt: the run's state, the summary, the ledger lines and the
      commit are as described.
- [ ] A failing check goes back to the next attempt as a finding in its prompt, the first attempt was
      told nothing, the finding closes with the attempts it took, and the leaf is clean after the checks.
- [ ] A session that fails as an agent costs the attempt, leaves no half work in the leaf, is in the next
      attempt's prompt, its tokens count, and what it wrote is kept in a ref.
- [ ] A session retried after a transient failure starts from the checkpoint.

**Named test:** `go test ./internal/engine -run 'TestALoopWhoseWork|TestAFailingCheckGoesBack|TestASessionThatFailsAsAnAgent|TestARetriedSessionStartsFromTheCheckpoint'`
in `odin`. **Layer:** `odin`. **Size:** M (338). **Depends on:** v0-T133; v0-T123 merged.

- [ ] **Step 1:** write the tests.

Write `internal/engine/loop_test.go`:

```go
package engine

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/run"
)

const loopNode = "  - { id: build, kind: loop, repo: repos/app, role: planner, prompt: p.md, attempts: 3, checks: [unit] }\n"
const unitCheck = "checks:\n  unit: [grep, -q, done, build.txt]\n"

func write(path, content string) string {
	return "{ write: { path: " + path + ", content: \"" + content + "\\n\" } }"
}

func startLoop(t *testing.T, mode, script string) *run.Run {
	t.Helper()
	return startWith(t, setup{mode: mode, pack: unitCheck, nodes: loopNode, script: script})
}

func transcript(t *testing.T, r *run.Run, name string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(r.Dir, "transcripts", name+".json"))
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func TestALoopWhoseWorkPassesItsChecksIsOneAttempt(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok, summary: built it, usage: { in: 100, out: 10, turns: 2 } }\n"
	r := startLoop(t, "key-points", script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	rec := r.State.Loops["build"]
	if rec == nil || !rec.State.Passed || rec.State.Attempt != 1 || r.State.Attempts["build"] != 1 {
		t.Errorf("loop record = %+v, sessions %d", rec, r.State.Attempts["build"])
	}
	if got := r.State.Summaries["build"]; !strings.Contains(got, "passed in attempt 1 of 3") {
		t.Errorf("summary = %q", got)
	}
	text := ledgerText(t, r)
	for _, want := range []string{`"event":"loop_attempt"`, "attempt 1 of 3 starts with 0 finding(s) open", `"event":"check_result"`, "unit: exit 0", `"ygg.result":"passed"`, `"event":"node_finished"`} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s:\n%s", want, text)
		}
	}
	l, _ := r.Leaf("repos/app")
	if head, _ := l.Head(context.Background()); head != r.State.Leaves["repos/app"].Checkpoint {
		t.Error("the attempt's work is not committed as the leaf's checkpoint")
	}
}

func TestAFailingCheckGoesBackToTheNextAttemptAsAFinding(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "todo") + " ]\n      result: { status: ok, summary: first try, usage: { in: 100, out: 10, turns: 2 } }\n" +
		"    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok, summary: second try, usage: { in: 100, out: 10, turns: 2 } }\n"
	r := startLoop(t, "key-points", script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if r.State.Attempts["build"] != 2 || r.State.Loops["build"].State.Attempt != 2 {
		t.Errorf("sessions %d, loop attempt %d; want 2 and 2", r.State.Attempts["build"], r.State.Loops["build"].State.Attempt)
	}
	first, second := transcript(t, r, "build-1"), transcript(t, r, "build-2")
	if strings.Contains(first, "Findings to fix") {
		t.Errorf("the first attempt was told of findings:\n%s", first)
	}
	for _, want := range []string{"## Findings to fix", "- check-unit (blocker, from unit) at logs/build-1-unit.log:1", "check unit failed: exit status 1", "Do not say any of them is fixed"} {
		if !strings.Contains(second, want) {
			t.Errorf("the second attempt's prompt lacks %q:\n%s", want, second)
		}
	}
	text := ledgerText(t, r)
	for _, want := range []string{`"event":"finding_raised"`, `"ygg.finding.id":"check-unit"`, `"ygg.finding.severity":"blocker"`,
		`"event":"finding_closed"`, `"ygg.finding.attempts":2`, "unit: exit status 1", "unit: exit 0"} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s:\n%s", want, text)
		}
	}
	// The check wrote nothing that stays: the leaf is at the commit the checks ran on.
	l, _ := r.Leaf("repos/app")
	if st, _ := l.Git(context.Background(), "status", "--porcelain"); st != "" {
		t.Errorf("the leaf holds %q after the checks", st)
	}
}

func TestASessionThatFailsAsAnAgentUsesUpAnAttemptAndLeavesNoHalfWork(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("junk.txt", "half a thought") + " ]\n      error: the tests hung and the session timed out\n      usage: { in: 50, out: 5, turns: 1 }\n" +
		"    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok, summary: built it }\n"
	r := startLoop(t, "unattended", script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if r.State.Loops["build"].State.Attempt != 2 {
		t.Errorf("the loop is in attempt %d; the failed session was an attempt", r.State.Loops["build"].State.Attempt)
	}
	if _, err := os.Stat(filepath.Join(r.RepoDir("repos/app"), "junk.txt")); err == nil {
		t.Error("what the failed session wrote is still in the leaf")
	}
	second := transcript(t, r, "build-2")
	if !strings.Contains(second, "## The last attempt failed") || !strings.Contains(second, "the tests hung and the session timed out") {
		t.Errorf("attempt 2 wasn't told why attempt 1 failed:\n%s", second)
	}
	if r.State.Usage.InTok != 50 {
		t.Errorf("usage = %+v; the failed session's tokens count", r.State.Usage)
	}
	if len(r.Saved) != 1 || !strings.Contains(r.Saved[0], "discarded") {
		t.Errorf("Saved = %v; what the reset removed is kept in a ref", r.Saved)
	}
}

func TestARetriedSessionStartsFromTheCheckpoint(t *testing.T) {
	script := "steps:\n  a:\n    - actions: [ " + write("half.txt", "half") + " ]\n      error: the connection dropped\n      kind: transient\n" +
		"    - actions: [ " + write("a.txt", "a") + " ]\n      result: { status: ok }\n"
	w := &waits{}
	r := startWith(t, setup{nodes: oneNode, script: script, hooks: hooks(w)})
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if _, err := os.Stat(filepath.Join(r.RepoDir("repos/app"), "half.txt")); err == nil {
		t.Error("the retry ran on what the dropped session wrote")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestALoopWhoseWorkPassesItsChecksIsOneAttempt (0.22s)
    loop_test.go:43: loop record = <nil>, sessions 0
    loop_test.go:46: summary = ""
    loop_test.go:51: the ledger lacks "event":"loop_attempt":
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index f47415a..e3a69bd 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -63,6 +63,8 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 		switch n.Kind {
 		case schema.KindAgent:
 			err = runAgent(ctx, r, n)
+		case schema.KindLoop:
+			err = runLoop(ctx, r, n)
 		case schema.KindExec:
 			err = runExec(ctx, r, n)
 		case schema.KindGate:
```

Write `internal/engine/loop.go`:

```go
package engine

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/ouroboric-dev/gleipnir/checks"
	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/jormungandr"
	"github.com/ouroboric-dev/odin/internal/leaf"
	"github.com/ouroboric-dev/odin/internal/run"
)

// runLoop runs loop node n (spec §4.2): an implementer, then a ladder of checks and reviewers, with the
// findings that stay open going back to the next attempt, until the work passes or the attempts run
// out. Jormungandr decides what comes next; this file is what its steps do. The loop's state is in
// run.json, saved at every boundary, so a stop for a cap or a quota, or a crash, repeats no attempt and
// loses no finding.
func runLoop(ctx context.Context, r *run.Run, n schema.Node) error {
	s := r.State
	cfg := loopConfig(n)
	rec := s.Loops[n.ID]
	if rec == nil {
		rec = &run.LoopRecord{State: *jormungandr.NewState(cfg)}
		s.Loops[n.ID] = rec
	}
	if rec.State.Passed {
		return nil // an earlier run of this node passed; a rejection that sends the work back clears the record
	}
	steps := &loopSteps{r: r, n: n, st: &rec.State}
	out, err := jormungandr.Run(ctx, cfg, &rec.State, steps)
	if err != nil {
		return nodeError(err)
	}
	switch out.Kind {
	case jormungandr.Passed:
		delete(s.Reasons, n.ID)
		s.Summaries[n.ID] = fmt.Sprintf("passed in attempt %d of %d with %d minor finding(s) open", out.Attempts, rec.State.Limit, len(rec.State.Book.Open()))
		return r.Log(gungnir.Event{Name: gungnir.EventLoopAttempt, Node: n.ID, Attempt: out.Attempts, Result: "passed"})
	case jormungandr.Capped:
		return &hardStop{gate: gungnir.GateBudgetCap, err: out.Cap}
	case jormungandr.Paused:
		return &pause{out.Quota}
	}
	// Escalated: the next task stops the run for a person; until then the node fails with the reason.
	return &nodeFailure{fmt.Errorf("the loop %s gave up (%s): %s", n.ID, out.Reason, out.Detail)}
}

func loopConfig(n schema.Node) jormungandr.Config {
	cfg := jormungandr.Config{Attempts: n.Attempts, Checks: n.Checks}
	for _, rv := range n.Reviewers {
		cfg.Reviewers = append(cfg.Reviewers, rv.ID)
	}
	return cfg
}

// loopSteps is what a loop's steps do in a run: sessions, checks, ledger lines and run.json.
type loopSteps struct {
	r  *run.Run
	n  schema.Node
	st *jormungandr.State
}

var _ jormungandr.Steps = (*loopSteps)(nil)

// prompt is the text of a session: the prompt file of the realm, the skills it names, and the brief.
func (l *loopSteps) prompt(file string, skillNames []string) (string, error) {
	b, err := os.ReadFile(filepath.Join(l.r.Setup.RealmDir, file))
	if err != nil {
		return "", err
	}
	text := string(b)
	skillText, err := l.r.Setup.Libs.Load(skillNames)
	if err != nil {
		return "", err
	}
	if skillText != "" {
		text += "\n\n" + skillText
	}
	if l.r.Setup.BriefText != "" {
		text += "\n\n## Brief\n\n" + l.r.Setup.BriefText
	}
	return text, nil
}

// Implement runs one implementer session with the findings that are open, and commits what it did.
// A session that failed as an agent does leaves the leaf as the last attempt left it: what it wrote is
// discarded, so the next attempt does not build on half a thought.
func (l *loopSteps) Implement(ctx context.Context, attempt int, in jormungandr.Input) error {
	r, n := l.r, l.n
	text, err := l.prompt(n.Prompt, n.Skills)
	if err != nil {
		return err
	}
	text += "\n\n" + jormungandr.Feedback(in.Open, in.LastFailure, r.State.Reasons[n.ID])
	if err := r.Log(gungnir.Event{Name: gungnir.EventLoopAttempt, Node: n.ID, Attempt: attempt,
		Result: fmt.Sprintf("attempt %d of %d starts with %d finding(s) open", attempt, l.st.Limit, len(in.Open))}); err != nil {
		return err
	}
	res, ev, err := session(ctx, r, sessionSpec{key: n.ID, role: n.Role, repo: n.Repo, text: text,
		maxTurns: n.MaxTurns, timeout: time.Duration(n.Timeout)})
	if err != nil {
		var af *jormungandr.AgentFailure
		if errors.As(err, &af) {
			if derr := r.DiscardWork(ctx, n.Repo); derr != nil {
				return derr
			}
		}
		return err
	}
	if ev.Commit, err = checkpoint(ctx, r, n, attempt); err != nil {
		return failCheckpoint(r, ev, err)
	}
	ev.Name, ev.Result = gungnir.EventNodeFinished, res.Summary
	return r.Log(ev)
}

// Check runs one check of the ladder in the leaf, on the work the attempt committed, and puts the leaf
// back to that commit afterwards (backlog B-004). A failing check is a finding; a check that could not
// run, because the sandbox failed under it, is an error.
func (l *loopSteps) Check(ctx context.Context, attempt int, name string) (jormungandr.CheckOutcome, error) {
	r, n := l.r, l.n
	rel := filepath.Join("logs", fmt.Sprintf("%s-%d-%s.log", n.ID, attempt, name))
	res, err := runCheck(ctx, r, n.ID, n.Repo, r.RepoDir(n.Repo), checks.Spec{Name: name, Argv: r.Setup.Pack.Checks[name], Timeout: ExecTimeout},
		filepath.Join(r.Dir, rel))
	if err == nil {
		var lf *leaf.Leaf
		if lf, err = r.Leaf(n.Repo); err == nil {
			err = tidied(ctx, lf, nil)
		}
	}
	if err != nil {
		if leaf.IsPolicy(err) { // a check rewrote the leaf's .git or planted a repository
			return jormungandr.CheckOutcome{}, &hardStop{gate: gungnir.GatePolicyViolation, err: err}
		}
		return jormungandr.CheckOutcome{}, err
	}
	result := name + ": exit 0"
	if !res.Passed {
		result = fmt.Sprintf("%s: exit status %d", name, res.ExitCode)
		if res.TimedOut {
			result = name + ": timed out"
		}
	}
	if err := r.Log(gungnir.Event{Name: gungnir.EventCheckResult, Node: n.ID, Attempt: attempt, Result: result,
		DurationMS: res.Duration.Milliseconds()}); err != nil {
		return jormungandr.CheckOutcome{}, err
	}
	out := jormungandr.CheckOutcome{Passed: res.Passed, FindingID: checks.FindingID(name),
		Proof: fmt.Sprintf("check %s ran in attempt %d and passed (%s)", name, attempt, filepath.ToSlash(rel))}
	if f, failed := res.Finding(filepath.ToSlash(rel) + ":1"); failed {
		out.Finding = f
	}
	return out, nil
}

// Review is the next task's: a loop with reviewers does not run yet.
func (l *loopSteps) Review(context.Context, int, string, []gungnir.Finding, []string) (string, error) {
	return "", errors.New("reviewers are not run yet")
}

// Record writes the changes to the findings to the ledger (spec §10.1): when each was raised, how
// many attempts each took to close, and how often it came back.
func (l *loopSteps) Record(attempt int, changes []jormungandr.Change) error {
	for _, c := range changes {
		ev := gungnir.Event{Node: l.n.ID, Attempt: attempt, FindingID: c.Finding.ID, FindingSource: c.Finding.Source,
			FindingSeverity: string(c.Finding.Severity), Note: firstLine(c.Finding.Location + ": " + c.Finding.Claim)}
		switch c.Kind {
		case jormungandr.Raised:
			ev.Name = gungnir.EventFindingRaised
		case jormungandr.Closed:
			ev.Name, ev.FindingAttempts, ev.FindingReopens = gungnir.EventFindingClosed, c.Attempts, c.Reopens
		case jormungandr.Reopened:
			ev.Name, ev.FindingReopens = gungnir.EventFindingReopened, c.Reopens
		}
		if err := l.r.Log(ev); err != nil {
			return err
		}
	}
	return nil
}

// Save keeps the loop's state in run.json.
func (l *loopSteps) Save(*jormungandr.State) error { return l.r.Save() }

// firstLine is the first line of s, cut to 200 characters.
func firstLine(s string) string {
	line, _, _ := strings.Cut(strings.TrimSpace(s), "\n")
	if len([]rune(line)) > 200 {
		return string([]rune(line)[:200]) + "…"
	}
	return line
}
```

Apply to `internal/engine/session.go`:

```diff
diff --git a/internal/engine/session.go b/internal/engine/session.go
index ff58b82..ef6ccdd 100644
--- a/internal/engine/session.go
+++ b/internal/engine/session.go
@@ -46,6 +46,12 @@ func session(ctx context.Context, r *run.Run, sp sessionSpec) (gungnir.Result, g
 	meter := r.Meter()
 	retrier := jormungandr.Retrier{Backoff: r.Setup.Backoff, Meter: meter, Sleep: r.Setup.Sleep,
 		OnRetry: func(try int, wait time.Duration, why string) error {
+			// The failed try may have left half its work in the leaf: the retry starts from the checkpoint.
+			if _, ok := r.State.Leaves[sp.repo]; ok {
+				if err := r.DiscardWork(ctx, sp.repo); err != nil {
+					return err
+				}
+			}
 			return r.Log(gungnir.Event{Name: gungnir.EventRetry, Node: sp.key, Attempt: r.State.Attempts[sp.key],
 				Note: fmt.Sprintf("try %d failed for a reason that is not the agent's; it runs again in %s: %s", try, wait, why)})
 		}}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T135: reviewers in the loop: read-only sessions that report findings, and an ignored file counts as a change

Spec §9.5 rung 6, §4.6, decision 14 and backlog B-018. A loop's reviewers run on work that passed every
check, as read-only sessions, and answer with findings.

**Files (in `odin`):**

- Create: `internal/engine/reviewers_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/loop.go`

**Interfaces:**

- Consumes: `jormungandr.ReviewRequest`; `session` (v0-T128).
- Produces: `loopSteps.Review`: the reviewer's prompt (its prompt file, its skills, the brief, then
  `ReviewRequest(id, open, passed)`), run read-only under the session key `<loop>-<reviewer>`; its whole
  answer goes back to Jormungandr. A change to the leaf is a hard stop at `policy-violation`.
- Changes: `engine.snapshot(ctx, r, repo)` lists the leaf with `git status --porcelain --ignored -uall`;
  `readOnly(ctx, r, repo, role, before)` compares it with the snapshot taken before the session and
  refuses any file that appeared or went, naming it (`+ !! notes.log`). A read-only agent node uses the
  same pair, so an ignored file an earlier check left is not the reader's doing.

**Acceptance criteria:**

- [ ] A reviewer is told its own findings and the checks that passed; its finding goes back to the next
      attempt; it closes only with a proof that names a check, and the ledger says so.
- [ ] Reviewers run read-only and the implementer does not.
- [ ] A reviewer that writes a file `.gitignore` names stops the run at `policy-violation`, with the leaf
      kept and the file named in the gate file; the same for a read-only agent node.
- [ ] An ignored file that was there before the session is not a change.

**Named test:** `go test ./internal/engine -run 'TestAReviewerSeesItsFindings|TestReviewersRunReadOnly|TestAReviewerThatWritesAnIgnoredFile|TestIgnoredFilesThatWereThere|TestAReadOnlyRoleThatWritesAnIgnoredFile'`
in `odin`. **Layer:** `odin`. **Size:** M (182). **Depends on:** v0-T134; v0-T116 merged.

- [ ] **Step 1:** write the tests.

Write `internal/engine/reviewers_test.go`:

```go
package engine

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/run"
)

// reviewLoop is a loop with the check unit and one reviewer, spec, who runs as the scripted planner.
const reviewLoop = `  - id: build
    kind: loop
    repo: repos/app
    role: planner
    prompt: p.md
    attempts: 3
    checks: [unit]
    reviewers:
      - { id: spec, role: planner, prompt: p.md }
`

func startReview(t *testing.T, mode, script string) *run.Run {
	t.Helper()
	return startWith(t, setup{mode: mode, pack: unitCheck, nodes: reviewLoop, script: script})
}

const majorFinding = `{ id: spec-1, source: spec, severity: major, location: "build.txt:1", claim: "build.txt doesn't say what the brief asks", status: open }`

func fixedFinding(proof string) string {
	return `{ id: spec-1, source: spec, severity: major, location: "build.txt:1", claim: "build.txt doesn't say what the brief asks", status: fixed, proof: "` + proof + `" }`
}

func TestAReviewerSeesItsFindingsAndClosesThemOnlyWithProof(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done v1") + " ]\n      result: { status: ok }\n" +
		"    - actions: [ " + write("build.txt", "done v2") + " ]\n      result: { status: ok }\n" +
		"  build-spec:\n    - result: { status: ok, report: [ " + majorFinding + " ] }\n" +
		"    - result: { status: ok, report: [ " + fixedFinding("build.txt:1 now says what the brief asks; check unit passed") + " ] }\n"
	r := startReview(t, "key-points", script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if r.State.Loops["build"].State.Attempt != 2 || r.State.Attempts["build-spec"] != 2 {
		t.Errorf("loop attempt %d, reviewer sessions %d; want 2 and 2", r.State.Loops["build"].State.Attempt, r.State.Attempts["build-spec"])
	}
	first, second := transcript(t, r, "build-spec-1"), transcript(t, r, "build-spec-2")
	if !strings.Contains(first, "Your id is spec") || !strings.Contains(first, "The checks that passed on this work: unit.") || strings.Contains(first, "reported before") {
		t.Errorf("the first review was told:\n%s", first)
	}
	if !strings.Contains(second, "Findings you reported before") || !strings.Contains(second, `\"id\": \"spec-1\"`) {
		t.Errorf("the second review wasn't shown its finding:\n%s", second)
	}
	if !strings.Contains(transcript(t, r, "build-2"), "- spec-1 (major, from spec) at build.txt:1") {
		t.Error("the second implementer attempt wasn't given the reviewer's finding")
	}
	text := ledgerText(t, r)
	for _, want := range []string{`"event":"finding_raised"`, `"ygg.finding.id":"spec-1"`, `"ygg.finding.source":"spec"`, `"event":"finding_closed"`, `"ygg.finding.attempts":2`} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s:\n%s", want, text)
		}
	}
	// The implementer is never told it may close a finding; only the reviewer did.
	if got := r.State.Loops["build"].State.Book.Records["spec-1"]; got == nil || got.Status != gungnir.FindingFixed || !strings.Contains(got.Proof, "check unit passed") {
		t.Errorf("record = %+v", got)
	}
}

func TestReviewersRunReadOnlyAndTheImplementerDoesNot(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n  build-spec:\n    - result: { status: ok, report: [] }\n"
	r := startReview(t, "key-points", script)
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if !strings.Contains(transcript(t, r, "build-spec-1"), `"read_only": true`) || !strings.Contains(transcript(t, r, "build-1"), `"read_only": false`) {
		t.Error("the reviewer must run read-only, and the implementer not")
	}
}

// Backlog B-018: an ignored file is a change too.
func TestAReviewerThatWritesAnIgnoredFileIsAHardStop(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write(".gitignore", "*.log") + ", " + write("build.txt", "done") + " ]\n      result: { status: ok }\n" +
		"  build-spec:\n    - actions: [ " + write("notes.log", "I was here") + " ]\n      result: { status: ok, report: [] }\n"
	r := startReview(t, "unattended", script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GatePolicyViolation {
		t.Fatalf("Advance() = %+v, %v, gate %s; want a stop at policy-violation", out, err, r.State.PendingGate)
	}
	if _, err := os.Stat(filepath.Join(r.RepoDir("repos/app"), "notes.log")); err != nil {
		t.Error("the leaf was cleaned; a quarantine keeps what the reader wrote, for investigation")
	}
	gate, _ := os.ReadFile(filepath.Join(r.Dir, "gates", "build-1.md"))
	if !strings.Contains(string(gate), "the read-only role planner changed the leaf") || !strings.Contains(string(gate), "+ !! notes.log") {
		t.Errorf("the gate file = %s", gate)
	}
}

func TestIgnoredFilesThatWereThereBeforeAreNotTheReadersDoing(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write(".gitignore", "*.log") + ", " + write("build.txt", "done") + ", " + write("cache.log", "left by the build") + " ]\n      result: { status: ok }\n" +
		"  build-spec:\n    - result: { status: ok, report: [] }\n"
	r := startReview(t, "key-points", script)
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v; an ignored file the build left is not the reviewer's", out, err)
	}
}

// Backlog B-018, for a read-only agent node.
func TestAReadOnlyRoleThatWritesAnIgnoredFileIsAHardStop(t *testing.T) {
	nodes := "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n  - { id: look, kind: agent, role: planner, prompt: p.md, repo: repos/app, read_only: true }\n"
	script := "steps:\n  a:\n    - actions: [ " + write(".gitignore", "*.log") + " ]\n      result: { status: ok }\n  look:\n    - actions: [ " + write("notes.log", "I was here") + " ]\n      result: { status: ok }\n"
	r := start(t, "key-points", "", nodes, script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GatePolicyViolation {
		t.Errorf("Advance() = %+v, %v, gate %s; want a stop at policy-violation", out, err, r.State.PendingGate)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAReviewerSeesItsFindingsAndClosesThemOnlyWithProof (0.27s)
    reviewers_test.go:45: Advance() = {Status: Gate: Err:<nil> Warn:[]}, reviewers are not run yet
--- FAIL: TestReviewersRunReadOnlyAndTheImplementerDoesNot (0.28s)
    reviewers_test.go:76: Advance() = {Status: Gate: Err:<nil> Warn:[]}, reviewers are not run yet
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index e3a69bd..3d29f69 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -145,13 +145,19 @@ func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 	if reason := s.Reasons[n.ID]; reason != "" {
 		text += "\n\n## Rejected at the approval point\n\n" + reason + "\n"
 	}
+	var before string
+	if n.ReadOnly {
+		if before, err = snapshot(ctx, r, n.Repo); err != nil {
+			return err
+		}
+	}
 	res, ev, err := session(ctx, r, sessionSpec{key: n.ID, role: n.Role, repo: n.Repo, text: text, readOnly: n.ReadOnly,
 		maxTurns: n.MaxTurns, timeout: time.Duration(n.Timeout)})
 	if err != nil {
 		return nodeError(err)
 	}
 	if n.ReadOnly {
-		if err := readOnly(ctx, r, n); err != nil {
+		if err := readOnly(ctx, r, n.Repo, n.Role, before); err != nil {
 			return failCheckpoint(r, ev, err)
 		}
 	}
@@ -354,21 +360,38 @@ func scanForSecrets(ctx context.Context, r *run.Run, l *leaf.Leaf, repo string)
 	return &nodeFailure{err}
 }
 
-// readOnly refuses a read-only agent that changed the leaf: the tool flags and the adapter's
-// settings keep such a role to read and search tools, and this is the check that doesn't trust them.
-func readOnly(ctx context.Context, r *run.Run, n schema.Node) error {
-	l, err := r.Leaf(n.Repo)
+// snapshot lists what a leaf holds beyond its last commit, one line for each file: changed files,
+// untracked files and ignored files too (backlog B-018). A read-only role gets no write tool, but a
+// file it wrote that .gitignore names would not show in an ordinary status.
+func snapshot(ctx context.Context, r *run.Run, repo string) (string, error) {
+	l, err := r.Leaf(repo)
 	if err != nil {
-		return err
+		return "", err
 	}
-	st, err := l.Git(ctx, "status", "--porcelain")
+	return l.Git(ctx, "status", "--porcelain", "--ignored", "-uall")
+}
+
+// readOnly refuses a read-only agent that changed the leaf: the tool flags and the adapter's settings
+// keep such a role to read and search tools, and this is the check that doesn't trust them. before is
+// what snapshot said before the session, since an ignored file an earlier check left is not the
+// reader's doing. A file that appeared, or went, is a hard stop at policy-violation.
+func readOnly(ctx context.Context, r *run.Run, repo, role, before string) error {
+	after, err := snapshot(ctx, r, repo)
 	if err != nil {
 		return err
 	}
-	if st != "" {
-		return &hardStop{gate: gungnir.GatePolicyViolation, err: &leaf.PolicyError{Reason: "the read-only role " + n.Role + " changed the leaf:\n" + st}}
+	if after == before {
+		return nil
+	}
+	var changed []string
+	for _, side := range []struct{ from, other, mark string }{{after, before, "+ "}, {before, after, "- "}} {
+		for _, line := range strings.Split(side.from, "\n") {
+			if line != "" && !strings.Contains("\n"+side.other+"\n", "\n"+line+"\n") {
+				changed = append(changed, side.mark+line)
+			}
+		}
 	}
-	return nil
+	return &hardStop{gate: gungnir.GatePolicyViolation, err: &leaf.PolicyError{Reason: "the read-only role " + role + " changed the leaf:\n" + strings.Join(changed, "\n")}}
 }
 
 // sandboxFailure is a sandbox that wouldn't start: an infrastructure failure, so the run stops
```

Apply to `internal/engine/loop.go`:

```diff
diff --git a/internal/engine/loop.go b/internal/engine/loop.go
index 1f65ebb..e240f9d 100644
--- a/internal/engine/loop.go
+++ b/internal/engine/loop.go
@@ -160,9 +160,36 @@ func (l *loopSteps) Check(ctx context.Context, attempt int, name string) (jormun
 	return out, nil
 }
 
-// Review is the next task's: a loop with reviewers does not run yet.
-func (l *loopSteps) Review(context.Context, int, string, []gungnir.Finding, []string) (string, error) {
-	return "", errors.New("reviewers are not run yet")
+// Review runs one read-only reviewer on the committed work and returns its whole answer, which
+// Jormungandr reads. The reviewer is told what it reported before and which checks passed. Whatever
+// it changed in the leaf, an ignored file too, is a hard stop at policy-violation.
+func (l *loopSteps) Review(ctx context.Context, attempt int, reviewer string, open []gungnir.Finding, passed []string) (string, error) {
+	r, n := l.r, l.n
+	var rv schema.Reviewer
+	for _, c := range n.Reviewers {
+		if c.ID == reviewer {
+			rv = c
+		}
+	}
+	text, err := l.prompt(rv.Prompt, rv.Skills)
+	if err != nil {
+		return "", err
+	}
+	text += "\n\n" + jormungandr.ReviewRequest(rv.ID, open, passed)
+	before, err := snapshot(ctx, r, n.Repo)
+	if err != nil {
+		return "", err
+	}
+	res, ev, err := session(ctx, r, sessionSpec{key: n.SessionKey(rv), role: rv.Role, repo: n.Repo, text: text, readOnly: true,
+		maxTurns: rv.MaxTurns, timeout: time.Duration(rv.Timeout)})
+	if err != nil {
+		return "", err
+	}
+	if err := readOnly(ctx, r, n.Repo, rv.Role, before); err != nil {
+		return "", failCheckpoint(r, ev, err)
+	}
+	ev.Name, ev.Result = gungnir.EventNodeFinished, res.Summary
+	return res.Output, r.Log(ev)
 }
 
 // Record writes the changes to the findings to the ledger (spec §10.1): when each was raised, how
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T136: a loop that gives up stops the run at escalation: findings listed, approve or reject, and an unreadable reviewer never passes

Spec §7.3 and §4.6, decisions 7 and 8. When the attempts run out, or a reviewer's answer can't be read
twice, the run stops for a person, in every mode.

**Files (in `odin`):**

- Create: `internal/engine/escalation.go`, `internal/engine/escalation_test.go`
- Modify: `internal/cli/cli.go`, `internal/engine/engine.go`, `internal/engine/gates.go`, `internal/engine/loop.go`

**Interfaces:**

- Produces: `engine.escalation{out jormungandr.Outcome}` and `stopEscalation(r, n, e)`: it writes
  `gates/<loop>-<attempt>.md` (what happened, the findings still open with their claims, the cost so far,
  and the decisions on offer), logs `gate_pending`, and stops the run with `PendingGate` `escalation`.
  The `escalation` line in the ledger says `stopped`, or `blocked` for an unattended run.
- Changes `Approve`: at an escalation it is refused, with nothing changed, unless the loop ran out of
  attempts; then the work goes on as it is, the loop is marked passed, the summary says it was accepted
  with its findings open, and the findings stay open. `Reject` at an escalation gives the loop another full
  set of attempts (`State.Extend`), clears the escalation and puts the reason where the implementer reads
  it; at a gate whose rejection re-runs a loop, the loop's record is cleared, so the loop starts over.
  `engine.Rejectable` and `engine.Approvable` say what a stop takes.
- Changes the CLI: after a stop it offers what the stop takes (both; `reject` only; `approve` only for a
  hard stop); `ygg status` has a `loop:` line for each loop (its attempt and phase, or that it passed or
  gave up in an attempt, and how many findings are open).

**Acceptance criteria:**

- [ ] A loop that runs out of attempts stops the run in all three modes with the right ledger lines, a
      gate file that lists the findings and offers both decisions.
- [ ] Rejecting it with a reason gives attempts 4 to 6, with the reason and the findings in the fourth
      attempt's prompt; a rejection with no reason is refused.
- [ ] Approving it goes on with the findings open, closes none, and records the note.
- [ ] A reviewer that can't be read twice stops the run; the loop is not passed; approving is refused and
      changes nothing; rejecting asks the reviewer again without another implementer attempt.
- [ ] A report that drops a finding or closes one without proof stops the loop too, with the finding open.
- [ ] A rejection at a gate after a passed loop starts the loop over, with the reason.
- [ ] An escalation survives a reopened run.

**Named test:** `go test ./internal/engine -run 'TestALoopThatRunsOutOfAttempts|TestRejectingAnEscalatedLoop|TestApprovingAnExhaustedLoop|TestAMalformedReviewerOutput|TestAReviewerReportThatDrops|TestASendBackAfterAPassedLoop|TestAnEscalatedLoopSurvives'`
in `odin`. **Layer:** `odin`. **Size:** M (375). **Depends on:** v0-T135.

- [ ] **Step 1:** write the tests.

Write `internal/engine/escalation_test.go`:

```go
package engine

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/jormungandr"
	"github.com/ouroboric-dev/odin/internal/run"
)

// passesAt is an implementer whose work fails the unit check in every attempt but the done-th, which
// writes what the check accepts; 0 means it never does.
func passesAt(done int) string {
	var b strings.Builder
	b.WriteString("steps:\n  build:\n")
	for i := 1; i <= 6; i++ {
		word := "todo"
		if i == done {
			word = "done"
		}
		b.WriteString("    - actions: [ " + write("build.txt", word) + " ]\n      result: { status: ok, usage: { in: 10, out: 1, turns: 1 } }\n")
	}
	return b.String()
}

func neverPasses() string { return passesAt(0) }

func TestALoopThatRunsOutOfAttemptsStopsTheRunForAPersonInEveryMode(t *testing.T) {
	for _, mode := range []string{"step-by-step", "key-points", "unattended"} {
		r := startLoop(t, mode, neverPasses())
		out, err := Advance(context.Background(), r)
		if err != nil || out.Status != run.StatusStopped || out.Gate != "build" || r.State.PendingGate != gungnir.GateEscalation || r.State.Position != 0 {
			t.Fatalf("%s: Advance() = %+v, %v, gate %s; want a stop at escalation", mode, out, err, r.State.PendingGate)
		}
		rec := r.State.Loops["build"]
		if rec.Escalation == nil || rec.Escalation.Reason != jormungandr.ReasonExhausted || r.State.Attempts["build"] != 3 {
			t.Errorf("%s: loop record %+v, %d sessions; want 3 attempts and attempts-exhausted", mode, rec, r.State.Attempts["build"])
		}
		text := ledgerText(t, r)
		want := `"ygg.result":"stopped"`
		if mode == "unattended" {
			want = `"ygg.result":"blocked"`
		}
		if !strings.Contains(text, `"event":"escalation"`) || !strings.Contains(text, want) || !strings.Contains(text, "attempts-exhausted") || !strings.Contains(text, `"event":"gate_pending"`) {
			t.Errorf("%s: the ledger lacks an escalation that is %s:\n%s", mode, want, text)
		}
		gate, _ := os.ReadFile(filepath.Join(r.Dir, "gates", "build-3.md"))
		for _, want := range []string{"Escalation at loop build", "3 attempts ended with 1 blocking finding(s) open", "- check-unit (blocker, from unit)", "ygg reject " + r.State.ID + " build --reason", "ygg approve " + r.State.ID + " build"} {
			if !strings.Contains(string(gate), want) {
				t.Errorf("%s: the gate file lacks %q:\n%s", mode, want, gate)
			}
		}
		if !Rejectable(r) || !Approvable(r) {
			t.Errorf("%s: an exhausted loop takes both a rejection and an approval", mode)
		}
	}
}

func TestRejectingAnEscalatedLoopGivesItAFullSetOfAttemptsWithTheOperatorsGuidance(t *testing.T) {
	// Attempts 1 to 3 fail; so do 4 and 5, which the rejection allows; the sixth, the last it allows, passes.
	r := startLoop(t, "key-points", passesAt(6))
	if out, _ := Advance(context.Background(), r); out.Status != run.StatusStopped {
		t.Fatalf("Advance() = %+v", out)
	}
	if err := Reject(context.Background(), r, "build", "  "); err == nil {
		t.Error("a rejection with no reason was accepted")
	}
	if err := Reject(context.Background(), r, "build", "The check wants the word done, in lower case."); err != nil {
		t.Fatal(err)
	}
	if rec := r.State.Loops["build"]; rec.Escalation != nil || rec.State.Limit != 6 || rec.State.Attempt != 4 {
		t.Errorf("after the rejection: %+v; want attempts 4 to 6 and no escalation", rec)
	}
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v; want done after the rejection", out, err)
	}
	if got := transcript(t, r, "build-4"); !strings.Contains(got, "## Guidance from the operator") || !strings.Contains(got, "in lower case") || !strings.Contains(got, "- check-unit (blocker") {
		t.Errorf("the fourth attempt was told:\n%s", got)
	}
	text := ledgerText(t, r)
	if !strings.Contains(text, `"event":"gate_rejected"`) || !strings.Contains(text, `"event":"finding_closed"`) || !strings.Contains(text, `"ygg.finding.attempts":`) {
		t.Errorf("the ledger lacks the rejection or the close:\n%s", text)
	}
}

func TestApprovingAnExhaustedLoopGoesOnWithTheFindingsOpen(t *testing.T) {
	nodes := loopNode + "  - { id: after, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n"
	script := neverPasses() + "  after:\n    - result: { status: ok, summary: went on }\n"
	r := startWith(t, setup{pack: unitCheck, nodes: nodes, script: script})
	Advance(context.Background(), r)
	if err := Approve(context.Background(), r, "build", "the check is too strict; ship it"); err != nil {
		t.Fatal(err)
	}
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if got := r.State.Summaries["build"]; !strings.Contains(got, "accepted by the operator") || !strings.Contains(got, "1 finding(s) open") {
		t.Errorf("summary = %q", got)
	}
	if f := r.State.Loops["build"].State.Book.Records["check-unit"]; f == nil || f.Status != gungnir.FindingOpen {
		t.Errorf("record = %+v; an approval closes nothing", f)
	}
	if text := ledgerText(t, r); strings.Contains(text, `"event":"finding_closed"`) || !strings.Contains(text, "the check is too strict") {
		t.Errorf("the ledger:\n%s", text)
	}
}

// The exit criterion: a malformed reviewer output stops the loop, and is never a pass.
func TestAMalformedReviewerOutputStopsTheLoopAndIsNeverAPass(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n" +
		"  build-spec:\n    - result: { status: ok, output: \"LGTM, ship it\" }\n    - result: { status: ok, output: \"Looks fine to me.\" }\n" +
		"    - result: { status: ok, report: [] }\n"
	r := startReview(t, "unattended", script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateEscalation {
		t.Fatalf("Advance() = %+v, %v; want a stop at escalation", out, err)
	}
	rec := r.State.Loops["build"]
	if rec.State.Passed || rec.Escalation.Reason != jormungandr.ReasonUnreadable || r.State.Attempts["build-spec"] != 2 || r.State.Attempts["build"] != 1 {
		t.Errorf("record %+v; reviewer sessions %d, implementer sessions %d; want a retry of the reviewer once and no second implementer attempt",
			rec, r.State.Attempts["build-spec"], r.State.Attempts["build"])
	}
	if !strings.Contains(rec.Escalation.Detail, "reviewer spec") {
		t.Errorf("detail = %q", rec.Escalation.Detail)
	}
	if r.State.Status == run.StatusDone || strings.Contains(r.State.Summaries["build"], "passed") {
		t.Error("an answer nobody could read was taken for a pass")
	}
	// Nobody can approve on the reviewer's behalf, and the refusal changes nothing.
	before := ledgerText(t, r)
	if err := Approve(context.Background(), r, "build", "just go"); err == nil || !strings.Contains(err.Error(), "can't be read") {
		t.Errorf("Approve() = %v, want a refusal", err)
	}
	if Approvable(r) || !Rejectable(r) || ledgerText(t, r) != before {
		t.Error("the refusal changed the run, or approve was offered")
	}
	gate, _ := os.ReadFile(filepath.Join(r.Dir, "gates", "build-1.md"))
	if !strings.Contains(string(gate), "Approving is not offered") || strings.Contains(string(gate), "ygg approve") {
		t.Errorf("the gate file offers an approval:\n%s", gate)
	}
	// Sending it back asks the reviewer again, and the loop goes on from there.
	if err := Reject(context.Background(), r, "build", "I fixed the reviewer's prompt."); err != nil {
		t.Fatal(err)
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone || r.State.Attempts["build"] != 1 {
		t.Errorf("Advance() = %+v, %v after the rejection; the implementer must not run again (%d sessions)", out, err, r.State.Attempts["build"])
	}
}

func TestAReviewerReportThatDropsAFindingOrClosesItWithoutProofStopsTheLoopToo(t *testing.T) {
	for name, second := range map[string]string{
		"dropped":         "[]",
		"closed no proof": `[ { id: spec-1, source: spec, severity: major, location: "build.txt:1", claim: c, status: fixed, proof: "it is fine now" } ]`,
		"closed no check": `[ ` + fixedFinding("build.txt:1 is right") + ` ]`,
	} {
		script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n    - actions: [ " + write("build.txt", "done again") + " ]\n      result: { status: ok }\n" +
			"  build-spec:\n    - result: { status: ok, report: [ " + majorFinding + " ] }\n" +
			"    - result: { status: ok, report: " + second + " }\n    - result: { status: ok, report: " + second + " }\n"
		r := startReview(t, "key-points", script)
		out, err := Advance(context.Background(), r)
		if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateEscalation || r.State.Loops["build"].Escalation.Reason != jormungandr.ReasonUnreadable {
			t.Errorf("%s: Advance() = %+v, %v; want a stop: the finding can't vanish or close on the reviewer's word alone", name, out, err)
		}
		if f := r.State.Loops["build"].State.Book.Records["spec-1"]; f == nil || f.Status != gungnir.FindingOpen {
			t.Errorf("%s: record = %+v; the finding must stay open", name, f)
		}
	}
}

func TestASendBackAfterAPassedLoopStartsTheLoopOver(t *testing.T) {
	nodes := loopNode + "  - { id: feature-gate, kind: gate, gate: feature }\n"
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n" +
		"    - actions: [ " + write("build.txt", "done, with the footer") + " ]\n      result: { status: ok }\n"
	r := startWith(t, setup{mode: "step-by-step", pack: unitCheck, nodes: nodes, script: script})
	if out, _ := Advance(context.Background(), r); out.Status != run.StatusStopped || out.Gate != "feature-gate" {
		t.Fatalf("Advance() = %+v", out)
	}
	if err := Reject(context.Background(), r, "feature-gate", "Add a footer."); err != nil {
		t.Fatal(err)
	}
	if _, kept := r.State.Loops["build"]; kept || r.State.Position != 0 {
		t.Errorf("the loop record survived a rejection: %+v at position %d", r.State.Loops, r.State.Position)
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusStopped || out.Gate != "feature-gate" {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if got := transcript(t, r, "build-2"); !strings.Contains(got, "Add a footer.") || !strings.Contains(got, "## Guidance from the operator") {
		t.Errorf("the loop's new first attempt was told:\n%s", got)
	}
	if r.State.Loops["build"].State.Attempt != 1 {
		t.Errorf("the new loop is at attempt %d, want 1", r.State.Loops["build"].State.Attempt)
	}
}

func TestAnEscalatedLoopSurvivesAReopenedRun(t *testing.T) {
	r := startLoop(t, "key-points", neverPasses())
	Advance(context.Background(), r)
	r = reopen(t, r)
	if r.State.PendingGate != gungnir.GateEscalation || r.State.Loops["build"].Escalation == nil || !Rejectable(r) || !Approvable(r) {
		t.Fatalf("after reopening: gate %s, loop %+v", r.State.PendingGate, r.State.Loops["build"])
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusStopped {
		t.Errorf("Advance() = %+v, %v; a resume of a stopped run reports its stop", out, err)
	}
	if err := Approve(context.Background(), r, "build", ""); err != nil {
		t.Fatal(err)
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Errorf("Advance() = %+v, %v", out, err)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/escalation_test.go:57:25: undefined: Approvable
internal/engine/escalation_test.go:140:5: undefined: Approvable
internal/engine/escalation_test.go:205:117: undefined: Approvable
```

- [ ] **Step 3:** write the code.

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index be67003..08d1d5e 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -241,14 +241,20 @@ func (c *command) advance(r *run.Run) int {
 		fmt.Fprintf(c.out, "Run %s is done.\n", id)
 		return ExitDone
 	case run.StatusStopped:
-		if engine.Rejectable(r) {
+		approve, reject := engine.Approvable(r), engine.Rejectable(r)
+		gates := filepath.Join(r.Dir, "gates")
+		switch {
+		case reject && approve:
 			fmt.Fprintf(c.out, "Run %s stopped at approval point %s. Read %s, then run one of:\n"+
 				"  ygg approve %s %s [--note \"...\"]\n  ygg reject %s %s --reason \"...\"\n",
-				id, out.Gate, filepath.Join(r.Dir, "gates"), id, out.Gate, id, out.Gate)
-		} else {
+				id, out.Gate, gates, id, out.Gate, id, out.Gate)
+		case reject:
+			fmt.Fprintf(c.out, "Run %s stopped at approval point %s, which takes no approval. Read %s, then run:\n"+
+				"  ygg reject %s %s --reason \"...\"\n", id, out.Gate, gates, id, out.Gate)
+		default:
 			fmt.Fprintf(c.out, "Run %s stopped at the hard approval point %s. Read %s, then run:\n"+
 				"  ygg approve %s %s [--note \"...\"]\nA hard stop takes no rejection: to drop the work, start a new run.\n",
-				id, r.State.PendingGate, filepath.Join(r.Dir, "gates"), id, out.Gate)
+				id, r.State.PendingGate, gates, id, out.Gate)
 		}
 		return ExitStopped
 	case run.StatusPaused:
@@ -290,6 +296,17 @@ func (c *command) status(args []string) int {
 	for _, p := range slices.Sorted(maps.Keys(s.Leaves)) {
 		fmt.Fprintf(c.out, "leaf:     %s on %s at %.12s\n", p, s.Leaves[p].Branch, s.Leaves[p].Checkpoint)
 	}
+	for _, id := range slices.Sorted(maps.Keys(s.Loops)) {
+		l := s.Loops[id]
+		line := fmt.Sprintf("attempt %d of %d, %s, %d finding(s) open", min(l.State.Attempt, l.State.Limit), l.State.Limit, l.State.Phase, len(l.State.Book.Open()))
+		if l.State.Passed {
+			line = fmt.Sprintf("passed in attempt %d, %d finding(s) open", l.State.Attempt, len(l.State.Book.Open()))
+		}
+		if l.Escalation != nil {
+			line = fmt.Sprintf("gave up after %d attempt(s) (%s), %d finding(s) open", l.State.Limit, l.Escalation.Reason, len(l.State.Book.Open()))
+		}
+		fmt.Fprintf(c.out, "loop:     %s: %s\n", id, line)
+	}
 	if s.Paused != nil {
 		fmt.Fprintf(c.out, "paused:   at %s since %s: %s\n", s.Paused.Node, s.Paused.Since.Format(time.RFC3339), s.Paused.Reason)
 	}
```

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 3d29f69..f3f9702 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -86,6 +86,10 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 		if errors.As(err, &p) {
 			return pauseRun(r, n, p)
 		}
+		var esc *escalation
+		if errors.As(err, &esc) {
+			return stopEscalation(r, n, esc)
+		}
 		if err != nil {
 			return Outcome{}, err
 		}
```

Write `internal/engine/escalation.go`:

```go
package engine

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/jormungandr"
	"github.com/ouroboric-dev/odin/internal/run"
)

// escalation is a loop that gave up: it ran out of attempts, or a reviewer's answer could not be used
// twice in a row (spec §4.6, §7.3). The run stops for a person.
type escalation struct{ out jormungandr.Outcome }

func (e *escalation) Error() string {
	return "the loop gave up (" + e.out.Reason + "): " + e.out.Detail
}

// stopEscalation stops the run at the approval point escalation, as a gate node stops: a gate file with
// the findings that are still open and what the operator can do, gate_pending, and the run saved as
// stopped. The leaf stays at the last attempt's commit, so nothing is lost.
func stopEscalation(r *run.Run, n schema.Node, e *escalation) (Outcome, error) {
	s := r.State
	rel := filepath.Join("gates", fmt.Sprintf("%s-%d.md", n.ID, e.out.Attempts))
	var b strings.Builder
	fmt.Fprintf(&b, "# Escalation at loop %s (%s)\n\n", n.ID, gungnir.GateEscalation)
	fmt.Fprintf(&b, "- Run: %s\n- Mode: %s\n- Time: %s\n- Reason: %s\n\n", s.ID, s.Mode, time.Now().UTC().Format(time.RFC3339), e.out.Reason)
	fmt.Fprintf(&b, "## What happened\n\n%s\n\n## Findings still open\n\n", e.out.Detail)
	if len(e.out.Open) == 0 {
		b.WriteString("None.\n")
	}
	for _, f := range e.out.Open {
		fmt.Fprintf(&b, "- %s (%s, from %s) at %s\n", f.ID, f.Severity, f.Source, f.Location)
		for _, line := range strings.Split(strings.TrimSpace(f.Claim), "\n") {
			fmt.Fprintf(&b, "  %s\n", line)
		}
	}
	u := s.Usage
	fmt.Fprintf(&b, "\n## Cost so far\n\n- Tokens: %d in, %d out, %d from cache\n- Turns: %d\n- Cost: $%.4f\n", u.InTok, u.OutTok, u.CacheTok, u.Turns, u.CostUSD)
	b.WriteString("\n## Decide\n\n")
	fmt.Fprintf(&b, "    ygg reject %s %s --reason \"...\"\n\nThe reason goes to the implementer, and the loop gets %d more attempts, with the findings above.\n", s.ID, n.ID, n.Attempts)
	if e.out.Reason == jormungandr.ReasonExhausted {
		fmt.Fprintf(&b, "\n    ygg approve %s %s [--note \"...\"]\n\nThe work goes on as it is. The findings stay open in the ledger: only a check or a reviewer can close one.\n", s.ID, n.ID)
	} else {
		b.WriteString("\nApproving is not offered: a reviewer whose answer can't be read has not approved anything. Fix the reviewer, its role or its prompt, and then reject, to ask it again.\n")
	}
	if err := os.MkdirAll(filepath.Join(r.Dir, "gates"), 0o755); err != nil {
		return Outcome{}, err
	}
	if err := os.WriteFile(filepath.Join(r.Dir, rel), []byte(b.String()), 0o644); err != nil {
		return Outcome{}, err
	}
	ev := gungnir.Event{Name: gungnir.EventGatePending, Node: n.ID, Attempt: e.out.Attempts, Gate: n.ID, GateFile: rel,
		Note: fmt.Sprintf("%s: %s", gungnir.GateEscalation, e.out.Reason)}
	if err := r.Log(ev); err != nil {
		return Outcome{}, err
	}
	s.Status, s.Pending, s.PendingGate = run.StatusStopped, n.ID, gungnir.GateEscalation
	return Outcome{Status: run.StatusStopped, Gate: n.ID}, r.Save()
}
```

Apply to `internal/engine/gates.go`:

```diff
diff --git a/internal/engine/gates.go b/internal/engine/gates.go
index 24d0c3e..08a3620 100644
--- a/internal/engine/gates.go
+++ b/internal/engine/gates.go
@@ -11,6 +11,7 @@ import (
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
+	"github.com/ouroboric-dev/jormungandr"
 	"github.com/ouroboric-dev/odin/internal/gate"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
@@ -103,12 +104,26 @@ func Approve(ctx context.Context, r *run.Run, gateID, note string) error {
 	}
 	s := r.State
 	n := r.Setup.Graph.Nodes[s.Position]
+	if n.Kind == schema.KindLoop && s.PendingGate == gungnir.GateEscalation {
+		if rec := s.Loops[n.ID]; rec == nil || rec.Escalation == nil || rec.Escalation.Reason != jormungandr.ReasonExhausted {
+			return fmt.Errorf("loop %s stopped because a reviewer's answer can't be read, and an answer nobody can read is not an approval; "+
+				"fix the reviewer or its prompt, and then reject the stop to ask it again", n.ID)
+		}
+	}
 	if err := r.Log(gungnir.Event{Name: gungnir.EventGateApproved, Node: gateID, Gate: gateID, Note: note}); err != nil {
 		return err
 	}
 	switch {
 	case n.Kind == schema.KindGate:
 		s.Position++
+	case n.Kind == schema.KindLoop && s.PendingGate == gungnir.GateEscalation:
+		// The operator accepts the work with its findings open. They stay open in the ledger: only their
+		// source can close a finding.
+		rec := s.Loops[n.ID]
+		rec.State.Passed, rec.Escalation = true, nil
+		s.Summaries[n.ID] = fmt.Sprintf("accepted by the operator after %d attempt(s), with %d finding(s) open", rec.State.Attempt-1, len(rec.State.Book.Open()))
+		delete(s.Reasons, n.ID)
+		s.Position++
 	case run.Quarantines(s.PendingGate):
 		rec := s.Leaves[n.Repo]
 		l, err := r.Leaf(n.Repo)
@@ -125,16 +140,37 @@ func Approve(ctx context.Context, r *run.Run, gateID, note string) error {
 	return r.Save()
 }
 
-// Rejectable reports whether the run's pending stop takes a rejection: a gate node does. A hard stop
-// that a node raised takes approve only, or a new run (spec §7.2).
+// Rejectable reports whether the run's pending stop takes a rejection: a gate node does, and so does a
+// loop that gave up. A hard stop that a node raised takes approve only, or a new run (spec §7.2).
 func Rejectable(r *run.Run) bool {
 	s := r.State
-	return s.Pending != "" && s.Position < len(r.Setup.Graph.Nodes) && r.Setup.Graph.Nodes[s.Position].Kind == schema.KindGate
+	if s.Pending == "" || s.Position >= len(r.Setup.Graph.Nodes) {
+		return false
+	}
+	n := r.Setup.Graph.Nodes[s.Position]
+	return n.Kind == schema.KindGate || (n.Kind == schema.KindLoop && s.PendingGate == gungnir.GateEscalation)
 }
 
-// Reject sends reason back into the node the gate re-runs (spec §7.2). Advance re-runs it with
-// the reason in its prompt, then reaches the gate again. A hard stop a node raised takes no
-// rejection: approve it, or start a new run to drop the work.
+// Approvable reports whether the pending stop takes an approval. A loop that gave up because a
+// reviewer's answer can't be read does not: that is not a decision a person can take for the reviewer.
+func Approvable(r *run.Run) bool {
+	s := r.State
+	if s.Pending == "" || s.Position >= len(r.Setup.Graph.Nodes) {
+		return false
+	}
+	n := r.Setup.Graph.Nodes[s.Position]
+	if n.Kind == schema.KindLoop && s.PendingGate == gungnir.GateEscalation {
+		rec := s.Loops[n.ID]
+		return rec != nil && rec.Escalation != nil && rec.Escalation.Reason == jormungandr.ReasonExhausted
+	}
+	return true
+}
+
+// Reject sends reason back (spec §7.2). At a gate it goes into the node the gate re-runs: Advance
+// re-runs it with the reason in its prompt, then reaches the gate again; when that node is a loop,
+// the loop starts over. At a loop that gave up (spec §7.3) the reason goes to the loop's implementer,
+// and the loop gets a full set of attempts again, with its findings. A hard stop a node raised takes
+// no rejection: approve it, or start a new run to drop the work.
 func Reject(ctx context.Context, r *run.Run, gateID, reason string) error {
 	if err := pending(r, gateID); err != nil {
 		return err
@@ -147,13 +183,23 @@ func Reject(ctx context.Context, r *run.Run, gateID, reason string) error {
 	if strings.TrimSpace(reason) == "" {
 		return errors.New("a rejection needs a reason; it goes back to the node as input")
 	}
-	target := g.Nodes[g.Index(gateID)].Reruns
 	if err := r.Log(gungnir.Event{Name: gungnir.EventGateRejected, Node: gateID, Gate: gateID, Note: reason}); err != nil {
 		return err
 	}
-	s.Reasons[target] = reason
+	if n := g.Nodes[s.Position]; n.Kind == schema.KindLoop {
+		rec := s.Loops[n.ID]
+		rec.State.Extend(loopConfig(n))
+		rec.Escalation = nil
+		s.Reasons[n.ID] = reason
+	} else {
+		target := n.Reruns
+		s.Reasons[target] = reason
+		s.Position = g.Index(target)
+		if g.Nodes[s.Position].Kind == schema.KindLoop {
+			delete(s.Loops, target) // the work goes back to the start of a new loop
+		}
+	}
 	s.Pending, s.PendingGate, s.Status = "", "", run.StatusRunning
-	s.Position = g.Index(target)
 	return r.Save()
 }
 
```

Apply to `internal/engine/loop.go`:

```diff
diff --git a/internal/engine/loop.go b/internal/engine/loop.go
index e240f9d..e1a7864 100644
--- a/internal/engine/loop.go
+++ b/internal/engine/loop.go
@@ -48,8 +48,19 @@ func runLoop(ctx context.Context, r *run.Run, n schema.Node) error {
 	case jormungandr.Paused:
 		return &pause{out.Quota}
 	}
-	// Escalated: the next task stops the run for a person; until then the node fails with the reason.
-	return &nodeFailure{fmt.Errorf("the loop %s gave up (%s): %s", n.ID, out.Reason, out.Detail)}
+	// Escalated: a person decides (spec §7.3). In unattended mode the task would be marked blocked and
+	// the rest would go on; a linear graph has no rest, so the run stops here in every mode, and the
+	// ledger says "blocked" for unattended runs (Phase 4, decision 7).
+	rec.Escalation = &run.Escalation{Reason: out.Reason, Detail: out.Detail}
+	result := "stopped"
+	if s.Mode == gungnir.ModeUnattended {
+		result = "blocked"
+	}
+	if err := r.Log(gungnir.Event{Name: gungnir.EventEscalation, Node: n.ID, Attempt: out.Attempts, Result: result,
+		Mode: s.Mode, Note: out.Reason + ": " + out.Detail}); err != nil {
+		return err
+	}
+	return &escalation{out: out}
 }
 
 func loopConfig(n schema.Node) jormungandr.Config {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T137: a loop stops and resumes without losing an attempt or a finding

Decision 13 and Review focus 3. These tests pin behavior that v0-T130, v0-T133 to v0-T136 built: a loop
that stops for a cap, a quota, an interruption or a quarantine goes on from where it was. They pass the
first time they run; each was checked to fail with its defence removed (see "Evidence").

**Files (in `odin`):**

- Create: `internal/engine/loop_resume_test.go`

**Acceptance criteria:**

- [ ] A cap between two attempts stops the run at `budget-cap` with the next attempt not started and the
      finding open; raising the cap and approving runs that attempt, not a later one, and the finding is in
      its prompt.
- [ ] A cap before a reviewer stops with the loop in its ladder; the resume does not run the implementer
      again.
- [ ] A quota used up in a reviewer's session pauses the run; the resume runs the ladder again and the
      implementer not at all.
- [ ] A transient failure of a reviewer is retried and costs no attempt.
- [ ] A run interrupted in the middle of an attempt resumes that attempt, with its half work gone and the
      finding in the prompt, and the attempt is not counted twice.
- [ ] A check that plants a repository in the leaf stops the run at `policy-violation`; the loop is not
      retried; a resume keeps the quarantine and does not clean the leaf.

**Named test:** `go test ./internal/engine -run 'TestACapBetweenTwoAttempts|TestACapBeforeAReviewer|TestAQuotaUsedUpInTheMiddle|TestATransientFailureOfAReviewer|TestARunInterruptedInAnAttempt|TestACheckThatPlantsARepository'`
in `odin`. **Layer:** `odin`. **Size:** M (144). **Depends on:** v0-T136.

- [ ] **Step 1:** write the tests.

Write `internal/engine/loop_resume_test.go`:

```go
package engine

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/run"
)

func raiseCap(t *testing.T, r *run.Run, from, to string) *run.Run {
	t.Helper()
	cfg, err := os.ReadFile(r.Setup.ConfigPath)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(cfg), from) {
		t.Fatalf("factory.yaml lacks %q:\n%s", from, cfg)
	}
	if err := os.WriteFile(r.Setup.ConfigPath, []byte(strings.Replace(string(cfg), from, to, 1)), 0o644); err != nil {
		t.Fatal(err)
	}
	return reopen(t, r)
}

func TestACapBetweenTwoAttemptsStopsTheRunAndTheSameAttemptGoesOnWhenItIsRaised(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "todo") + " ]\n      result: { status: ok, usage: { in: 100, out: 10, turns: 2 } }\n" +
		"    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok, usage: { in: 100, out: 10, turns: 2 } }\n"
	r := startWith(t, setup{mode: "unattended", pack: unitCheck, nodes: loopNode, script: script, budget: caps(110, 100, 200000, 200)})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateBudgetCap {
		t.Fatalf("Advance() = %+v, %v, gate %s; want a stop at budget-cap in attempt 2", out, err, r.State.PendingGate)
	}
	st := r.State.Loops["build"].State
	if st.Attempt != 2 || st.Phase != "implement" || len(st.Book.Open()) != 1 || r.State.Attempts["build"] != 1 {
		t.Errorf("loop state %+v, %d sessions; want attempt 2 not yet started, with the check's finding open", st, r.State.Attempts["build"])
	}
	r = raiseCap(t, r, "tokens: 110", "tokens: 1000")
	if err := Approve(context.Background(), r, "build", "raised it"); err != nil {
		t.Fatal(err)
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if got := r.State.Loops["build"].State.Attempt; got != 2 || r.State.Attempts["build"] != 2 {
		t.Errorf("the loop ended in attempt %d with %d sessions; a stop for a cap must not use up an attempt", got, r.State.Attempts["build"])
	}
	if !strings.Contains(transcript(t, r, "build-2"), "- check-unit (blocker") {
		t.Error("the finding was lost across the stop")
	}
}

func TestACapBeforeAReviewerStopsAtTheLadderAndAResumeDoesNotRunTheImplementerAgain(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok, usage: { in: 100, out: 10, turns: 2 } }\n" +
		"  build-spec:\n    - result: { status: ok, report: [] }\n"
	r := startWith(t, setup{pack: unitCheck, nodes: reviewLoop, script: script, budget: caps(110, 100, 200000, 200)})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateBudgetCap || r.State.Attempts["build-spec"] != 0 {
		t.Fatalf("Advance() = %+v, %v, gate %s, reviewer sessions %d; want a stop before the reviewer", out, err, r.State.PendingGate, r.State.Attempts["build-spec"])
	}
	if got := r.State.Loops["build"].State.Phase; got != "ladder" {
		t.Errorf("the loop is in phase %s, want ladder", got)
	}
	r = raiseCap(t, r, "tokens: 110", "tokens: 1000")
	Approve(context.Background(), r, "build", "")
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone || r.State.Attempts["build"] != 1 || r.State.Attempts["build-spec"] != 1 {
		t.Errorf("Advance() = %+v, %v; implementer sessions %d, reviewer sessions %d; want done with 1 and 1", out, err, r.State.Attempts["build"], r.State.Attempts["build-spec"])
	}
}

func TestAQuotaUsedUpInTheMiddleOfTheLadderPausesTheRunAndTheLadderRunsAgain(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n" +
		"  build-spec:\n    - { error: \"usage limit reached\", kind: quota, usage: { in: 30, out: 3, turns: 1 } }\n    - result: { status: ok, report: [] }\n"
	r := startReview(t, "key-points", script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusPaused {
		t.Fatalf("Advance() = %+v, %v; want a paused run", out, err)
	}
	r = reopen(t, r)
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone || r.State.Attempts["build"] != 1 || r.State.Attempts["build-spec"] != 2 {
		t.Errorf("Advance() = %+v, %v; implementer sessions %d, reviewer sessions %d; want done with 1 and 2", out, err, r.State.Attempts["build"], r.State.Attempts["build-spec"])
	}
}

func TestATransientFailureOfAReviewerIsRetriedWithoutUsingAnAttempt(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n" +
		"  build-spec:\n    - { error: \"HTTP 529 overloaded\", kind: transient }\n    - result: { status: ok, report: [] }\n"
	w := &waits{}
	r := startWith(t, setup{pack: unitCheck, nodes: reviewLoop, script: script, hooks: hooks(w)})
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone || len(w.got) != 1 || r.State.Loops["build"].State.Attempt != 1 {
		t.Errorf("Advance() = %+v, %v; %d waits; want done in attempt 1 after one retry", out, err, len(w.got))
	}
}

func TestARunInterruptedInAnAttemptResumesThatAttemptWithTheFindings(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "todo") + " ]\n      result: { status: ok }\n" +
		"    - actions: [ " + write("half.txt", "half a thought") + " ]\n      hang: true\n" +
		"    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n"
	r := startLoop(t, "key-points", script)
	ctx, cancel := context.WithTimeout(context.Background(), 1500*time.Millisecond)
	defer cancel()
	out, err := Advance(ctx, r)
	if err != nil || out.Status != run.StatusFailed {
		t.Fatalf("Advance() = %+v, %v; want a failed run after the interrupt", out, err)
	}
	r = reopen(t, r)
	if _, err := os.Stat(filepath.Join(r.RepoDir("repos/app"), "half.txt")); err == nil {
		t.Error("the interrupted attempt's half work is still in the leaf after the resume")
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("the resume: %+v, %v", out, err)
	}
	if got := r.State.Loops["build"].State.Attempt; got != 2 {
		t.Errorf("the loop ended in attempt %d; the interrupted attempt 2 must be done again, not counted twice", got)
	}
	if !strings.Contains(transcript(t, r, "build-3"), "- check-unit (blocker") {
		t.Error("the resumed attempt wasn't given the finding")
	}
}

func TestACheckThatPlantsARepositoryInTheLeafStopsTheRunAtPolicyViolationAndTheLoopDoesNotGoOn(t *testing.T) {
	pack := "checks:\n  unit: [sh, -c, \"mkdir -p vendor/x/.git && grep -q done build.txt\"]\n"
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n"
	r := startWith(t, setup{mode: "unattended", pack: pack, nodes: loopNode, script: script})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GatePolicyViolation {
		t.Fatalf("Advance() = %+v, %v, gate %s; want a hard stop at policy-violation", out, err, r.State.PendingGate)
	}
	if r.State.Attempts["build"] != 1 {
		t.Errorf("the loop ran %d sessions; a policy violation is not an attempt to retry", r.State.Attempts["build"])
	}
	// A resume keeps the quarantine: the leaf stays as it was left, for investigation.
	r = reopen(t, r)
	if _, err := os.Stat(filepath.Join(r.RepoDir("repos/app"), "vendor/x/.git")); err != nil {
		t.Error("a resume cleaned a quarantined leaf")
	}
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusStopped || r.State.Attempts["build"] != 1 {
		t.Errorf("Advance() = %+v, %v; a quarantined run is never resumed on its own", out, err)
	}
}
```

- [ ] **Step 2:** run the named test. Expect `ok`.
- [ ] **Step 3:** commit (see "How each task lands").

---

### Task v0-T138: the exit criteria through the whole stack: an unreadable reviewer stops the loop, a cap stops the run resumable, a finding closes only with proof

The phase's exit criterion, through `ygg` itself, on the toy loop realm with scripted agents (spec §13).

**Files (in `odin`):**

- Create: `internal/cli/loop_e2e_test.go`
- Modify: `internal/cli/cli.go`

**Interfaces:**

- Changes: the `loop:` line of `ygg status` says `gave up in attempt <n> (<reason>)`, with the attempt the
  loop was in.

**Acceptance criteria:**

- [ ] **A malformed reviewer output stops the loop.** `ygg run --mode unattended` with a reviewer that
      answers "LGTM" twice exits 3 at the approval point `build`, which takes no approval; `status` says
      the loop gave up in attempt 1 (`reviewer-unreadable`); `approve` is refused (exit 2); `resume` stays
      stopped; `reject --reason …` goes on to the end of the run, and the implementer ran once.
- [ ] **A run that hits a cap stops resumable.** With a per-run cap of 2,000 tokens the run stops at the
      hard approval point `budget-cap` after the first attempt (exit 3; `status` shows the loop in attempt
      2, the finding open, and the use of the cap); `approve` with the cap still reached stops again;
      after the cap is raised in `factory.yaml`, `approve` finishes the run.
- [ ] **Findings close only with proof.** A run in which the implementer writes "I fixed spec-1; it is
      closed." twice raises one finding, closes it once, after three attempts, when the reviewer's
      report carries a proof, and the ledger closes nothing before the reviewer did.

**Named test:** `go test ./internal/cli -run 'TestAMalformedReviewerOutputStopsTheLoopForAPerson|TestARunThatHitsACapStopsResumable|TestAFindingClosesOnlyWhenItsSourceConfirms'`
in `odin`. **Layer:** `odin`. **Size:** M (157). **Depends on:** v0-T137.

- [ ] **Step 1:** write the tests.

Write `internal/cli/loop_e2e_test.go`:

```go
package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

// loopProject makes a project, a factory.yaml whose implementer and reviewer roles play script, and
// returns the toy loop realm with them. caps is the budget: section.
func loopProject(t *testing.T, script, caps string) (dir, config, realm string) {
	t.Helper()
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	realm, err := filepath.Abs("../../testdata/toy-loop")
	if err != nil {
		t.Fatal(err)
	}
	dir = treetest.Project(t)
	cfgDir := t.TempDir()
	scriptPath := filepath.Join(cfgDir, "script.yaml")
	if err := os.WriteFile(scriptPath, []byte(script), 0o644); err != nil {
		t.Fatal(err)
	}
	config = filepath.Join(cfgDir, "factory.yaml")
	if caps == "" {
		caps = "budget:\n  per_run: { tokens: 100000, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\n"
	}
	body := "roles:\n  implementer: { agent: scripted, model: none, script: " + scriptPath + " }\n  reviewer: { agent: scripted, model: none, script: " + scriptPath + " }\n" + caps
	if err := os.WriteFile(config, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return dir, config, realm
}

const implementOnce = `steps:
  build:
    - actions: [ { write: { path: build.txt, content: "done\n" } } ]
      result: { status: ok, summary: built it, usage: { in: 2000, out: 400, turns: 5 } }
`

// The exit criterion: a malformed reviewer output stops the loop. Nothing counts it as a pass, an
// approval is refused, and sending the work back asks the reviewer again.
func TestAMalformedReviewerOutputStopsTheLoopForAPerson(t *testing.T) {
	script := implementOnce + `  build-spec:
    - result: { status: ok, output: "LGTM, ship it.", usage: { in: 100, out: 10, turns: 1 } }
    - result: { status: ok, output: "Looks fine to me.", usage: { in: 100, out: 10, turns: 1 } }
    - result: { status: ok, report: [], usage: { in: 100, out: 10, turns: 1 } }
  build-quality:
    - result: { status: ok, report: [], usage: { in: 100, out: 10, turns: 1 } }
`
	dir, config, realm := loopProject(t, script, "")
	code, out, errOut := ygg(t, "run", "--project", dir, "--config", config, "--realm", realm, "--mode", "unattended")
	id := runID(t, dir)
	if code != ExitStopped || !strings.Contains(out, "stopped at approval point build, which takes no approval") || !strings.Contains(out, "ygg reject "+id+" build --reason") || strings.Contains(out, "ygg approve") {
		t.Fatalf("run: exit %d:\n%s%s\nwant a stop that offers a rejection only", code, out, errOut)
	}
	code, out, _ = ygg(t, "status", id, "--project", dir)
	if code != ExitDone || !strings.Contains(out, "waiting:  build (escalation)") || !strings.Contains(out, "gave up in attempt 1 (reviewer-unreadable)") {
		t.Errorf("status: exit %d:\n%s", code, out)
	}
	if code, _, errOut := ygg(t, "approve", id, "build", "--project", dir); code != ExitRefused || !strings.Contains(errOut, "can't be read") {
		t.Errorf("approve: exit %d, %q; an answer nobody can read is not an approval", code, errOut)
	}
	if code, out, _ := ygg(t, "resume", id, "--project", dir); code != ExitStopped {
		t.Errorf("resume: exit %d:\n%s; a stopped run stays stopped", code, out)
	}
	code, out, errOut = ygg(t, "reject", id, "build", "--reason", "The reviewer's prompt was fixed.", "--project", dir)
	if code != ExitDone || !strings.Contains(out, "is done") {
		t.Errorf("reject: exit %d:\n%s%s; want the loop to go on to the end", code, out, errOut)
	}
	s, _ := run.LoadState(run.Dir(dir, id))
	if s.Attempts["build"] != 1 || s.Attempts["build-spec"] != 3 {
		t.Errorf("sessions: implementer %d, spec reviewer %d; the implementer must not run again for an unreadable reviewer", s.Attempts["build"], s.Attempts["build-spec"])
	}
}

// The exit criterion: a run that hits a cap stops, with everything resumable.
func TestARunThatHitsACapStopsResumableAndGoesOnWhenTheCapIsRaised(t *testing.T) {
	script := `steps:
  build:
    - actions: [ { write: { path: build.txt, content: "todo\n" } } ]
      result: { status: ok, usage: { in: 2000, out: 400, turns: 5 } }
    - actions: [ { write: { path: build.txt, content: "done\n" } } ]
      result: { status: ok, usage: { in: 2000, out: 400, turns: 5 } }
  build-spec:    [ { result: { status: ok, report: [] } } ]
  build-quality: [ { result: { status: ok, report: [] } } ]
`
	caps := "budget:\n  per_run: { tokens: 2000, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\n"
	dir, config, realm := loopProject(t, script, caps)
	code, out, errOut := ygg(t, "run", "--project", dir, "--config", config, "--realm", realm)
	id := runID(t, dir)
	if code != ExitStopped || !strings.Contains(out, "stopped at the hard approval point budget-cap") || strings.Contains(out, "ygg reject") {
		t.Fatalf("run: exit %d:\n%s%s", code, out, errOut)
	}
	code, out, _ = ygg(t, "status", id, "--project", dir)
	if code != ExitDone || !strings.Contains(out, "waiting:  build (budget-cap)") || !strings.Contains(out, "loop:     build: attempt 2 of 3, implement, 1 finding(s) open") ||
		!strings.Contains(out, "caps:     this run 2400 of 2000 tokens") {
		t.Errorf("status: exit %d:\n%s", code, out)
	}
	// Approving while the cap is reached stops again at once; raising the cap lets the run go on.
	if code, out, _ := ygg(t, "approve", id, "build", "--project", dir); code != ExitStopped || !strings.Contains(out, "budget-cap") {
		t.Errorf("approve with the cap still reached: exit %d:\n%s", code, out)
	}
	b, _ := os.ReadFile(config)
	os.WriteFile(config, []byte(strings.Replace(string(b), "tokens: 2000", "tokens: 30000", 1)), 0o644)
	code, out, errOut = ygg(t, "approve", id, "build", "--project", dir)
	if code != ExitDone {
		t.Errorf("approve after the cap was raised: exit %d:\n%s%s", code, out, errOut)
	}
	ledger, _ := os.ReadFile(filepath.Join(dir, ".factory", "runs", id, "ledger.jsonl"))
	if !strings.Contains(string(ledger), `"event":"config_changed"`) || !strings.Contains(string(ledger), `"event":"run_finished"`) {
		t.Errorf("the ledger:\n%s", ledger)
	}
}

// The exit criterion: a finding closes only with proof from its source. The implementer saying it fixed
// the problem changes nothing; the reviewer closes it, with a file and line and a check that passed.
func TestAFindingClosesOnlyWhenItsSourceConfirmsItWithProof(t *testing.T) {
	major := `{ id: spec-1, source: spec, severity: major, location: "build.txt:1", claim: "build.txt doesn't say done twice", status: open }`
	script := `steps:
  build:
    - actions: [ { write: { path: build.txt, content: "done\n" } } ]
      result: { status: ok, summary: built it }
    - actions: [ { write: { path: build.txt, content: "done done\n" } } ]
      result: { status: ok, summary: "I fixed spec-1; it is closed." }
    - actions: [ { write: { path: build.txt, content: "done done\n" } } ]
      result: { status: ok, summary: "spec-1 is fixed, really." }
  build-spec:
    - result: { status: ok, report: [ ` + major + ` ] }
    - result: { status: ok, report: [ ` + major + ` ] }
    - result: { status: ok, report: [ { id: spec-1, source: spec, severity: major, location: "build.txt:1", claim: "now fixed", status: fixed, proof: "build.txt:1 says done twice; check unit passed" } ] }
  build-quality: [ { result: { status: ok, report: [] } } ]
`
	dir, config, realm := loopProject(t, script, "")
	code, out, errOut := ygg(t, "run", "--project", dir, "--config", config, "--realm", realm)
	if code != ExitDone {
		t.Fatalf("run: exit %d:\n%s%s", code, out, errOut)
	}
	id := runID(t, dir)
	ledger, _ := os.ReadFile(filepath.Join(dir, ".factory", "runs", id, "ledger.jsonl"))
	text := string(ledger)
	if strings.Count(text, `"event":"finding_raised"`) != 1 || strings.Count(text, `"event":"finding_closed"`) != 1 || !strings.Contains(text, `"ygg.finding.attempts":3`) {
		t.Errorf("want one finding, raised once and closed once after 3 attempts:\n%s", text)
	}
	if strings.Index(text, "I fixed spec-1") > 0 && strings.Index(text, `"event":"finding_closed"`) < strings.Index(text, "I fixed spec-1") {
		t.Error("the finding closed before the reviewer confirmed it")
	}
	s, _ := run.LoadState(run.Dir(dir, id))
	if f := s.Loops["build"].State.Book.Records["spec-1"]; f == nil || f.Status != "fixed" || f.Closed != 3 || !strings.Contains(f.Proof, "check unit passed") {
		t.Errorf("record = %+v", f)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAMalformedReviewerOutputStopsTheLoopForAPerson (0.56s)
    loop_e2e_test.go:63: status: exit 0:
        run:      20261016-213532-098a97
        status:   stopped
```

- [ ] **Step 3:** write the code.

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 08d1d5e..83ee360 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -303,7 +303,7 @@ func (c *command) status(args []string) int {
 			line = fmt.Sprintf("passed in attempt %d, %d finding(s) open", l.State.Attempt, len(l.State.Book.Open()))
 		}
 		if l.Escalation != nil {
-			line = fmt.Sprintf("gave up after %d attempt(s) (%s), %d finding(s) open", l.State.Limit, l.Escalation.Reason, len(l.State.Book.Open()))
+			line = fmt.Sprintf("gave up in attempt %d (%s), %d finding(s) open", min(l.State.Attempt, l.State.Limit), l.Escalation.Reason, len(l.State.Book.Open()))
 		}
 		fmt.Fprintf(c.out, "loop:     %s: %s\n", id, line)
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T139: the loop smoke realm: a real implementer and a real reviewer in a bounded loop

Spec §13: the smoke run runs before benchmark runs and after any model or CLI version bump. This is its
loop. It costs a few cents and is the founder's to run (v0-H11); the test only checks it prepares.

**Files (in `odin`):**

- Create: `testdata/smoke-loop/factory.example.yaml`, `testdata/smoke-loop/graph.yaml`, `testdata/smoke-loop/pack.yaml`, `testdata/smoke-loop/prompts/hello.md`, `testdata/smoke-loop/prompts/review.md`, `testdata/smoke-loop/templates/app/LICENSE`
- Modify: `internal/run/loop_test.go`

**Acceptance criteria:**

- [ ] The realm prepares with `factory.example.yaml` (a `claude-code` implementer, an `opencode` reviewer),
      with one loop node of two attempts and one reviewer, and its sandbox opens
      `api.anthropic.com` and `openrouter.ai` and nothing else. (The test skips as root: `ygg` refuses to
      prepare a sandbox as root.)

**Named test:** `go test ./internal/run -run TestTheLoopSmokeRealmPreparesWithBothRealAdapters` in
`odin`. **Layer:** `odin`. **Size:** S (81). **Depends on:** v0-T138.

- [ ] **Step 1:** write the test.

```diff
diff --git a/internal/run/loop_test.go b/internal/run/loop_test.go
index 6657c2c..cf86c09 100644
--- a/internal/run/loop_test.go
+++ b/internal/run/loop_test.go
@@ -151,3 +151,30 @@ func TestALoopsStateSurvivesInRunJSON(t *testing.T) {
 		t.Error("the maps a state loads with are nil; the engine writes to them")
 	}
 }
+
+func TestTheLoopSmokeRealmPreparesWithBothRealAdapters(t *testing.T) {
+	if os.Getuid() == 0 {
+		t.Skip("ygg refuses to prepare a sandbox as root: the sandbox's user is the operator's own")
+	}
+	smoke, err := filepath.Abs("../../testdata/smoke-loop")
+	if err != nil {
+		t.Fatal(err)
+	}
+	b, err := os.ReadFile(filepath.Join(smoke, "factory.example.yaml"))
+	if err != nil {
+		t.Fatal(err)
+	}
+	cfg := filepath.Join(t.TempDir(), "factory.yaml")
+	if err := os.WriteFile(cfg, b, 0o644); err != nil {
+		t.Fatal(err)
+	}
+	s, err := Prepare(ctx, Options{Project: treetest.Project(t), Config: cfg, Realm: smoke})
+	if err != nil {
+		t.Fatal(err)
+	}
+	n := s.Graph.Nodes[0]
+	if n.Kind != "loop" || s.Agents["implementer"].Name() != "claude-code" || s.Agents["reviewer"].Name() != "opencode" ||
+		strings.Join(s.Sandbox.Egress, ",") != "api.anthropic.com,openrouter.ai" || len(n.Reviewers) != 1 || n.Attempts != 2 {
+		t.Errorf("node %+v, agents %v, egress %v", n, s.Agents, s.Sandbox.Egress)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, like this:

```output
--- FAIL: TestTheLoopSmokeRealmPreparesWithBothRealAdapters (0.00s)
    loop_test.go:165: open …/odin/testdata/smoke-loop/factory.example.yaml: no such file or directory
```

- [ ] **Step 3:** write the realm.

Write `testdata/smoke-loop/graph.yaml`:

```yaml
# The smoke graph for the loop (spec §13): a real implementer and a real read-only reviewer in a bounded
# loop, with one check, in a sandbox; then the gates and the merge. The implementer writes hello.txt, the
# check looks for the word, and the reviewer reports its findings as JSON. It costs a few cents. Run it
# with a factory.yaml whose implementer is claude-code and whose reviewer is opencode.
name: smoke-loop
version: 0.1.0
nodes:
  - id: hello
    kind: loop
    repo: repos/app
    role: implementer
    prompt: prompts/hello.md
    attempts: 2
    max_turns: 8
    timeout: 5m
    checks: [unit]
    reviewers:
      - { id: review, role: reviewer, prompt: prompts/review.md, max_turns: 6, timeout: 5m }
  - { id: feature-gate, kind: gate, gate: feature }
  - { id: merge-gate, kind: gate, gate: merge }
  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }
```

Write `testdata/smoke-loop/pack.yaml`:

```yaml
name: smoke-loop
version: 0.1.0
graph: graph.yaml
checks:
  unit: [grep, -q, hello, hello.txt]
leaves:
  repos/app: { description: the smoke test's app, template: templates/app, first_commit: [LICENSE] }
sandbox:
  stack: docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514
  egress: []
```

Write `testdata/smoke-loop/factory.example.yaml`:

```yaml
# An example factory.yaml for the loop smoke run. Copy it, set the engine and the mounts for your machine,
# and the caps you want; the factory ships no defaults. The credentials come from the environment:
# CLAUDE_CODE_OAUTH_TOKEN and OPENROUTER_API_KEY, never from this file.
mode: unattended
privacy: strict
roles:
  implementer: { agent: claude-code, model: sonnet }
  reviewer: { agent: opencode, model: openrouter/deepseek/deepseek-v4-flash }
budget:
  per_run: { tokens: 400000, turns: 40, usd: 2 }
  per_day: { tokens: 1000000, turns: 100, usd: 5 }
sandbox:
  engine: unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock
  mounts:
    - { host: /home/OPERATOR/ygg, engine: /mnt/wsl/ygg-bind }
```

Write `testdata/smoke-loop/prompts/hello.md`:

```md
Create a file named hello.txt in the current directory. Its only content is one line: hello from the factory.

Do nothing else: no other files, no commands that change anything else. Then reply with the word done.
```

Write `testdata/smoke-loop/prompts/review.md`:

```md
Review the work in this repository. It should hold a file hello.txt that contains the word hello.

Read hello.txt. Report a finding only if the file is missing, or does not contain the word hello, or holds
anything else that a person asking for a greeting would not expect. If it is fine, report no findings.
```

Write `testdata/smoke-loop/templates/app/LICENSE`:

```text
The toy app is a test fixture of Odin, AGPL-3.0-only.
```

- [ ] **Step 4:** run the named test. Expect `ok`.
- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T140: Odin's documentation

The architecture page says what Odin does now. A reference page, no test.

**Files (in `odin`):**

- Modify: `docs/architecture.md`

**Acceptance criteria:**

- [ ] `docs/architecture.md` says that a loop node is Jormungandr's loop with Odin's steps, that every
      session's usage is counted in the run and in a daily journal, that a cap stops the run before a
      session starts over it, and that a used-up quota pauses the run.

**Named test:** none: `reuse lint` passes. **Layer:** `odin`. **Size:** S (6).
**Depends on:** v0-T139.

- [ ] **Step 1:** apply the change.

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 1ae758a..0d99df1 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -13,7 +13,11 @@ The orchestrator: the graph engine and the `ygg` CLI, with routing and the ledge
 ## Responsibilities
 
 - Loads realm graphs and `factory.yaml`.
-- Walks the graph and runs exec, agent, loop and gate nodes; checkpoints runs and resumes them.
+- Walks the graph and runs exec, agent, loop and gate nodes; checkpoints runs and resumes them. A
+  loop node is Jormungandr's loop with Odin's steps: sessions, checks, ledger lines and `run.json`.
+- Counts every session's usage, a failed one's too, in the run and in a daily spend journal outside
+  any project, and stops the run at the hard approval point `budget-cap` before a session would start
+  over a cap (spec §7.4). Pauses the run when the provider's quota is used up (spec §12).
 - Walks the instance tree and moves pointers. It is the only writer of umbrellas, `features.json`,
   the ledger, gate files and reports (spec §3.3).
 - Does every git operation, from the host (spec §6.3).
@@ -22,7 +26,7 @@ The orchestrator: the graph engine and the `ygg` CLI, with routing and the ledge
 
 ## Depends on
 
-- Gungnir's interfaces.
+- Gungnir's interfaces, Gleipnir (adapters, the sandbox, the check runner) and Jormungandr (the loop).
 
 ## Source
 
```

- [ ] **Step 2:** run `uvx -q --from 'reuse==5.0.2' reuse lint -q`; it prints nothing.
- [ ] **Step 3:** commit (see "How each task lands").

When `odin`'s last task is committed, push and open its pull request (see "How each task lands"). It
needs `gungnir`, `gleipnir` and `jormungandr` merged and pinned. The PR body lists the three exit
criteria and the output of their named tests.

---

### Task v0-T141: pointers and the exit check

The umbrella moves the four pointers once, and the exit check runs on the merged code.

**Files (in `yggdrasil`):**

- Modify: the submodule pointers of `gungnir`, `gleipnir`, `jormungandr` and `odin`;
  `docs/2-engineering/backlog.md`.

**Acceptance criteria:**

- [ ] After all four pull requests are merged, the pointers are at each repo's `main`, and `go.work`
      builds them together: `go vet ./...` and `go test ./...` pass in each repo with `go.work` and with
      `GOWORK=off`.
- [ ] The exit criterion: the three named tests of v0-T138 pass on the merged code, and the founder's one
      real loop ran in a sandbox (v0-H11). The ledger lines are in the pull request.
- [ ] Backlog B-012, B-016, B-017, B-018, B-019, B-020, B-021 and B-028 move to Done, each with the pull
      request's link.

**Named test:** `go test ./...` in each repo, and the evidence of v0-H11. **Layer:** `yggdrasil`.
**Size:** S. **Depends on:** all above, merged.

- [ ] **Step 1:** switch each local copy to `main` and pull. Then, in `yggdrasil`:

```bash
git switch -c phase-4/pointers
git submodule update --remote gungnir gleipnir jormungandr odin
git status --short
```

- [ ] **Step 2:** in `docs/2-engineering/backlog.md`, move the eight items to **Done**, each with the
      pull request that fixed it (gleipnir's for B-016, B-017, B-019, B-020, B-021 and B-028; odin's for
      B-012 and B-018).
- [ ] **Step 3:** run the exit check: `go vet ./... && go test ./...` in each of the four repos, with
      `go.work` and with `GOWORK=off`, and paste the output and v0-H11's ledger lines into the PR body.
- [ ] **Step 4:** stage the four pointers and the backlog by path, commit, push and open the pull
      request (see "How each task lands").

---

### Task v0-H10 (founder): `test` required on `jormungandr`

`gungnir`, `gleipnir`, `odin` and `havamal` have CI. `jormungandr` gets it now. The pr-bot can't push
workflow files, so you do. Write this to `.github/workflows/ci.yml` on a branch `ci/workflow` of
`jormungandr`, after its pull request is merged:

```yaml
# CI: the required check "test" (spec §13). It runs in the devcontainer's image, without go.work, so it
# builds this module exactly as its go.mod says. The pr-bot can't change this file (it has no workflows
# permission); the founder pushes changes to it.
name: ci
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    container:
      image: docker.io/library/golang:1.26.9-bookworm@sha256:d9c68c2c51161e12fd77e4c6320687c9cd86e1af1e3ad6e6cd63ff970641453c
    env:
      GOWORK: "off"
      GOTOOLCHAIN: local
      GOFLAGS: -mod=readonly
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - name: gofmt
        run: test -z "$(gofmt -l .)" || { gofmt -l .; exit 1; }
      - name: vet
        run: go vet ./...
      - name: test
        run: go test -race ./...
      - name: govulncheck
        run: go run golang.org/x/vuln/cmd/govulncheck@v1.8.0 ./...
```

**Named test (agent-run):** `as-bot.sh --read all scripts/check-repos.sh --check ruleset jormungandr`
prints `PASS`. **Layer:** GitHub. **Size:** S. **Depends on:** v0-T124 merged.

- [ ] **Step 1:** push the branch and open the pull request with your own short-lived token, as in v0-H05
      step 2, for `jormungandr` only. Wait for `test` to pass, review, and merge with your admin bypass.
- [ ] **Step 2:** with the short-lived admin token, run `scripts/setup-repo.sh jormungandr`. Delete the token.
- [ ] **Step 3:** ask an agent to run the named test.

---

### Task v0-H11 (founder): one real loop

The exit criterion's real half: a real `claude-code` implementer and a real `opencode` reviewer run in a
bounded loop in a sandbox, report usage, and leave their spend in the day's journal. It uses your tokens
and costs a few cents, so you run it, or you tell an agent to. **Do this only after v0-T139 is merged,
with the engine up (Phase 3's v0-H07) and the images built (Phase 3's v0-H09).**

**Named test:** the run finishes, and its ledger has `node_finished` lines for `hello` and
`hello-review` with non-zero `gen_ai.usage.input_tokens`, a `loop_attempt` line with `passed`, and no
`finding_raised` line; and `ygg status` shows the caps with the run's spend in them. **Layer:** the
founder's machine. **Size:** S. **Depends on:** v0-T139 merged; Phase 3's v0-H07 and v0-H09.

- [ ] **Step 1:** copy `odin/testdata/smoke-loop/factory.example.yaml` over `~/ygg-it/factory.yaml`, or
      merge it into yours (keep `mounts.host` as `/home/brunogbv/ygg-it`), and set the caps you want.
      Make a project, as in v0-H09 step 1, in `~/ygg-it/smoke-loop`.
- [ ] **Step 2:** put the credentials in the shell that runs `ygg`, from your own file, without printing
      them: `set -a; . ~/.config/ouroboric/factory.env; set +a`.
- [ ] **Step 3:** build the images (once), then run:

```bash
cd ~/brunogbv/ouroboric/yggdrasil/odin
go run ./cmd/ygg sandbox build --config ~/ygg-it/factory.yaml --realm testdata/smoke-loop
go run ./cmd/ygg run --project ~/ygg-it/smoke-loop --config ~/ygg-it/factory.yaml --realm testdata/smoke-loop
```

- [ ] **Step 4:** send back, without any secret in it: the command's output; `ygg status <run id>` (it
      now shows the caps); `ygg doctor --project ~/ygg-it/smoke-loop --config ~/ygg-it/factory.yaml`; and the
      lines of `.factory/runs/<id>/ledger.jsonl` whose `event` is `node_finished`, `loop_attempt`,
      `finding_raised`, `finding_closed`, `sandbox_up` or `sandbox_down`. If a step fails, send the error
      text and `ygg doctor`'s output.
- [ ] **Step 5 (optional, and what teaches the factory):** if you ever see a session fail for a reason
      that is not the agent's, a rate limit, a quota, an overloaded API, send the text of the failure. The
      table that decides how it counts (`gleipnir/failure/failure.go`) was written from the shapes the
      tools document and from OpenRouter's real errors, and a real message is one line in it.

---

## Evidence

What was run while this plan was written, on 2026-10-16, on this machine (WSL2, Go 1.26.4; Go 1.26.9
through `GOTOOLCHAIN`).

**Tests.** `go test -race -count=1 ./...` passes in all four repos on Go 1.26.4 and on Go 1.26.9.
`gungnir` passes with `GOWORK=off`, as CI runs it. The other three build only through `go.work` until
their siblings' pull requests are merged and pinned, as in Phase 2 and Phase 3; with each sibling
pinned by a `replace` to its local copy and `go mod tidy` run (which is what the pin commit does with
real versions), `gleipnir`, `jormungandr` and `odin` pass `GOWORK=off go test -race ./...` too, and
Jormungandr's `go.mod` gains exactly Gungnir's three indirect dependencies. The tests pass with
`HOME` pointing at a folder that doesn't exist and with `XDG_STATE_HOME` unset (the Odin test binaries set
their own), and with no network (`unshare -rn`). As root (the same namespace), the 18 tests that fail
on `main` for Phase 3's reason, a sandbox that `ygg` will not prepare as root, are the only ones that
fail: none of this phase's does (its two sandbox tests skip). `govulncheck` v1.8.0 on Go 1.26.9 finds
no vulnerability in any of the four. `reuse lint` is clean in all four. `go vet -tags sandbox` passes in
`gleipnir/sandbox` and `odin/internal/cli`.

**Each task alone.** `plan-states.sh` built and tested every task commit on its own: 44 of 44 pass.
**Each first failure.** `plan-red.sh` put each task's test files on the task's parent commit: the first
failure of each is the one its step shows. Four tasks have none, and say so: the two documentation tasks
(v0-T124, v0-T140), v0-T137, whose tests pin behavior the tasks before it built, and v0-T139, whose
realm files are test data and so are part of the failing test's setup (its steps show the failure by
hand).

**The defences each fail when removed.** For each row, the defence was removed from the code, the named
test was run, and it failed; then the code was restored. (`scripts/plan-defences.py` does it, from the rows in `defences.json` of the SDD folder; an executor can run it again on the merged code.)

| Task | Defence removed | Test that fails |
| --- | --- | --- |
| v0-T097 | an answer over the limit is refused | `TestAResultNamesHowItFailed` |
| v0-T102 | a report may not use an id twice | `TestParseReport` |
| v0-T108 | a session that did not finish still counts | `TestASessionWithoutAResultCountsWhatItReported`, `TestATimedOutSessionStillCountsItsUsage` |
| v0-T108 | session output is bounded | `TestSessionOutputIsBounded` |
| v0-T109 | tokens with no cost are refused, failed or not | `TestAFailedSessionWithTokensAndNoCostIsRefused` |
| v0-T112 | podman's own failure is an error | `TestExecReportsAMissingContainerAsAnError`, `TestUpRefusesAProbeThatCouldNotRun` |
| v0-T113 | Down gives up on a hung engine | `TestDownGivesUpOnAHungEngine` |
| v0-T114 | a check that runs too long fails | `TestACheckThatRunsTooLongIsAFailedCheck` |
| v0-T118 | the meter is asked before every try | `TestNoTryStartsOverABudgetCap` |
| v0-T118 | transient failures are retried | `TestTransientFailuresStopAfterTheRetriesAreUsed` |
| v0-T119 | a closed finding closes again | `TestACheckClosesItsFindingOnlyWhenItPasses` |
| v0-T120 | a close needs a file:line | `TestAReviewerReportThatBreaksARuleChangesNothing` |
| v0-T120 | a close needs the name of a check that passed | `TestAReviewerReportThatBreaksARuleChangesNothing` |
| v0-T120 | a finding may not vanish from a report | `TestAReviewerReportThatBreaksARuleChangesNothing` |
| v0-T120 | a reviewer speaks only for its own source | `TestAReviewerReportThatBreaksARuleChangesNothing` |
| v0-T122 | an agent failure uses up an attempt | `TestASessionThatFailedAsAnAgentUsesUpAnAttemptAndSaysWhy` |
| v0-T123 | a loop passes only when no blocking finding is open | `TestABlockingFindingFromASourceThatNoLongerRunsKeepsTheLoopFromPassing` |
| v0-T123 | an unreadable answer is not a pass | `TestAReviewerThatCannotBeReadIsAskedAgainOnceAndThenTheLoopEscalates` |
| v0-T123 | an unreadable reviewer escalates the second time | `TestAReviewerThatCannotBeReadIsAskedAgainOnceAndThenTheLoopEscalates`, `TestAnUnreadableAnswerIsRemembered` |
| v0-T125 | escalation stops in every mode | `TestModeTimesApprovalPointTable` |
| v0-T126 | a bad line in the journal stops the count | `TestACutShortLastLineIsIgnoredAndAnyOtherBadLineStopsTheCount` |
| v0-T127 | the day's cap | `TestTheMeterStopsAtTheRunsCapThenTheDays` |
| v0-T128 | usage is counted | `TestAFailedSessionsUsageStillCounts`, `TestASessionsUsageIsCountedInTheRunAndInTheDaysJournal` |
| v0-T129 | a session is bounded by the turns left | `TestASessionIsGivenOnlyTheTurnsTheCapsStillAllow` |
| v0-T129 | no session starts over a cap | `TestARunThatReachesItsCapStopsAtBudgetCapInEveryModeBeforeTheNextSession` |
| v0-T130 | a used-up quota pauses the run | `TestAUsedUpQuotaPausesTheRunAndAResumeStartsTheNodeAgain` |
| v0-T132 | a sandbox that fails under a command fails the node | `TestASandboxThatFailsUnderACommandFailsTheNodeAndAResumeGoesOn` |
| v0-T134 | a failed attempt leaves no half work | `TestASessionThatFailsAsAnAgentUsesUpAnAttemptAndLeavesNoHalfWork` |
| v0-T135 | an ignored file is a change (B-018) | `TestAReadOnlyRoleThatWritesAnIgnoredFileIsAHardStop`, `TestAReviewerThatWritesAnIgnoredFileIsAHardStop` |
| v0-T136 | a send-back starts the loop over | `TestASendBackAfterAPassedLoopStartsTheLoopOver` |
| v0-T136 | an unreadable reviewer cannot be approved | `TestAMalformedReviewerOutputStopsTheLoopAndIsNeverAPass` |

The first run of this table showed three defences whose tests passed: the loop's check that no blocking
finding is open (the ladder made it redundant for every state the loop could reach, so a test builds the
state it protects: a finding of a source that no longer runs), and two mutations that did not compile.
The first got its test, in v0-T123; the others were mistakes of the table.

**Defects the build found, which the tasks above carry fixed:**

1. Every Odin test would have written spend to the real `HOME` (the journal defaults to the operator's
   state folder): each test package now sets `XDG_STATE_HOME` in `TestMain`, and each CLI test has a
   journal of its own, since one folder shared by the CLI tests added up past a cap (62,820 tokens
   of a 200,000 cap, from the tests before it) and showed in `ygg status` (v0-T128, v0-T131).
2. A read-only role compared with an empty status would have flagged every ignored file an earlier check
   left: the check compares the leaf before and after the session (v0-T135).
3. The gate file for a loop that ran out of attempts asked `Approvable` before the stop was saved, so it
   offered no approval; the offer is now decided from the reason (v0-T136).
4. A merge-gate test constant named `checks` clashed with the package now imported under that name
   (v0-T132), and a status line said how many attempts a loop *allowed* instead of how many it *used*
   when a reviewer ended it in attempt 1 (v0-T138).
5. A retried session ran on what the dropped one left in the leaf: a retry now starts from the
   checkpoint (v0-T134).

**What the tools printed.** The classification table (`failure.Classify`) rests on two things. The
`opencode` error event, `{"type":"error","error":{"name":"APIError","data":{"message","statusCode"}}}`,
was read from real output in Phase 3, and its fixtures are in `gleipnir/opencode/testdata`. Claude Code's
`result` event carries `is_error`, `subtype` and `api_error_status`, which the Phase 3 fixtures show,
and whose quota and rate-limit wording is **assumed**: no failure of that kind could be produced without
using the founder's quota. The `claude-code` adapter's count of a session that left no result reads
`message.id` and `message.usage` from `assistant` events; Phase 3's fixture has the usage and no id, so a
message with no id counts on its own, which can only overcount. v0-H11 step 5 asks for real messages.

**Not run:** a real model session, and the driver on a real engine again (v0-H11 does both; the driver's
only change in behavior is the exit code 125 of `podman exec`).
