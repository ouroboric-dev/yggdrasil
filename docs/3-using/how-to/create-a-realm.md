---
title: Create a realm
status: draft
date: 2026-10-20
style: procedure
related: [../../2-engineering/realm-readiness.md, ../../1-product/design/2026-10-18-ginnungagap-design.md, ../operations/README.md]
---

# Create a realm

A realm flavor is a leaf repo named `<realm>-<flavor>`, such as `midgard-react` or `helheim-go`. It holds
the recipe for one kind of leaf: the stack, the implementer prompt, the template, the check ladder and,
when it needs them, services and an acceptance check. It holds no graph. A run takes its graph from
[Voluspa](https://github.com/ouroboric-dev/voluspa), and each leaf takes its realm from its own pin.

Today you make a realm by hand, with this procedure. After v0, Ginnungagap, the realm that makes realms,
runs these steps as a `ygg run` with gates ([design](../../1-product/design/2026-10-18-ginnungagap-design.md)
§8.3 and §8.4). The [realm readiness checklist](../../2-engineering/realm-readiness.md) is what "done"
means. Each step below names the items it meets (RR-nn).

Copy from the two realms that exist. `helheim-go` is a Go API with services. `midgard-react` is a React
web app with an acceptance check. Steps marked **founder** need the admin token or a push of a workflow
file. An agent does every other step on a branch, through a pull request.

## 1. Choose and screen the name (RR-11)

- The realm is one of the nine in
  [naming and mythology](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/7-branding/story/naming-and-mythology.md).
  The flavor names the stack, such as `vue` or `rust`.
- Screen the name on npm, PyPI, crates.io, Docker Hub, Homebrew and GitHub, as
  [the Voluspa screening](../../5-research/2026-10-19-voluspa-name-screening.md) did. File the result in
  `docs/5-research/`.

## 2. Create the repo (founder)

In `~/brunogbv/ouroboric/ouroboric`, with the short-lived admin token (see the header of `scripts/new-repo.sh`):

```zsh
GH_TOKEN=... scripts/new-repo.sh --org ouroboric-dev --ci reuse,markdown,shell,actions,yaml \
  <realm>-<flavor> "<one sentence: the leaf this realm builds>"
```

The repo is made, pushed and protected, with base CI (`lint`). Then add it to the `ouroboric-pr-bot`
installation (the link the script prints, under Repository access) and check:

```zsh
scripts/as-bot.sh --read all scripts/check-repos.sh --check bot --check ruleset <realm>-<flavor>
```

Expected: `PASS <repo> bot` and `PASS <repo> ruleset`.

## 3. Clone and scaffold

In the umbrella:

```zsh
../ouroboric/scripts/as-bot.sh --read all git clone https://github.com/ouroboric-dev/<repo>.git <repo>
git -C <repo> switch -c scaffold
../ouroboric/scripts/scaffold-component.sh --mit-templates <repo> "<the job sentence>" <repo>
```

`--mit-templates` adds the MIT-licensed `templates/` folder: whatever the factory copies into a product
stays the product's (RR-02). Write the Responsibilities and Depends on sections of `docs/architecture.md`.

## 4. Write the recipe

### `pack.yaml`

Gungnir's pack schema checks this file. Start from `helheim-go/pack.yaml`. A build realm has:

- `name` and `version`: the repo name, and `0.1.0` to start.
- `checks`: each rung's name, mapped to a script under `/opt/ygg/checks/`. Rungs 1 to 5 are `static`,
  `unit`, `tdd`, `contract` and `security`, with `deps` beside `security` (RR-16).
- `leaf`:
  - `description`;
  - `template`: the folder under `templates/`;
  - `first_commit`: the files committed first, such as `[LICENSE]`;
  - `implementer`: `prompts/implementer.md`;
  - `checks`: the rungs a task's loop runs, in order.
- `sandbox`: `build: devcontainer` (and a `target` when the Containerfile has several), and `egress`: the
  smallest list of hosts that works, each with a reason in the docs (RR-19).
- `services`, if the leaf needs them, such as Postgres. Pin each image by digest (RR-13).
- An acceptance check, if the product needs one across leaves: a check named `accept`, and
  `sandbox.acceptance` naming its stack. Every pointer move runs the `accept` check of every leaf realm
  that defines one. A project needs at least one realm with it.

No `graph:` line. A realm never holds a graph (RR-12). No `routing:` block either: the graph pack's is
the one a move measures.

### The stack: `devcontainer/`

- **`Containerfile`:** every base image pinned by digest and at least two weeks old (RR-13), and the
  packages pinned (RR-14). It copies the check scripts and their lint and build configs to
  `/opt/ygg/checks`, owned by root (RR-15). It needs `bash`, `timeout` and `git`.
- **`checks/`:**
  - the rung scripts;
  - `docs.sh` and `protected-common`, copied byte for byte from `helheim-go`. They are shared pieces
    (RR-09);
  - every rung refuses a task's change to the protected files: base CI, licensing, tool configs,
    `.github/` and `.devcontainer/` (RR-15). See `go-static.sh` or `web-protected.sh`.

### The prompt and the template

- **`prompts/implementer.md`:** how an implementer works in this stack. A person reviews it (RR-20).
- **`templates/<kind>/`:** the first commit of a leaf.
  - It passes its own ladder when built in a copy (RR-17).
  - It gives the product a `.github/workflows/ci.yml` with a job `test`, and the MIT licence with the
    "Built with Ouroboric" notice (RR-18).

## 5. Test the realm (RR-08, RR-12, RR-16, RR-17, RR-15)

Write each test first, and watch it fail. Copy the shapes from `helheim-go`:

- **`pack_test.go`:** the pack loads and validates, it names the standard roles, and every rung's script
  exists. `TestTheRealmHoldsNoGraph`: there is no `graph.yaml`, and `graph` is empty.
- **`template_test.go`:** the template passes the ladder. Run it with `YGG_REQUIRE_TEMPLATES=1` so that it
  fails, rather than skips, without the module proxy.
- **`containerfile_test.go`:** the digests and the root-owned `/opt/ygg/checks`.
- **The refusal tests:** each rung refuses a change to every protected file.

Run them in the leaf:

```zsh
GOWORK=off go test -race ./...
```

## 6. Add the realm's CI (founder)

The agent writes `.github/workflows/ci.yml`, copied from `helheim-go`'s, with one job `test`. The pr-bot
can't push workflow files, so you push that branch and open its pull request. After it merges:

```zsh
GH_TOKEN=... scripts/setup-repo.sh --org ouroboric-dev <repo>
scripts/as-bot.sh --read all scripts/check-repos.sh --check ruleset <repo>
```

Expected: `PASS <repo> ruleset`. Now both `lint` and `test` are required (RR-01, RR-03, RR-04).

## 7. Wire it into the tree (RR-10)

These change files outside the leaf, so each lands as its own pull request:

- **The umbrella:** `git submodule add https://github.com/ouroboric-dev/<repo>.git <repo>`, and add
  `./<repo>` to `go.work` if the realm has Go.
- **`ouroboric/scripts/check-repos.sh`:** add the repo to `LEAVES`. Add it to `REALMS` too, if it shares
  `docs.sh` and `protected-common` with the other build realms.
- **Check it:**

  ```zsh
  scripts/check-repos.sh --check agents --check reuse --check gitleaks --check shared <repo>
  ```

  Expected: four `PASS` lines (RR-02, RR-05, RR-06, RR-09).

## 8. Let the graph offer it

A run's spec stage names each leaf's realm, in the project's `docs/leaves.yaml`. Today the `software`
graph's spec prompt (`voluspa/software/prompts/spec.md`) lists the realms it may use, and their versions.
A new realm is used by a run only after that list names it:

1. In `voluspa`, add the realm and its version to that list.
2. Update `TestTheSpecPromptNamesTheGallerysRealmsAtTheirVersions` to expect it.
3. Bump the `software` version in both `pack.yaml` and `graph.yaml`.
4. Open the pull request, and move the umbrella's `voluspa` pointer once it merges.

A project pins its graph's version. A project made before the bump is refused with
`the project is built with the graph software 0.1.0`. To move such a project, change `graph_version` in its
`umbrella.yaml` and commit that change.

## 9. Build it and run it (RR-21)

Run every `ygg` command that touches a sandbox inside the engine environment:

```zsh
cd ~/brunogbv/ouroboric/yggdrasil/odin
~/brunogbv/ouroboric/ouroboric/scripts/ygg-engine.sh run --folder ~/ygg-it/content -- \
  go run ./cmd/ygg sandbox build --config ~/ygg-it/content/factory.yaml --realm <repo>
```

Then:

1. **Check the realm loads:** `ygg doctor --config ~/ygg-it/content/factory.yaml` lists it on its
   `realms:` line.
2. **Run a smoke run** with a brief that needs the new realm. Follow
   [Operations, Name a graph](../operations/README.md#name-a-graph), with `--build` the first time.
3. **Approve any stop:** a contract change stops even an unattended run (B-072). Approve it the way that
   section shows.

## 10. Assess it

1. Copy the checklist to `docs/2-engineering/readiness/YYYY-MM-DD-<repo>.md`.
2. Fill a row for each item that applies, with evidence, and open the pull request.

The realm is ready when every auto item is `met` and a person has judged the human items.
