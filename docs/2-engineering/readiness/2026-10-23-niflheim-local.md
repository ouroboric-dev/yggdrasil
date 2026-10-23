---
title: Realm readiness — niflheim-local, 2026-10-23
status: draft
date: 2026-10-23
style: procedure
related: [../realm-readiness.md, ../backlog.md, ../changes/2026-10-22-gallery-runtime/proposal.md, 2026-10-18-helheim-go.md]
---

# Realm readiness: niflheim-local, 2026-10-23

**Bottom line: nearly ready.** Of 15 items that apply to a runtime realm, 12 are met, 1 is partial, 1 is `missing` (a
human item) and 1 is `n/a`. The partial item is RR-01: the ruleset of `niflheim-local` does not require `test` yet, and
only a founder run of `setup-repo.sh` fixes that.

- **Realm:** [`niflheim-local`](https://github.com/ouroboric-dev/niflheim-local) at
  [`8f21bf0`](https://github.com/ouroboric-dev/niflheim-local/commit/8f21bf011db8c79afeeb7c868f94f3c28808acb9), a
  runtime realm (kind `runtime`). The change's final pull request moves the umbrella's pointer to that commit.
- **Checklist:** the [realm readiness checklist](../realm-readiness.md), the items whose "applies to" is `all` or
  `runtime`, with RR-13 and RR-21 added because the realm pins services and has no leaf. The other build and document
  items are not rows here.
- **How it was run:** an agent ran the GitHub items under `as-bot.sh --read all` (a read-only token) on
  2026-10-23T20:23:44Z, and the local checks on the clone at `8f21bf0`. The [evidence](#evidence) section holds each
  command and its decisive lines.

## Summary

| Status | Count | Items |
| --- | --- | --- |
| met | 12 | RR-02 to RR-10, RR-13, RR-25, RR-26 |
| partial | 1 | RR-01 |
| missing | 1 | RR-11 (human) |
| n/a | 1 | RR-21 |

## Items

| ID | Status | Evidence | Backlog |
| --- | --- | --- | --- |
| RR-01 | partial | `PASS niflheim-local settings` and `security`; `FAIL niflheim-local ruleset`: the ruleset requires `lint` only, and `ci.yml` has a job `test` ([E1](#e1-github-settings-and-runs)). The fix is `setup-repo.sh` (a write action), which a founder runs. | — |
| RR-02 | met | `PASS niflheim-local reuse` ([E2](#e2-local-repo-checks)). | — |
| RR-03 | met | `.github/workflows/lint.yml` exists. Run [39936702141](https://github.com/ouroboric-dev/niflheim-local/actions/runs/39936702141) on `8f21bf0`: success ([E1](#e1-github-settings-and-runs)). | — |
| RR-04 | met | `ci.yml` has the one job `test`: gofmt, vet, `go test` (the pack and the product start) and govulncheck. Run [39936702550](https://github.com/ouroboric-dev/niflheim-local/actions/runs/39936702550) on `8f21bf0`: success ([E1](#e1-github-settings-and-runs)). | — |
| RR-05 | met | `PASS niflheim-local agents` ([E2](#e2-local-repo-checks)). | — |
| RR-06 | met | `PASS niflheim-local gitleaks` ([E2](#e2-local-repo-checks)). | — |
| RR-07 | met | `README.md`, `AGENTS.md` (15 lines) and `docs/architecture.md` exist, and `lint.yml` passes on `main` (RR-03). | — |
| RR-08 | met | `go test -run Pack ./...`: four `PASS` lines ([E3](#e3-go-tests)). The pack loads against the Gungnir version `go.mod` requires. | — |
| RR-09 | met | `PASS niflheim-local shared: not a realm` ([E2](#e2-local-repo-checks)). A runtime realm holds no shared check script, so the check has nothing to compare. | — |
| RR-10 | met | The umbrella's `.gitmodules` (lines 25 to 27) and `go.work` (line 10) hold `niflheim-local` ([yggdrasil#102](https://github.com/ouroboric-dev/yggdrasil/pull/102), T34). `check-repos.sh` lists it in `LEAVES` (line 14; [ouroboric#79](https://github.com/ouroboric-dev/ouroboric/pull/79), T27). | — |
| RR-11 | missing | Human item. The name follows `<realm>-<flavor>` (Niflheim, runtime; flavor local). No person has judged the name and its screening yet. The founder's answers to the change's questions (2026-10-23) chose the realm and its name. | — |
| RR-13 | met | The pack pins both services by digest: Postgres `18.4-bookworm@sha256:882236b8…` and SeaweedFS `4.45@sha256:fc9f76fa…`. `check-repos.sh --check services` passes ([E4](#e4-services-check)). The age of each digest is checked in T11's evidence; no script checks it yet. | — |
| RR-21 | n/a | The realm has no leaf, so no smoke run builds one. `ygg-smoke-runtime.sh` is RR-25's run. | — |
| RR-25 | met | `go test -run ProductStart ./...` passes ([E3](#e3-go-tests)). `ygg-smoke-runtime.sh --image cgl:4.1.0` (the founder, real engine, merged realms, T30): every check `PASS`, first answer in 7 s, restart in 35 s. | — |
| RR-26 | met | `go test -run Pack ./...` passes (the pack provides `postgres` and `s3`). `check-repos.sh --check services`: 3 `PASS` ([E4](#e4-services-check)). [mimir#8](https://github.com/ouroboric-dev/mimir/pull/8) writes the Postgres pins out literally. | — |

## Evidence

### E1: GitHub settings and runs

Under `as-bot.sh --read all`, 2026-10-23T20:23:44Z:

```text
$ scripts/as-bot.sh --read all scripts/check-repos.sh --check settings --check security --check ruleset niflheim-local
PASS niflheim-local settings
PASS niflheim-local security
FAIL niflheim-local ruleset: rules: deletion,non_fast_forward,pull_request:squash:1:stale-dismissed:last-push-approved,required_status_checks:lint@15368:strict (run setup-repo.sh)
$ gh run list -R ouroboric-dev/niflheim-local --branch main
success ci   8f21bf0 https://github.com/ouroboric-dev/niflheim-local/actions/runs/39936702550
success lint 8f21bf0 https://github.com/ouroboric-dev/niflheim-local/actions/runs/39936702141
```

### E2: local repo checks

```text
$ scripts/as-bot.sh --read all scripts/check-repos.sh --check reuse --check agents --check gitleaks --check shared niflheim-local
PASS niflheim-local reuse
PASS niflheim-local agents
PASS niflheim-local gitleaks
PASS niflheim-local shared: not a realm
```

### E3: Go tests

In the realm at `8f21bf0`, `GOWORK=off go test -count=1 -run 'Pack|ProductStart' -v ./...`:

```text
--- PASS: TestThePackProvidesTheNeeds (0.00s)
--- PASS: TestPackPostgresIsEighteen (0.00s)
--- PASS: TestPackSeaweedFSIsTheGraderImages (0.00s)
--- PASS: TestPackNamesTheProductStart (0.00s)
--- PASS: TestProductStart (41.50s)
ok  	github.com/ouroboric-dev/niflheim-local	41.519s
```

### E4: services check

```text
$ scripts/as-bot.sh --read all scripts/check-repos.sh --check services
PASS niflheim-local services: weed digest sha256:fc9f76fa993ad69966ffeb2f65d0318fcae39c6f8e20cf68ef7b3a5cb97769e5
PASS niflheim-local services: template CI postgres image equals the pack's
PASS niflheim-local services: postgres minor 18.4 (image) and 18.4 (package)
```
