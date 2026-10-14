# Harbor bench

Runs Yggdrasil on [Harbor](https://github.com/harbor-framework/harbor) tasks, such as
[`mimir/client-gallery-lite`](https://github.com/ouroboric-dev/mimir/tree/main/client-gallery-lite),
with this machine's Podman. Commands that use Podman need its socket, so run them outside Claude
Code's sandbox.

| File | What it does |
|---|---|
| `harbor-podman.sh` | `setup` installs pinned Docker Compose v5.5.1 (checked by SHA-256), a `docker` shim to Podman and an empty registry config in `~/.cache/yggdrasil-harbor`; `prepare` checks the brief's hash, builds the task image and makes a copy of the task that uses it; `exec` runs Harbor in that setup |
| `selfcheck.sh` | runs a build the way grading does: a fresh container, only `/app`, `start.sh` as `app` with a clean environment, port 3000 within 2 minutes, no writes outside `/app` and the temporary folders |
| `ygg_harbor/agent.py` | the agent `ygg_harbor.agent:YggdrasilAgent`: runs the factory command on the host and carries out its requests in the task environment (the bridge is described at the top of the file) |

## A run

```bash
bench/harbor/harbor-podman.sh setup
copy="$(mktemp -d)/client-gallery-lite"
bench/harbor/harbor-podman.sh prepare ../mimir/client-gallery-lite "$copy" \
  bd4b2c7aaf532d51acb3a7edfd5b193d368db8445093b7a24cd80b7ee24d8319
# Graded runs only: add the task's tests/ to "$copy" (outside every agent session).
jobs="$(mktemp -d /mnt/wsl/ygg-harbor-jobs.XXXXXX)"
bench/harbor/harbor-podman.sh exec uv run --project bench/harbor harbor run -p "$copy" -o "$jobs" -y \
  -a ygg_harbor.agent:YggdrasilAgent --ak "command=<factory command>" --ak budget_usd=100
```

The jobs folder must be under `/mnt/wsl`, where the Podman machine can see it. Containers write it
as root, so empty it with a container before deleting it (see `tests/smoke.sh`).

## Tests

From the `yggdrasil` checkout:

- `bash bench/harbor/tests/harbor-podman.test.sh` (add `YGG_TEST_ONLINE=1` to download the real
  Compose)
- `uv run --project bench/harbor pytest bench/harbor/tests`
- `bench/harbor/harbor-podman.sh exec bash bench/harbor/tests/selfcheck.test.sh localhost/client-gallery-lite:4.0.0`
  (Podman)
- `bench/harbor/tests/smoke.sh ../mimir/client-gallery-lite <brief sha256>` (Podman): prints
  `nop 0` and `yggdrasil 1`
