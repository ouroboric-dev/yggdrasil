---
title: Tasks for the realm readiness checklist and the first assessments
status: accepted
date: 2026-10-18
related: [proposal.md, delta.md, ../../../1-product/design/2026-10-18-ginnungagap-design.md]
style: spec
---

# Realm readiness: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking. Steps marked **founder** are done by the founder, never by
> an agent.

**Goal:** a written realm readiness checklist, CI on both build realms and on the products their
templates make, one shared `docs.sh`, and filed assessments of `midgard-react`, `helheim-go` and
`asgard`, before the Phase 5c plan.

**Architecture:** the checklist and the assessments are Markdown in the `yggdrasil` umbrella. Each
build realm gets a root `ci.yml` that runs its Go tests with template tests forced on, and a
`ci.yml` inside its template that runs the stack's own commands on the stack's pinned images. A Go
test in each realm keeps the template's workflow pinned and in step with the stack. The ladder adds
`.github/` to its protected paths. `check-repos.sh` gains a `shared` check that compares the realms'
copies of `docs.sh`.

**Tech stack:** GitHub Actions, Go tests (standard library only), bash, `check-repos.sh`'s test
harness, actionlint.

**Spec:** [proposal](proposal.md), [delta](delta.md), and the design doc's §6 and §8.1. Read all
three. Where this plan and the design differ, this plan wins.

**Status:** accepted when the founder merges the pull request that adds this file.

## Decisions made by this plan

- **`helheim-go`'s `docs.sh` is the source** until Ginnungagap's base stage exists. `midgard-react`
  takes its copy byte for byte. `check-repos.sh --check shared` compares every realm's copy with it.
- **A product's `lint.yml` is not the template's job.** It comes from repo creation (change
  `repo-bootstrap`, delta §4.2 `init`). RR-18 asks only for `ci.yml`.
- **The web template's CI runs no Playwright.** It runs `npm ci`, lint, typecheck, the unit tests and
  the build. The ladder's e2e rung keeps the browser tests.
- **The realm CI uses the stack's own base images.** `helheim-go`'s job runs in the Go stage's image.
  `midgard-react`'s job runs in the web stage's Node image, with Go installed by `actions/setup-go`
  at `1.26.9`.
- **The template's workflow is protected like the dev container.** A task that changes anything under
  `.github/` fails rung 1.

## Global constraints

- Images, exact (the same digests the stacks pin):
  - Go: `docker.io/library/golang:1.26.9-bookworm@sha256:d9c68c2c51161e12fd77e4c6320687c9cd86e1af1e3ad6e6cd63ff970641453c`
  - Node: `docker.io/library/node@sha256:efd0ab5780c2d9ab1f0f869571a00d5edb17793bff4cce4a2792e3eb0ffc7562`
  - Postgres: `docker.io/library/postgres:17.10-bookworm@sha256:9b18b78397054fce88a9552e9d5a3ad5bb7fd258c5b3cc1c5028e46373d6ea8f`
- Actions: `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`. For
  `actions/setup-go`, pin a release at least two weeks old by its full SHA, with a `# vX.Y.Z`
  comment.
- Tools: `golang.org/x/vuln/cmd/govulncheck@v1.8.0`, `golangci-lint` `v2.14.0`, actionlint run as
  `go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12 <file>`.
- Every workflow: `on: pull_request` and `push` to `main`; `permissions: contents: read`; one job
  named `test`; `timeout-minutes: 15`; checkout with `persist-credentials: false`; a header comment
  that says what it is and who may change it, like `odin/.github/workflows/ci.yml`.
- A root `.github/workflows/` file is pushed by the founder: the pr-bot has no Workflows permission. A
  workflow under `templates/` is pushed by the pr-bot. If GitHub refuses that push, stop and tell the
  founder.
- Go tests use the standard library only. No new module goes into `go.mod`.
- Write each test first and watch it fail (invariant 2). Commit messages end with the task id, as
  `(realm-readiness-T00n)`, and with
  `Co-Authored-By: Claude <model> <noreply@anthropic.com>`. Never add session links.
- A docs file passes the docs check: `YGG_CHECKS_PATH="$PATH" bash helheim-go/devcontainer/checks/docs.sh`,
  run in the umbrella, names no problem in a file that the task added or changed. (The umbrella has 43
  older problems, which are not this plan's.)

## Review focus

1. **The template's workflow drifts from the stack:** a digest bumped in the `Containerfile` or
   `pack.yaml` but not in the workflow. A test compares them (T004, T005).
2. **An agent weakens the product's CI** by editing the template's `ci.yml` in a task. Rung 1 must
   refuse it (T004, T005).
3. **The realm's CI passes by skipping the template tests,** because `npm` or the module proxy is not
   reachable. `YGG_REQUIRE_TEMPLATES=1` makes them fail instead. The first CI run's log must show
   them run (T002, T003).
4. **`check-repos.sh --check shared` with a realm that is not checked out** at its side-by-side path
   must FAIL and name the path. It must never pass (T007).
5. **The integration tests in the product's CI reach a different database** than the ladder does.
   The workflow must set `YGG_DATABASE_URL` in the same form `go-integration.sh` builds, with the
   service's host name (T004).

## How each task lands

Each task is one pull request in its layer's repo, from a branch `realm-readiness-T00n` made from
`main`. Use the tree's scripts: `../ouroboric/scripts/as-bot.sh <repo> git push -u origin <branch>`,
then `as-bot.sh <repo> gh pr create ...`. Stage files by path. The PR body lists the task's
acceptance criteria with the named tests' output.

---

### Task realm-readiness-T001: the realm readiness checklist

**Files (in `yggdrasil`):**

- Create: `docs/2-engineering/realm-readiness.md` (front matter `style: procedure`)
- Modify: `docs/3-using/operations/README.md` (one line that links to the checklist)

**Interfaces:**

- Produces: the item IDs `RR-01` to `RR-22`, which T008's assessments and backlog entries cite.

- [ ] **Step 1:** Write the checklist from design §6, with these changes:
  - The steps above the table, as in Asgard's checklist: copy the table into
    `docs/2-engineering/readiness/YYYY-MM-DD-<realm>.md`; fill one row for each item; give evidence
    for each item, or mark it `missing`. The status values are `met`, `partial`, `missing` and `n/a`
    (with a reason).
  - A column, **How to check**, which names the command for each `auto` item. For example:
    - RR-01: `check-repos.sh --check settings --check security --check ruleset <repo>`, which the
      founder runs under `as-bot.sh --read all`;
    - RR-02: `check-repos.sh --check reuse <repo>`;
    - RR-05: `check-repos.sh --check agents <repo>`;
    - RR-06: `check-repos.sh --check gitleaks <repo>`;
    - RR-09: `check-repos.sh --check shared <repo>`;
    - RR-07: the docs check, run in the leaf;
    - RR-08 and RR-12: `go test -run Pack ./...` in the leaf;
    - RR-17: `YGG_REQUIRE_TEMPLATES=1 go test -run Template ./...`;
    - RR-21: `ygg-smoke-realms.sh`.
  - RR-09 names its shared files: `devcontainer/checks/docs.sh` today.
  - RR-18 asks: does the template give the product `.github/workflows/ci.yml` with a job `test`, and
    the MIT licence with the "Built with Ouroboric" notice? It says that `lint.yml` and the
    pre-commit config come from repo creation.
  - A note on the items that read GitHub (RR-01, and "passes on `main`" in RR-03 and RR-04): the
    founder runs them.
  - A note on the wiring items RR-10 and RR-21, from design §6.
- [ ] **Step 2:** Run the docs check (Global constraints). Expected: no problem names
  `realm-readiness.md` or `operations/README.md`.
- [ ] **Step 3:** Commit, push and open the PR.

**Acceptance criteria:**

- [ ] The checklist has RR-01 to RR-22, each with an "applies to" value, a check type, and a "How to
  check" for each `auto` item.
- [ ] The docs check names no problem in either file.

**Named test:** the docs check on `docs/2-engineering/realm-readiness.md`.
**Layer:** `yggdrasil`. **Size:** M. **Depends on:** this change merged.

### Task realm-readiness-T002: `helheim-go`'s own CI

**Files (in `helheim-go`):**

- Create: `.github/workflows/ci.yml`
- Modify: `README.md` (one line: the `test` check, what it runs), `docs/architecture.md` (the CI)

**Interfaces:** none.

- [ ] **Step 1:** Write `ci.yml`, modelled on `odin/.github/workflows/ci.yml`: the Go image as the
  container; `GOWORK=off`, `GOTOOLCHAIN=local`, `GOFLAGS=-mod=readonly`, `YGG_REQUIRE_TEMPLATES=1`;
  steps gofmt, `go vet ./...`, `go test -race ./...` as a non-root user, then govulncheck.
- [ ] **Step 2:** Run actionlint on it. Expected: no output, exit 0.
- [ ] **Step 3:** Run the same commands locally in the Go image:
  `podman run --rm -v "$PWD":/src:Z -w /src -e YGG_REQUIRE_TEMPLATES=1 <Go image> go test ./...`.
  Expected: `ok`. A test that skips because a stack tool is missing is listed in the PR body.
- [ ] **Step 4:** Commit. **Founder:** push the branch and open the PR (`ci.yml` is under the root
  `.github/workflows/`). Expected: the `test` check passes, and its log shows the template test ran.
- [ ] **Step 5 (founder):** after the merge, run `setup-repo.sh` for `helheim-go`. Expected:
  `check-repos.sh --check ruleset helheim-go` prints `PASS`.

**Acceptance criteria:**

- [ ] `test` passes on the PR, and `TestTemplate*` ran, not skipped.
- [ ] `test` is required on `main`.

**Named test:** the `test` workflow on the PR; `check-repos.sh --check ruleset helheim-go`.
**Layer:** `helheim-go`. **Size:** S. **Depends on:** this change merged.

### Task realm-readiness-T003: `midgard-react`'s own CI

**Files (in `midgard-react`):**

- Create: `.github/workflows/ci.yml`
- Modify: `README.md`, `docs/architecture.md` (as in T002)

**Interfaces:** none.

- [ ] **Step 1:** Write `ci.yml` like T002's, with these differences: the Node image as the
  container; Go `1.26.9` from `actions/setup-go` (pinned by SHA); no govulncheck step unless the
  module has Go dependencies beyond the standard library. The template test needs `npm` and the
  e2e test needs `python3`. Both are in the Node image.
- [ ] **Step 2:** Run actionlint. Expected: no output, exit 0.
- [ ] **Step 3:** Run `YGG_REQUIRE_TEMPLATES=1 go test ./...` locally with Go and Node on `PATH`.
  Expected: `ok`, and no `SKIP` for `TestTemplate*` or the e2e test.
- [ ] **Step 4:** Commit. **Founder:** push and open the PR. Expected: `test` passes, and its log
  shows the template and e2e tests ran.
- [ ] **Step 5 (founder):** run `setup-repo.sh` for `midgard-react`. Expected:
  `check-repos.sh --check ruleset midgard-react` prints `PASS`.

**Acceptance criteria:**

- [ ] `test` passes on the PR, and the template and e2e tests ran, not skipped.
- [ ] `test` is required on `main`.

**Named test:** the `test` workflow on the PR; `check-repos.sh --check ruleset midgard-react`.
**Layer:** `midgard-react`. **Size:** S. **Depends on:** this change merged.

### Task realm-readiness-T004: the API template's CI, protected

**Files (in `helheim-go`):**

- Create: `templates/api/.github/workflows/ci.yml`, `ci_test.go`
- Modify: `devcontainer/checks/go-static.sh` (`protected=('.devcontainer/' '.github/')`),
  `checks_test.go`, `docs/architecture.md` (what the template's CI runs)

**Interfaces:**

- Produces: `TestTemplateCI` in `ci_test.go`, the model for T005's test.

- [ ] **Step 1: Write the failing tests.**
  - `TestTemplateCI` reads `templates/api/.github/workflows/ci.yml` as text and asserts:
    - it has the line `test:`, indented two spaces, under `jobs:`, and no other job;
    - each `uses:` line matches `@[0-9a-f]{40} # v`;
    - the container image is the `FROM` image of `devcontainer/Containerfile`'s `stack` stage;
    - the Postgres service image is `pack.yaml`'s `services.postgres.image`, and its env holds
      `POSTGRES_DB: app` and `POSTGRES_HOST_AUTH_METHOD: trust`;
    - it holds `contents: read`, `persist-credentials: false`, and
      `YGG_DATABASE_URL: postgres://postgres@postgres:5432/app?sslmode=disable`.
  - `TestStaticRefusesAWorkflowChange` in `checks_test.go`: a leaf whose task adds
    `.github/workflows/ci.yml`, and one whose task changes it, each fail `go-static.sh` with the path
    in the output. Follow the existing protected-path tests.
- [ ] **Step 2:** Run `go test -run 'TestTemplateCI|TestStaticRefusesAWorkflowChange' ./...`.
  Expected: FAIL (no workflow; the path is not protected).
- [ ] **Step 3:** Write the workflow. Steps: gofmt; `go vet ./...`; golangci-lint `v2.14.0` with the
  template's `.golangci.yml`; `go test -race ./...`; `go test -race -tags integration ./...`;
  govulncheck. Add `.github/` to `protected` in `go-static.sh`.
- [ ] **Step 4:** Run the two tests, then `go test ./...`, then actionlint on the workflow. Expected:
  all pass.
- [ ] **Step 5:** Run the workflow's commands in a copy of `templates/api` in the Go image, with a
  Postgres container. Expected: every command exits 0. (This is the first commit of a product.)
- [ ] **Step 6:** Commit, push and open the PR.

**Acceptance criteria:**

- [ ] `TestTemplateCI` and `TestStaticRefusesAWorkflowChange` pass, and fail when the workflow's
  image digest is edited, or when the path is taken out of `protected`.
- [ ] The workflow's commands pass on a fresh copy of the template.

**Named test:** `helheim-go/ci_test.go:TestTemplateCI`,
`helheim-go/checks_test.go:TestStaticRefusesAWorkflowChange`.
**Layer:** `helheim-go`. **Size:** M. **Depends on:** T002 (so the realm's CI runs these tests).

### Task realm-readiness-T005: the web template's CI, protected

**Files (in `midgard-react`):**

- Create: `templates/web/.github/workflows/ci.yml`, `ci_test.go`
- Modify: `devcontainer/checks/web-protected.sh` (`files=('.npmrc' '.github/')`),
  `checks_test.go`, `docs/architecture.md`

**Interfaces:**

- Consumes: T004's `TestTemplateCI` as the model.

- [ ] **Step 1: Write the failing tests.**
  - `TestTemplateCI` asserts what T004's does, with these differences: the container image is the
    `FROM` image of the `web` stage; there is no service; and each `npm run <name>` names a script in
    `templates/web/package.json` (as `build_prompts_test.go` checks the prompts).
  - `TestEveryRungRefusesAWorkflowChange` in `checks_test.go`: for each rung, a task that adds or
    changes `.github/workflows/ci.yml` fails before it installs anything, with the path in the
    output. Follow the existing `.npmrc` test.
- [ ] **Step 2:** Run both. Expected: FAIL.
- [ ] **Step 3:** Write the workflow. Steps: `npm ci --ignore-scripts --no-audit --no-fund`,
  `npm run lint`, `npm run typecheck`, `npm test`, `npm run build`. Add `.github/` to `files` in
  `web-protected.sh`.
- [ ] **Step 4:** Run the two tests, `go test ./...`, and actionlint. Expected: all pass.
- [ ] **Step 5:** Run the workflow's commands in a copy of `templates/web` in the Node image.
  Expected: every command exits 0.
- [ ] **Step 6:** Commit, push and open the PR.

**Acceptance criteria:**

- [ ] Both tests pass, and fail when a digest or an `npm run` name is edited, or when the path is
  taken out of `files`.
- [ ] The workflow's commands pass on a fresh copy of the template.

**Named test:** `midgard-react/ci_test.go:TestTemplateCI`,
`midgard-react/checks_test.go:TestEveryRungRefusesAWorkflowChange`.
**Layer:** `midgard-react`. **Size:** M. **Depends on:** T003.

### Task realm-readiness-T006: one `docs.sh`

**Files (in `midgard-react`):**

- Modify: `devcontainer/checks/docs.sh` (byte for byte `helheim-go`'s)

**Interfaces:**

- Produces: the two realms' `devcontainer/checks/docs.sh` are the same file, which T007's check
  verifies.

- [ ] **Step 1:** Run `cmp helheim-go/devcontainer/checks/docs.sh midgard-react/devcontainer/checks/docs.sh`
  in the umbrella. Expected: it reports a difference (the `PATH` lines).
- [ ] **Step 2:** Copy `helheim-go`'s file over `midgard-react`'s. Run the `cmp` again. Expected: no
  output, exit 0.
- [ ] **Step 3:** Run `go test ./...` in `midgard-react`. Expected: `ok`. (The copy sets `PATH` for
  `docs.sh` alone. It uses only `find`, `grep`, `sed` and `awk`, which are in `/usr/bin` and `/bin`.)
- [ ] **Step 4:** Commit, push and open the PR.

**Acceptance criteria:**

- [ ] The two copies are the same file, and `midgard-react`'s tests pass.

**Named test:** `cmp` of the two copies; `midgard-react` `go test ./...`.
**Layer:** `midgard-react`. **Size:** S. **Depends on:** this change merged.

### Task realm-readiness-T007: a check that keeps the shared scripts one

**Files (in `ouroboric`):**

- Modify: `scripts/check-repos.sh`, `scripts/tests/check-repos.test.sh`

**Interfaces:**

- Produces: in `check-repos.sh`, `check_shared <repo>`. For a repo in `REALMS=" midgard-react
  helheim-go "`, it compares the SHA-256 of each file in `SHARED=(devcontainer/checks/docs.sh)` with
  `helheim-go`'s copy. It prints `PASS <repo> shared`, or `FAIL <repo> shared: <file> differs from
  helheim-go's` or `...: <path> is missing`. For any other repo it prints
  `PASS <repo> shared: not a realm`. `shared` joins the default checks.
- Produces: `CHECK_REPOS_ROOT`, an environment override of `ROOT`, for the tests.

- [ ] **Step 1: Write the failing tests** in `check-repos.test.sh`, on a `CHECK_REPOS_ROOT` built in
  `$T` with the umbrella layout (`yggdrasil/<leaf>/...`):
  - the same file in both realms: `PASS`;
  - one byte different: `FAIL`, and the output names `docs.sh`;
  - the file missing in `midgard-react`, and the whole `midgard-react` folder missing: `FAIL`, with
    the path;
  - a repo that is not a realm (`gungnir`): `PASS ... not a realm`.
- [ ] **Step 2:** Run `bash scripts/tests/check-repos.test.sh`. Expected: the new lines start with
  `FAIL`.
- [ ] **Step 3:** Implement `check_shared` and the override, following `check_reuse`.
- [ ] **Step 4:** Run the test file. Expected: every line starts with `ok`, exit 0. Then run
  `uvx -q --from 'shellcheck-py==0.11.0.1' shellcheck -x -s bash scripts/check-repos.sh`. Expected:
  no output.
- [ ] **Step 5:** Commit, push and open the PR. Rebase it on any `repo-bootstrap` change to
  `check-repos.sh` that has merged by then.
- [ ] **Step 6:** After T006 merges, run `scripts/check-repos.sh --check shared midgard-react
  helheim-go`. Expected: two `PASS` lines.

**Acceptance criteria:**

- [ ] `check-repos.test.sh` passes, with the five new cases.
- [ ] `--check shared` passes on both realms.

**Named test:** `ouroboric/scripts/tests/check-repos.test.sh` (the `shared` cases).
**Layer:** `ouroboric`. **Size:** S. **Depends on:** this change merged; T006 for step 6.

### Task realm-readiness-T008: the three assessments

**Files (in `yggdrasil`):**

- Create: `docs/2-engineering/readiness/2026-10-<dd>-midgard-react.md`, `...-helheim-go.md`,
  `...-asgard.md` (front matter `style: procedure`, as Asgard's checklist uses)
- Modify: `docs/2-engineering/backlog.md`; the `midgard-react`, `helheim-go` and `asgard` submodule
  pointers (the commits that T002 to T006 merged)

**Interfaces:**

- Consumes: T001's checklist and item IDs; T007's `--check shared`.

- [ ] **Step 1:** Run each `auto` item's "How to check" on each realm, and keep the output.
  **Founder:** run the items that read GitHub (RR-01, the "passes on `main`" parts of RR-03 and
  RR-04) under `as-bot.sh --read all`, and paste the output.
- [ ] **Step 2:** Fill one assessment per realm: each row's status and evidence (a link, or the
  command and its output). Asgard is a document realm: build items are `n/a` with that reason.
- [ ] **Step 3:** For each row that is not `met` or `n/a`, add a backlog entry that names the realm
  and the item ID, unless an existing entry covers it (then link it). Known in advance: RR-03 (the
  base CI waits for `repo-bootstrap`'s rollout), RR-14 (B-044). Update B-043: the interim fix landed
  (T006, T007); the full fix is Ginnungagap's base stage.
- [ ] **Step 4:** Run the docs check. Expected: no problem names the new files or `backlog.md`.
- [ ] **Step 5:** Commit, push and open the PR. The body is a table: realm, `met`, `partial`,
  `missing`, `n/a` counts, and the backlog entries added.

**Acceptance criteria:**

- [ ] Three assessments, with every row filled and every `auto` row backed by output or a link.
- [ ] Every row that is not `met` or `n/a` has a backlog entry.

**Named test:** the docs check on the three files; each row's evidence.
**Layer:** `yggdrasil`. **Size:** M. **Depends on:** T001 to T007.

### Task realm-readiness-T009: the docs in `ouroboric`

**Files (in `ouroboric`):**

- Modify: `docs/4-ways-of-working/docs-standard.md` (the repo section), `AGENTS.md` (the scripts
  table: `check-repos.sh`'s `shared` check)
- Create: `docs/6-journal/2026-10-<dd>-a-definition-of-done-for-realms.md` (the journal's own front
  matter, see `docs/6-journal/README.md`)

**Interfaces:**

- Consumes: T008's counts for the journal's measured results.

- [ ] **Step 1:** In the docs standard's repo section, say what a realm repo holds beyond any repo:
  its own `ci.yml` (`test`), a `ci.yml` in each template, and a filed readiness assessment, with a
  link to the checklist.
- [ ] **Step 2:** Add `shared` to the `check-repos.sh` row of `AGENTS.md`'s scripts table.
- [ ] **Step 3:** Write the journal entry: the challenge (three realms with no definition of done),
  the solution (the checklist, the retrofit), and T008's counts as its results.
- [ ] **Step 4:** Run the docs check from `ouroboric` (as in Global constraints, with `ouroboric`'s
  `docs/`). Expected: no problem names a changed file.
- [ ] **Step 5:** Commit, push and open the PR.

**Acceptance criteria:**

- [ ] The docs standard and `AGENTS.md` match what T002 to T007 built.
- [ ] The journal entry quotes T008's counts.

**Named test:** the docs check on the changed files.
**Layer:** `ouroboric`. **Size:** S. **Depends on:** T007, T008.
