---
title: Tasks for the grader reading the scores from stdout
status: draft
date: 2026-10-21
related: [proposal.md, delta.md]
style: spec
---

# Grader scores from stdout: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first. One pull request per repo; the founder merges.

**Goal:** the score of a grade comes from a keyed line on the grader's stdout. An app that writes `results.json`,
or prints a line without the key, changes nothing.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `gleipnir`:** `GradeSpec.ScoreKey` (32 lowercase hex characters; `check` refuses anything else, and
  refuses a `Env` that names `YGG_SCORE_KEY`). `Grade` passes `--env YGG_SCORE_KEY=<key>`. `GradeResult.Stdout` holds
  the container's whole stdout, never its stderr, read with a bound of 32 MiB; over the bound `Grade` returns an
  error and no result. `Log` keeps its 8000-byte tail. Replace the `results.json` wording in the comments and in
  `docs/architecture.md`. Tests first, with the stand-in `podman` of `grade_test.go`: a stdout longer than 8000
  bytes comes back whole in `Stdout`; stderr text is not in `Stdout`; the key reaches the command line as
  `--env YGG_SCORE_KEY=`; a bad key and an `Env` that names the variable are refused; a stdout over the bound is an
  error. Change `integration_grade_test.go` so the suite prints a line and the test reads `Stdout`.
- [ ] **T2 `odin`:** `score.ParseStdout(stdout []byte, key string)`, which returns the same map as `ReadResults`.
  Remove `ReadResults` and its file guards. `engine.Grade` makes the key (`crypto/rand`, 16 bytes), puts it in the
  `GradeSpec`, and parses `res.Stdout`. Failures are `*GradeFailed`; a manifest mismatch stays `grade_refused`.
  Never write the key to the ledger. Tests first, in `score` and in `engine`:
  - **scores parsed from stdout:** a stdout with noise and one keyed line gives the statuses of its specs (last try
    wins, a title twice is an error, no spec is an error, as the old tests say);
  - **an app that overwrites `results.json` changes nothing:** the stand-in engine writes a forged
    `results.json` into the logs folder and the real report to stdout, and the score is the stdout's;
  - **fail closed:** no keyed line; a line with another key only; two keyed lines, identical and different; a
    line whose report does not parse; each is a `*GradeFailed` with no `score.json` and a `grade_*` ledger
    state that lets `ygg resume` grade again;
  - a keyed line in the middle of other output, and one that ends the output without a newline, both parse.

  Update `docs/architecture.md` (the grading paragraph) and the engine's and the CLI's stand-in engine
  (`engineStub` copies a file today; it prints to stdout).
- [ ] **T3 `yggdrasil`:** fold the delta into spec §9.5 and §11; mark the third decision of B-084 done, and the first
  bullet of B-085 (the unbounded grader output) done for the grader's stdout; move the pointers; archive this
  folder. File one backlog item for the suites: update the sample suite and the hidden suite to print the keyed line
  (the founder's). B-083 is not part of this change.

## Open for the builder

- **Whether `/logs/verifier` stays mounted.** Odin no longer opens it. The proposal keeps it for the suite's logs
  and for Harbor's layout. If the builder finds nothing in a suite that needs it, say so and propose removing the
  mount and the empty-folder check in a later change.
- **How Gleipnir bounds the stdout.** `Driver.run` buffers without a bound for every caller. `Grade` may need its
  own capture (a limited writer on `cmd.Stdout`). Say how a timeout and the bound interact: the process group is
  killed, and the error is the bound's.
- **Whether a line of 32 MiB reads well** with the standard line readers. Parse by searching the bytes, not by a
  fixed-size scanner buffer.
- **Whether Playwright's JSON reporter on stdout** stays on one stream with the tests' own output. The suite
  author, not Odin, decides how to keep the report apart. A real run on the sample suite settles it.
- **The key in `grade.log`.** The tail of stdout may hold the line and so the key. The file is `0600`, in the run
  folder, and never for an agent, and the key is good for one attempt. Say if the builder prefers to cut the key out.
- **Whether `/proc` and `/dev` in the container let the app reach the suite's stdout** when the suite runs as root
  and the app as `app`. The proposal assumes a different user cannot. A test on a real engine should show it.
