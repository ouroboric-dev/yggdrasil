---
title: A loop settles a disputed finding with a check
status: draft
date: 2026-10-20
related: [delta.md, tasks.md, ../2026-10-20-report-framing/proposal.md, ../../backlog.md]
style: spec
---

# A loop settles a disputed finding with a check

**Proposed 2026-10-20.** It fixes backlog [B-104](../../backlog.md). The founder decided the shape on 2026-10-20.

## Why

- In run 20261020-190818-5b02ff the reviewer said `findIndex` is not a JavaScript method. The implementer showed
  with `curl` that it is, and changed nothing. The reviewer repeated the claim in its next two sessions, and the
  run stopped at `attempts-exhausted` (exit 3). Nothing in the loop checks who is right.
- The loop already has a referee that does not guess: the checks ladder. Odin runs the realm's checks on the host,
  and a `fixed` finding already needs a check that passed as proof (spec §4.6). A dispute should use the same
  referee.
- An unattended run must stay frictionless. A person should stop it only where no check can decide.

## Decisions (the founder, 2026-10-20)

- **Dispute state only.** The vision of a review bot that approves or comments on the pull request, and a merge
  bot, is a later design. This change adds no GitHub app and does not touch "humans merge".
- **Settle with a named check, not with an arbiter agent.** The implementer's dispute MUST point at a check and
  a test, and Odin MUST verify that the check ran and passed on this attempt. A second model that judges the
  test was rejected: it is one model's word against another's again.
- **Where no check covers the claim, the run stops with both sides recorded**, in every mode. A run that cannot
  be decided by a test is a person's decision.

## What changes

- **The implementer can dispute a finding.** Its last answer in an attempt may hold a `disputes` document, read
  with the same strictness as a report: `{"disputes": [{"id": "<finding id>", "check": "<check name>", "test":
  "<test id>", "evidence": "<what it showed, and where>"}]}`. A dispute for a finding that is not open, or one
  that cites a check the loop does not run, is an error and costs nothing but a line in the ledger.
- **Odin verifies a dispute after the checks ran.** A dispute holds when the named check passed in this attempt
  and its output names the test (a substring match on the test id). The test therefore needs a check that prints
  the tests it runs; the realms' test checks do.
- **A dispute that holds overrules the finding.** The finding closes with status `overruled`, with the
  implementer's evidence and the check run as proof, and a `finding-overruled` ledger event. A reviewer that
  repeats the claim does not reopen it, unless it cites a check that failed in a later attempt, or a location the
  test does not cover. An overruled finding stays visible: the report and the operator's view list it, with both
  sides.
- **A dispute that does not hold changes nothing.** The finding stays open, as today. The next attempt's prompt
  says the dispute did not hold and why.
- **A dispute that no check can settle stops the run with a new reason, `finding-disputed`.** It is not
  `attempts-exhausted`. The escalation carries both sides: the reviewer's claim and location, and the
  implementer's evidence. In `step_by_step` mode the same record is what the operator reads at the gate. The run
  resumes after the operator rules: overrule, or send the work back with guidance.
- **The reviewer prompt and the implementer prompt** say how a dispute works, and that a reviewer must show proof
  for a blocker it repeats after a dispute.

## Not in this change

- **A review bot, a merge bot, or any change to the pull request.** A later design.
- **A second reviewer, or any arbiter agent.**
- **Disputing a failing check.** A check is already deterministic; a person fixes the check in the realm.

## Impact

- **Repos:** `gungnir` (the `overruled` status, the `disputes` schema, the ledger event), `jormungandr` (the book
  and the loop), `odin` (reading the disputes, verifying them, the escalation text), `yggdrasil` (backlog, spec,
  pointers).
- **Approval points:** none added or removed. A new stop reason appears at the existing escalation point
  (spec §7.3).
- **Risk:** a test that names the claim but proves nothing. The reviewers still read the test, and the operator
  sees both sides on any overruled finding in the report.
