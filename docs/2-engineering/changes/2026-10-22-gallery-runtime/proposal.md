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

## Why

The frozen brief and the realms describe two different machines. Read as files:

- **The brief** (`mimir/client-gallery-lite/instruction.md` §6, task 4.0.0) asks for one machine. Grading copies
  only `/app` onto a fresh copy of the task image and runs `/app/start.sh` as an ordinary user. Within 2 minutes the
  product serves everything on port 3000, on all interfaces. It uses no outside service, account or key. It may write
  only in `/app` and the temporary folder.
- **The task image** (`environment/Dockerfile`) is Playwright 1.63.0 on Ubuntu 24.04, with Node 24, npm, Python 3.12,
  git and curl. It has no Postgres, no SeaweedFS and no Go. The grader has no network.
- **The realms** build a Go API leaf (`helheim-go`) and a React web leaf (`midgard-react`). Spec §9.2 and §9.3 give
  the API Postgres and the photos an S3 store. `helheim-go/pack.yaml` names both services as container images
  (`postgres:17.10-bookworm`, `seaweedfs:4.45`). Photo bytes go between the browser and the S3 API, never through the
  API.
- **The leaves' run scripts** (change [leaf-run-contract](../2026-10-21-leaf-run-contract/proposal.md)) build at
  start. The API's `run.sh` runs `go build` with `GOPROXY=off`: it needs Go and the module cache. The web leaf's
  `run.sh` needs `node_modules` and serves with `vite preview --host 127.0.0.1` (B-117).
- **The grader's `/app`** is the committed files of the project and of each leaf
  (`odin/internal/run/grade.go`, `ExportApp`). Build outputs and installed packages are not in git, so they never reach
  the grader (B-118). The export refuses anything that is not a regular file. `ygg bridge` uploads the same export to
  Harbor.
- **No one writes the root `start.sh`.** The leaf run contract left it to an infra realm that does not exist
  (B-078). Agents work only in their leaf, so no task can write it.

Read together, a product built as the realms' design says cannot start in the grader.

## What v0-H19 showed

**Nothing that was recorded.** The founder ran the planning rehearsal, but its run folder was cleaned up, and no
journal entry or ledger line holds its outcome. This proposal does not say what the planner designed. It rests on the
realms' documented design (above) and states its assumptions. The first task of [tasks.md](tasks.md) runs the rehearsal
again, checks its design gate against these assumptions, and keeps the answers.

The assumptions:

1. The planner designs two leaves: a React web leaf (`repos/web`, `midgard-react`) and a Go API leaf (`repos/api`,
   `helheim-go`).
2. The API keeps its data in Postgres.
3. The photos live in an S3-compatible store, reached with presigned URLs, and their bytes do not pass through the
   API.
4. The design needs no other service at run time.

## Decisions

- **Option A (the founder, 2026-10-22).** Bake Postgres and SeaweedFS into a new task version of the grader image,
  `4.1.0`, with the same brief and the same brief hash. The factory writes a root `start.sh` that starts the whole
  product, the services and both leaves, and serves everything on port 3000 on all interfaces, as `instruction.md` §6
  asks.
- **Options B and C are not taken.** The realms keep their stack (Postgres, S3). The planner is not told to ignore the
  realms' docs.

The rest of this section is what this proposal decides to make option A work. Each item the founder may answer
differently is in "Questions for the founder", with the answer the tasks assume.

- **The task image gains the services and nothing else.** `client-gallery-lite` 4.1.0 adds PostgreSQL 17 (`initdb`,
  `postgres`, `pg_ctl`, `createdb`, `psql`) and SeaweedFS 4.45 (`weed`) to the image, on the `PATH` of the user `app`.
  It adds no Go, no project package and no factory script: the image is a public benchmark machine, and any factory
  may use it.
- **A leaf reaches the grader as a release, built by the factory and never committed (B-118).** Each build realm's
  template ships `release.sh`. Run in the leaf, with `OUT` set to an empty folder, it writes into `OUT` everything the
  leaf needs to start with no network and no tool beyond the task image, and `OUT/run.sh`, which starts that copy. The
  API's release is a static Go binary. The web leaf's release is the built bundle and a small server with no package.
  The founder's rule of 2026-10-21 holds: no binaries in git.
- **Odin builds the release when it exports `/app`.** `ygg grade` and `ygg bridge` both export through
  `ExportApp`. It runs each leaf's `release.sh` in the project's acceptance sandbox, on a snapshot of the commits it
  exports, and puts each release at `/app/.ygg/release/<leaf>/`. No agent runs there, and the sandbox stops before the
  grader starts. A release that fails fails the grade, never as a score of 0.
- **The root `start.sh` is the product start script of the web realm (B-078).** `midgard-react` already holds the
  acceptance run, which starts the whole product. It ships `templates/product/start.sh` and names it in `pack.yaml`
  (`product.start`). Odin's `init` node writes it at the project root, executable, and commits it, as it commits
  `.gitignore`. No agent changes it. An infra realm may take it over later.
- **The web leaf serves on `HOST` (B-117).** The web template gets `serve.mjs`, a server on Node's standard library.
  It serves the bundle, forwards `/api/` to the API and forwards the photo store's path to the S3 API. Both `run.sh`
  and the release use it. It listens on `HOST`, by default `127.0.0.1`. The API listens on `HOST` too, when it is set.
  The product start gives the web leaf `HOST=0.0.0.0` and `PORT=3000`.
- **Everything the browser loads is on port 3000.** The API signs storage URLs for the address the product was
  reached at, on the bucket's path. The web leaf forwards that path to SeaweedFS unchanged, with the `Host` header
  kept, so the signature still matches. Every other port listens on `127.0.0.1` only.
- **The leaves read fixed names.** The API reads `PORT`, `HOST`, `DATABASE_URL`, `S3_ENDPOINT`, `S3_REGION`,
  `S3_BUCKET`, `S3_ACCESS_KEY_ID` and `S3_SECRET_ACCESS_KEY`. The web leaf reads `PORT`, `HOST`, `API_URL`,
  `S3_ENDPOINT` and `S3_BUCKET`. The product start sets them. The S3 key pair is made at each start. It is kept only
  in SeaweedFS's identity file under `/app/.data/`, readable by `app` alone, and in the leaves' environment; never in
  git or in a log. SeaweedFS refuses a request without it.
- **The planner is told.** Voluspa's spec and plan prompts say that the product runs on one machine, that `start.sh`
  and the services are the factory's, and which names the leaves read. No task writes a file outside its leaf.

## What changes

- **`mimir`** (the founder's): `client-gallery-lite` 4.1.0. `instruction.md` is unchanged and keeps its hash.
  `task.toml` says `4.1.0`. The Dockerfile installs PostgreSQL 17 from the PostgreSQL project's apt repository for
  Ubuntu 24.04, at a pinned package version, and copies `weed` from the `seaweedfs:4.45` image by digest, the same
  digest `helheim-go/pack.yaml` pins. The README's table gets the new version.
- **`gungnir`:** the pack schema takes an optional `product.start`, a path inside the pack.
- **`helheim-go`:** `templates/api/release.sh`; the API listens on `HOST` when it is set; the template's `AGENTS.md`
  and the implementer prompt name the runtime variables. A test builds the release and starts it with no Go on the
  `PATH`.
- **`midgard-react`:** `templates/web/serve.mjs` and a `run.sh` that uses it; `templates/web/release.sh`;
  `templates/product/start.sh` and `product.start` in `pack.yaml`. Tests start each one.
- **`odin`:** `init` writes and commits the product start; `ExportApp` builds the releases in the acceptance sandbox
  and adds them to the export.
- **`voluspa`:** the `spec` and `plan` prompts name the runtime.
- **`ouroboric`:** `scripts/ygg-smoke-runtime.sh`, which starts a product made from both templates in the 4.1.0 image
  with no network, as `app`, and checks port 3000 from a non-loopback address.
- **`yggdrasil`:** spec §9.3, §9.4 and §11 take the delta; the readiness checklist gets RR-24 and RR-25; the backlog,
  the proof-runs runbook and the pointers follow.

## What the backlog items become

- **B-078** (no root `start.sh`): fixed by the product start script. `midgard-react` ships it, Odin's `init` writes it
  at the project root, and no agent changes it. The infra realm stays later, and may take the script over.
- **B-117** (the web leaf serves on loopback only): fixed. The web leaf listens on `HOST`, by default `127.0.0.1`, and
  the product start sets `0.0.0.0` for port 3000 alone.
- **B-118** (a leaf's dependencies do not reach the grader): fixed for the services by the 4.1.0 image, and for the
  leaves by the release that Odin builds at export. Nothing is committed. The grade smoke's workaround (committing
  `node_modules`) stays in the smoke only.
- **B-140** (the brief's runtime and the realms' do not fit): fixed by this change when its tasks merge.
- **B-116** (a grade per leaf): unchanged. A leaf can now be started alone from its release, which a per-leaf suite
  would need. The per-leaf suite in `huldra` is still the founder's.

## Not in this change

- **The hidden suite.** It is never part of a task, and no task reads, lists or searches `huldra` or
  `~/ygg-it/hidden-suites`. Any change to scoring stays with the founder. Whether 4.1.0 needs a new suite version is
  the founder's decision (question 3 below).
- **The acceptance run.** It keeps starting the product its own way (`accept-e2e.sh`). Making it start the product
  through the release and `start.sh` is a later change, filed in the backlog by the last task.
- **The development sandbox's SeaweedFS.** It runs with no S3 identities, so it accepts anonymous requests. The
  product start gives SeaweedFS an identity; the sandbox is not changed here, and the last task files the gap.
- **Other product shapes.** The product start knows the web realm's shape: at most one API leaf and one web leaf,
  as the acceptance run does. A product of another shape needs its own start, or the infra realm.
- **Persistence across machines.** Data lives under `/app/.data/` for the life of the grading copy.

## Questions for the founder

Each task assumes the answer in **bold**. Say so on the pull request if you want another.

| # | Question | Assumed |
| --- | --- | --- |
| 1 | How do the leaves' builds reach the grader (B-118)? | **A release that Odin builds at export, never committed.** The other ways: commit `node_modules` and a vendored Go module folder, as the grade smoke did (large repositories, platform binaries in git); or add Go to the image too and build at start (still needs `node_modules`) |
| 2 | Who owns the root `start.sh` until an infra realm exists? | **`midgard-react`**, which holds the acceptance run. The other ways: a new infra realm now; or Voluspa's graph pack, which today holds no recipe |
| 3 | Which hidden suite scores 4.1.0? | **The founder's decision.** Task T02 keeps `suite = "v2"` in `task.toml` unless the founder names another. No agent reads or changes a suite |
| 4 | Where does the product keep its data in the grader? | **Under `/app/.data/`**, so a restart of `start.sh` in the same grading copy keeps it. The other way: the temporary folder, fresh at each start |
| 5 | Which Postgres minor version? | **PostgreSQL 17 from the PostgreSQL project's apt repository for Ubuntu 24.04, at a pinned package version.** The realm's sandbox runs 17.10 on Debian. The minor version may differ; the major may not |
| 6 | What happens to 4.0.0? | **It stays in the repository's history and the README lists 4.1.0.** A run of 4.0.0 is graded against 4.0.0's image, as today, because the task version and the image travel together |

## Impact

- **Repos:** `mimir` (the founder's), `gungnir`, `helheim-go`, `midgard-react`, `odin`, `voluspa`, `ouroboric`,
  `yggdrasil`.
- **Order:** the rehearsal first (T01). Then `gungnir`, before the `midgard-react` task that names `product.start` and
  before `odin`. `odin` pins `gungnir`. The realms, `voluspa` and `mimir` merge in any order. The runtime smoke runs
  when the image and the realms are merged. `yggdrasil` folds the delta and moves the pointers last.
- **Approval points:** none added. The release sandbox runs no agent.
- **The proof runs:** run 1 and every later run use task 4.1.0. `ygg-proof-run.sh` reads the suite from `task.toml`,
  so it needs no change.
- **Other factories:** a Harbor run of 4.1.0 builds on the same image, with Postgres and SeaweedFS available. The
  brief is the same, so a factory that ignores them is graded as before.

## Risk

- **The planner designs something else.** Then this proposal is wrong in part. T01 checks it before any agent task
  starts, and says what to do.
- **The signature through the forward.** The proposal assumes that SeaweedFS checks a presigned URL against the `Host`
  header it receives, so that forwarding the path unchanged keeps the signature valid. The runtime smoke (T12, T13)
  must show it with a signed request through port 3000.
- **Port clashes.** SeaweedFS's volume server listens on 8080 by default, the API's port. The product start must move
  it.
- **Postgres as `app`.** `initdb` refuses root, which suits the brief. The 2-minute limit holds `initdb`, both
  services and both leaves; the runtime smoke measures it.
- **Ownership of the release's files.** A file written in a rootless sandbox may belong to a subuid on the host, as
  in B-139. T10 must copy the release out as the host user.
- **One more sandbox start per export.** The release adds a sandbox start to `ygg grade` and `ygg bridge`, with B-051's
  hang. Odin keeps a release by the commits it was built from, so a second grade reuses it.
