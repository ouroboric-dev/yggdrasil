---
title: Delta for the grader reading the scores from stdout
status: draft
date: 2026-10-21
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §9.5 and §11

The spec never names `results.json`. The file and its folder are described in the benchmark-split plan and in the
architecture pages of `gleipnir` and `odin`; those pages change in T1 and T2 of the tasks.

## Added

- §9.5, item 7: Odin MUST take the scores of the hidden suite from the stdout of the grader container. It MUST NOT
  read any file the grader container could write as a score. The container's stdout MUST be read outside the
  container, apart from its stderr, with a bound. A stdout over the bound MUST fail the grade.
- §9.5, item 7: Odin MUST give each grading attempt a random key, as the environment variable `YGG_SCORE_KEY`. A
  score line MUST carry it. Odin MUST ignore a line that does not.
- §9.5, item 7: a grade MUST fail, with no score written, when the stdout holds no score line with the key, or
  more than one. A grade that fails MUST NOT count as a score of 0.
- §11: a hidden suite MUST print its scores as one line on stdout, `ygg-results/v1 <key> <report>`, with `<key>`
  the value of `YGG_SCORE_KEY` and `<report>` a Playwright JSON report on a single line. It MUST print the line
  once, after it has stopped the app.
- §11: a hidden suite MUST start the app with a clean environment, without `YGG_SCORE_KEY`, and MUST NOT send the
  app's output to the container's stdout.
- §11: a suite that is also run by Harbor MUST still write Harbor's reward file. Odin MUST NOT read it.

## Modified

- §11, "Output: `score.json` (pass/fail per scenario, by category) joined with the run's metrics" is unchanged. The
  input of that join changes: it is the report on the keyed stdout line, not a results file.

## Removed

None in the spec. The contract that the suite writes `/logs/verifier/results.json` leaves the architecture pages
of `gleipnir` and `odin` and the benchmark-split plan's description of the grader.
