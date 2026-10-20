---
title: Delta for the report framing
status: draft
date: 2026-10-20
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §4.6

## Added

- §4.6: a reviewer's answer MAY have prose before its report. The report MUST be the last thing in the answer,
  bare or in one code fence. The prose MUST be ignored.

## Modified

- §4.6: "If a reviewer output does not parse… it MUST be retried once" now also covers text after the report, a
  second fence or document, and an unclosed fence. Prose before the report no longer counts as unparsable.

## Removed

None.
