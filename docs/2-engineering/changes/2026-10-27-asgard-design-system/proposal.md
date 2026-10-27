---
title: Asgard's design system process
status: draft
date: 2026-10-27
related: [delta.md, tasks.md, ../../specs/2026-10-26-brand-tools.md, ../../../1-product/design/2026-10-17-asgard-v0-design.md]
style: direction
---


# Change proposal: Asgard's design system process

## Why

The first real company kickstart (the Asgard v0 design's acceptance run, §9) reached step 6, **Brand: look**, and
produced a palette, a logo, one typeface, imagery guidelines and a brand board. The run showed that step 6 names its
outputs but not how the founder reaches them, and that the design system it leaves behind is thin. Everything below
was improvised in that run, or missing.

1. **No method for the founder's choices.** The typeface was chosen from candidates the agent picked by instinct,
   with no criteria. The palette took four rounds of reactions with no seed and no stopping rule. The founder's logo
   (made with an image generator) was cut out, cleaned and rebuilt in a real typeface by ad hoc scripts.
2. **Foundations missing from the tokens.** `tokens.json` holds colours and font families; `type.scale` is empty.
   There is no spacing scale, radius, elevation, motion, breakpoints, or interaction states (focus, hover, disabled).
   The identity page's "rules" are prose a product cannot read.
3. **Checks the design system lacks.** Glyph coverage for the clients' languages, a minimum text size, the focus
   indicator's contrast, the web font's format and weight, and the tokens' completeness are not checked.
4. **A board that shows too little.** One specimen line per typeface, no type scale, no components, no logo usage.
5. **No component baseline and no applications.** Nothing shows a button, a link, a field or a card in both modes;
   nothing produces the places a small company's brand appears first: a social profile picture, a link preview, an
   email signature.
6. **No kickstart guide.** The journey exists only as the design's §6 table; the run's questions, checks and order
   were the agent's own.
7. **Products ignore the design system.** The web realm's template starts on stock Tailwind and a neutral theme; no
   contract maps the company's tokens to a product's theme. That is Yggdrasil's side (it extends B-195); this
   proposal only names the contract the company's tokens must meet.

## What changes

- **The journey (design §6).** Step 6 becomes seven sub-steps, each with its selection method: palette, typography,
  logo, imagery, foundations, the board with the brand's first applications, and a **playground**: an interactive
  prototype of the whole system on fake content, where everything except the logo can be adjusted (typefaces mixed
  per role from the candidates) and the company's checks run live, with a visible warning where a choice breaks a
  rule. The founder still decides by reacting to options; the agent now builds the options by a stated method and
  checks them before showing them.
- **The template (design §7).** The identity gains foundations: a type scale, spacing, radius, elevation, motion,
  breakpoints and interaction states, as tokens and as identity sections.
- **Readiness (design §8).** RB-21 becomes four level 1 items: the identity, the typography, the foundations, and
  interaction and accessibility. RL-06 (level 2) grows to the component baseline, the icon set, logo usage and the
  brand's applications. A product item names the token contract.
- **The brand tools (spec).** New tools for typeface candidates and specimens, palette rounds, logo preparation and
  the foundations; new checks; a fuller board. The delta lists them.
- **A kickstart guide** in the Asgard leaf (design §5.2: it holds the journey): the nine steps as a procedure, each
  with its questions, outputs, checks and stop.

## Not in this change

- Anything particular to one company or one trade: what a photographer shows as sample images, her channels, her
  prices. The process is generic; a trade's specifics stay in that company's documents.
- The token contract's implementation in the web realm (a Yggdrasil backlog item, B-217).
- Changing any company's design system: companies take the new template and tools through their own update.
