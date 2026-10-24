---
title: Delta for typed boundaries
status: proposed
date: 2026-10-24
related: [proposal.md, design.md, tasks.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §2.2, §4.2, §4.4, §4.6, §5, §6.2, §7.2, §9.5, §10.2

## Added

- **§2.2, Core interfaces:** "Every block hands another block data only through a contract: a versioned JSON Schema
  in Gungnir with a Go type, tested to agree. Instructions (a role's prompt, its skills, the brief) may be prose;
  data never is. A contract changes compatibly within a version (new optional fields only); anything else is a new
  version."
- **§4.2, nodes:** "Each node of a graph MUST declare its inputs, as named contracts, and exactly one output
  contract. A graph whose node declares an input no earlier node or built-in source provides, or an output its
  consumer does not accept, MUST NOT load. No untyped output type exists. The built-in sources are `brief`,
  `decisions`, `task`, `change`, `open_findings`, `check_results`, `rejection`, `refusal`, `record` and `date`."
- **§4.2, views:** "Odin MUST render every document people read (the design, the spec, `plan.md`, `tasks.md`, the
  reuse review, the gate files) from the typed outputs, and MUST NOT read Markdown an agent wrote. A publish node
  writes each output's JSON and its rendered view. `leaves.yaml` is written by Odin from the spec's output."
- **§4.2, owner decisions:** "The spec's output MUST cite every owner decision id, in its decisions or its
  deviations. A spec that does not goes back to the spec stage once, with the ids it misses."
- **§4.2, implement ⇄ check ladder:** "An implementer answer that says `blocked` ends the attempt: no reviewer
  runs, and the loop escalates as `implementer-blocked` with the reason."
- **§4.6:** "Every agent output carries `blocked` (with a reason) and `notes`, always allowed and always recorded."
- **§5, the output channel:** "An agent session returns its output through the `submit` tool of `ygg-submit`, a
  stdio MCP server in the work image that validates the output against the node's contract and writes nothing.
  Odin reads the last call that validates from the session's stream and validates it again. An adapter without the
  tool returns its output as the whole final answer: exactly one JSON document, bare or in one fence, and nothing
  else. An output that does not validate is asked for once more, with the errors; then the node fails as an agent
  failure."
- **§9.5, check results:** "Every check writes a `ygg.check/v1` result through `ygg-check-result`. The exit code
  decides pass or fail; a result that contradicts it is refused. A failing check raises one finding per failure,
  with the test id and the location where the tool gives them. A check that writes no valid result is a failure of
  the realm, and its finding says so."
- **§10.2, the experiment record:** "Every run has `record.json` (`ygg.run-record/v1`), which `ygg record RUN`
  rebuilds from the ledger, the run state and the judgements: the setup (each role's agent, model, CLI version and
  reasoning; the hashes of the graph, prompts, skills and realms; the task and its version; the factory build), the
  objective numbers by task, loop and graph, the harness's health (outputs refused and repaired by role and model,
  `blocked` answers, notes, open questions left to the spec), the retrospective and the operator's judgements."
- **§10.2, the retrospective:** "A read-only `retro` node, role `retrospective`, runs after the grade and writes
  `ygg.retro/v1`: what went well, what went wrong (each with a category, a severity, its evidence and the block it
  targets) and suggestions. Of the hidden suite it sees the totals only."
- **§10.2, judgements:** "`ygg score RUN --score N --well TEXT --wrong TEXT [--task ID]` records the operator's
  judgement (`ygg.judgement/v1`), 0 to 10, per run by default and per task with `--task`, at any time after the run.
  A new judgement of the same run or task replaces the last; the ledger keeps each."

## Modified

- **§4.2, plan + reuse review:** "Odin derives `features.json` from `tasks.md`" becomes: "Odin derives
  `features.json` from the plan's typed output. Each task carries its fields, its `text` and its optional
  `contract`, whole; the readiness check bounds them and refuses an over-size task."
- **§4.4:** "the current task from its read-only `features.json`, and the routing summary" becomes: "what its prompt
  holds: the node's declared inputs, rendered by Odin. An input over the prompt's bound goes into the workspace as a
  file the prompt names, never left out."
- **§4.6:** a reviewer's report "as the last JSON document of its answer" becomes: "through the output channel
  (§5), as one `ygg.review/v1` document". The implementer's disputes likewise come in `ygg.implement/v1`.
- **§6.2, hardening:** "the managed settings block project MCP servers" becomes: "the managed settings allow exactly
  one MCP server, `ygg-submit`, by name and command; sessions keep `--strict-mcp-config`, and a leaf can add no
  server."
- **§7.2, mechanics:** "approve with a note" becomes: "approve or reject with a decisions file
  (`ygg.decisions/v1`: decisions with ids the operator chooses, stable across runs, and optional answers keyed to
  this run's open questions; a rejection's file also holds a reason). `--note TEXT` is shorthand for a file with
  one decision."

## Removed

- **§4.6:** "Any text before it is ignored" and the reading of the last JSON document in prose.
- **§4.2:** the `inputs:` folders copied into a scratch workspace; a node's inputs are its declared contracts.
