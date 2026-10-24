---
title: Inventory of the factory's boundaries
status: accepted
date: 2026-10-24
related: [../../specs/2026-10-11-yggdrasil-v0-spec.md, ../2026-10-23-reviewers-see-the-diff/proposal.md]
style: spec
---

# Inventory of the factory's boundaries

Read on 2026-10-24 at yggdrasil `ea63ecb` (gungnir `f99e538`, odin `8b3fe33`), after run 1
(`20261024-000619-5b319d`) stopped at t002. It lists every place where one part of the factory hands something to
another: what crosses, its form today, whether anything checks it, and what has broken there. It is the input to
the typed-boundaries redesign.

**The goal (the founder's, 2026-10-24):** not identical runs, but a "semi deterministic result, where the whole
harness (graphs, loops, skills, etc) are providing as much determinism as possible without limiting the models",
so that models can be compared fairly.

Form: **typed** (a schema or a Go type, checked on read), **prose+JSON** (free text with a JSON document dug out of
it), **parsed prose** (Markdown read by a parser), **prose** (free text that nothing checks).

## 1. Into an agent session (what Odin sends)

Every prompt is a string that Odin concatenates (`odin/internal/engine/loop.go:110-127`, `stages.go:196-216`,
`loop.go:215-245`). No node declares what its prompt must hold, so nothing checks that it does.

| # | What crosses | Form today | Checked? | Seen |
| --- | --- | --- | --- | --- |
| 1.1 | The role's prompt (a graph's or a realm's Markdown file) | prose | no | B-170: the reviewers' prompts promised a `git diff` they could not run |
| 1.2 | Skills (`skills:` on a node) | prose, appended | no | — |
| 1.3 | The brief, as "## Brief", to every session | prose | no | — |
| 1.4 | The product owner's decisions (gate notes) | prose, one line each, appended | one line, no control characters (`decisions.go:44`) | — |
| 1.5 | "Your task": title, criteria, named test, leaf, dependencies | typed fields, rendered | fields clipped (200 / 30 × 1,000) | B-176: the task's text and contract are dropped by the parser |
| 1.6 | "The change": the task's diff, to the task reviewers | rendered from host git | cap 200 KB | B-170 fixed this; B-173, B-174 parked |
| 1.7 | "Your answer": the report format, to the reviewers | prose with a JSON example (`jormungandr/prompt.go:69-81`) | no | B-175 |
| 1.8 | Findings open from before | JSON in a fence | typed on the way out | — |
| 1.9 | Disputes format, to the implementer | prose with a JSON example (`prompt.go:86-94`) | no | — |
| 1.10 | Workspace inputs (`inputs:` folders seeded into scratch; the leaf for a loop) | files | paths and links only | — |

## 2. Out of an agent session (what Odin reads)

| # | Node | Output | Form today | Checked? | Who reads it | Seen |
| --- | --- | --- | --- | --- | --- | --- |
| 2.1 | design | `out/1-product/design/<date>-<slug>.md` | prose (sections asked for) | paths, scan; no structure | spec, conformance, the design gate (a person) | the open questions are prose; the gate note answers them in prose |
| 2.2 | spec | the spec's Markdown | prose (sections asked for, "Deviations" among them) | no structure | conformance, plan, the spec gate | run 1: deviations written as "Decisions" instead |
| 2.3 | spec | `out/leaves.yaml` | typed (`leaves.schema.json`) | yes | `ready`, `leaves`, routing | — |
| 2.4 | conformance | `out/conformance.json`, one document, nothing else | typed (`conformance.schema.json`) | yes; asked once more if unreadable (`scratch.go:71-74`) | the spec gate | the one output already built the way the redesign proposes |
| 2.5 | plan | `plan.md` | prose | no | people | — |
| 2.6 | plan | `tasks.md` | parsed prose (regex, `gungnir/schema/tasks.go`) → `features.json` | readiness (`ready.go`): fields present, size S/M, dependencies | Odin, then every task session | B-176: prose and fences dropped; sizes never measured (t001: "M", 797 lines) |
| 2.7 | reuse-review | a Markdown review | prose | no | nobody: published, no verdict, no gate | — |
| 2.8 | implementer | the code, in the leaf | the craft | the check ladder | reviewers, merge | — |
| 2.9 | implementer | its final answer: a summary, and disputes as the last JSON document | prose+JSON | the disputes only | Jormungandr; the summary goes to the ledger as text | t002: "I stopped because…" was prose; three paid attempts followed |
| 2.10 | three task reviewers | final answer: the report as the last JSON document | prose+JSON (`schema/event.go`, `lastDocument`) | the report schema | Jormungandr | B-175; the first run's `reviewer-unreadable` (missing `status`, `proof`) |
| 2.11 | every session | `gungnir.Result`: status, usage, failure kind, the answer up to 256 KB | typed envelope | yes | Odin, the meter | — |

## 3. Between the harness's own parts

| # | What crosses | Form today | Checked? | Seen |
| --- | --- | --- | --- | --- |
| 3.1 | Configuration: `factory.yaml`, `graph.yaml`, `pack.yaml`, the umbrella, `leaves.yaml` | typed (schemas in `gungnir/schema`) | on load | — |
| 3.2 | The graph's wiring: what each node needs and makes | implicit: folders by name (`inputs:`, `from:`, `reviews:`) | no type check between nodes | — |
| 3.3 | Checks (the realm's scripts) → findings | exit code and the log's tail, as one blocker at `<log>:1` (`gleipnir/checks/checks.go:86-100`) | typed envelope, prose content | which test failed is prose in the tail |
| 3.4 | The API contract between leaves | an agent copies the task's OpenAPI text into the web leaf's `contracts/` | the web leaf's `contract` check lints the copy and its generated types | B-176 left nothing to copy |
| 3.5 | Gates: what a person sees | a Markdown gate file, from typed data | — | — |
| 3.6 | Gates: what a person decides | approve or reject, and a one-line note or reason | one line; its meaning is prose | spec-gate notes carry product decisions as prose |
| 3.7 | The pointer-contract verdict | typed (verdict, evidence, reason) | yes | the first contract of a new project always stops (no index yet) |
| 3.8 | Ledger, `run.json`, `features.json`, the spend journal | typed (`ledger-event.schema.json` and Go types) | yes | — |
| 3.9 | Routing indexes: `REPOS.md`'s wiring block, `.ygg/impact.json` | typed, deterministic, no model | shrink guard, bench | — |
| 3.10 | The grader: the suite and the score | typed (`suite.schema.json`, `score.schema.json`) | yes | — |
| 3.11 | Adapters (`gleipnir`): Odin's `Task` → a CLI → `Result` | typed in Go (`gungnir/agent.go`); MCP shut off (`--strict-mcp-config`, spec §6.2) | yes | — |

## 4. Harness variance that is not about types

These make two runs differ for reasons other than the model, so they matter to a fair comparison.

- **The roles run on different CLIs.** The planner and implementer use Claude Code, the reviewer opencode. Each CLI
  has its own tools and system prompt, so a model comparison also compares CLIs unless the adapter is held fixed.
- **Wall-clock timeouts depend on the provider's speed.** Turn caps treat models alike; minute caps do not.
- **The plan's cut drives everything after it**, and nothing measures it: sizes are the planner's guess.
- **Agents fetch facts the harness could give:** the date (`date +%F` in four prompts), the contract copy (3.4).
- **Prose channels carry decisions:** gate notes (3.6) and the brief (1.3).
- **A check failure is coarse:** an exit code and a tail, not the failing tests (3.3).
- **An output nobody reads still costs a session:** the reuse review (2.7).

## 5. What already works this way

Configuration, the ledger, the grader, the routing indexes and `conformance.json` are typed end to end. The
conformance node shows the pattern for agent outputs: one file, one JSON document, validated, and asked again once
with the error when it does not validate.
