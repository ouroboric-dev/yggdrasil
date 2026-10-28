---
title: Brand tools spec
status: accepted
date: 2026-10-26
related: [../../1-product/design/2026-10-17-asgard-v0-design.md, 2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Brand tools spec

## 1. Summary

This spec says how Asgard delivers the tools of step 6, **Brand: look**, in the
[Asgard v0 design](https://github.com/ouroboric-dev/yggdrasil/blob/main/docs/1-product/design/2026-10-17-asgard-v0-design.md)
(§6.1 row 6, §6.2, §8). Step 6 ends at the founder's `brand` stop, where she approves a **brand board**.

There are four tools:

- **The contrast check** reads the palettes in `tokens.json` and checks every text and shape pair against WCAG 2.2
  level AA, in light and dark mode.
- **The font licence check** reads the licence file and the metadata of each font the company ships. It passes a
  font only on evidence of a known open licence and flags everything else for a person.
- **Logo processing** traces the founder's PNG into SVG with **VTracer 0.6.15 (MIT)**, recolours it with the palette
  tokens, derives the missing mode, exports the favicon and app icons (from an optional square mark when she brings
  one), and checks that the trace is faithful. A trace that is not faithful is recorded as a gap and shown on the
  board.
- **The brand board** is a generated page in the company's docs, in plain Markdown with generated images, so it reads
  the same in GitHub's file view as in the rendered pages. It shows the palettes with their contrast, the fonts, her
  PNG beside the SVGs, the icons, sample images and every open gap.

The two checks are company checks: the company's CI runs them on every pull request. Logo processing and the board
are Asgard scripts that the agent runs. Every tool works offline after a one-time setup, and nothing it writes into
the company's repository names Ouroboric or any of its parts.

The founder answered the open questions on 2026-10-27; §9 records the answers and §12 the deviations they make.

**Amended 2026-10-28** by the change proposal
[Asgard's design system process](https://github.com/ouroboric-dev/yggdrasil/blob/main/docs/2-engineering/changes/2026-10-27-asgard-design-system/proposal.md):
step 6 runs as seven sub-steps (design §6.1), so the tools gain typeface candidates, palette rounds, logo preparation
and proposals, a playground and a reference; `brand.py` gains checks and accepted exceptions (§3.1); the board shows
more (§5.4); and §5.5 to §5.8 are new. "Where they run" is now §5.9.

The tools build on what Asgard already holds:

- [`templates/company/core/docs/7-branding/identity/README.md`](https://github.com/ouroboric-dev/asgard/blob/main/templates/company/core/docs/7-branding/identity/README.md)
- [`templates/company/core/docs/7-branding/identity/tokens.json`](https://github.com/ouroboric-dev/asgard/blob/main/templates/company/core/docs/7-branding/identity/tokens.json)
- [`templates/company/core/docs/7-branding/identity/logo/README.md`](https://github.com/ouroboric-dev/asgard/blob/main/templates/company/core/docs/7-branding/identity/logo/README.md)
- [`templates/company/core/.ouroboric/checks/run.sh`](https://github.com/ouroboric-dev/asgard/blob/main/templates/company/core/.ouroboric/checks/run.sh)
- [`templates/company/core/.ouroboric/mkdocs.yml`](https://github.com/ouroboric-dev/asgard/blob/main/templates/company/core/.ouroboric/mkdocs.yml)
- [`scripts/company-site.sh`](https://github.com/ouroboric-dev/asgard/blob/main/scripts/company-site.sh)
- [`templates/readiness/checklist.md`](https://github.com/ouroboric-dev/asgard/blob/main/templates/readiness/checklist.md)

## 2. Architecture and components

```text
asgard leaf (AGPL-3.0)
├── scripts/brand.sh            setup | logo DIR | board [--check] DIR
├── scripts/brand/              logo.py, board.py, requirements.txt (hashed pins), resvg.lock (URL and SHA-256 per platform)
└── scripts/tests/              brand.test.sh, brand-checks.test.sh

a company repository (from templates/company, MIT)
├── .ouroboric/checks/brand.py  contrast | fonts | tokens [--write] | board-fresh | check
├── .ouroboric/checks/run.sh    gains the step "brand: contrast, fonts, generated files"
├── .ouroboric/mkdocs.yml       gains extra_css: 7-branding/identity/fonts.css
└── docs/7-branding/identity/
    ├── tokens.json             the source: palettes and fonts (written by the agent from her choices)
    ├── tokens.css, fonts.css   generated from tokens.json and the font files
    ├── fonts/<family>/         font files as published, with the licence file they came with
    ../imagery/                 up to six sample images she chooses, and imagery.md's record for each (§4.4)
    ├── board.md                generated: the brand board, plain Markdown
    ├── board/                  generated: the board's images (palette panels, logo on each background, type specimens)
    └── logo/
        ├── source/             her PNGs, committed: logo.png (light backgrounds), logo-dark.png (dark), mark.png (optional square mark)
        ├── logo.svg, logo-dark.svg, mark.svg, mark-dark.svg (with a mark), favicon.svg, favicon.ico, icon-192.png, icon-512.png
        ├── trace-light.png, trace-dark.png   generated: where the trace differs from her PNG
        └── trace.json          generated: the faithfulness result, the colour mapping and the gaps
```

The checks live in the company template so the company's CI runs them with no Asgard code. The board script reads
their results with `brand.py contrast --json` and `brand.py fonts --json`, so each rule has one implementation.

### 2.1 Dependencies

| Tool | Version | Licence | Used for | Pinning |
| --- | --- | --- | --- | --- |
| Python | 3.10 or later | PSF-2.0 | every tool; the contrast check needs only the standard library | the CI's `setup-python` (3.11) |
| [VTracer](https://github.com/visioncortex/vtracer) (PyPI `vtracer`) | 0.6.15 (2026-03-23) | [MIT](https://github.com/visioncortex/vtracer/blob/0.6.15/LICENSE) | tracing | `requirements.txt`, exact version and `--hash` |
| [Pillow](https://python-pillow.org) | 12.3.0 (2026-07-01) | MIT-CMU (PyPI metadata) | PNG reading, alpha cleanup, comparison, ICO and PNG export | same |
| [fontTools](https://github.com/fonttools/fonttools) | 4.66.1 (2026-09-29) | MIT | font `name` and `OS/2` tables | same; also in the company's `checks.yml` |
| [Brotli](https://github.com/google/brotli) | 1.2.0 (2025-11-05) | MIT | WOFF2 reading for fontTools | same |
| [resvg](https://github.com/linebender/resvg) CLI | 0.48.1 (2026-08-02) | [Apache-2.0 OR MIT](https://github.com/linebender/resvg/blob/main/Cargo.toml) | SVG to PNG, for the faithfulness check and the icons | release binary (`linux-x86_64`, `macos-aarch64`, `macos-x86_64`), SHA-256 in `resvg.lock` |
| MkDocs, Material for MkDocs | 1.5.3, 9.2.7 | BSD, MIT (PyPI classifiers) | renders the board with the other pages | unchanged from the template |

Every version is a release at least two weeks old, as the template's lint pins are. Newer releases exist (Pillow
13.0.0, fontTools 4.67.0, Brotli 1.2.1) but are younger than two weeks today. Every licence in the table is
permissive, so Asgard's AGPL-3.0 scripts can call each tool. The tools run on the founder's files, and their output
carries none of their code: the one mark a tool leaves, VTracer's generator comment, is removed (§5.3).

## 3. Interfaces and contracts

### 3.1 `brand.py` (company check)

```text
.ouroboric/checks/brand.py contrast [--json]    the palette pairs (§5.1)
.ouroboric/checks/brand.py fonts [--json]       the font licence evidence (§5.2)
.ouroboric/checks/brand.py tokens [--write]     tokens.css and fonts.css from tokens.json; without --write, fail when stale
.ouroboric/checks/brand.py board-fresh          board.md matches its inputs (§5.4)
.ouroboric/checks/brand.py reference-fresh      identity/reference/ matches its inputs (§5.8)
.ouroboric/checks/brand.py check                all of them; run.sh runs this
```

Added by the design system process (the checks are in the task list as DS-T04):

- `brand.py` checks the **glyph coverage** of every shipped font for the clients' languages (read from `tokens.json`);
  the minimum body size in the type scale (16 px) and a body line height of at least 1.5; the focus colour at 3:1
  against `bg` and `surface` in both modes, at least 2 px thick; the touch target at least 24 px; and the foundation
  tokens present. The body face's italic and each role's weights are read from the font files (`fvar`, `OS/2`), never
  from `tokens.json`.
- `brand.py` reads `accepted` in `tokens.json`: entries of check id, value, reason, by and date. A failure whose check
  id and value match an entry is reported as **accepted**, not as a failure, and does not stop the build. An entry
  whose value no longer matches is reported as **stale**, and the check fails again. An exception names one check on
  one value.

Each finding prints as `path: what is wrong`, like `docs-check.py`. Exit codes: 0 when every check passes, 1 when a
check has a finding, 2 when it cannot run (for example, `tokens.json` is not valid JSON). `--json` prints one object
per pair or font, with its result, for the board.

### 3.2 `brand.sh` (Asgard script)

```text
brand.sh setup               install the pinned tools into the cache; the only command that uses the network
brand.sh logo DIR            trace, recolour, derive, export and check the logo of the company in DIR
brand.sh board [--check] DIR write DIR/docs/7-branding/identity/board.md; --check fails when it is stale
brand.sh fonts DIR CANDIDATES.json            fetch candidate typefaces and write the facts the typography page shows
brand.sh palette DIR ROUND.json               render a palette round, each palette checked before it is shown
brand.sh logo-prep DIR IMAGE                  cut out, flatten and enlarge the founder's concept
brand.sh logo-proposals DIR CANDIDATES.json   the logo review page; writes the chosen design to logo/source/
brand.sh playground DIR                       the playground as one self-contained page (§5.6)
brand.sh reference DIR                        write identity/reference/ (§5.8)
```

- `setup` creates a virtual environment under `${XDG_CACHE_HOME:-$HOME/.cache}/asgard/brand/<key>`, where `<key>` is
  a hash of `requirements.txt` and `resvg.lock`. It runs `pip install --require-hashes --only-binary :all:`. It
  downloads the resvg binary for the platform and refuses it when its SHA-256 differs from `resvg.lock`.
- `brand.sh fonts DIR`: fetches three to five candidate typefaces from an open library (each with its licence
  file, from the Google Fonts repository's `ofl/<family>/`), reads each face's facts from the file (family name,
  weights from `fvar`, italic from a sibling italic file or an `ital` axis, glyph coverage), and renders a specimen of
  each with the company's name, tagline and about text, in its languages. A face without an italic is reported
  without one, whatever the candidates file says.
- `brand.sh palette DIR ROUND.json`: renders a palette round (light and dark, the logo applied). It checks every
  preset with `brand.py`'s rules before it is shown, and refuses a failing preset with the failing pairs named.
- `brand.sh logo-prep DIR IMAGE`: cuts out the founder's concept, removes a flat background, flattens anti-aliased
  edges to the logo's flat colours, and raises the resolution so that the short side is at least 1000 px and a mark
  at least 2400 px.
- `brand.sh logo-proposals DIR CANDIDATES.json`: renders the concept and the agent's alternatives as a review page (a
  panel per alternative with Strength and Risk, the logo at 16, 24, 32 and 48 px and the mark at 16, 32 and 64 px
  with an enlarged 16, each in its own light and dark row), each alternative set in every candidate typeface of the
  candidates file (grouped serious and stylised, each with its licence and a poor-fit note per alternative where one
  applies), and writes the chosen design as `logo/source/` PNGs in neutral colours for the palette to recolour, with
  the chosen typeface recorded for the wordmark role.
- `logo` and `board` refuse to run when the environment for the current `<key>` is missing, and name `setup`.
- Exit codes follow `company-site.sh`: 0 done, 2 refused (usage, missing setup, an input refused). A gap is not a
  failure: `logo` prints it, records it in `trace.json`, and exits 0.

### 3.3 How step 6 uses them

1. The agent writes her palette and font choices into `tokens.json`. It copies each font's folder, unchanged, from
   its publisher into `fonts/<family>/`.
2. The agent runs `brand.py tokens --write`, then `brand.py check`, and resolves each finding with her.
3. The agent saves her PNGs in `logo/source/` and runs `brand.sh logo`. When `trace.json` proposes brand tokens
   (§5.3), the agent adds the ones she accepts to `tokens.json` and runs `brand.sh logo` again.
4. The agent copies the sample images she chooses into `docs/7-branding/imagery/` and records each one in
   `imagery.md` (§4.4).
5. The agent runs `brand.sh board`, then `run.sh`, and opens the pull request for the `brand` stop.
6. The agent asks her to merge only when `run.sh` passes. While it fails, the agent resolves the findings with her
   first.
7. She opens `board.md` from the pull request in GitHub's file view, which the agent links, and approves by merging
   (design §6.2).

Each tool writes only its generated files and never edits a document a person wrote. Running a step again gives the
same files from the same inputs.

## 4. Data model

### 4.1 `tokens.json` (changed)

The colour keys stay as the template has them: `bg`, `surface`, `border`, `text`, `muted`, `accent`, `accent-text`,
`on-accent`, `ok`, `warn`, `crit`, in `light` and in `dark`. Each value is `#RRGGBB` (opaque) or `null` before step 6.

A palette MAY add brand tokens, `brand-1`, `brand-2` and so on, for logo colours that no other token holds (§5.3).
A brand token MUST have a value in both `light` and `dark`. Brand tokens are for the logo only.

Each font role gains the evidence the font check reads. `type.licence` is removed.

```json
"heading": {
  "family": "Literata",
  "fallback": "Georgia, serif",
  "weights": [600, 700],
  "files": "fonts/literata",
  "licence": "OFL-1.1",
  "source": "https://github.com/google/fonts/tree/main/ofl/literata"
}
```

- `files` is a folder relative to `identity/`, or `null` for a font the products do not ship (the reader's device
  supplies it).
- `licence` is an SPDX id. `source` is where the folder came from, for the person who reads a flag.
- `licence_review: {"by": "<name>", "date": "YYYY-MM-DD"}` is optional. It records that a person read a licence the
  check flagged (§5.2). The person is the founder, or someone she names. The tools record the name; they cannot
  check who it is.

### 4.2 `trace.json` (generated)

```json
{
  "inputs": {"source/logo.png": "sha256:..."},
  "tracer": {"name": "vtracer", "version": "0.6.15", "params": {"colormode": "color", "hierarchical": "stacked"}},
  "modes": {
    "light": {"from": "given", "mismatch": 0.004, "inner_mismatch_px": 0, "colour_delta": 0.006,
              "colours": [{"traced": "#1B1B1B", "token": "text", "value": "#1A1A1A", "delta": 0.003}]},
    "dark": {"from": "derived", "colours": [{"token": "text", "value": "#EDEFF3"}]}
  },
  "proposed_brand_tokens": [{"traced": "#C2185B", "light": "#C2185B", "dark": "#F06292"}],
  "gaps": [{"what": "a detail of the logo is lost", "where": "trace-light.png"}],
  "faithful": false
}
```

The readiness check script reads `faithful` and `gaps` as evidence for RB-21. That script is not in this spec.

### 4.3 `tokens.css` and `fonts.css` (generated)

- `tokens.css` holds the light values in `:root`, the dark values in `@media (prefers-color-scheme: dark)` and in
  `:root[data-theme="dark"]`, and one `--font-<role>` stack for each role, and the foundation variables (`--space-*`, `--radius-*`, `--shadow-*`, `--motion-*`, `--focus-*`).
- `fonts.css` holds one `@font-face` for each shipped font file, with `font-display: swap`. Each `url()` is relative to
  `fonts.css`, so the browser resolves it on any page and on any host. It serves WOFF2, converted from the shipped
  font and subset to the clients' languages (fontTools with the Brotli module); the original file stays as the
  licence's evidence.
- Each file opens with a comment that says it is generated from `tokens.json` and must not be edited.

### 4.4 Sample images in `imagery.md`

`imagery.md` gains a table, written by the agent with her:

```markdown
## Sample images

| File | Shows a person | Consent |
| --- | --- | --- |
| wedding-rings.jpg | no | |
| portrait-ana.jpg | yes | confirmed by the founder, 2026-11-02 |
```

`File` names an image in `docs/7-branding/imagery/`. `Shows a person` is `yes` or `no`, as she says. `Consent` is
filled when a person appears. The tools read the table; they never judge whether a person appears in an image.

## 5. Features and acceptance criteria

### 5.1 The contrast check

The check computes each ratio with the WCAG 2.2 definitions of
[relative luminance and contrast ratio](https://www.w3.org/TR/WCAG22/#dfn-relative-luminance) (the sRGB threshold
is 0.04045). It compares the ratio with the minimum unrounded, as the
[Understanding document for 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) says
(4.499:1 does not meet 4.5:1).

| Foreground | Background | Kind | Minimum | Source |
| --- | --- | --- | --- | --- |
| `text`, `muted`, `accent-text` | `bg`, `surface` | text | 4.5:1 | [SC 1.4.3](https://www.w3.org/TR/WCAG22/#contrast-minimum) |
| `on-accent` | `accent` | text | 4.5:1 | SC 1.4.3 |
| `ok`, `warn`, `crit` | `bg`, `surface` | text | 4.5:1 | SC 1.4.3 |
| `accent` | `bg`, `surface` | shape | 3:1 | [SC 1.4.11](https://www.w3.org/TR/WCAG22/#non-text-contrast) |
| `border` | `bg`, `surface` | decorative | none: reported only | — |

Brand tokens are reported against `bg` in each mode, for information only: text that is part of a logo has no
contrast requirement (SC 1.4.3, "Logotypes"). §5.3 records a gap when the logo itself would be hard to see.

Status colours carry messages, such as an error, so they are checked as text. Text pairs also report whether they
meet the enhanced level, 7:1 ([SC 1.4.6](https://www.w3.org/TR/WCAG22/#contrast-enhanced)), for information.

1. The check MUST test each pair in the table in the light palette and in the dark palette.
2. The check MUST use the WCAG 2.2 formula for relative luminance, with the threshold 0.04045.
3. The check MUST NOT round a ratio before it compares the ratio with the minimum.
4. A pair below its minimum MUST fail the check.
5. A failure MUST name the mode, the two tokens, the ratio and the minimum.
6. The output MUST show each ratio rounded down to two decimals.
7. A colour value that is not `#RRGGBB` MUST fail the check.
8. When all colour values are `null`, the check MUST pass and say that the palette is not set.
9. When only some colour values are `null`, the check MUST fail and name each missing token.
10. `#767676` text on a `#FFFFFF` background MUST pass (4.54:1). `#777777` MUST fail (4.47:1).
11. A brand token MUST NOT fail the check by its contrast. A brand token with a value in one mode only MUST fail it.

### 5.2 The font licence check

For each font role with a `family`, the check reads the evidence in its `files` folder:

- the licence file (`OFL.txt`, `UFL.txt`, `LICENSE*` or `LICENCE*`). The check knows three licences by their text:
  SIL Open Font License 1.1 (`OFL-1.1`, "SIL OPEN FONT LICENSE Version 1.1"), Apache License 2.0 (`Apache-2.0`,
  "Apache License" and "Version 2.0, January 2004") and Ubuntu Font Licence 1.0 (`UFL-1.0`, "UBUNTU FONT LICENCE
  Version 1.0"). These are the licences of the Google Fonts library's folders `ofl/`, `apache/` and `ufl/`.
- each font file (`.ttf`, `.otf`, `.woff`, `.woff2`): the family name (`name` IDs 16 and 1), the licence description
  and URL (`name` IDs 13 and 14), and the embedding flags (`OS/2.fsType`). The
  [OS/2 table](https://learn.microsoft.com/en-us/typography/opentype/spec/os2#fstype) defines usage values 0
  (installable), 2 (restricted), 4 (preview and print) and 8 (editable), bit 8 (no subsetting) and bit 9 (bitmap
  embedding only).

Each font gets one of three results:

| Result | When |
| --- | --- |
| **known open licence** | the licence file is one of the three, `licence` names the same one, and every font file agrees |
| **needs a person** | the licence file is not one of the three; or `fsType` has usage 2 or 4, or bit 9; or `name` ID 13 or 14 names another licence or a limit such as "personal use", "non-commercial", "demo", "trial" or "evaluation" |
| **missing evidence** | `files` does not exist or holds no font file; there is no licence file or more than one; `licence` differs from the licence file; or a font file's family differs from `family` |

A font with `files: null` is reported as not shipped and needs no licence evidence.

1. The check MUST give each font with a `family` exactly one result from the table.
2. Missing evidence MUST fail the check.
3. "Needs a person" MUST fail the check while the font has no `licence_review`.
4. A font with a `licence_review` MUST be reported as "read by `<name>` on `<date>`: this is their reading".
5. When `fsType` restricts use or `name` ID 13 or 14 names a limit, the report MUST suggest that a qualified
   person reads the licence. A recorded review still clears the check.
6. The check MUST NOT report a reviewed font as a known open licence.
7. Every report MUST end with this sentence: "This check compares licence files and font data. It is not legal advice."
8. The check MUST NOT use the words "legal", "allowed" or "permitted" about a font.
9. The tools MUST NOT change a font file.

### 5.3 Logo processing

**Inputs.** She brings one PNG or one per mode (design §8), and MAY add a square mark. `logo/source/logo.png` is for
light backgrounds; `logo/source/logo-dark.png` is for dark backgrounds; `logo/source/mark.png` is an optional square
mark for the favicon and the app icons, used in both modes. Her PNGs are committed: they are inputs she made, not
generated rasters, and re-runs and the faithfulness check need them. `logo` refuses an input, with a sentence the agent can relay,
when it:

- is not a PNG (checked by its first bytes, not its name);
- is larger than 8192 pixels on a side, or smaller than 512 pixels on its short side;
- is `mark.png` and is not roughly square: its width divided by its height is under 0.8 or over 1.25;
- has no transparent background: fewer than 20% of the pixels on its outer rows are transparent. VTracer takes
  transparency out of the trace at the same 20% rule
  ([`converter.rs`](https://github.com/visioncortex/vtracer/blob/0.6.15/cmdapp/src/converter.rs), `KEYING_THRESHOLD`).

It records a gap, and goes on, when the short side is under 1000 pixels or the PNG holds more than eight main
colours (each covering at least 0.5% of the logo's pixels), which shows gradients or a photo rather than flat colours.

**Trace.** Pixels with alpha under 128 become transparent and the others opaque. VTracer traces the result with
fixed settings: `colormode="color"`, `hierarchical="stacked"`, `mode="spline"`, `filter_speckle=4`,
`color_precision=6`, `layer_difference=16`, `corner_threshold=60`, `length_threshold=4.0`, `max_iterations=10`,
`splice_threshold=45`, `path_precision=3`. The stacked mode layers the colour regions, so no gap opens between two
colours.

**Faithfulness.** For each given PNG, the mark included, resvg renders the traced SVG, before recolouring, at the
PNG's size. Then:

- **shape:** the pixels whose opaque or transparent state differs, divided by the PNG's opaque pixels, MUST be 1% or
  less;
- **detail:** after the differing pixels within 2 pixels of an edge are removed (a 5 by 5 minimum filter), differing
  pixels MUST NOT remain. This catches a lost dot or a filled hole that the shape ratio hides;
- **colour:** for each traced colour, the mean OKLab distance from her PNG's pixels inside that region MUST be 0.02 or
  less.

These limits are first values. The plan's first task tunes them on the test fixtures and on a real logo from the acceptance run (design §9), and a
change to them is a change proposal. A failed limit is a gap: `trace.json` records it, `trace-<mode>.png` shows the
differing pixels in `crit` over a faded copy of her PNG, and the board shows both.

**Recolour and derive.** Each traced colour maps to the nearest colour token of the same mode, by OKLab distance.

- With one PNG, the other mode uses the dark (or light) value of the same tokens. A white shape inside a dark mark
  maps to `bg`, so it follows the background in the other mode.
- With two PNGs, each is traced and mapped in its own mode. Nothing is derived.
- A traced colour farther than 0.05 from every token, brand tokens included, becomes a proposed brand token in
  `trace.json`: its light value is the traced colour, and its dark value keeps the hue and chroma and takes the
  nearest OKLab lightness that reaches 3:1 against the dark `bg` (the other way round for a dark PNG). The agent adds
  each proposal she accepts to `tokens.json`, and the next run maps the colour to it.
- Until then, the colour is kept unchanged in both modes and recorded. When a kept colour is under 3:1 against `bg`
  of a mode, that is a gap: "the logo may be hard to see on dark backgrounds".

**Exports.**

| File | Content |
| --- | --- |
| `logo.svg`, `logo-dark.svg` | the recoloured traces for light and dark backgrounds |
| `mark.svg`, `mark-dark.svg` | with `mark.png`: the recoloured mark for light and dark backgrounds |
| `favicon.svg` | the mark, or else the logo, fitted into a square, light colours, with a `prefers-color-scheme: dark` style that switches to the dark colours |
| `favicon.ico` | 16, 32 and 48 pixels, each rendered by resvg at its own size, transparent background |
| `icon-192.png`, `icon-512.png` | the light logo on the light `bg`, opaque, inside the maskable safe zone: a centred circle with a radius of 40% of the icon ([Web App Manifest §2.3](https://www.w3.org/TR/appmanifest/#icon-masks)) |

The favicon and the icons come from the mark when she brings one, and from the logo otherwise. Without a mark, a logo
wider than 1.5 times its height gives a hard-to-read favicon: that is a gap.

1. `logo` MUST refuse each input that §5.3 lists, with exit code 2 and a plain sentence.
2. `logo` MUST trace with VTracer 0.6.15 and the fixed settings in §5.3.
3. `logo` MUST compute the shape, detail and colour results for each given PNG, the mark included.
4. A failed limit MUST be a gap in `trace.json` and on the board.
5. `logo` MUST NOT change or remove a gap to make the trace look faithful.
6. With one PNG, `logo` MUST derive the other mode from the same tokens.
7. With two PNGs, `logo` MUST NOT derive a mode.
8. With `mark.png`, the favicons and the icons MUST come from the mark, and the wide-logo gap MUST NOT apply.
9. A traced colour with no token within 0.05 MUST be proposed as a brand token in `trace.json`.
10. `logo` MUST NOT write `tokens.json`.
11. Each SVG MUST hold only the elements `svg` and `path`. `favicon.svg` MAY also hold one `style` element.
12. Each SVG MUST hold a `viewBox` and no comment, script, link or external reference.
13. `favicon.ico` MUST hold the sizes 16, 32 and 48.
14. Each PNG icon MUST be opaque, and its logo MUST be inside the safe-zone circle.
15. Two runs on the same inputs MUST write byte-identical files.
16. `logo` MUST NOT write outside `docs/7-branding/identity/logo/`.

VTracer writes a comment that names itself (`<!-- Generator: visioncortex VTracer ... -->`,
[`svg.rs`](https://github.com/visioncortex/vtracer/blob/0.6.15/cmdapp/src/svg.rs)) and sets no `viewBox`. Criteria 8
and 12 remove and add these.

### 5.4 The brand board

`brand.sh board` writes `docs/7-branding/identity/board.md`, a page of the company's docs. It shows, in order:

1. **Palette:** `board/palette-light.svg` and `board/palette-dark.svg`, each a panel on its mode's `bg` with one
   swatch per token, its name and its value. Under each panel, the contrast table: each pair, its ratio, its minimum
   and "passes" or "fails" in words, never by colour alone.
2. **Type:** for each role, `board/type-<role>.png`, a specimen that resvg renders from the shipped font files in
   each weight, and the licence result in words. A role with no shipped files shows its family and fallback in words.
3. **Logo:** her PNG, then `board/logo-on-light.svg` and `board/logo-on-dark.svg` (each SVG on its mode's `bg`), and
   the mark the same way when she brought one. Then the colour mapping and any proposed brand token, the favicon at
   16, 32 and 48 pixels, and the icons inside a circle mask. Then "Faithful", or each gap with its numbers and
   `trace-<mode>.png`.
4. **Sample images:** up to six images from `docs/7-branding/imagery/`, each with its record from `imagery.md`, and
   `board/palette-strip.svg` under them.
5. **Open items:** every gap, every font that needs a person, every proposed brand token not yet in `tokens.json`,
   and every sample image with no record or with a person and no consent, in plain words.

The design system process adds to the board, after the parts above: each role in its typeface at its scale size; the
foundations; a component sheet (button, link, field, card, message) in both modes, built from the component recipes of
§5.5, with the message colours kept off the board; logo usage (clear space as the mark's width on every side, the
minimum sizes of the logo and of the mark, and the misuses, each misuse on its own tile); the kept exceptions with
their reasons; and the applications (a square profile picture from the mark, a link preview image of 1200 × 630
pixels, an email signature with a double-resolution logo). A hard-edged shadow is blurred in print. The board is
generated only from the playground's saved settings (§5.6).

**Rendering.** The founder reviews the board in GitHub's own file view, from the pull request, until a private
preview exists. So the board is plain Markdown: headings, paragraphs, lists, tables and images in Markdown image
syntax, with no HTML. Everything that needs colour or a font is a generated image in `board/`, because GitHub's file
view shows images but no styles or web fonts. The strict build checks each image link. The page uses relative links
only, no script and no external URL, so it reads the same in GitHub's file view, through `company-site.sh` on
127.0.0.1, and on any static host later. Hosting a private preview is not in this spec.

**No tool names.** The board's fixed text is plain English with no tool names. It opens with a comment that says it is
generated and must not be edited, and a SHA-256 of its inputs: `tokens.json`, `fonts.css`, the font files, the files
in `logo/`, the sample images and `imagery.md`.

1. `board` MUST show the five parts in the order of §5.4.
2. The board MUST show the light and the dark palette at the same time.
3. Each result MUST be in words. Colour MUST NOT be the only sign of a result.
4. The board MUST use no script, no external URL and no absolute link.
5. The company's docs MUST build with `mkdocs build --strict` after `board` runs.
6. `names-check.sh` MUST pass on a company after `logo` and `board` run.
7. `board --check` and `brand.py board-fresh` MUST fail when an input changed after `board` ran.
8. `brand.py board-fresh` MUST pass on the template's placeholder board, which has no input hash.
9. `board.md` MUST hold no HTML element.
10. Each image in `board/` MUST be an SVG of the elements of §5.3 plus `rect`, `g` and `text`, or a PNG.
11. `board` MUST refuse, with exit code 2 and a plain sentence, more than six sample images or one longer than 1600
    pixels on its long side.

### 5.5 The token contract

The names and meanings a product theme maps from `tokens.json`, written for the product realms to read. Every key
below is in `tokens.json`; `brand.py tokens --write` turns each into the CSS custom property named beside it in
`tokens.css`, and the reference stylesheet (§5.8) reads only those properties. A product maps its theme from the
properties, not from the JSON. The realm side is the change proposal 2026-10-27-product-ui-from-design-system.

A key MAY be `null` before step 6 sets it; a key that is set MUST have the type and unit below. A missing foundation
is a finding of `brand.py` (§3.1).

#### Colours

`light` and `dark` each hold the same keys, every value `#RRGGBB`. The property carries the light value in `:root`
and the dark value under `prefers-color-scheme: dark` and `:root[data-theme="dark"]` (§4.3).

| Key | Property | Meaning |
| --- | --- | --- |
| `bg` | `--color-bg` | the page background |
| `surface` | `--color-surface` | a raised or inset area on `bg`: cards, fields, the footer |
| `border` | `--color-border` | rules and outlines of surfaces |
| `text` | `--color-text` | body text, on `bg` and `surface` |
| `muted` | `--color-muted` | secondary text, on `bg` and `surface` |
| `accent` | `--color-accent` | the brand colour for fills and shapes: buttons, focus, selected state |
| `accent-text` | `--color-accent-text` | the brand colour as text on `bg` and `surface`: links, outlined buttons |
| `on-accent` | `--color-on-accent` | text on an `accent` fill |
| `ok`, `warn`, `crit` | `--color-ok`, `--color-warn`, `--color-crit` | message colours, as text on `bg` and `surface` |
| `brand-1`, `brand-2`, … | `--color-brand-1`, … | logo colours that no other token holds; for the logo only |

#### Type roles and scale

`type.fonts` holds one entry for each role: `wordmark` (the logo's lettering), `display` (the largest headline),
`heading`, `body` and `ui` (labels, buttons, fields, navigation). A role has the keys of §4.1 plus `weights`
(array of integers, the weights shipped) and, for `body`, `italic` and `emphasis` (`bold` or `italic`: how the
face marks emphasis). The property `--font-<role>` holds the family and its fallback as one stack.

`type.scale` sets the sizes:

| Key | Type and unit | Meaning |
| --- | --- | --- |
| `base` | number, px | the body size |
| `ratio` | number | the step between sizes |
| `minimum` | number, px | the smallest body size the company allows; at least 16 |
| `sizes` | object, px | `small`, `body`, `h3`, `h2`, `h1`, `display`; property `--text-<name>`, for example `--text-body` |
| `lineHeight` | object, unitless | `body`, `heading`, `display`; property `--leading-<name>`; `body` at least 1.5 |

#### Foundations

| Key | Type and unit | Property | Meaning |
| --- | --- | --- | --- |
| `space` | array of numbers, px, ascending | `--space-1` … `--space-n` | the spacing scale; every gap and padding is one step |
| `radius` | object, px | `--radius-sm`, `-md`, `-lg`, `-button` | corner radii: `sm` and `md` for fields and small parts, `lg` for cards, `button` for buttons |
| `elevation` | object of CSS `box-shadow` values | `--shadow-card`, `--shadow-overlay` | `card` for a raised card, `overlay` for what floats over the page |
| `motion` | object | `--motion-distance`, `--motion-duration`, `--motion-easing` | `distance` (px) and `duration` (ms) of an entrance, `easing` (a CSS timing function); `reduced` is `none` or `fade`: what a device that asks for reduced motion gets |
| `focus` | object | `--focus-color`, `--focus-width`, `--focus-offset` | `role` (a colour key, normally `accent`), `width` (px, at least 2) and `offset` (px) of the focus ring |
| `target` | number, px | `--target` | the smallest height of a thing a finger or pointer presses; at least 24 |
| `breakpoints` | array of numbers, px, ascending | `--bp-1` … `--bp-n` | the widths where the layout changes; a media query cannot read a property, so the reference stylesheet writes each value out and the contract names the order |

#### Components

`components` maps each component to the variant the founder chose. The recipes below say which tokens each part and
state of each variant uses. They are what the reference stylesheet (§5.8) builds, so a product that follows them
looks the same as the reference. A recipe names tokens, never a literal value. A state not listed is the base state.

States for every pressable part. **hover** lowers the part's brightness by 7%; **active** scales it to 0.97;
**focus-visible** draws an outline of `--focus-width` in `--focus-color` at `--focus-offset`; **disabled** sets 45%
opacity and the `not-allowed` cursor. Hover and active animate over `--motion-duration` with `--motion-easing`, and
not at all where `motion.reduced` is `none` and the device asks for reduced motion.

#### button

Variants `filled`, `outlined`, `soft`. Parts: the box has a border of 1.5 px in `--color-accent`, `--radius-button`, height
at least `--target`, horizontal padding `--space-4`, and its label in `--font-ui` at `--text-small`, weight 600.

| Variant | Background | Label | Border |
| --- | --- | --- | --- |
| `filled` | `--color-accent` | `--color-on-accent` | `--color-accent` |
| `outlined` | none | `--color-accent-text` | `--color-accent` |
| `soft` | `--color-accent` mixed 16% into `--color-bg` | `--color-accent-text` | the background's colour |

The secondary button is `outlined` whatever the primary variant.

#### link

Variants `underlined`, `colour`. The text is `--color-accent-text`. `underlined` always has an underline, offset 3 px;
`colour` has none and gains it on hover.

#### field

One variant. The label is above the control, in `--font-ui` at `--text-small`, weight 500, `--color-text`. The control is
at least `--target` high, with horizontal padding `--space-3`, background `--color-surface`, a 1 px border in `--color-border`,
`--radius-md`, its value in `--font-body` and `--color-text`, and its placeholder in `--color-muted`. On focus-visible the
control gets the focus outline. In error the border is `--color-crit` and the message beneath is `--color-crit`, weight 500.

#### card

Variants `bordered`, `surface`, `raised`. Padding `--space-3`, `--radius-lg`, the heading in `--font-heading` at
`--text-h3`, the body in `--font-body`.

| Variant | Background | Border | Shadow |
| --- | --- | --- | --- |
| `bordered` | `--color-bg` | 1 px `--color-border` | none |
| `surface` | `--color-surface` | none | none |
| `raised` | `--color-surface` | 1 px `--color-border` | `--shadow-card` |

#### message

Variants `tint`, `bar`; the colour `--c` is `--color-ok`, `--color-warn` or `--color-crit`. Padding `--space-2` and `--space-3`,
`--radius-md`, text at `--text-small`.

| Variant | Background | Text | Edge |
| --- | --- | --- | --- |
| `tint` | `--c` mixed 10% into `--color-bg` | `--c` | none |
| `bar` | `--color-surface` | `--c` | 3 px left border in `--c`, square on the left |

#### navigation

Variants `left` (the logo at the start, the links at the end) and `centre` (the logo centred, the links beneath).
Padding `--space-3` and `--space-4`, a 1 px bottom border in `--color-border`, links in `--font-ui` at `--text-small`,
weight 500, in `--color-text`; the current page's link in `--color-accent-text`. Each link is at least `--target` high.

#### image

Variants `borderless`, `rounded`, `framed`. `borderless` shows the image alone. `rounded` adds `--radius-md`.
`framed` adds a `--space-1` border in `--color-bg` (a print's margin) and a 1 px shadow, 3 px blur, of `--color-text` mixed 18%
into transparent, so the frame shows in both modes.

#### icon

Variants `outline`, `filled`. Size 22 px, colour `--color-accent-text`; an icon that stands alone is at least `--target`
square, with the icon centred. The icon set and its licence are RL-06 (design §8).

#### Exceptions

`accepted` is an array of objects: `check` (the check's id), `value` (the value that failed), `reason` (the founder's
words), `by` and `date`. A product reads it only to show a reviewer what the founder kept; the checks of §3.1 decide
when an entry applies or is stale.

### 5.6 The playground

`brand.sh playground DIR` writes the playground as one self-contained HTML file in the company's brand folder. It
needs no network at view time: the candidate typefaces are embedded, subset. It is generated from `tokens.json`, a
candidates file (palette presets and per-role values, typography looks and per-role faces, the wordmark included,
foundation candidates, component variants) and the company's check rules, so its live checks are the same rules as
`brand.py`. The page has tabs for palette, type, foundations, components and checks, and a sample site painted only
from tokens, in light and dark, at phone, tablet and desktop widths, with motion played. The logo is drawn from its
traced design, recoloured from the live palette, with its lettering set in the live wordmark face (per-face masks). A
failing check can be kept with a reason, which becomes an accepted exception. Its export is a token file that
`brand.py` validates before anything is applied, and it carries the checks still open. The founder opens it from a
link: GitHub's file view does not run it, so until a private preview exists (backlog B-202) the agent shares it
privately for viewing. It saves and reopens as every choice page does (§5.7).

### 5.7 The choice pages

The choice pages (`logo-proposals`, `palette`, `fonts`, `playground`) share four rules, one shared module and a test
for each:

1. The page saves the founder's confirmed choice and reason where the agent reads it, and reopens on it.
2. Every candidate's facts are read from the source at build time (a font's weights and italics from the font or its
   library, never typed by hand).
3. Every candidate face the page offers is shown to load before the page is shared (a headless browser lists
   `document.fonts` as loaded for each family). Font names in inline `style` attributes are single-quoted.
4. Every option the page offers visibly changes what it shows (in both modes, at phone, tablet and desktop widths),
   so no choice is blind: the test fingerprints the preview's computed styles per option, and two options with the
   same fingerprint fail. An option whose effect depends on another (a shadow that only a raised card shows) gets
   something that always shows it.

### 5.8 The reference

`brand.sh reference DIR` writes `identity/reference/` from `tokens.json`: `components.css` (every recipe and variant,
only `var(--…)` from `tokens.css`), `playground.html` (self-contained, without saving) and the screenshots (light and
dark; 390, 820 and 1280 pixels wide), rendered by a pinned headless browser. `brand.py` reports the reference as stale
when its inputs change, as it does the board.

### 5.9 Where they run

| Tool | Agent, at step 6 | Company CI (`run.sh`) | Asgard CI (`ci.yml`) |
| --- | --- | --- | --- |
| contrast check | `brand.py contrast` | yes, in `brand.py check` | through `brand-checks.test.sh` |
| font licence check | `brand.py fonts` | yes; `checks.yml` installs `fonttools[woff]==4.66.1` and `brotli==1.2.0` | same |
| generated files fresh | `brand.py tokens --write` | yes | same |
| logo processing | `brand.sh logo` | no: it writes files | through `brand.test.sh` |
| brand board | `brand.sh board` | freshness only (`board-fresh`) | through `brand.test.sh` |

1. `run.sh` MUST run `brand.py check` as one step.
2. A fresh scaffold MUST pass `run.sh`.
3. `brand.sh logo` and `brand.sh board` MUST NOT open a network connection.
4. A file the tools write under `.ouroboric/` MUST NOT name an internal part of the factory (Asgard, Yggdrasil, a
   component, a realm or a script by its path), except in a setting that is for that part.

## 6. Template changes

- `tokens.json`: `files`, `licence` and `source` per font; `type.licence` removed (§4.1).
- `tokens.css`, `fonts.css`: placeholder comments, replaced by `brand.py tokens --write`.
- `imagery.md`: the sample images table (§4.4), empty.
- `identity/board.md`: a placeholder page ("The brand board appears here once the palette, the fonts and the logo
  are in."), linked from `identity/README.md`.
- `logo/README.md`: the source files (her PNGs, committed, and the optional square mark) and the generated files of §2.
- `.ouroboric/mkdocs.yml`: `extra_css: [7-branding/identity/fonts.css]`.
- `.ouroboric/checks/brand.py`, the `run.sh` step, and the `checks.yml` install line.

## 7. Security considerations

- **Untrusted input.** Her PNG can come from anywhere. `logo` checks the PNG signature and the size before Pillow
  decodes the image, so a decompression bomb is refused.
- **Safe SVG output.** The SVGs hold only the elements of §5.3, with no script and no external reference, so a page
  or a product can inline them.
- **Supply chain.** Python packages install from wheels only, with hashes. The resvg binary is checked against its
  SHA-256. Nothing installs globally. Updates arrive as pull requests that change `requirements.txt` or `resvg.lock`.
- **Offline.** After `setup`, no tool uses the network. The checks read only the repository's files.
- **Privacy.** Her logo and sample images stay in her private repository and on the machine that runs the tools.
  `company-site.sh` serves the board on 127.0.0.1 only.
- **No secrets.** No tool reads or needs a token.

## 8. Testing approach

Test first, in bash, like the existing `scripts/tests/*.test.sh`. Each test scaffolds a company with
`new-company.sh` in a temporary folder.

- `brand-checks.test.sh` covers §5.1, §5.2 and the freshness rules. It writes palettes with known ratios
  (criterion 5.1.10). It builds test fonts with fontTools' `FontBuilder`, with the `name` and `fsType` values each
  case needs, and writes short licence files. No font file is committed.
- `brand.test.sh` covers §5.3 and §5.4. It draws its PNG fixtures with Pillow: a two-colour mark that traces
  faithfully, a mark with a 3-pixel dot that `filter_speckle` drops (a gap), a wide wordmark, an opaque background,
  an image that is too small, a square mark, a mark that is not square, and a logo colour far from every token. It checks the files, `trace.json` and its proposed brand tokens, the strict build, `names-check.sh`,
  that `board.md` holds no HTML, byte-identical re-runs, and `board --check` after a token changes.
- Criterion 5.9.3 is checked in two ways: `brand.py`, `logo.py` and `board.py` import no network module (`socket`,
  `urllib`, `http`), and resvg does not fetch external resources
  ([resvg README](https://github.com/linebender/resvg/blob/main/README.md): no `a` or `script` elements).
- Asgard's `ci.yml` runs `brand.sh setup` before the tests. The pr-bot cannot change workflows, so the operator
  pushes that change.
- CI runs on Linux only. VTracer wheels and resvg binaries exist for macOS, but the shared MacBook is not tested in
  CI.

## 9. Decisions

**Decided 2026-10-26:** VTracer 0.6.15 (MIT) traces the logo. It traces colour images in one pass, and its stacked
mode leaves no gaps between colours. Potrace 1.16 (GPL-2.0-or-later, last release 2019-09-17) traces black and white
only: each colour would need its own trace and our own colour separation, and separate traces leave hairline gaps.
AutoTrace (GPL-2.0, last release 0.31.10 in January 2024) is less active. Inkscape's Trace Bitmap uses Potrace inside
a desktop application. imagetracerjs (Unlicense) has had no change since 2023. Each licence would allow running the
tool. The choice rests on colour, gaps and maintenance.

**Decided 2026-10-26:** The stable VTracer 0.6.15 is pinned, not the 1.0 alphas. VTracer 1.0 adds `--palette`, which
snaps colours to given values during the trace. A later change can adopt it when 1.0 is stable.

**Decided 2026-10-26:** resvg renders SVG to PNG. It is a single binary with no system libraries, and it has no
script support.

**Decided 2026-10-26:** The contrast and font checks are company checks in the template, so the company's CI runs
them without Asgard. Logo processing and the board are Asgard scripts, because the design keeps Asgard outside her
repository (§6.1) and they write files.

**Decided 2026-10-26:** Status colours are checked as text (4.5:1). Borders are decorative and only reported.

**Decided 2026-10-26:** A font flagged "needs a person" fails the check until a person's reading is recorded in
`tokens.json`. The check never says a licence allows a use.

**Decided 2026-10-26:** A trace that is not faithful does not stop the tools. It is a gap on the board, and she
decides at the `brand` stop.

**Decided 2026-10-26:** The board is a page of the company's docs, so every host of the docs shows it.

The founder answered the spec's open questions on 2026-10-27:

**Decided 2026-10-27:** Her source PNGs are committed in `logo/source/`. They are inputs she made, not generated
rasters, so the docs standard's rule on raw sources does not cover them.

**Decided 2026-10-27:** Sample images: up to six she chooses, at most 1600 pixels on the long side, in
`docs/7-branding/imagery/`. `imagery.md` records for each whether it shows a person and, if so, the consent. The tools
ask and record; they never judge.

**Decided 2026-10-27:** The tools accept an optional square mark, `mark.png`, for the favicon and the app icons.

**Decided 2026-10-27:** A logo colour that no token holds becomes a proposed brand token, with a light and a dark
value, which she accepts into the palette. The dark version of the logo can then be derived.

**Decided 2026-10-27:** The founder, or a person she names, records the reading of a flagged font licence. The check
suggests a qualified person when the licence restricts use.

**Decided 2026-10-27:** Until a private preview exists, she reviews the board in GitHub's file view, so the board is
plain Markdown with generated images.

**Decided 2026-10-27:** The agent asks her to merge at the `brand` stop only when `run.sh` passes.

**Decided 2026-10-27:** Files under `.ouroboric/` use generic wording. They name an internal part of the factory only
in a setting that is for that part.

## 10. Open questions for the founder

None. The founder answered seven on 2026-10-27 (§9).

## 11. Not in this spec

- Making the logo, the palette or the font choices: the founder's work, with the step 6 skill in Havamal.
- The step 6 kickstart skill and its eval.
- The readiness check script, which reads `trace.json` and the check results for RB-21.
- A hosted private preview, and the pull request's link to the rendered board.
- Converting or subsetting fonts for the web: the web realm's build, from the files as published.
- The full logo system and usage rules (RL-06, level 2).
- The moodboard of step 6.
- Prose checks (Vale) for the board's text.

## 12. Deviations from the design doc

The founder approved each on 2026-10-27.

- **A square mark** (design §8 takes one PNG or one per mode): an optional third PNG for the favicon and the icons.
- **Brand tokens** (design §8 recolours with the palette tokens): a logo colour that no token holds becomes a brand
  token with a light and a dark value, so the palette grows to hold it.
- **The board is plain Markdown** (design §6.2 says she reviews rendered pages): GitHub's file view is the rendered
  page until a private preview exists.

## 13. Not verified

- resvg's text rendering for the type specimens (`--use-font-file`), and which font formats it loads: TTF and OTF are
  expected; a WOFF or WOFF2-only font may need its specimen in words.
- That GitHub's file view shows the board's SVG and PNG images from a private repository as intended.

- The resvg binaries' SHA-256 values: the plan's first task records them in `resvg.lock` when it downloads them.
- resvg's output on the fixtures: this spec relies on its documentation; it was not run while writing.
- VTracer was run once on a generated two-colour PNG while writing: the transparent background was left out, the
  output was byte-identical across two runs, and the paths kept the two colours. The faithfulness limits are not yet
  measured. The 0.6.15 wheel writes "0.6.12" in its generator comment, which criterion 5.3.12 removes in any case.
