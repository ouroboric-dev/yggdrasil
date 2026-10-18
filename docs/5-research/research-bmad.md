---
title: "Research: BMAD Method v7 and bmad-loop"
status: draft
date: 2026-10-17
related: [curation.md, research-compounding.md, research-loops-graphs.md, ../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md]
style: research
---

# Research brief: BMAD Method v7 and bmad-loop

Prepared 2026-10-17. It asks what BMAD Method is today, what in it Yggdrasil should borrow, and how it
relates to the self-improvement loop in [research-compounding](research-compounding.md).

BMAD Method was read at commit `cfba3ff` (2026-10-16) on `main`, which carries the v7 preview. bmad-loop
was read from its README. Stars, forks and release data come from the GitHub REST API on 2026-10-17.

**How to read the evidence labels** (the same as in [research-loops-graphs](research-loops-graphs.md))
- **[PROVEN]**: primary source with concrete numbers, a reproducible artifact, or official
  documentation. Here it mostly means "read in the project's source or docs".
- **[CREDIBLE]**: primary source, but self-reported by an interested party with no independent check.
- **[EARLY / HYPE]**: secondary commentary, vendor marketing or anecdote.
- **[ANALYSIS]**: the author's own judgement, recommendation or inference, not a sourced fact.

---

## 0. TL;DR

1. **BMAD v7 is no longer a persona pipeline** **[PROVEN]**. Five personas remain, but the core is a
   set of skills that size the process to the work: `bmad-spec`, `bmad-ticket`, `bmad-build`,
   `bmad-build-auto`, `bmad-retrospective`, `bmad-eval`, `bmad-project-context`. The curation entry
   from 2026-10-11 described v4 to v6.
2. **`bmad-build-auto` is a worker contract for an outside orchestrator** **[PROVEN]**. One run builds
   one unit, never picks the next, and writes a typed terminal status into the plan's frontmatter.
   That is the shape of an Odin agent node.
3. **bmad-loop is the closest relative of Odin and Jormungandr found so far** **[PROVEN]**. It is a
   deterministic Python control loop: "no LLM in the control loop." It has no container sandbox.
4. **The retrospective and the eval runner fill parts of the self-improvement loop** **[PROVEN]**. The
   retrospective asks of every finding "what would prevent the next one" and checks whether the last
   retro's actions landed. The eval runner makes one change per round and reverts on regression.
5. **Its theory of project context matches independent studies** **[CREDIBLE]**. BMAD does not cite
   them; §5 traces them.
6. **[ANALYSIS]** Borrow the contracts and the guards. Do not adopt the method: v7 is an alpha with
   breaking changes, and its skills render themselves at run time.

---

## 1. What BMAD Method is

| Field | Value |
|---|---|
| URL | https://github.com/bmad-code-org/BMAD-METHOD |
| Owner | BMad Code, LLC |
| Stars / forks | 54,264 / 6,098 |
| Created | 2025-04-13 |
| Activity | Last push 2026-10-17. Stable `v6.12.4` (2026-10-14). The README calls v7 a "preview alpha" on `main` with a release ETA of 2026-10-16; no v7 tag existed on 2026-10-17. |
| Licence | MIT for the code. The README and `TRADEMARK.md` say "BMad", "BMad Method" and "BMad Core" are trademarks "covering all casings and variations" and are not licensed under MIT. |
| Contributors | 30 or more. The top two accounts are `alexeyv` (693 commits) and `bmadcode` (236). |
| Hosts | Installs skills for Claude Code, Codex, Cursor, Cline, Antigravity and others; v7 installs through `npx skills add` or a Claude Code or Codex plugin marketplace. |
| Shape | 33 skills in `skills/`, Python tooling in `tools/` run through `uv`, an Astro docs site |

The README describes it as "the agile way" to do AI-driven development, where "decisions stay
explicit, context carries forward, and the process sizes itself to the work. Small changes go straight
to build."

Official modules add a skill builder, a creative suite, a test architect, a games studio (Unity,
Unreal, Godot, Phaser) and bmad-loop (§4).

## 2. The v7 delivery model

All of §2 is **[PROVEN]** from `docs/`.

- **One question decides the planning path:** is the intent well defined? A well-defined intent "says
  what should be true when the work is done, what must not change, and what is out of scope."
- **`bmad-spec`** condenses any intent into one short contract. The docs warn that it reads its input
  in one pass, with "a practical ceiling" of "a few tens of thousands of tokens."
- **Size follows the intent.** A spec that fits one session goes to `bmad-build`. An epic goes to
  `bmad-ticket`, which writes ordered stories into the epic's `tickets.toml`, then one build per
  story. A project (about 20 or more sessions) adds a PRD and architecture documents and runs
  `bmad-spec` once per epic.
- **"Every path uses the same implementation unit."** Larger work adds shared context around the unit
  and repeats it.
- **Optional tools before the spec:** brainstorming, `bmad-forge-idea` (pressure-test an idea),
  `bmad-deep-recon` (cited research), product brief, PRFAQ, PRD, UX and architecture.
- **Personas are optional.** Analyst (Mary), Product Manager (John), Architect (Winston), Developer
  (Amelia) and UX Designer (Sally) remain as menus over the same skills.

## 3. The worker contract: `bmad-build-auto`

From `docs/build/autonomous-development-loops.md` **[PROVEN]**:

- **One unit per run.** It clarifies, plans, implements and reviews one intent or ticket. "It never
  picks the next ticket itself." A human or orchestrator "owns backlog policy and dispatch."
- **State lives in the plan file.** The plan's frontmatter `status` runs `draft`, `ready-for-dev`,
  `in-progress`, `in-review`, `built`, `done`, `blocked`, `dropped`. A re-dispatch resumes from that
  status.
- **It never marks work done.** It stops at `built`; "the user or an orchestrator" marks `done`.
- **Typed blocking conditions**, among them `unclear intent`, `intent gap`, `no subagents`,
  `implementation verification failed`, and `review repair loop exceeded 5 iterations
  (non-convergence)`.
- **Machine-readable results:** `baseline_revision`; `risk` (`low`, `medium`, `high`), "the business
  impact if the change is wrong," which "a CI process can read … to decide how much review the change
  gets"; `followup_review_recommended`; and `deferred` findings with summary, evidence, location and
  severity.
- **Deferred findings are "intentionally not a backlog."** The orchestrator decides whether to open a
  ticket, queue them, merge duplicates across runs, or drop them.
- **An intent gap leaves evidence.** When review halts on one, the attempted change is saved as a patch
  beside the plan. It shows which reading of the intent the run built.
- **It commits but does not push**, and leaves a clean working copy.
- **"Handle `blocked` as a routing signal, not just a failure signal."**

## 4. The orchestrator: bmad-loop

| Field | Value |
|---|---|
| URL | https://github.com/bmad-code-org/bmad-loop |
| Stars | 160 |
| Created | 2026-06-19 |
| Activity | Last push 2026-10-17. Latest release `v0.13.2` (2026-10-10). The README says "early open beta" with "breaking changes in any pre-1.0 release." |
| Licence | MIT (copyright BMad Code, LLC) |
| Language | Python 3.11+, tmux, git 2.34+ |

From the README **[PROVEN]**:

- **A deterministic loop.** "Plain Python drives the loop — pick story → implement → adversarially
  review → verify → commit — while LLMs do only the creative work." Story selection, retry budgets,
  gates and completion checks are code.
- **Completion is an event, not prose.** A session counts as complete "only on a completion event from
  the coding agent or the death of its session, never on model prose." Timeouts, stalls and budget
  caps end it as a failure.
- **Verification after every session:** spec status, baseline commit, a non-empty diff, the board in
  sync, then the project's own `[verify]` commands.
- **Fresh-context review**, "optionally on a different CLI or model," capped at
  `max_review_cycles` (default 3).
- **One board writer.** bmad-loop alone writes `sprint-status.yaml` during a run, and board writes
  "never move a story backward."
- **Unattended by design.** Runs resume from on-disk state. A story that never converges is deferred
  and the run continues. A critical escalation pauses the run and writes an `ATTENTION` file.
- **A deferred-work ledger** (`DW-<n>` entries) that `bmad-loop sweep` triages against the code.
- **Six CLIs** (`claude`, `codex`, `gemini`, `copilot`, `antigravity`, `opencode`) as TOML profiles,
  mixable per stage, with cost-weighted token budgets.
- **Isolation is optional worktrees.** The README describes no container sandbox. Agents run in tmux
  sessions on the host and commit in the repository.

## 5. Project context, and the evidence behind it

`docs/existing-codebases/theory-of-project-context.md` opens: "Most documentation written for AI
agents makes them worse." Its rules **[PROVEN]**:

- A line belongs in `AGENTS.md` only if removing it would change agent behaviour.
- Keep policy the code cannot express, divergences from ecosystem defaults, pitfalls "from observed
  failure only," cross-component rules and required versions.
- Leave out what the code says, file maps, overviews, ecosystem defaults, history and aspirational
  state.
- "A working rule stays": "Absence of recent failures is never grounds" for removal, because "a working
  rule erases the evidence that it is still needed."
- Implementation context (tiny, per repository) and planning context (rationale, rejected options, per
  initiative) are separate artifacts.

The page states its evidence without citations. Two sources match it:

- **ETH Zurich, "Evaluating AGENTS.md"** (Gloaguen, Mündler-Sasahara, Müller, Raychev and Vechev;
  [arXiv 2602.11988](https://arxiv.org/abs/2602.11988), February 2026, revised September 2026)
  **[CREDIBLE]**: "providing context files does not generally improve task success rates," for both
  LLM-generated and developer-committed files, and they raise inference cost by over 20% on average.
  Repository overviews did not help. The authors say context files are useful for non-standard
  practices and that any use "should be rigorously evaluated before deployment."
- **Vercel, "AGENTS.md outperforms skills in our agent evals"**
  ([blog](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals), January 2026)
  **[CREDIBLE]**, on Next.js 16 APIs absent from training data: no docs 53%, a skill 53%, the skill
  with explicit instructions to use it 79%, and an 8KB compressed docs index in `AGENTS.md` 100%. The
  skill was never invoked in 56% of cases.

BMAD draws the lesson: "Agents often skip retrieval they have to choose." An index "already in
context" is used; one the agent must decide to fetch is skipped.

## 6. The improvement parts: retrospective and eval

### 6.1 `bmad-retrospective`

From `docs/build/finish-an-epic.md` and `references/acceptance-verdict.md` **[PROVEN]**:

- It runs when every ticket of an epic is finished, because "the bugs that survive to this point are
  the ones isolation hides."
- It reads evidence, not memory: the epic file, each plan, the diff and commits from each plan's
  `baseline_revision`, and the previous retrospective. "A claim it can't point at doesn't make the
  report."
- **Two dispositions per finding.** One is "what to do about this instance": fix now, defer, or
  accept. The other is "what would prevent the next one": "spec wording, story sizing, a missing
  convention or gate, or nothing. This is where a recurring finding becomes a process change."
- **Follow-through.** It checks each action item of the previous retrospective against a commit, file
  or test. An item without a source is "no evidence found", not "not done."
- **A verdict:** `accepted`, `accepted-with-open-items` or `rejected`. Any unfinished ticket makes it
  `rejected`.
- It proposes and never applies: action items, spec reconciliations and decision records all wait for
  a human.

### 6.2 `bmad-eval`

From `skills/bmad-eval/` **[PROVEN]**:

- **Four modes:** baseline (does the skill beat the bare model?), variant (does a section earn its
  place?), quality (against a rubric), trigger (does the description fire on the right queries?).
- **Clean rooms.** Each case runs in a temporary folder with only the skill staged, so "host config,
  prior runs, the project's instruction files and its installed skills cannot bias the result."
- **Repetition.** "A result from fewer than 3 runs per case … is reported as a quick look, never as
  settled."
- **Retirement.** "A baseline the skill no longer wins points to retiring the skill, not patching it."
- **A bounded self-improvement loop** (`references/self-improvement.md`): review, eval, propose one
  fix, apply and re-eval. "One change per round"; "revert on regression"; a hard round bound; "the
  benchmark is a guardrail, never the judge. The human stays the judge." It warns against fixing the
  failing case instead of its class, and treats "ALL-CAPS ALWAYS or NEVER" fixes as a symptom patch.

## 7. Criticism

- **Token cost.** Issue [#1235](https://github.com/bmad-code-org/BMAD-METHOD/issues/1235), opened
  2026-01-01 against a v6 alpha, reported 82,100 and 96,500 tokens for two analysis steps of one story,
  on a PRD of about 1,400 lines and an architecture document of about 4,800 lines. The maintainer
  closed it on 2026-02-18, saying fixes were coming for 6.1 **[PROVEN]**. This brief did not confirm
  that they shipped.
- **Weight.** Practitioner comparisons call BMAD the heaviest of BMAD, Spec Kit and OpenSpec, best for
  large or greenfield work and excessive for small fixes **[EARLY / HYPE]**. No controlled comparison
  was found. These posts mostly predate v7's right-sizing.
- **Churn.** v7 renames skills (old names forward), and the README warns of breaking changes between
  preview updates **[PROVEN]**.

## 8. Fit with Yggdrasil

All of §8 is **[ANALYSIS]**.

### 8.1 As a planning strategy

The [SDD process](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/4-ways-of-working/spec-driven-development.md)
already names BMAD as an interchangeable planning strategy, to be benchmarked after v0. v7's
`bmad-spec` and `bmad-ticket` are much lighter than the v6 pipeline, which makes the comparison
cheaper to run. Wait for a stable v7.

### 8.2 The worker contract, for Odin's agent nodes

- Typed blocking conditions map to Odin's escalations and the ledger's events.
- `risk` at planning time could set review depth, as an input to the check ladder.
- Deferred findings as review output, not backlog, matches typed findings with Odin as their router.
- Saving the attempted change as a patch on an intent gap gives the human evidence at an approval
  point.
- "Never on model prose" matches Yggdrasil's choice that checks, not an agent's own report, decide
  whether work passes (the check ladder, spec §9.5).

### 8.3 bmad-loop, against Odin and Jormungandr

The two designs agree on almost every structural choice: code owns the loop, fresh-context review on a
different model, verification after every session, one writer of state, resumable runs, capped
retries, deferred work. The differences are where Yggdrasil's guardrails are:

- bmad-loop runs agents on the host; Gleipnir runs them in rootless containers.
- bmad-loop verifies with the project's own commands; Yggdrasil adds a hidden suite the agents never
  see.
- bmad-loop has a TUI already; Yggdrasil's terminal UI is an iteration-2 candidate.

It is worth reading closely before Odin's next iteration, especially `sweep` and its escalation guide.

### 8.4 The self-improvement loop

[research-compounding](research-compounding.md) found that Compound Engineering supplies a lesson store
but no measurement. BMAD supplies two other pieces:

- the retrospective's second disposition, "what would prevent the next one," is the step from a
  finding to a process change, and its follow-through check is a cheap first measurement;
- `bmad-eval`'s guards (one change per round, revert on regression, round bound, three runs, the human
  as judge) are a ready design for the "A/B bench" step, and match Havamal's eval rule (spec §5.1).

### 8.5 Context

The studies in §5 support two existing choices: `AGENTS.md` as "a map, not a manual," and Odin
injecting the routing summary into each session (spec §8.1) instead of leaving retrieval to the agent.
They also warn that lessons retrieved on demand, as Compound Engineering does, may be skipped. Lessons
that must change behaviour should be injected.

### 8.6 Other realms

`bmad-forge-idea`, `bmad-prfaq` and `bmad-product-brief` are worth reading for the Asgard realm's
kickstart. The Game Dev Studio module is worth reading when Jotunheim starts.

## 9. Risks of borrowing

All of §9 is **[ANALYSIS]**.

- **Trademark.** Code may be copied under MIT, but no Yggdrasil component or skill may carry the BMad
  name in any casing.
- **Vendoring.** Each v7 `SKILL.md` runs `uv run render_skill.py` to render its workflow from project
  config at run time. A pinned, hash-checked Havamal copy would pin the templates, not what the agent
  reads. The skills also execute Python inside the sandbox.
- **Churn.** Anything borrowed from a v7 alpha should be pinned to a commit and re-read after v7 ships.

## 10. Open questions

- Did the 6.1 token fixes ship, and what does a v7 story cost in tokens?
- Does bmad-loop's escalation model (pause, `resolve`, `confirm`) handle cases Odin's approval points
  do not?
- Can `bmad-eval`'s case format and Havamal's evals share one format, so skills move between them?

## Sources

- bmad-code-org, [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD), read at `cfba3ff`:
  `README.md`, `LICENSE`, `TRADEMARK.md`, `AGENTS.md`, `docs/plan/choose-a-planning-path.md`,
  `docs/reference/skills-and-agents.md`, `docs/existing-codebases/theory-of-project-context.md`,
  `docs/build/autonomous-development-loops.md`, `docs/build/finish-an-epic.md`,
  `skills/bmad-retrospective/`, `skills/bmad-eval/`
- bmad-code-org, [bmad-loop](https://github.com/bmad-code-org/bmad-loop), README
- Gloaguen et al., [Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding
  Agents?](https://arxiv.org/abs/2602.11988), arXiv, 2026
- Vercel, [AGENTS.md outperforms skills in our agent evals](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals),
  January 2026
- [Issue #1235: Excessive Token Usage in Workflows](https://github.com/bmad-code-org/BMAD-METHOD/issues/1235)
- Practitioner comparisons: [Reenbit](https://medium.com/@reenbit/bmad-vs-spec-kit-vs-openspec-choosing-your-spec-driven-ai-framework-in-2026-a6996b3ebb8d),
  [ranthebuilder](https://ranthebuilder.cloud/blog/i-tested-three-spec-driven-ai-tools-here-s-my-honest-take/),
  [nosam](https://www.nosam.com/spec-driven-development-openspec-vs-spec-kit-vs-bmad-which-ones-actually-worth-your-time/),
  [Mad about BMAD?](https://amboris.medium.com/mad-about-bmad-91b343813434)
