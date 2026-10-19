# Operations

This folder contains the runbooks to operate Yggdrasil: install, upgrade, `ygg doctor` and recovery.
This folder is empty until you can use v0.

The checklist for a finished realm is in [realm-readiness.md](../../2-engineering/realm-readiness.md).

## Name a graph

A run names the graph it follows. A graph is a folder in [Voluspa](https://github.com/ouroboric-dev/voluspa), such
as `software`, with a `graph.yaml` and the stage prompts. It holds no stack and no leaf recipe; the realms hold
those.

- `ygg run --graph <name|dir>`: a bare name is found in the `graphs` store, the folder that `graphs.dir` of
  `factory.yaml` names. A path is used as it is.
- The graph pin: the first run of a project writes `graph:` and `graph_version:` at the top of its
  `umbrella.yaml`, only when `--graph` is a name. A path pins nothing. A later run of another graph, or of another version, is refused. A project that still pins a
  realm at the top is refused, with the way to pin a graph.
- Every leaf pins its own realm in `umbrella.yaml`, and the realm of a leaf comes from that pin alone. There is no
  lead realm and no `ygg run --realm`.
- `--realm` is for `ygg sandbox build` only, which builds the stack of each realm it names (or `--all`).

### Run the content smoke run

`ygg-smoke-realms.sh --graph software --brief <brief> --tag h15` (in `ouroboric/scripts`) runs the content smoke
run on the real realms.

- The first time, and whenever the images are gone, add `--build`: it builds the sandbox image of every realm.
- An unattended content run stops at `version-t1-contract-gate` (B-072), with exit code 3. It needs `ygg approve`.
- Approve and resume need the engine environment (`CONTAINER_HOST`, the devcontainer CLI on `PATH`, the empty
  registry auth). Run them under `ygg-engine.sh`:

```zsh
cd ~/brunogbv/ouroboric/yggdrasil/odin
~/brunogbv/ouroboric/ouroboric/scripts/ygg-engine.sh run --folder ~/ygg-it/content -- \
  go run ./cmd/ygg approve <run-id> <gate> --project <project> --note "..."
~/brunogbv/ouroboric/ouroboric/scripts/ygg-engine.sh run --folder ~/ygg-it/content -- \
  go run ./cmd/ygg resume <run-id> --project <project>
```

- `--folder` is the folder that holds `factory.yaml`.
- `<project>` is the project folder, the one the smoke script prints as `smoke-realms: made <project>`. The run
  lives there. Odin's `--project` defaults to `.`, so without it the commands do not find the run.
- With `ygg` on `PATH`, `ygg approve …` replaces `go run ./cmd/ygg approve …`.

The `ygg resume` and `ygg approve` lines that `ygg` prints on a stop do not carry this environment (B-096).
