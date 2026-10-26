---
title: Brand tools plan
status: proposed
date: 2026-10-27
related: [tasks.md, ../../specs/2026-10-26-brand-tools.md, ../../../1-product/design/2026-10-17-asgard-v0-design.md]
style: spec
---

# Brand tools plan

**Goal:** the tools of step 6 of the company kickstart: the contrast and font licence checks in every company's
checks, and Asgard's `brand.sh` for logo processing and the brand board, all generic and tested first.

**Spec:** [2026-10-26-brand-tools.md](../../specs/2026-10-26-brand-tools.md). **Design:**
[Asgard v0 design](../../../1-product/design/2026-10-17-asgard-v0-design.md) (§6, §8).

## Order

```text
BT-T01 spike: resvg, VTracer and the wheels on the founder's machine and in CI   (no dependency)
BT-T02 the contrast check (brand.py contrast), the run.sh step                     (no dependency)
BT-T02 ─► BT-T03 the font licence check (brand.py fonts), tokens.json's font evidence
BT-T03 ─► BT-T04 the generated files (brand.py tokens), mkdocs extra_css
BT-T01 ─► BT-T05 brand.sh setup: hashed requirements, resvg.lock, the cache, ci.yml
BT-T05 ─► BT-T06 brand.sh logo: inputs, trace, faithfulness, gaps, trace.json
BT-T06 ─► BT-T07 brand.sh logo: recolour, derive, brand tokens, the mark, exports
BT-T04, BT-T07 ─► BT-T08 brand.sh board: board.md, board/ images, sample images, freshness
BT-T08 ─► BT-T09 docs: Asgard's map, the template's logo and imagery pages
```

BT-T02 to BT-T04 go in one Asgard pull request (the company checks), BT-T05 to BT-T07 in a second (logo
processing), BT-T08 and BT-T09 in a third (the board). Each pull request carries its tests.

## Global constraints

- Every task starts from Asgard's `origin/main`, on a branch, test first, and ends with a pull request opened by
  `ouroboric/scripts/pr-open.sh`. The founder's account pushes branches that change `.github/workflows/`.
- The tools are generic: no test, fixture, comment or commit names a real company. Tests scaffold "Example Studio".
- A fresh scaffold passes `run.sh` after every task, and `names-check.sh` passes on every company the tests build.
- Nothing the tools write into a company names a part of the factory, except in a setting for that part (spec
  §5.5).
- No binary file is committed in Asgard: tests draw their PNGs and build their fonts at run time.
- Every pinned version is a release at least two weeks old.

## Risks

| Risk | What happens | Answer |
| --- | --- | --- |
| VTracer has no wheel for the founder's Python (3.14) | `setup` fails locally | BT-T01 checks; `setup` uses the newest Python that has every wheel (3.11 is installed) |
| resvg cannot render a type specimen from a font file | §5.4's type part has no image | BT-T01 checks `--use-font-file`; if not, the specimen is rendered by Pillow from the TTF, and the spec is amended |
| GitHub's file view does not show the board's images in a private repository | The founder can't review the board in GitHub | BT-T01 checks it on a private scratch repository, with the founder |
| The faithfulness limits are too strict or too loose | False gaps, or missed ones | BT-T01 measures them on the fixtures; a real logo tunes them later, by a change proposal |

## Review focus

1. Each check's failure names the file, the token or font, and what to do, in words a person relays.
2. Re-runs give byte-identical files, and the board's freshness check fails when any input changes.
