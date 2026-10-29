---
title: Tasks for per-role weights
status: draft
date: 2026-10-29
related: [proposal.md, delta.md]
style: spec
---

# Tasks: per-role weights (option A)

Each task is one branch and one pull request, with its failing test first. The founder chose A on 2026-10-29; PW-T01 is applied with the proposal.

- [x] **PW-T01 Spec and contract.** Apply `delta.md` to the brand tools spec. Test: the spec lists the keys, the
      properties and the check ids.
- [x] **PW-T02 Check and defaults.** `brand.py type` reads `weight` and `strong`; `tokens --write` writes
      `--weight-<role>` and `--weight-<role>-strong`; a `tokens.json` without the keys gets the defaults of the
      proposal's item 5. Tests: a weight the files lack fails with `type:<role>:weight`; a company with no keys is
      unchanged on the page.
- [x] **PW-T03 Recipes, reference and playground.** The recipes read the properties; the reference and the playground
      show and export them. Tests: a recipe holds no weight number; changing a role's `weight` changes the rendered
      computed `font-weight` in the reference. Depends on PW-T02 and on the recipes' single source (follow-up 1).
- [x] **PW-T04 Type pages.** The depth and roles pages offer the weights the face has. Test: a face with one weight
      offers one and sets both values.

Built in asgard#47 (PW-T02), #48 (PW-T03), #49 (PW-T04) and #50 (the playground opens on the saved weights). One reading
to confirm: headings use the `strong` weight (600 by default), not `weight` (400), so that no existing page changes.
