---
title: The gallery's product starts in the grader (option A)
status: draft
date: 2026-10-22
related: [delta.md, tasks.md, ../../backlog.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../plans/2026-10-22-yggdrasil-v0-phase-6/tasks.md, ../2026-10-21-leaf-run-contract/proposal.md, ../2026-10-18-realm-readiness/proposal.md]
style: spec
---

# The gallery's product starts in the grader (option A)

**Proposed 2026-10-22.** It makes question 10 of the
[Phase 6 plan](../../plans/2026-10-22-yggdrasil-v0-phase-6/tasks.md) real, with the option the founder chose, and
fixes backlog [B-140](../../backlog.md). It is task v0-T293, the start of Phase 6 part two (the plan's decision 1).
Run 1 (v0-H20) waits for this change to be built and merged.

**What merging this approves.** Merging approves the direction on one condition: the planning rehearsal (T01 of
[tasks.md](tasks.md)) shows the four assumptions below. If it does not, T01's table says what to do, and no other task
starts. Running T01 before the merge is better: then the merge approves a direction the rehearsal has already checked.

## Questions for the founder

The founder chose option A. Everything in this proposal beyond option A is **assumed** and needs the founder's yes.
Each task assumes the answer in **bold**. Say so on the pull request if you want another.

| # | Question | Assumed |
| --- | --- | --- |
| 1 | How do the leaves' builds reach the grader (B-118)? | **A release that Odin builds when it exports `/app`, never committed** (see "Assumed, beyond option A"). B-118 named two other ways: a baked image, or a vendored folder. In practice: commit `node_modules` and a vendored Go module folder, as the grade smoke did, which means large repositories and platform binaries in git; or add Go to the image too and build at start, which still needs `node_modules`. **T05, T07, T12 and T13 do not start until this is answered** |
| 2 | Who owns the root `start.sh` until an infra realm exists? | **`midgard-react`**, which holds the acceptance run. The other ways: a new infra realm now; or Voluspa's graph pack, which today holds no recipe |
| 3 | Which hidden suite scores 4.1.0? | **The founder's decision.** T02 keeps `suite = "v2"` in `task.toml` unless the founder names another. No agent reads or changes a suite |
| 4 | Where does the product keep its data in the grader? | **Under `/app/.data/`**, so a restart of `start.sh` in the same grading copy keeps it. The other way: the temporary folder, fresh at each start |
| 5 | Which Postgres? | **PostgreSQL 17 for Ubuntu 24.04 from the PostgreSQL project, at one pinned package version.** The main repository keeps only the newest package of each version, so the pin comes from `apt-archive.postgresql.org` or a dated snapshot (to verify when T02 is built). The realm's sandbox runs 17.10 on Debian. The minor version may differ; the major may not |
| 6 | What happens to 4.0.0? | **It stays in the repository's history, and the README lists 4.1.0.** A run of 4.0.0 is graded against 4.0.0's image, as today, because the task version and the image travel together |
| 7 | Photo bytes and object versioning in the grading copy | **Allowed and to verify.** In grading, photo bytes pass through the web leaf's forward on port 3000, because the brief asks for one port; they still never pass through the API, and production stays direct to storage (delta §9.3). Object versioning is turned on when the bucket is made at start, if SeaweedFS 4.45 supports it (to verify in T16); if it does not, the grading copy runs without it, and that is written as a deviation |

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
  the API Postgres and the photos an S3 store. `helheim-go/pack.yaml` names both services as container images
  (`postgres:17.10-bookworm`, `seaweedfs:4.45`). Photo bytes go between the browser and the S3 API, never through the
  API.
- **The leaves' run scripts** (change [leaf-run-contract](../2026-10-21-leaf-run-contract/proposal.md)) build at
  start. The API's `run.sh` runs `go build` with `GOPROXY=off`: it needs Go and the module cache. The web leaf's
  `run.sh` needs `node_modules` and serves with `vite preview --host 127.0.0.1` (B-117).
- **The grader's `/app`** is the committed files of the project and of each leaf
  (`odin/internal/run/grade.go`, `ExportApp`). Build outputs and installed packages are not in git, so they never reach
  the grader (B-118). The export refuses anything that is not a regular file, and holds at most 32 MiB per file and
  256 MiB in all (`odin/internal/snapshot/snapshot.go`). `ygg bridge` uploads the same export to Harbor.
- **No one writes the root `start.sh`.** The leaf run contract left it to an infra realm that does not exist
  (B-078). Agents work only in their leaf, so no task can write it.
- **The acceptance run** (`midgard-react/devcontainer/checks/accept-e2e.sh`) starts the API with `PORT` and
  `DATABASE_URL` only, and serves the web leaf with a baked `vite.config.ts` that forwards only `/api`. Under the
  contract below, an upload in an end-to-end spec would fail at every pointer move.

Read together, a product built as the realms' design says cannot start in the grader.

## What v0-H19 showed

**Nothing that was recorded.** The founder ran the planning rehearsal, but its run folder was cleaned up, and no
journal entry or ledger line holds its outcome. This proposal does not say what the planner designed. It rests on the
realms' documented design (above) and states its assumptions. T01 runs the rehearsal again, checks its design and spec
gates against these assumptions, and keeps the answers.

The assumptions:

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
- **The task image gains the services and nothing else.** `client-gallery-lite` 4.1.0 adds PostgreSQL 17 (`initdb`,
  `postgres`, `pg_ctl`, `createdb`, `psql`) and SeaweedFS 4.45 (`weed`) to the image, on the `PATH` of the user `app`.
  It adds no Go, no project package and no factory script: the image is a public benchmark machine, and any factory
  may use it.

## Assumed, beyond option A

These make option A work. Each needs the founder's yes (the questions above).

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
- **The root `start.sh` is the product start script of the web realm (question 2, B-078).** `midgard-react` already
  holds the acceptance run, which starts the whole product. It ships `templates/product/start.sh` and names it in
  `pack.yaml` (`product.start`). Odin's `init` node writes it at the project root, executable, and commits it, as it
  commits `.gitignore`. No agent changes it. An infra realm may take it over later. The script finds the leaves at the
  fixed paths `repos/api` and `repos/web`, the paths the spec prompt already requires and the acceptance run already
  uses. It does not read `docs/leaves.yaml`.
- **The web leaf serves on `HOST` (B-117).** The web template gets `serve.mjs`, a server on Node's standard library.
  It serves the bundle, forwards `/api/` to the API and forwards the photo store's path to the S3 API. Both `run.sh`
  and the release use it. It listens on `HOST`, by default `127.0.0.1`. The API listens on `HOST` too, when it is set.
  The product start gives the web leaf `HOST=0.0.0.0` and `PORT=3000`.
- **Everything the browser loads is on port 3000.** The API signs storage URLs for the address the product was
  reached at, on the bucket's path. The web leaf forwards that path to SeaweedFS unchanged, with the `Host` header
  kept and no `X-Forwarded-*` header added, so that the signature can still match (to verify: see "Risk"). Every
  other port listens on `127.0.0.1` only.
- **The leaves read fixed names.** The API reads `PORT`, `HOST`, `DATABASE_URL`, `S3_ENDPOINT`, `S3_REGION`,
  `S3_BUCKET`, `S3_ACCESS_KEY_ID` and `S3_SECRET_ACCESS_KEY`. The web leaf reads `PORT`, `HOST`, `API_URL`,
  `S3_ENDPOINT` and `S3_BUCKET`. The product start and the acceptance run set them. The S3 key pair is made at each
  start. It is kept only in SeaweedFS's identity file under `/app/.data/`, readable by `app` alone, and in the leaves'
  environment; never in git or in a log. SeaweedFS refuses a request without it.
- **The acceptance run follows the same contract.** It gives the API the `S3_*` names (the sandbox's SeaweedFS), and
  serves the web leaf with the realm's baked copy of `serve.mjs`, so `/<bucket>/` and `/api/` behave at every pointer
  move as they do in the grader. It tells the specs that a real store is behind `/<bucket>/` (`YGG_E2E_STORE=1`); the
  e2e rung, which has no store, does not.
- **The planner is told.** Voluspa's spec and plan prompts say that the product runs on one machine, that `start.sh`
  and the services are the factory's, and which names the leaves read. No task writes a file outside its leaf.

## What changes

- **`mimir`** (the founder's): `client-gallery-lite` 4.1.0. `instruction.md` is unchanged and keeps its hash.
  `task.toml` says `4.1.0`. The Dockerfile turns off the Debian packaging's automatic cluster
  (`create_main_cluster = false` in `createcluster.conf`), then installs PostgreSQL 17 at one pinned package version
  (question 5), and copies `weed` from the `seaweedfs:4.45` image by digest, the same digest `helheim-go/pack.yaml`
  pins. The README's table gets the new version.
- **`gungnir`:** the pack schema takes an optional `product.start`, a path inside the pack.
- **`helheim-go`:** the API listens on `HOST` when it is set; the template's `AGENTS.md` and the implementer prompt
  name the runtime variables and say how the bucket is made. Then, once question 1 is answered,
  `templates/api/release.sh` and a test that starts the release with no Go on the `PATH`.
- **`midgard-react`:** `templates/web/serve.mjs` and a `run.sh` that uses it; `templates/web/release.sh` (once
  question 1 is answered); `product.start` in `pack.yaml`; `templates/product/start.sh`; the acceptance run on the new
  contract. Tests start each one.
- **`odin`:** `init` writes and commits the product start. Once question 1 is answered, `ExportApp` builds the
  releases in the acceptance sandbox and adds them to the export.
- **`voluspa`:** the `spec` and `plan` prompts name the runtime.
- **`ouroboric`:** `scripts/ygg-smoke-runtime.sh`. It starts a product made from both templates in the 4.1.0 image, as
  `app`, on a Podman `--internal` network (an address, no route out). It reaches port 3000 from a second container on
  that network, and checks with `ss -ltn` that every other listener is bound to `127.0.0.1`.
- **`yggdrasil`:** spec §9.3, §9.4 and §11 take the delta; the readiness checklist gets RR-24 and RR-25; the backlog,
  the proof-runs runbook and the pointers follow.

## What the backlog items become

- **B-078** (no root `start.sh`): fixed by the product start script. `midgard-react` ships it, Odin's `init` writes it
  at the project root, and no agent changes it. The infra realm stays later, and may take the script over.
- **B-117** (the web leaf serves on loopback only): fixed. The web leaf listens on `HOST`, by default `127.0.0.1`, and
  the product start sets `0.0.0.0` for port 3000 alone.
- **B-118** (a leaf's dependencies do not reach the grader): fixed for the services by the 4.1.0 image. For the
  leaves, fixed by the answer to question 1: as assumed, the release that Odin builds at export, with nothing
  committed. The grade smoke's workaround (committing `node_modules`) stays in the smoke only.
- **B-140** (the brief's runtime and the realms' do not fit): fixed by this change when its tasks merge.
- **B-116** (a grade per leaf): unchanged. A leaf can now be started alone from its release, which a per-leaf suite
  would need. The per-leaf suite in `huldra` is still the founder's.

## Not in this change

- **The hidden suite.** It is never part of a task, and no task reads, lists or searches `huldra` or
  `~/ygg-it/hidden-suites`. Any change to scoring stays with the founder. Whether 4.1.0 needs a new suite version is
  the founder's decision (question 3).
- **The release in the acceptance run.** The acceptance run builds and starts the leaves from source, as today. Making
  it build and start the release, so that the ladder exercises `release.sh`, is a later change; T17 files it.
- **A store in the web end-to-end rung.** In a task's loop the web leaf runs against a mock of the API, with no store.
  This change does not add one. T10 tells each spec whether a real store is behind `/<bucket>/`
  (`YGG_E2E_STORE=1` in the acceptance run, unset in the rung), and the implementer prompt says to stub the store only
  when it is unset, so the acceptance run exercises the real forward.
- **The development sandbox's SeaweedFS.** It runs with no S3 identities, so it accepts anonymous requests. The
  product start gives SeaweedFS an identity; the sandbox is not changed here, and T17 files the gap.
- **Other product shapes.** The product start knows the web realm's shape: at most one API leaf at `repos/api` and one
  web leaf at `repos/web`, as the acceptance run does. A product of another shape needs its own start, or the infra
  realm.
- **Persistence across machines.** Data lives under `/app/.data/` for the life of the grading copy.

## Impact

- **Repos:** `mimir` (the founder's), `gungnir`, `helheim-go`, `midgard-react`, `odin`, `voluspa`, `ouroboric`,
  `yggdrasil`.
- **Order:** the rehearsal first (T01). Then `gungnir`. Then `odin`'s first pull request (T11 and the new `gungnir`
  pin), because `gungnir`'s pack schema refuses unknown keys (`additionalProperties: false`): an `odin` on the old pin
  cannot load a `midgard-react` whose `pack.yaml` names `product`. `midgard-react` merges after it. `helheim-go`,
  `voluspa` and `mimir` merge in any order. The umbrella's pointers do not move until T17. Until then, T16 checks out
  each repo at its merged `main` and uses a `ygg` built from that `odin`.
- **Approval points:** none added. The release sandbox runs no agent.
- **The proof runs:** run 1 and every later run use task 4.1.0. `ygg-proof-run.sh` reads the suite from `task.toml`,
  so it needs no change.
- **Other factories:** a Harbor run of 4.1.0 builds on the same image, with Postgres and SeaweedFS available. The
  brief is the same, so a factory that ignores them is graded as before.

## Risk

- **The planner designs something else.** Then this proposal is wrong in part. T01 checks it before any agent task
  starts, and says what to do.
- **The rehearsal runs on the old prompts.** T01 runs before T14 makes the prompts name the runtime, so a design that
  plans its own `start.sh` or a port-3000 task is expected there and is not a stop. Run 1 is the first plan made with
  the new prompts.
- **The signature through the forward (to verify).** The proposal assumes that SeaweedFS checks a presigned URL
  against the `Host` header it receives, so that forwarding the path unchanged keeps the signature valid. SeaweedFS's
  SigV4 check may read `X-Forwarded-Host` and `X-Forwarded-Port` before `Host`; that is from memory and unverified.
  So the storage forward adds no `X-Forwarded-*` header. The runtime smoke (T15, T16) must show a signed request
  succeeding through port 3000.
- **`release.sh` is in the leaf and unprotected.** An agent can change it, and nothing in the ladder or the acceptance
  run runs it, so a broken release shows only at export. Once question 1 is answered, the implementer prompts say
  (T05, T07): keep `release.sh` working, and change it only when the leaf's build changes. T17 files a backlog item for a check that runs it.
- **Port clashes.** SeaweedFS's volume server listens on 8080 by default, the API's port. The product start must move
  it.
- **Postgres as `app`.** `initdb` refuses root, which suits the brief. The 2-minute limit holds `initdb`, both
  services and both leaves; the runtime smoke measures it.
- **Ownership of the release's files.** A file written in a rootless sandbox may belong to a subuid on the host, as
  in B-139. T13 must copy the release out as the host user.
- **One more sandbox start per export.** The release adds a sandbox start to `ygg grade` and `ygg bridge`, with B-051's
  hang. Odin keeps a release by the commits it was built from, so a second grade reuses it.
