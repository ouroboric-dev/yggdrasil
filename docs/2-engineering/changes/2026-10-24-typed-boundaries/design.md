---
title: Typed boundaries between the factory's blocks
status: accepted
date: 2026-10-24
related: [inventory.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../../backlog.md, ../2026-10-23-reviewers-see-the-diff/proposal.md, ../../../3-using/operations/proof-runs.md]
style: spec
---

# Typed boundaries between the factory's blocks

**Designed 2026-10-24 with the founder, after run 1 (v0-H20) stopped at t002.** This document is the input to a
plan. It is written for the session that plans and builds the change. That session should not need to go back to
the founder, except for the items under "Left to the builder" that say so.

## Why

Yggdrasil is a set of building blocks for building software with models: graphs, loops, skills, agents (the CLIs,
such as Claude Code and opencode), models, gates and realms. It ships with a default setup. An operator can change
any role's model or CLI at any time, and graphs, loops, skills and agents are meant to be customizable, even before
anyone customizes them. The founder does not believe one setup suits every use case. The factory is a research
instrument: setups are compared by experiment.

The founder's goal, in their words: not identical runs, but a "semi deterministic result, where the whole harness
(graphs, loops, skills, etc) are providing as much determinism as possible without limiting the models". Variance
between two runs should come from the models and setups being compared, not from loose joints in the harness.
That is what makes a comparison fair.

Run 1 stopped three times, and every stop was at a boundary between two blocks where both sides assumed a different
shape and nothing checked it (`inventory.md` has the full list):

| Stop | Boundary | What broke |
| --- | --- | --- |
| B-170 | Odin → reviewer | the prompt promised a diff that Odin never sent; no node declares what its prompt must hold |
| B-175 | reviewer → Odin | the report was prose with JSON in it; the parser guessed which part was the report |
| B-176 | planner → Odin → implementer | `tasks.md` is Markdown read by a regex parser that drops the task's text and its contract |

B-176 is open: run 1 (`20261024-000619-5b319d`) is stopped at t002, kept as its evidence. A narrow fix was drafted in
`.worktrees/yggdrasil-task-text` and is superseded by this change; its "What happened" section may be reused.

## Goals

1. **Every data boundary in the default graph is typed.** What crosses it has a versioned schema, checked by both
   sides. Instructions (prompts, skills, the brief) may be prose; data never is.
2. **Blocks are swappable.** A block that honours a contract can replace another. Odin checks the joins of a graph
   when it loads it, not hours into a run.
3. **The harness is the deterministic part.** Prompt assembly, the contracts, the checks and the gates behave the
   same whatever model or CLI fills a role.
4. **Every run leaves an experiment record:** its setup, its objective numbers, an agent's retrospective and the
   operator's judgement, in a form two runs can be compared by.
5. **Run 1 starts again on the new boundaries** and gets past t002.

## Non-goals

- Identical results between runs. Models differ, and so does one model between two runs.
- A best setup. The default setup is a starting point for experiments, not an answer.
- Changing what the harness does beyond its boundaries. Odin copying the API contract into the web leaf comes after
  run 1, as its own change.
- A comparison view across runs. The slice guarantees the record; a view comes later.
- Protobuf. The models emit JSON, and MCP tool inputs and structured outputs take JSON Schema. What is worth taking
  from protobuf is its discipline: schema first, versioned, compatible changes only.
- Putting Odin itself in a sandbox. Worth doing as defence in depth, but a separate change.

## Anti-goals

The founder named two outcomes that would make this a failure even if it works:

1. **The harness limits what the models can do.**
2. **The harness fails to give typed contracts between the blocks, or misses the goals above.**

The guards for each are part of the design ("Guards" below), and the acceptance criteria check them.

## Constraints

- **The tree's invariants hold** (`AGENTS.md`): branches and pull requests, the founder merges, the tree's scripts
  (`ouroboric/scripts/as-bot.sh`, `ygg-engine.sh`), staging by path, tests first, no secrets read or printed.
- **No hidden tests.** No session reads, lists or searches `huldra`, `ouroboric-private` or `~/ygg-it/hidden-suites`.
- **Guardrails are not weakened**, except the one MCP change below, which the founder approved in principle on
  2026-10-24 and which the proposal must name and test.
- **Spec-driven.** The change goes through a change folder (`proposal.md`, `delta.md`, `tasks.md`) with a delta to
  the v0 spec, as earlier changes did. This document and `inventory.md` sit in that folder.
- **The engine.** No session starts, stops or restarts the container engine; if it hangs, ask the founder.
- **Founder tasks stay the founder's:** proof runs and merges.

## The founder's decisions (2026-10-24)

- **Typed contracts are JSON Schema**, defined once in gungnir with matching Go types, tested to agree.
- **The slice before run 1** is: the mechanism (typed node inputs and one typed output per node, checked at graph
  load; prompts built from typed inputs; outputs as one schema-checked document with a repair round); every node's
  output in the default graph (design, spec, conformance, plan with its tasks, reuse review, reviewer reports, the
  implementer's answer, the retrospective); the checks' results; the operator's gate decisions as typed files; and
  the experiment record. Then run 1. (First agreed for three boundaries; the founder widened it on 2026-10-24: "untyped outputs is what got
  us here in the first place.")
- **Instructions may be prose; data never is.** No untyped output type exists, not even for legacy nodes.
- **The MCP path is acceptable**, as long as it gives agents no way out of the sandbox. Odin's submit server runs
  inside the sandbox over stdio, never on the host (see "The output channel").
- **Measurements are split.** Objective: turns, cost, tokens in and out, time and the rest below, at the task, loop
  and graph levels. Subjective: an agent's retrospective at the same levels, and the operator's score.
- **The retrospective's default is Matt Pocock's `retro` skill** (`github.com/mattpocock/skills`,
  `skills/engineering/retro/SKILL.md`), wrapped to return a typed record. Operators can replace it.
- **The operator's judgement** is a score from 0 to 10 with prose on what went well and what went wrong, per run by
  default and optionally per task.
- **Roles, models and CLIs are the operator's to set**, for every role, at any time.
- **The retrospective role in run 1 is Claude Code with Opus**, kept fixed as the judge across later comparisons:
  the strongest reader of long transcripts, on the subscription, and not the Sonnet that plans and builds, so it does
  not judge its own work.

## The design

### 1. Contracts

- Each contract is a JSON Schema in `gungnir/schema/` with an id and a version (`ygg.plan/v1`), and a Go type in
  gungnir. A test proves the two agree on fixtures: valid ones that both accept, invalid ones that both refuse.
- Contracts change compatibly within a version: new optional fields only. Anything else is a new version, and Odin
  reads the versions it knows.
- **Envelope, not craft.** A schema fixes which fields exist, their types and which are required. Prose fields are
  free text, bounded only for safety (far above what run 1 used). No enum stands where judgement belongs.
- **Every agent output has two fields for the unforeseen:** `blocked` (with a reason: the session could not do the
  work) and `notes` (anything the schema did not foresee). They are always allowed and always recorded.

### 2. Typed nodes and the graph check

**The rule (the founder's, 2026-10-24): instructions may be prose; data never is.** Instructions are what a session
is asked to do: the role's prompt, its skills and the brief. Odin passes them as they are. Data is everything one
block hands to another, and it is always typed. There is no untyped output type and no legacy escape hatch: the
graph schema has none, so a graph cannot declare one.

- **One typed output per node.** Each node in `graph.yaml` declares `input:` (a list of named contracts) and
  `output:` (exactly one named contract). The graph schema (`gungnir/schema/graph.schema.json`) gains the fields.
- **Markdown is a view.** Odin renders the files people read (the design, the spec, `plan.md`, `tasks.md`, the reuse
  review, the gate files) from the typed outputs, and publishes them where they are published today. Nothing ever
  reads Markdown back in. A file a later stage needs that today is written by an agent, such as `leaves.yaml`, is
  written by Odin from the typed output.
- **Sources of input** are earlier nodes' outputs, or Odin's built-in sources: `brief`, `decisions` (the operator's
  gate decisions, section 4), `task`, `change` (the task's diff), `open_findings`, `check_results` (typed, section 4), `date`.
- **The load check:** a node's every declared input has a source before it, and its output's contract is the one its
  consumers declare. A graph that fails does not load, and the error names the node and the field.
- **Prompt assembly from types.** Odin builds each prompt from the node's declared inputs: the role's prompt file,
  then one section for each input, rendered from its typed value. A declared input with no value is an error before
  the session starts. This closes the B-170 class: a reviewer that declares `change` cannot run without it. Inputs
  replace the `inputs:` folders seeded into scratch today: a session reads what its prompt holds, not what it may
  find. An input above a bound goes into the workspace as a file that the prompt names, never silently left out.
  (The designer's call; the bound is the builder's.)
- `date` ends the agents' `date +%F` calls: the date comes from Odin.

### 3. The output channel

The agent CLIs run inside the leaf's sandbox (`gleipnir/claudecode/claudecode.go:81-122`), whose only network is a
firewall to the model provider. Two ways back, both validated by Odin after the session:

- **The submit tool (primary).** A small static binary, `ygg-submit`, pinned and hashed in the work image like the
  other tools. The CLI starts it as a stdio MCP server, a child process inside the container, with the agent's own
  rights and no network of its own. It offers two tools:
  - `submit`: takes the node's output object, checks it against the node's output schema, returns the errors, or
    writes the valid object to one fixed path outside the leaf (for example `/run/ygg/out/result.json`);
  - `check`: checks a draft of the output, written to a file under `out/`, against the node's schema, and returns
    the errors. It lets a scratch stage build a large output (a spec, a plan) as a file and check it as it goes;
    the session still ends with `submit`, or with that file named in it. (The builder may fold the two tools into
    one.)

  It never talks to Odin or the host. The schemas reach it read-only. Odin reads the result file after the session
  and validates it again: the tool helps the model repair in-session; it is never trusted.
- **The strict whole answer (fallback).** For an adapter without the tool, the final answer must be exactly one
  JSON document (bare or in one fence) and nothing else. This replaces "the last document; prose before it is
  ignored" (`gungnir/schema/event.go`, B-175's parser), which is retired.
- **One repair round** when what comes back does not validate: Odin asks once more with the errors, as it does for
  `conformance.json` today (`odin/internal/engine/scratch.go:71-74`). Then the node fails as an agent failure.
- **The one guardrail change.** The work image's `managed-settings.json` allows no MCP server
  (`"allowManagedMcpServersOnly": true`, `"allowedMcpServers": []`). It changes to allow exactly one server, Odin's,
  by name and command. Sessions keep `--strict-mcp-config`, and Odin passes its own config (`--mcp-config`) only. A
  leaf can still add no server: a security test proves it, for each adapter.

### 4. Every boundary in the graph

Every node of the default graph gets its contract in this slice. The sections each prompt asks for today become
fields, mostly prose; what Odin or a gate acts on becomes structure. Field lists below are the shape, not the final
schema: the builder writes the schemas from the prompts as they stand.

- **Design (`ygg.design/v1`).** `summary`, `users`, `scope`, `success_criteria`, `decisions`, and `open_questions`:
  a list, each with an id the design gives it (`q1`, `q2`, …) and the question. Odin renders the design document.
  The design gate shows the open questions as a list.
- **Spec (`ygg.spec/v1`).** The spec's sections as prose fields, in the order `spec.md` asks for; `decisions`;
  `deviations` (a list: what differs from the design, where, why, and the owner decision it comes from, by id);
  and `leaves` (today's `leaves.yaml` content, `ygg.leaves/v1`). Odin writes the spec document and `leaves.yaml`.
  Run 1's spec filed the owner's changes under "Decisions" instead of "Deviations"; typed deviations end that.
- **Conformance (`ygg.conformance/v1`).** Typed already; it moves to the shared channel and repair round.
- **Plan (`ygg.plan/v1`).** `goal`, `decisions`, `risks` and `tasks`. Each task: `id`, `title`, `criteria` (2 to 5),
  `named_test`, `layer`, `size`, `depends_on`, `text` (the planner's words: behaviour, routes, fields, limits,
  errors) and `contract` (optional: the OpenAPI text the task adds or calls, verbatim). Odin renders `plan.md` and
  `tasks.md`; nothing parses them. `features.json` carries every field of a task. "Your task" renders `text` and
  `contract` whole. The readiness check bounds them (run 1's largest task text was 9.3 KB) and refuses an
  over-size task, so Odin never cuts one. It also checks that `contract` parses as OpenAPI.
- **Reuse review (`ygg.reuse-review/v1`).** A `verdict` and its `items` (each: what, where, the existing thing to
  reuse instead). Odin renders the review. The plan gate shows the verdict, so the review is read at last.
- **Reviewer reports (`ygg.review/v1`).** `findings` (the existing finding type), `blocked`, `notes`, through
  `submit`. Jormungandr's `ReportFormat` (`jormungandr/prompt.go:69-81`) becomes a short instruction to call
  `submit`, generated from the schema.
- **The implementer's answer (`ygg.implement/v1`).** `summary`, `disputes` (the existing dispute type), `blocked`,
  `notes`, through `submit`. A `blocked` answer ends the attempt: no reviewers run, and the loop escalates as
  `implementer-blocked` with the reason, for a person. (t002 paid for three attempts and their reviews after its
  implementer said it lacked the contract.) The designer's call: a person sees every `blocked`, so a model cannot
  use it to skip work unnoticed, and the record counts it per model.
- **Check results (`ygg.check/v1`).** Each check of the ladder (the realms' scripts: about 12 in `midgard-react`,
  11 in `helheim-go`) writes a result: the check's name, `passed`, the exit code, `timed_out`, the duration, counts
  (run, passed, failed, skipped, where the tool has them), and `failures`, each with a kind (test, lint, type, build,
  scan, policy), the test's id where there is one, a location (`file:line`) where the tool gives one, and the
  message. The log stays, for people. (The founder added this to the slice on 2026-10-24.)
  - **Converted by factory code, not by each script.** Most of the tools already emit machine output: `go test
    -json`, Vitest's and Playwright's JSON reporters, ESLint's JSON, SARIF from the scanners. A small tool in the
    work image, `ygg-check-result`, converts those formats into `ygg.check/v1`, tested once on fixtures of each.
    A script calls it; a tool with no machine output (such as `tsc`) gets a converter there, tested the same way.
    (The designer's call; the builder may choose another split, if the conversion stays in tested factory code.)
  - **The exit code stays the truth.** The checks run in the sandbox beside the agent's code, so an agent's test
    could write a result file. Odin creates the result path fresh for every check run, decides pass or fail from
    the exit code as today, and refuses a result that contradicts it. The result only adds the detail.
  - **One finding per failure**, with a stable id from the check and the test or the location, instead of one
    blocker per check pointing at `<log>:1` (`gleipnir/checks/checks.go:86-100`). A dispute names a test id that the
    typed result holds, not one to find in the log text (`jormungandr/prompt.go:86-94`).
  - **A check that writes no valid result** is a failure of the realm, not of the task: the finding says so and
    carries the log's tail, the record counts it, and each realm's own tests prove every script writes a valid
    result on a passing and on a failing fixture.
  - **The hidden suite stays out of reach.** The grader's results are typed already (`score.schema.json`); this
    changes nothing there, and no agent sees them (the retrospective gets the totals only, section 5).
- **The operator's gate decisions (`ygg.decisions/v1`).** What a person gives at a gate is data too. A decisions file
  holds:
  - `decisions`: each with an id the operator chooses (`password-reset`, `storage-cap`) and its text. These ids are
    stable across runs, so the proof runs give the same decisions, word for word, in every run, although each run's
    design asks different questions with different ids;
  - `answers` (optional): each with the id of one of this run's open questions and the answer.

  `ygg approve RUN GATE --decisions FILE` and `ygg reject RUN GATE --decisions FILE` (a rejection's file also
  holds a `reason`). `--note TEXT` stays as shorthand for a file with one decision. Odin validates the file, keeps it
  with the gate's events, and passes it to later stages as the `decisions` input. The proof runbook's two blocks
  become two checked-in decision files, so no block is pasted through a shell again.
- **Owner decisions are checked, not hoped for.** The spec must cite every owner decision id, in `decisions` or in
  `deviations`. Odin checks it before the conformance review, and a spec that misses one goes back to the spec
  stage with the missing ids, once, as a repair. That replaces the runbook's rejection block ("if the spec still
  lacks a decision, reject it"). An open question with no answer stays allowed: the spec decides it and records the
  decision, and the record counts the questions left to the spec. (The designer's call.)

### 5. The experiment record

Every run leaves `record.json` (`ygg.run-record/v1`) in its run folder, rebuilt by `ygg record RUN` from the ledger,
the run state and the judgements, so it can be rebuilt at any time.

- **Setup:** each role's agent, model, CLI version and reasoning; fingerprints (hashes) of the graph, the prompts,
  the skills and the realms; the task and its version; the factory build.
- **Objective numbers, at the task, loop and graph levels:** turns; tokens in, out and from cache; the cost figure
  and billed dollars; agent time and wall time, with the time waiting at gates apart; attempts; findings by source
  and severity, raised and closed; check results; gate stops and interventions; the estimated size against the
  actual lines changed (split into hand-written, tests and generated); the hidden suite's score.
- **Harness health:** validation failures and repairs per role and model, `blocked` answers, `notes`, and the open
  questions left to the spec. If the harness gets in a model's way, it shows here.
- **The retrospective (`ygg.retro/v1`):** written by a `retro` node at the end of the graph, by default. It is its
  own role, `retrospective`, in `factory.yaml`, so its model and CLI are chosen and can be held fixed across compared
  runs. Its prompt wraps the `retro` skill's categories (navigation, automated checks, coding standards, AGENTS.md,
  tool economy, information access) and adds "went well". It returns `went_well`, `went_wrong` (each with a category,
  a severity, evidence pointing to a task, a finding, a ledger entry or a transcript, and the block it targets) and
  `suggestions`. It is read-only and reads the objective part of the record, the ledger and the transcripts. Of the
  hidden suite it sees the score totals only: no test names, no per-test results, nothing from the suite itself
  (invariant: no agent reads hidden tests; the designer's call). A `retro` node inside the task loop, for each task
  or loop, is an option the default graph leaves off. The skill is vendored through havamal's `skills.lock`, as
  `ponytail-review` is.
- **The operator's judgement (`ygg.judgement/v1`):** `ygg score RUN --score N --well "…" --wrong "…" [--task ID]`,
  any time after the run, never blocking it. A run judgement by default; a task judgement with `--task`. Stored in
  `judgements.json` in the run folder; a new judgement for the same run or task replaces the old one, and the ledger
  keeps each.

### 6. Guards

Against anti-goal 1, limiting the models: the envelope only (section 1); repair in-session, not rejection (section
3); `blocked` and `notes` on every output; no new caps or tool limits in this change; the harness-health numbers
(section 5).

Against anti-goal 2, missing contracts: the graph load check, and a graph schema with no untyped output (section 2);
contract tests for every schema; one contract suite every adapter passes, so swapping Claude Code for opencode
cannot change what Odin receives.

## Acceptance criteria

- [ ] A graph whose node declares an input nobody provides, or an output its consumer does not accept, fails to load
  with the node and the field named. (B-170 class.)
- [ ] Every node of the default graph declares one typed output, and the graph schema accepts no untyped one.
  Nothing in the factory parses Markdown that an agent wrote.
- [ ] A reviewer or implementer answer that is not one valid document is repaired in the session through `submit`,
  or refused after one repair round. No answer is dug out of prose. (B-175 class.)
- [ ] Each task's `text` and `contract` reach the implementer and the task reviewers whole, from `tasks.json`.
  (B-176 class.) The web implementer can copy its task's contract.
- [ ] An implementer that answers `blocked` stops the loop with its reason, after one attempt.
- [ ] Every check of both realms writes a valid `ygg.check/v1` on a passing and a failing fixture; a failing check
  gives one finding per failure, with its test id and location where the tool has them; a result that contradicts
  the exit code is refused.
- [ ] Gate decisions are typed files with stable ids; the proof runs give the same files every run; a spec that
  does not cite every owner decision id goes back once with the missing ids.
- [ ] A leaf cannot add an MCP server for any adapter, and `ygg-submit` reaches neither Odin nor the network.
- [ ] Every adapter passes the same contract suite.
- [ ] `record.json` holds the setup, the objective numbers at three levels, the harness-health numbers, the
  retrospective and the operator's judgements, and `ygg record` rebuilds it.
- [ ] Run 1 starts again on the new graph (the founder's task) and gets past t002.

## The parts, in the order they depend on

1. **gungnir:** the contracts and their tests (design, spec, conformance, plan, reuse review, review, implement,
   check, retro, decisions, judgement, record); the graph schema's `input`/`output`; the readiness bounds.
2. **gleipnir:** `ygg-submit` and `ygg-check-result` (with its converters' fixtures); `checks` reads typed results
   and makes one finding per failure; the work image and its managed settings; both adapters pass the MCP config; the
   contract suite; the security tests.
3. **jormungandr:** the report and dispute instructions from the schemas; reading typed results; disputes matched
   against the typed check results' test ids.
4. **odin:** the graph load check; prompt assembly from typed inputs; the output channel and repair round; the
   Markdown views rendered from every typed output, and `leaves.yaml` written from the spec's; tasks from the plan's
   output; the owner-decision check; `--decisions` on approve and reject; `implementer-blocked`; `record.json`,
   `ygg record`, `ygg score`; the `retro` node kind or role.
5. **havamal:** vendor the `retro` skill (and `writing-for-agents`, if kept) through `skills.lock`, with licences.
6. **voluspa:** the software graph's declarations; every stage's prompt asks for its typed output (design, spec,
   conformance, plan, reuse review, the three reviewers); the `retro` node and its prompt wrapping the vendored
   skill.
7. **The realms** (`midgard-react`, `helheim-go`): every check script writes its typed result through
   `ygg-check-result`, with a test on a passing and a failing fixture each; the implementer prompts call `submit`;
   the web one reads the task's `contract`.
8. **ouroboric:** the proof run's factory template (`scripts/testdata/proof/factory.proof.example.yaml` and what
   `ygg-proof-run.sh` fills) gains the `retrospective` role (Claude Code, Opus); the script passes decision files
   (`--decisions`) instead of pasted blocks, and prints the `ygg score` command at the end.
9. **yggdrasil:** the spec delta; the runbook (`docs/3-using/operations/proof-runs.md`: the two decision files
   checked in beside it, `ygg score`, the record); the backlog (B-176 and the items below); the pointers.
10. **The founder:** merges, then run 1 again with the same decisions.

## Left to the builder

- **Verify, then decide:** what each CLI supports in headless mode. Can opencode run a local stdio MCP server under
  settings as strict as Claude Code's, and can a leaf's own opencode config add one? Does either CLI's native
  structured output beat `submit` for some node? If opencode cannot be kept strict, it uses the fallback, and the
  proposal says so.
- **Verify the `retro` skill's licence** before vendoring it, with REUSE annotations. It loads Matt Pocock's
  `writing-for-agents` skill: vendor that too, or drop the step from the wrapper.
- **The repair round's form:** a new session with the errors (simple, as `conformance.json` does), or a resumed one
  where a CLI allows it.
- **Bounds:** the sizes of `text`, `contract`, `notes` and the record's fields, above run 1's figures.
- **The schemas' exact fields,** from the prompts as they stand (section 4 gives the shape).
- **Ask the founder** only if a verification shows that a decision above cannot hold: for example, that `submit`
  cannot be kept inside the sandbox for an adapter.

## Seen on the way (to the backlog)

- **B-176:** the task parser drops the task's text and contract (run 1, t002). Fixed by this change.
- An implementer that reports a missing input still gets three attempts (t002). Fixed by `implementer-blocked`.
- A fresh project's first contract always stops at `contract-gate`: the impact index is written by the first pointer
  move (`odin/internal/routing/contract.go:147`). Every proof run will stop there once, at t001.
- A sandbox pod was removed with a container still running (`podman pod rm`, exit 125, after t001's review). `ygg
  doctor` cleans it; nothing failed.
- Task sizes are the planner's guess and are never measured: t001 was "M" (100 to 400 lines) and changed 797 lines
  (665 without generated code). The record now measures it.
- The roles run on different CLIs, and minute timeouts favour fast providers. These are setup choices to record, not
  bugs; the record names them.
