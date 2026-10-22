---
title: Tasks for the gallery's product starting in the grader
status: draft
date: 2026-10-22
related: [proposal.md, delta.md, ../../plans/2026-10-22-yggdrasil-v0-phase-6/tasks.md, ../../../3-using/operations/proof-runs.md]
style: spec
---

# Gallery runtime: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing test
> first. One pull request per repo; the founder merges. Tasks marked **founder** are done by the founder, never by an
> agent.

**Goal:** a product that the factory builds from the gallery brief starts in the grader of `client-gallery-lite`
4.1.0: `/app/start.sh` starts Postgres, SeaweedFS, the API and the web leaf, with no network, and serves everything on
port 3000 on all interfaces.

**Spec:** [proposal](proposal.md) and [delta](delta.md). Read both.

**Status:** accepted when the founder merges the pull request that adds this file.

## Global constraints

- The [Phase 6 plan's global constraints](../../plans/2026-10-22-yggdrasil-v0-phase-6/tasks.md) hold: worktrees,
  `as-bot.sh`, staging by path, `GOWORK=off go test -race ./...`, `reuse lint`, `shellcheck -s bash`, hermetic tests,
  no token.
- **The hidden suite.** No task reads, lists or searches `huldra`, its clone under `ouroboric-private`, or
  `~/ygg-it/hidden-suites`. No file of this change names a path inside it. A founder task may pass the suites folder
  to `ygg` by path, as the proof runs do.
- **Images by digest.** SeaweedFS is `docker.io/chrislusf/seaweedfs:4.45@sha256:fc9f76fa993ad69966ffeb2f65d0318fcae39c6f8e20cf68ef7b3a5cb97769e5`,
  the digest `helheim-go/pack.yaml` pins. The task image's base stays
  `mcr.microsoft.com/playwright:v1.63.0-noble@sha256:eff16c30e6f3f4af0a03fa4b706120d5e9b0891c344a27d64559aff5900a4a27`.
- **Commit messages** end with the task id, as `(gallery-runtime-T03)`, and with the session's attribution lines.
- **No task changes** `instruction.md`, the brief hash, a hidden suite, `features.json`, a ledger or a run report.

## Order and pull requests

| Task | Repo | Size | Depends on |
| --- | --- | --- | --- |
| T01 (founder) the planning rehearsal, kept | the founder's machine | S | none |
| T02 (founder) `client-gallery-lite` 4.1.0 | `mimir` | S, about 40 lines | T01 |
| T03 the pack's `product.start` | `gungnir` | S, about 90 lines | T01 |
| T04 the API's release and runtime names | `helheim-go` | M, about 250 lines | T01 |
| T05 the web leaf's server, on `HOST` | `midgard-react` | M, about 300 lines | T01 |
| T06 the web leaf's release | `midgard-react` | M, about 150 lines | T05 |
| T07 the product start script | `midgard-react` | M, about 350 lines | T03 merged, T04, T06 |
| T08 `init` writes the product start | `odin` | M, about 200 lines | T03 merged |
| T09 the release in the export | `odin` | M, about 300 lines | T01 |
| T10 the release built in the acceptance sandbox | `odin` | M, about 250 lines | T09 |
| T11 the prompts name the runtime | `voluspa` | S, about 60 lines | T01 |
| T12 the runtime smoke script | `ouroboric` | M, about 300 lines | T04, T07 |
| T13 (founder) the runtime smoke on the real engine | the founder's machine | S | T02, T04 to T12 merged |
| T14 fold the delta, the checklist, the backlog and the pointers | `yggdrasil` | M, about 200 lines | T13 |

The pull requests, one per repo, each from a branch `gallery-runtime` made from `main`:

1. `gungnir`: T03. It merges first.
2. `helheim-go`: T04. `midgard-react`: T05, T06, T07 on one branch; T07 pins the merged `gungnir`. `voluspa`: T11.
   `mimir`: T02, by the founder. These merge in any order after T03.
3. `odin`: T08, T09, T10 on one branch; it pins the merged `gungnir`.
4. `ouroboric`: T12.
5. `yggdrasil`: T14, after T13. It moves the pointers and archives this folder.

Run 1 (v0-H20 of the Phase 6 plan) waits for T14.

---

### Task gallery-runtime-T01 (founder): the planning rehearsal, kept

v0-H19 ran, but nothing of it was recorded. This task runs it again, checks the proposal's assumptions against what
the planner designs, and keeps the answers. No agent task starts before it passes.

**Files:** none in a repo. The answers go in a comment on this change's pull request, as aggregate facts, not
transcripts.

- [ ] **Step 1:** do the dry run, then start the rehearsal (see
  [proof runs](../../../3-using/operations/proof-runs.md#the-rehearsal)):

  ```zsh
  cd ~/brunogbv/ouroboric/ouroboric
  scripts/ygg-proof-run.sh --name rehearsal --mode step-by-step --dry-run
  scripts/ygg-proof-run.sh --name rehearsal --mode step-by-step --build
  ```

- [ ] **Step 2:** at the design stop, read `PROJECT/.factory/runs/RUN/gates/design-1.md` and the design doc. Approve
  it. At the spec stop, read `spec-1.md`, the spec and `docs/leaves.yaml`. Approve it. **Do not approve
  `plan-gate`.** The run ends there with exit 3.
- [ ] **Step 3:** check the four assumptions of the proposal, each yes or no, with the file and section that says so:
  1. two leaves, `repos/web` on `midgard-react` and `repos/api` on `helheim-go`;
  2. the API keeps its data in Postgres;
  3. the photos live in an S3-compatible store, through presigned URLs, and their bytes do not pass through the API;
  4. no other service at run time.

  Also note what the design says about `start.sh` and port 3000, the number of tasks and their sizes, and what the
  conformance and reuse reviewers found.
- [ ] **Step 4:** keep the run folder until T14 merges. Write the answers, with `ygg metrics` and `ygg report` of the
  run, in a comment on this change's pull request.
- [ ] **Step 5:** if an assumption does not hold, stop before any other task and act on the first row that applies:

| What the design does | What to do |
| --- | --- |
| All four hold | Go on with T02 to T14 |
| Two leaves, but another store (photos on disk through the API, SQLite) | Stop. Decide whether the realms' rules (spec §9.3) or the design win. Amend this proposal before T02: the image's services and the storage forward may change |
| One leaf, or one process for the whole product | Stop. The planner left the realms' design. Answer question 10 again (option B or C), and replace this change |
| Another service at run time (a queue, a cache, a mail server) | Stop. Amend this proposal: the image gains the service, or the planner is told not to use it |
| A leaf on a realm other than these two | Stop. The planner broke the spec prompt's rule; file it, and run the rehearsal again after the prompt is fixed |

**Acceptance criteria:**

- [ ] The run stopped at `plan-gate` with exit 3, and its folder is kept.
- [ ] The four assumptions are answered with the file that shows each answer, and the comment is on the pull request.
- [ ] When one does not hold, no other task has started, and the founder's decision is on the pull request.

**Named test:** the run's exit 3 at `plan-gate`, and the four answers checked against the gate files.
**Layer:** the founder's machine. **Size:** S. **Depends on:** none (`ygg-proof-run.sh`, v0-T291, is merged).

### Task gallery-runtime-T02 (founder): `client-gallery-lite` 4.1.0

A new task version: the same brief and hash, and an image that holds the services. `mimir/AGENTS.md` says a new task
version is made by the founder.

**Files (in `mimir`):**

- Modify: `client-gallery-lite/environment/Dockerfile`, `client-gallery-lite/task.toml` (`version = "4.1.0"`),
  `README.md` (the table's row)

- [ ] **Step 1: the failing test.** Build the 4.0.0 image and run, with no network, as `app`:

  ```zsh
  podman build -t cgl:4.0.0 client-gallery-lite/environment
  podman run --rm --network none --user app cgl:4.0.0 sh -c 'initdb --version && postgres --version && weed version'
  ```

  Expected: it fails (`initdb: not found`).
- [ ] **Step 2:** in the Dockerfile, install PostgreSQL 17 from the PostgreSQL project's apt repository for Ubuntu
  24.04 (`noble-pgdg`), at a pinned package version, with the repository's key checked by fingerprint. Put
  `/usr/lib/postgresql/17/bin` on the `PATH`. Copy `/usr/bin/weed` from the SeaweedFS image, by digest, in a second
  stage. Do not create a cluster or start a service. Update the header comment: the image also holds PostgreSQL 17
  and SeaweedFS 4.45, for a product that wants them; the product starts them itself.
- [ ] **Step 3:** set `version = "4.1.0"` in `task.toml`. Keep `brief_sha256`. Keep `suite = "v2"` unless the founder
  names another suite (proposal question 3). Change the README's row to 4.1.0.
- [ ] **Step 4:** run the command of step 1 on the new image. Expected: three version lines, PostgreSQL 17 and
  SeaweedFS 4.45. Then run, as `app` with no network, a cluster in a temporary folder:
  `initdb -D /tmp/pg -U postgres --auth=trust && pg_ctl -D /tmp/pg -o '-k /tmp -c listen_addresses=127.0.0.1' -w start && psql -h /tmp -U postgres -c 'select 1'`.
  Expected: `1`.
- [ ] **Step 5:** run `scripts/check-task.sh client-gallery-lite` and `bash scripts/check-task.test.sh`. Expected:
  both pass, and the brief hash is the README's.

**Acceptance criteria:**

- [ ] `instruction.md` is unchanged; `sha256sum` gives `bd4b2c7aaf532d51acb3a7edfd5b193d368db8445093b7a24cd80b7ee24d8319`.
- [ ] The 4.1.0 image runs `initdb`, `postgres`, `pg_ctl`, `psql` and `weed` as `app` with no network; the 4.0.0
  image did not.
- [ ] `check-task.sh` passes.

**Named test:** the `podman run` of step 1 (red on 4.0.0, green on 4.1.0); `mimir/scripts/check-task.sh client-gallery-lite`.
**Layer:** `mimir`. **Size:** S, about 40 lines. **Depends on:** T01.

### Task gallery-runtime-T03: the pack's `product.start`

**Files (in `gungnir`):**

- Modify: `schema/pack.go` (`Pack.Product *PackProduct`, `PackProduct.Start string`), `schema/pack.schema.json`
- Create: `schema/pack_product_test.go`

**Interfaces:**

- Produces: `Pack.Product.Start`, a path relative to the pack, which T07 sets and T08 reads.

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
**Layer:** `gungnir`. **Size:** S, about 90 lines. **Depends on:** T01.

### Task gallery-runtime-T04: the API's release and runtime names

**Files (in `helheim-go`):**

- Create: `templates/api/release.sh`, `release_test.go`
- Modify: `templates/api/cmd/api/main.go` and `main_test.go` (`HOST`), `templates/api/AGENTS.md` and
  `prompts/implementer.md` (the runtime names), `docs/architecture.md`

**Interfaces:**

- Produces: the API's names of delta §9.4, which T07 sets and T11 names.

- [ ] **Step 1: the failing tests.**
  - `TestReleaseScriptStarts` (so that `-run ReleaseScript` finds it): copy the template, run `release.sh` with `OUT`
    set to an empty folder, then run `OUT/run.sh` with `PORT` free, `HOST=127.0.0.1` and a `PATH` of `/usr/bin:/bin`
    only (no Go), and wait for the port. Assert that `OUT` holds only regular files and folders. Skip without Go;
    fail with `YGG_REQUIRE_TEMPLATES=1`.
  - `TestListensOnHost` in the template's `main_test.go`: with `HOST=127.0.0.1` the server's address is
    `127.0.0.1:<port>`; with no `HOST`, it is `:<port>`, all interfaces, as today (a sandbox may reach the API from
    another container).
  - `TestPromptNamesTheRuntime`: the implementer prompt and the template's `AGENTS.md` name each of `PORT`, `HOST`,
    `DATABASE_URL`, `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`,
    `X-Forwarded-Host` and `/app/start.sh`.

  Run them. Expected: FAIL.
- [ ] **Step 2:** write `release.sh`: `CGO_ENABLED=0 GOWORK=off GOFLAGS=-mod=readonly go build -trimpath -o "$OUT/api" ./cmd/api`,
  then write `OUT/run.sh`, which checks `PORT` as the leaf's `run.sh` does and runs `exec "$(dirname "$0")/api"`.
  The migrations are embedded already.
- [ ] **Step 3:** the server listens on `HOST:PORT`, and on all interfaces when `HOST` is unset. The template's
  `AGENTS.md` and the prompt say: the API reads only the names of delta §9.4; it builds public addresses from
  `X-Forwarded-Host` and `X-Forwarded-Proto`; storage URLs are path-style, `/<S3_BUCKET>/<key>`, signed for that
  address; the bucket is made at start when it is missing; the product's `/app/start.sh` is the factory's and no
  task changes it.
- [ ] **Step 4:** run the tests, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The release starts with no Go on the `PATH`, and holds only regular files.
- [ ] The API listens on `HOST` when it is set.
- [ ] The prompt and the template's `AGENTS.md` name the runtime.

**Named test:** `helheim-go/release_test.go:TestReleaseScriptStarts`, `templates/api/cmd/api/main_test.go:TestListensOnHost`,
`helheim-go/release_test.go:TestPromptNamesTheRuntime`.
**Layer:** `helheim-go`. **Size:** M, about 250 lines. **Depends on:** T01.

### Task gallery-runtime-T05: the web leaf's server, on `HOST`

It fixes B-117.

**Files (in `midgard-react`):**

- Create: `templates/web/serve.mjs` (Node's standard library only), `serve_test.go`
- Modify: `templates/web/run.sh` (build, then `node serve.mjs`), `runscript_test.go`, `templates/web/AGENTS.md`,
  `prompts/implementer.md`, `docs/architecture.md`

**Interfaces:**

- Produces: `serve.mjs`, which reads `PORT`, `HOST`, `API_URL`, `S3_ENDPOINT`, `S3_BUCKET` and `DIST` (default
  `dist`). T06 copies it into the release.

- [ ] **Step 1: the failing test.** `TestServeForwards` starts `node serve.mjs` on a free port with a small `dist/`,
  a stand-in API and a stand-in S3 store (Go `httptest` servers that record what they get), and asserts:
  - `GET /api/galleries?x=1` reaches the API as `/galleries?x=1`, with `X-Forwarded-Host` the request's host and
    `X-Forwarded-Proto: http`;
  - `PUT /<bucket>/a/b.jpg?X-Amz-Signature=s` with a body reaches the store with the same path, query and body, and
    with the request's `Host` header;
  - `GET /` and `GET /galleries/x` answer `dist/index.html`; `GET /assets/app.js` answers the file with a JavaScript
    content type; a path with `..` does not leave `dist`;
  - with `HOST=127.0.0.1` the server does not answer on another address of the machine; with `HOST=0.0.0.0` it does
    (skip that half when the machine has no non-loopback address).

  Skip without `node`; fail with `YGG_REQUIRE_TEMPLATES=1`. Run it. Expected: FAIL (no `serve.mjs`).
- [ ] **Step 2:** write `serve.mjs`: `node:http` and `node:fs` only, streaming both ways, no package. Change
  `run.sh` to build the bundle and `exec node serve.mjs` with `HOST` (default `127.0.0.1`). Keep the dev server's
  proxy in `vite.config.ts` as it is.
- [ ] **Step 3:** run `TestServeForwards` and `TestRunScriptStarts`, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`.
  Expected: PASS. The docs and the prompt say that `serve.mjs` is what serves the leaf, and that it forwards
  `/api/` and the bucket's path.

**Acceptance criteria:**

- [ ] `serve.mjs` forwards `/api/` and the bucket's path as delta §9.3 says, and serves the bundle with the fallback.
- [ ] It listens on `HOST`, loopback by default; `run.sh` uses it.

**Named test:** `midgard-react/serve_test.go:TestServeForwards`; `midgard-react/runscript_test.go:TestRunScriptStarts`.
**Layer:** `midgard-react`. **Size:** M, about 300 lines. **Depends on:** T01.

### Task gallery-runtime-T06: the web leaf's release

**Files (in `midgard-react`):**

- Create: `templates/web/release.sh`, `release_test.go`
- Modify: `docs/architecture.md`

- [ ] **Step 1: the failing test.** `TestReleaseScriptStarts`: copy the template, run `init.sh`, run `release.sh` with
  `OUT` set to an empty folder, then run `OUT/run.sh` with `PORT` free and a `PATH` that holds `node` and no `npm`,
  from a folder with no `node_modules`, and wait for the port. Assert that `OUT` holds only regular files and folders,
  and no `node_modules`. Skip without `npm`; fail with `YGG_REQUIRE_TEMPLATES=1`. Expected: FAIL.
- [ ] **Step 2:** write `release.sh`: `npm run build`, copy `dist/` to `OUT/dist` and `serve.mjs` to `OUT/`, and write
  `OUT/run.sh`, which checks `PORT` and runs `exec node serve.mjs` in its own folder.
- [ ] **Step 3:** run the test, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The release starts with Node alone, no `npm` and no `node_modules`, and holds only regular files.

**Named test:** `midgard-react/release_test.go:TestReleaseScriptStarts`.
**Layer:** `midgard-react`. **Size:** M, about 150 lines. **Depends on:** T05.

### Task gallery-runtime-T07: the product start script

It fixes B-078 for the web realm.

**Files (in `midgard-react`):**

- Create: `templates/product/start.sh`, `productstart_test.go`
- Modify: `pack.yaml` (`product: {start: templates/product/start.sh}`), `pack_test.go`, `go.mod` and `go.sum` (the
  merged `gungnir`), `docs/architecture.md`, `README.md`

**Interfaces:**

- Consumes: T03's `product.start`; T04's and T05's names; the releases of T04 and T06.
- Produces: the script that T08 writes at a project's root.

- [ ] **Step 1: the failing tests.**
  - `TestPackNamesTheProductStart` in `pack_test.go`: the pack loads with the merged `gungnir` and `Product.Start` is
    an executable file in the pack.
  - `TestProductStart` (so that `-run ProductStart` finds it): a temporary `/app`-like folder with stand-in releases
    at `.ygg/release/repos/api/run.sh` and `.ygg/release/repos/web/run.sh` (each records its environment and opens its
    port), and stand-in `initdb`, `postgres`, `pg_ctl`, `createdb` and `weed` first on the `PATH` (each records its
    arguments and opens the port it is given). Assert:
    - the web part gets `HOST=0.0.0.0`, `PORT=3000`, `API_URL`, `S3_ENDPOINT` and `S3_BUCKET`;
    - the API gets `HOST=127.0.0.1` and every name of delta §9.4, with a key pair that differs between two starts;
    - Postgres and SeaweedFS get data folders under `.data/`, listen on `127.0.0.1`, and SeaweedFS's volume port is
      not the API's;
    - SeaweedFS gets an identity file, mode `0600`, and the key appears in no output of the script;
    - with no release, the script starts `repos/api/run.sh` and `repos/web/run.sh` instead;
    - a part that does not open its port makes the script exit non-zero and name the part, and stops the others;
    - a `TERM` to the script stops every part;
    - run as root (`id -u` stubbed to 0), it refuses.

  It needs only `bash` and the stand-ins, so it never skips. Expected: FAIL.
- [ ] **Step 2:** write `start.sh`, in bash, after `accept-e2e.sh`: refuse root; `cd` to its own folder; make
  `.data/`; `initdb` once, start `postgres` on `127.0.0.1:5432` with its socket in the temporary folder, and run
  `createdb app` once; write SeaweedFS's identity file with a fresh key pair from `/dev/urandom`, and start
  `weed server -s3` on `127.0.0.1` with its S3 port 8333 and its other ports away from 8080; wait for each port (the
  waits sum to well under 2 minutes); start the API, then the web part; `wait` on all of them and stop the rest when
  one ends.
- [ ] **Step 3:** run the tests, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS. `shellcheck -s bash`
  on the script: no output.

**Acceptance criteria:**

- [ ] `TestProductStart` passes, and each of its assertions fails when the script's matching line is taken out.
- [ ] The pack names the script, and loads with the merged `gungnir`.

**Named test:** `midgard-react/productstart_test.go:TestProductStart`; `midgard-react/pack_test.go:TestPackNamesTheProductStart`.
**Layer:** `midgard-react`. **Size:** M, about 350 lines. **Depends on:** T03 merged, T04, T06.

### Task gallery-runtime-T08: `init` writes the product start

**Files (in `odin`):**

- Modify: `internal/engine/init.go` (after `ignoreFactory`), `internal/run/prepare.go` (at most one realm names a
  product start), `docs/architecture.md`, `go.mod` and `go.sum` (the merged `gungnir`)
- Create: `internal/engine/init_product_test.go`

- [ ] **Step 1: the failing tests.** `TestInitWritesProductStart`, on a project whose leaf realm names
  `product.start`:
  - `start.sh` is at the project root, mode `0755`, byte for byte the realm's file, in a commit of its own;
  - the project's `.gitignore` holds `.data/`;
  - a resumed `init` adds no commit;
  - a project whose `start.sh` differs from the realm's gets the realm's in a new commit that says so;
  - a project whose realms name no product start keeps its own `start.sh` untouched (the grade smoke has one);
  - two realms that each name one: `init` fails before it creates a leaf, and names both.

  Expected: FAIL.
- [ ] **Step 2:** implement it after `ignoreFactory`'s model. Write the mode, which first-commit files lose (B-128).
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The six cases pass.

**Named test:** `odin/internal/engine/init_product_test.go:TestInitWritesProductStart`.
**Layer:** `odin`. **Size:** M, about 200 lines. **Depends on:** T03 merged.

### Task gallery-runtime-T09: the release in the export

**Files (in `odin`):**

- Modify: `internal/run/grade.go` (`ExportApp`), `internal/engine/grade.go` (a release failure is a `GradeFailed`),
  `docs/architecture.md`
- Create: `internal/run/release.go`, `internal/run/release_test.go`

**Interfaces:**

- Produces: `run.Releaser`, `Build(ctx, snapshot string, leaves []string) (dir string, err error)`, and its use in
  `ExportApp`. T10 gives the real one.

- [ ] **Step 1: the failing tests,** with a stand-in `Releaser`:
  - `TestExportAppAddsTheRelease`: the export holds the committed files and, for each leaf with an executable
    `release.sh`, the release at `.ygg/release/<leaf>/`; a leaf with no `release.sh` gets none;
  - `TestReleaseIsReused`: a second export of the same commits calls the releaser once; a new commit of a leaf builds
    again;
  - `TestReleaseRefused`: a release with a symlink, a device file, or past its bound, and a releaser that fails, each
    make `ExportApp` return an error that names the leaf, and leave no partial export;
  - `TestGradeFailsOnARelease`: in `engine`, a failed release is a `*GradeFailed`, with no `score.json`, and a resume
    grades again.

  Expected: FAIL.
- [ ] **Step 2:** implement it. Keep each release in the run folder under the commits it was built from. Write the
  releaser's output to `release.log` beside `grade.log`, mode `0600`.
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS. `ygg bridge`'s tests still pass:
  its upload is the same export.

**Acceptance criteria:**

- [ ] The four tests pass. A release is never committed to the project or a leaf.

**Named test:** `odin/internal/run/release_test.go:TestExportAppAddsTheRelease`, `TestReleaseIsReused`,
`TestReleaseRefused`; `odin/internal/engine/grade_test.go:TestGradeFailsOnARelease`.
**Layer:** `odin`. **Size:** M, about 300 lines. **Depends on:** T01.

### Task gallery-runtime-T10: the release built in the acceptance sandbox

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
**Layer:** `odin`. **Size:** M, about 250 lines. **Depends on:** T09.

### Task gallery-runtime-T11: the prompts name the runtime

**Files (in `voluspa`):**

- Modify: `software/prompts/spec.md`, `software/prompts/plan.md`, `prompts_test.go`

- [ ] **Step 1: the failing test.** `TestPromptsNameTheRuntime`: `spec.md` says that the product runs on one machine
  with Postgres and an S3 store started by the factory's `start.sh`, and names the API's and the web leaf's variables
  of delta §9.4; `plan.md` says that no task writes `start.sh` or any file outside its leaf. Expected: FAIL.
- [ ] **Step 2:** add the lines, short, in the prompts' style.
- [ ] **Step 3:** run `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The test passes, and fails when either line is taken out.

**Named test:** `voluspa/prompts_test.go:TestPromptsNameTheRuntime`.
**Layer:** `voluspa`. **Size:** S, about 60 lines. **Depends on:** T01.

### Task gallery-runtime-T12: the runtime smoke script

**Files (in `ouroboric`):**

- Create: `scripts/ygg-smoke-runtime.sh`, `scripts/tests/ygg-smoke-runtime.test.sh`
- Modify: `AGENTS.md` (the scripts table)

**Interfaces:**

- Produces: `ygg-smoke-runtime.sh [--image REF] [--folder DIR] [--yggdrasil DIR]`, which T13 runs.

- [ ] **Step 1: the failing test.** `ygg-smoke-runtime.test.sh`, with a stand-in `podman` first on the `PATH` that
  records its arguments: the script builds each template's release in that realm's sandbox image, puts the product
  start at the root of a folder laid out like `/app`, and runs it in the task image with `--network none` and
  `--user app`; it refuses a missing image or a missing realm with a message; it never names `hidden-suites` or a
  credentials file. Expected: FAIL.
- [ ] **Step 2:** write the script. Its checks, each printed as `PASS` or `FAIL`:
  - port 3000 answers `GET /` with the bundle's `index.html` within 2 minutes, from the container's own
    non-loopback address;
  - `GET /api/<a route of the template>` answers from the API through port 3000;
  - an unsigned `PUT` to `/<bucket>/x` through port 3000 is refused;
  - a signed `PUT` and `GET` (`curl --aws-sigv4`, the key read as `app` from the identity file under `/app/.data/`)
    through port 3000 succeed, and the script never prints the key;
  - no port other than 3000 listens on a non-loopback address;
  - the time from start to the first answer, in seconds.
- [ ] **Step 3:** run the test and `shellcheck -s bash`. Expected: the test's lines all `ok`; no output.

**Acceptance criteria:**

- [ ] The test passes with the stand-in engine; the script names its checks and their order in its header.

**Named test:** `ouroboric/scripts/tests/ygg-smoke-runtime.test.sh`.
**Layer:** `ouroboric`. **Size:** M, about 300 lines. **Depends on:** T04, T07.

### Task gallery-runtime-T13 (founder): the runtime smoke on the real engine

- [ ] **Step 1:** build the 4.1.0 image and run the smoke:

  ```zsh
  cd ~/brunogbv/ouroboric/ouroboric
  scripts/ygg-smoke-runtime.sh --image cgl:4.1.0
  ```

  Expected: every check `PASS`, and the time to the first answer under 120 seconds.
- [ ] **Step 2 (optional):** run the content smoke with the gallery's brief (`ygg-smoke-realms.sh --graph software
  --brief <mimir>/client-gallery-lite/instruction.md --tag h15`), then `ygg grade <run> --project <project>`. The
  suites folder is passed by path and nobody reads it. Expected: a grade that ends with a reward (a template product
  scores low), no `GradeFailed`, and a `release.log` that shows both leaves built.
- [ ] **Step 3:** paste the output on the `yggdrasil` pull request of T14.

**Acceptance criteria:**

- [ ] Every check of the smoke passes on the real engine.

**Named test:** `ygg-smoke-runtime.sh` on the 4.1.0 image.
**Layer:** the founder's machine. **Size:** S. **Depends on:** T02, and T04 to T12 merged.

### Task gallery-runtime-T14: fold the delta, the checklist, the backlog and the pointers

**Files (in `yggdrasil`):**

- Modify: `docs/2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md` (§9.3, §9.4, §11, as the delta says),
  `docs/2-engineering/realm-readiness.md` (RR-24, RR-25), `docs/2-engineering/backlog.md`,
  `docs/3-using/operations/proof-runs.md` (the task is 4.1.0), the pointers of `gungnir`, `helheim-go`,
  `midgard-react`, `odin` and `voluspa`
- Move: this folder to `docs/2-engineering/changes/archive/`

- [ ] **Step 1:** fold the delta into the spec. Add RR-24 and RR-25 to the checklist, with their checks.
- [ ] **Step 2:** in the backlog, mark B-078, B-117, B-118 and B-140 done with the pull requests; add to B-116 that a
  leaf now starts alone from its release. File two items: the acceptance run does not start the product through the
  release and `start.sh`; the development sandbox's SeaweedFS accepts anonymous requests.
- [ ] **Step 3:** the proof-runs runbook says the runs use task 4.1.0, and that question 10 is answered (option A).
- [ ] **Step 4:** move the pointers to the merged commits, and archive this folder.
- [ ] **Step 5:** run `pre-commit run --files` on every changed file, and the docs check. Expected: pass; no problem
  names a changed file.

**Acceptance criteria:**

- [ ] The spec holds every line of the delta, and the checklist has RR-24 and RR-25.
- [ ] The four backlog items are done, with links, and the two new items are filed.
- [ ] The pointers are the merged commits.

**Named test:** `pre-commit run --files` on the changed files; the docs check.
**Layer:** `yggdrasil`. **Size:** M, about 200 lines. **Depends on:** T13.

## Open for the builder

- **SeaweedFS and the forwarded `Host`.** The proposal assumes that its S3 API checks a signature against the `Host`
  it receives. If it does not, say so in T05 or T12, and propose the fix (for example, the API signs for the store's
  own address and the web leaf rewrites `Host`) before going on.
- **The S3 region and the bucket's name.** Pick a fixed region (`us-east-1`) and a bucket name that no route of the
  web app uses (for example `ygg-store`). Say which in T04 and T07.
- **Postgres's socket and port.** `start.sh` may use a TCP port on `127.0.0.1` or only the socket in the temporary
  folder. `DATABASE_URL` must work with `pgx` either way.
- **The release's bound.** Pick it from what T04 and T06 produce (a Go binary of tens of MiB, a bundle of a few MiB),
  with room, and say it in T09.
- **Where the release is copied out of the sandbox.** `SnapshotRunner` writes into a snapshot on the host. Say how
  T10 reads it as the host user.
