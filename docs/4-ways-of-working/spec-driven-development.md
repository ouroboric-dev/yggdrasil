---
title: Spec-driven development
status: accepted
date: 2026-10-11
related: [docs-standard.md, ../1-product/design/2026-10-11-yggdrasil-v0-design.md]
---

# Spec-driven development

How work goes from an idea to merged, verified code, for **Yggdrasil itself and for every product it
builds**. The process doesn't depend on any tool: Spec Kit, OpenSpec, BMAD, Superpowers or native
prompts are interchangeable ways of producing the artifacts it defines.

## 1. Principles

1. **Humans approve direction. Deviations from approved direction stop. Building within it is
   automatic.** Every approval point follows from this rule.
2. **Ceremony scales with the size of the change.** A bug fix doesn't need a design doc.
3. **The process defines artifacts, not tools.** Any tool may produce them; Odin checks that what it
   produced conforms.
4. **Specs stay alive.** A change in behaviour carries its spec change in the same merge.
5. **Checks, not promises.** Readiness, conformance, test-first and drift are checked mechanically
   wherever possible.

## 2. The three layers

| Layer | Question it answers | Typical author | Approval |
|---|---|---|---|
| **Design doc** (like a PRD) | *What* are we building, for *whom*, and *why*? Scope, success criteria, non-goals | the product role: a human brainstorming with an agent | **a human, in every mode by default.** It decides what gets built. Overriding this needs an explicit `gates: { design: auto }` |
| **Spec** (like an RFC) | *How* will engineering deliver the design? Architecture, contracts, data model, acceptance criteria per feature, decisions | an engineering agent | **automatic if it conforms to the design doc.** A design-conformance reviewer checks it; a deviation stops the run. Key-points mode may be set to always stop (`spec: stop`) |
| **Plan and tasks** | In what order, in which repo, proven by which tests? | an engineering agent | automatic in every mode except step-by-step |

The design doc is the handover from product to engineering. The spec must stay within it. When
engineering finds the design is wrong or incomplete, the run stops at `design` with a proposed
amendment rather than quietly building something else.

## 3. Tiers

| Tier | Example | Artifacts | Human approval |
|---|---|---|---|
| **1: fix or chore** | a bug, a dependency bump, a docs fix | one task: acceptance criterion and a **failing test that reproduces it** | none beyond approving the issue itself (it is the direction) |
| **2: small change** | a new gallery setting | a **change proposal** (acts as a mini design doc, §5) and 1–3 tasks | `design` |
| **3: initiative** | a new product, a new realm, payments | design doc → spec → plan → tasks | `design` |

When in doubt, use the higher tier. If hidden complexity shows up during the work, move up a tier and
stop at the matching approval point.

## 4. Stages and approval points

```
intent ─► design doc ─► [design] ─► spec ─► conformance review ─► [spec] ─► plan + reuse review
       ─► tasks + DoR check ─► [plan] ─► implement (TDD, fresh session per task)
       ─► check ladder + reviewers (typed findings) ─► [feature] ─► merge gate ─► [merge]
       ─► pointer move ─► [pointer | pointer-contract] ─► update living spec ─► journal
```

| Approval point | step-by-step | key-points (default) | unattended |
|---|---|---|---|
| `design` | stop | stop | stop (default; explicit override only) |
| `spec` | stop | auto, stop on deviation (option: `spec: stop`) | auto, stop on deviation |
| `plan`, `feature`, `merge`, `pointer` | stop | auto | auto |
| `pointer-contract` | stop | auto if the contract change was in the approved spec; stop if not | same, but the task is blocked and the rest continue |
| hard approval points | stop | stop | stop |

Hard approval points (`deploy-prod`, `store-submit`, `real-secrets-or-user-data`, `budget-cap`,
`external-input`, `policy-violation`, `shrink-guard`, and `guardrail-change` once self-hosting starts)
always stop and can't be configured away. The merge gate's mechanical steps (lock, update, re-check,
merge pinned to the reviewed commit) run on every merge whether or not a human approves it.

## 5. Canonical artifacts

These are part of the Gungnir contract. Every planning strategy must produce them; Odin rejects output
that doesn't conform.

### Design doc — `docs/1-product/design/YYYY-MM-DD-<slug>.md`

Front matter (`title`, `status`, `date`, `related`) and sections: intent; users; problems; scope and
non-goals; success criteria; constraints; open questions; decisions (`**Decided YYYY-MM-DD:** …`).

### Spec — `docs/2-engineering/specs/YYYY-MM-DD-<slug>.md`

Links its design doc in `related`. Sections: summary; architecture and components; interfaces and
contracts; data model; acceptance criteria per feature; security considerations; testing approach;
decisions; deviations from the design doc (must be empty for automatic approval).

### Plan and tasks — `docs/2-engineering/plans/YYYY-MM-DD-<slug>/`

`plan.md` (order, dependencies, risks) and `tasks.md`. Every task has:

| Field | Rule |
|---|---|
| `id` | stable, feature-scoped (`<plan>-T001`) |
| acceptance criteria | testable checkboxes |
| named test | file and test name that will prove it |
| `layer` | which leaf repo |
| `size` | S < 100 changed lines, M 100–400, L means split it |
| depends on | task ids |

The **Definition of Ready** check rejects any task missing one of these, and sends L-sized tasks back
for splitting.

### Change proposal — `docs/2-engineering/changes/YYYY-MM-DD-<slug>/`

For changing something that already exists (OpenSpec-style):

- `proposal.md`: why, what changes, impact (from the impact index);
- `delta.md`: the spec delta, as **added**, **modified** and **removed** requirements against the
  living spec;
- `tasks.md`: as above.

When the change merges, Odin folds the delta into the living spec (`docs/2-engineering/system/`) and
moves the folder to `changes/archive/`.

### Living spec — `docs/2-engineering/system/`

How the system works **today**. Dated design docs and specs are records of decisions and are not edited
after acceptance; the living spec is the current truth and changes only through deltas.

## 6. Keeping the spec alive

"Changing code without updating the spec" is the most common way spec-driven development fails.
Controls:

- **Same-merge rule:** a change in behaviour includes its delta in the same merge. The
  spec-compliance reviewer raises a finding for a behaviour change with no delta.
- **Traceability:** commits carry task ids; the doc↔code index shows code that no task explains and
  tasks that no code implements.
- **Decisions are searchable:** `**Decided …**` lines feed the decisions index, so agents look up why
  something was chosen instead of re-arguing it.

## 7. Implementation and review

- **One fresh agent session per task**, reading `AGENTS.md`, `progress.md`, its task, and the routing
  summary.
- **Test first:** the task's named test must fail on the parent commit, then pass.
- **Check ladder** per realm, then three read-only reviewers in order: **spec compliance**, **code
  quality**, **simplicity**. Reviewers report typed findings with stable ids; a finding closes only with
  proof.
- **Merge gate** on every merge and pointer move.

## 8. Strategies: where tools plug in

| Strategy | Stage | Options | Status |
|---|---|---|---|
| **planning** | design doc → spec → plan → tasks | native (v0); Spec Kit; OpenSpec; BMAD | v0 native; others benchmarked later |
| **reuse review** | plan | Ponytail (`ponytail-review` on the plan): flags new dependencies or abstractions where the standard library or existing code already does the job | v0 |
| **simplicity reviewer** | check ladder | Ponytail (`ponytail-review`) | v0 |
| **cleanup** (against Nidhogg) | periodic, per leaf | Ponytail (`ponytail-audit`) | later |

Rules for third-party strategies:

- **Invoke explicitly, never rely on auto-triggering.** In an independent JetBrains test, Ponytail
  activated on its own in zero of ten sessions.
- **Vendor a pinned, reviewed copy.** Feed the skill's instructions to the agent as part of its prompt;
  don't install plugin hooks. A compromised upstream update would otherwise run inside every session of
  every run.
- **Benchmark every strategy.** Same brief with and without it; compare the hidden score, lines of
  code, tokens and cost.

## 9. Using the process before the factory exists (stage 0)

Until Yggdrasil can build itself, humans and an interactive agent follow the same process by hand:

1. Brainstorm the design doc together (this is what the 2026-10-10/11 sessions produced:
   [`2026-10-11-yggdrasil-v0-design.md`](../1-product/design/2026-10-11-yggdrasil-v0-design.md)).
   For v0 the design doc also carries the engineering decisions, because it was written by hand in one
   pass; from the first change proposal on, design and spec are separate documents.
2. Write the implementation plan and tasks into `docs/2-engineering/plans/`.
3. Implement test-first, one task per session, with reviews and the same commit conventions.
4. Record challenges in the journal.

## 10. Self-hosting

Yggdrasil builds itself in stages:

| Stage | Who builds Yggdrasil | Needs |
|---|---|---|
| 0 | a human with an interactive agent | this process, followed by hand |
| 1 | Yggdrasil builds one of its own features | the change graph, a Go realm, `guardrail-change` |
| 2 | Yggdrasil improves itself from benchmark results | the benchmark kit (Mimir) and a release regression gate |

A factory that edits itself can weaken its own guardrails: an agent "fixes" a flaky test by deleting an
escape-attempt test, the next version ships with that hole, and that weaker version then reviews and
builds the version after it. Rules:

- **Never build in place.** The factory that runs is always the last released version pinned in L0,
  never the working copy being changed.
- **`guardrail-change` is a hard approval point.** Any change to approval points and modes, sandbox
  hardening, policies, ledger integrity or the escape-attempt suite stops for a human in every mode.
- **The security suite can't shrink silently.** Fewer escape-attempt or gate tests than before trips
  the shrink guard.
- **No release that regresses on benchmarks.**
