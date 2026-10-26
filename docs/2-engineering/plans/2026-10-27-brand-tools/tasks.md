---
title: Brand tools tasks
status: proposed
date: 2026-10-27
related: [plan.md, ../../specs/2026-10-26-brand-tools.md, ../../../1-product/design/2026-10-17-asgard-v0-design.md]
style: spec
---

# Brand tools tasks

> **For agentic workers:** implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Steps marked **founder** are done by the founder, never by an agent.

**Goal:** the tools of step 6 of the company kickstart. **Architecture:** spec §2. **Tech stack:** Python 3.11
(standard library for the contrast check; fontTools, Pillow and VTracer for the others), the resvg CLI, Bash for
`brand.sh` and the tests. **Spec:** [2026-10-26-brand-tools.md](../../specs/2026-10-26-brand-tools.md). Global
constraints and review focus: [plan.md](plan.md).

Criteria are cited as spec section and number: 5.1.4 is criterion 4 of §5.1.

## Tasks

### Task BT-T01: the spike

Confirms the facts the spec marks as not verified (§13) before the tools that need them are built. No product code.

**Files (in `asgard`):** Create `scripts/brand/resvg.lock` (one line per platform: URL and SHA-256).

**Acceptance criteria:**

- [ ] `resvg.lock` holds the SHA-256 of the resvg 0.48.1 release binary for `linux-x86_64`, `macos-aarch64` and
      `macos-x86_64`, each computed from the downloaded file.
- [ ] resvg renders a test SVG to PNG, and renders a `text` element with a TTF given by `--use-font-file`.
- [ ] VTracer 0.6.15, Pillow 12.3.0, fontTools 4.66.1 and Brotli 1.2.0 install from wheels on Python 3.11, and the
      result for the founder's Python 3.14 is recorded.
- [ ] VTracer traces the two-colour fixture faithfully under the limits of §5.3, and drops the 3-pixel dot.
- [ ] GitHub's file view shows an SVG and a PNG linked from a Markdown file in a private repository.
- [ ] Each result that differs from the spec names the section to amend, and the amendment is in a commit to the spec.

**Named test:** none (a spike); its results are in the pull request. **Layer:** `asgard`. **Size:** S. **Depends
on:** the spec accepted.

- [ ] **Step 1 (founder):** allow the download of the resvg release binaries from GitHub, if the agent's sandbox asks.
- [ ] **Step 2:** download the three binaries, record their SHA-256 in `resvg.lock`, and run the Linux one.
- [ ] **Step 3:** in a scratch virtual environment, install the four packages from wheels with Python 3.11 and 3.14.
- [ ] **Step 4:** draw the fixtures with Pillow, trace them with the settings of §5.3, and measure the three limits.
- [ ] **Step 5 (founder):** open the scratch repository's Markdown file in GitHub and say what it shows.

---

### Task BT-T02: the contrast check

**Files (in `asgard`):** Create `templates/company/core/.ouroboric/checks/brand.py` (`contrast`, `check`),
`scripts/tests/brand-checks.test.sh`. Modify `templates/company/core/.ouroboric/checks/run.sh` (the step "brand:
contrast, fonts, generated files"), `.github/workflows/ci.yml` (nothing new to install for this task).

**Acceptance criteria:**

- [ ] 5.1.1 to 5.1.11 hold, each with a test case, 5.1.10 with the two known ratios.
- [ ] `--json` prints one object per pair with its mode, tokens, ratio, minimum and result (spec §3.1).
- [ ] Exit codes: 0, 1 on a finding, 2 when `tokens.json` is not valid JSON.
- [ ] A fresh scaffold passes `run.sh` (5.5.2).

**Named test:** `scripts/tests/brand-checks.test.sh`. **Layer:** `asgard` (company template). **Size:** M.
**Depends on:** none.

- [ ] **Step 1:** write the test cases: the template's null palette passes; a full palette passes; each failing pair
      names mode, tokens, ratio and minimum; a partial palette names each missing token; a bad value fails; the
      known ratios; brand tokens are reported and never fail by contrast; a brand token in one mode fails.
- [ ] **Step 2:** run it and watch each case fail.
- [ ] **Step 3:** write `brand.py contrast` with the standard library only, and the `run.sh` step.
- [ ] **Step 4:** run every Asgard test, then open nothing yet: BT-T03 and BT-T04 join this branch.

---

### Task BT-T03: the font licence check

**Files (in `asgard`):** Modify `brand.py` (`fonts`), `templates/company/core/docs/7-branding/identity/tokens.json`
(spec §4.1: `files`, `licence`, `source` per role; `type.licence` removed), `templates/company/core/.github/workflows/checks.yml`
(install `fonttools[woff]==4.66.1 brotli==1.2.0`), `brand-checks.test.sh`.

**Acceptance criteria:**

- [ ] 5.2.1 to 5.2.9 hold, each with a test case: the three known licences, each "needs a person" trigger
      (licence file, `fsType` usage 2 and 4 and bit 9, `name` IDs 13 and 14 limits), each "missing evidence" case,
      `files: null`, a reviewed font, the qualified-person suggestion, the closing sentence, and no forbidden word.
- [ ] Test fonts are built at test time with fontTools' `FontBuilder`; no font file is committed.
- [ ] The template's `tokens.json` stays valid, and a fresh scaffold passes `run.sh`.

**Named test:** `scripts/tests/brand-checks.test.sh`. **Layer:** `asgard`. **Size:** M. **Depends on:** BT-T02.

- [ ] **Step 1:** write the cases, with a helper that builds a font with given `name` and `fsType` values.
- [ ] **Step 2:** run them and watch each fail.
- [ ] **Step 3:** write `brand.py fonts`, change `tokens.json` and `checks.yml`.
- [ ] **Step 4:** run every Asgard test.

---

### Task BT-T04: the generated files

**Files (in `asgard`):** Modify `brand.py` (`tokens [--write]`, `board-fresh`, `check` runs all four),
`templates/company/core/docs/7-branding/identity/tokens.css` and `fonts.css` (placeholders),
`templates/company/core/.ouroboric/mkdocs.yml` (`extra_css`), `brand-checks.test.sh`.

**Acceptance criteria:**

- [ ] `tokens --write` writes `tokens.css` and `fonts.css` as spec §4.3 says; without `--write` it fails when they
      are stale.
- [ ] `board-fresh` passes on the placeholder board (5.4.8) and fails when an input's hash differs (5.4.7).
- [ ] The strict page build passes with `extra_css`, and a fresh scaffold passes `run.sh`.
- [ ] Then: one pull request for BT-T02 to BT-T04, with every Asgard test passing.

**Named test:** `scripts/tests/brand-checks.test.sh`. **Layer:** `asgard`. **Size:** S. **Depends on:** BT-T03.

---

### Task BT-T05: `brand.sh setup`

**Files (in `asgard`):** Create `scripts/brand.sh` (`setup`), `scripts/brand/requirements.txt` (exact versions and
`--hash`), `scripts/tests/brand.test.sh`. Modify `.github/workflows/ci.yml` (run `scripts/brand.sh setup` before the
tests).

**Acceptance criteria:**

- [ ] `setup` builds the environment under `${XDG_CACHE_HOME:-$HOME/.cache}/asgard/brand/<key>` as spec §3.2 says,
      with `--require-hashes --only-binary :all:`, and refuses a resvg binary whose SHA-256 differs.
- [ ] `logo` and `board` refuse to run without the environment, and name `setup`.
- [ ] A second `setup` with the same pins does nothing.

**Named test:** `scripts/tests/brand.test.sh`. **Layer:** `asgard`. **Size:** S. **Depends on:** BT-T01.

---

### Task BT-T06: logo processing, the trace

**Files (in `asgard`):** Create `scripts/brand/logo.py`. Modify `brand.sh` (`logo`), `brand.test.sh`.

**Acceptance criteria:**

- [ ] 5.3.1 to 5.3.5 hold: each refusal of §5.3 (the mark's shape included) with exit code 2 and a sentence; the
      fixed VTracer settings; the three limits for each given PNG; a failed limit is a gap; gaps are never removed.
- [ ] `trace.json` matches spec §4.2, and `trace-<mode>.png` shows the differing pixels.
- [ ] Fixtures: a faithful two-colour mark, a mark whose 3-pixel dot is dropped (a gap), an opaque background, an
      image too small, a mark that is not square.

**Named test:** `scripts/tests/brand.test.sh`. **Layer:** `asgard`. **Size:** M. **Depends on:** BT-T05.

---

### Task BT-T07: logo processing, the outputs

**Files (in `asgard`):** Modify `scripts/brand/logo.py`, `brand.test.sh`.

**Acceptance criteria:**

- [ ] 5.3.6 to 5.3.16 hold: derive with one PNG and not with two; the mark makes the favicons and icons; a far
      colour is a proposed brand token; `logo` never writes `tokens.json`; the SVG elements, `viewBox` and no
      comment; the ICO sizes; opaque icons inside the safe zone; byte-identical re-runs; nothing written outside
      `logo/`.
- [ ] `names-check.sh` passes on the company after `logo` (5.4.6).
- [ ] Then: one pull request for BT-T05 to BT-T07.

**Named test:** `scripts/tests/brand.test.sh`. **Layer:** `asgard`. **Size:** M. **Depends on:** BT-T06.

---

### Task BT-T08: the brand board

**Files (in `asgard`):** Create `scripts/brand/board.py`. Modify `brand.sh` (`board [--check]`), `brand.test.sh`,
the template's `identity/board.md` (placeholder), `identity/README.md` (links it) and `7-branding/imagery.md` (the
sample images table, spec §4.4).

**Acceptance criteria:**

- [ ] 5.4.1 to 5.4.11 hold: the five parts in order, both palettes at once, results in words, no script or external
      URL, the strict build, `names-check.sh`, freshness, no HTML element, the images' elements, and the refusals
      for sample images.
- [ ] The board's images are generated in `board/`, and re-runs give byte-identical files.
- [ ] Sample images with no record, or with a person and no consent, are open items.

**Named test:** `scripts/tests/brand.test.sh`. **Layer:** `asgard`. **Size:** L. **Depends on:** BT-T04, BT-T07.

---

### Task BT-T09: the docs

**Files (in `asgard`):** Modify `AGENTS.md` (the map), `templates/company/core/docs/7-branding/identity/logo/README.md`
(her PNGs, the optional mark, the generated files), `templates/company/core/.ouroboric/README.md` (the brand step in
`run.sh`).

**Acceptance criteria:**

- [ ] The map names `brand.sh` and its two tests; the template's pages say what she brings and what is generated,
      with no tool's name outside `.ouroboric/`.
- [ ] Then: one pull request for BT-T08 and BT-T09, with every Asgard test passing.

**Named test:** `scripts/tests/new-company.test.sh` (the names and wording checks). **Layer:** `asgard`. **Size:** S.
**Depends on:** BT-T08.
