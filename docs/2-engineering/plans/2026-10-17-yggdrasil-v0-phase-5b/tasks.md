---
title: Yggdrasil v0, Phase 5b tasks (the web realms' content)
status: accepted
date: 2026-10-17
related: [../2026-10-12-yggdrasil-v0/plan.md, ../2026-10-17-yggdrasil-v0-phase-5a/tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../changes/2026-10-17-realm-leaf-naming/proposal.md, ../../changes/2026-10-17-realm-engine/proposal.md, ../../changes/2026-10-17-realm-content/proposal.md, ../../backlog.md]
style: spec
---

# Yggdrasil v0, Phase 5b: the web realms' content

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking. Tasks and steps marked **founder** are done by the founder,
> never by an agent.

**Goal:** the content half of the [plan](../2026-10-12-yggdrasil-v0/plan.md)'s Phase 5. The two web realms
exist and work: `midgard-react`, the lead realm, holds the graph of a web product, the planners' and the
reviewers' prompts, the web leaf's template and recipe, and a stack image that carries the check ladder's
tools; `helheim-go` holds the recipe of a Go API leaf, its template, its ladder and the services an API needs.
The ladder's rungs 1 to 6 are real (static, tests with the TDD check, contract, security, end to end, and the
three reviewers). A pointer move's acceptance checks run, with a sandbox on, over a snapshot of the whole
project. The `spec` gate reads the design-conformance review's verdict.

**Architecture:** a realm's stack is built from a folder of the realm (`devcontainer/`) by `ygg sandbox
build`, and the ladder's scripts are baked into the image where the agent cannot write. Gungnir learns the
schema of that (a stack as an image or a build context), of a service's command, of a scratch reviewer and of
the conformance verdict. Gleipnir builds the stack from pinned inputs only. Odin resolves each realm's stack,
hands the `spec` gate its verdict, exports the snapshot and runs the acceptance checks in it. Havamal vendors
Ponytail's review skill. The two realm repos carry packs, graphs, prompts, Containerfiles, scripts and
templates, each tested with the real tools where it matters.

**Tech stack:** Go 1.26 and the pins of Phase 5a for the factory's own code; for the realms, Go 1.26.9 and
Node 22 images, React 19, Vite, TypeScript 5.9, Tailwind 4, TanStack, Vitest, Playwright, Prism, sqlc,
golangci-lint, oasdiff, vacuum, govulncheck and osv-scanner, each at one exact version (the templates'
`go.mod` and `package.json`, and the stacks' Containerfiles).

**Spec:** [v0 engineering spec](../../specs/2026-10-11-yggdrasil-v0-spec.md) §3.3, §4.2, §4.5, §4.6, §5.1,
§6, §7.1, §9 and §13; and the accepted changes in `docs/2-engineering/changes/` where they override it
(`require-budget-caps`, `remote-creates-repos`, `benchmark-split`, `factory-issues`,
`project-is-its-own-tree`, `loop-escalation-and-spend`, `realm-leaf-naming` and `realm-engine`), plus the
change this plan adds, [realm-content](../../changes/2026-10-17-realm-content/proposal.md), which records
the places where the spec was silent or had to give way.

**Status:** accepted when the founder merges the pull request that adds this file.

**Code in this plan was run.** Every Go file, script, schema, prompt, template and test below was built and run
in a scratch workspace on 2026-10-17, one commit per task, with `go test -race` where the repo is Go. The ladder's
scripts ran with the real tools (`gofmt`, `golangci-lint`, `sqlc`, `vacuum`, `oasdiff`, `govulncheck`,
`osv-scanner`, `npm`, `eslint`, `tsc`, Vitest, Prism, Playwright and Chromium) on the templates and on the
code of the two-task smoke run below. The two stack images were built on a real engine (rootless Podman),
and the content smoke run (v0-H15) was run there too, with scripted agents; "Evidence" says what happened
and what was not run. Copy the code as written; if a step's expected result differs, stop and report it,
because the plan is wrong.

Code blocks are of two kinds. A new file is shown whole. A change to an existing file is shown as a
git patch (`diff`); apply it with `git apply` from the repo's folder, or edit by hand: lines that
start with `+` are added, lines with `-` removed. A lock file (`package-lock.json`, `go.sum`) is not in the plan:
copy `package-lock.json` from the reference workspace (the reviewed one, see the handover), and let `go mod tidy`
write `go.sum`.

## Decisions for this phase

Each line is **Decided 2026-10-17** when the founder merges this plan.

1. **Phase 5b is the realms' content, and 5c follows** (founder, 2026-10-17: Phase 5 is three plans). This plan builds
   `midgard-react` (the lead realm) and `helheim-go` and what the engine needs for them: 40 agent tasks in six
   repos (gungnir 5, gleipnir 6, havamal 1, helheim-go 7, midgard-react 10, odin 10), then v0-T244 (pointers, in
   `yggdrasil`) and two founder tasks, v0-H14 and v0-H15. Its exit criterion is Phase 5's, with scripted agents:
   the real realms build a one-feature brief end to end (v0-T241 in a test that needs no engine, v0-T242 with the files of the run; v0-H15 on a
   real engine, with the real check ladder), their packs load and their stacks build (v0-H14). The real smoke
   brief with real agents is 5c's. This plan is bigger than the 35 or so the split assumed; it falls into six pull
   requests by repo, in an order that lets four of them run beside each other.
2. **A realm's stack is a pinned image or a build context in the realm** (founder, 2026-10-17: option A, "with both
   forms in the schema"). The check ladder needs fifteen tools and its scripts must be out of the agent's reach,
   which an upstream image cannot give. `pack.yaml` says `sandbox.stack` (an image by digest) or `sandbox.build` (a
   folder, optionally with a `target` stage); `ygg sandbox build` builds the folder from bases pinned by digest and
   its own stages only, and tags the image with a hash of the context and the stage. The scripts live in the
   context and the Containerfile bakes them into `/opt/ygg/checks`, owned by root. Moving a realm to images
   published in a registry later is naming the image. This differs from spec §9.4, which has `checks/` beside
   `devcontainer/`; the change [realm-content](../../changes/2026-10-17-realm-content/proposal.md) records it.
3. **Two stages of one Containerfile are the two images of `midgard-react`:** `web`, the leaf's stack, and
   `acceptance`, which adds Go so the acceptance run can build the API beside the web app. The Go realm has one.
4. **A web leaf's end-to-end rung runs against a mock of the contract; the real API runs at the pointer** (founder,
   2026-10-17: "mock per task, real stack at the pointer"). In a task's loop Playwright runs against the built app
   with Prism, made from the leaf's copy of the API contract, behind it. This differs from spec §9.2, which has
   Odin run the API as a read-only service in the web leaf's sandbox: a leaf's sandbox holds that leaf only, and a
   task of the web leaf should not need an API to build.
5. **Acceptance checks run in a snapshot sandbox** (replaces Phase 3 decision 11). A pointer move's acceptance
   checks run, in a run with a sandbox, in a scratch sandbox over the committed files of the umbrella and of each
   leaf (the one being moved at the commit it moves to), with no git directory and none of a working copy's ignored
   files, on the lead realm's `sandbox.acceptance` stack, with the services of every leaf's realm. The acceptance
   run builds the API from the snapshot, starts it against Postgres, builds the web app and runs its Playwright
   specs against both. A realm with acceptance checks and no acceptance stack is refused before the run starts.
6. **The web leaf holds a copy of the API contract, and the API may add to it but not break it.**
   `contracts/api.openapi.yaml` in the web leaf is the contract as the web app uses it; the planner puts the contract
   text in the task, so the implementer copies it exactly and regenerates the types. The acceptance run reads the
   copy as the old contract and the API's file as the new one (`oasdiff breaking --fail-on ERR`), so the API's task
   can land before the web task that uses it.
7. **A service may name its command** (replaces the "image's own command" of Phase 5a decision 12), as an argument
   vector with no shell, no `$`, at most 16 arguments of at most 256 bytes. SeaweedFS does nothing without
   `server -s3`.
8. **The firewall answers the work container's DNS itself** (found on a real engine). The rules allowed the
   addresses the sidecar resolved at its start; names served from a large pool, such as Google's Go proxy and
   vulnerability databases, answer with another address after a few minutes, and the connection was refused. Every
   DNS query of a process that is neither root nor nobody is redirected to a dnsmasq in the sandbox's network
   namespace. It answers from the addresses the rules allow (the rules are swapped before the answers), asks the
   services' resolver about the services' names, and answers nothing else. It also closes the DNS channel for the
   work container (backlog B-025), and a process that runs as root in the work container could still bypass it:
   the container has no root process and no capability.
9. **The design-conformance review hands the `spec` gate a verdict** (spec §4.2, §7.1). A scratch reviewer
   (`reviews:`) finds the output of the agent it reviews as `reviewed/` and writes `out/conformance.json`; the
   gate (`deviation_from:`) reads it. A deviation stops the gate in every mode, with the amendment in the gate
   file. A verdict that cannot be read is asked for once more, with the reason, and then stops the run: it is never
   a pass (§4.6).
10. **The ladder's rungs.** Rung 1 static (format, vet or lint, types, build, docs), rung 2 the tests and the TDD
    check, rung 3 the contract, rung 4 security (`govulncheck` or `npm audit`, and OSV), rung 5 the end-to-end
    tests (a mock in the web loop; the API leaf's rung 5 is its integration tests against Postgres), rung 6 the
    three reviewers in the spec's order: spec compliance, simplicity, quality. The pack's `leaf.checks` list the
    cheap rungs first. Rung 7 and the two-tenant authorisation harness are 5c's; Vale prose rules wait (B-042).
11. **The TDD check** compares the commit the task started from (the leaf's `main`) with the branch: the test files
    a change adds or changes are put on a copy of that commit and run, and they must fail there (a test of code
    that is not there yet fails to compile, which counts). Code without a new or changed test is refused;
    generated files are not code that needs a test. Tests behind the `integration` tag and Playwright specs need a
    database or a browser, so a change that only has those passes with a note, and the reviewers look.
12. **Go 1.26.9 is the Go stack's toolchain** (the founder's waiver for CI's 1.26.9, extended). `govulncheck` on
    Go 1.26.4 reported standard-library vulnerabilities fixed in 1.26.6 and others fixed in 1.26.9 (in `net/http`,
    `net/textproto` and `crypto/tls`); the ones fixed in 1.26.9 apply to 1.26.7, the version the factory's own
    tests used, so rung 4 could never pass on it. The 1.26.9 image is nine days old, under the two weeks Phase 3
    asked for of every pin. The same check found two known vulnerabilities in `golang.org/x/text`, a dependency of
    the Postgres driver, so the template pins 0.42.0; with both changes `govulncheck` and `osv-scanner` find
    nothing in the template.
13. **Ponytail's `ponytail-review` is vendored** (founder, 2026-10-17: keep it) through Havamal at commit
    `16352ac2…` (release 5.3.2) of `DietrichGebert/ponytail`, MIT, and loaded by name by the plan's reuse review and
    by the simplicity reviewer. The simplicity reviewer maps the skill's groups to severities: must fix is a
    blocker, should fix major, nice to have minor. The skill's text is instructions an agent follows: the diff of
    v0-T216 is what you read.
14. **The prompts.** A planner prompt says where its documents go and in what shape, and a test checks the
    examples in it against the schemas Odin reads. The implementer of a task sees its leaf and its task, nothing
    else, so the plan prompt asks for self-contained tasks (the exact routes, fields and contract text). The roles
    the graph uses are `planner`, `implementer` and `reviewer`: the operator's `factory.yaml` defines them. No
    prompt mentions the benchmark (a test checks).
15. **The graph.** The stages of spec §4.2 in the nodes Phase 5a built, and for every task: the implementer's loop
    (three attempts, the ladder, three reviewers), the feature gate, the merge gate, the merge, the pointer gate
    and the pointer move with the acceptance run, a refusal of the last two going back to the implementer. There
    is no `pointer-contract` gate: it waits for the impact index (5c). The `initializer` agent that would
    customize each leaf's `AGENTS.md` after `init` is not built: the templates carry a short `AGENTS.md`, and the
    first task may change it (B-046).
16. **The templates.** Each leaf template builds and passes its own checks in a copy, carries a short `AGENTS.md`
    and an MIT licence, and pins every dependency to one exact version. TypeScript is 5.9.3 because
    `openapi-typescript` 7 asks for TypeScript 5 (B-045). The tests of a template need the module proxy or the npm
    registry; they skip, or fail with `YGG_REQUIRE_TEMPLATES` set.
17. **Evidence from a real engine.** Both stacks were built on rootless Podman, and the content smoke run was run
    there with scripted agents. It found a root-owned `/go/pkg` (the agent's user could not make a module cache),
    a leftover `vite preview` that answered for a later run (the e2e scripts now refuse a taken port and start the
    server themselves, not through `npx`), and the DNS problem of decision 8. "Evidence" says what is and is not
    proven. v0-H14 and v0-H15 are the founder's repeat of it on the merged code.
18. **Backlog.** B-041's M-6 (a scratch sandbox keyed by a name a leaf path could also be) now covers the
    snapshot's `snapshot/<node>` too. New items: B-042 (Vale), B-043 (the scripts both realms copy), B-044
    (unpinned packages in the images), B-045 (TypeScript 5.9), B-046 (no initializer agent), B-047 (the
    implementer cannot see the project's design documents). B-005, B-006, B-037 and B-039 are untouched.
19. **Documentation.** The architecture page of each repo says what it now does (v0-T209, v0-T215, v0-T223,
    v0-T233, v0-T243). The spec is not edited; the change `realm-content` records where it gave way and folds
    into `system/` with the others when v0 lands.
20. **Sizes count insertions** as git reports them, lock files excepted (`go.sum`, `package-lock.json`: the plan tool
    skips them, with a test, in the `ouroboric` pull request that comes with this plan). No task is over 400.
21. **Pull requests and pins.** Seven, in this order: `gungnir` (v0-T205 to v0-T209); then `gleipnir`
    (v0-T210 to v0-T215), `havamal` (v0-T216), `helheim-go` (v0-T217 to v0-T223) and `midgard-react` (v0-T224 to
    v0-T233), which do not depend on each other and can be open together, each pinning the merged gungnir; then
    `odin` (v0-T234 to v0-T243), after the four are merged and pinned, because v0-T241 runs the real realms;
    then `yggdrasil` (v0-T244). `ouroboric` gets one more, for the plan tools and the smoke script, opened with
    this plan's pull request.

## Global constraints

- **Local copies.** The component repos are submodules of `yggdrasil`, at
  `/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`, and `yggdrasil/go.work` builds them together
  (`midgard-react` and `helheim-go` are modules of it too). Each task works on a branch in the submodule
  it changes. The umbrella's pointers move once, in v0-T244.
- **GitHub.** Agents reach GitHub only as `ouroboric-pr-bot`, through
  `/home/brunogbv/brunogbv/ouroboric/ouroboric/scripts/as-bot.sh`. `as-bot.sh <repo> <command>` pushes
  and opens PRs; `as-bot.sh --read all <command>` reads. Every change lands through a PR the founder
  merges. Agents never merge and never push to `main`, and never hold GitHub Administration rights.
- **Commits.** Read `git status --short` first, and stage explicit paths, never `git add -A`. Commit
  messages end with `Co-Authored-By: Claude <model> <noreply@anthropic.com>`, naming the model that wrote
  the commit. Commits and PRs carry no session links. Every repo runs the `gitleaks` hook.
- **Go.** `go.mod` says `go 1.26`. Code is `gofmt`-clean and `go vet`-clean. Before a PR opens, the repo
  passes `GOWORK=off go test -race ./...` in its own folder, as CI runs it. This machine has Go 1.26.4;
  CI uses 1.26.9.
- **Shell and TypeScript.** Every script starts `#!/bin/bash` and `set -euo pipefail` and passes
  `shellcheck -s bash`. The templates pin every dependency to one exact version.
- **Pins to the siblings.** `gleipnir`, `odin`, `helheim-go` and `midgard-react` pin `gungnir`; `odin` pins
  `gleipnir` and `havamal`. Until a sibling's PR is merged, develop through `yggdrasil/go.work`; the pin is
  the last commit of a repo's branch.
- **Credentials.** Nothing in this phase needs a token. v0-H14 and v0-H15 use scripted agents. No agent reads,
  prints or stores `~/.config/ouroboric/factory.env`; a script that needs the file's shape gets an empty one.
- **The hidden suite.** No agent reads, lists or searches `ouroboric-dev/huldra` or its clone under
  `~/brunogbv/ouroboric-private/`. The realms' prompts never mention the benchmark (a test checks).
- **Licences.** `reuse lint` (`reuse==5.0.2`) passes in every repo a task touches. A template is MIT, as
  `REUSE.toml` says.
- **Deletions** (`rm`, `git branch -D`) are asked for first, one per command, after a read-only check.
- **Tests are hermetic,** with three exceptions that skip, never fail, when they cannot run: a template's
  build (the module proxy or the npm registry; set `YGG_REQUIRE_TEMPLATES` to fail instead of skipping), a
  test of an e2e script (it needs `python3`), and the real-realms run in `odin` (it needs `midgard-react` and
  `helheim-go` beside `odin`, as in the umbrella). A test never writes under the real `HOME` and every
  `odin` test package sets `XDG_STATE_HOME`.
- **Agent text is data.** A plan, a leaves file, a verdict and a document come from an agent: they are read
  exactly, bounded, and reached through no symlink.
- **No claim without the tool.** A script in a stack image is tried with the real tools it calls before it
  is described as working; a stand-in tool is only for the script's own logic.

## Review focus

1. **A check an agent can weaken or fake.** A script it can edit, a tool it can replace, a new test that passes
   on the parent, code that lands with no test. Expected: the ladder's scripts are baked into the image owned by
   root and cannot be written by the agent's user; the TDD check refuses code without a test and tests that pass
   before the code. Pinned by v0-T219 `TestTheStackImageIsMadeOfPinnedInputsOnly`, v0-T220
   `TestTDDWantsTheNewTestsToFailOnTheCommitTheTaskStartedFrom` and v0-T226 (the same test of the web leaf's
   script), v0-T229 `TestTheStackImagesAreMadeOfPinnedInputsOnly`; on a real engine, by v0-H14 and v0-H15.
2. **An input of a stack image that is not pinned.** A base by tag, a download without a hash, a package at a
   floating version, a `COPY --from` an image, an `ADD` of a URL. Expected: refused before the engine is called.
   Pinned by v0-T211 `TestBuildStackRefusesAContextItCouldNotBuildFromPinnedInputsOnly`, v0-T205
   `TestABuildContextIsRefusedWhenItCouldReachOutsideItself`, and the Containerfile tests of v0-T219 and v0-T229.
3. **A verdict or a gate that lets a deviation through.** A verdict that is prose, missing, half written or has
   an extra field; a spec that deviates in a mode that is meant to be automatic. Expected: asked for once more,
   then the run stops; a deviation stops the `spec` gate in every mode. Pinned by v0-T208
   `TestParseConformanceReadsAVerdictExactly`, v0-T237 `TestAVerdictNobodyCanReadIsAskedForOnceMoreAndThenStopsTheRun`
   and `TestADeviationStopsTheSpecGateInEveryModeWithTheAmendment`.
4. **A snapshot or a sandbox that carries more than it should.** A symlink, a `.git`, ignored build output, an
   uncommitted edit, the services of a realm that disagree with another's, a DNS answer that is not an address the
   rules allow. Expected: the snapshot holds committed regular files and nothing else; realms that disagree on a
   service cannot share a sandbox; the work container resolves the allowed hosts and the services and nothing
   else. Pinned by v0-T238 `TestExportRefusesWhatCouldLeadOutOfTheSnapshot`, v0-T239
   `TestRealmsThatDisagreeOnAServiceCannotShareASnapshotSandbox`, v0-T240 `TestWhatALeafIgnoresIsNotInTheSnapshot`
   and v0-T213 `TestEgressAnswersDNSItselfForTheListedHostsAndTheServicesAndNothingElse`; on a real engine, by
   v0-T214's `TestSandboxAnswersDNSForTheListedHostsAndTheServicesOnly`.
5. **A server of an earlier run mistaken for this run's, or left up.** A port already taken, a server that
   outlives its script, a mock that never comes up. Expected: a taken port is refused before anything starts,
   every server a script started is stopped, success or failure, and a server that does not answer ends the run
   with its log. Pinned by v0-T228 `TestE2EStartsAMockAndTheAppRunsPlaywrightAndStopsThem` and
   `TestAcceptanceChecksTheAPIKeepsWhatTheWebCopyPromisesThenRunsBothAgainstEachOther`.
6. **A contract the two leaves read differently.** A web copy that lags, one the API breaks, types that are not
   what the copy says. Expected: the API may add; it may not break what the copy promises, and a copy whose
   generated types are out of date fails rung 3. Pinned by v0-T227
   `TestContractChecksTheTypesAreWhatTheContractSaysAndListsChanges` and the acceptance test above.

## Order

| Task | Repo | Size | Depends on |
|---|---|---|---|
| v0-T205 a realm's stack is a pinned image or a build context in the realm | `gungnir` | M | Phase 5a |
| v0-T206 a service may name its command, for an image that does nothing without one | `gungnir` | S | v0-T205 |
| v0-T207 a scratch reviewer reads the output of the agent it reviews, and the spec gate reads its verdict | `gungnir` | S | v0-T206 |
| v0-T208 the design-conformance verdict is read exactly, and the ledger records it | `gungnir` | M | v0-T207 |
| v0-T209 Gungnir's documentation | `gungnir` | S | v0-T208 |
| v0-T210 a service starts with the command the pack gives it | `gleipnir` | S | v0-T209 |
| v0-T211 ygg sandbox build can build a realm's stack from its context, from pinned bases only | `gleipnir` | M | v0-T210 |
| v0-T212 building the layers on a stack built from a realm's context needs no pull | `gleipnir` | S | v0-T211 |
| v0-T213 the firewall answers the work container's DNS itself, from the addresses it allows | `gleipnir` | M | v0-T212 |
| v0-T214 integration tests of a built stack, a service's command and the firewall's DNS, behind the sandbox tag | `gleipnir` | M | v0-T213 |
| v0-T215 Gleipnir's documentation | `gleipnir` | S | v0-T214 |
| v0-T216 vendor Ponytail's ponytail-review at a pinned commit, for the simplicity reviewer | `havamal` | M | Phase 5a |
| v0-T217 the Go API template: a server with a health route, its contract, its tests, and the rules for working in it | `helheim-go` | M | Phase 5a |
| v0-T218 the API template gets a database: migrations, sqlc and a store, with an integration test | `helheim-go` | M | v0-T217 |
| v0-T219 the Go stack image, and the static and unit rungs of the check ladder, tested on small leaves | `helheim-go` | M | v0-T218 |
| v0-T220 the TDD check: the tests a change adds must fail on the commit it started from | `helheim-go` | M | v0-T219 |
| v0-T221 the contract, security and integration rungs for a Go leaf, tried with the real tools on the template | `helheim-go` | M | v0-T220 |
| v0-T222 the helheim-go pack: the recipe of a Go API leaf, its ladder and its services | `helheim-go` | M | v0-T221 |
| v0-T223 helheim-go's documentation | `helheim-go` | S | v0-T222 |
| v0-T224 the React web template: Vite, TypeScript, Tailwind, TanStack, a typed API client and a first tested component | `midgard-react` | M | Phase 5a |
| v0-T225 the web template becomes a repo of the factory: its rules, licence, editor config, e2e setup, and a test that builds it | `midgard-react` | M | v0-T224 |
| v0-T226 the static and unit rungs for a web leaf, and the TDD check, tried with the real tools on the template | `midgard-react` | M | v0-T225 |
| v0-T227 the contract and security rungs for a web leaf | `midgard-react` | S | v0-T226 |
| v0-T228 the end-to-end rung with a mock API, and the acceptance run on a snapshot of the project | `midgard-react` | M | v0-T227 |
| v0-T229 the web stack images: Node with the ladder's tools and Chromium, and the acceptance stage with Go, all from pinned inputs | `midgard-react` | M | v0-T228 |
| v0-T230 the planning prompts: design, spec, the design-conformance review, plan and reuse review | `midgard-react` | M | v0-T229 |
| v0-T231 the build prompts: the web implementer and the three reviewers | `midgard-react` | M | v0-T230 |
| v0-T232 the midgard-react pack and graph: the stages of a web product, the task loop with three reviewers, and the acceptance run | `midgard-react` | M | v0-T231 |
| v0-T233 midgard-react's documentation | `midgard-react` | S | v0-T232 |
| v0-T234 a leaf starts on the stack of its realm: the pinned image, or the tag of the build | `odin` | M | v0-T216 |
| v0-T235 ygg sandbox build builds a realm's stacks from their contexts, then the layers on them | `odin` | M | v0-T234 |
| v0-T236 a scratch reviewer gets a copy of the output of the agent it reviews | `odin` | S | v0-T234 |
| v0-T237 the spec gate reads the design-conformance verdict, and a deviation stops it in every mode | `odin` | M | v0-T236 |
| v0-T238 a snapshot of the project's committed files, with no git dir, for the checks that run over several leaves | `odin` | M | v0-T234 |
| v0-T239 a sandbox that holds a snapshot of the project, for acceptance checks, with the services of every leaf's realm | `odin` | M | v0-T238 |
| v0-T240 a pointer move's acceptance checks run in the snapshot sandbox when the run has a sandbox | `odin` | M | v0-T239 |
| v0-T241 the real realms build a product from a brief with scripted agents, through Odin's own code | `odin` | M | v0-T240, and the PRs of helheim-go and midgard-react merged |
| v0-T242 the scripted answers, brief and example config of the content smoke run on a real engine | `odin` | M | v0-T241 |
| v0-T243 Odin's documentation | `odin` | S | v0-T242 |
| v0-T244 pointers and the exit check | `yggdrasil` | S | all above, merged |
| v0-H14 (founder) the stacks build, and the engine tests pass | the founder's machine | S | v0-T214 merged; Phase 3's v0-H07 |
| v0-H15 (founder) the content smoke run on a real engine, with the real check ladder | the founder's machine | S | v0-T242 and v0-H14 done |

Gungnir's five tasks go up as one pull request, one commit per task; gleipnir's six, havamal's one,
helheim-go's seven and midgard-react's ten as one each, opened once gungnir's is merged and pinned (they do
not depend on each other); odin's nine as one, opened once those four are merged and pinned. Inside a repo
the tasks stack on one branch.

## Not in Phase 5b

The check ladder's rung 7 (the final acceptance by the hidden suite) and the isolated grader with `score.json`;
the two-tenant authorisation harness (`TestCrossTenant...` for every route that takes a resource id); the routing
indexes and their bench, the impact index and with it the `pointer-contract` gate; the dependency policy's
canary-first bumps (all 5c); the real smoke brief with real agents (5c's exit criterion). Vale prose rules in
the docs rung (B-042); one home for the scripts both realms copy (B-043); pinned apt packages in the images
(B-044); an initializer agent that customizes each leaf's `AGENTS.md` (B-046); a way for an implementer to read
the project's design documents (B-047: a task states what it needs); a Prism mock that checks requests against
the contract beyond what Prism does; the `github` remote and fetching a realm by tag (iteration 2); a second
flavor of Midgard or Helheim (`midgard-vue`, `helheim-py`); deploying anything (`deploy-prod` is a hard approval
point and nothing in v0 deploys). The backlog items this phase does not touch (decision 18).

## How each task lands

Every agent task ends the same way. Run the commands in the repo's folder,
`/home/brunogbv/brunogbv/ouroboric/yggdrasil/<repo>`:

```bash
gofmt -l .                        # prints nothing
go vet ./...
GOWORK=off go test -race ./...    # what CI runs
uvx -q --from 'reuse==5.0.2' reuse lint -q
git status --short                # then stage the task's files by path
git commit -m "<what changed> (v0-T2xx)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

`havamal` has no race-sensitive code; its drift check is `go run ./cmd/havamal check .`. A shell script of a
realm also passes `shellcheck -s bash`. When the repo's last task is committed, push and open its pull request:

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

---

### Task v0-T205: a realm's stack is a pinned image or a build context in the realm

Gungnir's first task. Branch `realms/content` from `main` in `gungnir`, before step 1. A realm's tools must be in its sandbox's image, and its check scripts out of the agent's reach, which an upstream image pinned by digest can't give (change `realm-content`). The pack says the stack either way: an image, as before, or a folder of the realm with a Containerfile, which `ygg sandbox build` builds. Both forms are in the schema, so a realm can move to images published somewhere later by naming the image.

**Files (in `gungnir`):**
- Create: `schema/pack_stack_test.go`, `schema/stack.go`, `stack.go`, `stack_test.go`
- Modify: `sandbox.go`, `schema/pack.go`, `schema/pack.schema.json`

**Interfaces:**
- Produces: `schema.PackSandbox.Build` (a folder of the realm), `Target` (a stage of its Containerfile; the last when empty) and `Acceptance *PackStack{Stack, Build, Target}` (the stack of the sandbox that holds a snapshot of the whole project). Exactly one of `stack` and `build` is given, for the stack and for the acceptance stack; a target needs a build.
- Produces: `(*Pack).StackRef(dir string) (string, error)` and `AcceptanceRef`: the pinned image, or the local tag `localhost/ygg-stack-<realm>[-acceptance]:<12 hex>` of the build. `schema.StackHash(dir, target)` is the hash in the tag: of every file of the context (path, executable bit, bytes) and of the stage. `schema.HashContext(dir)` refuses a context with no Containerfile at its top, any file that is not a regular file (a symlink could lead the build outside the realm), more than `MaxContextFiles` (500) files or `MaxContextBytes` (64 MiB).
- Produces: `gungnir.ValidStack(ref)` (an image pinned by digest, or a local tag as above) and `gungnir.LocalStack(name, hash)`. `SandboxSpec.Validate` accepts either form of `Stack`.

**Acceptance criteria:**
- [ ] A pack with `sandbox.build` loads, and `StackRef` returns the local tag; a pack with `sandbox.stack` returns the image; both forms, or neither, are refused.
- [ ] The tag changes with a file's bytes, with a file made executable, with an added file and with the target; it does not change when nothing does.
- [ ] A context with no Containerfile, a symlink, too many files or too many bytes, and a `build` that climbs out of the realm are refused; so is a `target` on an image, or a target that is not a lower-case stage name.
- [ ] An acceptance stack is an image or a build too, and is tagged apart from the leaf's stack.

**Named test:** `go test ./schema . -run 'TestPackSandboxTakesABuildContextOrAPinnedImage|TestAStackTagFollowsTheContext|TestABuildContextIsRefusedWhenItCouldReachOutsideItself|TestAnAcceptanceStackIsAnImageOrABuildToo|TestATargetNamesAStageOfTheContextAndIsPartOfTheTag|TestValidStack'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (396). **Depends on:** Phase 5a.

- [ ] **Step 1:** write the tests.

Write `schema/pack_stack_test.go`:

```go
package schema

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"testing"
)

// writeContext writes files (path: body) under dir/devcontainer, with a Containerfile unless one is given.
func writeContext(t *testing.T, dir string, files map[string]string) {
	t.Helper()
	if _, ok := files["Containerfile"]; !ok {
		files["Containerfile"] = "FROM " + digest + "\n"
	}
	for name, body := range files {
		p := filepath.Join(dir, "devcontainer", name)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

var localStack = regexp.MustCompile(`^localhost/ygg-stack-toy:[0-9a-f]{12}$`)

func TestPackSandboxTakesABuildContextOrAPinnedImage(t *testing.T) {
	dir := writePack(t, "sandbox:\n  build: devcontainer\n  egress: [proxy.golang.org]\n")
	writeContext(t, dir, map[string]string{"checks/go-unit.sh": "#!/bin/sh\n"})
	p, err := LoadPack(dir)
	if err != nil || p.Sandbox == nil || p.Sandbox.Build != "devcontainer" || p.Sandbox.Stack != "" {
		t.Fatalf("LoadPack(build form) = %+v, %v", p, err)
	}
	ref, err := p.StackRef(dir)
	if err != nil || !localStack.MatchString(ref) {
		t.Fatalf("StackRef(build form) = %q, %v; want a local tag", ref, err)
	}
	pinned, err := LoadPack(writePack(t, "sandbox:\n  stack: "+digest+"\n"))
	if err != nil {
		t.Fatal(err)
	}
	if ref, err := pinned.StackRef(t.TempDir()); err != nil || ref != digest {
		t.Errorf("StackRef(digest form) = %q, %v; want %q", ref, err, digest)
	}
	for name, sb := range map[string]string{
		"both forms": "sandbox:\n  stack: " + digest + "\n  build: devcontainer\n",
		"neither":    "sandbox:\n  egress: [proxy.golang.org]\n",
	} {
		if _, err := LoadPack(writePack(t, sb)); err == nil {
			t.Errorf("%s: LoadPack() = nil, want an error", name)
		}
	}
}

func TestAStackTagFollowsTheContext(t *testing.T) {
	refOf := func(files map[string]string, mode os.FileMode) string {
		dir := writePack(t, "sandbox:\n  build: devcontainer\n")
		writeContext(t, dir, files)
		if mode != 0 {
			if err := os.Chmod(filepath.Join(dir, "devcontainer", "run.sh"), mode); err != nil {
				t.Fatal(err)
			}
		}
		p, err := LoadPack(dir)
		if err != nil {
			t.Fatal(err)
		}
		ref, err := p.StackRef(dir)
		if err != nil {
			t.Fatal(err)
		}
		return ref
	}
	base := refOf(map[string]string{"run.sh": "echo a\n"}, 0)
	if again := refOf(map[string]string{"run.sh": "echo a\n"}, 0); again != base {
		t.Errorf("the same context gave %q and %q", base, again)
	}
	if other := refOf(map[string]string{"run.sh": "echo b\n"}, 0); other == base {
		t.Error("a changed file gave the same tag")
	}
	if other := refOf(map[string]string{"run.sh": "echo a\n"}, 0o755); other == base {
		t.Error("a file made executable gave the same tag")
	}
	if other := refOf(map[string]string{"run.sh": "echo a\n", "more": ""}, 0); other == base {
		t.Error("an added file gave the same tag")
	}
}

func TestABuildContextIsRefusedWhenItCouldReachOutsideItself(t *testing.T) {
	fill := func(t *testing.T, dir string, n, size int) {
		for i := 0; i <= n; i++ {
			if err := os.WriteFile(filepath.Join(dir, "devcontainer", fmt.Sprintf("f%d", i)), make([]byte, size), 0o644); err != nil {
				t.Fatal(err)
			}
		}
	}
	cases := map[string]func(t *testing.T, dir string){
		"no Containerfile": func(t *testing.T, dir string) {
			if err := os.Remove(filepath.Join(dir, "devcontainer", "Containerfile")); err != nil {
				t.Fatal(err)
			}
		},
		"a symlink in the context": func(t *testing.T, dir string) {
			if err := os.Symlink("/etc/passwd", filepath.Join(dir, "devcontainer", "passwd")); err != nil {
				t.Fatal(err)
			}
		},
		"too many files":                func(t *testing.T, dir string) { fill(t, dir, MaxContextFiles, 0) },
		"a context bigger than allowed": func(t *testing.T, dir string) { fill(t, dir, MaxContextBytes>>20, 1<<20) },
	}
	for name, mutate := range cases {
		dir := writePack(t, "sandbox:\n  build: devcontainer\n")
		writeContext(t, dir, map[string]string{})
		mutate(t, dir)
		if _, err := LoadPack(dir); err == nil {
			t.Errorf("%s: LoadPack() = nil, want an error", name)
		}
	}
	out := t.TempDir() // a valid context beside the realm: only its place is wrong
	writeContext(t, out, map[string]string{})
	for _, build := range []string{"../" + filepath.Base(out) + "/devcontainer", "/etc", "."} {
		dir := writePack(t, "sandbox:\n  build: "+build+"\n")
		if _, err := LoadPack(dir); err == nil {
			t.Errorf("build %q: LoadPack() = nil, want an error", build)
		}
	}
}

func TestAnAcceptanceStackIsAnImageOrABuildToo(t *testing.T) {
	dir := writePack(t, "sandbox:\n  build: devcontainer\n  acceptance:\n    build: devcontainer\n    target: acceptance\n")
	writeContext(t, dir, map[string]string{})
	p, err := LoadPack(dir)
	if err != nil {
		t.Fatal(err)
	}
	ref, err := p.AcceptanceRef(dir)
	lead, _ := p.StackRef(dir)
	if err != nil || ref == lead || !regexp.MustCompile(`^localhost/ygg-stack-toy-acceptance:[0-9a-f]{12}$`).MatchString(ref) {
		t.Errorf("AcceptanceRef() = %q, %v; the lead stack is %q", ref, err, lead)
	}
	plain, err := LoadPack(writePack(t, "sandbox:\n  stack: "+digest+"\n"))
	if err != nil {
		t.Fatal(err)
	}
	if ref, err := plain.AcceptanceRef(t.TempDir()); err != nil || ref != "" {
		t.Errorf("AcceptanceRef() with none = %q, %v; want empty", ref, err)
	}
}

func TestATargetNamesAStageOfTheContextAndIsPartOfTheTag(t *testing.T) {
	refs := map[string]string{}
	for _, target := range []string{"", "web", "acceptance"} {
		sb := "sandbox:\n  build: devcontainer\n"
		if target != "" {
			sb += "  target: " + target + "\n"
		}
		dir := writePack(t, sb)
		writeContext(t, dir, map[string]string{"checks/go-unit.sh": "#!/bin/sh\n"})
		p, err := LoadPack(dir)
		if err != nil {
			t.Fatalf("target %q: %v", target, err)
		}
		ref, err := p.StackRef(dir)
		if err != nil {
			t.Fatal(err)
		}
		refs[target] = ref
	}
	if refs[""] == refs["web"] || refs["web"] == refs["acceptance"] || refs[""] == refs["acceptance"] {
		t.Errorf("two stages of one context share a tag: %v", refs)
	}
	for name, sb := range map[string]string{
		"a target with an image":              "sandbox:\n  stack: " + digest + "\n  target: web\n",
		"an acceptance target with an image":  "sandbox:\n  build: devcontainer\n  acceptance:\n    stack: " + digest + "\n    target: web\n",
		"a target that is not a stage name":   "sandbox:\n  build: devcontainer\n  target: \"Web Stage\"\n",
		"an acceptance stack of neither form": "sandbox:\n  stack: " + digest + "\n  acceptance: {}\n",
	} {
		d := writePack(t, sb)
		writeContext(t, d, map[string]string{})
		if _, err := LoadPack(d); err == nil {
			t.Errorf("%s: LoadPack() = nil, want an error", name)
		}
	}
}
```

Write `stack_test.go`:

```go
package gungnir

import "testing"

func TestValidStack(t *testing.T) {
	const pinned = "docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514"
	for ref, want := range map[string]bool{
		pinned: true,
		"localhost/ygg-stack-midgard-react:0123456789ab":            true,
		"localhost/ygg-stack-midgard-react-acceptance:0123456789ab": true,
		"localhost/ygg-stack-x:latest":                              false,
		"localhost/ygg-stack-X:0123456789ab":                        false,
		"localhost/other:0123456789ab":                              false,
		"docker.io/library/golang:1.26.7":                           false,
		"":                                                          false,
	} {
		if got := ValidStack(ref); got != want {
			t.Errorf("ValidStack(%q) = %v, want %v", ref, got, want)
		}
	}
	spec := SandboxSpec{Run: "r1", Name: "repos/app", Parent: "/p", Leaf: "/p/repos/app", GitDir: "/p/.git/modules/app", Stack: "localhost/ygg-stack-midgard-react:0123456789ab"}
	if err := spec.Validate(); err != nil {
		t.Errorf("a spec with a local stack: %v", err)
	}
	spec.Stack = "localhost/ygg-stack-midgard-react:latest"
	if err := spec.Validate(); err == nil {
		t.Error("a spec with an unpinned local stack was accepted")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./stack_test.go:17:13: undefined: ValidStack
FAIL	github.com/ouroboric-dev/gungnir [build failed]
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
```

- [ ] **Step 3:** write the code.

Apply to `sandbox.go`:

```diff
diff --git a/sandbox.go b/sandbox.go
index 17ef6bf..a40cbc0 100644
--- a/sandbox.go
+++ b/sandbox.go
@@ -31,8 +31,8 @@ type SandboxSpec struct {
 	Leaf   string   // the leaf's working copy: mounted read-write
 	GitDir string   // the leaf's git dir, inside Parent/.git/modules: mounted read-only; empty for a scratch folder
 	Egress []string // host names the firewall opens on port 443, besides DNS
-	// Stack is the image of the stack layer of the realm that provides this leaf, pinned by digest.
-	// Empty means the driver's own images. A run with several realms starts leaves with different
+	// Stack is the image of the stack layer of the realm that provides this leaf: pinned by digest, or the
+	// local tag of an image built from the realm's build context (ValidStack). Empty means the driver's own images. A run with several realms starts leaves with different
 	// stacks.
 	Stack string
 	// Services are the containers the leaf's sandbox starts beside the work container, such as a
@@ -110,8 +110,8 @@ func (s SandboxSpec) Validate() error {
 			errs = append(errs, fmt.Errorf("egress %q is not a plain host name (no scheme, port, wildcard or address)", h))
 		}
 	}
-	if s.Stack != "" && !ValidImage(s.Stack) {
-		errs = append(errs, fmt.Errorf("stack %q is not an image pinned by digest", s.Stack))
+	if s.Stack != "" && !ValidStack(s.Stack) {
+		errs = append(errs, fmt.Errorf("stack %q is neither an image pinned by digest nor the tag of a built stack", s.Stack))
 	}
 	return errors.Join(append(errs, ValidateServices(s.Services))...)
 }
```

Apply to `schema/pack.go`:

```diff
diff --git a/schema/pack.go b/schema/pack.go
index e246024..fa5f087 100644
--- a/schema/pack.go
+++ b/schema/pack.go
@@ -54,10 +54,16 @@ func (p *Pack) ServiceList() []gungnir.Service {
 	return out
 }
 
-// PackSandbox is what a realm adds to its leaves' sandboxes.
+// PackSandbox is what a realm adds to its leaves' sandboxes: its stack layer, in one of two forms (a
+// digest-pinned image, or a build context in the realm), and the hosts its commands reach.
 type PackSandbox struct {
 	Stack  string   `yaml:"stack"`  // the stack layer's image, pinned by digest
+	Build  string   `yaml:"build"`  // or the folder of the realm that holds the stack's Containerfile and the check scripts it bakes in
+	Target string   `yaml:"target"` // with build: the stage of the Containerfile this stack is; empty is its last stage
 	Egress []string `yaml:"egress"` // host names, such as package registries, opened on port 443 beside the model APIs
+	// Acceptance is the stack of the sandbox that holds a snapshot of the whole project, where a pointer
+	// move's acceptance checks run: a lead realm's, in either form. It is empty for a realm that has none.
+	Acceptance *PackStack `yaml:"acceptance"`
 }
 
 // PackLeaf is a leaf the realm creates when a project lacks it (spec §4.1).
@@ -132,6 +138,20 @@ func LoadPack(dir string) (*Pack, error) {
 		return nil, err
 	}
 	if p.Sandbox != nil {
+		for _, st := range []PackStack{{Stack: p.Sandbox.Stack, Build: p.Sandbox.Build, Target: p.Sandbox.Target}, ptrOr(p.Sandbox.Acceptance)} {
+			if st.Build != "" && !filepath.IsLocal(st.Build) {
+				return nil, fmt.Errorf("%s: sandbox build %q must be a folder inside the realm", file, st.Build)
+			}
+			if st.Target != "" && st.Build == "" {
+				return nil, fmt.Errorf("%s: sandbox target %q needs a build context; an image has no stages", file, st.Target)
+			}
+		}
+		if _, err := p.StackRef(dir); err != nil {
+			return nil, fmt.Errorf("%s: sandbox: %w", file, err)
+		}
+		if _, err := p.AcceptanceRef(dir); err != nil {
+			return nil, fmt.Errorf("%s: sandbox acceptance: %w", file, err)
+		}
 		for _, h := range p.Sandbox.Egress {
 			if !gungnir.ValidHost(h) {
 				return nil, fmt.Errorf("%s: sandbox.egress %q is not a plain host name (no scheme, port, wildcard or address)", file, h)
@@ -155,3 +175,10 @@ func LoadPack(dir string) (*Pack, error) {
 	}
 	return &p, nil
 }
+
+func ptrOr(s *PackStack) PackStack {
+	if s == nil {
+		return PackStack{}
+	}
+	return *s
+}
```

Apply to `schema/pack.schema.json`:

```diff
diff --git a/schema/pack.schema.json b/schema/pack.schema.json
index c9a32cc..8441c34 100644
--- a/schema/pack.schema.json
+++ b/schema/pack.schema.json
@@ -6,6 +6,9 @@
   "type": "object",
   "additionalProperties": false,
   "required": ["name", "version"],
+  "$defs": {
+    "digestImage": { "type": "string", "pattern": "^[a-z0-9][a-z0-9./_-]*(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$" }
+  },
   "properties": {
     "name": { "type": "string", "pattern": "^[a-z][a-z0-9-]*$" },
     "version": { "type": "string", "pattern": "^[0-9]+\\.[0-9]+\\.[0-9]+$" },
@@ -31,10 +34,23 @@
     "sandbox": {
       "type": "object",
       "additionalProperties": false,
-      "required": ["stack"],
+      "oneOf": [{ "required": ["stack"] }, { "required": ["build"] }],
       "properties": {
-        "stack": { "type": "string", "pattern": "^[a-z0-9][a-z0-9./_-]*(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$", "description": "the stack layer's image, pinned by digest" },
-        "egress": { "type": "array", "items": { "type": "string", "minLength": 1 } }
+        "stack": { "$ref": "#/$defs/digestImage", "description": "the stack layer's image, pinned by digest" },
+        "build": { "type": "string", "minLength": 1, "description": "or a folder of the realm: the build context of the stack, with a Containerfile" },
+        "target": { "type": "string", "pattern": "^[a-z][a-z0-9_-]*$", "description": "with build: the stage of the Containerfile this stack is; the last stage when unset" },
+        "egress": { "type": "array", "items": { "type": "string", "minLength": 1 } },
+        "acceptance": {
+          "type": "object",
+          "additionalProperties": false,
+          "oneOf": [{ "required": ["stack"] }, { "required": ["build"] }],
+          "description": "the stack of the sandbox that holds a snapshot of the whole project, for a pointer move's acceptance checks",
+          "properties": {
+            "stack": { "$ref": "#/$defs/digestImage" },
+            "build": { "type": "string", "minLength": 1 },
+            "target": { "type": "string", "pattern": "^[a-z][a-z0-9_-]*$" }
+          }
+        }
       }
     },
     "leaf": {
```

Write `schema/stack.go`:

```go
package schema

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/ouroboric-dev/gungnir"
)

// A build context is read whole into a hash and into an image, so it is bounded.
const (
	MaxContextFiles = 500
	MaxContextBytes = 64 << 20
)

// PackStack is the stack of a sandbox in one of its two forms: an image pinned by digest, or a build
// context in the realm, a folder with a Containerfile that `ygg sandbox build` builds (change realm-content).
type PackStack struct {
	Stack  string `yaml:"stack"`  // an image pinned by digest
	Build  string `yaml:"build"`  // a folder of the realm: the build context, with a Containerfile at its top
	Target string `yaml:"target"` // with build: the stage of the Containerfile to build; empty is its last stage
}

// StackRef returns the image leaves of this realm start on: the pinned image, or the local tag that a
// build of the realm's context gets. dir is the realm's folder. It is "" for a pack with no sandbox.
func (p *Pack) StackRef(dir string) (string, error) {
	if p.Sandbox == nil {
		return "", nil
	}
	return stackRef(p.Name, PackStack{Stack: p.Sandbox.Stack, Build: p.Sandbox.Build, Target: p.Sandbox.Target}, dir)
}

// AcceptanceRef is StackRef for the stack that acceptance checks run on, in a sandbox that holds a
// snapshot of the whole project. It is "" when the pack names none.
func (p *Pack) AcceptanceRef(dir string) (string, error) {
	if p.Sandbox == nil || p.Sandbox.Acceptance == nil {
		return "", nil
	}
	return stackRef(p.Name+"-acceptance", *p.Sandbox.Acceptance, dir)
}

func stackRef(name string, s PackStack, dir string) (string, error) {
	if s.Build == "" {
		return s.Stack, nil
	}
	h, err := StackHash(filepath.Join(dir, s.Build), s.Target)
	if err != nil {
		return "", err
	}
	return gungnir.LocalStack(name, h), nil
}

// StackHash is the hash in the tag of a stack built from the context at dir up to target: the context's
// hash (HashContext) and the stage built, so two stages of one Containerfile are two images.
func StackHash(dir, target string) (string, error) {
	h, err := HashContext(dir)
	if err != nil {
		return "", err
	}
	if target == "" {
		return h, nil
	}
	sum := sha256.Sum256([]byte(h + "\x00" + target))
	return hex.EncodeToString(sum[:])[:12], nil
}

// HashContext returns the first 12 hex digits of a hash of every file of the build context at dir: their
// names, whether each is executable, and their contents. It refuses a context without a Containerfile at
// its top, one with a symlink or any file that is not a regular file, and one over the limits.
func HashContext(dir string) (string, error) {
	if st, err := os.Lstat(dir); err != nil || !st.IsDir() {
		return "", fmt.Errorf("the build context %s must be a folder of the realm", dir)
	}
	if st, err := os.Lstat(filepath.Join(dir, "Containerfile")); err != nil || !st.Mode().IsRegular() {
		return "", fmt.Errorf("the build context %s has no Containerfile (it must be a regular file)", dir)
	}
	h := sha256.New()
	files, total := 0, int64(0)
	err := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		rel, _ := filepath.Rel(dir, path)
		st, err := d.Info()
		if err != nil {
			return err
		}
		if !st.Mode().IsRegular() {
			return fmt.Errorf("the build context holds %s, which is not a regular file; a symlink could lead the build outside the realm", rel)
		}
		files++
		total += st.Size()
		if files > MaxContextFiles || total > MaxContextBytes {
			return fmt.Errorf("the build context is over its limits (%d files, %d MiB)", MaxContextFiles, MaxContextBytes>>20)
		}
		f, err := os.Open(path)
		if err != nil {
			return err
		}
		defer f.Close()
		fmt.Fprintf(h, "%s\x00%v\x00%d\x00", filepath.ToSlash(rel), st.Mode()&0o111 != 0, st.Size())
		_, err = io.Copy(h, f)
		return err
	})
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil))[:12], nil
}
```

Write `stack.go`:

```go
package gungnir

import "regexp"

// localStack is the tag Odin gives the image it builds from a realm's build context: the realm's name and
// a hash of every file of the context, so a changed context is a new image and never a changed one.
var localStack = regexp.MustCompile(`^localhost/ygg-stack-[a-z][a-z0-9-]*:[0-9a-f]{12}$`)

// ValidStack reports whether ref names a stack a sandbox may start on: an image pinned by digest, or the
// local tag of an image built from a realm's build context.
func ValidStack(ref string) bool { return ValidImage(ref) || localStack.MatchString(ref) }

// LocalStack returns the tag of the image built from a context whose hash is hash, for the realm name
// (with "-acceptance" added for a realm's acceptance stack).
func LocalStack(name, hash string) string { return "localhost/ygg-stack-" + name + ":" + hash }
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T206: a service may name its command, for an image that does nothing without one

SeaweedFS, which the Go realm's API needs for object storage, does nothing when it starts without an argument. Phase 5a said a service runs the image's own command; a service may now name its own, as an argument vector (no shell).

**Files (in `gungnir`):**
- Create: `sandbox_command_test.go`, `schema/pack_command_test.go`
- Modify: `sandbox.go`, `schema/pack.go`, `schema/pack.schema.json`

**Interfaces:**
- Produces: `gungnir.Service.Command []string`, `MaxServiceCommand` (16) and `MaxServiceArg` (256); `schema.PackService.Command` and `(*Pack).ServiceList()` carries it.
- `ValidateServices` refuses an empty argument, one over 256 bytes, one with a NUL or a line break, one with a `$` (compose would expand it from the operator's environment), and more than 16 arguments; its message never echoes the argument.

**Acceptance criteria:**
- [ ] A service with a command validates; each refusal above is a test case, and the pack's schema refuses an empty command or an empty argument.
- [ ] The pack's command reaches `ServiceList()`.

**Named test:** `go test . ./schema -run 'TestAServiceMayNameItsCommandAsAnArgumentVector|TestAPackServiceCarriesItsCommandToTheSandbox'` in `gungnir`. **Layer:** `gungnir`. **Size:** S (93). **Depends on:** v0-T205.

- [ ] **Step 1:** write the tests.

Write `sandbox_command_test.go`:

```go
package gungnir

import (
	"strings"
	"testing"
)

func TestAServiceMayNameItsCommandAsAnArgumentVector(t *testing.T) {
	ok := Service{Name: "seaweedfs", Image: pg, Ports: []int{8333}, Command: []string{"server", "-s3", "-dir=/data"}}
	if err := ValidateServices([]Service{ok}); err != nil {
		t.Fatalf("ValidateServices() = %v", err)
	}
	long := make([]string, MaxServiceCommand+1)
	for i := range long {
		long[i] = "x"
	}
	bad := map[string][]string{
		"an empty argument":          {"server", ""},
		"an argument with a dollar":  {"server", "-dir=$HOME"},
		"an argument with a NUL":     {"server\x00x"},
		"an argument with a newline": {"server\n-s3"},
		"an argument too long":       {strings.Repeat("a", MaxServiceArg+1)},
		"too many arguments":         long,
	}
	for name, cmd := range bad {
		s := ok
		s.Command = cmd
		err := ValidateServices([]Service{s})
		if err == nil {
			t.Errorf("%s: ValidateServices() = nil, want an error", name)
		} else if strings.Contains(err.Error(), "$HOME") {
			t.Errorf("%s: the error echoes the argument: %v", name, err)
		}
	}
}
```

Write `schema/pack_command_test.go`:

```go
package schema

import (
	"slices"
	"strings"
	"testing"
)

func TestAPackServiceCarriesItsCommandToTheSandbox(t *testing.T) {
	pack := strings.Replace(recipe, "    ports: [5432]\n", "    ports: [5432]\n    command: [postgres, -c, fsync=off]\n", 1)
	p, err := LoadPack(recipeRealm(t, pack))
	if err != nil {
		t.Fatal(err)
	}
	got := p.ServiceList()
	if len(got) != 1 || !slices.Equal(got[0].Command, []string{"postgres", "-c", "fsync=off"}) {
		t.Fatalf("ServiceList() = %+v, want the command carried", got)
	}
	for name, cmd := range map[string]string{
		"a command with a dollar": "[postgres, \"$HOME\"]",
		"an empty command":        "[]",
		"an empty argument":       "[postgres, \"\"]",
	} {
		bad := strings.Replace(recipe, "    ports: [5432]\n", "    ports: [5432]\n    command: "+cmd+"\n", 1)
		if _, err := LoadPack(recipeRealm(t, bad)); err == nil {
			t.Errorf("%s: LoadPack() = nil, want an error", name)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir [github.com/ouroboric-dev/gungnir.test]
./sandbox_command_test.go:9:66: unknown field Command in struct literal of type Service
./sandbox_command_test.go:13:25: undefined: MaxServiceCommand
./sandbox_command_test.go:22:54: undefined: MaxServiceArg
```

- [ ] **Step 3:** write the code.

Apply to `sandbox.go`:

```diff
diff --git a/sandbox.go b/sandbox.go
index a40cbc0..c694cc5 100644
--- a/sandbox.go
+++ b/sandbox.go
@@ -49,10 +49,18 @@ type Service struct {
 	Image string            // pinned by digest
 	Env   map[string]string // the service's environment: made-up development values, never a secret
 	Ports []int             // the TCP ports the work container may reach; the firewall opens these and no others
+	// Command replaces the image's own command, as an argument vector (no shell), for an image that does
+	// nothing without one, such as an object store that must be told to serve. Empty keeps the image's.
+	Command []string
 }
 
-// MaxServices is how many services one sandbox may start.
-const MaxServices = 8
+// MaxServices is how many services one sandbox may start, and MaxServiceCommand and MaxServiceArg bound
+// the command of one.
+const (
+	MaxServices       = 8
+	MaxServiceCommand = 16
+	MaxServiceArg     = 256
+)
 
 var (
 	image       = regexp.MustCompile(`^[a-z0-9][a-z0-9./_-]*(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$`)
@@ -146,6 +154,19 @@ func ValidateServices(services []Service) error {
 			}
 			ports[p] = true
 		}
+		if len(v.Command) > MaxServiceCommand {
+			errs = append(errs, fmt.Errorf("service %s: a command of %d arguments; at most %d", v.Name, len(v.Command), MaxServiceCommand))
+		}
+		for i, a := range v.Command {
+			switch {
+			case a == "" || len(a) > MaxServiceArg:
+				errs = append(errs, fmt.Errorf("service %s: command argument %d is empty or over %d bytes", v.Name, i+1, MaxServiceArg))
+			case strings.ContainsAny(a, "\x00\n\r"):
+				errs = append(errs, fmt.Errorf("service %s: command argument %d has a NUL or a line break", v.Name, i+1))
+			case strings.Contains(a, "$"):
+				errs = append(errs, fmt.Errorf("service %s: command argument %d has a '$'; compose would expand it from the operator's environment, so give the value literally", v.Name, i+1))
+			}
+		}
 		for k, val := range v.Env {
 			switch {
 			case k == "" || strings.ContainsAny(k, "=\x00"):
```

Apply to `schema/pack.go`:

```diff
diff --git a/schema/pack.go b/schema/pack.go
index fa5f087..3ffbde8 100644
--- a/schema/pack.go
+++ b/schema/pack.go
@@ -42,6 +42,9 @@ type PackService struct {
 	Image string            `yaml:"image"` // pinned by digest
 	Env   map[string]string `yaml:"env"`   // made-up development values
 	Ports []int             `yaml:"ports"` // the TCP ports the work container may reach
+	// Command replaces the image's own command, as an argument vector: for an image that does nothing
+	// without one.
+	Command []string `yaml:"command"`
 }
 
 // ServiceList returns the pack's services for a sandbox spec, sorted by name.
@@ -49,7 +52,7 @@ func (p *Pack) ServiceList() []gungnir.Service {
 	var out []gungnir.Service
 	for _, name := range sortedKeys(p.Services) {
 		v := p.Services[name]
-		out = append(out, gungnir.Service{Name: name, Image: v.Image, Env: v.Env, Ports: v.Ports})
+		out = append(out, gungnir.Service{Name: name, Image: v.Image, Env: v.Env, Ports: v.Ports, Command: v.Command})
 	}
 	return out
 }
```

Apply to `schema/pack.schema.json`:

```diff
diff --git a/schema/pack.schema.json b/schema/pack.schema.json
index 8441c34..965f521 100644
--- a/schema/pack.schema.json
+++ b/schema/pack.schema.json
@@ -76,7 +76,8 @@
         "properties": {
           "image": { "type": "string", "pattern": "^[a-z0-9][a-z0-9./_-]*(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$" },
           "env": { "type": "object", "additionalProperties": { "type": "string" } },
-          "ports": { "type": "array", "items": { "type": "integer", "minimum": 1, "maximum": 65535 } }
+          "ports": { "type": "array", "items": { "type": "integer", "minimum": 1, "maximum": 65535 } },
+          "command": { "type": "array", "minItems": 1, "maxItems": 16, "items": { "type": "string", "minLength": 1, "maxLength": 256 } }
         }
       }
     },
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T207: a scratch reviewer reads the output of the agent it reviews, and the spec gate reads its verdict

Spec §4.2: a design-conformance reviewer checks the spec, and the spec gate stops on a deviation. The reviewer is a scratch agent that must see what the spec stage wrote, which is not in the project yet (it is published after the gate). This task is the graph's side of that.

**Files (in `gungnir`):**
- Create: `schema/graph_conformance_test.go`
- Modify: `schema/graph.go`, `schema/graph.schema.json`

**Interfaces:**
- Produces: `schema.Node.Reviews` (a scratch agent: the earlier scratch agent whose `out/` it finds as `reviewed/`) and `Node.DeviationFrom` (a gate of the `spec` kind: the scratch reviewer whose verdict it reads).
- `ParseGraph` refuses `reviews` on a node that is not a scratch agent, on one that names a node that is not there, is itself, comes after it or is not a scratch agent; and `deviation_from` on a gate that is not `spec`, or that names a node that is not a scratch agent with `reviews`.

**Acceptance criteria:**
- [ ] The spec stage of a web graph (spec, conformance, spec gate re-running spec, publish) parses with its `Reviews`, `DeviationFrom` and `Reruns`.
- [ ] Each refusal above is a test case, and each is refused for its own reason (the test checks the message).

**Named test:** `go test ./schema -run 'TestAScratchReviewerReadsTheOutputOfTheAgentItReviewsAndTheSpecGateReadsItsVerdict|TestAReviewerAndTheDeviationItReportsAreRefusedWhenTheyPointAtNothingReal'` in `gungnir`. **Layer:** `gungnir`. **Size:** S (77). **Depends on:** v0-T206.

- [ ] **Step 1:** write the tests.

Write `schema/graph_conformance_test.go`:

```go
package schema

import (
	"strings"
	"testing"
)

// conformanceGraph is the spec stage of the web realm (spec §4.2): the spec is written in a scratch
// workspace, a second scratch agent reviews it against the design, and the spec gate reads what that
// reviewer found before anything is published.
const conformanceGraph = `
name: conformance
version: 1.0.0
nodes:
  - { id: spec, kind: agent, role: planner, prompt: prompts/spec.md, scratch: true, inputs: [docs/1-product] }
  - { id: conformance, kind: agent, role: reviewer, prompt: prompts/conformance.md, scratch: true, reviews: spec, inputs: [docs/1-product] }
  - { id: spec-gate, kind: gate, gate: spec, reruns: spec, deviation_from: conformance }
  - { id: spec-docs, kind: publish, from: spec, to: docs }
`

func TestAScratchReviewerReadsTheOutputOfTheAgentItReviewsAndTheSpecGateReadsItsVerdict(t *testing.T) {
	g, err := ParseGraph("graph.yaml", []byte(conformanceGraph))
	if err != nil {
		t.Fatalf("ParseGraph() = %v", err)
	}
	if c := g.Nodes[1]; c.Reviews != "spec" {
		t.Errorf("conformance.Reviews = %q, want spec", c.Reviews)
	}
	if gate := g.Nodes[2]; gate.DeviationFrom != "conformance" || gate.Reruns != "spec" {
		t.Errorf("spec-gate = %+v, want it to read conformance and re-run spec", gate)
	}
}

func TestAReviewerAndTheDeviationItReportsAreRefusedWhenTheyPointAtNothingReal(t *testing.T) {
	noScratch := strings.Replace(conformanceGraph, "id: spec, kind: agent, role: planner, prompt: prompts/spec.md, scratch: true, inputs: [docs/1-product]", "id: spec, kind: agent, role: planner, prompt: prompts/spec.md, repo: repos/web", 1)
	noScratch = strings.Replace(noScratch, "  - { id: spec-gate, kind: gate, gate: spec, reruns: spec, deviation_from: conformance }\n  - { id: spec-docs, kind: publish, from: spec, to: docs }\n", "", 1)
	bad := map[string]struct{ graph, want string }{
		"reviews a node that is not there":      {strings.Replace(conformanceGraph, "reviews: spec", "reviews: nope", 1), "reviews"},
		"reviews itself":                        {strings.Replace(conformanceGraph, "reviews: spec", "reviews: conformance", 1), "reviews"},
		"reviews a node after it":               {strings.Replace(conformanceGraph, "reviews: spec", "reviews: spec-docs", 1), "reviews"},
		"reviews an agent that is no scratch":   {noScratch, "reviews"},
		"a reviewer that is no scratch agent":   {strings.Replace(conformanceGraph, "scratch: true, reviews: spec, inputs: [docs/1-product]", "reviews: spec", 1), "only a scratch agent reviews"},
		"a deviation read from no node":         {strings.Replace(conformanceGraph, "deviation_from: conformance", "deviation_from: nope", 1), "deviation_from"},
		"a deviation read from a plain scratch": {strings.Replace(conformanceGraph, "deviation_from: conformance", "deviation_from: spec", 1), "deviation_from"},
		"a deviation read by a gate not spec":   {strings.Replace(conformanceGraph, "gate: spec,", "gate: plan,", 1), "deviation_from"},
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

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/graph_conformance_test.go:26:24: c.Reviews undefined (type Node has no field or method Reviews)
schema/graph_conformance_test.go:27:53: c.Reviews undefined (type Node has no field or method Reviews)
schema/graph_conformance_test.go:29:30: gate.DeviationFrom undefined (type Node has no field or method DeviationFrom)
```

- [ ] **Step 3:** write the code.

Apply to `schema/graph.go`:

```diff
diff --git a/schema/graph.go b/schema/graph.go
index 69385d1..74c4bb1 100644
--- a/schema/graph.go
+++ b/schema/graph.go
@@ -65,6 +65,8 @@ type Node struct {
 	Gate     gungnir.Gate `yaml:"gate"`      // gate: the approval point
 	Reruns   string       `yaml:"reruns"`    // gate: the agent node a rejection re-runs; set by ParseGraph
 
+	DeviationFrom string `yaml:"deviation_from"` // gate (spec): the scratch reviewer whose conformance.json says whether the spec deviates from the design; a deviation stops the gate (spec §7.1)
+
 	Repo       string     `yaml:"repo"`       // exec, agent, loop, merge, pointer: a repo of the project, relative to it; "." is the project umbrella
 	Checks     []string   `yaml:"checks"`     // loop, merge, pointer: pack checks run in the leaf (a loop's, in order, after each attempt)
 	Attempts   int        `yaml:"attempts"`   // loop: how many attempts before it escalates; DefaultAttempts when unset
@@ -73,6 +75,7 @@ type Node struct {
 	Generated  []string   `yaml:"generated"`  // pointer: generated files of the parent umbrella, committed with the move under the shrink guard
 
 	Scratch bool     `yaml:"scratch"` // agent: runs in a scratch workspace, not a leaf, and writes its documents to out/ (spec §3.3 rule 1)
+	Reviews string   `yaml:"reviews"` // agent (scratch): an earlier scratch agent whose out/ this one reads, as reviewed/ in its own workspace (spec §4.2, the design-conformance review)
 	Inputs  []string `yaml:"inputs"`  // agent (scratch): files and folders of the project, copied into the workspace; changes to the copies are ignored
 	From    string   `yaml:"from"`    // publish: the scratch agent whose output is published; tasks: the tasks.md, by glob; init: the leaves file
 	To      string   `yaml:"to"`      // publish: the folder of the project its files go to
@@ -257,6 +260,10 @@ func (c *graphCheck) stage(n *Node, before []Node) error {
 			return fmt.Errorf("%s: node %s: a scratch agent writes its output to out/, so it can't be read-only", file, n.ID)
 		case !n.Scratch && len(n.Inputs) > 0:
 			return fmt.Errorf("%s: node %s: only a scratch agent takes inputs", file, n.ID)
+		case !n.Scratch && n.Reviews != "":
+			return fmt.Errorf("%s: node %s: only a scratch agent reviews another scratch agent's output", file, n.ID)
+		case n.Reviews != "" && !slices.ContainsFunc(before, func(m Node) bool { return m.ID == n.Reviews && m.Kind == KindAgent && m.Scratch }):
+			return fmt.Errorf("%s: node %s reviews %q, which must be a scratch agent node before it", file, n.ID, n.Reviews)
 		}
 		seen := map[string]bool{}
 		for _, in := range n.Inputs {
@@ -278,6 +285,18 @@ func (c *graphCheck) stage(n *Node, before []Node) error {
 		if n.To == "." || !projectPath(n.To) {
 			return fmt.Errorf("%s: node %s: to %q must be a folder of the project (not the project itself, .git or .factory)", file, n.ID, n.To)
 		}
+	case KindGate:
+		if n.DeviationFrom == "" {
+			break
+		}
+		if n.Gate != gungnir.GateSpec {
+			return fmt.Errorf("%s: node %s: deviation_from belongs to the spec gate, not %s", file, n.ID, n.Gate)
+		}
+		if !slices.ContainsFunc(before, func(m Node) bool {
+			return m.ID == n.DeviationFrom && m.Kind == KindAgent && m.Scratch && m.Reviews != ""
+		}) {
+			return fmt.Errorf("%s: node %s: deviation_from %q must be a scratch reviewer (an agent with reviews) before it", file, n.ID, n.DeviationFrom)
+		}
 	case KindTasks, KindInit:
 		if !projectPath(n.From) {
 			return fmt.Errorf("%s: node %s: from %q must be a path inside the project, outside .git and .factory", file, n.ID, n.From)
```

Apply to `schema/graph.schema.json`:

```diff
diff --git a/schema/graph.schema.json b/schema/graph.schema.json
index 0219085..3cfebba 100644
--- a/schema/graph.schema.json
+++ b/schema/graph.schema.json
@@ -66,6 +66,7 @@
             "repo": { "$ref": "#/$defs/repo" },
             "timeout": { "$ref": "#/$defs/duration" },
             "scratch": { "type": "boolean" },
+            "reviews": { "$ref": "#/$defs/id" },
             "inputs": { "type": "array", "items": { "type": "string", "minLength": 1 } }
           }
         },
@@ -76,7 +77,8 @@
             "id": { "$ref": "#/$defs/id" },
             "kind": { "const": "gate" },
             "gate": { "$ref": "#/$defs/gate" },
-            "reruns": { "$ref": "#/$defs/id" }
+            "reruns": { "$ref": "#/$defs/id" },
+            "deviation_from": { "$ref": "#/$defs/id" }
           }
         },
         {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T208: the design-conformance verdict is read exactly, and the ledger records it

The verdict decides whether a person must look at a spec, so it is read as strictly as a reviewer's findings (spec §4.6): one JSON document, bare or in one code fence; a verdict that cannot be read is an error, never a pass.

**Files (in `gungnir`):**
- Create: `conformance.go`, `schema/conformance.schema.json`, `schema/conformance_test.go`
- Modify: `event.go`, `schema/event.go`, `schema/ledger-event.schema.json`

**Interfaces:**
- Produces: `gungnir.Conformance{Deviation bool; Amendment string}` and `MaxAmendment` (8000); `schema.ParseConformance([]byte) (gungnir.Conformance, error)`; the ledger event `conformance_checked`.
- `ParseConformance` refuses an empty answer, prose, `{}`, a deviation with no amendment or a blank one, an amendment on a verdict with no deviation, a verdict that is not a boolean, an unknown field, two documents and an amendment over `MaxAmendment`.

**Acceptance criteria:**
- [ ] `{"deviation": false}`, the same in a code fence and a deviation with its amendment are read; every other answer above is an error.
- [ ] The ledger accepts a `conformance_checked` line.

**Named test:** `go test ./schema -run 'TestParseConformanceReadsAVerdictExactly|TestTheLedgerRecordsAConformanceCheck'` in `gungnir`. **Layer:** `gungnir`. **Size:** M (108). **Depends on:** v0-T207.

- [ ] **Step 1:** write the tests.

Write `schema/conformance_test.go`:

````go
package schema

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
)

func TestParseConformanceReadsAVerdictExactly(t *testing.T) {
	ok := map[string]gungnir.Conformance{
		`{"deviation": false}`:                                                {},
		"```json\n{\"deviation\": false}\n```":                                {},
		`{"deviation": true, "amendment": "Add offline mode to the design."}`: {Deviation: true, Amendment: "Add offline mode to the design."},
	}
	for answer, want := range ok {
		got, err := ParseConformance([]byte(answer))
		if err != nil || got != want {
			t.Errorf("ParseConformance(%q) = %+v, %v; want %+v", answer, got, err, want)
		}
	}
	bad := map[string]string{
		"nothing":                            ``,
		"prose":                              `The spec conforms.`,
		"no verdict":                         `{}`,
		"a deviation with no amendment":      `{"deviation": true}`,
		"a deviation with a blank amendment": `{"deviation": true, "amendment": "  "}`,
		"an amendment with no deviation":     `{"deviation": false, "amendment": "x"}`,
		"a verdict that is not a bool":       `{"deviation": "no"}`,
		"an unknown field":                   `{"deviation": false, "ok": true}`,
		"two documents":                      `{"deviation": false} {"deviation": true, "amendment": "x"}`,
		"an amendment too long":              `{"deviation": true, "amendment": "` + strings.Repeat("x", gungnir.MaxAmendment+1) + `"}`,
	}
	for name, answer := range bad {
		if got, err := ParseConformance([]byte(answer)); err == nil {
			t.Errorf("%s: ParseConformance() = %+v, nil; want an error (a verdict nobody can read is not a pass)", name, got)
		}
	}
}

func TestTheLedgerRecordsAConformanceCheck(t *testing.T) {
	e := event(gungnir.EventConformanceChecked)
	e.Node, e.Result = "conformance", "deviation: the spec adds offline mode"
	line, _ := json.Marshal(e)
	if err := ValidateEvent(line); err != nil {
		t.Errorf("ValidateEvent() = %v", err)
	}
}
````

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gungnir/schema [github.com/ouroboric-dev/gungnir/schema.test]
schema/conformance_test.go:12:27: undefined: gungnir.Conformance
schema/conformance_test.go:18:15: undefined: ParseConformance
schema/conformance_test.go:33:108: undefined: gungnir.MaxAmendment
```

- [ ] **Step 3:** write the code.

Write `conformance.go`:

```go
package gungnir

// Conformance is the verdict of the design-conformance reviewer on a spec (spec §4.2): whether the spec
// deviates from the approved design, and if it does, the amendment to the design it proposes. A
// deviation stops the spec approval point in every mode (spec §7.1).
type Conformance struct {
	Deviation bool   `json:"deviation"`
	Amendment string `json:"amendment,omitempty"`
}

// MaxAmendment is the most bytes of an amendment Odin reads and shows an operator.
const MaxAmendment = 8000
```

Apply to `event.go`:

```diff
diff --git a/event.go b/event.go
index 688a161..bd3edb7 100644
--- a/event.go
+++ b/event.go
@@ -46,6 +46,8 @@ const (
 	EventTaskStarted   EventName = "task_started"   // the first node of a task's shape began
 	EventTaskDone      EventName = "task_done"      // the last node of a task's shape finished
 	EventTaskBlocked   EventName = "task_blocked"   // an unattended run gave a task up and went on with the rest (spec §7.3)
+
+	EventConformanceChecked EventName = "conformance_checked" // the design-conformance reviewer's verdict on a spec was read (spec §4.2)
 )
 
 // Events returns every event name, in the order above.
@@ -57,7 +59,7 @@ func Events() []EventName {
 		EventModeChanged, EventConfigChanged, EventRepoCreated, EventSandboxUp, EventSandboxDown,
 		EventRetry, EventRunPaused, EventFindingRaised, EventFindingClosed, EventFindingReopened,
 		EventRealmLoaded, EventDocsPublished, EventTasksReady, EventNodeReturned, EventTaskStarted, EventTaskDone,
-		EventTaskBlocked}
+		EventTaskBlocked, EventConformanceChecked}
 }
 
 // Event is one ledger line. Fields follow OpenTelemetry's GenAI attribute names (gen_ai.*) where
```

Write `schema/conformance.schema.json`:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://github.com/ouroboric-dev/gungnir/schema/conformance.schema.json",
  "title": "a design-conformance verdict",
  "description": "The design-conformance reviewer's whole answer: whether the spec deviates from the approved design, and the amendment it proposes when it does (spec §4.2).",
  "type": "object",
  "additionalProperties": false,
  "required": ["deviation"],
  "properties": {
    "deviation": { "type": "boolean" },
    "amendment": { "type": "string", "maxLength": 8000 }
  },
  "if": { "properties": { "deviation": { "const": true } } },
  "then": { "required": ["amendment"], "properties": { "amendment": { "pattern": "\\S" } } },
  "else": { "not": { "required": ["amendment"] } }
}
```

Apply to `schema/event.go`:

```diff
diff --git a/schema/event.go b/schema/event.go
index 475777f..c88f605 100644
--- a/schema/event.go
+++ b/schema/event.go
@@ -91,3 +91,30 @@ func unfence(answer string) (string, error) {
 	}
 	return body, nil
 }
+
+// ParseConformance parses the design-conformance reviewer's verdict: one JSON document, bare or in one
+// code fence. A verdict that can't be read, a deviation without an amendment and an amendment without a
+// deviation are errors, never a pass: the spec gate would let a deviation through (spec §4.6).
+func ParseConformance(answer []byte) (gungnir.Conformance, error) {
+	var c gungnir.Conformance
+	data, err := unfence(string(answer))
+	if err != nil {
+		return c, err
+	}
+	doc, err := jsonschema.UnmarshalJSON(strings.NewReader(data))
+	if err != nil {
+		return c, fmt.Errorf("conformance: %w", err)
+	}
+	if err := validate("conformance", "conformance.schema.json", doc); err != nil {
+		return c, err
+	}
+	dec := json.NewDecoder(strings.NewReader(data))
+	dec.DisallowUnknownFields()
+	if err := dec.Decode(&c); err != nil {
+		return gungnir.Conformance{}, fmt.Errorf("conformance: %w", err)
+	}
+	if dec.More() {
+		return gungnir.Conformance{}, fmt.Errorf("conformance: more than one document")
+	}
+	return c, nil
+}
```

Apply to `schema/ledger-event.schema.json`:

```diff
diff --git a/schema/ledger-event.schema.json b/schema/ledger-event.schema.json
index ac0d59f..c0d564e 100644
--- a/schema/ledger-event.schema.json
+++ b/schema/ledger-event.schema.json
@@ -19,7 +19,7 @@
                "budget_warning", "policy_violation", "pointer_moved", "mode_changed", "config_changed",
                "repo_created", "sandbox_up", "sandbox_down", "retry", "run_paused", "finding_raised",
                "finding_closed", "finding_reopened", "realm_loaded", "docs_published", "tasks_ready",
-               "node_returned", "task_started", "task_done", "task_blocked"]
+               "node_returned", "task_started", "task_done", "task_blocked", "conformance_checked"]
     },
     "ygg.attempt": { "type": "integer", "minimum": 1 },
     "gen_ai.agent.name": { "type": "string" },
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T209: Gungnir's documentation

The architecture page says what Gungnir now defines.

**Files (in `gungnir`):**
- Modify: `docs/architecture.md`

**Acceptance criteria:**
- [ ] `docs/architecture.md` says that a stack is an image or a build context (with its target), that a service may carry a command, and what the design-conformance review is.

**Named test:** `git diff --stat -- docs/architecture.md` in `gungnir`. **Layer:** `gungnir`. **Size:** S (7). **Depends on:** v0-T208.

- [ ] **Step 1:** write the code.

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 85c5d9c..cedd2c0 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -27,7 +27,13 @@ The contract: Go interface types and JSON schemas for ledger events, `graph.yaml
 - Reads a plan's `tasks.md` exactly into `Feature`s, applies the Definition of Ready (`CheckReady`),
   and defines `features.json`, which Odin alone writes.
 - Describes a sandbox (`SandboxSpec`): the leaf or scratch folder it holds, the stack layer of the
-  leaf's realm, and the services it starts beside the work container.
+  leaf's realm, and the services it starts beside the work container (each with an optional command, for
+  an image that does nothing without one).
+- Says what a realm's stack is (change realm-content): an image pinned by digest, or a build context in
+  the realm, whose files (and the stage built, its `target`) are hashed into the local tag of the image `ygg sandbox build` builds from it.
+  A realm may name a second stack for the acceptance checks that run on a snapshot of the whole project.
+- Defines the design-conformance review (spec §4.2): a scratch reviewer (`reviews`) reads another scratch
+  agent's output, its verdict (`Conformance`) is read exactly, and the spec gate reads it (`deviation_from`).
 - Validates configs against those schemas.
 - Takes every interface change first: one PR here, plus one in each affected component (spec §1).
 
```

- [ ] **Step 2:** run the named test. Expect `ok`.

- [ ] **Step 3:** commit (see "How each task lands").

---

### Task v0-T210: a service starts with the command the pack gives it

Gleipnir's first task. Branch `realms/content` from `main` in `gleipnir`, before step 1. Gungnir's v0-T205 to v0-T209 are merged and pinned, or `yggdrasil/go.work` builds the local copy. A service the pack gives a command runs it instead of the image's own (SeaweedFS does nothing without `server -s3`). The compose file is still generated by the factory alone and checked against what it should be before every start.

**Files (in `gleipnir`):**
- Create: `sandbox/command_test.go`
- Modify: `sandbox/config.go`

**Interfaces:**
- Consumes: `gungnir.Service.Command`. The generated `compose.yaml` carries it as the service's `command`, and nothing for a service that has none, so the image's own stays.
- `Validate` compares the generated file with what the factory renders, so a command changed in the file since it was generated is refused.

**Acceptance criteria:**
- [ ] A service with a command renders it; one without renders none.
- [ ] `Validate` accepts the generated file and refuses one whose service command was changed.

**Named test:** `go test ./sandbox -run 'TestAServiceRunsTheCommandItWasGivenAndNotTheImagesOwn'` in `gleipnir`. **Layer:** `gleipnir`. **Size:** S (48). **Depends on:** v0-T209.

- [ ] **Step 1:** write the tests.

Write `sandbox/command_test.go`:

```go
package sandbox

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"go.yaml.in/yaml/v3"
)

func TestAServiceRunsTheCommandItWasGivenAndNotTheImagesOwn(t *testing.T) {
	tmp := t.TempDir()
	c := cfg()
	c.Mounts = append(c.Mounts, PathMap{Host: tmp, Engine: "/mnt/wsl/cfg"})
	sp := withServices()
	sp.Services[0].Command = []string{"server", "-s3", "-dir=/data"}
	g, err := Generate(filepath.Join(tmp, "sandbox"), sp, c)
	if err != nil {
		t.Fatal(err)
	}
	var cf composeFile
	raw, _ := os.ReadFile(g.Compose)
	if err := yaml.Unmarshal(raw, &cf); err != nil {
		t.Fatal(err)
	}
	if got := cf.Services["seaweedfs"].Command; !slices.Equal(got, sp.Services[0].Command) {
		t.Errorf("seaweedfs command = %v, want %v", got, sp.Services[0].Command)
	}
	if got := cf.Services["postgres"].Command; got != nil {
		t.Errorf("postgres has no command of its own, yet compose says %v", got)
	}
	if err := Validate(g, sp, c); err != nil {
		t.Errorf("Validate() = %v; a command the spec names is part of what the factory renders", err)
	}
	// A command that differs from the spec's is not what the factory generated.
	tampered := strings.Replace(string(raw), "-dir=/data", "-dir=/etc", 1)
	if err := os.WriteFile(g.Compose, []byte(tampered), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := Validate(g, sp, c); err == nil {
		t.Error("Validate() = nil for a compose file whose service command was changed")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAServiceRunsTheCommandItWasGivenAndNotTheImagesOwn (0.00s)
    command_test.go:29: seaweedfs command = [], want [server -s3 -dir=/data]
    command_test.go:43: Validate() = nil for a compose file whose service command was changed
FAIL
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/config.go`:

```diff
diff --git a/sandbox/config.go b/sandbox/config.go
index 2a95ca7..81d3934 100644
--- a/sandbox/config.go
+++ b/sandbox/config.go
@@ -237,7 +237,8 @@ func render(dir string, spec gungnir.SandboxSpec, c Config) (map[string][]byte,
 		},
 	}}
 	// The services a leaf's realm, and the realms of the leaves it consumes, ask for. They run on the
-	// image's own user and command, with no mount, no capability beyond the engine's default set and no
+	// image's own user and command (or the argument vector the pack gives an image that does nothing
+	// without one; gungnir refuses a '$' in it), with no mount, no capability beyond the engine's default set and no
 	// published port: the work container reaches them by name, through the firewall's network, only on
 	// the ports the spec lists (egress.sh). They sit on the internal ServicesNetwork alone, with no route
 	// out, so none of them can reach the internet for a client; the firewall joins it beside the default
@@ -245,7 +246,7 @@ func render(dir string, spec gungnir.SandboxSpec, c Config) (map[string][]byte,
 	var names []string
 	for _, v := range spec.Services {
 		cf.Services[v.Name] = service{Image: v.Image, PullPolicy: "never", SecurityOpt: []string{"no-new-privileges:true"},
-			Networks: []string{ServicesNetwork}, Environment: literalEnv(v.Env), Labels: labels}
+			Command: v.Command, Networks: []string{ServicesNetwork}, Environment: literalEnv(v.Env), Labels: labels}
 		names = append(names, v.Name)
 	}
 	slices.Sort(names)
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T211: ygg sandbox build can build a realm's stack from its context, from pinned bases only

A realm's stack may be a folder of the realm with a Containerfile (change `realm-content`). Building it is the one place a registry and the network are reached for tools, so the driver builds it from inputs that are pinned and refuses anything else before it calls the engine.

**Files (in `gleipnir`):**
- Create: `sandbox/stackbuild.go`, `sandbox/stackbuild_test.go`

**Interfaces:**
- Produces: `(*Driver).BuildStack(ctx, ref, dir, target string) (built bool, err error)`. It refuses a `ref` that is not the local tag of a stack, a tag that does not match `schema.StackHash(dir, target)`, a Containerfile with no `FROM`, a `FROM` that is neither an image pinned by digest nor `scratch` nor an earlier stage (an `ARG` in a `FROM` is refused too), a `COPY --from` or `RUN --mount ...from=` of anything but an earlier stage, an `ADD` (it may fetch a URL), and a `target` that is not a stage.
- Otherwise it returns `false` without a call to the engine when the image is already there (the tag is a hash of the context, so an image with it is this image); else it pulls every external base once, by digest, with the isolated registry auth, and runs `podman build --pull=never -t <ref> -f <dir>/Containerfile [--target <stage>] <dir>`.

**Acceptance criteria:**
- [ ] A context with two stages builds: each base is pulled once before the build, which never pulls, and `--target` is passed.
- [ ] An image that exists is left alone.
- [ ] Each refusal above is a test case, and in each the engine is not called.

**Named test:** `go test ./sandbox -run 'TestBuildStackPullsTheBasesByDigestThenBuildsTheContextNeverPulling|TestBuildStackLeavesAnImageThatIsThereAlone|TestBuildStackRefusesAContextItCouldNotBuildFromPinnedInputsOnly|TestBuildStackBuildsTheStageItWasToldTo'` in `gleipnir`. **Layer:** `gleipnir`. **Size:** M (296). **Depends on:** v0-T210.

- [ ] **Step 1:** write the tests.

Write `sandbox/stackbuild_test.go`:

```go
package sandbox

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

const (
	baseA = "docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514"
	baseB = "docker.io/library/node:24.1.0-bookworm@sha256:3333333333333333333333333333333333333333333333333333333333333333"
)

// stackContext writes a build context with the given Containerfile and returns it with the tag a
// build of it gets.
func stackContext(t *testing.T, containerfile string, more map[string]string) (dir, ref string) {
	t.Helper()
	return stackContextFor(t, containerfile, more, "")
}

func stackContextFor(t *testing.T, containerfile string, more map[string]string, target string) (dir, ref string) {
	t.Helper()
	dir = t.TempDir()
	files := map[string]string{"Containerfile": containerfile}
	for k, v := range more {
		files[k] = v
	}
	for name, body := range files {
		if err := os.MkdirAll(filepath.Dir(filepath.Join(dir, name)), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, name), []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	h, err := schema.StackHash(dir, target)
	if err != nil {
		t.Fatal(err)
	}
	return dir, gungnir.LocalStack("midgard-react", h)
}

const goodContainerfile = "# the stack\nFROM " + baseB + " AS tools\nRUN npm install -g prism@5.0.0 \\\n && true\nFROM " + baseA + " AS stack\nCOPY --from=tools /usr/local /opt/tools\nCOPY checks/ /opt/ygg/checks/\nRUN true\n"

func TestBuildStackPullsTheBasesByDigestThenBuildsTheContextNeverPulling(t *testing.T) {
	d, log, _ := fakeEngine(t)
	dir, ref := stackContext(t, goodContainerfile, map[string]string{"checks/go-unit.sh": "#!/bin/sh\n"})
	t.Setenv("STUB_MISSING", ref)
	built, err := d.BuildStack(context.Background(), ref, dir, "")
	if err != nil || !built {
		t.Fatalf("BuildStack() = %v, %v", built, err)
	}
	got := logOf(t, log)
	for _, want := range []string{"podman pull -q --authfile " + d.auth + "/auth.json " + baseA, "podman pull -q --authfile " + d.auth + "/auth.json " + baseB,
		"podman build --pull=never -t " + ref + " -f " + filepath.Join(dir, "Containerfile") + " " + dir} {
		if !strings.Contains(got, want) {
			t.Errorf("the engine calls lack %q:\n%s", want, got)
		}
	}
	if strings.Index(got, "podman pull") > strings.Index(got, "podman build") {
		t.Error("a build ran before the pulls")
	}
	if strings.Count(got, "podman pull") != 2 {
		t.Errorf("each base is pulled once:\n%s", got)
	}
}

func TestBuildStackLeavesAnImageThatIsThereAlone(t *testing.T) {
	d, log, _ := fakeEngine(t)
	dir, ref := stackContext(t, goodContainerfile, nil)
	built, err := d.BuildStack(context.Background(), ref, dir, "")
	if err != nil || built {
		t.Fatalf("BuildStack() = %v, %v; the tag is a hash of the context, so an image with it is this image", built, err)
	}
	if got := logOf(t, log); strings.Contains(got, "podman build") || strings.Contains(got, "podman pull") {
		t.Errorf("an existing stack was built or pulled again:\n%s", got)
	}
}

func TestBuildStackRefusesAContextItCouldNotBuildFromPinnedInputsOnly(t *testing.T) {
	bad := map[string]string{
		"a base with a tag and no digest":      "FROM docker.io/library/golang:1.26.7\n",
		"a base from an argument":              "ARG BASE=" + baseA + "\nFROM ${BASE}\n",
		"a stage copied from an image":         "FROM " + baseA + "\nCOPY --from=docker.io/library/busybox:1 /bin/sh /sh\n",
		"a stage copied from a later stage":    "FROM " + baseA + " AS a\nCOPY --from=b /x /x\nFROM " + baseB + " AS b\n",
		"a mount from an image":                "FROM " + baseA + "\nRUN --mount=type=bind,from=docker.io/library/busybox:1,target=/x true\n",
		"a remote file added":                  "FROM " + baseA + "\nADD https://example.com/tool.tgz /opt/\n",
		"no base at all":                       "RUN true\n",
		"a base on an option and not a digest": "FROM --platform=linux/amd64 docker.io/library/golang:1.26.7\n",
	}
	for name, cf := range bad {
		d, log, _ := fakeEngine(t)
		dir, ref := stackContext(t, cf, nil)
		if _, err := d.BuildStack(context.Background(), ref, dir, ""); err == nil {
			t.Errorf("%s: BuildStack() = nil, want an error", name)
		}
		if got := logOf(t, log); got != "" {
			t.Errorf("%s: the engine was called before the context was refused:\n%s", name, got)
		}
	}
	d, log, _ := fakeEngine(t)
	dir, ref := stackContext(t, goodContainerfile, nil)
	if err := os.WriteFile(filepath.Join(dir, "late.sh"), []byte("echo changed\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := d.BuildStack(context.Background(), ref, dir, ""); err == nil || !strings.Contains(err.Error(), "does not match") {
		t.Errorf("a tag that does not match the context: BuildStack() = %v", err)
	}
	for _, other := range []string{baseA, "localhost/ygg-work:abc", "localhost/ygg-stack-x:latest"} {
		if _, err := d.BuildStack(context.Background(), other, dir, ""); err == nil {
			t.Errorf("BuildStack(%q) = nil, want an error: only the tag of a built stack is built", other)
		}
	}
	if got := logOf(t, log); got != "" {
		t.Errorf("the engine was called:\n%s", got)
	}
}

func TestBuildStackBuildsTheStageItWasToldTo(t *testing.T) {
	cf := "FROM " + baseA + " AS web\nRUN true\nFROM web AS acceptance\nRUN true\n"
	d, log, _ := fakeEngine(t)
	dir, ref := stackContextFor(t, cf, nil, "acceptance")
	t.Setenv("STUB_MISSING", ref)
	if built, err := d.BuildStack(context.Background(), ref, dir, "acceptance"); err != nil || !built {
		t.Fatalf("BuildStack() = %v, %v", built, err)
	}
	if got := logOf(t, log); !strings.Contains(got, "-t "+ref+" -f "+filepath.Join(dir, "Containerfile")+" --target acceptance "+dir) {
		t.Errorf("the build lacks --target acceptance:\n%s", got)
	}
	if _, err := d.BuildStack(context.Background(), ref, dir, "web"); err == nil || !strings.Contains(err.Error(), "does not match") {
		t.Errorf("a tag made for another stage: BuildStack() = %v", err)
	}
	dir2, ref2 := stackContextFor(t, cf, nil, "nope")
	d2, log2, _ := fakeEngine(t)
	if _, err := d2.BuildStack(context.Background(), ref2, dir2, "nope"); err == nil || !strings.Contains(err.Error(), "no stage named") {
		t.Errorf("a stage the Containerfile lacks: BuildStack() = %v", err)
	}
	if got := logOf(t, log2); got != "" {
		t.Errorf("the engine was called:\n%s", got)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/gleipnir/sandbox [github.com/ouroboric-dev/gleipnir/sandbox.test]
sandbox/stackbuild_test.go:54:18: d.BuildStack undefined (type *Driver has no field or method BuildStack)
sandbox/stackbuild_test.go:76:18: d.BuildStack undefined (type *Driver has no field or method BuildStack)
sandbox/stackbuild_test.go:99:18: d.BuildStack undefined (type *Driver has no field or method BuildStack)
```

- [ ] **Step 3:** write the code.

Write `sandbox/stackbuild.go`:

```go
package sandbox

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

// BuildStack builds the stack layer of a realm from its build context at dir, up to the Containerfile's
// stage target (its last stage when empty), tagged ref, which is the tag gungnir gives this context and
// stage (schema.StackHash). It reports false when the image is
// there already: the tag is a hash of every file of the context, so an image with it is this image.
//
// The Containerfile may start only from images pinned by digest or from its own stages, and may copy
// only from its own stages: every external base is pulled here, with the isolated registry auth,
// before a build that never pulls. What its RUN lines fetch, at pinned versions, is the realm's to
// pin and the founder's to review. Like Build, it is for ygg sandbox build alone: a run never builds.
func (d *Driver) BuildStack(ctx context.Context, ref, dir, target string) (built bool, err error) {
	if !gungnir.ValidStack(ref) || gungnir.ValidImage(ref) {
		return false, fmt.Errorf("%q is not the tag of a built stack, so it is not built", ref)
	}
	hash, err := schema.StackHash(dir, target)
	if err != nil {
		return false, err
	}
	if !strings.HasSuffix(ref, ":"+hash) {
		return false, fmt.Errorf("the tag %s does not match the build context %s (its hash is %s)", ref, dir, hash)
	}
	raw, err := os.ReadFile(filepath.Join(dir, "Containerfile"))
	if err != nil {
		return false, err
	}
	bases, stages, err := containerfileBases(string(raw))
	if err != nil {
		return false, fmt.Errorf("%s: %w", filepath.Join(dir, "Containerfile"), err)
	}
	if target != "" && !slices.Contains(stages, target) {
		return false, fmt.Errorf("%s has no stage named %q", filepath.Join(dir, "Containerfile"), target)
	}
	if _, err := d.run(ctx, d.Podman, "image", "exists", ref); err == nil {
		return false, nil
	}
	for _, base := range bases {
		if _, err := d.run(ctx, d.Podman, "pull", "-q", "--authfile", filepath.Join(d.auth, "auth.json"), base); err != nil {
			return false, err
		}
	}
	args := []string{"build", "--pull=never", "-t", ref, "-f", filepath.Join(dir, "Containerfile")}
	if target != "" {
		args = append(args, "--target", target)
	}
	if _, err := d.run(ctx, d.Podman, append(args, dir)...); err != nil {
		return false, err
	}
	return true, nil
}

// containerfileBases returns the external images a Containerfile starts from, once each, and the names of
// its stages, and refuses
// anything that would reach an image nobody pinned: a base without a digest or from an argument, a COPY
// or mount from a stage that does not exist yet or from an image, and ADD, which may fetch a URL.
func containerfileBases(text string) (bases, stages []string, err error) {
	known := func(from string) bool {
		if n, err := strconv.Atoi(from); err == nil {
			return n >= 0 && n < len(stages)
		}
		return slices.Contains(stages, strings.ToLower(from))
	}
	for i, line := range joinContinuations(text) {
		fields := strings.Fields(line)
		if len(fields) == 0 || strings.HasPrefix(fields[0], "#") {
			continue
		}
		switch strings.ToUpper(fields[0]) {
		case "FROM":
			var args []string
			for _, f := range fields[1:] {
				if !strings.HasPrefix(f, "--") {
					args = append(args, f)
				}
			}
			if len(args) == 0 {
				return nil, nil, fmt.Errorf("instruction %d: FROM names no image", i+1)
			}
			img, name := args[0], ""
			if len(args) >= 3 && strings.EqualFold(args[1], "AS") {
				name = strings.ToLower(args[2])
			}
			switch {
			case img == "scratch" || known(img):
			case gungnir.ValidImage(img):
				if !slices.Contains(bases, img) {
					bases = append(bases, img)
				}
			default:
				return nil, nil, fmt.Errorf("instruction %d: FROM %s is not an image pinned by digest or an earlier stage", i+1, img)
			}
			stages = append(stages, name)
		case "COPY", "RUN":
			for _, f := range fields[1:] {
				for _, opt := range strings.Split(strings.TrimPrefix(f, "--mount="), ",") {
					from, ok := strings.CutPrefix(opt, "--from=")
					if !ok {
						from, ok = strings.CutPrefix(opt, "from=")
					}
					if ok && !known(from) {
						return nil, nil, fmt.Errorf("instruction %d: %s from %q, which is not an earlier stage", i+1, strings.ToUpper(fields[0]), from)
					}
				}
			}
		case "ADD":
			return nil, nil, fmt.Errorf("instruction %d: ADD may fetch a file nobody pinned; use COPY", i+1)
		}
	}
	if len(stages) == 0 {
		return nil, nil, fmt.Errorf("no FROM line")
	}
	return bases, stages, nil
}

// joinContinuations joins lines that end with a backslash, as a Containerfile does.
func joinContinuations(text string) []string {
	var out []string
	var cur strings.Builder
	for _, l := range strings.Split(text, "\n") {
		l = strings.TrimRight(l, " \t\r")
		if strings.HasPrefix(strings.TrimSpace(l), "#") && cur.Len() == 0 {
			out = append(out, l)
			continue
		}
		if body, ok := strings.CutSuffix(l, "\\"); ok {
			cur.WriteString(body + " ")
			continue
		}
		cur.WriteString(l)
		out = append(out, cur.String())
		cur.Reset()
	}
	if cur.Len() > 0 {
		out = append(out, cur.String())
	}
	return out
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T212: building the layers on a stack built from a realm's context needs no pull

`Build` pulls the stack by digest and layers the factory's tools on it. A stack built from a context is local: nothing to pull, and a missing one is a mistake to report.

**Files (in `gleipnir`):**
- Modify: `sandbox/images.go`, `sandbox/images_test.go`

**Interfaces:**
- `(*Driver).Build(ctx, stack)` with a local stack tag checks `podman image exists <stack>` instead of pulling it, and returns `ErrNoImage` naming the stack when it is not there; the node image is pulled as before, and the layers are built `--pull=never` on the stack.

**Acceptance criteria:**
- [ ] A built stack is not pulled from a registry, and the layers are built on it.
- [ ] A stack that was not built fails with `ErrNoImage`, and no layer is built.

**Named test:** `go test ./sandbox -run 'TestBuildStartsFromABuiltStackWithoutPullingIt|TestBuildRefusesABuiltStackThatWasNotBuilt'` in `gleipnir`. **Layer:** `gleipnir`. **Size:** S (39). **Depends on:** v0-T211.

- [ ] **Step 1:** write the tests.

Apply to `sandbox/images_test.go`:

```diff
diff --git a/sandbox/images_test.go b/sandbox/images_test.go
index 8560246..1c94101 100644
--- a/sandbox/images_test.go
+++ b/sandbox/images_test.go
@@ -3,6 +3,7 @@ package sandbox
 import (
 	"context"
 	"encoding/json"
+	"errors"
 	"strings"
 	"testing"
 )
@@ -61,3 +62,34 @@ func TestBuildPullsWithIsolatedAuthThenBuildsNeverPulling(t *testing.T) {
 		t.Error("a build ran before the pulls")
 	}
 }
+
+const builtStack = "localhost/ygg-stack-midgard-react:0123456789ab"
+
+func TestBuildStartsFromABuiltStackWithoutPullingIt(t *testing.T) {
+	d, log, _ := fakeEngine(t)
+	imgs, err := d.Build(context.Background(), builtStack)
+	if err != nil {
+		t.Fatal(err)
+	}
+	got := logOf(t, log)
+	if strings.Contains(got, "podman pull -q --authfile "+d.auth+"/auth.json "+builtStack) {
+		t.Errorf("a stack built here was pulled from a registry:\n%s", got)
+	}
+	for _, want := range []string{"podman image exists " + builtStack, "podman pull -q --authfile " + d.auth + "/auth.json " + NodeImage,
+		"STACK_IMAGE=" + builtStack, "--pull=never --target work -t " + imgs.Work} {
+		if !strings.Contains(got, want) {
+			t.Errorf("the engine calls lack %q:\n%s", want, got)
+		}
+	}
+}
+
+func TestBuildRefusesABuiltStackThatWasNotBuilt(t *testing.T) {
+	d, log, _ := fakeEngine(t)
+	t.Setenv("STUB_MISSING", builtStack)
+	if _, err := d.Build(context.Background(), builtStack); !errors.Is(err, ErrNoImage) || !strings.Contains(err.Error(), builtStack) {
+		t.Errorf("Build() = %v; want ErrNoImage naming the stack", err)
+	}
+	if got := logOf(t, log); strings.Contains(got, "podman build") {
+		t.Errorf("the layers were built on a stack that is missing:\n%s", got)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestBuildStartsFromABuiltStackWithoutPullingIt (0.01s)
    images_test.go:76: a stack built here was pulled from a registry:
        podman pull -q --authfile /tmp/TestBuildStartsFromABuiltStackWithoutPullingIt4218548338/002/registry-auth/auth.json docker.io/library/node@sha256:efd0ab5780c2d9ab1f0f869571a00d5edb17793bff4cce4a2792e3eb0ffc7562
        env host=unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock auth=/tmp/TestBuildStartsFromABuiltStackWithoutPullingIt4218548338/002/registry-auth/auth.json docker=/tmp/TestBuildStartsFromABuiltStackWithoutPullingIt4218548338/002/registry-auth tok=
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/images.go`:

```diff
diff --git a/sandbox/images.go b/sandbox/images.go
index 481f510..29aefc6 100644
--- a/sandbox/images.go
+++ b/sandbox/images.go
@@ -71,6 +71,13 @@ func (d *Driver) Build(ctx context.Context, stack string) (Images, error) {
 		}
 	}
 	for _, base := range []string{NodeImage, stack} {
+		if base == stack && !gungnir.ValidImage(stack) {
+			// A stack built from a realm's context is local (BuildStack): there is nothing to pull.
+			if _, err := d.run(ctx, d.Podman, "image", "exists", stack); err != nil {
+				return Images{}, fmt.Errorf("%w: %s (build the realm's stack first)", ErrNoImage, stack)
+			}
+			continue
+		}
 		if _, err := d.run(ctx, d.Podman, "pull", "-q", "--authfile", filepath.Join(d.auth, "auth.json"), base); err != nil {
 			return Images{}, err
 		}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T213: the firewall answers the work container's DNS itself, from the addresses it allows

The firewall allows the addresses its sidecar resolved when it started, and the work container resolved the same names later through the same resolver. A name served from a large pool answers with another address from time to time (the Go proxy and the vulnerability databases are Google's), and then the connection is refused: found on a real engine, when the first Go check of the smoke run failed with `connection refused` to an address the rules did not allow. So the work container is no longer left to ask. Every DNS query of a process that is neither root (the script's own lookups) nor nobody (dnsmasq's) is redirected to a dnsmasq in the sandbox's network namespace, which answers from the addresses the rules allow, asks the services' resolver about the services' names, and answers nothing else. This also closes the DNS channel for the work container (backlog B-025).

**Files (in `gleipnir`):**
- Modify: `sandbox/assets/Containerfile`, `sandbox/assets/egress.sh`, `sandbox/firewall_test.go`, `sandbox/images_test.go`, `sandbox/integration_test.go`

**Interfaces:**
- `egress.sh` writes `$STATE/hosts` ("address host" lines, whole, in one move) and `$STATE/dnsmasq.conf` (port 5353 on 127.0.0.1, `no-resolv`, `no-hosts`, no cache, `addn-hosts`, `server=/<service>/<resolver>` for each service name, `user=nobody`), starts dnsmasq and waits for its pid file before it says it is ready (a firewall that cannot answer never opens), and adds the `nat` rules: RETURN for uid 0 and uid 65534, REDIRECT of UDP and TCP port 53 to 5353 for the rest.
- On a refresh the rules are swapped first and the answers second (`kill -HUP`), so whatever dnsmasq gives out is already allowed. `YGG_MAX_REFRESH` ends the loop after that many refreshes (for tests). The `fw` image installs `dnsmasq-base`.

**Acceptance criteria:**
- [ ] The answers file holds every address of every listed host; dnsmasq's configuration forwards only the services' names; the redirect rules are in place, root and nobody first, before the firewall says it is ready.
- [ ] A firewall whose dnsmasq does not start never says it is ready, and after a refresh the answers are the new address alone and the rules have the new address in the other chain.
- [ ] The older tests of the script (hosts, services, a service that is late, a host that does not resolve) still pass.

**Named test:** `go test ./sandbox -run 'TestEgress'` in `gleipnir`. **Layer:** `gleipnir`. **Size:** M (160). **Depends on:** v0-T212.

- [ ] **Step 1:** write the tests.

Apply to `sandbox/firewall_test.go`:

```diff
diff --git a/sandbox/firewall_test.go b/sandbox/firewall_test.go
index 4d33cf9..9e66915 100644
--- a/sandbox/firewall_test.go
+++ b/sandbox/firewall_test.go
@@ -26,7 +26,17 @@ func stubs(t *testing.T) (bin, log string) {
   postgres) echo "10.89.0.5 STREAM postgres" ;;
   seaweedfs) echo "10.89.0.6 STREAM seaweedfs" ;;
   late) n="$(cat "$STUB_LATE" 2>/dev/null || echo 0)"; echo $((n+1)) > "$STUB_LATE"; [ "$n" -ge 2 ] && echo "10.89.0.7 STREAM late" ;;
+  rotating.example.com) n="$(cat "$STUB_ROTATE" 2>/dev/null || echo 0)"; echo $((n+1)) > "$STUB_ROTATE"; echo "10.0.0.$((n+1)) STREAM rotating.example.com" ;;
 esac
+`)
+	// dnsmasq logs how it was called and the configuration it was given, writes its pid file as the real one
+	// does once it listens, and stays up a moment, or fails to start when STUB_DNSMASQ_FAIL is set.
+	write("dnsmasq", `echo "dnsmasq $*" >> "$STUB_LOG"
+[ -z "$STUB_DNSMASQ_FAIL" ] || exit 1
+conf=""; for a in "$@"; do case "$a" in --conf-file=*) conf="${a#--conf-file=}" ;; esac; done
+sed 's/^/conf: /' "$conf" >> "$STUB_LOG"
+echo "$$" > "$(sed -n 's/^pid-file=//p' "$conf")"
+exec /bin/sleep 2
 `)
 	write("sleep", "exit 0\n")
 	return bin, log
@@ -57,7 +67,7 @@ func runEgressWithServices(t *testing.T, hosts, services string, extra ...string
 		args = append(args, servicesFile)
 	}
 	cmd := exec.Command("sh", args...)
-	cmd.Env = append([]string{"PATH=" + bin + ":" + os.Getenv("PATH"), "STUB_LOG=" + log, "STUB_LATE=" + filepath.Join(dir, "late"),
+	cmd.Env = append([]string{"PATH=" + bin + ":" + os.Getenv("PATH"), "STUB_LOG=" + log, "STUB_LATE=" + filepath.Join(dir, "late"), "STUB_ROTATE=" + filepath.Join(dir, "rotate"),
 		"YGG_FW_STATE=" + state, "YGG_ONCE=1"}, extra...)
 	out, err := cmd.CombinedOutput()
 	if err != nil {
@@ -155,3 +165,68 @@ func TestEgressRefusesToOpenWithoutAService(t *testing.T) {
 		t.Error("a failed firewall said it was ready")
 	}
 }
+
+func TestEgressAnswersDNSItselfForTheListedHostsAndTheServicesAndNothingElse(t *testing.T) {
+	calls, state, err := runEgressWithServices(t, "api.anthropic.com\nproxy.golang.org\n", "postgres 5432\n")
+	if err != nil {
+		t.Fatal(err)
+	}
+	hosts, _ := os.ReadFile(filepath.Join(state, "hosts"))
+	for _, want := range []string{"160.79.104.10 api.anthropic.com\n", "142.250.1.1 proxy.golang.org\n", "142.250.1.2 proxy.golang.org\n"} {
+		if !strings.Contains(string(hosts), want) {
+			t.Errorf("the answers lack %q:\n%s", want, hosts)
+		}
+	}
+	for _, want := range []string{"conf: port=5353\n", "conf: listen-address=127.0.0.1\n", "conf: no-resolv\n", "conf: no-hosts\n", "conf: cache-size=0\n",
+		"conf: addn-hosts=" + filepath.Join(state, "hosts") + "\n", "conf: server=/postgres/10.89.0.1\n", "conf: user=nobody\n"} {
+		if !strings.Contains(calls, want) {
+			t.Errorf("dnsmasq's configuration lacks %q:\n%s", want, calls)
+		}
+	}
+	if strings.Contains(calls, "conf: server=/api.anthropic.com") || strings.Contains(calls, "server=10.89.0.1") {
+		t.Errorf("dnsmasq forwards more than the services' names:\n%s", calls)
+	}
+	// What the work container asks is answered here: every DNS query of a process that is neither root (the
+	// script's own lookups) nor nobody (dnsmasq's) goes to dnsmasq's port.
+	for _, want := range []string{
+		"iptables -t nat -A OUTPUT -p udp --dport 53 -m owner --uid-owner 0 -j RETURN",
+		"iptables -t nat -A OUTPUT -p udp --dport 53 -m owner --uid-owner 65534 -j RETURN",
+		"iptables -A OUTPUT -p udp -d 127.0.0.1 --dport 5353 -j ACCEPT",
+		"iptables -A OUTPUT -p tcp -d 127.0.0.1 --dport 5353 -j ACCEPT",
+		"iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353",
+		"iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 5353",
+	} {
+		if !strings.Contains(calls, want+"\n") {
+			t.Errorf("the rules lack %q:\n%s", want, calls)
+		}
+	}
+	if _, err := os.Stat(filepath.Join(state, "ready")); err != nil {
+		t.Error("the firewall never said it was ready")
+	}
+}
+
+func TestEgressRefusesToOpenWhenItCannotAnswerDNS(t *testing.T) {
+	_, state, err := runEgress(t, "api.anthropic.com\n", "STUB_DNSMASQ_FAIL=1")
+	if err == nil {
+		t.Fatal("egress.sh succeeded without a resolver for the work container")
+	}
+	if _, err := os.Stat(filepath.Join(state, "ready")); err == nil {
+		t.Error("a firewall with no resolver said it was ready")
+	}
+}
+
+func TestEgressAnswersWhatItAllowsAfterARefreshToo(t *testing.T) {
+	calls, state, err := runEgress(t, "rotating.example.com\n", "YGG_ONCE=0", "YGG_MAX_REFRESH=1")
+	if err != nil {
+		t.Fatal(err)
+	}
+	hosts, _ := os.ReadFile(filepath.Join(state, "hosts"))
+	if string(hosts) != "10.0.0.2 rotating.example.com\n" {
+		t.Errorf("after a refresh the answers are %q, want the new address alone", hosts)
+	}
+	for _, want := range []string{"iptables -A YGG_HOSTS_A -p tcp -d 10.0.0.1 --dport 443 -j ACCEPT\n", "iptables -A YGG_HOSTS_B -p tcp -d 10.0.0.2 --dport 443 -j ACCEPT\n"} {
+		if !strings.Contains(calls, want) {
+			t.Errorf("the rules lack %q:\n%s", want, calls)
+		}
+	}
+}
```

Apply to `sandbox/images_test.go`:

```diff
diff --git a/sandbox/images_test.go b/sandbox/images_test.go
index 1c94101..b4a5800 100644
--- a/sandbox/images_test.go
+++ b/sandbox/images_test.go
@@ -30,7 +30,7 @@ func TestTheFactoryLayerIsPinned(t *testing.T) {
 	if !strings.Contains(NodeImage, "@sha256:") || len(GitleaksSHA256) != 64 {
 		t.Error("a base image or the gitleaks archive isn't pinned by digest")
 	}
-	for _, want := range []string{"sha256sum -c", "npm install -g --prefix /opt/ygg", "DISABLE_AUTOUPDATER=1", "AS fw", "AS work",
+	for _, want := range []string{"sha256sum -c", "npm install -g --prefix /opt/ygg", "DISABLE_AUTOUPDATER=1", "AS fw", "AS work", "iptables dnsmasq-base",
 		"the stack image needs bash, timeout and git"} {
 		if !strings.Contains(containerfile, want) {
 			t.Errorf("the Containerfile lacks %q", want)
```

Apply to `sandbox/integration_test.go`:

```diff
diff --git a/sandbox/integration_test.go b/sandbox/integration_test.go
index c65492e..3a3c0c6 100644
--- a/sandbox/integration_test.go
+++ b/sandbox/integration_test.go
@@ -156,7 +156,9 @@ func TestSandboxDriverOnARealEngine(t *testing.T) {
 	})
 	t.Run("the network is closed but for the listed hosts", func(t *testing.T) {
 		want("an open address", 124, "", "timeout", "4", "bash", "-c", "exec 3<>/dev/tcp/1.1.1.1/443")
-		want("example.com", 124, "", "timeout", "4", "bash", "-c", "exec 3<>/dev/tcp/example.com/80")
+		// A name that is not listed does not resolve at all: the firewall's resolver answers only the listed
+		// hosts and the services (change realm-content), so there is not even an address to connect to.
+		want("example.com", 2, "", "timeout", "4", "getent", "hosts", "example.com")
 		want("a listed host", 0, "", "timeout", "10", "bash", "-c", "exec 3<>/dev/tcp/api.anthropic.com/443")
 		want("a listed host's other port", 124, "", "timeout", "4", "bash", "-c", "exec 3<>/dev/tcp/api.anthropic.com/80")
 	})
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestEgressAnswersDNSItselfForTheListedHostsAndTheServicesAndNothingElse (0.02s)
    firewall_test.go:177: the answers lack "160.79.104.10 api.anthropic.com\n":
    firewall_test.go:177: the answers lack "142.250.1.1 proxy.golang.org\n":
    firewall_test.go:177: the answers lack "142.250.1.2 proxy.golang.org\n":
```

- [ ] **Step 3:** write the code.

Apply to `sandbox/assets/Containerfile`:

```diff
diff --git a/sandbox/assets/Containerfile b/sandbox/assets/Containerfile
index 5c0f2d0..15af22b 100644
--- a/sandbox/assets/Containerfile
+++ b/sandbox/assets/Containerfile
@@ -1,7 +1,8 @@
 # The factory layer of a leaf's sandbox (spec §6.1). Two targets:
 #   work  the realm's stack image, plus the agent CLIs pinned to exact versions, gitleaks, and
 #         managed settings; it holds no credential and no auto-update.
-#   fw    the firewall sidecar: iptables and nothing else of the stack.
+#   fw    the firewall sidecar: iptables, dnsmasq (it answers the work container's DNS queries, see egress.sh)
+#         and nothing else of the stack.
 # Built by the driver with isolated registry auth and --pull=never, after it pulled the bases by digest.
 ARG NODE_IMAGE
 ARG STACK_IMAGE
@@ -21,7 +22,7 @@ RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certifi
  && cp /usr/local/bin/node /opt/ygg/bin/node
 
 FROM ${NODE_IMAGE} AS fw
-RUN apt-get update && apt-get install -y --no-install-recommends iptables \
+RUN apt-get update && apt-get install -y --no-install-recommends iptables dnsmasq-base \
  && rm -rf /var/lib/apt/lists/*
 
 FROM ${STACK_IMAGE} AS work
```

Apply to `sandbox/assets/egress.sh`:

```diff
diff --git a/sandbox/assets/egress.sh b/sandbox/assets/egress.sh
index 70db0ab..f136b56 100644
--- a/sandbox/assets/egress.sh
+++ b/sandbox/assets/egress.sh
@@ -9,10 +9,18 @@
 # Names are resolved to addresses, so the script resolves them again every
 # YGG_REFRESH seconds (default 300) and swaps the rules in without a gap. Without a resolvable
 # host at the start it exits 1, so the sandbox never opens half closed.
+#
+# The work container asks the same resolver the firewall asked, and a name served from a large pool (the Go
+# proxy and the vulnerability databases are Google's) answers with another address from time to time, which
+# the rules would not allow. So the work container is not left to ask: every DNS query of a process that is
+# neither root (this script's own lookups) nor nobody (dnsmasq's) is redirected to a dnsmasq in this
+# namespace, which answers from the addresses the rules allow, forwards the names of the services to the
+# resolver that knows them, and answers nothing else. The rules are swapped before the answers change.
 set -eu
 HOSTS="${1:?usage: egress.sh HOSTS [SERVICES]}"
 SERVICES="${2:-}"
 WAIT="${YGG_SERVICE_WAIT:-30}"
+DNSPORT=5353
 STATE="${YGG_FW_STATE:-/run/ygg-fw}"
 REFRESH="${YGG_REFRESH:-300}"
 mkdir -p "$STATE"
@@ -20,13 +28,13 @@ mkdir -p "$STATE"
 ns="$(awk '/^nameserver/ { print $2; exit }' /etc/resolv.conf)"
 [ -n "$ns" ] || { echo "egress: no nameserver in /etc/resolv.conf" >&2; exit 1; }
 
-# resolve prints the IPv4 addresses of every host, one per line, or fails on a host with none.
+# resolve prints "address host" for every IPv4 address of every host, one per line, or fails on a host with none.
 resolve() {
   while read -r host; do
     [ -n "$host" ] || continue
     found="$(getent ahostsv4 "$host" | awk '{ print $1 }' | sort -u)"
     [ -n "$found" ] || { echo "egress: $host does not resolve" >&2; return 1; }
-    echo "$found"
+    for ip in $found; do echo "$ip $host"; done
   done < "$HOSTS"
 }
 
@@ -61,11 +69,61 @@ base() {
   done
   iptables -A OUTPUT -p udp -d "$ns" --dport 53 -j ACCEPT
   iptables -A OUTPUT -p tcp -d "$ns" --dport 53 -j ACCEPT
+  # A process that is not root and not nobody asks dnsmasq, not the resolvers. The kernel keeps the output
+  # interface of the route the packet had before its destination changed, so the filter does not see the
+  # redirected query as loopback traffic, and the query to dnsmasq is allowed by its address and port.
+  iptables -t nat -F OUTPUT
+  for proto in udp tcp; do
+    iptables -A OUTPUT -p "$proto" -d 127.0.0.1 --dport "$DNSPORT" -j ACCEPT
+    iptables -t nat -A OUTPUT -p "$proto" --dport 53 -m owner --uid-owner 0 -j RETURN
+    iptables -t nat -A OUTPUT -p "$proto" --dport 53 -m owner --uid-owner 65534 -j RETURN
+    iptables -t nat -A OUTPUT -p "$proto" --dport 53 -j REDIRECT --to-ports "$DNSPORT"
+  done
+}
+
+# answers writes the addresses dnsmasq gives for the allowed hosts ("address host" lines), whole, in one move.
+answers() {
+  printf '%s\n' "$1" > "$STATE/hosts.new"
+  mv "$STATE/hosts.new" "$STATE/hosts"
+}
+
+# dns_conf writes dnsmasq's configuration: it answers from the file of addresses and from nothing else but the
+# services' names, which it asks the resolver that knows them.
+dns_conf() {
+  {
+    echo "port=$DNSPORT"
+    echo "listen-address=127.0.0.1"
+    echo "bind-interfaces"
+    echo "no-resolv"
+    echo "no-hosts"
+    echo "cache-size=0"
+    echo "local-ttl=5"
+    echo "user=nobody"
+    echo "pid-file=$STATE/dnsmasq.pid"
+    echo "addn-hosts=$STATE/hosts"
+    if [ -n "$SERVICES" ] && [ -s "$SERVICES" ]; then
+      awk '{ print $1 }' "$SERVICES" | sort -u | while read -r name; do
+        [ -n "$name" ] && echo "server=/$name/$ns"
+      done
+    fi
+  } > "$STATE/dnsmasq.conf"
+}
+
+# start_dns starts dnsmasq and waits until it says it is listening (its pid file), or gives up.
+start_dns() {
+  rm -f "$STATE/dnsmasq.pid"
+  dnsmasq --keep-in-foreground --conf-file="$STATE/dnsmasq.conf" >&2 &
+  tries=0
+  while [ ! -s "$STATE/dnsmasq.pid" ]; do
+    tries=$((tries + 1))
+    if [ "$tries" -ge 10 ] || ! kill -0 "$!" 2>/dev/null; then echo "egress: dnsmasq did not start" >&2; return 1; fi
+    sleep 1
+  done
 }
 
 # apply swaps in a fresh chain of host rules: the new chain is reachable before the old one goes.
 apply() {
-  addrs="$1"
+  addrs="$(printf '%s\n' "$1" | awk '{ print $1 }' | sort -u)"
   svc="$2"
   old="$(cat "$STATE/chain" 2>/dev/null || true)"
   if [ "$old" = YGG_HOSTS_A ]; then new=YGG_HOSTS_B; else new=YGG_HOSTS_A; fi
@@ -87,12 +145,25 @@ EOF
   echo "$new" > "$STATE/chain"
 }
 
-addrs="$(resolve)"
+hosts="$(resolve)"
 svcs="$(resolve_services)"
 base
-apply "$addrs" "$svcs"
+apply "$hosts" "$svcs"
+answers "$hosts"
+dns_conf
+start_dns
 touch "$STATE/ready"
 [ "${YGG_ONCE:-}" = 1 ] && exit 0
+n=0
 while sleep "$REFRESH"; do
-  if addrs="$(resolve)" && svcs="$(resolve_services)"; then apply "$addrs" "$svcs"; else echo "egress: keeping the earlier addresses" >&2; fi
+  # The rules are swapped first, then the answers: whatever dnsmasq gives out is already allowed.
+  if hosts="$(resolve)" && svcs="$(resolve_services)"; then
+    apply "$hosts" "$svcs"
+    answers "$hosts"
+    kill -HUP "$(cat "$STATE/dnsmasq.pid")"
+  else
+    echo "egress: keeping the earlier addresses" >&2
+  fi
+  n=$((n + 1))
+  [ "$n" -ne "${YGG_MAX_REFRESH:--1}" ] || exit 0
 done
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T214: integration tests of a built stack, a service's command and the firewall's DNS, behind the sandbox tag

Things only a real engine can show: a leaf started on a stack built from a context sees the check scripts baked into it and cannot change them; a service takes the command it was given and a sandbox that has one still reaches the hosts its leaf may and nothing else; and the work container resolves the allowed hosts and the services and nothing else, to addresses it can connect to. Like Phase 5a's v0-T162, the tests are behind the `sandbox` build tag and skip without an engine; v0-H14 runs them. They were run for this plan on rootless Podman, and the DNS one is what showed v0-T213 was needed.

**Files (in `gleipnir`):**
- Create: `sandbox/integration_stack_test.go`

**Acceptance criteria:**
- [ ] `go vet -tags sandbox ./...` is clean.
- [ ] With an engine: a stack built from a context with a script is built once and not again, a leaf started on it runs the script and cannot write to it; a service started with a command is reachable on its port, `proxy.golang.org` is reachable from the same sandbox and `1.1.1.1` is not; the service's name and the listed hosts resolve to addresses the rules allow, and `example.com` does not resolve.

**Named test:** `go vet -tags sandbox ./sandbox; and, on an engine, go test -tags sandbox -run 'TestSandboxBuildsARealmsStackAndStartsALeafOnIt|TestASandboxServiceTakesTheCommandItWasGiven|TestSandboxAnswersDNSForTheListedHostsAndTheServicesOnly' ./sandbox` in `gleipnir`. **Layer:** `gleipnir`. **Size:** M (130). **Depends on:** v0-T213.

- [ ] **Step 1:** write the tests.

Write `sandbox/integration_stack_test.go`:

```go
//go:build sandbox

package sandbox

// Integration tests of a realm's built stack and of a service's command on a real engine (spec §13), with
// the same environment as TestSandboxDriverOnARealEngine. The second test needs an image that serves
// when told to, pinned by digest; set
//
//	YGG_SANDBOX_COMMAND_IMAGE   such as docker.io/library/busybox:1.37@sha256:<digest>
//
// then run: go test -tags sandbox -run 'TestSandboxBuilds|TestASandboxServiceTakes' -v -timeout 40m ./sandbox

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

func TestSandboxBuildsARealmsStackAndStartsALeafOnIt(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 35*time.Minute)
	defer cancel()
	d, tree := itDriver(t, ctx)
	dir := t.TempDir()
	for name, body := range map[string]string{
		"Containerfile":   "FROM " + itStack + "\nCOPY checks/ /opt/ygg/checks/\n",
		"checks/hello.sh": "#!/bin/sh\necho hello from the stack\n",
	} {
		if err := os.MkdirAll(filepath.Dir(filepath.Join(dir, name)), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, name), []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	hash, err := schema.StackHash(dir, "")
	if err != nil {
		t.Fatal(err)
	}
	ref := gungnir.LocalStack("it-realm", hash)
	if _, err := d.BuildStack(ctx, ref, dir, ""); err != nil {
		t.Fatalf("BuildStack() = %v", err)
	}
	if built, err := d.BuildStack(ctx, ref, dir, ""); err != nil || built {
		t.Errorf("a second BuildStack() = %v, %v; the image is there", built, err)
	}
	if _, err := d.Build(ctx, ref); err != nil {
		t.Fatalf("Build() = %v", err)
	}
	spec := itTree(t, tree)
	spec.Stack = ref
	env, err := d.Up(ctx, spec)
	if err != nil {
		t.Fatalf("Up() = %v", err)
	}
	t.Cleanup(func() { d.Down(context.Background(), env) })
	if code, out := inSandbox(t, ctx, d, env, "/opt/ygg/checks/hello.sh"); code != 0 || !strings.Contains(out, "hello from the stack") {
		t.Errorf("the check script of the stack: exit %d, %q", code, out)
	}
	if code, _ := inSandbox(t, ctx, d, env, "sh", "-c", "echo weaker >> /opt/ygg/checks/hello.sh"); code == 0 {
		t.Error("the work container's user rewrote a check script baked into the stack")
	}
}

func TestASandboxServiceTakesTheCommandItWasGiven(t *testing.T) {
	image := os.Getenv("YGG_SANDBOX_COMMAND_IMAGE")
	if image == "" {
		t.Skip("set YGG_SANDBOX_COMMAND_IMAGE to run this test")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 35*time.Minute)
	defer cancel()
	d, tree := itDriver(t, ctx)
	spec := itTree(t, tree)
	spec.Services = []gungnir.Service{{Name: "web", Image: image, Ports: []int{8080}, Command: []string{"httpd", "-f", "-p", "8080"}}}
	env, err := d.Up(ctx, spec)
	if err != nil {
		t.Fatalf("Up() = %v", err)
	}
	t.Cleanup(func() { d.Down(context.Background(), env) })
	if code, out := inSandbox(t, ctx, d, env, "timeout", "6", "bash", "-c", "exec 3<>/dev/tcp/web/8080"); code != 0 {
		t.Errorf("the service started with the command it was given: reaching web:8080 gave exit %d (%s)", code, out)
	}
	// A sandbox with a service still reaches the hosts its leaf may (the Go proxy is on the spec's list), and
	// still nothing else: the services network is internal, and the default route must not lead into it.
	if code, out := inSandbox(t, ctx, d, env, "timeout", "10", "bash", "-c", "exec 3<>/dev/tcp/proxy.golang.org/443"); code != 0 {
		t.Errorf("a host on the egress list is not reachable from a sandbox that has a service: exit %d (%s)", code, out)
	}
	if code, _ := inSandbox(t, ctx, d, env, "timeout", "6", "bash", "-c", "exec 3<>/dev/tcp/1.1.1.1/443"); code == 0 {
		t.Error("a host that is not on the egress list is reachable")
	}
}

// A name from a large pool (the Go proxy and the vulnerability databases are Google's) answers with another
// address from time to time. The work container's queries go to the firewall's dnsmasq, which answers from
// the addresses the rules allow, so what it resolves it can connect to, and it resolves nothing else.
func TestSandboxAnswersDNSForTheListedHostsAndTheServicesOnly(t *testing.T) {
	image := os.Getenv("YGG_SANDBOX_COMMAND_IMAGE")
	if image == "" {
		t.Skip("set YGG_SANDBOX_COMMAND_IMAGE to run this test")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 35*time.Minute)
	defer cancel()
	d, tree := itDriver(t, ctx)
	spec := itTree(t, tree)
	spec.Egress = []string{"proxy.golang.org", "api.anthropic.com"}
	spec.Services = []gungnir.Service{{Name: "web", Image: image, Ports: []int{8080}, Command: []string{"httpd", "-f", "-p", "8080"}}}
	env, err := d.Up(ctx, spec)
	if err != nil {
		t.Fatalf("Up() = %v", err)
	}
	t.Cleanup(func() { d.Down(context.Background(), env) })
	if code, out := inSandbox(t, ctx, d, env, "getent", "hosts", "web"); code != 0 || out == "" {
		t.Errorf("the service's name does not resolve: exit %d (%s)", code, out)
	}
	for _, host := range spec.Egress {
		if code, out := inSandbox(t, ctx, d, env, "timeout", "10", "bash", "-c", "exec 3<>/dev/tcp/"+host+"/443"); code != 0 {
			t.Errorf("%s resolves to an address the rules do not allow: exit %d (%s)", host, code, out)
		}
	}
	for _, host := range []string{"example.com", "github.com"} {
		if code, out := inSandbox(t, ctx, d, env, "timeout", "10", "getent", "hosts", host); code == 0 {
			t.Errorf("%s resolves although it is not on the list: %s", host, out)
		}
	}
}
```

- [ ] **Step 2:** run the named test. It passes at once, because the code or data it needs is already there (or the test is skipped without its build tag): expect `ok`.

- [ ] **Step 3:** run the named test. Expect `ok`.

- [ ] **Step 4:** commit (see "How each task lands").

---

### Task v0-T215: Gleipnir's documentation

The architecture page says what Gleipnir now does.

**Files (in `gleipnir`):**
- Modify: `docs/architecture.md`

**Acceptance criteria:**
- [ ] `docs/architecture.md` says that Gleipnir builds a realm's stack from pinned inputs only and that a service may take a command.

**Named test:** `git diff --stat -- docs/architecture.md` in `gleipnir`. **Layer:** `gleipnir`. **Size:** S (7). **Depends on:** v0-T214.

- [ ] **Step 1:** write the code.

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index ed6fb3a..3853b31 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -19,10 +19,16 @@ The harness: agent adapters, the devcontainer sandbox driver, policies and the c
   the egress firewall (spec §6).
 - Starts, beside the work container, the services a leaf's realm and the realms of the leaves it
   consumes ask for (a database, object storage), and opens their ports, and only theirs, to the work
-  container through the firewall. The services sit on an internal network with no route out, which the
+  container through the firewall. The firewall also answers the work container's DNS queries itself, from
+  the addresses it allows, so a name served from a large pool never resolves to an address the rules do
+  not allow; it resolves nothing but the allowed hosts and the services' names. The services sit on an internal network with no route out, which the
   firewall joins, so none of them can reach the internet for a client. Each sandbox starts on the stack layer its spec names, so leaves of
   different realms differ. A scratch sandbox holds one folder and no git directory: a planner's
   workspace (spec §3.3).
+- Builds a realm's stack from the realm's build context (`BuildStack`, for `ygg sandbox build`): only
+  from images pinned by digest and the Containerfile's own stages, with the isolated registry auth, and
+  tagged with a hash of the context. The check scripts a realm bakes into its stack are read-only for the
+  agent. A service may take the command its pack gives it, for an image that does nothing without one.
 - Runs checks.
 
 ## Depends on
```

- [ ] **Step 2:** run the named test. Expect `ok`.

- [ ] **Step 3:** commit (see "How each task lands").

---

### Task v0-T216: vendor Ponytail's ponytail-review at a pinned commit, for the simplicity reviewer

Havamal's only task. Branch `skills/ponytail` from `main` in `havamal`, before step 1. The plan's reuse review and the task loop's simplicity reviewer load Ponytail's `ponytail-review` skill (spec-driven development §8; the founder chose to keep it, 2026-10-17). It is vendored, never installed: a pinned, reviewed copy of one commit of the public upstream, under its licence (MIT, already listed in the writing styles). The skill is instructions an agent follows, so the diff of this task is the part a person must read.

**Files (in `havamal`):**
- Create: `ponytail_test.go`, `skills/ponytail-review/LICENSE`, `skills/ponytail-review/SKILL.md`
- Modify: `skills.lock`

**Interfaces:**
- `havamal vendor` copies `skills/ponytail-review/` of `https://github.com/DietrichGebert/ponytail` at commit `16352ac229eb08a9598dcae48fe9f2b342567d86` (release 5.3.2, 2026-10-17) into `skills/ponytail-review/` with its licence, and records the upstream, the commit, the licence and the SHA-256 of each file in `skills.lock`.
- `havamal.Embedded()` opens the library, so `Get("ponytail-review")` returns it.

**Acceptance criteria:**
- [ ] The skill is vendored from that commit: `SKILL.md` has the SHA-256 `33fe4ebe22a460924e5d4a261e223df22e409cc94ab76182bee9fb91a3ef022e` and `LICENSE` has `fb1bc6909ac3ef82d5c22106e32ef682b0cff66788fa915fb9b53b15c9d2f3ab`.
- [ ] `go run ./cmd/havamal check .` says the library is as locked, and the test reads the entry (MIT, the upstream's public URL at one full commit).

**Named test:** `go test . -run 'TestThePonytailReviewIsVendoredAtAPinnedCommitUnderItsLicence'` in `havamal`. **Layer:** `havamal`. **Size:** M (177). **Depends on:** Phase 5a.

- [ ] **Step 1:** write the tests.

Write `ponytail_test.go`:

```go
package havamal

import (
	"strings"
	"testing"
)

// The factory's reviewers load the simplicity review of Ponytail (spec §9.5 rung 6, spec-driven
// development §8). It is vendored, not installed: a pinned, reviewed copy of one commit.
func TestThePonytailReviewIsVendoredAtAPinnedCommitUnderItsLicence(t *testing.T) {
	lib, err := Embedded()
	if err != nil {
		t.Fatalf("Embedded() = %v; the library has drifted from its lock", err)
	}
	got, err := lib.Get("ponytail-review")
	if err != nil {
		t.Fatalf("Get(ponytail-review) = %v", err)
	}
	e := got.Entry
	if e.Own || e.Licence != "MIT" || e.Upstream == nil || e.Upstream.Repo != "https://github.com/DietrichGebert/ponytail" ||
		e.Upstream.Path != "skills/ponytail-review" || e.Upstream.Commit != "16352ac229eb08a9598dcae48fe9f2b342567d86" {
		t.Errorf("entry = %+v; want the upstream's public URL at one full commit, under MIT", e)
	}
	var paths []string
	for _, f := range e.Files {
		paths = append(paths, f.Path)
	}
	if !strings.Contains(strings.Join(paths, " "), "LICENSE") {
		t.Errorf("the vendored files %v lack the upstream's licence", paths)
	}
	if !strings.Contains(got.Body, "Lists findings, changes no code.") {
		t.Error("the skill's text is not the one that was reviewed")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestThePonytailReviewIsVendoredAtAPinnedCommitUnderItsLicence (0.00s)
    ponytail_test.go:17: Get(ponytail-review) = no skill "ponytail-review"
FAIL
FAIL	github.com/ouroboric-dev/havamal	0.245s
```

- [ ] **Step 3:** write the code.

Apply to `skills.lock`:

```diff
diff --git a/skills.lock b/skills.lock
index 7f60485..a5c662a 100644
--- a/skills.lock
+++ b/skills.lock
@@ -1,4 +1,24 @@
 {
   "schema": "ygg.skills-lock/v1",
-  "skills": []
+  "skills": [
+    {
+      "name": "ponytail-review",
+      "upstream": {
+        "repo": "https://github.com/DietrichGebert/ponytail",
+        "path": "skills/ponytail-review",
+        "commit": "16352ac229eb08a9598dcae48fe9f2b342567d86"
+      },
+      "licence": "MIT",
+      "files": [
+        {
+          "path": "LICENSE",
+          "sha256": "fb1bc6909ac3ef82d5c22106e32ef682b0cff66788fa915fb9b53b15c9d2f3ab"
+        },
+        {
+          "path": "SKILL.md",
+          "sha256": "33fe4ebe22a460924e5d4a261e223df22e409cc94ab76182bee9fb91a3ef022e"
+        }
+      ]
+    }
+  ]
 }
```

Write `skills/ponytail-review/LICENSE`:

```text
MIT License

Copyright (c) 2026 DietrichGebert

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Write `skills/ponytail-review/SKILL.md`:

```md
---
name: ponytail-review
description: >
  Quality review of a change: is the logic right, is it safe, does it hold
  under real load, is risky code tested, is it fast enough, and is every line
  needed. Reads the connected code, not only the diff. Each finding is
  explained in plain English. Use for "review this", "code review", "review
  the last commit", "review my PR", "is this over-engineered", /ponytail-review.
---

Review a change like the senior developer who will be paged when it breaks.
Order of importance: correct, safe, holds under load, tested, fast, lean.
Lean still matters: every extra line must be read, tested and fixed later.
This is a report the user asked for, so give it in full.

## 1. Understand first

- Review what the user names: uncommitted or staged changes, a branch, a PR
  link, or files. Nothing named: the uncommitted changes, or the last commit
  if there are none.
- Read the diff, then the code it touches: callers of every changed function,
  the functions it calls, the tests, the README.
- Trace the real flow: where data comes in, what is stored, what goes out.
- A change can break code it does not touch. When a signature, return value
  or behavior changes, grep every caller.
- Find the expected load in the repo (README, deploy config): one person
  running a script, or many users and processes at once. Judge scale against
  that, and say which load you assumed.

## 2. Look for

1. **Bug:** wrong result, crash, missed edge case (empty, zero, last item,
   rounding, time zones), a caller broken by the change, a fix applied in one
   caller while the shared function stays broken.
2. **Risk:** security holes (injection, weak randomness, secrets, missing
   checks on input from users), data loss (errors swallowed, writes in the
   wrong order, no transaction).
3. **Scale:** fine for one user, wrong for many: check-then-write races, the
   same work done by every process, memory or lists that only grow, a query
   per item, O(n^2) on big input, per-process state that must be shared.
4. **Missing test:** risky new logic (a branch, a parser, money, security,
   data writes, a bug fix) with no test that fails when it breaks. One good
   test, not coverage.
5. **Speed:** big slowdowns are problems. Small wins (work repeated in a hot
   loop) are suggestions; some software counts every millisecond.
6. **Lean:** code that should not exist or should be smaller.
   - delete: dead code, unused options, speculative features
   - reuse: the repo already has this helper (name the path)
   - stdlib / native: the standard library or platform already does it; a
     new dependency for a few lines
   - yagni: abstraction with one implementation, config nobody sets
   - merge: near-copies that must change together
   - split: one function doing several unrelated jobs, so it is hard to read
     or test. Split by job, never by line count, and never into helpers that
     exist only to make a function shorter.

## 3. Check before you report

- Every finding needs a concrete case: "this input or situation leads to this
  wrong result". No case, no finding.
- Re-read the lines and confirm: the caller exists, the value can really be
  empty, the code really is unused.
- A shortcut marked with a `shortcut:` (or older `ponytail:`) comment that names its limit is a
  decision, not a finding, unless the expected load already crosses it.
- Propose the smallest fix that works. Prefer fixes that delete code. Never
  add layers, frameworks or config the problem does not need.
- No style taste, no "consider", no vague worries.

## 4. Output

Very simple English: short sentences, everyday words. Explain a technical
term the first time you use it. The reader may never have seen this code.

Start with `What this change does:` in two or three sentences.

Then the findings in three groups, skip empty groups:
- **Must fix:** bug, security, data loss, breaks at the expected load.
- **Should fix:** risky code without a test, real slowness, duplication, a
  function that mixes jobs, code that should not exist.
- **Nice to have:** small speed-ups, shorter forms.

Number findings across all groups, so the user can say "fix 2 and 5".
Every finding has all four parts, each one or two short sentences:

2. **Orders land on the wrong day** (`billing/close_day.py:L40-52`)
   - **What this is:** At midnight this job closes the day and bills all orders of that day.
   - **Problem:** It takes "today" from the server clock, which runs in UTC. An order placed
     at 00:30 in Berlin is billed on the day before.
   - **Fix:** Compute the day once in the shop's time zone:
     `datetime.now(ZoneInfo("Europe/Berlin")).date()`. One line, nothing else changes.
   - **If we skip it:** Late orders show the wrong date, and accounting fixes them by hand.

End with:
- `Verdict: Ship.` or `Verdict: fix 1 and 3 first.`
- `Lean: -<N> lines possible.` when lean findings exist.
- `Not checked:` one line, if something mattered and you could not check it.

Nothing found: `What this change does:`, then `Looks good. Ship.` and one line
on what you checked.

Lists findings, changes no code.
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T217: the Go API template: a server with a health route, its contract, its tests, and the rules for working in it

helheim-go's first task. Branch `realm/content` from `main` in `helheim-go`, before step 1. A new API leaf starts from this template (`init` copies it, spec §4.2). It is small and real: it builds, passes its own checks, and holds the habits the ladder expects of a leaf: a contract the code is described by, tests first, standard library first, JSON errors that leak nothing. The template is MIT so a product may license it as it likes. Its tests run in a copy of the folder, as a product would have it.

**Files (in `helheim-go`):**
- Create: `template_test.go`, `templates/api/.devcontainer/devcontainer.json`, `templates/api/.gitignore`, `templates/api/.golangci.yml`, `templates/api/AGENTS.md`, `templates/api/LICENSE`, `templates/api/cmd/api/main.go`, `templates/api/cmd/api/main_test.go`, `templates/api/go.mod`, `templates/api/init.sh`, `templates/api/internal/httpapi/server.go`, `templates/api/internal/httpapi/server_test.go`, `templates/api/openapi.yaml`

**Interfaces:**
- Produces: `templates/api`, a Go module named `api`: `cmd/api` (the program: `PORT`, graceful shutdown), `internal/httpapi` (`New() http.Handler` with `GET /healthz` answering `{"status":"ok"}`, a 405 with `Allow` for another method and a 404 with a JSON body), `openapi.yaml`, `.golangci.yml` (standard linters plus `gosec`, `errorlint` and `bodyclose`), `AGENTS.md` (under 100 lines), `init.sh`, `LICENSE` (MIT) and a `.devcontainer/devcontainer.json` that only names the image.
- A catch-all route would answer a wrong method on a known path with 404, so `only(method, handler)` answers 405 itself (found by the test). `PORT` is checked to be a whole number from 1 to 65535 before it is logged or used (`gosec` G706).

**Acceptance criteria:**
- [ ] `go vet` and `go test -race` pass in a copy of the template, and `gofmt -l` prints nothing.
- [ ] `GET /healthz` is 200 with the JSON status; `POST /healthz` is 405; an unknown path is a JSON 404; a bad `PORT` is an error.
- [ ] The template carries a licence that starts "MIT License", an `AGENTS.md` of at most 100 lines, `init.sh`, `openapi.yaml`, and a `devcontainer.json` that sets none of the keys that run or widen something when a person opens the repo.

**Named test:** `go test . -run 'TestTheAPITemplateBuildsAndPassesItsOwnChecks|TestATemplateCarriesWhatARepoOfTheFactoryNeeds'` in `helheim-go`. **Layer:** `helheim-go`. **Size:** M (335). **Depends on:** Phase 5a.

- [ ] **Step 1:** write the tests.

Write `template_test.go`:

```go
package helheim

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// copyTemplate copies templates/<name> into a temp dir, where it is a module of its own, as it is in a
// product.
func copyTemplate(t *testing.T, name string) string {
	t.Helper()
	dst := t.TempDir()
	if err := os.CopyFS(dst, os.DirFS(filepath.Join("templates", name))); err != nil {
		t.Fatalf("templates/%s: %v", name, err)
	}
	return dst
}

func toolIn(t *testing.T, dir, tool string, args ...string) string {
	t.Helper()
	cmd := exec.Command(tool, args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GOFLAGS=-mod=mod", "GOWORK=off")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("%s %s in the template: %v\n%s", tool, strings.Join(args, " "), err, out)
	}
	return string(out)
}

func goIn(t *testing.T, dir string, args ...string) string { return toolIn(t, dir, "go", args...) }

func TestTheAPITemplateBuildsAndPassesItsOwnChecks(t *testing.T) {
	dir := copyTemplate(t, "api")
	if out := toolIn(t, dir, "gofmt", "-l", "."); out != "" {
		t.Errorf("not gofmt-clean:\n%s", out)
	}
	goIn(t, dir, "vet", "./...")
	goIn(t, dir, "test", "-race", "-count=1", "./...")
}

func TestATemplateCarriesWhatARepoOfTheFactoryNeeds(t *testing.T) {
	dir := copyTemplate(t, "api")
	read := func(name string) string {
		b, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			t.Fatalf("the template lacks %s: %v", name, err)
		}
		return string(b)
	}
	if lic := read("LICENSE"); !strings.HasPrefix(lic, "MIT License") {
		t.Errorf("LICENSE starts %q; a product may use a template under its own licence only if it is MIT", lic[:20])
	}
	if n := strings.Count(read("AGENTS.md"), "\n"); n > 100 {
		t.Errorf("AGENTS.md is %d lines; a short file that points into docs, about 100 lines (spec §4.2)", n)
	}
	for _, name := range []string{"init.sh", "openapi.yaml", ".golangci.yml", ".gitignore"} {
		read(name)
	}
	// The devcontainer.json is for people's editors. The factory never reads it, and it must stay one a
	// person can open without running anything of the repo's.
	var dc map[string]any
	if err := json.Unmarshal([]byte(read(".devcontainer/devcontainer.json")), &dc); err != nil {
		t.Fatalf(".devcontainer/devcontainer.json: %v", err)
	}
	for _, key := range []string{"initializeCommand", "onCreateCommand", "updateContentCommand", "postCreateCommand", "postStartCommand",
		"postAttachCommand", "mounts", "runArgs", "privileged", "capAdd", "securityOpt", "dockerComposeFile", "build", "features", "containerEnv", "remoteEnv", "forwardPorts"} {
		if _, bad := dc[key]; bad {
			t.Errorf(".devcontainer/devcontainer.json sets %s, which runs or widens something when a person opens the repo", key)
		}
	}
}
```

Write `templates/api/cmd/api/main_test.go`:

```go
package main

import "testing"

func TestPortComesFromTheEnvironmentOr8080(t *testing.T) {
	t.Setenv("PORT", "")
	if got, err := portFromEnv(); err != nil || got != 8080 {
		t.Errorf("portFromEnv() with no PORT = %d, %v; want 8080", got, err)
	}
	t.Setenv("PORT", "9090")
	if got, err := portFromEnv(); err != nil || got != 9090 {
		t.Errorf("portFromEnv() = %d, %v; want 9090", got, err)
	}
	for _, bad := range []string{"0", "65536", "-1", "http", "80 80", "8080;"} {
		t.Setenv("PORT", bad)
		if got, err := portFromEnv(); err == nil {
			t.Errorf("portFromEnv() with PORT=%q = %d, nil; want an error", bad, got)
		}
	}
}
```

Write `templates/api/internal/httpapi/server_test.go`:

```go
package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthzSaysOK(t *testing.T) {
	rec := httptest.NewRecorder()
	New().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /healthz = %d, want 200", rec.Code)
	}
	if ct := rec.Header().Get("Content-Type"); ct != "application/json" {
		t.Errorf("Content-Type = %q, want application/json", ct)
	}
	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil || body["status"] != "ok" {
		t.Errorf("body = %s, %v; want {\"status\":\"ok\"}", rec.Body.String(), err)
	}
}

func TestOnlyGetReachesHealthz(t *testing.T) {
	rec := httptest.NewRecorder()
	New().ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/healthz", nil))
	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("POST /healthz = %d, want 405", rec.Code)
	}
}

func TestAnUnknownRouteIsA404WithAJSONBody(t *testing.T) {
	rec := httptest.NewRecorder()
	New().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/nope", nil))
	if rec.Code != http.StatusNotFound || rec.Header().Get("Content-Type") != "application/json" {
		t.Errorf("GET /nope = %d %q, want a 404 with a JSON body", rec.Code, rec.Header().Get("Content-Type"))
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/helheim-go/templates/api/cmd/api [github.com/ouroboric-dev/helheim-go/templates/api/cmd/api.test]
templates/api/cmd/api/main_test.go:7:17: undefined: portFromEnv
templates/api/cmd/api/main_test.go:11:17: undefined: portFromEnv
templates/api/cmd/api/main_test.go:16:18: undefined: portFromEnv
```

- [ ] **Step 3:** write the code.

Write `templates/api/.devcontainer/devcontainer.json`:

```json
{
  "name": "api",
  "image": "docker.io/library/golang:1.26.9-bookworm@sha256:d9c68c2c51161e12fd77e4c6320687c9cd86e1af1e3ad6e6cd63ff970641453c"
}
```

Write `templates/api/.gitignore`:

```text
/bin/
*.test
coverage.out
```

Write `templates/api/.golangci.yml`:

```yaml
version: "2"
linters:
  default: standard
  enable:
    - bodyclose
    - errorlint
    - gosec
```

Write `templates/api/AGENTS.md`:

```md
# AGENTS.md: api

The Go HTTP API of this product. It owns `openapi.yaml`, the contract every consumer builds against.

Follow the Yggdrasil invariants:
https://github.com/ouroboric-dev/yggdrasil/blob/main/AGENTS.md#invariants
This file only adds rules for this leaf. Read `docs/` for the design; this file says how to work here.

## Work here

- Build, test, lint: `go build ./...`, `go test -race ./...`, `go vet ./...`, `golangci-lint run`.
- `go.mod` says `module api`. Imports are `api/internal/...`.
- Standard library first: `net/http` with the Go 1.22 pattern mux. A new dependency needs a reason in
  the commit message that the standard library cannot give.
- The server listens on `PORT`. It reads nothing else from the environment that is not named in `docs/`.

## Rules for every change

- **Test first.** A new test fails on the parent commit, for the reason the task gives. The factory
  checks this: a change to code without a new or changed test is refused.
- **The contract and the code change together.** A route is added in `internal/httpapi` and described in
  `openapi.yaml` in the same commit. A change that breaks consumers (a removed route or field, a new
  required field) is a contract change: say so in the commit message.
- **The server builds every storage key** from the logged-in user and the resource. It ignores keys a
  client sends. Authorisation is checked in the handler, not only in middleware.
- Errors answer JSON `{"error": "..."}` with the right status. A handler never leaks a stack trace, a
  query or a file path.
- No secret in the repository, in a test or in a log line.

## Layout

- `cmd/api`: the program. It wires things and starts the server; it holds no logic.
- `internal/httpapi`: routes, request and response encoding, errors.
- `openapi.yaml`: the contract.
```

Write `templates/api/LICENSE`:

```text
MIT License

Copyright (c) the contributors to this project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Write `templates/api/cmd/api/main.go`:

```go
// Command api serves the HTTP API on the port named by PORT (8080 when unset).
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"api/internal/httpapi"
)

func main() {
	port, err := portFromEnv()
	if err != nil {
		log.Fatal(err)
	}
	srv := &http.Server{Addr: ":" + strconv.Itoa(port), Handler: httpapi.New(), ReadHeaderTimeout: 5 * time.Second}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	go func() {
		<-ctx.Done()
		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		_ = srv.Shutdown(shutdown)
	}()
	log.Printf("listening on :%d", port)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

// portFromEnv reads PORT: a whole number from 1 to 65535, or 8080 when it is unset.
func portFromEnv() (int, error) {
	v := os.Getenv("PORT")
	if v == "" {
		return 8080, nil
	}
	port, err := strconv.Atoi(v)
	if err != nil || port < 1 || port > 65535 {
		return 0, errors.New("PORT must be a whole number from 1 to 65535")
	}
	return port, nil
}
```

Write `templates/api/go.mod`:

```text
module api

go 1.26
```

Write `templates/api/init.sh` (executable):

```sh
#!/bin/sh
# Prepares a fresh clone for work: downloads the modules. Run it once; it changes nothing else.
set -eu
go mod download
echo "ready: run ./... tests with 'go test ./...'"
```

Write `templates/api/internal/httpapi/server.go`:

```go
// Package httpapi is the API's HTTP surface: the routes, how they answer, and how they fail.
package httpapi

import (
	"encoding/json"
	"net/http"
)

// New returns the handler of every route. A route is added here and described in openapi.yaml, in the
// same change.
func New() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", only(http.MethodGet, healthz))
	mux.HandleFunc("/", notFound)
	return mux
}

// only answers 405 to every method but method. A catch-all route would otherwise answer a wrong method
// on a known path with 404 (the mux gives a method-specific pattern no 405 beside "/").
func only(method string, h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != method {
			w.Header().Set("Allow", method)
			writeJSON(w, http.StatusMethodNotAllowed, map[string]string{"error": "method not allowed"})
			return
		}
		h(w, r)
	}
}

func healthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func notFound(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
}

// writeJSON answers with status and v as JSON. A value that can't be encoded is a bug in the code that
// built it, so it answers 500 rather than a half-written body.
func writeJSON(w http.ResponseWriter, status int, v any) {
	body, err := json.Marshal(v)
	if err != nil {
		http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(append(body, '\n'))
}
```

Write `templates/api/openapi.yaml`:

```yaml
openapi: 3.1.0
info:
  title: API
  version: 0.1.0
  description: The contract of this API. It is the source of truth for every consumer (spec §9.2).
servers:
  - url: http://localhost:8080
paths:
  /healthz:
    get:
      operationId: getHealth
      summary: Is the server up
      responses:
        "200":
          description: The server is up.
          content:
            application/json:
              schema:
                type: object
                required: [status]
                properties:
                  status:
                    type: string
                    enum: [ok]
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T218: the API template gets a database: migrations, sqlc and a store, with an integration test

The API stack is Go, `sqlc` and Postgres (spec §9.2). The template carries the plumbing so that implementers add SQL and migrations, not tooling: a migration runner, the code `sqlc` generates, a store wired into `/healthz`, and an integration test that the ladder's last rung runs against the sandbox's Postgres. Building the template found two known vulnerabilities in a dependency of the Postgres driver (`golang.org/x/text`), so the template pins the fixed release; and Go 1.26.7's standard library fails `govulncheck`, so the image the template names is 1.26.9 (decision 11).

**Files (in `helheim-go`):**
- Create: `templates/api/db/queries/info.sql`, `templates/api/internal/store/db.go`, `templates/api/internal/store/info.sql.go`, `templates/api/internal/store/migrate.go`, `templates/api/internal/store/migrations/0001_init.sql`, `templates/api/internal/store/models.go`, `templates/api/internal/store/store_integration_test.go`, `templates/api/internal/store/store_test.go`, `templates/api/sqlc.yaml`
- Modify: `template_test.go`, `templates/api/AGENTS.md`, `templates/api/cmd/api/main.go`, `templates/api/go.mod`, `templates/api/internal/httpapi/server.go`, `templates/api/internal/httpapi/server_test.go`, `templates/api/openapi.yaml`

**Interfaces:**
- Produces: `sqlc.yaml`, `internal/store/migrations/0001_init.sql` (a table `app_info`), `db/queries/info.sql` (`GetInfo`, `SetInfo`) and the generated `internal/store` (`db.go`, `models.go`, `info.sql.go`, by `sqlc` 1.31.1); `store.Open(ctx, url)` and `store.Migrate(ctx, pool)`, which applies the embedded migrations in file order, each in a transaction, under an advisory lock; `httpapi.Deps{DB Pinger}` and `httpapi.New(Deps)`; `/healthz` answers 503 `{"status":"database unavailable"}` when the database does not answer, never the error.
- The program uses the database at `DATABASE_URL` when that is set. Tests that need a database carry `//go:build integration` and read `YGG_DATABASE_URL`.

**Acceptance criteria:**
- [ ] The unit tests cover `/healthz` with no database, with one that answers and with one that is down (and the body never carries the driver's error), and that the migrations are named `NNNN_what.sql`, in order, without a number twice.
- [ ] `go vet -tags integration` is clean, so the integration test compiles; `sqlc diff` finds nothing to change.
- [ ] `govulncheck` and `osv-scanner` find nothing in the template (run with Go 1.26.9).

**Named test:** `go test . -run 'TestTheAPITemplateBuildsAndPassesItsOwnChecks'; and, in templates/api, go test ./...` in `helheim-go`. **Layer:** `helheim-go`. **Size:** M (365). **Depends on:** v0-T217.

- [ ] **Step 1:** write the tests.

Apply to `template_test.go`:

```diff
diff --git a/template_test.go b/template_test.go
index 4b9c132..67166a0 100644
--- a/template_test.go
+++ b/template_test.go
@@ -34,12 +34,30 @@ func toolIn(t *testing.T, dir, tool string, args ...string) string {
 
 func goIn(t *testing.T, dir string, args ...string) string { return toolIn(t, dir, "go", args...) }
 
+// needModules downloads the template's modules, and skips the test when the module proxy can't be
+// reached, unless YGG_REQUIRE_TEMPLATES is set (a CI that must not skip). It is the one place these
+// tests need the network, and only on a machine that has not built the template before.
+func needModules(t *testing.T, dir string) {
+	t.Helper()
+	cmd := exec.Command("go", "mod", "download")
+	cmd.Dir = dir
+	cmd.Env = append(os.Environ(), "GOWORK=off")
+	if out, err := cmd.CombinedOutput(); err != nil {
+		if os.Getenv("YGG_REQUIRE_TEMPLATES") != "" {
+			t.Fatalf("go mod download: %v\n%s", err, out)
+		}
+		t.Skipf("the template's modules can't be downloaded (set YGG_REQUIRE_TEMPLATES to fail instead): %v", err)
+	}
+}
+
 func TestTheAPITemplateBuildsAndPassesItsOwnChecks(t *testing.T) {
 	dir := copyTemplate(t, "api")
+	needModules(t, dir)
 	if out := toolIn(t, dir, "gofmt", "-l", "."); out != "" {
 		t.Errorf("not gofmt-clean:\n%s", out)
 	}
 	goIn(t, dir, "vet", "./...")
+	goIn(t, dir, "vet", "-tags", "integration", "./...")
 	goIn(t, dir, "test", "-race", "-count=1", "./...")
 }
 
```

Apply to `templates/api/internal/httpapi/server_test.go`:

```diff
diff --git a/templates/api/internal/httpapi/server_test.go b/templates/api/internal/httpapi/server_test.go
index f164d72..a693c06 100644
--- a/templates/api/internal/httpapi/server_test.go
+++ b/templates/api/internal/httpapi/server_test.go
@@ -1,15 +1,18 @@
 package httpapi
 
 import (
+	"context"
 	"encoding/json"
+	"errors"
 	"net/http"
 	"net/http/httptest"
+	"strings"
 	"testing"
 )
 
 func TestHealthzSaysOK(t *testing.T) {
 	rec := httptest.NewRecorder()
-	New().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
+	New(Deps{}).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
 	if rec.Code != http.StatusOK {
 		t.Fatalf("GET /healthz = %d, want 200", rec.Code)
 	}
@@ -24,7 +27,7 @@ func TestHealthzSaysOK(t *testing.T) {
 
 func TestOnlyGetReachesHealthz(t *testing.T) {
 	rec := httptest.NewRecorder()
-	New().ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/healthz", nil))
+	New(Deps{}).ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/healthz", nil))
 	if rec.Code != http.StatusMethodNotAllowed {
 		t.Errorf("POST /healthz = %d, want 405", rec.Code)
 	}
@@ -32,8 +35,35 @@ func TestOnlyGetReachesHealthz(t *testing.T) {
 
 func TestAnUnknownRouteIsA404WithAJSONBody(t *testing.T) {
 	rec := httptest.NewRecorder()
-	New().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/nope", nil))
+	New(Deps{}).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/nope", nil))
 	if rec.Code != http.StatusNotFound || rec.Header().Get("Content-Type") != "application/json" {
 		t.Errorf("GET /nope = %d %q, want a 404 with a JSON body", rec.Code, rec.Header().Get("Content-Type"))
 	}
 }
+
+type fakeDB struct{ err error }
+
+func (f fakeDB) Ping(context.Context) error { return f.err }
+
+func TestHealthzTellsWhetherTheDatabaseAnswers(t *testing.T) {
+	for name, tc := range map[string]struct {
+		deps Deps
+		code int
+		want string
+	}{
+		"no database configured":  {Deps{}, http.StatusOK, "ok"},
+		"a database that answers": {Deps{DB: fakeDB{}}, http.StatusOK, "ok"},
+		"a database that is down": {Deps{DB: fakeDB{err: errors.New("connection refused")}}, http.StatusServiceUnavailable, "database unavailable"},
+	} {
+		rec := httptest.NewRecorder()
+		New(tc.deps).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/healthz", nil))
+		var body map[string]string
+		_ = json.Unmarshal(rec.Body.Bytes(), &body)
+		if rec.Code != tc.code || body["status"] != tc.want {
+			t.Errorf("%s: GET /healthz = %d %s, want %d %q", name, rec.Code, rec.Body.String(), tc.code, tc.want)
+		}
+		if strings.Contains(rec.Body.String(), "refused") {
+			t.Errorf("%s: the body leaks the database's error: %s", name, rec.Body.String())
+		}
+	}
+}
```

Write `templates/api/internal/store/store_integration_test.go`:

```go
//go:build integration

package store

import (
	"context"
	"os"
	"testing"
)

// Run with a database: YGG_DATABASE_URL=postgres://postgres@postgres:5432/app?sslmode=disable
// go test -tags integration ./... (the factory's integration check does it, in a sandbox that starts one).
func TestTheStoreMigratesAndAnswersQueries(t *testing.T) {
	url := os.Getenv("YGG_DATABASE_URL")
	if url == "" {
		t.Skip("set YGG_DATABASE_URL to run this test")
	}
	ctx := context.Background()
	pool, err := Open(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	defer pool.Close()
	if err := Migrate(ctx, pool); err != nil {
		t.Fatalf("migrating a second time = %v; applied migrations are skipped", err)
	}
	q := New(pool)
	if err := q.SetInfo(ctx, SetInfoParams{Key: "greeting", Value: "hello"}); err != nil {
		t.Fatal(err)
	}
	if got, err := q.GetInfo(ctx, "greeting"); err != nil || got != "hello" {
		t.Errorf("GetInfo() = %q, %v; want hello", got, err)
	}
}
```

Write `templates/api/internal/store/store_test.go`:

```go
package store

import (
	"sort"
	"strings"
	"testing"
)

func TestMigrationsAreNamedInTheOrderTheyRun(t *testing.T) {
	names, err := migrationNames()
	if err != nil || len(names) == 0 {
		t.Fatalf("migrationNames() = %v, %v", names, err)
	}
	if !sort.StringsAreSorted(names) {
		t.Errorf("migrations %v are not in file order", names)
	}
	for i, n := range names {
		if !strings.HasSuffix(n, ".sql") || len(n) < 6 || strings.Trim(n[:4], "0123456789") != "" {
			t.Errorf("migration %q is not named NNNN_what.sql", n)
		}
		if i > 0 && n[:4] == names[i-1][:4] {
			t.Errorf("migrations %q and %q share a number", names[i-1], n)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# ./templates/api/internal/httpapi
main module (github.com/ouroboric-dev/helheim-go) does not contain package github.com/ouroboric-dev/helheim-go/templates/api/internal/httpapi
FAIL	./templates/api/internal/httpapi [setup failed]
# ./templates/api/internal/store
```

- [ ] **Step 3:** write the code.

Apply to `templates/api/AGENTS.md`:

```diff
diff --git a/templates/api/AGENTS.md b/templates/api/AGENTS.md
index 227e506..114a23c 100644
--- a/templates/api/AGENTS.md
+++ b/templates/api/AGENTS.md
@@ -12,7 +12,8 @@ This file only adds rules for this leaf. Read `docs/` for the design; this file
 - `go.mod` says `module api`. Imports are `api/internal/...`.
 - Standard library first: `net/http` with the Go 1.22 pattern mux. A new dependency needs a reason in
   the commit message that the standard library cannot give.
-- The server listens on `PORT`. It reads nothing else from the environment that is not named in `docs/`.
+- The server listens on `PORT` and uses the database at `DATABASE_URL` when that is set. It reads nothing
+  else from the environment that is not named in `docs/`.
 
 ## Rules for every change
 
@@ -21,6 +22,9 @@ This file only adds rules for this leaf. Read `docs/` for the design; this file
 - **The contract and the code change together.** A route is added in `internal/httpapi` and described in
   `openapi.yaml` in the same commit. A change that breaks consumers (a removed route or field, a new
   required field) is a contract change: say so in the commit message.
+- **Data goes through sqlc.** A query is SQL in `db/queries`, a schema change is a new file in
+  `internal/store/migrations` (never an edit of one that exists), and `sqlc generate` writes
+  `internal/store`. The factory refuses a change whose generated code is out of date (`sqlc diff`).
 - **The server builds every storage key** from the logged-in user and the resource. It ignores keys a
   client sends. Authorisation is checked in the handler, not only in middleware.
 - Errors answer JSON `{"error": "..."}` with the right status. A handler never leaks a stack trace, a
@@ -31,4 +35,7 @@ This file only adds rules for this leaf. Read `docs/` for the design; this file
 
 - `cmd/api`: the program. It wires things and starts the server; it holds no logic.
 - `internal/httpapi`: routes, request and response encoding, errors.
+- `internal/store`: the database: migrations, and the code sqlc generates. Do not edit `*.sql.go`.
+- `db/queries`: the SQL that sqlc turns into Go.
+- Tests that need a database carry `//go:build integration` and read `YGG_DATABASE_URL`.
 - `openapi.yaml`: the contract.
```

Apply to `templates/api/cmd/api/main.go`:

```diff
diff --git a/templates/api/cmd/api/main.go b/templates/api/cmd/api/main.go
index c36d4ff..74d0d3f 100644
--- a/templates/api/cmd/api/main.go
+++ b/templates/api/cmd/api/main.go
@@ -1,4 +1,5 @@
-// Command api serves the HTTP API on the port named by PORT (8080 when unset).
+// Command api serves the HTTP API on the port named by PORT (8080 when unset), with the database at
+// DATABASE_URL when that is set.
 package main
 
 import (
@@ -13,6 +14,7 @@ import (
 	"time"
 
 	"api/internal/httpapi"
+	"api/internal/store"
 )
 
 func main() {
@@ -20,9 +22,18 @@ func main() {
 	if err != nil {
 		log.Fatal(err)
 	}
-	srv := &http.Server{Addr: ":" + strconv.Itoa(port), Handler: httpapi.New(), ReadHeaderTimeout: 5 * time.Second}
 	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
 	defer stop()
+	var deps httpapi.Deps
+	if url := os.Getenv("DATABASE_URL"); url != "" {
+		pool, err := store.Open(ctx, url)
+		if err != nil {
+			log.Fatal(err)
+		}
+		defer pool.Close()
+		deps.DB = pool
+	}
+	srv := &http.Server{Addr: ":" + strconv.Itoa(port), Handler: httpapi.New(deps), ReadHeaderTimeout: 5 * time.Second}
 	go func() {
 		<-ctx.Done()
 		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
```

Write `templates/api/db/queries/info.sql`:

```sql
-- name: GetInfo :one
SELECT value FROM app_info WHERE key = $1;

-- name: SetInfo :exec
INSERT INTO app_info (key, value) VALUES ($1, $2)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
```

Apply to `templates/api/go.mod`:

```diff
diff --git a/templates/api/go.mod b/templates/api/go.mod
index e826778..e2855c0 100644
--- a/templates/api/go.mod
+++ b/templates/api/go.mod
@@ -1,3 +1,13 @@
 module api
 
-go 1.26
+go 1.26.0
+
+require github.com/jackc/pgx/v5 v5.10.0
+
+require (
+	github.com/jackc/pgpassfile v1.0.0 // indirect
+	github.com/jackc/pgservicefile v0.0.0-20240606120523-5a60cdf6a761 // indirect
+	github.com/jackc/puddle/v2 v2.2.2 // indirect
+	golang.org/x/sync v0.23.0 // indirect
+	golang.org/x/text v0.42.0 // indirect
+)
```

Apply to `templates/api/internal/httpapi/server.go`:

```diff
diff --git a/templates/api/internal/httpapi/server.go b/templates/api/internal/httpapi/server.go
index fc09951..bd452ad 100644
--- a/templates/api/internal/httpapi/server.go
+++ b/templates/api/internal/httpapi/server.go
@@ -2,15 +2,26 @@
 package httpapi
 
 import (
+	"context"
 	"encoding/json"
 	"net/http"
 )
 
+// Pinger is what the server needs to know whether the database is there.
+type Pinger interface {
+	Ping(ctx context.Context) error
+}
+
+// Deps are what the routes use. A field that is nil is a part the server runs without.
+type Deps struct {
+	DB Pinger
+}
+
 // New returns the handler of every route. A route is added here and described in openapi.yaml, in the
 // same change.
-func New() http.Handler {
+func New(d Deps) http.Handler {
 	mux := http.NewServeMux()
-	mux.HandleFunc("/healthz", only(http.MethodGet, healthz))
+	mux.HandleFunc("/healthz", only(http.MethodGet, healthz(d)))
 	mux.HandleFunc("/", notFound)
 	return mux
 }
@@ -28,8 +39,15 @@ func only(method string, h http.HandlerFunc) http.HandlerFunc {
 	}
 }
 
-func healthz(w http.ResponseWriter, _ *http.Request) {
-	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
+func healthz(d Deps) http.HandlerFunc {
+	return func(w http.ResponseWriter, r *http.Request) {
+		if d.DB != nil && d.DB.Ping(r.Context()) != nil {
+			// What is wrong stays in the server's log; a caller learns only that the database is not there.
+			writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "database unavailable"})
+			return
+		}
+		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
+	}
 }
 
 func notFound(w http.ResponseWriter, _ *http.Request) {
```

Write `templates/api/internal/store/db.go`:

```go
// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.31.1

package store

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

type DBTX interface {
	Exec(context.Context, string, ...interface{}) (pgconn.CommandTag, error)
	Query(context.Context, string, ...interface{}) (pgx.Rows, error)
	QueryRow(context.Context, string, ...interface{}) pgx.Row
}

func New(db DBTX) *Queries {
	return &Queries{db: db}
}

type Queries struct {
	db DBTX
}

func (q *Queries) WithTx(tx pgx.Tx) *Queries {
	return &Queries{
		db: tx,
	}
}
```

Write `templates/api/internal/store/info.sql.go`:

```go
// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.31.1
// source: info.sql

package store

import (
	"context"
)

const getInfo = `-- name: GetInfo :one
SELECT value FROM app_info WHERE key = $1
`

func (q *Queries) GetInfo(ctx context.Context, key string) (string, error) {
	row := q.db.QueryRow(ctx, getInfo, key)
	var value string
	err := row.Scan(&value)
	return value, err
}

const setInfo = `-- name: SetInfo :exec
INSERT INTO app_info (key, value) VALUES ($1, $2)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value
`

type SetInfoParams struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

func (q *Queries) SetInfo(ctx context.Context, arg SetInfoParams) error {
	_, err := q.db.Exec(ctx, setInfo, arg.Key, arg.Value)
	return err
}
```

Write `templates/api/internal/store/migrate.go`:

```go
package store

import (
	"context"
	"embed"
	"fmt"
	"sort"

	"github.com/jackc/pgx/v5/pgxpool"
)

//go:embed migrations/*.sql
var migrations embed.FS

// migrationNames are the migration files, in the order they run.
func migrationNames() ([]string, error) {
	entries, err := migrations.ReadDir("migrations")
	if err != nil {
		return nil, err
	}
	var names []string
	for _, e := range entries {
		names = append(names, e.Name())
	}
	sort.Strings(names)
	return names, nil
}

// Open connects to the database at url and applies every migration that has not been applied.
func Open(ctx context.Context, url string) (*pgxpool.Pool, error) {
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		return nil, fmt.Errorf("opening the database: %w", err)
	}
	if err := Migrate(ctx, pool); err != nil {
		pool.Close()
		return nil, err
	}
	return pool, nil
}

// Migrate applies the migrations that the database has not seen, each in a transaction of its own, and
// records it in schema_migrations. Two processes that migrate at once take turns on an advisory lock.
func Migrate(ctx context.Context, pool *pgxpool.Pool) error {
	conn, err := pool.Acquire(ctx)
	if err != nil {
		return err
	}
	defer conn.Release()
	if _, err := conn.Exec(ctx, "SELECT pg_advisory_lock(7263841)"); err != nil {
		return err
	}
	defer func() { _, _ = conn.Exec(context.WithoutCancel(ctx), "SELECT pg_advisory_unlock(7263841)") }()
	if _, err := conn.Exec(ctx, "CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())"); err != nil {
		return err
	}
	names, err := migrationNames()
	if err != nil {
		return err
	}
	for _, name := range names {
		var done bool
		if err := conn.QueryRow(ctx, "SELECT EXISTS (SELECT 1 FROM schema_migrations WHERE name = $1)", name).Scan(&done); err != nil {
			return err
		}
		if done {
			continue
		}
		body, err := migrations.ReadFile("migrations/" + name)
		if err != nil {
			return err
		}
		tx, err := conn.Begin(ctx)
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, string(body)); err != nil {
			_ = tx.Rollback(ctx)
			return fmt.Errorf("migration %s: %w", name, err)
		}
		if _, err := tx.Exec(ctx, "INSERT INTO schema_migrations (name) VALUES ($1)", name); err != nil {
			_ = tx.Rollback(ctx)
			return err
		}
		if err := tx.Commit(ctx); err != nil {
			return err
		}
	}
	return nil
}
```

Write `templates/api/internal/store/migrations/0001_init.sql`:

```sql
-- A migration is applied once, in file order. Never edit one that has been applied: add the next.
CREATE TABLE app_info (
    key   text PRIMARY KEY,
    value text NOT NULL
);
```

Write `templates/api/internal/store/models.go`:

```go
// Code generated by sqlc. DO NOT EDIT.
// versions:
//   sqlc v1.31.1

package store

type AppInfo struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}
```

Apply to `templates/api/openapi.yaml`:

```diff
diff --git a/templates/api/openapi.yaml b/templates/api/openapi.yaml
index befdec6..b6fd737 100644
--- a/templates/api/openapi.yaml
+++ b/templates/api/openapi.yaml
@@ -22,3 +22,14 @@ paths:
                   status:
                     type: string
                     enum: [ok]
+        "503":
+          description: The server is up but its database does not answer.
+          content:
+            application/json:
+              schema:
+                type: object
+                required: [status]
+                properties:
+                  status:
+                    type: string
+                    enum: [database unavailable]
```

Write `templates/api/sqlc.yaml`:

```yaml
version: "2"
sql:
  - engine: postgresql
    schema: internal/store/migrations
    queries: db/queries
    gen:
      go:
        package: store
        out: internal/store
        sql_package: pgx/v5
        emit_json_tags: true
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T219: the Go stack image, and the static and unit rungs of the check ladder, tested on small leaves

The stack layer of the Go realm (spec §9.4): the Go toolchain, the tools of the ladder at pinned versions, and the ladder's scripts baked into `/opt/ygg/checks`, owned by root, where the agent's user can run them and cannot write them. Rung 1 (static) and the tests of rung 2 are its first scripts. They run in a leaf's top folder.

**Files (in `helheim-go`):**
- Create: `checks_test.go`, `containerfile_test.go`, `devcontainer/Containerfile`, `devcontainer/checks/docs.sh`, `devcontainer/checks/go-static.sh`, `devcontainer/checks/go-unit.sh`

**Interfaces:**
- Produces: `devcontainer/Containerfile` (one stage; `FROM golang:1.26.9-bookworm` by digest; `golangci-lint` 2.14.0, `sqlc` 1.31.1, `oasdiff` 1.33.0, `vacuum` 0.30.6 and `osv-scanner` 2.6.0 as release binaries, each checked against a SHA-256 recorded when the version was reviewed; `govulncheck` 1.8.0 by `go install`; `rm -rf /go/pkg` after it, so that the agent's user can make its module cache; `COPY checks/ /opt/ygg/checks/`, made read-only for all but root).
- Produces: `devcontainer/checks/docs.sh` (every `docs/**.md` has front matter with `title`, a `status` of draft, accepted, implemented or superseded and a `date`; a plain file name; relative links that point at files), `go-static.sh` (`gofmt -l`, `go vet` with and without the integration tag, `golangci-lint run`, the docs) and `go-unit.sh` (`go test -race -count=1 ./...`).

**Acceptance criteria:**
- [ ] Every `FROM` is pinned by digest, every download is checked against a hash, `curl` is used once (inside the checking function), `go install` names a version, nothing is piped into a shell, and the context is one gungnir can hash.
- [ ] The scripts are executable, start `#!/bin/bash` with `set -euo pipefail` and pass `shellcheck`.
- [ ] `docs.sh` accepts good documents and names every problem of bad ones; `go-static.sh` stops at the first problem (an unformatted file, a vet error, also behind the integration tag, a lint failure, a bad document) and says what to fix; `go-unit.sh` fails on a failing test.

**Named test:** `go test . -run 'TestDocsAcceptsDocumentsAndNamesEveryProblemOfTheOthers|TestStaticStopsAtTheFirstProblemAndSaysWhatToFix|TestUnitRunsEveryTestWithTheRaceDetectorAndNoCache|TestTheStackImageIsMadeOfPinnedInputsOnly|TestEveryCheckScriptIsExecutableAndShellcheckedByItsAuthor'` in `helheim-go`. **Layer:** `helheim-go`. **Size:** M (347). **Depends on:** v0-T218.

- [ ] **Step 1:** write the tests.

Write `checks_test.go`:

```go
package helheim

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// The scripts of devcontainer/checks are baked into the stack image and run in a leaf. These tests run them
// on small leaves made in a temp dir, with the real go, gofmt and git, and stand-ins for the tools that only
// the image has (golangci-lint, sqlc, oasdiff, vacuum, govulncheck, osv-scanner), which log how they were
// called and exit as the test says.

// leaf writes files (path: body) into a new temp dir and returns it.
func leaf(t *testing.T, files map[string]string) string {
	t.Helper()
	dir := t.TempDir()
	put(t, dir, files)
	return dir
}

func put(t *testing.T, dir string, files map[string]string) {
	t.Helper()
	for name, body := range files {
		p := filepath.Join(dir, name)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

// stubs makes a folder of executables named tools. Each logs "<tool> <args>" to calls.log in the folder and
// exits with the number in the variable STUB_<TOOL>_EXIT (0 when it is unset), after printing STUB_<TOOL>_OUT.
func stubs(t *testing.T, tools ...string) (bin string) {
	t.Helper()
	bin = t.TempDir()
	for _, tool := range tools {
		v := strings.ToUpper(strings.ReplaceAll(tool, "-", "_"))
		body := "#!/bin/sh\necho \"" + tool + " $*\" >> \"$(dirname \"$0\")/calls.log\"\n" +
			"[ -z \"$STUB_" + v + "_OUT\" ] || echo \"$STUB_" + v + "_OUT\"\nexit \"${STUB_" + v + "_EXIT:-0}\"\n"
		if err := os.WriteFile(filepath.Join(bin, tool), []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	return bin
}

func calls(bin string) string {
	b, _ := os.ReadFile(filepath.Join(bin, "calls.log"))
	return string(b)
}

// script runs devcontainer/checks/name in dir with bin first on PATH and the given extra environment
// (KEY=value), and returns its exit code and its output.
func script(t *testing.T, dir, bin, name string, env ...string) (int, string) {
	t.Helper()
	abs, err := filepath.Abs(filepath.Join("devcontainer", "checks", name))
	if err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command("bash", abs)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GOWORK=off", "GOFLAGS=-mod=mod", "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1")
	if bin != "" {
		cmd.Env = append(cmd.Env, "PATH="+bin+":"+os.Getenv("PATH"))
	}
	cmd.Env = append(cmd.Env, env...)
	var out bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &out
	err = cmd.Run()
	if ee, ok := err.(*exec.ExitError); ok {
		return ee.ExitCode(), out.String()
	}
	if err != nil {
		t.Fatalf("%s: %v", name, err)
	}
	return 0, out.String()
}

const goMod = "module t\n\ngo 1.26\n"

func TestDocsAcceptsDocumentsAndNamesEveryProblemOfTheOthers(t *testing.T) {
	good := "---\ntitle: A\nstatus: draft\ndate: 2026-10-17\n---\n# A\n\nSee [b](b.md), [a part](b.md#part), [the web](https://example.com/x) and [here](#top).\n"
	dir := leaf(t, map[string]string{"docs/a.md": good, "docs/b.md": good})
	if code, out := script(t, dir, "", "docs.sh"); code != 0 || !strings.Contains(out, "docs: ok") {
		t.Errorf("good documents: exit %d\n%s", code, out)
	}
	if code, out := script(t, t.TempDir(), "", "docs.sh"); code != 0 || !strings.Contains(out, "nothing to check") {
		t.Errorf("a leaf with no docs/: exit %d\n%s", code, out)
	}
	dir = leaf(t, map[string]string{
		"docs/b.md":            good,
		"docs/NoPlain Name.md": good,
		"docs/no-front.md":     "# no front matter\n",
		"docs/no-status.md":    "---\ntitle: A\ndate: 2026-10-17\n---\ntext\n",
		"docs/odd-status.md":   "---\ntitle: A\nstatus: maybe\ndate: 17 October\n---\ntext\n",
		"docs/dead-link.md":    strings.Replace(good, "[b](b.md)", "[gone](gone.md)", 1),
	})
	code, out := script(t, dir, "", "docs.sh")
	if code == 0 {
		t.Fatalf("bad documents passed:\n%s", out)
	}
	for _, want := range []string{"NoPlain Name.md: the file name must be", "no-front.md: starts without front matter", "no-status.md: the front matter has no status",
		"dead-link.md: the link gone.md points at nothing", "odd-status.md: status is maybe", "odd-status.md: date is 17 October", "6 problem(s)"} {
		if !strings.Contains(out, want) {
			t.Errorf("the output lacks %q:\n%s", want, out)
		}
	}
}

func TestStaticStopsAtTheFirstProblemAndSaysWhatToFix(t *testing.T) {
	bin := stubs(t, "golangci-lint")
	clean := map[string]string{"go.mod": goMod, "a.go": "package t\n\nfunc A() int { return 1 }\n"}
	if code, out := script(t, leaf(t, clean), bin, "go-static.sh"); code != 0 || !strings.Contains(calls(bin), "golangci-lint run ./...") {
		t.Fatalf("a clean leaf: exit %d\n%s\ncalls: %s", code, out, calls(bin))
	}
	bin = stubs(t, "golangci-lint")
	unformatted := map[string]string{"go.mod": goMod, "a.go": "package t\nfunc A() int {return 1}\n"}
	code, out := script(t, leaf(t, unformatted), bin, "go-static.sh")
	if code == 0 || !strings.Contains(out, "not gofmt-clean") || !strings.Contains(out, "a.go") || calls(bin) != "" {
		t.Errorf("an unformatted file: exit %d, calls %q\n%s", code, calls(bin), out)
	}
	vet := map[string]string{"go.mod": goMod, "a.go": "package t\n\nimport \"fmt\"\n\nfunc A() { fmt.Printf(\"%d\", \"x\") }\n"}
	if code, out := script(t, leaf(t, vet), stubs(t, "golangci-lint"), "go-static.sh"); code == 0 || !strings.Contains(out, "go vet") {
		t.Errorf("a vet problem: exit %d\n%s", code, out)
	}
	tagged := map[string]string{"go.mod": goMod, "a.go": "package t\n", "a_it_test.go": "//go:build integration\n\npackage t\n\nimport \"fmt\"\n\nfunc init() { fmt.Printf(\"%d\", \"x\") }\n"}
	if code, _ := script(t, leaf(t, tagged), stubs(t, "golangci-lint"), "go-static.sh"); code == 0 {
		t.Error("a vet problem in a file behind the integration tag passed; vet must look there too")
	}
	bin = stubs(t, "golangci-lint")
	if code, _ := script(t, leaf(t, clean), bin, "go-static.sh", "STUB_GOLANGCI_LINT_EXIT=1", "STUB_GOLANGCI_LINT_OUT=a.go:3: unused"); code == 0 {
		t.Error("a lint failure passed")
	}
	docs := map[string]string{"go.mod": goMod, "a.go": "package t\n", "docs/Bad Name.md": "x"}
	if code, out := script(t, leaf(t, docs), stubs(t, "golangci-lint"), "go-static.sh"); code == 0 || !strings.Contains(out, "docs:") {
		t.Errorf("a bad document: exit %d\n%s", code, out)
	}
}

func TestUnitRunsEveryTestWithTheRaceDetectorAndNoCache(t *testing.T) {
	pass := map[string]string{"go.mod": goMod, "a.go": "package t\n", "a_test.go": "package t\n\nimport \"testing\"\n\nfunc TestA(t *testing.T) {}\n"}
	if code, out := script(t, leaf(t, pass), "", "go-unit.sh"); code != 0 {
		t.Errorf("a passing leaf: exit %d\n%s", code, out)
	}
	fail := map[string]string{"go.mod": goMod, "a.go": "package t\n", "a_test.go": "package t\n\nimport \"testing\"\n\nfunc TestA(t *testing.T) { t.Fatal(\"broken\") }\n"}
	if code, out := script(t, leaf(t, fail), "", "go-unit.sh"); code == 0 || !strings.Contains(out, "broken") {
		t.Errorf("a failing test: exit %d\n%s", code, out)
	}
	racy := map[string]string{"go.mod": goMod, "a.go": "package t\n", "a_test.go": "package t\n\nimport \"testing\"\n\nfunc TestRace(t *testing.T) {\n\tn, done := 0, make(chan bool)\n\tgo func() {\n\t\tfor i := 0; i < 1000; i++ {\n\t\t\tn++\n\t\t}\n\t\tdone <- true\n\t}()\n\tfor i := 0; i < 1000; i++ {\n\t\tn++\n\t}\n\t<-done\n}\n"}
	if code, out := script(t, leaf(t, racy), "", "go-unit.sh"); code == 0 || !strings.Contains(out, "DATA RACE") {
		t.Errorf("a test with a data race: exit %d\n%s", code, out)
	}
}
```

Write `containerfile_test.go`:

```go
package helheim

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
)

var (
	fromLine   = regexp.MustCompile(`(?m)^FROM\s+(\S+)`)
	digestRef  = regexp.MustCompile(`^[a-z0-9][a-z0-9./_-]*(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$`)
	fetchCall  = regexp.MustCompile(`fetch (https://\S+) (\S+) ([0-9a-f]{64})`)
	goInstall  = regexp.MustCompile(`go install (\S+)`)
	pipedShell = regexp.MustCompile(`\|\s*(sudo\s+)?(ba|z)?sh\b`)
)

func TestTheStackImageIsMadeOfPinnedInputsOnly(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("devcontainer", "Containerfile"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(raw)
	froms := fromLine.FindAllStringSubmatch(text, -1)
	if len(froms) == 0 {
		t.Fatal("the Containerfile has no FROM line")
	}
	for _, f := range froms {
		if !digestRef.MatchString(f[1]) {
			t.Errorf("FROM %s is not pinned by digest", f[1])
		}
	}
	fetches := fetchCall.FindAllStringSubmatch(text, -1)
	if len(fetches) < 5 {
		t.Errorf("%d downloads are checked against a SHA-256; the ladder's five release binaries are", len(fetches))
	}
	if n := strings.Count(text, "curl "); n != 1 {
		t.Errorf("curl appears %d times; the one use is inside fetch, which checks the hash", n)
	}
	if !strings.Contains(text, `echo "$3  $2" | sha256sum -c -`) {
		t.Error("fetch does not check the download against its SHA-256 with sha256sum -c")
	}
	for _, f := range fetches {
		if !regexp.MustCompile(`/v?\d+\.\d+\.\d+/`).MatchString(f[1]) {
			t.Errorf("the download %s names no version", f[1])
		}
	}
	installs := goInstall.FindAllStringSubmatch(text, -1)
	if len(installs) == 0 {
		t.Error("govulncheck is installed with go install, at a version")
	}
	for _, i := range installs {
		if !regexp.MustCompile(`@v\d+\.\d+\.\d+$`).MatchString(i[1]) {
			t.Errorf("go install %s is not at a version", i[1])
		}
	}
	if pipedShell.MatchString(text) || strings.Contains(text, "@latest") || strings.Contains(strings.ToLower(text), ":latest") {
		t.Error("the Containerfile pipes a download into a shell or names a floating version")
	}
	// A root-owned /go/pkg would stop the agent's user from making a module cache (found on a real engine).
	if !strings.Contains(text, "rm -rf /go/pkg") {
		t.Error("the Containerfile leaves /go/pkg to root; the agent's user could not make its module cache")
	}
	for _, want := range []string{"golangci-lint", "sqlc", "oasdiff", "vacuum", "osv-scanner", "govulncheck", "COPY checks/ /opt/ygg/checks/", "go-w"} {
		if !strings.Contains(text, want) {
			t.Errorf("the Containerfile lacks %q", want)
		}
	}
	// Every stage the build context can reach is a file of the realm: no link leads out of it, and it is
	// small enough to hash into a tag (gungnir's rule for a build context).
	if _, err := schema.HashContext("devcontainer"); err != nil {
		t.Errorf("devcontainer is not a build context: %v", err)
	}
}

func TestEveryCheckScriptIsExecutableAndShellcheckedByItsAuthor(t *testing.T) {
	entries, err := os.ReadDir(filepath.Join("devcontainer", "checks"))
	if err != nil {
		t.Fatal(err)
	}
	for _, e := range entries {
		p := filepath.Join("devcontainer", "checks", e.Name())
		st, err := os.Stat(p)
		if err != nil {
			t.Fatal(err)
		}
		if st.Mode()&0o111 == 0 {
			t.Errorf("%s is not executable", p)
		}
		b, _ := os.ReadFile(p)
		if !strings.HasPrefix(string(b), "#!/bin/bash\n") || !strings.Contains(string(b), "set -euo pipefail") {
			t.Errorf("%s does not start with #!/bin/bash and set -euo pipefail", p)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestDocsAcceptsDocumentsAndNamesEveryProblemOfTheOthers (0.01s)
    checks_test.go:92: good documents: exit 127
        bash: /tmp/tmp.7hk41Ij7m2/v0-T219/helheim-go/devcontainer/checks/docs.sh: No such file or directory
    checks_test.go:95: a leaf with no docs/: exit 127
```

- [ ] **Step 3:** write the code.

Write `devcontainer/Containerfile`:

```text
# The stack layer of the helheim-go realm (spec §6.1, §9.4): the Go toolchain, the tools of the check
# ladder at pinned versions, and the ladder's scripts, baked in where the agent cannot edit them.
# `ygg sandbox build --realm helheim-go` builds it. Every base is pinned by digest, every download is
# checked against a SHA-256 recorded when the version was reviewed, and a version is at least two weeks
# old when it is pinned. A new version is a reviewed change to this file.
FROM docker.io/library/golang:1.26.9-bookworm@sha256:d9c68c2c51161e12fd77e4c6320687c9cd86e1af1e3ad6e6cd63ff970641453c AS stack

# golangci-lint 2.14.0, sqlc 1.31.1, oasdiff 1.33.0, vacuum 0.30.6 and osv-scanner 2.6.0 are release
# binaries (sqlc publishes no checksums; its hash is the one of the archive that was reviewed).
RUN set -eu; cd /tmp; \
    fetch() { curl -fsSL -o "$2" "$1"; echo "$3  $2" | sha256sum -c -; }; \
    fetch https://github.com/golangci/golangci-lint/releases/download/v2.14.0/golangci-lint-2.14.0-linux-amd64.tar.gz gcl.tgz ab90aeb7b066f92a33415b638a50fe5344bbb75a0d32ad30cc248d88f81032ab; \
    fetch https://github.com/sqlc-dev/sqlc/releases/download/v1.31.1/sqlc_1.31.1_linux_amd64.tar.gz sqlc.tgz 497ae4fcdfa64c5b0c311ffe4c2bd991e43991e82e5367792ed78bc2dca27354; \
    fetch https://github.com/oasdiff/oasdiff/releases/download/v1.33.0/oasdiff_1.33.0_linux_amd64.tar.gz oasdiff.tgz 43a4e328e2d13ba1552d760aa68d2485c75c5621f309f6ff64ae895188345247; \
    fetch https://github.com/daveshanley/vacuum/releases/download/v0.30.6/vacuum_0.30.6_linux_x86_64.tar.gz vacuum.tgz 179f038a71cd88721738d6c739dd07fbeebc905b48301935f2416e66aead95c6; \
    fetch https://github.com/google/osv-scanner/releases/download/v2.6.0/osv-scanner_linux_amd64 osv-scanner ca69b3d3cd08f889a49dc0a383122f71cc528b83803671df5fd874d97485b108; \
    tar -xzf gcl.tgz --strip-components=1 -C /usr/local/bin golangci-lint-2.14.0-linux-amd64/golangci-lint; \
    tar -xzf sqlc.tgz -C /usr/local/bin sqlc; \
    tar -xzf oasdiff.tgz -C /usr/local/bin oasdiff; \
    tar -xzf vacuum.tgz -C /usr/local/bin vacuum; \
    install -m 0755 osv-scanner /usr/local/bin/osv-scanner; \
    rm -f /tmp/*.tgz /tmp/osv-scanner

# govulncheck comes from the Go module proxy, whose checksum database vouches for the module.
# The install leaves /go/pkg behind, owned by root: removed, so that the agent's own user can make its module
# cache there (/go is world-writable in this image; /go/pkg and what is in it must not be root's).
RUN GOBIN=/usr/local/bin GOFLAGS=-mod=mod GOTOOLCHAIN=local go install golang.org/x/vuln/cmd/govulncheck@v1.8.0 \
 && go clean -cache -modcache \
 && rm -rf /go/pkg

# The ladder's scripts. Root owns them and nobody else may write: the agent runs as the operator's own
# user, so it can run a check and cannot weaken it.
COPY checks/ /opt/ygg/checks/
RUN chmod -R a+rX,go-w /opt/ygg/checks && chmod a+x /opt/ygg/checks/*.sh
```

Write `devcontainer/checks/docs.sh` (executable):

```sh
#!/bin/bash
# The docs part of the static rung (spec §9.5 rung 1): every markdown file under docs/ has the front matter
# the docs standard asks for (title, a status and a date; style and related are optional), a plain file name, and links that point at files that exist. Prose rules
# (Vale) wait for a later change. Run in a leaf's top folder; it reads and changes nothing.
set -euo pipefail
[ -d docs ] || { echo "docs: no docs/ folder, nothing to check"; exit 0; }
problems=0
say() { echo "docs: $*"; problems=$((problems + 1)); }
while IFS= read -r -d '' f; do
  name="$(basename "$f")"
  [[ "$name" =~ ^[a-z0-9][a-z0-9._-]*\.md$ ]] || say "$f: the file name must be lower case words joined by dashes, ending in .md"
  if [ "$(head -n 1 "$f")" != "---" ]; then
    say "$f: starts without front matter (--- on the first line)"
  else
    head_block="$(awk 'NR == 1 { next } /^---$/ { exit } { print }' "$f")"
    for key in title status date; do
      grep -q "^$key:" <<<"$head_block" || say "$f: the front matter has no $key"
    done
    status="$(sed -n 's/^status: *//p' <<<"$head_block" | head -n 1)"
    [ -z "$status" ] || [[ "$status" =~ ^(draft|accepted|implemented|superseded)$ ]] || say "$f: status is $status; it is draft, accepted, implemented or superseded"
    date="$(sed -n 's/^date: *//p' <<<"$head_block" | head -n 1)"
    [ -z "$date" ] || [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || say "$f: date is $date; it is YYYY-MM-DD"
  fi
  dir="$(dirname "$f")"
  while IFS= read -r link; do
    target="${link%%#*}"
    case "$target" in '' | http://* | https://* | mailto:*) continue ;; esac
    [ -e "$dir/$target" ] || say "$f: the link $link points at nothing"
  done < <(grep -o ']([^)]*)' "$f" | sed -e 's/^](//' -e 's/)$//' || true)
done < <(find docs -type f -name '*.md' -print0 | sort -z)
[ "$problems" -eq 0 ] || { echo "docs: $problems problem(s)"; exit 1; }
echo "docs: ok"
```

Write `devcontainer/checks/go-static.sh` (executable):

```sh
#!/bin/bash
# Rung 1 of the ladder for a Go leaf (spec §9.5): formatting, vet, lint, and the docs. Run in the leaf's
# top folder. The first problem ends it, with what to fix in the output.
set -euo pipefail
echo "== gofmt"
unformatted="$(gofmt -l . || true)"
if [ -n "$unformatted" ]; then
  echo "These files are not gofmt-clean; run gofmt -w on them:"
  echo "$unformatted"
  exit 1
fi
echo "== go vet"
go vet ./...
go vet -tags integration ./...
echo "== golangci-lint"
golangci-lint run ./...
echo "== docs"
"$(dirname "$0")/docs.sh"
```

Write `devcontainer/checks/go-unit.sh` (executable):

```sh
#!/bin/bash
# Rung 2, the tests: every test of the leaf, with the race detector, none cached. (go-tdd.sh is the other
# half of the rung: it shows the new tests fail on the parent commit.)
set -euo pipefail
go test -race -count=1 ./...
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T220: the TDD check: the tests a change adds must fail on the commit it started from

Spec §9.5 rung 2: new tests must fail on the parent commit. The script builds the commit the task started from (the leaf's `main`) in a folder of its own, puts the change's test files on it and runs their packages. A test of code that is not there yet fails to compile, and that counts. It is not a promise that a test is good, only that it can fail.

**Files (in `helheim-go`):**
- Create: `devcontainer/checks/go-tdd.sh`
- Modify: `checks_test.go`

**Interfaces:**
- Produces: `devcontainer/checks/go-tdd.sh`. It refuses Go code that changed without a new or changed test (generated files, marked `Code generated`, are not code that needs one); it refuses new tests that pass on the parent; it passes, with a note, a change that has only tests behind the `integration` tag (they need a database), and a change with no Go code.
- It works in a temporary folder and leaves the leaf as it was.

**Acceptance criteria:**
- [ ] A change with code and a test that needs it passes and shows the failure; code with no test, a test that passes before the code, and a changed test that does not fail are refused; generated code only, a document only, and an integration test only pass with the matching note; an unchanged branch passes.
- [ ] The leaf's tree is not changed by the check.

**Named test:** `go test . -run 'TestTDDWantsTheNewTestsToFailOnTheCommitTheTaskStartedFrom'` in `helheim-go`. **Layer:** `helheim-go`. **Size:** M (135). **Depends on:** v0-T219.

- [ ] **Step 1:** write the tests.

Apply to `checks_test.go`:

```diff
diff --git a/checks_test.go b/checks_test.go
index 87d139c..31154d5 100644
--- a/checks_test.go
+++ b/checks_test.go
@@ -158,3 +158,80 @@ func TestUnitRunsEveryTestWithTheRaceDetectorAndNoCache(t *testing.T) {
 		t.Errorf("a test with a data race: exit %d\n%s", code, out)
 	}
 }
+
+// repo makes a git repo with the given files committed on main, and returns it.
+func repo(t *testing.T, files map[string]string) string {
+	t.Helper()
+	dir := leaf(t, files)
+	git(t, dir, "init", "-q", "-b", "main")
+	git(t, dir, "add", "-A")
+	git(t, dir, "commit", "-q", "-m", "start")
+	return dir
+}
+
+func git(t *testing.T, dir string, args ...string) string {
+	t.Helper()
+	cmd := exec.Command("git", append([]string{"-c", "user.name=T", "-c", "user.email=t@example.invalid"}, args...)...)
+	cmd.Dir = dir
+	cmd.Env = append(os.Environ(), "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1")
+	out, err := cmd.CombinedOutput()
+	if err != nil {
+		t.Fatalf("git %v: %v\n%s", args, err, out)
+	}
+	return strings.TrimSpace(string(out))
+}
+
+// work puts files on a branch of the repo made from main, committed.
+func work(t *testing.T, dir string, files map[string]string) {
+	t.Helper()
+	git(t, dir, "switch", "-q", "-c", "work")
+	put(t, dir, files)
+	git(t, dir, "add", "-A")
+	git(t, dir, "commit", "-q", "-m", "work")
+}
+
+const (
+	aGo     = "package t\n\nfunc A() int { return 1 }\n"
+	aTestGo = "package t\n\nimport \"testing\"\n\nfunc TestA(t *testing.T) {\n\tif A() != 1 {\n\t\tt.Fatal(\"A\")\n\t}\n}\n"
+)
+
+func TestTDDWantsTheNewTestsToFailOnTheCommitTheTaskStartedFrom(t *testing.T) {
+	start := map[string]string{"go.mod": goMod, "a.go": aGo, "a_test.go": aTestGo}
+	cases := []struct {
+		name  string
+		files map[string]string
+		pass  bool
+		want  string
+	}{
+		{"code and a test that needs it", map[string]string{"b.go": "package t\n\nfunc B() int { return 2 }\n",
+			"b_test.go": "package t\n\nimport \"testing\"\n\nfunc TestB(t *testing.T) {\n\tif B() != 2 {\n\t\tt.Fatal(\"B\")\n\t}\n}\n"}, true, "fail on the commit the task started from"},
+		{"code with no test", map[string]string{"b.go": "package t\n\nfunc B() int { return 2 }\n"}, false, "changed without a new or changed test"},
+		{"a test that passes before the code", map[string]string{"c_test.go": "package t\n\nimport \"testing\"\n\nfunc TestAgain(t *testing.T) {\n\tif A() != 1 {\n\t\tt.Fatal(\"A\")\n\t}\n}\n"}, false, "test nothing new"},
+		{"a changed test that fails before the code", map[string]string{"a.go": "package t\n\nfunc A() int { return 3 }\n",
+			"a_test.go": strings.Replace(aTestGo, "A() != 1", "A() != 3", 1)}, true, "fail on the commit the task started from"},
+		{"only generated code", map[string]string{"gen.go": "// Code generated by sqlc. DO NOT EDIT.\n\npackage t\n\nvar G = 1\n"}, true, "no Go code changed"},
+		{"only a document", map[string]string{"README.md": "x\n"}, true, "no Go code changed"},
+		{"only a test behind the integration tag", map[string]string{"db_test.go": "//go:build integration\n\npackage t\n\nimport \"testing\"\n\nfunc TestDB(t *testing.T) {}\n"}, true, "cannot be shown to fail"},
+	}
+	for _, c := range cases {
+		dir := repo(t, start)
+		work(t, dir, c.files)
+		code, out := script(t, dir, "", "go-tdd.sh")
+		if (code == 0) != c.pass || !strings.Contains(out, c.want) {
+			t.Errorf("%s: exit %d, want pass=%v and %q\n%s", c.name, code, c.pass, c.want, out)
+		}
+	}
+	// Nothing changed on the branch: nothing to check.
+	dir := repo(t, start)
+	git(t, dir, "switch", "-q", "-c", "work")
+	if code, out := script(t, dir, "", "go-tdd.sh"); code != 0 || !strings.Contains(out, "no Go code changed") {
+		t.Errorf("an unchanged branch: exit %d\n%s", code, out)
+	}
+	// The leaf's own tree is left as it was: the check works in a folder of its own.
+	dir = repo(t, start)
+	work(t, dir, map[string]string{"c_test.go": "package t\n\nimport \"testing\"\n\nfunc TestAgain(t *testing.T) {}\n"})
+	script(t, dir, "", "go-tdd.sh")
+	if st := git(t, dir, "status", "--porcelain"); st != "" {
+		t.Errorf("the check left the leaf changed:\n%s", st)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTDDWantsTheNewTestsToFailOnTheCommitTheTaskStartedFrom (0.22s)
    checks_test.go:217: code and a test that needs it: exit 127, want pass=true and "fail on the commit the task started from"
        bash: /tmp/tmp.7hk41Ij7m2/v0-T220/helheim-go/devcontainer/checks/go-tdd.sh: No such file or directory
    checks_test.go:217: code with no test: exit 127, want pass=false and "changed without a new or changed test"
```

- [ ] **Step 3:** write the code.

Write `devcontainer/checks/go-tdd.sh` (executable):

```sh
#!/bin/bash
# The TDD check, the other half of rung 2 (spec §9.5): the tests a change adds or changes MUST fail on the
# commit it started from. It builds that commit in a folder of its own, puts the change's test files on it,
# and runs their packages: they have to fail (a test of code that is not there yet fails to compile, which
# counts). A change to Go code without a new or changed test is refused. Tests behind the integration tag
# need a database and cannot be run here; a change that only has those is passed with a note, and the
# reviewers look at it. Generated files are not code that needs a test. Run in the leaf's top folder, on the
# run branch; main is where the task started from.
set -euo pipefail
base="$(git merge-base HEAD main)" || { echo "tdd: this leaf has no main to compare with"; exit 1; }
generated() { head -n 5 "$1" | grep -q 'Code generated'; }
integration() { head -n 5 "$1" | grep -q '^//go:build .*integration'; }

tests=() code=() skipped=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  if integration "$f"; then skipped+=("$f"); else tests+=("$f"); fi
done < <(git diff --name-only --diff-filter=AM "$base" HEAD -- '*_test.go')
while IFS= read -r f; do
  [ -f "$f" ] || continue
  generated "$f" || code+=("$f")
done < <(git diff --name-only --diff-filter=AM "$base" HEAD -- '*.go' ':!*_test.go')

if [ ${#tests[@]} -eq 0 ]; then
  if [ ${#code[@]} -gt 0 ] && [ ${#skipped[@]} -eq 0 ]; then
    echo "tdd: Go code changed without a new or changed test:"
    printf '  %s\n' "${code[@]}"
    echo "Write the test first, see it fail, then write the code."
    exit 1
  fi
  if [ ${#skipped[@]} -gt 0 ]; then
    echo "tdd: only tests behind the integration tag changed, and they need a database; they cannot be shown to fail here:"
    printf '  %s\n' "${skipped[@]}"
  else
    echo "tdd: no Go code changed"
  fi
  exit 0
fi

parent="$(mktemp -d)"
trap 'rm -rf -- "$parent"' EXIT
git archive "$base" | tar -x -C "$parent"
for f in "${tests[@]}"; do
  mkdir -p "$parent/$(dirname "$f")"
  cp -- "$f" "$parent/$f"
done
pkgs="$(printf '%s\n' "${tests[@]}" | xargs -n1 dirname | sort -u | sed 's|^\([^.]\)|./\1|; s|^\.$|./.|')"
log="$parent/.tdd.log"
# shellcheck disable=SC2086 # the packages are words
if (cd "$parent" && go test -count=1 $pkgs) >"$log" 2>&1; then
  echo "tdd: the new tests pass on the commit the task started from, so they test nothing new:"
  printf '  %s\n' "${tests[@]}"
  echo "A test of new behaviour fails before the code for it exists. Change the tests so they do."
  exit 1
fi
echo "tdd: the new tests fail on the commit the task started from, as they must:"
printf '  %s\n' "${tests[@]}"
tail -n 12 "$log"
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T221: the contract, security and integration rungs for a Go leaf, tried with the real tools on the template

Rung 3 lints the contract, checks the generated code and lists the breaking changes since the task started (a breaking change is listed, not refused: the consumers must follow, and the task says so). Rung 4 asks `govulncheck` and OSV. Rung 5 for the API runs the integration tests against the Postgres the sandbox starts. The scripts were run with the real tools on the template and on the code of the smoke run (v0-H15's first task); the tests below use stand-ins for the tools, to check the scripts' own logic.

**Files (in `helheim-go`):**
- Create: `devcontainer/checks/go-contract.sh`, `devcontainer/checks/go-integration.sh`, `devcontainer/checks/go-security.sh`
- Modify: `checks_test.go`

**Interfaces:**
- Produces: `devcontainer/checks/go-contract.sh` (`vacuum lint` at error severity, `sqlc diff`, and `oasdiff breaking` against the commit the task started from, read as JSON: `[]` is none), `go-security.sh` (`govulncheck` with and without the integration tag, `osv-scanner scan source -L go.mod`) and `go-integration.sh` (waits for Postgres at `YGG_DB_HOST`/`YGG_DB_PORT`, `postgres:5432` by default, for `YGG_DB_WAIT` seconds; then `go test -race -tags integration` with `YGG_DATABASE_URL` set to a database `app` as the user `postgres` with no password).

**Acceptance criteria:**
- [ ] A lint error, generated code that is out of date and a missing contract fail; a breaking change is printed with `BREAKING` and does not fail; a contract that is new has nothing to break.
- [ ] A vulnerability found by either tool fails the rung.
- [ ] With the database answering the tagged tests run and see its address; with none the rung fails after the wait, naming the host and port.

**Named test:** `go test . -run 'TestContractLintsTheContractChecksGeneratedCodeAndListsBreakingChanges|TestSecurityStopsOnAVulnerabilityFromEitherSource|TestIntegrationWaitsForPostgresAndRunsTheTaggedTestsWithItsAddress'` in `helheim-go`. **Layer:** `helheim-go`. **Size:** M (129). **Depends on:** v0-T220.

- [ ] **Step 1:** write the tests.

Apply to `checks_test.go`:

```diff
diff --git a/checks_test.go b/checks_test.go
index 31154d5..28eb189 100644
--- a/checks_test.go
+++ b/checks_test.go
@@ -2,9 +2,11 @@ package helheim
 
 import (
 	"bytes"
+	"net"
 	"os"
 	"os/exec"
 	"path/filepath"
+	"strconv"
 	"strings"
 	"testing"
 )
@@ -235,3 +237,76 @@ func TestTDDWantsTheNewTestsToFailOnTheCommitTheTaskStartedFrom(t *testing.T) {
 		t.Errorf("the check left the leaf changed:\n%s", st)
 	}
 }
+
+func TestContractLintsTheContractChecksGeneratedCodeAndListsBreakingChanges(t *testing.T) {
+	start := map[string]string{"openapi.yaml": "openapi: 3.1.0\n", "sqlc.yaml": "version: \"2\"\n"}
+	dir := repo(t, start)
+	work(t, dir, map[string]string{"openapi.yaml": "openapi: 3.1.0\ninfo: {}\n"})
+	bin := stubs(t, "vacuum", "sqlc", "oasdiff")
+	code, out := script(t, dir, bin, "go-contract.sh", `STUB_OASDIFF_OUT=[{"id":"response-success-status-removed","text":"DELETE /x removed"}]`)
+	got := calls(bin)
+	for _, want := range []string{"vacuum lint --no-style --details --fail-severity error openapi.yaml", "sqlc diff", "oasdiff breaking "} {
+		if !strings.Contains(got, want) {
+			t.Errorf("the tools were called %q, want %q", got, want)
+		}
+	}
+	if code != 0 || !strings.Contains(out, "BREAKING") || !strings.Contains(out, "DELETE /x removed") || !strings.Contains(got, "oasdiff breaking") {
+		t.Errorf("a breaking change is listed and not refused: exit %d\n%s", code, out)
+	}
+	bin = stubs(t, "vacuum", "sqlc", "oasdiff")
+	if code, out := script(t, dir, bin, "go-contract.sh", "STUB_OASDIFF_OUT=[]"); code != 0 || !strings.Contains(out, "none") || strings.Contains(out, "BREAKING") {
+		t.Errorf("no breaking change: exit %d\n%s", code, out)
+	}
+	for name, env := range map[string]string{"a lint error": "STUB_VACUUM_EXIT=1", "generated code that is out of date": "STUB_SQLC_EXIT=1"} {
+		if code, out := script(t, dir, stubs(t, "vacuum", "sqlc", "oasdiff"), "go-contract.sh", env); code == 0 {
+			t.Errorf("%s passed:\n%s", name, out)
+		}
+	}
+	if code, out := script(t, repo(t, map[string]string{"a.txt": "x"}), stubs(t, "vacuum", "sqlc", "oasdiff"), "go-contract.sh"); code == 0 || !strings.Contains(out, "no openapi.yaml") {
+		t.Errorf("a leaf with no contract: exit %d\n%s", code, out)
+	}
+	// A contract that did not exist when the task started is new, with nothing to break.
+	fresh := repo(t, map[string]string{"sqlc.yaml": "x"})
+	work(t, fresh, map[string]string{"openapi.yaml": "openapi: 3.1.0\n"})
+	bin = stubs(t, "vacuum", "sqlc", "oasdiff")
+	if code, out := script(t, fresh, bin, "go-contract.sh"); code != 0 || !strings.Contains(out, "is new in this change") || strings.Contains(calls(bin), "oasdiff") {
+		t.Errorf("a new contract: exit %d, calls %q\n%s", code, calls(bin), out)
+	}
+}
+
+func TestSecurityStopsOnAVulnerabilityFromEitherSource(t *testing.T) {
+	dir := leaf(t, map[string]string{"go.mod": goMod})
+	bin := stubs(t, "govulncheck", "osv-scanner")
+	if code, out := script(t, dir, bin, "go-security.sh"); code != 0 {
+		t.Fatalf("a clean leaf: exit %d\n%s", code, out)
+	}
+	for _, want := range []string{"govulncheck ./...", "govulncheck -tags integration ./...", "osv-scanner scan source -L go.mod"} {
+		if !strings.Contains(calls(bin), want) {
+			t.Errorf("calls %q lack %q", calls(bin), want)
+		}
+	}
+	for _, env := range []string{"STUB_GOVULNCHECK_EXIT=3", "STUB_OSV_SCANNER_EXIT=1"} {
+		if code, _ := script(t, dir, stubs(t, "govulncheck", "osv-scanner"), "go-security.sh", env); code == 0 {
+			t.Errorf("%s passed", env)
+		}
+	}
+}
+
+func TestIntegrationWaitsForPostgresAndRunsTheTaggedTestsWithItsAddress(t *testing.T) {
+	ln, err := net.Listen("tcp", "127.0.0.1:0")
+	if err != nil {
+		t.Fatal(err)
+	}
+	defer ln.Close()
+	port := ln.Addr().(*net.TCPAddr).Port
+	files := map[string]string{"go.mod": goMod, "a.go": "package t\n", "a_it_test.go": "//go:build integration\n\npackage t\n\nimport (\n\t\"os\"\n\t\"testing\"\n)\n\n" +
+		"func TestURL(t *testing.T) {\n\tif os.Getenv(\"YGG_DATABASE_URL\") != \"postgres://postgres@127.0.0.1:" + strconv.Itoa(port) + "/app?sslmode=disable\" {\n\t\tt.Fatal(os.Getenv(\"YGG_DATABASE_URL\"))\n\t}\n}\n"}
+	env := []string{"YGG_DB_HOST=127.0.0.1", "YGG_DB_PORT=" + strconv.Itoa(port)}
+	if code, out := script(t, leaf(t, files), "", "go-integration.sh", env...); code != 0 {
+		t.Errorf("with a database: exit %d\n%s", code, out)
+	}
+	ln.Close()
+	if code, out := script(t, leaf(t, files), "", "go-integration.sh", append(env, "YGG_DB_WAIT=2")...); code == 0 || !strings.Contains(out, "did not answer") {
+		t.Errorf("with no database: exit %d\n%s", code, out)
+	}
+}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestContractLintsTheContractChecksGeneratedCodeAndListsBreakingChanges (0.06s)
    checks_test.go:246: the tools were called "", want "vacuum lint --no-style --details --fail-severity error openapi.yaml"
    checks_test.go:246: the tools were called "", want "sqlc diff"
    checks_test.go:246: the tools were called "", want "oasdiff breaking "
```

- [ ] **Step 3:** write the code.

Write `devcontainer/checks/go-contract.sh` (executable):

```sh
#!/bin/bash
# Rung 3 of the ladder for a Go leaf (spec §9.5): the contract. openapi.yaml is linted, the code sqlc
# generates is what the SQL says, and the breaking changes of openapi.yaml against the commit the task
# started from are listed. A breaking change is not refused here: the consumers must follow it, and the
# task says so (it decides the pointer-contract approval point later). Run in the leaf's top folder.
set -euo pipefail
[ -f openapi.yaml ] || { echo "contract: this leaf has no openapi.yaml, and it owns the contract of its API"; exit 1; }
echo "== openapi lint"
vacuum lint --no-style --details --fail-severity error openapi.yaml
if [ -f sqlc.yaml ]; then
  echo "== generated code"
  sqlc diff || { echo "contract: the code in internal/store is not what the SQL says; run sqlc generate"; exit 1; }
fi
echo "== breaking changes since the task started"
base="$(git merge-base HEAD main)" || { echo "contract: this leaf has no main to compare with"; exit 1; }
if git cat-file -e "$base:openapi.yaml" 2>/dev/null; then
  old="$(mktemp)"
  trap 'rm -f -- "$old"' EXIT
  git show "$base:openapi.yaml" > "$old"
  if [ "$(oasdiff breaking "$old" openapi.yaml --format json)" = "[]" ]; then
    echo "none"
  else
    echo "BREAKING: consumers of this API must follow these changes; say so in your summary."
    oasdiff breaking "$old" openapi.yaml
  fi
else
  echo "openapi.yaml is new in this change"
fi
```

Write `devcontainer/checks/go-integration.sh` (executable):

```sh
#!/bin/bash
# Rung 5 of the ladder for a Go leaf: the tests that need the services the sandbox starts beside this
# container. It waits for Postgres (host postgres, port 5432, unless YGG_DB_HOST and YGG_DB_PORT say
# otherwise; YGG_DB_WAIT seconds, 60 by default), then runs the tests behind the integration tag. The
# database has no password: the sandbox starts it for this run alone, on a network with no route out.
set -euo pipefail
host="${YGG_DB_HOST:-postgres}" port="${YGG_DB_PORT:-5432}" wait_s="${YGG_DB_WAIT:-60}"
up=0
for ((i = 0; i < wait_s; i++)); do
  if (exec 3<>"/dev/tcp/$host/$port") 2>/dev/null; then up=1; break; fi
  sleep 1
done
[ "$up" -eq 1 ] || { echo "integration: Postgres at $host:$port did not answer in ${wait_s}s"; exit 1; }
export YGG_DATABASE_URL="postgres://postgres@$host:$port/app?sslmode=disable"
export YGG_S3_ENDPOINT="${YGG_S3_ENDPOINT:-http://seaweedfs:8333}"
go test -race -count=1 -tags integration ./...
```

Write `devcontainer/checks/go-security.sh` (executable):

```sh
#!/bin/bash
# Rung 4 of the ladder for a Go leaf (spec §9.5, §9.6): known vulnerabilities, in the code that is called
# (govulncheck) and in the modules that are required (OSV). Secrets are scanned by Odin before every
# checkpoint, and the product's own security tests run with the unit tests. Run in the leaf's top folder.
set -euo pipefail
echo "== govulncheck"
govulncheck ./...
govulncheck -tags integration ./...
echo "== OSV"
osv-scanner scan source -L go.mod
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T222: the helheim-go pack: the recipe of a Go API leaf, its ladder and its services

The pack ties the realm together: the leaf recipe every build realm offers under the same names (template, implementer prompt, the ladder by name), the services an API needs, and the sandbox. It has no graph: a run takes its graph from its lead realm. The implementer prompt is what a task's implementer is told about this leaf.

**Files (in `helheim-go`):**
- Create: `pack.yaml`, `pack_test.go`, `prompts/implementer.md`

**Interfaces:**
- Produces: `pack.yaml` (`version: 0.1.0`; the checks `static`, `unit`, `tdd`, `contract`, `security`, `integration`, each one script in `/opt/ygg/checks`; `leaf.checks` in that order, cheap rungs first; `services.postgres` (17.10, by digest, `POSTGRES_DB=app`, `POSTGRES_HOST_AUTH_METHOD=trust`, port 5432) and `services.seaweedfs` (4.45, by digest, command `server -s3 -dir=/data`, port 8333); `sandbox.build: devcontainer` with the hosts the checks reach: the Go proxy and checksum database, `vuln.go.dev`, `api.osv.dev`) and `prompts/implementer.md`.
- The prompt tells the implementer to read `AGENTS.md`, to write the test first, to keep the contract with the code, to go through `sqlc`, to treat every input as hostile, which commands to run before it stops, and what it must not do (commit, change the checks or the devcontainer, leave the repository).

**Acceptance criteria:**
- [ ] The pack loads through Gungnir's schema; its stack tag is a local tag of `helheim-go`; every check runs one script that the Containerfile bakes in, and every baked script is used.
- [ ] The services are the ones an API asks for, pinned by digest, and `go-integration.sh` connects to what the pack starts.
- [ ] The commands the prompt tells the implementer to run are the ones the ladder runs.

**Named test:** `go test . -run 'TestThePackLoadsAndOffersTheRecipeEveryBuildRealmOffers|TestEveryCheckRunsAScriptThatTheStackImageBakesIn|TestTheServicesAreWhatAnAPIAsksForAndPinnedByDigest|TestTheImplementerPromptTellsWhatTheFactoryChecksAndWhatNotToDo'` in `helheim-go`. **Layer:** `helheim-go`. **Size:** M (205). **Depends on:** v0-T221.

- [ ] **Step 1:** write the tests.

Write `pack_test.go`:

```go
package helheim

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

func TestThePackLoadsAndOffersTheRecipeEveryBuildRealmOffers(t *testing.T) {
	p, err := schema.LoadPack(".")
	if err != nil {
		t.Fatalf("LoadPack() = %v", err)
	}
	if p.Name != "helheim-go" || p.Graph != "" {
		t.Errorf("name %q, graph %q; helheim-go provides leaves and has no graph in v0", p.Name, p.Graph)
	}
	r := p.Leaf
	if r == nil || r.Template != "templates/api" || r.Implementer != "prompts/implementer.md" {
		t.Fatalf("leaf recipe = %+v", r)
	}
	want := []string{"static", "unit", "tdd", "contract", "security", "integration"}
	if strings.Join(r.Checks, ",") != strings.Join(want, ",") {
		t.Errorf("the ladder is %v, want %v: cheap rungs first, the one that needs services last", r.Checks, want)
	}
	ref, err := p.StackRef(".")
	if err != nil || !regexp.MustCompile(`^localhost/ygg-stack-helheim-go:[0-9a-f]{12}$`).MatchString(ref) {
		t.Errorf("StackRef() = %q, %v; the stack is built from devcontainer/", ref, err)
	}
	if !gungnir.ValidStack(ref) {
		t.Errorf("%q is not a stack a sandbox can start on", ref)
	}
	for _, h := range p.Sandbox.Egress {
		if !gungnir.ValidHost(h) {
			t.Errorf("egress %q is not a plain host", h)
		}
	}
}

func TestEveryCheckRunsAScriptThatTheStackImageBakesIn(t *testing.T) {
	p, err := schema.LoadPack(".")
	if err != nil {
		t.Fatal(err)
	}
	for name, argv := range p.Checks {
		if len(argv) != 1 || !strings.HasPrefix(argv[0], "/opt/ygg/checks/") {
			t.Errorf("check %s is %v; it must be one script in /opt/ygg/checks, which the agent cannot edit", name, argv)
			continue
		}
		st, err := os.Stat(filepath.Join("devcontainer", "checks", filepath.Base(argv[0])))
		if err != nil || st.Mode()&0o111 == 0 {
			t.Errorf("check %s names %s, which devcontainer/checks does not hold as an executable: %v", name, argv[0], err)
		}
	}
	entries, _ := os.ReadDir(filepath.Join("devcontainer", "checks"))
	for _, e := range entries {
		used := e.Name() == "docs.sh" // run by go-static.sh
		for _, argv := range p.Checks {
			used = used || filepath.Base(argv[0]) == e.Name()
		}
		if !used {
			t.Errorf("devcontainer/checks/%s is baked into the image and no check runs it", e.Name())
		}
	}
}

func TestTheServicesAreWhatAnAPIAsksForAndPinnedByDigest(t *testing.T) {
	p, err := schema.LoadPack(".")
	if err != nil {
		t.Fatal(err)
	}
	svc := map[string]gungnir.Service{}
	for _, s := range p.ServiceList() {
		svc[s.Name] = s
	}
	pg, s3 := svc["postgres"], svc["seaweedfs"]
	if len(svc) != 2 || pg.Ports[0] != 5432 || s3.Ports[0] != 8333 {
		t.Fatalf("services = %+v; an API gets Postgres on 5432 and SeaweedFS's S3 on 8333", svc)
	}
	if pg.Env["POSTGRES_DB"] != "app" || pg.Env["POSTGRES_HOST_AUTH_METHOD"] != "trust" {
		t.Errorf("postgres env = %v; go-integration.sh connects to database app as postgres, with no password", pg.Env)
	}
	if len(s3.Command) == 0 || s3.Command[0] != "server" {
		t.Errorf("seaweedfs command = %v; the image does nothing without one", s3.Command)
	}
	if err := gungnir.ValidateServices(p.ServiceList()); err != nil {
		t.Error(err)
	}
}

func TestTheImplementerPromptTellsWhatTheFactoryChecksAndWhatNotToDo(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("prompts", "implementer.md"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(b)
	scripts := map[string]string{}
	for _, f := range []string{"go-static.sh", "go-unit.sh", "go-contract.sh"} {
		s, _ := os.ReadFile(filepath.Join("devcontainer", "checks", f))
		scripts[f] = string(s)
	}
	// What the prompt tells the implementer to run is what the ladder runs.
	for cmd, script := range map[string]string{"gofmt -l .": "go-static.sh", "go vet ./...": "go-static.sh", "golangci-lint run": "go-static.sh",
		"go test -race ./...": "go-unit.sh", "sqlc diff": "go-contract.sh"} {
		if !strings.Contains(text, cmd) || !strings.Contains(scripts[script], strings.Fields(cmd)[0]) {
			t.Errorf("the prompt and %s disagree about %q", script, cmd)
		}
	}
	for _, want := range []string{"AGENTS.md", "Test first", "Do not run `git commit`", "openapi.yaml", "sqlc generate", ".devcontainer/", "Findings to fix"} {
		if !strings.Contains(text, want) {
			t.Errorf("the prompt lacks %q", want)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestThePackLoadsAndOffersTheRecipeEveryBuildRealmOffers (0.00s)
    pack_test.go:17: LoadPack() = open pack.yaml: no such file or directory
--- FAIL: TestEveryCheckRunsAScriptThatTheStackImageBakesIn (0.00s)
    pack_test.go:47: open pack.yaml: no such file or directory
```

- [ ] **Step 3:** write the code.

Write `pack.yaml`:

```yaml
# The Go flavor of the Helheim realm (change realm-leaf-naming): the recipe of a Go API leaf and the
# services an API needs. It has no graph: a run takes its graph from its lead realm (midgard-react for the
# client gallery). The check ladder is rungs 1 to 5 of spec §9.5; the reviewers (rung 6) are the lead
# realm's, and rung 7 is the grader's.
name: helheim-go
version: 0.1.0
checks:
  static: [/opt/ygg/checks/go-static.sh]
  unit: [/opt/ygg/checks/go-unit.sh]
  tdd: [/opt/ygg/checks/go-tdd.sh]
  contract: [/opt/ygg/checks/go-contract.sh]
  security: [/opt/ygg/checks/go-security.sh]
  integration: [/opt/ygg/checks/go-integration.sh]
leaf:
  description: A Go HTTP API that owns its OpenAPI contract
  template: templates/api
  first_commit: [LICENSE]
  implementer: prompts/implementer.md
  checks: [static, unit, tdd, contract, security, integration]
services:
  postgres:
    image: docker.io/library/postgres:17.10-bookworm@sha256:9b18b78397054fce88a9552e9d5a3ad5bb7fd258c5b3cc1c5028e46373d6ea8f
    env: { POSTGRES_DB: app, POSTGRES_HOST_AUTH_METHOD: trust }
    ports: [5432]
  seaweedfs:
    image: docker.io/chrislusf/seaweedfs:4.45@sha256:fc9f76fa993ad69966ffeb2f65d0318fcae39c6f8e20cf68ef7b3a5cb97769e5
    command: [server, -s3, -dir=/data]
    ports: [8333]
sandbox:
  build: devcontainer
  egress: [proxy.golang.org, sum.golang.org, vuln.go.dev, api.osv.dev]
```

Write `prompts/implementer.md`:

````md
# Implementer: Go API leaf

You build one task in a Go HTTP API. You work in the repository you start in. It is one leaf of a product;
you see this leaf and your task, nothing else. The task below says what to build, the acceptance criteria
and the test that proves it.

## Before you write code

1. Read `AGENTS.md`. It holds the rules of this leaf. They bind you.
2. Read `openapi.yaml`, the routes in `internal/httpapi` and the layout of `internal/store`. Find where
   the task belongs. Follow the style of the code that is there.
3. Read the findings under "Findings to fix" if the prompt has that section. Fix every one of them.

## How to work

- **Test first.** Write the test the task names before the code. Run it and see it fail for the reason
  the task gives. Then write the least code that makes it pass. A test that passes before your code
  exists proves nothing, and the factory refuses it.
- **One task, nothing more.** Build what the acceptance criteria say. Do not add routes, options or
  dependencies the task does not need. The standard library comes first.
- **The contract moves with the code.** A route or a field you add or change is described in
  `openapi.yaml` in the same change. If a change removes something a consumer may use, say so in your
  summary.
- **Data goes through sqlc.** Write the SQL in `db/queries`, a migration in `internal/store/migrations`
  as a new file, and run `sqlc generate`. Do not edit generated files.
- **Treat every input as hostile.** Check what comes in: sizes, types, ranges, ids, content types. Answer
  JSON errors with the right status. Check that the caller may touch the resource in the handler, even
  if middleware checked it too. Build storage keys on the server from the user and the resource; never
  use a key a client sends.
- **Secrets.** Write none into code, tests, logs or docs. A test uses made-up values.

## Check your work before you stop

Run these in the repository and fix what they say:

```
gofmt -l .          # prints nothing
go vet ./...
go test -race ./...
golangci-lint run
sqlc diff
```

You do not need a database for these. Tests that need one carry `//go:build integration`; the factory
runs them in a sandbox that starts one. Write them when the task is about data.

## What you must not do

- Do not run `git commit`, `git checkout`, `git reset` or any other command that changes history or
  branches. The factory commits your work after you stop.
- Do not change `.devcontainer/`, `.golangci.yml`, or any script or tool that checks your work. If a
  check seems wrong, say so in your summary and leave it.
- Do not read or change files outside this repository.

When you are done, answer with a short summary: what you built, which tests prove it, and anything a
reviewer should look at first.
````

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T223: helheim-go's documentation

The architecture page and the README say what the realm holds and how it is tested.

**Files (in `helheim-go`):**
- Modify: `README.md`, `docs/architecture.md`

**Acceptance criteria:**
- [ ] `docs/architecture.md` lists the pack, the Containerfile, the scripts, the template and the prompt, and says how the tests run and what they need.

**Named test:** `git diff --stat -- docs/architecture.md README.md` in `helheim-go`. **Layer:** `helheim-go`. **Size:** S (29). **Depends on:** v0-T222.

- [ ] **Step 1:** write the code.

Apply to `README.md`:

````diff
diff --git a/README.md b/README.md
index 5003c61..13091e8 100644
--- a/README.md
+++ b/README.md
@@ -13,6 +13,12 @@ go test ./...
 go vet ./...
 ```
 
+## What it holds
+
+The recipe of a Go API leaf for the factory: a template, a stack image with the check ladder's tools, the
+ladder's scripts, an implementer prompt and the services an API needs. A run loads it by name from the realm
+store and builds its leaves in it. See [the architecture](docs/architecture.md).
+
 ## Docs
 
 - Architecture: [docs/architecture.md](docs/architecture.md)
````

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index 3c1b3c4..cbf7965 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -23,6 +23,29 @@ proposal `2026-10-17-realm-leaf-naming`).
   gallery); a backend-only product would add one here later.
 - Its templates are copied into products, so they are MIT-licensed (`templates/`).
 
+## What is here
+
+- `pack.yaml`: the recipe (template, implementer prompt, the check ladder by name), the services
+  (Postgres and SeaweedFS, by digest) and the sandbox: a stack built from `devcontainer/`, and the hosts
+  the checks reach (the Go proxy and checksum database, the vulnerability databases).
+- `devcontainer/Containerfile`: the stack layer: Go 1.26.9, `golangci-lint`, `sqlc`, `oasdiff`, `vacuum`,
+  `osv-scanner` and `govulncheck`, every download checked against a recorded SHA-256, and the ladder's
+  scripts in `/opt/ygg/checks`, read-only for the agent. `ygg sandbox build --realm helheim-go` builds it.
+- `devcontainer/checks/`: the ladder: `go-static.sh` (gofmt, vet, lint, docs) and `go-unit.sh`,
+  `go-tdd.sh` (new tests fail on the commit the task started from), `go-contract.sh` (OpenAPI lint,
+  generated code, breaking changes), `go-security.sh` (`govulncheck`, OSV) and `go-integration.sh`
+  (tests that need Postgres). Rung 6 is the lead realm's reviewers; rung 7 is the grader's.
+- `templates/api/`: the leaf a new API starts from: a server with a health route, its contract, a
+  store with migrations and `sqlc`, and the rules of the leaf in its `AGENTS.md`.
+- `prompts/implementer.md`: what the implementer of a task in this leaf is told.
+
+## Tests
+
+`go test ./...` runs the scripts on small leaves made in a temp dir, with the real `go` and `git` and
+stand-ins for the image's tools; it builds and tests the template, which needs the Go module proxy the
+first time (set `YGG_REQUIRE_TEMPLATES` to fail instead of skipping when it cannot be reached). The
+image itself and the tools in it are checked on a real engine (Phase 5b, v0-H14).
+
 ## Depends on
 
 - Gungnir's schemas.
```

- [ ] **Step 2:** run the named test. Expect `ok`.

- [ ] **Step 3:** commit (see "How each task lands").

---

### Task v0-T224: the React web template: Vite, TypeScript, Tailwind, TanStack, a typed API client and a first tested component

midgard-react's first task. Branch `realm/content` from `main` in `midgard-react`, before step 1. This task has no Go test: its test is Vitest's, run in `templates/web`. Copy `package-lock.json` from the reference workspace (the plan leaves lock files out; the copy is the reviewed one), or run `npm install --package-lock-only` and say in the PR that the transitive versions are new. A new web leaf starts from this template (`init` copies it). It is the stack of spec §9.2 in small: React 19, Vite, TypeScript (strict), Tailwind 4, shadcn/ui-style base components, TanStack Router and Query, and a client typed by the API contract (`openapi-typescript` and `openapi-fetch`). Every dependency is at one exact version. TypeScript is 5.9.3 because `openapi-typescript` 7 asks for TypeScript 5 (backlog B-045).

**Files (in `midgard-react`):**
- Create: `templates/web/components.json`, `templates/web/contracts/api.openapi.yaml`, `templates/web/eslint.config.js`, `templates/web/index.html`, `templates/web/package.json`, `templates/web/src/api/schema.d.ts`, `templates/web/src/components/health-badge.tsx`, `templates/web/src/components/ui/button.tsx`, `templates/web/src/health.test.tsx`, `templates/web/src/index.css`, `templates/web/src/lib/api.ts`, `templates/web/src/lib/utils.ts`, `templates/web/src/main.tsx`, `templates/web/src/router.tsx`, `templates/web/src/routes/index.tsx`, `templates/web/src/test-setup.ts`, `templates/web/tsconfig.json`, `templates/web/vite.config.ts`

**Interfaces:**
- Produces: `package.json` (scripts `dev`, `build`, `preview`, `lint`, `typecheck`, `test`, `test:e2e`, `gen:api`), `tsconfig.json`, `vite.config.ts` (the React and Tailwind plugins, the Vitest environment, and a proxy of `/api` to `API_URL` for the dev and preview servers), `eslint.config.js`, `components.json`, `index.html`, and `src/`: `main.tsx`, `router.tsx`, `routes/index.tsx` (the home page), `components/health-badge.tsx` (what `/healthz` says), `components/ui/button.tsx`, `lib/api.ts` (the typed client), `lib/utils.ts`, `api/schema.d.ts` (generated, committed) and `test-setup.ts`; `contracts/api.openapi.yaml`, the copy of the API's contract.
- `api` is `createClient<paths>` with an absolute base URL (`new URL("/api", window.location.origin)`: a relative one is refused by `Request` outside a browser) and a `fetch` that looks `globalThis.fetch` up at each call (the library keeps the one it finds when the client is made, so a test could not replace it).

**Acceptance criteria:**
- [ ] `npm ci`, `npm run typecheck`, `npm run lint`, `npm test` and `npm run build` pass in the folder.
- [ ] `HealthBadge` says `API: ok` for a 200, `API: database unavailable` for a 503 with that body, and `API: not reachable` when the request fails.
- [ ] `npm run gen:api` changes nothing: `src/api/schema.d.ts` is what the contract generates.

**Named test:** `npm test (in templates/web)` in `midgard-react`. **Layer:** `midgard-react`. **Size:** M (392). **Depends on:** Phase 5a.

- [ ] **Step 1:** write the tests.

Write `templates/web/src/health.test.tsx`:

```tsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { HealthBadge } from "@/components/health-badge";

function renderBadge() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <HealthBadge />
    </QueryClientProvider>,
  );
}

function answer(status: number, body: unknown) {
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } })),
  );
}

describe("HealthBadge", () => {
  it("says the API is ok when /healthz says ok", async () => {
    answer(200, { status: "ok" });
    renderBadge();
    expect(await screen.findByText("API: ok")).toBeInTheDocument();
  });

  it("says the API is down when the database is unavailable", async () => {
    answer(503, { status: "database unavailable" });
    renderBadge();
    expect(await screen.findByText("API: database unavailable")).toBeInTheDocument();
  });

  it("says the API cannot be reached when the request fails", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => Promise.reject(new TypeError("network"))));
    renderBadge();
    expect(await screen.findByText("API: not reachable")).toBeInTheDocument();
  });
});
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
 FAIL  src/health.test.tsx [ src/health.test.tsx ]
Error: Failed to resolve import "@/components/health-badge" from "src/health.test.tsx". Does the file exist?
  Plugin: vite:import-analysis
```

- [ ] **Step 3:** write the code.

Write `templates/web/components.json`:

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "rsc": false,
  "tsx": true,
  "tailwind": { "config": "", "css": "src/index.css", "baseColor": "neutral", "cssVariables": true },
  "aliases": { "components": "@/components", "utils": "@/lib/utils", "ui": "@/components/ui", "lib": "@/lib", "hooks": "@/hooks" }
}
```

Write `templates/web/contracts/api.openapi.yaml`:

```yaml
openapi: 3.1.0
info:
  title: API
  version: 0.1.0
  description: The contract of this API. It is the source of truth for every consumer (spec §9.2).
servers:
  - url: http://localhost:8080
paths:
  /healthz:
    get:
      operationId: getHealth
      summary: Is the server up
      responses:
        "200":
          description: The server is up.
          content:
            application/json:
              schema:
                type: object
                required: [status]
                properties:
                  status:
                    type: string
                    enum: [ok]
        "503":
          description: The server is up but its database does not answer.
          content:
            application/json:
              schema:
                type: object
                required: [status]
                properties:
                  status:
                    type: string
                    enum: [database unavailable]
```

Write `templates/web/eslint.config.js`:

```js
import js from "@eslint/js";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist", "node_modules", "playwright-report", "test-results", "src/api/schema.d.ts"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ["**/*.{ts,tsx}"],
    languageOptions: { globals: { ...globals.browser, ...globals.node } },
    plugins: { "react-hooks": reactHooks },
    rules: { ...reactHooks.configs.recommended.rules },
  },
);
```

Write `templates/web/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Gallery</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

Write `templates/web/package.json`:

```json
{
  "name": "web",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "engines": { "node": ">=22.12" },
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit && vite build",
    "preview": "vite preview",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:e2e": "playwright test",
    "gen:api": "openapi-typescript contracts/api.openapi.yaml -o src/api/schema.d.ts"
  },
  "dependencies": {
    "@radix-ui/react-slot": "1.3.3",
    "@tanstack/react-query": "5.104.1",
    "@tanstack/react-router": "1.170.41",
    "class-variance-authority": "0.7.1",
    "clsx": "2.1.1",
    "openapi-fetch": "0.17.0",
    "react": "19.3.0",
    "react-dom": "19.3.0",
    "tailwind-merge": "3.7.0"
  },
  "devDependencies": {
    "@eslint/js": "10.0.1",
    "@playwright/test": "1.63.0",
    "@tailwindcss/vite": "4.3.3",
    "@testing-library/jest-dom": "7.0.1",
    "@testing-library/react": "16.3.3",
    "@types/node": "26.6.4",
    "@types/react": "19.3.0",
    "@types/react-dom": "19.3.0",
    "@vitejs/plugin-react": "6.1.1",
    "eslint": "10.12.0",
    "eslint-plugin-react-hooks": "7.1.1",
    "globals": "17.13.0",
    "jsdom": "30.1.1",
    "openapi-typescript": "7.13.0",
    "tailwindcss": "4.3.3",
    "typescript": "5.9.3",
    "typescript-eslint": "8.71.0",
    "vite": "8.3.2",
    "vitest": "5.0.3"
  }
}
```

Write `templates/web/src/api/schema.d.ts`:

```ts
/**
 * This file was auto-generated by openapi-typescript.
 * Do not make direct changes to the file.
 */

export interface paths {
    "/healthz": {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        /** Is the server up */
        get: operations["getHealth"];
        put?: never;
        post?: never;
        delete?: never;
        options?: never;
        head?: never;
        patch?: never;
        trace?: never;
    };
}
export type webhooks = Record<string, never>;
export interface components {
    schemas: never;
    responses: never;
    parameters: never;
    requestBodies: never;
    headers: never;
    pathItems: never;
}
export type $defs = Record<string, never>;
export interface operations {
    getHealth: {
        parameters: {
            query?: never;
            header?: never;
            path?: never;
            cookie?: never;
        };
        requestBody?: never;
        responses: {
            /** @description The server is up. */
            200: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": {
                        /** @enum {string} */
                        status: "ok";
                    };
                };
            };
            /** @description The server is up but its database does not answer. */
            503: {
                headers: {
                    [name: string]: unknown;
                };
                content: {
                    "application/json": {
                        /** @enum {string} */
                        status: "database unavailable";
                    };
                };
            };
        };
    };
}
```

Write `templates/web/src/components/health-badge.tsx`:

```tsx
import { useQuery } from "@tanstack/react-query";
import { api } from "@/lib/api";

/** What /healthz says, as a short sentence. */
async function readHealth(): Promise<string> {
  const { data, error, response } = await api.GET("/healthz");
  if (data) return data.status;
  // 503 is an answer: the server is up and its database is not.
  if (error && response.status === 503) return error.status;
  throw new Error(`unexpected answer ${response.status}`);
}

export function HealthBadge() {
  const health = useQuery({ queryKey: ["health"], queryFn: readHealth, refetchInterval: 30_000 });
  const text = health.isPending ? "checking" : health.isError ? "not reachable" : health.data;
  return <p className="text-sm text-neutral-600">API: {text}</p>;
}
```

Write `templates/web/src/components/ui/button.tsx`:

```tsx
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import * as React from "react";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 disabled:pointer-events-none disabled:opacity-50",
  {
    variants: {
      variant: {
        default: "bg-neutral-900 text-white hover:bg-neutral-800",
        outline: "border border-neutral-300 bg-white hover:bg-neutral-100",
        ghost: "hover:bg-neutral-100",
      },
      size: { default: "h-9 px-4 py-2", sm: "h-8 px-3", lg: "h-10 px-6" },
    },
    defaultVariants: { variant: "default", size: "default" },
  },
);

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(({ className, variant, size, asChild = false, ...props }, ref) => {
  const Comp = asChild ? Slot : "button";
  return <Comp className={cn(buttonVariants({ variant, size, className }))} ref={ref} {...props} />;
});
Button.displayName = "Button";

export { Button, buttonVariants };
```

Write `templates/web/src/index.css`:

```css
@import "tailwindcss";
```

Write `templates/web/src/lib/api.ts`:

```ts
import createClient from "openapi-fetch";
import type { paths } from "@/api/schema";

/**
 * The API client, typed by contracts/api.openapi.yaml. Calls go to /api, which the dev and preview servers
 * forward to the API (see vite.config.ts) and a deployment routes to it, so the browser needs no CORS. The
 * URL is absolute because the Fetch API's Request refuses a relative one outside a browser, in the tests.
 */
export const api = createClient<paths>({
  baseUrl: new URL("/api", window.location.origin).href,
  // openapi-fetch keeps the fetch it finds when the client is made; this one looks it up at each call, so a
  // test can replace it (vi.stubGlobal) after the module is loaded.
  fetch: (request) => globalThis.fetch(request),
});
```

Write `templates/web/src/lib/utils.ts`:

```ts
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

/** cn joins class names and lets the later Tailwind class win over an earlier one that conflicts. */
export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

Write `templates/web/src/main.tsx`:

```tsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { RouterProvider } from "@tanstack/react-router";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import "./index.css";
import { router } from "./router";

const client = new QueryClient();
const el = document.getElementById("root");
if (!el) throw new Error("index.html has no #root");
createRoot(el).render(
  <StrictMode>
    <QueryClientProvider client={client}>
      <RouterProvider router={router} />
    </QueryClientProvider>
  </StrictMode>,
);
```

Write `templates/web/src/router.tsx`:

```tsx
import { createRootRoute, createRoute, createRouter, Outlet } from "@tanstack/react-router";
import { Home } from "@/routes";

const root = createRootRoute({ component: () => <Outlet /> });
const index = createRoute({ getParentRoute: () => root, path: "/", component: Home });

/** The routes of the app. A page is a route here and a component under src/routes. */
export const router = createRouter({ routeTree: root.addChildren([index]) });

declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
```

Write `templates/web/src/routes/index.tsx`:

```tsx
import { HealthBadge } from "@/components/health-badge";
import { Button } from "@/components/ui/button";

export function Home() {
  return (
    <main className="mx-auto max-w-3xl p-8">
      <h1 className="text-2xl font-semibold">Gallery</h1>
      <HealthBadge />
      <Button className="mt-4" variant="outline" onClick={() => window.location.reload()}>
        Reload
      </Button>
    </main>
  );
}
```

Write `templates/web/src/test-setup.ts`:

```ts
import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach, vi } from "vitest";

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
```

Write `templates/web/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2023",
    "lib": ["ES2023", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "isolatedModules": true,
    "skipLibCheck": true,
    "noEmit": true,
    "types": ["vite/client", "node"],
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] }
  },
  "include": ["src", "e2e", "vite.config.ts", "playwright.config.ts"]
}
```

Write `templates/web/vite.config.ts`:

```ts
import path from "node:path";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

// The API is at API_URL (the mock in a task's loop, the real server in the acceptance run). The browser
// calls it through /api so it never needs CORS, and the dev and preview servers forward the calls.
const api = process.env.API_URL ?? "http://localhost:8080";
const proxy = { "/api": { target: api, changeOrigin: true, rewrite: (p: string) => p.replace(/^\/api/, "") } };

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": path.resolve(import.meta.dirname, "src") } },
  server: { proxy },
  preview: { proxy },
  test: { environment: "jsdom", setupFiles: ["./src/test-setup.ts"], include: ["src/**/*.test.{ts,tsx}"] },
});
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T225: the web template becomes a repo of the factory: its rules, licence, editor config, e2e setup, and a test that builds it

What a leaf of the factory carries beyond its code: a short `AGENTS.md`, an MIT licence, an editor config that only names the image, a Playwright config and a first spec, and `init.sh`. A Go test in the realm's repo builds the template as a product would have it.

**Files (in `midgard-react`):**
- Create: `template_test.go`, `templates/web/.devcontainer/devcontainer.json`, `templates/web/.gitignore`, `templates/web/AGENTS.md`, `templates/web/LICENSE`, `templates/web/e2e/smoke.spec.ts`, `templates/web/init.sh`, `templates/web/playwright.config.ts`

**Interfaces:**
- Produces: `templates/web/AGENTS.md` (under 100 lines: the stack, test first, the contract is a copy that may lag but that the API may not break, the typed client only, every state, accessibility, no photo bytes through the API, no secret), `LICENSE` (MIT), `.gitignore`, `.devcontainer/devcontainer.json`, `init.sh`, `playwright.config.ts` (the app at `E2E_URL`, Chromium) and `e2e/smoke.spec.ts` (the home page shows `API: ok`).
- Produces: `template_test.go`: it copies the template, installs exactly what the lock file says, runs `typecheck`, `lint`, `test` and `build`, and checks that generating the types again changes nothing; it skips (fails with `YGG_REQUIRE_TEMPLATES`) when `npm` or the registry is not there. A second test checks the licence, the length of `AGENTS.md`, that every dependency is one exact version and that the editor config sets none of the keys that run or widen something.

**Acceptance criteria:**
- [ ] The template builds and passes its own checks in a copy.
- [ ] Every dependency is pinned to one version; `devcontainer.json` sets no `initializeCommand`, `postCreateCommand`, mounts, `runArgs`, features and the like.

**Named test:** `go test . -run 'TestTheWebTemplateBuildsAndPassesItsOwnChecks|TestTheWebTemplateCarriesWhatARepoOfTheFactoryNeeds'` in `midgard-react`. **Layer:** `midgard-react`. **Size:** M (212). **Depends on:** v0-T224.

- [ ] **Step 1:** write the tests.

Write `template_test.go`:

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

// copyTemplate copies templates/<name> into a temp dir, as it is in a product.
func copyTemplate(t *testing.T, name string) string {
	t.Helper()
	dst := t.TempDir()
	if err := os.CopyFS(dst, os.DirFS(filepath.Join("templates", name))); err != nil {
		t.Fatalf("templates/%s: %v", name, err)
	}
	return dst
}

func inDir(t *testing.T, dir string, tool string, args ...string) (string, error) {
	t.Helper()
	cmd := exec.Command(tool, args...)
	cmd.Dir = dir
	out, err := cmd.CombinedOutput()
	return string(out), err
}

// needPackages installs the template's packages, exactly as its lock file says, and skips the test when that
// can't be done: no npm, or no registry. YGG_REQUIRE_TEMPLATES makes it a failure instead (a CI that must not
// skip). It is the one place these tests need the network, and only on a machine without the npm cache.
func needPackages(t *testing.T, dir string) {
	t.Helper()
	if _, err := exec.LookPath("npm"); err != nil {
		if os.Getenv("YGG_REQUIRE_TEMPLATES") != "" {
			t.Fatal("npm is not installed")
		}
		t.Skip("npm is not installed (set YGG_REQUIRE_TEMPLATES to fail instead)")
	}
	if out, err := inDir(t, dir, "npm", "ci", "--no-audit", "--no-fund"); err != nil {
		if os.Getenv("YGG_REQUIRE_TEMPLATES") != "" {
			t.Fatalf("npm ci: %v\n%s", err, out)
		}
		t.Skipf("the template's packages can't be installed (set YGG_REQUIRE_TEMPLATES to fail instead): %v", err)
	}
}

func TestTheWebTemplateBuildsAndPassesItsOwnChecks(t *testing.T) {
	dir := copyTemplate(t, "web")
	needPackages(t, dir)
	for _, script := range []string{"typecheck", "lint", "test", "build"} {
		if out, err := inDir(t, dir, "npm", "run", script); err != nil {
			t.Errorf("npm run %s: %v\n%s", script, err, out)
		}
	}
	// The generated types are what the contract says: generating them again changes nothing.
	before, err := os.ReadFile(filepath.Join(dir, "src/api/schema.d.ts"))
	if err != nil {
		t.Fatal(err)
	}
	if out, err := inDir(t, dir, "npm", "run", "gen:api"); err != nil {
		t.Fatalf("npm run gen:api: %v\n%s", err, out)
	}
	after, _ := os.ReadFile(filepath.Join(dir, "src/api/schema.d.ts"))
	if string(before) != string(after) {
		t.Error("src/api/schema.d.ts is not what contracts/api.openapi.yaml generates; run npm run gen:api")
	}
}

func TestTheWebTemplateCarriesWhatARepoOfTheFactoryNeeds(t *testing.T) {
	dir := copyTemplate(t, "web")
	read := func(name string) string {
		b, err := os.ReadFile(filepath.Join(dir, name))
		if err != nil {
			t.Fatalf("the template lacks %s: %v", name, err)
		}
		return string(b)
	}
	if lic := read("LICENSE"); !strings.HasPrefix(lic, "MIT License") {
		t.Errorf("LICENSE starts %q; a product may use a template under its own licence only if it is MIT", lic[:20])
	}
	if n := strings.Count(read("AGENTS.md"), "\n"); n > 100 {
		t.Errorf("AGENTS.md is %d lines; a short file that points into docs, about 100 lines (spec §4.2)", n)
	}
	for _, name := range []string{"init.sh", "package-lock.json", "contracts/api.openapi.yaml", "src/api/schema.d.ts", "e2e/smoke.spec.ts", "playwright.config.ts", ".gitignore"} {
		read(name)
	}
	// Every dependency is pinned to one version: no range, no tag.
	var pkg struct {
		Dependencies, DevDependencies map[string]string
	}
	if err := json.Unmarshal([]byte(read("package.json")), &pkg); err != nil {
		t.Fatal(err)
	}
	for _, deps := range []map[string]string{pkg.Dependencies, pkg.DevDependencies} {
		for name, v := range deps {
			if strings.ContainsAny(v, "^~<>*|x ") || v == "latest" || v == "" {
				t.Errorf("%s is %q; the template pins an exact version", name, v)
			}
		}
	}
	// The devcontainer.json is for people's editors: the factory never reads it, and nothing in it runs.
	var dc map[string]any
	if err := json.Unmarshal([]byte(read(".devcontainer/devcontainer.json")), &dc); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"initializeCommand", "onCreateCommand", "updateContentCommand", "postCreateCommand", "postStartCommand",
		"postAttachCommand", "mounts", "runArgs", "privileged", "capAdd", "securityOpt", "dockerComposeFile", "build", "features", "containerEnv", "remoteEnv", "forwardPorts"} {
		if _, bad := dc[key]; bad {
			t.Errorf(".devcontainer/devcontainer.json sets %s, which runs or widens something when a person opens the repo", key)
		}
	}
}
```

Write `templates/web/e2e/smoke.spec.ts`:

```ts
import { expect, test } from "@playwright/test";

test("the home page shows that the API answers", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Gallery" })).toBeVisible();
  await expect(page.getByText("API: ok")).toBeVisible();
});
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTheWebTemplateCarriesWhatARepoOfTheFactoryNeeds (0.01s)
    template_test.go:76: the template lacks LICENSE: open /tmp/TestTheWebTemplateCarriesWhatARepoOfTheFactoryNeeds151104137/001/LICENSE: no such file or directory
FAIL
FAIL	github.com/ouroboric-dev/midgard-react	11.402s
```

- [ ] **Step 3:** write the code.

Write `templates/web/.devcontainer/devcontainer.json`:

```json
{
  "name": "web",
  "image": "docker.io/library/node@sha256:efd0ab5780c2d9ab1f0f869571a00d5edb17793bff4cce4a2792e3eb0ffc7562"
}
```

Write `templates/web/.gitignore`:

```text
node_modules/
dist/
playwright-report/
test-results/
*.tsbuildinfo
```

Write `templates/web/AGENTS.md`:

```md
# AGENTS.md: web

The React web app of this product. It talks to the API only through `contracts/api.openapi.yaml`.

Follow the Yggdrasil invariants:
https://github.com/ouroboric-dev/yggdrasil/blob/main/AGENTS.md#invariants
This file only adds rules for this leaf. Read `docs/` for the design; this file says how to work here.

## Work here

- `npm ci` first (`./init.sh`). Then `npm test` (unit tests), `npm run lint`, `npm run typecheck`,
  `npm run build`, and `npm run test:e2e` (Playwright, against the built app and an API behind it).
- Stack: React, Vite, TypeScript (strict), Tailwind, shadcn/ui style components in `src/components/ui`,
  TanStack Router for pages and TanStack Query for data. Uploads use Uppy with presigned URLs.
- Pin every dependency to an exact version and commit `package-lock.json`. A new dependency needs a reason
  the standard library, the browser and what is here cannot give.

## Rules for every change

- **Test first.** A new test fails on the parent commit, for the reason the task gives. The factory
  checks this: a change to code without a new or changed test is refused. Unit tests are `*.test.ts(x)`
  beside the code, with Vitest and Testing Library. One Playwright spec in `e2e/` per acceptance criterion
  that a person does in the browser.
- **The contract is a copy.** `contracts/api.openapi.yaml` is the API leaf's contract as this app uses it.
  The task gives you the contract text when the API changes: copy it exactly. After a change, run
  `npm run gen:api`; `src/api/schema.d.ts` is generated and committed, never edited by hand. The
  copy may lag behind the API; the acceptance run fails if the API takes away or changes what the copy
  promises.
- **Call the API through `src/lib/api.ts`.** The client is typed by the contract. Never write `fetch`
  against a URL by hand, and never put a server address in the code: the browser calls `/api`.
- **Photo bytes never pass through the API.** Uploads and downloads use presigned URLs the API hands out.
  Thumbnails are made in the browser. Large downloads stream to disk.
- Handle every state a user can see: loading, empty, error, and the result. Forms validate before they
  send, and the server's answer wins.
- No secret, token or real person's data in the repository, in a test or in a log line.
- Accessible by default: real buttons and links, labels on inputs, text alternatives.

## Layout

- `src/main.tsx`, `src/router.tsx`: the app and its routes. A page is a component in `src/routes`.
- `src/components`: shared components; `src/components/ui` are the base ones (shadcn/ui style).
- `src/lib`: `api.ts` (the typed client) and helpers.
- `src/api/schema.d.ts`: generated from the contract.
- `contracts/`: the API contract. `e2e/`: Playwright specs.
```

Write `templates/web/LICENSE`:

```text
MIT License

Copyright (c) the contributors to this project

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Write `templates/web/init.sh` (executable):

```sh
#!/bin/sh
# Prepares a fresh clone for work: installs exactly what package-lock.json says. Run it once.
set -eu
npm ci --no-audit --no-fund
echo "ready: 'npm test' runs the unit tests, 'npm run dev' the app"
```

Write `templates/web/playwright.config.ts`:

```ts
import { defineConfig } from "@playwright/test";

// The e2e run needs the app at E2E_URL (default: the Vite preview of a build, on 4173) and an API behind
// it: a mock of contracts/api.openapi.yaml in a task's loop (web-e2e.sh), the real server in the
// acceptance run (accept-e2e.sh). One spec per acceptance criterion, in e2e/.
export default defineConfig({
  testDir: "e2e",
  fullyParallel: true,
  reporter: [["list"]],
  use: { baseURL: process.env.E2E_URL ?? "http://localhost:4173", trace: "off" },
  projects: [{ name: "chromium", use: { browserName: "chromium" } }],
});
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T226: the static and unit rungs for a web leaf, and the TDD check, tried with the real tools on the template

The web leaf's ladder starts like the Go leaf's. `web-tdd.sh` runs the new Vitest files on a copy of the commit the task started from, with the leaf's installed packages beside it (a symlink to its `node_modules`), and they must fail there. Playwright specs need a browser and an API, so a change that has only those passes with a note.

**Files (in `midgard-react`):**
- Create: `checks_test.go`, `devcontainer/checks/docs.sh`, `devcontainer/checks/web-static.sh`, `devcontainer/checks/web-tdd.sh`, `devcontainer/checks/web-unit.sh`

**Interfaces:**
- Produces: `devcontainer/checks/docs.sh` (the same as `helheim-go`'s; backlog B-043 is the duplication), `web-static.sh` (`npm ci` if there are no packages, `eslint`, `tsc`, the build, the docs), `web-unit.sh` (`npm test`) and `web-tdd.sh`.
- `web-tdd.sh` refuses app code (`src/**/*.ts(x)` that is not a test, a `.d.ts` or the test setup) changed without a new or changed `*.test.ts(x)`; refuses new tests that pass on the parent; passes, with a note, a change with only a Playwright spec, only a generated type file, or a document.

**Acceptance criteria:**
- [ ] `web-static.sh` installs only what is missing and stops at the first failing step; a bad document fails it.
- [ ] `web-tdd.sh` passes code with a test that needs it and shows the failure; refuses code with no test and a test that passes on the parent; the leaf is left as it was, and Vitest is given the new test files only.
- [ ] The scripts were run on the template and on the smoke run's second task with the real tools.

**Named test:** `go test . -run 'TestDocsAcceptsDocumentsAndNamesEveryProblemOfTheOthers|TestStaticInstallsOnlyWhatIsMissingAndStopsAtTheFirstProblem|TestUnitRunsTheTests|TestTDDWantsTheNewTestsToFailOnTheCommitTheTaskStartedFrom'` in `midgard-react`. **Layer:** `midgard-react`. **Size:** M (338). **Depends on:** v0-T225.

- [ ] **Step 1:** write the tests.

Write `checks_test.go`:

```go
package midgard

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// The scripts of devcontainer/checks are baked into the stack image and run in a leaf. These tests run them
// on small leaves made in a temp dir, with the real go, gofmt and git, and stand-ins for the tools that only
// the image has (golangci-lint, sqlc, oasdiff, vacuum, govulncheck, osv-scanner), which log how they were
// called and exit as the test says.

// leaf writes files (path: body) into a new temp dir and returns it.
func leaf(t *testing.T, files map[string]string) string {
	t.Helper()
	dir := t.TempDir()
	put(t, dir, files)
	return dir
}

func put(t *testing.T, dir string, files map[string]string) {
	t.Helper()
	for name, body := range files {
		p := filepath.Join(dir, name)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

// stubs makes a folder of executables named tools. Each logs "<tool> <args>" to calls.log in the folder and
// exits with the number in the variable STUB_<TOOL>_EXIT (0 when it is unset), after printing STUB_<TOOL>_OUT.
func stubs(t *testing.T, tools ...string) (bin string) {
	t.Helper()
	bin = t.TempDir()
	for _, tool := range tools {
		v := strings.ToUpper(strings.ReplaceAll(tool, "-", "_"))
		body := "#!/bin/sh\necho \"" + tool + " $*\" >> \"$(dirname \"$0\")/calls.log\"\n" +
			"[ -z \"$STUB_" + v + "_OUT\" ] || echo \"$STUB_" + v + "_OUT\"\nexit \"${STUB_" + v + "_EXIT:-0}\"\n"
		if err := os.WriteFile(filepath.Join(bin, tool), []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	return bin
}

func calls(bin string) string {
	b, _ := os.ReadFile(filepath.Join(bin, "calls.log"))
	return string(b)
}

// script runs devcontainer/checks/name in dir with bin first on PATH and the given extra environment
// (KEY=value), and returns its exit code and its output.
func script(t *testing.T, dir, bin, name string, env ...string) (int, string) {
	t.Helper()
	abs, err := filepath.Abs(filepath.Join("devcontainer", "checks", name))
	if err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command("bash", abs)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GOWORK=off", "GOFLAGS=-mod=mod", "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1")
	if bin != "" {
		cmd.Env = append(cmd.Env, "PATH="+bin+":"+os.Getenv("PATH"))
	}
	cmd.Env = append(cmd.Env, env...)
	var out bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &out
	err = cmd.Run()
	if ee, ok := err.(*exec.ExitError); ok {
		return ee.ExitCode(), out.String()
	}
	if err != nil {
		t.Fatalf("%s: %v", name, err)
	}
	return 0, out.String()
}

// repo makes a git repo with the given files committed on main, and returns it.
func repo(t *testing.T, files map[string]string) string {
	t.Helper()
	dir := leaf(t, files)
	git(t, dir, "init", "-q", "-b", "main")
	git(t, dir, "add", "-A")
	git(t, dir, "commit", "-q", "-m", "start")
	return dir
}

func git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-c", "user.name=T", "-c", "user.email=t@example.invalid"}, args...)...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1")
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %v: %v\n%s", args, err, out)
	}
	return strings.TrimSpace(string(out))
}

// work puts files on a branch of the repo made from main, committed.
func work(t *testing.T, dir string, files map[string]string) {
	t.Helper()
	git(t, dir, "switch", "-q", "-c", "work")
	put(t, dir, files)
	git(t, dir, "add", "-A")
	git(t, dir, "commit", "-q", "-m", "work")
}

// stub writes one tool of a stub folder with a body of its own.
func stub(t *testing.T, bin, name, body string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(bin, name), []byte("#!/bin/sh\n"+body), 0o755); err != nil {
		t.Fatal(err)
	}
}

func TestDocsAcceptsDocumentsAndNamesEveryProblemOfTheOthers(t *testing.T) {
	good := "---\ntitle: A\nstatus: draft\ndate: 2026-10-17\n---\n# A\n\nSee [b](b.md) and [the web](https://example.com/x).\n"
	if code, out := script(t, leaf(t, map[string]string{"docs/a.md": good, "docs/b.md": good}), "", "docs.sh"); code != 0 || !strings.Contains(out, "docs: ok") {
		t.Errorf("good documents: exit %d\n%s", code, out)
	}
	code, out := script(t, leaf(t, map[string]string{"docs/a.md": strings.Replace(good, "[b](b.md)", "[gone](gone.md)", 1), "docs/No Plain.md": "# x\n"}), "", "docs.sh")
	if code == 0 || !strings.Contains(out, "points at nothing") || !strings.Contains(out, "file name must be") || !strings.Contains(out, "starts without front matter") {
		t.Errorf("bad documents: exit %d\n%s", code, out)
	}
}

func TestStaticInstallsOnlyWhatIsMissingAndStopsAtTheFirstProblem(t *testing.T) {
	bin := stubs(t, "npm")
	if code, out := script(t, leaf(t, map[string]string{"package.json": "{}"}), bin, "web-static.sh"); code != 0 {
		t.Fatalf("exit %d\n%s", code, out)
	}
	want := "npm ci --no-audit --no-fund\nnpm run lint\nnpm run typecheck\nnpm run build\n"
	if calls(bin) != want {
		t.Errorf("calls = %q, want %q: install, lint, type-check, build", calls(bin), want)
	}
	bin = stubs(t, "npm")
	if code, _ := script(t, leaf(t, map[string]string{"node_modules/.keep": ""}), bin, "web-static.sh"); code != 0 || strings.Contains(calls(bin), "npm ci") {
		t.Errorf("installed packages were installed again: %q", calls(bin))
	}
	// A failing step ends it: the later ones do not run.
	bin = stubs(t, "npm")
	stub(t, bin, "npm", `echo "npm $*" >> "$(dirname "$0")/calls.log"
[ "$*" = "run typecheck" ] && { echo "src/a.ts(1,1): error TS2322"; exit 2; }
exit 0
`)
	code, out := script(t, leaf(t, map[string]string{"node_modules/.keep": ""}), bin, "web-static.sh")
	if code == 0 || !strings.Contains(out, "TS2322") || strings.Contains(calls(bin), "run build") {
		t.Errorf("a type error: exit %d, calls %q\n%s", code, calls(bin), out)
	}
	if code, out := script(t, leaf(t, map[string]string{"node_modules/.keep": "", "docs/Bad Name.md": "x"}), stubs(t, "npm"), "web-static.sh"); code == 0 || !strings.Contains(out, "docs:") {
		t.Errorf("a bad document: exit %d\n%s", code, out)
	}
}

func TestUnitRunsTheTests(t *testing.T) {
	bin := stubs(t, "npm")
	if code, _ := script(t, leaf(t, map[string]string{"node_modules/.keep": ""}), bin, "web-unit.sh"); code != 0 || calls(bin) != "npm test\n" {
		t.Errorf("calls = %q", calls(bin))
	}
	if code, _ := script(t, leaf(t, map[string]string{"node_modules/.keep": ""}), stubs(t, "npm"), "web-unit.sh", "STUB_NPM_EXIT=1"); code == 0 {
		t.Error("a failing test passed")
	}
}

func TestTDDWantsTheNewTestsToFailOnTheCommitTheTaskStartedFrom(t *testing.T) {
	start := map[string]string{"node_modules/.keep": "", ".gitignore": "node_modules/\n", "src/a.ts": "export const a = 1;\n", "src/a.test.ts": "// test\n"}
	// npx stands in for vitest: it fails on the parent when the parent lacks the code the new test needs, as a
	// real run does, and logs where it ran and what was there.
	vitest := `echo "npx $*" >> "$(dirname "$0")/calls.log"
[ -e node_modules/.keep ] || { echo "no packages beside the parent"; exit 3; }
if [ -e src/lib/greet.test.ts ] && [ ! -e src/lib/greet.ts ]; then echo "Failed to resolve import @/lib/greet"; exit 1; fi
exit "${STUB_PARENT_EXIT:-0}"
`
	newCode := map[string]string{"src/lib/greet.ts": "export const greet = 1;\n", "src/lib/greet.test.ts": "// test\n"}
	cases := []struct {
		name  string
		files map[string]string
		env   []string
		pass  bool
		want  string
	}{
		{"code and a test that needs it", newCode, nil, true, "fail on the commit the task started from"},
		{"code with no test", map[string]string{"src/lib/greet.ts": "export const greet = 1;\n"}, nil, false, "changed without a new or changed unit test"},
		{"a test that passes before the code", map[string]string{"src/b.test.ts": "// test\n"}, nil, false, "test nothing new"},
		{"only a generated type file", map[string]string{"src/api/schema.d.ts": "export {};\n"}, nil, true, "no app code changed"},
		{"only a document", map[string]string{"README.md": "x\n"}, nil, true, "no app code changed"},
		{"only a Playwright spec", map[string]string{"e2e/home.spec.ts": "// spec\n"}, nil, true, "cannot be shown to fail"},
	}
	for _, c := range cases {
		dir := repo(t, start)
		work(t, dir, c.files)
		bin := t.TempDir()
		stub(t, bin, "npx", vitest)
		code, out := script(t, dir, bin, "web-tdd.sh", c.env...)
		if (code == 0) != c.pass || !strings.Contains(out, c.want) {
			t.Errorf("%s: exit %d, want pass=%v and %q\n%s", c.name, code, c.pass, c.want, out)
		}
	}
	dir := repo(t, start)
	git(t, dir, "switch", "-q", "-c", "work")
	bin := t.TempDir()
	stub(t, bin, "npx", vitest)
	if code, out := script(t, dir, bin, "web-tdd.sh"); code != 0 || !strings.Contains(out, "no app code changed") {
		t.Errorf("an unchanged branch: exit %d\n%s", code, out)
	}
	// The leaf is left as it was, and vitest was given the new test files only.
	dir = repo(t, start)
	work(t, dir, newCode)
	bin = t.TempDir()
	stub(t, bin, "npx", vitest)
	script(t, dir, bin, "web-tdd.sh")
	if st := git(t, dir, "status", "--porcelain"); st != "" {
		t.Errorf("the check left the leaf changed:\n%s", st)
	}
	if got := calls(bin); got != "npx vitest run src/lib/greet.test.ts\n" {
		t.Errorf("vitest was run as %q, want only the new test file", got)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestDocsAcceptsDocumentsAndNamesEveryProblemOfTheOthers (0.00s)
    checks_test.go:128: good documents: exit 127
        bash: /tmp/tmp.7hk41Ij7m2/v0-T226/midgard-react/devcontainer/checks/docs.sh: No such file or directory
    checks_test.go:132: bad documents: exit 127
```

- [ ] **Step 3:** write the code.

Write `devcontainer/checks/docs.sh` (executable):

```sh
#!/bin/bash
# The docs part of the static rung (spec §9.5 rung 1): every markdown file under docs/ has the front matter
# the docs standard asks for (title, a status and a date; style and related are optional), a plain file name, and links that point at files that exist. Prose rules
# (Vale) wait for a later change. Run in a leaf's top folder; it reads and changes nothing.
set -euo pipefail
[ -d docs ] || { echo "docs: no docs/ folder, nothing to check"; exit 0; }
problems=0
say() { echo "docs: $*"; problems=$((problems + 1)); }
while IFS= read -r -d '' f; do
  name="$(basename "$f")"
  [[ "$name" =~ ^[a-z0-9][a-z0-9._-]*\.md$ ]] || say "$f: the file name must be lower case words joined by dashes, ending in .md"
  if [ "$(head -n 1 "$f")" != "---" ]; then
    say "$f: starts without front matter (--- on the first line)"
  else
    head_block="$(awk 'NR == 1 { next } /^---$/ { exit } { print }' "$f")"
    for key in title status date; do
      grep -q "^$key:" <<<"$head_block" || say "$f: the front matter has no $key"
    done
    status="$(sed -n 's/^status: *//p' <<<"$head_block" | head -n 1)"
    [ -z "$status" ] || [[ "$status" =~ ^(draft|accepted|implemented|superseded)$ ]] || say "$f: status is $status; it is draft, accepted, implemented or superseded"
    date="$(sed -n 's/^date: *//p' <<<"$head_block" | head -n 1)"
    [ -z "$date" ] || [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || say "$f: date is $date; it is YYYY-MM-DD"
  fi
  dir="$(dirname "$f")"
  while IFS= read -r link; do
    target="${link%%#*}"
    case "$target" in '' | http://* | https://* | mailto:*) continue ;; esac
    [ -e "$dir/$target" ] || say "$f: the link $link points at nothing"
  done < <(grep -o ']([^)]*)' "$f" | sed -e 's/^](//' -e 's/)$//' || true)
done < <(find docs -type f -name '*.md' -print0 | sort -z)
[ "$problems" -eq 0 ] || { echo "docs: $problems problem(s)"; exit 1; }
echo "docs: ok"
```

Write `devcontainer/checks/web-static.sh` (executable):

```sh
#!/bin/bash
# Rung 1 of the ladder for a web leaf (spec §9.5): the packages are what package-lock.json says, the code
# is linted and type-checked and it builds, and the docs are in order. Run in the leaf's top folder.
set -euo pipefail
if [ ! -d node_modules ]; then
  echo "== npm ci"
  npm ci --no-audit --no-fund
fi
echo "== eslint"
npm run lint
echo "== tsc"
npm run typecheck
echo "== build"
npm run build
echo "== docs"
"$(dirname "$0")/docs.sh"
```

Write `devcontainer/checks/web-tdd.sh` (executable):

```sh
#!/bin/bash
# The TDD check, the other half of rung 2 (spec §9.5): the unit tests a change adds or changes MUST fail on
# the commit it started from. It builds that commit in a folder of its own with the leaf's installed
# packages beside it, puts the change's test files on it, and runs them: they have to fail (a test of code
# that is not there yet fails to load, which counts). A change to app code without a new or changed unit
# test is refused. Playwright specs need a browser and an API, so a change that only has those is passed
# with a note, and the reviewers look at it. Generated and type-only files are not code that needs a test.
# Run in the leaf's top folder, on the run branch; main is where the task started from.
set -euo pipefail
base="$(git merge-base HEAD main)" || { echo "tdd: this leaf has no main to compare with"; exit 1; }
[ -d node_modules ] || npm ci --no-audit --no-fund

tests=() code=() specs=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in e2e/*) specs+=("$f") ;; *.test.ts | *.test.tsx) tests+=("$f") ;; esac
done < <(git diff --name-only --diff-filter=AM "$base" HEAD -- 'src/**' 'e2e/**')
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "$f" in *.test.ts | *.test.tsx | *.d.ts | src/test-setup.ts | src/index.css) continue ;; esac
  case "$f" in *.ts | *.tsx) code+=("$f") ;; esac
done < <(git diff --name-only --diff-filter=AM "$base" HEAD -- 'src/**')

if [ ${#tests[@]} -eq 0 ]; then
  if [ ${#code[@]} -gt 0 ] && [ ${#specs[@]} -eq 0 ]; then
    echo "tdd: app code changed without a new or changed unit test:"
    printf '  %s\n' "${code[@]}"
    echo "Write the test first, see it fail, then write the code."
    exit 1
  fi
  if [ ${#specs[@]} -gt 0 ]; then
    echo "tdd: only Playwright specs changed, and they need a browser and an API; they cannot be shown to fail here:"
    printf '  %s\n' "${specs[@]}"
  else
    echo "tdd: no app code changed"
  fi
  exit 0
fi

parent="$(mktemp -d)"
trap 'rm -rf -- "$parent"' EXIT
git archive "$base" | tar -x -C "$parent"
ln -s "$PWD/node_modules" "$parent/node_modules"
for f in "${tests[@]}"; do
  mkdir -p "$parent/$(dirname "$f")"
  cp -- "$f" "$parent/$f"
done
log="$parent/.tdd.log"
if (cd "$parent" && npx vitest run "${tests[@]}") >"$log" 2>&1; then
  echo "tdd: the new tests pass on the commit the task started from, so they test nothing new:"
  printf '  %s\n' "${tests[@]}"
  echo "A test of new behaviour fails before the code for it exists. Change the tests so they do."
  exit 1
fi
echo "tdd: the new tests fail on the commit the task started from, as they must:"
printf '  %s\n' "${tests[@]}"
tail -n 12 "$log"
```

Write `devcontainer/checks/web-unit.sh` (executable):

```sh
#!/bin/bash
# Rung 2, the tests: every unit test of the leaf. (web-tdd.sh is the other half of the rung: it shows the
# new tests fail on the commit the task started from.)
set -euo pipefail
[ -d node_modules ] || npm ci --no-audit --no-fund
npm test
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T227: the contract and security rungs for a web leaf

Rung 3 for the web leaf is the contract it uses: its copy is linted, the types generated from it are what it says, and the changes of the copy since the task started are listed. Rung 4 asks npm's advisories and OSV.

**Files (in `midgard-react`):**
- Create: `contract_test.go`, `devcontainer/checks/web-contract.sh`, `devcontainer/checks/web-security.sh`

**Interfaces:**
- Produces: `devcontainer/checks/web-contract.sh` (`vacuum lint`, `openapi-typescript` into a temp file compared with `src/api/schema.d.ts`, `oasdiff breaking` against the copy at the commit the task started from) and `web-security.sh` (`npm audit --audit-level=high`, `osv-scanner scan source -L package-lock.json`).

**Acceptance criteria:**
- [ ] Types that are out of date fail, with `npm run gen:api` named; a lint error fails; a breaking change of the copy is listed and does not fail; a leaf with no contract copy fails.
- [ ] A vulnerability from either source fails rung 4.

**Named test:** `go test . -run 'TestContractChecksTheTypesAreWhatTheContractSaysAndListsChanges|TestSecurityStopsOnAVulnerabilityFromEitherSource'` in `midgard-react`. **Layer:** `midgard-react`. **Size:** S (91). **Depends on:** v0-T226.

- [ ] **Step 1:** write the tests.

Write `contract_test.go`:

```go
package midgard

import (
	"strings"
	"testing"
)

func TestContractChecksTheTypesAreWhatTheContractSaysAndListsChanges(t *testing.T) {
	files := map[string]string{"node_modules/.keep": "", ".gitignore": "node_modules/\n", "contracts/api.openapi.yaml": "openapi: 3.1.0\n", "src/api/schema.d.ts": "types\n"}
	dir := repo(t, files)
	work(t, dir, map[string]string{"contracts/api.openapi.yaml": "openapi: 3.1.0\ninfo: {}\n"})
	mk := func(generates string) string {
		bin := stubs(t, "vacuum", "oasdiff")
		stub(t, bin, "npx", `echo "npx $*" >> "$(dirname "$0")/calls.log"
out=""; while [ $# -gt 0 ]; do [ "$1" = -o ] && out="$2"; shift; done
printf '%s\n' '`+generates+`' > "$out"
`)
		return bin
	}
	bin := mk("types")
	code, out := script(t, dir, bin, "web-contract.sh", "STUB_OASDIFF_OUT=[]")
	if code != 0 || !strings.Contains(out, "none") || !strings.Contains(calls(bin), "vacuum lint --no-style --details --fail-severity error contracts/api.openapi.yaml") {
		t.Errorf("types that match: exit %d, calls %q\n%s", code, calls(bin), out)
	}
	if code, out := script(t, dir, mk("types"), "web-contract.sh", `STUB_OASDIFF_OUT=[{"id":"x"}]`); code != 0 || !strings.Contains(out, "BREAKING") {
		t.Errorf("a breaking change is listed and not refused: exit %d\n%s", code, out)
	}
	if code, out := script(t, dir, mk("other types"), "web-contract.sh", "STUB_OASDIFF_OUT=[]"); code == 0 || !strings.Contains(out, "npm run gen:api") {
		t.Errorf("types that are out of date: exit %d\n%s", code, out)
	}
	if code, _ := script(t, dir, mk("types"), "web-contract.sh", "STUB_VACUUM_EXIT=1", "STUB_OASDIFF_OUT=[]"); code == 0 {
		t.Error("a lint error passed")
	}
	if code, out := script(t, repo(t, map[string]string{"node_modules/.keep": "", "a": "x"}), mk("types"), "web-contract.sh"); code == 0 || !strings.Contains(out, "has no contracts/api.openapi.yaml") {
		t.Errorf("no contract: exit %d\n%s", code, out)
	}
}

func TestSecurityStopsOnAVulnerabilityFromEitherSource(t *testing.T) {
	dir := leaf(t, map[string]string{"node_modules/.keep": ""})
	bin := stubs(t, "npm", "osv-scanner")
	if code, out := script(t, dir, bin, "web-security.sh"); code != 0 || calls(bin) != "npm audit --audit-level=high\nosv-scanner scan source -L package-lock.json\n" {
		t.Fatalf("exit %d, calls %q\n%s", code, calls(bin), out)
	}
	for _, env := range []string{"STUB_NPM_EXIT=1", "STUB_OSV_SCANNER_EXIT=1"} {
		if code, _ := script(t, dir, stubs(t, "npm", "osv-scanner"), "web-security.sh", env); code == 0 {
			t.Errorf("%s passed", env)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestContractChecksTheTypesAreWhatTheContractSaysAndListsChanges (0.05s)
    contract_test.go:23: types that match: exit 127, calls ""
        bash: /tmp/tmp.7hk41Ij7m2/v0-T227/midgard-react/devcontainer/checks/web-contract.sh: No such file or directory
    contract_test.go:26: a breaking change is listed and not refused: exit 127
```

- [ ] **Step 3:** write the code.

Write `devcontainer/checks/web-contract.sh` (executable):

```sh
#!/bin/bash
# Rung 3 of the ladder for a web leaf (spec §9.5): the contract this app uses. The copy of the API's
# contract is linted, the types generated from it are what it says, and the changes of the copy against the
# commit the task started from are listed: a changed copy means the API changed, and the acceptance run
# checks the copy is the API leaf's own file. Run in the leaf's top folder.
set -euo pipefail
c=contracts/api.openapi.yaml
[ -f "$c" ] || { echo "contract: this leaf has no $c"; exit 1; }
[ -d node_modules ] || npm ci --no-audit --no-fund
echo "== openapi lint"
vacuum lint --no-style --details --fail-severity error "$c"
echo "== generated types"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
npx openapi-typescript "$c" -o "$tmp/schema.d.ts" >/dev/null
if ! diff -q "$tmp/schema.d.ts" src/api/schema.d.ts >/dev/null; then
  echo "contract: src/api/schema.d.ts is not what $c generates; run npm run gen:api"
  exit 1
fi
echo "== changes of the contract since the task started"
base="$(git merge-base HEAD main)" || { echo "contract: this leaf has no main to compare with"; exit 1; }
if git cat-file -e "$base:$c" 2>/dev/null; then
  git show "$base:$c" > "$tmp/old.yaml"
  if [ "$(oasdiff breaking "$tmp/old.yaml" "$c" --format json)" = "[]" ]; then
    echo "none"
  else
    echo "BREAKING: the API this app calls changed in ways that break callers; say so in your summary."
    oasdiff breaking "$tmp/old.yaml" "$c"
  fi
else
  echo "$c is new in this change"
fi
```

Write `devcontainer/checks/web-security.sh` (executable):

```sh
#!/bin/bash
# Rung 4 of the ladder for a web leaf (spec §9.5, §9.6): known vulnerabilities in the packages, from npm's
# advisories and from OSV. Secrets are scanned by Odin before every checkpoint. Run in the leaf's top folder.
set -euo pipefail
[ -d node_modules ] || npm ci --no-audit --no-fund
echo "== npm audit"
npm audit --audit-level=high
echo "== OSV"
osv-scanner scan source -L package-lock.json
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T228: the end-to-end rung with a mock API, and the acceptance run on a snapshot of the project

Rung 5 for the web leaf (decision 4): in a task's loop Playwright runs against the built app with a mock of the leaf's copy of the API contract behind it. The acceptance run (decision 5) is the pointer move's: on the snapshot it checks the API still keeps what the copy promises, builds the API, starts it against the Postgres of the acceptance sandbox, builds the web app and runs its specs against both. Both scripts start servers, so both refuse a port that is already taken: a server of an earlier run would otherwise answer for this run's (found on the first local run: a leftover `vite preview` served an old build). Both start the server itself (`node_modules/.bin/vite`, not `npx`), so that the pid kept is the server's and stopping it stops it.

**Files (in `midgard-react`):**
- Create: `devcontainer/checks/accept-e2e.sh`, `devcontainer/checks/web-e2e.sh`, `e2e_test.go`

**Interfaces:**
- Produces: `devcontainer/checks/web-e2e.sh` (Prism on `YGG_MOCK_PORT` 4010, `npm run build`, `vite preview` on `YGG_APP_PORT` 4173 with `API_URL` the mock, `playwright test` with `E2E_URL`; every server it started is stopped, on success and on failure) and `accept-e2e.sh` (`oasdiff breaking <web copy> <api contract> --fail-on ERR`; `go build` of `repos/api`; the API on `YGG_API_PORT` 8080 with `DATABASE_URL`; the web build; `vite preview` with `API_URL` the API; `playwright test`). The leaves are `repos/api` and `repos/web` unless `YGG_API_DIR` and `YGG_WEB_DIR` say otherwise.

**Acceptance criteria:**
- [ ] `web-e2e.sh` starts the mock from `contracts/api.openapi.yaml`, builds, starts the app, runs Playwright with the app's URL, and leaves no server up, also after a failing run; a mock that never comes up ends it with the mock's log; a taken port is refused before anything is started.
- [ ] `accept-e2e.sh` stops before building anything when the API's contract breaks what the web copy promises, and stops when the API leaf or the copy is missing; with a database answering it starts the API with its address, then the app, then runs Playwright; a taken port is refused.
- [ ] `web-e2e.sh` was run for real, with Prism, Vite and Chromium, on the template and on the smoke run's second task.

**Named test:** `go test . -run 'TestE2EStartsAMockAndTheAppRunsPlaywrightAndStopsThem|TestAcceptanceChecksTheAPIKeepsWhatTheWebCopyPromisesThenRunsBothAgainstEachOther'` in `midgard-react`. **Layer:** `midgard-react`. **Size:** M (303). **Depends on:** v0-T227.

- [ ] **Step 1:** write the tests.

Write `e2e_test.go`:

```go
package midgard

import (
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

// serve is a stub body that serves HTTP on the port after the option named by flag, until it is killed, and
// logs that it started. It needs python3, as the tests of the e2e scripts do.
func serve(flag string) string {
	return `echo "$0 $*" >> "$(dirname "$0")/calls.log"
port=""; while [ $# -gt 0 ]; do [ "$1" = ` + flag + ` ] && port="$2"; shift; done
exec python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1
`
}

func needPython(t *testing.T) {
	t.Helper()
	if _, err := exec.LookPath("python3"); err != nil {
		t.Skip("python3 is needed to stand in for the servers")
	}
}

func listening(port int) bool {
	c, err := net.DialTimeout("tcp", "127.0.0.1:"+strconv.Itoa(port), 200*1e6)
	if err != nil {
		return false
	}
	c.Close()
	return true
}

func freePort(t *testing.T) int {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	return ln.Addr().(*net.TCPAddr).Port
}

func TestE2EStartsAMockAndTheAppRunsPlaywrightAndStopsThem(t *testing.T) {
	needPython(t)
	mockPort, appPort := freePort(t), freePort(t)
	env := []string{"YGG_MOCK_PORT=" + strconv.Itoa(mockPort), "YGG_APP_PORT=" + strconv.Itoa(appPort), "YGG_E2E_WAIT=5"}
	mk := func() string {
		bin := t.TempDir()
		stub(t, bin, "prism", serve("--port"))
		stub(t, bin, "npm", `echo "npm $*" >> "$(dirname "$0")/calls.log"`+"\n")
		stub(t, bin, "npx", `d="$(dirname "$0")"
case "$1" in
  playwright) echo "playwright E2E_URL=$E2E_URL" >> "$d/calls.log"; exit "${STUB_PLAYWRIGHT_EXIT:-0}" ;;
esac
`)
		// The app is vite from the leaf's own node_modules, run directly so that its pid is the server's.
		stub(t, bin, "vite", `echo "app API_URL=$API_URL" >> "`+bin+`/calls.log"`+"\n"+serve("--port"))
		return bin
	}
	// leafWith makes the leaf, with the stub vite where the script looks for it.
	leafWith := func(bin string, files map[string]string) string {
		dir := leaf(t, files)
		if err := os.MkdirAll(filepath.Join(dir, "node_modules", ".bin"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(filepath.Join(bin, "vite"), filepath.Join(dir, "node_modules", ".bin", "vite")); err != nil {
			t.Fatal(err)
		}
		return dir
	}
	bin := mk()
	dir := leafWith(bin, map[string]string{"contracts/api.openapi.yaml": "openapi: 3.1.0\n"})
	code, out := script(t, dir, bin, "web-e2e.sh", env...)
	got := calls(bin)
	for _, want := range []string{"prism mock --host 127.0.0.1 --port " + strconv.Itoa(mockPort) + " contracts/api.openapi.yaml", "npm run build",
		"app API_URL=http://127.0.0.1:" + strconv.Itoa(mockPort), "playwright E2E_URL=http://127.0.0.1:" + strconv.Itoa(appPort)} {
		if !strings.Contains(got, want) {
			t.Errorf("calls lack %q:\n%s", want, got)
		}
	}
	if code != 0 {
		t.Errorf("exit %d\n%s", code, out)
	}
	time.Sleep(300 * time.Millisecond)
	if listening(mockPort) || listening(appPort) {
		t.Error("a server the script started was still up when it ended")
	}
	// A failing spec fails the check, and the servers are still stopped.
	if code, _ := script(t, dir, mk(), "web-e2e.sh", append(env, "STUB_PLAYWRIGHT_EXIT=1")...); code == 0 {
		t.Error("a failing Playwright run passed")
	}
	time.Sleep(300 * time.Millisecond)
	if listening(mockPort) || listening(appPort) {
		t.Error("a server was left up after a failing run")
	}
	// A mock that never comes up ends the run, with its log.
	broken := mk()
	stub(t, broken, "prism", "echo 'prism: cannot read the contract' >&2\nexit 1\n")
	if code, out := script(t, dir, broken, "web-e2e.sh", append(env, "YGG_E2E_WAIT=2")...); code == 0 || !strings.Contains(out, "mock did not answer") {
		t.Errorf("no mock: exit %d\n%s", code, out)
	}
	// A server of an earlier run still on a port is refused, not mistaken for this run's mock.
	taken, err := net.Listen("tcp", "127.0.0.1:"+strconv.Itoa(mockPort))
	if err != nil {
		t.Fatal(err)
	}
	defer taken.Close()
	busyBin := mk()
	if code, out := script(t, leafWith(busyBin, map[string]string{"contracts/api.openapi.yaml": "x"}), busyBin, "web-e2e.sh", env...); code == 0 || !strings.Contains(out, "already in use") || calls(busyBin) != "" {
		t.Errorf("a busy port: exit %d, calls %q\n%s", code, calls(busyBin), out)
	}
}

func TestAcceptanceChecksTheAPIKeepsWhatTheWebCopyPromisesThenRunsBothAgainstEachOther(t *testing.T) {
	needPython(t)
	db, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	apiPort, appPort := freePort(t), freePort(t)
	env := []string{"YGG_DB_HOST=127.0.0.1", "YGG_DB_PORT=" + strconv.Itoa(db.Addr().(*net.TCPAddr).Port), "YGG_API_PORT=" + strconv.Itoa(apiPort),
		"YGG_APP_PORT=" + strconv.Itoa(appPort), "YGG_E2E_WAIT=5"}
	mk := func() string {
		bin := t.TempDir()
		stub(t, bin, "oasdiff", `echo "oasdiff $*" >> "$(dirname "$0")/calls.log"`+"\n"+`[ -z "$STUB_OASDIFF_OUT" ] || echo "$STUB_OASDIFF_OUT"`+"\n"+`exit "${STUB_OASDIFF_EXIT:-0}"`+"\n")
		// go build -o <path>: the "API" it makes serves on $PORT and logs the database it was given.
		stub(t, bin, "go", `out=""; while [ $# -gt 0 ]; do [ "$1" = -o ] && out="$2"; shift; done
cat > "$out" <<EOS
#!/bin/sh
echo "api PORT=\$PORT DATABASE_URL=\$DATABASE_URL" >> "`+bin+`/calls.log"
exec python3 -m http.server "\$PORT" --bind 127.0.0.1 >/dev/null 2>&1
EOS
chmod +x "$out"
`)
		stub(t, bin, "npm", `echo "npm $*" >> "$(dirname "$0")/calls.log"`+"\n")
		stub(t, bin, "npx", `d="$(dirname "$0")"
case "$1" in
  playwright) echo "playwright E2E_URL=$E2E_URL" >> "$d/calls.log"; exit "${STUB_PLAYWRIGHT_EXIT:-0}" ;;
esac
`)
		stub(t, bin, "vite", `echo "app API_URL=$API_URL" >> "`+bin+`/calls.log"`+"\n"+serve("--port"))
		return bin
	}
	// project makes the snapshot, with the stub vite where the script looks for the web leaf's own.
	project := func(bin string) string {
		dir := leaf(t, map[string]string{"repos/api/openapi.yaml": "openapi: 3.1.0\n", "repos/api/cmd/api/main.go": "package main\n", "repos/web/contracts/api.openapi.yaml": "openapi: 3.1.0\n"})
		if err := os.MkdirAll(filepath.Join(dir, "repos/web/node_modules/.bin"), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(filepath.Join(bin, "vite"), filepath.Join(dir, "repos/web/node_modules/.bin/vite")); err != nil {
			t.Fatal(err)
		}
		return dir
	}
	bin := mk()
	code, out := script(t, project(bin), bin, "accept-e2e.sh", env...)
	got := calls(bin)
	for _, want := range []string{"oasdiff breaking repos/web/contracts/api.openapi.yaml repos/api/openapi.yaml --fail-on ERR", "api PORT=" + strconv.Itoa(apiPort) + " DATABASE_URL=postgres://postgres@127.0.0.1:", "npm ci --no-audit --no-fund", "npm run build",
		"app API_URL=http://127.0.0.1:" + strconv.Itoa(apiPort), "playwright E2E_URL=http://127.0.0.1:" + strconv.Itoa(appPort)} {
		if !strings.Contains(got, want) {
			t.Errorf("calls lack %q:\n%s", want, got)
		}
	}
	if code != 0 {
		t.Errorf("exit %d\n%s", code, out)
	}
	time.Sleep(300 * time.Millisecond)
	if listening(apiPort) || listening(appPort) {
		t.Error("a server the script started was still up when it ended")
	}
	// An API whose contract breaks what the web app's copy promises stops it before anything is built.
	bin = mk()
	code, out = script(t, project(bin), bin, "accept-e2e.sh", append(env, "STUB_OASDIFF_EXIT=1", "STUB_OASDIFF_OUT=error [response-success-status-removed]")...)
	if code == 0 || !strings.Contains(out, "breaks what the web app's copy") || strings.Contains(calls(bin), "go ") || strings.Contains(calls(bin), "npm") {
		t.Errorf("a broken contract: exit %d, calls %q\n%s", code, calls(bin), out)
	}
	failing := mk()
	if code, _ := script(t, project(failing), failing, "accept-e2e.sh", append(env, "STUB_PLAYWRIGHT_EXIT=1")...); code == 0 {
		t.Error("a failing Playwright run passed")
	}
	// A server of an earlier run still on a port is refused, not mistaken for this run's.
	taken, err := net.Listen("tcp", "127.0.0.1:"+strconv.Itoa(appPort))
	if err != nil {
		t.Fatal(err)
	}
	defer taken.Close()
	busyBin := mk()
	if code, out := script(t, project(busyBin), busyBin, "accept-e2e.sh", env...); code == 0 || !strings.Contains(out, "already in use") || strings.Contains(calls(busyBin), "go ") {
		t.Errorf("a busy port: exit %d, calls %q\n%s", code, calls(busyBin), out)
	}
	if code, out := script(t, leaf(t, map[string]string{"repos/web/contracts/api.openapi.yaml": "x"}), mk(), "accept-e2e.sh", env...); code == 0 || !strings.Contains(out, "has no repos/api/openapi.yaml") {
		t.Errorf("no API leaf: exit %d\n%s", code, out)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestE2EStartsAMockAndTheAppRunsPlaywrightAndStopsThem (0.62s)
    e2e_test.go:84: calls lack "prism mock --host 127.0.0.1 --port 43401 contracts/api.openapi.yaml":
    e2e_test.go:84: calls lack "npm run build":
    e2e_test.go:84: calls lack "app API_URL=http://127.0.0.1:43401":
```

- [ ] **Step 3:** write the code.

Write `devcontainer/checks/accept-e2e.sh` (executable):

```sh
#!/bin/bash
# The acceptance run of a pointer move (spec §4.5, §9.5): the whole product, as it would be built, on a
# snapshot of the project in the acceptance sandbox, which has the services of every leaf. It checks that the
# API still keeps what the web app's copy of the contract promises, builds the API, starts it against
# Postgres, builds the web app and runs its Playwright specs against both. The leaves are at repos/api and repos/web unless
# YGG_API_DIR and YGG_WEB_DIR say otherwise. Run in the top folder of the snapshot.
set -euo pipefail
api="${YGG_API_DIR:-repos/api}" web="${YGG_WEB_DIR:-repos/web}" wait_s="${YGG_E2E_WAIT:-60}"
api_port="${YGG_API_PORT:-8080}" app_port="${YGG_APP_PORT:-4173}"
db_host="${YGG_DB_HOST:-postgres}" db_port="${YGG_DB_PORT:-5432}"
[ -f "$api/openapi.yaml" ] || { echo "accept: the API leaf has no $api/openapi.yaml"; exit 1; }
[ -f "$web/contracts/api.openapi.yaml" ] || { echo "accept: the web leaf has no $web/contracts/api.openapi.yaml"; exit 1; }
echo "== the API keeps what the web app's copy of the contract promises"
# The copy may lag behind the API (the API's task comes first), but the API may not take away or change what the
# copy has: oasdiff reads the copy as the old contract and the API's file as the new one.
if ! oasdiff breaking "$web/contracts/api.openapi.yaml" "$api/openapi.yaml" --fail-on ERR; then
  echo "accept: the API's contract breaks what the web app's copy of it promises. Change the web app to the API's contract: copy $api/openapi.yaml to $web/contracts/api.openapi.yaml, run npm run gen:api in the web leaf, and fix what it breaks."
  exit 1
fi
busy() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
for p in "$api_port" "$app_port"; do
  if busy "$p"; then echo "accept: port $p is already in use; a server of an earlier run may still be up"; exit 1; fi
done
log="$(mktemp -d)"
pids=()
cleanup() {
  for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
  wait 2>/dev/null || true
  rm -rf -- "$log"
}
trap cleanup EXIT
wait_for() { # port name
  for ((i = 0; i < wait_s; i++)); do
    if (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; then return 0; fi
    sleep 1
  done
  echo "accept: $2 did not answer on port $1 in ${wait_s}s"
  tail -n 15 "$log/$2.log" 2>/dev/null || true
  exit 1
}
for ((i = 0; i < wait_s; i++)); do
  if (exec 3<>"/dev/tcp/$db_host/$db_port") 2>/dev/null; then break; fi
  [ "$i" -lt $((wait_s - 1)) ] || { echo "accept: Postgres at $db_host:$db_port did not answer in ${wait_s}s"; exit 1; }
  sleep 1
done
echo "== build the API"
(cd "$api" && go build -o "$log/api" ./cmd/api)
echo "== start the API"
PORT="$api_port" DATABASE_URL="postgres://postgres@$db_host:$db_port/app?sslmode=disable" "$log/api" >"$log/api.log" 2>&1 &
pids+=($!)
wait_for "$api_port" api
echo "== build the web app"
(cd "$web" && npm ci --no-audit --no-fund && npm run build)
echo "== start the web app"
(cd "$web" && API_URL="http://127.0.0.1:$api_port" exec node_modules/.bin/vite preview --host 127.0.0.1 --port "$app_port" --strictPort) >"$log/app.log" 2>&1 &
pids+=($!)
wait_for "$app_port" app
echo "== playwright"
(cd "$web" && E2E_URL="http://127.0.0.1:$app_port" npx playwright test)
```

Write `devcontainer/checks/web-e2e.sh` (executable):

```sh
#!/bin/bash
# Rung 5 of the ladder for a web leaf (spec §9.5): Playwright runs against the built app. In a task's loop the
# API behind the app is a mock made from the leaf's copy of the contract (Prism), so the task needs no API
# of its own; the real API is part of the acceptance run (accept-e2e.sh). The ports are YGG_MOCK_PORT
# (4010) and YGG_APP_PORT (4173); it refuses to start if either is taken. Run in the leaf's top folder. Every
# server it starts is stopped.
set -euo pipefail
mock_port="${YGG_MOCK_PORT:-4010}" app_port="${YGG_APP_PORT:-4173}" wait_s="${YGG_E2E_WAIT:-60}"
log="$(mktemp -d)"
busy() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
for p in "$mock_port" "$app_port"; do
  if busy "$p"; then echo "e2e: port $p is already in use; a server of an earlier run may still be up"; exit 1; fi
done
pids=()
cleanup() {
  for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done
  wait 2>/dev/null || true
  rm -rf -- "$log"
}
trap cleanup EXIT
wait_for() { # port name
  for ((i = 0; i < wait_s; i++)); do
    if (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; then return 0; fi
    sleep 1
  done
  echo "e2e: $2 did not answer on port $1 in ${wait_s}s"
  tail -n 15 "$log/$2.log" 2>/dev/null || true
  exit 1
}
[ -d node_modules ] || npm ci --no-audit --no-fund
echo "== mock API from contracts/api.openapi.yaml"
prism mock --host 127.0.0.1 --port "$mock_port" contracts/api.openapi.yaml >"$log/mock.log" 2>&1 &
pids+=($!)
wait_for "$mock_port" mock
echo "== build"
npm run build
echo "== app"
# vite itself, not npx: the pid kept is the server's, so stopping it stops the server.
(API_URL="http://127.0.0.1:$mock_port" exec node_modules/.bin/vite preview --host 127.0.0.1 --port "$app_port" --strictPort) >"$log/app.log" 2>&1 &
pids+=($!)
wait_for "$app_port" app
echo "== playwright"
E2E_URL="http://127.0.0.1:$app_port" npx playwright test
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T229: the web stack images: Node with the ladder's tools and Chromium, and the acceptance stage with Go, all from pinned inputs

One Containerfile, two stages that are two images (decision 2): `web`, the leaf's stack, and `acceptance`, which adds the Go toolchain for the sandbox that holds the snapshot. The base is the node image the factory's own layer uses, by digest. Playwright's browsers are the ones its version asks for, so the stack installs the template's version.

**Files (in `midgard-react`):**
- Create: `containerfile_test.go`, `devcontainer/Containerfile`

**Interfaces:**
- Produces: `devcontainer/Containerfile`: `golang:1.26.9-bookworm` by digest as a stage to copy the toolchain from; `web` from the factory's node image by digest, with `git`, `curl` and CA certificates (the node image is the slim one), `oasdiff` 1.33.0, `vacuum` 0.30.6 and `osv-scanner` 2.6.0 (each checked against a SHA-256), Prism 5.16.0 and Playwright 1.63.0 installed globally at exact versions, Chromium and its system libraries by `playwright install --with-deps chromium`, and the ladder's scripts in `/opt/ygg/checks`, read-only; `acceptance` from `web`, with `/usr/local/go` and `GOTOOLCHAIN=local`.

**Acceptance criteria:**
- [ ] Every `FROM` is pinned by digest or is an earlier stage; the three downloads are checked; `npm install -g` names exact versions; nothing is piped into a shell; the context is one gungnir can hash.
- [ ] The Playwright version in the Containerfile is the template's.
- [ ] Every check script is executable and starts the way the others do. Built on a real engine (v0-H14): Node 22, Prism 5.16.0, Playwright 1.63.0 with `chromium-1243`, the three binaries, and the scripts owned by root.

**Named test:** `go test . -run 'TestTheStackImagesAreMadeOfPinnedInputsOnly|TestPlaywrightsVersionIsTheTemplatesSoItsBrowsersMatch|TestEveryCheckScriptIsExecutableAndStartsTheWayTheOthersDo'` in `midgard-react`. **Layer:** `midgard-react`. **Size:** M (149). **Depends on:** v0-T228.

- [ ] **Step 1:** write the tests.

Write `containerfile_test.go`:

```go
package midgard

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
)

var (
	fromLine   = regexp.MustCompile(`(?m)^FROM\s+(\S+)(?:\s+AS\s+(\S+))?`)
	digestRef  = regexp.MustCompile(`^[a-z0-9][a-z0-9./_-]*(:[A-Za-z0-9._-]+)?@sha256:[0-9a-f]{64}$`)
	fetchCall  = regexp.MustCompile(`fetch (https://\S+) (\S+) ([0-9a-f]{64})`)
	npmGlobal  = regexp.MustCompile(`npm install -g[^\n]*`)
	pinned     = regexp.MustCompile(`@[^@\s]+@\d+\.\d+\.\d+|^[a-z-]+@\d+\.\d+\.\d+$`)
	pipedShell = regexp.MustCompile(`\|\s*(sudo\s+)?(ba|z)?sh\b`)
)

func TestTheStackImagesAreMadeOfPinnedInputsOnly(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("devcontainer", "Containerfile"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(raw)
	stages := map[string]bool{}
	for _, f := range fromLine.FindAllStringSubmatch(text, -1) {
		if !digestRef.MatchString(f[1]) && !stages[f[1]] {
			t.Errorf("FROM %s is neither pinned by digest nor an earlier stage", f[1])
		}
		stages[f[2]] = true
	}
	for _, want := range []string{"golang", "web", "acceptance"} {
		if !stages[want] {
			t.Errorf("the Containerfile has no stage %q", want)
		}
	}
	if n := len(fetchCall.FindAllStringSubmatch(text, -1)); n != 3 {
		t.Errorf("%d downloads are checked against a SHA-256; the three release binaries are", n)
	}
	if n := strings.Count(text, "curl -"); n != 1 {
		t.Errorf("curl is used %d times; the one use is inside fetch, which checks the hash", n)
	}
	if !strings.Contains(text, `echo "$3  $2" | sha256sum -c -`) {
		t.Error("fetch does not check the download against its SHA-256 with sha256sum -c")
	}
	for _, line := range npmGlobal.FindAllString(text, -1) {
		for _, w := range strings.Fields(line)[3:] {
			if !strings.HasPrefix(w, "-") && w != "\\" && !pinned.MatchString(w) {
				t.Errorf("npm installs %q, which is not at an exact version", w)
			}
		}
	}
	if pipedShell.MatchString(text) || strings.Contains(text, "@latest") || strings.Contains(strings.ToLower(text), ":latest") {
		t.Error("the Containerfile pipes a download into a shell or names a floating version")
	}
	for _, want := range []string{"oasdiff", "vacuum", "osv-scanner", "prism-cli", "playwright install --with-deps chromium", "COPY checks/ /opt/ygg/checks/", "go-w", "/usr/local/go"} {
		if !strings.Contains(text, want) {
			t.Errorf("the Containerfile lacks %q", want)
		}
	}
	if _, err := schema.HashContext("devcontainer"); err != nil {
		t.Errorf("devcontainer is not a build context: %v", err)
	}
}

func TestPlaywrightsVersionIsTheTemplatesSoItsBrowsersMatch(t *testing.T) {
	pkg, err := os.ReadFile(filepath.Join("templates", "web", "package.json"))
	if err != nil {
		t.Fatal(err)
	}
	cf, _ := os.ReadFile(filepath.Join("devcontainer", "Containerfile"))
	m := regexp.MustCompile(`"@playwright/test": "(\d+\.\d+\.\d+)"`).FindSubmatch(pkg)
	if m == nil {
		t.Fatal("the template pins no @playwright/test")
	}
	if !strings.Contains(string(cf), "playwright@"+string(m[1])) {
		t.Errorf("the template's Playwright is %s and the stack installs another; the browsers would not match", m[1])
	}
}

func TestEveryCheckScriptIsExecutableAndStartsTheWayTheOthersDo(t *testing.T) {
	entries, err := os.ReadDir(filepath.Join("devcontainer", "checks"))
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) == 0 {
		t.Fatal("no check scripts")
	}
	for _, e := range entries {
		p := filepath.Join("devcontainer", "checks", e.Name())
		st, err := os.Stat(p)
		if err != nil {
			t.Fatal(err)
		}
		b, _ := os.ReadFile(p)
		if st.Mode()&0o111 == 0 || !strings.HasPrefix(string(b), "#!/bin/bash\n") || !strings.Contains(string(b), "set -euo pipefail") {
			t.Errorf("%s is not an executable bash script that starts with set -euo pipefail", p)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTheStackImagesAreMadeOfPinnedInputsOnly (0.00s)
    containerfile_test.go:25: open devcontainer/Containerfile: no such file or directory
--- FAIL: TestPlaywrightsVersionIsTheTemplatesSoItsBrowsersMatch (0.00s)
    containerfile_test.go:80: the template's Playwright is 1.63.0 and the stack installs another; the browsers would not match
```

- [ ] **Step 3:** write the code.

Write `devcontainer/Containerfile`:

```text
# The stack layers of the midgard-react realm (spec §6.1, §9.4). Two stages of one build, each an image:
#   web         the leaf's stack: Node, the tools of the check ladder at pinned versions, Chromium for
#               Playwright, and the ladder's scripts, baked in where the agent cannot edit them
#   acceptance  the stack of the sandbox that holds a snapshot of the whole project: web, and the Go
#               toolchain, so the acceptance run can build the API leaf beside the web app
# `ygg sandbox build --realm midgard-react` builds both. Every base is pinned by digest, every download is
# checked against a SHA-256 recorded when the version was reviewed, every package is at an exact version,
# and a version is at least two weeks old when it is pinned. A new version is a reviewed change to this file.
# The Go stage is the one the helheim-go realm builds on (its 1.26.9 is a security release, see its stack).
FROM docker.io/library/golang:1.26.9-bookworm@sha256:d9c68c2c51161e12fd77e4c6320687c9cd86e1af1e3ad6e6cd63ff970641453c AS golang

FROM docker.io/library/node@sha256:efd0ab5780c2d9ab1f0f869571a00d5edb17793bff4cce4a2792e3eb0ffc7562 AS web
ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright

# git and curl are what the checks and this file need; the rest of the system libraries are Chromium's, and
# Playwright installs them with the browser.
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git && rm -rf /var/lib/apt/lists/*

# oasdiff 1.33.0, vacuum 0.30.6 and osv-scanner 2.6.0 are release binaries.
RUN set -eu; cd /tmp; \
    fetch() { curl -fsSL -o "$2" "$1"; echo "$3  $2" | sha256sum -c -; }; \
    fetch https://github.com/oasdiff/oasdiff/releases/download/v1.33.0/oasdiff_1.33.0_linux_amd64.tar.gz oasdiff.tgz 43a4e328e2d13ba1552d760aa68d2485c75c5621f309f6ff64ae895188345247; \
    fetch https://github.com/daveshanley/vacuum/releases/download/v0.30.6/vacuum_0.30.6_linux_x86_64.tar.gz vacuum.tgz 179f038a71cd88721738d6c739dd07fbeebc905b48301935f2416e66aead95c6; \
    fetch https://github.com/google/osv-scanner/releases/download/v2.6.0/osv-scanner_linux_amd64 osv-scanner ca69b3d3cd08f889a49dc0a383122f71cc528b83803671df5fd874d97485b108; \
    tar -xzf oasdiff.tgz -C /usr/local/bin oasdiff; \
    tar -xzf vacuum.tgz -C /usr/local/bin vacuum; \
    install -m 0755 osv-scanner /usr/local/bin/osv-scanner; \
    rm -f /tmp/*.tgz /tmp/osv-scanner

# Prism makes the mock API of a task's loop from the contract. Playwright's version is the template's
# (@playwright/test in package.json): its browsers are the ones this version asks for.
RUN npm install -g --no-audit --no-fund @stoplight/prism-cli@5.16.0 playwright@1.63.0 \
 && playwright install --with-deps chromium \
 && rm -rf /var/lib/apt/lists/* \
 && chmod -R a+rX /opt/ms-playwright \
 && npm cache clean --force

# The ladder's scripts. Root owns them and nobody else may write: the agent runs as the operator's own
# user, so it can run a check and cannot weaken it.
COPY checks/ /opt/ygg/checks/
RUN chmod -R a+rX,go-w /opt/ygg/checks && chmod a+x /opt/ygg/checks/*.sh

FROM web AS acceptance
COPY --from=golang /usr/local/go /usr/local/go
ENV PATH=/usr/local/go/bin:$PATH \
    GOTOOLCHAIN=local
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T230: the planning prompts: design, spec, the design-conformance review, plan and reuse review

The stages before the code (spec §4.2) are agents with prompts. Each tells its agent where its documents go, in the shapes Odin reads: a planner's documents are published into `docs/`, the spec stage names the leaves in the realm versions the store has, the plan is tasks that a program reads and that each stand alone (the implementer sees its leaf and its task only), the conformance reviewer answers with one JSON verdict, and the reuse review reads the plan with Ponytail's eye.

**Files (in `midgard-react`):**
- Create: `prompts/conformance.md`, `prompts/design.md`, `prompts/plan.md`, `prompts/reuse-review.md`, `prompts/spec.md`, `prompts_test.go`

**Interfaces:**
- Produces: `prompts/design.md` (`out/1-product/design/<date>-<slug>.md`: summary, goals, non-goals and success criteria, context, the product at user level, decisions, open questions; stay inside the brief), `spec.md` (`out/2-engineering/specs/<date>-<slug>.md` and `out/leaves.yaml`, offering `helheim-go` 0.1.0 and `midgard-react` 0.1.0 and the paths `repos/api` and `repos/web`), `conformance.md` (`out/conformance.json`: `{"deviation": false}` or `{"deviation": true, "amendment": ...}`; what counts as a deviation; when in doubt it is one), `plan.md` (`out/2-engineering/plans/<date>-<slug>/{plan,tasks}.md` in the canonical layout; self-contained tasks; the contract first; a thin slice first) and `reuse-review.md` (`out/2-engineering/reviews/<date>-<slug>-reuse-review.md`).
- A test checks that no prompt mentions the benchmark, that each names where its documents go, and that the examples in them are what Odin reads: the verdicts through `ParseConformance`, the example task through `ParseTasks` and `CheckReady`, the leaves file through `ParseLeaves`.

**Acceptance criteria:**
- [ ] Each prompt is a page or two, names the paths its output goes to, and keeps the benchmark out of the agent's reach.
- [ ] The conformance prompt's two examples are verdicts Odin accepts; the plan prompt's task is ready; the spec prompt's leaves file parses and its second leaf consumes the first.

**Named test:** `go test . -run 'TestEveryPlanningPromptIsThereAndKeepsTheBenchmarkOutOfAgentsReach|TestThePlanningPromptsSayWhereTheirDocumentsGo|TestTheConformancePromptsExamplesAreVerdictsOdinReads|TestThePlanAndSpecPromptsExamplesAreFilesOdinReads'` in `midgard-react`. **Layer:** `midgard-react`. **Size:** M (399). **Depends on:** v0-T229.

- [ ] **Step 1:** write the tests.

Write `prompts_test.go`:

````go
package midgard

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
)

func prompt(t *testing.T, name string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("prompts", name))
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

var fence = regexp.MustCompile("(?s)```[a-z]*\n(.*?)```")

// blocks returns the fenced code blocks of a prompt.
func blocks(text string) []string {
	var out []string
	for _, m := range fence.FindAllStringSubmatch(text, -1) {
		out = append(out, m[1])
	}
	return out
}

var planningPrompts = []string{"design.md", "spec.md", "conformance.md", "plan.md", "reuse-review.md"}

// sensible checks a prompt is a page or two and keeps the benchmark out of an agent's reach.
func sensible(t *testing.T, names []string) {
	t.Helper()
	for _, name := range names {
		text := prompt(t, name)
		if len(text) < 600 || len(text) > 12<<10 {
			t.Errorf("%s is %d bytes; a prompt is a page or two", name, len(text))
		}
		for _, bad := range []string{"huldra", "hidden suite", "ouroboric-private", "benchmark"} {
			if strings.Contains(strings.ToLower(text), bad) {
				t.Errorf("%s mentions %q; an agent that builds a product never learns what scores it", name, bad)
			}
		}
	}
}

func TestEveryPlanningPromptIsThereAndKeepsTheBenchmarkOutOfAgentsReach(t *testing.T) {
	sensible(t, planningPrompts)
}

func TestThePlanningPromptsSayWhereTheirDocumentsGo(t *testing.T) {
	for name, paths := range map[string][]string{
		"design.md":       {"out/1-product/design/<date>-<slug>.md"},
		"spec.md":         {"out/2-engineering/specs/<date>-<slug>.md", "out/leaves.yaml", "docs/1-product/design/"},
		"conformance.md":  {"out/conformance.json", "reviewed/2-engineering/specs/", "reviewed/leaves.yaml", "docs/1-product/design/"},
		"plan.md":         {"out/2-engineering/plans/<date>-<slug>/", "docs/leaves.yaml", "docs/2-engineering/specs/"},
		"reuse-review.md": {"out/2-engineering/reviews/<date>-<slug>-reuse-review.md", "reviewed/2-engineering/plans/"},
	} {
		text := prompt(t, name)
		for _, p := range paths {
			if !strings.Contains(text, p) {
				t.Errorf("%s does not mention %s", name, p)
			}
		}
	}
}

// What the conformance prompt shows as the answer is an answer Odin accepts.
func TestTheConformancePromptsExamplesAreVerdictsOdinReads(t *testing.T) {
	text := prompt(t, "conformance.md")
	for _, ex := range []string{`{"deviation": false}`, `{"deviation": true, "amendment": "<text>"}`} {
		if !strings.Contains(text, ex) {
			t.Fatalf("the prompt lacks the example %s", ex)
		}
		c, err := schema.ParseConformance([]byte(strings.ReplaceAll(ex, "<text>", "The spec adds offline mode.")))
		if err != nil {
			t.Errorf("%s: %v", ex, err)
		} else if c.Deviation != strings.Contains(ex, "true") {
			t.Errorf("%s was read as %+v", ex, c)
		}
	}
}

// The task the plan prompt shows is a task Odin reads, and a ready one; the leaves file the spec prompt shows
// is a leaves file Odin reads.
func TestThePlanAndSpecPromptsExamplesAreFilesOdinReads(t *testing.T) {
	var task string
	for _, b := range blocks(prompt(t, "plan.md")) {
		if strings.Contains(b, "**Named test:**") {
			task = b
		}
	}
	if task == "" {
		t.Fatal("the plan prompt shows no task")
	}
	task = strings.NewReplacer("<plan>", "gallery", "<title>", "the API stores galleries", "<a thing that is true when the task is done>", "a gallery can be created", "<another>", "a gallery has a name",
		"<the test file and test name that proves it>", "gallery_test.go TestCreateGallery").Replace(task)
	fs, err := schema.ParseTasks("tasks.md", []byte(task))
	if err != nil || len(fs) != 1 {
		t.Fatalf("ParseTasks() = %v, %v", fs, err)
	}
	if err := schema.CheckReady(fs, []string{"repos/api"}); err != nil {
		t.Errorf("the example task is not ready: %v", err)
	}
	var leaves string
	for _, b := range blocks(prompt(t, "spec.md")) {
		if strings.HasPrefix(b, "leaves:") {
			leaves = b
		}
	}
	l, err := schema.ParseLeaves("leaves.yaml", []byte(leaves))
	if err != nil {
		t.Fatalf("ParseLeaves() = %v", err)
	}
	if got := strings.Join(l.Paths(), ","); got != "repos/api,repos/web" || l.Leaves["repos/web"].Consumes[0] != "repos/api" {
		t.Errorf("leaves = %v", l.Leaves)
	}
}
````

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestEveryPlanningPromptIsThereAndKeepsTheBenchmarkOutOfAgentsReach (0.00s)
    prompts_test.go:52: open prompts/design.md: no such file or directory
--- FAIL: TestThePlanningPromptsSayWhereTheirDocumentsGo (0.00s)
    prompts_test.go:63: open prompts/reuse-review.md: no such file or directory
```

- [ ] **Step 3:** write the code.

Write `prompts/conformance.md`:

```md
# Design conformance: does the spec stay inside the design?

You review a spec against the design it was written from. You do not improve the spec and you do not write
documents. You answer one question: **does the spec deviate from the design?** Your answer is read by a
program. It decides whether a person must look at the spec before the build goes on.

## What to read

- `docs/1-product/design/`: the approved design. It is the authority.
- `reviewed/`: the spec to check (under `reviewed/2-engineering/specs/`), and the list of leaves
  (`reviewed/leaves.yaml`).

## What counts as a deviation

The spec deviates when it does any of these:

- adds something the design does not ask for: a feature, a kind of user, a stored kind of data, a payment,
  an integration, a third-party service;
- leaves out a goal or a success criterion of the design, or a feature the design describes;
- contradicts a decision, a non-goal or a constraint of the design;
- changes what users see or can do, in a way a user would notice;
- changes who can see or delete what.

These are **not** deviations: choosing frameworks, tables, routes and field names; splitting the work into
leaves; adding tests, validation and limits that make a design feature safe; turning an open question of the
design into a decision when the spec says so in its Decisions. If the spec's own section "Deviations from the
design doc" lists something, it is still a deviation: report it.

When in doubt, it is a deviation. A person can approve it in a minute; a missed one costs a build.

## What to write

One file, `out/conformance.json`, containing one JSON document and nothing else:

- No deviation: `{"deviation": false}`
- A deviation: `{"deviation": true, "amendment": "<text>"}`

The amendment says, in plain sentences for a person who has the design open: what the spec does that the
design does not say (or the reverse), where in the spec, and the two ways to settle it: change the design to
include it, or change the spec to drop it. Keep it under 2,000 characters. Do not put anything else in the
file, not even a sentence before or after the JSON. Do not write any other file.

When you are done, answer with one sentence.
```

Write `prompts/design.md`:

````md
# Design: from a brief to a design doc

You are the first stage of a spec-driven build. A person gave you a brief (below, under "Brief"). You write
the design doc: what the product is, for whom, why, how far it goes and how anyone will know it works. A
person reads it and approves it before anything else is built. Everything later is built from what you write
and from nothing else, so what you leave out will not exist.

## What to write

One markdown file at `out/1-product/design/<date>-<slug>.md`. Get the date by running `date +%F`, and make
the slug two or three words of the product's name, lower case, joined by dashes.

Start with this front matter:

```
---
title: <the product's name> design
status: draft
date: <the date>
related: []
---
```

Then these sections, in this order, each with a `##` heading:

1. **Summary**: what the product is, for whom, in four sentences at most.
2. **Goals, non-goals and success criteria**: goals as a short list. Non-goals as a short list, with the
   reason for each one (a non-goal is a decision, not an oversight). Success criteria that a person could
   check by using the product, each one a single sentence that can be true or false.
3. **Context and constraints**: who the users are, what they do today, and the limits the brief gives: time,
   budget, law, devices, hosting, languages. Say what you assumed because the brief did not say.
4. **The product at user level**: what each kind of user can do, step by step, in words a user would use.
   Include what happens when things go wrong: an empty list, a failed upload, a wrong link, a lost password.
   Include what the product stores about people and who can see it.
5. **Decisions**: each as `**Decided <date>:** <the decision>. <the reason>.` Decide what the brief leaves open
   and the design needs. Keep the list short: only decisions someone could reasonably have made the other
   way.
6. **Open questions**: what you could not decide and a person should. Say who could answer.

## Rules

- Stay inside the brief. Do not add a feature, a user group, a payment, an integration or a kind of stored
  data that the brief does not ask for. If you think one is needed, put it in Open questions.
- Write for a reader who has not seen the brief. Short sentences, active voice, no undefined jargon, no
  marketing words. Name things the way users would.
- Do not design the system. No frameworks, tables, endpoints or libraries here: that is the spec's job.
  Say what the product does, never how it is built.
- Success criteria are about behaviour a person can observe. "Fast" is not one. "A page of 50 photos shows
  within two seconds on a phone" is one.
- Privacy and safety are part of the design: say who may see what, and what a person can delete.
- Do not read or write anything outside your workspace. Write only under `out/`.

When you are done, answer with one or two sentences: what the design covers, and the open questions that
matter most.
````

Write `prompts/plan.md`:

````md
# Plan: from an approved spec to tasks that can be built

You are the third stage of a spec-driven build. The spec is approved and the leaves are named. You write the
plan and the tasks. Each task is built by a different agent, in a fresh session, in one leaf, in order. A
program checks that each task is ready before anything is built, and sends the whole plan back to you, with
every problem, if one is not.

## What to read

`docs/2-engineering/specs/` holds the approved spec, `docs/leaves.yaml` the leaves, and `docs/1-product/` the
design. If a plan from before is in `docs/2-engineering/plans/`, this is a change: plan only what is new.

## What to write

A folder `out/2-engineering/plans/<date>-<slug>/` (the date from `date +%F`) with two files.

### `plan.md`

Front matter (`title`, `status: draft`, `date`, `related` with a link to the spec), then **Goal**; **Order**
(a table: task id, leaf, size, depends on); **Decisions** (each `**Decided <date>:** <decision>. <reason>.`,
for choices the spec left to you: the order, how a feature is split, what is built first); **Risks**.

### `tasks.md`

Front matter as above, then one section for each task, exactly in this form (a program reads it):

```
## <plan>-T001: <title>

- **Acceptance criteria:**
  - [ ] <a thing that is true when the task is done>
  - [ ] <another>
- **Named test:** <the test file and test name that proves it>
- **Layer:** repos/api
- **Size:** S
- **Depends on:** nothing
```

- The id is `<slug>-T001`, `<slug>-T002` and so on. A title says what the task delivers.
- **Layer** is a leaf path from `docs/leaves.yaml`, exactly. One task works in one leaf.
- **Size**: S is under 100 changed lines, M is 100 to 400. A task that is bigger is split: the plan is sent
  back if any task is L. Prefer S.
- **Depends on** lists task ids, separated by commas, or `nothing`. Dependencies form no loop.
- **Named test** is the file and the test that will fail before the task is built and pass after. The
  implementer writes it first.

## How to cut the work

- **Each task is self-contained.** The agent that builds it sees its leaf and the task, nothing else: not the
  design, not the spec, not the other leaves. Put into the task everything it needs: the behaviour, the exact
  routes, fields, status codes and messages, the files or components to change, the limits and the errors.
  When a task changes the API's contract, give the full text of the OpenAPI addition. When a web task calls
  a route, give the same text, so it can copy the contract exactly.
- **The contract first.** A task that adds or changes a route comes before the task in another leaf that
  uses it, and the consumer depends on it.
- **A thin working slice first.** The first tasks end with something a person can run, even if small. Later
  tasks add to it.
- **Tests belong to tasks.** Do not make a task of "write tests". Each task has its own, written first.
- **Security is part of every task** that touches it: who may do this, how the server checks it, what
  happens when someone else asks for it.
- **No task for what is not in the spec.** No cleanup, refactoring or tooling tasks.
- Acceptance criteria are checkable by a test or by using the product. Two to five for each task.

## Rules

- Write only under `out/`. Short sentences, active voice, concrete values.
- Keep the plan as small as the spec allows. Fewer, clearer tasks beat many.

When you are done, answer with one or two sentences: how many tasks, in how many leaves, and what is built
first.
````

Write `prompts/reuse-review.md`:

```md
# Reuse review: does the plan build what already exists?

You review a plan before it is built, looking for work the plan does not need. You do not change the plan.
You write a short report that a person reads when they decide whether to approve the plan.

The skill below is a code reviewer's. Use its eye on the plan: read each task as if it were the change.
Where it looks for code that should not exist, look in the plan for tasks, dependencies and abstractions that
should not exist.

## What to read

- `reviewed/2-engineering/plans/`: the plan and its tasks.
- `docs/2-engineering/specs/`: the spec the plan builds. `docs/leaves.yaml`: the leaves.

## What to look for

- A task that adds a **dependency** (a library, a service, a tool) where the standard library, the platform
  or what the leaf's template already has does the job.
- A task that adds an **abstraction** (a layer, a framework, a configuration system, a plugin point) for one
  use.
- Two tasks that build the same thing in two places, or build again what an earlier task already delivers.
- A task for something the spec does not ask for.
- A task that could be removed with no acceptance criterion of the spec missing.

Each finding needs a concrete case: the task id, what it adds, and what already does the job (name the file
or the library function). If you cannot name it, it is not a finding.

## What to write

One file, `out/2-engineering/reviews/<date>-<slug>-reuse-review.md` (the date from `date +%F`, the slug of the
plan's folder). Front matter (`title`, `status: draft`, `date`, `related` with a link to the plan), then a
`##` heading **Verdict** (one line: "Nothing to remove." or "Remove or change N things."), and a heading
**Findings** with one numbered item for each finding: the task id, what it adds, what already does the job,
and the smallest change to the plan. Nothing else. Do not write any other file.

When you are done, answer with one sentence.
```

Write `prompts/spec.md`:

````md
# Spec: from an approved design to an engineering spec

You are the second stage of a spec-driven build. The design doc is approved. You write the engineering spec
that builds it, and the list of repositories (leaves) the product will have. A second agent checks your spec
against the design, and a person approves the leaves. Everything later is built from what you write.

## What to read

`docs/1-product/design/` in your workspace holds the approved design. Read all of it. If a file named
`docs/leaves.yaml` or an earlier spec is there, this is a change to a product that exists: keep what it says
and change only what the design now asks for.

## What to write

### 1. The spec: `out/2-engineering/specs/<date>-<slug>.md`

Get the date by running `date +%F`. The slug is the design's slug. Front matter:

```
---
title: <the product's name> spec
status: draft
date: <the date>
related: [<relative link to the design doc>]
---
```

Sections, in this order: **Summary**; **Architecture and components**; **Interfaces and contracts**; **Data
model**; **Acceptance criteria per feature**; **Security considerations**; **Testing approach**;
**Decisions** (each `**Decided <date>:** <decision>. <reason>.`); **Deviations from the design doc**.

- *Deviations from the design doc* is empty (write "None.") unless the design cannot be built as written.
  List each deviation and why. A deviation stops the spec for a person to decide; use it only when you must.
- Every feature of the design has acceptance criteria here, each one testable by a program or a person
  without asking you what it meant. Name inputs and outputs: paths, fields, status codes, messages.
- *Interfaces and contracts*: give the API's routes with methods, request and response fields, status codes
  and errors, in enough detail that two people could build the two sides apart and have them fit.
- *Security considerations*: who may do what, how that is checked on the server, what is stored about
  people, what is never stored, how files and keys are named, which limits stop abuse.
- Do not add anything the design does not ask for.

### 2. The leaves: `out/leaves.yaml`

The repositories the product is built in. One leaf for each part that is built and tested on its own. For a
product with a web app and a server, that is two:

```
leaves:
  repos/api:
    realm: helheim-go
    realm_version: 0.1.0
    description: The product's API.
  repos/web:
    realm: midgard-react
    realm_version: 0.1.0
    description: The product's web app.
    consumes: [repos/api]
```

- The realms you may use, and their versions: `helheim-go` 0.1.0 (a Go HTTP API with Postgres and
  object storage) and `midgard-react` 0.1.0 (a React web app). Use only these, at these versions.
- `consumes` lists the leaves whose API or contract this leaf calls.
- A path is `repos/<name>`. A description is one line. When the product has a web app and an API, name them
  `repos/web` and `repos/api`: the acceptance run looks there.
- A product with no server of its own has only `repos/web`.

## Rules

- Write only under `out/`. Do not change `docs/` or anything else.
- Short sentences, active voice, concrete examples. Say "the API returns 404", not "an appropriate error".
- If the design is unclear, choose the simplest reading that satisfies its success criteria, and write the
  choice as a Decision.

When you are done, answer with one or two sentences: what the spec covers, and any deviation you listed.
````

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T231: the build prompts: the web implementer and the three reviewers

The task loop's agents (spec §9.5 rung 6): the implementer of the web leaf, and three read-only reviewers, in the spec's order: spec compliance, simplicity, quality. Odin adds the findings format to a reviewer's prompt, so the prompts say what to look for and how to name findings, not the format. The simplicity reviewer loads Ponytail's skill and maps its groups to severities: must fix is a blocker, should fix is major, nice to have is minor.

**Files (in `midgard-react`):**
- Create: `build_prompts_test.go`, `prompts/implementer.md`, `prompts/reviewer-quality.md`, `prompts/reviewer-simplicity.md`, `prompts/reviewer-spec.md`

**Interfaces:**
- Produces: `prompts/implementer.md` (read `AGENTS.md`; test first; one task; the contract text is copied exactly and `gen:api` run; every state; accessible; no photo bytes through the API; the four commands to run before stopping; no `git commit`, no change to the checks, the devcontainer or Playwright's config), `reviewer-spec.md` (each criterion: done, tested, matches its words; more than asked; the contract; the named test), `reviewer-simplicity.md` and `reviewer-quality.md` (correctness, security, tests, accessibility and states, the rules, readability), with the ids `spec-1`, `simple-1`, `quality-1`.

**Acceptance criteria:**
- [ ] Each prompt keeps the benchmark out; the implementer names only `npm` scripts the template has, and the files and commands it must use.
- [ ] Each reviewer says it is read-only, how to see the change (`git diff $(git merge-base HEAD main) HEAD`), the id scheme, `file:line` and the severities; none talks of committing.

**Named test:** `go test . -run 'TestEveryBuildPromptIsThereAndKeepsTheBenchmarkOutOfAgentsReach|TestThePromptsNameOnlyScriptsAndCommandsThatExist|TestTheReviewersSayWhatToLookAtAndHowToNameFindings'` in `midgard-react`. **Layer:** `midgard-react`. **Size:** M (221). **Depends on:** v0-T230.

- [ ] **Step 1:** write the tests.

Write `build_prompts_test.go`:

```go
package midgard

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

var buildPrompts = []string{"implementer.md", "reviewer-spec.md", "reviewer-simplicity.md", "reviewer-quality.md"}

func TestEveryBuildPromptIsThereAndKeepsTheBenchmarkOutOfAgentsReach(t *testing.T) {
	sensible(t, buildPrompts)
}

func TestThePromptsNameOnlyScriptsAndCommandsThatExist(t *testing.T) {
	pkg, err := os.ReadFile(filepath.Join("templates", "web", "package.json"))
	if err != nil {
		t.Fatal(err)
	}
	var p struct{ Scripts map[string]string }
	if err := json.Unmarshal(pkg, &p); err != nil {
		t.Fatal(err)
	}
	run := regexp.MustCompile("npm (?:run )?([a-z0-9:]+)")
	for _, name := range []string{"implementer.md"} {
		for _, m := range run.FindAllStringSubmatch(prompt(t, name), -1) {
			if m[1] == "test" || m[1] == "ci" {
				if m[1] == "test" && p.Scripts["test"] == "" {
					t.Errorf("%s names npm test, which the template lacks", name)
				}
				continue
			}
			if _, ok := p.Scripts[m[1]]; !ok {
				t.Errorf("%s names npm run %s, which the template's package.json lacks", name, m[1])
			}
		}
	}
	impl := prompt(t, "implementer.md")
	for _, want := range []string{"AGENTS.md", "Test first", "Do not run `git commit`", "contracts/api.openapi.yaml", "npm run gen:api", ".devcontainer/", "Findings to fix", "src/lib/api.ts"} {
		if !strings.Contains(impl, want) {
			t.Errorf("implementer.md lacks %q", want)
		}
	}
}

func TestTheReviewersSayWhatToLookAtAndHowToNameFindings(t *testing.T) {
	for name, ids := range map[string]string{"reviewer-spec.md": "spec-1", "reviewer-simplicity.md": "simple-1", "reviewer-quality.md": "quality-1"} {
		text := prompt(t, name)
		for _, want := range []string{"read-only", "git merge-base HEAD main", ids, "file:line", "**blocker**"} {
			if want == "**blocker**" && name == "reviewer-simplicity.md" {
				want = "**Must fix**"
			}
			if !strings.Contains(text, want) {
				t.Errorf("%s lacks %q", name, want)
			}
		}
		if strings.Contains(text, "git commit") {
			t.Errorf("%s talks of committing; a reviewer changes nothing", name)
		}
	}
	if !strings.Contains(prompt(t, "reviewer-simplicity.md"), "The skill below") || !strings.Contains(prompt(t, "reuse-review.md"), "The skill below") {
		t.Error("a prompt that relies on the vendored skill must say that the skill follows it")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestEveryBuildPromptIsThereAndKeepsTheBenchmarkOutOfAgentsReach (0.00s)
    build_prompts_test.go:15: open prompts/implementer.md: no such file or directory
--- FAIL: TestThePromptsNameOnlyScriptsAndCommandsThatExist (0.00s)
    build_prompts_test.go:29: open prompts/implementer.md: no such file or directory
```

- [ ] **Step 3:** write the code.

Write `prompts/implementer.md`:

````md
# Implementer: React web leaf

You build one task in a React web app. You work in the repository you start in. It is one leaf of a product;
you see this leaf and your task, nothing else. The task below says what to build, the acceptance criteria and
the test that proves it.

## Before you write code

1. Read `AGENTS.md`. It holds the rules of this leaf. They bind you.
2. Read `src/router.tsx`, `src/routes`, `src/components`, `src/lib/api.ts` and `contracts/api.openapi.yaml`.
   Find where the task belongs. Follow the style of the code that is there.
3. If the prompt has a section "Findings to fix", fix every finding in it.

## How to work

- **Test first.** Write the unit test the task names (Vitest and Testing Library, beside the code) before the
  code. Run it and see it fail for the reason the task gives. Then write the least code that makes it pass.
  A test that passes before your code exists proves nothing, and the factory refuses it. For something a
  person does in the browser, also write a Playwright spec in `e2e/`, one for each such acceptance criterion.
- **One task, nothing more.** Build what the acceptance criteria say. Add no page, option or dependency the
  task does not need. Use what is here first: the base components, TanStack Router and Query, the typed
  client.
- **The API contract.** When the task gives you contract text, copy it exactly into
  `contracts/api.openapi.yaml`, then run `npm run gen:api`. Call the API only through `src/lib/api.ts`. If the
  task needs a route the contract lacks, stop and say so in your summary: do not invent one.
- **Every state.** A screen shows loading, empty, error and success. A form checks its input before it sends
  and shows what the server answers. Nothing breaks on a slow or failed request.
- **Accessible.** Real buttons and links, labels on inputs, text alternatives, a visible focus, keyboard use.
- **Photo bytes never pass through the API.** Uploads and downloads go to the presigned URLs the API hands out.
- **Secrets.** Write none into code, tests, logs or docs. A test uses made-up values.

## Check your work before you stop

Run these in the repository and fix what they say:

```
npm run lint
npm run typecheck
npm test
npm run build
```

`npm run test:e2e` needs a browser and an API; the factory runs it against a mock of the contract. Write the
specs anyway, and read them as a user would.

## What you must not do

- Do not run `git commit`, `git checkout`, `git reset` or any other command that changes history or
  branches. The factory commits your work after you stop.
- Do not change `.devcontainer/`, `playwright.config.ts`, the versions in `package.json`, or any script or
  tool that checks your work. If a check seems wrong, say so in your summary and leave it.
- Do not read or change files outside this repository.

When you are done, answer with a short summary: what you built, which tests prove it, and anything a
reviewer should look at first.
````

Write `prompts/reviewer-quality.md`:

```md
# Reviewer: is the work good enough to keep?

You review the work of one task in this repository, read-only, for quality. Another reviewer checks it does
what the task says, another checks its simplicity. You do not change any file.

## What to read

The change: `git diff $(git merge-base HEAD main) HEAD` shows everything the task changed. Read it all, then
the code it touches, its callers and its tests. `AGENTS.md` holds the rules of this repository.

## What to look for

- **Correctness.** A wrong result, a crash, a missed case (empty, zero, one, many, the last item, a failed or
  slow request, a double click, a stale cache). A change that breaks a caller. These are **blocker** when a
  user would hit them in normal use, **major** otherwise.
- **Security.** Input trusted without a check; a check done only on the client; a secret, a token or a
  person's data in code, tests or logs; a URL or a key built from user input; an upload or download that
  passes bytes through the API; HTML built from strings. A security hole is a **blocker**.
- **Tests.** A test that asserts nothing a user would care about, mocks away what it should test, depends on
  timing or order, or would pass if the code were wrong: **major**. Risky logic with no test: **major**.
- **Accessibility and states.** A control a keyboard cannot reach, an input without a label, an image
  without alternative text, a screen with no loading, empty or error state: **major**.
- **Rules.** A rule in `AGENTS.md` that the change breaks: **major**; **blocker** if the rule says never.
- **Readability.** Names that mislead, comments that lie, a function nobody can follow: **minor**.

Do not report taste. Do not report what the other reviewers report: whether the task is done, and whether
the code could be smaller.

## How to report

Every finding has a location (`file:line`) and a claim in plain words: the case that goes wrong, what
happens, and the fix. No case, no finding. Use the ids `quality-1`, `quality-2`, ... in the order you find
them, and keep an id for the same problem when you look again. If the work is good, report no findings.
```

Write `prompts/reviewer-simplicity.md`:

```md
# Reviewer: is the work as simple as it can be?

You review the work of one task in this repository, read-only, for simplicity. Another reviewer checks it does
what the task says, another checks its quality. You do not change any file.

The skill below is the method. Review the change of this task: `git diff $(git merge-base HEAD main) HEAD`
shows it. Read the code it touches too.

## What to report

Report what the skill calls a finding: code that should not exist or should be smaller (dead code, unused
options, speculative features, a new dependency for a few lines, an abstraction with one use, near-copies that
must change together, a function that does several jobs), and the bugs and risks it finds on the way. Every
finding needs a concrete case, as the skill says.

Map the skill's groups to severities:

- **Must fix**: **blocker**.
- **Should fix**: **major**.
- **Nice to have**: **minor**.

## How to report

Do not use the skill's report format: your answer is read by a program, in the format you are given below.
Each finding has a location (`file:line`), and a claim in plain words that says what is there, why it is not
needed or is wrong, and the smallest fix. Use the ids `simple-1`, `simple-2`, ... in the order you find them,
and keep an id for the same problem when you look again. If the change is as simple as it can be, report no
findings. Do not report style or naming.
```

Write `prompts/reviewer-spec.md`:

```md
# Reviewer: does the work do what the task says?

You review the work of one task in this repository, read-only. You check it against the task and nothing
else. Another reviewer looks at the code's simplicity, another at its quality. You do not change any file.

## What to read

- The task below ("Your task"): its acceptance criteria and the test that proves it.
- The change: `git diff $(git merge-base HEAD main) HEAD` shows everything the task changed. Read it all,
  then read the code it touches.
- `AGENTS.md`: the rules of this repository.

## What to check

For each acceptance criterion, in order:

1. Is it done? Find the code that does it and say where. A criterion with no code is a **blocker**.
2. Is it tested? Find the test that fails without that code. A criterion with no test, or a test that would
   pass without the code, is **major**.
3. Does the behaviour match the words? Read the criterion as a user would. A behaviour that differs from it is
   a **blocker**.

Then:

- **More than asked.** Behaviour, routes, options or dependencies the task does not ask for: **major**.
- **The contract.** If the task gives contract text, the leaf's copy matches it exactly and the generated
  types are current: a mismatch is a **blocker**. If the work changes what the API or the app promises
  without the task saying so: **major**.
- **The named test.** The test the task names exists and proves the task: if not, **major**.
- **Documentation.** If the work changes how the app is used or run and `README.md` or `docs/` says
  otherwise: **minor**.

## How to report

Report only what you can point at. Every finding has a location (`file:line`) and a claim that says what is
wrong and what the task asked for. Use the ids `spec-1`, `spec-2`, ... in the order you find them, and keep
an id for the same problem when you look again. Report nothing about style, naming or structure: the other
reviewers do.
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T232: the midgard-react pack and graph: the stages of a web product, the task loop with three reviewers, and the acceptance run

The lead realm's graph (spec §4.2) in the nodes Phase 5a built: design (scratch agent, gate, publish); spec, the conformance review, the spec gate that reads its verdict, publish; plan, the reuse review, publish, publish; the plan read into tasks (a refusal goes back to the planner), the leaves created, the plan gate; then for every task the implementer's loop with the ladder and the three reviewers, the feature and merge gates, the merge, the pointer gate and the pointer move with the acceptance run (a refusal of either goes back to the implementer). There is no `pointer-contract` gate: it waits for the impact index (5c).

**Files (in `midgard-react`):**
- Create: `graph.yaml`, `pack.yaml`, `pack_test.go`

**Interfaces:**
- Produces: `graph.yaml` and `pack.yaml` (`version: 0.1.0`; the checks `static`, `unit`, `tdd`, `contract`, `security`, `e2e` and `accept`, each one script in `/opt/ygg/checks`; `leaf.checks` in that order; `sandbox.build: devcontainer` with `target: web`, the hosts `registry.npmjs.org` and `api.osv.dev`, and `acceptance: {build: devcontainer, target: acceptance}`). The roles the graph uses are `planner`, `implementer` and `reviewer`: the operator's `factory.yaml` defines them.

**Acceptance criteria:**
- [ ] The pack loads; its two stack tags are two images of one context; every check runs a baked script and every baked script is used; the stages it builds are stages of the Containerfile.
- [ ] The graph has the nodes in the order above, `conformance` reviews `spec`, `spec-gate` reads `conformance` and re-runs `spec`, `ready` goes back to `plan`, and the task shape is implement (three attempts, three reviewers, the simplicity one with the skill), feature gate, merge gate, merge, pointer gate, pointer move with `accept`.
- [ ] Every prompt a node names is there and every prompt is used; the spec prompt offers this realm at this pack's version.

**Named test:** `go test . -run 'TestThePackLoadsAsTheLeadRealmWithTwoStacksFromOneContext|TestTheSpecPromptNamesThisRealmAtTheVersionOfThisPack|TestTheGraphHasTheStagesOfSpecSection42InOrder|TestEveryTaskRunsTheLoopWithThreeReviewersThenTheGatesAndTheMoveWithAcceptance|TestEveryPromptIsUsedAndEveryPromptTheGraphNamesIsThere'` in `midgard-react`. **Layer:** `midgard-react`. **Size:** M (262). **Depends on:** v0-T231.

- [ ] **Step 1:** write the tests.

Write `pack_test.go`:

```go
package midgard

import (
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
)

func loadPack(t *testing.T) *schema.Pack {
	t.Helper()
	p, err := schema.LoadPack(".")
	if err != nil {
		t.Fatalf("LoadPack() = %v", err)
	}
	return p
}

func loadGraph(t *testing.T) *schema.Graph {
	t.Helper()
	g, err := schema.LoadGraph("graph.yaml")
	if err != nil {
		t.Fatalf("LoadGraph() = %v", err)
	}
	return g
}

func TestThePackLoadsAsTheLeadRealmWithTwoStacksFromOneContext(t *testing.T) {
	p := loadPack(t)
	if p.Name != "midgard-react" || p.Graph != "graph.yaml" || p.Leaf == nil {
		t.Fatalf("pack = %+v", p)
	}
	web, err := p.StackRef(".")
	if err != nil {
		t.Fatal(err)
	}
	acc, err := p.AcceptanceRef(".")
	if err != nil {
		t.Fatal(err)
	}
	if !regexp.MustCompile(`^localhost/ygg-stack-midgard-react:[0-9a-f]{12}$`).MatchString(web) ||
		!regexp.MustCompile(`^localhost/ygg-stack-midgard-react-acceptance:[0-9a-f]{12}$`).MatchString(acc) || web == acc {
		t.Errorf("stacks %q and %q; the leaf's and the acceptance sandbox's are two images of one context", web, acc)
	}
	want := []string{"static", "unit", "tdd", "contract", "security", "e2e"}
	if strings.Join(p.Leaf.Checks, ",") != strings.Join(want, ",") {
		t.Errorf("the ladder is %v, want %v: cheap rungs first, the browser last", p.Leaf.Checks, want)
	}
	for name, argv := range p.Checks {
		if len(argv) != 1 || !strings.HasPrefix(argv[0], "/opt/ygg/checks/") {
			t.Errorf("check %s is %v; it must be one script in /opt/ygg/checks", name, argv)
			continue
		}
		if st, err := os.Stat(filepath.Join("devcontainer", "checks", filepath.Base(argv[0]))); err != nil || st.Mode()&0o111 == 0 {
			t.Errorf("check %s names %s, which devcontainer/checks does not hold as an executable: %v", name, argv[0], err)
		}
	}
	entries, _ := os.ReadDir(filepath.Join("devcontainer", "checks"))
	for _, e := range entries {
		used := e.Name() == "docs.sh" // run by web-static.sh
		for _, argv := range p.Checks {
			used = used || filepath.Base(argv[0]) == e.Name()
		}
		if !used {
			t.Errorf("devcontainer/checks/%s is baked into the image and no check runs it", e.Name())
		}
	}
	for _, h := range p.Sandbox.Egress {
		if !gungnir.ValidHost(h) {
			t.Errorf("egress %q is not a plain host", h)
		}
	}
	// The stages the pack asks for are stages of the Containerfile.
	cf, _ := os.ReadFile(filepath.Join("devcontainer", "Containerfile"))
	for _, stage := range []string{p.Sandbox.Target, p.Sandbox.Acceptance.Target} {
		if !regexp.MustCompile(`(?m)^FROM .* AS ` + stage + `$`).Match(cf) {
			t.Errorf("the pack builds the stage %q, which the Containerfile lacks", stage)
		}
	}
}

func TestTheSpecPromptNamesThisRealmAtTheVersionOfThisPack(t *testing.T) {
	want := "`midgard-react` " + loadPack(t).Version
	if !strings.Contains(prompt(t, "spec.md"), want) {
		t.Errorf("spec.md does not offer %s: a spec that names another version fails the leaves check", want)
	}
}

func TestTheGraphHasTheStagesOfSpecSection42InOrder(t *testing.T) {
	g := loadGraph(t)
	var ids []string
	for _, n := range g.Nodes {
		ids = append(ids, n.ID)
	}
	want := "design,design-gate,design-docs,spec,conformance,spec-gate,spec-docs,plan,reuse-review,plan-docs,reuse-docs,ready,leaves,plan-gate,tasks"
	if strings.Join(ids, ",") != want {
		t.Errorf("nodes = %v", ids)
	}
	by := map[string]schema.Node{}
	for _, n := range g.Nodes {
		by[n.ID] = n
	}
	if by["conformance"].Reviews != "spec" || by["spec-gate"].DeviationFrom != "conformance" || by["spec-gate"].Reruns != "spec" ||
		by["reuse-review"].Reviews != "plan" || by["ready"].BackTo != "plan" || by["plan-gate"].Reruns != "plan" {
		t.Errorf("the spec stage and the plan stage are not wired as spec §4.2 says: %+v", by)
	}
	if !slices.Contains(by["reuse-review"].Skills, "ponytail-review") {
		t.Error("the reuse review does not load the Ponytail skill")
	}
	// A planner works in a scratch workspace and publishes after its gate; none touches a leaf.
	for _, id := range []string{"design", "spec", "conformance", "plan", "reuse-review"} {
		if !by[id].Scratch || by[id].Repo != "" {
			t.Errorf("%s is not a scratch agent", id)
		}
	}
	for id, from := range map[string]string{"design-docs": "design", "spec-docs": "spec", "plan-docs": "plan", "reuse-docs": "reuse-review"} {
		if by[id].From != from || by[id].To != "docs" {
			t.Errorf("%s publishes %s to %q, want %s to docs", id, by[id].From, by[id].To, from)
		}
	}
}

func TestEveryTaskRunsTheLoopWithThreeReviewersThenTheGatesAndTheMoveWithAcceptance(t *testing.T) {
	g := loadGraph(t)
	body := g.Nodes[len(g.Nodes)-1].Body
	var ids []string
	for _, n := range body {
		ids = append(ids, n.ID)
	}
	if strings.Join(ids, ",") != "implement,feature-gate,merge-gate,land,pointer-gate,move" {
		t.Fatalf("the task shape = %v", ids)
	}
	impl := body[0]
	var rv []string
	for _, r := range impl.Reviewers {
		rv = append(rv, r.ID)
	}
	if impl.RealmFrom != schema.RealmLeaf || impl.Role != "implementer" || impl.Attempts != 3 || strings.Join(rv, ",") != "spec-compliance,simplicity,quality" {
		t.Errorf("implement = %+v; reviewers %v run in the spec's order (§9.5 rung 6)", impl, rv)
	}
	if !slices.Contains(impl.Reviewers[1].Skills, "ponytail-review") {
		t.Error("the simplicity reviewer does not load the Ponytail skill")
	}
	land, move := body[3], body[5]
	if land.BackTo != "implement" || move.BackTo != "implement" || !slices.Equal(move.Acceptance, []string{"accept"}) {
		t.Errorf("land %+v, move %+v: a refusal goes back to the implementer, and the move runs the acceptance check", land, move)
	}
	if _, ok := loadPack(t).Checks["accept"]; !ok {
		t.Error("the graph's acceptance check is not defined in the pack")
	}
}

func TestEveryPromptIsUsedAndEveryPromptTheGraphNamesIsThere(t *testing.T) {
	g := loadGraph(t)
	used := map[string]bool{"implementer.md": true} // the leaf recipe's
	roles := map[string]bool{}
	for _, n := range g.All() {
		if n.Prompt != "" {
			used[filepath.Base(n.Prompt)] = true
			if _, err := os.Stat(n.Prompt); err != nil {
				t.Errorf("node %s names the prompt %s: %v", n.ID, n.Prompt, err)
			}
		}
		if n.Role != "" {
			roles[n.Role] = true
		}
		for _, r := range n.Reviewers {
			used[filepath.Base(r.Prompt)] = true
			roles[r.Role] = true
			if _, err := os.Stat(r.Prompt); err != nil {
				t.Errorf("reviewer %s names the prompt %s: %v", r.ID, r.Prompt, err)
			}
		}
	}
	entries, _ := os.ReadDir("prompts")
	for _, e := range entries {
		if !used[e.Name()] {
			t.Errorf("prompts/%s is used by no node", e.Name())
		}
	}
	for r := range roles {
		if !slices.Contains([]string{"planner", "implementer", "reviewer"}, r) {
			t.Errorf("the graph uses the role %q, which an operator's factory.yaml is not told to define", r)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestThePackLoadsAsTheLeadRealmWithTwoStacksFromOneContext (0.00s)
    pack_test.go:34: LoadPack() = open pack.yaml: no such file or directory
--- FAIL: TestTheSpecPromptNamesThisRealmAtTheVersionOfThisPack (0.00s)
    pack_test.go:88: LoadPack() = open pack.yaml: no such file or directory
```

- [ ] **Step 3:** write the code.

Write `graph.yaml`:

```yaml
# The graph of a web product (spec §4.2): the stages that write documents in scratch workspaces, Odin
# publishing them after the approval points, the plan read into tasks, the leaves created from their realms'
# templates, and then, for every task, a loop of the implementer with the check ladder and three reviewers, the
# merge gate and the pointer move with the acceptance run. The roles are the operator's factory.yaml roles:
# planner, implementer and reviewer.
name: midgard-react
version: 0.1.0
nodes:
  - { id: design, kind: agent, role: planner, prompt: prompts/design.md, scratch: true, max_turns: 30, timeout: 20m }
  - { id: design-gate, kind: gate, gate: design }
  - { id: design-docs, kind: publish, from: design, to: docs }
  - { id: spec, kind: agent, role: planner, prompt: prompts/spec.md, scratch: true, inputs: [docs/1-product], max_turns: 40, timeout: 30m }
  - { id: conformance, kind: agent, role: reviewer, prompt: prompts/conformance.md, scratch: true, reviews: spec, inputs: [docs/1-product], max_turns: 15, timeout: 10m }
  - { id: spec-gate, kind: gate, gate: spec, reruns: spec, deviation_from: conformance }
  - { id: spec-docs, kind: publish, from: spec, to: docs }
  - { id: plan, kind: agent, role: planner, prompt: prompts/plan.md, scratch: true, inputs: [docs/1-product, docs/2-engineering/specs, docs/leaves.yaml], max_turns: 40, timeout: 30m }
  - { id: reuse-review, kind: agent, role: reviewer, prompt: prompts/reuse-review.md, scratch: true, reviews: plan, inputs: [docs/2-engineering/specs, docs/leaves.yaml], skills: [ponytail-review], max_turns: 15, timeout: 10m }
  - { id: plan-docs, kind: publish, from: plan, to: docs }
  - { id: reuse-docs, kind: publish, from: reuse-review, to: docs }
  - { id: ready, kind: tasks, from: docs/2-engineering/plans/*/tasks.md, leaves: docs/leaves.yaml, back_to: plan }
  - { id: leaves, kind: init, from: docs/leaves.yaml }
  - { id: plan-gate, kind: gate, gate: plan, reruns: plan }
  - id: tasks
    kind: foreach
    over: tasks
    nodes:
      - id: implement
        kind: loop
        realm: leaf
        role: implementer
        attempts: 3
        max_turns: 60
        timeout: 30m
        reviewers:
          - { id: spec-compliance, role: reviewer, prompt: prompts/reviewer-spec.md, max_turns: 20, timeout: 10m }
          - { id: simplicity, role: reviewer, prompt: prompts/reviewer-simplicity.md, skills: [ponytail-review], max_turns: 20, timeout: 10m }
          - { id: quality, role: reviewer, prompt: prompts/reviewer-quality.md, max_turns: 20, timeout: 10m }
      - { id: feature-gate, kind: gate, gate: feature }
      - { id: merge-gate, kind: gate, gate: merge }
      - { id: land, kind: merge, realm: leaf, back_to: implement }
      - { id: pointer-gate, kind: gate, gate: pointer }
      - { id: move, kind: pointer, realm: leaf, acceptance: [accept], timeout: 25m, back_to: implement }
```

Write `pack.yaml`:

```yaml
# The React flavor of the Midgard realm (change realm-leaf-naming): the lead realm of the client gallery. It
# holds the graph of a web product (spec §4.2), the planning prompts and reviewers, and the recipe of a React
# web leaf. A project that also needs a Go API pins helheim-go for that leaf. The check ladder is rungs 1 to
# 5 of spec §9.5 in the task's loop; rung 6 is the three reviewers in the graph; the acceptance run is the
# pointer move's, and rung 7 is the grader's.
name: midgard-react
version: 0.1.0
graph: graph.yaml
checks:
  static: [/opt/ygg/checks/web-static.sh]
  unit: [/opt/ygg/checks/web-unit.sh]
  tdd: [/opt/ygg/checks/web-tdd.sh]
  contract: [/opt/ygg/checks/web-contract.sh]
  security: [/opt/ygg/checks/web-security.sh]
  e2e: [/opt/ygg/checks/web-e2e.sh]
  accept: [/opt/ygg/checks/accept-e2e.sh]
leaf:
  description: A React web app that talks to its API through a typed contract
  template: templates/web
  first_commit: [LICENSE]
  implementer: prompts/implementer.md
  checks: [static, unit, tdd, contract, security, e2e]
sandbox:
  build: devcontainer
  target: web
  egress: [registry.npmjs.org, api.osv.dev]
  acceptance:
    build: devcontainer
    target: acceptance
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T233: midgard-react's documentation

The architecture page and the README say what the realm holds and how it is tested.

**Files (in `midgard-react`):**
- Modify: `README.md`, `docs/architecture.md`

**Acceptance criteria:**
- [ ] `docs/architecture.md` lists the pack, the graph, the prompts, the Containerfile and scripts and the template, and says how the tests run and what they need.

**Named test:** `git diff --stat -- docs/architecture.md README.md` in `midgard-react`. **Layer:** `midgard-react`. **Size:** S (39). **Depends on:** v0-T232.

- [ ] **Step 1:** write the code.

Apply to `README.md`:

````diff
diff --git a/README.md b/README.md
index baefa80..c8a8a68 100644
--- a/README.md
+++ b/README.md
@@ -14,6 +14,13 @@ go test ./...
 go vet ./...
 ```
 
+## What it holds
+
+The lead realm of a web product for the factory: the graph from a brief to a merged, accepted product, the
+prompts of each stage, a stack image with the check ladder's tools, the ladder's scripts and the web app
+template. A run loads it by name from the realm store (`--realm midgard-react`). See
+[the architecture](docs/architecture.md).
+
 ## Docs
 
 - Architecture: [docs/architecture.md](docs/architecture.md)
````

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index e0a344d..2b3fa22 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -23,9 +23,41 @@ change proposal `2026-10-17-realm-leaf-naming`).
   tied to one leaf (planner, initializer, reviewers). The api leaf's recipe is `helheim-go`'s.
 - Its templates are copied into products, so they are MIT-licensed (`templates/`).
 
+## What is here
+
+- `pack.yaml`: the leaf recipe (template, implementer prompt, the ladder by name), the check scripts, and
+  the sandbox: two images built from `devcontainer/`, the leaf's stack (`web`) and the one for acceptance
+  checks (`acceptance`, with Go).
+- `graph.yaml`: the stages of a web product (spec §4.2). The planning stages run in scratch workspaces and
+  Odin publishes their documents after the approval points; a design-conformance reviewer checks the spec
+  against the design and the spec gate stops on a deviation; a reuse review reads the plan; the plan is read
+  into tasks and the leaves are created from their realms' templates. Then, for every task: the implementer
+  in a loop with the check ladder and three reviewers (spec compliance, simplicity, quality), the merge
+  gate, and the pointer move with the acceptance run.
+- `prompts/`: planner, conformance, reuse-review, implementer and reviewer prompts. A planner prompt tells
+  where its documents go; a test checks the examples in them against the schemas Odin reads.
+- `devcontainer/Containerfile` and `devcontainer/checks/`: the stack and the ladder's scripts. `web-static`,
+  `web-unit`, `web-tdd` (new tests fail on the commit the task started from), `web-contract`, `web-security`
+  and `web-e2e` (Playwright against the built app and a Prism mock of the contract) make the leaf's ladder.
+  `accept-e2e` is the acceptance run: on a snapshot of the project it checks the API still keeps what the
+  web app's copy of the contract promises (the copy may lag; the API may not break it), builds and starts
+  the API against Postgres, and runs the Playwright specs.
+- `templates/web/`: the leaf a new web app starts from: Vite, React, TypeScript, Tailwind, TanStack Router
+  and Query, a typed client for the contract, a tested component and a Playwright spec.
+
+## Tests
+
+`go test ./...` checks the pack, the graph and the prompts against Gungnir's schemas; runs the scripts on
+small leaves with stand-ins for the image's tools (and python3 for the servers); and builds the template,
+which needs the npm registry the first time (set `YGG_REQUIRE_TEMPLATES` to fail instead of skipping when
+it cannot be reached). The image and the tools in it are checked on a real engine (Phase 5b, v0-H14).
+
 ## Depends on
 
 - Gungnir's schemas.
+- Havamal's `ponytail-review` skill, for the reuse review and the simplicity reviewer.
+- A lead realm's graph names the roles `planner`, `implementer` and `reviewer`: the operator's
+  `factory.yaml` defines them.
 
 ## Source
 
```

- [ ] **Step 2:** run the named test. Expect `ok`.

- [ ] **Step 3:** commit (see "How each task lands").

---

### Task v0-T234: a leaf starts on the stack of its realm: the pinned image, or the tag of the build

Odin's first task. Branch `realms/content` from `main` in `odin`, before step 1. Gungnir's v0-T205 to v0-T209 and gleipnir's v0-T210 to v0-T215 are merged and pinned, or `yggdrasil/go.work` builds the local copies. Phase 5a started each leaf on `Pack.Sandbox.Stack`, an image. A realm may now name a build context instead (change `realm-content`), and then the image is the local tag of what `ygg sandbox build` makes. Odin works the reference out once, when it loads the realm, and uses it everywhere a stack is named.

**Files (in `odin`):**
- Create: `internal/run/sandbox_build_test.go`
- Modify: `internal/realm/realm.go`, `internal/run/prepare.go`, `internal/run/sandbox.go`

**Interfaces:**
- Produces: `realm.Realm.Stack` and `Acceptance` (empty for a realm with no sandbox or no acceptance stack), filled by `Load` from `Pack.StackRef` and `AcceptanceRef`. `Setup.SandboxFor`, the default images of the sandbox configuration and a scratch agent's sandbox use them.

**Acceptance criteria:**
- [ ] A web leaf whose realm builds its stack from a context starts on the local tag, and the default images of the sandbox configuration are those of the lead realm's stack.
- [ ] A leaf whose realm names an image starts on the image, as in Phase 5a.
- [ ] The spec Odin builds is one the driver would accept.

**Named test:** `go test ./internal/run -run 'TestARealmWhoseStackIsBuiltFromItsContextGivesItsLeavesTheTagOfTheBuild'` in `odin`. **Layer:** `odin`. **Size:** M (109). **Depends on:** v0-T216.

- [ ] **Step 1:** write the tests.

Write `internal/run/sandbox_build_test.go`:

```go
package run

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gleipnir/sandbox"
	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/sandboxfake"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

const goBase = "docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514"

// buildContext turns the realm name in store into one whose stack is built from its own devcontainer folder.
func buildContext(t *testing.T, store, name string) string {
	t.Helper()
	dir := filepath.Join(store, name)
	pack, err := os.ReadFile(filepath.Join(dir, "pack.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(string(pack), "\n")
	for i, l := range lines {
		if strings.HasPrefix(l, "  stack: ") {
			lines[i] = "  build: devcontainer"
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "pack.yaml"), []byte(strings.Join(lines, "\n")), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(dir, "devcontainer", "checks"), 0o755); err != nil {
		t.Fatal(err)
	}
	for f, body := range map[string]string{"Containerfile": "FROM " + goBase + "\nCOPY checks/ /opt/ygg/checks/\n", "checks/unit.sh": "#!/bin/sh\ntrue\n"} {
		if err := os.WriteFile(filepath.Join(dir, "devcontainer", f), []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	p, err := schema.LoadPack(dir)
	if err != nil {
		t.Fatal(err)
	}
	ref, err := p.StackRef(dir)
	if err != nil {
		t.Fatal(err)
	}
	return ref
}

func TestARealmWhoseStackIsBuiltFromItsContextGivesItsLeavesTheTagOfTheBuild(t *testing.T) {
	store := t.TempDir()
	sandboxRealm(t, store, "midgard-react", "0.1.0", nodeStack, "registry.npmjs.org", "")
	sandboxRealm(t, store, "helheim-go", "0.2.0", nodeStack, "proxy.golang.org", "")
	webRef := buildContext(t, store, "midgard-react")
	root := treetest.Node{Owner: "ouroboric-dev", Visibility: "private", Pin: treetest.Pin{Realm: "midgard-react", Version: "0.1.0"}, Children: map[string]treetest.Node{
		"repos/app": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true},
		"repos/api": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Pin: treetest.Pin{Realm: "helheim-go", Version: "0.2.0"}},
	}}
	fake := &sandboxfake.Sandbox{}
	h := Hooks{NewSandbox: func(s *SandboxSetup, _ string) (gungnir.Sandbox, error) {
		if want := sandbox.ImagesFor(webRef); s.Config.Images != want {
			t.Errorf("the default images are %+v, want those of the lead realm's built stack %+v", s.Config.Images, want)
		}
		return fake, nil
	}}
	script := "{ agent: scripted, model: none, script: " + filepath.Join(toySandbox(t), "script.yaml") + " }"
	r, err := Start(ctx, Options{Project: treetest.Build(t, root), Config: sandboxConfig(t, script, "realms:\n  dir: "+store+"\n"), Realm: "midgard-react", Hooks: h})
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	for _, repo := range []string{"repos/app", "repos/api"} {
		if _, err := r.Runner(ctx, repo); err != nil {
			t.Fatalf("Runner(%s) = %v", repo, err)
		}
	}
	stacks := map[string]string{}
	for _, s := range fake.Ups {
		stacks[s.Name] = s.Stack
		if err := s.Validate(); err != nil {
			t.Errorf("the spec for %s is one the driver would refuse: %v", s.Name, err)
		}
	}
	if stacks["repos/app"] != webRef || !strings.HasPrefix(webRef, "localhost/ygg-stack-midgard-react:") {
		t.Errorf("the web leaf starts on %q, want the local tag %q", stacks["repos/app"], webRef)
	}
	if stacks["repos/api"] != nodeStack {
		t.Errorf("the api leaf, whose realm names an image, starts on %q, want %q", stacks["repos/api"], nodeStack)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestARealmWhoseStackIsBuiltFromItsContextGivesItsLeavesTheTagOfTheBuild (0.65s)
    sandbox_build_test.go:66: the default images are {Work:localhost/ygg-work:ef2e92d58e34 Firewall:localhost/ygg-fw:a6c8dbe873e0}, want those of the lead realm's built stack {Work:localhost/ygg-work:cef2e62ac5e0 Firewall:localhost/ygg-fw:a6c8dbe873e0}
    sandbox_build_test.go:89: the web leaf starts on "", want the local tag "localhost/ygg-stack-midgard-react:612dc8644441"
FAIL
```

- [ ] **Step 3:** write the code.

Apply to `internal/realm/realm.go`:

```diff
diff --git a/internal/realm/realm.go b/internal/realm/realm.go
index 4e3488c..55373bc 100644
--- a/internal/realm/realm.go
+++ b/internal/realm/realm.go
@@ -24,6 +24,10 @@ type Realm struct {
 	Dir     string // absolute
 	Hash    string // of every file a run could read; see Hash
 	Pack    *schema.Pack
+	// Stack is the image the realm's leaves start on: the pinned image its pack names, or the local tag of
+	// the image `ygg sandbox build` builds from the realm's build context. Acceptance is the same for the
+	// stack acceptance checks run on. Both are empty for a realm with no sandbox stack.
+	Stack, Acceptance string
 }
 
 // Load hashes the realm in dir and reads its pack. The hash comes first: it refuses a symlink anywhere in
@@ -41,7 +45,14 @@ func Load(dir string) (*Realm, error) {
 	if err != nil {
 		return nil, err
 	}
-	return &Realm{Name: p.Name, Version: p.Version, Dir: abs, Hash: h, Pack: p}, nil
+	r := &Realm{Name: p.Name, Version: p.Version, Dir: abs, Hash: h, Pack: p}
+	if r.Stack, err = p.StackRef(abs); err != nil {
+		return nil, err
+	}
+	if r.Acceptance, err = p.AcceptanceRef(abs); err != nil {
+		return nil, err
+	}
+	return r, nil
 }
 
 type limits struct{ files, bytes int64 }
```

Apply to `internal/run/prepare.go`:

```diff
diff --git a/internal/run/prepare.go b/internal/run/prepare.go
index 0f8b9d9..4ec0f73 100644
--- a/internal/run/prepare.go
+++ b/internal/run/prepare.go
@@ -46,7 +46,7 @@ func (s *Setup) prepareSandbox() error {
 	if uid == 0 {
 		return fmt.Errorf("ygg must not run as root: the sandbox's user is the operator's own")
 	}
-	cfg := sandbox.Config{Images: sandbox.ImagesFor(s.Pack.Sandbox.Stack), UID: uid, GID: gid}
+	cfg := sandbox.Config{Images: sandbox.ImagesFor(s.Lead.Stack), UID: uid, GID: gid}
 	for _, m := range s.Config.Sandbox.Mounts {
 		cfg.Mounts = append(cfg.Mounts, sandbox.PathMap{Host: m.Host, Engine: m.Engine})
 	}
@@ -107,7 +107,7 @@ func (s *Setup) SandboxFor(repo string) (stack string, egress []string, services
 		}
 	}
 	slices.SortFunc(services, func(a, b gungnir.Service) int { return strings.Compare(a.Name, b.Name) })
-	return r.Pack.Sandbox.Stack, sortedUnique(slices.Concat(r.Pack.Sandbox.Egress, s.Sandbox.Hosts)), services, nil
+	return r.Stack, sortedUnique(slices.Concat(r.Pack.Sandbox.Egress, s.Sandbox.Hosts)), services, nil
 }
 
 func sameService(a, b gungnir.Service) bool {
```

Apply to `internal/run/sandbox.go`:

```diff
diff --git a/internal/run/sandbox.go b/internal/run/sandbox.go
index b5d2417..5231ef1 100644
--- a/internal/run/sandbox.go
+++ b/internal/run/sandbox.go
@@ -91,7 +91,7 @@ func (r *Run) ScratchRunner(ctx context.Context, node string) (gungnir.Runner, e
 		return gungnir.Bind(r.Sandbox, env), nil
 	}
 	env, err := r.Sandbox.Up(ctx, gungnir.SandboxSpec{Run: r.State.ID, Name: key, Parent: r.Dir, Leaf: r.ScratchDir(node), Scratch: true,
-		Egress: r.Setup.Sandbox.Egress, Stack: r.Setup.Pack.Sandbox.Stack})
+		Egress: r.Setup.Sandbox.Egress, Stack: r.Setup.Lead.Stack})
 	if err != nil {
 		return nil, err
 	}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T235: ygg sandbox build builds a realm's stacks from their contexts, then the layers on them

`ygg sandbox build` is the one command that pulls and builds images (a run never does). For a realm whose stack is a context it now builds the context first (and the acceptance stack, a second stage of it, when the pack names one), then the factory's layers on it, once for each distinct stack.

**Files (in `odin`):**
- Create: `internal/cli/sandbox_build_test.go`
- Modify: `internal/cli/sandbox.go`, `internal/cli/sandbox_test.go`

**Interfaces:**
- `stacksToBuild` returns `stackBuild{ref, dir, target}` for each distinct stack of the realms named (or all of the store): `dir` is empty for an image pinned by digest. For a context, `BuildStack` runs first; its answer "the stack is there already" is printed, and then `Build` makes the layers on the stack.

**Acceptance criteria:**
- [ ] A realm with a build and an acceptance stage builds both stacks, in that order, and the layers on both; the stack is built before its layers.
- [ ] A second `ygg sandbox build` finds the stacks and builds nothing of them again.
- [ ] The older tests of the command (images, `--all`, the services' images pulled once) still pass.

**Named test:** `go test ./internal/cli -run 'TestSandboxBuildBuildsARealmsStackFromItsContextThenTheLayersOnIt|TestSandboxBuild'` in `odin`. **Layer:** `odin`. **Size:** M (116). **Depends on:** v0-T234.

- [ ] **Step 1:** write the tests.

Write `internal/cli/sandbox_build_test.go`:

```go
package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// contextRealm writes a realm whose stack is built from devcontainer/Containerfile, with stages web and
// acceptance, and an acceptance stack on the second one.
func contextRealm(t *testing.T, store, name string) {
	t.Helper()
	dir := filepath.Join(store, name)
	files := map[string]string{
		"pack.yaml":                   "name: " + name + "\nversion: 0.1.0\nsandbox:\n  build: devcontainer\n  target: web\n  acceptance:\n    build: devcontainer\n    target: acceptance\n",
		"devcontainer/Containerfile":  "FROM " + goStack + " AS web\nCOPY checks/ /opt/ygg/checks/\nFROM web AS acceptance\nRUN true\n",
		"devcontainer/checks/unit.sh": "#!/bin/sh\ntrue\n",
	}
	for f, body := range files {
		if err := os.MkdirAll(filepath.Dir(filepath.Join(dir, f)), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, f), []byte(body), 0o755); err != nil {
			t.Fatal(err)
		}
	}
}

func TestSandboxBuildBuildsARealmsStackFromItsContextThenTheLayersOnIt(t *testing.T) {
	log := stubEngine(t)
	store, config := realmsStore(t)
	contextRealm(t, store, "midgard-react")
	code, out, errOut := ygg(t, "sandbox", "build", "--config", config, "--realm", "midgard-react")
	if code != ExitDone {
		t.Fatalf("exit %d:\n%s%s", code, out, errOut)
	}
	b, _ := os.ReadFile(log)
	calls := string(b)
	var stacks []string
	for _, line := range strings.Split(calls, "\n") {
		if strings.HasPrefix(line, "podman build --pull=never -t localhost/ygg-stack-midgard-react") {
			stacks = append(stacks, line)
		}
	}
	if len(stacks) != 2 || !strings.Contains(stacks[0], "--target web") || !strings.Contains(stacks[1], "-acceptance:") || !strings.Contains(stacks[1], "--target acceptance") {
		t.Errorf("the realm's two stacks were built as:\n%s\nall calls:\n%s", strings.Join(stacks, "\n"), calls)
	}
	if got := builds(log); len(got) != 2 || !strings.Contains(strings.Join(got, "\n"), "STACK_IMAGE=localhost/ygg-stack-midgard-react:") {
		t.Errorf("the layers were built on:\n%s", strings.Join(got, "\n"))
	}
	if strings.Index(calls, "-t localhost/ygg-stack-") > strings.Index(calls, "--target work") {
		t.Errorf("the factory layers were built before the stack:\n%s", calls)
	}
	if strings.Contains(calls, "podman pull -q --authfile") && !strings.Contains(calls, goStack) {
		t.Errorf("the Containerfile's pinned base was not pulled:\n%s", calls)
	}
	// A second build finds the stacks there and builds the layers' images again only.
	code, _, _ = ygg(t, "sandbox", "build", "--config", config, "--realm", "midgard-react")
	b, _ = os.ReadFile(log)
	if code != ExitDone || strings.Count(string(b), "podman build --pull=never -t localhost/ygg-stack-midgard-react") != 2 {
		t.Errorf("a stack that was built was built again (exit %d):\n%s", code, b)
	}
}
```

Apply to `internal/cli/sandbox_test.go`:

```diff
diff --git a/internal/cli/sandbox_test.go b/internal/cli/sandbox_test.go
index f47f0b9..38d2a3f 100644
--- a/internal/cli/sandbox_test.go
+++ b/internal/cli/sandbox_test.go
@@ -35,6 +35,13 @@ case "$1" in
       *) echo c1 ;;
     esac ;;
   network) [ "$2" = exists ] && exit 1 ;;
+  image) case "$2 $3" in
+      "exists localhost/ygg-stack-"*) [ -f "$d/built-$(echo "$3" | tr '/:' '__')" ] || exit 1 ;;
+    esac ;;
+  build) prev=; for a in "$@"; do
+      [ "$prev" = -t ] && case "$a" in localhost/ygg-stack-*) touch "$d/built-$(echo "$a" | tr '/:' '__')" ;; esac
+      prev=$a
+    done ;;
 esac
 exit 0
 `)
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestSandboxBuildBuildsARealmsStackFromItsContextThenTheLayersOnIt (0.06s)
    sandbox_build_test.go:47: the realm's two stacks were built as:
        
        all calls:
```

- [ ] **Step 3:** write the code.

Apply to `internal/cli/sandbox.go`:

```diff
diff --git a/internal/cli/sandbox.go b/internal/cli/sandbox.go
index 99327e6..8ecf4f5 100644
--- a/internal/cli/sandbox.go
+++ b/internal/cli/sandbox.go
@@ -58,9 +58,20 @@ func (c *command) sandbox(args []string) int {
 	if err != nil {
 		return c.refuse(err)
 	}
-	for _, stack := range stacks {
-		fmt.Fprintf(c.out, "Pulling and building the images for %s; this takes a few minutes.\n", stack)
-		imgs, err := d.Build(c.ctx, stack)
+	for _, st := range stacks {
+		if st.dir != "" {
+			fmt.Fprintf(c.out, "Building the stack %s from the realm's context.\n", st.ref)
+			built, err := d.BuildStack(c.ctx, st.ref, st.dir, st.target)
+			if err != nil {
+				fmt.Fprintf(c.err, "ygg: building the stack failed: %v\n", err)
+				return ExitFailed
+			}
+			if !built {
+				fmt.Fprintf(c.out, "The stack %s is there already.\n", st.ref)
+			}
+		}
+		fmt.Fprintf(c.out, "Pulling and building the images for %s; this takes a few minutes.\n", st.ref)
+		imgs, err := d.Build(c.ctx, st.ref)
 		if err != nil {
 			fmt.Fprintf(c.err, "ygg: the build failed: %v\n", err)
 			return ExitFailed
@@ -77,11 +88,15 @@ func (c *command) sandbox(args []string) int {
 	return ExitDone
 }
 
+// stackBuild is one stack to build: the image the layers go on (ref) and, for a stack built from a realm's
+// context, the context's folder and the stage to build. dir is empty for an image pinned by digest.
+type stackBuild struct{ ref, dir, target string }
+
 // stacksToBuild returns the distinct sandbox stacks of the realms named, in the order named, or of every
 // realm in the store with --all, and the distinct images of their services, which a sandbox uses without
 // ever pulling them. A realm named on purpose that has no stack is an error; with --all it is skipped,
 // and the skip is returned for the output.
-func stacksToBuild(cfg *schema.Factory, refs []string, all bool) (stacks, services, skipped []string, err error) {
+func stacksToBuild(cfg *schema.Factory, refs []string, all bool) (stacks []stackBuild, services, skipped []string, err error) {
 	var store *realm.Store
 	if cfg.Realms != nil {
 		store = &realm.Store{Dir: cfg.Realms.Dir}
@@ -118,8 +133,32 @@ func stacksToBuild(cfg *schema.Factory, refs []string, all bool) (stacks, servic
 			skipped = append(skipped, fmt.Sprintf("The realm %s names no sandbox stack; skipped.", pack.Name))
 		case pack.Sandbox == nil:
 			return nil, nil, nil, fmt.Errorf("the realm %s names no sandbox stack in its pack.yaml", pack.Name)
-		case !slices.Contains(stacks, pack.Sandbox.Stack):
-			stacks = append(stacks, pack.Sandbox.Stack)
+		default:
+			sb := pack.Sandbox
+			ref, err := pack.StackRef(dir)
+			if err != nil {
+				return nil, nil, nil, err
+			}
+			want := []stackBuild{{ref: ref, target: sb.Target}}
+			if sb.Build != "" {
+				want[0].dir = filepath.Join(dir, sb.Build)
+			}
+			if sb.Acceptance != nil {
+				acc, err := pack.AcceptanceRef(dir)
+				if err != nil {
+					return nil, nil, nil, err
+				}
+				a := stackBuild{ref: acc, target: sb.Acceptance.Target}
+				if sb.Acceptance.Build != "" {
+					a.dir = filepath.Join(dir, sb.Acceptance.Build)
+				}
+				want = append(want, a)
+			}
+			for _, w := range want {
+				if !slices.ContainsFunc(stacks, func(x stackBuild) bool { return x.ref == w.ref }) {
+					stacks = append(stacks, w)
+				}
+			}
 		}
 		if pack.Sandbox != nil {
 			for _, v := range pack.ServiceList() {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T236: a scratch reviewer gets a copy of the output of the agent it reviews

The design-conformance reviewer checks a spec that is not published yet: it is in the `out/` of the spec agent's workspace until the gate approves it. A scratch agent with `reviews: <node>` gets that output as a copy in `reviewed/`, beside its own inputs, and is told so. The copy follows the same rule as an input: regular files only, nothing that could lead out of the project, bounded.

**Files (in `odin`):**
- Create: `internal/engine/reviewscratch_test.go`
- Modify: `internal/engine/scratch.go`

**Interfaces:**
- `seedScratch` copies `<scratch of the reviewed node>/out` to `<workspace>/reviewed`, through `copyTree` (a symlink or any other kind of file is refused, with the file's name; the file and byte limits of the workspace apply), after the inputs; the workspace note says `reviewed/ holds the output of the node X, which you review ... What you change in it is ignored.` A node that reviews nothing is told nothing of the kind.

**Acceptance criteria:**
- [ ] The reviewer reads the spec's output as a copy, and a change it makes to the copy does not reach the output it reviews.
- [ ] A symlink in the reviewed output fails the reviewer's node before it runs, and nothing is copied.

**Named test:** `go test ./internal/engine -run 'TestAScratchReviewerFindsTheOutputOfTheAgentItReviewsAsACopy|TestAReviewerIsRefusedAnOutputThatCouldLeadOutOfTheRun'` in `odin`. **Layer:** `odin`. **Size:** S (74). **Depends on:** v0-T234.

- [ ] **Step 1:** write the tests.

Write `internal/engine/reviewscratch_test.go`:

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

const specAndReview = "  - { id: spec, kind: agent, role: planner, prompt: p.md, scratch: true }\n" +
	"  - { id: conformance, kind: agent, role: planner, prompt: p.md, scratch: true, reviews: spec }\n"

const specAndReviewScript = "steps:\n  spec:\n    - actions: [ { write: { path: out/docs/spec.md, content: \"# The spec\\n\" } } ]\n      result: { status: ok, summary: wrote the spec }\n" +
	"  conformance:\n    - actions:\n        - run: { argv: [sh, -c, \"cat reviewed/docs/spec.md > out/seen.md; echo changed > reviewed/docs/spec.md\"] }\n" +
	"      result: { status: ok, summary: read the spec }\n"

func TestAScratchReviewerFindsTheOutputOfTheAgentItReviewsAsACopy(t *testing.T) {
	r, _ := startSandboxedWith(t, specAndReview, specAndReviewScript, run.Hooks{})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if b, err := os.ReadFile(filepath.Join(r.ScratchDir("conformance"), "out", "seen.md")); err != nil || string(b) != "# The spec\n" {
		t.Errorf("the reviewer saw %q, %v", b, err)
	}
	if b, _ := os.ReadFile(filepath.Join(r.ScratchDir("spec"), "out", "docs", "spec.md")); string(b) != "# The spec\n" {
		t.Errorf("the reviewer's change reached the output it reviewed: %q", b)
	}
	prompt := promptOf(t, r, "conformance-1")
	for _, want := range []string{"- reviewed/ holds the output of the node spec", "What you change in it is ignored"} {
		if !strings.Contains(prompt, want) {
			t.Errorf("the prompt lacks %q:\n%s", want, prompt)
		}
	}
	if strings.Contains(promptOf(t, r, "spec-1"), "reviewed/") {
		t.Error("a scratch agent that reviews nothing is told it has a reviewed/ folder")
	}
}

func TestAReviewerIsRefusedAnOutputThatCouldLeadOutOfTheRun(t *testing.T) {
	script := "steps:\n  spec:\n    - actions:\n        - write: { path: out/docs/spec.md, content: \"# The spec\\n\" }\n        - run: { argv: [ln, -s, /etc/passwd, out/docs/link.md] }\n" +
		"      result: { status: ok, summary: wrote the spec }\n  conformance:\n    - result: { status: ok, summary: read it }\n"
	r, _ := startSandboxedWith(t, specAndReview, script, run.Hooks{})
	out, err := Advance(context.Background(), r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "link.md") {
		t.Fatalf("Advance() = %+v, %v; want the run failed on link.md", out, err)
	}
	if r.State.Attempts["conformance"] != 0 {
		t.Error("the reviewer ran although its workspace could not be made")
	}
	if _, err := os.Stat(filepath.Join(r.ScratchDir("conformance"), "reviewed", "docs", "link.md")); err == nil {
		t.Error("the symlink was copied into the reviewer's workspace")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAScratchReviewerFindsTheOutputOfTheAgentItReviewsAsACopy (0.43s)
    reviewscratch_test.go:24: Advance() = {Status:failed Gate: Err:node conformance: the agent failed: scripted: [sh -c cat reviewed/docs/spec.md > out/seen.md; echo changed > reviewed/docs/spec.md] exited 2 Warn:[]}, <nil>
--- FAIL: TestAReviewerIsRefusedAnOutputThatCouldLeadOutOfTheRun (0.41s)
    reviewscratch_test.go:49: Advance() = {Status:done Gate: Err:<nil> Warn:[]}, <nil>; want the run failed on link.md
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/scratch.go`:

```diff
diff --git a/internal/engine/scratch.go b/internal/engine/scratch.go
index b86e05b..2f5a8a4 100644
--- a/internal/engine/scratch.go
+++ b/internal/engine/scratch.go
@@ -46,7 +46,7 @@ func runScratch(ctx context.Context, r *run.Run, n schema.Node) error {
 	if skillText != "" {
 		text += "\n\n" + skillText
 	}
-	text += "\n\n" + workspaceNote(r, present)
+	text += "\n\n" + workspaceNote(r, present, n.Reviews)
 	if r.Setup.BriefText != "" {
 		text += "\n\n## Brief\n\n" + r.Setup.BriefText
 	}
@@ -73,7 +73,7 @@ func runScratch(ctx context.Context, r *run.Run, n schema.Node) error {
 }
 
 // workspaceNote tells the agent what its workspace holds and where its output goes.
-func workspaceNote(r *run.Run, present []string) string {
+func workspaceNote(r *run.Run, present []string, reviews string) string {
 	var b strings.Builder
 	b.WriteString("## Your workspace\n\nYou work in the folder you start in. It is not a repository, and nothing in it is committed by you.\n")
 	if r.Setup.BriefText != "" {
@@ -82,13 +82,17 @@ func workspaceNote(r *run.Run, present []string) string {
 	for _, p := range present {
 		fmt.Fprintf(&b, "- %s is a copy of the project's file or folder of that name. Read it. What you change in it is ignored.\n", p)
 	}
+	if reviews != "" {
+		fmt.Fprintf(&b, "- reviewed/ holds the output of the node %s, which you review: what it wrote under its out/. Read it. What you change in it is ignored.\n", reviews)
+	}
 	b.WriteString("- Write every document you produce under out/, in the folders it should have in the project (for example out/docs/2-engineering/specs/...). " +
 		"Only out/ leaves this workspace, and only after a person or a check has approved it.\n")
 	return b.String()
 }
 
 // seedScratch makes the workspace of node n anew: the brief, a copy of each input that exists in the
-// project, and an empty out/. It returns the inputs it copied. Everything in Odin's own folder is
+// project, and an empty out/. A node that reviews another scratch agent also gets a copy of that agent's
+// out/ as reviewed/. It returns the inputs it copied. Everything in Odin's own folder is
 // replaced; nothing outside it is touched. The folder itself stays, emptied in place: the scratch sandbox
 // mounts it and stays up across a retry and a refusal sent back, and a folder made again would not be
 // the one its container sees (review I-3). An input that is, or holds, a symlink or anything but a
@@ -120,6 +124,16 @@ func seedScratch(r *run.Run, n schema.Node) (present []string, err error) {
 		}
 		present = append(present, in)
 	}
+	if n.Reviews != "" {
+		// The output of the agent under review, as a copy: the reviewer reads it and cannot change it.
+		src := filepath.Join(r.ScratchDir(n.Reviews), "out")
+		if st, err := os.Lstat(src); err != nil || !st.IsDir() {
+			return nil, fmt.Errorf("node %s reviews %s, which has no output to review", n.ID, n.Reviews)
+		}
+		if err := copyTree(src, src, filepath.Join(dir, "reviewed"), b); err != nil {
+			return nil, fmt.Errorf("the output of %s, which %s reviews: %w", n.Reviews, n.ID, err)
+		}
+	}
 	return present, nil
 }
 
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T237: the spec gate reads the design-conformance verdict, and a deviation stops it in every mode

Spec §7.1: the `spec` gate is automatic unless the design-conformance review found a deviation, and then it stops with the proposed amendment. The mode table already had the fact (`Facts.Deviation`); nothing set it. A verdict that is missing or cannot be read must never be taken for "no deviation" (§4.6), so the reviewer is asked once more with the reason, and a second failure stops the run.

**Files (in `odin`):**
- Create: `internal/engine/conformance.go`, `internal/engine/conformance_test.go`
- Modify: `internal/engine/gates.go`, `internal/engine/scratch.go`

**Interfaces:**
- Produces: `readConformance(r, node)` (the reviewer's `out/conformance.json`, a regular file of at most 64 KiB inside its workspace, through `schema.ParseConformance`) and `conformanceSection`. After a scratch node that a gate reads the verdict of, `runScratch` reads it; if it cannot, it makes the workspace again and runs the node once more with the reason in the prompt (`Your answer could not be read`), then fails the node. `reachGate` reads the verdict for a gate with `deviation_from`, logs `conformance_checked` (`no deviation`, or `deviation:` and the amendment's first line), passes the fact to `gate.Decide` and adds a section "Design conformance" to the gate file.

**Acceptance criteria:**
- [ ] No deviation: the spec gate opens by itself in key-points mode, the gate file says so, and the spec is published after the gate. Step-by-step still stops.
- [ ] A deviation stops the gate in key-points and unattended modes, the gate file quotes the amendment, nothing is published before the approval, and an approval continues.
- [ ] A rejection re-runs the spec writer with the reason and the reviewer again, and the second verdict decides.
- [ ] Prose, a missing file, a deviation with no amendment and an unknown field are asked for once more; twice fails the run and publishes nothing.

**Named test:** `go test ./internal/engine -run 'TestTheSpecGateOpensByItselfWhenTheSpecDoesNotDeviateFromTheDesign|TestADeviationStopsTheSpecGateInEveryModeWithTheAmendment|TestARejectedSpecRunsTheConformanceReviewAgain|TestAVerdictNobodyCanReadIsAskedForOnceMoreAndThenStopsTheRun|TestStepByStepModeStopsAtTheSpecGateEvenWithoutADeviation'` in `odin`. **Layer:** `odin`. **Size:** M (243). **Depends on:** v0-T236.

- [ ] **Step 1:** write the tests.

Write `internal/engine/conformance_test.go`:

```go
package engine

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/run"
)

// The spec stage of the web realm (spec §4.2): the spec is written in a scratch workspace, a second
// scratch agent checks it against the design, and the spec gate reads its verdict.
const conformanceNodes = "  - { id: spec, kind: agent, role: planner, prompt: p.md, scratch: true }\n" +
	"  - { id: conformance, kind: agent, role: planner, prompt: p.md, scratch: true, reviews: spec }\n" +
	"  - { id: spec-gate, kind: gate, gate: spec, reruns: spec, deviation_from: conformance }\n" +
	"  - { id: spec-docs, kind: publish, from: spec, to: docs }\n"

// verdictScript is a spec stage whose conformance reviewer answers with each of verdicts in turn (a verdict
// is the whole text of out/conformance.json, or "" for no file at all).
func verdictScript(verdicts ...string) string {
	s := "steps:\n  spec:\n    - actions: [ { write: { path: out/specs/spec.md, content: \"# Spec\\n\" } } ]\n      result: { status: ok, summary: wrote the spec }\n" +
		"    - actions: [ { write: { path: out/specs/spec.md, content: \"# Spec, revised\\n\" } } ]\n      result: { status: ok, summary: revised the spec }\n  conformance:\n"
	for _, v := range verdicts {
		s += "    - "
		if v != "" {
			s += "actions: [ { write: { path: out/conformance.json, content: '" + v + "' } } ]\n      "
		}
		s += "result: { status: ok, summary: checked the spec }\n"
	}
	return s
}

const (
	noDeviation = `{"deviation": false}`
	deviation   = `{"deviation": true, "amendment": "The design says nothing about offline mode; add it or drop it from the spec."}`
)

func TestTheSpecGateOpensByItselfWhenTheSpecDoesNotDeviateFromTheDesign(t *testing.T) {
	r := start(t, "key-points", "", conformanceNodes, verdictScript(noDeviation))
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	text := ledgerText(t, r)
	for _, want := range []string{`"event":"conformance_checked"`, "no deviation", `"event":"gate_auto_passed"`, `"event":"docs_published"`} {
		if !strings.Contains(text, want) {
			t.Errorf("the ledger lacks %s:\n%s", want, text)
		}
	}
	gate, _ := os.ReadFile(filepath.Join(r.Dir, "gates", "spec-gate-1.md"))
	if !strings.Contains(string(gate), "## Design conformance") || !strings.Contains(string(gate), "The spec does not deviate from the design.") {
		t.Errorf("the gate file lacks the verdict:\n%s", gate)
	}
	if _, err := os.Stat(filepath.Join(r.Project, "docs", "specs", "spec.md")); err != nil {
		t.Errorf("the spec was not published after the gate: %v", err)
	}
}

func TestADeviationStopsTheSpecGateInEveryModeWithTheAmendment(t *testing.T) {
	for _, mode := range []string{"key-points", "unattended"} {
		r := start(t, mode, "", conformanceNodes, verdictScript(deviation))
		out, err := Advance(bg, r)
		if err != nil || out.Status != run.StatusStopped || out.Gate != "spec-gate" {
			t.Fatalf("%s: Advance() = %+v, %v; want a stop at the spec gate", mode, out, err)
		}
		gate, _ := os.ReadFile(filepath.Join(r.Dir, "gates", "spec-gate-1.md"))
		for _, want := range []string{"The spec deviates from the design.", "add it or drop it from the spec.", "stopped for a decision"} {
			if !strings.Contains(string(gate), want) {
				t.Errorf("%s: the gate file lacks %q:\n%s", mode, want, gate)
			}
		}
		if _, err := os.Stat(filepath.Join(r.Project, "docs", "specs", "spec.md")); err == nil {
			t.Errorf("%s: the spec was published before it was approved", mode)
		}
		if err := Approve(bg, r, "spec-gate", "offline mode is in"); err != nil {
			t.Fatal(err)
		}
		if out, err := Advance(bg, r); err != nil || out.Status != run.StatusDone {
			t.Errorf("%s: after the approval Advance() = %+v, %v", mode, out, err)
		}
	}
}

func TestARejectedSpecRunsTheConformanceReviewAgain(t *testing.T) {
	r := start(t, "key-points", "", conformanceNodes, verdictScript(deviation, noDeviation))
	if out, err := Advance(bg, r); err != nil || out.Status != run.StatusStopped {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if err := Reject(bg, r, "spec-gate", "drop offline mode from the spec"); err != nil {
		t.Fatal(err)
	}
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() after the rejection = %+v, %v; the second verdict says no deviation", out, err)
	}
	if !strings.Contains(promptOf(t, r, "spec-2"), "drop offline mode from the spec") {
		t.Error("the spec writer was not told why the spec was rejected")
	}
	if got := r.State.Attempts["conformance"]; got != 2 {
		t.Errorf("conformance ran %d times, want 2: the revised spec is reviewed again", got)
	}
	if b, _ := os.ReadFile(filepath.Join(r.Project, "docs", "specs", "spec.md")); string(b) != "# Spec, revised\n" {
		t.Errorf("the published spec = %q", b)
	}
}

func TestAVerdictNobodyCanReadIsAskedForOnceMoreAndThenStopsTheRun(t *testing.T) {
	for name, bad := range map[string]string{
		"prose":                         "It conforms.",
		"no file":                       "",
		"a deviation with no amendment": `{"deviation": true}`,
		"an unknown field":              `{"deviation": false, "ok": true}`,
	} {
		r := start(t, "key-points", "", conformanceNodes, verdictScript(bad, noDeviation))
		out, err := Advance(bg, r)
		if err != nil || out.Status != run.StatusDone {
			t.Fatalf("%s then a good verdict: Advance() = %+v, %v", name, out, err)
		}
		if !strings.Contains(promptOf(t, r, "conformance-2"), "Your answer could not be read") {
			t.Errorf("%s: the second try was not told what was wrong", name)
		}
		r = start(t, "key-points", "", conformanceNodes, verdictScript(bad, bad))
		out, err = Advance(bg, r)
		if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "conformance") {
			t.Errorf("%s twice: Advance() = %+v, %v; want a failed run, never a pass", name, out, err)
		}
		if _, err := os.Stat(filepath.Join(r.Project, "docs", "specs", "spec.md")); err == nil {
			t.Errorf("%s twice: a spec nobody could check was published", name)
		}
	}
}

func TestStepByStepModeStopsAtTheSpecGateEvenWithoutADeviation(t *testing.T) {
	r := start(t, "step-by-step", "", conformanceNodes, verdictScript(noDeviation))
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusStopped || out.Gate != "spec-gate" {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	gate, _ := os.ReadFile(filepath.Join(r.Dir, "gates", "spec-gate-1.md"))
	if !strings.Contains(string(gate), "The spec does not deviate from the design.") {
		t.Errorf("the gate file lacks the verdict:\n%s", gate)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTheSpecGateOpensByItselfWhenTheSpecDoesNotDeviateFromTheDesign (0.33s)
    conformance_test.go:48: the ledger lacks "event":"conformance_checked":
        {"schema":"ygg.ledger/v1","seq":1,"time":"2026-10-17T17:12:59.554233114Z","ygg.run.id":"20261017-171259-23c5ce","event":"run_started","ygg.note":"realms: test 0.1.0 sha256:890b3dedc19ef2da4c06ac530c00732dbbbdc91b76322e23741301b068288dd3","ygg.mode":"key-points","ygg.config.sha256":"d2a187316804d928531144e6213a9ee15b49d01b67d394a7cdafe2a89efab64e","ygg.realm.name":"test","ygg.realm.version":"0.1.0","prev":"0000000000000000000000000000000000000000000000000000000000000000"}
        {"schema":"ygg.ledger/v1","seq":2,"time":"2026-10-17T17:12:59.603004299Z","ygg.run.id":"20261017-171259-23c5ce","ygg.node.id":"spec","event":"node_started","ygg.attempt":1,"gen_ai.agent.name":"planner","gen_ai.request.model":"none","ygg.agent.adapter":"scripted","prev":"bf499f7957436eca789d73a15c60c762759252e47b92d76abdb1a7ee676a477d"}
```

- [ ] **Step 3:** write the code.

Write `internal/engine/conformance.go`:

```go
package engine

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/run"
)

// maxVerdictBytes is the most a design-conformance verdict may hold: a deviation and its amendment.
const maxVerdictBytes = 64 << 10

// readConformance reads the verdict that the scratch reviewer node wrote to out/conformance.json (spec
// §4.2): through the checks every file of an agent gets (a regular file inside the workspace, bounded),
// and then exactly (schema.ParseConformance). A verdict that is missing or can't be read is an error,
// never a pass: it would let a deviation through the spec gate (spec §4.6).
func readConformance(r *run.Run, node string) (gungnir.Conformance, error) {
	dir := filepath.Join(r.ScratchDir(node), "out")
	st, err := os.Lstat(filepath.Join(dir, "conformance.json"))
	if err != nil {
		return gungnir.Conformance{}, fmt.Errorf("%s wrote no out/conformance.json", node)
	}
	data, err := readRegular(dir, "conformance.json", st, maxVerdictBytes)
	if err != nil {
		return gungnir.Conformance{}, fmt.Errorf("out/conformance.json of %s can't be read: %w", node, err)
	}
	c, err := schema.ParseConformance(data)
	if err != nil {
		return gungnir.Conformance{}, fmt.Errorf("out/conformance.json of %s: %w", node, err)
	}
	return c, nil
}

// isVerdictSource reports whether a gate of the graph reads the verdict of the scratch node id.
func isVerdictSource(r *run.Run, id string) bool {
	return slices.ContainsFunc(r.Nodes(), func(m schema.Node) bool { return m.Kind == schema.KindGate && m.DeviationFrom == id })
}

// conformanceSection is what the gate file of a spec gate says about the verdict.
func conformanceSection(c gungnir.Conformance) string {
	var b strings.Builder
	b.WriteString("## Design conformance\n\n")
	if !c.Deviation {
		b.WriteString("The spec does not deviate from the design.\n\n")
		return b.String()
	}
	b.WriteString("The spec deviates from the design. The reviewer proposes this amendment (a suggestion, written by an agent):\n\n")
	for _, line := range strings.Split(strings.TrimSpace(c.Amendment), "\n") {
		b.WriteString("> " + line + "\n")
	}
	b.WriteString("\n")
	return b.String()
}
```

Apply to `internal/engine/gates.go`:

```diff
diff --git a/internal/engine/gates.go b/internal/engine/gates.go
index d7fce2c..0f014ca 100644
--- a/internal/engine/gates.go
+++ b/internal/engine/gates.go
@@ -24,10 +24,26 @@ func reachGate(r *run.Run, n schema.Node) (bool, error) {
 	if err != nil {
 		return false, err
 	}
-	// Phase 1 has no conformance review and no contracts, so both facts are false. Block only
-	// arises for pointer-contract, which Phase 2 brings; until then it stops like Stop.
-	action := gate.Decide(s.Mode, n.Gate, r.Setup.Config.Gates, gate.Facts{})
-	file, err := writeGateFile(r, n, attempt, action)
+	// The spec gate reads the verdict of the design-conformance review (spec §7.1); no gate knows a
+	// contract yet, so ContractInSpec is false. Block only arises for pointer-contract.
+	var facts gate.Facts
+	var verdict *gungnir.Conformance
+	if n.DeviationFrom != "" {
+		v, err := readConformance(r, n.DeviationFrom)
+		if err != nil {
+			return false, &nodeFailure{err}
+		}
+		verdict, facts.Deviation = &v, v.Deviation
+		result := "no deviation"
+		if v.Deviation {
+			result = "deviation: " + firstLine(v.Amendment)
+		}
+		if err := r.Log(gungnir.Event{Name: gungnir.EventConformanceChecked, Node: n.DeviationFrom, Attempt: attempt, Result: result}); err != nil {
+			return false, err
+		}
+	}
+	action := gate.Decide(s.Mode, n.Gate, r.Setup.Config.Gates, facts)
+	file, err := writeGateFile(r, n, attempt, action, verdict)
 	if err != nil {
 		return false, err
 	}
@@ -45,7 +61,7 @@ func reachGate(r *run.Run, n schema.Node) (bool, error) {
 }
 
 // writeGateFile writes gates/<node>-<attempt>.md and returns its path relative to the run.
-func writeGateFile(r *run.Run, n schema.Node, attempt int, action gate.Action) (string, error) {
+func writeGateFile(r *run.Run, n schema.Node, attempt int, action gate.Action, verdict *gungnir.Conformance) (string, error) {
 	s := r.State
 	rel := filepath.Join("gates", fmt.Sprintf("%s-%d.md", n.ID, attempt))
 	var b strings.Builder
@@ -68,6 +84,9 @@ func writeGateFile(r *run.Run, n schema.Node, attempt int, action gate.Action) (
 	for _, m := range nodes[start:s.Position] {
 		fmt.Fprintf(&b, "- %s (%s, attempt %d): %s\n", m.ID, m.Kind, s.Attempts[m.ID], s.Summaries[m.ID])
 	}
+	if verdict != nil {
+		b.WriteString("\n" + conformanceSection(*verdict))
+	}
 	u := s.Usage
 	fmt.Fprintf(&b, "\n## Cost so far\n\n- Tokens: %d in, %d out, %d from cache\n- Turns: %d\n- Cost: $%.4f",
 		u.InTok, u.OutTok, u.CacheTok, u.Turns, u.CostUSD)
```

Apply to `internal/engine/scratch.go`:

```diff
diff --git a/internal/engine/scratch.go b/internal/engine/scratch.go
index 2f5a8a4..b021459 100644
--- a/internal/engine/scratch.go
+++ b/internal/engine/scratch.go
@@ -62,6 +62,23 @@ func runScratch(ctx context.Context, r *run.Run, n schema.Node) error {
 	if err != nil {
 		return nodeError(err)
 	}
+	if isVerdictSource(r, n.ID) {
+		// The verdict gates the spec, so it has to be readable. An answer that is not is asked for once
+		// more, from a fresh workspace and with the reason; a second one stops the run (spec §4.6).
+		if _, rerr := readConformance(r, n.ID); rerr != nil {
+			if _, err := seedScratch(r, n); err != nil {
+				return &nodeFailure{err}
+			}
+			sp.text = text + "\n\n## Your answer could not be read\n\n" + rerr.Error() +
+				"\n\nWrite out/conformance.json again, as the instructions above say, and nothing else is read.\n"
+			if res, ev, err = session(ctx, r, sp); err != nil {
+				return nodeError(err)
+			}
+			if _, rerr = readConformance(r, n.ID); rerr != nil {
+				return &nodeFailure{fmt.Errorf("the design-conformance verdict of %s can't be read, after being asked twice: %w", n.ID, rerr)}
+			}
+		}
+	}
 	ev.Name, ev.Result = gungnir.EventNodeFinished, res.Summary
 	if err := r.Log(ev); err != nil {
 		return err
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T238: a snapshot of the project's committed files, with no git dir, for the checks that run over several leaves

Acceptance checks run over several leaves, so no leaf's sandbox holds them. With a sandbox on they run in one that holds a snapshot of the project (decision 5): what each repo has committed, at the commit it is on, in a plain folder. A working copy's ignored build output (`node_modules`), a file not added yet and an edit not committed never reach it, and nothing in it can lead out of it.

**Files (in `odin`):**
- Create: `internal/snapshot/snapshot.go`, `internal/snapshot/snapshot_test.go`
- Modify: `internal/git/git.go`

**Interfaces:**
- Produces: package `snapshot`: `Export(ctx, dst, []Source{Rel, Repo git.Repo, Rev string}) error` makes `dst` hold, in the order given, the files of `git archive <rev>` of each repo at `Rel` (`.` for the project umbrella; `HEAD` when `Rev` is empty, otherwise a full commit hash), with the executable bit kept. `dst` is emptied in place, so a sandbox that mounted it keeps the same folder.
- It refuses a tracked symlink or any entry that is not a regular file or a folder, a path that leaves its source's folder, a source at `Rel` that is empty or climbs, a file two repos both hold (nothing is overwritten), a `Rev` that is not `HEAD` or a full hash (so it can never be read as an option), more than 20,000 files, 256 MiB, or a file over 32 MiB. Produces `git.Repo.Pipe(ctx, read, args...)`, which hands git's standard output to `read` as it is made and stops git if `read` returns early.

**Acceptance criteria:**
- [ ] The snapshot of a project with two leaves holds exactly the committed files of the three repos, with the right modes, and none of an ignored file, an unadded file or an uncommitted edit; a leftover of an earlier export is gone; `dst` is the same folder.
- [ ] A tracked symlink is refused and not written; the other refusals above are test cases; a repo is exported at the commit it is told to.

**Named test:** `go test ./internal/snapshot -run 'TestExport'` in `odin`. **Layer:** `odin`. **Size:** M (342). **Depends on:** v0-T234.

- [ ] **Step 1:** write the tests.

Write `internal/snapshot/snapshot_test.go`:

```go
package snapshot

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/odin/internal/git"
)

var bg = context.Background()

// repo makes a git repo in a temp dir with the given files committed, and returns it.
func repo(t *testing.T, files map[string]string) git.Repo {
	t.Helper()
	dir := t.TempDir()
	write(t, dir, files)
	for _, args := range [][]string{{"init", "-q", "-b", "main"}, {"add", "-A"}, {"commit", "-q", "-m", "files"}} {
		if _, err := git.Run(bg, dir, args...); err != nil {
			t.Fatal(err)
		}
	}
	return git.Repo{GitDir: filepath.Join(dir, ".git"), WorkTree: dir}
}

func write(t *testing.T, dir string, files map[string]string) {
	t.Helper()
	for name, body := range files {
		p := filepath.Join(dir, name)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		mode := os.FileMode(0o644)
		if strings.HasSuffix(name, ".sh") {
			mode = 0o755
		}
		if err := os.WriteFile(p, []byte(body), mode); err != nil {
			t.Fatal(err)
		}
	}
}

func TestExportHoldsTheCommittedFilesOfTheProjectAndOfEachLeafAndNothingElse(t *testing.T) {
	project := repo(t, map[string]string{"docs/readme.md": "docs\n", "run.sh": "#!/bin/sh\n"})
	web := repo(t, map[string]string{"src/app.ts": "app\n", ".gitignore": "node_modules\n", "e2e/run.sh": "#!/bin/sh\n"})
	api := repo(t, map[string]string{"main.go": "package main\n"})
	// What a leaf holds beyond its commit must not reach the snapshot: ignored build output, a file not
	// added yet, and a tracked file edited since.
	write(t, web.WorkTree, map[string]string{"node_modules/pkg/index.js": "big\n", "scratch.txt": "not added\n", "src/app.ts": "edited, not committed\n"})
	dst := filepath.Join(t.TempDir(), "snap")
	if err := os.MkdirAll(dst, 0o755); err != nil {
		t.Fatal(err)
	}
	write(t, dst, map[string]string{"left-over.txt": "from the last export\n"})
	if err := Export(bg, dst, []Source{{Rel: ".", Repo: project}, {Rel: "repos/web", Repo: web}, {Rel: "repos/api", Repo: api}}); err != nil {
		t.Fatalf("Export() = %v", err)
	}
	want := map[string]string{"docs/readme.md": "docs\n", "run.sh": "#!/bin/sh\n", "repos/web/src/app.ts": "app\n", "repos/web/.gitignore": "node_modules\n",
		"repos/web/e2e/run.sh": "#!/bin/sh\n", "repos/api/main.go": "package main\n"}
	var got []string
	filepath.WalkDir(dst, func(p string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() {
			rel, _ := filepath.Rel(dst, p)
			got = append(got, rel)
			if body, ok := want[rel]; !ok {
				t.Errorf("the snapshot holds %s, which no repo committed", rel)
			} else if b, _ := os.ReadFile(p); string(b) != body {
				t.Errorf("%s = %q, want %q", rel, b, body)
			}
		}
		return nil
	})
	if len(got) != len(want) {
		t.Errorf("the snapshot holds %v, want exactly %d files", got, len(want))
	}
	for rel, exec := range map[string]bool{"run.sh": true, "repos/web/e2e/run.sh": true, "docs/readme.md": false} {
		st, err := os.Stat(filepath.Join(dst, rel))
		if err != nil || (st.Mode()&0o111 != 0) != exec {
			t.Errorf("%s: mode %v, %v; want executable %v", rel, st.Mode(), err, exec)
		}
	}
	st, _ := os.Stat(dst)
	if !st.IsDir() {
		t.Error("the folder itself was replaced")
	}
}

func TestExportRefusesWhatCouldLeadOutOfTheSnapshot(t *testing.T) {
	linked := repo(t, map[string]string{"a.txt": "a\n"})
	if err := os.Symlink("/etc/passwd", filepath.Join(linked.WorkTree, "passwd")); err != nil {
		t.Fatal(err)
	}
	for _, args := range [][]string{{"add", "-A"}, {"commit", "-q", "-m", "a link"}} {
		if _, err := git.Run(bg, linked.WorkTree, args...); err != nil {
			t.Fatal(err)
		}
	}
	dst := t.TempDir()
	err := Export(bg, dst, []Source{{Rel: ".", Repo: linked}})
	if err == nil || !strings.Contains(err.Error(), "passwd") || !strings.Contains(err.Error(), "not a regular file") {
		t.Errorf("a tracked symlink: Export() = %v", err)
	}
	if _, err := os.Lstat(filepath.Join(dst, "passwd")); err == nil {
		t.Error("the symlink was written")
	}
	plain := repo(t, map[string]string{"a.txt": "a\n"})
	for _, rel := range []string{"../out", "/abs", "a/../../b", ""} {
		if err := Export(bg, t.TempDir(), []Source{{Rel: rel, Repo: plain}}); err == nil {
			t.Errorf("Export() into %q = nil, want an error", rel)
		}
	}
	// Two repos that both hold a file at one path: the second never overwrites the first.
	other := repo(t, map[string]string{"a.txt": "other\n"})
	if err := Export(bg, t.TempDir(), []Source{{Rel: ".", Repo: plain}, {Rel: ".", Repo: other}}); err == nil {
		t.Error("two repos wrote one file and Export() = nil")
	}
}

func TestExportStopsAtMoreFilesOrBytesThanASnapshotMayHold(t *testing.T) {
	r := repo(t, map[string]string{"a.txt": "1\n", "b.txt": "2\n", "c.txt": "3\n"})
	defer func(f int, b int64) { maxFiles, maxBytes = f, b }(maxFiles, maxBytes)
	maxFiles = 2
	if err := Export(bg, t.TempDir(), []Source{{Rel: ".", Repo: r}}); err == nil || !strings.Contains(err.Error(), "more than 2 files") {
		t.Errorf("too many files: Export() = %v", err)
	}
	maxFiles, maxBytes = 100, 4
	if err := Export(bg, t.TempDir(), []Source{{Rel: ".", Repo: r}}); err == nil || !strings.Contains(err.Error(), "bytes") {
		t.Errorf("too many bytes: Export() = %v", err)
	}
}

func TestExportTakesAReposFilesAtTheCommitItWasToldTo(t *testing.T) {
	r := repo(t, map[string]string{"a.txt": "first\n"})
	first, err := git.Run(bg, r.WorkTree, "rev-parse", "HEAD")
	if err != nil {
		t.Fatal(err)
	}
	write(t, r.WorkTree, map[string]string{"a.txt": "second\n"})
	for _, args := range [][]string{{"add", "-A"}, {"commit", "-q", "-m", "second"}} {
		if _, err := git.Run(bg, r.WorkTree, args...); err != nil {
			t.Fatal(err)
		}
	}
	dst := t.TempDir()
	if err := Export(bg, dst, []Source{{Rel: ".", Repo: r, Rev: first}}); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(dst, "a.txt")); string(b) != "first\n" {
		t.Errorf("a.txt = %q, want the file at the first commit", b)
	}
	for _, rev := range []string{"--output=/tmp/x", "main", "HEAD~1", first[:12], "HEAD; touch x"} {
		if err := Export(bg, t.TempDir(), []Source{{Rel: ".", Repo: r, Rev: rev}}); err == nil {
			t.Errorf("Export() at %q = nil, want an error: only HEAD or a full hash is taken", rev)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/snapshot [github.com/ouroboric-dev/odin/internal/snapshot.test]
internal/snapshot/snapshot_test.go:57:12: undefined: Export
internal/snapshot/snapshot_test.go:57:30: undefined: Source
internal/snapshot/snapshot_test.go:101:9: undefined: Export
```

- [ ] **Step 3:** write the code.

Apply to `internal/git/git.go`:

```diff
diff --git a/internal/git/git.go b/internal/git/git.go
index e001d21..da0d512 100644
--- a/internal/git/git.go
+++ b/internal/git/git.go
@@ -9,6 +9,7 @@ import (
 	"context"
 	"errors"
 	"fmt"
+	"io"
 	"os"
 	"os/exec"
 	"strings"
@@ -94,6 +95,39 @@ func (r Repo) Output(ctx context.Context, args ...string) ([]byte, error) {
 	return Output(ctx, r.WorkTree, append([]string{"--git-dir=" + r.GitDir, "--work-tree=" + r.WorkTree}, args...)...)
 }
 
+// Pipe runs git with args against r and hands its standard output to read as it is produced, for output
+// too big to hold, such as an archive of the repo. read decides how much it takes: if it returns early,
+// git is stopped. An error of git's wins over one of read's only when read saw the end of the output.
+func (r Repo) Pipe(ctx context.Context, read func(io.Reader) error, args ...string) error {
+	ctx, cancel := context.WithCancel(ctx)
+	defer cancel()
+	full := append(append([]string{}, safe...), "--git-dir="+r.GitDir, "--work-tree="+r.WorkTree)
+	cmd := exec.CommandContext(ctx, "git", append(full, args...)...)
+	cmd.Dir = r.WorkTree
+	cmd.Env = env()
+	var errOut bytes.Buffer
+	cmd.Stderr = &errOut
+	out, err := cmd.StdoutPipe()
+	if err != nil {
+		return err
+	}
+	if err := cmd.Start(); err != nil {
+		return err
+	}
+	readErr := read(out)
+	if readErr != nil {
+		cancel()
+	}
+	waitErr := cmd.Wait()
+	switch {
+	case readErr != nil:
+		return readErr
+	case waitErr != nil:
+		return fmt.Errorf("git %s (in %s): %w: %s", strings.Join(args, " "), r.WorkTree, waitErr, strings.TrimSpace(errOut.String()))
+	}
+	return nil
+}
+
 // CheckURL refuses a repo URL that host git shouldn't fetch: anything but https, ssh (also in the
 // git@host:path form) and local paths, and anything git could read as an option.
 func CheckURL(url string) error {
```

Write `internal/snapshot/snapshot.go`:

```go
// Package snapshot exports a project as it would be built: the committed files of the project umbrella
// and of each leaf, at the commits they are on, into a plain folder with no git directory (spec §6.1,
// change realm-content). Acceptance checks run on it in a sandbox of their own, where no leaf's
// working copy, git dir or ignored build output can reach them or be changed by them.
package snapshot

import (
	"archive/tar"
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path"
	"path/filepath"
	"regexp"

	"github.com/ouroboric-dev/odin/internal/git"
)

// What a snapshot may hold. A project's committed files are source code, so these are generous; a repo
// with more is holding something that is not source, and the export says so rather than fill the disk.
var (
	maxFiles       = 20000
	maxBytes int64 = 256 << 20
	maxFile  int64 = 32 << 20
)

// Source is one repo of the snapshot: where it goes, relative to the snapshot's top ("." for the project
// umbrella), the repo to take the files of, always with its git dir given explicitly, and the commit to
// take them at: HEAD when Rev is empty, otherwise a full commit hash.
type Source struct {
	Rel  string
	Repo git.Repo
	Rev  string
}

var revPattern = regexp.MustCompile(`^(HEAD|[0-9a-f]{40})$`)

// Export makes dst hold the committed files of each source, at its commit, in the order given. dst stays:
// its contents are removed in place, since a sandbox that mounted it keeps seeing the same folder. A
// tracked symlink, or any entry that is not a regular file or a folder, is refused, and so are a file
// that two sources both hold, a path that leaves its source's folder, and more files or bytes than the
// limits. A failed export leaves dst partly written: the caller does not use it.
func Export(ctx context.Context, dst string, sources []Source) error {
	if err := emptyDir(dst); err != nil {
		return err
	}
	root, err := os.OpenRoot(dst)
	if err != nil {
		return err
	}
	defer root.Close()
	var files int
	var total int64
	for _, s := range sources {
		if s.Rel != "." && (s.Rel == "" || !filepath.IsLocal(s.Rel)) {
			return fmt.Errorf("a snapshot source at %q: it must be a path inside the snapshot", s.Rel)
		}
		rev := s.Rev
		if rev == "" {
			rev = "HEAD"
		}
		if !revPattern.MatchString(rev) {
			return fmt.Errorf("a snapshot source at %q: %q is neither HEAD nor a full commit hash", s.Rel, s.Rev)
		}
		base := filepath.ToSlash(filepath.Clean(s.Rel))
		err := s.Repo.Pipe(ctx, func(r io.Reader) error {
			tr := tar.NewReader(r)
			for {
				h, err := tr.Next()
				if errors.Is(err, io.EOF) {
					return nil
				}
				if err != nil {
					return err
				}
				if h.Typeflag == tar.TypeXGlobalHeader {
					continue
				}
				name := path.Clean(h.Name)
				if !filepath.IsLocal(name) && name != "." {
					return fmt.Errorf("%s holds a path that leaves the snapshot: %q", s.Rel, h.Name)
				}
				target := path.Join(base, name)
				switch h.Typeflag {
				case tar.TypeDir:
					if err := root.MkdirAll(target, 0o755); err != nil {
						return err
					}
				case tar.TypeReg:
					if files++; files > maxFiles {
						return fmt.Errorf("the snapshot would hold more than %d files", maxFiles)
					}
					if total += h.Size; h.Size > maxFile || total > maxBytes {
						return fmt.Errorf("the snapshot would hold more than %d bytes (%s is %d)", maxBytes, name, h.Size)
					}
					if err := root.MkdirAll(path.Dir(target), 0o755); err != nil {
						return err
					}
					mode := os.FileMode(0o644)
					if h.Mode&0o111 != 0 {
						mode = 0o755
					}
					f, err := root.OpenFile(target, os.O_WRONLY|os.O_CREATE|os.O_EXCL, mode)
					if err != nil {
						return fmt.Errorf("%s: %w; a file that two repos both hold is refused", target, err)
					}
					_, err = io.CopyN(f, tr, h.Size)
					if cerr := f.Close(); err == nil {
						err = cerr
					}
					if err != nil {
						return err
					}
				default:
					return fmt.Errorf("%s holds %s, which is not a regular file; a link could lead the snapshot's checks outside it", target, h.Name)
				}
			}
		}, "archive", "--format=tar", rev)
		if err != nil {
			return fmt.Errorf("exporting %s: %w", s.Rel, err)
		}
	}
	return nil
}

// emptyDir removes everything in dir and keeps dir; a dir that is not there is made.
func emptyDir(dir string) error {
	st, err := os.Lstat(dir)
	switch {
	case errors.Is(err, fs.ErrNotExist):
		return os.MkdirAll(dir, 0o755)
	case err != nil:
		return err
	case !st.IsDir():
		return fmt.Errorf("%s is not a folder", dir)
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	for _, e := range entries {
		if err := os.RemoveAll(filepath.Join(dir, e.Name())); err != nil {
			return err
		}
	}
	return nil
}
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T239: a sandbox that holds a snapshot of the project, for acceptance checks, with the services of every leaf's realm

The sandbox of the snapshot is a scratch sandbox (one folder, no git dir) on the lead realm's acceptance stack, with the services of the realm of every leaf of the project, since the checks run the whole product, and the registries of those realms. A realm with acceptance checks and no acceptance stack is refused before the run starts.

**Files (in `odin`):**
- Create: `internal/run/snapshot_sandbox_test.go`
- Modify: `internal/run/prepare.go`, `internal/run/sandbox.go`

**Interfaces:**
- Produces: `Setup.SnapshotSandbox() (stack, egress, services, err)`; `Run.SnapshotRunner(ctx, node, revs)`: it exports the snapshot into `<run>/snapshot/<node>` (every time: the work changes between attempts), starts the sandbox the first time under the name `snapshot/<node>`, records it in `run.json` so that `Advance`, a resume and `ygg doctor` stop it like a leaf's, and returns the runner; a failure of the export is a `*run.SnapshotError`, not a failure of the sandbox. `serviceSet` merges services (two realms may offer one service only exactly alike, command included). `Prepare` refuses a node with acceptance checks when the lead realm has no acceptance stack.

**Acceptance criteria:**
- [ ] The snapshot sandbox gets the stack, the services of both realms and the registries of both; its spec is one the driver accepts.
- [ ] The snapshot is made again at every call and the sandbox starts once; a commit made in a leaf between two calls is in the second snapshot.
- [ ] Realms that disagree on a service cannot share it, and the error says "the snapshot"; a realm with no acceptance stack has no snapshot sandbox.

**Named test:** `go test ./internal/run -run 'TestTheSnapshotSandboxGetsTheServicesAndRegistriesOfEveryLeafsRealm|TestTheSnapshotIsMadeAgainEveryTimeAndTheSandboxStartsOnce|TestRealmsThatDisagreeOnAServiceCannotShareASnapshotSandbox|TestARealmWithNoAcceptanceStackHasNoSnapshotSandbox'` in `odin`. **Layer:** `odin`. **Size:** M (280). **Depends on:** v0-T238.

- [ ] **Step 1:** write the tests.

Write `internal/run/snapshot_sandbox_test.go`:

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

// withAcceptance gives the realm named in store an acceptance stack.
func withAcceptance(t *testing.T, store, name string) {
	t.Helper()
	pack := filepath.Join(store, name, "pack.yaml")
	b, err := os.ReadFile(pack)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(pack, []byte(strings.Replace(string(b), "  egress:", "  acceptance: { stack: "+nodeStack+" }\n  egress:", 1)), 0o644); err != nil {
		t.Fatal(err)
	}
}

// snapshotRun starts a run of a web leaf and an api leaf that don't consume each other, so that only the
// snapshot, which holds both, sees both realms' services.
func snapshotRun(t *testing.T, webServices string, acceptance bool) (*Run, *sandboxfake.Sandbox, error) {
	t.Helper()
	store := t.TempDir()
	sandboxRealm(t, store, "midgard-react", "0.1.0", nodeStack, "registry.npmjs.org", webServices)
	sandboxRealm(t, store, "helheim-go", "0.2.0", nodeStack, "proxy.golang.org, sum.golang.org", apiServices)
	if acceptance {
		withAcceptance(t, store, "midgard-react")
	}
	root := treetest.Node{Owner: "ouroboric-dev", Visibility: "private", Pin: treetest.Pin{Realm: "midgard-react", Version: "0.1.0"}, Children: map[string]treetest.Node{
		"repos/app": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Pin: treetest.Pin{Realm: "midgard-react", Version: "0.1.0"}},
		"repos/api": {Owner: "ouroboric-dev", Visibility: "private", Leaf: true, Pin: treetest.Pin{Realm: "helheim-go", Version: "0.2.0"}},
	}}
	fake := &sandboxfake.Sandbox{}
	h := Hooks{NewSandbox: func(*SandboxSetup, string) (gungnir.Sandbox, error) { return fake, nil }}
	script := "{ agent: scripted, model: none, script: " + filepath.Join(toySandbox(t), "script.yaml") + " }"
	r, err := Start(ctx, Options{Project: treetest.Build(t, root), Config: sandboxConfig(t, script, "realms:\n  dir: "+store+"\n"), Realm: "midgard-react", Hooks: h})
	if err == nil {
		t.Cleanup(func() { r.Close() })
	}
	return r, fake, err
}

func TestTheSnapshotSandboxGetsTheServicesAndRegistriesOfEveryLeafsRealm(t *testing.T) {
	r, fake, err := snapshotRun(t, "", true)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := r.SnapshotRunner(ctx, "move", nil); err != nil {
		t.Fatalf("SnapshotRunner() = %v", err)
	}
	if len(fake.Ups) != 1 {
		t.Fatalf("%d sandboxes came up", len(fake.Ups))
	}
	up := fake.Ups[0]
	var names []string
	for _, v := range up.Services {
		names = append(names, v.Name)
	}
	if up.Name != "snapshot/move" || !up.Scratch || up.Stack != nodeStack || strings.Join(names, ",") != "postgres,seaweedfs" ||
		strings.Join(up.Egress, ",") != "proxy.golang.org,registry.npmjs.org,sum.golang.org" {
		t.Errorf("spec = %+v", up)
	}
	if err := up.Validate(); err != nil {
		t.Errorf("the spec is one the driver would refuse: %v", err)
	}
}

func TestTheSnapshotIsMadeAgainEveryTimeAndTheSandboxStartsOnce(t *testing.T) {
	r, fake, err := snapshotRun(t, "", true)
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i < 2; i++ {
		if _, err := r.SnapshotRunner(ctx, "move", nil); err != nil {
			t.Fatal(err)
		}
		if i == 0 {
			b, err := os.ReadFile(filepath.Join(r.Dir, "snapshot", "move", "repos", "app", "README.md"))
			if err != nil || len(b) == 0 {
				t.Fatalf("the snapshot lacks repos/app/README.md: %v", err)
			}
			if _, err := os.Stat(filepath.Join(r.Dir, "snapshot", "move", "repos", "api", "README.md")); err != nil {
				t.Errorf("the snapshot holds only the leaves the run works in: %v", err)
			}
			// A commit made in the leaf between the two snapshots is in the second one.
			dir := r.RepoDir("repos/app")
			os.WriteFile(filepath.Join(dir, "later.txt"), []byte("later\n"), 0o644)
			for _, args := range [][]string{{"add", "later.txt"}, {"commit", "-q", "-m", "later"}} {
				l, _ := r.Leaf("repos/app")
				if _, err := l.Git(ctx, args...); err != nil {
					t.Fatal(err)
				}
			}
		}
	}
	if _, err := os.Stat(filepath.Join(r.Dir, "snapshot", "move", "repos", "app", "later.txt")); err != nil {
		t.Errorf("the second snapshot lacks the commit made after the first: %v", err)
	}
	if len(fake.Ups) != 1 {
		t.Errorf("%d sandboxes came up for one node", len(fake.Ups))
	}
}

func TestRealmsThatDisagreeOnAServiceCannotShareASnapshotSandbox(t *testing.T) {
	clash := "services:\n  postgres:\n    image: " + pgImage + "\n    env: { POSTGRES_DB: other }\n    ports: [5432]\n"
	r, _, err := snapshotRun(t, clash, true)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := r.SnapshotRunner(ctx, "move", nil); err == nil || !strings.Contains(err.Error(), "two different services named postgres") || !strings.Contains(err.Error(), "the snapshot") {
		t.Errorf("SnapshotRunner() = %v", err)
	}
}

func TestARealmWithNoAcceptanceStackHasNoSnapshotSandbox(t *testing.T) {
	r, fake, err := snapshotRun(t, "", false)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := r.SnapshotRunner(ctx, "move", nil); err == nil || !strings.Contains(err.Error(), "names no acceptance stack") {
		t.Errorf("SnapshotRunner() = %v", err)
	}
	if len(fake.Ups) != 0 {
		t.Error("a sandbox came up without a stack for it")
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
# github.com/ouroboric-dev/odin/internal/run [github.com/ouroboric-dev/odin/internal/run.test]
internal/run/snapshot_sandbox_test.go:56:17: r.SnapshotRunner undefined (type *Run has no field or method SnapshotRunner)
internal/run/snapshot_sandbox_test.go:82:18: r.SnapshotRunner undefined (type *Run has no field or method SnapshotRunner)
internal/run/snapshot_sandbox_test.go:118:17: r.SnapshotRunner undefined (type *Run has no field or method SnapshotRunner)
```

- [ ] **Step 3:** write the code.

Apply to `internal/run/prepare.go`:

```diff
diff --git a/internal/run/prepare.go b/internal/run/prepare.go
index 4ec0f73..03971ad 100644
--- a/internal/run/prepare.go
+++ b/internal/run/prepare.go
@@ -36,10 +36,10 @@ func (s *Setup) prepareSandbox() error {
 		return fmt.Errorf("%s has a sandbox section, but the realm %s names no sandbox stack in its pack.yaml", s.ConfigPath, s.Pack.Name)
 	}
 	for _, n := range s.Graph.All() {
-		// Acceptance checks run in the project umbrella, over several leaves, so there is no one leaf
-		// to mount. Until a snapshot sandbox exists (Phase 5), they can't run with a sandbox on.
-		if len(n.Acceptance) > 0 {
-			return fmt.Errorf("node %s runs acceptance checks, which run in the project umbrella and so outside any sandbox; a realm can use them once a sandbox for them exists (Phase 3, decision 11)", n.ID)
+		// Acceptance checks run over several leaves, so no leaf's sandbox holds them. With a sandbox on,
+		// they run in one that holds a snapshot of the project, on the stack the lead realm names for it.
+		if len(n.Acceptance) > 0 && s.Lead.Acceptance == "" {
+			return fmt.Errorf("node %s runs acceptance checks, which need a sandbox that holds a snapshot of the project; the realm %s names none (sandbox.acceptance in its pack.yaml)", n.ID, s.Lead.Name)
 		}
 	}
 	uid, gid := os.Getuid(), os.Getgid()
@@ -82,36 +82,89 @@ func (s *Setup) SandboxFor(repo string) (stack string, egress []string, services
 	if r.Pack.Sandbox == nil {
 		return "", nil, nil, fmt.Errorf("the leaf %s is provided by the realm %s, which names no sandbox stack in its pack.yaml, and %s has a sandbox section", repo, r.Name, s.ConfigPath)
 	}
-	owners := map[string]string{} // service name: the realm that offers it
-	add := func(from *realm.Realm) error {
-		for _, v := range from.Pack.ServiceList() {
-			i := slices.IndexFunc(services, func(x gungnir.Service) bool { return x.Name == v.Name })
-			switch {
-			case i < 0:
-				services = append(services, v)
-				owners[v.Name] = from.Name
-			case !sameService(services[i], v):
-				return fmt.Errorf("the sandbox of %s would start two different services named %s: the realm %s offers one and the realm %s another", repo, v.Name, owners[v.Name], from.Name)
-			}
-		}
-		return nil
-	}
-	if err := add(r); err != nil {
+	var set serviceSet
+	if err := set.add(repo, r); err != nil {
 		return "", nil, nil, err
 	}
 	if u := s.Project.Umbrella; u != nil {
 		for _, c := range u.Children[repo].Consumes {
-			if err := add(s.RealmOf(c)); err != nil {
+			if err := set.add(repo, s.RealmOf(c)); err != nil {
 				return "", nil, nil, err
 			}
 		}
 	}
+	services = set.list
 	slices.SortFunc(services, func(a, b gungnir.Service) int { return strings.Compare(a.Name, b.Name) })
 	return r.Stack, sortedUnique(slices.Concat(r.Pack.Sandbox.Egress, s.Sandbox.Hosts)), services, nil
 }
 
+// serviceSet collects the services of several realms for one sandbox. Two realms may offer the same service
+// only if they offer it exactly alike.
+type serviceSet struct {
+	list   []gungnir.Service
+	owners map[string]string // service name: the realm that offers it
+}
+
+// add adds the services of realm from to the sandbox of where (a leaf, or the snapshot).
+func (ss *serviceSet) add(where string, from *realm.Realm) error {
+	if ss.owners == nil {
+		ss.owners = map[string]string{}
+	}
+	for _, v := range from.Pack.ServiceList() {
+		i := slices.IndexFunc(ss.list, func(x gungnir.Service) bool { return x.Name == v.Name })
+		switch {
+		case i < 0:
+			ss.list = append(ss.list, v)
+			ss.owners[v.Name] = from.Name
+		case !sameService(ss.list[i], v):
+			return fmt.Errorf("the sandbox of %s would start two different services named %s: the realm %s offers one and the realm %s another", where, v.Name, ss.owners[v.Name], from.Name)
+		}
+	}
+	return nil
+}
+
+// projectLeaves are the leaves the sandbox of a snapshot holds: those the run works in and those the
+// project's umbrella records, sorted.
+func (s *Setup) projectLeaves() []string {
+	paths := s.Leaves()
+	if u := s.Project.Umbrella; u != nil {
+		for p, c := range u.Children {
+			if c.Kind == schema.ChildLeaf {
+				paths = append(paths, p)
+			}
+		}
+	}
+	return sortedUnique(paths)
+}
+
+// SnapshotSandbox says what the sandbox that holds a snapshot of the project starts, for acceptance checks
+// (change realm-content): the lead realm's acceptance stack, the services of the realm of every leaf of
+// the project, since the checks run the whole product, and the registries of those realms.
+func (s *Setup) SnapshotSandbox() (stack string, egress []string, services []gungnir.Service, err error) {
+	if s.Lead.Acceptance == "" {
+		return "", nil, nil, fmt.Errorf("the realm %s names no acceptance stack, so there is no sandbox for a snapshot of the project (sandbox.acceptance in its pack.yaml)", s.Lead.Name)
+	}
+	var set serviceSet
+	realms := []*realm.Realm{s.Lead}
+	for _, p := range s.projectLeaves() {
+		if r := s.RealmOf(p); !slices.Contains(realms, r) {
+			realms = append(realms, r)
+		}
+	}
+	for _, r := range realms {
+		if err := set.add("the snapshot", r); err != nil {
+			return "", nil, nil, err
+		}
+		if r.Pack.Sandbox != nil {
+			egress = append(egress, r.Pack.Sandbox.Egress...)
+		}
+	}
+	slices.SortFunc(set.list, func(a, b gungnir.Service) int { return strings.Compare(a.Name, b.Name) })
+	return s.Lead.Acceptance, sortedUnique(egress), set.list, nil
+}
+
 func sameService(a, b gungnir.Service) bool {
-	return a.Image == b.Image && maps.Equal(a.Env, b.Env) && slices.Equal(a.Ports, b.Ports)
+	return a.Image == b.Image && maps.Equal(a.Env, b.Env) && slices.Equal(a.Ports, b.Ports) && slices.Equal(a.Command, b.Command)
 }
 
 // prepareSkills opens the libraries and records the skills the graph names (spec §5.1). A node that
```

Apply to `internal/run/sandbox.go`:

```diff
diff --git a/internal/run/sandbox.go b/internal/run/sandbox.go
index 5231ef1..1a72f61 100644
--- a/internal/run/sandbox.go
+++ b/internal/run/sandbox.go
@@ -10,6 +10,8 @@ import (
 
 	"github.com/ouroboric-dev/gleipnir/sandbox"
 	"github.com/ouroboric-dev/gungnir"
+	"github.com/ouroboric-dev/odin/internal/git"
+	"github.com/ouroboric-dev/odin/internal/snapshot"
 	"github.com/ouroboric-dev/odin/internal/tree"
 )
 
@@ -108,6 +110,76 @@ func (r *Run) ScratchRunner(ctx context.Context, node string) (gungnir.Runner, e
 	return gungnir.Bind(r.Sandbox, env), nil
 }
 
+// SnapshotRunner returns what runs commands in the sandbox that holds a snapshot of the project, for the
+// acceptance checks of node: the committed files of the project umbrella and of each leaf, at the commits
+// they are on, or at the commits revs names for a leaf (by its path), in a plain folder of the run. The
+// snapshot is made again every time, since the work it holds changes between attempts; the sandbox
+// is started the first time, with the services of every leaf's realm, and is recorded under its own name
+// so that Advance, a resume and doctor stop it like a leaf's (change realm-content).
+func (r *Run) SnapshotRunner(ctx context.Context, node string, revs map[string]string) (gungnir.Runner, error) {
+	if r.Sandbox == nil {
+		return nil, nil
+	}
+	key, dir := "snapshot/"+node, filepath.Join(r.Dir, "snapshot", node)
+	sources, err := r.snapshotSources(ctx, revs)
+	if err != nil {
+		return nil, &SnapshotError{err}
+	}
+	if err := snapshot.Export(ctx, dir, sources); err != nil {
+		return nil, &SnapshotError{err}
+	}
+	if env, ok := r.State.Sandboxes[key]; ok {
+		return gungnir.Bind(r.Sandbox, env), nil
+	}
+	stack, egress, services, err := r.Setup.SnapshotSandbox()
+	if err != nil {
+		return nil, err
+	}
+	env, err := r.Sandbox.Up(ctx, gungnir.SandboxSpec{Run: r.State.ID, Name: key, Parent: r.Dir, Leaf: dir, Scratch: true,
+		Egress: egress, Stack: stack, Services: services})
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
+// SnapshotError is a snapshot that could not be made: a failure of the node, not of the sandbox.
+type SnapshotError struct{ Err error }
+
+func (e *SnapshotError) Error() string {
+	return "the snapshot of the project could not be made: " + e.Err.Error()
+}
+func (e *SnapshotError) Unwrap() error { return e.Err }
+
+// snapshotSources are the repos a snapshot is made of: the project umbrella, then each leaf of the project
+// that is checked out.
+func (r *Run) snapshotSources(ctx context.Context, revs map[string]string) ([]snapshot.Source, error) {
+	p := r.Setup.Project
+	sources := []snapshot.Source{{Rel: ".", Repo: git.Repo{GitDir: p.GitDir, WorkTree: p.Dir}}}
+	for _, path := range r.Setup.projectLeaves() {
+		nodes, err := tree.Resolve(ctx, r.Setup.Root, filepath.Join(r.Setup.ProjectPath, path))
+		if err != nil {
+			return nil, err
+		}
+		n := nodes[len(nodes)-1]
+		if !n.Present {
+			continue
+		}
+		sources = append(sources, snapshot.Source{Rel: path, Repo: git.Repo{GitDir: n.GitDir, WorkTree: n.Dir}, Rev: revs[path]})
+	}
+	return sources, nil
+}
+
 // DownSandboxes stops every sandbox this process or an earlier one started for the run, and clears
 // the record of each one it stopped. A sandbox that won't stop stays recorded, for doctor.
 func (r *Run) DownSandboxes(ctx context.Context) error {
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T240: a pointer move's acceptance checks run in the snapshot sandbox when the run has a sandbox

Phase 3's decision 11 refused acceptance checks with a sandbox on; this task is what replaces it. In a run with a sandbox, a pointer node's acceptance checks run, as the lead realm's checks, in the snapshot sandbox, over the committed files of every leaf, the one being moved at the commit it moves to. A run without a sandbox runs them in the umbrella on the host, as before.

**Files (in `odin`):**
- Create: `internal/engine/snapshot_test.go`
- Modify: `internal/engine/engine.go`, `internal/engine/land.go`, `internal/engine/sandbox_test.go`

**Interfaces:**
- `runPointer`'s acceptance callback calls `runAcceptance` when `Run.Sandbox` is set and the node has acceptance checks; it needs the pointer's parent to be the project (else the node fails, saying so). `runChecks` is split into `runChecksWith`, which takes the function that runs a command, and `commandOn`/`runOn`, which run it on a runner chosen by the caller.

**Acceptance criteria:**
- [ ] A pointer move's acceptance check goes through the snapshot sandbox, on the acceptance stack, with the leaf's committed files in it and no `.git` anywhere; the sandboxes are all stopped at the end.
- [ ] A failing acceptance check refuses the move, and the pointer does not move.
- [ ] A file a leaf ignores is not in the snapshot, and the leaf itself still has it.

**Named test:** `go test ./internal/engine -run 'TestAcceptanceChecksRunInASandboxThatHoldsASnapshotOfTheProject|TestAFailingAcceptanceCheckInTheSnapshotRefusesThePointerMove|TestWhatALeafIgnoresIsNotInTheSnapshot'` in `odin`. **Layer:** `odin`. **Size:** M (154). **Depends on:** v0-T239.

- [ ] **Step 1:** write the tests.

Apply to `internal/engine/sandbox_test.go`:

```diff
diff --git a/internal/engine/sandbox_test.go b/internal/engine/sandbox_test.go
index 693d429..c9516f7 100644
--- a/internal/engine/sandbox_test.go
+++ b/internal/engine/sandbox_test.go
@@ -31,6 +31,12 @@ func startSandboxed(t *testing.T, nodes, script string) (*run.Run, *sandboxfake.
 
 // startSandboxedWith is startSandboxed with other hooks, such as a skill library.
 func startSandboxedWith(t *testing.T, nodes, script string, h run.Hooks) (*run.Run, *sandboxfake.Sandbox) {
+	t.Helper()
+	return startSandboxedPack(t, sandboxPack, nodes, script, h)
+}
+
+// startSandboxedPack is startSandboxedWith with a pack.yaml of its own.
+func startSandboxedPack(t *testing.T, pack, nodes, script string, h run.Hooks) (*run.Run, *sandboxfake.Sandbox) {
 	t.Helper()
 	realm, cfg := t.TempDir(), t.TempDir()
 	project := treetest.Project(t, "repos/app")
@@ -38,7 +44,7 @@ func startSandboxedWith(t *testing.T, nodes, script string, h run.Hooks) (*run.R
 	os.MkdirAll(tmpl, 0o755)
 	files := map[string]string{
 		filepath.Join(tmpl, "LICENSE"):     "MIT\n",
-		filepath.Join(realm, "pack.yaml"):  "name: test\nversion: 0.1.0\ngraph: graph.yaml\n" + sandboxPack,
+		filepath.Join(realm, "pack.yaml"):  "name: test\nversion: 0.1.0\ngraph: graph.yaml\n" + pack,
 		filepath.Join(realm, "graph.yaml"): "name: test\nversion: 1.0.0\nnodes:\n" + nodes,
 		filepath.Join(realm, "p.md"):       "Do the work.\n",
 		filepath.Join(cfg, "script.yaml"):  script,
```

Write `internal/engine/snapshot_test.go`:

```go
package engine

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir"
	"github.com/ouroboric-dev/odin/internal/run"
)

const acceptanceStack = "docker.io/library/node:24.1.0-bookworm@sha256:3333333333333333333333333333333333333333333333333333333333333333"

// acceptancePack is the sandboxed pack with a stack for acceptance checks, and an acceptance check that
// looks for the build in the snapshot of the project, where the leaf is at repos/app.
func acceptancePack(accept string) string {
	p := strings.Replace(sandboxPack, "checks:\n", "checks:\n  accept: "+accept+"\n", 1)
	return p + "  acceptance: { stack: " + acceptanceStack + " }\n"
}

const acceptanceNodes = buildNodes + "  - { id: merge, kind: merge, repo: repos/app, checks: [unit] }\n" +
	"  - { id: move, kind: pointer, repo: repos/app, checks: [unit], acceptance: [accept] }\n"

func TestAcceptanceChecksRunInASandboxThatHoldsASnapshotOfTheProject(t *testing.T) {
	r, fake := startSandboxedPack(t, acceptancePack("[grep, -q, done, repos/app/build.txt]"), acceptanceNodes, buildScript, run.Hooks{})
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	var snap *gungnir.SandboxSpec
	for i, u := range fake.Ups {
		if u.Name == "snapshot/move" {
			snap = &fake.Ups[i]
		}
	}
	if snap == nil {
		t.Fatalf("no snapshot sandbox came up: %+v", fake.Ups)
	}
	if !snap.Scratch || snap.GitDir != "" || snap.Stack != acceptanceStack || snap.Leaf != filepath.Join(r.Dir, "snapshot", "move") || snap.Parent != r.Dir {
		t.Errorf("spec = %+v; want a scratch sandbox on the acceptance stack over the run's snapshot folder", *snap)
	}
	if err := snap.Validate(); err != nil {
		t.Errorf("the spec Odin built is one the driver would refuse: %v", err)
	}
	var ran bool
	for _, c := range fake.Execs {
		ran = ran || (len(c.Argv) > 1 && c.Argv[0] == "grep" && c.Argv[3] == "repos/app/build.txt")
	}
	if !ran {
		t.Errorf("the acceptance check did not go through the sandbox: %+v", fake.Execs)
	}
	if b, err := os.ReadFile(filepath.Join(r.Dir, "snapshot", "move", "repos", "app", "build.txt")); err != nil || string(b) != "done\n" {
		t.Errorf("the snapshot holds repos/app/build.txt = %q, %v; the leaf at the commit it moves to", b, err)
	}
	filepath.WalkDir(filepath.Join(r.Dir, "snapshot"), func(p string, d os.DirEntry, err error) error {
		if err == nil && d.Name() == ".git" {
			t.Errorf("the snapshot holds %s", p)
		}
		return nil
	})
	if len(fake.Downs) != len(fake.Ups) {
		t.Errorf("%d sandboxes up, %d down; the snapshot sandbox is stopped with the rest", len(fake.Ups), len(fake.Downs))
	}
	if !strings.Contains(ledgerText(t, r), `"event":"pointer_moved"`) {
		t.Error("the pointer did not move")
	}
}

func TestAFailingAcceptanceCheckInTheSnapshotRefusesThePointerMove(t *testing.T) {
	r, _ := startSandboxedPack(t, acceptancePack("[grep, -q, never-written, repos/app/build.txt]"), acceptanceNodes, buildScript, run.Hooks{})
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusFailed || !strings.Contains(out.Err.Error(), "check accept") {
		t.Fatalf("Advance() = %+v, %v; want the move refused on the acceptance check", out, err)
	}
	if strings.Contains(ledgerText(t, r), `"event":"pointer_moved"`) {
		t.Error("the pointer moved although acceptance failed")
	}
}

// What a leaf holds beyond its commit (ignored build output such as node_modules) never reaches the
// snapshot, so an acceptance check can't depend on it and the snapshot stays small.
func TestWhatALeafIgnoresIsNotInTheSnapshot(t *testing.T) {
	script := "steps:\n  a:\n    - actions:\n        - write: { path: build.txt, content: \"done\\n\" }\n        - write: { path: .gitignore, content: \"ignored.txt\\n\" }\n" +
		"        - write: { path: ignored.txt, content: \"build output\\n\" }\n      result: { status: ok, summary: built }\n"
	r, _ := startSandboxedPack(t, acceptancePack("[sh, -c, \"test -f repos/app/build.txt && test ! -e repos/app/ignored.txt\"]"), acceptanceNodes, script, run.Hooks{})
	out, err := Advance(bg, r)
	if err != nil || out.Status != run.StatusDone {
		t.Fatalf("Advance() = %+v, %v", out, err)
	}
	if _, err := os.Stat(filepath.Join(r.RepoDir("repos/app"), "ignored.txt")); err != nil {
		t.Errorf("the leaf itself lost its ignored file: %v", err)
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestAcceptanceChecksRunInASandboxThatHoldsASnapshotOfTheProject (0.59s)
    snapshot_test.go:38: no snapshot sandbox came up: [{Run:20261017-171618-dccece Name:repos/app Parent:/tmp/TestAcceptanceChecksRunInASandboxThatHoldsASnapshotOfTheProject1536147778/008/l0 Leaf:/tmp/TestAcceptanceChecksRunInASandboxThatHoldsASnapshotOfTheProject1536147778/008/l0/repos/app GitDir:/tmp/TestAcceptanceChecksRunInASandboxThatHoldsASnapshotOfTheProject1536147778/008/l0/.git/modules/repos/app Egress:[proxy.golang.org] Stack:docker.io/library/golang:1.26.7-bookworm@sha256:e8c859f5632dcfde7b32d2012b4351728f6437930887c2f6a91ea242459e5514 Services:[] Scratch:false}]
--- FAIL: TestWhatALeafIgnoresIsNotInTheSnapshot (0.57s)
    snapshot_test.go:89: Advance() = {Status:failed Gate: Err:node move: pointer move refused (acceptance): check accept failed: exit status 1 (output: /tmp/TestWhatALeafIgnoresIsNotInTheSnapshot3248283590/008/l0/.factory/runs/20261017-171619-d3e8a4/logs/move-1-accept.log) Warn:[]}, <nil>
```

- [ ] **Step 3:** write the code.

Apply to `internal/engine/engine.go`:

```diff
diff --git a/internal/engine/engine.go b/internal/engine/engine.go
index 6223f90..3cf976b 100644
--- a/internal/engine/engine.go
+++ b/internal/engine/engine.go
@@ -18,6 +18,7 @@ import (
 	"github.com/ouroboric-dev/gungnir/schema"
 	"github.com/ouroboric-dev/jormungandr"
 	"github.com/ouroboric-dev/odin/internal/leaf"
+	"github.com/ouroboric-dev/odin/internal/realm"
 	"github.com/ouroboric-dev/odin/internal/run"
 )
 
@@ -280,6 +281,17 @@ func runExec(ctx context.Context, r *run.Run, n schema.Node) error {
 // failure of the node, never a failed command (spec §12; backlog B-017).
 func command(ctx context.Context, r *run.Run, node, repo, dir string, args []string, timeout time.Duration, logPath string) (cmdErr, err error) {
 	res, err := runCheck(ctx, r, node, repo, dir, checks.Spec{Name: node, Argv: args, Timeout: orDefault(timeout)}, logPath)
+	return commandResult(res, err, timeout)
+}
+
+// commandOn is command in a runner the caller chose, such as the snapshot sandbox of an acceptance check.
+func commandOn(ctx context.Context, runner gungnir.Runner, node string, args []string, timeout time.Duration, logPath string) (cmdErr, err error) {
+	res, err := runOn(ctx, runner, checks.Spec{Name: node, Argv: args, Timeout: orDefault(timeout)}, logPath)
+	return commandResult(res, err, timeout)
+}
+
+// commandResult reads how a command ended: its failure as cmdErr, Odin's own failure as err.
+func commandResult(res checks.Result, err error, timeout time.Duration) (cmdErr, rerr error) {
 	switch {
 	case err != nil:
 		return nil, err
@@ -309,6 +321,11 @@ func runCheck(ctx context.Context, r *run.Run, node, repo, dir string, spec chec
 	if runner == nil {
 		runner = hostRunner{r: r, node: node, dir: dir}
 	}
+	return runOn(ctx, runner, spec, logPath)
+}
+
+// runOn runs one command through the check runner in runner, and reads how it went.
+func runOn(ctx context.Context, runner gungnir.Runner, spec checks.Spec, logPath string) (checks.Result, error) {
 	res, err := checks.Run(ctx, runner, spec, logPath)
 	switch {
 	case err == nil:
@@ -330,13 +347,21 @@ func runChecks(ctx context.Context, r *run.Run, n schema.Node, attempt int, name
 	if repo == "" {
 		rl = r.Setup.Realm("")
 	}
+	return runChecksWith(ctx, r, n, attempt, names, rl, func(argv []string, logPath string) (error, error) {
+		return command(ctx, r, n.ID, repo, dir, argv, time.Duration(n.Timeout), logPath)
+	})
+}
+
+// runChecksWith is runChecks with the checks of realm rl, each run by exec, which returns the command's
+// failure and, apart from it, Odin's own.
+func runChecksWith(ctx context.Context, r *run.Run, n schema.Node, attempt int, names []string, rl *realm.Realm, exec func(argv []string, logPath string) (cmdErr, err error)) error {
 	for _, c := range names {
 		argv := rl.Pack.Checks[c]
 		if len(argv) == 0 {
 			return &nodeFailure{fmt.Errorf("the realm %s defines no check %s", rl.Name, c)}
 		}
 		logPath := filepath.Join(r.Dir, "logs", fmt.Sprintf("%s-%d-%s.log", n.ID, attempt, c))
-		cmdErr, err := command(ctx, r, n.ID, repo, dir, argv, time.Duration(n.Timeout), logPath)
+		cmdErr, err := exec(argv, logPath)
 		if err != nil {
 			return err
 		}
```

Apply to `internal/engine/land.go`:

```diff
diff --git a/internal/engine/land.go b/internal/engine/land.go
index 11fa7b3..0404d0d 100644
--- a/internal/engine/land.go
+++ b/internal/engine/land.go
@@ -108,8 +108,13 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 		Check: func(ctx context.Context) error {
 			return tidied(ctx, l, runChecks(ctx, r, n, attempt, n.Checks, n.Repo, l.Dir()))
 		},
-		Acceptance: func(ctx context.Context) error { return runChecks(ctx, r, n, attempt, n.Acceptance, "", parent.Dir) },
-		Generated:  n.Generated, SkipShrink: s.Waived[n.ID],
+		Acceptance: func(ctx context.Context) error {
+			if r.Sandbox == nil || len(n.Acceptance) == 0 {
+				return runChecks(ctx, r, n, attempt, n.Acceptance, "", parent.Dir)
+			}
+			return runAcceptance(ctx, r, n, attempt, parentRepo, n.Repo, to)
+		},
+		Generated: n.Generated, SkipShrink: s.Waived[n.ID],
 		Message: fmt.Sprintf("Move %s to %.12s (run %s, node %s)", child, to, s.ID, n.ID)})
 	var hs *hardStop
 	if errors.As(moveErr, &hs) { // the sandbox broke a hardening rule
@@ -166,6 +171,26 @@ func runPointer(ctx context.Context, r *run.Run, n schema.Node) error {
 	return nil
 }
 
+// runAcceptance runs a pointer node's acceptance checks, in a run with a sandbox, in the sandbox that holds
+// a snapshot of the project (change realm-content): the lead realm's checks, on the lead realm's
+// acceptance stack, over the committed files of every leaf, the one being moved at the commit it moves to.
+// Nothing of a leaf's working copy or git dir is in it, and what the checks write stays in the snapshot.
+func runAcceptance(ctx context.Context, r *run.Run, n schema.Node, attempt int, parentRepo, leafRepo, to string) error {
+	if parentRepo != "." {
+		return &nodeFailure{fmt.Errorf("node %s runs acceptance checks in the umbrella %s; the snapshot sandbox holds the project, so they run where the leaf's parent is the project", n.ID, parentRepo)}
+	}
+	runner, err := r.SnapshotRunner(ctx, n.ID, map[string]string{leafRepo: to})
+	var se *run.SnapshotError
+	if errors.As(err, &se) {
+		return &nodeFailure{err}
+	} else if err != nil {
+		return sandboxStart(err)
+	}
+	return runChecksWith(ctx, r, n, attempt, n.Acceptance, r.Setup.Realm(""), func(argv []string, logPath string) (error, error) {
+		return commandOn(ctx, runner, n.ID, argv, time.Duration(n.Timeout), logPath)
+	})
+}
+
 // failLanding fails a merge or pointer node that the gate refused, or whose target another process
 // holds. Anything else is a failure of Odin itself. A gate that refused because a check ran and failed on
 // the work sends the work back into the loop that made it when the node names one (spec §4.5, back_to); a
```

- [ ] **Step 4:** run the named test. Expect `ok`.

- [ ] **Step 5:** commit (see "How each task lands").

---

### Task v0-T241: the real realms build a product from a brief with scripted agents, through Odin's own code

Phase 5b's exit criterion with scripted agents: `midgard-react` and `helheim-go`, as they are in the umbrella, run through `ygg run`: their graph, prompts, templates and leaf recipes. Two things are not the realms': the agents answer from a script, and the check ladder's commands are replaced by plain ones, because the ladder's tools are in the stack images (v0-H15 runs the real ladder on a real engine). The test needs the realms beside `odin`, as in the umbrella, and skips without them; the executor runs it after the two realms' PRs are merged.

**Files (in `odin`):**
- Create: `internal/cli/realms_content_test.go`

**Interfaces:**
- Produces: `internal/cli/realms_content_test.go`: it copies both realms into a store (leaving out `.git`, `node_modules` and `dist`), swaps each ladder script for `test -f AGENTS.md` and the acceptance script for `test -f umbrella.yaml`, and runs the brief to the end: the design gate is approved by hand, the spec gate opens by itself, the leaves come from the real templates, three tasks run in two leaves with three reviewers each, and the pointers move.

**Acceptance criteria:**
- [ ] The documents of the three stages are published; the project pins `midgard-react` and each leaf's realm; the API leaf has `openapi.yaml`, `sqlc.yaml` and the store from its template and the web leaf has `package.json`, the typed client and the Playwright spec from its own.
- [ ] The three tasks are done and the project points at what landed; the nine reviewer sessions ran; the ledger has `conformance_checked` ("no deviation"), `tasks_ready` and `pointer_moved`; the simplicity reviewer's and the reuse review's prompts carry the Ponytail skill.
- [ ] The spec prompt offers each realm at the version the loaded pack has; `ygg status` shows both realms and three tasks done.

**Named test:** `go test ./internal/cli -run 'TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents'` in `odin`. **Layer:** `odin`. **Size:** M (277). **Depends on:** v0-T240, and the PRs of helheim-go and midgard-react merged.

- [ ] **Step 1:** write the tests.

Write `internal/cli/realms_content_test.go`:

```go
package cli

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gungnir/schema"
	"github.com/ouroboric-dev/odin/internal/git"
	"github.com/ouroboric-dev/odin/internal/run"
	"github.com/ouroboric-dev/odin/internal/tree/treetest"
)

// The exit criterion of Phase 5b, with scripted agents: the real realms midgard-react and helheim-go build a
// product from a brief, end to end, through Odin's real code: their graph, their prompts, their templates,
// their leaf recipes. Only two things are not the realms': the agents, which answer from a script, and the
// check ladder's commands, which are replaced by plain ones because the ladder's tools live in the stack images
// (the ladder runs on a real engine, v0-H14 and v0-H15). The test needs the realms beside odin, as they are in
// the yggdrasil umbrella; it skips without them.

// realRealm copies the realm repo at src into store/name, leaving out git, packages and build output, and
// swaps the ladder's scripts for commands any machine runs.
func realRealm(t *testing.T, store, name string) {
	t.Helper()
	src, err := filepath.Abs(filepath.Join("..", "..", "..", name))
	if err == nil {
		src, err = filepath.EvalSymlinks(src) // beside odin, the realm may be a link (a plan's reference workspace)
	}
	if err != nil {
		t.Skipf("the realm %s is not beside odin: %v", name, err)
	}
	if st, err := os.Stat(filepath.Join(src, "pack.yaml")); err != nil || !st.Mode().IsRegular() {
		t.Skipf("the realm %s is not beside odin (%s); run this test in the yggdrasil umbrella", name, src)
	}
	dst := filepath.Join(store, name)
	err = filepath.WalkDir(src, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel(src, p)
		if d.IsDir() && (d.Name() == ".git" || d.Name() == "node_modules" || d.Name() == "dist") {
			return filepath.SkipDir
		}
		if d.IsDir() {
			return os.MkdirAll(filepath.Join(dst, rel), 0o755)
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		info, _ := d.Info()
		return os.WriteFile(filepath.Join(dst, rel), b, info.Mode().Perm())
	})
	if err != nil {
		t.Fatal(err)
	}
	pack := filepath.Join(dst, "pack.yaml")
	b, _ := os.ReadFile(pack)
	plain := regexp.MustCompile(`\[/opt/ygg/checks/accept-e2e\.sh\]`).ReplaceAllString(string(b), "[test, -f, umbrella.yaml]")
	plain = regexp.MustCompile(`\[/opt/ygg/checks/[a-z0-9-]+\.sh\]`).ReplaceAllString(plain, "[test, -f, AGENTS.md]")
	if plain == string(b) {
		t.Fatalf("%s: no check to replace", pack)
	}
	if err := os.WriteFile(pack, []byte(plain), 0o644); err != nil {
		t.Fatal(err)
	}
}

const leafReviewers = "  gallery-t%d-implement-spec-compliance:\n    - result: { status: ok, report: [] }\n  gallery-t%d-implement-simplicity:\n    - result: { status: ok, report: [] }\n" +
	"  gallery-t%d-implement-quality:\n    - result: { status: ok, report: [] }\n"

const realScript = `steps:
  design:
    - actions: [ { write: { path: out/1-product/design/2026-10-17-gallery.md, content: "---\ntitle: Gallery design\nstatus: draft\ndate: 2026-10-17\nrelated: []\n---\n# Gallery design\n" } } ]
      result: { status: ok, summary: wrote the design, usage: { in: 1000, out: 100, turns: 2 } }
  spec:
    - actions:
        - write: { path: out/2-engineering/specs/2026-10-17-gallery.md, content: "---\ntitle: Gallery spec\nstatus: draft\ndate: 2026-10-17\nrelated: []\n---\n# Gallery spec\n" }
        - write:
            path: out/leaves.yaml
            content: |
              leaves:
                repos/api:
                  realm: helheim-go
                  realm_version: HELHEIM_VERSION
                  description: The gallery's API.
                repos/web:
                  realm: midgard-react
                  realm_version: MIDGARD_VERSION
                  description: The gallery's web app.
                  consumes: [repos/api]
      result: { status: ok, summary: wrote the spec and named the leaves, usage: { in: 1000, out: 100, turns: 2 } }
  conformance:
    - actions: [ { write: { path: out/conformance.json, content: '{"deviation": false}' } } ]
      result: { status: ok, summary: the spec stays inside the design, usage: { in: 500, out: 50, turns: 1 } }
  plan:
    - actions:
        - write:
            path: out/2-engineering/plans/2026-10-17-gallery/tasks.md
            content: |
              ---
              title: Gallery tasks
              status: draft
              date: 2026-10-17
              related: []
              ---
              # Tasks

              ## gallery-T1: the API stores galleries

              - **Acceptance criteria:**
                - [ ] a gallery can be created
              - **Named test:** gallery_test.go TestCreateGallery
              - **Layer:** repos/api
              - **Size:** S
              - **Depends on:** nothing

              ## gallery-T2: the web app lists them

              - **Acceptance criteria:**
                - [ ] the home page lists galleries
              - **Named test:** e2e/galleries.spec.ts
              - **Layer:** repos/web
              - **Size:** M
              - **Depends on:** gallery-T1

              ## gallery-T3: the web app shows a gallery

              - **Acceptance criteria:**
                - [ ] a gallery page shows its name
              - **Named test:** src/gallery.test.tsx
              - **Layer:** repos/web
              - **Size:** S
              - **Depends on:** gallery-T2
        - write:
            path: out/2-engineering/plans/2026-10-17-gallery/plan.md
            content: "---\ntitle: Gallery plan\nstatus: draft\ndate: 2026-10-17\nrelated: []\n---\n# Gallery plan\n"
      result: { status: ok, summary: wrote the plan, usage: { in: 1000, out: 100, turns: 2 } }
  reuse-review:
    - actions: [ { write: { path: out/2-engineering/reviews/2026-10-17-gallery-reuse-review.md, content: "---\ntitle: Gallery reuse review\nstatus: draft\ndate: 2026-10-17\nrelated: []\n---\n## Verdict\n\nNothing to remove.\n" } } ]
      result: { status: ok, summary: nothing to remove, usage: { in: 500, out: 50, turns: 1 } }
  gallery-t1-implement:
    - actions: [ { write: { path: api.txt, content: "done\n" } } ]
      result: { status: ok, summary: built the API's galleries, usage: { in: 2000, out: 200, turns: 4 } }
  gallery-t2-implement:
    - actions: [ { write: { path: web.txt, content: "done\n" } } ]
      result: { status: ok, summary: built the page, usage: { in: 2000, out: 200, turns: 4 } }
  gallery-t3-implement:
    - actions: [ { write: { path: gallery.txt, content: "done\n" } } ]
      result: { status: ok, summary: built the gallery page, usage: { in: 2000, out: 200, turns: 4 } }
`

func TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents(t *testing.T) {
	store := t.TempDir()
	realRealm(t, store, "midgard-react")
	realRealm(t, store, "helheim-go")
	versions := map[string]string{}
	for _, name := range []string{"midgard-react", "helheim-go"} {
		p, err := schema.LoadPack(filepath.Join(store, name))
		if err != nil {
			t.Fatalf("the realm %s does not load: %v", name, err)
		}
		versions[name] = p.Version
		if p.Leaf == nil {
			t.Fatalf("%s offers no leaf recipe", name)
		}
	}
	// The spec prompt offers each realm at the version it has: a spec that names another fails the leaves check.
	specPrompt, _ := os.ReadFile(filepath.Join(store, "midgard-react", "prompts", "spec.md"))
	for name, v := range versions {
		if !strings.Contains(string(specPrompt), "`"+name+"` "+v) {
			t.Errorf("midgard-react's spec prompt does not offer %s %s", name, v)
		}
	}
	script := strings.NewReplacer("HELHEIM_VERSION", versions["helheim-go"], "MIDGARD_VERSION", versions["midgard-react"]).Replace(realScript)
	for i := 1; i <= 3; i++ {
		script += fmt.Sprintf(leafReviewers, i, i, i)
	}
	path := filepath.Join(t.TempDir(), "script.yaml")
	if err := os.WriteFile(path, []byte(script), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	roles := "{ agent: scripted, model: none, script: " + path + " }"
	cfg := filepath.Join(t.TempDir(), "factory.yaml")
	body := "mode: key-points\nroles:\n  planner: " + roles + "\n  implementer: " + roles + "\n  reviewer: " + roles + "\n" +
		"budget:\n  per_run: { tokens: 1000000, turns: 1000 }\n  per_day: { tokens: 2000000, turns: 2000 }\nrealms:\n  dir: " + store + "\n"
	if err := os.WriteFile(cfg, []byte(body), 0o644); err != nil {
		t.Fatal(err)
	}
	dir := treetest.Project(t)
	code, out, errOut := ygg(t, "run", "--project", dir, "--config", cfg, "--realm", "midgard-react")
	if code != ExitStopped || !strings.Contains(out, "stopped at approval point design-gate") {
		t.Fatalf("run: exit %d:\n%s%s", code, out, errOut)
	}
	id := runID(t, dir)
	if code, out, errOut = ygg(t, "approve", id, "design-gate", "--project", dir); code != ExitDone || !strings.Contains(out, "is done.") {
		t.Fatalf("approve: exit %d:\n%s%s", code, out, errOut)
	}

	for _, f := range []string{"docs/1-product/design/2026-10-17-gallery.md", "docs/2-engineering/specs/2026-10-17-gallery.md", "docs/leaves.yaml",
		"docs/2-engineering/plans/2026-10-17-gallery/tasks.md", "docs/2-engineering/plans/2026-10-17-gallery/plan.md", "docs/2-engineering/reviews/2026-10-17-gallery-reuse-review.md"} {
		if _, err := os.Stat(filepath.Join(dir, f)); err != nil {
			t.Errorf("%s was not published: %v", f, err)
		}
	}
	st, err := run.LoadState(run.Dir(dir, id))
	if err != nil || st.Status != run.StatusDone {
		t.Fatalf("run.json: %+v, %v", st, err)
	}
	// The leaves were made from the real templates of their realms.
	for leaf, files := range map[string][]string{"repos/api": {"openapi.yaml", "sqlc.yaml", "internal/store/migrate.go", "cmd/api/main.go"},
		"repos/web": {"package.json", "package-lock.json", "src/lib/api.ts", "contracts/api.openapi.yaml", "e2e/smoke.spec.ts"}} {
		for _, f := range files {
			if _, err := os.Stat(filepath.Join(dir, leaf, f)); err != nil {
				t.Errorf("%s/%s: %v; the leaf is made from the template of its realm", leaf, f, err)
			}
		}
	}
	u, err := schema.LoadUmbrella(dir)
	if err != nil {
		t.Fatal(err)
	}
	if u.Realm != "midgard-react" || u.Children["repos/api"].Realm != "helheim-go" || u.Children["repos/web"].Realm != "midgard-react" {
		t.Errorf("the project's pins: lead %s; api %+v; web %+v", u.Realm, u.Children["repos/api"], u.Children["repos/web"])
	}
	for leaf, f := range map[string]string{"repos/api": "api.txt", "repos/web": "gallery.txt"} {
		if body, err := git.Run(ctx, filepath.Join(dir, leaf), "show", "main:"+f); err != nil || body != "done" {
			t.Errorf("%s: main:%s = %q, %v", leaf, f, body, err)
		}
		main, _ := git.Run(ctx, filepath.Join(dir, leaf), "rev-parse", "main")
		if got, _ := git.Run(ctx, dir, "rev-parse", "HEAD:"+leaf); got != main {
			t.Errorf("the project points at %s for %s, want main %s", got, leaf, main)
		}
	}
	feats, err := schema.LoadFeatures(filepath.Join(dir, ".factory", "features.json"))
	if err != nil || len(feats.Tasks) != 3 {
		t.Fatalf("features.json = %+v, %v", feats, err)
	}
	for _, f := range feats.Tasks {
		if f.Status != schema.TaskDone {
			t.Errorf("task %s is %s", f.ID, f.Status)
		}
	}
	// The three reviewers of the graph ran for every task, in the task's leaf, and the conformance review ran.
	for i := 1; i <= 3; i++ {
		for _, rv := range []string{"spec-compliance", "simplicity", "quality"} {
			key := fmt.Sprintf("gallery-t%d-implement-%s", i, rv)
			if st.Attempts[key] != 1 {
				t.Errorf("reviewer session %s ran %d times, want 1", key, st.Attempts[key])
			}
		}
	}
	ledger, _ := os.ReadFile(filepath.Join(run.Dir(dir, id), "ledger.jsonl"))
	for _, want := range []string{`"event":"conformance_checked"`, `"ygg.result":"no deviation"`, `"event":"tasks_ready"`, `"event":"pointer_moved"`} {
		if !strings.Contains(string(ledger), want) {
			t.Errorf("the ledger lacks %s", want)
		}
	}
	// The simplicity reviewer and the reuse review got the vendored Ponytail skill in their prompts.
	for _, stem := range []string{"reuse-review-1", "gallery-t1-implement-simplicity-1"} {
		tr, err := os.ReadFile(filepath.Join(run.Dir(dir, id), "transcripts", stem+".json"))
		if err != nil || !strings.Contains(string(tr), "Review a change like the senior developer who will be paged") {
			t.Errorf("transcript %s lacks the Ponytail skill: %v", stem, err)
		}
	}
	_, status, _ := ygg(t, "status", id, "--project", dir)
	for _, want := range []string{"realm:    midgard-react " + versions["midgard-react"], "(helheim-go " + versions["helheim-go"] + ")", "tasks:    3 (3 done, 0 doing, 0 to do, 0 blocked)"} {
		if !strings.Contains(status, want) {
			t.Errorf("status lacks %q:\n%s", want, status)
		}
	}
}
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents (0.00s)
    realms_content_test.go:156: read /tmp/tmp.7hk41Ij7m2/v0-T241/midgard-react: is a directory
FAIL
FAIL	github.com/ouroboric-dev/odin/internal/cli	32.100s
```

- [ ] **Step 3:** run the named test. Expect `ok`.

- [ ] **Step 4:** commit (see "How each task lands").

---

### Task v0-T242: the scripted answers, brief and example config of the content smoke run on a real engine

The files that v0-H15 reads when it runs the two real realms on a real engine, kept in `odin` so they are reviewed and versioned with the code that reads them. The agents answer from the script and cost nothing; the brief is two small tasks (the API says its version, the web page shows it), written so that every rung of the check ladders and the acceptance run has real code and real tests to judge.

**Files (in `odin`):**
- Create: `internal/cli/smoke_content_test.go`, `testdata/smoke-content/brief.md`, `testdata/smoke-content/factory.example.yaml`, `testdata/smoke-content/script.yaml`

**Interfaces:**
- Produces: `testdata/smoke-content/script.yaml` (the answers of the planners, the implementers and the reviewers, the same `scripted` format as `testdata/toy/script.yaml`), `brief.md`, `factory.example.yaml` (an operator copies it and sets the engine, the mounts and the realm folder) and `internal/cli/smoke_content_test.go`.

**Acceptance criteria:**
- [ ] The script loads with the scripted adapter, the brief is not empty, and the example config gives the planner, the implementer and the reviewer the script.
- [ ] The files were run on a real engine in the scratch workspace of this plan: both tasks done and merged, the pointers moved, the acceptance run passed on the snapshot sandbox ("Evidence" says so).

**Named test:** `go test ./internal/cli -run 'TestTheContentSmokeFilesLoad'` in `odin`. **Layer:** `odin`. **Size:** M (369). **Depends on:** v0-T241.

- [ ] **Step 1:** write the tests.

Write `internal/cli/smoke_content_test.go`:

```go
package cli

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/ouroboric-dev/gleipnir/scripted"
)

// The content smoke run (v0-H15) reads these files on a real engine; this test keeps them loadable.
func TestTheContentSmokeFilesLoad(t *testing.T) {
	dir := filepath.Join("..", "..", "testdata", "smoke-content")
	if _, err := scripted.Load(filepath.Join(dir, "script.yaml")); err != nil {
		t.Errorf("script.yaml does not load: %v", err)
	}
	brief, err := os.ReadFile(filepath.Join(dir, "brief.md"))
	if err != nil || len(strings.TrimSpace(string(brief))) == 0 {
		t.Errorf("brief.md: %q, %v", brief, err)
	}
	example, err := os.ReadFile(filepath.Join(dir, "factory.example.yaml"))
	if err != nil {
		t.Fatal(err)
	}
	for _, role := range []string{"planner", "implementer", "reviewer"} {
		if !strings.Contains(string(example), role+": { agent: scripted, model: none, script: ") {
			t.Errorf("factory.example.yaml gives the %s no script", role)
		}
	}
}
```

Write `testdata/smoke-content/brief.md`:

```md
# Brief: the gallery's version

The gallery's server should tell anyone who asks which version of it is running, and the gallery's web page
should show it.

- The server answers `GET /version` with the JSON `{"version": "0.1.0"}`. Any other method gets a 405.
- The web home page shows the line `API version: 0.1.0` below the line that says whether the API is up.

Nothing else: no login, no galleries, no pages.
```

Write `testdata/smoke-content/factory.example.yaml`:

```yaml
# An example factory.yaml for the content smoke run (v0-H15): the real midgard-react and helheim-go realms,
# built with scripted agents on a real container engine. The agents cost nothing: they answer from
# script.yaml, and every command the realms run (the check ladder, the services, the acceptance run) is
# real. Copy it, set the engine, the mounts and the realm folder for your machine. The factory ships no
# defaults for the caps.
mode: unattended
privacy: strict
gates:
  design: auto
roles:
  planner: { agent: scripted, model: none, script: /home/OPERATOR/yggdrasil/odin/testdata/smoke-content/script.yaml }
  implementer: { agent: scripted, model: none, script: /home/OPERATOR/yggdrasil/odin/testdata/smoke-content/script.yaml }
  reviewer: { agent: scripted, model: none, script: /home/OPERATOR/yggdrasil/odin/testdata/smoke-content/script.yaml }
budget:
  per_run: { tokens: 1000000, turns: 1000 }
  per_day: { tokens: 2000000, turns: 2000 }
sandbox:
  engine: unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock
  mounts:
    - { host: /home/OPERATOR/ygg, engine: /mnt/wsl/ygg-bind }
realms:
  dir: /home/OPERATOR/yggdrasil
```

Write `testdata/smoke-content/script.yaml`:

```yaml
# The scripted agents' answers for the content smoke run (v0-H15): a one-feature brief (the gallery's
# version) built in two leaves, with real code and real tests, so that every rung of the realms' check ladders
# and the acceptance run have something real to judge. The planners write the documents the prompts ask
# for; the implementers write what a real implementer would, with the commands a real one would run.
steps:
  design:
    - actions:
        - write:
            path: out/1-product/design/2026-10-17-version.md
            content: |
              ---
              title: Gallery version design
              status: draft
              date: 2026-10-17
              related: []
              ---
              # Gallery version design

              ## Summary

              The gallery tells anyone who asks which version is running, and its web page shows it.
      result: { status: ok, summary: wrote the design, usage: { in: 1000, out: 100, turns: 2 } }
  spec:
    - actions:
        - write:
            path: out/2-engineering/specs/2026-10-17-version.md
            content: |
              ---
              title: Gallery version spec
              status: draft
              date: 2026-10-17
              related: [../../1-product/design/2026-10-17-version.md]
              ---
              # Gallery version spec

              ## Summary

              `GET /version` answers `{"version": "0.1.0"}`; the home page shows `API version: 0.1.0`.

              ## Deviations from the design doc

              None.
        - write:
            path: out/leaves.yaml
            content: |
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
      result: { status: ok, summary: wrote the spec and named the leaves, usage: { in: 1000, out: 100, turns: 2 } }
  conformance:
    - actions: [ { write: { path: out/conformance.json, content: '{"deviation": false}' } } ]
      result: { status: ok, summary: the spec stays inside the design, usage: { in: 500, out: 50, turns: 1 } }
  plan:
    - actions:
        - write:
            path: out/2-engineering/plans/2026-10-17-version/plan.md
            content: |
              ---
              title: Gallery version plan
              status: draft
              date: 2026-10-17
              related: [../../specs/2026-10-17-version.md]
              ---
              # Gallery version plan

              ## Order

              | Task | Leaf | Size | Depends on |
              |---|---|---|---|
              | version-T1 | repos/api | S | nothing |
              | version-T2 | repos/web | S | version-T1 |
        - write:
            path: out/2-engineering/plans/2026-10-17-version/tasks.md
            content: |
              ---
              title: Gallery version tasks
              status: draft
              date: 2026-10-17
              related: [plan.md]
              ---
              # Tasks

              ## version-T1: the API says its version

              - **Acceptance criteria:**
                - [ ] `GET /version` answers 200 with the JSON `{"version": "0.1.0"}`
                - [ ] any other method on `/version` answers 405
                - [ ] `openapi.yaml` describes `/version`
              - **Named test:** internal/httpapi/version_test.go TestVersionIsServed
              - **Layer:** repos/api
              - **Size:** S
              - **Depends on:** nothing

              ## version-T2: the home page shows the version

              - **Acceptance criteria:**
                - [ ] the home page shows `API version: 0.1.0` below the health line
                - [ ] the web app's copy of the contract has `/version`, exactly as the API describes it
              - **Named test:** src/version.test.tsx
              - **Layer:** repos/web
              - **Size:** S
              - **Depends on:** version-T1
      result: { status: ok, summary: wrote the plan, usage: { in: 1000, out: 100, turns: 2 } }
  reuse-review:
    - actions:
        - write:
            path: out/2-engineering/reviews/2026-10-17-version-reuse-review.md
            content: |
              ---
              title: Gallery version reuse review
              status: draft
              date: 2026-10-17
              related: [../plans/2026-10-17-version/plan.md]
              ---
              ## Verdict

              Nothing to remove.
      result: { status: ok, summary: nothing to remove, usage: { in: 500, out: 50, turns: 1 } }
  version-t1-implement:
    - actions:
        - write:
            path: internal/httpapi/version_test.go
            content: |
              package httpapi

              import (
              	"encoding/json"
              	"net/http"
              	"net/http/httptest"
              	"testing"
              )

              func TestVersionIsServed(t *testing.T) {
              	rec := httptest.NewRecorder()
              	New(Deps{}).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/version", nil))
              	if rec.Code != http.StatusOK {
              		t.Fatalf("GET /version = %d, want 200", rec.Code)
              	}
              	var body map[string]string
              	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil || body["version"] != "0.1.0" {
              		t.Errorf("body = %s, %v; want {\"version\":\"0.1.0\"}", rec.Body.String(), err)
              	}
              }

              func TestOnlyGetReachesVersion(t *testing.T) {
              	rec := httptest.NewRecorder()
              	New(Deps{}).ServeHTTP(rec, httptest.NewRequest(http.MethodPost, "/version", nil))
              	if rec.Code != http.StatusMethodNotAllowed {
              		t.Errorf("POST /version = %d, want 405", rec.Code)
              	}
              }
        - write:
            path: internal/httpapi/version.go
            content: |
              package httpapi

              import "net/http"

              // version is the API's version, as /version reports it.
              const version = "0.1.0"

              func versionHandler(w http.ResponseWriter, _ *http.Request) {
              	writeJSON(w, http.StatusOK, map[string]string{"version": version})
              }
        - run:
            argv:
              - sed
              - -i
              - 's|^\tmux.HandleFunc("/", notFound)|\tmux.HandleFunc("/version", only(http.MethodGet, versionHandler))\n&|'
              - internal/httpapi/server.go
        - run:
            argv:
              - sh
              - -c
              - |
                cat >> openapi.yaml <<'EOF'
                  /version:
                    get:
                      operationId: getVersion
                      summary: Which version the server is
                      responses:
                        "200":
                          description: The server's version.
                          content:
                            application/json:
                              schema:
                                type: object
                                required: [version]
                                properties:
                                  version:
                                    type: string
                                    example: "0.1.0"
                EOF
      result: { status: ok, summary: the API serves its version, usage: { in: 2000, out: 200, turns: 4 } }
  version-t2-implement:
    - actions:
        - write:
            path: src/version.test.tsx
            content: |
              import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
              import { render, screen } from "@testing-library/react";
              import { describe, expect, it, vi } from "vitest";
              import { VersionBadge } from "@/components/version-badge";

              function renderBadge() {
                const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
                return render(
                  <QueryClientProvider client={client}>
                    <VersionBadge />
                  </QueryClientProvider>,
                );
              }

              describe("VersionBadge", () => {
                it("shows the version the API reports", async () => {
                  vi.stubGlobal(
                    "fetch",
                    vi.fn(async () => new Response(JSON.stringify({ version: "0.1.0" }), { status: 200, headers: { "Content-Type": "application/json" } })),
                  );
                  renderBadge();
                  expect(await screen.findByText("API version: 0.1.0")).toBeInTheDocument();
                });
              });
        - write:
            path: src/components/version-badge.tsx
            content: |
              import { useQuery } from "@tanstack/react-query";
              import { api } from "@/lib/api";

              /** The API's version, as /version says it. */
              async function readVersion(): Promise<string> {
                const { data } = await api.GET("/version");
                if (!data) throw new Error("the API did not say its version");
                return data.version;
              }

              export function VersionBadge() {
                const version = useQuery({ queryKey: ["version"], queryFn: readVersion });
                if (!version.data) return null;
                return <p className="text-sm text-neutral-600">API version: {version.data}</p>;
              }
        - run:
            argv:
              - sed
              - -i
              - -e
              - 's|^import { HealthBadge } from "@/components/health-badge";|&\nimport { VersionBadge } from "@/components/version-badge";|'
              - -e
              - 's|^      <HealthBadge />|&\n      <VersionBadge />|'
              - src/routes/index.tsx
        - run:
            argv:
              - sh
              - -c
              - |
                cat >> contracts/api.openapi.yaml <<'EOF'
                  /version:
                    get:
                      operationId: getVersion
                      summary: Which version the server is
                      responses:
                        "200":
                          description: The server's version.
                          content:
                            application/json:
                              schema:
                                type: object
                                required: [version]
                                properties:
                                  version:
                                    type: string
                                    example: "0.1.0"
                EOF
        - run: { argv: [npm, ci, --no-audit, --no-fund] }
        - run: { argv: [npm, run, gen:api] }
        - run:
            argv:
              - sh
              - -c
              - |
                cat >> e2e/smoke.spec.ts <<'EOF'

                test("the home page shows the API's version", async ({ page }) => {
                  await page.goto("/");
                  await expect(page.getByText("API version: 0.1.0")).toBeVisible();
                });
                EOF
      result: { status: ok, summary: the home page shows the version, usage: { in: 2000, out: 200, turns: 4 } }
  version-t1-implement-spec-compliance:
    - result: { status: ok, report: [] }
  version-t1-implement-simplicity:
    - result: { status: ok, report: [] }
  version-t1-implement-quality:
    - result: { status: ok, report: [] }
  version-t2-implement-spec-compliance:
    - result: { status: ok, report: [] }
  version-t2-implement-simplicity:
    - result: { status: ok, report: [] }
  version-t2-implement-quality:
    - result: { status: ok, report: [] }
```

- [ ] **Step 2:** run the named test. Expect it to fail, first like this:

```output
--- FAIL: TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents (0.00s)
    realms_content_test.go:156: read /tmp/tmp.7hk41Ij7m2/v0-T242/midgard-react: is a directory
FAIL
FAIL	github.com/ouroboric-dev/odin/internal/cli	25.785s
```

- [ ] **Step 3:** run the named test. Expect `ok`.

- [ ] **Step 4:** commit (see "How each task lands").

---

### Task v0-T243: Odin's documentation

The architecture page says what Odin now does.

**Files (in `odin`):**
- Modify: `docs/architecture.md`

**Acceptance criteria:**
- [ ] `docs/architecture.md` says that a realm's stack may be built from its context, that acceptance checks run in a snapshot sandbox, and how the spec gate reads the conformance verdict.

**Named test:** `git diff --stat -- docs/architecture.md` in `odin`. **Layer:** `odin`. **Size:** S (10). **Depends on:** v0-T242.

- [ ] **Step 1:** write the code.

Apply to `docs/architecture.md`:

```diff
diff --git a/docs/architecture.md b/docs/architecture.md
index c967a34..adfb5f1 100644
--- a/docs/architecture.md
+++ b/docs/architecture.md
@@ -30,7 +30,16 @@ The orchestrator: the graph engine and the `ygg` CLI, with routing and the ledge
   (`back_to`, a few times). An unattended run gives up a task whose loop gave up, keeps its work on a
   ref, and goes on with the tasks that do not depend on it.
 - Starts each leaf's sandbox on its realm's stack, with the services of its realm and of the leaves it
-  consumes (spec §6.1, §9.2).
+  consumes (spec §6.1, §9.2). A realm's stack is an image pinned by digest or one that `ygg sandbox build`
+  builds from the realm's own build context (change realm-content); the tag is a hash of the context.
+- Runs a pointer move's acceptance checks, when the run has a sandbox, in a sandbox that holds a snapshot
+  of the project: the committed files of the umbrella and of each leaf, at the commits they are on, in a
+  plain folder with no git directory, on the lead realm's acceptance stack and with the services of every
+  leaf's realm. What a leaf's working copy holds beyond its commits never reaches it.
+- Reads the design-conformance verdict (`out/conformance.json` of a scratch reviewer that reviews another
+  scratch agent's output, which it finds as `reviewed/`) and gives it to the spec gate: a deviation stops the
+  gate in every mode, with the proposed amendment in the gate file; a verdict that cannot be read is asked
+  for once more and then stops the run, never a pass (spec §4.2, §4.6).
 - Counts every session's usage, a failed one's too, in the run and in a daily spend journal outside
   any project, and stops the run at the hard approval point `budget-cap` before a session would start
   over a cap (spec §7.4). Pauses the run when the provider's quota is used up (spec §12).
```

- [ ] **Step 2:** run the named test. Expect `ok`.

- [ ] **Step 3:** commit (see "How each task lands").

---

### Task v0-T244: pointers and the exit check

The umbrella moves the pointers once, and the exit check runs on the merged code.

**Files (in `yggdrasil`):**
- Modify: the submodule pointers of `gungnir`, `gleipnir`, `havamal`, `helheim-go`, `midgard-react` and `odin`;
  `docs/2-engineering/backlog.md`.

**Acceptance criteria:**
- [ ] After all six pull requests are merged, the pointers are at each repo's `main`, and `go.work` builds them
      together: `go vet ./...` and `go test ./...` pass in each repo with `go.work` and with `GOWORK=off`.
- [ ] The exit criterion: `go test -run 'TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents|TestARunOfTheToyRealms|TestAnUnattendedRunOfTheToyRealms' ./internal/cli`
      in `odin` passes on the merged code, in the umbrella, where the two realms are beside `odin` (it must not
      skip), and the founder's two runs happened: v0-H14 (the stacks build, the engine tests pass) and v0-H15 (the
      content smoke run, with the real ladder). Their output is in the pull request.
- [ ] The backlog gets B-042 (Vale prose rules in the docs rung), B-043 (the scripts both realms copy), B-044
      (packages in the images are not pinned), B-045 (TypeScript is held at 5.9 by `openapi-typescript`), B-046 (no
      initializer agent), B-047 (an implementer cannot read the project's design documents), each as **Open**, with
      the problem and the fix in a line; B-041's M-6 is widened to the snapshot sandbox's `snapshot/<node>` name;
      B-025 gets a note that the work container's DNS is now answered by the firewall; B-005, B-006, B-037 and B-039
      get a note and stay open.

**Named test:** `go test ./...` in each repo, and the evidence of v0-H14 and v0-H15. **Layer:** `yggdrasil`.
**Size:** S. **Depends on:** all above, merged.

- [ ] **Step 1:** switch each local copy to `main` and pull. Then, in `yggdrasil`:

```bash
git switch -c phase-5b/pointers
git submodule update --remote gungnir gleipnir havamal helheim-go midgard-react odin
git status --short
```

- [ ] **Step 2:** in `docs/2-engineering/backlog.md`, add the six items and the notes above.
- [ ] **Step 3:** run the exit check: `go vet ./... && go test ./...` in each of the six repos, with `go.work` and
      with `GOWORK=off`, and paste the output and v0-H14's and v0-H15's results into the PR body.
- [ ] **Step 4:** stage the pointers and the backlog by path, commit, push and open the pull request (see "How
      each task lands").

---

### Task v0-H14 (founder): the stacks build, and the engine tests pass

Phase 5b's two realms build their stack images on your engine, and the engine tests of Gleipnir pass. Both were
run for this plan on rootless Podman (see "Evidence"); this repeats them on the merged code. **Do this after
v0-T214 is merged, with the engine up (Phase 3's v0-H07).** `~/ygg-it/factory.yaml` needs a `realms:` section
whose `dir` is your `yggdrasil` folder.

**Named test:** the three engine tests below pass, and none is skipped. **Layer:** the founder's machine.
**Size:** S. **Depends on:** v0-T214 merged; Phase 3's v0-H07.

- [ ] **Step 1:** build both realms' stacks and pull the services' images (this takes a few minutes the first
      time: apt, Chromium, tools, the Go and Node bases):

```zsh
cd ~/yggdrasil/odin
export PATH="$HOME/ygg-it/dc/node_modules/.bin:$PATH"
go run ./cmd/ygg sandbox build --config ~/ygg-it/factory.yaml --realm midgard-react --realm helheim-go
```

Expect: `Building the stack localhost/ygg-stack-helheim-go:…`, `…-midgard-react:…` and `…-midgard-react-acceptance:…`,
three `Built:` pairs and two `Pulling the service image …` lines (Postgres and SeaweedFS).

- [ ] **Step 2:** pull a small image that serves when told to, by digest, and run the engine tests:

```zsh
podman --url unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock pull -q \
  docker.io/library/busybox:1.37.0@sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e
cd ~/yggdrasil/gleipnir
export YGG_SANDBOX_ENGINE=unix:///mnt/wsl/podman-sockets/podman-machine-default/podman-user.sock
export YGG_SANDBOX_TREE=$HOME/ygg-it YGG_SANDBOX_TREE_ENGINE=/mnt/wsl/ygg-bind
export YGG_SANDBOX_COMMAND_IMAGE=docker.io/library/busybox:1.37.0@sha256:bdf57e528e45e4433820e045b29b4597825a1c9e38353532d90a01445013f82e
go test -tags sandbox -count=1 -v -timeout 40m \
  -run 'TestSandboxBuildsARealmsStackAndStartsALeafOnIt|TestASandboxServiceTakesTheCommandItWasGiven|TestSandboxAnswersDNSForTheListedHostsAndTheServicesOnly' ./sandbox
```

Expect three `PASS` lines. A plain `podman pull` fails behind a gcloud credential helper; give it an empty auth
file (`echo '{}' > ~/empty-auth.json; export REGISTRY_AUTH_FILE=~/empty-auth.json`).

- [ ] **Step 3:** send back the output of both steps.

---

### Task v0-H15 (founder): the content smoke run on a real engine, with the real check ladder

The exit criterion with scripted agents, on your engine and with every command real: the real planning stages,
the real leaves, the real ladder (gofmt, golangci-lint, sqlc, oasdiff, govulncheck, OSV, Vitest, eslint, tsc, Prism,
Playwright with Chromium), the services, and the acceptance run on a snapshot. The scripted agents answer from
`odin/testdata/smoke-content/script.yaml` and cost nothing: the brief is two small tasks, the API says its version
and the web page shows it. **Do this after v0-T242 is merged and v0-H14 is done.**

**Named test:** the run ends `done` with exit code 0, two tasks done, none blocked. **Layer:** the founder's
machine. **Size:** S. **Depends on:** v0-T242 and v0-H14.

- [ ] **Step 1:** make the run's folder and config (the folder is under `~/ygg-it`, which the engine mounts):

```zsh
mkdir -p ~/ygg-it/content && ln -sfn ../dc ~/ygg-it/content/dc
cp ~/yggdrasil/odin/testdata/smoke-content/factory.example.yaml ~/ygg-it/content/factory.yaml
# edit it: replace /home/OPERATOR with your home, the engine and the mount as in ~/ygg-it/factory.yaml
: > ~/ygg-it/content/empty.env     # the script wants a credentials file; scripted agents use none
```

- [ ] **Step 2:** run it (the script builds the images first with `--build`; leave that out if v0-H14 just did):

```zsh
cd ~/yggdrasil/ouroboric/scripts
./ygg-smoke-realms.sh --folder ~/ygg-it/content --env ~/ygg-it/content/empty.env --realm midgard-react \
  --brief ~/yggdrasil/odin/testdata/smoke-content/brief.md --tag h15 --clip
```

Expect exit code 0 and a report in `~/ygg-it/content/h15-report.txt`: `docs_published` three times, a
`conformance_checked` line saying `no deviation`, `tasks_ready`, `repo_created` or the leaves' creation, and for each
of `version-t1` and `version-t2` a `check_result` for every rung of its ladder (`static`, `unit`, `tdd`, `contract`,
`security`, and `integration` for the API, `e2e` for the web app), `pointer_moved` twice, and `Run … is done.`
- [ ] **Step 3:** paste the report (`--clip` puts it on the clipboard) into the pull request of v0-T244. If a rung
      failed, send the report anyway: the log of the failing check is in
      `~/ygg-it/content/smoke-realms-*/.factory/runs/*/logs/`.

## Evidence

What was run while this plan was written, on 2026-10-17, on this machine (WSL2, Go 1.26.4; Go 1.26.9 through
`GOTOOLCHAIN`; rootless Podman 5.7.1 and the devcontainer CLI 0.89.0 for the real-engine runs).

**Tests.** `gofmt -l .` prints nothing, `go vet ./...` is clean, and `go test -race -count=1 ./...` passes in all
six repos on Go 1.26.4; `go test -count=1 ./...` passes in them on Go 1.26.9. The reference workspace builds the
repos together through a `go.work`; the siblings are pinned by the last commit of each pull request once its
siblings are merged, as in Phase 5a. The tests of the templates that need the network (`npm ci`, `go mod download`)
ran with it; without it they skip, unless `YGG_REQUIRE_TEMPLATES` is set.

**Each task alone.** `plan-states.sh` built and tested every task commit on its own: 39 of 39 pass, except
v0-T224 of `midgard-react`, which has no Go code at all (`go vet` and `go test` say "no packages", exit 1); its test is
Vitest, and it passed in `templates/web` (`npm ci`, `npx vitest run`, `tsc`, `eslint`).

**Each first failure.** `plan-red.sh` put each task's test files on the task's parent commit: the first failure of
each is the one its step shows. v0-T224's test is a Vitest file, so its first failure was got by hand, by deleting
`src/components/health-badge.tsx` and running `npx vitest run` (the entry is marked in `red-overrides.md` of the
reference). Tasks with none, and the plan says so: the documentation tasks (v0-T209, v0-T215, v0-T223, v0-T233,
v0-T243), which have no test; and v0-T214, whose tests are behind the `sandbox` tag and skip without an engine.

**The plan reproduces the code.** `plan-replay.py` applied the plan's steps to fresh clones of each repo at its
merge base: the trees are identical to the reference's, for all six repos (lock files and file modes aside: a lock
file is copied from the reference, and an executable script is marked `(executable)` in the plan).

**On a real engine** (rootless Podman, the devcontainer CLI, a bind mount for the shared folder):

- Both stacks were built from their Containerfiles with `ygg sandbox build`: `helheim-go`, `midgard-react` and its
  acceptance stage. Every `FROM` is a digest and every download is checked against a hash.
- Gleipnir's engine tests pass: a realm's stack is built and a leaf starts on it, the scratch folder holds one
  folder and nothing else, and the driver test passes. The four tests that need `YGG_SANDBOX_SERVICE_IMAGE` and
  `YGG_SANDBOX_SERVICE_PORT` skipped; the smoke run below used the services.
- The content smoke run (what v0-H15 repeats): `ygg-smoke-realms.sh --realm midgard-react` with the files of
  v0-T242, scripted agents, the real check ladder, both services and the acceptance run in the snapshot sandbox.
  The run ended `done`, exit 0, two tasks done and merged into `main`, the pointers moved, no task blocked, in a
  little over five minutes.
- What the real runs found, fixed in the tasks above: the firewall could not follow a host whose address rotates
  (the DNS answerer, v0-T213); `/go/pkg` was root-owned in the Go image; a leftover `vite preview` answered for a
  later run (the e2e scripts refuse a busy port); the contract check wanted identical copies and so an API-first
  task could not land (it is `oasdiff breaking` of the web copy against the API); `govulncheck` reported standard
  library vulnerabilities of Go 1.26.4 and 1.26.7 (the images use 1.26.9) and one of `x/text`; TypeScript is held at
  5.9 because `openapi-typescript` asks for it (B-045).

**Not run:** real model sessions (v0-H15 is with scripted agents; the real brief is Phase 5c), `reuse lint` and
CI (the executor runs them), and the four service tests of Gleipnir that need an image of their own.

**The defences each fail when removed.** For each row, the defence was removed from the code, the named test was
run, and it failed; then the code was restored. (`scripts/plan-defences.py` does it, from the rows in
`defences.json` of the SDD folder; an executor can run it again on the merged code.) Nine rows did not pass at first. Three showed tests that claimed more than they checked, and the tests were fixed:
a build folder outside the realm was refused only because it did not exist (v0-T205), a reviewer that is no scratch
agent was refused by the inputs rule (v0-T207), and the unit rung's test had no racy test (v0-T219). Six named a
line that another check covers, or a text that was not there, and the rows were changed.

| Task | Defence removed | Test that fails |
|---|---|---|
| v0-T205 | a build context holding a symlink is refused | `TestABuildContextIsRefusedWhenItCouldReachOutsideItself` |
| v0-T205 | a build context over its limits is refused | `TestABuildContextIsRefusedWhenItCouldReachOutsideItself` |
| v0-T205 | a build folder outside the realm is refused | `TestABuildContextIsRefusedWhenItCouldReachOutsideItself` |
| v0-T205 | the stage built is part of the tag | `TestATargetNamesAStageOfTheContextAndIsPartOfTheTag` |
| v0-T206 | a service command with a $ is refused | `TestAServiceMayNameItsCommandAsAnArgumentVector` |
| v0-T207 | only a scratch agent reviews another | `TestAReviewerAndTheDeviationItReportsAreRefusedWhenTheyPointAtNothingReal` |
| v0-T207 | only the spec gate reads a verdict | `TestAReviewerAndTheDeviationItReportsAreRefusedWhenTheyPointAtNothingReal` |
| v0-T208 | a deviation without an amendment is refused | `TestParseConformanceReadsAVerdictExactly` |
| v0-T211 | ADD in a Containerfile is refused | `TestBuildStackRefusesAContextItCouldNotBuildFromPinnedInputsOnly` |
| v0-T211 | a build never pulls | `TestBuildStackPullsTheBasesByDigestThenBuildsTheContextNeverPulling` |
| v0-T212 | the layers go on a built stack without pulling it | `TestBuildStartsFromABuiltStackWithoutPullingIt` |
| v0-T213 | the firewall answers DNS from its list only | `TestEgressAnswersDNSItselfForTheListedHostsAndTheServicesAndNothingElse` |
| v0-T213 | the work container's DNS goes to the firewall's answerer | `TestEgressAnswersDNSItselfForTheListedHostsAndTheServicesAndNothingElse` |
| v0-T213 | the firewall does not open without its DNS answerer | `TestEgressRefusesToOpenWhenItCannotAnswerDNS` |
| v0-T213 | a refresh gives the answerer the new addresses | `TestEgressAnswersWhatItAllowsAfterARefreshToo` |
| v0-T219 | /go/pkg is not left to root | `TestTheStackImageIsMadeOfPinnedInputsOnly` |
| v0-T219 | every download is checked against its SHA-256 | `TestTheStackImageIsMadeOfPinnedInputsOnly` |
| v0-T219 | an unformatted file stops the static rung | `TestStaticStopsAtTheFirstProblemAndSaysWhatToFix` |
| v0-T219 | the unit rung runs with the race detector | `TestUnitRunsEveryTestWithTheRaceDetectorAndNoCache` |
| v0-T220 | a new test that passes before the code exists is refused | `TestTDDWantsTheNewTestsToFailOnTheCommitTheTaskStartedFrom` |
| v0-T220 | Go code without a new test is refused | `TestTDDWantsTheNewTestsToFailOnTheCommitTheTaskStartedFrom` |
| v0-T221 | a vulnerable module stops the security rung | `TestSecurityStopsOnAVulnerabilityFromEitherSource` |
| v0-T221 | generated code that is not what the SQL says is refused | `TestContractLintsTheContractChecksGeneratedCodeAndListsBreakingChanges` |
| v0-T221 | a breaking change is listed as breaking | `TestContractLintsTheContractChecksGeneratedCodeAndListsBreakingChanges` |
| v0-T221 | the integration rung fails when Postgres does not answer | `TestIntegrationWaitsForPostgresAndRunsTheTaggedTestsWithItsAddress` |
| v0-T226 | a new test that passes before the code exists is refused | `TestTDDWantsTheNewTestsToFailOnTheCommitTheTaskStartedFrom` |
| v0-T227 | types that are not what the contract generates are refused | `TestContractChecksTheTypesAreWhatTheContractSaysAndListsChanges` |
| v0-T227 | a vulnerable package stops the security rung | `TestSecurityStopsOnAVulnerabilityFromEitherSource` |
| v0-T228 | an API that breaks its consumer copy fails acceptance | `TestAcceptanceChecksTheAPIKeepsWhatTheWebCopyPromisesThenRunsBothAgainstEachOther` |
| v0-T228 | a busy port stops the e2e rung | `TestE2EStartsAMockAndTheAppRunsPlaywrightAndStopsThem` |
| v0-T229 | every download is checked against its SHA-256 | `TestTheStackImagesAreMadeOfPinnedInputsOnly` |
| v0-T237 | a deviation stops the spec gate in every mode | `TestADeviationStopsTheSpecGateInEveryModeWithTheAmendment` |
| v0-T237 | a verdict nobody can read is asked for once more | `TestAVerdictNobodyCanReadIsAskedForOnceMoreAndThenStopsTheRun` |
| v0-T236 | the reviewer gets the output it reviews, as a copy | `TestAScratchReviewerFindsTheOutputOfTheAgentItReviewsAsACopy` |
| v0-T238 | a file two repos both hold is refused | `TestExportRefusesWhatCouldLeadOutOfTheSnapshot` |
| v0-T238 | a revision that is not HEAD or a full hash is refused | `TestExportTakesAReposFilesAtTheCommitItWasToldTo` |
| v0-T239 | two realms offering one service differently cannot share a sandbox | `TestRealmsThatDisagreeOnAServiceCannotShareASnapshotSandbox` |
| v0-T240 | acceptance checks run in the snapshot sandbox | `TestAcceptanceChecksRunInASandboxThatHoldsASnapshotOfTheProject` |

