---
title: Tasks for Asgard's design system process
status: draft
date: 2026-10-27
related: [proposal.md, delta.md]
style: spec
---


# Tasks: Asgard's design system process

Each task starts from Asgard's `origin/main`, test first, and ends with a pull request. The design doc and the spec
are amended in yggdrasil with the delta once this proposal is approved.

- [ ] **DS-T01 The kickstart guide.** Asgard `docs/`: the nine steps as a procedure, step 6 in its seven sub-steps.
- [ ] **DS-T02 Readiness checklist.** Asgard `templates/readiness/checklist.md`: RB-21 to RB-25 and RL-06 as the
      delta gives them, with an "applies to" column (company or product) and no tool names in what a company copies.
- [ ] **DS-T03 Foundations in the template.** `tokens.json` schema, generated CSS, the identity page's sections, a
      starting set of foundation values that pass the new checks.
- [ ] **DS-T04 New checks.** `brand.py`: glyph coverage, minimum body size, focus contrast, foundations present,
      the body face's italic; and accepted exceptions (reported as accepted, stale when the value changes).
- [ ] **DS-T05 Typography tool.** `brand.sh fonts`: candidates with licences, specimens in the company's words.
- [ ] **DS-T06 Palette rounds.** `brand.sh palette`: a round from JSON, checked and rendered with the logo.
- [ ] **DS-T07 Logo design.** `brand.sh logo-prep` (cut out, flat background removed, resolution raised) and
      `brand.sh logo-proposals` (the concept and the alternatives as a review page, panels per alternative, the
      lettering picker over candidate typefaces with poor-fit notes; the chosen design written for the palette to
      recolour, the chosen typeface seeding the wordmark role).
- [ ] **DS-T08 Web fonts.** WOFF2, subset to the clients' languages, in `fonts.css`.
- [ ] **DS-T09 The board.** Type scale, component sheet, logo usage, applications.
- [ ] **DS-T11 The playground.** `brand.sh playground`: the self-contained prototype from a candidates file; every
      palette role, typography role (the wordmark included), foundation and component variant mixed and matched;
      the logo's design fixed, recoloured live, its lettering in the live wordmark face; live checks from the shared
      rule set; the export validated by `brand.py`. Its rules are generated from `brand.py`, so a test proves the two
      agree.
- [ ] **DS-T12 Choice pages save choices.** The rules of spec §5.7 for every choice page, with a test each: the
      choice and reason saved where the agent reads them, candidate facts read at build time, every face loads.
- [ ] **DS-T10 The token contract.** Written in the brand tools spec for the product realms; the realm side is
      backlog B-217.
