---
title: Delta for Asgard's design system process
status: draft
date: 2026-10-27
related: [proposal.md, tasks.md, ../../specs/2026-10-26-brand-tools.md, ../../../1-product/design/2026-10-17-asgard-v0-design.md]
style: spec
---


# Delta: Asgard v0 design §6, §7, §8; brand tools spec

## Design §6.1, step 6 (modified)

Step 6, **Brand: look**, runs as seven sub-steps, in this order. The logo's design is settled first, because the rest
of the system is built around it. Every sub-step works the same way: the agent proposes valid candidates by a stated
method, checks them before showing them, and shows them side by side in light and dark with the company's own name
and words; the founder reacts and chooses, and may mix and match; each choice records its reason in the decision log.
The methods of the pages Ouroboric used for its own typeface and logo choices are the starting point, not the limit.

**6a Logo design (first).** The founder brings an initial concept: her own logo in any format and any quality, a
sketch, or an image from a generator. The agent prepares it (cut out, flat background removed, resolution raised),
then critiques it plainly: legibility at small sizes, how it reads in light and dark, distinctiveness in her trade,
irregular geometry, and lettering that is not a real typeface. It offers two to four alternatives: the concept as
drawn and cleaned, a refined version, and one or two variations that explore the idea further. They are shown as
Ouroboric's logo page shows them: identical blocks in the same order, each with a plain Strength and Risk (with the
size at which it fails, if it does), at 16, 24, 32 and 48 pixels in a light and a dark row, the favicon at 16, 32 and
64 pixels with an enlarged 16. The founder chooses one. What she chooses is the logo's **design**: its shapes and
their composition. Its colours come from the palette (6b) and change with it; its lettering, if it has any, is the
wordmark, set by the typography's wordmark role (6c), not fixed here.

**6b Palette.** Presets first: two to four named palettes seeded from the founder's mood words (step 5), the colours
of her logo concept, a colour she already uses, and her references, each with light and dark versions and checked
before it is shown. Then per role: every colour token (background, surface, border, text, muted, accent, the text on
the accent, and the message colours) can be changed on its own, from candidate values the agent proposes for that
role, or freely; changing any role turns the preset into "Custom". The logo is shown recoloured throughout. After
three rounds without a choice, the agent asks what is missing instead of offering more. The message colours are toned
to the palette and kept off the brand board.

**6c Typography, the wordmark included.** Criteria, in order: the voice's personality words; legibility at interface
sizes; every glyph of the clients' languages; the weights and italics each role needs; an open licence that allows web
use and self-hosting. Candidates come from an open library as named presets ("looks": a pairing with a one-line
character), each a starting point; every role has its own picker among valid candidates, and changing any role turns
the look into "Custom". Roles come in two groups, each with its job, where it appears and how often it is seen:
*character* faces (the **wordmark**, display, initial) and *system* faces (heading, body, interface), with mono and
ornament where the company needs them; the rarer the role, the more character it can afford. The wordmark role sets
the company's name in the logo wherever the logo has lettering. An "In use" view shows the look in light and dark
with a fact card per role (family, weights, licence), and a "Contexts" view shows it where people meet the company
(its social profile and posts, a link preview in a chat app, an email, a page of its website), noting where its own
fonts cannot reach. A five-second test flashes each look without its label and reveals the labels at the end. Four
lessons from Ouroboric's own choice apply: think in roles; check that the body face has bold and italic; check where
a style's label comes from; show candidates where people meet the brand, not only in a specimen.

**6d Imagery.** The guidelines (what images look like, never look like, how they are used), and up to six sample
images with their consent records.

**6e Foundations.** Each foundation offered as a few valid candidates for the founder to react to, proposed from the
typefaces and the voice: the type scale (base size and ratio, line heights per role, a minimum body size), spacing,
corner radius, elevation, motion (with reduced motion), breakpoints, and interaction states (focus, hover, active,
disabled).

**6f Playground.** An interactive prototype of the whole design system on fake content, where the founder sees and
adjusts everything together before it is final. It is a prototype for looking, not a website.

- **Content:** a few page sections (navigation, a hero, a grid of images, an about block, service cards, a contact
  block, a footer) and every component of the system: buttons, links, fields, cards, messages, navigation, image
  treatments, icons, and the focus, hover, active and disabled states; the type scale and the foundations; light and
  dark.
- **Adjustable, by mixing and matching valid candidates the agent proposes:** every palette role (presets and per
  role, as 6b); every typography role, the wordmark included (as 6c); every foundation (as 6e); and each component's
  variants (for example a filled, outlined or soft button; a flat or raised card; a framed or borderless image).
  New candidates can be added to the playground when the founder asks for something none of them gives.
- **Fixed:** the logo's design (6a). It follows the palette live, and its lettering follows the wordmark role.
- **Live checks:** the company's checks run as she changes anything. A pair under its contrast minimum, a focus
  indicator under 3:1, a body size under the minimum, or a typeface without the weights or italics its role needs
  shows a visible warning next to what it affects, and in a list of every open check. The playground and the
  company's checks share one rule set, so they cannot disagree.
- **Export:** the founder's final settings export as a token file; the agent applies it, and the company's own
  checks then decide.

**6g Board and applications.** Generated from the final tokens: the brand board, and the first applications (a
square social profile picture from the mark, a link preview image, an email signature).

The `brand` stop approves the board, after the founder has settled the system in the playground.

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
| RB-22 | Is the typography chosen for every role, the wordmark included, with its reason, under a licence that allows web use, covering every glyph of the clients' languages? | auto + human |
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
- §3.2 `brand.sh logo-prep DIR IMAGE`: cuts out the founder's concept, removes a flat background and raises the
  resolution; `brand.sh logo-proposals DIR`: renders the concept and the agent's alternatives as a review page
  (identical blocks with Strength and Risk, size ladders in light and dark, the favicon at 16, 32 and 64), and writes
  the chosen design as `logo/source/` PNGs in neutral colours for the palette to recolour.
- §3.1 `brand.py` checks: glyph coverage of every shipped font for the clients' languages; the minimum body size in
  the type scale; the focus colour at 3:1 against `bg` and `surface`; the foundation tokens present.
- §4.3 `fonts.css` serves WOFF2 (converted from the shipped font, subset to the clients' languages); the original
  file stays as the licence's evidence.
- §5.4 the board adds: each role in its typeface at its scale, a component sheet (button, link, field, card,
  message) in both modes, the logo's clear space and minimum size, and the applications.
- §5.5 the token contract: the names and meanings a product theme maps from `tokens.json`, written for the product
  realms to read.
- §5.6 `brand.sh playground DIR`: writes the playground as one self-contained HTML file in the company's brand folder
  (no network at view time: the candidate typefaces are embedded, subset), generated from `tokens.json`, a candidates
  file (palette presets and per-role values, typography looks and per-role faces, the wordmark included, foundation
  candidates, component variants) and the company's check rules, so its live checks are the same rules as
  `brand.py`. The logo is drawn from its traced design, recoloured from the live palette, with its lettering set in
  the live wordmark face. Its export is a
  token file `brand.py` validates before anything is applied. The founder opens it from a link: GitHub's file view
  does not run it, so until a private preview exists (backlog B-202) the agent shares it privately for viewing.

## Kickstart guide (added)

A guide in the Asgard leaf: the nine steps of design §6 as a procedure. For each step: what to ask the founder, in
what order; what to write and where; which tool and check to run; what the founder approves and when. It is written
from the first real run's log, without any company's particulars.
