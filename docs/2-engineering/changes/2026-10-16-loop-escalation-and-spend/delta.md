---
title: Delta for loop escalation and what a cap counts
status: accepted
date: 2026-10-16
related: [proposal.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §4.6, §7.1, §7.3, §7.4, §10.1, §12

## Added

- §7.1: `escalation` is an approval point. It is soft (a config MAY set it to `stop`, and MUST NOT set it
  to `auto`) and stops in step-by-step, key-points and unattended mode.
- §7.3: a loop that gave up MUST stop the run at `escalation`. A rejection with a reason MUST give the loop
  another full set of its attempts, with its open findings and the reason in the implementer's prompt. An
  approval is allowed only when the attempts ran out, MUST let the work go on with its findings still open,
  and MUST NOT close them. In unattended mode the ledger MUST say `blocked`.
- §7.4: the caps count input plus output tokens (cache reads are reported, not counted), turns, and, only
  when a role bills a paid API, dollars. A cap is reached when use equals it. The per-day cap MUST count what
  every run of the operator used on the operator's local day, in every project, from a journal outside
  every project, in which every session's use is recorded, a failed one's too. A journal that can't be read
  MUST count as a reached cap. No session MAY start over a cap, a retry included, and a session's turns MUST
  be bounded by what the caps still allow. Approving a stop at `budget-cap` MUST NOT lift a cap that is still
  reached. A warning MUST go to the ledger the first time a cap is 80% used.
- §4.6: a reviewer MUST answer with one JSON document, `{"findings": [...]}`. The report MUST carry only
  the reviewer's own findings, mention every finding it still held open, and close a finding only with a
  proof that cites a `file:line` and names a check that passed in that attempt. An answer that breaks any of
  this, and a reviewer session that fails as an agent, MUST be asked once more without a new implementer
  attempt, and the second time MUST stop the loop. An unreadable reviewer MUST NOT be approvable. A finding
  that is minor MUST NOT fail a loop. A finding's texts are bounded (id and source 100 characters,
  location 300, claim 4,000, proof 2,000).
- §12: a failure MUST be told apart as agent, transient, quota or infrastructure. A failure not known MUST be
  an agent failure. A transient failure MUST be retried three times, after 5, 10 and 20 seconds, with the
  leaf put back to its checkpoint before each retry. A used-up quota MUST pause the run: `ygg` exits with 4,
  and `ygg resume` starts the node again from its checkpoint.
- §10.1: the events `retry`, `run_paused`, `finding_raised`, `finding_closed` and `finding_reopened`, with
  `ygg.finding.*` fields: the id, the source, the severity, the attempts a closed finding took and how often
  it came back.
- §9.5: the ladder MUST stop at the first check that fails; reviewers MUST run only on work that passed
  every check.

## Modified

- §7.3, unattended mode: the task is marked `blocked` and the run MUST stop, since a linear graph has no
  task that does not depend on it. Continuing with the rest comes with the web realm's per-task graph
  (Phase 5).

## Removed

None.
