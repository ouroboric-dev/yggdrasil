---
title: Tasks for the gallery's product starting in the grader
status: draft
date: 2026-10-22
related: [proposal.md, delta.md, ../../plans/2026-10-22-yggdrasil-v0-phase-6/tasks.md, ../../../3-using/operations/proof-runs.md]
style: spec
---

# Gallery runtime: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing test
> first. One pull request per repo, unless the order below says two; the founder merges. Tasks marked **founder** are
> done by the founder, never by an agent.

**Goal:** a product that the factory builds from the gallery brief starts in the grader of `client-gallery-lite`
4.1.0: `/app/start.sh` starts Postgres, SeaweedFS, the API and the web leaf, with no network, and serves everything on
port 3000 on all interfaces.

**Spec:** [proposal](proposal.md) and [delta](delta.md). Read both, and the proposal's questions first.

**Status:** accepted when the founder merges the pull request that adds this file. The merge approves the direction
on the condition that T01 shows the proposal's four assumptions. T01 may run before the merge, which is better.

**Waiting for question 1.** The release (T05, T07, T12, T13) is assumed, not decided: it goes beyond option A. Those
four tasks do not start until the founder answers the proposal's question 1. If the answer is another way, they are
replaced through an amendment of this file, and T15 follows the answer.

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
| T02 (founder) `client-gallery-lite` 4.1.0 | `mimir` | S, about 50 lines | T01 |
| T03 the pack's `product.start` | `gungnir` | S, about 90 lines | T01 |
| T04 the API on `HOST`, and the runtime names | `helheim-go` | M, about 150 lines | T01 |
| T05 the API's release | `helheim-go` | M, about 120 lines | T04, question 1 |
| T06 the web leaf's server, on `HOST` | `midgard-react` | M, about 300 lines | T01 |
| T07 the web leaf's release | `midgard-react` | M, about 150 lines | T06, question 1 |
| T08 the pack names the product start | `midgard-react` | S, about 60 lines | T03 merged, T11 merged |
| T09 the product start script | `midgard-react` | M, about 300 lines | T04, T06, T08 |
| T10 the acceptance run on the new contract | `midgard-react` | M, about 250 lines | T04, T06 |
| T11 `init` writes the product start | `odin` | M, about 200 lines | T03 merged |
| T12 the release in the export | `odin` | M, about 300 lines | T01, question 1 |
| T13 the release built in the acceptance sandbox | `odin` | M, about 250 lines | T12 |
| T14 the prompts name the runtime | `voluspa` | S, about 60 lines | T01 |
| T15 the runtime smoke script | `ouroboric` | M, about 300 lines | T05, T07, T09 |
| T16 (founder) the runtime smoke on the real engine | the founder's machine | S | T02, and T04 to T15 merged |
| T17 fold the delta, the checklist, the backlog and the pointers | `yggdrasil` | M, about 200 lines | T16 |

The pull requests, each from a branch `gallery-runtime` made from `main`:

1. `gungnir`: T03. It merges first.
2. `odin`, first pull request: T11, with the merged `gungnir` pinned. It merges before `midgard-react`'s, because
   `gungnir`'s pack schema refuses unknown keys: an `odin` on the old pin cannot load a `midgard-react` whose
   `pack.yaml` names `product`.
3. `midgard-react`: T06, T08, T09, T10 (and T07 once question 1 is answered) on one branch; T08 pins the merged
   `gungnir`. `helheim-go`: T04 (and T05 once question 1 is answered). `voluspa`: T14. `mimir`: T02, by the founder.
   These merge in any order after the first two. A repo whose release task still waits opens its pull request without
   it, and the release task follows in a second pull request.
4. `odin`, second pull request: T12, T13.
5. `ouroboric`: T15.
6. `yggdrasil`: T17, after T16. It moves the pointers.

The umbrella's pointers do not move until T17. T16 checks out each repo at its merged `main` and builds `ygg` from
that `odin`. Run 1 (v0-H20 of the Phase 6 plan) waits for T17.

---

### Task gallery-runtime-T01 (founder): the planning rehearsal, kept

v0-H19 ran, but nothing of it was recorded. This task runs it again, checks the proposal's assumptions against what
the planner designs, and keeps the answers. No agent task starts before it passes. It runs on today's prompts, before
T14 makes them name the runtime.

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
- [ ] **Step 4:** keep the run folder until T17 merges. Write the answers, with `ygg metrics` and `ygg report` of the
  run, in a comment on this change's pull request.
- [ ] **Step 5:** act on the first row that applies:

| What the design does | What to do |
| --- | --- |
| All four hold | Go on with T02 to T17 |
| All four hold, and the plan has its own `start.sh` or a port-3000 task | Expected on today's prompts; not a stop. Note it. T14 tells the planner, and run 1 is the first plan made with the new prompts |
| Two leaves on the right realms, at other paths (`repos/frontend`, `repos/server`) | Stop. The spec prompt's rule on paths was broken, and the product start finds the leaves only at `repos/web` and `repos/api`. Fix the prompt in T14 first, then run the rehearsal again; or amend this proposal so that the product start reads the paths |
| A third leaf (a worker on `helheim-go`, say) | Stop. The product start starts only `repos/api` and `repos/web`. Amend this proposal (T09 starts every leaf it finds), or tell the planner in T14 that the gallery has two leaves |
| Two leaves, but another store (photos on disk through the API, SQLite) | Stop. Decide whether the realms' rules (spec §9.3) or the design win. Amend this proposal before T02: the image's services and the storage forward may change |
| One leaf, or one process for the whole product | Stop. The planner left the realms' design. Answer question 10 again (option B or C), and replace this change |
| Another service at run time (a queue, a cache, a mail server) | Stop. Amend this proposal: the image gains the service, or the planner is told not to use it |
| A leaf on a realm other than these two | Stop. The planner broke the spec prompt's rule; file it, and run the rehearsal again after the prompt is fixed |

**Acceptance criteria:**

- [ ] The run stopped at `plan-gate` with exit 3, and its folder is kept.
- [ ] The four assumptions are answered with the file that shows each answer, and the comment is on the pull request.
- [ ] When a row says stop, no other task has started, and the founder's decision is on the pull request.

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
  podman run --rm --network none --user app cgl:4.0.0 sh -c 'initdb --version && postgres --version && createdb --version && weed version'
  ```

  Expected: it fails (`initdb: not found`).
- [ ] **Step 2:** in the Dockerfile, before the install, write `create_main_cluster = false` into
  `/etc/postgresql-common/createcluster.conf`, so the package makes no cluster. Install PostgreSQL 17 for Ubuntu 24.04
  from the PostgreSQL project, at one pinned package version, with the repository's key checked by fingerprint. The
  main repository keeps only the newest package of each version, so take the pin from `apt-archive.postgresql.org` or
  a dated snapshot (to verify when the image is built: say which in the pull request). Put
  `/usr/lib/postgresql/17/bin` on the `PATH`. Copy `/usr/bin/weed` from the SeaweedFS image, by digest, in a second
  stage. Do not start a service. Update the header comment: the image also holds PostgreSQL 17 and SeaweedFS 4.45, for
  a product that wants them; the product starts them itself.
- [ ] **Step 3:** set `version = "4.1.0"` in `task.toml`. Keep `brief_sha256`. Keep `suite = "v2"` unless the founder
  names another suite (proposal question 3). Change the README's row to 4.1.0.
- [ ] **Step 4:** run the command of step 1 on the new image. Expected: four version lines, PostgreSQL 17 and
  SeaweedFS 4.45. Then run, as `app` with no network, a cluster in a temporary folder:
  `initdb -D /tmp/pg -U postgres --auth=trust && pg_ctl -D /tmp/pg -o '-k /tmp -c listen_addresses=127.0.0.1' -w start && createdb -h /tmp -U postgres app && psql -h /tmp -U postgres -d app -c 'select 1'`.
  Expected: `1`. Check that `/var/lib/postgresql/17/main` does not exist.
- [ ] **Step 5:** run `scripts/check-task.sh client-gallery-lite` and `bash scripts/check-task.test.sh`. Expected:
  both pass. `check-task.sh` reads only the task folder, so check by hand that `sha256sum
  client-gallery-lite/instruction.md` is the hash in the README's row.

**Acceptance criteria:**

- [ ] `instruction.md` is unchanged; `sha256sum` gives `bd4b2c7aaf532d51acb3a7edfd5b193d368db8445093b7a24cd80b7ee24d8319`,
  the same as `task.toml` and the README (the README by hand).
- [ ] The 4.1.0 image runs `initdb`, `postgres`, `pg_ctl`, `createdb`, `psql` and `weed` as `app` with no network; the
  4.0.0 image did not. The image holds no cluster.
- [ ] `check-task.sh` passes.

**Named test:** the `podman run` of step 1 (red on 4.0.0, green on 4.1.0); `mimir/scripts/check-task.sh client-gallery-lite`.
**Layer:** `mimir`. **Size:** S, about 50 lines. **Depends on:** T01.

### Task gallery-runtime-T03: the pack's `product.start`

**Files (in `gungnir`):**

- Modify: `schema/pack.go` (`Pack.Product *PackProduct`, `PackProduct.Start string`), `schema/pack.schema.json`
- Create: `schema/pack_product_test.go`

**Interfaces:**

- Produces: `Pack.Product.Start`, a path relative to the pack, which T08 sets and T11 reads.

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

### Task gallery-runtime-T04: the API on `HOST`, and the runtime names

**Files (in `helheim-go`):**

- Modify: `templates/api/cmd/api/main.go` and `main_test.go` (`HOST`), `templates/api/AGENTS.md` and
  `prompts/implementer.md` (the runtime names, the bucket, `release.sh`), `docs/architecture.md`
- Create: `runtime_test.go`

**Interfaces:**

- Produces: the API's names of delta §9.4, which T09, T10 and T14 use.

- [ ] **Step 1: the failing tests.**
  - `TestListensOnHost` in the template's `main_test.go`: with `HOST=127.0.0.1` the server's address is
    `127.0.0.1:<port>`; with no `HOST`, it is `:<port>`, all interfaces, as today (a sandbox may reach the API from
    another container).
  - `TestPromptNamesTheRuntime` in `runtime_test.go`: the implementer prompt and the template's `AGENTS.md` name each
    of `PORT`, `HOST`, `DATABASE_URL`, `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`,
    `S3_SECRET_ACCESS_KEY`, `X-Forwarded-Host`, `/app/start.sh` and `release.sh`.

  Run them. Expected: FAIL.
- [ ] **Step 2:** the server listens on `HOST:PORT`, and on all interfaces when `HOST` is unset.
- [ ] **Step 3:** the template's `AGENTS.md` and the prompt say: the API reads only the names of delta §9.4; it builds
  public addresses from `X-Forwarded-Host` and `X-Forwarded-Proto`; storage URLs are path-style, `/<S3_BUCKET>/<key>`,
  signed for that address; the API makes the bucket at start when it is missing, with versioning on when the store
  supports it; the product's `/app/start.sh` is the factory's and no task changes it; keep `release.sh` working, and
  change it only when the leaf's build changes.
- [ ] **Step 4:** run the tests, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The API listens on `HOST` when it is set, and where it does today when it is not.
- [ ] The prompt and the template's `AGENTS.md` name the runtime, the bucket and `release.sh`.

**Named test:** `templates/api/cmd/api/main_test.go:TestListensOnHost`, `helheim-go/runtime_test.go:TestPromptNamesTheRuntime`.
**Layer:** `helheim-go`. **Size:** M, about 150 lines. **Depends on:** T01.

### Task gallery-runtime-T05: the API's release

Waits for the founder's answer to question 1.

**Files (in `helheim-go`):**

- Create: `templates/api/release.sh`, `release_test.go`
- Modify: `docs/architecture.md`

- [ ] **Step 1: the failing test.** `TestReleaseScriptStarts` (so that `-run ReleaseScript` finds it): copy the
  template, run `release.sh` with `OUT` set to an empty folder, then run `OUT/run.sh` with `PORT` free,
  `HOST=127.0.0.1` and a `PATH` of `/usr/bin:/bin` only (no Go), and wait for the port. Assert that `OUT` holds only
  regular files and folders. Skip without Go; fail with `YGG_REQUIRE_TEMPLATES=1`. Expected: FAIL.
- [ ] **Step 2:** write `release.sh`: `CGO_ENABLED=0 GOWORK=off GOFLAGS=-mod=readonly go build -trimpath -o "$OUT/api" ./cmd/api`
  (it may download modules through the realm's egress), then write `OUT/run.sh`, which checks `PORT` as the leaf's
  `run.sh` does and runs `exec "$(dirname "$0")/api"`. The migrations are embedded already. Print the binary's size.
- [ ] **Step 3:** run the test, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The release starts with no Go on the `PATH`, and holds only regular files. The pull request gives the binary's
  size, for T12's bound.

**Named test:** `helheim-go/release_test.go:TestReleaseScriptStarts`.
**Layer:** `helheim-go`. **Size:** M, about 120 lines. **Depends on:** T04, and question 1 answered.

### Task gallery-runtime-T06: the web leaf's server, on `HOST`

It fixes B-117.

**Files (in `midgard-react`):**

- Create: `templates/web/serve.mjs` (Node's standard library only), `serve_test.go`
- Modify: `templates/web/run.sh` (build, then `node serve.mjs`), `runscript_test.go`, `templates/web/AGENTS.md`,
  `prompts/implementer.md`, `docs/architecture.md`

**Interfaces:**

- Produces: `serve.mjs`, which reads `PORT`, `HOST`, `API_URL`, `S3_ENDPOINT`, `S3_BUCKET` and `DIST` (default
  `dist`). T07 copies it into the release, and T10 bakes a copy for the acceptance run.

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
  Expected: PASS. The docs and the prompt say that `serve.mjs` is what serves the leaf, that it forwards `/api/` and
  the bucket's path, and that `release.sh` is kept working and changed only when the leaf's build changes.

**Acceptance criteria:**

- [ ] `serve.mjs` forwards `/api/` and the bucket's path as delta §9.3 says, adds no `X-Forwarded-*` header to the
  store's requests, and serves the bundle with the fallback.
- [ ] It listens on `HOST`, loopback by default; `run.sh` uses it.

**Named test:** `midgard-react/serve_test.go:TestServeForwards`; `midgard-react/runscript_test.go:TestRunScriptStarts`.
**Layer:** `midgard-react`. **Size:** M, about 300 lines. **Depends on:** T01.

### Task gallery-runtime-T07: the web leaf's release

Waits for the founder's answer to question 1.

**Files (in `midgard-react`):**

- Create: `templates/web/release.sh`, `release_test.go`
- Modify: `docs/architecture.md`

- [ ] **Step 1: the failing test.** `TestReleaseScriptStarts`: copy the template **without** `node_modules` (a
  snapshot of committed files has none), run `release.sh` with `OUT` set to an empty folder, then run `OUT/run.sh`
  with `PORT` free and a `PATH` that holds `node` and no `npm`, from a folder with no `node_modules`, and wait for the
  port. Assert that `OUT` holds only regular files and folders, and no `node_modules`. Skip without `npm`; fail with
  `YGG_REQUIRE_TEMPLATES=1`. Expected: FAIL.
- [ ] **Step 2:** write `release.sh`: `npm ci --ignore-scripts --no-audit --no-fund` (as the acceptance run does; it
  fetches through the realm's egress), `npm run build`, copy `dist/` to `OUT/dist` and `serve.mjs` to `OUT/`, and
  write `OUT/run.sh`, which checks `PORT` and runs `exec node serve.mjs` in its own folder.
- [ ] **Step 3:** run the test, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The release builds from a copy with no `node_modules`, starts with Node alone (no `npm`, no `node_modules`), and
  holds only regular files.

**Named test:** `midgard-react/release_test.go:TestReleaseScriptStarts`.
**Layer:** `midgard-react`. **Size:** M, about 150 lines. **Depends on:** T06, and question 1 answered.

### Task gallery-runtime-T08: the pack names the product start

**Files (in `midgard-react`):**

- Create: `templates/product/start.sh` (a placeholder that exits 1 with "not built yet"; T09 writes it)
- Modify: `pack.yaml` (`product: {start: templates/product/start.sh}`), `pack_test.go`, `go.mod` and `go.sum` (the
  merged `gungnir`)

- [ ] **Step 1: the failing test.** `TestPackNamesTheProductStart` in `pack_test.go`: the pack loads with the merged
  `gungnir`, and `Product.Start` is an executable file in the pack. Expected: FAIL.
- [ ] **Step 2:** pin the merged `gungnir`, add the field and the placeholder.
- [ ] **Step 3:** run `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The pack names the script, and loads with the merged `gungnir`.
- [ ] `odin`'s first pull request (T11, with the same pin) is merged before this one.

**Named test:** `midgard-react/pack_test.go:TestPackNamesTheProductStart`.
**Layer:** `midgard-react`. **Size:** S, about 60 lines. **Depends on:** T03 merged, T11 merged.

### Task gallery-runtime-T09: the product start script

It fixes B-078 for the web realm.

**Files (in `midgard-react`):**

- Modify: `templates/product/start.sh`, `docs/architecture.md`, `README.md`
- Create: `productstart_test.go`

**Interfaces:**

- Consumes: T04's and T06's names; the releases of T05 and T07 when they exist.
- Produces: the script that T11 writes at a project's root.

- [ ] **Step 1: the failing test.** `TestProductStart` (so that `-run ProductStart` finds it): a temporary
  `/app`-like folder with stand-in releases at `.ygg/release/repos/api/run.sh` and `.ygg/release/repos/web/run.sh`
  (each records its environment and opens its port), and stand-in `initdb`, `postgres`, `pg_ctl`, `createdb` and
  `weed` first on the `PATH` (each records its arguments and opens the port it is given). Assert:
  - the web part gets `HOST=0.0.0.0`, `PORT=3000`, `API_URL`, `S3_ENDPOINT` and `S3_BUCKET`;
  - the API gets `HOST=127.0.0.1` and every name of delta §9.4, with a key pair that differs between two starts;
  - Postgres and SeaweedFS get data folders under `.data/`, listen on `127.0.0.1`, and SeaweedFS's volume port is
    not the API's;
  - SeaweedFS gets an identity file, mode `0600`, and the key appears in no output of the script;
  - with no release, the script starts `repos/api/run.sh` and `repos/web/run.sh` instead;
  - with no `repos/web`, it exits non-zero with a message that names the path;
  - a part that does not open its port makes the script exit non-zero and name the part, and stops the others;
  - a `TERM` to the script stops every part;
  - run as root (`id -u` stubbed to 0), it refuses.

  It needs only `bash` and the stand-ins, so it never skips. Expected: FAIL.
- [ ] **Step 2:** write `start.sh`, in bash, after `accept-e2e.sh`: refuse root; `cd` to its own folder; find the
  leaves at `repos/api` and `repos/web`; make `.data/`; `initdb` once, start `postgres` on `127.0.0.1:5432` with its
  socket in the temporary folder, and run `createdb app` once; write SeaweedFS's identity file with a fresh key pair
  from `/dev/urandom`, and start `weed server -s3` on `127.0.0.1` with its S3 port 8333 and its other ports away from
  8080; wait for each port (the waits sum to well under 2 minutes); start the API, then the web part; `wait` on all of
  them and stop the rest when one ends.
- [ ] **Step 3:** run the test, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS. `shellcheck -s bash`
  on the script: no output.

**Acceptance criteria:**

- [ ] `TestProductStart` passes, and each of its assertions fails when the script's matching line is taken out.

**Named test:** `midgard-react/productstart_test.go:TestProductStart`.
**Layer:** `midgard-react`. **Size:** M, about 300 lines. **Depends on:** T04, T06, T08.

### Task gallery-runtime-T10: the acceptance run on the new contract

Without it, an end-to-end spec that uploads a photo fails at every pointer move of run 1: `accept-e2e.sh` starts the
API with `PORT` and `DATABASE_URL` only, and its baked `vite.config.ts` forwards only `/api`, with `changeOrigin`.

**Files (in `midgard-react`):**

- Modify: `devcontainer/checks/accept-e2e.sh`, `devcontainer/checks/web-configs.sh` (the baked server), `checks_test.go`,
  `docs/architecture.md`
- Create: `devcontainer/checks/config/serve.mjs` (byte for byte `templates/web/serve.mjs`)

- [ ] **Step 1: the failing tests.**
  - `TestAcceptanceGivesTheRuntime` in `checks_test.go`, with stand-in `go`, `npm` and `node` on the `PATH` (follow
    the existing acceptance tests): the API is started with every name of delta §9.4, with `S3_ENDPOINT` the
    sandbox's SeaweedFS (`http://seaweedfs:8333` unless `YGG_S3_ENDPOINT` says otherwise) and a bucket name; the web
    app is served by the baked `serve.mjs`, not the leaf's, with `API_URL`, `S3_ENDPOINT` and `S3_BUCKET`.
  - `TestBakedServeIsTheTemplates`: the baked `serve.mjs` and the template's are the same bytes.

  Expected: FAIL.
- [ ] **Step 2:** change `accept-e2e.sh`: build the bundle with the baked config as today, then serve it with the
  baked `serve.mjs`; pass the names. Keep the Prism branch for a product with no API.
- [ ] **Step 3:** read `web-e2e.sh` (the e2e rung). It runs against a Prism mock and has no store, so an e2e spec that
  uploads cannot pass there. Write in `docs/architecture.md` and in the pull request what the rung does with such a
  spec today. T17 files a backlog item if it fails every upload spec.
- [ ] **Step 4:** run the tests, then `YGG_REQUIRE_TEMPLATES=1 go test ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The acceptance run gives the API the runtime names and serves the web app with the realm's baked server.
- [ ] The baked server is the template's, byte for byte.
- [ ] The e2e rung's behaviour with an upload spec is written down.

**Named test:** `midgard-react/checks_test.go:TestAcceptanceGivesTheRuntime`, `TestBakedServeIsTheTemplates`.
**Layer:** `midgard-react`. **Size:** M, about 250 lines. **Depends on:** T04, T06.

### Task gallery-runtime-T11: `init` writes the product start

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
- [ ] `odin` pins the merged `gungnir`, so it loads a pack that names `product`.

**Named test:** `odin/internal/engine/init_product_test.go:TestInitWritesProductStart`.
**Layer:** `odin`. **Size:** M, about 200 lines. **Depends on:** T03 merged.

### Task gallery-runtime-T12: the release in the export

Waits for the founder's answer to question 1.

**Files (in `odin`):**

- Modify: `internal/run/grade.go` (`ExportApp`), `internal/engine/grade.go` (a release failure is a `GradeFailed`),
  `docs/architecture.md`
- Create: `internal/run/release.go`, `internal/run/release_test.go`

**Interfaces:**

- Produces: `run.Releaser`, `Build(ctx, snapshot string, leaves []string) (dir string, err error)`, and its use in
  `ExportApp`. T13 gives the real one.

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
  named as constants in `release.go` (for example 128 MiB per file and 512 MiB in all; set them from T05's and T07's
  sizes), not the snapshot's limits for source (`internal/snapshot/snapshot.go`: 32 MiB per file, 256 MiB in all).
  Keep each release in the run folder under the commits it was built from. Write the releaser's output to
  `release.log` beside `grade.log`, mode `0600`.
- [ ] **Step 3:** run the tests, then `GOWORK=off go test -race ./...`. Expected: PASS. `ygg bridge`'s tests still pass:
  its upload is the same export.

**Acceptance criteria:**

- [ ] The five tests pass. A release is never committed to the project or a leaf.

**Named test:** `odin/internal/run/release_test.go:TestExportAppAddsTheRelease`, `TestReleaseIsReused`,
`TestReleaseRefused`, `TestReleaseBound`; `odin/internal/engine/grade_test.go:TestGradeFailsOnARelease`.
**Layer:** `odin`. **Size:** M, about 300 lines. **Depends on:** T01, and question 1 answered.

### Task gallery-runtime-T13: the release built in the acceptance sandbox

Waits for the founder's answer to question 1.

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
**Layer:** `odin`. **Size:** M, about 250 lines. **Depends on:** T12.

### Task gallery-runtime-T14: the prompts name the runtime

**Files (in `voluspa`):**

- Modify: `software/prompts/spec.md`, `software/prompts/plan.md`, `prompts_test.go`

- [ ] **Step 1: the failing test.** `TestPromptsNameTheRuntime`: `spec.md` says that the product runs on one machine
  with Postgres and an S3 store started by the factory's `start.sh`, that the leaves are `repos/web` and `repos/api`
  and no other, and names the API's and the web leaf's variables of delta §9.4; `plan.md` says that no task writes
  `start.sh` or any file outside its leaf. Expected: FAIL.
- [ ] **Step 2:** add the lines, short, in the prompts' style.
- [ ] **Step 3:** run `GOWORK=off go test -race ./...`. Expected: PASS.

**Acceptance criteria:**

- [ ] The test passes, and fails when any of the lines is taken out.

**Named test:** `voluspa/prompts_test.go:TestPromptsNameTheRuntime`.
**Layer:** `voluspa`. **Size:** S, about 60 lines. **Depends on:** T01.

### Task gallery-runtime-T15: the runtime smoke script

It builds the releases as question 1's answer says; as assumed, with each realm's `release.sh`.

**Files (in `ouroboric`):**

- Create: `scripts/ygg-smoke-runtime.sh`, `scripts/tests/ygg-smoke-runtime.test.sh`
- Modify: `AGENTS.md` (the scripts table)

**Interfaces:**

- Produces: `ygg-smoke-runtime.sh [--image REF] [--folder DIR] [--yggdrasil DIR]`, which T16 runs.

- [ ] **Step 1: the failing test.** `ygg-smoke-runtime.test.sh`, with a stand-in `podman` first on the `PATH` that
  records its arguments. The script builds each template's release in that realm's sandbox image, puts the product
  start at the root of a folder laid out like `/app`, makes a Podman network with `--internal`, and runs the product
  in the task image on that network with `--user app`. It runs its checks from a second container on the same
  network, and removes both containers and the network at the end. It refuses a missing image or a missing realm with
  a message, and never names `hidden-suites` or a credentials file. Expected: FAIL.
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
  - the time from start to the first answer, in seconds.
- [ ] **Step 3:** run the test and `shellcheck -s bash`. Expected: the test's lines all `ok`; no output.

**Acceptance criteria:**

- [ ] The test passes with the stand-in engine; the script names its checks and their order in its header.

**Named test:** `ouroboric/scripts/tests/ygg-smoke-runtime.test.sh`.
**Layer:** `ouroboric`. **Size:** M, about 300 lines. **Depends on:** T05, T07, T09.

### Task gallery-runtime-T16 (founder): the runtime smoke on the real engine

- [ ] **Step 1:** check out `gungnir`, `helheim-go`, `midgard-react`, `odin` and `voluspa` at their merged `main`
  (the umbrella's pointers move only in T17), and build `ygg` from that `odin`.
- [ ] **Step 2:** build the 4.1.0 image and run the smoke:

  ```zsh
  cd ~/brunogbv/ouroboric/ouroboric
  scripts/ygg-smoke-runtime.sh --image cgl:4.1.0
  ```

  Expected: every check `PASS`, and the time to the first answer under 120 seconds. Note whether SeaweedFS 4.45
  turned versioning on for the bucket (proposal question 7).
- [ ] **Step 3 (optional):** run the content smoke with the gallery's brief (`ygg-smoke-realms.sh --graph software
  --brief <mimir>/client-gallery-lite/instruction.md --tag h15`), then `ygg grade <run> --project <project>`. The
  suites folder is passed by path and nobody reads it. Expected: a grade that ends with a reward (a template product
  scores low), no `GradeFailed`, and a `release.log` that shows both leaves built.
- [ ] **Step 4:** paste the output on the `yggdrasil` pull request of T17.

**Acceptance criteria:**

- [ ] Every check of the smoke passes on the real engine, with the merged repos.
- [ ] Whether versioning is on is written on the pull request.

**Named test:** `ygg-smoke-runtime.sh` on the 4.1.0 image.
**Layer:** the founder's machine. **Size:** S. **Depends on:** T02, and T04 to T15 merged.

### Task gallery-runtime-T17: fold the delta, the checklist, the backlog and the pointers

**Files (in `yggdrasil`):**

- Modify: `docs/2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md` (§9.3, §9.4, §11, as the delta says),
  `docs/2-engineering/realm-readiness.md` (RR-24, RR-25), `docs/2-engineering/backlog.md`,
  `docs/3-using/operations/proof-runs.md` (the task is 4.1.0), this folder's front matter (`status: accepted`), the
  pointers of `gungnir`, `helheim-go`, `midgard-react`, `odin` and `voluspa`

**Where the delta goes.** The changes README says a merged delta is folded into `../system/` and the folder moves to
`archive/`. The earlier changes did not do that: they folded their deltas into the dated v0 spec and stayed where they
are, and no `changes/archive/` exists. This change does what the earlier ones did. Moving every change to the living
spec is its own piece of work, which T17 files in the backlog.

- [ ] **Step 1:** fold the delta into the dated spec. Add RR-24 and RR-25 to the checklist, with their checks.
- [ ] **Step 2:** in the backlog, mark B-078, B-117, B-118 and B-140 done with the pull requests; add to B-116 that a
  leaf now starts alone from its release. File these items: the acceptance run does not build or start the release,
  so no check runs `release.sh`; the development sandbox's SeaweedFS accepts anonymous requests; the e2e rung and
  upload specs (from T10's finding), if it fails them; versioning on SeaweedFS, if T16 found it off; the changes
  README's archive rule, which no change follows yet.
- [ ] **Step 3:** the proof-runs runbook says the runs use task 4.1.0, and that question 10 is answered (option A).
- [ ] **Step 4:** move the pointers to the merged commits. Set this folder's front matter to `accepted`.
- [ ] **Step 5:** run `pre-commit run --files` on every changed file, and the docs check. Expected: pass; no problem
  names a changed file.

**Acceptance criteria:**

- [ ] The spec holds every line of the delta, and the checklist has RR-24 and RR-25.
- [ ] The four backlog items are done, with links, and the new items are filed.
- [ ] The pointers are the merged commits.

**Named test:** `pre-commit run --files` on the changed files; the docs check.
**Layer:** `yggdrasil`. **Size:** M, about 200 lines. **Depends on:** T16.

## Open for the builder

- **SeaweedFS and the forwarded `Host` (to verify).** The proposal assumes that its S3 API checks a signature against
  the `Host` it receives, and that it may read `X-Forwarded-Host` before `Host` (from memory, unverified), which is why
  the storage forward adds no `X-Forwarded-*` header. If T16's signed request fails, say so and propose the fix (for
  example, the API signs for the store's own address and the web leaf rewrites `Host`) before going on.
- **The S3 region and the bucket's name.** Pick a fixed region (`us-east-1`) and a bucket name that no route of the
  web app uses (for example `ygg-store`). Say which in T04 and T09; T10 uses the same.
- **Postgres's socket and port.** `start.sh` may use a TCP port on `127.0.0.1` or only the socket in the temporary
  folder. `DATABASE_URL` must work with `pgx` either way.
- **Where the release is copied out of the sandbox.** `SnapshotRunner` writes into a snapshot on the host. Say how
  T13 reads it as the host user.
