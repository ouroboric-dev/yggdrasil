---
title: Ginnungagap and Voluspa design doc
status: accepted
date: 2026-10-18
related: [../charter.md, ../roadmap.md, 2026-10-17-asgard-v0-design.md, ../../2-engineering/changes/2026-10-17-realm-leaf-naming/proposal.md, ../../2-engineering/changes/2026-10-18-repo-bootstrap/proposal.md, ../../2-engineering/backlog.md]
style: direction
---

# Ginnungagap and Voluspa design doc

| | |
|---|---|
| **Author** | Bruno Valério, with Claude Code (Opus 5.5), from a brainstorming session held 2026-10-18 |
| **Within** | the [charter](../charter.md)'s "narrow first" rule: grow from specific realms and extract what is truly shared. Admitting Ginnungagap amends the charter (§9) |
| **Engineering specs** | one change proposal per step (§8), each written when its step starts |
| **Process** | tier 3, [spec-driven development](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/4-ways-of-working/spec-driven-development.md) |

## 1. Summary

Yggdrasil has three realms, all built by hand: `asgard`, `midgard-react` and `helheim-go`. Nobody
wrote down what a finished realm is, so gaps showed up only after each realm existed. Both build
realms shipped with no CI, the products they create get no CI either, and their shared scripts
already differ from each other.

This design does four things:

1. It defines **what every realm must have**: a realm contract and a **realm readiness
   checklist**, with the same shape as Asgard's checklist.
2. It moves the graph out of `midgard-react` into a new component, **Voluspa**, which holds **one
   graph for all software**. A flavor swaps only its loop: stack, implementer, template and checks.
3. It puts readiness into the factory: the checklist format in Gungnir, and a runner in Odin.
4. It adds **Ginnungagap**, the realm that creates realms through `ygg run`, with the founder
   approving at the gates. It sits outside the nine domain realms. In the myth, every world began in
   Ginnungagap, the void before creation.

Steps 1 and 2 (as a decision) come before Yggdrasil v0's Phase 5c. Steps 3 and 4 come after v0 (§8).

## 2. Why

- **No realm has a definition of done.** `midgard-react` and `helheim-go` have no
  `.github/workflows/`, so their `pack_test`, `checks_test`, `template_test` and
  `containerfile_test` run only by hand. Every other Go leaf (`gleipnir`, `gungnir`, `havamal`,
  `jormungandr`, `odin`) has a `ci.yml`.
- **The products have no CI.** `midgard-react/templates/web` and `helheim-go/templates/api` hold no
  `.github/`. The check ladder guards the work during a run. Nothing guards the product after it.
- **Copies drift.** `docs.sh` differs between the two realms: only `helheim-go`'s copy has the
  `PATH` hardening. Backlog B-043 asks for one home for these scripts.
- **The next flavor will repeat this.** `midgard-vue`, `midgard-next` or a second backend would be
  built the same way, with the same gaps.
- **The graph is not a flavor's.** Today `midgard-react` holds the graph of a web product, and the
  leaf-naming change says a run takes its graph from its lead realm. The founder decided
  (2026-10-18) that the graph is the same for any software, and that only the loops inside it are
  specific to a stack.
- **The ouroboric principle.** The factory should build its own parts with its own process: realms
  made by a realm, through gates, and checked by evidence.

## 3. Goals, non-goals and anti-goals

### 3.1 Goals

1. A written realm contract and a realm readiness checklist that every realm is assessed against,
   with evidence for every item.
2. The three existing realms assessed, and the gaps fixed or recorded in the backlog, before 5c.
3. One software graph in Voluspa, pinned like a realm, used by every software run.
4. One source for the pieces every realm shares, with a drift check on every copy.
5. Readiness as factory machinery that both Asgard and Ginnungagap use.
6. A realm leaf created by `ygg run` that passes the realm readiness checklist. The founder only
   writes the brief, approves at the gates, runs the repo creation and merges.
7. After every step, the docs in `ouroboric` and `yggdrasil` describe what exists (§8).

### 3.2 Non-goals

- **`midgard-vue` itself.** It is the example, not a commitment.
- **Other domain realms.** Niflheim, Nidavellir, Jotunheim, Alfheim, Vanaheim and Muspelheim stay
  named only.
- **Asgard's content.** Its journey, templates and checklists stay as the Asgard design says.
- **The base CI rollout to existing repos.** The repo-bootstrap change and the founder's other
  session own it. Step 1 uses it but does not design it.
- **Custom graphs per flavor.** The door stays open (§5.3). No flavor uses it at the start.
- **New node kinds**, except the readiness node of step 3.

### 3.3 Anti-goals

The work fails, even if every test passes, when any of these is true:

- A realm passes readiness with a weakened guardrail: a check removed, a config the agent can
  write, or an unpinned image.
- Moving the graph out of `midgard-react` reduces what acceptance checks on any pointer move.
- An agent in a realm-making run gets a token with Administration, or creates a repo itself.
- Shared pieces become a runtime dependency between realms, so one realm's change breaks another
  realm's run.
- Myth names appear inside graphs, node ids or prompt names. Myth names are for realms and
  components only.
- A readiness item can't be verified by a check or judged by a person with evidence.
- The pre-5c work grows past step 1 and the Voluspa proposal, and delays the first real-agent run.

## 4. The layers

The work splits into three layers. Each layer builds on the one below it and does not change it.

| Layer | What it gives | Where |
|---|---|---|
| 1. Every repo | created, licences, base CI (`lint`), protected | `ouroboric/scripts`, change [repo-bootstrap](../../2-engineering/changes/2026-10-18-repo-bootstrap/proposal.md) (`new-repo.sh`) |
| 2. Every realm repo | the realm contract, the realm repo's own `test` CI, readiness | this design |
| 3. Each flavor | language checks, stack, template, the CI that its template gives products | the realm itself |

The repo-bootstrap change already states two things this design relies on:

- The base CI is `.github/workflows/lint.yml` with one required job, `lint`. Language CI is
  `.github/workflows/ci.yml` with one required job, `test`. This holds for a realm repo's own CI
  and for the CI a template gives a product.
- A CI piece is one YAML fragment with one `repos:` entry and a pinned `rev`. A realm will ship its
  own pieces (`gofmt`, `golangci-lint`, `eslint`) in that format.

## 5. The structure

### 5.1 Where each piece lives

| Piece | Home | Why |
|---|---|---|
| The software graph, and the prompts that are not tied to a leaf (design, spec, plan, conformance, reuse review, the three reviewers) | **Voluspa**, folder `software/` | The graph is the same for all software (founder). |
| Flavor content: stack, implementer prompt, leaf template, leaf checks, acceptance check, the CI its template gives products | each realm | This is what a flavor swaps. |
| Contract, machine part: the standard role names, stack, services, a graph-only pack | **Gungnir** (most of it is there) | It is the interface between realms and Odin. Gungnir validates it. |
| The readiness checklist format | **Gungnir** | It is a schema, like `pack.yaml`. Asgard and Ginnungagap both use it. |
| The readiness runner (`ygg readiness`, and a graph node) | **Odin** | Asgard v0 calls the command by hand. Ginnungagap calls the node. |
| Running a checklist's auto items | **Gleipnir**'s check runner | It already runs a realm's checks in a sandbox. |
| Copies with a drift check | **Havamal**'s lock and verify code, made general | It already vendors at pinned commits, with per-file hashes and a drift check. |
| Contract, repo part: CI, licences, `AGENTS.md`, ruleset | the realm checklist, calling `check-repos.sh --check <name> <repo>` | Not a runtime interface. The repo-bootstrap change owns these checks. |
| Shared check scripts (`docs.sh` and others) | a base stage that every realm's Containerfile starts from, owned by **Ginnungagap** | It is realm content, not engine code. It ends the copies (B-043). |
| The realm checklist, the realm skeleton, the realm-builder implementer | **Ginnungagap** | What only the realm-maker needs. |
| Company and product checklists | **Asgard** | Unchanged. |

Ginnungagap is the source of every shared piece. Every realm, Asgard included, holds a copy, and a
drift check fails when a copy differs. A realm never loads another realm's files at run time.

### 5.2 Voluspa

Voluspa (Völuspá, "the seeress's prophecy") is the Edda poem that tells the course of the world
from creation to the end. It is a sibling of Hávamál: `havamal` holds what agents know (skills), and
`voluspa` holds the order that work follows (graphs).

- **One repo for every graph.** It starts with `software/`. It gets `kickstart/` when Asgard is
  automated. Split it only if the graphs' release cycles get in each other's way.
- **Graphs have descriptive names.** Myth names stay with realms and components.
- **A graph is a pack that holds only a graph** and its prompts. It loads through the realm store,
  the pins and the hash in `run.json` that Phase 5a built. No new loading mechanism is needed.
- **A graph states the Gungnir schema version it needs.** Odin refuses a graph that it can't run,
  before any sandbox starts.
- **A run names its graph** (`--graph software`), and the project pins it as it pins its realms.
  The "lead realm supplies the graph" rule of the leaf-naming change ends.
- **The content is MIT**, like realm content. It is a leaf of the `yggdrasil` umbrella.

### 5.3 What a flavor swaps

A flavor provides the loop inside the shared graph:

- the stack (`sandbox.build`, and `sandbox.acceptance` if it has an acceptance check);
- the implementer prompt;
- the leaf template, including the product's `lint.yml` and `ci.yml`;
- the leaf checks (rungs 1 to 5) and, if it has one, an acceptance check;
- its services.

A flavor MAY add reviewers to its loop later. None does at the start. Midgard's flavors share their
domain's conventions (the contract copy in `contracts/api.openapi.yaml`, the Prism mock, the web
acceptance run), but each flavor holds its own copy of them for now (§10).

### 5.4 Acceptance after the graph moves

Today a pointer move runs the lead realm's `accept` check on the lead realm's acceptance stack. For
the client gallery, that is `midgard-react`'s `accept-e2e.sh`, and it runs for the `api` leaf's
moves too. Without a lead realm, that check needs a new owner.

**Call made while writing:** every pointer move runs the acceptance check of **every leaf realm in
the project that has one**. Each runs on its own realm's acceptance stack, over the same snapshot,
with the services of every leaf's realm. A realm with no acceptance check adds none. This keeps
today's coverage, because the `api` leaf's move still runs the web specs against the real API. The
Voluspa change proposal confirms or replaces this call.

## 6. The realm readiness checklist

The checklist follows the shape of Asgard's: an ID, an area, a question, the check type (`auto` or
`human`), and an "applies to" column (`all`, `build` or `document`). An assessment gives each item
`met`, `partial`, `missing` or `n/a` (with a reason), and evidence for each item: a link, a command
and its output, or a person's judgement. This is the first draft. Step 1 refines it.

| ID | Applies to | Area | Question | Check |
|---|---|---|---|---|
| RR-01 | all | repo | Does the repo pass `check-repos.sh` (settings, security, ruleset), with `lint` required, and `test` where `ci.yml` exists? | auto |
| RR-02 | all | licence | Does `reuse lint` pass, with MIT on everything copied into products? | auto |
| RR-03 | all | CI | Does `lint.yml` exist, and does it pass on `main`? | auto |
| RR-04 | all | CI | Does `ci.yml` run the realm's own tests (pack, template, checks, Containerfile) in a job named `test`, and does it pass on `main`? | auto |
| RR-05 | all | agents | Does `AGENTS.md` carry the umbrella's invariants? | auto |
| RR-06 | all | secrets | Is gitleaks in the pre-commit config? | auto |
| RR-07 | all | docs | Do `README.md`, `AGENTS.md` and `docs/architecture.md` follow the docs standard? | auto |
| RR-08 | all | contract | Does `pack.yaml` load and validate against Gungnir at the version it declares? | auto |
| RR-09 | all | shared | Does every shared piece match its source? | auto |
| RR-10 | all | tree | Is the realm a submodule of the `yggdrasil` umbrella, in `go.work` if it is Go, and in `check-repos.sh`'s lists? | auto |
| RR-11 | all | name | Does the name follow `<realm>-<flavor>`, and was it screened? | human |
| RR-12 | build | contract | Does the pack name the standard roles: the implementer prompt, the leaf template and the leaf checks? | auto |
| RR-13 | build | stack | Is every base image and service pinned by digest, and at least two weeks old? | auto |
| RR-14 | build | stack | Are the packages in the stack pinned (B-044)? | auto |
| RR-15 | build | guard | Are the check scripts and their lint and build configs baked into `/opt/ygg/checks`, owned by root, and passed explicitly (B-049)? | auto + human |
| RR-16 | build | ladder | Does the pack name rungs 1 to 5, and does each script exist in the stack? | auto |
| RR-17 | build | template | Does the template pass its own ladder on its first commit, when it is built in a copy? | auto |
| RR-18 | build | product | Does the template give the product `lint.yml`, `ci.yml` (`test`), a pre-commit config with gitleaks, and the MIT licence with the "Built with Ouroboric" notice? Does that CI pass on the product's first commit? | auto |
| RR-19 | build | egress | Is the egress list the smallest that works, with a reason for each host? | human |
| RR-20 | build | prompt | Has a person reviewed the implementer prompt? | human |
| RR-21 | build | smoke | Does `ygg-smoke-realms.sh` include the realm, and does it pass? | auto |
| RR-22 | document | contract | Does the pack declare no stack, and are its checks document checks? | auto |

**Auto items that need GitHub** (RR-01, and the "passes on `main`" parts of RR-03 and RR-04) read
repo settings through the GitHub API. A factory sandbox has no GitHub token. In step 1 the founder
runs them by hand. Step 3 decides how the runner gets them (§8.3).

**Leaf items and wiring items (call made while writing).** RR-10 and RR-21 change files outside the
leaf: the umbrella's `.gitmodules` and `go.work`, and `check-repos.sh` and `ygg-smoke-realms.sh` in
`ouroboric`. An agent in a run never touches those (invariant 10). They are **wiring items**: after a
realm-making run, they come in a follow-up pull request from an agent building the factory, which the
founder merges. A realm-making run succeeds when every other auto item is `met` and a person has judged
the human items.

**Where it lives (call made while writing).** Until Ginnungagap exists, the checklist lives in
`yggdrasil/docs/2-engineering/realm-readiness.md`. It moves into the `ginnungagap` leaf in step 4.
Assessments are records, so they stay in the umbrella:
`yggdrasil/docs/2-engineering/readiness/YYYY-MM-DD-<realm>.md`.

## 7. Ginnungagap

- **Its domain is realms.** It stands outside the nine domain realms. The leaf is named
  `ginnungagap`, because a realm with one way of working may be named `<realm>` alone.
- **It is a software realm, so it runs Voluspa's `software` graph.** A realm leaf is software: Go
  tests, a Containerfile, scripts, a template. Its loop is specialized:
  - the implementer is a realm builder;
  - the template is the realm skeleton. It replaces `scaffold-component.sh --mit-templates` and
    adds to the existing `.pre-commit-config.yaml` (it never writes it whole);
  - the checks are the realm checklist's auto items;
  - its acceptance check runs the readiness assessment.
- **Readiness needs no graph of its own (call made while writing).** It fits the slots a flavor
  already fills. Ginnungagap's acceptance check runs the checklist's auto items on the pointer move.
  The human items go into the pointer gate's file, where the founder judges them. The `software` graph
  gains no node, and client-gallery runs are unchanged. Step 3's readiness node is for graphs that
  need one, such as Asgard's `kickstart`.
- **Its brief** names a domain and a flavor, for example "a Vue flavor of Midgard", and **carries
  the stack research** (founder, 2026-10-18). The founder writes it, or a Vanaheim research run
  produces it later. The design stage designs from the brief and never browses: a planner's egress is
  not widened. The spec stage names the leaf. The founder approves both at the gates.
- **Repo creation stays with the founder, behind `repo-admin`** (founder, 2026-10-18). `new-repo.sh`
  needs a token with Administration, which no agent gets. The run stops at the `repo-admin` hard
  approval point (change `remote-creates-repos`), the founder runs `new-repo.sh`, and the run goes
  on with the empty, protected repo. `init` adopts that first commit (licences and `lint.yml`) and
  adds the realm skeleton on top. The work reaches GitHub as pushes and pull requests through the
  `github` remote, and the founder merges them (invariant 3).
- **A realm's guardrails stop at `guardrail-change`** (founder, 2026-10-18). A new realm's check
  scripts, lint and build configs, egress list and Containerfile are the guardrails of every later
  run in that realm. Merging them stops at the `guardrail-change` hard approval point (spec §7.1,
  §15.4), as any change to policies or sandbox hardening does.
- **It owns the shared base stage.** Every realm's Containerfile starts from it, so `docs.sh` and
  the other shared check scripts have one source.
- **Ginnungagap passes its own checklist.** It is a realm, so the checklist applies to it.

**The risk to test first:** Ginnungagap's checks build the new realm's stack image and run its
template through its own ladder, inside a sandbox. That means building containers inside a
container. The sandbox may not allow this today. A spike answers it before step 4's plan. **If it
fails, the sandbox is not widened (call made while writing):** no `--privileged` and no engine socket,
as spec §6.2 requires. The way forward is a check on the host instead: Odin builds the new realm's
stack through Gleipnir's `BuildStack`, outside the agent's reach, and runs the template's ladder on
that image.

## 8. The steps

Each step has its own change proposal and plan. They come in this order.

**Every step updates the docs it changes (founder, 2026-10-18).** A step is done only when the living
docs in `ouroboric` and `yggdrasil` (and in the leaves it touches) describe what it built. They change
in the step's own pull requests, or in a docs pull request merged with them. Each step's plan has a
docs task, and the "Docs" list of each step below is where that task starts, not its limit. Dated
records stay as written. Each step adds a journal entry in `ouroboric/docs/6-journal/`.

### 8.1 Step 1: the realm checklist and a manual retrofit (before 5c)

It goes with the pre-5c hardening pass, because B-049 changes the same check scripts in both
realms.

- Write the realm checklist (§6) into the umbrella.
- Assess `midgard-react`, `helheim-go` and `asgard` by hand, and record each assessment.
- Fix what the assessments find, or add each gap to the backlog with its item ID. At least:
  - a `ci.yml` with a `test` job in both build realms;
  - the base CI from the repo-bootstrap change, when its scripts exist;
  - a `lint.yml` and a `ci.yml` in both templates, which pass on a product's first commit. **Call
    made while writing:** the product's `test` job runs the stack's own commands (for example
    `npm ci`, lint, `npm test` and the build; `go vet`, `go test` and lint), with the services as
    GitHub Actions service containers pinned by digest. It is a second line of defence. The ladder
    stays the main one, and its scripts stay in the realm image. The template's `.github/workflows/`
    joins the files the ladder protects from the agent, with B-049's fix;
  - one source for the shared check scripts, with a drift check (B-043). Until Ginnungagap's base
    stage exists, the builder picks an interim source and check.
- Docs:
  - `ouroboric/docs/4-ways-of-working/docs-standard.md`, the repo section: what a realm repo holds
    and its CI, with a link to the realm checklist;
  - `ouroboric/AGENTS.md`'s scripts table and the script headers, for any new script or check;
  - each realm's `README.md` and `docs/architecture.md`: its CI, and the CI its template gives a
    product;
  - `yggdrasil/docs/3-using/operations/`: how to assess a realm (a procedure);
  - `yggdrasil/docs/2-engineering/backlog.md`: B-043 closed or narrowed, and an entry for each gap.
- Success: three assessments are filed, every `missing` item is fixed or is in the backlog, and the
  docs above match.

### 8.2 Step 2: Voluspa (the decision before the 5c plan)

- A change proposal that covers §5.2 to §5.4: the graph-only pack, `--graph`, the project's pin,
  acceptance without a lead realm, and the spec sections the leaf-naming change touched.
- **The prompts move without changing behaviour (call made while writing).** This happens just
  before the first real-agent run, and a change would shift every benchmark baseline. Text tied to
  realms (`spec.md` names `midgard-react` and `helheim-go`, and `repos/web` and `repos/api`) stays as
  it is. A later proposal makes the stage prompts general, and decides whether a flavor may add text
  to them, as it may add reviewers.
- Screen the name `voluspa` (npm, PyPI, crates.io, Docker Hub, Homebrew, GitHub), as earlier names
  were screened.
- The proposal MUST be accepted before the 5c plan is written, so that 5c's graph changes (the
  routing indexes, `pointer-contract`) land in Voluspa. The move itself happens just before 5c or
  as 5c's first tasks. The 5c plan session decides which.
- Docs:
  - the living spec (`yggdrasil/docs/2-engineering/system/`) takes the proposal's delta, including
    the end of the lead-realm rule;
  - the diagrams `architecture.d2`, `instance-tree.d2` and `web-realm-graph.mmd`, re-rendered with
    `diagrams.sh`;
  - `yggdrasil/README.md` (the list of MIT repos), `AGENTS.md` and `docs/README.md`;
  - the architecture pages of `gungnir`, `odin` and `midgard-react`, and the new `voluspa`'s;
  - `yggdrasil/docs/3-using/`: `--graph` for operators;
  - in `ouroboric`: the naming doc's component table and long-term map (Voluspa), `docs/README.md`'s
    map, and `check-repos.sh`'s lists.
- Success: the client gallery's smoke run passes with `--graph software`, `midgard-react` holds no
  graph, acceptance checks no less than before, and the docs above match.

### 8.3 Step 3: readiness in the factory (after v0)

- **It is Asgard v0's readiness script, built once** (founder, 2026-10-18). The script that the
  Asgard design §8 describes is `ygg readiness`, so the runner is not built twice. It keeps that
  design's rules: it works offline by default, on one umbrella's files, and reports links to other
  repositories as present but not verified. The Asgard design gets a note (§9).
- The checklist format in Gungnir. It MUST express both Asgard's checklists and the realm
  checklist, and an assessment MUST stay readable Markdown.
- The runner in Odin, as `ygg readiness` and as a graph node. A gate shows the human items.
- How auto items that need GitHub run, outside the offline default: through the `github` remote
  with a read-only token, or as items the founder runs.
- Havamal's lock and verify code made general for copies of shared pieces.
- Docs:
  - the architecture pages of `gungnir`, `odin`, `gleipnir` and `havamal`;
  - `yggdrasil/docs/3-using/`: how to run `ygg readiness`;
  - spec-driven development §3.1 (the readiness assessment runs through `ygg readiness`), and the
    Asgard leaf's README and checklist template;
  - the realm checklist: its auto items now name the runner's checks.
- Success: Asgard's company checklist and the realm checklist both run through `ygg readiness`.
  Ouroboric's own umbrella is the first fixture, as the Asgard design asks. The docs above match.

### 8.4 Step 4: Ginnungagap (after v0)

- **It depends on** (founder, 2026-10-18):
  - the `github` remote of iteration 2, for pushes and pull requests, with `repo-admin`;
  - the `guardrail-change` hard approval point, active from self-hosting stage 1;
  - step 3's runner.
- The spike first: build a container image and run a ladder inside a sandbox.
- The `ginnungagap` leaf, created with `new-repo.sh`: its stack, the realm-builder implementer, the
  realm skeleton, its checks and the shared base stage. The checklist moves into it.
- The existing realms take their shared pieces from its base stage.
- Docs:
  - the naming doc and both Ouroboric maps (Ginnungagap built, not only named), `ouroboric`'s
    README and `docs/README.md`;
  - `yggdrasil/README.md`, `AGENTS.md` and `docs/README.md`;
  - the docs standard and `ouroboric/AGENTS.md`'s scripts table: the realm skeleton replaces
    `scaffold-component.sh --mit-templates`;
  - `yggdrasil/docs/3-using/`: a tutorial for creating a realm with `ygg run`;
  - each realm's `docs/architecture.md`: its shared pieces come from Ginnungagap's base stage.
- Success: a `ygg run` with a flavor brief produces a realm leaf that passes the realm checklist's
  leaf items (§6). The founder writes the brief, approves at the gates (`guardrail-change` included),
  runs `new-repo.sh` at `repo-admin`, and merges the pull requests, and does nothing else. The docs
  above match.

## 9. Direction changes

These go through the `charter` approval point, as the Asgard realm's admission did. **Call made
while writing:** they go with this design doc, before it is accepted.

- **Yggdrasil charter:** admit Ginnungagap, the realm whose domain is realms, outside the nine.
- **Yggdrasil roadmap:** step 1 and the Voluspa proposal before 5c; steps 3 and 4 after v0.
- **The naming doc** (`ouroboric/docs/7-branding/story/naming-and-mythology.md`): Ginnungagap is
  the realm that creates realms. Voluspa is the graph library. Asgard's kickstart graph is named
  `kickstart`. The line "every new company or product begins in Ginnungagap" changes, and the SDD
  line "every realm begins in Ginnungagap" becomes literally true.
- **The leaf-naming change's lead-realm rule** ends. The Voluspa proposal records this as its
  delta.
- **Places that name Ginnungagap as Asgard's graph** change to `kickstart`: the Yggdrasil and
  company roadmaps, the backlog's note on items B-035 to B-039, spec-driven development §3.1, `asgard/README.md`, and
  the two Ouroboric maps (sources and rendered). The accepted Asgard design gets a note: its graph
  is `kickstart`, and its readiness script is `ygg readiness` (§8.3). Dated
  records (journal entries, the name checks, the superseded Asgard charter) stay as written.

## 10. Left to the builders

- **The interim source of the shared scripts** in step 1, until Ginnungagap's base stage exists.
- **How a realm declares its schema version** and the exact `--graph` and pin fields (step 2's
  proposal).
- **Whether `--realm` stays** as an alias during the move (step 2's proposal).
- **The checklist format's file type** (step 3), within the constraint that assessments stay
  readable Markdown.
- **Which project a realm-making run works in** (step 4): the `yggdrasil` umbrella itself, or a
  separate project umbrella whose leaf is then added as a submodule. Invariant 10, the merge rules
  and `guardrail-change` must hold either way.
- **Domain-level sharing**, such as Midgard's contract copy and web acceptance run shared between
  `midgard-react` and `midgard-vue`. Each flavor keeps its own copy until a second flavor of a
  domain exists. Then a proposal decides.

## 11. Calls made while writing

These are Claude's calls, open to the founder's change:

1. Every pointer move runs the acceptance check of every leaf realm that has one (§5.4).
2. The checklist lives in the umbrella until Ginnungagap exists, and assessments stay there
   (§6).
3. The direction changes go with this design doc, before it is accepted (§9).
4. Asgard's kickstart graph is named `kickstart` (§9).
5. The checklist's IDs use `RR-` and the "applies to" column (§6).
6. GitHub-reading auto items are run by the founder in step 1 (§6).
7. RR-10 and RR-21 are wiring items, done in a follow-up pull request after a realm-making run (§6).
8. Readiness rides the acceptance check and the pointer gate, so the `software` graph gains no node
   (§7).
9. A failed nested-build spike never widens the sandbox. The fallback is a host-side check (§7).
10. A product's `test` job runs the stack's own commands, and the template's workflows are protected
    from the agent (§8.1).
11. Step 2 moves the prompts without changing behaviour (§8.2).
