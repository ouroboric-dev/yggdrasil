---
title: Voluspa, one software graph for every run
status: draft
date: 2026-10-19
related: [../../../1-product/design/2026-10-18-ginnungagap-design.md, delta.md, ../2026-10-17-realm-leaf-naming/proposal.md, ../2026-10-17-realm-engine/delta.md, ../2026-10-17-realm-content/delta.md, ../../plans/2026-10-18-yggdrasil-v0-phase-5c/tasks.md, ../../../5-research/2026-10-19-voluspa-name-screening.md]
style: spec
---

# Voluspa, one software graph for every run

**Proposed 2026-10-19:** step 2 of the
[Ginnungagap and Voluspa design doc](../../../1-product/design/2026-10-18-ginnungagap-design.md) (§5.2 to §5.4,
§8.2). The graph and the stage prompts move out of `midgard-react` into a new component, **Voluspa**, as the
graph `software`. A run names its graph with `--graph software`, and the project pins it as it pins its realms.
The lead realm ends. A realm keeps only its flavor: stack, implementer prompt, template, checks, acceptance check
and services.

**Decided (founder, 2026-10-19):** the graph moves now, as its own change, before Phase 5c is closed. Its Odin
tasks change the lead-realm reads that 5c added, on Odin's `main` as it is now. The graph changes already on
`midgard-react`'s `main` move with the graph, unchanged. The founder also decided every choice this proposal left
open, each as recommended. Each decision is recorded where it applies.

## Why

- **The graph is not a flavor's.** `midgard-react` holds the graph of every product it leads, so a backend-only
  product, or a product with another frontend flavor, has no graph to run (`helheim-go`'s pack says "a run takes
  its graph from its lead realm"). The founder decided (2026-10-18) that one graph serves all software and that
  only the loop inside it is specific to a stack.
- **The lead realm does too many jobs.** Today it supplies the graph, the stage prompts, the reviewers' prompts,
  the scratch sessions' stack and egress, the acceptance check and its stack, the routing threshold, and the
  default realm of an unpinned leaf. Each job needs one clear owner.
- **5c's code reads the lead realm.** Moving before 5c is closed means its founder steps, and Phase 6's first
  client-gallery baselines, run on the final model.

## What changes

### Voluspa, the graph library

- **A new leaf, `voluspa`**, in the `yggdrasil` umbrella. MIT content, like a realm. The founder creates it with
  `new-repo.sh`, so it has the base CI (`lint`) from the start. It is a Go module in `go.work`, because the graph
  tests move with the graph, and it gets a `ci.yml` with one job, `test`.
- **One repo for every graph.** It starts with `software/`. `kickstart/` comes when Asgard is automated.
- **A graph is a pack that holds only a graph and its prompts:**

  ```text
  voluspa/
    software/
      pack.yaml      name: software, version, graph: graph.yaml
      graph.yaml     schema: 1, and the graph of spec §4.2
      prompts/       design, spec, conformance, plan, reuse-review, reviewer-spec, reviewer-simplicity,
                     reviewer-quality
    *_test.go        the graph and prompt tests that move from midgard-react
  ```

- **It loads like a realm.** Odin reads it through a store, records its name, version and hash in `run.json`,
  and a resume refuses a graph whose hash changed. This is the mechanism Phase 5a built for realms. No new loader.
- **Graphs have descriptive names.** Myth names stay with realms and components.
- **A graph states the Gungnir schema version it needs.** Odin refuses a graph it can't run, before any sandbox
  starts.

  **Decided (founder, 2026-10-19):** one integer in `graph.yaml`, `schema: 1`. Gungnir bumps it on a change an
  older graph can't follow. Why: it is what the design asks for, and it is one field. Realm packs keep relying on
  their `go.mod` pin for now (backlog, below).

- **A pack may hold both a graph and a leaf recipe.** Odin's test realms (`smoke`, `smoke-loop`, `smoke-realms`,
  `smoke-content`, `smoke-grade`) do.

  **Decided (founder, 2026-10-19):** the schema allows it. "A realm leaf holds no graph" is a rule for the realm
  leaves in the umbrella, checked by each realm's tests and by readiness item RR-12. A leaf that pins no realm
  takes the recipe of such a pack. Why: the test data and the smoke scripts stay small, and the rule that matters
  is about the real leaves.

### What moves, and what stays

The move changes no behaviour of a run (design §8.2, call made while writing). A change would shift every
benchmark baseline.

| File in `midgard-react` | Goes to | How |
| --- | --- | --- |
| `graph.yaml` | `voluspa/software/graph.yaml` | Nodes unchanged. Only `name`, `version`, the header comment and the new `schema` line change |
| `prompts/design.md`, `spec.md`, `conformance.md`, `plan.md`, `reuse-review.md` | `voluspa/software/prompts/` | Byte for byte |
| `prompts/reviewer-spec.md`, `reviewer-simplicity.md`, `reviewer-quality.md` | `voluspa/software/prompts/` | Byte for byte |
| `prompts/implementer.md` | stays | It is the flavor's |
| the graph and prompt tests in `pack_test.go`, `prompts_test.go`, `build_prompts_test.go` | `voluspa/` | Unchanged, except their paths and the pack they load |
| `pack.yaml` | stays | Loses `graph:`. Keeps `checks`, `leaf`, `sandbox` (with `acceptance`) |

- **What landed on `main` moves with the graph, unchanged.** `midgard-react` #13 added the `contract-gate` node
  (`gate: pointer-contract`) and `generated: [REPOS.md, .ygg/impact.json]` on `move` (5c plan, v0-T256). Both
  move as they are. So does the test `TestTheContractGateComesBeforeTheMoveAndTheMoveShipsTheRoutingIndexes`. Its
  line "the pack sets no `routing` block" now checks Voluspa's `software` pack. The test that the web template's
  contract is named `*openapi.yaml` stays in `midgard-react`: it is about the template.
- **Text tied to realms stays as it is.** `spec.md` names `midgard-react` 0.1.0, `helheim-go` 0.1.0,
  `repos/web` and `repos/api`. `plan.md` shows `repos/api`. A later proposal makes the stage prompts general,
  and decides whether a flavor may add text to them.
- **`midgard-react` keeps version 0.1.0 (call made while writing).** `spec.md` names that version. A bump would
  change the prompt. The realm's hash still changes, and a run records it. Its version moves with the proposal
  that makes the prompts general.
- **The prompts are proved unchanged.** The pull request that adds them to Voluspa lists the SHA-256 of each
  prompt in `midgard-react` at the commit before the removal, and in Voluspa. They MUST be equal.

### A run names its graph: `--graph`

- `ygg run --project <path> --graph software --brief <brief.md>`. `--graph` takes a graph's name, found in the
  graph store, or a path to a folder that holds a graph pack, as `--realm` does today.
- **The project pins its graph.** The first run of a project pins the graph and its version, as the lead realm
  is pinned today. Every later run checks the pin. A run whose `--graph` names another graph, or another version,
  stops before anything starts.
- **Every leaf pins its realm (call made while writing).** A leaf with no pin was the lead realm's. With no lead
  realm, Odin refuses a leaf with no pin before anything starts. `init` already writes the pin into the commit
  that creates a leaf. The one exception is a pack that holds both a graph and a leaf recipe (above).

  **Decided (founder, 2026-10-19):** new top-level fields in `umbrella.yaml`, `graph` and `graph_version`. The
  top-level `realm` and `realm_version` go. Leaves keep `realm` and `realm_version`. Why: a field named `realm`
  that holds a graph would mislead every reader of the file.

  ```yaml
  graph: software
  graph_version: 0.1.0
  children:
    repos/api: { kind: leaf, realm: helheim-go, realm_version: 0.1.0 }
    repos/web: { kind: leaf, realm: midgard-react, realm_version: 0.1.0, consumes: [repos/api] }
  ```

  **Decided (founder, 2026-10-19):** Odin finds a graph by name through a new `factory.yaml` section,
  `graphs: {dir: <a Voluspa checkout>}`. `--graph software` finds `<dir>/software/pack.yaml`. Why: a graph and a
  realm are found the same way, but not in one folder, and the store's layout does not depend on one repo's name.
  `ygg doctor` checks the `graphs` section as it checks `realms`.

  A graph pack lives in a subfolder of a git repo. Odin's committed-files hash (B-050) only works on a repo's top
  folder today. It MUST hash the subfolder's committed files, or a graph would be hashed with its untracked files,
  as a plain folder is.

- **`--realm` on `ygg run`.**

  **Decided (founder, 2026-10-19):** it goes. `ygg run --realm` stops with "use `--graph`; a leaf's realm is
  pinned in the project". A resume of a run that recorded a lead realm stops with a reason. Why: no project
  outside the tests has runs to resume, and an alias would keep the lead realm alive. The smoke scripts change in
  the same change. `--realm` stays on `ygg sandbox build`, where it names a realm whose stack to build.

### Who owns each job of the lead realm

| Job | Today | After |
| --- | --- | --- |
| The graph | the lead realm | the graph pack named by `--graph` |
| Prompts of agent nodes and loop reviewers | the lead realm | the graph pack |
| The implementer prompt, the leaf's checks and template | the leaf's realm | unchanged |
| The realm of a leaf with no pin | the lead realm | none: the leaf is refused |
| Scratch sessions' stack and egress | the lead realm's | the factory layer alone, model APIs only |
| The acceptance check and its stack | the lead realm's | each leaf realm's |
| The routing threshold (`routing:` block) | the lead realm's pack | the graph pack |

**Where scratch sessions run.** The design, spec, conformance, plan and reuse-review sessions run in a scratch
sandbox on the lead realm's stack, with its egress (`registry.npmjs.org`, `api.osv.dev`) and the model APIs. No
stage prompt runs a command; they read and write documents.

**Decided (founder, 2026-10-19):** they run on the factory layer alone, on the Node image Gleipnir already pins,
with the model APIs as the only egress. Gleipnir and Odin learn to start a sandbox with no stack. Why: a planner
needs no package registry, so its egress shrinks, and a graph pack stays a graph and its prompts. The stage
sessions' sandbox changes; their prompts do not.

**The routing threshold.** Gungnir's `routing:` block (5c plan v0-T255, merged in `gungnir` #14) sits in a pack.
Odin reads it from the lead realm's pack. No pack sets it yet.

**Decided (founder, 2026-10-19):** the graph pack holds it. Why: the code path stays the same, with another pack.
The project's `umbrella.yaml` is the better home once a project writes its own bench (backlog, below). The test
that pins "the pack sets no `routing` block" moves with the graph and checks Voluspa's `software` pack.

**The `pointer-contract` gate needs no lead realm.** It reads the moving leaf's own git, picks the changed files
by name (`*openapi.yaml`, `*openapi.yml`), and judges them by the impact index shipped in the project and by the
host's `oasdiff`. No realm's pack plays a part.

### Acceptance without a lead realm

Today a pointer move runs the lead realm's `accept` check on the lead realm's acceptance stack. For the client
gallery that is `midgard-react`'s `accept-e2e.sh`, and it also runs for the `api` leaf's moves.

**Decided (founder, 2026-10-19), confirming the design's call (§5.4):** every pointer move runs the acceptance
check of **every leaf realm in the project that has one**. Each runs on its own realm's acceptance stack, over the
same snapshot, with the services of every leaf's realm. A realm with no acceptance check adds none. The graph's
`acceptance: [accept]` on `move` means "the check `accept` of each leaf realm that defines it", in realm-name
order, stopping at the first failure. Why: it keeps today's coverage, and it puts the check with the flavor that
knows the product's stack.

For the client gallery this runs exactly what runs today: `helheim-go` has no acceptance check, so every move
runs `midgard-react`'s `accept-e2e.sh` on its acceptance stack, with Postgres and SeaweedFS.

**Decided (founder, 2026-10-19):** a project where no leaf realm has an acceptance check (a backend-only product
today) is refused before the run starts, while the graph's `move` asks for acceptance: "no realm of this project
has an acceptance check". Why: a move with no acceptance check would check less than today, which the design's
anti-goals forbid. Such a project can't run today either: `helheim-go` has no graph.

### The spec sections the leaf-naming change touched

The leaf-naming change's lead-realm rule ends. Its other rules stay: realm leaves named `<realm>-<flavor>`, the
standard roles of a build realm, one version per realm leaf per run, the project deciding its leaves. The changes
`realm-engine` and `realm-content` also wrote "the lead realm" into §3.1 and §6.1. The [delta](delta.md) lists
every line.

## How this fits with Phase 5c

Most of 5c has merged: `gungnir` #14 (v0-T245, the `routing` block of v0-T255, the limits of v0-T262, docs of
v0-T264), `gleipnir` #12 (v0-T246), `helheim-go` #8 (v0-T256's docs and test, v0-T257, v0-T260),
`midgard-react` #13 (v0-T256's graph change, v0-T258), `mimir` #4 (v0-T261) and `odin` #18 (v0-T247 to v0-T264:
the `grade` stage, the routing indexes and the `pointer-contract` gate, `ygg deps bump`, and a test realm
`smoke-grade` with its own small graph, pack and prompts). What is left is the `ouroboric` scripts of v0-T262
and v0-T263, v0-T265, and the founder steps v0-H16 and v0-H17.

**This change owns the whole move:** the graph, the stage prompts, the test that pins #13's gate, and the docs.
The 5c plan stays the record, corrected by an erratum (below).

- **What moves with the graph:** #13's `contract-gate` node, the `generated` list on `move`, and
  `TestTheContractGateComesBeforeTheMoveAndTheMoveShipsTheRoutingIndexes`. Unchanged.
- **The lead-realm reads that 5c added**, which this change's Odin tasks change on Odin's `main` (with #18):
  - `internal/engine/routing.go`: the routing threshold, `r.Setup.Lead.Pack.Routing` (v0-T255), is read from the
    graph pack;
  - `internal/cli/deps.go`: `ygg deps bump` falls back to the umbrella's lead pin (`project.Umbrella.Realm`) for a
    leaf with no pin (v0-T259). The fallback goes: the bump takes a leaf's realm from its pin only;
  - `internal/routing/wiring.go`: the wiring index gives an unpinned leaf the umbrella's lead pin
    (`cmpOr(c.Realm, u.Realm)`) for its `uses-realm` and `needs` edges (v0-T251). The fallback goes, and the
    fixture `testdata/routing/project/umbrella.yaml` pins a graph and every leaf;
  - `ygg run --realm` in the tests, the smoke scripts (`ygg-smoke-grade.sh`, `ygg-smoke-real.sh`) and the example
    configs (`testdata/smoke-grade/factory.real.example.yaml` and the others) becomes `--graph`, and the configs
    set `graphs.dir` (v0-T262, v0-T263).
- **The lead-realm reads from before 5c**, which this change also replaces: `run.Prepare` loading `--realm` and
  its graph, `checkSession` and `checkBody` finding prompts and acceptance checks in the lead pack,
  `prepareSandbox` and `ScratchRunner` (the lead realm's stack and egress), `SnapshotSandbox`, `runChecks` and
  `runAcceptance` (the lead realm's acceptance check and stack), `RealmOf` and `init` (an unpinned leaf is the lead
  realm's), the loop's reviewer prompts, `pinLead`, `realm.Collect`'s lead pin check, and a resume's `RealmDir`.
- **The 5c plan's erratum** is the pre-5c session's:
  [yggdrasil #67](https://github.com/ouroboric-dev/yggdrasil/pull/67).
- **Test graphs after the move.** A test or test-data graph (`smoke`, `smoke-loop`, `smoke-realms`,
  `smoke-content`, `smoke-grade`) loads by path, `ygg run --graph <folder>`, as `--realm <folder>` loads it today.
  Such a folder stays one pack: it gives the graph and the leaf recipe, and a leaf that pins no realm takes the
  recipe of that pack. A real project pins every leaf.
- **The grade node** (v0-T245) is a node kind. If a later phase adds `grade` to the software graph, it goes into
  Voluspa.

## Docs

The plan has a docs task. It starts from this list (design §8.2):

- the v0 spec stays as accepted. This delta joins the others for the living spec (`docs/2-engineering/system/`),
  which takes the deltas when v0 lands, as its README says;
- the diagrams `architecture.d2` and `instance-tree.d2`, and `web-realm-graph.mmd`, renamed
  `software-graph.mmd` (call made while writing), re-rendered with `diagrams.sh`;
- `yggdrasil/README.md` (the list of MIT repos), `AGENTS.md` and `docs/README.md`;
- the architecture pages of `gungnir`, `odin` and `midgard-react`, the pack comment and architecture page of
  `helheim-go`, and Voluspa's own `README.md`, `AGENTS.md` and `docs/architecture.md`;
- `yggdrasil/docs/3-using/`: `--graph` and the graph pin, for operators;
- `docs/2-engineering/realm-readiness.md`: RR-12 adds "and holds no graph";
- `docs/2-engineering/backlog.md`: the items below;
- in `ouroboric`: the naming doc's component table (Voluspa built, screened) and long-term map, `docs/README.md`'s
  map, `check-repos.sh`'s lists, the smoke scripts' `--realm`, and a journal entry in `docs/6-journal/`.

## Name

The name `voluspa` was screened on 2026-10-19 ([screening](../../../5-research/2026-10-19-voluspa-name-screening.md)).
Voluspa is a common word from myth. The best-known use is a US candle and fragrance brand, whose marks cover
candles, fragrances and their retail, not software. No package registry holds the name. A small company, Voluspa
Labs, publishes developer tools under `@voluspalabs` on npm. The name is usable under the Ouroboric umbrella as a
component name, not as a product brand.

**Decided (founder, 2026-10-19):** the repo and the Go module are named `voluspa`, and nothing is claimed on
package registries. Why: Voluspa ships as a Go module under `github.com/ouroboric-dev/`, as the other components
do (the 2026-10-12 name-check decisions).

## Success criteria

- The client gallery's content smoke run (v0-H15, `ygg-smoke-realms.sh --brief <brief> --tag h15`, scripted
  agents on the real realms) passes with `--graph software`.
- `midgard-react` holds no graph and no stage prompt. Its pack has no `graph:`.
- Acceptance checks no less than before: on that run, every move runs the same `accept` check, on the same
  stack, with the same services, as the ledger of the last run before the change shows.
- Every moved prompt has the same SHA-256 in Voluspa as in `midgard-react` before the move.
- No Odin code reads a lead realm: a search for `Setup.Lead`, `Umbrella.Realm` and `Realm("")` finds nothing.
- The docs above match.

## Not in this change

- **General stage prompts**, and whether a flavor may add text to them or add reviewers. A later proposal.
- **The `kickstart` graph.** It comes with Asgard's automation.
- **Shared domain pieces** (Midgard's contract copy and web acceptance run), design §10.
- **Fetching a graph by tag.** Graphs come from a local store, as realms do, until iteration 2's `github` remote.

### Backlog

- **A schema version in every pack** (realm packs too, not only `graph.yaml`), when a second schema version
  exists.
- **The routing threshold in the project** (`umbrella.yaml`, beside `.ygg/routing-bench.yaml`), once a project
  writes its own bench (5c plan question 8).

## Impact

- **Repos:** `voluspa` (new), `gungnir` (graph schema version, graph pins in `umbrella.yaml`, the `graphs`
  section of `factory.yaml`), `odin` (`--graph`, the graph store and pin, prompts from the graph pack, acceptance
  per leaf realm, no lead realm), `gleipnir` (a sandbox with no stack), `midgard-react` (the graph and stage
  prompts leave, tests split), `helheim-go` (pack comment, docs), `ouroboric` (scripts, docs), `yggdrasil`
  (submodule, `go.work`, docs).
- **Founder:** creates `voluspa` with `new-repo.sh`, pushes its `ci.yml` (the pr-bot has no Workflows
  permission), and runs `setup-repo.sh` so that `test` is required.
- **Approval points:** none added. None loosened.
- **Phase 5c:** its remaining steps run on the model this change leaves, and the plan gets its erratum.
