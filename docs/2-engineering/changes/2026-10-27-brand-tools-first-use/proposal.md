---
title: Brand tools after their first real use
status: draft
date: 2026-10-27
related: [delta.md, tasks.md, ../../specs/2026-10-26-brand-tools.md, ../2026-10-27-brand-tools-spike/proposal.md]
style: spec
---


# Change proposal: brand tools after their first real use

## Why

The brand tools made their first real brand board, for a real company's founder (the Asgard v0 design's acceptance
run, §9). The founder asked for one change, and the run showed four defects.

1. **The message colours on the board.** The status tokens `ok`, `warn` and `crit` colour the products' system
   messages. On the board they read as brand colours that do not belong, and the founder asked to take them off.
2. **A cache folder in the company.** `brand.sh board` imports the company's `brand.py` to hash the board's inputs,
   and Python wrote `.ouroboric/checks/__pycache__/` into the company's repository.
3. **Variable fonts in `fonts.css`.** A variable font got one `font-weight`, its default instance's, so a browser
   would synthesise the other weights instead of using the font's own.
4. **Shades in the colour table.** A logo with smooth edges traces as several near-identical shades of one colour;
   the board listed each as its own row, all mapped to the same token.
5. **fontTools missing.** On a machine whose `python3` has no fontTools, the font check failed with a traceback.

## What changes

- The board shows the brand colours only: the message colours leave the palette panels, the palette strip and the
  contrast tables, and one line says where they are. The brand check still checks their contrast, and a failing
  message colour is still an open item on the board.
- No tool writes a bytecode cache into the company.
- `fonts.css` gives a variable font the range of its weight axis (`font-weight: 100 900`).
- The logo's colour table has one row for each mode and token (or kept colour).
- The font check stops with exit code 2 and names what it needs when fontTools is missing, and only when there is a
  font file to read.

## Not changed

The checks' rules, the tokens, the logo processing and every other criterion.
