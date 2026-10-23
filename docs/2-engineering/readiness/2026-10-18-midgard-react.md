---
title: Realm readiness — midgard-react, 2026-10-18
status: draft
date: 2026-10-18
style: procedure
related: [../realm-readiness.md, ../backlog.md, 2026-10-18-helheim-go.md, 2026-10-18-asgard.md]
---

# Realm readiness: midgard-react, 2026-10-18

**Bottom line: not ready yet.** Of 22 items, 15 are met, 6 are partial, 0 are missing and 1 is `n/a`. The
partial items are in the backlog: B-044, B-055, B-056, B-059, B-061 and B-062. The founder judged the three
human items on 2026-10-19.

- **Realm:** [`midgard-react`](https://github.com/ouroboric-dev/midgard-react) at
  [`26ca85e`](https://github.com/ouroboric-dev/midgard-react/commit/26ca85e3dfab42e65f5162f093d3719ddf2da1a7), a build
  realm and the client gallery's lead realm. This pull request moves the umbrella's pointer to that commit.
- **Checklist:** [realm readiness checklist](../realm-readiness.md), all 22 items.
- **How it was run:** as for [helheim-go](2026-10-18-helheim-go.md): the local checks of `check-repos.sh` on a clone,
  an agent's run of the GitHub items (2026-10-18T21:44:40Z, under `as-bot.sh --read all`), the Go
  tests on this machine with the realm CI's settings, and the CI log of `main` read with a read-only `gh run view`.
  The [evidence](#evidence) section holds each command and its decisive lines.

## Summary

| Status | Count | Items |
| --- | --- | --- |
| met | 15 | RR-01 to RR-12, RR-16, RR-17, RR-20 |
| partial | 6 | RR-13, RR-14, RR-15, RR-18, RR-19, RR-21 |
| missing | 0 | — |
| n/a | 1 | RR-22 |

## Items

| ID | Status | Evidence | Backlog |
| --- | --- | --- | --- |
| RR-01 | met | `PASS midgard-react settings`, `security` and `ruleset` ([E1](#e1-github-settings-and-runs)). The ruleset check wants `lint` and `test` required, because both workflows exist. | — |
| RR-02 | met | `PASS midgard-react reuse` ([E2](#e2-local-repo-checks)). `REUSE.toml` gives `templates/**` MIT, and no template file has its own licence header. | — |
| RR-03 | met | `.github/workflows/lint.yml` came with the base CI ([midgard-react #12](https://github.com/ouroboric-dev/midgard-react/pull/12)). Run [39169108086](https://github.com/ouroboric-dev/midgard-react/actions/runs/39169108086) on `26ca85e`: completed, success ([E1](#e1-github-settings-and-runs)). | — |
| RR-04 | met | `ci.yml` has the one job `test`: gofmt, vet, `go test -race -v ./...` (pack, graph, prompts, template, checks, contract, end-to-end and Containerfile tests) and govulncheck. Run [39169108095](https://github.com/ouroboric-dev/midgard-react/actions/runs/39169108095) on `26ca85e`: completed, success. Its log has 49 `--- PASS` lines and no `--- SKIP` ([E3](#e3-go-tests)). | — |
| RR-05 | met | `PASS midgard-react agents` ([E2](#e2-local-repo-checks)): 14 lines, links the `yggdrasil` invariants, defines none. | — |
| RR-06 | met | `PASS midgard-react gitleaks` ([E2](#e2-local-repo-checks)). | — |
| RR-07 | met | The docs check in the leaf: `docs: ok` ([E4](#e4-docs-check)). `README.md`, `AGENTS.md` and `docs/architecture.md` exist, as the leaf template asks. `docs.sh` reads only `docs/`; the `markdownlint-cli2` hook of `lint.yml` checks the other two, and passes on `main` (RR-03). | — |
| RR-08 | met | `go test -run Pack ./...`: `--- PASS: TestThePackLoadsAsTheLeadRealmWithTwoStacksFromOneContext`, `ok` ([E3](#e3-go-tests)). The pack loads with Gungnir `cb1dc0e`, the version `go.mod` requires (the umbrella's pointer too). | — |
| RR-09 | met | `PASS midgard-react shared` ([E2](#e2-local-repo-checks)): `devcontainer/checks/docs.sh` is helheim-go's byte for byte ([B-043](../backlog.md)). | — |
| RR-10 | met | The umbrella's `.gitmodules` (lines 13 to 15) and `go.work` (line 9) hold `midgard-react`. `check-repos.sh` lists it in `LEAVES` (line 12) and `REALMS` (line 14). | — |
| RR-11 | met | Name: `midgard-react`, `<realm>-<flavor>` (Midgard, web frontends; flavor React). Screening: the [realm-leaf-naming proposal](../changes/2026-10-17-realm-leaf-naming/proposal.md) records a web screening on 2026-10-17 that "found no collision that matters". It notes that Midgard is also an open-source content framework, mostly dormant since 2012, and that every new leaf name is free in the `ouroboric-dev` org. The founder judged the name and its screening acceptable (2026-10-19). | — |
| RR-12 | met | `pack.yaml` names `leaf.template: templates/web`, `leaf.implementer: prompts/implementer.md` and `leaf.checks`. Gungnir's `LoadPack` refuses a template that is not a folder or a prompt that is not a file, and the pack test passes ([E3](#e3-go-tests)). | — |
| RR-13 | partial | Every base is pinned by digest; the pack has no services of its own ([E5](#e5-image-digests-and-their-age)). The Node image (`node@sha256:efd0ab57…`, Node 22.23.3) was made on 2026-10-06 and pinned here on 2026-10-17, at 11 days old, with no waiver. The Go image of the acceptance stage was made on 2026-10-08, under the founder's waiver for Go 1.26.9 ([Phase 5b plan](../plans/2026-10-17-yggdrasil-v0-phase-5b/tasks.md), decision 12). Both are two weeks old from 2026-10-22. No script checks an image's age. Note, 2026-10-23: Go 1.26.10 for GO-2026-6809, a founder-approved exception to RR-13's two weeks (helheim-go#14, midgard-react#22). | [B-059](../backlog.md) |
| RR-14 | partial | The release binaries are checked against a SHA-256, and Prism and Playwright are at exact versions. But `apt-get install ca-certificates curl git` and `playwright install --with-deps chromium` take what the mirror serves, the browser has no hash, and the global npm packages' own dependencies have no lock file. The realm's own CI also installs six packages with `apt-get` (step `apt`). | [B-044](../backlog.md) |
| RR-15 | partial | The auto part is met: `COPY checks/ /opt/ygg/checks/` then `chmod -R a+rX,go-w` (Containerfile lines 40 and 41; root owns it); `web-configs.sh` puts the baked configs of `checks/config` into the leaf as `.ygg-*` copies, and each rung names them (`eslint --no-config-lookup -c`, `tsc -p`, `vite build --config`, `vitest run --config`). `TestEveryToolCallOfTheRungsNamesItsConfig` and `TestRealRungsIgnoreAnyConfigTheLeafHas` pass ([E3](#e3-go-tests)). The human part is open: the product's CI runs the leaf's own `eslint.config.js`, `tsconfig.json` and `vite.config.ts`, which the ladder ignores but does not refuse. It needs one founder decision for both build realms. | [B-055](../backlog.md) |
| RR-16 | met | `pack.yaml` names `static`, `unit`, `tdd`, `contract`, `security` and `e2e` (rungs 1 to 5), and `accept` for the pointer move, each one script in `/opt/ygg/checks`. The pack test checks that `devcontainer/checks/` holds each as an executable, and that no other script is baked in unused ([E3](#e3-go-tests)). | — |
| RR-17 | met | `YGG_REQUIRE_TEMPLATES=1 go test -run Template ./...` passes its six tests, among them `TestRealRungsPassOnTheUnchangedTemplate` (the static and unit rungs on the unchanged template) and `TestTheWebTemplateBuildsAndPassesItsOwnChecks` ([E3](#e3-go-tests)). The same tests pass in CI. | — |
| RR-18 | partial | `templates/web/.github/workflows/ci.yml` has the one job `test`, and `TestTemplateCI` checks each of its steps; `LICENSE` is MIT. The template's CI steps pass on a product's first commit, run on this machine in the job's pinned image ([E6](#e6-a-products-first-commit)); no product on GitHub has run it yet. Gaps: no "Built with Ouroboric" notice ([B-056](../backlog.md)); the product CI reads the leaf's own tool configs ([B-055](../backlog.md)). | [B-055](../backlog.md), [B-056](../backlog.md) |
| RR-19 | partial | Egress (`pack.yaml`): `registry.npmjs.org`, `api.osv.dev`. The pack states no reasons. What the check scripts use each host for: `registry.npmjs.org`, the clean `npm ci` that every web rung runs first, and `npm audit` (`web-security.sh`); `api.osv.dev`, `osv-scanner` (`web-security.sh`). The acceptance sandbox (`sandbox.acceptance`) names no hosts of its own. The founder judged the lists minimal (2026-10-19). | [B-062](../backlog.md) |
| RR-20 | met | Prompt: [`prompts/implementer.md`](https://github.com/ouroboric-dev/midgard-react/blob/26ca85e/prompts/implementer.md). Before this PR, no record of a person's review. The Phase 5b final review (an agent) read it in the diff, and `TestThePromptsNameOnlyScriptsAndCommandsThatExist` checks what it names. The founder reviewed `prompts/implementer.md` and accepted it (2026-10-19). | — |
| RR-21 | partial | `ygg-smoke-realms.sh` includes the realm in its content mode (`--realm midgard-react --brief … --tag h15`), as the lead realm. It does not pass at this commit: task 1's pointer move failed this realm's acceptance check, `accept: the web leaf has no repos/web/contracts/api.openapi.yaml` (exit 5). The cause is in Odin, not in the realm: the snapshot took the new web leaf at its first commit. The run and its output are in [helheim-go's E7](2026-10-18-helheim-go.md#e7-the-smoke-run). | [B-061](../backlog.md) |
| RR-22 | n/a | A build realm: the item is for document realms. | — |

## Evidence

### E1: GitHub settings and runs

The agent's run of 2026-10-18T21:44:40Z, under `as-bot.sh --read all`. The decisive output, with the run URLs:

```text
$ scripts/as-bot.sh --read all scripts/check-repos.sh --check settings --check security --check ruleset midgard-react helheim-go asgard
PASS midgard-react settings
PASS midgard-react security
PASS midgard-react ruleset
exit=0
$ gh run list -R ouroboric-dev/midgard-react --branch main --workflow lint.yml --limit 1
 push 26ca85e https://github.com/ouroboric-dev/midgard-react/actions/runs/39169108086
$ gh run list -R ouroboric-dev/midgard-react --branch main --workflow ci.yml --limit 1
 push 26ca85e https://github.com/ouroboric-dev/midgard-react/actions/runs/39169108095
midgard-react main run 39169108086: completed success lint 26ca85e
midgard-react main run 39169108095: completed success ci 26ca85e
```

### E2: local repo checks

```text
$ CHECK_REPOS_ROOT=<folder> ouroboric/scripts/check-repos.sh --check reuse --check agents --check gitleaks --check shared midgard-react helheim-go asgard
PASS midgard-react reuse
PASS midgard-react agents
PASS midgard-react gitleaks
PASS midgard-react shared
exit=0
```

### E3: Go tests

On this machine, in the realm, with the realm CI's settings (`GOWORK=off GOTOOLCHAIN=local GOFLAGS=-mod=readonly
YGG_REQUIRE_TEMPLATES=1`), Go 1.26.4 and Node 26:

```text
$ go test -count=1 -run Pack -v ./...
--- PASS: TestThePackLoadsAsTheLeadRealmWithTwoStacksFromOneContext (0.00s)
--- PASS: TestTheSpecPromptNamesThisRealmAtTheVersionOfThisPack (0.00s)
ok  	github.com/ouroboric-dev/midgard-react	0.011s

$ go test -count=1 -run Template -v ./...
--- PASS: TestTheTemplatesToolConfigsAreTheBakedOnes (0.00s)
--- PASS: TestRealRungsPassOnTheUnchangedTemplate (15.82s)
--- PASS: TestTemplateCI (0.00s)
--- PASS: TestPlaywrightsVersionIsTheTemplatesSoItsBrowsersMatch (0.00s)
--- PASS: TestTheWebTemplateBuildsAndPassesItsOwnChecks (11.31s)
--- PASS: TestTheWebTemplateCarriesWhatARepoOfTheFactoryNeeds (0.01s)
ok  	github.com/ouroboric-dev/midgard-react	27.135s

$ go test -race -count=1 -v ./...
40 top-level tests: 40 PASS, 0 SKIP
ok  	github.com/ouroboric-dev/midgard-react	73.072s
```

The CI run on `main`, read with `gh run view 39169108095 -R ouroboric-dev/midgard-react --log`: 49 `--- PASS`
lines (tests and subtests), no `--- SKIP`, and `ok  	github.com/ouroboric-dev/midgard-react`.

### E4: docs check

```text
$ YGG_CHECKS_PATH="$PATH" bash devcontainer/checks/docs.sh    # in the leaf
docs: ok
```

### E5: image digests and their age

The digests are in `devcontainer/Containerfile` (the `golang` and `web` stages). Each creation time is the image
config's `created`, read from Docker Hub's registry API (the `linux/amd64` image of an index; the Node digest is
one image):

```text
library/golang  sha256:d9c68c2c5116  created=2026-10-08T17:13:07Z   pinned 2026-10-17 (midgard-react #5), waiver
library/node    sha256:efd0ab5780c2  created=2026-10-06T01:45:41Z   pinned 2026-10-17 (midgard-react #5); Phase 3 (2026-10-16) before
```

### E6: a product's first commit

The template was copied into a new repository with one commit. Each step of its `ci.yml` then ran in the job's
image (`node@sha256:efd0ab57…`):

```text
$ podman run -v <product>:/w node@sha256:efd0ab57… sh ci-web.sh
STEP-OK npm ci --ignore-scripts --no-audit --no-fund
STEP-OK npm run lint
STEP-OK npm run typecheck
 Test Files  1 passed (1)
      Tests  3 passed (3)
STEP-OK npm test
✓ built in 235ms
STEP-OK npm run build
exit=0
```
