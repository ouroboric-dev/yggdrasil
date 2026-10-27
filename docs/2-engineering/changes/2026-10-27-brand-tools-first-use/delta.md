---
title: Delta for the brand tools after their first real use
status: draft
date: 2026-10-27
related: [proposal.md, tasks.md, ../../specs/2026-10-26-brand-tools.md]
style: spec
---


# Delta: brand tools spec §3.1, §4.3, §5.4, §5.5

## Added

- §5.4: the palette panels, the palette strip and the contrast tables MUST leave out the message colours (`ok`,
  `warn`, `crit`). The board MUST say in one line that they colour the products' system messages and are checked.
  A message colour that fails its contrast MUST still be an open item.
- §5.4: the logo's colour table MUST have one row for each mode and token, or for each kept colour.
- §5.5: no tool MUST write a bytecode cache (`__pycache__`) into the company's repository.
- §3.1: when fontTools is missing and a font file must be read, `brand.py` MUST stop with exit code 2 and name what it
  needs. A company with no shipped font MUST NOT need fontTools.

## Modified

- §4.3, `fonts.css` (was: one `@font-face` for each shipped font file): the same, and a variable font's
  `font-weight` is the range of its `wght` axis, minimum and maximum.
