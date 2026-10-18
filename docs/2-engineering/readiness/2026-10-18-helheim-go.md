---
title: Realm readiness — helheim-go, 2026-10-18
status: draft
date: 2026-10-18
style: procedure
related: [../realm-readiness.md, ../backlog.md, 2026-10-18-midgard-react.md, 2026-10-18-asgard.md]
---

# Realm readiness: helheim-go, 2026-10-18

**Bottom line: not ready yet.** Of 22 items, 14 are met, 4 are partial, 3 are missing and 1 is `n/a`. The
partial items are in the backlog: B-055, B-056, B-057, B-058 and B-061. The three missing items are the human
items. They wait for the founder's judgement in this pull request.

- **Realm:** [`helheim-go`](https://github.com/ouroboric-dev/helheim-go) at
  [`60731f6`](https://github.com/ouroboric-dev/helheim-go/commit/60731f68cd463e12b62f2eafdac0b812bed69467), a build
  realm. This pull request moves the umbrella's pointer to that commit.
- **Checklist:** [realm readiness checklist](../realm-readiness.md), all 22 items.
- **How it was run:** the local checks of `check-repos.sh` ran on a clone of the realm. The founder's run of the
  GitHub items (RR-01, and "passes on `main`" for RR-03 and RR-04) is the controller's evidence file of
  2026-10-18T21:44:40Z, run under `as-bot.sh --read all`. The Go tests ran on this machine with the realm CI's
  settings, and the CI log of `main` was read with a read-only `gh run view`. The [evidence](#evidence) section
  holds each command and its decisive lines.

## Summary

| Status | Count | Items |
| --- | --- | --- |
| met | 14 | RR-01 to RR-03, RR-05 to RR-10, RR-12 to RR-14, RR-16, RR-17 |
| partial | 4 | RR-04, RR-15, RR-18, RR-21 |
| missing | 3 | RR-11, RR-19, RR-20 (human items) |
| n/a | 1 | RR-22 |

## Items

| ID | Status | Evidence | Backlog |
| --- | --- | --- | --- |
| RR-01 | met | `PASS helheim-go settings`, `security` and `ruleset` ([E1](#e1-github-settings-and-runs)). The ruleset check wants `lint` and `test` required, because both workflows exist. | — |
| RR-02 | met | `PASS helheim-go reuse` ([E2](#e2-local-repo-checks)). `REUSE.toml` gives `templates/**` MIT, and no template file has its own licence header. | — |
| RR-03 | met | `.github/workflows/lint.yml` came with the base CI ([helheim-go #7](https://github.com/ouroboric-dev/helheim-go/pull/7)). Run [39166450392](https://github.com/ouroboric-dev/helheim-go/actions/runs/39166450392) on `60731f6`: success ([E1](#e1-github-settings-and-runs)). | — |
| RR-04 | partial | `ci.yml` has the one job `test`: gofmt, vet, `go test -race -v ./...` (pack, template, checks and Containerfile tests) and govulncheck. Run [39166450363](https://github.com/ouroboric-dev/helheim-go/actions/runs/39166450363) on `60731f6`: success. But its log shows 24 passes and 5 skips: the five tests that need sqlc or golangci-lint skip in the plain Go image ([E3](#e3-go-tests)). They pass on this machine with the stack's pins. | [B-057](../backlog.md) |
| RR-05 | met | `PASS helheim-go agents` ([E2](#e2-local-repo-checks)): 13 lines, links the `yggdrasil` invariants, defines none. | — |
| RR-06 | met | `PASS helheim-go gitleaks` ([E2](#e2-local-repo-checks)). | — |
| RR-07 | met | The docs check in the leaf: `docs: ok` ([E4](#e4-docs-check)). `README.md`, `AGENTS.md` and `docs/architecture.md` exist, as the leaf template asks. `docs.sh` reads only `docs/`; the `markdownlint-cli2` hook of `lint.yml` checks the other two, and passes on `main` (RR-03). | — |
| RR-08 | met | `go test -run Pack ./...`: `--- PASS: TestThePackLoadsAndOffersTheRecipeEveryBuildRealmOffers`, `ok` ([E3](#e3-go-tests)). The pack loads with Gungnir `cb1dc0e`, the version `go.mod` requires (the umbrella's pointer too). | — |
| RR-09 | met | `PASS helheim-go shared` ([E2](#e2-local-repo-checks)). helheim-go's `docs.sh` is the source ([B-043](../backlog.md)). | — |
| RR-10 | met | The umbrella's `.gitmodules` (lines 19 to 21) and `go.work` (line 7) hold `helheim-go`. `check-repos.sh` lists it in `LEAVES` (line 12) and `REALMS` (line 14). | — |
| RR-11 | missing | Name: `helheim-go`, `<realm>-<flavor>` (Helheim, backend; flavor Go). Screening: the [realm-leaf-naming proposal](../changes/2026-10-17-realm-leaf-naming/proposal.md) records a web screening on 2026-10-17 that "found no collision that matters", and that every new leaf name is free in the `ouroboric-dev` org. Awaiting the founder's judgement in this PR. | — |
| RR-12 | met | `pack.yaml` names `leaf.template: templates/api`, `leaf.implementer: prompts/implementer.md` and `leaf.checks`. `TestThePackLoadsAndOffersTheRecipeEveryBuildRealmOffers` checks all three ([E3](#e3-go-tests)). | — |
| RR-13 | met | Every base and service is pinned by digest ([E5](#e5-image-digests-and-their-age)). Postgres was made on 2026-08-05 and SeaweedFS on 2026-09-01. The Go image was made on 2026-10-08 and pinned at 9 days old, under the founder's recorded waiver: Go 1.26.9 fixes standard-library vulnerabilities ([Phase 5b plan](../plans/2026-10-17-yggdrasil-v0-phase-5b/tasks.md), decision 12). It is two weeks old from 2026-10-22. No script checks an image's age yet. | [B-059](../backlog.md) (the check) |
| RR-14 | met | The stack installs no system packages. Five release binaries are each checked against a SHA-256, and govulncheck v1.8.0 comes through the module proxy and its checksum database. The template's modules are in `go.sum`. ([B-044](../backlog.md) is midgard-react's.) | — |
| RR-15 | partial | The auto part is met: `COPY checks/ /opt/ygg/checks/` then `chmod -R a+rX,go-w` (Containerfile lines 37 and 38; root owns it); `go-static.sh` copies `config/golangci.yml` and runs `golangci-lint run --config "$conf"` (lines 46 to 57); sqlc's output is decided from the base commit (`sqlc-owned.sh`). The human part is open: the product's CI runs the leaf's own `.golangci.yml`, which the ladder ignores but does not refuse. It needs one founder decision for both build realms. | [B-055](../backlog.md) |
| RR-16 | met | `pack.yaml` names `static`, `unit`, `tdd`, `contract`, `security` and `integration` (rungs 1 to 5), each one script in `/opt/ygg/checks`. `TestEveryCheckRunsAScriptThatTheStackImageBakesIn` passes, here and in CI ([E3](#e3-go-tests)). `devcontainer/checks/` holds each script. | — |
| RR-17 | met | `YGG_REQUIRE_TEMPLATES=1 go test -run Template ./...` passes its five tests on this machine, with `TestTheUnchangedTemplatePassesStaticAndTDDAndItsSqlcOutputIsOwned` ([E3](#e3-go-tests)). CI skips that one (RR-04). | — |
| RR-18 | partial | `templates/api/.github/workflows/ci.yml` has the one job `test`; `LICENSE` is MIT. The template's CI steps pass on a product's first commit, run on this machine in the pinned images ([E6](#e6-a-products-first-commit)); no product on GitHub has run it yet. Gaps: no "Built with Ouroboric" notice ([B-056](../backlog.md)); the product CI reads the leaf's own lint config ([B-055](../backlog.md)); no SeaweedFS in the product CI, and `TestTemplateCI` does not check the steps ([B-058](../backlog.md)). | [B-055](../backlog.md), [B-056](../backlog.md), [B-058](../backlog.md) |
| RR-19 | missing | Egress (`pack.yaml`): `proxy.golang.org`, `sum.golang.org`, `vuln.go.dev`, `api.osv.dev`. The pack states no reasons. What the check scripts use each host for: `proxy.golang.org`, `go mod download` in every Go rung; `sum.golang.org`, the checksum database that `go mod download` and `go mod verify` consult; `vuln.go.dev`, govulncheck's database (`go-security.sh`); `api.osv.dev`, `osv-scanner` (`go-security.sh`). Awaiting the founder's judgement in this PR. | — |
| RR-20 | missing | Prompt: [`prompts/implementer.md`](https://github.com/ouroboric-dev/helheim-go/blob/60731f6/prompts/implementer.md). No record of a person's review. The Phase 5b final review (an agent) read it in the diff, and `TestTheImplementerPromptTellsWhatTheFactoryChecksAndWhatNotToDo` checks that it names the ladder's commands. Awaiting the founder's judgement in this PR. | — |
| RR-21 | partial | `ygg-smoke-realms.sh` includes the realm in its content mode (`--realm midgard-react --brief … --tag h15`): the run takes helheim-go for the API leaf. It does not pass at this commit. Task 1 passed all six rungs in its loop and at landing, and then its pointer move failed the acceptance check: `accept: the web leaf has no repos/web/contracts/api.openapi.yaml` (exit 5, both tasks given up). The cause is in Odin, not in the realm ([E7](#e7-the-smoke-run)). | [B-061](../backlog.md) |
| RR-22 | n/a | A build realm: the item is for document realms. | — |

## Evidence

### E1: GitHub settings and runs

The controller's evidence file (2026-10-18T21:44:40Z), lines 2 to 12, 17 to 20:

```text
$ scripts/as-bot.sh --read all scripts/check-repos.sh --check settings --check security --check ruleset midgard-react helheim-go asgard
PASS helheim-go settings
PASS helheim-go security
PASS helheim-go ruleset
exit=0
$ gh run list -R ouroboric-dev/helheim-go --branch main --workflow lint.yml --limit 1
success push 60731f6 https://github.com/ouroboric-dev/helheim-go/actions/runs/39166450392
$ gh run list -R ouroboric-dev/helheim-go --branch main --workflow ci.yml --limit 1
success push 60731f6 https://github.com/ouroboric-dev/helheim-go/actions/runs/39166450363
```

### E2: local repo checks

`CHECK_REPOS_ROOT` was a new folder with links to the three clones, in the layout `check-repos.sh` reads.

```text
$ CHECK_REPOS_ROOT=<folder> ouroboric/scripts/check-repos.sh --check reuse --check agents --check gitleaks --check shared midgard-react helheim-go asgard
PASS helheim-go reuse
PASS helheim-go agents
PASS helheim-go gitleaks
PASS helheim-go shared
exit=0
```

### E3: Go tests

On this machine, in the realm, with the realm CI's settings (`GOWORK=off GOTOOLCHAIN=local GOFLAGS=-mod=readonly
YGG_REQUIRE_TEMPLATES=1`), Go 1.26.4, and sqlc 1.31.1 and golangci-lint 2.14.0 on `PATH` (the stack's pins):

```text
$ go test -count=1 -run Pack -v ./...
--- PASS: TestThePackLoadsAndOffersTheRecipeEveryBuildRealmOffers (0.00s)
ok  	github.com/ouroboric-dev/helheim-go	0.010s

$ go test -count=1 -run Template -v ./...
--- PASS: TestTheUnchangedTemplatePassesStaticAndTDDAndItsSqlcOutputIsOwned (1.75s)
--- PASS: TestTheTemplatesLintConfigIsTheBakedOne (0.00s)
--- PASS: TestTemplateCI (0.00s)
--- PASS: TestTheAPITemplateBuildsAndPassesItsOwnChecks (2.21s)
--- PASS: TestATemplateCarriesWhatARepoOfTheFactoryNeeds (0.01s)
ok  	github.com/ouroboric-dev/helheim-go	3.969s

$ go test -race -count=1 -v ./...
29 top-level tests: 29 PASS, 0 SKIP
ok  	github.com/ouroboric-dev/helheim-go	33.883s
```

The CI run on `main`, read with `gh run view 39166450363 -R ouroboric-dev/helheim-go --log`:

```text
--- SKIP: TestTheUnchangedTemplatePassesStaticAndTDDAndItsSqlcOutputIsOwned
--- SKIP: TestTDDExemptsOnlyWhatSqlcGeneratesAndCountsItsSQLAsCode
--- SKIP: TestStaticLintsWithTheBakedConfigAndSkipsOnlyVerifiedSqlcOutput
--- SKIP: TestStaticLintsWhatTheLeafTriedToHide
--- SKIP: TestSqlcOwnedListsOnlyFilesThatAreByteForByteWhatSqlcGenerates
(24 more lines of --- PASS)
ok  	github.com/ouroboric-dev/helheim-go	45.207s
```

### E4: docs check

```text
$ YGG_CHECKS_PATH="$PATH" bash devcontainer/checks/docs.sh    # in the leaf
docs: ok
```

### E5: image digests and their age

The digests are in `devcontainer/Containerfile` (the `stack` stage) and `pack.yaml` (`services`). Each creation
time is the image config's `created`, read from Docker Hub's registry API (the `linux/amd64` image of an index):

```text
library/golang     sha256:d9c68c2c5116  created=2026-10-08T17:13:07Z   pinned 2026-10-17 (helheim-go #2)
library/postgres   sha256:9b18b7839705  created=2026-08-05T00:36:52Z   pinned 2026-10-17
chrislusf/seaweedfs sha256:fc9f76fa993a created=2026-09-01T00:43:01Z   pinned 2026-10-17
```

### E6: a product's first commit

The template was copied into a new repository with one commit. Each step of its `ci.yml` then ran in the job's
image (`golang:1.26.9-bookworm@sha256:d9c68c2c…`), with Postgres from the pinned digest on a private network under
the host name `postgres`, as the workflow's service is:

```text
$ podman run --network <private network> -v <product>:/w golang:1.26.9-bookworm@sha256:d9c68c2c… sh ci-api.sh
STEP-OK gofmt
STEP-OK vet                      (go vet ./... && go vet -tags integration ./...)
gcl.tgz: OK                      (golangci-lint 2.14.0, the workflow's SHA-256)
0 issues.
STEP-OK golangci-lint
ok  	api/internal/store	1.011s
STEP-OK test
ok  	api/internal/store	1.070s   (YGG_DATABASE_URL set, so the store test does not skip)
STEP-OK integration
No vulnerabilities found.
STEP-OK govulncheck
exit=0
```

### E7: the smoke run

`ygg-smoke-realms.sh` needs the engine through `ygg-engine.sh`, the devcontainer CLI 0.89.0 and the bind mount.
All three were there. The content mode uses scripted agents, so it needs no credentials (`--env` was an empty
file). It ran in a new folder under the bind mount, with `realms.dir` on clones of the realms at `main`, and `ygg`
built from odin `6829cfb` and gleipnir `f362ea2` (the umbrella's pointers). The images were built first
(`ygg sandbox build --all`, 43 s). The run took 5 min 17 s.

```text
$ YGG_CMD=<ygg> ygg-smoke-realms.sh --folder <folder> --env <empty file> --realm midgard-react \
    --brief odin/testdata/smoke-content/brief.md --tag h15
leaf:     repos/api on ygg/20261018-215815-b4fb50 at cbbd07845993 (helheim-go 0.1.0)
leaf:     repos/web on ygg/20261018-215815-b4fb50 at 9fc1d5eca023 (midgard-react 0.1.0)
version-t1-implement  static, unit, tdd, contract, security, integration: exit 0; three reviewers; passed
version-t1-land       static, unit, tdd, contract, security, integration: exit 0; merged into main
version-t1-move       the six rungs: exit 0; accept: exit status 1
accept: the web leaf has no repos/web/contracts/api.openapi.yaml
Run 20261018-215815-b4fb50 is done, with 2 task(s) given up.
smoke-realms: the run ended with exit code 5
```

The snapshot's `repos/web` held only `LICENSE`. The project's umbrella recorded `repos/web` at `454b811`, the
leaf's first commit, while the leaf's `main` held the template (`9fc1d5e`). [B-061](../backlog.md) has the cause.
