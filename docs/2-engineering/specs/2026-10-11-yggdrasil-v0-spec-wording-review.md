---
title: v0 spec wording review (style pass)
status: superseded
date: 2026-10-12
related: [2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

> **Resolved 2026-10-12; kept as a record.** The founder confirmed items 1–19, 21–28, 30–36, 38, 39 and
> 41–58 as written, confirmed the readings of #3 (SHOULD), #14 (a pointer move runs rungs 1–5 and the
> umbrella's acceptance tests) and #40 ("later" means iteration 2), and decided three changes in the
> spec: #20, an own skill's eval MUST show a gain; #29, only `extracted` or `oasdiff` evidence
> triggers `pointer-contract`, with acceptance tests catching the rest; #37, a bump MUST NOT roll out
> if the canary's suite fails. Both factual slips listed in (c) were already fixed. The spec is
> accepted.
>
> Review aid from the 2026-10-11 style pass. The spec's requirements were rewritten with RFC 2119 keywords and ASD-STE100 sentences. This list shows every requirement whose meaning might have shifted, so a human can confirm each one. Archive or delete this file once the spec is accepted.

# Style pass: `spec` (yggdrasil/docs/2-engineering)

Style source: `ouroboric/docs/4-ways-of-working/writing-styles.md` (`spec`: Google developer style for prose; ASD-STE100 for requirement sentences; RFC 2119 keywords).
Backups of the originals: `style-pass/orig-spec/` (spec.md, specs-README.md, changes-README.md, plans-README.md, system-README.md).

Verification (script `style-pass/check_spec.py`): front matter, all 58 heading lines, all 19 link targets and all 8 code blocks are byte-identical to the originals in every file. No table was removed.

## (a) Per-file summary

### specs/2026-10-11-yggdrasil-v0-spec.md
- Requirements now use RFC 2119 keywords. This covers isolation rules (§3.3), pointer-move rules (§3.4), DoR and spec-deviation rules (§4.2), checkpoints (§4.3), the merge gate (§4.5), typed findings (§4.6), adapters and privacy (§5), skills (§5.1), sandbox hardening and credentials (§6.2, §6.3), approval mechanics (§7.2), the budget cap (§7.4), routing guards (§8), web-realm design rules (§9.3), check-ladder security rungs (§9.5), dependency policy (§9.6), the ledger (§10.1), the tracker (§10.4), journal scrubbing (§10.5), benchmark isolation (§11), `run.json` atomicity (§12), test expectations (§13), GitHub identities (§15.1, §15.2), self-hosting guardrails (§15.4), docs (§15.5) and the licence rule (§17).
- Long sentences split, so each sentence carries one rule or fact. Conditions now come first ("If a leaf does not exist, create it…").
- Passive voice changed to active where the actor is stated in the original (for example, "The implementation plan settles the exact method sets"). Where the original names no actor, the passive stays, so that no actor is invented.
- Pronouns made explicit ("Odin commits the planner's output", "each finding took to close").
- Restructured as lists for readability, with no facts added or removed: §10.2 metrics (bullets), §13 unit tests (nested bullets), §15.1 GitHub Apps (sub-bullets), §15.2 MIP-0063 lessons (bullets), §15.4 stages and guardrails (bullets).
- Tables: the only cell changed is §3.2 ("children MAY tighten them but MUST NOT loosen them"). The other cells were already short or are lists of facts, so I left them alone.

### specs/README.md
- Added a subject ("This folder holds…"). "linked to the design doc" became "Each spec MUST link to…". "Not edited after acceptance" became "A spec MUST NOT be edited after acceptance."

### changes/README.md
- Turned the noun phrase into full sentences. "Merged proposals move to `archive/`…" became "A merged proposal MUST move to `archive/` after its delta is folded into `../system/`."

### plans/README.md
- Added a subject. "Every task passes the Definition of Ready" became "Every task MUST pass the Definition of Ready".

### system/README.md
- Added a subject. "Updated only through…" became "It MUST be updated only through…". The empty-until-v0 sentence is now two sentences.

## (b) Requirements whose meaning might have shifted

Each entry shows the old wording, then the new wording, then the reason to check it. Entries marked **[security]** touch a control. A wrong reading there could open a real hole, so check those first.

1. **§1 Version tagging.** "Versions are tagged only when an interface settles." → "Versions MUST be tagged only when an interface settles." Reason: descriptive became normative.
2. **§1 Interface location.** "Interfaces live only in `gungnir`" → "Interfaces MUST live only in `gungnir`." Reason: same as item 1.
3. **§3.1 Adding a tree level.** "Add a level only when a subtree has its own contract and its own acceptance tests." → "A new level SHOULD be added only when…". Reason: the original imperative has no RFC strength. I chose SHOULD (guidance), not MUST. If it is meant as a hard rule, change it to MUST.
4. **§3.1 Node metadata [security].** "Every node records `owner`… and `visibility`" → "Every node MUST record…". Reason: descriptive became normative.
5. **§3.1 Consequences [security].** "no secrets or hidden tests in any repo, and an operator warning if a public L0 lists private projects" → "A repo MUST NOT contain secrets or hidden tests. If a public L0 lists private projects, the factory MUST warn the operator…". Reason: the noun list became explicit MUST rules. The warning is attributed to "the factory", following "The factory only applies the consequences".
6. **§3.3 rule 4 [security].** "At most it is mounted read-only" → "If the git directory is mounted, it MUST be mounted read-only." Reason: same meaning in my reading ("at most read-only", or not mounted). The heading lead "Leaf git data is out of reach" became "MUST be out of reach".
7. **§3.3 rule 6.** "never `--recursive` from L0" → "Odin MUST NOT initialise submodules with `--recursive` from L0." Reason: I added the verb "initialise" to make the sentence complete.
8. **§3.4 One level per move.** "One level per move; each move requires that level's own tests to pass." → "A move MUST span one level only. That level's own tests MUST pass before the move." Reason: "before the move" makes the timing explicit.
9. **§4.2 Decision lines.** "with decisions recorded as `**Decided YYYY-MM-DD:** …` lines" → "The plan MUST record decisions as … lines." Reason: a format description became a MUST.
10. **§4.2 DoR size L.** "L means split: back to the planner" → "An L task MUST be split, so it goes back to the planner." Reason: the implied rule became explicit.
11. **§4.2 init.** "…, first commit." → "The node ends with the first commit." Reason: this keeps the original ambiguity about who commits (agent+exec node). It does NOT say the agent commits, which §3.3 rule 3 forbids.
12. **§4.3 Re-runnable nodes.** "Nodes are designed to be safe to re-run." → "Every node MUST be safe to re-run." Reason: a design intent became a requirement.
13. **§4.4 Clean sessions.** "Every agent session starts clean" → "Every agent session MUST start clean." Reason: descriptive became normative.
14. **§4.5 step 3, pointer-move checks.** "ladder rungs 1–5 for a leaf merge, plus the umbrella's acceptance tests for a pointer move" → "For a leaf merge, run ladder rungs 1–5. For a pointer move, add the umbrella's acceptance tests." Reason: "add" is meant to keep the original "plus" reading (rungs 1–5 and acceptance tests). Please confirm that is the intent.
15. **§4.5 step 4.** "Anything else aborts and returns to the loop." → "Otherwise, abort and return to the loop." Reason: same meaning; please confirm.
16. **§4.6 Malformed retry.** "is retried once as an agent failure" → "it MUST be retried once as an agent failure." Reason: descriptive became normative. No actor was added.
17. **§5 Adapters [security].** "Adapters use each tool's native headless protocol…, never screen-scraping" → "Adapters MUST use… Adapters MUST NOT screen-scrape a terminal UI."
18. **§5 Privacy [security].** "Policy tightens only, going down" → "Policy MUST only tighten going down". "`privacy: strict` restricts…" → "MUST restrict…".
19. **§5.1 Havamal inclusion [security].** "Only skills with redistributable licences, vendored from public upstreams, may be included; organisation-internal skills never are." → "Havamal MUST include only skills that… Organisation-internal skills MUST NOT be included." Reason: the original names no subject. I chose Havamal, the skill library. "may be included" in the original works as a restriction ("only X may"), so MUST-only fits.
20. **§5.1 Own-skill evals.** "each ships only with an eval showing it measurably improves agent behaviour" → "Each of our own skills MUST ship with an eval. The eval shows that the skill measurably improves agent behaviour…". Reason: the split moves "measurably improves" into a descriptive sentence. If the improvement itself is a ship gate, make the second sentence "The eval MUST show…".
21. **§5.1 Updates.** "updates are reviewed pull requests" → "Updates MUST be reviewed pull requests."
22. **§6.2 Factory-owned config [security].** "is passed with `--config`, and is never mounted" → "It is passed with `--config`. It MUST NOT be mounted." Reason: "passed with --config" stays descriptive.
23. **§6.2 Egress [security].** "default deny; allowlist for the model APIs and package registries the realm needs" → "the default MUST be deny. An allowlist opens only the model APIs and package registries that the realm needs." Reason: I added "only". The original implies it through "default deny", but check it.
24. **§6.3 Credentials [security].** "A model credential must be in the sandbox, so it is dedicated and revocable" → "The sandbox needs a model credential, so that credential MUST be dedicated and revocable." Reason: the original lowercase "must" described a necessity, not a requirement. "Never the operator's main login files" → "The sandbox MUST NOT get the operator's main login files."
25. **§7.2 Auto-pass [security].** "still writes the gate file and logs `gate_auto_passed`" → "Odin MUST still write the gate file and log `gate_auto_passed`." Reason: the actor (Odin) is inferred from "Stop:" in the same list.
26. **§7.2 Config.** "Mode switches are allowed at any pause; a switch to a looser mode is logged." → "Mode switches MAY happen at any pause. A switch to a looser mode MUST be logged."
27. **§7.4 Budget cap.** "Hitting a cap stops the run with everything resumable." → "When a run hits a cap, it MUST stop with everything resumable."
28. **§8.1 Bundles.** "built by deterministic exec nodes (no model calls), stored outside the agent's mount" → "Deterministic exec nodes MUST build the bundle, with no model calls. The bundle MUST be stored outside the agent's mount."
29. **§8.2 Edge tags and pointer-contract [security].** "Odin only treats a pointer move as `pointer-contract` on `extracted` evidence or on `oasdiff`" → "Odin MUST treat a pointer move as `pointer-contract` only on `extracted` evidence or on `oasdiff`." Reason: the meaning is the same, but this rule decides when a human approval point fires, so it deserves a check. With this rule, `inferred` edges alone never trigger `pointer-contract`.
30. **§8.2 Later indexes.** "each only if it beats the bench" → "Each one ships only if it beats the bench." (descriptive). Compare §8.3, where "An index ships only if it raises the right-first score" → "An index MUST NOT ship unless it raises the right-first score."
31. **§8.3 Shrink guard and model files.** "is refused if…" → "MUST be refused if…". "pinned by hash, loaded only as `safetensors`" → "MUST be pinned by hash. They MUST be loaded only as `safetensors`."
32. **§9.2 Producer builds.** "A consumer never builds its producer from source" → "A consumer MUST NOT build its producer from source."
33. **§9.3 Design rules [security].** All five rules became MUST/MUST NOT. "Download-all zips are built in the browser…, falling back to per-photo downloads" stays descriptive: "The browser builds… If a browser cannot stream, it falls back…". "Storage keys: bucket-scoped, with object versioning on" → "MUST be bucket-scoped. Object versioning MUST be on."
34. **§9.5 rung 4 [security].** The check items became MUST statements ("the bucket MUST refuse anonymous reads", "PIN attempts MUST be rate-limited", and so on). Reason: these describe what the rung enforces, so they read as requirements on the product.
35. **§9.5 rung 6.** "spec compliance (…), then simplicity (…), then code quality" → "run in this order: spec compliance, then simplicity, then code quality". Reason: "in this order" makes the "then" sequence explicit.
36. **§9.5 rung 7 [security].** "the hidden benchmark suite (§11), run by Odin in a separate grader container…, results to the ledger only, never to agents" → "Odin MUST run… Results MUST go to the ledger only. Results MUST NOT go to agents."
37. **§9.6 Dependency policy.** Imperatives became MUST. The original "Roll version bumps to one canary product first, run its suite, then roll out in batches" → "A version bump MUST roll to one canary product first. After the canary's suite runs, the bump rolls out in batches." Reason: like the original, this does not say the canary suite must *pass* before rollout. If that is intended, add it in a design change, not here.
38. **§10.1 Ledger.** "written only by Odin, schema-versioned, flushed to disk per line" → "Odin MUST be its only writer. The file MUST be schema-versioned and flushed to disk per line." "Field names follow… `gen_ai.*`" → "MUST follow".
39. **§10.2 Run report.** "Every run report records the factory version and config hash" → "MUST record".
40. **§10.4 Tracker inputs [security].** "the only inputs read back: human-approved work (through `external-input`), and later approvals" → "the tracker MUST read back only these inputs: human-approved work (through `external-input`) and, later, approvals". Reason: I read "later approvals" as "approvals, in a later iteration". If it means "subsequent approvals", the commas change the meaning.
41. **§10.5 Private lessons [security].** "Lessons from private product runs are recorded in the private L0 instance first, and only distilled, anonymised versions move to the public journal." → "…MUST be recorded in the private L0 instance first. A lesson MUST be distilled and anonymised before it moves to the public journal."
42. **§10.5 When to record.** "a decision whose result is still pending is worth recording at once" → "A decision SHOULD be recorded at once, even if its result is still pending." Reason: "worth" maps to SHOULD.
43. **§10.5 Scrubbing [security].** "Private evidence is linked from L0, and only aggregate numbers are quoted publicly." → "Private evidence MUST be linked from L0. Public text MUST quote only aggregate numbers."
44. **§11 Scoring.** "tests that must start passing ("fail to pass") and tests that must stay green ("pass to pass")" → ""fail to pass" tests MUST start passing. "Pass to pass" tests MUST stay green." Reason: the lowercase "must" in the original was definitional. It is now an RFC keyword.
45. **§11 Black-box.** "hidden tests use what the brief describes" → "hidden tests MUST use only what the brief describes". Reason: I added "only", from the "Black-box only" lead.
46. **§11 v0 hidden suite.** "is written before the first factory run, from the brief alone, by the operator (optionally with a separate agent session that never sees factory runs or their code)" → "The operator MUST write… before the first factory run, from the brief alone. The operator MAY use a separate agent session for this, if that session never sees factory runs or their code." Reason: a plan statement became MUST. The "never sees" clause is now a condition of the MAY.
47. **§12.** "`run.json` is written atomically" → "MUST be written atomically".
48. **§13 Factory repos.** "Each factory repo has a Go devcontainer and a short `AGENTS.md`, and is built test-first." → two MUST sentences.
49. **§15.1 Rulesets.** "Rulesets on every `main`: PR required, checks required, one human approval; bypass for admins and the merge bot." → "Every `main` MUST have a ruleset that requires a PR, required checks and one human approval. Admins and the merge bot MAY bypass the ruleset." "External contributors always need a human review" → "MUST always get a human review".
50. **§15.1 Tokens [security].** "Tokens minted per operation, limited to one repo and minimal permissions, valid one hour." → "Tokens MUST be minted per operation. Each token MUST be limited to one repo and minimal permissions. Each token is valid for one hour." Reason: I kept the one-hour validity descriptive, not "at most one hour".
51. **§15.1 External input [security].** "Only human-approved work (an `agent-ready`-style label or the brief) becomes factory work (`external-input`)." → "Work MUST NOT become factory work unless a human approved it (`external-input`). Human approval comes from an `agent-ready`-style label or the brief."
52. **§15.1 Optional App pair.** "optionally one App pair per product org" → "An operator MAY use one App pair per product org."
53. **§15.1 Public repo filing.** "No automatic filing to the public factory repo from private runs." → "Private runs MUST NOT file anything automatically to the public factory repo."
54. **§15.2 GitHub approval [security].** "Approval from GitHub, if added, accepts only the operator's account…, never comment text alone." → "If approval from GitHub is added, it MUST accept only the operator's account… It MUST NOT accept comment text alone." "`Closes #N` must be in…" → "MUST be in…".
55. **§15.4 Guardrails.** "never build in place (the running factory is always the last released version pinned in L0)" → "The factory MUST NOT build in place. The running factory MUST always be the last released version pinned in L0." "the security suite can't shrink without it" → "MUST NOT shrink without `guardrail-change`". "no release that regresses on benchmarks" → "A release that regresses on benchmarks MUST NOT ship." Reason: "ship" stands in for the original noun phrase "no release".
56. **§15.5 Docs.** "Every umbrella and leaf follows the docs standard" → "MUST follow".
57. **§17 Licence rule.** "we don't copy their code unless the licence allows it" → "We MUST NOT copy their code unless the licence allows it."
58. **READMEs.** "linked to the design doc they implement" → "Each spec MUST link to the design doc that it implements". "Not edited after acceptance" → "MUST NOT be edited after acceptance". "Merged proposals move to `archive/`" → "A merged proposal MUST move". "Every task passes the Definition of Ready" → "MUST pass". "Updated only through the spec deltas" → "MUST be updated only through".

## (c) Deliberately left unchanged

- **Every heading, link target, code block, the front matter and the metadata table.** The task's hard constraints require this.
- **The §7.1 rule line ("humans approve direction; deviations from approved direction stop; building within it is automatic").** It is a principle that sums up the table, not one requirement. Rewriting it in RFC form would duplicate the table.
- **The §7.1 approval table, the §14 threat table, the §17 prior-art table and the §18 decision log.** The cells are already short noun phrases. Shortening them would remove facts.
- **The §2.1 component table.** Its cells are lists of responsibilities. Each item is a fact.
- **Descriptive mechanics stay descriptive, on purpose:** §4.2 design stop "by default" (MUST would contradict "by default"), §4.2 implement-loop description, §7.2 Stop/Decide, §7.3 exhausted loops (already imperative and short), §10.3 views, the §13 smoke run and integration tests, and the §15.3 planned-work list. They describe behaviour, not separate requirements. The table in §7.1 is the normative source for stops.
- **The §16 open questions.** They are questions, not requirements. Item 4 stays a fragment because rewriting it as a rule would add a requirement.
- **Factual inconsistencies in the original, kept because this pass must not change facts.** Please look at these separately:
  - §10.5 gives the journal location as `docs/6-journal/` but the entry path as `docs/journal/YYYY-MM-DD-<slug>.md`.
  - §15.4 link text says "spec-driven development §7", but the anchor is `#10-self-hosting`.
- **The `scripted` "tests only" note, the British spelling (initialise, authorisation, behaviour, licence, organisation) and the double blank line before §5.1.** These are unchanged.
- **Sentence length.** Some requirement sentences stay at 21 to 23 words. In each case the extra words are an inline list of items (for example, §6.2's refused config contents, or §10.5's excluded content types). Splitting them would separate one rule into fragments.
