---
title: Each type role has its own weights in the token contract
status: accepted
date: 2026-10-29
related: [delta.md, tasks.md, ../2026-10-27-asgard-design-system/proposal.md, ../../specs/2026-10-26-brand-tools.md]
style: spec
---

# Each type role has its own weights in the token contract

**Proposed 2026-10-29.** It comes from the follow-ups of the design system build. The shape below is a proposal;
the founder has not decided it.

## Why

- A role's `weights` in `tokens.json` lists the weights the company **ships** (§4.2 of the brand tools spec). Nothing
  says which weight the role is **set in**. The component recipes fix those numbers themselves: a button label is
  600, a field label, an error and a navigation link are 500, body text is 400, and the reference's display text is
  regular because the display face has one weight.
- So a company cannot choose them. A heading face that looks right at 500 is set at 600; a ui face shipped at 400 and
  700 has no 500 or 600, and the browser draws a faux weight that `brand.py type` never sees, because the check
  only tests the weights the role lists.
- Both the playground and the reference had to guess a weight per role when the build found the display face had a
  single weight (asgard#41). The guess is in the code, not in the contract, and a product built from the contract
  repeats it differently.

## What changes

1. **Two weights for each role.** Each entry of `type.fonts` gets `weight` (the role's regular weight, an integer)
   and `strong` (the weight for emphasis inside the role, an integer above `weight`, or equal to it when the face
   has only one). The properties are `--weight-<role>` and `--weight-<role>-strong`.
2. **The recipes read them.** A button label is `--weight-ui-strong`; a field label, an error and a link are
   `--weight-ui`; body text is `--weight-body` and its bold emphasis `--weight-body-strong`; headings and the display
   text use their own role's `weight`. No recipe holds a number.
3. **The check reads the files.** `brand.py type` fails a role whose `weight` or `strong` is not in its shipped
   files (finding id `type:<role>:weight`), as it does for the `weights` list. The two are in `weights`.
4. **The tools propose them.** The type pages and the playground offer the weights the chosen face has; a face with one
   weight sets both to it. The reference and the playground read the properties and show them.
5. **Existing companies.** A `tokens.json` without the keys gets today's values when the tools read it: `weight` 400
   and `strong` 600 for `heading`, `body`, `display` and `wordmark`; `weight` 500 and `strong` 600 for `ui`, each
   lowered to the nearest weight the files have. Nothing changes on the page until a company sets them. `brand.py
   tokens --write` writes them out.

## Options

| | Shape | Cost |
| --- | --- | --- |
| **A. `weight` and `strong` for each role (recommended)** | the above | five roles, ten values; a recipe never holds a number |
| B. One `weight` for each role | `--weight-<role>` only; emphasis is `weight` + 200 | a button label and a field label cannot differ, and a face with 400 and 700 gets 600 |
| C. Keep shared numbers in the recipes | no change | the faux-weight case stays invisible to the check |

## Decision

Option A, chosen by the founder on 2026-10-29. It changes the token contract (§4.2), the button, field and link recipes and the `brand.py type`
check; the spec edits are applied with it and the other tasks are in `tasks.md`.
