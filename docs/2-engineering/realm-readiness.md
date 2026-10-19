---
title: Realm readiness checklist
status: draft
date: 2026-10-18
style: procedure
related: [../1-product/design/2026-10-18-ginnungagap-design.md]
---

# Realm readiness checklist

This is the checklist for a realm: a leaf repo with its own `pack.yaml`. It follows the shape of
Asgard's readiness checklist. Ginnungagap's design (§6) is its source. Ginnungagap passes this checklist
too, because it is a realm.

1. Copy this checklist into `docs/2-engineering/readiness/YYYY-MM-DD-<realm>.md`.
2. Fill one row for each item that applies to the realm.
3. Give evidence for each item, or mark it `missing`. Evidence is a link, a command and its output, or
   a person's judgement.

Check type **auto** means that a command can verify the item. The "How to check" column names it.
Check type **human** means that a person must judge the item.

Use these status values: `met`, `partial`, `missing`, `n/a` (give a reason).

The "applies to" column says which realms an item covers:

- `all`: every realm.
- `build`: a realm that builds software. It has a stack, a template and a ladder.
- `document`: a realm that makes documents. Its pack declares no stack.

## The checklist

| ID | Applies to | Area | Question | Check | How to check |
| --- | --- | --- | --- | --- | --- |
| RR-01 | all | repo | Does the repo pass `check-repos.sh` (settings, security, ruleset), with `lint` required, and `test` where `ci.yml` exists? | auto | `check-repos.sh --check settings --check security --check ruleset <repo>`. The founder, or an agent under `scripts/as-bot.sh --read all` (a read-only token), runs it. |
| RR-02 | all | licence | Does `reuse lint` pass, with MIT on everything copied into products? | auto | `check-repos.sh --check reuse <repo>` |
| RR-03 | all | CI | Does `lint.yml` exist, and does it pass on `main`? | auto | The file `.github/workflows/lint.yml` exists (it comes from the repo-bootstrap scripts). The founder, or an agent under `scripts/as-bot.sh --read all` (a read-only token), checks on GitHub that it passes on `main`. |
| RR-04 | all | CI | Does `ci.yml` run the realm's own tests (pack, template, checks, Containerfile) in a job named `test`, and does it pass on `main`? | auto | The file `.github/workflows/ci.yml` has a job `test`. The founder, or an agent under `scripts/as-bot.sh --read all` (a read-only token), checks on GitHub that it passes on `main`. |
| RR-05 | all | agents | Does `AGENTS.md` carry the umbrella's invariants? | auto | `check-repos.sh --check agents <repo>` |
| RR-06 | all | secrets | Is gitleaks in the pre-commit config? | auto | `check-repos.sh --check gitleaks <repo>` |
| RR-07 | all | docs | Do `README.md`, `AGENTS.md` and `docs/architecture.md` follow the docs standard? | auto | The docs check, run in the leaf. |
| RR-08 | all | contract | Does `pack.yaml` load and validate against Gungnir at the version it declares? | auto | `go test -run Pack ./...` in the leaf |
| RR-09 | all | shared | Does every shared piece match its source? The shared files today: `devcontainer/checks/docs.sh`, and in the build realms `devcontainer/checks/protected-common`, the list of protected files. | auto | `check-repos.sh --check shared <repo>`. The check exists (ouroboric #48); it compares `protected-common` too (ouroboric #60). |
| RR-10 | all | tree | Is the realm a submodule of the `yggdrasil` umbrella, in `go.work` if it is Go, and in `check-repos.sh`'s lists? | auto | Read `.gitmodules` and `go.work` in the umbrella, and the lists at the top of `check-repos.sh`. This is a wiring item. |
| RR-11 | all | name | Does the name follow `<realm>-<flavor>`, and was it screened? | human | A person judges the name and the screening. |
| RR-12 | build | contract | Does the pack name the standard roles: the implementer prompt, the leaf template and the leaf checks, and does it hold no graph? | auto | `go test -run 'Pack\|HoldsNoGraph' ./...` in the leaf |
| RR-13 | build | stack | Is every base image and service pinned by digest, and at least two weeks old? | auto | Read the `Containerfile` and the pack's services for digests. Check each digest's age in its registry. |
| RR-14 | build | stack | Are the packages in the stack pinned (B-044)? | auto | Read the `Containerfile` and the lock files for exact versions. |
| RR-15 | build | guard | Are the check scripts and their lint and build configs baked into `/opt/ygg/checks`, owned by root, and passed explicitly (B-049)? Does every rung refuse a task's change to the protected files (base-CI, licensing, tool configs, `.github/`, `.devcontainer/`)? | auto + human | Read the `Containerfile` for the copy, the owner and the path, and the pack for the explicit path. Read the protected-paths block of `go-static.sh` or `web-protected.sh` for the list, `protected-common`, and run the refusal test (helheim-go #9 and #10, midgard-react #15 and #16). A person judges the guard. |
| RR-16 | build | ladder | Does the pack name rungs 1 to 5, and does each script exist in the stack? | auto | `go test -run Pack ./...` in the leaf, and read `devcontainer/checks/` for each script. |
| RR-17 | build | template | Does the template pass its own ladder on its first commit, when it is built in a copy? | auto | `YGG_REQUIRE_TEMPLATES=1 go test -run Template ./...` in the leaf |
| RR-18 | build | product | Does the template give the product `.github/workflows/ci.yml` with a job `test`, and the MIT licence with the "Built with Ouroboric" notice? Does that CI pass on the product's first commit? | auto | Read the template for `ci.yml` (job `test`) and for `LICENSE` and the notice. Build a product from the template and check its CI run. The product's `lint.yml` and pre-commit config (with gitleaks) do not come from the template. They come from repo creation (`new-repo.sh`, `add-ci.sh`). |
| RR-19 | build | egress | Is the egress list the smallest that works, with a reason for each host? | human | A person reads the egress list and the reason for each host. |
| RR-20 | build | prompt | Has a person reviewed the implementer prompt? | human | A person reviews the prompt and records it. |
| RR-21 | build | smoke | Does `ygg-smoke-realms.sh` include the realm, and does it pass? | auto | `ygg-smoke-realms.sh`. This is a wiring item. |
| RR-22 | document | contract | Does the pack declare no stack, and are its checks document checks? | auto | `go test -run Pack ./...` in the leaf |

## Items that read GitHub

RR-01, and the "passes on `main`" parts of RR-03 and RR-04, read repo settings and workflow runs
through the GitHub API. A factory sandbox has no GitHub token. The founder, or an agent under
`scripts/as-bot.sh --read all` (a read-only token), runs these items and gives the output as evidence. A later
step decides how the runner gets them.

## Wiring items

RR-10 and RR-21 change files outside the leaf: the umbrella's `.gitmodules` and `go.work`, and
`check-repos.sh` and `ygg-smoke-realms.sh` in `ouroboric`. An agent in a run never touches those
(invariant 10). After a realm-making run, they come in a follow-up pull request from an agent building
the factory, which the founder merges. A realm-making run succeeds when every other auto item is `met`
and a person has judged the human items.
