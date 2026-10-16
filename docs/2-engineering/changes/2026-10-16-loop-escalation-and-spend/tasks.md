---
title: Tasks for loop escalation and what a cap counts
status: accepted
date: 2026-10-16
related: [proposal.md, delta.md]
style: spec
---

# Tasks

## loop-escalation-and-spend-T001: the choices of this change, built (v0, Phase 4)

- **Acceptance criteria:**
  - [ ] A loop that runs out of attempts stops the run at `escalation` in all three modes, and a rejection
        gives it another full set of attempts with the operator's reason.
  - [ ] A reviewer's unreadable answer stops the loop, is never approvable, and closes nothing.
  - [ ] A run that reaches a cap stops at `budget-cap` before the next session, and approving does not
        lift the cap.
  - [ ] The day's cap counts what another run spent; a journal that can't be read stops the run.
  - [ ] A rate limit is retried and costs no attempt; a used-up quota pauses the run with exit code 4.
- **Named test:** Phase 4's `tasks.md`: v0-T136 `TestALoopThatRunsOutOfAttempts…`,
  `TestAMalformedReviewerOutputStopsTheLoopAndIsNeverAPass`; v0-T129 `TestARunThatReachesItsCap…`,
  `TestApprovingBudgetCapDoesNotWaiveTheCapButRaisingItDoes`, `TestThePerDayCapCountsWhatOtherRunsSpent`;
  v0-T130 `TestATransientFailureIsRetried…`, `TestAUsedUpQuotaPausesTheRunAndAResumeStartsTheNodeAgain`.
- **Layer:** `gungnir`, `gleipnir`, `jormungandr` and `odin`.
- **Size:** the sum of Phase 4's tasks.
- **Depends on:** Phase 3.
