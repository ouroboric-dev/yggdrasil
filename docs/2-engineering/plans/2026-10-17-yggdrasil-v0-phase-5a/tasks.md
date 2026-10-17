---
title: Yggdrasil v0, Phase 5a tasks (realms and tasks: the engine)
status: accepted
date: 2026-10-17
related: [../2026-10-12-yggdrasil-v0/plan.md, ../2026-10-16-yggdrasil-v0-phase-4/tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../changes/2026-10-17-realm-leaf-naming/proposal.md, ../../changes/2026-10-17-realm-engine/proposal.md, ../../backlog.md]
style: spec
---

# Yggdrasil v0, Phase 5a: realms and tasks, the engine

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking. Tasks and steps marked **founder** are done by the founder,
> never by an agent.

**Goal:** the engine half of the [plan](../2026-10-12-yggdrasil-v0/plan.md)'s Phase 5. A run loads its
lead realm and the realm of each leaf, each once, at the version the project pins. The spec stage names
the product's leaves and their realms, and Odin creates them. The plan becomes tasks, and the task shape
(implement and check, merge gate, pointer move) repeats for every ready task, in the task's leaf, with the
prompt, checks and sandbox of that leaf's realm. A merge gate that refuses sends the work back into the
loop, and an unattended run gives up a task whose loop gave up and goes on with the rest.

**Architecture:** Gungnir gets what the other components share: the realm pins in `umbrella.yaml`, the
pack's leaf recipe and services, `leaves.yaml`, `tasks.md` with the Definition of Ready, `features.json`,
the graph's `foreach`, scratch-agent, `publish`, `tasks` and `init` nodes and `back_to`, the sandbox spec's
stack, services and scratch folder, and the ledger events. Gleipnir's driver starts a sandbox's services,
opens their ports and no others, starts each leaf on its realm's stack, holds a scratch folder with no git
directory, and stops mixing up two leaves whose paths differ in punctuation. Jormungandr's loop can be
reopened after it passed. Odin loads realms from a store and pins them, records them, runs the stages
before the code in scratch workspaces and publishes their documents, reads the plan into tasks, creates the
leaves, expands the task shape for each task, sends refusals back, and gives up tasks when it is unattended.

**Tech stack:** Go 1.26 and the pins of Phase 4. No new third-party dependency.

**Spec:** [v0 engineering spec](../../specs/2026-10-11-yggdrasil-v0-spec.md) §2.1, §3.1, §3.3, §4.1,
§4.2, §4.5, §6, §7.3, §9.2, §9.4, §9.5, §10.1 and §13; and the accepted changes in
`docs/2-engineering/changes/` where they override it (`require-budget-caps`, `remote-creates-repos`,
`benchmark-split`, `factory-issues`, `project-is-its-own-tree`, `loop-escalation-and-spend` and
[realm-leaf-naming](../../changes/2026-10-17-realm-leaf-naming/proposal.md), whose task T004 this plan
builds), plus the change this plan adds,
[realm-engine](../../changes/2026-10-17-realm-engine/proposal.md), which records the places where the
spec was silent and this phase had to choose.

**Status:** accepted when the founder merges the pull request that adds this file.

**Code in this plan was run.** Every Go file, script, schema and test below was built and run in a
scratch Go workspace on 2026-10-17, one commit per task, with `go test -race` on Go 1.26.4 and on
1.26.9, CI's version. Each task's end state was also built and tested on its own, and each task's
first test run was checked to fail as its step says (a task whose tests pass at once says so). Real model
sessions and a real container engine are the two things not run (v0-H12 and v0-H13: they need your
machine and, for the second, your tokens). Copy the code as written; if a step's expected result differs,
stop and report it, because the plan is wrong.

Code blocks are of two kinds. A new file is shown whole. A change to an existing file is shown as a
git patch (`diff`); apply it with `git apply` from the repo's folder, or edit by hand: lines that
start with `+` are added, lines with `-` removed.

## Decisions for this phase

Each line is **Decided 2026-10-17** when the founder merges this plan.

1. **Phase 5 is three plans, and this is the first** (founder, 2026-10-17). 5a is the engine: the
   realms, the per-task graph, the loop in a run of many tasks, the merge gate's refusal going back, the
   stages before the code. 5b is the realms' content: the packs, prompts, stack layers and templates of
   `midgard-react` and `helheim-go`, the check ladder's rungs 1 to 6 and the reviewers, with the snapshot
   sandbox that lets acceptance checks run with a sandbox on. 5c is rung 7 and the isolated grader with
   `score.json`, the routing indexes and bench, the dependency policy and the real smoke brief, which is
   Phase 5's exit criterion. This plan's own exit criterion is smaller: a scripted run of two toy realms
   builds a product from both end to end (v0-T192), and the realms smoke run with real agents does the
   same on your machine (v0-H13), with the services on a real engine checked by v0-H12. The v0 spec and
   the dated design docs are records and stay as accepted; the accepted proposals override the spec where
   they differ, and this plan's [change](../../changes/2026-10-17-realm-engine/proposal.md) records the
   rest. **This plan came out at 62 agent tasks, more than the 35 or so the split assumed** (Phase 4 had 44).
   The tasks are small (the largest adds 372 lines) and fall into four pull requests by repo; if you want a
   smaller review, the Gungnir, Gleipnir and Jormungandr tasks (v0-T142 to v0-T167) make a self-contained
   first half.
2. **Realms live in a local store, and a pin is a name and a version** (founder, 2026-10-17: "Local realm
   store"). `factory.yaml` says `realms: {dir: ...}`, a folder with one checkout of each realm leaf
   (`<dir>/midgard-react/pack.yaml`). `--realm` takes a name, found there, or a path, used as it is. A
   project pins its lead realm and, for each leaf, the realm that provides it, in `umbrella.yaml`
   (`realm`, `realm_version`, and for a leaf `consumes`). The pin's version must be the store's: Odin does
   not fetch. It records every realm of a run in `run.json` with a hash of every file a run could read
   (not `.git`), and a resume refuses a realm whose hash or version changed. The first run of a project
   that names its lead realm pins it, in a commit of its own; a realm given as a path pins nothing. Fetching
   a realm by tag from GitHub waits for iteration 2's `github` remote (spec §15.1).
3. **One version per realm leaf per run, and a disagreement stops the run before anything is created.**
   Two pins of one realm at two versions, a lead pin that names another realm than `--realm`, a store that
   holds another version than the pin, and a realm the store lacks are all reported at once, with the pin
   that caused each. A leaf with no pin is the lead realm's, so every project that exists keeps working.
4. **A build realm's pack offers the same recipe under the same names.** `leaf:` holds the template, the
   first-commit files, the implementer's prompt and the leaf's checks; `services:` the containers a sandbox
   of its leaves starts. A realm that never leads has no graph (the `graph` of a pack is optional), and a
   documents realm (Asgard, Alfheim, Vanaheim) has neither a recipe nor a stack: backlog B-036's engine
   half is done by scratch agents and `publish` (v0-T193). The pack's `leaves:` map stays, as the default
   leaves of the lead realm's own graph; the project's pins and the leaves file decide the rest, so the
   map is not needed for the client gallery, and removing it would break every older fixture for nothing.
5. **The project decides its leaves, through a file the spec stage writes.** `leaves.yaml` names each
   leaf's path, realm, version, description and consumers. The operator approves it at the `spec` gate (the
   stage's documents are published into the project after the gate, so the approved file is the one Odin
   reads). `init` reads it exactly, loads the realms it names, refuses it before it creates anything if the
   realms disagree with the project's pins, a realm offers no leaf recipe, a leaf that exists is pinned
   otherwise or consumes otherwise, or a consumed leaf does not exist; then creates each missing leaf, the
   ones a leaf consumes first, through the remote with the pin in the same commit, and copies the rest of
   the realm's template onto the run's branch in a checkpoint of its own while the leaf holds only its
   first commit. A leaf with history keeps what it has. A project may use several flavors of one realm.
6. **The stages before the code run as scratch agents, and Odin publishes their output.** Spec §3.3 rule 1
   says a planner gets a scratch directory and Odin commits its output after the approval point. A scratch
   agent works in `<run>/scratch/<node>`, made again for every attempt and retry: the brief, copies of the
   project paths it names (never a symlink, never `.git`), and an empty `out/`; in a scratch sandbox when
   the run has one (the folder and nothing else, no git directory). `publish` copies `out/` into a folder
   of the project and commits it by explicit paths with hooks off. It publishes documents only: regular
   files with plain names, endings of a document, bounded in number and size, through no symlink, and (with
   a sandbox) free of secrets, which is a hard stop at `real-secrets-or-user-data`. A read-only scratch
   agent, the design-conformance reviewer of §4.2, and the `spec` gate's deviation fact are 5b's.
7. **A plan is read exactly, and a plan that is not ready goes back to the planner.** `tasks.md` is the
   canonical layout (a heading `## <id>: <title>`, then `**Acceptance criteria:**` with checkboxes,
   `**Named test:**`, `**Layer:**`, `**Size:**`, `**Depends on:**`), bounded at 1 MiB and 200 tasks, with
   fences ignored. A task's layer is its leaf's path (`layer/web` reads as `repos/web`). The Definition of
   Ready lists every problem of every task (no criteria, test, layer or size; size L; a layer that no
   leaf has; a missing blocker; a ring), and the list goes back into the planner's prompt, which is why it
   is cut at 6,000 bytes. `features.json` is derived from the plan and written by Odin alone; an agent is
   told its task in its prompt, bounded, and never reads the file.
8. **A refusal goes back into an earlier node as that node's input, a few times** (spec §4.5, §4.2). A merge,
   a pointer or a tasks node may name `back_to` (an earlier agent or loop of its own scope) and `returns` (1
   to 5, 2 when unset). Past `returns`, or with no `back_to`, the node fails as before. A rejection at a
   gate gives the refusals after its target their returns again. This is the merge gate's loop-back, the
   second half of Phase 4's decision 12.
9. **Only a refusal the implementer can fix goes back.** A merge gate whose checks fail on the branch with
   the base merged in, a pointer move whose checks or acceptance tests fail: yes, and the leaf's
   checkpoint becomes the merged head the checks ran on. A base that does not merge cleanly, a target
   another process holds, and Odin's own failures: no, they fail the node (the implementer is not run
   again for a conflict it cannot see).
10. **The task shape is a foreach node, expanded when the walk reaches it** (spec §4.2, "for each ready
    task"). The graph holds the shape once; its body names no repo, and its loop, merge and pointer take
    their prompt, checks and sandbox from the realm of the task's leaf (`realm: leaf`), so the graph names
    roles and Odin resolves each in that realm. The expansion is a pure function of the graph, the tasks in
    build order and the realms; the run records that it happened and the tasks, so a resume makes the same
    nodes. Tasks run one after another, each after what it depends on. A task is todo, doing, done or
    blocked, in `run.json`, `features.json` and the ledger. Every leaf a task works in joins the run when
    the shape is expanded.
11. **An unattended run gives up a task whose loop gave up** (spec §7.3, second half; it replaces Phase 4's
    decision 7 for this case). The task is blocked with the loop's reason, the leaf goes back to its main,
    what the task did stays on `refs/ygg/<run>/blocked/<task>`, and the tasks that depend on it are blocked
    when the walk reaches them. The run ends `done` and lists the blocked tasks first, in the ledger, in the
    output, in `ygg status`; the exit code is 5, so a script notices. The other modes stop at the
    escalation as before, and every other failure still fails or stops the run. The `pointer-contract`
    gate's unattended blocking waits for the impact index (5c).
12. **Each leaf's sandbox starts on its realm's stack with its realm's services and those of each leaf it
    consumes** (spec §6.1, §9.2; the proposal's "services follow the leaves a sandbox uses"). Two realms
    offering different services of one name, and a realm with no stack when a sandbox is on, stop the run
    before a sandbox starts. A service runs on a digest-pinned image, with the image's own user and command,
    no mount, no added capability, no published port and no credential in its environment (made-up
    development values only: a service that wants a password uses the image's mode without one). The
    firewall opens a service's listed ports to the work container and no others, waiting for a service that
    is still starting. The services' reachability on a real engine is checked by v0-H12.
13. **Acceptance checks with a sandbox stay for 5b.** They run in the project over several leaves, so no
    leaf sandbox holds them (Phase 3, decision 11). This plan only makes the refusal cover a task shape's
    nodes (v0-T196).
14. **Backlog.** B-010 (v0-T179), B-015 (v0-T157), B-035 (the loading of v0-T168 to v0-T171 and v0-T185) and
    B-036 (v0-T193, with v0-T145) are fixed here. B-005 and B-006 (locks) stay: this plan does not touch
    the code that takes them, and `AddLeaf` runs after the locks are held. B-037 (a gate approved outside
    the CLI) and B-039 (Podman on macOS) wait for the Asgard realm's graph, which needs them, not this
    plan. B-040 is the founder's. Of B-034's minors, none is touched.
15. **Tests are hermetic.** They need no network and no engine, write nothing under the real `HOME` (every
    Odin test package sets `XDG_STATE_HOME`), and run the scripted adapter, whose transcripts show the
    prompt each session got. The two checks that need a real engine are integration tests behind the
    `sandbox` build tag (v0-T162), and the real-agent check is a script (v0-H13), like Phase 4's v0-H11.
16. **Documentation.** The architecture page of each repo says what the component now does (v0-T156,
    v0-T164, v0-T167, v0-T203). The spec is not edited; the change `realm-engine` records the places where
    it was silent and folds into `system/` with the others when v0 lands.
17. **Sizes count insertions,** as git reports them. No task is over 400: the two largest add 372 and 367.
18. **Pull requests and pins.** Four pull requests, in this order, each opened once the one before is
    merged and pinned: `gungnir` (v0-T142 to v0-T156), then `gleipnir` (v0-T157 to v0-T164) and
    `jormungandr` (v0-T165 to v0-T167), which do not depend on each other and can be open together, then
    `odin` (v0-T168 to v0-T203), then `yggdrasil` (v0-T204). `ouroboric` gets one more, for the
    founder's script (v0-H13), which is opened with this plan's pull request.

## Global constraints

- **Local copies.** The component repos are submodules of `yggdrasil`, at
  `/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`, and `yggdrasil/go.work` builds them together.
  Each task works on a branch in the submodule it changes. The umbrella's pointers move once, in
  v0-T204.
- **GitHub.** Agents reach GitHub only as `ouroboric-pr-bot`, through
  `/home/brunogbv/brunogbv/ouroboric/ouroboric/scripts/as-bot.sh`. `as-bot.sh <repo> <command>` pushes
  and opens PRs; `as-bot.sh --read all <command>` reads. Every change lands through a PR the founder
  merges. Agents never merge and never push to `main`, and never hold GitHub Administration rights:
  creating or renaming a repo is the founder's.
- **Commits.** Read `git status --short` first, and stage explicit paths, never `git add -A`. Commit
  messages end with `Co-Authored-By: Claude <model> <noreply@anthropic.com>`, naming the model that wrote
  the commit. Commits and PRs carry no session links. Every repo runs the `gitleaks` hook.
- **Go.** `go.mod` says `go 1.26`. Code is `gofmt`-clean and `go vet`-clean. Before a PR opens, the
  repo passes `GOWORK=off go test -race ./...` in its own folder, as CI runs it. This machine has Go
  1.26.4; CI uses 1.26.9.
- **Podman.** Nothing in this phase needs the engine except v0-H12 and v0-H13. Claude Code's sandbox
  blocks the engine's socket, so a command that reaches it runs with `dangerouslyDisableSandbox` and
  the founder's approval, as in Phase 3.
- **Credentials.** Real tokens (`CLAUDE_CODE_OAUTH_TOKEN`) belong to the founder's run (v0-H13). No
  agent reads, prints or stores `~/.config/ouroboric/factory.env`, and the tests use made-up values,
  including a service's environment.
- **Pins.** Phase 3's and Phase 4's. This phase adds none.
- **Licences.** `reuse lint` (`reuse==5.0.2`) passes in every repo a task touches.
- **The hidden suite.** No agent reads, lists or searches `ouroboric-dev/huldra` or its clone under
  `~/brunogbv/ouroboric-private/`. This phase does not touch the benchmark.
- **Deletions** (`rm`, `git branch -D`) are asked for first, one per command, after a read-only check.
- **Tests are hermetic.** A test never writes under the real `HOME`, never needs the network or an
  engine, and passes in any working directory. A test that runs a session gives it a state folder of its
  own.
- **Agent text is data.** A plan, a leaves file, a document and a task's words come from an agent. They
  are read exactly, bounded, and reached through no symlink; they never become a path, a command or a
  prompt without a check on the way.

## Review focus

1. **An agent's file that gets more than it should.** A plan, a leaves file, a scratch input or a document
   with a symlink on its path, a hidden name, a path outside the project, a leaf inside a leaf, a secret, a
   file too big or too many. Expected: refused with a reason that names it, nothing written outside the
   project, nothing created, nothing published. Pinned by v0-T150 `TestParseTasksRefusesWhatItCannotReadExactly`,
   v0-T182 `TestAnInputThatCouldLeadOutOfTheProjectIsRefused`, v0-T183 `TestPublishRefusesWhatIsNotADocument`
   and `TestSecretsInTheDocumentsAreAHardStopAndNothingIsPublished`, v0-T187
   `TestInitRefusesBeforeItCreatesAnything`, v0-T194 `TestPublishWritesNothingThroughASymlinkInTheProject`
   and v0-T200 `TestLocalCreateRefusesALeafInsideAnotherChildOrHoldingOne`.
2. **Realms that disagree, change, or are half taken.** Two pins of one realm, a store at another version,
   a prompt edited under a run, an init that stops after one leaf. Expected: the run stops before it
   creates anything, a resume refuses the changed realm, and a resume after a half init finishes it. Pinned
   by v0-T169 `TestTwoPinsOfOneRealmThatDisagreeStopTheRun`, v0-T170
   `TestRunJSONRecordsEveryRealmAndAResumeRefusesOneThatChanged`, v0-T186 `TestInitCreatesEachLeafFromTheTemplateOfItsRealmAndRecordsThePin`
   and v0-T199 `TestAnInitThatStopsHalfWayCanBeResumedAndFinishes`.
3. **A refusal that loops forever, loses work, or goes to the wrong place.** A merge gate that keeps
   refusing, a conflict, a plan that stays bad, a rejection after a return, a resume in the middle.
   Expected: it goes back at most `returns` times, a conflict fails the node, the second prompt carries the
   refusal, and the work that failed the gate is not on main. Pinned by v0-T177
   `TestARefusalGoesBackOnlyAsOftenAsTheNodeAllows`, v0-T180 `TestABaseThatDoesNotMergeCleanlyIsNotSentBack`
   and `TestARefusalThatKeepsComingBackFailsTheNodeAfterItsReturns`, and v0-T197
   `TestARejectionGivesARefusalItsReturnsAgain`.
4. **A task given up that leaves damage, or a task started that should not be.** The leaf of a blocked task,
   a task that depends on it, a task done just before the skipped ones, a mode that is not unattended.
   Expected: the leaf is back at main with the work on a ref, dependents are never started, every status is
   right at the end, only an unattended run gives up. Pinned by v0-T181
   `TestAnUnattendedRunGivesUpATaskWhoseLoopGaveUpAndGoesOnWithTheRest` and `TestOtherModesStopAtTheLoopThatGaveUp`,
   and v0-T190 `TestATaskDoneJustBeforeTasksThatAreSkippedIsStillDone`.
5. **A sandbox that gets more than its leaf's realm allows.** Services of two realms with one name, a port
   not listed, a scratch folder with a git directory, a service that asks for a credential or a privilege.
   Expected: refused before it starts, or closed by the firewall. Pinned by v0-T144
   `TestASandboxSpecMayCarryAStackAndServices`, v0-T158 `TestAServiceTheFactoryDidNotWriteIsRefusedBeforeItStarts`,
   v0-T159 `TestEgressOpensAServicesPortsAndNoOthers`, v0-T161 `TestAScratchSandboxMountsOneFolderAndNothingElse`
   and v0-T174 `TestTwoRealmsOfferingDifferentServicesOfOneNameStopTheRunBeforeASandboxStarts`; on a real
   engine, by v0-H12.

## Order

| Task | Repo | Size | Depends on |
|---|---|---|---|
| v0-T142 a project records its lead realm, and each leaf its realm and what it consumes | `gungnir` | M | Phase 4 |
| v0-T143 realm names and versions are checked in one place, and a repo a remote creates carries its pin | `gungnir` | M | v0-T142 |
| v0-T144 a sandbox spec names its stack and services, and may hold a scratch folder instead of a leaf | `gungnir` | M | v0-T143 |
| v0-T145 a build realm's pack offers a leaf recipe and services under standard names, and a realm may have no graph | `gungnir` | M | v0-T144 |
| v0-T146 factory.yaml says where the realm leaves are | `gungnir` | S | v0-T145 |
| v0-T147 a graph repeats a task shape for every ready task, in the realm of the task's leaf | `gungnir` | M | v0-T145 |
| v0-T148 graph nodes for the stages that write documents: scratch agents, publish, tasks and init | `gungnir` | M | v0-T147 |
| v0-T149 a merge, a pointer move or a plan check that refuses can send the run back into an earlier node, a few times | `gungnir` | M | v0-T148 |
| v0-T150 a plan's tasks.md is read into features, exactly, with its limits | `gungnir` | M | v0-T149 |
| v0-T151 the Definition of Ready, applied to a plan's tasks: every reason is listed, and L tasks go back to be split | `gungnir` | M | v0-T150 |
| v0-T152 the spec stage names the leaves of a product and the realm of each, in a file Odin reads exactly | `gungnir` | M | v0-T142 |
| v0-T153 ledger events for realms, published documents, ready tasks and returned refusals | `gungnir` | S | v0-T152 |
| v0-T154 features.json: the plan's tasks and where each stands, written by Odin alone | `gungnir` | M | v0-T150 |
| v0-T155 the tasks node names the leaves file whose leaves its tasks may work in | `gungnir` | S | v0-T148 |
| v0-T156 Gungnir's documentation | `gungnir` | S | v0-T155 |
| v0-T157 two leaves never share a sandbox project or a configuration folder (B-015) | `gleipnir` | S | v0-T156 |
| v0-T158 a sandbox starts the services its leaf's realm asks for beside the work container | `gleipnir` | M | v0-T157 |
| v0-T159 the firewall opens a service's ports to the work container and no others | `gleipnir` | M | v0-T158 |
| v0-T160 each sandbox starts on the stack layer its spec names, so leaves of different realms differ | `gleipnir` | M | v0-T159 |
| v0-T161 a scratch sandbox: one plain folder, no git dir | `gleipnir` | S | v0-T160 |
| v0-T162 integration tests of services and scratch folders on a real engine, behind the sandbox tag | `gleipnir` | M | v0-T161 |
| v0-T163 Up refuses a service image that was never pulled, and Pull fetches one, by digest, with the isolated auth | `gleipnir` | S | v0-T158 |
| v0-T164 Gleipnir's documentation | `gleipnir` | S | v0-T163 |
| v0-T165 a loop that passed can be reopened when something downstream refuses its work | `jormungandr` | S | Phase 4 |
| v0-T166 the next attempt is told what a later step refused | `jormungandr` | S | v0-T165 |
| v0-T167 Jormungandr's documentation | `jormungandr` | S | v0-T166 |
| v0-T168 realm leaves load from a store, by name, with a hash of what a run could read | `odin` | M | v0-T167 (merged) |
| v0-T169 a run loads each realm once, and stops before anything starts when the pins disagree | `odin` | M | v0-T168 |
| v0-T170 a run takes its lead realm by name, loads the realm each leaf is pinned to, and records them all | `odin` | M | v0-T169 |
| v0-T171 the first run of a project pins the lead realm it was given by name, and the ledger's first line names every realm | `odin` | M | v0-T170 |
| v0-T172 a task shape is expanded for each task, in the leaf and the realm the task names | `odin` | M | v0-T168 |
| v0-T173 a node reads its prompt and runs its checks from its own realm | `odin` | M | v0-T170 |
| v0-T174 each leaf's sandbox starts on its realm's stack and gets the services of its realm and of the leaves it consumes | `odin` | M | v0-T170 |
| v0-T175 a run can take a leaf its graph doesn't name, and keeps it on resume | `odin` | M | v0-T170 |
| v0-T176 the tasks node reads the plan's tasks.md, checks every task is ready, and writes features.json | `odin` | M | v0-T170, v0-T151 (merged) |
| v0-T177 a refusal can go back into an earlier node as its input, a few times, and a plan that isn't ready goes back to the planner | `odin` | M | v0-T176, v0-T165 (merged), v0-T166 (merged) |
| v0-T178 a foreach node becomes each task's shape in the task's leaf and realm, and each task is tracked from todo to done | `odin` | M | v0-T172, v0-T173, v0-T175, v0-T176 |
| v0-T179 a pointer move's ledger lines close the attempts they open, and a waiver lasts one move (B-010) | `odin` | M | v0-T178 |
| v0-T180 a merge gate or pointer move that refuses the work's checks sends it back into the loop that made it | `odin` | M | v0-T177, v0-T179 |
| v0-T181 an unattended run gives up a task whose loop gave up and goes on with the tasks that don't depend on it | `odin` | M | v0-T178 |
| v0-T182 a scratch agent works in a workspace of its own, with copies of what it reads and an out/ folder for what it writes | `odin` | M | v0-T161 (merged), v0-T148 (merged), v0-T173 |
| v0-T183 publish copies a scratch agent's documents into the project and commits them, after checking they are documents and have no secret | `odin` | M | v0-T182 |
| v0-T184 the local remote records a leaf's realm pin and what it consumes in the commit that creates the leaf | `odin` | S | v0-T142 (merged), v0-T143 (merged) |
| v0-T185 a run can take the realms new pins name after it started, and records them | `odin` | S | v0-T170 |
| v0-T186 init creates the leaves the spec stage named, each from its realm's template, and records the pins | `odin` | M | v0-T184, v0-T185, v0-T175 |
| v0-T187 init refuses, before it creates anything, a leaves file it can't make real | `odin` | S | v0-T186 |
| v0-T188 ygg sandbox build builds the stack of every realm named, or of all in the store | `odin` | M | v0-T170 |
| v0-T189 ygg status shows each leaf's realm, the tasks and the ones given up; a finished run lists them first; doctor lists the realms | `odin` | M | v0-T181, v0-T188 |
| v0-T190 a task is done when the walk leaves its last node, even when the tasks after it are skipped | `odin` | S | v0-T181 |
| v0-T191 a pointer's acceptance checks are the lead realm's, and a check a realm doesn't define is an error | `odin` | S | v0-T173 |
| v0-T192 the toy realms build a product from two realms end to end, with scripted agents | `odin` | M | v0-T189, v0-T190, v0-T191, v0-T187, v0-T180, v0-T183 |
| v0-T193 a realm with no leaves, no stack and no recipe runs in an umbrella with no leaves (B-036) | `odin` | S | v0-T183 |
| v0-T194 documents and plans are read and written only inside the project, never through a symlink | `odin` | M | v0-T183, v0-T186, v0-T176 |
| v0-T195 a task's session is told its task, as the plan states it, bounded | `odin` | S | v0-T178 |
| v0-T196 acceptance checks in a task shape are refused with a sandbox on, as the graph's own are | `odin` | S | v0-T178 |
| v0-T197 a rejection gives the refusals after it their returns again | `odin` | S | v0-T177 |
| v0-T198 the realms smoke run: two realms, real planners and implementers, and a test that its prompts ask for files Odin accepts | `odin` | M | v0-T192 |
| v0-T199 init checks the leaves file against the realms before the run takes them, and a resume keeps the realms a run recorded | `odin` | S | v0-T187 |
| v0-T200 the local remote refuses a leaf inside another child, or holding one, before it creates anything | `odin` | S | v0-T184 |
| v0-T201 a plan in a project with no leaves is checked against no leaves | `odin` | S | v0-T176 |
| v0-T202 ygg sandbox build also pulls the images of the services of the realms it builds | `odin` | S | v0-T188, v0-T163 |
| v0-T203 Odin's documentation | `odin` | S | v0-T202 |
| v0-T204 pointers and the exit check | `yggdrasil` | S | all above, merged |
| v0-H12 (founder) services and a scratch folder on a real engine | the founder's machine | S | v0-T163 merged; Phase 3's v0-H07 and v0-H09 |
| v0-H13 (founder) the realms smoke run with real agents | the founder's machine | S | v0-T198 merged; Phase 3's v0-H07 and v0-H09 |

Gungnir's fifteen tasks go up as one pull request, one commit per task; gleipnir's eight as one, opened
once gungnir's is merged and pinned; jormungandr's three as one, opened the same way; odin's thirty-six as
one, opened once all three are merged and pinned. Inside a repo the tasks stack on one branch.

## Not in Phase 5a

The realms' content (the packs, prompts, stack layers, templates, graph and checks of `midgard-react` and
`helheim-go`), the check ladder's rungs and the TDD check, the reviewers, the design-conformance review and
the `spec` gate's deviation fact, and acceptance checks with a sandbox (5b). The isolated grader and
`score.json`, the routing indexes and bench, the impact index and the `pointer-contract` gate's behavior,
and the dependency policy (5c). The `github` remote, fetching a realm by tag, a second tracker, parallel
tasks, `ygg metrics` and the Harbor bridge (iteration 2 and Phase 6). The backlog items this phase
doesn't touch (decision 14). A way for an agent to read `features.json` (it is told its task in its
prompt), a planner that revises its earlier output in a fresh workspace (it gets the rejection and the
refusal as words), and a snapshot of a leaf for the services' data between runs.

## How each task lands

Every agent task ends the same way. Run the commands in the repo's folder,
`/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`:

```bash
gofmt -l .                        # prints nothing
go vet ./...
GOWORK=off go test -race ./...    # what CI runs
uvx -q --from 'reuse==5.0.2' reuse lint -q
git status --short                # then stage the task's files by path
git commit -m "<what changed> (v0-T1xx)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

When the repo's last task is committed, push and open its pull request:

```bash
../../ouroboric/scripts/as-bot.sh <repo> git push -u origin <branch>
../../ouroboric/scripts/as-bot.sh <repo> gh pr create --repo ouroboric-dev/<repo> --title "<title>" --body-file <file>
```

The PR body names the tasks, lists their acceptance criteria with their evidence (the named tests'
output), and says which earlier PRs it needs merged first. CI's `test` check must be green before the
founder merges it.

To pin a sibling, fetch it, then pin its `main`:

```bash
../../ouroboric/scripts/as-bot.sh --read all git -C ../gungnir fetch -q origin
GOWORK=off go get github.com/ouroboric-dev/gungnir@$(git -C ../gungnir rev-parse origin/main)
GOWORK=off go mod tidy
```

`gleipnir` pins `gungnir`; `jormungandr` pins `gungnir`; `odin` pins `gungnir`, `gleipnir` and
`jormungandr` (and keeps `havamal`). Until a sibling's PR is merged, develop through `yggdrasil/go.work`,
as Phase 2 to Phase 4 did, and add the pin as the last commit once it merges.

---

### Task v0-T142: a project records its lead realm, and each leaf its realm and what it consumes

Gungnir's first task. Branch `realms/contract` from `main` in `gungnir`, before step 1. Change `realm-leaf-naming` has the project decide its leaves and the realm of each. This task is where the project writes that down: in `umbrella.yaml`, beside the owner and the visibility Odin already keeps there (spec §3.1).

**Files (in `gungnir`):**
- Create: `schema/umbrella_realm_test.go`
- Modify: `schema/umbrella.go`, `schema/umbrella.schema.json`

**Interfaces:**
- Produces: `schema.Umbrella.Realm` and `RealmVersion` (the lead realm's pin, on the project's own umbrella); `schema.Child.Realm`, `RealmVersion` and `Consumes []string` (a leaf's realm pin and the sibling leaves it calls). A pin is both fields or neither.
- Produces: `schema.Pin{Realm, Version, Where string}` and `(*Umbrella).Pins() []Pin`, the lead pin (where `"."`) and then each child's, by path.
- `ParseUmbrella` refuses a realm without a version or the reverse, a realm name that is not lower case words joined by dashes, a version that is not `1.2.3`, a leaf that consumes itself, twice, a stranger or an umbrella, an umbrella that consumes, and leaves that consume each other in a ring.

**Acceptance criteria:**
- [ ] A project's `umbrella.yaml` round trips its lead pin, each leaf's pin and what a leaf consumes, through `Save` and `LoadUmbrella`.
- [ ] A leaf with no pin stays without one: it is the lead realm's.
- [ ] Every malformed pin and every bad consumer in the list above is refused.

**Named test:** `go test ./schema -run 'TestAProjectRecordsItsLeadRealmAndEachLeafsRealm|TestParseUmbrellaRefusesBadRealmPins|TestUmbrellaKeepsItsPinsWhenSaved'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (226). **Depends on:** Phase 4.

- [ ] **Step 1:** write the tests.

Write `schema/umbrella_realm_test.go`:

```go
package schema

import (
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

const gallery = `
root: true
owner: ouroboric-dev
visibility: private
realm: midgard-react
realm_version: 0.1.0
children:
  repos/api:
    kind: leaf
    owner: ouroboric-dev
    visibility: private
    realm: helheim-go
    realm_version: 0.1.0
  repos/web:
    kind: leaf
    owner: ouroboric-dev
    visibility: private
    realm: midgard-react
    realm_version: 0.1.0
    consumes: [repos/api]
  repos/legacy: { kind: leaf, owner: ouroboric-dev, visibility: private }
`

func TestAProjectRecordsItsLeadRealmAndEachLeafsRealm(t *testing.T) {
	u, err := ParseUmbrella("umbrella.yaml", []byte(gallery))
	if err != nil {
		t.Fatalf("ParseUmbrella() = %v", err)
	}
	if u.Realm != "midgard-react" || u.RealmVersion != "0.1.0" {
		t.Errorf("lead realm = %s %s", u.Realm, u.RealmVersion)
	}
	api, web, legacy := u.Children["repos/api"], u.Children["repos/web"], u.Children["repos/legacy"]
	if api.Realm != "helheim-go" || api.RealmVersion != "0.1.0" {
		t.Errorf("api = %+v", api)
	}
	if web.Realm != "midgard-react" || !slices.Equal(web.Consumes, []string{"repos/api"}) {
		t.Errorf("web = %+v", web)
	}
	if legacy.Realm != "" || legacy.RealmVersion != "" || legacy.Consumes != nil {
		t.Errorf("a leaf with no pin keeps none: %+v", legacy)
	}
	pins := u.Pins()
	want := []Pin{{"helheim-go", "0.1.0", "repos/api"}, {"midgard-react", "0.1.0", "."}, {"midgard-react", "0.1.0", "repos/web"}}
	slices.SortFunc(pins, func(a, b Pin) int { return strings.Compare(a.Realm+a.Where, b.Realm+b.Where) })
	if !slices.Equal(pins, want) {
		t.Errorf("Pins() = %+v, want %+v", pins, want)
	}
}

func TestParseUmbrellaRefusesBadRealmPins(t *testing.T) {
	head := "owner: o\nvisibility: private\nchildren:\n"
	leaf := func(extra string) string { return "  a: { kind: leaf, owner: o, visibility: private" + extra + " }\n" }
	cases := map[string]string{
		"a realm with no version":         head + leaf(", realm: midgard-react"),
		"a version with no realm":         head + leaf(", realm_version: 0.1.0"),
		"a realm name in capitals":        head + leaf(", realm: Midgard, realm_version: 0.1.0"),
		"a version that is not semver":    head + leaf(", realm: midgard-react, realm_version: v1"),
		"a lead realm with no version":    "realm: midgard-react\n" + head + leaf(""),
		"a lead version with no realm":    "realm_version: 0.1.0\n" + head + leaf(""),
		"a leaf consuming itself":         head + leaf(", consumes: [a]"),
		"a leaf consuming a stranger":     head + leaf(", consumes: [b]"),
		"a leaf consuming twice":          head + leaf(", consumes: [b, b]") + "  b: { kind: leaf, owner: o, visibility: private }\n",
		"a leaf consuming an umbrella":    head + leaf(", consumes: [u]") + "  u: { kind: umbrella, owner: o, visibility: private }\n",
		"an umbrella that consumes":       head + "  u: { kind: umbrella, owner: o, visibility: private, consumes: [a] }\n" + "  a: { kind: leaf, owner: o, visibility: private }\n",
		"two leaves consuming each other": head + leaf(", consumes: [b]") + "  b: { kind: leaf, owner: o, visibility: private, consumes: [a] }\n",
		"a ring of three":                 head + leaf(", consumes: [b]") + "  b: { kind: leaf, owner: o, visibility: private, consumes: [c] }\n  c: { kind: leaf, owner: o, visibility: private, consumes: [a] }\n",
	}
	for name, y := range cases {
		if _, err := ParseUmbrella("umbrella.yaml", []byte(y)); err == nil {
			t.Errorf("%s: ParseUmbrella() = nil error", name)
		}
	}
}

func TestUmbrellaKeepsItsPinsWhenSaved(t *testing.T) {
	dir := t.TempDir()
	u, err := ParseUmbrella("umbrella.yaml", []byte(gallery))
	if err != nil {
		t.Fatal(err)
	}
	if err := u.Save(dir); err != nil {
		t.Fatal(err)
	}
	got, err := LoadUmbrella(dir)
	if err != nil {
		t.Fatalf("LoadUmbrella() after Save = %v", err)
	}
	if got.Realm != "midgard-react" || got.Children["repos/web"].Consumes[0] != "repos/api" || got.Children["repos/api"].Visibility != gungnir.VisibilityPrivate {
		t.Errorf("round trip lost the pins: %+v", got)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/umbrella_realm_test.go:39:7: u.Realm undefined (type *Umbrella has no field or method Realm)
schema/umbrella_realm_test.go:39:37: u.RealmVersion undefined (type *Umbrella has no field or method RealmVersion)
schema/umbrella_realm_test.go:40:36: u.Realm undefined (type *Umbrella has no field or method Realm)
```

- [ ] **Step 3:** write the code.

Apply to `schema/umbrella.go`:

```diff
diff --git a/schema/umbrella.go b/schema/umbrella.go
index cf2ad54..b918ab4 100644
--- a/schema/umbrella.go
+++ b/schema/umbrella.go
@@ -5,6 +5,7 @@ import (
 	"fmt"
 	"os"
 	"path/filepath"
+	"regexp"
 	"strings"
 
 	"github.com/ouroboric-dev/gungnir"
@@ -17,7 +18,11 @@ type Umbrella struct {
 	Root       bool               `yaml:"root,omitempty"` // the top of the tree: a project, or a company umbrella holding projects
 	Owner      string             `yaml:"owner"`
 	Visibility gungnir.Visibility `yaml:"visibility"`
-	Children   map[string]Child   `yaml:"children,omitempty"` // path relative to the umbrella: child
+	// Realm and RealmVersion pin the lead realm of the project this umbrella is: the realm leaf whose
+	// graph builds it (change realm-leaf-naming). Both are set, or neither.
+	Realm        string           `yaml:"realm,omitempty"`
+	RealmVersion string           `yaml:"realm_version,omitempty"`
+	Children     map[string]Child `yaml:"children,omitempty"` // path relative to the umbrella: child
 }
 
 // ChildKind is what a child node is.
@@ -33,6 +38,14 @@ type Child struct {
 	Kind       ChildKind          `yaml:"kind"`
 	Owner      string             `yaml:"owner"`
 	Visibility gungnir.Visibility `yaml:"visibility"`
+	// Realm and RealmVersion pin the realm leaf that provides this leaf's recipe: its stack layer,
+	// templates, implementer prompt and checks. Both are set, or neither; a leaf with neither uses the
+	// project's lead realm.
+	Realm        string `yaml:"realm,omitempty"`
+	RealmVersion string `yaml:"realm_version,omitempty"`
+	// Consumes lists the sibling leaves this leaf calls, such as a web leaf's api. A leaf's sandbox gets
+	// the services of the realms of the leaves it consumes (spec §6.1, §9.2).
+	Consumes []string `yaml:"consumes,omitempty"`
 }
 
 // UmbrellaFile is the name of an umbrella's metadata file.
@@ -67,9 +80,114 @@ func ParseUmbrella(file string, data []byte) (*Umbrella, error) {
 	if u.Children == nil { // an umbrella with no children yet; Odin adds to the map
 		u.Children = map[string]Child{}
 	}
+	if err := u.checkRealms(file); err != nil {
+		return nil, err
+	}
 	return &u, nil
 }
 
+// checkRealms checks the realm pins and the consumers: a pin is a realm name and a version, together;
+// a leaf consumes other leaves of the umbrella, each once, and never in a ring.
+func (u *Umbrella) checkRealms(file string) error {
+	if err := checkPin(file, "the umbrella", u.Realm, u.RealmVersion); err != nil {
+		return err
+	}
+	for _, p := range u.Paths() {
+		c := u.Children[p]
+		if err := checkPin(file, "child "+p, c.Realm, c.RealmVersion); err != nil {
+			return err
+		}
+		if len(c.Consumes) > 0 && c.Kind != ChildLeaf {
+			return fmt.Errorf("%s: child %s is an umbrella, and only a leaf consumes other leaves", file, p)
+		}
+		seen := map[string]bool{}
+		for _, q := range c.Consumes {
+			switch other, ok := u.Children[q]; {
+			case q == p:
+				return fmt.Errorf("%s: child %s consumes itself", file, p)
+			case !ok || other.Kind != ChildLeaf:
+				return fmt.Errorf("%s: child %s consumes %q, which is not a leaf of this umbrella", file, p, q)
+			case seen[q]:
+				return fmt.Errorf("%s: child %s consumes %s twice", file, p, q)
+			}
+			seen[q] = true
+		}
+	}
+	return u.checkRing(file)
+}
+
+// checkRing refuses leaves that consume each other, directly or through others.
+func (u *Umbrella) checkRing(file string) error {
+	state := map[string]int{} // 1: on the path being walked, 2: done
+	var walk func(p string, path []string) error
+	walk = func(p string, path []string) error {
+		switch state[p] {
+		case 1:
+			return fmt.Errorf("%s: leaves consume each other in a ring: %s", file, strings.Join(append(path, p), " -> "))
+		case 2:
+			return nil
+		}
+		state[p] = 1
+		for _, q := range u.Children[p].Consumes {
+			if err := walk(q, append(path, p)); err != nil {
+				return err
+			}
+		}
+		state[p] = 2
+		return nil
+	}
+	for _, p := range u.Paths() {
+		if err := walk(p, nil); err != nil {
+			return err
+		}
+	}
+	return nil
+}
+
+var (
+	realmName    = regexp.MustCompile(`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`)
+	realmVersion = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`)
+)
+
+// ValidRealm reports whether s names a realm leaf: lower case, with dashes between words.
+func ValidRealm(s string) bool { return realmName.MatchString(s) }
+
+// ValidVersion reports whether s is a version of the form 1.2.3.
+func ValidVersion(s string) bool { return realmVersion.MatchString(s) }
+
+// checkPin checks that a realm and its version are both set or both empty, and well formed.
+func checkPin(file, where, realm, version string) error {
+	switch {
+	case realm == "" && version == "":
+		return nil
+	case realm == "" || version == "":
+		return fmt.Errorf("%s: %s sets a realm or a realm version without the other; a pin is both", file, where)
+	case !ValidRealm(realm):
+		return fmt.Errorf("%s: %s: realm %q is not a realm name (lower case words joined by dashes)", file, where, realm)
+	case !ValidVersion(version):
+		return fmt.Errorf("%s: %s: realm version %q is not a version such as 1.2.3", file, where, version)
+	}
+	return nil
+}
+
+// Pin is a realm leaf at a version, and where the umbrella pins it: "." for the umbrella itself, or
+// a child's path.
+type Pin struct{ Realm, Version, Where string }
+
+// Pins returns every realm pin of the umbrella: its own lead realm, then each child's, by path.
+func (u *Umbrella) Pins() []Pin {
+	var pins []Pin
+	if u.Realm != "" {
+		pins = append(pins, Pin{u.Realm, u.RealmVersion, "."})
+	}
+	for _, p := range u.Paths() {
+		if c := u.Children[p]; c.Realm != "" {
+			pins = append(pins, Pin{c.Realm, c.RealmVersion, p})
+		}
+	}
+	return pins
+}
+
 // Paths returns the child paths, sorted.
 func (u *Umbrella) Paths() []string { return sortedKeys(u.Children) }
 
```

Apply to `schema/umbrella.schema.json`:

```diff
diff --git a/schema/umbrella.schema.json b/schema/umbrella.schema.json
index b7fde74..8182cb2 100644
--- a/schema/umbrella.schema.json
+++ b/schema/umbrella.schema.json
@@ -10,6 +10,8 @@
     "root": { "type": "boolean" },
     "owner": { "$ref": "#/$defs/owner" },
     "visibility": { "$ref": "#/$defs/visibility" },
+    "realm": { "type": "string" },
+    "realm_version": { "type": "string" },
     "children": {
       "type": "object",
       "propertyNames": { "pattern": "^[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)*$" },
@@ -20,7 +22,10 @@
         "properties": {
           "kind": { "enum": ["umbrella", "leaf"] },
           "owner": { "$ref": "#/$defs/owner" },
-          "visibility": { "$ref": "#/$defs/visibility" }
+          "visibility": { "$ref": "#/$defs/visibility" },
+          "realm": { "type": "string" },
+          "realm_version": { "type": "string" },
+          "consumes": { "type": "array", "items": { "type": "string", "minLength": 1 } }
         }
       }
     }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T143: realm names and versions are checked in one place, and a repo a remote creates carries its pin

A remote that creates a leaf must record its pin in the same commit, or a leaf could exist without it (backlog B-003 is the warning). The checks of a pin move to the root package, where `Repo` lives.

**Files (in `gungnir`):**
- Create: `realm.go`, `realm_test.go`
- Modify: `remote.go`, `schema/umbrella.go`

**Interfaces:**
- Produces: `gungnir.ValidRealm(string) bool` and `gungnir.ValidVersion(string) bool`; `schema.ValidRealm` and `schema.ValidVersion` go (the umbrella uses these).
- Produces: `gungnir.Repo.Realm`, `RealmVersion` and `Consumes []string`; `Repo.Validate` refuses half a pin, a bad name or version, a consumer path that climbs, one listed twice, and the repo itself.

**Acceptance criteria:**
- [ ] `ValidRealm` and `ValidVersion` accept the names and versions of the realms and refuse capitals, dots, double dashes, a leading digit or dash, and a version with a prefix or a suffix.
- [ ] A `Repo` with a pin and consumers validates; each of the malformed forms above is refused; a repo with no pin still validates.

**Named test:** `go test . -run 'TestValidRealmAndVersion|TestARepoCarriesItsRealmPin'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (100). **Depends on:** v0-T142.

- [ ] **Step 1:** write the tests.

Write `realm_test.go`:

```go
package gungnir

import "testing"

func TestValidRealmAndVersion(t *testing.T) {
	for _, s := range []string{"midgard-react", "helheim-go", "asgard", "midgard-react2"} {
		if !ValidRealm(s) {
			t.Errorf("ValidRealm(%q) = false", s)
		}
	}
	for _, s := range []string{"", "Midgard", "midgard_react", "-midgard", "midgard-", "midgard--react", "2fast", "midgard react", "../x"} {
		if ValidRealm(s) {
			t.Errorf("ValidRealm(%q) = true", s)
		}
	}
	for _, s := range []string{"0.1.0", "12.0.103"} {
		if !ValidVersion(s) {
			t.Errorf("ValidVersion(%q) = false", s)
		}
	}
	for _, s := range []string{"", "1", "1.2", "v1.2.3", "1.2.3-rc1", "1.2.3.4", "1.x.3"} {
		if ValidVersion(s) {
			t.Errorf("ValidVersion(%q) = true", s)
		}
	}
}

func TestARepoCarriesItsRealmPin(t *testing.T) {
	ok := Repo{Owner: "o", Name: "api", Visibility: VisibilityPrivate, Path: "repos/api", Files: map[string][]byte{"LICENSE": []byte("x")},
		Realm: "helheim-go", RealmVersion: "0.1.0", Consumes: []string{"repos/db"}}
	if err := ok.Validate(); err != nil {
		t.Fatalf("Validate() = %v", err)
	}
	for name, mutate := range map[string]func(*Repo){
		"a realm with no version":     func(r *Repo) { r.RealmVersion = "" },
		"a version with no realm":     func(r *Repo) { r.Realm = "" },
		"a bad realm name":            func(r *Repo) { r.Realm = "Helheim Go" },
		"a bad version":               func(r *Repo) { r.RealmVersion = "latest" },
		"a consumer path that climbs": func(r *Repo) { r.Consumes = []string{"../x"} },
		"a consumer listed twice":     func(r *Repo) { r.Consumes = []string{"repos/db", "repos/db"} },
		"itself as a consumer":        func(r *Repo) { r.Consumes = []string{"repos/api"} },
	} {
		r := ok
		r.Consumes = append([]string(nil), ok.Consumes...)
		mutate(&r)
		if r.Validate() == nil {
			t.Errorf("%s: Validate() = nil", name)
		}
	}
	plain := ok
	plain.Realm, plain.RealmVersion, plain.Consumes = "", "", nil
	if err := plain.Validate(); err != nil {
		t.Errorf("a repo with no pin = %v; it uses the lead realm", err)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./realm_test.go:7:7: undefined: ValidRealm
./realm_test.go:12:6: undefined: ValidRealm
./realm_test.go:17:7: undefined: ValidVersion
```

- [ ] **Step 3:** write the code.

Write `realm.go`:

```go
package gungnir

import "regexp"

var (
	realmName    = regexp.MustCompile(`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`)
	realmVersion = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`)
)

// ValidRealm reports whether s names a realm leaf: lower case words joined by dashes, such as
// midgard-react (change realm-leaf-naming).
func ValidRealm(s string) bool { return realmName.MatchString(s) }

// ValidVersion reports whether s is a version of the form 1.2.3.
func ValidVersion(s string) bool { return realmVersion.MatchString(s) }
```

Apply to `remote.go`:

```diff
diff --git a/remote.go b/remote.go
index 5ef3ed4..8fefbdd 100644
--- a/remote.go
+++ b/remote.go
@@ -39,6 +39,13 @@ type Repo struct {
 	Description string            // one line
 	Path        string            // where its working copy goes, relative to its parent umbrella
 	Files       map[string][]byte // the first commit: path in the repo to content
+	// Realm and RealmVersion pin the realm leaf that provides the new leaf's recipe, and Consumes lists
+	// the sibling leaves it calls (paths from the parent umbrella). A remote records them with the
+	// leaf, in the same step, so a leaf never exists without its pin. A Repo with none uses the
+	// project's lead realm.
+	Realm        string
+	RealmVersion string
+	Consumes     []string
 }
 
 var repoName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)
@@ -66,5 +73,26 @@ func (r Repo) Validate() error {
 			errs = append(errs, fmt.Errorf("first-commit file %q must be a relative path outside .git", p))
 		}
 	}
+	switch {
+	case r.Realm == "" && r.RealmVersion == "":
+	case r.Realm == "" || r.RealmVersion == "":
+		errs = append(errs, errors.New("a realm pin is a realm and its version, together"))
+	case !ValidRealm(r.Realm):
+		errs = append(errs, fmt.Errorf("realm %q is not a realm name", r.Realm))
+	case !ValidVersion(r.RealmVersion):
+		errs = append(errs, fmt.Errorf("realm version %q is not a version such as 1.2.3", r.RealmVersion))
+	}
+	seen := map[string]bool{}
+	for _, c := range r.Consumes {
+		switch {
+		case !filepath.IsLocal(c):
+			errs = append(errs, fmt.Errorf("consumed leaf %q must be a relative path inside the parent umbrella", c))
+		case c == r.Path:
+			errs = append(errs, fmt.Errorf("leaf %s can't consume itself", c))
+		case seen[c]:
+			errs = append(errs, fmt.Errorf("consumed leaf %s is listed twice", c))
+		}
+		seen[c] = true
+	}
 	return errors.Join(errs...)
 }
```

Apply to `schema/umbrella.go`:

```diff
diff --git a/schema/umbrella.go b/schema/umbrella.go
index b918ab4..05f5e1b 100644
--- a/schema/umbrella.go
+++ b/schema/umbrella.go
@@ -5,7 +5,6 @@ import (
 	"fmt"
 	"os"
 	"path/filepath"
-	"regexp"
 	"strings"
 
 	"github.com/ouroboric-dev/gungnir"
@@ -144,17 +143,6 @@ func (u *Umbrella) checkRing(file string) error {
 	return nil
 }
 
-var (
-	realmName    = regexp.MustCompile(`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`)
-	realmVersion = regexp.MustCompile(`^[0-9]+\.[0-9]+\.[0-9]+$`)
-)
-
-// ValidRealm reports whether s names a realm leaf: lower case, with dashes between words.
-func ValidRealm(s string) bool { return realmName.MatchString(s) }
-
-// ValidVersion reports whether s is a version of the form 1.2.3.
-func ValidVersion(s string) bool { return realmVersion.MatchString(s) }
-
 // checkPin checks that a realm and its version are both set or both empty, and well formed.
 func checkPin(file, where, realm, version string) error {
 	switch {
@@ -162,9 +150,9 @@ func checkPin(file, where, realm, version string) error {
 		return nil
 	case realm == "" || version == "":
 		return fmt.Errorf("%s: %s sets a realm or a realm version without the other; a pin is both", file, where)
-	case !ValidRealm(realm):
+	case !gungnir.ValidRealm(realm):
 		return fmt.Errorf("%s: %s: realm %q is not a realm name (lower case words joined by dashes)", file, where, realm)
-	case !ValidVersion(version):
+	case !gungnir.ValidVersion(version):
 		return fmt.Errorf("%s: %s: realm version %q is not a version such as 1.2.3", file, where, version)
 	}
 	return nil
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T144: a sandbox spec names its stack and services, and may hold a scratch folder instead of a leaf

Spec §6.1: a leaf's sandbox gets the stack layer of its realm and the services of its realm and of the leaves it consumes (§9.2). A planner works in a scratch folder, not a leaf (§3.3 rule 1). Both are in the sandbox spec Odin hands the driver.

**Files (in `gungnir`):**
- Create: `sandbox_services_test.go`
- Modify: `sandbox.go`

**Interfaces:**
- Produces: `SandboxSpec.Stack` (an image pinned by digest; empty means the driver's own), `Services []Service` and `Scratch bool`; `Service{Name, Image string; Env map[string]string; Ports []int}`; `MaxServices` (8); `ValidImage(string) bool`; `ValidateServices([]Service) error`.
- `SandboxSpec.Validate` accepts a scratch spec with no git dir and refuses one with a git dir; it refuses a leaf spec with none. `Layout()` of a scratch spec has no git dir.
- `ValidateServices` refuses a name that is not lower case words, `work` and `fw`, a name twice, an image without a digest, no port or a port out of range or twice, an env name that is empty or holds `=`, an env name that names a credential (`PASSWORD`, `TOKEN`, `SECRET`, `API_KEY`, `CREDENTIAL`), and nine services.

**Acceptance criteria:**
- [ ] A spec with a stack and two services validates, and so does one with eight.
- [ ] Each refusal in the list above is a test case.
- [ ] A scratch spec validates only without a git dir, and its layout names only the folder.

**Named test:** `go test . -run 'TestASandboxSpecMayCarryAStackAndServices|TestAScratchSandboxHoldsOneFolderAndNoGitDir|TestValidImagePinsByDigest'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (186). **Depends on:** v0-T143.

- [ ] **Step 1:** write the tests.

Write `sandbox_services_test.go`:

```go
package gungnir

import (
	"slices"
	"testing"
)

const pg = "docker.io/library/postgres:17.2@sha256:1111111111111111111111111111111111111111111111111111111111111111"

func specWithServices() SandboxSpec {
	s := validSpec()
	s.Stack = "docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514"
	s.Services = []Service{{Name: "postgres", Image: pg, Env: map[string]string{"POSTGRES_DB": "app"}, Ports: []int{5432}}}
	return s
}

func TestASandboxSpecMayCarryAStackAndServices(t *testing.T) {
	if err := specWithServices().Validate(); err != nil {
		t.Fatalf("Validate() = %v", err)
	}
	bad := map[string]func(*SandboxSpec){
		"a stack with no digest":         func(s *SandboxSpec) { s.Stack = "docker.io/library/golang:1.26.7" },
		"a service with no digest":       func(s *SandboxSpec) { s.Services[0].Image = "docker.io/library/postgres:17.2" },
		"a service named work":           func(s *SandboxSpec) { s.Services[0].Name = "work" },
		"a service named fw":             func(s *SandboxSpec) { s.Services[0].Name = "fw" },
		"a service name in capitals":     func(s *SandboxSpec) { s.Services[0].Name = "Postgres" },
		"a service twice":                func(s *SandboxSpec) { s.Services = append(s.Services, s.Services[0]) },
		"a service with no port":         func(s *SandboxSpec) { s.Services[0].Ports = nil },
		"a port out of range":            func(s *SandboxSpec) { s.Services[0].Ports = []int{70000} },
		"a port twice":                   func(s *SandboxSpec) { s.Services[0].Ports = []int{5432, 5432} },
		"an env name with an equals":     func(s *SandboxSpec) { s.Services[0].Env = map[string]string{"A=B": "c"} },
		"an empty env name":              func(s *SandboxSpec) { s.Services[0].Env = map[string]string{"": "c"} },
		"an env that names a credential": func(s *SandboxSpec) { s.Services[0].Env = map[string]string{"POSTGRES_PASSWORD": "dev"} },
		"nine services":                  func(s *SandboxSpec) { s.Services = manyServices(9) },
	}
	for name, change := range bad {
		s := specWithServices()
		s.Services = slices.Clone(s.Services)
		change(&s)
		if err := s.Validate(); err == nil {
			t.Errorf("%s: Validate() = nil, want an error", name)
		}
	}
	if err := func() error { s := specWithServices(); s.Services = manyServices(8); return s.Validate() }(); err != nil {
		t.Errorf("eight services = %v", err)
	}
}

func manyServices(n int) []Service {
	var out []Service
	for i := 0; i < n; i++ {
		out = append(out, Service{Name: "svc" + string(rune('a'+i)), Image: pg, Ports: []int{8000 + i}})
	}
	return out
}

func TestAScratchSandboxHoldsOneFolderAndNoGitDir(t *testing.T) {
	s := SandboxSpec{Run: "20261016-101500-a1b2c3", Name: "scratch/design", Scratch: true,
		Parent: "/work/project/.factory/runs/r1", Leaf: "/work/project/.factory/runs/r1/scratch/design"}
	if err := s.Validate(); err != nil {
		t.Fatalf("Validate() = %v", err)
	}
	if l := s.Layout(); l.Leaf != "scratch/design" || l.GitDir != "" {
		t.Errorf("Layout() = %+v", l)
	}
	for name, change := range map[string]func(*SandboxSpec){
		"a git dir":                   func(s *SandboxSpec) { s.GitDir = "/work/project/.git/modules/x" },
		"a folder outside the parent": func(s *SandboxSpec) { s.Leaf = "/elsewhere" },
		"a relative folder":           func(s *SandboxSpec) { s.Leaf = "scratch/design" },
	} {
		c := s
		change(&c)
		if c.Validate() == nil {
			t.Errorf("%s: Validate() = nil", name)
		}
	}
	notScratch := validSpec()
	notScratch.GitDir = ""
	if notScratch.Validate() == nil {
		t.Error("a leaf sandbox with no git dir validated")
	}
}

func TestValidImagePinsByDigest(t *testing.T) {
	for img, want := range map[string]bool{
		pg: true, "ghcr.io/x/y@sha256:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789": true,
		"postgres:17": false, "": false, "docker.io/library/postgres@sha256:short": false, "Docker.io/x@sha256:" + "1111111111111111111111111111111111111111111111111111111111111111": false,
	} {
		if got := ValidImage(img); got != want {
			t.Errorf("ValidImage(%q) = %v, want %v", img, got, want)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./sandbox_services_test.go:12:4: s.Stack undefined (type SandboxSpec has no field or method Stack)
./sandbox_services_test.go:13:4: s.Services undefined (type SandboxSpec has no field or method Services)
./sandbox_services_test.go:13:17: undefined: Service
```

- [ ] **Step 3:** write the code.

Apply to `sandbox.go`:

```diff
diff --git a/sandbox.go b/sandbox.go
index 8b24c83..c84d353 100644
--- a/sandbox.go
+++ b/sandbox.go
@@ -29,10 +29,41 @@ type SandboxSpec struct {
 	Name   string   // the leaf's path from the project, such as "repos/app"
 	Parent string   // the leaf's parent umbrella: the sandbox mirrors its layout
 	Leaf   string   // the leaf's working copy: mounted read-write
-	GitDir string   // the leaf's git dir, inside Parent/.git/modules: mounted read-only
+	GitDir string   // the leaf's git dir, inside Parent/.git/modules: mounted read-only; empty for a scratch folder
 	Egress []string // host names the firewall opens on port 443, besides DNS
+	// Stack is the image of the stack layer of the realm that provides this leaf, pinned by digest.
+	// Empty means the driver's own images. A run with several realms starts leaves with different
+	// stacks.
+	Stack string
+	// Services are the containers the leaf's sandbox starts beside the work container, such as a
+	// database: the services of the leaf's realm, and of each leaf it consumes (spec §6.1).
+	Services []Service
+	// Scratch makes the sandbox hold one plain folder, not a leaf: a planner's workspace (spec §3.3).
+	// It has no git dir.
+	Scratch bool
 }
 
+// Service is a container that runs beside the work container.
+type Service struct {
+	Name  string            // the compose service name, and the host name the work container reaches it by
+	Image string            // pinned by digest
+	Env   map[string]string // the service's environment: made-up development values, never a secret
+	Ports []int             // the TCP ports the work container may reach; the firewall opens these and no others
+}
+
+// MaxServices is how many services one sandbox may start.
+const MaxServices = 8
+
+var (
+	image       = regexp.MustCompile(`^[a-z0-9][a-z0-9./_-]*(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$`)
+	serviceName = regexp.MustCompile(`^[a-z][a-z0-9-]*$`)
+	secretName  = regexp.MustCompile(`(?i)(API_?KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL)`)
+)
+
+// ValidImage reports whether ref is an image reference pinned by digest: a pull can only ever give the
+// image that was reviewed.
+func ValidImage(ref string) bool { return image.MatchString(ref) }
+
 var (
 	runID    = regexp.MustCompile(`^[a-z0-9][a-z0-9-]*$`)
 	hostName = regexp.MustCompile(`^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]([a-z0-9-]*[a-z0-9])?$`)
@@ -51,7 +82,14 @@ func (s SandboxSpec) Validate() error {
 	if !filepath.IsLocal(s.Name) {
 		errs = append(errs, fmt.Errorf("name %q must be a path inside the project", s.Name))
 	}
-	for what, p := range map[string]string{"parent": s.Parent, "leaf": s.Leaf, "git dir": s.GitDir} {
+	paths := map[string]string{"parent": s.Parent, "leaf": s.Leaf}
+	switch {
+	case s.Scratch && s.GitDir != "":
+		errs = append(errs, fmt.Errorf("a scratch sandbox holds no git dir, but %q is given", s.GitDir))
+	case !s.Scratch:
+		paths["git dir"] = s.GitDir
+	}
+	for what, p := range paths {
 		if !filepath.IsAbs(p) {
 			errs = append(errs, fmt.Errorf("%s %q must be an absolute path", what, p))
 		}
@@ -62,15 +100,62 @@ func (s SandboxSpec) Validate() error {
 	if rel, err := filepath.Rel(s.Parent, s.Leaf); err != nil || !filepath.IsLocal(rel) {
 		errs = append(errs, fmt.Errorf("leaf %q is not inside the parent umbrella %q", s.Leaf, s.Parent))
 	}
-	if rel, err := filepath.Rel(filepath.Join(s.Parent, ".git", "modules"), s.GitDir); err != nil || !filepath.IsLocal(rel) {
-		errs = append(errs, fmt.Errorf("git dir %q is not inside %s", s.GitDir, filepath.Join(s.Parent, ".git", "modules")))
+	if !s.Scratch {
+		if rel, err := filepath.Rel(filepath.Join(s.Parent, ".git", "modules"), s.GitDir); err != nil || !filepath.IsLocal(rel) {
+			errs = append(errs, fmt.Errorf("git dir %q is not inside %s", s.GitDir, filepath.Join(s.Parent, ".git", "modules")))
+		}
 	}
 	for _, h := range s.Egress {
 		if !ValidHost(h) {
 			errs = append(errs, fmt.Errorf("egress %q is not a plain host name (no scheme, port, wildcard or address)", h))
 		}
 	}
-	return errors.Join(errs...)
+	if s.Stack != "" && !ValidImage(s.Stack) {
+		errs = append(errs, fmt.Errorf("stack %q is not an image pinned by digest", s.Stack))
+	}
+	return errors.Join(append(errs, s.checkServices()...)...)
+}
+
+// checkServices refuses services the driver could not start exactly as described.
+func (s SandboxSpec) checkServices() []error {
+	var errs []error
+	if len(s.Services) > MaxServices {
+		errs = append(errs, fmt.Errorf("%d services; a sandbox starts at most %d", len(s.Services), MaxServices))
+	}
+	seen := map[string]bool{}
+	for _, v := range s.Services {
+		switch {
+		case !serviceName.MatchString(v.Name):
+			errs = append(errs, fmt.Errorf("service name %q must be lower case words joined by dashes", v.Name))
+		case v.Name == "work" || v.Name == "fw":
+			errs = append(errs, fmt.Errorf("service name %q is taken by the sandbox's own containers", v.Name))
+		case seen[v.Name]:
+			errs = append(errs, fmt.Errorf("service %s is listed twice", v.Name))
+		}
+		seen[v.Name] = true
+		if !ValidImage(v.Image) {
+			errs = append(errs, fmt.Errorf("service %s: image %q is not pinned by digest", v.Name, v.Image))
+		}
+		if len(v.Ports) == 0 {
+			errs = append(errs, fmt.Errorf("service %s names no port, so the work container could not reach it", v.Name))
+		}
+		ports := map[int]bool{}
+		for _, p := range v.Ports {
+			if p < 1 || p > 65535 || ports[p] {
+				errs = append(errs, fmt.Errorf("service %s: port %d is out of range or listed twice", v.Name, p))
+			}
+			ports[p] = true
+		}
+		for k := range v.Env {
+			switch {
+			case k == "" || strings.ContainsAny(k, "=\x00"):
+				errs = append(errs, fmt.Errorf("service %s: env name %q is not a variable name", v.Name, k))
+			case secretName.MatchString(k):
+				errs = append(errs, fmt.Errorf("service %s: env %s names a credential; a service in a sandbox takes none (use the image's mode without a password)", v.Name, k))
+			}
+		}
+	}
+	return errs
 }
 
 // Layout holds where the sandbox mounts the leaf and its git dir, relative to the sandbox's root:
@@ -80,6 +165,9 @@ type Layout struct{ Leaf, GitDir string }
 // Layout returns the mirrored layout of a valid spec.
 func (s SandboxSpec) Layout() Layout {
 	leaf, _ := filepath.Rel(s.Parent, s.Leaf)
+	if s.Scratch {
+		return Layout{Leaf: filepath.ToSlash(leaf)}
+	}
 	git, _ := filepath.Rel(s.Parent, s.GitDir)
 	return Layout{Leaf: filepath.ToSlash(leaf), GitDir: filepath.ToSlash(git)}
 }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T145: a build realm's pack offers a leaf recipe and services under standard names, and a realm may have no graph

Change `realm-leaf-naming` says every build realm offers the same roles under standard names, which the graph names and Odin resolves in the realm of the task's leaf. A realm that is only a backend has no graph, and backlog B-036 says a realm may have no leaves and no stack at all.

**Files (in `gungnir`):**
- Create: `schema/pack_recipe_test.go`
- Modify: `sandbox.go`, `schema/pack.go`, `schema/pack.schema.json`

**Interfaces:**
- Produces: `schema.Pack.Leaf *PackRecipe{Description, Template, FirstCommit []string; Implementer string; Checks []string}`, the recipe; `Pack.Services map[string]PackService{Image; Env; Ports}`; `(*Pack).ServiceList() []gungnir.Service`, sorted by name. `Pack.Graph` is optional.
- `LoadPack` refuses a template that is not a folder of the realm, a first-commit file that is not a regular file of the template, an implementer that is not a regular file of the realm, no checks, a check the pack does not define, a check twice, and every service `ValidateServices` refuses.
- The pack's `leaves:` map stays, as the default leaves of a lead realm's own graph (decision 3).

**Acceptance criteria:**
- [ ] A pack with a recipe, services and no graph loads; a pack with none of those loads too (a documents realm, B-036).
- [ ] Each refusal above is a test case.
- [ ] The older tests of `LoadPack` and `leaves:` still pass.

**Named test:** `go test ./schema -run 'TestARealmWithoutAGraphOffersARecipeAndServices|TestLoadPackRefusesABadRecipe|TestLoadPack'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (214). **Depends on:** v0-T144.

- [ ] **Step 1:** write the tests.

Write `schema/pack_recipe_test.go`:

```go
package schema

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

const pgImage = "docker.io/library/postgres:17.2@sha256:1111111111111111111111111111111111111111111111111111111111111111"

// recipeRealm writes a realm folder with a template, an implementer prompt and the given pack.yaml.
func recipeRealm(t *testing.T, pack string) string {
	t.Helper()
	dir := t.TempDir()
	for f, body := range map[string]string{
		"templates/api/LICENSE": "licence\n", "templates/api/AGENTS.md": "rules\n", "prompts/implementer.md": "Build the task.\n", "pack.yaml": pack,
	} {
		if err := os.MkdirAll(filepath.Dir(filepath.Join(dir, f)), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, f), []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

const recipe = `name: helheim-go
version: 0.1.0
checks:
  lint: [go, vet, ./...]
  unit: [go, test, ./...]
leaf:
  description: the api
  template: templates/api
  first_commit: [LICENSE]
  implementer: prompts/implementer.md
  checks: [lint, unit]
services:
  postgres:
    image: ` + pgImage + `
    env: { POSTGRES_DB: app }
    ports: [5432]
`

func TestARealmWithoutAGraphOffersARecipeAndServices(t *testing.T) {
	p, err := LoadPack(recipeRealm(t, recipe))
	if err != nil {
		t.Fatalf("LoadPack() = %v", err)
	}
	if p.Graph != "" {
		t.Errorf("Graph = %q; a realm that doesn't lead has none", p.Graph)
	}
	r := p.Leaf
	if r == nil || r.Template != "templates/api" || r.Implementer != "prompts/implementer.md" || !slices.Equal(r.Checks, []string{"lint", "unit"}) {
		t.Fatalf("Leaf = %+v", r)
	}
	want := []gungnir.Service{{Name: "postgres", Image: pgImage, Env: map[string]string{"POSTGRES_DB": "app"}, Ports: []int{5432}}}
	if got := p.ServiceList(); len(got) != 1 || got[0].Name != want[0].Name || got[0].Image != pgImage || got[0].Ports[0] != 5432 || got[0].Env["POSTGRES_DB"] != "app" {
		t.Errorf("ServiceList() = %+v", got)
	}
	if p, err := LoadPack(recipeRealm(t, "name: notes\nversion: 0.1.0\n")); err != nil || p.Leaf != nil || len(p.ServiceList()) != 0 {
		t.Errorf("a realm with no leaf recipe, no graph and no stack (a documents realm) = %+v, %v", p, err)
	}
}

func TestLoadPackRefusesABadRecipe(t *testing.T) {
	swap := func(old, new string) string { return strings.Replace(recipe, old, new, 1) }
	cases := map[string]string{
		"a template outside the realm":      swap("template: templates/api", "template: ../api"),
		"a template that is not there":      swap("template: templates/api", "template: templates/web"),
		"a first file that is not there":    swap("first_commit: [LICENSE]", "first_commit: [NOTICE]"),
		"no implementer prompt":             swap("  implementer: prompts/implementer.md\n", ""),
		"an implementer outside the realm":  swap("prompts/implementer.md", "../implementer.md"),
		"an implementer that is not there":  swap("implementer: prompts/implementer.md", "implementer: prompts/other.md"),
		"no checks":                         swap("  checks: [lint, unit]\n", ""),
		"a check the pack doesn't define":   swap("checks: [lint, unit]", "checks: [lint, e2e]"),
		"a check twice":                     swap("checks: [lint, unit]", "checks: [lint, lint]"),
		"a service image without a digest":  swap(pgImage, "docker.io/library/postgres:17.2"),
		"a service with no port":            swap("    ports: [5432]\n", ""),
		"a service named work":              swap("  postgres:", "  work:"),
		"a service env name with an equals": swap("{ POSTGRES_DB: app }", "{ A=B: app }"),
		"a recipe field nobody knows":       swap("  description: the api\n", "  description: the api\n  hooks: [x]\n"),
	}
	for name, y := range cases {
		if _, err := LoadPack(recipeRealm(t, y)); err == nil {
			t.Errorf("%s: LoadPack() = nil error", name)
		} else if strings.Contains(err.Error(), "yaml:") && !strings.Contains(err.Error(), "pack.yaml") {
			t.Errorf("%s: %v", name, err)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/pack_recipe_test.go:58:9: p.Leaf undefined (type *Pack has no field or method Leaf)
schema/pack_recipe_test.go:63:14: p.ServiceList undefined (type *Pack has no field or method ServiceList)
schema/pack_recipe_test.go:66:90: p.Leaf undefined (type *Pack has no field or method Leaf)
```

- [ ] **Step 3:** write the code.

Apply to `sandbox.go`:

```diff
diff --git a/sandbox.go b/sandbox.go
index c84d353..262f87e 100644
--- a/sandbox.go
+++ b/sandbox.go
@@ -113,17 +113,17 @@ func (s SandboxSpec) Validate() error {
 	if s.Stack != "" && !ValidImage(s.Stack) {
 		errs = append(errs, fmt.Errorf("stack %q is not an image pinned by digest", s.Stack))
 	}
-	return errors.Join(append(errs, s.checkServices()...)...)
+	return errors.Join(append(errs, ValidateServices(s.Services))...)
 }
 
-// checkServices refuses services the driver could not start exactly as described.
-func (s SandboxSpec) checkServices() []error {
+// ValidateServices refuses services a driver could not start exactly as described.
+func ValidateServices(services []Service) error {
 	var errs []error
-	if len(s.Services) > MaxServices {
-		errs = append(errs, fmt.Errorf("%d services; a sandbox starts at most %d", len(s.Services), MaxServices))
+	if len(services) > MaxServices {
+		errs = append(errs, fmt.Errorf("%d services; a sandbox starts at most %d", len(services), MaxServices))
 	}
 	seen := map[string]bool{}
-	for _, v := range s.Services {
+	for _, v := range services {
 		switch {
 		case !serviceName.MatchString(v.Name):
 			errs = append(errs, fmt.Errorf("service name %q must be lower case words joined by dashes", v.Name))
@@ -155,7 +155,7 @@ func (s SandboxSpec) checkServices() []error {
 			}
 		}
 	}
-	return errs
+	return errors.Join(errs...)
 }
 
 // Layout holds where the sandbox mounts the leaf and its git dir, relative to the sandbox's root:
```

Apply to `schema/pack.go`:

```diff
diff --git a/schema/pack.go b/schema/pack.go
index 7d5be03..e246024 100644
--- a/schema/pack.go
+++ b/schema/pack.go
@@ -12,11 +12,46 @@ import (
 type Pack struct {
 	Name    string              `yaml:"name"`
 	Version string              `yaml:"version"`
-	Graph   string              `yaml:"graph"`   // relative to the pack
+	Graph   string              `yaml:"graph"`   // relative to the pack; empty for a realm that never leads a run
 	Roles   map[string]PackRole `yaml:"roles"`   // default roles; factory.yaml's roles are used from Phase 1
 	Checks  map[string][]string `yaml:"checks"`  // check commands: merge and pointer nodes run them from Phase 2
-	Leaves  map[string]PackLeaf `yaml:"leaves"`  // the leaves the graph works in, by path relative to the project
+	Leaves  map[string]PackLeaf `yaml:"leaves"`  // the default leaves of the lead realm's graph, by path relative to the project
 	Sandbox *PackSandbox        `yaml:"sandbox"` // the realm's stack layer and the hosts its commands reach (spec §6.1)
+
+	// Leaf is what a build realm offers every leaf it provides, under the same names in every realm
+	// (change realm-leaf-naming): a template, an implementer prompt and the leaf's checks. The graph
+	// names these roles, and Odin looks each one up in the realm of the task's leaf.
+	Leaf *PackRecipe `yaml:"leaf"`
+	// Services are the containers a sandbox of a leaf of this realm starts beside the work container,
+	// and the sandbox of each leaf that consumes it (spec §6.1, §9.2).
+	Services map[string]PackService `yaml:"services"`
+}
+
+// PackRecipe is the contract of a build realm: how to make a leaf, what to tell its implementer, and
+// the checks that decide a task in it is done.
+type PackRecipe struct {
+	Description string   `yaml:"description"`  // the new repo's description
+	Template    string   `yaml:"template"`     // the leaf's template directory, relative to the pack
+	FirstCommit []string `yaml:"first_commit"` // files of the template that make the repo's first commit, such as its licence
+	Implementer string   `yaml:"implementer"`  // the implementer's prompt file, relative to the pack
+	Checks      []string `yaml:"checks"`       // the check ladder, by name: each is defined in the pack's checks
+}
+
+// PackService is a container a sandbox starts beside the work container.
+type PackService struct {
+	Image string            `yaml:"image"` // pinned by digest
+	Env   map[string]string `yaml:"env"`   // made-up development values
+	Ports []int             `yaml:"ports"` // the TCP ports the work container may reach
+}
+
+// ServiceList returns the pack's services for a sandbox spec, sorted by name.
+func (p *Pack) ServiceList() []gungnir.Service {
+	var out []gungnir.Service
+	for _, name := range sortedKeys(p.Services) {
+		v := p.Services[name]
+		out = append(out, gungnir.Service{Name: name, Image: v.Image, Env: v.Env, Ports: v.Ports})
+	}
+	return out
 }
 
 // PackSandbox is what a realm adds to its leaves' sandboxes.
@@ -38,6 +73,46 @@ type PackRole struct {
 	Model string `yaml:"model"`
 }
 
+// checkRecipe checks the leaf recipe and the services: every path stays inside the realm and is there,
+// every check the recipe names is defined, and the services are what a sandbox can start.
+func (p *Pack) checkRecipe(file, dir string) error {
+	if r := p.Leaf; r != nil {
+		for what, f := range map[string]string{"template": r.Template, "implementer": r.Implementer} {
+			if !filepath.IsLocal(f) {
+				return fmt.Errorf("%s: leaf.%s %q must be a path inside the realm", file, what, f)
+			}
+		}
+		if st, err := os.Stat(filepath.Join(dir, r.Template)); err != nil || !st.IsDir() {
+			return fmt.Errorf("%s: leaf.template %q must be a directory of the realm", file, r.Template)
+		}
+		if st, err := os.Lstat(filepath.Join(dir, r.Implementer)); err != nil || !st.Mode().IsRegular() {
+			return fmt.Errorf("%s: leaf.implementer %q must be a regular file of the realm", file, r.Implementer)
+		}
+		for _, f := range r.FirstCommit {
+			if !filepath.IsLocal(f) {
+				return fmt.Errorf("%s: leaf.first_commit file %q must be a path inside the template", file, f)
+			}
+			if st, err := os.Lstat(filepath.Join(dir, r.Template, f)); err != nil || !st.Mode().IsRegular() {
+				return fmt.Errorf("%s: leaf.first_commit file %s/%s must be a regular file", file, r.Template, f)
+			}
+		}
+		seen := map[string]bool{}
+		for _, c := range r.Checks {
+			if _, ok := p.Checks[c]; !ok {
+				return fmt.Errorf("%s: leaf.checks names %q, which the pack doesn't define under checks", file, c)
+			}
+			if seen[c] {
+				return fmt.Errorf("%s: leaf.checks names %q twice", file, c)
+			}
+			seen[c] = true
+		}
+	}
+	if err := gungnir.ValidateServices(p.ServiceList()); err != nil {
+		return fmt.Errorf("%s: services: %w", file, err)
+	}
+	return nil
+}
+
 // LoadPack reads dir/pack.yaml. The graph and every template must stay inside dir, and every
 // first-commit file must be a regular file inside its template.
 func LoadPack(dir string) (*Pack, error) {
@@ -50,9 +125,12 @@ func LoadPack(dir string) (*Pack, error) {
 	if err := parseYAML(file, "pack.schema.json", data, &p); err != nil {
 		return nil, err
 	}
-	if !filepath.IsLocal(p.Graph) {
+	if p.Graph != "" && !filepath.IsLocal(p.Graph) {
 		return nil, fmt.Errorf("%s: graph %q must be a path inside the realm", file, p.Graph)
 	}
+	if err := p.checkRecipe(file, dir); err != nil {
+		return nil, err
+	}
 	if p.Sandbox != nil {
 		for _, h := range p.Sandbox.Egress {
 			if !gungnir.ValidHost(h) {
```

Apply to `schema/pack.schema.json`:

```diff
diff --git a/schema/pack.schema.json b/schema/pack.schema.json
index 5bff629..c9a32cc 100644
--- a/schema/pack.schema.json
+++ b/schema/pack.schema.json
@@ -2,14 +2,14 @@
   "$schema": "https://json-schema.org/draft/2020-12/schema",
   "$id": "https://github.com/ouroboric-dev/gungnir/schema/pack.schema.json",
   "title": "pack.yaml",
-  "description": "A realm pack: its name, version, graph, default roles, check commands, and the leaves its graph works in, with each one's template and first-commit files (spec §9.4; change remote-creates-repos).",
+  "description": "A realm pack: its name, version, graph (when it can lead a run), default roles, check commands, the leaf recipe a build realm offers, its sandbox services, and the default leaves its graph works in (spec §9.4; changes remote-creates-repos and realm-leaf-naming).",
   "type": "object",
   "additionalProperties": false,
-  "required": ["name", "version", "graph"],
+  "required": ["name", "version"],
   "properties": {
     "name": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
     "version": { "type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$" },
-    "graph": { "type": "string", "minLength": 1 },
+    "graph": { "type": "string", "minLength": 1, "description": "the realm's graph, relative to the pack; a realm that never leads a run has none" },
     "roles": {
       "type": "object",
       "propertyNames": { "pattern": "^[a-z][a-z0-9-]*$" },
@@ -37,6 +37,33 @@
         "egress": { "type": "array", "items": { "type": "string", "minLength": 1 } }
       }
     },
+    "leaf": {
+      "type": "object",
+      "additionalProperties": false,
+      "required": ["description", "template", "first_commit", "implementer", "checks"],
+      "description": "the contract of a build realm: the same fields in every realm, so the graph names roles and Odin resolves them in the realm of the task's leaf",
+      "properties": {
+        "description": { "type": "string", "minLength": 1 },
+        "template": { "type": "string", "minLength": 1 },
+        "first_commit": { "type": "array", "minItems": 1, "items": { "type": "string", "minLength": 1 } },
+        "implementer": { "type": "string", "minLength": 1 },
+        "checks": { "type": "array", "minItems": 1, "items": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" } }
+      }
+    },
+    "services": {
+      "type": "object",
+      "propertyNames": { "pattern": "^[a-z][a-z0-9-]*$" },
+      "additionalProperties": {
+        "type": "object",
+        "additionalProperties": false,
+        "required": ["image", "ports"],
+        "properties": {
+          "image": { "type": "string", "pattern": "^[a-z0-9][a-z0-9./_-]*(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$" },
+          "env": { "type": "object", "additionalProperties": { "type": "string" } },
+          "ports": { "type": "array", "items": { "type": "integer", "minimum": 1, "maximum": 65535 } }
+        }
+      }
+    },
     "leaves": {
       "type": "object",
       "propertyNames": { "pattern": "^[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)*$" },
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T146: factory.yaml says where the realm leaves are

`ygg run --realm midgard-react` has to find `midgard-react` somewhere. The operator says where once (the founder chose a local realm store on 2026-10-17, decision 2).

**Files (in `gungnir`):**
- Create: `schema/factory_realms_test.go`
- Modify: `schema/factory.go`, `schema/factory.schema.json`

**Interfaces:**
- Produces: `schema.Factory.Realms *Realms{Dir string}`. The folder holds one checkout of each realm leaf (`<dir>/midgard-react/pack.yaml`). It must be a clean, absolute path and not the root.

**Acceptance criteria:**
- [ ] A config with `realms: {dir: /abs}` parses; one without parses with `Realms == nil`.
- [ ] A relative folder, an unclean one, `/`, no folder and an unknown field are refused.

**Named test:** `go test ./schema -run 'TestFactoryNamesWhereTheRealmsAre'` in `gungnir`. **Layer:** `gungnir`. **Size:** S (52). **Depends on:** v0-T145.

- [ ] **Step 1:** write the tests.

Write `schema/factory_realms_test.go`:

```go
package schema

import (
	"strings"
	"testing"
)

const factoryHead = "roles:\n  implementer: { agent: scripted, model: none, script: s.yaml }\nbudget:\n  per_run: { tokens: 1000, turns: 10 }\n  per_day: { tokens: 2000, turns: 20 }\n"

func TestFactoryNamesWhereTheRealmsAre(t *testing.T) {
	f, err := ParseFactory("factory.yaml", []byte(factoryHead+"realms:\n  dir: /home/op/yggdrasil\n"))
	if err != nil {
		t.Fatalf("ParseFactory() = %v", err)
	}
	if f.Realms == nil || f.Realms.Dir != "/home/op/yggdrasil" {
		t.Errorf("Realms = %+v", f.Realms)
	}
	if f, err := ParseFactory("factory.yaml", []byte(factoryHead)); err != nil || f.Realms != nil {
		t.Errorf("a config with no realms = %+v, %v", f, err)
	}
	for name, y := range map[string]string{
		"a relative folder":         "realms:\n  dir: yggdrasil\n",
		"a folder that isn't clean": "realms:\n  dir: /home/op/../op/yggdrasil\n",
		"the root":                  "realms:\n  dir: /\n",
		"no folder":                 "realms: {}\n",
		"an unknown field":          "realms:\n  dir: /home/op/yggdrasil\n  url: https://example.com\n",
	} {
		_, err := ParseFactory("factory.yaml", []byte(factoryHead+y))
		if err == nil {
			t.Errorf("%s: ParseFactory() = nil error", name)
		} else if strings.Contains(err.Error(), "no complete budget caps") {
			t.Errorf("%s: %v", name, err)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/factory_realms_test.go:15:7: f.Realms undefined (type *Factory has no field or method Realms)
schema/factory_realms_test.go:16:30: f.Realms undefined (type *Factory has no field or method Realms)
schema/factory_realms_test.go:18:82: f.Realms undefined (type *Factory has no field or method Realms)
```

- [ ] **Step 3:** write the code.

Apply to `schema/factory.go`:

```diff
diff --git a/schema/factory.go b/schema/factory.go
index 4fdef55..a4725a8 100644
--- a/schema/factory.go
+++ b/schema/factory.go
@@ -19,6 +19,14 @@ type Factory struct {
 	Privacy string                  `yaml:"privacy"`
 	Sandbox *Sandbox                `yaml:"sandbox"` // required when a role runs a real agent (spec §6)
 	Skills  Skills                  `yaml:"skills"`
+	Realms  *Realms                 `yaml:"realms"` // where the realm leaves are, so --realm can name one
+}
+
+// Realms says where the operator keeps the realm leaves: a folder with one checkout of each, such as
+// the yggdrasil umbrella (<dir>/midgard-react/pack.yaml). A project pins the version it needs, and a
+// run uses the checkout only if it is at that version (change realm-leaf-naming).
+type Realms struct {
+	Dir string `yaml:"dir"`
 }
 
 // Sandbox says where the container engine is and how it sees the host's files (spec §6; sandbox
@@ -229,6 +237,9 @@ func (f *Factory) checkSandbox() error {
 	if f.Skills.PrivateDir != "" && !filepath.IsAbs(f.Skills.PrivateDir) {
 		return fmt.Errorf("skills.private_dir %q must be an absolute path", f.Skills.PrivateDir)
 	}
+	if r := f.Realms; r != nil && (!filepath.IsAbs(r.Dir) || filepath.Clean(r.Dir) != r.Dir || r.Dir == "/") {
+		return fmt.Errorf("realms.dir %q must be a clean, absolute path, and not the root", r.Dir)
+	}
 	if f.Sandbox == nil {
 		for _, r := range sortedKeys(f.Roles) {
 			if agent := f.Roles[r].Agent; agent != "scripted" {
```

Apply to `schema/factory.schema.json`:

```diff
diff --git a/schema/factory.schema.json b/schema/factory.schema.json
index cecebb6..c3e3bcc 100644
--- a/schema/factory.schema.json
+++ b/schema/factory.schema.json
@@ -52,6 +52,12 @@
         }
       }
     },
+    "realms": {
+      "type": "object",
+      "additionalProperties": false,
+      "required": ["dir"],
+      "properties": { "dir": { "type": "string", "minLength": 1, "description": "an absolute folder with one checkout of each realm leaf, so --realm midgard-react finds <dir>/midgard-react" } }
+    },
     "skills": {
       "type": "object",
       "additionalProperties": false,
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T147: a graph repeats a task shape for every ready task, in the realm of the task's leaf

Spec §4.2: "for each ready task: implement ⇄ check ladder, merge gate, pointer move". A `foreach` node holds the shape once. Its body names no repo (the task's leaf is its repo), and its loop, merge and pointer nodes take their prompt and checks from the realm of that leaf (`realm: leaf`).

**Files (in `gungnir`):**
- Create: `schema/graph_foreach_test.go`
- Modify: `schema/graph.go`, `schema/graph.schema.json`

**Interfaces:**
- Produces: `schema.KindForeach`; `Node.Over` (only `tasks`), `Node.Body []Node` (yaml `nodes`), `Node.RealmFrom` (yaml `realm`, `RealmLead` or `RealmLeaf`); internal, never read from a file: `Node.Realm` (the realm whose files a node uses; empty is the lead) and `Node.Task` (the task's node id). `(*Graph).All()`: every node, a foreach body after its foreach node.
- Body rules, in the schema and `ParseGraph`: no repo; a loop has `realm: leaf`, a role, and no prompt and no checks; a merge and a pointer have `realm: leaf` and no checks; no nested foreach; ids are unique across the whole graph; a gate in the body re-runs a loop or agent of the body, the nearest before it by default, never a node outside.

**Acceptance criteria:**
- [ ] The gallery-shaped graph parses; its body gates re-run the body's loop.
- [ ] Each rule above is refused, with the same messages as the graph's own nodes where the rule is the same.
- [ ] `All()` lists the body after its foreach node.

**Named test:** `go test ./schema -run 'TestAGraphRepeatsATaskShapeForEveryReadyTask|TestParseGraphRefusesABadTaskShape|TestAllListsTheBodyAfterItsForeachNode|TestParseGraph'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (287). **Depends on:** v0-T145.

- [ ] **Step 1:** write the tests.

Write `schema/graph_foreach_test.go`:

```go
package schema

import (
	"slices"
	"strings"
	"testing"
)

// gallery is the shape of a lead realm's graph: stages that write documents, then a task shape that
// repeats for every ready task, in the leaf the task names.
const galleryGraph = `
name: gallery
version: 1.0.0
nodes:
  - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md, repo: repos/app }
  - { id: plan-gate, kind: gate, gate: plan }
  - id: tasks
    kind: foreach
    over: tasks
    nodes:
      - id: implement
        kind: loop
        realm: leaf
        role: implementer
        reviewers:
          - { id: spec, role: reviewer, prompt: prompts/review-spec.md }
      - { id: feature-gate, kind: gate, gate: feature }
      - { id: land, kind: merge, realm: leaf }
      - { id: merge-gate, kind: gate, gate: merge }
      - { id: move, kind: pointer, realm: leaf, acceptance: [e2e], generated: [REPOS.md] }
  - { id: report, kind: exec, run: [echo, done], repo: . }
`

func TestAGraphRepeatsATaskShapeForEveryReadyTask(t *testing.T) {
	g, err := ParseGraph("graph.yaml", []byte(galleryGraph))
	if err != nil {
		t.Fatalf("ParseGraph() = %v", err)
	}
	fe := g.Nodes[2]
	if fe.Kind != KindForeach || fe.Over != "tasks" || len(fe.Body) != 5 {
		t.Fatalf("the foreach node = %+v", fe)
	}
	loop := fe.Body[0]
	if loop.RealmFrom != RealmLeaf || loop.Attempts != DefaultAttempts || loop.Prompt != "" || len(loop.Checks) != 0 || loop.Reviewers[0].ID != "spec" {
		t.Errorf("the body's loop = %+v", loop)
	}
	if got := fe.Body[1].Reruns; got != "implement" {
		t.Errorf("feature-gate reruns %q, want implement (the nearest loop in the body)", got)
	}
	if got := fe.Body[3].Reruns; got != "implement" {
		t.Errorf("merge-gate reruns %q, want implement", got)
	}
	if g.Nodes[1].Reruns != "plan" {
		t.Errorf("plan-gate reruns %q, want plan", g.Nodes[1].Reruns)
	}
	if !slices.Equal(g.Nodes[2].Body[4].Acceptance, []string{"e2e"}) {
		t.Errorf("pointer = %+v", g.Nodes[2].Body[4])
	}
}

func TestParseGraphRefusesABadTaskShape(t *testing.T) {
	head := "name: g\nversion: 1.0.0\nnodes:\n"
	fe := func(body string) string {
		return "  - id: tasks\n    kind: foreach\n    over: tasks\n    nodes:\n" + body
	}
	loop := "      - { id: implement, kind: loop, realm: leaf, role: implementer }\n"
	const bySchema = "jsonschema validation failed"
	cases := map[string]struct{ nodes, want string }{
		"over something else":                {"  - id: t\n    kind: foreach\n    over: leaves\n    nodes:\n" + loop, bySchema},
		"a foreach with no body":             {"  - { id: t, kind: foreach, over: tasks, nodes: [] }\n", bySchema},
		"a foreach in a foreach":             {fe("      - id: inner\n        kind: foreach\n        over: tasks\n        nodes:\n" + strings.ReplaceAll(loop, "      -", "          -")), bySchema},
		"a repo in the body":                 {fe("      - { id: implement, kind: loop, realm: leaf, role: implementer, repo: repos/app }\n"), bySchema},
		"a loop of the lead realm":           {fe("      - { id: implement, kind: loop, role: implementer, prompt: p.md, checks: [vet] }\n"), bySchema},
		"a leaf loop with its own prompt":    {fe("      - { id: implement, kind: loop, realm: leaf, role: implementer, prompt: p.md }\n"), bySchema},
		"a leaf loop with its own checks":    {fe("      - { id: implement, kind: loop, realm: leaf, role: implementer, checks: [vet] }\n"), bySchema},
		"a merge with its own checks":        {fe(loop + "      - { id: land, kind: merge, realm: leaf, checks: [unit] }\n"), bySchema},
		"a merge of the lead realm":          {fe(loop + "      - { id: land, kind: merge, checks: [unit] }\n"), bySchema},
		"realm: lead":                        {fe("      - { id: implement, kind: loop, realm: lead, role: implementer }\n"), bySchema},
		"realm: leaf outside a foreach":      {"  - { id: implement, kind: loop, realm: leaf, role: implementer, repo: repos/app }\n", bySchema},
		"an id used in the body and outside": {fe(loop) + "  - { id: implement, kind: exec, run: [echo] }\n", "used twice"},
		"a gate in the body with no loop":    {fe("      - { id: g, kind: gate, gate: feature }\n"), "no agent or loop node before it"},
		"a gate that reruns a node outside":  {"  - { id: plan, kind: agent, role: planner, prompt: p.md }\n" + fe(loop+"      - { id: g, kind: gate, gate: feature, reruns: plan }\n"), "must be an agent or loop node before it"},
		"a body reviewer that climbs":        {fe("      - { id: implement, kind: loop, realm: leaf, role: implementer, reviewers: [{ id: spec, role: reviewer, prompt: ../r.md }] }\n"), "inside the realm"},
		"an exec node outside any repo":      {fe(loop + "      - { id: e, kind: exec, run: [echo], repo: . }\n"), bySchema},
	}
	for name, c := range cases {
		_, err := ParseGraph("graph.yaml", []byte(head+c.nodes))
		if err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: ParseGraph() = %v, want an error containing %q", name, err, c.want)
		}
	}
}

func TestAllListsTheBodyAfterItsForeachNode(t *testing.T) {
	g, err := ParseGraph("graph.yaml", []byte(galleryGraph))
	if err != nil {
		t.Fatal(err)
	}
	var ids []string
	for _, n := range g.All() {
		ids = append(ids, n.ID)
	}
	want := "plan plan-gate tasks implement feature-gate land merge-gate move report"
	if strings.Join(ids, " ") != want {
		t.Errorf("All() = %s, want %s", strings.Join(ids, " "), want)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/graph_foreach_test.go:40:16: undefined: KindForeach
schema/graph_foreach_test.go:40:34: fe.Over undefined (type Node has no field or method Over)
schema/graph_foreach_test.go:40:60: fe.Body undefined (type Node has no field or method Body)
```

- [ ] **Step 3:** write the code.

Apply to `schema/graph.go`:

```diff
diff --git a/schema/graph.go b/schema/graph.go
index 82c5981..0c92214 100644
--- a/schema/graph.go
+++ b/schema/graph.go
@@ -28,6 +28,13 @@ const (
 	KindMerge   NodeKind = "merge"   // lands a leaf's run branch on its main, through the merge gate
 	KindPointer NodeKind = "pointer" // moves a leaf's pointer in its parent umbrella, one level
 	KindLoop    NodeKind = "loop"    // implement, check and fix with a bounded number of attempts (spec §4.2, §4.6, §7.3)
+	KindForeach NodeKind = "foreach" // repeats its body for every ready task of the plan, in the leaf the task names (spec §4.2)
+)
+
+// RealmFrom says whose files a node uses: the lead realm's (the default) or the realm of the task's leaf.
+const (
+	RealmLead = "lead"
+	RealmLeaf = "leaf"
 )
 
 // DefaultAttempts is how many times a loop runs its implementer when the node sets no attempts (spec §4.2).
@@ -53,6 +60,14 @@ type Node struct {
 	Reviewers  []Reviewer `yaml:"reviewers"`  // loop: read-only agents that review each attempt once its checks pass, in order
 	Acceptance []string   `yaml:"acceptance"` // pointer: pack checks run in the leaf's parent umbrella
 	Generated  []string   `yaml:"generated"`  // pointer: generated files of the parent umbrella, committed with the move under the shrink guard
+
+	Over      string `yaml:"over"`  // foreach: what it repeats for; only "tasks"
+	Body      []Node `yaml:"nodes"` // foreach: the nodes that run for each task, in the task's leaf
+	RealmFrom string `yaml:"realm"` // loop, merge, pointer in a foreach body: "leaf", the realm of the task's leaf supplies the prompt and the checks
+
+	// Set by Odin when it expands a foreach for one task; never in a graph file.
+	Realm string `yaml:"-"` // the realm whose files this node's prompt and checks come from; empty is the lead realm
+	Task  string `yaml:"-"` // the id of the task this node works for
 }
 
 // Reviewer is a read-only agent that reviews a loop's work and reports typed findings (spec §4.6, §9.5).
@@ -80,6 +95,18 @@ func (d *Duration) UnmarshalYAML(n *yaml.Node) error {
 	return nil
 }
 
+// All returns every node of the graph, the nodes of a foreach body after the foreach node itself, in the
+// order they are written. It is for what applies to every node, such as the roles and skills the graph
+// names.
+func (g *Graph) All() []Node {
+	var out []Node
+	for _, n := range g.Nodes {
+		out = append(out, n)
+		out = append(out, n.Body...)
+	}
+	return out
+}
+
 // Index returns the position of the node with the given id, or -1.
 func (g *Graph) Index(id string) int {
 	for i, n := range g.Nodes {
@@ -99,39 +126,69 @@ func LoadGraph(path string) (*Graph, error) {
 	return ParseGraph(path, data)
 }
 
-// ParseGraph parses graph.yaml. Ids must be unique, prompt files must stay inside the realm, merge
-// and pointer nodes must name a child repo, and every gate gets the node its rejection re-runs: the
-// agent or loop node it names, which must come before it, or else the nearest one before it. A
-// rejection's reason is input for an agent, so it never re-runs an exec node, which would drop it.
-// A loop's attempts default to DefaultAttempts, its reviewers' ids are unique, and a reviewer's
-// session key (the loop's id, a dash and the reviewer's id) never equals a node's id.
+// ParseGraph parses graph.yaml. Ids must be unique across the graph, prompt files must stay inside the
+// realm, merge and pointer nodes must name a child repo, and every gate gets the node its rejection
+// re-runs: the agent or loop node it names, which must come before it in its own scope (the graph, or
+// one foreach body), or else the nearest one before it. A rejection's reason is input for an agent, so
+// it never re-runs an exec node, which would drop it. A loop's attempts default to DefaultAttempts, its
+// reviewers' ids are unique, and a reviewer's session key (the loop's id, a dash and the reviewer's id)
+// never equals a node's id. A foreach node's body is checked as a graph of its own, in which a node
+// names no repo: the task's leaf is its repo.
 func ParseGraph(file string, data []byte) (*Graph, error) {
 	var g Graph
 	if err := parseYAML(file, "graph.schema.json", data, &g); err != nil {
 		return nil, err
 	}
-	seen := map[string]int{}
-	keys := map[string]string{} // reviewer session key: the loop that owns it
-	for i := range g.Nodes {
-		n := &g.Nodes[i]
-		if _, dup := seen[n.ID]; dup {
-			return nil, fmt.Errorf("%s: node id %q is used twice", file, n.ID)
+	c := &graphCheck{file: file, seen: map[string]bool{}, keys: map[string]string{}}
+	if err := c.scope(g.Nodes, false); err != nil {
+		return nil, err
+	}
+	for key, loop := range c.keys {
+		if c.seen[key] {
+			return nil, fmt.Errorf("%s: loop %s: a reviewer's session key %q is also a node id", file, loop, key)
 		}
-		seen[n.ID] = i
-		if (n.Kind == KindAgent || n.Kind == KindLoop) && !filepath.IsLocal(n.Prompt) {
-			return nil, fmt.Errorf("%s: node %s: prompt %q must be a path inside the realm", file, n.ID, n.Prompt)
+	}
+	return &g, nil
+}
+
+// graphCheck holds what ParseGraph learns across scopes: every node id, and the reviewer session keys.
+type graphCheck struct {
+	file string
+	seen map[string]bool   // node ids of the whole graph, bodies included
+	keys map[string]string // reviewer session key: the loop that owns it
+}
+
+// scope checks the nodes of the graph, or of one foreach body.
+func (c *graphCheck) scope(nodes []Node, body bool) error {
+	file := c.file
+	at := map[string]int{} // node id: its position in this scope
+	for i := range nodes {
+		n := &nodes[i]
+		if c.seen[n.ID] {
+			return fmt.Errorf("%s: node id %q is used twice", file, n.ID)
+		}
+		c.seen[n.ID] = true
+		at[n.ID] = i
+		leafLoop := n.Kind == KindLoop && n.RealmFrom == RealmLeaf
+		if (n.Kind == KindAgent || n.Kind == KindLoop) && !leafLoop && !filepath.IsLocal(n.Prompt) {
+			return fmt.Errorf("%s: node %s: prompt %q must be a path inside the realm", file, n.ID, n.Prompt)
 		}
 		if n.Kind == KindLoop {
-			if err := checkLoop(file, n, keys); err != nil {
-				return nil, err
+			if err := checkLoop(file, n, c.keys); err != nil {
+				return err
 			}
 		}
 		if (n.Kind == KindMerge || n.Kind == KindPointer) && n.Repo == "." {
-			return nil, fmt.Errorf("%s: node %s: repo must be a child of the project, not the project itself", file, n.ID)
+			return fmt.Errorf("%s: node %s: repo must be a child of the project, not the project itself", file, n.ID)
 		}
 		for _, f := range n.Generated {
 			if !filepath.IsLocal(f) {
-				return nil, fmt.Errorf("%s: node %s: generated file %q must be a path inside the umbrella", file, n.ID, f)
+				return fmt.Errorf("%s: node %s: generated file %q must be a path inside the umbrella", file, n.ID, f)
+			}
+		}
+		if n.Kind == KindForeach {
+			if err := c.scope(n.Body, true); err != nil {
+				return err
 			}
 		}
 		if n.Kind != KindGate {
@@ -139,26 +196,21 @@ func ParseGraph(file string, data []byte) (*Graph, error) {
 		}
 		if n.Reruns == "" {
 			for j := i - 1; j >= 0 && n.Reruns == ""; j-- {
-				if k := g.Nodes[j].Kind; k == KindAgent || k == KindLoop {
-					n.Reruns = g.Nodes[j].ID
+				if k := nodes[j].Kind; k == KindAgent || k == KindLoop {
+					n.Reruns = nodes[j].ID
 				}
 			}
 			if n.Reruns == "" {
-				return nil, fmt.Errorf("%s: gate %s has no agent or loop node before it to re-run when rejected", file, n.ID)
+				return fmt.Errorf("%s: gate %s has no agent or loop node before it to re-run when rejected", file, n.ID)
 			}
 			continue
 		}
-		j, ok := seen[n.Reruns]
-		if !ok || j == i || (g.Nodes[j].Kind != KindAgent && g.Nodes[j].Kind != KindLoop) {
-			return nil, fmt.Errorf("%s: gate %s re-runs %q, which must be an agent or loop node before it", file, n.ID, n.Reruns)
-		}
-	}
-	for key, loop := range keys {
-		if _, clash := seen[key]; clash {
-			return nil, fmt.Errorf("%s: loop %s: a reviewer's session key %q is also a node id", file, loop, key)
+		j, ok := at[n.Reruns]
+		if !ok || j == i || (nodes[j].Kind != KindAgent && nodes[j].Kind != KindLoop) {
+			return fmt.Errorf("%s: gate %s re-runs %q, which must be an agent or loop node before it", file, n.ID, n.Reruns)
 		}
 	}
-	return &g, nil
+	return nil
 }
 
 // checkLoop checks a loop node's attempts and reviewers, and records its reviewers' session keys.
```

Apply to `schema/graph.schema.json`:

```diff
diff --git a/schema/graph.schema.json b/schema/graph.schema.json
index 2bda5e1..ddba842 100644
--- a/schema/graph.schema.json
+++ b/schema/graph.schema.json
@@ -2,7 +2,7 @@
   "$schema": "https://json-schema.org/draft/2020-12/schema",
   "$id": "https://github.com/ouroboric-dev/gungnir/schema/graph.schema.json",
   "title": "graph.yaml",
-  "description": "A realm's graph: nodes run in order; a gate node is an approval point (spec §4.2, §7). Exec and agent nodes work in a repo of the project, merge nodes land a leaf's run branch through the merge gate (§4.5), pointer nodes move a leaf's pointer one level (§3.4), loop nodes run an implementer against a check ladder and reviewers, with a bounded number of attempts (§4.2, §4.6, §7.3).",
+  "description": "A realm's graph: nodes run in order; a foreach node repeats its body for every ready task, in the leaf the task names, and the body's loop, merge and pointer nodes take their prompt and checks from the realm of that leaf (change realm-leaf-naming); a gate node is an approval point (spec §4.2, §7). Exec and agent nodes work in a repo of the project, merge nodes land a leaf's run branch through the merge gate (§4.5), pointer nodes move a leaf's pointer one level (§3.4), loop nodes run an implementer against a check ladder and reviewers, with a bounded number of attempts (§4.2, §4.6, §7.3).",
   "type": "object",
   "additionalProperties": false,
   "required": ["name", "version", "nodes"],
@@ -17,6 +17,12 @@
     "duration": { "type": "string", "pattern": "^[1-9][0-9]*(ms|s|m|h)$" },
     "repo": { "type": "string", "pattern": "^(\\.|[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)*)$" },
     "names": { "type": "array", "items": { "$ref": "#/$defs/id" } },
+    "gate": {
+      "enum": ["design", "spec", "plan", "feature", "merge", "pointer", "pointer-contract", "escalation",
+               "deploy-prod", "store-submit", "real-secrets-or-user-data", "budget-cap",
+               "external-input", "policy-violation", "shrink-guard", "guardrail-change",
+               "repo-admin"]
+    },
     "reviewer": {
       "type": "object",
       "additionalProperties": false,
@@ -33,7 +39,7 @@
     "node": {
       "type": "object",
       "required": ["id", "kind"],
-      "properties": { "kind": { "enum": ["exec", "agent", "gate", "merge", "pointer", "loop"] } },
+      "properties": { "kind": { "enum": ["exec", "agent", "gate", "merge", "pointer", "loop", "foreach"] } },
       "oneOf": [
         {
           "additionalProperties": false,
@@ -67,12 +73,7 @@
           "properties": {
             "id": { "$ref": "#/$defs/id" },
             "kind": { "const": "gate" },
-            "gate": {
-              "enum": ["design", "spec", "plan", "feature", "merge", "pointer", "pointer-contract", "escalation",
-                       "deploy-prod", "store-submit", "real-secrets-or-user-data", "budget-cap",
-                       "external-input", "policy-violation", "shrink-guard", "guardrail-change",
-                       "repo-admin"]
-            },
+            "gate": { "$ref": "#/$defs/gate" },
             "reruns": { "$ref": "#/$defs/id" }
           }
         },
@@ -117,6 +118,94 @@
             "checks": { "$ref": "#/$defs/names", "minItems": 1, "uniqueItems": true },
             "reviewers": { "type": "array", "minItems": 1, "maxItems": 5, "items": { "$ref": "#/$defs/reviewer" } }
           }
+        },
+        {
+          "additionalProperties": false,
+          "required": ["over", "nodes"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "foreach" },
+            "over": { "const": "tasks" },
+            "nodes": { "type": "array", "minItems": 1, "items": { "$ref": "#/$defs/bodyNode" } }
+          }
+        }
+      ]
+    },
+    "bodyNode": {
+      "type": "object",
+      "required": ["id", "kind"],
+      "properties": { "kind": { "enum": ["exec", "agent", "gate", "merge", "pointer", "loop"] } },
+      "oneOf": [
+        {
+          "additionalProperties": false,
+          "required": ["run"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "exec" },
+            "run": { "type": "array", "minItems": 1, "items": { "type": "string", "minLength": 1 } },
+            "timeout": { "$ref": "#/$defs/duration" }
+          }
+        },
+        {
+          "additionalProperties": false,
+          "required": ["role", "prompt"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "agent" },
+            "role": { "$ref": "#/$defs/id" },
+            "prompt": { "type": "string", "minLength": 1 },
+            "read_only": { "type": "boolean" },
+            "max_turns": { "type": "integer", "minimum": 1 },
+            "skills": { "$ref": "#/$defs/names", "uniqueItems": true },
+            "timeout": { "$ref": "#/$defs/duration" }
+          }
+        },
+        {
+          "additionalProperties": false,
+          "required": ["gate"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "gate" },
+            "gate": { "$ref": "#/$defs/gate" },
+            "reruns": { "$ref": "#/$defs/id" }
+          }
+        },
+        {
+          "additionalProperties": false,
+          "required": ["realm"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "merge" },
+            "realm": { "const": "leaf" },
+            "timeout": { "$ref": "#/$defs/duration" }
+          }
+        },
+        {
+          "additionalProperties": false,
+          "required": ["realm"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "pointer" },
+            "realm": { "const": "leaf" },
+            "acceptance": { "$ref": "#/$defs/names" },
+            "generated": { "type": "array", "items": { "type": "string", "minLength": 1 } },
+            "timeout": { "$ref": "#/$defs/duration" }
+          }
+        },
+        {
+          "additionalProperties": false,
+          "required": ["realm", "role"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "loop" },
+            "realm": { "const": "leaf" },
+            "role": { "$ref": "#/$defs/id" },
+            "skills": { "$ref": "#/$defs/names", "uniqueItems": true },
+            "max_turns": { "type": "integer", "minimum": 1 },
+            "timeout": { "$ref": "#/$defs/duration" },
+            "attempts": { "type": "integer", "minimum": 1, "maximum": 10 },
+            "reviewers": { "type": "array", "minItems": 1, "maxItems": 5, "items": { "$ref": "#/$defs/reviewer" } }
+          }
         }
       ]
     }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T148: graph nodes for the stages that write documents: scratch agents, publish, tasks and init

The stages before the code (design, spec, plan, DoR, init: spec §4.2) write documents, and the planner "gets a scratch directory with the brief; Odin commits the planner's output into L1 after the `spec` approval point" (§3.3 rule 1). Four graph additions say so.

**Files (in `gungnir`):**
- Create: `schema/graph_stages_test.go`
- Modify: `schema/graph.go`, `schema/graph.schema.json`

**Interfaces:**
- Produces: `Node.Scratch` and `Node.Inputs` on an agent (the agent works in a workspace of its own, with copies of the project paths it names, and writes under `out/`); `schema.KindPublish` with `From` (the scratch agent) and `To` (a folder of the project); `schema.KindTasks` and `schema.KindInit`, each with `From` (a project path: tasks takes a glob).
- Rules: a scratch agent names no repo and is not read-only; inputs only on a scratch agent, each a project path outside `.git` and `.factory`, none twice; a publish reads a scratch agent that comes before it and writes to a folder of the project, never the project itself, `.git` or `.factory`.

**Acceptance criteria:**
- [ ] The front of a lead graph (design, spec, plan, tasks, init) parses, and a gate after a scratch agent re-runs it.
- [ ] Every rule above is refused.

**Named test:** `go test ./schema -run 'TestAGraphWritesDocumentsInAScratchWorkspaceAndPublishesThemIntoTheProject|TestParseGraphRefusesBadStageNodes'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (166). **Depends on:** v0-T147.

- [ ] **Step 1:** write the tests.

Write `schema/graph_stages_test.go`:

```go
package schema

import (
	"slices"
	"strings"
	"testing"
)

// stagesGraph is the front of a lead realm's graph: agents that write documents in a scratch workspace,
// Odin publishing them into the project once approved, the plan read into tasks, and the leaves created.
const stagesGraph = `
name: stages
version: 1.0.0
nodes:
  - { id: design, kind: agent, role: planner, prompt: prompts/design.md, scratch: true }
  - { id: design-gate, kind: gate, gate: design }
  - { id: design-docs, kind: publish, from: design, to: docs }
  - { id: spec, kind: agent, role: planner, prompt: prompts/spec.md, scratch: true, inputs: [docs/1-product, brief.md], max_turns: 30 }
  - { id: spec-gate, kind: gate, gate: spec }
  - { id: spec-docs, kind: publish, from: spec, to: docs }
  - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md, scratch: true, inputs: [docs] }
  - { id: plan-docs, kind: publish, from: plan, to: docs }
  - { id: ready, kind: tasks, from: docs/2-engineering/plans/*/tasks.md }
  - { id: leaves, kind: init, from: docs/leaves.yaml }
`

func TestAGraphWritesDocumentsInAScratchWorkspaceAndPublishesThemIntoTheProject(t *testing.T) {
	g, err := ParseGraph("graph.yaml", []byte(stagesGraph))
	if err != nil {
		t.Fatalf("ParseGraph() = %v", err)
	}
	spec := g.Nodes[3]
	if !spec.Scratch || spec.Repo != "" || !slices.Equal(spec.Inputs, []string{"docs/1-product", "brief.md"}) {
		t.Errorf("spec = %+v", spec)
	}
	if pub := g.Nodes[2]; pub.Kind != KindPublish || pub.From != "design" || pub.To != "docs" {
		t.Errorf("publish = %+v", pub)
	}
	if n := g.Nodes[8]; n.Kind != KindTasks || n.From != "docs/2-engineering/plans/*/tasks.md" {
		t.Errorf("tasks = %+v", n)
	}
	if n := g.Nodes[9]; n.Kind != KindInit || n.From != "docs/leaves.yaml" {
		t.Errorf("init = %+v", n)
	}
	if g.Nodes[1].Reruns != "design" || g.Nodes[4].Reruns != "spec" {
		t.Errorf("a gate re-runs the scratch agent before it: %q, %q", g.Nodes[1].Reruns, g.Nodes[4].Reruns)
	}
}

func TestParseGraphRefusesBadStageNodes(t *testing.T) {
	head := "name: g\nversion: 1.0.0\nnodes:\n"
	scratch := "  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true }\n"
	const bySchema = "jsonschema validation failed"
	cases := map[string]struct{ nodes, want string }{
		"a scratch agent with a repo":        {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, repo: repos/app }\n", "names no repo"},
		"a read-only scratch agent":          {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, read_only: true }\n", "writes its output"},
		"inputs without a scratch workspace": {"  - { id: s, kind: agent, role: planner, prompt: p.md, repo: repos/app, inputs: [docs] }\n", "only a scratch agent"},
		"an input that climbs":               {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [../x] }\n", "inside the project"},
		"an input in .factory":               {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [.factory/runs] }\n", "inside the project"},
		"an input in .git":                   {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [.git/config] }\n", "inside the project"},
		"an input twice":                     {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [docs, docs] }\n", "twice"},
		"a publish without from":             {"  - { id: p, kind: publish, to: docs }\n", bySchema},
		"a publish without to":               {scratch + "  - { id: p, kind: publish, from: s }\n", bySchema},
		"a publish from a node that isn't":   {"  - { id: e, kind: exec, run: [echo] }\n  - { id: p, kind: publish, from: e, to: docs }\n", "scratch agent node before it"},
		"a publish from a later node":        {"  - { id: p, kind: publish, from: s, to: docs }\n" + scratch, "scratch agent node before it"},
		"a publish into the project root":    {scratch + "  - { id: p, kind: publish, from: s, to: . }\n", "a folder of the project"},
		"a publish that climbs":              {scratch + "  - { id: p, kind: publish, from: s, to: ../docs }\n", "a folder of the project"},
		"a publish into .git":                {scratch + "  - { id: p, kind: publish, from: s, to: .git/hooks }\n", "a folder of the project"},
		"a publish into .factory":            {scratch + "  - { id: p, kind: publish, from: s, to: .factory/runs }\n", "a folder of the project"},
		"tasks without from":                 {"  - { id: t, kind: tasks }\n", bySchema},
		"tasks from a file that climbs":      {"  - { id: t, kind: tasks, from: ../tasks.md }\n", "inside the project"},
		"init from a file that climbs":       {"  - { id: i, kind: init, from: ../leaves.yaml }\n", "inside the project"},
		"init with a repo":                   {"  - { id: i, kind: init, from: docs/leaves.yaml, repo: repos/app }\n", bySchema},
		"a scratch flag on an exec node":     {"  - { id: e, kind: exec, run: [echo], scratch: true }\n", bySchema},
	}
	for name, c := range cases {
		_, err := ParseGraph("graph.yaml", []byte(head+c.nodes))
		if err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: ParseGraph() = %v, want an error containing %q", name, err, c.want)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/graph_stages_test.go:33:11: spec.Scratch undefined (type Node has no field or method Scratch)
schema/graph_stages_test.go:33:60: spec.Inputs undefined (type Node has no field or method Inputs)
schema/graph_stages_test.go:36:36: undefined: KindPublish
```

- [ ] **Step 3:** write the code.

Apply to `schema/graph.go`:

```diff
diff --git a/schema/graph.go b/schema/graph.go
index 0c92214..5dd5217 100644
--- a/schema/graph.go
+++ b/schema/graph.go
@@ -5,6 +5,7 @@ import (
 	"os"
 	"path/filepath"
 	"slices"
+	"strings"
 	"time"
 
 	"github.com/ouroboric-dev/gungnir"
@@ -29,6 +30,9 @@ const (
 	KindPointer NodeKind = "pointer" // moves a leaf's pointer in its parent umbrella, one level
 	KindLoop    NodeKind = "loop"    // implement, check and fix with a bounded number of attempts (spec §4.2, §4.6, §7.3)
 	KindForeach NodeKind = "foreach" // repeats its body for every ready task of the plan, in the leaf the task names (spec §4.2)
+	KindPublish NodeKind = "publish" // Odin copies a scratch agent's output into the project and commits it (spec §3.3 rule 1)
+	KindTasks   NodeKind = "tasks"   // Odin reads the plan's tasks.md, checks every task is ready, and writes features.json (spec §4.2)
+	KindInit    NodeKind = "init"    // Odin creates the leaves the spec names, each from its realm's template (spec §4.2, §4.1)
 )
 
 // RealmFrom says whose files a node uses: the lead realm's (the default) or the realm of the task's leaf.
@@ -61,6 +65,11 @@ type Node struct {
 	Acceptance []string   `yaml:"acceptance"` // pointer: pack checks run in the leaf's parent umbrella
 	Generated  []string   `yaml:"generated"`  // pointer: generated files of the parent umbrella, committed with the move under the shrink guard
 
+	Scratch bool     `yaml:"scratch"` // agent: runs in a scratch workspace, not a leaf, and writes its documents to out/ (spec §3.3 rule 1)
+	Inputs  []string `yaml:"inputs"`  // agent (scratch): files and folders of the project, copied into the workspace; changes to the copies are ignored
+	From    string   `yaml:"from"`    // publish: the scratch agent whose output is published; tasks: the tasks.md, by glob; init: the leaves file
+	To      string   `yaml:"to"`      // publish: the folder of the project its files go to
+
 	Over      string `yaml:"over"`  // foreach: what it repeats for; only "tasks"
 	Body      []Node `yaml:"nodes"` // foreach: the nodes that run for each task, in the task's leaf
 	RealmFrom string `yaml:"realm"` // loop, merge, pointer in a foreach body: "leaf", the realm of the task's leaf supplies the prompt and the checks
@@ -186,6 +195,9 @@ func (c *graphCheck) scope(nodes []Node, body bool) error {
 				return fmt.Errorf("%s: node %s: generated file %q must be a path inside the umbrella", file, n.ID, f)
 			}
 		}
+		if err := c.stage(n, nodes[:i]); err != nil {
+			return err
+		}
 		if n.Kind == KindForeach {
 			if err := c.scope(n.Body, true); err != nil {
 				return err
@@ -213,6 +225,55 @@ func (c *graphCheck) scope(nodes []Node, body bool) error {
 	return nil
 }
 
+// stage checks the nodes that work on documents and the project, not on a leaf: a scratch agent, and
+// publish, tasks and init. before holds the nodes of the scope ahead of n.
+func (c *graphCheck) stage(n *Node, before []Node) error {
+	file := c.file
+	switch n.Kind {
+	case KindAgent:
+		switch {
+		case n.Scratch && n.Repo != "":
+			return fmt.Errorf("%s: node %s: a scratch agent names no repo; it works in a workspace of its own", file, n.ID)
+		case n.Scratch && n.ReadOnly:
+			return fmt.Errorf("%s: node %s: a scratch agent writes its output to out/, so it can't be read-only", file, n.ID)
+		case !n.Scratch && len(n.Inputs) > 0:
+			return fmt.Errorf("%s: node %s: only a scratch agent takes inputs", file, n.ID)
+		}
+		seen := map[string]bool{}
+		for _, in := range n.Inputs {
+			if !projectPath(in) {
+				return fmt.Errorf("%s: node %s: input %q must be a path inside the project, outside .git and .factory", file, n.ID, in)
+			}
+			if seen[in] {
+				return fmt.Errorf("%s: node %s: input %q is listed twice", file, n.ID, in)
+			}
+			seen[in] = true
+		}
+	case KindPublish:
+		if !slices.ContainsFunc(before, func(m Node) bool { return m.ID == n.From && m.Kind == KindAgent && m.Scratch }) {
+			return fmt.Errorf("%s: node %s publishes the output of %q, which must be a scratch agent node before it", file, n.ID, n.From)
+		}
+		if n.To == "." || !projectPath(n.To) {
+			return fmt.Errorf("%s: node %s: to %q must be a folder of the project (not the project itself, .git or .factory)", file, n.ID, n.To)
+		}
+	case KindTasks, KindInit:
+		if !projectPath(n.From) {
+			return fmt.Errorf("%s: node %s: from %q must be a path inside the project, outside .git and .factory", file, n.ID, n.From)
+		}
+	}
+	return nil
+}
+
+// projectPath reports whether p is a path inside a project that a run may read or write: relative,
+// without ".." and not inside .git or .factory, which are Odin's.
+func projectPath(p string) bool {
+	if !filepath.IsLocal(p) {
+		return false
+	}
+	first, _, _ := strings.Cut(filepath.ToSlash(filepath.Clean(p)), "/")
+	return first != ".git" && first != ".factory"
+}
+
 // checkLoop checks a loop node's attempts and reviewers, and records its reviewers' session keys.
 func checkLoop(file string, n *Node, keys map[string]string) error {
 	if n.Attempts == 0 {
```

Apply to `schema/graph.schema.json`:

```diff
diff --git a/schema/graph.schema.json b/schema/graph.schema.json
index ddba842..e6b8579 100644
--- a/schema/graph.schema.json
+++ b/schema/graph.schema.json
@@ -39,7 +39,7 @@
     "node": {
       "type": "object",
       "required": ["id", "kind"],
-      "properties": { "kind": { "enum": ["exec", "agent", "gate", "merge", "pointer", "loop", "foreach"] } },
+      "properties": { "kind": { "enum": ["exec", "agent", "gate", "merge", "pointer", "loop", "foreach", "publish", "tasks", "init"] } },
       "oneOf": [
         {
           "additionalProperties": false,
@@ -64,7 +64,9 @@
             "max_turns": { "type": "integer", "minimum": 1 },
             "skills": { "$ref": "#/$defs/names", "uniqueItems": true },
             "repo": { "$ref": "#/$defs/repo" },
-            "timeout": { "$ref": "#/$defs/duration" }
+            "timeout": { "$ref": "#/$defs/duration" },
+            "scratch": { "type": "boolean" },
+            "inputs": { "type": "array", "items": { "type": "string", "minLength": 1 } }
           }
         },
         {
@@ -119,6 +121,25 @@
             "reviewers": { "type": "array", "minItems": 1, "maxItems": 5, "items": { "$ref": "#/$defs/reviewer" } }
           }
         },
+        {
+          "additionalProperties": false,
+          "required": ["from", "to"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "publish" },
+            "from": { "$ref": "#/$defs/id" },
+            "to": { "type": "string", "minLength": 1 }
+          }
+        },
+        {
+          "additionalProperties": false,
+          "required": ["from"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "enum": ["tasks", "init"] },
+            "from": { "type": "string", "minLength": 1 }
+          }
+        },
         {
           "additionalProperties": false,
           "required": ["over", "nodes"],
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T149: a merge, a pointer move or a plan check that refuses can send the run back into an earlier node, a few times

Spec §4.5: "any failure returns to the loop". A node that can refuse work names where the refusal goes: `back_to`, an earlier agent or loop node of its own scope, and how often (`returns`).

**Files (in `gungnir`):**
- Create: `schema/graph_returns_test.go`
- Modify: `schema/graph.go`, `schema/graph.schema.json`

**Interfaces:**
- Produces: `Node.BackTo` and `Node.Returns` on a merge, a pointer and a tasks node (also in a foreach body); `DefaultReturns` (2) and `MaxReturns` (5). `returns` without `back_to` is refused; `back_to` must name an agent or loop node before the node, in its own scope (a body's node cannot go back outside the body).

**Acceptance criteria:**
- [ ] `back_to` sets `returns` to 2 when the node gives none, and a node may set 1 to 5.
- [ ] A missing node, an exec node, a later node, the node itself, a node of another scope, `returns` alone and `back_to` on an agent or init node are refused.

**Named test:** `go test ./schema -run 'TestARefusalCanGoBackIntoAnEarlierNodeAFewTimes|TestParseGraphRefusesBadReturns'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (113). **Depends on:** v0-T148.

- [ ] **Step 1:** write the tests.

Write `schema/graph_returns_test.go`:

```go
package schema

import (
	"strings"
	"testing"
)

const returnsGraph = `
name: returns
version: 1.0.0
nodes:
  - { id: plan, kind: agent, role: planner, prompt: p.md, scratch: true }
  - { id: ready, kind: tasks, from: docs/tasks.md, back_to: plan, returns: 3 }
  - id: tasks
    kind: foreach
    over: tasks
    nodes:
      - { id: implement, kind: loop, realm: leaf, role: implementer }
      - { id: land, kind: merge, realm: leaf, back_to: implement }
      - { id: move, kind: pointer, realm: leaf, back_to: implement, returns: 1 }
`

func TestARefusalCanGoBackIntoAnEarlierNodeAFewTimes(t *testing.T) {
	g, err := ParseGraph("graph.yaml", []byte(returnsGraph))
	if err != nil {
		t.Fatalf("ParseGraph() = %v", err)
	}
	ready, body := g.Nodes[1], g.Nodes[2].Body
	if ready.BackTo != "plan" || ready.Returns != 3 {
		t.Errorf("tasks = %+v", ready)
	}
	if body[1].BackTo != "implement" || body[1].Returns != DefaultReturns || DefaultReturns != 2 {
		t.Errorf("merge = %+v; returns default to %d", body[1], DefaultReturns)
	}
	if body[2].Returns != 1 {
		t.Errorf("pointer = %+v", body[2])
	}
}

func TestParseGraphRefusesBadReturns(t *testing.T) {
	head := "name: g\nversion: 1.0.0\nnodes:\n"
	agent := "  - { id: a, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n"
	const bySchema = "jsonschema validation failed"
	cases := map[string]struct{ nodes, want string }{
		"returns without back_to":        {agent + "  - { id: m, kind: merge, repo: repos/app, checks: [unit], returns: 2 }\n", bySchema},
		"zero returns":                   {agent + "  - { id: m, kind: merge, repo: repos/app, checks: [unit], back_to: a, returns: 0 }\n", bySchema},
		"six returns":                    {agent + "  - { id: m, kind: merge, repo: repos/app, checks: [unit], back_to: a, returns: 6 }\n", bySchema},
		"back_to a node that isn't":      {agent + "  - { id: m, kind: merge, repo: repos/app, checks: [unit], back_to: nope }\n", "must be an agent or loop node before it"},
		"back_to an exec node":           {"  - { id: e, kind: exec, run: [echo] }\n  - { id: m, kind: merge, repo: repos/app, checks: [unit], back_to: e }\n", "must be an agent or loop node before it"},
		"back_to a later node":           {"  - { id: m, kind: merge, repo: repos/app, checks: [unit], back_to: a }\n" + agent, "must be an agent or loop node before it"},
		"back_to itself":                 {agent + "  - { id: p, kind: pointer, repo: repos/app, back_to: p }\n", "must be an agent or loop node before it"},
		"back_to on an agent":            {agent + "  - { id: b, kind: agent, role: planner, prompt: p.md, repo: repos/app, back_to: a }\n", bySchema},
		"back_to on init":                {agent + "  - { id: i, kind: init, from: docs/leaves.yaml, back_to: a }\n", bySchema},
		"back_to from a body to outside": {agent + "  - id: t\n    kind: foreach\n    over: tasks\n    nodes:\n      - { id: implement, kind: loop, realm: leaf, role: implementer }\n      - { id: land, kind: merge, realm: leaf, back_to: a }\n", "must be an agent or loop node before it"},
	}
	for name, c := range cases {
		_, err := ParseGraph("graph.yaml", []byte(head+c.nodes))
		if err == nil || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: ParseGraph() = %v, want an error containing %q", name, err, c.want)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/graph_returns_test.go:29:11: ready.BackTo undefined (type Node has no field or method BackTo)
schema/graph_returns_test.go:29:37: ready.Returns undefined (type Node has no field or method Returns)
schema/graph_returns_test.go:32:13: body[1].BackTo undefined (type Node has no field or method BackTo)
```

- [ ] **Step 3:** write the code.

Apply to `schema/graph.go`:

```diff
diff --git a/schema/graph.go b/schema/graph.go
index 5dd5217..5f63804 100644
--- a/schema/graph.go
+++ b/schema/graph.go
@@ -35,6 +35,13 @@ const (
 	KindInit    NodeKind = "init"    // Odin creates the leaves the spec names, each from its realm's template (spec §4.2, §4.1)
 )
 
+// DefaultReturns is how many times a refusal may send a run back into the node named by back_to when the
+// node sets no returns, and MaxReturns the most it may set.
+const (
+	DefaultReturns = 2
+	MaxReturns     = 5
+)
+
 // RealmFrom says whose files a node uses: the lead realm's (the default) or the realm of the task's leaf.
 const (
 	RealmLead = "lead"
@@ -70,6 +77,9 @@ type Node struct {
 	From    string   `yaml:"from"`    // publish: the scratch agent whose output is published; tasks: the tasks.md, by glob; init: the leaves file
 	To      string   `yaml:"to"`      // publish: the folder of the project its files go to
 
+	BackTo  string `yaml:"back_to"` // merge, pointer, tasks: the earlier agent or loop node a refusal goes back into, with the refusal as its input
+	Returns int    `yaml:"returns"` // merge, pointer, tasks: how many times it may go back; DefaultReturns when back_to is set and this is not
+
 	Over      string `yaml:"over"`  // foreach: what it repeats for; only "tasks"
 	Body      []Node `yaml:"nodes"` // foreach: the nodes that run for each task, in the task's leaf
 	RealmFrom string `yaml:"realm"` // loop, merge, pointer in a foreach body: "leaf", the realm of the task's leaf supplies the prompt and the checks
@@ -198,6 +208,14 @@ func (c *graphCheck) scope(nodes []Node, body bool) error {
 		if err := c.stage(n, nodes[:i]); err != nil {
 			return err
 		}
+		if n.BackTo != "" {
+			if j, ok := at[n.BackTo]; !ok || j >= i || (nodes[j].Kind != KindAgent && nodes[j].Kind != KindLoop) {
+				return fmt.Errorf("%s: node %s goes back to %q, which must be an agent or loop node before it", file, n.ID, n.BackTo)
+			}
+			if n.Returns == 0 {
+				n.Returns = DefaultReturns
+			}
+		}
 		if n.Kind == KindForeach {
 			if err := c.scope(n.Body, true); err != nil {
 				return err
```

Apply to `schema/graph.schema.json`:

```diff
diff --git a/schema/graph.schema.json b/schema/graph.schema.json
index e6b8579..4acde6f 100644
--- a/schema/graph.schema.json
+++ b/schema/graph.schema.json
@@ -87,8 +87,11 @@
             "kind": { "const": "merge" },
             "repo": { "$ref": "#/$defs/repo" },
             "checks": { "$ref": "#/$defs/names", "minItems": 1 },
-            "timeout": { "$ref": "#/$defs/duration" }
-          }
+            "timeout": { "$ref": "#/$defs/duration" },
+            "back_to": { "$ref": "#/$defs/id" },
+            "returns": { "type": "integer", "minimum": 1, "maximum": 5 }
+          },
+          "dependentRequired": { "returns": ["back_to"] }
         },
         {
           "additionalProperties": false,
@@ -100,8 +103,11 @@
             "checks": { "$ref": "#/$defs/names" },
             "acceptance": { "$ref": "#/$defs/names" },
             "generated": { "type": "array", "items": { "type": "string", "minLength": 1 } },
-            "timeout": { "$ref": "#/$defs/duration" }
-          }
+            "timeout": { "$ref": "#/$defs/duration" },
+            "back_to": { "$ref": "#/$defs/id" },
+            "returns": { "type": "integer", "minimum": 1, "maximum": 5 }
+          },
+          "dependentRequired": { "returns": ["back_to"] }
         },
         {
           "additionalProperties": false,
@@ -136,10 +142,22 @@
           "required": ["from"],
           "properties": {
             "id": { "$ref": "#/$defs/id" },
-            "kind": { "enum": ["tasks", "init"] },
+            "kind": { "const": "init" },
             "from": { "type": "string", "minLength": 1 }
           }
         },
+        {
+          "additionalProperties": false,
+          "required": ["from"],
+          "properties": {
+            "id": { "$ref": "#/$defs/id" },
+            "kind": { "const": "tasks" },
+            "from": { "type": "string", "minLength": 1 },
+            "back_to": { "$ref": "#/$defs/id" },
+            "returns": { "type": "integer", "minimum": 1, "maximum": 5 }
+          },
+          "dependentRequired": { "returns": ["back_to"] }
+        },
         {
           "additionalProperties": false,
           "required": ["over", "nodes"],
@@ -198,8 +216,11 @@
             "id": { "$ref": "#/$defs/id" },
             "kind": { "const": "merge" },
             "realm": { "const": "leaf" },
-            "timeout": { "$ref": "#/$defs/duration" }
-          }
+            "timeout": { "$ref": "#/$defs/duration" },
+            "back_to": { "$ref": "#/$defs/id" },
+            "returns": { "type": "integer", "minimum": 1, "maximum": 5 }
+          },
+          "dependentRequired": { "returns": ["back_to"] }
         },
         {
           "additionalProperties": false,
@@ -210,8 +231,11 @@
             "realm": { "const": "leaf" },
             "acceptance": { "$ref": "#/$defs/names" },
             "generated": { "type": "array", "items": { "type": "string", "minLength": 1 } },
-            "timeout": { "$ref": "#/$defs/duration" }
-          }
+            "timeout": { "$ref": "#/$defs/duration" },
+            "back_to": { "$ref": "#/$defs/id" },
+            "returns": { "type": "integer", "minimum": 1, "maximum": 5 }
+          },
+          "dependentRequired": { "returns": ["back_to"] }
         },
         {
           "additionalProperties": false,
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T150: a plan's tasks.md is read into features, exactly, with its limits

Spec §4.2 and the canonical artifacts: "Odin derives `features.json` from `tasks.md`", and "Odin rejects output that doesn't conform". The planner is an agent, so the file is data: it is read exactly and bounded.

**Files (in `gungnir`):**
- Create: `schema/tasks.go`, `schema/tasks_test.go`

**Interfaces:**
- Produces: `schema.Feature{ID, Title; Criteria []string; Test, Layer, Size string; DependsOn []string; Line int}`; `(Feature).Slug()`, the id as a node id; `ParseTasks(file string, data []byte) ([]Feature, error)`; `MaxTasksFile` (1 MiB) and `MaxTasks` (200); `SizeS`, `SizeM`, `SizeL`.
- A task is a heading of level two or three, `## <id>: <title>` or `### Task <id>: <title>`, with an id that holds a digit; its fields are the bullets `**Acceptance criteria:**` (a checkbox for each, continuation lines joined), `**Named test:**`, `**Layer:**` (`layer/x` reads as `repos/x`), `**Size:**` (the first letter) and `**Depends on:**` (`nothing`, `none` or a list of ids). Everything inside a code fence is ignored, and a heading that is not a task ends the task before it.
- Refused: an id twice, a field twice, a checkbox outside the criteria, an unclosed fence, no task, more than `MaxTasks`, a file over `MaxTasksFile`. A task with fields missing parses: the readiness check refuses it, with the reasons.

**Acceptance criteria:**
- [ ] The canonical layout parses into the tasks, criteria, test, layer, size and dependencies it holds, and ignores a heading inside a fence.
- [ ] A heading that is not a task ends the task before it.
- [ ] Every refusal above is a test case.

**Named test:** `go test ./schema -run 'TestParseTasksReadsTheCanonicalLayout|TestAHeadingThatIsNotATaskEndsTheTaskBeforeIt|TestParseTasksRefusesWhatItCannotReadExactly|TestParseTasksLeavesMissingFieldsToTheReadinessCheck'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (300). **Depends on:** v0-T149.

- [ ] **Step 1:** write the tests.

Write `schema/tasks_test.go`:

````go
package schema

import (
	"slices"
	"strings"
	"testing"
)

const planTasks = `---
title: Tasks of the gallery
status: draft
---

# Tasks

Some words before the first task.

## gallery-T001: the api owns galleries

- **Files:** ` + "`repos/api/gallery.go`" + `
- **Acceptance criteria:**
  - [ ] a client can list the galleries they own
  - [x] another client's galleries are never listed,
        even by id
- **Named test:** ` + "`repos/api/gallery_test.go`" + ` ` + "`TestAClientListsOnlyTheirGalleries`" + `
- **Layer:** ` + "`repos/api`" + `
- **Size:** S
- **Depends on:** nothing

### Task gallery-T002: the web shows them

- **Acceptance criteria:**
  - [ ] the page lists the galleries
- **Named test:** gallery.spec.ts: lists galleries
- **Layer:** layer/web
- **Size:** M (about 200 lines)
- **Depends on:** gallery-T001, ` + "`gallery-T003`" + `

` + "```" + `
## gallery-T999: a heading inside a code block is not a task
` + "```" + `

## gallery-T003: the api signs download urls
- **Acceptance criteria:**
  - [ ] a signed url expires
- **Named test:** TestSignedURLsExpire
- **Layer:** repos/api
- **Size:** S
- **Depends on:** none
`

func TestParseTasksReadsTheCanonicalLayout(t *testing.T) {
	fs, err := ParseTasks("tasks.md", []byte(planTasks))
	if err != nil {
		t.Fatalf("ParseTasks() = %v", err)
	}
	if len(fs) != 3 {
		t.Fatalf("got %d tasks, want 3 (a heading in a code block is not one): %+v", len(fs), fs)
	}
	a, b, c := fs[0], fs[1], fs[2]
	if a.ID != "gallery-T001" || a.Title != "the api owns galleries" || a.Layer != "repos/api" || a.Size != "S" || len(a.DependsOn) != 0 {
		t.Errorf("first task = %+v", a)
	}
	if len(a.Criteria) != 2 || !strings.HasSuffix(a.Criteria[1], "even by id") || !strings.Contains(a.Criteria[1], "never listed,") {
		t.Errorf("criteria = %q", a.Criteria)
	}
	if !strings.Contains(a.Test, "TestAClientListsOnlyTheirGalleries") {
		t.Errorf("test = %q", a.Test)
	}
	if b.ID != "gallery-T002" || b.Layer != "repos/web" || b.Size != "M" || !slices.Equal(b.DependsOn, []string{"gallery-T001", "gallery-T003"}) {
		t.Errorf("second task = %+v", b)
	}
	if c.ID != "gallery-T003" || len(c.DependsOn) != 0 || c.Line == 0 {
		t.Errorf("third task = %+v", c)
	}
	if a.Slug() != "gallery-t001" || (Feature{ID: "007"}).Slug() != "t007" || (Feature{ID: "A_b.C"}).Slug() != "a-b-c" {
		t.Errorf("slugs: %q %q %q", a.Slug(), (Feature{ID: "007"}).Slug(), (Feature{ID: "A_b.C"}).Slug())
	}
}

func TestAHeadingThatIsNotATaskEndsTheTaskBeforeIt(t *testing.T) {
	fs, err := ParseTasks("tasks.md", []byte("## a-T1: x\n- **Layer:** repos/a\n\n## Notes: extra\n- **Layer:** repos/elsewhere\n- **Size:** L\n"))
	if err != nil || len(fs) != 1 || fs[0].Layer != "repos/a" || fs[0].Size != "" {
		t.Errorf("ParseTasks() = %+v, %v; the notes' bullets are not task a-T1's", fs, err)
	}
}

func TestParseTasksRefusesWhatItCannotReadExactly(t *testing.T) {
	cases := map[string]string{
		"an id used twice":            "## a-T1: x\n- **Layer:** repos/a\n## a-T1: y\n",
		"a field twice":               "## a-T1: x\n- **Layer:** repos/a\n- **Layer:** repos/b\n",
		"a criterion outside a field": "## a-T1: x\n  - [ ] stray\n- **Layer:** repos/a\n",
		"no tasks":                    "# Tasks\n\nNothing here.\n",
		"a file that is too big":      "## a-T1: x\n" + strings.Repeat("a line of words\n", 70000),
		"an id with a slash":          "## a/T1: x\n- **Layer:** repos/a\n",
		"an unclosed code fence":      "## a-T1: x\n```\n- **Layer:** repos/a\n",
	}
	for name, md := range cases {
		if _, err := ParseTasks("tasks.md", []byte(md)); err == nil {
			t.Errorf("%s: ParseTasks() = nil error", name)
		}
	}
}

func TestParseTasksLeavesMissingFieldsToTheReadinessCheck(t *testing.T) {
	fs, err := ParseTasks("tasks.md", []byte("## a-T1: only a title\n"))
	if err != nil || len(fs) != 1 || fs[0].Layer != "" || fs[0].Size != "" || len(fs[0].Criteria) != 0 {
		t.Errorf("ParseTasks() = %+v, %v; a task with fields missing is the readiness check's to refuse", fs, err)
	}
}
````

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/tasks_test.go:53:13: undefined: ParseTasks
schema/tasks_test.go:76:36: undefined: Feature
schema/tasks_test.go:77:42: undefined: Feature
```

- [ ] **Step 3:** write the code.

Write `schema/tasks.go`:

````go
package schema

import (
	"fmt"
	"regexp"
	"strings"
)

// Feature is one task of a plan's tasks.md, as Odin keeps it in features.json (spec §4.2, §5 canonical
// artifacts). The planner writes the file; its text is data, never an instruction.
type Feature struct {
	ID        string   `json:"id"`       // stable, scoped to the plan: <plan>-T001
	Title     string   `json:"title"`    // the heading's words after the id
	Criteria  []string `json:"criteria"` // the acceptance criteria, one for each checkbox
	Test      string   `json:"test"`     // the named test: the file and the test that will prove it
	Layer     string   `json:"layer"`    // the leaf that holds the work, by path in the project, such as repos/api
	Size      string   `json:"size"`     // S (under 100 changed lines), M (100 to 400) or L (split it)
	DependsOn []string `json:"depends_on"`
	Line      int      `json:"line"` // where the task's heading is in tasks.md
}

// Task sizes of the Definition of Ready.
const (
	SizeS = "S"
	SizeM = "M"
	SizeL = "L"
)

// MaxTasksFile is the biggest tasks.md Odin reads, and MaxTasks the most tasks it holds: a plan is
// written by an agent, and what it writes is bounded before anything reads it.
const (
	MaxTasksFile = 1 << 20
	MaxTasks     = 200
)

var (
	taskHeading = regexp.MustCompile(`^#{2,3}\s+(?:Task\s+)?([A-Za-z0-9][A-Za-z0-9._-]*):\s*(.*?)\s*$`)
	anyHeading  = regexp.MustCompile(`^#{1,3}\s`)
	fieldLine   = regexp.MustCompile(`^- \*\*([A-Za-z ]+?):\*\*\s*(.*)$`)
	checkbox    = regexp.MustCompile(`^\s+- \[[ xX]\]\s+(.*)$`)
	noneWord    = regexp.MustCompile(`^(?i:nothing|none|no one|n/a|-|—)$`)
	splitIDs    = regexp.MustCompile(`[\s,;&]+`)
	notSlug     = regexp.MustCompile(`[^a-z0-9]+`)
)

// Slug is the task's id as a node id: lower case words joined by dashes, starting with a letter.
func (f Feature) Slug() string {
	s := strings.Trim(notSlug.ReplaceAllString(strings.ToLower(f.ID), "-"), "-")
	if s == "" || s[0] < 'a' || s[0] > 'z' {
		s = "t" + s
	}
	return s
}

// ParseTasks reads a plan's tasks.md. A task is a heading of the second or third level, "## <id>:
// <title>" or "### Task <id>: <title>", the id holding a digit, and the bullets under it: "**Acceptance criteria:**" with a
// checkbox for each criterion, "**Named test:**", "**Layer:**", "**Size:**" and "**Depends on:**". Other
// bullets and prose are ignored, and so is everything inside a code fence. A task with fields missing
// parses (the readiness check refuses it, with the reasons); an id used twice, a field given twice, a
// criterion outside a field, an unclosed fence, a file with no task and a file over MaxTasksFile are
// errors.
func ParseTasks(file string, data []byte) ([]Feature, error) {
	if len(data) > MaxTasksFile {
		return nil, fmt.Errorf("%s: %d bytes is more than the %d a tasks file may hold", file, len(data), MaxTasksFile)
	}
	var out []Feature
	var cur *Feature
	seenID := map[string]bool{}
	seenField := map[string]bool{}
	field := ""
	fenced := false
	for i, line := range strings.Split(strings.ReplaceAll(string(data), "\r\n", "\n"), "\n") {
		n := i + 1
		if strings.HasPrefix(strings.TrimSpace(line), "```") {
			fenced = !fenced
			continue
		}
		if fenced {
			continue
		}
		if m := taskHeading.FindStringSubmatch(line); m != nil && strings.ContainsAny(m[1], "0123456789") {
			if seenID[m[1]] {
				return nil, fmt.Errorf("%s:%d: task id %s is used twice", file, n, m[1])
			}
			seenID[m[1]] = true
			if len(out) == MaxTasks {
				return nil, fmt.Errorf("%s:%d: more than %d tasks; a plan this big needs splitting", file, n, MaxTasks)
			}
			out = append(out, Feature{ID: m[1], Title: m[2], Line: n})
			cur, field, seenField = &out[len(out)-1], "", map[string]bool{}
			continue
		}
		if anyHeading.MatchString(line) { // another section: the bullets under it are not the last task's
			cur, field = nil, ""
			continue
		}
		if cur == nil {
			continue
		}
		if m := fieldLine.FindStringSubmatch(line); m != nil {
			field = strings.ToLower(m[1])
			if seenField[field] {
				return nil, fmt.Errorf("%s:%d: task %s gives %q twice", file, n, cur.ID, m[1])
			}
			seenField[field] = true
			setField(cur, field, m[2])
			continue
		}
		if m := checkbox.FindStringSubmatch(line); m != nil {
			if field != "acceptance criteria" {
				return nil, fmt.Errorf("%s:%d: a checkbox outside \"Acceptance criteria\" in task %s", file, n, cur.ID)
			}
			cur.Criteria = append(cur.Criteria, strings.TrimSpace(m[1]))
			continue
		}
		// A line that continues the last criterion, or the last field's value.
		if t := strings.TrimSpace(line); t != "" && strings.HasPrefix(line, "  ") {
			continueField(cur, field, t)
		} else if t == "" || !strings.HasPrefix(line, "-") {
			field = ""
		}
	}
	if fenced {
		return nil, fmt.Errorf("%s: a code fence is not closed", file)
	}
	if len(out) == 0 {
		return nil, fmt.Errorf("%s: no task found; a task is a heading such as \"## plan-T001: title\"", file)
	}
	for i := range out {
		finish(&out[i])
	}
	return out, nil
}

// setField records the first line of a field.
func setField(f *Feature, field, value string) {
	switch field {
	case "named test":
		f.Test = value
	case "layer":
		f.Layer = value
	case "size":
		f.Size = value
	case "depends on":
		f.DependsOn = []string{value}
	}
}

// continueField adds a continuation line to the last criterion, or to the field's value.
func continueField(f *Feature, field, text string) {
	switch field {
	case "acceptance criteria":
		if n := len(f.Criteria); n > 0 {
			f.Criteria[n-1] += " " + text
		}
	case "named test":
		f.Test += " " + text
	case "layer":
		f.Layer += " " + text
	case "size":
		f.Size += " " + text
	case "depends on":
		f.DependsOn = append(f.DependsOn, text)
	}
}

// finish turns the raw values into the fields' meanings: a layer as a path, a size as a letter, and the
// ids a task depends on.
func finish(f *Feature) {
	f.Test = strings.TrimSpace(f.Test)
	f.Layer = strings.Trim(strings.TrimSpace(f.Layer), "`")
	if rest, ok := strings.CutPrefix(f.Layer, "layer/"); ok {
		f.Layer = "repos/" + rest
	}
	if words := strings.Fields(strings.ReplaceAll(f.Size, "`", "")); len(words) > 0 {
		if letter := strings.ToUpper(strings.Trim(words[0], "().,:")); len(letter) == 1 {
			f.Size = letter
		}
	}
	raw := strings.ReplaceAll(strings.Join(f.DependsOn, " "), "`", "")
	f.DependsOn = nil
	if noneWord.MatchString(strings.TrimSpace(raw)) {
		return
	}
	for _, w := range splitIDs.Split(raw, -1) {
		if w != "" && !strings.EqualFold(w, "and") {
			f.DependsOn = append(f.DependsOn, w)
		}
	}
}
````

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T151: the Definition of Ready, applied to a plan's tasks: every reason is listed, and L tasks go back to be split

The DoR check (spec §4.2) rejects a task with no acceptance criteria, named test, layer or size, with an open blocker, or of size L, which "MUST be split, so it goes back to the planner". Its answer goes back into the planner's prompt, so it lists every problem and is bounded.

**Files (in `gungnir`):**
- Create: `schema/ready.go`, `schema/ready_test.go`

**Interfaces:**
- Produces: `schema.CheckReady(fs []Feature, leaves []string) error`, a `*ReadinessError{Problems []Problem}`; `Problem{Task, Text}`; `MaxReadinessText` (6,000 bytes); `ReadyOrder([]Feature) ([]Feature, error)`, the plan's order with each task after what it depends on. `leaves`, when not nil, are the layers a task may name.

**Acceptance criteria:**
- [ ] A plan of ready tasks passes. Each reason a task is not ready is listed: no criteria or blank ones, no test, no layer, a layer that is not one of `leaves`, no size, size L ("split it"), a size of words, a blocker that is not in the plan, a task that depends on itself, a ring, two ids that are one node id.
- [ ] All the problems of all the tasks are listed, not the first; the text is cut at `MaxReadinessText`.
- [ ] `ReadyOrder` keeps the file's order, holding a task back until its blockers are placed.

**Named test:** `go test ./schema -run 'TestAPlanOfReadyTasksPasses|TestCheckReadyListsEveryReasonATaskIsNotReady|TestTheReadinessErrorIsBounded|TestReadyOrderPutsEveryTaskAfterWhatItDependsOn'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (212). **Depends on:** v0-T150.

- [ ] **Step 1:** write the tests.

Write `schema/ready_test.go`:

```go
package schema

import (
	"errors"
	"strings"
	"testing"
)

func ready(id, layer string, deps ...string) Feature {
	return Feature{ID: id, Title: id, Criteria: []string{"it works"}, Test: "TestIt", Layer: layer, Size: SizeS, DependsOn: deps}
}

func TestAPlanOfReadyTasksPasses(t *testing.T) {
	fs := []Feature{ready("p-T1", "repos/api"), ready("p-T2", "repos/web", "p-T1")}
	fs[1].Size = SizeM
	if err := CheckReady(fs, []string{"repos/api", "repos/web"}); err != nil {
		t.Fatalf("CheckReady() = %v", err)
	}
	if err := CheckReady(fs, nil); err != nil {
		t.Errorf("with no leaf list, the layers are not looked up: %v", err)
	}
}

func TestCheckReadyListsEveryReasonATaskIsNotReady(t *testing.T) {
	leaves := []string{"repos/api", "repos/web"}
	bad := func(mutate func(*Feature)) []Feature {
		f := ready("p-T1", "repos/api")
		mutate(&f)
		return []Feature{f}
	}
	cases := map[string]struct {
		fs   []Feature
		want string
	}{
		"no criteria":                  {bad(func(f *Feature) { f.Criteria = nil }), "no acceptance criteria"},
		"a blank criterion":            {bad(func(f *Feature) { f.Criteria = []string{"  "} }), "no acceptance criteria"},
		"no named test":                {bad(func(f *Feature) { f.Test = " " }), "no named test"},
		"no layer":                     {bad(func(f *Feature) { f.Layer = "" }), "no layer"},
		"an unknown layer":             {bad(func(f *Feature) { f.Layer = "repos/db" }), `layer "repos/db" is not a leaf of this project (repos/api, repos/web)`},
		"no size":                      {bad(func(f *Feature) { f.Size = "" }), "no size"},
		"a size L":                     {bad(func(f *Feature) { f.Size = SizeL }), "split it"},
		"a size of words":              {bad(func(f *Feature) { f.Size = "Small" }), `size "Small" is not S, M or L`},
		"an unknown blocker":           {bad(func(f *Feature) { f.DependsOn = []string{"p-T9"} }), `depends on "p-T9", which is not a task of this plan`},
		"itself":                       {bad(func(f *Feature) { f.DependsOn = []string{"p-T1"} }), "depends on itself"},
		"a ring of two":                {[]Feature{ready("a-1", "repos/api", "a-2"), ready("a-2", "repos/api", "a-1")}, "ring"},
		"a ring of three":              {[]Feature{ready("a-1", "repos/api", "a-3"), ready("a-2", "repos/api", "a-1"), ready("a-3", "repos/api", "a-2")}, "ring"},
		"two ids that are one node id": {[]Feature{ready("A_1", "repos/api"), ready("a-1", "repos/api")}, "same node id"},
	}
	for name, c := range cases {
		err := CheckReady(c.fs, leaves)
		var re *ReadinessError
		if !errors.As(err, &re) || !strings.Contains(err.Error(), c.want) {
			t.Errorf("%s: CheckReady() = %v, want a ReadinessError containing %q", name, err, c.want)
		}
	}
	err := CheckReady([]Feature{{ID: "p-T1"}, {ID: "p-T2", Layer: "repos/api"}}, leaves)
	var re *ReadinessError
	if !errors.As(err, &re) || len(re.Problems) < 5 {
		t.Fatalf("CheckReady() = %v; every reason for every task is listed, not only the first", err)
	}
	if re.Problems[0].Task != "p-T1" {
		t.Errorf("problems = %+v", re.Problems)
	}
	if err := CheckReady(nil, leaves); err == nil {
		t.Error("a plan with no task was ready")
	}
}

func TestTheReadinessErrorIsBounded(t *testing.T) {
	var fs []Feature
	for i := 0; i < MaxTasks; i++ {
		fs = append(fs, Feature{ID: "p-T" + strings.Repeat("9", 1+i%7) + string(rune('a'+i%26)), Title: strings.Repeat("x", 500)})
	}
	err := CheckReady(fs, nil)
	if err == nil || len(err.Error()) > 8000 || !strings.Contains(err.Error(), "more") {
		t.Errorf("a plan of %d unready tasks gave an error of %d bytes; it goes back into a prompt, so it is cut", len(fs), len(err.Error()))
	}
}

func TestReadyOrderPutsEveryTaskAfterWhatItDependsOn(t *testing.T) {
	fs := []Feature{ready("c", "r", "b"), ready("a", "r"), ready("b", "r", "a"), ready("d", "r")}
	got, err := ReadyOrder(fs)
	if err != nil {
		t.Fatal(err)
	}
	var ids []string
	for _, f := range got {
		ids = append(ids, f.ID)
	}
	if strings.Join(ids, ",") != "a,b,c,d" {
		t.Errorf("order = %v; the file's order, held back until a task's blockers are done", ids)
	}
	if _, err := ReadyOrder([]Feature{ready("a", "r", "b"), ready("b", "r", "a")}); err == nil {
		t.Error("a ring has no order")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/ready_test.go:16:12: undefined: CheckReady
schema/ready_test.go:19:12: undefined: CheckReady
schema/ready_test.go:50:10: undefined: CheckReady
```

- [ ] **Step 3:** write the code.

Write `schema/ready.go`:

```go
package schema

import (
	"fmt"
	"slices"
	"strings"
)

// Problem is one reason a task is not ready.
type Problem struct{ Task, Text string }

// ReadinessError lists why tasks are not ready (the Definition of Ready, spec §4.2). Its text goes back
// to the planner as input, so it names each problem and is cut short.
type ReadinessError struct{ Problems []Problem }

// MaxReadinessText bounds the error's text: it becomes part of a prompt.
const MaxReadinessText = 6000

func (e *ReadinessError) Error() string {
	var b strings.Builder
	fmt.Fprintf(&b, "the plan has %d problem(s) that keep its tasks from being ready:\n", len(e.Problems))
	for i, p := range e.Problems {
		line := fmt.Sprintf("- %s: %s\n", p.Task, p.Text)
		if b.Len()+len(line) > MaxReadinessText {
			fmt.Fprintf(&b, "- ... and %d more\n", len(e.Problems)-i)
			break
		}
		b.WriteString(line)
	}
	return b.String()
}

// CheckReady applies the Definition of Ready to a plan: every task has acceptance criteria, a named
// test, a layer, a size of S or M (L means split it), and dependencies that are tasks of the plan,
// without a ring; and no two ids are the same node id. leaves, when given, are the paths a layer may
// name. The error is a *ReadinessError that lists everything, not the first problem.
func CheckReady(fs []Feature, leaves []string) error {
	if len(fs) == 0 {
		return &ReadinessError{Problems: []Problem{{"plan", "has no task"}}}
	}
	var ps []Problem
	add := func(f Feature, format string, a ...any) { ps = append(ps, Problem{f.ID, fmt.Sprintf(format, a...)}) }
	byID := map[string]Feature{}
	slugs := map[string]string{}
	for _, f := range fs {
		byID[f.ID] = f
		if other, dup := slugs[f.Slug()]; dup {
			add(f, "id %q and %q are the same node id (%s)", f.ID, other, f.Slug())
		}
		slugs[f.Slug()] = f.ID
	}
	for _, f := range fs {
		if !slices.ContainsFunc(f.Criteria, func(c string) bool { return strings.TrimSpace(c) != "" }) {
			add(f, "no acceptance criteria (a checkbox under \"Acceptance criteria\")")
		}
		if strings.TrimSpace(f.Test) == "" {
			add(f, "no named test: name the file and the test that will prove it")
		}
		switch {
		case f.Layer == "":
			add(f, "no layer: name the leaf that holds the work")
		case leaves != nil && !slices.Contains(leaves, f.Layer):
			add(f, "layer %q is not a leaf of this project (%s)", f.Layer, strings.Join(leaves, ", "))
		}
		switch f.Size {
		case SizeS, SizeM:
		case SizeL:
			add(f, "size L: split it into tasks of size S (under 100 changed lines) or M (100 to 400)")
		case "":
			add(f, "no size: S (under 100 changed lines) or M (100 to 400)")
		default:
			add(f, "size %q is not S, M or L", f.Size)
		}
		for _, d := range f.DependsOn {
			switch _, ok := byID[d]; {
			case d == f.ID:
				add(f, "depends on itself")
			case !ok:
				add(f, "depends on %q, which is not a task of this plan", d)
			}
		}
	}
	if len(ps) == 0 {
		if _, err := ReadyOrder(fs); err != nil {
			ps = append(ps, Problem{"plan", err.Error()})
		}
	}
	if len(ps) > 0 {
		return &ReadinessError{Problems: ps}
	}
	return nil
}

// ReadyOrder returns the tasks in the order they can be built: the plan's own order, with a task held
// back until everything it depends on is placed. It refuses a ring of dependencies.
func ReadyOrder(fs []Feature) ([]Feature, error) {
	done := map[string]bool{}
	var out []Feature
	left := slices.Clone(fs)
	for len(left) > 0 {
		next := slices.IndexFunc(left, func(f Feature) bool {
			return !slices.ContainsFunc(f.DependsOn, func(d string) bool { return !done[d] })
		})
		if next < 0 {
			var ring []string
			for _, f := range left {
				ring = append(ring, f.ID)
			}
			return nil, fmt.Errorf("these tasks depend on each other in a ring (or on a task that is not in the plan): %s", strings.Join(ring, ", "))
		}
		out = append(out, left[next])
		done[left[next].ID] = true
		left = slices.Delete(left, next, next+1)
	}
	return out, nil
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T152: the spec stage names the leaves of a product and the realm of each, in a file Odin reads exactly

Change `realm-leaf-naming`: "the run's spec stage names the product's leaves and the realm that provides each one, and the operator approves it at the spec gate". The file is `leaves.yaml`.

**Files (in `gungnir`):**
- Create: `schema/leaves.go`, `schema/leaves.schema.json`, `schema/leaves_test.go`

**Interfaces:**
- Produces: `schema.Leaves{Leaves map[string]LeafSpec}`, `LeafSpec{Realm, RealmVersion, Description string; Consumes []string}`; `ParseLeaves(file string, data []byte) (*Leaves, error)`; `(*Leaves).Paths()` and `Pins()`. Up to 20 leaves; each path inside the project, outside `.git` and `.factory`, none inside another; a description of one line up to 200 characters; consumers as in the umbrella (not itself, not twice, no ring among the listed leaves); a consumer the file does not list may be a leaf the project has.

**Acceptance criteria:**
- [ ] A file naming an API and a web leaf that consumes it parses; `Paths()` and `Pins()` give them sorted.
- [ ] A missing realm, version or description, a description of two lines or over 200 characters, a path that climbs or sits in `.git` or `.factory`, a leaf inside a leaf, an unknown field, a self-consuming leaf, a consumer twice or that climbs, a ring and twenty-one leaves are refused.

**Named test:** `go test ./schema -run 'TestTheSpecStageNamesTheLeavesAndTheirRealms|TestParseLeavesRefuses'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (192). **Depends on:** v0-T142.

- [ ] **Step 1:** write the tests.

Write `schema/leaves_test.go`:

```go
package schema

import (
	"slices"
	"strings"
	"testing"
)

const leavesFile = `
leaves:
  repos/api:
    realm: helheim-go
    realm_version: 0.1.0
    description: The gallery's API.
  repos/web:
    realm: midgard-react
    realm_version: 0.1.0
    description: The gallery's web app.
    consumes: [repos/api]
`

func TestTheSpecStageNamesTheLeavesAndTheirRealms(t *testing.T) {
	l, err := ParseLeaves("leaves.yaml", []byte(leavesFile))
	if err != nil {
		t.Fatalf("ParseLeaves() = %v", err)
	}
	if !slices.Equal(l.Paths(), []string{"repos/api", "repos/web"}) {
		t.Errorf("Paths() = %q", l.Paths())
	}
	web := l.Leaves["repos/web"]
	if web.Realm != "midgard-react" || web.RealmVersion != "0.1.0" || !slices.Equal(web.Consumes, []string{"repos/api"}) || web.Description != "The gallery's web app." {
		t.Errorf("web = %+v", web)
	}
	pins := l.Pins()
	if len(pins) != 2 || pins[0] != (Pin{"helheim-go", "0.1.0", "repos/api"}) {
		t.Errorf("Pins() = %+v", pins)
	}
}

func TestParseLeavesRefuses(t *testing.T) {
	leaf := func(path, extra string) string {
		return "leaves:\n  " + path + ": { realm: helheim-go, realm_version: 0.1.0, description: x" + extra + " }\n"
	}
	cases := map[string]string{
		"no leaves":                  "leaves: {}\n",
		"a leaf with no realm":       "leaves:\n  repos/api: { realm_version: 0.1.0, description: x }\n",
		"a leaf with no version":     "leaves:\n  repos/api: { realm: helheim-go, description: x }\n",
		"a leaf with no description": "leaves:\n  repos/api: { realm: helheim-go, realm_version: 0.1.0 }\n",
		"a description of two lines": "leaves:\n  repos/api: { realm: helheim-go, realm_version: 0.1.0, description: \"a\\nb\" }\n",
		"a realm in capitals":        "leaves:\n  repos/api: { realm: Helheim, realm_version: 0.1.0, description: x }\n",
		"a path that climbs":         leaf("../api", ""),
		"a path in .git":             leaf(".git/api", ""),
		"a path in .factory":         leaf(".factory/api", ""),
		"an absolute path":           leaf("/srv/api", ""),
		"a leaf inside a leaf":       leaf("repos/api", "") + "  repos/api/sub: { realm: helheim-go, realm_version: 0.1.0, description: x }\n",
		"an unknown field":           leaf("repos/api", ", sandbox: off"),
		"a leaf consuming itself":    leaf("repos/api", ", consumes: [repos/api]"),
		"a leaf consuming twice":     leaf("repos/api", ", consumes: [repos/db, repos/db]"),
		"a consumer that climbs":     leaf("repos/api", ", consumes: [../db]"),
		"a ring":                     leaf("repos/a", ", consumes: [repos/b]") + "  repos/b: { realm: helheim-go, realm_version: 0.1.0, description: x, consumes: [repos/a] }\n",
	}
	cases["a description too long"] = "leaves:\n  repos/api: { realm: helheim-go, realm_version: 0.1.0, description: " + strings.Repeat("x", 201) + " }\n"
	for name, y := range cases {
		if _, err := ParseLeaves("leaves.yaml", []byte(y)); err == nil {
			t.Errorf("%s: ParseLeaves() = nil error", name)
		}
	}
	if _, err := ParseLeaves("leaves.yaml", []byte(leave21())); err == nil {
		t.Error("twenty-one leaves parsed; a product with that many leaves needs a company umbrella")
	}
}

func leave21() string {
	var b strings.Builder
	b.WriteString("leaves:\n")
	for i := 0; i < 21; i++ {
		b.WriteString("  repos/l" + string(rune('a'+i)) + ": { realm: helheim-go, realm_version: 0.1.0, description: x }\n")
	}
	return b.String()
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/leaves_test.go:23:12: undefined: ParseLeaves
schema/leaves_test.go:64:16: undefined: ParseLeaves
schema/leaves_test.go:68:15: undefined: ParseLeaves
```

- [ ] **Step 3:** write the code.

Write `schema/leaves.go`:

```go
package schema

import (
	"fmt"
	"path/filepath"
	"strings"
)

// Leaves is a product's leaves file (leaves.yaml): the leaves the spec stage names, and the realm that
// provides each one.
type Leaves struct {
	Leaves map[string]LeafSpec `yaml:"leaves"`
}

// LeafSpec is one leaf of the file.
type LeafSpec struct {
	Realm        string   `yaml:"realm"`
	RealmVersion string   `yaml:"realm_version"`
	Description  string   `yaml:"description"`        // the new repo's description
	Consumes     []string `yaml:"consumes,omitempty"` // sibling leaves this one calls
}

// ParseLeaves parses leaves.yaml. A leaf's path stays inside the project and outside .git and .factory,
// no leaf is inside another, and no leaf consumes itself, a leaf twice, or another in a ring. A leaf may
// consume one the file doesn't list: an earlier run made it, and Odin checks the project has it.
func ParseLeaves(file string, data []byte) (*Leaves, error) {
	var l Leaves
	if err := parseYAML(file, "leaves.schema.json", data, &l); err != nil {
		return nil, err
	}
	paths := l.Paths()
	for i, p := range paths {
		if !projectPath(p) {
			return nil, fmt.Errorf("%s: leaf %q must be a path inside the project, outside .git and .factory", file, p)
		}
		if i > 0 && strings.HasPrefix(p, paths[i-1]+"/") {
			return nil, fmt.Errorf("%s: leaf %q is inside leaf %q", file, p, paths[i-1])
		}
		seen := map[string]bool{}
		for _, q := range l.Leaves[p].Consumes {
			switch {
			case !filepath.IsLocal(q):
				return nil, fmt.Errorf("%s: leaf %s consumes %q, which must be a path inside the project", file, p, q)
			case q == p:
				return nil, fmt.Errorf("%s: leaf %s consumes itself", file, p)
			case seen[q]:
				return nil, fmt.Errorf("%s: leaf %s consumes %s twice", file, p, q)
			}
			seen[q] = true
		}
	}
	// A ring among the listed leaves is a ring of the umbrella they will be recorded in.
	u := &Umbrella{Children: map[string]Child{}}
	for _, p := range paths {
		u.Children[p] = Child{Kind: ChildLeaf, Consumes: l.Leaves[p].Consumes}
	}
	for _, p := range paths {
		var kept []string
		for _, q := range u.Children[p].Consumes {
			if _, listed := u.Children[q]; listed {
				kept = append(kept, q)
			}
		}
		c := u.Children[p]
		c.Consumes = kept
		u.Children[p] = c
	}
	if err := u.checkRing(file); err != nil {
		return nil, err
	}
	return &l, nil
}

// Paths returns the leaf paths, sorted.
func (l *Leaves) Paths() []string { return sortedKeys(l.Leaves) }

// Pins returns the realm pin of every leaf, by path.
func (l *Leaves) Pins() []Pin {
	var pins []Pin
	for _, p := range l.Paths() {
		pins = append(pins, Pin{l.Leaves[p].Realm, l.Leaves[p].RealmVersion, p})
	}
	return pins
}
```

Write `schema/leaves.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/leaves.schema.json",
  "title": "leaves.yaml",
  "description": "The leaves a product has and the realm that provides each one. The spec stage writes it, the operator approves it at the spec gate, and the init node creates each missing leaf from its realm's template (change realm-leaf-naming).",
  "type": "object",
  "additionalProperties": false,
  "required": ["leaves"],
  "properties": {
    "leaves": {
      "type": "object",
      "minProperties": 1,
      "maxProperties": 20,
      "propertyNames": { "pattern": "^[a-z0-9][a-z0-9._-]*(/[a-z0-9][a-z0-9._-]*)*$" },
      "additionalProperties": {
        "type": "object",
        "additionalProperties": false,
        "required": ["realm", "realm_version", "description"],
        "properties": {
          "realm": { "type": "string", "pattern": "^[a-z][a-z0-9]*(-[a-z0-9]+)*$" },
          "realm_version": { "type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$" },
          "description": { "type": "string", "pattern": "^[^\\n\\r]{1,200}$" },
          "consumes": { "type": "array", "items": { "type": "string", "minLength": 1 } }
        }
      }
    }
  }
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T153: ledger events for realms, published documents, ready tasks and returned refusals

Spec §10.1 lists the events a ledger holds. This phase adds the ones it needs to be audited: when a realm was loaded, when documents were published, when a plan's tasks were ready, when a refusal went back, and the life of a task.

**Files (in `gungnir`):**
- Create: `schema/event_realms_test.go`
- Modify: `event.go`, `schema/ledger-event.schema.json`

**Interfaces:**
- Produces: `EventRealmLoaded`, `EventDocsPublished`, `EventTasksReady`, `EventNodeReturned`, `EventTaskStarted`, `EventTaskDone`, `EventTaskBlocked`; the fields `Event.Realm`, `RealmVersion` and `Task` (`ygg.realm.name`, `ygg.realm.version`, `ygg.task.id`), and the ledger line schema that allows them (a realm name, a version and a node-id-shaped task).

**Acceptance criteria:**
- [ ] Every event name validates as a ledger line, and a line with the realm fields and one with a task validates.
- [ ] A realm name in capitals is refused.

**Named test:** `go test ./schema -run 'TestTheLedgerRecordsRealmsAndTasks|TestLedgerEventSchema'` in `gungnir`. **Layer:** `gungnir`. **Size:** S (61). **Depends on:** v0-T152.

- [ ] **Step 1:** write the tests.

Write `schema/event_realms_test.go`:

```go
package schema

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func TestTheLedgerRecordsRealmsAndTasks(t *testing.T) {
	e := event(gungnir.EventRealmLoaded)
	e.Realm, e.RealmVersion, e.Note = "midgard-react", "0.1.0", "sha256:abc"
	line, err := json.Marshal(e)
	if err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{`"ygg.realm.name":"midgard-react"`, `"ygg.realm.version":"0.1.0"`} {
		if !strings.Contains(string(line), key) {
			t.Errorf("line lacks %s:\n%s", key, line)
		}
	}
	if err := ValidateEvent(line); err != nil {
		t.Errorf("ValidateEvent() = %v", err)
	}
	for _, name := range []gungnir.EventName{gungnir.EventDocsPublished, gungnir.EventTasksReady, gungnir.EventNodeReturned,
		gungnir.EventTaskStarted, gungnir.EventTaskDone, gungnir.EventTaskBlocked} {
		e := event(name)
		e.Task = "gallery-t001"
		line, _ := json.Marshal(e)
		if !strings.Contains(string(line), `"ygg.task.id":"gallery-t001"`) || ValidateEvent(line) != nil {
			t.Errorf("%s: %s", name, line)
		}
	}
	bad := strings.Replace(string(line), `"midgard-react"`, `"Midgard React"`, 1)
	if ValidateEvent([]byte(bad)) == nil {
		t.Error("a realm name in capitals validated")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/event_realms_test.go:12:21: undefined: gungnir.EventRealmLoaded
schema/event_realms_test.go:13:4: e.Realm undefined (type gungnir.Event has no field or method Realm)
schema/event_realms_test.go:13:13: e.RealmVersion undefined (type gungnir.Event has no field or method RealmVersion)
```

- [ ] **Step 3:** write the code.

Apply to `event.go`:

```diff
diff --git a/event.go b/event.go
index cf6f7b0..688a161 100644
--- a/event.go
+++ b/event.go
@@ -38,6 +38,14 @@ const (
 	EventFindingRaised   EventName = "finding_raised"   // a check or reviewer reported a finding (spec §4.6)
 	EventFindingClosed   EventName = "finding_closed"   // its source confirmed the fix, with proof
 	EventFindingReopened EventName = "finding_reopened" // a closed finding was reported again
+
+	EventRealmLoaded   EventName = "realm_loaded"   // a realm leaf was loaded at the version the project pins (change realm-leaf-naming)
+	EventDocsPublished EventName = "docs_published" // Odin copied a scratch agent's documents into the project and committed them
+	EventTasksReady    EventName = "tasks_ready"    // a plan's tasks passed the Definition of Ready and features.json was written
+	EventNodeReturned  EventName = "node_returned"  // a refusal went back into an earlier node, as its input (spec §4.5)
+	EventTaskStarted   EventName = "task_started"   // the first node of a task's shape began
+	EventTaskDone      EventName = "task_done"      // the last node of a task's shape finished
+	EventTaskBlocked   EventName = "task_blocked"   // an unattended run gave a task up and went on with the rest (spec §7.3)
 )
 
 // Events returns every event name, in the order above.
@@ -47,7 +55,9 @@ func Events() []EventName {
 		EventGateApproved, EventGateRejected, EventGateAutoPassed, EventLoopAttempt, EventEscalation,
 		EventRoutingLookup, EventBudgetWarning, EventPolicyViolation, EventPointerMoved,
 		EventModeChanged, EventConfigChanged, EventRepoCreated, EventSandboxUp, EventSandboxDown,
-		EventRetry, EventRunPaused, EventFindingRaised, EventFindingClosed, EventFindingReopened}
+		EventRetry, EventRunPaused, EventFindingRaised, EventFindingClosed, EventFindingReopened,
+		EventRealmLoaded, EventDocsPublished, EventTasksReady, EventNodeReturned, EventTaskStarted, EventTaskDone,
+		EventTaskBlocked}
 }
 
 // Event is one ledger line. Fields follow OpenTelemetry's GenAI attribute names (gen_ai.*) where
@@ -87,8 +97,12 @@ type Event struct {
 	FindingID       string `json:"ygg.finding.id,omitempty"`
 	FindingSource   string `json:"ygg.finding.source,omitempty"`
 	FindingSeverity string `json:"ygg.finding.severity,omitempty"`
-	FindingAttempts int    `json:"ygg.finding.attempts,omitempty"` // finding_closed: the loop attempts the finding took to close
-	FindingReopens  int    `json:"ygg.finding.reopens,omitempty"`  // finding_closed, finding_reopened: how often it came back
+	Realm           string `json:"ygg.realm.name,omitempty"`    // realm_loaded, repo_created: the realm leaf
+	RealmVersion    string `json:"ygg.realm.version,omitempty"` // and the version it was loaded at
+	Task            string `json:"ygg.task.id,omitempty"`       // the task a node works for, on every line of its shape
+
+	FindingAttempts int `json:"ygg.finding.attempts,omitempty"` // finding_closed: the loop attempts the finding took to close
+	FindingReopens  int `json:"ygg.finding.reopens,omitempty"`  // finding_closed, finding_reopened: how often it came back
 
 	Prev string `json:"prev"` // hex SHA-256 of the previous line; 64 zeros on the first line
 }
```

Apply to `schema/ledger-event.schema.json`:

```diff
diff --git a/schema/ledger-event.schema.json b/schema/ledger-event.schema.json
index e4955ac..ac0d59f 100644
--- a/schema/ledger-event.schema.json
+++ b/schema/ledger-event.schema.json
@@ -18,7 +18,8 @@
                "gate_rejected", "gate_auto_passed", "loop_attempt", "escalation", "routing_lookup",
                "budget_warning", "policy_violation", "pointer_moved", "mode_changed", "config_changed",
                "repo_created", "sandbox_up", "sandbox_down", "retry", "run_paused", "finding_raised",
-               "finding_closed", "finding_reopened"]
+               "finding_closed", "finding_reopened", "realm_loaded", "docs_published", "tasks_ready",
+               "node_returned", "task_started", "task_done", "task_blocked"]
     },
     "ygg.attempt": { "type": "integer", "minimum": 1 },
     "gen_ai.agent.name": { "type": "string" },
@@ -41,6 +42,9 @@
     "ygg.config.sha256": { "type": "string", "pattern": "^[0-9a-f]{64}$" },
     "ygg.ref.commit": { "type": "string", "pattern": "^[0-9a-f]{40,64}$" },
     "ygg.ref.gate_file": { "type": "string" },
+    "ygg.realm.name": { "type": "string", "pattern": "^[a-z][a-z0-9]*(-[a-z0-9]+)*$" },
+    "ygg.realm.version": { "type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$" },
+    "ygg.task.id": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
     "ygg.finding.id": { "type": "string", "minLength": 1 },
     "ygg.finding.source": { "type": "string", "minLength": 1 },
     "ygg.finding.severity": { "enum": ["blocker", "major", "minor"] },
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T154: features.json: the plan's tasks and where each stands, written by Odin alone

Spec §3.3 rule 2: Odin is the only writer of `features.json`. Its format is Gungnir's.

**Files (in `gungnir`):**
- Create: `schema/features.go`, `schema/features_test.go`

**Interfaces:**
- Produces: `schema.Features{Schema, Run, Source, SourceSHA256 string; Tasks []FeatureRecord}`; `FeatureRecord{Feature; Status TaskStatus; Why string}`; `TaskTodo`, `TaskDoing`, `TaskDone`, `TaskBlocked`; `(*Features).Save(path)` (atomic: a temporary file, synced, renamed) and `LoadFeatures(path)` (no unknown field, the schema `ygg.features/v1`, a known status).

**Acceptance criteria:**
- [ ] The file round-trips, and `Save` leaves no temporary file.
- [ ] `LoadFeatures` refuses another schema, an unknown field, an unknown status and text that is not JSON; `Save` refuses a status nobody knows.

**Named test:** `go test ./schema -run 'TestFeaturesRoundTripThroughTheFileOdinWrites|TestLoadFeaturesRefusesWhatOdinDidNotWrite|TestSavingFeaturesWithAnUnknownStatusIsRefused'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (160). **Depends on:** v0-T150.

- [ ] **Step 1:** write the tests.

Write `schema/features_test.go`:

```go
package schema

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func sampleFeatures() *Features {
	return &Features{Run: "20261017-101500-a1b2c3", Source: "docs/2-engineering/plans/p/tasks.md", SourceSHA256: strings.Repeat("a", 64),
		Tasks: []FeatureRecord{
			{Feature: ready("p-T1", "repos/api"), Status: TaskDone},
			{Feature: ready("p-T2", "repos/web", "p-T1"), Status: TaskBlocked, Why: "its loop ran out of attempts"},
		}}
}

func TestFeaturesRoundTripThroughTheFileOdinWrites(t *testing.T) {
	path := filepath.Join(t.TempDir(), "features.json")
	if err := sampleFeatures().Save(path); err != nil {
		t.Fatal(err)
	}
	got, err := LoadFeatures(path)
	if err != nil {
		t.Fatalf("LoadFeatures() = %v", err)
	}
	if got.Schema != FeaturesSchema || len(got.Tasks) != 2 || got.Tasks[1].Status != TaskBlocked || got.Tasks[1].DependsOn[0] != "p-T1" ||
		got.Tasks[1].Why == "" || got.Tasks[0].Criteria[0] != "it works" {
		t.Errorf("round trip = %+v", got)
	}
	if left, _ := filepath.Glob(path + ".tmp*"); len(left) != 0 {
		t.Errorf("Save left temporary files: %v", left)
	}
}

func TestLoadFeaturesRefusesWhatOdinDidNotWrite(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "features.json")
	if err := sampleFeatures().Save(path); err != nil {
		t.Fatal(err)
	}
	good, _ := os.ReadFile(path)
	cases := map[string]string{
		"another schema":    strings.Replace(string(good), FeaturesSchema, "ygg.features/v9", 1),
		"an unknown field":  strings.Replace(string(good), `"run"`, `"owner": "x", "run"`, 1),
		"an unknown status": strings.Replace(string(good), `"done"`, `"finished"`, 1),
		"not JSON":          "{",
	}
	for name, body := range cases {
		os.WriteFile(path, []byte(body), 0o644)
		if _, err := LoadFeatures(path); err == nil {
			t.Errorf("%s: LoadFeatures() = nil error", name)
		}
	}
}

func TestSavingFeaturesWithAnUnknownStatusIsRefused(t *testing.T) {
	f := sampleFeatures()
	f.Tasks[0].Status = "finished"
	if err := f.Save(filepath.Join(t.TempDir(), "features.json")); err == nil {
		t.Error("Save() = nil for a status nobody knows")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/features_test.go:10:24: undefined: Features
schema/features_test.go:11:10: undefined: Features
schema/features_test.go:12:12: undefined: FeatureRecord
```

- [ ] **Step 3:** write the code.

Write `schema/features.go`:

```go
package schema

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// FeaturesSchema names the features.json format.
const FeaturesSchema = "ygg.features/v1"

// TaskStatus is where a task stands in a run.
type TaskStatus string

const (
	TaskTodo    TaskStatus = "todo"
	TaskDoing   TaskStatus = "doing"
	TaskDone    TaskStatus = "done"
	TaskBlocked TaskStatus = "blocked" // an unattended run gave it up, or a task it depends on (spec §7.3)
)

// FeatureRecord is a task with its status.
type FeatureRecord struct {
	Feature
	Status TaskStatus `json:"status"`
	Why    string     `json:"why,omitempty"` // a blocked task: what stopped it
}

// Features is features.json: the plan's tasks and where each stands, derived from tasks.md by Odin, who is
// its only writer (spec §3.3 rule 2). An agent is told its task in its prompt; it never reads this file.
type Features struct {
	Schema       string          `json:"schema"`
	Run          string          `json:"run"`           // the run that last wrote it
	Source       string          `json:"source"`        // the tasks.md it came from, relative to the project
	SourceSHA256 string          `json:"source_sha256"` // that file as Odin read it
	Tasks        []FeatureRecord `json:"tasks"`         // in the order they are built
}

func (s TaskStatus) known() bool {
	return s == TaskTodo || s == TaskDoing || s == TaskDone || s == TaskBlocked
}

// Save writes the file atomically: a temporary file in the same folder, synced, then renamed.
func (f *Features) Save(path string) error {
	f.Schema = FeaturesSchema
	for _, t := range f.Tasks {
		if !t.Status.known() {
			return fmt.Errorf("task %s has the status %q; want todo, doing, done or blocked", t.ID, t.Status)
		}
	}
	data, err := json.MarshalIndent(f, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), filepath.Base(path)+".tmp-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.Write(append(data, '\n')); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), path)
}

// LoadFeatures reads features.json, and refuses unknown fields, another schema and a status nobody knows.
func LoadFeatures(path string) (*Features, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	var f Features
	if err := dec.Decode(&f); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	if f.Schema != FeaturesSchema {
		return nil, fmt.Errorf("%s: schema %q, want %q", path, f.Schema, FeaturesSchema)
	}
	for _, t := range f.Tasks {
		if !t.Status.known() {
			return nil, fmt.Errorf("%s: task %s has the status %q", path, t.ID, t.Status)
		}
	}
	return &f, nil
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T155: the tasks node names the leaves file whose leaves its tasks may work in

The plan check runs before `init` (spec §4.2: plan, DoR check, init), so the leaves a task names do not exist yet; the leaves file the spec stage wrote says which will.

**Files (in `gungnir`):**
- Modify: `schema/graph.go`, `schema/graph.schema.json`, `schema/graph_stages_test.go`

**Interfaces:**
- Produces: `Node.Leaves` on a tasks node, a project path outside `.git` and `.factory`.

**Acceptance criteria:**
- [ ] A tasks node may name a leaves file; one that climbs, or one on an init node, is refused.

**Named test:** `go test ./schema -run 'TestAGraphWritesDocumentsInAScratchWorkspaceAndPublishesThemIntoTheProject|TestParseGraphRefusesBadStageNodes'` in `gungnir`. **Layer:** `gungnir`. **Size:** S (29). **Depends on:** v0-T148.

- [ ] **Step 1:** write the tests.

Apply to `schema/graph_stages_test.go`:

```diff
diff --git a/schema/graph_stages_test.go b/schema/graph_stages_test.go
index 4b8e34e..f1d6cf2 100644
--- a/schema/graph_stages_test.go
+++ b/schema/graph_stages_test.go
@@ -20,7 +20,7 @@ nodes:
   - { id: spec-docs, kind: publish, from: spec, to: docs }
   - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md, scratch: true, inputs: [docs] }
   - { id: plan-docs, kind: publish, from: plan, to: docs }
-  - { id: ready, kind: tasks, from: docs/2-engineering/plans/*/tasks.md }
+  - { id: ready, kind: tasks, from: docs/2-engineering/plans/*/tasks.md, leaves: docs/leaves.yaml }
   - { id: leaves, kind: init, from: docs/leaves.yaml }
 `
 
@@ -36,7 +36,7 @@ func TestAGraphWritesDocumentsInAScratchWorkspaceAndPublishesThemIntoTheProject(
 	if pub := g.Nodes[2]; pub.Kind != KindPublish || pub.From != "design" || pub.To != "docs" {
 		t.Errorf("publish = %+v", pub)
 	}
-	if n := g.Nodes[8]; n.Kind != KindTasks || n.From != "docs/2-engineering/plans/*/tasks.md" {
+	if n := g.Nodes[8]; n.Kind != KindTasks || n.From != "docs/2-engineering/plans/*/tasks.md" || n.Leaves != "docs/leaves.yaml" {
 		t.Errorf("tasks = %+v", n)
 	}
 	if n := g.Nodes[9]; n.Kind != KindInit || n.From != "docs/leaves.yaml" {
@@ -52,26 +52,28 @@ func TestParseGraphRefusesBadStageNodes(t *testing.T) {
 	scratch := "  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true }\n"
 	const bySchema = "jsonschema validation failed"
 	cases := map[string]struct{ nodes, want string }{
-		"a scratch agent with a repo":        {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, repo: repos/app }\n", "names no repo"},
-		"a read-only scratch agent":          {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, read_only: true }\n", "writes its output"},
-		"inputs without a scratch workspace": {"  - { id: s, kind: agent, role: planner, prompt: p.md, repo: repos/app, inputs: [docs] }\n", "only a scratch agent"},
-		"an input that climbs":               {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [../x] }\n", "inside the project"},
-		"an input in .factory":               {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [.factory/runs] }\n", "inside the project"},
-		"an input in .git":                   {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [.git/config] }\n", "inside the project"},
-		"an input twice":                     {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [docs, docs] }\n", "twice"},
-		"a publish without from":             {"  - { id: p, kind: publish, to: docs }\n", bySchema},
-		"a publish without to":               {scratch + "  - { id: p, kind: publish, from: s }\n", bySchema},
-		"a publish from a node that isn't":   {"  - { id: e, kind: exec, run: [echo] }\n  - { id: p, kind: publish, from: e, to: docs }\n", "scratch agent node before it"},
-		"a publish from a later node":        {"  - { id: p, kind: publish, from: s, to: docs }\n" + scratch, "scratch agent node before it"},
-		"a publish into the project root":    {scratch + "  - { id: p, kind: publish, from: s, to: . }\n", "a folder of the project"},
-		"a publish that climbs":              {scratch + "  - { id: p, kind: publish, from: s, to: ../docs }\n", "a folder of the project"},
-		"a publish into .git":                {scratch + "  - { id: p, kind: publish, from: s, to: .git/hooks }\n", "a folder of the project"},
-		"a publish into .factory":            {scratch + "  - { id: p, kind: publish, from: s, to: .factory/runs }\n", "a folder of the project"},
-		"tasks without from":                 {"  - { id: t, kind: tasks }\n", bySchema},
-		"tasks from a file that climbs":      {"  - { id: t, kind: tasks, from: ../tasks.md }\n", "inside the project"},
-		"init from a file that climbs":       {"  - { id: i, kind: init, from: ../leaves.yaml }\n", "inside the project"},
-		"init with a repo":                   {"  - { id: i, kind: init, from: docs/leaves.yaml, repo: repos/app }\n", bySchema},
-		"a scratch flag on an exec node":     {"  - { id: e, kind: exec, run: [echo], scratch: true }\n", bySchema},
+		"a scratch agent with a repo":            {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, repo: repos/app }\n", "names no repo"},
+		"a read-only scratch agent":              {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, read_only: true }\n", "writes its output"},
+		"inputs without a scratch workspace":     {"  - { id: s, kind: agent, role: planner, prompt: p.md, repo: repos/app, inputs: [docs] }\n", "only a scratch agent"},
+		"an input that climbs":                   {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [../x] }\n", "inside the project"},
+		"an input in .factory":                   {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [.factory/runs] }\n", "inside the project"},
+		"an input in .git":                       {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [.git/config] }\n", "inside the project"},
+		"an input twice":                         {"  - { id: s, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [docs, docs] }\n", "twice"},
+		"a publish without from":                 {"  - { id: p, kind: publish, to: docs }\n", bySchema},
+		"a publish without to":                   {scratch + "  - { id: p, kind: publish, from: s }\n", bySchema},
+		"a publish from a node that isn't":       {"  - { id: e, kind: exec, run: [echo] }\n  - { id: p, kind: publish, from: e, to: docs }\n", "scratch agent node before it"},
+		"a publish from a later node":            {"  - { id: p, kind: publish, from: s, to: docs }\n" + scratch, "scratch agent node before it"},
+		"a publish into the project root":        {scratch + "  - { id: p, kind: publish, from: s, to: . }\n", "a folder of the project"},
+		"a publish that climbs":                  {scratch + "  - { id: p, kind: publish, from: s, to: ../docs }\n", "a folder of the project"},
+		"a publish into .git":                    {scratch + "  - { id: p, kind: publish, from: s, to: .git/hooks }\n", "a folder of the project"},
+		"a publish into .factory":                {scratch + "  - { id: p, kind: publish, from: s, to: .factory/runs }\n", "a folder of the project"},
+		"tasks without from":                     {"  - { id: t, kind: tasks }\n", bySchema},
+		"tasks from a file that climbs":          {"  - { id: t, kind: tasks, from: ../tasks.md }\n", "inside the project"},
+		"init from a file that climbs":           {"  - { id: i, kind: init, from: ../leaves.yaml }\n", "inside the project"},
+		"tasks naming a leaves file that climbs": {"  - { id: t, kind: tasks, from: docs/tasks.md, leaves: ../leaves.yaml }\n", "inside the project"},
+		"init with a leaves file":                {"  - { id: i, kind: init, from: docs/leaves.yaml, leaves: docs/leaves.yaml }\n", bySchema},
+		"init with a repo":                       {"  - { id: i, kind: init, from: docs/leaves.yaml, repo: repos/app }\n", bySchema},
+		"a scratch flag on an exec node":         {"  - { id: e, kind: exec, run: [echo], scratch: true }\n", bySchema},
 	}
 	for name, c := range cases {
 		_, err := ParseGraph("graph.yaml", []byte(head+c.nodes))
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/graph_stages_test.go:39:98: n.Leaves undefined (type Node has no field or method Leaves)
FAIL	github.com/ouroboric-dev/gungnir/schema [build failed]
FAIL
```

- [ ] **Step 3:** write the code.

Apply to `schema/graph.go`:

```diff
diff --git a/schema/graph.go b/schema/graph.go
index 5f63804..d4e7c85 100644
--- a/schema/graph.go
+++ b/schema/graph.go
@@ -76,6 +76,7 @@ type Node struct {
 	Inputs  []string `yaml:"inputs"`  // agent (scratch): files and folders of the project, copied into the workspace; changes to the copies are ignored
 	From    string   `yaml:"from"`    // publish: the scratch agent whose output is published; tasks: the tasks.md, by glob; init: the leaves file
 	To      string   `yaml:"to"`      // publish: the folder of the project its files go to
+	Leaves  string   `yaml:"leaves"`  // tasks: the leaves file of the spec stage; its leaves are the layers a task may name, beside the leaves the project has
 
 	BackTo  string `yaml:"back_to"` // merge, pointer, tasks: the earlier agent or loop node a refusal goes back into, with the refusal as its input
 	Returns int    `yaml:"returns"` // merge, pointer, tasks: how many times it may go back; DefaultReturns when back_to is set and this is not
@@ -278,6 +279,9 @@ func (c *graphCheck) stage(n *Node, before []Node) error {
 		if !projectPath(n.From) {
 			return fmt.Errorf("%s: node %s: from %q must be a path inside the project, outside .git and .factory", file, n.ID, n.From)
 		}
+		if n.Leaves != "" && !projectPath(n.Leaves) {
+			return fmt.Errorf("%s: node %s: leaves %q must be a path inside the project, outside .git and .factory", file, n.ID, n.Leaves)
+		}
 	}
 	return nil
 }
```

Apply to `schema/graph.schema.json`:

```diff
diff --git a/schema/graph.schema.json b/schema/graph.schema.json
index 4acde6f..0219085 100644
--- a/schema/graph.schema.json
+++ b/schema/graph.schema.json
@@ -153,6 +153,7 @@
             "id": { "$ref": "#/$defs/id" },
             "kind": { "const": "tasks" },
             "from": { "type": "string", "minLength": 1 },
+            "leaves": { "type": "string", "minLength": 1 },
             "back_to": { "$ref": "#/$defs/id" },
             "returns": { "type": "integer", "minimum": 1, "maximum": 5 }
           },
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T156: Gungnir's documentation

The architecture page says what the component now does for realms and tasks.

**Files (in `gungnir`):**
- Modify: `docs/architecture.md`

**Acceptance criteria:**
- [ ] `docs/architecture.md` lists the project's pins, the pack's recipe and services, `leaves.yaml`, the graph's new nodes, `tasks.md` with the Definition of Ready and `features.json`, and the sandbox spec.

**Named test:** `go test ./...` in `gungnir`. **Layer:** `gungnir`. **Size:** S (12). **Depends on:** v0-T155.

- [ ] **Step 1:** write the code.

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 90e00db..85c5d9c 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -16,6 +16,18 @@ The contract: Go interface types and JSON schemas for ledger events, `graph.yaml
   `Tracker` (spec §2.2).
 - Defines the schemas: `factory.yaml`, `graph.yaml`, `pack.yaml`, ledger events (with OpenTelemetry
   `gen_ai.*` field names) and findings.
+- Defines what a realm and a project say about each other (change realm-leaf-naming): a project's
+  `umbrella.yaml` pins its lead realm and, for each leaf, the realm that provides it and the leaves it
+  consumes; a build realm's `pack.yaml` offers a leaf recipe (template, implementer prompt, checks) and
+  sandbox services under the same names in every realm, and may have no graph; `leaves.yaml` is the
+  spec stage's list of a product's leaves and their realms.
+- Defines the graph's nodes beyond the loop: `foreach` (a task shape repeated for every ready task, in the
+  leaf and the realm of the task), scratch agents, `publish`, `tasks` and `init`, and `back_to` for a
+  refusal that goes back into an earlier node.
+- Reads a plan's `tasks.md` exactly into `Feature`s, applies the Definition of Ready (`CheckReady`),
+  and defines `features.json`, which Odin alone writes.
+- Describes a sandbox (`SandboxSpec`): the leaf or scratch folder it holds, the stack layer of the
+  leaf's realm, and the services it starts beside the work container.
 - Validates configs against those schemas.
 - Takes every interface change first: one PR here, plus one in each affected component (spec §1).
 
```

- [ ] **Step 2:** run the named test. Expect `ok`.

- [ ] **Step 3:** commit (see "How each task lands").

---

### Task v0-T157: two leaves never share a sandbox project or a configuration folder (B-015)

Gleipnir's first task. Branch `realms/sandbox` from `main` in `gleipnir`, before step 1. It needs v0-T156 merged and pinned. Backlog B-015: `Project()` and the configuration folder's name drop punctuation, so `repos/web-app` and `repos/webapp` are one compose project, and one leaf's `Down` stops the other's sandbox. A project with several leaves from several realms makes this likelier.

**Files (in `gleipnir`):**
- Create: `sandbox/names_test.go`
- Modify: `sandbox/config.go`, `sandbox/config_test.go`, `sandbox/driver.go`, `sandbox/driver_test.go`

**Interfaces:**
- Produces: `sandbox.Project(spec)` ends in a hash of the run and the leaf's path (still lower-case letters and digits only); `sandbox.ConfigDir(work, spec) string`, the folder of a sandbox's configuration, named by its project; `Driver.Up` uses it.

**Acceptance criteria:**
- [ ] Leaves whose paths differ only in punctuation (`repos/web-app`, `repos/webapp`, `repos/web/app`, `repos/web.app`, `repos/web_app`) get five projects and five folders.
- [ ] A project name is the same on every call and holds only lower-case letters and digits.

**Named test:** `go test ./sandbox -run 'TestTwoLeavesNeverShareASandboxProject|TestTwoLeavesNeverShareAConfigurationFolder'` in `gleipnir`. **Layer:** `gleipnir`. **Size:** S (66). **Depends on:** v0-T156.

- [ ] **Step 1:** write the tests.

Apply to `sandbox/config_test.go`:

```diff
diff --git a/sandbox/config_test.go b/sandbox/config_test.go
index d531b84..52583ea 100644
--- a/sandbox/config_test.go
+++ b/sandbox/config_test.go
@@ -68,7 +68,7 @@ func TestGenerateWritesTheMirroredHardenedConfig(t *testing.T) {
 		len(work.CapAdd) != 0 || work.CapDrop[0] != "ALL" || fw.CapAdd[0] != "NET_ADMIN" {
 		t.Errorf("work = %+v, fw = %+v; want keep-id on both, no added capability in work, and the firewall in its own sidecar", work, fw)
 	}
-	if cf.Name != "ygg20261016101500a1b2c3reposapp" || work.Labels[LabelRun] != "20261016-101500-a1b2c3" {
+	if !strings.HasPrefix(cf.Name, "ygg20261016101500a1b2c3reposapp") || len(cf.Name) != len("ygg20261016101500a1b2c3reposapp")+8 || work.Labels[LabelRun] != "20261016-101500-a1b2c3" {
 		t.Errorf("project %q, labels %v", cf.Name, work.Labels)
 	}
 	if fw.User != "0:0" {
```

Apply to `sandbox/driver_test.go`:

```diff
diff --git a/sandbox/driver_test.go b/sandbox/driver_test.go
index 05b326f..ee28865 100644
--- a/sandbox/driver_test.go
+++ b/sandbox/driver_test.go
@@ -89,7 +89,7 @@ func TestUpUsesTheEngineAndAuthTheFactoryChose(t *testing.T) {
 	if !strings.Contains(got, "host="+socket) || !strings.Contains(got, "auth="+filepath.Join(d.work, "registry-auth", "auth.json")) {
 		t.Errorf("a call lacked the factory's engine or the isolated auth:\n%s", got)
 	}
-	for _, want := range []string{"devcontainer up --docker-path", "--skip-post-create", "--config " + filepath.Join(d.work, "repos-app", "devcontainer.json")} {
+	for _, want := range []string{"devcontainer up --docker-path", "--skip-post-create", "--config " + filepath.Join(ConfigDir(d.work, sp), "devcontainer.json")} {
 		if !strings.Contains(got, want) {
 			t.Errorf("the devcontainer call lacks %q:\n%s", want, got)
 		}
@@ -233,7 +233,7 @@ func TestEachCommandStartsWithAnEmptyHome(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
-	compose, _ := os.ReadFile(filepath.Join(d.work, "repos-app", "compose.yaml"))
+	compose, _ := os.ReadFile(filepath.Join(ConfigDir(d.work, sp), "compose.yaml"))
 	for _, kv := range []string{"HOME: /home/ygg", "XDG_CONFIG_HOME: /home/ygg/.config", "XDG_CACHE_HOME: /home/ygg/.cache",
 		"XDG_DATA_HOME: /home/ygg/.local/share", "XDG_STATE_HOME: /home/ygg/.local/state"} {
 		if !strings.Contains(string(compose), kv) {
```

Write `sandbox/names_test.go`:

```go
package sandbox

import (
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func named(name string) gungnir.SandboxSpec {
	s := spec("/home/ana/ygg/proj")
	s.Name = name
	s.Leaf = "/home/ana/ygg/proj/" + name
	s.GitDir = "/home/ana/ygg/proj/.git/modules/" + name
	return s
}

func TestTwoLeavesNeverShareASandboxProject(t *testing.T) {
	names := []string{"repos/web-app", "repos/webapp", "repos/web/app", "repos/web.app", "repos/web_app"}
	seen := map[string]string{}
	for _, n := range names {
		p := Project(named(n))
		if other, dup := seen[p]; dup {
			t.Errorf("%s and %s share the project %s: one leaf's Down would stop the other's sandbox", n, other, p)
		}
		seen[p] = n
		if !regexp.MustCompile(`^ygg[a-z0-9]+$`).MatchString(p) {
			t.Errorf("project %q must be lower-case letters and digits only (the devcontainer CLI strips the rest)", p)
		}
		if p != Project(named(n)) {
			t.Errorf("Project(%s) changes between calls", n)
		}
	}
}

func TestTwoLeavesNeverShareAConfigurationFolder(t *testing.T) {
	seen := map[string]string{}
	for _, n := range []string{"repos/web-app", "repos/web/app", "repos/web.app", "repos/webapp"} {
		dir := ConfigDir("/work", named(n))
		if filepath.Dir(dir) != "/work" || strings.Contains(filepath.Base(dir), "/") {
			t.Errorf("ConfigDir(%s) = %q; want one folder directly under the work folder", n, dir)
		}
		if other, dup := seen[dir]; dup {
			t.Errorf("%s and %s share the folder %s", n, other, dir)
		}
		seen[dir] = n
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gleipnir/sandbox [github.com/ouroboric-dev/gleipnir/sandbox.test]
sandbox/driver_test.go:92:115: undefined: ConfigDir
sandbox/driver_test.go:236:42: undefined: ConfigDir
sandbox/names_test.go:41:10: undefined: ConfigDir
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/config.go`:

```diff
diff --git a/sandbox/config.go b/sandbox/config.go
index 761c9aa..b2adfee 100644
--- a/sandbox/config.go
+++ b/sandbox/config.go
@@ -1,6 +1,8 @@
 package sandbox
 
 import (
+	"crypto/sha256"
+	"encoding/hex"
 	"encoding/json"
 	"errors"
 	"fmt"
@@ -85,10 +87,19 @@ type Generated struct {
 // Project returns the compose project name of a sandbox: one per run and leaf. It is lower-case letters
 // and digits only, because the devcontainer CLI strips everything else from the name it gives the
 // engine, and Down finds containers by that name (found on a real engine, 2026-10-16).
+//
+// The name ends in a hash of the run and the leaf's path, because dropping punctuation alone makes
+// repos/web-app and repos/webapp one project, and one leaf's Down would stop the other's sandbox
+// (backlog B-015).
 func Project(s gungnir.SandboxSpec) string {
-	return "ygg" + regexp.MustCompile(`[^a-z0-9]`).ReplaceAllString(strings.ToLower(s.Run+s.Name), "")
+	sum := sha256.Sum256([]byte(s.Run + "\x00" + s.Name))
+	return "ygg" + regexp.MustCompile(`[^a-z0-9]`).ReplaceAllString(strings.ToLower(s.Run+s.Name), "") + hex.EncodeToString(sum[:4])
 }
 
+// ConfigDir returns the folder under work where the sandbox of spec keeps its configuration: its
+// project name, so no two sandboxes of a run share one.
+func ConfigDir(work string, s gungnir.SandboxSpec) string { return filepath.Join(work, Project(s)) }
+
 type composeFile struct {
 	Name     string             `yaml:"name"`
 	Services map[string]service `yaml:"services"`
```

Apply to `sandbox/driver.go`:

```diff
diff --git a/sandbox/driver.go b/sandbox/driver.go
index f2e594c..1d630f3 100644
--- a/sandbox/driver.go
+++ b/sandbox/driver.go
@@ -97,7 +97,7 @@ func (d *Driver) Up(ctx context.Context, spec gungnir.SandboxSpec) (gungnir.Env,
 	if err := spec.Validate(); err != nil {
 		return gungnir.Env{}, err
 	}
-	g, err := Generate(filepath.Join(d.work, strings.ReplaceAll(spec.Name, "/", "-")), spec, d.cfg)
+	g, err := Generate(ConfigDir(d.work, spec), spec, d.cfg)
 	if err != nil {
 		return gungnir.Env{}, err
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T158: a sandbox starts the services its leaf's realm asks for beside the work container

Spec §6.1 and §9.3: a leaf's sandbox runs the realm's services, Postgres and SeaweedFS for the web realm, beside the work container. Nothing started one until now.

**Files (in `gleipnir`):**
- Create: `sandbox/services_test.go`
- Modify: `sandbox/config.go`

**Interfaces:**
- Consumes: `gungnir.SandboxSpec.Services` (v0-T144).
- Produces: one compose service for each `Service`, on the image pinned by digest (`pull_policy: never`), with the service's env, the sandbox's labels, `no-new-privileges`, no mount, no added capability, no published port and the image's own user and command; the firewall and the work container wait for them (`depends_on`). The `service` struct's optional fields are `omitempty`, so a service with no command does not override the image's.
- `Validate` already scans every compose service, so a service the factory did not write (`privileged`, a swapped image) is refused or differs from what the factory generates.

**Acceptance criteria:**
- [ ] A spec with two services renders both, with the properties above, and the dependencies run fw and work after them.
- [ ] A privileged service is refused with a message that names the service and the key; a swapped image is a difference; a service whose env names a credential is refused when the config is generated.

**Named test:** `go test ./sandbox -run 'TestServicesStartBesideTheWorkContainerAndTheFirewall|TestAServiceTheFactoryDidNotWriteIsRefusedBeforeItStarts'` in `gleipnir`. **Layer:** `gleipnir`. **Size:** M (128). **Depends on:** v0-T157.

- [ ] **Step 1:** write the tests.

Write `sandbox/services_test.go`:

```go
package sandbox

import (
	"errors"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"go.yaml.in/yaml/v3"
)

const (
	pgImage  = "docker.io/library/postgres:17.2@sha256:1111111111111111111111111111111111111111111111111111111111111111"
	s3Image  = "docker.io/chrislusf/seaweedfs:3.80@sha256:2222222222222222222222222222222222222222222222222222222222222222"
	stackImg = "docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514"
)

func withServices() gungnir.SandboxSpec {
	s := spec("/home/ana/ygg/proj")
	s.Services = []gungnir.Service{
		{Name: "seaweedfs", Image: s3Image, Env: nil, Ports: []int{8333}},
		{Name: "postgres", Image: pgImage, Env: map[string]string{"POSTGRES_DB": "app", "POSTGRES_HOST_AUTH_METHOD": "trust"}, Ports: []int{5432}},
	}
	return s
}

func TestServicesStartBesideTheWorkContainerAndTheFirewall(t *testing.T) {
	tmp := t.TempDir()
	c := cfg()
	c.Mounts = append(c.Mounts, PathMap{Host: tmp, Engine: "/mnt/wsl/cfg"})
	g, err := Generate(filepath.Join(tmp, "sandbox"), withServices(), c)
	if err != nil {
		t.Fatal(err)
	}
	var cf composeFile
	raw, _ := os.ReadFile(g.Compose)
	if err := yaml.Unmarshal(raw, &cf); err != nil {
		t.Fatal(err)
	}
	pg, s3, work, fw := cf.Services["postgres"], cf.Services["seaweedfs"], cf.Services["work"], cf.Services["fw"]
	if pg.Image != pgImage || pg.PullPolicy != "never" || pg.Environment["POSTGRES_DB"] != "app" || pg.Labels[LabelRun] != "20261016-101500-a1b2c3" {
		t.Errorf("postgres = %+v", pg)
	}
	if !slices.Equal(pg.SecurityOpt, []string{"no-new-privileges:true"}) || len(pg.CapAdd) != 0 || pg.NetworkMode != "" || len(pg.Volumes) != 0 || pg.User != "" || pg.UsernsMode != "" {
		t.Errorf("postgres = %+v; a service gets no capability, no mount and the image's own user, and shares no namespace", pg)
	}
	if s3.Image != s3Image || len(s3.Environment) != 0 {
		t.Errorf("seaweedfs = %+v", s3)
	}
	for name, deps := range map[string][]string{"work": work.DependsOn, "fw": fw.DependsOn} {
		if !slices.Equal(deps, wantDeps(name)) {
			t.Errorf("%s depends on %v, want %v: the services are up before the firewall resolves them, and before the work container starts", name, deps, wantDeps(name))
		}
	}
	if !strings.Contains(string(raw), "command:") || strings.Count(string(raw), "command: []") != 0 {
		t.Errorf("a service with no command of its own must not override the image's:\n%s", raw)
	}
}

func wantDeps(name string) []string {
	if name == "fw" {
		return []string{"postgres", "seaweedfs"}
	}
	return []string{"fw", "postgres", "seaweedfs"}
}

func TestAServiceTheFactoryDidNotWriteIsRefusedBeforeItStarts(t *testing.T) {
	tmp := t.TempDir()
	c := cfg()
	c.Mounts = append(c.Mounts, PathMap{Host: tmp, Engine: "/mnt/wsl/cfg"})
	sp := withServices()
	g, err := Generate(filepath.Join(tmp, "sandbox"), sp, c)
	if err != nil {
		t.Fatal(err)
	}
	if err := Validate(g, sp, c); err != nil {
		t.Fatalf("Validate() = %v on what Generate wrote", err)
	}
	edit := func(change func(services map[string]any)) {
		t.Helper()
		var cf map[string]any
		b, _ := os.ReadFile(g.Compose)
		if err := yaml.Unmarshal(b, &cf); err != nil {
			t.Fatal(err)
		}
		change(cf["services"].(map[string]any))
		out, _ := yaml.Marshal(cf)
		os.WriteFile(g.Compose, out, 0o644)
	}
	edit(func(svcs map[string]any) { svcs["postgres"].(map[string]any)["privileged"] = true })
	var pe *PolicyError
	if err := Validate(g, sp, c); err == nil || !errors.As(err, &pe) || !strings.Contains(err.Error(), "service postgres has privileged") {
		t.Errorf("a privileged service: Validate() = %v", err)
	}
	g, _ = Generate(filepath.Join(tmp, "sandbox"), sp, c)
	edit(func(svcs map[string]any) {
		svcs["postgres"].(map[string]any)["image"] = "docker.io/library/postgres:evil"
	})
	if err := Validate(g, sp, c); err == nil || !strings.Contains(err.Error(), "differs from what the factory generates") {
		t.Errorf("a swapped service image: Validate() = %v", err)
	}
	bad := withServices()
	bad.Services[1].Env = map[string]string{"POSTGRES_PASSWORD": "dev"}
	if _, err := Generate(filepath.Join(tmp, "other"), bad, c); err == nil {
		t.Error("a service that takes a password was accepted")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestServicesStartBesideTheWorkContainerAndTheFirewall (0.00s)
    services_test.go:45: postgres = {Image: PullPolicy: Command:[] User: UsernsMode: CapAdd:[] CapDrop:[] SecurityOpt:[] NetworkMode: DependsOn:[] Environment:map[] Labels:map[] Volumes:[]}
    services_test.go:48: postgres = {Image: PullPolicy: Command:[] User: UsernsMode: CapAdd:[] CapDrop:[] SecurityOpt:[] NetworkMode: DependsOn:[] Environment:map[] Labels:map[] Volumes:[]}; a service gets no capability, no mount and the image's own user, and shares no namespace
    services_test.go:51: seaweedfs = {Image: PullPolicy: Command:[] User: UsernsMode: CapAdd:[] CapDrop:[] SecurityOpt:[] NetworkMode: DependsOn:[] Environment:map[] Labels:map[] Volumes:[]}
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/config.go`:

```diff
diff --git a/sandbox/config.go b/sandbox/config.go
index b2adfee..e54315b 100644
--- a/sandbox/config.go
+++ b/sandbox/config.go
@@ -10,6 +10,7 @@ import (
 	"os"
 	"path/filepath"
 	"regexp"
+	"slices"
 	"strings"
 
 	"github.com/ouroboric-dev/gungnir"
@@ -108,9 +109,9 @@ type composeFile struct {
 type service struct {
 	Image       string            `yaml:"image"`
 	PullPolicy  string            `yaml:"pull_policy"` // never: images are built or pulled beforehand, with the isolated auth
-	Command     []string          `yaml:"command"`
+	Command     []string          `yaml:"command,omitempty"`
 	User        string            `yaml:"user,omitempty"`
-	UsernsMode  string            `yaml:"userns_mode"`
+	UsernsMode  string            `yaml:"userns_mode,omitempty"`
 	CapAdd      []string          `yaml:"cap_add,omitempty"`
 	CapDrop     []string          `yaml:"cap_drop,omitempty"`
 	SecurityOpt []string          `yaml:"security_opt,omitempty"`
@@ -118,7 +119,7 @@ type service struct {
 	DependsOn   []string          `yaml:"depends_on,omitempty"`
 	Environment map[string]string `yaml:"environment,omitempty"`
 	Labels      map[string]string `yaml:"labels"`
-	Volumes     []string          `yaml:"volumes"`
+	Volumes     []string          `yaml:"volumes,omitempty"`
 }
 
 // Generate writes a sandbox's devcontainer.json, compose.yaml and firewall host list into dir,
@@ -188,6 +189,20 @@ func render(dir string, spec gungnir.SandboxSpec, c Config) (map[string][]byte,
 			},
 		},
 	}}
+	// The services a leaf's realm, and the realms of the leaves it consumes, ask for. They run on the
+	// image's own user and command, with no mount, no capability beyond the engine's default set and no
+	// published port: the work container reaches them by name, through the firewall's network, only on
+	// the ports the spec lists (egress.sh).
+	var names []string
+	for _, v := range spec.Services {
+		cf.Services[v.Name] = service{Image: v.Image, PullPolicy: "never", SecurityOpt: []string{"no-new-privileges:true"},
+			Environment: maps.Clone(v.Env), Labels: labels}
+		names = append(names, v.Name)
+	}
+	slices.Sort(names)
+	fwSvc, workSvc := cf.Services["fw"], cf.Services["work"]
+	fwSvc.DependsOn, workSvc.DependsOn = names, append([]string{"fw"}, names...)
+	cf.Services["fw"], cf.Services["work"] = fwSvc, workSvc
 	dc := map[string]any{
 		"name": Project(spec), "dockerComposeFile": "compose.yaml", "service": "work",
 		"workspaceFolder": Root + "/" + l.Leaf, "updateRemoteUserUID": false, "shutdownAction": "stopCompose",
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T159: the firewall opens a service's ports to the work container and no others

The work container shares the firewall sidecar's network and its egress is default-deny (spec §6.2). A service beside it is reachable only if the firewall says so, on the ports the realm listed.

**Files (in `gleipnir`):**
- Modify: `sandbox/assets/egress.sh`, `sandbox/config.go`, `sandbox/firewall_test.go`, `sandbox/services_test.go`, `sandbox/validate.go`

**Interfaces:**
- Produces: `fw/services`, a file of `name port` lines (one for each port of each service, by name), written beside `fw/hosts` and checked like it; `Generated.Services`; the sidecar's command takes it as a second argument.
- `egress.sh HOSTS [SERVICES]` resolves each service name (waiting up to `YGG_SERVICE_WAIT` tries, 30 by default, one a second, for a service that is still starting), and opens each listed port of its addresses, in the same chain as the hosts, swapped in without a gap. A name that never resolves exits 1 before any rule changes, so the sandbox never opens half closed.

**Acceptance criteria:**
- [ ] The script opens `5432` to the address of `postgres` and each listed port of `seaweedfs`, and neither opens `443` to them nor any other port; it opens the hosts as before.
- [ ] A service that resolves on the third try is waited for; one that never resolves fails the script before a rule changes and the firewall never says it is ready.
- [ ] A port added to `fw/services` after the config was generated is a difference that `Validate` finds.

**Named test:** `go test ./sandbox -run 'TestEgressOpensAServicesPortsAndNoOthers|TestEgressWaitsForAServiceThatIsStillStarting|TestEgressRefusesToOpenWithoutAService|TestTheFirewallIsToldWhichServicePortsToOpen|TestEgress'` in `gleipnir`. **Layer:** `gleipnir`. **Size:** M (147). **Depends on:** v0-T158.

- [ ] **Step 1:** write the tests.

Apply to `sandbox/firewall_test.go`:

```diff
diff --git a/sandbox/firewall_test.go b/sandbox/firewall_test.go
index 307c7e2..4d33cf9 100644
--- a/sandbox/firewall_test.go
+++ b/sandbox/firewall_test.go
@@ -23,12 +23,23 @@ func stubs(t *testing.T) (bin, log string) {
 	write("getent", `case "$2" in
   api.anthropic.com) echo "160.79.104.10 STREAM api.anthropic.com" ;;
   proxy.golang.org) echo "142.250.1.1 STREAM"; echo "142.250.1.2 STREAM" ;;
+  postgres) echo "10.89.0.5 STREAM postgres" ;;
+  seaweedfs) echo "10.89.0.6 STREAM seaweedfs" ;;
+  late) n="$(cat "$STUB_LATE" 2>/dev/null || echo 0)"; echo $((n+1)) > "$STUB_LATE"; [ "$n" -ge 2 ] && echo "10.89.0.7 STREAM late" ;;
 esac
 `)
+	write("sleep", "exit 0\n")
 	return bin, log
 }
 
 func runEgress(t *testing.T, hosts string, extra ...string) (calls string, state string, err error) {
+	t.Helper()
+	return runEgressWithServices(t, hosts, "", extra...)
+}
+
+// runEgressWithServices is runEgress with a services file: one "name port" line for each port a service
+// opens. An empty services means the script gets no second argument.
+func runEgressWithServices(t *testing.T, hosts, services string, extra ...string) (calls string, state string, err error) {
 	t.Helper()
 	bin, log := stubs(t)
 	dir := t.TempDir()
@@ -39,8 +50,15 @@ func runEgress(t *testing.T, hosts string, extra ...string) (calls string, state
 	script := filepath.Join(dir, "egress.sh")
 	os.WriteFile(script, []byte(strings.ReplaceAll(EgressScript, "/etc/resolv.conf", resolv)), 0o755)
 	state = filepath.Join(dir, "state")
-	cmd := exec.Command("sh", script, hostsFile)
-	cmd.Env = append([]string{"PATH=" + bin + ":" + os.Getenv("PATH"), "STUB_LOG=" + log, "YGG_FW_STATE=" + state, "YGG_ONCE=1"}, extra...)
+	args := []string{script, hostsFile}
+	if services != "" {
+		servicesFile := filepath.Join(dir, "services")
+		os.WriteFile(servicesFile, []byte(services), 0o644)
+		args = append(args, servicesFile)
+	}
+	cmd := exec.Command("sh", args...)
+	cmd.Env = append([]string{"PATH=" + bin + ":" + os.Getenv("PATH"), "STUB_LOG=" + log, "STUB_LATE=" + filepath.Join(dir, "late"),
+		"YGG_FW_STATE=" + state, "YGG_ONCE=1"}, extra...)
 	out, err := cmd.CombinedOutput()
 	if err != nil {
 		err = &scriptError{err, string(out)}
@@ -92,3 +110,48 @@ func TestEgressRefusesToOpenHalfClosed(t *testing.T) {
 		t.Error("a failed firewall said it was ready")
 	}
 }
+
+func TestEgressOpensAServicesPortsAndNoOthers(t *testing.T) {
+	calls, state, err := runEgressWithServices(t, "api.anthropic.com\n", "postgres 5432\nseaweedfs 8333\nseaweedfs 9333\n")
+	if err != nil {
+		t.Fatal(err)
+	}
+	for _, want := range []string{
+		"iptables -A YGG_HOSTS_A -p tcp -d 160.79.104.10 --dport 443 -j ACCEPT",
+		"iptables -A YGG_HOSTS_A -p tcp -d 10.89.0.5 --dport 5432 -j ACCEPT",
+		"iptables -A YGG_HOSTS_A -p tcp -d 10.89.0.6 --dport 8333 -j ACCEPT",
+		"iptables -A YGG_HOSTS_A -p tcp -d 10.89.0.6 --dport 9333 -j ACCEPT",
+	} {
+		if !strings.Contains(calls, want+"\n") {
+			t.Errorf("the rules lack %q:\n%s", want, calls)
+		}
+	}
+	for _, not := range []string{"-d 10.89.0.5 --dport 443", "-d 10.89.0.5 --dport 5433", "-P OUTPUT ACCEPT"} {
+		if strings.Contains(calls, not) {
+			t.Errorf("the rules hold %q, which opens more than the service's ports:\n%s", not, calls)
+		}
+	}
+	if _, err := os.Stat(filepath.Join(state, "ready")); err != nil {
+		t.Error("the firewall never said it was ready")
+	}
+}
+
+func TestEgressWaitsForAServiceThatIsStillStarting(t *testing.T) {
+	calls, _, err := runEgressWithServices(t, "api.anthropic.com\n", "late 5432\n", "YGG_SERVICE_WAIT=5")
+	if err != nil || !strings.Contains(calls, "-d 10.89.0.7 --dport 5432 -j ACCEPT\n") {
+		t.Errorf("a service that resolves on the third try: %v\n%s", err, calls)
+	}
+}
+
+func TestEgressRefusesToOpenWithoutAService(t *testing.T) {
+	calls, state, err := runEgressWithServices(t, "api.anthropic.com\n", "postgres 5432\nghost 5432\n", "YGG_SERVICE_WAIT=2")
+	if err == nil {
+		t.Fatal("egress.sh succeeded with a service that never resolves")
+	}
+	if strings.Contains(calls, "-P OUTPUT DROP") {
+		t.Errorf("the script changed rules before it knew every address:\n%s", calls)
+	}
+	if _, err := os.Stat(filepath.Join(state, "ready")); err == nil {
+		t.Error("a failed firewall said it was ready")
+	}
+}
```

Apply to `sandbox/services_test.go`:

```diff
diff --git a/sandbox/services_test.go b/sandbox/services_test.go
index c88ef14..60afb42 100644
--- a/sandbox/services_test.go
+++ b/sandbox/services_test.go
@@ -108,3 +108,37 @@ func TestAServiceTheFactoryDidNotWriteIsRefusedBeforeItStarts(t *testing.T) {
 		t.Error("a service that takes a password was accepted")
 	}
 }
+
+func TestTheFirewallIsToldWhichServicePortsToOpen(t *testing.T) {
+	tmp := t.TempDir()
+	c := cfg()
+	c.Mounts = append(c.Mounts, PathMap{Host: tmp, Engine: "/mnt/wsl/cfg"})
+	sp := withServices()
+	sp.Services[0].Ports = []int{8333, 9333}
+	g, err := Generate(filepath.Join(tmp, "sandbox"), sp, c)
+	if err != nil {
+		t.Fatal(err)
+	}
+	if b, _ := os.ReadFile(g.Services); string(b) != "postgres 5432\nseaweedfs 8333\nseaweedfs 9333\n" {
+		t.Errorf("fw/services = %q; one line for each port of each service, by name", b)
+	}
+	var cf composeFile
+	raw, _ := os.ReadFile(g.Compose)
+	yaml.Unmarshal(raw, &cf)
+	if got := strings.Join(cf.Services["fw"].Command, " "); got != "sh /etc/ygg-fw/egress.sh /etc/ygg-fw/hosts /etc/ygg-fw/services" {
+		t.Errorf("fw command = %q", got)
+	}
+	// A port the agent adds to the file is a difference from what the factory generates.
+	os.WriteFile(g.Services, []byte("postgres 5432\nseaweedfs 8333\nseaweedfs 9333\nseaweedfs 22\n"), 0o644)
+	if err := Validate(g, sp, c); err == nil || !strings.Contains(err.Error(), "fw/services differs") {
+		t.Errorf("Validate() = %v after a port was added to fw/services", err)
+	}
+	noServices := spec("/home/ana/ygg/proj")
+	g2, err := Generate(filepath.Join(tmp, "plain"), noServices, c)
+	if err != nil {
+		t.Fatal(err)
+	}
+	if b, err := os.ReadFile(g2.Services); err != nil || len(b) != 0 {
+		t.Errorf("fw/services for a sandbox with no services = %q, %v; want an empty file", b, err)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gleipnir/sandbox [github.com/ouroboric-dev/gleipnir/sandbox.test]
sandbox/services_test.go:122:27: g.Services undefined (type Generated has no field or method Services)
sandbox/services_test.go:132:17: g.Services undefined (type Generated has no field or method Services)
sandbox/services_test.go:141:30: g2.Services undefined (type Generated has no field or method Services)
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/assets/egress.sh`:

```diff
diff --git a/sandbox/assets/egress.sh b/sandbox/assets/egress.sh
index fd9b8fa..70db0ab 100644
--- a/sandbox/assets/egress.sh
+++ b/sandbox/assets/egress.sh
@@ -1,13 +1,18 @@
 #!/bin/sh
-# egress.sh HOSTS: the egress firewall of a leaf's sandbox (spec §6.2). It runs as root in the
+# egress.sh HOSTS [SERVICES]: the egress firewall of a leaf's sandbox (spec §6.2). It runs as root in the
 # firewall sidecar, which owns the network namespace the work container joins; the agent's container
 # has no capabilities, so it can't change a rule. Output, input and forwarding are dropped, except
-# loopback, replies, DNS to the resolver, and 443/tcp to the addresses of the hosts in HOSTS (one
-# name per line). Names are resolved to addresses, so the script resolves them again every
+# loopback, replies, DNS to the resolver, 443/tcp to the addresses of the hosts in HOSTS (one
+# name per line), and the listed ports of the services in SERVICES (one "name port" per line; the
+# containers beside the work container, such as a database). A service may still be starting, so a
+# name that does not resolve is tried again each second, up to YGG_SERVICE_WAIT times (default 30).
+# Names are resolved to addresses, so the script resolves them again every
 # YGG_REFRESH seconds (default 300) and swaps the rules in without a gap. Without a resolvable
 # host at the start it exits 1, so the sandbox never opens half closed.
 set -eu
-HOSTS="${1:?usage: egress.sh HOSTS}"
+HOSTS="${1:?usage: egress.sh HOSTS [SERVICES]}"
+SERVICES="${2:-}"
+WAIT="${YGG_SERVICE_WAIT:-30}"
 STATE="${YGG_FW_STATE:-/run/ygg-fw}"
 REFRESH="${YGG_REFRESH:-300}"
 mkdir -p "$STATE"
@@ -25,6 +30,24 @@ resolve() {
   done < "$HOSTS"
 }
 
+# resolve_services prints "address port" for every port of every service, or fails on a service that
+# has no address after WAIT tries.
+resolve_services() {
+  [ -n "$SERVICES" ] && [ -s "$SERVICES" ] || return 0
+  while read -r name port; do
+    [ -n "$name" ] || continue
+    tries=0
+    while :; do
+      found="$(getent ahostsv4 "$name" | awk '{ print $1 }' | sort -u)"
+      [ -n "$found" ] && break
+      tries=$((tries + 1))
+      if [ "$tries" -ge "$WAIT" ]; then echo "egress: service $name does not resolve" >&2; return 1; fi
+      sleep 1
+    done
+    for ip in $found; do echo "$ip $port"; done
+  done < "$SERVICES"
+}
+
 base() {
   for t in iptables ip6tables; do
     command -v "$t" >/dev/null 2>&1 || continue
@@ -43,12 +66,19 @@ base() {
 # apply swaps in a fresh chain of host rules: the new chain is reachable before the old one goes.
 apply() {
   addrs="$1"
+  svc="$2"
   old="$(cat "$STATE/chain" 2>/dev/null || true)"
   if [ "$old" = YGG_HOSTS_A ]; then new=YGG_HOSTS_B; else new=YGG_HOSTS_A; fi
   iptables -N "$new" 2>/dev/null || iptables -F "$new"
   for ip in $addrs; do
     iptables -A "$new" -p tcp -d "$ip" --dport 443 -j ACCEPT
   done
+  while read -r ip port; do
+    [ -n "$ip" ] || continue
+    iptables -A "$new" -p tcp -d "$ip" --dport "$port" -j ACCEPT
+  done <<EOF
+$svc
+EOF
   iptables -A OUTPUT -j "$new"
   if [ -n "$old" ]; then
     iptables -D OUTPUT -j "$old"
@@ -58,10 +88,11 @@ apply() {
 }
 
 addrs="$(resolve)"
+svcs="$(resolve_services)"
 base
-apply "$addrs"
+apply "$addrs" "$svcs"
 touch "$STATE/ready"
 [ "${YGG_ONCE:-}" = 1 ] && exit 0
 while sleep "$REFRESH"; do
-  if addrs="$(resolve)"; then apply "$addrs"; else echo "egress: keeping the earlier addresses" >&2; fi
+  if addrs="$(resolve)" && svcs="$(resolve_services)"; then apply "$addrs" "$svcs"; else echo "egress: keeping the earlier addresses" >&2; fi
 done
```

Apply to `sandbox/config.go`:

```diff
diff --git a/sandbox/config.go b/sandbox/config.go
index e54315b..0c71e1a 100644
--- a/sandbox/config.go
+++ b/sandbox/config.go
@@ -83,6 +83,7 @@ type Generated struct {
 	Compose      string
 	Devcontainer string
 	Hosts        string // the firewall's host list
+	Services     string // the firewall's list of service ports: "name port" lines
 }
 
 // Project returns the compose project name of a sandbox: one per run and leaf. It is lower-case letters
@@ -172,7 +173,7 @@ func render(dir string, spec gungnir.SandboxSpec, c Config) (map[string][]byte,
 	labels := map[string]string{LabelRun: spec.Run, LabelLeaf: spec.Name}
 	cf := composeFile{Name: Project(spec), Services: map[string]service{
 		"fw": {
-			Image: c.Images.Firewall, PullPolicy: "never", Command: []string{"sh", "/etc/ygg-fw/egress.sh", "/etc/ygg-fw/hosts"},
+			Image: c.Images.Firewall, PullPolicy: "never", Command: []string{"sh", "/etc/ygg-fw/egress.sh", "/etc/ygg-fw/hosts", "/etc/ygg-fw/services"},
 			// root of its own user namespace: keep-id alone would run it as the operator, who can't write rules
 			User: "0:0", UsernsMode: "keep-id", CapAdd: []string{"NET_ADMIN"}, Labels: labels,
 			Volumes: []string{fwEngine + ":/etc/ygg-fw:ro,Z"},
@@ -207,7 +208,7 @@ func render(dir string, spec gungnir.SandboxSpec, c Config) (map[string][]byte,
 		"name": Project(spec), "dockerComposeFile": "compose.yaml", "service": "work",
 		"workspaceFolder": Root + "/" + l.Leaf, "updateRemoteUserUID": false, "shutdownAction": "stopCompose",
 	}
-	g := Generated{Dir: dir, Compose: filepath.Join(dir, "compose.yaml"), Devcontainer: filepath.Join(dir, "devcontainer.json"), Hosts: filepath.Join(fwDir, "hosts")}
+	g := Generated{Dir: dir, Compose: filepath.Join(dir, "compose.yaml"), Devcontainer: filepath.Join(dir, "devcontainer.json"), Hosts: filepath.Join(fwDir, "hosts"), Services: filepath.Join(fwDir, "services")}
 	composeYAML, err := yaml.Marshal(cf)
 	if err != nil {
 		return nil, Generated{}, err
@@ -220,8 +221,14 @@ func render(dir string, spec gungnir.SandboxSpec, c Config) (map[string][]byte,
 	if hosts != "" {
 		hosts += "\n"
 	}
+	var ports strings.Builder
+	for _, v := range slices.SortedFunc(slices.Values(spec.Services), func(a, b gungnir.Service) int { return strings.Compare(a.Name, b.Name) }) {
+		for _, p := range v.Ports {
+			fmt.Fprintf(&ports, "%s %d\n", v.Name, p)
+		}
+	}
 	return map[string][]byte{
-		g.Compose: composeYAML, g.Devcontainer: append(dcJSON, '\n'), g.Hosts: []byte(hosts),
+		g.Compose: composeYAML, g.Devcontainer: append(dcJSON, '\n'), g.Hosts: []byte(hosts), g.Services: []byte(ports.String()),
 		filepath.Join(fwDir, "egress.sh"): []byte(EgressScript),
 	}, g, nil
 }
```

Apply to `sandbox/validate.go`:

```diff
diff --git a/sandbox/validate.go b/sandbox/validate.go
index 51425b7..4afc343 100644
--- a/sandbox/validate.go
+++ b/sandbox/validate.go
@@ -159,6 +159,7 @@ func differences(g Generated, spec gungnir.SandboxSpec, c Config) []string {
 		{"devcontainer.json", g.Devcontainer, parseJSON},
 		{"compose.yaml", g.Compose, parseYAML},
 		{"fw/hosts", g.Hosts, parseRaw},
+		{"fw/services", g.Services, parseRaw},
 		{"fw/egress.sh", filepath.Join(filepath.Dir(g.Hosts), "egress.sh"), parseRaw},
 	} {
 		got, err := readParsed(f.path, f.parse)
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T160: each sandbox starts on the stack layer its spec names, so leaves of different realms differ

Change `realm-leaf-naming`: "the leaf's sandbox gets that realm's stack layer". A run with a React leaf and a Go leaf starts two kinds of work container.

**Files (in `gleipnir`):**
- Create: `sandbox/stack_test.go`
- Modify: `sandbox/config.go`, `sandbox/driver.go`

**Interfaces:**
- Produces: `Config.ImagesOf(spec) Images`, the images of `spec.Stack` (`ImagesFor`), or the config's own when the spec names none; the compose file and `Up`'s check that the images exist use it. The firewall image does not depend on the stack.

**Acceptance criteria:**
- [ ] Two specs with two stacks get two work images and one firewall image; a spec with none gets the config's.
- [ ] `Up` checks the images of the stack it was given, and a missing one is `ErrNoImage` naming it.
- [ ] A config with no images and a spec with no stack is refused; a spec with a stack needs no images in the config.

**Named test:** `go test ./sandbox -run 'TestEachLeafStartsOnTheStackLayerOfItsRealm|TestUpChecksTheImagesOfTheStackItWasGiven|TestAConfigWithNoImagesAndASpecWithNoStackIsRefused'` in `gleipnir`. **Layer:** `gleipnir`. **Size:** M (100). **Depends on:** v0-T159.

- [ ] **Step 1:** write the tests.

Write `sandbox/stack_test.go`:

```go
package sandbox

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"go.yaml.in/yaml/v3"
)

const otherStack = "docker.io/library/node:24.1.0-bookworm@sha256:3333333333333333333333333333333333333333333333333333333333333333"

func TestEachLeafStartsOnTheStackLayerOfItsRealm(t *testing.T) {
	tmp := t.TempDir()
	c := cfg()
	c.Mounts = append(c.Mounts, PathMap{Host: tmp, Engine: "/mnt/wsl/cfg"})
	work := func(stack string) (workImage, fwImage string) {
		sp := spec("/home/ana/ygg/proj")
		sp.Stack = stack
		g, err := Generate(filepath.Join(tmp, "s", strings.ReplaceAll(stack, "/", "_")), sp, c)
		if err != nil {
			t.Fatal(err)
		}
		var cf composeFile
		raw, _ := os.ReadFile(g.Compose)
		if err := yaml.Unmarshal(raw, &cf); err != nil {
			t.Fatal(err)
		}
		return cf.Services["work"].Image, cf.Services["fw"].Image
	}
	goWork, goFW := work(stackImg)
	nodeWork, nodeFW := work(otherStack)
	defWork, defFW := work("")
	if goWork != ImagesFor(stackImg).Work || nodeWork != ImagesFor(otherStack).Work {
		t.Errorf("work images %q and %q; want each realm's own stack layer", goWork, nodeWork)
	}
	if goWork == nodeWork {
		t.Error("two realms with two stacks got one work image")
	}
	if goFW != nodeFW || goFW != ImagesFor(stackImg).Firewall {
		t.Errorf("firewall images %q and %q; the firewall does not depend on the stack", goFW, nodeFW)
	}
	if defWork != c.Images.Work || defFW != c.Images.Firewall {
		t.Errorf("a spec with no stack uses the driver's images: %q, %q", defWork, defFW)
	}
}

func TestUpChecksTheImagesOfTheStackItWasGiven(t *testing.T) {
	d, log, sp := fakeEngine(t)
	sp.Stack = otherStack
	if _, err := d.Up(context.Background(), sp); err != nil {
		t.Fatal(err)
	}
	got := logOf(t, log)
	for _, want := range []string{"image exists " + ImagesFor(otherStack).Work, "image exists " + ImagesFor(otherStack).Firewall} {
		if !strings.Contains(got, want) {
			t.Errorf("Up did not check %q:\n%s", want, got)
		}
	}
	if strings.Contains(got, "image exists "+d.cfg.Images.Work) {
		t.Errorf("Up checked the driver's default work image for a spec with a stack:\n%s", got)
	}
	t.Setenv("STUB_MISSING", ImagesFor(otherStack).Work)
	d2, _, sp2 := fakeEngine(t)
	sp2.Stack = otherStack
	if _, err := d2.Up(context.Background(), sp2); !errors.Is(err, ErrNoImage) || !strings.Contains(err.Error(), ImagesFor(otherStack).Work) {
		t.Errorf("a missing image of the realm's stack: Up() = %v", err)
	}
}

func TestAConfigWithNoImagesAndASpecWithNoStackIsRefused(t *testing.T) {
	c := cfg()
	c.Images = Images{}
	if _, err := Generate(t.TempDir(), spec("/home/ana/ygg/proj"), Config{Images: c.Images, UID: 1000, GID: 1000}); err == nil {
		t.Error("a sandbox with no images at all was generated")
	}
	sp := spec("/home/ana/ygg/proj")
	sp.Stack = stackImg
	if _, err := Generate(t.TempDir(), sp, Config{UID: 1000, GID: 1000}); err != nil {
		t.Errorf("a spec with a stack needs no default images: %v", err)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestEachLeafStartsOnTheStackLayerOfItsRealm (0.00s)
    stack_test.go:38: work images "localhost/ygg-work:abc" and "localhost/ygg-work:abc"; want each realm's own stack layer
    stack_test.go:41: two realms with two stacks got one work image
    stack_test.go:44: firewall images "localhost/ygg-fw:abc" and "localhost/ygg-fw:abc"; the firewall does not depend on the stack
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/config.go`:

```diff
diff --git a/sandbox/config.go b/sandbox/config.go
index 0c71e1a..79884c2 100644
--- a/sandbox/config.go
+++ b/sandbox/config.go
@@ -57,6 +57,15 @@ type Config struct {
 	GID    int
 }
 
+// ImagesOf returns the images a sandbox of spec starts: those of the spec's stack layer, so each leaf
+// runs on its own realm's stack, or the driver's own when the spec names none.
+func (c Config) ImagesOf(s gungnir.SandboxSpec) Images {
+	if s.Stack != "" {
+		return ImagesFor(s.Stack)
+	}
+	return c.Images
+}
+
 // MapPath returns the path the engine sees for host path p. With no mounts configured, the engine
 // is taken to see the host's paths. With mounts, a path outside all of them is an error: the
 // engine could not mount it.
@@ -148,7 +157,8 @@ func render(dir string, spec gungnir.SandboxSpec, c Config) (map[string][]byte,
 	if err := spec.Validate(); err != nil {
 		return nil, Generated{}, err
 	}
-	if c.Images.Work == "" || c.Images.Firewall == "" || c.UID <= 0 || c.GID <= 0 {
+	images := c.ImagesOf(spec)
+	if images.Work == "" || images.Firewall == "" || c.UID <= 0 || c.GID <= 0 {
 		return nil, Generated{}, errors.New("the driver needs both images and a non-root uid and gid")
 	}
 	for _, p := range []string{dir} {
@@ -173,13 +183,13 @@ func render(dir string, spec gungnir.SandboxSpec, c Config) (map[string][]byte,
 	labels := map[string]string{LabelRun: spec.Run, LabelLeaf: spec.Name}
 	cf := composeFile{Name: Project(spec), Services: map[string]service{
 		"fw": {
-			Image: c.Images.Firewall, PullPolicy: "never", Command: []string{"sh", "/etc/ygg-fw/egress.sh", "/etc/ygg-fw/hosts", "/etc/ygg-fw/services"},
+			Image: images.Firewall, PullPolicy: "never", Command: []string{"sh", "/etc/ygg-fw/egress.sh", "/etc/ygg-fw/hosts", "/etc/ygg-fw/services"},
 			// root of its own user namespace: keep-id alone would run it as the operator, who can't write rules
 			User: "0:0", UsernsMode: "keep-id", CapAdd: []string{"NET_ADMIN"}, Labels: labels,
 			Volumes: []string{fwEngine + ":/etc/ygg-fw:ro,Z"},
 		},
 		"work": {
-			Image: c.Images.Work, PullPolicy: "never", Command: []string{"sleep", "infinity"},
+			Image: images.Work, PullPolicy: "never", Command: []string{"sleep", "infinity"},
 			User: fmt.Sprintf("%d:%d", c.UID, c.GID), UsernsMode: "keep-id",
 			CapDrop: []string{"ALL"}, SecurityOpt: []string{"no-new-privileges:true"},
 			NetworkMode: "service:fw", DependsOn: []string{"fw"},
```

Apply to `sandbox/driver.go`:

```diff
diff --git a/sandbox/driver.go b/sandbox/driver.go
index 1d630f3..dc502fc 100644
--- a/sandbox/driver.go
+++ b/sandbox/driver.go
@@ -107,7 +107,8 @@ func (d *Driver) Up(ctx context.Context, spec gungnir.SandboxSpec) (gungnir.Env,
 	if err := Validate(g, spec, d.cfg); err != nil {
 		return gungnir.Env{}, err
 	}
-	for _, img := range []string{d.cfg.Images.Work, d.cfg.Images.Firewall} {
+	imgs := d.cfg.ImagesOf(spec)
+	for _, img := range []string{imgs.Work, imgs.Firewall} {
 		if _, err := d.run(ctx, d.Podman, "image", "exists", img); err != nil {
 			return gungnir.Env{}, fmt.Errorf("%w: %s (run ygg sandbox build)", ErrNoImage, img)
 		}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T161: a scratch sandbox: one plain folder, no git dir

Spec §3.3 rule 1: a planner gets a scratch directory, never an umbrella and never a leaf. Its sandbox mounts that folder and nothing else.

**Files (in `gleipnir`):**
- Create: `sandbox/scratch_test.go`
- Modify: `sandbox/config.go`

**Interfaces:**
- Consumes: `SandboxSpec.Scratch` (v0-T144).
- Produces: for a scratch spec, one work volume (the folder, read-write, at `/u/<its path under the parent>`), no git dir mounted or looked up, and the same hardening, firewall and validation as a leaf's.

**Acceptance criteria:**
- [ ] A scratch spec renders a work container with the one volume, a devcontainer whose workspace is that folder, and no mention of a git dir; `Validate` accepts what `Generate` wrote.
- [ ] A scratch folder the engine cannot see is refused ("can't see"); `Up` starts a scratch sandbox and reports the workspace as its working directory.

**Named test:** `go test ./sandbox -run 'TestAScratchSandboxMountsOneFolderAndNothingElse|TestUpStartsAScratchSandbox'` in `gleipnir`. **Layer:** `gleipnir`. **Size:** S (86). **Depends on:** v0-T160.

- [ ] **Step 1:** write the tests.

Write `sandbox/scratch_test.go`:

```go
package sandbox

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"go.yaml.in/yaml/v3"
)

func scratchSpec(parent string) gungnir.SandboxSpec {
	return gungnir.SandboxSpec{Run: "20261016-101500-a1b2c3", Name: "scratch/design", Scratch: true, Parent: parent,
		Leaf: parent + "/scratch/design", Egress: []string{"api.anthropic.com"}}
}

func TestAScratchSandboxMountsOneFolderAndNothingElse(t *testing.T) {
	tmp := t.TempDir()
	c := cfg()
	c.Mounts = append(c.Mounts, PathMap{Host: tmp, Engine: "/mnt/wsl/cfg"})
	sp := scratchSpec("/home/ana/ygg/proj/.factory/runs/r1")
	g, err := Generate(filepath.Join(tmp, "sandbox"), sp, c)
	if err != nil {
		t.Fatal(err)
	}
	var cf composeFile
	raw, _ := os.ReadFile(g.Compose)
	if err := yaml.Unmarshal(raw, &cf); err != nil {
		t.Fatal(err)
	}
	wantVols := []string{"/mnt/wsl/ygg-bind/proj/.factory/runs/r1/scratch/design:/u/scratch/design:Z"}
	if got := cf.Services["work"].Volumes; strings.Join(got, "|") != strings.Join(wantVols, "|") {
		t.Errorf("work volumes = %q, want only the scratch folder", got)
	}
	if strings.Contains(string(raw), ".git") {
		t.Errorf("a scratch sandbox mentions a git dir:\n%s", raw)
	}
	if dc, _ := os.ReadFile(g.Devcontainer); !strings.Contains(string(dc), `"workspaceFolder": "/u/scratch/design"`) {
		t.Errorf("devcontainer.json = %s", dc)
	}
	if err := Validate(g, sp, c); err != nil {
		t.Errorf("Validate() = %v on what Generate wrote", err)
	}
	elsewhere := Config{Images: c.Images, UID: 1000, GID: 1000, Mounts: []PathMap{{Host: "/home/ana/other", Engine: "/mnt/x"}}}
	if _, err := Generate(filepath.Join(tmp, "unseen"), scratchSpec("/home/ana/ygg/proj/.factory/runs/r1"), elsewhere); err == nil || !strings.Contains(err.Error(), "can't see") {
		t.Errorf("a scratch folder the engine can't see: %v", err)
	}
}

func TestUpStartsAScratchSandbox(t *testing.T) {
	d, log, _ := fakeEngine(t)
	parent := t.TempDir()
	sp := scratchSpec(parent)
	if err := os.MkdirAll(sp.Leaf, 0o755); err != nil {
		t.Fatal(err)
	}
	d.cfg.Mounts = []PathMap{{Host: filepath.Dir(parent), Engine: "/mnt/wsl/t"}, {Host: d.work, Engine: "/mnt/wsl/w"}}
	env, err := d.Up(context.Background(), sp)
	if err != nil {
		t.Fatal(err)
	}
	if env.Workdir != "/u/scratch/design" || env.Name != "scratch/design" {
		t.Errorf("env = %+v", env)
	}
	if got := logOf(t, log); !strings.Contains(got, "--workspace-folder "+sp.Leaf) {
		t.Errorf("devcontainer was not pointed at the scratch folder:\n%s", got)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAScratchSandboxMountsOneFolderAndNothingElse (0.00s)
    scratch_test.go:26: the engine can't see : add a sandbox.mounts entry for it in factory.yaml
--- FAIL: TestUpStartsAScratchSandbox (0.00s)
    scratch_test.go:62: the engine can't see : add a sandbox.mounts entry for it in factory.yaml
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/config.go`:

```diff
diff --git a/sandbox/config.go b/sandbox/config.go
index 79884c2..1ab51be 100644
--- a/sandbox/config.go
+++ b/sandbox/config.go
@@ -132,6 +132,16 @@ type service struct {
 	Volumes     []string          `yaml:"volumes,omitempty"`
 }
 
+// workVolumes are the work container's mounts: the leaf read-write and its git dir read-only, mirrored
+// under Root; for a scratch folder, the folder alone.
+func workVolumes(spec gungnir.SandboxSpec, l gungnir.Layout, leaf, git string) []string {
+	vols := []string{leaf + ":" + Root + "/" + l.Leaf + ":Z"}
+	if !spec.Scratch {
+		vols = append(vols, git+":"+Root+"/"+l.GitDir+":ro,Z")
+	}
+	return vols
+}
+
 // Generate writes a sandbox's devcontainer.json, compose.yaml and firewall host list into dir,
 // which must be outside the leaf. The files are the only configuration Up reads: nothing in the leaf
 // can reach them or change them (spec §6.2). Generate doesn't check its own output; Up does, before
@@ -170,9 +180,11 @@ func render(dir string, spec gungnir.SandboxSpec, c Config) (map[string][]byte,
 	if err != nil {
 		return nil, Generated{}, err
 	}
-	git, err := c.MapPath(spec.GitDir)
-	if err != nil {
-		return nil, Generated{}, err
+	var git string
+	if !spec.Scratch { // a scratch folder is no repo: it has no git dir to mount
+		if git, err = c.MapPath(spec.GitDir); err != nil {
+			return nil, Generated{}, err
+		}
 	}
 	fwDir := filepath.Join(dir, "fw")
 	fwEngine, err := c.MapPath(fwDir)
@@ -194,10 +206,7 @@ func render(dir string, spec gungnir.SandboxSpec, c Config) (map[string][]byte,
 			CapDrop: []string{"ALL"}, SecurityOpt: []string{"no-new-privileges:true"},
 			NetworkMode: "service:fw", DependsOn: []string{"fw"},
 			Environment: maps.Clone(homeEnv), Labels: labels,
-			Volumes: []string{
-				leaf + ":" + Root + "/" + l.Leaf + ":Z",
-				git + ":" + Root + "/" + l.GitDir + ":ro,Z",
-			},
+			Volumes: workVolumes(spec, l, leaf, git),
 		},
 	}}
 	// The services a leaf's realm, and the realms of the leaves it consumes, ask for. They run on the
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T162: integration tests of services and scratch folders on a real engine, behind the sandbox tag

Phase 3's integration tests of the driver run on a real engine behind the `sandbox` tag (spec §13). Services and scratch folders need the same kind of test: only a real engine shows that the work container reaches a service by name, through the firewall, on its ports only. This task writes the tests; the founder runs them (v0-H12).

**Files (in `gleipnir`):**
- Create: `sandbox/integration_services_test.go`

**Interfaces:**
- Consumes: the environment of Phase 3's tests (`YGG_SANDBOX_ENGINE`, `YGG_SANDBOX_TREE`, `YGG_SANDBOX_TREE_ENGINE`), plus `YGG_SANDBOX_SERVICE_IMAGE` (an image pinned by digest that listens on a port) and `YGG_SANDBOX_SERVICE_PORT`.
- Tests: a service is reachable by name on its listed port and on no other port, the open internet stays closed beside it, and `Down` leaves nothing; a scratch sandbox holds the folder and nothing beside it, no git dir, and writes in it reach the host.

**Acceptance criteria:**
- [ ] The tests compile and vet under `-tags sandbox`, and skip without the environment.
- [ ] The founder's run (v0-H12) passes.

**Named test:** `go vet -tags sandbox ./sandbox && go test -tags sandbox -run 'TestSandboxServices|TestSandboxScratch' -v ./sandbox   # skips without the environment` in `gleipnir`. **Layer:** `gleipnir`. **Size:** M (139). **Depends on:** v0-T161.

- [ ] **Step 1:** write the tests.

Write `sandbox/integration_services_test.go`:

```go
//go:build sandbox

package sandbox

// Integration tests of services and scratch folders on a real engine (spec §13: behind a build tag, with
// the same environment as TestSandboxDriverOnARealEngine). A service needs an image that listens on a
// port, pinned by digest; set
//
//	YGG_SANDBOX_SERVICE_IMAGE   such as docker.io/library/nginx:1.27-alpine@sha256:<digest>
//	YGG_SANDBOX_SERVICE_PORT    the port it listens on, such as 80
//
// then run: go test -tags sandbox -run 'TestSandboxServices|TestSandboxScratch' -v -timeout 40m ./sandbox

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
)

// itDriver returns a driver on the real engine with the images built for itStack.
func itDriver(t *testing.T, ctx context.Context) (*Driver, string) {
	t.Helper()
	socket, tree, engineTree := itEnv(t)
	cfg := Config{Mounts: []PathMap{{Host: tree, Engine: engineTree}}, Images: ImagesFor(itStack), UID: os.Getuid(), GID: os.Getgid()}
	work, err := os.MkdirTemp(tree, "work-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(work) })
	d, err := New(socket, cfg, work)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := d.run(ctx, d.Podman, "image", "exists", cfg.Images.Work); err != nil {
		t.Logf("building the images (a few minutes)")
		if _, err := d.Build(ctx, itStack); err != nil {
			t.Fatalf("Build() = %v", err)
		}
	}
	return d, tree
}

func inSandbox(t *testing.T, ctx context.Context, d *Driver, env gungnir.Env, argv ...string) (int, string) {
	t.Helper()
	var out bytes.Buffer
	res, err := d.Exec(ctx, env, gungnir.Cmd{Argv: argv, Stdout: &out, Stderr: &out})
	if err != nil {
		t.Fatalf("%v: %v", argv, err)
	}
	return res.ExitCode, strings.TrimSpace(out.String())
}

func TestSandboxServicesAreReachableByNameOnTheirPortsOnly(t *testing.T) {
	image, portText := os.Getenv("YGG_SANDBOX_SERVICE_IMAGE"), os.Getenv("YGG_SANDBOX_SERVICE_PORT")
	if image == "" || portText == "" {
		t.Skip("set YGG_SANDBOX_SERVICE_IMAGE and YGG_SANDBOX_SERVICE_PORT to run this test")
	}
	port, err := strconv.Atoi(portText)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 35*time.Minute)
	defer cancel()
	d, tree := itDriver(t, ctx)
	spec := itTree(t, tree)
	spec.Services = []gungnir.Service{{Name: "svc", Image: image, Ports: []int{port}}}
	env, err := d.Up(ctx, spec)
	if err != nil {
		t.Fatalf("Up() = %v", err)
	}
	t.Cleanup(func() { d.Down(context.Background(), env) })
	reach := func(host string, p int) int {
		code, _ := inSandbox(t, ctx, d, env, "timeout", "6", "bash", "-c", "exec 3<>/dev/tcp/"+host+"/"+strconv.Itoa(p))
		return code
	}
	if code := reach("svc", port); code != 0 {
		t.Errorf("the service on its listed port: exit %d; the work container reaches it by name", code)
	}
	if code := reach("svc", port+1); code == 0 {
		t.Errorf("the service on %d, which is not listed: reachable", port+1)
	}
	if code := reach("1.1.1.1", 443); code == 0 {
		t.Error("the open internet is reachable beside the service")
	}
	if err := d.Down(ctx, env); err != nil {
		t.Fatalf("Down() = %v", err)
	}
	left, err := d.Leftovers(ctx)
	if err != nil {
		t.Fatal(err)
	}
	for _, l := range left {
		if l.Run == spec.Run {
			t.Errorf("Down left %+v, the service's container among them", l)
		}
	}
}

func TestSandboxScratchHoldsOneFolderAndNothingElse(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 35*time.Minute)
	defer cancel()
	d, tree := itDriver(t, ctx)
	parent, err := os.MkdirTemp(tree, "scratch-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { os.RemoveAll(parent) })
	folder := filepath.Join(parent, "scratch", "design")
	os.MkdirAll(filepath.Join(folder, "out"), 0o755)
	os.WriteFile(filepath.Join(parent, "outside.txt"), []byte("not in the workspace"), 0o644)
	spec := gungnir.SandboxSpec{Run: "20261016-130000-a1b2c3", Name: "scratch/design", Scratch: true, Parent: parent, Leaf: folder,
		Egress: []string{"api.anthropic.com"}}
	env, err := d.Up(ctx, spec)
	if err != nil {
		t.Fatalf("Up() = %v", err)
	}
	t.Cleanup(func() { d.Down(context.Background(), env) })
	if code, out := inSandbox(t, ctx, d, env, "sh", "-c", "echo x > out/made.txt && pwd"); code != 0 || !strings.HasSuffix(out, "/scratch/design") {
		t.Errorf("a write in the workspace: exit %d, %q", code, out)
	}
	if b, err := os.ReadFile(filepath.Join(folder, "out", "made.txt")); err != nil || strings.TrimSpace(string(b)) != "x" {
		t.Errorf("the workspace on the host holds %q, %v", b, err)
	}
	for name, argv := range map[string][]string{
		"a file beside the workspace": {"test", "-e", "../../outside.txt"},
		"a git dir":                   {"sh", "-c", "ls /u/.git 2>/dev/null | grep -q ."},
	} {
		if code, _ := inSandbox(t, ctx, d, env, argv...); code == 0 {
			t.Errorf("%s is there", name)
		}
	}
}
```

- [ ] **Step 2:** run the named test. It passes at once, because the code or data it needs is already there (or the test is skipped without its build tag): expect `ok`.

- [ ] **Step 3:** run the named test. Expect `ok`.

- [ ] **Step 4:** commit (see "How each task lands").

---

### Task v0-T163: Up refuses a service image that was never pulled, and Pull fetches one, by digest, with the isolated auth

A sandbox's compose file uses a service's image with `pull_policy: never`, because a run never pulls (spec §16 item 7). Something must pull it, with the isolated registry auth, and a run must say so when it was not pulled.

**Files (in `gleipnir`):**
- Modify: `sandbox/driver.go`, `sandbox/images.go`, `sandbox/services_test.go`

**Interfaces:**
- Produces: `Driver.Pull(ctx, image) error`: `podman pull -q` with the isolated `--authfile`, and only for an image pinned by digest; `Driver.Up` refuses, before it starts anything, a service whose image the engine lacks: `ErrNoImage`, naming the image and `ygg sandbox build`.

**Acceptance criteria:**
- [ ] `Up` with a service image the engine lacks returns `ErrNoImage` naming it, and starts nothing.
- [ ] `Pull` calls the engine with the isolated auth and never with the shell's, and refuses a tag, a bare name, an empty string and a short digest.

**Named test:** `go test ./sandbox -run 'TestUpRefusesAServiceImageThatWasNeverPulled|TestPullFetchesAnImageWithTheIsolatedAuthAndOnlyADigestPinnedOne'` in `gleipnir`. **Layer:** `gleipnir`. **Size:** S (51). **Depends on:** v0-T158.

- [ ] **Step 1:** write the tests.

Apply to `sandbox/services_test.go`:

```diff
diff --git a/sandbox/services_test.go b/sandbox/services_test.go
index 60afb42..e0ad982 100644
--- a/sandbox/services_test.go
+++ b/sandbox/services_test.go
@@ -1,6 +1,7 @@
 package sandbox
 
 import (
+	"context"
 	"errors"
 	"os"
 	"path/filepath"
@@ -142,3 +143,35 @@ func TestTheFirewallIsToldWhichServicePortsToOpen(t *testing.T) {
 		t.Errorf("fw/services for a sandbox with no services = %q, %v; want an empty file", b, err)
 	}
 }
+
+func TestUpRefusesAServiceImageThatWasNeverPulled(t *testing.T) {
+	d, log, sp := fakeEngine(t)
+	sp.Services = []gungnir.Service{{Name: "postgres", Image: pgImage, Ports: []int{5432}}}
+	t.Setenv("STUB_MISSING", pgImage)
+	_, err := d.Up(context.Background(), sp)
+	if !errors.Is(err, ErrNoImage) || !strings.Contains(err.Error(), pgImage) || !strings.Contains(err.Error(), "ygg sandbox build") {
+		t.Fatalf("Up() = %v; want ErrNoImage naming the service's image and the command that pulls it", err)
+	}
+	if got := logOf(t, log); strings.Contains(got, "devcontainer up") {
+		t.Errorf("the sandbox was started although a service image was missing:\n%s", got)
+	}
+}
+
+func TestPullFetchesAnImageWithTheIsolatedAuthAndOnlyADigestPinnedOne(t *testing.T) {
+	d, log, _ := fakeEngine(t)
+	if err := d.Pull(context.Background(), pgImage); err != nil {
+		t.Fatalf("Pull() = %v", err)
+	}
+	got := logOf(t, log)
+	if !strings.Contains(got, "podman pull -q --authfile "+filepath.Join(d.work, "registry-auth", "auth.json")+" "+pgImage) {
+		t.Errorf("the engine calls:\n%s", got)
+	}
+	if strings.Contains(got, "docker.sock") {
+		t.Errorf("a call used the shell's engine:\n%s", got)
+	}
+	for _, bad := range []string{"docker.io/library/postgres:17.2", "postgres", "", "docker.io/library/postgres@sha256:short"} {
+		if err := d.Pull(context.Background(), bad); err == nil {
+			t.Errorf("Pull(%q) = nil; an image that is not pinned by digest is not pulled", bad)
+		}
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gleipnir/sandbox [github.com/ouroboric-dev/gleipnir/sandbox.test]
sandbox/services_test.go:162:14: d.Pull undefined (type *Driver has no field or method Pull)
sandbox/services_test.go:173:15: d.Pull undefined (type *Driver has no field or method Pull)
FAIL	github.com/ouroboric-dev/gleipnir/sandbox [build failed]
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/driver.go`:

```diff
diff --git a/sandbox/driver.go b/sandbox/driver.go
index dc502fc..88be77a 100644
--- a/sandbox/driver.go
+++ b/sandbox/driver.go
@@ -108,7 +108,11 @@ func (d *Driver) Up(ctx context.Context, spec gungnir.SandboxSpec) (gungnir.Env,
 		return gungnir.Env{}, err
 	}
 	imgs := d.cfg.ImagesOf(spec)
-	for _, img := range []string{imgs.Work, imgs.Firewall} {
+	needed := []string{imgs.Work, imgs.Firewall}
+	for _, v := range spec.Services {
+		needed = append(needed, v.Image)
+	}
+	for _, img := range needed {
 		if _, err := d.run(ctx, d.Podman, "image", "exists", img); err != nil {
 			return gungnir.Env{}, fmt.Errorf("%w: %s (run ygg sandbox build)", ErrNoImage, img)
 		}
```

Apply to `sandbox/images.go`:

```diff
diff --git a/sandbox/images.go b/sandbox/images.go
index 7339761..481f510 100644
--- a/sandbox/images.go
+++ b/sandbox/images.go
@@ -8,6 +8,8 @@ import (
 	"fmt"
 	"os"
 	"path/filepath"
+
+	"github.com/ouroboric-dev/gungnir"
 )
 
 //go:embed assets/Containerfile
@@ -42,6 +44,17 @@ func ImagesFor(stack string) Images {
 	return Images{Work: "localhost/ygg-work:" + hex.EncodeToString(h.Sum(nil))[:12], Firewall: "localhost/ygg-fw:" + fw}
 }
 
+// Pull fetches one image, which must be pinned by digest, with the isolated registry auth: a service's
+// image, which a sandbox's compose file uses without ever pulling it (a run never pulls). Like Build, it
+// is for ygg sandbox build alone.
+func (d *Driver) Pull(ctx context.Context, image string) error {
+	if !gungnir.ValidImage(image) {
+		return fmt.Errorf("%q is not an image pinned by digest, so it is not pulled", image)
+	}
+	_, err := d.run(ctx, d.Podman, "pull", "-q", "--authfile", filepath.Join(d.auth, "auth.json"), image)
+	return err
+}
+
 // Build pulls the bases by digest, with the isolated auth, and builds the firewall and work images
 // for stack. It is the only call that reaches a registry, and ygg sandbox build is the only caller:
 // a run never pulls or builds.
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T164: Gleipnir's documentation

The architecture page says what the component now does for realms and tasks.

**Files (in `gleipnir`):**
- Modify: `docs/architecture.md`

**Acceptance criteria:**
- [ ] `docs/architecture.md` says a sandbox starts its leaf's services and opens their ports only, starts on the stack of its spec, and may hold a scratch folder.

**Named test:** `go test ./...` in `gleipnir`. **Layer:** `gleipnir`. **Size:** S (5). **Depends on:** v0-T163.

- [ ] **Step 1:** write the code.

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index cf253d9..0e6f9e5 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -17,6 +17,11 @@ The harness: agent adapters, the devcontainer sandbox driver, policies and the c
 - Loads skills explicitly per task, from Havamal at a pinned version (spec §5.1).
 - Runs commands in sandboxes and applies policies: devcontainer hardening, managed settings and
   the egress firewall (spec §6).
+- Starts, beside the work container, the services a leaf's realm and the realms of the leaves it
+  consumes ask for (a database, object storage), and opens their ports, and only theirs, to the work
+  container through the firewall. Each sandbox starts on the stack layer its spec names, so leaves of
+  different realms differ. A scratch sandbox holds one folder and no git directory: a planner's
+  workspace (spec §3.3).
 - Runs checks.
 
 ## Depends on
```

- [ ] **Step 2:** run the named test. Expect `ok`.

- [ ] **Step 3:** commit (see "How each task lands").

---

### Task v0-T165: a loop that passed can be reopened when something downstream refuses its work

Jormungandr's first task. Branch `realms/loop` from `main` in `jormungandr`, before step 1. It needs v0-T156 merged and pinned only for the module's own build (it uses Gungnir alone). Spec §4.5: the merge gate's failure "returns to the loop". A loop that passed is finished (`Run` returns at once), so the work needs a way back in.

**Files (in `jormungandr`):**
- Create: `reopen_test.go`
- Modify: `loop.go`

**Interfaces:**
- Produces: `(*State).Reopen(cfg Config)`. A passed loop starts the next attempt as a new one, with the limit raised to a full set of attempts from there, the findings as they were, no failure and no unreadable reviewer. A loop that is not finished is extended as an operator's rejection extends it.

**Acceptance criteria:**
- [ ] A loop that passed at attempt 1 and is reopened runs the implementer once more as attempt 2, with the findings it held open, and passes in attempt 2.
- [ ] An escalated loop that is reopened has a full set of attempts again.

**Named test:** `go test . -run 'TestALoopThatPassedIsReopenedWhenSomethingDownstreamRefusesItsWork|TestReopeningALoopThatIsNotFinishedGivesItAFullSetOfAttempts'` in `jormungandr`. **Layer:** `jormungandr`. **Size:** S (58). **Depends on:** Phase 4.

- [ ] **Step 1:** write the tests.

Write `reopen_test.go`:

```go
package jormungandr

import (
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func TestALoopThatPassedIsReopenedWhenSomethingDownstreamRefusesItsWork(t *testing.T) {
	st := NewState(cfg)
	nit := gungnir.Finding{ID: "q-1", Source: "quality", Severity: gungnir.SeverityMinor, Location: "a.go:1", Claim: "a nit", Status: gungnir.FindingOpen}
	f := &fakeSteps{review: map[string][]answer{"quality": {{text: rep(nit)}}}}
	if out := run(t, st, f); out.Kind != Passed || out.Attempts != 1 {
		t.Fatalf("the first run = %+v", out)
	}
	st.Reopen(cfg)
	if st.Passed || st.Attempt != 2 || st.Phase != PhaseImplement || st.Limit != 4 {
		t.Fatalf("after Reopen: passed %v, attempt %d, phase %s, limit %d; want a new attempt 2 with attempts up to 4", st.Passed, st.Attempt, st.Phase, st.Limit)
	}
	again := &fakeSteps{review: map[string][]answer{"quality": {{text: rep(nit)}}}} // a reviewer must mention what it still holds open
	out := run(t, st, again)
	if out.Kind != Passed || out.Attempts != 2 {
		t.Errorf("the reopened loop = %+v; want a pass in attempt 2", out)
	}
	if !again.ran("implement 2") || again.ran("implement 1") {
		t.Errorf("calls = %v; the implementer runs again, once", again.calls)
	}
	if len(again.inputs[0].Open) != 1 || again.inputs[0].Open[0].ID != "q-1" {
		t.Errorf("the findings must stay across a reopening: %+v", again.inputs[0].Open)
	}
}

func TestReopeningALoopThatIsNotFinishedGivesItAFullSetOfAttempts(t *testing.T) {
	f := &fakeSteps{check: map[string][]bool{"test": {false, false, false}}}
	st := NewState(cfg)
	if out := run(t, st, f); out.Kind != Escalated {
		t.Fatalf("Run() = %+v", out)
	}
	st.Reopen(cfg)
	if st.Limit != 6 || st.Attempt != 4 || st.Passed {
		t.Errorf("attempt %d, limit %d, passed %v; an escalated loop is extended, as an operator's rejection does", st.Attempt, st.Limit, st.Passed)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/jormungandr [github.com/ouroboric-dev/jormungandr.test]
./reopen_test.go:16:5: st.Reopen undefined (type *State has no field or method Reopen)
./reopen_test.go:39:5: st.Reopen undefined (type *State has no field or method Reopen)
FAIL	github.com/ouroboric-dev/jormungandr [build failed]
```

- [ ] **Step 3:** write the code.

Apply to `loop.go`:

```diff
diff --git a/loop.go b/loop.go
index eecee0a..cea00f8 100644
--- a/loop.go
+++ b/loop.go
@@ -51,6 +51,21 @@ func (s *State) Extend(cfg Config) {
 	s.Unreadable = nil
 }
 
+// Reopen sends a loop back for another set of attempts after something downstream refused its work, such
+// as the merge gate (spec §4.5). A loop that passed starts a new attempt, with attempts up to the full
+// set again; one that has not finished is extended as an operator's rejection extends it. The findings
+// stay, open or closed, as they were.
+func (s *State) Reopen(cfg Config) {
+	if !s.Passed {
+		s.Extend(cfg)
+		return
+	}
+	s.Passed = false
+	s.Attempt++
+	s.Phase, s.Failure, s.Unreadable = PhaseImplement, "", nil
+	s.Limit = max(s.Limit, s.Attempt+cfg.Attempts-1)
+}
+
 // Input is what an implementer attempt needs besides its prompt.
 type Input struct {
 	Open        []gungnir.Finding // the findings to fix
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T166: the next attempt is told what a later step refused

An implementer reopened by a refusal needs to read it, and not as the operator's words.

**Files (in `jormungandr`):**
- Modify: `prompt.go`, `prompt_test.go`

**Interfaces:**
- Produces: `jormungandr.Refusal(text string) string`, a block that tells the implementer that its work passed and a later step refused it, to fix what the step says and not to say it is fixed (the step decides); empty for no refusal.

**Acceptance criteria:**
- [ ] `Refusal` carries the step's words under a heading of its own, and says nothing for blank text.

**Named test:** `go test . -run 'TestARefusalGoesIntoTheNextAttemptsPrompt'` in `jormungandr`. **Layer:** `jormungandr`. **Size:** S (24). **Depends on:** v0-T165.

- [ ] **Step 1:** write the tests.

Apply to `prompt_test.go`:

```diff
diff --git a/prompt_test.go b/prompt_test.go
index 09ba4b0..6fe37be 100644
--- a/prompt_test.go
+++ b/prompt_test.go
@@ -61,3 +61,15 @@ func TestTheReportFormatTheReviewerIsGivenIsTheOneParseReportReads(t *testing.T)
 		t.Errorf("the example in ReportFormat does not parse: %v\n%s", err, example)
 	}
 }
+
+func TestARefusalGoesIntoTheNextAttemptsPrompt(t *testing.T) {
+	got := Refusal("merge gate refused (conflict): CONFLICT in api/auth.go")
+	for _, want := range []string{"## Refused after your work passed", "merge gate refused (conflict)", "CONFLICT in api/auth.go", "Do not say"} {
+		if !strings.Contains(got, want) {
+			t.Errorf("Refusal() lacks %q:\n%s", want, got)
+		}
+	}
+	if Refusal("  \n") != "" {
+		t.Error("an empty refusal says something")
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/jormungandr [github.com/ouroboric-dev/jormungandr.test]
./prompt_test.go:66:9: undefined: Refusal
./prompt_test.go:72:5: undefined: Refusal
FAIL	github.com/ouroboric-dev/jormungandr [build failed]
```

- [ ] **Step 3:** write the code.

Apply to `prompt.go`:

```diff
diff --git a/prompt.go b/prompt.go
index 50af841..c8353f5 100644
--- a/prompt.go
+++ b/prompt.go
@@ -38,6 +38,18 @@ func Feedback(open []gungnir.Finding, lastFailure, guidance string) string {
 	return b.String()
 }
 
+// Refusal is the text added to an implementer's prompt when a step after the loop refused its work, such
+// as the merge gate (spec §4.5): what the step said, so the attempt can fix it. It is empty for no
+// refusal.
+func Refusal(text string) string {
+	text = strings.TrimSpace(text)
+	if text == "" {
+		return ""
+	}
+	return "## Refused after your work passed\n\nYour work passed its checks and reviewers, and then a later step refused it. " +
+		"Fix what it says. Do not say it is fixed: the step looks again after your work and decides.\n\n" + text + "\n\n"
+}
+
 // ReportFormat explains to a reviewer how to answer (spec §4.6). Its answer is read by a program, and
 // anything that doesn't parse stops the loop.
 const ReportFormat = `Answer with one JSON document and nothing else, not even a sentence before or after it:
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T167: Jormungandr's documentation

The architecture page says what the component now does.

**Files (in `jormungandr`):**
- Modify: `docs/architecture.md`

**Acceptance criteria:**
- [ ] `docs/architecture.md` says a loop that passed is reopened by `Reopen`, and `Refusal` is the text the next prompt carries.

**Named test:** `go test ./...` in `jormungandr`. **Layer:** `jormungandr`. **Size:** S (3). **Depends on:** v0-T166.

- [ ] **Step 1:** write the code.

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 1893582..3b6b023 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -24,6 +24,9 @@ The loop: build, check and fix with attempts, backoff, budgets, feedback and esc
   backoff and is not a loop attempt, a used-up quota pauses the run, an infrastructure failure stops
   it, and anything else counts as a loop attempt (spec §12).
 - Asks the budget before every session, so none starts over a cap (spec §7.4).
+- Reopens a loop that passed when something after it refuses its work, such as the merge gate (spec
+  §4.5): `Reopen` starts another attempt with the findings as they were, and `Refusal` is the text the
+  next implementer prompt carries.
 
 ## How a loop runs
 
```

- [ ] **Step 2:** run the named test. Expect `ok`.

- [ ] **Step 3:** commit (see "How each task lands").

---

### Task v0-T168: realm leaves load from a store, by name, with a hash of what a run could read

Odin's first task. Branch `realms/phase-5a` from `main` in `odin`, before step 1. It needs gungnir's, gleipnir's and jormungandr's pull requests merged and pinned. A run loads its lead realm and the realm of each leaf, each at a pinned version (change `realm-leaf-naming`, backlog B-035). Until now `--realm` was a folder. This task is the loading: find a realm leaf by name in the operator's store, read its pack, and hash what a run could read, so a resume can tell nothing changed under it.

**Files (in `odin`):**
- Create: `internal/realm/realm.go`, `internal/realm/realm_test.go`

**Interfaces:**
- Produces: `realm.Realm{Name, Version, Dir, Hash string; Pack *schema.Pack}`; `realm.Load(dir)`; `realm.Hash(dir)`, a SHA-256 over every file but `.git`'s (its path, its executable bit, its bytes) and every symlink (path and target), in path order, refusing a folder of more than 5,000 files or 64 MiB (a build output, not a realm).
- Produces: `realm.Store{Dir}` with `Find(name)`: `<dir>/<name>`, whose pack must name itself that; `realm.Resolve(ref, store) (dir, byName, err)`: a value with a path separator or a leading dot is a path, anything else a name found in the store; a name with no store says where to set one.

**Acceptance criteria:**
- [ ] `Load` reads the pack and hashes the realm; the hash is stable, and changes when a prompt changes, a file is added or removed, a file becomes executable, or a symlink appears or changes target; it does not follow `.git`.
- [ ] `Find` refuses a name that is not a realm name, a realm the store lacks, and a folder that holds another realm than its name says; `Resolve` takes a path or a name.

**Named test:** `go test ./internal/realm` in `odin`. **Layer:** `odin`. **Size:** M (278). **Depends on:** v0-T167 (merged).

- [ ] **Step 1:** write the tests.

Write `internal/realm/realm_test.go`:

```go
package realm

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func write(t *testing.T, root, rel, body string, mode os.FileMode) {
	t.Helper()
	p := filepath.Join(root, rel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(body), mode); err != nil {
		t.Fatal(err)
	}
}

// fixture writes a realm named name at version into dir.
func fixture(t *testing.T, dir, name, version string) {
	t.Helper()
	write(t, dir, "pack.yaml", "name: "+name+"\nversion: "+version+"\ngraph: graph.yaml\n", 0o644)
	write(t, dir, "graph.yaml", "name: "+name+"\nversion: "+version+"\nnodes:\n  - { id: a, kind: exec, run: [true], repo: . }\n", 0o644)
	write(t, dir, "prompts/implementer.md", "Build it.\n", 0o644)
}

func TestLoadReadsTheRealmAndHashesIt(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "midgard-react")
	fixture(t, dir, "midgard-react", "0.1.0")
	r, err := Load(dir)
	if err != nil {
		t.Fatalf("Load() = %v", err)
	}
	if r.Name != "midgard-react" || r.Version != "0.1.0" || r.Dir != dir || r.Pack.Graph != "graph.yaml" || len(r.Hash) != 64 {
		t.Errorf("Load() = %+v", r)
	}
	again, _ := Load(dir)
	if again.Hash != r.Hash {
		t.Error("the hash of an unchanged realm changed")
	}
}

func TestTheHashFollowsEveryFileTheRunCouldRead(t *testing.T) {
	base := t.TempDir()
	hashOf := func(mutate func(dir string)) string {
		dir := filepath.Join(base, "r"+strings.ReplaceAll(t.Name(), "/", "-"))
		os.RemoveAll(dir)
		fixture(t, dir, "midgard-react", "0.1.0")
		mutate(dir)
		h, err := Hash(dir)
		if err != nil {
			t.Fatal(err)
		}
		return h
	}
	plain := hashOf(func(string) {})
	for name, mutate := range map[string]func(string){
		"a prompt changes":        func(d string) { write(t, d, "prompts/implementer.md", "Build it twice.\n", 0o644) },
		"a file is added":         func(d string) { write(t, d, "prompts/extra.md", "x", 0o644) },
		"a file is removed":       func(d string) { os.Remove(filepath.Join(d, "prompts/implementer.md")) },
		"a file becomes a script": func(d string) { os.Chmod(filepath.Join(d, "prompts/implementer.md"), 0o755) },
		"a symlink appears":       func(d string) { os.Symlink("../pack.yaml", filepath.Join(d, "prompts/link.md")) },
	} {
		if got := hashOf(mutate); got == plain {
			t.Errorf("%s, and the hash did not change", name)
		}
	}
	if got := hashOf(func(d string) { write(t, d, ".git/HEAD", "ref: x", 0o644) }); got != plain {
		t.Error("the hash follows .git, which holds nothing a run reads")
	}
	a := hashOf(func(d string) { os.Symlink("../pack.yaml", filepath.Join(d, "prompts/link.md")) })
	b := hashOf(func(d string) { os.Symlink("../graph.yaml", filepath.Join(d, "prompts/link.md")) })
	if a == b {
		t.Error("two symlinks with different targets hash alike")
	}
}

func TestTheHashRefusesARealmTooBigToBeOne(t *testing.T) {
	dir := t.TempDir()
	fixture(t, dir, "midgard-react", "0.1.0")
	for i := 0; i < 5; i++ {
		write(t, dir, "f"+string(rune('a'+i)), "x", 0o644)
	}
	if _, err := hashLimited(dir, limits{files: 4, bytes: 1 << 20}); err == nil || !strings.Contains(err.Error(), "files") {
		t.Errorf("too many files: %v", err)
	}
	if _, err := hashLimited(dir, limits{files: 100, bytes: 20}); err == nil || !strings.Contains(err.Error(), "bytes") {
		t.Errorf("too many bytes: %v", err)
	}
}

func TestAStoreFindsARealmByName(t *testing.T) {
	store := t.TempDir()
	fixture(t, filepath.Join(store, "midgard-react"), "midgard-react", "0.1.0")
	fixture(t, filepath.Join(store, "helheim-go"), "midgard-react", "0.1.0") // a folder holding another realm than its name says
	s := &Store{Dir: store}
	if dir, err := s.Find("midgard-react"); err != nil || dir != filepath.Join(store, "midgard-react") {
		t.Errorf("Find() = %q, %v", dir, err)
	}
	for name, want := range map[string]string{"helheim-go": "holds the realm midgard-react", "asgard": "no realm asgard", "../x": "not a realm name", "Midgard": "not a realm name"} {
		if _, err := s.Find(name); err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("Find(%q) = %v, want an error containing %q", name, err, want)
		}
	}
}

func TestResolveTakesAPathOrAName(t *testing.T) {
	store := t.TempDir()
	fixture(t, filepath.Join(store, "midgard-react"), "midgard-react", "0.1.0")
	s := &Store{Dir: store}
	if dir, byName, err := Resolve(filepath.Join(store, "midgard-react"), s); err != nil || byName || dir != filepath.Join(store, "midgard-react") {
		t.Errorf("a path: %q, %v, %v", dir, byName, err)
	}
	if dir, byName, err := Resolve("midgard-react", s); err != nil || !byName || dir != filepath.Join(store, "midgard-react") {
		t.Errorf("a name: %q, %v, %v", dir, byName, err)
	}
	if _, _, err := Resolve("midgard-react", nil); err == nil || !strings.Contains(err.Error(), "realms") {
		t.Errorf("a name with no store: %v", err)
	}
	if dir, byName, err := Resolve("./testdata/x", nil); err != nil || byName || dir != "./testdata/x" {
		t.Errorf("a relative path with no store: %q, %v, %v", dir, byName, err)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/realm [github.com/ouroboric-dev/odin/internal/realm.test]
internal/realm/realm_test.go:32:12: undefined: Load
internal/realm/realm_test.go:39:14: undefined: Load
internal/realm/realm_test.go:52:13: undefined: Hash
```

- [ ] **Step 3:** write the code.

Write `internal/realm/realm.go`:

```go
// Package realm loads realm leaves (change realm-leaf-naming): the repos that hold a pack.yaml with a
// graph, prompts, templates and checks. A run loads its lead realm and each leaf's realm once, at the
// version the project pins, and records a hash of each so a resume can tell nothing changed under it.
package realm

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

// Realm is a realm leaf as a run loaded it.
type Realm struct {
	Name    string
	Version string
	Dir     string // absolute
	Hash    string // of every file a run could read; see Hash
	Pack    *schema.Pack
}

// Load reads the pack in dir and hashes the realm.
func Load(dir string) (*Realm, error) {
	abs, err := filepath.Abs(dir)
	if err != nil {
		return nil, err
	}
	p, err := schema.LoadPack(abs)
	if err != nil {
		return nil, err
	}
	h, err := Hash(abs)
	if err != nil {
		return nil, err
	}
	return &Realm{Name: p.Name, Version: p.Version, Dir: abs, Hash: h, Pack: p}, nil
}

type limits struct{ files, bytes int64 }

// A realm is a few hundred small files. One with more is not a realm but a folder that holds build
// output, and hashing it would be slow and its hash would change with every build.
var defaultLimits = limits{files: 5000, bytes: 64 << 20}

// Hash returns a SHA-256 over every file of the realm but the contents of .git: each file's path, its
// executable bit and its bytes, and each symlink's path and target, in path order. A run records it, and
// a resume refuses a realm whose hash changed (spec §4.3: the run's positions mean what they meant).
func Hash(dir string) (string, error) { return hashLimited(dir, defaultLimits) }

func hashLimited(dir string, lim limits) (string, error) {
	h := sha256.New()
	var files, size int64
	err := filepath.WalkDir(dir, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(dir, p)
		if err != nil {
			return err
		}
		if rel == "." {
			return nil
		}
		if d.IsDir() {
			if rel == ".git" {
				return filepath.SkipDir
			}
			return nil
		}
		files++
		if files > lim.files {
			return fmt.Errorf("%s holds more than %d files; a realm is a few hundred small ones, so this is not one", dir, lim.files)
		}
		rel = filepath.ToSlash(rel)
		if d.Type()&fs.ModeSymlink != 0 {
			target, err := os.Readlink(p)
			if err != nil {
				return err
			}
			fmt.Fprintf(h, "link\x00%s\x00%s\x00", rel, target)
			return nil
		}
		if !d.Type().IsRegular() {
			return fmt.Errorf("%s is neither a file nor a symlink", p)
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		size += info.Size()
		if size > lim.bytes {
			return fmt.Errorf("%s holds more than %d bytes; a realm is text and small, so this is not one", dir, lim.bytes)
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		mode := "file"
		if info.Mode()&0o111 != 0 {
			mode = "exec"
		}
		fmt.Fprintf(h, "%s\x00%s\x00%d\x00", mode, rel, len(b))
		h.Write(b)
		return nil
	})
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

// Store is a folder with one checkout of each realm leaf: <Dir>/<name>/pack.yaml (factory.yaml,
// realms.dir).
type Store struct{ Dir string }

// Find returns the folder of the realm called name. The pack in it must say it is that realm.
func (s *Store) Find(name string) (string, error) {
	if !gungnir.ValidRealm(name) {
		return "", fmt.Errorf("%q is not a realm name (lower case words joined by dashes)", name)
	}
	dir := filepath.Join(s.Dir, name)
	p, err := schema.LoadPack(dir)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return "", fmt.Errorf("there is no realm %s in %s (factory.yaml, realms.dir)", name, s.Dir)
	case err != nil:
		return "", err
	case p.Name != name:
		return "", fmt.Errorf("%s holds the realm %s, not %s", dir, p.Name, name)
	}
	return dir, nil
}

// Resolve turns what --realm says into a folder. A value with a path separator, or one that starts
// with a dot, is a path: a realm checked out anywhere, used as it is. Anything else is a realm name,
// found in the store; byName is true for it. A name with no store is an error that says where to set one.
func Resolve(ref string, store *Store) (dir string, byName bool, err error) {
	if strings.ContainsRune(ref, filepath.Separator) || strings.HasPrefix(ref, ".") {
		return ref, false, nil
	}
	if store == nil {
		return "", true, fmt.Errorf("--realm %s names a realm leaf, but factory.yaml has no realms section to find it in: set realms: {dir: <folder with the realm leaves>}, or give --realm a path", ref)
	}
	dir, err = store.Find(ref)
	return dir, true, err
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T169: a run loads each realm once, and stops before anything starts when the pins disagree

Change `realm-leaf-naming`: "each realm leaf loads once per run, at a pinned version; two pins of one realm leaf that disagree stop the run before any sandbox comes up".

**Files (in `odin`):**
- Create: `internal/realm/set.go`, `internal/realm/set_test.go`

**Interfaces:**
- Produces: `realm.Set{Lead *Realm; Realms map[string]*Realm}` with `Names()`; `realm.Collect(lead, pins []schema.Pin, load) (*Set, error)`. `load` is called once for each realm but the lead. Every problem is listed: two pins of one realm at two versions ("midgard-react is pinned at 0.1.0 by . and at 0.2.0 by repos/web"), a pin of the lead (where `.`) that names another realm than `--realm`, a realm the store cannot load, and a store whose version is not the pinned one.

**Acceptance criteria:**
- [ ] Five pins over three realms load two realms (the lead is loaded already) and give a set of three.
- [ ] Each problem above is reported, with the pin that caused it, and a set with problems is not returned.

**Named test:** `go test ./internal/realm -run 'TestEachRealmLoadsOnceAtThePinnedVersion|TestTwoPinsOfOneRealmThatDisagreeStopTheRun|TestTheRealmStoreMustHoldTheVersionThePinNames|TestThePinOfTheLeadRealmNamesTheLeadRealm'` in `odin`. **Layer:** `odin`. **Size:** M (171). **Depends on:** v0-T168.

- [ ] **Step 1:** write the tests.

Write `internal/realm/set_test.go`:

```go
package realm

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
)

// store writes realm leaves at the given versions and returns the loader of a run.
func store(t *testing.T, versions map[string]string) func(string) (*Realm, error) {
	t.Helper()
	root := t.TempDir()
	for name, v := range versions {
		fixture(t, filepath.Join(root, name), name, v)
	}
	s := &Store{Dir: root}
	return func(name string) (*Realm, error) {
		dir, err := s.Find(name)
		if err != nil {
			return nil, err
		}
		return Load(dir)
	}
}

func TestEachRealmLoadsOnceAtThePinnedVersion(t *testing.T) {
	load := store(t, map[string]string{"midgard-react": "0.1.0", "helheim-go": "0.1.0", "midgard-vue": "0.3.0"})
	lead, err := load("midgard-react")
	if err != nil {
		t.Fatal(err)
	}
	loads := 0
	counting := func(name string) (*Realm, error) { loads++; return load(name) }
	set, err := Collect(lead, []schema.Pin{
		{Realm: "midgard-react", Version: "0.1.0", Where: "."},
		{Realm: "helheim-go", Version: "0.1.0", Where: "repos/api"},
		{Realm: "midgard-react", Version: "0.1.0", Where: "repos/web"},
		{Realm: "midgard-react", Version: "0.1.0", Where: "repos/admin"},
		{Realm: "midgard-vue", Version: "0.3.0", Where: "repos/storefront"},
	}, counting)
	if err != nil {
		t.Fatalf("Collect() = %v", err)
	}
	if loads != 2 {
		t.Errorf("%d realms loaded, want 2 (the lead is already loaded, and each other realm once)", loads)
	}
	if set.Lead != lead || len(set.Realms) != 3 || set.Realms["helheim-go"].Version != "0.1.0" || set.Realms["midgard-react"] != lead {
		t.Errorf("set = %+v", set)
	}
	if got := set.Names(); strings.Join(got, ",") != "helheim-go,midgard-react,midgard-vue" {
		t.Errorf("Names() = %v", got)
	}
}

func TestTwoPinsOfOneRealmThatDisagreeStopTheRun(t *testing.T) {
	load := store(t, map[string]string{"midgard-react": "0.1.0", "helheim-go": "0.1.0"})
	lead, _ := load("midgard-react")
	_, err := Collect(lead, []schema.Pin{
		{Realm: "midgard-react", Version: "0.1.0", Where: "."},
		{Realm: "midgard-react", Version: "0.2.0", Where: "repos/web"},
		{Realm: "helheim-go", Version: "0.1.0", Where: "repos/api"},
		{Realm: "helheim-go", Version: "0.1.1", Where: "repos/db"},
	}, load)
	if err == nil {
		t.Fatal("Collect() = nil with two pins of one realm at different versions")
	}
	for _, want := range []string{"midgard-react is pinned at 0.1.0 by . and at 0.2.0 by repos/web", "helheim-go is pinned at 0.1.0 by repos/api and at 0.1.1 by repos/db"} {
		if !strings.Contains(err.Error(), want) {
			t.Errorf("the error lacks %q:\n%v", want, err)
		}
	}
}

func TestTheRealmStoreMustHoldTheVersionThePinNames(t *testing.T) {
	load := store(t, map[string]string{"midgard-react": "0.2.0", "helheim-go": "0.1.0"})
	lead, _ := load("midgard-react")
	_, err := Collect(lead, []schema.Pin{{Realm: "midgard-react", Version: "0.1.0", Where: "."}, {Realm: "helheim-go", Version: "0.2.0", Where: "repos/api"}}, load)
	if err == nil || !strings.Contains(err.Error(), "the realm store holds midgard-react 0.2.0, but . pins 0.1.0") || !strings.Contains(err.Error(), "helheim-go 0.1.0, but repos/api pins 0.2.0") {
		t.Errorf("Collect() = %v", err)
	}
	_, err = Collect(lead, []schema.Pin{{Realm: "asgard", Version: "0.1.0", Where: "repos/x"}}, load)
	if err == nil || !strings.Contains(err.Error(), "repos/x") || !strings.Contains(err.Error(), "asgard") {
		t.Errorf("a realm the store lacks: %v", err)
	}
}

func TestThePinOfTheLeadRealmNamesTheLeadRealm(t *testing.T) {
	load := store(t, map[string]string{"midgard-react": "0.1.0", "midgard-vue": "0.1.0"})
	lead, _ := load("midgard-vue")
	_, err := Collect(lead, []schema.Pin{{Realm: "midgard-react", Version: "0.1.0", Where: "."}}, load)
	if err == nil || !strings.Contains(err.Error(), "the project is built with midgard-react, not midgard-vue") {
		t.Errorf("Collect() = %v", err)
	}
	set, err := Collect(lead, nil, load)
	if err != nil {
		t.Fatalf("no pins: %v", err)
	}
	if set.Lead != lead || len(set.Realms) != 1 {
		t.Errorf("a set with no pins holds the lead alone: %+v", set)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/realm [github.com/ouroboric-dev/odin/internal/realm.test]
internal/realm/set_test.go:36:14: undefined: Collect
internal/realm/set_test.go:60:12: undefined: Collect
internal/realm/set_test.go:79:12: undefined: Collect
```

- [ ] **Step 3:** write the code.

Write `internal/realm/set.go`:

```go
package realm

import (
	"fmt"
	"maps"
	"slices"
	"strings"

	"github.com/ouroboric-dev/gungnir/schema"
)

// Set is the realm leaves of one run: the lead realm, and every realm a leaf of the project names, each
// loaded once.
type Set struct {
	Lead   *Realm
	Realms map[string]*Realm // by name; the lead is among them
}

// Names returns the realms' names, sorted.
func (s *Set) Names() []string { return slices.Sorted(maps.Keys(s.Realms)) }

// Collect builds the set for a run whose lead realm is loaded. pins are the pins of the project: the lead
// pin (where ".") and each leaf's. One version of a realm leaf serves the whole run (change
// realm-leaf-naming), so Collect refuses, before anything starts: two pins of one realm at different
// versions; a pin of the lead realm that names another realm than --realm did; and a realm store that
// holds another version of a realm than the one pinned. Every problem is listed. load finds a realm by
// name, and is called once for each realm but the lead.
func Collect(lead *Realm, pins []schema.Pin, load func(name string) (*Realm, error)) (*Set, error) {
	var problems []string
	byRealm := map[string][]schema.Pin{}
	for _, p := range pins {
		byRealm[p.Realm] = append(byRealm[p.Realm], p)
		if p.Where == "." && p.Realm != lead.Name {
			problems = append(problems, fmt.Sprintf("the project is built with %s, not %s", p.Realm, lead.Name))
		}
	}
	for _, name := range slices.Sorted(maps.Keys(byRealm)) {
		ps := byRealm[name]
		for _, p := range ps[1:] {
			if p.Version != ps[0].Version {
				problems = append(problems, fmt.Sprintf("realm %s is pinned at %s by %s and at %s by %s", name, ps[0].Version, ps[0].Where, p.Version, p.Where))
			}
		}
	}
	set := &Set{Lead: lead, Realms: map[string]*Realm{lead.Name: lead}}
	for _, name := range slices.Sorted(maps.Keys(byRealm)) {
		r := set.Realms[name]
		if r == nil {
			var err error
			if r, err = load(name); err != nil {
				for _, p := range byRealm[name] {
					problems = append(problems, fmt.Sprintf("%s pins realm %s, which can't be loaded: %v", p.Where, name, err))
				}
				continue
			}
			set.Realms[name] = r
		}
		for _, p := range byRealm[name] {
			if p.Version != r.Version {
				problems = append(problems, fmt.Sprintf("the realm store holds %s %s, but %s pins %s", name, r.Version, p.Where, p.Version))
			}
		}
	}
	if len(problems) > 0 {
		return nil, fmt.Errorf("the run's realms don't agree, so nothing started:\n  %s", strings.Join(slices.Compact(problems), "\n  "))
	}
	return set, nil
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T170: a run takes its lead realm by name, loads the realm each leaf is pinned to, and records them all

This is where `Prepare` uses the realm store. `ygg run --realm midgard-react` finds the realm in `factory.yaml`'s `realms.dir`; the project's pins say which realm each leaf has; the run records every realm with its version and hash, and a resume refuses one that changed.

**Files (in `odin`):**
- Create: `internal/run/realms_test.go`
- Modify: `internal/run/run.go`, `internal/run/state.go`, `internal/tree/treetest/treetest.go`

**Interfaces:**
- Consumes: `schema.Factory.Realms` (v0-T146), `realm.*` (v0-T168, v0-T169), `schema.Umbrella.Pins()` (v0-T142).
- Produces: `run.Options.Realms` (a resume's recorded folders) and `Leaves`; `Setup.Lead`, `Setup.Realms` and `Setup.RealmOf(repo)`, `Setup.Realm(name)` ("" is the lead); `State.Realms map[string]RealmRecord{Version, Dir, SHA256}`; `State.checkRealms`. A lead realm needs a graph. A leaf with no pin is the lead realm's. `treetest.Node` can carry a pin and consumers.
- A resume loads the realms from the folders `run.json` recorded, and refuses, after the graph's own check, a realm whose version or hash changed.

**Acceptance criteria:**
- [ ] `--realm` takes a name found in the store, or a path; a name with no store is refused with a hint; a realm with no graph cannot lead.
- [ ] Each leaf uses the realm the project pins for it; pins that disagree, a lead pin that names another realm and a store at another version stop `Prepare` and `Start` with nothing created.
- [ ] `run.json` records every realm, and a resume refuses a prompt that changed in a leaf's realm.

**Named test:** `go test ./internal/run -run 'TestARealmIsNamedAndFoundInTheStore|TestANameWithNoStoreIsRefusedWithAHint|TestARealmWithoutAGraphCannotLead|TestEachLeafUsesTheRealmTheProjectPinsForIt|TestPinsThatDisagreeStopTheRunBeforeAnythingIsWritten|TestRunJSONRecordsEveryRealmAndAResumeRefusesOneThatChanged'` in `odin`. **Layer:** `odin`. **Size:** M (277). **Depends on:** v0-T169.

- [ ] **Step 1:** write the tests.

Write `internal/run/realms_test.go`:

```go
package run

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

// realmStore copies the toy realm into a store once for each name, at the given version, and returns the
// store and a factory.yaml that names it.
func realmStore(t *testing.T, versions map[string]string) (store, cfg string) {
	t.Helper()
	store = t.TempDir()
	for name, v := range versions {
		dir := filepath.Join(store, name)
		if err := os.CopyFS(dir, os.DirFS(toy(t))); err != nil {
			t.Fatal(err)
		}
		pack, _ := os.ReadFile(filepath.Join(dir, "pack.yaml"))
		pack = []byte(strings.Replace(strings.Replace(string(pack), "name: toy", "name: "+name, 1), "version: 0.3.0", "version: "+v, 1))
		if err := os.WriteFile(filepath.Join(dir, "pack.yaml"), pack, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	return store, writeConfig(t, t.TempDir(), scriptedRoles+fullCaps+"realms:\n  dir: "+store+"\n")
}

func pinned(lead, version string, leaves map[string]treetest.Pin) treetest.Node {
	n := treetest.Node{Owner: "ouroboric-dev", Visibility: "private", Pin: treetest.Pin{Realm: lead, Version: version}, Children: map[string]treetest.Node{}}
	for path, p := range leaves {
		n.Children[path] = treetest.Node{Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Pin: p}
	}
	return n
}

func TestARealmIsNamedAndFoundInTheStore(t *testing.T) {
	_, cfg := realmStore(t, map[string]string{"midgard-react": "0.1.0"})
	project := treetest.Project(t, "repos/app")
	s, err := Prepare(ctx, Options{Project: project, Config: cfg, Realm: "midgard-react"})
	if err != nil {
		t.Fatalf("Prepare() = %v", err)
	}
	if s.Lead.Name != "midgard-react" || s.Pack != s.Lead.Pack || s.RealmDir != s.Lead.Dir || s.Graph == nil || len(s.Realms.Realms) != 1 {
		t.Errorf("lead = %+v, realms = %v", s.Lead, s.Realms.Names())
	}
	if s.RealmOf("repos/app") != s.Lead || s.Realm("") != s.Lead {
		t.Error("a leaf with no pin uses the lead realm")
	}
}

func TestANameWithNoStoreIsRefusedWithAHint(t *testing.T) {
	project := treetest.Project(t, "repos/app")
	cfg := writeConfig(t, t.TempDir(), scriptedRoles+fullCaps)
	if _, err := Prepare(ctx, Options{Project: project, Config: cfg, Realm: "midgard-react"}); err == nil || !strings.Contains(err.Error(), "realms") {
		t.Errorf("Prepare() = %v", err)
	}
}

func TestARealmWithoutAGraphCannotLead(t *testing.T) {
	store, cfg := realmStore(t, map[string]string{"helheim-go": "0.1.0"})
	pack := filepath.Join(store, "helheim-go", "pack.yaml")
	b, _ := os.ReadFile(pack)
	os.WriteFile(pack, []byte(strings.Replace(string(b), "graph: graph.yaml\n", "", 1)), 0o644)
	if _, err := Prepare(ctx, Options{Project: treetest.Project(t, "repos/app"), Config: cfg, Realm: "helheim-go"}); err == nil || !strings.Contains(err.Error(), "has no graph") {
		t.Errorf("Prepare() = %v", err)
	}
}

func TestEachLeafUsesTheRealmTheProjectPinsForIt(t *testing.T) {
	_, cfg := realmStore(t, map[string]string{"midgard-react": "0.1.0", "helheim-go": "0.2.0"})
	project := treetest.Build(t, pinned("midgard-react", "0.1.0", map[string]treetest.Pin{
		"repos/app": {Realm: "midgard-react", Version: "0.1.0"}, "repos/api": {Realm: "helheim-go", Version: "0.2.0"}, "repos/old": {}}))
	s, err := Prepare(ctx, Options{Project: project, Config: cfg, Realm: "midgard-react"})
	if err != nil {
		t.Fatalf("Prepare() = %v", err)
	}
	if got := strings.Join(s.Realms.Names(), ","); got != "helheim-go,midgard-react" {
		t.Errorf("realms = %s", got)
	}
	if s.RealmOf("repos/api").Name != "helheim-go" || s.RealmOf("repos/app") != s.Lead || s.RealmOf("repos/old") != s.Lead {
		t.Errorf("RealmOf: api %s, app %s, old %s", s.RealmOf("repos/api").Name, s.RealmOf("repos/app").Name, s.RealmOf("repos/old").Name)
	}
}

func TestPinsThatDisagreeStopTheRunBeforeAnythingIsWritten(t *testing.T) {
	_, cfg := realmStore(t, map[string]string{"midgard-react": "0.1.0", "helheim-go": "0.1.0"})
	disagree := treetest.Build(t, pinned("midgard-react", "0.1.0", map[string]treetest.Pin{
		"repos/web": {Realm: "midgard-react", Version: "0.2.0"}, "repos/api": {Realm: "helheim-go", Version: "0.1.0"}}))
	_, err := Start(ctx, Options{Project: disagree, Config: cfg, Realm: "midgard-react"})
	if err == nil || !strings.Contains(err.Error(), "midgard-react is pinned at 0.1.0 by . and at 0.2.0 by repos/web") {
		t.Errorf("Start() = %v", err)
	}
	if _, err := os.Stat(filepath.Join(disagree, ".factory")); err == nil {
		t.Error("a refused start created .factory/")
	}
	other := treetest.Build(t, pinned("midgard-react", "0.1.0", nil))
	if _, err := Prepare(ctx, Options{Project: other, Config: cfg, Realm: "helheim-go"}); err == nil || !strings.Contains(err.Error(), "built with midgard-react, not helheim-go") {
		t.Errorf("the lead realm is another than the project's: %v", err)
	}
	old := treetest.Build(t, pinned("midgard-react", "0.0.9", nil))
	if _, err := Prepare(ctx, Options{Project: old, Config: cfg, Realm: "midgard-react"}); err == nil || !strings.Contains(err.Error(), "the realm store holds midgard-react 0.1.0, but . pins 0.0.9") {
		t.Errorf("the store holds another version than the pin: %v", err)
	}
}

func TestRunJSONRecordsEveryRealmAndAResumeRefusesOneThatChanged(t *testing.T) {
	store, cfg := realmStore(t, map[string]string{"midgard-react": "0.1.0", "helheim-go": "0.2.0"})
	project := treetest.Build(t, pinned("midgard-react", "0.1.0", map[string]treetest.Pin{
		"repos/app": {Realm: "midgard-react", Version: "0.1.0"}, "repos/api": {Realm: "helheim-go", Version: "0.2.0"}}))
	r, err := Start(ctx, Options{Project: project, Config: cfg, Realm: "midgard-react"})
	if err != nil {
		t.Fatalf("Start() = %v", err)
	}
	id := r.State.ID
	got := r.State.Realms
	r.Close()
	if got["helheim-go"].Version != "0.2.0" || got["helheim-go"].Dir != filepath.Join(store, "helheim-go") || len(got["midgard-react"].SHA256) != 64 || len(got) != 2 {
		t.Errorf("Realms = %+v", got)
	}
	if s, _ := LoadState(Dir(project, id)); s.Realm != "midgard-react" || s.RealmVersion != "0.1.0" || len(s.Realms) != 2 {
		t.Errorf("run.json realms = %+v", s.Realms)
	}
	r, err = Open(ctx, project, id, "")
	if err != nil {
		t.Fatalf("Open() with the realms as they were = %v", err)
	}
	r.Close()
	prompt := filepath.Join(store, "helheim-go", "prompts")
	entries, _ := os.ReadDir(prompt)
	if err := os.WriteFile(filepath.Join(prompt, entries[0].Name()), []byte("changed under the run\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := Open(ctx, project, id, ""); err == nil || !strings.Contains(err.Error(), "the realm helheim-go changed since the run started") {
		t.Errorf("Open() after a prompt of a leaf's realm changed = %v", err)
	}
}
```

Apply to `internal/tree/treetest/treetest.go`:

```diff
diff --git a/internal/tree/treetest/treetest.go b/internal/tree/treetest/treetest.go
index 345c2c2..a1950d5 100644
--- a/internal/tree/treetest/treetest.go
+++ b/internal/tree/treetest/treetest.go
@@ -22,8 +22,13 @@ type Node struct {
 	Leaf       bool            // a leaf holds a README; an umbrella holds umbrella.yaml
 	Children   map[string]Node // path relative to this umbrella: child node
 	Plain      []string        // submodules that are not nodes, such as shared assets an umbrella vendors
+	Pin        Pin             // the realm leaf this node is built with: a leaf's own, an umbrella's lead realm
+	Consumes   []string        // a leaf: the sibling leaves it calls
 }
 
+// Pin is a realm leaf and the version a fixture node pins; the zero Pin is none.
+type Pin struct{ Realm, Version string }
+
 // Standard is a company umbrella over two projects and their leaves, the shape Asgard's company
 // trees have: one project is public with a private leaf, and assets/ and tools/ are submodules
 // that are not nodes.
@@ -78,13 +83,15 @@ func build(t *testing.T, ctx context.Context, remotes, name string, n Node, root
 	if n.Leaf {
 		write(t, filepath.Join(dir, "README.md"), "# "+name+"\n")
 	} else {
-		u := schema.Umbrella{Root: root, Owner: n.Owner, Visibility: n.Visibility, Children: map[string]schema.Child{}}
+		u := schema.Umbrella{Root: root, Owner: n.Owner, Visibility: n.Visibility, Realm: n.Pin.Realm, RealmVersion: n.Pin.Version,
+			Children: map[string]schema.Child{}}
 		for path, c := range n.Children {
 			kind := schema.ChildUmbrella
 			if c.Leaf {
 				kind = schema.ChildLeaf
 			}
-			u.Children[path] = schema.Child{Kind: kind, Owner: c.Owner, Visibility: c.Visibility}
+			u.Children[path] = schema.Child{Kind: kind, Owner: c.Owner, Visibility: c.Visibility,
+				Realm: c.Pin.Realm, RealmVersion: c.Pin.Version, Consumes: c.Consumes}
 		}
 		if err := u.Save(dir); err != nil {
 			t.Fatal(err)
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/run [github.com/ouroboric-dev/odin/internal/run.test]
internal/run/realms_test.go:46:7: s.Lead undefined (type *Setup has no field or method Lead)
internal/run/realms_test.go:46:116: s.Realms undefined (type *Setup has no field or method Realms)
internal/run/realms_test.go:47:41: s.Lead undefined (type *Setup has no field or method Lead)
```

- [ ] **Step 3:** write the code.

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index a545a5b..1149ba4 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -23,18 +23,20 @@ import (
 	"github.com/ouroboric-dev/odin/internal/leaf"
 	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/lock"
+	"github.com/ouroboric-dev/odin/internal/realm"
 	"github.com/ouroboric-dev/odin/internal/remote"
 	"github.com/ouroboric-dev/odin/internal/tree"
 )
 
 // Options say what to run.
 type Options struct {
-	Project string       // the project umbrella (L1), inside an instance tree
-	Config  string       // factory.yaml
-	Realm   string       // the directory that holds pack.yaml
-	Brief   string       // optional
-	Mode    gungnir.Mode // "" means the config's mode
-	Hooks   Hooks        // tests only
+	Project string            // the project umbrella (L1), inside an instance tree
+	Config  string            // factory.yaml
+	Realm   string            // the lead realm: a realm leaf's name, found in factory.yaml's realms.dir, or a path to the folder that holds pack.yaml
+	Realms  map[string]string // a resume: the folder of each realm the run recorded, by name; they are loaded from there
+	Brief   string            // optional
+	Mode    gungnir.Mode      // "" means the config's mode
+	Hooks   Hooks             // tests only
 }
 
 // Hooks replace parts of a run in tests: the skill libraries, the sandbox driver, the clock that
@@ -52,8 +54,10 @@ type Setup struct {
 	Config       *schema.Factory
 	ConfigPath   string // absolute
 	ConfigSHA256 string
-	Pack         *schema.Pack
-	RealmDir     string // absolute
+	Pack         *schema.Pack // the lead realm's
+	RealmDir     string       // the lead realm's folder, absolute
+	Lead         *realm.Realm // the lead realm: --realm, loaded
+	Realms       *realm.Set   // every realm of the run: the lead's and one for each realm a leaf of the project names, each loaded once
 	Graph        *schema.Graph
 	GraphSHA256  string
 	Brief        string // absolute, or ""
@@ -100,12 +104,21 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 	if o.Mode != "" {
 		s.Mode = o.Mode
 	}
-	if s.RealmDir, err = filepath.Abs(o.Realm); err != nil {
+	var store *realm.Store
+	if s.Config.Realms != nil {
+		store = &realm.Store{Dir: s.Config.Realms.Dir}
+	}
+	realmDir, _, err := realm.Resolve(o.Realm, store)
+	if err != nil {
 		return nil, err
 	}
-	if s.Pack, err = schema.LoadPack(s.RealmDir); err != nil {
+	if s.Lead, err = realm.Load(realmDir); err != nil {
 		return nil, err
 	}
+	s.Pack, s.RealmDir = s.Lead.Pack, s.Lead.Dir
+	if s.Pack.Graph == "" {
+		return nil, fmt.Errorf("the realm %s has no graph, so it can't lead a run; --realm names the realm whose graph builds the product", s.Pack.Name)
+	}
 	graphPath := filepath.Join(s.RealmDir, s.Pack.Graph)
 	graphData, err := os.ReadFile(graphPath)
 	if err != nil {
@@ -118,6 +131,9 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 	if err := s.findProject(ctx, o.Project); err != nil {
 		return nil, err
 	}
+	if s.Realms, err = s.collectRealms(store, o.Realms); err != nil {
+		return nil, err
+	}
 	for _, n := range s.Graph.Nodes {
 		if err := s.checkNode(ctx, graphPath, n); err != nil {
 			return nil, err
@@ -253,6 +269,55 @@ func (s *Setup) checkSession(graphPath, node, role, prompt string) error {
 	return nil
 }
 
+// collectRealms loads the realms of the run: the lead's, and one for each realm the project's pins name.
+// The pins must agree with each other and with what the realm store holds (change realm-leaf-naming), so
+// a mismatch stops the run before anything is created or started. recorded holds the folders a resumed
+// run loaded its realms from.
+func (s *Setup) collectRealms(store *realm.Store, recorded map[string]string) (*realm.Set, error) {
+	var pins []schema.Pin
+	if u := s.Project.Umbrella; u != nil {
+		for _, p := range u.Pins() {
+			if p.Where == "." || u.Children[p.Where].Kind == schema.ChildLeaf {
+				pins = append(pins, p)
+			}
+		}
+	}
+	return realm.Collect(s.Lead, pins, func(name string) (*realm.Realm, error) {
+		if dir, ok := recorded[name]; ok {
+			return realm.Load(dir)
+		}
+		if store == nil {
+			return nil, errors.New("factory.yaml has no realms section to find it in")
+		}
+		dir, err := store.Find(name)
+		if err != nil {
+			return nil, err
+		}
+		return realm.Load(dir)
+	})
+}
+
+// Realm returns the realm called name, or the lead realm for "".
+func (s *Setup) Realm(name string) *realm.Realm {
+	if name == "" {
+		return s.Lead
+	}
+	return s.Realms.Realms[name]
+}
+
+// RealmOf returns the realm that provides the leaf at repo: the one the project pins for it, or the lead
+// realm when the leaf has no pin.
+func (s *Setup) RealmOf(repo string) *realm.Realm {
+	if u := s.Project.Umbrella; u != nil {
+		if c, ok := u.Children[repo]; ok && c.Realm != "" {
+			if r := s.Realms.Realms[c.Realm]; r != nil {
+				return r
+			}
+		}
+	}
+	return s.Lead
+}
+
 // isLeaf reports whether repo is a leaf: one the tree records as a leaf, or one Start creates.
 func (s *Setup) isLeaf(repo string) bool {
 	if n, ok := s.Repos[repo]; ok {
@@ -501,7 +566,7 @@ func record(project, dir, id string, setup *Setup) (*Run, error) {
 	now := time.Now().UTC()
 	r := &Run{Project: project, Dir: dir, Setup: setup, Ledger: l, unlock: unlock, State: &State{
 		ID: id, Status: StatusRunning, Mode: setup.Mode,
-		Realm: setup.Pack.Name, RealmVersion: setup.Pack.Version, RealmDir: setup.RealmDir,
+		Realm: setup.Pack.Name, RealmVersion: setup.Pack.Version, RealmDir: setup.RealmDir, Realms: realmRecords(setup),
 		GraphVersion: setup.Graph.Version, GraphSHA256: setup.GraphSHA256,
 		ConfigPath: setup.ConfigPath, ConfigSHA256: setup.ConfigSHA256,
 		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles(setup), Skills: setup.Skills,
@@ -520,6 +585,17 @@ func record(project, dir, id string, setup *Setup) (*Run, error) {
 	return r, nil
 }
 
+// realmRecords is what run.json keeps of each realm of the run, so a resume loads the same folders and
+// can tell none of them changed.
+func realmRecords(setup *Setup) map[string]RealmRecord {
+	out := map[string]RealmRecord{}
+	for _, name := range setup.Realms.Names() {
+		r := setup.Realms.Realms[name]
+		out[name] = RealmRecord{Version: r.Version, Dir: r.Dir, SHA256: r.Hash}
+	}
+	return out
+}
+
 func roles(setup *Setup) map[string]RoleRecord {
 	roles := map[string]RoleRecord{}
 	for name := range setup.Agents {
@@ -626,7 +702,11 @@ func open(ctx context.Context, project, dir string, mode gungnir.Mode, h Hooks)
 	if mode == "" {
 		mode = s.Mode
 	}
-	setup, err := Prepare(ctx, Options{Project: project, Config: s.ConfigPath, Realm: s.RealmDir, Brief: s.Brief, Mode: mode, Hooks: h})
+	dirs := map[string]string{}
+	for name, r := range s.Realms {
+		dirs[name] = r.Dir
+	}
+	setup, err := Prepare(ctx, Options{Project: project, Config: s.ConfigPath, Realm: s.RealmDir, Realms: dirs, Brief: s.Brief, Mode: mode, Hooks: h})
 	if err != nil {
 		return nil, err
 	}
@@ -639,6 +719,9 @@ func open(ctx context.Context, project, dir string, mode gungnir.Mode, h Hooks)
 	if setup.Skills.Hash != s.Skills.Hash {
 		return nil, errors.New("the skills the graph names changed since the run started, so results would not compare; start a new run")
 	}
+	if err := s.checkRealms(setup); err != nil {
+		return nil, err
+	}
 	if setup.Root != s.Root || setup.ProjectPath != s.ProjectPath {
 		return nil, fmt.Errorf("the run belongs to %s in %s, not this project", s.ProjectPath, s.Root)
 	}
```

Apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index c5e6207..1014476 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -40,6 +40,13 @@ const (
 	StatusDone    Status = "done"
 )
 
+// RealmRecord is a realm leaf as the run loaded it.
+type RealmRecord struct {
+	Version string `json:"version"`
+	Dir     string `json:"dir"`
+	SHA256  string `json:"sha256"` // of every file a run could read; a resume refuses a realm whose hash changed
+}
+
 // RoleRecord is the agent and model a role used.
 type RoleRecord struct {
 	Agent string `json:"agent"`
@@ -55,6 +62,7 @@ type State struct {
 	Realm        string                 `json:"realm"`
 	RealmVersion string                 `json:"realm_version"`
 	RealmDir     string                 `json:"realm_dir"`
+	Realms       map[string]RealmRecord `json:"realms,omitempty"` // every realm of the run, the lead's too, by name
 	GraphVersion string                 `json:"graph_version"`
 	GraphSHA256  string                 `json:"graph_sha256"`
 	ConfigPath   string                 `json:"config_path"`
@@ -282,6 +290,32 @@ func Lock(dir string) (unlock func(), err error) {
 // can't make another process's resume fail.
 func Locked(dir string) bool { return lock.Held(filepath.Join(dir, "lock")) }
 
+// checkRealms refuses a resume when a realm changed under the run, or the project's pins no longer name
+// the realms the run started with: its graph positions and prompts would no longer mean what they meant.
+func (s *State) checkRealms(setup *Setup) error {
+	if len(s.Realms) == 0 {
+		return nil // a run from before realms were recorded; the graph's hash is all there is
+	}
+	for _, name := range setup.Realms.Names() {
+		got := setup.Realms.Realms[name]
+		want, ok := s.Realms[name]
+		switch {
+		case !ok:
+			return fmt.Errorf("the project now names the realm %s, which this run didn't start with; start a new run", name)
+		case got.Version != want.Version:
+			return fmt.Errorf("the realm %s is at %s, and the run started with %s; start a new run", name, got.Version, want.Version)
+		case got.Hash != want.SHA256:
+			return fmt.Errorf("the realm %s changed since the run started (%s), so the run's prompts and checks are not the ones it began with; start a new run", name, want.Dir)
+		}
+	}
+	for name := range s.Realms {
+		if setup.Realms.Realms[name] == nil {
+			return fmt.Errorf("the run started with the realm %s, which the project no longer names; start a new run", name)
+		}
+	}
+	return nil
+}
+
 // check refuses a run.json whose position, pending node or leaves don't fit setup's graph and
 // tree. Odin wrote it, but a hand-edited file must not crash the engine.
 func (s *State) check(setup *Setup) error {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T171: the first run of a project pins the lead realm it was given by name, and the ledger's first line names every realm

"The lead realm is pinned in the project like a leaf's realm." The first run pins it; later runs must agree with it.

**Files (in `odin`):**
- Modify: `internal/run/realms_test.go`, `internal/run/run.go`

**Interfaces:**
- Produces: when `--realm` is a name and the project's umbrella pins no lead realm, `Start` writes the pin to `umbrella.yaml` and commits it (`Pin the lead realm midgard-react 0.1.0`), by path, and refuses if `umbrella.yaml` has uncommitted changes. A realm given as a path pins nothing. The first ledger line (`run_started`) carries the lead realm, its version and a note listing every realm with its hash.

**Acceptance criteria:**
- [ ] A first run pins and commits the lead; a second run finds the pin and commits nothing; a run with a path pins nothing; an uncommitted `umbrella.yaml` refuses the start and leaves no run behind.

**Named test:** `go test ./internal/run -run 'TestTheFirstRunPinsTheLeadRealmItWasGivenByName|TestARealmGivenByPathIsNotPinned|TestARunWontPinOverUncommittedWork'` in `odin`. **Layer:** `odin`. **Size:** M (125). **Depends on:** v0-T170.

- [ ] **Step 1:** write the tests.

Apply to `internal/run/realms_test.go`:

```diff
diff --git a/internal/run/realms_test.go b/internal/run/realms_test.go
index 6cf7e05..033e29a 100644
--- a/internal/run/realms_test.go
+++ b/internal/run/realms_test.go
@@ -6,6 +6,8 @@ import (
 	"strings"
 	"testing"
 
+	"github.com/ouroboric-dev/gungnir/schema"
+	"github.com/ouroboric-dev/odin/internal/git"
 	"github.com/ouroboric-dev/odin/internal/tree/treetest"
 )
 
@@ -137,3 +139,77 @@ func TestRunJSONRecordsEveryRealmAndAResumeRefusesOneThatChanged(t *testing.T) {
 		t.Errorf("Open() after a prompt of a leaf's realm changed = %v", err)
 	}
 }
+
+func gitOut(t *testing.T, dir string, args ...string) string {
+	t.Helper()
+	out, err := git.Run(ctx, dir, args...)
+	if err != nil {
+		t.Fatal(err)
+	}
+	return out
+}
+
+func TestTheFirstRunPinsTheLeadRealmItWasGivenByName(t *testing.T) {
+	_, cfg := realmStore(t, map[string]string{"midgard-react": "0.1.0"})
+	project := treetest.Project(t, "repos/app")
+	r, err := Start(ctx, Options{Project: project, Config: cfg, Realm: "midgard-react"})
+	if err != nil {
+		t.Fatalf("Start() = %v", err)
+	}
+	r.Close()
+	u, err := schema.LoadUmbrella(project)
+	if err != nil || u.Realm != "midgard-react" || u.RealmVersion != "0.1.0" {
+		t.Fatalf("umbrella.yaml = %+v, %v; want the lead realm pinned", u, err)
+	}
+	if msg := gitOut(t, project, "log", "-1", "--format=%s", "--", "umbrella.yaml"); msg != "Pin the lead realm midgard-react 0.1.0" {
+		t.Errorf("the pin's commit says %q", msg)
+	}
+	if st := gitOut(t, project, "status", "--porcelain", "--", "umbrella.yaml"); st != "" {
+		t.Errorf("umbrella.yaml is left uncommitted: %q", st)
+	}
+	ledger, _ := os.ReadFile(filepath.Join(Dir(project, r.State.ID), "ledger.jsonl"))
+	first, _, _ := strings.Cut(string(ledger), "\n")
+	if !strings.Contains(first, `"event":"run_started"`) || !strings.Contains(first, `"ygg.realm.name":"midgard-react"`) || !strings.Contains(first, `"ygg.realm.version":"0.1.0"`) ||
+		!strings.Contains(first, "realms: midgard-react 0.1.0 sha256:") {
+		t.Errorf("the first ledger line lacks the realms:\n%s", first)
+	}
+	// The next run finds the pin and agrees with it.
+	r2, err := Start(ctx, Options{Project: project, Config: cfg, Realm: "midgard-react"})
+	if err != nil {
+		t.Fatalf("a second Start() = %v", err)
+	}
+	r2.Close()
+	if n := gitOut(t, project, "rev-list", "--count", "HEAD", "--", "umbrella.yaml"); n != "2" {
+		t.Errorf("umbrella.yaml has %s commits; the second run pinned nothing", n)
+	}
+}
+
+func TestARealmGivenByPathIsNotPinned(t *testing.T) {
+	project := treetest.Project(t, "repos/app")
+	before := gitOut(t, project, "rev-parse", "HEAD")
+	r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
+	if err != nil {
+		t.Fatal(err)
+	}
+	r.Close()
+	if gitOut(t, project, "rev-parse", "HEAD") != before {
+		t.Error("a run with a realm given by path committed to the project: it pins nothing")
+	}
+}
+
+func TestARunWontPinOverUncommittedWork(t *testing.T) {
+	_, cfg := realmStore(t, map[string]string{"midgard-react": "0.1.0"})
+	project := treetest.Project(t, "repos/app")
+	f := filepath.Join(project, "umbrella.yaml")
+	b, _ := os.ReadFile(f)
+	os.WriteFile(f, append(b, []byte("# the operator's note\n")...), 0o644)
+	if _, err := Start(ctx, Options{Project: project, Config: cfg, Realm: "midgard-react"}); err == nil || !strings.Contains(err.Error(), "umbrella.yaml") {
+		t.Errorf("Start() = %v; the operator's own edit of umbrella.yaml is not Odin's to commit", err)
+	}
+	if _, err := os.Stat(filepath.Join(project, ".factory", "runs")); err == nil {
+		entries, _ := os.ReadDir(filepath.Join(project, ".factory", "runs"))
+		if len(entries) != 0 {
+			t.Errorf("a refused start left run directories: %v", entries)
+		}
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTheFirstRunPinsTheLeadRealmItWasGivenByName (0.21s)
    realms_test.go:162: umbrella.yaml = &{Root:true Owner:ouroboric-dev Visibility:private Realm: RealmVersion: Children:map[repos/app:{Kind:leaf Owner:ouroboric-dev Visibility:private Realm: RealmVersion: Consumes:[]}]}, <nil>; want the lead realm pinned
--- FAIL: TestARunWontPinOverUncommittedWork (0.21s)
    realms_test.go:207: Start() = <nil>; the operator's own edit of umbrella.yaml is not Odin's to commit
```

- [ ] **Step 3:** write the code.

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 1149ba4..363d2af 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -20,6 +20,7 @@ import (
 	"github.com/ouroboric-dev/jormungandr"
 	"github.com/ouroboric-dev/odin/internal/agents"
 	"github.com/ouroboric-dev/odin/internal/budget"
+	"github.com/ouroboric-dev/odin/internal/git"
 	"github.com/ouroboric-dev/odin/internal/leaf"
 	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/lock"
@@ -72,6 +73,7 @@ type Setup struct {
 	Journal      *budget.Journal // where every session's usage is recorded, and the per-day cap is summed
 	Backoff      jormungandr.Backoff
 	Sleep        func(ctx context.Context, d time.Duration) error // nil: wait for real
+	PinLead      bool                                             // the lead realm was named, and the project doesn't pin one yet: Start pins it
 
 	Root        string               // the tree's root: the project, or an umbrella above it
 	ProjectPath string               // the project's path from the root
@@ -108,7 +110,7 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 	if s.Config.Realms != nil {
 		store = &realm.Store{Dir: s.Config.Realms.Dir}
 	}
-	realmDir, _, err := realm.Resolve(o.Realm, store)
+	realmDir, byName, err := realm.Resolve(o.Realm, store)
 	if err != nil {
 		return nil, err
 	}
@@ -134,6 +136,9 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 	if s.Realms, err = s.collectRealms(store, o.Realms); err != nil {
 		return nil, err
 	}
+	// A realm named in the store is pinned by the project's first run; one given as a path is a checkout
+	// being worked on, and pins nothing.
+	s.PinLead = byName && s.Project.Umbrella != nil && s.Project.Umbrella.Realm == ""
 	for _, n := range s.Graph.Nodes {
 		if err := s.checkNode(ctx, graphPath, n); err != nil {
 			return nil, err
@@ -537,6 +542,11 @@ func Start(ctx context.Context, o Options) (*Run, error) {
 		os.RemoveAll(dir) // the run's own new directory: nothing ran
 		return nil, err
 	}
+	if err := r.pinLead(ctx); err != nil {
+		r.Close()
+		os.RemoveAll(dir)
+		return nil, err
+	}
 	if err := r.openSandbox(setup.newSandbox); err != nil {
 		r.Close()
 		os.RemoveAll(dir)
@@ -552,6 +562,41 @@ func Start(ctx context.Context, o Options) (*Run, error) {
 	return r, r.Save()
 }
 
+// pinLead records the lead realm and its version in the project's umbrella.yaml, in a commit of its own,
+// when the project pins none: from then on every run of the project must agree with it. The operator's
+// own uncommitted edit of umbrella.yaml is not Odin's to commit.
+func (r *Run) pinLead(ctx context.Context) error {
+	s := r.Setup
+	if !s.PinLead {
+		return nil
+	}
+	p := s.Project
+	if st, err := git.Run(ctx, p.Dir, "status", "--porcelain", "--", schema.UmbrellaFile); err != nil || st != "" {
+		return fmt.Errorf("%s has changes that are not committed, so the run can't pin the realm %s %s in it: commit or discard them first (%v)",
+			filepath.Join(p.Dir, schema.UmbrellaFile), s.Lead.Name, s.Lead.Version, err)
+	}
+	p.Umbrella.Realm, p.Umbrella.RealmVersion = s.Lead.Name, s.Lead.Version
+	if err := p.Umbrella.Save(p.Dir); err != nil {
+		return err
+	}
+	if _, err := git.Run(ctx, p.Dir, "add", "--", schema.UmbrellaFile); err != nil {
+		return err
+	}
+	_, err := git.Run(ctx, p.Dir, "commit", "-q", "-m", fmt.Sprintf("Pin the lead realm %s %s", s.Lead.Name, s.Lead.Version), "--", schema.UmbrellaFile)
+	return err
+}
+
+// realmNote lists the realms of the run for the ledger's first line: each with its version and the hash
+// a resume compares.
+func realmNote(set *realm.Set) string {
+	var parts []string
+	for _, name := range set.Names() {
+		r := set.Realms[name]
+		parts = append(parts, fmt.Sprintf("%s %s sha256:%s", r.Name, r.Version, r.Hash))
+	}
+	return "realms: " + strings.Join(parts, "; ")
+}
+
 // record locks the new run and writes its run.json and first ledger line.
 func record(project, dir, id string, setup *Setup) (*Run, error) {
 	unlock, err := takeLocks(project, dir)
@@ -574,7 +619,9 @@ func record(project, dir, id string, setup *Setup) (*Run, error) {
 		Attempts: map[string]int{}, Reasons: map[string]string{}, Summaries: map[string]string{},
 		Waived: map[string]bool{}, Warned: map[string]bool{}, Loops: map[string]*LoopRecord{}, Created: now, Updated: now,
 	}}
-	if err := r.Log(gungnir.Event{Name: gungnir.EventRunStarted, Mode: setup.Mode, ConfigHash: setup.ConfigSHA256}); err != nil {
+	started := gungnir.Event{Name: gungnir.EventRunStarted, Mode: setup.Mode, ConfigHash: setup.ConfigSHA256,
+		Realm: setup.Lead.Name, RealmVersion: setup.Lead.Version, Note: realmNote(setup.Realms)}
+	if err := r.Log(started); err != nil {
 		r.Close()
 		return nil, err
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T172: a task shape is expanded for each task, in the leaf and the realm the task names

Spec §4.2: "for each ready task". A pure function turns the foreach node and the tasks in build order into the nodes of the run.

**Files (in `odin`):**
- Create: `internal/plan/expand.go`, `internal/plan/expand_test.go`

**Interfaces:**
- Produces: `plan.Recipe{Realm, Implementer string; Checks []string}`; `plan.Expand(fe, tasks, g, recipeOf) ([]schema.Node, error)`. Task `gallery-T1` is the node-id slug `gallery-t1`; its nodes are `gallery-t1-implement` and so on, each with `Task` set and `Repo` the task's layer. A `realm: leaf` loop takes its prompt and its checks from the recipe of the task's leaf; a merge and a pointer take its checks; `Realm` names that realm. A body gate's `reruns` and a node's `back_to` point at the task's own node. A reviewer's session key is `<node>-<reviewer>`. Nothing in the graph changes, and no slice is shared between expansions.
- Expand refuses a node id, or a reviewer's session key, that the graph or another task already uses; a layer `recipeOf` does not know; and a realm that offers no recipe.

**Acceptance criteria:**
- [ ] Two tasks over two leaves of two realms give ten nodes in order, with the prompts, checks and realms of their leaves; the input is unchanged.
- [ ] Each refusal above is a test case; no tasks give no nodes.

**Named test:** `go test ./internal/plan` in `odin`. **Layer:** `odin`. **Size:** M (219). **Depends on:** v0-T168.

- [ ] **Step 1:** write the tests.

Write `internal/plan/expand_test.go`:

```go
package plan

import (
	"fmt"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
)

const shape = `
name: g
version: 1.0.0
nodes:
  - { id: before, kind: exec, run: [echo, before], repo: . }
  - id: tasks
    kind: foreach
    over: tasks
    nodes:
      - id: implement
        kind: loop
        realm: leaf
        role: implementer
        reviewers:
          - { id: spec, role: reviewer, prompt: prompts/review-spec.md }
      - { id: feature-gate, kind: gate, gate: feature }
      - { id: land, kind: merge, realm: leaf, back_to: implement }
      - { id: merge-gate, kind: gate, gate: merge }
      - { id: move, kind: pointer, realm: leaf, acceptance: [e2e], back_to: implement }
  - { id: after, kind: exec, run: [echo, after], repo: . }
`

func graph(t *testing.T) *schema.Graph {
	t.Helper()
	g, err := schema.ParseGraph("graph.yaml", []byte(shape))
	if err != nil {
		t.Fatal(err)
	}
	return g
}

func recipes(layer string) (Recipe, error) {
	switch layer {
	case "repos/api":
		return Recipe{Realm: "helheim-go", Implementer: "prompts/implementer-api.md", Checks: []string{"vet", "unit"}}, nil
	case "repos/web":
		return Recipe{Realm: "midgard-react", Implementer: "prompts/implementer-web.md", Checks: []string{"lint", "unit", "e2e"}}, nil
	}
	return Recipe{}, fmt.Errorf("the project has no leaf %s", layer)
}

var tasks = []schema.Feature{{ID: "gallery-T001", Layer: "repos/api"}, {ID: "gallery-T002", Layer: "repos/web", DependsOn: []string{"gallery-T001"}}}

func TestEveryTaskGetsTheBodyInItsLeafAndTheRealmOfThatLeaf(t *testing.T) {
	g := graph(t)
	nodes, err := Expand(g.Nodes[1], tasks, g, recipes)
	if err != nil {
		t.Fatalf("Expand() = %v", err)
	}
	var ids []string
	for _, n := range nodes {
		ids = append(ids, n.ID)
	}
	want := "gallery-t001-implement gallery-t001-feature-gate gallery-t001-land gallery-t001-merge-gate gallery-t001-move " +
		"gallery-t002-implement gallery-t002-feature-gate gallery-t002-land gallery-t002-merge-gate gallery-t002-move"
	if strings.Join(ids, " ") != want {
		t.Fatalf("ids =\n%s\nwant\n%s", strings.Join(ids, " "), want)
	}
	api, web := nodes[0], nodes[5]
	if api.Task != "gallery-t001" || api.Repo != "repos/api" || api.Realm != "helheim-go" || api.Prompt != "prompts/implementer-api.md" ||
		!slices.Equal(api.Checks, []string{"vet", "unit"}) || api.Role != "implementer" || api.Attempts != schema.DefaultAttempts {
		t.Errorf("the api's loop = %+v", api)
	}
	if web.Realm != "midgard-react" || web.Prompt != "prompts/implementer-web.md" || !slices.Equal(web.Checks, []string{"lint", "unit", "e2e"}) || web.Repo != "repos/web" {
		t.Errorf("the web's loop = %+v", web)
	}
	if rv := api.Reviewers[0]; rv.ID != "spec" || rv.Prompt != "prompts/review-spec.md" || api.SessionKey(rv) != "gallery-t001-implement-spec" {
		t.Errorf("the reviewer = %+v, key %s", rv, api.SessionKey(rv))
	}
	gate, land, move := nodes[1], nodes[2], nodes[4]
	if gate.Reruns != "gallery-t001-implement" || gate.Task != "gallery-t001" || gate.Kind != schema.KindGate {
		t.Errorf("the feature gate = %+v", gate)
	}
	if land.BackTo != "gallery-t001-implement" || land.Returns != schema.DefaultReturns || land.Repo != "repos/api" ||
		!slices.Equal(land.Checks, []string{"vet", "unit"}) || land.Realm != "helheim-go" {
		t.Errorf("the merge = %+v", land)
	}
	if move.BackTo != "gallery-t001-implement" || !slices.Equal(move.Acceptance, []string{"e2e"}) || !slices.Equal(move.Checks, []string{"vet", "unit"}) {
		t.Errorf("the pointer move = %+v", move)
	}
	if nodes[8].Reruns != "gallery-t002-implement" {
		t.Errorf("the second task's merge gate reruns %q", nodes[8].Reruns)
	}
}

func TestExpandingChangesNothingInTheGraph(t *testing.T) {
	g := graph(t)
	before := fmt.Sprintf("%+v", g.Nodes[1])
	if _, err := Expand(g.Nodes[1], tasks, g, recipes); err != nil {
		t.Fatal(err)
	}
	if after := fmt.Sprintf("%+v", g.Nodes[1]); after != before {
		t.Errorf("Expand changed the foreach node:\n%s\n%s", before, after)
	}
	a, _ := Expand(g.Nodes[1], tasks[:1], g, recipes)
	a[0].Checks[0] = "changed"
	b, _ := Expand(g.Nodes[1], tasks[:1], g, recipes)
	if b[0].Checks[0] != "vet" {
		t.Error("two expansions share one checks slice")
	}
}

func TestExpandRefusesWhatItCannotPlace(t *testing.T) {
	g := graph(t)
	if _, err := Expand(g.Nodes[1], []schema.Feature{{ID: "x-T1", Layer: "repos/db"}}, g, recipes); err == nil || !strings.Contains(err.Error(), "x-T1") || !strings.Contains(err.Error(), "repos/db") {
		t.Errorf("a task in a leaf nobody knows: %v", err)
	}
	none := func(string) (Recipe, error) { return Recipe{Realm: "notes"}, nil }
	if _, err := Expand(g.Nodes[1], tasks, g, none); err == nil || !strings.Contains(err.Error(), "offers no leaf recipe") {
		t.Errorf("a realm with no recipe: %v", err)
	}
	// A node id the graph already uses.
	clash := graph(t)
	clash.Nodes = append(clash.Nodes, schema.Node{ID: "gallery-t001-land", Kind: schema.KindExec})
	if _, err := Expand(clash.Nodes[1], tasks, clash, recipes); err == nil || !strings.Contains(err.Error(), "gallery-t001-land") {
		t.Errorf("an id the graph uses: %v", err)
	}
	keyClash := graph(t)
	keyClash.Nodes = append(keyClash.Nodes, schema.Node{ID: "gallery-t001-implement-spec", Kind: schema.KindExec})
	if _, err := Expand(keyClash.Nodes[1], tasks, keyClash, recipes); err == nil || !strings.Contains(err.Error(), "gallery-t001-implement-spec") {
		t.Errorf("a reviewer's session key the graph uses as a node id: %v", err)
	}
	if got, err := Expand(g.Nodes[1], nil, g, recipes); err != nil || len(got) != 0 {
		t.Errorf("no tasks = %v, %v", got, err)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/plan [github.com/ouroboric-dev/odin/internal/plan.test]
internal/plan/expand_test.go:43:29: undefined: Recipe
internal/plan/expand_test.go:46:10: undefined: Recipe
internal/plan/expand_test.go:48:10: undefined: Recipe
```

- [ ] **Step 3:** write the code.

Write `internal/plan/expand.go`:

```go
// Package plan turns a lead realm's task shape into the nodes of a run (spec §4.2: "for each ready
// task"). A foreach node in the graph is written once; Expand makes its nodes for each task, in the leaf
// the task names, with the prompt and checks of the realm that provides that leaf.
package plan

import (
	"fmt"
	"slices"

	"github.com/ouroboric-dev/gungnir/schema"
)

// Recipe is what a leaf's realm offers its tasks (the pack's leaf recipe): the realm's name, the
// implementer's prompt and the checks, in the realm's own terms.
type Recipe struct {
	Realm       string
	Implementer string
	Checks      []string
}

// Expand returns the nodes of foreach node fe for tasks, which are in the order they are built: fe's body
// once for each task. A task's nodes work in its layer, which is a leaf of the project; their ids are the
// task's id as a node id, a dash and the body node's id; they name the task; a gate re-runs, and a merge
// or pointer node goes back to, the task's own node. A loop, merge or pointer node of the realm "leaf"
// takes its prompt and checks from recipeOf(layer). Expand changes nothing in the graph, and refuses an
// id or a reviewer session key that the graph already uses, or that two tasks would share.
func Expand(fe schema.Node, tasks []schema.Feature, g *schema.Graph, recipeOf func(layer string) (Recipe, error)) ([]schema.Node, error) {
	taken := map[string]bool{}
	for _, n := range g.Nodes {
		taken[n.ID] = true
		if n.Kind == schema.KindLoop {
			for _, rv := range n.Reviewers {
				taken[n.SessionKey(rv)] = true
			}
		}
	}
	var out []schema.Node
	for _, f := range tasks {
		rec, err := recipeOf(f.Layer)
		if err != nil {
			return nil, fmt.Errorf("task %s works in %s: %w", f.ID, f.Layer, err)
		}
		slug := f.Slug()
		name := func(id string) string { return slug + "-" + id }
		for _, b := range fe.Body {
			n := b
			n.ID, n.Task, n.Repo = name(b.ID), slug, f.Layer
			if b.Reruns != "" {
				n.Reruns = name(b.Reruns)
			}
			if b.BackTo != "" {
				n.BackTo = name(b.BackTo)
			}
			n.Skills, n.Acceptance, n.Generated = slices.Clone(b.Skills), slices.Clone(b.Acceptance), slices.Clone(b.Generated)
			n.Reviewers = slices.Clone(b.Reviewers)
			if b.RealmFrom == schema.RealmLeaf {
				if rec.Implementer == "" || len(rec.Checks) == 0 {
					return nil, fmt.Errorf("task %s: the realm %s offers no leaf recipe, so it can't provide %s", f.ID, rec.Realm, f.Layer)
				}
				n.Realm = rec.Realm
				n.Checks = slices.Clone(rec.Checks)
				if b.Kind == schema.KindLoop {
					n.Prompt = rec.Implementer
				}
			}
			keys := []string{n.ID}
			if n.Kind == schema.KindLoop {
				for _, rv := range n.Reviewers {
					keys = append(keys, n.SessionKey(rv))
				}
			}
			for _, k := range keys {
				if taken[k] {
					return nil, fmt.Errorf("task %s: the node id %q is already used in the graph, or by another task", f.ID, k)
				}
				taken[k] = true
			}
			out = append(out, n)
		}
	}
	return out, nil
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T173: a node reads its prompt and runs its checks from its own realm

An expanded node carries `Realm`. The engine used to read every prompt from the one realm of the run and every check from its pack.

**Files (in `odin`):**
- Create: `internal/engine/realms_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/loop.go`

**Interfaces:**
- Produces: `runAgent` and a loop's implementer read their prompt file from `Setup.Realm(n.Realm).Dir`; `runChecks` and a loop's `Check` run `Setup.Realm(n.Realm).Pack.Checks`. A loop's reviewers keep the lead realm's prompts. A node with no realm is the lead's, as before.

**Acceptance criteria:**
- [ ] A node with `Realm: helheim-go` reads that realm's prompt and runs that realm's check; one with none, the lead's.

**Named test:** `go test ./internal/engine -run 'TestANodeReadsItsPromptAndRunsItsChecksFromItsOwnRealm'` in `odin`. **Layer:** `odin`. **Size:** M (161). **Depends on:** v0-T170.

- [ ] **Step 1:** write the tests.

Write `internal/engine/realms_test.go`:

```go
package engine

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

// A realm for a test: its name and version, the lines of its pack.yaml after those, and its files.
type realmFiles struct {
	name, version, pack string
	files               map[string]string
}

// realmsSetup says how startRealms makes a run with several realms. The first realm leads, with the
// nodes; leaves maps each leaf of the project to the realm it is pinned to ("" pins none).
type realmsSetup struct {
	mode, nodes, script, roles, budget string
	realms                             []realmFiles
	leaves                             map[string]string
	hooks                              run.Hooks
}

const defaultRoles = "roles:\n  planner: { agent: scripted, model: none, script: script.yaml }\n  implementer: { agent: scripted, model: none, script: script.yaml }\n  reviewer: { agent: scripted, model: none, script: script.yaml }\n"

// startRealms writes a realm store, a project pinned to those realms and a factory.yaml, and starts a run.
func startRealms(t *testing.T, o realmsSetup) *run.Run {
	t.Helper()
	store, cfg := t.TempDir(), t.TempDir()
	lead := o.realms[0]
	for i, r := range o.realms {
		dir := filepath.Join(store, r.name)
		files := map[string]string{"pack.yaml": "name: " + r.name + "\nversion: " + r.version + "\n" + r.pack}
		if i == 0 {
			files["pack.yaml"] += "graph: graph.yaml\n"
			files["graph.yaml"] = "name: " + r.name + "\nversion: 1.0.0\nnodes:\n" + o.nodes
		}
		for f, body := range r.files {
			files[f] = body
		}
		for f, body := range files {
			if err := os.MkdirAll(filepath.Dir(filepath.Join(dir, f)), 0o755); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(dir, f), []byte(body), 0o644); err != nil {
				t.Fatal(err)
			}
		}
	}
	version := map[string]string{}
	for _, r := range o.realms {
		version[r.name] = r.version
	}
	root := treetest.Node{Owner: "ouroboric-dev", Visibility: "private", Pin: treetest.Pin{Realm: lead.name, Version: lead.version}, Children: map[string]treetest.Node{}}
	for path, name := range o.leaves {
		var pin treetest.Pin
		if name != "" {
			pin = treetest.Pin{Realm: name, Version: version[name]}
		}
		root.Children[path] = treetest.Node{Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Pin: pin}
	}
	project := treetest.Build(t, root)
	if o.mode == "" {
		o.mode = "key-points"
	}
	if o.roles == "" {
		o.roles = defaultRoles
	}
	if o.budget == "" {
		o.budget = "budget:\n  per_run: { tokens: 1000000, turns: 1000 }\n  per_day: { tokens: 2000000, turns: 2000 }\n"
	}
	o.budget = strings.TrimRight(o.budget, "\n") + "\n  journal: " + filepath.Join(cfg, "spend") + "\n"
	for f, body := range map[string]string{
		"script.yaml":  o.script,
		"factory.yaml": "mode: " + o.mode + "\n" + o.roles + o.budget + "realms:\n  dir: " + store + "\n",
	} {
		if err := os.WriteFile(filepath.Join(cfg, f), []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	r, err := run.Start(context.Background(), run.Options{Project: project, Config: filepath.Join(cfg, "factory.yaml"), Realm: lead.name, Hooks: o.hooks})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { r.Close() })
	return r
}

// transcriptPrompt returns the prompt a scripted session of node got in attempt 1.
func transcriptPrompt(t *testing.T, r *run.Run, node string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(r.Dir, "transcripts", node+"-1.json"))
	if err != nil {
		t.Fatal(err)
	}
	var tr struct{ Prompt string }
	if err := json.Unmarshal(b, &tr); err != nil {
		t.Fatal(err)
	}
	return tr.Prompt
}

const leadAndOther = "checks:\n  unit: [sh, -c, \"echo lead > ran-by.txt\"]\n"

func twoRealms() []realmFiles {
	return []realmFiles{
		{name: "midgard-react", version: "0.1.0", pack: leadAndOther, files: map[string]string{"p.md": "Lead prompt.\n"}},
		{name: "helheim-go", version: "0.2.0", pack: "checks:\n  unit: [sh, -c, \"echo other > ran-by.txt\"]\n", files: map[string]string{"prompts/implementer.md": "Other realm's implementer prompt.\n"}},
	}
}

func TestANodeReadsItsPromptAndRunsItsChecksFromItsOwnRealm(t *testing.T) {
	r := startRealms(t, realmsSetup{realms: twoRealms(), leaves: map[string]string{"repos/api": "helheim-go", "repos/web": "midgard-react"},
		nodes:  "  - { id: web-build, kind: agent, role: implementer, prompt: p.md, repo: repos/web }\n  - { id: api-touch, kind: exec, run: [echo, api], repo: repos/api }\n",
		script: "steps:\n  api-build:\n    - result: { status: ok, summary: built }\n  web-build:\n    - result: { status: ok, summary: built }\n"})
	ctx := context.Background()
	api := schema.Node{ID: "api-build", Kind: schema.KindAgent, Role: "implementer", Prompt: "prompts/implementer.md", Repo: "repos/api", Realm: "helheim-go", Checks: []string{"unit"}}
	if err := runAgent(ctx, r, api); err != nil {
		t.Fatalf("runAgent() = %v", err)
	}
	if got := transcriptPrompt(t, r, "api-build"); !strings.Contains(got, "Other realm's implementer prompt.") {
		t.Errorf("the api's implementer got %q; its prompt is in the realm of its leaf", got)
	}
	web := schema.Node{ID: "web-build", Kind: schema.KindAgent, Role: "implementer", Prompt: "p.md", Repo: "repos/web"}
	if err := runAgent(ctx, r, web); err != nil {
		t.Fatalf("runAgent() = %v", err)
	}
	if got := transcriptPrompt(t, r, "web-build"); !strings.Contains(got, "Lead prompt.") {
		t.Errorf("a node with no realm got %q; it is the lead realm's", got)
	}
	if err := runChecks(ctx, r, api, 1, api.Checks, "repos/api", r.RepoDir("repos/api")); err != nil {
		t.Fatalf("runChecks() = %v", err)
	}
	if b, _ := os.ReadFile(filepath.Join(r.RepoDir("repos/api"), "ran-by.txt")); strings.TrimSpace(string(b)) != "other" {
		t.Errorf("the api's check was run by %q; the check of helheim-go is the one to run", b)
	}
	web.Checks = []string{"unit"}
	if err := runChecks(ctx, r, web, 1, web.Checks, "repos/web", r.RepoDir("repos/web")); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(r.RepoDir("repos/web"), "ran-by.txt")); strings.TrimSpace(string(b)) != "lead" {
		t.Errorf("the web's check was run by %q", b)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestANodeReadsItsPromptAndRunsItsChecksFromItsOwnRealm (0.34s)
    realms_test.go:126: runAgent() = open /tmp/TestANodeReadsItsPromptAndRunsItsChecksFromItsOwnRealm1169228780/001/midgard-react/prompts/implementer.md: no such file or directory
FAIL
FAIL	github.com/ouroboric-dev/odin/internal/engine	37.645s
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 8cb2b06..080025d 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -130,7 +130,7 @@ func startAttempt(r *run.Run, n schema.Node) (int, error) {
 
 func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 	s := r.State
-	prompt, err := os.ReadFile(filepath.Join(r.Setup.RealmDir, n.Prompt))
+	prompt, err := os.ReadFile(filepath.Join(r.Setup.Realm(n.Realm).Dir, n.Prompt))
 	if err != nil {
 		return err
 	}
@@ -266,7 +266,7 @@ func runCheck(ctx context.Context, r *run.Run, node, repo, dir string, spec chec
 func runChecks(ctx context.Context, r *run.Run, n schema.Node, attempt int, names []string, repo, dir string) error {
 	for _, c := range names {
 		logPath := filepath.Join(r.Dir, "logs", fmt.Sprintf("%s-%d-%s.log", n.ID, attempt, c))
-		cmdErr, err := command(ctx, r, n.ID, repo, dir, r.Setup.Pack.Checks[c], time.Duration(n.Timeout), logPath)
+		cmdErr, err := command(ctx, r, n.ID, repo, dir, r.Setup.Realm(n.Realm).Pack.Checks[c], time.Duration(n.Timeout), logPath)
 		if err != nil {
 			return err
 		}
```

Apply to `internal/engine/loop.go`:

```diff
diff --git a/internal/engine/loop.go b/internal/engine/loop.go
index 0549b8f..45f7c09 100644
--- a/internal/engine/loop.go
+++ b/internal/engine/loop.go
@@ -80,9 +80,11 @@ type loopSteps struct {
 
 var _ jormungandr.Steps = (*loopSteps)(nil)
 
-// prompt is the text of a session: the prompt file of the realm, the skills it names, and the brief.
-func (l *loopSteps) prompt(file string, skillNames []string) (string, error) {
-	b, err := os.ReadFile(filepath.Join(l.r.Setup.RealmDir, file))
+// prompt is the text of a session: the prompt file of the realm named realm ("" is the lead realm), the
+// skills it names, and the brief. The implementer's prompt comes from the realm of the task's leaf; a
+// reviewer's from the lead realm.
+func (l *loopSteps) prompt(realm, file string, skillNames []string) (string, error) {
+	b, err := os.ReadFile(filepath.Join(l.r.Setup.Realm(realm).Dir, file))
 	if err != nil {
 		return "", err
 	}
@@ -105,7 +107,7 @@ func (l *loopSteps) prompt(file string, skillNames []string) (string, error) {
 // discarded, so the next attempt does not build on half a thought.
 func (l *loopSteps) Implement(ctx context.Context, attempt int, in jormungandr.Input) error {
 	r, n := l.r, l.n
-	text, err := l.prompt(n.Prompt, n.Skills)
+	text, err := l.prompt(n.Realm, n.Prompt, n.Skills)
 	if err != nil {
 		return err
 	}
@@ -138,7 +140,7 @@ func (l *loopSteps) Implement(ctx context.Context, attempt int, in jormungandr.I
 func (l *loopSteps) Check(ctx context.Context, attempt int, name string) (jormungandr.CheckOutcome, error) {
 	r, n := l.r, l.n
 	rel := filepath.Join("logs", fmt.Sprintf("%s-%d-%s.log", n.ID, attempt, name))
-	res, err := runCheck(ctx, r, n.ID, n.Repo, r.RepoDir(n.Repo), checks.Spec{Name: name, Argv: r.Setup.Pack.Checks[name], Timeout: ExecTimeout},
+	res, err := runCheck(ctx, r, n.ID, n.Repo, r.RepoDir(n.Repo), checks.Spec{Name: name, Argv: r.Setup.Realm(n.Realm).Pack.Checks[name], Timeout: ExecTimeout},
 		filepath.Join(r.Dir, rel))
 	if err == nil {
 		var lf *leaf.Leaf
@@ -182,7 +184,7 @@ func (l *loopSteps) Review(ctx context.Context, attempt int, reviewer string, op
 			rv = c
 		}
 	}
-	text, err := l.prompt(rv.Prompt, rv.Skills)
+	text, err := l.prompt("", rv.Prompt, rv.Skills)
 	if err != nil {
 		return "", err
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T174: each leaf's sandbox starts on its realm's stack and gets the services of its realm and of the leaves it consumes

Change `realm-leaf-naming`: "a sandbox gets its realm's services plus those of each leaf it consumes (`web` gets `helheim-go`'s Postgres and SeaweedFS)"; spec §9.2.

**Files (in `odin`):**
- Create: `internal/run/sandbox_realms_test.go`
- Modify: `internal/run/prepare.go`, `internal/run/sandbox.go`

**Interfaces:**
- Produces: `SandboxSetup.Hosts` (the model APIs of the roles any node uses, bodies included); `(*Setup).SandboxFor(repo) (stack, egress, services, err)`: the stack and registries of the leaf's realm, the model APIs, and the services of its realm and of each leaf it consumes, sorted. Two realms offering different services of one name, and a realm with no stack when a sandbox is on, stop `Prepare` for every leaf the run has. `Run.Runner` starts the sandbox with them.

**Acceptance criteria:**
- [ ] The web leaf and the API leaf start on the stacks and with the registries of their own realms.
- [ ] The web leaf, which consumes the API, gets the API's realm's services; the API gets its own.
- [ ] A service named twice with different images, env or ports, and a realm that names no stack, are refused before any sandbox starts.

**Named test:** `go test ./internal/run -run 'TestEachLeafsSandboxGetsItsRealmsStackAndEgress|TestASandboxGetsTheServicesOfEachLeafItConsumes|TestTwoRealmsOfferingDifferentServicesOfOneNameStopTheRunBeforeASandboxStarts|TestARealmThatNamesNoStackCannotProvideALeafWhenASandboxIsOn'` in `odin`. **Layer:** `odin`. **Size:** M (226). **Depends on:** v0-T170.

- [ ] **Step 1:** write the tests.

Write `internal/run/sandbox_realms_test.go`:

```go
package run

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/sandboxfake"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

const (
	nodeStack = "docker.io/library/node:24.1.0-bookworm@sha256:3333333333333333333333333333333333333333333333333333333333333333"
	pgImage   = "docker.io/library/postgres:17.2@sha256:1111111111111111111111111111111111111111111111111111111111111111"
	s3Image   = "docker.io/chrislusf/seaweedfs:3.80@sha256:2222222222222222222222222222222222222222222222222222222222222222"
)

// sandboxRealm copies the sandboxed toy realm into store as name, with the given lines after the sandbox
// stack, and a graph that also touches repos/api so both leaves are in the run.
func sandboxRealm(t *testing.T, store, name, version, stack, egress, services string) {
	t.Helper()
	dir := filepath.Join(store, name)
	if err := os.CopyFS(dir, os.DirFS(toySandbox(t))); err != nil {
		t.Fatal(err)
	}
	pack := "name: " + name + "\nversion: " + version + "\ngraph: graph.yaml\nchecks:\n  unit: [grep, -q, done, build.txt]\n" +
		"sandbox:\n  stack: " + stack + "\n  egress: [" + egress + "]\n" + services
	if err := os.WriteFile(filepath.Join(dir, "pack.yaml"), []byte(pack), 0o644); err != nil {
		t.Fatal(err)
	}
	g, _ := os.ReadFile(filepath.Join(dir, "graph.yaml"))
	g = append(g, []byte("  - { id: api-touch, kind: exec, run: [echo, api], repo: repos/api }\n")...)
	os.WriteFile(filepath.Join(dir, "graph.yaml"), g, 0o644)
}

const apiServices = "services:\n  postgres:\n    image: " + pgImage + "\n    env: { POSTGRES_DB: app, POSTGRES_HOST_AUTH_METHOD: trust }\n    ports: [5432]\n" +
	"  seaweedfs:\n    image: " + s3Image + "\n    ports: [8333]\n"

// gallery starts a run of a web leaf and an api leaf, each in its own realm; the web leaf consumes the api.
func gallery(t *testing.T, webServices string) (*Run, *sandboxfake.Sandbox) {
	t.Helper()
	store := t.TempDir()
	sandboxRealm(t, store, "midgard-react", "0.1.0", "docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514",
		"registry.npmjs.org", webServices)
	sandboxRealm(t, store, "helheim-go", "0.2.0", nodeStack, "proxy.golang.org, sum.golang.org", apiServices)
	root := treetest.Node{Owner: "ouroboric-dev", Visibility: "private", Pin: treetest.Pin{Realm: "midgard-react", Version: "0.1.0"}, Children: map[string]treetest.Node{
		"repos/app": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Pin: treetest.Pin{Realm: "midgard-react", Version: "0.1.0"}, Consumes: []string{"repos/api"}},
		"repos/api": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Pin: treetest.Pin{Realm: "helheim-go", Version: "0.2.0"}},
	}}
	fake := &sandboxfake.Sandbox{}
	h := Hooks{NewSandbox: func(*SandboxSetup, string) (gungnir.Sandbox, error) { return fake, nil }}
	script := "{ agent: scripted, model: none, script: " + filepath.Join(toySandbox(t), "script.yaml") + " }"
	cfg := sandboxConfig(t, script, "realms:\n  dir: "+store+"\n")
	r, err := Start(ctx, Options{Project: treetest.Build(t, root), Config: cfg, Realm: "midgard-react", Hooks: h})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { r.Close() })
	return r, fake
}

func TestEachLeafsSandboxGetsItsRealmsStackAndEgress(t *testing.T) {
	r, fake := gallery(t, "")
	for _, repo := range []string{"repos/app", "repos/api"} {
		if _, err := r.Runner(ctx, repo); err != nil {
			t.Fatalf("Runner(%s) = %v", repo, err)
		}
	}
	specs := map[string]gungnir.SandboxSpec{}
	for _, s := range fake.Ups {
		specs[s.Name] = s
		if err := s.Validate(); err != nil {
			t.Errorf("the spec Odin built for %s is one the driver would refuse: %v", s.Name, err)
		}
	}
	web, api := specs["repos/app"], specs["repos/api"]
	if !strings.Contains(web.Stack, "golang") || !strings.Contains(api.Stack, "node:24.1.0") {
		t.Errorf("stacks: web %q, api %q; each leaf runs on the stack of its own realm", web.Stack, api.Stack)
	}
	if got := strings.Join(web.Egress, ","); got != "registry.npmjs.org" {
		t.Errorf("web egress = %s", got)
	}
	if got := strings.Join(api.Egress, ","); got != "proxy.golang.org,sum.golang.org" {
		t.Errorf("api egress = %s", got)
	}
}

func TestASandboxGetsTheServicesOfEachLeafItConsumes(t *testing.T) {
	r, fake := gallery(t, "")
	for _, repo := range []string{"repos/app", "repos/api"} {
		if _, err := r.Runner(ctx, repo); err != nil {
			t.Fatal(err)
		}
	}
	names := func(s gungnir.SandboxSpec) string {
		var out []string
		for _, v := range s.Services {
			out = append(out, v.Name)
		}
		return strings.Join(out, ",")
	}
	var web, api gungnir.SandboxSpec
	for _, s := range fake.Ups {
		if s.Name == "repos/app" {
			web = s
		} else {
			api = s
		}
	}
	if names(api) != "postgres,seaweedfs" {
		t.Errorf("api services = %s; its own realm's", names(api))
	}
	if names(web) != "postgres,seaweedfs" {
		t.Errorf("web services = %s; it consumes the api, so it gets the services of the api's realm (spec §9.2)", names(web))
	}
	if web.Services[0].Image != pgImage || web.Services[0].Env["POSTGRES_DB"] != "app" || web.Services[0].Ports[0] != 5432 {
		t.Errorf("postgres = %+v", web.Services[0])
	}
}

func TestTwoRealmsOfferingDifferentServicesOfOneNameStopTheRunBeforeASandboxStarts(t *testing.T) {
	store := t.TempDir()
	clash := "services:\n  postgres:\n    image: " + pgImage + "\n    env: { POSTGRES_DB: other }\n    ports: [5432]\n"
	sandboxRealm(t, store, "midgard-react", "0.1.0", nodeStack, "registry.npmjs.org", clash)
	sandboxRealm(t, store, "helheim-go", "0.2.0", nodeStack, "proxy.golang.org", apiServices)
	root := treetest.Node{Owner: "ouroboric-dev", Visibility: "private", Pin: treetest.Pin{Realm: "midgard-react", Version: "0.1.0"}, Children: map[string]treetest.Node{
		"repos/app": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Consumes: []string{"repos/api"}},
		"repos/api": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Pin: treetest.Pin{Realm: "helheim-go", Version: "0.2.0"}},
	}}
	script := "{ agent: scripted, model: none, script: " + filepath.Join(toySandbox(t), "script.yaml") + " }"
	cfg := sandboxConfig(t, script, "realms:\n  dir: "+store+"\n")
	_, err := Prepare(ctx, Options{Project: treetest.Build(t, root), Config: cfg, Realm: "midgard-react"})
	if err == nil || !strings.Contains(err.Error(), "two different services named postgres") {
		t.Errorf("Prepare() = %v", err)
	}
}

func TestARealmThatNamesNoStackCannotProvideALeafWhenASandboxIsOn(t *testing.T) {
	store := t.TempDir()
	sandboxRealm(t, store, "midgard-react", "0.1.0", nodeStack, "registry.npmjs.org", "")
	sandboxRealm(t, store, "helheim-go", "0.2.0", nodeStack, "proxy.golang.org", "")
	pack := filepath.Join(store, "helheim-go", "pack.yaml")
	b, _ := os.ReadFile(pack)
	os.WriteFile(pack, []byte(strings.SplitN(string(b), "sandbox:", 2)[0]), 0o644)
	root := treetest.Node{Owner: "ouroboric-dev", Visibility: "private", Pin: treetest.Pin{Realm: "midgard-react", Version: "0.1.0"}, Children: map[string]treetest.Node{
		"repos/app": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true},
		"repos/api": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Pin: treetest.Pin{Realm: "helheim-go", Version: "0.2.0"}},
	}}
	script := "{ agent: scripted, model: none, script: " + filepath.Join(toySandbox(t), "script.yaml") + " }"
	_, err := Prepare(ctx, Options{Project: treetest.Build(t, root), Config: sandboxConfig(t, script, "realms:\n  dir: "+store+"\n"), Realm: "midgard-react"})
	if err == nil || !strings.Contains(err.Error(), "helheim-go") || !strings.Contains(err.Error(), "repos/api") || !strings.Contains(err.Error(), "no sandbox stack") {
		t.Errorf("Prepare() = %v", err)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestEachLeafsSandboxGetsItsRealmsStackAndEgress (0.38s)
    sandbox_realms_test.go:80: stacks: web "", api ""; each leaf runs on the stack of its own realm
    sandbox_realms_test.go:86: api egress = registry.npmjs.org
--- FAIL: TestASandboxGetsTheServicesOfEachLeafItConsumes (0.38s)
```

- [ ] **Step 3:** write the code.

Apply to `internal/run/prepare.go`:

```diff
diff --git a/internal/run/prepare.go b/internal/run/prepare.go
index bc31f3b..7edc7e7 100644
--- a/internal/run/prepare.go
+++ b/internal/run/prepare.go
@@ -2,15 +2,19 @@ package run
 
 import (
 	"fmt"
+	"maps"
 	"os"
 	"slices"
 	"sort"
+	"strings"
 
 	"github.com/ouroboric-dev/gleipnir/sandbox"
 	"github.com/ouroboric-dev/gleipnir/skills"
+	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/havamal"
 	"github.com/ouroboric-dev/odin/internal/agents"
+	"github.com/ouroboric-dev/odin/internal/realm"
 )
 
 // SandboxSetup is what Prepare works out for a run whose leaves run in sandboxes (spec §6): where
@@ -19,7 +23,8 @@ import (
 type SandboxSetup struct {
 	Engine string
 	Config sandbox.Config
-	Egress []string // the model APIs of the roles the graph uses, and the realm's registries
+	Egress []string // the lead realm's registries and the model APIs of the roles the graph uses
+	Hosts  []string // the model APIs of the roles the graph uses: every leaf's sandbox opens them
 }
 
 // prepareSandbox sets up the sandbox of a run, and refuses a graph that would run outside it.
@@ -45,17 +50,70 @@ func (s *Setup) prepareSandbox() error {
 	for _, m := range s.Config.Sandbox.Mounts {
 		cfg.Mounts = append(cfg.Mounts, sandbox.PathMap{Host: m.Host, Engine: m.Engine})
 	}
-	egress := slices.Clone(s.Pack.Sandbox.Egress)
-	for _, n := range s.Graph.Nodes {
+	var hosts []string
+	for _, n := range s.Graph.All() {
 		for _, role := range nodeRoles(n) {
-			egress = append(egress, agents.Hosts(s.Config.Roles[role].Agent)...)
+			hosts = append(hosts, agents.Hosts(s.Config.Roles[role].Agent)...)
+		}
+	}
+	hosts = sortedUnique(hosts)
+	s.Sandbox = &SandboxSetup{Engine: s.Config.Sandbox.Engine, Config: cfg, Hosts: hosts, Egress: sortedUnique(slices.Concat(s.Pack.Sandbox.Egress, hosts))}
+	// A leaf of another realm starts on that realm's stack, so every leaf of the run must have one
+	// before anything starts, not when its sandbox comes up.
+	for _, p := range s.Leaves() {
+		if _, _, _, err := s.SandboxFor(p); err != nil {
+			return err
 		}
 	}
-	sort.Strings(egress)
-	s.Sandbox = &SandboxSetup{Engine: s.Config.Sandbox.Engine, Config: cfg, Egress: slices.Compact(egress)}
 	return nil
 }
 
+func sortedUnique(in []string) []string {
+	out := slices.Clone(in)
+	sort.Strings(out)
+	return slices.Compact(out)
+}
+
+// SandboxFor says what the sandbox of the leaf at repo starts: the stack layer and the registries of the
+// realm that provides the leaf, and the services of that realm and of each leaf it consumes (spec §6.1,
+// §9.2, change realm-leaf-naming). The model APIs of the run's roles are open in every sandbox.
+func (s *Setup) SandboxFor(repo string) (stack string, egress []string, services []gungnir.Service, err error) {
+	r := s.RealmOf(repo)
+	if r.Pack.Sandbox == nil {
+		return "", nil, nil, fmt.Errorf("the leaf %s is provided by the realm %s, which names no sandbox stack in its pack.yaml, and %s has a sandbox section", repo, r.Name, s.ConfigPath)
+	}
+	owners := map[string]string{} // service name: the realm that offers it
+	add := func(from *realm.Realm) error {
+		for _, v := range from.Pack.ServiceList() {
+			i := slices.IndexFunc(services, func(x gungnir.Service) bool { return x.Name == v.Name })
+			switch {
+			case i < 0:
+				services = append(services, v)
+				owners[v.Name] = from.Name
+			case !sameService(services[i], v):
+				return fmt.Errorf("the sandbox of %s would start two different services named %s: the realm %s offers one and the realm %s another", repo, v.Name, owners[v.Name], from.Name)
+			}
+		}
+		return nil
+	}
+	if err := add(r); err != nil {
+		return "", nil, nil, err
+	}
+	if u := s.Project.Umbrella; u != nil {
+		for _, c := range u.Children[repo].Consumes {
+			if err := add(s.RealmOf(c)); err != nil {
+				return "", nil, nil, err
+			}
+		}
+	}
+	slices.SortFunc(services, func(a, b gungnir.Service) int { return strings.Compare(a.Name, b.Name) })
+	return r.Pack.Sandbox.Stack, sortedUnique(slices.Concat(r.Pack.Sandbox.Egress, s.Sandbox.Hosts)), services, nil
+}
+
+func sameService(a, b gungnir.Service) bool {
+	return a.Image == b.Image && maps.Equal(a.Env, b.Env) && slices.Equal(a.Ports, b.Ports)
+}
+
 // prepareSkills opens the libraries and records the skills the graph names (spec §5.1). A node that
 // names a skill nobody has vendored refuses the run before it starts.
 func (s *Setup) prepareSkills(override *skills.Libraries) error {
@@ -74,7 +132,7 @@ func (s *Setup) prepareSkills(override *skills.Libraries) error {
 		}
 	}
 	var names []string
-	for _, n := range s.Graph.Nodes {
+	for _, n := range s.Graph.All() {
 		names = append(names, n.Skills...)
 		for _, rv := range n.Reviewers {
 			names = append(names, rv.Skills...)
```

Apply to `internal/run/sandbox.go`:

```diff
diff --git a/internal/run/sandbox.go b/internal/run/sandbox.go
index 2553bd8..8f36079 100644
--- a/internal/run/sandbox.go
+++ b/internal/run/sandbox.go
@@ -50,8 +50,12 @@ func (r *Run) Runner(ctx context.Context, repo string) (gungnir.Runner, error) {
 		return nil, err
 	}
 	parent, leaf := nodes[len(nodes)-2], nodes[len(nodes)-1]
+	stack, egress, services, err := r.Setup.SandboxFor(repo)
+	if err != nil {
+		return nil, err
+	}
 	env, err := r.Sandbox.Up(ctx, gungnir.SandboxSpec{Run: r.State.ID, Name: repo, Parent: parent.Dir, Leaf: leaf.Dir,
-		GitDir: leaf.GitDir, Egress: r.Setup.Sandbox.Egress})
+		GitDir: leaf.GitDir, Egress: egress, Stack: stack, Services: services})
 	if err != nil {
 		return nil, err
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T175: a run can take a leaf its graph doesn't name, and keeps it on resume

The project decides its leaves, so the graph can no longer name them all. A task works in the leaf its plan names, and init creates leaves the graph never heard of.

**Files (in `odin`):**
- Create: `internal/run/addleaf_test.go`
- Modify: `internal/run/run.go`

**Interfaces:**
- Produces: `(*Run).AddLeaf(ctx, repo)`: a leaf of the project becomes part of the run (resolved in the tree, its sandbox checked against its realm, the run's branch started in it, a record in run.json); a leaf the run has is left alone; a path that is not a leaf of the project, climbs, or is the project, is refused. `Options.Leaves` makes a resume resolve the leaves the run recorded.

**Acceptance criteria:**
- [ ] A run adds `repos/extra`, which no node names; it is on the run's branch; a second add is nothing; a resume knows the leaf.
- [ ] `repos/nope`, `../outside` and `.` are refused and change nothing.

**Named test:** `go test ./internal/run -run 'TestARunTakesALeafTheGraphDoesNotNameWhenAskedAndKeepsItOnResume|TestAddLeafRefusesWhatIsNotALeafOfTheProject'` in `odin`. **Layer:** `odin`. **Size:** M (116). **Depends on:** v0-T170.

- [ ] **Step 1:** write the tests.

Write `internal/run/addleaf_test.go`:

```go
package run

import (
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

func TestARunTakesALeafTheGraphDoesNotNameWhenAskedAndKeepsItOnResume(t *testing.T) {
	project := treetest.Project(t, "repos/app", "repos/extra")
	cfg := writeConfig(t, t.TempDir(), scriptedRoles+fullCaps)
	r, err := Start(ctx, Options{Project: project, Config: cfg, Realm: toy(t)})
	if err != nil {
		t.Fatal(err)
	}
	id := r.State.ID
	if _, ok := r.State.Leaves["repos/extra"]; ok {
		t.Fatal("a leaf no node names was started with the run")
	}
	if err := r.AddLeaf(ctx, "repos/extra"); err != nil {
		t.Fatalf("AddLeaf() = %v", err)
	}
	rec := r.State.Leaves["repos/extra"]
	if rec.Branch != Branch(id) || rec.Base == "" || rec.Base != rec.Checkpoint {
		t.Errorf("the leaf's record = %+v", rec)
	}
	if err := r.AddLeaf(ctx, "repos/extra"); err != nil {
		t.Errorf("a second AddLeaf() = %v; adding a leaf the run has is nothing", err)
	}
	l, _ := r.Leaf("repos/extra")
	if branch, _ := l.Git(ctx, "branch", "--show-current"); branch != Branch(id) {
		t.Errorf("repos/extra is on %q, want the run's branch", branch)
	}
	r.Close()
	r, err = Open(ctx, project, id, "")
	if err != nil {
		t.Fatalf("Open() = %v; a resume knows the leaves the run added", err)
	}
	defer r.Close()
	if _, ok := r.Setup.Repos["repos/extra"]; !ok || !strings.Contains(strings.Join(r.Setup.Leaves(), ","), "repos/extra") {
		t.Errorf("a resumed run's leaves = %v", r.Setup.Leaves())
	}
}

func TestAddLeafRefusesWhatIsNotALeafOfTheProject(t *testing.T) {
	project := treetest.Project(t, "repos/app")
	r, err := Start(ctx, Options{Project: project, Config: writeConfig(t, t.TempDir(), scriptedRoles+fullCaps), Realm: toy(t)})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	for _, p := range []string{"repos/nope", "../outside", "."} {
		if err := r.AddLeaf(ctx, p); err == nil {
			t.Errorf("AddLeaf(%q) = nil", p)
		}
	}
	if len(r.State.Leaves) != 1 {
		t.Errorf("leaves = %v", r.State.Leaves)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/run [github.com/ouroboric-dev/odin/internal/run.test]
internal/run/addleaf_test.go:21:14: r.AddLeaf undefined (type *Run has no field or method AddLeaf)
internal/run/addleaf_test.go:28:14: r.AddLeaf undefined (type *Run has no field or method AddLeaf)
internal/run/addleaf_test.go:54:15: r.AddLeaf undefined (type *Run has no field or method AddLeaf)
```

- [ ] **Step 3:** write the code.

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 363d2af..ea82124 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -35,6 +35,7 @@ type Options struct {
 	Config  string            // factory.yaml
 	Realm   string            // the lead realm: a realm leaf's name, found in factory.yaml's realms.dir, or a path to the folder that holds pack.yaml
 	Realms  map[string]string // a resume: the folder of each realm the run recorded, by name; they are loaded from there
+	Leaves  []string          // a resume: the leaves the run added beyond the ones its graph names (AddLeaf)
 	Brief   string            // optional
 	Mode    gungnir.Mode      // "" means the config's mode
 	Hooks   Hooks             // tests only
@@ -136,6 +137,11 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 	if s.Realms, err = s.collectRealms(store, o.Realms); err != nil {
 		return nil, err
 	}
+	for _, p := range o.Leaves {
+		if err := s.addLeaf(ctx, p); err != nil {
+			return nil, err
+		}
+	}
 	// A realm named in the store is pinned by the project's first run; one given as a path is a checkout
 	// being worked on, and pins nothing.
 	s.PinLead = byName && s.Project.Umbrella != nil && s.Project.Umbrella.Realm == ""
@@ -331,6 +337,53 @@ func (s *Setup) isLeaf(repo string) bool {
 	return slices.Contains(s.Create, repo)
 }
 
+// addLeaf resolves the leaf at repo, a path from the project, and makes it one of the run's repos.
+func (s *Setup) addLeaf(ctx context.Context, repo string) error {
+	if !filepath.IsLocal(repo) || repo == "." {
+		return fmt.Errorf("%q is not a path inside the project", repo)
+	}
+	if _, ok := s.Repos[repo]; ok {
+		return nil
+	}
+	if u := s.Project.Umbrella; u == nil || u.Children[repo].Kind != schema.ChildLeaf {
+		return fmt.Errorf("%s is not a leaf of the project", repo)
+	}
+	nodes, err := tree.Resolve(ctx, s.Root, filepath.Join(s.ProjectPath, repo))
+	if err != nil {
+		return err
+	}
+	s.Repos[repo] = nodes[len(nodes)-1]
+	if s.Sandbox != nil {
+		if _, _, _, err := s.SandboxFor(repo); err != nil {
+			delete(s.Repos, repo)
+			return err
+		}
+	}
+	return nil
+}
+
+// AddLeaf makes the leaf at repo part of the run once the run knows it needs it: a task works in it,
+// or init made it. The leaf gets the run's branch and a record in run.json, as a leaf its graph names
+// does at the start; a leaf the run already has is left alone.
+func (r *Run) AddLeaf(ctx context.Context, repo string) error {
+	if err := r.Setup.addLeaf(ctx, repo); err != nil {
+		return err
+	}
+	if _, ok := r.State.Leaves[repo]; ok {
+		return nil
+	}
+	l, err := r.Leaf(repo)
+	if err != nil {
+		return err
+	}
+	head, err := l.StartBranch(ctx, Branch(r.State.ID), "main")
+	if err != nil {
+		return err
+	}
+	r.State.Leaves[repo] = LeafRecord{Branch: Branch(r.State.ID), Base: head, Checkpoint: head}
+	return r.Save()
+}
+
 // Leaves returns the paths of the leaves the graph works in, sorted.
 func (s *Setup) Leaves() []string {
 	var ls []string
@@ -753,7 +806,8 @@ func open(ctx context.Context, project, dir string, mode gungnir.Mode, h Hooks)
 	for name, r := range s.Realms {
 		dirs[name] = r.Dir
 	}
-	setup, err := Prepare(ctx, Options{Project: project, Config: s.ConfigPath, Realm: s.RealmDir, Realms: dirs, Brief: s.Brief, Mode: mode, Hooks: h})
+	setup, err := Prepare(ctx, Options{Project: project, Config: s.ConfigPath, Realm: s.RealmDir, Realms: dirs, Leaves: slices.Sorted(maps.Keys(s.Leaves)),
+		Brief: s.Brief, Mode: mode, Hooks: h})
 	if err != nil {
 		return nil, err
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T176: the tasks node reads the plan's tasks.md, checks every task is ready, and writes features.json

Spec §4.2: "DoR check (exec): every task MUST have acceptance criteria, a named test, a layer and a size... Odin derives `features.json` from `tasks.md`". The node finds the plan, applies the Definition of Ready against the project's leaves and the leaves the spec stage named, and records the tasks in build order.

**Files (in `odin`):**
- Create: `internal/engine/stages.go`, `internal/engine/tasks_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/gates.go`, `internal/engine/realms_test.go`, `internal/run/run.go`, `internal/run/state.go`

**Interfaces:**
- Produces: `engine.runTasks`; `engine.FeaturesFile`; `State.Features []FeatureRecord`, `PlanSource`, `PlanSHA256`; `(*Run).Nodes()`, the nodes the run walks (the graph's, for now); `Prepare` accepts the nodes that work in the project, not in a leaf (`tasks`, `publish`, `init`). The plan is the one regular file the glob matches, reached through no symlink, under 1 MiB; the leaves it may name are the project's and those of the leaves file the node names.
- A plan that cannot be read or is not ready fails the node with the problems listed (v0-T177 sends it back to the planner). A ready plan writes `.factory/features.json` (all tasks to do) and a `tasks_ready` line.

**Acceptance criteria:**
- [ ] A ready plan becomes features in the order they are built, in run.json and in features.json.
- [ ] A plan that is not ready fails the node with every problem; no features.json is written.
- [ ] Not one file, or a symlink, is not a plan; a layer named by the spec stage's leaves file passes, one that no leaf has does not.

**Named test:** `go test ./internal/engine -run 'TestAReadyPlanBecomesFeaturesInTheOrderTheyAreBuilt|TestAPlanThatIsNotReadyFailsTheNodeWithEveryProblem|TestThePlanMustBeOneRegularFile|TestATaskMayWorkInALeafTheSpecStageNamedAndInitHasNotCreatedYet'` in `odin`. **Layer:** `odin`. **Size:** M (310). **Depends on:** v0-T170, v0-T151 (merged).

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/realms_test.go`:

```diff
diff --git a/internal/engine/realms_test.go b/internal/engine/realms_test.go
index f7cad3c..35d222e 100644
--- a/internal/engine/realms_test.go
+++ b/internal/engine/realms_test.go
@@ -2,7 +2,6 @@ package engine
 
 import (
 	"context"
-	"encoding/json"
 	"os"
 	"path/filepath"
 	"strings"
@@ -94,18 +93,7 @@ func startRealms(t *testing.T, o realmsSetup) *run.Run {
 }
 
 // transcriptPrompt returns the prompt a scripted session of node got in attempt 1.
-func transcriptPrompt(t *testing.T, r *run.Run, node string) string {
-	t.Helper()
-	b, err := os.ReadFile(filepath.Join(r.Dir, "transcripts", node+"-1.json"))
-	if err != nil {
-		t.Fatal(err)
-	}
-	var tr struct{ Prompt string }
-	if err := json.Unmarshal(b, &tr); err != nil {
-		t.Fatal(err)
-	}
-	return tr.Prompt
-}
+func transcriptPrompt(t *testing.T, r *run.Run, node string) string { return promptOf(t, r, node+"-1") }
 
 const leadAndOther = "checks:\n  unit: [sh, -c, \"echo lead > ran-by.txt\"]\n"
 
```

Write `internal/engine/tasks_test.go`:

```go
package engine

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
)

// taskMD is one task of a tasks.md, ready unless a field is left out of the arguments.
func taskMD(id, layer, size, deps string) string {
	return "## " + id + ": task " + id + "\n\n- **Acceptance criteria:**\n  - [ ] it works\n- **Named test:** TestIt\n- **Layer:** " + layer +
		"\n- **Size:** " + size + "\n- **Depends on:** " + deps + "\n\n"
}

const readyPlan = "# Tasks\n\n"

// planScript writes tasks.md in the leaf, the way a planner's session would: one entry for each attempt.
func planScript(plans ...string) string {
	var b strings.Builder
	b.WriteString("steps:\n  plan:\n")
	for _, p := range plans {
		b.WriteString("    - actions: [ { write: { path: tasks.md, content: " + quote(p) + " } } ]\n      result: { status: ok, summary: wrote tasks.md }\n")
	}
	return b.String()
}

func quote(s string) string {
	s = strings.ReplaceAll(strings.ReplaceAll(s, `\`, `\\`), `"`, `\"`)
	return `"` + strings.ReplaceAll(s, "\n", `\n`) + `"`
}

const planNodes = "  - { id: plan, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n"

func TestAReadyPlanBecomesFeaturesInTheOrderTheyAreBuilt(t *testing.T) {
	plan := readyPlan + taskMD("gallery-T2", "repos/app", "M", "gallery-T1") + taskMD("gallery-T1", "repos/app", "S", "nothing")
	r := start(t, "key-points", "", planNodes+"  - { id: ready, kind: tasks, from: repos/app/tasks.md }\n", planScript(plan))
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if len(r.State.Features) != 2 || r.State.Features[0].ID != "gallery-T1" || r.State.Features[1].ID != "gallery-T2" ||
		r.State.Features[0].Status != schema.TaskTodo || r.State.PlanSource != "repos/app/tasks.md" || len(r.State.PlanSHA256) != 64 {
		t.Fatalf("Features = %+v, source %q", r.State.Features, r.State.PlanSource)
	}
	f, err := schema.LoadFeatures(filepath.Join(r.Project, ".factory", "features.json"))
	if err != nil || f.Run != r.State.ID || len(f.Tasks) != 2 || f.Tasks[0].ID != "gallery-T1" || f.Tasks[1].DependsOn[0] != "gallery-T1" {
		t.Errorf("features.json = %+v, %v", f, err)
	}
	if text := ledgerText(t, r); !strings.Contains(text, `"event":"tasks_ready"`) || !strings.Contains(text, "2 task(s) are ready, from repos/app/tasks.md") {
		t.Errorf("the ledger lacks tasks_ready:\n%s", text)
	}
}

func TestAPlanThatIsNotReadyFailsTheNodeWithEveryProblem(t *testing.T) {
	bad := readyPlan + taskMD("p-T1", "repos/app", "", "nothing")
	r := start(t, "key-points", "", planNodes+"  - { id: ready, kind: tasks, from: repos/app/tasks.md }\n", planScript(bad))
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "no size") {
		t.Errorf("Advance() = %+v, %v", out, err)
	}
}

func TestThePlanMustBeOneRegularFile(t *testing.T) {
	r := start(t, "key-points", "", "  - { id: ready, kind: tasks, from: plans/*/tasks.md }\n", "steps: {}\n")
	app := r.Project
	run1 := func() string {
		out, err := Advance(context.Background(), r)
		if err != nil || out.Status != run.StatusFailed {
			t.Fatalf("Advance() = %+v, %v", out, err)
		}
		return out.Err.Error()
	}
	if msg := run1(); !strings.Contains(msg, "there is no tasks file at plans/*/tasks.md") {
		t.Errorf("no file: %s", msg)
	}
	for _, d := range []string{"a", "b"} {
		os.MkdirAll(filepath.Join(app, "plans", d), 0o755)
		os.WriteFile(filepath.Join(app, "plans", d, "tasks.md"), []byte(readyPlan+taskMD("p-T1", "repos/app", "S", "nothing")), 0o644)
	}
	if msg := run1(); !strings.Contains(msg, "2 files match") {
		t.Errorf("two files: %s", msg)
	}
	os.RemoveAll(filepath.Join(app, "plans", "b"))
	os.MkdirAll(filepath.Join(app, "plans", "b"), 0o755)
	os.Symlink("../a/tasks.md", filepath.Join(app, "plans", "b", "tasks.md")) // a link is not a plan
	os.Remove(filepath.Join(app, "plans", "a", "tasks.md"))
	if msg := run1(); !strings.Contains(msg, "there is no tasks file") {
		t.Errorf("a symlink: %s", msg)
	}
}

func TestATaskMayWorkInALeafTheSpecStageNamedAndInitHasNotCreatedYet(t *testing.T) {
	leaves := "leaves:\n  repos/api: { realm: helheim-go, realm_version: 0.1.0, description: The API. }\n"
	plan := readyPlan + taskMD("p-T1", "repos/api", "S", "nothing")
	script := planScript(plan) + "  leaves-file:\n    - actions: [ { write: { path: leaves.yaml, content: " + quote(leaves) + " } } ]\n      result: { status: ok, summary: wrote leaves.yaml }\n"
	nodes := planNodes + "  - { id: leaves-file, kind: agent, role: planner, prompt: p.md, repo: repos/app }\n  - { id: ready, kind: tasks, from: repos/app/tasks.md, leaves: repos/app/leaves.yaml }\n"
	r := start(t, "key-points", "", nodes, script)
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	// With no leaves file, the layer is not a leaf of the project.
	noFile := strings.Replace(nodes, "leaves: repos/app/leaves.yaml", "leaves: repos/app/missing.yaml", 1)
	r = start(t, "key-points", "", noFile, script)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "the leaves file repos/app/missing.yaml can't be read") {
		t.Errorf("Advance() = %+v, %v", out, err)
	}
	// A leaves file that doesn't parse is the spec stage's to fix.
	r = start(t, "key-points", "", nodes, strings.Replace(script, "realm: helheim-go, ", "", 1))
	out, err = Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "leaves.yaml") {
		t.Errorf("Advance() = %+v, %v", out, err)
	}
}

// promptOf returns the prompt the scripted session named stem (node-attempt) got, as the agent read it.
func promptOf(t *testing.T, r *run.Run, stem string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(r.Dir, "transcripts", stem+".json"))
	if err != nil {
		t.Fatal(err)
	}
	var tr struct{ Prompt string }
	if err := json.Unmarshal(b, &tr); err != nil {
		t.Fatal(err)
	}
	return tr.Prompt
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/tasks_test.go:47:17: r.State.Features undefined (type *run.State has no field or method Features)
internal/engine/tasks_test.go:48:11: r.State.Features undefined (type *run.State has no field or method Features)
internal/engine/tasks_test.go:48:60: r.State.PlanSource undefined (type *run.State has no field or method PlanSource)
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 080025d..cc68b10 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -55,7 +55,7 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 	if err := r.Save(); err != nil {
 		return Outcome{}, err
 	}
-	nodes := r.Setup.Graph.Nodes
+	nodes := r.Nodes()
 	for s.Position < len(nodes) {
 		n := nodes[s.Position]
 		var stop bool
@@ -73,6 +73,8 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 			err = runMerge(ctx, r, n)
 		case schema.KindPointer:
 			err = runPointer(ctx, r, n)
+		case schema.KindTasks:
+			err = runTasks(ctx, r, n)
 		}
 		var nf *nodeFailure
 		if errors.As(err, &nf) {
```

Apply to `internal/engine/gates.go`:

```diff
diff --git a/internal/engine/gates.go b/internal/engine/gates.go
index 3d2cf20..31ac71e 100644
--- a/internal/engine/gates.go
+++ b/internal/engine/gates.go
@@ -57,7 +57,7 @@ func writeGateFile(r *run.Run, n schema.Node, attempt int, action gate.Action) (
 	fmt.Fprintf(&b, "- Run: %s\n- Mode: %s\n- Decision: %s\n- Time: %s\n\n", s.ID, s.Mode, decision,
 		time.Now().UTC().Format(time.RFC3339))
 	b.WriteString("## What happened\n\n")
-	nodes := r.Setup.Graph.Nodes
+	nodes := r.Nodes()
 	start := 0
 	for i := s.Position - 1; i >= 0; i-- {
 		if nodes[i].Kind == schema.KindGate {
@@ -103,7 +103,7 @@ func Approve(ctx context.Context, r *run.Run, gateID, note string) error {
 		return err
 	}
 	s := r.State
-	n := r.Setup.Graph.Nodes[s.Position]
+	n := r.Nodes()[s.Position]
 	if n.Kind == schema.KindLoop && s.PendingGate == gungnir.GateEscalation {
 		if rec := s.Loops[n.ID]; rec == nil || rec.Escalation == nil || rec.Escalation.Reason != jormungandr.ReasonExhausted {
 			return fmt.Errorf("loop %s stopped because a reviewer's answer can't be read, and an answer nobody can read is not an approval; "+
@@ -144,10 +144,10 @@ func Approve(ctx context.Context, r *run.Run, gateID, note string) error {
 // loop that gave up. A hard stop that a node raised takes approve only, or a new run (spec §7.2).
 func Rejectable(r *run.Run) bool {
 	s := r.State
-	if s.Pending == "" || s.Position >= len(r.Setup.Graph.Nodes) {
+	if s.Pending == "" || s.Position >= len(r.Nodes()) {
 		return false
 	}
-	n := r.Setup.Graph.Nodes[s.Position]
+	n := r.Nodes()[s.Position]
 	return n.Kind == schema.KindGate || (n.Kind == schema.KindLoop && s.PendingGate == gungnir.GateEscalation)
 }
 
@@ -155,10 +155,10 @@ func Rejectable(r *run.Run) bool {
 // reviewer's answer can't be read does not: that is not a decision a person can take for the reviewer.
 func Approvable(r *run.Run) bool {
 	s := r.State
-	if s.Pending == "" || s.Position >= len(r.Setup.Graph.Nodes) {
+	if s.Pending == "" || s.Position >= len(r.Nodes()) {
 		return false
 	}
-	n := r.Setup.Graph.Nodes[s.Position]
+	n := r.Nodes()[s.Position]
 	if n.Kind == schema.KindLoop && s.PendingGate == gungnir.GateEscalation {
 		rec := s.Loops[n.ID]
 		return rec != nil && rec.Escalation != nil && rec.Escalation.Reason == jormungandr.ReasonExhausted
@@ -176,7 +176,7 @@ func Reject(ctx context.Context, r *run.Run, gateID, reason string) error {
 		return err
 	}
 	s := r.State
-	g := r.Setup.Graph
+	nodes := r.Nodes()
 	if !Rejectable(r) {
 		return fmt.Errorf("%s stopped at the hard approval point %s, which takes approve; to drop the work, start a new run", gateID, s.PendingGate)
 	}
@@ -186,7 +186,7 @@ func Reject(ctx context.Context, r *run.Run, gateID, reason string) error {
 	if err := r.Log(gungnir.Event{Name: gungnir.EventGateRejected, Node: gateID, Gate: gateID, Note: reason}); err != nil {
 		return err
 	}
-	if n := g.Nodes[s.Position]; n.Kind == schema.KindLoop {
+	if n := nodes[s.Position]; n.Kind == schema.KindLoop {
 		rec := s.Loops[n.ID]
 		rec.State.Extend(loopConfig(n))
 		rec.Escalation = nil
@@ -195,10 +195,10 @@ func Reject(ctx context.Context, r *run.Run, gateID, reason string) error {
 		target := n.Reruns
 		s.Reasons[target] = reason
 		gate := s.Position
-		s.Position = g.Index(target)
+		s.Position = indexOf(nodes, target)
 		// Every loop from the target up to the gate starts over: the work under a loop that passed changes
 		// when a node before it runs again (review I2).
-		for _, m := range g.Nodes[s.Position:gate] {
+		for _, m := range nodes[s.Position:gate] {
 			if m.Kind == schema.KindLoop {
 				delete(s.Loops, m.ID)
 			}
@@ -276,3 +276,13 @@ func stopHard(r *run.Run, n schema.Node, h *hardStop) (Outcome, error) {
 	s.Status, s.Pending, s.PendingGate = run.StatusStopped, n.ID, h.gate
 	return Outcome{Status: run.StatusStopped, Gate: n.ID}, r.Save()
 }
+
+// indexOf returns the position of the node with the given id, or -1.
+func indexOf(nodes []schema.Node, id string) int {
+	for i, n := range nodes {
+		if n.ID == id {
+			return i
+		}
+	}
+	return -1
+}
```

Write `internal/engine/stages.go`:

```go
package engine

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
)

// FeaturesFile is where Odin writes the plan's tasks and where each stands, in the project (spec §3.3 rule 2).
const FeaturesFile = ".factory/features.json"

// runTasks reads the plan's tasks.md, checks every task is ready (the Definition of Ready, spec §4.2) and
// derives features.json from it. A plan that isn't ready is a refusal: it goes back to the node n names
// with back_to, the planner, as input with every problem listed; with no back_to, or once the returns are
// used, the node fails. The tasks of a ready plan are recorded in build order, in run.json and in
// features.json, with all of them to do.
func runTasks(ctx context.Context, r *run.Run, n schema.Node) error {
	attempt, err := startAttempt(r, n)
	if err != nil {
		return err
	}
	if err := r.Log(gungnir.Event{Name: gungnir.EventNodeStarted, Node: n.ID, Attempt: attempt}); err != nil {
		return err
	}
	fs, source, sum, refusal, err := readPlan(r, n)
	if err != nil {
		return err
	}
	if refusal != "" {
		ev := gungnir.Event{Name: gungnir.EventNodeFailed, Node: n.ID, Attempt: attempt, Result: firstLine(refusal)}
		if err := r.Log(ev); err != nil {
			return err
		}
		return &nodeFailure{errors.New(refusal)}
	}
	s := r.State
	s.Features, s.PlanSource, s.PlanSHA256 = nil, source, sum
	for _, f := range fs {
		s.Features = append(s.Features, schema.FeatureRecord{Feature: f, Status: schema.TaskTodo})
	}
	if err := writeFeatures(r); err != nil {
		return err
	}
	s.Summaries[n.ID] = fmt.Sprintf("%d task(s) are ready, from %s", len(fs), source)
	return r.Log(gungnir.Event{Name: gungnir.EventTasksReady, Node: n.ID, Attempt: attempt, Result: s.Summaries[n.ID]})
}

// readPlan finds the one tasks.md that n.From names, reads it, and applies the Definition of Ready. A plan
// that can't be read or isn't ready gives a refusal, in words for the planner; err is Odin's own failure.
func readPlan(r *run.Run, n schema.Node) (fs []schema.Feature, source, sum, refusal string, err error) {
	matches, err := filepath.Glob(filepath.Join(r.Project, filepath.FromSlash(n.From)))
	if err != nil {
		return nil, "", "", fmt.Sprintf("tasks: %q is not a path pattern: %v", n.From, err), nil
	}
	var files []string
	for _, m := range matches {
		if st, err := os.Lstat(m); err == nil && st.Mode().IsRegular() {
			files = append(files, m)
		}
	}
	switch {
	case len(files) == 0:
		return nil, "", "", fmt.Sprintf("there is no tasks file at %s, so there is no plan to build. Write the plan's tasks.md there.", n.From), nil
	case len(files) > 1:
		return nil, "", "", fmt.Sprintf("%d files match %s, and a plan has exactly one tasks.md: keep one.", len(files), n.From), nil
	}
	f, err := os.Open(files[0])
	if err != nil {
		return nil, "", "", "", err
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, schema.MaxTasksFile+1))
	if err != nil {
		return nil, "", "", "", err
	}
	source, err = filepath.Rel(r.Project, files[0])
	if err != nil {
		return nil, "", "", "", err
	}
	source = filepath.ToSlash(source)
	if fs, err = schema.ParseTasks(source, data); err != nil {
		return nil, "", "", err.Error(), nil
	}
	leaves, refusal, err := planLeaves(r, n)
	if err != nil || refusal != "" {
		return nil, "", "", refusal, err
	}
	if err := schema.CheckReady(fs, leaves); err != nil {
		return nil, "", "", err.Error(), nil
	}
	if fs, err = schema.ReadyOrder(fs); err != nil {
		return nil, "", "", err.Error(), nil
	}
	h := sha256.Sum256(data)
	return fs, source, hex.EncodeToString(h[:]), "", nil
}

// planLeaves returns the leaves a task may work in: those the project has, and those the spec stage named
// in the leaves file the node points at, which init has not created yet.
func planLeaves(r *run.Run, n schema.Node) (leaves []string, refusal string, err error) {
	if u := r.Setup.Project.Umbrella; u != nil {
		for _, p := range u.Paths() {
			if u.Children[p].Kind == schema.ChildLeaf {
				leaves = append(leaves, p)
			}
		}
	}
	if n.Leaves != "" {
		file := filepath.Join(r.Project, filepath.FromSlash(n.Leaves))
		data, rerr := os.ReadFile(file)
		if rerr != nil {
			return nil, fmt.Sprintf("the leaves file %s can't be read (%v), so the tasks' leaves can't be checked. The spec stage names the product's leaves there.", n.Leaves, rerr), nil
		}
		l, perr := schema.ParseLeaves(n.Leaves, data)
		if perr != nil {
			return nil, perr.Error(), nil
		}
		leaves = append(leaves, l.Paths()...)
	}
	slices.Sort(leaves)
	return slices.Compact(leaves), "", nil
}

// writeFeatures writes features.json from the run's record of the tasks.
func writeFeatures(r *run.Run) error {
	s := r.State
	if err := os.MkdirAll(filepath.Join(r.Project, ".factory"), 0o755); err != nil {
		return err
	}
	f := &schema.Features{Run: s.ID, Source: s.PlanSource, SourceSHA256: s.PlanSHA256, Tasks: slices.Clone(s.Features)}
	return f.Save(filepath.Join(r.Project, filepath.FromSlash(FeaturesFile)))
}
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index ea82124..f2bf8c4 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -221,8 +221,9 @@ func (s *Setup) findProject(ctx context.Context, project string) error {
 
 // checkNode checks that node n can run in this project: its repo, its role and prompt, its checks.
 func (s *Setup) checkNode(ctx context.Context, graphPath string, n schema.Node) error {
-	if n.Kind == schema.KindGate {
-		return nil
+	switch {
+	case n.Kind == schema.KindGate, n.Kind == schema.KindPublish, n.Kind == schema.KindTasks, n.Kind == schema.KindInit:
+		return nil // they work in the project, not in a leaf
 	}
 	if n.Repo == "" {
 		return fmt.Errorf("%s: node %s names no repo; every node that does work runs in a repo of the project", graphPath, n.ID)
@@ -410,6 +411,9 @@ type Run struct {
 	Sandbox  gungnir.Sandbox // runs the leaves' commands; nil when the config has no sandbox section
 }
 
+// Nodes returns the nodes the run walks, in order. Position indexes this list.
+func (r *Run) Nodes() []schema.Node { return r.Setup.Graph.Nodes }
+
 // Meter returns the budget of this run: its caps against its own usage and the day's journal.
 func (r *Run) Meter() *budget.Meter {
 	return &budget.Meter{Run: &r.State.Usage, Caps: r.Setup.Config.Budget, USD: r.Setup.Config.PaysPerToken(), Journal: r.Setup.Journal}
```

Apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index 1014476..ecd5dd2 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -20,6 +20,7 @@ import (
 
 	"github.com/ouroboric-dev/gleipnir/skills"
 	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/jormungandr"
 	"github.com/ouroboric-dev/odin/internal/budget"
 	"github.com/ouroboric-dev/odin/internal/ledger"
@@ -87,6 +88,9 @@ type State struct {
 	Paused       *Pause                 `json:"paused,omitempty"`        // why the run is paused
 	Warned       map[string]bool        `json:"warned,omitempty"`        // the budget warnings already given, so each comes once
 	Loops        map[string]*LoopRecord `json:"loops,omitempty"`         // loop node id: where its loop stands
+	Features     []schema.FeatureRecord `json:"features,omitempty"`      // the plan's tasks in the order they are built, once the tasks node has run
+	PlanSource   string                 `json:"plan_source,omitempty"`   // the tasks.md they came from, relative to the project
+	PlanSHA256   string                 `json:"plan_sha256,omitempty"`   // that file as Odin read it
 	Ledger       ledger.Anchor          `json:"ledger"`
 	Error        string                 `json:"error,omitempty"`
 	Exec         *ExecProcess           `json:"exec,omitempty"` // the exec node running now, if any
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T177: a refusal can go back into an earlier node as its input, a few times, and a plan that isn't ready goes back to the planner

Spec §4.5 and §4.2: a refusal "returns to the loop", and a task of size L "goes back to the planner". One mechanism does both: the refusing node names where it goes (`back_to`) and how often (`returns`).

**Files (in `odin`):**
- Create: `internal/engine/returns.go`
- Modify: `internal/engine/engine.go`, `internal/engine/loop.go`, `internal/engine/stages.go`, `internal/engine/tasks_test.go`, `internal/run/run.go`, `internal/run/state.go`

**Interfaces:**
- Produces: `engine.sendBack(r, n, refusal) (bool, error)`: at most `n.Returns` times it logs `node_returned`, makes the refusal the target's input for its next attempt (`State.Refusals`, shown in the prompt as `jormungandr.Refusal`), reopens a loop target, starts over every loop between the target and the node, moves Position back and saves; it returns a `*sentBack` that `Advance` treats as "go on from Position". `State.Returns`, `State.Refusals`. The tasks node uses it.

**Acceptance criteria:**
- [ ] A plan with an L task and a missing blocker goes back to the planner, whose second prompt lists every problem; the second plan passes; the ledger has `node_returned`.
- [ ] With `returns: 1` a plan that stays bad fails the node after one return; with no `back_to` it fails at once; no features.json is written for a plan that is not ready.

**Named test:** `go test ./internal/engine -run 'TestAPlanThatIsNotReadyGoesBackToThePlannerWithEveryProblem|TestARefusalGoesBackOnlyAsOftenAsTheNodeAllows|TestAPlanWithNoBackToFailsTheNode'` in `odin`. **Layer:** `odin`. **Size:** M (124). **Depends on:** v0-T176, v0-T165 (merged), v0-T166 (merged).

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/tasks_test.go`:

```diff
diff --git a/internal/engine/tasks_test.go b/internal/engine/tasks_test.go
index 81dc33f..e5b34a9 100644
--- a/internal/engine/tasks_test.go
+++ b/internal/engine/tasks_test.go
@@ -57,7 +57,51 @@ func TestAReadyPlanBecomesFeaturesInTheOrderTheyAreBuilt(t *testing.T) {
 	}
 }
 
-func TestAPlanThatIsNotReadyFailsTheNodeWithEveryProblem(t *testing.T) {
+func TestAPlanThatIsNotReadyGoesBackToThePlannerWithEveryProblem(t *testing.T) {
+	bad := readyPlan + taskMD("p-T1", "repos/app", "L", "nothing") + taskMD("p-T2", "repos/db", "S", "p-T9")
+	good := readyPlan + taskMD("p-T1", "repos/app", "S", "nothing") + taskMD("p-T2", "repos/app", "S", "p-T1")
+	r := start(t, "key-points", "", planNodes+"  - { id: ready, kind: tasks, from: repos/app/tasks.md, back_to: plan }\n", planScript(bad, good))
+	out, err := Advance(context.Background(), r)
+	if err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+	if r.State.Attempts["plan"] != 2 || r.State.Returns["ready"] != 1 {
+		t.Errorf("the planner ran %d times, the refusal went back %d times; want 2 and 1", r.State.Attempts["plan"], r.State.Returns["ready"])
+	}
+	prompt := promptOf(t, r, "plan-2")
+	for _, want := range []string{"## Refused after your work passed", "size L: split it", `layer "repos/db" is not a leaf of this project (repos/app)`, `depends on "p-T9"`} {
+		if !strings.Contains(prompt, want) {
+			t.Errorf("the planner's second prompt lacks %q:\n%s", want, prompt)
+		}
+	}
+	if first := promptOf(t, r, "plan-1"); strings.Contains(first, "Refused after") {
+		t.Error("the first attempt was told of a refusal that had not happened")
+	}
+	if len(r.State.Features) != 2 || len(r.State.Refusals) != 0 {
+		t.Errorf("features %d, refusals %v; the refusal is spent once the planner's work is accepted", len(r.State.Features), r.State.Refusals)
+	}
+	text := ledgerText(t, r)
+	if !strings.Contains(text, `"event":"node_returned"`) || !strings.Contains(text, "back to plan, 1 of 2") {
+		t.Errorf("the ledger lacks node_returned:\n%s", text)
+	}
+}
+
+func TestARefusalGoesBackOnlyAsOftenAsTheNodeAllows(t *testing.T) {
+	bad := readyPlan + taskMD("p-T1", "repos/app", "L", "nothing")
+	r := start(t, "key-points", "", planNodes+"  - { id: ready, kind: tasks, from: repos/app/tasks.md, back_to: plan, returns: 1 }\n", planScript(bad, bad, bad))
+	out, err := Advance(context.Background(), r)
+	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "size L: split it") {
+		t.Fatalf("Advance() = %+v, %v; want the run failed with the readiness error", out, err)
+	}
+	if r.State.Attempts["plan"] != 2 || r.State.Returns["ready"] != 1 {
+		t.Errorf("planner %d times, returned %d times; want 2 and 1", r.State.Attempts["plan"], r.State.Returns["ready"])
+	}
+	if _, err := os.Stat(filepath.Join(r.Project, ".factory", "features.json")); err == nil {
+		t.Error("features.json was written for a plan that is not ready")
+	}
+}
+
+func TestAPlanWithNoBackToFailsTheNode(t *testing.T) {
 	bad := readyPlan + taskMD("p-T1", "repos/app", "", "nothing")
 	r := start(t, "key-points", "", planNodes+"  - { id: ready, kind: tasks, from: repos/app/tasks.md }\n", planScript(bad))
 	out, err := Advance(context.Background(), r)
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/tasks_test.go:68:46: r.State.Returns undefined (type *run.State has no field or method Returns)
internal/engine/tasks_test.go:69:120: r.State.Returns undefined (type *run.State has no field or method Returns)
internal/engine/tasks_test.go:80:47: r.State.Refusals undefined (type *run.State has no field or method Refusals)
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index cc68b10..ce92f03 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -16,6 +16,7 @@ import (
 	"github.com/ouroboric-dev/gleipnir/scan"
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
+	"github.com/ouroboric-dev/jormungandr"
 	"github.com/ouroboric-dev/odin/internal/leaf"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
@@ -76,6 +77,10 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 		case schema.KindTasks:
 			err = runTasks(ctx, r, n)
 		}
+		var sb *sentBack
+		if errors.As(err, &sb) {
+			continue // the refusal went back: Position points at the node it went back to
+		}
 		var nf *nodeFailure
 		if errors.As(err, &nf) {
 			return fail(r, n, nf.err)
@@ -151,6 +156,9 @@ func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 	if reason := s.Reasons[n.ID]; reason != "" {
 		text += "\n\n## Rejected at the approval point\n\n" + reason + "\n"
 	}
+	if refusal := s.Refusals[n.ID]; refusal != "" {
+		text += "\n\n" + jormungandr.Refusal(refusal)
+	}
 	var before string
 	if n.ReadOnly {
 		if before, err = snapshot(ctx, r, n.Repo); err != nil {
@@ -171,6 +179,7 @@ func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 		return err
 	}
 	delete(s.Reasons, n.ID)
+	delete(s.Refusals, n.ID)
 	s.Summaries[n.ID] = res.Summary
 	return nil
 }
```

Apply to `internal/engine/loop.go`:

```diff
diff --git a/internal/engine/loop.go b/internal/engine/loop.go
index 45f7c09..b1cdfb9 100644
--- a/internal/engine/loop.go
+++ b/internal/engine/loop.go
@@ -41,6 +41,7 @@ func runLoop(ctx context.Context, r *run.Run, n schema.Node) error {
 	switch out.Kind {
 	case jormungandr.Passed:
 		delete(s.Reasons, n.ID)
+		delete(s.Refusals, n.ID)
 		s.Summaries[n.ID] = fmt.Sprintf("passed in attempt %d of %d with %d minor finding(s) open", out.Attempts, rec.State.Limit, len(rec.State.Book.Open()))
 		return r.Log(gungnir.Event{Name: gungnir.EventLoopAttempt, Node: n.ID, Attempt: out.Attempts, Result: "passed"})
 	case jormungandr.Capped:
@@ -111,7 +112,7 @@ func (l *loopSteps) Implement(ctx context.Context, attempt int, in jormungandr.I
 	if err != nil {
 		return err
 	}
-	text += "\n\n" + jormungandr.Feedback(in.Open, in.LastFailure, r.State.Reasons[n.ID])
+	text += "\n\n" + jormungandr.Feedback(in.Open, in.LastFailure, r.State.Reasons[n.ID]) + jormungandr.Refusal(r.State.Refusals[n.ID])
 	started := func() error {
 		return r.Log(gungnir.Event{Name: gungnir.EventLoopAttempt, Node: n.ID, Attempt: attempt,
 			Result: fmt.Sprintf("attempt %d of %d starts with %d finding(s) open", attempt, l.st.Limit, len(in.Open))})
```

Write `internal/engine/returns.go`:

```go
package engine

import (
	"fmt"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
)

// sentBack is a node whose refusal went back into an earlier node: Position already points at that node
// and run.json is saved, so the walk goes on from there. It is not a failure.
type sentBack struct{ to string }

func (s *sentBack) Error() string { return "sent back to " + s.to }

// sendBack lets node n's refusal go back into the earlier node n names with back_to (spec §4.5): the merge
// gate that finds the base moved, a pointer move whose checks fail, a plan with tasks that aren't ready.
// The refusal is the target's input for its next attempt, a loop gets another full set of attempts with
// its findings, and every loop between the target and n starts over, since the work under it changes when
// the target runs again. It happens at most n.Returns times; after that, or with no back_to, it reports
// false and the node fails as it always did. It returns a *sentBack when the refusal went back.
func sendBack(r *run.Run, n schema.Node, refusal string) (bool, error) {
	s := r.State
	if n.BackTo == "" || s.Returns[n.ID] >= n.Returns {
		return false, nil
	}
	nodes := r.Nodes()
	at, to := indexOf(nodes, n.ID), indexOf(nodes, n.BackTo)
	if at < 0 || to < 0 || to >= at {
		return false, fmt.Errorf("node %s can't go back to %q: it is not an earlier node of the run", n.ID, n.BackTo)
	}
	s.Returns[n.ID]++
	if err := r.Log(gungnir.Event{Name: gungnir.EventNodeReturned, Node: n.ID, Attempt: s.Returns[n.ID], Task: n.Task,
		Result: fmt.Sprintf("back to %s, %d of %d", n.BackTo, s.Returns[n.ID], n.Returns), Note: firstLine(refusal)}); err != nil {
		return false, err
	}
	target := nodes[to]
	s.Refusals[target.ID] = refusal
	for _, m := range nodes[to+1 : at] {
		if m.Kind == schema.KindLoop {
			delete(s.Loops, m.ID)
		}
	}
	if target.Kind == schema.KindLoop {
		if rec := s.Loops[target.ID]; rec != nil {
			rec.State.Reopen(loopConfig(target))
			rec.Escalation = nil
		}
	}
	s.Position, s.Pending, s.PendingGate = to, "", ""
	if err := r.Save(); err != nil {
		return false, err
	}
	return true, &sentBack{to: target.ID}
}
```

Apply to `internal/engine/stages.go`:

```diff
diff --git a/internal/engine/stages.go b/internal/engine/stages.go
index adf28c5..386c7f7 100644
--- a/internal/engine/stages.go
+++ b/internal/engine/stages.go
@@ -41,6 +41,9 @@ func runTasks(ctx context.Context, r *run.Run, n schema.Node) error {
 		if err := r.Log(ev); err != nil {
 			return err
 		}
+		if sent, err := sendBack(r, n, refusal); sent || err != nil {
+			return err
+		}
 		return &nodeFailure{errors.New(refusal)}
 	}
 	s := r.State
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index f2bf8c4..5bb11c2 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -674,7 +674,7 @@ func record(project, dir, id string, setup *Setup) (*Run, error) {
 		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles(setup), Skills: setup.Skills,
 		Root: setup.Root, ProjectPath: setup.ProjectPath, Leaves: map[string]LeafRecord{},
 		Attempts: map[string]int{}, Reasons: map[string]string{}, Summaries: map[string]string{},
-		Waived: map[string]bool{}, Warned: map[string]bool{}, Loops: map[string]*LoopRecord{}, Created: now, Updated: now,
+		Waived: map[string]bool{}, Warned: map[string]bool{}, Loops: map[string]*LoopRecord{}, Returns: map[string]int{}, Refusals: map[string]string{}, Created: now, Updated: now,
 	}}
 	started := gungnir.Event{Name: gungnir.EventRunStarted, Mode: setup.Mode, ConfigHash: setup.ConfigSHA256,
 		Realm: setup.Lead.Name, RealmVersion: setup.Lead.Version, Note: realmNote(setup.Realms)}
```

Apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index ecd5dd2..b82ac06 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -91,6 +91,8 @@ type State struct {
 	Features     []schema.FeatureRecord `json:"features,omitempty"`      // the plan's tasks in the order they are built, once the tasks node has run
 	PlanSource   string                 `json:"plan_source,omitempty"`   // the tasks.md they came from, relative to the project
 	PlanSHA256   string                 `json:"plan_sha256,omitempty"`   // that file as Odin read it
+	Returns      map[string]int         `json:"returns,omitempty"`       // node id: how many times its refusal went back into an earlier node
+	Refusals     map[string]string      `json:"refusals,omitempty"`      // node id: what a later step refused, for the node's next attempt
 	Ledger       ledger.Anchor          `json:"ledger"`
 	Error        string                 `json:"error,omitempty"`
 	Exec         *ExecProcess           `json:"exec,omitempty"` // the exec node running now, if any
@@ -214,6 +216,12 @@ func LoadState(dir string) (*State, error) {
 	if s.Loops == nil {
 		s.Loops = map[string]*LoopRecord{}
 	}
+	if s.Returns == nil {
+		s.Returns = map[string]int{}
+	}
+	if s.Refusals == nil {
+		s.Refusals = map[string]string{}
+	}
 	if s.Leaves == nil {
 		s.Leaves = map[string]LeafRecord{}
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T178: a foreach node becomes each task's shape in the task's leaf and realm, and each task is tracked from todo to done

Spec §4.2 and §7.3: the per-task graph. The foreach node, when the walk reaches it, takes every leaf the tasks work in into the run and is replaced by its tasks' nodes; a task is todo, doing, then done.

**Files (in `odin`):**
- Create: `internal/engine/foreach_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/stages.go`, `internal/run/run.go`, `internal/run/state.go`

**Interfaces:**
- Produces: `(*Run).Expand(ctx, id)`, `(*Setup).NodesFor(state)`, `State.Expanded`; `Run.Nodes()` returns the expanded list, and a resume makes the same nodes from the recorded tasks (`State.check` uses it). `engine.expandForeach` fails a foreach with no plan, a task in a leaf the project lacks and a realm with no recipe, and records nothing then. `Prepare` checks a body's roles and its reviewers' prompts (the lead realm's); the prompt and checks of a leaf's loop come from its realm, where `Expand` finds them.
- `settleTasks` keeps each task's status, features.json and `task_started` / `task_done` lines in step with Position.

**Acceptance criteria:**
- [ ] Two tasks in two leaves of two realms each run their shape in their leaf with their realm's implementer prompt; the work lands on each leaf's main and the project points at it; statuses go todo, doing, done.
- [ ] A run stopped at the first task's feature gate resumes with the same nodes and finishes the rest.
- [ ] A foreach with no plan, and a task whose realm offers no recipe, fail the node.

**Named test:** `go test ./internal/engine -run 'TestEveryTaskRunsItsShapeInItsLeafWithTheRecipeOfItsRealm|TestAResumeMakesTheSameNodesAndGoesOnWhereTheRunStopped|TestAForeachNodeWithNoPlanFailsInsteadOfDoingNothing|TestATaskInALeafWhoseRealmOffersNoRecipeFailsTheNode'` in `odin`. **Layer:** `odin`. **Size:** M (364). **Depends on:** v0-T172, v0-T173, v0-T175, v0-T176.

- [ ] **Step 1:** write the tests.

Write `internal/engine/foreach_test.go`:

```go
package engine

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
)

// recipeRealm is a realm with a leaf recipe: a template, an implementer prompt and one check, which passes
// when the leaf holds file.
func recipeRealm(name, version, file, prompt string) realmFiles {
	return realmFiles{name: name, version: version,
		pack:  "checks:\n  unit: [sh, -c, \"test -f " + file + "\"]\nleaf:\n  description: the " + name + " leaf\n  template: templates/leaf\n  first_commit: [LICENSE]\n  implementer: prompts/implementer.md\n  checks: [unit]\n",
		files: map[string]string{"templates/leaf/LICENSE": "licence\n", "prompts/implementer.md": prompt + "\n", "p.md": "Lead prompt.\n"}}
}

const taskShape = `  - { id: ready, kind: tasks, from: tasks.md }
  - id: tasks
    kind: foreach
    over: tasks
    nodes:
      - { id: implement, kind: loop, realm: leaf, role: implementer }
      - { id: feature-gate, kind: gate, gate: feature }
      - { id: land, kind: merge, realm: leaf }
      - { id: move, kind: pointer, realm: leaf }
`

// writeStep is the script entry of an implementer that writes file.
func writeStep(node, file string) string {
	return "  " + node + ":\n    - actions: [ { write: { path: " + file + ", content: \"done\\n\" } } ]\n      result: { status: ok, summary: wrote " + file + " }\n"
}

func galleryRun(t *testing.T, mode, script string) *run.Run {
	t.Helper()
	r := startRealms(t, realmsSetup{mode: mode, nodes: taskShape, script: "steps:\n" + script,
		realms: []realmFiles{recipeRealm("midgard-react", "0.1.0", "web.txt", "Web implementer prompt."), recipeRealm("helheim-go", "0.2.0", "api.txt", "API implementer prompt.")},
		leaves: map[string]string{"repos/api": "helheim-go", "repos/web": "midgard-react"}})
	plan := "# Tasks\n\n" + taskMD("p-T1", "repos/api", "S", "nothing") + taskMD("p-T2", "repos/web", "M", "p-T1")
	if err := os.WriteFile(filepath.Join(r.Project, "tasks.md"), []byte(plan), 0o644); err != nil {
		t.Fatal(err)
	}
	return r
}

func TestEveryTaskRunsItsShapeInItsLeafWithTheRecipeOfItsRealm(t *testing.T) {
	r := galleryRun(t, "key-points", writeStep("p-t1-implement", "api.txt")+writeStep("p-t2-implement", "web.txt"))
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if got := len(r.Nodes()); got != 1+2*4 || !r.State.Expanded["tasks"] {
		t.Errorf("the run has %d nodes (expanded %v); want the tasks node and a shape of four for each of two tasks", got, r.State.Expanded)
	}
	if got := promptOf(t, r, "p-t1-implement-1"); !strings.Contains(got, "API implementer prompt.") || strings.Contains(got, "Web implementer") {
		t.Errorf("task 1's implementer was given:\n%s", got)
	}
	if got := promptOf(t, r, "p-t2-implement-1"); !strings.Contains(got, "Web implementer prompt.") {
		t.Errorf("task 2's implementer was given:\n%s", got)
	}
	for leaf, file := range map[string]string{"repos/api": "api.txt", "repos/web": "web.txt"} {
		l, err := r.Leaf(leaf)
		if err != nil {
			t.Fatal(err)
		}
		if body, err := l.Git(context.Background(), "show", "main:"+file); err != nil || body != "done" {
			t.Errorf("%s: main:%s = %q, %v; the task's work is landed on the leaf's main", leaf, file, body, err)
		}
		if rec := r.State.Leaves[leaf]; rec.Branch != run.Branch(r.State.ID) {
			t.Errorf("%s record = %+v", leaf, rec)
		}
	}
	for _, f := range r.State.Features {
		if f.Status != schema.TaskDone {
			t.Errorf("task %s is %s", f.ID, f.Status)
		}
	}
	saved, err := schema.LoadFeatures(filepath.Join(r.Project, ".factory", "features.json"))
	if err != nil || saved.Tasks[0].Status != schema.TaskDone || saved.Tasks[1].Status != schema.TaskDone {
		t.Errorf("features.json = %+v, %v", saved, err)
	}
	if got := strings.Join(taskEvents(t, r), ", "); got != "task_started p-t1, task_done p-t1, task_started p-t2, task_done p-t2" {
		t.Errorf("task events = %s; task 1 starts and is done before task 2 starts", got)
	}
}

// taskEvents lists the task_started, task_done and task_blocked lines of the ledger, with their task.
func taskEvents(t *testing.T, r *run.Run) []string {
	t.Helper()
	var out []string
	for _, line := range strings.Split(strings.TrimSpace(ledgerText(t, r)), "\n") {
		var e struct {
			Event string `json:"event"`
			Task  string `json:"ygg.task.id"`
		}
		if err := json.Unmarshal([]byte(line), &e); err != nil {
			t.Fatal(err)
		}
		if strings.HasPrefix(e.Event, "task_") {
			out = append(out, e.Event+" "+e.Task)
		}
	}
	return out
}

func TestAResumeMakesTheSameNodesAndGoesOnWhereTheRunStopped(t *testing.T) {
	r := galleryRun(t, "step-by-step", writeStep("p-t1-implement", "api.txt")+writeStep("p-t2-implement", "web.txt"))
	ctx := context.Background()
	out, err := Advance(ctx, r)
	if err != nil || out.Status != run.StatusStopped || out.Gate != "p-t1-feature-gate" {
		t.Fatalf("Advance() = %+v, %v; want a stop at task 1's feature gate", out, err)
	}
	if r.State.Features[0].Status != schema.TaskDoing || r.State.Features[1].Status != schema.TaskTodo {
		t.Errorf("statuses while task 1 waits: %+v", r.State.Features)
	}
	id, project := r.State.ID, r.Project
	r.Close()
	r, err = run.Open(ctx, project, id, "")
	if err != nil {
		t.Fatalf("Open() = %v", err)
	}
	defer r.Close()
	if len(r.Nodes()) != 9 || r.Nodes()[r.State.Position].ID != "p-t1-feature-gate" {
		t.Fatalf("after Open: %d nodes, position %d", len(r.Nodes()), r.State.Position)
	}
	if err := Approve(ctx, r, "p-t1-feature-gate", ""); err != nil {
		t.Fatal(err)
	}
	out, err = Advance(ctx, r)
	if err != nil || out.Status != run.StatusStopped || out.Gate != "p-t2-feature-gate" {
		t.Fatalf("Advance() = %+v, %v; want task 1 done and a stop at task 2's feature gate", out, err)
	}
	if r.State.Features[0].Status != schema.TaskDone || r.State.Features[1].Status != schema.TaskDoing {
		t.Errorf("statuses: %+v", r.State.Features)
	}
	if err := Approve(ctx, r, "p-t2-feature-gate", ""); err != nil {
		t.Fatal(err)
	}
	if out, err := Advance(ctx, r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if r.State.Features[1].Status != schema.TaskDone {
		t.Errorf("the last task, whose last node is a move, is %s", r.State.Features[1].Status)
	}
}

func TestAForeachNodeWithNoPlanFailsInsteadOfDoingNothing(t *testing.T) {
	r := startRealms(t, realmsSetup{nodes: taskShape[strings.Index(taskShape, "  - id: tasks"):], script: "steps: {}\n",
		realms: []realmFiles{recipeRealm("midgard-react", "0.1.0", "web.txt", "Web.")}, leaves: map[string]string{"repos/web": "midgard-react"}})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "a tasks node must come before it") {
		t.Errorf("Advance() = %+v, %v", out, err)
	}
}

func TestATaskInALeafWhoseRealmOffersNoRecipeFailsTheNode(t *testing.T) {
	lead := recipeRealm("midgard-react", "0.1.0", "web.txt", "Web.")
	bare := realmFiles{name: "notes", version: "0.1.0"}
	r := startRealms(t, realmsSetup{nodes: taskShape, script: "steps: {}\n", realms: []realmFiles{lead, bare},
		leaves: map[string]string{"repos/web": "midgard-react", "repos/docs": "notes"}})
	plan := "# Tasks\n\n" + taskMD("p-T1", "repos/docs", "S", "nothing")
	os.WriteFile(filepath.Join(r.Project, "tasks.md"), []byte(plan), 0o644)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "offers no leaf recipe") {
		t.Errorf("Advance() = %+v, %v", out, err)
	}
	if r.State.Expanded["tasks"] {
		t.Error("a failed expansion was recorded")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/foreach_test.go:57:53: r.State.Expanded undefined (type *run.State has no field or method Expanded)
internal/engine/foreach_test.go:58:126: r.State.Expanded undefined (type *run.State has no field or method Expanded)
internal/engine/foreach_test.go:172:13: r.State.Expanded undefined (type *run.State has no field or method Expanded)
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index ce92f03..a21ed62 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -56,8 +56,14 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 	if err := r.Save(); err != nil {
 		return Outcome{}, err
 	}
-	nodes := r.Nodes()
-	for s.Position < len(nodes) {
+	for {
+		nodes := r.Nodes()
+		if err := settleTasks(r, nodes); err != nil {
+			return Outcome{}, err
+		}
+		if s.Position >= len(nodes) {
+			break
+		}
 		n := nodes[s.Position]
 		var stop bool
 		var err error
@@ -76,10 +82,13 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 			err = runPointer(ctx, r, n)
 		case schema.KindTasks:
 			err = runTasks(ctx, r, n)
+		case schema.KindForeach:
+			err = expandForeach(ctx, r, n)
 		}
 		var sb *sentBack
-		if errors.As(err, &sb) {
-			continue // the refusal went back: Position points at the node it went back to
+		var ex *expanded
+		if errors.As(err, &sb) || errors.As(err, &ex) {
+			continue // Position already points at the node to run next
 		}
 		var nf *nodeFailure
 		if errors.As(err, &nf) {
```

Apply to `internal/engine/stages.go`:

```diff
diff --git a/internal/engine/stages.go b/internal/engine/stages.go
index 386c7f7..3e59df3 100644
--- a/internal/engine/stages.go
+++ b/internal/engine/stages.go
@@ -143,3 +143,62 @@ func writeFeatures(r *run.Run) error {
 	f := &schema.Features{Run: s.ID, Source: s.PlanSource, SourceSHA256: s.PlanSHA256, Tasks: slices.Clone(s.Features)}
 	return f.Save(filepath.Join(r.Project, filepath.FromSlash(FeaturesFile)))
 }
+
+// expanded is a foreach node that became the nodes of its tasks: Position now points at the first of them.
+type expanded struct{}
+
+func (*expanded) Error() string { return "expanded" }
+
+// expandForeach turns foreach node n into its task shape once for each task the plan holds, in the leaf and
+// the realm each task names (spec §4.2, change realm-leaf-naming). A plan the tasks node has not read, or a
+// task whose leaf the project lacks, fails the node.
+func expandForeach(ctx context.Context, r *run.Run, n schema.Node) error {
+	if len(r.State.Features) == 0 {
+		return &nodeFailure{fmt.Errorf("%s repeats its nodes for every task, and the run has no plan yet: a tasks node must come before it", n.ID)}
+	}
+	if err := r.Expand(ctx, n.ID); err != nil {
+		return &nodeFailure{err}
+	}
+	return &expanded{}
+}
+
+// settleTasks keeps the record of each task in step with Position: a task is doing once the first node of
+// its shape is next, and done once the walk has left its last node. It writes features.json when a task
+// changes, and a line in the ledger.
+func settleTasks(r *run.Run, nodes []schema.Node) error {
+	s := r.State
+	if s.Position > 0 && s.Position <= len(nodes) {
+		if prev := nodes[s.Position-1]; prev.Task != "" && (s.Position == len(nodes) || nodes[s.Position].Task != prev.Task) {
+			if err := setTask(r, prev.Task, schema.TaskDone, gungnir.EventTaskDone); err != nil {
+				return err
+			}
+		}
+	}
+	if s.Position < len(nodes) && nodes[s.Position].Task != "" {
+		return setTask(r, nodes[s.Position].Task, schema.TaskDoing, gungnir.EventTaskStarted)
+	}
+	return nil
+}
+
+// setTask moves the task with the node id slug to status, if that moves it forward: todo to doing, and
+// todo or doing to done. A task that is already done, or blocked, stays as it is.
+func setTask(r *run.Run, slug string, to schema.TaskStatus, event gungnir.EventName) error {
+	s := r.State
+	i := slices.IndexFunc(s.Features, func(f schema.FeatureRecord) bool { return f.Slug() == slug })
+	if i < 0 {
+		return nil
+	}
+	from := s.Features[i].Status
+	forward := (to == schema.TaskDoing && from == schema.TaskTodo) || (to == schema.TaskDone && (from == schema.TaskTodo || from == schema.TaskDoing))
+	if !forward {
+		return nil
+	}
+	s.Features[i].Status = to
+	if err := writeFeatures(r); err != nil {
+		return err
+	}
+	if err := r.Log(gungnir.Event{Name: event, Task: slug, Note: s.Features[i].ID}); err != nil {
+		return err
+	}
+	return r.Save()
+}
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 5bb11c2..94720e3 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -24,6 +24,7 @@ import (
 	"github.com/ouroboric-dev/odin/internal/leaf"
 	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/lock"
+	"github.com/ouroboric-dev/odin/internal/plan"
 	"github.com/ouroboric-dev/odin/internal/realm"
 	"github.com/ouroboric-dev/odin/internal/remote"
 	"github.com/ouroboric-dev/odin/internal/tree"
@@ -224,6 +225,8 @@ func (s *Setup) checkNode(ctx context.Context, graphPath string, n schema.Node)
 	switch {
 	case n.Kind == schema.KindGate, n.Kind == schema.KindPublish, n.Kind == schema.KindTasks, n.Kind == schema.KindInit:
 		return nil // they work in the project, not in a leaf
+	case n.Kind == schema.KindForeach:
+		return s.checkBody(graphPath, n)
 	}
 	if n.Repo == "" {
 		return fmt.Errorf("%s: node %s names no repo; every node that does work runs in a repo of the project", graphPath, n.ID)
@@ -261,6 +264,42 @@ func (s *Setup) checkNode(ctx context.Context, graphPath string, n schema.Node)
 	return nil
 }
 
+// checkBody checks the roles and prompts of a foreach node's body, which run in leaves the project
+// decides later: a role must be in factory.yaml, a reviewer's prompt must be in the lead realm, and the
+// prompt and checks of a leaf's loop come from the realm of the leaf, where Expand finds them.
+func (s *Setup) checkBody(graphPath string, fe schema.Node) error {
+	for _, n := range fe.Body {
+		switch n.Kind {
+		case schema.KindAgent:
+			if err := s.checkSession(graphPath, n.ID, n.Role, n.Prompt); err != nil {
+				return err
+			}
+		case schema.KindLoop:
+			if _, ok := s.Config.Roles[n.Role]; !ok {
+				return fmt.Errorf("%s: node %s uses role %s, which %s doesn't define", graphPath, n.ID, n.Role, s.ConfigPath)
+			}
+			if s.Agents[n.Role] == nil {
+				a, err := agents.New(s.Config.Roles[n.Role], filepath.Dir(s.ConfigPath), agents.Options{Privacy: s.Config.Privacy})
+				if err != nil {
+					return fmt.Errorf("role %s: %w", n.Role, err)
+				}
+				s.Agents[n.Role] = a
+			}
+			for _, rv := range n.Reviewers {
+				if err := s.checkSession(graphPath, fe.ID+"-"+n.ID+"-"+rv.ID, rv.Role, rv.Prompt); err != nil {
+					return err
+				}
+			}
+		}
+		for _, c := range n.Acceptance {
+			if _, ok := s.Pack.Checks[c]; !ok {
+				return fmt.Errorf("%s: node %s runs check %s, which the pack doesn't define", graphPath, n.ID, c)
+			}
+		}
+	}
+	return nil
+}
+
 // checkSession checks that a session of node (a node, or a loop's reviewer) can run: its prompt file
 // is in the realm and its role is in factory.yaml, whose adapter is built once per role.
 func (s *Setup) checkSession(graphPath, node, role, prompt string) error {
@@ -409,10 +448,73 @@ type Run struct {
 	Saved    []string        // one note per leaf whose discarded changes Open saved to a ref, or discarded unsaved, before resetting it
 	SetAside []string        // the notes of Saved from the set-aside of a session whose spend the journal couldn't take, for its gate (review I4)
 	Sandbox  gungnir.Sandbox // runs the leaves' commands; nil when the config has no sandbox section
+	nodes    []schema.Node   // the nodes of the run, with foreach nodes expanded; see Nodes
+}
+
+// Nodes returns the nodes the run walks, in order: the graph's, with each foreach node that has been
+// expanded replaced by the nodes of its tasks. Position indexes this list.
+func (r *Run) Nodes() []schema.Node {
+	if r.nodes == nil {
+		r.nodes = r.Setup.Graph.Nodes
+	}
+	return r.nodes
+}
+
+// Expand replaces foreach node id by its task shape for each task of the plan, in the leaf and the realm
+// each task names, and every leaf the tasks work in becomes part of the run. Position is not changed: it
+// then points at the first node of the first task's shape. The expansion is recorded in run.json, so a
+// resume makes the same nodes.
+func (r *Run) Expand(ctx context.Context, id string) error {
+	s := r.State
+	for _, f := range s.Features {
+		if err := r.AddLeaf(ctx, f.Layer); err != nil {
+			return fmt.Errorf("task %s works in %s: %w", f.ID, f.Layer, err)
+		}
+	}
+	s.Expanded[id] = true
+	nodes, err := r.Setup.NodesFor(s)
+	if err != nil {
+		delete(s.Expanded, id)
+		return err
+	}
+	r.nodes = nodes
+	return r.Save()
+}
+
+// NodesFor returns the nodes of the run in the state st: the graph's, with each foreach node that st has
+// expanded replaced by its task shape once for each task, in the order the tasks are built.
+func (s *Setup) NodesFor(st *State) ([]schema.Node, error) {
+	var out []schema.Node
+	for _, n := range s.Graph.Nodes {
+		if n.Kind != schema.KindForeach || !st.Expanded[n.ID] {
+			out = append(out, n)
+			continue
+		}
+		fs := make([]schema.Feature, len(st.Features))
+		for i, f := range st.Features {
+			fs[i] = f.Feature
+		}
+		ex, err := plan.Expand(n, fs, s.Graph, s.recipeOf)
+		if err != nil {
+			return nil, err
+		}
+		out = append(out, ex...)
+	}
+	return out, nil
 }
 
-// Nodes returns the nodes the run walks, in order. Position indexes this list.
-func (r *Run) Nodes() []schema.Node { return r.Setup.Graph.Nodes }
+// recipeOf says what the realm of the leaf at layer offers its tasks.
+func (s *Setup) recipeOf(layer string) (plan.Recipe, error) {
+	if u := s.Project.Umbrella; u == nil || u.Children[layer].Kind != schema.ChildLeaf {
+		return plan.Recipe{}, fmt.Errorf("the project has no leaf %s", layer)
+	}
+	r := s.RealmOf(layer)
+	rec := plan.Recipe{Realm: r.Name}
+	if r.Pack.Leaf != nil {
+		rec.Implementer, rec.Checks = r.Pack.Leaf.Implementer, r.Pack.Leaf.Checks
+	}
+	return rec, nil
+}
 
 // Meter returns the budget of this run: its caps against its own usage and the day's journal.
 func (r *Run) Meter() *budget.Meter {
@@ -674,7 +776,7 @@ func record(project, dir, id string, setup *Setup) (*Run, error) {
 		Brief: setup.Brief, BriefSHA256: setup.BriefSHA256, Roles: roles(setup), Skills: setup.Skills,
 		Root: setup.Root, ProjectPath: setup.ProjectPath, Leaves: map[string]LeafRecord{},
 		Attempts: map[string]int{}, Reasons: map[string]string{}, Summaries: map[string]string{},
-		Waived: map[string]bool{}, Warned: map[string]bool{}, Loops: map[string]*LoopRecord{}, Returns: map[string]int{}, Refusals: map[string]string{}, Created: now, Updated: now,
+		Waived: map[string]bool{}, Warned: map[string]bool{}, Loops: map[string]*LoopRecord{}, Expanded: map[string]bool{}, Returns: map[string]int{}, Refusals: map[string]string{}, Created: now, Updated: now,
 	}}
 	started := gungnir.Event{Name: gungnir.EventRunStarted, Mode: setup.Mode, ConfigHash: setup.ConfigSHA256,
 		Realm: setup.Lead.Name, RealmVersion: setup.Lead.Version, Note: realmNote(setup.Realms)}
@@ -845,6 +947,10 @@ func open(ctx context.Context, project, dir string, mode gungnir.Mode, h Hooks)
 		s.Exec = nil
 	}
 	r := &Run{Project: setup.Project.Dir, Dir: dir, State: s, Setup: setup, Ledger: l, unlock: func() {}}
+	if r.nodes, err = setup.NodesFor(s); err != nil { // State.check made it once, so this holds
+		l.Close()
+		return nil, err
+	}
 	// The spends the journal missed are written before the run goes on, so the day's cap counts them,
 	// and before anything else changes, so a refusal while the journal is still broken leaves the
 	// sandboxes and the leaves as they are. run.json is written as it was loaded, less what was
```

Apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index b82ac06..7f97ccb 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -91,6 +91,7 @@ type State struct {
 	Features     []schema.FeatureRecord `json:"features,omitempty"`      // the plan's tasks in the order they are built, once the tasks node has run
 	PlanSource   string                 `json:"plan_source,omitempty"`   // the tasks.md they came from, relative to the project
 	PlanSHA256   string                 `json:"plan_sha256,omitempty"`   // that file as Odin read it
+	Expanded     map[string]bool        `json:"expanded,omitempty"`      // foreach node ids already expanded into the nodes of each task
 	Returns      map[string]int         `json:"returns,omitempty"`       // node id: how many times its refusal went back into an earlier node
 	Refusals     map[string]string      `json:"refusals,omitempty"`      // node id: what a later step refused, for the node's next attempt
 	Ledger       ledger.Anchor          `json:"ledger"`
@@ -216,6 +217,9 @@ func LoadState(dir string) (*State, error) {
 	if s.Loops == nil {
 		s.Loops = map[string]*LoopRecord{}
 	}
+	if s.Expanded == nil {
+		s.Expanded = map[string]bool{}
+	}
 	if s.Returns == nil {
 		s.Returns = map[string]int{}
 	}
@@ -331,7 +335,10 @@ func (s *State) checkRealms(setup *Setup) error {
 // check refuses a run.json whose position, pending node or leaves don't fit setup's graph and
 // tree. Odin wrote it, but a hand-edited file must not crash the engine.
 func (s *State) check(setup *Setup) error {
-	nodes := setup.Graph.Nodes
+	nodes, err := setup.NodesFor(s)
+	if err != nil {
+		return fmt.Errorf("the tasks the run expanded no longer fit the project: %w", err)
+	}
 	if s.Position < 0 || s.Position > len(nodes) {
 		return fmt.Errorf("position %d is outside the graph's %d nodes", s.Position, len(nodes))
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T179: a pointer move's ledger lines close the attempts they open, and a waiver lasts one move (B-010)

Backlog B-010, three gaps around landings, which merge-gate loops and more leaves make matter: a shrink-guard stop never closes the attempt its `node_started` opened; a pointer move that committed but whose record was lost has no `pointer_moved` line on the next attempt; and a waiver outlives a failed move.

**Files (in `odin`):**
- Create: `internal/engine/ledgergaps_test.go`
- Modify: `internal/engine/land.go`, `internal/ledger/ledger.go`, `internal/ledger/ledger_test.go`

**Interfaces:**
- Produces: `ledger.Has(path, match) (bool, error)`; in `runPointer`: `node_failed` before the shrink-guard stop; on an attempt after the first, a pointer already at the target with no `pointer_moved` line of the node gets one that says so; the waiver is cleared whatever became of the move.

**Acceptance criteria:**
- [ ] A shrink-guard stop's lines for the move are `node_started`, the check, `node_failed`, `gate_pending`.
- [ ] An approved waiver followed by a failed move is gone, and the next move meets the guard again.
- [ ] A move an earlier attempt made and the ledger lacks is logged on the next attempt.

**Named test:** `go test ./internal/engine ./internal/ledger -run 'TestAShrinkGuardStopClosesTheAttemptTheLedgerOpened|TestAWaiverIsForOneMoveWhateverBecomesOfIt|TestAMoveThatCommittedBeforeTheRunRecordedItIsLoggedOnTheNextAttempt|TestHasFindsAnEventThatWasWritten'` in `odin`. **Layer:** `odin`. **Size:** M (183). **Depends on:** v0-T178.

- [ ] **Step 1:** write the tests.

Write `internal/engine/ledgergaps_test.go`:

```go
package engine

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
)

// shrunkRun starts a run whose pointer move meets a REPOS.md that kept 1 of its 10 rows; the move's
// acceptance check passes while ok.flag is in the project.
func shrunkRun(t *testing.T) *run.Run {
	t.Helper()
	nodes := build + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
		"  - { id: move, kind: pointer, repo: repos/app, acceptance: [flag], generated: [REPOS.md] }\n"
	r := startPack(t, "unattended", "", packChecks+"  flag: [test, -f, ok.flag]\n", nodes, okScript)
	if err := os.WriteFile(filepath.Join(r.Project, "ok.flag"), nil, 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(r.Project, "REPOS.md"), []byte(strings.Repeat("| row |\n", 10)), 0o644); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"add", "REPOS.md"}, {"commit", "-q", "-m", "REPOS.md"}} {
		if _, err := git.Run(bg, r.Project, args...); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(r.Project, "REPOS.md"), []byte("| one |\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return r
}

// nodeEvents lists the events of one node in the ledger as "event attempt".
func nodeEvents(t *testing.T, r *run.Run, node string) []string {
	t.Helper()
	var out []string
	for _, line := range strings.Split(strings.TrimSpace(ledgerText(t, r)), "\n") {
		var e struct {
			Event   string `json:"event"`
			Node    string `json:"ygg.node.id"`
			Attempt int    `json:"ygg.attempt"`
		}
		if err := json.Unmarshal([]byte(line), &e); err != nil {
			t.Fatal(err)
		}
		if e.Node == node {
			out = append(out, e.Event+" "+string(rune('0'+e.Attempt)))
		}
	}
	return out
}

func TestAShrinkGuardStopClosesTheAttemptTheLedgerOpened(t *testing.T) {
	r := shrunkRun(t)
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateShrinkGuard {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if got := strings.Join(nodeEvents(t, r, "move"), ", "); got != "node_started 1, check_result 1, node_failed 1, gate_pending 1" {
		t.Errorf("the move's ledger lines = %s; the attempt that started must end", got)
	}
}

func TestAWaiverIsForOneMoveWhateverBecomesOfIt(t *testing.T) {
	r := shrunkRun(t)
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusStopped {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if err := Approve(bg, r, "move", "the index shrank on purpose"); err != nil {
		t.Fatal(err)
	}
	if !r.State.Waived["move"] {
		t.Fatal("approving the shrink-guard stop did not waive the next move")
	}
	os.Remove(filepath.Join(r.Project, "ok.flag")) // the move now fails its acceptance check, after the guard is skipped
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusFailed {
		t.Fatalf("Advance() = %+v, %v; want the move refused by its acceptance check", out, err)
	}
	if r.State.Waived["move"] {
		t.Error("the waiver outlived the failed move")
	}
	os.WriteFile(filepath.Join(r.Project, "ok.flag"), nil, 0o644)
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateShrinkGuard {
		t.Errorf("Advance() = %+v, %v (pending %s); the next move meets the guard again, since the waiver was for one move", out, err, r.State.PendingGate)
	}
}

func TestAMoveThatCommittedBeforeTheRunRecordedItIsLoggedOnTheNextAttempt(t *testing.T) {
	nodes := build + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
		"  - { id: pointer-gate, kind: gate, gate: pointer }\n  - { id: move, kind: pointer, repo: repos/app }\n"
	r := startPack(t, "key-points", "gates:\n  pointer: stop\n", packChecks, nodes, okScript)
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusStopped || out.Gate != "pointer-gate" {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	// As if an earlier attempt of the move committed, and the process died before the ledger got the line.
	l, _ := r.Leaf("repos/app")
	main, _ := l.Rev(bg, "main")
	for _, args := range [][]string{{"update-index", "--cacheinfo", "160000," + main + ",repos/app"}, {"commit", "-q", "-m", "the move an earlier attempt made"}} {
		if _, err := git.Run(bg, r.Project, args...); err != nil {
			t.Fatal(err)
		}
	}
	r.State.Attempts["move"] = 1
	if err := Approve(bg, r, "pointer-gate", ""); err != nil {
		t.Fatal(err)
	}
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if text := ledgerText(t, r); !strings.Contains(text, `"event":"pointer_moved"`) || !strings.Contains(text, "an earlier attempt moved it and the run didn't record it") {
		t.Errorf("the ledger lacks the move the earlier attempt made:\n%s", text)
	}
	// A move that was already there on the node's first attempt was not this node's: nothing is logged.
}
```

Apply to `internal/ledger/ledger_test.go`:

```diff
diff --git a/internal/ledger/ledger_test.go b/internal/ledger/ledger_test.go
index 6d96a34..b29a683 100644
--- a/internal/ledger/ledger_test.go
+++ b/internal/ledger/ledger_test.go
@@ -127,3 +127,20 @@ func TestAppendRefusesAnEventTheSchemaRejects(t *testing.T) {
 		t.Errorf("a refused event moved the head to %d", l.Head().Seq)
 	}
 }
+
+func TestHasFindsAnEventThatWasWritten(t *testing.T) {
+	path, _ := write(t, 2)
+	if ok, err := Has(path, func(e gungnir.Event) bool { return e.Node == "design" && e.Attempt == 2 }); err != nil || !ok {
+		t.Errorf("Has(attempt 2) = %v, %v", ok, err)
+	}
+	if ok, err := Has(path, func(e gungnir.Event) bool { return e.Attempt == 3 }); err != nil || ok {
+		t.Errorf("Has(attempt 3) = %v, %v", ok, err)
+	}
+	if _, err := Has(filepath.Join(t.TempDir(), "none.jsonl"), func(gungnir.Event) bool { return true }); err == nil {
+		t.Error("Has() of a ledger that isn't there = nil error")
+	}
+	os.WriteFile(path, []byte("not json\n"), 0o644)
+	if _, err := Has(path, func(gungnir.Event) bool { return false }); err == nil {
+		t.Error("Has() of a line that isn't an event = nil error")
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/ledger [github.com/ouroboric-dev/odin/internal/ledger.test]
internal/ledger/ledger_test.go:133:16: undefined: Has
internal/ledger/ledger_test.go:136:16: undefined: Has
internal/ledger/ledger_test.go:139:15: undefined: Has
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/land.go`:

```diff
diff --git a/internal/engine/land.go b/internal/engine/land.go
index a85cd41..1d16d84 100644
--- a/internal/engine/land.go
+++ b/internal/engine/land.go
@@ -10,6 +10,7 @@ import (
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/odin/internal/leaf"
+	"github.com/ouroboric-dev/odin/internal/ledger"
 	"github.com/ouroboric-dev/odin/internal/lock"
 	"github.com/ouroboric-dev/odin/internal/merge"
 	"github.com/ouroboric-dev/odin/internal/pointer"
@@ -109,8 +110,16 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 	if errors.As(moveErr, &hs) { // the sandbox broke a hardening rule
 		return hs
 	}
+	// A waiver is for the next move only: whatever came of it, a later move is not waived (backlog B-010).
+	delete(s.Waived, n.ID)
 	var se *shrink.Error
 	if errors.As(moveErr, &se) {
+		// The attempt the node_started line opened closes in the ledger (backlog B-010).
+		fail := gungnir.Event{Name: gungnir.EventNodeFailed, Node: n.ID, Attempt: attempt, Result: moveErr.Error(),
+			DurationMS: time.Since(began).Milliseconds()}
+		if err := r.Log(fail); err != nil {
+			return err
+		}
 		return &hardStop{gate: gungnir.GateShrinkGuard, err: moveErr}
 	}
 	if leaf.IsPolicy(moveErr) { // a check rewrote the leaf's .git or planted a repository
@@ -121,13 +130,28 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 	if moveErr != nil {
 		return failLanding(r, ev, moveErr)
 	}
-	delete(s.Waived, n.ID)
 	if res.Commit != "" {
 		moved := gungnir.Event{Name: gungnir.EventPointerMoved, Node: n.ID, Attempt: attempt, Commit: res.Commit,
 			Note: fmt.Sprintf("%s: %.12s -> %.12s", filepath.Join(parentRepo, child), res.From, res.To)}
 		if err := r.Log(moved); err != nil {
 			return err
 		}
+	} else if attempt > 1 {
+		// The pointer is already there on a later attempt: an earlier attempt moved it, and the ledger may
+		// not have the line, if the process died between the commit and the line (backlog B-010).
+		logged, err := ledger.Has(filepath.Join(r.Dir, "ledger.jsonl"), func(e gungnir.Event) bool {
+			return e.Name == gungnir.EventPointerMoved && e.Node == n.ID
+		})
+		if err != nil {
+			return err
+		}
+		if !logged {
+			moved := gungnir.Event{Name: gungnir.EventPointerMoved, Node: n.ID, Attempt: attempt,
+				Note: fmt.Sprintf("%s: already at %.12s; an earlier attempt moved it and the run didn't record it", filepath.Join(parentRepo, child), res.To)}
+			if err := r.Log(moved); err != nil {
+				return err
+			}
+		}
 	}
 	ev.Result, ev.Commit = "moved "+child, res.Commit
 	if err := r.Log(ev); err != nil {
```

Apply to `internal/ledger/ledger.go`:

```diff
diff --git a/internal/ledger/ledger.go b/internal/ledger/ledger.go
index 0a405ff..026d6ce 100644
--- a/internal/ledger/ledger.go
+++ b/internal/ledger/ledger.go
@@ -135,6 +135,28 @@ func Verify(path string, want Anchor) (Anchor, error) {
 	return head, nil
 }
 
+// Has reports whether any line of the ledger at path is an event for which match is true. It reads the
+// lines as they are and does not check the chain: Verify does that. A line that is not an event is an error.
+func Has(path string, match func(gungnir.Event) bool) (bool, error) {
+	f, err := os.Open(path)
+	if err != nil {
+		return false, err
+	}
+	defer f.Close()
+	sc := bufio.NewScanner(f)
+	sc.Buffer(make([]byte, 0, 64*1024), 4<<20)
+	for n := 1; sc.Scan(); n++ {
+		var e gungnir.Event
+		if err := json.Unmarshal(sc.Bytes(), &e); err != nil {
+			return false, fmt.Errorf("%s:%d: %w", path, n, err)
+		}
+		if match(e) {
+			return true, nil
+		}
+	}
+	return false, sc.Err()
+}
+
 func hash(line []byte) string {
 	s := sha256.Sum256(line)
 	return hex.EncodeToString(s[:])
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T180: a merge gate or pointer move that refuses the work's checks sends it back into the loop that made it

Spec §4.5: "re-run the checks... any failure returns to the loop"; Phase 4 left this to the graph of Phase 5.

**Files (in `odin`):**
- Create: `internal/engine/loopback_test.go`
- Modify: `internal/engine/land.go`

**Interfaces:**
- Produces: `failLanding(r, n, ev, err)` sends the refusal back (v0-T177) when the gate refused because the checks fail on the branch with the base merged in, or a pointer move's checks or acceptance failed. After a merge refusal the leaf's checkpoint is the merged head the checks ran on. A base that does not merge cleanly, a target another process holds and an Odin failure fail the node as before: the implementer cannot fix them.

**Acceptance criteria:**
- [ ] A merge gate whose late check fails sends the work back; the second attempt's prompt carries the refusal; the work lands.
- [ ] A refusal that keeps coming back fails the node after its returns, and nothing of it lands on main.
- [ ] A conflict with the base is not sent back (the implementer is not run again); a pointer move whose acceptance fails goes back and the project then points at main.

**Named test:** `go test ./internal/engine -run 'TestAMergeGateThatRefusesTheChecksSendsTheWorkBackIntoTheLoop|TestARefusalThatKeepsComingBackFailsTheNodeAfterItsReturns|TestABaseThatDoesNotMergeCleanlyIsNotSentBack|TestAPointerMoveWhoseAcceptanceFailsSendsTheWorkBackIntoTheLoop'` in `odin`. **Layer:** `odin`. **Size:** M (145). **Depends on:** v0-T177, v0-T179.

- [ ] **Step 1:** write the tests.

Write `internal/engine/loopback_test.go`:

```go
package engine

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
)

// The checks of these tests: unit passes when the agent wrote out.txt (the loop's ladder), late passes
// only once it also wrote fixed.txt (the merge gate's), and accept does so in the project, with the leaf
// at the pointer's new commit (the pointer's acceptance).
const gateChecks = "checks:\n  unit: [test, -f, out.txt]\n  late: [test, -f, fixed.txt]\n  accept: [test, -f, repos/app/fixed.txt]\n"

const loopOfBuild = "  - { id: build, kind: loop, repo: repos/app, role: planner, prompt: p.md, checks: [unit] }\n"

// fixScript has the implementer write out.txt in attempt 1 and fixed.txt in the attempts after it.
const fixScript = "steps:\n  build:\n" +
	"    - actions: [ { write: { path: out.txt, content: \"done\\n\" } } ]\n      result: { status: ok, summary: wrote out.txt }\n" +
	"    - actions: [ { write: { path: fixed.txt, content: \"done\\n\" } } ]\n      result: { status: ok, summary: wrote fixed.txt }\n" +
	"    - actions: [ { write: { path: more.txt, content: \"done\\n\" } } ]\n      result: { status: ok, summary: wrote more.txt }\n"

func TestAMergeGateThatRefusesTheChecksSendsTheWorkBackIntoTheLoop(t *testing.T) {
	nodes := loopOfBuild + "  - { id: merge, kind: merge, repo: repos/app, checks: [late], back_to: build }\n"
	r := startPack(t, "key-points", "", gateChecks, nodes, fixScript)
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if r.State.Attempts["build"] != 2 || r.State.Returns["merge"] != 1 {
		t.Errorf("the implementer ran %d times, the refusal went back %d times; want 2 and 1", r.State.Attempts["build"], r.State.Returns["merge"])
	}
	prompt := promptOf(t, r, "build-2")
	for _, want := range []string{"## Refused after your work passed", "merge gate refused (checks)", "check late failed"} {
		if !strings.Contains(prompt, want) {
			t.Errorf("the second attempt's prompt lacks %q:\n%s", want, prompt)
		}
	}
	l, _ := r.Leaf("repos/app")
	if body, err := l.Git(bg, "show", "main:fixed.txt"); err != nil || body != "done" {
		t.Errorf("main:fixed.txt = %q, %v; the second attempt's work landed", body, err)
	}
	if rec := r.State.Leaves["repos/app"]; rec.Checkpoint == "" {
		t.Error("the leaf has no checkpoint")
	}
	if text := ledgerText(t, r); !strings.Contains(text, `"event":"node_returned"`) || !strings.Contains(text, "back to build, 1 of 2") {
		t.Errorf("the ledger lacks node_returned:\n%s", text)
	}
}

func TestARefusalThatKeepsComingBackFailsTheNodeAfterItsReturns(t *testing.T) {
	nodes := loopOfBuild + "  - { id: merge, kind: merge, repo: repos/app, checks: [late], back_to: build, returns: 1 }\n"
	script := strings.Replace(fixScript, "writes fixed.txt", "wrote nothing useful", 1)
	script = strings.ReplaceAll(script, "fixed.txt", "nothing.txt")
	r := startPack(t, "key-points", "", gateChecks, nodes, script)
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "check late failed") {
		t.Fatalf("Advance() = %+v, %v; want the node failed with the gate's refusal", out, err)
	}
	if r.State.Attempts["build"] != 2 || r.State.Returns["merge"] != 1 {
		t.Errorf("implementer %d times, returned %d times; want 2 and 1", r.State.Attempts["build"], r.State.Returns["merge"])
	}
	l, _ := r.Leaf("repos/app")
	if _, err := l.Git(bg, "show", "main:out.txt"); err == nil {
		t.Error("work the gate refused landed on main")
	}
}

func TestABaseThatDoesNotMergeCleanlyIsNotSentBack(t *testing.T) {
	nodes := loopOfBuild + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit], back_to: build }\n"
	r := startPack(t, "key-points", "", gateChecks, nodes, fixScript)
	l, _ := r.Leaf("repos/app")
	// main gets an out.txt of its own, so the run's out.txt conflicts with it.
	for _, args := range [][]string{{"switch", "-q", "main"}, {"switch", "-q", run.Branch(r.State.ID)}} {
		if args[2] == "main" {
			if _, err := l.Git(bg, args...); err != nil {
				t.Fatal(err)
			}
			os.WriteFile(filepath.Join(l.Dir(), "out.txt"), []byte("someone else's\n"), 0o644)
			for _, step := range [][]string{{"add", "out.txt"}, {"commit", "-q", "-m", "someone else landed out.txt"}} {
				if _, err := l.Git(bg, step...); err != nil {
					t.Fatal(err)
				}
			}
			continue
		}
		if _, err := l.Git(bg, args...); err != nil {
			t.Fatal(err)
		}
	}
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "conflict") {
		t.Fatalf("Advance() = %+v, %v; want failed on the conflict", out, err)
	}
	if r.State.Returns["merge"] != 0 || r.State.Attempts["build"] != 1 {
		t.Errorf("returns %d, implementer ran %d times; a conflict is not the implementer's to fix", r.State.Returns["merge"], r.State.Attempts["build"])
	}
}

func TestAPointerMoveWhoseAcceptanceFailsSendsTheWorkBackIntoTheLoop(t *testing.T) {
	nodes := loopOfBuild + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
		"  - { id: move, kind: pointer, repo: repos/app, checks: [unit], acceptance: [accept], back_to: build }\n"
	r := startPack(t, "key-points", "", gateChecks, nodes, fixScript)
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if r.State.Attempts["build"] != 2 || r.State.Returns["move"] != 1 || r.State.Attempts["merge"] != 2 {
		t.Errorf("implementer %d times, merge %d times, returned %d times; want 2, 2 and 1", r.State.Attempts["build"], r.State.Attempts["merge"], r.State.Returns["move"])
	}
	if prompt := promptOf(t, r, "build-2"); !strings.Contains(prompt, "pointer move refused (acceptance)") {
		t.Errorf("the second attempt's prompt lacks the pointer's refusal:\n%s", prompt)
	}
	l, _ := r.Leaf("repos/app")
	main, _ := l.Rev(bg, "main")
	if got, _ := git.Run(bg, r.Project, "rev-parse", "HEAD:repos/app"); got != main {
		t.Errorf("the project points at %s, want main %s", got, main)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAMergeGateThatRefusesTheChecksSendsTheWorkBackIntoTheLoop (0.36s)
    loopback_test.go:31: Advance() = {Status:failed Gate: Err:node merge: merge gate refused (checks): check late failed: exit status 1 (output: /tmp/TestAMergeGateThatRefusesTheChecksSendsTheWorkBackIntoTheLoop1817645410/008/l0/.factory/runs/20261017-043545-e7700b/logs/merge-1-late.log) Warn:[]}, <nil>
--- FAIL: TestARefusalThatKeepsComingBackFailsTheNodeAfterItsReturns (0.37s)
    loopback_test.go:64: implementer 1 times, returned 0 times; want 2 and 1
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/land.go`:

```diff
diff --git a/internal/engine/land.go b/internal/engine/land.go
index 1d16d84..5f4202e 100644
--- a/internal/engine/land.go
+++ b/internal/engine/land.go
@@ -48,10 +48,16 @@ func runMerge(ctx context.Context, r *run.Run, n schema.Node) error {
 	if leaf.IsPolicy(landErr) { // a check rewrote the leaf's .git or planted a repository
 		return &hardStop{gate: gungnir.GatePolicyViolation, err: landErr}
 	}
-	ev := gungnir.Event{Name: gungnir.EventNodeFinished, Node: n.ID, Attempt: attempt,
+	ev := gungnir.Event{Name: gungnir.EventNodeFinished, Node: n.ID, Attempt: attempt, Task: n.Task,
 		DurationMS: time.Since(began).Milliseconds()}
 	if landErr != nil {
-		return failLanding(r, ev, landErr)
+		var mr *merge.Refused
+		if errors.As(landErr, &mr) && mr.Why == merge.WhyChecks && res.Checked != "" {
+			// The branch, with the base merged in, is what the checks refused: the loop goes on from there.
+			rec.Checkpoint = res.Checked
+			r.State.Leaves[n.Repo] = rec
+		}
+		return failLanding(r, n, ev, landErr)
 	}
 	rec.Checkpoint = res.Merged
 	r.State.Leaves[n.Repo] = rec
@@ -115,7 +121,7 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 	var se *shrink.Error
 	if errors.As(moveErr, &se) {
 		// The attempt the node_started line opened closes in the ledger (backlog B-010).
-		fail := gungnir.Event{Name: gungnir.EventNodeFailed, Node: n.ID, Attempt: attempt, Result: moveErr.Error(),
+		fail := gungnir.Event{Name: gungnir.EventNodeFailed, Node: n.ID, Attempt: attempt, Task: n.Task, Result: moveErr.Error(),
 			DurationMS: time.Since(began).Milliseconds()}
 		if err := r.Log(fail); err != nil {
 			return err
@@ -125,13 +131,13 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 	if leaf.IsPolicy(moveErr) { // a check rewrote the leaf's .git or planted a repository
 		return &hardStop{gate: gungnir.GatePolicyViolation, err: moveErr}
 	}
-	ev := gungnir.Event{Name: gungnir.EventNodeFinished, Node: n.ID, Attempt: attempt,
+	ev := gungnir.Event{Name: gungnir.EventNodeFinished, Node: n.ID, Attempt: attempt, Task: n.Task,
 		DurationMS: time.Since(began).Milliseconds()}
 	if moveErr != nil {
-		return failLanding(r, ev, moveErr)
+		return failLanding(r, n, ev, moveErr)
 	}
 	if res.Commit != "" {
-		moved := gungnir.Event{Name: gungnir.EventPointerMoved, Node: n.ID, Attempt: attempt, Commit: res.Commit,
+		moved := gungnir.Event{Name: gungnir.EventPointerMoved, Node: n.ID, Attempt: attempt, Task: n.Task, Commit: res.Commit,
 			Note: fmt.Sprintf("%s: %.12s -> %.12s", filepath.Join(parentRepo, child), res.From, res.To)}
 		if err := r.Log(moved); err != nil {
 			return err
@@ -146,7 +152,7 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 			return err
 		}
 		if !logged {
-			moved := gungnir.Event{Name: gungnir.EventPointerMoved, Node: n.ID, Attempt: attempt,
+			moved := gungnir.Event{Name: gungnir.EventPointerMoved, Node: n.ID, Attempt: attempt, Task: n.Task,
 				Note: fmt.Sprintf("%s: already at %.12s; an earlier attempt moved it and the run didn't record it", filepath.Join(parentRepo, child), res.To)}
 			if err := r.Log(moved); err != nil {
 				return err
@@ -162,8 +168,11 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 }
 
 // failLanding fails a merge or pointer node that the gate refused, or whose target another process
-// holds. Anything else is a failure of Odin itself.
-func failLanding(r *run.Run, ev gungnir.Event, err error) error {
+// holds. Anything else is a failure of Odin itself. A gate that refused because the work fails its checks
+// sends the work back into the loop that made it when the node names one (spec §4.5, back_to); a base that
+// doesn't merge cleanly, or a target another process holds, fails the node, since the implementer can't
+// fix either.
+func failLanding(r *run.Run, n schema.Node, ev gungnir.Event, err error) error {
 	var mr *merge.Refused
 	var pr *pointer.Refused
 	if !errors.As(err, &mr) && !errors.As(err, &pr) && !errors.Is(err, lock.ErrHeld) {
@@ -173,6 +182,11 @@ func failLanding(r *run.Run, ev gungnir.Event, err error) error {
 	if lerr := r.Log(ev); lerr != nil {
 		return lerr
 	}
+	if (mr != nil && mr.Why == merge.WhyChecks) || pr != nil {
+		if sent, serr := sendBack(r, n, err.Error()); sent || serr != nil {
+			return serr
+		}
+	}
 	return &nodeFailure{err}
 }
 
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T181: an unattended run gives up a task whose loop gave up and goes on with the tasks that don't depend on it

Spec §7.3, second half: "unattended: mark the task `blocked`. Continue with tasks that do not depend on it. List it first in the run report." Phase 4 decision 7 stopped every mode at the escalation because a linear graph had no rest to go on with; now it has.

**Files (in `odin`):**
- Create: `internal/engine/blocked_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/stages.go`

**Interfaces:**
- Produces: in unattended mode, a loop escalation inside a task blocks the task (`blockTask`): features.json and the ledger say so with the loop's reason; the leaf is put back to its main and what the task did is kept on `refs/ygg/<run>/blocked/<task>`; Position moves past the task's nodes. `skipBlocked` blocks, without starting, each task that depends on a blocked one when the walk reaches it. The run finishes `done`, and its `run_finished` line lists the blocked tasks. The other modes stop at the escalation as before; every other failure still fails or stops the run.

**Acceptance criteria:**
- [ ] Four tasks, the second given up and the third depending on it, the fourth independent: the first and fourth are done, the second and third blocked; the third was never started; the web leaf is back at main; the blocked work is on its ref; the fourth landed.
- [ ] Step-by-step and key-points stop at the loop that gave up.

**Named test:** `go test ./internal/engine -run 'TestAnUnattendedRunGivesUpATaskWhoseLoopGaveUpAndGoesOnWithTheRest|TestOtherModesStopAtTheLoopThatGaveUp'` in `odin`. **Layer:** `odin`. **Size:** M (229). **Depends on:** v0-T178.

- [ ] **Step 1:** write the tests.

Write `internal/engine/blocked_test.go`:

```go
package engine

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
)

// A plan of four tasks: 1 builds the api, 2 the web leaf on it, 3 depends on 2, and 4 builds more of the
// api and depends on nothing. Task 2's implementer never writes what its check wants.
func blockedRun(t *testing.T, mode string) *run.Run {
	t.Helper()
	idle := "    - result: { status: ok, summary: did nothing }\n"
	script := writeStep("p-t1-implement", "api.txt") + writeStep("p-t4-implement", "api2.txt") +
		"  p-t2-implement:\n" + strings.Repeat(idle, 3) + writeStep("p-t3-implement", "web2.txt")
	r := startRealms(t, realmsSetup{mode: mode, nodes: taskShape, script: "steps:\n" + script,
		realms: []realmFiles{recipeRealm("midgard-react", "0.1.0", "web.txt", "Web implementer prompt."), recipeRealm("helheim-go", "0.2.0", "api.txt", "API implementer prompt.")},
		leaves: map[string]string{"repos/api": "helheim-go", "repos/web": "midgard-react"}})
	plan := "# Tasks\n\n" + taskMD("p-T1", "repos/api", "S", "nothing") + taskMD("p-T2", "repos/web", "M", "p-T1") +
		taskMD("p-T3", "repos/web", "S", "p-T2") + taskMD("p-T4", "repos/api", "S", "p-T1")
	if err := os.WriteFile(filepath.Join(r.Project, "tasks.md"), []byte(plan), 0o644); err != nil {
		t.Fatal(err)
	}
	return r
}

func TestAnUnattendedRunGivesUpATaskWhoseLoopGaveUpAndGoesOnWithTheRest(t *testing.T) {
	r := blockedRun(t, "unattended")
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v; want the run done, with a task given up", out, err)
	}
	status := map[string]schema.TaskStatus{}
	for _, f := range r.State.Features {
		status[f.ID] = f.Status
	}
	want := map[string]schema.TaskStatus{"p-T1": schema.TaskDone, "p-T2": schema.TaskBlocked, "p-T3": schema.TaskBlocked, "p-T4": schema.TaskDone}
	for id, st := range want {
		if status[id] != st {
			t.Errorf("task %s is %s, want %s (all: %v)", id, status[id], st, status)
		}
	}
	if why := r.State.Features[1].Why; !strings.Contains(why, "attempts-exhausted") || !strings.Contains(why, "refs/ygg/"+r.State.ID+"/blocked/p-t2") {
		t.Errorf("task 2's reason = %q", why)
	}
	if why := r.State.Features[2].Why; !strings.Contains(why, "depends on p-T2, which is blocked") {
		t.Errorf("task 3's reason = %q", why)
	}
	if r.State.Attempts["p-t3-implement"] != 0 {
		t.Error("a task that depends on a blocked task was started")
	}
	if got := strings.Join(taskEvents(t, r), ", "); got != "task_started p-t1, task_done p-t1, task_started p-t2, task_blocked p-t2, task_blocked p-t3, task_started p-t4, task_done p-t4" {
		t.Errorf("task events = %s", got)
	}
	web, _ := r.Leaf("repos/web")
	main, _ := web.Rev(context.Background(), "main")
	if head, _ := web.Head(context.Background()); head != main || r.State.Leaves["repos/web"].Checkpoint != main {
		t.Errorf("repos/web is at %s with checkpoint %s, want main %s: the blocked task's work is not left on the run's branch", head, r.State.Leaves["repos/web"].Checkpoint, main)
	}
	if kept, err := web.Git(context.Background(), "rev-parse", "refs/ygg/"+r.State.ID+"/blocked/p-t2"); err != nil || kept == "" {
		t.Errorf("the blocked task's work is not kept on a ref: %q, %v", kept, err)
	}
	api, _ := r.Leaf("repos/api")
	if body, err := api.Git(context.Background(), "show", "main:api2.txt"); err != nil || body != "done" {
		t.Errorf("the task that doesn't depend on the blocked one did not land: %q, %v", body, err)
	}
	f, err := schema.LoadFeatures(filepath.Join(r.Project, ".factory", "features.json"))
	if err != nil || f.Tasks[1].Status != schema.TaskBlocked || f.Tasks[1].Why == "" {
		t.Errorf("features.json = %+v, %v", f, err)
	}
	text := ledgerText(t, r)
	if !strings.Contains(text, `"ygg.result":"done, with 2 task(s) blocked: p-T2, p-T3"`) || !strings.Contains(text, `"ygg.result":"blocked"`) {
		t.Errorf("the ledger doesn't list the blocked tasks:\n%s", text)
	}
}

func TestOtherModesStopAtTheLoopThatGaveUp(t *testing.T) {
	for _, mode := range []string{"step-by-step", "key-points"} {
		r := blockedRun(t, mode)
		if mode == "step-by-step" {
			// every task's feature gate stops in this mode: approve them as they come
			for {
				out, err := Advance(context.Background(), r)
				if err != nil {
					t.Fatal(err)
				}
				if out.Status == run.StatusStopped && strings.HasSuffix(out.Gate, "feature-gate") {
					if err := Approve(context.Background(), r, out.Gate, ""); err != nil {
						t.Fatal(err)
					}
					continue
				}
				if out.Status != run.StatusStopped || out.Gate != "p-t2-implement" || r.State.PendingGate != "escalation" {
					t.Errorf("%s: Advance() = %+v, pending %s; want a stop at the escalation of task 2's loop", mode, out, r.State.PendingGate)
				}
				break
			}
			continue
		}
		out, err := Advance(context.Background(), r)
		if err != nil || out.Status != run.StatusStopped || out.Gate != "p-t2-implement" || r.State.PendingGate != "escalation" {
			t.Errorf("%s: Advance() = %+v, %v; want a stop at the escalation of task 2's loop", mode, out, err)
		}
		if r.State.Features[1].Status == schema.TaskBlocked {
			t.Errorf("%s: a task was given up with an operator there to decide", mode)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAnUnattendedRunGivesUpATaskWhoseLoopGaveUpAndGoesOnWithTheRest (1.05s)
    blocked_test.go:36: Advance() = {Status:stopped Gate:p-t2-implement Err:<nil> Warn:[]}, <nil>; want the run done, with a task given up
FAIL
FAIL	github.com/ouroboric-dev/odin/internal/engine	62.515s
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index a21ed62..bb7a5a1 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -58,6 +58,11 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 	}
 	for {
 		nodes := r.Nodes()
+		if moved, err := skipBlocked(r, nodes); err != nil {
+			return Outcome{}, err
+		} else if moved {
+			continue
+		}
 		if err := settleTasks(r, nodes); err != nil {
 			return Outcome{}, err
 		}
@@ -104,6 +109,13 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 		}
 		var esc *escalation
 		if errors.As(err, &esc) {
+			if blocksTasks(r, n) {
+				// Unattended: give the task up and go on with the tasks that don't depend on it (spec §7.3).
+				if err := blockTask(ctx, r, nodes, n, "its loop gave up ("+esc.out.Reason+"): "+esc.out.Detail+"."); err != nil {
+					return Outcome{}, err
+				}
+				continue
+			}
 			return stopEscalation(r, n, esc)
 		}
 		if err != nil {
@@ -118,12 +130,26 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 		}
 	}
 	s.Status = run.StatusDone
-	if err := r.Log(gungnir.Event{Name: gungnir.EventRunFinished, Result: "done"}.WithUsage(s.Usage)); err != nil {
+	if err := r.Log(gungnir.Event{Name: gungnir.EventRunFinished, Result: doneResult(s)}.WithUsage(s.Usage)); err != nil {
 		return Outcome{}, err
 	}
 	return Outcome{Status: run.StatusDone}, r.Save()
 }
 
+// doneResult is how a finished run is described: "done", or the tasks it gave up, listed first (spec §7.3).
+func doneResult(s *run.State) string {
+	var blocked []string
+	for _, f := range s.Features {
+		if f.Status == schema.TaskBlocked {
+			blocked = append(blocked, f.ID)
+		}
+	}
+	if len(blocked) == 0 {
+		return "done"
+	}
+	return fmt.Sprintf("done, with %d task(s) blocked: %s", len(blocked), strings.Join(blocked, ", "))
+}
+
 // nodeFailure is a node that failed; the run stops failed, and resume re-runs the node.
 type nodeFailure struct{ err error }
 
```

Apply to `internal/engine/stages.go`:

```diff
diff --git a/internal/engine/stages.go b/internal/engine/stages.go
index 3e59df3..435dc0a 100644
--- a/internal/engine/stages.go
+++ b/internal/engine/stages.go
@@ -202,3 +202,92 @@ func setTask(r *run.Run, slug string, to schema.TaskStatus, event gungnir.EventN
 	}
 	return r.Save()
 }
+
+// blocksTasks reports whether the run gives a task up when its loop does, and goes on with the rest:
+// an unattended run's answer to an exhausted loop, where the other modes stop and ask (spec §7.3).
+func blocksTasks(r *run.Run, n schema.Node) bool {
+	return r.State.Mode == gungnir.ModeUnattended && n.Task != ""
+}
+
+// blockTask gives up the task node n works for: the task is blocked, with the reason, the leaf is put
+// back to its main with what the task did kept on a ref for the operator, and Position moves past the
+// task's nodes. The tasks that depend on it are blocked when the walk reaches them (skipBlocked).
+func blockTask(ctx context.Context, r *run.Run, nodes []schema.Node, n schema.Node, why string) error {
+	s := r.State
+	if rec, ok := s.Leaves[n.Repo]; ok && n.Repo != "" {
+		l, err := r.Leaf(n.Repo)
+		if err != nil {
+			return err
+		}
+		base, err := l.Rev(ctx, "main")
+		if err != nil {
+			return err
+		}
+		ref := "refs/ygg/" + s.ID + "/blocked/" + n.Task
+		if _, err := l.Git(ctx, "update-ref", ref, rec.Checkpoint); err != nil {
+			return err
+		}
+		if err := l.Reset(ctx, rec.Branch, base); err != nil {
+			return err
+		}
+		rec.Checkpoint = base
+		s.Leaves[n.Repo] = rec
+		why += fmt.Sprintf(" What the task did is kept on %s (git -C %s log %s).", ref, r.RepoDir(n.Repo), ref)
+	}
+	if err := markBlocked(r, n.Task, why); err != nil {
+		return err
+	}
+	for s.Position < len(nodes) && nodes[s.Position].Task == n.Task {
+		s.Position++
+	}
+	s.Pending, s.PendingGate = "", ""
+	return r.Save()
+}
+
+// markBlocked records the task as blocked, in features.json and the ledger.
+func markBlocked(r *run.Run, slug, why string) error {
+	s := r.State
+	i := slices.IndexFunc(s.Features, func(f schema.FeatureRecord) bool { return f.Slug() == slug })
+	if i < 0 || s.Features[i].Status == schema.TaskBlocked {
+		return nil
+	}
+	s.Features[i].Status, s.Features[i].Why = schema.TaskBlocked, why
+	if err := writeFeatures(r); err != nil {
+		return err
+	}
+	return r.Log(gungnir.Event{Name: gungnir.EventTaskBlocked, Task: slug, Result: "blocked", Note: firstLine(why)})
+}
+
+// skipBlocked blocks, without starting it, the task whose nodes come next if a task it depends on is
+// blocked, and moves Position past the task's nodes. It returns whether it moved.
+func skipBlocked(r *run.Run, nodes []schema.Node) (bool, error) {
+	s := r.State
+	moved := false
+	for s.Position < len(nodes) && nodes[s.Position].Task != "" {
+		slug := nodes[s.Position].Task
+		i := slices.IndexFunc(s.Features, func(f schema.FeatureRecord) bool { return f.Slug() == slug })
+		if i < 0 {
+			return moved, nil
+		}
+		f := s.Features[i]
+		if f.Status != schema.TaskBlocked {
+			dep := slices.IndexFunc(s.Features, func(g schema.FeatureRecord) bool {
+				return g.Status == schema.TaskBlocked && slices.Contains(f.DependsOn, g.ID)
+			})
+			if dep < 0 {
+				return moved, nil
+			}
+			if err := markBlocked(r, slug, fmt.Sprintf("it depends on %s, which is blocked", s.Features[dep].ID)); err != nil {
+				return moved, err
+			}
+		}
+		for s.Position < len(nodes) && nodes[s.Position].Task == slug {
+			s.Position++
+		}
+		moved = true
+	}
+	if moved {
+		return true, r.Save()
+	}
+	return false, nil
+}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T182: a scratch agent works in a workspace of its own, with copies of what it reads and an out/ folder for what it writes

Spec §3.3 rule 1: "A planner gets a scratch directory with the brief." The stages that write documents (design, spec, plan) run as agents in a workspace under the run, in a scratch sandbox when the run has one.

**Files (in `odin`):**
- Create: `internal/engine/scratch.go`, `internal/engine/scratch_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/session.go`, `internal/run/run.go`, `internal/run/sandbox.go`

**Interfaces:**
- Produces: `(*Run).ScratchDir(node)` (`<run>/scratch/<node>`) and `(*Run).ScratchRunner(ctx, node)`; `engine.runScratch`: the workspace is made again for every attempt and every retry (the brief as `brief.md`, a copy of each input that exists, an empty `out/`); an input that is, or holds, a symlink or any file but a regular one is refused, and so is more than 2,000 files or 16 MiB; `.git` inside an input is left out; the prompt is the node's prompt, its skills, a note on the workspace, the brief and any rejection or refusal. The session runs with `sessionSpec.scratch`. `Prepare` accepts a scratch agent, which names no repo. No checkpoint, no secret scan, no leaf.

**Acceptance criteria:**
- [ ] The agent writes `out/docs/design.md`; the brief and the inputs are in the workspace; a change to an input's copy leaves the project's file alone.
- [ ] A second attempt after a rejection starts from a fresh workspace and its prompt carries the reason.
- [ ] An input that holds a symlink is refused before the agent runs.
- [ ] With a sandbox, one scratch sandbox comes up for the node (no git dir, the workspace as its leaf), commands run in it, and it stops with the rest.

**Named test:** `go test ./internal/engine -run 'TestAScratchAgentWorksInAWorkspaceOfItsOwnAndWritesUnderOut|TestEachAttemptOfAScratchAgentStartsFromAFreshWorkspace|TestAnInputThatCouldLeadOutOfTheProjectIsRefused|TestAScratchAgentRunsInAScratchSandboxWithNoGitDir'` in `odin`. **Layer:** `odin`. **Size:** M (367). **Depends on:** v0-T161 (merged), v0-T148 (merged), v0-T173.

- [ ] **Step 1:** write the tests.

Write `internal/engine/scratch_test.go`:

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

const scratchNode = "  - { id: design, kind: agent, role: planner, prompt: p.md, scratch: true, inputs: [docs/input.md, docs/more, missing.md] }\n"

const designScript = "steps:\n  design:\n    - actions:\n        - write: { path: out/docs/design.md, content: \"# Design\\n\" }\n        - write: { path: docs/input.md, content: \"changed in the copy\\n\" }\n" +
	"      result: { status: ok, summary: wrote the design }\n" +
	"    - actions: [ { write: { path: out/docs/other.md, content: \"# Other\\n\" } } ]\n      result: { status: ok, summary: wrote another design }\n"

// withInputs writes the project files a scratch agent is given copies of.
func withInputs(t *testing.T, r *run.Run) {
	t.Helper()
	for p, body := range map[string]string{"docs/input.md": "the input\n", "docs/more/a.md": "a\n", "docs/more/.git/HEAD": "ref\n"} {
		f := filepath.Join(r.Project, p)
		os.MkdirAll(filepath.Dir(f), 0o755)
		if err := os.WriteFile(f, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

func TestAScratchAgentWorksInAWorkspaceOfItsOwnAndWritesUnderOut(t *testing.T) {
	r := start(t, "key-points", "", scratchNode, designScript)
	withInputs(t, r)
	r.Setup.BriefText = "Build a gallery."
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	ws := r.ScratchDir("design")
	if ws != filepath.Join(r.Dir, "scratch", "design") {
		t.Errorf("ScratchDir = %s", ws)
	}
	if b, err := os.ReadFile(filepath.Join(ws, "out", "docs", "design.md")); err != nil || string(b) != "# Design\n" {
		t.Errorf("out/docs/design.md = %q, %v", b, err)
	}
	if b, _ := os.ReadFile(filepath.Join(ws, "brief.md")); string(b) != "Build a gallery." {
		t.Errorf("brief.md = %q", b)
	}
	if b, _ := os.ReadFile(filepath.Join(ws, "docs", "more", "a.md")); string(b) != "a\n" {
		t.Errorf("the copy of docs/more/a.md = %q", b)
	}
	if _, err := os.Stat(filepath.Join(ws, "docs", "more", ".git")); err == nil {
		t.Error("a .git inside an input was copied into the workspace")
	}
	if b, _ := os.ReadFile(filepath.Join(r.Project, "docs", "input.md")); string(b) != "the input\n" {
		t.Errorf("the agent changed the project's docs/input.md through its copy: %q", b)
	}
	prompt := promptOf(t, r, "design-1")
	for _, want := range []string{"## Your workspace", "- docs/input.md is a copy", "- docs/more is a copy", "Write every document you produce under out/", "## Brief"} {
		if !strings.Contains(prompt, want) {
			t.Errorf("the prompt lacks %q:\n%s", want, prompt)
		}
	}
	if strings.Contains(prompt, "missing.md") {
		t.Errorf("the prompt lists an input that is not in the project:\n%s", prompt)
	}
	if len(r.State.Leaves) != 0 {
		t.Errorf("a scratch node is not a leaf: leaves %v", r.State.Leaves)
	}
}

func TestEachAttemptOfAScratchAgentStartsFromAFreshWorkspace(t *testing.T) {
	nodes := scratchNode + "  - { id: design-gate, kind: gate, gate: design }\n"
	r := start(t, "key-points", "", nodes, designScript)
	withInputs(t, r)
	ctx := context.Background()
	out, err := Advance(ctx, r)
	if err != nil || out.Status != run.StatusStopped {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if err := Reject(ctx, r, "design-gate", "shorter, please"); err != nil {
		t.Fatal(err)
	}
	if out, err := Advance(ctx, r); err != nil || out.Status != run.StatusStopped {
		t.Fatalf("Advance() after the rejection = %+v, %v", out, err)
	}
	ws := r.ScratchDir("design")
	if _, err := os.Stat(filepath.Join(ws, "out", "docs", "design.md")); err == nil {
		t.Error("the first attempt's output was still in the workspace for the second")
	}
	if _, err := os.Stat(filepath.Join(ws, "out", "docs", "other.md")); err != nil {
		t.Errorf("the second attempt's output is missing: %v", err)
	}
	if b, _ := os.ReadFile(filepath.Join(ws, "docs", "input.md")); string(b) != "the input\n" {
		t.Errorf("the second attempt got %q for docs/input.md; the first attempt's change in its copy must not carry over", b)
	}
	if got := promptOf(t, r, "design-2"); !strings.Contains(got, "shorter, please") {
		t.Errorf("the second prompt lacks the rejection:\n%s", got)
	}
}

func TestAnInputThatCouldLeadOutOfTheProjectIsRefused(t *testing.T) {
	r := start(t, "key-points", "", scratchNode, designScript)
	withInputs(t, r)
	secret := filepath.Join(t.TempDir(), "secret.txt")
	os.WriteFile(secret, []byte("secret\n"), 0o644)
	if err := os.Symlink(secret, filepath.Join(r.Project, "docs", "more", "link.md")); err != nil {
		t.Fatal(err)
	}
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "link.md") || !strings.Contains(out.Err.Error(), "not a regular file") {
		t.Errorf("Advance() = %+v, %v", out, err)
	}
	if _, err := os.Stat(filepath.Join(r.ScratchDir("design"), "docs", "more", "link.md")); err == nil {
		t.Error("the symlink's target was copied into the workspace")
	}
	if r.State.Attempts["design"] != 0 {
		t.Error("the agent ran although its workspace could not be made")
	}
}

func TestAScratchAgentRunsInAScratchSandboxWithNoGitDir(t *testing.T) {
	r, fake := startSandboxedWith(t, strings.Replace(scratchNode, "inputs: [docs/input.md, docs/more, missing.md] ", "", 1),
		"steps:\n  design:\n    - actions:\n        - write: { path: out/design.md, content: \"# Design\\n\" }\n        - run: { argv: [sh, -c, \"echo ok > ran-in-sandbox.txt\"] }\n      result: { status: ok, summary: wrote }\n", run.Hooks{})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if len(fake.Ups) != 1 {
		t.Fatalf("%d sandboxes came up", len(fake.Ups))
	}
	up := fake.Ups[0]
	if !up.Scratch || up.GitDir != "" || up.Name != "scratch/design" || up.Leaf != r.ScratchDir("design") || up.Parent != r.Dir {
		t.Errorf("spec = %+v", up)
	}
	if err := up.Validate(); err != nil {
		t.Errorf("the spec Odin built is one the driver would refuse: %v", err)
	}
	if b, err := os.ReadFile(filepath.Join(r.ScratchDir("design"), "ran-in-sandbox.txt")); err != nil || strings.TrimSpace(string(b)) != "ok" {
		t.Errorf("the agent's command did not run in the workspace: %q, %v", b, err)
	}
	if len(fake.Downs) != 1 || len(r.State.Sandboxes) != 0 {
		t.Errorf("downs %d, recorded %v; the scratch sandbox stops with the rest", len(fake.Downs), r.State.Sandboxes)
	}
	if fake.Scans != 0 {
		t.Errorf("%d secret scans ran for a node that commits nothing", fake.Scans)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/scratch_test.go:39:10: r.ScratchDir undefined (type *run.Run has no field or method ScratchDir)
internal/engine/scratch_test.go:87:10: r.ScratchDir undefined (type *run.Run has no field or method ScratchDir)
internal/engine/scratch_test.go:114:39: r.ScratchDir undefined (type *run.Run has no field or method ScratchDir)
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index bb7a5a1..3249a74 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -74,7 +74,11 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 		var err error
 		switch n.Kind {
 		case schema.KindAgent:
-			err = runAgent(ctx, r, n)
+			if n.Scratch {
+				err = runScratch(ctx, r, n)
+			} else {
+				err = runAgent(ctx, r, n)
+			}
 		case schema.KindLoop:
 			err = runLoop(ctx, r, n)
 		case schema.KindExec:
```

Write `internal/engine/scratch.go`:

```go
package engine

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/jormungandr"
	"github.com/ouroboric-dev/odin/internal/run"
)

// What a scratch workspace may be seeded with: a plan's documents are a few hundred small text files.
const (
	maxScratchFiles = 2000
	maxScratchBytes = 16 << 20
)

// runScratch runs a scratch agent node (spec §3.3 rule 1): a planner gets a workspace of its own, not an
// umbrella and not a leaf. The workspace holds the brief, read-only copies of the project paths the node
// names, and an empty out/ folder where the agent writes what it produces. Odin publishes out/ into the
// project later (a publish node), after the approval point. A workspace is made again for every attempt
// and every retry, so a half-written one never reaches the next.
func runScratch(ctx context.Context, r *run.Run, n schema.Node) error {
	s := r.State
	dir := r.ScratchDir(n.ID)
	present, err := seedScratch(r, n)
	if err != nil {
		return &nodeFailure{err}
	}
	prompt, err := os.ReadFile(filepath.Join(r.Setup.Realm(n.Realm).Dir, n.Prompt))
	if err != nil {
		return err
	}
	text := string(prompt)
	skillText, err := r.Setup.Libs.Load(n.Skills)
	if err != nil {
		return err
	}
	if skillText != "" {
		text += "\n\n" + skillText
	}
	text += "\n\n" + workspaceNote(r, present)
	if r.Setup.BriefText != "" {
		text += "\n\n## Brief\n\n" + r.Setup.BriefText
	}
	if reason := s.Reasons[n.ID]; reason != "" {
		text += "\n\n## Rejected at the approval point\n\n" + reason + "\n"
	}
	if refusal := s.Refusals[n.ID]; refusal != "" {
		text += "\n\n" + jormungandr.Refusal(refusal)
	}
	sp := sessionSpec{key: n.ID, role: n.Role, text: text, maxTurns: n.MaxTurns, timeout: time.Duration(n.Timeout),
		scratch: dir, reseed: func() error { _, err := seedScratch(r, n); return err }}
	res, ev, err := session(ctx, r, sp)
	if err != nil {
		return nodeError(err)
	}
	ev.Name, ev.Result = gungnir.EventNodeFinished, res.Summary
	if err := r.Log(ev); err != nil {
		return err
	}
	delete(s.Reasons, n.ID)
	delete(s.Refusals, n.ID)
	s.Summaries[n.ID] = res.Summary
	return nil
}

// workspaceNote tells the agent what its workspace holds and where its output goes.
func workspaceNote(r *run.Run, present []string) string {
	var b strings.Builder
	b.WriteString("## Your workspace\n\nYou work in the folder you start in. It is not a repository, and nothing in it is committed by you.\n")
	if r.Setup.BriefText != "" {
		b.WriteString("- brief.md is the brief, as you are given it below.\n")
	}
	for _, p := range present {
		fmt.Fprintf(&b, "- %s is a copy of the project's file or folder of that name. Read it. What you change in it is ignored.\n", p)
	}
	b.WriteString("- Write every document you produce under out/, in the folders it should have in the project (for example out/docs/2-engineering/specs/...). " +
		"Only out/ leaves this workspace, and only after a person or a check has approved it.\n")
	return b.String()
}

// seedScratch makes the workspace of node n anew: the brief, a copy of each input that exists in the
// project, and an empty out/. It returns the inputs it copied. Odin's own folder is replaced as a whole;
// nothing outside it is touched. An input that is, or holds, a symlink or anything but a regular file is
// refused, since the workspace is a copy and must not lead out of the project.
func seedScratch(r *run.Run, n schema.Node) (present []string, err error) {
	dir := r.ScratchDir(n.ID)
	if err := os.RemoveAll(dir); err != nil {
		return nil, err
	}
	if err := os.MkdirAll(filepath.Join(dir, "out"), 0o755); err != nil {
		return nil, err
	}
	if r.Setup.BriefText != "" {
		if err := os.WriteFile(filepath.Join(dir, "brief.md"), []byte(r.Setup.BriefText), 0o644); err != nil {
			return nil, err
		}
	}
	b := &copyBudget{files: maxScratchFiles, bytes: maxScratchBytes}
	for _, in := range n.Inputs {
		src := filepath.Join(r.Project, filepath.FromSlash(in))
		if _, err := os.Lstat(src); errors.Is(err, fs.ErrNotExist) {
			continue // not written yet, such as the leaves file before the spec stage
		}
		if err := copyTree(src, filepath.Join(dir, filepath.FromSlash(in)), b); err != nil {
			return nil, fmt.Errorf("input %s of %s: %w", in, n.ID, err)
		}
		present = append(present, in)
	}
	return present, nil
}

type copyBudget struct{ files, bytes int64 }

// copyTree copies the regular files under src to dst, leaving out .git. It stops at a symlink or any
// other kind of file, and at more files or bytes than the budget holds.
func copyTree(src, dst string, b *copyBudget) error {
	return filepath.WalkDir(src, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(src, p)
		if err != nil {
			return err
		}
		if d.Name() == ".git" {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		target := filepath.Join(dst, rel)
		switch {
		case d.IsDir():
			return os.MkdirAll(target, 0o755)
		case !d.Type().IsRegular():
			return fmt.Errorf("%s is %s, not a regular file; the workspace holds copies of files and nothing that could lead out of the project", p, d.Type())
		}
		if b.files--; b.files < 0 {
			return fmt.Errorf("more than %d files", maxScratchFiles)
		}
		data, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		if b.bytes -= int64(len(data)); b.bytes < 0 {
			return fmt.Errorf("more than %d bytes", maxScratchBytes)
		}
		if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
			return err
		}
		return os.WriteFile(target, data, 0o644)
	})
}
```

Apply to `internal/engine/session.go`:

```diff
diff --git a/internal/engine/session.go b/internal/engine/session.go
index d50e0c4..ef1ddb8 100644
--- a/internal/engine/session.go
+++ b/internal/engine/session.go
@@ -25,6 +25,10 @@ type sessionSpec struct {
 	before   string // a read-only session's snapshot of the leaf before it ran
 	maxTurns int
 	timeout  time.Duration
+	// scratch, when set, is the workspace a scratch agent works in, in place of a leaf: the session runs
+	// there, in the scratch sandbox of key, and a try that failed starts again from reseed's fresh copy.
+	scratch string
+	reseed  func() error
 	// started, when set, runs once, when the first try starts: after the meter let it, so a stop for
 	// a cap or a quota before the session logs nothing that says it started (review I5).
 	started func() error
@@ -86,12 +90,19 @@ func session(ctx context.Context, r *run.Run, sp sessionSpec) (gungnir.Result, g
 		if err := r.Log(begin); err != nil {
 			return stop(err)
 		}
-		runner, err := r.Runner(ctx, sp.repo)
+		var runner gungnir.Runner
+		workdir := r.RepoDir(sp.repo)
+		if sp.scratch != "" {
+			runner, err = r.ScratchRunner(ctx, sp.key)
+			workdir = sp.scratch
+		} else {
+			runner, err = r.Runner(ctx, sp.repo)
+		}
 		if err != nil {
 			// A sandbox that won't start is not a failure of the agent, and is not retried here (spec §12).
 			return stop(sandboxStart(err))
 		}
-		task := gungnir.Task{Role: sp.role, Node: sp.key, Attempt: attempt, Prompt: sp.text, Workdir: r.RepoDir(sp.repo),
+		task := gungnir.Task{Role: sp.role, Node: sp.key, Attempt: attempt, Prompt: sp.text, Workdir: workdir,
 			Model: role.Model, ReadOnly: sp.readOnly, MaxTurns: turnsFor(sp.maxTurns, left), Timeout: sp.timeout,
 			TranscriptDir: filepath.Join(r.Dir, "transcripts"), Sandbox: runner}
 		actx, cancel := ctx, context.CancelFunc(func() {})
@@ -159,6 +170,9 @@ func session(ctx context.Context, r *run.Run, sp sessionSpec) (gungnir.Result, g
 // as DiscardWork says. A read-only session's leaf is compared first: the reset would hide what it
 // changed (review I1).
 func setAside(ctx context.Context, r *run.Run, sp sessionSpec) error {
+	if sp.scratch != "" {
+		return sp.reseed() // a workspace holds nothing worth keeping: a try starts from a fresh one
+	}
 	if sp.readOnly {
 		if err := readOnly(context.WithoutCancel(ctx), r, sp.repo, sp.role, sp.before); err != nil {
 			return err
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 94720e3..e25a7f9 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -227,6 +227,8 @@ func (s *Setup) checkNode(ctx context.Context, graphPath string, n schema.Node)
 		return nil // they work in the project, not in a leaf
 	case n.Kind == schema.KindForeach:
 		return s.checkBody(graphPath, n)
+	case n.Kind == schema.KindAgent && n.Scratch:
+		return s.checkSession(graphPath, n.ID, n.Role, n.Prompt) // it works in a workspace of its own
 	}
 	if n.Repo == "" {
 		return fmt.Errorf("%s: node %s names no repo; every node that does work runs in a repo of the project", graphPath, n.ID)
```

Apply to `internal/run/sandbox.go`:

```diff
diff --git a/internal/run/sandbox.go b/internal/run/sandbox.go
index 8f36079..b5d2417 100644
--- a/internal/run/sandbox.go
+++ b/internal/run/sandbox.go
@@ -74,6 +74,40 @@ func (r *Run) Runner(ctx context.Context, repo string) (gungnir.Runner, error) {
 	return gungnir.Bind(r.Sandbox, env), nil
 }
 
+// ScratchDir is the workspace of a scratch agent node: a folder of the run, beside the leaves and apart
+// from them (spec §3.3 rule 1).
+func (r *Run) ScratchDir(node string) string { return filepath.Join(r.Dir, "scratch", node) }
+
+// ScratchRunner returns what runs commands in the sandbox of node's scratch workspace, starting it the
+// first time. It returns nil when the run has no sandbox: a scripted-only run works on the host. The
+// sandbox holds the workspace and nothing else, on the lead realm's stack, and is recorded under the
+// node's scratch name so that Advance, a resume and doctor stop it like a leaf's.
+func (r *Run) ScratchRunner(ctx context.Context, node string) (gungnir.Runner, error) {
+	if r.Sandbox == nil {
+		return nil, nil
+	}
+	key := "scratch/" + node
+	if env, ok := r.State.Sandboxes[key]; ok {
+		return gungnir.Bind(r.Sandbox, env), nil
+	}
+	env, err := r.Sandbox.Up(ctx, gungnir.SandboxSpec{Run: r.State.ID, Name: key, Parent: r.Dir, Leaf: r.ScratchDir(node), Scratch: true,
+		Egress: r.Setup.Sandbox.Egress, Stack: r.Setup.Pack.Sandbox.Stack})
+	if err != nil {
+		return nil, err
+	}
+	if r.State.Sandboxes == nil {
+		r.State.Sandboxes = map[string]gungnir.Env{}
+	}
+	r.State.Sandboxes[key] = env
+	if err := r.Log(gungnir.Event{Name: gungnir.EventSandboxUp, Note: fmt.Sprintf("%s: container %.12s", key, env.Container)}); err != nil {
+		return nil, err
+	}
+	if err := r.Save(); err != nil {
+		return nil, err
+	}
+	return gungnir.Bind(r.Sandbox, env), nil
+}
+
 // DownSandboxes stops every sandbox this process or an earlier one started for the run, and clears
 // the record of each one it stopped. A sandbox that won't stop stays recorded, for doctor.
 func (r *Run) DownSandboxes(ctx context.Context) error {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T183: publish copies a scratch agent's documents into the project and commits them, after checking they are documents and have no secret

Spec §3.3 rule 1: "Odin commits the planner's output into L1 after the `spec` approval point." The planner's output is data from an agent; it becomes part of the project only through this node.

**Files (in `odin`):**
- Create: `internal/engine/publish.go`, `internal/engine/publish_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/gates.go`

**Interfaces:**
- Produces: `engine.runPublish`, `listDocuments`, `scanDocuments`, `copyDocument`. Only regular files under `out/`, named with letters, digits, dots, dashes and underscores and not starting with a dot, ending in `.md .yaml .yml .json .txt .toml .d2 .mmd`, at most 500 files, 1 MiB each and 8 MiB in all. With a sandbox the documents are scanned for secrets in the scratch sandbox of the agent that wrote them; a secret is a hard stop at `real-secrets-or-user-data`, with nothing published (the gate file names the folder; approve once it is clean and the node runs again). The files are written under the node's `to` folder and committed with `git add` and `git commit` by explicit paths, with hooks off; staged work Odin did not make refuses the node; identical documents commit nothing.

**Acceptance criteria:**
- [ ] The agent's two documents land under `docs/` in one commit, and `docs_published` is logged.
- [ ] Publishing the same documents again makes no commit.
- [ ] A script, a hidden file or folder, a name with a space or a dollar, a symlink, a file over the limit and more than 500 files are refused.
- [ ] Staged work of the operator's is not committed; a secret found by the scan stops the run and publishes nothing.

**Named test:** `go test ./internal/engine -run 'TestPublishCopiesWhatAScratchAgentWroteIntoTheProjectAndCommitsIt|TestPublishingTheSameDocumentsAgainCommitsNothing|TestPublishRefusesWhatIsNotADocument|TestPublishWontCommitOverStagedWorkItDidNotMake|TestSecretsInTheDocumentsAreAHardStopAndNothingIsPublished'` in `odin`. **Layer:** `odin`. **Size:** M (372). **Depends on:** v0-T182.

- [ ] **Step 1:** write the tests.

Write `internal/engine/publish_test.go`:

```go
package engine

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
)

const publishNodes = "  - { id: design, kind: agent, role: planner, prompt: p.md, scratch: true }\n  - { id: design-gate, kind: gate, gate: design }\n" +
	"  - { id: design-docs, kind: publish, from: design, to: docs }\n"

const publishScript = "steps:\n  design:\n    - actions:\n        - write: { path: out/1-product/design.md, content: \"# Design\\n\" }\n        - write: { path: out/leaves.yaml, content: \"leaves: {}\\n\" }\n" +
	"      result: { status: ok, summary: wrote the design }\n"

func headFiles(t *testing.T, dir string) string {
	t.Helper()
	out, err := git.Run(context.Background(), dir, "show", "--name-only", "--format=", "HEAD")
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func TestPublishCopiesWhatAScratchAgentWroteIntoTheProjectAndCommitsIt(t *testing.T) {
	r := start(t, "unattended", "gates:\n  design: auto\n", publishNodes, publishScript)
	before, _ := git.Run(bg, r.Project, "rev-parse", "HEAD")
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if b, err := os.ReadFile(filepath.Join(r.Project, "docs", "1-product", "design.md")); err != nil || string(b) != "# Design\n" {
		t.Errorf("docs/1-product/design.md = %q, %v", b, err)
	}
	if got := headFiles(t, r.Project); got != "docs/1-product/design.md\ndocs/leaves.yaml" {
		t.Errorf("the commit holds %q; want the two documents, by their paths", got)
	}
	if msg, _ := git.Run(bg, r.Project, "log", "-1", "--format=%s"); !strings.HasPrefix(msg, "Publish design's documents (run "+r.State.ID+", node design-docs)") {
		t.Errorf("commit message = %q", msg)
	}
	if after, _ := git.Run(bg, r.Project, "rev-parse", "HEAD"); after == before {
		t.Error("nothing was committed")
	}
	if st, _ := git.Run(bg, r.Project, "status", "--porcelain", "--", "docs"); st != "" {
		t.Errorf("docs/ is left uncommitted: %q", st)
	}
	if text := ledgerText(t, r); !strings.Contains(text, `"event":"docs_published"`) || !strings.Contains(text, "2 file(s) under docs") {
		t.Errorf("the ledger lacks docs_published:\n%s", text)
	}
}

func TestPublishingTheSameDocumentsAgainCommitsNothing(t *testing.T) {
	r := start(t, "unattended", "gates:\n  design: auto\n", publishNodes, publishScript)
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	head, _ := git.Run(bg, r.Project, "rev-parse", "HEAD")
	n := r.Nodes()[2]
	if err := runPublish(bg, r, n); err != nil {
		t.Fatal(err)
	}
	if again, _ := git.Run(bg, r.Project, "rev-parse", "HEAD"); again != head {
		t.Error("publishing identical documents made a commit")
	}
	if got := r.State.Summaries["design-docs"]; !strings.Contains(got, "unchanged") {
		t.Errorf("summary = %q", got)
	}
}

func TestPublishRefusesWhatIsNotADocument(t *testing.T) {
	out := t.TempDir()
	put := func(rel, body string) {
		p := filepath.Join(out, rel)
		os.MkdirAll(filepath.Dir(p), 0o755)
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	put("docs/ok.md", "fine\n")
	if files, err := listDocuments(out); err != nil || strings.Join(files, ",") != "docs/ok.md" {
		t.Fatalf("listDocuments() = %v, %v", files, err)
	}
	cases := map[string]func(){
		"a script":             func() { put("run.sh", "rm -rf /\n") },
		"a hidden file":        func() { put(".env", "KEY=1\n") },
		"a hidden folder":      func() { put(".github/workflows/x.md", "x\n") },
		"a name with a space":  func() { put("a b.md", "x\n") },
		"a name with a dollar": func() { put("$(x).md", "x\n") },
		"a symlink":            func() { os.Symlink("/etc/passwd", filepath.Join(out, "docs", "link.md")) },
		"a big file":           func() { put("big.md", strings.Repeat("x", maxPublishFile+1)) },
		"an upper case ending is still an ending": nil,
	}
	delete(cases, "an upper case ending is still an ending")
	for name, add := range cases {
		os.RemoveAll(out)
		os.MkdirAll(out, 0o755)
		put("docs/ok.md", "fine\n")
		add()
		if _, err := listDocuments(out); err == nil {
			t.Errorf("%s: listDocuments() = nil error", name)
		}
	}
	os.RemoveAll(out)
	os.MkdirAll(out, 0o755)
	for i := 0; i <= maxPublishFiles; i++ {
		put("d/f"+strings.Repeat("a", 1+i%20)+string(rune('a'+i%26))+string(rune('a'+(i/26)%26))+string(rune('a'+(i/676)%26))+".md", "x\n")
	}
	if _, err := listDocuments(out); err == nil || !strings.Contains(err.Error(), "more than") {
		t.Errorf("too many files: %v", err)
	}
}

func TestPublishWontCommitOverStagedWorkItDidNotMake(t *testing.T) {
	r := start(t, "unattended", "gates:\n  design: auto\n", publishNodes, publishScript)
	os.WriteFile(filepath.Join(r.Project, "notes.txt"), []byte("mine\n"), 0o644)
	if _, err := git.Run(bg, r.Project, "add", "notes.txt"); err != nil {
		t.Fatal(err)
	}
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "staged changes Odin didn't make") {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if files := headFiles(t, r.Project); strings.Contains(files, "notes.txt") {
		t.Error("the operator's staged file was committed with the documents")
	}
}

func TestSecretsInTheDocumentsAreAHardStopAndNothingIsPublished(t *testing.T) {
	r, fake := startSandboxed(t, publishNodes, publishScript)
	fake.Scan.Exit, fake.Scan.Report = 7, secretReport
	head, _ := git.Run(bg, r.Project, "rev-parse", "HEAD")
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusStopped || r.State.PendingGate != gungnir.GateRealSecrets || out.Gate != "design-docs" {
		t.Fatalf("Advance() = %+v, %v, gate %s; want a stop at real-secrets-or-user-data", out, err, r.State.PendingGate)
	}
	if after, _ := git.Run(bg, r.Project, "rev-parse", "HEAD"); after != head {
		t.Error("documents with a secret in them were committed")
	}
	if _, err := os.Stat(filepath.Join(r.Project, "docs")); err == nil {
		t.Error("documents with a secret in them were copied into the project")
	}
	if len(fake.ScanFiles) != 1 || strings.Join(fake.ScanFiles[0], ",") != "out/1-product/design.md,out/leaves.yaml" {
		t.Errorf("the scan was given %q; want the two documents, as paths in the workspace", fake.ScanFiles)
	}
	b, _ := os.ReadFile(filepath.Join(r.Dir, "gates", "design-docs-1.md"))
	if !strings.Contains(string(b), "Nothing was published") || !strings.Contains(string(b), "scratch") {
		t.Errorf("the gate file = %s", b)
	}
	fake.Scan.Exit, fake.Scan.Report = 0, ""
	if err := Approve(bg, r, "design-docs", "a test key, removed"); err != nil {
		t.Fatal(err)
	}
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() after approval = %+v, %v", out, err)
	}
	if got := headFiles(t, r.Project); !strings.Contains(got, "docs/1-product/design.md") {
		t.Errorf("after approval the commit holds %q", got)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/publish_test.go:63:12: undefined: runPublish
internal/engine/publish_test.go:84:19: undefined: listDocuments
internal/engine/publish_test.go:94:70: undefined: maxPublishFile
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 3249a74..d27052b 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -93,6 +93,8 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 			err = runTasks(ctx, r, n)
 		case schema.KindForeach:
 			err = expandForeach(ctx, r, n)
+		case schema.KindPublish:
+			err = runPublish(ctx, r, n)
 		}
 		var sb *sentBack
 		var ex *expanded
```

Apply to `internal/engine/gates.go`:

```diff
diff --git a/internal/engine/gates.go b/internal/engine/gates.go
index 31ac71e..dff1462 100644
--- a/internal/engine/gates.go
+++ b/internal/engine/gates.go
@@ -124,6 +124,9 @@ func Approve(ctx context.Context, r *run.Run, gateID, note string) error {
 		s.Summaries[n.ID] = fmt.Sprintf("accepted by the operator after %d attempt(s), with %d finding(s) open", rec.State.Attempt-1, len(rec.State.Book.Open()))
 		delete(s.Reasons, n.ID)
 		s.Position++
+	case run.Quarantines(s.PendingGate) && n.Repo == "":
+		// A node that works in the project, such as a publish: nothing in a leaf to put back. The person
+		// edited the workspace the stop names, and the node runs again.
 	case run.Quarantines(s.PendingGate):
 		rec := s.Leaves[n.Repo]
 		l, err := r.Leaf(n.Repo)
@@ -237,6 +240,8 @@ func stopHard(r *run.Run, n schema.Node, h *hardStop) (Outcome, error) {
 		time.Now().UTC().Format(time.RFC3339), h.err)
 	fmt.Fprintf(&b, "## Decide\n\n    ygg approve %s %s [--note \"...\"]\n\n", s.ID, n.ID)
 	switch {
+	case run.Quarantines(h.gate) && n.Repo == "":
+		fmt.Fprintf(&b, "Nothing was published. The documents are in %s; remove what the scan found, and then approve: %s runs again.\n", filepath.Join(r.ScratchDir(n.From), "out"), n.ID)
 	case run.Quarantines(h.gate):
 		fmt.Fprintf(&b, "Until then the leaf %s stays as the node left it, for investigation. Approving puts it back to its last checkpoint and runs %s again; what the node wrote is not saved.\n", n.Repo, n.ID)
 	case h.gate == gungnir.GateBudgetCap && journalCap(h.err) && len(s.PendingSpend) > 0:
```

Write `internal/engine/publish.go`:

```go
package engine

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/ouroboric-dev/gleipnir/scan"
	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
)

// What a scratch agent may publish: documents, a few hundred of them. Anything else in out/ is refused,
// not skipped, so a planner that wrote a script finds out why it was not published.
const (
	maxPublishFiles = 500
	maxPublishFile  = 1 << 20
	maxPublishBytes = 8 << 20
)

var (
	publishExt  = []string{".md", ".yaml", ".yml", ".json", ".txt", ".toml", ".d2", ".mmd"}
	publishName = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)
)

// runPublish copies the documents a scratch agent wrote under out/ into the project, under the folder
// the node names, and commits them in the project umbrella (spec §3.3 rule 1: "Odin commits the
// planner's output into L1 after the spec approval point"). The files are checked first: only regular
// files with the names and endings of documents, in bounded number and size, and with no secret in
// them when the run has a sandbox to scan in. Odin commits with host git, by explicit paths.
func runPublish(ctx context.Context, r *run.Run, n schema.Node) error {
	attempt, err := startAttempt(r, n)
	if err != nil {
		return err
	}
	if err := r.Log(gungnir.Event{Name: gungnir.EventNodeStarted, Node: n.ID, Attempt: attempt}); err != nil {
		return err
	}
	out := filepath.Join(r.ScratchDir(n.From), "out")
	files, err := listDocuments(out)
	if err != nil {
		return &nodeFailure{fmt.Errorf("%s publishes what %s wrote, and %w", n.ID, n.From, err)}
	}
	if err := scanDocuments(ctx, r, n, files); err != nil {
		return err
	}
	project := r.Project
	if staged, err := git.Run(ctx, project, "diff", "--cached", "--name-only"); err != nil {
		return err
	} else if staged != "" {
		return &nodeFailure{fmt.Errorf("the project has staged changes Odin didn't make (%s); commit or unstage them first", strings.ReplaceAll(staged, "\n", ", "))}
	}
	var paths []string
	for _, rel := range files {
		dst := path.Join(n.To, rel)
		if err := copyDocument(filepath.Join(out, filepath.FromSlash(rel)), filepath.Join(project, filepath.FromSlash(dst))); err != nil {
			return &nodeFailure{fmt.Errorf("publishing %s: %w", dst, err)}
		}
		paths = append(paths, dst)
	}
	ev := gungnir.Event{Name: gungnir.EventDocsPublished, Node: n.ID, Attempt: attempt}
	if len(paths) > 0 {
		if _, err := git.Run(ctx, project, append([]string{"add", "--"}, paths...)...); err != nil {
			return err
		}
		if changed, err := git.Run(ctx, project, "diff", "--cached", "--name-only"); err != nil {
			return err
		} else if changed != "" {
			msg := fmt.Sprintf("Publish %s's documents (run %s, node %s)", n.From, r.State.ID, n.ID)
			if _, err := git.Run(ctx, project, append([]string{"commit", "-q", "-m", msg, "--"}, paths...)...); err != nil {
				return err
			}
			if ev.Commit, err = git.Run(ctx, project, "rev-parse", "HEAD"); err != nil {
				return err
			}
		}
	}
	switch {
	case len(paths) == 0:
		ev.Note = n.From + " wrote nothing under out/"
	case ev.Commit == "":
		ev.Note = fmt.Sprintf("%d file(s) under %s, unchanged", len(paths), n.To)
	default:
		ev.Note = fmt.Sprintf("%d file(s) under %s: %s", len(paths), n.To, strings.Join(paths[:min(len(paths), 5)], ", "))
	}
	r.State.Summaries[n.ID] = ev.Note
	return r.Log(ev)
}

// listDocuments lists the files under out as slash paths, sorted, and refuses what a document is not: a
// symlink, a special file, a hidden name, an odd character, an ending that is not a document's, a file
// over the size limit, or more files or bytes than the limits.
func listDocuments(out string) ([]string, error) {
	if st, err := os.Lstat(out); err != nil || !st.IsDir() {
		return nil, fmt.Errorf("its output folder %s is not there (the node has not run)", out)
	}
	var files []string
	var total int64
	err := filepath.WalkDir(out, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(out, p)
		if err != nil || rel == "." {
			return err
		}
		for _, seg := range strings.Split(filepath.ToSlash(rel), "/") {
			if !publishName.MatchString(seg) {
				return fmt.Errorf("%s has the name %q; a document's folders and files are named with letters, digits, dots, dashes and underscores, and do not start with a dot", rel, seg)
			}
		}
		if d.IsDir() {
			return nil
		}
		if !d.Type().IsRegular() {
			return fmt.Errorf("%s is %s, not a regular file", rel, d.Type())
		}
		if !slices.Contains(publishExt, strings.ToLower(filepath.Ext(rel))) {
			return fmt.Errorf("%s does not end like a document (%s)", rel, strings.Join(publishExt, ", "))
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		total += info.Size()
		switch {
		case info.Size() > maxPublishFile:
			return fmt.Errorf("%s is %d bytes; a document is at most %d", rel, info.Size(), maxPublishFile)
		case len(files) >= maxPublishFiles:
			return fmt.Errorf("it wrote more than %d files", maxPublishFiles)
		case total > maxPublishBytes:
			return fmt.Errorf("it wrote more than %d bytes", maxPublishBytes)
		}
		files = append(files, filepath.ToSlash(rel))
		return nil
	})
	slices.Sort(files)
	return files, err
}

// scanDocuments looks for secrets in the documents in the scratch sandbox of the node that wrote them,
// where gitleaks is pinned (spec §14). A run with no sandbox has nowhere to run the scanner, and only
// scripted agents. Secrets are a hard stop at real-secrets-or-user-data with nothing published; a scan
// that could not run fails the node, because no answer is never "clean".
func scanDocuments(ctx context.Context, r *run.Run, n schema.Node, files []string) error {
	runner, err := r.ScratchRunner(ctx, n.From)
	if err != nil {
		return sandboxStart(err)
	}
	if runner == nil || len(files) == 0 {
		return nil
	}
	listed := make([]string, len(files))
	for i, f := range files {
		listed[i] = path.Join("out", f)
	}
	err = scan.Run(ctx, runner, listed)
	var found *scan.FoundError
	switch {
	case err == nil:
		return nil
	case errors.As(err, &found):
		return &hardStop{gate: gungnir.GateRealSecrets, err: err}
	}
	return &nodeFailure{err}
}

// copyDocument writes src to dst, making dst's folders, and refuses to write through a symlink the project
// already has at dst or in its path: a document must land where the node says.
func copyDocument(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	for d := filepath.Dir(dst); ; d = filepath.Dir(d) {
		if st, err := os.Lstat(d); err == nil {
			if st.Mode()&fs.ModeSymlink != 0 {
				return fmt.Errorf("%s is a symlink", d)
			}
			break
		}
		if d == filepath.Dir(d) {
			break
		}
	}
	if st, err := os.Lstat(dst); err == nil && !st.Mode().IsRegular() {
		return fmt.Errorf("%s exists and is not a regular file", dst)
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0o644)
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T184: the local remote records a leaf's realm pin and what it consumes in the commit that creates the leaf

A leaf must never exist without its pin: the same commit that adds the submodule writes `realm`, `realm_version` and `consumes` in `umbrella.yaml`.

**Files (in `odin`):**
- Modify: `internal/remote/local.go`, `internal/remote/local_test.go`

**Interfaces:**
- Produces: `remote.Local.Create` writes `Repo.Realm`, `RealmVersion` and `Consumes` into the child entry; it refuses, before it creates anything, a consumer the umbrella does not list as a leaf.

**Acceptance criteria:**
- [ ] Two leaves are created with pins, the second consuming the first; `umbrella.yaml` is committed with them.
- [ ] A leaf that consumes a leaf the umbrella lacks is refused, with no commit, no folder and a clean umbrella.

**Named test:** `go test ./internal/remote -run 'TestLocalCreateRecordsTheRealmPinAndWhatTheLeafConsumesInTheSameCommit'` in `odin`. **Layer:** `odin`. **Size:** S (50). **Depends on:** v0-T142 (merged), v0-T143 (merged).

- [ ] **Step 1:** write the tests.

Apply to `internal/remote/local_test.go`:

```diff
diff --git a/internal/remote/local_test.go b/internal/remote/local_test.go
index c46d20e..c057d57 100644
--- a/internal/remote/local_test.go
+++ b/internal/remote/local_test.go
@@ -110,3 +110,46 @@ func TestLocalProtectDoesNotApply(t *testing.T) {
 		t.Error("Protect() changed the parent")
 	}
 }
+
+func TestLocalCreateRecordsTheRealmPinAndWhatTheLeafConsumesInTheSameCommit(t *testing.T) {
+	_, parent := gallery(t)
+	api := blog()
+	api.Name, api.Path, api.Realm, api.RealmVersion = "gallery-service", "repos/service", "helheim-go", "0.2.0"
+	web := blog()
+	web.Name, web.Path, web.Realm, web.RealmVersion, web.Consumes = "gallery-site", "repos/site", "midgard-react", "0.1.0", []string{"repos/service"}
+	l := NewLocal(parent)
+	if err := l.Create(ctx, api); err != nil {
+		t.Fatal(err)
+	}
+	if err := l.Create(ctx, web); err != nil {
+		t.Fatal(err)
+	}
+	u, err := schema.LoadUmbrella(parent.Dir)
+	if err != nil {
+		t.Fatal(err)
+	}
+	if c := u.Children["repos/service"]; c.Realm != "helheim-go" || c.RealmVersion != "0.2.0" || len(c.Consumes) != 0 {
+		t.Errorf("api = %+v", c)
+	}
+	if c := u.Children["repos/site"]; c.Realm != "midgard-react" || c.RealmVersion != "0.1.0" || len(c.Consumes) != 1 || c.Consumes[0] != "repos/service" {
+		t.Errorf("web = %+v", c)
+	}
+	if st, _ := git.Run(ctx, parent.Dir, "status", "--porcelain", "--", "umbrella.yaml"); st != "" {
+		t.Errorf("umbrella.yaml is left uncommitted: %q; the pin is in the commit that creates the leaf", st)
+	}
+	bad := blog()
+	bad.Path, bad.Name, bad.Consumes = "repos/ghost", "ghost", []string{"repos/nowhere"}
+	before, _ := git.Run(ctx, parent.Dir, "rev-parse", "HEAD")
+	if err := l.Create(ctx, bad); err == nil {
+		t.Error("a leaf that consumes a leaf the umbrella doesn't have was created")
+	}
+	if after, _ := git.Run(ctx, parent.Dir, "rev-parse", "HEAD"); after != before {
+		t.Error("the umbrella got a commit for a leaf that was refused")
+	}
+	if _, err := os.Stat(filepath.Join(parent.Dir, "repos", "ghost")); err == nil {
+		t.Error("a leaf that was refused left its folder behind")
+	}
+	if st, _ := git.Run(ctx, parent.Dir, "status", "--porcelain"); st != "" {
+		t.Errorf("a refused leaf left the umbrella dirty: %q", st)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestLocalCreateRecordsTheRealmPinAndWhatTheLeafConsumesInTheSameCommit (0.94s)
    local_test.go:132: api = {Kind:leaf Owner:ouroboric-dev Visibility:private Realm: RealmVersion: Consumes:[]}
    local_test.go:135: web = {Kind:leaf Owner:ouroboric-dev Visibility:private Realm: RealmVersion: Consumes:[]}
    local_test.go:144: a leaf that consumes a leaf the umbrella doesn't have was created
```

- [ ] **Step 3:** write the code.

Apply to `internal/remote/local.go`:

```diff
diff --git a/internal/remote/local.go b/internal/remote/local.go
index 5ce6b1e..53e1cd1 100644
--- a/internal/remote/local.go
+++ b/internal/remote/local.go
@@ -49,6 +49,11 @@ func (l *Local) Create(ctx context.Context, r gungnir.Repo) error {
 	if _, listed := p.Umbrella.Children[r.Path]; listed {
 		return fmt.Errorf("the umbrella %q already lists %s, so nothing was created", p.Path, r.Path)
 	}
+	for _, c := range r.Consumes {
+		if p.Umbrella.Children[c].Kind != schema.ChildLeaf {
+			return fmt.Errorf("%s consumes %s, which %q doesn't list as a leaf, so nothing was created", r.Path, c, p.Path)
+		}
+	}
 	if err := firstCommit(ctx, dir, r); err != nil {
 		return fmt.Errorf("creating %s: %w (remove %s before trying again)", r.Path, err, dir)
 	}
@@ -61,7 +66,8 @@ func (l *Local) Create(ctx context.Context, r gungnir.Repo) error {
 			return fmt.Errorf("adding %s to %q: %w", r.Path, p.Path, err)
 		}
 	}
-	p.Umbrella.Children[r.Path] = schema.Child{Kind: schema.ChildLeaf, Owner: r.Owner, Visibility: r.Visibility}
+	p.Umbrella.Children[r.Path] = schema.Child{Kind: schema.ChildLeaf, Owner: r.Owner, Visibility: r.Visibility,
+		Realm: r.Realm, RealmVersion: r.RealmVersion, Consumes: r.Consumes}
 	if err := p.Umbrella.Save(p.Dir); err != nil {
 		return err
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T185: a run can take the realms new pins name after it started, and records them

Init learns which realms the product needs only after the spec stage: the run takes them then.

**Files (in `odin`):**
- Modify: `internal/run/realms_test.go`, `internal/run/run.go`

**Interfaces:**
- Produces: `(*Run).AddRealms(extra []schema.Pin) error`: loads the realms the pins name that the run lacks, after checking every pin of the project, old and new, against each other and the store; records each in run.json and a `realm_loaded` line; a refused call changes nothing. `(*Setup).loadRealm` finds a realm already loaded, a recorded folder, or the store.

**Acceptance criteria:**
- [ ] A new pin loads its realm and records it; a second realm already held is not loaded or logged again; a pin at another version changes nothing.

**Named test:** `go test ./internal/run -run 'TestARunTakesTheRealmsNewPinsNameAfterItStarted'` in `odin`. **Layer:** `odin`. **Size:** S (92). **Depends on:** v0-T170.

- [ ] **Step 1:** write the tests.

Apply to `internal/run/realms_test.go`:

```diff
diff --git a/internal/run/realms_test.go b/internal/run/realms_test.go
index 033e29a..e69f0e4 100644
--- a/internal/run/realms_test.go
+++ b/internal/run/realms_test.go
@@ -213,3 +213,37 @@ func TestARunWontPinOverUncommittedWork(t *testing.T) {
 		}
 	}
 }
+
+func TestARunTakesTheRealmsNewPinsNameAfterItStarted(t *testing.T) {
+	store, cfg := realmStore(t, map[string]string{"midgard-react": "0.1.0", "helheim-go": "0.2.0"})
+	project := treetest.Build(t, pinned("midgard-react", "0.1.0", nil))
+	r, err := Start(ctx, Options{Project: project, Config: cfg, Realm: "midgard-react"})
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer r.Close()
+	if err := r.AddRealms([]schema.Pin{{Realm: "helheim-go", Version: "0.2.0", Where: "repos/api"}, {Realm: "midgard-react", Version: "0.1.0", Where: "repos/web"}}); err != nil {
+		t.Fatalf("AddRealms() = %v", err)
+	}
+	if got := strings.Join(r.Setup.Realms.Names(), ","); got != "helheim-go,midgard-react" {
+		t.Errorf("realms = %s", got)
+	}
+	if rec := r.State.Realms["helheim-go"]; rec.Version != "0.2.0" || rec.Dir != filepath.Join(store, "helheim-go") || len(rec.SHA256) != 64 {
+		t.Errorf("run.json records %+v", r.State.Realms)
+	}
+	if s, _ := LoadState(r.Dir); len(s.Realms) != 2 {
+		t.Errorf("run.json on disk holds %d realms", len(s.Realms))
+	}
+	ledger, _ := os.ReadFile(filepath.Join(r.Dir, "ledger.jsonl"))
+	if strings.Count(string(ledger), `"event":"realm_loaded"`) != 1 || !strings.Contains(string(ledger), `"ygg.realm.name":"helheim-go"`) {
+		t.Errorf("the ledger should hold one realm_loaded, for the realm that was new:\n%s", ledger)
+	}
+	// A pin that disagrees with one the run has changes nothing.
+	err = r.AddRealms([]schema.Pin{{Realm: "helheim-go", Version: "0.9.0", Where: "repos/db"}})
+	if err == nil || !strings.Contains(err.Error(), "helheim-go is pinned at 0.2.0 by repos/api") && !strings.Contains(err.Error(), "the realm store holds helheim-go 0.2.0, but repos/db pins 0.9.0") {
+		t.Errorf("AddRealms() = %v", err)
+	}
+	if len(r.Setup.Realms.Realms) != 2 || len(r.State.Realms) != 2 {
+		t.Error("a refused AddRealms changed the run")
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/run [github.com/ouroboric-dev/odin/internal/run.test]
internal/run/realms_test.go:225:14: r.AddRealms undefined (type *Run has no field or method AddRealms)
internal/run/realms_test.go:242:10: r.AddRealms undefined (type *Run has no field or method AddRealms)
FAIL	github.com/ouroboric-dev/odin/internal/run [build failed]
```

- [ ] **Step 3:** write the code.

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index e25a7f9..9935fac 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -76,6 +76,8 @@ type Setup struct {
 	Backoff      jormungandr.Backoff
 	Sleep        func(ctx context.Context, d time.Duration) error // nil: wait for real
 	PinLead      bool                                             // the lead realm was named, and the project doesn't pin one yet: Start pins it
+	store        *realm.Store                                     // where a realm is found by name; nil without factory.yaml's realms section
+	recorded     map[string]string                                // a resume: the folder of each realm the run recorded
 
 	Root        string               // the tree's root: the project, or an umbrella above it
 	ProjectPath string               // the project's path from the root
@@ -135,7 +137,8 @@ func Prepare(ctx context.Context, o Options) (*Setup, error) {
 	if err := s.findProject(ctx, o.Project); err != nil {
 		return nil, err
 	}
-	if s.Realms, err = s.collectRealms(store, o.Realms); err != nil {
+	s.store, s.recorded = store, o.Realms
+	if s.Realms, err = s.collectRealms(nil); err != nil {
 		return nil, err
 	}
 	for _, p := range o.Leaves {
@@ -322,11 +325,8 @@ func (s *Setup) checkSession(graphPath, node, role, prompt string) error {
 	return nil
 }
 
-// collectRealms loads the realms of the run: the lead's, and one for each realm the project's pins name.
-// The pins must agree with each other and with what the realm store holds (change realm-leaf-naming), so
-// a mismatch stops the run before anything is created or started. recorded holds the folders a resumed
-// run loaded its realms from.
-func (s *Setup) collectRealms(store *realm.Store, recorded map[string]string) (*realm.Set, error) {
+// projectPins returns the realm pins of the project: its lead realm's, and each leaf's.
+func (s *Setup) projectPins() []schema.Pin {
 	var pins []schema.Pin
 	if u := s.Project.Umbrella; u != nil {
 		for _, p := range u.Pins() {
@@ -335,19 +335,61 @@ func (s *Setup) collectRealms(store *realm.Store, recorded map[string]string) (*
 			}
 		}
 	}
-	return realm.Collect(s.Lead, pins, func(name string) (*realm.Realm, error) {
-		if dir, ok := recorded[name]; ok {
-			return realm.Load(dir)
+	return pins
+}
+
+// loadRealm finds a realm by name: one the run has already loaded, the folder a resumed run recorded,
+// or the realm store.
+func (s *Setup) loadRealm(name string) (*realm.Realm, error) {
+	if s.Realms != nil {
+		if r := s.Realms.Realms[name]; r != nil {
+			return r, nil
 		}
-		if store == nil {
-			return nil, errors.New("factory.yaml has no realms section to find it in")
+	}
+	if dir, ok := s.recorded[name]; ok {
+		return realm.Load(dir)
+	}
+	if s.store == nil {
+		return nil, errors.New("factory.yaml has no realms section to find it in")
+	}
+	dir, err := s.store.Find(name)
+	if err != nil {
+		return nil, err
+	}
+	return realm.Load(dir)
+}
+
+// collectRealms loads the realms of the run: the lead's, and one for each realm the project's pins and
+// extra name. The pins must agree with each other and with what the realm store holds (change
+// realm-leaf-naming), so a mismatch stops the run before anything is created or started.
+func (s *Setup) collectRealms(extra []schema.Pin) (*realm.Set, error) {
+	return realm.Collect(s.Lead, append(s.projectPins(), extra...), s.loadRealm)
+}
+
+// AddRealms loads the realms that extra pins name and the run doesn't have yet, after checking that
+// every pin of the project, the old and the new, agrees. The spec stage names the product's leaves and
+// their realms, and init is where they join the run. Each new realm is recorded in run.json and the
+// ledger.
+func (r *Run) AddRealms(extra []schema.Pin) error {
+	set, err := r.Setup.collectRealms(extra)
+	if err != nil {
+		return err
+	}
+	for _, name := range set.Names() {
+		if _, had := r.Setup.Realms.Realms[name]; had {
+			continue
 		}
-		dir, err := store.Find(name)
-		if err != nil {
-			return nil, err
+		x := set.Realms[name]
+		if r.State.Realms == nil {
+			r.State.Realms = map[string]RealmRecord{}
 		}
-		return realm.Load(dir)
-	})
+		r.State.Realms[name] = RealmRecord{Version: x.Version, Dir: x.Dir, SHA256: x.Hash}
+		if err := r.Log(gungnir.Event{Name: gungnir.EventRealmLoaded, Realm: x.Name, RealmVersion: x.Version, Note: "sha256:" + x.Hash}); err != nil {
+			return err
+		}
+	}
+	r.Setup.Realms = set
+	return r.Save()
 }
 
 // Realm returns the realm called name, or the lead realm for "".
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T186: init creates the leaves the spec stage named, each from its realm's template, and records the pins

Spec §4.2: "init (agent + exec): scaffolds leaves from templates." Change `realm-leaf-naming`: "`init` creates each missing leaf from its realm's template and records the leaf's realm and version in the project". The spec stage's `leaves.yaml`, approved at the spec gate and published into the project, is what init reads.

**Files (in `odin`):**
- Create: `internal/engine/init.go`, `internal/engine/init_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/foreach_test.go`

**Interfaces:**
- Produces: `engine.runInit`. It reads the leaves file (one regular file, under 1 MiB), takes the realms it names (v0-T185), creates each leaf the project lacks through the remote with the recipe's first-commit files, the realm, the version and the consumers (leaves a leaf consumes first), makes the leaf part of the run (v0-T175) and, while the leaf holds only its first commit, copies the rest of the realm's template to the run's branch in a checkpoint of its own. A leaf with history keeps what it has. It logs `repo_created` for each leaf, with the realm.

**Acceptance criteria:**
- [ ] The API leaf is created from the second realm's template and the web leaf from the lead's; `umbrella.yaml` records each pin and the consumer; each leaf's main holds only the first commit and the run's branch holds the template; the run knows both realms and leaves, and a resume does too.
- [ ] A leaf that consumes a leaf sorting after it is created after it.
- [ ] A realm without a leaf recipe is refused and nothing is created.

**Named test:** `go test ./internal/engine -run 'TestInitCreatesEachLeafFromTheTemplateOfItsRealmAndRecordsThePin|TestInitCreatesWhatALeafConsumesFirst|TestInitRefusesARealmWithNoLeafRecipe'` in `odin`. **Layer:** `odin`. **Size:** M (336). **Depends on:** v0-T184, v0-T185, v0-T175.

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/foreach_test.go`:

```diff
diff --git a/internal/engine/foreach_test.go b/internal/engine/foreach_test.go
index 970fbc8..3186de3 100644
--- a/internal/engine/foreach_test.go
+++ b/internal/engine/foreach_test.go
@@ -16,8 +16,9 @@ import (
 // when the leaf holds file.
 func recipeRealm(name, version, file, prompt string) realmFiles {
 	return realmFiles{name: name, version: version,
-		pack:  "checks:\n  unit: [sh, -c, \"test -f " + file + "\"]\nleaf:\n  description: the " + name + " leaf\n  template: templates/leaf\n  first_commit: [LICENSE]\n  implementer: prompts/implementer.md\n  checks: [unit]\n",
-		files: map[string]string{"templates/leaf/LICENSE": "licence\n", "prompts/implementer.md": prompt + "\n", "p.md": "Lead prompt.\n"}}
+		pack: "checks:\n  unit: [sh, -c, \"test -f " + file + "\"]\nleaf:\n  description: the " + name + " leaf\n  template: templates/leaf\n  first_commit: [LICENSE]\n  implementer: prompts/implementer.md\n  checks: [unit]\n",
+		files: map[string]string{"templates/leaf/LICENSE": "licence\n", "templates/leaf/AGENTS.md": "rules of " + name + "\n", "templates/leaf/docs/architecture.md": "# " + name + "\n",
+			"prompts/implementer.md": prompt + "\n", "p.md": "Lead prompt.\n"}}
 }
 
 const taskShape = `  - { id: ready, kind: tasks, from: tasks.md }
```

Write `internal/engine/init_test.go`:

```go
package engine

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
)

const initNode = "  - { id: leaves, kind: init, from: docs/leaves.yaml }\n"

const galleryLeaves = `leaves:
  repos/api:
    realm: helheim-go
    realm_version: 0.2.0
    description: The gallery's API.
  repos/web:
    realm: midgard-react
    realm_version: 0.1.0
    description: The gallery's web app.
    consumes: [repos/api]
`

// initRun starts a run on a project with no leaves, and writes the leaves file into it.
func initRun(t *testing.T, leaves string, realms ...realmFiles) *run.Run {
	t.Helper()
	if realms == nil {
		realms = []realmFiles{recipeRealm("midgard-react", "0.1.0", "web.txt", "Web."), recipeRealm("helheim-go", "0.2.0", "api.txt", "API.")}
	}
	r := startRealms(t, realmsSetup{nodes: initNode, script: "steps: {}\n", realms: realms})
	if err := os.MkdirAll(filepath.Join(r.Project, "docs"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(r.Project, "docs", "leaves.yaml"), []byte(leaves), 0o644); err != nil {
		t.Fatal(err)
	}
	return r
}

func TestInitCreatesEachLeafFromTheTemplateOfItsRealmAndRecordsThePin(t *testing.T) {
	r := initRun(t, galleryLeaves)
	ctx := context.Background()
	out, err := Advance(ctx, r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	u, err := schema.LoadUmbrella(r.Project)
	if err != nil {
		t.Fatal(err)
	}
	api, web := u.Children["repos/api"], u.Children["repos/web"]
	if api.Kind != schema.ChildLeaf || api.Realm != "helheim-go" || api.RealmVersion != "0.2.0" || web.Realm != "midgard-react" || web.RealmVersion != "0.1.0" || len(web.Consumes) != 1 || web.Consumes[0] != "repos/api" {
		t.Errorf("umbrella.yaml records api %+v and web %+v", api, web)
	}
	if st, _ := git.Run(ctx, r.Project, "status", "--porcelain", "--", "umbrella.yaml", ".gitmodules"); st != "" {
		t.Errorf("the project's record of the leaves is left uncommitted: %q", st)
	}
	for leaf, realmName := range map[string]string{"repos/api": "helheim-go", "repos/web": "midgard-react"} {
		l, err := r.Leaf(leaf)
		if err != nil {
			t.Fatalf("%s: %v", leaf, err)
		}
		if first, _ := l.Git(ctx, "ls-tree", "-r", "--name-only", "main"); first != "LICENSE" {
			t.Errorf("%s: main holds %q; the first commit is the recipe's first_commit files", leaf, first)
		}
		if b, _ := os.ReadFile(filepath.Join(l.Dir(), "AGENTS.md")); string(b) != "rules of "+realmName+"\n" {
			t.Errorf("%s: AGENTS.md = %q; the template of its own realm", leaf, b)
		}
		if _, err := os.Stat(filepath.Join(l.Dir(), "docs", "architecture.md")); err != nil {
			t.Errorf("%s: the template's folders are copied: %v", leaf, err)
		}
		if branch, _ := l.Git(ctx, "branch", "--show-current"); branch != run.Branch(r.State.ID) {
			t.Errorf("%s is on %q, want the run's branch", leaf, branch)
		}
		if st, _ := l.Git(ctx, "status", "--porcelain"); st != "" {
			t.Errorf("%s: the template is left uncommitted: %q", leaf, st)
		}
		if rec := r.State.Leaves[leaf]; rec.Checkpoint == rec.Base || rec.Branch == "" {
			t.Errorf("%s: record %+v; the checkpoint is the template's commit, after the base", leaf, rec)
		}
	}
	if r.Setup.RealmOf("repos/api").Name != "helheim-go" || r.Setup.RealmOf("repos/web").Name != "midgard-react" {
		t.Error("the run does not use each new leaf's realm")
	}
	if rec := r.State.Realms["helheim-go"]; rec.Version != "0.2.0" || len(rec.SHA256) != 64 {
		t.Errorf("run.json lacks the realm init loaded: %+v", r.State.Realms)
	}
	text := ledgerText(t, r)
	if strings.Count(text, `"event":"repo_created"`) != 2 || !strings.Contains(text, `"event":"realm_loaded"`) || !strings.Contains(text, `"ygg.realm.name":"helheim-go"`) {
		t.Errorf("the ledger lacks repo_created and realm_loaded lines:\n%s", text)
	}
	if got := r.State.Summaries["leaves"]; !strings.Contains(got, "created 2 leaf(s) (repos/api, repos/web)") {
		t.Errorf("summary = %q", got)
	}
	// A resume knows the realms and the leaves init added.
	id, project := r.State.ID, r.Project
	r.Close()
	again, err := run.Open(ctx, project, id, "")
	if err != nil {
		t.Fatalf("Open() = %v", err)
	}
	defer again.Close()
	if len(again.Setup.Realms.Realms) != 2 || len(again.Setup.Leaves()) != 2 {
		t.Errorf("a resumed run has realms %v and leaves %v", again.Setup.Realms.Names(), again.Setup.Leaves())
	}
}

func TestInitCreatesWhatALeafConsumesFirst(t *testing.T) {
	leaves := strings.NewReplacer("repos/api", "repos/z-api", "repos/web", "repos/a-web").Replace(galleryLeaves)
	r := initRun(t, leaves)
	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v; repos/a-web consumes repos/z-api, which sorts after it", out, err)
	}
	u, _ := schema.LoadUmbrella(r.Project)
	if got := u.Children["repos/a-web"].Consumes; len(got) != 1 || got[0] != "repos/z-api" {
		t.Errorf("a-web consumes %v", got)
	}
}

func TestInitRefusesARealmWithNoLeafRecipe(t *testing.T) {
	bare := realmFiles{name: "helheim-go", version: "0.2.0"}
	r := initRun(t, galleryLeaves, recipeRealm("midgard-react", "0.1.0", "web.txt", "Web."), bare)
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "the realm helheim-go offers no leaf recipe") {
		t.Errorf("Advance() = %+v, %v", out, err)
	}
	if u, _ := schema.LoadUmbrella(r.Project); len(u.Children) != 0 {
		t.Errorf("init created %v for a realm that can't provide a leaf", u.Paths())
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestInitCreatesEachLeafFromTheTemplateOfItsRealmAndRecordsThePin (0.19s)
    init_test.go:58: umbrella.yaml records api {Kind: Owner: Visibility: Realm: RealmVersion: Consumes:[]} and web {Kind: Owner: Visibility: Realm: RealmVersion: Consumes:[]}
    init_test.go:66: repos/api:  is not a checked-out leaf
--- FAIL: TestInitCreatesWhatALeafConsumesFirst (0.33s)
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index d27052b..4bcfe60 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -95,6 +95,8 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 			err = expandForeach(ctx, r, n)
 		case schema.KindPublish:
 			err = runPublish(ctx, r, n)
+		case schema.KindInit:
+			err = runInit(ctx, r, n)
 		}
 		var sb *sentBack
 		var ex *expanded
```

Write `internal/engine/init.go`:

```go
package engine

import (
	"context"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/remote"
	"github.com/ouroboric-dev/odin/internal/run"
)

// runInit creates the leaves the spec stage named, each from the template of the realm that provides it,
// and records each leaf's realm and version in the project (spec §4.2, change realm-leaf-naming). The
// operator approved the leaves file at the spec gate; here Odin reads it exactly, checks that the realms
// it names agree with the project's pins and offer what a leaf needs, and only then creates anything.
// A leaf the project has already must be pinned as the file says; it is left as it is. Run again after
// a stop, the node finds what it made and finishes the rest.
func runInit(ctx context.Context, r *run.Run, n schema.Node) error {
	attempt, err := startAttempt(r, n)
	if err != nil {
		return err
	}
	if err := r.Log(gungnir.Event{Name: gungnir.EventNodeStarted, Node: n.ID, Attempt: attempt}); err != nil {
		return err
	}
	spec, err := readLeaves(r, n)
	if err != nil {
		return &nodeFailure{err}
	}
	if err := r.AddRealms(spec.Pins()); err != nil {
		return &nodeFailure{err}
	}
	for _, p := range spec.Paths() {
		if r.Setup.Realms.Realms[spec.Leaves[p].Realm].Pack.Leaf == nil {
			return &nodeFailure{fmt.Errorf("%s: the realm %s offers no leaf recipe, so it can't provide a leaf", p, spec.Leaves[p].Realm)}
		}
	}
	var created, kept []string
	for _, p := range initOrder(spec) {
		made, err := initLeaf(ctx, r, n, p, spec.Leaves[p])
		if err != nil {
			return err
		}
		if made {
			created = append(created, p)
		} else {
			kept = append(kept, p)
		}
	}
	r.State.Summaries[n.ID] = fmt.Sprintf("created %d leaf(s) (%s); %d already there (%s)", len(created), strings.Join(created, ", "), len(kept), strings.Join(kept, ", "))
	return r.Log(gungnir.Event{Name: gungnir.EventNodeFinished, Node: n.ID, Attempt: attempt, Result: r.State.Summaries[n.ID]})
}

// readLeaves reads and parses the leaves file n names.
func readLeaves(r *run.Run, n schema.Node) (*schema.Leaves, error) {
	file := filepath.Join(r.Project, filepath.FromSlash(n.From))
	st, err := os.Lstat(file)
	if err != nil || !st.Mode().IsRegular() {
		return nil, fmt.Errorf("the leaves file %s is not there as a regular file; the spec stage names the product's leaves in it", n.From)
	}
	f, err := os.Open(file)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, 1<<20))
	if err != nil {
		return nil, err
	}
	return schema.ParseLeaves(n.From, data)
}

// initOrder puts the leaves a leaf consumes before it, since a remote records a leaf's consumers only if
// they exist; otherwise the order of the paths.
func initOrder(spec *schema.Leaves) []string {
	var out []string
	done := map[string]bool{}
	var visit func(p string)
	visit = func(p string) {
		if done[p] {
			return
		}
		done[p] = true
		for _, q := range spec.Leaves[p].Consumes {
			if _, listed := spec.Leaves[q]; listed {
				visit(q)
			}
		}
		out = append(out, p)
	}
	for _, p := range spec.Paths() {
		visit(p)
	}
	return out
}

// initLeaf makes leaf p real: it creates it through the remote when the project lacks it, makes it part
// of the run, and, while the leaf holds only its first commit, adds the rest of the realm's template to
// the run's branch in a checkpoint of its own. It reports whether it created the leaf.
func initLeaf(ctx context.Context, r *run.Run, n schema.Node, p string, l schema.LeafSpec) (created bool, err error) {
	s := r.Setup
	rl := s.Realms.Realms[l.Realm]
	recipe := rl.Pack.Leaf
	if _, has := s.Project.Umbrella.Children[p]; !has {
		files := map[string][]byte{}
		for _, f := range recipe.FirstCommit {
			b, err := os.ReadFile(filepath.Join(rl.Dir, recipe.Template, f))
			if err != nil {
				return false, err
			}
			files[f] = b
		}
		repo := gungnir.Repo{Owner: s.Project.Owner, Name: filepath.Base(p), Visibility: s.Project.Visibility, Description: l.Description,
			Path: p, Files: files, Realm: l.Realm, RealmVersion: l.RealmVersion, Consumes: l.Consumes}
		rem := remote.NewLocal(s.Project)
		if err := rem.Create(ctx, repo); err != nil {
			return false, &nodeFailure{err}
		}
		created = true
		if err := r.Log(gungnir.Event{Name: gungnir.EventRepoCreated, Node: n.ID, Realm: l.Realm, RealmVersion: l.RealmVersion,
			Note: fmt.Sprintf("%s (%s remote)", p, rem.Name())}); err != nil {
			return created, err
		}
	}
	if err := r.AddLeaf(ctx, p); err != nil {
		return created, &nodeFailure{err}
	}
	lf, err := r.Leaf(p)
	if err != nil {
		return created, err
	}
	if count, err := lf.Git(ctx, "rev-list", "--count", "HEAD"); err != nil || count != "1" {
		return created, err // the leaf has history beyond its first commit: its template was applied, or it is not new
	}
	if err := copyTemplate(filepath.Join(rl.Dir, recipe.Template), lf.Dir(), recipe.FirstCommit); err != nil {
		return created, &nodeFailure{fmt.Errorf("copying the template of %s into %s: %w", l.Realm, p, err)}
	}
	head, _, err := lf.Checkpoint(ctx, fmt.Sprintf("ygg: run %s, node %s: the %s template", r.State.ID, n.ID, l.Realm))
	if err != nil {
		return created, err
	}
	rec := r.State.Leaves[p]
	rec.Checkpoint = head
	r.State.Leaves[p] = rec
	return created, r.Save()
}

// copyTemplate copies the template's files into the leaf, except the first commit's, which the leaf has.
// A template is the realm's own text; a link or any file but a regular one in it is refused.
func copyTemplate(tmpl, dst string, first []string) error {
	return filepath.WalkDir(tmpl, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(tmpl, p)
		if err != nil || rel == "." {
			return err
		}
		if d.Name() == ".git" {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		target := filepath.Join(dst, rel)
		if d.IsDir() {
			return os.MkdirAll(target, 0o755)
		}
		if !d.Type().IsRegular() {
			return fmt.Errorf("%s is %s, not a regular file", p, d.Type())
		}
		if slices.Contains(first, filepath.ToSlash(rel)) {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		data, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		mode := os.FileMode(0o644)
		if info.Mode()&0o111 != 0 {
			mode = 0o755
		}
		return os.WriteFile(target, data, mode)
	})
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T187: init refuses, before it creates anything, a leaves file it can't make real

The leaves file is an agent's output, approved by a person who may not read every line. Init checks what it can before it changes the project.

**Files (in `odin`):**
- Modify: `internal/engine/init.go`, `internal/engine/init_test.go`

**Interfaces:**
- Produces: `engine.checkLeaves`: every problem is listed — a pin of the lead realm at another version, a realm the store lacks or that offers no recipe, a leaf the project has as an umbrella, as another realm or version, or consuming other leaves than the file says, and a consumed leaf that neither the file nor the project has. Nothing is created if any is found.

**Acceptance criteria:**
- [ ] Each of those leaves the project with no new leaf.
- [ ] A second pass over a finished project creates nothing and keeps what is there; a leaf that exists as another realm is refused.

**Named test:** `go test ./internal/engine -run 'TestInitRefusesBeforeItCreatesAnything|TestInitLeavesALeafThatExistsAsItIsAndRefusesToRepinIt'` in `odin`. **Layer:** `odin`. **Size:** S (96). **Depends on:** v0-T186.

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/init_test.go`:

```diff
diff --git a/internal/engine/init_test.go b/internal/engine/init_test.go
index ac29382..beefa84 100644
--- a/internal/engine/init_test.go
+++ b/internal/engine/init_test.go
@@ -122,6 +122,29 @@ func TestInitCreatesWhatALeafConsumesFirst(t *testing.T) {
 	}
 }
 
+func TestInitRefusesBeforeItCreatesAnything(t *testing.T) {
+	cases := map[string]struct{ leaves, want string }{
+		"a pin of the lead realm at another version": {strings.Replace(galleryLeaves, "realm_version: 0.1.0", "realm_version: 0.3.0", 1), "midgard-react is pinned at 0.1.0 by . and at 0.3.0 by repos/web"},
+		"a realm the store lacks":                    {strings.Replace(galleryLeaves, "helheim-go", "asgard", 1), "asgard"},
+		"a leaf that consumes a leaf nobody has":     {strings.Replace(galleryLeaves, "consumes: [repos/api]", "consumes: [repos/db]", 1), "it consumes repos/db"},
+		"no leaves file":                             {"", "is not there as a regular file"},
+	}
+	for name, c := range cases {
+		r := initRun(t, c.leaves)
+		if c.leaves == "" {
+			os.Remove(filepath.Join(r.Project, "docs", "leaves.yaml"))
+		}
+		out, err := Advance(context.Background(), r)
+		if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), c.want) {
+			t.Errorf("%s: Advance() = %+v, %v; want a failure mentioning %q", name, out, err, c.want)
+		}
+		u, _ := schema.LoadUmbrella(r.Project)
+		if len(u.Children) != 0 {
+			t.Errorf("%s: init created %v before refusing", name, u.Paths())
+		}
+	}
+}
+
 func TestInitRefusesARealmWithNoLeafRecipe(t *testing.T) {
 	bare := realmFiles{name: "helheim-go", version: "0.2.0"}
 	r := initRun(t, galleryLeaves, recipeRealm("midgard-react", "0.1.0", "web.txt", "Web."), bare)
@@ -133,3 +156,37 @@ func TestInitRefusesARealmWithNoLeafRecipe(t *testing.T) {
 		t.Errorf("init created %v for a realm that can't provide a leaf", u.Paths())
 	}
 }
+
+func TestInitLeavesALeafThatExistsAsItIsAndRefusesToRepinIt(t *testing.T) {
+	r := initRun(t, galleryLeaves)
+	ctx := context.Background()
+	if out, err := Advance(ctx, r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+	// The implementer's work on the leaf must not be undone by a second pass through init.
+	api, _ := r.Leaf("repos/api")
+	os.WriteFile(filepath.Join(api.Dir(), "api.txt"), []byte("work\n"), 0o644)
+	os.Remove(filepath.Join(api.Dir(), "AGENTS.md"))
+	if _, _, err := api.Checkpoint(ctx, "work"); err != nil {
+		t.Fatal(err)
+	}
+	r.State.Position = 0
+	if out, err := Advance(ctx, r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("the second Advance() = %+v, %v", out, err)
+	}
+	if _, err := os.Stat(filepath.Join(api.Dir(), "AGENTS.md")); err == nil {
+		t.Error("init put the template back into a leaf that has history")
+	}
+	if got := r.State.Summaries["leaves"]; !strings.Contains(got, "created 0 leaf(s) ()") || !strings.Contains(got, "2 already there") {
+		t.Errorf("summary = %q", got)
+	}
+	// Another realm for a leaf that exists is a change of the project, not of a run.
+	if err := os.WriteFile(filepath.Join(r.Project, "docs", "leaves.yaml"), []byte(strings.Replace(galleryLeaves, "helheim-go\n    realm_version: 0.2.0", "midgard-react\n    realm_version: 0.1.0", 1)), 0o644); err != nil {
+		t.Fatal(err)
+	}
+	r.State.Position = 0
+	out, err := Advance(ctx, r)
+	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "the project has this leaf from helheim-go 0.2.0, and the leaves file names midgard-react 0.1.0") {
+		t.Errorf("Advance() = %+v, %v", out, err)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestInitRefusesBeforeItCreatesAnything (0.94s)
    init_test.go:139: a leaf that consumes a leaf nobody has: Advance() = {Status:failed Gate: Err:node leaves: repos/web consumes repos/db, which "" doesn't list as a leaf, so nothing was created Warn:[]}, <nil>; want a failure mentioning "it consumes repos/db"
    init_test.go:143: a leaf that consumes a leaf nobody has: init created [repos/api] before refusing
--- FAIL: TestInitLeavesALeafThatExistsAsItIsAndRefusesToRepinIt (0.66s)
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/init.go`:

```diff
diff --git a/internal/engine/init.go b/internal/engine/init.go
index e03a4ae..1c57fc8 100644
--- a/internal/engine/init.go
+++ b/internal/engine/init.go
@@ -37,10 +37,8 @@ func runInit(ctx context.Context, r *run.Run, n schema.Node) error {
 	if err := r.AddRealms(spec.Pins()); err != nil {
 		return &nodeFailure{err}
 	}
-	for _, p := range spec.Paths() {
-		if r.Setup.Realms.Realms[spec.Leaves[p].Realm].Pack.Leaf == nil {
-			return &nodeFailure{fmt.Errorf("%s: the realm %s offers no leaf recipe, so it can't provide a leaf", p, spec.Leaves[p].Realm)}
-		}
+	if err := checkLeaves(r, spec); err != nil {
+		return &nodeFailure{err}
 	}
 	var created, kept []string
 	for _, p := range initOrder(spec) {
@@ -77,6 +75,43 @@ func readLeaves(r *run.Run, n schema.Node) (*schema.Leaves, error) {
 	return schema.ParseLeaves(n.From, data)
 }
 
+// checkLeaves checks, before anything is created, that each leaf can be: its realm offers a leaf recipe,
+// one that exists already is pinned as the file says, and what a leaf consumes will exist.
+func checkLeaves(r *run.Run, spec *schema.Leaves) error {
+	var problems []string
+	have := r.Setup.Project.Umbrella.Children
+	for _, p := range spec.Paths() {
+		l := spec.Leaves[p]
+		rl := r.Setup.Realms.Realms[l.Realm]
+		if rl.Pack.Leaf == nil {
+			problems = append(problems, fmt.Sprintf("%s: the realm %s offers no leaf recipe (a template, an implementer prompt and checks), so it can't provide a leaf", p, l.Realm))
+		}
+		if c, ok := have[p]; ok {
+			realmName, version := c.Realm, c.RealmVersion
+			if realmName == "" { // a leaf with no pin is the lead realm's
+				realmName, version = r.Setup.Lead.Name, r.Setup.Lead.Version
+			}
+			switch {
+			case c.Kind != schema.ChildLeaf:
+				problems = append(problems, fmt.Sprintf("%s: the project has an umbrella there, not a leaf", p))
+			case realmName != l.Realm || version != l.RealmVersion:
+				problems = append(problems, fmt.Sprintf("%s: the project has this leaf from %s %s, and the leaves file names %s %s", p, realmName, version, l.Realm, l.RealmVersion))
+			case !slices.Equal(c.Consumes, l.Consumes):
+				problems = append(problems, fmt.Sprintf("%s: the project has this leaf consuming %v, and the leaves file says %v; rewiring a leaf that exists is not something a run does", p, c.Consumes, l.Consumes))
+			}
+		}
+		for _, q := range l.Consumes {
+			if _, listed := spec.Leaves[q]; !listed && have[q].Kind != schema.ChildLeaf {
+				problems = append(problems, fmt.Sprintf("%s: it consumes %s, which neither the file nor the project has as a leaf", p, q))
+			}
+		}
+	}
+	if len(problems) > 0 {
+		return fmt.Errorf("the leaves file can't be made real, so nothing was created:\n  %s", strings.Join(problems, "\n  "))
+	}
+	return nil
+}
+
 // initOrder puts the leaves a leaf consumes before it, since a remote records a leaf's consumers only if
 // they exist; otherwise the order of the paths.
 func initOrder(spec *schema.Leaves) []string {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T188: ygg sandbox build builds the stack of every realm named, or of all in the store

Each realm has a stack layer, and only `ygg sandbox build` pulls and builds images (a run never does: spec §16 item 7).

**Files (in `odin`):**
- Create: `internal/cli/sandbox_realms_test.go`
- Modify: `internal/cli/cli.go`, `internal/cli/sandbox.go`

**Interfaces:**
- Produces: `ygg sandbox build (--realm <name|dir>)... | --all`: the distinct stacks of the realms named, or of every realm of the store (a realm without a stack is skipped, with a line, under `--all`, and is an error when named). `--realm` takes a name found in `realms.dir` or a folder; `run`'s usage says so too.

**Acceptance criteria:**
- [ ] Two realms named build two stacks; `--all` builds each stack once and says which realm it skipped.
- [ ] Neither or both of `--realm` and `--all`, an unknown name, a name with no store, `--all` with no store and a named realm with no stack are refused.

**Named test:** `go test ./internal/cli -run 'TestSandboxBuild'` in `odin`. **Layer:** `odin`. **Size:** M (175). **Depends on:** v0-T170.

- [ ] **Step 1:** write the tests.

Write `internal/cli/sandbox_realms_test.go`:

```go
package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const (
	goStack   = "docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514"
	nodeStack = "docker.io/library/node:24.1.0-bookworm@sha256:3333333333333333333333333333333333333333333333333333333333333333"
)

// realmsStore writes a realm store: midgard-react and helheim-go on stacks of their own, a third realm on
// the first one's stack, and a documents realm with no stack. It returns the store and a config for it.
func realmsStore(t *testing.T) (store, config string) {
	t.Helper()
	store = t.TempDir()
	for name, stack := range map[string]string{"midgard-react": nodeStack, "helheim-go": goStack, "midgard-vue": nodeStack, "asgard": ""} {
		body := "name: " + name + "\nversion: 0.1.0\n"
		if stack != "" {
			body += "sandbox:\n  stack: " + stack + "\n"
		}
		if err := os.MkdirAll(filepath.Join(store, name), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(store, name, "pack.yaml"), []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	_, plain := project(t, "script.yaml", "")
	b, _ := os.ReadFile(plain)
	config = filepath.Join(t.TempDir(), "factory.yaml")
	if err := os.WriteFile(config, append(b, []byte(sandboxExtra+"realms:\n  dir: "+store+"\n")...), 0o644); err != nil {
		t.Fatal(err)
	}
	return store, config
}

func builds(log string) []string {
	b, _ := os.ReadFile(log)
	var out []string
	for _, line := range strings.Split(string(b), "\n") {
		if strings.Contains(line, "--target work") {
			out = append(out, line)
		}
	}
	return out
}

func TestSandboxBuildBuildsTheStackOfEveryRealmNamed(t *testing.T) {
	log := stubEngine(t)
	_, config := realmsStore(t)
	code, out, errOut := ygg(t, "sandbox", "build", "--config", config, "--realm", "midgard-react", "--realm", "helheim-go")
	if code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	got := builds(log)
	if len(got) != 2 || !strings.Contains(strings.Join(got, "\n"), "STACK_IMAGE="+nodeStack) || !strings.Contains(strings.Join(got, "\n"), "STACK_IMAGE="+goStack) {
		t.Errorf("work images built:\n%s", strings.Join(got, "\n"))
	}
	if strings.Count(out, "Built:") != 2 {
		t.Errorf("output:\n%s", out)
	}
}

func TestSandboxBuildAllBuildsEachStackOnceAndSkipsRealmsWithNone(t *testing.T) {
	log := stubEngine(t)
	_, config := realmsStore(t)
	code, out, errOut := ygg(t, "sandbox", "build", "--config", config, "--all")
	if code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	if got := builds(log); len(got) != 2 {
		t.Errorf("%d work images built, want one for each of the two stacks (midgard-vue shares midgard-react's):\n%s", len(got), strings.Join(got, "\n"))
	}
	if !strings.Contains(out, "asgard names no sandbox stack; skipped") {
		t.Errorf("output lacks the skipped realm:\n%s", out)
	}
}

func TestSandboxBuildNeedsARealmOrAllAndAStoreForNames(t *testing.T) {
	stubEngine(t)
	store, config := realmsStore(t)
	_ = store
	_, noStore := project(t, "script.yaml", "")
	noStore = withSandbox(t, noStore)
	for name, args := range map[string][]string{
		"neither":                     {"sandbox", "build", "--config", config},
		"all with a realm":            {"sandbox", "build", "--config", config, "--all", "--realm", "midgard-react"},
		"a name the store lacks":      {"sandbox", "build", "--config", config, "--realm", "nowhere"},
		"a name with no store":        {"sandbox", "build", "--config", noStore, "--realm", "midgard-react"},
		"all with no store":           {"sandbox", "build", "--config", noStore, "--all"},
		"a named realm with no stack": {"sandbox", "build", "--config", config, "--realm", "asgard"},
	} {
		if code, _, _ := ygg(t, args...); code != ExitRefused {
			t.Errorf("%s: exit %d, want %d", name, code, ExitRefused)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestSandboxBuildBuildsTheStackOfEveryRealmNamed (0.04s)
    sandbox_realms_test.go:57: exit 2:
        ygg: open helheim-go/pack.yaml: no such file or directory
--- FAIL: TestSandboxBuildAllBuildsEachStackOnceAndSkipsRealmsWithNone (0.04s)
```

- [ ] **Step 3:** write the code.

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 83ee360..9db0627 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -30,13 +30,13 @@ const (
 )
 
 const usage = `usage:
-  ygg run     --realm <dir> [--project <dir>] [--config <factory.yaml>] [--brief <file>] [--mode <mode>]
+  ygg run     --realm <name|dir> [--project <dir>] [--config <factory.yaml>] [--brief <file>] [--mode <mode>]
   ygg resume  <run-id> [--project <dir>] [--mode <mode>]
   ygg approve <run-id> <gate> [--note <text>] [--project <dir>] [--mode <mode>]
   ygg reject  <run-id> <gate> --reason <text> [--project <dir>] [--mode <mode>]
   ygg status  <run-id> [--project <dir>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
-  ygg sandbox build --realm <dir> [--config <factory.yaml>]
+  ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
 exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point, 4 paused: the provider's quota is used up
 `
 
@@ -67,6 +67,8 @@ type command struct {
 // flags holds every flag; each command reads the ones it defines.
 type flags struct {
 	project, config, realm, brief, mode, note, reason, root string
+	realms                                                  []string        // sandbox build: every --realm given
+	all                                                     bool            // sandbox build: --all
 	set                                                     map[string]bool // the flags given
 }
 
@@ -119,7 +121,7 @@ func (c *command) refuse(err error) int {
 func (c *command) run(args []string) int {
 	f, _, ok := c.parse("run", args, 0, func(fs *flag.FlagSet, f *flags) {
 		fs.StringVar(&f.config, "config", "factory.yaml", "the factory config")
-		fs.StringVar(&f.realm, "realm", "", "the realm directory (holds pack.yaml)")
+		fs.StringVar(&f.realm, "realm", "", "the lead realm: a name found in factory.yaml's realms.dir, or the directory that holds pack.yaml")
 		fs.StringVar(&f.brief, "brief", "", "the brief")
 	})
 	if !ok {
```

Apply to `internal/cli/sandbox.go`:

```diff
diff --git a/internal/cli/sandbox.go b/internal/cli/sandbox.go
index 4de8479..5c542ae 100644
--- a/internal/cli/sandbox.go
+++ b/internal/cli/sandbox.go
@@ -1,12 +1,16 @@
 package cli
 
 import (
+	"errors"
 	"flag"
 	"fmt"
 	"os"
+	"path/filepath"
+	"slices"
 
 	"github.com/ouroboric-dev/gleipnir/sandbox"
 	"github.com/ouroboric-dev/gungnir/schema"
+	"github.com/ouroboric-dev/odin/internal/realm"
 )
 
 // sandbox runs ygg sandbox build: the one command that pulls and builds images. A run never does
@@ -19,13 +23,17 @@ func (c *command) sandbox(args []string) int {
 	}
 	f, _, ok := c.parse("sandbox build", args[1:], 0, func(fs *flag.FlagSet, f *flags) {
 		fs.StringVar(&f.config, "config", "factory.yaml", "the factory config")
-		fs.StringVar(&f.realm, "realm", "", "the realm directory (holds pack.yaml): its sandbox stack is what gets built")
+		fs.Func("realm", "a realm whose sandbox stack is built: a name found in factory.yaml's realms.dir, or a directory; repeat it for more", func(v string) error {
+			f.realms = append(f.realms, v)
+			return nil
+		})
+		fs.BoolVar(&f.all, "all", false, "build the stack of every realm in factory.yaml's realms.dir")
 	})
 	if !ok {
 		return ExitRefused
 	}
-	if f.realm == "" {
-		return c.refuse(fmt.Errorf("sandbox build needs --realm"))
+	if len(f.realms) == 0 && !f.all || len(f.realms) > 0 && f.all {
+		return c.refuse(errors.New("sandbox build needs --realm (once for each realm) or --all, not both"))
 	}
 	cfg, err := schema.LoadFactory(f.config)
 	if err != nil {
@@ -34,12 +42,12 @@ func (c *command) sandbox(args []string) int {
 	if cfg.Sandbox == nil {
 		return c.refuse(fmt.Errorf("%s has no sandbox section", f.config))
 	}
-	pack, err := schema.LoadPack(f.realm)
+	stacks, skipped, err := stacksToBuild(cfg, f.realms, f.all)
 	if err != nil {
 		return c.refuse(err)
 	}
-	if pack.Sandbox == nil {
-		return c.refuse(fmt.Errorf("the realm %s names no sandbox stack in its pack.yaml", pack.Name))
+	for _, s := range skipped {
+		fmt.Fprintf(c.out, "%s\n", s)
 	}
 	work, err := os.MkdirTemp("", "ygg-sandbox-build-")
 	if err != nil {
@@ -50,12 +58,61 @@ func (c *command) sandbox(args []string) int {
 	if err != nil {
 		return c.refuse(err)
 	}
-	fmt.Fprintf(c.out, "Pulling and building the images for %s; this takes a few minutes.\n", pack.Sandbox.Stack)
-	imgs, err := d.Build(c.ctx, pack.Sandbox.Stack)
-	if err != nil {
-		fmt.Fprintf(c.err, "ygg: the build failed: %v\n", err)
-		return ExitFailed
+	for _, stack := range stacks {
+		fmt.Fprintf(c.out, "Pulling and building the images for %s; this takes a few minutes.\n", stack)
+		imgs, err := d.Build(c.ctx, stack)
+		if err != nil {
+			fmt.Fprintf(c.err, "ygg: the build failed: %v\n", err)
+			return ExitFailed
+		}
+		fmt.Fprintf(c.out, "Built:\n  %s\n  %s\n", imgs.Work, imgs.Firewall)
 	}
-	fmt.Fprintf(c.out, "Built:\n  %s\n  %s\n", imgs.Work, imgs.Firewall)
 	return ExitDone
 }
+
+// stacksToBuild returns the distinct sandbox stacks of the realms named, in the order named, or of every
+// realm in the store with --all. A realm named on purpose that has no stack is an error; with --all it
+// is skipped, and the skip is returned for the output.
+func stacksToBuild(cfg *schema.Factory, refs []string, all bool) (stacks, skipped []string, err error) {
+	var store *realm.Store
+	if cfg.Realms != nil {
+		store = &realm.Store{Dir: cfg.Realms.Dir}
+	}
+	var dirs []string
+	if all {
+		if store == nil {
+			return nil, nil, errors.New("--all needs factory.yaml's realms section, which says where the realm leaves are")
+		}
+		entries, err := os.ReadDir(store.Dir)
+		if err != nil {
+			return nil, nil, err
+		}
+		for _, e := range entries {
+			if _, err := os.Stat(filepath.Join(store.Dir, e.Name(), "pack.yaml")); err == nil {
+				dirs = append(dirs, filepath.Join(store.Dir, e.Name()))
+			}
+		}
+	}
+	for _, ref := range refs {
+		dir, _, err := realm.Resolve(ref, store)
+		if err != nil {
+			return nil, nil, err
+		}
+		dirs = append(dirs, dir)
+	}
+	for _, dir := range dirs {
+		pack, err := schema.LoadPack(dir)
+		if err != nil {
+			return nil, nil, err
+		}
+		switch {
+		case pack.Sandbox == nil && all:
+			skipped = append(skipped, fmt.Sprintf("The realm %s names no sandbox stack; skipped.", pack.Name))
+		case pack.Sandbox == nil:
+			return nil, nil, fmt.Errorf("the realm %s names no sandbox stack in its pack.yaml", pack.Name)
+		case !slices.Contains(stacks, pack.Sandbox.Stack):
+			stacks = append(stacks, pack.Sandbox.Stack)
+		}
+	}
+	return stacks, skipped, nil
+}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T189: ygg status shows each leaf's realm, the tasks and the ones given up; a finished run lists them first; doctor lists the realms

Change `realm-leaf-naming`: "`run.json` and the status line record the lead realm with its graph version and each leaf's realm with its version". Spec §7.3: the tasks given up come first.

**Files (in `odin`):**
- Create: `internal/cli/status_realms_test.go`
- Modify: `internal/cli/cli.go`, `internal/cli/doctor.go`, `internal/run/run.go`, `internal/run/state.go`

**Interfaces:**
- Produces: `LeafRecord.Realm` and `RealmVersion` (set when a leaf joins the run); `ygg status` prints each leaf with its realm, a `blocked:` line for each task given up (before the leaves) and a line with the tasks' counts; `ExitBlocked` (5): a run that finished with tasks given up prints them first and exits 5; `ygg doctor` lists the realm store (`OK realms: <dir> (name version, ...)`), reports a realm that does not load or whose folder holds another realm as an error, an empty store as an error and a config with no realms section as a warning.

**Acceptance criteria:**
- [ ] Status shows `(toy 0.3.0)` after a leaf, the blocked task with its reason before the leaves, and `tasks: 3 (1 done, 0 doing, 1 to do, 1 blocked)`; the usage text lists exit code 5.
- [ ] Doctor lists the store, and fails on a pack that does not parse and on a folder named for another realm.

**Named test:** `go test ./internal/cli -run 'TestStatusShowsEachLeafsRealmAndTheTasksStartingWithTheOnesGivenUp|TestDoctorListsTheRealmsOfTheStoreAndChecksEachLoads|TestDoctorSaysWhenThereAreNoRealms'` in `odin`. **Layer:** `odin`. **Size:** M (173). **Depends on:** v0-T181, v0-T188.

- [ ] **Step 1:** write the tests.

Write `internal/cli/status_realms_test.go`:

```go
package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
)

func TestStatusShowsEachLeafsRealmAndTheTasksStartingWithTheOnesGivenUp(t *testing.T) {
	dir, config := project(t, "script.yaml", "")
	if code, _, errOut := ygg(t, "run", "--project", dir, "--config", config, "--realm", toyRealm(t)); code != ExitStopped {
		t.Fatalf("run: exit %d: %s", code, errOut)
	}
	id := runID(t, dir)
	st, err := run.LoadState(run.Dir(dir, id))
	if err != nil {
		t.Fatal(err)
	}
	f := func(id string, status schema.TaskStatus, why string) schema.FeatureRecord {
		return schema.FeatureRecord{Feature: schema.Feature{ID: id}, Status: status, Why: why}
	}
	st.Features = []schema.FeatureRecord{f("p-T1", schema.TaskDone, ""), f("p-T2", schema.TaskBlocked, "its loop gave up (attempts-exhausted)"), f("p-T3", schema.TaskTodo, "")}
	if err := st.Save(run.Dir(dir, id)); err != nil {
		t.Fatal(err)
	}
	code, out, errOut := ygg(t, "status", id, "--project", dir)
	if code != ExitDone {
		t.Fatalf("status: exit %d: %s", code, errOut)
	}
	for _, want := range []string{"realm:    toy 0.3.0 (graph 3.0.0)", "leaf:     repos/app on ygg/" + id, "(toy 0.3.0)",
		"blocked:  p-T2: its loop gave up (attempts-exhausted)", "tasks:    3 (1 done, 0 doing, 1 to do, 1 blocked)"} {
		if !strings.Contains(out, want) {
			t.Errorf("status lacks %q:\n%s", want, out)
		}
	}
	if strings.Index(out, "blocked:") > strings.Index(out, "leaf:") {
		t.Errorf("the blocked tasks should come before the leaves:\n%s", out)
	}
	if !strings.Contains(usage, "5 done, with tasks given up") || ExitBlocked != 5 {
		t.Error("the usage text lacks exit code 5")
	}
}

func TestDoctorListsTheRealmsOfTheStoreAndChecksEachLoads(t *testing.T) {
	stubEngine(t)
	store, config := realmsStore(t)
	dir, _ := project(t, "script.yaml", "")
	code, out, _ := ygg(t, "doctor", "--project", dir, "--config", config)
	want := "OK    realms: " + store + " (asgard 0.1.0, helheim-go 0.1.0, midgard-react 0.1.0, midgard-vue 0.1.0)"
	if !strings.Contains(out, want) {
		t.Errorf("doctor's output lacks %q:\n%s", want, out)
	}
	if code != ExitDone {
		t.Errorf("exit %d:\n%s", code, out)
	}
	// A realm that doesn't load, and a folder that holds another realm than its name says.
	os.WriteFile(filepath.Join(store, "asgard", "pack.yaml"), []byte("name: asgard\n"), 0o644)
	os.WriteFile(filepath.Join(store, "midgard-vue", "pack.yaml"), []byte("name: midgard-react\nversion: 0.1.0\n"), 0o644)
	code, out, _ = ygg(t, "doctor", "--project", dir, "--config", config)
	for _, w := range []string{"ERROR realms: asgard:", "ERROR realms: " + filepath.Join(store, "midgard-vue") + " holds the realm midgard-react, so --realm midgard-vue can't find it"} {
		if !strings.Contains(out, w) {
			t.Errorf("doctor's output lacks %q:\n%s", w, out)
		}
	}
	if code != ExitFailed {
		t.Errorf("exit %d; a realm that doesn't load is an error", code)
	}
}

func TestDoctorSaysWhenThereAreNoRealms(t *testing.T) {
	dir, config := project(t, "script.yaml", "")
	if _, out, _ := ygg(t, "doctor", "--project", dir, "--config", config); !strings.Contains(out, "WARN  realms: no realms section") {
		t.Errorf("doctor's output:\n%s", out)
	}
	empty := t.TempDir()
	b, _ := os.ReadFile(config)
	cfg := filepath.Join(t.TempDir(), "factory.yaml")
	os.WriteFile(cfg, append(b, []byte("realms:\n  dir: "+empty+"\n")...), 0o644)
	if code, out, _ := ygg(t, "doctor", "--project", dir, "--config", cfg); code != ExitFailed || !strings.Contains(out, "ERROR realms: "+empty+" holds no realm leaf") {
		t.Errorf("an empty store: exit %d:\n%s", code, out)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/cli [github.com/ouroboric-dev/odin/internal/cli.test]
internal/cli/status_realms_test.go:43:64: undefined: ExitBlocked
FAIL	github.com/ouroboric-dev/odin/internal/cli [build failed]
FAIL
```

- [ ] **Step 3:** write the code.

Apply to `internal/cli/cli.go`:

```diff
diff --git a/internal/cli/cli.go b/internal/cli/cli.go
index 9db0627..f0e0ad5 100644
--- a/internal/cli/cli.go
+++ b/internal/cli/cli.go
@@ -27,6 +27,7 @@ const (
 	ExitRefused = 2 // bad usage or config: nothing ran
 	ExitStopped = 3 // the run waits at an approval point
 	ExitPaused  = 4 // the run waits for the provider's quota; resume it once the quota is back
+	ExitBlocked = 5 // an unattended run finished, and gave up tasks whose loops gave up: they are listed first
 )
 
 const usage = `usage:
@@ -37,7 +38,8 @@ const usage = `usage:
   ygg status  <run-id> [--project <dir>]
   ygg doctor  [--project <dir>] [--config <factory.yaml>] [--root <dir>]
   ygg sandbox build (--realm <name|dir>)... | --all [--config <factory.yaml>]
-exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point, 4 paused: the provider's quota is used up
+exit codes: 0 done, 1 a node failed, 2 refused, 3 stopped at an approval point, 4 paused: the provider's quota is used up,
+  5 done, with tasks given up (unattended)
 `
 
 // Main runs one ygg command and returns its exit code.
@@ -240,6 +242,10 @@ func (c *command) advance(r *run.Run) int {
 	}
 	switch out.Status {
 	case run.StatusDone:
+		if blocked := blockedTasks(r.State); len(blocked) > 0 {
+			fmt.Fprintf(c.out, "Run %s is done, with %d task(s) given up. They are listed first, because they need you:\n%s", id, len(blocked), strings.Join(blocked, ""))
+			return ExitBlocked
+		}
 		fmt.Fprintf(c.out, "Run %s is done.\n", id)
 		return ExitDone
 	case run.StatusStopped:
@@ -295,8 +301,24 @@ func (c *command) status(args []string) int {
 	if s.Pending != "" {
 		fmt.Fprintf(c.out, "waiting:  %s (%s)\n", s.Pending, s.PendingGate)
 	}
+	for _, line := range blockedTasks(s) {
+		fmt.Fprintf(c.out, "blocked:  %s", line)
+	}
 	for _, p := range slices.Sorted(maps.Keys(s.Leaves)) {
-		fmt.Fprintf(c.out, "leaf:     %s on %s at %.12s\n", p, s.Leaves[p].Branch, s.Leaves[p].Checkpoint)
+		l := s.Leaves[p]
+		from := ""
+		if l.Realm != "" {
+			from = fmt.Sprintf(" (%s %s)", l.Realm, l.RealmVersion)
+		}
+		fmt.Fprintf(c.out, "leaf:     %s on %s at %.12s%s\n", p, l.Branch, l.Checkpoint, from)
+	}
+	if len(s.Features) > 0 {
+		counts := map[schema.TaskStatus]int{}
+		for _, f := range s.Features {
+			counts[f.Status]++
+		}
+		fmt.Fprintf(c.out, "tasks:    %d (%d done, %d doing, %d to do, %d blocked)\n", len(s.Features),
+			counts[schema.TaskDone], counts[schema.TaskDoing], counts[schema.TaskTodo], counts[schema.TaskBlocked])
 	}
 	for _, id := range slices.Sorted(maps.Keys(s.Loops)) {
 		l := s.Loops[id]
@@ -324,6 +346,17 @@ func (c *command) status(args []string) int {
 	return ExitDone
 }
 
+// blockedTasks lists the tasks the run gave up, one line each, with why.
+func blockedTasks(s *run.State) []string {
+	var out []string
+	for _, f := range s.Features {
+		if f.Status == schema.TaskBlocked {
+			out = append(out, fmt.Sprintf("%s: %s\n", f.ID, f.Why))
+		}
+	}
+	return out
+}
+
 // capsLine says how much of the caps the run and the day have used, from the run's config as it is now.
 // It is empty when the config can't be read: status then says nothing about caps, rather than guess.
 func capsLine(s *run.State) string {
```

Apply to `internal/cli/doctor.go`:

```diff
diff --git a/internal/cli/doctor.go b/internal/cli/doctor.go
index 9210ee4..33972ab 100644
--- a/internal/cli/doctor.go
+++ b/internal/cli/doctor.go
@@ -7,11 +7,13 @@ import (
 	"io/fs"
 	"os"
 	"path/filepath"
+	"strings"
 
 	"github.com/ouroboric-dev/gleipnir/sandbox"
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/odin/internal/ledger"
+	"github.com/ouroboric-dev/odin/internal/realm"
 	"github.com/ouroboric-dev/odin/internal/run"
 	"github.com/ouroboric-dev/odin/internal/tree"
 )
@@ -52,6 +54,7 @@ func (c *command) doctor(args []string) int {
 		return exit(bad)
 	}
 	if factory != nil {
+		checkRealms(factory, report)
 		checkBudget(factory, report)
 		c.checkSandbox(f.project, factory, report)
 	}
@@ -113,6 +116,43 @@ func checkConfig(path string, report func(level, what, msg string)) *schema.Fact
 	return f
 }
 
+// checkRealms says which realm leaves the store holds and at which versions, and that each loads: a realm
+// a project pins must load at the pinned version, or its runs stop before they start (change
+// realm-leaf-naming). A config with no realms section takes --realm as a path, which is fine.
+func checkRealms(f *schema.Factory, report func(level, what, msg string)) {
+	if f.Realms == nil {
+		report("WARN", "realms", "no realms section: --realm takes a path, and a project can't pin a realm leaf")
+		return
+	}
+	entries, err := os.ReadDir(f.Realms.Dir)
+	if err != nil {
+		report("ERROR", "realms", err.Error())
+		return
+	}
+	var found []string
+	for _, e := range entries {
+		dir := filepath.Join(f.Realms.Dir, e.Name())
+		if _, err := os.Stat(filepath.Join(dir, "pack.yaml")); err != nil {
+			continue // not a realm leaf
+		}
+		r, err := realm.Load(dir)
+		if err != nil {
+			report("ERROR", "realms", e.Name()+": "+err.Error())
+			continue
+		}
+		if r.Name != e.Name() {
+			report("ERROR", "realms", fmt.Sprintf("%s holds the realm %s, so --realm %s can't find it", dir, r.Name, e.Name()))
+			continue
+		}
+		found = append(found, r.Name+" "+r.Version)
+	}
+	if len(found) == 0 {
+		report("ERROR", "realms", f.Realms.Dir+" holds no realm leaf")
+		return
+	}
+	report("OK", "realms", f.Realms.Dir+" ("+strings.Join(found, ", ")+")")
+}
+
 // checkBudget says what the caps are and how much of today's is used, and checks that the spend
 // journal can be read and written: a spend that can't be recorded can't be capped (spec §7.4).
 func checkBudget(f *schema.Factory, report func(level, what, msg string)) {
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 9935fac..7ff043f 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -464,10 +464,16 @@ func (r *Run) AddLeaf(ctx context.Context, repo string) error {
 	if err != nil {
 		return err
 	}
-	r.State.Leaves[repo] = LeafRecord{Branch: Branch(r.State.ID), Base: head, Checkpoint: head}
+	r.State.Leaves[repo] = r.leafRecord(repo, head)
 	return r.Save()
 }
 
+// leafRecord is the record of a leaf that joins the run at head: its branch, and the realm that provides it.
+func (r *Run) leafRecord(repo, head string) LeafRecord {
+	rl := r.Setup.RealmOf(repo)
+	return LeafRecord{Branch: Branch(r.State.ID), Base: head, Checkpoint: head, Realm: rl.Name, RealmVersion: rl.Version}
+}
+
 // Leaves returns the paths of the leaves the graph works in, sorted.
 func (s *Setup) Leaves() []string {
 	var ls []string
@@ -876,7 +882,7 @@ func (r *Run) begin(ctx context.Context) error {
 		if err != nil {
 			return err
 		}
-		r.State.Leaves[p] = LeafRecord{Branch: Branch(r.State.ID), Base: head, Checkpoint: head}
+		r.State.Leaves[p] = r.leafRecord(p, head)
 	}
 	return nil
 }
```

Apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index 7f97ccb..05cda67 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -126,6 +126,10 @@ type LeafRecord struct {
 	Branch     string `json:"branch"`     // the run's branch: ygg/<run id>
 	Base       string `json:"base"`       // the leaf's main when the run started
 	Checkpoint string `json:"checkpoint"` // the last checkpoint commit; resume resets the leaf to it
+	// Realm and RealmVersion are the realm leaf that provides this leaf, as the run used it (the lead
+	// realm's, for a leaf with no pin).
+	Realm        string `json:"realm,omitempty"`
+	RealmVersion string `json:"realm_version,omitempty"`
 }
 
 var idPattern = regexp.MustCompile(`^[0-9]{8}-[0-9]{6}-[0-9a-f]{6}$`)
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T190: a task is done when the walk leaves its last node, even when the tasks after it are skipped

Found by the end-to-end test of v0-T192: the last task that ran stayed `doing` when the tasks after it were skipped because they depend on a blocked one.

**Files (in `odin`):**
- Modify: `internal/engine/blocked_test.go`, `internal/engine/engine.go`, `internal/engine/stages.go`

**Interfaces:**
- Produces: `settleTasks` becomes `finishTask`, which runs before `skipBlocked`, and `startTask`, which runs after it, in `Advance`'s loop: a task is finished by the node the walk has just left, before any task is skipped past it.

**Acceptance criteria:**
- [ ] The task before skipped tasks is done at the end of the run.

**Named test:** `go test ./internal/engine -run 'TestATaskDoneJustBeforeTasksThatAreSkippedIsStillDone|TestAnUnattendedRunGivesUpATaskWhoseLoopGaveUpAndGoesOnWithTheRest'` in `odin`. **Layer:** `odin`. **Size:** S (38). **Depends on:** v0-T181.

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/blocked_test.go`:

```diff
diff --git a/internal/engine/blocked_test.go b/internal/engine/blocked_test.go
index e5bac8e..71cba54 100644
--- a/internal/engine/blocked_test.go
+++ b/internal/engine/blocked_test.go
@@ -14,6 +14,13 @@ import (
 // A plan of four tasks: 1 builds the api, 2 the web leaf on it, 3 depends on 2, and 4 builds more of the
 // api and depends on nothing. Task 2's implementer never writes what its check wants.
 func blockedRun(t *testing.T, mode string) *run.Run {
+	t.Helper()
+	return blockedRunOf(t, mode, "# Tasks\n\n"+taskMD("p-T1", "repos/api", "S", "nothing")+taskMD("p-T2", "repos/web", "M", "p-T1")+
+		taskMD("p-T3", "repos/web", "S", "p-T2")+taskMD("p-T4", "repos/api", "S", "p-T1"))
+}
+
+// blockedRunOf is blockedRun with the plan given.
+func blockedRunOf(t *testing.T, mode, plan string) *run.Run {
 	t.Helper()
 	idle := "    - result: { status: ok, summary: did nothing }\n"
 	script := writeStep("p-t1-implement", "api.txt") + writeStep("p-t4-implement", "api2.txt") +
@@ -21,8 +28,6 @@ func blockedRun(t *testing.T, mode string) *run.Run {
 	r := startRealms(t, realmsSetup{mode: mode, nodes: taskShape, script: "steps:\n" + script,
 		realms: []realmFiles{recipeRealm("midgard-react", "0.1.0", "web.txt", "Web implementer prompt."), recipeRealm("helheim-go", "0.2.0", "api.txt", "API implementer prompt.")},
 		leaves: map[string]string{"repos/api": "helheim-go", "repos/web": "midgard-react"}})
-	plan := "# Tasks\n\n" + taskMD("p-T1", "repos/api", "S", "nothing") + taskMD("p-T2", "repos/web", "M", "p-T1") +
-		taskMD("p-T3", "repos/web", "S", "p-T2") + taskMD("p-T4", "repos/api", "S", "p-T1")
 	if err := os.WriteFile(filepath.Join(r.Project, "tasks.md"), []byte(plan), 0o644); err != nil {
 		t.Fatal(err)
 	}
@@ -111,3 +116,19 @@ func TestOtherModesStopAtTheLoopThatGaveUp(t *testing.T) {
 		}
 	}
 }
+
+func TestATaskDoneJustBeforeTasksThatAreSkippedIsStillDone(t *testing.T) {
+	// T3 is the last task that runs: T4 comes after it and depends on the blocked T2, so the walk skips it.
+	r := blockedRunOf(t, "unattended", "# Tasks\n\n"+taskMD("p-T1", "repos/api", "S", "nothing")+taskMD("p-T2", "repos/web", "M", "p-T1")+
+		taskMD("p-T3", "repos/api", "S", "p-T1")+taskMD("p-T4", "repos/web", "S", "p-T2"))
+	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+	got := map[string]schema.TaskStatus{}
+	for _, f := range r.State.Features {
+		got[f.ID] = f.Status
+	}
+	if got["p-T3"] != schema.TaskDone || got["p-T4"] != schema.TaskBlocked || got["p-T2"] != schema.TaskBlocked || got["p-T1"] != schema.TaskDone {
+		t.Errorf("statuses = %v", got)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestATaskDoneJustBeforeTasksThatAreSkippedIsStillDone (2.46s)
    blocked_test.go:132: statuses = map[p-T1:done p-T2:blocked p-T3:doing p-T4:blocked]
FAIL
FAIL	github.com/ouroboric-dev/odin/internal/engine	86.671s
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 4bcfe60..b29e339 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -58,12 +58,15 @@ func advance(ctx context.Context, r *run.Run) (Outcome, error) {
 	}
 	for {
 		nodes := r.Nodes()
+		if err := finishTask(r, nodes); err != nil {
+			return Outcome{}, err
+		}
 		if moved, err := skipBlocked(r, nodes); err != nil {
 			return Outcome{}, err
 		} else if moved {
 			continue
 		}
-		if err := settleTasks(r, nodes); err != nil {
+		if err := startTask(r, nodes); err != nil {
 			return Outcome{}, err
 		}
 		if s.Position >= len(nodes) {
```

Apply to `internal/engine/stages.go`:

```diff
diff --git a/internal/engine/stages.go b/internal/engine/stages.go
index 435dc0a..f302ce1 100644
--- a/internal/engine/stages.go
+++ b/internal/engine/stages.go
@@ -162,18 +162,22 @@ func expandForeach(ctx context.Context, r *run.Run, n schema.Node) error {
 	return &expanded{}
 }
 
-// settleTasks keeps the record of each task in step with Position: a task is doing once the first node of
-// its shape is next, and done once the walk has left its last node. It writes features.json when a task
-// changes, and a line in the ledger.
-func settleTasks(r *run.Run, nodes []schema.Node) error {
+// finishTask marks done the task whose last node the walk has just left, and startTask marks doing the
+// task whose first node is next. Each writes features.json and a line in the ledger when a task changes.
+// A task that is skipped because one it depends on is blocked is neither: it is blocked, by skipBlocked,
+// which runs between the two.
+func finishTask(r *run.Run, nodes []schema.Node) error {
 	s := r.State
 	if s.Position > 0 && s.Position <= len(nodes) {
 		if prev := nodes[s.Position-1]; prev.Task != "" && (s.Position == len(nodes) || nodes[s.Position].Task != prev.Task) {
-			if err := setTask(r, prev.Task, schema.TaskDone, gungnir.EventTaskDone); err != nil {
-				return err
-			}
+			return setTask(r, prev.Task, schema.TaskDone, gungnir.EventTaskDone)
 		}
 	}
+	return nil
+}
+
+func startTask(r *run.Run, nodes []schema.Node) error {
+	s := r.State
 	if s.Position < len(nodes) && nodes[s.Position].Task != "" {
 		return setTask(r, nodes[s.Position].Task, schema.TaskDoing, gungnir.EventTaskStarted)
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T191: a pointer's acceptance checks are the lead realm's, and a check a realm doesn't define is an error

Found by the end-to-end test of v0-T192: a body pointer's acceptance checks run in the project, but its node carried the leaf's realm, which lacked the check.

**Files (in `odin`):**
- Modify: `internal/engine/engine.go`, `internal/engine/loop.go`, `internal/engine/realms_test.go`

**Interfaces:**
- Produces: `runChecks` uses the lead realm's checks when it is given no repo (the pointer's acceptance), and returns a node failure naming the realm and the check when a realm does not define a check, in `runChecks` and in a loop's `Check`, instead of running an empty command.

**Acceptance criteria:**
- [ ] A pointer node of another realm runs its acceptance check from the lead's pack; an undefined check is a `nodeFailure`, not a panic.

**Named test:** `go test ./internal/engine -run 'TestAPointersAcceptanceChecksAreTheLeadRealmsEvenInALeafOfAnotherRealm|TestACheckTheRealmDoesNotDefineIsAnErrorNotAPanic'` in `odin`. **Layer:** `odin`. **Size:** S (47). **Depends on:** v0-T173.

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/realms_test.go`:

```diff
diff --git a/internal/engine/realms_test.go b/internal/engine/realms_test.go
index 35d222e..b6189e1 100644
--- a/internal/engine/realms_test.go
+++ b/internal/engine/realms_test.go
@@ -2,6 +2,7 @@ package engine
 
 import (
 	"context"
+	"errors"
 	"os"
 	"path/filepath"
 	"strings"
@@ -137,3 +138,33 @@ func TestANodeReadsItsPromptAndRunsItsChecksFromItsOwnRealm(t *testing.T) {
 		t.Errorf("the web's check was run by %q", b)
 	}
 }
+
+func TestAPointersAcceptanceChecksAreTheLeadRealmsEvenInALeafOfAnotherRealm(t *testing.T) {
+	realms := twoRealms()
+	realms[0].pack += "  accept: [sh, -c, \"echo lead > accepted-by.txt\"]\n"
+	r := startRealms(t, realmsSetup{realms: realms, leaves: map[string]string{"repos/api": "helheim-go"},
+		nodes: "  - { id: api-touch, kind: exec, run: [echo, api], repo: repos/api }\n", script: "steps: {}\n"})
+	api := schema.Node{ID: "move", Kind: schema.KindPointer, Repo: "repos/api", Realm: "helheim-go", Acceptance: []string{"accept"}}
+	// The acceptance check runs in the project, with no repo: helheim-go defines no accept, and the lead does.
+	if err := runChecks(context.Background(), r, api, 1, api.Acceptance, "", r.Project); err != nil {
+		t.Fatalf("runChecks() = %v", err)
+	}
+	if b, _ := os.ReadFile(filepath.Join(r.Project, "accepted-by.txt")); strings.TrimSpace(string(b)) != "lead" {
+		t.Errorf("the acceptance check was run by %q", b)
+	}
+}
+
+func TestACheckTheRealmDoesNotDefineIsAnErrorNotAPanic(t *testing.T) {
+	r := startRealms(t, realmsSetup{realms: twoRealms(), leaves: map[string]string{"repos/api": "helheim-go"},
+		nodes: "  - { id: api-touch, kind: exec, run: [echo, api], repo: repos/api }\n", script: "steps: {}\n"})
+	n := schema.Node{ID: "land", Kind: schema.KindMerge, Repo: "repos/api", Realm: "helheim-go", Checks: []string{"nope"}}
+	err := runChecks(context.Background(), r, n, 1, n.Checks, "repos/api", r.RepoDir("repos/api"))
+	var nf *nodeFailure
+	if !errors.As(err, &nf) || !strings.Contains(err.Error(), "the realm helheim-go defines no check nope") {
+		t.Errorf("runChecks() = %v", err)
+	}
+	steps := &loopSteps{r: r, n: schema.Node{ID: "build", Kind: schema.KindLoop, Repo: "repos/api", Realm: "helheim-go"}}
+	if _, err := steps.Check(context.Background(), 1, "nope"); !errors.As(err, &nf) || !strings.Contains(err.Error(), "defines no check nope") {
+		t.Errorf("the loop's Check() = %v", err)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAPointersAcceptanceChecksAreTheLeadRealmsEvenInALeafOfAnotherRealm (0.25s)
panic: runtime error: index out of range [0] with length 0 [recovered, repanicked]

goroutine 6012 [running]:
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index b29e339..70afc51 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -321,9 +321,19 @@ func runCheck(ctx context.Context, r *run.Run, node, repo, dir string, spec chec
 // when the run has one; the pointer node's acceptance checks pass "" and the umbrella's dir, and run
 // on the host.
 func runChecks(ctx context.Context, r *run.Run, n schema.Node, attempt int, names []string, repo, dir string) error {
+	// A pointer node's acceptance checks, which pass no repo, are the lead realm's, run in the project; the
+	// checks of a leaf are its realm's.
+	rl := r.Setup.Realm(n.Realm)
+	if repo == "" {
+		rl = r.Setup.Realm("")
+	}
 	for _, c := range names {
+		argv := rl.Pack.Checks[c]
+		if len(argv) == 0 {
+			return &nodeFailure{fmt.Errorf("the realm %s defines no check %s", rl.Name, c)}
+		}
 		logPath := filepath.Join(r.Dir, "logs", fmt.Sprintf("%s-%d-%s.log", n.ID, attempt, c))
-		cmdErr, err := command(ctx, r, n.ID, repo, dir, r.Setup.Realm(n.Realm).Pack.Checks[c], time.Duration(n.Timeout), logPath)
+		cmdErr, err := command(ctx, r, n.ID, repo, dir, argv, time.Duration(n.Timeout), logPath)
 		if err != nil {
 			return err
 		}
```

Apply to `internal/engine/loop.go`:

```diff
diff --git a/internal/engine/loop.go b/internal/engine/loop.go
index b1cdfb9..307c968 100644
--- a/internal/engine/loop.go
+++ b/internal/engine/loop.go
@@ -141,7 +141,11 @@ func (l *loopSteps) Implement(ctx context.Context, attempt int, in jormungandr.I
 func (l *loopSteps) Check(ctx context.Context, attempt int, name string) (jormungandr.CheckOutcome, error) {
 	r, n := l.r, l.n
 	rel := filepath.Join("logs", fmt.Sprintf("%s-%d-%s.log", n.ID, attempt, name))
-	res, err := runCheck(ctx, r, n.ID, n.Repo, r.RepoDir(n.Repo), checks.Spec{Name: name, Argv: r.Setup.Realm(n.Realm).Pack.Checks[name], Timeout: ExecTimeout},
+	argv := r.Setup.Realm(n.Realm).Pack.Checks[name]
+	if len(argv) == 0 {
+		return jormungandr.CheckOutcome{}, &nodeFailure{fmt.Errorf("the realm %s defines no check %s", r.Setup.Realm(n.Realm).Name, name)}
+	}
+	res, err := runCheck(ctx, r, n.ID, n.Repo, r.RepoDir(n.Repo), checks.Spec{Name: name, Argv: argv, Timeout: ExecTimeout},
 		filepath.Join(r.Dir, rel))
 	if err == nil {
 		var lf *leaf.Leaf
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T192: the toy realms build a product from two realms end to end, with scripted agents

The change's task T004 as a test: a run with `--realm midgard-toy` walks that realm's graph; the spec stage names the leaves and their realms; init creates the API from `helheim-toy`'s template and the web leaf from `midgard-toy`'s; each task runs in its leaf with its realm's recipe; run.json and the status line record every realm. The scripts write what a planner would: the second plan has a task in a leaf nobody named, and goes back once.

**Files (in `odin`):**
- Create: `internal/cli/realms_e2e_test.go`, `testdata/realms-scripts/gallery.yaml`, `testdata/realms/helheim-toy/pack.yaml`, `testdata/realms/helheim-toy/prompts/implementer.md`, `testdata/realms/helheim-toy/templates/api/AGENTS.md`, `testdata/realms/helheim-toy/templates/api/LICENSE`, `testdata/realms/midgard-toy/graph.yaml`, `testdata/realms/midgard-toy/pack.yaml`, `testdata/realms/midgard-toy/prompts/design.md`, `testdata/realms/midgard-toy/prompts/implementer.md`, `testdata/realms/midgard-toy/prompts/plan.md`, `testdata/realms/midgard-toy/prompts/spec.md`, `testdata/realms/midgard-toy/templates/web/AGENTS.md`, `testdata/realms/midgard-toy/templates/web/LICENSE`

**Interfaces:**
- Produces: `testdata/realms/{midgard-toy,helheim-toy}`, `testdata/realms-scripts/gallery.yaml`, and three tests through `ygg`: the whole run with an approval at the design gate; an unattended run that gives up a task, finishes with exit code 5 and lists the task; and a run refused for pins that disagree, with nothing created.

**Acceptance criteria:**
- [ ] The documents of three stages are published and committed; the plan went back to the planner once; the project pins the lead realm, each leaf's realm and the consumer; the leaves are made from their realms' templates; four tasks are done, landed on each leaf's main, and the project points at them.
- [ ] The unattended run exits 5, lists `gallery-T2` and `gallery-T4`, and runs the API's tasks.
- [ ] A pin the store lacks exits 2 and leaves no `.factory`.

**Named test:** `go test ./internal/cli -run 'TestARunOfTheToyRealmsBuildsAProductFromTwoRealms|TestAnUnattendedRunOfTheToyRealmsGivesUpATaskAndExitsFive|TestARunWhoseRealmPinsDisagreeIsRefusedAndCreatesNothing'` in `odin`. **Layer:** `odin`. **Size:** M (353). **Depends on:** v0-T189, v0-T190, v0-T191, v0-T187, v0-T180, v0-T183.

- [ ] **Step 1:** write the tests.

Write `internal/cli/realms_e2e_test.go`:

```go
package cli

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

// The exit criterion of the realm work, with scripted agents: a run with --realm midgard-toy walks that
// realm's graph; the spec stage names the leaves and their realms; init creates the API from
// helheim-toy's template and the web leaf from midgard-toy's; each task runs in its leaf with the
// recipe of its leaf's realm; and run.json and the status line record every realm and its version.

var ctx = context.Background()

func realmsDir(t *testing.T) string {
	t.Helper()
	p, err := filepath.Abs("../../testdata/realms")
	if err != nil {
		t.Fatal(err)
	}
	return p
}

// galleryConfig writes a factory.yaml for the toy realms with the given mode and script file.
func galleryConfig(t *testing.T, mode, gates, script string) string {
	t.Helper()
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	abs, err := filepath.Abs(script)
	if err != nil {
		t.Fatal(err)
	}
	body := "mode: " + mode + "\n" + gates + "roles:\n  planner: { agent: scripted, model: none, script: " + abs + " }\n  implementer: { agent: scripted, model: none, script: " + abs + " }\n" +
		"budget:\n  per_run: { tokens: 1000000, turns: 1000 }\n  per_day: { tokens: 2000000, turns: 2000 }\nrealms:\n  dir: " + realmsDir(t) + "\n"
	p := filepath.Join(t.TempDir(), "factory.yaml")
	if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestARunOfTheToyRealmsBuildsAProductFromTwoRealms(t *testing.T) {
	dir := treetest.Project(t)
	cfg := galleryConfig(t, "key-points", "", "../../testdata/realms-scripts/gallery.yaml")
	code, out, errOut := ygg(t, "run", "--project", dir, "--config", cfg, "--realm", "midgard-toy")
	if code != ExitStopped || !strings.Contains(out, "stopped at approval point design-gate") {
		t.Fatalf("run: exit %d:\n%s%s", code, out, errOut)
	}
	id := runID(t, dir)
	code, out, errOut = ygg(t, "approve", id, "design-gate", "--project", dir)
	if code != ExitDone || !strings.Contains(out, "is done.") {
		t.Fatalf("approve: exit %d:\n%s%s", code, out, errOut)
	}

	// The documents of the three stages are in the project, committed by Odin.
	for _, f := range []string{"docs/1-product/design.md", "docs/2-engineering/specs/spec.md", "docs/leaves.yaml", "docs/2-engineering/plans/2026-10-17-gallery/tasks.md"} {
		if _, err := os.Stat(filepath.Join(dir, f)); err != nil {
			t.Errorf("%s was not published: %v", f, err)
		}
	}
	// The plan with a mistake went back to the planner once.
	st, err := run.LoadState(run.Dir(dir, id))
	if err != nil {
		t.Fatal(err)
	}
	if st.Returns["ready"] != 1 || st.Attempts["plan"] != 2 || st.Status != run.StatusDone {
		t.Errorf("returns %v, plan attempts %d, status %s", st.Returns, st.Attempts["plan"], st.Status)
	}
	// The project pins the lead realm and each leaf's realm, and the leaves were made from their templates.
	u, err := schema.LoadUmbrella(dir)
	if err != nil {
		t.Fatal(err)
	}
	api, web := u.Children["repos/api"], u.Children["repos/web"]
	if u.Realm != "midgard-toy" || api.Realm != "helheim-toy" || web.Realm != "midgard-toy" || web.Consumes[0] != "repos/api" {
		t.Errorf("the project's pins: lead %s; api %+v; web %+v", u.Realm, api, web)
	}
	for leaf, want := range map[string]string{"repos/api": "# AGENTS.md: the toy API leaf\n", "repos/web": "# AGENTS.md: the toy web leaf\n"} {
		if b, err := os.ReadFile(filepath.Join(dir, leaf, "AGENTS.md")); err != nil || string(b) != want {
			t.Errorf("%s/AGENTS.md = %q, %v; the leaf is made from the template of its own realm", leaf, b, err)
		}
	}
	// Each task landed in its leaf, and the project points at what landed.
	for leaf, files := range map[string][]string{"repos/api": {"api.txt", "api-own.txt"}, "repos/web": {"web.txt", "photos.txt"}} {
		for _, f := range files {
			if body, err := git.Run(ctx, filepath.Join(dir, leaf), "show", "main:"+f); err != nil || body != "done" {
				t.Errorf("%s: main:%s = %q, %v", leaf, f, body, err)
			}
		}
		main, _ := git.Run(ctx, filepath.Join(dir, leaf), "rev-parse", "main")
		if got, _ := git.Run(ctx, dir, "rev-parse", "HEAD:"+leaf); got != main {
			t.Errorf("the project points at %s for %s, want main %s", got, leaf, main)
		}
	}
	feats, err := schema.LoadFeatures(filepath.Join(dir, ".factory", "features.json"))
	if err != nil || len(feats.Tasks) != 4 {
		t.Fatalf("features.json = %+v, %v", feats, err)
	}
	for _, f := range feats.Tasks {
		if f.Status != schema.TaskDone {
			t.Errorf("task %s is %s", f.ID, f.Status)
		}
	}
	// run.json and the status line record the lead realm with its graph, and each leaf's realm.
	if st.Realm != "midgard-toy" || st.RealmVersion != "0.1.0" || len(st.Realms) != 2 || st.Leaves["repos/api"].Realm != "helheim-toy" || st.Leaves["repos/web"].Realm != "midgard-toy" {
		t.Errorf("run.json: realm %s %s, realms %v, leaves %+v", st.Realm, st.RealmVersion, st.Realms, st.Leaves)
	}
	_, status, _ := ygg(t, "status", id, "--project", dir)
	for _, want := range []string{"realm:    midgard-toy 0.1.0 (graph 0.1.0)", "(helheim-toy 0.1.0)", "(midgard-toy 0.1.0)", "tasks:    4 (4 done, 0 doing, 0 to do, 0 blocked)"} {
		if !strings.Contains(status, want) {
			t.Errorf("status lacks %q:\n%s", want, status)
		}
	}
	// Doctor is content with the finished run.
	if code, out, _ := ygg(t, "doctor", "--project", dir, "--config", cfg); code != ExitDone || !strings.Contains(out, "OK    realms: "+realmsDir(t)) {
		t.Errorf("doctor: exit %d:\n%s", code, out)
	}
}

func TestAnUnattendedRunOfTheToyRealmsGivesUpATaskAndExitsFive(t *testing.T) {
	dir := treetest.Project(t)
	script, err := os.ReadFile("../../testdata/realms-scripts/gallery.yaml")
	if err != nil {
		t.Fatal(err)
	}
	// Task 2's implementer builds nothing, twice, so its loop gives up; task 4 depends on it.
	broken := strings.Replace(string(script), "    - actions: [ { write: { path: web.txt, content: \"done\\n\" } } ]\n      result: { status: ok, summary: built the page, usage: { in: 2000, out: 200, turns: 4 } }\n",
		"    - result: { status: ok, summary: did nothing }\n    - result: { status: ok, summary: did nothing again }\n", 1)
	if broken == string(script) {
		t.Fatal("the script was not changed")
	}
	path := filepath.Join(t.TempDir(), "gallery-broken.yaml")
	if err := os.WriteFile(path, []byte(broken), 0o644); err != nil {
		t.Fatal(err)
	}
	cfg := galleryConfig(t, "unattended", "gates:\n  design: auto\n", path)
	code, out, errOut := ygg(t, "run", "--project", dir, "--config", cfg, "--realm", "midgard-toy")
	if code != ExitBlocked {
		t.Fatalf("exit %d, want %d:\n%s%s", code, ExitBlocked, out, errOut)
	}
	for _, want := range []string{"is done, with 2 task(s) given up", "gallery-T2:", "gallery-T4: it depends on gallery-T2, which is blocked"} {
		if !strings.Contains(out, want) {
			t.Errorf("the output lacks %q:\n%s", want, out)
		}
	}
	feats, err := schema.LoadFeatures(filepath.Join(dir, ".factory", "features.json"))
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]schema.TaskStatus{}
	for _, f := range feats.Tasks {
		got[f.ID] = f.Status
	}
	if got["gallery-T1"] != schema.TaskDone || got["gallery-T3"] != schema.TaskDone || got["gallery-T2"] != schema.TaskBlocked || got["gallery-T4"] != schema.TaskBlocked {
		t.Errorf("task statuses = %v; the API tasks go on, and the web tasks are given up", got)
	}
	_, status, _ := ygg(t, "status", runID(t, dir), "--project", dir)
	if !strings.Contains(status, "blocked:  gallery-T2:") || !strings.Contains(status, "tasks:    4 (2 done, 0 doing, 0 to do, 2 blocked)") {
		t.Errorf("status:\n%s", status)
	}
}

func TestARunWhoseRealmPinsDisagreeIsRefusedAndCreatesNothing(t *testing.T) {
	root := treetest.Node{Owner: "ouroboric-dev", Visibility: "private", Pin: treetest.Pin{Realm: "midgard-toy", Version: "0.1.0"}, Children: map[string]treetest.Node{
		"repos/api": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Pin: treetest.Pin{Realm: "helheim-toy", Version: "0.9.0"}}}}
	dir := treetest.Build(t, root)
	cfg := galleryConfig(t, "key-points", "", "../../testdata/realms-scripts/gallery.yaml")
	code, _, errOut := ygg(t, "run", "--project", dir, "--config", cfg, "--realm", "midgard-toy")
	if code != ExitRefused || !strings.Contains(errOut, "the realm store holds helheim-toy 0.1.0, but repos/api pins 0.9.0") {
		t.Errorf("exit %d:\n%s", code, errOut)
	}
	if _, err := os.Stat(filepath.Join(dir, ".factory")); err == nil {
		t.Error("a refused run created .factory/")
	}
	// A realm named with no store to find it in says where to set one.
	plain := galleryConfig(t, "key-points", "", "../../testdata/realms-scripts/gallery.yaml")
	b, _ := os.ReadFile(plain)
	noStore := filepath.Join(t.TempDir(), "factory.yaml")
	os.WriteFile(noStore, []byte(strings.Split(string(b), "realms:")[0]), 0o644)
	if code, _, errOut := ygg(t, "run", "--project", dir, "--config", noStore, "--realm", "midgard-toy"); code != ExitRefused || !strings.Contains(errOut, "realms") {
		t.Errorf("a name with no store: exit %d:\n%s", code, errOut)
	}
}
```

Write `testdata/realms-scripts/gallery.yaml`:

```yaml
# The scripted agent's answers for the toy realms' graph: the documents of the three stages, then the
# four tasks. The plan names two leaves, an API from helheim-toy and a web leaf from midgard-toy that
# consumes it, and four tasks over them.
steps:
  design:
    - actions: [ { write: { path: out/1-product/design.md, content: "# Design\n\nA gallery for photographers.\n" } } ]
      result: { status: ok, summary: wrote the design, usage: { in: 1000, out: 100, turns: 2 } }
  spec:
    - actions:
        - write: { path: out/2-engineering/specs/spec.md, content: "# Spec\n" }
        - write:
            path: out/leaves.yaml
            content: |
              leaves:
                repos/api:
                  realm: helheim-toy
                  realm_version: 0.1.0
                  description: The gallery's API.
                repos/web:
                  realm: midgard-toy
                  realm_version: 0.1.0
                  description: The gallery's web app.
                  consumes: [repos/api]
      result: { status: ok, summary: wrote the spec and named the leaves, usage: { in: 1000, out: 100, turns: 2 } }
  plan:
    # The first plan has a task in a leaf the spec did not name; the plan check sends it back.
    - actions:
        - write:
            path: out/2-engineering/plans/2026-10-17-gallery/tasks.md
            content: |
              # Tasks

              ## gallery-T1: the API stores galleries

              - **Acceptance criteria:**
                - [ ] a gallery can be created
              - **Named test:** TestCreateGallery
              - **Layer:** repos/api
              - **Size:** S
              - **Depends on:** nothing

              ## gallery-T2: the web app shows them

              - **Acceptance criteria:**
                - [ ] the page lists galleries
              - **Named test:** gallery.spec.ts
              - **Layer:** repos/db
              - **Size:** M
              - **Depends on:** gallery-T1
      result: { status: ok, summary: wrote a plan with a mistake, usage: { in: 1000, out: 100, turns: 2 } }
    - actions:
        - write:
            path: out/2-engineering/plans/2026-10-17-gallery/tasks.md
            content: |
              # Tasks

              ## gallery-T1: the API stores galleries

              - **Acceptance criteria:**
                - [ ] a gallery can be created
              - **Named test:** TestCreateGallery
              - **Layer:** repos/api
              - **Size:** S
              - **Depends on:** nothing

              ## gallery-T2: the web app shows them

              - **Acceptance criteria:**
                - [ ] the page lists galleries
              - **Named test:** gallery.spec.ts
              - **Layer:** repos/web
              - **Size:** M
              - **Depends on:** gallery-T1

              ## gallery-T3: the API lists a client's galleries only

              - **Acceptance criteria:**
                - [ ] another client's galleries are never listed
              - **Named test:** TestListsOnlyOwn
              - **Layer:** repos/api
              - **Size:** S
              - **Depends on:** gallery-T1

              ## gallery-T4: the web app shows a gallery's photos

              - **Acceptance criteria:**
                - [ ] the page shows the photos
              - **Named test:** photos.spec.ts
              - **Layer:** repos/web
              - **Size:** S
              - **Depends on:** gallery-T2
      result: { status: ok, summary: wrote the plan, usage: { in: 1000, out: 100, turns: 2 } }
  gallery-t1-implement:
    - actions: [ { write: { path: api.txt, content: "done\n" } } ]
      result: { status: ok, summary: built the API's galleries, usage: { in: 2000, out: 200, turns: 4 } }
  gallery-t2-implement:
    - actions: [ { write: { path: web.txt, content: "done\n" } } ]
      result: { status: ok, summary: built the page, usage: { in: 2000, out: 200, turns: 4 } }
  gallery-t3-implement:
    - actions: [ { write: { path: api-own.txt, content: "done\n" } } ]
      result: { status: ok, summary: built the listing, usage: { in: 2000, out: 200, turns: 4 } }
  gallery-t4-implement:
    - actions: [ { write: { path: photos.txt, content: "done\n" } } ]
      result: { status: ok, summary: built the photos, usage: { in: 2000, out: 200, turns: 4 } }
```

Write `testdata/realms/helheim-toy/pack.yaml`:

```yaml
# A toy backend realm: a leaf recipe and no graph, so it can provide leaves but never lead a run.
name: helheim-toy
version: 0.1.0
checks:
  unit: [test, -f, api.txt]
leaf:
  description: The toy API leaf.
  template: templates/api
  first_commit: [LICENSE]
  implementer: prompts/implementer.md
  checks: [unit]
```

Write `testdata/realms/helheim-toy/prompts/implementer.md`:

```md
Build the task you are given in the API leaf.
```

Write `testdata/realms/helheim-toy/templates/api/AGENTS.md`:

```md
# AGENTS.md: the toy API leaf
```

Write `testdata/realms/helheim-toy/templates/api/LICENSE`:

```text
MIT
```

Write `testdata/realms/midgard-toy/graph.yaml`:

```yaml
# The toy lead graph (spec §4.2 in small): stages that write documents in scratch workspaces, Odin
# publishing them after the approval points, the plan read into tasks, the leaves created, and then a
# task shape that repeats for every task, in the leaf and the realm the task names.
name: midgard-toy
version: 0.1.0
nodes:
  - { id: design, kind: agent, role: planner, prompt: prompts/design.md, scratch: true }
  - { id: design-gate, kind: gate, gate: design }
  - { id: design-docs, kind: publish, from: design, to: docs }
  - { id: spec, kind: agent, role: planner, prompt: prompts/spec.md, scratch: true, inputs: [docs/1-product] }
  - { id: spec-gate, kind: gate, gate: spec }
  - { id: spec-docs, kind: publish, from: spec, to: docs }
  - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md, scratch: true, inputs: [docs/2-engineering/specs, docs/leaves.yaml] }
  - { id: plan-docs, kind: publish, from: plan, to: docs }
  - { id: ready, kind: tasks, from: docs/2-engineering/plans/*/tasks.md, leaves: docs/leaves.yaml, back_to: plan }
  - { id: leaves, kind: init, from: docs/leaves.yaml }
  - { id: plan-gate, kind: gate, gate: plan, reruns: plan }
  - id: tasks
    kind: foreach
    over: tasks
    nodes:
      - { id: implement, kind: loop, realm: leaf, role: implementer, attempts: 2 }
      - { id: feature-gate, kind: gate, gate: feature }
      - { id: land, kind: merge, realm: leaf, back_to: implement }
      - { id: move, kind: pointer, realm: leaf, acceptance: [accept], back_to: implement }
```

Write `testdata/realms/midgard-toy/pack.yaml`:

```yaml
# A toy lead realm for the end-to-end tests of realms (change realm-leaf-naming): the graph of a
# product whose leaves come from two realms, the web leaf's recipe, and nothing that needs a container.
name: midgard-toy
version: 0.1.0
graph: graph.yaml
checks:
  unit: [test, -f, web.txt]
  accept: [test, -f, docs/leaves.yaml]
leaf:
  description: The toy web leaf.
  template: templates/web
  first_commit: [LICENSE]
  implementer: prompts/implementer.md
  checks: [unit]
```

Write `testdata/realms/midgard-toy/prompts/design.md`:

```md
Write the design doc for the brief, as out/1-product/design.md.
```

Write `testdata/realms/midgard-toy/prompts/implementer.md`:

```md
Build the task you are given in the web leaf.
```

Write `testdata/realms/midgard-toy/prompts/plan.md`:

```md
Write the plan as out/2-engineering/plans/<date>-<name>/tasks.md.
```

Write `testdata/realms/midgard-toy/prompts/spec.md`:

```md
Write the spec as out/2-engineering/specs/spec.md, and name the leaves in out/leaves.yaml.
```

Write `testdata/realms/midgard-toy/templates/web/AGENTS.md`:

```md
# AGENTS.md: the toy web leaf
```

Write `testdata/realms/midgard-toy/templates/web/LICENSE`:

```text
MIT
```

- [ ] **Step 2:** run the named test. It passes at once, because the code or data it needs is already there (or the test is skipped without its build tag): expect `ok`.

- [ ] **Step 3:** run the named test. Expect `ok`.

- [ ] **Step 4:** commit (see "How each task lands").

---

### Task v0-T193: a realm with no leaves, no stack and no recipe runs in an umbrella with no leaves (B-036)

Backlog B-036: the Asgard, Alfheim and Vanaheim realms make documents, not code. With scratch agents and publish the engine can do that; this test says so.

**Files (in `odin`):**
- Create: `internal/engine/docsrealm_test.go`

**Interfaces:**
- Produces: a test only: a lead realm with a pack that names nothing but its graph, a graph of a scratch agent, a gate and a publish, and a project with no leaves, runs to done and publishes its document.

**Acceptance criteria:**
- [ ] The run has no leaf, no recipe and no stack, and its document is in the project.

**Named test:** `go test ./internal/engine -run 'TestARealmWithNoLeavesNoStackAndNoRecipeRunsInAnUmbrellaWithNoLeaves'` in `odin`. **Layer:** `odin`. **Size:** S (41). **Depends on:** v0-T183.

- [ ] **Step 1:** write the tests.

Write `internal/engine/docsrealm_test.go`:

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

// Backlog B-036: a realm whose output is documents has no code leaves, no stack layer and no leaf recipe
// (the Asgard realm is the first). A run of it works in a project umbrella with no leaves.
func TestARealmWithNoLeavesNoStackAndNoRecipeRunsInAnUmbrellaWithNoLeaves(t *testing.T) {
	r := startRealms(t, realmsSetup{mode: "unattended", nodes: publishNodes, script: publishScript,
		roles:  "gates:\n  design: auto\n" + defaultRoles,
		realms: []realmFiles{{name: "asgard", version: "0.1.0", files: map[string]string{"p.md": "Write the charter.\n"}}}})
	if len(r.Setup.Leaves()) != 0 || len(r.State.Leaves) != 0 || r.Setup.Lead.Pack.Leaf != nil || r.Setup.Lead.Pack.Sandbox != nil {
		t.Fatalf("leaves %v, recipe %v, sandbox %v", r.Setup.Leaves(), r.Setup.Lead.Pack.Leaf, r.Setup.Lead.Pack.Sandbox)
	}
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if b, err := os.ReadFile(filepath.Join(r.Project, "docs", "1-product", "design.md")); err != nil || string(b) != "# Design\n" {
		t.Errorf("the document was not published: %q, %v", b, err)
	}
	if st, _ := loadStatus(t, r); !strings.Contains(st, "done") {
		t.Errorf("status = %s", st)
	}
}

func loadStatus(t *testing.T, r *run.Run) (string, error) {
	t.Helper()
	s, err := run.LoadState(r.Dir)
	if err != nil {
		return "", err
	}
	return string(s.Status), nil
}
```

- [ ] **Step 2:** run the named test. It passes at once, because the code or data it needs is already there (or the test is skipped without its build tag): expect `ok`.

- [ ] **Step 3:** run the named test. Expect `ok`.

- [ ] **Step 4:** commit (see "How each task lands").

---

### Task v0-T194: documents and plans are read and written only inside the project, never through a symlink

Review focus 1: a symlink anywhere on the path of a file the engine reads from, or writes into, the project would carry the access out of it. The planner cannot make one (publish refuses non-regular files), but the project is a tree of git repos that other hands touch.

**Files (in `odin`):**
- Create: `internal/engine/symlinks_test.go`
- Modify: `internal/engine/init.go`, `internal/engine/publish.go`, `internal/engine/scratch.go`, `internal/engine/stages.go`

**Interfaces:**
- Produces: `engine.noSymlinks(project, path)` refuses a path of which any existing part under the project is a symlink; publish uses it for every file it writes, the scratch workspace for every input it copies, the tasks node for every plan file its glob finds and every leaves file, init for the leaves file.

**Acceptance criteria:**
- [ ] A `docs` that is a link, and a link deeper in the path, write nothing outside the project and stage nothing.
- [ ] An input reached through a linked folder is refused; a plan behind a linked folder is not a plan; a leaves file that is a link is not read.

**Named test:** `go test ./internal/engine -run 'TestPublishWritesNothingThroughASymlinkInTheProject|TestAScratchInputReachedThroughASymlinkIsRefused|TestAPlanAndALeavesFileReachedThroughASymlinkAreNotRead'` in `odin`. **Layer:** `odin`. **Size:** M (140). **Depends on:** v0-T183, v0-T186, v0-T176.

- [ ] **Step 1:** write the tests.

Write `internal/engine/symlinks_test.go`:

```go
package engine

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
)

// outsideDir makes a folder beside the project and returns it.
func outsideDir(t *testing.T) string {
	t.Helper()
	d := t.TempDir()
	if err := os.WriteFile(filepath.Join(d, "secret.md"), []byte("outside the project\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	return d
}

func TestPublishWritesNothingThroughASymlinkInTheProject(t *testing.T) {
	r := start(t, "unattended", "gates:\n  design: auto\n", publishNodes, publishScript)
	outside := outsideDir(t)
	if err := os.Symlink(outside, filepath.Join(r.Project, "docs")); err != nil {
		t.Fatal(err)
	}
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "is a symlink") {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	entries, _ := os.ReadDir(outside)
	if len(entries) != 1 {
		t.Errorf("the folder outside the project holds %d entries after a publish; it was written through the link", len(entries))
	}
	// A link deeper in the path too: docs is a folder, docs/1-product is not.
	os.Remove(filepath.Join(r.Project, "docs"))
	os.MkdirAll(filepath.Join(r.Project, "docs"), 0o755)
	if err := os.Symlink(outside, filepath.Join(r.Project, "docs", "1-product")); err != nil {
		t.Fatal(err)
	}
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusFailed {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if entries, _ := os.ReadDir(outside); len(entries) != 1 {
		t.Errorf("the folder outside the project holds %d entries; a link in the middle of the path was followed", len(entries))
	}
	if st, _ := git.Run(bg, r.Project, "status", "--porcelain", "--", "docs"); strings.Contains(st, "design.md") {
		t.Errorf("a document was staged: %q", st)
	}
}

func TestAScratchInputReachedThroughASymlinkIsRefused(t *testing.T) {
	r := start(t, "key-points", "", scratchNode, designScript)
	outside := outsideDir(t)
	if err := os.MkdirAll(filepath.Join(r.Project, "docs"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(r.Project, "docs", "more")); err != nil {
		t.Fatal(err)
	}
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "docs/more") || !strings.Contains(out.Err.Error(), "symlink") {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if _, err := os.Stat(filepath.Join(r.ScratchDir("design"), "docs", "more", "secret.md")); err == nil {
		t.Error("a file outside the project was copied into the workspace")
	}
}

func TestAPlanAndALeavesFileReachedThroughASymlinkAreNotRead(t *testing.T) {
	outside := outsideDir(t)
	os.WriteFile(filepath.Join(outside, "tasks.md"), []byte(readyPlan+taskMD("p-T1", "repos/app", "S", "nothing")), 0o644)
	os.WriteFile(filepath.Join(outside, "leaves.yaml"), []byte("leaves: {}\n"), 0o644)
	r := start(t, "key-points", "", "  - { id: ready, kind: tasks, from: plans/*/tasks.md }\n", "steps: {}\n")
	if err := os.MkdirAll(filepath.Join(r.Project, "plans"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(r.Project, "plans", "x")); err != nil {
		t.Fatal(err)
	}
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "there is no tasks file") {
		t.Errorf("a plan behind a symlink: %+v, %v", out, err)
	}
	// The leaves file the tasks node names, and the one init reads.
	if err := os.Symlink(filepath.Join(outside, "leaves.yaml"), filepath.Join(r.Project, "leaves.yaml")); err != nil {
		t.Fatal(err)
	}
	for _, node := range []string{"  - { id: ready, kind: tasks, from: tasks.md, leaves: leaves.yaml }\n", "  - { id: leaves, kind: init, from: leaves.yaml }\n"} {
		r2 := start(t, "key-points", "", node, "steps: {}\n")
		os.WriteFile(filepath.Join(r2.Project, "tasks.md"), []byte(readyPlan+taskMD("p-T1", "repos/app", "S", "nothing")), 0o644)
		os.Symlink(filepath.Join(outside, "leaves.yaml"), filepath.Join(r2.Project, "leaves.yaml"))
		out, err := Advance(bg, r2)
		if err != nil || out.Status != run.StatusFailed || !(strings.Contains(out.Err.Error(), "symlink") || strings.Contains(out.Err.Error(), "not there as a regular file")) {
			t.Errorf("%s: %+v, %v", node, out, err)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAScratchInputReachedThroughASymlinkIsRefused (0.19s)
    symlinks_test.go:65: Advance() = {Status:failed Gate: Err:node design: input docs/more of design: /tmp/TestAScratchInputReachedThroughASymlinkIsRefused436758083/008/l0/docs/more is L---------, not a regular file; the workspace holds copies of files and nothing that could lead out of the project Warn:[]}, <nil>
--- FAIL: TestAPlanAndALeavesFileReachedThroughASymlinkAreNotRead (0.76s)
    symlinks_test.go:84: a plan behind a symlink: {Status:done Gate: Err:<nil> Warn:[]}, <nil>
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/init.go`:

```diff
diff --git a/internal/engine/init.go b/internal/engine/init.go
index 1c57fc8..630bc7a 100644
--- a/internal/engine/init.go
+++ b/internal/engine/init.go
@@ -60,7 +60,7 @@ func runInit(ctx context.Context, r *run.Run, n schema.Node) error {
 func readLeaves(r *run.Run, n schema.Node) (*schema.Leaves, error) {
 	file := filepath.Join(r.Project, filepath.FromSlash(n.From))
 	st, err := os.Lstat(file)
-	if err != nil || !st.Mode().IsRegular() {
+	if err != nil || !st.Mode().IsRegular() || noSymlinks(r.Project, file) != nil {
 		return nil, fmt.Errorf("the leaves file %s is not there as a regular file; the spec stage names the product's leaves in it", n.From)
 	}
 	f, err := os.Open(file)
```

Apply to `internal/engine/publish.go`:

```diff
diff --git a/internal/engine/publish.go b/internal/engine/publish.go
index cef1ffb..b4ea037 100644
--- a/internal/engine/publish.go
+++ b/internal/engine/publish.go
@@ -62,7 +62,7 @@ func runPublish(ctx context.Context, r *run.Run, n schema.Node) error {
 	var paths []string
 	for _, rel := range files {
 		dst := path.Join(n.To, rel)
-		if err := copyDocument(filepath.Join(out, filepath.FromSlash(rel)), filepath.Join(project, filepath.FromSlash(dst))); err != nil {
+		if err := copyDocument(project, filepath.Join(out, filepath.FromSlash(rel)), filepath.Join(project, filepath.FromSlash(dst))); err != nil {
 			return &nodeFailure{fmt.Errorf("publishing %s: %w", dst, err)}
 		}
 		paths = append(paths, dst)
@@ -174,23 +174,39 @@ func scanDocuments(ctx context.Context, r *run.Run, n schema.Node, files []strin
 	return &nodeFailure{err}
 }
 
-// copyDocument writes src to dst, making dst's folders, and refuses to write through a symlink the project
-// already has at dst or in its path: a document must land where the node says.
-func copyDocument(src, dst string) error {
+// noSymlinks refuses a path under the project if any part of it that exists, from the project down, is a
+// symlink: a write or a read through one would leave the project. Parts that don't exist yet are fine.
+func noSymlinks(project, path string) error {
+	rel, err := filepath.Rel(project, path)
+	if err != nil || !filepath.IsLocal(rel) {
+		return fmt.Errorf("%s is not inside the project", path)
+	}
+	cur := project
+	for _, seg := range strings.Split(rel, string(filepath.Separator)) {
+		cur = filepath.Join(cur, seg)
+		st, err := os.Lstat(cur)
+		if errors.Is(err, fs.ErrNotExist) {
+			return nil
+		}
+		if err != nil {
+			return err
+		}
+		if st.Mode()&fs.ModeSymlink != 0 {
+			return fmt.Errorf("%s is a symlink", cur)
+		}
+	}
+	return nil
+}
+
+// copyDocument writes src to dst, making dst's folders. Nothing on the way to dst may be a symlink: a
+// document must land where the node says, inside the project.
+func copyDocument(project, src, dst string) error {
 	data, err := os.ReadFile(src)
 	if err != nil {
 		return err
 	}
-	for d := filepath.Dir(dst); ; d = filepath.Dir(d) {
-		if st, err := os.Lstat(d); err == nil {
-			if st.Mode()&fs.ModeSymlink != 0 {
-				return fmt.Errorf("%s is a symlink", d)
-			}
-			break
-		}
-		if d == filepath.Dir(d) {
-			break
-		}
+	if err := noSymlinks(project, dst); err != nil {
+		return err
 	}
 	if st, err := os.Lstat(dst); err == nil && !st.Mode().IsRegular() {
 		return fmt.Errorf("%s exists and is not a regular file", dst)
```

Apply to `internal/engine/scratch.go`:

```diff
diff --git a/internal/engine/scratch.go b/internal/engine/scratch.go
index e4878ca..cfb059d 100644
--- a/internal/engine/scratch.go
+++ b/internal/engine/scratch.go
@@ -107,6 +107,9 @@ func seedScratch(r *run.Run, n schema.Node) (present []string, err error) {
 	b := &copyBudget{files: maxScratchFiles, bytes: maxScratchBytes}
 	for _, in := range n.Inputs {
 		src := filepath.Join(r.Project, filepath.FromSlash(in))
+		if err := noSymlinks(r.Project, src); err != nil {
+			return nil, fmt.Errorf("input %s of %s: %w; the workspace holds copies of files and nothing that could lead out of the project", in, n.ID, err)
+		}
 		if _, err := os.Lstat(src); errors.Is(err, fs.ErrNotExist) {
 			continue // not written yet, such as the leaves file before the spec stage
 		}
```

Apply to `internal/engine/stages.go`:

```diff
diff --git a/internal/engine/stages.go b/internal/engine/stages.go
index f302ce1..d3c0789 100644
--- a/internal/engine/stages.go
+++ b/internal/engine/stages.go
@@ -67,7 +67,8 @@ func readPlan(r *run.Run, n schema.Node) (fs []schema.Feature, source, sum, refu
 	}
 	var files []string
 	for _, m := range matches {
-		if st, err := os.Lstat(m); err == nil && st.Mode().IsRegular() {
+		// A plan is a regular file reached without a symlink, so it is a file of the project.
+		if st, err := os.Lstat(m); err == nil && st.Mode().IsRegular() && noSymlinks(r.Project, m) == nil {
 			files = append(files, m)
 		}
 	}
@@ -120,7 +121,11 @@ func planLeaves(r *run.Run, n schema.Node) (leaves []string, refusal string, err
 	}
 	if n.Leaves != "" {
 		file := filepath.Join(r.Project, filepath.FromSlash(n.Leaves))
-		data, rerr := os.ReadFile(file)
+		var data []byte
+		rerr := noSymlinks(r.Project, file)
+		if rerr == nil {
+			data, rerr = os.ReadFile(file)
+		}
 		if rerr != nil {
 			return nil, fmt.Sprintf("the leaves file %s can't be read (%v), so the tasks' leaves can't be checked. The spec stage names the product's leaves there.", n.Leaves, rerr), nil
 		}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T195: a task's session is told its task, as the plan states it, bounded

Spec §4.4: a session reads its task, and Odin is the only reader of features.json, so the task goes into the prompt: the implementer's and the reviewers'.

**Files (in `odin`):**
- Modify: `internal/engine/engine.go`, `internal/engine/foreach_test.go`, `internal/engine/loop.go`, `internal/engine/stages.go`

**Interfaces:**
- Produces: `engine.taskBlock(r, n)`: "Your task" with the id and title, the leaf, the acceptance criteria, the named test and what it builds on; the title is cut at 200 characters, a field at 1,000 and the criteria at 30 (the rest counted). It is empty for a node with no task. It is added to a loop's implementer and reviewers and to a body agent.

**Acceptance criteria:**
- [ ] The implementer's and the reviewer's prompts of a task hold its criteria and test.
- [ ] A task of 5,000-character fields and 40 criteria gives a block with nothing over 1,000 characters and `... and 10 more in the plan`.

**Named test:** `go test ./internal/engine -run 'TestTheTaskIsInThePromptOfItsImplementerAndItsReviewer|TestATasksWordsAreBoundedInAPrompt'` in `odin`. **Layer:** `odin`. **Size:** S (93). **Depends on:** v0-T178.

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/foreach_test.go`:

```diff
diff --git a/internal/engine/foreach_test.go b/internal/engine/foreach_test.go
index 3186de3..4dfd8f0 100644
--- a/internal/engine/foreach_test.go
+++ b/internal/engine/foreach_test.go
@@ -174,3 +174,45 @@ func TestATaskInALeafWhoseRealmOffersNoRecipeFailsTheNode(t *testing.T) {
 		t.Error("a failed expansion was recorded")
 	}
 }
+
+func TestTheTaskIsInThePromptOfItsImplementerAndItsReviewer(t *testing.T) {
+	shape := strings.Replace(taskShape, "      - { id: implement, kind: loop, realm: leaf, role: implementer }\n",
+		"      - { id: implement, kind: loop, realm: leaf, role: implementer, reviewers: [ { id: spec, role: reviewer, prompt: p.md } ] }\n", 1)
+	script := "steps:\n" + writeStep("p-t1-implement", "api.txt") + "  p-t1-implement-spec:\n    - result: { status: ok, summary: no findings, report: [] }\n"
+	r := startRealms(t, realmsSetup{nodes: shape, script: script,
+		realms: []realmFiles{recipeRealm("midgard-react", "0.1.0", "web.txt", "Web."), recipeRealm("helheim-go", "0.2.0", "api.txt", "API.")},
+		leaves: map[string]string{"repos/api": "helheim-go"}})
+	plan := "# Tasks\n\n## p-T1: the API stores galleries\n\n- **Acceptance criteria:**\n  - [ ] a gallery can be created\n  - [ ] a name is required\n" +
+		"- **Named test:** repos/api/gallery_test.go TestCreate\n- **Layer:** repos/api\n- **Size:** S\n- **Depends on:** nothing\n"
+	os.WriteFile(filepath.Join(r.Project, "tasks.md"), []byte(plan), 0o644)
+	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+	for _, stem := range []string{"p-t1-implement-1", "p-t1-implement-spec-1"} {
+		got := promptOf(t, r, stem)
+		for _, want := range []string{"## Your task", "p-T1: the API stores galleries", "You work in the leaf repos/api.", "- a gallery can be created", "- a name is required",
+			"The test that proves it: repos/api/gallery_test.go TestCreate"} {
+			if !strings.Contains(got, want) {
+				t.Errorf("the prompt of %s lacks %q:\n%s", stem, want, got)
+			}
+		}
+	}
+}
+
+func TestATasksWordsAreBoundedInAPrompt(t *testing.T) {
+	r := startRealms(t, realmsSetup{nodes: taskShape, script: "steps: {}\n", realms: []realmFiles{recipeRealm("midgard-react", "0.1.0", "web.txt", "Web.")},
+		leaves: map[string]string{"repos/web": "midgard-react"}})
+	long := strings.Repeat("w", 5000)
+	f := schema.Feature{ID: "p-T1", Title: long, Layer: "repos/web", Test: long}
+	for i := 0; i < 40; i++ {
+		f.Criteria = append(f.Criteria, long)
+	}
+	r.State.Features = []schema.FeatureRecord{{Feature: f, Status: schema.TaskTodo}}
+	got := taskBlock(r, schema.Node{Task: "p-t1"})
+	if len(got) > 40*1100 || strings.Contains(got, strings.Repeat("w", 1001)) || !strings.Contains(got, "... and 10 more in the plan") {
+		t.Errorf("the block is %d bytes: a task's words are cut, and criteria past the thirtieth are counted", len(got))
+	}
+	if taskBlock(r, schema.Node{}) != "" || taskBlock(r, schema.Node{Task: "nobody"}) != "" {
+		t.Error("a node with no task, or an unknown one, gets a task block")
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/engine [github.com/ouroboric-dev/odin/internal/engine.test]
internal/engine/foreach_test.go:211:9: undefined: taskBlock
internal/engine/foreach_test.go:215:5: undefined: taskBlock
FAIL	github.com/ouroboric-dev/odin/internal/engine [build failed]
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 70afc51..3451483 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -199,6 +199,9 @@ func runAgent(ctx context.Context, r *run.Run, n schema.Node) error {
 	if r.Setup.BriefText != "" {
 		text += "\n\n## Brief\n\n" + r.Setup.BriefText
 	}
+	if block := taskBlock(r, n); block != "" {
+		text += "\n\n" + block
+	}
 	if reason := s.Reasons[n.ID]; reason != "" {
 		text += "\n\n## Rejected at the approval point\n\n" + reason + "\n"
 	}
```

Apply to `internal/engine/loop.go`:

```diff
diff --git a/internal/engine/loop.go b/internal/engine/loop.go
index 307c968..4928f3d 100644
--- a/internal/engine/loop.go
+++ b/internal/engine/loop.go
@@ -112,6 +112,9 @@ func (l *loopSteps) Implement(ctx context.Context, attempt int, in jormungandr.I
 	if err != nil {
 		return err
 	}
+	if block := taskBlock(r, n); block != "" {
+		text += "\n\n" + block
+	}
 	text += "\n\n" + jormungandr.Feedback(in.Open, in.LastFailure, r.State.Reasons[n.ID]) + jormungandr.Refusal(r.State.Refusals[n.ID])
 	started := func() error {
 		return r.Log(gungnir.Event{Name: gungnir.EventLoopAttempt, Node: n.ID, Attempt: attempt,
@@ -193,6 +196,9 @@ func (l *loopSteps) Review(ctx context.Context, attempt int, reviewer string, op
 	if err != nil {
 		return "", err
 	}
+	if block := taskBlock(r, n); block != "" {
+		text += "\n\n" + block
+	}
 	text += "\n\n" + jormungandr.ReviewRequest(rv.ID, open, passed)
 	before, err := snapshot(ctx, r, n.Repo)
 	if err != nil {
```

Apply to `internal/engine/stages.go`:

```diff
diff --git a/internal/engine/stages.go b/internal/engine/stages.go
index d3c0789..a4fc766 100644
--- a/internal/engine/stages.go
+++ b/internal/engine/stages.go
@@ -10,6 +10,7 @@ import (
 	"os"
 	"path/filepath"
 	"slices"
+	"strings"
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
@@ -149,6 +150,47 @@ func writeFeatures(r *run.Run) error {
 	return f.Save(filepath.Join(r.Project, filepath.FromSlash(FeaturesFile)))
 }
 
+// What a task's text may take up in a prompt: the plan is written by an agent, and one task's fields
+// must not swamp a session.
+const (
+	maxTaskTitle    = 200
+	maxTaskCriteria = 30
+	maxTaskField    = 1000
+)
+
+func clip(s string, n int) string {
+	if r := []rune(strings.TrimSpace(s)); len(r) > n {
+		return string(r[:n]) + "…"
+	}
+	return strings.TrimSpace(s)
+}
+
+// taskBlock tells a session what its task is, as the plan states it (spec §4.4: a session reads its task
+// from features.json, and Odin, the only reader of that file, puts the task in the prompt). It is empty
+// for a node that works for no task. The words are the planner's, bounded, and are data to the session as
+// the rest of the repository is.
+func taskBlock(r *run.Run, n schema.Node) string {
+	i := slices.IndexFunc(r.State.Features, func(f schema.FeatureRecord) bool { return n.Task != "" && f.Slug() == n.Task })
+	if i < 0 {
+		return ""
+	}
+	f := r.State.Features[i]
+	var b strings.Builder
+	fmt.Fprintf(&b, "## Your task\n\n%s: %s\n\nYou work in the leaf %s.\n\nAcceptance criteria:\n", f.ID, clip(f.Title, maxTaskTitle), f.Layer)
+	for j, c := range f.Criteria {
+		if j == maxTaskCriteria {
+			fmt.Fprintf(&b, "- ... and %d more in the plan\n", len(f.Criteria)-j)
+			break
+		}
+		fmt.Fprintf(&b, "- %s\n", clip(c, maxTaskField))
+	}
+	fmt.Fprintf(&b, "\nThe test that proves it: %s\n", clip(f.Test, maxTaskField))
+	if len(f.DependsOn) > 0 {
+		fmt.Fprintf(&b, "\nIt builds on: %s (already landed).\n", strings.Join(f.DependsOn, ", "))
+	}
+	return b.String()
+}
+
 // expanded is a foreach node that became the nodes of its tasks: Position now points at the first of them.
 type expanded struct{}
 
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T196: acceptance checks in a task shape are refused with a sandbox on, as the graph's own are

Acceptance checks run in the project umbrella, over several leaves, so no leaf sandbox holds them; Phase 3 refused them with a sandbox on, until a snapshot sandbox exists. `Prepare` looked only at the graph's top-level nodes.

**Files (in `odin`):**
- Modify: `internal/run/prepare.go`, `internal/run/prepare_test.go`

**Interfaces:**
- Produces: `Prepare` looks at every node, a foreach body's too. (The snapshot sandbox that lets the real graph use acceptance tests is 5b's rung 5.)

**Acceptance criteria:**
- [ ] A task shape with a pointer that has acceptance checks, and a sandbox section, is refused naming the node.

**Named test:** `go test ./internal/run -run 'TestPrepareRefusesWhatWouldRunOutsideTheSandbox'` in `odin`. **Layer:** `odin`. **Size:** S (8). **Depends on:** v0-T178.

- [ ] **Step 1:** write the tests.

Apply to `internal/run/prepare_test.go`:

```diff
diff --git a/internal/run/prepare_test.go b/internal/run/prepare_test.go
index e5675c1..03df2ef 100644
--- a/internal/run/prepare_test.go
+++ b/internal/run/prepare_test.go
@@ -93,6 +93,13 @@ func TestPrepareRefusesWhatWouldRunOutsideTheSandbox(t *testing.T) {
 	if _, err := Prepare(ctx, Options{Project: project, Config: cfg, Realm: acceptance}); err == nil || !strings.Contains(err.Error(), "runs acceptance checks") {
 		t.Errorf("a realm with acceptance checks and a sandbox: %v", err)
 	}
+	// The same in a task shape, whose nodes are the body of a foreach node.
+	inBody := variant(t, "graph.yaml", func(g string) string {
+		return g + "  - { id: tasks, kind: foreach, over: tasks, nodes: [ { id: move, kind: pointer, realm: leaf, acceptance: [unit] } ] }\n"
+	})
+	if _, err := Prepare(ctx, Options{Project: project, Config: cfg, Realm: inBody}); err == nil || !strings.Contains(err.Error(), "node move runs acceptance checks") {
+		t.Errorf("a task shape with acceptance checks and a sandbox: %v", err)
+	}
 	// A pack with no stack can't build an image.
 	noStack := variant(t, "pack.yaml", func(p string) string { return strings.SplitN(p, "sandbox:", 2)[0] })
 	if _, err := Prepare(ctx, Options{Project: project, Config: cfg, Realm: noStack}); err == nil || !strings.Contains(err.Error(), "names no sandbox stack") {
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestPrepareRefusesWhatWouldRunOutsideTheSandbox (0.21s)
    prepare_test.go:101: a task shape with acceptance checks and a sandbox: <nil>
FAIL
FAIL	github.com/ouroboric-dev/odin/internal/run	15.949s
```

- [ ] **Step 3:** write the code.

Apply to `internal/run/prepare.go`:

```diff
diff --git a/internal/run/prepare.go b/internal/run/prepare.go
index 7edc7e7..0f8b9d9 100644
--- a/internal/run/prepare.go
+++ b/internal/run/prepare.go
@@ -35,7 +35,7 @@ func (s *Setup) prepareSandbox() error {
 	if s.Pack.Sandbox == nil {
 		return fmt.Errorf("%s has a sandbox section, but the realm %s names no sandbox stack in its pack.yaml", s.ConfigPath, s.Pack.Name)
 	}
-	for _, n := range s.Graph.Nodes {
+	for _, n := range s.Graph.All() {
 		// Acceptance checks run in the project umbrella, over several leaves, so there is no one leaf
 		// to mount. Until a snapshot sandbox exists (Phase 5), they can't run with a sandbox on.
 		if len(n.Acceptance) > 0 {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T197: a rejection gives the refusals after it their returns again

A rejection at a gate is the operator starting the stages after its target over; a refusal that spent its returns before should be able to go back again.

**Files (in `odin`):**
- Modify: `internal/engine/gates.go`, `internal/engine/tasks_test.go`

**Interfaces:**
- Produces: `Reject` clears `State.Returns` for the nodes from the target up to the gate.

**Acceptance criteria:**
- [ ] A plan check that used its one return, a rejection at the plan gate, and the check goes back to the planner again.

**Named test:** `go test ./internal/engine -run 'TestARejectionGivesARefusalItsReturnsAgain'` in `odin`. **Layer:** `odin`. **Size:** S (22). **Depends on:** v0-T177.

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/tasks_test.go`:

```diff
diff --git a/internal/engine/tasks_test.go b/internal/engine/tasks_test.go
index e5b34a9..2f2a2f2 100644
--- a/internal/engine/tasks_test.go
+++ b/internal/engine/tasks_test.go
@@ -176,3 +176,24 @@ func promptOf(t *testing.T, r *run.Run, stem string) string {
 	}
 	return tr.Prompt
 }
+
+func TestARejectionGivesARefusalItsReturnsAgain(t *testing.T) {
+	bad := readyPlan + taskMD("p-T1", "repos/app", "L", "nothing")
+	good := readyPlan + taskMD("p-T1", "repos/app", "S", "nothing")
+	nodes := planNodes + "  - { id: ready, kind: tasks, from: repos/app/tasks.md, back_to: plan, returns: 1 }\n  - { id: plan-gate, kind: gate, gate: plan }\n"
+	r := start(t, "key-points", "gates:\n  plan: stop\n", nodes, planScript(bad, good, bad, good))
+	out, err := Advance(context.Background(), r)
+	if err != nil || out.Status != run.StatusStopped || out.Gate != "plan-gate" || r.State.Returns["ready"] != 1 {
+		t.Fatalf("Advance() = %+v, %v (returns %v)", out, err, r.State.Returns)
+	}
+	if err := Reject(context.Background(), r, "plan-gate", "the plan is thin"); err != nil {
+		t.Fatal(err)
+	}
+	if r.State.Returns["ready"] != 0 {
+		t.Errorf("returns = %v after a rejection; a refusal may go back again", r.State.Returns)
+	}
+	out, err = Advance(context.Background(), r)
+	if err != nil || out.Status != run.StatusStopped || out.Gate != "plan-gate" || r.State.Attempts["plan"] != 4 {
+		t.Errorf("Advance() = %+v, %v (planner ran %d times); want the plan back at the gate after one more return", out, err, r.State.Attempts["plan"])
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestARejectionGivesARefusalItsReturnsAgain (0.80s)
    tasks_test.go:193: returns = map[ready:1] after a rejection; a refusal may go back again
    tasks_test.go:197: Advance() = {Status:failed Gate: Err:node ready: the plan has 1 problem(s) that keep its tasks from being ready:
        - p-T1: size L: split it into tasks of size S (under 100 changed lines) or M (100 to 400)
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/gates.go`:

```diff
diff --git a/internal/engine/gates.go b/internal/engine/gates.go
index dff1462..1d7bb89 100644
--- a/internal/engine/gates.go
+++ b/internal/engine/gates.go
@@ -205,6 +205,7 @@ func Reject(ctx context.Context, r *run.Run, gateID, reason string) error {
 			if m.Kind == schema.KindLoop {
 				delete(s.Loops, m.ID)
 			}
+			delete(s.Returns, m.ID) // a rejection is a fresh start: a refusal may go back again
 		}
 	}
 	s.Pending, s.PendingGate, s.Status = "", "", run.StatusRunning
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T198: the realms smoke run: two realms, real planners and implementers, and a test that its prompts ask for files Odin accepts

The real-agent check of this plan (v0-H13). The smoke realms ask a real Claude Code, in sandboxes, to write the leaves file and the plan exactly as given, then to build `hello.txt` in each leaf. The run tests the machinery, not the model's judgment; this task is the realms, the example config, and a test that runs the same graph with scripted agents that write exactly what the prompts say, so a prompt that asks for a file Odin would refuse fails here, not on the founder's tokens.

**Files (in `odin`):**
- Create: `internal/cli/smoke_realms_test.go`, `testdata/smoke-realms/factory.example.yaml`, `testdata/smoke-realms/smoke-api/pack.yaml`, `testdata/smoke-realms/smoke-api/prompts/implementer.md`, `testdata/smoke-realms/smoke-api/templates/leaf/LICENSE`, `testdata/smoke-realms/smoke-lead/graph.yaml`, `testdata/smoke-realms/smoke-lead/pack.yaml`, `testdata/smoke-realms/smoke-lead/prompts/implementer.md`, `testdata/smoke-realms/smoke-lead/prompts/plan.md`, `testdata/smoke-realms/smoke-lead/prompts/spec.md`, `testdata/smoke-realms/smoke-lead/templates/leaf/LICENSE`

**Interfaces:**
- Produces: `testdata/smoke-realms/{smoke-lead,smoke-api}` (packs with a leaf recipe and a stack, the lead with a graph of two scratch agents, two publishes, the plan check, init and a task shape of a loop, a merge and a pointer move), `factory.example.yaml` (unattended, Claude Code for both roles, the realms folder), and two tests.

**Acceptance criteria:**
- [ ] The scripted run is done: the leaves file and the plan the prompts ask for are accepted, two leaves are made from two realms, and both tasks are done.
- [ ] The example config, with its placeholders filled, prepares with the real adapter, finds the realm, and opens `api.anthropic.com` only.

**Named test:** `go test ./internal/cli -run 'TestTheSmokeRealmsRunWithScriptedAgentsThatWriteWhatThePromptsAsk|TestTheSmokeRealmsPrepareWithTheRealAdapter'` in `odin`. **Layer:** `odin`. **Size:** M (226). **Depends on:** v0-T192.

- [ ] **Step 1:** write the tests.

Write `internal/cli/smoke_realms_test.go`:

```go
package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

func smokeRealms(t *testing.T) string {
	t.Helper()
	p, err := filepath.Abs("../../testdata/smoke-realms")
	if err != nil {
		t.Fatal(err)
	}
	return p
}

// exactContent returns what a smoke prompt asks the agent to write: the text between "with exactly this
// content and nothing else in it:" and the line "Do nothing else".
func exactContent(t *testing.T, prompt string) string {
	t.Helper()
	b, err := os.ReadFile(prompt)
	if err != nil {
		t.Fatal(err)
	}
	_, rest, ok := strings.Cut(string(b), "with exactly this content and nothing else in it:\n\n")
	body, _, ok2 := strings.Cut(rest, "\nDo nothing else")
	if !ok || !ok2 {
		t.Fatalf("%s does not ask for exact content", prompt)
	}
	return strings.TrimRight(body, "\n") + "\n"
}

func indentBlock(s string) string {
	var out []string
	for _, l := range strings.Split(strings.TrimRight(s, "\n"), "\n") {
		out = append(out, "              "+l)
	}
	return strings.Join(out, "\n") + "\n"
}

// The realms smoke run (v0-H13) with real agents has a fixed shape; this runs the same graph with
// scripted agents that write exactly what the prompts ask for. If a prompt asked for a file that Odin
// would refuse, the founder's run with real tokens would fail on it, and this test fails first.
func TestTheSmokeRealmsRunWithScriptedAgentsThatWriteWhatThePromptsAsk(t *testing.T) {
	lead := filepath.Join(smokeRealms(t), "smoke-lead")
	leaves := exactContent(t, filepath.Join(lead, "prompts", "spec.md"))
	tasks := exactContent(t, filepath.Join(lead, "prompts", "plan.md"))
	hello := "    - actions: [ { write: { path: hello.txt, content: \"hello from the factory\\n\" } } ]\n      result: { status: ok, summary: wrote hello.txt }\n"
	script := "steps:\n  spec:\n    - actions:\n        - write:\n            path: out/leaves.yaml\n            content: |\n" + indentBlock(leaves) +
		"      result: { status: ok, summary: wrote the leaves file }\n  plan:\n    - actions:\n        - write:\n            path: out/plan/tasks.md\n            content: |\n" + indentBlock(tasks) +
		"      result: { status: ok, summary: wrote the plan }\n  smoke-t1-implement:\n" + hello + "  smoke-t2-implement:\n" + hello
	scriptPath := filepath.Join(t.TempDir(), "smoke.yaml")
	if err := os.WriteFile(scriptPath, []byte(script), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	cfg := filepath.Join(t.TempDir(), "factory.yaml")
	body := "mode: unattended\ngates:\n  design: auto\nroles:\n  planner: { agent: scripted, model: none, script: " + scriptPath + " }\n  implementer: { agent: scripted, model: none, script: " + scriptPath + " }\n" +
		"budget:\n  per_run: { tokens: 600000, turns: 80 }\n  per_day: { tokens: 1500000, turns: 200 }\nrealms:\n  dir: " + smokeRealms(t) + "\n"
	if err := os.WriteFile(cfg, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	dir := treetest.Project(t)
	code, out, errOut := ygg(t, "run", "--project", dir, "--config", cfg, "--realm", "smoke-lead")
	if code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	u, err := schema.LoadUmbrella(dir)
	if err != nil || u.Realm != "smoke-lead" || u.Children["repos/api"].Realm != "smoke-api" || u.Children["repos/web"].Realm != "smoke-lead" || u.Children["repos/web"].Consumes[0] != "repos/api" {
		t.Errorf("umbrella.yaml = %+v, %v", u, err)
	}
	feats, err := schema.LoadFeatures(filepath.Join(dir, ".factory", "features.json"))
	if err != nil || len(feats.Tasks) != 2 || feats.Tasks[0].Status != schema.TaskDone || feats.Tasks[1].Status != schema.TaskDone {
		t.Errorf("features.json = %+v, %v", feats, err)
	}
	st, _ := run.LoadState(run.Dir(dir, runID(t, dir)))
	if len(st.Realms) != 2 || st.Leaves["repos/api"].Realm != "smoke-api" {
		t.Errorf("run.json realms %v, leaves %v", st.Realms, st.Leaves)
	}
}

// The example config, with the placeholders filled, prepares with the real adapter and finds both realms.
func TestTheSmokeRealmsPrepareWithTheRealAdapter(t *testing.T) {
	b, err := os.ReadFile(filepath.Join(smokeRealms(t), "factory.example.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	cfg := filepath.Join(t.TempDir(), "factory.yaml")
	body := strings.ReplaceAll(string(b), "/home/OPERATOR/yggdrasil/odin/testdata/smoke-realms", smokeRealms(t))
	if err := os.WriteFile(cfg, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	s, err := run.Prepare(ctx, run.Options{Project: treetest.Project(t), Config: cfg, Realm: "smoke-lead"})
	if err != nil {
		t.Fatal(err)
	}
	if s.Agents["planner"].Name() != "claude-code" || s.Agents["implementer"].Name() != "claude-code" || strings.Join(s.Sandbox.Hosts, ",") != "api.anthropic.com" {
		t.Errorf("agents %v, hosts %v", s.Agents, s.Sandbox.Hosts)
	}
	if got := strings.Join(s.Realms.Names(), ","); got != "smoke-lead" {
		t.Errorf("realms = %s; smoke-api joins when init creates its leaf", got)
	}
}
```

Write `testdata/smoke-realms/factory.example.yaml`:

```yaml
# An example factory.yaml for the realms smoke run (v0-H13). Copy it, set the engine, the mounts and the
# realm folder for your machine, and the caps you want; the factory ships no defaults. The credentials
# come from the environment: CLAUDE_CODE_OAUTH_TOKEN, never from this file. Both roles are Claude Code,
# so no OpenRouter key is needed.
mode: unattended
privacy: strict
gates:
  design: auto
roles:
  planner: { agent: claude-code, model: sonnet }
  implementer: { agent: claude-code, model: sonnet }
budget:
  per_run: { tokens: 600000, turns: 80 }
  per_day: { tokens: 1500000, turns: 200 }
sandbox:
  engine: unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock
  mounts:
    - { host: /home/OPERATOR/ygg, engine: /mnt/wsl/ygg-bind }
realms:
  dir: /home/OPERATOR/yggdrasil/odin/testdata/smoke-realms
```

Write `testdata/smoke-realms/smoke-api/pack.yaml`:

```yaml
# The second realm of the realms smoke run: a leaf recipe and no graph, with a stack of its own.
name: smoke-api
version: 0.1.0
checks:
  unit: [grep, -q, hello, hello.txt]
leaf:
  description: A smoke leaf of the second realm.
  template: templates/leaf
  first_commit: [LICENSE]
  implementer: prompts/implementer.md
  checks: [unit]
sandbox:
  stack: docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514
  egress: []
```

Write `testdata/smoke-realms/smoke-api/prompts/implementer.md`:

```md
Create a file named hello.txt in the current directory. Its only content is one line: hello from the factory.

Do nothing else: no other files, no commands that change anything else. Then reply with the word done.
```

Write `testdata/smoke-realms/smoke-api/templates/leaf/LICENSE`:

```text
MIT
```

Write `testdata/smoke-realms/smoke-lead/graph.yaml`:

```yaml
# The realms smoke graph (spec §4.2 in small): two scratch stages with real agents, Odin publishing their
# documents, the plan read into tasks, the leaves created from two realms, and then one implementer
# loop, a merge and a pointer move for each task, in its leaf.
name: smoke-lead
version: 0.1.0
nodes:
  - { id: spec, kind: agent, role: planner, prompt: prompts/spec.md, scratch: true, max_turns: 8, timeout: 5m }
  - { id: spec-docs, kind: publish, from: spec, to: docs }
  - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md, scratch: true, inputs: [docs/leaves.yaml], max_turns: 8, timeout: 5m }
  - { id: plan-docs, kind: publish, from: plan, to: docs }
  - { id: ready, kind: tasks, from: docs/plan/tasks.md, leaves: docs/leaves.yaml, back_to: plan, returns: 1 }
  - { id: leaves, kind: init, from: docs/leaves.yaml }
  - id: tasks
    kind: foreach
    over: tasks
    nodes:
      - { id: implement, kind: loop, realm: leaf, role: implementer, attempts: 2, max_turns: 8, timeout: 5m }
      - { id: land, kind: merge, realm: leaf }
      - { id: move, kind: pointer, realm: leaf }
```

Write `testdata/smoke-realms/smoke-lead/pack.yaml`:

```yaml
# The lead realm of the realms smoke run: real planners write the leaves file and the plan in scratch
# workspaces, Odin publishes them and creates the leaves, and a real implementer builds one small task in
# each leaf. It costs a few cents. The prompts ask for exact files: this run tests the machinery, not the
# planner's judgment.
name: smoke-lead
version: 0.1.0
graph: graph.yaml
checks:
  unit: [grep, -q, hello, hello.txt]
leaf:
  description: A smoke leaf of the lead realm.
  template: templates/leaf
  first_commit: [LICENSE]
  implementer: prompts/implementer.md
  checks: [unit]
sandbox:
  stack: docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514
  egress: []
```

Write `testdata/smoke-realms/smoke-lead/prompts/implementer.md`:

```md
Create a file named hello.txt in the current directory. Its only content is one line: hello from the factory.

Do nothing else: no other files, no commands that change anything else. Then reply with the word done.
```

Write `testdata/smoke-realms/smoke-lead/prompts/plan.md`:

```md
Read docs/leaves.yaml. Write one file, out/plan/tasks.md, with exactly this content and nothing else in it:

# Tasks

## smoke-T1: the api says hello

- **Acceptance criteria:**
  - [ ] hello.txt holds the word hello
- **Named test:** the unit check
- **Layer:** repos/api
- **Size:** S
- **Depends on:** nothing

## smoke-T2: the web leaf says hello

- **Acceptance criteria:**
  - [ ] hello.txt holds the word hello
- **Named test:** the unit check
- **Layer:** repos/web
- **Size:** S
- **Depends on:** smoke-T1

Do nothing else: no other files, no commands that change anything else. Then reply with the word done.
```

Write `testdata/smoke-realms/smoke-lead/prompts/spec.md`:

```md
Write one file, out/leaves.yaml, with exactly this content and nothing else in it:

leaves:
  repos/api:
    realm: smoke-api
    realm_version: 0.1.0
    description: The smoke test's api.
  repos/web:
    realm: smoke-lead
    realm_version: 0.1.0
    description: The smoke test's web leaf.
    consumes: [repos/api]

Do nothing else: no other files, no commands that change anything else. Then reply with the word done.
```

Write `testdata/smoke-realms/smoke-lead/templates/leaf/LICENSE`:

```text
MIT
```

- [ ] **Step 2:** run the named test. It passes at once, because the code or data it needs is already there (or the test is skipped without its build tag): expect `ok`.

- [ ] **Step 3:** run the named test. Expect `ok`.

- [ ] **Step 4:** commit (see "How each task lands").

---

### Task v0-T199: init checks the leaves file against the realms before the run takes them, and a resume keeps the realms a run recorded

Found in review of v0-T186: init took the realms into the run before it checked the leaves file, so a refused file, or an init that stopped half way, left realms in run.json that the project did not yet pin, and a resume refused them.

**Files (in `odin`):**
- Modify: `internal/engine/init.go`, `internal/engine/init_test.go`, `internal/run/run.go`, `internal/run/state.go`

**Interfaces:**
- Produces: `(*Run).PlanRealms(extra)` loads and checks the realms, changing nothing; init checks the leaves file against them, then takes them; a resume loads every realm `run.json` recorded, pinned by the project yet or not.

**Acceptance criteria:**
- [ ] An init that fails after it made one leaf resumes and finishes; a refused leaves file leaves run.json with the realms it had.

**Named test:** `go test ./internal/engine -run 'TestAnInitThatStopsHalfWayCanBeResumedAndFinishes|TestARefusedLeavesFileDoesNotMakeTheRunTakeItsRealms'` in `odin`. **Layer:** `odin`. **Size:** S (78). **Depends on:** v0-T187.

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/init_test.go`:

```diff
diff --git a/internal/engine/init_test.go b/internal/engine/init_test.go
index beefa84..67ceee5 100644
--- a/internal/engine/init_test.go
+++ b/internal/engine/init_test.go
@@ -190,3 +190,48 @@ func TestInitLeavesALeafThatExistsAsItIsAndRefusesToRepinIt(t *testing.T) {
 		t.Errorf("Advance() = %+v, %v", out, err)
 	}
 }
+
+func TestAnInitThatStopsHalfWayCanBeResumedAndFinishes(t *testing.T) {
+	r := initRun(t, galleryLeaves)
+	ctx := context.Background()
+	// repos/web is taken by a folder the project doesn't list, so creating it is refused after repos/api is made.
+	if err := os.MkdirAll(filepath.Join(r.Project, "repos", "web"), 0o755); err != nil {
+		t.Fatal(err)
+	}
+	out, err := Advance(ctx, r)
+	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "exists") {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+	if u, _ := schema.LoadUmbrella(r.Project); len(u.Children) != 1 {
+		t.Fatalf("the project lists %v; repos/api should be there alone", u.Paths())
+	}
+	id, project := r.State.ID, r.Project
+	r.Close()
+	if err := os.Remove(filepath.Join(project, "repos", "web")); err != nil {
+		t.Fatal(err)
+	}
+	again, err := run.Open(ctx, project, id, "")
+	if err != nil {
+		t.Fatalf("Open() = %v; the run loaded helheim-go before it stopped, and a resume keeps it", err)
+	}
+	defer again.Close()
+	if got := strings.Join(again.Setup.Realms.Names(), ","); got != "helheim-go,midgard-react" {
+		t.Errorf("realms after the resume = %s", got)
+	}
+	if out, err := Advance(ctx, again); err != nil || out.Status != run.StatusDone {
+		t.Fatalf("Advance() after the resume = %+v, %v", out, err)
+	}
+	if u, _ := schema.LoadUmbrella(project); len(u.Children) != 2 || u.Children["repos/web"].Realm != "midgard-react" {
+		t.Errorf("the project lists %v after init finished", u.Paths())
+	}
+}
+
+func TestARefusedLeavesFileDoesNotMakeTheRunTakeItsRealms(t *testing.T) {
+	r := initRun(t, strings.Replace(galleryLeaves, "consumes: [repos/api]", "consumes: [repos/db]", 1))
+	if out, err := Advance(context.Background(), r); err != nil || out.Status != run.StatusFailed {
+		t.Fatalf("Advance() = %+v, %v", out, err)
+	}
+	if len(r.State.Realms) != 1 || len(r.Setup.Realms.Realms) != 1 {
+		t.Errorf("run.json holds %v after a leaves file that was refused; the run took no realm", r.State.Realms)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestARefusedLeavesFileDoesNotMakeTheRunTakeItsRealms (0.25s)
    init_test.go:235: run.json holds map[helheim-go:{0.2.0 /tmp/TestARefusedLeavesFileDoesNotMakeTheRunTakeItsRealms2548928159/001/helheim-go d95b79ae2c909eb25dbce5c75572f9cb94e95825016dfa819a256802424e7e9e} midgard-react:{0.1.0 /tmp/TestARefusedLeavesFileDoesNotMakeTheRunTakeItsRealms2548928159/001/midgard-react bea3ec9afd284496452065bad657e6e67966ca6bba7671a5fb1ed9445ee38149}] after a leaves file that was refused; the run took no realm
FAIL
FAIL	github.com/ouroboric-dev/odin/internal/engine	84.820s
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/init.go`:

```diff
diff --git a/internal/engine/init.go b/internal/engine/init.go
index 630bc7a..faba90c 100644
--- a/internal/engine/init.go
+++ b/internal/engine/init.go
@@ -12,6 +12,7 @@ import (
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
+	"github.com/ouroboric-dev/odin/internal/realm"
 	"github.com/ouroboric-dev/odin/internal/remote"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
@@ -34,10 +35,16 @@ func runInit(ctx context.Context, r *run.Run, n schema.Node) error {
 	if err != nil {
 		return &nodeFailure{err}
 	}
-	if err := r.AddRealms(spec.Pins()); err != nil {
+	// The realms are loaded and the leaves file is checked against them before the run takes the realms
+	// or anything is created.
+	set, err := r.PlanRealms(spec.Pins())
+	if err != nil {
 		return &nodeFailure{err}
 	}
-	if err := checkLeaves(r, spec); err != nil {
+	if err := checkLeaves(r, set, spec); err != nil {
+		return &nodeFailure{err}
+	}
+	if err := r.AddRealms(spec.Pins()); err != nil {
 		return &nodeFailure{err}
 	}
 	var created, kept []string
@@ -77,12 +84,12 @@ func readLeaves(r *run.Run, n schema.Node) (*schema.Leaves, error) {
 
 // checkLeaves checks, before anything is created, that each leaf can be: its realm offers a leaf recipe,
 // one that exists already is pinned as the file says, and what a leaf consumes will exist.
-func checkLeaves(r *run.Run, spec *schema.Leaves) error {
+func checkLeaves(r *run.Run, set *realm.Set, spec *schema.Leaves) error {
 	var problems []string
 	have := r.Setup.Project.Umbrella.Children
 	for _, p := range spec.Paths() {
 		l := spec.Leaves[p]
-		rl := r.Setup.Realms.Realms[l.Realm]
+		rl := set.Realms[l.Realm]
 		if rl.Pack.Leaf == nil {
 			problems = append(problems, fmt.Sprintf("%s: the realm %s offers no leaf recipe (a template, an implementer prompt and checks), so it can't provide a leaf", p, l.Realm))
 		}
```

Apply to `internal/run/run.go`:

```diff
diff --git a/internal/run/run.go b/internal/run/run.go
index 7ff043f..76ecd7c 100644
--- a/internal/run/run.go
+++ b/internal/run/run.go
@@ -363,9 +363,28 @@ func (s *Setup) loadRealm(name string) (*realm.Realm, error) {
 // extra name. The pins must agree with each other and with what the realm store holds (change
 // realm-leaf-naming), so a mismatch stops the run before anything is created or started.
 func (s *Setup) collectRealms(extra []schema.Pin) (*realm.Set, error) {
-	return realm.Collect(s.Lead, append(s.projectPins(), extra...), s.loadRealm)
+	set, err := realm.Collect(s.Lead, append(s.projectPins(), extra...), s.loadRealm)
+	if err != nil {
+		return nil, err
+	}
+	// A resumed run keeps every realm it recorded, whether or not the project pins it yet: init loads a
+	// realm, and may stop before it has created the leaf that pins it.
+	for name, dir := range s.recorded {
+		if set.Realms[name] == nil {
+			x, err := realm.Load(dir)
+			if err != nil {
+				return nil, err
+			}
+			set.Realms[name] = x
+		}
+	}
+	return set, nil
 }
 
+// PlanRealms loads and checks the realms that extra pins would add to the run, as AddRealms does, and
+// changes nothing: a caller can look at the realms before it commits the run to them.
+func (r *Run) PlanRealms(extra []schema.Pin) (*realm.Set, error) { return r.Setup.collectRealms(extra) }
+
 // AddRealms loads the realms that extra pins name and the run doesn't have yet, after checking that
 // every pin of the project, the old and the new, agrees. The spec stage names the product's leaves and
 // their realms, and init is where they join the run. Each new realm is recorded in run.json and the
```

Apply to `internal/run/state.go`:

```diff
diff --git a/internal/run/state.go b/internal/run/state.go
index 05cda67..b533225 100644
--- a/internal/run/state.go
+++ b/internal/run/state.go
@@ -310,8 +310,8 @@ func Lock(dir string) (unlock func(), err error) {
 // can't make another process's resume fail.
 func Locked(dir string) bool { return lock.Held(filepath.Join(dir, "lock")) }
 
-// checkRealms refuses a resume when a realm changed under the run, or the project's pins no longer name
-// the realms the run started with: its graph positions and prompts would no longer mean what they meant.
+// checkRealms refuses a resume when a realm changed under the run, or the project now names a realm the run
+// did not load: its graph positions and prompts would no longer mean what they meant.
 func (s *State) checkRealms(setup *Setup) error {
 	if len(s.Realms) == 0 {
 		return nil // a run from before realms were recorded; the graph's hash is all there is
@@ -328,11 +328,6 @@ func (s *State) checkRealms(setup *Setup) error {
 			return fmt.Errorf("the realm %s changed since the run started (%s), so the run's prompts and checks are not the ones it began with; start a new run", name, want.Dir)
 		}
 	}
-	for name := range s.Realms {
-		if setup.Realms.Realms[name] == nil {
-			return fmt.Errorf("the run started with the realm %s, which the project no longer names; start a new run", name)
-		}
-	}
 	return nil
 }
 
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T200: the local remote refuses a leaf inside another child, or holding one, before it creates anything

A child is never inside another (the umbrella's own rule), but `Create` learned that only when it saved `umbrella.yaml`, after `git submodule add` had staged the leaf (backlog B-003). A leaves file from a planner can name such a path.

**Files (in `odin`):**
- Modify: `internal/remote/local.go`, `internal/remote/local_test.go`

**Interfaces:**
- Produces: `Local.Create` checks the path against the umbrella's children before it makes anything.

**Acceptance criteria:**
- [ ] A leaf inside a leaf is refused with "never inside another", with no commit and a clean umbrella.

**Named test:** `go test ./internal/remote -run 'TestLocalCreateRefusesALeafInsideAnotherChildOrHoldingOne'` in `odin`. **Layer:** `odin`. **Size:** S (31). **Depends on:** v0-T184.

- [ ] **Step 1:** write the tests.

Apply to `internal/remote/local_test.go`:

```diff
diff --git a/internal/remote/local_test.go b/internal/remote/local_test.go
index c057d57..6ca7379 100644
--- a/internal/remote/local_test.go
+++ b/internal/remote/local_test.go
@@ -153,3 +153,28 @@ func TestLocalCreateRecordsTheRealmPinAndWhatTheLeafConsumesInTheSameCommit(t *t
 		t.Errorf("a refused leaf left the umbrella dirty: %q", st)
 	}
 }
+
+func TestLocalCreateRefusesALeafInsideAnotherChildOrHoldingOne(t *testing.T) {
+	_, parent := gallery(t)
+	l := NewLocal(parent)
+	before, _ := git.Run(ctx, parent.Dir, "rev-parse", "HEAD")
+	for name, path := range map[string]string{"inside a leaf": "repos/api/sub", "holding a leaf": "repos"} {
+		r := blog()
+		r.Path, r.Name = path, "x"
+		if err := l.Create(ctx, r); err == nil {
+			t.Errorf("%s (%s): Create() = nil", name, path)
+		}
+	}
+	// A folder the project doesn't have yet, whose name is a leaf's folder plus more, is what the check is for.
+	deeper := blog()
+	deeper.Path, deeper.Name = "repos/api/sub", "x"
+	if err := l.Create(ctx, deeper); err == nil || !strings.Contains(err.Error(), "never inside another") {
+		t.Errorf("a leaf inside a leaf: Create() = %v", err)
+	}
+	if after, _ := git.Run(ctx, parent.Dir, "rev-parse", "HEAD"); after != before {
+		t.Error("the umbrella got a commit for a leaf that was refused")
+	}
+	if st, _ := git.Run(ctx, parent.Dir, "status", "--porcelain"); st != "" {
+		t.Errorf("a refused leaf left the umbrella dirty: %q", st)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestLocalCreateRefusesALeafInsideAnotherChildOrHoldingOne (0.69s)
    local_test.go:172: a leaf inside a leaf: Create() = /tmp/TestLocalCreateRefusesALeafInsideAnotherChildOrHoldingOne336553789/018/l0/projects/gallery/repos/api/sub exists, so nothing was created
FAIL
FAIL	github.com/ouroboric-dev/odin/internal/remote	3.574s
```

- [ ] **Step 3:** write the code.

Apply to `internal/remote/local.go`:

```diff
diff --git a/internal/remote/local.go b/internal/remote/local.go
index 53e1cd1..1bb73e7 100644
--- a/internal/remote/local.go
+++ b/internal/remote/local.go
@@ -10,6 +10,7 @@ import (
 	"os"
 	"path/filepath"
 	"slices"
+	"strings"
 
 	"github.com/ouroboric-dev/gungnir"
 	"github.com/ouroboric-dev/gungnir/schema"
@@ -49,6 +50,11 @@ func (l *Local) Create(ctx context.Context, r gungnir.Repo) error {
 	if _, listed := p.Umbrella.Children[r.Path]; listed {
 		return fmt.Errorf("the umbrella %q already lists %s, so nothing was created", p.Path, r.Path)
 	}
+	for q := range p.Umbrella.Children {
+		if strings.HasPrefix(r.Path, q+"/") || strings.HasPrefix(q, r.Path+"/") {
+			return fmt.Errorf("%s would be inside %s or hold it, and a child is never inside another, so nothing was created", r.Path, q)
+		}
+	}
 	for _, c := range r.Consumes {
 		if p.Umbrella.Children[c].Kind != schema.ChildLeaf {
 			return fmt.Errorf("%s consumes %s, which %q doesn't list as a leaf, so nothing was created", r.Path, c, p.Path)
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T201: a plan in a project with no leaves is checked against no leaves

`CheckReady` skips the layer check when it is given no list. A project with no leaf and no leaves file gave it none.

**Files (in `odin`):**
- Modify: `internal/engine/stages.go`, `internal/engine/tasks_test.go`

**Interfaces:**
- Produces: the tasks node always gives a list, empty when there is no leaf.

**Acceptance criteria:**
- [ ] A task naming a layer in a project with no leaf is refused: `layer "repos/anything" is not a leaf of this project ()`.

**Named test:** `go test ./internal/engine -run 'TestAPlanInAProjectWithNoLeafIsCheckedAgainstNoLeavesNotNotAtAll'` in `odin`. **Layer:** `odin`. **Size:** S (11). **Depends on:** v0-T176.

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/tasks_test.go`:

```diff
diff --git a/internal/engine/tasks_test.go b/internal/engine/tasks_test.go
index 2f2a2f2..722f9e6 100644
--- a/internal/engine/tasks_test.go
+++ b/internal/engine/tasks_test.go
@@ -197,3 +197,13 @@ func TestARejectionGivesARefusalItsReturnsAgain(t *testing.T) {
 		t.Errorf("Advance() = %+v, %v (planner ran %d times); want the plan back at the gate after one more return", out, err, r.State.Attempts["plan"])
 	}
 }
+
+func TestAPlanInAProjectWithNoLeafIsCheckedAgainstNoLeavesNotNotAtAll(t *testing.T) {
+	r := startRealms(t, realmsSetup{nodes: "  - { id: ready, kind: tasks, from: tasks.md }\n", script: "steps: {}\n",
+		realms: []realmFiles{recipeRealm("midgard-react", "0.1.0", "web.txt", "Web.")}})
+	os.WriteFile(filepath.Join(r.Project, "tasks.md"), []byte(readyPlan+taskMD("p-T1", "repos/anything", "S", "nothing")), 0o644)
+	out, err := Advance(context.Background(), r)
+	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), `layer "repos/anything" is not a leaf of this project ()`) {
+		t.Errorf("Advance() = %+v, %v", out, err)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAPlanInAProjectWithNoLeafIsCheckedAgainstNoLeavesNotNotAtAll (0.15s)
    tasks_test.go:207: Advance() = {Status:done Gate: Err:<nil> Warn:[]}, <nil>
FAIL
FAIL	github.com/ouroboric-dev/odin/internal/engine	86.606s
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/stages.go`:

```diff
diff --git a/internal/engine/stages.go b/internal/engine/stages.go
index a4fc766..f025d77 100644
--- a/internal/engine/stages.go
+++ b/internal/engine/stages.go
@@ -113,6 +113,7 @@ func readPlan(r *run.Run, n schema.Node) (fs []schema.Feature, source, sum, refu
 // planLeaves returns the leaves a task may work in: those the project has, and those the spec stage named
 // in the leaves file the node points at, which init has not created yet.
 func planLeaves(r *run.Run, n schema.Node) (leaves []string, refusal string, err error) {
+	leaves = []string{} // never nil: no leaf at all is a list a layer is checked against, not no check
 	if u := r.Setup.Project.Umbrella; u != nil {
 		for _, p := range u.Paths() {
 			if u.Children[p].Kind == schema.ChildLeaf {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T202: ygg sandbox build also pulls the images of the services of the realms it builds

A sandbox refuses a service whose image was never pulled (the task before this one in Gleipnir), and only `ygg sandbox build` may reach a registry.

**Files (in `odin`):**
- Modify: `internal/cli/sandbox.go`, `internal/cli/sandbox_realms_test.go`

**Interfaces:**
- Produces: after the stacks, `ygg sandbox build` pulls each distinct service image of the realms it built, through `Driver.Pull`, and prints a line for each. A realm with no stack is skipped under `--all` and its services with it.

**Acceptance criteria:**
- [ ] Two realms that share one service image pull it once; a realm with none pulls nothing.

**Named test:** `go test ./internal/cli -run 'TestSandboxBuild'` in `odin`. **Layer:** `odin`. **Size:** S (46). **Depends on:** v0-T188, v0-T163.

- [ ] **Step 1:** write the tests.

Apply to `internal/cli/sandbox_realms_test.go`:

```diff
diff --git a/internal/cli/sandbox_realms_test.go b/internal/cli/sandbox_realms_test.go
index 4494868..7d46335 100644
--- a/internal/cli/sandbox_realms_test.go
+++ b/internal/cli/sandbox_realms_test.go
@@ -10,6 +10,7 @@ import (
 const (
 	goStack   = "docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514"
 	nodeStack = "docker.io/library/node:24.1.0-bookworm@sha256:3333333333333333333333333333333333333333333333333333333333333333"
+	pgImage   = "docker.io/library/postgres:17.2@sha256:1111111111111111111111111111111111111111111111111111111111111111"
 )
 
 // realmsStore writes a realm store: midgard-react and helheim-go on stacks of their own, a third realm on
@@ -22,6 +23,9 @@ func realmsStore(t *testing.T) (store, config string) {
 		if stack != "" {
 			body += "sandbox:\n  stack: " + stack + "\n"
 		}
+		if name != "midgard-react" { // two realms share one service image, a third has none
+			body += "services:\n  postgres:\n    image: " + pgImage + "\n    ports: [5432]\n"
+		}
 		if err := os.MkdirAll(filepath.Join(store, name), 0o755); err != nil {
 			t.Fatal(err)
 		}
@@ -49,6 +53,17 @@ func builds(log string) []string {
 	return out
 }
 
+func pulls(log string) []string {
+	b, _ := os.ReadFile(log)
+	var out []string
+	for _, line := range strings.Split(string(b), "\n") {
+		if strings.HasPrefix(line, "podman pull ") && strings.HasSuffix(line, pgImage) {
+			out = append(out, line)
+		}
+	}
+	return out
+}
+
 func TestSandboxBuildBuildsTheStackOfEveryRealmNamed(t *testing.T) {
 	log := stubEngine(t)
 	_, config := realmsStore(t)
@@ -63,6 +78,9 @@ func TestSandboxBuildBuildsTheStackOfEveryRealmNamed(t *testing.T) {
 	if strings.Count(out, "Built:") != 2 {
 		t.Errorf("output:\n%s", out)
 	}
+	if got := pulls(log); len(got) != 1 || !strings.Contains(out, "Pulling the service image "+pgImage) {
+		t.Errorf("the service image was pulled %d times; helheim-go has one, midgard-react none:\n%s", len(got), out)
+	}
 }
 
 func TestSandboxBuildAllBuildsEachStackOnceAndSkipsRealmsWithNone(t *testing.T) {
@@ -78,6 +96,9 @@ func TestSandboxBuildAllBuildsEachStackOnceAndSkipsRealmsWithNone(t *testing.T)
 	if !strings.Contains(out, "asgard names no sandbox stack; skipped") {
 		t.Errorf("output lacks the skipped realm:\n%s", out)
 	}
+	if got := pulls(log); len(got) != 1 {
+		t.Errorf("the service image shared by two realms was pulled %d times, want once:\n%s", len(got), strings.Join(got, "\n"))
+	}
 }
 
 func TestSandboxBuildNeedsARealmOrAllAndAStoreForNames(t *testing.T) {
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestSandboxBuildBuildsTheStackOfEveryRealmNamed (0.07s)
    sandbox_realms_test.go:82: the service image was pulled 0 times; helheim-go has one, midgard-react none:
        Pulling and building the images for docker.io/library/node:24.1.0-bookworm@sha256:3333333333333333333333333333333333333333333333333333333333333333; this takes a few minutes.
        Built:
```

- [ ] **Step 3:** write the code.

Apply to `internal/cli/sandbox.go`:

```diff
diff --git a/internal/cli/sandbox.go b/internal/cli/sandbox.go
index 5c542ae..99327e6 100644
--- a/internal/cli/sandbox.go
+++ b/internal/cli/sandbox.go
@@ -42,7 +42,7 @@ func (c *command) sandbox(args []string) int {
 	if cfg.Sandbox == nil {
 		return c.refuse(fmt.Errorf("%s has no sandbox section", f.config))
 	}
-	stacks, skipped, err := stacksToBuild(cfg, f.realms, f.all)
+	stacks, services, skipped, err := stacksToBuild(cfg, f.realms, f.all)
 	if err != nil {
 		return c.refuse(err)
 	}
@@ -67,13 +67,21 @@ func (c *command) sandbox(args []string) int {
 		}
 		fmt.Fprintf(c.out, "Built:\n  %s\n  %s\n", imgs.Work, imgs.Firewall)
 	}
+	for _, image := range services {
+		fmt.Fprintf(c.out, "Pulling the service image %s.\n", image)
+		if err := d.Pull(c.ctx, image); err != nil {
+			fmt.Fprintf(c.err, "ygg: pulling a service image failed: %v\n", err)
+			return ExitFailed
+		}
+	}
 	return ExitDone
 }
 
 // stacksToBuild returns the distinct sandbox stacks of the realms named, in the order named, or of every
-// realm in the store with --all. A realm named on purpose that has no stack is an error; with --all it
-// is skipped, and the skip is returned for the output.
-func stacksToBuild(cfg *schema.Factory, refs []string, all bool) (stacks, skipped []string, err error) {
+// realm in the store with --all, and the distinct images of their services, which a sandbox uses without
+// ever pulling them. A realm named on purpose that has no stack is an error; with --all it is skipped,
+// and the skip is returned for the output.
+func stacksToBuild(cfg *schema.Factory, refs []string, all bool) (stacks, services, skipped []string, err error) {
 	var store *realm.Store
 	if cfg.Realms != nil {
 		store = &realm.Store{Dir: cfg.Realms.Dir}
@@ -81,11 +89,11 @@ func stacksToBuild(cfg *schema.Factory, refs []string, all bool) (stacks, skippe
 	var dirs []string
 	if all {
 		if store == nil {
-			return nil, nil, errors.New("--all needs factory.yaml's realms section, which says where the realm leaves are")
+			return nil, nil, nil, errors.New("--all needs factory.yaml's realms section, which says where the realm leaves are")
 		}
 		entries, err := os.ReadDir(store.Dir)
 		if err != nil {
-			return nil, nil, err
+			return nil, nil, nil, err
 		}
 		for _, e := range entries {
 			if _, err := os.Stat(filepath.Join(store.Dir, e.Name(), "pack.yaml")); err == nil {
@@ -96,23 +104,30 @@ func stacksToBuild(cfg *schema.Factory, refs []string, all bool) (stacks, skippe
 	for _, ref := range refs {
 		dir, _, err := realm.Resolve(ref, store)
 		if err != nil {
-			return nil, nil, err
+			return nil, nil, nil, err
 		}
 		dirs = append(dirs, dir)
 	}
 	for _, dir := range dirs {
 		pack, err := schema.LoadPack(dir)
 		if err != nil {
-			return nil, nil, err
+			return nil, nil, nil, err
 		}
 		switch {
 		case pack.Sandbox == nil && all:
 			skipped = append(skipped, fmt.Sprintf("The realm %s names no sandbox stack; skipped.", pack.Name))
 		case pack.Sandbox == nil:
-			return nil, nil, fmt.Errorf("the realm %s names no sandbox stack in its pack.yaml", pack.Name)
+			return nil, nil, nil, fmt.Errorf("the realm %s names no sandbox stack in its pack.yaml", pack.Name)
 		case !slices.Contains(stacks, pack.Sandbox.Stack):
 			stacks = append(stacks, pack.Sandbox.Stack)
 		}
+		if pack.Sandbox != nil {
+			for _, v := range pack.ServiceList() {
+				if !slices.Contains(services, v.Image) {
+					services = append(services, v.Image)
+				}
+			}
+		}
 	}
-	return stacks, skipped, nil
+	return stacks, services, skipped, nil
 }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T203: Odin's documentation

The architecture page says what the component now does.

**Files (in `odin`):**
- Modify: `docs/architecture.md`

**Acceptance criteria:**
- [ ] `docs/architecture.md` says how a run loads realms, runs the stages before the code, repeats a task shape, sends a refusal back, gives a task up, and starts each leaf's sandbox.

**Named test:** `go test ./...` in `odin`. **Layer:** `odin`. **Size:** S (16). **Depends on:** v0-T202.

- [ ] **Step 1:** write the code.

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 0d99df1..c967a34 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -15,6 +15,22 @@ The orchestrator: the graph engine and the `ygg` CLI, with routing and the ledge
 - Loads realm graphs and `factory.yaml`.
 - Walks the graph and runs exec, agent, loop and gate nodes; checkpoints runs and resumes them. A
   loop node is Jormungandr's loop with Odin's steps: sessions, checks, ledger lines and `run.json`.
+- Loads realm leaves (change realm-leaf-naming): `--realm` names the lead realm, found in the realm
+  store of `factory.yaml` or given as a path; each leaf runs with the realm the project pins for it;
+  each realm loads once, at the pinned version, and two pins that disagree stop the run before any
+  sandbox comes up. `run.json` records every realm with a hash of what a run could read, and a resume
+  refuses a realm that changed. The first run of a project pins its lead realm.
+- Runs the stages before the code: a scratch agent works in a workspace of its own (the brief, copies
+  of what it reads, an `out/` folder); `publish` copies its documents into the project and commits them,
+  after checking they are documents and hold no secret; `tasks` reads `tasks.md`, applies the Definition
+  of Ready and writes `features.json`; `init` creates the leaves the spec stage named from their realms'
+  templates and records the pins.
+- Repeats a task shape for every ready task (`foreach`), in the leaf and the realm of the task. A
+  merge gate or pointer move that refuses the work's checks sends it back into the loop that made it
+  (`back_to`, a few times). An unattended run gives up a task whose loop gave up, keeps its work on a
+  ref, and goes on with the tasks that do not depend on it.
+- Starts each leaf's sandbox on its realm's stack, with the services of its realm and of the leaves it
+  consumes (spec §6.1, §9.2).
 - Counts every session's usage, a failed one's too, in the run and in a daily spend journal outside
   any project, and stops the run at the hard approval point `budget-cap` before a session would start
   over a cap (spec §7.4). Pauses the run when the provider's quota is used up (spec §12).
```

- [ ] **Step 2:** run the named test. Expect `ok`.

- [ ] **Step 3:** commit (see "How each task lands").

---

### Task v0-T204: pointers and the exit check

The umbrella moves the four pointers once, and the exit check runs on the merged code.

**Files (in `yggdrasil`):**
- Modify: the submodule pointers of `gungnir`, `gleipnir`, `jormungandr` and `odin`;
  `docs/2-engineering/backlog.md`.

**Acceptance criteria:**
- [ ] After all four pull requests are merged, the pointers are at each repo's `main`, and `go.work`
      builds them together: `go vet ./...` and `go test ./...` pass in each repo with `go.work` and with
      `GOWORK=off`.
- [ ] The exit criterion: `go test -run 'TestARunOfTheToyRealms|TestAnUnattendedRunOfTheToyRealms|TestARunWhoseRealmPinsDisagree|TestTheSmokeRealms' ./internal/cli`
      in `odin` passes on the merged code (the engine of this phase, end to end with scripted agents), and
      the founder's two real runs happened: v0-H12 (services and a scratch folder on a real engine) and
      v0-H13 (the realms smoke run with real agents). The ledger lines are in the pull request.
- [ ] Backlog B-010, B-015, B-035 and B-036 move to Done, each with the pull request that fixed it
      (gleipnir's for B-015, odin's for B-010, B-035 and B-036). B-005, B-006, B-037 and B-039 get a note,
      and stay open: B-005 and B-006 because this phase leaves `Prepare` and the lock names as they were;
      B-037 and B-039 because gates still assume a terminal and the factory still runs on WSL2 only (both
      are Phase 5b/5c or later).

**Named test:** `go test ./...` in each repo, and the evidence of v0-H12 and v0-H13. **Layer:** `yggdrasil`.
**Size:** S. **Depends on:** all above, merged.

- [ ] **Step 1:** switch each local copy to `main` and pull. Then, in `yggdrasil`:

```bash
git switch -c phase-5a/pointers
git submodule update --remote gungnir gleipnir jormungandr odin
git status --short
```

- [ ] **Step 2:** in `docs/2-engineering/backlog.md`, move the four items to **Done**, each with the pull
      request that fixed it, and add the one-line notes to B-005, B-006, B-037 and B-039.
- [ ] **Step 3:** run the exit check: `go vet ./... && go test ./...` in each of the four repos, with
      `go.work` and with `GOWORK=off`, and paste the output and v0-H12's and v0-H13's results into the PR body.
- [ ] **Step 4:** stage the four pointers and the backlog by path, commit, push and open the pull
      request (see "How each task lands").

---

### Task v0-H12 (founder): services and a scratch folder on a real engine

Phase 5a's sandbox starts a service (a database, say) beside the work container, opens only its ports,
and gives a scratch agent one plain folder. The unit tests use a fake engine; two tests behind the
`sandbox` tag check them on a real one. They need an image that listens on a port. **Do this only after
v0-T163 (gleipnir's `Pull`) is merged, with the engine up (Phase 3's v0-H07) and the images built
(Phase 3's v0-H09).**

**Named test:** the two tests below pass, and neither is skipped. **Layer:** the founder's machine.
**Size:** S. **Depends on:** v0-T163 merged; Phase 3's v0-H07 and v0-H09.

- [ ] **Step 1:** pull a small image and get its digest (a tag alone is refused):

```bash
podman pull docker.io/library/nginx:1.27-alpine
podman image inspect --format '{{index .RepoDigests 0}}' docker.io/library/nginx:1.27-alpine
```

- [ ] **Step 2:** run the tests, with the image from step 1 and the same three variables Phase 3's
      v0-H09 used for the driver test:

```bash
cd ~/brunogbv/ouroboric/yggdrasil/gleipnir
YGG_SANDBOX_ENGINE=unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock \
YGG_SANDBOX_TREE=$HOME/ygg-it YGG_SANDBOX_TREE_ENGINE=/mnt/wsl/ygg-bind \
YGG_SANDBOX_SERVICE_IMAGE='<the digest line from step 1>' YGG_SANDBOX_SERVICE_PORT=80 \
go test -tags sandbox -count=1 -v -timeout 40m -run 'TestSandboxServices|TestSandboxScratch' ./sandbox
```

- [ ] **Step 3:** send back the output (no secret is in it). If a test fails, send the error text too.

---

### Task v0-H13 (founder): the realms smoke run with real agents

The exit criterion's real half: two realms, real planners that write the leaves file and the plan in
scratch workspaces in sandboxes, Odin publishing them and creating two leaves from their realms'
templates, and a real implementer building one task in each leaf. It tests the machinery, not the
model's judgment. It uses your tokens and costs a few cents, so you run it, or you tell an agent to.
**Do this only after v0-T198 is merged, with the engine up (Phase 3's v0-H07) and the images built
(Phase 3's v0-H09).**

**Named test:** the run finishes; its report (`h13-report.txt`) shows `realm_loaded` for both realms,
`repo_created` for both leaves, `docs_published` twice, `tasks_ready`, and `task_done` for each task;
and no `task_blocked`. **Layer:** the founder's machine. **Size:** S. **Depends on:** v0-T198 merged;
Phase 3's v0-H07 and v0-H09; the `ouroboric` pull request of this phase (`scripts/ygg-smoke-realms.sh`) merged.

- [ ] **Step 1:** copy `odin/testdata/smoke-realms/factory.example.yaml` over `~/ygg-it/factory.yaml`, or
      merge it into yours (keep `mounts.host` as `/home/brunogbv/ygg-it`), set `realms.dir` to
      `/home/brunogbv/brunogbv/ouroboric/yggdrasil/odin/testdata/smoke-realms`, and set the caps you want.
- [ ] **Step 2:** run the script. It checks the devcontainer CLI and the bind mount, makes a fresh project,
      loads the credentials from `~/.config/ouroboric/factory.env` without printing them, builds the
      images (`--build`, once), runs the realm, and prints a report with the credentials removed:

```bash
cd ~/brunogbv/ouroboric/ouroboric
scripts/ygg-smoke-realms.sh --build
```

- [ ] **Step 3:** send back the report it prints (also in `~/ygg-it/h13-report.txt`), not the raw output.
      If a step fails, send the error text and `ygg doctor`'s output.
- [ ] **Step 4 (optional, and what teaches the factory):** if a planner's `leaves.yaml` or `tasks.md` was
      refused, send the refusal text and the file: the prompts in `smoke-lead` are one line each in the
      realm, and a real refusal is the best fix for them.

---

## Evidence

What was run while this plan was written, on 2026-10-17, on this machine (WSL2, Go 1.26.4; Go 1.26.9
through `GOTOOLCHAIN`).

**Tests.** `gofmt -l .` prints nothing, `go vet ./...` is clean, and `go test -race -count=1 ./...`
passes in all four repos on Go 1.26.4 and on Go 1.26.9. The reference workspace builds the four repos
together through a `go.work`; the siblings are pinned by the last commit of each pull request once its
siblings are merged, as in Phase 2 to Phase 4.

**Each task alone.** `plan-states.sh` built and tested every task commit on its own: 62 of 62 pass (15 in `gungnir`, 8 in `gleipnir`, 3 in `jormungandr`, 36 in `odin`).

**Each first failure.** `plan-red.sh` put each task's test files on the task's parent commit: the first
failure of each is the one its step shows. Eight tasks have none, and say so: the four documentation tasks
(v0-T156, v0-T164, v0-T167, v0-T203), which have no test; v0-T162, whose tests are behind the `sandbox` tag and
skip without an engine; and v0-T192, v0-T193 and v0-T198, which add tests and test data for behavior the
tasks before them built (the end-to-end run of the toy realms, a documents realm in a project with no
leaves, and the smoke realms' prompts), and so pass at once.

**The plan reproduces the code.** `plan-replay.py` applied the plan's steps to fresh clones of
each repo at its merge base: the trees are identical to the reference's, for all four repos.

**The defences each fail when removed.** For each row, the defence was removed from the code, the named
test was run, and it failed; then the code was restored. (`scripts/plan-defences.py` does it, from the
rows in `defences.json` of the SDD folder; an executor can run it again on the merged code.)

| Task | Defence removed | Test that fails |
|---|---|---|
| v0-T142 | leaves that consume each other in a ring | `TestParseUmbrellaRefusesBadRealmPins` |
| v0-T144 | a service env that names a credential | `TestASandboxSpecMayCarryAStackAndServices` |
| v0-T150 | a heading inside a code fence is not a task | `TestParseTasksReadsTheCanonicalLayout` |
| v0-T151 | a task of size L must be split | `TestCheckReadyListsEveryReasonATaskIsNotReady` |
| v0-T158 | a privileged service is refused before it starts | `TestAServiceTheFactoryDidNotWriteIsRefusedBeforeItStarts` |
| v0-T159 | the firewall opens a service's listed ports and no others | `TestEgressOpensAServicesPortsAndNoOthers` |
| v0-T161 | a scratch sandbox mounts no git dir | `TestAScratchSandboxMountsOneFolderAndNothingElse` |
| v0-T165 | a reopened loop runs again | `TestALoopThatPassedIsReopenedWhenSomethingDownstreamRefusesItsWork` |
| v0-T169 | two pins of one realm at different versions | `TestTwoPinsOfOneRealmThatDisagreeStopTheRun` |
| v0-T170 | a realm that changed under a run is refused on resume | `TestRunJSONRecordsEveryRealmAndAResumeRefusesOneThatChanged` |
| v0-T171 | the operator's uncommitted umbrella.yaml is not committed by the pin | `TestARunWontPinOverUncommittedWork` |
| v0-T172 | a node id two tasks would share | `TestExpandRefusesWhatItCannotPlace` |
| v0-T174 | two realms offering different services of one name | `TestTwoRealmsOfferingDifferentServicesOfOneNameStopTheRunBeforeASandboxStarts` |
| v0-T177 | a plan that is not ready is refused | `TestAPlanThatIsNotReadyGoesBackToThePlannerWithEveryProblem` |
| v0-T177 | a refusal goes back at most `returns` times | `TestARefusalGoesBackOnlyAsOftenAsTheNodeAllows` |
| v0-T178 | a task in a leaf whose realm offers no recipe fails the node | `TestATaskInALeafWhoseRealmOffersNoRecipeFailsTheNode` |
| v0-T179 | a waiver lasts one move | `TestAWaiverIsForOneMoveWhateverBecomesOfIt` |
| v0-T179 | a shrink-guard stop closes its attempt in the ledger | `TestAShrinkGuardStopClosesTheAttemptTheLedgerOpened` |
| v0-T180 | a conflict is not sent back to the implementer | `TestABaseThatDoesNotMergeCleanlyIsNotSentBack` |
| v0-T181 | only an unattended run gives a task up | `TestOtherModesStopAtTheLoopThatGaveUp` |
| v0-T181 | a task that depends on a blocked task is blocked | `TestAnUnattendedRunGivesUpATaskWhoseLoopGaveUpAndGoesOnWithTheRest` |
| v0-T182 | a symlink in a scratch input is refused | `TestAnInputThatCouldLeadOutOfTheProjectIsRefused` |
| v0-T183 | only documents are published | `TestPublishRefusesWhatIsNotADocument` |
| v0-T183 | documents are scanned for secrets before they are published | `TestSecretsInTheDocumentsAreAHardStopAndNothingIsPublished` |
| v0-T187 | init refuses a leaves file before it creates anything | `TestInitRefusesBeforeItCreatesAnything` |
| v0-T188 | each stack is built once | `TestSandboxBuildAllBuildsEachStackOnceAndSkipsRealmsWithNone` |
| v0-T191 | acceptance checks are the lead realm's | `TestAPointersAcceptanceChecksAreTheLeadRealmsEvenInALeafOfAnotherRealm` |
| v0-T194 | nothing is published through a symlink | `TestPublishWritesNothingThroughASymlinkInTheProject` |
| v0-T195 | a task's words are bounded in a prompt | `TestATasksWordsAreBoundedInAPrompt` |
| v0-T196 | acceptance checks in a task shape are refused with a sandbox on | `TestPrepareRefusesWhatWouldRunOutsideTheSandbox` |
| v0-T197 | a rejection gives a refusal its returns again | `TestARejectionGivesARefusalItsReturnsAgain` |
| v0-T199 | a refused leaves file does not make the run take its realms | `TestARefusedLeavesFileDoesNotMakeTheRunTakeItsRealms` |
| v0-T200 | a leaf inside another child is refused | `TestLocalCreateRefusesALeafInsideAnotherChildOrHoldingOne` |
| v0-T201 | a plan with no leaf to work in is refused | `TestAPlanInAProjectWithNoLeafIsCheckedAgainstNoLeavesNotNotAtAll` |

The first run of this table showed eight rows that did not fail. Six mutations did not compile or ran the
wrong package, and one hung (removing the check that a `foreach` node has a plan makes the walk expand
nothing for ever, so that row was replaced by a defence of the same task whose removal fails fast). The
eighth, "a resume keeps the realms the run recorded", passed without the defence, because a leaf's pin loads
the realm anyway; its row now moves `AddRealms` before the leaves file is checked, which
`TestARefusedLeavesFileDoesNotMakeTheRunTakeItsRealms` catches.

**Defects the build found, which the tasks above carry fixed:**

1. A run whose `init` was refused or stopped half way had already recorded the leaf realms in `run.json`,
   so a resume refused them as a change: `PlanRealms` comes before `AddRealms`, and a resume keeps the
   realms the run recorded (v0-T188, v0-T199).
2. The last task stayed `doing` when the tasks after it were skipped: finishing a task and starting the
   next one are separate steps around the skip (v0-T190).
3. A pointer move's acceptance checks ran the checks of the leaf's realm, and panicked on an empty
   argument vector for a realm that doesn't define the check: they are the lead realm's, and an
   undefined check is an error (v0-T191).
4. A path could reach outside the project through a symlink on any component, for a published document,
   a scratch input, a plan glob and a leaves file: every one of them refuses a symlink (v0-T194).
5. A leaf could be created inside another child, or around one: `Local.Create` checks the path against
   the existing children first (v0-T200).
6. A plan in a project with no leaves skipped the readiness check of layers, because a nil list meant
   "not given": the list is never nil (v0-T201).
7. Acceptance checks inside a task shape bypassed the sandbox refusal, because `Prepare` looked only at
   the top-level nodes: it looks at all of them (v0-T196).
8. A rejection did not give the refusals after it their `returns` again (v0-T197).
9. A task's words were not in its session's prompt: the task block is added, bounded (v0-T195).
10. A service's image was never pulled, and `Up` failed on it: `Pull` fetches it by digest through the
    isolated auth, `Up` refuses one that is missing, and only `ygg sandbox build` reaches a registry
    (v0-T163, and v0-T202 for `ygg sandbox build`).

**Not run:** the real engine (v0-H12 does it for services and scratch folders), real model sessions
(v0-H13 does them), `reuse lint` (`uvx` is not installed on this machine; CI and each task's own gate run
it), and CI itself (the branches were not pushed while this plan was written). The scripted-agent
tests run the whole 5a path through the real `ygg` command with fake agents that write exactly what the
prompts ask for; they cannot show that a real model does.
