---
title: Loop escalation and what a cap counts
status: accepted
date: 2026-10-16
related: [../../specs/2026-10-11-yggdrasil-v0-spec.md, ../2026-10-12-require-budget-caps/proposal.md, delta.md, tasks.md, ../../plans/2026-10-16-yggdrasil-v0-phase-4/tasks.md]
style: spec
---

# Loop escalation and what a cap counts

**Decided 2026-10-16:** Phase 4 builds the loop (spec §4.2, §4.6, §7.3), the budget caps as a hard
approval point (§7.4) and the error handling of §12. In doing so it had to choose where the spec is
silent. This change records those choices, so that the spec and the code do not drift apart.

## Why

The spec says what a loop does when its attempts run out ("stop and ask", or in unattended mode "mark the
task blocked and continue with the tasks that do not depend on it"), but its table of approval points has
no row for it, and a linear graph has no other task to continue with. It says a run MUST stop when it hits
a cap, but not what a cap counts, how a day is measured when the operator runs several projects on one
subscription, or what approving a stop at a cap means. It says a malformed reviewer output MUST stop the
loop, retried once, but not what a well-formed one must keep promising. It lists the failures of §12 but
not how a failure is told from another. Each of these is a place where an implementer, left to guess,
would guess differently from the next.

## What changes

- A new soft approval point, `escalation`, stops the run in every mode when a loop gives up. It takes a
  rejection (another full set of attempts, with the operator's reason) and, after the attempts ran out
  only, an approval (the work goes on with its findings open).
- A cap counts input and output tokens, turns and, for a paid API, dollars; the per-day cap counts every
  run's use that day, in every project, from a journal outside the projects; a cap that can't be checked
  is reached; approving a stop at a cap does not waive it.
- A reviewer's report is one JSON document with rules that keep a finding from vanishing or closing on
  its own word; an unreadable one is asked again once, without a new implementer attempt.
- Minor findings do not fail a loop.
- A failed session is told apart as agent, transient, quota or infrastructure, and each has its response.
  A used-up quota pauses the run, with exit code 4.
- The ledger gets the events `retry`, `run_paused`, `finding_raised`, `finding_closed` and
  `finding_reopened`.

## Impact

- **Components:** Gungnir (types, schemas, the `loop` node), Gleipnir (adapters, the check runner),
  Jormungandr (the loop), Odin (the steps, the journal, the meter, the CLI).
- **Approval points:** one is added, `escalation`; none changes.
- **Operators:** `factory.yaml` may name a `budget.journal`; `ygg` has a new exit code, 4; a loop node in
  a graph.
- **v0 plan:** Phase 4's `tasks.md` implements it.
