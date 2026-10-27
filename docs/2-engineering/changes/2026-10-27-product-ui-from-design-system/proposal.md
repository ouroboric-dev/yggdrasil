---
title: A product's UI from its company's design system
status: draft
date: 2026-10-27
related: [delta.md, tasks.md, ../2026-10-27-asgard-design-system/proposal.md, ../../backlog.md]
style: direction
---


# Change proposal: a product's UI from its company's design system

## Why

Proof run 1's product worked, but the founder judged its interface "very basic and barebones" (2/10 for the
product). Backlog B-195 traces it: nothing in the software graph decides what the screens look like, and each web task
builds its page from the acceptance criteria and the template's plain components. B-217 adds that a new web product
starts on stock Tailwind and a neutral theme, whatever its company chose.

The company side is changing (change 2026-10-27-asgard-design-system): at step 6 the founder settles a whole design
system in a playground, and the company keeps it as tokens (palette, type roles and scale, foundations, component
variants) and a **reference** generated from them (a component stylesheet, the final playground and its
screenshots). A rehearsal on a real company showed the playground is faithful to what the founder wants. What is
missing is the way from there into a product the factory builds:

1. **No input.** A run does not receive the company's design system, so no stage can read it.
2. **No theme.** The web realm's template has no theme to fill and no base components built from tokens.
3. **No UI design.** No stage designs the product's own screens: which ones, how a user moves between them, how each
   is laid out, and the product's own components (for a client gallery: the photo grid, the viewer, downloads).
4. **No check.** Nothing compares what was built with the design: the founder found out at the end, by looking.

## What changes

- **The design input.** A run takes a design input: the company's identity folder (tokens, fonts, logo, reference),
  or the same shape given by hand for a product with no company behind it. Odin copies it into the project as
  read-only input, and every stage that needs it reads it from there.
- **The theme and base components (`midgard-react`).** The template's theme (Tailwind theme and shadcn/ui variables)
  and its fonts are generated from the design input through the token contract. Its base components (button, link,
  field, card, message, navigation, image, icon) are built from the component recipes, with the variants the company
  chose, in both modes. A `/styleguide` route renders every base component in every state, in light and dark.
- **A UI design stage (`voluspa/software`, UI realms only).** After the spec: the screens, the flows between them, the
  layout of each, and the product's own components as new recipes from the same tokens, written as `ui.md` with one
  static prototype page per screen built only from the reference stylesheet. A **UI gate** shows the founder the
  prototypes, with the choice-page rules of the company step (her choices saved where the agent reads them, every
  option visible).
- **The implementer's context.** The web implementer reads `ui.md`, the screen's prototype, the reference
  screenshots and the stylesheet, and builds only from theme tokens and base components.
- **Checks.** A token-use check (no colour, font or size outside the theme in the product's source); a fidelity check
  (the product's `/styleguide` against the reference: the computed styles of each component and state must match, in
  both modes and at three widths); each screen's screenshot next to its prototype for the reviewers; accessibility
  in both modes.

## Not in this change

- Native mobile UI: a mobile realm would read the same input and contract; it is not built yet.
- Pixel-diff visual regression: the fidelity check compares computed styles, which survive content changes; pixels
  do not.
- The company's own step 6: change 2026-10-27-asgard-design-system.
