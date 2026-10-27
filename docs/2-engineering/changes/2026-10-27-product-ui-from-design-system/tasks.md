---
title: Tasks for a product's UI from its company's design system
status: draft
date: 2026-10-27
related: [proposal.md, delta.md]
style: spec
---


# Tasks: a product's UI from its company's design system

Each task starts from its repository's `origin/main`, writes its failing test first, and ends with a pull request
opened with `ouroboric/scripts/pr-open.sh`. This change depends on change 2026-10-27-asgard-design-system for the
token contract (brand tools spec §5.5), the choice-page rules (§5.7) and the reference (§5.8): UI-T01 to UI-T03 can
start from a fixture design input written to the contract before Asgard's tools exist. It closes backlog B-195 and
B-217 when the last task lands.

```text
UI-T00 ── UI-T01 ──┬─ UI-T02 ── UI-T03 ──┬─ UI-T04
                   │                     ├─ UI-T05
                   │                     └─ UI-T09
                   └─ UI-T06 ── UI-T07 ── UI-T08 ── UI-T10
```

## Yggdrasil

- [ ] **UI-T00 Fold the delta and a fixture.** Once approved: amend the v0 spec (§4.1, §4.2, §7.1, §9.4, §9.5) with
      the delta. Add a fixture design input under `odin/internal/run/testdata/` (or the realm's `testdata/`): a full
      `tokens.json` to the token contract with two palettes, five type roles, foundations and component variants,
      a free font with its licence, a logo, and a `reference/` with `components.css`. Every later test reads it.

## Odin

- [ ] **UI-T01 The design input.** `odin/internal/cli` (the run flag), `odin/internal/run` (start): `ygg run` takes
      `--design DIR`; Odin validates it against the token contract (required keys, hex colours, a font file and licence
      per role, the reference present), copies it read-only into the project (fixed path, for example
      `.factory/design/`), and writes its hash to the ledger. A graph whose realm declares a UI refuses to start
      without one. Tests: a valid input is copied and hashed; a missing key, a missing font file and a missing input on
      a UI realm are each refused with a message naming what is missing.

## `midgard-react`

- [ ] **UI-T02 The theme.** `templates/web/src/index.css`, `components.json`, the scaffold (`init.sh`): generate a
      `theme.css` from the design input that maps the contract's tokens to Tailwind v4 `@theme` variables and the
      shadcn/ui CSS variables (`--background`, `--foreground`, `--primary`, `--primary-foreground`, `--card`,
      `--border`, `--ring`, `--radius`, …) in light and dark (`prefers-color-scheme` and `data-theme`), and
      `@font-face` for each role from the input's font files, served by the product. `baseColor: neutral` goes.
      Tests (`template_test.go`): a product scaffolded with the fixture shows the fixture's background, accent and
      fonts in both modes; a second fixture palette changes them.
- [ ] **UI-T03 The base components and the styleguide.** `templates/web/src/components/ui/`: button (filled,
      outlined, soft; default, hover, active, focus, disabled), link (underlined, colour only), field (default,
      focus, error), card (bordered, surface, raised), message (tint, bar; ok, warn, crit), navigation (logo left,
      centred), image (borderless, rounded, framed), icon (outline, filled), each reading the variant from the design
      input; and `src/routes/styleguide.tsx` rendering every component, variant and state in light and dark. Tests:
      every variant renders differently (computed-style fingerprint per variant, as the rehearsal's playground test).
- [ ] **UI-T04 The token-use check.** `devcontainer/checks/web-static.sh` or a new `web-tokens.sh` on the per-task
      rung: a literal colour (`#…`, `rgb(`, `hsl(`, named colours), font family, font size in px, radius, shadow or
      duration in `src/` outside `theme.css` is a finding with file and line; Tailwind arbitrary values (`[#…]`,
      `[13px]`) count. Tests: one fixture source per kind of literal.
- [ ] **UI-T05 The fidelity check.** A new `devcontainer/checks/web-fidelity.sh` on the merge-gate rung: a pinned
      headless browser (the one the e2e checks already use) opens the product's `/styleguide` and the design input's
      `reference/playground.html` component sheet, in light and dark at 390, 820 and 1280 px, reads the computed
      styles of each component and state (colour, background, border, radius, shadow, font family, size, weight, line
      height, padding, gap, outline, min-height, transition and animation durations), and reports each difference as
      a finding: component, state, mode, width, property, expected, found. Components carry matching
      `data-component` and `data-state` attributes in both pages. Tests: one deliberate drift per property family.
- [ ] **UI-T08 The implementer and the reviewers.** `prompts/implementer.md`: read `ui.md`, the screen's prototype,
      the reference screenshots and `components.css`; build only from theme tokens and the base components; add a new
      component as a recipe in `ui.md` first. Reviewer prompts in `voluspa/software/prompts/reviewer-*.md`: each
      screen's screenshots (both modes) beside its prototype; a visible difference is a finding with the screen and
      the region. Tests: `prompts_test.go` asserts the context is named.
- [ ] **UI-T09 Accessibility.** A `web-a11y.sh` check per task: axe-core through the e2e browser on every route in
      both modes; a violation is a finding with the rule and the element. Tests: a fixture page with a low-contrast
      text and a missing label.

## `voluspa/software` and Odin

- [ ] **UI-T06 The UI design stage.** `voluspa/software/graph.yaml`: a `ui-design` node after `spec-gate` for realms
      that declare a UI, and `prompts/ui-design.md`: from the spec and the design input, write `ui.md` (screens; the
      flows between them; for each screen its layout, sections and the base components used; the product's own
      components as recipes from the tokens) and one static prototype page per screen in `ui/`, built only from
      `reference/components.css` and the new recipes, with sample content and no client data. Test: a dry run on the
      client gallery's spec writes one prototype per screen and a `ui.md` whose recipes use only contract tokens.
- [ ] **UI-T07 The UI gate.** `odin/internal/gate` and the graph: an approval point after `ui-design`; its review
      page shows every prototype in both modes at three widths, under the choice-page rules (choices and reasons
      saved where the agent reads them, every option visible, reopening on the saved choice); the saved choices go
      back into `ui.md` before `plan`. Tests: the gate blocks until approved; a saved choice changes `ui.md`.
- [ ] **UI-T10 A proof run.** The client gallery built for a company with a set design system (a fixture company, or
      a real one with its founder's consent); the founder compares the product with its prototypes, and the fidelity
      check passes. The run's report records the fidelity and accessibility findings.
