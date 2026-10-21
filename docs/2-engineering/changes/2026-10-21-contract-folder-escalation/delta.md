---
title: Delta for the contract folder escalation
status: draft
date: 2026-10-21
related: [proposal.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §3.4, §8.2 and the decision log

## Added

- §3.4: the `pointer-contract` gate MUST also look at the folder of each contract that the shipped impact index lists
  (the directory of the entry's path, and every folder below it, except that for a contract at a leaf's root only the
  files directly in the root count). A move that changes a file there MUST escalate if
  the file is a YAML file (`.yaml`, `.yml`) or a JSON file (`.json`), and if its git mode is `120000` (a symlink),
  whatever its name. The escalation uses the evidence `inferred`. It stops the gate in every mode. An approved spec
  that holds the change MUST NOT open it.
- §3.4: the gate's reason MUST name the file and say which rule selected it.

## Modified

- §8.2, the paragraph that ends "Every pointer move also runs the umbrella's acceptance tests (§4.5), so a break that
  only an `inferred` edge noticed is still caught." Before: Odin MUST treat a pointer move as `pointer-contract`
  only on `extracted` evidence or on `oasdiff`. After: Odin MUST treat a pointer move as `pointer-contract` on
  `extracted` evidence or on `oasdiff`, and MUST escalate it on the two folder rules of §3.4. The acceptance-test
  sentence stays and narrows: it covers what neither the evidence nor the folder rules select.
- §18, the decision log row "Contract-change stops (2026-10-12)". Before: "only `extracted` or `oasdiff` evidence
  triggers `pointer-contract`; acceptance tests on every pointer move catch the rest". After: the same text,
  followed by "; a changed YAML or JSON file and a symlink under a listed contract's folder escalate (2026-10-21)".
  This is the decision the backlog entry B-084 calls the plan's decision 15. The plan
  (`plans/2026-10-12-yggdrasil-v0/plan.md`) has no decision of that number. The text is in the spec's log. The plan's
  decision 15 in Phase 5c is another rule (the two-tenant rule). The fold changes the spec's row and adds a one-line
  note to the plan's errata.

## Removed

None. The sentence "acceptance tests catch the rest" stays as the net for files the gate does not select. It no
longer says that nothing inside a contract's folder is judged.
