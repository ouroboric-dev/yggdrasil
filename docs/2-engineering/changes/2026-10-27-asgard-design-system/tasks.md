---
title: Tasks for Asgard's design system process
status: draft
date: 2026-10-27
related: [proposal.md, delta.md]
style: spec
---


# Tasks: Asgard's design system process

Each task starts from its repository's `origin/main`, writes its failing test first, and ends with a pull request
opened with `ouroboric/scripts/pr-open.sh`. Nothing in Asgard names a company; test fixtures use "Example Studio".
The order below follows the dependencies; tasks on one line of the graph can run in parallel.

```text
DS-T00 ─┬─ DS-T03 ── DS-T04 ──┬─ DS-T08 ── DS-T09 ── DS-T13
        │                     ├─ DS-T05 ─┐
        ├─ DS-T02             ├─ DS-T06 ─┼─ DS-T12 ─┬─ DS-T14 ─┐
        └─ DS-T01 (last)      └─ DS-T07 ─┘          ├─ DS-T15 ─┼─ DS-T11
                                                    └─ DS-T16 ─┘
DS-T10 (with DS-T03)
```

## Yggdrasil

- [x] **DS-T00 Fold the delta.** Once approved: amend the Asgard v0 design (§6.1 step 6, §7, §8) and the brand tools
      spec (§3.1, §3.2, §4.3, §5.4 to §5.8) with the delta. Docs only.
- [x] **DS-T10 The token contract.** Brand tools spec §5.5: every key of `tokens.json` a product reads (colours, type
      roles and scale, `space`, `radius`, `elevation`, `motion`, `focus`, `target`, `breakpoints`, `components`,
      `accepted`), its type, unit and meaning, and the component recipes: for each component (button, link, field,
      card, message, navigation, image, icon) and variant, the tokens each part and state uses. Written for the
      product realms; the realm side is change 2026-10-27-product-ui-from-design-system.

## Asgard

- [x] **DS-T03 Foundations in the template.** `templates/company/core/docs/7-branding/identity/tokens.json`: the new
      keys of the token contract with a starting set that passes the checks; the type roles `wordmark` and `display`
      beside `heading`, `body`, `ui`; the identity page's sections (foundations, components, accepted exceptions,
      applications). `brand.py tokens` generates `tokens.css` with the foundation variables (`--space-1`…,
      `--radius-*`, `--shadow-*`, `--motion-*`, `--focus-*`, `--font-<role>` for the five roles). Test first in
      `scripts/tests/brand-checks.test.sh`: a fixture company's generated CSS carries every foundation variable.
- [x] **DS-T04 New checks.** `templates/company/core/.ouroboric/checks/brand.py`: glyph coverage of each shipped
      font for the clients' languages (the languages read from `tokens.json`); the minimum body size (16 px); body line
      height at least 1.5; the focus colour at 3:1 against `bg` and `surface` in both modes, at least 2 px; the touch
      target at least 24 px; the foundations present; the body face's italic and the roles' weights read from the font
      files (fvar and OS/2), never from `tokens.json`; and the accepted exceptions: an `accepted` entry (check id,
      value, reason, by, date) whose value matches turns a failure into "accepted"; one whose value changed is
      reported stale and the check fails. Tests first: one fixture per rule that fails, and one accepted exception
      that passes and then goes stale when its value changes.
- [x] **DS-T08 Web fonts.** `fonts.css` serves WOFF2 converted from the shipped font and subset to the clients'
      languages (fontTools with the Brotli module); the original stays as the licence's evidence. Test: the WOFF2 holds
      every glyph of the languages.
- [x] **DS-T09 The board.** `scripts/brand/board.py`: each type role at its scale size, the foundations, a component
      sheet in both modes from the recipes, logo usage (clear space as the mark's width, minimum sizes, misuses), the
      kept exceptions with their reasons, and the applications. Message colours stay off the board. Test: a fixture's
      board lists every role, every recipe and every accepted exception.
- [x] **DS-T05 Typography tool.** `brand.sh fonts DIR CANDIDATES.json`: fetches the candidate faces with their licence
      files from the Google Fonts repository (`ofl/<family>/`), reads each face's facts from the file (family name,
      weights from fvar, italic from a sibling italic file, glyph coverage), and writes the facts the typography page
      shows. Test: a fixture face without italic is reported without italic, whatever the candidates file says.
- [x] **DS-T06 Palette rounds.** `brand.sh palette DIR ROUND.json`: checks every preset with `brand.py`'s rules before
      it is shown and refuses a failing preset with the failing pairs named. Test: a round with one failing preset.
- [x] **DS-T07 Logo design.** `brand.sh logo-prep DIR IMAGE`: cuts out a flat background, flattens anti-aliased edges
      to the logo's flat colours, and raises the resolution so the short side is at least 1000 px and a mark is at
      least 2400 px (at 1400 px the tracer cut a mark's long arcs short: 1.94% against a 1% limit; at 2400 px,
      0.35%). `brand.sh logo-proposals DIR CANDIDATES.json`: the review page (a panel per alternative; the logo at 16,
      24, 32, 48 px and the mark at 16, 32, 64 px with an enlarged 16, each in its own light and dark row; the
      lettering picker in serious and stylised groups; a poor-fit note per alternative and face) and the chosen
      design written as `logo/source/` PNGs in the palette's text and accent colours. Tests: a mark with long arcs
      traces faithfully after logo-prep; a symbol that does not fit a face's counter is flagged.
- [x] **DS-T12 Choice pages.** The four rules of spec §5.7 as one shared module the pages use, each with a test: the
      choice and reason saved where the agent reads them (the company's `docs/7-branding/identity/choices/`, through
      `brand.sh serve`, a local server on 127.0.0.1, or a download), and the page reopening on it; candidate facts read
      at build time; every face loads (`brand.sh check-page` lists `document.fonts` as loaded for each family in
      Playwright's Chromium, pinned in `requirements.txt`); every option visibly changes the page (fingerprint the
      preview's computed styles per option in both modes at 390, 820 and 1280 px; two options with the same
      fingerprint fail). Font names in inline `style` attributes are single-quoted. `logo-proposals` is rebuilt on the
      module.
- [x] **DS-T14 The palette page.** The page of step 6b, the first of the guided pages: one decision at a time, one
      option at a time, with its explanation. `brand.sh palette-page DIR`: from a checked round (DS-T06), a card for
      the choice of a preset (each preset shown alone, in light and dark, with the logo recoloured, what each colour is
      for, and its contrast results in plain words), then a card for each colour role in turn (what it is for,
      candidate values one at a time, or her own value, with the company's rule checked live in plain words). It adds
      the guided-page component to the shared module (cards, one option shown at a time, progress, summary). Saves
      `choices/palette.json`. Tests: the page and `brand.py` agree on every pair of a fixture; the four rules.
- [x] **DS-T15 The typography pages.** The pages of step 6c, width first. `brand.sh type-page DIR CANDIDATES.json
      [--stage taste|depth|roles]` builds three guided pages, each from what the one before saved: *taste* (a card for
      each of 16 style directions with the two faces that start it, in her own words: which does she like?), *depth*
      (only the directions she liked, with the faces held back there) and *roles* (a card for each of the wordmark,
      display, heading, body and interface roles, offering her favourites that suit it, with the facts read from the
      font files and plain warnings about the weights and italic a role needs). Asgard ships a curated list of 75 open
      faces in 16 directions (`faces.json`, made by `pin_faces.py` from `faces-source.json`), each file pinned by its
      SHA-256 at one commit of the library; any family `brand.sh fonts` fetched can be offered too. Saves
      `choices/type-taste.json`, `type-depth.json` and `type.json`. Tests: the four rules; a face without an italic is
      shown without one; a file that does not match its hash is refused.
- [x] **DS-T16 The foundations page.** The page of step 6e. `brand.sh foundations-page DIR CANDIDATES.json`: a card for
      each foundation in turn (type scale, spacing, corner radius, elevation, motion, breakpoints, interaction
      states), each with a few candidates shown, not described: motion played side by side and still where the
      device asks for reduced motion, breakpoints as a ruler with a width slider, depth on a card that shows it.
      Saves `choices/foundations.json`. Tests: the four rules; every foundation has its card.
- [x] **DS-T11 The playground.** `brand.sh playground DIR [CANDIDATES.json]`: one self-contained page that opens on the
      founder's saved choices (DS-T14 to DS-T16, DS-T07) and on `tokens.json`, so she revisits everything together one
      last time: tabs for the palette (her own, the presets, a colour at a time, her own value), the type (a face for each
      role from her favourites), the foundations, the components (a variant of each) and the checks; a sample site painted
      only from tokens, in light and dark, at phone, tablet and desktop widths, with motion played; the checks listed with
      their ids from `brand.py`'s own pairs and minimums (a test proves the page and `brand.py` agree on every pair of a
      fixture); a failure she keeps, with a reason, becomes an accepted exception; save and reopen (DS-T12). It adds
      `brand.py components` (a soft button's text on its tint, an outlined button's text, a link without an underline, a
      tinted message) and `brand.sh playground-apply DIR --by NAME`, which validates the export with `brand.py` in a
      throwaway copy before it writes `tokens.json`, copies the shipped fonts and makes the CSS again. Depends on DS-T03 to
      DS-T07, DS-T12 and the guided pages DS-T14 to DS-T16.
- [x] **DS-T13 The reference.** `brand.sh reference DIR`: `identity/reference/components.css` (every recipe and
      variant, only `var(--…)` from `tokens.css`), `playground.html` (self-contained, saving removed) and the
      screenshots (light and dark at 390, 820 and 1280 px) from a pinned headless browser; `brand.py` reports the
      reference stale when its inputs change. Tests: the stylesheet holds no literal colour, font or size; the stale
      check fails after a token changes.
- [x] **DS-T02 Readiness checklist.** `templates/readiness/checklist.md`: RB-21 to RB-25 and RL-06 as the delta gives
      them, with an "applies to" column (company or product) and no tool names in what a company copies; accepted
      exceptions listed under their item.
- [x] **DS-T01 The kickstart guide.** Asgard `docs/`: the nine steps of design §6 as a procedure, step 6 in its seven
      sub-steps, each with what to ask, in what order, what to write where, which tool and check to run, what the
      founder approves and how the choice is saved. Written from the first real run's log, without any company's
      particulars. Last, so it describes the tools as built.

## Follow-ups from the build

- The reference and the playground each hold a copy of the component recipes (`components.json` feeds the reference; the
  playground carries its own): one source for both.
- The logo's lettering is drawn once from the chosen face and is not redrawn when the wordmark face changes later.
- Type roles share one weight token; a weight for each role is a change to the token contract.

## After the tasks

- A company already set up takes the new template and tools through its own update (backlog B-203), then reruns
  readiness level 1.
