# Local models

This page is for the operator who runs a model on their own GPU and uses it from the factory. It gives the setup,
the daily commands, how runs and the interactive tools use the server, and what to do when something fails.

## What this is

One container, the model server, runs `llama-server` with one model loaded. Runs, OpenCode and Claude Code all use
this one server. A role on a local model bills nothing, but the run records a notional cost at the model's OpenRouter
price, so a local run compares with a paid one.

Every command on this page is for zsh. Run each one from your `ouroboric` clone, unless a step says otherwise. The
scripts are in `scripts/`; the comment block at the top of each script is its full reference.

The defaults that this page uses:

| What | Default | Flag that changes it |
| --- | --- | --- |
| The factory folder, which holds `factory.yaml` | `~/ygg-it` | `--folder DIR` |
| The model list | `~/.config/ygg/models.yaml` | `--models FILE` |
| The weights (the model files) | `~/ygg-it/models/weights` | `setup --weights DIR`, for a new list only |
| The state (the preset and the allow file) | `~/ygg-it/models/state` | `setup --state DIR`, for a new list only |
| The server on the host | `http://127.0.0.1:8088` | `server.host_port` in the list |

`--models` and `--folder` go before the command, such as `scripts/ygg-models.sh --folder DIR status`.

## Before you start

You need:

- Windows with WSL2, and an NVIDIA GPU with a Windows driver that gives CUDA to WSL. `nvidia-smi` must show the GPU.
  The example model uses about 19 GB of GPU memory.
- The factory's engine: a rootless Podman machine on WSL2. `ygg-engine.sh check` must pass (see
  [Proof runs, before the first run](proof-runs.md#before-the-first-run)).
- A `factory.yaml` in the factory folder with `sandbox.engine` and `sandbox.mounts`. The engine sees your files only
  through `sandbox.mounts`, so the weights and the state must be under a mounted folder. The default folders are under
  `~/ygg-it`, which the usual mount covers:

  ```yaml
  sandbox:
    engine: unix:///<the engine socket>
    mounts:
      - { host: /home/<user>/ygg-it, engine: /mnt/wsl/ygg-bind }
  ```

- `uv` (for `uvx`) or `hf` on `PATH`, to download the weights.
- `python3` and `curl` on `PATH`.
- About 20 GB of free disk under the mounted folder. The example model's two files are 18 GB.
- For interactive use: `opencode` and `claude` on `PATH`.

Then build `ygg`, so that the `ygg` on your `PATH` has `ygg models`:

1. Update the checkouts of your `yggdrasil` clone (`git -C MODULE pull` for each module).
2. Build `ygg`:

   ```zsh
   scripts/ygg-build.sh
   ```

3. Check the engine:

   ```zsh
   scripts/ygg-engine.sh check
   ```

4. If the check refuses with `XDG_RUNTIME_DIR is /run/user/<uid>, but that folder does not exist`, set a folder that
   exists, in this shell:

   ```zsh
   export XDG_RUNTIME_DIR=/tmp/ygg-xdg-$(id -u)
   mkdir -p -m 700 "$XDG_RUNTIME_DIR"
   ```

5. If you did step 4, run the check again.

## First-time setup

`scripts/ygg-models.sh setup` does the whole setup. It is safe to run again: each step that is in place is skipped.

Before you run it, read the model's price:

1. Open the model's page on OpenRouter, such as `https://openrouter.ai/qwen/qwen3.8-27b`.
2. Write down the input price and the output price, in dollars per million tokens. If the page shows a cache read
   price, write it down too.

Then run the setup:

**Caution:** the first setup downloads 18 GB and builds the server image with CUDA. Both take a long time.

1. Run the setup with the price, as `IN:OUT` or `IN:OUT:CACHE_READ`:

   ```zsh
   scripts/ygg-models.sh setup --price IN:OUT
   ```

2. Read the lines that it prints. Each step prints one line that says what it did or that it was already in place:

   | Line | Step |
   | --- | --- |
   | `gpu: ...` | the GPU check; when a step is missing, `ygg-gpu.sh setup` runs |
   | `model list: written ~/.config/ygg/models.yaml (weights ..., state ...)` | the list, made from the example with your folders and price |
   | `download: Qwen3.8-27B-UD-Q4_K_M.gguf: done` and `download: MTP/mtp-Qwen3.8-27B-Q4_0.gguf: done` | the weights, with `hf download` |
   | `image: built ...` | the server image |
   | `server: started on http://127.0.0.1:8088, without the chat template for now` | the first start |
   | `load: qwen3.8-27b: loaded` | the model is loaded |
   | `template: saved .../chat-template.jinja` | the chat template that Claude Code needs |
   | `server: started again on http://127.0.0.1:8088, with the chat template` | the start with the whole preset; the model loads again |

3. Check the server:

   ```zsh
   scripts/ygg-models.sh status
   ```

   Expect `running on http://127.0.0.1:8088, loaded: qwen3.8-27b`.

4. Check that a client gets an answer:

   ```zsh
   scripts/qwen-opencode.sh run "Say OK."
   ```

   Expect `OK`.

What the setup made:

- The model list, `~/.config/ygg/models.yaml`. It is your file. Never commit it.
- The weights, in `~/ygg-it/models/weights`: the two model files, `chat-template.jinja`, and `.cache/huggingface`
  (the download's own state).
- The state, in `~/ygg-it/models/state`: `preset.ini`, and the allow file `allowed` when a run has used the server.
- The image (`ygg models image` prints its tag), the container `ygg-models` and the internal network `ygg-models`.

`--price`, `--weights` and `--state` count for a new list only. When the list exists, `setup` uses it as it is.

## Start, stop and status

**Warning:** `stop` and `load` do not check for runs. Stop the server or load another model only when no run uses
the server.

To see whether a run uses the server, list the containers on its network. Any name other than `ygg-models` is a run's:

```zsh
scripts/ygg-engine.sh run -- podman container ls -a --filter network=ygg-models --format '{{.Names}}'
```

| Task | Command | What it prints |
| --- | --- | --- |
| Start | `scripts/ygg-models.sh start` | `ready on http://127.0.0.1:8088 (container ygg-models; ...)`, or `already running on ...` |
| Load a model | `scripts/ygg-models.sh load qwen3.8-27b` | `loaded qwen3.8-27b` |
| Status | `scripts/ygg-models.sh status` | `running on http://127.0.0.1:8088, loaded: <name or none>`; `not running` and exit 3 |
| Stop | `scripts/ygg-models.sh stop` | `stopped ygg-models`; the network and the image stay |
| Read the server's log | `scripts/ygg-engine.sh run -- podman logs --tail 50 ygg-models` | the end of the log |

`start` runs `ygg-gpu.sh check` first. It starts with no model loaded. A run loads its own model. For interactive use,
run `load` after `start`.

To apply a change to the list's `args` or `context`, stop and start the server.

## Use the server

The server holds one model and serves one request at a time.

**Warning:** do not use OpenCode or Claude Code on the server while a run uses it. A request for another model
swaps the model under the run. A request for the same model makes the run wait.

### In a run

1. Make sure that the server runs: `scripts/ygg-models.sh status`.
2. In the run's `factory.yaml`, name the local model on an `opencode` role. Do not set `reasoning:` on that role:
   the model list sets the effort.

   ```yaml
   roles:
     reviewer: { agent: opencode, model: local/qwen3.8-27b }
   ```

3. In the same `factory.yaml`, add the model list as a clean absolute path:

   ```yaml
   models:
     file: /home/<user>/.config/ygg/models.yaml
   ```

4. Name one local model only. Two local roles may share it. A run whose roles name two local models is refused.
5. Check the config. Expect a line that starts with `OK    models:`:

   ```zsh
   scripts/ygg-engine.sh run -- ygg doctor --project PROJECT --config FACTORY_YAML
   ```

6. Start the run as usual.

What the run does and what it counts:

- Before the first sandbox starts, `ygg` checks that the server answers, writes the allow file and loads the model.
  The load takes about 40 to 80 seconds. When the server does not answer, the run is refused and nothing is made.
- A local session counts toward the token and turn caps. It never counts toward the dollar caps.
- A config whose roles are all local or Claude Code needs no `usd` line in `budget`. A config with an OpenRouter
  role still needs one, and the dollar caps count what OpenRouter billed.
- The ledger records a local session with provider `local` and a cost at the list's price, marked as estimated.
  `ygg metrics` and the report show it beside the real costs.

### In the proof and smoke scripts

1. Name the local role and the model list. For a proof run, the reviewer:

   ```zsh
   scripts/ygg-proof-run.sh --name NAME --reviewer opencode:local/qwen3.8-27b \
     --models ~/.config/ygg/models.yaml --dry-run
   ```

   For the real-agent smoke, the implementer:

   ```zsh
   scripts/ygg-smoke-real.sh --dry-run --implementer opencode:local/qwen3.8-27b --models ~/.config/ygg/models.yaml
   ```

2. Read the plan. For a local reviewer, expect `the reviewer is a local model, so its reasoning is left out of the
   config`. When no role is on OpenRouter, expect `no role is paid per token, so the config has no usd line`.
3. Run the same command without `--dry-run`.

The scripts refuse a local role without `--models`, `--models` without a local role, and roles on two local models.
A local role needs no credential. `--reviewer-reasoning` does not apply to a local reviewer.

### Switch a stopped run's reviewer to the local model

The founder did this for run 1, which stopped with an OpenRouter reviewer and resumed with the local one.

**Caution:** the run then has two reviewers in its record. Write the switch down with the run's evidence.

1. Make sure that the run is stopped or paused (exit 3 or 4), not running.
2. Make sure that the server runs: `scripts/ygg-models.sh status`.
3. Set `W` to the run's proof folder:

   ```zsh
   W=~/ygg-it/proof-NAME-TIME
   ```

4. Back up the two files you will change:

   ```zsh
   cp "$W/factory.yaml" "$W/factory.yaml.before-local"
   cp "$W/proof.meta" "$W/proof.meta.before-local"
   ```

5. In `$W/factory.yaml`, change the reviewer line to `reviewer: { agent: opencode, model: local/qwen3.8-27b }`.
   Remove its `reasoning:`.
6. At the end of `$W/factory.yaml`, add the model list:

   ```yaml
   models:
     file: /home/<user>/.config/ygg/models.yaml
   ```

7. In `$W/proof.meta`, change the `reviewer` line to `reviewer opencode:local/qwen3.8-27b`.
8. If you rebuilt `ygg` since the run started, build the sandbox images again:

   ```zsh
   scripts/ygg-engine.sh run -- ygg sandbox build --all --config "$W/factory.yaml"
   ```

9. Do a dry run. Expect the `OK    models:` line from `ygg doctor` and `dry run: nothing was started`:

   ```zsh
   scripts/ygg-proof-run.sh --continue RUN --resume --dry-run
   ```

10. Resume the run:

    ```zsh
    scripts/ygg-proof-run.sh --continue RUN --resume
    ```

To go back, copy the two `.before-local` files over the changed ones while the run is stopped.

Build `ygg` with `scripts/ygg-build.sh` only. A `ygg` built by hand has no build facts: the proof script refuses it,
and the run records the factory version as `odin unknown`.

### In OpenCode and Claude Code

1. Make sure that no run uses the server.
2. Load the model: `scripts/ygg-models.sh load qwen3.8-27b`.
3. For OpenCode, start a session:

   ```zsh
   scripts/qwen-opencode.sh
   ```

   For one prompt, use `scripts/qwen-opencode.sh run "..."`.
4. For Claude Code, set up its config folder once:

   ```zsh
   scripts/qwen-claude.sh init
   ```

   It writes `~/.claude-qwen` (`QWEN_CLAUDE_DIR`). It reads the plugins and skills of your personal config folder
   (`QWEN_PERSONAL_DIR`, default `~/.claude-personal`) and never writes to it.
5. Start a Claude Code session:

   ```zsh
   scripts/qwen-claude.sh
   ```

   For one prompt, use `scripts/qwen-claude.sh -p "..."`.

Both scripts find the server through `ygg-models.sh status`, and remove the cloud credentials from the session. Set
these variables when your setup is not the default:

| Variable | When | Value |
| --- | --- | --- |
| `QWEN_MODELS` | the list is not `~/.config/ygg/models.yaml` | the list's path |
| `QWEN_FOLDER` | the factory folder is not `~/ygg-it` | the factory folder |
| `QWEN_ALIAS` | the model is not `qwen3.8-27b` | the model's name in the list |
| `QWEN_CTX` | the model's `context` is not 102400 | the model's `context` |

## Change or add a model

A model in the list has these keys:

| Key | What |
| --- | --- |
| `file` | the model file, under the weights folder |
| `context` | the context size in tokens |
| `output` | the most output tokens a client asks for |
| `args` | `llama-server` preset keys, written as given; a path names the container's view, such as `/models/...` |
| `download` | `repo` (`owner/name` on Hugging Face), `revision` (optional; default `main`) and `files` (paths in the repo; each lands at the same path under the weights folder) |
| `price` | `input` and `output` (required), `cache_read` and `cache_write` (optional): OpenRouter's price in dollars per million tokens |

`llama-server` takes the sampling settings (`temp`, `top-k`, `top-p`) from the model file. Set them in `args` only
to override the file. The example sets `min-p: "0"` because the Qwen file has no `min_p`.

`setup` makes one chat template only, at `/models/chat-template.jinja`, for the model it loads. Do not name that
file for a second model.

**Warning:** this procedure stops the server. Do it only when no run uses the server.

1. Edit the model list. Add the model under `models:`, or change the keys of a model.
2. Stop the server:

   ```zsh
   scripts/ygg-models.sh stop
   ```

3. Run the setup for that model:

   ```zsh
   scripts/ygg-models.sh setup --model NAME
   ```

4. Check that the model is loaded: `scripts/ygg-models.sh status`.

`setup` downloads the missing files, starts the server with the new preset and loads the model.

To switch between models that are in the list, run `scripts/ygg-models.sh load NAME`. A run loads the model that its
roles name.

A change to `price` only needs the edit. The next run reads it.

## After a Windows driver update or on a new Podman machine

A driver update can make the GPU unreachable for the engine. A new Podman machine has no NVIDIA toolkit.

1. Check the GPU:

   ```zsh
   scripts/ygg-gpu.sh check
   ```

   Expect `gpu: NVIDIA ...`, with the GPU's name and memory.
2. If it prints `missing: toolkit`, `missing: spec` or `missing: stale spec` (exit 3), set it up:

   ```zsh
   scripts/ygg-gpu.sh setup
   ```

3. On a new Podman machine, run the setup again. It builds the missing image and starts the server:

   ```zsh
   scripts/ygg-models.sh setup
   ```

`ygg-models.sh start` sets up a stale spec by itself. Add `--machine NAME` to `ygg-gpu.sh` when the machine is not
the default one.

## Clean up

**Caution:** `clean --weights` deletes 18 GB of downloads. You download them again with `setup`.

`clean` refuses, and changes nothing, while another container is on the model network.

1. To remove the server, the network and the image, run:

   ```zsh
   scripts/ygg-models.sh clean
   ```

2. To also remove the state files (`preset.ini`, `allowed` and their temporary files), add `--state`. The state
   folder stays:

   ```zsh
   scripts/ygg-models.sh clean --state
   ```

3. To also delete the downloaded files, add `--weights`. It deletes the files that the list's `download` names and
   `.cache/huggingface` in the weights folder. It refuses when `.cache` or `.cache/huggingface` is a symlink:

   ```zsh
   scripts/ygg-models.sh clean --weights
   ```

`clean` never deletes the model list, the folders, `chat-template.jinja` or any file that the list does not
download.

If `clean` names containers of runs that have ended, remove those first:

1. See what would be cleaned:

   ```zsh
   scripts/ygg-clean.sh --dry-run
   ```

2. Clean:

   ```zsh
   scripts/ygg-clean.sh
   ```

3. Run `scripts/ygg-models.sh clean` again.

## Troubleshooting

| Symptom | Cause | What to do |
| --- | --- | --- |
| `start` or `setup` fails with `unresolvable CDI devices nvidia.com/gpu=all`, or says `the engine cannot resolve the GPU` | The NVIDIA toolkit or its CDI spec is missing where the engine runs: in the Podman machine's own distro, not in the distro that runs `ygg` | `scripts/ygg-gpu.sh setup` |
| `ygg-gpu.sh check` prints `missing: stale spec` | A Windows driver update moved the driver folder that the spec names | `scripts/ygg-gpu.sh setup`; `start` also does it |
| `ygg-engine.sh` refuses `XDG_RUNTIME_DIR` | WSL restarted without a user session, so `/run/user/<uid>` is gone | Set `XDG_RUNTIME_DIR=/tmp/ygg-xdg-$(id -u)` and make the folder (see "Before you start") |
| `ygg models server` says that a folder `is under none of ...'s sandbox.mounts` | The weights or the state folder is outside every mounted folder | Move the folder under a mounted folder, such as `~/ygg-it/models`, and change the list. A symlink to a file outside the mounts does not resolve in the engine |
| Every Claude Code request fails with HTTP 500, `System message must be at the beginning` | The fixed chat template is missing, or the list does not name it | Make sure that the model has `chat-template-file: /models/chat-template.jinja` in `args`. When no run uses the server, run `scripts/ygg-models.sh stop`, then `scripts/ygg-models.sh setup` |
| A resume fails with `missing localhost/ygg-work:<tag>` | `ygg` was rebuilt from other commits, so the sandbox image tags changed | `scripts/ygg-engine.sh run -- ygg sandbox build --all --config FACTORY_YAML`, then resume |
| `setup` or `clean` says `other containers are on the network ygg-models` | A run uses the server, or an ended run left containers | Let the run end. For an ended run, `scripts/ygg-clean.sh --dry-run`, then `scripts/ygg-clean.sh`. Run the command again |
| A load fails (`the load failed, exit_code N`) after a download stopped halfway | A model file is incomplete. `setup` never replaces a file that is there | Delete that file in the weights folder, then run `scripts/ygg-models.sh setup` |
| `start` fails to publish the port | Another program uses port 8088 | Stop that program, or change `server.host_port` in the list |
| `setup` fails on `ygg models sources`, or `ygg models` is unknown | The `ygg` on `PATH` is older than `ygg models` | `scripts/ygg-build.sh` |
| `ygg run` or `ygg doctor` says `the model server does not answer` | The server is not running | `scripts/ygg-models.sh start` |
| The first request, or a run's start, waits for about a minute | The model loads: about 40 seconds without the draft model, 80 seconds with it | Wait. `load` waits up to 300 seconds |
| The server goes away in a long session, and `dmesg` shows `Out of memory: Killed process (llama-server)` | WSL ran out of RAM | Keep `cache-ram` and `ctx-checkpoints` low in `args`, or give WSL more memory in `.wslconfig` |
| `setup` refuses with `a new list needs --price` | There is no list yet | Run `setup` with `--price IN:OUT` |
