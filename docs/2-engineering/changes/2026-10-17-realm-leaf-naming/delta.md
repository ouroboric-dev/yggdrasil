---
title: Delta for realm leaf naming
status: accepted
date: 2026-10-17
related: [proposal.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §1, §2, §2.1, §4.1, §4.2, §6.1, §9, §15.3

## Added

- §2: realm leaves follow one convention. Each of the nine realms owns a domain, and a leaf is named
  `<realm>-<flavor>` in lowercase ASCII, or `<realm>` for a realm with one way of working. The map of
  realms to domains lives in
  [`naming-and-mythology.md`](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/7-branding/story/naming-and-mythology.md).
- §2: a product that crosses domains is a combination of leaves from several realms. A run has one
  **lead realm**, which holds the graph. Each project leaf names its own realm leaf and version, in
  the project. The project decides its leaves and their realms; a build realm does not. A project
  MAY have several leaves from different flavors of one realm (`midgard-react` and `midgard-vue`).
- §2: every build realm's pack MUST provide the same roles under standard names: an `implementer`
  prompt, a leaf template and the leaf's checks. A graph refers to these roles, and Odin resolves each
  one in the realm of the task's leaf.
- §4.1: Odin MUST load the lead realm named by `--realm`, and for each leaf the realm that leaf names,
  each at its pinned version. A realm leaf loads once per run. A leaf whose realm can't be loaded at
  its pinned version, or two pins of one realm leaf at different versions, MUST stop the run before
  any sandbox comes up.
- §4.2: the spec stage MUST name the product's leaves and the realm that provides each one. The
  operator approves them at the `spec` gate. `init` creates each missing leaf from its realm's
  template and records the leaf's realm and version in the project.
- §4.1: `run.json` MUST record each leaf's realm and version, next to the lead realm and its graph
  version.

## Modified

- §1: the scope line's "the web realm" becomes "the client gallery's realms (`midgard-react`,
  `helheim-go`)".
- §2's repo table: the `realm-web` row becomes two rows. `midgard-react`: the Midgard realm's React
  flavor (web frontends): graph, prompts, devcontainer stack layer, templates, checks. `helheim-go`:
  the Helheim realm's Go flavor (backend): prompts, devcontainer stack layer and services, templates,
  checks. §2's diagram shows both.
- §2.1: the `realm-web` row becomes `midgard-react` ("the client gallery's lead realm and the web
  leaf's recipe, §9") and `helheim-go` ("the api leaf's recipe, §9"), both depending on Gungnir
  schemas.
- §4.1: `ygg run --project <path> --realm web --brief <brief.md>` becomes
  `ygg run --project <path> --realm midgard-react --brief <brief.md>`. Step 1's "create it from the
  realm templates" becomes "create it from its realm's templates".
- §4.2: "The web realm graph" becomes "The client gallery's graph", held by `midgard-react` as the
  lead realm. "This graph is the web realm's implementation of them" becomes "This graph is
  `midgard-react`'s implementation of them". The `implement ⇄ check ladder` node uses the
  implementer prompt and checks of the task's leaf's realm.
- §6.1: "Two layers per image: the realm's stack layer and the factory layer" becomes "the stack
  layer of the leaf's realm and the factory layer". "Plus the realm's services (§9.3)" becomes "plus
  the services of the leaf's realm and of each leaf it consumes".
- §9: "The web realm" becomes "The client gallery's realms". §9.2's table gains a column naming each
  leaf's realm: `api` is `helheim-go`, `web` is `midgard-react`. §9.4's single pack becomes two:

  ```text
  midgard-react/
    pack.yaml        name, version, default roles/models, check commands
    graph.yaml       the graph in §4.2
    prompts/         planner, initializer, implementer (web), reviewer-spec, reviewer-quality
    devcontainer/    stack layer (Dockerfile, devcontainer.json)
    templates/       the web leaf starter: lint/test/e2e config, AGENTS.md, init.sh
    checks/          the web leaf's check ladder scripts
  helheim-go/
    pack.yaml        name, version, default roles/models, check commands
    prompts/         implementer (api)
    devcontainer/    stack layer (Dockerfile, devcontainer.json, compose services)
    templates/       the api leaf starter: lint/test config, AGENTS.md, init.sh
    checks/          the api leaf's check ladder scripts
  ```

- §15.3: "Next.js full-stack comparison realm" becomes "Next.js full-stack comparison flavor of
  Midgard (`midgard-next`)".

## Removed

- §2, §2.1, §9.4: the `realm-web` repo.
