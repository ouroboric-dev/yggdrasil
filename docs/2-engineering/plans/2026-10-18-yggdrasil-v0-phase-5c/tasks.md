---
title: Yggdrasil v0, Phase 5c tasks (the grader, routing, dependency policy and the real smoke)
status: proposed
date: 2026-10-18
related: [../2026-10-12-yggdrasil-v0/plan.md, ../2026-10-17-yggdrasil-v0-phase-5b/tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../changes/2026-10-14-benchmark-split/proposal.md]
style: spec
---

# Yggdrasil v0, Phase 5c: the grader, routing, dependency policy and the real smoke

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking. Tasks and steps marked **founder** are done by the founder,
> never by an agent.

**Goal:** the last part of the [plan](../2026-10-12-yggdrasil-v0/plan.md)'s Phase 5. A finished product is
graded by rung 7: a hidden suite runs in an isolated grader container that starts after every agent container
has stopped, and writes `score.json` to the run's ledger folder only. Rung 3 and rung 4 get what 5b left out:
the two-tenant authorisation check and the dependency policy. Routing gets its deterministic part: a wiring
index and an impact index, with every edge tagged `extracted` or `inferred`, a bench that gates whether an index
ships, and the `pointer-contract` gate. A smoke run with real agents is ready for the founder to start.

**Architecture:** the grade stage is a new last node of a graph (`grade`). Odin stops every sandbox, exports the
project's committed files as `/app` of a fresh container built from the task's `environment/` folder in `mimir`,
mounts the hidden suite read-only from a path in `factory.yaml` that no agent task reads, and joins the suite's
result file with its manifest into `score.json`. The checks of a realm's ladder read policy files baked into the
stack image, as 5b's tool configs are. Routing generators are plain code: same input, same bytes, no model.
`ygg deps bump` bumps a canary product, checks it, and rolls out only after it passes.

**Tech stack:** Go 1.26 and the pins of Phase 5b; `github.com/BurntSushi/toml` v1.6.0 for `task.toml`; the
tools the realms' ladders already use, plus `go.yaml.in/yaml/v3` (pinned) for the two-tenant tool; Playwright
as pinned by the `mimir` task images.

**Spec:** [v0 engineering spec](../../specs/2026-10-11-yggdrasil-v0-spec.md) §8, §9.5, §9.6 and §11; and the
accepted change [benchmark-split](../../changes/2026-10-14-benchmark-split/proposal.md) (its T001 is the grader's
required behaviour), plus the changes the earlier phases list.

**Status:** accepted when the founder merges the pull request that adds this file.

**Code in this plan was run.** Every Go file, script, schema, test and fixture below was built and run in a
scratch workspace on 2026-10-18, one commit per task (a few tasks have two or three commits, where one commit
would pass 400 lines), with `go test -race` where the repo is Go. The grader ran on a real engine (rootless
Podman) with scripted agents and the PUBLIC sample suite of `smoke-notes`; "Evidence" says what happened and
what was not run. Copy the code as written; if a step's expected result differs, stop and report it, because
the plan is wrong. The reading rules for code blocks are those of Phase 5b: a new file is shown whole; a change
is a `diff`; a lock file is copied from the reference workspace or written by `go mod tidy`.

**The hard rule of this plan.** Nothing in it asks an agent to read, list or search `huldra` or
`ouroboric-private`. The grader reads the hidden suite inside the container the founder starts, from a path in
the founder's `factory.yaml`. Every test here uses a tiny suite written for the test, and the smoke uses the
public sample suite in `mimir`. A test walks the sandbox specs of a full fake run and fails if the suite's path
appears in one.

## Decisions for this phase

Each line is **Decided 2026-10-18** when the founder merges this plan. The drafts' own flags are in
"Questions for the founder", with the answer each task assumes.

1. **Phase 5c is the full path to a graded product** (founder, 2026-10-18): the grader, wiring and impact routing
   with its bench, the dependency policy with the canary bump command, and a real-agent smoke that the founder
   starts. 21 agent tasks in six repos plus `yggdrasil` pointers, and two founder tasks (v0-H16, v0-H17).
2. **The grader is native and Harbor-compatible** (founder, 2026-10-18). Odin runs it, so a run ends with a
   score. The task folder follows Harbor (`task.toml` with `verifier.environment_mode = "separate"`,
   `artifacts = ["/app"]`, `SCORE_WEIGHTS`, `suite`), so `bench/harbor` can run the same task later. The
   Harbor adapter is not the grader.
3. **`grade` is a node kind and must be the last node** of a graph. Odin stops every agent sandbox first, then
   exports the project's committed files as the grader's `/app`. The container has exactly three mounts: `/app`
   (read-write copy), `/tests` (the hidden suite, read-only) and `/logs/verifier` (a host folder). It has no
   network but loopback, a label `ygg.grader=<run id>`, and is removed in every case.
4. **Where the hidden suite is.** `grader.suite_dir/<task-id>/<suite>/tests/`, with `<suite>` taken from
   `metadata.suite` of `task.toml`. A `retired/<suite>` mark beside the task in `mimir` refuses that suite
   before anything is built. `grader.tasks_dir` is a `mimir` checkout. The two folders must not sit inside each
   other.
5. **The suite's manifest and the result file are joined by exact id.** `tests/manifest.json`
   (`ygg.suite/v1`) lists each scenario with a category and a kind (`fail-to-pass` or `pass-to-pass`). The
   suite writes Playwright JSON to `/logs/verifier/results.json`. A scenario on one side only is an error
   (`bad_manifest`), never a pass.
6. **The reward counts fail-to-pass scenarios only,** weighted by category from `SCORE_WEIGHTS`.
   Pass-to-pass is reported on its own and never changes `reward` (spec §11: reported separately).
7. **Refusals.** `retired`, `missing_suite`, `brief_changed`, `bad_manifest`, `bad_task`. The first four that
   can be seen before the container runs build nothing; `bad_manifest` from a mismatch of results can only be
   seen after it ran. A refusal fails the run; `ygg resume` grades again. `ygg grade` exits 2.
8. **`score.json` is for the founder and the ledger.** It is written to `<project>/.factory/runs/<run>/` and
   named in the ledger. It is never in a leaf, never in a task's input, never shown to an agent. (Questions 3
   and 4 below.)
9. **Rootless Podman here cannot apply `--memory` or `--cpus`** (no cgroup delegation); with them every grade run
   failed with exit 127. `grader.memory: none` and `grader.cpus: 0` mean "no limit" on purpose, `ygg doctor` warns,
   and a missing field is still an error. Exit codes 125 to 127 of `podman run` are engine errors, not suite results.
10. **Routing indexes carry tags.** Each edge is `extracted` (read from a manifest, an import, an OpenAPI file or
    a lockfile) or `inferred`. The wiring block of `REPOS.md` sits between `<!-- ygg:wiring:begin -->` and
    `<!-- ygg:wiring:end -->`; the impact index is `.ygg/impact.json`. Both are rebuilt when a pointer node moves,
    in the project umbrella only. Generators never call a model.
11. **The `pointer-contract` gate** passes on `extracted` evidence or `oasdiff` only. A guess alone gives
    `escalate`, and a person decides in every mode. A pointer move that changes no contract passes. The gate
    reads the impact index shipped at the umbrella's `HEAD`.
12. **The bench gates the shipping of an index.** A pack may carry `routing: {threshold, bench}`; an index ships
    only at or above the threshold. The scripted grep baseline is reported beside the score, and does not gate.
13. **The dependency policy is a baked file,** `devcontainer/checks/config/deps-policy.json`
    (`ygg.deps/v1`), read from beside the script and never from the leaf. A direct dependency has an exact
    version (Go), or `x.y.z` or `~x.y.z` (npm); a `minimum` names a version floor; the audits are
    `govulncheck` and OSV (Go), `npm audit` and OSV (web). The rung sits before `security`.
14. **`ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>...]`** bumps the canary, runs the
    `deps` and `unit` checks in the canary's sandbox, and on failure puts the canary back byte for byte and
    touches nothing else. After a pass it bumps and checks each rollout product, one at a time. The tool may
    change the manifest and its lock file and nothing else. It does not commit.
15. **The two-tenant check is its own rung, `authz`,** after `security` in helheim-go. A Go tool reads
    `openapi.yaml` and wants a passing `TestCrossTenant<OperationId>` for each route with a path
    variable (any variable; the first draft took only id-like names, and the founder closed that on 2026-10-18, see the
    errata note below). User A must get 2xx and user B 403 or 404. A route may be marked public in `authz.json` with a reason.
16. **The smoke task is `smoke-notes`** in `mimir`, with a PUBLIC sample suite and a reference solution kept out
    of `environment/`. The real hidden suite for any task plugs in through the same config.
17. **The real-agent smoke is a script and an example config with real caps** (v0-T263): $3 a run and $6 a day,
    400k tokens a run. Odin has no per-agent token cap; a graph's `max_turns` and timeout bound an agent. The
    script never reads `factory.env`'s values.
18. **Sizes.** Tasks stay under 400 inserted lines where the code allows; the commits that pass it say why
    (a fixture or a golden file).
19. **What 5c leaves open** is in "Not in Phase 5c" and in the backlog items v0-T265 files.

## Questions for the founder

Each task assumes the answer in **bold**. Say so on the pull request if you want another.

| # | Question | Assumed |
| --- | --- | --- |
| 1 | Reward counts fail-to-pass only, and pass-to-pass is reported alone? | **Yes** |
| 2 | Hidden suite and grader run with no memory or CPU limit on this machine (`none` and `0`)? Or do you delegate cgroups to your user? | **No limit, with a doctor warning** |
| 3 | `.factory/runs/` is untracked but not ignored in a project. Does the umbrella template ignore it? | **It must; v0-T265 files a backlog item** |
| 4 | `score.json` stays in the run folder of the project's working copy. Move it outside the project? | **Stays** |
| 5 | The grader's `/app` is the umbrella plus `repos/<leaf>`, and the suite starts `/app/start.sh`. How does a real project provide `start.sh`? The smoke commits a shim. | **Open; backlog** |
| 6 | The first contract that a new API adds gets `escalate` (the shipped index does not know it). Pass instead? | **Escalate** |
| 7 | Must the grep baseline also gate an index (spec §8.3 "raises the score")? | **No: report only** |
| 8 | Who writes a project's first routing bench: a planner stage, or a person? | **A person; no `routing` block in midgard-react** |
| 9 | Real version floors for the policy files. The npm floor `vite 8.3.2` equals the template pin and answers no advisory. | **Floors equal the template pins** |
| 10 | Go and OSV audits fail on any finding (neither call has a severity filter); npm audit uses `--audit-level=high`. | **As built** |
| 11 | A canary checks `deps` and `unit` only. Enough? | **Yes** |
| 12 | A bump stays uncommitted in the working copies. Commit or branch it? | **Uncommitted** |
| 13 | Is it acceptable that the smoke script sources `factory.env` in the subshell that runs `ygg`, when it only counts the two names with `grep -c`? | **Yes** |
| 14 | Command timeout of a bump is 30 minutes, the loop's is 10. | **30 minutes** |
| 15 | `Advance` has no default case: an unknown node kind passes silently. `Block` in unattended mode still stops the run. A bump leaves `.factory/deps/` that `doctor` and `status` do not list. | **Three backlog items (v0-T265)** |
| 16 | `v0-T261` is 595 lines (a task folder, its sample suite, a reference solution and a check script). Split? | **One task; the check script is 130 lines of it** |

## Global constraints

- **Local copies.** The component repos are submodules of `yggdrasil`, at
  `/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`, and `yggdrasil/go.work` builds them together.
  `mimir` and `ouroboric` are separate folders beside it. Each task works on a branch in the repo it changes.
  The umbrella's pointers move once, in v0-T265.
- **GitHub.** Agents reach GitHub only as `ouroboric-pr-bot`, through
  `/home/brunogbv/brunogbv/ouroboric/ouroboric/scripts/as-bot.sh`. Every change lands through a PR the founder
  merges. Agents never merge and never push to `main`.
- **Commits.** Read `git status --short` first, and stage explicit paths, never `git add -A`. Commit messages end
  with `Co-Authored-By: Claude <model> <noreply@anthropic.com>`. Commits and PRs carry no session links. Every
  repo runs the `gitleaks` hook.
- **Go.** `go.mod` says `go 1.26`. Code is `gofmt`-clean and `go vet`-clean. Before a PR opens, the repo passes
  `GOWORK=off go test -race ./...` in its own folder. This machine has Go 1.26.4; CI uses 1.26.9.
- **Shell.** Every script starts `#!/bin/bash` or `#!/usr/bin/env bash` as its neighbours do, uses
  `set -euo pipefail` (or `-uo pipefail` where a probe must go on), and passes `shellcheck -s bash`.
- **Pins to the siblings.** `gleipnir`, `odin`, `helheim-go` and `midgard-react` pin `gungnir`; `odin` pins
  `gleipnir`. Until a sibling's PR is merged, develop through `yggdrasil/go.work`; the pin is the last commit of
  a repo's branch. The pull requests go in this order: gungnir; gleipnir, helheim-go, midgard-react and mimir;
  odin; ouroboric.
- **Event names are snake case** (`grade_started`, not `grade.started`): the ledger schema is an enum.
- **Credentials.** v0-T262 and everything before v0-H17 need no token. No agent reads, prints or stores
  `~/.config/ouroboric/factory.env`. The real-agent script checks for the two variable names with `grep -c` and
  never prints a value.
- **The hidden suite.** No agent reads, lists or searches `ouroboric-dev/huldra` or its clone under
  `~/brunogbv/ouroboric-private/`. No file of this plan names a path inside it. The realms' prompts never
  mention the benchmark (a test of 5b checks).
- **Licences.** `reuse lint` (`reuse==5.0.2`) passes in every repo a task touches.
- **Deletions** (`rm`, `git branch -D`) are asked for first, one per command, after a read-only check.
- **Tests are hermetic,** except those 5b lists and: the real-engine tests (behind the `sandbox` tag, they skip
  without an engine), the offline `go get` of v0-T259 (a local `file://` proxy), and the container build of
  `smoke-notes` (v0-T261, needs an engine). A test never writes under the real `HOME`.
- **Agent text is data.** A result file, a manifest, a leaf's source and a verdict come from an agent or a suite:
  they are read exactly, bounded, and reached through no symlink.
- **No claim without the tool.** A script in a stack image is tried with the real tools it calls before it is
  described as working; a stand-in tool is only for the script's own logic. Where a tool was not available
  (`govulncheck`, `osv-scanner`, `oasdiff`, `npm bump`) the task's Evidence says so.

## Review focus

1. **A hidden suite an agent could reach.** A mount, an env var, a path in a prompt, a copy of the suite in a leaf
   or in `/app`. Expected: the suite path appears in no agent sandbox spec; the grade stage starts after every
   agent sandbox stopped; the grader container has three mounts and no more; `score.json` is in no leaf. Pinned
   by v0-T246 `TestGradeNeverMountsAnythingButTheThreePaths`, v0-T249 (the walker test and the order test) and
   v0-T262 (the polled engine run).
2. **A score that can be forged or inflated.** A brief that changed after the task froze, a retired suite, a
   scenario missing from the results or the manifest, a skipped spec counted as a pass, a reward over a category
   with no scenario. Expected: refused with a named reason; a skip is a skip. Pinned by v0-T247
   `TestGraderRefusesRetiredVersion`, v0-T248 and v0-T249 `TestGraderCombinesPublicTaskAndHiddenSuite`.
3. **A grader that is left running or hangs.** A container after a timeout, after a cancel, after an engine
   error; a suite that never ends. Expected: removed in every case; the smaller timeout wins; `ygg doctor`
   finds a leftover. Pinned by v0-T246 and v0-T250.
4. **A routing answer that looks sure and is a guess.** An `inferred` edge used as proof, an index that lost
   edges, an index below the bench's threshold. Expected: `escalate`; the shrink guard refuses; the index does not
   ship. Pinned by v0-T253 and v0-T254 `TestAnInferredOnlyEdgeNeverGivesPass`, v0-T255.
5. **A policy an agent can edit.** A policy file or a registry read from the leaf, a bump that edits more than
   a manifest. Expected: the policy is read from beside the baked script; the bump may change the manifest and its
   lock file and nothing else. Pinned by v0-T257, v0-T258 and v0-T259.
6. **A bump that spreads before the canary passes.** A failing canary that is not put back, a rollout product
   touched after a failure. Expected: the canary is restored byte for byte and nothing else changes. Pinned by
   v0-T259.
7. **A cross-tenant route with no test, or a test that cheats.** Expected: the rung fails for a route with no
   passing `TestCrossTenant…`. A hostile author can still fake the helper, so reviewers read the test. Pinned by
   v0-T260.
8. **A real-agent run that spends more than it should or reads the credentials.** Expected: caps in the
   config, the cost printed from the ledger, the names counted and never the values. Pinned by v0-T263.

## Order

| Task | Repo | Size | Depends on |
| --- | --- | --- | --- |
| v0-T245 schema and ledger events for the grader, routing and dependency checks; the `grade` node; the `grader` block | `gungnir` | M | Phase 5b |
| v0-T246 `Grade`: build the task image, run the hidden suite in an isolated container | `gleipnir` | M | v0-T245 |
| v0-T247 task.toml, the brief hash, the suite version, the retired mark | `odin` | M | v0-T245 |
| v0-T248 the suite manifest, the result join and `score.json` | `odin` | M | v0-T247 |
| v0-T249 the `grade` stage in the engine | `odin` | M | v0-T246, v0-T248 |
| v0-T250 `ygg grade`, the `grader` config, `ygg doctor` finds leftovers | `odin` | M | v0-T249 |
| v0-T251 the wiring index generator | `odin` | M | v0-T245 |
| v0-T252 the impact index generator | `odin` | M | v0-T251 |
| v0-T253 the shrink guard covers both indexes; routing events | `odin` | M | v0-T252 |
| v0-T254 the `pointer-contract` gate | `odin` | M | v0-T253 |
| v0-T255 the routing bench; the pack's `routing` block | `gungnir`, `odin` | M | v0-T254 |
| v0-T256 `pointer-contract` in the realms; routing docs | `midgard-react`, `helheim-go` | S | v0-T255 |
| v0-T257 the dependency policy rung for Go | `helheim-go` | M | v0-T245 |
| v0-T258 the dependency policy rung for the web leaf | `midgard-react` | M | v0-T245 |
| v0-T259 `ygg deps bump` | `odin` | L | v0-T257, v0-T258, v0-T255 |
| v0-T260 the two-tenant authorisation harness | `helheim-go` | M | v0-T257 |
| v0-T261 the smoke task `smoke-notes` and its public sample suite | `mimir` | M | none |
| v0-T262 the grader smoke on a real engine; `grader.memory: none` | `odin`, `gungnir`, `ouroboric` | M | v0-T250, v0-T261 |
| v0-T263 the real-agent smoke script, example config and cost report | `odin`, `ouroboric` | M | v0-T262 |
| v0-T264 documentation of the grader, routing and the bump | `odin`, `gleipnir`, `gungnir` | S | v0-T263 |
| v0-T265 pointers and the exit check | `yggdrasil` | S | all above, merged |
| v0-H16 (founder) the grader smoke on the merged code | the founder's machine | S | v0-T262 merged |
| v0-H17 (founder) the real-agent smoke | the founder's machine | S | v0-H16, v0-T263 merged |

Pull requests, in order: `gungnir` (v0-T245, the `routing` block of v0-T255, the limits change of v0-T262 and
the docs of v0-T264) first. Then, beside each other, `gleipnir` (v0-T246, docs), `helheim-go` (v0-T256, v0-T257,
v0-T260), `midgard-react` (v0-T256, v0-T258) and `mimir` (v0-T261). Then `odin` (all its tasks, in the order
above), then `ouroboric` (the two scripts). Inside a repo the tasks stack on one branch.

## Not in Phase 5c

The Harbor verifier path for the same task (`bench/harbor` runs agents, not the grader); the real hidden suite
of `client-gallery-lite` and the first proof run (Phase 6, with the metrics); `doc-code` and `decisions`
indexes (spec §8.2) and the routing summary injected into a session (§8.1); the emitter of `routing_lookup`;
a TypeScript import graph; `ygg routing build|bench` as commands; a per-agent token cap; the `github` remote
and fetching a realm by tag; a second flavor of Midgard or Helheim; deploying anything; the backlog items of
decision 19. Asgard as a realm is next after this phase.

## Errata found while executing

- **The smoke brief's hash.** markdownlint (MD060) rejects the compact table separators of `smoke-notes/instruction.md`.
  The two separator rows are now `| --- |`, and the pinned SHA-256 is `637d14af…0ef82` (was `2ec48a63…c003`) in v0-T261
  (`task.toml`, the README row and the check output). No markdownlint ignore is added. v0-T262 and later tasks read
  the hash from `task.toml`, so they do not change.
- **The two-tenant rule (decision 15).** `ygg-authz` takes every path variable as a resource id, not only id-like names
  (`{photoId}`, `*_id`). A route is excused only by a public mark with a reason in `authz.json`. The code of v0-T260 in
  this file still shows the first draft's `idName` filter; the merged helheim-go code is the reference.

## How each task lands

Every agent task ends the same way. Run the commands in the repo's folder:

```bash
gofmt -l .                        # prints nothing
go vet ./...
GOWORK=off go test -race ./...    # what CI runs
uvx -q --from 'reuse==5.0.2' reuse lint -q
git status --short                # then stage the task's files by path
git commit -m "<what changed> (v0-T2xx)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

A shell script also passes `shellcheck -s bash`. When the repo's last task is committed, push and open its pull
request:

```bash
../../ouroboric/scripts/as-bot.sh <repo> git push -u origin <branch>
../../ouroboric/scripts/as-bot.sh <repo> gh pr create --repo ouroboric-dev/<repo> --title "<title>" --body-file <file>
```

The PR body names the tasks, lists their acceptance criteria with their evidence (the named tests' output), and
says which earlier PRs it needs merged first. CI's `test` check must be green before the founder merges it.
To pin a sibling, fetch it, then pin its `main`:

```bash
../../ouroboric/scripts/as-bot.sh --read all git -C ../gungnir fetch -q origin
GOWORK=off go get github.com/ouroboric-dev/gungnir@$(git -C ../gungnir rev-parse origin/main)
GOWORK=off go mod tidy
```

`GOWORK=off go test` fails until the merged pins exist; develop through `go.work` and pin before the PR.

---

### Task v0-T245: schema and ledger events for the grader, routing and dependency checks; the `grade` node kind; the `grader:` factory block

Gungnir's first task of Phase 5c. Branch `grader/contract` from `main` in `gungnir`, before step 1. The isolated grader (change `benchmark-split`) needs a contract before any other repo can use it: a node that grades, a factory block that says where the tasks and the hidden suites are, the shape of `score.json` and of a suite's `manifest.json`, and the ledger events. The ledger events of the routing and dependency tasks (v0-T251 to v0-T259) are added here too, so those tasks only use them.

**Files (in `gungnir`):**

- Create: `score.go`, `score_test.go`, `schema/score.go`, `schema/score_test.go`, `schema/score.schema.json`, `schema/suite.schema.json`, `schema/event_grade_test.go`, `schema/graph_grade_test.go`, `schema/factory_grader_test.go`
- Modify: `event.go`, `schema/ledger-event.schema.json`, `schema/graph.go`, `schema/graph.schema.json`, `schema/factory.go`, `schema/factory.schema.json`

**Interfaces:**

- Produces: `schema.KindGrade` (`grade`), a graph node with an `id` and nothing else. It must be the last node of the graph, and there is at most one: grading starts only after every sandbox has stopped. It is not allowed in a `foreach` body.
- Produces: `schema.Factory.Grader *Grader{TasksDir, SuiteDir string; Timeout Duration; Memory string; CPUs int}`, YAML key `grader`. All five fields are required when the block is there, and nothing is defaulted. The two folders are clean, absolute paths, not the root, and neither is inside the other. `timeout` is positive (`30m`), `memory` is a number and `m` or `g` (`4g`), `cpus` is 1 to 256.
- Produces: `gungnir.Suite{Schema, Suite, Scenarios []Scenario{ID, Category, Kind}}` (`tests/manifest.json`, `ygg.suite/v1`) with `Validate`, and `schema.ParseSuite([]byte)`. A scenario id used twice, no scenario, an unknown kind and a wrong schema are errors.
- Produces: `gungnir.Score` (`score.json`, `ygg.score/v1`) with the fields of the grader contract, `Validate`, `gungnir.RewardOf(categories)` and `schema.ParseScore([]byte)`. `Validate` checks that the tallies, the categories, the weights (sum 1, within 1e-9) and the reward add up to the scenarios. Only fail-to-pass scenarios count in `categories` and in `reward`; pass-to-pass is reported on its own.
- Produces: `gungnir.FailToPass`, `PassToPass`, `ScenarioPassed`, `ScenarioFailed`, `ScenarioSkipped`, and `gungnir.GradeReason` with `GradeRetired`, `GradeMissingSuite`, `GradeBriefChanged`, `GradeBadManifest`, `GradeBadTask`.
- Produces: seven `EventName`s and their `Event` fields. The ledger writes every event name in snake case, so the contract's `grade.started` is `grade_started` (see "Deviation" below): `EventGradeStarted`, `EventGradeFinished`, `EventGradeRefused`, `EventRoutingIndexBuilt`, `EventPointerContractChecked`, `EventDepsChecked`, `EventDepsBump`. `Events()` lists them and the ledger schema accepts them.

| Event | Fields (JSON name; `Event` field) |
| --- | --- |
| `grade_started` | `ygg.task.id` (`Task`), `ygg.grade.suite` (`Suite`), `ygg.grade.brief_sha256` (`BriefSHA256`), `ygg.grade.image` (`Image`) |
| `grade_finished` | `Task`, `Suite`, `ygg.grade.score_path` (`ScorePath`), `ygg.grade.reward` (`Reward *float64`: a pointer, so a reward of 0 is still written), `ygg.grade.fail_to_pass` (`FailToPass`, `"p/t"`), `ygg.grade.pass_to_pass` (`PassToPass`) |
| `grade_refused` | `Task`, `Suite`, `ygg.grade.reason` (`Reason GradeReason`) |
| `routing_index_built` | `ygg.routing.kind` (`IndexKind`: `wiring` or `impact`), `ygg.routing.edges` (`Edges`), `ygg.routing.extracted` (`Extracted`), `ygg.routing.inferred` (`Inferred`) |
| `pointer_contract_checked` | `ygg.pointer.move` (`Move`), `ygg.pointer.evidence` (`Evidence`: `extracted`, `inferred` or `oasdiff`), `ygg.verdict` (`Verdict`: `pass`, `fail` or `escalate`) |
| `deps_checked` | `ygg.realm.name` (`Realm`), `ygg.verdict` (`Verdict`: `pass` or `fail`), `ygg.deps.findings` (`Findings`) |
| `deps_bump` | `ygg.deps.package` (`Package`), `ygg.deps.from` (`From`), `ygg.deps.to` (`To`), `ygg.deps.stage` (`Stage`: `canary` or `rollout`), `ygg.verdict` (`Verdict`) |

A count of 0 (`Edges`, `Extracted`, `Inferred`, `Findings`) is left out of the line, like the other counts of the ledger. The schema therefore asks for at least 1 where a field is there.

**Deviation from the grader contract (T245 owns the names):** the contract writes `grade.started`, `routing.index_built`, `pointer_contract.checked`, `deps.checked` and `deps.bump`, and says `routing.lookup` and `conformance.checked` exist. They do not. The ledger's 36 names are snake case (`routing_lookup`, `conformance_checked`), and the ledger schema is an enum of them. The new names follow that rule. Every later task uses the snake-case names.

**Acceptance criteria:**

- [ ] A graph whose last node is `{ id: score, kind: grade }` loads. A grade node with a node after it, two grade nodes, a grade node in a `foreach` body, and a grade node with a field (`repo`, `run`) are refused.
- [ ] A `grader:` block with five exact fields loads. A relative folder, a folder that is not clean, the root, one folder inside the other, a timeout of zero, negative or without a unit, a missing field, a memory without a unit, zero `cpus` and an unknown key are refused. A config with no `grader:` block still loads.
- [ ] A score round-trips through JSON. A score with a lying tally, category, weight sum or reward is refused. A pass-to-pass failure does not change the reward. A category with no scenarios counts 0.
- [ ] A manifest with a duplicate scenario id, a wrong kind, no scenario, an unknown field or a second document is refused.
- [ ] All seven events validate with their fields. A reward of 0 is written. A reward over 1, a tally that is not `p/t`, an unknown reason, evidence, stage or verdict, and a short brief hash are refused.

**Review focus pinned by tests:** a score that does not add up is never accepted (`TestAScoreThatDoesNotAddUpIsRefused`, `TestParseScoreReadsWhatMarshalWrote`); pass-to-pass never moves the reward (`TestPassToPassNeverChangesTheReward`); an ambiguous manifest is an error and never a pass (`TestASuiteManifestIsRefusedWhenItIsAmbiguous`, `TestParseSuiteReadsAManifestExactly`); grading cannot start while a sandbox runs (`TestAGradeNodeThatCouldRunBesideASandboxIsRefused`); the hidden suite's folder cannot sit inside the tasks folder an agent may be given (`TestTheGraderBlockIsRefusedWhenItIsNotExact`); a reward of 0 is still in the ledger (`TestAZeroRewardIsStillWrittenAndABadGradeFieldIsRefused`).

**Named test:** `go test ./schema . -run 'TestAScoreRoundTripsThroughJSON|TestPassToPassNeverChangesTheReward|TestAScoreThatDoesNotAddUpIsRefused|TestASuiteManifestIsRefusedWhenItIsAmbiguous|TestParseSuiteReadsAManifestExactly|TestParseScoreReadsWhatMarshalWrote|TestAGradeNodeEndsTheGraph|TestAGradeNodeThatCouldRunBesideASandboxIsRefused|TestFactoryNamesTheGrader|TestTheGraderBlockIsRefusedWhenItIsNotExact|TestTheLedgerRecordsGradingRoutingAndDependencyChecks|TestAZeroRewardIsStillWrittenAndABadGradeFieldIsRefused|TestLedgerEventSchema'` in `gungnir`. **Layer:** `gungnir`. **Size:** L (884). **Depends on:** Phase 5b merged.

- [ ] **Step 1:** write the tests.

Write `score_test.go`:

```go
package gungnir

import (
	"encoding/json"
	"math"
	"strings"
	"testing"
	"time"
)

func goodScore() Score {
	t0 := time.Date(2026, 10, 18, 9, 0, 0, 0, time.UTC)
	return Score{
		Schema: ScoreSchema, Run: "20261018-090000-a1b2c3", Task: "client-gallery-lite", TaskVersion: "4.0.0",
		BriefSHA256: strings.Repeat("ab", 32), Suite: "v1", Started: t0, Finished: t0.Add(20 * time.Minute),
		Scenarios: []ScoredScenario{
			{"photographer creates a gallery", "photographer", FailToPass, ScenarioPassed},
			{"photographer uploads a photo", "photographer", FailToPass, ScenarioFailed},
			{"client opens a link", "client", FailToPass, ScenarioPassed},
			{"login page loads", "client", PassToPass, ScenarioPassed},
			{"old link still works", "client", PassToPass, ScenarioFailed},
		},
		FailToPass: Tally{2, 3},
		PassToPass: Tally{1, 2},
		Categories: map[string]CategoryScore{"photographer": {1, 2, 0.4}, "client": {1, 1, 0.6}},
		Reward:     0.4*0.5 + 0.6,
	}
}

func TestAScoreRoundTripsThroughJSON(t *testing.T) {
	s := goodScore()
	if err := s.Validate(); err != nil {
		t.Fatalf("Validate() = %v", err)
	}
	raw, err := json.Marshal(s)
	if err != nil {
		t.Fatal(err)
	}
	var back Score
	if err := json.Unmarshal(raw, &back); err != nil {
		t.Fatal(err)
	}
	again, _ := json.Marshal(back)
	if string(raw) != string(again) || back.Validate() != nil {
		t.Errorf("a score changed in a round trip:\n%s\n%s", raw, again)
	}
	for _, key := range []string{`"schema":"ygg.score/v1"`, `"task_version":"4.0.0"`, `"fail_to_pass":{"passed":2,"total":3}`} {
		if !strings.Contains(string(raw), key) {
			t.Errorf("score lacks %s:\n%s", key, raw)
		}
	}
}

func TestPassToPassNeverChangesTheReward(t *testing.T) {
	s := goodScore()
	want := RewardOf(s.Categories)
	for i := range s.Scenarios {
		if s.Scenarios[i].Kind == PassToPass {
			s.Scenarios[i].Status = ScenarioFailed
		}
	}
	s.PassToPass = Tally{0, 2}
	if err := s.Validate(); err != nil {
		t.Fatalf("Validate() = %v", err)
	}
	if got := RewardOf(s.Categories); got != want {
		t.Errorf("RewardOf = %v after pass-to-pass failed, want %v", got, want)
	}
	if got := RewardOf(map[string]CategoryScore{"a": {0, 0, 0.5}, "b": {3, 3, 0.5}}); math.Abs(got-0.5) > 1e-12 {
		t.Errorf("a category with no scenarios counts 0, so RewardOf = %v, want 0.5", got)
	}
}

func TestAScoreThatDoesNotAddUpIsRefused(t *testing.T) {
	cases := map[string]func(*Score){
		"another schema":                 func(s *Score) { s.Schema = "ygg.score/v2" },
		"no run":                         func(s *Score) { s.Run = "" },
		"a bad task version":             func(s *Score) { s.TaskVersion = "4" },
		"a short brief hash":             func(s *Score) { s.BriefSHA256 = "abc" },
		"finished before started":        func(s *Score) { s.Finished = s.Started.Add(-time.Second) },
		"a scenario used twice":          func(s *Score) { s.Scenarios = append(s.Scenarios, s.Scenarios[0]) },
		"an unknown status":              func(s *Score) { s.Scenarios[0].Status = "flaky" },
		"an unknown kind":                func(s *Score) { s.Scenarios[0].Kind = "maybe" },
		"a fail-to-pass tally that lies": func(s *Score) { s.FailToPass = Tally{3, 3} },
		"a pass-to-pass tally that lies": func(s *Score) { s.PassToPass = Tally{2, 2} },
		"a category that lies":           func(s *Score) { s.Categories["client"] = CategoryScore{0, 1, 0.6} },
		"a category with no entry":       func(s *Score) { delete(s.Categories, "client") },
		"weights that do not sum to 1":   func(s *Score) { s.Categories["client"] = CategoryScore{1, 1, 0.5} },
		"a reward that is not the sum":   func(s *Score) { s.Reward = 1 },
		"a weight over 1":                func(s *Score) { s.Categories["client"] = CategoryScore{1, 1, 1.6} },
	}
	for name, mutate := range cases {
		s := goodScore()
		mutate(&s)
		if err := s.Validate(); err == nil {
			t.Errorf("%s: Validate() = nil", name)
		}
	}
}

func TestASuiteManifestIsRefusedWhenItIsAmbiguous(t *testing.T) {
	good := Suite{Schema: SuiteSchema, Suite: "v1", Scenarios: []Scenario{
		{"photographer creates a gallery", "photographer", FailToPass}, {"login page loads", "client", PassToPass}}}
	if err := good.Validate(); err != nil {
		t.Fatalf("Validate() = %v", err)
	}
	cases := map[string]func(*Suite){
		"another schema":     func(s *Suite) { s.Schema = "ygg.suite/v2" },
		"no suite version":   func(s *Suite) { s.Suite = "" },
		"no scenarios":       func(s *Suite) { s.Scenarios = nil },
		"an id used twice":   func(s *Suite) { s.Scenarios[1].ID = s.Scenarios[0].ID },
		"an empty id":        func(s *Suite) { s.Scenarios[0].ID = "" },
		"a category in caps": func(s *Suite) { s.Scenarios[0].Category = "Photographer" },
		"an unknown kind":    func(s *Suite) { s.Scenarios[0].Kind = "flaky" },
	}
	for name, mutate := range cases {
		s := good
		s.Scenarios = append([]Scenario(nil), good.Scenarios...)
		mutate(&s)
		if err := s.Validate(); err == nil {
			t.Errorf("%s: Validate() = nil", name)
		}
	}
}
```

Write `schema/score_test.go`:

```go
package schema

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

const goodManifest = `{"schema":"ygg.suite/v1","suite":"v1","scenarios":[
 {"id":"photographer creates a gallery","category":"photographer","kind":"fail-to-pass"},
 {"id":"login page loads","category":"client","kind":"pass-to-pass"}]}`

func TestParseSuiteReadsAManifestExactly(t *testing.T) {
	s, err := ParseSuite([]byte(goodManifest))
	if err != nil || s.Suite != "v1" || len(s.Scenarios) != 2 || s.Scenarios[1].Kind != gungnir.PassToPass {
		t.Fatalf("ParseSuite() = %+v, %v", s, err)
	}
	bad := map[string]string{
		"nothing":          ``,
		"prose":            `the suite`,
		"another schema":   strings.Replace(goodManifest, "ygg.suite/v1", "ygg.suite/v2", 1),
		"an unknown kind":  strings.Replace(goodManifest, `"pass-to-pass"`, `"flaky"`, 1),
		"an unknown field": strings.Replace(goodManifest, `"suite":"v1",`, `"suite":"v1","extra":1,`, 1),
		"an id used twice": strings.Replace(goodManifest, "login page loads", "photographer creates a gallery", 1),
		"no scenarios":     `{"schema":"ygg.suite/v1","suite":"v1","scenarios":[]}`,
		"two documents":    goodManifest + goodManifest,
	}
	for name, doc := range bad {
		if _, err := ParseSuite([]byte(doc)); err == nil {
			t.Errorf("%s: ParseSuite() = nil", name)
		}
	}
}

func TestParseScoreReadsWhatMarshalWrote(t *testing.T) {
	t0 := time.Date(2026, 10, 18, 9, 0, 0, 0, time.UTC)
	want := gungnir.Score{
		Schema: gungnir.ScoreSchema, Run: "20261018-090000-a1b2c3", Task: "client-gallery-lite", TaskVersion: "4.0.0",
		BriefSHA256: strings.Repeat("ab", 32), Suite: "v1", Started: t0, Finished: t0.Add(time.Minute),
		Scenarios:  []gungnir.ScoredScenario{{ID: "a", Category: "photographer", Kind: gungnir.FailToPass, Status: gungnir.ScenarioPassed}},
		FailToPass: gungnir.Tally{Passed: 1, Total: 1},
		Categories: map[string]gungnir.CategoryScore{"photographer": {Passed: 1, Total: 1, Weight: 1}},
		Reward:     1,
	}
	raw, _ := json.Marshal(want)
	got, err := ParseScore(raw)
	if err != nil {
		t.Fatalf("ParseScore() = %v\n%s", err, raw)
	}
	if again, _ := json.Marshal(got); string(again) != string(raw) {
		t.Errorf("round trip changed the score:\n%s\n%s", raw, again)
	}
	bad := map[string]string{
		"an unknown field":   strings.Replace(string(raw), `"reward":1`, `"reward":1,"bonus":2`, 1),
		"a reward that lies": strings.Replace(string(raw), `"reward":1`, `"reward":0.5`, 1),
		"a reward over 1":    strings.Replace(string(raw), `"reward":1`, `"reward":2`, 1),
		"no categories":      strings.Replace(string(raw), `"categories":{"photographer":{"passed":1,"total":1,"weight":1}}`, `"categories":{}`, 1),
		"a missing field":    strings.Replace(string(raw), `"suite":"v1",`, ``, 1),
	}
	for name, doc := range bad {
		if _, err := ParseScore([]byte(doc)); err == nil {
			t.Errorf("%s: ParseScore() = nil", name)
		}
	}
}
```

Write `schema/event_grade_test.go`:

```go
package schema

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func TestTheLedgerRecordsGradingRoutingAndDependencyChecks(t *testing.T) {
	reward := 0.75
	sha := strings.Repeat("ab", 32)
	cases := []struct {
		name  gungnir.EventName
		fill  func(*gungnir.Event)
		wants []string
	}{
		{gungnir.EventGradeStarted, func(e *gungnir.Event) {
			e.Task, e.Suite, e.BriefSHA256, e.Image = "client-gallery-lite", "v1", sha, "localhost/ygg-grader-client-gallery-lite:0123456789ab"
		}, []string{`"event":"grade_started"`, `"ygg.task.id":"client-gallery-lite"`, `"ygg.grade.suite":"v1"`, `"ygg.grade.brief_sha256":"` + sha + `"`, `"ygg.grade.image":"localhost/ygg-grader-client-gallery-lite:0123456789ab"`}},
		{gungnir.EventGradeFinished, func(e *gungnir.Event) {
			e.Task, e.Suite, e.ScorePath, e.Reward, e.FailToPass, e.PassToPass = "client-gallery-lite", "v1", "/runs/r1/score.json", &reward, "3/4", "5/5"
		}, []string{`"event":"grade_finished"`, `"ygg.grade.score_path":"/runs/r1/score.json"`, `"ygg.grade.reward":0.75`, `"ygg.grade.fail_to_pass":"3/4"`, `"ygg.grade.pass_to_pass":"5/5"`}},
		{gungnir.EventGradeRefused, func(e *gungnir.Event) {
			e.Task, e.Suite, e.Reason = "client-gallery-lite", "v1", gungnir.GradeRetired
		}, []string{`"event":"grade_refused"`, `"ygg.grade.reason":"retired"`}},
		{gungnir.EventRoutingIndexBuilt, func(e *gungnir.Event) {
			e.IndexKind, e.Edges, e.Extracted, e.Inferred = "wiring", 12, 10, 2
		}, []string{`"event":"routing_index_built"`, `"ygg.routing.kind":"wiring"`, `"ygg.routing.edges":12`, `"ygg.routing.extracted":10`, `"ygg.routing.inferred":2`}},
		{gungnir.EventPointerContractChecked, func(e *gungnir.Event) {
			e.Move, e.Evidence, e.Verdict = "repos/api", "oasdiff", "pass"
		}, []string{`"event":"pointer_contract_checked"`, `"ygg.pointer.move":"repos/api"`, `"ygg.pointer.evidence":"oasdiff"`, `"ygg.verdict":"pass"`}},
		{gungnir.EventDepsChecked, func(e *gungnir.Event) {
			e.Realm, e.Verdict, e.Findings = "helheim-go", "fail", 2
		}, []string{`"event":"deps_checked"`, `"ygg.realm.name":"helheim-go"`, `"ygg.verdict":"fail"`, `"ygg.deps.findings":2`}},
		{gungnir.EventDepsBump, func(e *gungnir.Event) {
			e.Package, e.From, e.To, e.Stage, e.Verdict = "vite", "7.1.2", "7.1.9", "canary", "fail"
		}, []string{`"event":"deps_bump"`, `"ygg.deps.package":"vite"`, `"ygg.deps.from":"7.1.2"`, `"ygg.deps.to":"7.1.9"`, `"ygg.deps.stage":"canary"`, `"ygg.verdict":"fail"`}},
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

func TestAZeroRewardIsStillWrittenAndABadGradeFieldIsRefused(t *testing.T) {
	zero := 0.0
	e := event(gungnir.EventGradeFinished)
	e.Task, e.Reward, e.FailToPass = "client-gallery-lite", &zero, "0/4"
	line, _ := json.Marshal(e)
	if !strings.Contains(string(line), `"ygg.grade.reward":0`) {
		t.Errorf("a reward of 0 was dropped:\n%s", line)
	}
	if err := ValidateEvent(line); err != nil {
		t.Errorf("ValidateEvent() = %v", err)
	}
	for name, bad := range map[string]string{
		"a reward over 1":          strings.Replace(string(line), `"ygg.grade.reward":0`, `"ygg.grade.reward":1.5`, 1),
		"a negative reward":        strings.Replace(string(line), `"ygg.grade.reward":0`, `"ygg.grade.reward":-0.1`, 1),
		"a tally that is no tally": strings.Replace(string(line), `"0/4"`, `"all"`, 1),
		"an unknown reason":        strings.Replace(strings.Replace(string(line), "grade_finished", "grade_refused", 1), `"ygg.grade.fail_to_pass":"0/4"`, `"ygg.grade.reason":"tired"`, 1),
		"an unknown evidence":      `{"schema":"ygg.ledger/v1","seq":1,"time":"2026-10-15T09:00:00Z","ygg.run.id":"20261015-090000-a1b2c3","event":"pointer_contract_checked","ygg.pointer.evidence":"guess","prev":"` + zeros + `"}`,
		"an unknown stage":         `{"schema":"ygg.ledger/v1","seq":1,"time":"2026-10-15T09:00:00Z","ygg.run.id":"20261015-090000-a1b2c3","event":"deps_bump","ygg.deps.stage":"yolo","prev":"` + zeros + `"}`,
		"a verdict out of the set": `{"schema":"ygg.ledger/v1","seq":1,"time":"2026-10-15T09:00:00Z","ygg.run.id":"20261015-090000-a1b2c3","event":"deps_checked","ygg.verdict":"escalate","prev":"` + zeros + `"}`,
		"a short brief hash":       `{"schema":"ygg.ledger/v1","seq":1,"time":"2026-10-15T09:00:00Z","ygg.run.id":"20261015-090000-a1b2c3","event":"grade_started","ygg.grade.brief_sha256":"abc","prev":"` + zeros + `"}`,
	} {
		if err := ValidateEvent([]byte(bad)); err == nil {
			t.Errorf("%s: ValidateEvent() = nil", name)
		}
	}
}
```

Write `schema/graph_grade_test.go`:

```go
package schema

import (
	"strings"
	"testing"
)

const gradeGraph = `
name: graded
version: 1.0.0
nodes:
  - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md, scratch: true }
  - { id: build, kind: foreach, over: tasks, nodes: [ { id: impl, kind: loop, realm: leaf, role: implementer } ] }
  - { id: score, kind: grade }
`

func TestAGradeNodeEndsTheGraph(t *testing.T) {
	g, err := ParseGraph("graph.yaml", []byte(gradeGraph))
	if err != nil {
		t.Fatalf("ParseGraph() = %v", err)
	}
	if n := g.Nodes[2]; n.Kind != KindGrade || n.ID != "score" {
		t.Errorf("the last node = %+v, want the grade node", n)
	}
}

func TestAGradeNodeThatCouldRunBesideASandboxIsRefused(t *testing.T) {
	bad := map[string]struct{ graph, want string }{
		"a node after it": {gradeGraph + "  - { id: late, kind: agent, role: planner, prompt: prompts/late.md, scratch: true }\n", "last node"},
		"two of them":     {strings.Replace(gradeGraph, "  - { id: score, kind: grade }\n", "  - { id: score, kind: grade }\n  - { id: again, kind: grade }\n", 1), "last node"},
		"in a foreach":    {strings.Replace(gradeGraph, "{ id: impl, kind: loop, realm: leaf, role: implementer }", "{ id: g, kind: grade }", 1), "kind"},
		"with a field":    {strings.Replace(gradeGraph, "{ id: score, kind: grade }", "{ id: score, kind: grade, repo: repos/web }", 1), "repo"},
		"with a command":  {strings.Replace(gradeGraph, "{ id: score, kind: grade }", "{ id: score, kind: grade, run: [sh] }", 1), "run"},
	}
	for name, c := range bad {
		_, err := ParseGraph("graph.yaml", []byte(c.graph))
		if err == nil {
			t.Errorf("%s: ParseGraph() = nil, want an error", name)
		} else if !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: ParseGraph() = %v, want it to mention %q", name, err, c.want)
		}
	}
}
```

Write `schema/factory_grader_test.go`:

```go
package schema

import (
	"strings"
	"testing"
	"time"
)

const graderBlock = "grader:\n  tasks_dir: /home/op/mimir\n  suite_dir: /home/op/suites\n  timeout: 30m\n  memory: 4g\n  cpus: 4\n"

func TestFactoryNamesTheGrader(t *testing.T) {
	f, err := ParseFactory("factory.yaml", []byte(factoryHead+graderBlock))
	if err != nil {
		t.Fatalf("ParseFactory() = %v", err)
	}
	g := f.Grader
	if g == nil || g.TasksDir != "/home/op/mimir" || g.SuiteDir != "/home/op/suites" || time.Duration(g.Timeout) != 30*time.Minute || g.Memory != "4g" || g.CPUs != 4 {
		t.Errorf("Grader = %+v", g)
	}
	if f, err := ParseFactory("factory.yaml", []byte(factoryHead)); err != nil || f.Grader != nil {
		t.Errorf("a config with no grader = %+v, %v", f, err)
	}
}

func TestTheGraderBlockIsRefusedWhenItIsNotExact(t *testing.T) {
	cases := map[string]struct{ yaml, want string }{
		"a relative tasks folder":     {strings.Replace(graderBlock, "/home/op/mimir", "mimir", 1), "tasks_dir"},
		"a relative suite folder":     {strings.Replace(graderBlock, "/home/op/suites", "suites", 1), "suite_dir"},
		"a folder that isn't clean":   {strings.Replace(graderBlock, "/home/op/suites", "/home/op/../op/suites", 1), "suite_dir"},
		"the root as tasks folder":    {strings.Replace(graderBlock, "/home/op/mimir", "/", 1), "tasks_dir"},
		"one folder for both":         {strings.Replace(graderBlock, "/home/op/suites", "/home/op/mimir", 1), "grader"},
		"the suites inside the tasks": {strings.Replace(graderBlock, "/home/op/suites", "/home/op/mimir/suites", 1), "grader"},
		"the tasks inside the suites": {strings.Replace(graderBlock, "/home/op/mimir", "/home/op/suites/tasks", 1), "grader"},
		"a timeout of zero":           {strings.Replace(graderBlock, "30m", "0s", 1), "timeout"},
		"a negative timeout":          {strings.Replace(graderBlock, "30m", "-5m", 1), "timeout"},
		"a timeout with no unit":      {strings.Replace(graderBlock, "30m", "30", 1), "timeout"},
		"no timeout":                  {strings.Replace(graderBlock, "  timeout: 30m\n", "", 1), "timeout"},
		"no memory":                   {strings.Replace(graderBlock, "  memory: 4g\n", "", 1), "memory"},
		"a memory with no unit":       {strings.Replace(graderBlock, "4g", "4", 1), "memory"},
		"no cpus":                     {strings.Replace(graderBlock, "  cpus: 4\n", "", 1), "cpus"},
		"zero cpus":                   {strings.Replace(graderBlock, "cpus: 4", "cpus: 0", 1), "cpus"},
		"no suite folder":             {strings.Replace(graderBlock, "  suite_dir: /home/op/suites\n", "", 1), "suite_dir"},
		"an unknown field":            {graderBlock + "  network: true\n", "network"},
	}
	for name, c := range cases {
		_, err := ParseFactory("factory.yaml", []byte(factoryHead+c.yaml))
		if err == nil {
			t.Errorf("%s: ParseFactory() = nil error", name)
		} else if !strings.Contains(err.Error(), c.want) || strings.Contains(err.Error(), "no complete budget caps") {
			t.Errorf("%s: ParseFactory() = %v, want an error naming %q", name, err, c.want)
		}
	}
}
```

- [ ] **Step 2:** run the tests. Expect a build failure, first like this:

```bash
go test ./schema . 2>&1 | head -6
```

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/event_grade_test.go:19:12: undefined: gungnir.EventGradeStarted
schema/event_grade_test.go:20:14: e.Suite undefined (type *gungnir.Event has no field or method Suite)
schema/event_grade_test.go:20:23: e.BriefSHA256 undefined (type *gungnir.Event has no field or method BriefSHA256)
schema/event_grade_test.go:20:38: e.Image undefined (type *gungnir.Event has no field or method Image)
schema/event_grade_test.go:22:12: undefined: gungnir.EventGradeFinished
```

- [ ] **Step 3:** write the code. First the two new schemas, the score types and the parsers.

Write `score.go`:

```go
package gungnir

import (
	"errors"
	"fmt"
	"math"
	"regexp"
	"slices"
	"time"
)

// The schema names of the two files grading reads and writes (spec §11, change benchmark-split).
const (
	ScoreSchema = "ygg.score/v1" // <run>/score.json, which Odin writes
	SuiteSchema = "ygg.suite/v1" // tests/manifest.json, which the hidden suite holds
)

// GradeReason is why grading was refused before anything was built (the grade_refused event).
type GradeReason string

const (
	GradeRetired      GradeReason = "retired"       // the suite version of the task is retired
	GradeMissingSuite GradeReason = "missing_suite" // the store holds no suite for the task and its suite version
	GradeBriefChanged GradeReason = "brief_changed" // instruction.md no longer hashes to metadata.brief_sha256
	GradeBadManifest  GradeReason = "bad_manifest"  // the suite's manifest and its results do not agree
	GradeBadTask      GradeReason = "bad_task"      // task.toml is missing a field or holds a wrong one
)

// ScenarioKind says what a scenario of a suite proves.
type ScenarioKind string

const (
	FailToPass ScenarioKind = "fail-to-pass" // the product must make it pass; the reward counts these only
	PassToPass ScenarioKind = "pass-to-pass" // it passes on the empty product too; reported, never in the reward
)

// ScenarioStatus is what happened to a scenario in a grading run.
type ScenarioStatus string

const (
	ScenarioPassed  ScenarioStatus = "passed"
	ScenarioFailed  ScenarioStatus = "failed"
	ScenarioSkipped ScenarioStatus = "skipped"
)

var (
	categoryName = regexp.MustCompile(`^[a-z][a-z0-9-]*$`)
	suiteName    = regexp.MustCompile(`^[a-z0-9][a-z0-9._-]*$`)
	sha256Hex    = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// MaxScenarioID is the most characters a scenario id (a Playwright spec title) may have.
const MaxScenarioID = 300

// Scenario is one line of a suite's manifest. Its id is the title of one Playwright spec.
type Scenario struct {
	ID       string       `json:"id"`
	Category string       `json:"category"`
	Kind     ScenarioKind `json:"kind"`
}

func (s Scenario) validate() error {
	var errs []error
	if s.ID == "" || len(s.ID) > MaxScenarioID {
		errs = append(errs, fmt.Errorf("scenario id %q must have 1 to %d characters", s.ID, MaxScenarioID))
	}
	if !categoryName.MatchString(s.Category) {
		errs = append(errs, fmt.Errorf("scenario %q: category %q must be lower case words joined by dashes", s.ID, s.Category))
	}
	if s.Kind != FailToPass && s.Kind != PassToPass {
		errs = append(errs, fmt.Errorf("scenario %q: kind %q is not fail-to-pass or pass-to-pass", s.ID, s.Kind))
	}
	return errors.Join(errs...)
}

// Suite is tests/manifest.json of a hidden suite: every scenario it holds, by id, category and kind.
type Suite struct {
	Schema    string     `json:"schema"`
	Suite     string     `json:"suite"`
	Scenarios []Scenario `json:"scenarios"`
}

// Validate refuses a manifest without scenarios, with a scenario id used twice or with a malformed
// field. A manifest that can't be read exactly is an error, never a pass (spec §4.6).
func (s Suite) Validate() error {
	var errs []error
	if s.Schema != SuiteSchema {
		errs = append(errs, fmt.Errorf("schema %q is not %s", s.Schema, SuiteSchema))
	}
	if !suiteName.MatchString(s.Suite) {
		errs = append(errs, fmt.Errorf("suite %q is not a suite version", s.Suite))
	}
	if len(s.Scenarios) == 0 {
		errs = append(errs, errors.New("a suite needs at least one scenario"))
	}
	seen := map[string]bool{}
	for _, sc := range s.Scenarios {
		if err := sc.validate(); err != nil {
			errs = append(errs, err)
		}
		if seen[sc.ID] {
			errs = append(errs, fmt.Errorf("scenario id %q is used twice", sc.ID))
		}
		seen[sc.ID] = true
	}
	return errors.Join(errs...)
}

// ScoredScenario is a scenario with its result.
type ScoredScenario struct {
	ID       string         `json:"id"`
	Category string         `json:"category"`
	Kind     ScenarioKind   `json:"kind"`
	Status   ScenarioStatus `json:"status"`
}

// Tally counts passed scenarios out of a total.
type Tally struct {
	Passed int `json:"passed"`
	Total  int `json:"total"`
}

// CategoryScore is one category of the reward: its fail-to-pass scenarios and the weight of the category.
type CategoryScore struct {
	Passed int     `json:"passed"`
	Total  int     `json:"total"`
	Weight float64 `json:"weight"`
}

// Score is score.json (spec §11): the result of grading one run. Odin writes it to the run folder and
// the ledger only: never to a leaf, and never where an agent can read it.
type Score struct {
	Schema      string                   `json:"schema"`
	Run         string                   `json:"run"`
	Task        string                   `json:"task"`
	TaskVersion string                   `json:"task_version"`
	BriefSHA256 string                   `json:"brief_sha256"`
	Suite       string                   `json:"suite"`
	Started     time.Time                `json:"started"`
	Finished    time.Time                `json:"finished"`
	Scenarios   []ScoredScenario         `json:"scenarios"`
	FailToPass  Tally                    `json:"fail_to_pass"`
	PassToPass  Tally                    `json:"pass_to_pass"`
	Categories  map[string]CategoryScore `json:"categories"`
	Reward      float64                  `json:"reward"`
}

// weightEpsilon is how far the weights may be from a sum of 1, and a reward from its recomputed value.
const weightEpsilon = 1e-9

// RewardOf returns the sum, over the categories, of weight * passed / total. A category with no
// scenarios counts 0.
func RewardOf(cats map[string]CategoryScore) float64 {
	var r float64
	for _, c := range cats {
		if c.Total > 0 {
			r += c.Weight * float64(c.Passed) / float64(c.Total)
		}
	}
	return r
}

// Validate refuses a score that does not add up: a field that is malformed, a tally or a category that
// does not match the scenarios, weights that do not sum to 1, or a reward that is not the one the
// categories give. Only fail-to-pass scenarios count in the categories and the reward; pass-to-pass is
// reported on its own.
func (s Score) Validate() error {
	var errs []error
	add := func(format string, a ...any) { errs = append(errs, fmt.Errorf(format, a...)) }
	if s.Schema != ScoreSchema {
		add("schema %q is not %s", s.Schema, ScoreSchema)
	}
	if s.Run == "" || s.Task == "" || s.Suite == "" {
		add("a score needs a run, a task and a suite")
	}
	if !ValidVersion(s.TaskVersion) {
		add("task_version %q is not of the form 1.2.3", s.TaskVersion)
	}
	if !sha256Hex.MatchString(s.BriefSHA256) {
		add("brief_sha256 %q is not a SHA-256 in hex", s.BriefSHA256)
	}
	if s.Started.IsZero() || s.Finished.Before(s.Started) {
		add("finished must not be before started, and both are needed")
	}
	var f2p, p2p Tally
	cats := map[string]Tally{}
	seen := map[string]bool{}
	for _, sc := range s.Scenarios {
		if err := (Scenario{ID: sc.ID, Category: sc.Category, Kind: sc.Kind}).validate(); err != nil {
			errs = append(errs, err)
		}
		if seen[sc.ID] {
			add("scenario id %q is used twice", sc.ID)
		}
		seen[sc.ID] = true
		if !slices.Contains([]ScenarioStatus{ScenarioPassed, ScenarioFailed, ScenarioSkipped}, sc.Status) {
			add("scenario %q: status %q is not passed, failed or skipped", sc.ID, sc.Status)
		}
		t := &p2p
		if sc.Kind == FailToPass {
			t = &f2p
			c := cats[sc.Category]
			c.Total++
			if sc.Status == ScenarioPassed {
				c.Passed++
			}
			cats[sc.Category] = c
		}
		t.Total++
		if sc.Status == ScenarioPassed {
			t.Passed++
		}
	}
	if s.FailToPass != f2p {
		add("fail_to_pass is %d/%d, the scenarios give %d/%d", s.FailToPass.Passed, s.FailToPass.Total, f2p.Passed, f2p.Total)
	}
	if s.PassToPass != p2p {
		add("pass_to_pass is %d/%d, the scenarios give %d/%d", s.PassToPass.Passed, s.PassToPass.Total, p2p.Passed, p2p.Total)
	}
	var sum float64
	for name, c := range s.Categories {
		sum += c.Weight
		if c.Weight < 0 || c.Weight > 1 {
			add("category %q: weight %v is not between 0 and 1", name, c.Weight)
		}
		if got := cats[name]; (Tally{c.Passed, c.Total}) != got {
			add("category %q is %d/%d, its fail-to-pass scenarios give %d/%d", name, c.Passed, c.Total, got.Passed, got.Total)
		}
	}
	for name := range cats {
		if _, ok := s.Categories[name]; !ok {
			add("category %q has fail-to-pass scenarios and no entry in categories", name)
		}
	}
	if len(s.Categories) == 0 || math.Abs(sum-1) > weightEpsilon {
		add("the weights of the categories sum to %v, not 1", sum)
	}
	if want := RewardOf(s.Categories); math.Abs(s.Reward-want) > weightEpsilon {
		add("reward is %v, the categories give %v", s.Reward, want)
	}
	return errors.Join(errs...)
}
```

Write `schema/score.go`:

```go
package schema

import (
	"bytes"
	"encoding/json"
	"fmt"

	"github.com/ouroboric-dev/gungnir"
	"github.com/santhosh-tekuri/jsonschema/v6"
)

// ParseSuite parses a hidden suite's tests/manifest.json. A manifest that fails the schema or Validate
// is an error, never an empty suite: a scenario nobody can read must not count as a pass (spec §4.6).
func ParseSuite(data []byte) (gungnir.Suite, error) {
	var s gungnir.Suite
	if err := parseJSON("manifest", "suite.schema.json", data, &s); err != nil {
		return gungnir.Suite{}, err
	}
	if err := s.Validate(); err != nil {
		return gungnir.Suite{}, fmt.Errorf("manifest: %w", err)
	}
	return s, nil
}

// ParseScore parses a run's score.json, and refuses one whose tallies, categories, weights or reward do
// not add up.
func ParseScore(data []byte) (gungnir.Score, error) {
	var s gungnir.Score
	if err := parseJSON("score", "score.schema.json", data, &s); err != nil {
		return gungnir.Score{}, err
	}
	if err := s.Validate(); err != nil {
		return gungnir.Score{}, fmt.Errorf("score: %w", err)
	}
	return s, nil
}

// parseJSON validates one JSON document against the named schema, then decodes it into v without
// unknown fields and without a second document.
func parseJSON(what, schemaName string, data []byte, v any) error {
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("%s: %w", what, err)
	}
	if err := validate(what, schemaName, doc); err != nil {
		return err
	}
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		return fmt.Errorf("%s: %w", what, err)
	}
	return nil
}
```

Write `schema/score.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/score.schema.json",
  "title": "a run's score.json",
  "description": "The result of grading one run: every scenario with its status, the fail-to-pass and pass-to-pass tallies, the categories with their weights, and the reward. Odin writes it to the run folder and the ledger only, never to a leaf (spec §11, change benchmark-split).",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "run", "task", "task_version", "brief_sha256", "suite", "started", "finished",
               "scenarios", "fail_to_pass", "pass_to_pass", "categories", "reward"],
  "properties": {
    "schema": { "const": "ygg.score/v1" },
    "run": { "type": "string", "minLength": 1 },
    "task": { "type": "string", "minLength": 1 },
    "task_version": { "type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$" },
    "brief_sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
    "suite": { "type": "string", "pattern": "^[a-z0-9][a-z0-9._-]*$" },
    "started": { "type": "string", "minLength": 20 },
    "finished": { "type": "string", "minLength": 20 },
    "scenarios": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["id", "category", "kind", "status"],
        "properties": {
          "id": { "type": "string", "minLength": 1, "maxLength": 300 },
          "category": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
          "kind": { "enum": ["fail-to-pass", "pass-to-pass"] },
          "status": { "enum": ["passed", "failed", "skipped"] }
        }
      }
    },
    "fail_to_pass": { "$ref": "#/$defs/tally" },
    "pass_to_pass": { "$ref": "#/$defs/tally" },
    "categories": {
      "type": "object",
      "propertyNames": { "pattern": "^[a-z][a-z0-9-]*$" },
      "additionalProperties": {
        "type": "object",
        "additionalProperties": false,
        "required": ["passed", "total", "weight"],
        "properties": {
          "passed": { "type": "integer", "minimum": 0 },
          "total": { "type": "integer", "minimum": 0 },
          "weight": { "type": "number", "minimum": 0, "maximum": 1 }
        }
      }
    },
    "reward": { "type": "number", "minimum": 0, "maximum": 1 }
  },
  "$defs": {
    "tally": {
      "type": "object",
      "additionalProperties": false,
      "required": ["passed", "total"],
      "properties": {
        "passed": { "type": "integer", "minimum": 0 },
        "total": { "type": "integer", "minimum": 0 }
      }
    }
  }
}
```

Write `schema/suite.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/suite.schema.json",
  "title": "a hidden suite's tests/manifest.json",
  "description": "Every scenario of a hidden suite, by id (the title of one Playwright spec), category and kind. Odin joins it with the suite's results to make score.json (spec §11, change benchmark-split).",
  "type": "object",
  "additionalProperties": false,
  "required": ["schema", "suite", "scenarios"],
  "properties": {
    "schema": { "const": "ygg.suite/v1" },
    "suite": { "type": "string", "pattern": "^[a-z0-9][a-z0-9._-]*$" },
    "scenarios": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["id", "category", "kind"],
        "properties": {
          "id": { "type": "string", "minLength": 1, "maxLength": 300 },
          "category": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
          "kind": { "enum": ["fail-to-pass", "pass-to-pass"] }
        }
      }
    }
  }
}
```

Then the events. Apply to `event.go` (`gofmt` aligns the constant block):

```diff
diff --git a/event.go b/event.go
index bd3edb7..8e895db 100644
--- a/event.go
+++ b/event.go
@@ -48,6 +48,14 @@ const (
 	EventTaskBlocked   EventName = "task_blocked"   // an unattended run gave a task up and went on with the rest (spec §7.3)
 
 	EventConformanceChecked EventName = "conformance_checked" // the design-conformance reviewer's verdict on a spec was read (spec §4.2)
+
+	EventGradeStarted           EventName = "grade_started"            // the hidden suite began to run against a run's /app (spec §11)
+	EventGradeFinished          EventName = "grade_finished"           // the suite ended and score.json was written
+	EventGradeRefused           EventName = "grade_refused"            // grading was refused before anything was built, with a reason (GradeReason)
+	EventRoutingIndexBuilt      EventName = "routing_index_built"      // a wiring or impact index was generated
+	EventPointerContractChecked EventName = "pointer_contract_checked" // the pointer-contract gate judged a pointer move
+	EventDepsChecked            EventName = "deps_checked"             // a realm's dependency policy was checked
+	EventDepsBump               EventName = "deps_bump"                // ygg deps bump ran a stage on a product
 )
 
 // Events returns every event name, in the order above.
@@ -59,7 +67,8 @@ func Events() []EventName {
 		EventModeChanged, EventConfigChanged, EventRepoCreated, EventSandboxUp, EventSandboxDown,
 		EventRetry, EventRunPaused, EventFindingRaised, EventFindingClosed, EventFindingReopened,
 		EventRealmLoaded, EventDocsPublished, EventTasksReady, EventNodeReturned, EventTaskStarted, EventTaskDone,
-		EventTaskBlocked, EventConformanceChecked}
+		EventTaskBlocked, EventConformanceChecked, EventGradeStarted, EventGradeFinished, EventGradeRefused,
+		EventRoutingIndexBuilt, EventPointerContractChecked, EventDepsChecked, EventDepsBump}
 }
 
 // Event is one ledger line. Fields follow OpenTelemetry's GenAI attribute names (gen_ai.*) where
@@ -106,6 +115,34 @@ type Event struct {
 	FindingAttempts int `json:"ygg.finding.attempts,omitempty"` // finding_closed: the loop attempts the finding took to close
 	FindingReopens  int `json:"ygg.finding.reopens,omitempty"`  // finding_closed, finding_reopened: how often it came back
 
+	// grade_started, grade_finished, grade_refused (Task is the task graded)
+	Suite       string      `json:"ygg.grade.suite,omitempty"`
+	BriefSHA256 string      `json:"ygg.grade.brief_sha256,omitempty"`
+	Image       string      `json:"ygg.grade.image,omitempty"`        // grade_started: the image the suite runs in
+	ScorePath   string      `json:"ygg.grade.score_path,omitempty"`   // grade_finished: where score.json is, in the run folder
+	Reward      *float64    `json:"ygg.grade.reward,omitempty"`       // grade_finished: a pointer, so a reward of 0 is still written
+	FailToPass  string      `json:"ygg.grade.fail_to_pass,omitempty"` // grade_finished: "passed/total"
+	PassToPass  string      `json:"ygg.grade.pass_to_pass,omitempty"`
+	Reason      GradeReason `json:"ygg.grade.reason,omitempty"` // grade_refused: a GradeReason
+
+	// routing_index_built; a count of 0 is left out
+	IndexKind string `json:"ygg.routing.kind,omitempty"` // wiring or impact
+	Edges     int    `json:"ygg.routing.edges,omitempty"`
+	Extracted int    `json:"ygg.routing.extracted,omitempty"`
+	Inferred  int    `json:"ygg.routing.inferred,omitempty"`
+
+	// pointer_contract_checked; Verdict is also deps_checked's and deps_bump's (pass or fail)
+	Move     string `json:"ygg.pointer.move,omitempty"`
+	Evidence string `json:"ygg.pointer.evidence,omitempty"` // extracted, inferred or oasdiff
+	Verdict  string `json:"ygg.verdict,omitempty"`
+
+	// deps_checked (Realm names the realm), deps_bump
+	Findings int    `json:"ygg.deps.findings,omitempty"`
+	Package  string `json:"ygg.deps.package,omitempty"`
+	From     string `json:"ygg.deps.from,omitempty"`
+	To       string `json:"ygg.deps.to,omitempty"`
+	Stage    string `json:"ygg.deps.stage,omitempty"` // canary or rollout
+
 	Prev string `json:"prev"` // hex SHA-256 of the previous line; 64 zeros on the first line
 }
 
```

The ledger schema takes the seven names and the new fields:

```diff
diff --git a/schema/ledger-event.schema.json b/schema/ledger-event.schema.json
index c0d564e..4623914 100644
--- a/schema/ledger-event.schema.json
+++ b/schema/ledger-event.schema.json
@@ -19,7 +19,8 @@
                "budget_warning", "policy_violation", "pointer_moved", "mode_changed", "config_changed",
                "repo_created", "sandbox_up", "sandbox_down", "retry", "run_paused", "finding_raised",
                "finding_closed", "finding_reopened", "realm_loaded", "docs_published", "tasks_ready",
-               "node_returned", "task_started", "task_done", "task_blocked", "conformance_checked"]
+               "node_returned", "task_started", "task_done", "task_blocked", "conformance_checked", "grade_started", "grade_finished",
+               "grade_refused", "routing_index_built", "pointer_contract_checked", "deps_checked", "deps_bump"]
     },
     "ygg.attempt": { "type": "integer", "minimum": 1 },
     "gen_ai.agent.name": { "type": "string" },
@@ -50,6 +51,31 @@
     "ygg.finding.severity": { "enum": ["blocker", "major", "minor"] },
     "ygg.finding.attempts": { "type": "integer", "minimum": 1 },
     "ygg.finding.reopens": { "type": "integer", "minimum": 1 },
+    "ygg.grade.suite": { "type": "string", "pattern": "^[a-z0-9][a-z0-9._-]*$" },
+    "ygg.grade.brief_sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
+    "ygg.grade.image": { "type": "string", "minLength": 1 },
+    "ygg.grade.score_path": { "type": "string", "minLength": 1 },
+    "ygg.grade.reward": { "type": "number", "minimum": 0, "maximum": 1 },
+    "ygg.grade.fail_to_pass": { "$ref": "#/$defs/tally" },
+    "ygg.grade.pass_to_pass": { "$ref": "#/$defs/tally" },
+    "ygg.grade.reason": { "enum": ["retired", "missing_suite", "brief_changed", "bad_manifest", "bad_task"] },
+    "ygg.routing.kind": { "enum": ["wiring", "impact"] },
+    "ygg.routing.edges": { "type": "integer", "minimum": 1 },
+    "ygg.routing.extracted": { "type": "integer", "minimum": 1 },
+    "ygg.routing.inferred": { "type": "integer", "minimum": 1 },
+    "ygg.pointer.move": { "type": "string", "minLength": 1 },
+    "ygg.pointer.evidence": { "enum": ["extracted", "inferred", "oasdiff"] },
+    "ygg.verdict": { "enum": ["pass", "fail", "escalate"] },
+    "ygg.deps.findings": { "type": "integer", "minimum": 1 },
+    "ygg.deps.package": { "type": "string", "minLength": 1 },
+    "ygg.deps.from": { "type": "string", "minLength": 1 },
+    "ygg.deps.to": { "type": "string", "minLength": 1 },
+    "ygg.deps.stage": { "enum": ["canary", "rollout"] },
     "prev": { "type": "string", "pattern": "^[0-9a-f]{64}$" }
-  }
+  },
+  "$defs": {
+    "tally": { "type": "string", "pattern": "^[0-9]+/[0-9]+$" }
+  },
+  "if": { "properties": { "event": { "const": "deps_checked" } }, "required": ["event"] },
+  "then": { "properties": { "ygg.verdict": { "enum": ["pass", "fail"] } } }
 }
```

The `grade` node kind:

```diff
diff --git a/schema/graph.go b/schema/graph.go
index 74c4bb1..a5c2d32 100644
--- a/schema/graph.go
+++ b/schema/graph.go
@@ -33,6 +33,7 @@ const (
 	KindPublish NodeKind = "publish" // Odin copies a scratch agent's output into the project and commits it (spec §3.3 rule 1)
 	KindTasks   NodeKind = "tasks"   // Odin reads the plan's tasks.md, checks every task is ready, and writes features.json (spec §4.2)
 	KindInit    NodeKind = "init"    // Odin creates the leaves the spec names, each from its realm's template (spec §4.2, §4.1)
+	KindGrade   NodeKind = "grade"   // Odin stops every sandbox, exports the project's /app and grades it against the hidden suite; the last node of a graph (spec §11)
 )
 
 // DefaultReturns is how many times a refusal may send a run back into the node named by back_to when the
@@ -155,7 +156,8 @@ func LoadGraph(path string) (*Graph, error) {
 // one foreach body), or else the nearest one before it. A rejection's reason is input for an agent, so
 // it never re-runs an exec node, which would drop it. A loop's attempts default to DefaultAttempts, its
 // reviewers' ids are unique, and a reviewer's session key (the loop's id, a dash and the reviewer's id)
-// never equals a node's id. A foreach node's body is checked as a graph of its own, in which a node
+// never equals a node's id. A grade node is the last node of the graph, because it runs after every
+// sandbox has stopped. A foreach node's body is checked as a graph of its own, in which a node
 // names no repo: the task's leaf is its repo.
 func ParseGraph(file string, data []byte) (*Graph, error) {
 	var g Graph
@@ -166,6 +168,11 @@ func ParseGraph(file string, data []byte) (*Graph, error) {
 	if err := c.scope(g.Nodes, false); err != nil {
 		return nil, err
 	}
+	for i, n := range g.Nodes {
+		if n.Kind == KindGrade && i != len(g.Nodes)-1 {
+			return nil, fmt.Errorf("%s: node %s: a grade node must be the last node of the graph and there is one at most: grading starts only after every sandbox has stopped", file, n.ID)
+		}
+	}
 	for key, loop := range c.keys {
 		if c.seen[key] {
 			return nil, fmt.Errorf("%s: loop %s: a reviewer's session key %q is also a node id", file, loop, key)
diff --git a/schema/graph.schema.json b/schema/graph.schema.json
index 3cfebba..f8dc407 100644
--- a/schema/graph.schema.json
+++ b/schema/graph.schema.json
@@ -39,7 +39,7 @@
     "node": {
       "type": "object",
       "required": ["id", "kind"],
-      "properties": { "kind": { "enum": ["exec", "agent", "gate", "merge", "pointer", "loop", "foreach", "publish", "tasks", "init"] } },
+      "properties": { "kind": { "enum": ["exec", "agent", "gate", "merge", "pointer", "loop", "foreach", "publish", "tasks", "init", "grade"] } },
       "oneOf": [
         {
           "additionalProperties": false,
@@ -161,6 +161,13 @@
           },
           "dependentRequired": { "returns": ["back_to"] }
         },
+        {
+          "additionalProperties": false,
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "grade" }
+          }
+        },
         {
           "additionalProperties": false,
           "required": ["over", "nodes"],
```

The `grader:` block:

```diff
diff --git a/schema/factory.go b/schema/factory.go
index a4725a8..39d9b77 100644
--- a/schema/factory.go
+++ b/schema/factory.go
@@ -20,6 +20,17 @@ type Factory struct {
 	Sandbox *Sandbox                `yaml:"sandbox"` // required when a role runs a real agent (spec §6)
 	Skills  Skills                  `yaml:"skills"`
 	Realms  *Realms                 `yaml:"realms"` // where the realm leaves are, so --realm can name one
+	Grader  *Grader                 `yaml:"grader"` // where the benchmark tasks and the hidden suites are, and the limits of a grading run (spec §11)
+}
+
+// Grader says where grading finds its inputs and how much it may use (spec §11, change benchmark-split).
+// Nothing is defaulted: the operator sets every limit.
+type Grader struct {
+	TasksDir string   `yaml:"tasks_dir"` // a checkout of the task repo (mimir): <dir>/<task id>/{task.toml,instruction.md,environment/}
+	SuiteDir string   `yaml:"suite_dir"` // the store of hidden suites: <dir>/<task id>/<suite>/tests/. It is never mounted into an agent's sandbox
+	Timeout  Duration `yaml:"timeout"`   // the most one grading run's container may run
+	Memory   string   `yaml:"memory"`    // the container's memory limit, such as 4g
+	CPUs     int      `yaml:"cpus"`      // the container's CPUs
 }
 
 // Realms says where the operator keeps the realm leaves: a folder with one checkout of each, such as
@@ -240,6 +251,11 @@ func (f *Factory) checkSandbox() error {
 	if r := f.Realms; r != nil && (!filepath.IsAbs(r.Dir) || filepath.Clean(r.Dir) != r.Dir || r.Dir == "/") {
 		return fmt.Errorf("realms.dir %q must be a clean, absolute path, and not the root", r.Dir)
 	}
+	if g := f.Grader; g != nil {
+		if err := g.check(); err != nil {
+			return err
+		}
+	}
 	if f.Sandbox == nil {
 		for _, r := range sortedKeys(f.Roles) {
 			if agent := f.Roles[r].Agent; agent != "scripted" {
@@ -266,6 +282,23 @@ func (f *Factory) checkSandbox() error {
 	return nil
 }
 
+// check refuses a grader with a folder that is not clean and absolute, one folder inside the other (a
+// hidden suite inside a folder an agent may be given, or the reverse), or a limit that is not positive.
+func (g *Grader) check() error {
+	for _, d := range []struct{ name, path string }{{"tasks_dir", g.TasksDir}, {"suite_dir", g.SuiteDir}} {
+		if !filepath.IsAbs(d.path) || filepath.Clean(d.path) != d.path || d.path == "/" {
+			return fmt.Errorf("grader.%s %q must be a clean, absolute path, and not the root", d.name, d.path)
+		}
+	}
+	if g.TasksDir == g.SuiteDir || strings.HasPrefix(g.TasksDir, g.SuiteDir+"/") || strings.HasPrefix(g.SuiteDir, g.TasksDir+"/") {
+		return fmt.Errorf("grader: tasks_dir %q and suite_dir %q must be two folders, neither inside the other", g.TasksDir, g.SuiteDir)
+	}
+	if g.Timeout <= 0 {
+		return fmt.Errorf("grader.timeout must be positive")
+	}
+	return nil
+}
+
 func sortedKeys[K ~string, V any](m map[K]V) []K {
 	keys := make([]K, 0, len(m))
 	for k := range m {
diff --git a/schema/factory.schema.json b/schema/factory.schema.json
index c3e3bcc..3fc23a4 100644
--- a/schema/factory.schema.json
+++ b/schema/factory.schema.json
@@ -58,6 +58,18 @@
       "required": ["dir"],
       "properties": { "dir": { "type": "string", "minLength": 1, "description": "an absolute folder with one checkout of each realm leaf, so --realm midgard-react finds <dir>/midgard-react" } }
     },
+    "grader": {
+      "type": "object",
+      "additionalProperties": false,
+      "required": ["tasks_dir", "suite_dir", "timeout", "memory", "cpus"],
+      "properties": {
+        "tasks_dir": { "type": "string", "minLength": 1, "description": "an absolute folder: a checkout of the task repo, <dir>/<task id>/{task.toml,instruction.md,environment/}" },
+        "suite_dir": { "type": "string", "minLength": 1, "description": "an absolute folder: the store of hidden suites, <dir>/<task id>/<suite>/tests/; never mounted into an agent's sandbox" },
+        "timeout": { "type": "string", "pattern": "^[1-9][0-9]*(ms|s|m|h)$" },
+        "memory": { "type": "string", "pattern": "^[1-9][0-9]*[mg]$", "description": "the container's memory limit, such as 4g" },
+        "cpus": { "type": "integer", "minimum": 1, "maximum": 256 }
+      }
+    },
     "skills": {
       "type": "object",
       "additionalProperties": false,
```

- [ ] **Step 4:** run the named test, then the whole repo the way CI does.

```bash
gofmt -l .
go vet ./...
go test -race -count=1 -v -run 'TestAScoreRoundTripsThroughJSON|TestPassToPassNeverChangesTheReward|TestAScoreThatDoesNotAddUpIsRefused|TestASuiteManifestIsRefusedWhenItIsAmbiguous|TestParseSuiteReadsAManifestExactly|TestParseScoreReadsWhatMarshalWrote|TestAGradeNodeEndsTheGraph|TestAGradeNodeThatCouldRunBesideASandboxIsRefused|TestFactoryNamesTheGrader|TestTheGraderBlockIsRefusedWhenItIsNotExact|TestTheLedgerRecordsGradingRoutingAndDependencyChecks|TestAZeroRewardIsStillWrittenAndABadGradeFieldIsRefused|TestLedgerEventSchema' ./... 2>&1 | grep -E "^(--- |ok|FAIL|PASS)"
GOWORK=off go test -race -count=1 ./...
```

```output
--- PASS: TestAScoreRoundTripsThroughJSON (0.00s)
--- PASS: TestPassToPassNeverChangesTheReward (0.00s)
--- PASS: TestAScoreThatDoesNotAddUpIsRefused (0.00s)
--- PASS: TestASuiteManifestIsRefusedWhenItIsAmbiguous (0.00s)
PASS
ok  	github.com/ouroboric-dev/gungnir	1.027s
--- PASS: TestTheLedgerRecordsGradingRoutingAndDependencyChecks (0.05s)
--- PASS: TestAZeroRewardIsStillWrittenAndABadGradeFieldIsRefused (0.05s)
--- PASS: TestLedgerEventSchema (0.28s)
--- PASS: TestFactoryNamesTheGrader (0.01s)
--- PASS: TestTheGraderBlockIsRefusedWhenItIsNotExact (0.09s)
--- PASS: TestAGradeNodeEndsTheGraph (0.01s)
--- PASS: TestAGradeNodeThatCouldRunBesideASandboxIsRefused (0.05s)
--- PASS: TestParseSuiteReadsAManifestExactly (0.02s)
--- PASS: TestParseScoreReadsWhatMarshalWrote (0.03s)
PASS
ok  	github.com/ouroboric-dev/gungnir/schema	1.652s
ok  	github.com/ouroboric-dev/gungnir	1.020s
ok  	github.com/ouroboric-dev/gungnir/schema	4.440s
```

`gofmt -l .` and `go vet ./...` print nothing. The times differ from run to run.

- [ ] **Step 5:** commit (see "How each task lands"):

```bash
git add event.go score.go score_test.go schema/event_grade_test.go schema/factory.go schema/factory.schema.json \
  schema/factory_grader_test.go schema/graph.go schema/graph.schema.json schema/graph_grade_test.go \
  schema/ledger-event.schema.json schema/score.go schema/score.schema.json schema/score_test.go schema/suite.schema.json
git commit -m "Schema and ledger events for the grader, routing and dependency checks (v0-T245)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**Evidence (v0-T245):** built and run in the reference workspace on 2026-10-18 as commit `74d6c89` on `main` of `gungnir` (not pushed). Tests first: the build failed as in step 2, then every test passed. `go vet ./...` and `gofmt -l .` print nothing. `GOWORK=off go test -race -count=1 ./...`: `ok` for `gungnir` and `gungnir/schema`. `reuse lint` (5.0.2) prints nothing. Not run: the documentation of these types (v0-T264) and any use of them by Odin (v0-T247 to v0-T250).

---

### Task v0-T246: `Grade`: build the task image, run the hidden suite in an isolated container, labelled, with no agent mount

Gleipnir's task of Phase 5c. Branch `grader/run` from `main` in `gleipnir`, before step 1. Needs v0-T245 merged and pinned only for the types Odin uses; the code below imports nothing new from `gungnir` and builds with the pin of Phase 5b. Odin (v0-T249) hands `Grade` four host folders and gets back an exit status. The score is Odin's: `Grade` reads no result.

**Files (in `gleipnir`):**

- Create: `sandbox/grade.go`, `sandbox/grade_test.go`, `sandbox/integration_grade_test.go`
- Modify: `sandbox/stackbuild.go` (the pull-and-build tail becomes `pullAndBuild`, used by `BuildStack` and `BuildGrader`), `sandbox/driver_test.go` (the fake `podman` answers `run` and `rm`)

**Interfaces:**

- Produces: `sandbox.GraderImage(task, environment) (ref string, err error)`: `localhost/ygg-grader-<task>:<12 hex>`, the hash of every file of the task's environment folder (path, executable bit, bytes). It refuses a folder with no `Containerfile` or `Dockerfile`, a file that is not a regular file (a symlink), and more than `schema.MaxContextFiles` files or `schema.MaxContextBytes` bytes.
- Produces: `(*Driver).BuildGrader(ctx, task, environment) (ref string, built bool, err error)`: builds the image from the `Containerfile` or else the `Dockerfile` of the folder, with the rules of `BuildStack`: every base pinned by digest, no `ADD`, no `COPY --from` an image. The image exists already: nothing is built. The image never holds the hidden suite.
- Produces: `sandbox.GradeSpec{Run, Task, Environment, App, Tests, Logs string; Timeout time.Duration; Memory string; CPUs int; Env map[string]string}` and `(*Driver).Grade(ctx, GradeSpec) (GradeResult{Image, ExitCode, Log}, error)`. `Grade` runs `bash /tests/test.sh` in a container of the image with: `--network none` (loopback only), `/app` the `App` folder (read-write; Odin passes a copy it throws away), `/tests` the `Tests` folder (`ro=true`), `/logs/verifier` the `Logs` folder (must be empty), the label `ygg.grader=<run>`, the name `ygg-grader-<run>-<task>`, `--memory`, `--cpus`, `--env` for each `Env` entry. There is no other mount, and no other flag that gives the container more.
- Produces: `ErrGradeTimeout` (the container ran longer than `Timeout`). `Grade` returns it with the result, and removes the container.
- Produces: `(*Driver).RemoveGrader(ctx, container)`, `(*Driver).GraderLeftovers(ctx) ([]GraderLeftover{Run, Container, State}, error)` and `sandbox.LabelGrader` (`ygg.grader`). `ygg doctor` (v0-T250) finds a leftover with `GraderLeftovers` and removes it with `RemoveGrader`.
- `Grade` refuses before it calls the engine to run: a task or run name that is not safe in a container name; a path that is relative, not clean, the root or has a comma, a colon or a newline in it; a path that is not a folder; one of the three folders inside another or the same; a `Tests` folder with no `test.sh`; a `Logs` folder that is not empty (a result left in it would pass for this run's); a timeout of zero; a memory limit that is not `4g` or `512m`; negative CPUs; an `Env` name not in capitals or a value with a newline; a folder the engine can't see (`sandbox.mounts`).
- A `podman run` that exits 125, 126 or 127 is an error, not a result: those are podman's own failures (and a limit the engine can't apply). Any other exit status is `GradeResult.ExitCode`, and `results.json` is the truth.

**Facts found on a real engine (read before v0-H16):**

- The rootless engine of this workspace (Podman on WSL, cgroup v2 with no delegation) cannot apply `--memory` or `--cpus`: `podman run` exits 127 with `crun: open memory.max for writing: No such file or directory`. `Grade` passes the limits the factory gives it, so on such an engine every grading run fails with the error above, not with a wrong score. `GradeSpec` takes an empty `Memory` and `CPUs` 0 as "no limit", so a test can run without them. The factory's `grader:` block asks for both (v0-T245). Decision for the founder: on this engine either delegate the cgroup controllers to the user, or accept grading without limits. The plan does not choose.
- Registry credentials: a pull through the host's own Podman config failed on a credential helper of the host. The driver's pulls use the isolated, empty auth, and worked.
- The mimir task `client-gallery-lite` has a `Dockerfile`, not a `Containerfile`. `BuildGrader` takes either.
- Not tried: the Dockerfile of `client-gallery-lite` itself (Playwright image, `npm ci`), and Chromium in the container under the grader's flags. A rootless engine maps the container's root to the operator's user; whether `/app` is writable for the unprivileged `app` user of that image is v0-H16's to find.

**Acceptance criteria:**

- [ ] `Grade` calls the engine in this order: pull of each base, build, run, remove. The `run` line has `--network none`, the label, the name, the limits, the `--env` entries and ends with `<image> bash /tests/test.sh`.
- [ ] The `run` line has exactly three `--mount` options, with the destinations `/app` (rw), `/tests` (ro) and `/logs/verifier` (rw), each from the engine's view of the given host folder, and no `-v`, `--volume`, `--tmpfs`, `--device`, `--privileged`, `--userns`, `--cap-add` or other network flag. No path of the environment folder, of the task folder or of a sibling of the three folders is on the line.
- [ ] The container is removed after a suite that passes, one that fails, an engine failure (125 and 127), a timeout, and a cancelled context. A container that can't be removed is an error.
- [ ] An image that exists is not built again. A base without a digest, an `ADD` of a URL and a `COPY` from an image are refused before the engine is called.
- [ ] Every refusal in the Interfaces list happens before any container runs.
- [ ] On a real engine: the container has the interface `lo` only and cannot connect to `1.1.1.1:443`; `/app` is writable and the write reaches the host copy; `/tests` is read-only; `/logs/verifier` receives `results.json`; the mounts of the container are `/`, `/app`, `/logs/verifier` and `/tests` besides the engine's own; a running grader carries the label; a timeout ends it and removes it; `GraderLeftovers` is empty after each.

**Review focus pinned by tests:** no agent path to the hidden suite, and no path but three (`TestGradeNeverMountsAnythingButTheThreePaths`, with a mutation check in the Evidence); the container never outlives `Grade` (`TestGradeAlwaysRemovesTheContainer`, `TestGradeRemovesTheContainerWhenTheRunIsCancelled`, `TestGradeReportsAContainerItCouldNotRemove`); a stale result cannot pass for this run's (`TestGradeRefusesPathsItCouldNotMountSafely`, empty-logs case); the base images are the pinned ones (`TestGradeKeepsAnImageThatIsThereAndRefusesABaseNobodyPinned`); a doctor finds a leftover by label (`TestGraderLeftoversAreFoundByTheirLabelAndRemoved`).

**Named test:** `go test ./sandbox -run 'TestGrade|TestGrader|TestBuildStack'` in `gleipnir`, and, on a real engine, `go test -tags sandbox -run TestSandboxGrade ./sandbox` (see the header of `sandbox/integration_grade_test.go`). **Layer:** `gleipnir`. **Size:** L (780). **Depends on:** Phase 5b; its types are v0-T245's.

- [ ] **Step 1:** write the tests. First the fake engine learns `run` and `rm`.

Apply to `sandbox/driver_test.go`:

```diff
diff --git a/sandbox/driver_test.go b/sandbox/driver_test.go
index 7bed8e4..7a80ee7 100644
--- a/sandbox/driver_test.go
+++ b/sandbox/driver_test.go
@@ -35,6 +35,9 @@ echo "env host=${CONTAINER_HOST:-} auth=${REGISTRY_AUTH_FILE:-} docker=${DOCKER_
 case "$1" in
   image) case " $STUB_MISSING " in *" $3 "*) exit 1 ;; esac; exit 0 ;;
   network) [ "$2" = exists ] && exit 0; exit 0 ;;
+  run) [ -z "$STUB_RUN_SLEEP" ] || exec sleep "$STUB_RUN_SLEEP"
+    exit "${STUB_RUN_EXIT:-0}" ;;
+  rm) exit "${STUB_RM_EXIT:-0}" ;;
   ps) [ -z "$STUB_PS_SLEEP" ] || exec sleep "$STUB_PS_SLEEP"
     case "$*" in *service=fw*) echo fw456 ;; *) echo work123; echo fw456 ;; esac; exit 0 ;;
   exec)
```

Write `sandbox/grade_test.go`:

```go
package sandbox

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// graderDirs writes what a grading run is given: a task's environment folder, a copy of the project's
// /app, a hidden suite's tests folder and an empty folder for the verifier's logs. A file named
// SECRET sits beside each folder, so a test can show that no mount reaches past its folder.
func graderDirs(t *testing.T, dockerfile string) GradeSpec {
	t.Helper()
	root := t.TempDir()
	mk := func(rel, body string) string {
		p := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
		return filepath.Dir(p)
	}
	mk("task/SECRET", "task\n")
	env := mk("task/environment/Dockerfile", dockerfile)
	mk("task/environment/package.json", "{}\n")
	app := mk("export/app/index.js", "console.log(1)\n")
	mk("export/SECRET", "export\n")
	tests := mk("suite/v1/tests/test.sh", "#!/bin/bash\nexit 0\n")
	mk("suite/SECRET", "suite\n")
	logs := filepath.Join(root, "logs/verifier")
	if err := os.MkdirAll(logs, 0o755); err != nil {
		t.Fatal(err)
	}
	return GradeSpec{Run: "20261018-090000-a1b2c3", Task: "client-gallery-lite", Environment: env, App: app, Tests: tests, Logs: logs,
		Timeout: time.Minute, Memory: "4g", CPUs: 4, Env: map[string]string{"WORKERS": "4"}}
}

const graderDockerfile = "FROM " + baseA + "\nWORKDIR /grader\nCOPY package.json ./\nRUN mkdir -p /app\n"

// runCall returns the arguments of the one `podman run` in the engine's log.
func runCall(t *testing.T, log string) []string {
	t.Helper()
	var calls [][]string
	for _, l := range strings.Split(logOf(t, log), "\n") {
		if rest, ok := strings.CutPrefix(l, "podman run "); ok {
			calls = append(calls, strings.Fields(rest))
		}
	}
	if len(calls) != 1 {
		t.Fatalf("want one podman run, got %d:\n%s", len(calls), logOf(t, log))
	}
	return calls[0]
}

func TestGradeBuildsTheImageThenRunsTheSuiteWithoutANetworkAndRemovesTheContainer(t *testing.T) {
	d, log, _ := fakeEngine(t)
	gs := graderDirs(t, graderDockerfile)
	ref, err := GraderImage(gs.Task, gs.Environment)
	if err != nil || !strings.HasPrefix(ref, "localhost/ygg-grader-client-gallery-lite:") {
		t.Fatalf("GraderImage() = %q, %v", ref, err)
	}
	t.Setenv("STUB_MISSING", ref)
	res, err := d.Grade(context.Background(), gs)
	if err != nil || res.ExitCode != 0 || res.Image != ref {
		t.Fatalf("Grade() = %+v, %v", res, err)
	}
	got := logOf(t, log)
	pull := "podman pull -q --authfile " + d.auth + "/auth.json " + baseA
	build := "podman build --pull=never -t " + ref + " -f " + filepath.Join(gs.Environment, "Dockerfile") + " " + gs.Environment
	for _, want := range []string{pull, build, "podman rm -f --ignore --time 0 ygg-grader-20261018-090000-a1b2c3-client-gallery-lite"} {
		if !strings.Contains(got, want) {
			t.Errorf("the engine calls lack %q:\n%s", want, got)
		}
	}
	if !(strings.Index(got, "podman pull") < strings.Index(got, "podman build") && strings.Index(got, "podman build") < strings.Index(got, "podman run") && strings.Index(got, "podman run") < strings.Index(got, "podman rm")) {
		t.Errorf("the calls are not in the order pull, build, run, remove:\n%s", got)
	}
	args := runCall(t, log)
	flags := " " + strings.Join(args, " ") + " "
	for _, want := range []string{" --network none ", " --label ygg.grader=20261018-090000-a1b2c3 ", " --memory 4g ", " --cpus 4 ",
		" --name ygg-grader-20261018-090000-a1b2c3-client-gallery-lite ", " --env WORKERS=4 ", " " + ref + " bash /tests/test.sh"} {
		if !strings.Contains(flags, want) {
			t.Errorf("podman run lacks %q:\n%s", want, flags)
		}
	}
	if !strings.HasSuffix(flags, " "+ref+" bash /tests/test.sh ") {
		t.Errorf("the image and the command must end the line:\n%s", flags)
	}
}

func TestGradeKeepsAnImageThatIsThereAndRefusesABaseNobodyPinned(t *testing.T) {
	d, log, _ := fakeEngine(t)
	gs := graderDirs(t, graderDockerfile)
	if _, err := d.Grade(context.Background(), gs); err != nil {
		t.Fatal(err)
	}
	if got := logOf(t, log); strings.Contains(got, "podman build") || strings.Contains(got, "podman pull") {
		t.Errorf("an image that is there was built again:\n%s", got)
	}
	for name, dockerfile := range map[string]string{
		"a base with no digest": "FROM docker.io/library/node:24\n",
		"a remote file added":   "FROM " + baseA + "\nADD https://example.com/x.tgz /opt/\n",
		"a copy from an image":  "FROM " + baseA + "\nCOPY --from=docker.io/library/busybox:1 /bin/sh /sh\n",
	} {
		d, log, _ := fakeEngine(t)
		gs := graderDirs(t, dockerfile)
		if _, err := d.Grade(context.Background(), gs); err == nil {
			t.Errorf("%s: Grade() = nil, want an error", name)
		}
		if got := logOf(t, log); got != "" {
			t.Errorf("%s: the engine was called:\n%s", name, got)
		}
	}
}

func TestGradeNeverMountsAnythingButTheThreePaths(t *testing.T) {
	d, log, _ := fakeEngine(t)
	gs := graderDirs(t, graderDockerfile)
	if _, err := d.Grade(context.Background(), gs); err != nil {
		t.Fatal(err)
	}
	args := runCall(t, log)
	want := map[string]string{ // destination: the engine's view of the source, and the mode
		"/app":           engineSide(t, d, gs.App) + " rw",
		"/tests":         engineSide(t, d, gs.Tests) + " ro",
		"/logs/verifier": engineSide(t, d, gs.Logs) + " rw",
	}
	got := map[string]string{}
	for i, a := range args {
		switch a {
		case "--mount":
			kv := map[string]string{}
			for _, f := range strings.Split(args[i+1], ",") {
				k, v, _ := strings.Cut(f, "=")
				kv[k] = v
			}
			mode := "rw"
			if kv["ro"] == "true" {
				mode = "ro"
			}
			if kv["type"] != "bind" {
				t.Errorf("mount %q is not a bind mount", args[i+1])
			}
			if _, dup := got[kv["dst"]]; dup {
				t.Errorf("destination %s is mounted twice", kv["dst"])
			}
			got[kv["dst"]] = kv["src"] + " " + mode
		case "-v", "--volume", "--volumes-from", "--tmpfs", "--device", "--privileged", "--pid", "--ipc", "--uts", "--userns", "--cap-add", "--security-opt", "--network", "--net":
			if a != "--network" || args[i+1] != "none" {
				t.Errorf("podman run has the flag %s, which the grader does not use", a)
			}
		}
	}
	if len(got) != len(want) {
		t.Errorf("mounts = %v, want exactly %v", got, want)
	}
	for dst, w := range want {
		if got[dst] != w {
			t.Errorf("mount at %s = %q, want %q", dst, got[dst], w)
		}
	}
	// No path outside the three folders (the task, the other siblings, the environment) reaches the engine.
	root := filepath.Dir(filepath.Dir(gs.Environment))
	line := strings.Join(args, " ")
	for _, leak := range []string{filepath.Join(root, "task"), gs.Environment, filepath.Join(root, "suite", "SECRET"), filepath.Join(root, "export", "SECRET")} {
		if strings.Contains(line, leak) || strings.Contains(line, engineSide(t, d, leak)) {
			t.Errorf("podman run names %s, which is not one of the three paths:\n%s", leak, line)
		}
	}
}

func engineSide(t *testing.T, d *Driver, p string) string {
	t.Helper()
	e, err := d.cfg.MapPath(p)
	if err != nil {
		t.Fatal(err)
	}
	return e
}

func TestGradeSetsNoLimitItWasNotGiven(t *testing.T) {
	d, log, _ := fakeEngine(t)
	gs := graderDirs(t, graderDockerfile)
	gs.Memory, gs.CPUs = "", 0
	if _, err := d.Grade(context.Background(), gs); err != nil {
		t.Fatal(err)
	}
	if line := strings.Join(runCall(t, log), " "); strings.Contains(line, "--memory") || strings.Contains(line, "--cpus") {
		t.Errorf("podman run sets a limit nobody gave:\n%s", line)
	}
}

func TestGradeRefusesPathsItCouldNotMountSafely(t *testing.T) {
	good := graderDirs(t, graderDockerfile)
	other := t.TempDir()
	cases := map[string]func(*GradeSpec){
		"a relative app":           func(g *GradeSpec) { g.App = "app" },
		"an app that is not clean": func(g *GradeSpec) { g.App = g.App + "/../app" },
		"a path with a comma":      func(g *GradeSpec) { g.App = filepath.Join(other, "a,b"); os.MkdirAll(g.App, 0o755) },
		"a missing tests folder":   func(g *GradeSpec) { g.Tests = filepath.Join(other, "nope") },
		"tests without test.sh":    func(g *GradeSpec) { g.Tests = other },
		"logs that are not empty":  func(g *GradeSpec) { os.WriteFile(filepath.Join(g.Logs, "results.json"), []byte("{}"), 0o644) },
		"logs inside the app":      func(g *GradeSpec) { g.Logs = filepath.Join(g.App, "logs"); os.MkdirAll(g.Logs, 0o755) },
		"the tests inside the app": func(g *GradeSpec) {
			g.Tests = filepath.Join(g.App, "tests")
			os.MkdirAll(g.Tests, 0o755)
			os.WriteFile(filepath.Join(g.Tests, "test.sh"), nil, 0o755)
		},
		"the app as the logs":           func(g *GradeSpec) { g.Logs = g.App },
		"a task name with a slash":      func(g *GradeSpec) { g.Task = "a/b" },
		"a run name with a space":       func(g *GradeSpec) { g.Run = "run 1" },
		"no timeout":                    func(g *GradeSpec) { g.Timeout = 0 },
		"a memory limit that is a flag": func(g *GradeSpec) { g.Memory = "--privileged" },
		"negative cpus":                 func(g *GradeSpec) { g.CPUs = -1 },
		"an env name in lower case":     func(g *GradeSpec) { g.Env = map[string]string{"workers": "4"} },
		"an env value with a newline":   func(g *GradeSpec) { g.Env = map[string]string{"WORKERS": "4\n5"} },
	}
	for name, mutate := range cases {
		d, log, _ := fakeEngine(t)
		gs := good
		gs.Logs = filepath.Join(t.TempDir(), "verifier")
		os.MkdirAll(gs.Logs, 0o755)
		mutate(&gs)
		if _, err := d.Grade(context.Background(), gs); err == nil {
			t.Errorf("%s: Grade() = nil, want an error", name)
		}
		if got := logOf(t, log); strings.Contains(got, "podman run") {
			t.Errorf("%s: a container ran:\n%s", name, got)
		}
	}
	d, _, _ := fakeEngine(t)
	d.cfg.Mounts = []PathMap{{Host: "/home/ana/ygg", Engine: "/mnt/wsl/ygg-bind"}}
	if _, err := d.Grade(context.Background(), good); err == nil || !strings.Contains(err.Error(), "engine can't see") {
		t.Errorf("a folder the engine can't see: Grade() = %v", err)
	}
}

func TestGradeAlwaysRemovesTheContainer(t *testing.T) {
	cases := map[string]struct {
		env     map[string]string
		wantErr string
		exit    int
	}{
		"the suite fails":     {map[string]string{"STUB_RUN_EXIT": "1"}, "", 1},
		"the suite passes":    {nil, "", 0},
		"the engine fails":    {map[string]string{"STUB_RUN_EXIT": "125"}, "could not run", 0},
		"the container hangs": {map[string]string{"STUB_RUN_SLEEP": "30"}, "timed out", 0},
	}
	for name, c := range cases {
		d, log, _ := fakeEngine(t)
		for k, v := range c.env {
			t.Setenv(k, v)
		}
		gs := graderDirs(t, graderDockerfile)
		gs.Timeout = 300 * time.Millisecond
		start := time.Now()
		res, err := d.Grade(context.Background(), gs)
		if c.wantErr == "" && (err != nil || res.ExitCode != c.exit) {
			t.Errorf("%s: Grade() = %+v, %v", name, res, err)
		}
		if c.wantErr != "" && (err == nil || !strings.Contains(err.Error(), c.wantErr)) {
			t.Errorf("%s: Grade() = %v, want an error naming %q", name, err, c.wantErr)
		}
		if name == "the container hangs" && (!errors.Is(err, ErrGradeTimeout) || time.Since(start) > 10*time.Second) {
			t.Errorf("%s: err = %v after %v, want ErrGradeTimeout soon", name, err, time.Since(start))
		}
		if got := logOf(t, log); !strings.Contains(got, "podman rm -f --ignore --time 0 ygg-grader-") {
			t.Errorf("%s: the container was not removed:\n%s", name, got)
		}
		for k := range c.env {
			os.Unsetenv(k)
		}
	}
}

func TestGradeRemovesTheContainerWhenTheRunIsCancelled(t *testing.T) {
	d, log, _ := fakeEngine(t)
	t.Setenv("STUB_RUN_SLEEP", "30")
	gs := graderDirs(t, graderDockerfile)
	ctx, cancel := context.WithCancel(context.Background())
	time.AfterFunc(200*time.Millisecond, cancel)
	if _, err := d.Grade(ctx, gs); err == nil || errors.Is(err, ErrGradeTimeout) {
		t.Errorf("Grade() = %v, want the cancellation, not a timeout", err)
	}
	if got := logOf(t, log); !strings.Contains(got, "podman rm -f --ignore --time 0 ygg-grader-") {
		t.Errorf("a cancelled grading left its container:\n%s", got)
	}
}

func TestGradeReportsAContainerItCouldNotRemove(t *testing.T) {
	d, _, _ := fakeEngine(t)
	t.Setenv("STUB_RM_EXIT", "1")
	if _, err := d.Grade(context.Background(), graderDirs(t, graderDockerfile)); err == nil || !strings.Contains(err.Error(), "remov") {
		t.Errorf("Grade() = %v, want an error about the container it could not remove", err)
	}
}

func TestGraderLeftoversAreFoundByTheirLabelAndRemoved(t *testing.T) {
	d, log, _ := fakeEngine(t)
	list := filepath.Join(t.TempDir(), "podman")
	os.WriteFile(list, []byte(`#!/bin/sh
echo "podman $*" >> "$STUB_LOG"
case "$1" in
  ps) cat <<'JSON'
[{"Id":"bbb","State":"running","Labels":{"ygg.grader":"20261018-101500-a1b2c3"}},
 {"Id":"aaa","State":"exited","Labels":{"ygg.grader":"20261017-090000-ffffff"}}]
JSON
  ;;
esac
exit 0
`), 0o755)
	d.Podman = list
	ls, err := d.GraderLeftovers(context.Background())
	if err != nil || len(ls) != 2 || ls[0].Run != "20261017-090000-ffffff" || ls[0].Container != "aaa" || ls[1].State != "running" {
		t.Fatalf("GraderLeftovers() = %+v, %v; want two, oldest run first", ls, err)
	}
	if err := d.RemoveGrader(context.Background(), ls[1].Container); err != nil {
		t.Fatal(err)
	}
	got := logOf(t, log)
	if !strings.Contains(got, "podman ps -a --filter label=ygg.grader --format json") || !strings.Contains(got, "podman rm -f --ignore --time 0 bbb") {
		t.Errorf("the engine calls are wrong:\n%s", got)
	}
}

func TestGraderImageIsNamedForEveryFileOfTheEnvironmentAndRefusesWhatCouldLeadOutside(t *testing.T) {
	gs := graderDirs(t, graderDockerfile)
	first, err := GraderImage(gs.Task, gs.Environment)
	if err != nil {
		t.Fatal(err)
	}
	if again, _ := GraderImage(gs.Task, gs.Environment); again != first {
		t.Errorf("the same environment gave %s and then %s", first, again)
	}
	// A changed file, a new file and a file made executable are each a new image: nothing stale runs as the task's.
	for name, change := range map[string]func(env string){
		"a changed file of the same size and mode": func(env string) { os.WriteFile(filepath.Join(env, "package.json"), []byte("[]\n"), 0o755) },
		"a new file":           func(env string) { os.WriteFile(filepath.Join(env, "extra.txt"), []byte("x\n"), 0o644) },
		"a file made readonly": func(env string) { os.Chmod(filepath.Join(env, "package.json"), 0o644) },
	} {
		gs := graderDirs(t, graderDockerfile)
		before, _ := GraderImage(gs.Task, gs.Environment)
		change(gs.Environment)
		if got, err := GraderImage(gs.Task, gs.Environment); err != nil || got == before {
			t.Errorf("%s: GraderImage() = %q, %v; the tag was %q before", name, got, err, before)
		}
	}
	// A link in the environment could lead the build outside it.
	gs = graderDirs(t, graderDockerfile)
	if err := os.Symlink("/etc/passwd", filepath.Join(gs.Environment, "link")); err != nil {
		t.Fatal(err)
	}
	if _, err := GraderImage(gs.Task, gs.Environment); err == nil || !strings.Contains(err.Error(), "not a regular file") {
		t.Errorf("an environment holding a symlink: GraderImage() = %v", err)
	}
	d, log, _ := fakeEngine(t)
	if _, err := d.Grade(context.Background(), gs); err == nil {
		t.Error("Grade() = nil for an environment holding a symlink")
	}
	if got := logOf(t, log); strings.Contains(got, "podman build") || strings.Contains(got, "podman run") {
		t.Errorf("the engine built or ran something:\n%s", got)
	}
}
```

- [ ] **Step 2:** run the tests. Expect a build failure:

```bash
go vet ./sandbox
```

```output
# github.com/ouroboric-dev/gleipnir/sandbox
# [github.com/ouroboric-dev/gleipnir/sandbox]
vet: ./grade_test.go:16:50: undefined: GradeSpec
```

- [ ] **Step 3:** write the code. First the small refactor of `BuildStack`; its own tests must stay green.

Apply to `sandbox/stackbuild.go`:

```diff
diff --git a/sandbox/stackbuild.go b/sandbox/stackbuild.go
index 2b8fd11..818172e 100644
--- a/sandbox/stackbuild.go
+++ b/sandbox/stackbuild.go
@@ -47,19 +47,26 @@ func (d *Driver) BuildStack(ctx context.Context, ref, dir, target string) (built
 	if _, err := d.run(ctx, d.Podman, "image", "exists", ref); err == nil {
 		return false, nil
 	}
+	if err := d.pullAndBuild(ctx, ref, filepath.Join(dir, "Containerfile"), dir, target, bases); err != nil {
+		return false, err
+	}
+	return true, nil
+}
+
+// pullAndBuild pulls every base with the isolated registry auth, then builds the context at dir from the
+// Containerfile file, tagged ref, with a build that never pulls.
+func (d *Driver) pullAndBuild(ctx context.Context, ref, file, dir, target string, bases []string) error {
 	for _, base := range bases {
 		if _, err := d.run(ctx, d.Podman, "pull", "-q", "--authfile", filepath.Join(d.auth, "auth.json"), base); err != nil {
-			return false, err
+			return err
 		}
 	}
-	args := []string{"build", "--pull=never", "-t", ref, "-f", filepath.Join(dir, "Containerfile")}
+	args := []string{"build", "--pull=never", "-t", ref, "-f", file}
 	if target != "" {
 		args = append(args, "--target", target)
 	}
-	if _, err := d.run(ctx, d.Podman, append(args, dir)...); err != nil {
-		return false, err
-	}
-	return true, nil
+	_, err := d.run(ctx, d.Podman, append(args, dir)...)
+	return err
 }
 
 // containerfileBases returns the external images a Containerfile starts from, once each, and the names of
```

Write `sandbox/grade.go`:

```go
package sandbox

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/ouroboric-dev/gungnir/schema"
)

// LabelGrader is the label every grader container carries, with the run's id as its value, so ygg doctor
// finds one that a killed ygg left behind. It is not LabelRun: the sandbox of an agent and the container of
// a grader are different things, and a doctor that stops one must not stop the other.
const LabelGrader = "ygg.grader"

// The three places a grader container sees the host, and nothing else (spec §11).
const (
	GradeApp   = "/app"           // the exported project: a copy, read and write
	GradeTests = "/tests"         // the hidden suite: read only
	GradeLogs  = "/logs/verifier" // an empty host folder the suite writes results.json to
)

// ErrGradeTimeout means the suite did not end within the time it was given. The container is removed.
var ErrGradeTimeout = errors.New("the grader timed out")

// GradeSpec is one grading run: a task's image, and the three host folders its container sees.
type GradeSpec struct {
	Run         string        // the run's id: the label's value, and part of the container's name
	Task        string        // the task's id, such as client-gallery-lite
	Environment string        // the task's environment folder, with a Containerfile or a Dockerfile; it is built, never mounted
	App         string        // the project's exported files, as a copy the container may change: Odin throws it away
	Tests       string        // the hidden suite's tests folder, with test.sh; mounted read only
	Logs        string        // an empty host folder; the suite writes results.json to it
	Timeout     time.Duration // the most the container may run
	Memory      string        // the memory limit, such as 4g
	CPUs        int
	Env         map[string]string // the task's verifier.env; NAME in capitals
}

// GradeResult says how a grading run ended. The suite's exit status is not the score: results.json is.
type GradeResult struct {
	Image    string // the image the suite ran in
	ExitCode int    // test.sh's exit status
	Log      string // the end of what the container wrote and the engine said, for the run folder; never for an agent
}

// podman run's own failures: 125 for podman, 126 for a command it could not invoke and 127 for one it
// could not find, which includes a limit the engine could not apply. A suite whose test.sh exits with one
// of them reads the same way, which is a cost worth paying, as with podmanFailed.
const podmanCommandNotFound = 127

// maxGradeLog is how many bytes of the container's output a GradeResult keeps.
const maxGradeLog = 8000

var (
	graderName = regexp.MustCompile(`^[a-z][a-z0-9-]*$`)
	graderRun  = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9_.-]*$`)
	graderMem  = regexp.MustCompile(`^[1-9][0-9]*[mg]$`)
	graderVar  = regexp.MustCompile(`^[A-Z][A-Z0-9_]*$`)
)

// envContainerfile returns the file of the build context at dir that the image is built from: a
// Containerfile, or else a Dockerfile (a task of the benchmark has one).
func envContainerfile(dir string) (string, error) {
	for _, name := range []string{"Containerfile", "Dockerfile"} {
		if st, err := os.Lstat(filepath.Join(dir, name)); err == nil && st.Mode().IsRegular() {
			return filepath.Join(dir, name), nil
		}
	}
	return "", fmt.Errorf("the environment %s has no Containerfile or Dockerfile (it must be a regular file)", dir)
}

// GraderImage returns the tag of the image built from a task's environment folder: the task's id and a
// hash of every file of the folder, so a changed environment is a new image.
func GraderImage(task, environment string) (string, error) {
	if !graderName.MatchString(task) {
		return "", fmt.Errorf("task %q is not a task id", task)
	}
	if _, err := envContainerfile(environment); err != nil {
		return "", err
	}
	h := sha256.New()
	files, total := 0, int64(0)
	err := filepath.WalkDir(environment, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		rel, _ := filepath.Rel(environment, path)
		st, err := d.Info()
		if err != nil {
			return err
		}
		if !st.Mode().IsRegular() {
			return fmt.Errorf("the environment holds %s, which is not a regular file; a symlink could lead the build outside it", rel)
		}
		files++
		total += st.Size()
		if files > schema.MaxContextFiles || total > schema.MaxContextBytes {
			return fmt.Errorf("the environment is over its limits (%d files, %d MiB)", schema.MaxContextFiles, schema.MaxContextBytes>>20)
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		fmt.Fprintf(h, "%s\x00%v\x00%d\x00", filepath.ToSlash(rel), st.Mode()&0o111 != 0, st.Size())
		h.Write(b)
		return nil
	})
	if err != nil {
		return "", err
	}
	return "localhost/ygg-grader-" + task + ":" + hex.EncodeToString(h.Sum(nil))[:12], nil
}

// BuildGrader builds the image of a task's environment, from bases pinned by digest and its own stages
// only (the rules of BuildStack), and reports false when the image is there already. It is for grading
// alone: the image never holds the hidden suite, which is mounted when the container runs.
func (d *Driver) BuildGrader(ctx context.Context, task, environment string) (ref string, built bool, err error) {
	if ref, err = GraderImage(task, environment); err != nil {
		return "", false, err
	}
	file, err := envContainerfile(environment)
	if err != nil {
		return "", false, err
	}
	raw, err := os.ReadFile(file)
	if err != nil {
		return "", false, err
	}
	bases, _, err := containerfileBases(string(raw))
	if err != nil {
		return "", false, fmt.Errorf("%s: %w", file, err)
	}
	if _, err := d.run(ctx, d.Podman, "image", "exists", ref); err == nil {
		return ref, false, nil
	}
	if err := d.pullAndBuild(ctx, ref, file, environment, "", bases); err != nil {
		return "", false, err
	}
	return ref, true, nil
}

// check refuses a grading run whose folders could not be mounted exactly as the contract says.
func (g GradeSpec) check() error {
	if !graderName.MatchString(g.Task) {
		return fmt.Errorf("task %q is not a task id", g.Task)
	}
	if !graderRun.MatchString(g.Run) {
		return fmt.Errorf("run %q can't name a container", g.Run)
	}
	if g.Timeout <= 0 || g.CPUs < 0 || (g.Memory != "" && !graderMem.MatchString(g.Memory)) {
		return fmt.Errorf("a grading run needs a timeout above zero, no negative cpus and a memory limit such as 4g")
	}
	for _, name := range sortedEnv(g.Env) {
		if !graderVar.MatchString(name) || strings.ContainsAny(g.Env[name], "\n\x00") {
			return fmt.Errorf("env %s can't be passed to the grader", name)
		}
	}
	dirs := []struct{ name, path string }{{"app", g.App}, {"tests", g.Tests}, {"logs", g.Logs}}
	for _, p := range dirs {
		if !filepath.IsAbs(p.path) || filepath.Clean(p.path) != p.path || p.path == "/" || strings.ContainsAny(p.path, ",:\n") {
			return fmt.Errorf("the %s folder %q must be a clean, absolute path without a comma or a colon", p.name, p.path)
		}
		if st, err := os.Stat(p.path); err != nil || !st.IsDir() {
			return fmt.Errorf("the %s folder %s must be a folder", p.name, p.path)
		}
	}
	for i, a := range dirs {
		for _, b := range dirs[i+1:] {
			if a.path == b.path || strings.HasPrefix(a.path, b.path+"/") || strings.HasPrefix(b.path, a.path+"/") {
				return fmt.Errorf("the %s folder and the %s folder must be two folders, neither inside the other", a.name, b.name)
			}
		}
	}
	if st, err := os.Stat(filepath.Join(g.Tests, "test.sh")); err != nil || !st.Mode().IsRegular() {
		return fmt.Errorf("the tests folder %s has no test.sh", g.Tests)
	}
	if left, err := os.ReadDir(g.Logs); err != nil || len(left) > 0 {
		return fmt.Errorf("the logs folder %s must be empty: a result left in it would pass for this run's", g.Logs)
	}
	return nil
}

// Grade builds the task's image (BuildGrader) and runs the hidden suite in a container of it: no network
// but loopback, /app a read-write copy of the project, /tests the suite read only, /logs/verifier an empty
// host folder, the label ygg.grader=<run>, the memory and CPU limits, and a timeout. It runs
// `bash /tests/test.sh`. The container holds no other mount, and Grade always removes it, on success, on
// failure, on a timeout and on cancellation. A container it can't remove is an error. Like Build it is not
// for an agent's sandbox: no agent ever sees the container or the suite.
func (d *Driver) Grade(ctx context.Context, g GradeSpec) (res GradeResult, err error) {
	if err := g.check(); err != nil {
		return GradeResult{}, err
	}
	var src [3]string
	for i, p := range []string{g.App, g.Tests, g.Logs} {
		if src[i], err = d.cfg.MapPath(p); err != nil {
			return GradeResult{}, err
		}
	}
	ref, _, err := d.BuildGrader(ctx, g.Task, g.Environment)
	if err != nil {
		return GradeResult{}, err
	}
	name := "ygg-grader-" + g.Run + "-" + g.Task
	defer func() {
		// The caller's context may be over: the container is removed all the same.
		rmCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 2*time.Minute)
		defer cancel()
		if rmErr := d.RemoveGrader(rmCtx, name); rmErr != nil {
			err = errors.Join(err, fmt.Errorf("removing the grader container %s: %w", name, rmErr))
		}
	}()
	args := []string{"run", "--name", name, "--label", LabelGrader + "=" + g.Run, "--network", "none"}
	if g.Memory != "" {
		args = append(args, "--memory", g.Memory)
	}
	if g.CPUs > 0 {
		args = append(args, "--cpus", strconv.Itoa(g.CPUs))
	}
	for _, k := range sortedEnv(g.Env) {
		args = append(args, "--env", k+"="+g.Env[k])
	}
	args = append(args,
		"--mount", "type=bind,src="+src[0]+",dst="+GradeApp,
		"--mount", "type=bind,src="+src[1]+",dst="+GradeTests+",ro=true",
		"--mount", "type=bind,src="+src[2]+",dst="+GradeLogs,
		ref, "bash", GradeTests+"/test.sh")
	runCtx, cancel := context.WithTimeout(ctx, g.Timeout)
	defer cancel()
	out, runErr := d.run(runCtx, d.Podman, args...)
	res = GradeResult{Image: ref}
	if runErr != nil {
		out = append(out, runErr.Error()...)
	}
	res.Log = string(out[max(0, len(out)-maxGradeLog):])
	var ee *exec.ExitError
	switch {
	case ctx.Err() != nil:
		return res, ctx.Err()
	case runCtx.Err() != nil:
		return res, fmt.Errorf("%w after %v", ErrGradeTimeout, g.Timeout)
	case runErr == nil:
		return res, nil
	case errors.As(runErr, &ee) && (ee.ExitCode() < podmanFailed || ee.ExitCode() > podmanCommandNotFound):
		res.ExitCode = ee.ExitCode()
		return res, nil
	}
	return res, fmt.Errorf("podman could not run the grader (exit 125 to 127): %w", runErr)
}

// RemoveGrader removes a grader container, running or not. It is not an error if it is gone.
func (d *Driver) RemoveGrader(ctx context.Context, container string) error {
	_, err := d.run(ctx, d.Podman, "rm", "-f", "--ignore", "--time", "0", container)
	return err
}

// GraderLeftover is a grader container as the engine lists it.
type GraderLeftover struct {
	Run       string
	Container string
	State     string
}

// GraderLeftovers lists every container that carries the grader label, running or not, oldest run first.
func (d *Driver) GraderLeftovers(ctx context.Context) ([]GraderLeftover, error) {
	out, err := d.run(ctx, d.Podman, "ps", "-a", "--filter", "label="+LabelGrader, "--format", "json")
	if err != nil {
		return nil, err
	}
	var rows []struct {
		ID     string            `json:"Id"`
		State  string            `json:"State"`
		Labels map[string]string `json:"Labels"`
	}
	if err := json.Unmarshal(out, &rows); err != nil {
		return nil, fmt.Errorf("the engine's container list can't be read: %w", err)
	}
	var ls []GraderLeftover
	for _, r := range rows {
		ls = append(ls, GraderLeftover{Run: r.Labels[LabelGrader], Container: r.ID, State: r.State})
	}
	sort.Slice(ls, func(i, j int) bool { return ls[i].Run+"\x00"+ls[i].Container < ls[j].Run+"\x00"+ls[j].Container })
	return ls, nil
}
```

- [ ] **Step 4:** run the named test, then the whole repo the way CI does.

```bash
gofmt -l .
go vet ./...
go test -race -count=1 -v -run 'TestGrade|TestGrader|TestBuildStack' ./sandbox 2>&1 | grep -E "^(--- |ok|FAIL)"
GOWORK=off go test -race -count=1 ./...
```

```output
--- PASS: TestGradeBuildsTheImageThenRunsTheSuiteWithoutANetworkAndRemovesTheContainer (0.01s)
--- PASS: TestGradeKeepsAnImageThatIsThereAndRefusesABaseNobodyPinned (0.03s)
--- PASS: TestGradeNeverMountsAnythingButTheThreePaths (0.01s)
--- PASS: TestGradeSetsNoLimitItWasNotGiven (0.01s)
--- PASS: TestGradeRefusesPathsItCouldNotMountSafely (0.04s)
--- PASS: TestGradeAlwaysRemovesTheContainer (0.34s)
--- PASS: TestGradeRemovesTheContainerWhenTheRunIsCancelled (0.21s)
--- PASS: TestGradeReportsAContainerItCouldNotRemove (0.01s)
--- PASS: TestGraderLeftoversAreFoundByTheirLabelAndRemoved (0.01s)
--- PASS: TestGraderImageIsNamedForEveryFileOfTheEnvironmentAndRefusesWhatCouldLeadOutside (0.02s)
--- PASS: TestBuildStackPullsTheBasesByDigestThenBuildsTheContextNeverPulling (0.01s)
--- PASS: TestBuildStackLeavesAnImageThatIsThereAlone (0.00s)
--- PASS: TestBuildStackRefusesAContextItCouldNotBuildFromPinnedInputsOnly (0.02s)
--- PASS: TestBuildStackBuildsTheStageItWasToldTo (0.01s)
ok  	github.com/ouroboric-dev/gleipnir/sandbox	1.730s
ok  	github.com/ouroboric-dev/gleipnir/bounded	1.012s
ok  	github.com/ouroboric-dev/gleipnir/checks	1.299s
ok  	github.com/ouroboric-dev/gleipnir/claudecode	1.086s
ok  	github.com/ouroboric-dev/gleipnir/failure	1.014s
ok  	github.com/ouroboric-dev/gleipnir/opencode	1.055s
ok  	github.com/ouroboric-dev/gleipnir/sandbox	13.652s
ok  	github.com/ouroboric-dev/gleipnir/scan	1.068s
ok  	github.com/ouroboric-dev/gleipnir/scripted	1.087s
ok  	github.com/ouroboric-dev/gleipnir/skills	1.016s
```

`gofmt -l .` and `go vet ./...` print nothing.

- [ ] **Step 5:** the integration test, behind the `sandbox` build tag. Write `sandbox/integration_grade_test.go`:

```go
//go:build sandbox

package sandbox

// Integration tests of Grade on a real engine (spec §13), with the environment of
// TestSandboxDriverOnARealEngine. They need only the engine and a base image with bash, pinned by digest
// (itStack), which the first run pulls. Set YGG_SANDBOX_ENGINE, YGG_SANDBOX_TREE and
// YGG_SANDBOX_TREE_ENGINE, and YGG_SANDBOX_GRADE_LIMITS=1 on an engine that can apply memory and CPU
// limits (a rootless engine needs cgroup delegation; without it the container fails to start), then run:
//
//	go test -tags sandbox -run TestSandboxGrade -v -timeout 20m ./sandbox

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
	"time"
)

// itGrader returns a driver for the engine and a grading run in a folder of the shared tree. The
// suite's test.sh is the script given.
func itGrader(t *testing.T, script string) (*Driver, GradeSpec) {
	t.Helper()
	socket, tree, engineTree := itEnv(t)
	root, err := os.MkdirTemp(tree, "grade-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(root) })
	work := filepath.Join(root, "work")
	d, err := New(socket, Config{Mounts: []PathMap{{Host: tree, Engine: engineTree}}, UID: os.Getuid(), GID: os.Getgid()}, work)
	if err != nil {
		t.Fatal(err)
	}
	write := func(rel, body string, mode os.FileMode) string {
		p := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), mode); err != nil {
			t.Fatal(err)
		}
		return filepath.Dir(p)
	}
	env := write("task/environment/Dockerfile", "FROM "+itStack+"\nRUN mkdir -p /app /grader\n", 0o644)
	app := write("export/app/index.js", "console.log(1)\n", 0o644)
	tests := write("suite/v1/tests/test.sh", script, 0o755)
	logs := filepath.Join(root, "logs", "verifier")
	if err := os.MkdirAll(logs, 0o755); err != nil {
		t.Fatal(err)
	}
	gs := GradeSpec{Run: "20261018-120000-a1b2c3", Task: "it-task", Environment: env, App: app, Tests: tests, Logs: logs,
		Timeout: 5 * time.Minute, Env: map[string]string{"WORKERS": "2"}}
	if os.Getenv("YGG_SANDBOX_GRADE_LIMITS") != "" {
		gs.Memory, gs.CPUs = "1g", 1
	}
	return d, gs
}

const probeScript = `#!/bin/bash
cd /logs/verifier
ls /sys/class/net > ifaces.txt
if (exec 3<>/dev/tcp/1.1.1.1/443) 2>/dev/null; then echo reachable > net.txt; else echo blocked > net.txt; fi
echo from-the-suite > /app/written.txt && echo app-rw > app.txt
if touch /tests/x 2>/dev/null; then echo tests-rw > tests.txt; else echo tests-ro > tests.txt; fi
echo "$WORKERS" > env.txt
cat /proc/self/mountinfo | cut -d' ' -f5 > mounts.txt
echo '{"suites":[]}' > results.json
exit 3
`

func TestSandboxGradeRunsTheSuiteIsolatedAndRemovesTheContainer(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
	defer cancel()
	d, gs := itGrader(t, probeScript)
	res, err := d.Grade(ctx, gs)
	if err != nil || res.ExitCode != 3 {
		t.Fatalf("Grade() = %+v, %v; want the suite's exit status 3\n%s", res, err, res.Log)
	}
	read := func(name string) string {
		b, err := os.ReadFile(filepath.Join(gs.Logs, name))
		if err != nil {
			t.Fatalf("the suite wrote no %s: %v", name, err)
		}
		return strings.TrimSpace(string(b))
	}
	if got := read("ifaces.txt"); got != "lo" {
		t.Errorf("the container's network interfaces = %q, want lo only", got)
	}
	for file, want := range map[string]string{"net.txt": "blocked", "app.txt": "app-rw", "tests.txt": "tests-ro", "env.txt": "2", "results.json": `{"suites":[]}`} {
		if got := read(file); got != want {
			t.Errorf("%s = %q, want %q", file, got, want)
		}
	}
	if b, err := os.ReadFile(filepath.Join(gs.App, "written.txt")); err != nil || strings.TrimSpace(string(b)) != "from-the-suite" {
		t.Errorf("the suite's write to /app did not reach the copy: %q, %v", b, err)
	}
	// Every mount point in the container is the engine's own, or one of the three.
	var user []string
	for _, m := range strings.Fields(read("mounts.txt")) {
		own := false
		for _, p := range []string{"/proc", "/sys", "/dev", "/run", "/etc/hosts", "/etc/hostname", "/etc/resolv.conf"} {
			own = own || m == p || strings.HasPrefix(m, p+"/")
		}
		if !own {
			user = append(user, m)
		}
	}
	sort.Strings(user)
	if got := strings.Join(user, " "); got != "/ /app /logs/verifier /tests" {
		t.Errorf("the container's mounts = %q, want / /app /logs/verifier /tests", got)
	}
	left, err := d.GraderLeftovers(ctx)
	if err != nil || len(left) != 0 {
		t.Errorf("GraderLeftovers() = %+v, %v; want none after Grade", left, err)
	}
}

func TestSandboxGradeLabelsTheContainerAndRemovesItOnATimeout(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
	defer cancel()
	d, gs := itGrader(t, "#!/bin/bash\nsleep 300\n")
	gs.Timeout = 20 * time.Second
	if _, _, err := d.BuildGrader(ctx, gs.Task, gs.Environment); err != nil {
		t.Fatalf("BuildGrader() = %v", err)
	}
	done := make(chan error, 1)
	go func() { _, err := d.Grade(ctx, gs); done <- err }()
	seen := false
	for deadline := time.Now().Add(15 * time.Second); time.Now().Before(deadline) && !seen; time.Sleep(500 * time.Millisecond) {
		ls, err := d.GraderLeftovers(ctx)
		if err != nil {
			t.Fatal(err)
		}
		for _, l := range ls {
			seen = seen || (l.Run == gs.Run && l.State == "running")
		}
	}
	if !seen {
		t.Error("no running container carried the label ygg.grader=" + gs.Run)
	}
	if err := <-done; !errors.Is(err, ErrGradeTimeout) {
		t.Errorf("Grade() = %v, want ErrGradeTimeout", err)
	}
	if ls, err := d.GraderLeftovers(ctx); err != nil || len(ls) != 0 {
		t.Errorf("GraderLeftovers() = %+v, %v; want none after a timeout", ls, err)
	}
}
```

Run it on a real engine (the founder's rootless Podman on WSL; the folder is the bind mount the other integration tests use). Add `YGG_SANDBOX_GRADE_LIMITS=1` only on an engine that applies cgroup limits:

```bash
YGG_SANDBOX_ENGINE=unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock \
YGG_SANDBOX_TREE=/mnt/wsl/ygg-bind YGG_SANDBOX_TREE_ENGINE=/mnt/wsl/ygg-bind \
  go test -tags sandbox -count=1 -run TestSandboxGrade -v -timeout 20m ./sandbox
```

```output
=== RUN   TestSandboxGradeRunsTheSuiteIsolatedAndRemovesTheContainer
--- PASS: TestSandboxGradeRunsTheSuiteIsolatedAndRemovesTheContainer (0.31s)
=== RUN   TestSandboxGradeLabelsTheContainerAndRemovesItOnATimeout
--- PASS: TestSandboxGradeLabelsTheContainerAndRemovesItOnATimeout (20.23s)
PASS
ok  	github.com/ouroboric-dev/gleipnir/sandbox	20.549s
```

Without the tag, `go test ./sandbox` skips the file. With the tag and without the three variables, the tests skip.

- [ ] **Step 6:** commit (see "How each task lands"):

```bash
git add sandbox/driver_test.go sandbox/stackbuild.go sandbox/grade.go sandbox/grade_test.go sandbox/integration_grade_test.go
git commit -m "Grade: build the task image, run the hidden suite isolated, labelled, no agent mount (v0-T246)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**Evidence (v0-T246):** built and run in the reference workspace on 2026-10-18 as commit `3766b48` on `main` of `gleipnir` (not pushed). Tests first: the build failed as in step 2, then all passed. Mutation check: a temporary extra `--mount ...,dst=/env` of the environment folder made `TestGradeNeverMountsAnythingButTheThreePaths` fail with two errors (the mount set, and the path on the line); the change was removed. `gofmt -l .`, `go vet ./...` and `go vet -tags sandbox ./sandbox` print nothing; `GOWORK=off go test -race -count=1 ./...` is `ok` in every package; `reuse lint` prints nothing. Ran on a real engine (Podman client 5.8.3 on WSL, the user socket `podman-user.sock`): both `TestSandboxGrade...` tests passed, with the base `golang:1.26.7-bookworm@sha256:e8c859f5...` and WITHOUT memory and CPU limits, because this engine cannot apply them (see "Facts found on a real engine"). Not run: the limits on a real engine; the Dockerfile of `client-gallery-lite` (Playwright, `npm ci`); the hidden suite itself (nobody here may read it; the integration test uses a probe script); a second engine or rootful mode.

---

### Task v0-T247: read a benchmark task: `task.toml`, the brief's hash, the suite version, the retired mark

Odin's first task of the grader. Branch `grader/odin` from `main` in `odin`, before step 1. It needs v0-T245 and v0-T246
merged and pinned (see "To pin a sibling" under "How each task lands"); until then build through `yggdrasil/go.work`.
Two commits: part 1 reads the task, part 2 reads its hidden suite.

**Files (in `odin`):**

- Create: `internal/task/task.go`, `internal/task/task_test.go`
- Modify: `go.mod`, `go.sum` (the TOML parser: decision 1)

**Interfaces:**

- Consumes: `gungnir.GradeReason` and its five values, `gungnir.ValidVersion`, `gungnir.Suite` (`Validate`), `gungnir.Scenario`, `gungnir.FailToPass` (v0-T245). `tasks_dir/<id>/{task.toml,instruction.md,environment/}`; the hidden suite at `suite_dir/<id>/<suite>/tests/{test.sh,manifest.json}`; a retired suite is `tasks_dir/<id>/retired/<suite>`, a file or a folder.
- Produces: `task.Load(tasksDir, suiteDir, id) (*Task, error)` (in part 1 the signature is `Load(tasksDir, id)`; part 2 adds `suiteDir`). `Task` holds `ID`, `Version`, `Suite`, `BriefSHA256`, `Dir`, `Environment`, `Tests`, `Timeout`, `Env`, `Weights` and `Manifest`.
- Produces: `*task.Refusal{Reason gungnir.GradeReason, Detail string}`. Every failure of `Load` is one. Odin's grade stage (v0-T249) logs it as `grade_refused`.
- The checks run in this order, so the cheapest and the most specific refusal comes first: the task id and `task.toml` (`bad_task`), the retired mark (`retired`), the brief's hash (`brief_changed`), the suite's folders (`missing_suite`), the manifest (`bad_manifest`).
- `bad_task`: a task id that is not lower case words joined by dashes; a `task.toml` that is missing, not a regular file (a symlink could lead outside the checkout), over 64 KiB or not TOML; `artifacts` other than `["/app"]`; a `task.name` that does not end in the folder's name; a `task.version` that is not `x.y.z`; a `brief_sha256` that is not 64 hex digits; a `metadata.suite` that is not a suite version (it becomes a path); a `verifier.environment_mode` other than `"separate"`; a `verifier.timeout_sec` of 0 or over a day; a `verifier.env` name that is not in capitals; `SCORE_WEIGHTS` that is missing, malformed, names a category twice, has a weight outside 0 to 1, or does not sum to 1 within 1e-9.
- `brief_changed`: SHA-256 of `instruction.md` is not `metadata.brief_sha256`.
- `bad_manifest`: `manifest.json` that is not one JSON document, has an unknown field, fails `gungnir.Suite.Validate`, names another suite than `task.toml`, or has a fail-to-pass scenario in a category that `SCORE_WEIGHTS` gives no weight. (A category with a weight and no scenario is fine: it counts 0.)

**Acceptance criteria:**

- [ ] `Load` of a well-formed fake task returns its version, suite, brief hash, folders, timeout (the verifier's), env, weights and manifest.
- [ ] `retired/<suite>` as a file or as a folder gives `retired`. A mark for another suite does not.
- [ ] A changed `instruction.md` gives `brief_changed`, with the first 12 hex digits of the true hash in the detail.
- [ ] Each of: no store entry, no tests folder, no `test.sh`, no manifest gives `missing_suite`.
- [ ] Each case of the `bad_task` table and the `bad_manifest` table gives its reason.
- [ ] The smoke task of mimir (`smoke-notes`) with its PUBLIC sample suite loads: 7 scenarios, weight 0.4 for security. The test skips when no mimir checkout is near; `YGG_MIMIR` names one and `YGG_REQUIRE_MIMIR` makes the skip a failure.

**Review focus pinned by tests:**

- A retired suite scores a new run: `TestGraderRefusesRetiredVersion` (named by change benchmark-split-T001).
- A task whose brief changed after the hash was frozen: `TestAChangedBriefIsRefused`.
- A task file that lies about itself or leads out of the checkout: `TestATaskFileThatIsNotExactIsRefused`, `TestATaskFolderMayNotLeadOutsideItself`.
- A suite or manifest that can't be read exactly, so that a scenario could be lost: `TestAMissingSuiteIsRefused`, `TestAManifestThatCannotBeReadExactlyIsRefused`.

**Named test:** `go test ./internal/task` in `odin`. **Layer:** `odin`. **Size:** M and S (386 and 134). **Depends on:** v0-T245, v0-T246.

#### Part 1: the task

- [ ] **Step 1:** create the branch, add the parser, and write the tests first.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/odin
git switch -c grader/odin main
GOWORK=off go get github.com/BurntSushi/toml@v1.6.0
```

Expected output: `go: added github.com/BurntSushi/toml v1.6.0`. Then `go.mod` gains one line (`go.sum` is written by the tool, not copied):

```diff
diff --git a/go.mod b/go.mod
index e7e36bc..74b0418 100644
--- a/go.mod
+++ b/go.mod
@@ -3,6 +3,7 @@ module github.com/ouroboric-dev/odin
 go 1.26
 
 require (
+	github.com/BurntSushi/toml v1.6.0
 	github.com/ouroboric-dev/gleipnir v0.0.0-20261017195920-f003f21e48c7
 	github.com/ouroboric-dev/gungnir v0.0.0-20261017195515-cb1dc0ee9cc6
 	github.com/ouroboric-dev/havamal v0.0.0-20261017195922-be698041a5ae
```

Create `internal/task/task_test.go` (the whole file is in the commit; this is its first version):

```go
package task

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

const brief = "# Tiny\n\nBuild a tiny product.\n"

func taskToml(sha string) string {
	return `schema_version = "1.4"
artifacts = ["/app"]

[task]
name = "ouroboric-dev/tiny-task"
version = "2.1.0"

[metadata]
brief_sha256 = "` + sha + `"
suite = "v1"

[verifier]
timeout_sec = 300.0
environment_mode = "separate"

[verifier.env]
WORKERS = "2"
SCORE_WEIGHTS = "core=0.6,security=0.4"
`
}

func sha(s string) string { b := sha256.Sum256([]byte(s)); return hex.EncodeToString(b[:]) }

// fake is a tiny task, written by the test. Nothing here is a real task.
type fake struct{ tasks, dir string }

func newFake(t *testing.T) *fake {
	t.Helper()
	root := t.TempDir()
	f := &fake{tasks: filepath.Join(root, "tasks")}
	f.dir = filepath.Join(f.tasks, "tiny-task")
	f.write(t, "task.toml", taskToml(sha(brief)))
	f.write(t, "instruction.md", brief)
	f.write(t, "environment/Dockerfile", "FROM scratch\n")
	return f
}

func (f *fake) write(t *testing.T, rel, body string) {
	t.Helper()
	f.writeAt(t, filepath.Join(f.dir, rel), body)
}

func (f *fake) writeAt(t *testing.T, path, body string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
}

func (f *fake) load() (*Task, error) { return Load(f.tasks, "tiny-task") }

func wantRefusal(t *testing.T, err error, reason gungnir.GradeReason, detail string) {
	t.Helper()
	var r *Refusal
	if !errors.As(err, &r) {
		t.Fatalf("Load() = %v, want a *Refusal (%s)", err, reason)
	}
	if r.Reason != reason || !strings.Contains(r.Detail, detail) {
		t.Errorf("refusal = %s: %q, want %s with %q", r.Reason, r.Detail, reason, detail)
	}
}

func TestLoadReadsTheTask(t *testing.T) {
	f := newFake(t)
	tk, err := f.load()
	if err != nil {
		t.Fatalf("Load() = %v", err)
	}
	if tk.ID != "tiny-task" || tk.Version != "2.1.0" || tk.Suite != "v1" || tk.BriefSHA256 != sha(brief) {
		t.Errorf("task = %+v", tk)
	}
	if tk.Environment != filepath.Join(f.dir, "environment") {
		t.Errorf("environment = %s", tk.Environment)
	}
	if tk.Timeout != 300*time.Second || tk.Env["WORKERS"] != "2" || tk.Weights["core"] != 0.6 || tk.Weights["security"] != 0.4 {
		t.Errorf("limits = %v, env %v, weights %v", tk.Timeout, tk.Env, tk.Weights)
	}
}

func TestGraderRefusesRetiredVersion(t *testing.T) {
	f := newFake(t)
	// A retired suite is a file or a folder named for it; the suite itself may still be in the store.
	f.write(t, "retired/v1", "retired after the proof runs\n")
	_, err := f.load()
	wantRefusal(t, err, gungnir.GradeRetired, "v1")
	os.Remove(filepath.Join(f.dir, "retired", "v1"))
	f.write(t, "retired/v1/README.md", "folder form\n")
	_, err = f.load()
	wantRefusal(t, err, gungnir.GradeRetired, "v1")
	// Another version's mark does not retire this one.
	os.RemoveAll(filepath.Join(f.dir, "retired"))
	f.write(t, "retired/v0", "old\n")
	if _, err := f.load(); err != nil {
		t.Errorf("Load() with only v0 retired = %v", err)
	}
}

func TestAChangedBriefIsRefused(t *testing.T) {
	f := newFake(t)
	f.write(t, "instruction.md", brief+"One more line.\n")
	_, err := f.load()
	wantRefusal(t, err, gungnir.GradeBriefChanged, sha(brief)[:12])
}

func TestATaskFileThatIsNotExactIsRefused(t *testing.T) {
	good := taskToml(sha(brief))
	cases := map[string]struct{ from, to, want string }{
		"a verifier on the same machine": {`"separate"`, `"shared"`, "environment_mode"},
		"no version":                     {`version = "2.1.0"`, ``, "task.version"},
		"a version that is not x.y.z":    {`"2.1.0"`, `"2.1"`, "task.version"},
		"a name that is not the folder":  {`ouroboric-dev/tiny-task`, `ouroboric-dev/other`, "task.name"},
		"a brief hash that is not hex":   {sha(brief), `xyz`, "brief_sha256"},
		"a suite that is a path":         {`suite = "v1"`, `suite = "../v1"`, "metadata.suite"},
		"no suite":                       {`suite = "v1"`, ``, "metadata.suite"},
		"more than /app as artifact":     {`["/app"]`, `["/app", "/etc"]`, "artifacts"},
		"weights that sum to 1.1":        {`core=0.6,security=0.4`, `core=0.7,security=0.4`, "SCORE_WEIGHTS"},
		"a weight twice":                 {`core=0.6,security=0.4`, `core=0.6,core=0.4`, "SCORE_WEIGHTS"},
		"a weight that is not a number":  {`core=0.6,security=0.4`, `core=0.6,security=lots`, "SCORE_WEIGHTS"},
		"no weights":                     {`SCORE_WEIGHTS = "core=0.6,security=0.4"`, ``, "SCORE_WEIGHTS"},
		"no timeout":                     {`timeout_sec = 300.0`, ``, "timeout_sec"},
		"a lower case env name":          {`WORKERS = "2"`, `workers = "2"`, "verifier.env"},
		"toml that does not parse":       {`[task]`, `[task`, "task.toml"},
	}
	for name, c := range cases {
		f := newFake(t)
		if !strings.Contains(good, c.from) {
			t.Fatalf("%s: the good file lacks %q", name, c.from)
		}
		f.write(t, "task.toml", strings.Replace(good, c.from, c.to, 1))
		_, err := f.load()
		t.Run(name, func(t *testing.T) { wantRefusal(t, err, gungnir.GradeBadTask, c.want) })
	}
	f := newFake(t)
	os.Remove(filepath.Join(f.dir, "task.toml"))
	_, err := f.load()
	wantRefusal(t, err, gungnir.GradeBadTask, "task.toml")
	for _, id := range []string{"", "../tiny-task", "Tiny", "tiny/task", "-tiny"} {
		_, err := Load(f.tasks, id)
		wantRefusal(t, err, gungnir.GradeBadTask, "task id")
	}
}

func TestATaskFolderMayNotLeadOutsideItself(t *testing.T) {
	f := newFake(t)
	outside := filepath.Join(t.TempDir(), "instruction.md")
	os.WriteFile(outside, []byte(brief), 0o644)
	os.Remove(filepath.Join(f.dir, "instruction.md"))
	if err := os.Symlink(outside, filepath.Join(f.dir, "instruction.md")); err != nil {
		t.Skip("no symlinks here")
	}
	_, err := f.load()
	wantRefusal(t, err, gungnir.GradeBadTask, "instruction.md")
}
```

- [ ] **Step 2:** run the tests. They must not build.

```bash
go test ./internal/task
```

Real output (the tests of this commit on the code of its parent):

```text
# github.com/ouroboric-dev/odin/internal/task [github.com/ouroboric-dev/odin/internal/task.test]
internal/task/task_test.go:71:25: undefined: Task
internal/task/task_test.go:71:47: undefined: Load
internal/task/task_test.go:75:9: undefined: Refusal
internal/task/task_test.go:159:13: undefined: Load
FAIL	github.com/ouroboric-dev/odin/internal/task [build failed]
FAIL
```

- [ ] **Step 3:** create `internal/task/task.go`.

```go
// Package task reads a benchmark task for grading (spec §11, change benchmark-split): the public half
// from a checkout of mimir. It checks everything that can be
// checked before a container is built, and refuses with one of five reasons when a check fails. It
// reads files and starts nothing.
package task

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"time"

	"github.com/BurntSushi/toml"
	"github.com/ouroboric-dev/gungnir"
)

// Task is a task of mimir. Every path is absolute when the folder given to Load is.
type Task struct {
	ID          string
	Version     string // task.version: the version of the brief, such as 4.0.0
	Suite       string // metadata.suite: the hidden suite that scores this version, such as v1
	BriefSHA256 string // metadata.brief_sha256, which Load has checked against instruction.md
	Dir         string // <tasks_dir>/<id>
	Environment string // <tasks_dir>/<id>/environment: the grader's image is built from it
	Timeout     time.Duration
	Env         map[string]string  // verifier.env, passed to the grader's container
	Weights     map[string]float64 // the categories of the reward, from SCORE_WEIGHTS; they sum to 1
}

// Refusal is why grading was refused before anything was built. Reason is the word the ledger records.
type Refusal struct {
	Reason gungnir.GradeReason
	Detail string
}

func (r *Refusal) Error() string { return fmt.Sprintf("grading refused (%s): %s", r.Reason, r.Detail) }

func refuse(reason gungnir.GradeReason, format string, a ...any) error {
	return &Refusal{Reason: reason, Detail: fmt.Sprintf(format, a...)}
}

// File size limits: a task's files are small text, and a larger one is not a task.
const (
	maxToml  = 64 << 10
	maxBrief = 1 << 20
)

// weightEpsilon is how far the weights may be from a sum of 1.
const weightEpsilon = 1e-9

var (
	taskID    = regexp.MustCompile(`^[a-z][a-z0-9-]*$`)
	suiteName = regexp.MustCompile(`^[a-z0-9][a-z0-9._-]*$`)
	category  = regexp.MustCompile(`^[a-z][a-z0-9-]*$`)
	envName   = regexp.MustCompile(`^[A-Z][A-Z0-9_]*$`)
	sha256Hex = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// taskFile is the part of task.toml that grading reads. The file holds more (Harbor's keys); they are
// not ours and not checked.
type taskFile struct {
	Artifacts []string `toml:"artifacts"`
	Task      struct {
		Name    string `toml:"name"`
		Version string `toml:"version"`
	} `toml:"task"`
	Metadata struct {
		BriefSHA256 string `toml:"brief_sha256"`
		Suite       string `toml:"suite"`
	} `toml:"metadata"`
	Verifier struct {
		TimeoutSec      float64           `toml:"timeout_sec"`
		EnvironmentMode string            `toml:"environment_mode"`
		Env             map[string]string `toml:"env"`
	} `toml:"verifier"`
}

// Load reads task id from tasksDir, and checks it in this order: the task file (bad_task), the retired
// mark (retired) and the brief's hash (brief_changed). Any failure is a *Refusal.
func Load(tasksDir, id string) (*Task, error) {
	if !taskID.MatchString(id) {
		return nil, refuse(gungnir.GradeBadTask, "%q is not a task id (lower case words joined by dashes)", id)
	}
	t := &Task{ID: id, Dir: filepath.Join(tasksDir, id)}
	t.Environment = filepath.Join(t.Dir, "environment")
	raw, err := readRegular(filepath.Join(t.Dir, "task.toml"), maxToml)
	if err != nil {
		return nil, refuse(gungnir.GradeBadTask, "task.toml: %v", err)
	}
	var f taskFile
	if _, err := toml.NewDecoder(bytes.NewReader(raw)).Decode(&f); err != nil {
		return nil, refuse(gungnir.GradeBadTask, "task.toml does not parse: %v", err)
	}
	if err := t.fromFile(f); err != nil {
		return nil, err
	}
	if _, err := os.Lstat(filepath.Join(t.Dir, "retired", t.Suite)); err == nil {
		return nil, refuse(gungnir.GradeRetired, "the hidden suite %s of task %s is retired; a new task version names a new suite", t.Suite, id)
	}
	brief, err := readRegular(filepath.Join(t.Dir, "instruction.md"), maxBrief)
	if err != nil {
		return nil, refuse(gungnir.GradeBadTask, "instruction.md: %v", err)
	}
	if sum := sha256.Sum256(brief); hex.EncodeToString(sum[:]) != t.BriefSHA256 {
		return nil, refuse(gungnir.GradeBriefChanged, "instruction.md hashes to %s, task.toml says %s; any change to a brief is a new task version", hex.EncodeToString(sum[:]), t.BriefSHA256)
	}
	return t, nil
}

// fromFile checks the fields grading uses, and sets them.
func (t *Task) fromFile(f taskFile) error {
	bad := func(format string, a ...any) error { return refuse(gungnir.GradeBadTask, format, a...) }
	if !slices.Equal(f.Artifacts, []string{"/app"}) {
		return bad("artifacts is %q, it must be [\"/app\"]: only /app is carried to the grader", f.Artifacts)
	}
	if name := f.Task.Name; name[strings.LastIndex(name, "/")+1:] != t.ID {
		return bad("task.name %q does not end in the task's folder name %s", name, t.ID)
	}
	if !gungnir.ValidVersion(f.Task.Version) {
		return bad("task.version %q is not of the form 1.2.3", f.Task.Version)
	}
	if !sha256Hex.MatchString(f.Metadata.BriefSHA256) {
		return bad("metadata.brief_sha256 %q is not a SHA-256 in hex", f.Metadata.BriefSHA256)
	}
	if !suiteName.MatchString(f.Metadata.Suite) {
		return bad("metadata.suite %q is not a suite version such as v1", f.Metadata.Suite)
	}
	if f.Verifier.EnvironmentMode != "separate" {
		return bad("verifier.environment_mode is %q, it must be \"separate\": the grader holds only the collected /app", f.Verifier.EnvironmentMode)
	}
	if f.Verifier.TimeoutSec <= 0 || f.Verifier.TimeoutSec > 24*3600 {
		return bad("verifier.timeout_sec %v must be above 0 and at most a day", f.Verifier.TimeoutSec)
	}
	for name := range f.Verifier.Env {
		if !envName.MatchString(name) {
			return bad("verifier.env: %q is not a variable name in capitals", name)
		}
	}
	w, err := parseWeights(f.Verifier.Env["SCORE_WEIGHTS"])
	if err != nil {
		return bad("verifier.env SCORE_WEIGHTS: %v", err)
	}
	t.Version, t.BriefSHA256, t.Suite = f.Task.Version, f.Metadata.BriefSHA256, f.Metadata.Suite
	t.Timeout, t.Env, t.Weights = time.Duration(f.Verifier.TimeoutSec*float64(time.Second)), f.Verifier.Env, w
	return nil
}

// parseWeights reads "cat=w,cat=w": categories once each, weights from 0 to 1, summing to 1.
func parseWeights(s string) (map[string]float64, error) {
	if s == "" {
		return nil, errors.New("it is not set")
	}
	w := map[string]float64{}
	var sum float64
	for _, part := range strings.Split(s, ",") {
		name, num, ok := strings.Cut(part, "=")
		v, err := strconv.ParseFloat(num, 64)
		switch {
		case !ok || !category.MatchString(name):
			return nil, fmt.Errorf("%q is not category=weight", part)
		case err != nil || math.IsNaN(v) || v < 0 || v > 1:
			return nil, fmt.Errorf("the weight of %s must be a number from 0 to 1", name)
		}
		if _, twice := w[name]; twice {
			return nil, fmt.Errorf("the category %s is named twice", name)
		}
		w[name] = v
		sum += v
	}
	if math.Abs(sum-1) > weightEpsilon {
		return nil, fmt.Errorf("the weights sum to %v, not 1", sum)
	}
	return w, nil
}

// readRegular reads a regular file of at most max bytes, and nothing that is a link: a task's files are
// read from a checkout, and a link could lead to a file outside it.
func readRegular(path string, max int64) ([]byte, error) {
	st, err := os.Lstat(path)
	switch {
	case err != nil:
		return nil, bare(err)
	case !st.Mode().IsRegular():
		return nil, errors.New("it is not a regular file")
	case st.Size() > max:
		return nil, fmt.Errorf("it is over %d bytes", max)
	}
	b, err := os.ReadFile(path)
	return b, bare(err)
}

// bare is err without the path, which the message names already.
func bare(err error) error {
	var pe *fs.PathError
	if errors.As(err, &pe) {
		return pe.Err
	}
	return err
}
```

- [ ] **Step 4:** run the tests, the vet and the format check.

```bash
gofmt -l .
go vet ./internal/task
go test -race -count=1 ./internal/task
```

Expected: the first two print nothing. The third prints `ok  	github.com/ouroboric-dev/odin/internal/task	1.053s`.

- [ ] **Step 5:** commit.

```bash
git status --short                # go.mod, go.sum and internal/task/
git add go.mod go.sum internal/task/task.go internal/task/task_test.go
git commit -m "Read a benchmark task: task.toml, the brief's hash, the retired mark (v0-T247)" -m "Adds github.com/BurntSushi/toml v1.6.0 (December 2025, no dependencies) for task.toml." -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

#### Part 2: the hidden suite

This part changes `Load` to take the suite store, and makes `Task` hold the tests folder and the manifest. The tests change with it: the fake task gets a fake suite, and the suite tests are added.

- [ ] **Step 6:** write the tests first. Apply to `internal/task/task_test.go`:

```diff
diff --git a/internal/task/task_test.go b/internal/task/task_test.go
index 68026e0..7322377 100644
--- a/internal/task/task_test.go
+++ b/internal/task/task_test.go
@@ -15,6 +15,11 @@ import (
 
 const brief = "# Tiny\n\nBuild a tiny product.\n"
 
+const manifest = `{"schema":"ygg.suite/v1","suite":"v1","scenarios":[
+ {"id":"a thing works","category":"core","kind":"fail-to-pass"},
+ {"id":"a thing stays","category":"core","kind":"pass-to-pass"},
+ {"id":"a thing is private","category":"security","kind":"fail-to-pass"}]}`
+
 func taskToml(sha string) string {
 	return `schema_version = "1.4"
 artifacts = ["/app"]
@@ -39,17 +44,21 @@ SCORE_WEIGHTS = "core=0.6,security=0.4"
 
 func sha(s string) string { b := sha256.Sum256([]byte(s)); return hex.EncodeToString(b[:]) }
 
-// fake is a tiny task, written by the test. Nothing here is a real task.
-type fake struct{ tasks, dir string }
+// fake is a tiny task and a tiny suite, written by the test: tasks/<id> is the public half, suites/<id>/v1
+// the hidden half. Nothing here is a real suite.
+type fake struct{ tasks, suites, dir, tests string }
 
 func newFake(t *testing.T) *fake {
 	t.Helper()
 	root := t.TempDir()
-	f := &fake{tasks: filepath.Join(root, "tasks")}
+	f := &fake{tasks: filepath.Join(root, "tasks"), suites: filepath.Join(root, "suites")}
 	f.dir = filepath.Join(f.tasks, "tiny-task")
+	f.tests = filepath.Join(f.suites, "tiny-task", "v1", "tests")
 	f.write(t, "task.toml", taskToml(sha(brief)))
 	f.write(t, "instruction.md", brief)
 	f.write(t, "environment/Dockerfile", "FROM scratch\n")
+	f.writeAt(t, filepath.Join(f.tests, "test.sh"), "#!/bin/bash\nexit 0\n")
+	f.writeAt(t, filepath.Join(f.tests, "manifest.json"), manifest)
 	return f
 }
 
@@ -68,7 +77,7 @@ func (f *fake) writeAt(t *testing.T, path, body string) {
 	}
 }
 
-func (f *fake) load() (*Task, error) { return Load(f.tasks, "tiny-task") }
+func (f *fake) load() (*Task, error) { return Load(f.tasks, f.suites, "tiny-task") }
 
 func wantRefusal(t *testing.T, err error, reason gungnir.GradeReason, detail string) {
 	t.Helper()
@@ -81,7 +90,7 @@ func wantRefusal(t *testing.T, err error, reason gungnir.GradeReason, detail str
 	}
 }
 
-func TestLoadReadsTheTask(t *testing.T) {
+func TestLoadReadsTheTaskAndFindsItsSuite(t *testing.T) {
 	f := newFake(t)
 	tk, err := f.load()
 	if err != nil {
@@ -90,12 +99,15 @@ func TestLoadReadsTheTask(t *testing.T) {
 	if tk.ID != "tiny-task" || tk.Version != "2.1.0" || tk.Suite != "v1" || tk.BriefSHA256 != sha(brief) {
 		t.Errorf("task = %+v", tk)
 	}
-	if tk.Environment != filepath.Join(f.dir, "environment") {
-		t.Errorf("environment = %s", tk.Environment)
+	if tk.Environment != filepath.Join(f.dir, "environment") || tk.Tests != f.tests {
+		t.Errorf("folders = %s, %s", tk.Environment, tk.Tests)
 	}
 	if tk.Timeout != 300*time.Second || tk.Env["WORKERS"] != "2" || tk.Weights["core"] != 0.6 || tk.Weights["security"] != 0.4 {
 		t.Errorf("limits = %v, env %v, weights %v", tk.Timeout, tk.Env, tk.Weights)
 	}
+	if len(tk.Manifest.Scenarios) != 3 || tk.Manifest.Suite != "v1" {
+		t.Errorf("manifest = %+v", tk.Manifest)
+	}
 }
 
 func TestGraderRefusesRetiredVersion(t *testing.T) {
@@ -123,6 +135,21 @@ func TestAChangedBriefIsRefused(t *testing.T) {
 	wantRefusal(t, err, gungnir.GradeBriefChanged, sha(brief)[:12])
 }
 
+func TestAMissingSuiteIsRefused(t *testing.T) {
+	cases := map[string]func(f *fake){
+		"no store entry for the task": func(f *fake) { os.RemoveAll(filepath.Join(f.suites, "tiny-task")) },
+		"no tests folder":             func(f *fake) { os.RemoveAll(f.tests) },
+		"no test.sh":                  func(f *fake) { os.Remove(filepath.Join(f.tests, "test.sh")) },
+		"no manifest":                 func(f *fake) { os.Remove(filepath.Join(f.tests, "manifest.json")) },
+	}
+	for name, mutate := range cases {
+		f := newFake(t)
+		mutate(f)
+		_, err := f.load()
+		t.Run(name, func(t *testing.T) { wantRefusal(t, err, gungnir.GradeMissingSuite, "v1") })
+	}
+}
+
 func TestATaskFileThatIsNotExactIsRefused(t *testing.T) {
 	good := taskToml(sha(brief))
 	cases := map[string]struct{ from, to, want string }{
@@ -156,7 +183,7 @@ func TestATaskFileThatIsNotExactIsRefused(t *testing.T) {
 	_, err := f.load()
 	wantRefusal(t, err, gungnir.GradeBadTask, "task.toml")
 	for _, id := range []string{"", "../tiny-task", "Tiny", "tiny/task", "-tiny"} {
-		_, err := Load(f.tasks, id)
+		_, err := Load(f.tasks, f.suites, id)
 		wantRefusal(t, err, gungnir.GradeBadTask, "task id")
 	}
 }
@@ -172,3 +199,49 @@ func TestATaskFolderMayNotLeadOutsideItself(t *testing.T) {
 	_, err := f.load()
 	wantRefusal(t, err, gungnir.GradeBadTask, "instruction.md")
 }
+
+func TestAManifestThatCannotBeReadExactlyIsRefused(t *testing.T) {
+	cases := map[string]string{
+		"not json":                  `{"schema":`,
+		"an unknown field":          strings.Replace(manifest, `"kind":"fail-to-pass"}]`, `"kind":"fail-to-pass","skip":true}]`, 1),
+		"another schema":            strings.Replace(manifest, "ygg.suite/v1", "ygg.suite/v9", 1),
+		"another suite":             strings.Replace(manifest, `"suite":"v1"`, `"suite":"v2"`, 1),
+		"an id twice":               strings.Replace(manifest, "a thing stays", "a thing works", 1),
+		"no scenarios":              `{"schema":"ygg.suite/v1","suite":"v1","scenarios":[]}`,
+		"a category with no weight": strings.Replace(manifest, `"security"`, `"billing"`, 1),
+		"a second document":         manifest + manifest,
+	}
+	for name, body := range cases {
+		f := newFake(t)
+		f.writeAt(t, filepath.Join(f.tests, "manifest.json"), body)
+		_, err := f.load()
+		t.Run(name, func(t *testing.T) { wantRefusal(t, err, gungnir.GradeBadManifest, "") })
+	}
+}
+
+// The smoke task of mimir is the real shape. Its sample suite is PUBLIC, so it may stand in for a hidden
+// suite here. The test needs a checkout of mimir: YGG_MIMIR names it, else it is looked for beside odin.
+func TestTheSmokeTaskOfMimirLoadsWithItsSampleSuite(t *testing.T) {
+	mimir := os.Getenv("YGG_MIMIR")
+	if mimir == "" {
+		mimir = filepath.Join("..", "..", "..", "mimir")
+	}
+	tests := filepath.Join(mimir, "smoke-notes", "sample-suite", "tests")
+	if _, err := os.Stat(tests); err != nil {
+		if os.Getenv("YGG_REQUIRE_MIMIR") != "" {
+			t.Fatal(err)
+		}
+		t.Skip("no checkout of mimir: set YGG_MIMIR")
+	}
+	suites := t.TempDir()
+	if err := os.CopyFS(filepath.Join(suites, "smoke-notes", "v1", "tests"), os.DirFS(tests)); err != nil {
+		t.Fatal(err)
+	}
+	tk, err := Load(mimir, suites, "smoke-notes")
+	if err != nil {
+		t.Fatalf("Load() = %v", err)
+	}
+	if tk.Version != "1.0.0" || tk.Suite != "v1" || len(tk.Manifest.Scenarios) != 7 || tk.Weights["security"] != 0.4 {
+		t.Errorf("task = %+v", tk)
+	}
+}
```

- [ ] **Step 7:** run the tests. They must not build (`Load` has two arguments).

```bash
go test ./internal/task
```

Real output (first lines):

```text
# github.com/ouroboric-dev/odin/internal/task [github.com/ouroboric-dev/odin/internal/task.test]
internal/task/task_test.go:80:71: too many arguments in call to Load
	have (string, string, string)
	want (string, string)
internal/task/task_test.go:102:65: tk.Tests undefined (type *Task has no field or method Tests)
internal/task/task_test.go:103:51: tk.Tests undefined (type *Task has no field or method Tests)
internal/task/task_test.go:108:12: tk.Manifest undefined (type *Task has no field or method Manifest)
```

- [ ] **Step 8:** apply to `internal/task/task.go`:

```diff
diff --git a/internal/task/task.go b/internal/task/task.go
index d1da379..801c35f 100644
--- a/internal/task/task.go
+++ b/internal/task/task.go
@@ -1,5 +1,5 @@
 // Package task reads a benchmark task for grading (spec §11, change benchmark-split): the public half
-// from a checkout of mimir. It checks everything that can be
+// from a checkout of mimir, the hidden half from the suite store. It checks everything that can be
 // checked before a container is built, and refuses with one of five reasons when a check fails. It
 // reads files and starts nothing.
 package task
@@ -8,6 +8,7 @@ import (
 	"bytes"
 	"crypto/sha256"
 	"encoding/hex"
+	"encoding/json"
 	"errors"
 	"fmt"
 	"io/fs"
@@ -24,7 +25,8 @@ import (
 	"github.com/ouroboric-dev/gungnir"
 )
 
-// Task is a task of mimir. Every path is absolute when the folder given to Load is.
+// Task is a task of mimir joined with its hidden suite. Every path is absolute when the folders given
+// to Load are.
 type Task struct {
 	ID          string
 	Version     string // task.version: the version of the brief, such as 4.0.0
@@ -32,9 +34,11 @@ type Task struct {
 	BriefSHA256 string // metadata.brief_sha256, which Load has checked against instruction.md
 	Dir         string // <tasks_dir>/<id>
 	Environment string // <tasks_dir>/<id>/environment: the grader's image is built from it
+	Tests       string // <suite_dir>/<id>/<suite>/tests: mounted read only into the grader and nowhere else
 	Timeout     time.Duration
 	Env         map[string]string  // verifier.env, passed to the grader's container
 	Weights     map[string]float64 // the categories of the reward, from SCORE_WEIGHTS; they sum to 1
+	Manifest    gungnir.Suite      // tests/manifest.json
 }
 
 // Refusal is why grading was refused before anything was built. Reason is the word the ledger records.
@@ -51,8 +55,9 @@ func refuse(reason gungnir.GradeReason, format string, a ...any) error {
 
 // File size limits: a task's files are small text, and a larger one is not a task.
 const (
-	maxToml  = 64 << 10
-	maxBrief = 1 << 20
+	maxToml     = 64 << 10
+	maxBrief    = 1 << 20
+	maxManifest = 1 << 20
 )
 
 // weightEpsilon is how far the weights may be from a sum of 1.
@@ -85,9 +90,10 @@ type taskFile struct {
 	} `toml:"verifier"`
 }
 
-// Load reads task id from tasksDir, and checks it in this order: the task file (bad_task), the retired
-// mark (retired) and the brief's hash (brief_changed). Any failure is a *Refusal.
-func Load(tasksDir, id string) (*Task, error) {
+// Load reads task id from tasksDir and its hidden suite from suiteDir, and checks them in this order:
+// the task file (bad_task), the retired mark (retired), the brief's hash (brief_changed), the suite's
+// folders (missing_suite) and the suite's manifest (bad_manifest). Any failure is a *Refusal.
+func Load(tasksDir, suiteDir, id string) (*Task, error) {
 	if !taskID.MatchString(id) {
 		return nil, refuse(gungnir.GradeBadTask, "%q is not a task id (lower case words joined by dashes)", id)
 	}
@@ -114,7 +120,17 @@ func Load(tasksDir, id string) (*Task, error) {
 	if sum := sha256.Sum256(brief); hex.EncodeToString(sum[:]) != t.BriefSHA256 {
 		return nil, refuse(gungnir.GradeBriefChanged, "instruction.md hashes to %s, task.toml says %s; any change to a brief is a new task version", hex.EncodeToString(sum[:]), t.BriefSHA256)
 	}
-	return t, nil
+	t.Tests = filepath.Join(suiteDir, id, t.Suite, "tests")
+	if st, err := os.Stat(t.Tests); err != nil || !st.IsDir() {
+		return nil, refuse(gungnir.GradeMissingSuite, "the store holds no tests folder for suite %s of task %s", t.Suite, id)
+	}
+	if st, err := os.Stat(filepath.Join(t.Tests, "test.sh")); err != nil || !st.Mode().IsRegular() {
+		return nil, refuse(gungnir.GradeMissingSuite, "suite %s of task %s has no test.sh", t.Suite, id)
+	}
+	if _, err := os.Lstat(filepath.Join(t.Tests, "manifest.json")); err != nil {
+		return nil, refuse(gungnir.GradeMissingSuite, "suite %s of task %s has no manifest.json", t.Suite, id)
+	}
+	return t, t.readManifest()
 }
 
 // fromFile checks the fields grading uses, and sets them.
@@ -183,6 +199,36 @@ func parseWeights(s string) (map[string]float64, error) {
 	return w, nil
 }
 
+// readManifest reads tests/manifest.json exactly: no unknown field, the schema, the suite the task names,
+// and a weight for every category that has a fail-to-pass scenario.
+func (t *Task) readManifest() error {
+	bad := func(format string, a ...any) error { return refuse(gungnir.GradeBadManifest, format, a...) }
+	raw, err := readRegular(filepath.Join(t.Tests, "manifest.json"), maxManifest)
+	if err != nil {
+		return bad("manifest.json: %v", err)
+	}
+	dec := json.NewDecoder(bytes.NewReader(raw))
+	dec.DisallowUnknownFields()
+	if err := dec.Decode(&t.Manifest); err != nil {
+		return bad("manifest.json does not parse: %v", err)
+	}
+	if dec.More() {
+		return bad("manifest.json holds more than one document")
+	}
+	if err := t.Manifest.Validate(); err != nil {
+		return bad("manifest.json: %v", err)
+	}
+	if t.Manifest.Suite != t.Suite {
+		return bad("manifest.json is of suite %s, task.toml names %s", t.Manifest.Suite, t.Suite)
+	}
+	for _, sc := range t.Manifest.Scenarios {
+		if _, ok := t.Weights[sc.Category]; !ok && sc.Kind == gungnir.FailToPass {
+			return bad("scenario %q is in category %s, which SCORE_WEIGHTS gives no weight", sc.ID, sc.Category)
+		}
+	}
+	return nil
+}
+
 // readRegular reads a regular file of at most max bytes, and nothing that is a link: a task's files are
 // read from a checkout, and a link could lead to a file outside it.
 func readRegular(path string, max int64) ([]byte, error) {
```

- [ ] **Step 9:** run the tests with the race detector.

```bash
go test -race -count=1 -v ./internal/task 2>&1 | grep -E "^(--- |ok|FAIL)"
```

Real output:

```text
--- PASS: TestLoadReadsTheTaskAndFindsItsSuite (0.00s)
--- PASS: TestGraderRefusesRetiredVersion (0.01s)
--- PASS: TestAChangedBriefIsRefused (0.00s)
--- PASS: TestAMissingSuiteIsRefused (0.01s)
--- PASS: TestATaskFileThatIsNotExactIsRefused (0.05s)
--- PASS: TestATaskFolderMayNotLeadOutsideItself (0.00s)
--- PASS: TestAManifestThatCannotBeReadExactlyIsRefused (0.02s)
--- PASS: TestTheSmokeTaskOfMimirLoadsWithItsSampleSuite (0.00s)
ok  	github.com/ouroboric-dev/odin/internal/task	1.119s
```

The last test passes (it did not skip) because, in the reference workspace, mimir's checkout is at `../../../mimir` of the package folder. In the umbrella it is not there; set `YGG_MIMIR` to run it.

- [ ] **Step 10:** commit.

```bash
git add internal/task/task.go internal/task/task_test.go
git commit -m "Read a task's hidden suite: its folders and its manifest, refusing with missing_suite and bad_manifest (v0-T247)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**Evidence (v0-T247):** built and run in the reference workspace on 2026-10-18 as commits `a82a0fb` and `e0a136d` on branch `grader/odin` of `odin` (not pushed). Tests first: the build failed as in steps 2 and 7, then every test passed. `gofmt -l .` and `go vet ./...` print nothing. `go test -race -count=1 ./internal/task`: `ok`. Two mutations were tried and each failed the test named for it, then were undone: the retired check made never true (`TestGraderRefusesRetiredVersion` failed), the hash comparison made never true (`TestAChangedBriefIsRefused` failed). Not run: `GOWORK=off go test`, which needs the merged pins of v0-T245 and v0-T246 (the pinned `gungnir` has no `GradeReason`); the tests ran through `go.work`. `reuse lint` (5.0.2) prints nothing.

### Task v0-T248: the suite manifest, the results join and `score.json`

Odin's second task of the grader. It needs v0-T247 on the same branch. Two commits: part 1 reads the Playwright results, part 2 joins them with the manifest and writes the score.

**Files (in `odin`):**

- Create: `internal/score/results.go`, `internal/score/results_test.go`, `internal/score/score.go`, `internal/score/score_test.go`

**Interfaces:**

- Consumes: `gungnir.Suite`, `gungnir.Score` (`Validate`, `RewardOf`), `gungnir.ScoredScenario`, `gungnir.Tally`, `gungnir.CategoryScore`, `gungnir.ScoreSchema` (v0-T245); `task.Task.Manifest` and `.Weights` (v0-T247, passed in by the caller: `score` does not import `task`).
- Produces: `score.ReadResults(path) (map[string]gungnir.ScenarioStatus, error)`: the status of each spec of a Playwright JSON report, by title, in nested suites too. A test is as good as its last try. A spec passes when every test of it passes; it fails when one fails, times out, is interrupted or has a status Odin does not know; it is skipped when none ran or one was skipped. A report with no spec, a title used twice, or a file over 32 MiB is an error.
- Produces: `*score.MismatchError{NotRun, Unknown, Repeated}`. A scenario in the manifest and not in the results, a spec in the results and not in the manifest, or a title twice. The message names at most five ids. The grade stage logs it as `bad_manifest`.
- Produces: `score.Compute(Input, results) (gungnir.Score, error)`. The scenarios keep the manifest's order. `reward` is the sum over the categories of `weight * passed / total`, fail-to-pass scenarios only; a category with no fail-to-pass scenario counts 0; pass-to-pass has its own tally and never changes `reward`. The categories are summed in name order, so the same results give the same bytes. The result passes `Score.Validate`.
- Produces: `score.Write(runDir, Score) (path, error)`: validates, then writes `<runDir>/score.json` through a temporary file in the same folder and a rename, mode `0600`. It has no other place to write to, and refuses a relative path or a folder that is not there.

**Acceptance criteria:**

- [ ] A report with nested suites, a retried test, a test with two projects and a skipped spec reads as the tests say.
- [ ] A last try of `failed`, `timedOut`, `interrupted` or an unknown word is a failure, whatever came before.
- [ ] A scenario on one side only gives a `*MismatchError` in both directions, and no score.
- [ ] The reward of the sample numbers is 0.7: core 1 of 2 at 0.6, security 1 of 1 at 0.4. A failed pass-to-pass scenario shows in `pass_to_pass` and leaves the reward at 1. A skipped scenario scores 0.
- [ ] `score.json` is the contract's: `schema`, `run`, `task`, `task_version`, `brief_sha256`, `suite`, `started`, `finished`, `scenarios`, `fail_to_pass`, `pass_to_pass`, `categories`, `reward`.
- [ ] After `Write`, the run folder holds `score.json` and no other new file, and the parent folder holds nothing new.

**Review focus pinned by tests:**

- A scenario that disappears and is read as a pass: `TestAScenarioOnOneSideOnlyIsAnErrorNeverAPass`, `TestReadResultsRefusesWhatItCannotReadExactly` (title twice).
- A retry, a skip or an interrupt read as a pass: `TestReadResultsReadsNestedSuitesAndTheLastTryOfEachTest`, `TestAFailedLastTryIsAFailureWhateverCameBefore`, `TestASkippedScenarioIsNotAPass`.
- A pass-to-pass scenario that changes the reward: `TestPassToPassIsReportedOnItsOwnAndNeverChangesTheReward`.
- A score written where an agent can read it: `TestWriteMakesOneFileInTheRunFolderAndNothingBesideIt` (the engine side is v0-T249's `TestScoreJSONIsInNoLeafAndNoTree`).

**Named test:** `go test ./internal/score` in `odin`. **Layer:** `odin`. **Size:** M and M (232 and 365). **Depends on:** v0-T247.

#### Part 1: the results

- [ ] **Step 1:** write the tests first. Create `internal/score/results_test.go`:

```go
package score

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func write(t *testing.T, body string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "results.json")
	if err := os.WriteFile(p, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	return p
}

// A report in Playwright's JSON reporter format: nested suites, a retried test, a project per browser.
const playwrightReport = `{"config":{"rootDir":"/grader"},"suites":[
 {"title":"notes.spec.ts","file":"notes.spec.ts","specs":[
   {"title":"a thing works","ok":true,"tests":[{"projectName":"chromium","results":[{"status":"failed"},{"status":"passed"}]}]},
   {"title":"a thing stays","ok":true,"tests":[{"results":[{"status":"passed"}]}]}],
  "suites":[{"title":"a group","specs":[
   {"title":"a second thing works","tests":[{"results":[{"status":"passed"}]},{"results":[{"status":"timedOut"}]}]},
   {"title":"a thing is private","tests":[{"results":[{"status":"skipped"}]}]}]}]}],
 "errors":[]}`

func TestReadResultsReadsNestedSuitesAndTheLastTryOfEachTest(t *testing.T) {
	got, err := ReadResults(write(t, playwrightReport))
	if err != nil {
		t.Fatalf("ReadResults() = %v", err)
	}
	want := map[string]gungnir.ScenarioStatus{
		"a thing works":        gungnir.ScenarioPassed, // it failed once and the retry passed
		"a thing stays":        gungnir.ScenarioPassed,
		"a second thing works": gungnir.ScenarioFailed, // one of its two projects timed out
		"a thing is private":   gungnir.ScenarioSkipped,
	}
	for id, st := range want {
		if got[id] != st {
			t.Errorf("%q = %q, want %q", id, got[id], st)
		}
	}
	if len(got) != len(want) {
		t.Errorf("got %d specs, want %d", len(got), len(want))
	}
}

func TestReadResultsRefusesWhatItCannotReadExactly(t *testing.T) {
	var m *MismatchError
	_, err := ReadResults(write(t, `{"suites":[{"specs":[{"title":"x","tests":[]},{"title":"x","tests":[]}]}]}`))
	if !errors.As(err, &m) || !strings.Contains(err.Error(), `"x"`) {
		t.Errorf("a spec title used twice: %v", err)
	}
	for name, body := range map[string]string{"not json": `{"suites":`, "an empty file": ``, "no suites": `{"suites":[]}`} {
		if _, err := ReadResults(write(t, body)); err == nil {
			t.Errorf("%s: ReadResults() = nil", name)
		}
	}
	if _, err := ReadResults(filepath.Join(t.TempDir(), "none.json")); err == nil {
		t.Error("a missing file read")
	}
}

func TestAFailedLastTryIsAFailureWhateverCameBefore(t *testing.T) {
	body := `{"suites":[{"specs":[
	 {"title":"passes then fails","tests":[{"results":[{"status":"passed"},{"status":"failed"}]}]},
	 {"title":"interrupted","tests":[{"results":[{"status":"interrupted"}]}]},
	 {"title":"a status nobody knows","tests":[{"results":[{"status":"flaky-ish"}]}]},
	 {"title":"ran in one project, skipped in another","tests":[{"results":[{"status":"passed"}]},{"results":[{"status":"skipped"}]}]},
	 {"title":"no tests","tests":[]}]}]}`
	got, err := ReadResults(write(t, body))
	if err != nil {
		t.Fatal(err)
	}
	for title, want := range map[string]gungnir.ScenarioStatus{
		"passes then fails": gungnir.ScenarioFailed, "interrupted": gungnir.ScenarioFailed, "a status nobody knows": gungnir.ScenarioFailed,
		"ran in one project, skipped in another": gungnir.ScenarioSkipped, "no tests": gungnir.ScenarioSkipped,
	} {
		if got[title] != want {
			t.Errorf("%q = %q, want %q", title, got[title], want)
		}
	}
}
```

- [ ] **Step 2:** run them. They must not build.

```bash
go test ./internal/score
```

Real output:

```text
# github.com/ouroboric-dev/odin/internal/score [github.com/ouroboric-dev/odin/internal/score.test]
internal/score/results_test.go:33:14: undefined: ReadResults
internal/score/results_test.go:54:9: undefined: MismatchError
internal/score/results_test.go:55:12: undefined: ReadResults
internal/score/results_test.go:60:16: undefined: ReadResults
internal/score/results_test.go:64:15: undefined: ReadResults
internal/score/results_test.go:76:14: undefined: ReadResults
FAIL	github.com/ouroboric-dev/odin/internal/score [build failed]
FAIL
```

- [ ] **Step 3:** create `internal/score/results.go`:

```go
// Package score turns the results of a hidden suite into score.json (spec §11, change benchmark-split).
// It reads the Playwright report the suite wrote, joins it with the suite's manifest by scenario id,
// and adds up the reward. A scenario on one side only is an error, never a pass. It writes score.json
// to the run folder and nowhere else: the score is for the operator and the ledger, never for an agent.
package score

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"slices"
	"strings"

	"github.com/ouroboric-dev/gungnir"
)

// maxResults is the most bytes of a results file that are read.
const maxResults = 32 << 20

// MismatchError says the manifest and the results do not name the same scenarios, or that the results
// name one twice. No score comes out of it: a missing scenario can't be told from a failed one.
type MismatchError struct {
	NotRun   []string // in the manifest, not in the results
	Unknown  []string // in the results, not in the manifest
	Repeated []string // a spec title used more than once in the results
}

func (e *MismatchError) Error() string {
	var parts []string
	for _, p := range []struct {
		what string
		ids  []string
	}{{"in the manifest and not in the results", e.NotRun}, {"in the results and not in the manifest", e.Unknown}, {"used twice in the results", e.Repeated}} {
		if len(p.ids) > 0 {
			parts = append(parts, fmt.Sprintf("%d %s: %s", len(p.ids), p.what, list(p.ids)))
		}
	}
	return "the suite's manifest and its results disagree: " + strings.Join(parts, "; ")
}

// list names at most five ids, so an error stays one line.
func list(ids []string) string {
	q := make([]string, 0, 6)
	for i, id := range ids {
		if i == 5 {
			q = append(q, "...")
			break
		}
		q = append(q, fmt.Sprintf("%q", id))
	}
	return strings.Join(q, ", ")
}

// The part of Playwright's JSON reporter format that scoring reads. Suites nest.
type report struct {
	Suites []reportSuite `json:"suites"`
}

type reportSuite struct {
	Specs  []reportSpec  `json:"specs"`
	Suites []reportSuite `json:"suites"`
}

type reportSpec struct {
	Title string `json:"title"`
	Tests []struct {
		Results []struct {
			Status string `json:"status"`
		} `json:"results"`
	} `json:"tests"`
}

// ReadResults reads a Playwright JSON report and returns the status of each spec by title. A test is
// as good as its last try (a retry that passes counts); a spec passes when all its tests pass, fails
// when one fails, times out or is interrupted, and is skipped when none ran. A report with no spec,
// or one that names a title twice, is an error.
func ReadResults(path string) (map[string]gungnir.ScenarioStatus, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("the suite wrote no results: %w", err)
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, maxResults+1))
	if err != nil {
		return nil, err
	}
	if len(b) > maxResults {
		return nil, fmt.Errorf("the results are over %d bytes", maxResults)
	}
	var r report
	if err := json.Unmarshal(b, &r); err != nil {
		return nil, fmt.Errorf("the results are not a Playwright report: %w", err)
	}
	out := map[string]gungnir.ScenarioStatus{}
	var again []string
	var walk func(ss []reportSuite)
	walk = func(ss []reportSuite) {
		for _, s := range ss {
			for _, sp := range s.Specs {
				if _, twice := out[sp.Title]; twice {
					again = append(again, sp.Title)
				}
				out[sp.Title] = specStatus(sp)
			}
			walk(s.Suites)
		}
	}
	walk(r.Suites)
	if len(again) > 0 {
		slices.Sort(again)
		return nil, &MismatchError{Repeated: slices.Compact(again)}
	}
	if len(out) == 0 {
		return nil, errors.New("the results hold no spec")
	}
	return out, nil
}

func specStatus(sp reportSpec) gungnir.ScenarioStatus {
	ran, skipped := 0, 0
	for _, t := range sp.Tests {
		if len(t.Results) == 0 {
			skipped++
			continue
		}
		switch t.Results[len(t.Results)-1].Status {
		case "passed":
			ran++
		case "skipped":
			skipped++
		default: // failed, timedOut, interrupted, or a word we don't know: not a pass
			return gungnir.ScenarioFailed
		}
	}
	if ran == 0 {
		return gungnir.ScenarioSkipped
	}
	if skipped > 0 {
		return gungnir.ScenarioSkipped
	}
	return gungnir.ScenarioPassed
}
```

- [ ] **Step 4:** run the tests, then commit.

```bash
gofmt -l . ; go vet ./internal/score
go test -race -count=1 ./internal/score
git add internal/score/results.go internal/score/results_test.go
git commit -m "Read a hidden suite's Playwright results: the last try of each test, nested suites, no pass for what did not run (v0-T248)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

Expected: the first two print nothing; the third prints `ok  	github.com/ouroboric-dev/odin/internal/score	1.015s`.

#### Part 2: the score

- [ ] **Step 5:** write the tests first. Create `internal/score/score_test.go`:

```go
package score

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

var (
	t0 = time.Date(2026, 10, 18, 9, 0, 0, 0, time.UTC)
	t1 = t0.Add(4 * time.Minute)
)

// manifest: two fail-to-pass in core, one in security, one pass-to-pass in core.
func input() Input {
	return Input{
		Run: "20261018-090000-a1b2c3", Task: "tiny-task", TaskVersion: "2.1.0", Suite: "v1",
		BriefSHA256: strings.Repeat("ab", 32), Started: t0, Finished: t1,
		Weights: map[string]float64{"core": 0.6, "security": 0.4},
		Manifest: gungnir.Suite{Schema: gungnir.SuiteSchema, Suite: "v1", Scenarios: []gungnir.Scenario{
			{ID: "a thing works", Category: "core", Kind: gungnir.FailToPass},
			{ID: "a thing stays", Category: "core", Kind: gungnir.PassToPass},
			{ID: "a second thing works", Category: "core", Kind: gungnir.FailToPass},
			{ID: "a thing is private", Category: "security", Kind: gungnir.FailToPass},
		}},
	}
}

func passed(ids ...string) map[string]gungnir.ScenarioStatus {
	m := map[string]gungnir.ScenarioStatus{}
	for _, id := range ids {
		m[id] = gungnir.ScenarioPassed
	}
	return m
}

func all(status gungnir.ScenarioStatus) map[string]gungnir.ScenarioStatus {
	m := passed("a thing works", "a thing stays", "a second thing works", "a thing is private")
	for id := range m {
		m[id] = status
	}
	return m
}

func TestComputeAddsUpTheRewardFromTheFailToPassScenariosOnly(t *testing.T) {
	res := passed("a thing works", "a thing stays", "a second thing works", "a thing is private")
	res["a second thing works"] = gungnir.ScenarioFailed
	s, err := Compute(input(), res)
	if err != nil {
		t.Fatalf("Compute() = %v", err)
	}
	if s.FailToPass != (gungnir.Tally{Passed: 2, Total: 3}) || s.PassToPass != (gungnir.Tally{Passed: 1, Total: 1}) {
		t.Errorf("tallies = %+v, %+v", s.FailToPass, s.PassToPass)
	}
	// core: 1 of 2 at 0.6, security: 1 of 1 at 0.4.
	if got := s.Categories["core"]; got != (gungnir.CategoryScore{Passed: 1, Total: 2, Weight: 0.6}) {
		t.Errorf("core = %+v", got)
	}
	if s.Reward < 0.7-1e-12 || s.Reward > 0.7+1e-12 {
		t.Errorf("reward = %v, want 0.7", s.Reward)
	}
	if s.Schema != gungnir.ScoreSchema || s.Run != input().Run || s.Task != "tiny-task" || s.TaskVersion != "2.1.0" || s.Suite != "v1" || s.BriefSHA256 != input().BriefSHA256 {
		t.Errorf("score = %+v", s)
	}
	if err := s.Validate(); err != nil {
		t.Errorf("the score does not validate: %v", err)
	}
}

func TestPassToPassIsReportedOnItsOwnAndNeverChangesTheReward(t *testing.T) {
	res := all(gungnir.ScenarioPassed)
	res["a thing stays"] = gungnir.ScenarioFailed
	s, err := Compute(input(), res)
	if err != nil {
		t.Fatal(err)
	}
	if s.Reward < 1-1e-12 || s.PassToPass != (gungnir.Tally{Passed: 0, Total: 1}) {
		t.Errorf("reward %v, pass_to_pass %+v; a failed pass-to-pass scenario must show there and leave the reward at 1", s.Reward, s.PassToPass)
	}
}

func TestACategoryWithNoFailToPassScenarioCountsZero(t *testing.T) {
	in := input()
	in.Weights = map[string]float64{"core": 0.5, "security": 0.3, "billing": 0.2}
	s, err := Compute(in, all(gungnir.ScenarioPassed))
	if err != nil {
		t.Fatal(err)
	}
	if got := s.Categories["billing"]; got != (gungnir.CategoryScore{Weight: 0.2}) {
		t.Errorf("billing = %+v", got)
	}
	if s.Reward < 0.8-1e-12 || s.Reward > 0.8+1e-12 {
		t.Errorf("reward = %v, want 0.8: a category without scenarios scores nothing", s.Reward)
	}
}

func TestASkippedScenarioIsNotAPass(t *testing.T) {
	s, err := Compute(input(), all(gungnir.ScenarioSkipped))
	if err != nil {
		t.Fatal(err)
	}
	if s.Reward != 0 || s.FailToPass.Passed != 0 || s.Scenarios[0].Status != gungnir.ScenarioSkipped {
		t.Errorf("score = %+v", s)
	}
}

func TestAScenarioOnOneSideOnlyIsAnErrorNeverAPass(t *testing.T) {
	missing := all(gungnir.ScenarioPassed)
	delete(missing, "a thing is private")
	extra := all(gungnir.ScenarioPassed)
	extra["a new thing"] = gungnir.ScenarioPassed
	for name, c := range map[string]struct {
		res           map[string]gungnir.ScenarioStatus
		manifest, run string
	}{
		"a scenario the suite did not run":  {missing, "a thing is private", ""},
		"a spec the manifest does not know": {extra, "", "a new thing"},
		"results with nothing in them":      {map[string]gungnir.ScenarioStatus{}, "a thing works", ""},
	} {
		_, err := Compute(input(), c.res)
		var m *MismatchError
		if !errors.As(err, &m) {
			t.Errorf("%s: Compute() = %v, want a *MismatchError", name, err)
			continue
		}
		if c.manifest != "" && !strings.Contains(m.Error(), c.manifest) || c.run != "" && !strings.Contains(m.Error(), c.run) {
			t.Errorf("%s: %v does not name the scenario", name, m)
		}
	}
}

func TestComputeRefusesWhatCannotBeScored(t *testing.T) {
	in := input()
	in.Weights = map[string]float64{"core": 1}
	if _, err := Compute(in, all(gungnir.ScenarioPassed)); err == nil {
		t.Error("a fail-to-pass category with no weight scored")
	}
	in = input()
	in.Finished = t0.Add(-time.Second)
	if _, err := Compute(in, all(gungnir.ScenarioPassed)); err == nil {
		t.Error("a run that finished before it started scored")
	}
}

func TestScoreJSONIsTheContract(t *testing.T) {
	res := passed("a thing works", "a thing stays", "a second thing works", "a thing is private")
	res["a thing is private"] = gungnir.ScenarioFailed
	s, err := Compute(input(), res)
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	path, err := Write(dir, s)
	if err != nil || path != filepath.Join(dir, "score.json") {
		t.Fatalf("Write() = %q, %v", path, err)
	}
	got, _ := os.ReadFile(path)
	want := `{
  "schema": "ygg.score/v1",
  "run": "20261018-090000-a1b2c3",
  "task": "tiny-task",
  "task_version": "2.1.0",
  "brief_sha256": "` + strings.Repeat("ab", 32) + `",
  "suite": "v1",
  "started": "2026-10-18T09:00:00Z",
  "finished": "2026-10-18T09:04:00Z",
  "scenarios": [
    { "id": "a thing works", "category": "core", "kind": "fail-to-pass", "status": "passed" },
    { "id": "a thing stays", "category": "core", "kind": "pass-to-pass", "status": "passed" },
    { "id": "a second thing works", "category": "core", "kind": "fail-to-pass", "status": "passed" },
    { "id": "a thing is private", "category": "security", "kind": "fail-to-pass", "status": "failed" }
  ],
  "fail_to_pass": { "passed": 2, "total": 3 },
  "pass_to_pass": { "passed": 1, "total": 1 },
  "categories": {
    "core": { "passed": 2, "total": 2, "weight": 0.6 },
    "security": { "passed": 0, "total": 1, "weight": 0.4 }
  },
  "reward": 0.6
}
`
	if !sameJSON(t, string(got), want) {
		t.Errorf("score.json:\n%s\nwant (as JSON):\n%s", got, want)
	}
}

func TestWriteRefusesARunFolderThatIsNotAbsoluteAndWritesNothing(t *testing.T) {
	t.Chdir(t.TempDir())
	if err := os.Mkdir("run", 0o755); err != nil {
		t.Fatal(err)
	}
	s, _ := Compute(input(), all(gungnir.ScenarioPassed))
	if _, err := Write("run", s); err == nil {
		t.Error("Write(\"run\") = nil: a relative folder means whatever the working directory is")
	}
	if left, _ := os.ReadDir("run"); len(left) != 0 {
		t.Errorf("a refused write left %d file(s) in run/", len(left))
	}
}

func TestWriteMakesOneFileInTheRunFolderAndNothingBesideIt(t *testing.T) {
	parent := t.TempDir()
	runDir := filepath.Join(parent, "run")
	os.Mkdir(runDir, 0o755)
	s, _ := Compute(input(), all(gungnir.ScenarioPassed))
	if _, err := Write(runDir, s); err != nil {
		t.Fatal(err)
	}
	var found []string
	filepath.WalkDir(parent, func(p string, d os.DirEntry, _ error) error {
		if !d.IsDir() {
			rel, _ := filepath.Rel(parent, p)
			found = append(found, rel)
		}
		return nil
	})
	if strings.Join(found, ",") != filepath.Join("run", "score.json") {
		t.Errorf("files = %v, want only run/score.json", found)
	}
	if st, _ := os.Stat(filepath.Join(runDir, "score.json")); st.Mode().Perm() != 0o600 {
		t.Errorf("mode = %v, want 0600", st.Mode().Perm())
	}
	bad := s
	bad.Reward = 1.5
	if _, err := Write(runDir, bad); err == nil {
		t.Error("Write() wrote a score that does not add up")
	}
	for _, dir := range []string{"relative/run", filepath.Join(parent, "none")} {
		if _, err := Write(dir, s); err == nil {
			t.Errorf("Write(%q) = nil", dir)
		}
	}
}

// sameJSON compares two documents by value, so the test does not depend on white space.
func sameJSON(t *testing.T, a, b string) bool {
	t.Helper()
	var x, y any
	if err := json.Unmarshal([]byte(a), &x); err != nil {
		t.Fatalf("score.json is not JSON: %v", err)
	}
	if err := json.Unmarshal([]byte(b), &y); err != nil {
		t.Fatal(err)
	}
	return reflect.DeepEqual(x, y)
}
```

- [ ] **Step 6:** run them. They must not build.

```bash
go test ./internal/score
```

Real output (first lines):

```text
# github.com/ouroboric-dev/odin/internal/score [github.com/ouroboric-dev/odin/internal/score.test]
internal/score/score_test.go:22:14: undefined: Input
internal/score/score_test.go:23:9: undefined: Input
internal/score/score_test.go:55:12: undefined: Compute
internal/score/score_test.go:80:12: undefined: Compute
internal/score/score_test.go:92:12: undefined: Compute
```

- [ ] **Step 7:** create `internal/score/score.go`:

```go
package score

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

// FileName is the name of the score in the run folder.
const FileName = "score.json"

// Input is what a score is made of, besides the results: the task and the suite it was graded by.
type Input struct {
	Run         string // the run's id
	Task        string
	TaskVersion string
	Suite       string
	BriefSHA256 string
	Manifest    gungnir.Suite      // the suite's manifest, which Load has validated
	Weights     map[string]float64 // the categories of the reward; they sum to 1
	Started     time.Time
	Finished    time.Time
}

// Compute joins the manifest with the results and adds up the score (contract: reward = sum over the
// categories of weight * passed / total, fail-to-pass scenarios only, a category with none counts 0;
// pass-to-pass is reported on its own). The scenarios keep the manifest's order. The categories are
// summed in name order, so the same results always give the same bytes.
func Compute(in Input, results map[string]gungnir.ScenarioStatus) (gungnir.Score, error) {
	if err := in.Manifest.Validate(); err != nil {
		return gungnir.Score{}, err
	}
	var miss MismatchError
	known := map[string]bool{}
	for _, sc := range in.Manifest.Scenarios {
		known[sc.ID] = true
		if _, ok := results[sc.ID]; !ok {
			miss.NotRun = append(miss.NotRun, sc.ID)
		}
	}
	for id := range results {
		if !known[id] {
			miss.Unknown = append(miss.Unknown, id)
		}
	}
	if len(miss.NotRun)+len(miss.Unknown) > 0 {
		slices.Sort(miss.Unknown)
		return gungnir.Score{}, &miss
	}
	s := gungnir.Score{Schema: gungnir.ScoreSchema, Run: in.Run, Task: in.Task, TaskVersion: in.TaskVersion, BriefSHA256: in.BriefSHA256,
		Suite: in.Suite, Started: in.Started, Finished: in.Finished, Categories: map[string]gungnir.CategoryScore{}}
	for name, w := range in.Weights {
		s.Categories[name] = gungnir.CategoryScore{Weight: w}
	}
	for _, sc := range in.Manifest.Scenarios {
		st := results[sc.ID]
		s.Scenarios = append(s.Scenarios, gungnir.ScoredScenario{ID: sc.ID, Category: sc.Category, Kind: sc.Kind, Status: st})
		tally := &s.PassToPass
		if sc.Kind == gungnir.FailToPass {
			c, ok := s.Categories[sc.Category]
			if !ok {
				return gungnir.Score{}, fmt.Errorf("scenario %q is in category %s, which has no weight", sc.ID, sc.Category)
			}
			c.Total++
			if st == gungnir.ScenarioPassed {
				c.Passed++
			}
			s.Categories[sc.Category] = c
			tally = &s.FailToPass
		}
		tally.Total++
		if st == gungnir.ScenarioPassed {
			tally.Passed++
		}
	}
	names := make([]string, 0, len(s.Categories))
	for name := range s.Categories {
		names = append(names, name)
	}
	slices.Sort(names)
	for _, name := range names {
		if c := s.Categories[name]; c.Total > 0 {
			s.Reward += c.Weight * float64(c.Passed) / float64(c.Total)
		}
	}
	return s, s.Validate()
}

// Write validates the score and writes it as score.json in runDir: atomically, readable by the operator
// only. runDir is the run's own folder; Write has no other place to write to, and refuses a relative
// path or a folder that is not there. It returns the path.
func Write(runDir string, s gungnir.Score) (string, error) {
	if !filepath.IsAbs(runDir) {
		return "", fmt.Errorf("the run folder %q must be an absolute path", runDir)
	}
	if err := s.Validate(); err != nil {
		return "", fmt.Errorf("the score does not add up: %w", err)
	}
	b, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return "", err
	}
	tmp, err := os.CreateTemp(runDir, ".score-*")
	if err != nil {
		return "", err
	}
	defer os.Remove(tmp.Name()) // gone after the rename; a failed write leaves nothing
	if _, err := tmp.Write(append(b, '\n')); err != nil {
		tmp.Close()
		return "", err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return "", err
	}
	if err := tmp.Close(); err != nil {
		return "", err
	}
	path := filepath.Join(runDir, FileName)
	return path, os.Rename(tmp.Name(), path)
}
```

- [ ] **Step 8:** run the tests with the race detector and commit.

```bash
gofmt -l . ; go vet ./internal/score
go test -race -count=1 -v ./internal/score 2>&1 | grep -E "^(--- |ok|FAIL)"
git add internal/score/score.go internal/score/score_test.go
git commit -m "Join the manifest with the results and write score.json to the run folder (v0-T248)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

Real output of the test run:

```text
--- PASS: TestReadResultsReadsNestedSuitesAndTheLastTryOfEachTest (0.00s)
--- PASS: TestReadResultsRefusesWhatItCannotReadExactly (0.00s)
--- PASS: TestAFailedLastTryIsAFailureWhateverCameBefore (0.00s)
--- PASS: TestComputeAddsUpTheRewardFromTheFailToPassScenariosOnly (0.00s)
--- PASS: TestPassToPassIsReportedOnItsOwnAndNeverChangesTheReward (0.00s)
--- PASS: TestACategoryWithNoFailToPassScenarioCountsZero (0.00s)
--- PASS: TestASkippedScenarioIsNotAPass (0.00s)
--- PASS: TestAScenarioOnOneSideOnlyIsAnErrorNeverAPass (0.00s)
--- PASS: TestComputeRefusesWhatCannotBeScored (0.00s)
--- PASS: TestScoreJSONIsTheContract (0.03s)
--- PASS: TestWriteRefusesARunFolderThatIsNotAbsoluteAndWritesNothing (0.00s)
--- PASS: TestWriteMakesOneFileInTheRunFolderAndNothingBesideIt (0.01s)
ok  	github.com/ouroboric-dev/odin/internal/score	1.051s
```

**Evidence (v0-T248):** built and run in the reference workspace on 2026-10-18 as commits `6d08bd9` and `654dc8c` (not pushed). Tests first: both builds failed as in steps 2 and 6, then every test passed. `gofmt -l .` and `go vet ./...` print nothing; `go test -race -count=1 ./internal/score`: `ok`. Three mutations were tried, each undone: Compute ignoring a scenario that was not run (`TestAScenarioOnOneSideOnlyIsAnErrorNeverAPass` failed); pass-to-pass scenarios counted in the categories (six tests failed, among them `TestPassToPassIsReportedOnItsOwnAndNeverChangesTheReward`); `failed` read as a pass (the first version of the tests did not catch it, so `TestAFailedLastTryIsAFailureWhateverCameBefore` was added, and then failed). Not run: a real Playwright report; the shape is the JSON reporter's as described by the contract and as the sample suite of mimir writes it, but the sample suite was not run in a container (v0-H16).

### Task v0-T249: the `grade` stage in the engine

Odin's third task of the grader. It needs v0-T248. Three commits: part 1 gives the run a grader and the export, part 2 is the stage, part 3 pins the failure paths and the isolation.

**Files (in `odin`):**

- Create: `internal/task/tasktest/tasktest.go`, `internal/run/grade.go`, `internal/run/grade_test.go`, `internal/engine/grade.go`, `internal/engine/grade_test.go`, `internal/engine/grade_failure_test.go`, `internal/engine/grade_isolation_test.go`
- Modify: `internal/run/run.go` (hooks, the `Grader` field, `checkNode`), `internal/engine/engine.go` (one `case`)

**Interfaces:**

- Consumes: `schema.KindGrade` and `schema.Factory.Grader` (v0-T245); `sandbox.GradeSpec`, `GradeResult`, `GraderImage`, `(*Driver).Grade` (v0-T246); `task.Load` (v0-T247); `score.ReadResults`, `Compute`, `Write` (v0-T248); `snapshot.Export` and `Run.snapshotSources` (v0-T238).
- Produces: `run.Grader` (one method, `Grade(ctx, sandbox.GradeSpec) (sandbox.GradeResult, error)`; `*sandbox.Driver` is the real one), `run.Hooks.NewGrader` (tests give a fake), `Run.Grader` (nil unless the config has both a `grader:` and a `sandbox:` section; the driver gets a configuration folder of its own, `<run>/grader`).
- Produces: `Run.GradeDir()` (`<run>/grade`), `Run.ExportApp(ctx, dst)` (the committed files of the project umbrella and of each leaf at the commit the umbrella records, no git dir; `dst` is emptied first) and `Run.NoSandboxesLeft()`.
- Produces: a graph with a `grade` node is refused at `Prepare` when the config lacks the `grader:` or the `sandbox:` section.
- Produces: `engine.Grade(ctx, r, taskID) (*Graded{Score, Path}, error)` and the `grade` node. `taskID` "" reads the task from the run's brief (decision 3). The order of `Grade`:
  1. Stop every sandbox of the run (`DownSandboxes`) and refuse to go on if one is still recorded as up (`*GradeFailed`).
  2. Find the task; `task.Load`; compare the run's brief hash with the task's; compute the image tag (`sandbox.GraderImage`). Any refusal here writes `grade_refused` (`task`, `suite`, `reason`) and returns a `*task.Refusal`. Nothing is built, exported or run.
  3. Write `grade_started` (`task`, `suite`, `brief_sha256`, `image`).
  4. Export `/app` to `<run>/grade/app`; make an empty `<run>/grade/logs-<time>`.
  5. Call the grader with `Tests` = the suite's tests folder, `Timeout` = the smaller of `grader.timeout` and the task's, `Memory`, `CPUs`, `Env` = `verifier.env`.
  6. Write the container's output to `<run>/grade/grade.log` (mode `0600`).
  7. Read `results.json`, compute, write `<run>/score.json`, write `grade_finished` (`task`, `suite`, `score_path`, `reward`, `fail_to_pass` "p/t", `pass_to_pass`).
  A grader error, a timeout, no `results.json`, or a report that can't be read is a `*GradeFailed`: the node fails, the run stops failed, and `ygg resume` grades again. A mismatch between report and manifest is `grade_refused` with `bad_manifest` (decision 4).
- The grader sees three folders: `/app` (a copy, in the run folder), `/tests` (the suite's tests folder, read only, and nothing else of the store) and `/logs/verifier`. No agent sandbox is ever given the store (`SandboxSpec` has no field for it), and the stage starts after the last sandbox stopped. The tests below walk every field of every `SandboxSpec` and `Cmd` of a full fake run.

**Acceptance criteria:**

- [ ] `TestGraderCombinesPublicTaskAndHiddenSuite`: the spec given to the fake grader has the environment from `tasks_dir`, the tests from `suite_dir`, the run's id, the smaller timeout, the limits and the env; `score.json` names the task, its version, the brief's SHA-256 and the suite; the ledger has `grade_started` and `grade_finished` with every field.
- [ ] Each of the five refusals stops the run failed with its reason in the error, calls the grader zero times, exports nothing, writes no `score.json`, and leaves `grade_refused` (and no `grade_started`) in the ledger. A run built from another brief than the task's is refused as `brief_changed`.
- [ ] A report missing a scenario, or holding one the manifest does not know, leaves no `score.json`, and the ledger has `grade_started` and `grade_refused` with `bad_manifest`.
- [ ] A grader error fails the node; a second `Advance` grades again and scores. A suite that wrote no results is a failure.
- [ ] When the fake grader runs, the leaf's, the scratch agent's and a snapshot sandbox are all down and none is recorded in `run.json`.
- [ ] `/app` holds `umbrella.yaml` and `repos/app/README.md`; it holds no `.git`, no `.factory`, no uncommitted file, no `score.json`.
- [ ] `score.json` is in the run folder; it is in no leaf's working copy, no scratch workspace, no `/app`; the project and its leaf track no file of it.
- [ ] No string of any `SandboxSpec` or `Cmd` of the fake sandbox, and no prompt of an agent, holds the path of `grader.suite_dir`. The walker itself is tested: it finds the path in a spec and in a command that hold it.

**Review focus pinned by tests:**

- No agent path to the hidden suite: `TestNoAgentSandboxOrCommandEverHoldsTheSuiteFolder`, `TestTheWalkerThatGuardsTheSuiteFolderFindsItWhereItIs`.
- Grading beside a live sandbox: `TestGradingStartsOnlyAfterEverySandboxHasStopped`.
- The score where an agent can read it: `TestScoreJSONIsInNoLeafAndNoTree`.
- An uncommitted or ignored file graded as the product: `TestTheGraderGetsTheCommittedProjectAsAppAndNothingElse`, `TestExportAppIsTheProjectAsCommittedAndNothingMore`.
- A refusal that builds first: `TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt`.
- A brief or a task version that does not match the build: `TestARunBuiltFromAnotherBriefThanTheTasksIsRefused`.
- A mismatch read as a pass: `TestAResultsFileThatDoesNotMatchTheManifestIsRefusedAsBadManifest`.
- A suite that wrote nothing read as a pass: `TestASuiteThatWritesNoResultsIsAFailureNotAPass`.
- A graph that grades without the sections: `TestAGradeNodeNeedsTheGraderAndTheSandboxSections`.

**Named tests:** `TestGraderCombinesPublicTaskAndHiddenSuite` (`go test ./internal/engine -run TestGraderCombinesPublicTaskAndHiddenSuite`) and, in v0-T247, `TestGraderRefusesRetiredVersion`. **Layer:** `odin`. **Size:** M, L and M (304, 410, 271). **Depends on:** v0-T248.

#### Part 1: a run can hold a grader

- [ ] **Step 1:** write the fixture and the tests first. Create `internal/task/tasktest/tasktest.go` (a fake task and a made-up stand-in for a suite; it holds no real scenario) and `internal/run/grade_test.go`:

```go
// Package tasktest writes a tiny benchmark task and a tiny stand-in for its hidden suite into a
// temporary folder, for tests of the grader. The suite is made up: it holds no real scenario.
package tasktest

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"testing"
)

// Brief is the text of the task's instruction.md.
const Brief = "# Tiny\n\nBuild a tiny product.\n"

// Manifest is the stand-in suite's manifest: two fail-to-pass scenarios in core, one in security, one
// pass-to-pass in core. Weights are core 0.6 and security 0.4.
const Manifest = `{"schema":"ygg.suite/v1","suite":"v1","scenarios":[
 {"id":"a thing works","category":"core","kind":"fail-to-pass"},
 {"id":"a thing stays","category":"core","kind":"pass-to-pass"},
 {"id":"a second thing works","category":"core","kind":"fail-to-pass"},
 {"id":"a thing is private","category":"security","kind":"fail-to-pass"}]}`

// Titles are the scenario ids of Manifest, in its order.
var Titles = []string{"a thing works", "a thing stays", "a second thing works", "a thing is private"}

// Task is a written task: TasksDir/tiny-task is its public half, SuiteDir/tiny-task/v1 the stand-in
// for the hidden half. The two folders are apart, as the factory config demands.
type Task struct {
	ID       string
	TasksDir string
	SuiteDir string
	Dir      string // TasksDir/tiny-task
	Tests    string // SuiteDir/tiny-task/v1/tests
}

// Brief returns the path of the task's instruction.md, which a run takes as its brief.
func (k *Task) Brief() string { return filepath.Join(k.Dir, "instruction.md") }

// New writes the task and the stand-in suite into a temporary folder of t.
func New(t *testing.T) *Task {
	t.Helper()
	root := t.TempDir()
	k := &Task{ID: "tiny-task", TasksDir: filepath.Join(root, "tasks"), SuiteDir: filepath.Join(root, "suites")}
	k.Dir = filepath.Join(k.TasksDir, k.ID)
	k.Tests = filepath.Join(k.SuiteDir, k.ID, "v1", "tests")
	sum := sha256.Sum256([]byte(Brief))
	toml := "artifacts = [\"/app\"]\n\n[task]\nname = \"ouroboric-dev/tiny-task\"\nversion = \"2.1.0\"\n\n" +
		"[metadata]\nbrief_sha256 = \"" + hex.EncodeToString(sum[:]) + "\"\nsuite = \"v1\"\n\n" +
		"[verifier]\ntimeout_sec = 300.0\nenvironment_mode = \"separate\"\n\n[verifier.env]\nWORKERS = \"2\"\nSCORE_WEIGHTS = \"core=0.6,security=0.4\"\n"
	for p, body := range map[string]string{
		filepath.Join(k.Dir, "task.toml"):                 toml,
		filepath.Join(k.Dir, "instruction.md"):            Brief,
		filepath.Join(k.Dir, "environment", "Dockerfile"): "FROM scratch\n",
		filepath.Join(k.Tests, "test.sh"):                 "#!/bin/bash\nexit 0\n",
		filepath.Join(k.Tests, "manifest.json"):           Manifest,
	} {
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return k
}

// Results is a Playwright report for the stand-in suite: one spec for each title, with the status given
// for it ("passed" when the title is not in status).
func Results(status map[string]string) string {
	out := `{"suites":[{"title":"stand-in.spec.ts","specs":[`
	for i, title := range Titles {
		st := status[title]
		if st == "" {
			st = "passed"
		}
		if i > 0 {
			out += ","
		}
		out += `{"title":"` + title + `","tests":[{"results":[{"status":"` + st + `"}]}]}`
	}
	return out + `]}]}`
}
```

```go
package run

import (
	"context"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gleipnir/sandbox"
	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/sandboxfake"
	"github.com/ouroboric-dev/odin/internal/task/tasktest"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

type noGrader struct{}

func (noGrader) Grade(context.Context, sandbox.GradeSpec) (sandbox.GradeResult, error) {
	return sandbox.GradeResult{}, nil
}

// graderBlock is a grader section for the task tk.
func graderBlock(tk *tasktest.Task) string {
	return "grader:\n  tasks_dir: " + tk.TasksDir + "\n  suite_dir: " + tk.SuiteDir + "\n  timeout: 30m\n  memory: 4g\n  cpus: 4\n"
}

// gradeRealm is the toy sandbox realm with a grade node added to the end of its graph.
func gradeRealm(t *testing.T) string {
	t.Helper()
	dir := filepath.Join(t.TempDir(), "toy")
	if err := os.CopyFS(dir, os.DirFS(toySandbox(t))); err != nil {
		t.Fatal(err)
	}
	g, _ := os.ReadFile(filepath.Join(dir, "graph.yaml"))
	if err := os.WriteFile(filepath.Join(dir, "graph.yaml"), append(g, []byte("  - { id: score, kind: grade }\n")...), 0o644); err != nil {
		t.Fatal(err)
	}
	return dir
}

func TestAGradeNodeNeedsTheGraderAndTheSandboxSections(t *testing.T) {
	tk := tasktest.New(t)
	script := filepath.Join(toySandbox(t), "script.yaml")
	head := "roles:\n  planner: { agent: scripted, model: none, script: " + script + " }\n  implementer: { agent: scripted, model: none, script: " + script + " }\n" + fullCaps
	for name, body := range map[string]string{
		"no grader section":  head + sandboxSection,
		"no sandbox section": head + graderBlock(tk),
	} {
		t.Run(name, func(t *testing.T) {
			cfg := filepath.Join(t.TempDir(), "factory.yaml")
			os.WriteFile(cfg, []byte(body), 0o644)
			_, err := Prepare(ctx, Options{Project: treetest.Project(t, "repos/app"), Config: cfg, Realm: gradeRealm(t)})
			if err == nil || !strings.Contains(err.Error(), "node score") || !strings.Contains(err.Error(), "grader and the sandbox sections") {
				t.Errorf("Prepare() = %v, want a refusal that names the node and the sections", err)
			}
		})
	}
}

func TestTheRunHoldsAGraderOnlyWithBothSections(t *testing.T) {
	tk := tasktest.New(t)
	for name, c := range map[string]struct {
		extra string
		want  bool
	}{"with the grader section": {graderBlock(tk), true}, "without": {"", false}} {
		t.Run(name, func(t *testing.T) {
			made := 0
			h := Hooks{
				NewSandbox: func(*SandboxSetup, string) (gungnir.Sandbox, error) { return &sandboxfake.Sandbox{}, nil },
				NewGrader:  func(*SandboxSetup, string) (Grader, error) { made++; return noGrader{}, nil },
			}
			realm := toySandbox(t)
			r, err := Start(ctx, Options{Project: treetest.Project(t, "repos/app"), Config: sandboxConfig(t, "{ agent: scripted, model: none, script: "+filepath.Join(realm, "script.yaml")+" }", c.extra), Realm: realm, Hooks: h})
			if err != nil {
				t.Fatal(err)
			}
			defer r.Close()
			if (r.Grader != nil) != c.want || (made == 1) != c.want {
				t.Errorf("grader %v, made %d; want a grader: %v", r.Grader, made, c.want)
			}
		})
	}
}

func TestExportAppIsTheProjectAsCommittedAndNothingMore(t *testing.T) {
	realm := toySandbox(t)
	h := Hooks{NewSandbox: func(*SandboxSetup, string) (gungnir.Sandbox, error) { return &sandboxfake.Sandbox{}, nil }}
	r, err := Start(ctx, Options{Project: treetest.Project(t, "repos/app"), Config: sandboxConfig(t, "{ agent: scripted, model: none, script: "+filepath.Join(realm, "script.yaml")+" }", ""), Realm: realm, Hooks: h})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	os.WriteFile(filepath.Join(r.Project, "stray.txt"), []byte("not committed\n"), 0o644)
	dst := filepath.Join(r.GradeDir(), "app")
	os.MkdirAll(dst, 0o755)
	os.WriteFile(filepath.Join(dst, "left-from-before.txt"), []byte("old\n"), 0o644)
	if err := r.ExportApp(ctx, dst); err != nil {
		t.Fatalf("ExportApp() = %v", err)
	}
	var files []string
	filepath.WalkDir(dst, func(p string, d fs.DirEntry, _ error) error {
		if rel, _ := filepath.Rel(dst, p); !d.IsDir() {
			files = append(files, filepath.ToSlash(rel))
		}
		return nil
	})
	for _, want := range []string{"umbrella.yaml", "repos/app/README.md"} {
		if !slices.Contains(files, want) {
			t.Errorf("the export lacks %s: %v", want, files)
		}
	}
	for _, f := range files {
		for _, part := range strings.Split(f, "/") {
			if slices.Contains([]string{".git", ".factory", "stray.txt", "left-from-before.txt"}, part) {
				t.Errorf("the export holds %s", f)
			}
		}
	}
}

func TestNoSandboxesLeftRefusesWhileOneIsRecordedAsUp(t *testing.T) {
	r := &Run{State: &State{}}
	if err := r.NoSandboxesLeft(); err != nil {
		t.Errorf("NoSandboxesLeft() = %v on a run with none", err)
	}
	r.State.Sandboxes = map[string]gungnir.Env{"repos/app": {Name: "repos/app"}}
	if err := r.NoSandboxesLeft(); err == nil || !strings.Contains(err.Error(), "still up") {
		t.Errorf("NoSandboxesLeft() = %v, want a refusal", err)
	}
}
```

- [ ] **Step 2:** run them. They must not build.

```bash
go test ./internal/run -run 'Grade|Grader|Export|NoSandboxes'
```

Real output:

```text
# github.com/ouroboric-dev/odin/internal/run [github.com/ouroboric-dev/odin/internal/run.test]
internal/run/grade_test.go:73:5: unknown field NewGrader in struct literal of type Hooks
internal/run/grade_test.go:73:46: undefined: Grader
internal/run/grade_test.go:81:10: r.Grader undefined (type *Run has no field or method Grader)
internal/run/grade_test.go:82:57: r.Grader undefined (type *Run has no field or method Grader)
internal/run/grade_test.go:97:25: r.GradeDir undefined (type *Run has no field or method GradeDir)
internal/run/grade_test.go:100:14: r.ExportApp undefined (type *Run has no field or method ExportApp)
internal/run/grade_test.go:126:14: r.NoSandboxesLeft undefined (type *Run has no field or method NoSandboxesLeft)
internal/run/grade_test.go:130:14: r.NoSandboxesLeft undefined (type *Run has no field or method NoSandboxesLeft)
FAIL	github.com/ouroboric-dev/odin/internal/run [build failed]
FAIL
```

- [ ] **Step 3:** create `internal/run/grade.go` and apply to `internal/run/run.go`:

```go
package run

import (
	"context"
	"fmt"
	"path/filepath"

	"github.com/ouroboric-dev/gleipnir/sandbox"
	"github.com/ouroboric-dev/odin/internal/snapshot"
)

// Grader runs the hidden suite of a task in a container of its own (spec §11). Gleipnir's driver is the
// real one; tests give a fake. It is not a gungnir.Sandbox: no agent ever has a Grader, and the engine
// reaches it only in the grade stage, after every sandbox has stopped.
type Grader interface {
	Grade(ctx context.Context, g sandbox.GradeSpec) (sandbox.GradeResult, error)
}

// NewGrader builds the grader of a run. dir is a folder of the run where the driver keeps its
// configuration. Tests replace it with a fake.
type NewGrader func(s *SandboxSetup, dir string) (Grader, error)

// defaultGrader is the devcontainer driver on the engine factory.yaml names, with a configuration folder
// of its own, so that it shares nothing with the driver of the sandboxes.
func defaultGrader(s *SandboxSetup, dir string) (Grader, error) {
	return sandbox.New(s.Engine, s.Config, dir)
}

// openGrader gives the run its grader, when its config has both a grader and a sandbox section: the
// sandbox section names the engine that runs the grader's container.
func (r *Run) openGrader(open NewGrader) error {
	if r.Setup.Config.Grader == nil || r.Setup.Sandbox == nil {
		return nil
	}
	if open == nil {
		open = defaultGrader
	}
	var err error
	r.Grader, err = open(r.Setup.Sandbox, filepath.Join(r.Dir, "grader"))
	return err
}

// GradeDir is the folder of the run that holds what grading makes: the exported /app, the logs of each
// grading run and its container's output. It is in the run folder, which no sandbox mounts.
func (r *Run) GradeDir() string { return filepath.Join(r.Dir, "grade") }

// ExportApp writes the project as it is committed to dst: the files of the project umbrella and of each
// leaf at the commit the umbrella records, with no git directory and nothing a working copy ignores
// (the snapshot of v0-T238). dst is emptied first. The result is what a grader's /app holds.
func (r *Run) ExportApp(ctx context.Context, dst string) error {
	sources, err := r.snapshotSources(ctx, nil)
	if err != nil {
		return &SnapshotError{err}
	}
	if err := snapshot.Export(ctx, dst, sources); err != nil {
		return &SnapshotError{err}
	}
	return nil
}

// NoSandboxesLeft refuses to go on while a sandbox of the run is recorded as up: grading starts only
// after every agent sandbox has stopped (spec §11).
func (r *Run) NoSandboxesLeft() error {
	if len(r.State.Sandboxes) > 0 {
		return fmt.Errorf("%d sandbox(es) of the run are still up; grading starts only after every sandbox has stopped (ygg doctor stops them)", len(r.State.Sandboxes))
	}
	return nil
}
```

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index eb483b9..c23ad5b 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -47,6 +47,7 @@ type Options struct {
 type Hooks struct {
 	Libs       *skills.Libraries
 	NewSandbox NewSandbox
+	NewGrader  NewGrader
 	Now        func() time.Time
 	Backoff    *jormungandr.Backoff
 	Sleep      func(ctx context.Context, d time.Duration) error
@@ -72,6 +73,7 @@ type Setup struct {
 	Skills       skills.Record            // every skill the graph names, with the set's hash
 	Sandbox      *SandboxSetup            // nil: no sandbox section, so leaf commands run on the host
 	newSandbox   NewSandbox
+	newGrader    NewGrader
 	Journal      *budget.Journal // where every session's usage is recorded, and the per-day cap is summed
 	Backoff      jormungandr.Backoff
 	Sleep        func(ctx context.Context, d time.Duration) error // nil: wait for real
@@ -157,7 +159,7 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 	if err := s.prepareBudget(o.Hooks); err != nil {
 		return nil, err
 	}
-	s.newSandbox = o.Hooks.NewSandbox
+	s.newSandbox, s.newGrader = o.Hooks.NewSandbox, o.Hooks.NewGrader
 	if err := s.prepareSandbox(); err != nil {
 		return nil, err
 	}
@@ -226,6 +228,13 @@ func (s *Setup) findProject(ctx context.Context, project string) error {
 // checkNode checks that node n can run in this project: its repo, its role and prompt, its checks.
 func (s *Setup) checkNode(ctx context.Context, graphPath string, n schema.Node) error {
 	switch {
+	case n.Kind == schema.KindGrade:
+		// Grading runs the hidden suite in a container of the engine the sandbox section names, so a graph
+		// with a grade node needs both sections, before anything runs.
+		if s.Config.Grader == nil || s.Config.Sandbox == nil {
+			return fmt.Errorf("%s: node %s grades the run, which needs the grader and the sandbox sections in %s", graphPath, n.ID, s.ConfigPath)
+		}
+		return nil
 	case n.Kind == schema.KindGate, n.Kind == schema.KindPublish, n.Kind == schema.KindTasks, n.Kind == schema.KindInit:
 		return nil // they work in the project, not in a leaf
 	case n.Kind == schema.KindForeach:
@@ -517,6 +526,7 @@ type Run struct {
 	Saved    []string        // one note per leaf whose discarded changes Open saved to a ref, or discarded unsaved, before resetting it
 	SetAside []string        // the notes of Saved from the set-aside of a session whose spend the journal couldn't take, for its gate (review I4)
 	Sandbox  gungnir.Sandbox // runs the leaves' commands; nil when the config has no sandbox section
+	Grader   Grader          // runs the hidden suite; nil unless the config has a grader and a sandbox section
 	nodes    []schema.Node   // the nodes of the run, with foreach nodes expanded; see Nodes
 }
 
@@ -806,6 +816,11 @@ func Start(ctx context.Context, o Options) (*Run, error) {
 		os.RemoveAll(dir)
 		return nil, err
 	}
+	if err := r.openGrader(setup.newGrader); err != nil {
+		r.Close()
+		os.RemoveAll(dir)
+		return nil, err
+	}
 	if err := r.begin(ctx); err != nil {
 		r.State.Status, r.State.Error = StatusFailed, err.Error()
 		r.Log(gungnir.Event{Name: gungnir.EventRunFailed, Result: r.State.Error})
@@ -1058,6 +1073,10 @@ func open(ctx context.Context, project, dir string, mode gungnir.Mode, h Hooks)
 		l.Close()
 		return nil, err
 	}
+	if err := r.openGrader(setup.newGrader); err != nil {
+		l.Close()
+		return nil, err
+	}
 	// A ygg that was killed leaves its sandboxes up: stop them before the run goes on.
 	if err := r.DownSandboxes(ctx); err != nil {
 		l.Close()
```

- [ ] **Step 4:** run the tests, then commit.

```bash
gofmt -l . ; go vet ./...
go test -race -count=1 ./internal/run ./internal/task/...
git add internal/run/grade.go internal/run/run.go internal/run/grade_test.go internal/task/tasktest/tasktest.go
git commit -m "A run can hold a grader: the grade node's sections, the project exported as /app, no sandbox left up (v0-T249)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

Expected: `ok  	github.com/ouroboric-dev/odin/internal/run	24.283s`, `ok  .../internal/task	1.123s` and `?   	.../internal/task/tasktest	[no test files]`.

#### Part 2: the stage

- [ ] **Step 5:** write the tests first. Create `internal/engine/grade_test.go` (the fake grader, the helper that starts a graded run, and the flow tests):

```go
package engine

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/ouroboric-dev/gleipnir/sandbox"
	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/sandboxfake"
	"github.com/ouroboric-dev/odin/internal/task/tasktest"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

// fakeGrader stands in for Gleipnir's driver. It writes Results to the logs folder it is given, as the
// hidden suite's test.sh would, and lists the exported /app as it is at that moment.
type fakeGrader struct {
	mu      sync.Mutex
	Specs   []sandbox.GradeSpec
	Apps    [][]string // the files of /app, for each call
	Results string     // the report to write; "" writes none
	Err     error      // what Grade returns
	Before  func(sandbox.GradeSpec)
}

func (f *fakeGrader) Grade(_ context.Context, g sandbox.GradeSpec) (sandbox.GradeResult, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.Specs = append(f.Specs, g)
	var files []string
	filepath.WalkDir(g.App, func(p string, d fs.DirEntry, _ error) error {
		rel, _ := filepath.Rel(g.App, p)
		files = append(files, filepath.ToSlash(rel))
		return nil
	})
	f.Apps = append(f.Apps, files)
	if f.Before != nil {
		f.Before(g)
	}
	if f.Err != nil {
		return sandbox.GradeResult{Image: "localhost/ygg-grader-fake"}, f.Err
	}
	if f.Results != "" {
		if err := os.WriteFile(filepath.Join(g.Logs, "results.json"), []byte(f.Results), 0o644); err != nil {
			return sandbox.GradeResult{}, err
		}
	}
	return sandbox.GradeResult{Image: "localhost/ygg-grader-fake", Log: "suite output\n"}, nil
}

// graded is a run with a sandbox, a grader block and a task: the pieces a test needs to look at.
type graded struct {
	r      *run.Run
	box    *sandboxfake.Sandbox
	grader *fakeGrader
	task   *tasktest.Task
}

// gradedPack is the sandbox pack with an acceptance stack, so a test can bring up a snapshot sandbox.
var gradedPack = strings.Replace(sandboxPack, "  egress:", "  acceptance: { stack: docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514 }\n  egress:", 1)

const gradedNodes = buildNodes +
	"  - { id: design, kind: agent, role: planner, prompt: p.md, scratch: true }\n" +
	"  - { id: check, kind: exec, run: [grep, -q, done, build.txt], repo: repos/app }\n" +
	"  - { id: score, kind: grade }\n"

const gradedScript = buildScript +
	"  design:\n    - actions: [ { write: { path: out/design.md, content: \"# Design\\n\" } } ]\n      result: { status: ok, summary: designed }\n"

// startGraded starts a run of nodes whose brief is the task's instruction.md, with the fake sandbox and the
// fake grader. results is what the fake suite writes.
func startGraded(t *testing.T, nodes, results string, edit func(*tasktest.Task)) *graded {
	t.Helper()
	tk := tasktest.New(t)
	if edit != nil {
		edit(tk)
	}
	realm, cfg := t.TempDir(), t.TempDir()
	project := treetest.Project(t, "repos/app")
	tmpl := filepath.Join(realm, "t")
	os.MkdirAll(tmpl, 0o755)
	files := map[string]string{
		filepath.Join(tmpl, "LICENSE"):     "MIT\n",
		filepath.Join(realm, "pack.yaml"):  "name: test\nversion: 0.1.0\ngraph: graph.yaml\n" + gradedPack,
		filepath.Join(realm, "graph.yaml"): "name: test\nversion: 1.0.0\nnodes:\n" + nodes,
		filepath.Join(realm, "p.md"):       "Do the work.\n",
		filepath.Join(cfg, "script.yaml"):  gradedScript,
		filepath.Join(cfg, "factory.yaml"): "mode: unattended\ngates: { design: auto }\nroles:\n  planner: { agent: scripted, model: none, script: script.yaml }\n" +
			"budget:\n  per_run: { tokens: 100000, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\n" +
			"sandbox:\n  engine: unix:///run/ygg-test.sock\n" +
			"grader:\n  tasks_dir: " + tk.TasksDir + "\n  suite_dir: " + tk.SuiteDir + "\n  timeout: 30m\n  memory: 4g\n  cpus: 4\n",
	}
	for p, body := range files {
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	g := &graded{box: &sandboxfake.Sandbox{}, grader: &fakeGrader{Results: results}, task: tk}
	h := run.Hooks{
		NewSandbox: func(*run.SandboxSetup, string) (gungnir.Sandbox, error) { return g.box, nil },
		NewGrader:  func(*run.SandboxSetup, string) (run.Grader, error) { return g.grader, nil },
	}
	r, err := run.Start(context.Background(), run.Options{Project: project, Config: filepath.Join(cfg, "factory.yaml"), Realm: realm, Brief: tk.Brief(), Hooks: h})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { r.Close() })
	g.r = r
	return g
}

func (g *graded) advance(t *testing.T) Outcome {
	t.Helper()
	out, err := Advance(context.Background(), g.r)
	if err != nil {
		t.Fatalf("Advance() = %v", err)
	}
	return out
}

func readScore(t *testing.T, r *run.Run) gungnir.Score {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(r.Dir, "score.json"))
	if err != nil {
		t.Fatalf("score.json: %v", err)
	}
	var s gungnir.Score
	if err := json.Unmarshal(b, &s); err != nil {
		t.Fatal(err)
	}
	return s
}

func TestGraderCombinesPublicTaskAndHiddenSuite(t *testing.T) {
	g := startGraded(t, gradedNodes, tasktest.Results(map[string]string{"a thing is private": "failed"}), nil)
	if out := g.advance(t); out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v", out)
	}
	if len(g.grader.Specs) != 1 {
		t.Fatalf("%d grading runs, want 1", len(g.grader.Specs))
	}
	spec := g.grader.Specs[0]
	// The image comes from the public task, the tests from the hidden store, and nothing else is given.
	if spec.Task != "tiny-task" || spec.Run != g.r.State.ID || spec.Environment != filepath.Join(g.task.Dir, "environment") || spec.Tests != g.task.Tests {
		t.Errorf("spec = %+v", spec)
	}
	if spec.App != filepath.Join(g.r.Dir, "grade", "app") || !strings.HasPrefix(spec.Logs, filepath.Join(g.r.Dir, "grade")+string(filepath.Separator)) {
		t.Errorf("the app and logs folders = %s, %s; want them in the run folder", spec.App, spec.Logs)
	}
	// 5 minutes is the task's verifier timeout, under the factory's 30.
	if spec.Timeout != 5*time.Minute || spec.Memory != "4g" || spec.CPUs != 4 || spec.Env["WORKERS"] != "2" || spec.Env["SCORE_WEIGHTS"] == "" {
		t.Errorf("limits = %v %s %d %v", spec.Timeout, spec.Memory, spec.CPUs, spec.Env)
	}
	sum := sha256.Sum256([]byte(tasktest.Brief))
	s := readScore(t, g.r)
	if s.Task != "tiny-task" || s.TaskVersion != "2.1.0" || s.Suite != "v1" || s.BriefSHA256 != hex.EncodeToString(sum[:]) || s.Run != g.r.State.ID {
		t.Errorf("score = %+v", s)
	}
	if s.FailToPass != (gungnir.Tally{Passed: 2, Total: 3}) || s.PassToPass != (gungnir.Tally{Passed: 1, Total: 1}) || s.Reward < 0.6-1e-9 || s.Reward > 0.6+1e-9 {
		t.Errorf("score = %+v", s)
	}
	text := ledgerText(t, g.r)
	for _, want := range []string{`"event":"grade_started"`, `"ygg.task.id":"tiny-task"`, `"ygg.grade.suite":"v1"`, `"ygg.grade.brief_sha256":"` + hex.EncodeToString(sum[:]) + `"`,
		`"ygg.grade.image":"localhost/ygg-grader-tiny-task:`, `"event":"grade_finished"`, `"ygg.grade.score_path":"` + filepath.Join(g.r.Dir, "score.json") + `"`,
		`"ygg.grade.fail_to_pass":"2/3"`, `"ygg.grade.pass_to_pass":"1/1"`, `"ygg.grade.reward":0.6`} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s:\n%s", want, text)
		}
	}
	if b, _ := os.ReadFile(filepath.Join(g.r.Dir, "grade", "grade.log")); string(b) != "suite output\n" {
		t.Errorf("grade.log = %q", b)
	}
}

// refusals writes the five ways grading is refused before a container is built.
var refusals = map[string]struct {
	edit   func(k *tasktest.Task)
	reason gungnir.GradeReason
}{
	"retired": {func(k *tasktest.Task) {
		os.MkdirAll(filepath.Join(k.Dir, "retired"), 0o755)
		os.WriteFile(filepath.Join(k.Dir, "retired", "v1"), []byte("retired\n"), 0o644)
	}, gungnir.GradeRetired},
	"missing_suite": {func(k *tasktest.Task) { os.RemoveAll(filepath.Join(k.SuiteDir, k.ID)) }, gungnir.GradeMissingSuite},
	"brief_changed": {func(k *tasktest.Task) { // task.toml still names the hash of the old text
		os.WriteFile(filepath.Join(k.Dir, "instruction.md"), []byte(tasktest.Brief+"One more line.\n"), 0o644)
	}, gungnir.GradeBriefChanged},
	"bad_manifest": {func(k *tasktest.Task) {
		os.WriteFile(filepath.Join(k.Tests, "manifest.json"), []byte(`{"schema":`), 0o644)
	}, gungnir.GradeBadManifest},
	"bad_task": {func(k *tasktest.Task) {
		b, _ := os.ReadFile(filepath.Join(k.Dir, "task.toml"))
		os.WriteFile(filepath.Join(k.Dir, "task.toml"), []byte(strings.Replace(string(b), `"separate"`, `"shared"`, 1)), 0o644)
	}, gungnir.GradeBadTask},
}

func TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt(t *testing.T) {
	for name, c := range refusals {
		t.Run(name, func(t *testing.T) {
			g := startGraded(t, gradedNodes, tasktest.Results(nil), nil)
			c.edit(g.task)
			out := g.advance(t)
			if out.Status != run.StatusFailed || out.Err == nil || !strings.Contains(out.Err.Error(), string(c.reason)) {
				t.Fatalf("Advance() = %+v, want a failed run whose error says %s", out, c.reason)
			}
			if len(g.grader.Specs) != 0 {
				t.Errorf("the grader was called %d time(s) after a refusal", len(g.grader.Specs))
			}
			if _, err := os.Stat(filepath.Join(g.r.Dir, "score.json")); err == nil {
				t.Error("a refused run has a score.json")
			}
			if _, err := os.Stat(filepath.Join(g.r.Dir, "grade", "app")); err == nil {
				t.Error("a refused run exported /app")
			}
			text := ledgerText(t, g.r)
			if !strings.Contains(text, `"event":"grade_refused"`) || !strings.Contains(text, `"ygg.grade.reason":"`+string(c.reason)+`"`) || strings.Contains(text, `"event":"grade_started"`) {
				t.Errorf("the ledger:\n%s", text)
			}
		})
	}
}
```

- [ ] **Step 6:** run them. The graph has a grade node and the engine does not know it yet.

```bash
go test ./internal/engine -run 'Grader|Refusal'
```

Real output (first lines):

```text
--- FAIL: TestGraderCombinesPublicTaskAndHiddenSuite (0.36s)
    grade_test.go:149: 0 grading runs, want 1
--- FAIL: TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt (1.82s)
    --- FAIL: TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt/brief_changed (0.36s)
        grade_test.go:213: Advance() = {Status:done Gate: Err:<nil> Warn:[]}, want a failed run whose error says brief_changed
    --- FAIL: TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt/bad_manifest (0.37s)
        grade_test.go:213: Advance() = {Status:done Gate: Err:<nil> Warn:[]}, want a failed run whose error says bad_manifest
```

The run finished `done` and graded nothing: the node kind had no case (decision 9).

- [ ] **Step 7:** create `internal/engine/grade.go` and apply to `internal/engine/engine.go`:

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

	"github.com/ouroboric-dev/gleipnir/sandbox"
	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/score"
	"github.com/ouroboric-dev/odin/internal/task"
)

// Graded is what a grading run gave: the score and where score.json is.
type Graded struct {
	Score gungnir.Score
	Path  string
}

// GradeFailed is a grading run that could not finish: the container did not run or timed out, the
// suite wrote no readable results, or the project could not be exported. It is not a refusal and
// not a score. The run stops failed, and a resume grades again.
type GradeFailed struct{ Err error }

func (e *GradeFailed) Error() string { return "grading failed: " + e.Err.Error() }
func (e *GradeFailed) Unwrap() error { return e.Err }

// runGrade is the grade node (spec §11), the last node of a graph: it grades the project the run built.
func runGrade(ctx context.Context, r *run.Run, n schema.Node) error {
	attempt, err := startAttempt(r, n)
	if err != nil {
		return err
	}
	if err := r.Log(gungnir.Event{Name: gungnir.EventNodeStarted, Node: n.ID, Attempt: attempt}); err != nil {
		return err
	}
	began := time.Now()
	g, err := Grade(ctx, r, "")
	ev := gungnir.Event{Name: gungnir.EventNodeFinished, Node: n.ID, Attempt: attempt, DurationMS: time.Since(began).Milliseconds()}
	var refusal *task.Refusal
	var failed *GradeFailed
	switch {
	case err == nil:
		ev.Result = fmt.Sprintf("graded %s: reward %.4f (see score.json in the run folder)", g.Score.Task, g.Score.Reward)
		if err := r.Log(ev); err != nil {
			return err
		}
		r.State.Summaries[n.ID] = ev.Result
		return nil
	case errors.As(err, &refusal), errors.As(err, &failed):
		ev.Name, ev.Result = gungnir.EventNodeFailed, err.Error()
		if lerr := r.Log(ev); lerr != nil {
			return lerr
		}
		return &nodeFailure{err}
	}
	return err // the context ended, or the ledger or the disk failed: Odin's own
}

// Grade grades the project of run r against the hidden suite of a task, and writes score.json to the run
// folder (spec §11, change benchmark-split). taskID names the task; "" takes it from the run's brief,
// which must be the instruction.md of a task in grader.tasks_dir. Grading starts only after every
// sandbox of the run has stopped. It refuses, before it builds anything, with a *task.Refusal, which
// the ledger records as grade_refused; a failure of the grading run itself is a *GradeFailed.
//
// The container sees three folders and nothing else (v0-T246): /app, a copy of the project's committed
// files in the run folder; /tests, the suite's tests folder in the store, read only; and /logs/verifier,
// an empty folder in the run folder. The suite's folder is never given to an agent's sandbox.
func Grade(ctx context.Context, r *run.Run, taskID string) (*Graded, error) {
	cfg := r.Setup.Config.Grader
	if cfg == nil || r.Grader == nil {
		return nil, errors.New("grading needs the grader and the sandbox sections in factory.yaml")
	}
	if err := r.DownSandboxes(context.WithoutCancel(ctx)); err != nil {
		return nil, &GradeFailed{err}
	}
	if err := r.NoSandboxesLeft(); err != nil {
		return nil, &GradeFailed{err}
	}
	if taskID == "" {
		var ok bool
		if taskID, ok = taskOfBrief(cfg.TasksDir, r.State.Brief); !ok {
			return nil, refused(r, taskID, "", gungnir.GradeBadTask,
				"the run's brief %q is not the instruction.md of a task in %s, so the task to grade is not known (ygg grade --task names it)", r.State.Brief, cfg.TasksDir)
		}
	}
	t, err := task.Load(cfg.TasksDir, cfg.SuiteDir, taskID)
	var refusal *task.Refusal
	if errors.As(err, &refusal) {
		return nil, refused(r, taskID, "", refusal.Reason, "%s", refusal.Detail)
	} else if err != nil {
		return nil, err
	}
	if r.State.BriefSHA256 != t.BriefSHA256 {
		return nil, refused(r, taskID, t.Suite, gungnir.GradeBriefChanged,
			"the run was built from a brief that hashes to %q; the task's brief hashes to %s", r.State.BriefSHA256, t.BriefSHA256)
	}
	image, err := sandbox.GraderImage(t.ID, t.Environment)
	if err != nil {
		return nil, refused(r, taskID, t.Suite, gungnir.GradeBadTask, "%v", err)
	}
	if err := r.Log(gungnir.Event{Name: gungnir.EventGradeStarted, Task: t.ID, Suite: t.Suite, BriefSHA256: t.BriefSHA256, Image: image}); err != nil {
		return nil, err
	}
	started := time.Now().UTC()
	app, logs := filepath.Join(r.GradeDir(), "app"), filepath.Join(r.GradeDir(), "logs-"+started.Format("20060102-150405.000000"))
	if err := r.ExportApp(ctx, app); err != nil {
		return nil, &GradeFailed{err}
	}
	if err := os.MkdirAll(logs, 0o755); err != nil {
		return nil, err
	}
	res, err := r.Grader.Grade(ctx, sandbox.GradeSpec{Run: r.State.ID, Task: t.ID, Environment: t.Environment, App: app, Tests: t.Tests, Logs: logs,
		Timeout: min(time.Duration(cfg.Timeout), t.Timeout), Memory: cfg.Memory, CPUs: cfg.CPUs, Env: t.Env})
	if ctx.Err() != nil {
		return nil, ctx.Err()
	}
	// The container's output is for the operator: it goes to the run folder, never to an agent.
	if werr := os.WriteFile(filepath.Join(r.GradeDir(), "grade.log"), []byte(res.Log), 0o600); werr != nil {
		return nil, werr
	}
	if err != nil {
		return nil, &GradeFailed{err}
	}
	results, err := score.ReadResults(filepath.Join(logs, "results.json"))
	var mismatch *score.MismatchError
	if errors.As(err, &mismatch) {
		return nil, refused(r, t.ID, t.Suite, gungnir.GradeBadManifest, "%v", err)
	} else if err != nil {
		return nil, &GradeFailed{err}
	}
	s, err := score.Compute(score.Input{Run: r.State.ID, Task: t.ID, TaskVersion: t.Version, Suite: t.Suite, BriefSHA256: t.BriefSHA256,
		Manifest: t.Manifest, Weights: t.Weights, Started: started, Finished: time.Now().UTC()}, results)
	if errors.As(err, &mismatch) {
		return nil, refused(r, t.ID, t.Suite, gungnir.GradeBadManifest, "%v", err)
	} else if err != nil {
		return nil, &GradeFailed{err}
	}
	path, err := score.Write(r.Dir, s)
	if err != nil {
		return nil, err
	}
	reward := s.Reward
	if err := r.Log(gungnir.Event{Name: gungnir.EventGradeFinished, Task: t.ID, Suite: t.Suite, ScorePath: path, Reward: &reward,
		FailToPass: fmt.Sprintf("%d/%d", s.FailToPass.Passed, s.FailToPass.Total), PassToPass: fmt.Sprintf("%d/%d", s.PassToPass.Passed, s.PassToPass.Total)}); err != nil {
		return nil, err
	}
	return &Graded{Score: s, Path: path}, r.Save()
}

// refused records grade_refused in the ledger and returns the refusal. A failure to write the ledger is
// what comes back instead: Odin's own.
func refused(r *run.Run, taskID, suite string, reason gungnir.GradeReason, format string, a ...any) error {
	ref := &task.Refusal{Reason: reason, Detail: fmt.Sprintf(format, a...)}
	if err := r.Log(gungnir.Event{Name: gungnir.EventGradeRefused, Task: taskID, Suite: suite, Reason: reason}); err != nil {
		return err
	}
	return ref
}

// taskOfBrief returns the task id when brief is <tasksDir>/<id>/instruction.md.
func taskOfBrief(tasksDir, brief string) (string, bool) {
	if brief == "" {
		return "", false
	}
	rel, err := filepath.Rel(tasksDir, brief)
	parts := strings.Split(filepath.ToSlash(rel), "/")
	if err != nil || len(parts) != 2 || parts[1] != "instruction.md" {
		return "", false
	}
	return parts[0], true
}
```

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 3cf976b..2b98a02 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -101,6 +101,8 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 			err = runPublish(ctx, r, n)
 		case schema.KindInit:
 			err = runInit(ctx, r, n)
+		case schema.KindGrade:
+			err = runGrade(ctx, r, n)
 		}
 		var sb *sentBack
 		var ex *expanded
```

- [ ] **Step 8:** run the tests, then commit.

```bash
gofmt -l . ; go vet ./internal/engine
go test -race -count=1 -v -run 'Grader|Refusal' ./internal/engine 2>&1 | grep -E "^(--- |    ---|ok|FAIL)"
git add internal/engine/engine.go internal/engine/grade.go internal/engine/grade_test.go
git commit -m "The grade stage: grade the committed project against the task's hidden suite and write score.json to the run folder (v0-T249)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

Real output (the two tests of this step; the filter also matches two older tests with "Refusal" in the name):

```text
--- PASS: TestGraderCombinesPublicTaskAndHiddenSuite (0.65s)
--- PASS: TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt (3.02s)
    --- PASS: TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt/retired (0.61s)
    --- PASS: TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt/missing_suite (0.59s)
    --- PASS: TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt/brief_changed (0.61s)
    --- PASS: TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt/bad_manifest (0.61s)
    --- PASS: TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt/bad_task (0.60s)
ok  	github.com/ouroboric-dev/odin/internal/engine	7.949s
```

#### Part 3: failures, order and isolation

These tests pin behavior that part 2 already has. They were written after the code, so they have no red step; the Evidence lists the mutations that make them fail.

- [ ] **Step 9:** create `internal/engine/grade_failure_test.go` and `internal/engine/grade_isolation_test.go`:

```go
package engine

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/task/tasktest"
)

func TestAResultsFileThatDoesNotMatchTheManifestIsRefusedAsBadManifest(t *testing.T) {
	missing := strings.Replace(tasktest.Results(nil), `{"title":"a thing is private","tests":[{"results":[{"status":"passed"}]}]}`, ``, 1)
	missing = strings.Replace(missing, `},]`, `}]`, 1)
	extra := strings.TrimSuffix(tasktest.Results(nil), `]}]}`) + `,{"title":"a new thing","tests":[{"results":[{"status":"passed"}]}]}]}]}`
	for name, results := range map[string]string{"a scenario the suite did not run": missing, "a spec the manifest does not know": extra} {
		t.Run(name, func(t *testing.T) {
			g := startGraded(t, gradedNodes, results, nil)
			out := g.advance(t)
			if out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "bad_manifest") {
				t.Fatalf("Advance() = %+v", out)
			}
			if _, err := os.Stat(filepath.Join(g.r.Dir, "score.json")); err == nil {
				t.Error("a mismatch left a score.json: a scenario on one side only must never score")
			}
			text := ledgerText(t, g.r)
			if !strings.Contains(text, `"event":"grade_started"`) || !strings.Contains(text, `"ygg.grade.reason":"bad_manifest"`) || strings.Contains(text, `"event":"grade_finished"`) {
				t.Errorf("the ledger:\n%s", text)
			}
		})
	}
}

func TestAGradingRunThatFailsFailsTheNodeAndAResumeGradesAgain(t *testing.T) {
	g := startGraded(t, gradedNodes, tasktest.Results(nil), nil)
	g.grader.Err = errors.New("the grader timed out after 5m0s")
	out := g.advance(t)
	if out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "timed out") {
		t.Fatalf("Advance() = %+v", out)
	}
	if _, err := os.Stat(filepath.Join(g.r.Dir, "score.json")); err == nil {
		t.Error("a grading run that failed has a score")
	}
	g.grader.Err = nil
	if out := g.advance(t); out.Status != run.StatusDone {
		t.Fatalf("the second Advance() = %+v", out)
	}
	if len(g.grader.Specs) != 2 || readScore(t, g.r).Reward < 1-1e-9 {
		t.Errorf("grader calls %d, score %+v", len(g.grader.Specs), readScore(t, g.r))
	}
}

func TestASuiteThatWritesNoResultsIsAFailureNotAPass(t *testing.T) {
	g := startGraded(t, gradedNodes, "", nil)
	if out := g.advance(t); out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "wrote no results") {
		t.Errorf("Advance() = %+v", out)
	}
	if _, err := os.Stat(filepath.Join(g.r.Dir, "score.json")); err == nil {
		t.Error("a suite with no results has a score")
	}
}

func TestARunBuiltFromAnotherBriefThanTheTasksIsRefused(t *testing.T) {
	g := startGraded(t, gradedNodes, tasktest.Results(nil), nil)
	// The task moves to a new version after the run began: the file and its hash agree, but not with the run's.
	brief := tasktest.Brief + "A newer brief.\n"
	sum := sha256.Sum256([]byte(brief))
	toml, _ := os.ReadFile(filepath.Join(g.task.Dir, "task.toml"))
	old := sha256.Sum256([]byte(tasktest.Brief))
	os.WriteFile(filepath.Join(g.task.Dir, "task.toml"), []byte(strings.Replace(string(toml), hex.EncodeToString(old[:]), hex.EncodeToString(sum[:]), 1)), 0o644)
	os.WriteFile(g.task.Brief(), []byte(brief), 0o644)
	out := g.advance(t)
	if out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "brief_changed") || len(g.grader.Specs) != 0 {
		t.Errorf("Advance() = %+v, grader calls %d", out, len(g.grader.Specs))
	}
}
```

```go
package engine

import (
	"context"
	"github.com/ouroboric-dev/gleipnir/sandbox"
	"io/fs"
	"os"
	"path/filepath"
	"reflect"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/task/tasktest"
	"github.com/ouroboric-dev/odin/internal/tree"
)

func TestGradingStartsOnlyAfterEverySandboxHasStopped(t *testing.T) {
	g := startGraded(t, gradedNodes, tasktest.Results(nil), nil)
	if _, err := g.r.SnapshotRunner(context.Background(), "move", nil); err != nil { // a snapshot sandbox, as an acceptance check starts
		t.Fatal(err)
	}
	var ups, downs, recorded int
	g.grader.Before = func(sandbox.GradeSpec) {
		ups, downs, recorded = len(g.box.Ups), len(g.box.Downs), len(g.r.State.Sandboxes)
	}
	if out := g.advance(t); out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v", out)
	}
	// The leaf's, the scratch agent's and the snapshot's: three, all down before the container starts.
	if ups != 3 || downs != 3 || recorded != 0 {
		t.Errorf("when the grader ran: %d sandboxes up in all, %d stopped, %d still recorded; want 3, 3, 0", ups, downs, recorded)
	}
}

func TestTheGraderGetsTheCommittedProjectAsAppAndNothingElse(t *testing.T) {
	g := startGraded(t, gradedNodes, tasktest.Results(nil), nil)
	os.WriteFile(filepath.Join(g.r.Project, "stray.txt"), []byte("not committed\n"), 0o644)
	if out := g.advance(t); out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v", out)
	}
	files := g.grader.Apps[0]
	for _, want := range []string{"umbrella.yaml", "repos/app/README.md"} {
		if !slices.Contains(files, want) {
			t.Errorf("/app lacks %s:\n%s", want, strings.Join(files, "\n"))
		}
	}
	for _, f := range files {
		for _, part := range strings.Split(f, "/") {
			if slices.Contains([]string{".git", ".factory", "stray.txt", "score.json", "build.txt"}, part) {
				t.Errorf("/app holds %s", f)
			}
		}
	}
}

func TestScoreJSONIsInNoLeafAndNoTree(t *testing.T) {
	g := startGraded(t, gradedNodes, tasktest.Results(nil), nil)
	if out := g.advance(t); out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v", out)
	}
	path := filepath.Join(g.r.Dir, "score.json")
	if _, err := os.Stat(path); err != nil {
		t.Fatal(err)
	}
	// No file called score.json is anywhere in a leaf's working copy, in what the grader was given as /app,
	// in a scratch workspace or in a snapshot; the only one is the run folder's.
	roots := []string{g.r.ScratchDir("design"), filepath.Join(g.r.Dir, "grade", "app")}
	for repo, n := range g.r.Setup.Repos {
		if repo != "." {
			roots = append(roots, n.Dir)
			if rel, err := filepath.Rel(n.Dir, path); err == nil && filepath.IsLocal(rel) {
				t.Errorf("score.json is inside the leaf %s", repo)
			}
		}
	}
	for _, root := range roots {
		filepath.WalkDir(root, func(p string, d fs.DirEntry, _ error) error {
			if d != nil && !d.IsDir() && d.Name() == "score.json" {
				t.Errorf("a score.json at %s", p)
			}
			return nil
		})
	}
	// Neither the project umbrella nor a leaf tracks a score.json, or anything of the run folder.
	nodes, err := tree.Resolve(context.Background(), g.r.Setup.Root, filepath.Join(g.r.Setup.ProjectPath, "repos/app"))
	if err != nil {
		t.Fatal(err)
	}
	for _, n := range []tree.Node{g.r.Setup.Project, nodes[len(nodes)-1]} {
		out, err := git.Repo{GitDir: n.GitDir, WorkTree: n.Dir}.Run(context.Background(), "ls-files", "--cached")
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(out, "score.json") || strings.Contains(out, ".factory") {
			t.Errorf("%s tracks or shows:\n%s", n.Dir, out)
		}
	}
}

// strs collects every string a value holds, through exported fields, slices, arrays, maps and pointers.
// It skips interfaces, which hold the readers and writers of a command.
func strs(v reflect.Value, out *[]string) {
	switch v.Kind() {
	case reflect.String:
		*out = append(*out, v.String())
	case reflect.Slice, reflect.Array:
		for i := range v.Len() {
			strs(v.Index(i), out)
		}
	case reflect.Map:
		for _, k := range v.MapKeys() {
			strs(k, out)
			strs(v.MapIndex(k), out)
		}
	case reflect.Pointer:
		if !v.IsNil() {
			strs(v.Elem(), out)
		}
	case reflect.Struct:
		for i := range v.NumField() {
			if v.Type().Field(i).IsExported() {
				strs(v.Field(i), out)
			}
		}
	}
}

// under names every string in v that is the folder or a path under it.
func under(v any, dir string) []string {
	var all, hit []string
	strs(reflect.ValueOf(v), &all)
	for _, s := range all {
		if s == dir || strings.HasPrefix(s, dir+"/") || strings.Contains(s, dir+"/") {
			hit = append(hit, s)
		}
	}
	return hit
}

func TestTheWalkerThatGuardsTheSuiteFolderFindsItWhereItIs(t *testing.T) {
	spec := gungnir.SandboxSpec{Run: "r", Name: "repos/app", Parent: "/p", Leaf: "/p/repos/app", GitDir: "/p/.git/modules/app"}
	if hit := under(spec, "/suites"); len(hit) != 0 {
		t.Errorf("found %v in a clean spec", hit)
	}
	spec.Leaf = "/suites/tiny-task/v1/tests"
	if hit := under(spec, "/suites"); len(hit) != 1 {
		t.Errorf("found %v in a spec that holds the suite", hit)
	}
	cmd := gungnir.Cmd{Argv: []string{"cat", "/suites/tiny-task/v1/tests/manifest.json"}, Env: map[string]string{"X": "/suites"}}
	if hit := under(cmd, "/suites"); len(hit) != 2 {
		t.Errorf("found %v in a command that reads the suite", hit)
	}
}

func TestNoAgentSandboxOrCommandEverHoldsTheSuiteFolder(t *testing.T) {
	g := startGraded(t, gradedNodes, tasktest.Results(nil), nil)
	if _, err := g.r.SnapshotRunner(context.Background(), "move", nil); err != nil {
		t.Fatal(err)
	}
	if out := g.advance(t); out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v", out)
	}
	suite := g.r.Setup.Config.Grader.SuiteDir
	if len(g.box.Ups) != 3 {
		t.Fatalf("%d sandboxes came up, want a leaf's, a scratch agent's and a snapshot's", len(g.box.Ups))
	}
	for _, up := range g.box.Ups {
		if hit := under(up, suite); len(hit) > 0 {
			t.Errorf("the sandbox %s holds the suite folder: %v", up.Name, hit)
		}
	}
	for _, c := range g.box.Execs {
		if hit := under(c, suite); len(hit) > 0 {
			t.Errorf("a command in a sandbox names the suite folder: %v", hit)
		}
	}
	// What an agent was told is no place to look either: its prompt and the files of its workspace.
	for _, key := range []string{"a-1", "design-1"} {
		if p := promptOf(t, g.r, key); strings.Contains(p, suite) || strings.Contains(p, "tiny-task/v1") {
			t.Errorf("the prompt of %s names the suite store", key)
		}
	}
	// The one container that holds the suite is the grader's, and it holds the tests folder only.
	if spec := g.grader.Specs[0]; spec.Tests != g.task.Tests || spec.App == suite || strings.HasPrefix(spec.App, suite) || strings.HasPrefix(spec.Logs, suite) {
		t.Errorf("the grader's folders = %+v", spec)
	}
}
```

- [ ] **Step 10:** run the whole package with the race detector, then commit.

```bash
gofmt -l . ; go vet ./internal/engine
go test -race -count=1 ./internal/engine
git add internal/engine/grade_failure_test.go internal/engine/grade_isolation_test.go
git commit -m "Pin the grade stage: failures stop the run, sandboxes are down first, no agent path holds the suite, score.json stays in the run folder (v0-T249)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

Expected: `ok  	github.com/ouroboric-dev/odin/internal/engine	107.266s` (the package is slow: 29 files of engine tests).

Real output of the new tests:

```text
--- PASS: TestAResultsFileThatDoesNotMatchTheManifestIsRefusedAsBadManifest (1.26s)
--- PASS: TestAGradingRunThatFailsFailsTheNodeAndAResumeGradesAgain (0.62s)
--- PASS: TestASuiteThatWritesNoResultsIsAFailureNotAPass (0.53s)
--- PASS: TestARunBuiltFromAnotherBriefThanTheTasksIsRefused (0.51s)
--- PASS: TestGradingStartsOnlyAfterEverySandboxHasStopped (0.66s)
--- PASS: TestTheGraderGetsTheCommittedProjectAsAppAndNothingElse (0.56s)
--- PASS: TestScoreJSONIsInNoLeafAndNoTree (0.57s)
--- PASS: TestTheWalkerThatGuardsTheSuiteFolderFindsItWhereItIs (0.00s)
--- PASS: TestNoAgentSandboxOrCommandEverHoldsTheSuiteFolder (0.60s)
```

**Evidence (v0-T249):** built and run in the reference workspace on 2026-10-18 as commits `a5925c4`, `4ef3d84` and `9267548` (not pushed). Tests first for parts 1 and 2: the failures are as in steps 2 and 6. `gofmt -l .` and `go vet ./...` print nothing; `go test -race -count=1 ./...` is `ok` for every package of `odin` (the slowest: `engine` 107 s, `cli` 46 s, `run` 28 s). Mutations tried on the finished code, each undone: (1) the sandboxes not stopped before grading: nine tests failed, among them `TestGradingStartsOnlyAfterEverySandboxHasStopped`; (2) the scratch sandbox given the suite folder as an egress entry, a stand-in for any sandbox spec that names it: `TestNoAgentSandboxOrCommandEverHoldsTheSuiteFolder` failed; (3) `score.json` written into the leaf: `TestScoreJSONIsInNoLeafAndNoTree`, `TestGraderCombinesPublicTaskAndHiddenSuite` and the resume test failed; (4) the run-brief comparison removed: `TestARunBuiltFromAnotherBriefThanTheTasksIsRefused` failed. The grader here is a fake: the real container is gleipnir's (v0-T246) and runs only in v0-H16. Not run: a run through `ygg run` with a grade node on a real engine.

### Task v0-T250: `ygg grade`, the `grader:` block checked by `ygg doctor`, and leftover grader containers

Odin's last task of the grader. It needs v0-T249.

**Files (in `odin`):**

- Create: `internal/cli/grade.go`, `internal/cli/grade_test.go`
- Modify: `internal/cli/cli.go` (the usage, the command table, the `--task` flag), `internal/cli/doctor.go`

**Interfaces:**

- Consumes: `engine.Grade`, `task.Refusal`, `sandbox.Driver.GraderLeftovers` and `RemoveGrader` (v0-T246).
- Produces: `ygg grade <run-id> [--task <id>] [--project <dir>]`. It opens the run as `resume` does, refuses a run that is not done (its sandboxes and its work are final only then) and a config without the `grader:` and `sandbox:` sections (exit 2), then calls `engine.Grade`. A refusal exits 2 and prints `ygg: grading refused (<reason>): <detail>`. A failure of the grading run exits 1. Success prints the run, the task and its version, the suite, `reward`, `fail-to-pass`, `pass-to-pass` and the path of `score.json`, and exits 0. The reward goes to the operator's terminal and to nobody else.
- Produces: the config wiring. The `grader:` block is parsed and checked by v0-T245 (`schema.Factory.Grader`). v0-T249 gave the run its `Grader` and refused a `grade` node without the sections. This task adds what the operator sees: `ygg doctor` reports `OK grader: <n> task(s) in <tasks_dir>, suites in <suite_dir>` and an `ERROR grader:` when `tasks_dir` can't be read or `suite_dir` is not a folder.
- Produces: `ygg doctor` finds the containers that carry the label `ygg.grader` (`GraderLeftovers`), and for each one: a live `ygg` holds the run (its lock): leave it; the run is not in this project: `WARN graders: container <id> of run <run> belongs to another project; doctor in that project removes it`; otherwise `RemoveGrader` and `WARN graders: run <run> left the grader container <id> (<state>); removed it`. Last line: `OK graders: <n> grader container(s) of ygg runs`. A container that can't be removed is an `ERROR`.

**Acceptance criteria:**

- [ ] `ygg grade <id>` on a done run, with the real driver and a stand-in `podman` on the path, writes `score.json` and prints the reward. The `podman run` line has `--network none`, `--label ygg.grader=<run>`, exactly three `--mount` options (`/app`, `/tests` read only, `/logs/verifier`) and ends with `bash /tests/test.sh`. The container is removed after.
- [ ] A retired suite makes `ygg grade` exit 2, call neither `podman run` nor `podman build`, leave no `score.json` and leave `grade_refused` with reason `retired` in the ledger. `--task` with a task that is not in the store is `bad_task`.
- [ ] `ygg grade` without a grader section, for a run that does not exist, with no run id, or for a run that is stopped, exits 2.
- [ ] `ygg doctor` removes the leftover of this project's run and only that one, and names the other.
- [ ] `ygg doctor` reports a missing `tasks_dir` as an error, and says nothing of graders when the config has no `grader:` block.

**Review focus pinned by tests:**

- A refusal that still builds or runs: `TestGradeRefusesWithExitTwoAndBuildsNothing`.
- A grader container that lives on after a killed `ygg`: `TestDoctorFindsAndRemovesALeftoverGraderContainer`.
- A doctor that removes the container of a run another process is grading, or of another project: the same test (the other project's) and, for the lock, `run.Locked` as `ygg doctor` uses it for sandboxes.
- A grader folder that is wrong found late: `TestDoctorChecksTheGraderSectionsFolders`.
- The container's mounts and flags through the real driver: `TestGradeGradesADoneRunAndPrintsTheScore`.

**Named test:** `go test ./internal/cli -run 'TestGrade|TestDoctorFinds|TestDoctorChecksTheGrader'` in `odin`. **Layer:** `odin`. **Size:** M (315). **Depends on:** v0-T249.

- [ ] **Step 1:** write the tests first. Create `internal/cli/grade_test.go`:

```go
package cli

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/engine"
	"github.com/ouroboric-dev/odin/internal/lock"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/sandboxfake"
	"github.com/ouroboric-dev/odin/internal/task/tasktest"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

const gradePack = "leaves:\n  repos/app: { description: the app, template: t, first_commit: [LICENSE] }\n" +
	"sandbox:\n  stack: docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514\n  egress: [proxy.golang.org]\n"

// engineStub puts a podman and a devcontainer that log what they are asked in front of the real ones. The
// podman answers `run` as a hidden suite would, by copying results into the logs folder it mounts, and
// lists graderPS (a JSON array) for the containers that carry the grader label. Their answers are written
// into the scripts, because the driver passes the stubs no variable of the test's. It returns the log.
func engineStub(t *testing.T, results, graderPS string) string {
	t.Helper()
	bin, work := t.TempDir(), t.TempDir()
	log, res, ps := filepath.Join(work, "calls.log"), filepath.Join(work, "results.json"), filepath.Join(work, "ps.json")
	os.WriteFile(res, []byte(results), 0o644)
	os.WriteFile(ps, []byte(graderPS), 0o644)
	podman := "#!/bin/sh\necho \"podman $*\" >> " + log + "\ncase \"$1\" in\n  info) echo \"true 5.0.0\" ;;\n  image) exit 0 ;;\n" +
		"  ps) case \"$*\" in *ygg.grader*) cat " + ps + " ;; *) echo '[]' ;; esac ;;\n" +
		"  run) src=; for a in \"$@\"; do case \"$a\" in *dst=/logs/verifier) src=${a#type=bind,src=}; src=${src%,dst=*} ;; esac; done\n" +
		"    [ -z \"$src\" ] || cp " + res + " \"$src/results.json\" ;;\nesac\nexit 0\n"
	for name, body := range map[string]string{"podman": podman, "devcontainer": "#!/bin/sh\necho 0.89.0\n"} {
		if err := os.WriteFile(filepath.Join(bin, name), []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	return log
}

// gradedRun makes a project and a config with a sandbox section and, when withGrader is set, a grader
// section; runs a one-node graph to its end with a fake sandbox, brief = the task's instruction.md; and
// returns the project, the config, the run's id and the task. A later ygg command opens the run as the
// real command line does, with the real driver, which the stubs of engineStub stand in for.
func gradedRun(t *testing.T, withGrader bool) (dir, config, id string, tk *tasktest.Task) {
	t.Helper()
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	tk = tasktest.New(t)
	realm, cfgDir := t.TempDir(), t.TempDir()
	os.MkdirAll(filepath.Join(realm, "t"), 0o755)
	script := "steps:\n  a:\n    - actions: [ { write: { path: build.txt, content: \"done\\n\" } } ]\n      result: { status: ok, summary: built }\n"
	cfg := "mode: unattended\nroles:\n  planner: { agent: scripted, model: none, script: script.yaml }\n" +
		"budget:\n  per_run: { tokens: 100000, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\nsandbox:\n  engine: unix:///run/ygg-test.sock\n"
	if withGrader {
		cfg += "grader:\n  tasks_dir: " + tk.TasksDir + "\n  suite_dir: " + tk.SuiteDir + "\n  timeout: 30m\n  memory: 4g\n  cpus: 4\n"
	}
	for p, body := range map[string]string{
		filepath.Join(realm, "t", "LICENSE"):  "MIT\n",
		filepath.Join(realm, "pack.yaml"):     "name: test\nversion: 0.1.0\ngraph: graph.yaml\n" + gradePack,
		filepath.Join(realm, "graph.yaml"):    "name: test\nversion: 1.0.0\nnodes:\n  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n",
		filepath.Join(realm, "p.md"):          "Do the work.\n",
		filepath.Join(cfgDir, "script.yaml"):  script,
		filepath.Join(cfgDir, "factory.yaml"): cfg,
	} {
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	dir, config = treetest.Project(t, "repos/app"), filepath.Join(cfgDir, "factory.yaml")
	h := run.Hooks{NewSandbox: func(*run.SandboxSetup, string) (gungnir.Sandbox, error) { return &sandboxfake.Sandbox{}, nil }}
	r, err := run.Start(context.Background(), run.Options{Project: dir, Config: config, Realm: realm, Brief: tk.Brief(), Hooks: h})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	if out, err := engine.Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	return dir, config, r.State.ID, tk
}

func TestGradeGradesADoneRunAndPrintsTheScore(t *testing.T) {
	dir, _, id, _ := gradedRun(t, true)
	log := engineStub(t, tasktest.Results(map[string]string{"a thing is private": "failed"}), "[]")
	code, out, errOut := ygg(t, "grade", id, "--project", dir)
	if code != ExitDone {
		t.Fatalf("grade: exit %d\n%s%s", code, out, errOut)
	}
	for _, want := range []string{"Graded run " + id, "tiny-task 2.1.0", "suite v1", "reward:        0.6000", "fail-to-pass:  2/3", "pass-to-pass:  1/1",
		filepath.Join(run.Dir(dir, id), "score.json")} {
		if !strings.Contains(out, want) {
			t.Errorf("the output lacks %q:\n%s", want, out)
		}
	}
	if _, err := os.Stat(filepath.Join(run.Dir(dir, id), "score.json")); err != nil {
		t.Error(err)
	}
	calls, _ := os.ReadFile(log)
	var runLine string
	for _, l := range strings.Split(string(calls), "\n") {
		if strings.HasPrefix(l, "podman run ") {
			runLine = l
		}
	}
	// The real driver ran: no network, the run's label, three mounts, the suite's command, then the removal.
	for _, want := range []string{"--network none", "--label ygg.grader=" + id, "dst=/app", "dst=/tests,ro=true", "dst=/logs/verifier", "bash /tests/test.sh"} {
		if !strings.Contains(runLine, want) {
			t.Errorf("the run line lacks %q:\n%s", want, runLine)
		}
	}
	if n := strings.Count(runLine, "--mount"); n != 3 {
		t.Errorf("%d mounts, want 3", n)
	}
	if !strings.Contains(string(calls), "podman rm -f --ignore --time 0 ygg-grader-"+id+"-tiny-task") {
		t.Errorf("the container was not removed:\n%s", calls)
	}
}

func TestGradeRefusesWithExitTwoAndBuildsNothing(t *testing.T) {
	dir, _, id, tk := gradedRun(t, true)
	log := engineStub(t, tasktest.Results(nil), "[]")
	os.MkdirAll(filepath.Join(tk.Dir, "retired"), 0o755)
	os.WriteFile(filepath.Join(tk.Dir, "retired", "v1"), []byte("retired\n"), 0o644)
	code, out, errOut := ygg(t, "grade", id, "--project", dir)
	if code != ExitRefused || !strings.Contains(errOut, "refused (retired)") || strings.Contains(out, "reward") {
		t.Errorf("grade: exit %d\n%s%s", code, out, errOut)
	}
	if calls, _ := os.ReadFile(log); strings.Contains(string(calls), "podman run") || strings.Contains(string(calls), "podman build") {
		t.Errorf("the engine was asked to build or run after a refusal:\n%s", calls)
	}
	if _, err := os.Stat(filepath.Join(run.Dir(dir, id), "score.json")); err == nil {
		t.Error("a refused grading left a score")
	}
	led, _ := os.ReadFile(filepath.Join(run.Dir(dir, id), "ledger.jsonl"))
	if !strings.Contains(string(led), `"event":"grade_refused"`) || !strings.Contains(string(led), `"ygg.grade.reason":"retired"`) {
		t.Errorf("the ledger lacks the refusal:\n%s", led)
	}
	// A task named on the command line must be a task of the store; the run's brief must be its brief.
	if code, _, errOut := ygg(t, "grade", id, "--project", dir, "--task", "no-such-task"); code != ExitRefused || !strings.Contains(errOut, "bad_task") {
		t.Errorf("grade --task no-such-task: exit %d, %q", code, errOut)
	}
}

func TestGradeNeedsADoneRunAndTheGraderSection(t *testing.T) {
	dir, _, id, _ := gradedRun(t, false)
	engineStub(t, tasktest.Results(nil), "[]")
	if code, _, errOut := ygg(t, "grade", id, "--project", dir); code != ExitRefused || !strings.Contains(errOut, "grader") {
		t.Errorf("grade without a grader section: exit %d, %q", code, errOut)
	}
	if code, _, errOut := ygg(t, "grade", "20261015-090000-a1b2c3", "--project", dir); code != ExitRefused || !strings.Contains(errOut, "no run") {
		t.Errorf("grade of no run: exit %d, %q", code, errOut)
	}
	if code, _, _ := ygg(t, "grade", "--project", dir); code != ExitRefused {
		t.Errorf("grade without a run id: exit %d", code)
	}
	// A run that did not finish is not graded: its sandboxes may be up and its work is not final.
	p, _ := filepath.Abs("../../testdata/toy")
	dir2, config2 := project(t, "script.yaml", "")
	ygg(t, "run", "--project", dir2, "--config", config2, "--realm", p)
	if code, _, errOut := ygg(t, "grade", runID(t, dir2), "--project", dir2); code != ExitRefused {
		t.Errorf("grade of a stopped run: exit %d, %q", code, errOut)
	}
	// With the grader section there, the status alone refuses a run that did not finish.
	dir3, _, id3, _ := gradedRun(t, true)
	engineStub(t, tasktest.Results(nil), "[]")
	state := filepath.Join(dir3, ".factory", "runs", id3, "run.json")
	b, err := os.ReadFile(state)
	if err != nil || !strings.Contains(string(b), `"status": "done"`) {
		t.Fatalf("run.json = %v, %.200s", err, b)
	}
	os.WriteFile(state, []byte(strings.Replace(string(b), `"status": "done"`, `"status": "stopped"`, 1)), 0o644)
	if code, _, errOut := ygg(t, "grade", id3, "--project", dir3); code != ExitRefused || !strings.Contains(errOut, "stopped") {
		t.Errorf("grade of a stopped run with a grader section: exit %d, %q", code, errOut)
	}
	if _, err := os.Stat(filepath.Join(dir3, ".factory", "runs", id3, "score.json")); err == nil {
		t.Error("a run that did not finish has a score")
	}
}

func TestDoctorLeavesTheGraderContainerOfARunAliveYggHoldsAlone(t *testing.T) {
	dir, config, id, _ := gradedRun(t, true)
	log := engineStub(t, tasktest.Results(nil), `[{"Id":"abc123def456abc","State":"running","Labels":{"ygg.grader":"`+id+`"}}]`)
	release, err := lock.Take(filepath.Join(run.Dir(dir, id), "lock")) // a live ygg holds the run while it grades
	if err != nil {
		t.Fatal(err)
	}
	defer release()
	code, out, errOut := ygg(t, "doctor", "--project", dir, "--config", config)
	if code != ExitDone {
		t.Fatalf("doctor: exit %d\n%s%s", code, out, errOut)
	}
	if strings.Contains(out, "removed it") {
		t.Errorf("doctor removed the container of a run a live ygg holds:\n%s", out)
	}
	if calls, _ := os.ReadFile(log); strings.Contains(string(calls), "podman rm") {
		t.Errorf("the engine was asked to remove it:\n%s", calls)
	}
}

func TestDoctorFindsAndRemovesALeftoverGraderContainer(t *testing.T) {
	dir, config, id, tk := gradedRun(t, true)
	other := "20200101-000000-aaaaaa"
	log := engineStub(t, tasktest.Results(nil), `[{"Id":"abc123def456abc","State":"exited","Labels":{"ygg.grader":"`+id+`"}},`+
		`{"Id":"zzz999zzz999zzz","State":"running","Labels":{"ygg.grader":"`+other+`"}}]`)
	code, out, errOut := ygg(t, "doctor", "--project", dir, "--config", config)
	if code != ExitDone {
		t.Fatalf("doctor: exit %d\n%s%s", code, out, errOut)
	}
	for _, want := range []string{"OK    grader: 1 task(s) in " + tk.TasksDir,
		"WARN  graders: run " + id + " left the grader container abc123def456 (exited); removed it",
		"WARN  graders: container zzz999zzz999 of run " + other + " belongs to another project; doctor in that project removes it",
		"OK    graders: 2 grader container(s) of ygg runs"} {
		if !strings.Contains(out, want) {
			t.Errorf("doctor lacks %q:\n%s", want, out)
		}
	}
	calls, _ := os.ReadFile(log)
	if !strings.Contains(string(calls), "podman rm -f --ignore --time 0 abc123def456abc") || strings.Contains(string(calls), "rm -f --ignore --time 0 zzz999") {
		t.Errorf("the engine was asked:\n%s", calls)
	}
}

func TestDoctorChecksTheGraderSectionsFolders(t *testing.T) {
	dir, config, _, tk := gradedRun(t, true)
	engineStub(t, tasktest.Results(nil), "[]")
	b, _ := os.ReadFile(config)
	os.WriteFile(config, []byte(strings.Replace(string(b), "tasks_dir: "+tk.TasksDir, "tasks_dir: "+tk.TasksDir+"-gone", 1)), 0o644)
	code, out, _ := ygg(t, "doctor", "--project", dir, "--config", config)
	if code != ExitFailed || !strings.Contains(out, "ERROR grader: ") || !strings.Contains(out, "tasks_dir") {
		t.Errorf("doctor with no tasks folder: exit %d\n%s", code, out)
	}
	dir, config, _, _ = gradedRun(t, false)
	engineStub(t, tasktest.Results(nil), "[]")
	if code, out, _ := ygg(t, "doctor", "--project", dir, "--config", config); code != ExitDone || strings.Contains(out, "grader") {
		t.Errorf("doctor without a grader section: exit %d\n%s", code, out)
	}
}
```

The stand-in `podman` copies a made-up report into the logs folder it is given as a mount, as a suite would. Its answers are written into the script, because the driver passes the stubs no variable of the test's. The run itself is made in-process with a fake sandbox, then opened by `ygg grade` as the command line does.

- [ ] **Step 2:** run them.

```bash
go test ./internal/cli -run 'TestGrade|TestDoctorFinds|TestDoctorChecksTheGrader'
```

Real output (first lines):

```text
--- FAIL: TestGradeGradesADoneRunAndPrintsTheScore (0.28s)
    grade_test.go:90: grade: exit 2
        ygg: unknown command "grade"
        usage:
          ygg run     --realm <name|dir> [--project <dir>] [--config <factory.yaml>] [--brief <file>] [--mode <mode>]
```

- [ ] **Step 3:** create `internal/cli/grade.go` and apply to `internal/cli/cli.go` and `internal/cli/doctor.go`:

```go
package cli

import (
	"errors"
	"flag"
	"fmt"

	"github.com/ouroboric-dev/odin/internal/engine"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/task"
)

// grade runs ygg grade: it grades the project of a finished run against the hidden suite of a task and
// writes score.json to the run's folder (spec §11). A run whose graph has a grade node is graded at its
// end; this command grades a run that has none, or grades again after a refusal was fixed. It prints the
// score to the operator, and to nobody else. A refusal exits 2 and builds nothing.
func (c *command) grade(args []string) int {
	f, pos, ok := c.parse("grade", args, 1, func(fs *flag.FlagSet, f *flags) {
		fs.StringVar(&f.task, "task", "", "the task to grade against: a folder of grader.tasks_dir; the default is the task whose instruction.md was the run's brief")
	})
	if !ok {
		return ExitRefused
	}
	r, code := c.open(f, pos[0])
	if r == nil {
		return code
	}
	defer r.Close()
	switch {
	case r.State.Status != run.StatusDone:
		return c.refuse(fmt.Errorf("run %s is %s; grade a run that is done, because its sandboxes and its work are final only then", r.State.ID, r.State.Status))
	case r.Setup.Config.Grader == nil || r.Grader == nil:
		return c.refuse(fmt.Errorf("%s needs the grader and the sandbox sections to grade a run", r.Setup.ConfigPath))
	}
	g, err := engine.Grade(c.ctx, r, f.task)
	var refusal *task.Refusal
	switch {
	case errors.As(err, &refusal):
		return c.refuse(err)
	case err != nil:
		fmt.Fprintf(c.err, "ygg: run %s: %v\n", r.State.ID, err)
		return ExitFailed
	}
	s := g.Score
	fmt.Fprintf(c.out, "Graded run %s: %s %s against suite %s.\nreward:        %.4f\nfail-to-pass:  %d/%d\npass-to-pass:  %d/%d\nscore:         %s\n",
		r.State.ID, s.Task, s.TaskVersion, s.Suite, s.Reward, s.FailToPass.Passed, s.FailToPass.Total, s.PassToPass.Passed, s.PassToPass.Total, g.Path)
	return ExitDone
}
```

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index f0e0ad5..2e3203f 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -36,6 +36,7 @@ const usage = `usage:
   ygg approve <run-id> <gate> [--note <text>] [--project <dir>] [--mode <mode>]
   ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
   ygg status  <run-id> [--project <dir>]
+  ygg grade   <run-id> [--task <id>] [--project <dir>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
   ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
 exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point, 4 paused: the provider's quota is used up,
@@ -51,7 +52,7 @@ func Main(ctx context.Context, args []string, stdout, stderr io.Writer) int {
 	c := &command{ctx: ctx, out: stdout, err: stderr}
 	cmds := map[string]func([]string) int{
 		"run": c.run, "resume": c.resume, "approve": c.approve, "reject": c.reject,
-		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox,
+		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade,
 	}
 	f, ok := cmds[args[0]]
 	if !ok {
@@ -68,10 +69,10 @@ type command struct {
 
 // flags holds every flag; each command reads the ones it defines.
 type flags struct {
-	project, config, realm, brief, mode, note, reason, root string
-	realms                                                  []string        // sandbox build: every --realm given
-	all                                                     bool            // sandbox build: --all
-	set                                                     map[string]bool // the flags given
+	project, config, realm, brief, mode, note, reason, root, task string
+	realms                                                        []string        // sandbox build: every --realm given
+	all                                                           bool            // sandbox build: --all
+	set                                                           map[string]bool // the flags given
 }
 
 // parse parses flags that may come before, between or after the positional arguments, and
```

```diff
diff --git a/internal/cli/doctor.go b/internal/cli/doctor.go
index 33972ab..79d57e6 100644
--- a/internal/cli/doctor.go
+++ b/internal/cli/doctor.go
@@ -56,6 +56,7 @@ func (c *command) doctor(args []string) int {
 	if factory != nil {
 		checkRealms(factory, report)
 		checkBudget(factory, report)
+		checkGrader(factory, report)
 		c.checkSandbox(f.project, factory, report)
 	}
 	runs := filepath.Join(f.project, ".factory", "runs")
@@ -251,6 +252,61 @@ func (c *command) checkSandbox(project string, f *schema.Factory, report func(le
 		}
 	}
 	report("OK", "sandboxes", fmt.Sprintf("%d container(s) of ygg runs", len(left)))
+	if f.Grader != nil {
+		c.checkGraders(d, project, report)
+	}
+}
+
+// checkGrader says how many tasks the grader's folder holds, and that its two folders are there.
+func checkGrader(f *schema.Factory, report func(level, what, msg string)) {
+	g := f.Grader
+	if g == nil {
+		return
+	}
+	tasks, err := os.ReadDir(g.TasksDir)
+	if err != nil {
+		report("ERROR", "grader", "tasks_dir: "+err.Error())
+		return
+	}
+	n := 0
+	for _, e := range tasks {
+		if _, err := os.Stat(filepath.Join(g.TasksDir, e.Name(), "task.toml")); err == nil {
+			n++
+		}
+	}
+	if st, err := os.Stat(g.SuiteDir); err != nil || !st.IsDir() {
+		report("ERROR", "grader", "suite_dir "+g.SuiteDir+" is not a folder")
+		return
+	}
+	report("OK", "grader", fmt.Sprintf("%d task(s) in %s, suites in %s", n, g.TasksDir, g.SuiteDir))
+}
+
+// checkGraders finds the grader containers a killed ygg left, by their label, and removes the ones no
+// live run holds: a container of the grader is removed by Grade itself, so one that is left means ygg
+// died while it ran.
+func (c *command) checkGraders(d *sandbox.Driver, project string, report func(level, what, msg string)) {
+	left, err := d.GraderLeftovers(c.ctx)
+	if err != nil {
+		report("ERROR", "graders", err.Error())
+		return
+	}
+	for _, l := range left {
+		short := l.Container[:min(12, len(l.Container))]
+		dir := run.Dir(project, l.Run)
+		switch _, err := os.Stat(dir); {
+		case !run.ValidID(l.Run) || err != nil:
+			report("WARN", "graders", fmt.Sprintf("container %s of run %s belongs to another project; doctor in that project removes it", short, l.Run))
+		case run.Locked(dir):
+			// A live ygg is grading.
+		default:
+			if err := d.RemoveGrader(c.ctx, l.Container); err != nil {
+				report("ERROR", "graders", fmt.Sprintf("couldn't remove %s of run %s: %v", short, l.Run, err))
+			} else {
+				report("WARN", "graders", fmt.Sprintf("run %s left the grader container %s (%s); removed it", l.Run, short, l.State))
+			}
+		}
+	}
+	report("OK", "graders", fmt.Sprintf("%d grader container(s) of ygg runs", len(left)))
 }
 
 // checkTree walks the instance tree from root, checking out nothing, and warns when a public
```

- [ ] **Step 4:** run the tests, the whole suite, and commit.

```bash
gofmt -l . ; go vet ./...
go test -race -count=1 -v -run 'TestGrade|TestDoctorFinds|TestDoctorChecksTheGrader' ./internal/cli 2>&1 | grep -E "^(--- |ok|FAIL)"
GOWORK=$PWD/../go.work go test -race -count=1 ./...
git status --short
git add internal/cli/cli.go internal/cli/doctor.go internal/cli/grade.go internal/cli/grade_test.go
git commit -m "ygg grade, and ygg doctor lists and removes leftover grader containers and checks the grader folders (v0-T250)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

Real output of the named tests:

```text
--- PASS: TestDoctorFindsAChangedLedger (0.58s)
--- PASS: TestGradeGradesADoneRunAndPrintsTheScore (0.59s)
--- PASS: TestGradeRefusesWithExitTwoAndBuildsNothing (0.55s)
--- PASS: TestGradeNeedsADoneRunAndTheGraderSection (0.83s)
--- PASS: TestDoctorLeavesTheGraderContainerOfARunAliveYggHoldsAlone (0.41s)
--- PASS: TestDoctorFindsAndRemovesALeftoverGraderContainer (0.43s)
--- PASS: TestDoctorChecksTheGraderSectionsFolders (0.86s)
ok  	github.com/ouroboric-dev/odin/internal/cli	4.864s
```

(`TestDoctorFindsAChangedLedger` matches the filter by its name; it is an older test.) Real output of the whole suite:

```text
ok  	github.com/ouroboric-dev/odin/internal/agents	1.047s
ok  	github.com/ouroboric-dev/odin/internal/budget	1.333s
ok  	github.com/ouroboric-dev/odin/internal/cli	45.883s
ok  	github.com/ouroboric-dev/odin/internal/engine	107.266s
ok  	github.com/ouroboric-dev/odin/internal/gate	1.014s
ok  	github.com/ouroboric-dev/odin/internal/git	1.182s
ok  	github.com/ouroboric-dev/odin/internal/leaf	15.982s
ok  	github.com/ouroboric-dev/odin/internal/ledger	1.803s
ok  	github.com/ouroboric-dev/odin/internal/lock	1.063s
ok  	github.com/ouroboric-dev/odin/internal/merge	7.507s
ok  	github.com/ouroboric-dev/odin/internal/plan	1.119s
ok  	github.com/ouroboric-dev/odin/internal/pointer	6.632s
ok  	github.com/ouroboric-dev/odin/internal/realm	1.575s
ok  	github.com/ouroboric-dev/odin/internal/remote	6.072s
ok  	github.com/ouroboric-dev/odin/internal/run	27.703s
ok  	github.com/ouroboric-dev/odin/internal/score	1.031s
ok  	github.com/ouroboric-dev/odin/internal/shrink	1.014s
ok  	github.com/ouroboric-dev/odin/internal/snapshot	1.262s
ok  	github.com/ouroboric-dev/odin/internal/task	1.193s
ok  	github.com/ouroboric-dev/odin/internal/tree	7.525s
```

(packages with no test files are left out.)

**Evidence (v0-T250):** built and run in the reference workspace on 2026-10-18 as commit `b6da7a0` (not pushed). Tests first: the failure is as in step 2. `gofmt -l .` and `go vet ./...` print nothing; `go test -race -count=1 ./...` is `ok` for every package. Mutations tried, each undone: `RemoveGrader` not called (`TestDoctorFindsAndRemovesALeftoverGraderContainer` failed); a refusal exiting 1 instead of 2 (`TestGradeRefusesWithExitTwoAndBuildsNothing` failed). The `podman` and `devcontainer` of these tests are shell stand-ins that log their arguments: they prove the arguments the real driver passes, not that a container behaves. Not run: `ygg grade` and `ygg doctor` against a real engine (v0-H16); a doctor that finds a grader container whose run a live `ygg` holds leaves it alone (`TestDoctorLeavesTheGraderContainerOfARunAliveYggHoldsAlone` holds the run's lock).

### Task v0-T251: the wiring index generator: the `REPOS.md` block, every edge tagged `extracted` or `inferred`

Odin's first routing task. Branch `grader/odin` continues in `odin`. A new package, `internal/routing`, reads a project
umbrella and writes the wiring block (spec §8.2). It calls no model and gives the same bytes for the same files. Three commits:
part 1 is the edge type and the block, part 2 reads the umbrella, the packs and the manifests, part 3 reads imports and contracts
and makes the reading safe.

**Files (in `odin`):**

- Create: `internal/routing/edge.go`, `block.go`, `block_test.go`, `wiring.go`, `wiring_test.go`
- Create: `testdata/routing/project/**` (the fixture project: three leaves, no git), `testdata/routing/wiring.golden.md`
- Modify: `go.mod` (`go.yaml.in/yaml/v3` is now a direct dependency; it was already in `go.sum`)

**Interfaces:**

- Consumes: `schema.LoadUmbrella`, `schema.Pack.Services`, `schema.ChildLeaf` (Gungnir). No new Gungnir code.
- Produces: `routing.Edge{From, To, Kind, Tag, Source}`; `routing.Extracted`, `routing.Inferred`; `routing.Sorted`, `routing.Counts`.
- Produces: `routing.Wiring(dir string, packs map[string]*schema.Pack) (*Result, error)`. `Result` holds `Edges` (sorted, no duplicates), `Leaves`, `Contracts` (v0-T252 uses these) and `Skipped` (what was left out, and why).
- Produces: `routing.Block(edges) []byte`, `routing.ReplaceBlock(doc, block) ([]byte, error)`, `routing.WriteWiring(dir, edges)`, the markers `routing.BeginMarker`/`EndMarker` and `routing.ReposFile`.
- The nodes of an edge are a leaf path (`api`), `contract:<path>`, `go:<module>`, `npm:<name>`, the same with `@<version>` for a pin, `realm:<name>@<version>` and `service:<name>`.
- The kinds, and the tag each one has: `consumes` (umbrella.yaml `consumes`, extracted), `uses-realm` (extracted), `needs` (a service of the leaf's realm pack, extracted), `requires` (a direct `go.mod` or `package.json` dependency; a `require` of another leaf's module is an edge to that leaf; extracted), `pins` (the version `go.sum` or `package-lock.json` confirms, extracted), `imports` (a Go import of another leaf's module, extracted), `holds` (a leaf holds an OpenAPI file, extracted), `copies` (a leaf's contract copies the contract of a leaf it depends on, when both have the same `info.title`: **extracted if the bytes are identical, `inferred` if not**), `mentions` (a README or AGENTS.md names another leaf with no extracted edge between them: `inferred`).

**Acceptance criteria:**

- [ ] The fixture gives the edges of the golden file, byte for byte, three times in a row.
- [ ] Every edge has a tag, and the tag is `extracted` or `inferred`. The fixture has both.
- [ ] A symlink in a leaf, a file over 1 MiB, an indirect Go requirement, a name with `|` or a marker in it: none gives an edge. Each one but the indirect requirement is in `Skipped`.
- [ ] `WriteWiring` twice leaves one block and the text around it as it was. Two begin markers, or an end before a begin, is an error and the file is unchanged.

**Review focus pinned by tests:**

- Leaf files are written by an agent: `TestWiringIgnoresSymlinksHugeFilesAndNamesThatBreakTheTable`.
- A guess is never a fact: `TestEveryEdgeIsTaggedExtractedOrInferred`, and the `copies` and `mentions` rows of `TestWiringReadsManifestsLockfilesContractsAndImports`.
- Same input, same bytes: `TestWiringIsTheSameBytesEveryTime`, `TestTheFixtureBlockMatchesItsGoldenFile`.
- A person's text is not cut: `TestTheBlockReplacesItselfAndKeepsThePeopleText`, `TestAStrayMarkerIsAnErrorAndCutsNothing`.

**Named test:** `go test ./internal/routing` in `odin`. **Layer:** `odin`. **Size:** M, S and M (171, 433, 282). **Depends on:** v0-T250.

#### Part 1: the edge and the block (`0251122`)

- [ ] **Step 1:** write the tests first, then the code. The block tests compile with the edge type alone.

Create `internal/routing/block_test.go`:

```go
package routing

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestTheBlockReplacesItselfAndKeepsThePeopleText(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, ReposFile)
	human := "# Repos\n\nWhat each repo is for.\n\n"
	os.WriteFile(p, []byte(human), 0o644)
	one := []Edge{{From: "a", To: "b", Kind: "consumes", Tag: Extracted, Source: "umbrella.yaml"}}
	two := append(one, Edge{From: "b", To: "c", Kind: "consumes", Tag: Inferred, Source: "b/README.md"})
	for _, es := range [][]Edge{one, two, two} {
		if err := WriteWiring(dir, es); err != nil {
			t.Fatal(err)
		}
	}
	got, _ := os.ReadFile(p)
	want := human + string(Block(two))
	if string(got) != want {
		t.Errorf("REPOS.md =\n%s\nwant\n%s", got, want)
	}
	os.WriteFile(p, []byte("top\n"+string(Block(one))+"\nbottom\n"), 0o644)
	WriteWiring(dir, two)
	got, _ = os.ReadFile(p)
	if !strings.HasPrefix(string(got), "top\n"+BeginMarker) || !strings.HasSuffix(string(got), EndMarker+"\n\nbottom\n") {
		t.Errorf("text around the block changed:\n%s", got)
	}
}

func TestAStrayMarkerIsAnErrorAndCutsNothing(t *testing.T) {
	for name, doc := range map[string]string{
		"two begins":   BeginMarker + "\nx\n" + BeginMarker + "\n" + EndMarker + "\n",
		"end first":    EndMarker + "\n" + BeginMarker + "\n",
		"only a begin": "text\n" + BeginMarker + "\nmore text\n",
	} {
		if out, err := ReplaceBlock([]byte(doc), Block(nil)); err == nil {
			t.Errorf("%s: no error, got %q", name, out)
		}
	}
}
```

Create `internal/routing/block.go`:

```go
package routing

import (
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// The markers of the wiring block in REPOS.md (spec §8.2).
const (
	BeginMarker = "<!-- ygg:wiring:begin -->"
	EndMarker   = "<!-- ygg:wiring:end -->"
	// ReposFile is the file that holds the block, in the project umbrella.
	ReposFile = "REPOS.md"
)

// Block renders the edges as the wiring block: the two markers and a table between them, one row per
// edge, in the order of Sorted. Same edges, same bytes.
func Block(edges []Edge) []byte {
	var b strings.Builder
	b.WriteString(BeginMarker + "\n")
	b.WriteString("<!-- Generated by ygg from the manifests, lockfiles and contracts of the leaves. Do not edit. -->\n\n")
	b.WriteString("| From | Kind | To | Tag | Source |\n|---|---|---|---|---|\n")
	for _, e := range Sorted(edges) {
		fmt.Fprintf(&b, "| %s | %s | %s | %s | %s |\n", e.From, e.Kind, e.To, e.Tag, e.Source)
	}
	b.WriteString(EndMarker + "\n")
	return []byte(b.String())
}

// ReplaceBlock puts block in doc in place of the block already there. A document with no block gets it
// at its end. Exactly one pair of markers, begin before end, is fine; any other count is an error, so
// that a stray marker never makes Odin cut text a person wrote.
func ReplaceBlock(doc, block []byte) ([]byte, error) {
	nb, ne := bytes.Count(doc, []byte(BeginMarker)), bytes.Count(doc, []byte(EndMarker))
	switch {
	case nb == 0 && ne == 0:
		out := bytes.TrimRight(doc, "\n")
		if len(out) > 0 {
			out = append(out, '\n', '\n')
		}
		return append(out, block...), nil
	case nb != 1 || ne != 1:
		return nil, fmt.Errorf("%s has %d begin and %d end markers of the wiring block; it needs one pair", ReposFile, nb, ne)
	}
	i := bytes.Index(doc, []byte(BeginMarker))
	j := bytes.Index(doc, []byte(EndMarker))
	if j < i {
		return nil, fmt.Errorf("%s: the end marker of the wiring block comes before the begin marker", ReposFile)
	}
	j += len(EndMarker)
	if j < len(doc) && doc[j] == '\n' {
		j++
	}
	return append(append(append([]byte{}, doc[:i]...), block...), doc[j:]...), nil
}

// WriteWiring writes the block into dir/REPOS.md, keeping the text around it.
func WriteWiring(dir string, edges []Edge) error {
	p := filepath.Join(dir, ReposFile)
	old, err := os.ReadFile(p)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	out, err := ReplaceBlock(old, Block(edges))
	if err != nil {
		return err
	}
	return os.WriteFile(p, out, 0o644)
}
```

Create `internal/routing/edge.go`:

```go
// Package routing builds the routing bundle of a project umbrella (spec §8): the wiring index (the
// REPOS.md block), the impact index (.ygg/impact.json) and the bench that decides whether an index
// ships. The generators are deterministic: the same files give the same bytes, and no model is called.
// Every edge says how Odin knows it: extracted (read from a manifest, an import, an OpenAPI file or
// a lockfile) or inferred (any guess, such as matching a name).
package routing

import (
	"cmp"
	"slices"
)

// The two tags of an edge (spec §8.2).
const (
	Extracted = "extracted"
	Inferred  = "inferred"
)

// Edge is one fact of the wiring: From uses To, in the way Kind says, and Source is where Odin read it.
// A node is a leaf path (api), a contract (contract:api/internal/api.openapi.yaml), a package
// (go:github.com/x/y, npm:react, the same with @version for a pin), a realm (realm:name@version) or a
// service (service:postgres).
type Edge struct {
	From   string `json:"from"`
	To     string `json:"to"`
	Kind   string `json:"kind"`
	Tag    string `json:"tag"`
	Source string `json:"source"`
}

func compare(a, b Edge) int {
	return cmp.Or(cmp.Compare(a.From, b.From), cmp.Compare(a.Kind, b.Kind), cmp.Compare(a.To, b.To),
		cmp.Compare(a.Tag, b.Tag), cmp.Compare(a.Source, b.Source))
}

// Sorted returns the edges in one fixed order, without exact duplicates.
func Sorted(edges []Edge) []Edge {
	out := slices.Clone(edges)
	slices.SortFunc(out, compare)
	return slices.CompactFunc(out, func(a, b Edge) bool { return compare(a, b) == 0 })
}

// Counts returns how many edges are extracted and how many are inferred.
func Counts(edges []Edge) (extracted, inferred int) {
	for _, e := range edges {
		if e.Tag == Extracted {
			extracted++
		} else {
			inferred++
		}
	}
	return extracted, inferred
}
```

- [ ] **Step 2:** run the checks.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/odin
go test -race ./internal/routing
```

Expected output: `ok  	github.com/ouroboric-dev/odin/internal/routing`.

- [ ] **Step 3:** commit in `odin`: `The routing package: edges tagged extracted or inferred, and the REPOS.md wiring block between its markers (v0-T251)`.

#### Part 2: the umbrella, the packs, `go.mod`, `package.json` and the lockfiles (`58aab31`)

- [ ] **Step 4:** write the fixture and the test. At this point there is no `wiring.go`, so the test does not build.

Create `internal/routing/wiring_test.go`:

```go
package routing

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
)

const fixture = "../../testdata/routing/project"

func packs() map[string]*schema.Pack {
	return map[string]*schema.Pack{
		"helheim-go":    {Name: "helheim-go", Services: map[string]schema.PackService{"postgres": {}, "seaweedfs": {}}},
		"midgard-react": {Name: "midgard-react"},
	}
}

func find(es []Edge, from, kind, to string) *Edge {
	for i, e := range es {
		if e.From == from && e.Kind == kind && e.To == to {
			return &es[i]
		}
	}
	return nil
}

func TestWiringReadsTheUmbrellaThePacksManifestsAndLockfiles(t *testing.T) {
	res, err := Wiring(fixture, packs())
	if err != nil {
		t.Fatal(err)
	}
	for _, w := range []struct{ from, kind, to, tag, source string }{
		{"web", "consumes", "api", Extracted, "umbrella.yaml"},
		{"web", "uses-realm", "realm:midgard-react@0.1.0", Extracted, "umbrella.yaml"},
		{"api", "uses-realm", "realm:helheim-go@0.1.0", Extracted, "umbrella.yaml"},
		{"api", "needs", "service:postgres", Extracted, "realm:helheim-go/pack.yaml"},
		{"api", "requires", "go:github.com/go-chi/chi/v5", Extracted, "api/go.mod"},
		{"api", "pins", "go:github.com/go-chi/chi/v5@v5.2.3", Extracted, "api/go.sum"},
		{"worker", "requires", "api", Extracted, "worker/go.mod"},
		{"web", "requires", "npm:react", Extracted, "web/package.json"},
		{"web", "pins", "npm:react@19.3.0", Extracted, "web/package-lock.json"},
	} {
		e := find(res.Edges, w.from, w.kind, w.to)
		if e == nil {
			t.Errorf("no edge %s -%s-> %s", w.from, w.kind, w.to)
			continue
		}
		if e.Tag != w.tag || e.Source != w.source {
			t.Errorf("edge %s -%s-> %s is %s from %s, want %s from %s", w.from, w.kind, w.to, e.Tag, e.Source, w.tag, w.source)
		}
	}
	if find(res.Edges, "api", "requires", "go:github.com/jackc/pgx/v5") != nil {
		t.Error("an indirect requirement is a direct edge")
	}
}

func TestEveryEdgeIsTaggedExtractedOrInferred(t *testing.T) {
	res, err := Wiring(fixture, packs())
	if err != nil {
		t.Fatal(err)
	}
	for _, e := range res.Edges {
		if e.Tag != Extracted && e.Tag != Inferred || e.From == "" || e.To == "" || e.Kind == "" || e.Source == "" {
			t.Errorf("bad edge %+v", e)
		}
	}
	x, i := Counts(res.Edges)
	if x == 0 || x+i != len(res.Edges) {
		t.Errorf("counts %d extracted, %d inferred of %d", x, i, len(res.Edges))
	}
}

func TestWiringIsTheSameBytesEveryTime(t *testing.T) {
	var first []byte
	for range 3 {
		res, err := Wiring(fixture, packs())
		if err != nil {
			t.Fatal(err)
		}
		b := Block(res.Edges)
		if first == nil {
			first = b
		} else if string(b) != string(first) {
			t.Fatal("two runs gave two blocks")
		}
	}
	if !strings.HasPrefix(string(first), BeginMarker+"\n") || !strings.HasSuffix(string(first), EndMarker+"\n") {
		t.Errorf("block does not sit between the markers:\n%s", first)
	}
}

// Review focus: package names come from files an agent wrote. A name must not break the table or the
// markers, and must not hide the good names beside it.
func TestWiringDropsNamesThatBreakTheTable(t *testing.T) {
	dir := t.TempDir()
	copyTree(t, fixture, dir)
	os.WriteFile(filepath.Join(dir, "web/package.json"), []byte(`{"dependencies":{"a|b":"1.0.0","x\n`+EndMarker+`":"1.0.0","ok":"1.0.0"}}`), 0o644)
	res, err := Wiring(dir, packs())
	if err != nil {
		t.Fatal(err)
	}
	for _, e := range res.Edges {
		if strings.ContainsAny(e.To, "|\n<") {
			t.Errorf("edge %+v can break the table", e)
		}
	}
	if find(res.Edges, "web", "requires", "npm:ok") == nil {
		t.Error("a good dependency was dropped with the bad ones")
	}
	if len(res.Skipped) != 2 {
		t.Errorf("skipped = %v; want the two bad names reported", res.Skipped)
	}
}

func copyTree(t *testing.T, from, to string) {
	t.Helper()
	err := filepath.WalkDir(from, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(from, p)
		if d.IsDir() {
			return os.MkdirAll(filepath.Join(to, rel), 0o755)
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		return os.WriteFile(filepath.Join(to, rel), b, 0o644)
	})
	if err != nil {
		t.Fatal(err)
	}
}
```

Create `testdata/routing/project/api/cmd/api/main.go`:

```go
package main

func main() {}
```

Create `testdata/routing/project/api/go.mod`:

```go
module example.test/api

go 1.26

require (
	github.com/go-chi/chi/v5 v5.2.3
	github.com/jackc/pgx/v5 v5.7.6 // indirect
)
```

Create `testdata/routing/project/api/go.sum`:

```text
github.com/go-chi/chi/v5 v5.2.3 h1:fixturehashchi=
github.com/go-chi/chi/v5 v5.2.3/go.mod h1:fixturehashchimod=
github.com/jackc/pgx/v5 v5.7.6 h1:fixturehashpgx=
```

Create `testdata/routing/project/umbrella.yaml`:

```yaml
root: true
owner: fixture
visibility: private
realm: midgard-react
realm_version: 0.1.0
children:
  api:
    kind: leaf
    owner: fixture
    visibility: private
    realm: helheim-go
    realm_version: 0.1.0
  web:
    kind: leaf
    owner: fixture
    visibility: private
    consumes: [api]
  worker:
    kind: leaf
    owner: fixture
    visibility: private
    realm: helheim-go
    realm_version: 0.1.0
```

Create `testdata/routing/project/web/package-lock.json`:

```json
{
  "name": "web",
  "lockfileVersion": 3,
  "packages": {
    "": { "name": "web" },
    "node_modules/react": { "version": "19.3.0" },
    "node_modules/openapi-fetch": { "version": "0.17.0" },
    "node_modules/vite": { "version": "7.2.0" }
  }
}
```

Create `testdata/routing/project/web/package.json`:

```json
{
  "name": "web",
  "private": true,
  "dependencies": { "react": "19.3.0", "openapi-fetch": "0.17.0" },
  "devDependencies": { "vite": "7.2.0" }
}
```

Create `testdata/routing/project/web/src/main.ts`:

```text
export const app = 1
```

Create `testdata/routing/project/worker/go.mod`:

```go
module example.test/worker

go 1.26

require example.test/api v0.0.0
```

Expected output (this run was taken before part 1 existed, so it also lists `Edge` and `Extracted`; with part 1 in place the first lines are `undefined: Wiring`):

```text
# github.com/ouroboric-dev/odin/internal/routing [github.com/ouroboric-dev/odin/internal/routing.test]
internal/routing/wiring_test.go:21:16: undefined: Edge
internal/routing/wiring_test.go:31:14: undefined: Wiring
internal/routing/wiring_test.go:36:30: undefined: Extracted
internal/routing/wiring_test.go:37:54: undefined: Extracted
internal/routing/wiring_test.go:38:51: undefined: Extracted
...
FAIL	github.com/ouroboric-dev/odin/internal/routing [build failed]
```

- [ ] **Step 5:** write the reader.

Change `go.mod`:

```diff
diff --git a/go.mod b/go.mod
index 74b0418..e6ef846 100644
--- a/go.mod
+++ b/go.mod
@@ -8,10 +8,10 @@ require (
 	github.com/ouroboric-dev/gungnir v0.0.0-20261017195515-cb1dc0ee9cc6
 	github.com/ouroboric-dev/havamal v0.0.0-20261017195922-be698041a5ae
 	github.com/ouroboric-dev/jormungandr v0.0.0-20261017110129-97ae1fd0ad99
+	go.yaml.in/yaml/v3 v3.0.5
 )
 
 require (
 	github.com/santhosh-tekuri/jsonschema/v6 v6.0.3 // indirect
-	go.yaml.in/yaml/v3 v3.0.5 // indirect
 	golang.org/x/text v0.41.0 // indirect
 )
```

Create `internal/routing/wiring.go`:

```go
package routing

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/ouroboric-dev/gungnir/schema"
)

// Limits on what the generator reads. A leaf is written by an agent, so the generator never follows a
// link out of it and never reads without a bound.
const maxFile = 1 << 20 // bytes of one file

// Result is a generated wiring: its edges, and what the generator left out and why.
type Result struct {
	Edges   []Edge
	Skipped []string
}

type wiring struct {
	root    string
	edges   []Edge
	skipped []string
	modules map[string]string // a leaf's Go module path: the leaf
}

// Wiring reads the project umbrella at dir: umbrella.yaml, the packs of the realms it names, and in each
// leaf that is checked out go.mod, go.sum, package.json, package-lock.json, OpenAPI files and Go imports.
// A leaf that isn't checked out has the edges umbrella.yaml gives it, and no more.
func Wiring(dir string, packs map[string]*schema.Pack) (*Result, error) {
	u, err := schema.LoadUmbrella(dir)
	if err != nil {
		return nil, err
	}
	w := &wiring{root: dir, modules: map[string]string{}}
	var leaves []string
	for p, c := range u.Children {
		if c.Kind == schema.ChildLeaf {
			leaves = append(leaves, p)
		}
	}
	slices.Sort(leaves)
	for _, l := range leaves {
		c := u.Children[l]
		for _, q := range c.Consumes {
			w.add(l, "consumes", q, Extracted, schema.UmbrellaFile)
		}
		realm, ver := cmpOr(c.Realm, u.Realm), cmpOr(c.RealmVersion, u.RealmVersion)
		if realm != "" {
			w.add(l, "uses-realm", "realm:"+realm+"@"+ver, Extracted, schema.UmbrellaFile)
			if p := packs[realm]; p != nil {
				for _, s := range slices.Sorted(mapKeys(p.Services)) {
					w.add(l, "needs", "service:"+s, Extracted, "realm:"+realm+"/pack.yaml")
				}
			}
		}
		if m := w.goModule(l); m != "" {
			w.modules[m] = l
		}
	}
	for _, l := range leaves {
		w.goDeps(l)
		w.npmDeps(l)
	}
	return &Result{Edges: Sorted(w.edges), Skipped: slices.Sorted(slices.Values(w.skipped))}, nil
}

func cmpOr(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

func mapKeys[V any](m map[string]V) func(func(string) bool) {
	return func(yield func(string) bool) {
		for k := range m {
			if !yield(k) {
				return
			}
		}
	}
}

// plain reports whether s may sit in a table cell: printable ASCII with none of | < > or a backtick.
func plain(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < 0x20 || r > 0x7e || strings.ContainsRune("|<>`", r) {
			return false
		}
	}
	return true
}

func (w *wiring) skip(format string, a ...any) {
	w.skipped = append(w.skipped, fmt.Sprintf(format, a...))
}

func (w *wiring) add(from, kind, to, tag, source string) {
	if !plain(from) || !plain(to) || !plain(source) {
		w.skip("%s: a name that can't sit in the table: %q", source, to)
		return
	}
	w.edges = append(w.edges, Edge{From: from, To: to, Kind: kind, Tag: tag, Source: source})
}

// read returns the file at rel under the root: a regular file, not a link, within the size limit. A
// missing file is (nil, nil).
func (w *wiring) read(rel string) []byte {
	p := filepath.Join(w.root, filepath.FromSlash(rel))
	fi, err := os.Lstat(p)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return nil
	case err != nil || !fi.Mode().IsRegular():
		w.skip("%s: not a regular file", rel)
		return nil
	case fi.Size() > maxFile:
		w.skip("%s: over %d bytes", rel, maxFile)
		return nil
	}
	f, err := os.Open(p)
	if err != nil {
		w.skip("%s: %v", rel, err)
		return nil
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, maxFile+1))
	if err != nil || len(b) > maxFile {
		w.skip("%s: unreadable or over %d bytes", rel, maxFile)
		return nil
	}
	return b
}

// goMod parses what go.mod says: the module and its direct requirements.
func goMod(b []byte) (module string, req [][2]string) {
	inBlock := false
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		indirect := strings.Contains(line, "// indirect")
		if i := strings.Index(line, "//"); i >= 0 {
			line = strings.TrimSpace(line[:i])
		}
		f := strings.Fields(line)
		switch {
		case len(f) == 2 && f[0] == "module":
			module = strings.Trim(f[1], `"`)
		case line == "require (":
			inBlock = true
		case inBlock && line == ")":
			inBlock = false
		case inBlock && len(f) == 2 && !indirect:
			req = append(req, [2]string{f[0], f[1]})
		case !inBlock && len(f) == 3 && f[0] == "require" && !indirect:
			req = append(req, [2]string{f[1], f[2]})
		}
	}
	return module, req
}

func (w *wiring) goModule(leaf string) string {
	m, _ := goMod(w.read(leaf + "/go.mod"))
	return m
}

func (w *wiring) goDeps(leaf string) {
	b := w.read(leaf + "/go.mod")
	if b == nil {
		return
	}
	_, req := goMod(b)
	sum := string(w.read(leaf + "/go.sum"))
	for _, r := range req {
		if other, ok := w.modules[r[0]]; ok {
			w.add(leaf, "requires", other, Extracted, leaf+"/go.mod")
			continue
		}
		w.add(leaf, "requires", "go:"+r[0], Extracted, leaf+"/go.mod")
		if strings.Contains(sum, r[0]+" "+r[1]+" h1:") {
			w.add(leaf, "pins", "go:"+r[0]+"@"+r[1], Extracted, leaf+"/go.sum")
		}
	}
}

func (w *wiring) npmDeps(leaf string) {
	b := w.read(leaf + "/package.json")
	if b == nil {
		return
	}
	var pkg struct {
		Dependencies    map[string]string `json:"dependencies"`
		DevDependencies map[string]string `json:"devDependencies"`
	}
	if err := json.Unmarshal(b, &pkg); err != nil {
		w.skip("%s/package.json: %v", leaf, err)
		return
	}
	var lock struct {
		Packages map[string]struct {
			Version string `json:"version"`
		} `json:"packages"`
	}
	if lb := w.read(leaf + "/package-lock.json"); lb != nil {
		if err := json.Unmarshal(lb, &lock); err != nil {
			w.skip("%s/package-lock.json: %v", leaf, err)
		}
	}
	names := map[string]bool{}
	for n := range pkg.Dependencies {
		names[n] = true
	}
	for n := range pkg.DevDependencies {
		names[n] = true
	}
	for _, n := range slices.Sorted(mapKeys(names)) {
		if !plain(n) {
			w.skip("%s/package.json: a name that can't sit in the table: %q", leaf, n)
			continue
		}
		w.add(leaf, "requires", "npm:"+n, Extracted, leaf+"/package.json")
		if v := lock.Packages["node_modules/"+n].Version; v != "" {
			w.add(leaf, "pins", "npm:"+n+"@"+v, Extracted, leaf+"/package-lock.json")
		}
	}
}
```

- [ ] **Step 6:** run the tests, then commit.

```bash
gofmt -l .
go vet ./...
go test -race ./internal/routing
```

Expected output: `ok  	github.com/ouroboric-dev/odin/internal/routing`. Commit in `odin`: `Wiring index part 1: the umbrella, the realm packs, go.mod and go.sum, package.json and the lockfile (v0-T251)`.

#### Part 3: imports, contracts, copies, guesses, and a reading that cannot be led out of the leaf (`be6a9fa`)

- [ ] **Step 7:** add the rest of the fixture (the contract files, the worker's import and README) and extend the tests. The golden file is written once with `-update`: read it.

Change `internal/routing/wiring_test.go`:

```diff
diff --git a/internal/routing/wiring_test.go b/internal/routing/wiring_test.go
index f5a6fa4..9684952 100644
--- a/internal/routing/wiring_test.go
+++ b/internal/routing/wiring_test.go
@@ -1,6 +1,7 @@
 package routing
 
 import (
+	"flag"
 	"os"
 	"path/filepath"
 	"strings"
@@ -27,7 +28,7 @@ func find(es []Edge, from, kind, to string) *Edge {
 	return nil
 }
 
-func TestWiringReadsTheUmbrellaThePacksManifestsAndLockfiles(t *testing.T) {
+func TestWiringReadsManifestsLockfilesContractsAndImports(t *testing.T) {
 	res, err := Wiring(fixture, packs())
 	if err != nil {
 		t.Fatal(err)
@@ -40,8 +41,13 @@ func TestWiringReadsTheUmbrellaThePacksManifestsAndLockfiles(t *testing.T) {
 		{"api", "requires", "go:github.com/go-chi/chi/v5", Extracted, "api/go.mod"},
 		{"api", "pins", "go:github.com/go-chi/chi/v5@v5.2.3", Extracted, "api/go.sum"},
 		{"worker", "requires", "api", Extracted, "worker/go.mod"},
+		{"worker", "imports", "api", Extracted, "worker/cmd/worker/main.go"},
 		{"web", "requires", "npm:react", Extracted, "web/package.json"},
 		{"web", "pins", "npm:react@19.3.0", Extracted, "web/package-lock.json"},
+		{"api", "holds", "contract:api/internal/api.openapi.yaml", Extracted, "api/internal/api.openapi.yaml"},
+		{"contract:web/contracts/api.openapi.yaml", "copies", "contract:api/internal/api.openapi.yaml", Extracted, "web/contracts/api.openapi.yaml"},
+		{"contract:worker/internal/api.openapi.yaml", "copies", "contract:api/internal/api.openapi.yaml", Inferred, "worker/internal/api.openapi.yaml"},
+		{"worker", "mentions", "web", Inferred, "worker/README.md"},
 	} {
 		e := find(res.Edges, w.from, w.kind, w.to)
 		if e == nil {
@@ -68,7 +74,7 @@ func TestEveryEdgeIsTaggedExtractedOrInferred(t *testing.T) {
 		}
 	}
 	x, i := Counts(res.Edges)
-	if x == 0 || x+i != len(res.Edges) {
+	if x == 0 || i == 0 || x+i != len(res.Edges) {
 		t.Errorf("counts %d extracted, %d inferred of %d", x, i, len(res.Edges))
 	}
 }
@@ -92,26 +98,32 @@ func TestWiringIsTheSameBytesEveryTime(t *testing.T) {
 	}
 }
 
-// Review focus: package names come from files an agent wrote. A name must not break the table or the
-// markers, and must not hide the good names beside it.
-func TestWiringDropsNamesThatBreakTheTable(t *testing.T) {
+// Review focus: leaf files are written by an agent. A link must not lead the generator out of the leaf,
+// and a name must not be able to break the table or the markers.
+func TestWiringIgnoresSymlinksHugeFilesAndNamesThatBreakTheTable(t *testing.T) {
 	dir := t.TempDir()
 	copyTree(t, fixture, dir)
+	outside := filepath.Join(t.TempDir(), "secret.openapi.yaml")
+	os.WriteFile(outside, []byte("openapi: 3.0.3\ninfo: {title: secret}\n"), 0o644)
+	if err := os.Symlink(outside, filepath.Join(dir, "api/internal/leak.openapi.yaml")); err != nil {
+		t.Fatal(err)
+	}
 	os.WriteFile(filepath.Join(dir, "web/package.json"), []byte(`{"dependencies":{"a|b":"1.0.0","x\n`+EndMarker+`":"1.0.0","ok":"1.0.0"}}`), 0o644)
+	os.WriteFile(filepath.Join(dir, "worker/big.go"), []byte("package big\n"+strings.Repeat("// pad\n", 200000)), 0o644)
 	res, err := Wiring(dir, packs())
 	if err != nil {
 		t.Fatal(err)
 	}
 	for _, e := range res.Edges {
-		if strings.ContainsAny(e.To, "|\n<") {
-			t.Errorf("edge %+v can break the table", e)
+		if strings.Contains(e.To+e.From+e.Source, "leak") || strings.ContainsAny(e.To, "|\n") {
+			t.Errorf("edge %+v came from a link or a bad name", e)
 		}
 	}
 	if find(res.Edges, "web", "requires", "npm:ok") == nil {
 		t.Error("a good dependency was dropped with the bad ones")
 	}
-	if len(res.Skipped) != 2 {
-		t.Errorf("skipped = %v; want the two bad names reported", res.Skipped)
+	if len(res.Skipped) < 3 {
+		t.Errorf("skipped = %v; want the link, the two names and the big file reported", res.Skipped)
 	}
 }
 
@@ -135,3 +147,25 @@ func copyTree(t *testing.T, from, to string) {
 		t.Fatal(err)
 	}
 }
+
+// The block of the fixture is pinned byte by byte. A change of the generator that moves a row shows here.
+// Run `go test ./internal/routing -run Golden -update` to write it again, and read the diff.
+func TestTheFixtureBlockMatchesItsGoldenFile(t *testing.T) {
+	res, err := Wiring(fixture, packs())
+	if err != nil {
+		t.Fatal(err)
+	}
+	golden := "../../testdata/routing/wiring.golden.md"
+	got := Block(res.Edges)
+	if *update {
+		if err := os.WriteFile(golden, got, 0o644); err != nil {
+			t.Fatal(err)
+		}
+	}
+	want, err := os.ReadFile(golden)
+	if err != nil || string(want) != string(got) {
+		t.Errorf("the block differs from %s (%v):\n%s", golden, err, got)
+	}
+}
+
+var update = flag.Bool("update", false, "write the golden files again")
```

Create `testdata/routing/project/api/internal/api.openapi.yaml`:

```yaml
openapi: 3.0.3
info:
  title: Gallery API
  version: 1.0.0
paths:
  /galleries/{id}:
    get:
      operationId: getGallery
      parameters:
        - { name: id, in: path, required: true, schema: { type: string } }
      responses:
        "200": { description: the gallery }
```

Create `testdata/routing/project/web/contracts/api.openapi.yaml`:

```yaml
openapi: 3.0.3
info:
  title: Gallery API
  version: 1.0.0
paths:
  /galleries/{id}:
    get:
      operationId: getGallery
      parameters:
        - { name: id, in: path, required: true, schema: { type: string } }
      responses:
        "200": { description: the gallery }
```

Create `testdata/routing/project/worker/README.md`:

```markdown
# worker

Sends mail for the web app. It reads galleries the way the api serves them.
```

Create `testdata/routing/project/worker/cmd/worker/main.go`:

```go
package main

import (
	"fmt"

	"example.test/api/client"
)

func main() { fmt.Println(client.Name) }
```

Create `testdata/routing/project/worker/internal/api.openapi.yaml`:

```yaml
openapi: 3.0.3
info:
  title: Gallery API
  version: 0.9.0
paths:
  /galleries/{id}:
    get:
      operationId: getGallery
      parameters:
        - { name: id, in: path, required: true, schema: { type: string } }
      responses:
        "200": { description: the gallery }
```

Create `testdata/routing/wiring.golden.md` (written by `go test ./internal/routing -run Golden -update`; read the diff before you commit it):

```markdown
<!-- ygg:wiring:begin -->
<!-- Generated by ygg from the manifests, lockfiles and contracts of the leaves. Do not edit. -->

| From | Kind | To | Tag | Source |
|---|---|---|---|---|
| api | holds | contract:api/internal/api.openapi.yaml | extracted | api/internal/api.openapi.yaml |
| api | needs | service:postgres | extracted | realm:helheim-go/pack.yaml |
| api | needs | service:seaweedfs | extracted | realm:helheim-go/pack.yaml |
| api | pins | go:github.com/go-chi/chi/v5@v5.2.3 | extracted | api/go.sum |
| api | requires | go:github.com/go-chi/chi/v5 | extracted | api/go.mod |
| api | uses-realm | realm:helheim-go@0.1.0 | extracted | umbrella.yaml |
| contract:web/contracts/api.openapi.yaml | copies | contract:api/internal/api.openapi.yaml | extracted | web/contracts/api.openapi.yaml |
| contract:worker/internal/api.openapi.yaml | copies | contract:api/internal/api.openapi.yaml | inferred | worker/internal/api.openapi.yaml |
| web | consumes | api | extracted | umbrella.yaml |
| web | holds | contract:web/contracts/api.openapi.yaml | extracted | web/contracts/api.openapi.yaml |
| web | pins | npm:openapi-fetch@0.17.0 | extracted | web/package-lock.json |
| web | pins | npm:react@19.3.0 | extracted | web/package-lock.json |
| web | pins | npm:vite@7.2.0 | extracted | web/package-lock.json |
| web | requires | npm:openapi-fetch | extracted | web/package.json |
| web | requires | npm:react | extracted | web/package.json |
| web | requires | npm:vite | extracted | web/package.json |
| web | uses-realm | realm:midgard-react@0.1.0 | extracted | umbrella.yaml |
| worker | holds | contract:worker/internal/api.openapi.yaml | extracted | worker/internal/api.openapi.yaml |
| worker | imports | api | extracted | worker/cmd/worker/main.go |
| worker | mentions | web | inferred | worker/README.md |
| worker | needs | service:postgres | extracted | realm:helheim-go/pack.yaml |
| worker | needs | service:seaweedfs | extracted | realm:helheim-go/pack.yaml |
| worker | requires | api | extracted | worker/go.mod |
| worker | uses-realm | realm:helheim-go@0.1.0 | extracted | umbrella.yaml |
<!-- ygg:wiring:end -->
```

- [ ] **Step 8:** extend the reader.

Change `internal/routing/wiring.go`:

```diff
diff --git a/internal/routing/wiring.go b/internal/routing/wiring.go
index ef13cbf..28b74bd 100644
--- a/internal/routing/wiring.go
+++ b/internal/routing/wiring.go
@@ -1,22 +1,34 @@
 package routing
 
 import (
+	"crypto/sha256"
 	"encoding/json"
 	"errors"
 	"fmt"
+	"go/parser"
+	"go/token"
 	"io"
 	"io/fs"
 	"os"
+	"path"
 	"path/filepath"
+	"regexp"
 	"slices"
+	"strconv"
 	"strings"
 
 	"github.com/ouroboric-dev/gungnir/schema"
+	"go.yaml.in/yaml/v3"
 )
 
 // Limits on what the generator reads. A leaf is written by an agent, so the generator never follows a
 // link out of it and never reads without a bound.
-const maxFile = 1 << 20 // bytes of one file
+const (
+	maxFile    = 1 << 20 // bytes of one file
+	maxEntries = 20000   // files and folders walked in one leaf
+)
+
+var skipDirs = map[string]bool{".git": true, "node_modules": true, "vendor": true, "testdata": true, "dist": true, ".factory": true}
 
 // Result is a generated wiring: its edges, and what the generator left out and why.
 type Result struct {
@@ -31,6 +43,11 @@ type wiring struct {
 	modules map[string]string // a leaf's Go module path: the leaf
 }
 
+type contractFile struct {
+	leaf, rel, title string
+	sum              string
+}
+
 // Wiring reads the project umbrella at dir: umbrella.yaml, the packs of the realms it names, and in each
 // leaf that is checked out go.mod, go.sum, package.json, package-lock.json, OpenAPI files and Go imports.
 // A leaf that isn't checked out has the edges umbrella.yaml gives it, and no more.
@@ -65,10 +82,15 @@ func Wiring(dir string, packs map[string]*schema.Pack) (*Result, error) {
 			w.modules[m] = l
 		}
 	}
+	var contracts []contractFile
 	for _, l := range leaves {
 		w.goDeps(l)
 		w.npmDeps(l)
+		w.goImports(l)
+		contracts = append(contracts, w.contracts(l)...)
 	}
+	w.copies(contracts)
+	w.mentions(leaves)
 	return &Result{Edges: Sorted(w.edges), Skipped: slices.Sorted(slices.Values(w.skipped))}, nil
 }
 
@@ -234,3 +256,141 @@ func (w *wiring) npmDeps(leaf string) {
 		}
 	}
 }
+
+// walk lists the regular files of a leaf, by path relative to the root, never through a link.
+func (w *wiring) walk(leaf string, keep func(rel string) bool) []string {
+	var out []string
+	n := 0
+	base := filepath.Join(w.root, leaf)
+	if fi, err := os.Lstat(base); err != nil || !fi.IsDir() {
+		return nil
+	}
+	_ = filepath.WalkDir(base, func(p string, d fs.DirEntry, err error) error {
+		if err != nil {
+			return nil
+		}
+		if n++; n > maxEntries {
+			w.skip("%s: more than %d entries; the rest is not read", leaf, maxEntries)
+			return filepath.SkipAll
+		}
+		rel, _ := filepath.Rel(w.root, p)
+		rel = filepath.ToSlash(rel)
+		switch {
+		case d.IsDir() && skipDirs[d.Name()]:
+			return filepath.SkipDir
+		case d.Type()&fs.ModeSymlink != 0:
+			if keep(rel) {
+				w.skip("%s: a link, not followed", rel)
+			}
+		case d.Type().IsRegular() && keep(rel):
+			out = append(out, rel)
+		}
+		return nil
+	})
+	return out
+}
+
+func (w *wiring) goImports(leaf string) {
+	if len(w.modules) == 0 {
+		return
+	}
+	seen := map[string]bool{}
+	for _, rel := range w.walk(leaf, func(r string) bool { return strings.HasSuffix(r, ".go") && !strings.HasSuffix(r, "_test.go") }) {
+		b := w.read(rel)
+		if b == nil {
+			continue
+		}
+		f, err := parser.ParseFile(token.NewFileSet(), rel, b, parser.ImportsOnly)
+		if err != nil {
+			continue
+		}
+		for _, imp := range f.Imports {
+			p, _ := strconv.Unquote(imp.Path.Value)
+			for m, other := range w.modules {
+				if other != leaf && !seen[other] && (p == m || strings.HasPrefix(p, m+"/")) {
+					seen[other] = true
+					w.add(leaf, "imports", other, Extracted, rel)
+				}
+			}
+		}
+	}
+}
+
+func isContractName(rel string) bool {
+	b := path.Base(rel)
+	return strings.HasSuffix(b, "openapi.yaml") || strings.HasSuffix(b, "openapi.yml")
+}
+
+func (w *wiring) contracts(leaf string) []contractFile {
+	var out []contractFile
+	for _, rel := range w.walk(leaf, isContractName) {
+		b := w.read(rel)
+		var doc struct {
+			OpenAPI string `yaml:"openapi"`
+			Info    struct {
+				Title string `yaml:"title"`
+			} `yaml:"info"`
+		}
+		if b == nil || yaml.Unmarshal(b, &doc) != nil || doc.OpenAPI == "" {
+			if b != nil {
+				w.skip("%s: not an OpenAPI document", rel)
+			}
+			continue
+		}
+		w.add(leaf, "holds", "contract:"+rel, Extracted, rel)
+		out = append(out, contractFile{leaf: leaf, rel: rel, title: doc.Info.Title, sum: fmt.Sprintf("%x", sha256.Sum256(b))})
+	}
+	return out
+}
+
+// copies links a leaf's contract to the contract of a leaf it depends on, when both name the same API.
+// Identical bytes are a fact (extracted). The same title with other bytes is a guess that it is the
+// same contract gone out of date (inferred).
+func (w *wiring) copies(cs []contractFile) {
+	linked := map[[2]string]bool{}
+	for _, e := range w.edges {
+		if e.Tag == Extracted && (e.Kind == "consumes" || e.Kind == "requires" || e.Kind == "imports") {
+			linked[[2]string{e.From, e.To}] = true
+		}
+	}
+	for _, c := range cs {
+		for _, o := range cs {
+			if c.leaf == o.leaf || c.title == "" || c.title != o.title || !linked[[2]string{c.leaf, o.leaf}] {
+				continue
+			}
+			tag := Inferred
+			if c.sum == o.sum {
+				tag = Extracted
+			}
+			w.add("contract:"+c.rel, "copies", "contract:"+o.rel, tag, c.rel)
+		}
+	}
+}
+
+// mentions is a guess: a leaf's README or AGENTS.md names another leaf. It is added only where no
+// extracted edge already joins the two.
+func (w *wiring) mentions(leaves []string) {
+	joined := map[[2]string]bool{}
+	for _, e := range w.edges {
+		if e.Tag == Extracted {
+			joined[[2]string{e.From, e.To}] = true
+		}
+	}
+	for _, l := range leaves {
+		for _, doc := range []string{"README.md", "AGENTS.md"} {
+			b := w.read(l + "/" + doc)
+			if b == nil {
+				continue
+			}
+			for _, o := range leaves {
+				if o == l || joined[[2]string{l, o}] {
+					continue
+				}
+				if regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(o) + `\b`).Match(b) {
+					w.add(l, "mentions", o, Inferred, l+"/"+doc)
+					joined[[2]string{l, o}] = true
+				}
+			}
+		}
+	}
+}
```

- [ ] **Step 9:** run the tests and the whole suite, then commit.

```bash
gofmt -l .
go vet ./...
go test -race -v -run 'TestWiring|TestEveryEdge|TestTheFixtureBlock|TestTheBlock|TestAStray' ./internal/routing
```

Expected output:

```text
--- PASS: TestTheBlockReplacesItselfAndKeepsThePeopleText (0.00s)
--- PASS: TestAStrayMarkerIsAnErrorAndCutsNothing (0.00s)
--- PASS: TestWiringReadsManifestsLockfilesContractsAndImports (0.02s)
--- PASS: TestEveryEdgeIsTaggedExtractedOrInferred (0.01s)
--- PASS: TestWiringIsTheSameBytesEveryTime (0.03s)
--- PASS: TestWiringIgnoresSymlinksHugeFilesAndNamesThatBreakTheTable (0.03s)
--- PASS: TestTheFixtureBlockMatchesItsGoldenFile (0.01s)
PASS
ok  	github.com/ouroboric-dev/odin/internal/routing	1.137s
```

Commit in `odin`: `Wiring index part 2: Go imports, OpenAPI contracts and their copies, guessed mentions; links and big files are never read (v0-T251)`.

**Evidence:** the test files were written before the code. The red run is above (a build failure: no `Wiring`, no `Edge`). The green run is above, with `-race`. `go test -race ./...` in `odin` passed in all packages with the three commits in place (`internal/engine` takes about 100 seconds). The symlink test makes a real link to a file outside the fixture copy and a real file of 1.4 MB. The fixture lives under `testdata/routing/project` and has no git history, so no network and no engine is needed.

### Task v0-T252: the impact index generator: what a change to X reaches

Spec §8.2: the impact index says what a change to a file or contract affects. It is always labelled a lower bound. It keeps every
guess apart from the facts. One commit (`26f99eb`).

**Files (in `odin`):**

- Create: `internal/routing/impact.go`, `internal/routing/impact_test.go`, `testdata/routing/impact.golden.json`
- Modify: `internal/routing/wiring.go` (`Result` gains `Leaves`, `Contracts`)

**Interfaces:**

- Consumes: `routing.Result` and the edges of v0-T251.
- Produces: `routing.Impact` (JSON file `.ygg/impact.json`, schema `ygg.impact/v1`, `"bound": "lower"`), with `edges`, `extracted`, `inferred`, `contracts[]` (`id`, `path`, `owner`, `sha256`, `readers{extracted[],inferred[]}`), `reach{<node>: {extracted[], inferred[]}}` and `inferred_edges[]` (every guess, in full).
- Produces: `routing.ImpactOf(*Result) *Impact`, `(*Impact).Reaches(node)`, `(*Impact).Contract(path)`, `(*Impact).JSON()`, `routing.WriteImpact(dir, imp)`, `routing.ReadImpact(dir)`, `routing.ParseImpact([]byte)` (strict: unknown field, other schema or a bound other than `lower` is an error), `routing.ImpactFile`.
- How a change reaches: the edges are read backwards. A change to X reaches every node with an edge to X, then every node with an edge to those. `reach.extracted` holds what a chain of extracted edges reaches. `reach.inferred` holds what only a chain with a guess in it reaches. A node is in one list. Only leaves and contracts are reported. The subject X can be a leaf, a contract, a package, a realm or a service.
- A contract's `readers` are the leaves other than its owner that a change to it reaches.

**Acceptance criteria:**

- [ ] A change to the api's contract reaches web and worker by extracted edges. A change to web reaches worker only as a guess (the README mention).
- [ ] A bump of `go:github.com/go-chi/chi/v5` reaches `api`, and `web` and `worker` through `api`.
- [ ] The fixture index has 24 edges: 22 extracted and 2 inferred, and the two guesses are in `inferred_edges`.
- [ ] Two runs give the same bytes, and the bytes equal the golden file. `WriteImpact` then `ReadImpact` round-trips.

**Review focus pinned by tests:**

- A lower bound, and guesses apart: `TestTheImpactIndexIsALabelledLowerBoundAndReportsGuessesApart`.
- A guess is never counted as a fact: `TestAChangeToALeafReachesWhatDependsOnIt` (web reaches worker in `inferred` only).
- Same input, same bytes: `TestTheImpactIndexIsTheSameBytesEveryTimeAndRoundTrips`.

**Named test:** `go test ./internal/routing -run 'TestAChange|TestTheImpact'`. **Layer:** `odin`. **Size:** M (510, 140 of them the golden file). **Depends on:** v0-T251.

- [ ] **Step 1:** write the tests first.

Create `internal/routing/impact_test.go`:

```go
package routing

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func fixtureImpact(t *testing.T) *Impact {
	t.Helper()
	res, err := Wiring(fixture, packs())
	if err != nil {
		t.Fatal(err)
	}
	return ImpactOf(res)
}

func TestAChangeToAContractReachesItsOwnerAndItsReaders(t *testing.T) {
	imp := fixtureImpact(t)
	c, ok := imp.Contract("api/internal/api.openapi.yaml")
	if !ok {
		t.Fatal("the api's contract is not in the index")
	}
	if c.Owner != "api" || len(c.SHA256) != 64 {
		t.Errorf("contract = %+v", c)
	}
	if !slices.Equal(c.Readers.Extracted, []string{"web", "worker"}) || len(c.Readers.Inferred) != 0 {
		t.Errorf("readers = %+v, want web and worker, both extracted", c.Readers)
	}
	// The worker's copy of the contract is linked by title only: a change to that copy reaches nothing
	// by a fact, and the guess is reported on its own.
	w, ok := imp.Contract("worker/internal/api.openapi.yaml")
	if !ok || len(w.Readers.Extracted) != 0 {
		t.Errorf("worker's copy = %+v, %v", w, ok)
	}
}

func TestAChangeToALeafReachesWhatDependsOnIt(t *testing.T) {
	imp := fixtureImpact(t)
	r := imp.Reaches("api")
	if !slices.Equal(r.Extracted, []string{"web", "worker"}) {
		t.Errorf("api reaches %+v", r)
	}
	// worker is only guessed to be read by nobody; a change to web reaches worker only by the README guess.
	r = imp.Reaches("web")
	if len(r.Extracted) != 0 || !slices.Equal(r.Inferred, []string{"worker"}) {
		t.Errorf("web reaches %+v, want worker as a guess only", r)
	}
	if r := imp.Reaches("go:github.com/go-chi/chi/v5"); !slices.Equal(r.Extracted, []string{"api", "web", "worker"}) {
		t.Errorf("a bump of chi reaches %+v, want api and what depends on api", r)
	}
	if r := imp.Reaches("nobody"); len(r.Extracted)+len(r.Inferred) != 0 {
		t.Errorf("an unknown node reaches %+v", r)
	}
}

func TestTheImpactIndexIsALabelledLowerBoundAndReportsGuessesApart(t *testing.T) {
	imp := fixtureImpact(t)
	b, err := imp.JSON()
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatal(err)
	}
	if m["schema"] != "ygg.impact/v1" || m["bound"] != "lower" {
		t.Errorf("schema %v, bound %v", m["schema"], m["bound"])
	}
	inferred, _ := m["inferred_edges"].([]any)
	if len(inferred) != 2 {
		t.Errorf("inferred_edges = %v, want the two guesses of the fixture", inferred)
	}
	if m["edges"].(float64) != 24 || m["extracted"].(float64) != 22 || m["inferred"].(float64) != 2 {
		t.Errorf("counts %v/%v/%v", m["edges"], m["extracted"], m["inferred"])
	}
}

func TestTheImpactIndexIsTheSameBytesEveryTimeAndRoundTrips(t *testing.T) {
	a, _ := fixtureImpact(t).JSON()
	b, _ := fixtureImpact(t).JSON()
	if !bytes.Equal(a, b) {
		t.Fatal("two runs gave two indexes")
	}
	golden := "../../testdata/routing/impact.golden.json"
	if *update {
		os.WriteFile(golden, a, 0o644)
	}
	if want, err := os.ReadFile(golden); err != nil || !bytes.Equal(want, a) {
		t.Errorf("the index differs from %s (%v):\n%s", golden, err, a)
	}
	dir := t.TempDir()
	res, _ := Wiring(fixture, packs())
	if err := WriteImpact(dir, ImpactOf(res)); err != nil {
		t.Fatal(err)
	}
	got, err := ReadImpact(dir)
	if err != nil || got.Edges != 24 {
		t.Fatalf("ReadImpact = %+v, %v", got, err)
	}
	if _, err := os.Stat(filepath.Join(dir, ImpactFile)); err != nil {
		t.Error(err)
	}
}
```

Expected output:

```text
# github.com/ouroboric-dev/odin/internal/routing [github.com/ouroboric-dev/odin/internal/routing.test]
internal/routing/impact_test.go:12:35: undefined: Impact
internal/routing/impact_test.go:18:9: undefined: ImpactOf
internal/routing/impact_test.go:97:12: undefined: WriteImpact
internal/routing/impact_test.go:97:29: undefined: ImpactOf
FAIL	github.com/ouroboric-dev/odin/internal/routing [build failed]
```

- [ ] **Step 2:** write the generator.

Create `internal/routing/impact.go`:

```go
package routing

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"slices"
)

// ImpactFile is the impact index, in the project umbrella (spec §8.2).
const ImpactFile = ".ygg/impact.json"

// ImpactSchema names the format of the file.
const ImpactSchema = "ygg.impact/v1"

// Reached is what a change reaches, in leaves and contracts. Extracted holds what a chain of extracted
// edges reaches. Inferred holds what only a chain with a guess in it reaches. A node is in one list.
type Reached struct {
	Extracted []string `json:"extracted"`
	Inferred  []string `json:"inferred"`
}

// ContractEntry is a contract and who reads it.
type ContractEntry struct {
	ID      string  `json:"id"`
	Path    string  `json:"path"`
	Owner   string  `json:"owner"`
	SHA256  string  `json:"sha256"`
	Readers Reached `json:"readers"` // leaves, other than the owner, that a change to the contract reaches
}

// Impact is the impact index: what a change to a leaf, a contract or a package reaches. It is a lower
// bound: it holds what manifests, imports, lockfiles and contracts show, and nothing else.
type Impact struct {
	Schema        string             `json:"schema"`
	Bound         string             `json:"bound"` // always "lower"
	Edges         int                `json:"edges"`
	Extracted     int                `json:"extracted"`
	Inferred      int                `json:"inferred"`
	Contracts     []ContractEntry    `json:"contracts"`
	Reach         map[string]Reached `json:"reach"`
	InferredEdges []Edge             `json:"inferred_edges"` // every guess, listed apart from the facts
}

// ImpactOf builds the index from a wiring. A change to X reaches every node that has an edge to X, and
// every node that has an edge to those, and so on: the edges are read backwards.
func ImpactOf(res *Result) *Impact {
	imp := &Impact{Schema: ImpactSchema, Bound: "lower", Edges: len(res.Edges), Contracts: []ContractEntry{},
		Reach: map[string]Reached{}, InferredEdges: []Edge{}}
	imp.Extracted, imp.Inferred = Counts(res.Edges)
	back := map[string][]Edge{} // node: the edges that point at it
	nodes := map[string]bool{}
	for _, e := range res.Edges {
		back[e.To] = append(back[e.To], e)
		nodes[e.To] = true
		if e.Tag == Inferred {
			imp.InferredEdges = append(imp.InferredEdges, e)
		}
	}
	reportable := map[string]bool{}
	for _, l := range res.Leaves {
		reportable[l] = true
	}
	for _, c := range res.Contracts {
		reportable["contract:"+c.Path] = true
	}
	for n := range nodes {
		if r := reach(n, back, reportable); len(r.Extracted)+len(r.Inferred) > 0 {
			imp.Reach[n] = r
		}
	}
	for _, c := range res.Contracts {
		r := reach("contract:"+c.Path, back, reportable)
		r = Reached{Extracted: leavesOnly(r.Extracted, c.Owner, res.Leaves), Inferred: leavesOnly(r.Inferred, c.Owner, res.Leaves)}
		imp.Contracts = append(imp.Contracts, ContractEntry{ID: "contract:" + c.Path, Path: c.Path, Owner: c.Owner, SHA256: c.SHA256, Readers: r})
	}
	return imp
}

func leavesOnly(ids []string, owner string, leaves []string) []string {
	out := []string{}
	for _, id := range ids {
		if id != owner && slices.Contains(leaves, id) {
			out = append(out, id)
		}
	}
	return out
}

// reach walks the edges backwards from n twice: along extracted edges only, then along all of them.
func reach(n string, back map[string][]Edge, keep map[string]bool) Reached {
	walk := func(onlyExtracted bool) map[string]bool {
		seen := map[string]bool{n: true}
		queue := []string{n}
		for len(queue) > 0 {
			cur := queue[0]
			queue = queue[1:]
			for _, e := range back[cur] {
				if (onlyExtracted && e.Tag != Extracted) || seen[e.From] {
					continue
				}
				seen[e.From] = true
				queue = append(queue, e.From)
			}
		}
		delete(seen, n)
		return seen
	}
	fact, all := walk(true), walk(false)
	r := Reached{Extracted: []string{}, Inferred: []string{}}
	for id := range all {
		switch {
		case !keep[id]:
		case fact[id]:
			r.Extracted = append(r.Extracted, id)
		default:
			r.Inferred = append(r.Inferred, id)
		}
	}
	slices.Sort(r.Extracted)
	slices.Sort(r.Inferred)
	return r
}

// Reaches returns what a change to node reaches: a leaf path, a contract id, or a package, realm or
// service node. An unknown node reaches nothing.
func (i *Impact) Reaches(node string) Reached {
	if r, ok := i.Reach[node]; ok {
		return r
	}
	return Reached{Extracted: []string{}, Inferred: []string{}}
}

// Contract returns the contract in the file at path (from the project root).
func (i *Impact) Contract(path string) (ContractEntry, bool) {
	for _, c := range i.Contracts {
		if c.Path == path {
			return c, true
		}
	}
	return ContractEntry{}, false
}

// JSON renders the index: indented, keys in a fixed order, one trailing newline.
func (i *Impact) JSON() ([]byte, error) {
	b, err := json.MarshalIndent(i, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(b, '\n'), nil
}

// WriteImpact writes the index to dir/.ygg/impact.json.
func WriteImpact(dir string, i *Impact) error {
	b, err := i.JSON()
	if err != nil {
		return err
	}
	p := filepath.Join(dir, filepath.FromSlash(ImpactFile))
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	return os.WriteFile(p, b, 0o644)
}

// ReadImpact reads dir/.ygg/impact.json.
func ReadImpact(dir string) (*Impact, error) {
	b, err := os.ReadFile(filepath.Join(dir, filepath.FromSlash(ImpactFile)))
	if err != nil {
		return nil, err
	}
	return ParseImpact(b)
}

// ParseImpact parses an index. It refuses an unknown field, another schema, and an index that is not
// labelled a lower bound.
func ParseImpact(b []byte) (*Impact, error) {
	var i Impact
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&i); err != nil {
		return nil, err
	}
	if i.Schema != ImpactSchema || i.Bound != "lower" {
		return nil, fmt.Errorf("impact index: schema %q and bound %q; want %q and \"lower\"", i.Schema, i.Bound, ImpactSchema)
	}
	return &i, nil
}
```

Change `internal/routing/wiring.go`:

```diff
diff --git a/internal/routing/wiring.go b/internal/routing/wiring.go
index 28b74bd..7701220 100644
--- a/internal/routing/wiring.go
+++ b/internal/routing/wiring.go
@@ -32,8 +32,17 @@ var skipDirs = map[string]bool{".git": true, "node_modules": true, "vendor": tru
 
 // Result is a generated wiring: its edges, and what the generator left out and why.
 type Result struct {
-	Edges   []Edge
-	Skipped []string
+	Edges     []Edge
+	Leaves    []string   // the leaves of the umbrella, sorted
+	Contracts []Contract // the OpenAPI files found, sorted by path
+	Skipped   []string
+}
+
+// Contract is an OpenAPI file that a leaf holds.
+type Contract struct {
+	Path   string `json:"path"` // from the project root
+	Owner  string `json:"owner"`
+	SHA256 string `json:"sha256"`
 }
 
 type wiring struct {
@@ -91,7 +100,12 @@ func Wiring(dir string, packs map[string]*schema.Pack) (*Result, error) {
 	}
 	w.copies(contracts)
 	w.mentions(leaves)
-	return &Result{Edges: Sorted(w.edges), Skipped: slices.Sorted(slices.Values(w.skipped))}, nil
+	res := &Result{Edges: Sorted(w.edges), Leaves: leaves, Skipped: slices.Sorted(slices.Values(w.skipped))}
+	for _, c := range contracts {
+		res.Contracts = append(res.Contracts, Contract{Path: c.rel, Owner: c.leaf, SHA256: c.sum})
+	}
+	slices.SortFunc(res.Contracts, func(a, b Contract) int { return strings.Compare(a.Path, b.Path) })
+	return res, nil
 }
 
 func cmpOr(a, b string) string {
```

- [ ] **Step 3:** write the golden file, read it, run the tests, commit.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/odin
go test ./internal/routing -run 'TestTheImpactIndexIsTheSameBytes' -update
git diff --stat testdata/routing/impact.golden.json
go test -race -v -run 'TestAChange|TestTheImpact' ./internal/routing
```

Expected output:

```text
--- PASS: TestAChangeToAContractReachesItsOwnerAndItsReaders (0.01s)
--- PASS: TestAChangeToALeafReachesWhatDependsOnIt (0.01s)
--- PASS: TestTheImpactIndexIsALabelledLowerBoundAndReportsGuessesApart (0.01s)
--- PASS: TestTheImpactIndexIsTheSameBytesEveryTimeAndRoundTrips (0.02s)
ok  	github.com/ouroboric-dev/odin/internal/routing	1.073s
```

Commit in `odin`: `The impact index: what a change to a leaf, a contract or a package reaches, as a lower bound, guesses kept apart (v0-T252)`. The golden file is generated, so the plan does not copy its 300 lines. Its first lines are the `schema`, `bound: lower`, `edges: 24`, `extracted: 22`, `inferred: 2`, then the three contracts of the fixture: the api's contract has readers `web` and `worker` (extracted), the web copy has `worker` as an inferred reader.

**Evidence:** red run (build failure) and green run above, with `-race`. The golden file was read by hand before it was committed. `go test -race ./...` passed in `odin`.

### Task v0-T253: the shrink guard covers both indexes, and a pointer move builds them and logs `routing_index_built`

Spec §8.3: a generated file committed at a pointer move is refused if it has fewer than 50% of the previous version's rows. The
5b guard counts lines. A person's text around the `REPOS.md` block would hide a loss, and an impact index is JSON, so this task
makes the guard count edges. It also puts the generators into the move. One commit (`e6c4a3b`).

**Files (in `odin`):**

- Create: `internal/engine/routing.go`, `internal/engine/routing_test.go`
- Modify: `internal/shrink/shrink.go`, `internal/shrink/shrink_test.go`, `internal/pointer/pointer.go`, `internal/routing/block.go` (`WiringRows`), `internal/routing/impact.go` (`ImpactRows`), `internal/engine/land.go`, `internal/engine/land_test.go`, `internal/engine/ledgergaps_test.go`

**Interfaces:**

- Consumes: `gungnir.EventRoutingIndexBuilt` and its fields `IndexKind`, `Edges`, `Extracted`, `Inferred` (v0-T245).
- Produces: `shrink.Guard(file, prev, next)`. For a file called `REPOS.md` it counts the rows of the wiring block. For `.ygg/impact.json` it counts `edges + contracts + reach entries`. Any other file counts its lines, as `shrink.Check` does (which stays). A `next` with no block, or that is not an index, has no rows. A `prev` that cannot be counted leaves nothing to compare with: `next` passes. The limit is the spec's: under half is refused.
- Produces: `routing.WiringRows([]byte) (rows int, found bool)`, `routing.ImpactRows([]byte) (rows int, ok bool)`.
- `pointer.Move` uses `shrink.Guard` for every file of `Spec.Generated`. A refusal is a `*shrink.Error`, the hard approval point `shrink-guard`, as before.
- A pointer node that lists `REPOS.md` or `.ygg/impact.json` in `generated` has Odin rebuild that file before the move (`engine.shipRouting`), in the project umbrella only. For each file it writes, it logs `routing_index_built` (`kind` `wiring` or `impact`, `edges`, `extracted`, `inferred`; the ledger note says how many files were left out, if any).

**Acceptance criteria:**

- [ ] A `REPOS.md` with 40 lines of text and a block of 10 edges, replaced by one with the same text and 2 edges, is refused. `shrink.Check` alone misses it.
- [ ] Exactly half passes. A first block in a file with none passes. A `REPOS.md` that lost its block is refused.
- [ ] An impact index of 20 edges replaced by one of 3 is refused; 10 passes; a damaged old index passes; an unreadable new one is refused.
- [ ] A run whose leaf has a `go.mod` with one requirement and a `move` node that lists both files commits `.ygg/impact.json`, `REPOS.md` and the pointer in one commit, and the ledger has two `routing_index_built` lines.
- [ ] The same run with a `REPOS.md` of 6 committed edges stops at `shrink-guard` in unattended mode; the gate file says `REPOS.md keeps 1 of its 6 rows`.

**Review focus pinned by tests:**

- The guard counts the index, not the prose around it: `TestGuardCountsTheWiringRowsNotTheProse`, `TestGuardRefusesAnImpactIndexThatLostEdges`.
- A refusal stops the move for a person, in every mode: `TestAnIndexThatLostEdgesStopsAtTheShrinkGuard`.
- The move ships both indexes and the ledger records them: `TestAPointerMoveShipsBothIndexesAndLogsThem`.

**Named test:** `go test ./internal/shrink ./internal/engine -run 'Guard|ShipsBoth|LostEdges'`. **Layer:** `odin`. **Size:** M (280). **Depends on:** v0-T251, v0-T252.

- [ ] **Step 1:** write the tests first.

Change `internal/engine/land_test.go`:

```diff
diff --git a/internal/engine/land_test.go b/internal/engine/land_test.go
index f28a032..970e394 100644
--- a/internal/engine/land_test.go
+++ b/internal/engine/land_test.go
@@ -71,14 +71,14 @@ func TestAPointerNodeMovesTheProjectsPointer(t *testing.T) {
 }
 
 func TestAShrunkGeneratedFileStopsAtTheShrinkGuard(t *testing.T) {
-	nodes := build + "  - { id: index, kind: exec, run: [sh, -c, \"echo '| one |' > REPOS.md\"], repo: . }\n" +
+	nodes := build + "  - { id: index, kind: exec, run: [sh, -c, \"echo '| one |' > INDEX.md\"], repo: . }\n" +
 		"  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
-		"  - { id: move, kind: pointer, repo: repos/app, generated: [REPOS.md] }\n"
+		"  - { id: move, kind: pointer, repo: repos/app, generated: [INDEX.md] }\n"
 	r := startPack(t, "unattended", "", packChecks, nodes, okScript)
-	if err := os.WriteFile(filepath.Join(r.Project, "REPOS.md"), []byte(strings.Repeat("| row |\n", 10)), 0o644); err != nil {
+	if err := os.WriteFile(filepath.Join(r.Project, "INDEX.md"), []byte(strings.Repeat("| row |\n", 10)), 0o644); err != nil {
 		t.Fatal(err)
 	}
-	for _, args := range [][]string{{"add", "REPOS.md"}, {"commit", "-q", "-m", "REPOS.md"}} {
+	for _, args := range [][]string{{"add", "INDEX.md"}, {"commit", "-q", "-m", "INDEX.md"}} {
 		if _, err := git.Run(bg, r.Project, args...); err != nil {
 			t.Fatal(err)
 		}
@@ -99,8 +99,8 @@ func TestAShrunkGeneratedFileStopsAtTheShrinkGuard(t *testing.T) {
 	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
 		t.Fatalf("Advance() after approval = %+v, %v", out, err)
 	}
-	if files, _ := git.Run(bg, r.Project, "show", "--name-only", "--format=", "HEAD"); files != "REPOS.md\nrepos/app" {
-		t.Errorf("the approved move commits %q, want the shrunk REPOS.md with the pointer", files)
+	if files, _ := git.Run(bg, r.Project, "show", "--name-only", "--format=", "HEAD"); files != "INDEX.md\nrepos/app" {
+		t.Errorf("the approved move commits %q, want the shrunk INDEX.md with the pointer", files)
 	}
 }
 
```

Change `internal/engine/ledgergaps_test.go`:

```diff
diff --git a/internal/engine/ledgergaps_test.go b/internal/engine/ledgergaps_test.go
index 82a2b81..93752e0 100644
--- a/internal/engine/ledgergaps_test.go
+++ b/internal/engine/ledgergaps_test.go
@@ -12,25 +12,25 @@ import (
 	"github.com/ouroboric-dev/odin/internal/run"
 )
 
-// shrunkRun starts a run whose pointer move meets a REPOS.md that kept 1 of its 10 rows; the move's
+// shrunkRun starts a run whose pointer move meets a INDEX.md that kept 1 of its 10 rows; the move's
 // acceptance check passes while ok.flag is in the project.
 func shrunkRun(t *testing.T) *run.Run {
 	t.Helper()
 	nodes := build + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
-		"  - { id: move, kind: pointer, repo: repos/app, acceptance: [flag], generated: [REPOS.md] }\n"
+		"  - { id: move, kind: pointer, repo: repos/app, acceptance: [flag], generated: [INDEX.md] }\n"
 	r := startPack(t, "unattended", "", packChecks+"  flag: [test, -f, ok.flag]\n", nodes, okScript)
 	if err := os.WriteFile(filepath.Join(r.Project, "ok.flag"), nil, 0o644); err != nil {
 		t.Fatal(err)
 	}
-	if err := os.WriteFile(filepath.Join(r.Project, "REPOS.md"), []byte(strings.Repeat("| row |\n", 10)), 0o644); err != nil {
+	if err := os.WriteFile(filepath.Join(r.Project, "INDEX.md"), []byte(strings.Repeat("| row |\n", 10)), 0o644); err != nil {
 		t.Fatal(err)
 	}
-	for _, args := range [][]string{{"add", "REPOS.md"}, {"commit", "-q", "-m", "REPOS.md"}} {
+	for _, args := range [][]string{{"add", "INDEX.md"}, {"commit", "-q", "-m", "INDEX.md"}} {
 		if _, err := git.Run(bg, r.Project, args...); err != nil {
 			t.Fatal(err)
 		}
 	}
-	if err := os.WriteFile(filepath.Join(r.Project, "REPOS.md"), []byte("| one |\n"), 0o644); err != nil {
+	if err := os.WriteFile(filepath.Join(r.Project, "INDEX.md"), []byte("| one |\n"), 0o644); err != nil {
 		t.Fatal(err)
 	}
 	return r
```

Create `internal/engine/routing_test.go`:

```go
package engine

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/routing"
	"github.com/ouroboric-dev/odin/internal/run"
)

// goModScript makes the leaf require a package, so the wiring has an edge to build.
const goModScript = `steps:
  a:
    - actions:
        - write: { path: out.txt, content: "done\n" }
        - write: { path: go.mod, content: "module example.test/app\n\ngo 1.26\n\nrequire github.com/go-chi/chi/v5 v5.2.3\n" }
      result: { status: ok, summary: wrote out.txt, usage: { in: 100, out: 10, cache: 5, turns: 2, cost_usd: 0.5 } }
`

const shipNodes = build + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
	"  - { id: move, kind: pointer, repo: repos/app, generated: [REPOS.md, .ygg/impact.json] }\n"

func TestAPointerMoveShipsBothIndexesAndLogsThem(t *testing.T) {
	r := startPack(t, "key-points", "", packChecks, shipNodes, goModScript)
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if files, _ := git.Run(bg, r.Project, "show", "--name-only", "--format=", "HEAD"); files != ".ygg/impact.json\nREPOS.md\nrepos/app" {
		t.Errorf("the move commits %q, want both indexes with the pointer", files)
	}
	repos, _ := git.Run(bg, r.Project, "show", "HEAD:REPOS.md")
	if !strings.Contains(repos, "| repos/app | requires | go:github.com/go-chi/chi/v5 | extracted | repos/app/go.mod |") {
		t.Errorf("REPOS.md lacks the edge:\n%s", repos)
	}
	text := ledgerText(t, r)
	for _, want := range []string{`"event":"routing_index_built"`, `"ygg.routing.kind":"wiring","ygg.routing.edges":1,"ygg.routing.extracted":1`,
		`"ygg.routing.kind":"impact"`} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s", want)
		}
	}
}

// Review focus: an index that lost more than half of its edges against the last shipped one stops the
// move at the hard approval point shrink-guard, in every mode.
func TestAnIndexThatLostEdgesStopsAtTheShrinkGuard(t *testing.T) {
	r := startPack(t, "unattended", "", packChecks, shipNodes, goModScript)
	var es []routing.Edge
	for _, to := range []string{"a", "b", "c", "d", "e", "f"} {
		es = append(es, routing.Edge{From: "repos/app", To: "go:" + to, Kind: "requires", Tag: routing.Extracted, Source: "repos/app/go.mod"})
	}
	if err := routing.WriteWiring(r.Project, es); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"add", "REPOS.md"}, {"commit", "-q", "-m", "an index of six edges"}} {
		if _, err := git.Run(bg, r.Project, args...); err != nil {
			t.Fatal(err)
		}
	}
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateShrinkGuard {
		t.Fatalf("Advance() = %+v, %v (pending %s); want a stop at shrink-guard", out, err, r.State.PendingGate)
	}
	if b, _ := os.ReadFile(filepath.Join(r.Dir, "gates", "move-1.md")); !strings.Contains(string(b), "REPOS.md keeps 1 of its 6 rows") {
		t.Errorf("gate file = %q", b)
	}
	if got, _ := git.Run(bg, r.Project, "rev-parse", "HEAD:repos/app"); got == "" {
		t.Error("no pointer")
	}
}
```

Change `internal/shrink/shrink_test.go`:

```diff
diff --git a/internal/shrink/shrink_test.go b/internal/shrink/shrink_test.go
index 23a6f60..3d25e91 100644
--- a/internal/shrink/shrink_test.go
+++ b/internal/shrink/shrink_test.go
@@ -1,7 +1,10 @@
 package shrink
 
 import (
+	"fmt"
+
 	"errors"
+	"github.com/ouroboric-dev/odin/internal/routing"
 	"strings"
 	"testing"
 )
@@ -35,3 +38,71 @@ func TestShrinkGuard(t *testing.T) {
 		t.Errorf("the refusal doesn't say what shrank: %v", err)
 	}
 }
+
+// block makes a REPOS.md with a wiring block of n edges and some text a person wrote around it.
+func block(n int, prose int) []byte {
+	var es []routing.Edge
+	for i := range n {
+		es = append(es, routing.Edge{From: fmt.Sprintf("leaf%03d", i), To: "api", Kind: "consumes", Tag: routing.Extracted, Source: "umbrella.yaml"})
+	}
+	return append([]byte(strings.Repeat("What a repo is for.\n", prose)+"\n"), routing.Block(es)...)
+}
+
+// Review focus: the guard counts the index's edges, so a person's text around the block can't hide a loss.
+func TestGuardCountsTheWiringRowsNotTheProse(t *testing.T) {
+	prev := block(10, 40)
+	if err := Check("REPOS.md", prev, block(2, 40)); err != nil {
+		t.Fatalf("Check() counts lines, so it should miss this loss: %v", err)
+	}
+	var se *Error
+	if err := Guard("REPOS.md", prev, block(2, 40)); !errors.As(err, &se) || se.Old != 10 || se.New != 2 {
+		t.Errorf("Guard() = %v; want a refusal that keeps 2 of 10 edges", err)
+	}
+	for name, next := range map[string][]byte{
+		"exactly half": block(5, 40), "growth": block(30, 1), "a first block": block(3, 0),
+	} {
+		old := prev
+		if name == "a first block" {
+			old = []byte("# Repos\n")
+		}
+		if err := Guard("REPOS.md", old, next); err != nil {
+			t.Errorf("%s: Guard() = %v", name, err)
+		}
+	}
+	if err := Guard("REPOS.md", prev, []byte(strings.Repeat("prose\n", 50))); err == nil {
+		t.Error("a REPOS.md that lost its block is not refused")
+	}
+}
+
+func impactJSON(t *testing.T, edges int) []byte {
+	t.Helper()
+	b, err := (&routing.Impact{Schema: routing.ImpactSchema, Bound: "lower", Edges: edges, Extracted: edges,
+		Reach: map[string]routing.Reached{"api": {}}}).JSON()
+	if err != nil {
+		t.Fatal(err)
+	}
+	return b
+}
+
+func TestGuardRefusesAnImpactIndexThatLostEdges(t *testing.T) {
+	prev := impactJSON(t, 20)
+	var se *Error
+	if err := Guard(routing.ImpactFile, prev, impactJSON(t, 3)); !errors.As(err, &se) || se.Path != routing.ImpactFile {
+		t.Errorf("Guard() = %v; want a refusal", err)
+	}
+	if err := Guard(routing.ImpactFile, prev, []byte("{not json")); err == nil {
+		t.Error("an index that can't be read is not refused")
+	}
+	if err := Guard(routing.ImpactFile, prev, impactJSON(t, 10)); err != nil {
+		t.Errorf("half is fine: %v", err)
+	}
+	if err := Guard(routing.ImpactFile, nil, impactJSON(t, 1)); err != nil {
+		t.Errorf("a first index is fine: %v", err)
+	}
+	if err := Guard(routing.ImpactFile, []byte("{damaged"), impactJSON(t, 1)); err != nil {
+		t.Errorf("a damaged old index leaves nothing to compare: %v", err)
+	}
+	if err := Guard("other.md", rows(10), rows(4)); err == nil {
+		t.Error("other files keep the row rule")
+	}
+}
```

Expected output (the shrink package does not build; the engine run is a real failure, since nothing writes the files):

```text
# github.com/ouroboric-dev/odin/internal/shrink [github.com/ouroboric-dev/odin/internal/shrink.test]
internal/shrink/shrink_test.go:58:12: undefined: Guard
internal/shrink/shrink_test.go:68:13: undefined: Guard
internal/shrink/shrink_test.go:72:12: undefined: Guard
internal/shrink/shrink_test.go:90:12: undefined: Guard
FAIL	github.com/ouroboric-dev/odin/internal/shrink [build failed]
...
--- FAIL: TestAPointerMoveShipsBothIndexesAndLogsThem (0.42s)
    routing_test.go:30: Advance() = {Status: Gate: Err:<nil> Warn:[]}, git add -- REPOS.md .ygg/impact.json (in /tmp/TestAPointerMoveShipsBothIndexesAndLogsThem965987771/008/l0): exit status 128: fatal: pathspec 'REPOS.md' did not match any files
--- FAIL: TestAnIndexThatLostEdgesStopsAtTheShrinkGuard (0.36s)
```

- [ ] **Step 2:** write the guard, the counters and the engine hook. The 5b tests that used `REPOS.md` as a plain generated file move to `INDEX.md`: the diff for them is in the test patches above.

Change `internal/engine/land.go`:

```diff
diff --git a/internal/engine/land.go b/internal/engine/land.go
index 0404d0d..bfdc8d5 100644
--- a/internal/engine/land.go
+++ b/internal/engine/land.go
@@ -101,6 +101,9 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 	if err != nil {
 		return err
 	}
+	if err := shipRouting(r, n, attempt, parent); err != nil {
+		return err
+	}
 	s := r.State
 	began := time.Now()
 	res, moveErr := pointer.Move(ctx, pointer.Spec{Parent: parent, Child: child, Leaf: l, To: to,
```

Create `internal/engine/routing.go`:

```go
package engine

import (
	"fmt"
	"slices"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/routing"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/tree"
)

// shipRouting builds the routing indexes that pointer node n lists in generated, in the project umbrella
// that is the leaf's parent (spec §8): REPOS.md gets its wiring block, and .ygg/impact.json is written.
// Both are deterministic and call no model. The shrink guard then compares each with the version at HEAD
// when the pointer moves (pointer.Move), and the ledger records each index built. An umbrella that is
// not the project root ships nothing: the indexes are the project's.
func shipRouting(r *run.Run, n schema.Node, attempt int, parent tree.Node) error {
	wiring := slices.Contains(n.Generated, routing.ReposFile)
	impact := slices.Contains(n.Generated, routing.ImpactFile)
	if (!wiring && !impact) || parent.Dir != r.Project {
		return nil
	}
	packs := map[string]*schema.Pack{}
	for name, rl := range r.Setup.Realms.Realms {
		packs[name] = rl.Pack
	}
	res, err := routing.Wiring(parent.Dir, packs)
	if err != nil {
		return &nodeFailure{fmt.Errorf("routing: %w", err)}
	}
	note := ""
	if len(res.Skipped) > 0 {
		note = fmt.Sprintf("left out: %d (first: %s)", len(res.Skipped), res.Skipped[0])
	}
	x, i := routing.Counts(res.Edges)
	built := func(kind string) error {
		return r.Log(gungnir.Event{Name: gungnir.EventRoutingIndexBuilt, Node: n.ID, Attempt: attempt, Task: n.Task,
			IndexKind: kind, Edges: len(res.Edges), Extracted: x, Inferred: i, Note: note})
	}
	if wiring {
		if err := routing.WriteWiring(parent.Dir, res.Edges); err != nil {
			return &nodeFailure{err}
		}
		if err := built("wiring"); err != nil {
			return err
		}
	}
	if impact {
		if err := routing.WriteImpact(parent.Dir, routing.ImpactOf(res)); err != nil {
			return &nodeFailure{err}
		}
		if err := built("impact"); err != nil {
			return err
		}
	}
	return nil
}
```

Change `internal/pointer/pointer.go`:

```diff
diff --git a/internal/pointer/pointer.go b/internal/pointer/pointer.go
index f6357a5..b238cea 100644
--- a/internal/pointer/pointer.go
+++ b/internal/pointer/pointer.go
@@ -90,7 +90,7 @@ func Move(ctx context.Context, s Spec) (Result, error) {
 			if err != nil && !errors.Is(err, os.ErrNotExist) {
 				return res, err
 			}
-			if err := shrink.Check(f, []byte(prev), next); err != nil {
+			if err := shrink.Guard(f, []byte(prev), next); err != nil {
 				return res, err
 			}
 		}
```

Change `internal/routing/block.go`:

```diff
diff --git a/internal/routing/block.go b/internal/routing/block.go
index 485aa6b..49dbcca 100644
--- a/internal/routing/block.go
+++ b/internal/routing/block.go
@@ -71,3 +71,23 @@ func WriteWiring(dir string, edges []Edge) error {
 	}
 	return os.WriteFile(p, out, 0o644)
 }
+
+// WiringRows counts the edges in the wiring block of doc: the table rows between the markers. found is
+// false when doc has no block.
+func WiringRows(doc []byte) (rows int, found bool) {
+	i := bytes.Index(doc, []byte(BeginMarker))
+	j := bytes.Index(doc, []byte(EndMarker))
+	if i < 0 || j < i {
+		return 0, false
+	}
+	inTable := false
+	for _, line := range strings.Split(string(doc[i:j]), "\n") {
+		switch {
+		case strings.HasPrefix(line, "|---"):
+			inTable = true
+		case inTable && strings.HasPrefix(line, "| "):
+			rows++
+		}
+	}
+	return rows, true
+}
```

Change `internal/routing/impact.go`:

```diff
diff --git a/internal/routing/impact.go b/internal/routing/impact.go
index d880e9e..dfa7270 100644
--- a/internal/routing/impact.go
+++ b/internal/routing/impact.go
@@ -188,3 +188,13 @@ func ParseImpact(b []byte) (*Impact, error) {
 	}
 	return &i, nil
 }
+
+// ImpactRows counts what an impact index holds: its edges, its contracts and its reach entries. ok is
+// false when b is not an impact index.
+func ImpactRows(b []byte) (rows int, ok bool) {
+	i, err := ParseImpact(b)
+	if err != nil {
+		return 0, false
+	}
+	return i.Edges + len(i.Contracts) + len(i.Reach), true
+}
```

Change `internal/shrink/shrink.go`:

```diff
diff --git a/internal/shrink/shrink.go b/internal/shrink/shrink.go
index 1a9f853..35a5ba1 100644
--- a/internal/shrink/shrink.go
+++ b/internal/shrink/shrink.go
@@ -7,6 +7,9 @@ package shrink
 import (
 	"bytes"
 	"fmt"
+	"path"
+
+	"github.com/ouroboric-dev/odin/internal/routing"
 )
 
 // Error is a refused generated file. It stops the pointer move at the hard approval point
@@ -20,6 +23,34 @@ func (e *Error) Error() string {
 	return fmt.Sprintf("shrink guard: %s keeps %d of its %d rows, under half; a person decides whether the move goes ahead", e.Path, e.New, e.Old)
 }
 
+// Guard is Check for the generated files Odin knows: the wiring block of REPOS.md counts its edges, so the
+// text a person wrote around it can't hide a loss, and .ygg/impact.json counts its edges, contracts and
+// reach entries. A next version that has no block, or can't be read as an index, has no rows. Any other
+// file counts its lines, as Check does. A previous version that can't be counted leaves nothing to
+// compare with, so the next one passes.
+func Guard(file string, prev, next []byte) error {
+	var o, n int
+	var ok bool
+	switch {
+	case path.Base(file) == routing.ReposFile:
+		if o, ok = routing.WiringRows(prev); !ok {
+			return Check(file, prev, next)
+		}
+		n, _ = routing.WiringRows(next)
+	case file == routing.ImpactFile:
+		if o, ok = routing.ImpactRows(prev); !ok {
+			return nil
+		}
+		n, _ = routing.ImpactRows(next)
+	default:
+		return Check(file, prev, next)
+	}
+	if 2*n < o {
+		return &Error{Path: file, Old: o, New: n}
+	}
+	return nil
+}
+
 // Rows counts a file's rows: its lines that aren't blank.
 func Rows(b []byte) int {
 	n := 0
```

- [ ] **Step 3:** run the checks, then commit.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/odin
gofmt -l .
go vet ./...
go test -race -v -run 'Guard|ShipsBoth|LostEdges' ./internal/shrink ./internal/engine
go test -race ./internal/engine ./internal/pointer
```

Expected output:

```text
--- PASS: TestShrinkGuard (0.00s)
--- PASS: TestGuardCountsTheWiringRowsNotTheProse (0.00s)
--- PASS: TestGuardRefusesAnImpactIndexThatLostEdges (0.00s)
ok  	github.com/ouroboric-dev/odin/internal/shrink	1.024s
--- PASS: TestAPointerMoveShipsBothIndexesAndLogsThem (0.75s)
--- PASS: TestAnIndexThatLostEdgesStopsAtTheShrinkGuard (0.55s)
ok  	github.com/ouroboric-dev/odin/internal/engine	2.372s
```

Commit in `odin`: `The shrink guard counts the edges of REPOS.md and the impact index; a pointer move builds both indexes and logs routing_index_built (v0-T253)`.

**Evidence:** red and green runs above, with `-race`. The engine tests run a real fake-sandbox run over a real git project made by `treetest`: the leaf is committed, merged, and the umbrella commit holds the two generated files. The refusal test commits a 6 edge `REPOS.md` first and reads the gate file the engine wrote. The full `internal/engine` suite (about 100 seconds) passed with the change.

### Task v0-T254: the `pointer-contract` gate: extracted evidence or oasdiff only; a guess alone escalates

Spec §3.4 and §8.2. The gate sits before a pointer node and judges the move that node makes. Two commits: part 1 judges a list of
changes (`0549cb7`), part 2 puts the judgement into the gate node (`5e76894`).

**Files (in `odin`):**

- Create: `internal/routing/contract.go`, `internal/routing/contract_test.go`, `internal/engine/contract.go`, `internal/engine/contract_test.go`
- Modify: `internal/gate/decide.go`, `internal/gate/decide_test.go`, `internal/engine/gates.go`, `internal/engine/engine.go`

**Interfaces:**

- Consumes: `routing.Impact` (v0-T252), `gungnir.EventPointerContractChecked` with `Move`, `Evidence`, `Verdict` (v0-T245), `leaf.Git`.
- Produces: `routing.Judge(ctx, imp, changes, differ) Judgement{Verdict, Evidence, Reason, Contracts}`. `Change{Path, Old, New}`: the path is from the project root; `Old` is nil for a file the move adds, `New` for one it deletes. Only a file whose name ends in `openapi.yaml` or `openapi.yml` can be a contract change. Per contract file:
  - oasdiff ran and finds no change: `pass`, evidence `oasdiff` (only the layout moved);
  - the index lists the file and an extracted edge reaches readers: `fail`, evidence `extracted`, or `oasdiff` if oasdiff confirmed the change;
  - the index lists the file and only inferred edges reach readers: `escalate`, evidence `inferred`;
  - the index lists the file and nothing reaches it: `pass` (the index is a lower bound; the umbrella's acceptance tests still run);
  - the index does not list the file: `fail`, evidence `oasdiff`, if oasdiff sees a change; otherwise `escalate`, evidence `inferred` (a name is only a guess).
  Several files: the worst verdict wins (`escalate` over `fail` over `pass`).
- Produces: `routing.Differ` (`Diff(ctx, old, new) (Delta{Changed, Breaking}, error)`), `routing.OasdiffCLI{Bin}` (writes the two versions to a new private folder, runs the binary with no environment but `PATH`, one minute limit, output capped at 1 MiB), `routing.HostOasdiff()`. An oasdiff that fails leaves the decision to the index.
- Produces: `gate.Facts{NoContractChange, Escalate}`. `Decide` for `pointer-contract`: `Escalate` stops in every mode. `NoContractChange` (or `ContractInSpec`) gives `Auto`, except in step-by-step mode, which stops at every gate. Otherwise unattended mode gives `Block` and the others `Stop`, as in 5b. The zero `Facts` keep the 5b table.
- The gate node: `reachGate(ctx, r, n)` calls `contractFacts` when `n.Gate` is `pointer-contract`. It finds the next pointer node of the same task, takes the commit the umbrella points at (`HEAD:<leaf>`) and the leaf's `main`, lists the changed files with `git diff --name-only` in the leaf's own git (`leaf.Git`, never the leaf's `.git` file), reads the old and the new content with `git show`, and reads the impact index shipped at `HEAD` of the umbrella. A move of more than 64 contract files escalates. It logs `pointer_contract_checked` and writes a `## Contract evidence` section into the gate file.

**Acceptance criteria:**

- [ ] Every row of `TestJudgeByTheEvidenceOfTheIndex` holds (11 rows: the cases above).
- [ ] An inferred-only edge never gives `pass`, with oasdiff absent, failing, or the index empty.
- [ ] `OasdiffCLI` returns `{}` for equal files, `Changed` for different files and `Breaking` when `breaking` exits 1, against a stand-in program; a missing binary is an error.
- [ ] The table of `gate.Decide` for `pointer-contract` with the new facts is as listed.
- [ ] A run whose leaf changes no contract passes the gate by itself, even in unattended mode, with a `pointer_contract_checked` line (`extracted`, `pass`) and `gate_auto_passed`.
- [ ] A run whose leaf changes a contract that an extracted edge reaches stops at the gate in key-points and unattended modes. The pointer has not moved. The gate file names the contract. After `Approve` the run finishes and the pointer moves.
- [ ] A contract that only a guess reaches stops in both modes, with `inferred` and `escalate` in the ledger.

**Review focus pinned by tests:**

- A guess never passes: `TestAnInferredOnlyEdgeNeverGivesPass`, `TestAContractOnlyAGuessReachesEscalatesInEveryMode`, and the `Escalate` rows of `TestPointerContractFollowsTheJudgement`.
- The 5b table still holds: `TestModeTimesApprovalPointTable` (unchanged).
- The gate reads Odin's own git on the leaf and the index Odin shipped, not files in the leaf's working copy: `contractJudgement` uses `leaf.Git` and `git show HEAD:.ygg/impact.json`.

**Named test:** `go test ./internal/routing ./internal/gate ./internal/engine -run 'Judge|Inferred|Oasdiff|PointerContract|AMoveThat|AContractOnly'`. **Layer:** `odin`. **Size:** M and M (295, 293). **Depends on:** v0-T252, v0-T253.

#### Part 1: the judgement (`0549cb7`)

- [ ] **Step 1:** write the tests first.

Create `internal/routing/contract_test.go`:

```go
package routing

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"
)

type fakeDiff struct {
	delta Delta
	err   error
	calls int
}

func (f *fakeDiff) Diff(context.Context, []byte, []byte) (Delta, error) {
	f.calls++
	return f.delta, f.err
}

// An index with three contracts: one an extracted leaf reads, one only a guess reads, one nobody reads.
func contractIndex() *Impact {
	return &Impact{Schema: ImpactSchema, Bound: "lower", Contracts: []ContractEntry{
		{ID: "contract:api/a.openapi.yaml", Path: "api/a.openapi.yaml", Owner: "api", Readers: Reached{Extracted: []string{"web"}}},
		{ID: "contract:api/b.openapi.yaml", Path: "api/b.openapi.yaml", Owner: "api", Readers: Reached{Inferred: []string{"worker"}}},
		{ID: "contract:api/c.openapi.yaml", Path: "api/c.openapi.yaml", Owner: "api"},
	}}
}

func change(p string) Change { return Change{Path: p, Old: []byte("old"), New: []byte("new")} }

func TestJudgeByTheEvidenceOfTheIndex(t *testing.T) {
	cases := []struct {
		name     string
		changes  []Change
		differ   Differ
		verdict  Verdict
		evidence Evidence
	}{
		{"no contract file changed", []Change{change("api/main.go"), change("web/src/app.ts")}, nil, Pass, Extracted},
		{"a contract an extracted edge reaches", []Change{change("api/a.openapi.yaml")}, nil, Fail, Extracted},
		{"a contract only a guess reaches", []Change{change("api/b.openapi.yaml")}, nil, Escalate, Inferred},
		{"a contract nobody reads", []Change{change("api/c.openapi.yaml")}, nil, Pass, Extracted},
		{"a contract file the index does not list", []Change{change("api/new.openapi.yaml")}, nil, Escalate, Inferred},
		{"the worst verdict wins", []Change{change("api/a.openapi.yaml"), change("api/b.openapi.yaml")}, nil, Escalate, Inferred},
		{"oasdiff finds a change", []Change{change("api/a.openapi.yaml")}, &fakeDiff{delta: Delta{Changed: true, Breaking: true}}, Fail, Oasdiff},
		{"oasdiff finds no change: only the layout moved", []Change{change("api/a.openapi.yaml")}, &fakeDiff{}, Pass, Oasdiff},
		{"oasdiff proves a change in a file the index does not list", []Change{change("api/new.openapi.yaml")}, &fakeDiff{delta: Delta{Changed: true}}, Fail, Oasdiff},
		{"oasdiff fails: the index decides", []Change{change("api/a.openapi.yaml")}, &fakeDiff{err: errors.New("boom")}, Fail, Extracted},
		{"oasdiff fails on an unlisted file: a guess", []Change{change("api/new.openapi.yaml")}, &fakeDiff{err: errors.New("boom")}, Escalate, Inferred},
	}
	for _, c := range cases {
		j := Judge(context.Background(), contractIndex(), c.changes, c.differ)
		if j.Verdict != c.verdict || j.Evidence != c.evidence || j.Reason == "" {
			t.Errorf("%s: %+v; want %s on %s evidence", c.name, j, c.verdict, c.evidence)
		}
	}
}

// Review focus: an inferred edge never gives pass. A change that only a guess can see goes to a person.
func TestAnInferredOnlyEdgeNeverGivesPass(t *testing.T) {
	imp := contractIndex()
	for _, d := range []Differ{nil, &fakeDiff{err: errors.New("no oasdiff")}} {
		if j := Judge(context.Background(), imp, []Change{change("api/b.openapi.yaml")}, d); j.Verdict != Escalate {
			t.Errorf("verdict %s on inferred-only evidence, want escalate", j.Verdict)
		}
	}
	// Even when the guess is the only link of a new copy.
	if j := Judge(context.Background(), &Impact{}, []Change{{Path: "web/x.openapi.yaml", New: []byte("n")}}, nil); j.Verdict == Pass {
		t.Error("a contract the index never heard of passed")
	}
}

func TestOasdiffCLIAsksChangelogAndBreaking(t *testing.T) {
	bin := filepath.Join(t.TempDir(), "oasdiff")
	// oasdiff reads two files an agent's leaf wrote; it gets PATH and nothing else of Odin's environment.
	t.Setenv("YGG_TEST_SECRET", "must not reach oasdiff")
	script := `#!/bin/sh
[ -z "${YGG_TEST_SECRET:-}" ] || { echo "the environment leaked" >&2; exit 9; }
# a stand-in: "changelog" prints a line when the files differ; "breaking" exits 1 when the new file says BREAKING
cmd=$1; shift
for last; do :; done
case $cmd in
changelog) cmp -s "$1" "$2" || echo "changed";;
breaking) grep -q BREAKING "$last" && exit 1; exit 0;;
esac
`
	if err := os.WriteFile(bin, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	d := OasdiffCLI{Bin: bin}
	for _, c := range []struct {
		old, new string
		want     Delta
	}{
		{"a", "a", Delta{}},
		{"a", "b", Delta{Changed: true}},
		{"a", "BREAKING", Delta{Changed: true, Breaking: true}},
	} {
		got, err := d.Diff(context.Background(), []byte(c.old), []byte(c.new))
		if err != nil || got != c.want {
			t.Errorf("Diff(%q, %q) = %+v, %v; want %+v", c.old, c.new, got, err, c.want)
		}
	}
	if _, err := (OasdiffCLI{Bin: filepath.Join(t.TempDir(), "missing")}).Diff(context.Background(), nil, nil); err == nil {
		t.Error("a missing binary is not an error")
	}
}
```

Expected output:

```text
# github.com/ouroboric-dev/odin/internal/routing [github.com/ouroboric-dev/odin/internal/routing.test]
internal/routing/contract_test.go:12:8: undefined: Delta
internal/routing/contract_test.go:17:59: undefined: Delta
internal/routing/contract_test.go:28:23: undefined: Change
FAIL	github.com/ouroboric-dev/odin/internal/routing [build failed]
```

- [ ] **Step 2:** write the judge and the oasdiff runner.

Create `internal/routing/contract.go`:

```go
package routing

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"time"
)

// Verdict is what the pointer-contract gate finds (the ledger's pointer_contract_checked).
//   - Pass: the move changes no contract that a leaf reads. The gate opens by itself.
//   - Fail: the move changes a contract, and an extracted edge or oasdiff shows it. The approval point
//     applies: a person decides (spec §3.4).
//   - Escalate: the only evidence is a guess. A person decides in every mode.
type Verdict string

// Evidence is how the verdict was reached.
type Evidence string

const (
	Pass     Verdict = "pass"
	Fail     Verdict = "fail"
	Escalate Verdict = "escalate"

	Oasdiff Evidence = "oasdiff"
)

// Change is a file a pointer move changes. Path is from the project root. Old is nil for a file the move
// adds, New is nil for a file it deletes.
type Change struct {
	Path     string
	Old, New []byte
}

// Delta is what oasdiff finds between two versions of a contract.
type Delta struct{ Changed, Breaking bool }

// Differ compares two versions of a contract (oasdiff).
type Differ interface {
	Diff(ctx context.Context, old, new []byte) (Delta, error)
}

// Judgement is the verdict, the evidence behind it, and why.
type Judgement struct {
	Verdict   Verdict
	Evidence  Evidence
	Reason    string
	Contracts []string // the contract files whose change the verdict is about
}

// IsContractName reports whether a file's name says it holds an OpenAPI contract.
func IsContractName(path string) bool { return isContractName(path) }

var rank = map[Verdict]int{Pass: 0, Fail: 1, Escalate: 2}

// Judge decides whether a pointer move that makes changes is a pointer-contract move (spec §3.4, §8.2).
// It goes by extracted edges of the impact index, or by oasdiff, and never by a guess alone: a contract
// that only an inferred edge reaches, or that the index does not list, gives Escalate unless oasdiff
// shows the change. d may be nil when no oasdiff is at hand. Only files that are named like a contract
// matter; every move also runs the umbrella's acceptance tests, which catch the rest (spec §8.2).
func Judge(ctx context.Context, imp *Impact, changes []Change, d Differ) Judgement {
	out := Judgement{Verdict: Pass, Evidence: Extracted, Reason: "no contract file changed"}
	first := true
	for _, c := range changes {
		if !isContractName(c.Path) {
			continue
		}
		j := judgeOne(ctx, imp, c, d)
		if j.Verdict != Pass {
			out.Contracts = append(out.Contracts, c.Path)
		}
		if first || rank[j.Verdict] > rank[out.Verdict] {
			out.Verdict, out.Evidence, out.Reason, first = j.Verdict, j.Evidence, j.Reason, false
		}
	}
	slices.Sort(out.Contracts)
	return out
}

func judgeOne(ctx context.Context, imp *Impact, c Change, d Differ) Judgement {
	var delta *Delta
	if d != nil && c.Old != nil && c.New != nil {
		if dl, err := d.Diff(ctx, c.Old, c.New); err == nil {
			delta = &dl
		}
	}
	if delta != nil && !delta.Changed {
		return Judgement{Pass, Oasdiff, c.Path + ": oasdiff finds no change in the contract", nil}
	}
	entry, known := imp.Contract(c.Path)
	if !known {
		if delta != nil {
			return Judgement{Fail, Oasdiff, fmt.Sprintf("%s: oasdiff finds a change (breaking: %t); the index does not list the file", c.Path, delta.Breaking), nil}
		}
		return Judgement{Escalate, Inferred, c.Path + ": looks like a contract by its name only; the index does not list it", nil}
	}
	ev := Evidence(Extracted)
	if delta != nil {
		ev = Oasdiff
	}
	switch {
	case len(entry.Readers.Extracted) > 0:
		return Judgement{Fail, ev, fmt.Sprintf("%s: changes a contract that %v read by extracted edges", c.Path, entry.Readers.Extracted), nil}
	case len(entry.Readers.Inferred) > 0:
		return Judgement{Escalate, Inferred, fmt.Sprintf("%s: only guesses link %v to this contract", c.Path, entry.Readers.Inferred), nil}
	}
	return Judgement{Pass, ev, c.Path + ": no leaf reads this contract (a lower bound)", nil}
}

// OasdiffCLI runs the oasdiff program: `oasdiff changelog old new` says whether anything changed, and
// `oasdiff breaking --fail-on ERR old new` exits 1 when a change breaks a client. The contracts are
// written to a new folder only Odin can read, and the program gets no environment but PATH.
type OasdiffCLI struct{ Bin string }

// HostOasdiff returns the oasdiff on the host's PATH, or nil when there is none.
func HostOasdiff() Differ {
	if p, err := exec.LookPath("oasdiff"); err == nil {
		return OasdiffCLI{Bin: p}
	}
	return nil
}

// Diff compares old with new.
func (o OasdiffCLI) Diff(ctx context.Context, old, new []byte) (Delta, error) {
	dir, err := os.MkdirTemp("", "ygg-oasdiff-")
	if err != nil {
		return Delta{}, err
	}
	defer os.RemoveAll(dir)
	for name, b := range map[string][]byte{"old.yaml": old, "new.yaml": new} {
		if err := os.WriteFile(filepath.Join(dir, name), b, 0o600); err != nil {
			return Delta{}, err
		}
	}
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	run := func(args ...string) ([]byte, int, error) {
		cmd := exec.CommandContext(ctx, o.Bin, args...)
		cmd.Dir, cmd.Env = dir, []string{"PATH=" + os.Getenv("PATH")}
		var stdout bytes.Buffer
		cmd.Stdout = &limitWriter{w: &stdout, n: 1 << 20}
		err := cmd.Run()
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			return stdout.Bytes(), ee.ExitCode(), nil
		}
		return stdout.Bytes(), 0, err
	}
	out, code, err := run("changelog", "old.yaml", "new.yaml")
	if err != nil || code != 0 {
		return Delta{}, fmt.Errorf("oasdiff changelog: exit %d, %v", code, err)
	}
	d := Delta{Changed: len(bytes.TrimSpace(out)) > 0}
	if !d.Changed {
		return d, nil
	}
	_, code, err = run("breaking", "--fail-on", "ERR", "old.yaml", "new.yaml")
	switch {
	case err != nil:
		return Delta{}, fmt.Errorf("oasdiff breaking: %w", err)
	case code == 1:
		d.Breaking = true
	case code != 0:
		return Delta{}, fmt.Errorf("oasdiff breaking: exit %d", code)
	}
	return d, nil
}

// limitWriter keeps the first n bytes and drops the rest.
type limitWriter struct {
	w io.Writer
	n int
}

func (l *limitWriter) Write(p []byte) (int, error) {
	if len(p) > l.n {
		l.w.Write(p[:l.n])
		l.n = 0
		return len(p), nil
	}
	l.n -= len(p)
	return l.w.Write(p)
}
```

- [ ] **Step 3:** run the tests, then commit.

```bash
go test -race ./internal/routing
```

Expected output: `ok  	github.com/ouroboric-dev/odin/internal/routing`. Commit in `odin`: `pointer-contract part 1: judge a move's contract changes by extracted edges or oasdiff; a guess alone is an escalation (v0-T254)`.

#### Part 2: the gate node (`5e76894`)

- [ ] **Step 4:** write the gate table test and the engine tests first.

Create `internal/engine/contract_test.go`:

```go
package engine

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/routing"
	"github.com/ouroboric-dev/odin/internal/run"
)

const contractNodes = build + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
	"  - { id: contract-gate, kind: gate, gate: pointer-contract }\n" +
	"  - { id: move, kind: pointer, repo: repos/app }\n"

// scriptWriting is a scripted agent that writes out.txt and the given extra files into the leaf.
func scriptWriting(files ...string) string {
	s := "steps:\n  a:\n    - actions:\n        - write: { path: out.txt, content: \"done\\n\" }\n"
	for _, f := range files {
		s += "        - write: { path: " + f + ", content: \"openapi: 3.0.3\\ninfo: { title: T, version: 2.0.0 }\\n\" }\n"
	}
	return s + "      result: { status: ok, summary: wrote files, usage: { in: 1, out: 1, cache: 0, turns: 1, cost_usd: 0.01 } }\n"
}

// shipIndex commits an impact index to the project that lists one contract with the given readers.
func shipIndex(t *testing.T, r *run.Run, readers routing.Reached) {
	t.Helper()
	imp := &routing.Impact{Schema: routing.ImpactSchema, Bound: "lower", Contracts: []routing.ContractEntry{
		{ID: "contract:repos/app/api.openapi.yaml", Path: "repos/app/api.openapi.yaml", Owner: "repos/app", Readers: readers}}}
	if err := routing.WriteImpact(r.Project, imp); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"add", routing.ImpactFile}, {"commit", "-q", "-m", "ship the impact index"}} {
		if _, err := git.Run(bg, r.Project, args...); err != nil {
			t.Fatal(err)
		}
	}
}

func noOasdiff(t *testing.T) {
	old := contractDiffer
	contractDiffer = nil
	t.Cleanup(func() { contractDiffer = old })
}

func TestAMoveThatChangesNoContractPassesTheGate(t *testing.T) {
	noOasdiff(t)
	r := startPack(t, "unattended", "", packChecks, contractNodes, scriptWriting())
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	text := ledgerText(t, r)
	for _, want := range []string{`"event":"pointer_contract_checked"`, `"ygg.pointer.evidence":"extracted","ygg.verdict":"pass"`, `"event":"gate_auto_passed"`, `"event":"pointer_moved"`} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s", want)
		}
	}
}

func TestAMoveThatChangesAContractAnExtractedEdgeReachesStopsAtTheGate(t *testing.T) {
	noOasdiff(t)
	for _, mode := range []string{"key-points", "unattended"} {
		r := startPack(t, mode, "", packChecks, contractNodes, scriptWriting("api.openapi.yaml"))
		shipIndex(t, r, routing.Reached{Extracted: []string{"web"}})
		out, err := Advance(bg, r)
		if err != nil || out.Status != run.StatusStopped || out.Gate != "contract-gate" || r.State.PendingGate != gungnir.GatePointerContract {
			t.Fatalf("%s: Advance() = %+v, %v; want a stop at the pointer-contract gate", mode, out, err)
		}
		if got, _ := git.Run(bg, r.Project, "rev-parse", "HEAD:repos/app"); got == mainOf(t, r) {
			t.Errorf("%s: the pointer moved before the approval", mode)
		}
		b, _ := os.ReadFile(filepath.Join(r.Dir, "gates", "contract-gate-1.md"))
		for _, want := range []string{"## Contract evidence", "repos/app/api.openapi.yaml", "[web] read by extracted edges"} {
			if !strings.Contains(string(b), want) {
				t.Errorf("%s: the gate file lacks %q:\n%s", mode, want, b)
			}
		}
		if text := ledgerText(t, r); !strings.Contains(text, `"ygg.pointer.evidence":"extracted","ygg.verdict":"fail"`) {
			t.Errorf("%s: the ledger doesn't record the failed check", mode)
		}
		if err := Approve(bg, r, "contract-gate", "the contract change is in the spec"); err != nil {
			t.Fatal(err)
		}
		if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
			t.Fatalf("%s: Advance() after approval = %+v, %v", mode, out, err)
		}
		if got, _ := git.Run(bg, r.Project, "rev-parse", "HEAD:repos/app"); got != mainOf(t, r) {
			t.Errorf("%s: the pointer did not move after the approval", mode)
		}
	}
}

// Review focus: a contract that only an inferred edge reaches is never a pass; it goes to a person.
func TestAContractOnlyAGuessReachesEscalatesInEveryMode(t *testing.T) {
	noOasdiff(t)
	for _, mode := range []string{"key-points", "unattended"} {
		r := startPack(t, mode, "", packChecks, contractNodes, scriptWriting("api.openapi.yaml"))
		shipIndex(t, r, routing.Reached{Inferred: []string{"worker"}})
		out, err := Advance(bg, r)
		if err != nil || out.Status != run.StatusStopped || out.Gate != "contract-gate" {
			t.Fatalf("%s: Advance() = %+v, %v; want a stop", mode, out, err)
		}
		if text := ledgerText(t, r); !strings.Contains(text, `"ygg.pointer.evidence":"inferred","ygg.verdict":"escalate"`) {
			t.Errorf("%s: the ledger lacks the escalation", mode)
		}
	}
}

func mainOf(t *testing.T, r *run.Run) string {
	t.Helper()
	l, err := r.Leaf("repos/app")
	if err != nil {
		t.Fatal(err)
	}
	main, err := l.Rev(bg, "main")
	if err != nil {
		t.Fatal(err)
	}
	return main
}
```

Change `internal/gate/decide_test.go`:

```diff
diff --git a/internal/gate/decide_test.go b/internal/gate/decide_test.go
index 3c072d7..def1aed 100644
--- a/internal/gate/decide_test.go
+++ b/internal/gate/decide_test.go
@@ -71,3 +71,31 @@ func TestDecideFactsAndOverrides(t *testing.T) {
 		}
 	}
 }
+
+// Review focus: only a contract change that an extracted edge or oasdiff shows needs a person at
+// pointer-contract; a guess alone always does, in every mode but step-by-step the gate is open when no
+// contract changed.
+func TestPointerContractFollowsTheJudgement(t *testing.T) {
+	g := gungnir.GatePointerContract
+	cases := []struct {
+		name string
+		mode gungnir.Mode
+		f    Facts
+		want Action
+	}{
+		{"no contract change, key-points", gungnir.ModeKeyPoints, Facts{NoContractChange: true}, Auto},
+		{"no contract change, unattended", gungnir.ModeUnattended, Facts{NoContractChange: true}, Auto},
+		{"no contract change, step-by-step", gungnir.ModeStepByStep, Facts{NoContractChange: true}, Stop},
+		{"a contract change, key-points", gungnir.ModeKeyPoints, Facts{}, Stop},
+		{"a contract change, unattended", gungnir.ModeUnattended, Facts{}, Block},
+		{"a contract change the spec holds", gungnir.ModeUnattended, Facts{ContractInSpec: true}, Auto},
+		{"a guess alone, key-points", gungnir.ModeKeyPoints, Facts{Escalate: true}, Stop},
+		{"a guess alone stops even when the spec holds the change", gungnir.ModeUnattended, Facts{Escalate: true, ContractInSpec: true}, Stop},
+		{"a guess alone is not a no-change", gungnir.ModeKeyPoints, Facts{Escalate: true, NoContractChange: true}, Stop},
+	}
+	for _, c := range cases {
+		if got := Decide(c.mode, g, nil, c.f); got != c.want {
+			t.Errorf("%s: Decide() = %s, want %s", c.name, got, c.want)
+		}
+	}
+}
```

Expected output:

```text
# github.com/ouroboric-dev/odin/internal/gate
# [github.com/ouroboric-dev/odin/internal/gate]
vet: internal/gate/decide_test.go:86:67: unknown field NoContractChange in struct literal of type Facts
# github.com/ouroboric-dev/odin/internal/engine
# [github.com/ouroboric-dev/odin/internal/engine]
vet: internal/engine/contract_test.go:44:9: undefined: contractDiffer
```

- [ ] **Step 5:** write the facts, the check and the gate-file section.

Create `internal/engine/contract.go`:

```go
package engine

import (
	"context"
	"fmt"
	"path"
	"path/filepath"
	"strings"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/gate"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/routing"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/tree"
)

// contractDiffer compares two versions of a contract: the oasdiff on the host's PATH, or nil when there is
// none (the realm images bake oasdiff in; a host without it judges by the index alone). Tests replace it.
var contractDiffer = routing.HostOasdiff()

// maxContractChanges bounds the contract files one move is judged on; a move that changes more goes to a
// person without a verdict by file.
const maxContractChanges = 64

// contractJudgement is the pointer-contract gate's check (spec §3.4, §8.2). The gate node judges the move
// of the next pointer node: the changes between the commit the project points at and the leaf's main, in
// the leaf's own git, against the impact index of the last shipped version (HEAD of the project). The
// index is Odin's: a leaf can't write it before the move is committed.
func contractJudgement(ctx context.Context, r *run.Run, gateNode schema.Node) (routing.Judgement, string, error) {
	var p schema.Node
	nodes := r.Nodes()
	for _, m := range nodes[r.State.Position+1:] {
		if m.Kind == schema.KindPointer && m.Task == gateNode.Task {
			p = m
			break
		}
	}
	if p.ID == "" {
		return routing.Judgement{}, "", &nodeFailure{fmt.Errorf("gate %s judges a pointer move, and no pointer node follows it", gateNode.ID)}
	}
	tn, err := tree.Resolve(ctx, r.Setup.Root, filepath.Join(r.Setup.ProjectPath, p.Repo))
	if err != nil {
		return routing.Judgement{}, "", err
	}
	parent, leafNode := tn[len(tn)-2], tn[len(tn)-1]
	child, err := filepath.Rel(parent.Dir, leafNode.Dir)
	if err != nil {
		return routing.Judgement{}, "", err
	}
	l, err := r.Leaf(p.Repo)
	if err != nil {
		return routing.Judgement{}, "", err
	}
	to, err := l.Rev(ctx, "main")
	if err != nil {
		return routing.Judgement{}, "", err
	}
	from, err := git.Run(ctx, parent.Dir, "rev-parse", "HEAD:"+child)
	if err != nil {
		return routing.Judgement{}, "", err
	}
	move := fmt.Sprintf("%s: %.12s -> %.12s", child, from, to)
	if from == to {
		return routing.Judgement{Verdict: routing.Pass, Evidence: routing.Extracted, Reason: "the pointer is already there"}, move, nil
	}
	imp := &routing.Impact{}
	if b, err := git.Run(ctx, parent.Dir, "show", "HEAD:"+routing.ImpactFile); err == nil {
		if imp, err = routing.ParseImpact([]byte(b)); err != nil {
			return routing.Judgement{}, "", &nodeFailure{fmt.Errorf("the shipped %s can't be read: %w", routing.ImpactFile, err)}
		}
	}
	names, err := l.Git(ctx, "diff", "-z", "--name-only", "--no-renames", from, to)
	if err != nil {
		return routing.Judgement{}, "", err
	}
	var changes []routing.Change
	for _, f := range strings.Split(names, "\x00") {
		if f == "" || !routing.IsContractName(f) {
			continue
		}
		if len(changes) == maxContractChanges {
			return routing.Judgement{Verdict: routing.Escalate, Evidence: routing.Inferred,
				Reason: fmt.Sprintf("the move changes more than %d contract files", maxContractChanges)}, move, nil
		}
		c := routing.Change{Path: path.Join(child, f)}
		if old, err := l.Git(ctx, "show", from+":"+f); err == nil {
			c.Old = []byte(old)
		}
		if nw, err := l.Git(ctx, "show", to+":"+f); err == nil {
			c.New = []byte(nw)
		}
		changes = append(changes, c)
	}
	return routing.Judge(ctx, imp, changes, contractDiffer), move, nil
}

// contractFacts runs the check for gate node n, writes pointer_contract_checked, and turns the verdict
// into the facts the gate table reads. The section is for the gate file.
func contractFacts(ctx context.Context, r *run.Run, n schema.Node, attempt int) (gate.Facts, string, error) {
	j, move, err := contractJudgement(ctx, r, n)
	if err != nil {
		return gate.Facts{}, "", err
	}
	ev := gungnir.Event{Name: gungnir.EventPointerContractChecked, Node: n.ID, Attempt: attempt, Task: n.Task,
		Move: move, Evidence: string(j.Evidence), Verdict: string(j.Verdict), Result: j.Reason}
	if err := r.Log(ev); err != nil {
		return gate.Facts{}, "", err
	}
	section := fmt.Sprintf("## Contract evidence\n\n- Move: %s\n- Verdict: %s\n- Evidence: %s\n- Why: %s\n", move, j.Verdict, j.Evidence, j.Reason)
	for _, c := range j.Contracts {
		section += "- Contract: " + c + "\n"
	}
	return gate.Facts{NoContractChange: j.Verdict == routing.Pass, Escalate: j.Verdict == routing.Escalate}, section, nil
}
```

Change `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 2b98a02..f6b3d7a 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -88,7 +88,7 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 		case schema.KindExec:
 			err = runExec(ctx, r, n)
 		case schema.KindGate:
-			stop, err = reachGate(r, n)
+			stop, err = reachGate(ctx, r, n)
 		case schema.KindMerge:
 			err = runMerge(ctx, r, n)
 		case schema.KindPointer:
```

Change `internal/engine/gates.go`:

```diff
diff --git a/internal/engine/gates.go b/internal/engine/gates.go
index 0f014ca..2a0dc97 100644
--- a/internal/engine/gates.go
+++ b/internal/engine/gates.go
@@ -18,7 +18,7 @@ import (
 
 // reachGate decides gate node n (spec §7.2). Both a stop and an auto-pass write a gate file, so
 // unattended decisions can be audited. A stop saves the run as stopped and reports true.
-func reachGate(r *run.Run, n schema.Node) (bool, error) {
+func reachGate(ctx context.Context, r *run.Run, n schema.Node) (bool, error) {
 	s := r.State
 	attempt, err := startAttempt(r, n)
 	if err != nil {
@@ -42,8 +42,17 @@ func reachGate(r *run.Run, n schema.Node) (bool, error) {
 			return false, err
 		}
 	}
+	var evidence string
+	if n.Gate == gungnir.GatePointerContract {
+		// The gate judges the move that the next pointer node makes (spec §3.4): a pass opens it, a fail
+		// is the approval point, and a guess alone is an escalation.
+		var err error
+		if facts, evidence, err = contractFacts(ctx, r, n, attempt); err != nil {
+			return false, err
+		}
+	}
 	action := gate.Decide(s.Mode, n.Gate, r.Setup.Config.Gates, facts)
-	file, err := writeGateFile(r, n, attempt, action, verdict)
+	file, err := writeGateFile(r, n, attempt, action, verdict, evidence)
 	if err != nil {
 		return false, err
 	}
@@ -61,7 +70,7 @@ func reachGate(r *run.Run, n schema.Node) (bool, error) {
 }
 
 // writeGateFile writes gates/<node>-<attempt>.md and returns its path relative to the run.
-func writeGateFile(r *run.Run, n schema.Node, attempt int, action gate.Action, verdict *gungnir.Conformance) (string, error) {
+func writeGateFile(r *run.Run, n schema.Node, attempt int, action gate.Action, verdict *gungnir.Conformance, evidence string) (string, error) {
 	s := r.State
 	rel := filepath.Join("gates", fmt.Sprintf("%s-%d.md", n.ID, attempt))
 	var b strings.Builder
@@ -87,6 +96,9 @@ func writeGateFile(r *run.Run, n schema.Node, attempt int, action gate.Action, v
 	if verdict != nil {
 		b.WriteString("\n" + conformanceSection(*verdict))
 	}
+	if evidence != "" {
+		b.WriteString("\n" + evidence)
+	}
 	u := s.Usage
 	fmt.Fprintf(&b, "\n## Cost so far\n\n- Tokens: %d in, %d out, %d from cache\n- Turns: %d\n- Cost: $%.4f",
 		u.InTok, u.OutTok, u.CacheTok, u.Turns, u.CostUSD)
```

Change `internal/gate/decide.go`:

```diff
diff --git a/internal/gate/decide.go b/internal/gate/decide.go
index 364c379..2b72b0d 100644
--- a/internal/gate/decide.go
+++ b/internal/gate/decide.go
@@ -16,6 +16,12 @@ const (
 type Facts struct {
 	Deviation      bool // spec: the design-conformance review found a deviation
 	ContractInSpec bool // pointer-contract: the approved spec contains the contract change
+
+	// NoContractChange: pointer-contract found no contract change by an extracted edge or oasdiff
+	// (routing.Judge said pass), so the gate opens by itself. Escalate: only a guess found one
+	// (routing.Judge said escalate), so a person decides in every mode. Neither: a contract changed.
+	NoContractChange bool
+	Escalate         bool
 }
 
 // Decide applies the mode × approval-point table of spec §7.1, then the config's overrides.
@@ -43,7 +49,10 @@ func Decide(mode gungnir.Mode, g gungnir.Gate, overrides map[gungnir.Gate]string
 		}
 		return Auto
 	case gungnir.GatePointerContract:
-		if f.ContractInSpec {
+		if f.Escalate {
+			return Stop
+		}
+		if f.NoContractChange || f.ContractInSpec {
 			return Auto
 		}
 		if mode == gungnir.ModeUnattended {
```

- [ ] **Step 6:** run the checks, then commit.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/odin
gofmt -l .
go vet ./...
go test -race -v -run 'Judge|Inferred|Oasdiff|PointerContract|AMoveThat|AContractOnly' ./internal/routing ./internal/gate ./internal/engine
```

Expected output:

```text
--- PASS: TestJudgeByTheEvidenceOfTheIndex (0.00s)
--- PASS: TestAnInferredOnlyEdgeNeverGivesPass (0.00s)
--- PASS: TestOasdiffCLIAsksChangelogAndBreaking (0.01s)
--- PASS: TestEveryEdgeIsTaggedExtractedOrInferred (0.01s)
ok  	github.com/ouroboric-dev/odin/internal/routing	1.044s
--- PASS: TestPointerContractFollowsTheJudgement (0.00s)
ok  	github.com/ouroboric-dev/odin/internal/gate	1.011s
--- PASS: TestAMoveThatChangesNoContractPassesTheGate (0.87s)
--- PASS: TestAMoveThatChangesAContractAnExtractedEdgeReachesStopsAtTheGate (1.47s)
--- PASS: TestAContractOnlyAGuessReachesEscalatesInEveryMode (1.06s)
--- PASS: TestAMoveThatCommittedBeforeTheRunRecordedItIsLoggedOnTheNextAttempt (0.61s)
ok  	github.com/ouroboric-dev/odin/internal/engine	5.080s
```

(`TestEveryEdgeIsTaggedExtractedOrInferred` and `TestAMoveThatCommittedBeforeTheRunRecordedItIsLoggedOnTheNextAttempt` are in the list only because the pattern also matches them.) Commit in `odin`: `pointer-contract part 2: the gate node judges the next pointer move, writes pointer_contract_checked and the evidence into the gate file (v0-T254)`.

**Evidence:** red runs above (the routing package does not build; the gate and engine packages fail vet). Green runs above with `-race`. The engine tests run real runs on a real git project: the scripted agent writes `api.openapi.yaml` into the leaf, the merge lands it, and the gate stops before the move. The ledger lines and the gate file are read back from disk. oasdiff is a stand-in script in the unit test and `nil` in the engine tests (`noOasdiff`), so the real binary is not exercised: decision 7. The full `go test -race ./...` passed in `odin`.

### Task v0-T255: the routing bench: right-first answers decide whether an index ships

Spec §8.3. A bench is a list of questions with known answers over a project. The score is the share of questions the index answers
right first. An index ships only at or above the pack's threshold. The bench runs with no model: each answer is one lookup in the
index. A scripted baseline (a grep over the leaves) gives the figure to beat. Three commits: Gungnir's pack block (`5a03331`), the
bench (`39ae718`), the gate on shipping (`bb841e2`).

**Files (in `gungnir`):**

- Create: `schema/pack_routing_test.go`
- Modify: `schema/pack.go`, `schema/pack.schema.json`

**Files (in `odin`):**

- Create: `internal/routing/bench.go`, `internal/routing/bench_test.go`, `testdata/routing/bench.yaml`
- Modify: `internal/engine/routing.go`, `internal/engine/routing_test.go`

**Interfaces:**

- Produces (Gungnir): `schema.Pack.Routing *PackRouting{Threshold float64; Bench string}`, YAML key `routing`. `threshold` is above 0 and at most 1 and is required when the block is there. `bench` is a path inside the project and defaults to `schema.DefaultBenchPath` (`.ygg/routing-bench.yaml`). `PackRouting.BenchPath()`. A pack with no block has `Routing == nil`.
- Produces: `routing.LoadBench(path)`: one YAML document, no unknown field, schema `ygg.routing-bench/v1`, 1 to 500 questions, unique ids, known kinds, from a regular file (not a link) of at most 1 MiB. A question is `{id, kind, about, arg?, answer[]}`. Kinds: `consumers`, `contract-owner`, `reached-by`, `contract-readers`, `pin` (needs `arg`), `services`.
- Produces: `routing.Answerer`; `routing.IndexAnswerer(res, imp)` (one lookup per question, extracted edges only); `routing.GrepBaseline(dir, leaves)` (a scripted stand-in for an agent without an index: it searches the leaves' text for the name; it can only answer `consumers`, `reached-by`, `contract-owner` and `contract-readers`).
- Produces: `(*Bench).Score(Answerer) Report{Right, Total, Score, Misses}`; `Report.Ships(threshold)` (true when `Total > 0` and `Right` is at or above `threshold * Total`, within 1e-9); an answer is right when it is the known set, no more and no less.
- In a run: when the lead realm's pack has a `routing` block, `shipRouting` loads the bench from the project umbrella, scores the index and the baseline, and refuses to write anything when the bench cannot be read or the score is under the threshold (the node fails with `the routing index does not ship: bench 2/3 right first at threshold 0.80 (grep baseline ...); wrong or unanswered: [...]`). When it ships, the score and the baseline are in the ledger note of `routing_index_built`. A pack without the block ships unmeasured (decision 6).
- The bench lives in the project umbrella. No agent mounts the umbrella, so an agent cannot write the answers it is scored on.

**Acceptance criteria:**

- [ ] The fixture bench has 8 questions. The index answers 8 of 8. The grep baseline answers 2 of 8.
- [ ] An index that lost its `imports` and `needs` edges scores under 8/8 and does not ship at 0.9.
- [ ] `Ships` is right at the edges: 7/8 at 0.875 ships, 7/8 at 0.9 does not, 4/5 at 0.8 ships, 0/0 never ships.
- [ ] A bench with an unknown field, another schema, no question, an unknown kind, a repeated or empty id, a pin with no arg, two documents, or behind a link is refused.
- [ ] A pack with `routing: {threshold: 0.8}` loads; a threshold of 0, over 1, missing, a bench path outside the project, or an unknown key is refused (each error names `routing`).
- [ ] In a run, an index at the threshold ships with the score in the ledger. A wrong answer, or no bench at all, fails the move, writes no `REPOS.md` and leaves the pointer.

**Review focus pinned by tests:**

- An index ships only at or above the threshold: `TestAnIndexShipsOnlyAtOrAboveTheThreshold`, `TestAnIndexUnderTheThresholdDoesNotShip`.
- The bench runs with no model: `TestTheIndexAnswersTheFixtureBenchRightFirst` uses `IndexAnswerer` only.
- The threshold and the list live in the repo: the pack block (`TestAPackSetsTheRoutingBenchThreshold`) and `testdata/routing/bench.yaml`.
- A bench that cannot be read exactly is refused: `TestABenchThatIsNotExactIsRefused`.

**Named test:** `go test ./internal/routing ./internal/engine -run 'Bench|Grep|Threshold|Unmeasured|ShipsOnly'` in `odin`, and `go test ./schema -run Routing` in `gungnir`. **Layer:** `gungnir` and `odin`. **Size:** S, M and S (73, 340, 76). **Depends on:** v0-T252, v0-T253.

#### Part 1: the pack's `routing` block, in `gungnir` (`5a03331`)

- [ ] **Step 1:** in `gungnir`, create the branch and write the tests first.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/gungnir
git switch -c routing/pack main
```

Create `schema/pack_routing_test.go`:

```go
package schema

import (
	"strings"
	"testing"
)

func TestAPackSetsTheRoutingBenchThreshold(t *testing.T) {
	p, err := LoadPack(recipeRealm(t, recipe+"routing:\n  threshold: 0.8\n"))
	if err != nil {
		t.Fatal(err)
	}
	if p.Routing == nil || p.Routing.Threshold != 0.8 || p.Routing.BenchPath() != DefaultBenchPath {
		t.Fatalf("Routing = %+v, want threshold 0.8 and the default bench path", p.Routing)
	}
	p, err = LoadPack(recipeRealm(t, recipe+"routing:\n  threshold: 1\n  bench: docs/bench.yaml\n"))
	if err != nil || p.Routing.BenchPath() != "docs/bench.yaml" || p.Routing.Threshold != 1 {
		t.Fatalf("LoadPack() = %+v, %v", p, err)
	}
	if p, err := LoadPack(recipeRealm(t, recipe)); err != nil || p.Routing != nil {
		t.Errorf("a pack with no routing block has Routing %+v, %v; want nil", p.Routing, err)
	}
}

func TestAPackRefusesABadRoutingBlock(t *testing.T) {
	for name, block := range map[string]string{
		"a threshold of zero":  "routing:\n  threshold: 0\n",
		"a threshold over one": "routing:\n  threshold: 1.5\n",
		"no threshold":         "routing:\n  bench: docs/bench.yaml\n",
		"a bench outside":      "routing:\n  threshold: 0.5\n  bench: ../bench.yaml\n",
		"an absolute bench":    "routing:\n  threshold: 0.5\n  bench: /etc/bench.yaml\n",
		"an unknown field":     "routing:\n  threshold: 0.5\n  model: x\n",
	} {
		_, err := LoadPack(recipeRealm(t, recipe+block))
		if err == nil {
			t.Errorf("%s: LoadPack() = nil, want an error", name)
		} else if !strings.Contains(err.Error(), "routing") {
			t.Errorf("%s: the error does not name the block: %v", name, err)
		}
	}
}
```

Expected output:

```text
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/pack_routing_test.go:13:7: p.Routing undefined (type *Pack has no field or method Routing)
schema/pack_routing_test.go:13:80: undefined: DefaultBenchPath
schema/pack_routing_test.go:14:78: p.Routing undefined (type *Pack has no field or method Routing)
schema/pack_routing_test.go:17:21: p.Routing undefined (type *Pack has no field or method Routing)
FAIL
```

- [ ] **Step 2:** add the field, the default path and the schema.

Change `schema/pack.go`:

```diff
diff --git a/schema/pack.go b/schema/pack.go
index 3ffbde8..14f1cda 100644
--- a/schema/pack.go
+++ b/schema/pack.go
@@ -25,6 +25,26 @@ type Pack struct {
 	// Services are the containers a sandbox of a leaf of this realm starts beside the work container,
 	// and the sandbox of each leaf that consumes it (spec §6.1, §9.2).
 	Services map[string]PackService `yaml:"services"`
+	// Routing sets what a routing index must score on the project's bench before it ships (spec §8.3).
+	// A pack without the block ships its indexes unmeasured.
+	Routing *PackRouting `yaml:"routing"`
+}
+
+// DefaultBenchPath is where a project keeps its routing bench, from the project root.
+const DefaultBenchPath = ".ygg/routing-bench.yaml"
+
+// PackRouting is the routing block of a lead realm's pack: the right-first score an index needs to ship.
+type PackRouting struct {
+	Threshold float64 `yaml:"threshold"` // above 0 and at most 1: the share of the bench's questions the index answers right first
+	Bench     string  `yaml:"bench"`     // the bench file, from the project root; DefaultBenchPath when empty
+}
+
+// BenchPath returns the bench file, from the project root.
+func (r *PackRouting) BenchPath() string {
+	if r.Bench == "" {
+		return DefaultBenchPath
+	}
+	return r.Bench
 }
 
 // PackRecipe is the contract of a build realm: how to make a leaf, what to tell its implementer, and
@@ -140,6 +160,9 @@ func LoadPack(dir string) (*Pack, error) {
 	if err := p.checkRecipe(file, dir); err != nil {
 		return nil, err
 	}
+	if p.Routing != nil && !filepath.IsLocal(p.Routing.BenchPath()) {
+		return nil, fmt.Errorf("%s: routing bench %q must be a path inside the project", file, p.Routing.BenchPath())
+	}
 	if p.Sandbox != nil {
 		for _, st := range []PackStack{{Stack: p.Sandbox.Stack, Build: p.Sandbox.Build, Target: p.Sandbox.Target}, ptrOr(p.Sandbox.Acceptance)} {
 			if st.Build != "" && !filepath.IsLocal(st.Build) {
```

Change `schema/pack.schema.json`:

```diff
diff --git a/schema/pack.schema.json b/schema/pack.schema.json
index 965f521..b8dcc18 100644
--- a/schema/pack.schema.json
+++ b/schema/pack.schema.json
@@ -66,6 +66,15 @@
         "checks": { "type": "array", "minItems": 1, "items": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" } }
       }
     },
+    "routing": {
+      "type": "object",
+      "additionalProperties": false,
+      "required": ["threshold"],
+      "properties": {
+        "threshold": { "type": "number", "exclusiveMinimum": 0, "maximum": 1, "description": "the right-first score a routing index needs on the project's bench to ship" },
+        "bench": { "type": "string", "minLength": 1, "description": "the bench file, from the project root; .ygg/routing-bench.yaml when absent" }
+      }
+    },
     "services": {
       "type": "object",
       "propertyNames": { "pattern": "^[a-z][a-z0-9-]*$" },
```

- [ ] **Step 3:** run the tests, then commit.

```bash
go vet ./... && go test -race ./...
```

Expected output: `ok` for `gungnir` and `gungnir/schema`. Commit in `gungnir`: `A pack can set the routing bench threshold: routing.threshold and routing.bench (v0-T255)`.

#### Part 2: the bench, in `odin` (`39ae718`)

- [ ] **Step 4:** write the bench file and the tests first.

Create `internal/routing/bench_test.go`:

```go
package routing

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const benchFile = "../../testdata/routing/bench.yaml"

func fixtureAnswerers(t *testing.T) (Answerer, Answerer, *Bench) {
	t.Helper()
	b, err := LoadBench(benchFile)
	if err != nil {
		t.Fatal(err)
	}
	res, err := Wiring(fixture, packs())
	if err != nil {
		t.Fatal(err)
	}
	return IndexAnswerer(res, ImpactOf(res)), GrepBaseline(fixture, res.Leaves), b
}

func TestTheIndexAnswersTheFixtureBenchRightFirst(t *testing.T) {
	idx, _, b := fixtureAnswerers(t)
	rep := b.Score(idx)
	if rep.Right != rep.Total || rep.Total != 8 || rep.Score != 1 || len(rep.Misses) != 0 {
		t.Errorf("report = %+v; want all 8 right", rep)
	}
}

// The scripted baseline is what an agent does without an index: it greps the leaves for the name.
func TestTheGrepBaselineScoresLowerThanTheIndex(t *testing.T) {
	_, base, b := fixtureAnswerers(t)
	rep := b.Score(base)
	res, _ := Wiring(fixture, packs())
	t.Logf("index %v, baseline %v, misses %v", b.Score(IndexAnswerer(res, ImpactOf(res))), rep, rep.Misses)
	if rep.Total != 8 || rep.Right >= 5 {
		t.Errorf("baseline = %+v; the fixture is meant to show the index beating it", rep)
	}
	if len(rep.Misses) != rep.Total-rep.Right {
		t.Errorf("misses %v", rep.Misses)
	}
}

// Review focus: an index ships only at or above the pack's threshold; a lossy index does not.
func TestAnIndexShipsOnlyAtOrAboveTheThreshold(t *testing.T) {
	_, _, b := fixtureAnswerers(t)
	res, _ := Wiring(fixture, packs())
	var lossy []Edge
	for _, e := range res.Edges {
		if e.Kind != "imports" && e.Kind != "needs" { // lose two kinds of edge
			lossy = append(lossy, e)
		}
	}
	lres := *res
	lres.Edges = lossy
	rep := b.Score(IndexAnswerer(&lres, ImpactOf(&lres)))
	if rep.Right >= rep.Total {
		t.Fatalf("a lossy index scored %+v", rep)
	}
	for _, c := range []struct {
		right, total int
		threshold    float64
		want         bool
	}{{8, 8, 1, true}, {7, 8, 0.875, true}, {7, 8, 0.9, false}, {4, 5, 0.8, true}, {3, 5, 0.8, false}, {0, 0, 0.5, false}} {
		if got := (Report{Right: c.right, Total: c.total}).Ships(c.threshold); got != c.want {
			t.Errorf("%d/%d at %v: Ships() = %v", c.right, c.total, c.threshold, got)
		}
	}
	if rep.Ships(0.9) {
		t.Errorf("the lossy index %+v ships at 0.9", rep)
	}
}

func TestABenchThatIsNotExactIsRefused(t *testing.T) {
	dir := t.TempDir()
	good := "schema: ygg.routing-bench/v1\nquestions:\n  - { id: q, kind: consumers, about: api, answer: [web] }\n"
	for name, body := range map[string]string{
		"an unknown field":  strings.Replace(good, "answer:", "model: x, answer:", 1),
		"another schema":    strings.Replace(good, "bench/v1", "bench/v2", 1),
		"no question":       "schema: ygg.routing-bench/v1\nquestions: []\n",
		"an unknown kind":   strings.Replace(good, "consumers", "guess", 1),
		"a repeated id":     good + "  - { id: q, kind: consumers, about: api, answer: [] }\n",
		"no id":             strings.Replace(good, "id: q", "id: ''", 1),
		"a pin with no arg": strings.Replace(good, "kind: consumers", "kind: pin", 1),
		"more than one doc": good + "---\nschema: x\n",
	} {
		p := filepath.Join(dir, "bench.yaml")
		os.WriteFile(p, []byte(body), 0o644)
		if _, err := LoadBench(p); err == nil {
			t.Errorf("%s: LoadBench() = nil, want an error", name)
		}
	}
	os.WriteFile(filepath.Join(dir, "good.yaml"), []byte(good), 0o644)
	if _, err := LoadBench(filepath.Join(dir, "good.yaml")); err != nil {
		t.Error(err)
	}
	os.Symlink(filepath.Join(dir, "good.yaml"), filepath.Join(dir, "link.yaml"))
	if _, err := LoadBench(filepath.Join(dir, "link.yaml")); err == nil {
		t.Error("a bench behind a link is read")
	}
}
```

Create `testdata/routing/bench.yaml`:

```yaml
# The routing bench of the fixture project: fixed questions, with the answers a person checked by hand
# against the files under project/. Add a question for every miss the ledger records (spec §8.3).
schema: ygg.routing-bench/v1
questions:
  - { id: who-consumes-api, kind: consumers, about: api, answer: [web, worker] }
  - { id: who-consumes-web, kind: consumers, about: web, answer: [] }
  - { id: who-holds-the-api-contract, kind: contract-owner, about: api/internal/api.openapi.yaml, answer: [api] }
  - { id: a-change-to-the-api-reaches, kind: reached-by, about: api, answer: [web, worker] }
  - { id: a-chi-bump-reaches, kind: reached-by, about: "go:github.com/go-chi/chi/v5", answer: [api, web, worker] }
  - { id: the-contract-reaches-leaves, kind: contract-readers, about: api/internal/api.openapi.yaml, answer: [web, worker] }
  - { id: which-react-does-web-pin, kind: pin, about: web, arg: "npm:react", answer: ["19.3.0"] }
  - { id: what-does-the-api-need, kind: services, about: api, answer: [postgres, seaweedfs] }
```

Expected output:

```text
# github.com/ouroboric-dev/odin/internal/routing [github.com/ouroboric-dev/odin/internal/routing.test]
internal/routing/bench_test.go:12:38: undefined: Answerer
internal/routing/bench_test.go:12:59: undefined: Bench
internal/routing/bench_test.go:14:12: undefined: LoadBench
FAIL	github.com/ouroboric-dev/odin/internal/routing [build failed]
```

- [ ] **Step 5:** write the bench, the index answerer and the baseline.

Create `internal/routing/bench.go`:

```go
package routing

import (
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"regexp"
	"slices"
	"strings"

	"go.yaml.in/yaml/v3"
)

// BenchSchema names the format of a routing bench.
const BenchSchema = "ygg.routing-bench/v1"

// The kinds of question a bench asks (spec §8.3). Each is answered by one lookup in an index.
const (
	QConsumers       = "consumers"        // about a leaf: the leaves that depend on it
	QContractOwner   = "contract-owner"   // about a contract file: the leaf that holds it
	QReachedBy       = "reached-by"       // about a leaf, contract or package: the leaves a change reaches
	QContractReaders = "contract-readers" // about a contract file: the leaves other than its owner that a change reaches
	QPin             = "pin"              // about a leaf, arg a package: the version it pins
	QServices        = "services"         // about a leaf: the services its realm gives it
)

// Question is one bench question with its known answer. An answer is a set: its order does not matter.
type Question struct {
	ID     string   `yaml:"id"`
	Kind   string   `yaml:"kind"`
	About  string   `yaml:"about"`
	Arg    string   `yaml:"arg,omitempty"`
	Answer []string `yaml:"answer"`
}

// Bench is a project's routing bench: fixed questions with known answers. It lives in the project
// umbrella, where no agent mounts, so an agent can't write the answers it is graded on.
type Bench struct {
	Schema    string     `yaml:"schema"`
	Questions []Question `yaml:"questions"`
}

var benchID = regexp.MustCompile(`^[a-z0-9][a-z0-9-]*$`)

// LoadBench reads a bench file: one YAML document with no unknown field, 1 to 500 questions, each with
// a unique id and a known kind, from a regular file (not a link) of at most 1 MiB.
func LoadBench(path string) (*Bench, error) {
	fi, err := os.Lstat(path)
	if err != nil {
		return nil, err
	}
	if !fi.Mode().IsRegular() || fi.Size() > maxFile {
		return nil, fmt.Errorf("%s: the bench must be a regular file of at most %d bytes", path, maxFile)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	dec := yaml.NewDecoder(bytes.NewReader(data))
	dec.KnownFields(true)
	var b Bench
	if err := dec.Decode(&b); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if err := dec.Decode(new(any)); !errors.Is(err, io.EOF) {
		return nil, fmt.Errorf("%s: more than one YAML document", path)
	}
	if b.Schema != BenchSchema {
		return nil, fmt.Errorf("%s: schema %q, want %q", path, b.Schema, BenchSchema)
	}
	if len(b.Questions) == 0 || len(b.Questions) > 500 {
		return nil, fmt.Errorf("%s: %d questions, want 1 to 500", path, len(b.Questions))
	}
	seen := map[string]bool{}
	for _, q := range b.Questions {
		switch {
		case !benchID.MatchString(q.ID):
			return nil, fmt.Errorf("%s: question id %q must be lower case words joined by dashes", path, q.ID)
		case seen[q.ID]:
			return nil, fmt.Errorf("%s: question %s is there twice", path, q.ID)
		case !slices.Contains([]string{QConsumers, QContractOwner, QReachedBy, QContractReaders, QPin, QServices}, q.Kind):
			return nil, fmt.Errorf("%s: question %s has the unknown kind %q", path, q.ID, q.Kind)
		case q.About == "":
			return nil, fmt.Errorf("%s: question %s asks about nothing", path, q.ID)
		case (q.Kind == QPin) != (q.Arg != ""):
			return nil, fmt.Errorf("%s: question %s: only a pin question has an arg, and it needs one", path, q.ID)
		}
		seen[q.ID] = true
	}
	return &b, nil
}

// Answerer answers a question with a set. ok is false when it can't answer.
type Answerer interface {
	Answer(q Question) (answer []string, ok bool)
}

// Report is a bench run: the questions answered right first, out of all of them.
type Report struct {
	Right, Total int
	Score        float64
	Misses       []string // the ids of the questions answered wrong, in bench order
}

// Score asks every question once. An answer is right when it is the known set, no more, no less. There is
// no second try and no model: this is right-first.
func (b *Bench) Score(a Answerer) Report {
	r := Report{Total: len(b.Questions)}
	for _, q := range b.Questions {
		if got, ok := a.Answer(q); ok && sameSet(got, q.Answer) {
			r.Right++
		} else {
			r.Misses = append(r.Misses, q.ID)
		}
	}
	if r.Total > 0 {
		r.Score = float64(r.Right) / float64(r.Total)
	}
	return r
}

// Ships reports whether an index with this score ships: it scored at or above the pack's threshold.
// A bench with no question never ships an index.
func (r Report) Ships(threshold float64) bool {
	return r.Total > 0 && float64(r.Right)+1e-9 >= threshold*float64(r.Total)
}

func (r Report) String() string { return fmt.Sprintf("%d/%d right first", r.Right, r.Total) }

func sameSet(a, b []string) bool {
	x, y := slices.Clone(a), slices.Clone(b)
	slices.Sort(x)
	slices.Sort(y)
	return slices.Equal(slices.Compact(x), slices.Compact(y))
}

type indexAnswerer struct {
	res *Result
	imp *Impact
}

// IndexAnswerer answers from the two indexes alone: one lookup for each question, extracted edges only.
func IndexAnswerer(res *Result, imp *Impact) Answerer { return indexAnswerer{res, imp} }

func (a indexAnswerer) Answer(q Question) ([]string, bool) {
	out := []string{}
	switch q.Kind {
	case QConsumers:
		for _, e := range a.res.Edges {
			if e.Tag == Extracted && e.To == q.About && slices.Contains([]string{"consumes", "requires", "imports"}, e.Kind) && slices.Contains(a.res.Leaves, e.From) {
				out = append(out, e.From)
			}
		}
	case QContractOwner:
		for _, e := range a.res.Edges {
			if e.Tag == Extracted && e.Kind == "holds" && e.To == "contract:"+q.About {
				out = append(out, e.From)
			}
		}
	case QReachedBy:
		out = slices.Clone(a.imp.Reaches(q.About).Extracted)
		out = slices.DeleteFunc(out, func(s string) bool { return !slices.Contains(a.res.Leaves, s) })
	case QContractReaders:
		c, ok := a.imp.Contract(q.About)
		if !ok {
			return nil, false
		}
		out = c.Readers.Extracted
	case QPin:
		for _, e := range a.res.Edges {
			if e.Tag == Extracted && e.Kind == "pins" && e.From == q.About && strings.HasPrefix(e.To, q.Arg+"@") {
				out = append(out, strings.TrimPrefix(e.To, q.Arg+"@"))
			}
		}
	case QServices:
		for _, e := range a.res.Edges {
			if e.Tag == Extracted && e.Kind == "needs" && e.From == q.About {
				out = append(out, strings.TrimPrefix(e.To, "service:"))
			}
		}
	default:
		return nil, false
	}
	return out, true
}

type grepBaseline struct {
	w      *wiring
	leaves []string
}

// GrepBaseline is the scripted stand-in for an agent with no index: it searches the leaves' text for the
// name asked about. It can answer who mentions a name, and nothing else. It is the figure to beat.
func GrepBaseline(dir string, leaves []string) Answerer {
	return grepBaseline{w: &wiring{root: dir}, leaves: leaves}
}

func (g grepBaseline) Answer(q Question) ([]string, bool) {
	var term string
	switch q.Kind {
	case QConsumers, QReachedBy:
		term = strings.TrimPrefix(strings.TrimPrefix(q.About, "go:"), "npm:")
	case QContractOwner, QContractReaders:
		term = q.About[strings.LastIndex(q.About, "/")+1:]
	default:
		return nil, false
	}
	re := regexp.MustCompile(`(?i)\b` + regexp.QuoteMeta(term) + `\b`)
	out := []string{}
	for _, l := range g.leaves {
		if l == q.About {
			continue
		}
		for _, rel := range g.w.walk(l, func(string) bool { return true }) {
			if b := g.w.read(rel); b != nil && (re.Match(b) || re.MatchString(rel)) {
				out = append(out, l)
				break
			}
		}
	}
	return out, true
}
```

- [ ] **Step 6:** run the tests, then commit.

```bash
go test -race -v -run 'Bench|Grep|ShipsOnly|TheIndexAnswers' ./internal/routing
```

The baseline test logs the figures: `index 8/8 right first, baseline 2/8 right first, misses [who-consumes-web who-holds-the-api-contract a-chi-bump-reaches the-contract-reaches-leaves which-react-does-web-pin what-does-the-api-need]`. Commit in `odin`: `The routing bench: fixed questions with known answers, scored right-first from the indexes with no model, and a grep baseline to beat (v0-T255)`.

#### Part 3: an index ships only at or above the threshold (`bb841e2`)

- [ ] **Step 7:** write the engine tests first.

Change `internal/engine/routing_test.go`:

```diff
diff --git a/internal/engine/routing_test.go b/internal/engine/routing_test.go
index 771f2b5..8fc3d28 100644
--- a/internal/engine/routing_test.go
+++ b/internal/engine/routing_test.go
@@ -72,3 +72,62 @@ func TestAnIndexThatLostEdgesStopsAtTheShrinkGuard(t *testing.T) {
 		t.Error("no pointer")
 	}
 }
+
+const benchPack = packChecks + "routing:\n  threshold: 0.8\n"
+
+func writeBench(t *testing.T, r *run.Run, body string) {
+	t.Helper()
+	p := filepath.Join(r.Project, ".ygg", "routing-bench.yaml")
+	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
+		t.Fatal(err)
+	}
+	if err := os.WriteFile(p, []byte("schema: ygg.routing-bench/v1\nquestions:\n"+body), 0o644); err != nil {
+		t.Fatal(err)
+	}
+}
+
+const rightBench = "  - { id: who-requires-chi, kind: pin, about: repos/app, arg: \"go:github.com/go-chi/chi/v5\", answer: []}\n" +
+	"  - { id: who-consumes-app, kind: consumers, about: repos/app, answer: [] }\n"
+
+func TestAnIndexAtTheThresholdShipsAndTheLedgerKeepsTheScore(t *testing.T) {
+	r := startPack(t, "key-points", "", benchPack, shipNodes, goModScript)
+	writeBench(t, r, rightBench)
+	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+	if text := ledgerText(t, r); !strings.Contains(text, "bench 2/2 right first at threshold 0.80") {
+		t.Errorf("the ledger lacks the bench score:\n%s", text)
+	}
+}
+
+// Review focus: an index under the pack's threshold does not ship. Nothing is written and the pointer stays.
+func TestAnIndexUnderTheThresholdDoesNotShip(t *testing.T) {
+	cases := map[string]string{
+		"a wrong answer":  rightBench + "  - { id: who-consumes-nothing, kind: consumers, about: repos/app, answer: [ghost] }\n",
+		"no bench at all": "",
+	}
+	for name, body := range cases {
+		r := startPack(t, "key-points", "", benchPack, shipNodes, goModScript)
+		if body != "" {
+			writeBench(t, r, body)
+		}
+		before, _ := git.Run(bg, r.Project, "rev-parse", "HEAD:repos/app")
+		out, err := Advance(bg, r)
+		if err != nil || out.Status != run.StatusFailed || out.Err == nil || !strings.Contains(out.Err.Error(), "does not ship") {
+			t.Fatalf("%s: Advance() = %+v, %v; want a failed node that says the index does not ship", name, out, err)
+		}
+		if _, err := os.Stat(filepath.Join(r.Project, "REPOS.md")); err == nil {
+			t.Errorf("%s: REPOS.md was written", name)
+		}
+		if after, _ := git.Run(bg, r.Project, "rev-parse", "HEAD:repos/app"); after != before {
+			t.Errorf("%s: the pointer moved", name)
+		}
+	}
+}
+
+func TestAPackWithoutARoutingBlockShipsUnmeasured(t *testing.T) {
+	r := startPack(t, "key-points", "", packChecks, shipNodes, goModScript)
+	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+}
```

Expected output (the bench is not read yet, so the score is never logged and the under-threshold run finishes `done`):

```text
--- FAIL: TestAnIndexAtTheThresholdShipsAndTheLedgerKeepsTheScore (0.45s)
    routing_test.go:99: the ledger lacks the bench score:
...
--- FAIL: TestAnIndexUnderTheThresholdDoesNotShip
    routing_test.go:117: a wrong answer: Advance() = {Status:done ...}; want a failed node that says the index does not ship
FAIL
```

- [ ] **Step 8:** read the bench in `shipRouting`.

Change `internal/engine/routing.go`:

```diff
diff --git a/internal/engine/routing.go b/internal/engine/routing.go
index 7e2d048..fa3e2cd 100644
--- a/internal/engine/routing.go
+++ b/internal/engine/routing.go
@@ -2,7 +2,9 @@ package engine
 
 import (
 	"fmt"
+	"path/filepath"
 	"slices"
+	"strings"
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
@@ -34,6 +36,21 @@ func shipRouting(r *run.Run, n schema.Node, attempt int, parent tree.Node) error
 	if len(res.Skipped) > 0 {
 		note = fmt.Sprintf("left out: %d (first: %s)", len(res.Skipped), res.Skipped[0])
 	}
+	// The pack of the lead realm sets the bar (spec §8.3). The bench is in the project umbrella, where
+	// no agent mounts. Under the bar, or with no bench to measure by, nothing is written.
+	if rp := r.Setup.Lead.Pack.Routing; rp != nil {
+		bench, err := routing.LoadBench(filepath.Join(parent.Dir, filepath.FromSlash(rp.BenchPath())))
+		if err != nil {
+			return &nodeFailure{fmt.Errorf("the routing index does not ship, because its bench can't be read: %w", err)}
+		}
+		rep := bench.Score(routing.IndexAnswerer(res, routing.ImpactOf(res)))
+		base := bench.Score(routing.GrepBaseline(parent.Dir, res.Leaves))
+		score := fmt.Sprintf("bench %v at threshold %.2f (grep baseline %v)", rep, rp.Threshold, base)
+		if !rep.Ships(rp.Threshold) {
+			return &nodeFailure{fmt.Errorf("the routing index does not ship: %s; wrong or unanswered: %v", score, rep.Misses)}
+		}
+		note = strings.TrimSpace(note + " " + score)
+	}
 	x, i := routing.Counts(res.Edges)
 	built := func(kind string) error {
 		return r.Log(gungnir.Event{Name: gungnir.EventRoutingIndexBuilt, Node: n.ID, Attempt: attempt, Task: n.Task,
```

- [ ] **Step 9:** run the checks, then commit.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/odin
gofmt -l .
go vet ./...
go test -race -v -run 'Bench|Grep|Threshold|Unmeasured|ShipsOnly|Index' ./internal/routing ./internal/engine
(cd ../gungnir && go test -race -v -run Routing ./schema)
```

Expected output:

```text
--- PASS: TestTheIndexAnswersTheFixtureBenchRightFirst (0.01s)
    bench_test.go:38: index 8/8 right first, baseline 2/8 right first, misses [who-consumes-web who-holds-the-api-contract a-chi-bump-reaches the-contract-reaches-leaves which-react-does-web-pin what-does-the-api-need]
--- PASS: TestTheGrepBaselineScoresLowerThanTheIndex (0.02s)
--- PASS: TestAnIndexShipsOnlyAtOrAboveTheThreshold (0.01s)
--- PASS: TestABenchThatIsNotExactIsRefused (0.00s)
--- PASS: TestJudgeByTheEvidenceOfTheIndex (0.00s)
--- PASS: TestTheImpactIndexIsALabelledLowerBoundAndReportsGuessesApart (0.01s)
--- PASS: TestTheImpactIndexIsTheSameBytesEveryTimeAndRoundTrips (0.02s)
ok  	github.com/ouroboric-dev/odin/internal/routing	1.103s
--- PASS: TestAPointerMoveShipsBothIndexesAndLogsThem (0.78s)
--- PASS: TestAnIndexThatLostEdgesStopsAtTheShrinkGuard (0.59s)
--- PASS: TestAnIndexAtTheThresholdShipsAndTheLedgerKeepsTheScore (0.59s)
--- PASS: TestAnIndexUnderTheThresholdDoesNotShip (0.84s)
--- PASS: TestAPackWithoutARoutingBlockShipsUnmeasured (0.51s)
ok  	github.com/ouroboric-dev/odin/internal/engine	4.381s
--- PASS: TestTheLedgerRecordsGradingRoutingAndDependencyChecks (0.04s)
--- PASS: TestAPackSetsTheRoutingBenchThreshold (0.02s)
--- PASS: TestAPackRefusesABadRoutingBlock (0.05s)
ok  	github.com/ouroboric-dev/gungnir/schema	(cached)
```

Commit in `odin`: `An index ships only at or above the pack's routing threshold; under it, or without a bench, nothing is written (v0-T255)`.

**Evidence:** red runs above, green runs above, all with `-race`. The engine tests run full fake runs on a real git project, with a real bench file in the umbrella and a pack with `routing: {threshold: 0.8}`; the failing runs are checked for no `REPOS.md` on disk and an unmoved pointer. The grep baseline reads the fixture files for real. `go test -race ./...` in `odin` and in `gungnir` passed.

### Task v0-T256: `pointer-contract` in the graph of midgard-react, and the routing docs of midgard-react and helheim-go

Branches `routing/pointer-contract` from `origin/main` in `midgard-react` and in `helheim-go`, one commit each. Both tests run
through a workspace that holds the local Gungnir (`go.work`), because midgard-react's test reads `Pack.Routing` (v0-T255).

**helheim-go has no graph** (its `pack.yaml` says: "A run takes its graph from its lead realm"; `TestThePackLoadsAndOffersTheRecipeEveryBuildRealmOffers` pins `Graph == ""`). So it gets no gate. What it owes routing is wired: a contract that Odin finds, and `oasdiff` in the image. A test pins both, and the architecture page documents routing.

**Files (in `midgard-react`):**

- Modify: `graph.yaml`, `pack_test.go`, `docs/architecture.md`

**Files (in `helheim-go`):**

- Modify: `pack_test.go`, `docs/architecture.md`

**Interfaces:**

- Consumes: the `pointer-contract` gate and the shipping of indexes at a move (v0-T253, v0-T254). No new field in Gungnir's graph schema: the `move` node uses `generated`, which exists.
- Produces: in the task body of `midgard-react`'s graph, a node `{ id: contract-gate, kind: gate, gate: pointer-contract }` between `pointer-gate` and `move`, and `generated: [REPOS.md, .ygg/impact.json]` on `move`. The body is now `implement, feature-gate, merge-gate, land, pointer-gate, contract-gate, move`. The gate re-runs `implement` when a person rejects it (every gate gets the loop before it).
- The pack of midgard-react sets **no** `routing` block (decision 6). The test says so, so that nobody turns the threshold on by accident.
- The docs: a "Routing" section in each `docs/architecture.md`: what Odin builds, which files a leaf gives it, how a contract is named (a file name that ends in `openapi.yaml`), how the gate judges, and how a project turns the bench on.

**Acceptance criteria:**

- [ ] The graph loads with Gungnir's schema, and `contract-gate` is right before `move` and after `land`.
- [ ] `move` lists both indexes in `generated`.
- [ ] The web template holds one OpenAPI file and its name ends in `openapi.yaml`; the api template's OpenAPI files all do, and `go-contract.sh` runs `oasdiff breaking`.

**Review focus pinned by tests:**

- The gate judges the move after it, so its place matters: `TestTheContractGateComesBeforeTheMoveAndTheMoveShipsTheRoutingIndexes`.
- A rename of a template contract would hide it from routing: `TestTheTemplatesContractIsNamedSoRoutingFindsIt` in both repos.

**Named test:** `go test . -run 'Contract|EveryTask|Templates'` in each repo. **Layer:** `midgard-react`, `helheim-go`. **Size:** S and S (65, 46). **Depends on:** v0-T254, v0-T255.

- [ ] **Step 1:** in `midgard-react`, create the branch and write the tests first (the existing graph test changes its expected body).

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/midgard-react
git switch -c routing/pointer-contract main
```

Change `pack_test.go`:

```diff
diff --git a/pack_test.go b/pack_test.go
index 496d3bf..1f03e27 100644
--- a/pack_test.go
+++ b/pack_test.go
@@ -134,7 +134,7 @@ func TestEveryTaskRunsTheLoopWithThreeReviewersThenTheGatesAndTheMoveWithAccepta
 	for _, n := range body {
 		ids = append(ids, n.ID)
 	}
-	if strings.Join(ids, ",") != "implement,feature-gate,merge-gate,land,pointer-gate,move" {
+	if strings.Join(ids, ",") != "implement,feature-gate,merge-gate,land,pointer-gate,contract-gate,move" {
 		t.Fatalf("the task shape = %v", ids)
 	}
 	impl := body[0]
@@ -148,7 +148,7 @@ func TestEveryTaskRunsTheLoopWithThreeReviewersThenTheGatesAndTheMoveWithAccepta
 	if !slices.Contains(impl.Reviewers[1].Skills, "ponytail-review") {
 		t.Error("the simplicity reviewer does not load the Ponytail skill")
 	}
-	land, move := body[3], body[5]
+	land, move := body[3], body[6]
 	if land.BackTo != "implement" || move.BackTo != "implement" || !slices.Equal(move.Acceptance, []string{"accept"}) {
 		t.Errorf("land %+v, move %+v: a refusal goes back to the implementer, and the move runs the acceptance check", land, move)
 	}
@@ -191,3 +191,42 @@ func TestEveryPromptIsUsedAndEveryPromptTheGraphNamesIsThere(t *testing.T) {
 		}
 	}
 }
+
+// Spec §3.4: a move that changes a contract is the pointer-contract approval point. The gate judges the move
+// that follows it, so it comes after the leaf has landed and before the move. The move also ships the routing
+// indexes (spec §8): Odin builds REPOS.md's wiring block and .ygg/impact.json, and the shrink guard reads them.
+func TestTheContractGateComesBeforeTheMoveAndTheMoveShipsTheRoutingIndexes(t *testing.T) {
+	body := loadGraph(t).Nodes[len(loadGraph(t).Nodes)-1].Body
+	by := map[string]int{}
+	for i, n := range body {
+		by[n.ID] = i
+	}
+	gate, move := body[by["contract-gate"]], body[by["move"]]
+	if gate.Kind != schema.KindGate || gate.Gate != gungnir.GatePointerContract || by["contract-gate"] != by["move"]-1 || by["contract-gate"] < by["land"] {
+		t.Errorf("contract-gate = %+v at %d; want the pointer-contract gate right before the move and after the land", gate, by["contract-gate"])
+	}
+	if !slices.Equal(move.Generated, []string{"REPOS.md", ".ygg/impact.json"}) {
+		t.Errorf("the move generates %v; it must list both routing indexes so Odin builds them and the shrink guard reads them", move.Generated)
+	}
+	if loadPack(t).Routing != nil {
+		t.Error("the pack sets a routing threshold; a project needs its bench first (docs/architecture.md)")
+	}
+}
+
+// Routing finds a contract by its name (Odin: a file name that ends in openapi.yaml). The web template's copy
+// of the API contract must be named so, or the impact index never sees it.
+func TestTheTemplatesContractIsNamedSoRoutingFindsIt(t *testing.T) {
+	var found []string
+	err := filepath.WalkDir("templates/web", func(p string, d os.DirEntry, err error) error {
+		if err == nil && !d.IsDir() && strings.Contains(d.Name(), "openapi") {
+			found = append(found, p)
+		}
+		return err
+	})
+	if err != nil {
+		t.Fatal(err)
+	}
+	if len(found) != 1 || !strings.HasSuffix(found[0], "openapi.yaml") {
+		t.Errorf("OpenAPI files in the web template = %v; want one, named *openapi.yaml", found)
+	}
+}
```

Expected output:

```text
--- FAIL: TestEveryTaskRunsTheLoopWithThreeReviewersThenTheGatesAndTheMoveWithAcceptance (0.01s)
    pack_test.go:138: the task shape = [implement feature-gate merge-gate land pointer-gate move]
--- FAIL: TestTheContractGateComesBeforeTheMoveAndTheMoveShipsTheRoutingIndexes
    pack_test.go:206: contract-gate = {ID:implement ...} at 0; want the pointer-contract gate right before the move and after the land
    pack_test.go:209: the move generates []; it must list both routing indexes ...
FAIL
```

- [ ] **Step 2:** change the graph and the page.

Change `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 2b3fa22..4687d24 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -33,7 +33,7 @@ change proposal `2026-10-17-realm-leaf-naming`).
   against the design and the spec gate stops on a deviation; a reuse review reads the plan; the plan is read
   into tasks and the leaves are created from their realms' templates. Then, for every task: the implementer
   in a loop with the check ladder and three reviewers (spec compliance, simplicity, quality), the merge
-  gate, and the pointer move with the acceptance run.
+  gate, the `pointer-contract` gate and the pointer move with the acceptance run.
 - `prompts/`: planner, conformance, reuse-review, implementer and reviewer prompts. A planner prompt tells
   where its documents go; a test checks the examples in them against the schemas Odin reads.
 - `devcontainer/Containerfile` and `devcontainer/checks/`: the stack and the ladder's scripts. `web-static`,
@@ -45,6 +45,25 @@ change proposal `2026-10-17-realm-leaf-naming`).
 - `templates/web/`: the leaf a new web app starts from: Vite, React, TypeScript, Tailwind, TanStack Router
   and Query, a typed client for the contract, a tested component and a Playwright spec.
 
+## Routing
+
+Odin keeps two indexes of a project (spec §8). The wiring block of `REPOS.md` says who consumes, requires or
+pins what. `.ygg/impact.json` says what a change to a leaf, a contract or a package reaches. Odin builds both
+from the umbrella, the packs, `go.mod`, `package.json`, the lockfiles, Go imports and OpenAPI files. It calls no
+model. Every edge is `extracted` (read from a file) or `inferred` (a guess).
+
+- The `move` node lists both files in `generated`. At each move Odin rebuilds them and logs
+  `routing_index_built`. The shrink guard refuses an index that kept under half of its edges.
+- The `contract-gate` node judges the move after it. A move that changes an OpenAPI file is judged by
+  `extracted` edges of the shipped impact index, or by `oasdiff`. If the only evidence is an `inferred` edge,
+  the verdict is `escalate` and a person decides in every mode. The ledger records `pointer_contract_checked`.
+- A contract file is a file whose name ends in `openapi.yaml` or `openapi.yml`. The web template keeps its copy
+  of the API contract in `contracts/api.openapi.yaml`. A byte-identical copy is an `extracted` edge. A copy
+  with the same title and other bytes is `inferred`. Keep the copy current, or the gate escalates.
+- The pack sets no `routing` block. A project that wants its indexes measured adds `.ygg/routing-bench.yaml` to
+  its umbrella (questions with known answers, scored right first with no model) and a `routing:` block with a
+  `threshold` to the pack. Odin then ships an index only at or above the threshold.
+
 ## Tests
 
 `go test ./...` checks the pack, the graph and the prompts against Gungnir's schemas; runs the scripts on
```

Change `graph.yaml`:

```diff
diff --git a/graph.yaml b/graph.yaml
index 9631ded..4cd5fa7 100644
--- a/graph.yaml
+++ b/graph.yaml
@@ -1,7 +1,8 @@
 # The graph of a web product (spec §4.2): the stages that write documents in scratch workspaces, Odin
 # publishing them after the approval points, the plan read into tasks, the leaves created from their realms'
 # templates, and then, for every task, a loop of the implementer with the check ladder and three reviewers, the
-# merge gate and the pointer move with the acceptance run. The roles are the operator's factory.yaml roles:
+# merge gate, the pointer-contract gate (it judges the move after it: a contract change is a person's decision,
+# spec §3.4) and the pointer move with the acceptance run, which ships the routing indexes (spec §8). The roles are the operator's factory.yaml roles:
 # planner, implementer and reviewer.
 name: midgard-react
 version: 0.1.0
@@ -39,4 +40,5 @@ nodes:
       - { id: merge-gate, kind: gate, gate: merge }
       - { id: land, kind: merge, realm: leaf, back_to: implement }
       - { id: pointer-gate, kind: gate, gate: pointer }
-      - { id: move, kind: pointer, realm: leaf, acceptance: [accept], timeout: 25m, back_to: implement }
+      - { id: contract-gate, kind: gate, gate: pointer-contract }
+      - { id: move, kind: pointer, realm: leaf, acceptance: [accept], generated: [REPOS.md, .ygg/impact.json], timeout: 25m, back_to: implement }
```

- [ ] **Step 3:** run the checks, then commit.

```bash
gofmt -l .
GOWORK=$(pwd)/../go.work go test ./...
uvx -q --from 'reuse==5.0.2' reuse lint -q
```

Expected output: `ok  	github.com/ouroboric-dev/midgard-react` and no output from `reuse lint -q` (checked in all four repos). Commit in `midgard-react`: `The graph judges a move's contract changes at pointer-contract and ships the routing indexes at the move; routing documented (v0-T256)`.

- [ ] **Step 4:** in `helheim-go`, create the branch, write the test, change the page.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/helheim-go
git switch -c routing/pointer-contract main
```

Change `pack_test.go`:

```diff
diff --git a/pack_test.go b/pack_test.go
index f82d38d..e58acf6 100644
--- a/pack_test.go
+++ b/pack_test.go
@@ -117,3 +117,31 @@ func TestTheImplementerPromptTellsWhatTheFactoryChecksAndWhatNotToDo(t *testing.
 		}
 	}
 }
+
+// helheim-go has no graph in v0: the lead realm's graph holds the pointer-contract gate and the move that
+// ships the routing indexes (midgard-react). What this realm owes routing is a contract Odin can find,
+// and an oasdiff in its image for the gate. Odin finds a contract by a file name that ends in openapi.yaml.
+func TestTheTemplatesContractIsNamedSoRoutingFindsIt(t *testing.T) {
+	var found []string
+	err := filepath.WalkDir("templates/api", func(p string, d os.DirEntry, err error) error {
+		if err == nil && !d.IsDir() && strings.Contains(d.Name(), "openapi") {
+			found = append(found, p)
+		}
+		return err
+	})
+	if err != nil {
+		t.Fatal(err)
+	}
+	if len(found) == 0 {
+		t.Fatal("the api template holds no OpenAPI file")
+	}
+	for _, f := range found {
+		if !strings.HasSuffix(f, "openapi.yaml") {
+			t.Errorf("%s: routing finds a contract by a name that ends in openapi.yaml", f)
+		}
+	}
+	script, err := os.ReadFile("devcontainer/checks/go-contract.sh")
+	if err != nil || !strings.Contains(string(script), "oasdiff breaking") {
+		t.Errorf("go-contract.sh must run oasdiff breaking, the evidence the pointer-contract gate accepts beside extracted edges: %v", err)
+	}
+}
```

The test passes at once, because the template is named right today. It is a pin. To show it can fail, the run below renames `templates/api/openapi.yaml` and adds `templates/api/openapi-v1.json`:

```text
--- FAIL: TestTheTemplatesContractIsNamedSoRoutingFindsIt (0.00s)
    pack_test.go:140: templates/api/openapi-v1.json: routing finds a contract by a name that ends in openapi.yaml
FAIL
FAIL	github.com/ouroboric-dev/helheim-go	0.006s
FAIL
```

The two files are put back before the commit.

Change `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index cbf7965..07d7c12 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -39,6 +39,24 @@ proposal `2026-10-17-realm-leaf-naming`).
   store with migrations and `sqlc`, and the rules of the leaf in its `AGENTS.md`.
 - `prompts/implementer.md`: what the implementer of a task in this leaf is told.
 
+## Routing
+
+This realm has no graph, so it adds no gate and ships no index. The lead realm's graph does both
+(`midgard-react`: the `contract-gate` and the `move` with `generated: [REPOS.md, .ygg/impact.json]`). Odin builds
+the wiring block of `REPOS.md` and `.ygg/impact.json` from the project, with no model (spec §8). What a Go leaf
+gives it, all read from files, so every edge is `extracted`:
+
+- `go.mod`: direct requirements (a `require` of another leaf's module is an edge to that leaf), and the pins
+  that `go.sum` confirms.
+- Go imports of another leaf's module.
+- Every file whose name ends in `openapi.yaml`: the leaf holds that contract. The template's contract is
+  `openapi.yaml`. Name any other contract the same way, or routing does not see it.
+- The services this pack names (`postgres`, `seaweedfs`).
+
+The `pointer-contract` gate judges a move that changes a contract by these edges or by `oasdiff`. `go-contract.sh`
+already runs `oasdiff breaking` in the leaf, and the image holds `oasdiff`. A contract change that only a guess
+reaches goes to a person.
+
 ## Tests
 
 `go test ./...` runs the scripts on small leaves made in a temp dir, with the real `go` and `git` and
```

- [ ] **Step 5:** run the checks, then commit.

```bash
gofmt -l .
GOWORK=$(pwd)/../go.work go test ./...
uvx -q --from 'reuse==5.0.2' reuse lint -q
```

Expected output: `ok  	github.com/ouroboric-dev/helheim-go`. Commit in `helheim-go`: `Routing documented, and a test that the template's contract is named so routing finds it; helheim-go has no graph, the lead realm holds the gate (v0-T256)`.

**Evidence:** midgard-react: the red run above (the body had no gate, the move no `generated`), then `go test ./...` green in about 66 seconds, and `reuse lint -q` clean. helheim-go: the mutation run above, then `go test ./...` green in about 23 seconds. Both ran from a git worktree of `origin/main`, so the commits do not contain the dependency-policy and authorisation commits (T257, T258, T260) that other drafts hold on the local `main` of the same clones. The graph is not run end to end in this part: the engine tests of v0-T253 and v0-T254 use a test graph with the same node shapes. Running the real graph is the work of v0-T262.

## Exit state of this part

```text
ok  	github.com/ouroboric-dev/odin/internal/agents	
ok  	github.com/ouroboric-dev/odin/internal/budget	
ok  	github.com/ouroboric-dev/odin/internal/cli	
ok  	github.com/ouroboric-dev/odin/internal/engine	
ok  	github.com/ouroboric-dev/odin/internal/gate	
ok  	github.com/ouroboric-dev/odin/internal/git	
ok  	github.com/ouroboric-dev/odin/internal/leaf	
ok  	github.com/ouroboric-dev/odin/internal/ledger	
ok  	github.com/ouroboric-dev/odin/internal/lock	
ok  	github.com/ouroboric-dev/odin/internal/merge	
ok  	github.com/ouroboric-dev/odin/internal/plan	
ok  	github.com/ouroboric-dev/odin/internal/pointer	
ok  	github.com/ouroboric-dev/odin/internal/realm	
ok  	github.com/ouroboric-dev/odin/internal/remote	
ok  	github.com/ouroboric-dev/odin/internal/routing	
ok  	github.com/ouroboric-dev/odin/internal/run	
ok  	github.com/ouroboric-dev/odin/internal/score	
ok  	github.com/ouroboric-dev/odin/internal/shrink	
ok  	github.com/ouroboric-dev/odin/internal/snapshot	
ok  	github.com/ouroboric-dev/odin/internal/task	
ok  	github.com/ouroboric-dev/odin/internal/tree	
done
```

(`gofmt -l .` and `go vet ./...` print nothing. The `go test -race ./...` lines above are those of the tree with all nine commits.)

### Task v0-T257: the dependency policy rung for a Go leaf (`go-deps.sh`): tagged releases, a minimum patched version, `govulncheck` and OSV

Spec §9.6 says a dependency pins the minor version line, with a minimum patched version, and is gated on `govulncheck` and OSV. This task makes that a rung. The policy is a JSON file baked into the image beside the scripts, owned by root. The script passes its path to a small checker. The script never reads a policy file from the leaf. A leaf that carries its own `deps-policy.json` changes nothing.

For Go, "pinned to the minor line" means this: `go.mod` already names an exact version, so the rule is that every direct requirement is a tagged release. A pseudo-version, a pre-release and any `replace` are refused. A `replace` sends a package to a place `go.sum` does not vouch for. The `minimum` map applies to direct and indirect requirements, because the patched package is often indirect (`golang.org/x/text`, see Phase 5b decision 12).

The rung is its own check, `deps`, and not a part of `security`. Why: it needs no network for its first half, so it fails fast and cheap before the audits run. Odin's `deps.checked` event (v0-T245) can name the check. The spec puts it in rung 4 with `security`, so `deps` sits directly before `security` in the leaf's list.

**Files (in `helheim-go`):**

- Modify: `checks_test.go`
- Create: `deps_test.go`
- Create: `devcontainer/checks/config/deps-policy.json`
- Create: `devcontainer/checks/go-deps.sh`
- Create: `devcontainer/checks/lib/godeps.go`
- Modify: `docs/architecture.md`
- Modify: `pack.yaml`
- Modify: `pack_test.go`
- Modify: `templates/api/AGENTS.md`

**Interfaces:**

- Consumes: the baked `devcontainer/checks/config/` folder (the B-049 pattern: `go-static.sh` reads `config/golangci.yml` from beside itself) and the module-cache check of `go-security.sh`.
- Produces: the check `deps` in `pack.yaml` (`/opt/ygg/checks/go-deps.sh`), listed after `contract` and before `security`. The policy file `devcontainer/checks/config/deps-policy.json` with the contract shape `{"schema":"ygg.deps/v1","pin":"minor","minimum":{...},"audit":["govulncheck","osv"]}`. The checker `devcontainer/checks/lib/godeps.go` (`//go:build ignore`, standard library only, run with `go run`): `check <policy>` and `audit <policy>`. The checker refuses a policy with another schema, another pin, an unknown audit name, a bad minimum or an unknown field.
- The policy file in this realm: `golang.org/x/text` at or above `0.42.0` (the version Phase 5b pinned for the two known vulnerabilities, decision 12), audits `govulncheck` and `osv`.

**Acceptance criteria:**

- [ ] A clean leaf passes, and the rung runs `govulncheck ./...`, `govulncheck -tags integration ./...` and `osv-scanner scan source -L go.mod`. An audit tool that exits non-zero fails the rung.
- [ ] A direct requirement at a pseudo-version or a pre-release fails. A `replace` of any kind fails. A package below its minimum fails, also when it is indirect and also when it is a pre-release of the minimum. Each problem is printed, with a count.
- [ ] When the policy fails, no audit tool runs.
- [ ] A `deps-policy.json` in the leaf, or at `devcontainer/checks/config/` in the leaf, is not read.
- [ ] The unchanged template passes with the real `go`.
- [ ] A tampered module cache stops the rung (the same test as the other Go rungs).
- [ ] `TestEveryCheckRunsAScriptThatTheStackImageBakesIn` still holds: `lib/` is the one folder the pack test accepts besides `config/`.

**Review focus pinned:** 1 (a check an agent can weaken: the policy is baked and passed by path; `TestDepsListsEveryProblemAndNeverReadsAPolicyOfTheLeaf`). New line proposed for 5c: **a policy or a registry read from the leaf**; pinned by that test and by `TestTheBakedDepsPolicyIsValidAndTheChecksRunIt`.

**Named test:** `go test . -run 'Deps|TestEveryGoCheckRefusesATamperedModuleCache|TestThePackLoads|TestEveryCheckRunsAScript'` in `helheim-go`. **Layer:** `helheim-go`. **Size:** M. **Depends on:** v0-T256 (the pack edit follows it; no other dependency).

- [ ] **Step 1:** write the tests. Create `deps_test.go` as shown below. Apply the small test changes (`checks_test.go`, `pack_test.go`) from the patches below.
- [ ] **Step 2:** run the named test and see it fail.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/helheim-go
go test -count=1 -run 'Deps' . 2>&1 | tail -8
```

Expected: `FAIL`. The test output has `stat .../devcontainer/checks/lib/godeps.go: no such file or directory` and `bash: .../go-deps.sh: No such file or directory`.

- [ ] **Step 3:** write the policy, the checker and the script (all shown below), make the script executable (`chmod +x devcontainer/checks/go-deps.sh`), and apply the pack, architecture and template patches.
- [ ] **Step 4:** run the named test. Expect `ok`.

```bash
go vet ./... && go test -count=1 -run 'Deps|TestEveryGoCheckRefusesATamperedModuleCache|TestThePackLoads|TestEveryCheckRunsAScript' -v . 2>&1 | grep -E '^(--- |ok|FAIL)'
```

Expected: `--- PASS` for `TestDepsPassesACleanLeafAndRunsTheAuditsThePolicyNames`, `TestDepsRefusesWhatIsNotPinnedToATaggedVersionAndWhatIsBelowTheMinimum`, `TestDepsListsEveryProblemAndNeverReadsAPolicyOfTheLeaf`, `TestDepsCheckerRefusesAPolicyItDoesNotKnow`, `TestDepsPassesTheUnchangedTemplateWithTheRealGo`, `TestTheBakedDepsPolicyIsValidAndTheChecksRunIt`, then `ok  github.com/ouroboric-dev/helheim-go`.

- [ ] **Step 5:** try the script by hand. This is the real `go`, with stand-ins for the two audit tools (see Evidence).

```bash
# a leaf with three problems
printf 'module t\n\ngo 1.26\n\nrequire example.invalid/a v0.0.0-20261017195515-cb1dc0ee9cc6\nrequire golang.org/x/text v0.41.0 // indirect\nreplace example.invalid/a => ../a\n' > go.mod
bash /opt/ygg/checks/go-deps.sh
```

Expected, exit 1:

```text
== dependency policy
go.mod: example.invalid/a v0.0.0-20261017195515-cb1dc0ee9cc6 is a pseudo-version; pin a tagged release
go.mod: golang.org/x/text v0.41.0 is below the minimum 0.42.0
go.mod: replace example.invalid/a: a dependency is taken from nowhere the lock file vouches for
deps policy: 3 problem(s)
exit status 1
```

(`exit status 1` is `go run` saying the checker exited 1.) The same script on the unchanged template (audit tools replaced by stand-ins that print their call) gives exit 0 and:

```text
== dependency policy
deps policy: ok
== govulncheck
govulncheck ./...
govulncheck -tags integration ./...
== OSV
osv-scanner scan source -L go.mod
```

**The files.**

**New file `deps_test.go`**

```go
package helheim

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// go-deps.sh is rung 4's first half: the dependency policy (B-049 style: the policy is baked into the image and
// passed to the checker by path; the leaf's own copy of it, if it has one, is never read). These tests run it on
// small leaves with the real go, and stand-ins for govulncheck and osv-scanner.

const goModWith = "module t\n\ngo 1.26\n\n"

func TestDepsPassesACleanLeafAndRunsTheAuditsThePolicyNames(t *testing.T) {
	bin := stubs(t, "govulncheck", "osv-scanner")
	code, out := script(t, leaf(t, map[string]string{"go.mod": goMod}), bin, "go-deps.sh")
	if code != 0 || !strings.Contains(out, "deps policy: ok") {
		t.Fatalf("a clean leaf: exit %d\n%s", code, out)
	}
	for _, want := range []string{"govulncheck ./...", "govulncheck -tags integration ./...", "osv-scanner scan source -L go.mod"} {
		if !strings.Contains(calls(bin), want) {
			t.Errorf("calls %q lack %q", calls(bin), want)
		}
	}
	for _, env := range []string{"STUB_GOVULNCHECK_EXIT=3", "STUB_OSV_SCANNER_EXIT=1"} {
		if code, _ := script(t, leaf(t, map[string]string{"go.mod": goMod}), stubs(t, "govulncheck", "osv-scanner"), "go-deps.sh", env); code == 0 {
			t.Errorf("%s passed", env)
		}
	}
}

func TestDepsRefusesWhatIsNotPinnedToATaggedVersionAndWhatIsBelowTheMinimum(t *testing.T) {
	cases := []struct{ name, mod, want string }{
		{"a pseudo-version", "require example.invalid/dep v0.0.0-20261017195515-cb1dc0ee9cc6\n", "example.invalid/dep v0.0.0-20261017195515-cb1dc0ee9cc6 is a pseudo-version"},
		{"a pre-release", "require example.invalid/dep v1.2.3-rc.1\n", "example.invalid/dep v1.2.3-rc.1 is a pre-release"},
		{"a replace to a folder", "require example.invalid/dep v1.2.3\nreplace example.invalid/dep => ../dep\n", "replace example.invalid/dep"},
		{"a replace to another module", "require example.invalid/dep v1.2.3\nreplace example.invalid/dep => example.invalid/fork v1.2.3\n", "replace example.invalid/dep"},
		{"x/text below the minimum", "require golang.org/x/text v0.41.0 // indirect\n", "golang.org/x/text v0.41.0 is below the minimum 0.42.0"},
		{"a pre-release of the minimum", "require golang.org/x/text v0.42.0-rc.1 // indirect\n", "golang.org/x/text v0.42.0-rc.1 is below the minimum 0.42.0"},
		{"x/text far below the minimum", "require golang.org/x/text v0.9.0\n", "golang.org/x/text v0.9.0 is below the minimum 0.42.0"},
	}
	for _, c := range cases {
		bin := stubs(t, "govulncheck", "osv-scanner")
		code, out := script(t, leaf(t, map[string]string{"go.mod": goModWith + c.mod}), bin, "go-deps.sh")
		if code == 0 || !strings.Contains(out, c.want) {
			t.Errorf("%s: exit %d, want %q in:\n%s", c.name, code, c.want, out)
		}
		if calls(bin) != "" {
			t.Errorf("%s: an audit tool ran after the policy failed: %s", c.name, calls(bin))
		}
	}
	// At the minimum and above it, in any of the forms a version has, the policy is met.
	for _, v := range []string{"v0.42.0", "v0.42.1", "v0.43.0", "v1.0.0"} {
		dir := leaf(t, map[string]string{"go.mod": goModWith + "require golang.org/x/text " + v + " // indirect\n"})
		if out, err := checker(t, dir, "check", filepath.Join("devcontainer", "checks", "config", "deps-policy.json")); err != nil || !strings.Contains(out, "deps policy: ok") {
			t.Errorf("x/text %s: %v\n%s", v, err, out)
		}
	}
}

func TestDepsListsEveryProblemAndNeverReadsAPolicyOfTheLeaf(t *testing.T) {
	files := map[string]string{
		"go.mod": goModWith + "require (\n\texample.invalid/a v0.0.0-20261017195515-cb1dc0ee9cc6\n\tgolang.org/x/text v0.41.0 // indirect\n)\nreplace example.invalid/a => ../a\n",
		// the leaf's own policy, which would pass all of the above
		"deps-policy.json": `{"schema":"ygg.deps/v1","pin":"minor","minimum":{},"audit":[]}`,
		"devcontainer/checks/config/deps-policy.json": `{"schema":"ygg.deps/v1","pin":"minor","minimum":{},"audit":[]}`,
	}
	code, out := script(t, leaf(t, files), stubs(t, "govulncheck", "osv-scanner"), "go-deps.sh")
	if code == 0 {
		t.Fatalf("a leaf with its own policy passed:\n%s", out)
	}
	for _, want := range []string{"is a pseudo-version", "replace example.invalid/a", "is below the minimum 0.42.0", "3 problem(s)"} {
		if !strings.Contains(out, want) {
			t.Errorf("the output lacks %q:\n%s", want, out)
		}
	}
}

// checker runs devcontainer/checks/lib/godeps.go in dir with the command and the path of a policy.
func checker(t *testing.T, dir string, args ...string) (string, error) {
	t.Helper()
	helper, err := filepath.Abs(filepath.Join("devcontainer", "checks", "lib", "godeps.go"))
	if err != nil {
		t.Fatal(err)
	}
	if p, err := filepath.Abs(args[len(args)-1]); err == nil {
		args[len(args)-1] = p
	}
	cmd := exec.Command("go", append([]string{"run", helper}, args...)...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GOWORK=off")
	out, err := cmd.CombinedOutput()
	return string(out), err
}

// The checker reads the policy it is given and refuses one it does not know.
func TestDepsCheckerRefusesAPolicyItDoesNotKnow(t *testing.T) {
	dir := leaf(t, map[string]string{"go.mod": goMod})
	for name, policy := range map[string]string{
		"another schema":   `{"schema":"ygg.deps/v2","pin":"minor","minimum":{},"audit":[]}`,
		"another pin":      `{"schema":"ygg.deps/v1","pin":"major","minimum":{},"audit":[]}`,
		"an unknown audit": `{"schema":"ygg.deps/v1","pin":"minor","minimum":{},"audit":["npm"]}`,
		"a bad minimum":    `{"schema":"ygg.deps/v1","pin":"minor","minimum":{"a/b":"one"},"audit":[]}`,
		"an unknown field": `{"schema":"ygg.deps/v1","pin":"minor","minimum":{},"audit":[],"extra":1}`,
		"not json":         `pin: minor`,
	} {
		p := filepath.Join(t.TempDir(), "policy.json")
		if err := os.WriteFile(p, []byte(policy), 0o644); err != nil {
			t.Fatal(err)
		}
		out, err := checker(t, dir, "check", p)
		if err == nil || !strings.Contains(string(out), "deps policy") {
			t.Errorf("%s: err %v\n%s", name, err, out)
		}
	}
}

func TestDepsPassesTheUnchangedTemplateWithTheRealGo(t *testing.T) {
	dir := copyTemplate(t, "api")
	needModules(t, dir)
	code, out := script(t, dir, stubs(t, "govulncheck", "osv-scanner"), "go-deps.sh")
	if code != 0 || !strings.Contains(out, "deps policy: ok") {
		t.Errorf("the template: exit %d\n%s", code, out)
	}
}

func TestTheBakedDepsPolicyIsValidAndTheChecksRunIt(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("devcontainer", "checks", "config", "deps-policy.json"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{`"schema":"ygg.deps/v1"`, `"pin":"minor"`, `"golang.org/x/text":"0.42.0"`, `"govulncheck"`, `"osv"`} {
		if !strings.Contains(string(b), want) {
			t.Errorf("the baked policy lacks %s", want)
		}
	}
	s, _ := os.ReadFile(filepath.Join("devcontainer", "checks", "go-deps.sh"))
	if !strings.Contains(string(s), `"$here/config/deps-policy.json"`) {
		t.Error("go-deps.sh does not read the policy from from beside itself, through $here")
	}
}
```

**New file `devcontainer/checks/config/deps-policy.json`**

```json
{"schema":"ygg.deps/v1","pin":"minor","minimum":{"golang.org/x/text":"0.42.0"},"audit":["govulncheck","osv"]}
```

**New file `devcontainer/checks/go-deps.sh`**

```bash
#!/bin/bash
# Rung 4 of the ladder for a Go leaf, first half (spec §9.5, §9.6; v0-T257): the dependency policy. Every direct
# dependency is a tagged release, nothing is replaced, the packages the policy names are at or above their
# minimum patched version, and the audit tools the policy names find nothing. The policy is
# config/deps-policy.json, baked beside this script where the agent cannot write; a policy file in the leaf
# is never read. Run in the leaf's top folder.
set -euo pipefail
# The tools are found in the image's root-owned folders only, never in one the agent can write (/go/bin).
export PATH="${YGG_CHECKS_PATH:-/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin}"
here="$(cd "$(dirname "$0")" && pwd)"
policy="$here/config/deps-policy.json"
echo "== dependency policy"
GOFLAGS=-mod=mod go run "$here/lib/godeps.go" check "$policy"
# The module cache is kept between runs and the agent can write it (see go-security.sh).
{ go mod download && go mod verify; } >/dev/null 2>&1 || {
  echo "the module cache does not match go.sum, a dependency in it was changed:"
  go mod verify 2>&1 || go mod download 2>&1 || true
  exit 1
}
for tool in $(GOFLAGS=-mod=mod go run "$here/lib/godeps.go" audit "$policy"); do
  case "$tool" in
    govulncheck)
      echo "== govulncheck"
      govulncheck ./...
      govulncheck -tags integration ./...
      ;;
    osv)
      echo "== OSV"
      osv-scanner scan source -L go.mod
      ;;
  esac
done
```

**New file `devcontainer/checks/lib/godeps.go`**

```go
//go:build ignore

// godeps.go is the dependency policy checker of go-deps.sh (v0-T257). Run it in the leaf's top folder:
//
//	go run godeps.go check <policy.json>   checks go.mod against the policy
//	go run godeps.go audit <policy.json>   prints the audit tools the policy names, one per line
//
// It uses the standard library only, so it needs no module download. The policy is baked into the image
// and the script passes its path; the checker never looks for a policy in the leaf.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

type policy struct {
	Schema  string            `json:"schema"`
	Pin     string            `json:"pin"`
	Minimum map[string]string `json:"minimum"`
	Audit   []string          `json:"audit"`
}

type goMod struct {
	Require []struct {
		Path     string
		Version  string
		Indirect bool
	}
	Replace []struct {
		Old struct{ Path string }
	}
}

var (
	release = regexp.MustCompile(`^v(\d+)\.(\d+)\.(\d+)(\+incompatible)?$`)
	pseudo  = regexp.MustCompile(`-(0\.)?\d{14}-[0-9a-f]{12}`)
	plain   = regexp.MustCompile(`^(\d+)\.(\d+)\.(\d+)$`)
)

func fail(format string, a ...any) {
	fmt.Printf("deps policy: "+format+"\n", a...)
	os.Exit(1)
}

func load(path string) policy {
	b, err := os.ReadFile(path)
	if err != nil {
		fail("%v", err)
	}
	var p policy
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&p); err != nil {
		fail("%s is not a policy: %v", path, err)
	}
	if p.Schema != "ygg.deps/v1" {
		fail("%s has schema %q, want ygg.deps/v1", path, p.Schema)
	}
	if p.Pin != "minor" {
		fail("%s has pin %q, want minor", path, p.Pin)
	}
	for pkg, v := range p.Minimum {
		if !plain.MatchString(v) {
			fail("%s: the minimum of %s is %q, want x.y.z", path, pkg, v)
		}
	}
	for _, a := range p.Audit {
		if a != "govulncheck" && a != "osv" {
			fail("%s names the audit tool %q; the Go ladder knows govulncheck and osv", path, a)
		}
	}
	return p
}

func parts(v string) [3]int {
	m := release.FindStringSubmatch(v)
	if m == nil {
		m = plain.FindStringSubmatch("v" + strings.TrimPrefix(v, "v"))
		if m == nil {
			m = plain.FindStringSubmatch(strings.TrimPrefix(v, "v"))
		}
	}
	var out [3]int
	if m != nil {
		for i := range out {
			out[i], _ = strconv.Atoi(m[i+1])
		}
	}
	return out
}

func below(have, want string) bool {
	h, w := parts(have), parts(want)
	for i := range h {
		if h[i] != w[i] {
			return h[i] < w[i]
		}
	}
	// a pre-release of the minimum is lower than the minimum
	return strings.Contains(have, "-")
}

func check(p policy) {
	out, err := exec.Command("go", "mod", "edit", "-json").Output()
	if err != nil {
		fail("go mod edit -json: %v", err)
	}
	var m goMod
	if err := json.Unmarshal(out, &m); err != nil {
		fail("go.mod: %v", err)
	}
	var problems []string
	for _, r := range m.Replace {
		problems = append(problems, fmt.Sprintf("go.mod: replace %s: a dependency is taken from nowhere the lock file vouches for", r.Old.Path))
	}
	for _, r := range m.Require {
		if !r.Indirect {
			switch {
			case pseudo.MatchString(r.Version):
				problems = append(problems, fmt.Sprintf("go.mod: %s %s is a pseudo-version; pin a tagged release", r.Path, r.Version))
			case !release.MatchString(r.Version):
				problems = append(problems, fmt.Sprintf("go.mod: %s %s is a pre-release or not a tagged version; pin a tagged release", r.Path, r.Version))
			}
		}
		if min, ok := p.Minimum[r.Path]; ok && below(r.Version, min) {
			problems = append(problems, fmt.Sprintf("go.mod: %s %s is below the minimum %s", r.Path, r.Version, min))
		}
	}
	sort.Strings(problems)
	for _, s := range problems {
		fmt.Println(s)
	}
	if len(problems) > 0 {
		fail("%d problem(s)", len(problems))
	}
	fmt.Println("deps policy: ok")
}

func main() {
	if len(os.Args) != 3 {
		fail("usage: godeps.go check|audit <policy.json>")
	}
	p := load(os.Args[2])
	switch os.Args[1] {
	case "check":
		check(p)
	case "audit":
		for _, a := range p.Audit {
			fmt.Println(a)
		}
	default:
		fail("unknown command %q", os.Args[1])
	}
}
```

**Change to `checks_test.go`**

```diff
diff --git a/checks_test.go b/checks_test.go
index d66c2e6..dad9dbb 100644
--- a/checks_test.go
+++ b/checks_test.go
@@ -774,5 +774,5 @@ func TestEveryGoCheckRefusesATamperedModuleCache(t *testing.T) {
 	git(t, dir, "add", "b.go")
 	git(t, dir, "commit", "-q", "-m", "work")
-	names := []string{"go-static.sh", "go-unit.sh", "go-tdd.sh", "go-integration.sh", "go-security.sh"}
+	names := []string{"go-static.sh", "go-unit.sh", "go-tdd.sh", "go-integration.sh", "go-security.sh", "go-deps.sh"}
 	run := func(name string) (int, string) {
 		bin := stubs(t, "golangci-lint", "govulncheck", "osv-scanner")
```

**Change to `docs/architecture.md`**

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index cbf7965..530ba84 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -34,5 +34,7 @@ proposal `2026-10-17-realm-leaf-naming`).
 - `devcontainer/checks/`: the ladder: `go-static.sh` (gofmt, vet, lint, docs) and `go-unit.sh`,
   `go-tdd.sh` (new tests fail on the commit the task started from), `go-contract.sh` (OpenAPI lint,
-  generated code, breaking changes), `go-security.sh` (`govulncheck`, OSV) and `go-integration.sh`
+  generated code, breaking changes), `go-deps.sh` (the dependency policy: tagged releases only, the
+  minimum patched versions of `config/deps-policy.json`, then the audits the policy names), `go-security.sh`
+  (`govulncheck`, OSV) and `go-integration.sh`
   (tests that need Postgres). Rung 6 is the lead realm's reviewers; rung 7 is the grader's.
 - `templates/api/`: the leaf a new API starts from: a server with a health route, its contract, a
```

**Change to `pack.yaml`**

```diff
diff --git a/pack.yaml b/pack.yaml
index 2d6e1a7..f238d61 100644
--- a/pack.yaml
+++ b/pack.yaml
@@ -1,6 +1,7 @@
 # The Go flavor of the Helheim realm (change realm-leaf-naming): the recipe of a Go API leaf and the
 # services an API needs. It has no graph: a run takes its graph from its lead realm (midgard-react for the
-# client gallery). The check ladder is rungs 1 to 5 of spec §9.5; the reviewers (rung 6) are the lead
-# realm's, and rung 7 is the grader's.
+# client gallery). The check ladder is rungs 1 to 5 of spec §9.5, with the dependency policy (deps) beside
+# the security rung; the
+# reviewers (rung 6) are the lead realm's, and rung 7 is the grader's.
 name: helheim-go
 version: 0.1.0
@@ -10,4 +11,5 @@ checks:
   tdd: [/opt/ygg/checks/go-tdd.sh]
   contract: [/opt/ygg/checks/go-contract.sh]
+  deps: [/opt/ygg/checks/go-deps.sh]
   security: [/opt/ygg/checks/go-security.sh]
   integration: [/opt/ygg/checks/go-integration.sh]
@@ -17,5 +19,5 @@ leaf:
   first_commit: [LICENSE]
   implementer: prompts/implementer.md
-  checks: [static, unit, tdd, contract, security, integration]
+  checks: [static, unit, tdd, contract, deps, security, integration]
 services:
   postgres:
```

**Change to `pack_test.go`**

```diff
diff --git a/pack_test.go b/pack_test.go
index f82d38d..7363115 100644
--- a/pack_test.go
+++ b/pack_test.go
@@ -24,5 +24,5 @@ func TestThePackLoadsAndOffersTheRecipeEveryBuildRealmOffers(t *testing.T) {
 		t.Fatalf("leaf recipe = %+v", r)
 	}
-	want := []string{"static", "unit", "tdd", "contract", "security", "integration"}
+	want := []string{"static", "unit", "tdd", "contract", "deps", "security", "integration"}
 	if strings.Join(r.Checks, ",") != strings.Join(want, ",") {
 		t.Errorf("the ladder is %v, want %v: cheap rungs first, the one that needs services last", r.Checks, want)
@@ -59,6 +59,7 @@ func TestEveryCheckRunsAScriptThatTheStackImageBakesIn(t *testing.T) {
 	entries, _ := os.ReadDir(filepath.Join("devcontainer", "checks"))
 	for _, e := range entries {
-		// docs.sh and sqlc-owned.sh are run by the checks, and config/ is read by go-static.sh
-		used := e.Name() == "docs.sh" || e.Name() == "sqlc-owned.sh" || e.Name() == "config"
+		// docs.sh and sqlc-owned.sh are run by the checks, config/ is read by go-static.sh and go-deps.sh, and lib/ holds
+		// the helper go-deps.sh runs
+		used := e.Name() == "docs.sh" || e.Name() == "sqlc-owned.sh" || e.Name() == "config" || e.Name() == "lib"
 		for _, argv := range p.Checks {
 			used = used || filepath.Base(argv[0]) == e.Name()
```

**Change to `templates/api/AGENTS.md`**

```diff
diff --git a/templates/api/AGENTS.md b/templates/api/AGENTS.md
index 114a23c..0f1c7b6 100644
--- a/templates/api/AGENTS.md
+++ b/templates/api/AGENTS.md
@@ -12,5 +12,5 @@ This file only adds rules for this leaf. Read `docs/` for the design; this file
 - `go.mod` says `module api`. Imports are `api/internal/...`.
 - Standard library first: `net/http` with the Go 1.22 pattern mux. A new dependency needs a reason in
-  the commit message that the standard library cannot give.
+  the commit message that the standard library cannot give. A dependency is a tagged release: no pseudo-version, no `replace`.
 - The server listens on `PORT` and uses the database at `DATABASE_URL` when that is set. It reads nothing
   else from the environment that is not named in `docs/`.
```

- [ ] **Step 6:** the task's ending (see "How each task lands" in the 5b plan), then commit in `helheim-go`.

```bash
gofmt -l .                      # prints nothing
go vet ./...
GOWORK=off go test -race ./...  # ok
git add checks_test.go docs/architecture.md pack.yaml pack_test.go templates/api/AGENTS.md deps_test.go \
  devcontainer/checks/config/deps-policy.json devcontainer/checks/go-deps.sh devcontainer/checks/lib/godeps.go
git commit -m "feat(checks): dependency policy rung go-deps.sh with a baked deps-policy.json (v0-T257)" \
  -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**Evidence (run 2026-10-18, commit 70a6d1f in the reference clone):** `go vet ./...` clean, `go test -count=1 -race ./...` ok (31 s) with Go 1.26, the real `git`, `golangci-lint` and `sqlc` (the template static and TDD tests ran, none skipped). The checker and the script ran with the **real `go`** on the template (exit 0, policy ok) and on a leaf with a pseudo-version, a `replace` and a `golang.org/x/text` below the minimum (exit 1, three problems). **Not run:** `govulncheck` and `osv-scanner` are not installed in this environment (`command -v` finds neither). The tests and the hand run use stand-ins on `PATH` that log their call and exit as the test says; the commands the script gives them are the ones `go-security.sh` already gives the real tools. The image was not rebuilt for this task: it changes no Containerfile line, because `COPY checks/` takes `lib/` and `config/deps-policy.json`. **Limit:** `govulncheck` and `osv-scanner` have no severity filter in these calls, so the rung fails on any finding, which is stricter than "HIGH and above" in the contract. Filtering by severity needs OSV's JSON output and is left for the founder to decide. The audit calls repeat those of `go-security.sh`; the cost is two cached lookups, and the two can be merged later.

---

### Task v0-T258: the dependency policy rung for a web leaf (`web-deps.sh`): the same policy for npm

The web rung is the twin of v0-T257. The policy file has the same shape and the same name. The rule for npm: every direct dependency in `package.json` (`dependencies`, `devDependencies`, `optionalDependencies`) is `x.y.z` or `~x.y.z`. A caret, a range, `*`, a tag such as `latest`, a git URL, a file path and an alias are refused. The `minimum` map is read against `package-lock.json`: every copy of a named package in the lock file, nested copies included, is at or above the minimum. The checker reads the two JSON files and runs nothing of the leaf. The policy check runs before `npm ci`, so a bad pin fails with no network. Then `npm ci --ignore-scripts`, then the audits the policy names: `npm audit --audit-level=high` (name `npm-audit` in the policy) and `osv-scanner` (name `osv`).

`web-deps.sh` starts with `web-protected.sh`, like every web rung. The audit names differ from the Go ones (`npm-audit` for `govulncheck`), because the contract shows only the Go list. The checker refuses a policy that names a tool of the other ladder.

**Files (in `midgard-react`):**

- Modify: `checks_test.go`
- Create: `deps_test.go`
- Create: `devcontainer/checks/config/deps-policy.json`
- Create: `devcontainer/checks/lib/webdeps.mjs`
- Create: `devcontainer/checks/web-deps.sh`
- Modify: `docs/architecture.md`
- Modify: `pack.yaml`
- Modify: `pack_test.go`
- Modify: `templates/web/AGENTS.md`

**Interfaces:**

- Consumes: `web-protected.sh` (run first), `config/` (the baked folder; it now also holds `deps-policy.json`, which is data and not a tool config).
- Produces: the check `deps` in `pack.yaml` (`/opt/ygg/checks/web-deps.sh`) after `contract` and before `security`. The policy `{"schema":"ygg.deps/v1","pin":"minor","minimum":{"vite":"8.3.2"},"audit":["npm-audit","osv"]}`. The checker `devcontainer/checks/lib/webdeps.mjs` (node modules only): `check <policy>` and `audit <policy>`.
- The minimum in this realm is a floor, not a reaction to an advisory: `vite` at `8.3.2`, the version the template pins and the reviewed one. There is no advisory data in this environment to name a better number. **Decision for the founder:** which packages get a patched floor, and at which version.

**Acceptance criteria:**

- [ ] A clean leaf passes and the calls are, in order: `npm ci --ignore-scripts --no-audit --no-fund`, `npm audit --audit-level=high`, `osv-scanner scan source -L package-lock.json`. A failing audit tool fails the rung.
- [ ] Each of these fails and runs neither `npm` nor an audit tool: `^19.3.0`, `*`, `latest`, `>=19.0.0`, `19.x`, a `github:` URL, a `file:` path, an `npm:` alias, a caret in `optionalDependencies`; a locked `vite` below the minimum; a nested copy of `vite` below the minimum (the message names the nested path). A package of another scope with the same last name is not matched.
- [ ] A missing `package-lock.json` fails with "no package-lock.json".
- [ ] A `deps-policy.json` in the leaf is not read; all problems are listed with a count.
- [ ] The checker refuses a policy with another schema, another pin, a Go audit name, a bad minimum, an unknown field, or text that is not JSON.
- [ ] `web-deps.sh` is in the list of rungs that refuse a change to `.npmrc` or to the scripts of `package.json`.
- [ ] The unchanged template passes with the **real `npm`** (`npm ci` and `npm audit` find nothing), and the rung leaves the leaf unchanged.

**Review focus pinned:** 1 and the proposed new line of v0-T257 (a policy read from the leaf): `TestDepsNeedsALockFileAndNeverReadsAPolicyOfTheLeaf`, `TestEveryWebRungRefusesAChangeToTheScriptsAndNpmrc` (now with `web-deps.sh`).

**Named test:** `go test . -run 'Deps|TestEveryWebRungRefusesAChange|TestTheTemplatesToolConfigsAreTheBakedOnes|TestThePackLoads'` in `midgard-react`. **Layer:** `midgard-react`. **Size:** M. **Depends on:** v0-T256.

- [ ] **Step 1:** write the tests: create `deps_test.go`, and apply the test patches (`checks_test.go`: the rung list, and the count of files in `config/`; `pack_test.go`: the ladder and the folder `lib`).
- [ ] **Step 2:** run and see it fail.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/midgard-react
go test -count=1 -run 'Deps' . 2>&1 | grep -E '^(--- |ok|FAIL)'
```

Expected: six `--- FAIL` lines, then `FAIL`.

- [ ] **Step 3:** write the policy, the checker and the script, `chmod +x devcontainer/checks/web-deps.sh`, and apply the pack, docs and template patches.
- [ ] **Step 4:** run the named test. Expect `ok`.

```bash
gofmt -l . ; go vet ./... && go test -count=1 -run 'Deps' -v . 2>&1 | grep -E '^(--- |ok)'
```

Expected: six `--- PASS` lines (`TestDepsPassesACleanLeafAndRunsTheAuditsThePolicyNames`, `TestDepsRefusesWhatIsNotPinnedToAMinorLineAndWhatIsBelowTheMinimum`, `TestDepsNeedsALockFileAndNeverReadsAPolicyOfTheLeaf`, `TestDepsCheckerRefusesAPolicyItDoesNotKnow`, `TestDepsPassesTheUnchangedTemplateWithTheRealNpm`, `TestTheBakedDepsPolicyIsValidAndTheRungReadsItFromBesideItself`) and `ok  github.com/ouroboric-dev/midgard-react`.

- [ ] **Step 5:** try the script by hand on a leaf with a caret and a locked `vite 8.0.0` (committed on `main`).

```bash
bash /opt/ygg/checks/web-deps.sh
```

Expected, exit 1:

```text
== protected files
== dependency policy
package-lock.json: vite 8.0.0 is below the minimum 8.3.2
package.json: react ^19.3.0 is not pinned to a minor line (x.y.z or ~x.y.z)
deps policy: 2 problem(s)
```

On the unchanged template (with a stand-in for `osv-scanner`) it ends with exit 0 and:

```text
== protected files
== dependency policy
deps policy: ok

added 292 packages in 5s
== npm audit
found 0 vulnerabilities
== OSV
osv-scanner scan source -L package-lock.json
```

**The files.**

**New file `deps_test.go`**

```go
package midgard

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// web-deps.sh is rung 4's first half for a web leaf (v0-T258): the dependency policy. The policy is baked into
// the image and passed to the checker by path; the leaf's own copy, if it has one, is never read. These tests
// run it with the real node, and stand-ins for npm and osv-scanner.

// lock makes the text of a package-lock.json that resolves the given packages (path: version).
func lock(t *testing.T, pkgs map[string]string) string {
	t.Helper()
	p := map[string]any{"": map[string]any{"name": "t"}}
	for path, v := range pkgs {
		p[path] = map[string]any{"version": v}
	}
	b, err := json.Marshal(map[string]any{"name": "t", "lockfileVersion": 3, "packages": p})
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func pkgJSON(deps string) string {
	return `{"name":"t","scripts":{"lint":"eslint ."},` + deps + `}`
}

func depsLeaf(t *testing.T, deps string, pkgs map[string]string) string {
	t.Helper()
	return repo(t, map[string]string{".gitignore": "node_modules/\n", "package.json": pkgJSON(deps), "package-lock.json": lock(t, pkgs)})
}

func TestDepsPassesACleanLeafAndRunsTheAuditsThePolicyNames(t *testing.T) {
	dir := depsLeaf(t, `"dependencies":{"react":"19.3.0"},"devDependencies":{"vite":"~8.3.2","vitest":"5.0.3"}`,
		map[string]string{"node_modules/react": "19.3.0", "node_modules/vite": "8.3.2", "node_modules/vitest": "5.0.3"})
	bin := stubs(t, "osv-scanner")
	webTools(t, bin, nil)
	code, out := script(t, dir, bin, "web-deps.sh")
	want := "npm ci --ignore-scripts --no-audit --no-fund\nnpm audit --audit-level=high\nosv-scanner scan source -L package-lock.json\n"
	if code != 0 || calls(bin) != want || !strings.Contains(out, "deps policy: ok") {
		t.Fatalf("exit %d, calls %q\n%s", code, calls(bin), out)
	}
	for _, env := range []string{"STUB_NPM_EXIT=1", "STUB_OSV_SCANNER_EXIT=1"} {
		bin := stubs(t, "osv-scanner")
		webTools(t, bin, nil)
		if code, _ := script(t, dir, bin, "web-deps.sh", env); code == 0 {
			t.Errorf("%s passed", env)
		}
	}
}

func TestDepsRefusesWhatIsNotPinnedToAMinorLineAndWhatIsBelowTheMinimum(t *testing.T) {
	cases := []struct {
		name, deps string
		pkgs       map[string]string
		want       string
	}{
		{"a caret range", `"dependencies":{"react":"^19.3.0"}`, nil, "react ^19.3.0 is not pinned"},
		{"a wildcard", `"devDependencies":{"vitest":"*"}`, nil, "vitest * is not pinned"},
		{"a dist-tag", `"dependencies":{"react":"latest"}`, nil, "react latest is not pinned"},
		{"a range", `"dependencies":{"react":">=19.0.0"}`, nil, "react >=19.0.0 is not pinned"},
		{"an x range", `"dependencies":{"react":"19.x"}`, nil, "react 19.x is not pinned"},
		{"a git url", `"dependencies":{"evil":"github:someone/evil#main"}`, nil, "evil github:someone/evil#main is not pinned"},
		{"a file path", `"devDependencies":{"evil":"file:../evil"}`, nil, "evil file:../evil is not pinned"},
		{"an alias", `"dependencies":{"react":"npm:other@1.2.3"}`, nil, "react npm:other@1.2.3 is not pinned"},
		{"an optional dependency", `"optionalDependencies":{"fsevents":"^2.3.0"}`, nil, "fsevents ^2.3.0 is not pinned"},
		{"vite below the minimum", `"devDependencies":{"vite":"8.3.1"}`, map[string]string{"node_modules/vite": "8.3.1"}, "vite 8.3.1 is below the minimum 8.3.2"},
		{"vite far below, a major", `"devDependencies":{"vite":"7.9.9"}`, map[string]string{"node_modules/vite": "7.9.9"}, "vite 7.9.9 is below the minimum 8.3.2"},
		{"a copy of vite nested in another package", `"dependencies":{"react":"19.3.0"}`, map[string]string{"node_modules/vite": "8.3.2", "node_modules/x/node_modules/vite": "8.0.0"}, "node_modules/x/node_modules/vite 8.0.0 is below the minimum 8.3.2"},
		{"a scoped name is matched by its last parts", `"dependencies":{"react":"19.3.0"}`, map[string]string{"node_modules/vite": "8.3.2", "node_modules/@s/vite": "1.0.0"}, ""},
	}
	for _, c := range cases {
		dir := depsLeaf(t, c.deps, c.pkgs)
		bin := stubs(t, "osv-scanner")
		webTools(t, bin, nil)
		code, out := script(t, dir, bin, "web-deps.sh")
		if c.want == "" {
			if code != 0 {
				t.Errorf("%s: exit %d\n%s", c.name, code, out)
			}
			continue
		}
		if code == 0 || !strings.Contains(out, c.want) {
			t.Errorf("%s: exit %d, want %q in:\n%s", c.name, code, c.want, out)
		}
		if calls(bin) != "" {
			t.Errorf("%s: npm or an audit tool ran after the policy failed: %s", c.name, calls(bin))
		}
	}
}

func TestDepsNeedsALockFileAndNeverReadsAPolicyOfTheLeaf(t *testing.T) {
	dir := repo(t, map[string]string{"package.json": pkgJSON(`"dependencies":{"react":"^19.3.0"}`)})
	bin := stubs(t, "osv-scanner")
	webTools(t, bin, nil)
	if code, out := script(t, dir, bin, "web-deps.sh"); code == 0 || !strings.Contains(out, "no package-lock.json") {
		t.Errorf("no lock file: exit %d\n%s", code, out)
	}
	files := map[string]string{
		".gitignore": "node_modules/\n", "package.json": pkgJSON(`"dependencies":{"react":"^19.3.0"},"devDependencies":{"vite":"8.0.0"}`),
		"package-lock.json": lock(t, map[string]string{"node_modules/vite": "8.0.0"}),
		// the leaf's own policy, which would pass all of the above
		"deps-policy.json": `{"schema":"ygg.deps/v1","pin":"minor","minimum":{},"audit":[]}`,
		"devcontainer/checks/config/deps-policy.json": `{"schema":"ygg.deps/v1","pin":"minor","minimum":{},"audit":[]}`,
	}
	code, out := script(t, repo(t, files), bin, "web-deps.sh")
	if code == 0 {
		t.Fatalf("a leaf with its own policy passed:\n%s", out)
	}
	for _, want := range []string{"react ^19.3.0 is not pinned", "vite 8.0.0 is below the minimum 8.3.2", "2 problem(s)"} {
		if !strings.Contains(out, want) {
			t.Errorf("the output lacks %q:\n%s", want, out)
		}
	}
}

// A package.json of a leaf cannot make the checker run its code: the checker reads files and runs nothing of the leaf.
func TestDepsCheckerRefusesAPolicyItDoesNotKnow(t *testing.T) {
	dir := repo(t, map[string]string{"package.json": "{}", "package-lock.json": lock(t, nil)})
	helper, err := filepath.Abs(filepath.Join("devcontainer", "checks", "lib", "webdeps.mjs"))
	if err != nil {
		t.Fatal(err)
	}
	for name, policy := range map[string]string{
		"another schema":   `{"schema":"ygg.deps/v2","pin":"minor","minimum":{},"audit":[]}`,
		"another pin":      `{"schema":"ygg.deps/v1","pin":"major","minimum":{},"audit":[]}`,
		"an unknown audit": `{"schema":"ygg.deps/v1","pin":"minor","minimum":{},"audit":["govulncheck"]}`,
		"a bad minimum":    `{"schema":"ygg.deps/v1","pin":"minor","minimum":{"a":"one"},"audit":[]}`,
		"an unknown field": `{"schema":"ygg.deps/v1","pin":"minor","minimum":{},"audit":[],"extra":1}`,
		"not json":         `pin: minor`,
	} {
		p := filepath.Join(t.TempDir(), "policy.json")
		if err := os.WriteFile(p, []byte(policy), 0o644); err != nil {
			t.Fatal(err)
		}
		cmd := exec.Command("node", helper, "check", p)
		cmd.Dir = dir
		out, err := cmd.CombinedOutput()
		if err == nil || !strings.Contains(string(out), "deps policy") {
			t.Errorf("%s: err %v\n%s", name, err, out)
		}
	}
}

func TestDepsPassesTheUnchangedTemplateWithTheRealNpm(t *testing.T) {
	dir := realLeaf(t, nil)
	bin := stubs(t, "osv-scanner") // OSV needs its database; the policy and npm's own audit are real
	code, out := script(t, dir, bin, "web-deps.sh")
	skipOffline(t, out)
	if code != 0 || !strings.Contains(out, "deps policy: ok") {
		t.Errorf("the template: exit %d\n%s", code, out)
	}
	if st := git(t, dir, "status", "--porcelain"); st != "" {
		t.Errorf("web-deps.sh left the leaf changed:\n%s", st)
	}
}

func TestTheBakedDepsPolicyIsValidAndTheRungReadsItFromBesideItself(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("devcontainer", "checks", "config", "deps-policy.json"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{`"schema":"ygg.deps/v1"`, `"pin":"minor"`, `"vite":"8.3.2"`, `"npm-audit"`, `"osv"`} {
		if !strings.Contains(string(b), want) {
			t.Errorf("the baked policy lacks %s", want)
		}
	}
	s, _ := os.ReadFile(filepath.Join("devcontainer", "checks", "web-deps.sh"))
	if !strings.Contains(string(s), `"$here/config/deps-policy.json"`) || !strings.Contains(string(s), `web-protected.sh`) {
		t.Error("web-deps.sh does not read the policy from beside itself, or does not run web-protected.sh first")
	}
}
```

**New file `devcontainer/checks/config/deps-policy.json`**

```json
{"schema":"ygg.deps/v1","pin":"minor","minimum":{"vite":"8.3.2"},"audit":["npm-audit","osv"]}
```

**New file `devcontainer/checks/lib/webdeps.mjs`**

```js
// webdeps.mjs is the dependency policy checker of web-deps.sh (v0-T258). Run it in the leaf's top folder:
//
//   node webdeps.mjs check <policy.json>   checks package.json and package-lock.json against the policy
//   node webdeps.mjs audit <policy.json>   prints the audit tools the policy names, one per line
//
// It reads files and runs nothing of the leaf, and uses node's own modules only. The policy is baked into the
// image and the script passes its path; the checker never looks for a policy in the leaf.
import { readFileSync } from "node:fs";

const fail = (message) => {
  console.log(`deps policy: ${message}`);
  process.exit(1);
};

const readJSON = (path) => {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (e) {
    return fail(`${path}: ${e.code === "ENOENT" ? `no ${path}` : e.message}`);
  }
};

const plain = /^(\d+)\.(\d+)\.(\d+)$/;
const pinned = /^~?(\d+)\.(\d+)\.(\d+)$/;

function load(path) {
  const p = readJSON(path);
  const known = ["schema", "pin", "minimum", "audit"];
  const extra = Object.keys(p).filter((k) => !known.includes(k));
  if (extra.length > 0) fail(`${path} has the unknown field ${extra[0]}`);
  if (p.schema !== "ygg.deps/v1") fail(`${path} has schema ${JSON.stringify(p.schema)}, want ygg.deps/v1`);
  if (p.pin !== "minor") fail(`${path} has pin ${JSON.stringify(p.pin)}, want minor`);
  for (const [name, v] of Object.entries(p.minimum ?? {})) {
    if (!plain.test(v)) fail(`${path}: the minimum of ${name} is ${JSON.stringify(v)}, want x.y.z`);
  }
  for (const a of p.audit ?? []) {
    if (a !== "npm-audit" && a !== "osv") fail(`${path} names the audit tool ${JSON.stringify(a)}; the web ladder knows npm-audit and osv`);
  }
  return p;
}

// below says whether version is lower than minimum (x.y.z). A pre-release of the minimum is lower than it.
function below(version, minimum) {
  const m = /^(\d+)\.(\d+)\.(\d+)(-.*)?/.exec(version);
  if (!m) return true;
  const have = m.slice(1, 4).map(Number);
  const want = minimum.split(".").map(Number);
  for (let i = 0; i < 3; i++) if (have[i] !== want[i]) return have[i] < want[i];
  return m[4] !== undefined;
}

function check(p) {
  const pkg = readJSON("package.json");
  const problems = [];
  for (const section of ["dependencies", "devDependencies", "optionalDependencies"]) {
    for (const [name, spec] of Object.entries(pkg[section] ?? {})) {
      if (!pinned.test(spec)) problems.push(`package.json: ${name} ${spec} is not pinned to a minor line (x.y.z or ~x.y.z)`);
    }
  }
  let lock;
  try {
    lock = JSON.parse(readFileSync("package-lock.json", "utf8"));
  } catch {
    problems.push("package-lock.json: no package-lock.json; the packages must be locked");
  }
  const marker = "node_modules/";
  for (const [path, entry] of Object.entries(lock?.packages ?? {})) {
    const at = path.lastIndexOf(marker);
    if (at < 0) continue;
    const name = path.slice(at + marker.length);
    const min = p.minimum?.[name];
    if (min !== undefined && below(String(entry.version), min)) {
      const label = path.indexOf(marker) === at ? name : path;
      problems.push(`package-lock.json: ${label} ${entry.version} is below the minimum ${min}`);
    }
  }
  problems.sort();
  for (const s of problems) console.log(s);
  if (problems.length > 0) fail(`${problems.length} problem(s)`);
  console.log("deps policy: ok");
}

const [command, policyPath, ...rest] = process.argv.slice(2);
if (!policyPath || rest.length > 0) fail("usage: webdeps.mjs check|audit <policy.json>");
const policy = load(policyPath);
if (command === "check") check(policy);
else if (command === "audit") for (const a of policy.audit ?? []) console.log(a);
else fail(`unknown command ${JSON.stringify(command)}`);
```

**New file `devcontainer/checks/web-deps.sh`**

```bash
#!/bin/bash
# Rung 4 of the ladder for a web leaf, first half (spec §9.5, §9.6; v0-T258): the dependency policy. Every direct
# dependency is pinned to a minor line (x.y.z or ~x.y.z), the packages the policy names are locked at or above
# their minimum patched version, and the audit tools the policy names find nothing. The policy is
# config/deps-policy.json, baked beside this script where the agent cannot write; a policy file in the leaf is
# never read. The policy check reads package.json and package-lock.json and runs before any install. Run in the
# leaf's top folder.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
policy="$here/config/deps-policy.json"
"$here/web-protected.sh"
echo "== dependency policy"
node "$here/lib/webdeps.mjs" check "$policy"
# A clean install first: npm ci deletes node_modules, which the agent can write, so no tool it left there runs.
npm ci --ignore-scripts --no-audit --no-fund
for tool in $(node "$here/lib/webdeps.mjs" audit "$policy"); do
  case "$tool" in
    npm-audit)
      echo "== npm audit"
      npm audit --audit-level=high
      ;;
    osv)
      echo "== OSV"
      osv-scanner scan source -L package-lock.json
      ;;
  esac
done
```

**Change to `checks_test.go`**

```diff
diff --git a/checks_test.go b/checks_test.go
index d731800..325c2c0 100644
--- a/checks_test.go
+++ b/checks_test.go
@@ -392,5 +392,5 @@ func TestEveryWebRungRefusesAChangeToTheScriptsAndNpmrc(t *testing.T) {
 	start := map[string]string{".gitignore": "node_modules/\n.npmrc.local\n", "package.json": `{"scripts": {"lint": "eslint ."}}`, "contracts/api.openapi.yaml": "x",
 		"eslint.config.js": "export default [];\n", "tsconfig.json": "{}\n", "vite.config.ts": "export default {};\n", "playwright.config.ts": "export default {};\n", "src/a.ts": "export const a = 1;\n"}
-	rungs := []string{"web-static.sh", "web-unit.sh", "web-tdd.sh", "web-contract.sh", "web-security.sh", "web-e2e.sh"}
+	rungs := []string{"web-static.sh", "web-unit.sh", "web-tdd.sh", "web-contract.sh", "web-deps.sh", "web-security.sh", "web-e2e.sh"}
 	tools := map[string]string{"eslint": "", "tsc": "", "vite": "", "vitest": "", "prism": "", "playwright": ""}
 	for _, rung := range rungs {
@@ -472,6 +472,7 @@ func TestTheTemplatesToolConfigsAreTheBakedOnes(t *testing.T) {
 		t.Fatal(err)
 	}
-	if len(entries) != len(bakedConfigs) {
-		t.Errorf("devcontainer/checks/config has %d files, want the %d tool configs %v", len(entries), len(bakedConfigs), bakedConfigs)
+	// deps-policy.json is data for web-deps.sh, not a tool config (see deps_test.go).
+	if len(entries) != len(bakedConfigs)+1 {
+		t.Errorf("devcontainer/checks/config has %d files, want the %d tool configs %v and deps-policy.json", len(entries), len(bakedConfigs), bakedConfigs)
 	}
 	for _, name := range bakedConfigs {
```

**Change to `docs/architecture.md`**

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 2b3fa22..bac3307 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -38,6 +38,7 @@ change proposal `2026-10-17-realm-leaf-naming`).
   where its documents go; a test checks the examples in them against the schemas Odin reads.
 - `devcontainer/Containerfile` and `devcontainer/checks/`: the stack and the ladder's scripts. `web-static`,
-  `web-unit`, `web-tdd` (new tests fail on the commit the task started from), `web-contract`, `web-security`
-  and `web-e2e` (Playwright against the built app and a Prism mock of the contract) make the leaf's ladder.
+  `web-unit`, `web-tdd` (new tests fail on the commit the task started from), `web-contract`, `web-deps` (the
+  dependency policy of `config/deps-policy.json`: pinned minor lines, minimum patched versions, then the
+  audits the policy names), `web-security` and `web-e2e` (Playwright against the built app and a Prism mock of the contract) make the leaf's ladder.
   `accept-e2e` is the acceptance run: on a snapshot of the project it checks the API still keeps what the
   web app's copy of the contract promises (the copy may lag; the API may not break it), builds and starts
```

**Change to `pack.yaml`**

```diff
diff --git a/pack.yaml b/pack.yaml
index 13c923b..be1cc45 100644
--- a/pack.yaml
+++ b/pack.yaml
@@ -2,6 +2,6 @@
 # holds the graph of a web product (spec §4.2), the planning prompts and reviewers, and the recipe of a React
 # web leaf. A project that also needs a Go API pins helheim-go for that leaf. The check ladder is rungs 1 to
-# 5 of spec §9.5 in the task's loop; rung 6 is the three reviewers in the graph; the acceptance run is the
-# pointer move's, and rung 7 is the grader's.
+# 5 of spec §9.5 in the task's loop, with the dependency policy (deps) beside the security rung; rung 6 is the
+# three reviewers in the graph; the acceptance run is the pointer move's, and rung 7 is the grader's.
 name: midgard-react
 version: 0.1.0
@@ -12,4 +12,5 @@ checks:
   tdd: [/opt/ygg/checks/web-tdd.sh]
   contract: [/opt/ygg/checks/web-contract.sh]
+  deps: [/opt/ygg/checks/web-deps.sh]
   security: [/opt/ygg/checks/web-security.sh]
   e2e: [/opt/ygg/checks/web-e2e.sh]
@@ -20,5 +21,5 @@ leaf:
   first_commit: [LICENSE]
   implementer: prompts/implementer.md
-  checks: [static, unit, tdd, contract, security, e2e]
+  checks: [static, unit, tdd, contract, deps, security, e2e]
 sandbox:
   build: devcontainer
```

**Change to `pack_test.go`**

```diff
diff --git a/pack_test.go b/pack_test.go
index 496d3bf..1b7ece4 100644
--- a/pack_test.go
+++ b/pack_test.go
@@ -48,5 +48,5 @@ func TestThePackLoadsAsTheLeadRealmWithTwoStacksFromOneContext(t *testing.T) {
 		t.Errorf("stacks %q and %q; the leaf's and the acceptance sandbox's are two images of one context", web, acc)
 	}
-	want := []string{"static", "unit", "tdd", "contract", "security", "e2e"}
+	want := []string{"static", "unit", "tdd", "contract", "deps", "security", "e2e"}
 	if strings.Join(p.Leaf.Checks, ",") != strings.Join(want, ",") {
 		t.Errorf("the ladder is %v, want %v: cheap rungs first, the browser last", p.Leaf.Checks, want)
@@ -64,6 +64,6 @@ func TestThePackLoadsAsTheLeadRealmWithTwoStacksFromOneContext(t *testing.T) {
 	for _, e := range entries {
 		// docs.sh, web-protected.sh and web-configs.sh (sourced) are used by the web rungs; config/ holds the baked
-		// tool configs web-configs.sh installs.
-		used := e.Name() == "docs.sh" || e.Name() == "web-protected.sh" || e.Name() == "web-configs.sh" || e.Name() == "config"
+		// tool configs web-configs.sh installs and the policy web-deps.sh reads, and lib/ holds the checker it runs.
+		used := e.Name() == "docs.sh" || e.Name() == "web-protected.sh" || e.Name() == "web-configs.sh" || e.Name() == "config" || e.Name() == "lib"
 		for _, argv := range p.Checks {
 			used = used || filepath.Base(argv[0]) == e.Name()
```

**Change to `templates/web/AGENTS.md`**

```diff
diff --git a/templates/web/AGENTS.md b/templates/web/AGENTS.md
index 90804e4..c567577 100644
--- a/templates/web/AGENTS.md
+++ b/templates/web/AGENTS.md
@@ -13,5 +13,5 @@ This file only adds rules for this leaf. Read `docs/` for the design; this file
 - Stack: React, Vite, TypeScript (strict), Tailwind, shadcn/ui style components in `src/components/ui`,
   TanStack Router for pages and TanStack Query for data. Uploads use Uppy with presigned URLs.
-- Pin every dependency to an exact version and commit `package-lock.json`. A new dependency needs a reason
+- Pin every dependency to an exact version (`x.y.z`; `~x.y.z` also passes the factory) and commit `package-lock.json`. A new dependency needs a reason
   the standard library, the browser and what is here cannot give.
 
```

- [ ] **Step 6:** the task's ending, then commit in `midgard-react`.

```bash
gofmt -l . ; go vet ./... ; GOWORK=off go test -race ./...   # ok
git add checks_test.go docs/architecture.md pack.yaml pack_test.go templates/web/AGENTS.md deps_test.go \
  devcontainer/checks/config/deps-policy.json devcontainer/checks/lib/webdeps.mjs devcontainer/checks/web-deps.sh
git commit -m "feat(checks): dependency policy rung web-deps.sh with a baked deps-policy.json (v0-T258)" \
  -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**Evidence (run 2026-10-18, commit 2305a97 in the reference clone):** `go vet ./...` clean; `go test -count=1 ./...` ok (78 s), with the real `node` 26.3.0 and the real `npm`. The template test ran `npm ci` and `npm audit --audit-level=high` for real (292 packages, 0 vulnerabilities) and the hand run above is the real output. `shellcheck` is clean on `web-deps.sh`. **Not run:** `osv-scanner` is not installed here, so the template test and the hand run use a stand-in for it; the call is the one `web-security.sh` already makes. The image was not rebuilt: no Containerfile line changes (`COPY checks/` takes `lib/` and the policy). **Limit:** `npm audit` has `--audit-level=high`; `osv-scanner` fails on any finding (no severity filter), as in v0-T257. The audit calls repeat those of `web-security.sh`.

---

### Task v0-T259: `ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>...]`: the canary first, no rollout after a canary failure

Spec §9.6 says a version bump rolls to one canary product first, and does not roll out if the canary's suite fails. The dependency policy (v0-T257, v0-T258) says what a good dependency is. This task moves a dependency to a new version, and proves the move on one product before it touches another.

For each product the command does this, in this order. It reads the manifest (`go.mod` or `package.json`) and refuses a bump that goes down. It takes a snapshot of the product's files. It runs the ecosystem tool in the product's sandbox (`go get`, or `npm install`). It checks that only the manifest and its lock file changed, and that the manifest now names the new version. It runs the `deps` check, then the `unit` check, through the same check runner (`gleipnir/checks`) that the loop's ladder uses. On any failure it stops the sandbox, restores the snapshot byte for byte, and writes the `deps_bump` line with verdict `fail`. A canary failure ends the command: no rollout product is opened, read for change, or touched. A canary pass is written first (`deps_bump` stage `canary` verdict `pass`). Then each rollout product goes through the same steps, one at a time. The first rollout failure stops the command and restores that product only. The products that passed before it keep the new version. The command never writes a policy file.

**Files (in `odin`):**

- Create: `internal/deps/version.go`, `internal/deps/version_test.go`
- Create: `internal/deps/manifest.go`, `internal/deps/manifest_test.go`
- Create: `internal/deps/snapshot.go`, `internal/deps/snapshot_test.go`
- Create: `internal/deps/bump.go`, `internal/deps/bump_test.go`, `internal/deps/bump_more_test.go`, `internal/deps/bump_go_test.go`
- Create: `internal/cli/deps.go`, `internal/cli/deps_test.go`
- Modify: `internal/cli/cli.go` (usage, the command table, two fields of `flags`)

**Interfaces:**

- Consumes: `gleipnir/checks` (`Run`, `Spec`, `Result`), `gungnir.Runner`, `gungnir.Sandbox`, `gungnir.SandboxSpec`, `gungnir.Event` with `EventDepsBump` and `EventDepsChecked` (v0-T245), `internal/ledger`, `internal/lock` and `run.RunsLock`, `run.NewIDNow`, `internal/realm` (`Store`, `Load`), `internal/tree`.
- Produces: package `internal/deps`. `Bumper{Open Opener; Log func(gungnir.Event) error; LogDir string; Timeout time.Duration}` and `(*Bumper).Bump(ctx, pkg, version, canary Product, rollout []Product) (Report, error)`. `Opener` is the interface the tests fake: `Open(ctx, Product) (gungnir.Runner, stop func(ctx) error, error)`. `Product{Name, Dir, Realm, Checks}`. `Report{Steps []Step}` with `Failed()`. `*Refusal` for a bump refused before it changed anything. `Find(dir, pkg) (Manifest, error)`, `Manifest.Command`, `ParseVersion`, `Version.Compare`, `ValidPackage`, `Take(dir) (*Snapshot, error)`, `Snapshot.Changes`, `Snapshot.Restore`. In `internal/cli`: the command `ygg deps bump`, and the variable `newDepsSandbox`, which tests replace with a fake.
- The command line: `ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--project <dir>] [--config <factory.yaml>]`.

**Acceptance criteria:**

- [ ] `Find` reads a requirement from `go.mod` in the single-line form, in a `require (...)` block, and with `// indirect`. It reads `package.json` in `dependencies`, `devDependencies` and `optionalDependencies`. It refuses a pseudo-version, a `^` range, a tag, a URL, a package in neither file and a package in both.
- [ ] Versions order by semantic-version rules, with pre-releases before their release. A name that starts with `-`, holds `..`, a space or a shell sign is not a package name.
- [ ] A snapshot restores a changed file, a removed file, a created file and a created folder, a file mode and a symlink, byte for byte. It skips `.git` (also a `.git` file) and `node_modules`. It refuses a product over its size limit.
- [ ] A canary that passes both rungs is followed by each rollout product in order. The timeline of commands and ledger lines shows the canary's `deps_bump pass` line before the first command in a rollout product.
- [ ] A canary whose tool, `deps` check or `unit` check fails is restored byte for byte. No rollout product is opened, and no rollout line is written. Its sandbox is stopped.
- [ ] A rollout product that fails is restored. The products after it are never opened. The products before it keep the new version.
- [ ] A bump down, an equal canary, a pre-release, a bad package name, a missing package, a product named twice, and a realm without a `deps` or `unit` check are refused. Nothing is opened, logged or changed.
- [ ] A tool that also changes a policy file, or any file outside the manifest and its lock file, fails the product, and the file is put back. The ladder does not run.
- [ ] A cancel during a check puts the product back, stops its sandbox, and writes no verdict line.
- [ ] An npm bump keeps the tilde of the manifest and passes `--ignore-scripts`.
- [ ] With the real `go` and no network, a canary and a rollout product move to a compatible version. A canary whose build breaks on a newer version is restored, and the rollout product is not touched.
- [ ] `ygg deps bump` through the CLI: exit 0 with the change in both working copies and a verified ledger; exit 1 for a failed canary with all files as they were; exit 2 for each refusal, with no `.factory/deps` folder; in a project with a sandbox, one sandbox per product, with the stack, egress and git directory of the product, and every sandbox stopped.

**Review focus pinned by tests:**

- 1, a check an agent can weaken: a policy file, or any file that is not the manifest or its lock, that a tool changes fails the product and is put back (`TestAToolThatChangesAPolicyFileFailsTheProductAndTheFileIsPutBack`). The bump never reads a policy file of a product, and the realm's policy is baked (v0-T257).
- New line proposed for 5c: **a bump that goes on after a failure, or leaves a product half changed.** A canary failure stops the command and touches no rollout product (`TestACanaryThatFailsIsPutBackByteForByteAndNoRolloutProductIsTouched`, `TestDepsBumpPutsAFailedCanaryBackAndTouchesNoRolloutProduct`, and with the real `go`, `TestTheRealGoCanaryThatBreaksTheBuildIsPutBackAndTheRolloutProductIsNotTouched`). A rollout failure stops at that product (`TestARolloutStopsAtTheFirstFailureAndPutsBackOnlyThatProduct`). A cancel restores (`TestACancelledBumpPutsTheProductBackAndStopsItsSandbox`). A product is restored byte for byte (`TestSnapshotRestoresChangedRemovedAndCreatedFilesByteForByte`).
- New line proposed for 5c: **a bump that goes down, or a name the tool reads as an option.** `TestARefusalChangesNothingAndOpensNothing`, `TestValidPackageRefusesAnOptionAndAPathEscape`, `TestDepsBumpRefusalsExitTwoAndLeaveNoTrace`.
- 4, a sandbox that carries more than it should: the bump starts one sandbox per product, and it is the product's own leaf, git directory and stack (`TestDepsBumpRunsToolAndChecksInTheSandboxOfEachLeafAndStopsIt`).

**Named test:** `go test ./internal/deps ./internal/cli -run 'Deps|Bump|Snapshot|Version|Find|Package|Refusal|Canary|Rollout|Real'` in `odin`. **Layer:** `odin`. **Size:** L, in six commits. **Depends on:** v0-T245 (the events), v0-T257 and v0-T258 (the `deps` check exists in the realms; the tests here use toy realms and do not need them).

#### Part 1: versions and manifests

- [ ] **Step 1:** create the package folder, and write the two test files first.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/odin
mkdir -p internal/deps
```

Create `internal/deps/version_test.go` and `internal/deps/manifest_test.go` as shown below. `manifest_test.go` also holds `write`, a helper that the later tests use.

- [ ] **Step 2:** run the tests and see the build fail.

```bash
go test -count=1 ./internal/deps 2>&1 | head -8
```

Expected: `FAIL` with a build error. The output has `./manifest_test.go:39:13: undefined: Find` and lines for `Go`, `Version`, `Manifest` and `NPM`.

- [ ] **Step 3:** create `version.go` and `manifest.go`.
- [ ] **Step 4:** run the tests.

```bash
gofmt -l internal/deps && go vet ./internal/deps && go test -count=1 -race ./internal/deps
```

Expected: `ok  github.com/ouroboric-dev/odin/internal/deps`.

- [ ] **Step 5:** commit.

```bash
git add internal/deps/version.go internal/deps/version_test.go internal/deps/manifest.go internal/deps/manifest_test.go
git commit -m "deps part 1: read the version a product requires (go.mod or package.json), order versions, refuse a name the tool would read as an option (v0-T259)" \
  -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**New file `internal/deps/version.go`**

```go
// Package deps bumps one dependency across the products of a project (spec §9.6): the canary product
// first, then the rest, one at a time. A bump that fails a product's ladder checks is undone in that
// product, byte for byte, and goes no further.
package deps

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

var versionRE = regexp.MustCompile(`^v?(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})(?:-([0-9A-Za-z][0-9A-Za-z.-]*))?(?:\+[0-9A-Za-z.-]+)?$`)

// Version is a semantic version, such as 1.4.2 or 1.4.2-rc.1. Build metadata is dropped.
type Version struct {
	Major, Minor, Patch int
	Pre                 string
}

// ParseVersion reads x.y.z, with an optional leading v, a pre-release and build metadata.
func ParseVersion(s string) (Version, error) {
	m := versionRE.FindStringSubmatch(s)
	if m == nil {
		return Version{}, fmt.Errorf("%q is not a version of the form x.y.z", s)
	}
	n := func(i int) int { v, _ := strconv.Atoi(m[i]); return v }
	return Version{Major: n(1), Minor: n(2), Patch: n(3), Pre: m[4]}, nil
}

func (v Version) String() string {
	s := fmt.Sprintf("%d.%d.%d", v.Major, v.Minor, v.Patch)
	if v.Pre != "" {
		s += "-" + v.Pre
	}
	return s
}

// Compare returns -1, 0 or 1 as v is before, equal to or after o. A pre-release is before its release.
func (v Version) Compare(o Version) int {
	for _, p := range [][2]int{{v.Major, o.Major}, {v.Minor, o.Minor}, {v.Patch, o.Patch}} {
		if c := cmpInt(p[0], p[1]); c != 0 {
			return c
		}
	}
	switch {
	case v.Pre == o.Pre:
		return 0
	case v.Pre == "":
		return 1
	case o.Pre == "":
		return -1
	}
	a, b := strings.Split(v.Pre, "."), strings.Split(o.Pre, ".")
	for i := 0; i < len(a) && i < len(b); i++ {
		if c := cmpIdent(a[i], b[i]); c != 0 {
			return c
		}
	}
	return cmpInt(len(a), len(b))
}

// cmpIdent orders two pre-release identifiers: numbers by value and before words, words as text.
func cmpIdent(a, b string) int {
	x, ea := strconv.Atoi(a)
	y, eb := strconv.Atoi(b)
	switch {
	case ea == nil && eb == nil:
		return cmpInt(x, y)
	case ea == nil:
		return -1
	case eb == nil:
		return 1
	}
	return strings.Compare(a, b)
}

func cmpInt(a, b int) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	}
	return 0
}

var packageRE = regexp.MustCompile(`^(@[a-z0-9][a-z0-9._~-]*/)?[A-Za-z0-9][A-Za-z0-9._~/-]*$`)

// ValidPackage reports whether name can be a Go module path or an npm package name. It refuses a name
// that starts with "-" (an option for the tool), and "..".
func ValidPackage(name string) bool {
	return packageRE.MatchString(name) && !strings.Contains(name, "..") && len(name) <= 214
}
```

**New file `internal/deps/manifest.go`**

```go
package deps

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

// Kind is the ecosystem of a manifest.
type Kind string

const (
	Go  Kind = "go"  // go.mod
	NPM Kind = "npm" // package.json
)

// Manifest is where a product requires a package.
type Manifest struct {
	Kind    Kind
	Path    string  // the manifest file
	Current Version // the version it requires now
	Tilde   bool    // npm: the requirement is written ~x.y.z, so the bump keeps the tilde
}

// Files are the files, relative to the manifest's folder, that the ecosystem tool may change.
func (k Kind) Files() []string {
	if k == Go {
		return []string{"go.mod", "go.sum"}
	}
	return []string{"package.json", "package-lock.json", "npm-shrinkwrap.json"}
}

// Command is the ecosystem tool's command that moves pkg to version to. The command takes no shell. npm
// runs no install script, and keeps the pin style the manifest has: exact, or a tilde.
func (m Manifest) Command(pkg string, to Version) []string {
	if m.Kind == Go {
		return []string{"go", "get", pkg + "@v" + to.String()}
	}
	style := "--save-exact"
	if m.Tilde {
		style = "--save-prefix=~"
	}
	return []string{"npm", "install", "--ignore-scripts", style, pkg + "@" + to.String()}
}

// Find reads the manifest of the product in dir that requires pkg. A package that no manifest requires,
// that both manifests require, or whose version it can't read (a range, a URL, a tag) is an error: a
// bump never adds a package and never guesses.
func Find(dir, pkg string) (Manifest, error) {
	var found []Manifest
	for _, read := range []func(string, string) (Manifest, bool, error){readGoMod, readPackageJSON} {
		m, ok, err := read(dir, pkg)
		if err != nil {
			return Manifest{}, err
		}
		if ok {
			found = append(found, m)
		}
	}
	switch len(found) {
	case 0:
		return Manifest{}, fmt.Errorf("%s requires no package %s in its go.mod or package.json", dir, pkg)
	case 1:
		return found[0], nil
	}
	return Manifest{}, fmt.Errorf("%s requires %s in both go.mod and package.json; the bump will not guess", dir, pkg)
}

func readGoMod(dir, pkg string) (Manifest, bool, error) {
	path := filepath.Join(dir, "go.mod")
	b, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return Manifest{}, false, nil
	} else if err != nil {
		return Manifest{}, false, err
	}
	in := false
	for _, line := range strings.Split(string(b), "\n") {
		if i := strings.Index(line, "//"); i >= 0 {
			line = line[:i]
		}
		f := strings.Fields(line)
		switch {
		case len(f) == 2 && f[0] == "require" && f[1] == "(":
			in = true
			continue
		case in && len(f) == 1 && f[0] == ")":
			in = false
			continue
		case len(f) == 3 && f[0] == "require" && !in:
			f = f[1:]
		case !in || len(f) != 2:
			continue
		}
		if f[0] != pkg {
			continue
		}
		v, err := ParseVersion(f[1])
		if err != nil || v.Pre != "" {
			return Manifest{}, false, fmt.Errorf("%s requires %s %s: that is not a tagged release, so the bump will not guess", path, pkg, f[1])
		}
		return Manifest{Kind: Go, Path: path, Current: v}, true, nil
	}
	return Manifest{}, false, nil
}

func readPackageJSON(dir, pkg string) (Manifest, bool, error) {
	path := filepath.Join(dir, "package.json")
	b, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return Manifest{}, false, nil
	} else if err != nil {
		return Manifest{}, false, err
	}
	var doc struct {
		Dependencies, DevDependencies, OptionalDependencies map[string]string
	}
	if err := json.Unmarshal(b, &doc); err != nil {
		return Manifest{}, false, fmt.Errorf("%s: %w", path, err)
	}
	for _, section := range []map[string]string{doc.Dependencies, doc.DevDependencies, doc.OptionalDependencies} {
		spec, ok := section[pkg]
		if !ok {
			continue
		}
		tilde := strings.HasPrefix(spec, "~")
		v, err := ParseVersion(strings.TrimLeft(spec, "~=v"))
		if err != nil || v.Pre != "" || strings.HasPrefix(spec, "^") {
			return Manifest{}, false, fmt.Errorf("%s requires %s as %q: the policy pins x.y.z or ~x.y.z, so the bump will not guess", path, pkg, spec)
		}
		return Manifest{Kind: NPM, Path: path, Current: v, Tilde: tilde}, true, nil
	}
	return Manifest{}, false, nil
}
```

**New file `internal/deps/version_test.go`**

```go
package deps

import "testing"

func TestVersionOrder(t *testing.T) {
	order := []string{"0.9.9", "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0", "1.0.1", "1.2.0", "2.0.0"}
	for i, a := range order {
		for j, b := range order {
			va, err := ParseVersion(a)
			vb, err2 := ParseVersion(b)
			if err != nil || err2 != nil {
				t.Fatal(err, err2)
			}
			want := cmpInt(i, j)
			if got := va.Compare(vb); got != want {
				t.Errorf("Compare(%s, %s) = %d, want %d", a, b, got, want)
			}
		}
	}
}

func TestParseVersionReadsGoAndNpmForms(t *testing.T) {
	for in, want := range map[string]string{"v1.2.3": "1.2.3", "1.2.3": "1.2.3", "v0.42.0": "0.42.0", "1.2.3-rc.1+build.5": "1.2.3-rc.1"} {
		if v, err := ParseVersion(in); err != nil || v.String() != want {
			t.Errorf("ParseVersion(%q) = %v, %v; want %s", in, v, err, want)
		}
	}
	for _, bad := range []string{"", "1.2", "latest", "^1.2.3", "v01.2.3", "1.2.3.4", "1.2.3-", "1.2.x"} {
		if _, err := ParseVersion(bad); err == nil {
			t.Errorf("ParseVersion(%q) passed", bad)
		}
	}
}

func TestValidPackageRefusesAnOptionAndAPathEscape(t *testing.T) {
	for _, ok := range []string{"golang.org/x/text", "vite", "@tanstack/react-query", "github.com/Foo/bar"} {
		if !ValidPackage(ok) {
			t.Errorf("%q refused", ok)
		}
	}
	for _, bad := range []string{"", "-g", "--registry=http://x", "a/../b", "a b", "a;b", "$(x)", "@/x"} {
		if ValidPackage(bad) {
			t.Errorf("%q passed", bad)
		}
	}
}
```

**New file `internal/deps/manifest_test.go`**

```go
package deps

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func write(t *testing.T, dir, name, text string) {
	t.Helper()
	p := filepath.Join(dir, name)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
}

const goMod = `module example.invalid/app

go 1.26

require example.invalid/single v1.4.2

require (
	golang.org/x/text v0.41.0 // indirect
	example.invalid/dep v2.0.1
)

replace example.invalid/gone => ../gone
`

func TestFindReadsGoModInEveryFormOfRequire(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "go.mod", goMod)
	for pkg, want := range map[string]string{"example.invalid/single": "1.4.2", "golang.org/x/text": "0.41.0", "example.invalid/dep": "2.0.1"} {
		m, err := Find(dir, pkg)
		if err != nil || m.Kind != Go || m.Current.String() != want || m.Path != filepath.Join(dir, "go.mod") {
			t.Errorf("Find(%s) = %+v, %v; want go %s", pkg, m, err, want)
		}
	}
	if cmd := mustFind(t, dir, "golang.org/x/text").Command("golang.org/x/text", Version{Major: 0, Minor: 42, Patch: 0}); strings.Join(cmd, " ") != "go get golang.org/x/text@v0.42.0" {
		t.Errorf("command %v", cmd)
	}
}

func mustFind(t *testing.T, dir, pkg string) Manifest {
	t.Helper()
	m, err := Find(dir, pkg)
	if err != nil {
		t.Fatal(err)
	}
	return m
}

func TestFindReadsPackageJSONAndKeepsTheTilde(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "package.json", `{"dependencies":{"vite":"7.1.2","react":"~19.1.0"},"devDependencies":{"vitest":"3.2.4"}}`)
	to := Version{Major: 7, Minor: 1, Patch: 9}
	if m := mustFind(t, dir, "vite"); m.Kind != NPM || m.Tilde || strings.Join(m.Command("vite", to), " ") != "npm install --ignore-scripts --save-exact vite@7.1.9" {
		t.Errorf("vite: %+v %v", m, m.Command("vite", to))
	}
	if m := mustFind(t, dir, "react"); !m.Tilde || m.Current.String() != "19.1.0" || strings.Join(m.Command("react", to), " ") != "npm install --ignore-scripts --save-prefix=~ react@7.1.9" {
		t.Errorf("react: %+v %v", m, m.Command("react", to))
	}
	if m := mustFind(t, dir, "vitest"); m.Current.String() != "3.2.4" {
		t.Errorf("vitest: %+v", m)
	}
}

func TestFindRefusesWhatItWouldHaveToGuess(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "go.mod", "module m\n\ngo 1.26\n\nrequire (\n\texample.invalid/pseudo v0.0.0-20261017195515-cb1dc0ee9cc6\n\texample.invalid/both v1.0.0\n)\n")
	write(t, dir, "package.json", `{"dependencies":{"caret":"^1.2.3","tag":"latest","url":"git+https://x/y.git","example.invalid/both":"1.0.0"}}`)
	for pkg, want := range map[string]string{
		"missing":                "requires no package",
		"example.invalid/pseudo": "not a tagged release",
		"caret":                  "pins x.y.z or ~x.y.z",
		"tag":                    "pins x.y.z or ~x.y.z",
		"url":                    "pins x.y.z or ~x.y.z",
		"example.invalid/both":   "both go.mod and package.json",
	} {
		if _, err := Find(dir, pkg); err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("Find(%s) = %v, want %q", pkg, err, want)
		}
	}
}
```

#### Part 2: the snapshot

A snapshot is how a failed bump gets back. It reads every file of the product into memory, with the mode and the target of each symlink. `Changes` says which files differ now. `Restore` writes the old bytes back, removes the files the tool created, and removes the folders it created when they are empty. A walk that meets a skipped file (a `.git` file in a leaf is one) must not return `SkipDir`: that would skip the other files of the folder. The first version of the code did, and `TestSnapshotRestoresChangedRemovedAndCreatedFilesByteForByte` found it, because its fixture has a `.git` file. The code below is the fixed one (`skip`).

- [ ] **Step 1:** write `snapshot_test.go` (below). **Step 2:** run `go test -count=1 ./internal/deps 2>&1 | head -4` and see `undefined: takeLimited`. **Step 3:** create `snapshot.go`. **Step 4:** run the tests, **Step 5:** commit.

```bash
gofmt -l internal/deps && go vet ./internal/deps && go test -count=1 -race ./internal/deps
git add internal/deps/snapshot.go internal/deps/snapshot_test.go
git commit -m "deps part 2: a snapshot of a product that a failed bump restores byte for byte (v0-T259)" \
  -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

Expected: `ok  github.com/ouroboric-dev/odin/internal/deps`.

**New file `internal/deps/snapshot.go`**

```go
package deps

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"
)

// MaxSnapshot is the most bytes of files a snapshot keeps. A product bigger than this is refused: the
// bump could not undo a failure.
const MaxSnapshot int64 = 256 << 20

type entry struct {
	mode fs.FileMode
	data []byte
	link string // a symlink's target
}

// Snapshot holds the files of a product as they were, so that a failed bump can put them back byte for
// byte. It skips .git (the leaf's git directory is the leaf's own, and the bump never writes to it) and
// node_modules (a cache npm rebuilds from the lock file).
type Snapshot struct {
	root  string
	files map[string]entry
	dirs  map[string]bool
}

func skipped(rel string, d fs.DirEntry) bool {
	n := d.Name()
	return rel != "." && (n == ".git" || (n == "node_modules" && d.IsDir()))
}

// skip is what a walk returns for an entry it skips: SkipDir on a file would skip its folder's other files.
func skip(d fs.DirEntry) error {
	if d.IsDir() {
		return fs.SkipDir
	}
	return nil
}

// Take reads every file of the product in root.
func Take(root string) (*Snapshot, error) { return takeLimited(root, MaxSnapshot) }

func takeLimited(root string, limit int64) (*Snapshot, error) {
	s := &Snapshot{root: root, files: map[string]entry{}, dirs: map[string]bool{}}
	var size int64
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(root, p)
		switch {
		case skipped(rel, d):
			return skip(d)
		case d.IsDir():
			s.dirs[rel] = true
			return nil
		}
		e, n, err := read(p, d)
		if err != nil {
			return err
		}
		if size += n; size > limit {
			return fmt.Errorf("%s holds too many bytes of files: too big to snapshot, so a failed bump could not be undone", root)
		}
		s.files[rel] = e
		return nil
	})
	return s, err
}

func read(p string, d fs.DirEntry) (entry, int64, error) {
	info, err := d.Info()
	if err != nil {
		return entry{}, 0, err
	}
	switch {
	case info.Mode()&fs.ModeSymlink != 0:
		l, err := os.Readlink(p)
		return entry{mode: info.Mode(), link: l}, 0, err
	case info.Mode().IsRegular():
		b, err := os.ReadFile(p)
		return entry{mode: info.Mode().Perm(), data: b}, int64(len(b)), err
	}
	return entry{}, 0, fmt.Errorf("%s is neither a file, a folder nor a symlink", p)
}

// Changes lists the files, relative to the product, that differ from the snapshot: changed, created or
// removed. The list is sorted.
func (s *Snapshot) Changes() ([]string, error) {
	var out []string
	seen := map[string]bool{}
	err := filepath.WalkDir(s.root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(s.root, p)
		switch {
		case skipped(rel, d):
			return skip(d)
		case d.IsDir():
			return nil
		}
		seen[rel] = true
		cur, _, err := read(p, d)
		if err != nil {
			return err
		}
		if want, ok := s.files[rel]; !ok || !same(want, cur) {
			out = append(out, rel)
		}
		return nil
	})
	for rel := range s.files {
		if !seen[rel] {
			out = append(out, rel)
		}
	}
	sort.Strings(out)
	return out, err
}

func same(a, b entry) bool {
	return a.mode == b.mode && a.link == b.link && bytes.Equal(a.data, b.data)
}

// Restore puts the product back as the snapshot was: it rewrites changed files and the ones removed, and
// removes the files and the empty folders that were created. File times are not restored.
func (s *Snapshot) Restore() error {
	var extra, extraDirs []string
	err := filepath.WalkDir(s.root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(s.root, p)
		switch {
		case skipped(rel, d):
			return skip(d)
		case d.IsDir():
			if !s.dirs[rel] {
				extraDirs = append(extraDirs, rel)
			}
			return nil
		}
		if _, ok := s.files[rel]; !ok {
			extra = append(extra, rel)
		}
		return nil
	})
	if err != nil {
		return err
	}
	for _, rel := range extra {
		if err := os.Remove(filepath.Join(s.root, rel)); err != nil {
			return err
		}
	}
	for rel, want := range s.files {
		p := filepath.Join(s.root, rel)
		if info, err := os.Lstat(p); err == nil {
			if cur, _, err := read(p, fs.FileInfoToDirEntry(info)); err == nil && same(want, cur) {
				continue
			}
			if err := os.RemoveAll(p); err != nil {
				return err
			}
		} else if !errors.Is(err, fs.ErrNotExist) {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			return err
		}
		if want.link != "" {
			err = os.Symlink(want.link, p)
		} else if err = os.WriteFile(p, want.data, want.mode); err == nil {
			err = os.Chmod(p, want.mode)
		}
		if err != nil {
			return err
		}
	}
	slices.SortFunc(extraDirs, func(a, b string) int { return strings.Compare(b, a) }) // the deepest first
	for _, rel := range extraDirs {
		os.Remove(filepath.Join(s.root, rel)) // a folder that still holds something is not ours to remove
	}
	return nil
}
```

**New file `internal/deps/snapshot_test.go`**

```go
package deps

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestSnapshotRestoresChangedRemovedAndCreatedFilesByteForByte(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "go.mod", "module m\r\n\x00binary\xff")
	write(t, dir, "go.sum", "sum\n")
	write(t, dir, "src/a.go", "package a\n")
	write(t, dir, "devcontainer/checks/config/deps-policy.json", `{"schema":"ygg.deps/v1"}`)
	write(t, dir, "node_modules/x/index.js", "cache")
	write(t, dir, ".git", "gitdir: ../x")
	if err := os.Chmod(filepath.Join(dir, "src/a.go"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink("src/a.go", filepath.Join(dir, "link")); err != nil {
		t.Fatal(err)
	}
	snap, err := Take(dir)
	if err != nil {
		t.Fatal(err)
	}
	if ch, err := snap.Changes(); err != nil || len(ch) != 0 {
		t.Fatalf("changes of an untouched product: %v, %v", ch, err)
	}
	write(t, dir, "go.mod", "changed")
	os.Remove(filepath.Join(dir, "go.sum"))
	write(t, dir, "package-lock.json", "{}")
	write(t, dir, "new/deep/file", "x")
	write(t, dir, "devcontainer/checks/config/deps-policy.json", `{"schema":"weakened"}`)
	os.Chmod(filepath.Join(dir, "src/a.go"), 0o600)
	os.Remove(filepath.Join(dir, "link"))
	write(t, dir, "node_modules/x/index.js", "changed cache, not counted")
	want := []string{"devcontainer/checks/config/deps-policy.json", "go.mod", "go.sum", "link", "new/deep/file", "package-lock.json", "src/a.go"}
	if ch, err := snap.Changes(); err != nil || !reflect.DeepEqual(ch, want) {
		t.Fatalf("changes = %v, %v; want %v", ch, err, want)
	}
	if err := snap.Restore(); err != nil {
		t.Fatal(err)
	}
	if ch, _ := snap.Changes(); len(ch) != 0 {
		t.Errorf("still changed after restore: %v", ch)
	}
	if b, _ := os.ReadFile(filepath.Join(dir, "go.mod")); string(b) != "module m\r\n\x00binary\xff" {
		t.Errorf("go.mod = %q", b)
	}
	if _, err := os.Stat(filepath.Join(dir, "new")); !os.IsNotExist(err) {
		t.Errorf("the folder the tool created is still there: %v", err)
	}
	if l, err := os.Readlink(filepath.Join(dir, "link")); err != nil || l != "src/a.go" {
		t.Errorf("symlink = %q, %v", l, err)
	}
	if info, _ := os.Stat(filepath.Join(dir, "src/a.go")); info.Mode().Perm() != 0o755 {
		t.Errorf("mode = %v", info.Mode())
	}
}

func TestSnapshotRefusesAProductTooBigToUndo(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "f", "x")
	if _, err := takeLimited(dir, 0); err == nil { // one byte is over a limit of none
		t.Error("a snapshot over the limit was taken")
	}
}
```

#### Part 3: `Bump`

`Bump` is in two halves. `plan` checks everything that can be checked before a file changes, and gives a `*Refusal` if a check fails. `stage` does one product: snapshot, open the runner, `apply`, stop the runner, then restore if `apply` failed or errored. The restore comes after the stop, because a container that still runs could write after the restore. A restore and a stop use a context that a cancel does not end (`context.WithoutCancel`). A failed verdict is not an error: it is a `Step` with verdict `fail`, and the loop in `Bump` writes it and stops. An error (the sandbox, a log file, a cancel) also restores the product, and ends the command without a verdict line.

`apply` runs the tool as a check named `bump` through `checks.Run`, so its output has a log and a timeout like any check. The test file `bump_test.go` holds the fake world: a fake `Opener` and `gungnir.Runner` that stand for the sandbox and the tools, a timeline of commands and ledger lines in order, and a map of exit codes by product and check.

- [ ] **Step 1:** write `bump_test.go` (below). **Step 2:** move `bump.go` aside, or just run the tests before it exists.

```bash
go test -count=1 ./internal/deps 2>&1 | head -6
```

Expected: `FAIL` with `internal/deps/bump_test.go:48:38: undefined: Product`, `undefined: Bumper` and more.

- [ ] **Step 3:** create `bump.go`. **Step 4:** run the tests. **Step 5:** commit.

```bash
gofmt -l internal/deps && go vet ./internal/deps && go test -count=1 -race ./internal/deps
git add internal/deps/bump.go internal/deps/bump_test.go
git commit -m "deps part 3: Bump moves a package in the canary, runs the deps and unit rungs, and puts the canary back byte for byte when one fails (v0-T259)" \
  -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

Expected: `ok  github.com/ouroboric-dev/odin/internal/deps`.

**New file `internal/deps/bump_test.go`**

```go
package deps

import (
	"context"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

const policyJSON = `{"schema":"ygg.deps/v1","pin":"minor","minimum":{"golang.org/x/text":"0.42.0"},"audit":["govulncheck","osv"]}`

func goModAt(v string) string {
	return "module example.invalid/app\r\n\r\ngo 1.26\r\n\r\nrequire golang.org/x/text v" + v + "\r\n"
}

// world is a project of products, a fake that stands for the sandbox and the tools in it, and a timeline of
// what happened, in order, across commands and ledger lines.
type world struct {
	t        *testing.T
	root     string
	timeline []string
	events   []gungnir.Event
	opened   []string
	stopped  []string
	// fail maps "product:check" (check is bump, deps or unit) to an exit code.
	fail map[string]int
	// also is an extra change the tool makes in a product, besides the manifest: file, then text.
	also map[string][2]string
	// onRun, if set, sees each command before it is answered.
	onRun func(product, check string) error
}

func newWorld(t *testing.T, versions map[string]string) *world {
	w := &world{t: t, root: t.TempDir(), fail: map[string]int{}, also: map[string][2]string{}}
	for name, v := range versions {
		write(t, filepath.Join(w.root, name), "go.mod", goModAt(v))
		write(t, filepath.Join(w.root, name), "go.sum", "golang.org/x/text v"+v+" h1:aaa=\r\n")
		write(t, filepath.Join(w.root, name), "main.go", "package main\n")
		write(t, filepath.Join(w.root, name), "devcontainer/checks/config/deps-policy.json", policyJSON)
	}
	return w
}

func (w *world) product(name string) Product {
	return Product{Name: name, Dir: filepath.Join(w.root, name), Realm: "helheim-go", Checks: map[string][]string{
		"deps": {"/opt/ygg/checks/go-deps.sh"}, "unit": {"/opt/ygg/checks/go-unit.sh"}, "static": {"/opt/ygg/checks/go-static.sh"}}}
}

func (w *world) bumper() *Bumper {
	return &Bumper{Open: w, LogDir: filepath.Join(w.root, "logs"), Log: func(e gungnir.Event) error {
		w.events = append(w.events, e)
		w.timeline = append(w.timeline, "event "+string(e.Name)+" "+e.Stage+" "+e.Verdict)
		return nil
	}}
}

func (w *world) Open(_ context.Context, p Product) (gungnir.Runner, func(context.Context) error, error) {
	w.opened = append(w.opened, p.Name)
	return fakeRunner{w, p}, func(context.Context) error { w.stopped = append(w.stopped, p.Name); return nil }, nil
}

type fakeRunner struct {
	w *world
	p Product
}

var toolVersion = regexp.MustCompile(`@v?([0-9][^ ]*)$`)

func (f fakeRunner) Run(_ context.Context, c gungnir.Cmd) (gungnir.ExecResult, error) {
	w, p := f.w, f.p
	check := "bump"
	switch {
	case strings.HasSuffix(c.Argv[0], "go-deps.sh"):
		check = "deps"
	case strings.HasSuffix(c.Argv[0], "go-unit.sh"):
		check = "unit"
	}
	w.timeline = append(w.timeline, p.Name+" "+check)
	if w.onRun != nil {
		if err := w.onRun(p.Name, check); err != nil {
			return gungnir.ExecResult{}, err
		}
	}
	if code := w.fail[p.Name+":"+check]; code != 0 {
		c.Stdout.Write([]byte(check + " says no\n"))
		return gungnir.ExecResult{ExitCode: code}, nil
	}
	if check == "bump" { // what go get does: the version in go.mod and go.sum
		v := toolVersion.FindStringSubmatch(c.Argv[len(c.Argv)-1])[1]
		write(w.t, p.Dir, "go.mod", goModAt(v))
		write(w.t, p.Dir, "go.sum", "golang.org/x/text v"+v+" h1:bbb=\r\n")
		if x, ok := w.also[p.Name]; ok {
			write(w.t, p.Dir, x[0], x[1])
		}
	}
	return gungnir.ExecResult{}, nil
}

// bytes reads every file of a product, so a test can say "as it was".
func (w *world) bytes(name string) map[string]string {
	out := map[string]string{}
	filepath.WalkDir(filepath.Join(w.root, name), func(p string, d os.DirEntry, _ error) error {
		if !d.IsDir() {
			b, _ := os.ReadFile(p)
			out[p] = string(b)
		}
		return nil
	})
	return out
}

func same2(a, b map[string]string) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		if w, ok := b[k]; !ok || w != v {
			return false
		}
	}
	return true
}

func (w *world) eventLines() []string {
	var out []string
	for _, e := range w.events {
		out = append(out, string(e.Name)+" "+e.Stage+" "+e.Verdict+" "+e.Package+" "+e.From+">"+e.To)
	}
	return out
}

func (w *world) has(name string) string {
	b, _ := os.ReadFile(filepath.Join(w.root, name, "go.mod"))
	return string(b)
}

func TestACanaryThatPassesRollsOutOneProductAtATime(t *testing.T) {
	w := newWorld(t, map[string]string{"api": "0.41.0", "api2": "0.41.0", "api3": "0.40.0"})
	rep, err := w.bumper().Bump(context.Background(), "golang.org/x/text", "0.42.0", w.product("api"), []Product{w.product("api2"), w.product("api3")})
	if err != nil || rep.Failed() || len(rep.Steps) != 3 {
		t.Fatalf("report %+v, error %v", rep, err)
	}
	want := []string{
		"api bump", "api deps", "event deps_checked  pass", "api unit", "event deps_bump canary pass",
		"api2 bump", "api2 deps", "event deps_checked  pass", "api2 unit", "event deps_bump rollout pass",
		"api3 bump", "api3 deps", "event deps_checked  pass", "api3 unit", "event deps_bump rollout pass",
	}
	if got := strings.Join(w.timeline, "|"); got != strings.Join(want, "|") {
		t.Errorf("timeline\n got %s\nwant %s", got, strings.Join(want, "|"))
	}
	for _, n := range []string{"api", "api2", "api3"} {
		if !strings.Contains(w.has(n), "v0.42.0") {
			t.Errorf("%s: %q", n, w.has(n))
		}
	}
	if w.events[1].From != "0.41.0" || w.events[1].To != "0.42.0" || w.events[1].Package != "golang.org/x/text" || w.events[len(w.events)-1].From != "0.40.0" {
		t.Errorf("events: %v", w.eventLines())
	}
	if strings.Join(w.stopped, ",") != "api,api2,api3" {
		t.Errorf("stopped %v", w.stopped)
	}
}

func TestACanaryThatFailsIsPutBackByteForByteAndNoRolloutProductIsTouched(t *testing.T) {
	for _, bad := range []string{"api:bump", "api:deps", "api:unit"} {
		w := newWorld(t, map[string]string{"api": "0.41.0", "api2": "0.41.0"})
		w.fail[bad] = 1
		beforeCanary, beforeRollout := w.bytes("api"), w.bytes("api2")
		rep, err := w.bumper().Bump(context.Background(), "golang.org/x/text", "0.42.0", w.product("api"), []Product{w.product("api2")})
		if err != nil || !rep.Failed() || len(rep.Steps) != 1 || rep.Steps[0].Stage != "canary" {
			t.Fatalf("%s: report %+v, error %v", bad, rep, err)
		}
		if !same2(beforeCanary, w.bytes("api")) {
			t.Errorf("%s: the canary is not as it was", bad)
		}
		if !same2(beforeRollout, w.bytes("api2")) || strings.Join(w.opened, ",") != "api" {
			t.Errorf("%s: a rollout product was touched or opened: %v", bad, w.opened)
		}
		last := w.events[len(w.events)-1]
		if last.Name != gungnir.EventDepsBump || last.Stage != "canary" || last.Verdict != "fail" || !strings.Contains(last.Note, "api") {
			t.Errorf("%s: last event %+v", bad, last)
		}
		for _, e := range w.events {
			if e.Stage == "rollout" {
				t.Errorf("%s: a rollout event: %+v", bad, e)
			}
		}
		if strings.Join(w.stopped, ",") != "api" {
			t.Errorf("%s: the canary's sandbox was not stopped: %v", bad, w.stopped)
		}
	}
}
```

**New file `internal/deps/bump.go`**

```go
package deps

import (
	"context"
	"errors"
	"fmt"
	"path/filepath"
	"slices"
	"strings"
	"time"

	"github.com/ouroboric-dev/gleipnir/checks"
	"github.com/ouroboric-dev/gungnir"
)

// Ladder is the checks a bump runs in a product, in this order: the dependency policy, then the unit
// tests. Both are checks of the product's realm, run by the same check runner as a loop's ladder.
var Ladder = []string{"deps", "unit"}

// DefaultTimeout is how long one command of a bump may run.
const DefaultTimeout = 30 * time.Minute

// Product is one leaf a bump may change.
type Product struct {
	Name   string              // its path from the project, such as repos/api
	Dir    string              // its working copy, absolute
	Realm  string              // the realm that provides it
	Checks map[string][]string // that realm's checks: name, then the command
}

// Opener starts what runs a product's commands, and returns the function that stops it. In a project
// with a sandbox this is the product's sandbox: the tool and the checks run where an agent's would.
type Opener interface {
	Open(ctx context.Context, p Product) (gungnir.Runner, func(context.Context) error, error)
}

// Step is how the bump went in one product.
type Step struct {
	Product string
	Stage   string // canary or rollout
	From    string
	To      string
	Verdict string // pass, fail, or skip: the product has the version already
	Reason  string
}

// Report is what a bump did. A bump that failed a product is a Report with Failed true, not an error.
type Report struct{ Steps []Step }

// Failed reports whether a product failed its ladder, so the bump stopped.
func (r Report) Failed() bool {
	return len(r.Steps) > 0 && r.Steps[len(r.Steps)-1].Verdict == "fail"
}

// Refusal is a bump that was refused before it touched anything.
type Refusal struct{ Reason string }

func (r *Refusal) Error() string { return r.Reason }

// Bumper bumps a package.
type Bumper struct {
	Open    Opener
	Log     func(gungnir.Event) error // the ledger of the bump
	LogDir  string                    // where the output of each command is kept
	Timeout time.Duration             // zero is DefaultTimeout
}

type plan struct {
	p     Product
	m     Manifest
	stage string
	skip  bool
}

// Bump moves pkg to version in the canary, runs the ladder there, and only if it passes does the same in
// each rollout product, one at a time. The first product that fails is put back as it was, and the bump
// stops: products after it are never touched. A policy file is never changed: the tool may change the
// manifest and its lock file, and nothing else, or the product fails. A refusal changes nothing.
func (b *Bumper) Bump(ctx context.Context, pkg, version string, canary Product, rollout []Product) (Report, error) {
	plans, to, err := b.plan(pkg, version, canary, rollout)
	if err != nil {
		return Report{}, err
	}
	var rep Report
	for _, pl := range plans {
		step := Step{Product: pl.p.Name, Stage: pl.stage, From: pl.m.Current.String(), To: to.String()}
		if pl.skip {
			step.Verdict, step.Reason = "skip", "it requires "+step.From+" already"
			rep.Steps = append(rep.Steps, step)
			continue
		}
		var err error
		if step.Verdict, step.Reason, err = b.stage(ctx, pkg, to, pl); err != nil {
			return rep, err
		}
		rep.Steps = append(rep.Steps, step)
		note := pl.p.Name
		if step.Reason != "" {
			note += ": " + step.Reason
		}
		if err := b.Log(gungnir.Event{Name: gungnir.EventDepsBump, Package: pkg, From: step.From, To: step.To,
			Stage: pl.stage, Verdict: step.Verdict, Note: cut(note, 400)}); err != nil {
			return rep, err
		}
		if step.Verdict == "fail" {
			break
		}
	}
	return rep, nil
}

// plan checks everything that can be checked before a file changes.
func (b *Bumper) plan(pkg, version string, canary Product, rollout []Product) ([]plan, Version, error) {
	refuse := func(f string, a ...any) ([]plan, Version, error) {
		return nil, Version{}, &Refusal{fmt.Sprintf(f, a...)}
	}
	to, err := ParseVersion(version)
	switch {
	case !ValidPackage(pkg):
		return refuse("%q is not a package name", pkg)
	case err != nil:
		return refuse("%v", err)
	case to.Pre != "":
		return refuse("%s is a pre-release; the policy allows tagged releases only", version)
	}
	var plans []plan
	var dirs []string
	for i, p := range append([]Product{canary}, rollout...) {
		stage := "rollout"
		if i == 0 {
			stage = "canary"
		}
		if dir := filepath.Clean(p.Dir); slices.Contains(dirs, dir) {
			return refuse("the product %s is named twice", p.Name)
		} else {
			dirs = append(dirs, dir)
		}
		for _, name := range Ladder {
			if len(p.Checks[name]) == 0 {
				return refuse("the realm %s of %s defines no check %s; a bump never skips a rung", p.Realm, p.Name, name)
			}
		}
		m, err := Find(p.Dir, pkg)
		if err != nil {
			return refuse("%s: %v", p.Name, err)
		}
		switch c := to.Compare(m.Current); {
		case c < 0:
			return refuse("%s requires %s %s: %s goes down, and a bump only goes up", p.Name, pkg, m.Current, to)
		case c == 0 && stage == "canary":
			return refuse("the canary %s requires %s %s already; there is nothing to bump", p.Name, pkg, m.Current)
		}
		plans = append(plans, plan{p: p, m: m, stage: stage, skip: to.Compare(m.Current) == 0})
	}
	return plans, to, nil
}

// stage bumps one product and runs its ladder. A product that fails is put back as it was; the error is
// for what is not the product's fault: the sandbox, the log, the snapshot or a context that ended.
func (b *Bumper) stage(ctx context.Context, pkg string, to Version, pl plan) (verdict, reason string, err error) {
	snap, err := Take(pl.p.Dir)
	if err != nil {
		return "", "", err
	}
	end := context.WithoutCancel(ctx) // a restore and a stop must also happen after a cancel
	runner, stop, err := b.Open.Open(ctx, pl.p)
	if err != nil {
		return "", "", err
	}
	verdict, reason, err = b.apply(ctx, runner, snap, pkg, to, pl)
	if serr := stop(end); serr != nil && err == nil {
		err = serr
	}
	if err != nil || verdict == "fail" {
		if rerr := snap.Restore(); rerr != nil {
			err = errors.Join(err, fmt.Errorf("could not put %s back as it was: %w", pl.p.Name, rerr))
			if verdict == "fail" { // the ledger must say what is in the product
				reason += "; the product could not be put back"
			}
		}
	}
	return verdict, reason, err
}

func (b *Bumper) apply(ctx context.Context, runner gungnir.Runner, snap *Snapshot, pkg string, to Version, pl plan) (verdict, reason string, err error) {
	run := func(name string, argv []string) (checks.Result, error) {
		t := b.Timeout
		if t == 0 {
			t = DefaultTimeout
		}
		log := filepath.Join(b.LogDir, strings.ReplaceAll(pl.p.Name, "/", "_")+"-"+pl.stage+"-"+name+".log")
		return checks.Run(ctx, runner, checks.Spec{Name: name, Argv: argv, Timeout: t}, log)
	}
	res, err := run("bump", pl.m.Command(pkg, to))
	if err != nil {
		return "", "", err
	}
	if !res.Passed {
		return "fail", "the tool failed: " + ended(res), nil
	}
	changed, err := snap.Changes()
	if err != nil {
		return "", "", err
	}
	if extra := slices.DeleteFunc(changed, func(f string) bool { return slices.Contains(pl.m.Kind.Files(), f) }); len(extra) > 0 {
		return "fail", "the tool changed files that are not the manifest or its lock file: " + strings.Join(extra, ", "), nil
	}
	if m, err := Find(pl.p.Dir, pkg); err != nil || m.Current.Compare(to) != 0 {
		return "fail", fmt.Sprintf("the manifest does not require %s %s after the tool ran", pkg, to), nil
	}
	for _, name := range Ladder {
		res, err := run(name, pl.p.Checks[name])
		if err != nil {
			return "", "", err
		}
		if name == "deps" {
			v := "pass"
			if !res.Passed {
				v = "fail"
			}
			if err := b.Log(gungnir.Event{Name: gungnir.EventDepsChecked, Realm: pl.p.Realm, Verdict: v}); err != nil {
				return "", "", err
			}
		}
		if !res.Passed {
			return "fail", "the check " + name + " failed: " + ended(res), nil
		}
	}
	return "pass", "", nil
}

func ended(r checks.Result) string {
	if r.TimedOut {
		return "it timed out"
	}
	return fmt.Sprintf("exit status %d (output: %s)", r.ExitCode, r.Log)
}

func cut(s string, n int) string {
	if len(s) > n {
		return s[:n]
	}
	return s
}
```

#### Part 4: the other tests of `Bump`, and the real `go`

These tests pin behavior that part 3 already has. They were written after the code, so they have no red step. The Evidence lists the mutations that make them fail.

`bump_go_test.go` runs the real `go get`, offline. It writes a module proxy as a folder: for each of three versions of `example.invalid/dep` a `.mod`, an `.info` and a `.zip`, and a `list` file. It sets `GOPROXY=file://<folder>`, `GOSUMDB=off`, `GOTOOLCHAIN=local`, `GOWORK=off` and its own `GOMODCACHE`, `GOCACHE` and `HOME`. Version 1.0.1 is compatible. Version 1.1.0 removes the function `F` that the product calls. The two rungs of the product are real commands: `go mod verify` stands for `deps` and `go build ./...` stands for `unit`. The test skips when there is no `go` on `PATH`.

- [ ] **Step 1:** create `bump_more_test.go` and `bump_go_test.go`. **Step 2:** run them.

```bash
go test -count=1 -race -v ./internal/deps 2>&1 | grep -E '^(--- |ok|FAIL)'
```

Expected (18 tests, in the order go prints them; the real-go tests take about 1.6 seconds each):

```text
--- PASS: TestTheRealGoBumpsACanaryAndThenTheRolloutProductOffline (1.67s)
--- PASS: TestTheRealGoCanaryThatBreaksTheBuildIsPutBackAndTheRolloutProductIsNotTouched (1.49s)
--- PASS: TestARolloutStopsAtTheFirstFailureAndPutsBackOnlyThatProduct (0.01s)
--- PASS: TestARefusalChangesNothingAndOpensNothing (0.02s)
--- PASS: TestAToolThatChangesAPolicyFileFailsTheProductAndTheFileIsPutBack (0.01s)
--- PASS: TestARolloutProductThatHasTheVersionIsSkippedWithoutBeingOpened (0.01s)
--- PASS: TestACancelledBumpPutsTheProductBackAndStopsItsSandbox (0.00s)
--- PASS: TestNpmBumpKeepsTheTildeAndRunsNoScript (0.00s)
--- PASS: TestACanaryThatPassesRollsOutOneProductAtATime (0.01s)
--- PASS: TestACanaryThatFailsIsPutBackByteForByteAndNoRolloutProductIsTouched (0.02s)
--- PASS: TestFindReadsGoModInEveryFormOfRequire (0.00s)
--- PASS: TestFindReadsPackageJSONAndKeepsTheTilde (0.00s)
--- PASS: TestFindRefusesWhatItWouldHaveToGuess (0.00s)
--- PASS: TestSnapshotRestoresChangedRemovedAndCreatedFilesByteForByte (0.01s)
--- PASS: TestSnapshotRefusesAProductTooBigToUndo (0.00s)
--- PASS: TestVersionOrder (0.00s)
--- PASS: TestParseVersionReadsGoAndNpmForms (0.00s)
--- PASS: TestValidPackageRefusesAnOptionAndAPathEscape (0.00s)
ok  	github.com/ouroboric-dev/odin/internal/deps	4.255s
```

- [ ] **Step 3:** commit.

```bash
git add internal/deps/bump_more_test.go internal/deps/bump_go_test.go
git commit -m "deps part 4: tests for the rollout stop, the refusals, a tool that changes a policy file, a cancel, npm, and the real go tool offline (v0-T259)" \
  -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**New file `internal/deps/bump_more_test.go`**

```go
package deps

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func TestARolloutStopsAtTheFirstFailureAndPutsBackOnlyThatProduct(t *testing.T) {
	w := newWorld(t, map[string]string{"api": "0.41.0", "r1": "0.41.0", "r2": "0.41.0", "r3": "0.41.0"})
	w.fail["r2:unit"] = 1
	before2, before3 := w.bytes("r2"), w.bytes("r3")
	rep, err := w.bumper().Bump(context.Background(), "golang.org/x/text", "0.42.0", w.product("api"), []Product{w.product("r1"), w.product("r2"), w.product("r3")})
	if err != nil || !rep.Failed() || len(rep.Steps) != 3 {
		t.Fatalf("report %+v, error %v", rep, err)
	}
	if !same2(before2, w.bytes("r2")) || !same2(before3, w.bytes("r3")) || strings.Contains(strings.Join(w.opened, ","), "r3") {
		t.Errorf("r2 not restored or r3 touched; opened %v", w.opened)
	}
	if !strings.Contains(w.has("api"), "v0.42.0") || !strings.Contains(w.has("r1"), "v0.42.0") {
		t.Error("the products that passed were put back")
	}
	if got := strings.Join(w.eventLines(), "|"); !strings.HasSuffix(got, "deps_bump rollout fail golang.org/x/text 0.41.0>0.42.0") || strings.Count(got, "deps_bump") != 3 {
		t.Errorf("events: %s", got)
	}
}

func TestARefusalChangesNothingAndOpensNothing(t *testing.T) {
	cases := map[string]struct {
		pkg, version string
		canary       string
		rollout      []string
		mutate       func(*world)
		want         string
	}{
		"a bump down":          {"golang.org/x/text", "0.40.0", "api", nil, nil, "goes down"},
		"a rollout bump down":  {"golang.org/x/text", "0.42.0", "api", []string{"new"}, func(w *world) { write(w.t, w.root+"/new", "go.mod", goModAt("0.43.0")) }, "goes down"},
		"the canary has it":    {"golang.org/x/text", "0.41.0", "api", nil, nil, "nothing to bump"},
		"a pre-release":        {"golang.org/x/text", "0.42.0-rc.1", "api", nil, nil, "pre-release"},
		"a bad version":        {"golang.org/x/text", "latest", "api", nil, nil, "not a version"},
		"an option as package": {"--registry=http://evil", "1.0.0", "api", nil, nil, "not a package name"},
		"a package not there":  {"example.invalid/other", "1.0.0", "api", nil, nil, "requires no package"},
		"the canary twice":     {"golang.org/x/text", "0.42.0", "api", []string{"api"}, nil, "named twice"},
		"a missing rung":       {"golang.org/x/text", "0.42.0", "api", nil, nil, "defines no check unit"},
	}
	for name, c := range cases {
		w := newWorld(t, map[string]string{"api": "0.41.0"})
		if c.mutate != nil {
			c.mutate(w)
		}
		canary := w.product("api")
		if name == "a missing rung" {
			delete(canary.Checks, "unit")
		}
		var rollout []Product
		for _, r := range c.rollout {
			rollout = append(rollout, w.product(r))
		}
		before := w.bytes("api")
		_, err := w.bumper().Bump(context.Background(), c.pkg, c.version, canary, rollout)
		var refusal *Refusal
		if !errors.As(err, &refusal) || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: error %v, want a refusal with %q", name, err, c.want)
		}
		if len(w.opened) != 0 || len(w.events) != 0 || !same2(before, w.bytes("api")) {
			t.Errorf("%s: it opened %v, logged %v or changed a file", name, w.opened, w.eventLines())
		}
	}
}

func TestAToolThatChangesAPolicyFileFailsTheProductAndTheFileIsPutBack(t *testing.T) {
	for _, file := range []string{"devcontainer/checks/config/deps-policy.json", "deps-policy.json", "main.go"} {
		w := newWorld(t, map[string]string{"api": "0.41.0"})
		w.also["api"] = [2]string{file, `{"schema":"ygg.deps/v1","minimum":{}}`}
		before := w.bytes("api")
		rep, err := w.bumper().Bump(context.Background(), "golang.org/x/text", "0.42.0", w.product("api"), nil)
		if err != nil || !rep.Failed() || !strings.Contains(rep.Steps[0].Reason, file) {
			t.Fatalf("%s: report %+v, error %v", file, rep, err)
		}
		if !same2(before, w.bytes("api")) {
			t.Errorf("%s: not put back", file)
		}
		if strings.Contains(strings.Join(w.timeline, "|"), "api deps") {
			t.Errorf("%s: the ladder ran on a product the tool changed beyond its manifest", file)
		}
	}
}

func TestARolloutProductThatHasTheVersionIsSkippedWithoutBeingOpened(t *testing.T) {
	w := newWorld(t, map[string]string{"api": "0.41.0", "done": "0.42.0"})
	rep, err := w.bumper().Bump(context.Background(), "golang.org/x/text", "0.42.0", w.product("api"), []Product{w.product("done")})
	if err != nil || rep.Failed() || rep.Steps[1].Verdict != "skip" || strings.Join(w.opened, ",") != "api" {
		t.Fatalf("report %+v, error %v, opened %v", rep, err, w.opened)
	}
	if len(w.events) != 2 { // deps_checked and the canary's deps_bump; the skipped product logs nothing
		t.Errorf("events %v", w.eventLines())
	}
}

func TestACancelledBumpPutsTheProductBackAndStopsItsSandbox(t *testing.T) {
	w := newWorld(t, map[string]string{"api": "0.41.0"})
	ctx, cancel := context.WithCancel(context.Background())
	w.onRun = func(_, check string) error {
		if check == "unit" {
			cancel()
			return ctx.Err()
		}
		return nil
	}
	before := w.bytes("api")
	_, err := w.bumper().Bump(ctx, "golang.org/x/text", "0.42.0", w.product("api"), nil)
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("error %v", err)
	}
	if !same2(before, w.bytes("api")) || strings.Join(w.stopped, ",") != "api" {
		t.Errorf("not put back, or not stopped: %v", w.stopped)
	}
	for _, e := range w.events {
		if e.Name == gungnir.EventDepsBump {
			t.Errorf("a cancelled bump logged a verdict: %+v", e)
		}
	}
}

func TestNpmBumpKeepsTheTildeAndRunsNoScript(t *testing.T) {
	dir := t.TempDir()
	write(t, dir, "package.json", `{"dependencies":{"react":"~19.1.0"}}`)
	write(t, dir, "package-lock.json", "{}\n")
	var got []string
	w := &npmWorld{dir: dir, got: &got}
	b := &Bumper{Open: w, LogDir: filepath.Join(dir, "..", "logs"), Log: func(gungnir.Event) error { return nil }}
	p := Product{Name: "web", Dir: dir, Realm: "midgard-react", Checks: map[string][]string{"deps": {"web-deps.sh"}, "unit": {"web-unit.sh"}}}
	rep, err := b.Bump(context.Background(), "react", "19.1.4", p, nil)
	if err != nil || rep.Failed() {
		t.Fatalf("report %+v, error %v", rep, err)
	}
	if got[0] != "npm install --ignore-scripts --save-prefix=~ react@19.1.4" {
		t.Errorf("tool command %q", got[0])
	}
}

type npmWorld struct {
	dir string
	got *[]string
}

func (n *npmWorld) Open(context.Context, Product) (gungnir.Runner, func(context.Context) error, error) {
	return n, func(context.Context) error { return nil }, nil
}

func (n *npmWorld) Run(_ context.Context, c gungnir.Cmd) (gungnir.ExecResult, error) {
	*n.got = append(*n.got, strings.Join(c.Argv, " "))
	if c.Argv[0] == "npm" {
		os.WriteFile(filepath.Join(n.dir, "package.json"), []byte(`{"dependencies":{"react":"~19.1.4"}}`), 0o644)
		os.WriteFile(filepath.Join(n.dir, "package-lock.json"), []byte("{\"v\":2}\n"), 0o644)
	}
	return gungnir.ExecResult{}, nil
}
```

**New file `internal/deps/bump_go_test.go`**

```go
package deps

import (
	"archive/zip"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

// The tests below run the real go tool, with no network: the module comes from a module proxy that is a
// folder (GOPROXY=file://...), built here. Version 1.0.1 of the module is compatible with the product's
// code; 1.1.0 removes a function the code calls, so the product's build, which is its unit rung here, fails.

func writeProxy(t *testing.T) string {
	t.Helper()
	proxy := t.TempDir()
	versions := map[string]string{
		"v1.0.0": "package dep\n\nfunc F() string { return \"one\" }\n",
		"v1.0.1": "package dep\n\nfunc F() string { return \"one, patched\" }\n",
		"v1.1.0": "package dep\n\nfunc G() string { return \"F is gone\" }\n",
	}
	dir := filepath.Join(proxy, "example.invalid", "dep", "@v")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	var list string
	for v, src := range versions {
		list += v + "\n"
		mod := "module example.invalid/dep\n\ngo 1.21\n"
		must := func(err error) {
			if err != nil {
				t.Fatal(err)
			}
		}
		must(os.WriteFile(filepath.Join(dir, v+".mod"), []byte(mod), 0o644))
		must(os.WriteFile(filepath.Join(dir, v+".info"), []byte(fmt.Sprintf(`{"Version":%q,"Time":"2026-01-01T00:00:00Z"}`, v)), 0o644))
		f, err := os.Create(filepath.Join(dir, v+".zip"))
		must(err)
		zw := zip.NewWriter(f)
		for name, body := range map[string]string{"go.mod": mod, "dep.go": src} {
			w, err := zw.Create("example.invalid/dep@" + v + "/" + name)
			must(err)
			_, err = w.Write([]byte(body))
			must(err)
		}
		must(zw.Close())
		must(f.Close())
	}
	if err := os.WriteFile(filepath.Join(dir, "list"), []byte(list), 0o644); err != nil {
		t.Fatal(err)
	}
	return proxy
}

// goRunner runs commands with the real tools on the host, with no network and no cache of the operator's.
type goRunner struct {
	dir string
	env []string
}

func (g goRunner) Run(ctx context.Context, c gungnir.Cmd) (gungnir.ExecResult, error) {
	cmd := exec.CommandContext(ctx, c.Argv[0], c.Argv[1:]...)
	cmd.Dir, cmd.Env, cmd.Stdout, cmd.Stderr = g.dir, g.env, c.Stdout, c.Stderr
	err := cmd.Run()
	if ee, ok := err.(*exec.ExitError); ok {
		return gungnir.ExecResult{ExitCode: ee.ExitCode()}, nil
	}
	return gungnir.ExecResult{}, err
}

type goOpener struct{ env []string }

func (o goOpener) Open(_ context.Context, p Product) (gungnir.Runner, func(context.Context) error, error) {
	return goRunner{p.Dir, o.env}, func(context.Context) error { return nil }, nil
}

func goProduct(t *testing.T, env []string, name string) Product {
	t.Helper()
	dir := filepath.Join(t.TempDir(), name)
	write(t, dir, "go.mod", "module example.invalid/"+name+"\n\ngo 1.21\n\nrequire example.invalid/dep v1.0.0\n")
	write(t, dir, "main.go", "package main\n\nimport \"example.invalid/dep\"\n\nfunc main() { println(dep.F()) }\n")
	write(t, dir, "devcontainer/checks/config/deps-policy.json", policyJSON)
	tidy := exec.Command("go", "mod", "tidy")
	tidy.Dir, tidy.Env = dir, env
	if out, err := tidy.CombinedOutput(); err != nil {
		t.Fatalf("go mod tidy: %v\n%s", err, out)
	}
	return Product{Name: name, Dir: dir, Realm: "helheim-go", Checks: map[string][]string{
		"deps": {"go", "mod", "verify"}, "unit": {"go", "build", "./..."}}}
}

func goWorld(t *testing.T) (env []string, b *Bumper, events *[]gungnir.Event) {
	t.Helper()
	if _, err := exec.LookPath("go"); err != nil {
		t.Skip("no go tool on PATH")
	}
	proxy, tmp := writeProxy(t), t.TempDir()
	env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + tmp, "GOPATH=" + filepath.Join(tmp, "gopath"), "GOCACHE=" + filepath.Join(tmp, "cache"),
		"GOMODCACHE=" + filepath.Join(tmp, "mod"), "GOFLAGS=-modcacherw", "GOPROXY=file://" + proxy, "GOSUMDB=off", "GOTOOLCHAIN=local", "GOWORK=off"}
	events = &[]gungnir.Event{}
	return env, &Bumper{Open: goOpener{env}, LogDir: filepath.Join(tmp, "logs"), Log: func(e gungnir.Event) error {
		*events = append(*events, e)
		return nil
	}}, events
}

func TestTheRealGoBumpsACanaryAndThenTheRolloutProductOffline(t *testing.T) {
	env, b, events := goWorld(t)
	canary, next := goProduct(t, env, "canary"), goProduct(t, env, "next")
	rep, err := b.Bump(context.Background(), "example.invalid/dep", "1.0.1", canary, []Product{next})
	if err != nil || rep.Failed() || len(rep.Steps) != 2 {
		t.Fatalf("report %+v, error %v", rep, err)
	}
	for _, p := range []Product{canary, next} {
		if m := mustFind(t, p.Dir, "example.invalid/dep"); m.Current.String() != "1.0.1" {
			t.Errorf("%s requires %s", p.Name, m.Current)
		}
	}
	if len(*events) != 4 || (*events)[1].Verdict != "pass" || (*events)[3].Stage != "rollout" {
		t.Errorf("events %+v", *events)
	}
}

func TestTheRealGoCanaryThatBreaksTheBuildIsPutBackAndTheRolloutProductIsNotTouched(t *testing.T) {
	env, b, events := goWorld(t)
	canary, next := goProduct(t, env, "canary"), goProduct(t, env, "next")
	before := map[string]string{}
	for _, p := range []Product{canary, next} {
		for k, v := range (&world{root: filepath.Dir(p.Dir)}).bytes(p.Name) {
			before[k] = v
		}
	}
	rep, err := b.Bump(context.Background(), "example.invalid/dep", "1.1.0", canary, []Product{next})
	if err != nil || !rep.Failed() || len(rep.Steps) != 1 || !strings.Contains(rep.Steps[0].Reason, "check unit failed") {
		t.Fatalf("report %+v, error %v", rep, err)
	}
	after := map[string]string{}
	for _, p := range []Product{canary, next} {
		for k, v := range (&world{root: filepath.Dir(p.Dir)}).bytes(p.Name) {
			after[k] = v
		}
	}
	if !same2(before, after) {
		t.Error("a file of the canary or of the rollout product is not as it was")
	}
	if n := len(*events); n != 2 || (*events)[1].Stage != "canary" || (*events)[1].Verdict != "fail" {
		t.Errorf("events %+v", *events)
	}
}
```

#### Part 5: the command

`ygg deps bump` finds the project (`tree.FindRoot`), takes the runs lock, and turns each path into a `deps.Product`: the leaf node, its realm (pinned by the project, else the lead), and the realm's checks. It starts the sandbox driver only when `factory.yaml` has a `sandbox` section. The driver config is that of `prepareSandbox` (the operator's uid and gid, the mounts, the images of the first product's stack). `newDepsSandbox` is a variable so a test can put a fake there. Each product gets its own `SandboxSpec`: the product's leaf, git directory and parent, the egress of its realm's pack, its realm's stack and services. The ledger and its folder are made when the first line is written.

The usage text in `cli.go` gets one line. The command table gets `"deps": c.deps`. `flags` gets `canary` and `rollout`.

- [ ] **Step 1:** write `internal/cli/deps_test.go` (part 6 below) first, and see it fail.

```bash
go test -count=1 -run 'DepsBump' ./internal/cli 2>&1 | head -6
```

Expected: `FAIL` with `internal/cli/deps_test.go:170:9: undefined: newDepsSandbox`.

- [ ] **Step 2:** create `internal/cli/deps.go` and apply the `cli.go` patch.
- [ ] **Step 3:** run the tests, then everything.

```bash
gofmt -l . && go vet ./... && go test -count=1 -race -v -run DepsBump ./internal/cli 2>&1 | grep -E '^(--- |ok|FAIL)'
```

Expected:

```text
--- PASS: TestDepsBumpMovesTheCanaryThenTheRolloutProduct (0.65s)
--- PASS: TestDepsBumpPutsAFailedCanaryBackAndTouchesNoRolloutProduct (0.60s)
--- PASS: TestDepsBumpRefusalsExitTwoAndLeaveNoTrace (0.71s)
--- PASS: TestDepsBumpRunsToolAndChecksInTheSandboxOfEachLeafAndStopsIt (0.61s)
ok  	github.com/ouroboric-dev/odin/internal/cli	3.632s
```

- [ ] **Step 4:** commit the code, then (Part 6) the tests. In a real history the tests come first; here they are two commits, so that no commit is far over 400 lines.

```bash
git add internal/cli/deps.go internal/cli/cli.go
git commit -m "ygg deps bump: the canary first, a rollout only after it passes, a failed product put back (v0-T259)" \
  -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**New file `internal/cli/deps.go`**

```go
package cli

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"

	"github.com/ouroboric-dev/gleipnir/sandbox"
	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/deps"
	"github.com/ouroboric-dev/odin/internal/ledger"
	"github.com/ouroboric-dev/odin/internal/lock"
	"github.com/ouroboric-dev/odin/internal/realm"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/tree"
)

// newDepsSandbox starts the sandbox driver of a bump. Tests replace it with a fake.
var newDepsSandbox = func(engine string, cfg sandbox.Config, work string) (gungnir.Sandbox, error) {
	return sandbox.New(engine, cfg, work)
}

// deps runs ygg deps bump (spec §9.6): one package to one version in a canary product, and only if the
// canary's deps and unit rungs pass, in each rollout product, one at a time. A product that fails is put
// back as it was and the bump stops. The change stays in the working copies, uncommitted: a human, or
// a run, commits it. Each product's own realm decides its checks; no policy file is read or written here.
func (c *command) deps(args []string) int {
	if len(args) == 0 || args[0] != "bump" {
		fmt.Fprint(c.err, usage)
		return ExitRefused
	}
	f, pos, ok := c.parse("deps bump", args[1:], 2, func(fs *flag.FlagSet, f *flags) {
		fs.StringVar(&f.config, "config", "factory.yaml", "the factory config")
		fs.StringVar(&f.canary, "canary", "", "the product that takes the bump first: a leaf of the project: a path from the project, or absolute")
		fs.Func("rollout", "a product that takes the bump after the canary passes: a leaf of the project; repeat it for more", func(v string) error {
			f.rollout = append(f.rollout, v)
			return nil
		})
	})
	if !ok {
		return ExitRefused
	}
	if f.canary == "" {
		return c.refuse(errors.New("deps bump needs --canary"))
	}
	cfg, err := schema.LoadFactory(f.config)
	if err != nil {
		return c.refuse(err)
	}
	root, projectPath, err := tree.FindRoot(c.ctx, f.project)
	if err != nil {
		return c.refuse(err)
	}
	nodes, err := tree.Resolve(c.ctx, root, projectPath)
	if err != nil {
		return c.refuse(err)
	}
	project := nodes[len(nodes)-1]
	if project.Umbrella == nil || project.Kind != schema.ChildUmbrella {
		return c.refuse(fmt.Errorf("%s is not a project umbrella", f.project))
	}
	release, err := lock.Take(run.RunsLock(project.Dir))
	if errors.Is(err, lock.ErrHeld) {
		return c.refuse(run.ErrProjectBusy)
	} else if err != nil {
		return c.refuse(err)
	}
	defer release()
	id, err := run.NewIDNow()
	if err != nil {
		return c.refuse(err)
	}
	work := filepath.Join(project.Dir, ".factory", "deps", id)
	opener := &depsOpener{id: id, home: filepath.Join(work, "home"), places: map[string]depsPlace{}}
	var products []deps.Product
	var firstStack string
	for i, dir := range append([]string{f.canary}, f.rollout...) {
		p, place, err := c.depsProduct(cfg, root, projectPath, project, dir)
		if err != nil {
			return c.refuse(err)
		}
		if i == 0 {
			firstStack = place.realm.Stack
		}
		opener.places[p.Dir] = place
		products = append(products, p)
	}
	if cfg.Sandbox != nil {
		uid, gid := os.Getuid(), os.Getgid()
		if uid == 0 {
			return c.refuse(errors.New("ygg must not run as root: the sandbox's user is the operator's own"))
		}
		sc := sandbox.Config{Images: sandbox.ImagesFor(firstStack), UID: uid, GID: gid}
		for _, m := range cfg.Sandbox.Mounts {
			sc.Mounts = append(sc.Mounts, sandbox.PathMap{Host: m.Host, Engine: m.Engine})
		}
		if opener.sb, err = newDepsSandbox(cfg.Sandbox.Engine, sc, filepath.Join(work, "sandbox")); err != nil {
			return c.refuse(err)
		}
	}
	// The bump's folder, and its ledger, appear when the first line is written: a refusal leaves nothing.
	var l *ledger.Ledger
	defer func() {
		if l != nil {
			l.Close()
		}
	}()
	b := &deps.Bumper{Open: opener, LogDir: filepath.Join(work, "logs"), Log: func(e gungnir.Event) error {
		if l == nil {
			if err := os.MkdirAll(work, 0o755); err != nil {
				return err
			}
			var err error
			if l, err = ledger.Open(filepath.Join(work, "ledger.jsonl"), ledger.Anchor{}); err != nil {
				return err
			}
		}
		e.Run = id
		return l.Append(e)
	}}
	rep, err := b.Bump(c.ctx, pos[0], pos[1], products[0], products[1:])
	var refusal *deps.Refusal
	if errors.As(err, &refusal) {
		return c.refuse(err)
	}
	for _, s := range rep.Steps {
		line := fmt.Sprintf("%s (%s): %s to %s: %s", s.Product, s.Stage, s.From, s.To, s.Verdict)
		if s.Reason != "" {
			line += " (" + s.Reason + ")"
		}
		fmt.Fprintln(c.out, line)
	}
	switch {
	case err != nil:
		fmt.Fprintf(c.err, "ygg: the bump %s stopped: %v\n", id, err)
		return ExitFailed
	case rep.Failed():
		last := rep.Steps[len(rep.Steps)-1]
		fmt.Fprintf(c.err, "ygg: %s failed (%s) and is back as it was; no product after it was touched. The ledger is %s\n", last.Product, last.Reason, filepath.Join(work, "ledger.jsonl"))
		return ExitFailed
	}
	fmt.Fprintf(c.out, "Bump %s done: %s is at %s in %d product(s). The change is in the working copies, uncommitted.\n", id, pos[0], pos[1], len(rep.Steps))
	return ExitDone
}

// depsPlace is where a product is in the tree, and the realm that provides it.
type depsPlace struct {
	parent, leaf tree.Node
	realm        *realm.Realm
}

// depsProduct finds the leaf dir names in the project, and the realm the project pins for it.
func (c *command) depsProduct(cfg *schema.Factory, root, projectPath string, project tree.Node, dir string) (deps.Product, depsPlace, error) {
	abs := dir
	if !filepath.IsAbs(dir) { // a relative path is from the project, so repos/api works from anywhere
		abs = filepath.Join(project.Dir, dir)
	}
	rel, err := filepath.Rel(project.Dir, filepath.Clean(abs))
	if err != nil || !filepath.IsLocal(rel) {
		return deps.Product{}, depsPlace{}, fmt.Errorf("%s is not inside the project %s", dir, project.Dir)
	}
	rel = filepath.ToSlash(rel)
	child, ok := project.Umbrella.Children[rel]
	if !ok || child.Kind != schema.ChildLeaf {
		return deps.Product{}, depsPlace{}, fmt.Errorf("%s is not a leaf of the project: --canary and --rollout name a leaf by its path, such as repos/api", dir)
	}
	name := child.Realm
	if name == "" {
		name = project.Umbrella.Realm
	}
	if name == "" || cfg.Realms == nil {
		return deps.Product{}, depsPlace{}, fmt.Errorf("%s pins no realm, or factory.yaml has no realms section: the bump cannot tell which checks to run", rel)
	}
	rdir, err := (&realm.Store{Dir: cfg.Realms.Dir}).Find(name)
	if err != nil {
		return deps.Product{}, depsPlace{}, err
	}
	r, err := realm.Load(rdir)
	if err != nil {
		return deps.Product{}, depsPlace{}, err
	}
	ns, err := tree.Resolve(c.ctx, root, filepath.Join(projectPath, rel))
	if err != nil {
		return deps.Product{}, depsPlace{}, err
	}
	p := deps.Product{Name: rel, Dir: ns[len(ns)-1].Dir, Realm: r.Name, Checks: r.Pack.Checks}
	return p, depsPlace{parent: ns[len(ns)-2], leaf: ns[len(ns)-1], realm: r}, nil
}

// depsOpener runs a product's commands in its sandbox, or on the host when factory.yaml has no sandbox.
type depsOpener struct {
	sb     gungnir.Sandbox
	id     string
	home   string
	places map[string]depsPlace // by the product's folder
}

func (o *depsOpener) Open(ctx context.Context, p deps.Product) (gungnir.Runner, func(context.Context) error, error) {
	pl := o.places[p.Dir]
	if o.sb == nil {
		return hostExec{dir: p.Dir, home: o.home}, func(context.Context) error { return nil }, nil
	}
	if pl.realm.Pack.Sandbox == nil {
		return nil, nil, fmt.Errorf("the realm %s of %s names no sandbox stack in its pack.yaml, and factory.yaml has a sandbox section", pl.realm.Name, p.Name)
	}
	env, err := o.sb.Up(ctx, gungnir.SandboxSpec{Run: o.id, Name: p.Name, Parent: pl.parent.Dir, Leaf: pl.leaf.Dir, GitDir: pl.leaf.GitDir,
		Egress: pl.realm.Pack.Sandbox.Egress, Stack: pl.realm.Stack, Services: pl.realm.Pack.ServiceList()})
	if err != nil {
		return nil, nil, err
	}
	return gungnir.Bind(o.sb, env), func(ctx context.Context) error { return o.sb.Down(ctx, env) }, nil
}

// hostExec runs a command on the host, in the product, in a process group of its own, with PATH, HOME and
// LANG only. It is the runner of a project whose factory.yaml has no sandbox section.
type hostExec struct{ dir, home string }

func (h hostExec) Run(ctx context.Context, c gungnir.Cmd) (gungnir.ExecResult, error) {
	if err := c.Validate(); err != nil {
		return gungnir.ExecResult{}, err
	}
	if len(c.Env) > 0 {
		return gungnir.ExecResult{}, errors.New("a command on the host takes no environment of its own: credentials belong to the sandbox")
	}
	if err := os.MkdirAll(h.home, 0o755); err != nil {
		return gungnir.ExecResult{}, err
	}
	cmd := exec.CommandContext(ctx, c.Argv[0], c.Argv[1:]...)
	cmd.Dir = filepath.Join(h.dir, c.Dir)
	cmd.Env = []string{"PATH=" + os.Getenv("PATH"), "HOME=" + h.home, "LANG=C.UTF-8"}
	cmd.Stdin, cmd.Stdout, cmd.Stderr = c.Stdin, c.Stdout, c.Stderr
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error { return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL) }
	cmd.WaitDelay = 5 * time.Second
	err := cmd.Run()
	var ee *exec.ExitError
	switch {
	case ctx.Err() != nil:
		return gungnir.ExecResult{}, ctx.Err()
	case err == nil:
		return gungnir.ExecResult{}, nil
	case errors.As(err, &ee):
		return gungnir.ExecResult{ExitCode: ee.ExitCode()}, nil
	case errors.Is(err, exec.ErrNotFound) || errors.Is(err, os.ErrNotExist) || errors.Is(err, os.ErrPermission):
		fmt.Fprintf(c.Stderr, "ygg: %v\n", err) // a program that can't start is a command that failed, as in a shell
		return gungnir.ExecResult{ExitCode: 127}, nil
	}
	return gungnir.ExecResult{}, err
}
```

**Change to `internal/cli/cli.go`**

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 2e3203f..d8cdacc 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -38,4 +38,5 @@ const usage = `usage:
   ygg status  <run-id> [--project <dir>]
   ygg grade   <run-id> [--task <id>] [--project <dir>]
+  ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--project <dir>] [--config <factory.yaml>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
   ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
@@ -53,5 +54,5 @@ func Main(ctx context.Context, args []string, stdout, stderr io.Writer) int {
 	cmds := map[string]func([]string) int{
 		"run": c.run, "resume": c.resume, "approve": c.approve, "reject": c.reject,
-		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade,
+		"status": c.status, "doctor": c.doctor, "sandbox": c.sandbox, "grade": c.grade, "deps": c.deps,
 	}
 	f, ok := cmds[args[0]]
@@ -70,8 +71,8 @@ type command struct {
 // flags holds every flag; each command reads the ones it defines.
 type flags struct {
-	project, config, realm, brief, mode, note, reason, root, task string
-	realms                                                        []string        // sandbox build: every --realm given
-	all                                                           bool            // sandbox build: --all
-	set                                                           map[string]bool // the flags given
+	project, config, realm, brief, mode, note, reason, root, task, canary string
+	realms, rollout                                                       []string        // sandbox build: every --realm given; deps bump: every --rollout given
+	all                                                                   bool            // sandbox build: --all
+	set                                                                   map[string]bool // the flags given
 }
 
```

#### Part 6: the command's tests

The fixture is a project of three Go leaves, `repos/api`, `repos/web` and `repos/old`, pinned to a toy realm called `helheim-go` that is written into a temporary store. The toy realm's `deps` check is `test -f go.mod`, and its `unit` check is `test -f ok.txt`. A `go` script first on `PATH` stands for `go get`: it writes the version into `go.mod`. So the test needs no network. For the sandbox test the toy realm also names a stack, and `newDepsSandbox` returns the `sandboxfake` (which runs commands on the host, in the leaf's folder). A failed canary is made by removing `ok.txt` in `repos/api`.

```bash
git add internal/cli/deps_test.go
git commit -m "ygg deps bump: tests with a stand-in go, a toy realm and the fake sandbox (v0-T259)" \
  -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**New file `internal/cli/deps_test.go`**

```go
package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gleipnir/sandbox"
	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/ledger"
	"github.com/ouroboric-dev/odin/internal/sandboxfake"
	"github.com/ouroboric-dev/odin/internal/tree"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

// A bump in a project of three Go leaves whose realm (helheim-go, a toy of it) has the two rungs a bump runs:
// deps passes when go.mod is there, unit passes when ok.txt is there. The "go" the tool runs is a script
// first on PATH, so no test needs a network: it writes the version it is given into go.mod.

const fakeGo = `#!/bin/sh
v="${2#*@v}"
printf 'module m\n\ngo 1.26\n\nrequire golang.org/x/text v%s\n' "$v" > go.mod
`

func goMod(v string) string {
	return "module m\n\ngo 1.26\n\nrequire golang.org/x/text v" + v + "\n"
}

func depsProject(t *testing.T, stack string) (dir, config string) {
	t.Helper()
	bin := t.TempDir()
	if err := os.WriteFile(filepath.Join(bin, "go"), []byte(fakeGo), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	store := t.TempDir()
	pack := "name: helheim-go\nversion: 0.1.0\nchecks:\n  deps: [test, -f, go.mod]\n  unit: [test, -f, ok.txt]\n"
	if stack != "" {
		pack += "sandbox:\n  stack: " + stack + "\n  egress: [proxy.golang.org]\n"
	}
	if err := os.MkdirAll(filepath.Join(store, "helheim-go"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(store, "helheim-go", "pack.yaml"), []byte(pack), 0o644); err != nil {
		t.Fatal(err)
	}
	pin := treetest.Pin{Realm: "helheim-go", Version: "0.1.0"}
	leaf := treetest.Node{Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate, Leaf: true, Pin: pin}
	dir = treetest.Build(t, treetest.Node{Owner: "ouroboric-dev", Visibility: gungnir.VisibilityPrivate,
		Children: map[string]treetest.Node{"repos/api": leaf, "repos/web": leaf, "repos/old": leaf}})
	for name, v := range map[string]string{"api": "0.41.0", "web": "0.41.0", "old": "0.43.0"} {
		ns, err := tree.Resolve(ctx, dir, "repos/"+name) // checks the leaf out
		if err != nil {
			t.Fatal(err)
		}
		for f, body := range map[string]string{"go.mod": goMod(v), "ok.txt": "ok\n"} {
			if err := os.WriteFile(filepath.Join(ns[len(ns)-1].Dir, f), []byte(body), 0o644); err != nil {
				t.Fatal(err)
			}
		}
	}
	_, base := project(t, "script.yaml", "")
	b, _ := os.ReadFile(base)
	extra := "realms:\n  dir: " + store + "\n"
	if stack != "" {
		extra += sandboxExtra
	}
	config = filepath.Join(t.TempDir(), "factory.yaml")
	if err := os.WriteFile(config, append(b, []byte(extra)...), 0o644); err != nil {
		t.Fatal(err)
	}
	return dir, config
}

func mod(t *testing.T, dir, leaf string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(dir, "repos", leaf, "go.mod"))
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

// bumpLedger returns the one bump's ledger, verified, or "" when the bump wrote none.
func bumpLedger(t *testing.T, dir string) string {
	t.Helper()
	entries, _ := os.ReadDir(filepath.Join(dir, ".factory", "deps"))
	if len(entries) == 0 {
		return ""
	}
	p := filepath.Join(dir, ".factory", "deps", entries[0].Name(), "ledger.jsonl")
	if _, err := ledger.Verify(p, ledger.Anchor{}); err != nil {
		t.Fatalf("the ledger of the bump: %v", err)
	}
	b, _ := os.ReadFile(p)
	return string(b)
}

func TestDepsBumpMovesTheCanaryThenTheRolloutProduct(t *testing.T) {
	dir, config := depsProject(t, "")
	code, out, errOut := ygg(t, "deps", "bump", "golang.org/x/text", "0.42.0", "--project", dir, "--config", config,
		"--canary", filepath.Join(dir, "repos/api"), "--rollout", "repos/web")
	if code != ExitDone || !strings.Contains(out, "repos/api (canary): 0.41.0 to 0.42.0: pass") || !strings.Contains(out, "repos/web (rollout): 0.41.0 to 0.42.0: pass") {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	if mod(t, dir, "api") != goMod("0.42.0") || mod(t, dir, "web") != goMod("0.42.0") || mod(t, dir, "old") != goMod("0.43.0") {
		t.Error("go.mod of api, web or old is wrong")
	}
	l := bumpLedger(t, dir)
	for _, want := range []string{`"event":"deps_checked"`, `"ygg.realm.name":"helheim-go"`, `"event":"deps_bump"`, `"ygg.deps.stage":"canary"`, `"ygg.deps.stage":"rollout"`, `"ygg.deps.package":"golang.org/x/text"`, `"ygg.verdict":"pass"`} {
		if !strings.Contains(l, want) {
			t.Errorf("ledger lacks %s:\n%s", want, l)
		}
	}
}

func TestDepsBumpPutsAFailedCanaryBackAndTouchesNoRolloutProduct(t *testing.T) {
	dir, config := depsProject(t, "")
	if err := os.Remove(filepath.Join(dir, "repos/api/ok.txt")); err != nil { // the unit rung of api now fails
		t.Fatal(err)
	}
	code, out, errOut := ygg(t, "deps", "bump", "golang.org/x/text", "0.42.0", "--project", dir, "--config", config, "--canary", "repos/api", "--rollout", "repos/web")
	if code != ExitFailed || !strings.Contains(out, "repos/api (canary): 0.41.0 to 0.42.0: fail (the check unit failed") || !strings.Contains(errOut, "repos/api failed") {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	if mod(t, dir, "api") != goMod("0.41.0") || mod(t, dir, "web") != goMod("0.41.0") {
		t.Error("a go.mod is not as it was")
	}
	l := bumpLedger(t, dir)
	if !strings.Contains(l, `"ygg.deps.stage":"canary"`) || !strings.Contains(l, `"ygg.verdict":"fail"`) || strings.Contains(l, `"rollout"`) {
		t.Errorf("ledger:\n%s", l)
	}
}

func TestDepsBumpRefusalsExitTwoAndLeaveNoTrace(t *testing.T) {
	dir, config := depsProject(t, "")
	common := []string{"--project", dir, "--config", config}
	cases := map[string]struct {
		args []string
		want string
	}{
		"a bump down":           {[]string{"deps", "bump", "golang.org/x/text", "0.40.0", "--canary", "repos/api"}, "goes down"},
		"a rollout bump down":   {[]string{"deps", "bump", "golang.org/x/text", "0.42.0", "--canary", "repos/api", "--rollout", "repos/old"}, "goes down"},
		"no canary":             {[]string{"deps", "bump", "golang.org/x/text", "0.42.0"}, "needs --canary"},
		"the project as canary": {[]string{"deps", "bump", "golang.org/x/text", "0.42.0", "--canary", "."}, "not a leaf of the project"},
		"a folder outside":      {[]string{"deps", "bump", "golang.org/x/text", "0.42.0", "--canary", t.TempDir()}, "not inside the project"},
		"a package not there":   {[]string{"deps", "bump", "golang.org/x/other", "1.0.0", "--canary", "repos/api"}, "requires no package"},
		"a pre-release":         {[]string{"deps", "bump", "golang.org/x/text", "0.42.0-rc.1", "--canary", "repos/api"}, "pre-release"},
		"an option as package":  {[]string{"deps", "bump", "--", "-g", "0.42.0", "--canary", "repos/api"}, "not a package name"},
		"too few arguments":     {[]string{"deps", "bump", "golang.org/x/text", "--canary", "repos/api"}, "want 2 argument(s)"},
		"another subcommand":    {[]string{"deps", "audit"}, "usage:"},
	}
	for name, c := range cases {
		if code, out, errOut := ygg(t, append(c.args, common...)...); code != ExitRefused || !strings.Contains(errOut, c.want) {
			t.Errorf("%s: exit %d, want 2 and %q:\n%s%s", name, code, c.want, out, errOut)
		}
	}
	if mod(t, dir, "api") != goMod("0.41.0") || mod(t, dir, "old") != goMod("0.43.0") || bumpLedger(t, dir) != "" {
		t.Error("a refusal changed a file or wrote a ledger")
	}
	if _, err := os.Stat(filepath.Join(dir, ".factory", "deps")); !os.IsNotExist(err) {
		t.Errorf("a refusal left the folder of a bump: %v", err)
	}
}

func TestDepsBumpRunsToolAndChecksInTheSandboxOfEachLeafAndStopsIt(t *testing.T) {
	dir, config := depsProject(t, goStack)
	fake := &sandboxfake.Sandbox{}
	old := newDepsSandbox
	newDepsSandbox = func(engine string, cfg sandbox.Config, work string) (gungnir.Sandbox, error) { return fake, nil }
	t.Cleanup(func() { newDepsSandbox = old })
	code, out, errOut := ygg(t, "deps", "bump", "golang.org/x/text", "0.42.0", "--project", dir, "--config", config, "--canary", "repos/api", "--rollout", "repos/web")
	if code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	if len(fake.Ups) != 2 || len(fake.Downs) != 2 {
		t.Fatalf("ups %d, downs %d", len(fake.Ups), len(fake.Downs))
	}
	up := fake.Ups[0]
	if up.Name != "repos/api" || up.Stack != goStack || strings.Join(up.Egress, ",") != "proxy.golang.org" || up.GitDir == "" || up.Leaf != filepath.Join(dir, "repos/api") || up.Scratch {
		t.Errorf("sandbox of the canary: %+v", up)
	}
	if fake.Ups[1].Name != "repos/web" || fake.Ups[1].Run != up.Run {
		t.Errorf("sandbox of the rollout product: %+v", fake.Ups[1])
	}
	var tools []string
	for _, c := range fake.Execs {
		tools = append(tools, strings.Join(c.Argv, " "))
	}
	if got := strings.Join(tools, "|"); got != "go get golang.org/x/text@v0.42.0|test -f go.mod|test -f ok.txt|go get golang.org/x/text@v0.42.0|test -f go.mod|test -f ok.txt" {
		t.Errorf("commands in the sandboxes: %s", got)
	}
}
```

**Step: the end of the task.**

```bash
gofmt -l .                       # prints nothing
go vet ./...
go test -count=1 -race ./...     # every package ok
```

**Evidence (v0-T259):** built and run in the reference workspace on 2026-10-18 as the six commits above on branch `grader/odin` of `odin` (not pushed), through `go.work` (the local Gungnir with the events of v0-T245). Parts 1, 2, 3 and 5 had a red step with a build failure as shown. Parts 4 and 6 pin behavior of the code before them. `gofmt -l .` and `go vet ./...` print nothing. `go test -count=1 -race ./...` passes in every package of `odin` (`internal/cli` 47.7 s, `internal/engine` 112 s, `internal/deps` 6.2 s). The real `go` (1.26.4) ran in the two tests of `bump_go_test.go` with no network: a canary and a rollout product moved from 1.0.0 to 1.0.1 and the ledger had four lines; a canary moved to 1.1.0 failed its `unit` rung (`go build` fails, `F` is gone), was restored with every file of both products as before, and the ledger had two lines (`deps_checked` pass, `deps_bump` canary fail). Five mutations of `bump.go` were tried, each undone with `git checkout`, and each failed the tests named for it: the restore made never to run (five tests failed, among them `TestACanaryThatFailsIsPutBackByteForByteAndNoRolloutProductIsTouched` and the real-go canary test); the `break` after a failed product removed (three tests failed: the canary test, the rollout test and the real-go test); the check for files outside the manifest made never true (`TestAToolThatChangesAPolicyFileFailsTheProductAndTheFileIsPutBack` failed); the downgrade refusal made never true (`TestARefusalChangesNothingAndOpensNothing` failed); a failed `unit` check read as a pass (three tests failed). One real bug was found by a test and fixed in part 2: a walk that skipped a `.git` file with `SkipDir` skipped its whole folder. Not run: the real `npm` (decision 11); a real sandbox engine (the sandbox is the fake; the same `Up`, `Bind` and `Down` calls that a run makes); a real bump of a web or Go product of the factory (the policy rungs of v0-T257 and v0-T258 ran only in their own tests). `GOWORK=off go test` waits for the pins of v0-T245 (the pinned `gungnir` has no `EventDepsBump`).

### Exit state of this part

- `ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>...]` exists, with exit codes 0, 1 and 2, in `odin`.
- A canary failure leaves every file as it was and writes one `deps_bump` line with stage `canary` and verdict `fail`. A pass writes `deps_bump` stage `canary` verdict `pass`, then one line for each rollout product.
- Open questions for the founder: decisions 1, 3, 4 (doctor and status), 5 (a bump does not commit) and 12.

### Task v0-T260: the two-tenant authorisation harness: every route with a resource id has a registered cross-tenant test

Spec §9.5 rung 4: "every OpenAPI route that takes a resource ID MUST have a registered test. In that test, user B requests user A's resource and gets 403/404." This task builds the harness in the Go realm.

How it works. A route takes a resource id when a variable of its path is named `id`, or ends in `Id`, `ID`, `_id` or `-id`. A reader of `openapi.yaml`, `ygg-authz`, lists every operation of such a route and the test it needs: `TestCrossTenant<OperationId>` (first letter of the `operationId` in capitals). The template gets a small package, `internal/authztest`, with one function, `Check(t, handler, Case{Operation, Request})`. `Check` sends the request as `user-a` and as `user-b`. User A must get a 2xx, so the test names a resource that is there. User B must get 403 or 404, and nothing else: a 401 or a 5xx does not count. `Check` also fails when the test has the wrong name, and prints one line `YGG-AUTHZ {json}` with both answers. The script `go-authz.sh` runs `go test -json -run '^TestCrossTenant' ./...` and hands the JSON to `ygg-authz check`. A route is covered only when its test passed, and a line for that operation and that test says A got 2xx and B got 403 or 404. An empty test, a skipped test, a test that checks another operation, a leaf that does not compile, a missing `operationId` or a duplicate one all fail, with a message.

The registry. `authz.json` is optional: `{"schema":"ygg.authz/v1","public":{"<operationId>":"<reason>"}}`. A route listed there is excused and printed on every run with its reason, so a reviewer sees it. An entry for an operation that does not exist, for a route with no resource id, or with fewer than two words of reason is an error: a stale excuse is not kept.

Why a reader in Go and not YAML in bash: an OpenAPI file has flow style, quotes and references, and a hand parser can be made to miss a route. `ygg-authz` uses `go.yaml.in/yaml/v3` (already in this realm's `go.sum`), and fails closed on anything it cannot read (a path item that is a `$ref`, duplicate keys, a document with no paths). The Containerfile builds it from `devcontainer/checks/lib/authz` into `/usr/local/bin`, root-owned, with `-mod=readonly`, so only the version and hash in its `go.sum` build.

Why a rung of its own, `authz`, and not a part of `security`: it compiles and runs the leaf's tests, so it is the slow half of rung 4, and its findings (a route name and a status) are a different kind from a CVE. It sits right after `security` in the leaf's list, before `integration`. The cross-tenant tests are plain tests (no `integration` tag), so they also run in rung 2, with the race detector. A route that needs the real database to show its isolation is tested in the handler with the store faked; the integration rung can add more.

**Limit, in plain words.** A test in the leaf can print a fake `YGG-AUTHZ` line, and the leaf writes `authztest` itself. The harness stops the case where nobody wrote the test, or the test never asked user B, or user B got the resource. It does not stop a hostile author. The reviewers of rung 6 read the test. Putting `authztest` in the image would not help: the leaf's test controls the handler and the requests.

**Files (in `helheim-go`):**

- Create: `authz_test.go`
- Modify: `devcontainer/Containerfile`
- Create: `devcontainer/checks/go-authz.sh`
- Create: `devcontainer/checks/lib/authz/go.mod`
- Create: `devcontainer/checks/lib/authz/go.sum`
- Create: `devcontainer/checks/lib/authz/main.go`
- Modify: `docs/architecture.md`
- Modify: `pack.yaml`
- Modify: `pack_test.go`
- Modify: `prompts/implementer.md`
- Modify: `templates/api/AGENTS.md`
- Create: `templates/api/internal/authztest/authztest.go`
- Create: `templates/api/internal/authztest/authztest_test.go`

**Interfaces:**

- Consumes: `openapi.yaml` of the leaf (the contract it owns); the module-cache check of the other Go rungs; the `go.yaml.in/yaml/v3 v3.0.5` hashes of the realm's `go.sum`.
- Produces: the check `authz` in `pack.yaml` (`/opt/ygg/checks/go-authz.sh`); the command `ygg-authz plan|check` (stdout lines `require <op> <METHOD> <path> <test>`, `public <op>: <reason>`, `covered <op> (<test>: user A <n>, user B <n>)`, `missing <op> <METHOD> <path>: <why>`, then `authz: ok` or `authz: N problem(s)`); `authztest.Check`, `authztest.Case`, `authztest.T`, `authztest.UserA`, `authztest.UserB`, `authztest.Out`; the registry schema `ygg.authz/v1`; a rule in the template's `AGENTS.md` and the implementer prompt.

**Acceptance criteria:**

- [ ] A covered route passes and prints `covered getPhoto (TestCrossTenantGetPhoto: user A 200, user B 404)`; 403 also passes. A route with no resource id (`/healthz`) is never asked for a test.
- [ ] A route with no test fails: `missing getPhoto GET /photos/{photoId}: no passing test TestCrossTenantGetPhoto`. A test of another name does not cover it.
- [ ] User B getting 200, 500 or 401 fails. User A not getting a 2xx fails (in `authztest`).
- [ ] A test with the right name that is empty, is skipped, or checks another operation fails. A leaf that does not compile fails.
- [ ] Routes are read from block and flow YAML, with `{id}`, `{galleryId}`, `{item_id}` and `{photoID}` found and `{token}` not.
- [ ] A spec without `operationId` on a resource route, with a duplicate one, with a bad one, with a path item `$ref`, with no paths, or that is not YAML, fails. A leaf with no `openapi.yaml` fails.
- [ ] A registry excuses a named route and prints it, refuses a stale or reasonless entry, another schema or an unknown field, and does not excuse any other route.
- [ ] A contract with no resource route passes with `authz: no route takes a resource id` and runs no test. The unchanged template passes.
- [ ] A tampered module cache stops the rung.
- [ ] `authztest.Check` rejects a test named for another operation, accepts a subtest of the right test, and writes the `YGG-AUTHZ` line.
- [ ] The image builds `ygg-authz` and the rung works inside it (Evidence).

**Review focus pinned:** 1 (a check an agent can weaken: the reader is built into a root-owned path from pinned source; the limit above is stated); the proposed new line of v0-T257; 2 (an unpinned input of the image: `go build -mod=readonly` from a `go.sum`, pinned by `TestTheAuthzRungIsInThePackAndTheImageBuildsItsToolFromPinnedSource`). The spec's rule "authorisation MUST NOT rely on middleware alone" (§9.6) is what `Check` tests: it calls the handler the server runs.

**Named test:** `go test . -run 'Authz' && (cd templates/api && go test ./internal/authztest/)` in `helheim-go`. **Layer:** `helheim-go`. **Size:** L. **Depends on:** v0-T257 (the pack list).

- [ ] **Step 1:** write the tests: create `authz_test.go` and `templates/api/internal/authztest/authztest_test.go`.
- [ ] **Step 2:** run and see them fail.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/helheim-go
go test -count=1 -run 'Authz' . 2>&1 | tail -5
```

Expected: `FAIL`, because `devcontainer/checks/lib/authz` has no Go files (the tool cannot be built) and `templates/api/internal/authztest/authztest.go` does not exist.

- [ ] **Step 3:** write `authztest.go`, the tool (`go.mod`, `go.sum`, `main.go`), the script (`chmod +x`), and apply the patches (Containerfile, pack, pack test, docs, template rule, prompt).
- [ ] **Step 4:** run the named test. Expect `ok`.

```bash
gofmt -l . ; go vet ./... && go test -count=1 -run 'Authz' -v . 2>&1 | grep -E '^(--- |ok|FAIL)'
(cd templates/api && go test -count=1 ./internal/authztest/)
```

Expected: twelve `--- PASS` lines (`TestAuthzPassesWhenEveryRouteWithAResourceIdHasACrossTenantTest`, `…FailsWhenARouteWithAResourceIdHasNoTest`, `…FailsWhenUserBGetsTheResource`, `…FailsOnATestThatNamesTheRightNameAndChecksNothing`, `…FailsWhenTheLeafDoesNotCompile`, `…ReadsTheRoutesWhateverTheShapeOfTheYAML`, `…RefusesASpecItCannotReadWholly`, `…ListsAPublicRouteFromTheRegistryAndRefusesAStaleOne`, `…HasNothingToDoForAContractWithoutAResourceId`, `…PassesTheUnchangedTemplate`, `…RefusesATamperedModuleCache`, `TestTheAuthzRungIsInThePackAndTheImageBuildsItsToolFromPinnedSource`), `ok  github.com/ouroboric-dev/helheim-go`, then `ok  api/internal/authztest`. The first build of the tool needs the module proxy once; the tests skip when it is not there, unless `YGG_REQUIRE_TEMPLATES` is set.

- [ ] **Step 5:** the whole suite, which includes the template's own lint (`golangci-lint` with `gosec`: the template code was changed until it passed it) when `golangci-lint` is installed.

```bash
GOWORK=off go test -race ./...
```

Expected: `ok  github.com/ouroboric-dev/helheim-go`.

- [ ] **Step 6:** build the stack image and run the rung inside it (the founder's engine; the reference run used rootless Podman). Use any leaf with the route `GET /photos/{photoId}`, operation `getPhoto`.

```bash
podman build -t localhost/ygg-helheim-go-probe -f devcontainer/Containerfile devcontainer
# in a leaf without the test:
/opt/ygg/checks/go-authz.sh
```

Expected, exit 1:

```text
== routes with a resource id
require getPhoto GET /photos/{photoId} TestCrossTenantGetPhoto
== cross-tenant tests
missing getPhoto GET /photos/{photoId}: no passing test TestCrossTenantGetPhoto
authz: 1 problem(s)
```

With `TestCrossTenantGetPhoto` added (it calls `authztest.Check`), exit 0:

```text
== routes with a resource id
require getPhoto GET /photos/{photoId} TestCrossTenantGetPhoto
== cross-tenant tests
covered getPhoto (TestCrossTenantGetPhoto: user A 200, user B 404)
authz: ok
```

**The files.**

**New file `authz_test.go`**

```go
package helheim

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

// go-authz.sh is the two-tenant authorisation harness (spec §9.5 rung 4, v0-T260): every route of openapi.yaml
// that takes a resource id has a test TestCrossTenant<OperationId> that passes, in which user B asks for user
// A's resource and gets 403 or 404 while user A gets it. These tests run it on small leaves, with the real go and
// the real ygg-authz (built here from devcontainer/checks/lib/authz, as the Containerfile builds it).

var (
	authzOnce sync.Once
	authzBin  string
	authzErr  error
)

// authzTool builds ygg-authz once and returns the folder that holds it. The build needs the module proxy
// the first time; the test skips when it is not there, unless YGG_REQUIRE_TEMPLATES is set.
func authzTool(t *testing.T) string {
	t.Helper()
	authzOnce.Do(func() {
		authzBin, authzErr = os.MkdirTemp("", "ygg-authz")
		if authzErr != nil {
			return
		}
		src, _ := filepath.Abs(filepath.Join("devcontainer", "checks", "lib", "authz"))
		cmd := exec.Command("go", "build", "-o", filepath.Join(authzBin, "ygg-authz"), ".")
		cmd.Dir = src
		cmd.Env = append(os.Environ(), "GOWORK=off", "GOFLAGS=-mod=readonly")
		if out, err := cmd.CombinedOutput(); err != nil {
			authzErr = &buildError{err, string(out)}
		}
	})
	if authzErr != nil {
		if os.Getenv("YGG_REQUIRE_TEMPLATES") != "" {
			t.Fatal(authzErr)
		}
		t.Skipf("ygg-authz can't be built (set YGG_REQUIRE_TEMPLATES to fail instead): %v", authzErr)
	}
	return authzBin
}

type buildError struct {
	err error
	out string
}

func (e *buildError) Error() string { return e.err.Error() + "\n" + e.out }

const photosAPI = `openapi: 3.1.0
info: {title: API, version: 0.1.0}
paths:
  /healthz:
    get:
      operationId: getHealth
      responses: {"200": {description: ok}}
  /photos/{photoId}:
    get:
      operationId: getPhoto
      responses: {"200": {description: ok}}
`

const photosCode = `package photos

import "net/http"

// Handler serves GET /photos/{photoId}. The photo p1 is user-a's. leak makes the handler answer anyone.
func Handler(leak bool, other int) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /photos/{photoId}", func(w http.ResponseWriter, r *http.Request) {
		if leak || r.Header.Get("X-User") == "user-a" {
			w.WriteHeader(http.StatusOK)
			return
		}
		w.WriteHeader(other)
	})
	return mux
}
`

// crossTenant is the test a leaf writes for an operation, with a handler it is given.
func crossTenant(op, handler string) string {
	return `package photos

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"api/internal/authztest"
)

func TestCrossTenant` + strings.ToUpper(op[:1]) + op[1:] + `(t *testing.T) {
	authztest.Check(t, ` + handler + `, authztest.Case{Operation: "` + op + `", Request: func(user string) *http.Request {
		r := httptest.NewRequest(http.MethodGet, "/photos/p1", nil)
		r.Header.Set("X-User", user)
		return r
	}})
}
`
}

// authzLeaf is a leaf with the authztest package of the template, the photos handler and the given extra files.
func authzLeaf(t *testing.T, files map[string]string) string {
	t.Helper()
	all := map[string]string{
		"go.mod":                      "module api\n\ngo 1.26\n",
		"openapi.yaml":                photosAPI,
		"internal/photos/photos.go":   photosCode,
		"internal/authztest/check.go": mustRead(t, filepath.Join("templates", "api", "internal", "authztest", "authztest.go")),
	}
	for k, v := range files {
		all[k] = v
	}
	return leaf(t, all)
}

func mustRead(t *testing.T, p string) string {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func runAuthz(t *testing.T, dir string, env ...string) (int, string) {
	t.Helper()
	return script(t, dir, authzTool(t), "go-authz.sh", env...)
}

func TestAuthzPassesWhenEveryRouteWithAResourceIdHasACrossTenantTest(t *testing.T) {
	dir := authzLeaf(t, map[string]string{"internal/photos/photos_test.go": crossTenant("getPhoto", "Handler(false, http.StatusNotFound)")})
	code, out := runAuthz(t, dir)
	if code != 0 || !strings.Contains(out, "covered getPhoto (TestCrossTenantGetPhoto: user A 200, user B 404)") || !strings.Contains(out, "authz: ok") {
		t.Fatalf("a covered route: exit %d\n%s", code, out)
	}
	if strings.Contains(out, "getHealth") {
		t.Errorf("a route with no resource id was asked for a test:\n%s", out)
	}
	dir = authzLeaf(t, map[string]string{"internal/photos/photos_test.go": crossTenant("getPhoto", "Handler(false, http.StatusForbidden)")})
	if code, out := runAuthz(t, dir); code != 0 || !strings.Contains(out, "user B 403") {
		t.Errorf("a 403: exit %d\n%s", code, out)
	}
}

func TestAuthzFailsWhenARouteWithAResourceIdHasNoTest(t *testing.T) {
	dir := authzLeaf(t, nil)
	code, out := runAuthz(t, dir)
	if code == 0 || !strings.Contains(out, "missing getPhoto GET /photos/{photoId}: no passing test TestCrossTenantGetPhoto") || !strings.Contains(out, "authz: 1 problem(s)") {
		t.Errorf("a route with no test: exit %d\n%s", code, out)
	}
	// A test for some other route does not cover this one.
	other := strings.ReplaceAll(crossTenant("getPhoto", "Handler(false, http.StatusNotFound)"), "TestCrossTenantGetPhoto", "TestCrossTenantListPhotos")
	if code, out := runAuthz(t, authzLeaf(t, map[string]string{"internal/photos/photos_test.go": other})); code == 0 || !strings.Contains(out, "no passing test TestCrossTenantGetPhoto") {
		t.Errorf("a test of another name: exit %d\n%s", code, out)
	}
}

func TestAuthzFailsWhenUserBGetsTheResource(t *testing.T) {
	for name, handler := range map[string]string{
		"a leak":          "Handler(true, http.StatusNotFound)",
		"a server error":  "Handler(false, http.StatusInternalServerError)",
		"an unauthorised": "Handler(false, http.StatusUnauthorized)",
	} {
		dir := authzLeaf(t, map[string]string{"internal/photos/photos_test.go": crossTenant("getPhoto", handler)})
		if code, out := runAuthz(t, dir); code == 0 || !strings.Contains(out, "getPhoto") {
			t.Errorf("%s: exit %d\n%s", name, code, out)
		}
	}
}

func TestAuthzFailsOnATestThatNamesTheRightNameAndChecksNothing(t *testing.T) {
	cases := map[string]string{
		"an empty test": "package photos\n\nimport \"testing\"\n\nfunc TestCrossTenantGetPhoto(t *testing.T) {}\n",
		"a skipped one": "package photos\n\nimport \"testing\"\n\nfunc TestCrossTenantGetPhoto(t *testing.T) { t.Skip(\"later\") }\n",
		"a check for another operation": strings.Replace(crossTenant("getPhoto", "Handler(false, http.StatusNotFound)"),
			`Operation: "getPhoto"`, `Operation: "listPhotos"`, 1),
	}
	for name, body := range cases {
		dir := authzLeaf(t, map[string]string{"internal/photos/photos_test.go": body})
		code, out := runAuthz(t, dir)
		if code == 0 || !strings.Contains(out, "missing getPhoto") {
			t.Errorf("%s: exit %d\n%s", name, code, out)
		}
	}
}

func TestAuthzFailsWhenTheLeafDoesNotCompile(t *testing.T) {
	dir := authzLeaf(t, map[string]string{"internal/photos/photos_test.go": "package photos\n\nfunc TestCrossTenantGetPhoto(t *testing.T) {\n"})
	if code, out := runAuthz(t, dir); code == 0 || !strings.Contains(out, "missing getPhoto") {
		t.Errorf("a leaf that does not compile: exit %d\n%s", code, out)
	}
}

func TestAuthzReadsTheRoutesWhateverTheShapeOfTheYAML(t *testing.T) {
	spec := `openapi: 3.1.0
info: {title: API, version: 0.1.0}
paths: {
  "/a/{id}": {get: {operationId: getA}, delete: {operationId: deleteA}},
  "/b/{galleryId}/items/{item_id}": {put: {operationId: putItem}},
  "/c/{token}": {get: {operationId: getByToken}},
  "/d/{photoID}":
    {post: {operationId: postD}},
  "/e": {get: {operationId: listE}}}
`
	dir := authzLeaf(t, map[string]string{"openapi.yaml": spec})
	_, out := runAuthz(t, dir)
	for _, want := range []string{"require getA GET /a/{id} TestCrossTenantGetA", "require deleteA DELETE /a/{id} TestCrossTenantDeleteA",
		"require putItem PUT /b/{galleryId}/items/{item_id} TestCrossTenantPutItem", "require postD POST /d/{photoID} TestCrossTenantPostD"} {
		if !strings.Contains(out, want) {
			t.Errorf("the plan lacks %q:\n%s", want, out)
		}
	}
	for _, not := range []string{"getByToken", "listE"} {
		if strings.Contains(out, "require "+not) {
			t.Errorf("a route with no resource id is required to have a test: %s\n%s", not, out)
		}
	}
}

func TestAuthzRefusesASpecItCannotReadWholly(t *testing.T) {
	cases := map[string]struct{ spec, want string }{
		"no operationId":     {"openapi: 3.1.0\npaths:\n  /a/{id}:\n    get:\n      responses: {}\n", "GET /a/{id} has no operationId"},
		"a duplicate id":     {"openapi: 3.1.0\npaths:\n  /a/{id}:\n    get: {operationId: x}\n    put: {operationId: x}\n", "operationId x is used twice"},
		"a bad operation id": {"openapi: 3.1.0\npaths:\n  /a/{id}:\n    get: {operationId: get-a}\n", "operationId get-a"},
		"a path item ref":    {"openapi: 3.1.0\npaths:\n  /a/{id}:\n    $ref: other.yaml\n", "/a/{id} is a $ref"},
		"no paths":           {"openapi: 3.1.0\n", "has no paths"},
		"not yaml":           {"paths: [\n", "openapi.yaml"},
	}
	for name, c := range cases {
		code, out := runAuthz(t, authzLeaf(t, map[string]string{"openapi.yaml": c.spec}))
		if code == 0 || !strings.Contains(out, c.want) {
			t.Errorf("%s: exit %d, want %q in\n%s", name, code, c.want, out)
		}
	}
	// A leaf with no contract has nothing to check against: the contract rung says so, and so does this one.
	dir := leaf(t, map[string]string{"go.mod": goMod})
	if code, out := runAuthz(t, dir); code == 0 || !strings.Contains(out, "no openapi.yaml") {
		t.Errorf("no openapi.yaml: exit %d\n%s", code, out)
	}
}

func TestAuthzListsAPublicRouteFromTheRegistryAndRefusesAStaleOne(t *testing.T) {
	spec := photosAPI + "  /shares/{shareId}:\n    get:\n      operationId: getShare\n      responses: {\"200\": {description: ok}}\n"
	files := map[string]string{
		"openapi.yaml":                   spec,
		"internal/photos/photos_test.go": crossTenant("getPhoto", "Handler(false, http.StatusNotFound)"),
		"authz.json":                     `{"schema":"ygg.authz/v1","public":{"getShare":"a share link is the capability: whoever holds it may read"}}`,
	}
	code, out := runAuthz(t, authzLeaf(t, files))
	if code != 0 || !strings.Contains(out, "public getShare: a share link is the capability") {
		t.Errorf("a public route: exit %d\n%s", code, out)
	}
	for name, reg := range map[string]string{
		"a route that is not there":    `{"schema":"ygg.authz/v1","public":{"getShare":"x y","getNothing":"gone"}}`,
		"a route that is not resource": `{"schema":"ygg.authz/v1","public":{"getShare":"x y","getHealth":"no id"}}`,
		"no reason":                    `{"schema":"ygg.authz/v1","public":{"getShare":""}}`,
		"another schema":               `{"schema":"ygg.authz/v2","public":{}}`,
		"an unknown field":             `{"schema":"ygg.authz/v1","public":{},"skip":["getPhoto"]}`,
	} {
		files["authz.json"] = reg
		if code, out := runAuthz(t, authzLeaf(t, files)); code == 0 || !strings.Contains(out, "authz.json") {
			t.Errorf("%s: exit %d\n%s", name, code, out)
		}
	}
	// The exemption does not cover a route that is not named in it.
	files["authz.json"] = `{"schema":"ygg.authz/v1","public":{"getShare":"a share link is the capability"}}`
	delete(files, "internal/photos/photos_test.go")
	if code, out := runAuthz(t, authzLeaf(t, files)); code == 0 || !strings.Contains(out, "missing getPhoto") {
		t.Errorf("a public route hid another: exit %d\n%s", code, out)
	}
}

func TestAuthzHasNothingToDoForAContractWithoutAResourceId(t *testing.T) {
	spec := "openapi: 3.1.0\ninfo: {title: API, version: 0.1.0}\npaths:\n  /healthz:\n    get:\n      operationId: getHealth\n      responses: {\"200\": {description: ok}}\n"
	dir := authzLeaf(t, map[string]string{"openapi.yaml": spec})
	if code, out := runAuthz(t, dir); code != 0 || !strings.Contains(out, "no route takes a resource id") {
		t.Errorf("exit %d\n%s", code, out)
	}
}

func TestAuthzPassesTheUnchangedTemplate(t *testing.T) {
	dir := copyTemplate(t, "api")
	needModules(t, dir)
	if code, out := runAuthz(t, dir); code != 0 || !strings.Contains(out, "no route takes a resource id") {
		t.Errorf("the template: exit %d\n%s", code, out)
	}
}

func TestAuthzRefusesATamperedModuleCache(t *testing.T) {
	proxyURL := proxyModule(t, "example.invalid/dep", "v1.0.0", "package dep\n\nfunc D() int { return 1 }\n")
	cache := t.TempDir()
	t.Cleanup(func() { _ = exec.Command("chmod", "-R", "u+w", cache).Run() })
	env := []string{"GOMODCACHE=" + cache, "GOPROXY=" + proxyURL, "GOSUMDB=off", "GONOSUMDB=*"}
	dir := authzLeaf(t, map[string]string{
		"go.mod":                         "module api\n\ngo 1.26\n\nrequire example.invalid/dep v1.0.0\n",
		"internal/photos/photos_test.go": crossTenant("getPhoto", "Handler(false, http.StatusNotFound)"),
		"dep.go":                         "package api\n\nimport _ \"example.invalid/dep\"\n",
	})
	tidy := exec.Command("go", "mod", "tidy")
	tidy.Dir = dir
	tidy.Env = append(os.Environ(), append(env, "GOWORK=off", "GOFLAGS=-mod=mod")...)
	if out, err := tidy.CombinedOutput(); err != nil {
		t.Fatalf("go mod tidy: %v\n%s", err, out)
	}
	if _, out := runAuthz(t, dir, env...); strings.Contains(out, "module cache") {
		t.Errorf("an untouched cache was refused:\n%s", out)
	}
	if err := exec.Command("chmod", "-R", "u+w", cache).Run(); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(cache, "example.invalid", "dep@v1.0.0", "evil.go"), []byte("package dep\n\nimport \"os\"\n\nfunc init() { os.Exit(0) }\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if code, out := runAuthz(t, dir, env...); code == 0 || !strings.Contains(out, "module cache") {
		t.Errorf("a dependency edited in the cache: exit %d\n%s", code, out)
	}
}

func TestTheAuthzRungIsInThePackAndTheImageBuildsItsToolFromPinnedSource(t *testing.T) {
	pack, _ := os.ReadFile("pack.yaml")
	if !strings.Contains(string(pack), "authz: [/opt/ygg/checks/go-authz.sh]") || !strings.Contains(string(pack), "security, authz, integration]") {
		t.Error("pack.yaml does not run go-authz.sh as the check authz, after security")
	}
	cf := mustRead(t, filepath.Join("devcontainer", "Containerfile"))
	for _, want := range []string{"COPY checks/lib/authz/ /tmp/ygg-authz/", "-mod=readonly", "-o /usr/local/bin/ygg-authz"} {
		if !strings.Contains(cf, want) {
			t.Errorf("the Containerfile lacks %q", want)
		}
	}
	mod := mustRead(t, filepath.Join("devcontainer", "checks", "lib", "authz", "go.mod"))
	sum := mustRead(t, filepath.Join("devcontainer", "checks", "lib", "authz", "go.sum"))
	if !strings.Contains(mod, "go.yaml.in/yaml/v3 v3.0.5") || !strings.Contains(sum, "go.yaml.in/yaml/v3 v3.0.5 h1:") {
		t.Error("the tool's module does not pin go.yaml.in/yaml/v3 with its hash in go.sum")
	}
}

// The rung reads the answers from the output of the leaf's tests, and a test of the leaf can print anything. A
// test that skips authztest.Check and reports what it likes must still be judged by what it reports.
func TestAuthzDoesNotTrustALeafTestThatReportsWhatItLikes(t *testing.T) {
	forged := func(a, b string) string {
		return strings.NewReplacer("AAA", a, "BBB", b).Replace("package photos\n\nimport (\n\t\"fmt\"\n\t\"testing\"\n)\n\n" +
			"func TestCrossTenantGetPhoto(t *testing.T) {\n\tfmt.Println(\"YGG-AUTHZ {\\\"operation\\\":\\\"getPhoto\\\",\\\"test\\\":\\\"TestCrossTenantGetPhoto\\\",\\\"a\\\":AAA,\\\"b\\\":BBB}\")\n}\n")
	}
	if code, out := runAuthz(t, authzLeaf(t, map[string]string{"internal/photos/photos_test.go": forged("200", "404")})); code != 0 {
		t.Fatalf("a test that reports user A 200 and user B 404 (the control): exit %d\n%s", code, out)
	}
	for name, body := range map[string]string{
		"user B got the photo":      forged("200", "200"),
		"user B was not signed in":  forged("200", "401"),
		"user B met a server error": forged("200", "500"),
		"user A got nothing":        forged("404", "404"),
		"user A was refused":        forged("403", "404"),
	} {
		code, out := runAuthz(t, authzLeaf(t, map[string]string{"internal/photos/photos_test.go": body}))
		if code == 0 || !strings.Contains(out, "missing getPhoto") {
			t.Errorf("%s: exit %d\n%s", name, code, out)
		}
	}
}
```

**New file `devcontainer/checks/go-authz.sh`**

```bash
#!/bin/bash
# Rung 4 of the ladder for a Go leaf, the two-tenant authorisation harness (spec §9.5; v0-T260): every route of
# openapi.yaml that takes a resource id has a test TestCrossTenant<OperationId> that passes, in which user B asks
# for user A's resource and gets 403 or 404 while user A gets it (internal/authztest.Check prints both answers). The
# only exceptions are the routes authz.json names as public, each with a reason, and they are listed here. The
# reader of the contract is ygg-authz, which the image builds into /usr/local/bin. Run in the leaf's top folder.
set -euo pipefail
# The tools are found in the image's root-owned folders only, never in one the agent can write (/go/bin).
export PATH="${YGG_CHECKS_PATH:-/usr/local/go/bin:/usr/local/bin:/usr/bin:/bin}"
[ -f openapi.yaml ] || { echo "authz: this leaf has no openapi.yaml, and it owns the contract of its API"; exit 1; }
args=(-spec openapi.yaml)
[ ! -f authz.json ] || args+=(-registry authz.json)
echo "== routes with a resource id"
plan="$(ygg-authz plan "${args[@]}")" || { echo "$plan"; exit 1; }
echo "$plan"
grep -q '^require ' <<<"$plan" || { echo "authz: no route takes a resource id"; exit 0; }
# The module cache is kept between runs and the agent can write it (see go-security.sh).
{ go mod download && go mod verify; } >/dev/null 2>&1 || {
  echo "the module cache does not match go.sum, a dependency in it was changed:"
  go mod verify 2>&1 || go mod download 2>&1 || true
  exit 1
}
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
echo "== cross-tenant tests"
# A failing test or a leaf that does not build is reported by ygg-authz from the JSON; stderr is shown on failure.
go test -count=1 -json -run '^TestCrossTenant' ./... >"$scratch/tests.json" 2>"$scratch/stderr" || true
if ! ygg-authz check "${args[@]}" -tests "$scratch/tests.json"; then
  cat "$scratch/stderr"
  exit 1
fi
```

**New file `devcontainer/checks/lib/authz/go.mod`**

```text
module ygg-authz

go 1.26

require go.yaml.in/yaml/v3 v3.0.5
```

**New file `devcontainer/checks/lib/authz/go.sum`**

```text
go.yaml.in/yaml/v3 v3.0.5 h1:N6y/pJk8buWs9NY5ERU2HSMfm+IuD/OtfdAnq6kESPw=
go.yaml.in/yaml/v3 v3.0.5/go.mod h1:HVTZu1O7/Vkt2N+BFy8Zza+lnLsABggaTM2ZpNIGuKg=
```

**New file `devcontainer/checks/lib/authz/main.go`**

```go
// Command ygg-authz is the reader of go-authz.sh, the two-tenant authorisation harness of the Go ladder
// (spec §9.5 rung 4, v0-T260). The image builds it from this folder, with the hash of its one dependency in
// go.sum, into /usr/local/bin where the agent cannot write.
//
//	ygg-authz plan  -spec openapi.yaml [-registry authz.json]
//	    lists every operation that takes a resource id and the test it needs
//	ygg-authz check -spec openapi.yaml [-registry authz.json] -tests go-test.json
//	    fails unless each of them has a passing TestCrossTenant<OperationId> in which user B got 403 or 404 and
//	    user A got the resource. The answers are lines "YGG-AUTHZ {json}" that authztest.Check printed, which
//	    go test -json carries in the output of the test
//
// A route takes a resource id when a variable of its path is named id, or ends in Id, ID, _id or -id.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"regexp"
	"sort"
	"strings"

	"go.yaml.in/yaml/v3"
)

type operation struct{ ID, Method, Path, Test string }

var (
	pathVar  = regexp.MustCompile(`\{([^{}]+)\}`)
	idName   = regexp.MustCompile(`^(id|.*(Id|ID|_id|-id))$`)
	opName   = regexp.MustCompile(`^[A-Za-z][A-Za-z0-9]*$`)
	methods  = []string{"get", "put", "post", "delete", "options", "head", "patch", "trace"}
	registry = struct {
		Schema string            `json:"schema"`
		Public map[string]string `json:"public"`
	}{}
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("usage: ygg-authz plan|check -spec openapi.yaml [-registry authz.json] [-tests go-test.json -report report.jsonl]")
		os.Exit(2)
	}
	fs := flag.NewFlagSet(os.Args[1], flag.ExitOnError)
	spec := fs.String("spec", "openapi.yaml", "the OpenAPI document")
	reg := fs.String("registry", "", "the registry of public routes")
	tests := fs.String("tests", "", "the output of go test -json")
	_ = fs.Parse(os.Args[2:])
	var more []string // output of failed tests, shown after the problems and not counted
	ops, public, problems := plan(*spec, *reg)
	switch os.Args[1] {
	case "plan":
		for _, o := range ops {
			fmt.Printf("require %s %s %s %s\n", o.ID, o.Method, o.Path, o.Test)
		}
		for _, id := range sortedKeys(public) {
			fmt.Printf("public %s: %s\n", id, public[id])
		}
	case "check":
		if len(problems) == 0 {
			problems, more = check(ops, *tests)
		}
	default:
		fmt.Printf("authz: unknown command %q\n", os.Args[1])
		os.Exit(2)
	}
	for _, p := range problems {
		fmt.Println(p)
	}
	if len(problems) > 0 {
		for _, l := range more {
			fmt.Println("  " + l)
		}
		fmt.Printf("authz: %d problem(s)\n", len(problems))
		os.Exit(1)
	}
	if os.Args[1] == "check" {
		fmt.Println("authz: ok")
	}
}

// plan reads the spec and the registry. ops are the operations that need a test, public the ones the registry
// excepts.
func plan(specPath, regPath string) (ops []operation, public map[string]string, problems []string) {
	raw, err := os.ReadFile(specPath)
	if err != nil {
		return nil, nil, []string{"authz: no " + specPath + ": " + err.Error()}
	}
	var doc struct {
		Paths map[string]yaml.Node `yaml:"paths"`
	}
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		return nil, nil, []string{"authz: " + specPath + " can't be read: " + err.Error()}
	}
	if len(doc.Paths) == 0 {
		return nil, nil, []string{"authz: " + specPath + " has no paths"}
	}
	seen := map[string]bool{}
	all := map[string]bool{}
	for path, node := range doc.Paths {
		var item map[string]yaml.Node
		if err := node.Decode(&item); err != nil {
			problems = append(problems, fmt.Sprintf("authz: %s can't be read: %v", path, err))
			continue
		}
		if _, ref := item["$ref"]; ref {
			problems = append(problems, fmt.Sprintf("authz: %s is a $ref; write the path item in the file, so that its routes can be read", path))
			continue
		}
		resource := false
		for _, m := range pathVar.FindAllStringSubmatch(path, -1) {
			resource = resource || idName.MatchString(m[1])
		}
		for _, m := range methods {
			n, ok := item[m]
			if !ok {
				continue
			}
			var op struct {
				ID string `yaml:"operationId"`
			}
			_ = n.Decode(&op)
			label := strings.ToUpper(m) + " " + path
			switch {
			case op.ID == "" && resource:
				problems = append(problems, fmt.Sprintf("authz: %s has no operationId; the test is named for it", label))
				continue
			case op.ID == "":
				continue
			case !opName.MatchString(op.ID):
				problems = append(problems, fmt.Sprintf("authz: operationId %s of %s must be letters and digits, starting with a letter", op.ID, label))
				continue
			case seen[op.ID]:
				problems = append(problems, fmt.Sprintf("authz: operationId %s is used twice", op.ID))
				continue
			}
			seen[op.ID] = true
			all[op.ID] = resource
			if resource {
				ops = append(ops, operation{op.ID, strings.ToUpper(m), path, "TestCrossTenant" + strings.ToUpper(op.ID[:1]) + op.ID[1:]})
			}
		}
	}
	if regPath != "" {
		public, problems = readRegistry(regPath, all, problems)
	}
	var required []operation
	for _, o := range ops {
		if _, ok := public[o.ID]; !ok {
			required = append(required, o)
		}
	}
	sort.Strings(problems)
	sort.Slice(required, func(i, j int) bool { return required[i].ID < required[j].ID })
	return required, public, problems
}

func readRegistry(path string, all map[string]bool, problems []string) (map[string]string, []string) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, append(problems, "authz: "+path+": "+err.Error())
	}
	dec := json.NewDecoder(bytes.NewReader(b))
	dec.DisallowUnknownFields()
	r := registry
	if err := dec.Decode(&r); err != nil {
		return nil, append(problems, "authz: "+path+" is not a registry: "+err.Error())
	}
	if r.Schema != "ygg.authz/v1" {
		return nil, append(problems, fmt.Sprintf("authz: %s has schema %q, want ygg.authz/v1", path, r.Schema))
	}
	for id, why := range r.Public {
		switch resource, there := all[id]; {
		case !there:
			problems = append(problems, fmt.Sprintf("authz: %s names %s, which is no operation of the contract; remove it", path, id))
		case !resource:
			problems = append(problems, fmt.Sprintf("authz: %s names %s, which takes no resource id; remove it", path, id))
		case len(strings.Fields(why)) < 2:
			problems = append(problems, fmt.Sprintf("authz: %s gives %s no reason; say why anyone may read it", path, id))
		}
	}
	return r.Public, problems
}

type event struct {
	Action, Package, Test, Output string
}

type entry struct {
	Operation, Test string
	A, B            int
}

func check(ops []operation, testsPath string) (problems, more []string) {
	passed, entries, failedOut, err := readTests(testsPath)
	if err != nil {
		return []string{"authz: " + err.Error()}, nil
	}
	for _, o := range ops {
		label := fmt.Sprintf("%s %s %s", o.ID, o.Method, o.Path)
		var got *entry
		for i := range entries {
			if entries[i].Operation == o.ID && entries[i].Test == o.Test {
				got = &entries[i]
			}
		}
		switch {
		case !passed[o.Test]:
			problems = append(problems, fmt.Sprintf("missing %s: no passing test %s", label, o.Test))
		case got == nil:
			problems = append(problems, fmt.Sprintf("missing %s: %s passed without a request of user B; call authztest.Check with Operation %q", label, o.Test, o.ID))
		case got.A < 200 || got.A > 299:
			problems = append(problems, fmt.Sprintf("missing %s: user A got %d, want 2xx; use a resource of user A", label, got.A))
		case got.B != 403 && got.B != 404:
			problems = append(problems, fmt.Sprintf("missing %s: user B got %d, want 403 or 404", label, got.B))
		default:
			fmt.Printf("covered %s (%s: user A %d, user B %d)\n", o.ID, o.Test, got.A, got.B)
		}
	}
	if len(problems) > 0 {
		more = failedOut
	}
	return problems, more
}

// readTests returns the top-level tests that passed and the output that is not a pass: what failed, and what
// a package that did not build said.
func readTests(path string) (passed map[string]bool, entries []entry, out []string, err error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, nil, nil, err
	}
	defer f.Close()
	passed = map[string]bool{}
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1<<20), 1<<24)
	for sc.Scan() {
		var e event
		if json.Unmarshal(sc.Bytes(), &e) != nil {
			continue
		}
		top, _, _ := strings.Cut(e.Test, "/")
		switch {
		case e.Action == "pass" && e.Test != "" && e.Test == top:
			passed[top] = true
		case e.Action == "fail" && e.Test != "":
			delete(passed, top)
		case e.Action == "output" && strings.HasPrefix(e.Output, "YGG-AUTHZ "):
			var en entry
			if json.Unmarshal([]byte(strings.TrimPrefix(e.Output, "YGG-AUTHZ ")), &en) == nil {
				entries = append(entries, en)
			}
		case e.Action == "output" && strings.TrimSpace(e.Output) != "" && !strings.HasPrefix(e.Output, "=== ") &&
			!strings.HasPrefix(e.Output, "--- PASS") && !strings.HasPrefix(e.Output, "PASS") && !strings.HasPrefix(e.Output, "ok ") && !strings.HasPrefix(e.Output, "?") && !strings.HasPrefix(e.Output, "testing: warning"):
			out = append(out, strings.TrimRight(e.Output, "\n"))
		}
	}
	if len(out) > 40 {
		out = append(out[:40], "... more output left out")
	}
	return passed, entries, out, sc.Err()
}

func sortedKeys(m map[string]string) []string {
	var out []string
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}
```

**New file `templates/api/internal/authztest/authztest.go`**

```go
// Package authztest is the two-tenant check of the API: user B asks for a resource of user A and must not get
// it. Every route of openapi.yaml with a resource id in its path has a test named TestCrossTenant<OperationId>
// that calls Check (the factory's rung go-authz.sh fails without one). Check does not trust a middleware: it
// sends real requests to the handler the server runs.
package authztest

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
)

// The two users. Request builds a request for the one it is given, in whatever way the server knows a user.
const (
	UserA = "user-a"
	UserB = "user-b"
)

// T is the part of *testing.T that Check uses.
type T interface {
	Helper()
	Name() string
	Errorf(format string, args ...any)
}

// Case is one route. Operation is its operationId in openapi.yaml. Request builds a request for the resource
// of UserA, signed in as the user it is given.
type Case struct {
	Operation string
	Request   func(user string) *http.Request
}

// Check sends the request as UserA and as UserB. UserA must get a 2xx, so that the request names a resource
// that is there; UserB must get 403 or 404, and nothing else (a 401 says the request was not signed in, a 5xx
// says it failed). The calling test must be named TestCrossTenant<Operation>, with the first letter of the
// operationId in capitals. It also writes both answers to Out, for the factory to read.
func Check(t T, h http.Handler, c Case) {
	t.Helper()
	if c.Operation == "" || c.Request == nil {
		t.Errorf("a case needs an Operation and a Request")
		return
	}
	want := "TestCrossTenant" + strings.ToUpper(c.Operation[:1]) + c.Operation[1:]
	if top, _, _ := strings.Cut(t.Name(), "/"); top != want {
		t.Errorf("the test of operation %s must be named %s, it is %s", c.Operation, want, top)
		return
	}
	a := send(h, c.Request(UserA))
	b := send(h, c.Request(UserB))
	record(t, c.Operation, want, a, b)
	if a < 200 || a > 299 {
		t.Errorf("%s: user A got %d for a resource of user A, want 2xx; the request must name a resource that is there", c.Operation, a)
	}
	if b != http.StatusForbidden && b != http.StatusNotFound {
		t.Errorf("%s: user B got %d for a resource of user A, want 403 or 404", c.Operation, b)
	}
}

func send(h http.Handler, r *http.Request) int {
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, r)
	return rec.Code
}

// Out is where Check writes what both users got, as one line that starts with "YGG-AUTHZ ". `go test -json`
// carries it to the factory's rung go-authz.sh. A test of this package may point it elsewhere.
var Out io.Writer = os.Stdout

func record(t T, operation, test string, a, b int) {
	line, err := json.Marshal(struct {
		Operation string `json:"operation"`
		Test      string `json:"test"`
		A         int    `json:"a"`
		B         int    `json:"b"`
	}{operation, test, a, b})
	if err != nil {
		t.Errorf("authztest: %v", err)
		return
	}
	if _, err := fmt.Fprintf(Out, "YGG-AUTHZ %s\n", line); err != nil {
		t.Errorf("authztest: %v", err)
	}
}
```

**New file `templates/api/internal/authztest/authztest_test.go`**

```go
package authztest

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// fakeT is a test the checks can fail without failing this one.
type fakeT struct {
	name   string
	failed []string
}

func (f *fakeT) Helper()      {}
func (f *fakeT) Name() string { return f.name }
func (f *fakeT) Errorf(format string, args ...any) {
	f.failed = append(f.failed, fmt.Sprintf(format, args...))
}

// notes serves GET /notes/{id}: the note n1 belongs to user-a. other is what any other user gets.
func notes(other int) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-User") == UserA {
			w.WriteHeader(http.StatusOK)
			return
		}
		w.WriteHeader(other)
	})
}

func get(user string) *http.Request {
	r := httptest.NewRequest(http.MethodGet, "/notes/n1", nil)
	r.Header.Set("X-User", user)
	return r
}

func TestAnOwnerSeesTheNoteAndAnotherUserDoesNot(t *testing.T) {
	for _, other := range []int{http.StatusForbidden, http.StatusNotFound} {
		ft := &fakeT{name: "TestCrossTenantGetNote"}
		Check(ft, notes(other), Case{Operation: "getNote", Request: get})
		if len(ft.failed) != 0 {
			t.Errorf("user B got %d: %v", other, ft.failed)
		}
	}
}

func TestACheckFailsWhenAnotherUserGetsAnythingButForbiddenOrNotFound(t *testing.T) {
	for _, other := range []int{http.StatusOK, http.StatusNoContent, http.StatusInternalServerError, http.StatusUnauthorized, http.StatusBadRequest} {
		ft := &fakeT{name: "TestCrossTenantGetNote"}
		Check(ft, notes(other), Case{Operation: "getNote", Request: get})
		if len(ft.failed) == 0 || !strings.Contains(ft.failed[0], "user B") {
			t.Errorf("user B got %d and the check passed: %v", other, ft.failed)
		}
	}
}

func TestACheckFailsWhenTheOwnerCannotSeeTheResource(t *testing.T) {
	ft := &fakeT{name: "TestCrossTenantGetNote"}
	h := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusNotFound) })
	Check(ft, h, Case{Operation: "getNote", Request: get})
	if len(ft.failed) == 0 || !strings.Contains(ft.failed[0], "user A") {
		t.Errorf("user A got 404 and the check passed: %v", ft.failed)
	}
}

func TestACheckFailsWhenTheTestIsNotNamedForTheOperation(t *testing.T) {
	for _, name := range []string{"TestGetNote", "TestCrossTenantGetNotes", "TestCrossTenantgetNote"} {
		ft := &fakeT{name: name}
		Check(ft, notes(http.StatusNotFound), Case{Operation: "getNote", Request: get})
		if len(ft.failed) == 0 || !strings.Contains(ft.failed[0], "TestCrossTenantGetNote") {
			t.Errorf("a test named %s passed: %v", name, ft.failed)
		}
	}
	ft := &fakeT{name: "TestCrossTenantGetNote/subtest"}
	Check(ft, notes(http.StatusNotFound), Case{Operation: "getNote", Request: get})
	if len(ft.failed) != 0 {
		t.Errorf("a subtest of the right test failed: %v", ft.failed)
	}
}

func TestACheckWritesWhatBothUsersGotForTheFactoryToRead(t *testing.T) {
	var out strings.Builder
	defer func(old io.Writer) { Out = old }(Out)
	Out = &out
	ft := &fakeT{name: "TestCrossTenantGetNote"}
	Check(ft, notes(http.StatusNotFound), Case{Operation: "getNote", Request: get})
	want := `YGG-AUTHZ {"operation":"getNote","test":"TestCrossTenantGetNote","a":200,"b":404}` + "\n"
	if out.String() != want {
		t.Errorf("Out = %q; want %q", out.String(), want)
	}
}
```

**Change to `devcontainer/Containerfile`**

```diff
diff --git a/devcontainer/Containerfile b/devcontainer/Containerfile
index c58c910..c363578 100644
--- a/devcontainer/Containerfile
+++ b/devcontainer/Containerfile
@@ -29,4 +29,12 @@ RUN GOBIN=/usr/local/bin GOFLAGS=-mod=mod GOTOOLCHAIN=local go install golang.or
  && rm -rf /go/pkg
 
+# ygg-authz reads openapi.yaml for go-authz.sh, the two-tenant authorisation harness. It is built from its
+# folder of this realm: its one dependency is at the version and hash in its go.sum (-mod=readonly refuses
+# anything else), and the binary lands in /usr/local/bin, owned by root.
+COPY checks/lib/authz/ /tmp/ygg-authz/
+RUN cd /tmp/ygg-authz && GOFLAGS=-mod=readonly GOTOOLCHAIN=local go build -o /usr/local/bin/ygg-authz . \
+ && cd / && rm -rf /tmp/ygg-authz && go clean -cache -modcache \
+ && rm -rf /go/pkg
+
 # The golang image puts /go/bin ahead of the tools on PATH and makes it world-writable, so the agent could
 # put its own go or golangci-lint there. Root owns it, and the check scripts fix their own PATH as well.
```

**Change to `docs/architecture.md`**

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 530ba84..ee7b619 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -36,5 +36,6 @@ proposal `2026-10-17-realm-leaf-naming`).
   generated code, breaking changes), `go-deps.sh` (the dependency policy: tagged releases only, the
   minimum patched versions of `config/deps-policy.json`, then the audits the policy names), `go-security.sh`
-  (`govulncheck`, OSV) and `go-integration.sh`
+  (`govulncheck`, OSV), `go-authz.sh` (the two-tenant harness: every route with a resource id has a passing
+  `TestCrossTenant<OperationId>`, read by `ygg-authz`, which the image builds from `devcontainer/checks/lib/authz`) and `go-integration.sh`
   (tests that need Postgres). Rung 6 is the lead realm's reviewers; rung 7 is the grader's.
 - `templates/api/`: the leaf a new API starts from: a server with a health route, its contract, a
```

**Change to `pack.yaml`**

```diff
diff --git a/pack.yaml b/pack.yaml
index f238d61..154264e 100644
--- a/pack.yaml
+++ b/pack.yaml
@@ -1,6 +1,6 @@
 # The Go flavor of the Helheim realm (change realm-leaf-naming): the recipe of a Go API leaf and the
 # services an API needs. It has no graph: a run takes its graph from its lead realm (midgard-react for the
-# client gallery). The check ladder is rungs 1 to 5 of spec §9.5, with the dependency policy (deps) beside
-# the security rung; the
+# client gallery). The check ladder is rungs 1 to 5 of spec §9.5, with the dependency policy (deps) and the
+# two-tenant authorisation harness (authz) beside the security rung; the
 # reviewers (rung 6) are the lead realm's, and rung 7 is the grader's.
 name: helheim-go
@@ -13,4 +13,5 @@ checks:
   deps: [/opt/ygg/checks/go-deps.sh]
   security: [/opt/ygg/checks/go-security.sh]
+  authz: [/opt/ygg/checks/go-authz.sh]
   integration: [/opt/ygg/checks/go-integration.sh]
 leaf:
@@ -19,5 +20,5 @@ leaf:
   first_commit: [LICENSE]
   implementer: prompts/implementer.md
-  checks: [static, unit, tdd, contract, deps, security, integration]
+  checks: [static, unit, tdd, contract, deps, security, authz, integration]
 services:
   postgres:
```

**Change to `pack_test.go`**

```diff
diff --git a/pack_test.go b/pack_test.go
index 7363115..cd427c0 100644
--- a/pack_test.go
+++ b/pack_test.go
@@ -24,5 +24,5 @@ func TestThePackLoadsAndOffersTheRecipeEveryBuildRealmOffers(t *testing.T) {
 		t.Fatalf("leaf recipe = %+v", r)
 	}
-	want := []string{"static", "unit", "tdd", "contract", "deps", "security", "integration"}
+	want := []string{"static", "unit", "tdd", "contract", "deps", "security", "authz", "integration"}
 	if strings.Join(r.Checks, ",") != strings.Join(want, ",") {
 		t.Errorf("the ladder is %v, want %v: cheap rungs first, the one that needs services last", r.Checks, want)
```

**Change to `prompts/implementer.md`**

```diff
diff --git a/prompts/implementer.md b/prompts/implementer.md
index cad8c36..5230429 100644
--- a/prompts/implementer.md
+++ b/prompts/implementer.md
@@ -28,4 +28,7 @@ and the test that proves it.
   if middleware checked it too. Build storage keys on the server from the user and the resource; never
   use a key a client sends.
+- **Cross-tenant test.** A route with a resource id in its path (`{id}`, `{photoId}`) needs a test
+  `TestCrossTenant<OperationId>` that calls `authztest.Check`: user A gets the resource, user B gets 403 or
+  404. The factory fails the change without it.
 - **Secrets.** Write none into code, tests, logs or docs. A test uses made-up values.
 
```

**Change to `templates/api/AGENTS.md`**

```diff
diff --git a/templates/api/AGENTS.md b/templates/api/AGENTS.md
index 0f1c7b6..9ccb9fe 100644
--- a/templates/api/AGENTS.md
+++ b/templates/api/AGENTS.md
@@ -28,4 +28,8 @@ This file only adds rules for this leaf. Read `docs/` for the design; this file
 - **The server builds every storage key** from the logged-in user and the resource. It ignores keys a
   client sends. Authorisation is checked in the handler, not only in middleware.
+- **Every route with a resource id has a cross-tenant test.** A route whose path has a variable named `id`
+  or ending in `Id` needs a test `TestCrossTenant<OperationId>` that calls `authztest.Check`: user A gets
+  the resource, user B gets 403 or 404. The factory refuses a change without one. A route that anyone may
+  read on purpose is named, with the reason, in `authz.json` (`{"schema":"ygg.authz/v1","public":{"<operationId>":"<why>"}}`).
 - Errors answer JSON `{"error": "..."}` with the right status. A handler never leaks a stack trace, a
   query or a file path.
```

- [ ] **Step 7:** the task's ending, then commit in `helheim-go`.

```bash
gofmt -l .                      # prints nothing
go vet ./...
GOWORK=off go test -race ./...  # ok
git add authz_test.go devcontainer/Containerfile devcontainer/checks/go-authz.sh devcontainer/checks/lib/authz \
  docs/architecture.md pack.yaml pack_test.go prompts/implementer.md templates/api/AGENTS.md templates/api/internal/authztest
git commit -m "feat(checks): two-tenant authorisation harness go-authz.sh with authztest and a registry of public routes (v0-T260)" \
  -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**Evidence (run 2026-10-18, commit 3d352bb in the reference clone):** `go vet ./...` clean, `go test -count=1 -race ./...` ok (32 s), with the real `go`, `git` and the real `ygg-authz` built by the test from the folder the Containerfile builds. `golangci-lint` (installed here) ran on the template through `go-static.sh` in `TestTheUnchangedTemplatePassesStaticAndTDDAndItsSqlcOutputIsOwned` and passed after three `gosec` and `errcheck` findings in `authztest` were fixed. **On a real engine (rootless Podman 5.8):** the Containerfile built with the new `COPY` and `go build` step (exit 0). `/usr/local/bin/ygg-authz` is `-rwxr-xr-x root root`. In a derived image holding a leaf with the route `GET /photos/{photoId}`, `/opt/ygg/checks/go-authz.sh` failed with the `missing` output above when the test was absent and printed `covered … authz: ok` when the test was added. **Not run:** the rung was not run by Odin in a sandbox with the firewall and the agent's user (that is v0-H14 and v0-H15 territory, and the firewall allows the Go proxy already); `oasdiff`, `vacuum` and `sqlc` are not used by this rung.

### Task v0-T261: the smoke task `smoke-notes`, its public sample suite and the task check

Mimir's only task of this phase. Branch `smoke-notes` from `main` in `mimir`, before step 1. The grader (v0-T246 to
v0-T250) and the real-agent smoke (v0-T263) need a task that is cheap, small and still has a security category. This is
it: a tiny private notes app. It also adds `scripts/check-task.sh`, which every task folder must pass, and a PUBLIC
sample suite that tests the grader's wiring. The hidden suite of `smoke-notes` is NOT written here. It is written by
the founder in `huldra` and no agent reads it.

**Files (in `mimir`):**

- Create: `smoke-notes/instruction.md`, `smoke-notes/task.toml`, `smoke-notes/environment/Dockerfile`,
  `smoke-notes/environment/package.json`, `smoke-notes/environment/package-lock.json`,
  `smoke-notes/sample-suite/README.md`, `smoke-notes/sample-suite/tests/manifest.json`,
  `smoke-notes/sample-suite/tests/test.sh`, `smoke-notes/sample-suite/tests/playwright.config.ts`,
  `smoke-notes/sample-suite/tests/notes.spec.ts`, `smoke-notes/sample-suite/reference/README.md`,
  `smoke-notes/sample-suite/reference/start.sh`, `smoke-notes/sample-suite/reference/server.js`,
  `scripts/check-task.sh`, `scripts/check-task.test.sh`
- Modify: `README.md`, `AGENTS.md`

**Interfaces:**

- Consumes: the task layout of `client-gallery-lite` (`task.toml` keys, the Dockerfile style, a pinned Playwright base by digest) and
  the grader contract: `tasks_dir/<task-id>/{task.toml,instruction.md,environment/}`, suite at `.../<suite>/tests/`,
  `bash /tests/test.sh`, `/logs/verifier/results.json` in Playwright's JSON format, `tests/manifest.json` (`ygg.suite/v1`).
- Produces: task id `smoke-notes`, version `1.0.0`, suite `v1`, brief SHA-256
  `637d14afbc4140df9ce586123a51804ddfc81a70ef1e91ae6fa1662a92f0ef82`, weights `account=0.3,notes=0.3,security=0.4`.
  `scripts/check-task.sh <task-dir>` exits 0 when the task is well formed, 1 when a check fails, 2 on wrong usage.
  v0-T247 and v0-T248 may use `smoke-notes/sample-suite/` as a fixture; v0-T262 uses the task with scripted agents.

**Acceptance criteria:**

- [ ] `task.toml` has every key the grader reads; `brief_sha256` is the SHA-256 of `instruction.md`; `suite = "v1"`;
  `environment_mode = "separate"`; the weights are over `account`, `notes` and `security` and sum to 1; the limits are short
  (`budget_usd = 5`, agent 3600 s, verifier 300 s).
- [ ] The sample suite has 7 scenarios (6 fail-to-pass, 1 pass-to-pass); every manifest id is a Playwright spec title and
  every spec title is a manifest id.
- [ ] The Dockerfile pins its base by tag and digest (the same image as `client-gallery-lite`) and the runner package by lockfile.
- [ ] `scripts/check-task.sh` passes on `smoke-notes` and on `client-gallery-lite` (which has no sample suite: it says so and skips
  the manifest and spec checks). It fails on a changed brief, a repeated id, an id with no spec, a spec with no id, weights that do not
  sum to 1, a missing key, a wrong mode and a category with no weight.
- [ ] On a real engine: the image builds; the sample suite fails all 7 scenarios on an empty `/app`, passes all 7 on the reference
  solution, and fails the security scenario on a reference solution that leaks a note.
- [ ] The reference solution is not under `environment/`. `reuse lint` passes.

**Named test:** `bash scripts/check-task.test.sh` in `mimir`. **Layer:** `mimir`. **Size:** M (595 insertions without the
lock file; 391 for the task and its sample suite, 204 for the check and its test and docs). **Depends on:** none (v0-T246 and
later tasks use its output).

**Decision to flag.** This task is over the plan's 400 limit by itself (decision 20 of 5b). Two ways: keep one commit, or
split the check script into its own task. The founder chooses; the text below is one commit as asked.

**Review focus pinned by this task.**

- The hidden suite never goes in `mimir`: the sample suite is labelled PUBLIC in its README, `AGENTS.md` says so, and the
  reference solution is outside `environment/`, so the grader's image (built from `environment/`) and any agent's machine
  never hold it. `scripts/check-task.test.sh` pins the shape; the label is by review.
- A task that drifts from its brief: `scripts/check-task.test.sh`, case "a changed brief".
- A suite whose manifest and specs disagree (a scenario in one side only is an error, never a pass): cases "a manifest id with no
  spec", "a spec with no manifest id" and "a repeated id".
- A reward that does not add up: case "weights that do not sum to 1" and "a category with no weight".

- [ ] **Step 1:** create the branch and write the check's test first.

```bash
cd /home/brunogbv/brunogbv/ouroboric/yggdrasil/../mimir 2>/dev/null || cd ~/brunogbv/ouroboric/mimir
git switch -c smoke-notes main
mkdir -p scripts smoke-notes/environment smoke-notes/sample-suite/tests smoke-notes/sample-suite/reference
```

Write `scripts/check-task.test.sh`:

```bash
#!/bin/bash
# Tests scripts/check-task.sh on copies of the real tasks, each broken in one way.
# Run: bash scripts/check-task.test.sh   Exit 0 when every case behaves.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
check="$root/scripts/check-task.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failed=0

# expect <name> <exit code> <text in the output> <task dir>
expect() {
  local name="$1" code="$2" text="$3" dir="$4" out rc=0
  out="$("$check" "$dir" 2>&1)" || rc=$?
  if [ "$rc" -ne "$code" ] || ! grep -qF -- "$text" <<<"$out"; then
    echo "FAIL $name: exit $rc (want $code), output: $out"
    failed=1
  else
    echo "ok   $name"
  fi
}

# fresh <name>: a clean copy of smoke-notes in $work/<name>
fresh() { mkdir "$work/$1" && cp -r "$root/smoke-notes/." "$work/$1/"; }

expect "smoke-notes passes" 0 "passes the task checks" "$root/smoke-notes"
expect "a task without a sample suite says so" 0 "no sample suite" "$root/client-gallery-lite"
expect "no argument is a usage error" 2 "usage" "$work/missing"

fresh brief
echo "one more line" >>"$work/brief/instruction.md"
expect "a changed brief" 1 "brief hash differs" "$work/brief"

fresh dup
sed -i 's/"id": "delete a note"/"id": "add and list a note"/' "$work/dup/sample-suite/tests/manifest.json"
expect "a repeated id" 1 "not unique" "$work/dup"

fresh nospec
sed -i "s/test('delete a note'/test('remove a note'/" "$work/nospec/sample-suite/tests/notes.spec.ts"
expect "a manifest id with no spec" 1 "is not a spec title" "$work/nospec"
expect "a spec with no manifest id" 1 "is not in the manifest" "$work/nospec"

fresh weights
sed -i 's/security=0.4/security=0.5/' "$work/weights/task.toml"
expect "weights that do not sum to 1" 1 "not 1" "$work/weights"

fresh key
sed -i '/^environment_mode/d' "$work/key/task.toml"
expect "a missing required key" 1 "lacks the key verifier.environment_mode" "$work/key"

fresh mode
sed -i 's/environment_mode = "separate"/environment_mode = "shared"/' "$work/mode/task.toml"
expect "a wrong environment mode" 1 'must be "separate"' "$work/mode"

fresh cat
sed -i 's/"category": "security"/"category": "speed"/' "$work/cat/sample-suite/tests/manifest.json"
expect "a category with no weight" 1 "has no weight" "$work/cat"

fresh suite
sed -i 's/"suite": "v1"/"suite": "v2"/' "$work/suite/sample-suite/tests/manifest.json"
expect "a manifest of another suite than the task names" 1 "manifest suite differs" "$work/suite"

fresh f2p
sed -i 's/"kind": "fail-to-pass"/"kind": "pass-to-pass"/' "$work/f2p/sample-suite/tests/manifest.json"
expect "a manifest with no fail-to-pass scenario" 1 "no fail-to-pass scenario" "$work/f2p"

exit "$failed"
```

- [ ] **Step 2:** run the test. Expect it to fail, because the script and the task are not there yet.

```bash
bash scripts/check-task.test.sh
```

```output
FAIL smoke-notes passes: exit 127 (want 0), output: bash: line 1: .../scripts/check-task.sh: No such file or directory
FAIL a task without a sample suite says so: exit 127 (want 0), output: ...
...
```

- [ ] **Step 3:** write the check script.

Write `scripts/check-task.sh`:

```bash
#!/bin/bash
# Checks one task folder of mimir: usage `scripts/check-task.sh <task-dir>`.
# Needs bash and python3 (3.11 or newer). Exit 0: all checks pass. Exit 1: a check failed.
# Exit 2: wrong usage. It never reads or writes anything outside the task folder.
set -euo pipefail

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
  echo "usage: check-task.sh <task-dir>" >&2
  exit 2
fi

exec python3 -I - "$1" <<'PY'
import hashlib, json, math, re, sys, tomllib
from pathlib import Path

task = Path(sys.argv[1])
errors = []


def fail(msg):
    errors.append(msg)


def get(d, dotted):
    for part in dotted.split("."):
        if not isinstance(d, dict) or part not in d:
            return None
        d = d[part]
    return d


try:
    cfg = tomllib.loads((task / "task.toml").read_text())
except (OSError, tomllib.TOMLDecodeError) as e:
    print(f"FAIL: task.toml cannot be read: {e}")
    sys.exit(1)

required = [
    "artifacts", "task.name", "task.version", "metadata.brief_sha256", "metadata.suite",
    "metadata.budget_usd", "agent.timeout_sec", "environment.workdir", "verifier.timeout_sec",
    "verifier.environment_mode", "verifier.env.SCORE_WEIGHTS",
]
for key in required:
    if get(cfg, key) is None:
        fail(f"task.toml lacks the key {key}")
if get(cfg, "verifier.environment_mode") not in (None, "separate"):
    fail('verifier.environment_mode must be "separate"')

# The brief hash.
try:
    digest = hashlib.sha256((task / "instruction.md").read_bytes()).hexdigest()
    want = get(cfg, "metadata.brief_sha256")
    if want is not None and want != digest:
        fail(f"brief hash differs: task.toml says {want}, instruction.md is {digest}")
except OSError as e:
    fail(f"instruction.md cannot be read: {e}")

if not (task / "environment" / "Dockerfile").is_file():
    fail("environment/Dockerfile is missing")

# The weights.
weights = {}
raw = get(cfg, "verifier.env.SCORE_WEIGHTS")
if isinstance(raw, str):
    for item in raw.split(","):
        name, sep, val = item.partition("=")
        try:
            if not sep or not name.strip():
                raise ValueError
            if name.strip() in weights:
                fail(f"SCORE_WEIGHTS names {name.strip()} twice")
            weights[name.strip()] = float(val)
        except ValueError:
            fail(f"SCORE_WEIGHTS has a bad item {item!r}")
    if weights and not math.isclose(sum(weights.values()), 1.0, rel_tol=0, abs_tol=1e-9):
        fail(f"SCORE_WEIGHTS sum to {sum(weights.values())}, not 1")
    if any(w < 0 for w in weights.values()):
        fail("SCORE_WEIGHTS has a negative weight")

# The public sample suite, when the task has one.
suite_dir = task / "sample-suite" / "tests"
notes = []
if not (task / "sample-suite").is_dir():
    notes.append("no sample suite: the manifest and spec checks are skipped")
else:
    try:
        man = json.loads((suite_dir / "manifest.json").read_text())
    except (OSError, json.JSONDecodeError) as e:
        man = None
        fail(f"sample-suite/tests/manifest.json cannot be read: {e}")
    if man is not None:
        if man.get("schema") != "ygg.suite/v1":
            fail('manifest schema must be "ygg.suite/v1"')
        if man.get("suite") != get(cfg, "metadata.suite"):
            fail("manifest suite differs from metadata.suite")
        ids, kinds = [], set()
        for sc in man.get("scenarios", []):
            ids.append(sc.get("id"))
            kinds.add(sc.get("kind"))
            if sc.get("kind") not in ("fail-to-pass", "pass-to-pass"):
                fail(f"scenario {sc.get('id')!r} has kind {sc.get('kind')!r}")
            if weights and sc.get("category") not in weights:
                fail(f"scenario {sc.get('id')!r} has category {sc.get('category')!r}, which has no weight")
        if not ids:
            fail("manifest has no scenarios")
        dup = sorted({i for i in ids if ids.count(i) > 1}, key=str)
        if dup:
            fail(f"manifest ids are not unique: {dup}")
        if "fail-to-pass" not in kinds:
            fail("manifest has no fail-to-pass scenario")
        if not (suite_dir / "test.sh").is_file():
            fail("sample-suite/tests/test.sh is missing")
        titles = set()
        specs = sorted(suite_dir.glob("*.spec.*"))
        if not specs:
            fail("sample-suite/tests has no spec file")
        for spec in specs:
            for m in re.finditer(r"""\btest(?:\.\w+)?\(\s*(['"`])((?:\\.|(?!\1).)*)\1""", spec.read_text()):
                titles.add(m.group(2).replace("\\'", "'").replace('\\"', '"'))
        for i in sorted({i for i in ids if i}):
            if i not in titles:
                fail(f"manifest id {i!r} is not a spec title")
        for t in sorted(titles - set(ids)):
            fail(f"spec title {t!r} is not in the manifest")

for n in notes:
    print(f"note: {n}")
if errors:
    for e in errors:
        print(f"FAIL: {e}")
    sys.exit(1)
print(f"ok: {task.name} passes the task checks")
PY
```

- [ ] **Step 4:** write the brief. Do not edit it after step 5: the hash in `task.toml` is of these exact bytes.

Write `smoke-notes/instruction.md`:

```md
# Notes: product brief

Build a tiny web product where people keep private notes. It is small on purpose: it checks that a
factory can build, start and secure a whole product.

## 1. Accounts

- **Sign up** with an email and a password of at least 8 characters. Sign-up takes effect at once:
  no email confirmation. A used email is refused.
- **Log in** and **log out**. A session is a cookie.

## 2. Notes

- A person adds a note: a line of text, 1 to 500 characters.
- A person sees a list of their own notes, newest first, and deletes any of them.
- A person never sees, changes or deletes the notes of another person. A note id that is not theirs
  answers exactly as an id that does not exist.

## 3. Interface

The page at `/` holds everything. Use these names exactly.

| Where | Element | Name |
| --- | --- | --- |
| Signed out | fields; buttons | "Email", "Password"; "Sign up", "Log in" |
| Signed in | button | "Log out" |
| Signed in | field; button | "Note"; "Add note" |
| Signed in | list of notes, one list item per note | each item shows the note text and a button "Delete" |
| Signed out | message after a refused sign-up or log-in | the word "refused" |

## 4. HTTP interface

All bodies are JSON. A missing or wrong session answers 401.

| Request | Answer |
| --- | --- |
| `POST /api/signup` `{"email","password"}` | 201 and a session cookie. 400 for a bad email or a short password. 409 for a used email. |
| `POST /api/login` `{"email","password"}` | 200 and a session cookie. 401 for a wrong email or password. |
| `POST /api/logout` | 204. The cookie stops working. |
| `GET /api/notes` | 200 and a list of `{"id","text"}`, newest first. |
| `POST /api/notes` `{"text"}` | 201 and `{"id","text"}`. 400 for empty or longer than 500 characters. |
| `DELETE /api/notes/{id}` | 204. 404 when the note is not the caller's or does not exist. |

## 5. Running it

- **Where to build.** Build the product in `/app` on the machine you're given. Grading copies only
  `/app` onto a fresh copy of that machine and runs `/app/start.sh` there as an ordinary user (not
  root) who owns `/app`. Anything outside `/app` is lost.
- **Start command.** `/app/start.sh` is executable. Run with no arguments, it starts the whole product.
  Within 1 minute the product serves everything on port 3000, on all network interfaces, and keeps
  serving until stopped.
- **Self-contained.** The product runs on that one machine alone: no outside services, accounts or keys.
  It works over plain HTTP.

## 6. Out of scope

Editing notes, sharing, search, password reset, email.
```

- [ ] **Step 5:** write `task.toml` with the hash of the brief. Print the hash first.

```bash
sha256sum smoke-notes/instruction.md
```

```output
637d14afbc4140df9ce586123a51804ddfc81a70ef1e91ae6fa1662a92f0ef82  smoke-notes/instruction.md
```

Write `smoke-notes/task.toml`:

```toml
schema_version = "1.4"

# The build: everything in /app is carried from the build machine to the grading copy.
artifacts = ["/app"]

[task]
name = "ouroboric-dev/smoke-notes"
version = "1.0.0"
description = "Build notes, a tiny private notes web app, from instruction.md. A cheap smoke task for the factory's grader. Graded black-box on a fresh copy of the machine."
authors = [{ name = "Bruno Guilhermo de Barros Valério", email = "bruno@valerio.dev" }]
keywords = ["web-app", "smoke", "playwright", "security"]

[metadata]
category = "web-app"
difficulty = "easy"
tags = ["yggdrasil-v0", "smoke"]
# SHA-256 of instruction.md. Any change to the brief makes a new task version.
brief_sha256 = "637d14afbc4140df9ce586123a51804ddfc81a70ef1e91ae6fa1662a92f0ef82"
# Hidden suite version that scores runs of this task version.
suite = "v1"
# Spend limit for one factory build (model and infrastructure costs).
budget_usd = 5

[agent]
# Wall-clock limit for one factory build.
timeout_sec = 3600.0

[environment]
workdir = "/app"
build_timeout_sec = 600.0
cpus = 2
memory_mb = 4096
storage_mb = 4096

[verifier]
timeout_sec = 300.0
# Grade on a fresh copy of the environment, holding only the collected /app.
environment_mode = "separate"

[verifier.env]
WORKERS = "2"
# Category weights for the overall reward; each category scores its share of passing scenarios.
SCORE_WEIGHTS = "account=0.3,notes=0.3,security=0.4"
```

- [ ] **Step 6:** write the environment. The base is the same pinned image as `client-gallery-lite`. Only the runner package differs.

Write `smoke-notes/environment/Dockerfile`:

```dockerfile
# The machine a factory builds notes on, and (as a fresh copy holding only /app) the machine its
# build is graded on. Playwright 1.63.0 on Ubuntu 24.04, with Node 24, npm 11, Python 3.12, git and
# curl. Anything else a build needs, it installs while building; only what ends up in /app is
# carried to grading.
FROM mcr.microsoft.com/playwright:v1.63.0-noble@sha256:eff16c30e6f3f4af0a03fa4b706120d5e9b0891c344a27d64559aff5900a4a27

# Grading uses these; the product must not depend on them.
WORKDIR /grader
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund && npx playwright --version

# Grading starts the product as this unprivileged user, who owns /app.
RUN useradd --create-home --shell /bin/bash app && mkdir -p /app

WORKDIR /app
```

Write `smoke-notes/environment/package.json`:

```json
{
  "name": "smoke-notes-grader",
  "private": true,
  "description": "Grader dependencies for the smoke-notes benchmark task",
  "license": "AGPL-3.0-only",
  "dependencies": {
    "@playwright/test": "1.63.0"
  }
}
```

Do not write `package-lock.json` by hand. Let npm write it from `package.json`:

```bash
(cd smoke-notes/environment && npm install --package-lock-only --no-audit --no-fund)
grep -c '"integrity"' smoke-notes/environment/package-lock.json
```

```output
3
```

The three entries are `@playwright/test`, `playwright` and `playwright-core`, all at 1.63.0. The `@playwright/test` entry has the
same integrity as in `client-gallery-lite`'s lock: `sha512-oxMK4vllB9RK5NQ2l1pq1IfOf2AvnEuj/vYGDj0H2nMtmtZpKtCwt/l00GEO6xjGfpBNAvjovvYdCm50dRQkpQ==`.

- [ ] **Step 7:** write the public sample suite. Seven scenarios; the manifest ids are the Playwright titles.

Write `smoke-notes/sample-suite/README.md`:

```md
# smoke-notes: PUBLIC sample suite

This suite is public. It shows the shape of a hidden suite and tests the grader. It is NOT the
hidden suite that scores runs of this task. Never copy hidden scenarios here.

- `tests/`: `manifest.json`, `test.sh`, `playwright.config.ts` and `notes.spec.ts`. The grader runs
  `bash /tests/test.sh` with this folder (or the hidden one) mounted at `/tests`.
- `reference/`: a tiny solution used only to test this suite. It is not in `environment/`, so no
  agent sees it.
```

Write `smoke-notes/sample-suite/tests/manifest.json`:

```json
{
  "schema": "ygg.suite/v1",
  "suite": "v1",
  "scenarios": [
    { "id": "sign up then log in", "category": "account", "kind": "fail-to-pass" },
    { "id": "a short password is refused", "category": "account", "kind": "fail-to-pass" },
    { "id": "log out ends the session", "category": "account", "kind": "pass-to-pass" },
    { "id": "add and list a note", "category": "notes", "kind": "fail-to-pass" },
    { "id": "delete a note", "category": "notes", "kind": "fail-to-pass" },
    { "id": "notes need a session", "category": "security", "kind": "fail-to-pass" },
    { "id": "another person cannot see or delete my note", "category": "security", "kind": "fail-to-pass" }
  ]
}
```

Write `smoke-notes/sample-suite/tests/playwright.config.ts`:

```ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  testMatch: '*.spec.ts',
  workers: Number(process.env.WORKERS ?? 2),
  timeout: 20_000,
  retries: 0,
  use: { baseURL: 'http://localhost:3000' },
});
```

Write `smoke-notes/sample-suite/tests/notes.spec.ts`:

```ts
import { test, expect, type APIRequestContext } from '@playwright/test';

const password = 'correct horse';
let n = 0;
const fresh = () => `p${process.pid}-${Date.now()}-${n++}@example.com`;

async function signUp(request: APIRequestContext, email: string) {
  const res = await request.post('/api/signup', { data: { email, password } });
  expect(res.status()).toBe(201);
}

test('sign up then log in', async ({ page, request }) => {
  const email = fresh();
  await page.goto('/');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Password').fill(password);
  await page.getByRole('button', { name: 'Sign up' }).click();
  await expect(page.getByRole('button', { name: 'Log out' })).toBeVisible();
  await page.getByRole('button', { name: 'Log out' }).click();
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Password').fill(password);
  await page.getByRole('button', { name: 'Log in' }).click();
  await expect(page.getByRole('button', { name: 'Log out' })).toBeVisible();
  const wrong = await request.post('/api/login', { data: { email, password: 'wrong wrong' } });
  expect(wrong.status()).toBe(401);
});

test('a short password is refused', async ({ request }) => {
  const res = await request.post('/api/signup', { data: { email: fresh(), password: 'short' } });
  expect(res.status()).toBe(400);
});

test('log out ends the session', async ({ request }) => {
  await signUp(request, fresh());
  expect((await request.get('/api/notes')).status()).toBe(200);
  expect((await request.post('/api/logout')).status()).toBe(204);
  expect((await request.get('/api/notes')).status()).toBe(401);
});

test('add and list a note', async ({ page }) => {
  await page.goto('/');
  await page.getByLabel('Email').fill(fresh());
  await page.getByLabel('Password').fill(password);
  await page.getByRole('button', { name: 'Sign up' }).click();
  await page.getByLabel('Note').fill('buy milk');
  await page.getByRole('button', { name: 'Add note' }).click();
  await expect(page.getByRole('listitem').filter({ hasText: 'buy milk' })).toHaveCount(1);
});

test('delete a note', async ({ request }) => {
  await signUp(request, fresh());
  const created = await request.post('/api/notes', { data: { text: 'to delete' } });
  expect(created.status()).toBe(201);
  const { id } = await created.json();
  expect((await request.delete(`/api/notes/${id}`)).status()).toBe(204);
  expect(await (await request.get('/api/notes')).json()).toEqual([]);
});

test('notes need a session', async ({ request }) => {
  expect((await request.get('/api/notes')).status()).toBe(401);
  expect((await request.post('/api/notes', { data: { text: 'x' } })).status()).toBe(401);
  expect((await request.delete('/api/notes/1')).status()).toBe(401);
});

test('another person cannot see or delete my note', async ({ playwright, baseURL }) => {
  const alice = await playwright.request.newContext({ baseURL });
  const bob = await playwright.request.newContext({ baseURL });
  await signUp(alice, fresh());
  await signUp(bob, fresh());
  const created = await alice.post('/api/notes', { data: { text: 'alice secret' } });
  const { id } = await created.json();
  expect(await (await bob.get('/api/notes')).json()).toEqual([]);
  const del = await bob.delete(`/api/notes/${id}`);
  const missing = await bob.delete('/api/notes/does-not-exist');
  expect(del.status()).toBe(404);
  expect(missing.status()).toBe(404);
  expect(await del.text()).toBe(await missing.text());
  const mine = await (await alice.get('/api/notes')).json();
  expect(mine.map((x: { text: string }) => x.text)).toEqual(['alice secret']);
  await alice.dispose();
  await bob.dispose();
});
```

Write `smoke-notes/sample-suite/tests/test.sh`:

```bash
#!/bin/bash
# Runs the sample suite. The grader runs it as `bash /tests/test.sh` with the product in /app, this
# folder at /tests (read-only) and an empty /logs/verifier. It writes /logs/verifier/results.json
# in Playwright's JSON reporter format. A failing scenario does not fail this script; the results do.
set -euo pipefail

mkdir -p /logs/verifier
rm -rf /grader/suite
cp -r /tests /grader/suite

server=""
cleanup() { [ -n "$server" ] && kill "$server" 2>/dev/null || true; }
trap cleanup EXIT

if [ -x /app/start.sh ]; then
  runuser -u app -- bash -c 'cd /app && exec ./start.sh' >/logs/verifier/server.log 2>&1 &
  server=$!
fi

up=""
for _ in $(seq 1 60); do
  if curl -fsS -o /dev/null http://localhost:3000/ 2>/dev/null; then up=1; break; fi
  sleep 1
done

cd /grader
if [ -z "$up" ]; then
  echo "the product did not answer on port 3000 within 60 seconds" >&2
fi
PLAYWRIGHT_JSON_OUTPUT_NAME=/logs/verifier/results.json \
  npx playwright test --config suite/playwright.config.ts --reporter=json >/dev/null || true
test -s /logs/verifier/results.json
```

- [ ] **Step 8:** write the reference solution. It tests the suite and nothing else. It sits in `sample-suite/reference/`, not in
`environment/`, so the image never holds it.

Write `smoke-notes/sample-suite/reference/README.md`:

```md
# Reference solution (test aid only)

This is a tiny solution to `instruction.md`. It exists to test the sample suite and the grader's
wiring. It is NOT part of `environment/`, so no agent sees it. Never use it as a hint for the
hidden suite. Copy it to `/app` to try the sample suite.
```

Write `smoke-notes/sample-suite/reference/start.sh`:

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
exec node server.js
```

Write `smoke-notes/sample-suite/reference/server.js`:

```js
// Reference solution for the smoke-notes sample suite. In memory, no dependencies.
'use strict';
const http = require('node:http');
const crypto = require('node:crypto');

const users = new Map(); // email -> { id, salt, hash }
const sessions = new Map(); // token -> user id
const notes = []; // { id, owner, text }

const page = `<!doctype html><meta charset="utf-8"><title>Notes</title>
<div id="out"><form id="in">
<label>Email <input id="email" type="email"></label>
<label>Password <input id="pw" type="password"></label>
<button type="button" id="up">Sign up</button><button type="button" id="login">Log in</button>
<p id="msg"></p></form>
<div id="app" hidden><button id="logout">Log out</button>
<label>Note <input id="note"></label><button id="add">Add note</button><ul id="list"></ul></div></div>
<script>
const $ = (i) => document.getElementById(i);
const post = (p, b) => fetch(p, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(b) });
async function show() {
  const r = await fetch('/api/notes');
  $('in').hidden = r.status === 200;
  $('app').hidden = r.status !== 200;
  if (r.status !== 200) return;
  $('list').replaceChildren(...(await r.json()).map((n) => {
    const li = document.createElement('li'); li.append(n.text + ' ');
    const b = document.createElement('button'); b.textContent = 'Delete';
    b.onclick = async () => { await fetch('/api/notes/' + n.id, { method: 'DELETE' }); show(); };
    li.append(b); return li; }));
}
async function auth(path) {
  const r = await post(path, { email: $('email').value, password: $('pw').value });
  $('msg').textContent = r.ok ? '' : 'refused'; show();
}
$('up').onclick = () => auth('/api/signup'); $('login').onclick = () => auth('/api/login');
$('logout').onclick = async () => { await post('/api/logout', {}); show(); };
$('add').onclick = async () => { await post('/api/notes', { text: $('note').value }); $('note').value = ''; show(); };
show();
</script>`;

const hash = (pw, salt) => crypto.scryptSync(pw, salt, 32).toString('hex');
const send = (res, code, body, headers = {}) => {
  res.writeHead(code, { 'content-type': 'application/json', ...headers });
  res.end(body === undefined ? '' : JSON.stringify(body));
};
const userOf = (req) => {
  const m = /(?:^|; )sid=([a-f0-9]+)/.exec(req.headers.cookie || '');
  return m ? sessions.get(m[1]) : undefined;
};
const login = (res, userId, code) => {
  const token = crypto.randomBytes(24).toString('hex');
  sessions.set(token, userId);
  send(res, code, { ok: true }, { 'set-cookie': `sid=${token}; HttpOnly; SameSite=Lax; Path=/` });
};

http.createServer((req, res) => {
  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => {
    let body = {};
    try { body = JSON.parse(Buffer.concat(chunks).toString() || '{}'); } catch { return send(res, 400, { error: 'bad json' }); }
    const url = new URL(req.url, 'http://x');
    const p = url.pathname;
    if (req.method === 'GET' && p === '/') {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      return res.end(page);
    }
    if (req.method === 'POST' && p === '/api/signup') {
      const { email, password } = body;
      if (typeof email !== 'string' || !/^[^@\s]+@[^@\s]+$/.test(email) || typeof password !== 'string' || password.length < 8) {
        return send(res, 400, { error: 'bad input' });
      }
      if (users.has(email)) return send(res, 409, { error: 'used' });
      const salt = crypto.randomBytes(8).toString('hex');
      const user = { id: crypto.randomUUID(), salt, hash: hash(password, salt) };
      users.set(email, user);
      return login(res, user.id, 201);
    }
    if (req.method === 'POST' && p === '/api/login') {
      const u = users.get(body.email);
      if (!u || typeof body.password !== 'string' || hash(body.password, u.salt) !== u.hash) return send(res, 401, { error: 'refused' });
      return login(res, u.id, 200);
    }
    if (req.method === 'POST' && p === '/api/logout') {
      const m = /(?:^|; )sid=([a-f0-9]+)/.exec(req.headers.cookie || '');
      if (m) sessions.delete(m[1]);
      return send(res, 204);
    }
    if (p.startsWith('/api/notes')) {
      const me = userOf(req);
      if (!me) return send(res, 401, { error: 'login needed' });
      if (p === '/api/notes' && req.method === 'GET') {
        return send(res, 200, notes.filter((n) => n.owner === me).map(({ id, text }) => ({ id, text })).reverse());
      }
      if (p === '/api/notes' && req.method === 'POST') {
        if (typeof body.text !== 'string' || body.text.length < 1 || body.text.length > 500) return send(res, 400, { error: 'bad text' });
        const note = { id: crypto.randomUUID(), owner: me, text: body.text };
        notes.push(note);
        return send(res, 201, { id: note.id, text: note.text });
      }
      const id = p.slice('/api/notes/'.length);
      if (req.method === 'DELETE' && p.startsWith('/api/notes/')) {
        const i = notes.findIndex((n) => n.id === id && n.owner === me);
        if (i < 0) return send(res, 404, { error: 'not found' });
        notes.splice(i, 1);
        return send(res, 204);
      }
    }
    send(res, 404, { error: 'not found' });
  });
}).listen(3000, '0.0.0.0');
```

```bash
chmod +x scripts/check-task.sh scripts/check-task.test.sh smoke-notes/sample-suite/tests/test.sh smoke-notes/sample-suite/reference/start.sh
```

- [ ] **Step 9:** document the task and the check.

```diff
diff --git a/AGENTS.md b/AGENTS.md
index 37b270f..8b1de21 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -7,4 +7,6 @@ Public benchmark tasks for Yggdrasil. The company invariants apply:
   task version, made by the founder.
 - Hidden test suites never go in this repo. Only retired suites are published here, by the founder.
 - Never look for, read or reconstruct a task's hidden suite. Build to the brief.
+- A `sample-suite/` is public and is not a hidden suite. Its `reference/` solution only tests the suite; never
+  use it to build a task. Run `scripts/check-task.sh <task-dir>` after any change to a task folder.
 - Check a brief's SHA-256 against the table in `README.md` before running a task.
diff --git a/README.md b/README.md
index e9165f1..b1b5ad8 100644
--- a/README.md
+++ b/README.md
@@ -7,16 +7,25 @@ software factory. Each task is a frozen product brief that a factory builds from
 | Task | Version | Brief SHA-256 |
 |---|---|---|
 | [`client-gallery-lite`](client-gallery-lite/) | 4.0.0 | `bd4b2c7aaf532d51acb3a7edfd5b193d368db8445093b7a24cd80b7ee24d8319` |
+| [`smoke-notes`](smoke-notes/) | 1.0.0 | `637d14afbc4140df9ce586123a51804ddfc81a70ef1e91ae6fa1662a92f0ef82` |
 
 A task holds:
 
 - `instruction.md`: the brief. It is frozen: any change makes a new task version.
 - `task.toml`: limits, budget and grading settings.
 - `environment/`: the machine a build runs on, and the machine it is graded on.
+- `sample-suite/` (optional): a small PUBLIC suite that shows the shape of the hidden one and tests the
+  grader. It is not the hidden suite and it scores nothing. `smoke-notes` has one, with a reference
+  solution that only tests the suite.
 
 Builds are graded by hidden black-box suites, which are kept private so they don't leak to other
 factories or into model training data. When a suite is retired, it is published here with its scores.
 
+## Checking a task
+
+`scripts/check-task.sh <task-dir>` checks the brief hash, the `task.toml` keys, the weights and, when
+there is a sample suite, its manifest. `bash scripts/check-task.test.sh` tests the check.
+
 ## Contributing
 
 Run `uvx pre-commit install` once after cloning, so `gitleaks` checks each commit for secrets.
```

- [ ] **Step 10:** run the named test and the check on both tasks. Expect the output below.

```bash
bash scripts/check-task.test.sh
scripts/check-task.sh smoke-notes
scripts/check-task.sh client-gallery-lite
shellcheck -s bash scripts/*.sh smoke-notes/sample-suite/tests/test.sh smoke-notes/sample-suite/reference/start.sh
uvx -q --from 'reuse==5.0.2' reuse lint -q
```

```output
ok   smoke-notes passes
ok   a task without a sample suite says so
ok   no argument is a usage error
ok   a changed brief
ok   a repeated id
ok   a manifest id with no spec
ok   a spec with no manifest id
ok   weights that do not sum to 1
ok   a missing required key
ok   a wrong environment mode
ok   a category with no weight
ok   a manifest of another suite than the task names
ok   a manifest with no fail-to-pass scenario
ok: smoke-notes passes the task checks
note: no sample suite: the manifest and spec checks are skipped
ok: client-gallery-lite passes the task checks
```

`shellcheck` and `reuse lint` print nothing and exit 0.

- [ ] **Step 11:** build the image and run the sample suite on a real engine. This is the part that proves the suite. It needs Docker or
Podman and the Playwright base image (about 2.5 GB). The grader runs `bash /tests/test.sh` with the product in `/app`, the suite at
`/tests`, no network and an empty `/logs/verifier`. The commands below do the same with `create` and `cp`, which also works when the
engine is remote and cannot mount your folders (as the Podman of this plan's author is):

```bash
podman build -t smoke-notes-env:test smoke-notes/environment
run() {  # run <app dir or ""> <out dir>
  c=$(podman create --network=none smoke-notes-env:test bash /tests/test.sh)
  podman cp smoke-notes/sample-suite/tests "$c":/tests
  [ -n "$1" ] && podman cp "$1"/. "$c":/app
  podman start -a "$c" || true
  mkdir -p "$2" && podman cp "$c":/logs/verifier/. "$2"
  podman rm "$c" >/dev/null
}
titles='.. | objects | select(has("specs")) | .specs[] | "\(.title) | \(.tests[0].results[0].status)"'
run "" "$OUT/empty";  jq -r "$titles" "$OUT/empty/results.json"
run smoke-notes/sample-suite/reference "$OUT/ref";  jq -r "$titles" "$OUT/ref/results.json"
```

`$OUT` is any empty folder. The third run uses a copy of the reference with the owner test removed from `DELETE` (`n.owner === me`
deleted); it must fail only the cross-tenant scenario.

```output
# empty /app (the product does not answer on port 3000 within 60 seconds)
sign up then log in | failed
a short password is refused | failed
log out ends the session | failed
add and list a note | failed
delete a note | failed
notes need a session | failed
another person cannot see or delete my note | failed
# the reference solution
sign up then log in | passed
a short password is refused | passed
log out ends the session | passed
add and list a note | passed
delete a note | passed
notes need a session | passed
another person cannot see or delete my note | passed
# the reference solution with the owner check removed from DELETE
sign up then log in | passed
a short password is refused | passed
log out ends the session | passed
add and list a note | passed
delete a note | passed
notes need a session | passed
another person cannot see or delete my note | failed
```

Remove the test image and containers with `podman rmi smoke-notes-env:test` (one command, asked for first).

- [ ] **Step 12:** commit (see "How each task lands"; `mimir` has no Go, so the race test and `gofmt` do not apply).

```bash
git status --short
git add README.md AGENTS.md scripts smoke-notes
git commit -m "Add the smoke-notes task, its public sample suite and scripts/check-task.sh (v0-T261)" \
  -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

**Evidence.** Run on 2026-10-18 in a clone of `mimir` at `main` (`f8f2f6a`), commit `6fcc549`:

- `bash scripts/check-task.test.sh`: 11 cases, all `ok`. `scripts/check-task.sh` passed on `smoke-notes` and on `client-gallery-lite`
  (the latter prints the "no sample suite" note). `shellcheck -s bash` on the three scripts printed nothing. `reuse lint -q`
  (`reuse==5.0.2` through `uvx`) passed.
- Real engine: Podman 5.8.3, remote client to a rootful Podman in WSL. `podman build` of `environment/` succeeded on the pinned
  Playwright 1.63.0 base (the digest was in the local cache, so `--pull=never` was used; `npm ci` ran against the real registry).
  The sample suite ran inside the image with `--network=none`: 7 of 7 failed on an empty `/app`, 7 of 7 passed on the reference
  solution (about 4 s), and 6 of 7 passed with an owner check removed from `DELETE`, the failing one being the cross-tenant
  scenario. This proves the suite and `test.sh` (start as user `app`, wait for port 3000, run Playwright, write
  `/logs/verifier/results.json`).
- Not run: the grader itself (Gleipnir's `Grade`, v0-T246) and Odin's join of manifest and results (v0-T248): they do not exist yet.
  The bind-mount layout (`/app`, `/tests` read-only, `/logs/verifier`) was not tried, because the engine here is remote and
  cannot mount this machine's folders; `create` and `cp` put the same files in the same places. The hidden suite of `smoke-notes`
  does not exist in this task and was not read or written. The brief is a new task, not a change to `client-gallery-lite`, so no
  existing task changed.

### Task v0-T262: the grader smoke on a real engine, with scripted agents and the PUBLIC sample suite

Odin's task of Phase 5c, with one small change in Gungnir and one script in `ouroboric`. Branches: `grader/odin` in `odin` (the branch of the other Phase 5c tasks), `grader/limits-docs` from the routing branch in `gungnir`, `grader/scripts` from `main` in `ouroboric`. Needs v0-T245 to v0-T250 and v0-T261 in the tree. The unit tests of those tasks use a fake grader. This task runs the real one. It builds the image of `smoke-notes`, runs the sample suite of that task in a real container, and checks the score.

The suite is the PUBLIC sample suite (`mimir/smoke-notes/sample-suite/tests`). The script copies it to a temp folder laid out as `<task>/<suite>/tests/`, and that folder is `grader.suite_dir`. No hidden suite exists for `smoke-notes`. Nobody reads or writes one in this task.

**Files:**

- `gungnir`: Modify `schema/factory.go`, `schema/factory.schema.json`, `schema/factory_grader_test.go` (commit `5988fdf`).
- `odin`: Modify `internal/engine/grade.go`, `internal/engine/grade_test.go`, `internal/cli/doctor.go`, `internal/cli/grade_test.go`. Create `internal/cli/smoke_grade_test.go`, `testdata/smoke-grade/{pack.yaml,graph.yaml,prompts/build.md,prompts/review.md,templates/notes/LICENSE}` (commit `c523c83`).
- `ouroboric`: Create `scripts/ygg-smoke-grade.sh`, `scripts/tests/ygg-smoke-grade.test.sh` (commit `8caf6a4`).

**Interfaces:**

- Consumes: `ygg run` with a graph that ends in a `grade` node (v0-T249), `ygg grade <run-id>` (v0-T250), `ygg doctor` (graders), `sandbox.Driver.Grade` (v0-T246), the task `smoke-notes` and its public suite (v0-T261).
- Produces: `schema.Grader.Limits() (memory string, cpus int)` and the value `memory: none` (with `cpus: 0`) in `grader:`. Both mean "no limit". See decision 1.
- Produces: the realm `odin/testdata/smoke-grade` (a loop with an implementer and a reviewer, a merge, a pointer move, then the `grade` node), and `ouroboric/scripts/ygg-smoke-grade.sh [--build] [--folder DIR] [--tasks DIR] [--odin DIR] [--limits] [--clip]`. It prints one PASS or FAIL line per check and exits 0 only when every check passes.

**Decisions and flags (for the founder, when the plan is merged):**

1. **The cgroup finding, and a change to v0-T245.** Rootless Podman on this machine has no cgroup controllers for the user (`podman info` shows `CgroupControllers: []`). A container with `--memory 512m` fails with `crun: open memory.max for writing: No such file or directory`. A container with `--cpus 2` fails with `controller cpu is not available`. v0-T245 made `memory` and `cpus` required and positive ("nothing is defaulted"). So no config could run the grader here. The fix keeps the rule that the operator chooses: `grader.memory: none` and `grader.cpus: 0` mean no limit. A missing field is still an error. `Grade` receives an empty memory and zero CPUs, which v0-T246 already reads as "no limit". `ygg doctor` prints a WARN while the limits are off. The smoke runs with no limit by default; `--limits` asks for `4g` and 4 CPUs on an engine that has controllers. Please confirm. The cost: a hung suite is held by `grader.timeout` only. The alternative is to delegate the controllers to the user (a change to the WSL host, not to the plan).
2. **`/app` is the project, and the leaf is in `repos/notes`.** `Grade` exports the committed files of the umbrella and of each leaf, so a leaf's `start.sh` lands in `/app/repos/notes/start.sh`. The suite starts `/app/start.sh`. The brief says "build the product in `/app`". The smoke solves it with one committed file in the umbrella: a `start.sh` that runs the leaf's. The leaf prompt tells the agent that the root of its repository plays the part of `/app`. Please decide how a real project should do this. The choices: the planner puts a `start.sh` in the umbrella, the grade node exports one chosen leaf as `/app`, or the brief changes. The plan does not choose.
3. **The full `ygg run` smoke was cheap, so it is not left as a founder step.** The scripted agent writes the reference solution (the script builds the answers from `reference/` of the task, so nothing is copied by hand), the real Playwright image grades it, and the scripted reviewer finds nothing. The founder repeats it as v0-H16. It takes about 4 minutes after the first image pull.
4. **The realm folder is part of the run's hash.** A resume or a later `ygg grade` refuses a realm that changed since the run began ("the realm smoke-grade changed since the run started"). It happened once during this work, when a file was added to the folder while a run went on. Do not edit `testdata/smoke-grade` during a smoke.
5. **What the script checks, and how.** The engine is polled every second during each run. For every container, the poll records the label `ygg.grader` and the sources of the mounts. A container of this run without the label that holds the suite folder fails the smoke. The check is not empty: it needs at least one container of the run, and it prints the number it saw. The grader container is expected to hold the suite folder, and the script reports when the poll saw it. The poll can miss it (a grading run takes about 3 seconds), so a miss is a NOTE and not a failure.

**Acceptance criteria:**

- [ ] `ygg run` on the reference solution ends `done` and the grade node gives reward 1.0 with 6 of 6 fail-to-pass and 1 of 1 pass-to-pass. `ygg grade <run-id>` on the same run gives the same.
- [ ] `ygg run` on a product that holds nothing gives a reward below 1 (0.0, 0 of 6).
- [ ] After each run: no container with the label `ygg.grader` exists, `ygg doctor` finds 0 grader containers, no container of the run that is not a grader held `suite_dir`, and `score.json` exists once, in the run folder, and nowhere else under the project.
- [ ] `grader.memory: none` with `cpus: 0` loads, reaches the driver as no limit, and makes `ygg doctor` warn. A missing limit, a negative CPU count and `memory: 4` are still refused.
- [ ] The script has a test with a fake `ygg`, `podman` and `devcontainer`. Each check fails when its condition breaks (the Evidence lists the mutations).

**Review focus pinned by tests:** the suite folder is never held by an agent container of the run (`not_held` in the script, and the case `an agent container that holds the suite folder fails the smoke`); `score.json` is only in the run folder (`a score.json outside the run folder fails the smoke`); the container is gone after (`a grader container left behind fails the smoke`); the reward of the reference is 1 and of an empty product is below 1 (`a reference that does not grade 1 fails the smoke`, `an empty product that grades 1 fails the smoke`); the suite is a copy of the public suite and nothing else (`the suite folder is a copy of the PUBLIC suite and nothing else`); no limit reaches the driver as no limit (`TestNoLimitGoesToTheDriverAsNoLimit`, `TestTheGraderMayAskForNoLimitAndOnlyByWritingIt`, `TestDoctorWarnsWhenTheGraderRunsWithNoLimit`).

**Named test:** `go test ./schema -run 'TestTheGraderMayAskForNoLimit|TestTheGraderBlockIsRefusedWhenItIsNotExact'` in `gungnir`; `go test ./internal/engine ./internal/cli -run 'TestNoLimitGoesToTheDriver|TestDoctorWarnsWhenTheGraderRunsWithNoLimit|TestTheGradeSmokeRealmLoads'` in `odin`; `bash scripts/tests/ygg-smoke-grade.test.sh` in `ouroboric`; and, on a real engine, `scripts/ygg-smoke-grade.sh --build`. **Layer:** `odin`, `gungnir`, `ouroboric`. **Size:** L. **Depends on:** v0-T245 to v0-T250, v0-T261.

- [ ] **Step 1:** in `gungnir`, allow `none` and `0` as the explicit choice of no limit. These tests pin behavior of the code in step 1. They were written with the code, so they have no red step. The Evidence lists the mutation that makes them fail.

```diff
diff --git a/schema/factory.go b/schema/factory.go
index 39d9b77..d269bd2 100644
--- a/schema/factory.go
+++ b/schema/factory.go
@@ -29,8 +29,8 @@ type Grader struct {
 	TasksDir string   `yaml:"tasks_dir"` // a checkout of the task repo (mimir): <dir>/<task id>/{task.toml,instruction.md,environment/}
 	SuiteDir string   `yaml:"suite_dir"` // the store of hidden suites: <dir>/<task id>/<suite>/tests/. It is never mounted into an agent's sandbox
 	Timeout  Duration `yaml:"timeout"`   // the most one grading run's container may run
-	Memory   string   `yaml:"memory"`    // the container's memory limit, such as 4g
-	CPUs     int      `yaml:"cpus"`      // the container's CPUs
+	Memory   string   `yaml:"memory"`    // the container's memory limit, such as 4g; "none" is no limit (an engine that cannot apply one)
+	CPUs     int      `yaml:"cpus"`      // the container's CPUs; 0 is no limit
 }
 
 // Realms says where the operator keeps the realm leaves: a folder with one checkout of each, such as
@@ -282,6 +282,19 @@ func (f *Factory) checkSandbox() error {
 	return nil
 }
 
+// NoLimit is the value of grader.memory that asks for no memory limit.
+const NoLimit = "none"
+
+// Limits returns the memory and CPU limits to give the grader's container: "" and 0 mean no limit. An
+// operator on an engine that cannot apply limits (rootless Podman with no cgroup delegation) writes
+// `memory: none` and `cpus: 0`. Writing it is the choice; the factory never picks it for them.
+func (g *Grader) Limits() (memory string, cpus int) {
+	if g.Memory == NoLimit {
+		return "", g.CPUs
+	}
+	return g.Memory, g.CPUs
+}
+
 // check refuses a grader with a folder that is not clean and absolute, one folder inside the other (a
 // hidden suite inside a folder an agent may be given, or the reverse), or a limit that is not positive.
 func (g *Grader) check() error {
diff --git a/schema/factory.schema.json b/schema/factory.schema.json
index 3fc23a4..eed9b87 100644
--- a/schema/factory.schema.json
+++ b/schema/factory.schema.json
@@ -66,8 +66,8 @@
         "tasks_dir": { "type": "string", "minLength": 1, "description": "an absolute folder: a checkout of the task repo, <dir>/<task id>/{task.toml,instruction.md,environment/}" },
         "suite_dir": { "type": "string", "minLength": 1, "description": "an absolute folder: the store of hidden suites, <dir>/<task id>/<suite>/tests/; never mounted into an agent's sandbox" },
         "timeout": { "type": "string", "pattern": "^[1-9][0-9]*(ms|s|m|h)$" },
-        "memory": { "type": "string", "pattern": "^[1-9][0-9]*[mg]$", "description": "the container's memory limit, such as 4g" },
-        "cpus": { "type": "integer", "minimum": 1, "maximum": 256 }
+        "memory": { "type": "string", "pattern": "^([1-9][0-9]*[mg]|none)$", "description": "the container's memory limit, such as 4g; none asks for no limit, for an engine that cannot apply one (rootless Podman with no cgroup delegation)" },
+        "cpus": { "type": "integer", "minimum": 0, "maximum": 256, "description": "the container's CPUs; 0 asks for no limit, as memory: none does" }
       }
     },
     "skills": {
diff --git a/schema/factory_grader_test.go b/schema/factory_grader_test.go
index beec36f..b32b33f 100644
--- a/schema/factory_grader_test.go
+++ b/schema/factory_grader_test.go
@@ -38,7 +38,7 @@ func TestTheGraderBlockIsRefusedWhenItIsNotExact(t *testing.T) {
 		"no memory":                   {strings.Replace(graderBlock, "  memory: 4g\n", "", 1), "memory"},
 		"a memory with no unit":       {strings.Replace(graderBlock, "4g", "4", 1), "memory"},
 		"no cpus":                     {strings.Replace(graderBlock, "  cpus: 4\n", "", 1), "cpus"},
-		"zero cpus":                   {strings.Replace(graderBlock, "cpus: 4", "cpus: 0", 1), "cpus"},
+		"negative cpus":               {strings.Replace(graderBlock, "cpus: 4", "cpus: -1", 1), "cpus"},
 		"no suite folder":             {strings.Replace(graderBlock, "  suite_dir: /home/op/suites\n", "", 1), "suite_dir"},
 		"an unknown field":            {graderBlock + "  network: true\n", "network"},
 	}
@@ -51,3 +51,20 @@ func TestTheGraderBlockIsRefusedWhenItIsNotExact(t *testing.T) {
 		}
 	}
 }
+
+func TestTheGraderMayAskForNoLimitAndOnlyByWritingIt(t *testing.T) {
+	f, err := ParseFactory("factory.yaml", []byte(factoryHead+strings.NewReplacer("memory: 4g", "memory: none", "cpus: 4", "cpus: 0").Replace(graderBlock)))
+	if err != nil {
+		t.Fatalf("ParseFactory() = %v", err)
+	}
+	if m, c := f.Grader.Limits(); m != "" || c != 0 {
+		t.Errorf("Limits() = %q, %d; want no limit", m, c)
+	}
+	f, err = ParseFactory("factory.yaml", []byte(factoryHead+graderBlock))
+	if err != nil {
+		t.Fatal(err)
+	}
+	if m, c := f.Grader.Limits(); m != "4g" || c != 4 {
+		t.Errorf("Limits() = %q, %d; want 4g and 4", m, c)
+	}
+}
```

Run `go test -race -count=1 ./...` in `gungnir`. Expect `ok` for `gungnir` and `gungnir/schema`.

- [ ] **Step 2:** in `odin`, pass the limits through `Limits()`, warn in `ygg doctor`, and add the smoke realm. Apply:

```diff
diff --git a/internal/cli/doctor.go b/internal/cli/doctor.go
index 79d57e6..66d94d1 100644
--- a/internal/cli/doctor.go
+++ b/internal/cli/doctor.go
@@ -279,6 +279,9 @@ func checkGrader(f *schema.Factory, report func(level, what, msg string)) {
 		return
 	}
 	report("OK", "grader", fmt.Sprintf("%d task(s) in %s, suites in %s", n, g.TasksDir, g.SuiteDir))
+	if m, c := g.Limits(); m == "" || c == 0 {
+		report("WARN", "grader", "the grader's container runs with no memory or CPU limit (grader.memory: none or cpus: 0); a suite that hangs or leaks is held by the timeout only")
+	}
 }
 
 // checkGraders finds the grader containers a killed ygg left, by their label, and removes the ones no
diff --git a/internal/cli/grade_test.go b/internal/cli/grade_test.go
index 18c766f..7271fb4 100644
--- a/internal/cli/grade_test.go
+++ b/internal/cli/grade_test.go
@@ -203,3 +203,17 @@ func TestDoctorChecksTheGraderSectionsFolders(t *testing.T) {
 		t.Errorf("doctor without a grader section: exit %d\n%s", code, out)
 	}
 }
+
+func TestDoctorWarnsWhenTheGraderRunsWithNoLimit(t *testing.T) {
+	dir, config, _, _ := gradedRun(t, true)
+	engineStub(t, tasktest.Results(nil), "[]")
+	if _, out, _ := ygg(t, "doctor", "--project", dir, "--config", config); strings.Contains(out, "no memory or CPU limit") {
+		t.Errorf("doctor warns about limits that are set:\n%s", out)
+	}
+	b, _ := os.ReadFile(config)
+	os.WriteFile(config, []byte(strings.NewReplacer("memory: 4g", "memory: none", "cpus: 4", "cpus: 0").Replace(string(b))), 0o644)
+	code, out, _ := ygg(t, "doctor", "--project", dir, "--config", config)
+	if code != ExitDone || !strings.Contains(out, "WARN  grader: the grader's container runs with no memory or CPU limit") {
+		t.Errorf("doctor with no limit: exit %d\n%s", code, out)
+	}
+}
diff --git a/internal/engine/grade.go b/internal/engine/grade.go
index 46a4d85..01883ff 100644
--- a/internal/engine/grade.go
+++ b/internal/engine/grade.go
@@ -116,8 +116,9 @@ func Grade(ctx context.Context, r *run.Run, taskID string) (*Graded, error) {
 	if err := os.MkdirAll(logs, 0o755); err != nil {
 		return nil, err
 	}
+	memory, cpus := cfg.Limits() // "none" and 0 are the operator's choice of no limit, for an engine that cannot apply one
 	res, err := r.Grader.Grade(ctx, sandbox.GradeSpec{Run: r.State.ID, Task: t.ID, Environment: t.Environment, App: app, Tests: t.Tests, Logs: logs,
-		Timeout: min(time.Duration(cfg.Timeout), t.Timeout), Memory: cfg.Memory, CPUs: cfg.CPUs, Env: t.Env})
+		Timeout: min(time.Duration(cfg.Timeout), t.Timeout), Memory: memory, CPUs: cpus, Env: t.Env})
 	if ctx.Err() != nil {
 		return nil, ctx.Err()
 	}
diff --git a/internal/engine/grade_test.go b/internal/engine/grade_test.go
index 37a03bc..a0ea2dd 100644
--- a/internal/engine/grade_test.go
+++ b/internal/engine/grade_test.go
@@ -76,6 +76,9 @@ const gradedNodes = buildNodes +
 const gradedScript = buildScript +
 	"  design:\n    - actions: [ { write: { path: out/design.md, content: \"# Design\\n\" } } ]\n      result: { status: ok, summary: designed }\n"
 
+// gradedLimits is the limits part of the grader block; a test changes it for one run.
+var gradedLimits = "  memory: 4g\n  cpus: 4\n"
+
 // startGraded starts a run of nodes whose brief is the task's instruction.md, with the fake sandbox and the
 // fake grader. results is what the fake suite writes.
 func startGraded(t *testing.T, nodes, results string, edit func(*tasktest.Task)) *graded {
@@ -97,7 +100,7 @@ func startGraded(t *testing.T, nodes, results string, edit func(*tasktest.Task))
 		filepath.Join(cfg, "factory.yaml"): "mode: unattended\ngates: { design: auto }\nroles:\n  planner: { agent: scripted, model: none, script: script.yaml }\n" +
 			"budget:\n  per_run: { tokens: 100000, turns: 100 }\n  per_day: { tokens: 200000, turns: 200 }\n" +
 			"sandbox:\n  engine: unix:///run/ygg-test.sock\n" +
-			"grader:\n  tasks_dir: " + tk.TasksDir + "\n  suite_dir: " + tk.SuiteDir + "\n  timeout: 30m\n  memory: 4g\n  cpus: 4\n",
+			"grader:\n  tasks_dir: " + tk.TasksDir + "\n  suite_dir: " + tk.SuiteDir + "\n  timeout: 30m\n" + gradedLimits,
 	}
 	for p, body := range files {
 		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
@@ -228,3 +231,18 @@ func TestEveryRefusalStopsTheRunBeforeAnythingIsBuilt(t *testing.T) {
 		})
 	}
 }
+
+// An engine that cannot apply limits gets none: the operator wrote `memory: none` and `cpus: 0`, and the driver
+// receives an empty memory and zero CPUs, not the words (the driver would refuse "none" as a limit).
+func TestNoLimitGoesToTheDriverAsNoLimit(t *testing.T) {
+	old := gradedLimits
+	gradedLimits = "  memory: none\n  cpus: 0\n"
+	defer func() { gradedLimits = old }()
+	g := startGraded(t, gradedNodes, tasktest.Results(map[string]string{}), nil)
+	if out := g.advance(t); out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v", out)
+	}
+	if spec := g.grader.Specs[0]; spec.Memory != "" || spec.CPUs != 0 {
+		t.Errorf("limits = %q, %d; want none", spec.Memory, spec.CPUs)
+	}
+}
```

Create `internal/cli/smoke_grade_test.go`:

```go
package cli

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
)

// The grader smoke (v0-H16) runs this realm on a real engine, with ouroboric/scripts/ygg-smoke-grade.sh; this
// test keeps it loadable: a loop, then the merge and the pointer, then the grade node last, with the prompts
// and the template it names, and a sandbox stack pinned by digest.
func TestTheGradeSmokeRealmLoads(t *testing.T) {
	dir := filepath.Join("..", "..", "testdata", "smoke-grade")
	pack, err := schema.LoadPack(dir)
	if err != nil {
		t.Fatal(err)
	}
	g, err := schema.LoadGraph(filepath.Join(dir, pack.Graph))
	if err != nil {
		t.Fatal(err)
	}
	first, last := g.Nodes[0], g.Nodes[len(g.Nodes)-1]
	if first.Kind != schema.KindLoop || last.Kind != schema.KindGrade || len(first.Reviewers) != 1 {
		t.Errorf("the graph starts with %+v and ends with %+v", first, last)
	}
	if len(pack.Checks["unit"]) == 0 || pack.Sandbox == nil || pack.Sandbox.Stack == "" {
		t.Errorf("the pack: checks %v, sandbox %+v", pack.Checks, pack.Sandbox)
	}
	for _, f := range []string{first.Prompt, first.Reviewers[0].Prompt, "templates/notes/LICENSE"} {
		if _, err := os.Stat(filepath.Join(dir, f)); err != nil {
			t.Errorf("the realm names %s: %v", f, err)
		}
	}
}
```

Create `testdata/smoke-grade/pack.yaml`:

```yaml
name: smoke-grade
version: 0.1.0
graph: graph.yaml
checks:
  unit: [test, -f, README.md] # in the leaf's sandbox
leaves:
  repos/notes: { description: the notes product, template: templates/notes, first_commit: [LICENSE] }
sandbox:
  # The machine the task gives (mimir smoke-notes/environment/Dockerfile): Playwright 1.63.0 on Ubuntu 24.04
  # with Node 24 and Python 3.12. The digest is the one in that Dockerfile.
  stack: mcr.microsoft.com/playwright:v1.63.0-noble@sha256:eff16c30e6f3f4af0a03fa4b706120d5e9b0891c344a27d64559aff5900a4a27
  egress: []
```

Create `testdata/smoke-grade/graph.yaml`:

```yaml
# The smoke graph for the grader (spec §11): one implementer and one read-only reviewer in a bounded loop build
# the product of a task in one leaf; the leaf is merged and the umbrella pointer moves; then the grade node
# stops every sandbox, exports the project as /app and grades it against the task's suite. The caps are the
# graph's: each session has a turn cap and a time cap. With scripted agents it costs nothing; with real agents
# it costs a few dollars (see ouroboric/scripts/ygg-smoke-real.sh).
name: smoke-grade
version: 0.1.0
nodes:
  - id: build
    kind: loop
    repo: repos/notes
    role: implementer
    prompt: prompts/build.md
    attempts: 2
    max_turns: 40
    timeout: 20m
    checks: [unit]
    reviewers:
      - { id: review, role: reviewer, prompt: prompts/review.md, max_turns: 10, timeout: 5m }
  - { id: feature-gate, kind: gate, gate: feature }
  - { id: merge-gate, kind: gate, gate: merge }
  - { id: merge, kind: merge, repo: repos/notes, checks: [unit] }
  - { id: pointer-gate, kind: gate, gate: pointer }
  - { id: pointer, kind: pointer, repo: repos/notes, checks: [unit] }
  - { id: score, kind: grade }
```

Create `testdata/smoke-grade/prompts/build.md`:

```md
Build the product of the brief below in this repository. The brief says `/app`: the root of this repository
plays that part. The grader starts the product with the `start.sh` of this repository, so this repository must
hold an executable `start.sh` that starts the whole product on port 3000.

The machine has Node 24 and Python 3.12 and has no network. Use only their standard libraries. Do not install
packages. The product keeps its data in memory.

Write a `README.md` that says in three lines what the product is and how to start it. Test the product with
`curl` before you finish. Make no other change. Then reply with the word done.
```

Create `testdata/smoke-grade/prompts/review.md`:

```md
Review the work in this repository against the brief below. It should hold an executable `start.sh` that
starts a web product on port 3000, and a `README.md`.

Read the files. Start the product if you can, and try one sign-up with `curl`. Report a finding only if
`start.sh` is missing or not executable, or if the product does not start, or if it breaks a rule of the brief
that you have checked. Do not report style. If the work is fine, report no findings.
```

Copy `testdata/smoke-loop/templates/app/LICENSE` to `testdata/smoke-grade/templates/notes/LICENSE`.

The sandbox stack is the Playwright image of the task, by the digest in `mimir/smoke-notes/environment/Dockerfile`. The agents work on the same machine the grader uses. The reference solution needs Node 24, which that image has.

Run in `odin` (through `go.work`): `go vet ./... && go test -count=1 ./internal/engine ./internal/cli -run 'TestNoLimit|TestDoctorWarns|TestTheGradeSmokeRealmLoads|TestGraderCombines'`. Expect `ok` for both packages.

- [ ] **Step 3:** in `ouroboric`, write the script. It does not write your `factory.yaml`. It writes one config per case in the new folder.

Create `scripts/ygg-smoke-grade.sh`:

```bash
#!/usr/bin/env bash
# Run the grader smoke (v0-H16): `ygg run` with scripted agents on a real engine, ending in the grade node, then
# `ygg grade` again, on the reference solution and on an empty product of the task smoke-notes.
#   ygg-smoke-grade.sh [--build] [--folder DIR] [--tasks DIR] [--odin DIR] [--limits] [--clip]
# The suite is the PUBLIC sample suite of the task (smoke-notes/sample-suite/tests): this script never reads or
# writes a hidden suite. It copies the public suite into DIR/smoke-grade-<time>/suites/smoke-notes/v1/tests, and
# that folder is the grader's suite_dir. Needs DIR/factory.yaml (it names the engine; this script never writes
# it), the devcontainer CLI 0.89.0, jq and python3, the engine up, the bind mount present, and a checkout of
# `mimir` (--tasks, default: the mimir folder next to this repo in the umbrella). It
#   1. checks the engine (ygg-engine.sh), the tools and the task;
#   2. makes DIR/smoke-grade-<time> with one project per case (reference, empty), each with a committed
#      `start.sh` that starts the leaf's own, because the grader's /app is the project, and the leaf is in repos/notes;
#   3. writes the scripted answers from the reference solution of the task (the files are not copied by hand);
#   4. runs `ygg run` on each project (the brief is the task's instruction.md; the graph ends in the grade node),
#      and watches the engine while it runs;
#      (--build first builds the sandbox image of the realm, which a first run needs);
#   5. runs `ygg grade` on each finished run, and prints one line per check: PASS or FAIL.
# The checks: reward 1 for the reference; reward below 1 for the empty product; no container with the label
# ygg.grader is left; ygg doctor finds none; no container that is not a grader ever held the suite folder
# (the engine is polled every second while the run goes); score.json is in the run folder and in no other place.
# Exit 0 only when every check passes. The grader runs without a memory or CPU limit (grader.memory: none,
# cpus: 0), because rootless Podman without cgroup delegation cannot apply them; --limits asks for 4g and 4 CPUs.
# Defaults: DIR=$HOME/ygg-it. For tests and other machines: YGG_CMD (how ygg runs), YGG_ODIN (the odin folder),
# YGG_BIND (the bind mount, default /mnt/wsl/ygg-bind), YGG_CLI_VERSION (default 0.89.0). The engine environment
# comes from ygg-engine.sh (YGG_ENGINE_CHECK=0 skips it).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="$HOME/ygg-it" tasks="$HERE/../../mimir" limits=0 clip=0 build=0
odin="${YGG_ODIN:-$HERE/../../yggdrasil/odin}"
usage() { echo "usage: ygg-smoke-grade.sh [--folder DIR] [--tasks DIR] [--odin DIR] [--build] [--limits] [--clip]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --folder) [ $# -ge 2 ] || usage; dir="$2"; shift 2 ;;
    --tasks) [ $# -ge 2 ] || usage; tasks="$2"; shift 2 ;;
    --odin) [ $# -ge 2 ] || usage; odin="$2"; shift 2 ;;
    --build) build=1; shift ;;
    --limits) limits=1; shift ;;
    --clip) clip=1; shift ;;
    *) usage ;;
  esac
done
fail() { echo "smoke-grade: $*" >&2; exit 2; }
task=smoke-notes
bind="${YGG_BIND:-/mnt/wsl/ygg-bind}"

export PATH="$dir/dc/node_modules/.bin:$PATH"
if [ "${YGG_ENGINE_CHECK:-1}" = 1 ]; then
  engine_env="$("$HERE/ygg-engine.sh" env --folder "$dir")" || exit 2
  eval "$engine_env"
fi
[ -f "$dir/factory.yaml" ] || fail "$dir/factory.yaml is missing; it names the engine (sandbox.engine)"
engine="$(sed -n 's/^[[:space:]]*engine:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$dir/factory.yaml" | head -n 1)"
case "$engine" in unix://*) ;; *) fail "sandbox.engine in $dir/factory.yaml is '${engine:-missing}'; it must be a unix:// URL" ;; esac
for tool in jq python3 podman git; do command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed"; done
tasks="$(cd "$tasks" 2>/dev/null && pwd)" || fail "no mimir folder at $tasks (--tasks)"
odin="$(cd "$odin" 2>/dev/null && pwd)" || fail "no odin folder at $odin (--odin)"
realm="$odin/testdata/smoke-grade"
public="$tasks/$task/sample-suite"
for f in "$tasks/$task/task.toml" "$tasks/$task/instruction.md" "$public/tests/manifest.json" "$public/tests/test.sh" "$public/reference/start.sh" "$realm/pack.yaml"; do
  [ -f "$f" ] || fail "$f is missing"
done
suite="$(sed -n 's/^suite[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$tasks/$task/task.toml" | head -n 1)"
[ -n "$suite" ] || fail "$tasks/$task/task.toml has no metadata.suite"

work="$dir/smoke-grade-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$work/suites/$task/$suite"
cp -r "$public/tests" "$work/suites/$task/$suite/tests"
echo "smoke-grade: made $work"
echo "smoke-grade: the suite is the PUBLIC sample suite $public/tests (suite $suite)"

ygg="${YGG_CMD:-}"
if [ -z "$ygg" ]; then
  if command -v ygg >/dev/null 2>&1; then ygg=ygg
  else
    mkdir -p "$work/bin"
    (cd "$odin" && go build -o "$work/bin/ygg" ./cmd/ygg) || fail "go build of ygg failed in $odin"
    ygg="'$work/bin/ygg'"
  fi
fi

# The scripted answers: the implementer writes the files of the case; the reviewer finds nothing.
script() { # script CASE OUT: reference writes every file of the task's reference solution; empty writes a README
  python3 -I - "$1" "$public/reference" >"$2" <<'PY'
import json, os, sys
case, ref = sys.argv[1], sys.argv[2]
usage = "usage: { in: 2000, out: 400, turns: 5 }"
print("steps:\n  build:\n    - actions:")
if case == "reference":
    for name in sorted(os.listdir(ref)):
        with open(os.path.join(ref, name), encoding="utf-8") as f:
            print("        - write: { path: %s, content: %s }" % (json.dumps(name), json.dumps(f.read())))
    print('        - run: { argv: ["chmod", "+x", "start.sh"] }')
else:
    print("        - write: { path: README.md, content: %s }" % json.dumps("Nothing is built here.\n"))
print("      result: { status: ok, summary: built it, %s }" % usage)
print("  build-review:\n    - result: { status: ok, summary: reviewed, report: [], usage: { in: 800, out: 100, turns: 2 } }")
PY
}

# config CASE: the factory.yaml of a case, on stdout.
config() {
  local memory=none cpus=0
  [ "$limits" -eq 0 ] || { memory=4g cpus=4; }
  cat <<EOF
mode: unattended
privacy: strict
roles:
  implementer: { agent: scripted, model: none, script: $work/$1/script.yaml }
  reviewer: { agent: scripted, model: none, script: $work/$1/script.yaml }
budget:
  per_run: { tokens: 100000, turns: 100 }
  per_day: { tokens: 1000000, turns: 1000 }
sandbox:
  engine: $engine
  mounts:
    - { host: $dir, engine: $bind }
grader:
  tasks_dir: $tasks
  suite_dir: $work/suites
  timeout: 10m
  memory: $memory
  cpus: $cpus
EOF
}

results=() bad=0
check() { # check DESCRIPTION COMMAND...: PASS when the command succeeds
  local d="$1"
  shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $d"; results+=("PASS  $d"); else echo "FAIL  $d"; results+=("FAIL  $d"); bad=1; fi
}
# Conditions for check, one per kind.
is_done() { [ "$1" -eq 0 ] && [ -n "$2" ]; }
is_zero() { [ "$1" -eq 0 ]; }
is_empty() { [ -z "$1" ]; }
is_same() { [ "$1" = "$2" ]; }
is_count() { [ "$(grep -Ec "$2" "$1")" -eq "$3" ]; }
seen_agents() { # seen_agents LOG MINE: how many containers of this run (they mount a path under MINE) the watch saw, grader excluded
  awk -v m="$2" '$2 == "-" && index($0, m) {print $1}' "$1" | sort -u | wc -l
}
not_held() { # not_held LOG NEEDLE MINE: the watch saw containers of this run, and none that is not a grader held NEEDLE
  [ "$(seen_agents "$1" "$3")" -gt 0 ] && ! awk -v n="$2" '$2 == "-" && index($0, n)' "$1" | grep -q .
}
held() { # held LOG NEEDLE: the grader container (it has the label) held NEEDLE
  awk -v n="$2" '$2 != "-" && index($0, n)' "$1" | grep -q .
}

# watch FILE: polls the engine until the file FILE.stop exists; writes one line per container and poll:
# "<name> <grader label or -> <mount sources...>".
watch() {
  while [ ! -e "$1.stop" ]; do
    ids="$(podman ps -a -q 2>/dev/null || true)"
    if [ -n "$ids" ]; then
      # shellcheck disable=SC2086
      podman inspect --format '{{.Name}} {{or (index .Config.Labels "ygg.grader") "-"}} {{range .Mounts}}{{.Source}} {{end}}' $ids >>"$1" 2>/dev/null || true
    fi
    sleep 1
  done
}

oneCase() { # oneCase CASE: build the project, run it to its end, grade it again
  local c="$1" v="$work/$1" project id rc
  project="$v/project"
  mkdir -p "$project"
  git -C "$project" init -q -b main
  printf 'root: true\nowner: ouroboric-dev\nvisibility: private\n' >"$project/umbrella.yaml"
  # The grader's /app is the project. The product is the leaf's; this file starts it.
  # shellcheck disable=SC2016
  printf '#!/bin/sh\ncd "$(dirname "$0")/repos/notes" && exec ./start.sh\n' >"$project/start.sh"
  chmod +x "$project/start.sh"
  git -C "$project" add umbrella.yaml start.sh
  git -C "$project" -c user.name=ygg -c user.email=ygg@example.invalid commit -q -m "the grader smoke project"
  script "$c" "$v/script.yaml"
  config "$c" >"$v/factory.yaml"
  : >"$v/mounts.log"
  watch "$v/mounts.log" &
  local watcher=$!
  set +e
  eval "$ygg run --project '$project' --config '$v/factory.yaml' --realm '$realm' --brief '$tasks/$task/instruction.md'" 2>&1 | tee "$v/run.txt"
  rc="${PIPESTATUS[0]}"
  set -e
  id="$(find "$project/.factory/runs" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | tail -n 1 || true)"
  check "$c: ygg run ended done (exit $rc, run ${id:-none})" is_done "$rc" "$id"
  if [ -n "$id" ]; then
    set +e
    eval "$ygg grade '$id' --project '$project'" 2>&1 | tee "$v/grade.txt"
    local grc="${PIPESTATUS[0]}"
    eval "$ygg doctor --project '$project' --config '$v/factory.yaml'" >"$v/doctor.txt" 2>&1
    set -e
    check "$c: ygg grade of the finished run exited 0" is_zero "$grc"
  fi
  touch "$v/mounts.log.stop"
  wait "$watcher" || true
  local score="$project/.factory/runs/${id:-none}/score.json" reward=none
  [ -f "$score" ] && reward="$(jq -r '.reward' "$score")"
  echo "smoke-grade: $c reward $reward"
  if [ "$c" = reference ]; then
    check "reference: reward is 1" jq -e '.reward == 1' "$score"
  else
    check "empty: reward is below 1 (it is $reward)" jq -e '.reward < 1' "$score"
  fi
  check "$c: the ledger has grade_finished twice (the node, then the command)" is_count "$project/.factory/runs/${id:-none}/ledger.jsonl" '"event": ?"grade_finished"' 2
  check "$c: no container with the label ygg.grader is left" is_empty "$(podman ps -a -q --filter label=ygg.grader 2>/dev/null || true)"
  check "$c: ygg doctor finds 0 grader containers" grep -q ' 0 grader container' "$v/doctor.txt"
  local needle
  needle="$(basename "$work")/suites"
  check "$c: the watch saw $(seen_agents "$v/mounts.log" "$(basename "$work")/$c/") agent container(s) of this run, and none held the suite folder" \
    not_held "$v/mounts.log" "$needle" "$(basename "$work")/$c/"
  if held "$v/mounts.log" "$needle"; then
    echo "PASS  $c: the watch saw the grader container hold the suite folder (the watch works)"
  else
    echo "NOTE  $c: the watch did not catch the grader container while it ran (a 1 second poll can miss it)"
  fi
  local found
  found="$(find "$v" -name 'score.json' | sort)"
  check "$c: score.json is in the run folder and nowhere else" is_same "$found" "$score"
}

if [ "$build" -eq 1 ]; then
  mkdir -p "$work/reference"
  config reference >"$work/reference/factory.yaml"
  eval "$ygg sandbox build --config '$work/reference/factory.yaml' --realm '$realm'"
fi
oneCase reference
oneCase empty

echo
echo "smoke-grade: the folder is $work"
report="$work/report.txt"
printf '%s\n' "${results[@]}" >"$report"
if [ "$clip" -eq 1 ]; then
  if command -v clip.exe >/dev/null 2>&1; then clip.exe <"$report"; echo "(copied to the clipboard)" >&2
  else echo "smoke-grade: --clip needs clip.exe (WSL); the report is in $report" >&2; fi
fi
if [ "$bad" -ne 0 ]; then echo "smoke-grade: a check failed"; exit 1; fi
echo "smoke-grade: every check passed"
```

- [ ] **Step 4:** write its test. The fake `ygg` makes a run folder, a ledger and a `score.json` (reward 1 only when the scripted answers hold the reference solution). The fake `podman` reports the containers a test asks for.

Create `scripts/tests/ygg-smoke-grade.test.sh`:

```bash
#!/usr/bin/env bash
# Tests for ygg-smoke-grade.sh.   scripts/tests/ygg-smoke-grade.test.sh
# A fake `ygg`, a fake `podman` and a fake `devcontainer` stand in for the real tools: no model, no engine, no
# network, no money. The task folder is a small made-up mimir with a made-up public suite.
# shellcheck disable=SC2329,SC2016 # check calls has and hasnt by name; the $ in the patterns is literal
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
has() { grep -q -F -- "$1" "$T/out"; }
hasnt() { ! grep -q -F -- "$1" "$T/out"; }
export HOME="$T/home"; mkdir -p "$HOME"
export YGG_ENGINE_CHECK=0 # the engine environment has its own test (ygg-engine.test.sh)
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

# A made-up mimir: the task, its public suite and its reference solution.
M="$T/mimir"; mkdir -p "$M/smoke-notes/sample-suite/tests" "$M/smoke-notes/sample-suite/reference"
printf '[metadata]\nsuite = "v1"\n' >"$M/smoke-notes/task.toml"
printf '# brief\n' >"$M/smoke-notes/instruction.md"
printf '{"schema":"ygg.suite/v1"}\n' >"$M/smoke-notes/sample-suite/tests/manifest.json"
printf '#!/bin/bash\n' >"$M/smoke-notes/sample-suite/tests/test.sh"
printf '#!/bin/bash\nexec node server.js\n' >"$M/smoke-notes/sample-suite/reference/start.sh"
printf 'console.log("it has a \\"quote\\" and a tab\\there");\n' >"$M/smoke-notes/sample-suite/reference/server.js"
printf '# reference\n' >"$M/smoke-notes/sample-suite/reference/README.md"
# A made-up odin: the realm and the example config of the real run.
O="$T/odin/testdata/smoke-grade"; mkdir -p "$O"
printf 'name: smoke-grade\n' >"$O/pack.yaml"
cat >"$O/factory.real.example.yaml" <<'EOF'
mode: unattended
roles:
  implementer: { agent: claude-code, model: sonnet }
  reviewer: { agent: opencode, model: openrouter/deepseek/deepseek-v4-flash }
budget:
  per_run: { tokens: 400000, turns: 100, usd: 3 }
  per_day: { tokens: 1000000, turns: 200, usd: 6 }
sandbox:
  engine: @ENGINE@
  mounts:
    - { host: @FOLDER@, engine: @BIND@ }
grader:
  tasks_dir: @TASKS@
  suite_dir: @SUITES@
  timeout: 10m
  memory: none
  cpus: 0
EOF

# The fake ygg. `run` makes a run folder with a ledger and a score.json (reward 1 when the scripted answers hold
# the reference solution, else 0); FAKE_LEAK puts a second score.json in the project; FAKE_RUN_SLEEP makes it hang.
mkdir -p "$T/bin" "$T/it"
cat >"$T/bin/ygg" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"${FAKE_ARGS_LOG:-/dev/null}"
proj='' cfg=''
while [ $# -gt 0 ]; do case "$1" in --project) proj="$2" ;; --config) cfg="$2" ;; esac; shift; done
case "$FAKE_VERB" in
  doctor)
    [ -z "${FAKE_DOCTOR_RC:-}" ] || { echo "ERROR graders: 2 grader container(s) of ygg runs"; exit "$FAKE_DOCTOR_RC"; }
    echo "OK    graders: 0 grader container(s) of ygg runs" ;;
  status) echo "status:   done" ;;
  build) echo "built" ;;
  run)
    [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] || echo "the credentials were loaded" >>"${FAKE_ARGS_LOG:-/dev/null}"
    [ -z "${FAKE_RUN_SLEEP:-}" ] || exec sleep "$FAKE_RUN_SLEEP"
    id=20261018-000000-000001
    mkdir -p "$proj/.factory/runs/$id"
    script="$(grep -o 'script: [^ ,}]*' "$cfg" | head -n 1 | sed 's/^script: //')"
    reward=0
    [ -z "$script" ] || ! grep -q 'server.js' "$script" || reward=1
    [ -z "${FAKE_REWARD:-}" ] || reward="$FAKE_REWARD"
    printf '{"schema":"ygg.score/v1","reward":%s,"task":"smoke-notes","task_version":"1.0.0","fail_to_pass":{"passed":6,"total":6},"pass_to_pass":{"passed":1,"total":1}}\n' "$reward" >"$proj/.factory/runs/$id/score.json"
    [ -z "${FAKE_LEAK:-}" ] || cp "$proj/.factory/runs/$id/score.json" "$proj/score.json"
    {
      echo '{"seq":1,"event":"node_finished","ygg.node.id":"build","gen_ai.usage.input_tokens":1000,"gen_ai.usage.output_tokens":200,"gen_ai.usage.cache_read.input_tokens":5000,"ygg.usage.turns":3,"ygg.usage.cost_usd":0.25}'
      echo '{"seq":2,"event":"node_failed","ygg.node.id":"build","gen_ai.usage.input_tokens":500,"gen_ai.usage.output_tokens":100,"ygg.usage.turns":2,"ygg.usage.cost_usd":0.125,"ygg.usage.cost_estimated":true}'
      echo '{"seq":3,"event":"grade_finished","ygg.grade.reward":'"$reward"'}'
      echo '{"seq":4,"event":"run_finished","gen_ai.usage.input_tokens":1500,"gen_ai.usage.output_tokens":300,"ygg.usage.turns":5,"ygg.usage.cost_usd":0.375}'
    } >"$proj/.factory/runs/$id/ledger.jsonl"
    echo "Run $id is done."
    exit "${FAKE_RUN_RC:-0}" ;;
  grade)
    id="$(ls -1 "$proj/.factory/runs" | tail -n 1)"
    echo '{"seq":9,"event":"grade_finished"}' >>"$proj/.factory/runs/$id/ledger.jsonl"
    echo "Graded run $id: smoke-notes 1.0.0 against suite v1." ;;
esac
EOF
# The fake podman: no container, or the containers a test asks for. A container line is
# "<name> <grader label or -> <mount source>": the agents of each case, and the grader that holds the suite.
cat >"$T/bin/podman" <<'EOF'
#!/usr/bin/env bash
w="$(ls -d "$FAKE_IT"/smoke-*/ 2>/dev/null | tail -n 1)"; w="${w%/}"
case "$1" in
  ps)
    case "$*" in *label=ygg.grader*) [ -z "${FAKE_LEFTOVER:-}" ] || echo abc123 ;; *) [ -z "$w" ] || echo agent1 ;; esac ;;
  inspect)
    [ -z "$w" ] || {
      echo "ygg_reference_work_1 - $w/reference/project/repos/notes"
      echo "ygg_empty_work_1 - $w/empty/project/repos/notes"
      echo "ygg-grader-run-smoke-notes $FAKE_RUN $w/suites/smoke-notes/v1/tests"
      [ -z "${FAKE_SUITE_LEAK:-}" ] || echo "ygg_leaky_work_1 - $w/suites/smoke-notes"
    } ;;
esac
EOF
printf '#!/usr/bin/env bash\necho 0.89.0\n' >"$T/bin/devcontainer"
chmod +x "$T/bin/ygg" "$T/bin/podman" "$T/bin/devcontainer"
export PATH="$T/bin:$PATH" FAKE_IT="$T/it" FAKE_RUN=run1
# YGG_CMD is how ygg runs; this wrapper gives the fake its verb.
cat >"$T/bin/ygg-cmd" <<'EOF'
#!/usr/bin/env bash
verb="$1"; [ "$verb" != sandbox ] || verb=build
FAKE_VERB="$verb" exec "$(dirname "$0")/ygg" "$@"
EOF
chmod +x "$T/bin/ygg-cmd"
export YGG_CMD="$T/bin/ygg-cmd" YGG_BIND="$T/bind" YGG_ODIN="$T/odin"
mkdir -p "$T/bind"
D="$T/it"
newest() { find "$D" -maxdepth 1 -type d -name "$1" | sort | tail -n 1; } # the newest folder the script made
gargs=(--folder "$D" --tasks "$M" --odin "$T/odin")

# --- ygg-smoke-grade.sh.
run "$S/ygg-smoke-grade.sh" --nope
check "an unknown flag is refused" test "$rc" -eq 2
run "$S/ygg-smoke-grade.sh" "${gargs[@]}"
check "a missing factory.yaml is refused" test "$rc" -eq 2
printf 'sandbox:\n  engine: unix:///run/ygg-test.sock\n' >"$D/factory.yaml"
run "$S/ygg-smoke-grade.sh" --folder "$D" --tasks "$T/nowhere" --odin "$T/odin"
check "a missing task folder is refused" test "$rc" -eq 2
run "$S/ygg-smoke-grade.sh" "${gargs[@]}"
check "a good run passes every check and exits 0" test "$rc" -eq 0
check "the reference case grades 1" has "smoke-grade: reference reward 1"
check "the empty case grades 0" has "smoke-grade: empty reward 0"
check "no check failed" hasnt "FAIL"
check "the watch sees the grader hold the suite folder" has "the watch saw the grader container hold the suite folder"
w="$(newest "smoke-grade-*" | head -n 1)"
check "the suite folder is a copy of the PUBLIC suite and nothing else" diff -r "$M/smoke-notes/sample-suite/tests" "$w/suites/smoke-notes/v1/tests"
check "the suite is named by the task's metadata.suite" test -f "$w/suites/smoke-notes/v1/tests/manifest.json"
check "the reference answers write the reference files" grep -q 'path: "server.js"' "$w/reference/script.yaml"
check "and make start.sh executable" grep -q '"chmod", "+x", "start.sh"' "$w/reference/script.yaml"
check "the empty answers write no reference file" test -z "$(grep 'server.js' "$w/empty/script.yaml")"
check "a content with quotes and tabs is written as one YAML string" grep -q 'a \\\\\\"quote' "$w/reference/script.yaml"
check "the project holds the start.sh that runs the leaf's" grep -q 'repos/notes' "$w/reference/project/start.sh"
check "the grader runs with no limit on an engine that has none" grep -q 'memory: none' "$w/reference/factory.yaml"
check "the folder of the suite is outside both projects" test -z "$(find "$w/reference/project" "$w/empty/project" -path '*suites*' -not -path '*/.git/*' | head -n 1)"
sleep 1
run "$S/ygg-smoke-grade.sh" "${gargs[@]}" --limits
check "--limits asks for 4g and 4 CPUs" grep -q 'memory: 4g' "$(newest "smoke-grade-*")/reference/factory.yaml"
sleep 1
FAKE_LEAK=1 run "$S/ygg-smoke-grade.sh" "${gargs[@]}"
check "a score.json outside the run folder fails the smoke" test "$rc" -eq 1
check "and the failing line says which check" has "FAIL  reference: score.json is in the run folder and nowhere else"
sleep 1
FAKE_REWARD=0.5 run "$S/ygg-smoke-grade.sh" "${gargs[@]}"
check "a reference that does not grade 1 fails the smoke" has "FAIL  reference: reward is 1"
sleep 1
FAKE_REWARD=1 run "$S/ygg-smoke-grade.sh" "${gargs[@]}"
check "an empty product that grades 1 fails the smoke" has "FAIL  empty: reward is below 1"
sleep 1
FAKE_LEFTOVER=1 run "$S/ygg-smoke-grade.sh" "${gargs[@]}"
check "a grader container left behind fails the smoke" has "FAIL  reference: no container with the label ygg.grader is left"
sleep 1
FAKE_SUITE_LEAK=1 run "$S/ygg-smoke-grade.sh" "${gargs[@]}"
check "an agent container that holds the suite folder fails the smoke" has "FAIL  reference: the watch saw"
check "and the smoke exits 1" test "$rc" -eq 1
sleep 1
FAKE_DOCTOR_RC=1 run "$S/ygg-smoke-grade.sh" "${gargs[@]}"
check "a doctor that does not find 0 grader containers fails the smoke" has "FAIL  reference: ygg doctor finds 0 grader containers"

exit "$fail"
```

Run it and `shellcheck -s bash scripts/ygg-smoke-grade.sh scripts/tests/ygg-smoke-grade.test.sh`. Expect 26 `ok` lines, no `FAIL`, and no shellcheck output.

- [ ] **Step 5:** run the smoke on a real engine. `REF` is the reference workspace; for the founder it is the umbrella (see v0-H16).

```zsh
cd $REF/ouroboric
scripts/ygg-smoke-grade.sh --build --odin $REF/odin
```

```output
smoke-grade: made $HOME/ygg-it/smoke-grade-<time>
smoke-grade: the suite is the PUBLIC sample suite $REF/mimir/smoke-notes/sample-suite/tests (suite v1)
Run 20261018-195952-7a7506 started in unattended mode.
Run 20261018-195952-7a7506 is done.
PASS  reference: ygg run ended done (exit 0, run 20261018-195952-7a7506)
Graded run 20261018-195952-7a7506: smoke-notes 1.0.0 against suite v1.
reward:        1.0000
fail-to-pass:  6/6
pass-to-pass:  1/1
score:         $HOME/ygg-it/smoke-grade-<time>/reference/project/.factory/runs/20261018-195952-7a7506/score.json
PASS  reference: ygg grade of the finished run exited 0
smoke-grade: reference reward 1
PASS  reference: reward is 1
PASS  reference: the ledger has grade_finished twice (the node, then the command)
PASS  reference: no container with the label ygg.grader is left
PASS  reference: ygg doctor finds 0 grader containers
PASS  reference: the watch saw 2 agent container(s) of this run, and none held the suite folder
PASS  reference: the watch saw the grader container hold the suite folder (the watch works)
PASS  reference: score.json is in the run folder and nowhere else
Run 20261018-200013-0fc15c started in unattended mode.
Run 20261018-200013-0fc15c is done.
PASS  empty: ygg run ended done (exit 0, run 20261018-200013-0fc15c)
Graded run 20261018-200013-0fc15c: smoke-notes 1.0.0 against suite v1.
reward:        0.0000
fail-to-pass:  0/6
pass-to-pass:  0/1
score:         $HOME/ygg-it/smoke-grade-<time>/empty/project/.factory/runs/20261018-200013-0fc15c/score.json
PASS  empty: ygg grade of the finished run exited 0
smoke-grade: empty reward 0
PASS  empty: reward is below 1 (it is 0)
PASS  empty: the ledger has grade_finished twice (the node, then the command)
PASS  empty: no container with the label ygg.grader is left
PASS  empty: ygg doctor finds 0 grader containers
PASS  empty: the watch saw 2 agent container(s) of this run, and none held the suite folder
NOTE  empty: the watch did not catch the grader container while it ran (a 1 second poll can miss it)
PASS  empty: score.json is in the run folder and nowhere else

smoke-grade: the folder is $HOME/ygg-it/smoke-grade-<time>
smoke-grade: every check passed
```

The first line of the run shows the folder. Its `reference/project/.factory/runs/<id>/score.json` is the score of the reference. The `ygg grade` lines are the T250 command on the same run.

- [ ] **Step 6:** commit three times, one per repo (see "How each task lands"). Stage by path.

```zsh
git -C gungnir add schema/factory.go schema/factory.schema.json schema/factory_grader_test.go
git -C gungnir commit -m "The grader's limits may be written as none, for an engine that cannot apply memory or CPU limits (v0-T262)"
git -C odin add internal/engine internal/cli testdata/smoke-grade
git -C odin commit -m "The grader smoke realm, and no limit for an engine that cannot apply one (v0-T262)"
git -C ouroboric add scripts/ygg-smoke-grade.sh scripts/tests/ygg-smoke-grade.test.sh
git -C ouroboric commit -m "ygg-smoke-grade.sh: the grader smoke on a real engine, with the public sample suite of smoke-notes (v0-T262)"
```

**Evidence (v0-T262):** built and run in the reference workspace on 2026-10-18. Commits: `gungnir` `5988fdf` (branch `grader/limits-docs`), `odin` `c523c83` (branch `grader/odin`), `ouroboric` `8caf6a4` (branch `grader/scripts`). None is pushed.

- **Real engine.** Podman 5.7.1 rootless on WSL (the user socket `podman-user.sock`), devcontainer CLI 0.89.0, the pinned Playwright 1.63.0 image pulled and built by `ygg sandbox build` and by the grader. The last full run is the output above: both cases, every check `PASS`, exit 0. The reference graded 1.0000 (6 of 6, 1 of 1) in about 3 seconds of container time, twice (the grade node, then `ygg grade`). The empty product graded 0.0000 (0 of 6, 0 of 1). Two agent containers of each run were seen by the poll, and none held the suite folder. The poll saw the grader container hold the suite folder in the first case and missed it in the second (the NOTE line): that is the expected miss.
- **The grader container ran with no limit.** With `memory: 4g` and `cpus: 4` the same engine fails the container (`crun: open memory.max for writing`). This was tried by hand with `podman run --memory 512m` and `--cpus 2` on an image of the workspace. Each failed with the error above. The `--limits` flag was NOT run on a real engine: this engine cannot. It is run only by the fake test (`memory: 4g`).
- **A first run found the stack missing** (`a sandbox image is missing: localhost/ygg-work:...`), hence `--build`. A second run found that `ygg grade` refuses a realm that changed (decision 4). Both are in the script's header now.
- **Tests.** `GOWORK` was the reference `go.work`. `go test -race -count=1 ./...` passes in every package of `odin` (the slowest: `internal/engine` 112 s, `internal/cli` 48 s, `internal/run` 27 s) and in `gungnir`; `gofmt -l` and `go vet ./...` print nothing; `bash scripts/tests/ygg-smoke-grade.test.sh` prints 26 `ok` and no `FAIL`; `shellcheck -s bash` prints nothing for the new files.
- **Mutations**, each undone: the engine passing `cfg.Memory` and `cfg.CPUs` instead of the limits made `TestNoLimitGoesToTheDriverAsNoLimit` fail (`limits = "none", 0; want none`); the suite-folder check made always true failed `an agent container that holds the suite folder fails the smoke` and `and the smoke exits 1`; the `score.json` check removed failed `a score.json outside the run folder fails the smoke`.
- **Not run:** `GOWORK=off go test` in `odin` (the pins of v0-T245 and v0-T246 are not merged); `reuse lint` (`reuse` is not installed here); the `--limits` flag on a real engine; the Dockerfile of `client-gallery-lite`; a hidden suite (none exists for `smoke-notes`, and none was read).

### Task v0-T263: the real-agent smoke: a script with real caps, a dry run, and the cost from the ledger

Odin's and `ouroboric`'s task of Phase 5c. It builds on v0-T262. The realm is the same: a real Claude Code implements `smoke-notes`, a real OpenCode on OpenRouter reviews it, and the grade node grades it with the public sample suite. This run costs money and needs credentials. **Nobody runs it in this task.** The task builds the script, the config and the tests, and it runs the script in `--dry-run` and with fake tools.

**Files:**

- `odin`: Create `testdata/smoke-grade/factory.real.example.yaml`, `internal/run/smoke_grade_test.go` (commit `3e4f99d`).
- `ouroboric`: Create `scripts/ygg-smoke-real.sh`, `scripts/ygg-cost.sh`. Modify `scripts/tests/ygg-smoke-grade.test.sh`, `AGENTS.md` (commit `0302bc1`).

**Interfaces:**

- Consumes: the realm of v0-T262, `ygg doctor`, `ygg-evidence.sh`, `ygg-engine.sh`, the rules of change require-budget-caps (`schema.CapsError`).
- Produces: `ygg-smoke-real.sh [--dry-run] [--build] [--folder DIR] [--env FILE] [--tasks DIR] [--odin DIR] [--wall TIME] [--clip]` and `ygg-cost.sh LEDGER [FACTORY_YAML]`.

**Decisions and flags:**

1. **The caps.** The config has: `per_run` 400000 tokens, 100 turns, 3 dollars; `per_day` 1000000 tokens, 200 turns, 6 dollars (the reviewer is a paid API, so the rules ask for dollars). Each session has a cap in the graph: the implementer 40 turns and 20 minutes, the reviewer 10 turns and 5 minutes. The grading container has `grader.timeout: 10m`. The script runs `ygg` under `timeout --signal=INT --kill-after=2m 90m`. A cap that is hit stops the run at `budget-cap`. The sums are a guess for a small web product; the first real run tells if they fit. Please confirm the dollar caps before v0-H17.
2. **There is no per-agent token cap.** The factory has no such cap. The per-agent limits are the turns and the time of each session in the graph. The tokens are capped for the whole run and the whole day. A cap per role is a change to `gungnir` and `odin`; the plan does not make it. Please say if it is wanted.
3. **How the script handles the credentials file.** It never prints, copies or parses a value. It checks that the file exists, and it runs `grep -c` for each of the two names (`CLAUDE_CODE_OAUTH_TOKEN`, `OPENROUTER_API_KEY`) with a value after the equals sign. `grep -c` prints a count. The run needs the values in the environment of `ygg`, so, like the other smoke scripts, it loads the file with `. FILE` inside the subshell that runs `ygg`. A test reads the source of the script and fails if any other line uses the file name. **Open question:** if "never read" must also forbid that load, the run needs another way to pass the two variables (for example `systemd-run --user -p EnvironmentFile=`). I did not add it.
4. **No new flag for the fake agents.** The existing pattern is `YGG_CMD` (a fake `ygg`) and `YGG_ENGINE_CHECK=0`, as in `ygg-evidence.test.sh`. The test uses it. The script has one new mode, `--dry-run`: it makes the folder, the project and the config, runs `ygg doctor` on the config (which spends nothing and refuses a bad config), prints the caps and the command it would run, and stops. It does not load the credentials.
5. **The cost comes from the ledger.** `ygg-cost.sh` adds the usage of every line that has one (finished and failed sessions) and leaves out `run_finished`, `run_paused` and `run_failed`, which repeat the totals. It prints the tokens, the turns, the dollars and whether any cost is an estimate, and the `per_run` dollar cap beside it. The script prints it after every real run, also after a failure.
6. **The public suite grades the real run.** No hidden suite of `smoke-notes` exists. The real agents never mount the suite folder, which is outside the project. When a hidden suite exists, put it in the `suite_dir` of a copy of this config.

**Acceptance criteria:**

- [ ] The example config loads with `claude-code` and `opencode`, and `Prepare` on the realm gives a loop, a grade node last, the egress of the two adapters only, and caps in tokens, turns and dollars. A config without a dollar cap or without a turn cap gives a `*CapsError`.
- [ ] `ygg-smoke-real.sh --dry-run` exits 0, runs `ygg doctor` on the generated config, prints the caps and the command, and does not run `ygg run` or load the credentials.
- [ ] A missing credentials file, a missing name and a name with no value are refused with exit 2, and no value is printed.
- [ ] A config that `ygg doctor` refuses stops the script before any run.
- [ ] A hung run is stopped by `--wall` and the script exits 124.
- [ ] After a run the script prints the evidence report with the credentials removed, the score, and the cost with the cap.

**Review focus pinned by tests:** the credentials file is only tested for existence, counted with `grep -c`, and loaded in the subshell (`the only uses of the credentials file are...`, `the credentials file is not read by cat, head, tail, sed or awk`, `no credential value is printed`, `no credential value is in the saved report or run output`); a dry run spends nothing (`a dry run does not start the run`, `a dry run does not load the credentials`); the caps are real (`TestTheGraderSmokeRealmPreparesWithRealAgentsAndRealCaps`, `TestTheRealExampleNeedsItsDollarCaps`); the wall clock stops a hung run (`the wall clock ends a run that hangs, and the code is 124`); the cost counts sessions and not the run's own total (`the cost counts the two sessions and not the run's own total`).

**Named test:** `go test ./internal/run -run 'TestTheGraderSmokeRealm|TestTheRealExample'` in `odin`; `bash scripts/tests/ygg-smoke-grade.test.sh` in `ouroboric`. **Layer:** `odin`, `ouroboric`. **Size:** L. **Depends on:** v0-T262.

- [ ] **Step 1:** write the example config. `ygg-smoke-real.sh` fills the five places between at signs.

Create `testdata/smoke-grade/factory.real.example.yaml`:

```yaml
# The factory.yaml of the real-agent smoke run (v0-H17), with real caps. ouroboric/scripts/ygg-smoke-real.sh
# fills the places written between two at signs (engine, folder, bind mount, tasks, suites) from its flags and
# writes the result to the run's folder. It never writes your factory.yaml. The implementer is Claude Code (subscription: CLAUDE_CODE_OAUTH_TOKEN) and the reviewer is
# OpenCode on OpenRouter (a paid API: OPENROUTER_API_KEY), so the caps count dollars. The credentials come
# from the environment, never from this file.
#
# The caps, from the widest to the narrowest:
#   - budget.per_day and budget.per_run: tokens (input and output, not cache reads), turns and dollars. The
#     run stops at the hard approval point budget-cap before a session would start over one of them.
#   - the graph's own caps for each session: max_turns and timeout of the implementer (40 turns, 20 minutes)
#     and of the reviewer (10 turns, 5 minutes). There is no token cap for one agent; the turns and the time
#     are the per-agent limit.
#   - the wall clock: the script runs ygg under `timeout` (--wall, 90 minutes by default) and stops it
#     with an interrupt; grader.timeout is the most the grading container may run.
mode: unattended
privacy: strict
roles:
  implementer: { agent: claude-code, model: sonnet }
  reviewer: { agent: opencode, model: openrouter/deepseek/deepseek-v4-flash }
budget:
  per_run: { tokens: 400000, turns: 100, usd: 3 }
  per_day: { tokens: 1000000, turns: 200, usd: 6 }
sandbox:
  engine: @ENGINE@
  mounts:
    - { host: @FOLDER@, engine: @BIND@ }
grader:
  tasks_dir: @TASKS@
  suite_dir: @SUITES@
  timeout: 10m
  memory: none
  cpus: 0
```

- [ ] **Step 2:** write the test of the realm and the caps. These tests pin behavior of the config and the realm. They were written with them and have no red step.

Create `internal/run/smoke_grade_test.go`:

```go
package run

import (
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

// realExample fills the places of testdata/smoke-grade/factory.real.example.yaml, as ygg-smoke-real.sh does,
// and writes the result to a config file. edit changes the text first.
func realExample(t *testing.T, edit func(string) string) (config string, tasks, suites string) {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("..", "..", "testdata", "smoke-grade", "factory.real.example.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	folder := t.TempDir()
	tasks, suites = filepath.Join(folder, "mimir"), filepath.Join(folder, "suites")
	for _, d := range []string{tasks, suites} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	text := strings.NewReplacer("@ENGINE@", "unix:///run/ygg-test.sock", "@FOLDER@", folder, "@BIND@", "/mnt/wsl/ygg-bind", "@TASKS@", tasks, "@SUITES@", suites).Replace(string(b))
	if edit != nil {
		text = edit(text)
	}
	if m := regexp.MustCompile(`@[A-Z]+@`).FindString(text); m != "" {
		t.Fatalf("the example has a place the script does not fill: %s", m)
	}
	config = filepath.Join(t.TempDir(), "factory.yaml")
	if err := os.WriteFile(config, []byte(text), 0o644); err != nil {
		t.Fatal(err)
	}
	return config, tasks, suites
}

// The grader smoke realm (v0-H16, v0-H17) is a loop and a grade node. With the real example config it must
// prepare with the two real adapters, real caps in every dimension, and a grade node at the end.
func TestTheGraderSmokeRealmPreparesWithRealAgentsAndRealCaps(t *testing.T) {
	if os.Getuid() == 0 {
		t.Skip("ygg refuses to prepare a sandbox as root: the sandbox's user is the operator's own")
	}
	smoke, err := filepath.Abs("../../testdata/smoke-grade")
	if err != nil {
		t.Fatal(err)
	}
	config, tasks, suites := realExample(t, nil)
	s, err := Prepare(ctx, Options{Project: treetest.Project(t), Config: config, Realm: smoke})
	if err != nil {
		t.Fatal(err)
	}
	loop, last := s.Graph.Nodes[0], s.Graph.Nodes[len(s.Graph.Nodes)-1]
	if loop.Kind != "loop" || last.Kind != "grade" || s.Agents["implementer"].Name() != "claude-code" || s.Agents["reviewer"].Name() != "opencode" {
		t.Errorf("first node %+v, last node %+v, agents %v", loop, last, s.Agents)
	}
	if strings.Join(s.Sandbox.Egress, ",") != "api.anthropic.com,openrouter.ai" {
		t.Errorf("egress %v: the realm adds nothing to what the two adapters need", s.Sandbox.Egress)
	}
	// Every session has a turn cap and a time cap in the graph; the run has token, turn and dollar caps.
	if loop.MaxTurns != 40 || time.Duration(loop.Timeout) != 20*time.Minute || len(loop.Reviewers) != 1 ||
		loop.Reviewers[0].MaxTurns != 10 || time.Duration(loop.Reviewers[0].Timeout) != 5*time.Minute {
		t.Errorf("the loop's session caps: %+v", loop)
	}
	b := s.Config.Budget
	if b.PerRun.Tokens <= 0 || b.PerRun.Turns <= 0 || b.PerRun.USD <= 0 || b.PerDay.USD < b.PerRun.USD || b.PerDay.Tokens < b.PerRun.Tokens {
		t.Errorf("budget %+v: the run needs caps in tokens, turns and dollars, and the day at least the run's", b)
	}
	g := s.Config.Grader
	if mem, cpus := g.Limits(); g.TasksDir != tasks || g.SuiteDir != suites || mem != "" || cpus != 0 {
		t.Errorf("grader %+v: want the two folders, and no limit (memory: none, cpus: 0)", g)
	}
}

// A paid reviewer needs a dollar cap: the existing rule (change require-budget-caps) refuses the example without one.
func TestTheRealExampleNeedsItsDollarCaps(t *testing.T) {
	for name, edit := range map[string]func(string) string{
		"the run's dollar cap": func(s string) string { return strings.Replace(s, ", usd: 3", "", 1) },
		"the day's dollar cap": func(s string) string { return strings.Replace(s, ", usd: 6", "", 1) },
		"the run's turn cap":   func(s string) string { return strings.Replace(s, "tokens: 400000, turns: 100", "tokens: 400000", 1) },
	} {
		config, _, _ := realExample(t, edit)
		b, _ := os.ReadFile(config)
		_, err := schema.ParseFactory(config, b)
		var ce *schema.CapsError
		if !errors.As(err, &ce) {
			t.Errorf("without %s: ParseFactory() = %v, want a *CapsError", name, err)
		}
	}
}
```

Run `go test -race -count=1 -run 'TestTheGraderSmokeRealm|TestTheRealExample' -v ./internal/run`. Expect two `PASS` lines.

- [ ] **Step 3:** write the two scripts.

Create `scripts/ygg-smoke-real.sh`:

```bash
#!/usr/bin/env bash
# Run the real-agent smoke (v0-H17): the task smoke-notes built by the real Claude Code and the real OpenCode on
# OpenRouter, then graded. IT COSTS MONEY: the caps are in odin/testdata/smoke-grade/factory.real.example.yaml.
#   ygg-smoke-real.sh [--dry-run] [--build] [--folder DIR] [--env FILE] [--tasks DIR] [--odin DIR] [--wall TIME] [--clip]
# The suite is the PUBLIC sample suite of the task (no hidden suite of smoke-notes exists); the agents never mount
# it. Needs DIR/factory.yaml (it names the engine; this script never writes it), the credentials file, the
# devcontainer CLI 0.89.0, jq and python3, the engine up, the bind mount present, and a checkout of `mimir`. It
#   1. checks the engine, the tools and the task;
#   2. checks the credentials file WITHOUT reading it: the file exists, and each of the two names
#      CLAUDE_CODE_OAUTH_TOKEN and OPENROUTER_API_KEY is on one line with a value after it (grep -c counts the
#      lines; no value is printed or kept);
#   3. makes DIR/smoke-real-<time> with the project, the public suite and the factory.yaml filled from the
#      example (its caps are the real ones);
#   4. runs `ygg doctor` on that config. A config that doctor refuses stops the script before any money is spent;
#   5. with --dry-run, stops here and prints what it would run;
#   6. otherwise runs `ygg run` under `timeout` (--wall, default 90m) with the credentials loaded in a subshell
#      only, and keeps the raw output in DIR/smoke-real-<time>/run.txt (shown live: do not paste that file);
#   7. prints the evidence report (credentials removed), the score, and the COST read from the ledger.
# The credentials are loaded by `. FILE` in the subshell that runs ygg, as the other smoke scripts do, and nothing
# in this script echoes, greps for a value, or copies them. The exit code is the run's (0 done, 1 a node failed,
# 3 stopped, 4 paused, 5 done with tasks given up, 124 the wall clock ended it) or 2 for a refusal before it.
# Defaults: DIR=$HOME/ygg-it, FILE=$HOME/.config/ouroboric/factory.env. For tests and other machines: YGG_CMD (how
# ygg runs), YGG_ODIN (the odin folder), YGG_BIND (the bind mount, default /mnt/wsl/ygg-bind), YGG_CLI_VERSION
# (default 0.89.0). The engine environment comes from ygg-engine.sh (YGG_ENGINE_CHECK=0 skips it).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dir="$HOME/ygg-it" envfile="$HOME/.config/ouroboric/factory.env" tasks="$HERE/../../mimir" wall=90m dry=0 build=0 clip=()
odin="${YGG_ODIN:-$HERE/../../yggdrasil/odin}"
usage() { echo "usage: ygg-smoke-real.sh [--dry-run] [--build] [--folder DIR] [--env FILE] [--tasks DIR] [--odin DIR] [--wall TIME] [--clip]" >&2; exit 2; }
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1; shift ;;
    --build) build=1; shift ;;
    --folder) [ $# -ge 2 ] || usage; dir="$2"; shift 2 ;;
    --env) [ $# -ge 2 ] || usage; envfile="$2"; shift 2 ;;
    --tasks) [ $# -ge 2 ] || usage; tasks="$2"; shift 2 ;;
    --odin) [ $# -ge 2 ] || usage; odin="$2"; shift 2 ;;
    --wall) [ $# -ge 2 ] || usage; wall="$2"; shift 2 ;;
    --clip) clip=(--clip); shift ;;
    *) usage ;;
  esac
done
fail() { echo "smoke-real: $*" >&2; exit 2; }
task=smoke-notes
bind="${YGG_BIND:-/mnt/wsl/ygg-bind}"
case "$wall" in [1-9]*[smh]) ;; *) fail "--wall is a number and s, m or h, such as 90m" ;; esac

export PATH="$dir/dc/node_modules/.bin:$PATH"
if [ "${YGG_ENGINE_CHECK:-1}" = 1 ]; then
  engine_env="$("$HERE/ygg-engine.sh" env --folder "$dir")" || exit 2
  eval "$engine_env"
fi
[ -f "$dir/factory.yaml" ] || fail "$dir/factory.yaml is missing; it names the engine (sandbox.engine)"
engine="$(sed -n 's/^[[:space:]]*engine:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$dir/factory.yaml" | head -n 1)"
case "$engine" in unix://*) ;; *) fail "sandbox.engine in $dir/factory.yaml is '${engine:-missing}'; it must be a unix:// URL" ;; esac
for tool in jq python3 git timeout; do command -v "$tool" >/dev/null 2>&1 || fail "$tool is not installed"; done
tasks="$(cd "$tasks" 2>/dev/null && pwd)" || fail "no mimir folder at $tasks (--tasks)"
odin="$(cd "$odin" 2>/dev/null && pwd)" || fail "no odin folder at $odin (--odin)"
realm="$odin/testdata/smoke-grade"
public="$tasks/$task/sample-suite"
example="$realm/factory.real.example.yaml"
for f in "$tasks/$task/task.toml" "$tasks/$task/instruction.md" "$public/tests/manifest.json" "$public/tests/test.sh" "$realm/pack.yaml" "$example"; do
  [ -f "$f" ] || fail "$f is missing"
done
suite="$(sed -n 's/^suite[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$tasks/$task/task.toml" | head -n 1)"
[ -n "$suite" ] || fail "$tasks/$task/task.toml has no metadata.suite"

# The credentials file: its existence, and the two names. grep -c prints a count and nothing else; the file's
# lines are never shown, stored or compared. A name needs one line, with something after the equals sign.
[ -f "$envfile" ] || fail "the credentials file $envfile is missing"
for name in CLAUDE_CODE_OAUTH_TOKEN OPENROUTER_API_KEY; do
  n="$(grep -c -E "^(export[[:space:]]+)?${name}=[^[:space:]]" "$envfile" || true)"
  [ "$n" = 1 ] || fail "$envfile has $n line(s) that set $name with a value; it needs exactly 1"
done

work="$dir/smoke-real-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$work/suites/$task/$suite" "$work/project"
cp -r "$public/tests" "$work/suites/$task/$suite/tests"
project="$work/project"
git -C "$project" init -q -b main
printf 'root: true\nowner: ouroboric-dev\nvisibility: private\n' >"$project/umbrella.yaml"
# The grader's /app is the project. The product is built in the leaf; this file starts it.
# shellcheck disable=SC2016
printf '#!/bin/sh\ncd "$(dirname "$0")/repos/notes" && exec ./start.sh\n' >"$project/start.sh"
chmod +x "$project/start.sh"
git -C "$project" add umbrella.yaml start.sh
git -C "$project" -c user.name=ygg -c user.email=ygg@example.invalid commit -q -m "the real-agent smoke project"
echo "smoke-real: made $work"
echo "smoke-real: the suite is the PUBLIC sample suite $public/tests (suite $suite)"

# The config: the example with its places filled. Its caps are the example's.
text="$(<"$example")"
text="${text//@ENGINE@/$engine}"
text="${text//@FOLDER@/$dir}"
text="${text//@BIND@/$bind}"
text="${text//@TASKS@/$tasks}"
text="${text//@SUITES@/$work/suites}"
printf '%s\n' "$text" >"$work/factory.yaml"
if grep -q '@[A-Z]*@' "$work/factory.yaml"; then fail "$work/factory.yaml still has a place to fill: $(grep -o '@[A-Z]*@' "$work/factory.yaml" | sort -u | tr '\n' ' ')"; fi

ygg="${YGG_CMD:-}"
if [ -z "$ygg" ]; then
  if command -v ygg >/dev/null 2>&1; then ygg=ygg
  else
    mkdir -p "$work/bin"
    (cd "$odin" && go build -o "$work/bin/ygg" ./cmd/ygg) || fail "go build of ygg failed in $odin"
    ygg="'$work/bin/ygg'"
  fi
fi

echo "smoke-real: the caps in $work/factory.yaml:"
grep -E '^  per_(run|day):' "$work/factory.yaml" | sed 's/^/  /'
echo "smoke-real: ygg doctor on that config"
if ! eval "$ygg doctor --project '$project' --config '$work/factory.yaml'"; then fail "ygg doctor refused the config; nothing was spent"; fi

run="$ygg run --project '$project' --config '$work/factory.yaml' --realm '$realm' --brief '$tasks/$task/instruction.md'"
if [ "$dry" -eq 1 ]; then
  [ "$build" -eq 0 ] || echo "smoke-real: would run: $ygg sandbox build --config '$work/factory.yaml' --realm '$realm'"
  echo "smoke-real: would run: timeout --signal=INT --kill-after=2m $wall $run"
  echo "smoke-real: dry run: nothing was started and the credentials were not loaded"
  exit 0
fi

out="$work/run.txt"
# The credentials live only in this subshell; nothing here prints them.
set +e
(
  set -a
  # shellcheck source=/dev/null
  . "$envfile"
  set +a
  if [ "$build" -eq 1 ]; then eval "$ygg sandbox build --config '$work/factory.yaml' --realm '$realm'"; fi
  eval "timeout --signal=INT --kill-after=2m '$wall' $run"
) 2>&1 | tee "$out"
rc="${PIPESTATUS[0]}"
set -e
echo "smoke-real: the run ended with exit code $rc (0 done, 1 a node failed, 3 stopped, 4 paused, 5 done with tasks given up, 124 wall clock)" >&2

report="$work/report.txt"
( set -a
  # shellcheck source=/dev/null
  . "$envfile"
  set +a
  YGG_CMD="$ygg" "$HERE/ygg-evidence.sh" --config "$work/factory.yaml" --output "$out" ${clip[@]+"${clip[@]}"} "$project"
) | tee "$report" || echo "smoke-real: no evidence report: the run left no ledger" >&2

# The score and the cost come from the run folder and its ledger; neither holds a credential.
id="$(find "$project/.factory/runs" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | tail -n 1 || true)"
if [ -n "$id" ] && [ -f "$project/.factory/runs/$id/score.json" ]; then
  jq -r '"smoke-real: score \(.task) \(.task_version): reward \(.reward), fail-to-pass \(.fail_to_pass.passed)/\(.fail_to_pass.total), pass-to-pass \(.pass_to_pass.passed)/\(.pass_to_pass.total)"' "$project/.factory/runs/$id/score.json"
else
  echo "smoke-real: no score.json: the run did not reach the grade node"
fi
if [ -n "$id" ] && [ -f "$project/.factory/runs/$id/ledger.jsonl" ]; then
  "$HERE/ygg-cost.sh" "$project/.factory/runs/$id/ledger.jsonl" "$work/factory.yaml"
fi
echo "smoke-real: the folder is $work" >&2
exit "$rc"
```

Create `scripts/ygg-cost.sh`:

```bash
#!/usr/bin/env bash
# Print what one ygg run spent, read from its ledger.
#   ygg-cost.sh LEDGER [FACTORY_YAML]
# Every ledger line that carries a session's usage is added up: the lines of the finished and the failed sessions.
# The run's own totals (run_finished, run_paused, run_failed) are left out, because they repeat the sessions. The
# cost is the sum of ygg.usage.cost_usd; a cost the adapter estimated is marked as such. With FACTORY_YAML, the
# per_run cap is printed beside the spend. The ledger holds no credential; this script reads nothing else.
set -euo pipefail
[ $# -ge 1 ] && [ $# -le 2 ] || { echo "usage: ygg-cost.sh LEDGER [FACTORY_YAML]" >&2; exit 2; }
[ -f "$1" ] || { echo "ygg-cost: no ledger at $1" >&2; exit 2; }
python3 -I - "$1" <<'PY'
import json, sys
totals = {"run_finished", "run_paused", "run_failed"}
n = tin = tout = cache = turns = 0
usd = 0.0
estimated = False
with open(sys.argv[1], encoding="utf-8") as f:
    for line in f:
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get("event") in totals:
            continue
        keys = ("gen_ai.usage.input_tokens", "gen_ai.usage.output_tokens", "ygg.usage.turns", "ygg.usage.cost_usd")
        if not any(e.get(k) for k in keys):
            continue
        n += 1
        tin += e.get("gen_ai.usage.input_tokens", 0)
        tout += e.get("gen_ai.usage.output_tokens", 0)
        cache += e.get("gen_ai.usage.cache_read.input_tokens", 0)
        turns += e.get("ygg.usage.turns", 0)
        usd += e.get("ygg.usage.cost_usd", 0.0)
        estimated = estimated or bool(e.get("ygg.usage.cost_estimated"))
print("ygg-cost: %d session line(s): %d tokens in, %d out, %d cache read, %d turns" % (n, tin, tout, cache, turns))
print("ygg-cost: cost $%.4f%s" % (usd, " (at least one session's cost is an estimate)" if estimated else ""))
PY
if [ $# -eq 2 ] && [ -f "$2" ]; then
  cap="$(grep -E '^  per_run:' "$2" | head -n 1 | sed -n 's/.*usd:[[:space:]]*\([0-9.]*\).*/\1/p')"
  [ -z "$cap" ] || echo "ygg-cost: the per_run cap is \$$cap"
fi
```

- [ ] **Step 4:** extend the test of v0-T262. The new cases run the cost script, then the real script with the fake tools. The credentials in the test are made-up values; the test checks that none of them appears in any output or saved file. Apply:

```diff
diff --git a/AGENTS.md b/AGENTS.md
index 78bf726..9bb817c 100644
--- a/AGENTS.md
+++ b/AGENTS.md
@@ -38,6 +38,8 @@ folder.
 | Push, open a pull request or read GitHub as `ouroboric-pr-bot` | `scripts/as-bot.sh <repo> <cmd>`; `--read all` to read. The only way an agent reaches GitHub |
 | Any real-engine run (Podman, devcontainer, the sandbox): the engine, registry config and checks | `scripts/ygg-engine.sh check\|env\|run --folder DIR`. Never set `CONTAINER_HOST` by hand: the root socket is the wrong one |
 | The realms smoke runs (v0-H13, v0-H15) and their evidence | `scripts/ygg-smoke-realms.sh`, `scripts/ygg-smoke-loop.sh`, `scripts/ygg-evidence.sh` |
+| The grader smoke on a real engine (v0-H16), with the public sample suite | `scripts/ygg-smoke-grade.sh [--build]`. Never a hidden suite |
+| The real-agent smoke (v0-H17): costs money; `--dry-run` first; the cost from the ledger | `scripts/ygg-smoke-real.sh --dry-run`, then without it; `scripts/ygg-cost.sh LEDGER`. It never prints the credentials file |
 | Build a plan from reference commits, or execute one task by task | `scripts/plan-*` (`plan-generate.py`, `plan-replay.py`, `plan-states.sh`, `plan-red.sh`, `plan-defences.py`; `plan-blocks.py`, `plan-task-start.sh`, `plan-task-done.sh`, `plan-task-land.sh`) |
 | Check that the repos have the required setup | `scripts/as-bot.sh --read all scripts/check-repos.sh` |
 | Scan git history for secrets | `scripts/scan-history.sh` |
diff --git a/scripts/tests/ygg-smoke-grade.test.sh b/scripts/tests/ygg-smoke-grade.test.sh
index 601ff2a..8af869f 100755
--- a/scripts/tests/ygg-smoke-grade.test.sh
+++ b/scripts/tests/ygg-smoke-grade.test.sh
@@ -1,5 +1,5 @@
 #!/usr/bin/env bash
-# Tests for ygg-smoke-grade.sh.   scripts/tests/ygg-smoke-grade.test.sh
+# Tests for ygg-smoke-grade.sh, ygg-smoke-real.sh and ygg-cost.sh.   scripts/tests/ygg-smoke-grade.test.sh
 # A fake `ygg`, a fake `podman` and a fake `devcontainer` stand in for the real tools: no model, no engine, no
 # network, no money. The task folder is a small made-up mimir with a made-up public suite.
 # shellcheck disable=SC2329,SC2016 # check calls has and hasnt by name; the $ in the patterns is literal
@@ -124,6 +124,24 @@ D="$T/it"
 newest() { find "$D" -maxdepth 1 -type d -name "$1" | sort | tail -n 1; } # the newest folder the script made
 gargs=(--folder "$D" --tasks "$M" --odin "$T/odin")
 
+# --- ygg-cost.sh.
+L="$T/ledger.jsonl"
+{
+  echo '{"seq":1,"event":"node_started"}'
+  echo '{"seq":2,"event":"node_finished","gen_ai.usage.input_tokens":1000,"gen_ai.usage.output_tokens":200,"gen_ai.usage.cache_read.input_tokens":5000,"ygg.usage.turns":3,"ygg.usage.cost_usd":0.25}'
+  echo '{"seq":3,"event":"node_failed","gen_ai.usage.input_tokens":500,"gen_ai.usage.output_tokens":100,"ygg.usage.turns":2,"ygg.usage.cost_usd":0.125,"ygg.usage.cost_estimated":true}'
+  echo '{"seq":4,"event":"run_finished","gen_ai.usage.input_tokens":1500,"gen_ai.usage.output_tokens":300,"ygg.usage.turns":5,"ygg.usage.cost_usd":0.375}'
+  echo 'not json'
+} >"$L"
+printf 'budget:\n  per_run: { tokens: 400000, turns: 100, usd: 3 }\n' >"$T/cap.yaml"
+run "$S/ygg-cost.sh" "$L" "$T/cap.yaml"
+check "the cost counts the two sessions and not the run's own total" has "2 session line(s): 1500 tokens in, 300 out, 5000 cache read, 5 turns"
+check "the cost is the sum of the sessions" has 'cost $0.3750'
+check "an estimated cost is marked" has "an estimate"
+check "the per_run cap is printed beside it" has 'per_run cap is $3'
+run "$S/ygg-cost.sh" "$T/nope.jsonl"
+check "a missing ledger is refused" test "$rc" -eq 2
+
 # --- ygg-smoke-grade.sh.
 run "$S/ygg-smoke-grade.sh" --nope
 check "an unknown flag is refused" test "$rc" -eq 2
@@ -172,4 +190,59 @@ sleep 1
 FAKE_DOCTOR_RC=1 run "$S/ygg-smoke-grade.sh" "${gargs[@]}"
 check "a doctor that does not find 0 grader containers fails the smoke" has "FAIL  reference: ygg doctor finds 0 grader containers"
 
+# --- ygg-smoke-real.sh. The credentials are made-up values; none may appear anywhere in the output.
+MARK_A='sekret-claude-0123456789'
+MARK_B='sekret-openrouter-9876543210'
+rargs=(--folder "$D" --tasks "$M" --odin "$T/odin" --env "$T/factory.env")
+run "$S/ygg-smoke-real.sh" "${rargs[@]}" --dry-run
+check "a missing credentials file is refused" test "$rc" -eq 2
+printf 'CLAUDE_CODE_OAUTH_TOKEN=%s\n' "$MARK_A" >"$T/factory.env"
+run "$S/ygg-smoke-real.sh" "${rargs[@]}" --dry-run
+check "a credentials file with one name missing is refused" test "$rc" -eq 2
+check "and the refusal names the missing variable" has "OPENROUTER_API_KEY"
+check "and prints no value" hasnt "$MARK_A"
+printf 'CLAUDE_CODE_OAUTH_TOKEN=%s\nOPENROUTER_API_KEY=\n' "$MARK_A" >"$T/factory.env"
+run "$S/ygg-smoke-real.sh" "${rargs[@]}" --dry-run
+check "a name with no value is refused" test "$rc" -eq 2
+printf 'export CLAUDE_CODE_OAUTH_TOKEN=%s\nOPENROUTER_API_KEY=%s\n' "$MARK_A" "$MARK_B" >"$T/factory.env"
+rm -f "$T/args.log"
+sleep 1
+FAKE_ARGS_LOG="$T/args.log" run "$S/ygg-smoke-real.sh" "${rargs[@]}" --dry-run
+check "a dry run exits 0" test "$rc" -eq 0
+check "a dry run says what it would run, under a wall clock" has "would run: timeout --signal=INT --kill-after=2m 90m"
+check "a dry run runs the doctor" grep -q '^doctor ' "$T/args.log"
+check "a dry run does not start the run" test -z "$(grep '^run ' "$T/args.log")"
+check "a dry run does not load the credentials" test -z "$(grep 'credentials were loaded' "$T/args.log")"
+check "a dry run prints the caps" has "per_run: { tokens: 400000, turns: 100, usd: 3 }"
+rc_yaml="$(newest "smoke-real-*")/factory.yaml"
+check "the config has no place left to fill" test -z "$(grep -h '@[A-Z]*@' "$rc_yaml")"
+check "the config has the real agents" grep -q 'agent: claude-code' "$rc_yaml"
+check "and the reviewer on OpenRouter" grep -q 'agent: opencode' "$rc_yaml"
+check "and dollar caps for the day" grep -q 'per_day:.*usd: 6' "$rc_yaml"
+sleep 1
+FAKE_DOCTOR_RC=1 FAKE_ARGS_LOG="$T/args2.log" run "$S/ygg-smoke-real.sh" "${rargs[@]}"
+check "a config that doctor refuses stops the script before the run" test "$rc" -eq 2
+check "and the run did not start" test -z "$(grep '^run ' "$T/args2.log")"
+sleep 1
+FAKE_ARGS_LOG="$T/args3.log" run "$S/ygg-smoke-real.sh" "${rargs[@]}" --build
+check "a run with the fake ygg exits with the run's code" test "$rc" -eq 0
+check "the images are built on request" has "built"
+check "the credentials were loaded for the run" grep -q 'credentials were loaded' "$T/args3.log"
+check "no credential value is printed" hasnt "$MARK_A"
+check "nor the second" hasnt "$MARK_B"
+check "the score is printed" has "reward 0, fail-to-pass 6/6"
+check "the cost is printed from the ledger" has 'cost $0.3750'
+check "and the cap beside it" has 'per_run cap is $3'
+w="$(newest "smoke-real-*")"
+check "no credential value is in the saved report or run output" test -z "$(grep -rl -e "$MARK_A" -e "$MARK_B" "$w" 2>/dev/null | head -n 1)"
+sleep 1
+FAKE_RUN_SLEEP=30 run "$S/ygg-smoke-real.sh" "${rargs[@]}" --wall 1s
+check "the wall clock ends a run that hangs, and the code is 124" test "$rc" -eq 124
+run "$S/ygg-smoke-real.sh" "${rargs[@]}" --wall soon
+check "a wall clock that is not a duration is refused" test "$rc" -eq 2
+# The script does not read the credentials file: every line that names it is on this list.
+bad="$(grep -n 'envfile' "$S/ygg-smoke-real.sh" | grep -v -E 'envfile=|--env\)|\[ -f "\$envfile" \]|grep -c -E "[^"]*" "\$envfile"|\. "\$envfile"|\$envfile (has|is missing)|source=|FILE' || true)"
+check "the only uses of the credentials file are the existence test, grep -c on a name, and the subshell load" test -z "$bad"
+check "the credentials file is not read by cat, head, tail, sed or awk" test -z "$(grep -E '(cat|head|tail|sed|awk|cut) [^|]*envfile' "$S/ygg-smoke-real.sh")"
+
 exit "$fail"
```

Run `bash scripts/tests/ygg-smoke-grade.test.sh` and `shellcheck -s bash scripts/ygg-smoke-real.sh scripts/ygg-cost.sh scripts/tests/ygg-smoke-grade.test.sh`. Expect 61 `ok` lines, no `FAIL`, and no shellcheck output.

- [ ] **Step 5:** run the dry run on the real engine, with a file of made-up values (not your credentials). It runs the real `ygg doctor` on the generated config.

```zsh
printf 'CLAUDE_CODE_OAUTH_TOKEN=dummy-value-one\nOPENROUTER_API_KEY=dummy-value-two\n' > $REF/t/dummy.env
cd $REF/ouroboric
scripts/ygg-smoke-real.sh --dry-run --env $REF/t/dummy.env --odin $REF/odin
```

```output
smoke-real: made $HOME/ygg-it/smoke-real-<time>
smoke-real: the suite is the PUBLIC sample suite $REF/mimir/smoke-notes/sample-suite/tests (suite v1)
smoke-real: the caps in $HOME/ygg-it/smoke-real-<time>/factory.yaml:
    per_run: { tokens: 400000, turns: 100, usd: 3 }
    per_day: { tokens: 1000000, turns: 200, usd: 6 }
smoke-real: ygg doctor on that config
OK    config: $HOME/ygg-it/smoke-real-<time>/factory.yaml
OK    tree: $HOME/ygg-it/smoke-real-<time>/project: 1 nodes, 1 checked out
WARN  realms: no realms section: --realm takes a path, and a project can't pin a realm leaf
OK    budget: this run 0 of 400000 tokens, 0 of 100 turns, $0.0000 of $3.0000; today 22000 of 1000000 tokens, 44 of 200 turns, $0.0000 of $6.0000 (journal $HOME/.local/state/ygg/spend)
OK    grader: 2 task(s) in $REF/mimir, suites in $HOME/ygg-it/smoke-real-<time>/suites
WARN  grader: the grader's container runs with no memory or CPU limit (grader.memory: none or cpus: 0); a suite that hangs or leaks is held by the timeout only
OK    engine: podman 5.7.1, rootless, at unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock
OK    devcontainer: CLI 0.89.0
OK    sandboxes: 18 container(s) of ygg runs
OK    graders: 0 grader container(s) of ygg runs
smoke-real: would run: timeout --signal=INT --kill-after=2m 90m '$HOME/ygg-it/smoke-real-<time>/bin/ygg' run --project '$HOME/ygg-it/smoke-real-<time>/project' --config '$HOME/ygg-it/smoke-real-<time>/factory.yaml' --realm '$REF/odin/testdata/smoke-grade' --brief '$REF/mimir/smoke-notes/instruction.md'
smoke-real: dry run: nothing was started and the credentials were not loaded
```

- [ ] **Step 6:** commit (see "How each task lands"), by path:

```zsh
git -C odin add testdata/smoke-grade/factory.real.example.yaml internal/run/smoke_grade_test.go
git -C odin commit -m "The real-agent smoke: an example config with real caps, and a test that the realm prepares with the two real adapters (v0-T263)"
git -C ouroboric add AGENTS.md scripts/ygg-smoke-real.sh scripts/ygg-cost.sh scripts/tests/ygg-smoke-grade.test.sh
git -C ouroboric commit -m "ygg-smoke-real.sh: the real-agent smoke with real caps, a dry run, a wall clock and the cost from the ledger (v0-T263)"
```

**Evidence (v0-T263):** built in the reference workspace on 2026-10-18. Commits: `odin` `3e4f99d`, `ouroboric` `0302bc1`. None is pushed.

- **What ran.** `bash scripts/tests/ygg-smoke-grade.test.sh`: 61 `ok`, no `FAIL`. `go test -race` of `TestTheGraderSmokeRealmPreparesWithRealAgentsAndRealCaps` and `TestTheRealExampleNeedsItsDollarCaps`: `ok`. The full `go test -race -count=1 ./...` of `odin` passes. `shellcheck -s bash` prints nothing for the new files. The dry run above ran the real `ygg doctor` against the real engine: the config is `OK`, the grader is `OK`, and the WARN for no limit shows.
- **Mutations**, each undone: the check of the two names made always true failed three cases (`a credentials file with one name missing is refused`, `... names the missing variable`, `a name with no value is refused`); the dry run made never to stop failed three cases (it started the run and loaded the credentials).
- **NOT run, on purpose:** the real run. No credential file was read or used. The dry run used a file of made-up values that the test workspace holds. Nothing was spent. The real Claude Code and OpenCode adapters were not started. The prompts of the realm (`build.md`, `review.md`) are therefore untested with a real model: the first real run is also their test.
- **Not run:** `reuse lint` (not installed); the wall clock with the real `ygg` (the test uses a fake that `exec`s `sleep`; `cmd/ygg` cancels its context on `SIGINT`, which was read and not exercised with a sandbox run).

### Task v0-T264: documentation: Odin (grade, deps bump, routing, the grade node and its flags), Gleipnir (Grade) and Gungnir (schemas, events, the grader block, the routing block)

The architecture pages and the README say what the code of Phase 5c does. Each page has a test that names the words it must keep.

**Files:**

- `odin`: Modify `README.md`, `docs/architecture.md`. Create `internal/cli/docs_test.go` (commit `b7ee9a5`).
- `gleipnir`: Modify `docs/architecture.md`. Create `sandbox/docs_test.go` (commit `0e17275`).
- `gungnir`: Modify `docs/architecture.md`. Create `docs_test.go` (commit `8063fcf`).

**Interfaces:**

- Consumes: the code of v0-T245 to v0-T263.
- Produces: pages in the style of the existing ones (a bullet for each responsibility, short sentences). The 5b plan has no test for the docs: its v0-T243 only looked at `git diff --stat`. These tests are new and small. They keep a new command or a new event from reaching a repo with no line in its docs.

**Acceptance criteria:**

- [ ] The README of `odin` shows every command of the usage text, `ygg grade` and `ygg deps bump` among them, and the exit codes 4 and 5.
- [ ] `docs/architecture.md` of `odin` describes: the `grade` node and the `ygg grade --task` command, the container and what an agent never sees, `score.json` and the reward, `grader.memory: none`, the leftover containers, the two routing indexes and their edge tags, the shrink guard, the bench and the pack's `routing` block, the `pointer-contract` gate, and `ygg deps bump --canary --rollout`.
- [ ] `docs/architecture.md` of `gleipnir` describes `Grade`, `BuildGrader`, the three mounts, the label, the removal, `GraderLeftovers` and `RemoveGrader`.
- [ ] `docs/architecture.md` of `gungnir` names the `grade` node, the `grader:` block, `score.json`, `manifest.json`, the seven new events, the five refusal reasons and the `routing` block.
- [ ] The three tests fail when a named word is removed from its page.

**Review focus pinned by tests:** a command of the usage text with no README line (`TestTheDocsNameEveryCommand`); a new event with no line in the contract page (`TestTheArchitecturePageNamesTheGraderContract`, which walks the seven `EventName` values); the grader's guarantees in the harness page (`TestTheArchitecturePageDescribesGrade`).

**Named test:** `go test ./internal/cli -run TestTheDocsNameEveryCommand` in `odin`; `go test ./sandbox -run TestTheArchitecturePageDescribesGrade` in `gleipnir`; `go test . -run TestTheArchitecturePageNamesTheGraderContract` in `gungnir`. **Layer:** `odin`, `gleipnir`, `gungnir`. **Size:** M. **Depends on:** v0-T263.

- [ ] **Step 1:** write the tests. They fail before the docs change (the words are not there).

Create `internal/cli/docs_test.go`:

```go
package cli

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// Every command of the usage text is in the README, and the architecture page names the commands and the
// node of the grader and the routing and dependency work. A new command with no line in the README fails here.
func TestTheDocsNameEveryCommand(t *testing.T) {
	readme, err := os.ReadFile(filepath.Join("..", "..", "README.md"))
	if err != nil {
		t.Fatal(err)
	}
	arch, err := os.ReadFile(filepath.Join("..", "..", "docs", "architecture.md"))
	if err != nil {
		t.Fatal(err)
	}
	commands := regexp.MustCompile(`(?m)^  (ygg [a-z]+(?: bump| build)?)`).FindAllStringSubmatch(usage, -1)
	if len(commands) < 9 {
		t.Fatalf("found %d commands in the usage text, want at least 9", len(commands))
	}
	for _, m := range commands {
		if !strings.Contains(string(readme), m[1]) {
			t.Errorf("README.md does not show %q", m[1])
		}
	}
	for _, want := range []string{"ygg grade", "ygg deps bump", "`grade` node", "--canary", "--task", "grade_refused", "score.json", "ygg.grader",
		"REPOS.md", ".ygg/impact.json", "shrink guard", "pointer-contract", "routing_index_built", "pointer_contract_checked", "deps_bump", "memory: none"} {
		if !strings.Contains(string(arch), want) {
			t.Errorf("docs/architecture.md does not mention %q", want)
		}
	}
}
```

Create `sandbox/docs_test.go`:

```go
package sandbox

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The architecture page says what Grade does and the guarantees it keeps. A change that drops a word here
// has to change the page too.
func TestTheArchitecturePageDescribesGrade(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("..", "docs", "architecture.md"))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"`Grade`", "`BuildGrader`", "/app", "/tests", "/logs/verifier", "ygg.grader", "`GraderLeftovers`", "`RemoveGrader`", "no network"} {
		if !strings.Contains(string(b), want) {
			t.Errorf("docs/architecture.md does not mention %q", want)
		}
	}
}
```

Create `docs_test.go`:

```go
package gungnir

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// The architecture page names the contract of the grader, routing and dependency work: every event it added,
// the node, the factory block, the two files, and the pack block. A new event of these kinds with no line in
// the page fails here.
func TestTheArchitecturePageNamesTheGraderContract(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("docs", "architecture.md"))
	if err != nil {
		t.Fatal(err)
	}
	page := string(b)
	for _, e := range []EventName{EventGradeStarted, EventGradeFinished, EventGradeRefused, EventRoutingIndexBuilt,
		EventPointerContractChecked, EventDepsChecked, EventDepsBump} {
		if !strings.Contains(page, string(e)) {
			t.Errorf("docs/architecture.md does not name the event %s", e)
		}
	}
	for _, want := range []string{"`grade` node", "`grader:`", "score.json", "ygg.score/v1", "manifest.json", "ygg.suite/v1", "`routing` block", "pointer-contract", "memory: none"} {
		if !strings.Contains(page, want) {
			t.Errorf("docs/architecture.md does not mention %q", want)
		}
	}
}
```

Expect each test to fail with `does not mention ...` (or `does not show ...`).

- [ ] **Step 2:** write the docs.

Apply to `odin`:

````diff
diff --git a/README.md b/README.md
index 64c3601..bc284b4 100644
--- a/README.md
+++ b/README.md
@@ -21,10 +21,14 @@ ygg resume  <run-id> [--project <dir>] [--mode <mode>]
 ygg approve <run-id> <gate> [--note <text>] [--project <dir>] [--mode <mode>]
 ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
 ygg status  <run-id> [--project <dir>]
+ygg grade   <run-id> [--task <id>] [--project <dir>]
+ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]... [--project <dir>] [--config <factory.yaml>]
 ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
+ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
 ```
 
-Exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point.
+Exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point, 4 paused (the provider's quota is
+used up), 5 done with tasks given up (unattended).
 
 `factory.yaml` must set both budget caps, `per_run` and `per_day`, each with `tokens` and `turns`.
 The factory ships no defaults, so a config without them runs nothing.
diff --git a/docs/architecture.md b/docs/architecture.md
index adfb5f1..4555f04 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -13,7 +13,7 @@ The orchestrator: the graph engine and the `ygg` CLI, with routing and the ledge
 ## Responsibilities
 
 - Loads realm graphs and `factory.yaml`.
-- Walks the graph and runs exec, agent, loop and gate nodes; checkpoints runs and resumes them. A
+- Walks the graph and runs exec, agent, loop, gate and grade nodes; checkpoints runs and resumes them. A
   loop node is Jormungandr's loop with Odin's steps: sessions, checks, ledger lines and `run.json`.
 - Loads realm leaves (change realm-leaf-naming): `--realm` names the lead realm, found in the realm
   store of `factory.yaml` or given as a path; each leaf runs with the realm the project pins for it;
@@ -43,6 +43,35 @@ The orchestrator: the graph engine and the `ygg` CLI, with routing and the ledge
 - Counts every session's usage, a failed one's too, in the run and in a daily spend journal outside
   any project, and stops the run at the hard approval point `budget-cap` before a session would start
   over a cap (spec §7.4). Pauses the run when the provider's quota is used up (spec §12).
+- Grades a build (spec §11, change benchmark-split). The `grade` node is the last node of a graph. It stops
+  every sandbox, exports the committed files of the project as `/app`, and runs the hidden suite of the
+  task in a container of Gleipnir's `Grade`: no network, `/app` read and write, `/tests` read only, one empty
+  folder for the results, and no other mount. It checks the task first (`internal/task`: `task.toml`, the
+  hash of `instruction.md`, the suite version, the retired mark) and refuses with `grade_refused` and a
+  reason, before it builds anything. It joins `manifest.json` and the suite's `results.json`
+  (`internal/score`) and writes `score.json` to the run folder and nowhere else. Fail-to-pass scenarios
+  decide the reward, by category and weight. Pass-to-pass scenarios are reported and never change it. An
+  agent never sees the suite folder, `score.json` or the container's output. `ygg grade <run-id>` grades a
+  finished run that has no grade node, or grades again; `--task` names the task when the brief is not a
+  task's `instruction.md`. `grader.memory: none` and `grader.cpus: 0` ask for no limit, for an engine that
+  cannot apply one; `ygg doctor` warns when they are set. `ygg doctor` also lists and removes grader
+  containers a killed `ygg` left (label `ygg.grader`).
+- Builds the routing indexes (spec §8) when a pointer node moves in the project umbrella, with no model call:
+  the wiring index (the block of `REPOS.md` between `<!-- ygg:wiring:begin -->` and `<!-- ygg:wiring:end -->`)
+  and the impact index (`.ygg/impact.json`). Every edge is `extracted` (read from a manifest, an import, an
+  OpenAPI file or a lock file) or `inferred` (a guess). The shrink guard refuses a generated file that keeps
+  fewer than half of the rows of its last version. A pack's `routing: {threshold, bench}` block makes an
+  index ship only when it answers at least `threshold` of the project's bench questions right first
+  (`.ygg/routing-bench.yaml` by default); a pack with no block ships its indexes unmeasured. Each build
+  writes `routing_index_built`.
+- Judges a pointer move that changes a contract (the `pointer-contract` gate). A change is judged by
+  `extracted` edges or by `oasdiff`. A guess alone never passes: the verdict is `escalate`, and a person
+  decides in every mode. The ledger line is `pointer_contract_checked`.
+- Bumps a dependency with `ygg deps bump <package> <version> --canary <leaf> [--rollout <leaf>]...`. The
+  canary product takes the bump first and runs its `deps` and `unit` checks. If they fail, Odin puts every
+  file back, touches no rollout product, and writes `deps_bump` with `stage: canary` and `verdict: fail`.
+  A bump has its own folder and ledger under `.factory/deps/`, takes the project's runs lock, and leaves
+  the change uncommitted in the working copies.
 - Walks the instance tree and moves pointers. It is the only writer of umbrellas, `features.json`,
   the ledger, gate files and reports (spec §3.3).
 - Does every git operation, from the host (spec §6.3).
````

Apply to `gleipnir`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 3853b31..1354489 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -29,6 +29,15 @@ The harness: agent adapters, the devcontainer sandbox driver, policies and the c
   from images pinned by digest and the Containerfile's own stages, with the isolated registry auth, and
   tagged with a hash of the context. The check scripts a realm bakes into its stack are read-only for the
   agent. A service may take the command its pack gives it, for an image that does nothing without one.
+- Grades a build (`Grade`, spec §11): builds the image of a benchmark task from its `environment/` folder
+  (`BuildGrader`, with the rules of `BuildStack`, and a tag that is a hash of the folder), then runs
+  `bash /tests/test.sh` in one container of that image. The container has no network but loopback and three
+  mounts: `/app` (the project, read and write), `/tests` (the suite, read only) and `/logs/verifier` (an empty
+  folder for the results). It has the label `ygg.grader=<run id>`, and it is always removed, after a pass, a
+  failure, a timeout and a cancel. `Grade` refuses a path it could not mount safely before it runs
+  anything, and a `podman run` that exits 125, 126 or 127 is an error, not a result. An empty memory limit and
+  zero CPUs mean no limit, for an engine that cannot apply one. `Grade` reads no result: the score is
+  Odin's. `GraderLeftovers` finds a container a killed run left, by its label, and `RemoveGrader` removes it.
 - Runs checks.
 
 ## Depends on
```

Apply to `gungnir`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index cedd2c0..182e4da 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -34,6 +34,19 @@ The contract: Go interface types and JSON schemas for ledger events, `graph.yaml
   A realm may name a second stack for the acceptance checks that run on a snapshot of the whole project.
 - Defines the design-conformance review (spec §4.2): a scratch reviewer (`reviews`) reads another scratch
   agent's output, its verdict (`Conformance`) is read exactly, and the spec gate reads it (`deviation_from`).
+- Defines the grader's contract (spec §11): the `grade` node, which is the last node of a graph and has no
+  other field; the `grader:` block of `factory.yaml` (`tasks_dir`, `suite_dir`, `timeout`, `memory`,
+  `cpus`: all five are set, none has a default, the two folders are separate and `memory: none` with
+  `cpus: 0` is the written choice of no limit); `score.json` (`ygg.score/v1`: the reward, the fail-to-pass
+  and pass-to-pass tallies, the categories and their weights) and a suite's `manifest.json`
+  (`ygg.suite/v1`). A score that does not add up and a manifest that can be read two ways are refused.
+- Defines the ledger events of grading (`grade_started`, `grade_finished`, `grade_refused`), of routing
+  (`routing_index_built`, `pointer_contract_checked`) and of dependency checks (`deps_checked`,
+  `deps_bump`). A reward of 0 is still written. A refusal has one reason: `retired`, `missing_suite`,
+  `brief_changed`, `bad_manifest` or `bad_task`.
+- Defines the `routing` block of a lead realm's `pack.yaml` (`threshold`, and `bench`, the bench file from
+  the project root): the share of bench questions an index must answer right first before it ships. The
+  hard approval point `pointer-contract` is in the schema of the gates.
 - Validates configs against those schemas.
 - Takes every interface change first: one PR here, plus one in each affected component (spec §1).
 
```

- [ ] **Step 3:** run the three named tests. Expect `ok` for each. Run `go test -race -count=1 ./...` in the three repos.

- [ ] **Step 4:** commit in the three repos (see "How each task lands"), by path:

```zsh
git -C odin add README.md docs/architecture.md internal/cli/docs_test.go
git -C odin commit -m "Docs: grade, deps bump, routing, the grade node and its flags (v0-T264)"
git -C gleipnir add docs/architecture.md sandbox/docs_test.go
git -C gleipnir commit -m "Docs: Grade, BuildGrader and the grader's leftovers (v0-T264)"
git -C gungnir add docs/architecture.md docs_test.go
git -C gungnir commit -m "Docs: the grader contract, the grade events and the routing block (v0-T264)"
```

**Evidence (v0-T264):** built in the reference workspace on 2026-10-18. Commits: `odin` `b7ee9a5`, `gleipnir` `0e17275` (branch `grader/docs`), `gungnir` `8063fcf`. None is pushed. The three tests pass; `go test -race -count=1 ./...` passes in `gleipnir` (the `sandbox` package takes 14 s), in `gungnir` and in `odin`; `gofmt -l` and `go vet ./...` print nothing. Mutations, each undone: removing the word `ygg.grader` from the page of `odin` failed `TestTheDocsNameEveryCommand`; replacing the text `deps_bump` in the page of `gungnir` failed its test with `does not name the event deps_bump`. The test of `gleipnir` was not mutated. Not run: `reuse lint` (not installed). The docs describe the code of the reference branches. They are true only after v0-T245 to v0-T263 are merged.

### Task v0-T265: pointers and the exit check

The umbrella moves the pointers once, and the exit check runs on the merged code.

**Files (in `yggdrasil`):**

- Modify: the submodule pointers of `gungnir`, `gleipnir`, `helheim-go`, `midgard-react` and `odin`;
  `docs/2-engineering/backlog.md`.

**Acceptance criteria:**

- [ ] After all pull requests are merged, the pointers are at each repo's `main`, and `go.work` builds them
      together: `go vet ./...` and `go test ./...` pass in each repo with `go.work` and with `GOWORK=off`.
- [ ] The exit criterion: `go test -run 'TestGraderCombinesPublicTaskAndHiddenSuite|TestGraderRefusesRetiredVersion|TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents' ./...`
      in `odin` passes on the merged code, in the umbrella, where the two realms are beside `odin` (it must not
      skip); and v0-H16 happened (the grader smoke on a real engine). The output is in the pull request.
- [ ] The real-agent smoke (v0-H17) is ready: the dry run passes. Whether the real run happened is said in the
      pull request; its result is the first finding of Phase 6.
- [ ] The backlog gets these items, each **Open**, with the problem and the fix in a line:
      `Advance` has no default case, so a node kind it does not know passes silently; `gate.Decide` returns
      `Block` for a contract change in unattended mode and `reachGate` stops the run; `.factory/runs/` is
      untracked but not ignored in a project (the umbrella template should ignore it); `ygg doctor` and
      `ygg status` do not list `.factory/deps/` or leftover bump sandboxes; the indexes are built from the
      leaves' working copies, not from their pointers; `ygg routing build|bench` does not exist; the first
      routing bench of a project has no author; `/app` of the grader needs a `start.sh` that a real project
      does not yet provide; the real version floors of the two policy files; a per-agent token cap; `oasdiff`
      is not proven against 1.33.0 on the host; `govulncheck` and `osv-scanner` were not run for the policy
      rungs (stubs only); the realm folder is hashed into a run, so editing a realm mid-run breaks `ygg grade`.
      B-047 stays open and gets a note that the real run is the place to watch it. B-051 keeps its next steps.
- [ ] The backlog marks the 5b notes that 5c closed: rung 7, the two-tenant harness, routing indexes, the
      `pointer-contract` gate and the dependency policy, each with the task that built it.

**Named test:** `go test ./...` in each repo, and the evidence of v0-H16. **Layer:** `yggdrasil`.
**Size:** S. **Depends on:** all above, merged.

- [ ] **Step 1:** switch each local copy to `main` and pull. Then, in `yggdrasil`:

```bash
git switch -c phase-5c/pointers
git submodule update --remote gungnir gleipnir helheim-go midgard-react odin
git status --short
```

- [ ] **Step 2:** in `docs/2-engineering/backlog.md`, add the items above.
- [ ] **Step 3:** run the exit check: `go vet ./... && go test ./...` in each of the five repos, with `go.work`
      and with `GOWORK=off`, and paste the output and v0-H16's result into the PR body.
- [ ] **Step 4:** stage the pointers and the backlog by path, commit, push and open the pull request (see "How
      each task lands").

---

### Task v0-H16 (founder): the grader smoke on the merged code

The smoke of v0-T262 ran in the reference workspace with the code on the reference branches. This step repeats it on the merged code, on your machine. **Do this after v0-T262 and the tasks it needs are merged and the engine is up (Phase 3's v0-H07).** It costs nothing: the agents are scripted. The first run pulls and builds the Playwright image (a few minutes).

**Named test:** the script ends with `smoke-grade: every check passed` and exit code 0. **Layer:** the founder's machine. **Size:** S. **Depends on:** v0-T262 merged.

- [ ] **Step 1:** switch `odin`, `gungnir`, `gleipnir`, `mimir` and `ouroboric` to `main` and pull. `~/ygg-it/factory.yaml` must name the engine (`sandbox.engine`), as for v0-H14.
- [ ] **Step 2:** run it.

```zsh
cd ~/yggdrasil/ouroboric
scripts/ygg-smoke-grade.sh --build --clip
```

Expect, for the cases `reference` and `empty`: `PASS` on every line, `reward: 1.0000` with `fail-to-pass: 6/6` for the reference and `0.0000` for the empty product, and the last line `smoke-grade: every check passed`. A `NOTE` line about the watch missing the grader container is normal.

- [ ] **Step 3:** if your engine applies cgroup limits, run it again with `--limits` (4 GB and 4 CPUs). Then the grader container runs with limits. Send the output of both runs. If a line says `FAIL`, send the folder it prints (`~/ygg-it/smoke-grade-<time>`): it holds `run.txt`, `grade.txt`, `doctor.txt` and `mounts.log` of each case.

### Task v0-H17 (founder): the real-agent smoke

One real run of `smoke-notes` with Claude Code and OpenCode on OpenRouter, graded by the public sample suite. **It costs money.** The caps are in `odin/testdata/smoke-grade/factory.real.example.yaml`: 3 dollars for the run, 6 for the day. Read them first. **Do this after v0-H16 passed and v0-T263 is merged.** Your credentials file is `~/.config/ouroboric/factory.env`. It needs the two names `CLAUDE_CODE_OAUTH_TOKEN` and `OPENROUTER_API_KEY`.

**Named test:** the run ends `done` (exit code 0), the score is printed, and the cost is under the cap. **Layer:** the founder's machine. **Size:** S. **Depends on:** v0-H16.

- [ ] **Step 1:** the dry run. It spends nothing. It checks the file for the two names, builds the config, runs `ygg doctor` on it and prints the caps and the command.

```zsh
cd ~/yggdrasil/ouroboric
scripts/ygg-smoke-real.sh --dry-run
```

Expect `smoke-real: dry run: nothing was started and the credentials were not loaded` and exit code 0. Check the two cap lines.

- [ ] **Step 2:** the real run. It stops after 90 minutes at most (`--wall`).

```zsh
scripts/ygg-smoke-real.sh --build --clip
```

Expect an exit code of 0 (done), 5 (done, tasks given up), 3 (stopped at a gate), 4 (paused: the quota) or 124 (the wall clock). The script prints the evidence report (the credentials are removed from it), the line `smoke-real: score smoke-notes 1.0.0: reward ...`, and `ygg-cost: cost $...` with `the per_run cap is $3`.

- [ ] **Step 3:** send back the report and the three last lines. The reward may be below 1: that is a finding about the agents and the brief, not a failure of the script. If `smoke-real: no score.json` shows, the run did not reach the grade node: send the report anyway.

---

## Evidence

What was run while this plan was written, on 2026-10-18, on this machine (WSL2 on Linux 6.18, Go 1.26.4; rootless
Podman 5.7.1 at first and 5.8.3 after an update, so the tasks name one or the other; devcontainer CLI 0.89.0 and
Node 26.3.0 for the real-engine and web runs).

**Tests.** In the reference workspace (the repos built together through a `go.work`, one commit per task), `gofmt -l .`
prints nothing and `go vet ./...` is clean in `gungnir`, `gleipnir`, `odin`, `helheim-go` and `midgard-react`; `go test
-race -count=1 ./...` passes in `gungnir`, `gleipnir` and `odin` (the slowest: `odin/internal/engine` about 110 s,
`internal/cli` about 48 s), and `go test -count=1 ./...` passes in `helheim-go` (about 32 s, with the real `git`,
`golangci-lint` and `sqlc`) and `midgard-react` (about 78 s, with the real `node` and `npm`, including `npm ci` and `npm
audit --audit-level=high`). `mimir` has no Go: `bash scripts/check-task.test.sh` (13 cases, `ok`) and `scripts/check-task.sh`
on `smoke-notes` and `client-gallery-lite`. `ouroboric`: `bash scripts/tests/ygg-smoke-grade.test.sh` (61 `ok`, no `FAIL`)
and `shellcheck -s bash` clean on every new script. The tests that need the network (`npm ci`, `go mod download` for
`ygg-authz`) ran with it; without it they skip, unless `YGG_REQUIRE_TEMPLATES` is set. The tests were run through
`go.work`, so the siblings did not have to be merged.

**On a real engine** (rootless Podman, the devcontainer CLI):

- The grader smoke of v0-T262 (`ygg-smoke-grade.sh --build`): `ygg run` with scripted agents and the PUBLIC sample suite
  of `smoke-notes`, on the pinned Playwright 1.63.0 image. The reference solution graded 1.0000 (6 of 6 fail-to-pass,
  1 of 1 pass-to-pass), twice (the grade node, then `ygg grade`); the empty product graded 0.0000. After each run no
  grader container was left, `ygg doctor` found none, no agent container held the suite folder and `score.json` was in
  the run folder only.
- The sandbox-tag tests of v0-T246 (`go test -tags sandbox -run TestSandboxGrade ./sandbox`): the grader container has
  loopback only and cannot reach `1.1.1.1:443`, `/app` is writable and the write reaches the host copy, `/tests` is
  read only, `/logs/verifier` receives `results.json`, the mounts are the three and the engine's own, a running grader
  carries the label, and a timeout ends and removes it. They ran WITHOUT memory and CPU limits (see the findings).
- The sample suite image of v0-T261: `podman build` of the `environment/` of `smoke-notes` on the pinned Playwright
  base; the sample suite ran in the image with `--network=none`: 7 of 7 failed on an empty `/app`, 7 of 7 passed on
  the reference solution, and 6 of 7 passed with an owner check removed (the failing one was the cross-tenant scenario).
- The `deps` rung hand runs of v0-T257 and v0-T258 used the real `go` and the real `npm`, and the authz rung of v0-T260
  was built into an image and run on a derived image holding a leaf (it failed with the `missing` output, then passed
  once the test was added).

**Each first failure and each task.** The tests-first runs are shown in the steps: the failure is the build failure or
the test failure the step prints.

**The plan reproduces the code.** A checker (`python3 -I`) applied every file shown whole and every `diff` of this plan,
task by task, to fresh clones of the six repos with code (`gungnir`, `gleipnir`, `odin`, `helheim-go`, `midgard-react`,
`mimir`) and of `ouroboric`, each at its `main` before Phase 5c. The resulting trees are identical to the reference
workspace's, apart from lock files (`go.sum`, `package-lock.json`), file modes and the two files that the plan makes by
a command and not by a block: `odin/testdata/routing/impact.golden.json` (written by the `-update` step of v0-T252, and
the checker ran that step) and `odin/testdata/smoke-grade/templates/notes/LICENSE` (a copy, step of v0-T262). Not
covered by the checker: the bash steps (`git mv`, `chmod`, `go mod tidy`, commits), v0-T265 (pointers of `yggdrasil`),
and whether each command's output matches the `output` blocks.

**What the real runs found** (already fixed or documented in the tasks above):

- Rootless Podman here has no cgroup delegation: with `--memory` or `--cpus` every grade run failed with exit 127
  (`crun: open memory.max for writing`). Hence `grader.memory: none` and `cpus: 0` (decision 9, v0-T262).
- The host's own Podman config uses a Google Cloud credential helper (`gcloud`) that failed on a pull; the driver's
  pulls use an isolated, empty auth and worked (v0-T246).
- The engine of v0-T261 is remote and cannot bind-mount this machine's folders, so the `/app`, `/tests` and
  `/logs/verifier` mount layout was checked in v0-T262 and the sandbox-tag tests with the bind-mount folder, while the
  image run of v0-T261 used `create` and `cp`, which put the same files in the same places.
- The grader's `/app` is the project, with the leaf in `repos/<leaf>`, while the suite starts `/app/start.sh`: the
  smoke commits a shim `start.sh` in the umbrella. How a real project provides it is open (question 5; backlog).
- Also found while running: the stack image must exist before the smoke (`--build`); `ygg grade` refuses a realm that
  changed since the run began (decision 4 of v0-T262).

**Not run:**

- `govulncheck` and `osv-scanner` (not installed): the `deps` rung, the `go-security.sh` and the template tests use
  stand-ins on `PATH` that log their call; the calls are the ones the existing security rungs already make.
- `oasdiff` 1.33.0 on the host (not installed): the pointer-contract tests use a stand-in script; the real binary is
  in the image of the realms, not here.
- A real `npm` bump (`ygg deps bump` on a web product): the bump tests use the real `go` and a stand-in `npm`
  (decision 11 of v0-T259).
- `reuse lint` where `reuse` was not installed (v0-T262 to v0-T264 in `odin`, `gleipnir` and `ouroboric`); the executor runs
  `uvx --from 'reuse==5.0.2' reuse lint -q` as every task says. Also `gitleaks`.
- `GOWORK=off go test` before the pins exist: v0-T245 to v0-T262 build only through `go.work` until the merged pins
  are fetched (see "How each task lands").
- The `--limits` flag of the grader smoke on a real engine (this engine cannot apply limits), the Dockerfile of
  `client-gallery-lite`, and any hidden suite (none was read).
- v0-H17: real agents (Claude Code and OpenCode on OpenRouter) have not run. The script ran with `--dry-run` and with
  fake tools only.

---

## The defences each fail when removed

For each row, the defence was removed from the reference code, the named test was run, and it failed; then the code
was restored (every clone was clean afterwards). `scripts/plan-defences.py` did the 37 Go rows, from `defences.json`;
the 8 rows of shell scripts (v0-T261 to v0-T263, marked `.test.sh`) were done by the same method with a small helper,
`shrun.py`, from `defences-sh.json`, because `plan-defences.py` runs `go test` only (see "For the executor" below).
Both row files and `shrun.py` are kept beside the draft parts in the SDD folder of the reference workspace. Sixteen
candidate rows did not pass at first. Nine showed tests that claimed more than they checked, and the tests were
strengthened; the plan text of v0-T246, v0-T247, v0-T248, v0-T249, v0-T250, v0-T254, v0-T260 and v0-T261 already
holds the strengthened tests, so executing the plan gives them. Seven named a line that another check covers (two
layers on purpose) or were a mutation that cannot be seen from outside, and those rows were dropped or changed.

| Task | Defence removed | Test that fails |
| --- | --- | --- |
| v0-T245 | a grade node that is not the last node of the graph is refused | `TestAGradeNodeThatCouldRunBesideASandboxIsRefused` |
| v0-T245 | a suite store inside the tasks folder (or the reverse) is refused | `TestTheGraderBlockIsRefusedWhenItIsNotExact` |
| v0-T246 | the grader container has no network | `TestGradeBuildsTheImageThenRunsTheSuiteWithoutANetworkAndRemovesTheContainer` |
| v0-T246 | the hidden suite is mounted read only | `TestGradeNeverMountsAnythingButTheThreePaths` |
| v0-T246 | Grade never mounts more than three paths | `TestGradeNeverMountsAnythingButTheThreePaths` |
| v0-T246 | the grader container is always removed | `TestGradeAlwaysRemovesTheContainer` |
| v0-T246 | an environment holding a symlink is refused | `TestGraderImageIsNamedForEveryFileOfTheEnvironmentAndRefusesWhatCouldLeadOutside` |
| v0-T247 | a retired suite is refused | `TestGraderRefusesRetiredVersion` |
| v0-T247 | a brief that no longer hashes to the task's brief_sha256 is refused | `TestAChangedBriefIsRefused` |
| v0-T247 | a suite with no test.sh is refused | `TestAMissingSuiteIsRefused` |
| v0-T247 | a manifest with a second document is refused | `TestAManifestThatCannotBeReadExactlyIsRefused` |
| v0-T248 | a scenario in one side only is an error | `TestAScenarioOnOneSideOnlyIsAnErrorNeverAPass` |
| v0-T248 | score.json is written to an absolute run folder only | `TestWriteRefusesARunFolderThatIsNotAbsoluteAndWritesNothing` |
| v0-T248 | a status Odin does not know is not a pass | `TestReadResultsReadsNestedSuitesAndTheLastTryOfEachTest` |
| v0-T249 | a run built from another brief than the task's is not graded | `TestARunBuiltFromAnotherBriefThanTheTasksIsRefused` |
| v0-T249 | score.json is never inside a leaf or the grader's /app | `TestScoreJSONIsInNoLeafAndNoTree` |
| v0-T249 | the hidden suite path is never mounted in an agent sandbox | `TestNoAgentSandboxOrCommandEverHoldsTheSuiteFolder` |
| v0-T249 | grading starts only after every sandbox has stopped | `TestGradingStartsOnlyAfterEverySandboxHasStopped` |
| v0-T249 | a suite that writes no results is a failure, not a pass | `TestASuiteThatWritesNoResultsIsAFailureNotAPass` |
| v0-T250 | ygg grade refuses a run that is not done | `TestGradeNeedsADoneRunAndTheGraderSection` |
| v0-T250 | doctor never removes the grader container of a run a live ygg holds | `TestDoctorLeavesTheGraderContainerOfARunAliveYggHoldsAlone` |
| v0-T253 | the shrink guard refuses a lost index | `TestGuardRefusesAnImpactIndexThatLostEdges` |
| v0-T254 | an inferred-only edge never passes pointer-contract | `TestAnInferredOnlyEdgeNeverGivesPass` |
| v0-T254 | oasdiff runs with PATH only in its environment | `TestOasdiffCLIAsksChangelogAndBreaking` |
| v0-T254 | a guess alone stops the pointer-contract gate in every mode | `TestPointerContractFollowsTheJudgement` |
| v0-T255 | an index under the bench threshold does not ship | `TestAnIndexUnderTheThresholdDoesNotShip` |
| v0-T256 | the pointer-contract gate comes right before the pointer move | `TestTheContractGateComesBeforeTheMoveAndTheMoveShipsTheRoutingIndexes` |
| v0-T257 | the policy file is read from beside the script, never the leaf | `TestDepsListsEveryProblemAndNeverReadsAPolicyOfTheLeaf` |
| v0-T258 | a dependency that is not pinned to a minor line is refused | `TestDepsRefusesWhatIsNotPinnedToAMinorLineAndWhatIsBelowTheMinimum` |
| v0-T258 | npm ci runs no install script in the deps rung | `TestDepsPassesACleanLeafAndRunsTheAuditsThePolicyNames` |
| v0-T259 | a canary failure stops the rollout | `TestACanaryThatFailsIsPutBackByteForByteAndNoRolloutProductIsTouched` |
| v0-T259 | a failed product is restored byte for byte | `TestACanaryThatFailsIsPutBackByteForByteAndNoRolloutProductIsTouched` |
| v0-T259 | a bump that changes a file other than the manifest and its lock fails | `TestAToolThatChangesAPolicyFileFailsTheProductAndTheFileIsPutBack` |
| v0-T260 | a route with an id and no cross-tenant test fails | `TestAuthzFailsWhenARouteWithAResourceIdHasNoTest` |
| v0-T260 | a route where user B gets anything but 403 or 404 fails | `TestAuthzDoesNotTrustALeafTestThatReportsWhatItLikes` |
| v0-T260 | a cross-tenant test where user A does not get the resource fails | `TestAuthzDoesNotTrustALeafTestThatReportsWhatItLikes` |
| v0-T260 | a test with the right name that never asks as user B fails | `TestAuthzFailsOnATestThatNamesTheRightNameAndChecksNothing` |
| v0-T261 | a manifest of another suite than the task names fails the check | `check-task.test.sh`: a manifest of another suite than the task names |
| v0-T261 | a manifest with no fail-to-pass scenario fails the check | `check-task.test.sh`: a manifest with no fail-to-pass scenario |
| v0-T262 | the smoke fails when a score.json is anywhere but the run folder | `ygg-smoke-grade.test.sh`: a score.json outside the run folder fails the smoke |
| v0-T262 | the smoke fails when a grader container is left behind | `ygg-smoke-grade.test.sh`: a grader container left behind fails the smoke |
| v0-T262 | the smoke fails when an agent container held the suite folder | `ygg-smoke-grade.test.sh`: an agent container that holds the suite folder fails the smoke |
| v0-T263 | the real smoke refuses a credentials file with a name missing | `ygg-smoke-grade.test.sh`: a credentials file with one name missing is refused |
| v0-T263 | a config that doctor refuses stops the real smoke before any money is spent | `ygg-smoke-grade.test.sh`: a config that doctor refuses stops the script before the run |
| v0-T263 | factory.env is never read by the smoke script | `ygg-smoke-grade.test.sh`: the credentials file is not read by cat, head, tail, sed or awk |

Notes on running it: the T256 row needs midgard-react on the branch `routing/pointer-contract` (on `main` of that clone
the gate is not in the graph yet) and the workspace with gungnir at its branch `grader/limits-docs`. The reference
workspace is `go.work` of the REF folder: gleipnir on `grader/docs`, gungnir on `grader/limits-docs`, odin on
`grader/odin`, helheim-go and midgard-react on `main`.

**Rows that did not pass at first.**

Tests that were weak. They are fixed in the code of this plan (the test in the task is the strengthened one):

| Task | Defence | What was wrong | Fix |
| --- | --- | --- | --- |
| v0-T246 | an environment holding a symlink is refused; a changed file is a new image tag | no test of `GraderImage` beyond the tag format: a symlink in the task's environment was never offered, and no file change was checked against the tag | new test `TestGraderImageIsNamedForEveryFileOfTheEnvironmentAndRefusesWhatCouldLeadOutside` (gleipnir) |
| v0-T247 | a manifest with a second document is refused | no such case in `TestAManifestThatCannotBeReadExactlyIsRefused` | case `a second document` |
| v0-T248 | score.json is written to an absolute run folder only | `Write` was tested with an absolute folder only | new test `TestWriteRefusesARunFolderThatIsNotAbsoluteAndWritesNothing` |
| v0-T249 | a suite that writes no results is a failure | the test accepted any message with the word `results`, and a mismatch refusal says it too | the message must say `wrote no results` |
| v0-T250 | ygg grade refuses a run that is not done | the stopped run of the test had no grader section, so it was refused for that reason; the status check was never the deciding one | the test sets a run of a graded config to `stopped` in run.json and expects the refusal |
| v0-T250 | doctor leaves the grader container of a live run alone | no test held a run's lock | new test `TestDoctorLeavesTheGraderContainerOfARunAliveYggHoldsAlone` |
| v0-T254 | oasdiff runs with PATH only | the stand-in oasdiff never looked at its environment | the stand-in exits 9 when a variable of Odin's reaches it |
| v0-T260 | user B must get 403 or 404 and user A 2xx, judged by `ygg-authz` | the leaf tests of the suite all call `authztest.Check`, which fails on the same conditions, so the checker's own judgement was never needed | new test `TestAuthzDoesNotTrustALeafTestThatReportsWhatItLikes`: a forged `YGG-AUTHZ` line from a test that skips `Check` |
| v0-T261 | a manifest of another suite, or with no fail-to-pass scenario, fails the task check | no such cases in `check-task.test.sh` | two cases |

Rows changed or dropped because another check covers the same line (the defence is real, but two layers hold it, so
removing one layer alone cannot fail a test; the plan text should say "two layers" where it describes them):

| Task | Candidate | Why it cannot fail alone |
| --- | --- | --- |
| v0-T245 | grader.timeout above zero in `Grader.check` | the JSON schema of the factory refuses it first; the row was dropped |
| v0-T247 | the tests folder of a suite must exist | the `test.sh` check right after it refuses the same case with the same reason (`missing_suite`); the row names the `test.sh` check |
| v0-T251 | wiring never follows a symlink / never reads a file over the limit | the walker skips links and `read` skips them again, and a size check sits in two places; dropped |
| v0-T254 | the engine hands `Escalate` and `NoContractChange` to the gate | `Escalate` is read before `NoContractChange` and `Block` and `Stop` both stop a run (equal at the engine); equivalent mutants, dropped |
| v0-T257 | a caret range or a pseudo-version is refused by the manifest reader | `ParseVersion` refuses the same text first; dropped |
| v0-T260 | a registry entry for a route that is not there | `!resource` refuses the same entry (a missing route has resource false); dropped |
| v0-T257/T260 | the tools come from root-owned folders; the module cache is verified in `go-deps.sh` | only the authz rung has a test for the cache; the deps rung's cache check and its PATH have none (not a fixup: the same lines are in the other rungs and are tested there); dropped |

Defences the rows above do not test and that no test pins (not added; listed so the plan can decide): more than 64
changed contract files escalates (`maxContractChanges`, v0-T254); a host command in `ygg deps bump` takes no
environment (`hostExec`); a cancelled bump stops its sandbox with a context that is not cancelled (the fake ignores
the context); only the project umbrella ships the routing indexes (`parent.Dir != r.Project`, v0-T253).

**For the executor.**

- `plan-defences.py` runs `go test` only. The 8 shell rows need a `"cmd"` key in a row (a shell command run in the repo
  instead of `go test`; a row passes when it exits non-zero and prints a `FAIL` or `not ok` line). Until `plan-defences.py`
  takes `cmd`, they run with `shrun.py`. **Follow-up task (not part of 5c):** `shrun.py` is a reusable tool, so it moves
  into `ouroboric/scripts/` (as `cmd` support in `plan-defences.py`, or as its own script) with a test and a pull
  request; a reusable script never stays in the scratchpad (rule 13 of the invariants). Until then v0-T265 files it as a
  backlog item.
- The v0-T260 rows need `YGG_REQUIRE_TEMPLATES` set in the environment: the test needs `go` and a module cache for
  `ygg-authz`, and it skips without the module proxy unless the variable is set. Without it the rows pass when skipped.
- The v0-T256 row needs `midgard-react` on its branch `routing/pointer-contract` (on `main` of that clone the gate is
  not in the graph yet) and the workspace with `gungnir` at `grader/limits-docs`.

---

## Notes from the drafts

The flags and decisions of the drafts of this plan, kept as written so that none is lost. Where a number differs from
the "Decisions for this phase" above, the decision above wins; the notes say what the drafter saw. Each draft's own
heading is below as a third-level heading. The parts of v0-T245 and v0-T246 (part A), v0-T251 to v0-T256 and the
later tasks keep their flags in the tasks themselves, except those of parts B, C and D, which are here.

### Phase 5c, part B: the grader in Odin (v0-T247 to v0-T250)

Drafted and run in the reference workspace on 2026-10-18, branch `grader/odin` of `odin`, on top of `main`
(`6829cfb`). It uses the types of v0-T245 (`gungnir`, commit `74d6c89`) and the driver of v0-T246 (`gleipnir`, commit
`3766b48`) through `yggdrasil/go.work`. The event names are the snake_case ones of the code (`grade_started`, not
`grade.started`). Nine commits, four tasks: three tasks are split in parts so that no commit is over about 410
inserted lines (see "Sizes").

#### Decisions and flags for this part

Each line is for the founder to confirm when the plan is merged.

1. **TOML parser: `github.com/BurntSushi/toml` v1.6.0.** It was not in any `go.sum` of the factory. v1.6.0 is from
   2025-12-18, so it is far older than the two weeks Phase 3 asks of a pin. It has no dependencies. v0-T247 adds it.
2. **Reward counts fail-to-pass only; pass-to-pass is reported on its own** (the contract). Please confirm. The
   effect: a product that breaks a pass-to-pass scenario shows it in `pass_to_pass` and keeps its reward.
3. **The task to grade comes from the brief.** The run's brief must be `<grader.tasks_dir>/<id>/instruction.md`; Odin
   reads `<id>` from the path. `ygg grade --task <id>` names it for a run whose brief is elsewhere. In both cases the
   run's own brief hash must equal the task's `brief_sha256`, else the grade is refused (`brief_changed`): a run built
   from another text than the frozen brief gets no score.
4. **`bad_manifest` has two moments.** A manifest that can't be read exactly is refused before anything is built. A
   report whose specs and the manifest disagree can only be seen after the container ran: Odin then logs
   `grade_refused` with `bad_manifest`, writes no `score.json`, and stops the run failed. The contract said "nothing
   built" for all five reasons; this one can't hold for the second moment.
5. **A refusal stops the run failed, not refused.** A refused grade is a node failure: `ygg resume <id>` grades again
   once the cause is fixed (a restored suite, a task version). `ygg grade` exits 2 on a refusal and builds nothing.
6. **The smaller timeout wins.** The container gets the smaller of `grader.timeout` and the task's
   `verifier.timeout_sec`.
7. **A spec that passed in one project and was skipped in another counts as skipped,** and a test is as good as its
   last try (a retry that passes is a pass). Both are the careful reading; flag them if the suite's `playwright.config.ts`
   will use projects.
8. **Where `score.json` lives.** It is in `<project>/.factory/runs/<run id>/score.json`. That folder is inside the
   project umbrella's working copy. No sandbox mounts it (a sandbox mounts a leaf and its git dir, and nothing of the
   parent) and the export for `/app` takes committed files only. But `.factory/` is untracked and not ignored in the test project (`git ls-files --others --exclude-standard` lists it). A person who runs `git add -A` in the umbrella would commit it. Please check that the umbrella template
   ignores `.factory/runs/`. This part does not change it.
9. **A node kind that `Advance` does not know passes silently.** The tests at v0-T249's red step showed it: before the
   `grade` case existed, a graph with a grade node finished `done` and graded nothing. The new kind is now handled, but
   the `switch` has no default. Suggest a backlog item.
10. **Not proven here:** the container runs only on a real engine (v0-H16). The logs folder is created `0755`; whether
    the suite's user can write to it, and to `/app`, under rootless Podman is v0-H16's to find (gleipnir's task
    lists the same fact).

#### Sizes

| Commit | Task | Insertions |
| --- | --- | --- |
| `a82a0fb` | v0-T247 part 1: task.toml, brief hash, retired mark | 386 (384 without `go.sum`) |
| `e0a136d` | v0-T247 part 2: the suite's folders and manifest | 134 (16 removed) |
| `6d08bd9` | v0-T248 part 1: read the Playwright results | 232 |
| `654dc8c` | v0-T248 part 2: join, reward, `score.json` | 365 |
| `a5925c4` | v0-T249 part 1: the run holds a grader, exports `/app` | 304 |
| `4ef3d84` | v0-T249 part 2: the grade stage | 410 |
| `9267548` | v0-T249 part 3: failures, order and isolation tests | 271 |
| `b6da7a0` | v0-T250: `ygg grade`, `ygg doctor` | 315 (5 removed) |

The whole part is 2401 insertions. v0-T249 part 2 is 10 lines over 400.

### Phase 5c, part C: routing in Odin, the `pointer-contract` gate and the routing docs (v0-T251 to v0-T256)

Drafted and run in the reference workspace on 2026-10-18. Odin: branch `grader/odin`, on top of v0-T250 (`b6da7a0`),
nine commits for five tasks. Gungnir: branch `routing/pack` on top of v0-T245 (`74d6c89`), one commit. Midgard-react and
helheim-go: branch `routing/pointer-contract` from `origin/main`, one commit each. The event names are the snake_case ones
of the code (`routing_index_built`, `pointer_contract_checked`). `routing_lookup` already exists in Gungnir and no code emits
it today (`grep` finds the constant only). This part does not add the emitter: see decision 12.

All Odin tests build through `yggdrasil/go.work` (the local Gungnir). Before CI (`GOWORK=off`) can build v0-T255, pin Gungnir
at the commit of the `routing/pack` branch (see "To pin a sibling" under "How each task lands" in the 5b plan).

#### Why `pointer-contract` was not in Phase 5b

The "Not in Phase 5b" section of the 5b plan says: "the routing indexes and their bench, the impact index and with it the
`pointer-contract` gate". The spec (§3.4, §8.2) says the gate decides on the impact index: a move is `pointer-contract` only
on `extracted` evidence or on `oasdiff`. Without an impact index the gate has nothing to judge by. A gate that guessed would
break the rule that a guess never passes. So 5b left the node kind known (`gungnir.GatePointerContract`, and the row in the
mode table) and put no node in a graph. This part builds the index first (v0-T251, v0-T252), then the gate on top of it
(v0-T254). The gate obeys the reason in two ways: it passes a move only when no contract file changed, or when nobody
reads the changed contract, and it never lets a guess pass (see decision 2).

#### Decisions and flags for this part

Each line is for the founder to confirm when the plan is merged.

1. **`REPOS.md` is a generated file in the project umbrella.** Odin writes the wiring block between
   `<!-- ygg:wiring:begin -->` and `<!-- ygg:wiring:end -->` and keeps all text around it. A file with a stray marker is an
   error and Odin cuts nothing. The three 5b tests that used `REPOS.md` as a plain "generated file" now use `INDEX.md`
   (v0-T253 diff), because a pointer node that lists `REPOS.md` in `generated` now rebuilds it.
2. **Gate semantics.** The ledger verdicts map as follows. `pass`: no contract file changed, or the contract has no reader
   (a lower bound), or oasdiff finds no change. The gate opens in key-points and unattended modes. `fail`: a contract changed
   and an extracted edge or oasdiff shows it. This is the approval point (key-points stops; unattended gives `Block`, which
   the engine treats as a stop today). `escalate`: only an `inferred` edge links readers, or the index does not list the
   file. A person decides in every mode, even if the spec holds the change. Step-by-step mode stops at every gate, as before.
3. **The first contract of a project escalates.** The gate reads the impact index shipped at `HEAD` of the umbrella. A new
   API's first task adds `openapi.yaml`. The index has no such contract, so the verdict is `escalate` and a person is asked.
   Please confirm this is wanted. The alternative is to treat a file the move adds as a new contract with no readers (`pass`).
   The code and the test (`TestAnInferredOnlyEdgeNeverGivesPass`) choose the careful one.
4. **A pack can carry a `routing` block** (`routing: {threshold: 0.8, bench: <path>}`). The contract did not list it, and Gungnir's
   pack schema refuses unknown keys, so v0-T255 adds it in Gungnir (one commit, 73 lines). The default bench path is
   `.ygg/routing-bench.yaml` in the project umbrella, where no agent mounts.
5. **The threshold gates; the grep baseline is only reported.** Spec §8.3 says an index "MUST NOT ship unless it raises the
   right-first score". The contract says "at or above a threshold in the pack". The code follows the contract and logs the
   scripted grep baseline beside the score (fixture: index 8/8, baseline 2/8). Please say if the baseline must gate too.
6. **midgard-react sets no `routing` block.** A new project has no bench, and a threshold without a bench refuses the move
   (`the routing index does not ship`). So a project opts in: it adds `.ygg/routing-bench.yaml` and the pack block. Please say
   who writes the first bench (a planner stage, or a person). Until then indexes ship unmeasured.
7. **oasdiff is not proven here.** The host has no `oasdiff`. `routing.OasdiffCLI` runs `oasdiff changelog old new` and
   `oasdiff breaking --fail-on ERR old new` and is tested against a stand-in script. The command lines follow `go-contract.sh`
   (`oasdiff breaking`) and the oasdiff CLI as the drafter knows it. They are not checked against the 1.33.0 binary. Odin looks for `oasdiff` on the host's `PATH` (`routing.HostOasdiff`); the images
   hold it, the host may not. Without it the index alone decides. The real binary is for the next handover step (v0-H16).
8. **The indexes are built when a pointer node moves, in the project umbrella only** (`parent.Dir == r.Project`). A
   company-level umbrella ships nothing. The build reads the leaves' working copies at that moment. At a move the leaf is
   checked out at the commit it moves to (`pointer.Move` checks it). Other leaves are at their working copies, not at their
   pointers: a leaf with uncommitted work is read as it is. Suggest a backlog item.
9. **Only Go imports are read, not TypeScript imports.** The web leaf's links come from `package.json`, the lockfile, the
   umbrella and the contract copy. A TypeScript import graph needs a parser the factory does not have yet.
10. **Leaf files are written by agents.** The generator reads only regular files, never a link, at most 1 MiB each, at most
    20000 entries a leaf, and skips `.git`, `node_modules`, `vendor`, `testdata`, `dist` and `.factory`. A name that can break
    a table row or a marker (`|`, `<`, `>`, a back tick, a control character) drops its edge and is counted in
    `Result.Skipped`. The ledger note of `routing_index_built` says how many were left out.
11. **`Block` in unattended mode.** `gate.Decide` returns `Block` for a contract change in unattended mode. `reachGate` treats
    every action but `Auto` as a stop, so the run stops instead of blocking the task and going on. This was so in 5b and is not
    changed here. Suggest a backlog item.
12. **Not built here:** the emitter of `routing_lookup`, and the routing summary Odin injects into each session (§8.1). The bundle
    is stored outside the agent's mount in the sense that the umbrella working copy is not mounted (the same fact as flag 8
    of part B). Both belong to a later task. The `doc-code` and `decisions` indexes of §8.2 are also later.
13. **No CLI command yet** for "build the indexes" or "run the bench" outside a run. The bench and the generators are
    packages with tests. Suggest `ygg routing build|bench` as a small task for the exit check.

#### Sizes

| Commit | Task | Insertions |
| --- | --- | --- |
| `0251122` | v0-T251 part 1: edges, the REPOS.md block | 171 |
| `58aab31` | v0-T251 part 2: umbrella, packs, go.mod, package.json, lockfiles | 433 (fixture and tests are 270) |
| `be6a9fa` | v0-T251 part 3: imports, contracts, copies, mentions, link safety | 282 |
| `26f99eb` | v0-T252: the impact index | 510 (a 140 line golden file is in it) |
| `e6c4a3b` | v0-T253: the shrink guard counts edges; the move builds both indexes | 280 |
| `0549cb7` | v0-T254 part 1: `routing.Judge`, oasdiff | 295 |
| `5e76894` | v0-T254 part 2: the gate node | 293 |
| `5a03331` (gungnir) | v0-T255 part 1: the pack's `routing` block | 73 |
| `39ae718` | v0-T255 part 2: the bench | 340 |
| `bb841e2` | v0-T255 part 3: the threshold gates shipping | 76 |
| `65df473` (midgard-react) | v0-T256 | 65 |
| `b57070e` (helheim-go) | v0-T256 | 46 |

The 433 and 510 line commits are over 400 because of fixtures and a golden file; the code in each is under 250 lines.

### Phase 5c, part D: `ygg deps bump` in Odin (v0-T259)

Drafted and run in the reference workspace on 2026-10-18. Odin: branch `grader/odin`, on top of the last Odin commit of part C (`bb841e2`, v0-T255). Six commits for one task. The task needs the event names of v0-T245 (`deps_bump`, `deps_checked`, in `gungnir/event.go`) and the packs of v0-T257 and v0-T258 (the `deps` check). It does not need the grader. The event names are the snake_case ones of the code. The contract spells them with a dot (`deps.bump`); the code does not.

Spec §9.6 says: a bump rolls to one canary product first; if the canary's suite fails, the bump does not roll out; after the canary passes, the bump rolls out in batches. This task builds the command that does it. The batch size is one: a rollout product is bumped, checked, and only then the next.

#### Decisions and flags for this part

Each line is for the founder to confirm when the plan is merged.

1. **The ladder of a bump is two checks: `deps`, then `unit`.** The contract names them. A realm that defines no `deps` or no `unit` check is refused before anything changes: a bump never skips a rung. The other rungs (static, security, contract, end to end) do not run. Please confirm that two rungs are enough for a canary. The check list is one variable (`deps.Ladder`).
2. **A product is a leaf of the project.** `--canary` and `--rollout` take a path from the project (`repos/api`) or an absolute path. The path must be a leaf in the project's `umbrella.yaml`. The realm is the one the project pins for the leaf, else the lead realm. It is found in `realms.dir` of `factory.yaml`, so a config with no `realms` section is refused. The pinned realm version is not compared with the store's, as `ygg run` does.
3. **Where the commands run.** With a `sandbox` section in `factory.yaml`, the tool and the checks of one product run in that product's own sandbox, on its realm's stack, with the registries of its pack in the egress list. One sandbox per product, started when its turn comes and stopped when it ends, also after a failure or a cancel. Without a `sandbox` section they run on the host with `PATH`, `HOME` and `LANG` only, as a run without a sandbox does. The sandbox gets the services of the product's own realm, not those of the leaves it consumes. `deps` and `unit` need no service in the two real realms. Flag it if a realm's `unit` needs one.
4. **The bump has its own folder and ledger, not a run's.** It writes `.factory/deps/<id>/ledger.jsonl` (hash-chained, the same writer as a run's ledger) and `logs/` with the output of each command. `<id>` has the form of a run id. The folder appears when the first line is written, so a refusal leaves nothing. The bump takes the project's runs lock, so it cannot run beside a run. `ygg status` and `ygg doctor` do not know the folder yet. Open question: should a later task teach `ygg doctor` to find a sandbox that a killed bump left? The sandboxes carry the bump's id as their run label.
5. **The change stays in the working copies, uncommitted.** Odin does not commit, branch or merge a bump. Why: the merge gate and the checkpoint code belong to a run, and a bump is not one. A human commits what passed, or a later task makes a bump a run. Please confirm.
6. **The tool may change the manifest and its lock file, and nothing else.** Before the tool runs, Odin reads every file of the product (not `.git`, not `node_modules`). After it, any change outside `go.mod`/`go.sum` (Go) or `package.json`/`package-lock.json`/`npm-shrinkwrap.json` (npm) fails the product, and the ladder does not run. This is how "never changes a policy file" holds: the policy file of a realm is baked in the image, and a copy in the product is as read-only to the bump as any other file. Odin never opens a policy file at all. A product over 256 MiB of files is refused, because a failed bump could not be undone. File times are not restored; mode and bytes are. `node_modules` is not restored: it is a cache that `npm ci` rebuilds.
7. **Down is refused, up only.** A version below what a product requires refuses the whole bump, also when only a rollout product is above it, and nothing changes. An equal version refuses a canary ("nothing to bump"), and skips a rollout product (it is reported as `skip`, logged nowhere, and its sandbox is never started). A pre-release target is refused: the policy wants tagged releases. A package name that starts with `-`, or has `..`, is refused: it would be read as an option of the tool. A package a product does not require is refused: a bump never adds one.
8. **The tool's command.** Go: `go get <module>@v<version>`. npm: `npm install --ignore-scripts --save-exact <pkg>@<version>`, or `--save-prefix=~` when the manifest has `~x.y.z`. So the pin style the policy checks (`x.y.z` or `~x.y.z`) is kept. An npm requirement written as `^x.y.z`, a range, a tag or a URL is refused: the bump does not guess a style. `--ignore-scripts` keeps a package's install script from running with the factory's credentials near.
9. **Ledger lines.** One `deps_bump` per product that ran (`stage` canary or rollout, `verdict` pass or fail, `from`, `to`, `package`; the `note` holds the product and the reason, cut at 400 bytes). One `deps_checked` after each `deps` rung (`realm`, `verdict`); `findings` is left out, because the script prints a count for people and Odin does not parse it. Failure order: the product is put back first, then the `fail` line is written, so the ledger never says "failed" before the files are right. A cancelled bump writes no verdict line.
10. **Exit codes.** 0 done. 1 a product failed its ladder (and was put back), or a tool, sandbox or file error stopped the bump (the product is still put back). 2 refused: nothing ran, nothing changed.
11. **The real `go` runs in a test; the real `npm` does not.** The test builds a module proxy as a folder (`GOPROXY=file://...`) with three versions of a module and bumps a real tiny module with the real `go get`, offline. `npm` has no such offline registry that is cheap to build, so the npm test uses a stand-in tool and checks the command and the tilde. The npm command line is checked by reading, and by the first real bump of a web product (v0-H16 or the real-agent smoke run).
12. **A command has 30 minutes.** `deps.DefaultTimeout` is 30 minutes, three times the loop's `ExecTimeout`, because `go get` may fetch and `unit` is a full test run. Flag it if you want one number.

#### Sizes

| Part | Commit | Inserted lines |
| --- | --- | --- |
| 1 versions and manifests | `88bb531` | 367 |
| 2 snapshot and restore | `c0f3e13` | 262 |
| 3 `Bump` and its core tests | `a312aa5` | 440 |
| 4 the other `Bump` tests, and the real `go` | `72b9fe6` | 318 |
| 5 the command | `a4066e5` | 262 |
| 6 the command's tests | `12cffed` | 194 |

Part 3 is 440 lines because `Bump` and its first tests belong together. The commit message says so.

---
