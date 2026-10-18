---
title: The realm readiness checklist and the first assessments
status: draft
date: 2026-10-18
related: [../../../1-product/design/2026-10-18-ginnungagap-design.md, delta.md, tasks.md, ../2026-10-18-repo-bootstrap/proposal.md, ../../backlog.md]
style: spec
---

# The realm readiness checklist and the first assessments

**Proposed 2026-10-18:** step 1 of the
[Ginnungagap and Voluspa design doc](../../../1-product/design/2026-10-18-ginnungagap-design.md) (§8.1).
The tree gets a realm readiness checklist. The three realms (`midgard-react`, `helheim-go`, `asgard`)
are assessed against it by hand, and the gaps that block a real-agent run are fixed before the Phase
5c plan. This change comes before 5c, because 5c changes both web realms a lot (rung 7, the dependency
policy) and neither realm has CI today.

## Why

- `midgard-react` and `helheim-go` have no `.github/workflows/`. Their own tests run only by hand.
- Their templates give a product no CI, so nothing guards a product after the factory leaves it.
- `docs.sh` differs between the two realms (B-043): only `helheim-go`'s copy fixes its `PATH`.
- Nobody wrote down what a finished realm is, so these gaps were found by chance.

## What changes

- **The checklist** `docs/2-engineering/realm-readiness.md`, refined from design §6. One change from
  the design: RR-18 asks only for the language CI (`ci.yml`). A product's `lint.yml` and pre-commit
  config come from repo creation (layer 1), as change `repo-bootstrap` says for `init`.
- **Each realm repo's own CI:** `.github/workflows/ci.yml` with one job, `test`, which runs the
  realm's tests and never skips the template tests.
- **Each build template's CI:** `templates/<leaf>/.github/workflows/ci.yml` with one job, `test`. It
  runs the stack's own commands on the stack's pinned images. The ladder refuses a task's change
  under `.github/`.
- **One `docs.sh`:** the two copies become the same file, and `check-repos.sh --check shared` fails
  when they differ. `helheim-go`'s copy is the source until Ginnungagap's base stage exists.
- **Three assessments** in `docs/2-engineering/readiness/`. Every item that is not `met` is fixed
  or becomes a backlog entry that names its item ID.
- **Docs:** the docs standard's repo section, `ouroboric/AGENTS.md`, each realm's README and
  architecture page, the operations index, the backlog and a journal entry.

## Not in this change

- The base CI (`lint.yml`) on the realm repos. It comes from change `repo-bootstrap`'s rollout. Until
  then, RR-03 is `missing` with that reason.
- Playwright in the product's CI. It needs a browser and the Prism mock. The ladder's e2e rung keeps
  it.
- Readiness as factory code (step 3) and Ginnungagap (step 4).

## Impact

- **Repos:** `yggdrasil` (checklist, assessments, backlog, pointers), `midgard-react` and `helheim-go`
  (CI, template CI, the protected paths, `docs.sh`), `ouroboric` (`check-repos.sh`, docs).
- **Approval points:** none added. The ladder protects one more path.
- **Founder:** pushes the two root `ci.yml` files (the pr-bot has no Workflows permission), runs
  `setup-repo.sh` so that `test` is required, and runs the checklist items that read GitHub.
- **v0 plan:** none of these tasks belongs to a phase. They land before the 5c plan session.
