---
title: Tasks for the gallery's product starting in the grader
status: accepted
date: 2026-10-22
related: [proposal.md, delta.md, ../../plans/2026-10-22-yggdrasil-v0-phase-6/tasks.md, ../../../3-using/operations/proof-runs.md, ../2026-10-18-repo-bootstrap/tasks.md, ../../realm-readiness.md]
style: spec
---

# Gallery runtime: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing test
> first. One pull request per repo, unless the order below says two; the founder merges. Tasks marked **founder** are
> done by the founder, never by an agent.

**Goal:** a product that the factory builds from the gallery brief starts in the grader of `client-gallery-lite`
4.1.0: `/app/start.sh`, the product start of the runtime realm `niflheim-local`, starts Postgres, SeaweedFS, the API
and the web leaf, with no network, and serves everything on port 3000 on all interfaces. And the proof runs give the
founder's product decisions to every later stage, and can reject a gate.

**Spec:** [proposal](proposal.md) and [delta](delta.md). Read both, and the proposal's questions first.

**Status:** accepted when the founder merged the pull request that added this file (yggdrasil#98). **Amended
2026-10-23:** the founder answered the questions, T01 is done, Niflheim owns the product start and the services, and
the rehearsal's three findings have tasks. Merging the amendment approves the new task list. No task waits for a
question now. The founder confirmed the open points on 2026-10-23: the names `needs`, `provides` and `runtime`, the
two needs, `DATA_DIR`, the reviewer's `reasoning: medium`, the service name `s3`, the web serving, and the early
submodule (T34).

## Global constraints

- The [Phase 6 plan's global constraints](../../plans/2026-10-22-yggdrasil-v0-phase-6/tasks.md) hold: worktrees,
  `as-bot.sh`, staging by path, `GOWORK=off go test -race ./...`, `reuse lint`, `shellcheck -s bash`, hermetic tests,
  no token.
- **The hidden suite.** No task reads, lists or searches `huldra`, its clone under `ouroboric-private`, or
  `~/ygg-it/hidden-suites`. No file of this change names a path inside it. A founder task may pass the suites folder
  to `ygg` by path, as the proof runs do. `task.toml` keeps `suite = "v2"`.
- **Images by digest.** SeaweedFS is `docker.io/chrislusf/seaweedfs:4.45@sha256:fc9f76fa993ad69966ffeb2f65d0318fcae39c6f8e20cf68ef7b3a5cb97769e5`,
  the digest `helheim-go/pack.yaml` pins today and `niflheim-local/pack.yaml` pins after T11. Postgres is
  `docker.io/library/postgres:18.x-<debian>@sha256:…`, taken from the registry in T11 and at least two weeks old
  (RR-13). The task image's base stays
  `mcr.microsoft.com/playwright:v1.63.0-noble@sha256:eff16c30e6f3f4af0a03fa4b706120d5e9b0891c344a27d64559aff5900a4a27`.
- **Commit messages** end with the task id, as `(gallery-runtime-T05)`, and with the session's attribution lines.
- **No task changes** `instruction.md`, the brief hash, a hidden suite, `features.json`, a ledger or a run report.
- **The founder's five product decisions** are product input for the proof runs (proposal, "The founder's product
  decisions"). No task builds them into a realm, a prompt or a test of the factory; T32 puts their text in the
  runbook.

## Order and pull requests

| Task | Repo | Size | Depends on | Was |
| --- | --- | --- | --- | --- |
| T01 (founder) the planning rehearsal, kept: **done 2026-10-23** | the founder's machine | S | none | T01 |
| T02 (founder) create `niflheim-local` | GitHub, with `ouroboric/scripts/new-repo.sh` | S | the amendment merged | new |
| T03 the realm's scaffold | `niflheim-local` | M, about 150 lines | T02 | new |
| T34 `niflheim-local` as a submodule, early | `yggdrasil` | S, about 10 lines | T03 merged | new |
| T04 the pack's `product.start` | `gungnir` | S, about 90 lines | none | T03 |
| T05 the pack's `needs` and `provides` | `gungnir` | M, about 220 lines | T04 | new |
| T06 the runtime pin in the leaves file and the umbrella | `gungnir` | M, about 180 lines | none | new |
| T07 the runtime realm joins the run, and `ready` checks the needs | `odin` | M, about 340 lines | T04 to T06 merged | new |
| T08 one function gives a leaf's services; the sandboxes, the sandbox build and the wiring use it | `odin` | M, about 330 lines | T07 | new |
| T09 the dependency policy's sandbox on the same function | `odin` | M, about 150 lines | T08 | new |
| T10 `init` writes the product start | `odin` | M, about 200 lines | T07 | T11 |
| T11 the services, Postgres 18 and SeaweedFS 4.45, and what they provide (with founder steps) | `niflheim-local` | M, about 200 lines | T03 merged, T05 merged | T04 (Postgres 18) |
| T12 the product start script | `niflheim-local` | M, about 330 lines | T04 merged, T11 | T08, T09 |
| T13 the API on `HOST` and the runtime names | `helheim-go` | M, about 150 lines | none | T04 |
| T14 the pack declares needs, and names no service | `helheim-go` | M, about 180 lines | T05 merged, T07 to T10 merged, T11 merged | new |
| T15 the API's release | `helheim-go` | M, about 120 lines | T13 | T05 |
| T16 the web leaf's server, on `HOST` | `midgard-react` | M, about 300 lines | none | T06 |
| T17 the web leaf's release | `midgard-react` | M, about 150 lines | T16 | T07 |
| T18 the acceptance run on the new contract, and the store flag for specs | `midgard-react` | M, about 330 lines | T13, T16 | T10 |
| T19 the prompts name the runtime and the runtime pin | `voluspa` | M, about 120 lines | T06 merged, T07 merged | T14 |
| T20 the conformance review gets 20 minutes (F2) | `voluspa` | S, about 30 lines | none | new |
| T21 (founder) `client-gallery-lite` 4.1.0, on Niflheim's versions | `mimir` | S, about 50 lines | T11 merged | T02 |
| T22 the release in the export | `odin` | M, about 300 lines | none | T12 |
| T23 the release built in the acceptance sandbox | `odin` | M, about 250 lines | T22 | T13 |
| T24 an approval's note reaches later stages (F1) | `odin` | M, about 280 lines | none | new |
| T25 the real-realm fixtures pin the runtime | `odin` | S, about 60 lines | T07, T14 merged, T11 merged | new |
| T26 the runtime smoke script | `ouroboric` | M, about 300 lines | T12, T15, T17 | T15 |
| T27 the services check, and `niflheim-local` in the lists | `ouroboric` | M, about 200 lines | T11, T14, T21 | new |
| T28 the reviewer's reasoning effort in the proof config (F2) | `ouroboric` | S, about 90 lines | none | new |
| T29 `ygg-proof-run.sh --reject` (F3) | `ouroboric` | M, about 180 lines | T28 | new |
| T30 (founder) the runtime smoke on the real engine | the founder's machine | S | T21, and T03 to T29 and T34 merged | T16 |
| T31 fold the delta, the checklist and the backlog | `yggdrasil` | M, about 250 lines | T30 | T17 |
| T32 the runbook: the founder's decisions, `--reject`, 4.1.0 | `yggdrasil` | M, about 120 lines | T21, T24, T28, T29 merged | new |
| T33 `niflheim-local`'s readiness record, and the pointers | `yggdrasil` | M, about 180 lines | T30, T31, T32, T34 | T17 |

Old T08 (`midgard-react`'s pack names the product start) is gone: the product start is `niflheim-local`'s (T12).

The pull requests, each from a branch `gallery-runtime` made from `main`:

1. `niflheim-local`, first pull request: T03, the scaffold, once the founder has made the repo (T02). It needs no
   other pull request and may merge at any time before `niflheim-local`'s second. Right after it, `yggdrasil`'s first
   pull request: T34, the submodule at T03's merge. It adds a pointer and moves none.
2. `ouroboric`, first pull request: T28, T29, on one branch, in this order (they change the same script). They depend
   on nothing, so F2 and F3 can reach the proof runs early; it may merge at any time.
3. `gungnir`: T04, T05, T06. It merges first of the code that the realms pin.
4. `odin`, first pull request: T07, T08, T09, T10, with the merged `gungnir` pinned. It merges before `helheim-go`'s
   and `voluspa`'s, because `gungnir`'s schemas refuse unknown keys: an `odin` on the old pin cannot load a
   `helheim-go` whose `pack.yaml` names `needs`, or a leaves file that names `runtime`; and an `odin` that does not
   resolve needs would start a `helheim-go` leaf, or run its dependency policy, with no services.
5. The repos that pin the new `gungnir`, and the others, in any order once their dependencies have merged:
   `niflheim-local`, second pull request: T11, T12 (after `gungnir`; T11's workflow is pushed by the founder). Like
   every task, they work in a worktree of the repo; their local `check-repos.sh` runs read the top-level clone of T03
   until T27 merges, and the submodule after.
   `helheim-go`: T13, T14, T15 (after `odin`'s first; T14 needs T11 merged too). `midgard-react`: T16, T17, T18 (no
   new `gungnir`). `voluspa`: T19, T20 (after `odin`'s first). `mimir`: T21, by the founder, after T11.
6. `odin`, second pull request: T22, T23, T24, T25 (T25 after `helheim-go`'s and `niflheim-local`'s second merge).
7. `ouroboric`, second pull request: T26, T27.
8. T30, the founder's smoke, on the merged `main` of every repo.
9. `yggdrasil`, second pull request: T31, T32, T33, after T30. It moves the pointers, `niflheim-local`'s among them.

The umbrella's pointers do not move until T33, except the new `niflheim-local` pointer that T34 adds. T30 checks out each repo at its merged `main` and builds `ygg` from
that `odin`. Run 1 (v0-H20 of the Phase 6 plan) waits for T33.

---

### Task gallery-runtime-T01 (founder): the planning rehearsal, kept

**Done 2026-10-23.** v0-H19 ran, but nothing of it was recorded. This task ran it again, checked the proposal's
assumptions against what the planner designed, and kept the answers. It ran on today's prompts, before T19 makes them
name the runtime.

**Files:** none in a repo. The answers are in this amendment, as aggregate facts, not transcripts. The evidence (the
design doc, the spec, the plan's tasks, the gate files and the ledger) is on the founder's machine.

- [x] **Step 1:** do the dry run, then start the rehearsal (see
  [proof runs](../../../3-using/operations/proof-runs.md#the-rehearsal)):

  ```zsh
  cd ~/brunogbv/ouroboric/ouroboric
  scripts/ygg-proof-run.sh --name rehearsal --mode step-by-step --dry-run
  scripts/ygg-proof-run.sh --name rehearsal --mode step-by-step --build
  ```

- [x] **Step 2:** at the design stop, read `PROJECT/.factory/runs/RUN/gates/design-1.md` and the design doc. Approve
  it. At the spec stop, read `spec-1.md`, the spec and `docs/leaves.yaml`. Approve it. **Do not approve
  `plan-gate`.** The run ends there with exit 3.
- [x] **Step 3:** check the four assumptions of the proposal, each yes or no, with the file and section that says so:
  1. two leaves, `repos/web` on `midgard-react` and `repos/api` on `helheim-go`;
  2. the API keeps its data in Postgres;
  3. the photos live in an S3-compatible store, through presigned URLs, and their bytes do not pass through the API;
  4. no other service at run time.

  Also note what the design says about `start.sh` and port 3000, the number of tasks and their sizes, and what the
  conformance and reuse reviewers found.
- [x] **Step 4:** keep the run folder until T33 merges. Write the answers, with `ygg metrics` and `ygg report` of the
  run, on this change's pull request (here: this amendment).
- [x] **Step 5:** act on the first row that applies:

| What the design does | What to do |
| --- | --- |
| All four hold, and the plan has its own `start.sh` or a port-3000 task | Expected on today's prompts; not a stop. Note it, and go on with T02 to T33. T19 tells the planner, and run 1 is the first plan made with the new prompts |
| All four hold | Go on with T02 to T33 |
| Two leaves on the right realms, at other paths (`repos/frontend`, `repos/server`) | Stop. The spec prompt's rule on paths was broken, and the product start finds the leaves only at `repos/web` and `repos/api`. Fix the prompt in T19 first, then run the rehearsal again; or amend this proposal so that the product start reads the paths |
| A third leaf (a worker on `helheim-go`, say) | Stop. The product start starts only `repos/api` and `repos/web`. Amend this proposal (T12 starts every leaf it finds), or tell the planner in T19 that the gallery has two leaves |
| Two leaves, but another store (photos on disk through the API, SQLite) | Stop. Decide whether the realms' rules (spec §9.3) or the design win. Amend this proposal before T21: the image's services and the storage forward may change |
| One leaf, or one process for the whole product | Stop. The planner left the realms' design. Answer question 10 again (option B or C), and replace this change |
| Another service at run time (a queue, a cache, a mail server) | Stop. Amend this proposal: the image gains the service, or the planner is told not to use it |
| A leaf on a realm other than these two | Stop. The planner broke the spec prompt's rule; file it, and run the rehearsal again after the prompt is fixed |

**The result (2026-10-23).** Run `20261022-205939-1301d4`, proof folder `proof-rehearsal-20261022-225838`, stopped at
`plan-gate` with exit 3 and kept. The first row applies: go on.

- The four assumptions hold: two leaves, `repos/api` (`helheim-go`) and `repos/web` (`midgard-react`, consuming the
  API) in `docs/leaves.yaml`; Postgres and an S3-compatible store in the spec; `/app/start.sh` starts everything; the
  web server on port 3000 forwards `/api/*`. No other service.
- The plan: 29 tasks, 17 in `repos/api` and 12 in `repos/web` by their Layer field; 23 of size M, 6 of size S. Its
  T001 puts `/app/start.sh` in `repos/api`, and the leaves file says that the API also serves the built web app: both
  expected on today's prompts, and T19 rules them out.
- The spec put the data and the reset outbox under `/app/data/`; question 4 names `/app/.data/`.
- The reuse reviewer found the plan lean, with two small changes. The conformance reviewer reported the founder's
  five decisions as deviations of the spec from the design, as expected (F1).
- Cost: 55 turns to `plan-gate`, $2.52 at API prices; billed, the reviewer's Qwen sessions, cents.
- Three findings: F1 (T24), F2 (T20, T28), F3 (T29). See the proposal.

**Acceptance criteria:**

- [x] The run stopped at `plan-gate` with exit 3, and its folder is kept.
- [x] The four assumptions are answered with the file that shows each answer, on the pull request.
- [x] No row said stop.

**Named test:** the run's exit 3 at `plan-gate`, and the four answers checked against the gate files.
**Layer:** the founder's machine. **Size:** S. **Depends on:** none (`ygg-proof-run.sh`, v0-T291, is merged).

### Task gallery-runtime-T02 (founder): create `niflheim-local`

Only the founder runs `new-repo.sh` (`ouroboric/AGENTS.md`). The repo is the Niflheim realm's `local` flavor: one
machine, no cloud.

**Files:** none in a repo of this tree. The repo gets `new-repo.sh`'s first commit: `README.md`, the licences and the
base CI.

- [ ] **Step 1: the failing check.** `scripts/as-bot.sh --read all scripts/check-repos.sh --check settings --check
  security --check ruleset niflheim-local` fails: the repo does not exist.
- [ ] **Step 2:** with the short-lived admin token that `new-repo.sh`'s header names, read without echo so it is
  never printed or kept in the history:

  ```zsh
  cd ~/brunogbv/ouroboric/ouroboric
  read -rs 'GH_TOKEN?admin token: ' && export GH_TOKEN
  scripts/new-repo.sh --org ouroboric-dev niflheim-local "The Niflheim realm's local flavor: the services a product runs on and its start script, for one machine with no cloud."
  unset GH_TOKEN
  ```

- [ ] **Step 3:** add the repo to the pr-bot's installation, as the after-create message says.
- [ ] **Step 4:** run the check of step 1 again, and `scripts/as-bot.sh niflheim-local git ls-remote
  https://github.com/ouroboric-dev/niflheim-local`.

**Acceptance criteria:**

- [ ] `niflheim-local` exists in `ouroboric-dev`, public, with `new-repo.sh`'s first commit on `main`, protected.
- [ ] The check of step 1 exits 0 (RR-01), and the pr-bot can read the repo.

**Named test:** `check-repos.sh --check settings --check security --check ruleset niflheim-local` (red before step 2,
green after). **Layer:** GitHub (`ouroboric/scripts/new-repo.sh`, the founder's machine). **Size:** S.
**Depends on:** this amendment merged.

### Task gallery-runtime-T03: the realm's scaffold

The first pull request of `niflheim-local`, like the first of `helheim-go` (realm-leaf-naming-T002) and of every
component: the scaffold, then the content in a second pull request.

**Files (in `niflheim-local`):**

- Create, with `ouroboric/scripts/scaffold-component.sh --mit-templates niflheim-local "<job sentence>" <clone>`:
  `go.mod`, the README's sections, `AGENTS.md`, `docs/architecture.md`, `.devcontainer/devcontainer.json`,
  `.gitignore`, `templates/README.md`, `LICENSES/MIT.txt` and the `templates/**` annotation in `REUSE.toml`
- Modify by hand: `docs/architecture.md` (Responsibilities and Depends on, from this change), `AGENTS.md` (a "This
  repo" list, as `helheim-go`'s)

The job sentence: "The Niflheim realm's local flavor: the services a product runs on and its start script, for one
machine with no cloud."

- [ ] **Step 1: the failing check.** In a clone made through `as-bot.sh` at `~/brunogbv/ouroboric/niflheim-local`,
  the top level, `check-repos.sh --check agents niflheim-local` and the docs check fail: there is no `AGENTS.md` and
  no `docs/architecture.md`. The clone goes there because `check-repos.sh` looks there for a repo that is not in its
  `LEAVES` list (`local_path`); T27 adds the repo to `LEAVES`, after T34 has made the submodule
  `yggdrasil/niflheim-local`, where the script looks from then on.
- [ ] **Step 2:** run the scaffold. Write the architecture doc's two sections: it is a runtime realm (delta §9.4); it
  provides the services of the build realms' needs and the product start; it depends on `gungnir` for the pack schema
  and on Odin to read it; it has no stack, template or ladder.
- [ ] **Step 3:** run `GOWORK=off go vet ./...`, `reuse lint`, the docs check, and
  `bash ../ouroboric/scripts/tests/scaffold-component.test.sh`. Expected: pass. Until T27, `check-repos.sh --check
  agents` says only "present" for a repo outside `LEAVES`, so check its leaf rule by hand: `AGENTS.md` has at most
  120 lines, no `## Invariants` section, and links `ouroboric-dev/yggdrasil/blob/main/AGENTS.md#invariants` (the
  scaffold's template does all three).

**Acceptance criteria:**

- [ ] The scaffold's files are there, and none of `new-repo.sh`'s first commit was overwritten.
- [ ] `reuse lint` passes, with MIT on `templates/**` (RR-02); `AGENTS.md` carries the umbrella's invariants and
  meets the leaf rule of `check_agents` (RR-05); the docs check passes (RR-07).

**Named test:** `check-repos.sh --check reuse --check agents --check gitleaks niflheim-local` and the docs check (red
in step 1, green in step 3). **Layer:** `niflheim-local`. **Size:** M, about 150 lines. **Depends on:** T02.

### Task gallery-runtime-T04: the pack's `product.start`

**Files (in `gungnir`):**

- Modify: `schema/pack.go` (`Pack.Product *PackProduct`, `PackProduct.Start string`), `schema/pack.schema.json`
- Create: `schema/pack_product_test.go`

**Interfaces:**

- Produces: `Pack.Product.Start`, a path relative to the pack, which T12 sets and T10 reads.

- [ ] **Step 1: the failing test.** `TestPackProductStart`: a pack with `product: {start: templates/product/start.sh}`
  loads, and `Product.Start` holds the path; a pack with no `product` loads with `Product` nil; an absolute path, a
  path with `..`, an empty `start` and an unknown key under `product` are each refused with the field in the message.
  Run `go test -run TestPackProductStart ./schema/`. Expected: FAIL (the field is unknown).
- [ ] **Step 2:** add the field and its schema. A pack whose `product.start` names a file that is not in the pack is
  refused where the pack's other paths are checked (`AcceptanceRef` is the model).
- [ ] **Step 3:** run the test, then `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] `TestPackProductStart` passes, and fails when the schema's check of the path is taken out.
- [ ] Every pack in the repos' testdata still loads.

**Named test:** `gungnir/schema/pack_product_test.go:TestPackProductStart`.
**Layer:** `gungnir`. **Size:** S, about 90 lines. **Depends on:** none (T01 is done).

### Task gallery-runtime-T05: the pack's `needs` and `provides`

A build realm says what it needs; a runtime realm says what it provides (delta §9.4; the names are the founder's, 2026-10-23).

**Files (in `gungnir`):**

- Create: `needs.go` (`Needs`, the list: `postgres`, "a Postgres-compatible database"; `s3`, "an S3 API"; and
  `ValidNeed`), `schema/pack_needs_test.go`
- Modify: `schema/pack.go` (`Pack.Needs []string`, `Pack.Provides map[string]string`, `Pack.Provider(need)`),
  `schema/pack.schema.json`, `docs/architecture.md`

**Interfaces:**

- Produces: `gungnir.Needs`, `Pack.Needs`, `Pack.Provides` and `Pack.Provider(need string) (gungnir.Service, bool)`,
  which T07, T08, T11 and T14 use.

- [ ] **Step 1: the failing test.** `TestPackNeedsAndProvides`:
  - a pack with `needs: [postgres, s3]` loads, and `Needs` holds both; a need that is not in `gungnir.Needs`, and a
    need named twice, are each refused with the need in the message;
  - a pack with `services` `postgres` and `s3` and `provides: {postgres: postgres, s3: s3}` loads, and
    `Provider("s3")` returns the `s3` service; `provides` that names a service the pack does not define, or a
    need not in `gungnir.Needs`, is refused;
  - a pack that names `leaf` and `provides`, or `leaf` and `product` (T04), is refused: "a runtime realm provides no
    leaf";
  - every pack in the repos' testdata still loads.

  Expected: FAIL.
- [ ] **Step 2:** add the fields, the schema (`needs`: an array of unique names; `provides`: an object from a need to
  a service name) and the checks in `checkRecipe`.
- [ ] **Step 3:** run the test, then `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] `TestPackNeedsAndProvides` passes, and each refusal fails when its check is taken out.
- [ ] A pack that names neither field loads as before.

**Named test:** `gungnir/schema/pack_needs_test.go:TestPackNeedsAndProvides`.
**Layer:** `gungnir`. **Size:** M, about 220 lines. **Depends on:** T04 (the same files, on the same branch).

### Task gallery-runtime-T06: the runtime pin in the leaves file and the umbrella

A project pins one runtime realm, beside its graph pin (delta §9.4; the names are the founder's, 2026-10-23).

**Files (in `gungnir`):**

- Modify: `schema/leaves.go` (`Leaves.Runtime *RuntimePin`, with `Realm` and `RealmVersion`),
  `schema/leaves.schema.json`, `schema/umbrella.go` (`Umbrella.Runtime`, `Umbrella.RuntimeVersion`,
  `Umbrella.RuntimePin() (Pin, bool)`), `schema/umbrella.schema.json`, `docs/architecture.md`
- Create: `schema/runtime_pin_test.go`

**Interfaces:**

- Produces: the runtime pin in both files, which T07 reads and records and T19's prompt asks the spec stage to write.

- [ ] **Step 1: the failing test.** `TestRuntimePin`:
  - a leaves file with `runtime: {realm: niflheim-local, realm_version: 0.1.0}` parses; one with a realm and no
    version, or a name that is not a realm name, is refused with `runtime` in the message; one with no `runtime`
    parses with `Runtime` nil;
  - an umbrella with `runtime: niflheim-local` and `runtime_version: 0.1.0` loads, and `RuntimePin()` returns it with
    `Where` set to `runtime`; one of the two without the other is refused, as for the graph pin;
  - `Pins()` still returns the leaves' pins only, and the top-level `realm` is still refused (change voluspa).

  Expected: FAIL.
- [ ] **Step 2:** add the fields and the checks, after `checkGraphPin`'s model.
- [ ] **Step 3:** run the test, then `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] `TestRuntimePin` passes; every umbrella and leaves file in the repos' testdata still loads.

**Named test:** `gungnir/schema/runtime_pin_test.go:TestRuntimePin`.
**Layer:** `gungnir`. **Size:** M, about 180 lines. **Depends on:** none.

### Task gallery-runtime-T07: the runtime realm joins the run, and `ready` checks the needs

**Files (in `odin`):**

- Modify: `go.mod` and `go.sum` (the merged `gungnir`), `internal/run/run.go` (`collectRealms` loads the umbrella's
  runtime pin; `Setup.Runtime`), `internal/engine/init.go` (the leaves file's `runtime`: loaded with `AddRealms` and
  recorded in `umbrella.yaml`), `internal/run/prepare.go` (`CheckNeeds`), `internal/engine/stages.go` (`runTasks`, the
  `ready` node, checks the needs of the leaves file it reads), `docs/architecture.md`
- Create: `internal/run/runtime_test.go`, `internal/engine/init_runtime_test.go`, `internal/engine/ready_needs_test.go`

**Interfaces:**

- Consumes: T05's `Pack.Needs` and `Pack.Provider`, T06's pins.
- Produces: `Setup.Runtime *realm.Realm` (nil when the project pins none) and `Setup.CheckNeeds(extra []*realm.Realm)
  error`, which T08, T09 and T10 use.

- [ ] **Step 1: the failing tests.**
  - `TestRuntimeRealmIsLoaded` in `runtime_test.go`: a project whose umbrella pins `runtime` gets that realm in
    `Setup.Runtime`, recorded in `run.json` and in a `realm_loaded` event; a pin the realm store does not hold fails
    before anything is created, as a leaf's pin does.
  - `TestInitRecordsTheRuntimePin` in `init_runtime_test.go`: a leaves file with `runtime` makes `init` load the realm
    and write `runtime` and `runtime_version` into `umbrella.yaml`, in the commit that records the leaves; a resumed
    `init` adds no commit; a leaves file whose `runtime` differs from the one the umbrella records is refused, with
    both pins named.
  - `TestNeedsWithoutAProviderStop`: a leaf realm that needs `postgres` and `s3`, in a project with no runtime realm,
    stops `init` before it creates a leaf, with a message that names the need, the realm and `runtime` in
    `docs/leaves.yaml`; a runtime realm that provides only `postgres` stops it naming `s3`; a runtime pin that names a
    build realm (one with `leaf`) is refused.
  - `TestReadyStopsOnAnUnmetNeed` in `ready_needs_test.go`: in `software`'s order (`ready` reads `docs/leaves.yaml`
    and runs before `leaves` and `plan-gate`), a leaves file whose realms need `postgres` and `s3` and that names no
    `runtime` fails the `ready` node with the same message, before `init` runs; it is not sent back to the planner
    (`back_to`), because the plan cannot fix the leaves file. A leaves file with the runtime pin passes.

  Expected: FAIL.
- [ ] **Step 2:** implement it. `CheckNeeds` runs where `CheckAcceptance` runs: at prepare for the leaves the project
  has, and in `init` for the realms it is about to add; and in `ready`, for the realms of the leaves file the node
  names. So a forgotten pin is found before any leaf or leaf sandbox exists, though after the plan's sessions.
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The four tests pass. A project with no runtime pin and no needs runs as today.
- [ ] `odin` pins the merged `gungnir`, so it loads packs that name `needs`, `provides` and `product`.

**Named test:** `odin/internal/run/runtime_test.go:TestRuntimeRealmIsLoaded`, `TestNeedsWithoutAProviderStop`;
`odin/internal/engine/init_runtime_test.go:TestInitRecordsTheRuntimePin`;
`odin/internal/engine/ready_needs_test.go:TestReadyStopsOnAnUnmetNeed`.
**Layer:** `odin`. **Size:** M, about 340 lines. **Depends on:** T04 to T06 merged.

### Task gallery-runtime-T08: one function gives a leaf's services; the sandboxes, the sandbox build and the wiring use it

`ygg deps` has no `run.Setup`: it loads the leaf's realm itself (`odin/internal/cli/deps.go`, `depsProduct`) and
starts the sandbox with that realm's `Pack.ServiceList()` (`depsOpener.Open`). So the resolution of needs must not
live on `Setup`. This task writes it once, with no `Setup`, and moves the run's two callers onto it; T09 moves `ygg
deps`. Split from one task because the two together come near 480 lines.

**Files (in `odin`):**

- Create: `internal/services/services.go` (`services.For(u *schema.Umbrella, repos []string, l Loader)
  ([]gungnir.Service, error)` and `Loader`, with `Leaf(repo string) (*realm.Realm, error)` and `Runtime()
  (*realm.Realm, error)`), `internal/services/services_test.go`
- Modify: `internal/run/prepare.go` (`SandboxFor` and `SnapshotSandbox` call `services.For`, with a `Loader` made from
  the run's realms; `serviceSet` moves to the new package), `internal/cli/sandbox.go` (`stacksToBuild` with `--all`
  keeps the service images of a realm that names no stack, the runtime realm, instead of skipping them),
  `internal/routing/wiring.go` (a `needs` edge for each need of a leaf's realm, to the provider's service name),
  the routing fixtures that name the store's service `seaweedfs` (`internal/routing/wiring_test.go`'s `helheim-go`
  pack, `testdata/routing/wiring.golden.md`, `testdata/routing/impact.golden.json`, `testdata/routing/bench.yaml`:
  they become a realm that needs `s3` and a provider named `s3`), `docs/architecture.md`

**Interfaces:**

- Produces: `services.For` and `services.Loader`, which T09 uses for `ygg deps`.

- [ ] **Step 1: the failing tests.**
  - `TestForGivesTheProvidersOfTheNeeds` in `services_test.go`, with a stand-in `Loader`: for a leaf whose realm needs
    `postgres` and `s3`, `For` returns the runtime realm's `postgres` and `s3` services, under those names, with
    their image, env, ports and command; for the leaf and a web leaf that consumes it, the same, once each; for a leaf
    whose realm needs nothing, none; a need with no runtime realm, or one the runtime realm does not provide, is an
    error that names the need and the realm.
  - `TestForKeepsARealmsOwnServices`: a realm that still names services (an older pack) gets them as today, and a
    service of the same name that differs from the runtime realm's is refused, naming both realms.
  - `TestLeafSandboxGetsTheProvidersOfItsNeeds` in `internal/run/needs_test.go`: `SandboxFor` gives a leaf what `For`
    gives; `TestSnapshotSandboxGetsTheProvidersOfEveryLeafsNeeds`: `SnapshotSandbox` gives the services of every need
    of every leaf realm of the project, once each.
  - `TestSandboxBuildPullsTheRuntimesServices` in `internal/cli/sandbox_test.go`: the images `stacksToBuild` returns
    with `--all` hold the runtime realm's services, and the realm is still listed as having no stack.
  - `TestWiringNeedsEdges` in `internal/routing/wiring_test.go`: a leaf of a realm that needs `postgres` and `s3` has
    `needs` edges to `service:postgres` and `service:s3`, the provider's service names (the wiring names
    services by name today, `wiring.go`'s `needs` edge), from the realm's `pack.yaml`. The wiring gets the
    provider's names from `services.For`, never from the leaf realms' packs alone.

  Expected: FAIL.
- [ ] **Step 2:** implement it. `For` never reads the run's state, so the run and `ygg deps` cannot disagree.
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS, with the existing
  `snapshot_sandbox_test.go` tests.

**Acceptance criteria:**

- [ ] The six tests pass. A sandbox never starts a service that neither the leaf's realm nor the runtime realm names.

**Named test:** `odin/internal/services/services_test.go:TestForGivesTheProvidersOfTheNeeds`,
`TestForKeepsARealmsOwnServices`; `odin/internal/run/needs_test.go:TestLeafSandboxGetsTheProvidersOfItsNeeds`,
`TestSnapshotSandboxGetsTheProvidersOfEveryLeafsNeeds`; `odin/internal/cli/sandbox_test.go:TestSandboxBuildPullsTheRuntimesServices`;
`odin/internal/routing/wiring_test.go:TestWiringNeedsEdges`.
**Layer:** `odin`. **Size:** M, about 330 lines. **Depends on:** T07.

### Task gallery-runtime-T09: the dependency policy's sandbox on the same function

After T14, `helheim-go` names no service, so `ygg deps` on an API leaf would start its sandbox with no Postgres: the
dependency policy's integration rung would fail.

**Files (in `odin`):**

- Modify: `internal/cli/deps.go` (`depsProduct` also loads the umbrella's runtime pin from the realm store, and the
  leaves the leaf consumes; `depsOpener.Open` takes its services from `services.For`), `docs/architecture.md`
- Modify: `internal/cli/deps_test.go`

- [ ] **Step 1: the failing tests,** in `deps_test.go`, with the stand-in engine the deps tests use:
  - `TestDepsSandboxGetsTheRuntimesServices`: a project whose umbrella pins `runtime: niflheim-local`, with an API leaf
    whose realm needs `postgres` and `s3`: the sandbox spec `ygg deps` starts holds the runtime realm's `postgres` and
    `s3` services;
  - `TestDepsRefusesAnUnmetNeed`: the same project with no runtime pin fails before any sandbox starts, with the
    message of `services.For`;
  - a leaf whose realm needs nothing starts with no service, as today.

  Expected: FAIL.
- [ ] **Step 2:** implement it. The `Loader` of `ygg deps` reads the umbrella's pins and the realm store
  (`realm.Store.Find`, `realm.Load`), as `depsProduct` does for the leaf's realm today.
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] `ygg deps` starts a leaf's sandbox with the services the run would give it.

**Named test:** `odin/internal/cli/deps_test.go:TestDepsSandboxGetsTheRuntimesServices`, `TestDepsRefusesAnUnmetNeed`.
**Layer:** `odin`. **Size:** M, about 150 lines. **Depends on:** T08.

### Task gallery-runtime-T10: `init` writes the product start

**Files (in `odin`):**

- Modify: `internal/engine/init.go` (after `ignoreFactory`), `docs/architecture.md`
- Create: `internal/engine/init_product_test.go`

**Interfaces:**

- Consumes: `Setup.Runtime` (T07) and its `Pack.Product.Start` (T04).

- [ ] **Step 1: the failing tests.** `TestInitWritesProductStart`, on a project whose runtime realm names
  `product.start`:
  - `start.sh` is at the project root, mode `0755`, byte for byte the runtime realm's file, in a commit of its own;
  - the project's `.gitignore` holds `.data/`;
  - a resumed `init` adds no commit;
  - a project whose `start.sh` differs from the realm's gets the realm's in a new commit that says so;
  - a project with no runtime realm, or whose runtime realm names no product start, keeps its own `start.sh`
    untouched (the grade smoke has one);
  - a runtime realm whose start script is missing from its folder makes `init` fail before it creates a leaf.

  Expected: FAIL.
- [ ] **Step 2:** implement it after `ignoreFactory`'s model. Write the mode, which first-commit files lose (B-128).
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The six cases pass.

**Named test:** `odin/internal/engine/init_product_test.go:TestInitWritesProductStart`.
**Layer:** `odin`. **Size:** M, about 200 lines. **Depends on:** T07.

### Task gallery-runtime-T11: the services, Postgres 18 and SeaweedFS 4.45, and what they provide

It moves the services out of `helheim-go` (B-158) and pins Postgres 18 (question 5).

**Files (in `niflheim-local`):**

- Create: `pack.yaml`, `pack_test.go`, `.github/workflows/ci.yml` (a job `test` that runs `go test -race ./...`, as
  `helheim-go`'s does)
- Modify: `go.mod` and `go.sum` (the merged `gungnir`), `README.md` and `docs/architecture.md` (what the realm holds)

**Interfaces:**

- Produces: the services `postgres` and `s3` and `provides: {postgres: postgres, s3: s3}`, which T08
  starts in a sandbox, T14 copies into `helheim-go`'s template CI, T21 follows in the grader image and T27 compares.

- [ ] **Step 1: the failing tests.**
  - `TestThePackProvidesTheNeeds`: the pack loads with the merged `gungnir`; it is named `niflheim-local`, at 0.1.0,
    with no `leaf`, `sandbox`, `graph` or `checks`; it provides every need of `gungnir.Needs`; the `postgres` service
    has port 5432, `POSTGRES_DB: app` and `POSTGRES_HOST_AUTH_METHOD: trust`, and the `s3` service (the SeaweedFS image) port 8333 and
    the command `[server, -s3, -dir=/data]`: the contract of delta §9.4, the values `helheim-go`'s pack holds today
    for its `seaweedfs` service, under the name `s3`;
    every image is pinned by digest.
  - `TestPackPostgresIsEighteen`: the `postgres` image matches `postgres:18\.\d+-\S+@sha256:[0-9a-f]{64}`.
  - `TestPackSeaweedFSIsTheGraderImages`: the `s3` service's image is the SeaweedFS digest of the global constraints.

  Expected: FAIL (no `pack.yaml`).
- [ ] **Step 2:** write `pack.yaml`. Take the current `postgres:18.x-bookworm` (or the current Debian variant, if
  `bookworm` is no longer built) digest from the registry, at least two weeks old, and say which in the pull request.
  The 18 image keeps its data under `/var/lib/postgresql/18/docker`; the pack mounts no data folder (to verify).
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS. Run actionlint on `ci.yml`:
  `go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12 .github/workflows/ci.yml`. Expected: no output.
- [ ] **Step 4:** commit on the branch `gallery-runtime`, and T12's commits after it. The agent does not push it:
  `ci.yml` is under the root `.github/workflows/`, and the pr-bot has no Workflows permission (change
  realm-readiness, its global constraints).
- [ ] **Step 5 (founder):** push the branch and open the pull request, from the agent's clone:

  ```zsh
  cd ~/brunogbv/ouroboric/niflheim-local
  git push -u origin gallery-runtime
  gh pr create --repo ouroboric-dev/niflheim-local --head gallery-runtime --fill
  ```

  Expected: the `test` check passes, and its log shows `TestThePackProvidesTheNeeds` ran.
- [ ] **Step 6 (founder):** after the merge, make `test` a required check (realm-readiness T002's step 5):

  ```zsh
  cd ~/brunogbv/ouroboric/ouroboric
  read -rs 'GH_TOKEN?admin token: ' && export GH_TOKEN
  scripts/setup-repo.sh --org ouroboric-dev niflheim-local
  unset GH_TOKEN
  scripts/as-bot.sh --read all scripts/check-repos.sh --check ruleset niflheim-local
  ```

  Expected: `setup-repo.sh` requires `lint` and `test`, and the check prints `PASS`.

**Acceptance criteria:**

- [ ] The pack provides `postgres` and `s3` with the services of the need contract, Postgres 18.x and SeaweedFS 4.45,
  each by digest (RR-13, RR-26).
- [ ] `ci.yml` has a job `test`, which passes on the pull request and is required on `main` (RR-04, RR-01).

**Named test:** `niflheim-local/pack_test.go:TestThePackProvidesTheNeeds`, `TestPackPostgresIsEighteen`,
`TestPackSeaweedFSIsTheGraderImages`; `check-repos.sh --check ruleset niflheim-local` after step 6.
**Layer:** `niflheim-local` (steps 5 and 6: the founder). **Size:** M, about 200 lines. **Depends on:** T03 merged,
T05 merged.

### Task gallery-runtime-T12: the product start script

It fixes B-078.

**Files (in `niflheim-local`):**

- Create: `templates/product/start.sh`, `productstart_test.go`
- Modify: `pack.yaml` (`product: {start: templates/product/start.sh}`), `pack_test.go`, `docs/architecture.md`,
  `README.md`

**Interfaces:**

- Consumes: the names of delta §9.4, which T13 and T16 give the leaves; the releases of T15 and T17 when they exist.
- Produces: the script that T10 writes at a project's root.

- [ ] **Step 1: the failing tests.** `TestPackNamesTheProductStart` in `pack_test.go`: `Product.Start` is an executable
  file in the pack. `TestProductStart` (so that `-run ProductStart` finds it): a temporary `/app`-like folder with
  stand-in releases at `.ygg/release/repos/api/run.sh` and `.ygg/release/repos/web/run.sh` (each records its
  environment and opens its port), and stand-in `initdb`, `postgres`, `pg_ctl`, `createdb` and `weed` first on the
  `PATH` (each records its arguments and opens the port it is given). Assert:
  - the web part gets `HOST=0.0.0.0`, `PORT=3000`, `API_URL`, `S3_ENDPOINT` and `S3_BUCKET`;
  - the API gets `HOST=127.0.0.1` and every name of delta §9.4, with `DATA_DIR` under `.data/` and a key pair that
    differs between two starts;
  - Postgres and SeaweedFS get data folders under `.data/`, listen on `127.0.0.1`, and SeaweedFS's volume port is
    not the API's;
  - SeaweedFS gets an identity file, mode `0600`, and the key appears in no output of the script;
  - a second start in the same folder finds the data folders and does not run `initdb` again;
  - with no release, the script starts `repos/api/run.sh` and `repos/web/run.sh` instead;
  - with no `repos/web`, it exits non-zero with a message that names the path;
  - a part that does not open its port makes the script exit non-zero and name the part, and stops the others;
  - a `TERM` to the script stops every part;
  - run as root (`id -u` stubbed to 0), it refuses.

  `TestProductStart` needs only `bash` and the stand-ins, so it never skips. Expected: FAIL.
- [ ] **Step 2:** write `start.sh`, in bash, after `midgard-react`'s `accept-e2e.sh`: refuse root; `cd` to its own
  folder; find the leaves at `repos/api` and `repos/web`; make `.data/`; `initdb` once, start `postgres` on
  `127.0.0.1:5432` with its socket in the temporary folder, and run `createdb app` once; write SeaweedFS's identity
  file with a fresh key pair from `/dev/urandom`, and start `weed server -s3` on `127.0.0.1` with its S3 port 8333 and
  its other ports away from 8080; wait for each port (the waits sum to well under 2 minutes); start the API, then the
  web part; `wait` on all of them and stop the rest when one ends. Name the script in `pack.yaml`.
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS. `shellcheck -s bash` on the
  script: no output.

**Acceptance criteria:**

- [ ] `TestProductStart` passes, and each of its assertions fails when the script's matching line is taken out.
- [ ] The pack names the script, and loads with the merged `gungnir`.

**Named test:** `niflheim-local/productstart_test.go:TestProductStart`, `niflheim-local/pack_test.go:TestPackNamesTheProductStart`.
**Layer:** `niflheim-local`. **Size:** M, about 330 lines. **Depends on:** T04 merged, T11.

### Task gallery-runtime-T13: the API on `HOST` and the runtime names

**Files (in `helheim-go`):**

- Modify: `templates/api/cmd/api/main.go` and `main_test.go` (`HOST`), `templates/api/AGENTS.md` and
  `prompts/implementer.md` (the runtime names, the bucket, `DATA_DIR`, the photo rule), `docs/architecture.md`
- Create: `runtime_test.go`

**Interfaces:**

- Produces: the API's names of delta §9.4, which T12, T18 and T19 use.

- [ ] **Step 1: the failing tests.**
  - `TestListensOnHost` in the template's `main_test.go`: with `HOST=127.0.0.1` the server's address is
    `127.0.0.1:<port>`; with no `HOST`, it is `:<port>`, all interfaces, as today (a sandbox may reach the API from
    another container).
  - `TestPromptNamesTheRuntime` in `runtime_test.go`: the implementer prompt and the template's `AGENTS.md` name each
    of `PORT`, `HOST`, `DATABASE_URL`, `DATA_DIR`, `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`,
    `S3_SECRET_ACCESS_KEY`, `X-Forwarded-Host` and `/app/start.sh`, and say that photo bytes and zips of photos never
    pass through the API.

  Run them. Expected: FAIL.
- [ ] **Step 2:** the server listens on `HOST:PORT`, and on all interfaces when `HOST` is unset.
- [ ] **Step 3:** the template's `AGENTS.md` and the prompt say: the API reads only the names of delta §9.4; it writes
  files only under `DATA_DIR`; it builds public addresses from `X-Forwarded-Host` and `X-Forwarded-Proto`; storage
  URLs are path-style, `/<S3_BUCKET>/<key>`, signed for that address; the API makes the bucket at start when it is
  missing, with versioning on when the store supports it; it never streams a photo or a zip; the product's
  `/app/start.sh` is the factory's and no task changes it.
- [ ] **Step 4:** run the tests, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The API listens on `HOST` when it is set, and where it does today when it is not.
- [ ] The prompt and the template's `AGENTS.md` name the runtime, `DATA_DIR`, the bucket and the photo rule.

**Named test:** `templates/api/cmd/api/main_test.go:TestListensOnHost`, `helheim-go/runtime_test.go:TestPromptNamesTheRuntime`.
**Layer:** `helheim-go`. **Size:** M, about 150 lines. **Depends on:** none.

### Task gallery-runtime-T14: the pack declares needs, and names no service

It finishes B-158 in `helheim-go`. The services were test fixtures of the API's checks; they now come from the
runtime realm, under the same names (T08).

**Files (in `helheim-go`):**

- Modify: `pack.yaml` (no `services:`; `needs: [postgres, s3]`; the header comment), `pack_test.go`
  (`TestThePackNeedsADatabaseAndAStore` replaces `TestTheServicesAreWhatAnAPIAsksForAndPinnedByDigest`), `ci_test.go`
  (the template CI's Postgres image is no longer compared with `pack.yaml`), `templates/api/.github/workflows/ci.yml`
  (Niflheim's Postgres 18 image), `devcontainer/checks/go-integration.sh` (the default `YGG_S3_ENDPOINT`,
  `http://seaweedfs:8333`, becomes `http://s3:8333`: the runtime realm's service is `s3`), `go.mod` and `go.sum` (the
  merged `gungnir`), `README.md`, `AGENTS.md`, `docs/architecture.md` ("the services an API needs" becomes its
  needs; its list "`postgres`, `seaweedfs`" goes), and any other place in `helheim-go` that names Postgres 17

- [ ] **Step 1: the failing tests.**
  - `TestThePackNeedsADatabaseAndAStore` in `pack_test.go`: the pack loads with the merged `gungnir`, its `Needs` are
    exactly `postgres` and `s3`, and it names no service (RR-27).
  - `TestTemplateCI` in `ci_test.go`: the template CI's `postgres` service image matches
    `postgres:18\.\d+-\S+@sha256:[0-9a-f]{64}`, and keeps the env and the `YGG_DATABASE_URL` the test checks today.
  - `TestNoPostgres17` in `pack_test.go`: no file in `helheim-go` (outside `.git`, `LICENSES`, the test file itself and
    `go.sum`) names `postgres:17`, `postgresql-17` or `postgresql/17`.
  - `TestTheStoreIsTheS3Service` in `pack_test.go`: `go-integration.sh`'s default `YGG_S3_ENDPOINT` is
    `http://s3:8333`, and no file outside the tests names `seaweedfs:8333` or `http://seaweedfs`.

  Expected: FAIL.
- [ ] **Step 2:** drop the services, add the needs, move the integration check's default endpoint to `s3`, and set the template CI's image to `niflheim-local/pack.yaml`'s
  `postgres` image, byte for byte (T27 checks that they stay the same). Then `grep -rn
  'postgres:17\|postgresql-17\|postgresql/17\|Postgres 17' .` must find nothing.
- [ ] **Step 3:** run the tests, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS, with the check tests
  that reach `postgres:5432` and `s3:8333`.

**Acceptance criteria:**

- [ ] The pack declares `needs: [postgres, s3]` and names no service.
- [ ] The template CI runs Niflheim's Postgres 18 image; nothing in `helheim-go` names Postgres 17.

**Named test:** `helheim-go/pack_test.go:TestThePackNeedsADatabaseAndAStore`, `TestNoPostgres17`,
`TestTheStoreIsTheS3Service`;
`helheim-go/ci_test.go:TestTemplateCI`.
**Layer:** `helheim-go`. **Size:** M, about 180 lines. **Depends on:** T05 merged, T07 to T10 merged (`odin`'s first
pull request), T11 merged.

### Task gallery-runtime-T15: the API's release

**Files (in `helheim-go`):**

- Create: `templates/api/release.sh`, `release_test.go`
- Modify: `templates/api/AGENTS.md` and `prompts/implementer.md` (`release.sh`), `runtime_test.go`,
  `docs/architecture.md`

- [ ] **Step 1: the failing tests.** `TestPromptNamesTheRelease` in `runtime_test.go`: the implementer prompt and the
  template's `AGENTS.md` name `release.sh` and say to keep it working. `TestReleaseScriptStarts` (so that
  `-run ReleaseScript` finds it): copy the
  template, run `release.sh` with `OUT` set to an empty folder, then run `OUT/run.sh` with `PORT` free,
  `HOST=127.0.0.1` and a `PATH` of `/usr/bin:/bin` only (no Go), and wait for the port. Assert that `OUT` holds only
  regular files and folders. Skip without Go; fail with `YGG_REQUIRE_TEMPLATES=1`. Expected: FAIL.
- [ ] **Step 2:** write `release.sh`: `CGO_ENABLED=0 GOWORK=off GOFLAGS=-mod=readonly go build -trimpath -o "$OUT/api" ./cmd/api`
  (it may download modules through the realm's egress), then write `OUT/run.sh`, which checks `PORT` as the leaf's
  `run.sh` does and runs `exec "$(dirname "$0")/api"`. The migrations are embedded already. Print the binary's size.
- [ ] **Step 3:** the template's `AGENTS.md` and the prompt say: keep `release.sh` working, and change it only when
  the leaf's build changes.
- [ ] **Step 4:** run the tests, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The release starts with no Go on the `PATH`, and holds only regular files. The pull request gives the binary's
  size, for T22's bound.
- [ ] The prompt and the template's `AGENTS.md` name `release.sh`.

**Named test:** `helheim-go/release_test.go:TestReleaseScriptStarts`, `helheim-go/runtime_test.go:TestPromptNamesTheRelease`.
**Layer:** `helheim-go`. **Size:** M, about 120 lines. **Depends on:** T13.

### Task gallery-runtime-T16: the web leaf's server, on `HOST`

It fixes B-117.

**Files (in `midgard-react`):**

- Create: `templates/web/serve.mjs` (Node's standard library only), `serve_test.go`
- Modify: `templates/web/run.sh` (build, then `node serve.mjs`), `runscript_test.go`, `templates/web/AGENTS.md`,
  `prompts/implementer.md`, `docs/architecture.md`

**Interfaces:**

- Produces: `serve.mjs`, which reads `PORT`, `HOST`, `API_URL`, `S3_ENDPOINT`, `S3_BUCKET` and `DIST` (default
  `dist`). T17 copies it into the release, and T18 bakes a copy for the acceptance run.

- [ ] **Step 1: the failing test.** `TestServeForwards` starts `node serve.mjs` on a free port with a small `dist/`,
  a stand-in API and a stand-in S3 store (Go `httptest` servers that record what they get), and asserts:
  - `GET /api/galleries?x=1` reaches the API as `/galleries?x=1`, with `X-Forwarded-Host` the request's host and
    `X-Forwarded-Proto: http`;
  - `PUT /<bucket>/a/b.jpg?X-Amz-Signature=s` with a body reaches the store with the same path, query and body, with
    the request's `Host` header, and with no `X-Forwarded-Host`, `X-Forwarded-Port` or `X-Forwarded-Proto` header;
  - `GET /` and `GET /galleries/x` answer `dist/index.html`; `GET /assets/app.js` answers the file with a JavaScript
    content type; a path with `..` does not leave `dist`;
  - with `HOST=127.0.0.1` the server does not answer on another address of the machine; with `HOST=0.0.0.0` it does
    (skip that half when the machine has no non-loopback address).

  Skip without `node`; fail with `YGG_REQUIRE_TEMPLATES=1`. Run it. Expected: FAIL (no `serve.mjs`).
- [ ] **Step 2:** write `serve.mjs`: `node:http` and `node:fs` only, streaming both ways, no package. Change
  `run.sh` to build the bundle and `exec node serve.mjs` with `HOST` (default `127.0.0.1`). Keep the dev server's
  proxy in `vite.config.ts` as it is.
- [ ] **Step 3:** run `TestServeForwards` and `TestRunScriptStarts`, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`.
  Expected: PASS. The docs and the prompt say that `serve.mjs` is what serves the leaf, on port 3000 in the product,
  and that it forwards `/api/` and the bucket's path.

**Acceptance criteria:**

- [ ] `serve.mjs` forwards `/api/` and the bucket's path as delta §9.3 says, adds no `X-Forwarded-*` header to the
  store's requests, and serves the bundle with the fallback.
- [ ] It listens on `HOST`, loopback by default; `run.sh` uses it.

**Named test:** `midgard-react/serve_test.go:TestServeForwards`; `midgard-react/runscript_test.go:TestRunScriptStarts`.
**Layer:** `midgard-react`. **Size:** M, about 300 lines. **Depends on:** none.

### Task gallery-runtime-T17: the web leaf's release

**Files (in `midgard-react`):**

- Create: `templates/web/release.sh`, `release_test.go`
- Modify: `templates/web/AGENTS.md`, `prompts/implementer.md` (`release.sh`), `prompts_test.go`, `docs/architecture.md`

- [ ] **Step 1: the failing tests.** `TestPromptNamesTheRelease` in `prompts_test.go`: the implementer prompt and the
  template's `AGENTS.md` name `release.sh` and say to keep it working. `TestReleaseScriptStarts`: copy the template **without** `node_modules` (a
  snapshot of committed files has none), run `release.sh` with `OUT` set to an empty folder, then run `OUT/run.sh`
  with `PORT` free and a `PATH` that holds `node` and no `npm`, from a folder with no `node_modules`, and wait for the
  port. Assert that `OUT` holds only regular files and folders, and no `node_modules`. Skip without `npm`; fail with
  `YGG_REQUIRE_TEMPLATES=1`. Expected: FAIL.
- [ ] **Step 2:** write `release.sh`: `npm ci --ignore-scripts --no-audit --no-fund` (as the acceptance run does; it
  fetches through the realm's egress), `npm run build`, copy `dist/` to `OUT/dist` and `serve.mjs` to `OUT/`, and
  write `OUT/run.sh`, which checks `PORT` and runs `exec node serve.mjs` in its own folder. The template's
  `AGENTS.md` and the prompt say: keep `release.sh` working, and change it only when the leaf's build changes.
- [ ] **Step 3:** run the tests, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The release builds from a copy with no `node_modules`, starts with Node alone (no `npm`, no `node_modules`), and
  holds only regular files.
- [ ] The prompt and the template's `AGENTS.md` name `release.sh`.

**Named test:** `midgard-react/release_test.go:TestReleaseScriptStarts`, `midgard-react/prompts_test.go:TestPromptNamesTheRelease`.
**Layer:** `midgard-react`. **Size:** M, about 150 lines. **Depends on:** T16.

### Task gallery-runtime-T18: the acceptance run on the new contract

Without it, an end-to-end spec that uploads a photo fails at every pointer move of run 1: `accept-e2e.sh` starts the
API with `PORT` and `DATABASE_URL` only, and its baked `vite.config.ts` forwards only `/api`, with `changeOrigin`.
And the e2e rung (`web-e2e.sh`, in every web task's loop) runs every spec against a Prism mock with no store, so a
spec that does a real `PUT` can never pass there. Agents would then stub the store with `page.route`, the stub would
run in the acceptance run too, and the store forward would never be exercised. So the scripts tell a spec whether a
real store is behind `/<bucket>/`. The snapshot's sandbox gets SeaweedFS from the runtime realm, as the service
`s3` (T08). `accept-e2e.sh` names no store today, so its default endpoint is `http://s3:8333` from the start.

**Files (in `midgard-react`):**

- Modify: `devcontainer/checks/accept-e2e.sh`, `devcontainer/checks/web-e2e.sh`, `devcontainer/checks/web-configs.sh`
  (the baked server), `checks_test.go`, `prompts/implementer.md`, `templates/web/AGENTS.md`, `prompts_test.go`,
  `docs/architecture.md`
- Create: `devcontainer/checks/config/serve.mjs` (byte for byte `templates/web/serve.mjs`)

- [ ] **Step 1: the failing tests.**
  - `TestAcceptanceGivesTheRuntime` in `checks_test.go`, with stand-in `go`, `npm` and `node` on the `PATH` (follow
    the existing acceptance tests): the API is started with every name of delta §9.4, with `S3_ENDPOINT` the
    sandbox's SeaweedFS (`http://s3:8333` unless `YGG_S3_ENDPOINT` says otherwise), a bucket name and a
    `DATA_DIR` in the temporary folder; the web app is served by the baked `serve.mjs`, not the leaf's, with
    `API_URL`, `S3_ENDPOINT` and `S3_BUCKET`.
  - `TestBakedServeIsTheTemplates`: the baked `serve.mjs` and the template's are the same bytes.
  - `TestE2EStoreFlag`: `accept-e2e.sh` runs Playwright with `YGG_E2E_STORE=1`; `web-e2e.sh` runs it with
    `YGG_E2E_STORE` unset, also when the caller's environment sets it.
  - `TestPromptSaysWhenToStubTheStore` in `prompts_test.go`: the implementer prompt and the template's `AGENTS.md`
    say that a spec stubs the store only when `YGG_E2E_STORE` is unset, and uses the real `/<bucket>/` when it is `1`.

  Expected: FAIL.
- [ ] **Step 2:** change `accept-e2e.sh`: build the bundle with the baked config as today, then serve it with the
  baked `serve.mjs`; pass the names; set `YGG_E2E_STORE=1` for Playwright. Keep the Prism branch for a product with no
  API, and leave the flag unset there.
- [ ] **Step 3:** change `web-e2e.sh` to unset `YGG_E2E_STORE` for Playwright. Write the rule in the prompt, the
  template's `AGENTS.md` and `docs/architecture.md`: in the rung, a spec stubs the store (for example with
  `page.route` on `/<bucket>/`); in the acceptance run, the same spec uses the real store through port 3000's forward.
- [ ] **Step 4:** run the tests, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The acceptance run gives the API the runtime names and serves the web app with the realm's baked server.
- [ ] The baked server is the template's, byte for byte.
- [ ] A spec can tell whether a real store is behind `/<bucket>/`: `YGG_E2E_STORE=1` in the acceptance run, unset in
  the rung; the prompt says to stub the store only when it is unset.

**Named test:** `midgard-react/checks_test.go:TestAcceptanceGivesTheRuntime`, `TestBakedServeIsTheTemplates`,
`TestE2EStoreFlag`; `midgard-react/prompts_test.go:TestPromptSaysWhenToStubTheStore`.
**Layer:** `midgard-react`. **Size:** M, about 330 lines. **Depends on:** T13, T16.

### Task gallery-runtime-T19: the prompts name the runtime and the runtime pin

**Files (in `voluspa`):**

- Modify: `software/prompts/spec.md`, `software/prompts/plan.md`, `software/prompts/reviewer-spec.md`,
  `prompts_test.go`; `go.mod` and `go.sum` (the merged `gungnir`) if `prompts_test.go` parses the leaves example

- [ ] **Step 1: the failing tests.**
  - `TestPromptsNameTheRuntime`: `spec.md` says that the product runs on one machine with Postgres and an S3 store
    started by the factory's `start.sh`; that the leaves are `repos/web` and `repos/api` and no other; that the web
    leaf serves port 3000 and the API never serves the web app; that the product keeps its data under `/app/.data/`
    and the API writes files only under `DATA_DIR`; and names the API's and the web leaf's variables of delta §9.4.
    Its leaves example holds `runtime: {realm: niflheim-local, realm_version: 0.1.0}`, and the list of realms names
    `niflheim-local` 0.1.0 as the only runtime realm. `plan.md` says that no task writes `start.sh` or any file
    outside its leaf.
  - `TestReviewerNamesThePhotoRule`: `reviewer-spec.md` says that an API that streams a photo's bytes or a zip of
    photos breaks spec §9.3, and is a finding.

  Expected: FAIL.
- [ ] **Step 2:** add the lines, short, in the prompts' style.
- [ ] **Step 3:** run `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The tests pass, and fail when any of the lines is taken out.
- [ ] The leaves example parses with the merged `gungnir` (T06).

**Named test:** `voluspa/prompts_test.go:TestPromptsNameTheRuntime`, `TestReviewerNamesThePhotoRule`.
**Layer:** `voluspa`. **Size:** M, about 120 lines. **Depends on:** T06 merged, T07 merged (an `odin` that reads the
runtime pin, before the prompt asks for it).

### Task gallery-runtime-T20: the conformance review gets 20 minutes (F2)

The rehearsal's conformance reviewer ran out its 10-minute session on a review of about 62 KB. Run 1 has one
conformance review; its task reviewers keep 10 minutes. The founder chose both fixes (2026-10-23): this deadline, and
the reviewer's `reasoning: medium` (T28).

**Files (in `voluspa`):**

- Modify: `software/graph.yaml` (the `conformance` node's `timeout: 20m`), `pack_test.go`

- [ ] **Step 1: the failing test.** `TestConformanceHasTwentyMinutes` in `pack_test.go`: the graph's `conformance` node
  has a timeout of 20 minutes, and every reviewer of the task loop keeps 10 minutes. Expected: FAIL.
- [ ] **Step 2:** change the timeout, with a comment that names F2.
- [ ] **Step 3:** run `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The conformance session's deadline is 20 minutes; no other deadline changes.

**Named test:** `voluspa/pack_test.go:TestConformanceHasTwentyMinutes`.
**Layer:** `voluspa`. **Size:** S, about 30 lines. **Depends on:** none.

### Task gallery-runtime-T21 (founder): `client-gallery-lite` 4.1.0, on Niflheim's versions

A new task version that replaces 4.0.0 in place: the same brief and hash, and an image that holds the services, at
the versions `niflheim-local` pins. `mimir/AGENTS.md` says a new task version is made by the founder.

**Files (in `mimir`):**

- Modify: `client-gallery-lite/environment/Dockerfile`, `client-gallery-lite/task.toml` (`version = "4.1.0"`),
  `README.md` (the table lists 4.0.0 and 4.1.0)

- [ ] **Step 1: the failing test.** Build the 4.0.0 image and run, with no network, as `app`:

  ```zsh
  podman build -t cgl:4.0.0 client-gallery-lite/environment
  podman run --rm --network none --user app cgl:4.0.0 sh -c 'initdb --version && postgres --version && createdb --version && weed version'
  ```

  Expected: it fails (`initdb: not found`).
- [ ] **Step 2:** write the Dockerfile in this order. Gleipnir's stack build refuses a `COPY --from` that names an
  image or a stage not yet defined (`gleipnir/sandbox/stackbuild.go`), and the last stage is the image, so:
  1. `FROM` the image of the `s3` service of `niflheim-local/pack.yaml` (SeaweedFS 4.45), by its digest, `AS weed`
     first;
  2. then the Playwright stage, as today;
  3. in it, install `postgresql-common`, then write `create_main_cluster = false` into
     `/etc/postgresql-common/createcluster.conf`, then install `postgresql-18` (the order the official `postgres`
     image uses; to verify when the image is built), so the package makes no cluster. Use the PostgreSQL project's
     repository for Ubuntu 24.04, with its key checked by fingerprint, at one pinned package version: the minor of
     `niflheim-local`'s `postgres` image when the archive has it, else the nearest 18.x, said in the commit. The main
     repository keeps only the newest package of each version, so take the pin from `apt-archive.postgresql.org` or a
     dated snapshot (say which). Put `/usr/lib/postgresql/18/bin` on the `PATH`;
  4. `COPY --from=weed /usr/bin/weed /usr/local/bin/weed`.

  Do not start a service. Update the header comment: the image also holds PostgreSQL 18 and SeaweedFS 4.45, at the
  versions of the runtime realm `niflheim-local`, for a product that wants them; the product starts them itself.
- [ ] **Step 3:** set `version = "4.1.0"` in `task.toml`. Keep `brief_sha256`. Keep `suite = "v2"` (question 3). The
  README's table gets a 4.1.0 row and keeps the 4.0.0 row, which says it is in the history.
- [ ] **Step 4:** run the command of step 1 on the new image. Expected: four version lines, PostgreSQL 18 and
  SeaweedFS 4.45. Then run, as `app` with no network, a cluster in a temporary folder:
  `initdb -D /tmp/pg -U postgres --auth=trust && pg_ctl -D /tmp/pg -o '-k /tmp -c listen_addresses=127.0.0.1' -w start && createdb -h /tmp -U postgres app && psql -h /tmp -U postgres -d app -c 'select 1'`.
  Expected: `1`. Check that `/var/lib/postgresql/18/main` does not exist.
- [ ] **Step 5:** run `scripts/check-task.sh client-gallery-lite` and `bash scripts/check-task.test.sh`. Expected:
  both pass. `check-task.sh` reads only the task folder, so check by hand that `sha256sum
  client-gallery-lite/instruction.md` is the hash in the README's row.

**Acceptance criteria:**

- [ ] `instruction.md` is unchanged; `sha256sum` gives `bd4b2c7aaf532d51acb3a7edfd5b193d368db8445093b7a24cd80b7ee24d8319`,
  the same as `task.toml` and the README (the README by hand).
- [ ] The 4.1.0 image runs `initdb`, `postgres`, `pg_ctl`, `createdb`, `psql` and `weed` as `app` with no network; the
  4.0.0 image did not. The image holds no cluster.
- [ ] The SeaweedFS digest is `niflheim-local`'s, and the Postgres major is 18 (T27 checks both).
- [ ] `check-task.sh` passes; `suite = "v2"`.

**Named test:** the `podman run` of step 1 (red on 4.0.0, green on 4.1.0); `mimir/scripts/check-task.sh client-gallery-lite`.
**Layer:** `mimir`. **Size:** S, about 50 lines. **Depends on:** T11 merged.

### Task gallery-runtime-T22: the release in the export

**Files (in `odin`):**

- Modify: `internal/run/grade.go` (`ExportApp`), `internal/engine/grade.go` (a release failure is a `GradeFailed`),
  `docs/architecture.md`
- Create: `internal/run/release.go`, `internal/run/release_test.go`

**Interfaces:**

- Produces: `run.Releaser`, `Build(ctx, snapshot string, leaves []string) (dir string, err error)`, and its use in
  `ExportApp`. T23 gives the real one.

- [ ] **Step 1: the failing tests,** with a stand-in `Releaser`:
  - `TestExportAppAddsTheRelease`: the export holds the committed files and, for each leaf with an executable
    `release.sh`, the release at `.ygg/release/<leaf>/`; a leaf with no `release.sh` gets none;
  - `TestReleaseIsReused`: a second export of the same commits calls the releaser once; a new commit of a leaf builds
    again;
  - `TestReleaseRefused`: a release with a symlink, a device file, or past its bound, and a releaser that fails, each
    make `ExportApp` return an error that names the leaf, and leave no partial export;
  - `TestReleaseBound`: a 40 MiB file in a release is accepted (above the snapshot's 32 MiB per file), and a release
    over the release's own bound is refused;
  - `TestGradeFailsOnARelease`: in `engine`, a failed release is a `*GradeFailed`, with no `score.json`, and a resume
    grades again.

  Expected: FAIL.
- [ ] **Step 2:** implement it. A release is copied into the export after `snapshot.Export`, under a bound of its own,
  named as constants in `release.go`: 128 MiB per file and 512 MiB in all. These stand until T15 and T17 report
  their sizes; a later commit adjusts them if a size comes near. They are not the snapshot's limits for source (`internal/snapshot/snapshot.go`: 32 MiB per file, 256 MiB in all).
  Keep each release in the run folder under the commits it was built from. Write the releaser's output to
  `release.log` beside `grade.log`, mode `0600`.
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS. `ygg bridge`'s tests still pass:
  its upload is the same export.

**Acceptance criteria:**

- [ ] The five tests pass. A release is never committed to the project or a leaf.

**Named test:** `odin/internal/run/release_test.go:TestExportAppAddsTheRelease`, `TestReleaseIsReused`,
`TestReleaseRefused`, `TestReleaseBound`; `odin/internal/engine/grade_test.go:TestGradeFailsOnARelease`.
**Layer:** `odin`. **Size:** M, about 300 lines. **Depends on:** none (question 1 is answered).

### Task gallery-runtime-T23: the release built in the acceptance sandbox

**Files (in `odin`):**

- Modify: `internal/run/release.go` (the sandbox `Releaser`), `internal/engine/grade.go` and `internal/cli/bridge.go`
  (they pass it), `docs/architecture.md`
- Create: `internal/run/release_sandbox_test.go`

- [ ] **Step 1: the failing tests,** with the stand-in engine the snapshot runner's tests use:
  - `TestReleaseRunsInTheAcceptanceSandbox`: the releaser starts the acceptance realm's sandbox through
    `SnapshotRunner` on the exported commits, runs `release.sh` in each leaf with `OUT` set, and copies the result
    out; no agent session starts; no secret is in the sandbox's environment;
  - `TestReleaseSandboxStopsBeforeTheGrader`: the sandbox is down, and `NoSandboxesLeft` passes, before the grader's
    container is started, also when the release fails;
  - `TestNoAcceptanceSandboxNoRelease`: a project with no acceptance realm exports as today.

  Expected: FAIL.
- [ ] **Step 2:** implement it. Copy the release out as the host user, so that a second grade can remove it (B-139).
  Give the whole release a timeout of its own, from the grader's settings.
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The three tests pass. The grader never starts while the release sandbox is up.

**Named test:** `odin/internal/run/release_sandbox_test.go:TestReleaseRunsInTheAcceptanceSandbox`,
`TestReleaseSandboxStopsBeforeTheGrader`, `TestNoAcceptanceSandboxNoRelease`.
**Layer:** `odin`. **Size:** M, about 250 lines. **Depends on:** T22.

### Task gallery-runtime-T24: an approval's note reaches later stages (F1)

In the rehearsal, the founder's design-gate note was recorded on `gate_approved` and read by nothing; only a
rejection's reason (`state.Reasons`) reaches a stage. This task gives the notes of gate approvals to every later
session (delta §7.2). `Approve` (`internal/engine/gates.go`) also takes the stops of a loop that gave up (escalation),
of `policy-violation` and of `shrink-guard`; a note there is about that stop, not the product, so it stays on the
`gate_approved` event only.

**Files (in `odin`):**

- Modify: `internal/run/state.go` (`State.Decisions`, a list of `{Gate, Note}`), `internal/engine/gates.go` (`Approve`
  refuses a note with a control character, and keeps a note that is not blank only when the stopped node is a gate,
  `n.Kind == schema.KindGate`; `Reject` drops the notes of the gates it sends the run back past),
  `internal/engine/engine.go` (`runAgent`), `internal/engine/scratch.go` (a scratch node's prompt),
  `internal/engine/loop.go` (the implementer's and the reviewers' prompts), `docs/architecture.md`
- Create: `internal/engine/decisions.go` (one function writes the block, after the brief), `internal/engine/decisions_test.go`

- [ ] **Step 1: the failing tests,** with scripted roles that record their prompts:
  - `TestApprovalNoteReachesLaterStages`: on a graph `design`, `design-gate`, `spec`, `conformance`, `spec-gate`,
    `plan`, the design gate approved with a note: the prompts of `spec`, `conformance` and `plan` hold "## The
    product owner's decisions", the gate's name and the note, after the brief; `design`'s prompt does not. A second
    note at `spec-gate` comes after the first in `plan`'s prompt.
  - `TestNoteReachesLoopSessions`: the implementer's and every reviewer's prompt in a task loop after the gate hold
    the note.
  - `TestApprovalWithoutANoteAddsNothing`: an approval with no note, or a blank one, adds no heading.
  - `TestOnlyAGateNoteIsADecision`: a note given when approving a loop's escalation, a `policy-violation` stop or a
    `shrink-guard` stop is on the `gate_approved` event and in no later prompt.
  - `TestANoteIsOneLine`: `Approve` refuses a note with a newline, a carriage return, a tab or another control
    character (the rule of `ygg-proof-run.sh`'s `--note`), with a message, and records nothing; so a note cannot
    start a heading of its own in a prompt.
  - `TestRejectionDropsTheNotesOfGatesItGoesBackPast`: a gate whose `reruns` is a node before an earlier gate drops
    that earlier gate's note when it is rejected; a rejection that goes back to a node after every gate keeps them all.
  - `TestDecisionsSurviveAResume`: the notes are in `run.json`, and a resumed run's next session gets them.

  Expected: FAIL.
- [ ] **Step 2:** implement it. The block's text is graph-neutral: "Decisions the product owner gave at the approval
  points of this run. They hold for this product: where one differs from an earlier document, the decision wins, and
  the difference is written down as the product owner's decision." Then one line per note: the gate, and the note.
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The seven tests pass, and `TestApprovalNoteReachesLaterStages` fails when the block is taken out of any one of
  the three kinds of prompt.
- [ ] `ygg report`'s list of interventions is unchanged.

**Named test:** `odin/internal/engine/decisions_test.go:TestApprovalNoteReachesLaterStages`, `TestNoteReachesLoopSessions`,
`TestApprovalWithoutANoteAddsNothing`, `TestOnlyAGateNoteIsADecision`, `TestANoteIsOneLine`,
`TestRejectionDropsTheNotesOfGatesItGoesBackPast`, `TestDecisionsSurviveAResume`.
**Layer:** `odin`. **Size:** M, about 280 lines. **Depends on:** none.

### Task gallery-runtime-T25: the real-realm fixtures pin the runtime

Two of `odin`'s fixtures build a product from the real realms beside `odin`, and their leaves file names
`helheim-go` with no `runtime`: `testdata/smoke-content/script.yaml` (the spec step's `out/leaves.yaml`, which the
content smoke of T30's step 3 runs on a real engine) and `realScript` in `internal/cli/realms_content_test.go`. Once
`helheim-go` declares needs (T14), both stop at T07's check. This task pins the runtime realm in both, and copies it
beside the others in the test.

**Files (in `odin`):**

- Modify: `testdata/smoke-content/script.yaml` (`runtime: {realm: niflheim-local, realm_version: 0.1.0}` in the leaves
  file), `internal/cli/realms_content_test.go` (`realScript`'s leaves file gets `runtime` with `NIFLHEIM_VERSION`,
  filled like `HELHEIM_VERSION`; the test copies `niflheim-local` into the store with `copyBesideOdin`, not
  `realRealm`, since it has no check to replace), `internal/cli/smoke_content_test.go`

- [ ] **Step 1: the failing tests.**
  - `TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents`, with `helheim-go` at T14 beside `odin`: it fails at
    `ready` (T07), naming the missing `runtime`. With the pin, and `niflheim-local` copied into the store, it passes,
    and the run's `run.json` records `niflheim-local` as a loaded realm. It skips when `niflheim-local` is not beside
    `odin`, the way it skips for the other realms (`copyBesideOdin`).
  - `TestTheContentSmokeFilesLoad` (it exists; extend it): the leaves file the spec step writes parses with `gungnir`'s `ParseLeaves` and
    names the runtime pin.

  Expected: FAIL.
- [ ] **Step 2:** pin the runtime in both leaves files, and copy the realm in the test.
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`, with the merged `helheim-go` and
  `niflheim-local` beside `odin`. Expected: PASS.

**Acceptance criteria:**

- [ ] Both fixtures pin `niflheim-local` 0.1.0, and the real-realm test passes with the realms at their merged `main`.

**Named test:** `odin/internal/cli/realms_content_test.go:TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents`;
`odin/internal/cli/smoke_content_test.go:TestTheContentSmokeFilesLoad`.
**Layer:** `odin`. **Size:** S, about 60 lines. **Depends on:** T07, T14 merged, T11 merged.

### Task gallery-runtime-T26: the runtime smoke script

It builds the releases with each build realm's `release.sh` (question 1), and starts the product with
`niflheim-local`'s product start.

**Files (in `ouroboric`):**

- Create: `scripts/ygg-smoke-runtime.sh`, `scripts/tests/ygg-smoke-runtime.test.sh`
- Modify: `AGENTS.md` (the scripts table)

**Interfaces:**

- Produces: `ygg-smoke-runtime.sh [--image REF] [--folder DIR] [--yggdrasil DIR]`, which T30 runs. `--yggdrasil` is
  the folder that holds `helheim-go`, `midgard-react` and `niflheim-local`.

- [ ] **Step 1: the failing test.** `ygg-smoke-runtime.test.sh`, with a stand-in `podman` first on the `PATH` that
  records its arguments, and a stand-in `ygg-engine.sh` (or `YGG_ENGINE_CHECK=0`). The script takes the engine's
  environment from `scripts/ygg-engine.sh env --folder DIR`, as `ygg-smoke-grade.sh` does, never a bare `podman` on
  the root socket; the test asserts that `podman` runs only after that environment is loaded. The script builds each template's release in that realm's sandbox image, puts
  `niflheim-local`'s product start at the root of a folder laid out like `/app`, makes a Podman network with
  `--internal`, and runs the product in the task image on that network with `--user app`. It runs its checks from a
  second container on the same network, and removes both containers and the network at the end. It refuses a missing
  image or a missing realm with a message, and never names `hidden-suites` or a credentials file. Expected: FAIL.
- [ ] **Step 2:** write the script. A `--network none` container has only loopback (the grader is one, and reaches the
  product there), so it cannot show "all interfaces"; the internal network gives an address with no route out. The
  checks, each printed as `PASS` or `FAIL`:
  - port 3000 answers `GET /` with the bundle's `index.html` within 2 minutes, from the second container, at the
    product container's address on the internal network;
  - `GET /api/<a route of the template>` answers from the API through port 3000, from the second container;
  - an unsigned `PUT` to `/<bucket>/x` through port 3000 is refused;
  - a signed `PUT` and `GET` (`curl --aws-sigv4`, the key read as `app` from the identity file under `/app/.data/`)
    through port 3000 succeed, and the script never prints the key;
  - `ss -ltn` in the product container (or `/proc/net/tcp` when the image has no `ss`) shows every listener except
    `:3000` bound to `127.0.0.1`;
  - the product container cannot reach an outside address;
  - a restart of `start.sh` in the same container finds the object it wrote;
  - the time from start to the first answer, in seconds.
- [ ] **Step 3:** run the test and `shellcheck -s bash`. Expected: the test's lines all `ok`; no output.

**Acceptance criteria:**

- [ ] The test passes with the stand-in engine; the script names its checks and their order in its header.

**Named test:** `ouroboric/scripts/tests/ygg-smoke-runtime.test.sh`.
**Layer:** `ouroboric`. **Size:** M, about 300 lines. **Depends on:** T12, T15, T17.

### Task gallery-runtime-T27: the services check, and `niflheim-local` in the lists

One fact, the services' versions, now lives in `niflheim-local`; the grader image and `helheim-go`'s template CI copy
it. This check keeps the copies equal (delta §11, RR-26).

**Files (in `ouroboric`):**

- Modify: `scripts/check-repos.sh` (`--check services`; `niflheim-local` in `LEAVES`, kept out of
  the build `REALMS` of the `shared` check), `scripts/tests/check-repos.test.sh`, `AGENTS.md` (the table's
  `check-repos.sh` row)

- [ ] **Step 1: the failing test.** In `check-repos.test.sh`, on stand-in clones under a temporary root:
  - `--check services` passes when the digest of `niflheim-local/pack.yaml`'s `s3` service is the one in
    `mimir/client-gallery-lite/environment/Dockerfile`'s `FROM … AS weed` line, `helheim-go`'s template CI names
    Niflheim's `postgres` image byte for byte, and the Dockerfile's `postgresql-18` package has Niflheim's major; it
    prints both Postgres minors;
  - it fails, naming the file and both values, when the digest differs, when the template CI's image differs, or when
    the majors differ; a missing `niflheim-local`, `helheim-go` or `mimir` clone fails, never skips;
  - it compares the three repos once per run of `check-repos.sh`, whatever repos are named: the loop over repos
    (`for r in "${repos[@]}"; do for c in "${checks[@]}"`) does not run it once per repo;
  - it is not in the default list: `check-repos.sh` with no `--check` does not run it;
  - a different minor passes, with a line that says so;
  - it reads only those three files, and never names `hidden-suites`, `huldra` or a credentials file.

  Expected: FAIL (the check is unknown).
- [ ] **Step 2:** write the check, in the style of `check_shared`, with `grep` and `sed` on the three files (no YAML
  library), run once after the loop over repos when `--check services` is given. Add `niflheim-local` to `LEAVES`,
  so the other checks cover it, and keep it out of `REALMS`: it has no `devcontainer/checks/` to share. From then on
  `check-repos.sh` reads it at `yggdrasil/niflheim-local`, the submodule of T34, which merged long before; it does not
  go into `LEAVES` in `ouroboric`'s first pull request, because T03's checks would then look for a submodule that
  only exists once T03 has merged. `check_agents` then applies the leaf rule, which the scaffold meets (T03).
- [ ] **Step 3:** run the test and `shellcheck -s bash`. Expected: pass; no output.

**Acceptance criteria:**

- [ ] The check passes and fails as above, runs once per call, and only with `--check services`; T30 and T33 name it.
- [ ] `check-repos.sh` covers `niflheim-local` (RR-10's list).

**Named test:** `ouroboric/scripts/tests/check-repos.test.sh` (the `services` cases).
**Layer:** `ouroboric`. **Size:** M, about 200 lines. **Depends on:** T34 merged (the submodule path), T11, T14, T21 (their files' form; on the merged
repos the check passes only once all three are merged).

### Task gallery-runtime-T28: the reviewer's reasoning effort in the proof config (F2)

The rehearsal's reviewer (opencode, `openrouter/qwen/qwen3.8-27b`, reasoning unset, so `high`) produced nothing for
600 seconds on one review. The proof config sets `reasoning: medium` on the reviewer role (spec §5's role setting;
the founder's choice, 2026-10-23).

**Files (in `ouroboric`):**

- Modify: `scripts/testdata/proof/factory.proof.example.yaml` (the reviewer role's `reasoning: @REVIEWER_REASONING@`),
  `scripts/ygg-proof-run.sh` (`--reviewer-reasoning low|medium|high|off`, default `medium`; the header; the plan line),
  `scripts/tests/ygg-proof-run.test.sh`, `AGENTS.md` (the table's row)

- [ ] **Step 1: the failing tests,** in `ygg-proof-run.test.sh`:
  - a dry run writes `reasoning: medium` on the reviewer role of `factory.yaml`, and no `reasoning` on the planner and
    the implementer;
  - `--reviewer-reasoning off` writes `off`; a value outside the four is refused with exit 2 and nothing made;
  - the plan line says "reviewer AGENT:MODEL (reasoning medium)";
  - `--continue` refuses `--reviewer-reasoning`, as it refuses the other setup flags;
  - the config passes the stand-in `ygg doctor`.

  Expected: FAIL.
- [ ] **Step 2:** add the flag and the line. A `claude-code` reviewer ignores the setting (the schema says so); the
  line is written for every agent, so the config is the same whichever reviewer runs.
- [ ] **Step 3:** run the test and `shellcheck -s bash`. Expected: the test's lines all `ok`; no output.

**Acceptance criteria:**

- [ ] Every proof run's reviewer asks for `medium` unless the operator names another effort, and the dry run shows it.

**Named test:** `ouroboric/scripts/tests/ygg-proof-run.test.sh` (the reasoning cases).
**Layer:** `ouroboric`. **Size:** S, about 90 lines. **Depends on:** none.

### Task gallery-runtime-T29: `ygg-proof-run.sh --reject` (F3)

`ygg reject` advances the run at once, so it starts sessions and needs the credentials. The founder had to run the raw
command in a shell with them loaded.

**Files (in `ouroboric`):**

- Modify: `scripts/ygg-proof-run.sh` (`--continue RUN_ID --reject GATE --reason TEXT`; the header, the usage, step 9's
  messages), `scripts/tests/ygg-proof-run.test.sh`, `AGENTS.md` (the table's row)

- [ ] **Step 1: the failing tests,** in `ygg-proof-run.test.sh`, with the stand-in `ygg` and `timeout`:
  - `--continue RUN --reject GATE --reason TEXT` runs `ygg reject RUN GATE --reason TEXT --project P` once, under
    `timeout --signal=INT --kill-after=2m WALL`, with the credentials in that subshell only, its output filtered and
    added to `run.txt`, then steps 8 and 9 as for `--approve`; the exit code is the run's;
  - the dry run prints the command and starts nothing;
  - refused with exit 2 and nothing started: `--reject` without `--reason`; `--reason` without `--reject`;
    `--reject` with `--approve` or `--resume`; `--note` with `--reject`; a blank reason; a reason with a control
    character; `--reject` without `--continue`;
  - after a stop (exit 3), step 9 prints the `--reject GATE --reason "..."` form beside the `--approve` one, and the
    raw fallback names `ygg reject`.

  Expected: FAIL.
- [ ] **Step 2:** implement it beside `--approve`, sharing its checks and its run.
- [ ] **Step 3:** run the test and `shellcheck -s bash`. Expected: the test's lines all `ok`; no output.

**Acceptance criteria:**

- [ ] A rejection runs as an approval does: the same timeout, credentials subshell, filter and evidence.

**Named test:** `ouroboric/scripts/tests/ygg-proof-run.test.sh` (the reject cases).
**Layer:** `ouroboric`. **Size:** M, about 180 lines. **Depends on:** T28 (the same script, on the same branch).

### Task gallery-runtime-T30 (founder): the runtime smoke on the real engine

- [ ] **Step 1:** check out `gungnir`, `helheim-go`, `midgard-react`, `odin` and `voluspa` at their merged `main`
  (the umbrella's pointers move only in T33), check out the `niflheim-local` submodule (T34) at its merged `main`, and
  build `ygg` from that `odin`. `check-repos.sh` finds the realm there, since T27 put it in `LEAVES`.
- [ ] **Step 2:** build the 4.1.0 image and run the smoke and the services check:

  ```zsh
  cd ~/brunogbv/ouroboric/ouroboric
  scripts/ygg-smoke-runtime.sh --image cgl:4.1.0
  scripts/as-bot.sh --read all scripts/check-repos.sh --check services
  ```

  Expected: every check `PASS`, the time to the first answer under 120 seconds, and the services check passing. Note
  whether SeaweedFS 4.45 turned versioning on for the bucket (proposal question 7, best effort).
- [ ] **Step 3 (optional):** run the content smoke with the gallery's brief (`ygg-smoke-realms.sh --graph software
  --brief <mimir>/client-gallery-lite/instruction.md --tag h15`), then `ygg grade <run> --project <project>`. The
  suites folder is passed by path and nobody reads it. Expected: a grade that ends with a reward (a template product
  scores low), no `GradeFailed`, and a `release.log` that shows both leaves built.
- [ ] **Step 4:** paste the output on the `yggdrasil` pull request of T31 to T33.

**Acceptance criteria:**

- [ ] Every check of the smoke passes on the real engine, with the merged repos; the services check passes.
- [ ] Whether versioning is on is written on the pull request.

**Named test:** `ygg-smoke-runtime.sh` on the 4.1.0 image; `check-repos.sh --check services`.
**Layer:** the founder's machine. **Size:** S. **Depends on:** T21, and T03 to T29 and T34 merged.

### Task gallery-runtime-T31: fold the delta, the checklist and the backlog

**Files (in `yggdrasil`):**

- Modify: `docs/2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md` (§6.1, §7.2, §9.3, §9.4, §11, as the delta
  says), `docs/2-engineering/realm-readiness.md` (the `runtime` kind, RR-24 to RR-27), `docs/2-engineering/backlog.md`

**Where the delta goes.** The changes README says a merged delta is folded into `../system/` and the folder moves to
`archive/`. The earlier changes did not do that: they folded their deltas into the dated v0 spec and stayed where they
are, and no `changes/archive/` exists. This change does what the earlier ones did. Moving every change to the living
spec is its own piece of work, which this task files in the backlog.

- [ ] **Step 1:** fold the delta into the dated spec. Add the `runtime` kind and RR-24 to RR-27 to the checklist,
  with their checks.
- [ ] **Step 2:** in the backlog, mark B-078, B-117, B-118, B-140 and B-158 done with the pull requests (B-158: the
  founder's decision of 2026-10-23, candidate (a), before run 1); add to B-116 that a leaf now starts alone from its
  release. File these items: the acceptance run does not build or start the release, so no check runs `release.sh`;
  the development sandbox's SeaweedFS accepts anonymous requests; versioning on SeaweedFS, if T30 found it off; a
  cloud flavor of Niflheim; the changes README's archive rule, which no change follows yet.
- [ ] **Step 3:** run `pre-commit run --files` on every changed file, and the docs check. Expected: pass; no problem
  names a changed file.

**Acceptance criteria:**

- [ ] The spec holds every line of the delta, and the checklist has the `runtime` kind and RR-24 to RR-27.
- [ ] The five backlog items are done, with links, and the new items are filed.

**Named test:** `pre-commit run --files` on the changed files; the docs check.
**Layer:** `yggdrasil`. **Size:** M, about 250 lines. **Depends on:** T30.

### Task gallery-runtime-T32: the runbook: the founder's decisions, `--reject`, 4.1.0

Every proof run gives the same product decisions, word for word (proposal, "The founder's product decisions").

**Files (in `yggdrasil`):**

- Modify: `docs/3-using/operations/proof-runs.md` ("The runs", "Gates you will meet", "Continue a stopped run", the
  flags table)

- [ ] **Step 1: the failing check.** The two text blocks below are not in the runbook: `grep -cF` of each block's
  first line in `proof-runs.md` prints `0`.
- [ ] **Step 2:** add a section "The product owner's decisions". It says: at `design-gate`, approve with the first
  block as the note, pasted, never retyped (`scripts/ygg-proof-run.sh --continue RUN --approve design-gate --note
  "<the block>"`); with T24 the note reaches every later stage; give a note at another gate only for a decision, since
  every note reaches every later stage; if the spec at `spec-gate` still lacks a decision, reject it with the second
  block (`--continue RUN --reject spec-gate --reason "<the block>"`). Both blocks, in fenced `text` blocks, one line
  each:

  ```text
  Product owner's answers (2026-10-22), for every run: 1. Add a password reset: primarily by email, with security questions set at sign-up as the second way. The graded machine has no outside services and no network, so the email sender is configurable; with none configured, each reset email is written to a local outbox file under /app/.data/ that the operator can read. 2. Photographers can delete photos, galleries and their own account. 3. The client's email step says that the photographer will see the email entered. 4. Storage cap: 10 GB per photographer by default, configurable per photographer. 5. A change of a gallery password or PIN logs out the clients already in, and a photographer's password change logs out their other sessions.
  ```

  ```text
  The product owner answered the design's open questions at the design gate (2026-10-22), and the answers apply to every run. The spec must include them, with routes, data model, acceptance criteria and tests, and list each one under "Deviations from the design doc" as the product owner's decision: 1. A password reset for photographers: primarily by email, with security questions set at sign-up as the second way. The graded machine has no outside services and no network, so the email sender is configurable; with none configured, each reset email is written to a local outbox file under /app/.data/ that the operator can read. 2. Photographers can delete photos, galleries and their own account. 3. The client's email step says that the photographer will see the email entered. 4. A storage cap of 10 GB per photographer by default, configurable per photographer. 5. A change of a gallery password or PIN logs out the clients already in, and a photographer's password change logs out their other sessions.
  ```

  These are the texts the founder approved in T01, with "under /app" made "under /app/.data/": the founder's
  decisions of 2026-10-23 write decision 1 that way (question 4).
- [ ] **Step 3:** replace the raw `ygg reject` fallback of "Continue a stopped run" with `--continue RUN --reject GATE
  --reason "..."` (T29), and keep the raw command as the fallback. Add `--reject` and `--reviewer-reasoning` (T28,
  default `medium`) to the flags table. Say that the runs use task 4.1.0 and that question 10 is answered (option A).
- [ ] **Step 4:** run `pre-commit run --files docs/3-using/operations/proof-runs.md` and the docs check.

**Acceptance criteria:**

- [ ] The runbook holds both blocks byte for byte as above: `diff` of each fenced block of the runbook against the same
  block of this task prints nothing.
- [ ] The runbook says how to give the decisions, how to reject with the script, and that the runs use 4.1.0.

**Named test:** the `grep -cF` of step 1 (`0`, then `1` for each block) and the `diff` of the blocks;
`pre-commit run --files` on the runbook; the docs check.
**Layer:** `yggdrasil`. **Size:** M, about 120 lines. **Depends on:** T21, T24, T28 and T29 merged.

### Task gallery-runtime-T33: `niflheim-local`'s readiness record, and the pointers

**Files (in `yggdrasil`):**

- Modify: `docs/README.md` and `AGENTS.md`'s map (realms: Niflheim holds the services and the product start), this
  folder's front matter (`status: accepted`), the pointers of `gungnir`, `helheim-go`, `midgard-react`,
  `niflheim-local`, `odin` and `voluspa`. T34 added the submodule and its `go.work` line; this task only moves its
  pointer, from T03's merge to the merged `main`.
- Create: `docs/2-engineering/readiness/2026-10-23-niflheim-local.md`, from the checklist: a row for each item that
  applies to a runtime realm (`all` and `runtime`), with its evidence or `missing`

- [ ] **Step 1: the failing check.** `git submodule status niflheim-local` shows T03's merge, not the merged `main`,
  and `docs/2-engineering/readiness/2026-10-23-niflheim-local.md` does not exist.
- [ ] **Step 2:** write the readiness record (RR-10 is T34 with T27's `LEAVES`; RR-21 is `n/a`, the realm has no
  leaf).
- [ ] **Step 3:** move the pointers to the merged commits. Set this folder's front matter to `accepted`.
- [ ] **Step 4:** run the check of step 1 again, `scripts/as-bot.sh --read all scripts/check-repos.sh --check services`
  and `--check ruleset niflheim-local` in `ouroboric`, `pre-commit run --files` on every changed file, and the docs
  check. Expected: pass.

**Acceptance criteria:**

- [ ] Every module builds through `go.work`, `niflheim-local` at its merged `main` among them.
- [ ] The readiness record has no `missing` row for an `auto` item.
- [ ] The pointers are the merged commits.

**Named test:** the check of step 1 (red, then green); `go build ./...` in each module through `go.work`;
`pre-commit run --files` on the changed files; the docs check.
**Layer:** `yggdrasil`. **Size:** M, about 180 lines. **Depends on:** T30, T31, T32, T34.

### Task gallery-runtime-T34: `niflheim-local` as a submodule, early

Its own small pull request in `yggdrasil`, right after `niflheim-local`'s first (T03), so that the realm sits where
the realm store, `check-repos.sh` and the founder's smoke look for it (`yggdrasil/niflheim-local`) long before T33.
It is numbered T34 to keep the other numbers. It adds a pointer; it moves none of the others, which wait for T33.

**Files (in `yggdrasil`):**

- Modify: `.gitmodules` (`niflheim-local`, `https://github.com/ouroboric-dev/niflheim-local.git`), `go.work` (`use
  ./niflheim-local`), and the submodule `niflheim-local` at T03's merge commit

- [ ] **Step 1: the failing check.** `git submodule status niflheim-local` fails, and `go work edit -json` names no
  `niflheim-local`.
- [ ] **Step 2:** `git submodule add https://github.com/ouroboric-dev/niflheim-local.git niflheim-local`, check it
  out at T03's merge commit, and add it to `go.work`.
- [ ] **Step 3:** run the check of step 1 again, `go build ./...` in `niflheim-local` through `go.work`, and
  `pre-commit run --files .gitmodules go.work`. Expected: pass.

**Acceptance criteria:**

- [ ] `git submodule status niflheim-local` shows T03's merge commit, and `go.work` uses `./niflheim-local`.
- [ ] No other pointer moved.

**Named test:** `git submodule status niflheim-local` and `go work edit -json` (red, then green); `pre-commit run
--files .gitmodules go.work`.
**Layer:** `yggdrasil`. **Size:** S, about 10 lines. **Depends on:** T03 merged.

## Open for the builder

- **SeaweedFS and the forwarded `Host` (to verify).** The proposal assumes that its S3 API checks a signature against
  the `Host` it receives, and that it may read `X-Forwarded-Host` before `Host` (from memory, unverified), which is why
  the storage forward adds no `X-Forwarded-*` header. If T30's signed request fails, say so and propose the fix (for
  example, the API signs for the store's own address and the web leaf rewrites `Host`) before going on.
- **The S3 region and the bucket's name.** Pick a fixed region (`us-east-1`) and a bucket name that no route of the
  web app uses (for example `ygg-store`). Say which in T13 and T12; T18 uses the same.
- **Postgres's socket and port.** `start.sh` may use a TCP port on `127.0.0.1` or only the socket in the temporary
  folder. `DATABASE_URL` must work with `pgx` either way.
- **Where the release is copied out of the sandbox.** `SnapshotRunner` writes into a snapshot on the host. Say how
  T23 reads it as the host user.
- **The `s3` service name.** The founder named the store's service `s3` (2026-10-23), the name of its need. Only
  `helheim-go` names `seaweedfs` as a service today (`pack.yaml`, `pack_test.go`,
  `devcontainer/checks/go-integration.sh`'s default `YGG_S3_ENDPOINT`, `docs/architecture.md`), and T14 changes
  them. `gleipnir`'s, `gungnir`'s and `odin`'s
  own unit tests use `seaweedfs` as a made-up service name and need no change, except `odin`'s routing fixtures,
  which T08 changes. The grader starts no service (one container, `--network none`), so it cannot depend on the name.
