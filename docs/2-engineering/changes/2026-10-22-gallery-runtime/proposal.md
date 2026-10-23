---
title: The gallery's product starts in the grader (option A)
status: accepted
date: 2026-10-22
related: [delta.md, tasks.md, ../../backlog.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../plans/2026-10-22-yggdrasil-v0-phase-6/tasks.md, ../2026-10-21-leaf-run-contract/proposal.md, ../2026-10-18-realm-readiness/proposal.md, ../2026-10-17-realm-leaf-naming/proposal.md, ../2026-10-18-repo-bootstrap/tasks.md, ../../../3-using/operations/proof-runs.md]
style: spec
---

# The gallery's product starts in the grader (option A)

**Proposed 2026-10-22. Amended 2026-10-22: Postgres 18 (the founder's answer to question 5). Amended 2026-10-23: the
founder's answers to every question, T01 done, a new Niflheim realm (`niflheim-local`) that owns the product start and
the services, the founder's five product decisions, and the rehearsal's three findings.** See "History" at the end.
It makes question 10 of the [Phase 6 plan](../../plans/2026-10-22-yggdrasil-v0-phase-6/tasks.md) real, with the
option the founder chose, and fixes backlog [B-140](../../backlog.md) and B-158. It is task v0-T293, the start of
Phase 6 part two (the plan's decision 1). Run 1 (v0-H20) waits for this change to be built and merged.

**What merging this approves.** The first merge approved the direction on one condition: that the planning rehearsal
(T01 of [tasks.md](tasks.md)) shows the four assumptions below. T01 ran on 2026-10-23, and all four hold (see "What
the rehearsal showed"). Merging this amendment approves the founder's answers below, the Niflheim realm, the product
decisions and the fixes of the three findings.

## Questions for the founder

The founder chose option A, and answered every question on 2026-10-23 (question 5 on 2026-10-22). Each task follows
the answer in **bold**.

| # | Question | Decided |
| --- | --- | --- |
| 1 | How do the leaves' builds reach the grader (B-118)? | **Decided by the founder (2026-10-23): a release that Odin builds when it exports `/app`, never committed**, as assumed (see "Decided, beyond option A"). T15, T17, T22 and T23 may start. The ways not taken: commit `node_modules` and a vendored Go module folder, as the grade smoke did; or add Go to the image and build at start |
| 2 | Who owns the root `start.sh`? | **Decided by the founder (2026-10-23): a new Niflheim realm, now, in the repo `niflheim-local`.** Its flavor `local` is one machine with no cloud; a cloud flavor (such as `niflheim-vercel`) comes later. Before run 1 it holds the product start script **and the services**: Postgres and SeaweedFS move out of `helheim-go/pack.yaml`, `helheim-go` declares what it needs, and Niflheim provides the containers of the sandbox and the versions the 4.1.0 grader image bakes in. Not `midgard-react`. This closes B-078 and B-158. The founder creates the repo (T02) |
| 3 | Which hidden suite scores 4.1.0? | **Decided by the founder (2026-10-23): keep `v2`.** `task.toml` keeps `suite = "v2"`. The founder checks `v2` against the product decisions below, outside this change's tasks. No agent reads or changes a suite |
| 4 | Where does the product keep its data in the grader? | **Decided by the founder (2026-10-23): under `/app/.data/`**, in `.gitignore`, never committed. A restart of `start.sh` in the same grading copy keeps it. The rehearsal's planner chose `/app/data/`; the start script and the prompts name `/app/.data/` |
| 5 | Which Postgres? | **Decided by the founder (2026-10-22): PostgreSQL 18.** With question 2, the pin lives in Niflheim's services, not in `helheim-go`: the sandbox's container image is `postgres:18.x` by digest (T11), and the grader image installs PostgreSQL 18 for Ubuntu 24.04 from the PostgreSQL project at one pinned package version (T21). The main repository keeps only the newest package of each version, so the pin comes from `apt-archive.postgresql.org` or a dated snapshot (to verify in T21). The major version is the same in both; the minor may differ, and the check of T27 prints both |
| 6 | What happens to 4.0.0? | **Decided by the founder (2026-10-23): 4.1.0 replaces it in place.** 4.0.0 stays in `mimir`'s git history, and the README lists both versions. A run of 4.0.0 is graded against 4.0.0's image, as today, because the task version and the image travel together |
| 7 | Photo bytes and object versioning in the grading copy | **Decided by the founder (2026-10-23).** While graded, photo bytes pass through the web server's forward on port 3000, never through the API; production stays direct to storage. Reviewers treat an API that streams a photo or a zip as a violation of spec §9.3 (delta). Object versioning is **best effort**: on if SeaweedFS 4.45 supports it, else a recorded deviation; T30 checks |

## Why

The frozen brief and the realms describe two different machines. Read as files:

- **The brief** (`mimir/client-gallery-lite/instruction.md` §6, task 4.0.0) asks for one machine. Grading copies
  only `/app` onto a fresh copy of the task image and runs `/app/start.sh` as an ordinary user. Within 2 minutes the
  product serves everything on port 3000, on all interfaces. It uses no outside service, account or key. It may write
  only in `/app` and the temporary folder.
- **The task image** (`environment/Dockerfile`) is Playwright 1.63.0 on Ubuntu 24.04, with Node 24, npm, Python 3.12,
  git and curl. It has no Postgres, no SeaweedFS and no Go. The grader runs with `--network none`
  (`gleipnir/sandbox/grade.go`), so it has no network and reaches the product on loopback.
- **The realms** build a Go API leaf (`helheim-go`) and a React web leaf (`midgard-react`). Spec §9.2 and §9.3 give
  the API Postgres and the photos an S3 store. Today `helheim-go/pack.yaml` names both services as container images
  (`postgres:17.10-bookworm` and `seaweedfs:4.45`), so a language recipe pins a database, a store and their
  versions (B-158). Photo bytes go between the browser and the S3 API, never through the API.
- **The leaves' run scripts** (change [leaf-run-contract](../2026-10-21-leaf-run-contract/proposal.md)) build at
  start. The API's `run.sh` runs `go build` with `GOPROXY=off`: it needs Go and the module cache. The web leaf's
  `run.sh` needs `node_modules` and serves with `vite preview --host 127.0.0.1` (B-117).
- **The grader's `/app`** is the committed files of the project and of each leaf
  (`odin/internal/run/grade.go`, `ExportApp`). Build outputs and installed packages are not in git, so they never reach
  the grader (B-118). The export refuses anything that is not a regular file, and holds at most 32 MiB per file and
  256 MiB in all (`odin/internal/snapshot/snapshot.go`). `ygg bridge` uploads the same export to Harbor.
- **No one writes the root `start.sh`.** The leaf run contract left it to an infra realm that does not exist
  (B-078). Agents work only in their leaf, so no task can write it. Niflheim is that realm now (question 2).
- **The acceptance run** (`midgard-react/devcontainer/checks/accept-e2e.sh`) starts the API with `PORT` and
  `DATABASE_URL` only, and serves the web leaf with a baked `vite.config.ts` that forwards only `/api`. Under the
  contract below, an upload in an end-to-end spec would fail at every pointer move.

Read together, a product built as the realms' design says cannot start in the grader.

## What the rehearsal showed

v0-H19's first rehearsal left no record. T01 ran it again on 2026-10-23, on today's prompts: run
`20261022-205939-1301d4`, left stopped at `plan-gate`, its folder kept on the founder's machine. Aggregate facts only:

- **The four assumptions hold.** The planner designed two leaves, `repos/api` on `helheim-go` and `repos/web` on
  `midgard-react` (consuming the API); Postgres and an S3-compatible store; `/app/start.sh` starts everything; the web
  server on port 3000 forwards `/api/*`. No other service at run time.
- **The plan:** 29 tasks, 17 in `repos/api` and 12 in `repos/web` by their Layer field; 23 of size M and 6 of size S;
  none L. Its T001 puts `/app/start.sh` in `repos/api`: the table's "plan has its own `start.sh`" row of T01, expected
  until the prompts change (T19). The leaves file also says that the API serves the built web app, which T19's
  prompts rule out.
- **The data folder:** the spec put the product's data, and the reset outbox, under `/app/data/`. Question 4 names
  `/app/.data/`.
- **Cost:** 55 turns to `plan-gate`, $2.52 at API prices. The planner ran on a subscription; what was billed is the
  reviewer's Qwen sessions, a few cents.
- **Three findings,** below: an approval note does not reach later stages (F1); the conformance reviewer ran out its
  session deadline once (F2); the proof-run script has no reject (F3).

The assumptions, as the first version of this proposal stated them:

1. The planner designs two leaves: a React web leaf at `repos/web` on `midgard-react`, and a Go API leaf at
   `repos/api` on `helheim-go`.
2. The API keeps its data in Postgres.
3. The photos live in an S3-compatible store, reached with presigned URLs, and their bytes do not pass through the
   API.
4. The design needs no other service at run time.

## Decided: option A

- **Option A (the founder, 2026-10-22).** Bake Postgres and SeaweedFS into a new task version of the grader image,
  `4.1.0`, with the same brief and the same brief hash. The factory writes a root `start.sh` that starts the whole
  product, the services and both leaves, and serves everything on port 3000 on all interfaces, as `instruction.md` §6
  asks.
- **Options B and C are not taken.** The realms keep their stack (Postgres, S3). The planner is not told to ignore the
  realms' docs.
- **The task image gains the services and nothing else.** `client-gallery-lite` 4.1.0 adds PostgreSQL 18 (`initdb`,
  `postgres`, `pg_ctl`, `createdb`, `psql`) and SeaweedFS 4.45 (`weed`) to the image, on the `PATH` of the user `app`.
  It adds no Go, no project package and no factory script: the image is a public benchmark machine, and any factory
  may use it.

## Decided, beyond option A

The founder said yes to each of these on 2026-10-23 (the questions above).

- **A leaf reaches the grader as a release, built by the factory and never committed (question 1, B-118).** Each build
  realm's template ships `release.sh`. Run in the leaf, with `OUT` set to an empty folder, it writes into `OUT`
  everything the leaf needs to start with no network and no tool beyond the task image, and `OUT/run.sh`, which starts
  that copy. It may install packages first, through the realm's egress, as the acceptance run does. The API's release
  is a static Go binary. The web leaf's release is the built bundle and a small server with no package. The founder's
  rule of 2026-10-21 holds: no binaries in git.
- **Odin builds the release when it exports `/app` (question 1).** `ygg grade` and `ygg bridge` both export through
  `ExportApp`. It runs each leaf's `release.sh` in the project's acceptance sandbox, on a snapshot of the commits it
  exports, and puts each release at `/app/.ygg/release/<leaf>/`. No agent runs there, and the sandbox stops before the
  grader starts. A release that fails fails the grade, never as a score of 0. A release has its own bound, not the
  snapshot's 32 MiB per file, because a static Go binary can come near 32 MiB.
- **Niflheim owns the product start and the services (question 2, B-078, B-158).** `niflheim-local` is a runtime
  realm: it provides no leaf and no stack. Its `pack.yaml` names the services (`postgres`, Postgres 18 by digest;
  `s3`, SeaweedFS 4.45 by digest), says which need each one provides (`provides`), and names the product start
  script (`product.start`, `templates/product/start.sh`).
  - A build realm declares its needs instead of images: `helheim-go` says `needs: [postgres, s3]`, "a
    Postgres-compatible database" and "an S3 API", from a fixed list in `gungnir`. It names no service.
  - A project pins its runtime realm once, beside its graph: the spec stage writes `runtime` in `docs/leaves.yaml`,
    and Odin's `init` records it in `umbrella.yaml` (`runtime`, `runtime_version`). The spec prompt names
    `niflheim-local` 0.1.0, the only runtime realm.
  - Odin gives a leaf's sandbox, and the snapshot's, the runtime realm's service for each need of the realms
    involved, under the service's own name, so the checks reach `postgres:5432` and `s3:8333`: each need and the
    service that provides it share one name (the founder, 2026-10-23). Today `helheim-go` names the store's service
    `seaweedfs`; T14 moves its checks to `s3`. A need
    that the runtime realm does not provide, or a need with no runtime realm, stops the run before any leaf or leaf
    sandbox exists: at the `ready` node, which reads `docs/leaves.yaml`, and again at `init`.
  - Odin's `init` writes the runtime realm's product start at the project root as `start.sh`, executable, and commits
    it, as it commits `.gitignore`. No agent changes it. The script finds the leaves at the fixed paths `repos/api`
    and `repos/web`, the paths the spec prompt already requires and the acceptance run already uses. It does not read
    `docs/leaves.yaml`.
  - The grader image follows Niflheim's versions: the same SeaweedFS digest and the same Postgres major. A check in
    `ouroboric` (`check-repos.sh --check services`) compares `niflheim-local/pack.yaml`, the 4.1.0 Dockerfile and the
    Postgres image of `helheim-go`'s template CI, and fails on a difference.
  - **Decided by the founder (2026-10-23):** the names `needs`, `provides` and `runtime`, the two needs `postgres`
    and `s3`, the service names `postgres` and `s3`, and that the spec stage names the runtime realm in
    `docs/leaves.yaml`, recorded in `umbrella.yaml`.
- **The web leaf serves on `HOST` (B-117).** The web template gets `serve.mjs`, a server on Node's standard library.
  It serves the bundle, forwards `/api/` to the API and forwards the photo store's path to the S3 API. Both `run.sh`
  and the release use it. It listens on `HOST`, by default `127.0.0.1`. The API listens on `HOST` too, when it is set.
  The product start gives the web leaf `HOST=0.0.0.0` and `PORT=3000`.
- **Everything the browser loads is on port 3000.** The API signs storage URLs for the address the product was
  reached at, on the bucket's path. The web leaf forwards that path to SeaweedFS unchanged, with the `Host` header
  kept and no `X-Forwarded-*` header added, so that the signature can still match (to verify: see "Risk"). Every
  other port listens on `127.0.0.1` only.
- **The leaves read fixed names.** The API reads `PORT`, `HOST`, `DATABASE_URL`, `DATA_DIR`, `S3_ENDPOINT`,
  `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID` and `S3_SECRET_ACCESS_KEY`. The web leaf reads `PORT`, `HOST`,
  `API_URL`, `S3_ENDPOINT` and `S3_BUCKET`. The product start and the acceptance run set them. `DATA_DIR` is the one
  folder the API may write files in, such as the reset outbox: `/app/.data/api` while graded (question 4; decided by the
  founder, 2026-10-23). The S3 key pair is made at each start. It is kept only in SeaweedFS's identity
  file under `/app/.data/`, readable by `app` alone, and in the leaves' environment; never in git or in a log.
  SeaweedFS refuses a request without it.
- **The acceptance run follows the same contract.** It gives the API the `S3_*` names (the sandbox's SeaweedFS), and
  serves the web leaf with the realm's baked copy of `serve.mjs`, so `/<bucket>/` and `/api/` behave at every pointer
  move as they do in the grader. It tells the specs that a real store is behind `/<bucket>/` (`YGG_E2E_STORE=1`); the
  e2e rung, which has no store, does not.
- **The planner is told.** Voluspa's spec and plan prompts say that the product runs on one machine, that `start.sh`
  and the services are the factory's, that the web leaf serves port 3000 and the API never serves the web app, that
  data lives under `/app/.data/`, and which names the leaves read. No task writes a file outside its leaf.

## The founder's product decisions

The founder answered the design's open questions at the rehearsal's design gate (2026-10-22). They are the product
owner's decisions for the gallery, and **every proof run gives them word for word**, so that two runs are built to the
same product and `ygg metrics --compare` compares two factories. The list below is a summary; the authoritative text is
the two blocks of T32 in [tasks.md](tasks.md), which the runbook copies byte for byte:

1. Password reset: primarily by email, with security questions set at sign-up as the second way. The email sender is
   configurable; with none configured, reset emails are written to a local outbox file under `/app/.data/` that the
   operator can read.
2. Photographers can delete photos, galleries and their own account.
3. The client's email step says that the photographer will see the email entered.
4. A storage cap of 10 GB per photographer by default, configurable per photographer.
5. A change of a gallery password or PIN logs out the clients already in; a photographer's password change logs out
   their other sessions.

The text the founder approved is the design-gate note and the spec-gate rejection reason of T01. T32 copies both into
the [proof-runs runbook](../../../3-using/operations/proof-runs.md), with one change: "a local outbox file under /app"
becomes "under /app/.data/". The founder made that change: the decisions of 2026-10-23 write decision 1 as "a local
outbox file under /app/.data/", with question 4. With F1 fixed, the runbook gives the
decisions as the note of the design-gate approval; the spec-gate reason stays as the fallback for a spec that still
lacks them.

## The rehearsal's findings, and how this change fixes them

- **F1 (odin): an approval note does not reach later stages.** `ygg approve --note` records the note on the
  `gate_approved` event, and nothing reads it again. Only a rejection's reason reaches a stage (`state.Reasons`, read
  by `runAgent` in `internal/engine/engine.go`). So the spec stage and the design doc lacked the founder's design-gate
  answers, the spec said "Deviations from the design doc: None", and the founder had to reject the spec with the same
  text. **Fix (T24):** the note of a gate's approval is kept in the run's state and reaches the prompt of every later agent
  session (agent and scratch nodes, implementers, reviewers) as "the product owner's decisions", in order. A
  rejection that sends the run back before a gate drops that gate's note, because the gate is met again. The runbook
  says how to give them (T32). A note given at another stop (a loop that gave up, `policy-violation`, `shrink-guard`)
  is about that stop and stays on its event; a note with a control character is refused, so a note is one line.
- **F2 (ouroboric, voluspa): the conformance reviewer ran out its session deadline.** The reviewer (opencode,
  `openrouter/qwen/qwen3.8-27b`) read the files in 6 seconds and then produced nothing for its whole 600-second
  deadline (`timeout: 10m` on the `conformance` node of `voluspa/software/graph.yaml`) on a review of about 62 KB: the
  verdict call never returned, and the run failed. The resume passed in 244 seconds and 10 turns. Run 1 has 29 tasks
  with three reviewers each. **Fix (the founder, 2026-10-23):** the proof config sets `reasoning: medium` on the
  reviewer role (`gungnir`'s role setting: `low`, `medium`, `high`, `off`; unset means `high`), with a flag to change
  it and a dry-run line that shows it (T28); and the `conformance` node's deadline goes from 10 to 20 minutes (T20);
  the task reviewers keep 10 minutes. Neither value is tested on this model: run 1's events show whether they hold.
- **F3 (ouroboric): `ygg-proof-run.sh` has no reject.** `ygg reject` advances the run at once (`engine.Reject`, then
  the CLI advances), so it needs the credentials, and the founder had to run the raw command. **Fix (T29):**
  `--continue RUN --reject GATE --reason TEXT`, with the same timeout, credentials subshell, filter and evidence as
  `--approve`, and tests.

## What changes

- **`mimir`** (the founder's): `client-gallery-lite` 4.1.0 replaces 4.0.0 in place. `instruction.md` is unchanged and
  keeps its hash. `task.toml` says `4.1.0` and keeps `suite = "v2"`. The Dockerfile turns off the Debian packaging's
  automatic cluster (`create_main_cluster = false` in `createcluster.conf`), then installs PostgreSQL 18 at one pinned
  package version, and copies `weed` from the `seaweedfs:4.45` image by the digest `niflheim-local/pack.yaml` pins.
  The README lists 4.0.0 and 4.1.0.
- **`niflheim-local`** (new): created by the founder (`new-repo.sh`); a scaffold like the other realm repos
  (`scaffold-component.sh --mit-templates`); `pack.yaml` with the services, `provides` and `product.start`;
  `templates/product/start.sh`. Tests load the pack and start the script with stand-ins.
- **`gungnir`:** the pack schema takes `product.start`, `needs` and `provides`; the leaves file and the umbrella take
  the runtime pin.
- **`helheim-go`:** the API listens on `HOST` when it is set; the template's `AGENTS.md` and the implementer prompt
  name the runtime variables and say how the bucket is made; the pack drops its services and declares
  `needs: [postgres, s3]`; the template's CI runs Postgres 18, the image Niflheim pins; `templates/api/release.sh` and
  a test that starts the release with no Go on the `PATH`.
- **`midgard-react`:** `templates/web/serve.mjs` and a `run.sh` that uses it; `templates/web/release.sh`; the
  acceptance run on the new contract. Tests start each one. It no longer owns the product start.
- **`odin`:** the runtime realm joins the run; a sandbox gets the services of the needs from it; `init` writes and
  commits the product start; `ExportApp` builds the releases in the acceptance sandbox and adds them to the export; an
  approval's note reaches later stages (F1).
- **`voluspa`:** the `spec` and `plan` prompts name the runtime and the runtime pin; the reviewers' prompt names the
  photo rule; the `conformance` node's deadline is 20 minutes (F2).
- **`ouroboric`:** `scripts/ygg-smoke-runtime.sh`, which starts a product made from the templates and Niflheim's
  start script in the 4.1.0 image, as `app`, on a Podman `--internal` network, and checks port 3000 and the
  listeners; `check-repos.sh --check services` and `niflheim-local` in its lists; the proof config's reviewer
  reasoning (F2); `ygg-proof-run.sh --reject` (F3).
- **`yggdrasil`:** spec §6.1, §7.2, §9.3, §9.4 and §11 take the delta; the readiness checklist gets RR-24 to RR-27
  and a `runtime` kind; the backlog, the proof-runs runbook (the decisions, `--reject`, 4.1.0) and the pointers follow;
  `niflheim-local` becomes a submodule early, right after its scaffold (T34).

## What the backlog items become

- **B-078** (no root `start.sh`): fixed by the product start script of `niflheim-local`. Odin's `init` writes it at
  the project root, and no agent changes it.
- **B-117** (the web leaf serves on loopback only): fixed. The web leaf listens on `HOST`, by default `127.0.0.1`, and
  the product start sets `0.0.0.0` for port 3000 alone.
- **B-118** (a leaf's dependencies do not reach the grader): fixed for the services by the 4.1.0 image, and for the
  leaves by the release that Odin builds at export, with nothing committed (question 1). The grade smoke's workaround
  (committing `node_modules`) stays in the smoke only.
- **B-140** (the brief's runtime and the realms' do not fit): fixed by this change when its tasks merge.
- **B-158** (the realms pin the stack's services, and the grader image copies them): the founder chose candidate (a)
  on 2026-10-23, before run 1 rather than after it. Fixed: `niflheim-local` owns the services and their versions,
  `helheim-go` declares needs, and `check-repos.sh --check services` keeps the grader image on the same versions.
- **B-116** (a grade per leaf): unchanged. A leaf can now be started alone from its release, which a per-leaf suite
  would need. The per-leaf suite in `huldra` is still the founder's.

## Not in this change

- **The hidden suite.** It is never part of a task, and no task reads, lists or searches `huldra` or
  `~/ygg-it/hidden-suites`. Any change to scoring stays with the founder. The founder keeps `v2` (question 3) and
  checks it against the product decisions outside this change's tasks.
- **The release in the acceptance run.** The acceptance run builds and starts the leaves from source, as today. Making
  it build and start the release, so that the ladder exercises `release.sh`, is a later change; T31 files it.
- **A store in the web end-to-end rung.** In a task's loop the web leaf runs against a mock of the API, with no store.
  This change does not add one. T18 tells each spec whether a real store is behind `/<bucket>/`
  (`YGG_E2E_STORE=1` in the acceptance run, unset in the rung), and the implementer prompt says to stub the store only
  when it is unset, so the acceptance run exercises the real forward.
- **The development sandbox's SeaweedFS.** It runs with no S3 identities, so it accepts anonymous requests. The
  product start gives SeaweedFS an identity; the sandbox is not changed here, and T31 files the gap.
- **Other product shapes.** `niflheim-local`'s product start knows the gallery's shape: at most one API leaf at
  `repos/api` and one web leaf at `repos/web`, as the acceptance run does. A product of another shape needs its own
  start.
- **Other runtime realms.** A cloud flavor (`niflheim-vercel`, say), deployment and operations are later. A project
  pins at most one runtime realm.
- **Persistence across machines.** Data lives under `/app/.data/` for the life of the grading copy.

## Impact

- **Repos:** `mimir` (the founder's), `niflheim-local` (new), `gungnir`, `helheim-go`, `midgard-react`, `odin`,
  `voluspa`, `ouroboric`, `yggdrasil`.
- **Order:** T01 is done. The founder creates `niflheim-local` (T02), and its scaffold (T03) merges whenever it is
  ready; right after it, a small `yggdrasil` pull request adds it as a submodule (T34). Then `gungnir` (T04 to T06). Then `odin`'s first pull request (T07 to T10, with the new `gungnir` pinned),
  because `gungnir`'s pack schema refuses unknown keys (`additionalProperties: false`): an `odin` on the old pin cannot
  load a `helheim-go` whose `pack.yaml` names `needs`, and an `odin` that does not resolve needs would give a
  `helheim-go` with no services an empty sandbox. Then the repos that pin the new `gungnir` (`niflheim-local`'s
  content, `helheim-go`) and the others (`midgard-react`, `voluspa`, `mimir`), in any order with the dependencies of
  tasks.md. Then `odin`'s second pull request (the release, F1, the real-realm fixtures), `ouroboric`'s second (the
  runtime smoke, the services check), and `yggdrasil`'s second pull request last. `ouroboric`'s first pull request (F2's reasoning, F3's
  reject) depends on nothing and may merge at any time. The umbrella's
  pointers do not move until T33 (T34 adds `niflheim-local`'s and moves none). Until then, T30 checks out each repo at its merged `main` and uses a `ygg` built
  from that `odin`.
- **Approval points:** none added. The release sandbox runs no agent. An approval's note now reaches later stages;
  the approval points themselves do not change.
- **The proof runs:** run 1 and every later run use task 4.1.0 and the five product decisions, word for word.
  `ygg-proof-run.sh` reads the suite from `task.toml`, so the suite needs no change there.
- **Other factories:** a Harbor run of 4.1.0 builds on the same image, with Postgres and SeaweedFS available. The
  brief is the same, so a factory that ignores them is graded as before.

## Risk

- **A new repo and more Odin work before run 1.** Niflheim adds a repo, a scaffold, three `gungnir` tasks and four
  `odin` tasks (T07 to T10, T25) to the change. The founder chose this over keeping B-158 until after run 1. Each task stays under 400
  lines, and run 1 waits for all of them.
- **The planner forgets the runtime pin.** Then the run stops at the `ready` node, before any leaf or leaf sandbox
  exists, because `helheim-go` needs services that no runtime realm provides; the message names the missing `runtime`
  in `docs/leaves.yaml`. `ready` runs after the plan stage, so a forgotten pin is found after the plan is paid for
  (the scratch sandboxes of design, spec and plan have run). T19's test keeps the pin in the spec prompt's example, and
  the founder reads `docs/leaves.yaml` at the spec gate.
- **Two forms of one Postgres.** The sandbox runs Postgres 18 from a Debian container image, the grader from an
  Ubuntu package. Their minors may differ. T27's check fails on a different major and prints both minors.
- **The planner designs something else.** T01 showed the four assumptions on today's prompts. Run 1 is the first plan
  made with the new prompts (T19); if it leaves them, the run's gates show it before any task starts.
- **The decisions differ between runs.** A run given other words is built to another product, and its comparison
  means little. The runbook holds the text, and T32 says to paste it, not to retype it.
- **An approval note is a decision (F1).** Every note on a gate's approval reaches every later stage, so "ok" becomes
  a decision too. The runbook says to give a note at a gate only for a decision.
- **A lower reasoning effort for the reviewers (F2).** `medium` may still run out a deadline, or make reviews
  shallower than `high`. Neither `medium` nor the 20-minute deadline is tested on `openrouter/qwen/qwen3.8-27b`: run
  1's events (a session that ends at its deadline, the reviewers' findings) show whether they hold, and the reviewer
  bench (`ygg-reviewer-bench.sh`) can measure them.
- **The signature through the forward (to verify).** The proposal assumes that SeaweedFS checks a presigned URL
  against the `Host` header it receives, so that forwarding the path unchanged keeps the signature valid. SeaweedFS's
  SigV4 check may read `X-Forwarded-Host` and `X-Forwarded-Port` before `Host`; that is from memory and unverified.
  So the storage forward adds no `X-Forwarded-*` header. The runtime smoke (T26, T30) must show a signed request
  succeeding through port 3000.
- **`release.sh` is in the leaf and unprotected.** An agent can change it, and nothing in the ladder or the acceptance
  run runs it, so a broken release shows only at export. The implementer prompts say (T15, T17): keep `release.sh`
  working, and change it only when the leaf's build changes. T31 files a backlog item for a check that runs it.
- **Port clashes.** SeaweedFS's volume server listens on 8080 by default, the API's port. The product start must move
  it.
- **Postgres as `app`.** `initdb` refuses root, which suits the brief. The 2-minute limit holds `initdb`, both
  services and both leaves; the runtime smoke measures it.
- **Ownership of the release's files.** A file written in a rootless sandbox may belong to a subuid on the host, as
  in B-139. T23 must copy the release out as the host user.
- **One more sandbox start per export.** The release adds a sandbox start to `ygg grade` and `ygg bridge`, with B-051's
  hang. Odin keeps a release by the commits it was built from, so a second grade reuses it.

## The amendment's open points, answered

The founder answered the six open points of this amendment on 2026-10-23. None is open now.

1. **The runtime pin:** `runtime` in `docs/leaves.yaml`, recorded in `umbrella.yaml`; the names `needs`, `provides`
   and `runtime` stand.
2. **`DATA_DIR`:** confirmed, `/app/.data/api` while graded.
3. **F2:** the reviewer's `reasoning: medium`, not `low`, and the conformance deadline of 20 minutes (T28, T20).
   Neither value is tested on this model; run 1's events show whether they hold.
4. **The store's service is named `s3`,** like its need; the image stays SeaweedFS 4.45 by digest.
5. **Web serving:** the web leaf serves port 3000 with the realm's baked `serve.mjs`; the API never serves the web app
   (T19).
6. **The submodule comes early:** T34 adds `niflheim-local` to the umbrella right after T03; T33 only moves its
   pointer.

## History

- **2026-10-22, proposed** (yggdrasil#98): option A, with questions 1 to 7 assumed.
- **2026-10-22, amended** (yggdrasil#99): Postgres 18 (question 5), in the grader image and, then, in `helheim-go`.
- **2026-10-23, amended:** the founder answered questions 1 to 4, 6 and 7, and T01 ran. Question 2's answer is a new
  Niflheim realm, `niflheim-local`, that owns the product start and the services; the Postgres 18 pin moves from
  `helheim-go` to it. The founder's five product decisions are recorded, and every proof run gives them word for
  word. The rehearsal's three findings get tasks (F1: T24; F2: T20, T28; F3: T29). The tasks are renumbered: see the
  table of [tasks.md](tasks.md), which maps the old numbers to the new. The review of the amendment split the services
  resolution in two (T08, T09), added the real-realm fixtures task (T25), and split `ouroboric`'s pull request in two.
- **2026-10-23, the founder's answers to the open points** (above): `reasoning: medium`, the service name `s3`, and
  the early submodule (T34).
