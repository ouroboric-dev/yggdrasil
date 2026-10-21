---
title: The grader reads the scores from the suite's stdout
status: draft
date: 2026-10-21
related: [delta.md, tasks.md, ../../backlog.md, ../2026-10-14-benchmark-split/proposal.md]
style: spec
---

# The grader reads the scores from the suite's stdout

**Proposed 2026-10-21.** It fixes the third decision of backlog [B-084](../../backlog.md), which the founder took on
2026-10-20: the grader reads the scores from the suite's stdout, and the app has no path to forge it.

## Why

- Odin reads the score from a file, `results.json`. The suite writes it to `/logs/verifier`, a host folder that
  Gleipnir's `Grade` mounts read and write into the grader container (`gleipnir/sandbox/grade.go`).
  `odin/internal/engine/grade.go` then opens `<logs>/results.json` with `score.ReadResults` and joins it with the
  manifest.
- The app and the suite share that container. `Grade` runs one container with `/app`, `/tests` and
  `/logs/verifier`. The suite's own `test.sh` starts the app inside it (the sample suite does: it runs
  `./start.sh` as the user `app` and waits on port 3000). Nothing in `Grade` stops the app from writing under
  `/logs/verifier`. The check that the folder is empty runs before the container starts, not after.
- So a graded app can write a `results.json` of its own, or replace the suite's, and Odin turns it into a reward.
  `ReadResults` only checks that the file is a regular file, that it parses and that no title repeats. It cannot
  tell who wrote it.
- The stdout of the container has no such path today. `Grade` takes it from the engine's pipe, outside the
  container. A process in the container can write to it only if it holds the pipe, which in the sample suite
  the app does not (the suite sends the app's output to a log file).

## What changes

- **The suite prints the scores on its stdout, once, as one line:**
  `ygg-results/v1 <key> <report>`, where `<report>` is the Playwright JSON report on a single line. The report
  is the same one Odin reads from the file today, so the join with the manifest does not change.
- **The key.** Odin makes a random key for each grading attempt (16 bytes, hex) and gives it to the container as
  the environment variable `YGG_SCORE_KEY`. The suite MUST print it in the line and MUST start the app with a
  clean environment (`env -i`, as the smoke script of `bench/harbor` does), so the app never sees it. A line that
  does not carry the key is not a score and is ignored. The key stops an app that can reach the container's
  stdout, for example when the suite forgets to redirect the app's output, from printing a line of its own.
- **Gleipnir returns the container's stdout whole**, apart from its stderr, in a new field of `GradeResult`,
  with a bound (32 MiB, the bound `ReadResults` has today for the file). Over the bound, the grade fails. The tail
  kept in `Log` (8000 bytes) stays for the operator.
- **Odin parses the stdout.** `score` gets `ParseStdout(stdout, key)`. It finds the lines that start with
  `ygg-results/v1` followed by a space and carry the key, and then reads the report as `ReadResults` reads it now (last try wins, a
  title used twice is an error, no spec is an error).
- **Odin stops reading `results.json`.** Nothing in the run reads a file from `/logs/verifier`. The folder stays
  mounted, empty at the start, for the suite's own logs (the operator reads them), and Odin never opens them.
  The code that guarded the read (the regular-file check, `O_NOFOLLOW`, the same-file check) goes with it.
- **What happens when the stdout holds no score line, or more than one.**
  - No line with the key: `*GradeFailed` ("the suite printed no scores"). No `score.json`.
  - Two or more lines with the key, identical or not: `*GradeFailed` ("the suite printed the scores twice").
    Odin does not pick one.
  - A line that does not parse, holds no spec, or repeats a title: `*GradeFailed`, as a bad file does today.
  - A scenario missing from the report or not in the manifest: `grade_refused` with `bad_manifest`, as today.
  - A `GradeFailed` stops the run failed and `ygg resume` grades again, as today. A failure is never a score of 0.
- **The suite's exit status** is still not the score.

## Compatibility with the benchmark format

- Harbor's layout is `tests/test.sh` run in the task image, with the verifier reading a reward file the script
  writes to `/logs/verifier` (`reward.json` in `bench/harbor/tests/smoke.sh`, from `verifier_result.rewards`).
  That is Harbor's own run, and it does not go through `ygg grade`. Odin's reward never came from that file.
- The bridge (`bench/harbor/ygg_harbor`) writes no reward and does not grade: it carries out the factory's
  requests, and Harbor runs `test.sh` and reads the reward itself. So **the bridge writes nothing new**.
- **What a suite must write**, to run under both: its reward file for Harbor, as now, and the keyed line on stdout
  for Odin. A suite that is run by Harbor and has no `YGG_SCORE_KEY` MAY print the line with an empty key, or no
  line. The two outputs are independent. Harbor's reward file stays forgeable by the app. This change does not
  touch it, because Harbor is the other factories' path and Odin never reads it.
- The layout of §11 does not change: `task.toml`, `environment/`, `tests/test.sh`, `tests/manifest.json`.

## What stays

- The container: no network, three mounts, the label, the limits, the timeout and the removal.
- `manifest.json` (`ygg.suite/v1`), the join by scenario id, the reward formula and `score.json`.
- The refusals before the build, and `grade.log` in the run folder.
- Gleipnir reads no result: the score is Odin's.

## Impact

- **Repos:** `gleipnir` (`GradeSpec.ScoreKey`, `GradeResult.Stdout`, the bound, the architecture page), `odin`
  (`score.ParseStdout`, `engine.Grade`, the key, the tests, the architecture page), `yggdrasil` (spec, backlog,
  pointers). `gungnir` is not touched: the manifest and the score do not change.
- **Order:** `gleipnir` merges first, then `odin` bumps its pin.
- **The suite is the founder's, and it must change.** Every suite needs three edits: read `YGG_SCORE_KEY`; start the
  app with `env -i` and with its stdout and stderr in a file; print `ygg-results/v1 $YGG_SCORE_KEY <report>` last,
  with the report on one line (for Playwright, its JSON reporter on stdout, kept on one line with `jq -c`). The
  sample suite in the public benchmark repo needs the same. This change does not write them. Until a suite is
  updated, `ygg grade` on it fails with "the suite printed no scores", on purpose.
- **Approval points:** none.

## Risk

- **A suite that leaks the key to the app** (the app is started without `env -i`) loses the protection. Odin
  cannot see that. The suite's own review has to. The two-lines rule still catches an app that prints a second
  line next to the suite's own.
- **An app that floods the container's stdout** fails the grade over the bound. That is a failed grade, not a
  forged one, and a resume grades again.
- **An app can still make the suite print wrong scores,** by being a different app. That is not forgery: it is
  the product's behaviour, which the suite is there to measure. This change closes only the path that skips the
  suite.
- **The report is large on one line** (traces and attachments in a Playwright report). The bound is 32 MiB as
  before. Most suites will not come near it.
