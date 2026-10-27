---
title: Delta for a product's UI from its company's design system
status: draft
date: 2026-10-27
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../specs/2026-10-26-brand-tools.md]
style: spec
---


# Delta: v0 spec §4.1, §4.2, §7.1, §9.4, §9.5

## §4.1 Starting a run (added)

- A run of a graph whose realm has a UI MUST take a **design input**: a folder in the shape of a company's identity
  (`tokens.json`, `fonts.css` and the font files, `logo/`, `reference/`), as the brand tools spec's token contract
  (§5.5) and reference (§5.8) define it. The operator names it when starting the run; for a product with no company
  behind it, the operator gives the same shape by hand, and the rest of the graph does not see a difference.
- Odin MUST copy the design input into the project as read-only input at a fixed path, record its hash in the
  ledger, and refuse a UI run without one, or with one that fails the token contract's validation.

## §4.2 The web realm graph (modified)

- After `spec` and its gate, UI realms run a **`ui-design`** stage. From the spec and the design input it writes
  `ui.md`: the screens, the flows between them, each screen's layout and the base components it uses, and the
  product's own components as recipes from the same tokens (a recipe names, for each part and state, the tokens it
  uses). It writes one static prototype page per screen, built only from the reference's `components.css` and the
  new recipes, with sample content and no client data.
- A **`ui-gate`** follows (§7.1). Its pages follow the choice-page rules of the brand tools spec (§5.7): the founder's
  choices and reasons are saved where the agent reads them, every option visibly changes the page, and the page
  reopens on the saved choice.
- `plan` and the tasks read `ui.md`; a task that builds a screen names its prototype.

## §7.1 The approval points (modified)

- **UI gate (added):** the founder approves the product's screens and flows from their prototypes, in both modes, at
  phone, tablet and desktop widths, before planning starts. A UI change after the gate goes back through it.

## §9.4 Pack layout (modified)

- The `midgard-react` template MUST generate its theme from the design input: the Tailwind theme and the shadcn/ui
  variables from `tokens.json` through the token contract, and the fonts from `fonts.css`, self-hosted. Nothing in the
  template sets a colour, font, size, radius, shadow or duration of its own.
- The template's base components (button, link, field, card, message, navigation, image, icon) MUST follow the
  component recipes with the variants the design input names, with every state, in light and dark.
- The template MUST ship a `/styleguide` route that renders every base component and every product component in
  every state, in light and dark; it is built with the product and never linked from its navigation.
- The web implementer's prompt MUST point it at `ui.md`, the screen's prototype, the reference's screenshots and
  `components.css`, and MUST say to build only from theme tokens and base components.

## §9.5 The check ladder (modified)

- **Token use (added, per task):** the product's source sets no colour, font family, font size, radius, shadow or
  duration outside the theme; a literal is a finding with its location.
- **Fidelity (added, merge gate):** a pinned headless browser renders the product's `/styleguide` and the reference's
  component sheet, in both modes and at 390, 820 and 1280 pixels wide, and compares the computed styles of each base
  component and state; any difference is a finding naming the component, the state, the property and both values.
  This check answers readiness RB-25.
- **Screens beside their prototypes (added, review):** each screen built in the task is captured in both modes and
  shown beside its prototype to the spec-compliance and quality reviewers, who read images.
- **Accessibility (added, per task):** an automated accessibility check of each screen in both modes; a finding
  names the rule and the element.
