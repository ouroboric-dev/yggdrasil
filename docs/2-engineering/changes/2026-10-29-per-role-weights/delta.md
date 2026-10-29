---
title: Delta to the brand tools spec for per-role weights
status: draft
date: 2026-10-29
related: [proposal.md, tasks.md, ../../specs/2026-10-26-brand-tools.md]
style: spec
---

# Delta: the brand tools spec

Edits to `docs/2-engineering/specs/2026-10-26-brand-tools.md`. The founder chose A on 2026-10-29; these edits are applied.

- **Type roles and scale.** After "A role has the keys of §4.1 plus `weights` (array of integers, the weights shipped)",
  add: "and `weight` and `strong` (integers: the role's regular weight and its weight for emphasis, both in `weights`;
  `strong` is above `weight`, or equal to it when the face has one weight)". Add to the property sentence: "`--weight-<role>`
  and `--weight-<role>-strong` hold them."
- **Checks.** `type:<role>:weight` and `type:<role>:strong`: the value is in the shipped files' weights (`fvar` or
  `OS/2`), as `type:<role>:weights` is. A missing key is read as the default of the proposal's item 5.
- **Recipes.** Button: "its label in `--font-ui` at `--text-small`, weight `--weight-ui-strong`". Field: label and error
  in `--weight-ui`. Link: `--weight-ui`. Body emphasis: `--weight-body-strong`. A recipe holds no number for a weight.
- **Playground and type pages.** The weights a face has are offered; a face with one weight sets `weight` and `strong`
  to it. The export carries both for each role.
