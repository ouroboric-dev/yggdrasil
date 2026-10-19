---
title: Delta for Voluspa
status: draft
date: 2026-10-19
related: [proposal.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md, ../2026-10-17-realm-leaf-naming/delta.md, ../2026-10-17-realm-engine/delta.md, ../2026-10-17-realm-content/delta.md]
style: spec
---

# Delta: v0 spec §1, §2, §2.1, §3.1, §4.1, §4.2, §6.1, §8.3, §9, §9.4

The founder decided every choice of the [proposal](proposal.md) on 2026-10-19. This delta follows those decisions.

## Added

- §1, §2: **Voluspa** (`voluspa`) is the graph library, an MIT leaf of the umbrella. It holds one folder per
  graph. The first is `software/`, the graph every software run uses. Graphs have descriptive names. Myth names
  stay with realms and components.
- §2: a **graph pack** is a pack that holds a graph and its prompts. It has no stack, no leaf recipe and no
  checks. Odin loads it as it loads a realm: from a store, with its name, version and a hash of its committed
  files recorded in `run.json`. A resume MUST refuse a graph pack whose hash or version changed.
- §2: a graph MUST state the Gungnir graph schema version it needs, as an integer `schema` in `graph.yaml`.
  Odin MUST refuse a graph whose schema version it doesn't support, before any sandbox starts.
- §3.1: a project MUST pin its graph in `umbrella.yaml` as `graph` and `graph_version`, and each leaf's
  realm as `realm` and `realm_version`. A run whose `--graph` names another graph or version than the pin MUST
  stop before anything starts. The first run of a project pins its graph.
- §3.1: a leaf with no realm pin MUST stop the run before anything starts. The one exception is a pack that
  holds both a graph and a leaf recipe (test data): a leaf that pins no realm takes that pack's recipe.
- §4.1: graph packs MUST be found by name in the store named by `factory.yaml` `graphs.dir`, or by a
  path. Odin MUST NOT fetch them.
- §4.2: the prompts of agent nodes and of a loop's reviewers MUST come from the graph pack. The implementer's
  prompt, the template and the checks of a task's loop MUST come from the realm of the task's leaf.
- §6.1: a scratch sandbox MUST start on the factory layer alone, with the model APIs as its only egress.
- §6.1: a pointer move's acceptance checks MUST be the named check of **every leaf realm of the project that
  defines it**. Each MUST run on its own realm's acceptance stack, over the same snapshot, with the services of
  every leaf's realm, in realm-name order, and the first failure MUST fail the move. A graph whose pointer node
  asks for acceptance, in a project where no leaf realm defines the check, MUST be refused before the run starts.
- §8.3: the threshold an index needs before it ships MUST come from the `routing` block of the graph pack.
- §9.4: a realm leaf in the umbrella MUST NOT hold a graph or a stage prompt.

## Modified

- §1's repo table: a `voluspa` row, "the graph library: one folder per graph (`software/`), with its stage
  prompts". The `midgard-react` row (leaf-naming delta) loses "graph" and "prompts that are not tied to one
  leaf": "the Midgard realm's React flavor: implementer prompt, stack, template, checks, acceptance check".
- §2's diagram: "realm (web, game…) graph.yaml, prompts, checks, templates" becomes two inputs to Odin: "graph
  (Voluspa): graph.yaml, stage prompts" and "realms: stack, implementer prompt, templates, checks".
- §2.1: a **Voluspa** row ("the graphs Odin runs; depends on Gungnir schemas"). `midgard-react` becomes "the web
  leaf's recipe, §9". Odin "loads realm graphs" becomes "loads the graph a run names, and each leaf's realm".
- §2 (leaf-naming delta): "A run has one **lead realm**, which holds the graph" becomes "A run names its graph,
  and the project pins it". "A graph refers to these roles, and Odin resolves each one in the realm of the
  task's leaf" stays.
- §3.1 (realm-engine delta): "a project MUST pin its lead realm and each leaf's realm" becomes "its graph and
  each leaf's realm". "A lead pin that names another realm than the run's" becomes "a graph pin that names
  another graph or version than the run's".
- §4.1 (leaf-naming delta): `ygg run --project <path> --realm midgard-react --brief <brief.md>` becomes
  `ygg run --project <path> --graph software --brief <brief.md>`. "Odin MUST load the lead realm named by
  `--realm`, and for each leaf the realm that leaf names" becomes "Odin MUST load the graph pack named by
  `--graph`, and for each leaf the realm that leaf names". `run.json` records the graph's name, version and hash
  instead of "the realm and graph version".
- §4.2's title "The web realm graph" (leaf-naming delta: "The client gallery's graph") becomes "The software
  graph", held by Voluspa. "This graph is `midgard-react`'s implementation of them" becomes "This graph is
  Voluspa's `software` implementation of them". The diagram `web-realm-graph.mmd` becomes `software-graph.mmd`.
- §6.1 (realm-content delta): "on the lead realm's acceptance stack" becomes "on the acceptance stack of each
  leaf realm that has an acceptance check, as above". "A realm with acceptance checks and no acceptance stack
  MUST be refused before the run starts" stays.
- §9: "The client gallery's realms" (leaf-naming delta) build the client gallery with Voluspa's `software`
  graph. §9.4's two packs become three:

  ```text
  voluspa/
    software/
      pack.yaml      name, version, graph
      graph.yaml     the graph in §4.2, with its schema version
      prompts/       design, spec, conformance, plan, reuse-review, reviewer-spec, reviewer-simplicity,
                     reviewer-quality
  midgard-react/
    pack.yaml        name, version, check commands, leaf recipe, stack and acceptance stack
    prompts/         implementer (web)
    devcontainer/    stack build context and the ladder's scripts (devcontainer/checks/)
    templates/       the web leaf starter
  helheim-go/
    pack.yaml        name, version, check commands, leaf recipe, stack, services
    prompts/         implementer (api)
    devcontainer/    stack build context and the ladder's scripts (devcontainer/checks/)
    templates/       the api leaf starter
  ```

## Removed

- §2, §4.1 (leaf-naming delta): the **lead realm**, and `ygg run --realm`. `ygg sandbox build --realm`
  keeps its flag: it names a realm whose stack to build.
- §3.1 (realm-engine delta): "A leaf with no pin MUST be the lead realm's."
- §9.4 (leaf-naming delta): `graph.yaml` and the planner, initializer and reviewer prompts in `midgard-react`.
