---
title: Realm leaf naming
status: accepted
date: 2026-10-17
related: [../../specs/2026-10-11-yggdrasil-v0-spec.md, delta.md, tasks.md, ../../backlog.md]
style: spec
---

# Realm leaf naming

**Decided 2026-10-17 (founder):** each of the nine realms of the myth owns one domain, and a realm
leaf is named `<realm>-<flavor>`. The web realm's leaf `realm-web` splits into `midgard-react` and
`helheim-go`. The word "realm" and the `--realm` flag stay as they are. This closes backlog B-038.

## Why

- `realm-web` doesn't fit the brand's naming. Every other part of Yggdrasil has a name from the
  myth, and the Asgard leaf already does. B-038 asked for one convention for every realm leaf.
- The brand story already says the nine realms hang in Yggdrasil's branches. Giving each realm a
  domain makes the names mean something to an operator.
- The founder wants the split to make sense from the operator's side. An operator picks a realm by
  what they're building, and a flavor by what they build it in.
- `realm-web` builds two kinds of leaf (spec §9.2): a Go `api` and a React `web`. Under the
  convention those belong to two domains, backend and web frontends, so the realm splits.

## What changes

### The convention

- **A realm is a domain**: the answer to "what am I building?". There are nine, one for each realm
  of the myth.
- **A flavor is a subdivision**: the answer to "in what?" (`midgard-react`, `midgard-vue`). Leaves in
  one realm do the same kind of work, so an operator who knows one flavor knows its neighbours.
- **A leaf is named `<realm>-<flavor>`**, lowercase ASCII. A realm with one way of working MAY be
  named `<realm>` alone (`asgard`).
- **A product that crosses domains is a combination of leaves**, not a realm. A web SaaS is a
  Midgard leaf and a Helheim leaf. A game is a Jotunheim leaf with Alfheim's assets and a Helheim
  backend.
- **Legacy and migration are kinds of work**, not realms. A realm MAY offer a graph for them.

### The map

All nine are decided by the founder (2026-10-17).

| Realm | Domain | Myth, in one sentence | Flavors (examples) |
|---|---|---|---|
| **Asgard** | kickstart: charters, brands, legal basics, roadmaps | Where the gods decide direction | (one leaf: `asgard`) |
| **Midgard** | web frontends | The human world, the part people live in and see | `react`, `vue`, `next` |
| **Helheim** | backend: services, APIs, workers | Below the world, behind the bridge Gjallarbru, where the guard Modgud asks every traveller their name and errand: the part no user sees, where every request is checked and every record is kept | `go` |
| **Niflheim** | infrastructure: deploy, cloud, operations | It lies under one of Yggdrasil's roots, and its well Hvergelmir feeds every river: the ground everything runs on | to be named with the realm |
| **Nidavellir** | desktop apps and command-line tools | The dwarves' realm; dwarves forged the gods' own tools (Mjolnir, Draupnir, Gungnir) | `tauri`, `cli` |
| **Jotunheim** | games (engine-based clients) | At Utgard the giants test Thor with contests: a race, an eating contest, wrestling old age itself | `godot`, `unity` |
| **Alfheim** | art: assets for apps and games (music, 3D models, sprites, icons); art as the work itself later | The light elves' realm, "more beautiful than the sun" | `audio`, `3d`, `2d` |
| **Vanaheim** | research: documents from sources or from data | The Vanir, masters of seidr (seeing hidden things), whose truce with the gods produced Kvasir, who could answer any question | `synthesis`, `paper` |
| **Muspelheim** | mobile apps | The gods took sparks from Muspelheim and set them moving across the sky as the sun, moon and stars: lights that travel with you | `swift`, `kotlin`, `flutter` |

Muspelheim's fit is the weakest of the nine. The founder accepted it. The flavor lists are examples,
not commitments: a flavor is named when its leaf is created.

A web screening on 2026-10-17 found no collision that matters (naming rule 4). Midgard is also an
open-source content framework, mostly dormant since 2012. An npm package `@datank/nidavellir`
exists. The others turn up only small repos and game mods. Every new leaf name is free in the
`ouroboric-dev` org.

### The split of `realm-web`

`realm-web` holds only its Phase 0 scaffold today (README, `AGENTS.md`, an architecture page, a
bare Go devcontainer, an empty `templates/`), so the split moves no built work.

- **`midgard-react`** is `realm-web` renamed on GitHub, so it keeps its history and GitHub redirects
  the old URL. It holds what §9.4 lists for the web leaf: React stack layer, web leaf template, web
  checks, the web implementer prompt. It is the client gallery's **lead realm**, so it also holds the
  graph (§4.2) and the prompts that are not tied to one leaf (planner, initializer, reviewers). A
  product that uses `helheim-go` with another frontend would take its graph from that frontend's
  realm.
- **`helheim-go`** is a new repo, scaffolded like the other leaves. It holds the Go stack layer, the
  compose services the API needs (Postgres, SeaweedFS), the api leaf template, the api checks and the
  api implementer prompt. It holds no graph in v0. A backend-only product would add one later.

### Products that cross realms: the lead realm

**Decided 2026-10-17 (founder):** a run has one lead realm, and each leaf has its own realm.

- The operator picks the lead realm with `--realm` (`--realm midgard-react` for the client gallery).
  The lead realm's graph runs the product. A realm still holds a graph, as §2 says today.
- Each leaf of the project names its realm leaf and that realm's version. The leaf's sandbox gets that
  realm's stack layer (§6.1), and its loop gets that realm's templates, checks and implementer
  prompt. The client gallery's `api` leaf runs with `helheim-go`, and its `web` leaf with
  `midgard-react`.
- Loading a realm leaf at a pinned version is the mechanism B-035 needs for Asgard. Phase 5 builds
  it once, for both.

**Decided 2026-10-17 (founder): the project decides its leaves, not the lead realm.** Today the lead
realm's `pack.yaml` lists the leaves its graph works in, with their templates (`leaves:`). After this
change a build realm no longer fixes which leaves a product has, or which realm provides each one. Any
frontend flavor can pair with any backend flavor. **A project MAY use several flavors of one realm**
(founder, 2026-10-17): a storefront in `midgard-react` beside an admin in `midgard-vue`, or two
backends in two Helheim flavors. Each leaf names its own realm leaf.

- **Where the choice is made (my call):** the run's spec stage names the product's leaves and the realm
  that provides each one, and the operator approves it at the spec gate, as the spec's other choices
  are approved. The `init` node then creates each missing leaf from its realm's template.
- **Where it is recorded (my call):** in the project, beside each leaf: its realm leaf and version. The
  leaf entries in `umbrella.yaml` hold only kind, owner and visibility today, so Phase 5 adds the
  field to Gungnir's schema.
- **The pack's `leaves:` map (left to Phase 5's plan):** it may go, or stay as the default set the spec
  stage starts from, so an operator who doesn't care gets a working pair.

**Three more calls of mine, open to the founder's change:**

- **Flavors keep one contract.** Every build realm's pack provides the same roles under standard
  names: an `implementer` prompt, a leaf template and the leaf's checks. The lead graph refers to the
  roles, and Odin looks each one up in the realm of the task's leaf. A backend flavor that keeps the
  contract can stand in for `helheim-go` without a change to `midgard-react`'s graph.
- **One version per realm leaf per run.** A realm leaf (`midgard-react`) loads once per run, however
  many project leaves use it. When two pins of the same realm leaf disagree (the lead's and a
  leaf's, or two leaves'), the run stops before any sandbox comes up. The lead realm is pinned in the
  project like a leaf's realm. `midgard-react` and `midgard-vue` are different realm leaves, so they
  never conflict.
- **Services follow the leaves a sandbox uses.** A leaf's sandbox gets its own realm's services, plus
  those of each leaf it consumes. That is what §9.2 already does when `web` runs `api` as a read-only
  service: `web`'s sandbox gets `helheim-go`'s Postgres and SeaweedFS.

### Art and research are realms

Alfheim and Vanaheim make art and research realms of Yggdrasil. Until now the company charter listed
"a research factory" and "artistic factories" as illustrative future factories. Asgard set the
precedent on 2026-10-17, when it moved from a factory to a realm. The company charter and the brand
doc change to match (task T005). Naming a realm is not a commitment to build it: the charter's focus
rule still holds, and only Asgard and the web realms are on the roadmap.

## Impact

- **Spec:** §1's scope line, §2's repo table, §2.1, §4.1, §4.2, §6.1, §9 and §15.3 (see the delta).
  §2's diagram names `realm-web`. The v0 spec stays as accepted; the delta, with a redrawn diagram,
  goes into the living spec (`system/`) when v0 lands.
- **Repos:** the founder renames `realm-web` to `midgard-react` and creates `helheim-go`. The umbrella's
  `.gitmodules`, `go.work` and pointers change, as do `ouroboric/scripts/check-repos.sh` and the
  `scaffold-component.sh` test's example name.
- **Phase 5:** grows by one mechanism: a run loads its lead realm and each leaf's realm at pinned
  versions, and the spec stage names the leaves and their realms. It overlaps B-035. B-036 (a realm with no code leaves and no stack layer) is now needed by
  Asgard, Alfheim and Vanaheim, so it weighs more in Phase 5's design.
- **Ledger:** `run.json` records the lead realm and its graph version (as today) and, from Phase 5,
  each leaf's realm and version.
- **Brand and company docs** (in `ouroboric`): the naming doc's story, glossary and rules, the
  long-term map, and the company charter's list of factories.

## Not in this change

- The word "realm", the `--realm` flag and the `graph.yaml` keys keep their names.
- Odin's test realms (`odin/testdata/smoke`, `smoke-loop`) are test data, not leaves, and keep their
  names.
- Past plans, SDD ledgers and journal entries stay as written. They are records.
- The Asgard leaf stays `asgard`. It moves under the `yggdrasil` umbrella after Yggdrasil v0, as
  already decided.
