---
title: Typed boundaries between the factory's blocks
status: proposed
date: 2026-10-24
related: [design.md, inventory.md, delta.md, tasks.md, ../../backlog.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../../3-using/operations/proof-runs.md]
style: spec
---

# Typed boundaries between the factory's blocks

**Proposed 2026-10-24, after run 1 (v0-H20) stopped at its second task.** It fixes backlog B-176 and the class of
B-170 and B-175. Run 1 starts again when this change is merged.

**What merging this approves:** the [design](design.md), which the founder approved on 2026-10-24, the
[delta](delta.md) to the v0 spec, and the [tasks](tasks.md). Every data boundary of the default graph gets a typed
contract: one typed output per node, Markdown only as a view, an in-sandbox submit tool, typed check results, typed
gate decisions and an experiment record. Instructions (prompts, skills, the brief) stay prose. The
[inventory](inventory.md) lists every boundary as it is today.

## Why

Run 1 stopped three times, each time where one block handed another something whose shape nothing checked: a
prompt that promised a diff (B-170), a report dug out of prose (B-175), a task whose text and contract a Markdown
parser dropped (B-176). The founder's goal is a harness that gives "as much determinism as possible without
limiting the models", so that setups and models can be compared fairly. The design says how; this proposal adds
what planning settled.

## What planning settled

Reading the code for the plan settled these, within what the design decided. Each is the planner's ruling.

1. **The submit result comes from the session's own stream.** Both CLIs record every tool call with its input in
   the output Odin already reads (`gleipnir/claudecode`, `gleipnir/opencode`). `ygg-submit` validates and answers;
   it writes nothing. Odin takes the last call that validates. The design's "fixed path outside the leaf" is not
   needed: a sandbox command gets no folder of its own (`gungnir.Cmd`), and this way a read-only reviewer writes
   nothing at all. If the probe (T07) shows a CLI's stream does not carry the input, that adapter uses the strict
   whole answer.
2. **`ygg-submit` and `ygg-check-result` are Node scripts in the work image.** The image's tools stage is the
   pinned Node image (`gleipnir/sandbox/assets/Containerfile`) and has no Go toolchain. `ygg-submit` validates with
   ajv, pinned like the CLIs, against the schemas gungnir ships, baked into the image. Odin's own validation, with
   gungnir's validator, stays the one that decides; a parity test runs gungnir's fixtures through both, and gungnir
   allows only the schema keywords both read alike.
3. **Odin reads a check's result with a second command in the same sandbox.** It removes the result path before
   the check and reads it after, bounded. The exit code decides pass or fail.
4. **The experiment record extends `ygg metrics`.** `odin/internal/metrics` already sums usage by role, loops,
   findings, interventions, the grade and the clock, and has `--compare`. `ygg record RUN` writes its JSON, with
   the new parts, to `record.json`; `ygg.run-record/v1` validates it.
5. **The contract types live in `gungnir/schema`**, beside their schemas: the spec's type holds `schema.Leaves`,
   and gungnir's root package cannot import `schema`. `gungnir.Conformance` stays where it is.
6. **The retrospective runs after the grade.** The rule that the grade node is last allows read-only agent nodes
   after it.
7. **The real-CLI probe is the founder's** (T07): it runs paid sessions.

## The founder's choices

All are in the design, "The founder's decisions (2026-10-24)". The retrospective role is Claude Code with Opus.

## History

- 2026-10-24: the inventory and the design were approved; this proposal, the delta and the tasks were planned.
