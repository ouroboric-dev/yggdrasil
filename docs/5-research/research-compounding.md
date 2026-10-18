---
title: "Research: compounding learnings and the self-improvement loop"
status: draft
date: 2026-10-17
related: [curation.md, research-bmad.md, research-loops-graphs.md, ../1-product/charter.md, ../1-product/design/2026-10-11-yggdrasil-v0-design.md, ../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md]
style: research
---

# Research brief: compounding learnings and the self-improvement loop

Prepared 2026-10-17. It asks two questions. Does Every's Compound Engineering plugin fit the loop in
which Yggdrasil improves itself? And should the lessons that loop keeps be stored as a graph?

The plugin was read at commit `2e41b44` (2026-10-17). Stars, forks and release data come from the
GitHub REST API on the same day.

**How to read the evidence labels** (the same as in [research-loops-graphs](research-loops-graphs.md))

- **[PROVEN]**: primary source with concrete numbers, a reproducible artifact, or official
  documentation. Here it mostly means "read in the plugin's source".
- **[CREDIBLE]**: primary source, but self-reported by an interested party with no independent check.
- **[EARLY / HYPE]**: secondary commentary, vendor marketing or anecdote.
- **[ANALYSIS]**: the author's own judgement, recommendation or inference, not a sourced fact.

---

## 0. TL;DR

1. **Compound Engineering (CE) is a skill pack, not a framework** **[PROVEN]**. It has 36 skills
   around the loop brainstorm → plan → work → simplify → review → **compound**. The compound step
   writes one learning per solved problem to `docs/solutions/` as markdown with typed YAML
   frontmatter.
2. **Its retrieval is grep, not a graph** **[PROVEN]**. A `learnings-researcher` subagent greps the
   frontmatter, then reads only the matching files. There are no embeddings and no graph store.
3. **CE does not measure whether a learning helped** **[PROVEN]**. Its strategy says: "these are
   signals we watch, not measurements." Yggdrasil's charter requires improvement "measured run
   against run".
4. **Distilled lessons beat raw traces, and a curated graph did not beat grep on accuracy**
   **[CREDIBLE]**. Two 2026 studies, in §3, show it. Gains from memory are small: about 3.7 points
   on average.
5. **[ANALYSIS]** "Graph" fits the self-improvement *loop*, as an Odin graph that feeds the change
   graph. It does not yet fit the *storage* of lessons. A graph index should ship only if it beats
   the routing bench, as spec §8.3 already requires of every index.
6. **[ANALYSIS]** Borrow CE's ideas; do not install the plugin. That is the same stance the spec
   takes on Spec Kit and Superpowers.

---

## 1. What Compound Engineering is

| Field | Value |
| --- | --- |
| URL | <https://github.com/EveryInc/compound-engineering-plugin> |
| Maintainers | Kieran Klaassen and Trevin Chow, at Every |
| Origin | Klaassen developed the practice while building Cora, Every's AI email assistant ([aibuilderclub](https://www.aibuilderclub.com/blog/compound-engineering-vs-loop-engineering)) **[EARLY / HYPE]** |
| Stars / forks | 25,571 / 2,079 |
| Created | 2025-10-09 |
| Activity | Last push 2026-10-17. Latest release `compound-engineering-v3.31.0` (2026-10-16). Releases are automated. |
| Licence | MIT |
| Hosts | The README says 14 agent hosts, including Claude Code, Cursor, Codex, OpenCode, Pi and Cline. A converter in `src/` translates the Claude plugin format for the others. |
| Shape | 36 skills (`skills/*/SKILL.md`) with reference files, Python helper scripts and a Bun/TypeScript test suite of skill contract tests |

The README states the philosophy: "Each unit of engineering work should make subsequent units easier
-- not harder." It puts "80% … in planning and review, 20% … in execution."

The six core skills are `ce-brainstorm`, `ce-plan`, `ce-work`, `ce-simplify-code`, `ce-code-review`
and `ce-compound`. `lfg` runs the whole pipeline unattended and stops before merging. Other skills
cover strategy, feedback intake (`ce-sweep`), product reports (`ce-product-pulse`), git workflow,
browser testing and handoffs.

The strategy names its users as "agent-first developers who work across more than one harness and
model." It ships "no telemetry, ever" ([STRATEGY.md](https://github.com/EveryInc/compound-engineering-plugin/blob/main/STRATEGY.md)).

## 2. How the compound step works

### 2.1 Capture: `ce-compound`

- **One learning per run.** A session with several lessons gets several runs. The skill says
  batching breaks research and deduplication **[PROVEN]**.
- **A bar for writing anything at all.** The skill applies a counterfactual test: "if the learning
  document disappeared, would a future engineer reading the final implementation still be likely to
  repeat the mistake or redo substantial investigation?" If not, it writes nothing. "Completion,
  effort, and diff size do not establish eligibility." **[PROVEN]**
- **Only solved and verified problems** qualify. An existing learning that has become wrong is
  updated, not duplicated **[PROVEN]**.
- **A typed schema** (`references/schema.yaml`, `schema_version: 1`) **[PROVEN]**:
  - required on every learning: `module`, `date`, `problem_type`, `component`, `severity`;
  - `problem_type` puts the learning on a **bug track** (for example `runtime_error`) or a
    **knowledge track** (for example `convention`, `tooling_decision`, `architecture_pattern`);
  - bug-track learnings also require `symptoms`, `root_cause` and `resolution_type`;
  - optional: `applies_when`, `tags`, `related_components`, and `retire_when`. The last one names the
    outside change that would retire the learning, such as an upstream bug being fixed, and how to
    check it.
- **Open vocabulary, corpus first.** `component` and `root_cause` reuse the spelling the existing
  learnings already use; the skill forbids coining near-synonyms **[PROVEN]**.
- **A write boundary.** Research subagents write only to scratch. The orchestrator writes the one
  learning, plus `CONCEPTS.md` (a project glossary) and, with consent, one line in `AGENTS.md` or
  `CLAUDE.md` so that later agents find the store **[PROVEN]**.

### 2.2 Retrieval: the learnings researcher

`ce-plan`, `ce-code-review`, `ce-ideate` and `ce-optimize` each ship a `learnings-researcher` prompt
**[PROVEN]**. It works in steps:

1. Read `CONCEPTS.md`, if present, to use the project's own terms.
2. Extract keywords from the work context: modules, technical terms, concepts, decisions.
3. Run parallel, case-insensitive greps over the frontmatter fields (`title`, `tags`, `module`,
   `problem_type`, `applies_when`), returning file names only.
4. Read the frontmatter of the 5 to 20 candidates, score them, and read only the strong matches in
   full.
5. Always read `solutions/patterns/critical-patterns.md` if it exists.

The prompt calls this "grep-first filtering". No index, embedding or graph is involved.

### 2.3 Maintenance: `ce-compound-refresh`

The refresh skill audits learnings against the current code **[PROVEN]**. Each learning gets one
outcome: **Keep**, **Update**, **Consolidate**, **Replace** or **Delete**. There is no archive
folder; "version history is the archive". Rules from `references/classify.md`:

- "Age alone is not staleness."
- "Unverifiable is not false." A claim the repo cannot confirm is kept, not deleted.
- A contradiction outranks staleness, because it actively misleads.
- Before a delete: is the problem domain still active, and do other docs rely on this one?
- A learning that contradicts a skill or runbook it names is reported; the refresh never edits the
  skill.

An optional "worth lens", which the user must confirm, deletes accurate learnings whose reasoning the
code, tests or instructions already state, quoting the file that states it.

### 2.4 Promotion: learning, pattern, pack

`CONCEPTS.md` in the plugin defines three levels **[PROVEN]**:

- a **learning** records what one past problem taught;
- a **pattern doc** generalises several learnings into a broader rule, "higher-leverage … and
  higher-risk when stale";
- a **Compound Pack** is a folder of prescriptive rules with `applies_when` frontmatter. Planning
  pulls matching rules in as constraints, and review flags work that contradicts them. A pack's text
  "is quoted as evidence inside other Skills' steps, never executed as instructions."

### 2.5 Measurement

The strategy is explicit: "We ship no product analytics by choice, so these are signals we watch, not
measurements." Its compounding signal is "learnings written in this repo and, more importantly, reused
by later runs" **[PROVEN]**.

One skill is the exception. `ce-retune` re-tunes the skills for a new model "measurement-first". It
refuses to run without a run archive, a way to point two runs at two builds of the skills, and a
repeatable task. It states: "A green test suite is not done: it proves nothing broke, not that
behavior improved." **[PROVEN]**

### 2.6 Criticism found

Independent critique is thin. One commentary says the knowledge compounds inside a single repository
and does not carry across machines, teammates or projects
([moclaw](https://moclaw.ai/blog/compound-engineering)) **[EARLY / HYPE]**. No independent
measurement of CE's effect was found.

## 3. Evidence: how should an agent's lessons be stored?

### 3.1 Abstraction decides whether a lesson transfers

Kim et al., "Memory Transfer Learning" (KAIST, NYU, DeepAuto.ai;
[arXiv 2604.14004](https://arxiv.org/abs/2604.14004), April 2026) tested four kinds of memory, from
concrete to abstract, on six coding benchmarks: LiveCodeBench v6, Aider-Polyglot, SWE-Bench Verified,
TerminalBench2, ReplicationBench and MLGym-Bench **[CREDIBLE]**.

Average Pass@3 with GPT-5-mini (the paper's Table 1):

| Memory | Average |
| --- | --- |
| none (zero-shot) | 0.523 |
| trajectory (raw trace) | 0.534 |
| workflow | 0.538 |
| summary | 0.546 |
| insight | **0.560** |

The paper says "high-level insights generalize well, whereas low-level traces often induce negative
transfer." Raw trajectories scored below no memory at all on TerminalBench2 (0.270 against 0.315) and
MLGym-Bench (0.583 against 0.667). The authors call a transferred trajectory "a brittle anchor." They
attribute the gains mainly to meta-knowledge such as validation routines, not reused code.

### 3.2 A curated graph did not beat grep on accuracy

The IWE team benchmarked IWE, their markdown knowledge graph, as agent memory on LOCOMO, a
long-conversation question set ([blog](https://iwe.md/blog/the-benchmark-that-built-the-tools/),
[memory-bench](https://github.com/iwe-org/memory-bench)) **[CREDIBLE]**:

- On the sealed test set of 351 questions, grep over raw transcripts scored 0.812, grep over the
  curated notes 0.764 and a multi-turn tool agent 0.735.
- Multi-hop questions, where a graph should help most, "showed no curated advantage at all."
- The graph won on cost. One-shot retrieval took about one turn, 20,800 tokens and 1.9 seconds per
  question; the grep agent took 4.6 turns, 77,800 tokens and 11.6 seconds.

The authors wrote that grep over raw transcripts "still refuses to be beaten on accuracy alone." They
argue a curated store stays compact while raw history "grows without bound."

LOCOMO is conversational recall, not coding, and the benchmark is small. **[ANALYSIS]** The result
transfers to a lessons store only as a warning: a graph has to prove itself.

### 3.3 Not yet read

These turned up in searches and are not yet read:

- "EA-Graph: Artifact-Anchored Verification Memory for Coding Agents under Upstream Drift"
  ([arXiv 2608.04278](https://arxiv.org/pdf/2608.04278)). The title matches CE's `retire_when`.
- "Ontology-Grounded Project Memory for Coding Agents"
  ([arXiv 2608.13662](https://arxiv.org/pdf/2608.13662)). It compares no memory, flat notes, mem0,
  BM25 and a structured project graph.
- "The Agent Memory Race of 2026" ([OSS Insight](https://ossinsight.io/blog/agent-memory-race-2026)).

## 4. Fit with Yggdrasil

All of §4 is **[ANALYSIS]**.

### 4.1 What already matches

- **Files in git, any host.** CE keeps its learnings as markdown in the repo and runs on 14 hosts.
  That fits the charter's "state lives in files and git, where every agent can read it."
- **The loop.** CE's loop is close to the web realm graph: design, spec, plan, build, review. The
  compound step is the part the realm graph lacks.
- **Measurement-first tuning.** `ce-retune`'s gate matches Havamal's rule that each of our skills
  ships with an eval showing it "measurably improves agent behaviour" (spec §5.1).

### 4.2 The gap CE fills

Yggdrasil has raw evidence, the hash-chained ledger (spec §10.1), and a narrative, the journal (spec
§10.5). Nothing sits between them: no typed, searchable, refreshable store of lessons. The
self-improvement loop needs that middle step.

```text
ledger (Odin) → distil a lesson → propose a factory change → A/B bench → guardrail-change approval → journal
                ^^^^^^^^^^^^^^^ CE's compound step
```

Yggdrasil already owns both ends. Design doc §2.3 criterion 7 requires a factory change that improves
a metric, shown by `ygg metrics --compare`. CE has no equivalent.

### 4.3 Two meanings of "graph"

1. **The improvement loop as an Odin graph: a good fit.** It matches the working definition: fixed
   structure, agents only for judgment, capped retries, human approval points. In effect it is the
   change graph (proposal → delta → tasks, spec §15.3) aimed at the factory, and it is Stage 2 of
   self-hosting, "improving itself from benchmark results" (spec §15.4). The compound step becomes
   the entry node; no new concept is needed.
2. **Lessons stored as a knowledge graph: not yet.** §3 does not support it. Start with typed links
   in frontmatter (`supersedes`, `derived_from: <run ids>`, `applies_when`). Add a BM25 "lessons"
   index beside the "decisions" index (spec §8.2). Tag every edge `extracted` or `inferred`. Build a
   real graph only if it raises the routing bench's right-first score.

### 4.4 Where it could apply

1. **Product realms.** A compound node after the merge gate writes lessons into the product leaf.
   The planner and reviewers read them through routing. This improves the product, not the factory,
   but it may raise the first-pass rate on later features.
2. **Factory self-improvement.** Lessons from many runs climb a ladder: lesson, pattern, rule (like a
   Compound Pack), then a Havamal skill or graph change. An eval and `guardrail-change` gate each
   step up.
3. **The Asgard realm.** The charter's "every late gap becomes a checklist item for the next one" is
   already compounding. The readiness checklist works like a Compound Pack.
4. **Building Yggdrasil now.** Memory files, SDD ledgers, handovers and the backlog already do this
   by hand. CE's discipline would help, but a fourth store to search should replace something, not
   add to the pile.

## 5. Risks

All of §5 is **[ANALYSIS]**.

- **Hidden-suite leakage.** A lesson distilled from rung-7 results would put hidden tests into
  agents' context, and spec §9.5 says those results "MUST NOT go to agents." Lessons must come from
  visible signals only, or from aggregate scores.
- **Persistent injection.** A lesson an agent writes and every later run loads is the "persistent
  injection" path in [research-harness](research-harness.md). Lessons are data, never instructions,
  as CE says of its packs. A promotion into a skill or graph is a `guardrail-change`.
- **Private lessons.** Spec §10.5 applies: lessons from private product runs stay in the private L0
  instance and are distilled and anonymised before any public use.
- **Goodhart's law.** A factory that optimises its own metrics can learn to game them. The hidden
  suite and "without lowering the hidden acceptance score" in criterion 7 are the guard.
- **Rot.** Every capture adds a document, and duplicates drift apart. CE's refresh rules (§2.3) are
  the model to borrow.
- **Small effect sizes.** §3.1 measured about 3.7 points on average. A single lesson's effect may
  sit inside run-to-run noise, so the bench needs a noise floor first, as `ce-retune` requires.

## 6. Borrow or adopt

All of §6 is **[ANALYSIS]**.

**Borrow:**

- the durable bar (§2.1) as the test for writing a lesson;
- the schema, with `retire_when`, plus our own fields for evidence (run ids, ledger refs);
- the refresh outcomes and rules (§2.3);
- the promotion ladder from learning to pack (§2.4), gated by evals;
- `CONCEPTS.md` as grounding vocabulary for retrieval;
- `ce-retune`'s gate: no tuning claim without an A/B harness and a noise floor.

**Do not adopt the plugin as a whole.** It depends on its own skill set, on host-specific question
tools and subagents, and it releases almost daily. If a skill is ever used inside factory runs, it
goes into Havamal as a pinned, reviewed copy with a `skills.lock` entry, like every other skill
(spec §5.1). MIT allows that.

## 7. Open questions

- Does the Phase 5b plan already define the mechanism for criterion 7? If not, the compound node
  could be it.
- How should a lesson's effect be attributed: per lesson, or per bundle of lessons?
- What do the two unread papers in §3.3 add, especially on lessons that go stale when upstream
  changes?
- How do self-improving agent systems outside coding-agent tooling handle this, for example systems
  that rewrite their own code and keep only measured improvements?

## Sources

- EveryInc, [compound-engineering-plugin](https://github.com/EveryInc/compound-engineering-plugin),
  read at `2e41b44`: `README.md`, `STRATEGY.md`, `CONCEPTS.md`, `skills/ce-compound/`,
  `skills/ce-compound-refresh/`, `skills/ce-plan/references/agents/learnings-researcher.md`,
  `skills/ce-retune/SKILL.md`
- Kim, Kang, Kim, Yang, Ren and Hwang, [Memory Transfer Learning: How Memories are Transferred Across
  Domains in Coding Agents](https://arxiv.org/abs/2604.14004), arXiv, 2026-04-15
- IWE, [The benchmark that built the tools](https://iwe.md/blog/the-benchmark-that-built-the-tools/)
  and [iwe-org/memory-bench](https://github.com/iwe-org/memory-bench)
- [What Compound Engineering Actually Compounds](https://moclaw.ai/blog/compound-engineering), moclaw
- [Compound Engineering vs Loop Engineering](https://www.aibuilderclub.com/blog/compound-engineering-vs-loop-engineering),
  AI Builder Club
