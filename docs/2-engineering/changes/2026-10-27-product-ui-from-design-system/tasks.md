---
title: Tasks for a product's UI from its company's design system
status: draft
date: 2026-10-27
related: [proposal.md, delta.md]
style: spec
---


# Tasks: a product's UI from its company's design system

Each task starts from its repository's `origin/main`, test first, and ends with a pull request. This change depends
on change 2026-10-27-asgard-design-system for the token contract (§5.5), the choice-page rules (§5.7) and the
reference (§5.8). It closes backlog B-195 and B-217 when the last task lands.

- [ ] **UI-T01 The design input.** Odin: `ygg run` takes the design input, validates it against the token contract,
      copies it read-only into the project and records its hash; a UI run without one is refused.
- [ ] **UI-T02 The theme.** `midgard-react`: the Tailwind theme, the shadcn/ui variables and the self-hosted fonts
      generated from the design input; a test that a product scaffolded with a set palette shows it, in both modes.
- [ ] **UI-T03 The base components and the styleguide.** `midgard-react`: the base components from the recipes and
      variants, and the `/styleguide` route; a test that every variant renders differently.
- [ ] **UI-T04 The token-use check.** `midgard-react` checks: literals outside the theme are findings with locations.
- [ ] **UI-T05 The fidelity check.** `midgard-react` checks: the computed-style comparison of `/styleguide` against the
      reference, in both modes at three widths; a test with one deliberate drift per kind of property.
- [ ] **UI-T06 The UI design stage.** `voluspa/software`: the `ui-design` node and its prompt, writing `ui.md` and the
      screen prototypes; a dry run on the client gallery's spec.
- [ ] **UI-T07 The UI gate.** Odin and `voluspa/software`: the approval point, its pages under the choice-page rules,
      the saved choices read back into the run.
- [ ] **UI-T08 The implementer and the reviewers.** `midgard-react/prompts/implementer.md` and the reviewer prompts:
      the UI context, and screens beside their prototypes.
- [ ] **UI-T09 Accessibility.** `midgard-react` checks: the automated accessibility check per screen in both modes.
- [ ] **UI-T10 A proof run.** The client gallery built for a company with a set design system; the founder compares
      the product with its prototypes, and the fidelity check passes.
