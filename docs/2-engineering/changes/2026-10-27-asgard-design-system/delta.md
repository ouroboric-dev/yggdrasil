---
title: Delta for Asgard's design system process
status: draft
date: 2026-10-27
related: [proposal.md, tasks.md, ../../specs/2026-10-26-brand-tools.md, ../../../1-product/design/2026-10-17-asgard-v0-design.md]
style: spec
---


# Delta: Asgard v0 design §6, §7, §8; brand tools spec

## Design §6.1, step 6 (modified)

Step 6, **Brand: look**, runs as six sub-steps. In each, the agent builds two to four options by the stated method,
checks them, and shows them side by side, in both modes, with the company's own name and words; the founder reacts
and chooses. A choice records its reason in the decision log.

| Sub-step | Method | Output |
| --- | --- | --- |
| 6a Palette | Seeds: the founder's mood words (step 5), a colour she already uses (her logo, a colour picked from her work), and her references. A round is two to four palettes, each with light and dark versions, checked for contrast before it is shown, the logo applied. After three rounds without a choice, the agent asks what is missing instead of offering more. Status colours are toned to the palette and kept off the board. | `tokens.json` colours |
| 6b Typography | Criteria, in order: the voice's personality words; legibility at interface sizes; every glyph of the clients' languages; the weights and italics the roles need; an open licence that allows web use and self-hosting; a heading and body pairing (one family is a valid pairing). Candidates come from an open library, three to five, each shown setting the company's name, tagline and about text. | the typefaces, their roles and the reason |
| 6c Logo | Intake: the founder's own logo (any format, any quality), a sketch, or none. Preparation: cut out, remove a flat background, raise the resolution, rebuild the lettering in the chosen typeface when it is not a real font, regularise geometric parts; the founder chooses between "as drawn" and "rebuilt". Then the existing trace, recolour and export. | the logo and mark, light and dark; favicon and icons |
| 6d Imagery | The guidelines (what images look like, never look like, how they are used), and up to six sample images with their consent records. | imagery guidelines, sample images |
| 6e Foundations | Proposed from the typeface and the voice, for the founder to react to: a type scale (sizes and line heights per role, a minimum body size), spacing, corner radius, elevation, motion (with reduced motion), breakpoints, and interaction states (focus, hover, active, disabled). | `tokens.json` foundations |
| 6f Board and applications | The brand board, plus the first applications: a square social profile picture from the mark, a link preview image, an email signature. | the board, the applications |

The `brand` stop approves the board, which shows all six.

## Design §7, the template (modified)

- Brand, identity: palette, typography (with its reason), logo, foundations (type scale, spacing, radius, elevation,
  motion, breakpoints, interaction states), tokens; applications.
- `tokens.json` gains `type.scale` (filled), `space`, `radius`, `elevation`, `motion`, `breakpoints` and `focus`,
  and the clients' languages the glyph check reads.

## Design §8, readiness (modified)

Level 1 (ready to build), replacing RB-21:

| ID | Question | Check |
| --- | --- | --- |
| RB-21 | Is the identity defined: logo and mark in light and dark, a palette whose pairs pass WCAG 2.2 AA in both modes? | auto + human |
| RB-22 | Is the typography chosen with its reason, under a licence that allows web use, covering every glyph of the clients' languages? | auto + human |
| RB-23 | Are the foundations set as tokens: type scale with a minimum body size, spacing, radius, elevation, motion, breakpoints? | auto |
| RB-24 | Are interaction states defined, with a focus indicator that reaches 3:1, and is reduced motion honoured? | auto + human |
| RB-25 (product) | Does the product's theme come from the company's tokens, through the token contract? | auto |

Level 2, RL-06 (modified): is the full visual identity done: the component baseline (buttons, links, fields, cards,
messages) in both modes, an icon set with its licence, logo usage rules (clear space, minimum size, misuse), and the
brand's applications?

## Brand tools spec (added)

- §3.2 `brand.sh fonts DIR`: fetches three to five candidate typefaces from an open library (each with its licence
  file), and renders a specimen of each with the company's name, tagline and about text, in its languages.
- §3.2 `brand.sh palette DIR ROUND.json`: renders a palette round (light and dark, the logo applied), each palette
  checked with the company's contrast rules before it is shown.
- §3.2 `brand.sh logo-prep DIR IMAGE`: cuts out the logo, removes a flat background, raises the resolution, and
  writes the founder's choices as `logo/source/` PNGs.
- §3.1 `brand.py` checks: glyph coverage of every shipped font for the clients' languages; the minimum body size in
  the type scale; the focus colour at 3:1 against `bg` and `surface`; the foundation tokens present.
- §4.3 `fonts.css` serves WOFF2 (converted from the shipped font, subset to the clients' languages); the original
  file stays as the licence's evidence.
- §5.4 the board adds: each role in its typeface at its scale, a component sheet (button, link, field, card,
  message) in both modes, the logo's clear space and minimum size, and the applications.
- §5.5 the token contract: the names and meanings a product theme maps from `tokens.json`, written for the product
  realms to read.

## Kickstart guide (added)

A guide in the Asgard leaf: the nine steps of design §6 as a procedure. For each step: what to ask the founder, in
what order; what to write and where; which tool and check to run; what the founder approves and when. It is written
from the first real run's log, without any company's particulars.
