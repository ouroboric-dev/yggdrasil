---
title: Yggdrasil v0, Phase 6 tasks (metrics, the Harbor bridge and the proof runs)
status: proposed
date: 2026-10-22
related: [../2026-10-12-yggdrasil-v0/plan.md, ../2026-10-18-yggdrasil-v0-phase-5c/tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../changes/2026-10-15-project-is-its-own-tree/tasks.md, ../../changes/2026-10-14-benchmark-split/tasks.md, ../../../1-product/design/2026-10-11-yggdrasil-v0-design.md]
style: spec
---

# Yggdrasil v0, Phase 6: metrics, the Harbor bridge and the proof runs

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking. Tasks and steps marked **founder** are done by the founder,
> never by an agent.

**Goal:** the last phase of the [plan](../2026-10-12-yggdrasil-v0/plan.md). The factory can say what a run
cost and how it went (`ygg metrics`, `ygg metrics --compare`, `ygg report`), show its work (`ygg board`,
`ygg board --all`, `ygg status --watch`), run on a Harbor task (`ygg bridge`), and the founder can run the proof
runs that meet the design doc's success criteria 1 to 7 and read their results with these commands. The v0
hidden suite is then retired. Before any of that, one hard cap is made to mean what the spec says: a dollar cap
counts what a paid API billed, not what a subscription's sessions would have cost.

**Architecture:** the metrics are reads of three files of a run: `ledger.jsonl`, whose hash chain is verified
before any number is taken from it, `run.json` (a few fields; unknown fields are ignored, so a run written by
another build stays readable) and `score.json`. The commands write nothing, except `ygg report`, which writes
`report.md`. The ledger gets the few fields that a metric needed and could not read without parsing text. The
board is the local tracker of spec §10.4. The bridge speaks the Harbor adapter's JSON-line protocol on standard
input and output and runs the same engine as `ygg run`. The proof runs are founder tasks run by one new script.

**Tech stack:** Go 1.26 and the pins of Phase 5c, with no new module; `bash` and `python3 -I` for the two scripts.

**Spec:** [v0 engineering spec](../../specs/2026-10-11-yggdrasil-v0-spec.md) §7.2, §7.4, §10 and §11; the
[design doc](../../../1-product/design/2026-10-11-yggdrasil-v0-design.md) §2.3 (the success criteria); and the
changes [project-is-its-own-tree](../../changes/2026-10-15-project-is-its-own-tree/tasks.md) (its T002 is
`ygg board --all`) and [benchmark-split](../../changes/2026-10-14-benchmark-split/tasks.md) (its T002 retires
the v0 suite).

**Status:** accepted when the founder merges the pull request that adds this file.

**Code in this plan was run, except where a task says it was not.** Every Go file, script and test shown below was built and run in a scratch workspace on
2026-10-22, one commit per task, with `go test` (`-race` for the packages with goroutines), and every test that
guards a defence was run again with the defence removed (the mutation checks in "Evidence"). The metrics were also
read from four real run folders on the founder's machine. The two tasks of the proof-run script (v0-T290 and v0-T291), the runbook,
the proposal and the pointers show no code: they were not built, and each says so. "Evidence" says what was and was not run. Copy the code
as written; if a step's expected result differs, stop and report it, because the plan is wrong. The reading rules
for code blocks are those of Phase 5c: a new file is shown whole; a change is a `diff`.

**The hard rule of this plan.** Nothing in it asks an agent to read, list or search `huldra` or
`ouroboric-private`. `ygg metrics`, `ygg report` and `ygg board` never open a suite. The proof-run script checks that
the suites folder exists (`test -d`) and passes its path to `ygg`; it never lists it. Every test here uses a run built
for the test, and the founder's runs use the folder the founder keeps.

## Decisions for this phase

Each line is **Decided 2026-10-22** when the founder merges this plan. The questions the founder may answer
differently are in "Questions for the founder", each with the answer a task assumes.

1. **Phase 6 is built in two parts** (see question 5). This plan holds part one: 24 agent tasks in `gungnir`, `odin`,
   `ouroboric` and `yggdrasil`, one conditional task that writes a change proposal, and the founder's runs. Part two is
   an amendment that the founder asks for after the planning rehearsal (v0-H19) and the first scored run (v0-H20): the
   runtime that lets the gallery brief's product start in the grader (question 10) and the factory change of the
   improvement run (criterion 7). Neither can be planned before a real run has shown what the factory builds.
2. **The metrics are reads.** `ygg metrics` reads the ledger after `ledger.Verify` checked its chain against the
   anchor in `run.json`, `run.json`, and `score.json`. A ledger that was changed or cut short gives no number at all.
3. **The definitions** (spec §10.2 names the metrics; this table fixes what each one counts):

   | Metric | What it counts | Read from |
   | --- | --- | --- |
   | tokens, turns | the sum of the lines that record a session (`node_finished`, `node_failed`); the run's own totals (`run_finished`, `run_paused`, `run_failed`) repeat them and are left out; the sum is checked against `run.json` and a difference is a warning | `ledger.jsonl`, `run.json` |
   | cost | two figures: **at API prices** (the sum of the cost fields) and **billed** (the part from a paid adapter: anything but `claude-code` and `scripted`). A session with tokens and no cost counts as **unpriced** (a `scripted` session has no price to miss): its cost is unknown, not zero (B-107) | `ledger.jsonl` |
   | wall time | **elapsed** (first line to `run_finished`), minus the **approval waits** (`gate_pending` to its decision) and the **stopped** time (`run_failed` or `run_paused` to the next `run_resumed`, or the gap before a resume that no failure line explains: a killed process). What is left is **active**. Grading after `run_finished` is grade time | `ledger.jsonl` |
   | first-pass rate | loops that passed in attempt 1, out of the loops that ended (passed or gave up). With no loop ended there is no rate, and the report says so | `loop_attempt`, `escalation` |
   | average loop attempts | the attempt each ended loop ended in, averaged | the same |
   | reviewer veto rate | attempts in which a reviewer raised or reopened a `blocker` or `major` finding, out of the attempts in which a reviewer ran. A failing check is not a veto | `finding_*` with `ygg.finding.origin`, reviewer sessions |
   | interventions | rejections, approvals with a note, and escalations (spec §7.2); each listed with where and what was said | `gate_*`, `escalation` |
   | escalations, blocked tasks | the escalation lines; the tasks `run.json` records as blocked, each with why | `escalation`, `run.json` |
   | hidden acceptance score | the reward, the fail-to-pass and pass-to-pass tallies and the categories of `score.json`; without it, the `grade_finished` line | `score.json` |
   | escaped defects | the fail-to-pass scenarios that failed. The report also says how many tasks the run gave up: with any, some failures are work that was never built | `score.json`, `run.json` |
   | routing | `routing_lookup` lines (the factory writes none yet), the indexes built, and the bench score of a measured index with its grep baseline and the pack's bar; "not measured" when the pack sets none | `routing_index_built` |

4. **A cost is stated at API prices, with the billed part apart, and the dollar caps count the billed part.** Today
   `Cap.Reached` counts the sum of every session's cost figure whenever any role pays per token, so a config with
   Claude Code on the subscription and OpenCode on OpenRouter would stop at the $5 cap on the subscription's *estimate*
   (Sonnet sessions come to about $0.03 a turn at API prices) long before the paid reviewer spent a dollar. v0-T288 and
   v0-T289 fix it. A journal written before the change has no billed figure, so the first day's total undercounts
   its earlier lines; the caps are per day and per run.
5. **A comparison is B minus A.** Two runs of another brief, task version or suite are *not comparable*; the deltas are
   still printed, with the reason. The verdict for criterion 7 names the metrics that improved and the ones that got
   worse and says whether the hidden score held; metrics with no direction (the veto rate) are shown and never judged.
6. **The report** is `report.md` in the run's folder: the tasks the run gave up first (spec §7.3), the metrics, the
   interventions, the loops that gave up, and every finding a dispute overruled with the reviewer's claim, the
   implementer's evidence and the check (B-115). It names the ledger line it was read from and is the same bytes every
   time. Text an agent wrote is quoted or put on one line, and control characters are never printed. `--commit` also
   commits a copy as `docs/runs/<run-id>.md` (question 12).
7. **The board** has the six columns of spec §10.3: Ready, In progress, Verifying, Blocked, Needs you, Done. A task
   that is doing is in progress while its implementer works, verifying once the checks and reviewers judge it or its
   loop has passed, and in Needs you when the run stopped at one of its gates or failed. Spec §10.4's views map to
   them (Now is In progress and Verifying, Agent queue is Ready, Triage is empty in v0 because nothing arrives from
   outside). `ygg board --all` reads `$XDG_CONFIG_HOME/ouroboric/projects.yaml` (or `~/.config/ouroboric/projects.yaml`),
   a list of absolute paths; one path that is not a project umbrella refuses the whole list.
8. **`ygg status --watch`** prints the status again every `--interval` (2 seconds) while a process holds the run, with
   a `now:` line from the end of the ledger. It reads a ledger being written and does not verify it: it is not evidence.
9. **The ledger gets five additions**, all additive and inside `ygg.ledger/v1`: the event `dispute_ignored` (B-114),
   `ygg.finding.origin` (`check` or `review`) on finding lines, the routing bench numbers on `routing_index_built`,
   and `ygg.factory.version` on `run_started` and `run_resumed`, with `factory` in `run.json`. The factory version is
   `odin <12 characters of the commit>` and the commits of `gungnir`, `gleipnir`, `jormungandr` and `havamal` from the
   binary's build info; a build with changes says `+dirty`, and a module replaced or built from a workspace says
   `local`, because such a build cannot be repeated from the pins.
10. **The Harbor bridge** is built (`ygg bridge`) although no criterion needs it: it is in the approved scope, and the
    adapter already waits for it. Standard output carries requests and nothing else. A Harbor run has no one to approve a
    gate, so a run that stops is handed over as it is. The Harbor verifier, not Odin's grader, scores such a run.
11. **The journal check** (`scripts/journal-check.sh`) makes criterion 6 mechanical: an entry tagged `factory-change`
    that is resolved must cite `ygg metrics --compare` and two run ids in its Result.
12. **The proof runs** (founder tasks) are: a planning rehearsal (v0-H19), run 1 (v0-H20), a repeat of it (v0-H21), the
    cross-model run (v0-H22) and the improvement run (v0-H23, after part two). All use the frozen brief of
    `client-gallery-lite`, the `software` graph and `key-points` mode. They differ in one thing each.
13. **Per leaf, not per suite, in v0** (question 7). The metrics and the report group tasks, usage and gave-up work by
    leaf and by role and model, which is what the founder needs to see which realm or model is good at what. A reward
    stays one number per task. A grade per leaf from its own suite, and a rubric for qualities no suite tests
    (`rubric.md`, spec §11), stay open as B-116's second half.
14. **Sizes** count inserted lines (S under 100, M to 400). No task is over 400.
15. **What Phase 6 leaves open** is in "Not in Phase 6" and in the backlog items v0-T294 files.

## Questions for the founder

Each task assumes the answer in **bold**. Say so on the pull request if you want another.

| # | Question | Assumed |
| --- | --- | --- |
| 1 | **The cross-model run (criterion 2).** Which role changes, and to what? | **The implementer, on OpenCode with `openrouter/qwen/qwen3.8-27b`** (B-110: it works with no adapter change and scored 0.5 against 1.0 on the smoke, one run each). The planner and the reviewers stay as in run 1. One role at a time. Run 1's implementer is free on the subscription and this one is not: the config's `per_run.usd` is the guard |
| 2 | **The improvement run (criterion 7).** Which factory change, and which metric must improve? | **Chosen after run 1, from its report**, and made through its own change proposal in part two. The candidates today: B-136 (a reviewer prompt that tries the brief's routes and forms; the metric is escaped defects, with the score held), a cheaper reviewer effort for one role (B-106; the metric is cost per task), B-137 (stray files). Criterion 7 names first-pass rate, cost per task or interventions, and `--compare` must show it without lowering the score |
| 3 | **How many runs, and the caps.** | **A rehearsal that plans only, then four scored runs: run 1, a repeat of it, the cross-model run and the improvement run.** One run per cell is thin (hosted models change from hour to hour, per the journal), so the repeat measures the spread. **Estimate, not measured:** the smoke took 14 turns and 44k tokens (cache reads excluded) for one tiny task; the gallery plan is probably 12 or more tasks, each with three reviewers, so a run is about 600 to 1,000 turns and 3 to 5M tokens. [budget.md](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/1-company/budget.md) caps a run at 400 turns, so run 1 would stop at the cap. **Assumed: `per_run` 1,500 turns, 12M tokens and $5 billed; `per_day` 2,000 turns, 24M tokens, $10 billed**, and the founder reads run 1's real size before the other runs. The paid part is the Qwen reviewers (about $0.01 a session, perhaps $1 a run); with a Qwen implementer, perhaps $3 to $6. The OpenRouter key's $25 a month is the backstop |
| 4 | **Unattended or attended.** | **Every scored run is `key-points`, the founder approving the design gate and any deviation.** The interventions metric needs the same mode on both sides of a comparison. Criterion 4's scripted half is `TestToyGraphEndToEnd` (all three modes, Phase 1), run again at the exit check. B-135 (an escalation from the contract folder rules stops an unattended run) is not decided here: it is measured, and it matters only if a run is made unattended |
| 5 | **A split.** | **No split by size** (25 tasks, under 45). The split is by what can be known: part two is an amendment after v0-H19 and v0-H20 (decision 1) |
| 6 | **The photographer's run.** | **It is not a Phase 6 factory run.** The Asgard design puts it "during Phase 6" as her own journey on her helper's machine; her products are built after Yggdrasil v0, and the proof runs stay on the frozen brief. Nothing in this plan builds her products |
| 7 | **A grade for each piece of software (B-116).** | **Per leaf in the metrics, one reward per task** (decision 13). The reward counts only the hidden suite's fail-to-pass scenarios, by category. A grade per leaf from a suite of its own needs the leaf's dependencies stood up (B-118) and a per-leaf suite in `huldra`, which is the founder's. "Beautiful" and "responsive" are judged from the built product against the task's `rubric.md`, by the founder, and written in the journal; they never enter the reward. No weights are invented before two scored runs show which leaves vary |
| 8 | **How a leaf's dependencies reach the grader (B-118, B-117).** | **With question 10.** Both are part of the runtime that lets the product start in the grader |
| 9 | **The suites and the grader (B-134, B-135, B-120).** | **B-134 is done** (the hidden suite v2 prints the keyed line; the reference product scored 29 of 29). **B-135: measure first, no change.** **B-120: no task**; the overshoot of a `max_tokens` is read from a scored run's ledger (`node_failed` with `token-limit`) |
| 10 | **Does the brief fit the realms? (new)** | **Decided after v0-H19, which costs cents and shows what the planner designs.** The frozen brief (§6 of `instruction.md`) asks for one self-contained machine: `/app/start.sh` starts the whole product, which serves everything on port 3000 on all interfaces, with "no outside services". The web realm builds a React leaf and a Go API leaf with Postgres and SeaweedFS (spec §9.2 and §9.3; the services in `helheim-go/pack.yaml`); the browser sends photo bytes straight to the S3 API; the web leaf serves on `127.0.0.1` only (B-117); the root `start.sh` is the infra realm's, which does not exist (B-078). The grader image (`mimir/client-gallery-lite/environment/Dockerfile`) holds Playwright, Node and Python, no Postgres and no SeaweedFS, and the grader has no network (B-118). Read together, a product built as the realms' design says cannot start in the grader. **Not run:** no real-agent run of the `software` graph has planned this brief. The options: **A**, bake Postgres and SeaweedFS into a new task version of the image (`4.1.0`, same brief and hash) and have the factory write a root `start.sh`; **B**, give the realms a single-machine flavor (SQLite and files on disk, one process); **C**, the planner is told by the brief only and the realms' docs yield. **Lean:** read v0-H19 first |
| 11 | **The dollar caps (new).** | **Fix them** (v0-T288, v0-T289), as decision 4 says. The alternative is a very high `per_run.usd` and the OpenRouter key's own limit as the only dollar guard |
| 12 | **Where a report is committed (new).** Spec §10.3 says `report.md` "is committed" in the run folder, which a project ignores (`.factory/`). | **`ygg report --commit` commits a copy as `docs/runs/<run-id>.md`.** Without the flag nothing is committed. A report holds numbers and the notes the operator wrote, no secret; a private run's report stays in the private project |
| 13 | **The Harbor side now (new).** | **Yes, v0-T286 and v0-T287.** No criterion needs it. The real Harbor run of it is v0-H24 and is optional |

## Global constraints

- **Local copies.** The component repos are submodules of `yggdrasil`, at
  `/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`, and `yggdrasil/go.work` builds them together. `mimir` and
  `ouroboric` are separate folders beside it. Each task works on a branch in the repo it changes. The umbrella's pointers
  move once, in v0-T294.
- **GitHub.** Agents reach GitHub only as `ouroboric-pr-bot`, through
  `/home/brunogbv/brunogbv/ouroboric/ouroboric/scripts/as-bot.sh`, and run `gh` with `--repo ouroboric-dev/<repo>`. Every
  change lands through a PR the founder merges. Agents never merge and never push to `main`.
- **Commits.** Read `git status --short` first, and stage explicit paths, never `git add -A`. Commit messages end with
  the attribution lines the session gives. Commits and PRs carry no session links. Every repo runs the `gitleaks` hook.
- **Go.** `go.mod` says `go 1.26`. Code is `gofmt`-clean and `go vet`-clean. Before a PR opens, the repo passes
  `GOWORK=off go test -race ./...` in its own folder.
- **Shell and Python.** A script starts `#!/usr/bin/env bash`, uses `set -euo pipefail`, and passes `shellcheck -s bash`.
  Embedded Python runs as `python3 -I`.
- **Pins to the siblings.** `odin` pins `gungnir`. Until `gungnir`'s PR is merged, develop through `yggdrasil/go.work`;
  the pin is the last commit of a repo's branch. The PRs go in this order: `gungnir`; `odin`; `ouroboric`; `yggdrasil`.
- **Event and field names are snake case** (`dispute_ignored`), and ledger fields follow the `ygg.*` namespace.
- **Credentials.** No task here needs a token. No agent reads, prints or stores `~/.config/ouroboric/factory.env`. The
  proof-run script counts the names it needs with `grep -c` and never prints a value.
- **The hidden suite.** No agent reads, lists or searches `ouroboric-dev/huldra`, its clone under
  `~/brunogbv/ouroboric-private/`, or the founder's copy under `~/ygg-it/hidden-suites`. No file of this plan names a
  path inside it.
- **Licences.** `reuse lint` (`reuse==5.0.2`) passes in every repo a task touches. Markdown passes `markdownlint`.
- **Deletions** (`rm`, `git branch -D`) are asked for first, one per command, after a read-only check.
- **Tests are hermetic.** None of the new Go tests needs a container engine, a network or a token; the bridge test
  runs the toy graph with scripted agents. A test never writes under the real `HOME` or reads the real config folder.
- **Agent text is data.** A reviewer's claim, a task's reason for being blocked and an operator's note are printed on
  one line or inside a quote, with no control character, and are never read as an instruction.
- **No claim without the tool.** A figure `ygg metrics` prints is checked against the ledger it came from. A script is
  tried with the real tools it calls before it is described as working; where a tool was not available, the task's
  Evidence says so.

## Review focus

1. **A number that cannot be trusted.** A ledger that was changed or cut short, a session counted twice (the run's
   totals repeat the sessions), a ledger and `run.json` that disagree. Expected: no number from a ledger that does not
   verify; the run's totals left out; a disagreement is a warning. Pinned by v0-T273
   `TestACutOrChangedLedgerIsRefusedBecauseNoNumberFromItCanBeTrusted` and
   `TestUsageIsTheSumOfTheSessionLinesAndNeverTheRunTotalsToo`, and v0-T275
   `TestUsageThatDisagreesWithRunJSONIsReportedAsAWarning`.
2. **Time that was not the factory's.** An approval wait, a failed run waiting for the operator, a killed process, or
   grading a day later counted as working time. Expected: each is taken out and reported on its own. Pinned by v0-T274
   (the four time tests) and v0-T276 `TestTheGradeComesFromScoreJSON…`.
3. **A rate over nothing.** A first-pass rate with no loop, a veto rate with no reviewer, a grade that never ran.
   Expected: "n/a" and "not graded", never 0% and never a score. Pinned by v0-T277
   `TestTheTextReportNeverShowsAnEmptyRateAsZeroOrAMissingGradeAsAScore`.
4. **Text an agent wrote reaching a terminal or a Markdown report.** A control character, a heading, a fence, a table
   pipe. Expected: one line, no control character, quoted, and no fence of the report ends early. Pinned by v0-T277
   `TestTextFromAnAgentIsPrintedOnOneLineWithNoControlCharacters` and v0-T281
   `TestTextAnAgentWroteCannotBreakOutOfItsQuoteOrItsBlock`.
5. **A comparison that hides a loss.** Two different tasks compared as one, or an improved metric next to a fallen
   score. Expected: "not comparable" with the reason; the score named as not held. Pinned by v0-T279
   `TestRunsOfAnotherBriefOrSuiteAreNotComparable…` and `TestAFallingRewardIsNeverHiddenBehindAnImprovedMetric`.
6. **A cap that stops a free run, or lets paid spend through.** Expected: the dollar cap counts what a paid adapter
   billed and nothing else, in `Reached`, in the meter's warning and in `ygg status`. Pinned by v0-T288 and v0-T289.
7. **The bridge saying anything but a request.** Expected: standard output holds only requests; a reply for another id,
   a refusal and an over-long line are errors; a run that was refused starts nothing and sends no `done`. Pinned by
   v0-T286 and v0-T287 `TestBridgeWritesNothingToStandardOutputButRequests`.
8. **A board or a list that lies.** A task in the wrong column, a stale `features.json`, a path in the operator's list
   that is not a project. Expected: the column its status and its loop say; a missing run falls back to statuses; one
   bad path refuses the list. Pinned by v0-T282 and v0-T283.
9. **A tool that reaches the hidden suite.** Expected: none does; the proof-run script only tests that the folder
   exists. Pinned by v0-T290 and v0-T291 (a shim for each reader of files; none is called with the suites folder).

## Order

| Task | Repo | Size | Depends on |
| --- | --- | --- | --- |
| v0-T270 ledger fields that the metrics read | `gungnir` | M (123) | Phase 5c |
| v0-T271 the `Tracker` interface and the board types | `gungnir` | M (179) | Phase 5c |
| v0-T288 `Usage.BilledUSD`: the dollar caps count what was billed | `gungnir` | S (41) | Phase 5c |
| v0-T289 the engine bills only a paid adapter's sessions | `odin` | S (63) | v0-T288 |
| v0-T272 the engine writes the new fields; the factory build is recorded | `odin` | M (285) | v0-T270 |
| v0-T273 `internal/metrics`: usage, the run's record and trust | `odin` | M (399) | v0-T272 |
| v0-T274 the time the factory worked | `odin` | M (197) | v0-T273 |
| v0-T275 tasks, loops, reviewer vetoes, findings and interventions | `odin` | M (387) | v0-T274 |
| v0-T276 the grade, the escaped defects and routing | `odin` | M (267) | v0-T275 |
| v0-T277 the text report and the range table | `odin` | M (322) | v0-T276 |
| v0-T278 `ygg metrics` | `odin` | M (237) | v0-T277 |
| v0-T279 compare two runs | `odin` | M (387) | v0-T277 |
| v0-T280 `ygg metrics --compare` | `odin` | S (86) | v0-T278, v0-T279 |
| v0-T281 `ygg report` | `odin` | M (398) | v0-T280 |
| v0-T282 the local tracker and `ygg board` | `odin` | M (347) | v0-T271, v0-T281 |
| v0-T283 `ygg board --all` | `odin` | M (224) | v0-T282 |
| v0-T284 `ygg status --watch` | `odin` | M (252) | v0-T273 |
| v0-T286 the factory's end of the Harbor bridge | `odin` | M (360) | none |
| v0-T287 `ygg bridge` | `odin` | M (399) | v0-T286, v0-T289 |
| v0-T285 `journal-check.sh` and the `factory-change` tag | `ouroboric` | M (216) | none |
| v0-T290 the proof-run script: setup and the dry run | `ouroboric` | M | none |
| v0-T291 the proof-run script: the run, the grade and the evidence | `ouroboric` | M | v0-T290, v0-T278, v0-T280, v0-T281 |
| v0-T292 the runbook of the proof runs | `yggdrasil` | S | v0-T291 |
| v0-T293 the runtime of the gallery brief: a change proposal (conditional) | `yggdrasil` | S | v0-H19 and the founder's answer to question 10 |
| v0-T294 pointers, backlog and the exit check | `yggdrasil` | S | all above, merged |
| v0-H18 (founder) get ready | the founder's machine | S | the PRs merged |
| v0-H19 (founder) the planning rehearsal | the founder's machine | S | v0-H18, v0-T291 |
| v0-H20 (founder) run 1, the baseline | the founder's machine | M | v0-H19, question 10 answered |
| v0-H21 (founder) run 1 again, for the spread | the founder's machine | M | v0-H20 |
| v0-H22 (founder) the cross-model run | the founder's machine | M | v0-H20 |
| v0-H23 (founder) the improvement run | the founder's machine | M | part two, v0-H21 |
| v0-H24 (founder, optional) the bridge on Harbor | the founder's machine | S | v0-T287 merged |
| v0-H25 (founder) the exit check | the founder's machine | S | v0-H20 to v0-H23 |
| v0-H26 (founder) retire the v0 hidden suite | the founder's machine | S | v0-H25 |

Pull requests, in order: `gungnir` (v0-T270, v0-T271, v0-T288) first. Then `odin` in two PRs that stack. **v0-T289 is the
first commit of the first**, because with the new `gungnir` an old test of the meter fails until it lands: the first PR holds
v0-T289 and v0-T272 to v0-T281, the second v0-T282 to v0-T284, v0-T286 and v0-T287. Then `ouroboric` (v0-T285, v0-T290, v0-T291),
then `yggdrasil` (v0-T292 and v0-T294; v0-T293 is its own PR, later). Inside a repo the tasks stack on one branch.

## Not in Phase 6

A grade per leaf from a suite of its own, and the rubric (decision 13); the root `start.sh`, the services in the grader
and the runtime of the gallery brief (question 10; part two); the improvement run's factory change (part two); the emitter
of `routing_lookup` and the routing summary in a session (spec §8.1), so the routing metrics read 0 lookups; `ygg routing
build|bench` (B-076) and the author of the first bench (B-077), so the `software` graph's indexes ship unmeasured;
the `github` tracker and any web board; a fix for B-051 (watch it with `ygg-events-watch.sh`; do not change Gleipnir's
retry); B-120, B-133 (the OpenCode bump) and B-135 (decisions 12 and question 9); parallel agents; deploying anything;
the photographer's builds; Bragi.

## How each task lands

Every agent task ends the same way. Run the commands in the repo's folder:

```bash
gofmt -l .                        # prints nothing
go vet ./...
GOWORK=off go test -race ./...    # what CI runs
uvx -q --from 'reuse==5.0.2' reuse lint -q
git status --short                # then stage the task's files by path
git commit -m "<what changed> (v0-T2xx)" -m "<the attribution lines the session gives>"
```

A shell script also passes `shellcheck -s bash`, and its test (`bash scripts/tests/<name>.test.sh`) exits 0. When the
repo's last task is committed, push and open its pull request:

```bash
../../ouroboric/scripts/as-bot.sh <repo> git push -u origin <branch>
../../ouroboric/scripts/as-bot.sh <repo> gh pr create --repo ouroboric-dev/<repo> --title "<title>" --body-file <file>
```

The PR body names the tasks, lists their acceptance criteria with their evidence (the named tests' output), and says which
earlier PRs it needs merged first. CI's `test` check must be green before the founder merges it. To pin a sibling, fetch it,
then pin its `main`:

```bash
../../ouroboric/scripts/as-bot.sh --read all git -C ../gungnir fetch -q origin
GOWORK=off go get github.com/ouroboric-dev/gungnir@$(git -C ../gungnir rev-parse origin/main)
GOWORK=off go mod tidy
```

`GOWORK=off go test` fails until the merged pins exist; develop through `go.work` and pin before the PR.

---

### Task v0-T270: ledger fields that the metrics read

Gungnir's first task of Phase 6. Branch `phase-6/ledger-fields` from `main` in `gungnir`, before step 1. The metrics of
spec §10.2 need four things that the ledger either does not write or writes only as text: a dispute that could not be used
(today a `loop_attempt` line whose result begins "dispute ignored", B-114), whether a check or a reviewer raised a finding
(a veto is a reviewer's, not a check's), the bench score of a routing index (today inside a note), and the build of `ygg`
that wrote the run (spec §10.2: "every run report MUST record the factory version"). The engine writes them in v0-T272.

**Files (in `gungnir`):**

- Create: `schema/event_metrics_test.go`
- Modify: `docs/architecture.md`, `docs_test.go`, `event.go`, `schema/ledger-event.schema.json`

**Interfaces:**

- Produces: `gungnir.EventDisputeIgnored` (`dispute_ignored`), listed by `gungnir.Events()` and accepted by the ledger
  schema. Its `Note` says why, and `Node` and `Attempt` say where.
- Produces: `gungnir.FindingOrigin` with `gungnir.OriginCheck` (`check`) and `gungnir.OriginReview` (`review`), and
  `Event.FindingOrigin` (`ygg.finding.origin`), written on the finding events and refused with any other value.
- Produces: `Event.RoutingBench`, `Event.RoutingBaseline` and `Event.RoutingThreshold` (`*float64`: `ygg.routing.bench`,
  `ygg.routing.baseline`, `ygg.routing.threshold`, each from 0 to 1). They are pointers so that a score of 0 is still
  written.
- Produces: `Event.FactoryVersion` (`ygg.factory.version`, 1 to 200 characters), written on `run_started` and
  `run_resumed`.

**Acceptance criteria:**

- [ ] Every new field validates on its event with the exact key names above. A bench score or a baseline over 1 or under
      0, an origin that is not `check` or `review`, and a factory version that is empty or over 200 characters are refused.
- [ ] A bench score of 0 is written to the line.
- [ ] `docs/architecture.md` names the event and the four fields; a test fails when it does not.

**Review focus pinned by tests:** a score of 0 is not a missing score (`TestAZeroBenchScoreIsStillWrittenAndABadMetricsFieldIsRefused`);
an unknown origin is refused (the same test); the page names what the metrics read (`TestTheArchitecturePageNamesWhatMetricsReads`).

**Named test:** `go test . ./schema -run 'TestTheLedgerRecordsWhatMetricsReads|TestAZeroBenchScoreIsStillWrittenAndABadMetricsFieldIsRefused|TestTheArchitecturePageNamesWhatMetricsReads|TestLedgerEventSchema'`
in `gungnir`. **Layer:** `gungnir`. **Size:** M (123). **Depends on:** Phase 5c merged.

- [ ] **Step 1:** write the tests.

Apply to `docs_test.go`:

```diff
diff --git a/docs_test.go b/docs_test.go
index b19d3fc..52e3779 100644
--- a/docs_test.go
+++ b/docs_test.go
@@ -43,3 +43,18 @@ func TestTheArchitecturePageNamesTheGraphPins(t *testing.T) {
 		}
 	}
 }
+
+// The architecture page names what `ygg metrics` reads from the ledger: a new field of that kind with no line in
+// the page fails here.
+func TestTheArchitecturePageNamesWhatMetricsReads(t *testing.T) {
+	b, err := os.ReadFile(filepath.Join("docs", "architecture.md"))
+	if err != nil {
+		t.Fatal(err)
+	}
+	page := string(b)
+	for _, want := range []string{string(EventDisputeIgnored), "ygg.finding.origin", "ygg.routing.bench", "ygg.routing.baseline", "ygg.routing.threshold", "ygg.factory.version"} {
+		if !strings.Contains(page, want) {
+			t.Errorf("docs/architecture.md does not mention %q", want)
+		}
+	}
+}
```

Write `schema/event_metrics_test.go`:

```go
package schema

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func TestTheLedgerRecordsWhatMetricsReads(t *testing.T) {
	bench, baseline, bar := 0.85, 0.6, 0.8
	cases := []struct {
		name  gungnir.EventName
		fill  func(*gungnir.Event)
		wants []string
	}{
		{gungnir.EventDisputeIgnored, func(e *gungnir.Event) {
			e.Node, e.Attempt, e.FindingID, e.FindingSource, e.Note = "implement", 2, "no-owner-check", "spec-compliance", "the check it names is not run by this loop"
		}, []string{`"event":"dispute_ignored"`, `"ygg.finding.id":"no-owner-check"`, `"ygg.finding.source":"spec-compliance"`}},
		{gungnir.EventFindingRaised, func(e *gungnir.Event) {
			e.FindingID, e.FindingSource, e.FindingSeverity, e.FindingOrigin = "f1", "quality", "major", gungnir.OriginReview
		}, []string{`"event":"finding_raised"`, `"ygg.finding.origin":"review"`}},
		{gungnir.EventFindingClosed, func(e *gungnir.Event) {
			e.FindingID, e.FindingSource, e.FindingSeverity, e.FindingOrigin, e.FindingAttempts = "f2", "unit", "blocker", gungnir.OriginCheck, 2
		}, []string{`"event":"finding_closed"`, `"ygg.finding.origin":"check"`}},
		{gungnir.EventRoutingIndexBuilt, func(e *gungnir.Event) {
			e.IndexKind, e.Edges, e.Extracted, e.RoutingBench, e.RoutingBaseline, e.RoutingThreshold = "impact", 9, 9, &bench, &baseline, &bar
		}, []string{`"ygg.routing.bench":0.85`, `"ygg.routing.baseline":0.6`, `"ygg.routing.threshold":0.8`}},
		{gungnir.EventRunStarted, func(e *gungnir.Event) {
			e.FactoryVersion = "odin b8c9716fa818 gungnir 32cc95d9d0ff gleipnir 6b6f83eec777"
		}, []string{`"ygg.factory.version":"odin b8c9716fa818 gungnir 32cc95d9d0ff gleipnir 6b6f83eec777"`}},
	}
	for _, c := range cases {
		e := event(c.name)
		c.fill(&e)
		line, err := json.Marshal(e)
		if err != nil {
			t.Fatal(err)
		}
		for _, want := range c.wants {
			if !strings.Contains(string(line), want) {
				t.Errorf("%s: line lacks %s:\n%s", c.name, want, line)
			}
		}
		if err := ValidateEvent(line); err != nil {
			t.Errorf("%s: ValidateEvent() = %v", c.name, err)
		}
	}
}

func TestAZeroBenchScoreIsStillWrittenAndABadMetricsFieldIsRefused(t *testing.T) {
	zero := 0.0
	e := event(gungnir.EventRoutingIndexBuilt)
	e.IndexKind, e.Edges, e.RoutingBench, e.RoutingBaseline = "wiring", 3, &zero, &zero
	line, _ := json.Marshal(e)
	if !strings.Contains(string(line), `"ygg.routing.bench":0`) || !strings.Contains(string(line), `"ygg.routing.baseline":0`) {
		t.Errorf("a bench score of 0 was dropped:\n%s", line)
	}
	if err := ValidateEvent(line); err != nil {
		t.Errorf("ValidateEvent() = %v", err)
	}
	start := func(field string) string {
		return `{"schema":"ygg.ledger/v1","seq":1,"time":"2026-10-15T09:00:00Z","ygg.run.id":"20261015-090000-a1b2c3","event":"finding_raised",` + field + `,"prev":"` + zeros + `"}`
	}
	for name, bad := range map[string]string{
		"an unknown origin":         start(`"ygg.finding.origin":"robot"`),
		"a bench score over 1":      strings.Replace(string(line), `"ygg.routing.bench":0`, `"ygg.routing.bench":1.5`, 1),
		"a negative baseline":       strings.Replace(string(line), `"ygg.routing.baseline":0`, `"ygg.routing.baseline":-0.2`, 1),
		"an empty factory version":  strings.Replace(start(`"ygg.factory.version":""`), "finding_raised", "run_started", 1),
		"a factory version of 300+": strings.Replace(start(`"ygg.factory.version":"`+strings.Repeat("x", 300)+`"`), "finding_raised", "run_started", 1),
	} {
		if err := ValidateEvent([]byte(bad)); err == nil {
			t.Errorf("%s: ValidateEvent() = nil", name)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./docs_test.go:55:39: undefined: EventDisputeIgnored
FAIL	github.com/ouroboric-dev/gungnir [build failed]
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
```

- [ ] **Step 3:** write the code.

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 082db5f..605d960 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -50,6 +50,10 @@ The contract: Go interface types and JSON schemas for ledger events, `graph.yaml
   (`routing_index_built`, `pointer_contract_checked`) and of dependency checks (`deps_checked`,
   `deps_bump`). A reward of 0 is still written. A refusal has one reason: `retired`, `missing_suite`,
   `brief_changed`, `bad_manifest` or `bad_task`.
+- Defines the ledger fields that `ygg metrics` reads: the event `dispute_ignored`, `ygg.finding.origin` (`check` or
+  `review`) on every finding line, the bench numbers of a measured routing index (`ygg.routing.bench`,
+  `ygg.routing.baseline`, `ygg.routing.threshold`, each from 0 to 1 and written when 0) and the build of ygg that wrote a
+  run (`ygg.factory.version`, on `run_started` and `run_resumed`).
 - Defines the `routing` block of a graph pack's `pack.yaml` (`threshold`, and `bench`, the bench file from
   the project root): the share of bench questions an index must answer right first before it ships. The
   hard approval point `pointer-contract` is in the schema of the gates.
```

Apply to `event.go`:

```diff
diff --git a/event.go b/event.go
index 8d3dc60..3891339 100644
--- a/event.go
+++ b/event.go
@@ -57,6 +57,16 @@ const (
 	EventPointerContractChecked EventName = "pointer_contract_checked" // the pointer-contract gate judged a pointer move
 	EventDepsChecked            EventName = "deps_checked"             // a realm's dependency policy was checked
 	EventDepsBump               EventName = "deps_bump"                // ygg deps bump ran a stage on a product
+
+	EventDisputeIgnored EventName = "dispute_ignored" // an implementer's dispute of a finding could not be used (B-114); Note says why
+)
+
+// FindingOrigin says what raised a finding, so a metric can tell a reviewer's veto from a failed check.
+type FindingOrigin string
+
+const (
+	OriginCheck  FindingOrigin = "check"  // a rung of the check ladder
+	OriginReview FindingOrigin = "review" // one of the loop's reviewers
 )
 
 // Events returns every event name, in the order above.
@@ -69,7 +79,7 @@ func Events() []EventName {
 		EventRetry, EventRunPaused, EventFindingRaised, EventFindingClosed, EventFindingReopened, EventFindingOverruled,
 		EventRealmLoaded, EventDocsPublished, EventTasksReady, EventNodeReturned, EventTaskStarted, EventTaskDone,
 		EventTaskBlocked, EventConformanceChecked, EventGradeStarted, EventGradeFinished, EventGradeRefused,
-		EventRoutingIndexBuilt, EventPointerContractChecked, EventDepsChecked, EventDepsBump}
+		EventRoutingIndexBuilt, EventPointerContractChecked, EventDepsChecked, EventDepsBump, EventDisputeIgnored}
 }
 
 // Event is one ledger line. Fields follow OpenTelemetry's GenAI attribute names (gen_ai.*) where
@@ -113,8 +123,9 @@ type Event struct {
 	RealmVersion    string `json:"ygg.realm.version,omitempty"` // and the version it was loaded at
 	Task            string `json:"ygg.task.id,omitempty"`       // the task a node works for, on every line of its shape
 
-	FindingAttempts int `json:"ygg.finding.attempts,omitempty"` // finding_closed: the loop attempts the finding took to close
-	FindingReopens  int `json:"ygg.finding.reopens,omitempty"`  // finding_closed, finding_reopened: how often it came back
+	FindingOrigin   FindingOrigin `json:"ygg.finding.origin,omitempty"`   // finding_* and dispute_ignored: a check or a reviewer
+	FindingAttempts int           `json:"ygg.finding.attempts,omitempty"` // finding_closed: the loop attempts the finding took to close
+	FindingReopens  int           `json:"ygg.finding.reopens,omitempty"`  // finding_closed, finding_reopened: how often it came back
 
 	// grade_started, grade_finished, grade_refused (Task is the task graded)
 	Suite       string      `json:"ygg.grade.suite,omitempty"`
@@ -131,6 +142,10 @@ type Event struct {
 	Edges     int    `json:"ygg.routing.edges,omitempty"`
 	Extracted int    `json:"ygg.routing.extracted,omitempty"`
 	Inferred  int    `json:"ygg.routing.inferred,omitempty"`
+	// The bench the index was measured by (spec §8.3), when its pack sets one. Pointers, so a score of 0 is written.
+	RoutingBench     *float64 `json:"ygg.routing.bench,omitempty"`     // the index's right-first score, 0 to 1
+	RoutingBaseline  *float64 `json:"ygg.routing.baseline,omitempty"`  // the grep baseline's score on the same questions
+	RoutingThreshold *float64 `json:"ygg.routing.threshold,omitempty"` // the bar the pack sets
 
 	// pointer_contract_checked; Verdict is also deps_checked's and deps_bump's (pass or fail)
 	Move     string `json:"ygg.pointer.move,omitempty"`
@@ -144,6 +159,9 @@ type Event struct {
 	To       string `json:"ygg.deps.to,omitempty"`
 	Stage    string `json:"ygg.deps.stage,omitempty"` // canary or rollout
 
+	// run_started and run_resumed: the build of ygg that wrote the line (spec §10.2: a report records the factory version)
+	FactoryVersion string `json:"ygg.factory.version,omitempty"`
+
 	Prev string `json:"prev"` // hex SHA-256 of the previous line; 64 zeros on the first line
 }
 
```

Apply to `schema/ledger-event.schema.json`:

```diff
diff --git a/schema/ledger-event.schema.json b/schema/ledger-event.schema.json
index 77ce8ab..fad31f8 100644
--- a/schema/ledger-event.schema.json
+++ b/schema/ledger-event.schema.json
@@ -20,7 +20,7 @@
                "repo_created", "sandbox_up", "sandbox_down", "retry", "run_paused", "finding_raised",
                "finding_closed", "finding_reopened", "finding_overruled", "realm_loaded", "docs_published", "tasks_ready",
                "node_returned", "task_started", "task_done", "task_blocked", "conformance_checked", "grade_started", "grade_finished",
-               "grade_refused", "routing_index_built", "pointer_contract_checked", "deps_checked", "deps_bump"]
+               "grade_refused", "routing_index_built", "pointer_contract_checked", "deps_checked", "deps_bump", "dispute_ignored"]
     },
     "ygg.attempt": { "type": "integer", "minimum": 1 },
     "gen_ai.agent.name": { "type": "string" },
@@ -49,6 +49,7 @@
     "ygg.finding.id": { "type": "string", "minLength": 1 },
     "ygg.finding.source": { "type": "string", "minLength": 1 },
     "ygg.finding.severity": { "enum": ["blocker", "major", "minor"] },
+    "ygg.finding.origin": { "enum": ["check", "review"] },
     "ygg.finding.attempts": { "type": "integer", "minimum": 1 },
     "ygg.finding.reopens": { "type": "integer", "minimum": 1 },
     "ygg.grade.suite": { "type": "string", "pattern": "^[a-z0-9][a-z0-9._-]*$" },
@@ -63,6 +64,10 @@
     "ygg.routing.edges": { "type": "integer", "minimum": 1 },
     "ygg.routing.extracted": { "type": "integer", "minimum": 1 },
     "ygg.routing.inferred": { "type": "integer", "minimum": 1 },
+    "ygg.routing.bench": { "type": "number", "minimum": 0, "maximum": 1 },
+    "ygg.routing.baseline": { "type": "number", "minimum": 0, "maximum": 1 },
+    "ygg.routing.threshold": { "type": "number", "minimum": 0, "maximum": 1 },
+    "ygg.factory.version": { "type": "string", "minLength": 1, "maxLength": 200 },
     "ygg.pointer.move": { "type": "string", "minLength": 1 },
     "ygg.pointer.evidence": { "enum": ["extracted", "inferred", "oasdiff"] },
     "ygg.verdict": { "enum": ["pass", "fail", "escalate"] },
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T271: the `Tracker` interface and the board types

Spec §2.2 names a `Tracker` interface "projecting project issues, milestones and the board from factory state" and gives
no method set. The local tracker of v0-T282 needs one, and so does the GitHub tracker of iteration 2. This task writes the
smallest: it returns a board, and a board knows what a valid one is. Same branch as v0-T270.

**Files (in `gungnir`):**

- Create: `tracker.go`, `tracker_test.go`
- Modify: `docs/architecture.md`, `docs_test.go`

**Interfaces:**

- Produces: `gungnir.Column` (`ColumnReady`, `ColumnInProgress`, `ColumnVerifying`, `ColumnBlocked`, `ColumnNeedsYou`,
  `ColumnDone`), `gungnir.Columns()` in reading order, and `Column.Title()` for a terminal board.
- Produces: `gungnir.Card{Task, Title, Leaf string; Column Column; Why, Run string}` and
  `gungnir.Board{Project string; Cards []Card}`, with `Board.Validate() error` (an unknown column, a task without an id, a
  task twice and a blocked card with no reason are errors), `Board.Counts() map[Column]int` (every column has a key) and
  `Board.Summary() string` ("2 done, 1 ready"; "no tasks" for an empty board).
- Produces: `gungnir.Tracker`, with one method: `Board(ctx context.Context) (Board, error)`.

**Acceptance criteria:**

- [ ] `Columns()` lists the six columns of spec §10.3 in reading order, each with a title that is not its identifier.
- [ ] `Validate` refuses the four faults above and accepts a board without them.
- [ ] `Counts` has a key for every column; `Summary` leaves out the empty columns.
- [ ] The architecture page names `Tracker`, `Board`, `Card` and `Column`.

**Named test:** `go test . -run 'TestTheBoardHasSixColumnsInReadingOrder|TestABoardIsRefusedWhenAColumnIsUnknownOrATaskRepeats|TestCountsByColumnNameEveryColumn|TestTheArchitecturePageNamesTheTrackerAndTheBoard'`
in `gungnir`. **Layer:** `gungnir`. **Size:** M (179). **Depends on:** Phase 5c merged.

- [ ] **Step 1:** write the tests.

Apply to `docs_test.go`:

```diff
diff --git a/docs_test.go b/docs_test.go
index 52e3779..93cb98a 100644
--- a/docs_test.go
+++ b/docs_test.go
@@ -58,3 +58,15 @@ func TestTheArchitecturePageNamesWhatMetricsReads(t *testing.T) {
 		}
 	}
 }
+
+func TestTheArchitecturePageNamesTheTrackerAndTheBoard(t *testing.T) {
+	b, err := os.ReadFile(filepath.Join("docs", "architecture.md"))
+	if err != nil {
+		t.Fatal(err)
+	}
+	for _, want := range []string{"`Tracker`", "`Board`", "`Card`", "`Column`"} {
+		if !strings.Contains(string(b), want) {
+			t.Errorf("docs/architecture.md does not mention %q", want)
+		}
+	}
+}
```

Write `tracker_test.go`:

```go
package gungnir

import (
	"slices"
	"strings"
	"testing"
)

func TestTheBoardHasSixColumnsInReadingOrder(t *testing.T) {
	got := Columns()
	want := []Column{ColumnReady, ColumnInProgress, ColumnVerifying, ColumnBlocked, ColumnNeedsYou, ColumnDone}
	if !slices.Equal(got, want) {
		t.Fatalf("Columns() = %v, want %v", got, want)
	}
	for _, c := range got {
		if c.Title() == "" || c.Title() == string(c) {
			t.Errorf("column %q has no title for a terminal board: %q", c, c.Title())
		}
	}
}

func TestABoardIsRefusedWhenAColumnIsUnknownOrATaskRepeats(t *testing.T) {
	ok := Board{Project: "/p", Cards: []Card{{Task: "v-T1", Column: ColumnDone}, {Task: "v-T2", Column: ColumnBlocked, Why: "attempts exhausted"}}}
	if err := ok.Validate(); err != nil {
		t.Fatalf("Validate() = %v", err)
	}
	for name, b := range map[string]Board{
		"an unknown column":             {Cards: []Card{{Task: "v-T1", Column: "doing"}}},
		"a task without an id":          {Cards: []Card{{Column: ColumnReady}}},
		"a task twice":                  {Cards: []Card{{Task: "v-T1", Column: ColumnReady}, {Task: "v-T1", Column: ColumnDone}}},
		"a blocked card with no reason": {Cards: []Card{{Task: "v-T1", Column: ColumnBlocked}}},
	} {
		if err := b.Validate(); err == nil {
			t.Errorf("%s: Validate() = nil", name)
		}
	}
}

func TestCountsByColumnNameEveryColumn(t *testing.T) {
	b := Board{Cards: []Card{{Task: "a", Column: ColumnDone}, {Task: "b", Column: ColumnDone}, {Task: "c", Column: ColumnReady}}}
	got := b.Counts()
	if got[ColumnDone] != 2 || got[ColumnReady] != 1 || len(got) != 6 {
		t.Errorf("Counts() = %v, want done 2, ready 1 and six keys", got)
	}
	if line := b.Summary(); !strings.Contains(line, "2 done") || !strings.Contains(line, "1 ready") {
		t.Errorf("Summary() = %q", line)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./tracker_test.go:10:9: undefined: Columns
./tracker_test.go:11:12: undefined: Column
./tracker_test.go:11:19: undefined: ColumnReady
```

- [ ] **Step 3:** write the code.

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 605d960..cb2bc57 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -50,6 +50,8 @@ The contract: Go interface types and JSON schemas for ledger events, `graph.yaml
   (`routing_index_built`, `pointer_contract_checked`) and of dependency checks (`deps_checked`,
   `deps_bump`). A reward of 0 is still written. A refusal has one reason: `retired`, `missing_suite`,
   `brief_changed`, `bad_manifest` or `bad_task`.
+- Defines `Tracker`, and the `Board`, `Card` and `Column` it returns: six columns in reading order, a board that is
+  checked (no unknown column, no task twice, a blocked card says why).
 - Defines the ledger fields that `ygg metrics` reads: the event `dispute_ignored`, `ygg.finding.origin` (`check` or
   `review`) on every finding line, the bench numbers of a measured routing index (`ygg.routing.bench`,
   `ygg.routing.baseline`, `ygg.routing.threshold`, each from 0 to 1 and written when 0) and the build of ygg that wrote a
```

Write `tracker.go`:

```go
package gungnir

import (
	"context"
	"errors"
	"fmt"
	"slices"
	"strings"
)

// Column is where a task stands on the board (spec §10.3).
type Column string

const (
	ColumnReady      Column = "ready"       // todo: planned, not started
	ColumnInProgress Column = "in-progress" // an agent is implementing or reviewing it
	ColumnVerifying  Column = "verifying"   // built; the checks, the merge or the acceptance run are judging it
	ColumnBlocked    Column = "blocked"     // given up, or waiting on a task that was
	ColumnNeedsYou   Column = "needs-you"   // a person's approval or ruling is the only thing it waits for
	ColumnDone       Column = "done"
)

// Columns lists the board's columns in reading order.
func Columns() []Column {
	return []Column{ColumnReady, ColumnInProgress, ColumnVerifying, ColumnBlocked, ColumnNeedsYou, ColumnDone}
}

// Title is the column's heading on a terminal board.
func (c Column) Title() string {
	switch c {
	case ColumnReady:
		return "Ready"
	case ColumnInProgress:
		return "In progress"
	case ColumnVerifying:
		return "Verifying"
	case ColumnBlocked:
		return "Blocked"
	case ColumnNeedsYou:
		return "Needs you"
	case ColumnDone:
		return "Done"
	}
	return string(c)
}

// Card is one task on the board.
type Card struct {
	Task   string // the task's id in features.json
	Title  string
	Leaf   string // the leaf that holds the work, by path in the project
	Column Column
	Why    string // blocked: what stopped it; needs-you: what waits for the person
	Run    string // the run that last touched the task
}

// Board is a project's tasks by column, as a tracker projects them (spec §10.4).
type Board struct {
	Project string
	Cards   []Card
}

// Validate refuses a board with an unknown column, a task without an id or listed twice, or a blocked card
// that does not say why.
func (b Board) Validate() error {
	var errs []error
	seen := map[string]bool{}
	for _, c := range b.Cards {
		switch {
		case c.Task == "":
			errs = append(errs, errors.New("a card has no task id"))
		case seen[c.Task]:
			errs = append(errs, fmt.Errorf("task %s is on the board twice", c.Task))
		}
		seen[c.Task] = true
		if !slices.Contains(Columns(), c.Column) {
			errs = append(errs, fmt.Errorf("task %s is in the unknown column %q", c.Task, c.Column))
		}
		if c.Column == ColumnBlocked && c.Why == "" {
			errs = append(errs, fmt.Errorf("task %s is blocked and says nothing about why", c.Task))
		}
	}
	return errors.Join(errs...)
}

// Counts is how many cards each column holds; every column has a key.
func (b Board) Counts() map[Column]int {
	out := map[Column]int{}
	for _, c := range Columns() {
		out[c] = 0
	}
	for _, c := range b.Cards {
		out[c.Column]++
	}
	return out
}

// Summary is the counts on one line, such as "2 done, 1 ready".
func (b Board) Summary() string {
	n := b.Counts()
	var parts []string
	for _, c := range Columns() {
		if n[c] > 0 {
			parts = append(parts, fmt.Sprintf("%d %s", n[c], strings.ReplaceAll(string(c), "-", " ")))
		}
	}
	if len(parts) == 0 {
		return "no tasks"
	}
	return strings.Join(parts, ", ")
}

// Tracker projects the factory's state one way, into a board (spec §10.4). Odin is its only writer; an agent
// never touches it. The local tracker reads features.json and the ledger; the GitHub tracker is iteration 2.
type Tracker interface {
	Board(ctx context.Context) (Board, error)
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T288: `Usage.BilledUSD`, so the dollar caps count what was billed

Spec §7.4 gives the caps "in tokens and turns (dollars on the API)". `Cap.Reached` counts dollars whenever any role pays per
token, and then counts the cost figure of every session, including the figure of a Claude Code session, which is what the
session would cost on the API and which the subscription does not charge. A config with Claude Code for the planner and the
implementer and OpenCode for the reviewers pays per token, so its `per_run.usd` would be used up by the subscription's
estimate: at the smoke's rate of about $0.03 a turn, in about 170 turns. A gallery run is expected to take many more
(question 3). This task gives `Usage` the part that was billed, and `Reached` counts that. The engine sets it in v0-T289.
Same branch as v0-T270.

**Files (in `gungnir`):**

- Create: `usage_billed_test.go`
- Modify: `agent.go`, `docs/architecture.md`, `docs_test.go`, `schema/factory.go`, `schema/factory_test.go`

**Interfaces:**

- Produces: `gungnir.Usage.BilledUSD float64` (JSON `billed_usd`, left out when 0): the part of `CostUSD` that an adapter
  bills to a paid API (`schema.PaidAPI`). `Usage.Add` sums it. A usage that says nothing of billing bills nothing.
- Changes: `schema.Cap.Reached` compares the dollar cap with `u.BilledUSD`, and only when `usd` is true.

**Acceptance criteria:**

- [ ] `Usage{CostUSD: 23, BilledUSD: 0.6}` does not reach a $5 cap on a config that pays per token, and
      `Usage{CostUSD: 23, BilledUSD: 2.5}` reaches a $2 cap, with the billed figure as what was used.
- [ ] `Add` sums both fields. The existing cap cases still hold when their usage names what was billed.
- [ ] The architecture page names `Usage.BilledUSD` and says what the dollar caps count.

**Review focus pinned by tests:** an estimate is not spend (`TestCapReached`, the two new cases);
`TestUsageAddsWhatWasBilledAndKeepsItApartFromTheCost`.

**Named test:** `go test . ./schema -run 'TestCapReached|TestUsageAddsWhatWasBilledAndKeepsItApartFromTheCost|TestTheArchitecturePageSaysWhatTheDollarCapsCount'`
in `gungnir`. **Layer:** `gungnir`. **Size:** S (41). **Depends on:** Phase 5c merged.

- [ ] **Step 1:** write the tests.

Apply to `docs_test.go`:

```diff
diff --git a/docs_test.go b/docs_test.go
index 93cb98a..45b1a5a 100644
--- a/docs_test.go
+++ b/docs_test.go
@@ -70,3 +70,13 @@ func TestTheArchitecturePageNamesTheTrackerAndTheBoard(t *testing.T) {
 		}
 	}
 }
+
+func TestTheArchitecturePageSaysWhatTheDollarCapsCount(t *testing.T) {
+	b, err := os.ReadFile(filepath.Join("docs", "architecture.md"))
+	if err != nil {
+		t.Fatal(err)
+	}
+	if !strings.Contains(string(b), "`Usage.BilledUSD`") {
+		t.Error("docs/architecture.md does not mention `Usage.BilledUSD`")
+	}
+}
```

Apply to `schema/factory_test.go`:

```diff
diff --git a/schema/factory_test.go b/schema/factory_test.go
index 0e96c78..c8473e9 100644
--- a/schema/factory_test.go
+++ b/schema/factory_test.go
@@ -169,11 +169,15 @@ func TestCapReached(t *testing.T) {
 		usd  bool
 		want gungnir.CapDimension // "" for no cap reached
 	}{
-		{"room left", gungnir.Usage{InTok: 400, OutTok: 500, Turns: 9, CostUSD: 1.99}, true, ""},
+		{"room left", gungnir.Usage{InTok: 400, OutTok: 500, Turns: 9, CostUSD: 1.99, BilledUSD: 1.99}, true, ""},
 		{"tokens exactly at the cap", gungnir.Usage{InTok: 600, OutTok: 400}, true, gungnir.CapTokens},
 		{"cache reads don't count", gungnir.Usage{InTok: 1, CacheTok: 1 << 40}, true, ""},
 		{"turns at the cap", gungnir.Usage{Turns: 10}, true, gungnir.CapTurns},
-		{"dollars at the cap on a paid API", gungnir.Usage{CostUSD: 2}, true, gungnir.CapUSD},
+		{"dollars at the cap on a paid API", gungnir.Usage{CostUSD: 2, BilledUSD: 2}, true, gungnir.CapUSD},
+		// A config with one paid role and one subscription role counts dollars; the subscription's figure is
+		// what its sessions would cost on the API, and nobody bills it.
+		{"a subscription's estimate beside a paid role is not spend", gungnir.Usage{CostUSD: 23, BilledUSD: 0.6}, true, ""},
+		{"what a paid role was billed is spend", gungnir.Usage{CostUSD: 23, BilledUSD: 2.5}, true, gungnir.CapUSD},
 		{"dollars of a subscription never count", gungnir.Usage{CostUSD: 500}, false, ""},
 	}
 	for _, tc := range cases {
```

Write `usage_billed_test.go`:

```go
package gungnir

import "testing"

func TestUsageAddsWhatWasBilledAndKeepsItApartFromTheCost(t *testing.T) {
	a := Usage{CostUSD: 1.5, BilledUSD: 0.5, Turns: 2}
	b := Usage{CostUSD: 0.25, BilledUSD: 0.25, Turns: 1}
	got := a.Add(b)
	if got.CostUSD != 1.75 || got.BilledUSD != 0.75 || got.Turns != 3 {
		t.Errorf("Add() = %+v; want cost 1.75, billed 0.75, 3 turns", got)
	}
	if (Usage{CostUSD: 3}).BilledUSD != 0 {
		t.Error("a usage that says nothing of billing must not count its cost as billed")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./usage_billed_test.go:6:27: unknown field BilledUSD in struct literal of type Usage
./usage_billed_test.go:7:28: unknown field BilledUSD in struct literal of type Usage
./usage_billed_test.go:9:32: got.BilledUSD undefined (type Usage has no field or method BilledUSD)
```

- [ ] **Step 3:** write the code.

Apply to `agent.go`:

```diff
diff --git a/agent.go b/agent.go
index 148fe8b..98869d4 100644
--- a/agent.go
+++ b/agent.go
@@ -48,6 +48,9 @@ type Usage struct {
 	Turns         int64   `json:"turns"`
 	CostUSD       float64 `json:"cost_usd"`
 	CostEstimated bool    `json:"cost_estimated"`
+	// BilledUSD is the part of CostUSD that an adapter bills to a paid API (see schema.PaidAPI). A subscription's
+	// sessions have a cost figure, what they would cost on the API, and bill nothing. The dollar caps count this.
+	BilledUSD float64 `json:"billed_usd,omitempty"`
 }
 
 // Add returns the sum of u and v. The sum is estimated if either part is.
@@ -59,6 +62,7 @@ func (u Usage) Add(v Usage) Usage {
 		Turns:         u.Turns + v.Turns,
 		CostUSD:       u.CostUSD + v.CostUSD,
 		CostEstimated: u.CostEstimated || v.CostEstimated,
+		BilledUSD:     u.BilledUSD + v.BilledUSD,
 	}
 }
 
```

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index cb2bc57..8652264 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -50,6 +50,8 @@ The contract: Go interface types and JSON schemas for ledger events, `graph.yaml
   (`routing_index_built`, `pointer_contract_checked`) and of dependency checks (`deps_checked`,
   `deps_bump`). A reward of 0 is still written. A refusal has one reason: `retired`, `missing_suite`,
   `brief_changed`, `bad_manifest` or `bad_task`.
+- Defines `Usage.BilledUSD`, the part of a session's cost that a paid API bills. The dollar caps count it, and not the
+  cost figure of a subscription's sessions, which is what they would cost on the API and which nobody charges.
 - Defines `Tracker`, and the `Board`, `Card` and `Column` it returns: six columns in reading order, a board that is
   checked (no unknown column, no task twice, a blocked card says why).
 - Defines the ledger fields that `ygg metrics` reads: the event `dispute_ignored`, `ygg.finding.origin` (`check` or
```

Apply to `schema/factory.go`:

```diff
diff --git a/schema/factory.go b/schema/factory.go
index 84e0580..dc46165 100644
--- a/schema/factory.go
+++ b/schema/factory.go
@@ -98,15 +98,16 @@ type Cap struct {
 
 // Reached returns the first limit of c that u has reached, or nil. A limit is reached when use equals
 // it, so a cap of zero stops everything. Dollars count only when usd is true, which is when a role
-// bills a paid API (see PaidAPI): a subscription's dollar figure is what the run would cost on the API.
+// bills a paid API (see PaidAPI), and then only what was billed (Usage.BilledUSD): a subscription's dollar
+// figure is what its sessions would cost on the API, and nobody charges it.
 func (c Cap) Reached(scope gungnir.CapScope, u gungnir.Usage, usd bool) *gungnir.CapError {
 	switch {
 	case u.CapTokens() >= c.Tokens:
 		return &gungnir.CapError{Scope: scope, Dimension: gungnir.CapTokens, Used: float64(u.CapTokens()), Limit: float64(c.Tokens)}
 	case u.Turns >= c.Turns:
 		return &gungnir.CapError{Scope: scope, Dimension: gungnir.CapTurns, Used: float64(u.Turns), Limit: float64(c.Turns)}
-	case usd && u.CostUSD >= c.USD:
-		return &gungnir.CapError{Scope: scope, Dimension: gungnir.CapUSD, Used: u.CostUSD, Limit: c.USD}
+	case usd && u.BilledUSD >= c.USD:
+		return &gungnir.CapError{Scope: scope, Dimension: gungnir.CapUSD, Used: u.BilledUSD, Limit: c.USD}
 	}
 	return nil
 }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T289: the engine bills only a paid adapter's sessions

The other half of v0-T288, and Odin's first task of Phase 6. Branch `phase-6/observability` from `main` in `odin`, before
step 1; develop against `gungnir`'s Phase 6 branch through `go.work`. It comes first because, with the new `gungnir`, the meter's
old test of the dollar cap fails until this task lands. The engine knows the role's adapter where a session's usage is spent,
and marks the part of the cost that a paid adapter bills; the meter's warning and `ygg status` count that part.

**Files (in `odin`):**

- Create: `internal/engine/billed_test.go`
- Modify: `README.md`, `docs/architecture.md`, `internal/budget/meter.go`, `internal/budget/meter_test.go`, `internal/cli/cli.go`, `internal/cli/docs_test.go`, `internal/engine/session.go`

**Interfaces:**

- Produces: `engine.billed(adapter string, u gungnir.Usage) gungnir.Usage`: `BilledUSD` is the cost when `schema.PaidAPI(adapter)`
  and 0 otherwise (`claude-code` and `scripted` are not paid; a new adapter is, until it is listed).
- Changes: `Run.Spend` receives the billed usage; `budget.Meter.Near` warns of a dollar cap by the billed figure;
  `ygg status` writes "$X billed of $Y".

**Acceptance criteria:**

- [ ] `billed("opencode", …)` and an unknown adapter bill the cost; `claude-code` and `scripted` bill nothing; the rest of the
      usage is unchanged.
- [ ] A run with $4.50 of cost at API prices and $0.50 billed is under a $5 cap, gets no warning of the dollar cap, and one
      with $5 billed reaches it with $5 as what was used.
- [ ] The README says what the dollar caps count.

**Review focus pinned by tests:** `TestTheDollarCapStopsOnWhatWasBilledNotOnASubscriptionsEstimate` (the warning and the check).

**Named test:** `go test ./internal/engine ./internal/budget ./internal/cli -run 'TestOnlyASessionOfAPaidAdapterIsBilled|TestTheDollarCapStopsOnWhatWasBilledNotOnASubscriptionsEstimate|TestTheDollarCapCountsOnlyForAPaidAPI|TestNearListsTheCapsOverEightyPercentAndNotYetReached|TestTheDocsNameEveryCommand'`
in `odin`. **Layer:** `odin`. **Size:** S (63). **Depends on:** v0-T288.

- [ ] **Step 1:** write the tests.

Apply to `internal/budget/meter_test.go`:

```diff
diff --git a/internal/budget/meter_test.go b/internal/budget/meter_test.go
index 779b212..6cfad52 100644
--- a/internal/budget/meter_test.go
+++ b/internal/budget/meter_test.go
@@ -38,7 +38,7 @@ func TestTheMeterStopsAtTheRunsCapThenTheDays(t *testing.T) {
 }
 
 func TestTheDollarCapCountsOnlyForAPaidAPI(t *testing.T) {
-	run := &gungnir.Usage{CostUSD: 5}
+	run := &gungnir.Usage{CostUSD: 5, BilledUSD: 5}
 	m, _ := meter(t, run, false)
 	if hit := m.Check(); hit != nil {
 		t.Errorf("Check() = %v; a subscription's dollars are only a figure", hit)
@@ -83,7 +83,7 @@ func TestTheTurnsLeftAreTheLesserOfTheRunsAndTheDays(t *testing.T) {
 }
 
 func TestNearListsTheCapsOverEightyPercentAndNotYetReached(t *testing.T) {
-	run := &gungnir.Usage{InTok: 850, Turns: 10, CostUSD: 4.5}
+	run := &gungnir.Usage{InTok: 850, Turns: 10, CostUSD: 4.5, BilledUSD: 4.5}
 	m, _ := meter(t, run, true)
 	var got []string
 	for _, n := range m.Near(0.8) {
@@ -97,3 +97,20 @@ func TestNearListsTheCapsOverEightyPercentAndNotYetReached(t *testing.T) {
 		t.Errorf("Near() = %+v without dollars", n)
 	}
 }
+
+// A config with a subscription role and a paid role counts dollars. The subscription's sessions have a cost
+// figure (what they would cost on the API) and bill nothing, so only what the paid role was billed counts.
+func TestTheDollarCapStopsOnWhatWasBilledNotOnASubscriptionsEstimate(t *testing.T) {
+	run := &gungnir.Usage{CostUSD: 4.5, CostEstimated: true, BilledUSD: 0.5}
+	m, _ := meter(t, run, true)
+	if hit := m.Check(); hit != nil {
+		t.Errorf("Check() = %v; $4.50 of cost figure and $0.50 billed is under a $5 cap", hit)
+	}
+	if near := m.Near(0.8); len(near) != 0 && near[0].Dimension == gungnir.CapUSD {
+		t.Errorf("Near() = %v; the estimate must not warn of a dollar cap", near)
+	}
+	run.BilledUSD = 5
+	if hit := m.Check(); hit == nil || hit.Dimension != gungnir.CapUSD || hit.Used != 5 {
+		t.Errorf("Check() = %v; want the dollar cap, with the billed $5 as what was used", hit)
+	}
+}
```

Apply to `internal/cli/docs_test.go`:

```diff
diff --git a/internal/cli/docs_test.go b/internal/cli/docs_test.go
index bbd258d..6f84ce8 100644
--- a/internal/cli/docs_test.go
+++ b/internal/cli/docs_test.go
@@ -36,3 +36,14 @@ func TestTheDocsNameEveryCommand(t *testing.T) {
 		}
 	}
 }
+
+// The architecture page says what the dollar caps count.
+func TestTheDocsSayWhatTheDollarCapsCount(t *testing.T) {
+	arch, err := os.ReadFile(filepath.Join("..", "..", "docs", "architecture.md"))
+	if err != nil {
+		t.Fatal(err)
+	}
+	if !strings.Contains(string(arch), "Usage.BilledUSD") {
+		t.Error("docs/architecture.md does not mention Usage.BilledUSD")
+	}
+}
```

Write `internal/engine/billed_test.go`:

```go
package engine

import (
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func TestOnlyASessionOfAPaidAdapterIsBilled(t *testing.T) {
	u := gungnir.Usage{InTok: 100, CostUSD: 0.30, CostEstimated: true}
	for adapter, want := range map[string]float64{"opencode": 0.30, "claude-code": 0, "scripted": 0, "a-new-adapter": 0.30} {
		if got := billed(adapter, u); got.BilledUSD != want || got.CostUSD != 0.30 || got.InTok != 100 {
			t.Errorf("billed(%q) = %+v; want BilledUSD %v and the rest as it was", adapter, got, want)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/billed_test.go:12:13: undefined: billed
--- FAIL: TestTheDollarCapStopsOnWhatWasBilledNotOnASubscriptionsEstimate (0.00s)
    meter_test.go:110: Near() = [{run usd 4.5 5 }]; the estimate must not warn of a dollar cap
```

- [ ] **Step 3:** write the code.

Apply to `README.md`:

```diff
diff --git a/README.md b/README.md
index bdcc89c..98d7a91 100644
--- a/README.md
+++ b/README.md
@@ -32,6 +32,9 @@ used up), 5 done with tasks given up (unattended).
 
 `factory.yaml` must set both budget caps, `per_run` and `per_day`, each with `tokens` and `turns`.
 The factory ships no defaults, so a config without them runs nothing.
+When any role bills a paid API (an OpenCode role), the caps also count dollars, and they count what the API billed. The
+cost figure of a Claude Code session is what it would cost on the API; the subscription charges nothing for it, so it does
+not count against `usd`. `ygg status` and `ygg metrics` show both.
 
 `ygg deps bump` runs the package manager and the checks in the sandbox of `factory.yaml`. Without a `sandbox:`
 section it refuses (exit 2) unless you pass `--host`, which runs the bump on the host with the full network and
```

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 27494d8..df6b53f 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -13,6 +13,8 @@ The orchestrator: the graph engine and the `ygg` CLI, with routing and the ledge
 ## Responsibilities
 
 - Loads the graph pack and `factory.yaml`.
+- Counts the budget caps. The dollar caps count `Usage.BilledUSD`, which the engine sets for a session of a paid adapter
+  (`billed`), and not the session's cost figure: a subscription's sessions have a figure and bill nothing.
 - Walks the graph and runs exec, agent, loop, gate and grade nodes; checkpoints runs and resumes them. A
   loop node is Jormungandr's loop with Odin's steps: sessions, checks, ledger lines and `run.json`.
 - Loads the graph pack and the realm leaves (change realm-leaf-naming, Voluspa): `--graph` names the
```

Apply to `internal/budget/meter.go`:

```diff
diff --git a/internal/budget/meter.go b/internal/budget/meter.go
index 30f80f2..16bc6ac 100644
--- a/internal/budget/meter.go
+++ b/internal/budget/meter.go
@@ -67,7 +67,7 @@ func (m *Meter) Near(frac float64) []gungnir.CapError {
 			{Scope: s.scope, Dimension: gungnir.CapTurns, Used: float64(s.use.Turns), Limit: float64(s.cap.Turns)},
 		}
 		if m.USD {
-			dims = append(dims, gungnir.CapError{Scope: s.scope, Dimension: gungnir.CapUSD, Used: s.use.CostUSD, Limit: s.cap.USD})
+			dims = append(dims, gungnir.CapError{Scope: s.scope, Dimension: gungnir.CapUSD, Used: s.use.BilledUSD, Limit: s.cap.USD})
 		}
 		for _, d := range dims {
 			if d.Limit > 0 && d.Used >= frac*d.Limit && d.Used < d.Limit {
```

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index b3d0e48..ecacdc5 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -393,7 +393,7 @@ func describeCaps(cfg *schema.Factory, runUse, dayUse gungnir.Usage) string {
 	one := func(c schema.Cap, u gungnir.Usage) string {
 		out := fmt.Sprintf("%d of %d tokens, %d of %d turns", u.CapTokens(), c.Tokens, u.Turns, c.Turns)
 		if cfg.PaysPerToken() {
-			out += fmt.Sprintf(", $%.4f of $%.4f", u.CostUSD, c.USD)
+			out += fmt.Sprintf(", $%.4f billed of $%.4f", u.BilledUSD, c.USD)
 		}
 		return out
 	}
```

Apply to `internal/engine/session.go`:

```diff
diff --git a/internal/engine/session.go b/internal/engine/session.go
index ea9c19b..3fb47ea 100644
--- a/internal/engine/session.go
+++ b/internal/engine/session.go
@@ -126,7 +126,7 @@ func session(ctx context.Context, r *run.Run, sp sessionSpec) (gungnir.Result, g
 		case errors.As(runErr, &se):
 			spent = se.Usage
 		}
-		if err := r.Spend(sp.key, spent); err != nil {
+		if err := r.Spend(sp.key, billed(role.Agent, spent)); err != nil {
 			// The journal can't record the spend, so the run stops at budget-cap (review I4). The leaf goes
 			// back to its checkpoint first, as for a retry, so a resume or an approval doesn't refuse it as
 			// changed while the run waited.
@@ -262,3 +262,12 @@ func warnBudget(r *run.Run, node string) error {
 	}
 	return nil
 }
+
+// billed marks the part of a session's cost that its adapter bills to a paid API, which is what the dollar caps
+// count (spec §7.4). A subscription's session has a cost figure, what it would cost on the API, and bills nothing.
+func billed(adapter string, u gungnir.Usage) gungnir.Usage {
+	if schema.PaidAPI(adapter) {
+		u.BilledUSD = u.CostUSD
+	}
+	return u
+}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T272: the engine writes the new fields, and a run records the build of ygg

The ledger fields of v0-T270 must come from the engine, and a run must say
which build of `ygg` made it, so that a number quoted later "can be traced back to the exact setup that produced it"
(spec §10.2). Same branch as v0-T289. The build is read from the binary's build info: the commit of `odin` and the commits that `gungnir`,
`gleipnir`, `jormungandr` and `havamal` were pinned at.

**Files (in `odin`):**

- Create: `internal/engine/ledger_fields_test.go`, `internal/run/factory_test.go`, `internal/version/version.go`, `internal/version/version_test.go`
- Modify: `internal/cli/cli.go`, `internal/engine/loop.go`, `internal/engine/routing.go`, `internal/routing/bench.go`, `internal/run/run.go`, `internal/run/state.go`

**Interfaces:**

- Produces: `version.Factory() string` and `version.Describe(*debug.BuildInfo) string`: `odin <12 characters>` and each
  sibling as `<name> <12 characters>`, in that order. `+dirty` follows the commit of a build with uncommitted changes;
  `local` stands for a module that was replaced or built from a workspace; a build with no commit says `odin unknown`.
  The result is cut at 200 characters, the ledger schema's bound.
- Produces: `run.State.Factory string` (`factory` in `run.json`), set when a run starts; `(*run.Run).Resumed(note string)
  error`, which logs `run_resumed` with the build that resumes the run. `run_started` carries the build too.
- Changes: the engine writes `FindingOrigin` on every finding line (`review` when the finding's source is one of the loop's
  reviewers, `check` otherwise); an ignored dispute is a `dispute_ignored` line whose note says why, not a `loop_attempt`
  line with text; `routing_index_built` carries `RoutingBench`, `RoutingBaseline` and `RoutingThreshold` when the pack's
  `routing` block measured the index, and none when it did not (`routing.Measure` holds the three).

**Acceptance criteria:**

- [ ] `Describe` names the commit and the siblings' commits from the build info, marks a dirty or local build, never
      exceeds 200 characters, and says `odin unknown` for a build with no recorded commit.
- [ ] `run.json` records the build, and `run_started` and `run_resumed` name it.
- [ ] A finding raised by a reviewer says `review`, one raised by a check says `check`; every finding line has an origin.
- [ ] An ignored dispute is a `dispute_ignored` line; the old text is still in its note.
- [ ] A measured index writes its bench numbers (a score of 1 is written as 1); an index shipped unmeasured writes none.

**Named test:** `go test ./internal/version ./internal/run ./internal/engine -run 'TestTheFactoryVersionNamesTheCommitsItWasBuiltFrom|TestADirtyOrLocalBuildSaysSoBecauseItCannotBeRepeated|TestABuildWithNoRecordedCommitStillHasAVersionOfBoundedLength|TestARunRecordsTheBuildOfYggThatStartedAndResumedIt|TestTheLedgerSaysWhetherACheckOrAReviewerRaisedAFinding|TestACheckFindingHasTheOriginCheck|TestAnIgnoredDisputeIsADisputeIgnoredEventNotALoopAttemptWithText|TestTheLedgerKeepsTheBenchScoreAsNumbersAndAnUnmeasuredIndexCarriesNone|TestAMalformedDisputeIsIgnoredWithALedgerLine'`
in `odin`. **Layer:** `odin`. **Size:** M (285). **Depends on:** v0-T270.

- [ ] **Step 1:** write the tests.

Write `internal/engine/ledger_fields_test.go`:

```go
package engine

import (
	"context"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/run"
)

// Spec §10.2 counts a reviewer's veto and an ignored dispute. The ledger names which raised a finding, and a
// dispute that could not be used has an event of its own, so ygg metrics reads fields and parses no text.
func TestTheLedgerSaysWhetherACheckOrAReviewerRaisedAFinding(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n" +
		"    - actions: [ " + write("build.txt", "done again") + " ]\n      result: { status: ok }\n" +
		"  build-spec:\n    - result: { status: ok, report: [ " + majorFinding + " ] }\n" +
		"    - result: { status: ok, report: [ " + fixedFinding("build.txt:1 now says what the brief asks; check unit passed") + " ] }\n"
	r := startReview(t, "key-points", script)
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	text := ledgerText(t, r)
	for _, want := range []string{
		`"event":"finding_raised"`, `"ygg.finding.source":"spec"`, `"ygg.finding.origin":"review"`,
		`"event":"finding_closed"`,
	} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s:\n%s", want, text)
		}
	}
	for _, line := range strings.Split(text, "\n") {
		if strings.Contains(line, `"event":"finding_`) && !strings.Contains(line, `"ygg.finding.origin":"`) {
			t.Errorf("a finding line names no origin:\n%s", line)
		}
	}
}

func TestACheckFindingHasTheOriginCheck(t *testing.T) {
	script := "steps:\n  build:\n    - actions: [ " + write("build.txt", "todo") + " ]\n      result: { status: ok }\n" +
		"    - actions: [ " + write("build.txt", "done") + " ]\n      result: { status: ok }\n"
	r := startLoop(t, "key-points", script)
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if text := ledgerText(t, r); !strings.Contains(text, `"ygg.finding.id":"check-unit"`) || !strings.Contains(text, `"ygg.finding.origin":"check"`) {
		t.Errorf("the check finding names no origin:\n%s", text)
	}
}

func TestAnIgnoredDisputeIsADisputeIgnoredEventNotALoopAttemptWithText(t *testing.T) {
	r := startDispute(t, disputeScript(`'{"disputes": [{"id": "spec-1"}]}'`, 2))
	Advance(context.Background(), r) //nolint:errcheck // the run's end is not what this test reads
	text := ledgerText(t, r)
	if !strings.Contains(text, `"event":"dispute_ignored"`) || !strings.Contains(text, `"ygg.note":"dispute ignored: `) {
		t.Errorf("the ledger has no dispute_ignored line that says why:\n%s", text)
	}
	if strings.Contains(text, `"ygg.result":"dispute ignored`) {
		t.Errorf("the dispute is still written as a loop_attempt with text:\n%s", text)
	}
}

func TestTheLedgerKeepsTheBenchScoreAsNumbersAndAnUnmeasuredIndexCarriesNone(t *testing.T) {
	r := startPack(t, "key-points", "", benchPack, shipNodes, goModScript)
	writeBench(t, r, rightBench)
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	text := ledgerText(t, r)
	for _, want := range []string{`"event":"routing_index_built"`, `"ygg.routing.bench":1`, `"ygg.routing.threshold":0.8`, `"ygg.routing.baseline":`} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s:\n%s", want, text)
		}
	}
	plain := startPack(t, "key-points", "", packChecks, shipNodes, goModScript)
	if out, err := Advance(bg, plain); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if text := ledgerText(t, plain); !strings.Contains(text, `"event":"routing_index_built"`) || strings.Contains(text, `"ygg.routing.bench"`) {
		t.Errorf("an index shipped unmeasured must say no score:\n%s", text)
	}
}
```

Write `internal/run/factory_test.go`:

```go
package run

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/tree/treetest"
	"github.com/ouroboric-dev/odin/internal/version"
)

func TestARunRecordsTheBuildOfYggThatStartedAndResumedIt(t *testing.T) {
	project := treetest.Project(t, "repos/app")
	realm := t.TempDir()
	if err := os.CopyFS(realm, os.DirFS(toy(t))); err != nil {
		t.Fatal(err)
	}
	r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Graph: realm})
	if err != nil {
		t.Fatal(err)
	}
	r.Close()
	want := version.Factory()
	if r.State.Factory != want {
		t.Errorf("State.Factory = %q, want %q", r.State.Factory, want)
	}
	again, err := Open(ctx, project, r.State.ID, "")
	if err != nil {
		t.Fatal(err)
	}
	if err := again.Resumed("a test"); err != nil {
		t.Fatal(err)
	}
	again.Close()
	b, _ := os.ReadFile(filepath.Join(Dir(project, r.State.ID), "ledger.jsonl"))
	line := `"ygg.factory.version":"` + want + `"`
	if n := strings.Count(string(b), line); n != 2 {
		t.Errorf("the ledger names the build %d times, want 2 (run_started and run_resumed):\n%s", n, b)
	}
	state, _ := os.ReadFile(filepath.Join(Dir(project, r.State.ID), "run.json"))
	if !strings.Contains(string(state), `"factory": "`+want+`"`) {
		t.Errorf("run.json does not record the build:\n%s", state)
	}
}
```

Write `internal/version/version_test.go`:

```go
package version

import (
	"runtime/debug"
	"strings"
	"testing"
)

func info(settings map[string]string, deps ...*debug.Module) *debug.BuildInfo {
	bi := &debug.BuildInfo{Deps: deps}
	for k, v := range settings {
		bi.Settings = append(bi.Settings, debug.BuildSetting{Key: k, Value: v})
	}
	return bi
}

func TestTheFactoryVersionNamesTheCommitsItWasBuiltFrom(t *testing.T) {
	bi := info(map[string]string{"vcs.revision": "b8c9716fa8180123456789abcdef0123456789ab", "vcs.modified": "false"},
		&debug.Module{Path: "github.com/ouroboric-dev/gleipnir", Version: "v0.0.0-20261022013122-6b6f83eec777"},
		&debug.Module{Path: "github.com/ouroboric-dev/gungnir", Version: "v0.0.0-20261021195316-32cc95d9d0ff"},
		&debug.Module{Path: "github.com/BurntSushi/toml", Version: "v1.6.0"})
	got := Describe(bi)
	want := "odin b8c9716fa818 gungnir 32cc95d9d0ff gleipnir 6b6f83eec777"
	if got != want {
		t.Errorf("Describe() = %q, want %q", got, want)
	}
}

func TestADirtyOrLocalBuildSaysSoBecauseItCannotBeRepeated(t *testing.T) {
	bi := info(map[string]string{"vcs.revision": "b8c9716fa8180123456789abcdef0123456789ab", "vcs.modified": "true"},
		&debug.Module{Path: "github.com/ouroboric-dev/gungnir", Version: "(devel)"},
		&debug.Module{Path: "github.com/ouroboric-dev/gleipnir", Version: "v0.0.0-20261022013122-6b6f83eec777",
			Replace: &debug.Module{Path: "../gleipnir"}})
	got := Describe(bi)
	for _, want := range []string{"odin b8c9716fa818+dirty", "gungnir local", "gleipnir local"} {
		if !strings.Contains(got, want) {
			t.Errorf("Describe() = %q, want it to contain %q", got, want)
		}
	}
}

func TestABuildWithNoRecordedCommitStillHasAVersionOfBoundedLength(t *testing.T) {
	for name, bi := range map[string]*debug.BuildInfo{"no settings": info(nil), "nil": nil} {
		got := Describe(bi)
		if got != "odin unknown" {
			t.Errorf("%s: Describe() = %q, want %q", name, got, "odin unknown")
		}
	}
	long := info(map[string]string{"vcs.revision": strings.Repeat("a", 500)})
	if got := Describe(long); len(got) > 200 {
		t.Errorf("Describe() is %d bytes, want at most 200 (the ledger schema's bound)", len(got))
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
github.com/ouroboric-dev/odin/internal/version: no non-test Go files in /tmp/tmp.RoxDEuVhvM/v0-T272/odin/internal/version
# github.com/ouroboric-dev/odin/internal/version [github.com/ouroboric-dev/odin/internal/version.test]
internal/version/version_test.go:22:9: undefined: Describe
internal/version/version_test.go:34:9: undefined: Describe
```

- [ ] **Step 3:** write the code.

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index ecacdc5..104eb11 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -198,7 +198,7 @@ func (c *command) resume(args []string) int {
 		}
 		return c.advance(r)
 	}
-	if err := r.Log(gungnir.Event{Name: gungnir.EventRunResumed, Mode: r.State.Mode, Note: strings.Join(r.Saved, "; ")}); err != nil {
+	if err := r.Resumed(strings.Join(r.Saved, "; ")); err != nil {
 		return c.refuse(err)
 	}
 	return c.advance(r)
```

Apply to `internal/engine/loop.go`:

```diff
diff --git a/internal/engine/loop.go b/internal/engine/loop.go
index c065326..a2efebb 100644
--- a/internal/engine/loop.go
+++ b/internal/engine/loop.go
@@ -312,14 +312,13 @@ func logNames(path, test string) (bool, error) {
 func (l *loopSteps) Record(attempt int, changes []jormungandr.Change) error {
 	for _, c := range changes {
 		if c.Kind == jormungandr.DisputeIgnored {
-			// No event of the closed list fits a dispute that could not be used; loop_attempt carries it.
-			if err := l.r.Log(gungnir.Event{Name: gungnir.EventLoopAttempt, Node: l.n.ID, Attempt: attempt, Result: c.Reason}); err != nil {
+			if err := l.r.Log(gungnir.Event{Name: gungnir.EventDisputeIgnored, Node: l.n.ID, Attempt: attempt, Note: firstLine(c.Reason)}); err != nil {
 				return err
 			}
 			continue
 		}
 		ev := gungnir.Event{Node: l.n.ID, Attempt: attempt, FindingID: c.Finding.ID, FindingSource: c.Finding.Source,
-			FindingSeverity: string(c.Finding.Severity), Note: firstLine(c.Finding.Location + ": " + c.Finding.Claim)}
+			FindingSeverity: string(c.Finding.Severity), FindingOrigin: l.origin(c.Finding.Source), Note: firstLine(c.Finding.Location + ": " + c.Finding.Claim)}
 		switch c.Kind {
 		case jormungandr.Raised:
 			ev.Name = gungnir.EventFindingRaised
@@ -360,3 +359,11 @@ func firstLine(s string) string {
 	}
 	return line
 }
+
+// origin says whether a finding came from one of the loop's reviewers or from a check of its ladder.
+func (l *loopSteps) origin(source string) gungnir.FindingOrigin {
+	if slices.ContainsFunc(l.n.Reviewers, func(r schema.Reviewer) bool { return r.ID == source }) {
+		return gungnir.OriginReview
+	}
+	return gungnir.OriginCheck
+}
```

Apply to `internal/engine/routing.go`:

```diff
diff --git a/internal/engine/routing.go b/internal/engine/routing.go
index 3eff16d..2779016 100644
--- a/internal/engine/routing.go
+++ b/internal/engine/routing.go
@@ -32,6 +32,7 @@ func shipRouting(r *run.Run, n schema.Node, attempt int, parent tree.Node) error
 		return &nodeFailure{fmt.Errorf("routing: %w", err)}
 	}
 	note := ""
+	var measured *routing.Measure
 	if len(res.Skipped) > 0 {
 		note = fmt.Sprintf("left out: %d (first: %s)", len(res.Skipped), res.Skipped[0])
 	}
@@ -50,11 +51,16 @@ func shipRouting(r *run.Run, n schema.Node, attempt int, parent tree.Node) error
 			return &nodeFailure{fmt.Errorf("the routing index does not ship: %s; wrong or unanswered: %v", score, rep.Misses)}
 		}
 		note = strings.TrimSpace(note + " " + score)
+		measured = &routing.Measure{Bench: rep.Score, Baseline: base.Score, Threshold: rp.Threshold}
 	}
 	x, i := routing.Counts(res.Edges)
 	built := func(kind string) error {
-		return r.Log(gungnir.Event{Name: gungnir.EventRoutingIndexBuilt, Node: n.ID, Attempt: attempt, Task: n.Task,
-			IndexKind: kind, Edges: len(res.Edges), Extracted: x, Inferred: i, Note: note})
+		ev := gungnir.Event{Name: gungnir.EventRoutingIndexBuilt, Node: n.ID, Attempt: attempt, Task: n.Task,
+			IndexKind: kind, Edges: len(res.Edges), Extracted: x, Inferred: i, Note: note}
+		if measured != nil {
+			ev.RoutingBench, ev.RoutingBaseline, ev.RoutingThreshold = &measured.Bench, &measured.Baseline, &measured.Threshold
+		}
+		return r.Log(ev)
 	}
 	if wiring {
 		if err := routing.WriteWiring(parent.Dir, res.Edges); err != nil {
```

Apply to `internal/routing/bench.go`:

```diff
diff --git a/internal/routing/bench.go b/internal/routing/bench.go
index 3828280..a490bd2 100644
--- a/internal/routing/bench.go
+++ b/internal/routing/bench.go
@@ -253,3 +253,7 @@ func (g grepBaseline) Answer(q Question) ([]string, bool) {
 	}
 	return out, true
 }
+
+// Measure is what a shipped index scored on its bench, for the ledger: the index's right-first score, the grep
+// baseline's on the same questions, and the pack's bar.
+type Measure struct{ Bench, Baseline, Threshold float64 }
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 9a3ed10..10e00c0 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -28,6 +28,7 @@ import (
 	"github.com/ouroboric-dev/odin/internal/realm"
 	"github.com/ouroboric-dev/odin/internal/remote"
 	"github.com/ouroboric-dev/odin/internal/tree"
+	"github.com/ouroboric-dev/odin/internal/version"
 )
 
 // Options say what to run.
@@ -982,13 +983,14 @@ func record(project, dir, id string, setup *Setup) (*Run, error) {
 		ID: id, Status: StatusRunning, Mode: setup.Mode,
 		Graph: setup.GraphPack.Name, GraphVersion: setup.GraphPack.Version, GraphDir: setup.GraphPack.Dir, GraphPackSHA256: setup.GraphPack.Hash,
 		Realms: realmRecords(setup), GraphSHA256: setup.GraphSHA256,
+		Factory:    version.Factory(),
 		ConfigPath: setup.ConfigPath, ConfigSHA256: setup.ConfigSHA256,
 		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles(setup), Skills: setup.Skills,
 		Root: setup.Root, ProjectPath: setup.ProjectPath, Leaves: map[string]LeafRecord{},
 		Attempts: map[string]int{}, Reasons: map[string]string{}, Summaries: map[string]string{},
 		Waived: map[string]bool{}, Judged: map[string]string{}, Warned: map[string]bool{}, Loops: map[string]*LoopRecord{}, Expanded: map[string]bool{}, NewLeaves: map[string]bool{}, Returns: map[string]int{}, Refusals: map[string]string{}, Created: now, Updated: now,
 	}}
-	started := gungnir.Event{Name: gungnir.EventRunStarted, Mode: setup.Mode, ConfigHash: setup.ConfigSHA256,
+	started := gungnir.Event{Name: gungnir.EventRunStarted, Mode: setup.Mode, ConfigHash: setup.ConfigSHA256, FactoryVersion: r.State.Factory,
 		Note: graphNote(setup.GraphPack) + "; " + realmNote(setup.Realms)}
 	if err := r.Log(started); err != nil {
 		r.Close()
@@ -1354,3 +1356,8 @@ func sum(b []byte) string {
 	s := sha256.Sum256(b)
 	return hex.EncodeToString(s[:])
 }
+
+// Resumed logs run_resumed with the build of ygg that resumes the run, which may not be the build that started it.
+func (r *Run) Resumed(note string) error {
+	return r.Log(gungnir.Event{Name: gungnir.EventRunResumed, Mode: r.State.Mode, Note: note, FactoryVersion: version.Factory()})
+}
```

Apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index cbd1965..520c1bf 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -70,6 +70,7 @@ type State struct {
 	GraphPackSHA256 string                 `json:"graph_pack_sha256"` // of every file of the graph pack a run could read
 	GraphSHA256     string                 `json:"graph_sha256"`      // of graph.yaml
 	Realms          map[string]RealmRecord `json:"realms,omitempty"`  // every realm of the run, by name
+	Factory         string                 `json:"factory,omitempty"` // the build of ygg that started the run (version.Factory)
 	ConfigPath      string                 `json:"config_path"`
 	ConfigSHA256    string                 `json:"config_sha256"`
 	Brief           string                 `json:"brief,omitempty"`
```

Write `internal/version/version.go`:

```go
// Package version names the build of ygg that wrote a run, so a number quoted later can be traced to the exact
// factory that produced it (spec §10.2).
package version

import (
	"fmt"
	"runtime/debug"
	"strings"
)

// siblings are the modules whose commits belong to the factory's identity, in the order they are printed.
var siblings = []string{"gungnir", "gleipnir", "jormungandr", "havamal"}

const maxLen = 200 // the ledger schema's bound on ygg.factory.version

// Factory is the identity of this build of ygg.
func Factory() string {
	bi, _ := debug.ReadBuildInfo()
	return Describe(bi)
}

// Describe is Factory for a given build info: "odin <12 characters of the commit>", then each sibling module
// with the commit its pseudo-version names. A build with uncommitted changes says +dirty; a sibling that was
// replaced or built from a workspace says local, because that build cannot be repeated from the pins.
func Describe(bi *debug.BuildInfo) string {
	parts := []string{"odin " + commit(bi)}
	if bi != nil {
		for _, name := range siblings {
			for _, d := range bi.Deps {
				if d.Path != "github.com/ouroboric-dev/"+name {
					continue
				}
				parts = append(parts, name+" "+moduleCommit(d))
			}
		}
	}
	out := strings.Join(parts, " ")
	if len(out) > maxLen {
		out = out[:maxLen]
	}
	return out
}

func commit(bi *debug.BuildInfo) string {
	if bi == nil {
		return "unknown"
	}
	var rev, dirty string
	for _, s := range bi.Settings {
		switch s.Key {
		case "vcs.revision":
			rev = s.Value
		case "vcs.modified":
			if s.Value == "true" {
				dirty = "+dirty"
			}
		}
	}
	if rev == "" {
		return "unknown"
	}
	return rev[:min(12, len(rev))] + dirty
}

func moduleCommit(d *debug.Module) string {
	if d.Replace != nil || d.Version == "" || d.Version == "(devel)" {
		return "local"
	}
	// A pseudo-version ends in the commit: v0.0.0-20261021195316-32cc95d9d0ff.
	if i := strings.LastIndex(d.Version, "-"); i >= 0 && len(d.Version)-i-1 == 12 {
		return d.Version[i+1:]
	}
	return fmt.Sprint(d.Version)
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T273: `internal/metrics`: usage, the run's record and trust

The package that answers spec §10.2. This task is its trunk: `Collect` opens a run's folder, refuses a ledger that does not
verify, and adds up what the sessions used. Three decisions are in the code and are the reason for its tests. The run's own
totals are left out of the sum, because they repeat the sessions. `run.json` is read for the fields metrics needs and no
others (the engine's own reader refuses unknown fields), so a run that another build wrote, with a field renamed, stays
readable for a comparison. A session with tokens and no cost is *unpriced* (a `scripted` session has no price to miss): its cost is
unknown, not zero (B-107). Same branch as v0-T272.

**Files (in `odin`):**

- Create: `internal/metrics/collect.go`, `internal/metrics/helpers_test.go`, `internal/metrics/record.go`, `internal/metrics/types.go`, `internal/metrics/usage_test.go`

**Interfaces:**

- Produces: `metrics.Collect(dir string) (*metrics.Run, error)`. `dir` is a run's folder. The error names the ledger when
  its chain does not verify against the anchor in `run.json`.
- Produces: `metrics.Run` (JSON-tagged; `ygg metrics --json` prints it) with `ID`, `Status`, `Mode`, `Graph`,
  `GraphVersion`, `Factory []string` (the builds that wrote lines, in order), `ConfigSHA256`, `BriefSHA256`, `Roles`,
  `Realms`, `Usage`, `ByRole map[string]Usage` (key: role, adapter and model) and `Retries`.
- Produces: `metrics.Usage{InTok, OutTok, CacheTok, Turns int64; CostUSD, EstimatedUSD, BilledUSD float64; Sessions,
  Unpriced int}`. `BilledUSD` is the part of the cost from a paid adapter (`schema.PaidAPI`).
- Consumes: `ledger.Verify`, `gungnir.Event`, `schema.FeatureRecord`.

**Acceptance criteria:**

- [ ] Usage is the sum of the lines that record a session (`node_finished`, `node_failed`); a `run_finished` line carrying the
      run's totals does not double it. Cost is split into at API prices, estimated and billed (only the OpenCode session
      is billed in the test).
- [ ] A session with tokens and no cost counts as unpriced, apart from the `scripted` adapter's; the cost it lacks is not zero.
- [ ] A ledger with one changed byte, or cut short, is an error that names `ledger.jsonl`; no `Run` is returned.
- [ ] A `run.json` with another schema number, an unknown field and a field the build does not have is still read; a file
      that is not a ygg run record is refused.

**Review focus pinned by tests:** `TestUsageIsTheSumOfTheSessionLinesAndNeverTheRunTotalsToo`,
`TestACutOrChangedLedgerIsRefusedBecauseNoNumberFromItCanBeTrusted`.

**Named test:** `go test ./internal/metrics -run 'TestUsageIsTheSumOfTheSessionLinesAndNeverTheRunTotalsToo|TestASessionWithTokensAndNoCostIsCountedAsUnpricedNotAsFree|TestACutOrChangedLedgerIsRefusedBecauseNoNumberFromItCanBeTrusted|TestARunWrittenByAnotherBuildWithOtherFieldsIsStillMeasured'`
in `odin`. **Layer:** `odin`. **Size:** M (399). **Depends on:** v0-T272.

- [ ] **Step 1:** write the tests.

Write `internal/metrics/helpers_test.go`:

```go
package metrics

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/ledger"
	"github.com/ouroboric-dev/odin/internal/run"
)

const testRun = "20261023-090000-a1b2c3"

var t0 = time.Date(2026, 10, 23, 9, 0, 0, 0, time.UTC)

// fake is a run folder under construction: events go through the real ledger writer, so the chain is real.
type fake struct {
	t     *testing.T
	dir   string
	l     *ledger.Ledger
	State *run.State
}

func newFake(t *testing.T) *fake {
	t.Helper()
	dir := filepath.Join(t.TempDir(), testRun)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	l, err := ledger.Open(filepath.Join(dir, "ledger.jsonl"), ledger.Anchor{})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { l.Close() })
	return &fake{t: t, dir: dir, l: l, State: &run.State{ID: testRun, Status: run.StatusDone, Mode: gungnir.ModeKeyPoints,
		Graph: "software", GraphVersion: "0.1.0", ConfigSHA256: "c0", BriefSHA256: "b0",
		Roles:  map[string]run.RoleRecord{"implementer": {Agent: "claude-code", Model: "sonnet"}, "reviewer": {Agent: "opencode", Model: "openrouter/qwen/qwen3.8-27b"}},
		Realms: map[string]run.RealmRecord{"helheim-go": {Version: "0.1.0"}}}}
}

// log appends e at minute min after the run began.
func (f *fake) log(min float64, e gungnir.Event) *fake {
	f.t.Helper()
	e.Run, e.Time = testRun, t0.Add(time.Duration(min*float64(time.Minute)))
	if err := f.l.Append(e); err != nil {
		f.t.Fatal(err)
	}
	return f
}

// session is a finished agent session with usage.
func session(node, role, adapter, model string, in, out, turns int64, cost float64, estimated bool) gungnir.Event {
	return gungnir.Event{Name: gungnir.EventNodeFinished, Node: node, Attempt: 1, Role: role, Adapter: adapter, Model: model,
		InputTokens: in, OutputTokens: out, CacheReadTokens: in * 2, Turns: turns, CostUSD: cost, CostEstimated: estimated}
}

// dir saves run.json with the ledger's anchor and returns the run folder.
func (f *fake) done() string {
	f.t.Helper()
	f.State.Ledger = f.l.Head()
	if err := f.State.Save(f.dir); err != nil {
		f.t.Fatal(err)
	}
	return f.dir
}

func mustCollect(t *testing.T, dir string) *Run {
	t.Helper()
	r, err := Collect(dir)
	if err != nil {
		t.Fatalf("Collect() = %v", err)
	}
	return r
}
```

Write `internal/metrics/usage_test.go`:

```go
package metrics

import (
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func near(a, b float64) bool { return math.Abs(a-b) < 1e-9 }

func TestUsageIsTheSumOfTheSessionLinesAndNeverTheRunTotalsToo(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted, FactoryVersion: "odin aaaaaaaaaaaa"})
	f.log(5, session("implement", "implementer", "claude-code", "sonnet", 1000, 200, 4, 0.08, true))
	f.log(9, session("implement-quality", "reviewer", "opencode", "openrouter/qwen/qwen3.8-27b", 500, 50, 2, 0.012, false))
	failed := session("implement", "implementer", "claude-code", "sonnet", 300, 30, 1, 0.02, true)
	failed.Name = gungnir.EventNodeFailed
	f.log(12, failed)
	// The run's own totals repeat the sessions: counting them would double everything.
	total := gungnir.Event{Name: gungnir.EventRunFinished, Result: "done"}.WithUsage(gungnir.Usage{InTok: 1800, OutTok: 280, CacheTok: 3600, Turns: 7, CostUSD: 0.112, CostEstimated: true})
	f.log(15, total)
	r := mustCollect(t, f.done())
	u := r.Usage
	if u.InTok != 1800 || u.OutTok != 280 || u.CacheTok != 3600 || u.Turns != 7 || u.Sessions != 3 {
		t.Errorf("usage = %+v; want 1800 in, 280 out, 3600 cache, 7 turns, 3 sessions", u)
	}
	if !near(u.CostUSD, 0.112) || !near(u.EstimatedUSD, 0.10) {
		t.Errorf("cost = %v, estimated = %v; want 0.112 and 0.10", u.CostUSD, u.EstimatedUSD)
	}
	// Only the OpenCode session was billed; the Claude Code sessions are a subscription's, at API prices.
	if !near(u.BilledUSD, 0.012) {
		t.Errorf("billed = %v; want 0.012", u.BilledUSD)
	}
	impl := r.ByRole["implementer claude-code sonnet"]
	if impl.Sessions != 2 || impl.Turns != 5 || !near(impl.CostUSD, 0.10) {
		t.Errorf("by role implementer = %+v", impl)
	}
	if got := r.ByRole["reviewer opencode openrouter/qwen/qwen3.8-27b"]; got.Sessions != 1 {
		t.Errorf("by role reviewer = %+v", got)
	}
	if want := []string{"odin aaaaaaaaaaaa"}; !equal(r.Factory, want) {
		t.Errorf("Factory = %v, want %v", r.Factory, want)
	}
}

func equal(a, b []string) bool { return strings.Join(a, "\n") == strings.Join(b, "\n") }

// B-107: a session with tokens and no cost is unknown, not free.
func TestASessionWithTokensAndNoCostIsCountedAsUnpricedNotAsFree(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(3, session("implement-quality", "reviewer", "opencode", "openrouter/anthropic/claude-haiku-5-5", 900, 90, 2, 0, false))
	f.log(4, session("implement-spec", "reviewer", "opencode", "openrouter/qwen/qwen3.8-27b", 900, 90, 2, 0.01, false))
	r := mustCollect(t, f.done())
	if r.Usage.Unpriced != 1 || !near(r.Usage.CostUSD, 0.01) {
		t.Errorf("Unpriced = %d, cost = %v; want 1 and 0.01", r.Usage.Unpriced, r.Usage.CostUSD)
	}
}

func TestACutOrChangedLedgerIsRefusedBecauseNoNumberFromItCanBeTrusted(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted}).log(1, session("a", "implementer", "claude-code", "sonnet", 10, 1, 1, 0.01, true))
	dir := f.done()
	path := filepath.Join(dir, "ledger.jsonl")
	b, _ := os.ReadFile(path)
	if err := os.WriteFile(path, []byte(strings.Replace(string(b), `"ygg.usage.cost_usd":0.01`, `"ygg.usage.cost_usd":0.00`, 1)), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Collect(dir); err == nil || !strings.Contains(err.Error(), "ledger.jsonl") {
		t.Errorf("Collect() = %v, want a refusal that names the ledger", err)
	}
}

// Compare reads runs of different builds. A build that dropped or added a field of run.json must not make an
// older run unreadable: the record is read for the few fields metrics uses and nothing else.
func TestARunWrittenByAnotherBuildWithOtherFieldsIsStillMeasured(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted}).log(1, session("a", "implementer", "claude-code", "sonnet", 10, 1, 1, 0.01, true))
	dir := f.done()
	b, _ := os.ReadFile(filepath.Join(dir, "run.json"))
	b = []byte(strings.Replace(strings.Replace(string(b), `"schema": "ygg.run/v3"`, `"schema": "ygg.run/v2", "lead_realm": "midgard-react", "from_the_future": 7`, 1), `"id":`, `"extra": {"a": 1}, "id":`, 1))
	if err := os.WriteFile(filepath.Join(dir, "run.json"), b, 0o644); err != nil {
		t.Fatal(err)
	}
	r := mustCollect(t, dir)
	if r.Usage.Sessions != 1 || r.Graph != "software" {
		t.Errorf("Run = %+v", r)
	}
	if err := os.WriteFile(filepath.Join(dir, "run.json"), []byte(`{"schema": "something/else"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Collect(dir); err == nil {
		t.Error("Collect() accepted a run.json that is not a ygg run record")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/metrics [github.com/ouroboric-dev/odin/internal/metrics.test]
internal/metrics/helpers_test.go:69:45: undefined: Run
internal/metrics/helpers_test.go:71:12: undefined: Collect
internal/metrics/usage_test.go:73:15: undefined: Collect
```

- [ ] **Step 3:** write the code.

Write `internal/metrics/collect.go`:

```go
package metrics

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/ledger"
)

// maxLine bounds one ledger line; the ledger schema keeps lines far below it.
const maxLine = 4 << 20

// Collect reads the run in dir (a folder of .factory/runs) and measures it. The ledger's hash chain is checked
// first, against the anchor in run.json: a ledger that was changed or cut short is an error and gives no numbers.
func Collect(dir string) (*Run, error) {
	state, err := loadRecord(dir)
	if err != nil {
		return nil, err
	}
	path := filepath.Join(dir, "ledger.jsonl")
	if _, err := ledger.Verify(path, state.Ledger); err != nil {
		return nil, fmt.Errorf("the ledger of run %s can't be trusted: %w", state.ID, err)
	}
	events, err := readEvents(path)
	if err != nil {
		return nil, err
	}
	r := &Run{ID: state.ID, Status: string(state.Status), Mode: string(state.Mode), Graph: state.Graph, GraphVersion: state.GraphVersion,
		ConfigSHA256: state.ConfigSHA256, BriefSHA256: state.BriefSHA256, Roles: map[string]Setting{}, Realms: map[string]string{},
		ByRole: map[string]Usage{}, Factory: []string{}}
	for name, rr := range state.Roles {
		r.Roles[name] = Setting{Agent: rr.Agent, Model: rr.Model}
	}
	for name, rl := range state.Realms {
		r.Realms[name] = rl.Version
	}
	if len(events) == 0 {
		return r, nil
	}
	taskUsage := map[string]Usage{}
	for _, e := range events {
		switch e.Name {
		case gungnir.EventRunStarted, gungnir.EventRunResumed:
			if e.FactoryVersion != "" && !slices.Contains(r.Factory, e.FactoryVersion) {
				r.Factory = append(r.Factory, e.FactoryVersion)
			}
		case gungnir.EventRetry:
			r.Retries++
		}
		u, ok := sessionUsage(e)
		if !ok {
			continue
		}
		r.Usage.add(u)
		key := e.Role + " " + e.Adapter + " " + e.Model
		by := r.ByRole[key]
		by.add(u)
		r.ByRole[key] = by
		if e.Task != "" {
			tu := taskUsage[e.Task]
			tu.add(u)
			taskUsage[e.Task] = tu
		}
	}
	return r, nil
}

func readEvents(path string) ([]gungnir.Event, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), maxLine)
	var out []gungnir.Event
	for n := 1; sc.Scan(); n++ {
		var e gungnir.Event
		if err := json.Unmarshal(sc.Bytes(), &e); err != nil {
			return nil, fmt.Errorf("%s:%d: %w", path, n, err)
		}
		out = append(out, e)
	}
	return out, sc.Err()
}

// sessionUsage is the usage of a ledger line that records one session. The run's own totals (run_finished,
// run_paused, run_failed) repeat the sessions and are left out.
func sessionUsage(e gungnir.Event) (Usage, bool) {
	switch e.Name {
	case gungnir.EventRunFinished, gungnir.EventRunPaused, gungnir.EventRunFailed:
		return Usage{}, false
	}
	if e.InputTokens == 0 && e.OutputTokens == 0 && e.Turns == 0 && e.CostUSD == 0 {
		return Usage{}, false
	}
	u := Usage{InTok: e.InputTokens, OutTok: e.OutputTokens, CacheTok: e.CacheReadTokens, Turns: e.Turns, CostUSD: e.CostUSD, Sessions: 1}
	if e.CostEstimated {
		u.EstimatedUSD = e.CostUSD
	}
	if schema.PaidAPI(e.Adapter) {
		u.BilledUSD = e.CostUSD
	}
	if e.CostUSD == 0 && (e.InputTokens > 0 || e.OutputTokens > 0) && e.Adapter != "scripted" {
		u.Unpriced = 1
	}
	return u, true
}
```

Write `internal/metrics/record.go`:

```go
package metrics

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/ledger"
)

// record is the part of run.json that metrics reads. It is read without refusing unknown fields, unlike the
// engine's own State: a comparison reads runs that different builds of ygg wrote, and a build that renamed a
// field must not make an older run unreadable.
type record struct {
	Schema       string `json:"schema"`
	ID           string `json:"id"`
	Status       string `json:"status"`
	Mode         string `json:"mode"`
	Graph        string `json:"graph"`
	GraphVersion string `json:"graph_version"`
	ConfigSHA256 string `json:"config_sha256"`
	BriefSHA256  string `json:"brief_sha256"`
	Roles        map[string]struct {
		Agent string `json:"agent"`
		Model string `json:"model"`
	} `json:"roles"`
	Realms map[string]struct {
		Version string `json:"version"`
	} `json:"realms"`
	Features []schema.FeatureRecord `json:"features"`
	Usage    struct {
		InTok  int64 `json:"in_tok"`
		OutTok int64 `json:"out_tok"`
		Turns  int64 `json:"turns"`
	} `json:"usage"`
	Ledger ledger.Anchor `json:"ledger"`
}

func loadRecord(dir string) (*record, error) {
	data, err := os.ReadFile(filepath.Join(dir, "run.json"))
	if err != nil {
		return nil, err
	}
	var rec record
	if err := json.Unmarshal(data, &rec); err != nil {
		return nil, fmt.Errorf("%s: %w", filepath.Join(dir, "run.json"), err)
	}
	if !strings.HasPrefix(rec.Schema, "ygg.run/") {
		return nil, fmt.Errorf("%s: schema %q is not a ygg run record", filepath.Join(dir, "run.json"), rec.Schema)
	}
	return &rec, nil
}
```

Write `internal/metrics/types.go`:

```go
// Package metrics reads a finished or running run's ledger, run.json and score.json, and answers the questions
// of spec §10.2: what the run cost, how long the factory worked, how often a loop passed first time, how many
// times a person had to step in, and what the hidden suite scored. It writes nothing. Every number comes from a
// ledger whose hash chain checked out, so a ledger that was changed gives no numbers at all.
package metrics

import ()

// Usage is what sessions used. Cost is the sum of the sessions' own cost fields.
type Usage struct {
	InTok        int64   `json:"in_tokens"`
	OutTok       int64   `json:"out_tokens"`
	CacheTok     int64   `json:"cache_read_tokens"`
	Turns        int64   `json:"turns"`
	CostUSD      float64 `json:"cost_usd"`
	EstimatedUSD float64 `json:"estimated_usd"` // of CostUSD: sessions whose adapter estimated the cost
	BilledUSD    float64 `json:"billed_usd"`    // of CostUSD: what a paid API billed. The rest is what subscription sessions would cost on the API
	Sessions     int     `json:"sessions"`
	Unpriced     int     `json:"unpriced_sessions"` // sessions with tokens and no cost: their cost is unknown, not zero (B-107)
}

func (u *Usage) add(o Usage) {
	u.InTok += o.InTok
	u.OutTok += o.OutTok
	u.CacheTok += o.CacheTok
	u.Turns += o.Turns
	u.CostUSD += o.CostUSD
	u.EstimatedUSD += o.EstimatedUSD
	u.BilledUSD += o.BilledUSD
	u.Sessions += o.Sessions
	u.Unpriced += o.Unpriced
}

// Setting is the agent and model of a role.
type Setting struct {
	Agent string `json:"agent"`
	Model string `json:"model"`
}

// Run is everything ygg metrics says about one run.
type Run struct {
	ID           string             `json:"run"`
	Status       string             `json:"status"`
	Mode         string             `json:"mode"`
	Graph        string             `json:"graph"`
	GraphVersion string             `json:"graph_version"`
	Factory      []string           `json:"factory"` // the builds of ygg that wrote lines of the ledger, in the order they first did
	ConfigSHA256 string             `json:"config_sha256"`
	BriefSHA256  string             `json:"brief_sha256,omitempty"`
	Roles        map[string]Setting `json:"roles"`
	Realms       map[string]string  `json:"realms"` // realm name: version
	Usage        Usage              `json:"usage"`
	ByRole       map[string]Usage   `json:"by_role"` // "role adapter model": what its sessions used
	Retries      int                `json:"retries"`
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T274: the time the factory worked

"Wall time excluding approval waits" (spec §10.2) is not the difference of two timestamps. A run stops at a gate and waits
for days; it fails and waits for the operator; the process is killed and left no line. The real ledgers show all three (the
run `20261019-184434-257049`: 41 minutes elapsed, 18 minutes at a gate, 12 stopped, 11 of work). This task counts the idle
spans, each moment once, and reports them apart. Grading after `run_finished` is not run time. Same branch.

**Files (in `odin`):**

- Create: `internal/metrics/clock.go`, `internal/metrics/time_test.go`
- Modify: `internal/metrics/collect.go`, `internal/metrics/types.go`

**Interfaces:**

- Produces: `metrics.Duration` (a `time.Duration` written in JSON as whole milliseconds, with `Round()`), `metrics.Time{Elapsed,
  Active, ApprovalWait, Stopped Duration}` and `Run.Time`.
- The rule: an *approval wait* runs from a `gate_pending` to the next `gate_approved` or `gate_rejected`; a *stopped* span from a
  `run_failed` or `run_paused` to the next `run_resumed`, or, for a `run_resumed` that follows neither (and no pending gate),
  from the line before it. The clock ends at the last `run_finished`. A wait still open at the last line counts for nothing.

**Acceptance criteria:**

- [ ] A run with a 60-minute approval wait, a 30-minute stop after a failure, and 30 minutes of work reports elapsed 120,
      approval wait 60, stopped 30, active 30.
- [ ] A process killed with no failure line is a stopped span that the resume closes.
- [ ] A run still waiting at a gate counts the wait up to its last line and not beyond.
- [ ] Times are written as whole milliseconds, named `…_ms`.

**Review focus pinned by tests:** all four tests of the task.

**Named test:** `go test ./internal/metrics -run 'TestWallTimeLeavesOutApprovalWaitsAndTimeTheRunWasStopped|TestAProcessKilledWithoutALedgerLineLeavesAGapThatTheResumeClosesAndTheReportCallsStopped|TestARunStillWaitingAtAGateCountsTheWaitUpToItsLastLineNotBeyond|TestTimesAndDurationsAreWrittenAsWholeMilliseconds'`
in `odin`. **Layer:** `odin`. **Size:** M (197). **Depends on:** v0-T273.

- [ ] **Step 1:** write the tests.

Write `internal/metrics/time_test.go`:

```go
package metrics

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

func minutes(d Duration) float64 { return time.Duration(d).Minutes() }

// Spec §10.2: wall time excludes approval waits. A failed run waiting for a person to resume it is not the
// factory's time either, and the report keeps the two apart.
func TestWallTimeLeavesOutApprovalWaitsAndTimeTheRunWasStopped(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(10, gungnir.Event{Name: gungnir.EventNodeFinished, Node: "design"})
	f.log(10, gungnir.Event{Name: gungnir.EventGatePending, Node: "design-gate", Gate: "design-gate"})
	f.log(70, gungnir.Event{Name: gungnir.EventGateApproved, Node: "design-gate", Gate: "design-gate", Note: "go ahead"})
	f.log(75, gungnir.Event{Name: gungnir.EventRunFailed, Result: "node plan: context canceled"})
	f.log(105, gungnir.Event{Name: gungnir.EventRunResumed})
	f.log(115, gungnir.Event{Name: gungnir.EventNodeFinished, Node: "plan"})
	f.log(120, gungnir.Event{Name: gungnir.EventRunFinished, Result: "done"})
	r := mustCollect(t, f.done())
	got := r.Time
	if minutes(got.Elapsed) != 120 || minutes(got.ApprovalWait) != 60 || minutes(got.Stopped) != 30 || minutes(got.Active) != 30 {
		t.Errorf("elapsed %v, approval wait %v, stopped %v, active %v; want 120, 60, 30 and 30 minutes",
			got.Elapsed, got.ApprovalWait, got.Stopped, got.Active)
	}
}

func TestAProcessKilledWithoutALedgerLineLeavesAGapThatTheResumeClosesAndTheReportCallsStopped(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(20, gungnir.Event{Name: gungnir.EventNodeStarted, Node: "implement"})
	f.log(50, gungnir.Event{Name: gungnir.EventRunResumed})
	f.log(60, gungnir.Event{Name: gungnir.EventRunFinished, Result: "done"})
	got := mustCollect(t, f.done()).Time
	if minutes(got.Stopped) != 30 || minutes(got.Active) != 30 || got.ApprovalWait != 0 {
		t.Errorf("stopped %v, active %v, approval wait %v; want 30, 30 and 0 minutes", got.Stopped, got.Active, got.ApprovalWait)
	}
}

func TestARunStillWaitingAtAGateCountsTheWaitUpToItsLastLineNotBeyond(t *testing.T) {
	f := newFake(t)
	f.State.Status = "stopped"
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(20, gungnir.Event{Name: gungnir.EventGatePending, Node: "design-gate", Gate: "design-gate"})
	got := mustCollect(t, f.done()).Time
	if minutes(got.Elapsed) != 20 || got.ApprovalWait != 0 || minutes(got.Active) != 20 {
		t.Errorf("elapsed %v, approval wait %v, active %v; want 20, 0 and 20 minutes", got.Elapsed, got.ApprovalWait, got.Active)
	}
}

func TestTimesAndDurationsAreWrittenAsWholeMilliseconds(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted}).log(2, gungnir.Event{Name: gungnir.EventRunFinished, Result: "done"})
	b, err := json.Marshal(mustCollect(t, f.done()).Time)
	if err != nil {
		t.Fatal(err)
	}
	if want := `{"elapsed_ms":120000,"active_ms":120000,"approval_wait_ms":0,"stopped_ms":0}`; string(b) != want {
		t.Errorf("Time = %s, want %s", b, want)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/metrics [github.com/ouroboric-dev/odin/internal/metrics.test]
internal/metrics/time_test.go:11:16: undefined: Duration
internal/metrics/time_test.go:26:11: r.Time undefined (type *Run has no field or method Time)
internal/metrics/time_test.go:39:34: mustCollect(t, f.done()).Time undefined (type *Run has no field or method Time)
```

- [ ] **Step 3:** write the code.

Write `internal/metrics/clock.go`:

```go
package metrics

import (
	"slices"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

// clock sets the run's times. The clock ends at the last run_finished, so grading a day later is not run time.
func (r *Run) clock(events []gungnir.Event) {
	start, end := events[0].Time, events[len(events)-1].Time
	for i := len(events) - 1; i >= 0; i-- {
		if events[i].Name == gungnir.EventRunFinished {
			end = events[i].Time
			events = events[:i+1]
			break
		}
	}
	approval, stopped := idle(events, end)
	elapsed, wait := end.Sub(start), length(approval, start, end)
	all := length(slices.Concat(approval, stopped), start, end)
	r.Time = Time{Elapsed: Duration(elapsed), ApprovalWait: Duration(wait), Stopped: Duration(all - wait), Active: Duration(elapsed - all)}
}

type span struct{ from, to time.Time }

// idle finds the time in which no one was working on the run: the approval waits (a gate_pending until the
// decision that follows it) and the stops (a failure or a pause until the resume, or the gap before a resume
// that no failure line explains, because the process was killed). end is the run's last counted line; a wait
// still open then counts for nothing, because the clock has not reached its end.
func idle(events []gungnir.Event, end time.Time) (approval, stopped []span) {
	for i, e := range events {
		switch e.Name {
		case gungnir.EventGatePending:
			if j := next(events, i, gungnir.EventGateApproved, gungnir.EventGateRejected); j >= 0 {
				approval = append(approval, span{e.Time, events[j].Time})
			}
		case gungnir.EventRunPaused, gungnir.EventRunFailed:
			if j := next(events, i, gungnir.EventRunResumed); j >= 0 {
				stopped = append(stopped, span{e.Time, events[j].Time})
			}
		case gungnir.EventRunResumed:
			if i > 0 && !slices.Contains([]gungnir.EventName{gungnir.EventRunPaused, gungnir.EventRunFailed, gungnir.EventGatePending}, events[i-1].Name) {
				stopped = append(stopped, span{events[i-1].Time, e.Time})
			}
		}
	}
	_ = end
	return approval, stopped
}

// next is the index of the first line after i that has one of the names, or -1.
func next(events []gungnir.Event, i int, names ...gungnir.EventName) int {
	for j := i + 1; j < len(events); j++ {
		if slices.Contains(names, events[j].Name) {
			return j
		}
	}
	return -1
}

// length is the total time the spans cover, each moment once, between from and to.
func length(spans []span, from, to time.Time) time.Duration {
	var clipped []span
	for _, s := range spans {
		s.from, s.to = maxTime(s.from, from), minTime(s.to, to)
		if s.to.After(s.from) {
			clipped = append(clipped, s)
		}
	}
	slices.SortFunc(clipped, func(a, b span) int { return a.from.Compare(b.from) })
	var total time.Duration
	var cur *span
	for i := range clipped {
		s := clipped[i]
		switch {
		case cur == nil:
			cur = &s
		case s.from.After(cur.to):
			total += cur.to.Sub(cur.from)
			cur = &s
		case s.to.After(cur.to):
			cur.to = s.to
		}
	}
	if cur != nil {
		total += cur.to.Sub(cur.from)
	}
	return total
}

func minTime(a, b time.Time) time.Time {
	if a.Before(b) {
		return a
	}
	return b
}

func maxTime(a, b time.Time) time.Time {
	if a.After(b) {
		return a
	}
	return b
}
```

Apply to `internal/metrics/collect.go`:

```diff
diff --git a/internal/metrics/collect.go b/internal/metrics/collect.go
index 5a55cf4..6d49dd4 100644
--- a/internal/metrics/collect.go
+++ b/internal/metrics/collect.go
@@ -43,6 +43,7 @@ func Collect(dir string) (*Run, error) {
 	if len(events) == 0 {
 		return r, nil
 	}
+	r.clock(events)
 	taskUsage := map[string]Usage{}
 	for _, e := range events {
 		switch e.Name {
```

Apply to `internal/metrics/types.go`:

```diff
diff --git a/internal/metrics/types.go b/internal/metrics/types.go
index 47d825d..558ddf0 100644
--- a/internal/metrics/types.go
+++ b/internal/metrics/types.go
@@ -4,7 +4,21 @@
 // ledger whose hash chain checked out, so a ledger that was changed gives no numbers at all.
 package metrics
 
-import ()
+import (
+	"strconv"
+	"time"
+)
+
+// Duration is a time.Duration that is written in JSON as whole milliseconds, which the field names promise.
+type Duration time.Duration
+
+// MarshalJSON writes d as milliseconds.
+func (d Duration) MarshalJSON() ([]byte, error) {
+	return []byte(strconv.FormatInt(time.Duration(d).Milliseconds(), 10)), nil
+}
+
+// Round is d to the second, for a table.
+func (d Duration) Round() time.Duration { return time.Duration(d).Round(time.Second) }
 
 // Usage is what sessions used. Cost is the sum of the sessions' own cost fields.
 type Usage struct {
@@ -31,6 +45,15 @@ func (u *Usage) add(o Usage) {
 	u.Unpriced += o.Unpriced
 }
 
+// Time is the run's clock. Elapsed runs from the first line to the run's end, or to the last line of a run that
+// has not ended. Active is what is left when the approval waits and the time the run was stopped are taken out.
+type Time struct {
+	Elapsed      Duration `json:"elapsed_ms"`
+	Active       Duration `json:"active_ms"`
+	ApprovalWait Duration `json:"approval_wait_ms"` // from gate_pending to the decision
+	Stopped      Duration `json:"stopped_ms"`       // from a failure, a pause or a killed process to the resume
+}
+
 // Setting is the agent and model of a role.
 type Setting struct {
 	Agent string `json:"agent"`
@@ -49,6 +72,7 @@ type Run struct {
 	BriefSHA256  string             `json:"brief_sha256,omitempty"`
 	Roles        map[string]Setting `json:"roles"`
 	Realms       map[string]string  `json:"realms"` // realm name: version
+	Time         Time               `json:"time"`
 	Usage        Usage              `json:"usage"`
 	ByRole       map[string]Usage   `json:"by_role"` // "role adapter model": what its sessions used
 	Retries      int                `json:"retries"`
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T275: tasks, loops, reviewer vetoes, findings and interventions

The figures that say whether the factory builds well: how often a loop passes first time, how often a reviewer vetoes, how
many times a person stepped in. A task's tag on the ledger lines (`ygg.task.id` is the task's slug) ties usage to the plan's
tasks and so to their leaves. The sum of the sessions is checked against the totals in `run.json`: on the real run
`20261021-225348-f4bd10` they agree to the token. Same branch.

**Files (in `odin`):**

- Create: `internal/metrics/loops_test.go`, `internal/metrics/measures.go`, `internal/metrics/tasks.go`, `internal/metrics/tasks_test.go`
- Modify: `internal/metrics/collect.go`, `internal/metrics/helpers_test.go`, `internal/metrics/types.go`, `internal/metrics/usage_test.go`

**Interfaces:**

- Produces: `metrics.Task{ID, Title, Leaf, Status, Why; Usage}`, `Run.Tasks` in the plan's order, `metrics.Group{Tasks, Done,
  Blocked; Usage}` and `Run.Leaves` (by leaf), `metrics.BlockedTask{Task, Why}` and `Run.BlockedTasks`.
- Produces: `metrics.Ratio{N, D int}` with `Value() (float64, bool)`, which has no value when `D` is 0. `metrics.Loops{Finished,
  Passed, GaveUp; FirstPass Ratio; AvgAttempts}`, `metrics.Review{Vetoes Ratio}`, `metrics.Findings{RaisedByCheck,
  RaisedByReview, RaisedUnattributed, Closed, Reopened, Overruled, DisputesIgnored}` (a finding line from before v0-T272
  has no origin and is counted as unattributed), `metrics.Interventions{Rejections, NotedApprovals, Escalations; Items
  []Item}` with `Total()`, and `Run.Warnings []string`.
- The rule: a loop *ended* when it passed (a `loop_attempt` with the result `passed`) or gave up (an `escalation`); it
  passed *first time* when it ended in attempt 1. A *veto* is an attempt in which a reviewer raised or reopened a
  `blocker` or `major` finding, out of the attempts in which a session of one of the loop's reviewers finished (its node id
  is the loop's id, a dash and the reviewer's id). A plain approval is not an intervention; a rejection, an approval with
  a note and an escalation are.

**Acceptance criteria:**

- [ ] Four ended loops (a pass in attempt 1, 3 and 2, and a give-up) give first pass 1 of 4 and 9/4 attempts on average.
- [ ] A reviewer's blocker or major is a veto; a minor one is not; a check's blocker is not.
- [ ] Findings and ignored disputes are counted from their own lines; an overruled finding is counted.
- [ ] Interventions are the three kinds; a plain approval is not one.
- [ ] The tasks come in the plan's order with their leaf, status and usage; a blocked task carries its reason.
- [ ] A ledger whose sessions add up to other totals than `run.json` gives exactly one warning that names `run.json`.

**Named test:** `go test ./internal/metrics -run 'TestFirstPassRateAndAverageAttemptsCountEveryLoopThatEnded|TestAReviewerVetoIsAnAttemptWhereAReviewerRaisedABlockingFinding|TestFindingsAndDisputesAreCountedFromTheirOwnEvents|TestInterventionsAreRejectionsNotedApprovalsAndEscalations|TestPerTaskAndPerLeafUsageFollowTheTaskTagOfTheLedgerLines|TestUsageThatDisagreesWithRunJSONIsReportedAsAWarning'`
in `odin`. **Layer:** `odin`. **Size:** M (387). **Depends on:** v0-T274.

- [ ] **Step 1:** write the tests.

Apply to `internal/metrics/helpers_test.go`:

```diff
diff --git a/internal/metrics/helpers_test.go b/internal/metrics/helpers_test.go
index 51380e2..a0011ad 100644
--- a/internal/metrics/helpers_test.go
+++ b/internal/metrics/helpers_test.go
@@ -7,6 +7,7 @@ import (
 	"time"
 
 	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
@@ -66,6 +67,15 @@ func (f *fake) done() string {
 	return f.dir
 }
 
+func (f *fake) features(fs ...schema.FeatureRecord) *fake {
+	f.State.Features = fs
+	return f
+}
+
+func feature(id, leaf string, status schema.TaskStatus, why string) schema.FeatureRecord {
+	return schema.FeatureRecord{Feature: schema.Feature{ID: id, Title: "title of " + id, Layer: leaf}, Status: status, Why: why}
+}
+
 func mustCollect(t *testing.T, dir string) *Run {
 	t.Helper()
 	r, err := Collect(dir)
```

Write `internal/metrics/loops_test.go`:

```go
package metrics

import (
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func passed(node string, attempt int) gungnir.Event {
	return gungnir.Event{Name: gungnir.EventLoopAttempt, Node: node, Attempt: attempt, Result: "passed"}
}

func review(node, reviewer string, attempt int) gungnir.Event {
	e := session(node+"-"+reviewer, "reviewer", "opencode", "openrouter/qwen/qwen3.8-27b", 100, 10, 2, 0.01, false)
	e.Attempt = attempt
	return e
}

func finding(name gungnir.EventName, node string, attempt int, id, source string, sev gungnir.Severity, origin gungnir.FindingOrigin) gungnir.Event {
	return gungnir.Event{Name: name, Node: node, Attempt: attempt, FindingID: id, FindingSource: source, FindingSeverity: string(sev), FindingOrigin: origin}
}

func TestFirstPassRateAndAverageAttemptsCountEveryLoopThatEnded(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(1, passed("a-implement", 1))                                                                                    // first time
	f.log(2, passed("b-implement", 3))                                                                                    // third attempt
	f.log(3, gungnir.Event{Name: gungnir.EventEscalation, Node: "c-implement", Attempt: 3, Result: "attempts-exhausted"}) // gave up
	f.log(3, passed("e-implement", 2))                                                                                    // second attempt: a pass, not a first pass
	f.log(4, gungnir.Event{Name: gungnir.EventLoopAttempt, Node: "d-implement", Attempt: 1, Result: "attempt 1 of 3 starts with 0 finding(s) open"})
	r := mustCollect(t, f.done())
	l := r.Loops
	if l.Finished != 4 || l.Passed != 3 || l.GaveUp != 1 || l.FirstPass != (Ratio{1, 4}) || !near(l.AvgAttempts, 9.0/4) {
		t.Errorf("Loops = %+v; want 4 ended, 3 passed, 1 gave up, first pass 1/4, 9/4 attempts on average", l)
	}
	if v, ok := l.FirstPass.Value(); !ok || !near(v, 0.25) {
		t.Errorf("FirstPass.Value() = %v, %v", v, ok)
	}
	if _, ok := (Ratio{0, 0}).Value(); ok {
		t.Error("a ratio of nothing over nothing must say it has no value, not 0")
	}
}

// Spec §10.2: the reviewer veto rate. A veto is an attempt in which a reviewer raised a blocking finding;
// a check that fails is not a reviewer's veto.
func TestAReviewerVetoIsAnAttemptWhereAReviewerRaisedABlockingFinding(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(1, review("x-implement", "quality", 1))
	f.log(2, finding(gungnir.EventFindingRaised, "x-implement", 1, "q-1", "quality", gungnir.SeverityMajor, gungnir.OriginReview))
	f.log(3, review("x-implement", "quality", 2))
	f.log(3, review("x-implement", "spec", 2))
	f.log(4, finding(gungnir.EventFindingRaised, "x-implement", 2, "q-2", "quality", gungnir.SeverityMinor, gungnir.OriginReview)) // minor: no veto
	f.log(5, finding(gungnir.EventFindingRaised, "x-implement", 2, "check-unit", "unit", gungnir.SeverityBlocker, gungnir.OriginCheck))
	f.log(6, passed("x-implement", 2))
	r := mustCollect(t, f.done())
	if r.Review.Vetoes != (Ratio{1, 2}) {
		t.Errorf("Review.Vetoes = %+v; want 1 of 2 reviewed attempts", r.Review.Vetoes)
	}
	fs := r.Findings
	if fs.RaisedByReview != 2 || fs.RaisedByCheck != 1 || fs.RaisedUnattributed != 0 {
		t.Errorf("Findings = %+v; want 2 by review and 1 by a check", fs)
	}
}

func TestFindingsAndDisputesAreCountedFromTheirOwnEvents(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(1, finding(gungnir.EventFindingRaised, "x-implement", 1, "a", "spec", gungnir.SeverityBlocker, ""))
	f.log(2, finding(gungnir.EventFindingClosed, "x-implement", 2, "a", "spec", gungnir.SeverityBlocker, gungnir.OriginReview))
	f.log(3, finding(gungnir.EventFindingReopened, "x-implement", 3, "a", "spec", gungnir.SeverityBlocker, gungnir.OriginReview))
	f.log(4, finding(gungnir.EventFindingOverruled, "x-implement", 3, "a", "spec", gungnir.SeverityBlocker, gungnir.OriginReview))
	f.log(5, gungnir.Event{Name: gungnir.EventDisputeIgnored, Node: "x-implement", Attempt: 3, Note: "dispute ignored: the check is not run"})
	f.log(6, gungnir.Event{Name: gungnir.EventRetry, Note: "429"})
	r := mustCollect(t, f.done())
	fs := r.Findings
	if fs.RaisedUnattributed != 1 || fs.Closed != 1 || fs.Reopened != 1 || fs.Overruled != 1 || fs.DisputesIgnored != 1 || r.Retries != 1 {
		t.Errorf("Findings = %+v, Retries = %d", fs, r.Retries)
	}
}

// Spec §7.2: rejections, approvals with notes and escalations are interventions. A plain approval is not.
func TestInterventionsAreRejectionsNotedApprovalsAndEscalations(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(1, gungnir.Event{Name: gungnir.EventGateApproved, Node: "design-gate", Gate: "design-gate"})
	f.log(2, gungnir.Event{Name: gungnir.EventGateApproved, Node: "x-contract-gate", Gate: "x-contract-gate", Note: "the contract change is in the spec"})
	f.log(3, gungnir.Event{Name: gungnir.EventGateRejected, Node: "plan-gate", Gate: "plan-gate", Note: "split task 3"})
	f.log(4, gungnir.Event{Name: gungnir.EventGateAutoPassed, Node: "feature-gate", Gate: "feature-gate"})
	f.log(5, gungnir.Event{Name: gungnir.EventEscalation, Node: "y-implement", Attempt: 3, Result: "attempts-exhausted"})
	got := mustCollect(t, f.done()).Interventions
	if got.Rejections != 1 || got.NotedApprovals != 1 || got.Escalations != 1 || got.Total() != 3 {
		t.Errorf("Interventions = %+v; want 1 rejection, 1 noted approval, 1 escalation, 3 in all", got)
	}
}
```

Write `internal/metrics/tasks_test.go`:

```go
package metrics

import (
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

func TestPerTaskAndPerLeafUsageFollowTheTaskTagOfTheLedgerLines(t *testing.T) {
	f := newFake(t).features(
		feature("gallery-T1", "repos/api", schema.TaskDone, ""),
		feature("gallery-T2", "repos/web", schema.TaskBlocked, "attempts-exhausted in implement"),
		feature("gallery-T3", "repos/web", schema.TaskTodo, ""))
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	a := session("gallery-t1-implement", "implementer", "claude-code", "sonnet", 100, 10, 3, 0.05, true)
	a.Task = "gallery-t1"
	b := session("gallery-t2-implement", "implementer", "claude-code", "sonnet", 200, 20, 6, 0.09, true)
	b.Task = "gallery-t2"
	c := session("gallery-t2-implement", "implementer", "claude-code", "sonnet", 200, 20, 6, 0.09, true)
	c.Task, c.Attempt = "gallery-t2", 2
	f.log(2, a).log(4, b).log(6, c)
	f.log(7, gungnir.Event{Name: gungnir.EventTaskBlocked, Task: "gallery-t2", Result: "blocked"})
	r := mustCollect(t, f.done())
	if len(r.Tasks) != 3 {
		t.Fatalf("Tasks = %+v, want the plan's three", r.Tasks)
	}
	t2 := r.Tasks[1]
	if t2.ID != "gallery-T2" || t2.Status != "blocked" || t2.Why != "attempts-exhausted in implement" || t2.Usage.Turns != 12 || t2.Leaf != "repos/web" {
		t.Errorf("task 2 = %+v", t2)
	}
	if got := r.Leaves["repos/web"]; got.Tasks != 2 || got.Blocked != 1 || got.Done != 0 || got.Usage.Turns != 12 {
		t.Errorf("leaf repos/web = %+v", got)
	}
	if got := r.Leaves["repos/api"]; got.Tasks != 1 || got.Done != 1 || !near(got.Usage.CostUSD, 0.05) {
		t.Errorf("leaf repos/api = %+v", got)
	}
	if len(r.BlockedTasks) != 1 || r.BlockedTasks[0].Task != "gallery-T2" {
		t.Errorf("BlockedTasks = %+v", r.BlockedTasks)
	}
}
```

Apply to `internal/metrics/usage_test.go`:

```diff
diff --git a/internal/metrics/usage_test.go b/internal/metrics/usage_test.go
index e227248..834923b 100644
--- a/internal/metrics/usage_test.go
+++ b/internal/metrics/usage_test.go
@@ -97,3 +97,19 @@ func TestARunWrittenByAnotherBuildWithOtherFieldsIsStillMeasured(t *testing.T) {
 		t.Error("Collect() accepted a run.json that is not a ygg run record")
 	}
 }
+
+func TestUsageThatDisagreesWithRunJSONIsReportedAsAWarning(t *testing.T) {
+	f := newFake(t)
+	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted}).log(1, session("a", "implementer", "claude-code", "sonnet", 10, 1, 1, 0.01, true))
+	f.State.Usage = gungnir.Usage{InTok: 10, OutTok: 1, CacheTok: 20, Turns: 1, CostUSD: 0.01}
+	if r := mustCollect(t, f.done()); len(r.Warnings) != 0 {
+		t.Errorf("Warnings = %v, want none when the ledger and run.json agree", r.Warnings)
+	}
+	g := newFake(t)
+	g.log(0, gungnir.Event{Name: gungnir.EventRunStarted}).log(1, session("a", "implementer", "claude-code", "sonnet", 10, 1, 1, 0.01, true))
+	g.State.Usage = gungnir.Usage{InTok: 99, OutTok: 1, Turns: 1, CostUSD: 0.01}
+	r := mustCollect(t, g.done())
+	if len(r.Warnings) != 1 || !strings.Contains(r.Warnings[0], "run.json") {
+		t.Errorf("Warnings = %v, want one that names run.json", r.Warnings)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/metrics [github.com/ouroboric-dev/odin/internal/metrics.test]
internal/metrics/loops_test.go:32:9: r.Loops undefined (type *Run has no field or method Loops)
internal/metrics/loops_test.go:33:74: undefined: Ratio
internal/metrics/loops_test.go:39:15: undefined: Ratio
```

- [ ] **Step 3:** write the code.

Apply to `internal/metrics/collect.go`:

```diff
diff --git a/internal/metrics/collect.go b/internal/metrics/collect.go
index 6d49dd4..90b21c2 100644
--- a/internal/metrics/collect.go
+++ b/internal/metrics/collect.go
@@ -33,7 +33,7 @@ func Collect(dir string) (*Run, error) {
 	}
 	r := &Run{ID: state.ID, Status: string(state.Status), Mode: string(state.Mode), Graph: state.Graph, GraphVersion: state.GraphVersion,
 		ConfigSHA256: state.ConfigSHA256, BriefSHA256: state.BriefSHA256, Roles: map[string]Setting{}, Realms: map[string]string{},
-		ByRole: map[string]Usage{}, Factory: []string{}}
+		ByRole: map[string]Usage{}, Leaves: map[string]Group{}, Tasks: []Task{}, BlockedTasks: []BlockedTask{}, Factory: []string{}, Warnings: []string{}}
 	for name, rr := range state.Roles {
 		r.Roles[name] = Setting{Agent: rr.Agent, Model: rr.Model}
 	}
@@ -69,6 +69,11 @@ func Collect(dir string) (*Run, error) {
 			taskUsage[e.Task] = tu
 		}
 	}
+	r.tasks(state, taskUsage)
+	r.crossCheck(state)
+	if err := r.measure(state, events); err != nil {
+		return nil, err
+	}
 	return r, nil
 }
 
@@ -113,3 +118,16 @@ func sessionUsage(e gungnir.Event) (Usage, bool) {
 	}
 	return u, true
 }
+
+// crossCheck compares what the ledger's sessions add up to with the totals run.json keeps. They are written
+// apart, so a difference means one of them is wrong or the run was edited.
+func (r *Run) crossCheck(state *record) {
+	u := state.Usage
+	if u.InTok+u.OutTok+u.Turns == 0 {
+		return
+	}
+	if r.Usage.InTok != u.InTok || r.Usage.OutTok != u.OutTok || r.Usage.Turns != u.Turns {
+		r.Warnings = append(r.Warnings, fmt.Sprintf("the ledger's sessions add up to %d tokens in, %d out and %d turns, but run.json says %d, %d and %d",
+			r.Usage.InTok, r.Usage.OutTok, r.Usage.Turns, u.InTok, u.OutTok, u.Turns))
+	}
+}
```

Write `internal/metrics/measures.go`:

```go
package metrics

import (
	"strings"

	"github.com/ouroboric-dev/gungnir"
)

// Ratio is a count out of a total. It has no value when the total is 0: a rate over nothing is not 0%.
type Ratio struct {
	N int `json:"n"`
	D int `json:"d"`
}

// Value is N/D, and false when D is 0.
func (r Ratio) Value() (float64, bool) {
	if r.D == 0 {
		return 0, false
	}
	return float64(r.N) / float64(r.D), true
}

// Loops counts the loops that ended, in a pass or in a give-up.
type Loops struct {
	Finished    int     `json:"finished"`
	Passed      int     `json:"passed"`
	GaveUp      int     `json:"gave_up"`
	FirstPass   Ratio   `json:"first_pass"` // loops that passed in attempt 1, out of the loops that ended
	AvgAttempts float64 `json:"avg_attempts"`
}

// Review is the reviewers' side of the loops.
type Review struct {
	Vetoes Ratio `json:"vetoes"` // attempts in which a reviewer raised a blocker or a major, out of the attempts reviewers saw
}

// Findings counts what the finding events record.
type Findings struct {
	RaisedByCheck      int `json:"raised_by_check"`
	RaisedByReview     int `json:"raised_by_review"`
	RaisedUnattributed int `json:"raised_unattributed"` // lines from before the ledger named an origin
	Closed             int `json:"closed"`
	Reopened           int `json:"reopened"`
	Overruled          int `json:"overruled"`
	DisputesIgnored    int `json:"disputes_ignored"`
}

// Interventions are the times a person had to step in (spec §7.2).
type Interventions struct {
	Rejections     int `json:"rejections"`
	NotedApprovals int `json:"noted_approvals"`
	Escalations    int `json:"escalations"`
}

// Total is every intervention.
func (i Interventions) Total() int { return i.Rejections + i.NotedApprovals + i.Escalations }

// measure fills the loop, review, finding, intervention, grade and routing figures.
func (r *Run) measure(state *record, events []gungnir.Event) error {
	attempts := map[string]int{} // loop node: the attempt it ended in
	end := func(node string, attempt int, passed bool) {
		if _, seen := attempts[node]; !seen {
			r.Loops.Finished++
			r.Loops.AvgAttempts += float64(attempt)
			if passed {
				r.Loops.Passed++
				if attempt == 1 {
					r.Loops.FirstPass.N++
				}
			} else {
				r.Loops.GaveUp++
			}
		}
		attempts[node] = attempt
	}
	loops := map[string]bool{}
	for _, e := range events {
		if e.Name == gungnir.EventLoopAttempt {
			loops[e.Node] = true
		}
	}
	type key struct {
		node    string
		attempt int
	}
	reviewed, vetoed := map[key]bool{}, map[key]bool{}
	for _, e := range events {
		switch e.Name {
		case gungnir.EventLoopAttempt:
			if e.Result == "passed" {
				end(e.Node, e.Attempt, true)
			}
		case gungnir.EventEscalation:
			r.Interventions.Escalations++
			end(e.Node, e.Attempt, false)
		case gungnir.EventGateRejected:
			r.Interventions.Rejections++
		case gungnir.EventGateApproved:
			if e.Note != "" {
				r.Interventions.NotedApprovals++
			}
		case gungnir.EventNodeFinished, gungnir.EventNodeFailed:
			if loop, ok := loopOf(e.Node, loops); ok {
				reviewed[key{loop, e.Attempt}] = true
			}
		case gungnir.EventFindingRaised:
			switch e.FindingOrigin {
			case gungnir.OriginCheck:
				r.Findings.RaisedByCheck++
			case gungnir.OriginReview:
				r.Findings.RaisedByReview++
			default:
				r.Findings.RaisedUnattributed++
			}
			fallthrough
		case gungnir.EventFindingReopened:
			if e.FindingOrigin == gungnir.OriginReview && (e.FindingSeverity == string(gungnir.SeverityBlocker) || e.FindingSeverity == string(gungnir.SeverityMajor)) {
				vetoed[key{e.Node, e.Attempt}] = true
			}
			if e.Name == gungnir.EventFindingReopened {
				r.Findings.Reopened++
			}
		case gungnir.EventFindingClosed:
			r.Findings.Closed++
		case gungnir.EventFindingOverruled:
			r.Findings.Overruled++
		case gungnir.EventDisputeIgnored:
			r.Findings.DisputesIgnored++
		}
	}
	if r.Loops.Finished > 0 {
		r.Loops.AvgAttempts /= float64(r.Loops.Finished)
	}
	r.Loops.FirstPass.D = r.Loops.Finished
	for k := range reviewed {
		r.Review.Vetoes.D++
		if vetoed[k] {
			r.Review.Vetoes.N++
		}
	}
	return nil
}

// loopOf finds the loop a reviewer's session belongs to: the session's node is the loop's id, a dash and the
// reviewer's id. The implementer's own sessions are the loop's node itself and are not reviews.
func loopOf(node string, loops map[string]bool) (string, bool) {
	for loop := range loops {
		if strings.HasPrefix(node, loop+"-") {
			return loop, true
		}
	}
	return "", false
}
```

Write `internal/metrics/tasks.go`:

```go
package metrics

// Task is one task of the plan with what it used.
type Task struct {
	ID     string `json:"id"`
	Title  string `json:"title"`
	Leaf   string `json:"leaf"`
	Status string `json:"status"`
	Why    string `json:"why,omitempty"`
	Usage  Usage  `json:"usage"`
}

// Group is the tasks of one leaf.
type Group struct {
	Tasks   int   `json:"tasks"`
	Done    int   `json:"done"`
	Blocked int   `json:"blocked"`
	Usage   Usage `json:"usage"`
}

// BlockedTask is a task the run gave up, with why.
type BlockedTask struct {
	Task string `json:"task"`
	Why  string `json:"why"`
}

// tasks lists the plan's tasks with what each used, and groups them by leaf.
func (r *Run) tasks(state *record, usage map[string]Usage) {
	for _, f := range state.Features {
		t := Task{ID: f.ID, Title: f.Title, Leaf: f.Layer, Status: string(f.Status), Why: f.Why, Usage: usage[f.Slug()]}
		r.Tasks = append(r.Tasks, t)
		g := r.Leaves[f.Layer]
		g.Tasks++
		g.Usage.add(t.Usage)
		switch f.Status {
		case "done":
			g.Done++
		case "blocked":
			g.Blocked++
			r.BlockedTasks = append(r.BlockedTasks, BlockedTask{Task: f.ID, Why: f.Why})
		}
		r.Leaves[f.Layer] = g
	}
}
```

Apply to `internal/metrics/types.go`:

```diff
diff --git a/internal/metrics/types.go b/internal/metrics/types.go
index 558ddf0..5f3e9e2 100644
--- a/internal/metrics/types.go
+++ b/internal/metrics/types.go
@@ -75,5 +75,14 @@ type Run struct {
 	Time         Time               `json:"time"`
 	Usage        Usage              `json:"usage"`
 	ByRole       map[string]Usage   `json:"by_role"` // "role adapter model": what its sessions used
+	Tasks        []Task             `json:"tasks"`
+	Leaves       map[string]Group   `json:"leaves"`
+	BlockedTasks []BlockedTask      `json:"blocked_tasks"`
 	Retries      int                `json:"retries"`
+	Warnings     []string           `json:"warnings"` // things that do not add up, such as a ledger and run.json that disagree
+
+	Loops         Loops         `json:"loops"`
+	Review        Review        `json:"review"`
+	Findings      Findings      `json:"findings"`
+	Interventions Interventions `json:"interventions"`
 }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T276: the grade, the escaped defects and routing

The hidden score and what it says about the factory. *Escaped defects* are the hidden tests that failed where the visible ones
passed (spec §10.2); this task counts the fail-to-pass scenarios that failed, and keeps the number of tasks the run gave up
beside it, because with a task given up some of the failures are work that was never built. Routing is reported as it is:
the factory writes no lookups yet, and an index shipped without a bench has no score. Scripted sessions have no price to
miss. Same branch.

**Files (in `odin`):**

- Create: `internal/metrics/grade.go`, `internal/metrics/grade_test.go`
- Modify: `internal/metrics/collect.go`, `internal/metrics/types.go`, `internal/metrics/usage_test.go`

**Interfaces:**

- Produces: `metrics.Grade{Task, TaskVersion, Suite string; Reward float64; FailToPass, PassToPass Tally; Categories
  map[string]Category; Duration Duration; EscapedDefects, TasksGivenUp int; Refused string}` and `Run.Grade *Grade` (nil
  when the run was never graded), `metrics.Tally{Passed, Total}`, `metrics.Category{Passed, Total; Weight}`.
- Produces: `metrics.Routing{Lookups, Indexes int; Bench, Baseline, Threshold *float64}` and `Run.Routing`.
- The rule: `score.json` is the source (`schema.ParseScore`, which refuses a score that does not add up); without it, the last
  `grade_finished` line; a `grade_refused` after the last finish is a refusal. Grade time is from `grade_started` to
  `grade_finished`.

**Acceptance criteria:**

- [ ] The grade comes from `score.json` with its categories and weights; grading a day after the run ended does not change
      the run's elapsed or active time, and the grade took 45 minutes.
- [ ] Escaped defects are the failed fail-to-pass scenarios (1 of 3 in the test), and a run with a task given up says so.
- [ ] Without `score.json`, the ledger's reward and tallies are used and there are no categories; a refused grade says its
      reason; a run never graded has no `Grade`.
- [ ] An index measured by a bench reports its score, its grep baseline and its bar; one shipped without a bench has no score.
- [ ] A scripted session with tokens and no cost is not unpriced.

**Named test:** `go test ./internal/metrics -run 'TestTheGradeComesFromScoreJSONWithItsCategoriesAndTheGradeTimeIsNotRunTime|TestEscapedDefectsAreFailedFailToPassScenariosAndSayWhetherTasksWereGivenUp|TestWithoutScoreJSONTheGradeIsTheLedgersAndARefusalIsSaid|TestARoutingIndexReportsItsBenchAndAnUnmeasuredOneSaysSo|TestSessionsOfTheScriptedAdapterAreNotUnpriced'`
in `odin`. **Layer:** `odin`. **Size:** M (267). **Depends on:** v0-T275.

- [ ] **Step 1:** write the tests.

Write `internal/metrics/grade_test.go`:

```go
package metrics

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

func writeScore(t *testing.T, dir string) {
	t.Helper()
	s := gungnir.Score{
		Schema: gungnir.ScoreSchema, Run: testRun, Task: "client-gallery-lite", TaskVersion: "4.0.0",
		BriefSHA256: "bd4b2c7aaf532d51acb3a7edfd5b193d368db8445093b7a24cd80b7ee24d8319", Suite: "v2", Started: t0, Finished: t0.Add(20 * time.Minute),
		Scenarios: []gungnir.ScoredScenario{
			{ID: "photographer creates a gallery", Category: "photographer", Kind: gungnir.FailToPass, Status: gungnir.ScenarioPassed},
			{ID: "photographer uploads a photo", Category: "photographer", Kind: gungnir.FailToPass, Status: gungnir.ScenarioFailed},
			{ID: "client opens a link", Category: "client", Kind: gungnir.FailToPass, Status: gungnir.ScenarioPassed},
			{ID: "login page loads", Category: "client", Kind: gungnir.PassToPass, Status: gungnir.ScenarioFailed},
			{ID: "old link still works", Category: "client", Kind: gungnir.PassToPass, Status: gungnir.ScenarioFailed},
		},
		FailToPass: gungnir.Tally{Passed: 2, Total: 3}, PassToPass: gungnir.Tally{Passed: 0, Total: 2},
		Categories: map[string]gungnir.CategoryScore{"photographer": {Passed: 1, Total: 2, Weight: 0.4}, "client": {Passed: 1, Total: 1, Weight: 0.6}},
		Reward:     0.4*0.5 + 0.6,
	}
	b, err := json.Marshal(s)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := schema.ParseScore(b); err != nil {
		t.Fatalf("the test's own score is invalid: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "score.json"), b, 0o644); err != nil {
		t.Fatal(err)
	}
}

func gradedRun(t *testing.T, blocked bool) *Run {
	t.Helper()
	f := newFake(t).features(feature("g-T1", "repos/api", schema.TaskDone, ""), feature("g-T2", "repos/web", schema.TaskDone, ""))
	if blocked {
		f.State.Features[1] = feature("g-T2", "repos/web", schema.TaskBlocked, "attempts-exhausted")
	}
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(30, gungnir.Event{Name: gungnir.EventRunFinished, Result: "done"})
	f.log(1000, gungnir.Event{Name: gungnir.EventGradeStarted, Task: "client-gallery-lite", Suite: "v2"})
	reward := 0.8
	f.log(1045, gungnir.Event{Name: gungnir.EventGradeFinished, Task: "client-gallery-lite", Suite: "v2", Reward: &reward, FailToPass: "2/3", PassToPass: "1/2"})
	dir := f.done()
	writeScore(t, dir)
	return mustCollect(t, dir)
}

func TestTheGradeComesFromScoreJSONWithItsCategoriesAndTheGradeTimeIsNotRunTime(t *testing.T) {
	r := gradedRun(t, false)
	if minutes(r.Time.Elapsed) != 30 || minutes(r.Time.Active) != 30 {
		t.Errorf("elapsed %v, active %v; want 30 minutes each: grading came a day later", r.Time.Elapsed, r.Time.Active)
	}
	g := r.Grade
	if g == nil {
		t.Fatal("Grade = nil")
	}
	if !near(g.Reward, 0.8) || g.FailToPass != (Tally{2, 3}) || g.PassToPass != (Tally{0, 2}) || g.Suite != "v2" || g.Task != "client-gallery-lite" || minutes(g.Duration) != 45 {
		t.Errorf("Grade = %+v", g)
	}
	if c := g.Categories["photographer"]; c.Passed != 1 || c.Total != 2 || !near(c.Weight, 0.4) {
		t.Errorf("category photographer = %+v", c)
	}
}

// Spec §10.2: escaped defects are hidden tests failing where the visible tests passed.
func TestEscapedDefectsAreFailedFailToPassScenariosAndSayWhetherTasksWereGivenUp(t *testing.T) {
	g := gradedRun(t, false).Grade
	if g.EscapedDefects != 1 || g.TasksGivenUp != 0 {
		t.Errorf("EscapedDefects = %d, TasksGivenUp = %d; want 1 and 0", g.EscapedDefects, g.TasksGivenUp)
	}
	g = gradedRun(t, true).Grade
	if g.EscapedDefects != 1 || g.TasksGivenUp != 1 {
		t.Errorf("EscapedDefects = %d, TasksGivenUp = %d; want 1 and 1: with a task given up some failures are unbuilt work", g.EscapedDefects, g.TasksGivenUp)
	}
}

func TestWithoutScoreJSONTheGradeIsTheLedgersAndARefusalIsSaid(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted}).log(5, gungnir.Event{Name: gungnir.EventRunFinished, Result: "done"})
	reward := 0.25
	f.log(9, gungnir.Event{Name: gungnir.EventGradeStarted, Task: "t", Suite: "v1"})
	f.log(10, gungnir.Event{Name: gungnir.EventGradeFinished, Task: "t", Suite: "v1", Reward: &reward, FailToPass: "1/4", PassToPass: "2/2"})
	g := mustCollect(t, f.done()).Grade
	if g == nil || !near(g.Reward, 0.25) || g.FailToPass != (Tally{1, 4}) || g.EscapedDefects != 3 || len(g.Categories) != 0 {
		t.Errorf("Grade = %+v; want the ledger's reward 0.25, 1/4 fail-to-pass, 3 escaped, no categories", g)
	}
	r := newFake(t)
	r.log(0, gungnir.Event{Name: gungnir.EventRunStarted}).log(5, gungnir.Event{Name: gungnir.EventRunFinished, Result: "done"})
	r.log(6, gungnir.Event{Name: gungnir.EventGradeRefused, Task: "t", Suite: "v1", Reason: gungnir.GradeBriefChanged})
	got := mustCollect(t, r.done())
	if got.Grade == nil || got.Grade.Refused != "brief_changed" {
		t.Errorf("Grade = %+v; want a refusal that says brief_changed", got.Grade)
	}
	none := newFake(t)
	none.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	if got := mustCollect(t, none.done()); got.Grade != nil {
		t.Errorf("a run never graded has Grade = %+v, want nil", got.Grade)
	}
}

func TestARoutingIndexReportsItsBenchAndAnUnmeasuredOneSaysSo(t *testing.T) {
	bench, base, bar := 0.9, 0.5, 0.8
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(1, gungnir.Event{Name: gungnir.EventRoutingIndexBuilt, IndexKind: "wiring", Edges: 4})
	f.log(1, gungnir.Event{Name: gungnir.EventRoutingLookup})
	f.log(2, gungnir.Event{Name: gungnir.EventRoutingIndexBuilt, IndexKind: "impact", Edges: 4, RoutingBench: &bench, RoutingBaseline: &base, RoutingThreshold: &bar})
	got := mustCollect(t, f.done()).Routing
	if got.Indexes != 2 || got.Lookups != 1 || got.Bench == nil || !near(*got.Bench, 0.9) || !near(*got.Baseline, 0.5) || !near(*got.Threshold, 0.8) {
		t.Errorf("Routing = %+v", got)
	}
	g := newFake(t)
	g.log(0, gungnir.Event{Name: gungnir.EventRunStarted}).log(1, gungnir.Event{Name: gungnir.EventRoutingIndexBuilt, IndexKind: "wiring", Edges: 4})
	if got := mustCollect(t, g.done()).Routing; got.Indexes != 1 || got.Bench != nil {
		t.Errorf("Routing = %+v; an index shipped without a bench has no score", got)
	}
}
```

Apply to `internal/metrics/usage_test.go`:

```diff
diff --git a/internal/metrics/usage_test.go b/internal/metrics/usage_test.go
index 834923b..53f25f3 100644
--- a/internal/metrics/usage_test.go
+++ b/internal/metrics/usage_test.go
@@ -113,3 +113,11 @@ func TestUsageThatDisagreesWithRunJSONIsReportedAsAWarning(t *testing.T) {
 		t.Errorf("Warnings = %v, want one that names run.json", r.Warnings)
 	}
 }
+
+func TestSessionsOfTheScriptedAdapterAreNotUnpriced(t *testing.T) {
+	f := newFake(t)
+	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted}).log(1, session("a", "implementer", "scripted", "none", 100, 10, 2, 0, false))
+	if r := mustCollect(t, f.done()); r.Usage.Unpriced != 0 || r.Usage.Sessions != 1 {
+		t.Errorf("Usage = %+v; a scripted session has no price to miss", r.Usage)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/metrics [github.com/ouroboric-dev/odin/internal/metrics.test]
internal/metrics/grade_test.go:63:9: r.Grade undefined (type *Run has no field or method Grade)
internal/metrics/grade_test.go:67:46: undefined: Tally
internal/metrics/grade_test.go:77:27: gradedRun(t, false).Grade undefined (type *Run has no field or method Grade)
```

- [ ] **Step 3:** write the code.

Apply to `internal/metrics/collect.go`:

```diff
diff --git a/internal/metrics/collect.go b/internal/metrics/collect.go
index 90b21c2..d41c6f7 100644
--- a/internal/metrics/collect.go
+++ b/internal/metrics/collect.go
@@ -74,6 +74,10 @@ func Collect(dir string) (*Run, error) {
 	if err := r.measure(state, events); err != nil {
 		return nil, err
 	}
+	r.routing(events)
+	if err := r.grade(dir, state, events); err != nil {
+		return nil, err
+	}
 	return r, nil
 }
 
```

Write `internal/metrics/grade.go`:

```go
package metrics

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

// Tally is passed out of total scenarios.
type Tally struct {
	Passed int `json:"passed"`
	Total  int `json:"total"`
}

// Category is one category of the reward.
type Category struct {
	Passed int     `json:"passed"`
	Total  int     `json:"total"`
	Weight float64 `json:"weight"`
}

// Grade is the hidden suite's result for the run.
type Grade struct {
	Task        string              `json:"task"`
	TaskVersion string              `json:"task_version,omitempty"`
	Suite       string              `json:"suite"`
	Reward      float64             `json:"reward"`
	FailToPass  Tally               `json:"fail_to_pass"`
	PassToPass  Tally               `json:"pass_to_pass"`
	Categories  map[string]Category `json:"categories"`
	Duration    Duration            `json:"duration_ms"`
	// EscapedDefects is the number of fail-to-pass scenarios that failed. TasksGivenUp says how many of the
	// run's tasks were never built: with any, some of the failures are missing work and not an escape.
	EscapedDefects int    `json:"escaped_defects"`
	TasksGivenUp   int    `json:"tasks_given_up"`
	Refused        string `json:"refused,omitempty"` // grading was refused, and why
}

// Routing is what the routing indexes of the run report (spec §8).
type Routing struct {
	Lookups   int      `json:"lookups"` // routing_lookup lines; the factory does not write them yet
	Indexes   int      `json:"indexes"` // routing_index_built lines
	Bench     *float64 `json:"bench,omitempty"`
	Baseline  *float64 `json:"baseline,omitempty"`
	Threshold *float64 `json:"threshold,omitempty"`
}

// routing counts the lookups and reads the bench score of the last index that was measured.
func (r *Run) routing(events []gungnir.Event) {
	for _, e := range events {
		switch e.Name {
		case gungnir.EventRoutingLookup:
			r.Routing.Lookups++
		case gungnir.EventRoutingIndexBuilt:
			r.Routing.Indexes++
			if e.RoutingBench != nil {
				r.Routing.Bench, r.Routing.Baseline, r.Routing.Threshold = e.RoutingBench, e.RoutingBaseline, e.RoutingThreshold
			}
		}
	}
}

// grade reads score.json, or the grade_finished line when there is none, and the time grading took.
func (r *Run) grade(dir string, state *record, events []gungnir.Event) error {
	var started, finished time.Time
	var fin *gungnir.Event
	var refused string
	for i, e := range events {
		switch e.Name {
		case gungnir.EventGradeStarted:
			started, refused = e.Time, ""
		case gungnir.EventGradeFinished:
			finished, fin, refused = e.Time, &events[i], ""
		case gungnir.EventGradeRefused:
			refused = string(e.Reason)
		}
	}
	data, err := os.ReadFile(filepath.Join(dir, "score.json"))
	switch {
	case err == nil:
		s, err := schema.ParseScore(data)
		if err != nil {
			return fmt.Errorf("%s: %w", filepath.Join(dir, "score.json"), err)
		}
		g := &Grade{Task: s.Task, TaskVersion: s.TaskVersion, Suite: s.Suite, Reward: s.Reward,
			FailToPass: Tally(s.FailToPass), PassToPass: Tally(s.PassToPass), Categories: map[string]Category{}}
		for name, c := range s.Categories {
			g.Categories[name] = Category(c)
		}
		r.Grade = g
	case os.IsNotExist(err) && fin != nil && fin.Reward != nil:
		g := &Grade{Task: fin.Task, Suite: fin.Suite, Reward: *fin.Reward, Categories: map[string]Category{}}
		g.FailToPass, g.PassToPass = tally(fin.FailToPass), tally(fin.PassToPass)
		r.Grade = g
	case os.IsNotExist(err):
		if refused != "" {
			r.Grade = &Grade{Refused: refused, Categories: map[string]Category{}}
		}
		return nil
	default:
		return err
	}
	if !started.IsZero() && !finished.IsZero() && finished.After(started) {
		r.Grade.Duration = Duration(finished.Sub(started))
	}
	r.Grade.EscapedDefects = r.Grade.FailToPass.Total - r.Grade.FailToPass.Passed
	r.Grade.TasksGivenUp = len(r.BlockedTasks)
	return nil
}

// tally reads "passed/total".
func tally(s string) Tally {
	p, t, ok := strings.Cut(s, "/")
	if !ok {
		return Tally{}
	}
	a, _ := strconv.Atoi(p)
	b, _ := strconv.Atoi(t)
	return Tally{a, b}
}
```

Apply to `internal/metrics/types.go`:

```diff
diff --git a/internal/metrics/types.go b/internal/metrics/types.go
index 5f3e9e2..52fd845 100644
--- a/internal/metrics/types.go
+++ b/internal/metrics/types.go
@@ -85,4 +85,6 @@ type Run struct {
 	Review        Review        `json:"review"`
 	Findings      Findings      `json:"findings"`
 	Interventions Interventions `json:"interventions"`
+	Grade         *Grade        `json:"grade,omitempty"`
+	Routing       Routing       `json:"routing"`
 }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T277: the text report and the range table

What the founder reads and pastes into a journal entry. Every figure of spec §10.2 is a line, in words. A rate over nothing
says so. Text an agent wrote (a blocked task's reason) is printed on one line without control characters: a terminal acts on
them. Same branch.

**Files (in `odin`):**

- Create: `internal/metrics/render.go`, `internal/metrics/render_test.go`

**Interfaces:**

- Produces: `(*metrics.Run).WriteText(w io.Writer)`: one labelled line each for the run, the factory build ("not recorded"
  for a run from before v0-T272), config and brief hashes with the realms, the roles, the time, the usage, the cost, the
  loops, the review, the findings, the interventions, the blocked tasks, the grade, the routing, retries and warnings,
  then tables by role and by task.
- Produces: `metrics.WriteRange(w io.Writer, runs []*metrics.Run)`: a header, one row for each run, a total line. It adds no
  figure the rows do not show: a mean reward over runs of different tasks would look like a measure.

**Acceptance criteria:**

- [ ] Each of the figures appears in words, with thousands separators for tokens, a cost "at API prices, $X of it billed to a
      paid API" and a note when sessions were unpriced ("so this is a floor").
- [ ] An empty run says "n/a (no loop has ended)", "n/a (no reviewer has run)", "not graded", "not recorded" and "bench not
      measured", and prints no "0%".
- [ ] A range has two rows and a total after its header.
- [ ] A reason holding a newline, an escape and a bell prints on one line without them.

**Review focus pinned by tests:** `TestTheTextReportNeverShowsAnEmptyRateAsZeroOrAMissingGradeAsAScore`,
`TestTextFromAnAgentIsPrintedOnOneLineWithNoControlCharacters`.

**Named test:** `go test ./internal/metrics -run 'TestTheTextReportSaysEachFigureOfSpecSection102InWords|TestTheTextReportNeverShowsAnEmptyRateAsZeroOrAMissingGradeAsAScore|TestARangeTableHasARowPerRunAndATotalLine|TestTextFromAnAgentIsPrintedOnOneLineWithNoControlCharacters'`
in `odin`. **Layer:** `odin`. **Size:** M (322). **Depends on:** v0-T276.

- [ ] **Step 1:** write the tests.

Write `internal/metrics/render_test.go`:

```go
package metrics

import (
	"bytes"
	"strings"
	"testing"
	"time"
)

func sample() *Run {
	bench, base, bar := 0.9, 0.5, 0.8
	return &Run{
		ID: "20261023-090000-a1b2c3", Status: "done", Mode: "key-points", Graph: "software", GraphVersion: "0.1.0",
		Factory: []string{"odin b8c9716fa818 gungnir 32cc95d9d0ff"}, ConfigSHA256: strings.Repeat("c0", 32), BriefSHA256: strings.Repeat("b0", 32),
		Roles:         map[string]Setting{"implementer": {"claude-code", "sonnet"}, "reviewer": {"opencode", "openrouter/qwen/qwen3.8-27b"}},
		Realms:        map[string]string{"helheim-go": "0.1.0"},
		Time:          Time{Elapsed: Duration(2*time.Hour + 5*time.Minute), Active: Duration(65 * time.Minute), ApprovalWait: Duration(50 * time.Minute), Stopped: Duration(10 * time.Minute)},
		Usage:         Usage{InTok: 1234567, OutTok: 89012, CacheTok: 3000000, Turns: 410, CostUSD: 1.5, EstimatedUSD: 1.2, BilledUSD: 0.3, Sessions: 90, Unpriced: 3},
		ByRole:        map[string]Usage{"implementer claude-code sonnet": {Turns: 300, CostUSD: 1.2, EstimatedUSD: 1.2, Sessions: 30}},
		Tasks:         []Task{{ID: "g-T1", Leaf: "repos/api", Status: "done", Usage: Usage{Turns: 12, CostUSD: 0.2}}, {ID: "g-T2", Leaf: "repos/web", Status: "blocked", Why: "attempts-exhausted"}},
		Leaves:        map[string]Group{"repos/api": {Tasks: 1, Done: 1}, "repos/web": {Tasks: 1, Blocked: 1}},
		BlockedTasks:  []BlockedTask{{Task: "g-T2", Why: "attempts-exhausted"}},
		Loops:         Loops{Finished: 4, Passed: 3, GaveUp: 1, FirstPass: Ratio{2, 4}, AvgAttempts: 1.75},
		Review:        Review{Vetoes: Ratio{3, 9}},
		Findings:      Findings{RaisedByCheck: 2, RaisedByReview: 5, Closed: 6, Overruled: 1, DisputesIgnored: 1},
		Interventions: Interventions{Rejections: 1, NotedApprovals: 2, Escalations: 1},
		Grade: &Grade{Task: "client-gallery-lite", Suite: "v2", Reward: 0.7125, FailToPass: Tally{20, 29}, PassToPass: Tally{4, 4},
			Categories: map[string]Category{"security": {Passed: 5, Total: 8, Weight: 0.35}}, EscapedDefects: 9, TasksGivenUp: 1},
		Routing:  Routing{Indexes: 2, Bench: &bench, Baseline: &base, Threshold: &bar},
		Warnings: []string{"the ledger's sessions add up to 1 tokens, but run.json says 2"},
	}
}

func TestTheTextReportSaysEachFigureOfSpecSection102InWords(t *testing.T) {
	var b bytes.Buffer
	sample().WriteText(&b)
	out := b.String()
	for _, want := range []string{
		"run:", "20261023-090000-a1b2c3", "(done, key-points, graph software 0.1.0)",
		"factory:      odin b8c9716fa818 gungnir 32cc95d9d0ff",
		"implementer = claude-code sonnet",
		"time:         1h05m active of 2h05m elapsed (approval waits 50m, stopped 10m)",
		"usage:        1,234,567 tokens in, 89,012 out, 3,000,000 from cache; 410 turns; 90 sessions",
		"cost:         $1.5000 at API prices, $0.3000 of it billed to a paid API; 3 sessions had tokens and no cost, so this is a floor",
		"first pass 2 of 4 (50%)", "1.75 attempts on average", "1 gave up",
		"reviewer vetoes 3 of 9 attempts (33%)",
		"raised 7 (2 by checks, 5 by reviewers)", "overruled 1", "disputes ignored 1",
		"interventions: 4 (1 rejections, 2 approvals with notes, 1 escalations)",
		"blocked:      g-T2: attempts-exhausted",
		"reward 0.7125", "fail-to-pass 20/29", "pass-to-pass 4/4", "escaped defects 9 (1 tasks were given up: some failures are missing work)",
		"security 5/8 (weight 0.35)",
		"bench 90% (grep baseline 50%, bar 80%)",
		"warning:      the ledger's sessions add up",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("the report lacks %q:\n%s", want, out)
		}
	}
}

func TestTheTextReportNeverShowsAnEmptyRateAsZeroOrAMissingGradeAsAScore(t *testing.T) {
	var b bytes.Buffer
	(&Run{ID: "20261023-090000-a1b2c3", Status: "running", Mode: "unattended", Roles: map[string]Setting{}}).WriteText(&b)
	out := b.String()
	for _, want := range []string{"first pass n/a (no loop has ended)", "reviewer vetoes n/a (no reviewer has run)",
		"grade:        not graded", "factory:      not recorded", "bench not measured"} {
		if !strings.Contains(out, want) {
			t.Errorf("the report lacks %q:\n%s", want, out)
		}
	}
	if strings.Contains(out, "0%") {
		t.Errorf("a rate over nothing was shown as 0%%:\n%s", out)
	}
}

func TestARangeTableHasARowPerRunAndATotalLine(t *testing.T) {
	a, b := sample(), sample()
	b.ID, b.Grade = "20261023-100000-d4e5f6", nil
	var w bytes.Buffer
	WriteRange(&w, []*Run{a, b})
	out := w.String()
	for _, want := range []string{"20261023-090000-a1b2c3", "20261023-100000-d4e5f6", "total", "0.7125", "not graded", "$3.0000"} {
		if !strings.Contains(out, want) {
			t.Errorf("the range lacks %q:\n%s", want, out)
		}
	}
	if lines := strings.Count(strings.TrimSpace(out), "\n"); lines != 3 {
		t.Errorf("the range has %d lines after the header, want 3 (two runs and a total):\n%s", lines, out)
	}
}

// A blocked task's reason can hold text an agent wrote. A terminal acts on control characters, so none is printed.
func TestTextFromAnAgentIsPrintedOnOneLineWithNoControlCharacters(t *testing.T) {
	r := sample()
	r.BlockedTasks = []BlockedTask{{Task: "g-T2", Why: "gave up\n\x1b[31m# injected\x07 \r\nsecond line"}}
	var b bytes.Buffer
	r.WriteText(&b)
	out := b.String()
	if strings.ContainsAny(out, "\x1b\x07\r") {
		t.Errorf("a control character reached the output:\n%q", out)
	}
	if !strings.Contains(out, "g-T2: gave up [31m# injected second line") {
		t.Errorf("the reason is not one clean line:\n%s", out)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/metrics [github.com/ouroboric-dev/odin/internal/metrics.test]
internal/metrics/render_test.go:36:11: sample().WriteText undefined (type *Run has no field or method WriteText)
internal/metrics/render_test.go:63:107: (&Run{…}).WriteText undefined (type *Run has no field or method WriteText)
internal/metrics/render_test.go:80:2: undefined: WriteRange
```

- [ ] **Step 3:** write the code.

Write `internal/metrics/render.go`:

```go
package metrics

import (
	"fmt"
	"io"
	"maps"
	"slices"
	"strings"
	"time"
	"unicode"
)

const labelWidth = 14

// line writes "label value", the label padded to a column.
func line(w io.Writer, label, format string, args ...any) {
	pad := " "
	if n := labelWidth - len(label); n > 0 {
		pad = strings.Repeat(" ", n)
	}
	fmt.Fprintf(w, "%s%s%s\n", label, pad, fmt.Sprintf(format, args...))
}

// WriteText writes the report the operator reads and pastes into a journal entry: every figure of spec §10.2,
// in words, with a rate that has nothing to count saying so.
func (r *Run) WriteText(w io.Writer) {
	line(w, "run:", "%s  (%s, %s, graph %s %s)", r.ID, r.Status, r.Mode, r.Graph, r.GraphVersion)
	if len(r.Factory) == 0 {
		line(w, "factory:", "not recorded (a run from before the ledger named its build)")
	} else {
		line(w, "factory:", "%s", strings.Join(r.Factory, "; "))
	}
	line(w, "config:", "%s  brief: %s%s", short(r.ConfigSHA256), short(r.BriefSHA256), realms(r.Realms))
	label := "roles:"
	for _, name := range slices.Sorted(maps.Keys(r.Roles)) {
		line(w, label, "%s = %s %s", name, r.Roles[name].Agent, r.Roles[name].Model)
		label = ""
	}
	line(w, "time:", "%s active of %s elapsed (approval waits %s, stopped %s)", dur(r.Time.Active), dur(r.Time.Elapsed), dur(r.Time.ApprovalWait), dur(r.Time.Stopped))
	u := r.Usage
	line(w, "usage:", "%s tokens in, %s out, %s from cache; %d turns; %d sessions", num(u.InTok), num(u.OutTok), num(u.CacheTok), u.Turns, u.Sessions)
	cost := fmt.Sprintf("$%.4f at API prices, $%.4f of it billed to a paid API", u.CostUSD, u.BilledUSD)
	if u.Unpriced > 0 {
		cost += fmt.Sprintf("; %d sessions had tokens and no cost, so this is a floor", u.Unpriced)
	}
	line(w, "cost:", "%s", cost)
	l := r.Loops
	line(w, "loops:", "%d ended: first pass %s, %.2f attempts on average, %d gave up", l.Finished, ratio(l.FirstPass, "", "no loop has ended"), l.AvgAttempts, l.GaveUp)
	line(w, "review:", "reviewer vetoes %s", ratio(r.Review.Vetoes, "attempts", "no reviewer has run"))
	f := r.Findings
	raised := f.RaisedByCheck + f.RaisedByReview + f.RaisedUnattributed
	by := fmt.Sprintf("%d by checks, %d by reviewers", f.RaisedByCheck, f.RaisedByReview)
	if f.RaisedUnattributed > 0 {
		by += fmt.Sprintf(", %d with no origin recorded", f.RaisedUnattributed)
	}
	line(w, "findings:", "raised %d (%s); closed %d; reopened %d; overruled %d; disputes ignored %d", raised, by, f.Closed, f.Reopened, f.Overruled, f.DisputesIgnored)
	i := r.Interventions
	line(w, "interventions:", "%d (%d rejections, %d approvals with notes, %d escalations)", i.Total(), i.Rejections, i.NotedApprovals, i.Escalations)
	if len(r.BlockedTasks) == 0 {
		line(w, "blocked:", "none")
	}
	for n, b := range r.BlockedTasks {
		label := ""
		if n == 0 {
			label = "blocked:"
		}
		line(w, label, "%s: %s", clean(b.Task), clean(b.Why))
	}
	r.writeGrade(w)
	rt := r.Routing
	bench := "bench not measured"
	if rt.Bench != nil {
		bench = fmt.Sprintf("bench %.0f%% (grep baseline %.0f%%, bar %.0f%%)", *rt.Bench*100, *rt.Baseline*100, *rt.Threshold*100)
	}
	line(w, "routing:", "%d lookups, %d indexes built; %s", rt.Lookups, rt.Indexes, bench)
	if r.Retries > 0 {
		line(w, "retries:", "%d sessions were retried after a transient failure", r.Retries)
	}
	for _, msg := range r.Warnings {
		line(w, "warning:", "%s", msg)
	}
	if len(r.ByRole) > 0 {
		fmt.Fprintln(w, "\nby role:")
		for _, k := range slices.Sorted(maps.Keys(r.ByRole)) {
			fmt.Fprintf(w, "  %-45s %s\n", k, usageLine(r.ByRole[k]))
		}
	}
	if len(r.Tasks) > 0 {
		fmt.Fprintln(w, "\ntasks:")
		for _, t := range r.Tasks {
			fmt.Fprintf(w, "  %-16s %-8s %-12s %s\n", t.ID, t.Status, t.Leaf, usageLine(t.Usage))
		}
	}
}

func (r *Run) writeGrade(w io.Writer) {
	g := r.Grade
	switch {
	case g == nil:
		line(w, "grade:", "not graded")
	case g.Refused != "" && g.Suite == "":
		line(w, "grade:", "refused: %s", g.Refused)
	default:
		line(w, "grade:", "reward %.4f (suite %s of %s): fail-to-pass %d/%d, pass-to-pass %d/%d; escaped defects %d%s",
			g.Reward, g.Suite, g.Task, g.FailToPass.Passed, g.FailToPass.Total, g.PassToPass.Passed, g.PassToPass.Total, g.EscapedDefects, given(g))
		for _, name := range slices.Sorted(maps.Keys(g.Categories)) {
			c := g.Categories[name]
			line(w, "", "%s %d/%d (weight %.2f)", name, c.Passed, c.Total, c.Weight)
		}
	}
}

func given(g *Grade) string {
	if g.TasksGivenUp == 0 {
		return ""
	}
	return fmt.Sprintf(" (%d tasks were given up: some failures are missing work)", g.TasksGivenUp)
}

func usageLine(u Usage) string {
	if u.Sessions == 0 && u.Turns == 0 {
		return ""
	}
	return fmt.Sprintf("%d turns, %d sessions, $%.4f", u.Turns, u.Sessions, u.CostUSD)
}

// WriteRange writes one row for each run and a total line. It adds no figure the rows do not show, such as a
// mean reward: a mean over runs of different briefs or suites would look like a measure.
func WriteRange(w io.Writer, runs []*Run) {
	fmt.Fprintf(w, "%-24s %-8s %-12s %9s %10s %12s %5s %7s  %s\n", "run", "status", "mode", "active", "cost", "first pass", "ints", "blocked", "reward")
	var active time.Duration
	var cost float64
	var ints, blocked int
	for _, r := range runs {
		reward := "not graded"
		if r.Grade != nil && r.Grade.Suite != "" {
			reward = fmt.Sprintf("%.4f", r.Grade.Reward)
		}
		first := "n/a"
		if v, ok := r.Loops.FirstPass.Value(); ok {
			first = fmt.Sprintf("%d/%d %.0f%%", r.Loops.FirstPass.N, r.Loops.FirstPass.D, v*100)
		}
		fmt.Fprintf(w, "%-24s %-8s %-12s %9s %10s %12s %5d %7d  %s\n", r.ID, r.Status, r.Mode, dur(r.Time.Active), fmt.Sprintf("$%.4f", r.Usage.CostUSD), first, r.Interventions.Total(), len(r.BlockedTasks), reward)
		active += time.Duration(r.Time.Active)
		cost += r.Usage.CostUSD
		ints += r.Interventions.Total()
		blocked += len(r.BlockedTasks)
	}
	fmt.Fprintf(w, "%-24s %-8s %-12s %9s %10s %12s %5d %7d  %s\n", "total", fmt.Sprintf("%d runs", len(runs)), "", dur(Duration(active)), fmt.Sprintf("$%.4f", cost), "", ints, blocked, "")
}

func realms(m map[string]string) string {
	if len(m) == 0 {
		return ""
	}
	var parts []string
	for _, k := range slices.Sorted(maps.Keys(m)) {
		parts = append(parts, k+" "+m[k])
	}
	return "  realms: " + strings.Join(parts, ", ")
}

func short(sha string) string {
	if len(sha) > 12 {
		return sha[:12]
	}
	if sha == "" {
		return "none"
	}
	return sha
}

func ratio(r Ratio, unit, empty string) string {
	v, ok := r.Value()
	if !ok {
		return "n/a (" + empty + ")"
	}
	if unit != "" {
		unit += " "
	}
	return fmt.Sprintf("%d of %d %s(%.0f%%)", r.N, r.D, unit, v*100)
}

// dur writes a duration as 1h05m, 5m05s or 45s.
func dur(d Duration) string {
	t := time.Duration(d).Round(time.Second)
	h, m, s := int(t.Hours()), int(t.Minutes())%60, int(t.Seconds())%60
	switch {
	case h > 0:
		return fmt.Sprintf("%dh%02dm", h, m)
	case m > 0 && s == 0:
		return fmt.Sprintf("%dm", m)
	case m > 0:
		return fmt.Sprintf("%dm%02ds", m, s)
	}
	return fmt.Sprintf("%ds", s)
}

// num writes an integer with thousands separators.
func num(n int64) string {
	s := fmt.Sprint(n)
	for i := len(s) - 3; i > 0; i -= 3 {
		s = s[:i] + "," + s[i:]
	}
	return s
}

// clean makes text an agent may have written safe to print: one line, and no control character, which a
// terminal would act on.
func clean(s string) string {
	return strings.Join(strings.Fields(strings.Map(func(r rune) rune {
		if unicode.IsControl(r) {
			return ' '
		}
		return r
	}, s)), " ")
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T278: `ygg metrics`

The verb. `ygg metrics <run-id>` prints one run; `ygg metrics <first>..<last>` prints every run of the project whose id is
from one to the other (ids begin with the time, so their order is the order the runs began in), as a table with a total
line; `--json` prints the same figures for a tool. It reads and writes nothing. It refuses what it cannot read or trust,
with exit 2. Same branch.

**Files (in `odin`):**

- Create: `internal/cli/metrics.go`, `internal/cli/metrics_test.go`
- Modify: `README.md`, `docs/architecture.md`, `internal/cli/cli.go`, `internal/cli/docs_test.go`

**Interfaces:**

- Produces: `ygg metrics <run-id|first..last> [--json] [--project <dir>]`. Exit 0, or 2 for a refusal.
- Consumes: `metrics.Collect`, `(*Run).WriteText`, `metrics.WriteRange`.

**Acceptance criteria:**

- [ ] On a real scripted run, the text has the run, the factory build, the time, the usage, the cost, the loops, the
      interventions and "not graded"; `--json` is valid JSON with the run id, a time in milliseconds and the factory builds.
- [ ] Refused with exit 2 and a message: no id, a path as an id, a run that is not there, a range backwards, a range with no
      run in it. A ledger with a changed byte is refused with "can't be trusted".
- [ ] A range of two real runs lists both and a total; its `--json` is a list of two.
- [ ] The README and the architecture page name the command; `TestTheDocsNameEveryCommand` fails when they do not.

**Named test:** `go test ./internal/cli -run 'TestYggMetricsPrintsTheFiguresOfARealRunAsTextAndAsJSON|TestYggMetricsRefusesWhatItCannotTrustOrReadAndWritesNothing|TestYggMetricsRangeListsEveryRunBetweenTwoIDsAndTotalsThem|TestTheDocsNameEveryCommand'`
in `odin`. **Layer:** `odin`. **Size:** M (237). **Depends on:** v0-T277.

- [ ] **Step 1:** write the tests.

Apply to `internal/cli/docs_test.go`:

```diff
diff --git a/internal/cli/docs_test.go b/internal/cli/docs_test.go
index 6f84ce8..3774980 100644
--- a/internal/cli/docs_test.go
+++ b/internal/cli/docs_test.go
@@ -30,7 +30,7 @@ func TestTheDocsNameEveryCommand(t *testing.T) {
 	}
 	for _, want := range []string{"ygg grade", "ygg deps bump", "`grade` node", "--canary", "--host", "--task", "grade_refused", "score.json", "ygg.grader",
 		"REPOS.md", ".ygg/impact.json", "shrink guard", "pointer-contract", "routing_index_built", "pointer_contract_checked", "deps_bump", "memory: none",
-		"--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
+		"ygg metrics", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
 		if !strings.Contains(string(arch), want) {
 			t.Errorf("docs/architecture.md does not mention %q", want)
 		}
```

Write `internal/cli/metrics_test.go`:

```go
package cli

import (
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/run"
)

func TestYggMetricsPrintsTheFiguresOfARealRunAsTextAndAsJSON(t *testing.T) {
	dir, config := project(t, "script.yaml", "mode: key-points\n")
	id, _ := walk(t, dir, config)
	code, out, errOut := ygg(t, "metrics", id, "--project", dir)
	if code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	for _, want := range []string{"run:", id, "key-points", "factory:", "time:", "usage:", "cost:", "loops:", "interventions:", "grade:        not graded"} {
		if !strings.Contains(out, want) {
			t.Errorf("the report lacks %q:\n%s", want, out)
		}
	}
	code, out, _ = ygg(t, "metrics", id, "--project", dir, "--json")
	var got struct {
		Run  string `json:"run"`
		Time struct {
			Elapsed int64 `json:"elapsed_ms"`
		} `json:"time"`
		Factory []string `json:"factory"`
	}
	if err := json.Unmarshal([]byte(out), &got); code != ExitDone || err != nil || got.Run != id || len(got.Factory) == 0 {
		t.Errorf("--json gave exit %d, %v, %+v:\n%s", code, err, got, out)
	}
}

func TestYggMetricsRefusesWhatItCannotTrustOrReadAndWritesNothing(t *testing.T) {
	dir, config := project(t, "script.yaml", "mode: key-points\n")
	id, _ := walk(t, dir, config)
	path := filepath.Join(run.Dir(dir, id), "ledger.jsonl")
	good, _ := os.ReadFile(path)
	for name, args := range map[string][]string{
		"no run id":               {"metrics", "--project", dir},
		"a path as run id":        {"metrics", "../../x", "--project", dir},
		"a run that is not there": {"metrics", "20200101-000000-aaaaaa", "--project", dir},
		"a range backwards":       {"metrics", "20300101-000000-aaaaaa..20200101-000000-aaaaaa", "--project", dir},
		"a range with no run":     {"metrics", "20200101-000000-aaaaaa..20200102-000000-aaaaaa", "--project", dir},
		"compare with one":        {"metrics", "--compare", id, "--project", dir},
	} {
		if code, _, errOut := ygg(t, args...); code != ExitRefused || errOut == "" {
			t.Errorf("%s: exit %d, stderr %q; want a refusal", name, code, errOut)
		}
	}
	if err := os.WriteFile(path, []byte(strings.Replace(string(good), `"ygg.mode":"key-points"`, `"ygg.mode":"unattended"`, 1)), 0o644); err != nil {
		t.Fatal(err)
	}
	if code, _, errOut := ygg(t, "metrics", id, "--project", dir); code != ExitRefused || !strings.Contains(errOut, "can't be trusted") {
		t.Errorf("a changed ledger: exit %d, stderr %q; want a refusal that says it can't be trusted", code, errOut)
	}
}

func TestYggMetricsRangeListsEveryRunBetweenTwoIDsAndTotalsThem(t *testing.T) {
	dir, config := project(t, "script.yaml", "mode: key-points\n")
	first, _ := walk(t, dir, config)
	second := anotherRun(t, dir, config)
	ids := []string{first, second}
	slices.Sort(ids)
	code, out, errOut := ygg(t, "metrics", ids[0]+".."+ids[1], "--project", dir)
	if code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	for _, want := range []string{ids[0], ids[1], "total"} {
		if !strings.Contains(out, want) {
			t.Errorf("the range lacks %q:\n%s", want, out)
		}
	}
	code, out, _ = ygg(t, "metrics", ids[0]+".."+ids[1], "--project", dir, "--json")
	var runs []struct{ Run string }
	if err := json.Unmarshal([]byte(out), &runs); code != ExitDone || err != nil || len(runs) != 2 {
		t.Errorf("--json of a range: exit %d, %v, %d runs", code, err, len(runs))
	}
}

// anotherRun starts a second run in a project that has one, approves every stop, and returns its id.
func anotherRun(t *testing.T, dir, config string) string {
	t.Helper()
	known := map[string]bool{}
	entries, _ := os.ReadDir(filepath.Join(dir, ".factory", "runs"))
	for _, e := range entries {
		known[e.Name()] = true
	}
	code, out, errOut := ygg(t, "run", "--project", dir, "--config", config, "--graph", toyRealm(t))
	entries, _ = os.ReadDir(filepath.Join(dir, ".factory", "runs"))
	var id string
	for _, e := range entries {
		if !known[e.Name()] {
			id = e.Name()
		}
	}
	for code == ExitStopped {
		s, err := run.LoadState(run.Dir(dir, id))
		if err != nil {
			t.Fatal(err)
		}
		code, out, errOut = ygg(t, "approve", id, s.Pending, "--project", dir)
	}
	if code != ExitDone || id == "" {
		t.Fatalf("exit %d, run %q:\n%s%s", code, id, out, errOut)
	}
	return id
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTheDocsNameEveryCommand (0.00s)
    docs_test.go:35: docs/architecture.md does not mention "ygg metrics"
    docs_test.go:35: docs/architecture.md does not mention "ygg.factory.version"
    docs_test.go:35: docs/architecture.md does not mention "dispute_ignored"
```

- [ ] **Step 3:** write the code.

Apply to `README.md`:

```diff
diff --git a/README.md b/README.md
index 98d7a91..25c8189 100644
--- a/README.md
+++ b/README.md
@@ -22,6 +22,7 @@ ygg approve <run-id> <gate> [--note <text>] [--project <dir>] [--mode <mode>]
 ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
 ygg status  <run-id> [--project <dir>]
 ygg grade   <run-id> [--task <id>] [--project <dir>]
+ygg metrics <run-id|first..last> [--json] [--project <dir>]
 ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
 ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
 ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -36,6 +37,14 @@ When any role bills a paid API (an OpenCode role), the caps also count dollars,
 cost figure of a Claude Code session is what it would cost on the API; the subscription charges nothing for it, so it does
 not count against `usd`. `ygg status` and `ygg metrics` show both.
 
+`ygg metrics` reads a run's ledger, `run.json` and `score.json` and prints the figures of spec §10.2: tokens, turns and
+cost (with what an adapter only estimated, and sessions that came back with tokens and no cost), the time the factory
+worked with the approval waits and the stopped time taken out, the first-pass rate and the average attempts of the loops,
+the reviewer veto rate, findings, interventions, blocked tasks, the hidden score and the escaped defects, and what the
+routing indexes scored. A rate over nothing says `n/a`. It checks the ledger's hash chain first and refuses a ledger that
+was changed. `first..last` lists every run of the project from one id to the other, with a total line. `--json` prints the
+same figures for a tool. It writes nothing.
+
 `ygg deps bump` runs the package manager and the checks in the sandbox of `factory.yaml`. Without a `sandbox:`
 section it refuses (exit 2) unless you pass `--host`, which runs the bump on the host with the full network and
 your user id, and records that in the first line of the bump's ledger. With a sandbox section `--host` has no effect.
```

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index df6b53f..8facdca 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -136,6 +136,17 @@ The orchestrator: the graph engine and the `ygg` CLI, with routing and the ledge
 - Writes the hash-chained ledger and serves the `ygg` CLI.
 - Holds routing (spec §8) and observability (spec §10) as packages.
 
+## Metrics
+
+`ygg metrics` (package `internal/metrics`) reads a run's folder and writes nothing. It verifies the ledger's hash chain
+against the anchor in `run.json` and refuses a ledger that does not verify. It reads `run.json` for the few fields it
+needs and ignores the rest, so a run written by another build of ygg stays readable. Session lines add up to the usage
+(the run's own totals repeat them and are not counted); the sum is checked against `run.json` and a difference is a
+warning. The time between a `gate_pending` and its decision is an approval wait; the time from a failure, a pause or a
+killed process to the next `run_resumed` is stopped time; neither is the factory's. Grading after `run_finished` is
+grade time. A finding line says whether a check or a reviewer raised it (`ygg.finding.origin`), a dispute that could not
+be used is a `dispute_ignored` line, and every run records the build of ygg that wrote it (`ygg.factory.version`).
+
 ## Depends on
 
 - Gungnir's interfaces, Gleipnir (adapters, the sandbox, the check runner) and Jormungandr (the loop).
```

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 104eb11..c75e7e4 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -37,6 +37,7 @@ const usage = `usage:
   ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
   ygg status  <run-id> [--project <dir>]
   ygg grade   <run-id> [--task <id>] [--project <dir>]
+  ygg metrics <run-id|first..last> [--json] [--project <dir>]
   ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
   ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -53,7 +54,7 @@ func Main(ctx context.Context, args []string, stdout, stderr io.Writer) int {
 	c := &command{ctx: ctx, out: stdout, err: stderr}
 	cmds := map[string]func([]string) int{
 		"run": c.run, "resume": c.resume, "approve": c.approve, "reject": c.reject,
-		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade, "deps": c.deps,
+		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade, "deps": c.deps, "metrics": c.metrics,
 	}
 	f, ok := cmds[args[0]]
 	if !ok {
@@ -72,7 +73,7 @@ type command struct {
 type flags struct {
 	project, config, graph, realm, brief, mode, note, reason, root, task, canary string
 	realms, rollout                                                              []string        // sandbox build: every --realm given; deps bump: every --rollout given
-	all, host                                                                    bool            // sandbox build: --all; deps bump: --host
+	all, host, json                                                              bool            // sandbox build: --all; deps bump: --host; metrics: --json
 	set                                                                          map[string]bool // the flags given
 }
 
```

Write `internal/cli/metrics.go`:

```go
package cli

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/ouroboric-dev/odin/internal/metrics"
	"github.com/ouroboric-dev/odin/internal/run"
)

// metrics runs ygg metrics: the figures of spec §10.2 for one run, or for the runs between two ids (A..B). It
// reads the run's folder and writes nothing. --json prints the same figures as JSON, for a tool.
func (c *command) metrics(args []string) int {
	f, pos, ok := c.parse("metrics", args, 1, func(fs *flag.FlagSet, f *flags) {
		fs.BoolVar(&f.json, "json", false, "print JSON, not text")
	})
	if !ok {
		return ExitRefused
	}
	project, err := filepath.Abs(f.project)
	if err != nil {
		return c.refuse(err)
	}
	ids, err := runIDs(project, pos[0])
	if err != nil {
		return c.refuse(err)
	}
	var runs []*metrics.Run
	for _, id := range ids {
		r, err := metrics.Collect(run.Dir(project, id))
		if err != nil {
			return c.refuse(err)
		}
		runs = append(runs, r)
	}
	single := !strings.Contains(pos[0], "..")
	switch {
	case f.json && single:
		return c.printJSON(runs[0])
	case f.json:
		return c.printJSON(runs)
	case single:
		runs[0].WriteText(c.out)
	default:
		metrics.WriteRange(c.out, runs)
	}
	return ExitDone
}

func (c *command) printJSON(v any) int {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return c.refuse(err)
	}
	fmt.Fprintf(c.out, "%s\n", b)
	return ExitDone
}

// runIDs resolves "ID" to that run, which must exist, and "A..B" to every run of the project whose id is from A
// to B, in order. Ids start with the time the run began, so their order is the order the runs began in.
func runIDs(project, spec string) ([]string, error) {
	from, to, isRange := strings.Cut(spec, "..")
	if !isRange {
		if !run.ValidID(spec) {
			return nil, fmt.Errorf("%q is not a run id", spec)
		}
		if _, err := os.Stat(run.Dir(project, spec)); err != nil {
			return nil, fmt.Errorf("project %s has no run %s", project, spec)
		}
		return []string{spec}, nil
	}
	if !run.ValidID(from) || !run.ValidID(to) {
		return nil, fmt.Errorf("%q is not a range of two run ids (A..B)", spec)
	}
	if from > to {
		return nil, fmt.Errorf("the range %s is backwards: %s began after %s", spec, from, to)
	}
	entries, err := os.ReadDir(filepath.Join(project, ".factory", "runs"))
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return nil, err
	}
	var ids []string
	for _, e := range entries {
		if e.IsDir() && run.ValidID(e.Name()) && e.Name() >= from && e.Name() <= to {
			ids = append(ids, e.Name())
		}
	}
	if len(ids) == 0 {
		return nil, fmt.Errorf("project %s has no run from %s to %s", project, from, to)
	}
	slices.Sort(ids)
	return ids, nil
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T279: compare two runs

`ygg metrics --compare` is "the result evidence for journal entries" (spec §10.2). This task is its core: what differed
between two setups, the metrics side by side with the delta B minus A, and the verdict for criterion 7. It does not let an
improved metric hide a fallen score, and it does not pretend that two different tasks can be compared. Same branch.

**Files (in `odin`):**

- Create: `internal/metrics/compare.go`, `internal/metrics/compare_test.go`

**Interfaces:**

- Produces: `metrics.Compare(a, b *metrics.Run) *metrics.Comparison` with `A`, `B` (run ids), `Comparable bool`, `Reasons`,
  `Differences []Difference{What, A, B}`, `Rows []Row{Name, A, B, D, Valid, Better, Dec}` and `Row.Delta()`;
  `(*Comparison).Verdict() Verdict{Improved, Worse []string; RewardKnown, RewardHeld bool}`; `(*Comparison).WriteText`.
- The differences, when they differ, in this order: factory build, config hash, mode, graph and version, brief hash, each
  realm's version, each role's agent and model, the task version and the suite (the last two only when both runs were
  graded). *Not comparable* when the brief hashes, the task versions or the suites differ.
- The rows: active time, cost at API prices, billed, cost per task (cost over the plan's tasks, or over the ended loops when
  there is no plan), turns, tokens, first pass, attempts per loop, reviewer veto, interventions, escalations, blocked tasks,
  retries, reward, fail-to-pass passed, escaped defects. Each says which way is better, or none: the veto rate has none,
  and is shown and never judged.

**Acceptance criteria:**

- [ ] A changed factory build, config hash and one role's model are named; what did not differ is not.
- [ ] The deltas are B minus A; cost, interventions, turns and active time down and first pass up are improvements; billed
      cost and cost per task are rows; the veto rate is in neither list.
- [ ] A reward that fell is in `Worse` and the verdict says it did not hold; a run with no grade makes the reward unknown.
- [ ] Runs of another brief and another suite are not comparable, with both reasons in the text.

**Review focus pinned by tests:** `TestAFallingRewardIsNeverHiddenBehindAnImprovedMetric`,
`TestRunsOfAnotherBriefOrSuiteAreNotComparableAndTheReportSaysWhy`.

**Named test:** `go test ./internal/metrics -run 'TestCompareSaysWhatDifferedBetweenTheTwoSetups|TestCompareDeltasAreBMinusAAndNameWhatImprovedAndWhatGotWorse|TestAFallingRewardIsNeverHiddenBehindAnImprovedMetric|TestRunsOfAnotherBriefOrSuiteAreNotComparableAndTheReportSaysWhy|TestCompareTextHasTheDifferencesTheTableAndTheVerdict'`
in `odin`. **Layer:** `odin`. **Size:** M (387). **Depends on:** v0-T277.

- [ ] **Step 1:** write the tests.

Write `internal/metrics/compare_test.go`:

```go
package metrics

import (
	"bytes"
	"strings"
	"testing"
	"time"
)

// variant is sample() as another run: a later id, a changed factory and one role on another model, cheaper,
// with fewer interventions and the same reward.
func variant() *Run {
	r := sample()
	r.ID = "20261024-090000-d4e5f6"
	r.Factory = []string{"odin 0123456789ab gungnir 32cc95d9d0ff"}
	r.ConfigSHA256 = strings.Repeat("d1", 32)
	r.Roles["reviewer"] = Setting{"opencode", "openrouter/qwen/qwen3.9-30b"}
	r.Usage.CostUSD, r.Usage.BilledUSD, r.Usage.Turns = 1.2, 0.2, 380
	r.Interventions = Interventions{Rejections: 0, NotedApprovals: 1, Escalations: 1}
	r.Loops.FirstPass = Ratio{3, 4}
	r.Review.Vetoes = Ratio{1, 9} // fewer vetoes: a reviewer who is satisfied, or one who sees less; the metric has no direction
	r.Time.Active = Duration(50 * time.Minute)
	return r
}

func TestCompareSaysWhatDifferedBetweenTheTwoSetups(t *testing.T) {
	c := Compare(sample(), variant())
	got := map[string][2]string{}
	for _, d := range c.Differences {
		got[d.What] = [2]string{d.A, d.B}
	}
	for _, what := range []string{"factory", "config", "role reviewer"} {
		if _, ok := got[what]; !ok {
			t.Errorf("Differences lacks %q: %+v", what, c.Differences)
		}
	}
	if d := got["role reviewer"]; d[0] != "opencode openrouter/qwen/qwen3.8-27b" || d[1] != "opencode openrouter/qwen/qwen3.9-30b" {
		t.Errorf("role reviewer = %v", d)
	}
	for _, same := range []string{"mode", "graph", "brief", "role implementer", "suite"} {
		if _, ok := got[same]; ok {
			t.Errorf("Differences names %q, which did not differ", same)
		}
	}
}

func TestCompareDeltasAreBMinusAAndNameWhatImprovedAndWhatGotWorse(t *testing.T) {
	c := Compare(sample(), variant())
	rows := map[string]Row{}
	for _, r := range c.Rows {
		rows[r.Name] = r
	}
	if r := rows["cost at API prices (usd)"]; !r.Valid || !near(r.Delta(), -0.3) || r.Better != Lower {
		t.Errorf("cost row = %+v (delta %v)", r, r.Delta())
	}
	if r := rows["billed (usd)"]; !r.Valid || !near(r.A, 0.3) || !near(r.B, 0.2) {
		t.Errorf("billed row = %+v", r)
	}
	if r := rows["first pass (%)"]; !near(r.A, 50) || !near(r.B, 75) || !near(r.Delta(), 25) {
		t.Errorf("first pass row = %+v", r)
	}
	if r := rows["interventions"]; !near(r.Delta(), -2) {
		t.Errorf("interventions row = %+v", r)
	}
	if r := rows["cost per task (usd)"]; !r.Valid || !near(r.A, 0.75) || !near(r.B, 0.6) {
		t.Errorf("cost per task = %+v; want 1.5/2 done tasks... and 1.2/2", r)
	}
	v := c.Verdict()
	for _, want := range []string{"first pass (%)", "cost at API prices (usd)", "interventions", "cost per task (usd)"} {
		if !contains(v.Improved, want) {
			t.Errorf("Improved = %v, want it to hold %q", v.Improved, want)
		}
	}
	if contains(v.Improved, "reviewer veto (%)") || contains(v.Worse, "reviewer veto (%)") {
		t.Errorf("the veto rate has no direction, yet the verdict judged it: %+v", v)
	}
	if len(v.Worse) != 0 || !v.RewardHeld {
		t.Errorf("Verdict = %+v; want nothing worse and the reward held", v)
	}
}

// Spec §2.3 criterion 7: a change counts only if the hidden score did not fall.
func TestAFallingRewardIsNeverHiddenBehindAnImprovedMetric(t *testing.T) {
	b := variant()
	b.Grade.Reward = 0.5
	v := Compare(sample(), b).Verdict()
	if v.RewardHeld || !contains(v.Worse, "reward") {
		t.Errorf("Verdict = %+v; want the reward named as worse and not held", v)
	}
	b = variant()
	b.Grade = nil
	v = Compare(sample(), b).Verdict()
	if v.RewardHeld || v.RewardKnown {
		t.Errorf("Verdict = %+v; a run with no grade cannot show that the reward held", v)
	}
}

func TestRunsOfAnotherBriefOrSuiteAreNotComparableAndTheReportSaysWhy(t *testing.T) {
	b := variant()
	b.BriefSHA256 = strings.Repeat("e2", 32)
	b.Grade.Suite = "v3"
	c := Compare(sample(), b)
	if c.Comparable || len(c.Reasons) != 2 {
		t.Errorf("Comparable = %v, Reasons = %v; want two reasons (brief and suite)", c.Comparable, c.Reasons)
	}
	var w bytes.Buffer
	c.WriteText(&w)
	if out := w.String(); !strings.Contains(out, "comparable:   NO") || !strings.Contains(out, "the briefs differ") || !strings.Contains(out, "the suites differ") {
		t.Errorf("the text does not warn:\n%s", out)
	}
	if !Compare(sample(), variant()).Comparable {
		t.Error("two runs of the same brief and suite must be comparable")
	}
}

func TestCompareTextHasTheDifferencesTheTableAndTheVerdict(t *testing.T) {
	var w bytes.Buffer
	Compare(sample(), variant()).WriteText(&w)
	out := w.String()
	for _, want := range []string{"compare:", "20261023-090000-a1b2c3", "20261024-090000-d4e5f6", "comparable:   yes",
		"what differed:", "role reviewer", "qwen3.9-30b", "metric", "cost at API prices (usd)", "-0.30", "first pass (%)", "+25",
		"improved:", "worse:        none", "reward:       held (0.7125 to 0.7125)", "0.7125"} {
		if !strings.Contains(out, want) {
			t.Errorf("the text lacks %q:\n%s", want, out)
		}
	}
}

func contains(s []string, x string) bool {
	for _, y := range s {
		if y == x {
			return true
		}
	}
	return false
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/metrics [github.com/ouroboric-dev/odin/internal/metrics.test]
internal/metrics/compare_test.go:27:7: undefined: Compare
internal/metrics/compare_test.go:48:7: undefined: Compare
internal/metrics/compare_test.go:49:21: undefined: Row
```

- [ ] **Step 3:** write the code.

Write `internal/metrics/compare.go`:

```go
package metrics

import (
	"fmt"
	"io"
	"maps"
	"math"
	"slices"
	"strings"
	"time"
)

// Direction says which way a metric improves.
type Direction int

const (
	Lower   Direction = -1
	Neutral Direction = 0
	Higher  Direction = 1
)

// Row is one metric of two runs. Valid is false when either run has no value for it.
type Row struct {
	Name   string    `json:"name"`
	A      float64   `json:"a"`
	B      float64   `json:"b"`
	D      float64   `json:"delta"` // B minus A
	Valid  bool      `json:"valid"`
	Better Direction `json:"better"`
	Dec    int       `json:"decimals"` // decimals to print: 0 for a count
}

// Delta is B minus A.
func (r Row) Delta() float64 { return r.D }

// Difference is one thing that differed between the two setups.
type Difference struct {
	What string `json:"what"`
	A    string `json:"a"`
	B    string `json:"b"`
}

// Comparison is ygg metrics --compare: what differed, whether the two runs may be compared, and the deltas.
type Comparison struct {
	A           string       `json:"a"`
	B           string       `json:"b"`
	Comparable  bool         `json:"comparable"`
	Reasons     []string     `json:"reasons"`
	Differences []Difference `json:"differences"`
	Rows        []Row        `json:"rows"`

	a, b *Run
}

// Verdict is what the deltas say for success criterion 7 (design doc §2.3): which metrics improved, which got
// worse, and whether the hidden score held. A change improves the factory only if the score held.
type Verdict struct {
	Improved    []string `json:"improved"`
	Worse       []string `json:"worse"`
	RewardKnown bool     `json:"reward_known"`
	RewardHeld  bool     `json:"reward_held"`
}

// Compare lays two runs side by side. Two runs of another brief, task version or suite are not comparable: the
// deltas are still computed, and the result says why they do not mean what a delta usually means.
func Compare(a, b *Run) *Comparison {
	c := &Comparison{A: a.ID, B: b.ID, a: a, b: b, Comparable: true, Reasons: []string{}, Differences: []Difference{}}
	c.differences()
	c.rows()
	return c
}

func (c *Comparison) differ(what, a, b string) {
	if a != b {
		c.Differences = append(c.Differences, Difference{what, a, b})
	}
}

func (c *Comparison) differences() {
	a, b := c.a, c.b
	c.differ("factory", orNone(strings.Join(a.Factory, "; ")), orNone(strings.Join(b.Factory, "; ")))
	c.differ("config", short(a.ConfigSHA256), short(b.ConfigSHA256))
	c.differ("mode", a.Mode, b.Mode)
	c.differ("graph", a.Graph+" "+a.GraphVersion, b.Graph+" "+b.GraphVersion)
	c.differ("brief", short(a.BriefSHA256), short(b.BriefSHA256))
	for _, name := range union(maps.Keys(a.Realms), maps.Keys(b.Realms)) {
		c.differ("realm "+name, orNone(a.Realms[name]), orNone(b.Realms[name]))
	}
	for _, name := range union(maps.Keys(a.Roles), maps.Keys(b.Roles)) {
		c.differ("role "+name, setting(a.Roles, name), setting(b.Roles, name))
	}
	if a.Grade != nil && b.Grade != nil {
		c.differ("task version", a.Grade.TaskVersion, b.Grade.TaskVersion)
		c.differ("suite", a.Grade.Suite, b.Grade.Suite)
		if a.Grade.TaskVersion != b.Grade.TaskVersion {
			c.Comparable = false
			c.Reasons = append(c.Reasons, "the task versions differ ("+a.Grade.TaskVersion+" and "+b.Grade.TaskVersion+")")
		}
		if a.Grade.Suite != b.Grade.Suite {
			c.Comparable = false
			c.Reasons = append(c.Reasons, "the suites differ ("+a.Grade.Suite+" and "+b.Grade.Suite+"): their scores are not on one scale")
		}
	}
	if a.BriefSHA256 != b.BriefSHA256 {
		c.Comparable = false
		c.Reasons = append(c.Reasons, "the briefs differ: these are two different tasks")
	}
}

func (c *Comparison) rows() {
	a, b := c.a, c.b
	add := func(name string, better Direction, dec int, av, bv float64, valid bool) {
		c.Rows = append(c.Rows, Row{Name: name, A: av, B: bv, D: bv - av, Valid: valid, Better: better, Dec: dec})
	}
	both := func(f func(*Run) (float64, bool)) (float64, float64, bool) {
		x, okx := f(a)
		y, oky := f(b)
		return x, y, okx && oky
	}
	num := func(name string, better Direction, dec int, f func(*Run) (float64, bool)) {
		x, y, ok := both(f)
		add(name, better, dec, x, y, ok)
	}
	always := func(f func(*Run) float64) func(*Run) (float64, bool) {
		return func(r *Run) (float64, bool) { return f(r), true }
	}
	num("active time (min)", Lower, 2, always(func(r *Run) float64 { return time.Duration(r.Time.Active).Minutes() }))
	num("cost at API prices (usd)", Lower, 2, always(func(r *Run) float64 { return r.Usage.CostUSD }))
	num("billed (usd)", Lower, 2, always(func(r *Run) float64 { return r.Usage.BilledUSD }))
	num("cost per task (usd)", Lower, 2, func(r *Run) (float64, bool) {
		n := len(r.Tasks)
		if n == 0 {
			n = r.Loops.Finished
		}
		return r.Usage.CostUSD / float64(max(n, 1)), n > 0
	})
	num("turns", Lower, 0, always(func(r *Run) float64 { return float64(r.Usage.Turns) }))
	num("tokens in", Lower, 0, always(func(r *Run) float64 { return float64(r.Usage.InTok) }))
	num("tokens out", Lower, 0, always(func(r *Run) float64 { return float64(r.Usage.OutTok) }))
	num("first pass (%)", Higher, 2, func(r *Run) (float64, bool) { v, ok := r.Loops.FirstPass.Value(); return v * 100, ok })
	num("attempts per loop", Lower, 2, func(r *Run) (float64, bool) { return r.Loops.AvgAttempts, r.Loops.Finished > 0 })
	num("reviewer veto (%)", Neutral, 2, func(r *Run) (float64, bool) { v, ok := r.Review.Vetoes.Value(); return v * 100, ok })
	num("interventions", Lower, 0, always(func(r *Run) float64 { return float64(r.Interventions.Total()) }))
	num("escalations", Lower, 0, always(func(r *Run) float64 { return float64(r.Interventions.Escalations) }))
	num("blocked tasks", Lower, 0, always(func(r *Run) float64 { return float64(len(r.BlockedTasks)) }))
	num("retries", Lower, 0, always(func(r *Run) float64 { return float64(r.Retries) }))
	graded := func(f func(*Grade) float64) func(*Run) (float64, bool) {
		return func(r *Run) (float64, bool) {
			if r.Grade == nil || r.Grade.Suite == "" {
				return 0, false
			}
			return f(r.Grade), true
		}
	}
	num("reward", Higher, 4, graded(func(g *Grade) float64 { return g.Reward }))
	num("fail-to-pass passed", Higher, 0, graded(func(g *Grade) float64 { return float64(g.FailToPass.Passed) }))
	num("escaped defects", Lower, 0, graded(func(g *Grade) float64 { return float64(g.EscapedDefects) }))
}

// Verdict reads the rows for criterion 7.
func (c *Comparison) Verdict() Verdict {
	v := Verdict{Improved: []string{}, Worse: []string{}}
	for _, r := range c.Rows {
		if !r.Valid || r.Better == Neutral || math.Abs(r.D) < 1e-9 {
			continue
		}
		if (r.D > 0) == (r.Better == Higher) {
			v.Improved = append(v.Improved, r.Name)
		} else {
			v.Worse = append(v.Worse, r.Name)
		}
		if r.Name == "reward" {
			v.RewardKnown = true
		}
	}
	for _, r := range c.Rows {
		if r.Name == "reward" && r.Valid {
			v.RewardKnown = true
			v.RewardHeld = r.D > -1e-9
		}
	}
	return v
}

// WriteText writes the comparison for a journal entry.
func (c *Comparison) WriteText(w io.Writer) {
	line(w, "compare:", "%s  to  %s", c.A, c.B)
	if c.Comparable {
		line(w, "comparable:", "yes (the same brief)")
	} else {
		line(w, "comparable:", "NO: %s", strings.Join(c.Reasons, "; "))
	}
	if len(c.Differences) == 0 {
		line(w, "what differed:", "nothing in the setup")
	} else {
		fmt.Fprintln(w, "what differed:")
		for _, d := range c.Differences {
			fmt.Fprintf(w, "  %-16s %s  ->  %s\n", d.What, d.A, d.B)
		}
	}
	fmt.Fprintf(w, "\n%-24s %12s %12s %10s\n", "metric", "A", "B", "delta")
	for _, r := range c.Rows {
		if !r.Valid {
			fmt.Fprintf(w, "%-24s %12s %12s %10s\n", r.Name, "n/a", "n/a", "")
			continue
		}
		fmt.Fprintf(w, "%-24s %12.*f %12.*f %+10.*f\n", r.Name, r.Dec, r.A, r.Dec, r.B, r.Dec, r.D)
	}
	v := c.Verdict()
	fmt.Fprintln(w)
	line(w, "improved:", "%s", orNone(strings.Join(v.Improved, ", ")))
	line(w, "worse:", "%s", orNone(strings.Join(v.Worse, ", ")))
	switch {
	case !v.RewardKnown && !v.hasReward(c):
		line(w, "reward:", "unknown (a run has no grade)")
	case v.RewardHeld:
		line(w, "reward:", "held (%.4f to %.4f)", c.a.Grade.Reward, c.b.Grade.Reward)
	default:
		line(w, "reward:", "NOT held (%.4f to %.4f)", c.a.Grade.Reward, c.b.Grade.Reward)
	}
}

func (v Verdict) hasReward(c *Comparison) bool {
	return c.a.Grade != nil && c.b.Grade != nil && c.a.Grade.Suite != "" && c.b.Grade.Suite != ""
}

func orNone(s string) string {
	if s == "" {
		return "none"
	}
	return s
}

func setting(m map[string]Setting, name string) string {
	s, ok := m[name]
	if !ok {
		return "none"
	}
	return s.Agent + " " + s.Model
}

func union(a, b func(func(string) bool)) []string {
	set := map[string]bool{}
	for k := range a {
		set[k] = true
	}
	for k := range b {
		set[k] = true
	}
	return slices.Sorted(maps.Keys(set))
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T280: `ygg metrics --compare`

The verb for v0-T279: `ygg metrics --compare <runA> <runB> [--json]` for two runs of one project. It refuses a range, one id or
a run that is not there. Same branch.

**Files (in `odin`):**

- Create: `internal/cli/metrics_compare.go`
- Modify: `README.md`, `docs/architecture.md`, `internal/cli/cli.go`, `internal/cli/docs_test.go`, `internal/cli/metrics.go`, `internal/cli/metrics_test.go`

**Interfaces:**

- Produces: `ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]`. Exit 0, or 2 for a refusal.

**Acceptance criteria:**

- [ ] On two real scripted runs the text has "compare:", both ids, "comparable:   yes", the table with "cost at API prices
      (usd)" and "interventions", and "reward:"; `--json` has `comparable` and rows.
- [ ] The README and the architecture page name `--compare` and "not comparable".

**Named test:** `go test ./internal/cli -run 'TestYggMetricsCompareOfTwoRealRunsPrintsTheDeltas|TestTheDocsNameEveryCommand'`
in `odin`. **Layer:** `odin`. **Size:** S (86). **Depends on:** v0-T278, v0-T279.

- [ ] **Step 1:** write the tests.

Apply to `internal/cli/docs_test.go`:

```diff
diff --git a/internal/cli/docs_test.go b/internal/cli/docs_test.go
index 3774980..7930a44 100644
--- a/internal/cli/docs_test.go
+++ b/internal/cli/docs_test.go
@@ -30,7 +30,7 @@ func TestTheDocsNameEveryCommand(t *testing.T) {
 	}
 	for _, want := range []string{"ygg grade", "ygg deps bump", "`grade` node", "--canary", "--host", "--task", "grade_refused", "score.json", "ygg.grader",
 		"REPOS.md", ".ygg/impact.json", "shrink guard", "pointer-contract", "routing_index_built", "pointer_contract_checked", "deps_bump", "memory: none",
-		"ygg metrics", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
+		"ygg metrics", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
 		if !strings.Contains(string(arch), want) {
 			t.Errorf("docs/architecture.md does not mention %q", want)
 		}
```

Apply to `internal/cli/metrics_test.go`:

```diff
diff --git a/internal/cli/metrics_test.go b/internal/cli/metrics_test.go
index 77c5e32..498e621 100644
--- a/internal/cli/metrics_test.go
+++ b/internal/cli/metrics_test.go
@@ -111,3 +111,26 @@ func anotherRun(t *testing.T, dir, config string) string {
 	}
 	return id
 }
+
+func TestYggMetricsCompareOfTwoRealRunsPrintsTheDeltas(t *testing.T) {
+	dir, config := project(t, "script.yaml", "mode: key-points\n")
+	first, _ := walk(t, dir, config)
+	second := anotherRun(t, dir, config)
+	code, out, errOut := ygg(t, "metrics", "--compare", first, second, "--project", dir)
+	if code != ExitDone {
+		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
+	}
+	for _, want := range []string{"compare:", first, second, "comparable:   yes", "metric", "cost at API prices (usd)", "interventions", "reward:"} {
+		if !strings.Contains(out, want) {
+			t.Errorf("the comparison lacks %q:\n%s", want, out)
+		}
+	}
+	code, out, _ = ygg(t, "metrics", "--compare", first, second, "--project", dir, "--json")
+	var got struct {
+		Comparable bool
+		Rows       []struct{ Name string }
+	}
+	if err := json.Unmarshal([]byte(out), &got); code != ExitDone || err != nil || !got.Comparable || len(got.Rows) == 0 {
+		t.Errorf("--json: exit %d, %v, %+v", code, err, got)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTheDocsNameEveryCommand (0.00s)
    docs_test.go:35: docs/architecture.md does not mention "--compare"
    docs_test.go:35: docs/architecture.md does not mention "not comparable"
--- FAIL: TestYggMetricsCompareOfTwoRealRunsPrintsTheDeltas (2.51s)
```

- [ ] **Step 3:** write the code.

Apply to `README.md`:

```diff
diff --git a/README.md b/README.md
index 25c8189..96802d4 100644
--- a/README.md
+++ b/README.md
@@ -23,6 +23,7 @@ ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
 ygg status  <run-id> [--project <dir>]
 ygg grade   <run-id> [--task <id>] [--project <dir>]
 ygg metrics <run-id|first..last> [--json] [--project <dir>]
+ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
 ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
 ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
 ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -45,6 +46,12 @@ routing indexes scored. A rate over nothing says `n/a`. It checks the ledger's h
 was changed. `first..last` lists every run of the project from one id to the other, with a total line. `--json` prints the
 same figures for a tool. It writes nothing.
 
+`ygg metrics --compare <runA> <runB>` prints what differed between two runs of one project (the factory build, the
+config hash, the agent and model of each role, the realm versions, the mode, the graph) and the deltas, B minus A.
+Runs of another brief, task version or suite are marked as not comparable, with the reason, and the deltas are still
+printed. It names the metrics that improved and the ones that got worse, and says whether the hidden score held: a
+factory change counts only if it did (design doc §2.3, criterion 7).
+
 `ygg deps bump` runs the package manager and the checks in the sandbox of `factory.yaml`. Without a `sandbox:`
 section it refuses (exit 2) unless you pass `--host`, which runs the bump on the host with the full network and
 your user id, and records that in the first line of the bump's ledger. With a sandbox section `--host` has no effect.
```

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 8facdca..a7aaeeb 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -147,6 +147,11 @@ killed process to the next `run_resumed` is stopped time; neither is the factory
 grade time. A finding line says whether a check or a reviewer raised it (`ygg.finding.origin`), a dispute that could not
 be used is a `dispute_ignored` line, and every run records the build of ygg that wrote it (`ygg.factory.version`).
 
+`ygg metrics --compare <runA> <runB>` lays two runs side by side: what differed in the setup, the metrics with the delta
+B minus A, and a verdict for success criterion 7 (the metrics that improved, the ones that got worse, and whether the hidden
+score held). Runs of another brief, task version or suite are marked not comparable, with the reason, because their
+scores are not on one scale. Metrics with no direction, such as the reviewer veto rate, are shown and never judged.
+
 ## Depends on
 
 - Gungnir's interfaces, Gleipnir (adapters, the sandbox, the check runner) and Jormungandr (the loop).
```

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index c75e7e4..75545db 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -38,6 +38,7 @@ const usage = `usage:
   ygg status  <run-id> [--project <dir>]
   ygg grade   <run-id> [--task <id>] [--project <dir>]
   ygg metrics <run-id|first..last> [--json] [--project <dir>]
+  ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
   ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
   ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
```

Apply to `internal/cli/metrics.go`:

```diff
diff --git a/internal/cli/metrics.go b/internal/cli/metrics.go
index 39cb870..b67b5d6 100644
--- a/internal/cli/metrics.go
+++ b/internal/cli/metrics.go
@@ -18,6 +18,9 @@ import (
 // metrics runs ygg metrics: the figures of spec §10.2 for one run, or for the runs between two ids (A..B). It
 // reads the run's folder and writes nothing. --json prints the same figures as JSON, for a tool.
 func (c *command) metrics(args []string) int {
+	if i := slices.Index(args, "--compare"); i >= 0 {
+		return c.compare(slices.Delete(slices.Clone(args), i, i+1))
+	}
 	f, pos, ok := c.parse("metrics", args, 1, func(fs *flag.FlagSet, f *flags) {
 		fs.BoolVar(&f.json, "json", false, "print JSON, not text")
 	})
@@ -98,3 +101,7 @@ func runIDs(project, spec string) ([]string, error) {
 	slices.Sort(ids)
 	return ids, nil
 }
+
+func errNotOneRun(spec string) error {
+	return fmt.Errorf("%q is not one run id: compare takes two ids, not a range", spec)
+}
```

Write `internal/cli/metrics_compare.go`:

```go
package cli

import (
	"flag"
	"path/filepath"

	"github.com/ouroboric-dev/odin/internal/metrics"
	"github.com/ouroboric-dev/odin/internal/run"
)

// compare runs ygg metrics --compare <runA> <runB>: what differed between two runs and the deltas (spec §10.2).
func (c *command) compare(args []string) int {
	f, pos, ok := c.parse("metrics --compare", args, 2, func(fs *flag.FlagSet, f *flags) {
		fs.BoolVar(&f.json, "json", false, "print JSON, not text")
	})
	if !ok {
		return ExitRefused
	}
	project, err := filepath.Abs(f.project)
	if err != nil {
		return c.refuse(err)
	}
	var runs [2]*metrics.Run
	for i, id := range pos {
		ids, err := runIDs(project, id)
		if err != nil || len(ids) != 1 || id != ids[0] {
			if err == nil {
				err = errNotOneRun(id)
			}
			return c.refuse(err)
		}
		if runs[i], err = metrics.Collect(run.Dir(project, id)); err != nil {
			return c.refuse(err)
		}
	}
	cmp := metrics.Compare(runs[0], runs[1])
	if f.json {
		return c.printJSON(cmp)
	}
	cmp.WriteText(c.out)
	return ExitDone
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T281: `ygg report`

`report.md` for a run (spec §10.3): what a person reads after a run. The tasks the run gave up come first (spec §7.3), then
the metrics, the interventions with their notes, the loops that gave up and, for each finding a dispute overruled, the
reviewer's claim, the implementer's evidence and the check that settled it: "an overruled finding is the implementer's word
backed by one test" (B-115). Everything an agent wrote is quoted. The same run gives the same bytes, and the report names the
ledger line it was read from. This task adds the list of interventions to the metrics for it (`Interventions.Items`). Same
branch.

**Files (in `odin`):**

- Create: `internal/cli/report.go`, `internal/cli/report_test.go`, `internal/report/report.go`, `internal/report/report_test.go`
- Modify: `README.md`, `docs/architecture.md`, `internal/cli/cli.go`, `internal/cli/docs_test.go`, `internal/metrics/loops_test.go`, `internal/metrics/measures.go`

**Interfaces:**

- Produces: `metrics.Item{Kind, Node, Note}` and `Interventions.Items`: each rejection, approval with a note and escalation
  in the order of the ledger.
- Produces: `report.Write(w io.Writer, m *metrics.Run, st *run.State) error`.
- Produces: `ygg report <run-id> [--commit] [--project <dir>]`: writes `<project>/.factory/runs/<run-id>/report.md` and prints
  its path. With `--commit` it also writes `docs/runs/<run-id>.md` in the project and commits that one file with the message
  `Report of run <run-id>`; other changes in the project stay out of the commit.

**Acceptance criteria:**

- [ ] "Blocked tasks" is the first section, "None." when there are none; "Metrics" is a text block that holds the report of
      v0-T277 with no line that is a fence.
- [ ] An overruled finding shows its id, severity, source, location, the claim, the evidence and the check; a claim that holds a
      heading and a fence stays inside its quote.
- [ ] Interventions are a table with the note of each; a loop that gave up shows its reason and detail.
- [ ] The report names the ledger line (`seq` and the first 12 characters of the hash) and two reports of one run are equal.
- [ ] `--commit` commits only `docs/runs/<run-id>.md`; a range, a path or a run that is not there is refused with exit 2.

**Review focus pinned by tests:** `TestTextAnAgentWroteCannotBreakOutOfItsQuoteOrItsBlock`,
`TestBlockedTasksComeBeforeEverythingElseAndANoneIsSaid`.

**Named test:** `go test ./internal/report ./internal/metrics ./internal/cli -run 'TestBlockedTasksComeBeforeEverythingElseAndANoneIsSaid|TestAnOverruledFindingShowsTheReviewersClaimTheImplementersEvidenceAndTheCheck|TestTextAnAgentWroteCannotBreakOutOfItsQuoteOrItsBlock|TestInterventionsAndGivenUpLoopsAreListedWithTheirReasons|TestTheReportNamesTheLedgerPositionItWasReadFromAndIsTheSameEveryTime|TestEachInterventionIsListedWithWhereItHappenedAndItsNote|TestYggReport|TestTheDocsNameEveryCommand'`
in `odin`. **Layer:** `odin`. **Size:** M (398). **Depends on:** v0-T280.

- [ ] **Step 1:** write the tests.

Apply to `internal/cli/docs_test.go`:

```diff
diff --git a/internal/cli/docs_test.go b/internal/cli/docs_test.go
index 7930a44..dee7516 100644
--- a/internal/cli/docs_test.go
+++ b/internal/cli/docs_test.go
@@ -30,7 +30,7 @@ func TestTheDocsNameEveryCommand(t *testing.T) {
 	}
 	for _, want := range []string{"ygg grade", "ygg deps bump", "`grade` node", "--canary", "--host", "--task", "grade_refused", "score.json", "ygg.grader",
 		"REPOS.md", ".ygg/impact.json", "shrink guard", "pointer-contract", "routing_index_built", "pointer_contract_checked", "deps_bump", "memory: none",
-		"ygg metrics", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
+		"ygg metrics", "ygg report", "docs/runs", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
 		if !strings.Contains(string(arch), want) {
 			t.Errorf("docs/architecture.md does not mention %q", want)
 		}
```

Write `internal/cli/report_test.go`:

```go
package cli

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
)

func TestYggReportWritesReportMDInTheRunFolderAndWritesItTheSameWayTwice(t *testing.T) {
	dir, config := project(t, "script.yaml", "mode: key-points\n")
	id, _ := walk(t, dir, config)
	code, out, errOut := ygg(t, "report", id, "--project", dir)
	if code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	path := filepath.Join(run.Dir(dir, id), "report.md")
	first, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("report.md was not written: %v", err)
	}
	if !strings.Contains(out, path) || !strings.HasPrefix(string(first), "# Run "+id) || !strings.Contains(string(first), "## Blocked tasks") {
		t.Errorf("stdout %q, report.md:\n%s", out, first)
	}
	if code, _, _ = ygg(t, "report", id, "--project", dir); code != ExitDone {
		t.Fatal("a second report failed")
	}
	if second, _ := os.ReadFile(path); string(second) != string(first) {
		t.Error("two reports of one run differ")
	}
}

func TestYggReportCommitCopiesTheReportIntoTheProjectAndCommitsOnlyIt(t *testing.T) {
	dir, config := project(t, "script.yaml", "mode: key-points\n")
	id, _ := walk(t, dir, config)
	os.WriteFile(filepath.Join(dir, "unrelated.txt"), []byte("not mine"), 0o644)
	if code, out, errOut := ygg(t, "report", id, "--commit", "--project", dir); code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	copy, err := os.ReadFile(filepath.Join(dir, "docs", "runs", id+".md"))
	if err != nil || !strings.HasPrefix(string(copy), "# Run "+id) {
		t.Fatalf("docs/runs/%s.md: %v", id, err)
	}
	files, _ := git.Run(context.Background(), dir, "show", "--name-only", "--format=%s", "HEAD")
	if !strings.HasPrefix(files, "Report of run "+id) || !strings.Contains(files, "docs/runs/"+id+".md") || strings.Contains(files, "unrelated.txt") {
		t.Errorf("the last commit is %q; want only the report", files)
	}
}

func TestYggReportRefusesWhatItCannotTrust(t *testing.T) {
	dir, config := project(t, "script.yaml", "mode: key-points\n")
	id, _ := walk(t, dir, config)
	for name, args := range map[string][]string{
		"no id": {"report", "--project", dir}, "a path": {"report", "../x", "--project", dir},
		"a range": {"report", id + ".." + id, "--project", dir}, "a run that is not there": {"report", "20200101-000000-aaaaaa", "--project", dir},
	} {
		if code, _, errOut := ygg(t, args...); code != ExitRefused || errOut == "" {
			t.Errorf("%s: exit %d, stderr %q", name, code, errOut)
		}
	}
}
```

Apply to `internal/metrics/loops_test.go`:

```diff
diff --git a/internal/metrics/loops_test.go b/internal/metrics/loops_test.go
index 5fad775..22ef32c 100644
--- a/internal/metrics/loops_test.go
+++ b/internal/metrics/loops_test.go
@@ -93,3 +93,22 @@ func TestInterventionsAreRejectionsNotedApprovalsAndEscalations(t *testing.T) {
 		t.Errorf("Interventions = %+v; want 1 rejection, 1 noted approval, 1 escalation, 3 in all", got)
 	}
 }
+
+func TestEachInterventionIsListedWithWhereItHappenedAndItsNote(t *testing.T) {
+	f := newFake(t)
+	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
+	f.log(1, gungnir.Event{Name: gungnir.EventGateApproved, Node: "x-contract-gate", Gate: "x-contract-gate", Note: "the contract change is in the spec"})
+	f.log(2, gungnir.Event{Name: gungnir.EventGateRejected, Node: "plan-gate", Gate: "plan-gate", Note: "split task 3"})
+	f.log(3, gungnir.Event{Name: gungnir.EventEscalation, Node: "y-implement", Attempt: 3, Result: "attempts-exhausted"})
+	f.log(4, gungnir.Event{Name: gungnir.EventGateApproved, Node: "design-gate", Gate: "design-gate"}) // plain: not an intervention
+	got := mustCollect(t, f.done()).Interventions.Items
+	want := []Item{{"approval with a note", "x-contract-gate", "the contract change is in the spec"}, {"rejection", "plan-gate", "split task 3"}, {"escalation", "y-implement", "attempts-exhausted"}}
+	if len(got) != len(want) {
+		t.Fatalf("Items = %+v, want %+v", got, want)
+	}
+	for i := range want {
+		if got[i] != want[i] {
+			t.Errorf("Items[%d] = %+v, want %+v", i, got[i], want[i])
+		}
+	}
+}
```

Write `internal/report/report_test.go`:

````go
package report

import (
	"bytes"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/jormungandr"
	"github.com/ouroboric-dev/odin/internal/ledger"
	"github.com/ouroboric-dev/odin/internal/metrics"
	"github.com/ouroboric-dev/odin/internal/run"
)

func fixture() (*metrics.Run, *run.State) {
	m := &metrics.Run{ID: "20261023-090000-a1b2c3", Status: "done", Mode: "key-points", Graph: "software", GraphVersion: "0.1.0",
		Factory: []string{"odin b8c9716fa818"}, Roles: map[string]metrics.Setting{}, Realms: map[string]string{},
		BlockedTasks: []metrics.BlockedTask{{Task: "g-T2", Why: "attempts-exhausted in implement"}},
		Interventions: metrics.Interventions{Escalations: 1, NotedApprovals: 1, Items: []metrics.Item{
			{Kind: "approval with a note", Node: "g-t1-contract-gate", Note: "the contract change is in the spec"},
			{Kind: "escalation", Node: "g-t2-implement", Note: "attempts-exhausted"}}}}
	st := &run.State{ID: m.ID, Ledger: ledger.Anchor{Seq: 26, Hash: "976c4a0eb053d2bf4182cb5c2e108a9d622ee44fc0eb4d164a6151a51a1bcf8b"},
		Loops: map[string]*run.LoopRecord{
			"g-t1-implement": {State: jormungandr.State{Book: jormungandr.Book{Records: map[string]*jormungandr.Record{
				"spec-1": {Finding: gungnir.Finding{ID: "spec-1", Source: "spec", Severity: gungnir.SeverityBlocker, Location: "build.txt:1",
					Claim: "findIndex is not a JavaScript method.\n# A heading the reviewer slipped in\n```\nescape", Status: gungnir.FindingOverruled,
					Proof: "curl showed findIndex is defined; TestFindIndex runs it"}, OverruledBy: "unit"}}}}},
			"g-t2-implement": {Escalation: &run.Escalation{Reason: "attempts-exhausted", Detail: "attempt 3 of 3 ended with 1 blocking finding open"}},
		}}
	return m, st
}

func render(t *testing.T) string {
	t.Helper()
	m, st := fixture()
	var b bytes.Buffer
	if err := Write(&b, m, st); err != nil {
		t.Fatal(err)
	}
	return b.String()
}

// Spec §7.3: a blocked task is listed first in the run report.
func TestBlockedTasksComeBeforeEverythingElseAndANoneIsSaid(t *testing.T) {
	out := render(t)
	blocked, metricsAt := strings.Index(out, "## Blocked tasks"), strings.Index(out, "## Metrics")
	if blocked < 0 || metricsAt < 0 || blocked > metricsAt || !strings.Contains(out, "g-T2: attempts-exhausted in implement") {
		t.Errorf("the blocked tasks are not first:\n%s", out)
	}
	m, st := fixture()
	m.BlockedTasks = nil
	var b bytes.Buffer
	Write(&b, m, st)
	if !strings.Contains(b.String(), "## Blocked tasks\n\nNone.") {
		t.Errorf("a report with no blocked task must say so:\n%s", b.String())
	}
}

// B-115: an overruled finding is the implementer's word backed by one test. The reader sees both sides.
func TestAnOverruledFindingShowsTheReviewersClaimTheImplementersEvidenceAndTheCheck(t *testing.T) {
	out := render(t)
	for _, want := range []string{"## Findings a dispute overruled", "spec-1", "blocker", "from spec", "build.txt:1",
		"Reviewer's claim", "findIndex is not a JavaScript method", "Implementer's evidence", "TestFindIndex runs it", "Settled by the check `unit`"} {
		if !strings.Contains(out, want) {
			t.Errorf("the report lacks %q:\n%s", want, out)
		}
	}
}

// An agent wrote the claim, and a blocked task's reason can hold agent text too. Whatever it holds must stay
// inside its quote or its block: it cannot open a heading or end a fence of the report.
func TestTextAnAgentWroteCannotBreakOutOfItsQuoteOrItsBlock(t *testing.T) {
	m, st := fixture()
	m.BlockedTasks[0].Why = "gave up\n```\n# injected heading"
	var b bytes.Buffer
	if err := Write(&b, m, st); err != nil {
		t.Fatal(err)
	}
	out := b.String()
	fences := 0
	for _, l := range strings.Split(out, "\n") {
		if strings.Contains(l, "A heading the reviewer slipped in") && !strings.HasPrefix(l, "> ") {
			t.Errorf("an agent's line is outside its quote: %q", l)
		}
		if strings.HasPrefix(l, "```") {
			fences++
		}
		if strings.HasPrefix(l, "# injected") {
			t.Errorf("an injected heading is live: %q", l)
		}
	}
	if fences != 2 {
		t.Errorf("the report has %d fence lines, want 2 (the metrics block opens and closes once):\n%s", fences, out)
	}
}

func TestInterventionsAndGivenUpLoopsAreListedWithTheirReasons(t *testing.T) {
	out := render(t)
	for _, want := range []string{"## Interventions", "the contract change is in the spec", "g-t1-contract-gate",
		"## Loops that gave up", "g-t2-implement", "attempts-exhausted", "attempt 3 of 3 ended with 1 blocking finding open"} {
		if !strings.Contains(out, want) {
			t.Errorf("the report lacks %q:\n%s", want, out)
		}
	}
}

func TestTheReportNamesTheLedgerPositionItWasReadFromAndIsTheSameEveryTime(t *testing.T) {
	out := render(t)
	if !strings.Contains(out, "ledger line 26") || !strings.Contains(out, "sha256 976c4a0eb053") {
		t.Errorf("the report does not say which ledger line its numbers come from:\n%s", out)
	}
	if again := render(t); again != out {
		t.Error("two renders of one run differ")
	}
}
````

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/report [github.com/ouroboric-dev/odin/internal/report.test]
internal/report/report_test.go:19:75: unknown field Items in struct literal of type metrics.Interventions
internal/report/report_test.go:19:92: undefined: metrics.Item
internal/report/report_test.go:37:12: undefined: Write
```

- [ ] **Step 3:** write the code.

Apply to `README.md`:

```diff
diff --git a/README.md b/README.md
index 96802d4..bae6f5a 100644
--- a/README.md
+++ b/README.md
@@ -24,6 +24,7 @@ ygg status  <run-id> [--project <dir>]
 ygg grade   <run-id> [--task <id>] [--project <dir>]
 ygg metrics <run-id|first..last> [--json] [--project <dir>]
 ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
+ygg report  <run-id> [--commit] [--project <dir>]
 ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
 ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
 ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -52,6 +53,11 @@ Runs of another brief, task version or suite are marked as not comparable, with
 printed. It names the metrics that improved and the ones that got worse, and says whether the hidden score held: a
 factory change counts only if it did (design doc §2.3, criterion 7).
 
+`ygg report <run-id>` writes `report.md` into the run's folder: the tasks the run gave up first, the metrics, every
+intervention with its note, the loops that gave up, and each finding a dispute overruled with both sides. It names the
+ledger line it was read from, and the same run always gives the same bytes. Text an agent wrote is quoted, so it cannot
+open a heading or end a block. `--commit` also commits a copy as `docs/runs/<run-id>.md`, because a project ignores `.factory/`.
+
 `ygg deps bump` runs the package manager and the checks in the sandbox of `factory.yaml`. Without a `sandbox:`
 section it refuses (exit 2) unless you pass `--host`, which runs the bump on the host with the full network and
 your user id, and records that in the first line of the bump's ledger. With a sandbox section `--host` has no effect.
```

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index a7aaeeb..d0fdef5 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -152,6 +152,10 @@ B minus A, and a verdict for success criterion 7 (the metrics that improved, the
 score held). Runs of another brief, task version or suite are marked not comparable, with the reason, because their
 scores are not on one scale. Metrics with no direction, such as the reviewer veto rate, are shown and never judged.
 
+`ygg report` (package `internal/report`) renders the run report of spec §10.3 as Markdown from the same checked figures,
+the interventions with their notes, and the loops' records in `run.json`. With `--commit` a copy is committed as
+`docs/runs/<run-id>.md`, because a project ignores `.factory/`.
+
 ## Depends on
 
 - Gungnir's interfaces, Gleipnir (adapters, the sandbox, the check runner) and Jormungandr (the loop).
```

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 75545db..3acb75c 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -39,6 +39,7 @@ const usage = `usage:
   ygg grade   <run-id> [--task <id>] [--project <dir>]
   ygg metrics <run-id|first..last> [--json] [--project <dir>]
   ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
+  ygg report  <run-id> [--commit] [--project <dir>]
   ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
   ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -55,7 +56,7 @@ func Main(ctx context.Context, args []string, stdout, stderr io.Writer) int {
 	c := &command{ctx: ctx, out: stdout, err: stderr}
 	cmds := map[string]func([]string) int{
 		"run": c.run, "resume": c.resume, "approve": c.approve, "reject": c.reject,
-		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade, "deps": c.deps, "metrics": c.metrics,
+		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade, "deps": c.deps, "metrics": c.metrics, "report": c.report,
 	}
 	f, ok := cmds[args[0]]
 	if !ok {
```

Write `internal/cli/report.go`:

```go
package cli

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/metrics"
	"github.com/ouroboric-dev/odin/internal/report"
	"github.com/ouroboric-dev/odin/internal/run"
)

// report runs ygg report: it writes report.md into the run's folder (spec §10.3). With --commit it also commits
// a copy as docs/runs/<run-id>.md, the one file, because a project ignores the run folder.
func (c *command) report(args []string) int {
	var commit bool
	f, pos, ok := c.parse("report", args, 1, func(fs *flag.FlagSet, f *flags) {
		fs.BoolVar(&commit, "commit", false, "also commit a copy as docs/runs/<run-id>.md")
	})
	if !ok {
		return ExitRefused
	}
	project, err := filepath.Abs(f.project)
	if err != nil {
		return c.refuse(err)
	}
	ids, err := runIDs(project, pos[0])
	if err != nil || len(ids) != 1 || ids[0] != pos[0] {
		if err == nil {
			err = errNotOneRun(pos[0])
		}
		return c.refuse(err)
	}
	dir := run.Dir(project, pos[0])
	m, err := metrics.Collect(dir)
	if err != nil {
		return c.refuse(err)
	}
	st, err := run.LoadState(dir)
	if err != nil {
		return c.refuse(err)
	}
	var b bytes.Buffer
	if err := report.Write(&b, m, st); err != nil {
		return c.refuse(err)
	}
	path := filepath.Join(dir, "report.md")
	if err := os.WriteFile(path, b.Bytes(), 0o644); err != nil {
		return c.refuse(err)
	}
	fmt.Fprintf(c.out, "report: %s\n", path)
	if !commit {
		return ExitDone
	}
	rel := filepath.Join("docs", "runs", pos[0]+".md")
	if err := os.MkdirAll(filepath.Join(project, "docs", "runs"), 0o755); err != nil {
		return c.refuse(err)
	}
	if err := os.WriteFile(filepath.Join(project, rel), b.Bytes(), 0o644); err != nil {
		return c.refuse(err)
	}
	if _, err := git.Run(c.ctx, project, "add", "--", rel); err != nil {
		return c.refuse(err)
	}
	if _, err := git.Run(c.ctx, project, "commit", "-q", "-m", "Report of run "+pos[0], "--", rel); err != nil {
		return c.refuse(err)
	}
	fmt.Fprintf(c.out, "committed: %s\n", rel)
	return ExitDone
}
```

Apply to `internal/metrics/measures.go`:

```diff
diff --git a/internal/metrics/measures.go b/internal/metrics/measures.go
index c919936..e30154f 100644
--- a/internal/metrics/measures.go
+++ b/internal/metrics/measures.go
@@ -45,11 +45,19 @@ type Findings struct {
 	DisputesIgnored    int `json:"disputes_ignored"`
 }
 
+// Item is one intervention: what kind, where, and what the person or the loop said.
+type Item struct {
+	Kind string `json:"kind"` // rejection, approval with a note or escalation
+	Node string `json:"node"`
+	Note string `json:"note"`
+}
+
 // Interventions are the times a person had to step in (spec §7.2).
 type Interventions struct {
-	Rejections     int `json:"rejections"`
-	NotedApprovals int `json:"noted_approvals"`
-	Escalations    int `json:"escalations"`
+	Rejections     int    `json:"rejections"`
+	NotedApprovals int    `json:"noted_approvals"`
+	Escalations    int    `json:"escalations"`
+	Items          []Item `json:"items"`
 }
 
 // Total is every intervention.
@@ -92,12 +100,15 @@ func (r *Run) measure(state *record, events []gungnir.Event) error {
 			}
 		case gungnir.EventEscalation:
 			r.Interventions.Escalations++
+			r.Interventions.Items = append(r.Interventions.Items, Item{"escalation", e.Node, e.Result})
 			end(e.Node, e.Attempt, false)
 		case gungnir.EventGateRejected:
 			r.Interventions.Rejections++
+			r.Interventions.Items = append(r.Interventions.Items, Item{"rejection", e.Node, e.Note})
 		case gungnir.EventGateApproved:
 			if e.Note != "" {
 				r.Interventions.NotedApprovals++
+				r.Interventions.Items = append(r.Interventions.Items, Item{"approval with a note", e.Node, e.Note})
 			}
 		case gungnir.EventNodeFinished, gungnir.EventNodeFailed:
 			if loop, ok := loopOf(e.Node, loops); ok {
```

Write `internal/report/report.go`:

````go
// Package report renders the run report of spec §10.3 as Markdown: the tasks the run gave up first (spec §7.3),
// the metrics, the interventions, and the findings a dispute overruled with both sides (B-115).
package report

import (
	"cmp"
	"fmt"
	"io"
	"maps"
	"slices"
	"strings"

	"github.com/ouroboric-dev/jormungandr"
	"github.com/ouroboric-dev/odin/internal/engine"
	"github.com/ouroboric-dev/odin/internal/metrics"
	"github.com/ouroboric-dev/odin/internal/run"
)

// Write renders the report. The same run always gives the same bytes: nothing in it is the time of writing.
func Write(w io.Writer, m *metrics.Run, st *run.State) error {
	var b strings.Builder
	fmt.Fprintf(&b, "# Run %s\n\n", m.ID)
	fmt.Fprintf(&b, "%s, %s mode, graph %s %s. Read from ledger line %d (sha256 %.12s): quote the run id and that line to cite a number.\n\n",
		m.Status, m.Mode, m.Graph, m.GraphVersion, st.Ledger.Seq, st.Ledger.Hash)

	b.WriteString("## Blocked tasks\n\n")
	if len(m.BlockedTasks) == 0 {
		b.WriteString("None.\n\n")
	}
	for _, t := range m.BlockedTasks {
		fmt.Fprintf(&b, "- %s: %s\n", t.Task, oneLine(t.Why))
	}
	if len(m.BlockedTasks) > 0 {
		b.WriteString("\n")
	}

	var text strings.Builder
	m.WriteText(&text)
	// The block is a fence, and part of its text can come from an agent: no line of it may be a fence.
	b.WriteString("## Metrics\n\n```text\n" + strings.ReplaceAll(text.String(), "```", "'''") + "```\n\n")

	b.WriteString("## Interventions\n\n")
	if len(m.Interventions.Items) == 0 {
		b.WriteString("None.\n\n")
	} else {
		b.WriteString("| Kind | Where | Note |\n| --- | --- | --- |\n")
		for _, it := range m.Interventions.Items {
			fmt.Fprintf(&b, "| %s | %s | %s |\n", cell(it.Kind), cell(it.Node), cell(it.Note))
		}
		b.WriteString("\n")
	}

	gave := false
	for _, id := range slices.Sorted(maps.Keys(st.Loops)) {
		if e := st.Loops[id].Escalation; e != nil {
			if !gave {
				b.WriteString("## Loops that gave up\n\n")
				gave = true
			}
			fmt.Fprintf(&b, "- %s: %s. %s\n", id, oneLine(e.Reason), oneLine(e.Detail))
		}
	}
	if gave {
		b.WriteString("\n")
	}

	overruled := false
	for _, id := range slices.Sorted(maps.Keys(st.Loops)) {
		for _, o := range slices.SortedFunc(slices.Values(engine.Overruled(&st.Loops[id].State)), func(a, b jormungandr.Record) int { return cmp.Compare(a.ID, b.ID) }) {
			if !overruled {
				b.WriteString("## Findings a dispute overruled\n\nEach is the implementer's word, backed by one check. Read both sides.\n\n")
				overruled = true
			}
			fmt.Fprintf(&b, "### %s in %s\n\n%s, from %s, at %s. Settled by the check `%s`.\n\nReviewer's claim:\n\n%s\n\nImplementer's evidence:\n\n%s\n\n",
				o.ID, id, o.Severity, o.Source, oneLine(o.Location), oneLine(o.OverruledBy), quote(o.Claim), quote(o.Proof))
		}
	}
	_, err := io.WriteString(w, b.String())
	return err
}

// quote puts text an agent wrote inside a block quote, line by line, so it cannot open a heading, a table or
// a fence of the report.
func quote(s string) string {
	lines := strings.Split(strings.TrimSpace(s), "\n")
	for i, l := range lines {
		lines[i] = "> " + l
	}
	return strings.Join(lines, "\n")
}

// cell makes text fit in one table cell.
func cell(s string) string {
	return strings.ReplaceAll(oneLine(s), "|", "\\|")
}

func oneLine(s string) string {
	return strings.Join(strings.Fields(s), " ")
}
````

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T282: the local tracker and `ygg board`

Spec §10.3 and §10.4: "a terminal kanban per project … built from `features.json` and the ledger". The local tracker reads
`.factory/features.json` and the run that file names and writes nothing. The second PR of `odin` starts here: branch
`phase-6/board` from the branch of the first PR, in `odin`, before step 1.

**Files (in `odin`):**

- Create: `internal/cli/board.go`, `internal/cli/board_test.go`, `internal/tracker/local.go`, `internal/tracker/tracker_test.go`
- Modify: `README.md`, `docs/architecture.md`, `internal/cli/cli.go`, `internal/cli/docs_test.go`

**Interfaces:**

- Produces: `tracker.Local{Project string}` with `Board(ctx) (gungnir.Board, error)`, which implements `gungnir.Tracker`;
  `tracker.WriteBoard(w io.Writer, b gungnir.Board)`.
- The rule: `done`, `blocked` (with the task's reason) and `todo` map to Done, Blocked and Ready. A task that is `doing` is in
  Needs you when the run is stopped at one of the task's gates (the pending node's id begins with the task's slug and a
  dash) or has failed or paused, with the reason on one line; in Verifying when one of its loops is in its ladder or has
  passed; otherwise in In progress. A project with no `features.json` has an empty board, which is not an error; a run that
  cannot be read leaves the board to the statuses of `features.json`. The text board shows at most 120 characters of a
  reason and the card keeps all of it.
- Produces: `ygg board [--project <dir>]`. Exit 0, or 2 for a refusal.

**Acceptance criteria:**

- [ ] Seven tasks in the seven situations above land in the columns named, in the plan's order, and the board validates.
- [ ] A failed run puts its doing task in Needs you with "run failed: …" on one line.
- [ ] An empty project says "no tasks"; a features file that names a missing run still gives a board.
- [ ] A reason of 400 characters is cut with an ellipsis on the board and whole on the card.
- [ ] `ygg board` prints a project's tasks by column, and the README and the architecture page name the command.

**Named test:** `go test ./internal/tracker ./internal/cli -run 'TestEveryTaskLandsInTheColumnItsStatusAndItsLoopSay|TestAFailedOrPausedRunPutsItsTaskInNeedsYouWithTheReason|TestAProjectWithNoPlanYetHasAnEmptyBoardNotAnError|TestAFeaturesFileThatNamesAMissingRunStillGivesABoardFromItsStatuses|TestTheTextBoardListsEveryColumnWithItsCount|TestALongReasonIsCutOnTheBoardAndKeptOnTheCard|TestYggBoardShowsTheProjectsTasksByColumnAndAnEmptyProjectSaysSo|TestTheDocsNameEveryCommand'`
in `odin`. **Layer:** `odin`. **Size:** M (347). **Depends on:** v0-T271, v0-T281.

- [ ] **Step 1:** write the tests.

Write `internal/cli/board_test.go`:

```go
package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
)

func TestYggBoardShowsTheProjectsTasksByColumnAndAnEmptyProjectSaysSo(t *testing.T) {
	dir, _ := project(t, "script.yaml", "")
	code, out, errOut := ygg(t, "board", "--project", dir)
	if code != ExitDone || !strings.Contains(out, "no tasks") {
		t.Fatalf("empty project: exit %d:\n%s%s", code, out, errOut)
	}
	if err := os.MkdirAll(filepath.Join(dir, ".factory"), 0o755); err != nil {
		t.Fatal(err)
	}
	f := &schema.Features{Run: "20261023-090000-a1b2c3", Source: "tasks.md", SourceSHA256: strings.Repeat("a", 64), Tasks: []schema.FeatureRecord{
		{Feature: schema.Feature{ID: "g-T1", Title: "a task", Layer: "repos/api"}, Status: schema.TaskTodo}}}
	if err := f.Save(filepath.Join(dir, ".factory", "features.json")); err != nil {
		t.Fatal(err)
	}
	code, out, errOut = ygg(t, "board", "--project", dir)
	if code != ExitDone || !strings.Contains(out, "Ready (1)") || !strings.Contains(out, "g-T1") {
		t.Errorf("exit %d:\n%s%s", code, out, errOut)
	}
}
```

Apply to `internal/cli/docs_test.go`:

```diff
diff --git a/internal/cli/docs_test.go b/internal/cli/docs_test.go
index dee7516..269c840 100644
--- a/internal/cli/docs_test.go
+++ b/internal/cli/docs_test.go
@@ -30,7 +30,7 @@ func TestTheDocsNameEveryCommand(t *testing.T) {
 	}
 	for _, want := range []string{"ygg grade", "ygg deps bump", "`grade` node", "--canary", "--host", "--task", "grade_refused", "score.json", "ygg.grader",
 		"REPOS.md", ".ygg/impact.json", "shrink guard", "pointer-contract", "routing_index_built", "pointer_contract_checked", "deps_bump", "memory: none",
-		"ygg metrics", "ygg report", "docs/runs", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
+		"ygg metrics", "ygg board", "ygg report", "docs/runs", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
 		if !strings.Contains(string(arch), want) {
 			t.Errorf("docs/architecture.md does not mention %q", want)
 		}
```

Write `internal/tracker/tracker_test.go`:

```go
package tracker

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/jormungandr"
	"github.com/ouroboric-dev/odin/internal/run"
)

const runID = "20261023-090000-a1b2c3"

func task(id, leaf string, status schema.TaskStatus, why string) schema.FeatureRecord {
	return schema.FeatureRecord{Feature: schema.Feature{ID: id, Title: "title of " + id, Layer: leaf}, Status: status, Why: why}
}

// project writes the two files the local tracker reads: .factory/features.json and the run it names.
func project(t *testing.T, tasks []schema.FeatureRecord, mutate func(*run.State)) string {
	t.Helper()
	dir := t.TempDir()
	if err := os.MkdirAll(filepath.Join(dir, ".factory", "runs", runID), 0o755); err != nil {
		t.Fatal(err)
	}
	f := &schema.Features{Run: runID, Source: "docs/plan/tasks.md", SourceSHA256: strings.Repeat("a", 64), Tasks: tasks}
	if err := f.Save(filepath.Join(dir, ".factory", "features.json")); err != nil {
		t.Fatal(err)
	}
	st := &run.State{ID: runID, Status: run.StatusRunning, Mode: gungnir.ModeKeyPoints, Features: tasks, Loops: map[string]*run.LoopRecord{}}
	if mutate != nil {
		mutate(st)
	}
	if err := st.Save(filepath.Join(dir, ".factory", "runs", runID)); err != nil {
		t.Fatal(err)
	}
	return dir
}

func column(t *testing.T, b gungnir.Board, id string) gungnir.Card {
	t.Helper()
	for _, c := range b.Cards {
		if c.Task == id {
			return c
		}
	}
	t.Fatalf("task %s is not on the board: %+v", id, b.Cards)
	return gungnir.Card{}
}

func TestEveryTaskLandsInTheColumnItsStatusAndItsLoopSay(t *testing.T) {
	tasks := []schema.FeatureRecord{
		task("g-T1", "repos/api", schema.TaskDone, ""),
		task("g-T2", "repos/web", schema.TaskBlocked, "attempts-exhausted in implement"),
		task("g-T3", "repos/web", schema.TaskTodo, ""),
		task("g-T4", "repos/api", schema.TaskDoing, ""), // loop still implementing
		task("g-T5", "repos/api", schema.TaskDoing, ""), // loop in its ladder
		task("g-T6", "repos/api", schema.TaskDoing, ""), // loop passed, merge and pointer to go
		task("g-T7", "repos/api", schema.TaskDoing, ""), // waiting at its contract gate
	}
	dir := project(t, tasks, func(s *run.State) {
		s.Status, s.Pending, s.PendingGate = run.StatusStopped, "g-t7-contract-gate", gungnir.GatePointerContract
		s.Loops["g-t4-implement"] = &run.LoopRecord{State: jormungandr.State{Attempt: 1, Limit: 3, Phase: jormungandr.PhaseImplement}}
		s.Loops["g-t5-implement"] = &run.LoopRecord{State: jormungandr.State{Attempt: 2, Limit: 3, Phase: jormungandr.PhaseLadder}}
		s.Loops["g-t6-implement"] = &run.LoopRecord{State: jormungandr.State{Attempt: 1, Limit: 3, Phase: jormungandr.PhaseLadder, Passed: true}}
		s.Loops["g-t7-implement"] = &run.LoopRecord{State: jormungandr.State{Attempt: 1, Limit: 3, Phase: jormungandr.PhaseLadder, Passed: true}}
	})
	b, err := Local{Project: dir}.Board(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if err := b.Validate(); err != nil {
		t.Fatalf("the board is not valid: %v", err)
	}
	want := map[string]gungnir.Column{"g-T1": gungnir.ColumnDone, "g-T2": gungnir.ColumnBlocked, "g-T3": gungnir.ColumnReady,
		"g-T4": gungnir.ColumnInProgress, "g-T5": gungnir.ColumnVerifying, "g-T6": gungnir.ColumnVerifying, "g-T7": gungnir.ColumnNeedsYou}
	for id, col := range want {
		if got := column(t, b, id).Column; got != col {
			t.Errorf("%s is in %q, want %q", id, got, col)
		}
	}
	if c := column(t, b, "g-T2"); c.Why != "attempts-exhausted in implement" {
		t.Errorf("g-T2 Why = %q", c.Why)
	}
	if c := column(t, b, "g-T7"); !strings.Contains(c.Why, "pointer-contract") {
		t.Errorf("g-T7 Why = %q; want the gate it waits at", c.Why)
	}
	if got := b.Cards[0].Task; got != "g-T1" || b.Cards[6].Task != "g-T7" {
		t.Errorf("cards are not in the plan's order: %+v", b.Cards)
	}
}

func TestAFailedOrPausedRunPutsItsTaskInNeedsYouWithTheReason(t *testing.T) {
	dir := project(t, []schema.FeatureRecord{task("g-T1", "repos/api", schema.TaskDoing, "")}, func(s *run.State) {
		s.Status, s.Error = run.StatusFailed, "node g-t1-implement: the sandbox didn't start\nsecond line of the error"
		s.Loops["g-t1-implement"] = &run.LoopRecord{State: jormungandr.State{Attempt: 1, Limit: 3, Phase: jormungandr.PhaseImplement}}
	})
	b, _ := Local{Project: dir}.Board(context.Background())
	c := column(t, b, "g-T1")
	if c.Column != gungnir.ColumnNeedsYou || !strings.Contains(c.Why, "run failed") || strings.Contains(c.Why, "\n") {
		t.Errorf("card = %+v; want needs-you with a one-line 'run failed' reason", c)
	}
}

func TestAProjectWithNoPlanYetHasAnEmptyBoardNotAnError(t *testing.T) {
	b, err := Local{Project: t.TempDir()}.Board(context.Background())
	if err != nil || len(b.Cards) != 0 || b.Summary() != "no tasks" {
		t.Errorf("Board() = %+v, %v", b, err)
	}
}

func TestAFeaturesFileThatNamesAMissingRunStillGivesABoardFromItsStatuses(t *testing.T) {
	dir := project(t, []schema.FeatureRecord{task("g-T1", "repos/api", schema.TaskDoing, ""), task("g-T2", "repos/api", schema.TaskTodo, "")}, nil)
	if err := os.RemoveAll(filepath.Join(dir, ".factory", "runs")); err != nil {
		t.Fatal(err)
	}
	b, err := Local{Project: dir}.Board(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if column(t, b, "g-T1").Column != gungnir.ColumnInProgress || column(t, b, "g-T2").Column != gungnir.ColumnReady {
		t.Errorf("Board = %+v", b)
	}
}

func TestTheTextBoardListsEveryColumnWithItsCount(t *testing.T) {
	dir := project(t, []schema.FeatureRecord{task("g-T1", "repos/api", schema.TaskDone, ""), task("g-T2", "repos/web", schema.TaskBlocked, "attempts-exhausted")}, nil)
	b, _ := Local{Project: dir}.Board(context.Background())
	var w bytes.Buffer
	WriteBoard(&w, b)
	out := w.String()
	for _, want := range []string{"Ready (0)", "In progress (0)", "Verifying (0)", "Blocked (1)", "g-T2", "attempts-exhausted", "Needs you (0)", "Done (1)", "g-T1"} {
		if !strings.Contains(out, want) {
			t.Errorf("the board lacks %q:\n%s", want, out)
		}
	}
	if strings.Index(out, "Ready") > strings.Index(out, "Done") {
		t.Error("the columns are not in reading order")
	}
}

func TestALongReasonIsCutOnTheBoardAndKeptOnTheCard(t *testing.T) {
	long := strings.Repeat("a long reason ", 30)
	dir := project(t, []schema.FeatureRecord{task("g-T1", "repos/api", schema.TaskBlocked, long)}, nil)
	b, _ := Local{Project: dir}.Board(context.Background())
	var w bytes.Buffer
	WriteBoard(&w, b)
	for _, l := range strings.Split(w.String(), "\n") {
		if strings.Contains(l, "g-T1") && len([]rune(l)) > 16+1+12+1+len("title of g-T1")+2+maxWhy+3+2 {
			t.Errorf("the board line is %d characters:\n%s", len([]rune(l)), l)
		}
	}
	if !strings.Contains(w.String(), "…]") || column(t, b, "g-T1").Why != strings.TrimSpace(long) {
		t.Errorf("the reason must be cut on the board with an ellipsis and whole on the card:\n%s", w.String())
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/tracker [github.com/ouroboric-dev/odin/internal/tracker.test]
internal/tracker/tracker_test.go:72:12: undefined: Local
internal/tracker/tracker_test.go:102:10: undefined: Local
internal/tracker/tracker_test.go:110:12: undefined: Local
```

- [ ] **Step 3:** write the code.

Apply to `README.md`:

```diff
diff --git a/README.md b/README.md
index bae6f5a..6f8e797 100644
--- a/README.md
+++ b/README.md
@@ -25,6 +25,7 @@ ygg grade   <run-id> [--task <id>] [--project <dir>]
 ygg metrics <run-id|first..last> [--json] [--project <dir>]
 ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
 ygg report  <run-id> [--commit] [--project <dir>]
+ygg board   [--project <dir>]
 ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
 ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
 ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -58,6 +59,10 @@ intervention with its note, the loops that gave up, and each finding a dispute o
 ledger line it was read from, and the same run always gives the same bytes. Text an agent wrote is quoted, so it cannot
 open a heading or end a block. `--commit` also commits a copy as `docs/runs/<run-id>.md`, because a project ignores `.factory/`.
 
+`ygg board` shows the project's tasks by column, as a terminal board: Ready, In progress, Verifying, Blocked, Needs you
+and Done, in the plan's order, each with its leaf and, for a blocked task or one that needs you, the reason. It reads
+`.factory/features.json` and the run that file names, and writes nothing.
+
 `ygg deps bump` runs the package manager and the checks in the sandbox of `factory.yaml`. Without a `sandbox:`
 section it refuses (exit 2) unless you pass `--host`, which runs the bump on the host with the full network and
 your user id, and records that in the first line of the bump's ledger. With a sandbox section `--host` has no effect.
```

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index d0fdef5..2c58ade 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -156,6 +156,11 @@ scores are not on one scale. Metrics with no direction, such as the reviewer vet
 the interventions with their notes, and the loops' records in `run.json`. With `--commit` a copy is committed as
 `docs/runs/<run-id>.md`, because a project ignores `.factory/`.
 
+`ygg board` (package `internal/tracker`) is the local tracker of spec §10.4: it projects `.factory/features.json` and the
+run it names into the `Board` of Gungnir's `Tracker` interface. A task that is doing is in progress while its implementer
+works, verifying once the checks and reviewers judge it or its loop has passed, and in needs you when the run stopped at
+one of its gates or failed.
+
 ## Depends on
 
 - Gungnir's interfaces, Gleipnir (adapters, the sandbox, the check runner) and Jormungandr (the loop).
```

Write `internal/cli/board.go`:

```go
package cli

import (
	"path/filepath"

	"github.com/ouroboric-dev/odin/internal/tracker"
)

// board runs ygg board: the project's tasks by column (spec §10.3), read from features.json and the run it
// names. It writes nothing.
func (c *command) board(args []string) int {
	f, _, ok := c.parse("board", args, 0, nil)
	if !ok {
		return ExitRefused
	}
	project, err := filepath.Abs(f.project)
	if err != nil {
		return c.refuse(err)
	}
	b, err := tracker.Local{Project: project}.Board(c.ctx)
	if err != nil {
		return c.refuse(err)
	}
	tracker.WriteBoard(c.out, b)
	return ExitDone
}
```

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 3acb75c..a85d4ae 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -40,6 +40,7 @@ const usage = `usage:
   ygg metrics <run-id|first..last> [--json] [--project <dir>]
   ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
   ygg report  <run-id> [--commit] [--project <dir>]
+  ygg board   [--project <dir>]
   ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
   ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -56,7 +57,7 @@ func Main(ctx context.Context, args []string, stdout, stderr io.Writer) int {
 	c := &command{ctx: ctx, out: stdout, err: stderr}
 	cmds := map[string]func([]string) int{
 		"run": c.run, "resume": c.resume, "approve": c.approve, "reject": c.reject,
-		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade, "deps": c.deps, "metrics": c.metrics, "report": c.report,
+		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade, "deps": c.deps, "metrics": c.metrics, "report": c.report, "board": c.board,
 	}
 	f, ok := cmds[args[0]]
 	if !ok {
@@ -87,7 +88,9 @@ func (c *command) parse(name string, args []string, want int, define func(*flag.
 	f := &flags{}
 	fs.StringVar(&f.project, "project", ".", "the project directory")
 	fs.StringVar(&f.mode, "mode", "", "step-by-step, key-points or unattended")
-	define(fs, f)
+	if define != nil {
+		define(fs, f)
+	}
 	var pos []string
 	for {
 		if err := fs.Parse(args); err != nil {
```

Write `internal/tracker/local.go`:

```go
// Package tracker is the local tracker of spec §10.4: it projects the factory's state one way, into a board.
// It reads .factory/features.json and the run that file names, and it writes nothing.
package tracker

import (
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"path/filepath"
	"strings"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/jormungandr"
	"github.com/ouroboric-dev/odin/internal/run"
)

// Local is the tracker of a project folder.
type Local struct{ Project string }

var _ gungnir.Tracker = Local{}

// Board puts each task of the plan in a column. A project with no plan yet has an empty board, which is not an
// error. A run.json that cannot be read leaves the board to the statuses of features.json alone.
func (l Local) Board(ctx context.Context) (gungnir.Board, error) {
	b := gungnir.Board{Project: l.Project}
	f, err := schema.LoadFeatures(filepath.Join(l.Project, ".factory", "features.json"))
	if errors.Is(err, fs.ErrNotExist) {
		return b, nil
	}
	if err != nil {
		return b, err
	}
	st, err := run.LoadState(run.Dir(l.Project, f.Run))
	if err != nil {
		st = nil
	}
	for _, t := range f.Tasks {
		col, why := place(t, st)
		b.Cards = append(b.Cards, gungnir.Card{Task: t.ID, Title: t.Title, Leaf: t.Layer, Column: col, Why: why, Run: f.Run})
	}
	return b, b.Validate()
}

// place decides the column of one task. A task that is doing is in progress while its implementer works,
// verifying once the checks and reviewers judge it or its loop has passed, and needs the person when the run
// stopped at one of its gates or stopped because something failed.
func place(t schema.FeatureRecord, st *run.State) (gungnir.Column, string) {
	switch t.Status {
	case schema.TaskDone:
		return gungnir.ColumnDone, ""
	case schema.TaskBlocked:
		return gungnir.ColumnBlocked, oneLine(t.Why)
	case schema.TaskTodo:
		return gungnir.ColumnReady, ""
	}
	if st == nil {
		return gungnir.ColumnInProgress, ""
	}
	mine := func(node string) bool { return strings.HasPrefix(node, t.Slug()+"-") }
	switch st.Status {
	case run.StatusStopped:
		if mine(st.Pending) {
			return gungnir.ColumnNeedsYou, fmt.Sprintf("waiting at %s (%s)", st.Pending, st.PendingGate)
		}
	case run.StatusFailed:
		return gungnir.ColumnNeedsYou, "run failed: " + oneLine(st.Error)
	case run.StatusPaused:
		if st.Paused != nil {
			return gungnir.ColumnNeedsYou, "run paused: " + oneLine(st.Paused.Reason)
		}
	}
	for id, l := range st.Loops {
		if mine(id) && (l.State.Passed || l.State.Phase == jormungandr.PhaseLadder) {
			return gungnir.ColumnVerifying, ""
		}
	}
	return gungnir.ColumnInProgress, ""
}

func oneLine(s string) string {
	line, _, _ := strings.Cut(strings.TrimSpace(s), "\n")
	return strings.Join(strings.Fields(line), " ")
}

// WriteBoard writes a board as text: each column with its count and its cards in the plan's order.
func WriteBoard(w io.Writer, b gungnir.Board) {
	fmt.Fprintf(w, "%s (%s)\n", b.Project, b.Summary())
	for _, col := range gungnir.Columns() {
		n := b.Counts()[col]
		fmt.Fprintf(w, "\n%s (%d)\n", col.Title(), n)
		for _, c := range b.Cards {
			if c.Column != col {
				continue
			}
			line := fmt.Sprintf("  %-16s %-12s %s", c.Task, c.Leaf, c.Title)
			if c.Why != "" {
				line += "  [" + clip(c.Why, maxWhy) + "]"
			}
			fmt.Fprintln(w, strings.TrimRight(line, " "))
		}
	}
}

// maxWhy is how much of a reason the board shows; the card keeps all of it.
const maxWhy = 120

func clip(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n]) + "…"
	}
	return s
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T283: `ygg board --all`

The change task `project-is-its-own-tree-T002`: "`ygg board --all` reads the operator's projects from local configuration, and
refuses a path that isn't a project umbrella". Its named test, which that change left to this plan, is
`TestAListNamingAnythingButProjectRootsIsRefusedWholeWithTheBadPath`. The list is a file on the operator's machine, never in
a tree. Same branch.

**Files (in `odin`):**

- Create: `internal/tracker/projects.go`, `internal/tracker/projects_test.go`
- Modify: `README.md`, `docs/architecture.md`, `internal/cli/board.go`, `internal/cli/board_test.go`, `internal/cli/cli.go`, `internal/cli/docs_test.go`

**Interfaces:**

- Produces: `tracker.DefaultProjectsFile() string` (`$XDG_CONFIG_HOME/ouroboric/projects.yaml`, else
  `$HOME/.config/ouroboric/projects.yaml`), `tracker.LoadProjects(path string) ([]string, error)` and
  `tracker.WriteAll(w io.Writer, boards []gungnir.Board)`.
- The rule: the file is YAML with a `projects` key holding absolute paths, no other key. Every path must be a project umbrella
  (an `umbrella.yaml` that sets `root: true`) and listed once. One bad path refuses the whole list, names the path, and shows
  no board.
- Produces: `ygg board --all [--projects <file>]`. `--all` takes no `--project`.

**Acceptance criteria:**

- [ ] Two projects are read in order and their boards are shown, each under its project.
- [ ] A leaf folder, an umbrella that is not a root, an empty folder, a folder that is not there, a relative path, a `~`, a
      path twice, an empty list and an unknown key each refuse the list, and the leaf's refusal names the leaf.
- [ ] With no list, `ygg board --all` refuses and says where the list goes; `--all` with `--project` is refused.

**Named test:** `go test ./internal/tracker ./internal/cli -run 'TestTheOperatorsProjectsAreReadFromTheLocalListInOrder|TestAListNamingAnythingButProjectRootsIsRefusedWholeWithTheBadPath|TestTheDefaultListIsInTheOperatorsConfigFolder|TestOneBoardPerProjectIsWrittenWithTheProjectAsItsHeading|TestYggBoardAllShowsEveryProjectOfTheLocalListAndRefusesAListWithAnImpostor|TestTheDocsNameEveryCommand'`
in `odin`. **Layer:** `odin`. **Size:** M (224). **Depends on:** v0-T282.

- [ ] **Step 1:** write the tests.

Apply to `internal/cli/board_test.go`:

```diff
diff --git a/internal/cli/board_test.go b/internal/cli/board_test.go
index e7003c2..9f7d7c2 100644
--- a/internal/cli/board_test.go
+++ b/internal/cli/board_test.go
@@ -28,3 +28,29 @@ func TestYggBoardShowsTheProjectsTasksByColumnAndAnEmptyProjectSaysSo(t *testing
 		t.Errorf("exit %d:\n%s%s", code, out, errOut)
 	}
 }
+
+func TestYggBoardAllShowsEveryProjectOfTheLocalListAndRefusesAListWithAnImpostor(t *testing.T) {
+	a, _ := project(t, "script.yaml", "")
+	b, _ := project(t, "script.yaml", "")
+	list := filepath.Join(t.TempDir(), "projects.yaml")
+	if err := os.WriteFile(list, []byte("projects:\n  - "+a+"\n  - "+b+"\n"), 0o644); err != nil {
+		t.Fatal(err)
+	}
+	code, out, errOut := ygg(t, "board", "--all", "--projects", list)
+	if code != ExitDone || !strings.Contains(out, a) || !strings.Contains(out, b) {
+		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
+	}
+	if err := os.WriteFile(list, []byte("projects:\n  - "+a+"\n  - "+t.TempDir()+"\n"), 0o644); err != nil {
+		t.Fatal(err)
+	}
+	if code, out, errOut := ygg(t, "board", "--all", "--projects", list); code != ExitRefused || out != "" || errOut == "" {
+		t.Errorf("a list with a folder that is no project: exit %d, stdout %q, stderr %q; want a refusal and no board", code, out, errOut)
+	}
+	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
+	if code, _, errOut := ygg(t, "board", "--all"); code != ExitRefused || !strings.Contains(errOut, "projects.yaml") {
+		t.Errorf("no list: exit %d, stderr %q; want a refusal that says where the list goes", code, errOut)
+	}
+	if code, _, _ := ygg(t, "board", "--all", "--project", a); code != ExitRefused {
+		t.Errorf("--all with --project: exit %d, want a refusal", code)
+	}
+}
```

Apply to `internal/cli/docs_test.go`:

```diff
diff --git a/internal/cli/docs_test.go b/internal/cli/docs_test.go
index 269c840..854c30c 100644
--- a/internal/cli/docs_test.go
+++ b/internal/cli/docs_test.go
@@ -30,7 +30,7 @@ func TestTheDocsNameEveryCommand(t *testing.T) {
 	}
 	for _, want := range []string{"ygg grade", "ygg deps bump", "`grade` node", "--canary", "--host", "--task", "grade_refused", "score.json", "ygg.grader",
 		"REPOS.md", ".ygg/impact.json", "shrink guard", "pointer-contract", "routing_index_built", "pointer_contract_checked", "deps_bump", "memory: none",
-		"ygg metrics", "ygg board", "ygg report", "docs/runs", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
+		"ygg metrics", "ygg board", "projects.yaml", "ygg report", "docs/runs", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
 		if !strings.Contains(string(arch), want) {
 			t.Errorf("docs/architecture.md does not mention %q", want)
 		}
```

Write `internal/tracker/projects_test.go`:

```go
package tracker

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

func writeList(t *testing.T, body string) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "projects.yaml")
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return path
}

func TestTheOperatorsProjectsAreReadFromTheLocalListInOrder(t *testing.T) {
	a, b := treetest.Project(t, "repos/app"), treetest.Project(t, "repos/app")
	got, err := LoadProjects(writeList(t, "projects:\n  - "+b+"\n  - "+a+"\n"))
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 || got[0] != b || got[1] != a {
		t.Errorf("LoadProjects() = %v, want [%s %s]", got, b, a)
	}
}

// Change project-is-its-own-tree-T002: a path that is not a project umbrella is refused, and nothing is read.
func TestAListNamingAnythingButProjectRootsIsRefusedWholeWithTheBadPath(t *testing.T) {
	good := treetest.Project(t, "repos/app")
	notRoot := t.TempDir()
	umbrella, _ := os.ReadFile(filepath.Join(good, "umbrella.yaml"))
	if err := os.WriteFile(filepath.Join(notRoot, "umbrella.yaml"), []byte(strings.Replace(string(umbrella), "root: true", "root: false", 1)), 0o644); err != nil {
		t.Fatal(err)
	}
	leaf := filepath.Join(good, "repos", "app")
	for name, body := range map[string]string{
		"a leaf folder":         "projects:\n  - " + good + "\n  - " + leaf + "\n",
		"an umbrella below one": "projects:\n  - " + notRoot + "\n",
		"a folder with nothing": "projects:\n  - " + t.TempDir() + "\n",
		"a folder that is gone": "projects:\n  - /no/such/project\n",
		"a relative path":       "projects:\n  - projects/gallery\n",
		"a home shortcut":       "projects:\n  - ~/gallery\n",
		"the same one twice":    "projects:\n  - " + good + "\n  - " + good + "/\n",
		"an empty list":         "projects: []\n",
		"an unknown key":        "projects:\n  - " + good + "\nextra: 1\n",
	} {
		if got, err := LoadProjects(writeList(t, body)); err == nil || got != nil {
			t.Errorf("%s: LoadProjects() = %v, %v; want a refusal and no projects", name, got, err)
		}
	}
	_, err := LoadProjects(writeList(t, "projects:\n  - "+good+"\n  - "+leaf+"\n"))
	if err == nil || !strings.Contains(err.Error(), leaf) {
		t.Errorf("the refusal must name the bad path %s: %v", leaf, err)
	}
}

func TestTheDefaultListIsInTheOperatorsConfigFolder(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", "/cfg")
	if got := DefaultProjectsFile(); got != "/cfg/ouroboric/projects.yaml" {
		t.Errorf("DefaultProjectsFile() = %q", got)
	}
	t.Setenv("XDG_CONFIG_HOME", "")
	t.Setenv("HOME", "/home/someone")
	if got := DefaultProjectsFile(); got != "/home/someone/.config/ouroboric/projects.yaml" {
		t.Errorf("DefaultProjectsFile() = %q", got)
	}
}

func TestOneBoardPerProjectIsWrittenWithTheProjectAsItsHeading(t *testing.T) {
	var w strings.Builder
	WriteAll(&w, []gungnir.Board{{Project: "/p/one", Cards: []gungnir.Card{{Task: "a-T1", Column: gungnir.ColumnDone}}}, {Project: "/p/two"}})
	out := w.String()
	if !strings.Contains(out, "/p/one (1 done)") || !strings.Contains(out, "/p/two (no tasks)") || strings.Index(out, "/p/one") > strings.Index(out, "/p/two") {
		t.Errorf("WriteAll() =\n%s", out)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/tracker [github.com/ouroboric-dev/odin/internal/tracker.test]
internal/tracker/projects_test.go:24:14: undefined: LoadProjects
internal/tracker/projects_test.go:53:18: undefined: LoadProjects
internal/tracker/projects_test.go:57:12: undefined: LoadProjects
```

- [ ] **Step 3:** write the code.

Apply to `README.md`:

```diff
diff --git a/README.md b/README.md
index 6f8e797..5feface 100644
--- a/README.md
+++ b/README.md
@@ -25,7 +25,7 @@ ygg grade   <run-id> [--task <id>] [--project <dir>]
 ygg metrics <run-id|first..last> [--json] [--project <dir>]
 ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
 ygg report  <run-id> [--commit] [--project <dir>]
-ygg board   [--project <dir>]
+ygg board   [--project <dir>] | --all [--projects <file>]
 ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
 ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
 ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -61,7 +61,9 @@ open a heading or end a block. `--commit` also commits a copy as `docs/runs/<run
 
 `ygg board` shows the project's tasks by column, as a terminal board: Ready, In progress, Verifying, Blocked, Needs you
 and Done, in the plan's order, each with its leaf and, for a blocked task or one that needs you, the reason. It reads
-`.factory/features.json` and the run that file names, and writes nothing.
+`.factory/features.json` and the run that file names, and writes nothing. `ygg board --all` shows the board of every project
+in the operator's local list, `$XDG_CONFIG_HOME/ouroboric/projects.yaml` (or `~/.config/ouroboric/projects.yaml`, or the file
+`--projects` names): `projects:` and a list of absolute paths. A path that is not a project umbrella refuses the whole list.
 
 `ygg deps bump` runs the package manager and the checks in the sandbox of `factory.yaml`. Without a `sandbox:`
 section it refuses (exit 2) unless you pass `--host`, which runs the bump on the host with the full network and
```

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 2c58ade..8a6defb 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -159,7 +159,7 @@ the interventions with their notes, and the loops' records in `run.json`. With `
 `ygg board` (package `internal/tracker`) is the local tracker of spec §10.4: it projects `.factory/features.json` and the
 run it names into the `Board` of Gungnir's `Tracker` interface. A task that is doing is in progress while its implementer
 works, verifying once the checks and reviewers judge it or its loop has passed, and in needs you when the run stopped at
-one of its gates or failed.
+one of its gates or failed. The operator's list of projects for `ygg board --all` is local configuration (`projects.yaml` in the config folder), never part of a tree.
 
 ## Depends on
 
```

Apply to `internal/cli/board.go`:

```diff
diff --git a/internal/cli/board.go b/internal/cli/board.go
index 45a7e3d..34b17bc 100644
--- a/internal/cli/board.go
+++ b/internal/cli/board.go
@@ -1,18 +1,49 @@
 package cli
 
 import (
+	"flag"
+	"fmt"
 	"path/filepath"
 
+	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/odin/internal/tracker"
 )
 
 // board runs ygg board: the project's tasks by column (spec §10.3), read from features.json and the run it
-// names. It writes nothing.
+// names. With --all it shows the board of every project in the operator's local list, and it shows nothing if
+// any path of the list is not a project. It writes nothing.
 func (c *command) board(args []string) int {
-	f, _, ok := c.parse("board", args, 0, nil)
+	var all bool
+	var list string
+	f, _, ok := c.parse("board", args, 0, func(fs *flag.FlagSet, f *flags) {
+		fs.BoolVar(&all, "all", false, "show every project of the local list")
+		fs.StringVar(&list, "projects", "", "the list of projects (default "+tracker.DefaultProjectsFile()+")")
+	})
 	if !ok {
 		return ExitRefused
 	}
+	if all {
+		if f.set["project"] {
+			return c.refuse(fmt.Errorf("--all shows the projects of the local list; it takes no --project"))
+		}
+		if list == "" {
+			list = tracker.DefaultProjectsFile()
+		}
+		projects, err := tracker.LoadProjects(list)
+		if err != nil {
+			return c.refuse(err)
+		}
+		var boards []gungnir.Board
+		for _, p := range projects {
+			b, err := tracker.Local{Project: p}.Board(c.ctx)
+			if err != nil {
+				return c.refuse(fmt.Errorf("%s: %w", p, err))
+			}
+			boards = append(boards, b)
+		}
+		tracker.WriteAll(c.out, boards)
+		return ExitDone
+	}
 	project, err := filepath.Abs(f.project)
 	if err != nil {
 		return c.refuse(err)
```

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index a85d4ae..ee433c3 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -40,7 +40,7 @@ const usage = `usage:
   ygg metrics <run-id|first..last> [--json] [--project <dir>]
   ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
   ygg report  <run-id> [--commit] [--project <dir>]
-  ygg board   [--project <dir>]
+  ygg board   [--project <dir>] | --all [--projects <file>]
   ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
   ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
```

Write `internal/tracker/projects.go`:

```go
package tracker

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"go.yaml.in/yaml/v3"
)

// DefaultProjectsFile is where the operator's list of projects is: local configuration on the operator's
// machine, never in a tree (change project-is-its-own-tree).
func DefaultProjectsFile() string {
	if dir := os.Getenv("XDG_CONFIG_HOME"); dir != "" {
		return filepath.Join(dir, "ouroboric", "projects.yaml")
	}
	return filepath.Join(os.Getenv("HOME"), ".config", "ouroboric", "projects.yaml")
}

// LoadProjects reads the list: a YAML file with a projects key holding absolute paths. Every path must be a
// project umbrella (an umbrella.yaml that sets root: true), listed once. One bad path refuses the whole list,
// and no board is shown from part of it.
func LoadProjects(path string) ([]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("the list of projects can't be read: %w (it holds `projects:` and a list of absolute paths)", err)
	}
	var list struct {
		Projects []string `yaml:"projects"`
	}
	dec := yaml.NewDecoder(bytes.NewReader(data))
	dec.KnownFields(true)
	if err := dec.Decode(&list); err != nil && !errors.Is(err, io.EOF) {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if len(list.Projects) == 0 {
		return nil, fmt.Errorf("%s lists no project", path)
	}
	seen := map[string]bool{}
	var out []string
	for _, p := range list.Projects {
		if !filepath.IsAbs(p) {
			return nil, fmt.Errorf("%s: %q is not an absolute path (a ~ is not expanded)", path, p)
		}
		p = filepath.Clean(p)
		if seen[p] {
			return nil, fmt.Errorf("%s: %s is listed twice", path, p)
		}
		seen[p] = true
		u, err := schema.LoadUmbrella(p)
		if err != nil {
			return nil, fmt.Errorf("%s: %s is not a project umbrella: %w", path, p, err)
		}
		if !u.Root {
			return nil, fmt.Errorf("%s: %s is not a project umbrella: its umbrella.yaml doesn't set root: true", path, p)
		}
		out = append(out, p)
	}
	return out, nil
}

// WriteAll writes one board after another, each under its project.
func WriteAll(w io.Writer, boards []gungnir.Board) {
	for i, b := range boards {
		if i > 0 {
			fmt.Fprintln(w, strings.Repeat("-", 40))
		}
		WriteBoard(w, b)
	}
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T284: `ygg status --watch`

The live view of spec §10.3: "current node, loop attempt, cost so far". `ygg status <run-id> --watch` prints the status block
again every `--interval` (2 seconds by default; 50 milliseconds to 1 hour) while a process holds the run's lock, with a `now:`
line from the end of the ledger, and stops when the run stops running or when nothing holds it. It reads a ledger that
another process is writing, ignores a last line that is still being written, and does not verify the chain: it is a view, and
`ygg metrics` is the evidence. Same branch.

**Files (in `odin`):**

- Create: `internal/cli/watch_test.go`, `internal/metrics/now.go`, `internal/metrics/now_test.go`
- Modify: `README.md`, `docs/architecture.md`, `internal/cli/cli.go`, `internal/cli/docs_test.go`, `internal/metrics/helpers_test.go`

**Interfaces:**

- Produces: `metrics.Current(dir string) (metrics.Now, error)` with `Now{Node, Role string; Attempt int; Since time.Time;
  Between bool}`: the last node that started, and whether it has finished.
- Changes: `ygg status` takes `--watch` and `--interval`; `--interval` without `--watch` is refused.

**Acceptance criteria:**

- [ ] A node that started and has not finished is `Now` with its attempt and start; after it finished, `Between` is true.
- [ ] A last line cut off is ignored.
- [ ] While the test holds the run's lock the watch prints the status at least three times, and when the run's status is
      changed to done it prints the last block and returns 0.
- [ ] A run that no process holds is printed once, as interrupted, and the watch returns.
- [ ] An interval of 0 or over an hour, and `--interval` alone, are refused.

**Named test:** `go test ./internal/metrics ./internal/cli -run 'TestCurrentNamesTheNodeThatIsRunningAndItsAttempt|TestCurrentBetweenNodesSaysWhatFinishedLast|TestCurrentIgnoresALastLineThatIsStillBeingWritten|TestStatusWatch|TestTheDocsNameEveryCommand'`
in `odin`. **Layer:** `odin`. **Size:** M (252). **Depends on:** v0-T273.

- [ ] **Step 1:** write the tests.

Apply to `internal/cli/docs_test.go`:

```diff
diff --git a/internal/cli/docs_test.go b/internal/cli/docs_test.go
index 854c30c..bdac5b7 100644
--- a/internal/cli/docs_test.go
+++ b/internal/cli/docs_test.go
@@ -30,7 +30,7 @@ func TestTheDocsNameEveryCommand(t *testing.T) {
 	}
 	for _, want := range []string{"ygg grade", "ygg deps bump", "`grade` node", "--canary", "--host", "--task", "grade_refused", "score.json", "ygg.grader",
 		"REPOS.md", ".ygg/impact.json", "shrink guard", "pointer-contract", "routing_index_built", "pointer_contract_checked", "deps_bump", "memory: none",
-		"ygg metrics", "ygg board", "projects.yaml", "ygg report", "docs/runs", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
+		"ygg metrics", "--watch", "ygg board", "projects.yaml", "ygg report", "docs/runs", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
 		if !strings.Contains(string(arch), want) {
 			t.Errorf("docs/architecture.md does not mention %q", want)
 		}
```

Write `internal/cli/watch_test.go`:

```go
package cli

import (
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/odin/internal/lock"
	"github.com/ouroboric-dev/odin/internal/run"
)

// A run that a process holds is live. The test holds the run's lock itself, as ygg does.
func TestStatusWatchPrintsAgainEveryIntervalUntilTheRunStopsRunning(t *testing.T) {
	dir, config := project(t, "script.yaml", "mode: key-points\n")
	id, _ := walk(t, dir, config)
	runDir := run.Dir(dir, id)
	st, err := run.LoadState(runDir)
	if err != nil {
		t.Fatal(err)
	}
	st.Status = run.StatusRunning
	if err := st.Save(runDir); err != nil {
		t.Fatal(err)
	}
	release, err := lock.Take(filepath.Join(runDir, "lock"))
	if err != nil {
		t.Fatal(err)
	}
	defer release()
	go func() {
		time.Sleep(400 * time.Millisecond)
		st.Status = run.StatusDone
		st.Save(runDir) //nolint:errcheck // the test reads what the watch printed
	}()
	code, out, errOut := ygg(t, "status", id, "--watch", "--interval", "100ms", "--project", dir)
	if code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	if n := strings.Count(out, "run:      "+id); n < 3 {
		t.Errorf("the watch printed the status %d times, want at least 3 before the run ended:\n%s", n, out)
	}
	if !strings.HasSuffix(strings.TrimSpace(out), "$0.0000") && !strings.Contains(out[strings.LastIndex(out, "run:      "+id):], "status:   done") {
		t.Errorf("the last block does not show the run as done:\n%s", out)
	}
}

func TestStatusWatchOfARunNoProcessHoldsPrintsOnceAndReturns(t *testing.T) {
	dir, config := project(t, "script.yaml", "mode: key-points\n")
	id, _ := walk(t, dir, config)
	runDir := run.Dir(dir, id)
	st, _ := run.LoadState(runDir)
	st.Status = run.StatusRunning // the process died: nothing holds the lock
	st.Save(runDir)               //nolint:errcheck // checked by the status below
	done := make(chan struct{})
	var out string
	go func() {
		_, out, _ = ygg(t, "status", id, "--watch", "--interval", "50ms", "--project", dir)
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("the watch of an interrupted run never returned")
	}
	if n := strings.Count(out, "run:      "+id); n != 1 || !strings.Contains(out, "interrupted") {
		t.Errorf("printed %d times:\n%s", n, out)
	}
}

func TestStatusWatchNeedsAPositiveIntervalAndOnlyWithWatch(t *testing.T) {
	dir, config := project(t, "script.yaml", "mode: key-points\n")
	id, _ := walk(t, dir, config)
	for name, args := range map[string][]string{
		"a zero interval":      {"status", id, "--watch", "--interval", "0s", "--project", dir},
		"an interval too long": {"status", id, "--watch", "--interval", "2h", "--project", dir},
		"an interval alone":    {"status", id, "--interval", "5s", "--project", dir},
	} {
		if code, _, errOut := ygg(t, args...); code != ExitRefused || errOut == "" {
			t.Errorf("%s: exit %d, stderr %q; want a refusal", name, code, errOut)
		}
	}
}
```

Apply to `internal/metrics/helpers_test.go`:

```diff
diff --git a/internal/metrics/helpers_test.go b/internal/metrics/helpers_test.go
index a0011ad..539e33d 100644
--- a/internal/metrics/helpers_test.go
+++ b/internal/metrics/helpers_test.go
@@ -84,3 +84,16 @@ func mustCollect(t *testing.T, dir string) *Run {
 	}
 	return r
 }
+
+// appendRaw adds text to the ledger as it is, with no newline: a line another process is still writing.
+func appendRaw(t *testing.T, dir, text string) {
+	t.Helper()
+	f, err := os.OpenFile(filepath.Join(dir, "ledger.jsonl"), os.O_APPEND|os.O_WRONLY, 0o644)
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer f.Close()
+	if _, err := f.WriteString(text); err != nil {
+		t.Fatal(err)
+	}
+}
```

Write `internal/metrics/now_test.go`:

```go
package metrics

import (
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

func TestCurrentNamesTheNodeThatIsRunningAndItsAttempt(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(1, gungnir.Event{Name: gungnir.EventNodeStarted, Node: "plan", Attempt: 1})
	f.log(5, gungnir.Event{Name: gungnir.EventNodeFinished, Node: "plan", Attempt: 1})
	f.log(6, gungnir.Event{Name: gungnir.EventNodeStarted, Node: "g-t1-implement", Attempt: 2, Role: "implementer"})
	now, err := Current(f.done())
	if err != nil {
		t.Fatal(err)
	}
	if now.Node != "g-t1-implement" || now.Attempt != 2 || now.Role != "implementer" || !now.Since.Equal(t0.Add(6*time.Minute)) || now.Between {
		t.Errorf("Current() = %+v", now)
	}
}

func TestCurrentBetweenNodesSaysWhatFinishedLast(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted})
	f.log(1, gungnir.Event{Name: gungnir.EventNodeStarted, Node: "plan", Attempt: 1})
	f.log(5, gungnir.Event{Name: gungnir.EventNodeFinished, Node: "plan", Attempt: 1})
	now, err := Current(f.done())
	if err != nil || !now.Between || now.Node != "plan" || now.Attempt != 1 {
		t.Errorf("Current() = %+v, %v; want between nodes, after plan", now, err)
	}
	empty := newFake(t)
	if now, err := Current(empty.done()); err != nil || now.Node != "" {
		t.Errorf("a run with no line: Current() = %+v, %v", now, err)
	}
}

// The live view reads a ledger another process is writing: a half-written last line is not an error.
func TestCurrentIgnoresALastLineThatIsStillBeingWritten(t *testing.T) {
	f := newFake(t)
	f.log(0, gungnir.Event{Name: gungnir.EventRunStarted}).log(1, gungnir.Event{Name: gungnir.EventNodeStarted, Node: "plan", Attempt: 1})
	dir := f.done()
	appendRaw(t, dir, `{"schema":"ygg.ledger/v1","seq":3,"ti`)
	if now, err := Current(dir); err != nil || now.Node != "plan" {
		t.Errorf("Current() = %+v, %v", now, err)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/metrics [github.com/ouroboric-dev/odin/internal/metrics.test]
internal/metrics/now_test.go:16:14: undefined: Current
internal/metrics/now_test.go:30:14: undefined: Current
internal/metrics/now_test.go:35:17: undefined: Current
```

- [ ] **Step 3:** write the code.

Apply to `README.md`:

```diff
diff --git a/README.md b/README.md
index 5feface..67f0511 100644
--- a/README.md
+++ b/README.md
@@ -20,7 +20,7 @@ ygg run     --graph <name|dir> [--project <dir>] [--config <factory.yaml>] [--br
 ygg resume  <run-id> [--project <dir>] [--mode <mode>]
 ygg approve <run-id> <gate> [--note <text>] [--project <dir>] [--mode <mode>]
 ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
-ygg status  <run-id> [--project <dir>]
+ygg status  <run-id> [--watch [--interval <duration>]] [--project <dir>]
 ygg grade   <run-id> [--task <id>] [--project <dir>]
 ygg metrics <run-id|first..last> [--json] [--project <dir>]
 ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
@@ -59,6 +59,11 @@ intervention with its note, the loops that gave up, and each finding a dispute o
 ledger line it was read from, and the same run always gives the same bytes. Text an agent wrote is quoted, so it cannot
 open a heading or end a block. `--commit` also commits a copy as `docs/runs/<run-id>.md`, because a project ignores `.factory/`.
 
+`ygg status <run-id> --watch` prints the status again every `--interval` (2 seconds by default) while a process holds the
+run, with a `now:` line that names the node that is running, its attempt and how long it has run, and the cost so far.
+It stops when the run stops running, or at once for a run that no process holds. The live view reads a ledger that is
+being written and does not check its chain: `ygg metrics` is the evidence.
+
 `ygg board` shows the project's tasks by column, as a terminal board: Ready, In progress, Verifying, Blocked, Needs you
 and Done, in the plan's order, each with its leaf and, for a blocked task or one that needs you, the reason. It reads
 `.factory/features.json` and the run that file names, and writes nothing. `ygg board --all` shows the board of every project
```

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 8a6defb..d88883f 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -161,6 +161,9 @@ run it names into the `Board` of Gungnir's `Tracker` interface. A task that is d
 works, verifying once the checks and reviewers judge it or its loop has passed, and in needs you when the run stopped at
 one of its gates or failed. The operator's list of projects for `ygg board --all` is local configuration (`projects.yaml` in the config folder), never part of a tree.
 
+`ygg status --watch` is the live view of spec §10.3: it prints the status block again until the run stops running, with the
+node that runs now (`metrics.Current`, the end of the ledger, read while another process writes it).
+
 ## Depends on
 
 - Gungnir's interfaces, Gleipnir (adapters, the sandbox, the check runner) and Jormungandr (the loop).
```

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index ee433c3..e8e482a 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -17,6 +17,7 @@ import (
 	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/odin/internal/budget"
 	"github.com/ouroboric-dev/odin/internal/engine"
+	"github.com/ouroboric-dev/odin/internal/metrics"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
 
@@ -35,7 +36,7 @@ const usage = `usage:
   ygg resume  <run-id> [--project <dir>] [--mode <mode>]
   ygg approve <run-id> <gate> [--note <text>] [--project <dir>] [--mode <mode>]
   ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
-  ygg status  <run-id> [--project <dir>]
+  ygg status  <run-id> [--watch [--interval <duration>]] [--project <dir>]
   ygg grade   <run-id> [--task <id>] [--project <dir>]
   ygg metrics <run-id|first..last> [--json] [--project <dir>]
   ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
@@ -288,21 +289,52 @@ func (c *command) advance(r *run.Run) int {
 }
 
 func (c *command) status(args []string) int {
-	f, pos, ok := c.parse("status", args, 1, func(*flag.FlagSet, *flags) {})
+	var watch bool
+	var every time.Duration
+	f, pos, ok := c.parse("status", args, 1, func(fs *flag.FlagSet, f *flags) {
+		fs.BoolVar(&watch, "watch", false, "print the status again until the run stops running")
+		fs.DurationVar(&every, "interval", 2*time.Second, "with --watch, how often to print again")
+	})
 	if !ok {
 		return ExitRefused
 	}
 	if !run.ValidID(pos[0]) {
 		return c.refuse(fmt.Errorf("%q is not a run id", pos[0]))
 	}
+	if f.set["interval"] && !watch {
+		return c.refuse(fmt.Errorf("--interval is for --watch"))
+	}
+	if watch && (every < 50*time.Millisecond || every > time.Hour) {
+		return c.refuse(fmt.Errorf("--interval %s is not between 50ms and 1h", every))
+	}
 	project, err := filepath.Abs(f.project)
 	if err != nil {
 		return c.refuse(err)
 	}
-	dir := run.Dir(project, pos[0])
+	if !watch {
+		_, code := c.printStatus(project, pos[0])
+		return code
+	}
+	for {
+		s, code := c.printStatus(project, pos[0])
+		if s == nil || code != ExitDone || s.Status != run.StatusRunning || !run.Locked(run.Dir(project, pos[0])) {
+			return code
+		}
+		fmt.Fprintln(c.out)
+		select {
+		case <-c.ctx.Done():
+			return ExitDone
+		case <-time.After(every):
+		}
+	}
+}
+
+// printStatus prints the status of one run, and returns its state so a watch can tell whether it still runs.
+func (c *command) printStatus(project, id string) (*run.State, int) {
+	dir := run.Dir(project, id)
 	s, err := run.LoadState(dir)
 	if err != nil {
-		return c.refuse(err)
+		return nil, c.refuse(err)
 	}
 	status := string(s.Status)
 	if s.Status == run.StatusRunning && !run.Locked(dir) {
@@ -310,6 +342,13 @@ func (c *command) status(args []string) int {
 	}
 	fmt.Fprintf(c.out, "run:      %s\nstatus:   %s\nmode:     %s\ngraph:    %s %s\nposition: %d\n",
 		s.ID, status, s.Mode, s.Graph, s.GraphVersion, s.Position)
+	if now, err := metrics.Current(dir); err == nil && now.Node != "" && s.Status == run.StatusRunning {
+		if now.Between {
+			fmt.Fprintf(c.out, "now:      between nodes, after %s (attempt %d)\n", now.Node, now.Attempt)
+		} else {
+			fmt.Fprintf(c.out, "now:      %s, attempt %d, for %s\n", now.Node, now.Attempt, time.Since(now.Since).Round(time.Second))
+		}
+	}
 	if s.Pending != "" {
 		fmt.Fprintf(c.out, "waiting:  %s (%s)\n", s.Pending, s.PendingGate)
 	}
@@ -361,7 +400,7 @@ func (c *command) status(args []string) int {
 		fmt.Fprintf(c.out, "caps:     %s\n", line)
 	}
 	c.bumpLines(project, s.ConfigPath)
-	return ExitDone
+	return s, ExitDone
 }
 
 // blockedTasks lists the tasks the run gave up, one line each, with why.
```

Write `internal/metrics/now.go`:

```go
package metrics

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

// Now is where a run is, for the live view.
type Now struct {
	Node    string
	Attempt int
	Role    string
	Since   time.Time // when the node started
	Between bool      // no node is running: Node is the one that finished last
}

// Current reads the end of a run's ledger. The live view reads a ledger another process is writing, so it does
// not check the hash chain, ignores a last line that is still being written, and is not evidence: ygg metrics is.
func Current(dir string) (Now, error) {
	data, err := os.ReadFile(filepath.Join(dir, "ledger.jsonl"))
	if err != nil {
		return Now{}, err
	}
	if i := bytes.LastIndexByte(data, '\n'); i >= 0 {
		data = data[:i+1]
	} else {
		data = nil
	}
	var now Now
	for _, line := range bytes.Split(data, []byte("\n")) {
		if len(line) == 0 {
			continue
		}
		var e gungnir.Event
		if err := json.Unmarshal(line, &e); err != nil {
			return Now{}, err
		}
		switch e.Name {
		case gungnir.EventNodeStarted:
			now = Now{Node: e.Node, Attempt: e.Attempt, Role: e.Role, Since: e.Time}
		case gungnir.EventNodeFinished, gungnir.EventNodeFailed:
			if e.Node == now.Node && e.Attempt == now.Attempt {
				now.Between = true
			}
		}
	}
	return now, nil
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T286: the factory's end of the Harbor bridge

The Harbor adapter (`bench/harbor/ygg_harbor/agent.py`) runs the factory as a command and talks JSON lines over its standard
input and output: the adapter sends one `start` line; the factory sends requests `{"id", "op", …}` and the adapter answers each
`{"id", "ok", …}`. "Yggdrasil's own side is built with the benchmark runs (plan Phase 6)", says v0-T018. This task is the
protocol client; v0-T287 is the verb. Same branch as v0-T282.

**Files (in `odin`):**

- Create: `internal/bridge/conn.go`, `internal/bridge/conn_test.go`

**Interfaces:**

- Produces: `bridge.NewConn(in io.Reader, out io.Writer) *bridge.Conn`; `ReadStart() (bridge.Start, error)` with
  `Start{Type, Instruction, Workdir string; BudgetUSD float64}`; `UploadDir(source, target string) error`;
  `Selfcheck() (bridge.Check, error)`; `Spend(usd float64) error`; `Done() (bridge.Check, error)` with `Check{Passed bool;
  Detail string}`; `*bridge.RemoteError{Op, Msg}` for a request that the adapter refused or could not carry out.
- The rule: `ReadStart` refuses a line that is not JSON, not of type `start`, with no instruction, with a workdir that is not
  absolute, with a budget of 0 or less, or with an unknown field. Ids count up from 1; a reply must carry the id of the request
  it answers; `ok: false` is a `RemoteError` with the adapter's words; a line from the adapter over 1 MiB, or an adapter that
  hangs up before it answers, is an error. Requests from two goroutines are sent one at a time.

**Acceptance criteria:**

- [ ] The start line gives the brief, the workdir and the budget; each of the seven bad start lines is refused.
- [ ] Two requests carry the ids 1 and 2, and a reply for another id is an error that names the id.
- [ ] A refused upload is a `RemoteError` that carries "OPENROUTER_API_KEY" from the adapter's text.
- [ ] `upload_dir`, `selfcheck` and `done` send the fields the adapter reads (`source`, `target`) and read `passed` and
      `detail`; a failed self-check is reported, not turned into an error.
- [ ] 20 concurrent `Spend` calls send 20 requests with 20 different ids (under `-race`).

**Review focus pinned by tests:** every test of the task, and the six mutations in "Evidence".

**Named test:** `go test -race ./internal/bridge` in `odin`. **Layer:** `odin`. **Size:** M (360). **Depends on:** none.

- [ ] **Step 1:** write the tests.

Write `internal/bridge/conn_test.go`:

```go
package bridge

import (
	"bufio"
	"encoding/json"
	"errors"
	"io"
	"strings"
	"sync"
	"testing"
)

// adapter plays the Harbor agent adapter (bench/harbor/ygg_harbor/agent.py) on the other end of the pipes: it
// sends the start line, then answers each request line with the handler of its op, one at a time.
type adapter struct {
	t        *testing.T
	toYgg    *io.PipeWriter
	fromYgg  *bufio.Reader
	mu       sync.Mutex
	requests []map[string]any
}

func newConn(t *testing.T, start string) (*Conn, *adapter) {
	t.Helper()
	inR, inW := io.Pipe()   // adapter to factory
	outR, outW := io.Pipe() // factory to adapter
	a := &adapter{t: t, toYgg: inW, fromYgg: bufio.NewReader(outR)}
	go func() {
		if start != "" {
			inW.Write([]byte(start + "\n")) //nolint:errcheck // the pipe closes when the test ends
		}
	}()
	t.Cleanup(func() { inW.Close(); outW.Close() })
	return NewConn(inR, outW), a
}

// answer reads one request and replies with reply(request). It returns the request.
func (a *adapter) answer(reply func(map[string]any) string) map[string]any {
	a.t.Helper()
	line, err := a.fromYgg.ReadBytes('\n')
	if err != nil {
		a.t.Fatalf("the factory wrote no request: %v", err)
	}
	var req map[string]any
	if err := json.Unmarshal(line, &req); err != nil {
		a.t.Fatalf("the factory wrote a line that is not a request: %q", line)
	}
	a.mu.Lock()
	a.requests = append(a.requests, req)
	a.mu.Unlock()
	if _, err := a.toYgg.Write([]byte(reply(req) + "\n")); err != nil {
		a.t.Fatal(err)
	}
	return req
}

func ok(fields string) func(map[string]any) string {
	return func(req map[string]any) string {
		id, _ := json.Marshal(req["id"])
		return `{"id":` + string(id) + `,"ok":true` + fields + `}`
	}
}

const goodStart = `{"type":"start","instruction":"Build the thing.","workdir":"/app","budget_usd":100}`

func TestTheStartLineGivesTheBriefTheWorkdirAndTheBudget(t *testing.T) {
	c, _ := newConn(t, goodStart)
	s, err := c.ReadStart()
	if err != nil || s.Instruction != "Build the thing." || s.Workdir != "/app" || s.BudgetUSD != 100 {
		t.Errorf("ReadStart() = %+v, %v", s, err)
	}
}

func TestAStartLineThatIsNotAStartIsRefused(t *testing.T) {
	for name, line := range map[string]string{
		"not JSON":           `hello`,
		"another type":       `{"type":"go","instruction":"x","workdir":"/app","budget_usd":1}`,
		"no instruction":     `{"type":"start","instruction":"","workdir":"/app","budget_usd":1}`,
		"a relative workdir": `{"type":"start","instruction":"x","workdir":"app","budget_usd":1}`,
		"no budget":          `{"type":"start","instruction":"x","workdir":"/app","budget_usd":0}`,
		"a negative budget":  `{"type":"start","instruction":"x","workdir":"/app","budget_usd":-5}`,
		"an unknown field":   `{"type":"start","instruction":"x","workdir":"/app","budget_usd":1,"root":true}`,
	} {
		c, _ := newConn(t, line)
		if s, err := c.ReadStart(); err == nil {
			t.Errorf("%s: ReadStart() = %+v, nil; want a refusal", name, s)
		}
	}
	c, a := newConn(t, "")
	a.toYgg.Close()
	if _, err := c.ReadStart(); err == nil {
		t.Error("an adapter that sent nothing: ReadStart() = nil")
	}
}

func TestEachRequestCarriesTheNextIDAndTheReplyMustBeForIt(t *testing.T) {
	c, a := newConn(t, "")
	go func() {
		a.answer(ok(""))
		a.answer(func(req map[string]any) string { return `{"id":99,"ok":true}` }) // an answer to another request
	}()
	if err := c.Spend(0.5); err != nil {
		t.Fatalf("first request: %v", err)
	}
	if err := c.Spend(0.7); err == nil || !strings.Contains(err.Error(), "id") {
		t.Errorf("a reply for another id: Spend() = %v; want an error that names the id", err)
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	if len(a.requests) != 2 || a.requests[0]["id"] != float64(1) || a.requests[1]["id"] != float64(2) || a.requests[0]["op"] != "spend" || a.requests[0]["usd"] != 0.5 {
		t.Errorf("requests = %+v", a.requests)
	}
}

func TestARefusedRequestIsARemoteErrorWithTheAdaptersWords(t *testing.T) {
	c, a := newConn(t, "")
	go a.answer(func(req map[string]any) string {
		id, _ := json.Marshal(req["id"])
		return `{"id":` + string(id) + `,"ok":false,"error":"refused: the value of OPENROUTER_API_KEY in key.txt"}`
	})
	err := c.UploadDir("/tmp/product", "/app")
	var re *RemoteError
	if !errors.As(err, &re) || re.Op != "upload_dir" || !strings.Contains(re.Msg, "OPENROUTER_API_KEY") {
		t.Errorf("UploadDir() = %v; want a *RemoteError that carries the adapter's words", err)
	}
}

func TestUploadSelfcheckAndDoneSendTheFieldsTheAdapterReads(t *testing.T) {
	c, a := newConn(t, "")
	go func() {
		a.answer(ok(""))
		a.answer(ok(`,"passed":true,"detail":"PASS port 3000 answered"`))
		a.answer(ok(`,"passed":false,"detail":"FAIL start.sh is missing"`))
	}()
	if err := c.UploadDir("/tmp/product", "/app"); err != nil {
		t.Fatal(err)
	}
	if got, err := c.Selfcheck(); err != nil || !got.Passed || got.Detail != "PASS port 3000 answered" {
		t.Errorf("Selfcheck() = %+v, %v", got, err)
	}
	if got, err := c.Done(); err != nil || got.Passed || !strings.HasPrefix(got.Detail, "FAIL") {
		t.Errorf("Done() = %+v, %v; a failed self-check still ends the run and is reported, not hidden", got, err)
	}
	a.mu.Lock()
	defer a.mu.Unlock()
	if r := a.requests[0]; r["op"] != "upload_dir" || r["source"] != "/tmp/product" || r["target"] != "/app" {
		t.Errorf("upload_dir request = %+v", r)
	}
	if a.requests[1]["op"] != "selfcheck" || a.requests[2]["op"] != "done" {
		t.Errorf("requests = %+v", a.requests)
	}
}

func TestAnAdapterThatHangsUpMidRequestIsAnErrorNotAHang(t *testing.T) {
	c, a := newConn(t, "")
	go func() {
		a.fromYgg.ReadBytes('\n') //nolint:errcheck // read the request, then hang up without a reply
		a.toYgg.Close()
	}()
	if err := c.Spend(1); err == nil || !strings.Contains(err.Error(), "closed") {
		t.Errorf("Spend() = %v; want an error that says the bridge closed", err)
	}
}

// The reporter of spend runs beside the main flow; two requests must never interleave on the line.
func TestRequestsFromTwoGoroutinesAreSentOneAtATime(t *testing.T) {
	c, a := newConn(t, "")
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := c.Spend(1); err != nil {
				t.Errorf("Spend() = %v", err)
			}
		}()
		a.answer(ok(""))
	}
	wg.Wait()
	seen := map[float64]bool{}
	a.mu.Lock()
	defer a.mu.Unlock()
	for _, r := range a.requests {
		seen[r["id"].(float64)] = true
	}
	if len(seen) != 20 {
		t.Errorf("%d different ids in 20 requests", len(seen))
	}
}

func TestAReplyLineOverTheBoundIsRefused(t *testing.T) {
	c, a := newConn(t, "")
	go a.answer(func(req map[string]any) string {
		return `{"id":1,"ok":true,"detail":"` + strings.Repeat("x", maxLine+10) + `"}`
	})
	if err := c.Spend(1); err == nil {
		t.Error("Spend() accepted a reply line over the bound")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/bridge [github.com/ouroboric-dev/odin/internal/bridge.test]
internal/bridge/conn_test.go:23:44: undefined: Conn
internal/bridge/conn_test.go:34:9: undefined: NewConn
internal/bridge/conn_test.go:122:10: undefined: RemoteError
```

- [ ] **Step 3:** write the code.

Write `internal/bridge/conn.go`:

```go
// Package bridge is Yggdrasil's side of the Harbor bridge (bench/harbor/ygg_harbor/agent.py): JSON lines over the
// factory's standard input and output. The adapter sends one start line; the factory then sends requests
// ({"id","op",...}) and the adapter answers each ({"id","ok",...}). Standard output carries requests and nothing
// else: a line that is not a request makes the adapter fail the run.
package bridge

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"path"
	"sync"
)

// maxLine bounds one line from the adapter. A reply to the requests used here is a few hundred bytes.
const maxLine = 1 << 20

// Start is the adapter's first line: the brief, where the product goes in the task environment, and the budget
// Harbor does not enforce.
type Start struct {
	Type        string  `json:"type"`
	Instruction string  `json:"instruction"`
	Workdir     string  `json:"workdir"`
	BudgetUSD   float64 `json:"budget_usd"`
}

// Check is the result of the adapter's self-check of the product in the task environment.
type Check struct {
	Passed bool   `json:"passed"`
	Detail string `json:"detail"`
}

// RemoteError is a request the adapter refused or could not carry out; Msg is its own words.
type RemoteError struct{ Op, Msg string }

func (e *RemoteError) Error() string { return "the adapter did not carry out " + e.Op + ": " + e.Msg }

// Conn is the factory's end of the bridge. Its methods may be called from several goroutines: each request is
// sent and answered before the next one goes out.
type Conn struct {
	in   *bufio.Reader
	out  io.Writer
	mu   sync.Mutex
	next int
}

// NewConn makes the factory's end from the adapter's output (the factory's standard input) and the factory's
// standard output.
func NewConn(in io.Reader, out io.Writer) *Conn { return &Conn{in: bufio.NewReader(in), out: out} }

// ReadStart reads and checks the start line.
func (c *Conn) ReadStart() (Start, error) {
	line, err := c.readLine()
	if err != nil {
		return Start{}, fmt.Errorf("no start line from the adapter: %w", err)
	}
	var s Start
	dec := json.NewDecoder(bytes.NewReader(line))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&s); err != nil {
		return Start{}, fmt.Errorf("the first line from the adapter is not a start line: %w", err)
	}
	switch {
	case s.Type != "start":
		return Start{}, fmt.Errorf("the first line from the adapter has the type %q, want start", s.Type)
	case s.Instruction == "":
		return Start{}, errors.New("the start line holds no instruction")
	case !path.IsAbs(s.Workdir):
		return Start{}, fmt.Errorf("the start line's workdir %q is not an absolute path", s.Workdir)
	case s.BudgetUSD <= 0:
		return Start{}, fmt.Errorf("the start line's budget_usd is %v, want more than 0", s.BudgetUSD)
	}
	return s, nil
}

// UploadDir asks the adapter to copy the host folder source into target of the task environment.
func (c *Conn) UploadDir(source, target string) error {
	_, err := c.call("upload_dir", map[string]any{"source": source, "target": target})
	return err
}

// Selfcheck asks the adapter to run its self-check on the product now.
func (c *Conn) Selfcheck() (Check, error) { return c.check("selfcheck") }

// Spend reports the run's total cost so far. The adapter stops the factory when it passes the budget.
func (c *Conn) Spend(usd float64) error {
	_, err := c.call("spend", map[string]any{"usd": usd})
	return err
}

// Done ends the run. The adapter runs its self-check once more and answers with it; the factory exits after.
func (c *Conn) Done() (Check, error) { return c.check("done") }

func (c *Conn) check(op string) (Check, error) {
	reply, err := c.call(op, nil)
	if err != nil {
		return Check{}, err
	}
	var ch Check
	if err := json.Unmarshal(reply, &ch); err != nil {
		return Check{}, fmt.Errorf("the reply to %s is not a check: %w", op, err)
	}
	return ch, nil
}

// call sends one request and returns the adapter's reply line once it answers that request.
func (c *Conn) call(op string, fields map[string]any) ([]byte, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.next++
	req := map[string]any{"id": c.next, "op": op}
	for k, v := range fields {
		req[k] = v
	}
	b, err := json.Marshal(req)
	if err != nil {
		return nil, err
	}
	if _, err := c.out.Write(append(b, '\n')); err != nil {
		return nil, fmt.Errorf("the bridge is closed: %w", err)
	}
	line, err := c.readLine()
	if err != nil {
		return nil, fmt.Errorf("the adapter closed the bridge before it answered %s: %w", op, err)
	}
	var reply struct {
		ID    *int   `json:"id"`
		OK    bool   `json:"ok"`
		Error string `json:"error"`
	}
	if err := json.Unmarshal(line, &reply); err != nil {
		return nil, fmt.Errorf("the reply to %s is not JSON: %w", op, err)
	}
	if reply.ID == nil || *reply.ID != c.next {
		return nil, fmt.Errorf("the reply to %s has the id %v, want %d", op, reply.ID, c.next)
	}
	if !reply.OK {
		return nil, &RemoteError{Op: op, Msg: reply.Error}
	}
	return line, nil
}

func (c *Conn) readLine() ([]byte, error) {
	var line []byte
	for {
		chunk, isPrefix, err := c.in.ReadLine()
		if err != nil {
			return nil, err
		}
		line = append(line, chunk...)
		if len(line) > maxLine {
			return nil, fmt.Errorf("a line from the adapter is longer than %d bytes", maxLine)
		}
		if !isPrefix {
			return line, nil
		}
	}
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T287: `ygg bridge`

The verb that Harbor starts. The adapter sends the brief; `ygg bridge` makes a scratch project (a git repository whose
`umbrella.yaml` sets `root: true`), runs the graph on the brief as `ygg run` would, with the run's own output on standard
error, reports the run's cost, copies the committed product to the task environment's working folder through `upload_dir`, asks
for a self-check and says `done`. Standard output carries requests and nothing else: a line that is not a request fails the
adapter's run. A Harbor run has no one to approve a gate, so a run that stops is handed over as it is, and the exit code is the
run's. A run that was refused before it started sends nothing, so that the adapter fails the run for want of `done`. Same branch.

**Files (in `odin`):**

- Create: `internal/cli/bridge.go`, `internal/cli/bridge_test.go`
- Modify: `README.md`, `docs/architecture.md`, `internal/cli/cli.go`, `internal/cli/docs_test.go`

**Interfaces:**

- Produces: `cli.MainWithInput(ctx, args, stdin, stdout, stderr) int` (`Main` calls it with `os.Stdin`) and
  `ygg bridge --config <factory.yaml> --graph <name|dir> [--work <dir>] [--mode <mode>]`. `--work` must not exist yet; the
  default is a temporary folder that is removed at the end.
- Produces: `cli.checkTaskBudget(cfg, budget)`: when a role pays per token, `budget.per_run.usd` above the task's `budget_usd`
  is refused.
- The sequence: read the start line; check the budget; make the project and `brief.md`; run (the cost is reported every 30
  seconds); on any exit but 2, `spend`, `upload_dir`, `selfcheck`, `done`. The product is `Run.ExportApp`, the same export that
  the grader uses.

**Acceptance criteria:**

- [ ] The toy graph, with scripted agents, runs on the brief; the requests end `spend`, `upload_dir /app`, `selfcheck`, `done`;
      the uploaded copy holds the committed leaf file; `brief.md` is the instruction; stderr says "the run ended with exit code 0".
- [ ] Every line on standard output is a request with an id and an op; the run's own output is on standard error.
- [ ] A run that stops at the design gate (key-points) is handed over, with exit 3, and stderr says where it stopped and that no
      one can approve.
- [ ] No config, no graph, a bad start line, a bad config, a graph that is not there and a `--work` that exists each exit 2 with
      no request sent.
- [ ] A paid role's per-run dollar cap above the task's budget is refused; a subscription's dollar figure is not a cap.

**Review focus pinned by tests:** `TestBridgeWritesNothingToStandardOutputButRequests`,
`TestBridgeRefusesWhatItCannotRunBeforeItStartsAnything`.

**Named test:** `go test -race ./internal/cli -run 'TestBridge|TestACapOfThePaidRolesAboveTheTasksBudgetIsRefused|TestTheDocsNameEveryCommand'`
in `odin`. **Layer:** `odin`. **Size:** M (399). **Depends on:** v0-T286, v0-T289.

- [ ] **Step 1:** write the tests.

Write `internal/cli/bridge_test.go`:

```go
package cli

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
)

// harbor plays the Harbor agent adapter for `ygg bridge`: it sends the start line, answers each request, and
// copies a folder the factory uploads into its own, as the adapter copies it into the task environment.
type harbor struct {
	stdout   []string // every line the factory wrote to standard output
	requests []map[string]any
	uploaded string // where the uploaded folder was copied
	code     int
	stderr   string
}

func runBridge(t *testing.T, start string, args ...string) *harbor {
	t.Helper()
	h := &harbor{uploaded: t.TempDir()}
	inR, inW := io.Pipe()
	outR, outW := io.Pipe()
	var errBuf strings.Builder
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		h.code = MainWithInput(context.Background(), append([]string{"bridge"}, args...), inR, outW, &errBuf)
		outW.Close()
	}()
	// A bridge that refuses before it reads its input never takes the start line, and a pipe write waits.
	go fmt.Fprintln(inW, start) //nolint:errcheck // the pipe closes when the test ends
	sc := bufio.NewScanner(outR)
	sc.Buffer(make([]byte, 0, 64*1024), 1<<20)
	for sc.Scan() {
		line := sc.Text()
		h.stdout = append(h.stdout, line)
		var req map[string]any
		if json.Unmarshal([]byte(line), &req) != nil {
			continue // agent.py would answer with an error; the test only needs to see the line
		}
		h.requests = append(h.requests, req)
		reply := map[string]any{"id": req["id"], "ok": true}
		switch req["op"] {
		case "upload_dir":
			if err := os.CopyFS(h.uploaded, os.DirFS(req["source"].(string))); err != nil {
				reply["ok"], reply["error"] = false, err.Error()
			}
		case "selfcheck", "done":
			reply["passed"], reply["detail"] = true, "PASS port 3000 answered"
		}
		b, _ := json.Marshal(reply)
		fmt.Fprintln(inW, string(b))
		if req["op"] == "done" {
			break
		}
	}
	inW.Close()
	wg.Wait()
	inR.Close()
	h.stderr = errBuf.String()
	return h
}

func (h *harbor) ops() []string {
	var ops []string
	for _, r := range h.requests {
		// An upload shows where it goes ("upload_dir/app"): that is part of what the test checks.
		ops = append(ops, r["op"].(string)+strings.TrimPrefix(fmt.Sprint(r["target"]), "<nil>"))
	}
	return ops
}

func bridgeStart(budget string) string {
	return `{"type":"start","instruction":"Build the toy product.\n","workdir":"/app","budget_usd":` + budget + `}`
}

func TestBridgeRunsTheFactoryOnTheBriefAndUploadsTheCommittedProductThenSaysDone(t *testing.T) {
	_, config := project(t, "script.yaml", "mode: unattended\ngates:\n  design: auto\n")
	work := filepath.Join(t.TempDir(), "work")
	h := runBridge(t, bridgeStart("100"), "--config", config, "--graph", toyRealm(t), "--work", work)
	if h.code != ExitDone {
		t.Fatalf("exit %d, stderr:\n%s", h.code, h.stderr)
	}
	ops := h.ops()
	if got := strings.Join(ops, " "); !strings.HasSuffix(got, "spend upload_dir/app selfcheck done") {
		t.Errorf("requests = %s; want spend, upload_dir, selfcheck, done in the end", got)
	}
	if _, err := os.Stat(filepath.Join(h.uploaded, "repos", "app", "build.txt")); err != nil {
		t.Errorf("the committed product is not in the upload: %v", err)
	}
	if b, _ := os.ReadFile(filepath.Join(work, "brief.md")); !strings.HasPrefix(string(b), "Build the toy product.") {
		t.Errorf("the run's brief = %q", b)
	}
	if !strings.Contains(h.stderr, "the run ended with exit code 0") {
		t.Errorf("stderr lacks the run's outcome:\n%s", h.stderr)
	}
}

// Standard output is the bridge. A line that is not a request fails the adapter's run.
func TestBridgeWritesNothingToStandardOutputButRequests(t *testing.T) {
	_, config := project(t, "script.yaml", "mode: unattended\ngates:\n  design: auto\n")
	h := runBridge(t, bridgeStart("100"), "--config", config, "--graph", toyRealm(t), "--work", filepath.Join(t.TempDir(), "w"))
	if len(h.stdout) == 0 || len(h.stdout) != len(h.requests) {
		t.Fatalf("%d lines on standard output, %d of them requests:\n%s", len(h.stdout), len(h.requests), strings.Join(h.stdout, "\n"))
	}
	for _, r := range h.requests {
		if r["id"] == nil || r["op"] == nil {
			t.Errorf("a request without an id or an op: %v", r)
		}
	}
	if !strings.Contains(h.stderr, "run ") {
		t.Errorf("the factory's own output should go to standard error:\n%s", h.stderr)
	}
}

// Harbor has no one to approve a gate. The run stops, and the bridge still hands over what exists and ends.
func TestBridgeSendsWhatExistsAndDoneWhenTheRunStopsAtAGate(t *testing.T) {
	_, config := project(t, "script.yaml", "mode: key-points\n")
	h := runBridge(t, bridgeStart("100"), "--config", config, "--graph", toyRealm(t), "--work", filepath.Join(t.TempDir(), "w"))
	if h.code != ExitStopped {
		t.Fatalf("exit %d, want %d (the run stopped at the design gate):\n%s", h.code, ExitStopped, h.stderr)
	}
	if got := strings.Join(h.ops(), " "); !strings.HasSuffix(got, "upload_dir/app selfcheck done") {
		t.Errorf("requests = %s; the run is over for Harbor, so it must still end with done", got)
	}
	if !strings.Contains(h.stderr, "design-gate") || !strings.Contains(h.stderr, "no one to approve") {
		t.Errorf("stderr must say where and why it stopped:\n%s", h.stderr)
	}
}

func TestBridgeRefusesWhatItCannotRunBeforeItStartsAnything(t *testing.T) {
	_, config := project(t, "script.yaml", "mode: unattended\n")
	for name, c := range map[string]struct {
		start string
		args  []string
	}{
		"no config":                 {bridgeStart("100"), []string{"--graph", toyRealm(t)}},
		"no graph":                  {bridgeStart("100"), []string{"--config", config}},
		"a bad start":               {`{"type":"stop"}`, []string{"--config", config, "--graph", toyRealm(t)}},
		"a graph that is not there": {bridgeStart("100"), []string{"--config", config, "--graph", "/no/such/graph"}},
		"a bad config":              {bridgeStart("100"), []string{"--config", "/no/such/factory.yaml", "--graph", toyRealm(t)}},
		"a work folder that exists": {bridgeStart("100"), []string{"--config", config, "--graph", toyRealm(t), "--work", os.TempDir()}},
	} {
		h := runBridge(t, c.start, c.args...)
		if h.code != ExitRefused || len(h.requests) != 0 || h.stderr == "" {
			t.Errorf("%s: exit %d, %d requests, stderr %q; want a refusal and no request", name, h.code, len(h.requests), h.stderr)
		}
	}
}

// The adapter stops the factory when spend passes its budget, but the factory should never plan to.
func TestACapOfThePaidRolesAboveTheTasksBudgetIsRefused(t *testing.T) {
	paid := &schema.Factory{Roles: map[string]schema.Role{"implementer": {Agent: "opencode", Model: "openrouter/x"}}, Budget: schema.Budget{PerRun: schema.Cap{USD: 50}}}
	if err := checkTaskBudget(paid, 10); err == nil || !strings.Contains(err.Error(), "50") {
		t.Errorf("checkTaskBudget(paid $50, $10) = %v; want a refusal that names the cap", err)
	}
	if err := checkTaskBudget(paid, 100); err != nil {
		t.Errorf("checkTaskBudget(paid $50, $100) = %v", err)
	}
	sub := &schema.Factory{Roles: map[string]schema.Role{"implementer": {Agent: "claude-code", Model: "sonnet"}}, Budget: schema.Budget{PerRun: schema.Cap{USD: 50}}}
	if err := checkTaskBudget(sub, 10); err != nil {
		t.Errorf("a subscription's dollar figure is not a cap: checkTaskBudget() = %v", err)
	}
}
```

Apply to `internal/cli/docs_test.go`:

```diff
diff --git a/internal/cli/docs_test.go b/internal/cli/docs_test.go
index bdac5b7..603e80e 100644
--- a/internal/cli/docs_test.go
+++ b/internal/cli/docs_test.go
@@ -30,7 +30,7 @@ func TestTheDocsNameEveryCommand(t *testing.T) {
 	}
 	for _, want := range []string{"ygg grade", "ygg deps bump", "`grade` node", "--canary", "--host", "--task", "grade_refused", "score.json", "ygg.grader",
 		"REPOS.md", ".ygg/impact.json", "shrink guard", "pointer-contract", "routing_index_built", "pointer_contract_checked", "deps_bump", "memory: none",
-		"ygg metrics", "--watch", "ygg board", "projects.yaml", "ygg report", "docs/runs", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
+		"ygg metrics", "ygg bridge", "Harbor", "--watch", "ygg board", "projects.yaml", "ygg report", "docs/runs", "--compare", "not comparable", "ygg.factory.version", "dispute_ignored", "approval wait", "--graph", "graphs.dir", "graph pin", "ygg.run/v3", "factory layer", "snapshot/<node>/<realm>"} {
 		if !strings.Contains(string(arch), want) {
 			t.Errorf("docs/architecture.md does not mention %q", want)
 		}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/cli [github.com/ouroboric-dev/odin/internal/cli.test]
internal/cli/bridge_test.go:38:12: undefined: MainWithInput
internal/cli/bridge_test.go:165:12: undefined: checkTaskBudget
internal/cli/bridge_test.go:168:12: undefined: checkTaskBudget
```

- [ ] **Step 3:** write the code.

Apply to `README.md`:

```diff
diff --git a/README.md b/README.md
index 67f0511..c3192e0 100644
--- a/README.md
+++ b/README.md
@@ -26,6 +26,7 @@ ygg metrics <run-id|first..last> [--json] [--project <dir>]
 ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
 ygg report  <run-id> [--commit] [--project <dir>]
 ygg board   [--project <dir>] | --all [--projects <file>]
+ygg bridge  --config <factory.yaml> --graph <name|dir> [--work <dir>] [--mode <mode>]
 ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
 ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
 ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -70,6 +71,13 @@ and Done, in the plan's order, each with its leaf and, for a blocked task or one
 in the operator's local list, `$XDG_CONFIG_HOME/ouroboric/projects.yaml` (or `~/.config/ouroboric/projects.yaml`, or the file
 `--projects` names): `projects:` and a list of absolute paths. A path that is not a project umbrella refuses the whole list.
 
+`ygg bridge` is the factory's side of the Harbor bridge (`bench/harbor`). The Harbor adapter starts it and sends the brief
+on standard input as one JSON line. It makes a scratch project, runs the graph on the brief, copies the committed
+product to the task environment's working folder through the adapter (`upload_dir`), asks for a self-check, reports the
+cost so far and says `done`. Standard output carries the bridge and nothing else; the run's own output goes to standard
+error. A Harbor run has no one to approve a gate: a run that stops is handed over as it is, and the exit code is the
+run's. The config's `budget.per_run.usd` must not be above the task's budget when a role bills per token.
+
 `ygg deps bump` runs the package manager and the checks in the sandbox of `factory.yaml`. Without a `sandbox:`
 section it refuses (exit 2) unless you pass `--host`, which runs the bump on the host with the full network and
 your user id, and records that in the first line of the bump's ledger. With a sandbox section `--host` has no effect.
```

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index d88883f..43a8ab4 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -164,6 +164,11 @@ one of its gates or failed. The operator's list of projects for `ygg board --all
 `ygg status --watch` is the live view of spec §10.3: it prints the status block again until the run stops running, with the
 node that runs now (`metrics.Current`, the end of the ledger, read while another process writes it).
 
+`ygg bridge` (packages `internal/bridge` and `internal/cli`) is Yggdrasil's side of the Harbor bridge: the start line,
+then `upload_dir`, `selfcheck`, `spend` and `done` requests, one at a time, each answered with its id. A reply for another
+id, a refusal and a line over 1 MiB are errors. The run, its checks and its sandboxes are the same as for `ygg run`; the
+Harbor verifier, not Odin's grader, scores the product.
+
 ## Depends on
 
 - Gungnir's interfaces, Gleipnir (adapters, the sandbox, the check runner) and Jormungandr (the loop).
```

Write `internal/cli/bridge.go`:

```go
package cli

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"sync"
	"time"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/bridge"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
)

// spendEvery is how often the bridge tells the adapter what the run has cost so far.
var spendEvery = 30 * time.Second

// bridge runs ygg bridge: the factory on a Harbor task (bench/harbor). The adapter starts it and sends the brief
// on standard input; it runs the graph in a scratch project, hands the committed product to the adapter, and says
// done. Standard output is the bridge and nothing else. A run that stops at a gate is handed over as it is, for no
// one can approve in a Harbor run. The exit code is the run's, or 2 when nothing could start.
func (c *command) bridge(args []string) int {
	var work string
	f, _, ok := c.parse("bridge", args, 0, func(fs *flag.FlagSet, f *flags) {
		fs.StringVar(&f.config, "config", "", "the factory config")
		fs.StringVar(&f.graph, "graph", "", "the graph pack: a name or a folder")
		fs.StringVar(&work, "work", "", "a folder to work in, which must not exist yet (default: a temporary one, removed at the end)")
	})
	if !ok {
		return ExitRefused
	}
	if f.config == "" || f.graph == "" {
		return c.refuse(errors.New("bridge needs --config and --graph"))
	}
	cfg, err := schema.LoadFactory(f.config)
	if err != nil {
		return c.refuse(err)
	}
	conn := bridge.NewConn(c.in, c.out)
	start, err := conn.ReadStart()
	if err != nil {
		return c.refuse(err)
	}
	if err := checkTaskBudget(cfg, start.BudgetUSD); err != nil {
		return c.refuse(err)
	}
	if work == "" {
		if work, err = os.MkdirTemp("", "ygg-bridge-"); err != nil {
			return c.refuse(err)
		}
		defer os.RemoveAll(work)
	} else if err := os.Mkdir(work, 0o755); err != nil {
		return c.refuse(fmt.Errorf("--work must be a folder that does not exist yet: %w", err))
	}
	project, brief := filepath.Join(work, "project"), filepath.Join(work, "brief.md")
	if err := newProject(c.ctx, project); err != nil {
		return c.refuse(err)
	}
	if err := os.WriteFile(brief, []byte(start.Instruction), 0o644); err != nil {
		return c.refuse(err)
	}

	// The run prints to standard error: standard output is the bridge.
	sub := &command{ctx: c.ctx, out: c.err, err: c.err}
	stopSpend := c.reportSpend(conn, project)
	runArgs := []string{"--project", project, "--config", f.config, "--graph", f.graph, "--brief", brief}
	if f.mode != "" {
		runArgs = append(runArgs, "--mode", f.mode)
	}
	code := sub.run(runArgs)
	stopSpend()
	fmt.Fprintf(c.err, "bridge: the run ended with exit code %d\n", code)
	if code == ExitRefused {
		return code // nothing started: no product to hand over, and the adapter fails the run for want of done
	}

	state := lastState(project)
	if state != nil {
		if state.Pending != "" {
			fmt.Fprintf(c.err, "bridge: the run stopped at %s (%s): there is no one to approve in a Harbor run, so what exists is handed over\n", state.Pending, state.PendingGate)
		}
		if err := conn.Spend(state.Usage.CostUSD); err != nil {
			fmt.Fprintf(c.err, "bridge: %v\n", err)
		}
	}
	export := filepath.Join(work, "export")
	if err := c.exportProduct(project, export); err != nil {
		fmt.Fprintf(c.err, "bridge: %v\n", err)
		code = max(code, ExitFailed)
	} else if err := conn.UploadDir(export, start.Workdir); err != nil {
		fmt.Fprintf(c.err, "bridge: %v\n", err)
		code = max(code, ExitFailed)
	}
	if ch, err := conn.Selfcheck(); err != nil {
		fmt.Fprintf(c.err, "bridge: %v\n", err)
	} else {
		fmt.Fprintf(c.err, "bridge: the adapter's self-check: passed=%v %s\n", ch.Passed, ch.Detail)
	}
	ch, err := conn.Done()
	if err != nil {
		fmt.Fprintf(c.err, "bridge: %v\n", err)
		return max(code, ExitFailed)
	}
	fmt.Fprintf(c.err, "bridge: done; the adapter's final self-check: passed=%v %s\n", ch.Passed, ch.Detail)
	return code
}

// checkTaskBudget refuses a config whose cap for one run is above the budget the task gives, when a role pays
// per token. A subscription's dollar figure is what the run would cost on the API: it is no cap.
func checkTaskBudget(cfg *schema.Factory, budget float64) error {
	if cfg.PaysPerToken() && cfg.Budget.PerRun.USD > budget {
		return fmt.Errorf("the config lets one run spend $%v and the task's budget is $%v; lower budget.per_run.usd", cfg.Budget.PerRun.USD, budget)
	}
	return nil
}

// reportSpend starts a goroutine that sends the run's cost so far every spendEvery. The returned function stops
// it and waits, so no request is in flight when the caller sends the next one.
func (c *command) reportSpend(conn *bridge.Conn, project string) (stop func()) {
	ctx, cancel := context.WithCancel(c.ctx)
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		tick := time.NewTicker(spendEvery)
		defer tick.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-tick.C:
				if s := lastState(project); s != nil {
					if err := conn.Spend(s.Usage.CostUSD); err != nil {
						fmt.Fprintf(c.err, "bridge: %v\n", err)
					}
				}
			}
		}
	}()
	return func() { cancel(); wg.Wait() }
}

// lastState is the state of the project's newest run, or nil when there is none.
func lastState(project string) *run.State {
	entries, err := os.ReadDir(filepath.Join(project, ".factory", "runs"))
	if err != nil {
		return nil
	}
	var ids []string
	for _, e := range entries {
		if e.IsDir() && run.ValidID(e.Name()) {
			ids = append(ids, e.Name())
		}
	}
	if len(ids) == 0 {
		return nil
	}
	s, err := run.LoadState(run.Dir(project, slices.Max(ids)))
	if err != nil {
		return nil
	}
	return s
}

// exportProduct writes the committed files of the project and its leaves to dst, as the grader's /app is made.
func (c *command) exportProduct(project, dst string) error {
	s := lastState(project)
	if s == nil {
		return errors.New("the run left no record to export a product from")
	}
	r, err := run.Open(c.ctx, project, s.ID, "")
	if err != nil {
		return err
	}
	defer r.Close()
	return r.ExportApp(c.ctx, dst)
}

// newProject makes an empty project: a git repository whose umbrella.yaml sets root: true, as a person does.
func newProject(ctx context.Context, dir string) error {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	if _, err := git.Run(ctx, dir, "init", "-q", "-b", "main"); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(dir, schema.UmbrellaFile), []byte("root: true\nowner: ouroboric-dev\nvisibility: private\n"), 0o644); err != nil {
		return err
	}
	if _, err := git.Run(ctx, dir, "add", "--", schema.UmbrellaFile); err != nil {
		return err
	}
	_, err := git.Run(ctx, dir, "-c", "user.name=ygg", "-c", "user.email=ygg@example.invalid", "commit", "-q", "-m", "A Harbor task's project")
	return err
}
```

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index e8e482a..94e5008 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -8,6 +8,7 @@ import (
 	"fmt"
 	"io"
 	"maps"
+	"os"
 	"path/filepath"
 	"slices"
 	"strings"
@@ -42,6 +43,7 @@ const usage = `usage:
   ygg metrics --compare <run-id> <run-id> [--json] [--project <dir>]
   ygg report  <run-id> [--commit] [--project <dir>]
   ygg board   [--project <dir>] | --all [--projects <file>]
+  ygg bridge  --config <factory.yaml> --graph <name|dir> [--work <dir>] [--mode <mode>]   (started by the Harbor adapter)
   ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--host] [--project <dir>] [--config <factory.yaml>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
   ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -51,14 +53,19 @@ exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point,
 
 // Main runs one ygg command and returns its exit code.
 func Main(ctx context.Context, args []string, stdout, stderr io.Writer) int {
+	return MainWithInput(ctx, args, os.Stdin, stdout, stderr)
+}
+
+// MainWithInput is Main with the standard input given, for the one command that reads it: ygg bridge.
+func MainWithInput(ctx context.Context, args []string, stdin io.Reader, stdout, stderr io.Writer) int {
 	if len(args) == 0 {
 		fmt.Fprint(stderr, usage)
 		return ExitRefused
 	}
-	c := &command{ctx: ctx, out: stdout, err: stderr}
+	c := &command{ctx: ctx, in: stdin, out: stdout, err: stderr}
 	cmds := map[string]func([]string) int{
 		"run": c.run, "resume": c.resume, "approve": c.approve, "reject": c.reject,
-		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade, "deps": c.deps, "metrics": c.metrics, "report": c.report, "board": c.board,
+		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade, "deps": c.deps, "metrics": c.metrics, "report": c.report, "board": c.board, "bridge": c.bridge,
 	}
 	f, ok := cmds[args[0]]
 	if !ok {
@@ -70,6 +77,7 @@ func Main(ctx context.Context, args []string, stdout, stderr io.Writer) int {
 
 type command struct {
 	ctx      context.Context
+	in       io.Reader
 	out, err io.Writer
 }
 
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T285: `journal-check.sh` and the `factory-change` tag

Spec §10.5 asks for a journal entry for every significant challenge and design criterion 6 asks that "every factory change
made in response to a run cites before/after runs from `ygg metrics --compare`". Today only a person checks. This task
makes it a script: it passes on today's journal (33 entries) and fails on each rule it enforces. Branch
`phase-6/journal-check` from `main` in `ouroboric`, before step 1.

**Files (in `ouroboric`):**

- Create: `scripts/journal-check.sh`, `scripts/tests/journal-check.test.sh`
- Modify: `AGENTS.md`, `docs/6-journal/README.md`

**Interfaces:**

- Produces: `scripts/journal-check.sh [JOURNAL_DIR]` (default: `docs/6-journal` beside the script). It reads and prints and
  changes nothing. Exit 0, 1 when a rule fails (one line for each problem, then a count), 2 for bad usage.
- The rules, for every file named `YYYY-MM-DD-*.md`: front matter with `date` (the file name's), `tags`, `status` (`open`,
  `resolved` or `abandoned`), `post-candidate` (`yes` or `no`) and `evidence` (not empty once resolved); the sections
  Challenge, Context, Options, Decision, Result and Lessons, in that order; a Result that is not "pending" once resolved; one
  row in `README.md` with the same date, status and post candidate, and no row for a file that is not there; no raw ledger
  line. An entry tagged `factory-change` that is resolved or abandoned cites `ygg metrics --compare` and two different run ids
  in its Result.
- Changes: `AGENTS.md` lists the script; the journal's README says what the script checks and what the tag means.

**Acceptance criteria:**

- [ ] A good journal passes; the real journal passes.
- [ ] Each of these fails with a message that names the file and the rule: no front matter, a missing key, a status outside
      the three, a date that is not the file name's, a missing section, sections out of order, a resolved entry with no
      evidence, a resolved entry whose Result is pending, an entry missing from the index, an index row that disagrees, an index
      row for a file that is not there, a factory change with no `ygg metrics --compare`, one that names one run, a raw ledger
      line.
- [ ] An open `factory-change` entry may still be waiting for its comparison. A folder that is not there is exit 2.

**Named test:** `bash scripts/tests/journal-check.test.sh` in `ouroboric` (20 cases, exit 0). **Layer:** `ouroboric`.
**Size:** M (216). **Depends on:** none.

- [ ] **Step 1:** write the tests.

Write `scripts/tests/journal-check.test.sh` (executable):

```sh
#!/usr/bin/env bash
# Tests for journal-check.sh: a good journal passes, and each rule of the checker fails on a journal that breaks it.
#   scripts/tests/journal-check.test.sh      Exit 0 when every case behaves.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="$HERE/.."
T="$(mktemp -d)"
trap 'rm -rf -- "$T"' EXIT
fail=0
check() {
  local d="$1"; shift
  if "$@"; then echo "ok   $d"; else echo "FAIL $d"; fail=1; [ -z "${VERBOSE:-}" ] || sed 's/^/     | /' "$T/out"; fi
}
run() { "$@" >"$T/out" 2>&1; rc=$?; }
# shellcheck disable=SC2329  # has runs through check
has() { grep -q -F -- "$1" "$T/out"; }

RUN_A=20261023-090000-a1b2c3
RUN_B=20261024-090000-d4e5f6

# entry FILE STATUS POST TAGS EVIDENCE RESULT: writes one entry with every section.
entry() {
  local file="$1" status="$2" post="$3" tags="$4" evidence="$5" result="$6"
  local date="${file:0:10}"
  cat > "$J/$file" <<EOT
---
date: $date
tags: [$tags]
status: $status
post-candidate: $post
evidence: [$evidence]
---
## Challenge
What went wrong.
## Context
What we knew.
## Options
What we considered.
## Decision
What we chose.
## Result
$result
## Lessons
What we would tell someone.
EOT
}
index() { # index LINE...: writes README.md with the table header and the given rows
  { echo "# Journal"; echo; echo "| Date | Entry | Tags | Status | Post candidate |"; echo "| --- | --- | --- | --- | --- |"; printf '%s\n' "$@"; } > "$J/README.md"
}
fresh() { J="$T/journal-$1"; mkdir -p "$J"; }

fresh good
entry 2026-10-23-first.md resolved yes "harness, cost" '"run 20261023-090000-a1b2c3"' "Measured: it took 3 attempts, then 2."
entry 2026-10-24-open.md open no "loop" "" "pending"
entry 2026-10-25-change.md resolved yes "harness, factory-change" '"run 20261023-090000-a1b2c3", "run 20261024-090000-d4e5f6"' "ygg metrics --compare $RUN_A $RUN_B: first pass 50% to 75%, reward held."
index "| 2026-10-23 | [first](2026-10-23-first.md) | harness, cost | resolved | yes |" \
      "| 2026-10-24 | [open](2026-10-24-open.md) | loop | open | no |" \
      "| 2026-10-25 | [change](2026-10-25-change.md) | harness, factory-change | resolved | yes |"
run "$S/journal-check.sh" "$J"
check "a good journal passes" test "$rc" -eq 0
check "and says how many entries it read" has "3 entries"

# shellcheck disable=SC2329  # runs through check
failed_with() { [ "$rc" = 1 ] && has "$1"; }
bad() { # bad NAME EXPECT: run the checker on the current $J and expect exit 1 and a message with EXPECT
  run "$S/journal-check.sh" "$J"
  check "$1" failed_with "$2"
}

fresh nofm;   entry 2026-10-23-a.md open no "x" "" "pending"; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | open | no |"; sed -i '1d' "$J/2026-10-23-a.md"
bad "an entry with no front matter fails" "2026-10-23-a.md: front matter"
fresh nokey;  entry 2026-10-23-a.md open no "x" "" "pending"; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | open | no |"; sed -i '/^post-candidate:/d' "$J/2026-10-23-a.md"
bad "a missing key fails" "2026-10-23-a.md: front matter lacks post-candidate"
fresh badstat; entry 2026-10-23-a.md "done" no "x" "" "pending"; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | done | no |"
bad "a status that is not open, resolved or abandoned fails" "status 'done'"
fresh baddate; entry 2026-10-23-a.md open no "x" "" "pending"; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | open | no |"; sed -i 's/^date: .*/date: 2026-10-22/' "$J/2026-10-23-a.md"
bad "a date that is not the file name's fails" "date 2026-10-22 is not the file name's"
fresh nosec;  entry 2026-10-23-a.md open no "x" "" "pending"; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | open | no |"; sed -i '/^## Options$/,+1d' "$J/2026-10-23-a.md"
bad "a missing section fails" "section Options"
fresh order;  entry 2026-10-23-a.md open no "x" "" "pending"; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | open | no |"; sed -i 's/^## Context$/## ContextX/;s/^## Options$/## Context/;s/^## ContextX$/## Options/' "$J/2026-10-23-a.md"
bad "sections out of order fail" "sections are not in the order"
fresh noevid; entry 2026-10-23-a.md resolved no "x" "" "Measured: fine."; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | resolved | no |"
bad "a resolved entry with no evidence fails" "resolved but evidence is empty"
fresh pend;   entry 2026-10-23-a.md resolved no "x" '"run 20261023-090000-a1b2c3"' "pending"; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | resolved | no |"
bad "a resolved entry whose result is pending fails" "resolved but its Result is pending"
fresh noidx;  entry 2026-10-23-a.md open no "x" "" "pending"; index
bad "an entry missing from the index fails" "2026-10-23-a.md: not in README.md"
fresh difidx; entry 2026-10-23-a.md open no "x" "" "pending"; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | resolved | yes |"
bad "an index row that disagrees with the entry fails" "README.md says resolved/yes"
fresh ghost;  entry 2026-10-23-a.md open no "x" "" "pending"; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | open | no |" "| 2026-10-24 | [gone](2026-10-24-gone.md) | x | open | no |"
bad "an index row for a file that is not there fails" "README.md: lists 2026-10-24-gone.md"
fresh nocomp; entry 2026-10-23-a.md resolved yes "harness, factory-change" '"run 20261023-090000-a1b2c3"' "It got better."; index "| 2026-10-23 | [a](2026-10-23-a.md) | harness, factory-change | resolved | yes |"
bad "a factory change with no ygg metrics --compare fails" "factory-change but its Result does not cite ygg metrics --compare"
fresh onerun; entry 2026-10-23-a.md resolved yes "factory-change" '"run 20261023-090000-a1b2c3"' "ygg metrics --compare $RUN_A: better."; index "| 2026-10-23 | [a](2026-10-23-a.md) | factory-change | resolved | yes |"
bad "a comparison that names one run fails" "two different run ids"
fresh ledger; entry 2026-10-23-a.md open no "x" "" '{"schema":"ygg.ledger/v1","seq":1,"event":"run_started"}'; index "| 2026-10-23 | [a](2026-10-23-a.md) | x | open | no |"
bad "a raw ledger line in an entry fails" "a raw ledger line"

fresh ok2; entry 2026-10-23-a.md open no "factory-change" "" "pending"; index "| 2026-10-23 | [a](2026-10-23-a.md) | factory-change | open | no |"
run "$S/journal-check.sh" "$J"
check "an open factory-change entry may still be waiting for its comparison" test "$rc" -eq 0
run "$S/journal-check.sh" "$T/no-such-folder"
check "a folder that is not there is a usage error" test "$rc" -eq 2
check "and the message says there is no journal" has "no journal"
run "$S/journal-check.sh" "$S/../docs/6-journal"
check "the real journal passes" test "$rc" -eq 0

exit "$fail"
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
FAIL a good journal passes
FAIL and says how many entries it read
FAIL an entry with no front matter fails
FAIL a missing key fails
```

- [ ] **Step 3:** write the code.

Apply to `AGENTS.md`:

```diff
diff --git a/AGENTS.md b/AGENTS.md
index 372f3a2..ed58b0d 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -48,6 +48,7 @@ folder.
 | Write the licence files or the base CI into a folder | `scripts/add-licences.sh`, `scripts/add-ci.sh`. Founder only |
 | Push the prepared `base-ci` branches of existing repos and open their PRs, then require `lint` after the merge | `scripts/rollout-ci.sh --org <org> push\|protect <repo>...`. Founder only |
 | Prove that a Markdown change is formatting only, such as `markdownlint-cli2 --fix` output | `scripts/md-same-text.sh <base-ref> <head-ref>` |
+| Check the journal against spec §10.5 and design criterion 6: front matter, sections, the index, evidence once resolved, a `factory-change` entry citing `ygg metrics --compare` | `scripts/journal-check.sh [DIR]` |
 | Scaffold a new Go component | `scripts/scaffold-component.sh` |
 | Render and check diagrams | `scripts/diagrams.sh` |
 
```

Apply to `docs/6-journal/README.md`:

```diff
diff --git a/docs/6-journal/README.md b/docs/6-journal/README.md
index 6f96e2e..cfc22ed 100644
--- a/docs/6-journal/README.md
+++ b/docs/6-journal/README.md
@@ -5,6 +5,14 @@ considered, what we chose, and the measured result. In the naming story these en
 **sagas**; a future content component (**Bragi**) will turn them into blog posts. Spec:
 [§13.5](https://github.com/ouroboric-dev/yggdrasil/blob/main/docs/2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md#105-journey-journal).
 
+## Checking
+
+`scripts/journal-check.sh` reads this folder and fails when an entry breaks the rules above: a missing key, a status that
+is not `open`, `resolved` or `abandoned`, sections out of order, a resolved entry with no evidence or a Result that is still
+"pending", an entry that the index below does not list or lists differently, or a raw ledger line. An entry that records a
+change to the factory carries the tag `factory-change`; once it is resolved, its Result cites the before and after with
+`ygg metrics --compare <runA> <runB>` and names both run ids (design doc §2.3, criterion 6).
+
 ## Entries
 
 | Date | Entry | Tags | Status | Post candidate |
```

Write `scripts/journal-check.sh` (executable):

```sh
#!/usr/bin/env bash
# Check the journey journal against spec §10.5 and design success criterion 6.
#   journal-check.sh [JOURNAL_DIR]      default: docs/6-journal beside this script's repo
# Every entry (a file named YYYY-MM-DD-*.md) must have:
#   - front matter with date (the file name's), tags, status (open, resolved or abandoned), post-candidate (yes or
#     no) and evidence (a list; not empty once the entry is resolved);
#   - the sections Challenge, Context, Options, Decision, Result and Lessons, in that order;
#   - a Result that is not "pending" once the entry is resolved;
#   - one row in README.md with the same date, status and post candidate, and no row for a file that is not there;
#   - no raw ledger line (a private run's ledger is quoted by aggregate numbers only).
# An entry tagged factory-change that is resolved or abandoned must cite its before and after in its Result: the
# words `ygg metrics --compare` and two different run ids (criterion 6: a factory change cites `--compare`).
# It reads and prints; it changes nothing. Exit 0 when the journal passes, 1 when a rule fails, 2 on bad usage.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="${1:-$HERE/../docs/6-journal}"
[ $# -le 1 ] || { echo "usage: journal-check.sh [JOURNAL_DIR]" >&2; exit 2; }
[ -d "$dir" ] || { echo "journal-check: no journal at $dir" >&2; exit 2; }
exec python3 -I - "$dir" <<'PY'
import os, re, sys

jdir = sys.argv[1]
SECTIONS = ["Challenge", "Context", "Options", "Decision", "Result", "Lessons"]
STATUS = {"open", "resolved", "abandoned"}
RUN = re.compile(r"\b\d{8}-\d{6}-[0-9a-f]{6}\b")
problems = []


def bad(file, msg):
    problems.append(f"{file}: {msg}")


entries = sorted(f for f in os.listdir(jdir) if re.match(r"\d{4}-\d\d-\d\d-.*\.md$", f))
facts = {}
for f in entries:
    text = open(os.path.join(jdir, f), encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        bad(f, "front matter is missing")
        continue
    fm = dict(re.findall(r"^([\w-]+):[ \t]*(.*)$", m.group(1), re.M))
    for key in ("date", "tags", "status", "post-candidate", "evidence"):
        if key not in fm:
            bad(f, f"front matter lacks {key}")
    status, post = fm.get("status", ""), fm.get("post-candidate", "")
    if "status" in fm and status not in STATUS:
        bad(f, f"status '{status}' is not open, resolved or abandoned")
    if "post-candidate" in fm and post not in ("yes", "no"):
        bad(f, f"post-candidate '{post}' is not yes or no")
    if "date" in fm and fm["date"] != f[:10]:
        bad(f, f"date {fm['date']} is not the file name's")
    body = text[m.end():]
    heads = re.findall(r"^## (\w+)\s*$", body, re.M)
    for s in SECTIONS:
        if s not in heads:
            bad(f, f"section {s} is missing")
    present = [h for h in heads if h in SECTIONS]
    if all(s in heads for s in SECTIONS) and present != SECTIONS:
        bad(f, "the sections are not in the order " + ", ".join(SECTIONS))
    result = ""
    rm = re.search(r"^## Result\s*$(.*?)(?=^## |\Z)", body, re.S | re.M)
    if rm:
        result = rm.group(1).strip()
    evidence = fm.get("evidence", "").strip()
    if status == "resolved" and evidence in ("", "[]"):
        bad(f, "resolved but evidence is empty")
    if status == "resolved" and result.lower().rstrip(".") == "pending":
        bad(f, "resolved but its Result is pending")
    tags = [t.strip() for t in fm.get("tags", "").strip("[]").split(",")]
    if "factory-change" in tags and status in ("resolved", "abandoned"):
        if "ygg metrics --compare" not in result:
            bad(f, "tagged factory-change but its Result does not cite ygg metrics --compare")
        elif len(set(RUN.findall(result))) < 2:
            bad(f, "its ygg metrics --compare citation does not name two different run ids")
    if re.search(r'^\{"schema":"ygg\.ledger/', body, re.M):
        bad(f, "holds a raw ledger line; quote aggregate numbers and link the run by id")
    facts[f] = (fm.get("date", ""), status, post)

index = os.path.join(jdir, "README.md")
rows = {}
if os.path.isfile(index):
    for d, link, status, post in re.findall(r"^\| (\d{4}-\d\d-\d\d) \| \[[^\]]*\]\(([^)]+)\) \| [^|]*\| (\w+) \| (\w+) \|", open(index, encoding="utf-8").read(), re.M):
        rows[link] = (d, status, post)
    for f in entries:
        if f not in rows:
            bad(f, "not in README.md")
        elif f in facts and facts[f][1:] != rows[f][1:]:
            bad(f, f"README.md says {rows[f][1]}/{rows[f][2]}, the entry says {facts[f][1]}/{facts[f][2]}")
    for link in rows:
        if link not in entries:
            bad("README.md", f"lists {link}, which is not there")
else:
    bad("README.md", "is missing")

for p in problems:
    print(p)
print(f"journal-check: {len(entries)} entries, {len(problems)} problem(s)")
sys.exit(1 if problems else 0)
PY
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

### Task v0-T290: the proof-run script: setup and the dry run

The proof runs are long and cost money, and each must be set up the same way, or `--compare` compares two setups and not two
factories. `scripts/ygg-proof-run.sh` makes the project, the config and the checks, and stops there with `--dry-run`. It is
written like `ygg-smoke-real.sh` (the real-agent smoke of v0-H17) and takes its idioms, but it is its own script: it runs the
`software` graph on the real `client-gallery-lite` with the realms, three roles that the operator names, and caps that the
operator sets. **This task and v0-T291 were not built in the scratch workspace**; their tests below are written first by the
executor, and "Evidence" says so. Branch `phase-6/proof-run` from `main` in `ouroboric` (the same branch as v0-T285).

**Files (in `ouroboric`):**

- Create: `scripts/ygg-proof-run.sh`, `scripts/tests/ygg-proof-run.test.sh`, `scripts/testdata/proof/factory.proof.example.yaml`
- Modify: `AGENTS.md` (the script's row in the table of scripts)

**Interfaces:**

- Produces: `scripts/ygg-proof-run.sh --name NAME [--mode key-points|unattended|step-by-step] [--planner AGENT:MODEL]
  [--implementer AGENT:MODEL] [--reviewer AGENT:MODEL] [--run-turns N] [--run-tokens N] [--run-usd N] [--day-turns N]
  [--day-tokens N] [--day-usd N] [--baseline RUN_ID] [--dry-run] [--build] [--folder DIR] [--env FILE] [--tasks DIR]
  [--suites DIR] [--yggdrasil DIR] [--wall TIME] [--clip]`.
  Defaults: `--mode key-points`; planner `claude-code:sonnet`; implementer `claude-code:sonnet`; reviewer
  `opencode:openrouter/qwen/qwen3.8-27b`; the caps of question 3 (a run: 1,500 turns, 12,000,000 tokens, $5; a day: 2,000
  turns, 24,000,000 tokens, $10); `--wall 8h` (the task's `agent.timeout_sec`); `--folder $HOME/ygg-it`; `--env
  $HOME/.config/ouroboric/factory.env`; `--tasks ../mimir`; `--suites $HOME/ygg-it/hidden-suites`; `--yggdrasil` the umbrella.
  An `AGENT:MODEL` has `claude-code` or `opencode`, and an `opencode` model is `openrouter/<model>`; its characters are
  `A-Za-z0-9._/:-`, because it goes into a YAML line.
- Produces: `scripts/testdata/proof/factory.proof.example.yaml`, the config with its places between two at signs:

```yaml
# The factory.yaml of a proof run (v0-H19 to v0-H23), with the places between two at signs that
# scripts/ygg-proof-run.sh fills from its flags. It never writes your factory.yaml. The credentials come from the
# environment, never from this file. A "usd" line is written only when a role pays per token (an opencode role):
# the caps then count what the API billed, not the cost figure of a subscription's sessions.
mode: @MODE@
privacy: strict
roles:
  planner: { agent: @PLANNER_AGENT@, model: @PLANNER_MODEL@ }
  implementer: { agent: @IMPLEMENTER_AGENT@, model: @IMPLEMENTER_MODEL@ }
  reviewer: { agent: @REVIEWER_AGENT@, model: @REVIEWER_MODEL@ }
budget:
  per_run: { tokens: @RUN_TOKENS@, turns: @RUN_TURNS@@RUN_USD@ }
  per_day: { tokens: @DAY_TOKENS@, turns: @DAY_TURNS@@DAY_USD@ }
sandbox:
  engine: @ENGINE@
  mounts:
    - { host: @FOLDER@, engine: @BIND@ }
realms:
  dir: @REALMS@
graphs:
  dir: @GRAPHS@
grader:
  tasks_dir: @TASKS@
  suite_dir: @SUITES@
  timeout: 30m
  memory: none
  cpus: 0
```

- The setup, in order: check the flags; the engine (`ygg-engine.sh`, skipped when `YGG_ENGINE_CHECK=0`); the tools (`git`, `python3`,
  `timeout`, `sha256sum`); the task (its `task.toml` and `instruction.md`, and that the SHA-256 of `instruction.md` is the
  `brief_sha256` of `task.toml`: a changed brief is another task, and a proof run uses the frozen one); the suites folder
  (`test -d $SUITES/<task>/<suite>` and nothing more, and neither folder inside the other, nor inside the project); the
  credentials by name (`grep -c`, one line each, with a value) for the adapters the roles name only; then a project
  `DIR/proof-<name>-<time>/project` (a git repository whose `umbrella.yaml` sets `root: true`), its `factory.yaml` filled from
  the example, `ygg doctor` on that config, and a printed plan of what would run. `--dry-run` stops after the plan and exits 0.

**Acceptance criteria:**

- [ ] Each of these exits 2 with a message that says why, before a project is made: no `--name`, a name with characters outside
      `a-z0-9-`, a bad mode, a bad role, a cap that is not a number, a missing task folder, a brief whose hash is not the
      task's `brief_sha256` (the message says it is not the frozen brief), a suites folder that is missing for the task and
      its suite, a suites folder inside the tasks folder, and a credentials file that lacks a name that a role needs. An
      all-Claude config does not ask for the OpenRouter key and an all-OpenCode config does not ask for the Claude token (B-130).
- [ ] The filled `factory.yaml` holds the roles and caps asked for, the grader block with the two folders, and no `usd` line when
      no role is paid; no value of the credentials file is in it, in the plan or in any output.
- [ ] `--dry-run` runs `ygg doctor` and never `ygg run`, and says that nothing was started and the credentials were not loaded.
- [ ] The suites folder is never listed or read: a test puts shims for `ls`, `find`, `cat`, `head`, `tail`, `grep`, `sed`, `awk`,
      `du` and `stat` first on the path, and none of them is called with the suites folder as an argument.
- [ ] `shellcheck -s bash` is clean on the script and its test.

**Named test:** `bash scripts/tests/ygg-proof-run.test.sh` in `ouroboric`, the cases named above, with a fake `ygg` and a fake
`devcontainer` standing in for the real tools (no engine, no model, no network). **Layer:** `ouroboric`. **Size:** M.
**Depends on:** none.

- [ ] **Step 1:** write `scripts/tests/ygg-proof-run.test.sh` in the style of `scripts/tests/ygg-smoke-real.test.sh` (a `check`
      helper, a fake `ygg` that records its arguments, one case for each criterion). Run it. Expect the cases to fail because
      the script is missing.
- [ ] **Step 2:** write `scripts/ygg-proof-run.sh` and `scripts/testdata/proof/factory.proof.example.yaml`. Run the test. Expect
      every case `ok`, then `shellcheck -s bash` on both files.
- [ ] **Step 3:** add the script to the table in `AGENTS.md`. Commit (see "How each task lands").

### Task v0-T291: the proof-run script: the run, the grade and the evidence

The second half of the script of v0-T290. Without `--dry-run` it starts the run with the credentials loaded in a subshell only,
and when the run ends it grades it, reads it, and prints what the founder pastes into the journal. Same branch.

**Files (in `ouroboric`):**

- Modify: `scripts/ygg-proof-run.sh`, `scripts/tests/ygg-proof-run.test.sh`

**Interfaces:**

- The run: `ygg run --project P --config C --graph software --brief <tasks>/<task>/instruction.md --mode M`, under `timeout
  --wall`, its output kept in `DIR/proof-<name>-<time>/run.txt` and shown as it comes. It prints the run's exit code (0 done, 1 a
  node failed, 3 stopped, 4 paused, 5 done with tasks given up, 124 the wall clock) and, for 3, the `ygg approve` command for the
  gate it stopped at, written to run under `ygg-engine.sh`.
- With `--build`, `ygg sandbox build --all --config C` runs before the run, as `ygg-smoke-realms.sh --build` does.
- After a run that ended 0 or 5: `ygg grade <run>`; then, for any ending, `ygg metrics <run>`, `ygg report <run>`,
  `scripts/ygg-cost.sh` on the ledger, and the evidence report of `scripts/ygg-evidence.sh` with the credentials' exact values
  removed, all kept in `DIR/proof-<name>-<time>/report.txt`. With `--baseline RUN_ID`, also `ygg metrics --compare RUN_ID <run>`.
  With `--clip` the report goes to the clipboard.
- A run that stopped (3) or paused (4) is not graded; the script says how to continue (`ygg approve`, `ygg resume`).

**Acceptance criteria:**

- [ ] The fake `ygg` is called in this order for a run that ended 0: `doctor`, `run`, `grade`, `metrics`, `report`; for 5 the same;
      for 3, 4 and 124 there is no `grade`, but `metrics` and `report` still run (a stopped run has figures).
- [ ] `run` receives the task's `instruction.md` as the brief, `--graph software`, `--mode` and the filled config; no credential
      value is in its arguments; the credentials are in its environment and not in the script's.
- [ ] With `--baseline`, `metrics --compare <baseline> <run>` follows. For a stopped run the output ends with the `approve` command.
- [ ] A fake credential value planted in the fake `ygg`'s output is not in the printed report or in `report.txt`.
- [ ] The exit code of the script is the run's. The suites folder is still never called as an argument of a reader.

**Named test:** `bash scripts/tests/ygg-proof-run.test.sh` in `ouroboric`. **Layer:** `ouroboric`. **Size:** M.
**Depends on:** v0-T290, v0-T278, v0-T280, v0-T281.

- [ ] **Step 1:** add the cases to the test. Run it. Expect the new cases to fail.
- [ ] **Step 2:** write the run and the evidence in the script. Run the test and `shellcheck -s bash`. Expect `ok` on every case.
- [ ] **Step 3:** run the script with `--dry-run` against the real `mimir` and a real `ygg`, with a throwaway `--folder`, and put
      the output in the PR. It spends nothing. Commit.

### Task v0-T292: the runbook of the proof runs

The founder runs the proof runs, and a runbook gives the order, the commands, what to look at and what to write down. It lives
with the operating docs, so that the next operator finds it. Branch `phase-6/runbook` from `main` in `yggdrasil`.

**Files (in `yggdrasil`):**

- Create: `docs/3-using/operations/proof-runs.md`
- Modify: `docs/3-using/operations/README.md` (a link and one line)

**Interfaces:**

- The runbook holds: the table of runs (the rehearsal, run 1, its repeat, the cross-model run, the improvement run) with what
  differs in each and the command of v0-T291 for it; how to read `ygg metrics`, `ygg metrics --compare` and `ygg report` (the
  definitions of decision 3, in a sentence each; `ygg metrics` of a run that is still writing may refuse because its last line is half written, so read it when the run has stopped and use `ygg status --watch` meanwhile); what to watch during a long run (`ygg status <run> --watch`, `ygg board`, and
  `scripts/ygg-events-watch.sh` in a second terminal for B-051); what stops a run (the caps; the gates; the wall clock) and how to
  continue; the template of a journal entry for a run, with the rule that the public journal quotes aggregate numbers and links
  the run by id only; the rule that a run is repeated only with the same brief, graph, mode and suite, and how to tell when it was
  not (`not comparable`).

**Acceptance criteria:**

- [ ] The runbook names every flag of `ygg-proof-run.sh` that a run in the table uses, and every command of this phase.
- [ ] Every link resolves; the folder's README links the page.
- [ ] `pre-commit run --files docs/3-using/operations/proof-runs.md docs/3-using/operations/README.md` passes (markdownlint, the
      licence check, `gitleaks`).

**Named test:** `pre-commit run --files docs/3-using/operations/proof-runs.md docs/3-using/operations/README.md` in `yggdrasil`.
**Layer:** `yggdrasil`. **Size:** S. **Depends on:** v0-T291.

- [ ] **Step 1:** write the page and the README line. Run the named test. Expect every hook `Passed`.
- [ ] **Step 2:** read each command of the page against `scripts/ygg-proof-run.sh --help` and `ygg` usage text. Commit.

### Task v0-T293: the runtime of the gallery brief: a change proposal (conditional)

**Do not start this task until the founder has run v0-H19 and answered question 10 on the pull request or in the session that
writes it.** The frozen brief asks for one self-contained machine, and the realms build a product that needs Postgres, an
S3-compatible store and two servers. The planning rehearsal shows what the planner designs for the brief. This task writes
the change proposal that makes the chosen option real, in the form of `docs/2-engineering/changes/README.md`: `proposal.md`
(why, with the evidence of v0-H19's report and the files named in question 10), `delta.md` (the spec's requirements added or
changed) and `tasks.md`, whose tasks each meet the Definition of Ready. It is the start of part two (decision 1). Branch
`phase-6/gallery-runtime` from `main` in `yggdrasil`.

**Files (in `yggdrasil`):**

- Create: `docs/2-engineering/changes/2026-10-<date>-gallery-runtime/proposal.md`, `delta.md`, `tasks.md`

**Acceptance criteria:**

- [ ] The proposal names the option the founder chose, why, and what v0-H19 showed (quoted as aggregate facts, not as
      transcripts), and says what B-117, B-118 and B-078 become.
- [ ] The delta lists the requirements it adds or changes in spec §9 and §11, and in the realms' readiness items.
- [ ] Each task has acceptance criteria, a named test, a layer, a size under 400 and its dependencies.
- [ ] The tasks include whatever changes `mimir`'s `client-gallery-lite` (a new task version, same brief and hash) if the founder
      chose the option that bakes services in; the hidden suite is never part of a task.

**Named test:** a reviewer applies the Definition of Ready to each task; `pre-commit run --files` the three files passes.
**Layer:** `yggdrasil`. **Size:** S. **Depends on:** v0-H19 and the founder's answer to question 10.

- [ ] **Step 1:** read v0-H19's report and `docs/2-engineering/plans/*/` from the rehearsal's project. Write the three files.
- [ ] **Step 2:** run the named test, commit, push and open the pull request (see "How each task lands").

### Task v0-T294: pointers, backlog and the exit check

The umbrella moves the pointers once, and the exit check runs on the merged code.

**Files (in `yggdrasil`):**

- Modify: the submodule pointers of `gungnir` and `odin`; `docs/2-engineering/backlog.md`.

**Acceptance criteria:**

- [ ] After all pull requests are merged, the pointers are at each repo's `main`, and `go.work` builds them together: `go vet ./...`
      and `go test ./...` pass in `gungnir` and `odin`, with `go.work` and with `GOWORK=off`.
- [ ] The exit criterion for the scripted half of criterion 4: `go test -run 'TestToyGraphEndToEnd|TestBridgeRunsTheFactoryOnTheBriefAndUploadsTheCommittedProductThenSaysDone' ./internal/cli`
      in `odin` passes on the merged code; and `bash scripts/journal-check.sh` in `ouroboric` exits 0.
- [ ] The backlog gets these items, each with the problem and the fix in a line: **B-140** (**Open**) the brief's runtime and the realms'
      do not fit (question 10; the evidence is named there); **B-141** (**Done**, v0-T288 and v0-T289) the dollar caps counted a subscription's
      estimate, with the note that a journal from before the change undercounts its earlier lines; **B-142** (**Open**) the factory writes no
      `routing_lookup`, so the routing metric reads 0 lookups (spec §8.1's summary in a session is not built); **B-143** (**Open**) the metrics
      find a loop's reviewer sessions by the node-id convention `<loop>-<reviewer>`, so a graph pack needs a test that pins the convention.
- [ ] The backlog marks the items this phase closed: B-114 (v0-T270, v0-T272), B-115 (v0-T281), and the Phase 6 half of B-116 (decision 13).
      B-116, B-117 and B-118 keep their second halves and point at question 10.

**Named test:** `go test ./...` in `gungnir` and `odin`, with `go.work` and with `GOWORK=off`. **Layer:** `yggdrasil`. **Size:** S.
**Depends on:** all above, merged.

- [ ] **Step 1:** switch each local copy to `main` and pull. Then, in `yggdrasil`:

```bash
git switch -c phase-6/pointers
git submodule update --remote gungnir odin
git status --short
```

- [ ] **Step 2:** in `docs/2-engineering/backlog.md`, add the items above and mark the closed ones.
- [ ] **Step 3:** run the exit check: `go vet ./... && go test ./...` in `gungnir` and `odin`, with `go.work` and with `GOWORK=off`,
      and paste the output into the PR body.
- [ ] **Step 4:** stage the pointers and the backlog by path, commit, push and open the pull request (see "How each task lands").

---

### Task v0-H18 (founder): get ready

Nothing here costs money. Do it after the pull requests of Phase 6 are merged.

**Named test:** `ygg metrics` and `ygg board` print their usage text without error, `ygg doctor` passes, and `scripts/ygg-engine.sh check`
passes. **Layer:** the founder's machine. **Size:** S. **Depends on:** the Phase 6 pull requests merged.

- [ ] **Step 1:** switch `yggdrasil`, its submodules, `mimir` and `ouroboric` to `main` and pull. If the machine restarted since the
      last run, do the three things that a restart undoes, in a normal terminal tab (`sudo` needs one):

```zsh
sudo mkdir -p /mnt/wsl/ygg-bind && sudo mount --bind /home/brunogbv/ygg-it /mnt/wsl/ygg-bind
sudo mkdir -p /run/user/1000 && sudo chown 1000:1000 /run/user/1000 && sudo chmod 700 /run/user/1000
```

- [ ] **Step 2:** build `ygg` from the merged code (into any folder on your `PATH`) and check the engine.

```zsh
cd ~/brunogbv/ouroboric/yggdrasil/odin && go build -o ~/.local/bin/ygg ./cmd/ygg
ygg metrics 2>&1 | head -3            # usage text, exit 2
cd ~/brunogbv/ouroboric/ouroboric && scripts/ygg-engine.sh check
```

- [ ] **Step 3:** check what the runs need and nothing more. The suites folder is the one you keep; do not open it. In the OpenRouter
      dashboard, check that the key's limit is $25 a month and see what is left of it. Read question 3 and decide the caps; the
      script's defaults are the assumed ones.

```zsh
test -d ~/ygg-it/hidden-suites/client-gallery-lite/v2 && echo "the v2 suite folder is there"
grep -c -E '^(export[[:space:]]+)?(CLAUDE_CODE_OAUTH_TOKEN|OPENROUTER_API_KEY)=' ~/.config/ouroboric/factory.env   # 2
```

- [ ] **Step 4:** the dry run. It spends nothing and loads no credential. Expect `dry run: nothing was started`, the roles and caps, the
      grader's two folders and exit 0. Send the plan it printed.

```zsh
scripts/ygg-proof-run.sh --name rehearsal --mode step-by-step --dry-run
```

### Task v0-H19 (founder): the planning rehearsal

The first real-agent run of the `software` graph. It plans the gallery and stops at the plan gate, before any code is written, so
it costs the planner's sessions and the conformance and reuse reviewers: cents to a dollar, **an estimate, not measured**. It
answers question 10 and shows how big the real plan is, which sets the caps of question 3.

**Named test:** the run stops at `plan-gate` (exit 3) with a plan of tasks that meet the Definition of Ready, and you can say
how the design starts the product (question 10). **Layer:** the founder's machine. **Size:** S. **Depends on:** v0-H18, v0-T291.

- [ ] **Step 1:** start it. `step-by-step` stops at every gate.

```zsh
cd ~/brunogbv/ouroboric/ouroboric
scripts/ygg-proof-run.sh --name rehearsal --mode step-by-step --build
```

- [ ] **Step 2:** at each stop, read the gate file (`<project>/.factory/runs/<run>/gates/<gate>-1.md`) and approve the design and
      the spec gates with the command the script prints. **Do not approve `plan-gate`.** Read the design, the spec, the plan
      (`docs/2-engineering/plans/*/tasks.md` in the project) and `docs/leaves.yaml`.
- [ ] **Step 3:** answer these from what you read. (a) Which leaves and realms does the plan use? (b) How does the design make
      `/app/start.sh` start the whole product on port 3000, with no outside service? (c) Where does it keep data and photos?
      (d) How many tasks, and which sizes? (e) Did the conformance reviewer or the reuse reviewer find anything?
- [ ] **Step 4:** read the run, and send the five answers, both outputs and the design documents (the brief is public; no hidden
      suite is involved). Question 10 is decided from them, and v0-T293 starts.

```zsh
ygg metrics <run> --project <project>
ygg report <run> --project <project>
```

### Task v0-H20 (founder): run 1, the baseline

The first scored run: the frozen brief, the `software` graph, `key-points`, Claude Code for the planner and the implementer,
Qwen3.8 27B on OpenRouter for the reviewers. **It costs money**: the OpenRouter part, and the subscription's quota, which your
own sessions share. Do this only after question 10 is answered and what it requires is built and merged.

**Named test:** the run ends `done` (exit 0) or `done` with tasks given up (exit 5), the score is printed, and the billed cost is
under the cap. **Layer:** the founder's machine. **Size:** M. **Depends on:** v0-H19, question 10 answered.

- [ ] **Step 1:** in a second terminal, watch the engine for B-051 (the first `devcontainer up` hangs about half the time, and
      Gleipnir's retry limits the damage; do not change the retry).

```zsh
cd ~/brunogbv/ouroboric/ouroboric && scripts/ygg-events-watch.sh
```

- [ ] **Step 2:** the dry run, then the run. It stops at the design gate; read the gate file and approve with the command the script
      prints. A contract change stops the run at a `pointer-contract` gate in `key-points` mode: read it and approve or reject
      with a note (a note makes it an intervention, which is the point).

```zsh
scripts/ygg-proof-run.sh --name r1 --dry-run
scripts/ygg-proof-run.sh --name r1 --build --clip
ygg status <run> --watch --project <project>        # in a third terminal
```

- [ ] **Step 3:** if the run stops at a cap (exit 3 at `budget-cap`), read how far it got and what it cost with `ygg metrics`, decide, and
      continue with `ygg approve` only if you raise the cap in the config first. Write the size of the run in the journal: it
      sets the caps for the others.
- [ ] **Step 4:** when it ends, the script has graded it and printed the evidence. Send the report. Write the journal entry (the
      template is in the runbook): aggregate numbers only, the run id as evidence, `status: open`. Run
      `scripts/journal-check.sh`.
- [ ] **Step 5:** add the project to the list that `ygg board --all` reads, and look at the board:

```zsh
mkdir -p ~/.config/ouroboric
printf 'projects:\n  - %s\n' "<project path>" >> ~/.config/ouroboric/projects.yaml
ygg board --all
```

### Task v0-H21 (founder): run 1 again, for the spread

The same setup, again. Hosted models change from hour to hour (the journal of 2026-10-20 saw 5 of 6 become 0 of 8), so one run is thin
and the second run says how thin. Everything is as in v0-H20; the script's `--baseline` prints the comparison.

**Named test:** the run ends as in v0-H20, and `ygg metrics --compare` says `comparable: yes`. **Layer:** the founder's machine.
**Size:** M. **Depends on:** v0-H20.

- [ ] **Step 1:** run it, with the first run as the baseline, and send the report.

```zsh
scripts/ygg-proof-run.sh --name r1b --baseline <run 1 id> --clip
```

- [ ] **Step 2:** write in the journal what the two runs differ by (the spread): first pass, cost per task, interventions, reward.
      Any change that a later run claims must be bigger than this spread to mean anything.

### Task v0-H22 (founder): the cross-model run

Criterion 2: the same brief with another agent tool or model for at least one role. As question 1 assumes: the implementer on
OpenCode with Qwen3.8 27B. **It costs money** (the implementer's tokens now bill through OpenRouter); the config's `per_run.usd` is the
guard, and the OpenRouter key's $25 a month is the backstop.

**Named test:** the run ends as in v0-H20 and `ygg metrics --compare` of run 1 and this run names one difference in the roles.
**Layer:** the founder's machine. **Size:** M. **Depends on:** v0-H20.

- [ ] **Step 1:** run it.

```zsh
scripts/ygg-proof-run.sh --name r2 --implementer opencode:openrouter/qwen/qwen3.8-27b --baseline <run 1 id> --clip
```

- [ ] **Step 2:** send the report. In the journal, write what the roles table shows (which model did what, at what cost), and what
      the reward and the escaped defects say. A lower score is a result, not a failure.

### Task v0-H23 (founder): the improvement run

Criterion 7: one factory change, made in response to a run, improves a metric without lowering the hidden score, shown by
`ygg metrics --compare`. The change comes from part two (decision 1, question 2): it has its own change proposal, tasks and
merge. This step runs the factory with it, on the same setup as run 1.

**Named test:** `ygg metrics --compare <run 1> <this run>` says `comparable: yes`, names the metric among those that improved, and
says `reward: held`; the improvement is larger than the spread of v0-H21; and a journal entry tagged `factory-change` cites the
comparison and passes `scripts/journal-check.sh`. **Layer:** the founder's machine. **Size:** M. **Depends on:** part two merged, v0-H21.

- [ ] **Step 1:** run it with the same mode, roles and caps as run 1, and with the first run as the baseline.

```zsh
scripts/ygg-proof-run.sh --name r3 --baseline <run 1 id> --clip
```

- [ ] **Step 2:** write the journal entry: `status: resolved`, tag `factory-change`, the change, the two run ids, the comparison's
      numbers, and the spread. Run `scripts/journal-check.sh`.

### Task v0-H24 (founder, optional): the bridge on Harbor

Checks that the factory runs as a Harbor agent. The product of a toy graph will not pass Harbor's tests: the point is the
protocol. It needs Podman and the Harbor setup of `bench/harbor`.

**Named test:** the trial's `bridge.jsonl` holds `spend`, `upload_dir`, `selfcheck` and `done` requests, each answered, and the
factory's standard error shows the run's exit code. **Layer:** the founder's machine. **Size:** S. **Depends on:** v0-T287, v0-T289 merged.

- [ ] **Step 1:** follow `bench/harbor/README.md` ("A run"), with `--ak "command=ygg bridge --config <factory.yaml> --graph <toy graph> --work
      <a new folder>"` and a config of scripted agents, as `bench/harbor/tests/smoke.sh` sets up its fake factory.
- [ ] **Step 2:** send `<trial>/yggdrasil/bridge.jsonl` and `factory.stderr.log`.

### Task v0-H25 (founder): the exit check

The seven criteria of the design doc §2.3, one line each, from the evidence.

**Named test:** every row of the table below has its evidence. **Layer:** the founder's machine. **Size:** S. **Depends on:** v0-H20 to v0-H23.

| Criterion | Evidence |
| --- | --- |
| 1. builds `client-gallery-lite`; rungs 1 to 6 pass; the hidden suite is scored | run 1: `ygg metrics` shows the grade; the ledger shows the ladder results |
| 2. another agent tool or model for one role | run 2: the roles table and `--compare` |
| 3. a complete hash-chained ledger; `ygg metrics` reports everything | every run: `ygg metrics` refused none, and the figures of spec §10.2 are all in its output |
| 4. all three modes with `scripted`; one real run in `key-points` | `go test -run TestToyGraphEndToEnd ./internal/cli` in `odin` (the three modes) and runs 1 to 3 (key-points) |
| 5. the escape-attempt tests pass | `go test ./...` in `gleipnir` and `odin` |
| 6. journal entries with evidence; factory changes cite `--compare` | `scripts/journal-check.sh` exits 0 |
| 7. one factory change improves a metric and the score held | run 3 against run 1: `--compare` |

- [ ] **Step 1:** run the commands of rows 4, 5 and 6, paste the output and the rows into a journal entry, and write the result.

### Task v0-H26 (founder): retire the v0 hidden suite

The change task `benchmark-split-T002`. After the proof runs are scored, the v0 hidden version is copied to `mimir` with a note naming the
runs it scored, and a new hidden version exists before the next scored run. **This is yours alone; no agent reads or copies a suite.**

**Named test (founder-run):** the retired version's tests in `mimir` match its last commit in `huldra` (`git diff --no-index` prints
nothing), and the next run's `score.json` names the new version. **Layer:** `mimir`, `huldra`. **Size:** S. **Depends on:** v0-H25.

- [ ] **Step 1:** copy the retired version into `mimir` with a note that names the runs of v0-H20 to v0-H23 (their ids), mark it retired
      beside the task as Phase 5c's `retired/<suite>` mark says, and remove it from `huldra` so that `huldra` keeps only versions that have
      not been retired. Open the `mimir` pull request; you merge it.
- [ ] **Step 2:** before the next scored run, write the new hidden version in `huldra` and set `suite` in `task.toml` to it (a new task
      version; the brief and its hash do not change).

---

## Evidence

What was run while this plan was written, on 2026-10-22, on this machine (WSL2 on Linux 6.18, Go 1.26.4). The reference workspace is
five clones side by side under a `go.work` (`odin` at `b8c9716`, `gungnir` at `32cc95d`, `gleipnir` at `6b6f83e`, `jormungandr` at
`ec8f18c`, `havamal` at `be69804`) and a clone of `ouroboric` at `5975dbf`, with one commit for each task of this plan.

**Tests.** At the last commit, `gofmt -l .` prints nothing and `go vet ./...` is clean in `gungnir` and `odin`; `go test ./...`
passes in both (`odin/internal/engine` about 120 s, `internal/cli` about 45 s, the rest a few seconds each). `go test -race` passes
for `internal/bridge`, `internal/metrics`, `internal/report` and `internal/tracker`, and `go test -race -count=3` for the bridge and
billed-dollar tests of `internal/cli`. The whole suite also passes under `-race` in `odin` (`internal/engine` about 170 s, `internal/cli` about 80 s) and in `gungnir`, which is what CI runs. Each task's commit was also tested alone, in a fresh worktree beside the final state of the other
repos (`plan-states.sh`): all 16 commits of `odin` and all 3 of `gungnir` pass `gofmt`, `go vet` and `go test` alone. The check also found that v0-T289 must be the first commit of `odin`: with the new `gungnir`, an old test of the meter fails until it lands (the order table and the pull requests say so). In `ouroboric`, `bash scripts/tests/journal-check.test.sh` runs 20 cases, all `ok`, and passes against the
real journal of 33 entries; `shellcheck -s bash` is clean on both files. `reuse lint -q` (`reuse==5.0.2`) exits 0 in `odin`, `gungnir`
and `ouroboric`, and `markdownlint-cli2` v0.23.3 reports 0 issues on the README and architecture pages and the journal README and
`AGENTS.md` that the tasks edit.

**The first failure of each task** is in its step 2: `plan-red.sh` puts each task's test files on its parent commit and shows what `go test`
prints. Every task fails there, for want of its code, except that the docs test of v0-T278 and v0-T280 fails on the missing
words in the architecture page before the verb's own tests run.

**Defences removed one at a time** (`plan-defences.py`: the text of a defence is replaced in the final code, the test that is meant
to catch it runs, and the code is put back). All 29 rows end in a named failing test:

| Task | Defence removed | Test that fails |
| --- | --- | --- |
| v0-T288 | the dollar cap counts what was billed, not the cost figure | `TestCapReached` |
| v0-T289 | a subscription session bills nothing | `TestOnlyASessionOfAPaidAdapterIsBilled` |
| v0-T289 | the warning of a dollar cap counts what was billed | `TestTheDollarCapStopsOnWhatWasBilledNotOnASubscriptionsEstimate` |
| v0-T273 | the run's own totals are left out of the sum | `TestUsageIsTheSumOfTheSessionLinesAndNeverTheRunTotalsToo` |
| v0-T273 | the ledger's chain is verified before a number is taken | `TestACutOrChangedLedgerIsRefusedBecauseNoNumberFromItCanBeTrusted` |
| v0-T273 | a session with tokens and no cost is unpriced, not free | `TestASessionWithTokensAndNoCostIsCountedAsUnpricedNotAsFree` |
| v0-T274 | the gap before a resume that no failure explains is stopped time | `TestAProcessKilledWithoutALedgerLineLeavesAGapThatTheResumeClosesAndTheReportCallsStopped` |
| v0-T274 | an approval wait is kept apart from stopped time | `TestWallTimeLeavesOutApprovalWaitsAndTimeTheRunWasStopped` |
| v0-T275 | a check's finding is not a reviewer's veto | `TestAReviewerVetoIsAnAttemptWhereAReviewerRaisedABlockingFinding` |
| v0-T275 | only attempt 1 is a first pass | `TestFirstPassRateAndAverageAttemptsCountEveryLoopThatEnded` |
| v0-T275 | a plain approval is not an intervention | `TestInterventionsAreRejectionsNotedApprovalsAndEscalations` |
| v0-T275 | a ledger and run.json that disagree give a warning | `TestUsageThatDisagreesWithRunJSONIsReportedAsAWarning` |
| v0-T276 | escaped defects are fail-to-pass failures | `TestEscapedDefectsAreFailedFailToPassScenariosAndSayWhetherTasksWereGivenUp` |
| v0-T276 | grading after run_finished is not run time | `TestTheGradeComesFromScoreJSONWithItsCategoriesAndTheGradeTimeIsNotRunTime` |
| v0-T277 | agent text is printed on one line without control characters | `TestTextFromAnAgentIsPrintedOnOneLineWithNoControlCharacters` |
| v0-T279 | a fallen reward is not held | `TestAFallingRewardIsNeverHiddenBehindAnImprovedMetric` |
| v0-T279 | two briefs are not comparable | `TestRunsOfAnotherBriefOrSuiteAreNotComparableAndTheReportSaysWhy` |
| v0-T279 | a metric with no direction is never judged | `TestCompareDeltasAreBMinusAAndNameWhatImprovedAndWhatGotWorse` |
| v0-T281 | an agent's claim stays inside its quote | `TestTextAnAgentWroteCannotBreakOutOfItsQuoteOrItsBlock` |
| v0-T282 | only the task's own gate puts it in Needs you | `TestEveryTaskLandsInTheColumnItsStatusAndItsLoopSay` |
| v0-T282 | a long reason is cut on the board | `TestALongReasonIsCutOnTheBoardAndKeptOnTheCard` |
| v0-T283 | a path that is not a project root refuses the list | `TestAListNamingAnythingButProjectRootsIsRefusedWholeWithTheBadPath` |
| v0-T286 | a reply must carry the id of its request | `TestEachRequestCarriesTheNextIDAndTheReplyMustBeForIt` |
| v0-T286 | a refusal is an error | `TestARefusedRequestIsARemoteErrorWithTheAdaptersWords` |
| v0-T286 | a start line without a budget is refused | `TestAStartLineThatIsNotAStartIsRefused` |
| v0-T287 | the run's output goes to standard error, not the bridge | `TestBridgeWritesNothingToStandardOutputButRequests` |
| v0-T287 | the product goes to the start line's workdir | `TestBridgeRunsTheFactoryOnTheBriefAndUploadsTheCommittedProductThenSaysDone` |
| v0-T287 | a refused run sends nothing, so the adapter fails it | `TestBridgeRefusesWhatItCannotRunBeforeItStartsAnything` |
| v0-T287 | a cap above the task's budget is refused | `TestACapOfThePaidRolesAboveTheTasksBudgetIsRefused` |

Earlier rounds of the same checks found and closed these gaps in the tests (each is in the code above): an ignored-dispute test that
asked for a finding id the engine does not have; a dollar-cap warning test whose numbers were over the cap, so the warning could
not show; a second attempt counted as a first pass that no test noticed; a routing lookup count that no test read; a bridge refusal
after the start line that no test covered; an escaped-defects fixture that could not tell fail-to-pass from pass-to-pass failures
(both were 1); and a bridge test that deadlocked, instead of failing, when the run printed on the bridge.

**On real run folders** (the founder's machine, read with a `ygg` built from the reference workspace; nothing in them was changed):

- `20261021-225348-f4bd10`, the smoke with a Qwen implementer (B-110): the usage that `ygg metrics` adds up from the ledger is 31,844 tokens in,
  12,429 out, 165,472 from cache and 14 turns, **equal to the totals in `run.json`**; reward 0.5, fail-to-pass 3 of 6, 3 escaped
  defects, reviewer vetoes 0 of 1 attempt. That is B-136 in numbers: the reviewer did not veto a product that failed half of the
  public suite.
- `20261019-184434-257049`, a scripted run of the `software` graph with a gate, two failures and two resumes: elapsed 41 min 20 s, approval
  wait 17 min 49 s, stopped 11 min 58 s, active 11 min 33 s; these agree with the timestamps read by hand from the ledger. Its
  `run.json` is schema `ygg.run/v2`, which the engine refuses to resume and `ygg metrics` reads.
- `20261019-212556-8b365f` (a gate wait of 19 minutes) and `20261017-152626-13daef` (a loop that gave up: first pass 0 of 1,
  one escalation, two blocked tasks) were read as well. `ygg board` on their projects shows two done and two blocked, with the reason.

**With the bridge:** the toy graph with scripted agents ran through `ygg bridge` and an in-process stand-in for the adapter that answers as
`agent.py` does (`spend`, `upload_dir`, `selfcheck`, `done`; `upload_dir` copies the folder). The uploaded copy held the committed file.

**Not run.**

- **Anything on a real engine or with a real agent.** No sandbox, no Claude Code, no OpenCode session, no OpenRouter call. No real-agent run of the `software` graph
  has happened, so the figures of question 3 (turns, tokens, cost of a gallery run) are estimates from the smoke, and the claim of
  question 10 is read from files, not seen in a run.
- **The Harbor adapter with Harbor.** `ygg bridge` was tested against a Go stand-in of the adapter, not against `ygg_harbor.agent` and a
  Podman task; v0-H24 does that. The adapter's own `pytest` suite was not run.
- **v0-T290 to v0-T294 and the founder tasks.** The proof-run script, the runbook, the proposal and the pointers were not built; the script's
  test cases are written in the task and are written first by the executor. `ygg-proof-run.sh` was never started, not even with `--dry-run`.
- **Whole-repo hooks.** `gitleaks`, `golangci-lint` and CI were not run on the new files. `pre-commit run --all-files` was not run; `shellcheck`,
  `reuse` and `markdownlint-cli2` were run on their own, as above.
- **A journal from before the change.** The billed-dollar change was tested with made-up usages; a day's journal written before it was not
  read (decision 4 says what it does).
