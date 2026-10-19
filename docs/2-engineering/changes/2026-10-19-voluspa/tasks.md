---
title: Tasks for Voluspa, one software graph for every run
status: draft
date: 2026-10-19
related: [proposal.md, delta.md, ../../plans/2026-10-18-yggdrasil-v0-phase-5c/tasks.md, ../../../1-product/design/2026-10-18-ginnungagap-design.md]
style: spec
---

# Voluspa: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for
> tracking. Tasks and steps marked **founder** are done by the founder, never by an agent.

**Goal:** the graph and the stage prompts leave `midgard-react` for a new leaf, `voluspa`, as the graph
`software`. A run names its graph with `--graph`, the project pins it, and no Odin code reads a lead realm.

**Architecture:** Gungnir gives a graph a schema version, an umbrella a graph pin and the factory a `graphs`
store. A graph pack loads as a realm does (`realm.Load`, hashed from its committed files, now also in a
subfolder of a repo). Odin's `Setup` holds a `GraphPack` beside the leaf realms. Prompts of agent nodes and
reviewers come from the graph pack, a leaf's implementer, template and checks from the leaf's pinned realm.
Each pointer move runs the named acceptance check of every leaf realm that defines it. Scratch sessions start
on Gleipnir's factory layer alone, on its pinned Node image, with the model APIs as their only egress.

**Tech stack:** Go 1.26 and the pins of Phase 5c; bash and the `ouroboric` test harness; d2 and Mermaid
through `diagrams.sh`.

**Spec:** [proposal](proposal.md) and [delta](delta.md); design §5.2 to §5.4 and §8.2. Every "Decided" in the
proposal is fixed. Where this plan and the proposal differ, this plan wins; the differences are in "Questions
for the founder".

**Status:** accepted when the founder merges the pull request that adds this file.

## Global constraints

- Code is read at: `gungnir` `f58d3b7`, `gleipnir` `74b54ec`, `odin` `7b5248a`, `midgard-react` `4d145f3`,
  `helheim-go` `c3a08de`, `ouroboric` `618c8c5`. Line numbers below are at those commits.
- `ygg run --realm <anything>` exits 2, writes nothing, and prints `ygg: use --graph; a leaf's realm is pinned in the project`.
- `ygg sandbox build --realm` keeps its flag: it names a realm whose stack to build.
- The acceptance refusal's text contains `no realm of this project has an acceptance check`.
- `graph.yaml` holds `schema: 1`, required. `schema.GraphSchema = 1` in Gungnir. A higher number is refused.
- `umbrella.yaml`: top-level `graph` and `graph_version`, both or neither. Leaves keep `realm` and
  `realm_version`. A top-level `realm` or `realm_version` is refused with a reason (T001).
- `factory.yaml`: `graphs: {dir: <a clean absolute path>}`. `--graph software` finds `<dir>/software/pack.yaml`,
  whose `name` must be `software` and which must name a `graph`.
- `--graph` takes a name (no path separator, no leading dot) or a path, by `realm.Resolve`'s rule.
- `run.json` is `ygg.run/v3`: it adds `graph`, `graph_dir`, `graph_pack_sha256` and keeps `graph_version` (now
  the pack's version) and `graph_sha256`. `realm`, `realm_version` and `realm_dir` go.
- The `software` pack: `name: software`, `version: 0.1.0`, `graph: graph.yaml`, nothing else. Its graph is
  `name: software`, `version: 0.1.0`, `schema: 1`, and otherwise `midgard-react`'s `graph.yaml` at `4d145f3`.
- A run's behaviour does not change: the same nodes, prompts byte for byte, checks, acceptance check, stack and
  services. Only the scratch sessions' sandbox changes (stack and egress, decided). `midgard-react` stays 0.1.0.
- Graphs have descriptive names. Myth names stay with realms and components.
- A pack "holds a recipe" when it has `checks`, `leaf`, `leaves`, `sandbox` or `services`
  (`schema.Pack.HoldsRecipe`). Only such a graph pack serves the leaves that pin no realm (test data).
- Go tests use the standard library and the modules a repo already requires. `voluspa` requires `gungnir` only.
- Write each test first and watch it fail (invariant 2). Never weaken a guardrail (invariant 7): no gate, check,
  mount or egress is loosened; the scratch egress only shrinks.
- No agent reads or searches `huldra` or `~/brunogbv/ouroboric-private/` (invariant 4).
- Commits end with `(voluspa-T0nn)` and `Co-Authored-By: Claude <model> <noreply@anthropic.com>`. No session
  links. Stage files by path after `git status --short`.
- Push and open PRs only with `../ouroboric/scripts/as-bot.sh <repo> git push -u origin <branch>` and
  `as-bot.sh <repo> gh pr create ...`. A root `.github/workflows/` file is pushed by the founder.
- A docs file passes `YGG_CHECKS_PATH="$PATH" bash helheim-go/devcontainer/checks/docs.sh` (run in the repo,
  no problem in a changed file) and `uvx -q --from 'pre-commit==4.6.2' pre-commit run --files <changed>`.
- Deletions (`git rm`, `rm`) are one per command, never inside a chain.

## Review focus

1. **An old project's `umbrella.yaml` pins a lead realm** at its top (every project made before this change,
   such as the founder's `~/ygg-it` projects). It must be refused with the way to pin a graph, never parsed with
   the pin dropped. Test `TestAnUmbrellaWithATopLevelRealmIsRefusedWithTheWayToPinAGraph` (T001) and
   `TestARunOnAProjectThatPinsALeadRealmStopsBeforeAnythingStarts` (T006).
2. **A graph pack whose files git does not track.** A pack folder inside a repo that is untracked or ignored must
   be refused, never hashed as an empty set. A dirty file elsewhere in the repo must not refuse it. Test
   `TestASubfolderOfAGitRepoIsHashedFromItsCommittedFiles` cases (d) and (e) (T011).
3. **A resume of a run that a lead realm led** (`ygg.run/v2`). It must stop with a reason before any leaf is
   reset or any sandbox starts. Test `TestAResumeOfARunLedByARealmIsRefusedAndTouchesNothing` (T007).
4. **A move whose leaf's realm has no acceptance check** (the `api` leaf's move). It must still run the other
   realm's check over a snapshot of both leaves; with two realms, realm-name order, and the second never runs
   after the first fails. Tests `TestEveryMoveRunsTheAcceptanceCheckOfEveryLeafRealmThatHasOne` and
   `TestAcceptanceRunsInRealmNameOrderAndStopsAtTheFirstFailure` (T009).
5. **`--graph` given as a path to a checkout at another version** than the project's pin. The pin check applies
   to a path as to a name, and compares the version too. Test
   `TestARunWhoseGraphIsNotTheProjectsPinStopsBeforeAnythingStarts`, case "path, other version" (T006).

## How each task lands

Each repo works on one branch, `voluspa`, from `origin/main`; its tasks stack on it, one commit per task. One
pull request per repo, except `voluspa` (T003, then T004), `yggdrasil` (T005, then T017) and `ouroboric` (T013,
then T016): their second PR's branch is `voluspa-2`, from `origin/main` after the first merged. Before a PR, in
the repo's folder:

```bash
gofmt -l .                        # prints nothing (Go repos)
go vet ./...
GOWORK=off go test -race ./...    # what CI runs
uvx -q --from 'reuse==5.0.2' reuse lint -q
```

A shell script also passes `uvx -q --from 'shellcheck-py==0.11.0.1' shellcheck -x -s bash <file>`. Develop
through `yggdrasil/go.work` until a sibling's PR merges, then pin its `main` and tidy:

```bash
../../ouroboric/scripts/as-bot.sh --read all git -C ../gungnir fetch -q origin
GOWORK=off go get github.com/ouroboric-dev/gungnir@$(git -C ../gungnir rev-parse origin/main)
GOWORK=off go mod tidy
```

The PR body names the tasks, lists their acceptance criteria with the named tests' output, and the PRs it needs
merged first. The founder merges once CI's checks are green.

## Order

| Task | Repo | Size | Depends on |
| --- | --- | --- | --- |
| voluspa-H01 (founder) create `voluspa`; the pr-bot reaches it | GitHub | S | this plan merged |
| voluspa-T001 graph schema version, graph pin, `graphs` store | `gungnir` | M | this plan merged |
| voluspa-T002 a sandbox with no stack | `gleipnir` | S | this plan merged |
| voluspa-T003 the `software` graph pack and its tests | `voluspa` | M | H01, T001 merged |
| voluspa-T004 Voluspa's CI (`test`) | `voluspa` | S | T003 merged |
| voluspa-T005 the submodule and `go.work` | `yggdrasil` | S | T003 merged |
| voluspa-H02 (founder) the baseline content smoke run | founder's machine | S | before the odin PR merges |
| voluspa-T006 the project pins its graph | `odin` | M | T001, T002 merged |
| voluspa-T007 `--graph`, the graph store, `run.json` v3 | `odin` | M | T006 |
| voluspa-T008 every leaf's realm from its pin; prompts from the graph pack | `odin` | M | T007 |
| voluspa-T009 acceptance per leaf realm | `odin` | M | T008 |
| voluspa-T010 scratch sessions on the factory layer; the routing threshold | `odin` | S | T009 |
| voluspa-T011 `ygg doctor` checks the graphs; a subfolder's committed files | `odin` | M | T010 |
| voluspa-T012 the real realms with Voluspa; example configs; docs | `odin` | S | T011, T005 |
| voluspa-T013 the smoke scripts take `--graph` | `ouroboric` | S | T012 (merge with or after odin) |
| voluspa-T014 the graph and stage prompts leave `midgard-react` | `midgard-react` | S | odin PR merged |
| voluspa-T015 `helheim-go`'s pack comment, docs and test | `helheim-go` | S | odin PR merged |
| voluspa-H03 (founder) the content smoke run with `--graph software` | founder's machine | S | T013, T014 merged |
| voluspa-T016 `check-repos.sh`, the naming doc, the journal | `ouroboric` | S | H03 |
| voluspa-T017 pointers, docs, diagrams, backlog | `yggdrasil` | M | all above |

Pull requests, in order: `gungnir` and `gleipnir` beside each other; `voluspa` (T003); `voluspa` (T004) and
`yggdrasil` (T005); `odin`; `ouroboric` (T013); `midgard-react` and `helheim-go`; `ouroboric` (T016);
`yggdrasil` (T017). **Odin must not lose the graph before Voluspa has it** (T003 merges before the odin PR), and
**`midgard-react` keeps its graph until Odin reads Voluspa's** (T014 after the odin PR).

**How this sequences with Phase 5c.** Merged in 5c and not touched here: `ouroboric` #59 (the scripts of v0-T262
and v0-T263). This change owns their `--realm` → `--graph` (T013) and the example configs (T012). v0-T265
(yggdrasil #69) is done on the tree from before this change. The 5c founder steps still to do run after T017,
on the final model: v0-H16 (`ygg-smoke-grade.sh`, now `--graph`) and v0-H17 (`ygg-smoke-real.sh`). T017's
pointer bump re-runs v0-T265's exit check `TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents`, now
with `voluspa` beside `odin` (T005). T017 adds only this change's backlog items.

---

### Task voluspa-H01 (founder): create `voluspa`, and let the pr-bot reach it

**Named test:** `PASS voluspa bot`. **Layer:** GitHub. **Size:** S. **Depends on:** this plan merged.

- [ ] **Step 1 (founder):** with the short-lived admin token (new-repo.sh's header says which), in
  `~/brunogbv/ouroboric/ouroboric`:

```zsh
GH_TOKEN=... scripts/new-repo.sh --org ouroboric-dev --ci reuse,markdown,shell,actions,yaml \
  voluspa "The graph library of Yggdrasil: one folder per graph, with its stage prompts."
```

  Expect the repo made, pushed and protected, then the after-create message: "Add voluspa to the pr-bot".

- [ ] **Step 2 (founder):** add `voluspa` to the `ouroboric-pr-bot` installation (the message's link, Repository
  access). Check: `scripts/as-bot.sh --read all scripts/check-repos.sh --check bot --check ruleset voluspa`.
  Expected: `PASS voluspa bot` and `PASS voluspa ruleset`.

### Task voluspa-T001: graph schema version, graph pin and `graphs` store

**Files (in `gungnir`):**

- Modify: `schema/graph.go` (`Graph`, `ParseGraph` at :162, comments at :46, :93), `schema/graph.schema.json`,
  `schema/umbrella.go` (:20-23, `checkRealms` :94, `Pins` :164-180), `schema/umbrella.schema.json` (:13-14),
  `schema/factory.go` (:22, :36-41, :251), `schema/factory.schema.json` (:55-60), `schema/pack.go` (comments at
  :15-18, :36, :88), `realm.go`, `remote.go` (comment :45), `docs/architecture.md`, `docs_test.go`, every graph
  fixture in `schema/*_test.go` (add `schema: 1`), `schema/umbrella_realm_test.go`, `realm_test.go` (:53)
- Create: `schema/graph_schema_test.go`, `schema/factory_graphs_test.go`, `schema/pack_recipe_holds_test.go`

**Interfaces:**

- Produces: `schema.GraphSchema = 1`; `schema.Graph.Schema int` (`yaml:"schema"`), required, integer ≥ 1.
- Produces: `schema.Umbrella.Graph`, `.GraphVersion string` (`graph`, `graph_version`); `Umbrella.Realm` and
  `.RealmVersion` removed. `Umbrella.Pins()` returns leaf pins only (`Where` is a child path, never `.`).
- Produces: `schema.Factory.Graphs *Graphs{Dir string}` (`graphs`), checked as `realms.dir` is.
- Produces: `func (p *Pack) HoldsRecipe() bool`; `gungnir.ValidGraph(string) bool` (the pattern of `ValidRealm`).

- [ ] **Step 1: Write the failing tests.**
  - `TestAGraphStatesItsSchemaVersion`: `schema: 1` loads with `Schema == 1`; no `schema`, `schema: 0` and
    `schema: "1"` are refused naming `schema`; `schema: 2` is refused and the error contains `needs graph schema 2`.
  - `TestTheUmbrellaPinsItsGraphAndEachLeafItsRealm`: `graph: software` with `graph_version: 0.1.0` loads; either
    alone is refused ("a pin is both"); `graph: Software` and `graph_version: 1` are refused; `Pins()` of an
    umbrella with a graph and two pinned leaves holds the two leaves only.
  - `TestAnUmbrellaWithATopLevelRealmIsRefusedWithTheWayToPinAGraph`: `realm: midgard-react` with
    `realm_version: 0.1.0` at the top, and each alone, are refused; the error contains `graph and graph_version`
    and `each leaf keeps its realm`. A leaf's `realm` still loads.
  - `TestFactoryNamesTheGraphStore`: `graphs: {dir: /abs/voluspa}` loads; a relative, unclean or `/` dir and an
    unknown key are refused; no `graphs` section loads.
  - `TestAGraphPackHoldsNoRecipe`: a pack of `name`, `version`, `graph` (and `routing`) gives `false`; adding
    each of `checks`, `leaf`, `leaves`, `sandbox`, `services` gives `true`.
  - `TestTheArchitecturePageNamesTheGraphPins` (`docs_test.go`): the page mentions `schema: 1`, `graph_version`,
    `graphs:` and `HoldsRecipe`.
- [ ] **Step 2:** `go test ./... -run 'SchemaVersion|PinsItsGraph|TopLevelRealm|GraphStore|HoldsNoRecipe|GraphPins'`.
  Expected: FAIL (fields and functions undefined).
- [ ] **Step 3:** Implement. `ParseGraph` refuses `Schema > GraphSchema` with
  `%s: the graph needs graph schema %d, and this Gungnir reads schema %d at most`. `ParseUmbrella` looks for a
  top-level `realm` or `realm_version` before the JSON schema runs, and refuses with
  `%s: the top-level realm and realm_version are gone (change voluspa): a project pins its graph as graph and graph_version, such as graph: software and graph_version: 0.1.0; each leaf keeps its realm and realm_version`.
  Add `schema: 1` to every graph fixture. Reword every comment that says "lead realm": `RealmFrom` is "the graph
  pack's (the default) or the realm of the task's leaf"; `Pack.Leaves` "the default leaves of the graph";
  `PackRouting` "of a graph pack"; `PackSandbox.Acceptance` "a leaf realm's".
- [ ] **Step 4:** Run the whole suite. Expected: `ok`. Then `grep -rni 'lead realm' --include='*.go' .`.
  Expected: no output.
- [ ] **Step 5:** `docs/architecture.md`: the graph's `schema`, the umbrella's graph pin, the `graphs` store, a
  graph pack and `HoldsRecipe`. Commit, push, open the PR.

**Named test:** the six tests above. **Size:** M. **Depends on:** this plan merged.

### Task voluspa-T002: a sandbox with no stack

**Files (in `gleipnir`):**

- Modify: `sandbox/images.go` (`Build`'s base loop at :73), `sandbox/images_test.go`, `sandbox/scratch_test.go`,
  `sandbox/integration_test.go`, `sandbox/docs_test.go`, `docs/architecture.md`

**Interfaces:**

- Produces: `func FactoryImages() Images`, equal to `ImagesFor(NodeImage)`: the factory layer alone, on the
  Node image Gleipnir pins (`images.go:24`). `Config.ImagesOf` (`config.go:66`) is unchanged: a spec with no
  `Stack` takes `Config.Images`, which Odin sets to `FactoryImages()` (T010).

- [ ] **Step 1: Write the failing tests.**
  - `TestASandboxWithNoStackStartsTheFactoryLayerOnTheNodeImage`: `FactoryImages() == ImagesFor(NodeImage)`; a
    scratch spec with `Stack: ""` and `Config{Images: FactoryImages()}` renders a compose file whose `work` image
    is `FactoryImages().Work`, with no `services` and the one scratch volume.
  - `TestBuildOfTheFactoryLayerPullsTheNodeImageOnce`: `Build(ctx, NodeImage)` with the stub engine logs one
    `pull` of `NodeImage`, then the `fw` and `work` builds tagged as `FactoryImages()`.
  - `TestTheArchitecturePageDescribesASandboxWithNoStack`: the page mentions `FactoryImages` and "no stack".
  - `TestAScratchSandboxWithNoStackRunsTheAgentCLIs` (tag `sandbox`): on a real engine, after `Build(ctx,
    NodeImage)`, a scratch sandbox runs `bash -c 'command -v node claude opencode git timeout'` with exit 0, and
    its firewall host list is exactly the egress given.
- [ ] **Step 2:** `go test ./sandbox -run 'NoStack|NodeImageOnce'`. Expected: FAIL (`FactoryImages` undefined).
- [ ] **Step 3:** Add `FactoryImages`. In `Build`, pull `NodeImage` once when `stack == NodeImage`.
- [ ] **Step 4:** Run the suite, then `go test -tags sandbox -run NoStack ./sandbox` on the engine. Expected: `ok`.
  If no engine is up, the PR says so and the founder runs it in H03.
- [ ] **Step 5:** Docs (a sandbox with no stack is the factory layer on the Node image), commit, push, open the PR.

**Named test:** the four tests above. **Size:** S. **Depends on:** this plan merged.

### Task voluspa-T003: the `software` graph pack and its tests

**Files (in `voluspa`):**

- Create (by `scaffold-component.sh`): `go.mod`, `AGENTS.md`, `docs/architecture.md`, `.devcontainer/devcontainer.json`,
  `.gitignore`, sections of `README.md`
- Create: `software/pack.yaml`, `software/graph.yaml`, `software/prompts/` (eight files), `pack_test.go`,
  `prompts_test.go`, `LICENSES/MIT.txt`
- Modify: `REUSE.toml` (an annotation `path = ["software/**"]`, MIT)

**Interfaces:**

- Consumes: T001's `schema.Graph.Schema`, `Pack.HoldsRecipe`. Produces: the graph pack `software` 0.1.0, which
  T007 to T012 load.

- [ ] **Step 1:** Clone and scaffold: `as-bot.sh --read all git clone https://github.com/ouroboric-dev/voluspa.git
  /home/brunogbv/brunogbv/ouroboric/yggdrasil/voluspa`, branch `voluspa`, then
  `../ouroboric/scripts/scaffold-component.sh voluspa "The graph library: one folder per graph, with its stage prompts." voluspa`
  from the umbrella. Write the architecture page's Responsibilities and Depends on (Gungnir's schemas) from the
  delta. Copy `midgard-react/LICENSES/MIT.txt` and add the `software/**` annotation (Question 2).
- [ ] **Step 2: Move the tests first.** From `midgard-react` at `4d145f3`, into package `voluspa`, each loading
  `software/` instead of `.`:
  - unchanged but for paths: `TestTheGraphHasTheStagesOfSpecSection42InOrder`,
    `TestTheContractGateComesBeforeTheMoveAndTheMoveShipsTheRoutingIndexes` (its `Routing != nil` check reads the
    `software` pack), and from `prompts_test.go` and `build_prompts_test.go` the five planning-prompt tests,
    `TestTheReviewersSayWhatToLookAtAndHowToNameFindings` and `TestEveryBuildPromptIsThereAndKeepsTheBenchmarkOutOfAgentsReach`
    with `buildPrompts` = the three reviewer prompts;
  - `TestEveryTaskRunsTheLoopWithThreeReviewersThenTheGatesAndTheMoveWithAcceptance` without its last check (the
    pack defines `accept`), which stays in `midgard-react` (T014);
  - `TestEveryPromptIsUsedAndEveryPromptTheGraphNamesIsThere` without the `implementer.md` seed;
  - `TestTheSpecPromptNamesTheGallerysRealmsAtTheirVersions`: `spec.md` contains `` `midgard-react` 0.1.0 `` and
    `` `helheim-go` 0.1.0 ``.
  - New: `TestTheSoftwarePackHoldsAGraphAndItsPromptsOnly`: name `software`, version `0.1.0`, graph `graph.yaml`,
    `HoldsRecipe()` false, graph `Schema == 1`; `software/` holds `pack.yaml`, `graph.yaml` and `prompts/` with the
    eight files and nothing else. `TestEveryFolderWithAPackIsAGraphPack`: each top-level folder that holds
    `pack.yaml` is a graph pack named as the folder.
- [ ] **Step 3:** `go test ./...` through `go.work` (add `./voluspa` locally, not committed in the umbrella).
  Expected: FAIL (`software/` is missing).
- [ ] **Step 4:** Copy the eight prompts byte for byte with `git -C ../midgard-react show 4d145f3:prompts/<f>`.
  Write `graph.yaml` from `4d145f3:graph.yaml`, changing only the header comment (the software graph, held by
  Voluspa), `name: software` and the new line `schema: 1` after `version`. Write `pack.yaml` (Global constraints)
  with a header comment.
- [ ] **Step 5:** The suite passes, through `go.work` and, after pinning T001's merged `gungnir`, with `GOWORK=off`.
- [ ] **Step 6: Proof.** In the umbrella:

```bash
for f in design spec conformance plan reuse-review reviewer-spec reviewer-simplicity reviewer-quality; do
  a=$(git -C midgard-react show 4d145f3:prompts/$f.md | sha256sum | cut -d' ' -f1)
  b=$(sha256sum < voluspa/software/prompts/$f.md | cut -d' ' -f1)
  printf '| %s.md | %s | %s |\n' "$f" "$a" "$b"; [ "$a" = "$b" ] || echo "DIFFERS $f"
done
diff <(git -C midgard-react show 4d145f3:graph.yaml) voluspa/software/graph.yaml
```

  Expected: eight rows with equal hashes, no `DIFFERS`; the diff shows only the header comment, `name` and the
  `schema: 1` line. Both go into the PR body, with the commit `4d145f3`.

- [ ] **Step 7:** Docs check and pre-commit on the new docs. Commit, push, open the PR.

**Named test:** `voluspa` `go test ./...`; the SHA-256 table. **Size:** M. **Depends on:** H01, T001 merged.

### Task voluspa-T004: Voluspa's CI

**Files (in `voluspa`):**

- Create: `.github/workflows/ci.yml`. Modify: `README.md` (the `test` check), `docs/architecture.md` (CI)

- [ ] **Step 1:** Write `ci.yml` as `helheim-go/.github/workflows/ci.yml` is, without `YGG_REQUIRE_TEMPLATES`: the
  pinned Go image, `GOWORK=off`, `GOTOOLCHAIN=local`, `GOFLAGS=-mod=readonly`; gofmt, `go vet ./...`,
  `go test -race ./...` as a non-root user, govulncheck `v1.8.0`; one job `test`. Run
  `go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.12 .github/workflows/ci.yml`. Expected: no output.
- [ ] **Step 2:** Commit. **Founder:** push the branch and open the PR. Expected: `test` and `lint` pass.
- [ ] **Step 3 (founder):** after the merge, `GH_TOKEN=... scripts/setup-repo.sh --org ouroboric-dev voluspa`,
  then `scripts/as-bot.sh --read all scripts/check-repos.sh --check ruleset voluspa`. Expected: `PASS voluspa ruleset`.

**Named test:** the `test` workflow; `--check ruleset voluspa`. **Size:** S. **Depends on:** T003 merged.

### Task voluspa-T005: the submodule and `go.work`

**Files (in `yggdrasil`):** Modify: `.gitmodules`, `go.work`, the new `voluspa` gitlink

- [ ] **Step 1:** `git switch -c voluspa`, then `git submodule add https://github.com/ouroboric-dev/voluspa.git voluspa`
  (T003's clone is reused); fetch it (`as-bot.sh --read all git -C voluspa fetch -q origin`), then
  `git -C voluspa switch --detach origin/main`; add `./voluspa` to `go.work`'s `use`.
- [ ] **Step 2:** `go test ./...` in `voluspa` with `go.work`. Expected: `ok`. Commit, then `git ls-tree HEAD voluspa`.
  Expected: a `160000` entry at T003's merge commit.
- [ ] **Step 3:** Push, open the PR.

**Size:** S. **Depends on:** T003 merged.

### Task voluspa-H02 (founder): the baseline content smoke run

The last run before the change, whose ledger H03 compares with. It costs nothing (scripted agents).

- [ ] **Step 1 (founder):** on today's `main` of every repo (odin `7b5248a` or later, before the odin PR of this
  change merges), as v0-H15 did:

```zsh
cd ~/brunogbv/ouroboric/ouroboric/scripts
./ygg-smoke-realms.sh --folder ~/ygg-it/content --env ~/ygg-it/content/empty.env --realm midgard-react \
  --brief ~/brunogbv/ouroboric/yggdrasil/odin/testdata/smoke-content/brief.md --tag h15-base --clip
```

  Expect exit 0 and `~/ygg-it/content/h15-base-report.txt`. Keep the project folder it names. If it fails,
  send the report: the comparison then uses the 2026-10-18 v0-H15 project (`smoke-realms-20261018-113734`).

**Size:** S. **Depends on:** nothing; before the odin PR merges.

### Task voluspa-T006: the project pins its graph

**Files (in `odin`):**

- Modify: `go.mod`, `go.sum` (pin T001's and T002's merged `gungnir` and `gleipnir`); every `testdata/*/graph.yaml`,
  `testdata/*/*/graph.yaml` and inline test graph (`schema: 1`); `internal/run/run.go` (`PinLead` :80, :153;
  `pinLead` :809, :834-856), `internal/realm/set.go` (the `.` pin, :212-214), `internal/cli/deps.go` (:185-187),
  `internal/routing/wiring.go` (:81), `testdata/routing/project/umbrella.yaml`, `internal/tree/treetest/treetest.go`
  (:25, :86), `internal/run/realms_test.go`, `internal/realm/set_test.go`, `internal/cli/deps_test.go`,
  `internal/routing/wiring_test.go`

**Interfaces:**

- Produces: `run.Setup.PinGraph bool`; `func (r *Run) pinGraph(ctx context.Context) error`, which writes
  `Umbrella.Graph` and `.GraphVersion` from the pack `--realm` loaded, in a commit `Pin the graph <name> <version>`;
  `func (s *Setup) checkGraphPin() error`. `treetest.Node.GraphPin Pin` sets an umbrella's graph pin; `Pin` stays
  a leaf's realm pin.

- [ ] **Step 1: Write the failing tests.**
  - `TestTheFirstRunPinsTheGraphItWasGivenByName` (replaces `TestTheFirstRunPinsTheLeadRealmItWasGivenByName`):
    the project's `umbrella.yaml` then holds `graph:` and `graph_version:` with the pack's name and version, and
    no top-level `realm:`; the commit's subject is `Pin the graph <name> <version>`. A pack given by path pins nothing.
  - `TestARunWhoseGraphIsNotTheProjectsPinStopsBeforeAnythingStarts`, four cases: another name by name; the same
    name at another version by name; the same name at another version by path; the same name and version by path
    (passes). Each refusal contains `the project is built with the graph`, and leaves no `.factory/runs/*` and no
    sandbox started (the fake records none).
  - `TestARunOnAProjectThatPinsALeadRealmStopsBeforeAnythingStarts`: `umbrella.yaml` with top-level
    `realm: toy` → `ygg run` exits 2 and stderr contains `graph and graph_version`.
  - `TestTheWiringIndexTakesALeafsRealmFromItsOwnPinOnly`: with the fixture's `web` pinned to `midgard-react 0.1.0`
    and the top pinned to `graph: software`, `wiring.golden.md` and `impact.golden.json` are unchanged byte for
    byte; a leaf with no pin gets no `uses-realm` and no `needs` edge.
  - In `deps_test.go`: a leaf that pins no realm is refused (`pins no realm`), whatever the umbrella pins.
- [ ] **Step 2:** `go test ./... -run 'PinsTheGraph|NotTheProjectsPin|PinsALeadRealm|OwnPinOnly|PinsNoRealm'`.
  Expected: FAIL (the build breaks on `Umbrella.Realm`).
- [ ] **Step 3:** Pin the siblings; add `schema: 1` to every graph fixture; replace each `Umbrella.Realm` read:
  `pinGraph`, `checkGraphPin` (name and version, by name or path, before `collectRealms`), no lead pin in
  `realm.Collect`, no fallback in `deps.go` and `wiring.go`. The fixture pins `graph: software`,
  `graph_version: 0.1.0`, and `web: {realm: midgard-react, realm_version: 0.1.0}`.
- [ ] **Step 4:** The suite passes, with `go.work` and `GOWORK=off`. Commit.

**Named test:** the five tests above. **Size:** M. **Depends on:** T001, T002 merged.

### Task voluspa-T007: `--graph`, the graph store and `run.json` v3

**Files (in `odin`):**

- Modify: `internal/cli/cli.go` (:34, :128-141, :301), `internal/run/run.go` (`Options.Realm` :37, `Setup` :61-63,
  `Prepare` :115-138, `record` :883, :892, `open` :1025-1031), `internal/run/state.go` (:31, :62-64, :207),
  `internal/realm/realm.go` (`Store`, `Resolve` :147-179), every `"--realm"` of `ygg run` in `internal/**/*_test.go`
  (40, in 14 files), `internal/run/realms_test.go`, `internal/realm/realm_test.go`, `internal/cli/cli_test.go`
- Create: `internal/run/graph_test.go`

**Interfaces:**

- Produces: `run.Options.Graph string` (replaces `Realm`); `run.Setup.GraphPack *realm.Realm` (replaces `Lead`,
  `Pack` and `RealmDir`); `realm.Store{Dir, Kind string}` (`Kind` is `realm` or `graph`, for messages);
  `realm.Resolve(ref string, store *Store, kind string) (dir string, byName bool, err error)`;
  `run.StateSchema = "ygg.run/v3"`; `State.Graph`, `State.GraphDir`, `State.GraphPackSHA256` (`graph`, `graph_dir`,
  `graph_pack_sha256`). Until T008, `RealmOf` falls back to `GraphPack` as it fell back to the lead.

- [ ] **Step 1: Write the failing tests.**
  - `TestAGraphIsNamedAndFoundInTheGraphStore`: `graphs: {dir: D}` and `--graph software` load `D/software`; a
    `D/software` whose pack is named `other` is refused (`holds the graph other`); a name with no `graphs`
    section is refused with `factory.yaml has no graphs section to find it in`; `--graph ./D/software` loads by path.
  - `TestRunWithRealmStopsAndSaysUseGraph`: `ygg run --realm toy` and `ygg run --graph <toy> --realm toy` exit 2
    with `ygg: use --graph; a leaf's realm is pinned in the project`; no `.factory/runs`. `ygg run` with neither
    says `run needs --graph`.
  - `TestRunJSONRecordsTheGraphAndAResumeRefusesOneThatChanged`: `run.json` has `schema: ygg.run/v3`, `graph`,
    `graph_version`, `graph_dir`, a 64-hex `graph_pack_sha256`, and no `realm_dir` key; after a prompt of the
    graph pack (a plain folder) changes, `ygg resume` exits 2 with `the graph toy changed since the run started`.
  - `TestAResumeOfARunLedByARealmIsRefusedAndTouchesNothing`: a `run.json` of schema `ygg.run/v2` with
    `realm_dir`: `ygg resume` exits 2, stderr contains `can't be resumed` and `start a new run with --graph`; each
    leaf's `HEAD` and `git status` are unchanged, and the fake sandbox records no `Up` and no `Down`.
  - `ygg status` prints `graph:    toy 0.3.0`.
- [ ] **Step 2:** Run them. Expected: FAIL (`--graph` is not a flag).
- [ ] **Step 3:** Implement. Prepare resolves `--graph` in `Config.Graphs` and refuses a pack with no graph:
  `the pack %s holds no graph; --graph names a graph pack, such as software in Voluspa`. `LoadState` reads the
  `schema` field first and refuses `ygg.run/v2` with
  `%s/run.json: run %s was led by a realm (schema ygg.run/v2), from before graphs, so it can't be resumed; start a new run with --graph`.
  `open` loads `State.GraphDir` and refuses a changed `graph_pack_sha256` or version with
  `the graph %s changed since the run started (%s), so its prompts and positions are not the ones the run began with; start a new run`.
  `run_started`'s note is `graph: <name> <version> sha256:<hash>; realms: ...`. Change the tests' `--realm` to
  `--graph`; `sandbox build --realm` stays.
- [ ] **Step 4:** The suite passes. Commit.

**Named test:** the four tests above. **Size:** M. **Depends on:** T006.

### Task voluspa-T008: every leaf's realm from its pin; prompts from the graph pack

**Files (in `odin`):**

- Modify: `internal/run/run.go` (`checkNode` :250, :263, `checkBody` :282-312, `checkSession` :319-321,
  `collectRealms` :374, `Realm` :423-429, `RealmOf` :431-442, `leafRecord` :501, `recipeOf` :616, `createLeaf`
  :954-957), `internal/realm/set.go` (`Set.Lead` :15, `Collect` :207), `internal/engine/init.go` (:123-124),
  `internal/engine/loop.go` (:84-88, :147-149, :195), `internal/engine/scratch.go` (:37), `internal/engine/engine.go`
  (:189, :345-352), `internal/plan/expand.go` (:1), `internal/run/prepare.go` (:81, :91), tests
- Create: `internal/run/leafpins_test.go`, `internal/engine/prompts_source_test.go`

**Interfaces:**

- Produces: `func (s *Setup) RealmOf(repo string) (*realm.Realm, error)`: the leaf's pinned realm, or the graph
  pack when the leaf pins none and `GraphPack.Pack.HoldsRecipe()`, else
  `the leaf %s pins no realm; every leaf of a project pins its realm (realm and realm_version in umbrella.yaml)`.
- Produces: `func (s *Setup) NodeRealm(n schema.Node) (*realm.Realm, error)` (`n.Realm`, else `RealmOf(n.Repo)`);
  `func (s *Setup) PromptFile(realmName, file string) string` (`""` is the graph pack). `Setup.Realm` is removed.
- Produces: `realm.Collect(have []*Realm, pins []schema.Pin, load func(string) (*Realm, error)) (*Set, error)`;
  `have` is the graph pack when it holds a recipe, else empty. `realm.Set{Realms}` has no `Lead`.

- [ ] **Step 1: Write the failing tests.**
  - `TestALeafWithNoPinStopsTheRunBeforeAnythingStarts`: a graph pack without a recipe and a project leaf
    `repos/api` with no `realm` → Prepare fails with `the leaf repos/api pins no realm`; no run folder.
  - `TestAPackThatHoldsAGraphAndARecipeServesTheLeavesThatPinNone`: `testdata/toy` by path: `repos/app`'s checks
    come from `toy`, and `run.json`'s `realms` holds `toy`.
  - `TestPromptsComeFromTheGraphPackAndTheImplementerFromTheLeafsRealm`: the graph pack's `design.md` and
    `reviewer-spec.md` hold `GRAPH-PACK`; the leaf realm's implementer holds `LEAF-REALM` and it also has a
    `prompts/reviewer-spec.md` holding `WRONG`. The scripted sessions' prompts: design and reviewer contain
    `GRAPH-PACK` and not `WRONG`; the implementer's contains `LEAF-REALM`.
  - `TestARealmPackIsRefusedAsAGraph` (replaces `TestARealmWithoutAGraphCannotLead`): `--graph` naming
    `helheim-toy` fails with `holds no graph`.
  - `TestCollectLoadsOnlyTheRealmsTheLeavesPin` (replaces `TestThePinOfTheLeadRealmNamesTheLeadRealm`).
  - In `init_test.go`: an existing leaf with no pin, under a graph pack without a recipe, is refused by init.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement, then `grep -rnE 'Setup\.Lead|\.Lead\b|Realm\(""\)' --include='*.go' internal`.
  Expected: no output.
- [ ] **Step 4:** The suite passes. Commit.

**Named test:** the six tests above. **Size:** M. **Depends on:** T007.

### Task voluspa-T009: acceptance per leaf realm

**Files (in `odin`):**

- Modify: `internal/run/prepare.go` (`prepareSandbox` :38-44, `SnapshotSandbox` :141-164), `internal/run/sandbox.go`
  (`SnapshotRunner` :107-138), `internal/run/run.go` (`checkNode` :262-266, `checkBody` :308-312),
  `internal/engine/land.go` (:118-123, `runAcceptance` :181-198), `internal/engine/engine.go` (`runChecks`
  :345-352), `internal/engine/init.go` (`checkLeaves`), `internal/run/snapshot_sandbox_test.go`
- Create: `internal/engine/acceptance_test.go`

**Interfaces:**

- Produces: `func (s *Setup) AcceptanceRealms(check string) []*realm.Realm`: the distinct realms of the
  project's leaves and of the leaves Start creates, that define `check`, sorted by name.
- Produces: `func (s *Setup) SnapshotSandbox(rl *realm.Realm) (stack string, egress []string, services []gungnir.Service, err error)`
  (stack `rl.Acceptance`; services and egress of every leaf's realm, as today);
  `func (r *Run) SnapshotRunner(ctx context.Context, node string, rl *realm.Realm, revs map[string]string) (gungnir.Runner, error)`,
  whose sandbox key and folder are `snapshot/<node>/<realm>`.
- Produces: an acceptance `check_result` line carries `ygg.realm.name`; its log is
  `logs/<node>-<attempt>-<check>-<realm>.log`.

- [ ] **Step 1: Write the failing tests.**
  - `TestEveryMoveRunsTheAcceptanceCheckOfEveryLeafRealmThatHasOne`: realms `api-toy` (no `accept`) and `web-toy`
    (`accept`, an acceptance stack, a service); the move of the `api` leaf runs `web-toy`'s `accept` in a sandbox
    `snapshot/<node>/web-toy` on `web-toy`'s acceptance stack, whose spec has the services of both realms and
    whose snapshot holds both leaves; its `check_result` has `ygg.realm.name: web-toy`. A run with no sandbox
    runs the same check on the host.
  - `TestAcceptanceRunsInRealmNameOrderAndStopsAtTheFirstFailure`: realms `a-toy` and `b-toy` both define `accept`.
    Both pass: two lines, `a-toy` then `b-toy`. `a-toy`'s fails: the move fails, and there is no `b-toy` line
    and no `snapshot/<node>/b-toy` sandbox.
  - `TestAProjectWhereNoLeafRealmHasTheAcceptanceCheckIsRefused`: a project whose pinned leaves' realms lack
    `accept` fails Prepare with `no realm of this project has an acceptance check`; a fresh project whose leaves
    file names only such realms is refused by init before any leaf is created (no `repo_created` line,
    `umbrella.yaml` unchanged) (Question 1).
  - `TestARealmWithAnAcceptanceCheckAndNoAcceptanceStackIsRefusedBeforeTheRunStarts` (replaces
    `TestARealmWithNoAcceptanceStackHasNoSnapshotSandbox`): with a sandbox, at Prepare and at init.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement. `runAcceptance` runs, for each check of `n.Acceptance`, each realm of
  `AcceptanceRealms(check)` in order, in its own snapshot sandbox (or on the host with no sandbox), and returns
  the first `*checkFailed`. `runChecks` runs a leaf's checks only, from `NodeRealm(n)`.
- [ ] **Step 4:** The suite passes. Commit.

**Named test:** the four tests above. **Size:** M. **Depends on:** T008.

### Task voluspa-T010: scratch sessions on the factory layer; the routing threshold

**Files (in `odin`):**

- Modify: `internal/run/prepare.go` (`SandboxSetup.Egress` :26, :35-37, :49, :60), `internal/run/sandbox.go`
  (`ScratchRunner` :86-97), `internal/engine/routing.go` (:38-41), `internal/cli/sandbox.go` (:62-90),
  `internal/run/prepare_test.go` (:47), `internal/run/sandbox_build_test.go` (:65), `internal/engine/scratch_test.go`,
  `internal/cli/sandbox_test.go`

**Interfaces:**

- Consumes: T002's `sandbox.FactoryImages()`. `SandboxSetup.Egress` is removed; scratch egress is `SandboxSetup.Hosts`.

- [ ] **Step 1: Write the failing tests.**
  - `TestAScratchSandboxStartsOnTheFactoryLayerWithTheModelAPIsAsItsOnlyEgress`: a leaf realm with egress
    `registry.npmjs.org`, `api.osv.dev` and a `claude-code` role: the scratch spec has `Stack == ""` and `Egress`
    equal to `agents.Hosts("claude-code")`, sorted, with neither registry; `Config.Images == sandbox.FactoryImages()`.
    A graph pack with no `sandbox` block prepares with a sandbox section.
  - `TestTheRoutingThresholdComesFromTheGraphPack`: a graph pack with `routing: {threshold: 1.0}` and a bench the
    index misses → the move fails with `does not ship`; the same block in the leaf realm's pack only → the index
    ships unmeasured.
  - `TestSandboxBuildAlsoBuildsTheFactoryLayer`: `ygg sandbox build --realm <toy-sandbox>` with the stub engine
    builds `FactoryImages()` once, before the realm's stack.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** The suite passes. Commit.

**Named test:** the three tests above. **Size:** S. **Depends on:** T009.

### Task voluspa-T011: `ygg doctor` checks the graphs; a subfolder's committed files

**Files (in `odin`):**

- Modify: `internal/cli/doctor.go` (:57, after `checkRealms` :120-155), `internal/realm/realm.go`
  (`hashLimited` :84-88), `internal/realm/committed.go` (`hashCommitted` :28-116), `internal/realm/realm_test.go`,
  `internal/cli/doctor_test.go`

**Interfaces:**

- Produces: `func checkGraphs(f *schema.Factory, report func(level, what, msg string))`.
- Produces: `realm.Hash` of a folder inside a git work tree hashes the files committed under it, named relative
  to it, and refuses a tracked file under it that differs from `HEAD`.

- [ ] **Step 1: Write the failing tests.**
  - `TestDoctorListsTheGraphsOfTheStore`: `OK graphs <dir> (software 0.1.0)`; a pack in the store with no graph
    gives `ERROR graphs`; no section gives `WARN graphs no graphs section: --graph takes a path, and a project can't pin a graph`.
  - `TestASubfolderOfAGitRepoIsHashedFromItsCommittedFiles`, in a repo made in `t.TempDir()`: (a) a clean
    `software/` hashes as a plain copy of it does; (b) an untracked file in it leaves the hash unchanged; (c) a
    changed tracked file in it is refused (`differs from the committed realm`); (d) a folder of the repo with no
    committed file (untracked, and git-ignored) is refused (`none of its files is committed`); (e) a changed file
    elsewhere in the repo leaves it loading with the same hash.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3:** Implement: `git rev-parse --show-prefix` finds the folder's place; `status` and `ls-tree` take
  `-- <prefix>`. From here on, commit a change to a pack under `odin/testdata` before a test loads that folder
  in place, or the test fails on (c).
- [ ] **Step 4:** The suite passes, in a clean checkout. Commit.

**Named test:** the two tests above. **Size:** M. **Depends on:** T010.

### Task voluspa-T012: the real realms with Voluspa; example configs; docs

**Files (in `odin`):**

- Modify: `internal/cli/realms_content_test.go` (:157-196), `internal/cli/smoke_content_test.go`,
  `testdata/smoke-content/factory.example.yaml`, `testdata/smoke-realms/factory.example.yaml`,
  `testdata/smoke-grade/factory.real.example.yaml` (comments), `docs/architecture.md`, `README.md`,
  `internal/cli/docs_test.go`

- [ ] **Step 1: Write the failing tests.**
  - `TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents`: copy `../../../voluspa` (skip as `realRealm`
    does when it is not beside `odin`) into a graph store, set `graphs.dir`, run `--graph software`; the spec
    prompt check reads `voluspa/software/prompts/spec.md`. Everything else it asserts stays.
  - `smoke_content_test.go`: the example config holds `graphs:` with `dir: /home/OPERATOR/yggdrasil/voluspa`.
  - `TestTheDocsNameEveryCommand`: `docs/architecture.md` names `--graph`, `graphs.dir` and the graph pin.
- [ ] **Step 2:** Run them in the umbrella (with `voluspa` beside `odin`, T005). Expected: FAIL; the real-realms
  test runs, not SKIP.
- [ ] **Step 3:** Change the configs and docs: the graph pack, `--graph`, the pin, acceptance per leaf realm,
  scratch sessions on the factory layer. Reword every comment and test name that still says "lead realm" (36 at
  `7b5248a`, such as `internal/realm/realm.go:2`, `internal/run/prepare.go:26`).
- [ ] **Step 4:** The suite passes. Then, in the umbrella:

```bash
grep -rnE 'Setup\.Lead|Umbrella\.Realm|Realm\(""\)' --include='*.go' odin
grep -rni 'lead realm' --include='*.go' odin gungnir gleipnir
grep -rni 'lead realm' odin/docs odin/README.md gungnir/docs gleipnir/docs
```

  Expected: no output from any of the three. Commit, push, and open the odin PR (T006 to T012).

**Named test:** `TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents` (ran, not skipped); the greps.
**Size:** S. **Depends on:** T011, T005.

### Task voluspa-T013: the smoke scripts take `--graph`

**Files (in `ouroboric`):**

- Modify: `scripts/ygg-smoke-realms.sh` (:3, :17-18, :25, :32, :35, :48, :76), `scripts/ygg-smoke-loop.sh` (:3,
  :26, :28, :73), `scripts/ygg-smoke-grade.sh` (:181), `scripts/ygg-smoke-real.sh` (:116), `scripts/tests/ygg-evidence.test.sh`
  (:96, :153-163), `scripts/tests/ygg-smoke-grade.test.sh`

**Interfaces:**

- Produces: `ygg-smoke-realms.sh [--graph NAME|DIR] ...`, default `$odin/testdata/smoke-realms/smoke-lead`;
  `ygg-smoke-loop.sh [--graph DIR] ...`. Each `ygg run` takes `--graph`; each `ygg sandbox build` keeps `--realm`.

- [ ] **Step 1: Write the failing tests.** In `ygg-evidence.test.sh`: `--graph software --brief <brief>` reaches the
  run's arguments; with no options the run gets `--graph <odin>/testdata/smoke-realms/smoke-lead`; `--graph
  software` with a config that has no `graphs:` section exits 2 and says `no graphs section`; no run argument
  holds `--realm`. In `ygg-smoke-grade.test.sh`: the fake's `run` arguments hold `--graph` and no `--realm`, its
  `sandbox build` arguments hold `--realm`, and `ygg-smoke-real.sh --dry-run` prints a run with `--graph`.
- [ ] **Step 2:** `bash scripts/tests/ygg-evidence.test.sh; bash scripts/tests/ygg-smoke-grade.test.sh`.
  Expected: the new lines FAIL.
- [ ] **Step 3:** Change the scripts and their header comments (v0-H15 is `--graph software --brief BRIEF --tag h15`).
- [ ] **Step 4:** Both test files print only `ok` lines; shellcheck prints nothing. Commit, push, open the PR. It
  merges with or after the odin PR.

**Named test:** the two test files. **Size:** S. **Depends on:** T012.

### Task voluspa-T014: the graph and stage prompts leave `midgard-react`

**Files (in `midgard-react`):**

- Delete: `graph.yaml`, `prompts/{design,spec,conformance,plan,reuse-review,reviewer-spec,reviewer-simplicity,reviewer-quality}.md`
- Modify: `pack.yaml` (header, `graph:`), `pack_test.go`, `prompts_test.go`, `build_prompts_test.go`,
  `docs/architecture.md`, `README.md`, `AGENTS.md`

- [ ] **Step 1: Write the failing test** `TestTheRealmHoldsNoGraphAndNoStagePrompt`: no `graph.yaml`; the pack's
  `Graph` is empty; `prompts/` holds `implementer.md` only. Rename `TestThePackLoadsAsTheLeadRealmWithTwoStacksFromOneContext`
  to `TestThePackLoadsAsAFlavorWithTwoStacksFromOneContext`: it asserts `p.Graph == ""` and takes the moved check
  that the pack defines `accept` and an acceptance stack. Run `go test ./...`. Expected: FAIL.
- [ ] **Step 2:** Delete the nine files, one `git rm` per command. Drop `graph:` and say in the header what the
  flavor holds (delta §9.4). Delete the moved tests and their helpers; `buildPrompts` is `implementer.md`;
  `TestTheTemplatesContractIsNamedSoRoutingFindsIt` stays. `version` stays `0.1.0`.
- [ ] **Step 3:** The suite passes in the realm-CI setup (the Node image, Go 1.26.9, `-race -v`). `reuse lint`
  passes. Docs: the architecture page loses the graph, prompts and "Routing" sections and points to Voluspa.
  Docs check and pre-commit.
- [ ] **Step 4:** Run T003's proof loop again with this branch's base (`git merge-base HEAD origin/main`) in place
  of `4d145f3`. Expected: eight equal rows, so the prompts did not change on `main` since T003. Put the table in
  the PR body. Commit, push, open the PR.

**Named test:** `TestTheRealmHoldsNoGraphAndNoStagePrompt`. **Size:** S. **Depends on:** the odin PR merged.

### Task voluspa-T015: `helheim-go`'s pack comment, docs and test

**Files (in `helheim-go`):** Modify: `pack.yaml` (:1-5), `pack_test.go`, `docs/architecture.md` (:22, :47, :54-55)

- [ ] **Step 1:** Add `TestTheRealmHoldsNoGraph`: no `graph.yaml`, `Graph` empty. It passes at once (RR-12's rule,
  now pinned); say so in the PR.
- [ ] **Step 2:** The comment says: "It has no graph: a run takes its graph from the graph pack it names
  (Voluspa's `software` for the client gallery). ... the reviewers (rung 6) are the graph's". The architecture
  page says the same; its routing paragraph names Voluspa's `software` graph.
- [ ] **Step 3:** The suite and the docs check pass. Commit, push, open the PR.

**Named test:** `TestTheRealmHoldsNoGraph`. **Size:** S. **Depends on:** the odin PR merged.

### Task voluspa-H03 (founder): the content smoke run with `--graph software`

The success criterion. It costs nothing.

- [ ] **Step 1 (founder):** switch every repo to `main` and pull (`git submodule update --init voluspa` in the
  umbrella). In `~/ygg-it/content/factory.yaml`, add from the new example
  `graphs: {dir: /home/brunogbv/brunogbv/ouroboric/yggdrasil/voluspa}`.
- [ ] **Step 2 (founder):** run it with `--build` (the scratch sessions need the factory layer's new image):

```zsh
cd ~/brunogbv/ouroboric/ouroboric/scripts
./ygg-smoke-realms.sh --build --folder ~/ygg-it/content --env ~/ygg-it/content/empty.env --graph software \
  --brief ~/brunogbv/ouroboric/yggdrasil/odin/testdata/smoke-content/brief.md --tag h15 --clip
```

  Expect exit 0, two tasks done, `pointer_moved` twice and `Run … is done.`, as v0-H15.

- [ ] **Step 3 (founder):** compare acceptance with H02's run. For each run folder `R`
  (`<project>/.factory/runs/<id>`):

```zsh
jq -r 'select(.event=="check_result" and (."ygg.result"|startswith("accept"))) | ."ygg.node.id"+" "+."ygg.result"+" "+(."ygg.realm.name"//"-")' $R/ledger.jsonl
for f in $(grep -l 'snapshot/' $R/sandbox/*/compose.yaml); do grep -E '^ +image:' $f | sort -u; done
```

  Expected: the same moves, each with `accept: exit 0` (the new run adds `midgard-react`); the same image lines
  (the `midgard-react` acceptance work image, the firewall image, Postgres and SeaweedFS) in both runs.

- [ ] **Step 4 (founder):** paste the report and both outputs into T017's PR.

**Size:** S. **Depends on:** T013, T014 merged; H02.

### Task voluspa-T016: `check-repos.sh`, the naming doc, the journal

**Files (in `ouroboric`):**

- Modify: `scripts/check-repos.sh` (`LEAVES` :12), `scripts/tests/check-repos.test.sh`,
  `docs/7-branding/story/naming-and-mythology.md` (:143, :145), `docs/6-journal/README.md`
- Create: `docs/6-journal/2026-10-<dd>-one-graph-for-every-run.md`

- [ ] **Step 1:** A test case: with a `CHECK_REPOS_ROOT` that holds `yggdrasil/voluspa/AGENTS.md` linking the
  invariants, `--check agents voluspa` prints `PASS voluspa agents`. Run the test file. Expected: that line FAILs.
- [ ] **Step 2:** `LEAVES` gains `voluspa` (not `REALMS`). The test file passes; shellcheck prints nothing.
- [ ] **Step 3:** The naming doc: the Voluspa row is built and screened (2026-10-19), and the realms row no longer
  says the graph moves. Check `docs/README.md`'s map: its alt text already names Voluspa as the graph library;
  change it only if it does not. The journal entry (challenge: a lead realm with seven jobs; solution: one graph
  pack; results: H03's run and the SHA-256 table) and its row in the journal's README.
- [ ] **Step 4:** Docs check and pre-commit. `scripts/check-repos.sh --check agents --check reuse voluspa`.
  Expected: two `PASS` lines. Commit, push, open the PR.

**Named test:** `check-repos.test.sh`. **Size:** S. **Depends on:** H03.

### Task voluspa-T017: pointers, docs, diagrams, backlog

**Files (in `yggdrasil`):**

- Modify: the pointers of `gungnir`, `gleipnir`, `odin`, `midgard-react`, `helheim-go`, `voluspa`; `README.md` (:31),
  `AGENTS.md` (Map), `docs/README.md`, `docs/3-using/operations/README.md`, `docs/2-engineering/realm-readiness.md`
  (RR-12 :46), `docs/2-engineering/backlog.md`, `docs/assets/diagrams/architecture.d2`, `instance-tree.d2`,
  `docs/2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md` (:193-196, paths only, Question 3)
- Rename: `docs/assets/diagrams/web-realm-graph.mmd` → `software-graph.mmd`, and its two rendered SVGs

- [ ] **Step 1:** `git switch -c voluspa-2`; `git submodule update --remote gungnir gleipnir odin midgard-react helheim-go voluspa`;
  check each with `git ls-tree HEAD <leaf>`.
- [ ] **Step 2:** Docs. `README.md`: `voluspa` joins the repos with MIT content. `AGENTS.md`: a Map line for
  graphs (`voluspa/`) and realms. `docs/3-using/operations/README.md`: a section "Name a graph" (`--graph`, the
  `graphs` store, the graph pin, every leaf pins its realm, `--realm` only on `sandbox build`). RR-12 ends
  "..., and holds no graph?". The backlog gains, at the end of Open, with the next two free numbers on `main` when
  T017 starts (check with `grep -o 'B-[0-9]*' backlog.md | sort -u | tail -1`; v0-T265 and protected-configs
  take numbers first),
  "a schema version in every pack" and "the routing threshold in the project", from the proposal's Backlog.
- [ ] **Step 3:** Diagrams: `architecture.d2` shows two inputs to Odin, "graph (Voluspa): graph.yaml, stage
  prompts" and "realms: stack, implementer prompt, templates, checks" (delta §2); `instance-tree.d2` shows the
  graph pin; `git mv` the Mermaid source. `../ouroboric/scripts/diagrams.sh up`, `render yggdrasil`,
  `check yggdrasil`, `down`. Expected: `check` passes.
- [ ] **Step 4:** Docs check and pre-commit on every changed file; `go test ./...` in each pointed repo with
  `go.work`. Expected: no new problem; `ok`.
- [ ] **Step 5:** Commit, push, open the PR. The body has H03's evidence, the SHA-256 table of T003, the greps of
  T012, and the success criteria of the proposal, each with its evidence.

**Named test:** `diagrams.sh check yggdrasil`; the success criteria. **Size:** M. **Depends on:** all above.

## Questions for the founder

Each task assumes the answer in **bold**. Say so on this plan's pull request if you want another.

1. **When is a project with no acceptance check refused, if its leaves are not known at the start?** A fresh
   project gets its leaves from the spec stage, after the start, so "refused before the run starts" can't see
   them. **At Prepare when the project has leaves; otherwise at init, before it creates any leaf** (T009).
2. **Voluspa's licence.** The proposal says "MIT content, like a realm", but `midgard-react`'s graph and prompts
   are AGPL-3.0-only today (its `REUSE.toml` makes only `templates/**` MIT). **`software/**` is MIT, as the proposal
   says; the code (tests) AGPL, docs CC BY. As the sole copyright holder you relicense the moved files; T003's
   PR says so.**
3. **The v0 spec embeds `web-realm-graph.mmd`** (spec lines 193-196), so the rename breaks `diagrams.sh check`.
   **T017 changes only those three paths in the spec, no words; the delta records the rename.**
4. **A test pack inside a repo is hashed from its committed files too** (T011), so a run of an uncommitted edit
   of `odin/testdata/smoke-loop` is refused, as a realm repo's is since B-050. **Accept it.**
