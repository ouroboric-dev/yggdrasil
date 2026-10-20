---
title: Delta for disputed findings
status: draft
date: 2026-10-20
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §4.6, §7.3

## Added

- §4.6: a finding's `status` MUST also allow `overruled`.
- §4.6: an implementer MAY dispute an open finding in its last answer of an attempt, with a `disputes` document.
  Each dispute MUST name the finding id, a check of the loop, a test id and the evidence. Anything else MUST be an
  error that changes no finding.
- §4.6: Odin MUST decide a dispute after the loop's checks ran. It holds only when the named check passed in this
  attempt and its output contains the test id.
- §4.6: a dispute that holds MUST close the finding as `overruled`, with the evidence and the check run as proof,
  and MUST write a `finding-overruled` ledger event. A reviewer's repeat of the claim MUST NOT reopen it unless the
  report cites a check that failed in a later attempt, or a location the test does not cover.
- §7.3: a loop MUST escalate with the reason `finding-disputed` when an implementer disputes an open finding that
  no check of the loop can settle. The escalation MUST carry the reviewer's claim and location and the
  implementer's evidence.

## Modified

- §4.6: "A finding MUST NOT close until its source confirms the fix with proof" gains: "or a dispute of it holds
  (an `overruled` finding)".

## Removed

None.
