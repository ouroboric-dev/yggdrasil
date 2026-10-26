---
title: Local models
status: draft
date: 2026-10-26
related: [README.md, proof-runs.md, ../../2-engineering/specs/2026-10-25-local-models.md, ../../2-engineering/changes/2026-10-26-local-models-setup/proposal.md]
style: procedure
---

# Local models

This page is for the operator who runs a model on their own GPU and uses it from the factory. It gives the setup,
the daily commands, how runs and the interactive tools use the server, and what to do when something fails.

## What this is

One container, the model server, runs `llama-server` with one model loaded. Runs, OpenCode and Claude Code all use
this one server. A role on a local model bills nothing, but the run records a notional cost at the model's OpenRouter
price, so a local run compares with a paid one.

Every command on this page is for zsh. Run each one from your `ouroboric` clone, unless a step says otherwise. The
scripts are in `scripts/`. The comment block at the top of each script is its full reference.

The defaults that this page uses:

| What | Default | Flag that changes it |
| --- | --- | --- |
| The factory folder, which holds `factory.yaml` | `~/ygg-it` | `--folder DIR` |
| The model list | `${XDG_CONFIG_HOME:-$HOME/.config}/ygg/models.yaml` | `--models FILE` |
| The weights (the model files) | `~/ygg-it/models/weights` | `setup --weights DIR`, for a new list only |
| The state (the preset and the allow file) | `~/ygg-it/models/state` | `setup --state DIR`, for a new list only |
| The server on the host | `http://127.0.0.1:8088` | `server.host_port` in the list |

`--models` and `--folder` go before the command, such as `scripts/ygg-models.sh --folder DIR status`.

The placeholders on this page:

| Placeholder | What to write |
| --- | --- |
| `<user>` | your user name, in a path such as `/home/<user>/ygg-it` |
| `NAME` | a model's name in the list, such as `qwen3.8-27b`; for a proof run, the run's name |
| `PROJECT` | the project folder of a run, such as `~/ygg-it/proof-NAME-TIME/project` |
| `FACTORY_YAML` | the run's `factory.yaml`, such as `~/ygg-it/proof-NAME-TIME/factory.yaml` |
| `proof-NAME-TIME` | the folder that `ygg-proof-run.sh` made for a proof run, such as `proof-r1-20261024-101500` |
| `RUN` | the run id, such as `20261024-101500-a1b2c3`: the proof script prints it, and it is the folder name under `PROJECT/.factory/runs/` |

## Before you start

You need:

- Windows with WSL2, and an NVIDIA GPU with a Windows driver that gives CUDA to WSL. `nvidia-smi` must show the GPU.
  The example model uses about 19 GB of GPU memory.
- The factory's engine: a rootless Podman machine on WSL2, the bind mount and the devcontainer CLI. There is no
  install runbook for these yet. [Proof runs, before the first run](proof-runs.md#before-the-first-run) gives the
  checks and the steps after a restart.
- A `factory.yaml` in the factory folder with `sandbox.engine` and `sandbox.mounts`. The engine sees your files only
  through `sandbox.mounts`, so the weights and the state must be under a mounted folder. The default folders are under
  `~/ygg-it`, which this mount covers:

  ```yaml
  sandbox:
    engine: unix:///mnt/wsl/podman-sockets/<machine>/podman-user.sock
    mounts:
      - { host: /home/<user>/ygg-it, engine: /mnt/wsl/ygg-bind }
  ```

- Your `yggdrasil` clone beside your `ouroboric` clone, as `../yggdrasil`. For another place, add
  `--yggdrasil DIR` to `ygg-build.sh`.
- `go`, `git`, `sha256sum`, `python3` and `curl` on `PATH`.
- `$(go env GOPATH)/bin` first on `PATH`, so that the `ygg` you build is the one that runs. For another place, add
  `--out FILE` to `ygg-build.sh`.
- `uv` (for `uvx`) or `hf` on `PATH`, to download the weights.
- `opencode` on `PATH`. The setup's last check uses it.
- For Claude Code: `claude` on `PATH`.
- About 20 GB of free disk under the mounted folder. The example model's two files are 18 GB.

`ygg-build.sh` refuses a module that has changes or that is behind its `origin/main`. Each module of
`../yggdrasil/go.work` must be on `main`.

Build `ygg`, so that the `ygg` on your `PATH` has `ygg models`:

1. Look at the `use` block of `../yggdrasil/go.work`. Each module is on its own line, as a tab and `./<module>`.
2. Update each module:

   ```zsh
   for m in $(sed -n 's#^\t\./##p' ../yggdrasil/go.work); do git -C ../yggdrasil/$m fetch -q origin main && git -C ../yggdrasil/$m checkout -q origin/main; done
   ```

3. Build `ygg`:

   ```zsh
   scripts/ygg-build.sh
   ```

4. Check the engine:

   ```zsh
   scripts/ygg-engine.sh check
   ```

If the check refuses with `XDG_RUNTIME_DIR is /run/user/<uid>, but that folder does not exist`, do one of these
fixes, then run the check again:

- For this shell only:

  ```zsh
  export XDG_RUNTIME_DIR=/tmp/ygg-xdg-$(id -u)
  mkdir -p -m 700 "$XDG_RUNTIME_DIR"
  ```

- For every shell, until WSL restarts, in a terminal where `sudo` can ask for your password:

  ```zsh
  sudo mkdir -p "/run/user/$(id -u)" && sudo chown "$(id -u):$(id -g)" "/run/user/$(id -u)" && sudo chmod 700 "/run/user/$(id -u)"
  ```

## First-time setup

`scripts/ygg-models.sh setup` does the whole setup. It is safe to run again: each step that is in place is skipped.

Read the model's price first:

1. Open the model's page on OpenRouter, such as `https://openrouter.ai/qwen/qwen3.8-27b`.
2. Write down the input price and the output price, in dollars per million tokens.
3. If the page shows a cache read price, write it down too.

**Caution:** the first setup downloads 18 GB and builds the server image with CUDA. Both take a long time.

Then run the setup:

1. Run the setup with the price, as `IN:OUT` or `IN:OUT:CACHE_READ`:

   ```zsh
   scripts/ygg-models.sh setup --price IN:OUT
   ```

2. Compare the lines that it prints with the table below.
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

What `setup` prints, from the script (each step prints one line that says what it did, or that it was already in
place):

| Line | Step |
| --- | --- |
| `gpu: already in place (NVIDIA ...)`, or `gpu: set up` | the GPU check; when a step is missing, `ygg-gpu.sh setup` runs |
| `model list: written /home/<user>/.config/ygg/models.yaml (weights ..., state ...)` | the list, made from the example with your folders and price |
| `download: Qwen3.8-27B-UD-Q4_K_M.gguf: done` and `download: MTP/mtp-Qwen3.8-27B-Q4_0.gguf: done` | the weights, with `hf download` |
| `ygg-models: building the image ... (the first build takes a long time: CUDA)` | the image build starts |
| `image: built ...` | the image build is done |
| `server: started on http://127.0.0.1:8088, without the chat template for now` | the first start |
| `load: qwen3.8-27b: loaded` | the model is loaded |
| `template: saved .../chat-template.jinja` | the chat template that Claude Code needs |
| `server: started again on http://127.0.0.1:8088, with the chat template` | the start with the whole preset; the next `load:` line follows |

What the setup made:

- The model list, `${XDG_CONFIG_HOME:-$HOME/.config}/ygg/models.yaml`. It is your file. Never commit it.
- The weights, in `~/ygg-it/models/weights`: the two model files, `chat-template.jinja`, and `.cache/huggingface`
  (the download's own state).
- The state, in `~/ygg-it/models/state`: `preset.ini`, and the allow file `allowed` when a run has used the server.
- The image (`ygg models image` prints its tag), the container `ygg-models` and the internal network `ygg-models`.

`--price`, `--weights` and `--state` count for a new list only. When the list exists, `setup` uses it as it is.

When `setup` must make the chat template, it restarts the server. In that case only, it first checks the model
network: while another container is on it, `setup` refuses before any step. If a run joins the network during the setup, the setup stops before the restart
and says that the server runs without the template.

## Start, stop and status

**Caution:** `stop` and `load` do not check for runs. A `stop` or a `load` of another model under a run breaks the
run's sessions. Stop the server or load another model only when no run uses it.

To see whether a run uses the server, list the containers on its network:

```zsh
scripts/ygg-engine.sh run -- podman container ls -a --filter network=ygg-models --format '{{.Names}}'
```

Any name other than `ygg-models` is a run's container.

| Task | Command | What it prints |
| --- | --- | --- |
| Start | `scripts/ygg-models.sh start` | `ready on http://127.0.0.1:8088 (container ygg-models; ...)`, or `already running on ...` |
| Load a model | `scripts/ygg-models.sh load NAME` | `loaded NAME` |
| Status | `scripts/ygg-models.sh status` | `running on http://127.0.0.1:8088, loaded: <name or none>`; `not running` and exit 3 |
| Stop | `scripts/ygg-models.sh stop` | `stopped ygg-models`; the network and the image stay |
| Read the server's log | `scripts/ygg-engine.sh run -- podman logs --tail 50 ygg-models` | the end of the log |

`start` runs `ygg-gpu.sh check` first. It starts with no model loaded. A run loads its own model. For interactive use,
run `load` after `start`.

A change to the list's `args` or `context` applies at the next start: stop, then start the server.

## Use the server

The server holds one model and serves one request at a time.

**Caution:** do not use OpenCode or Claude Code on the server while a run uses it. A request for another model
swaps the model under the run. A request for the same model makes the run wait.

### In a run

The rules for a local role:

- The agent is `opencode`, and the model is `local/NAME`.
- The role sets no `reasoning:`. The model list sets the effort.
- A run names one local model. Two local roles may share it. A run whose roles name two local models is refused.
- `models.file` is a clean absolute path.

1. Make sure that the server runs: `scripts/ygg-models.sh status`.
2. In the run's `factory.yaml`, name the local model on the role, with two spaces before the role's name:

   ```yaml
   roles:
     reviewer: { agent: opencode, model: local/qwen3.8-27b }
   ```

3. In the same `factory.yaml`, add the model list:

   ```yaml
   models:
     file: /home/<user>/.config/ygg/models.yaml
   ```

4. Check the config:

   ```zsh
   scripts/ygg-engine.sh run -- ygg doctor --project PROJECT --config FACTORY_YAML
   ```

   Expect a line that starts with `OK    models:`.

5. Start the run as usual.

What the run does and what it counts:

- Before the first sandbox starts, `ygg` checks that the server answers, writes the allow file and loads the model.
  The load takes about 40 to 80 seconds. When the server does not answer, the run is refused and nothing is made.
- A local session counts toward the token and turn caps. It never counts toward the dollar caps.
- A config whose roles are all local or Claude Code needs no `usd` line in `budget`. A config with an OpenRouter
  role still needs one, and the dollar caps count what OpenRouter billed.
- The ledger records a local session with provider `local` and a cost at the list's price, marked as estimated.
  `ygg metrics` and the report show it beside the real costs.

### In the proof and smoke scripts

The scripts refuse a local role without `--models`, `--models` without a local role, and roles on two local models.
A local role needs no credential. `--reviewer-reasoning` does not apply to a local reviewer.

For a proof run with a local reviewer:

1. Do a dry run:

   ```zsh
   scripts/ygg-proof-run.sh --name NAME --reviewer opencode:local/qwen3.8-27b \
     --models "${XDG_CONFIG_HOME:-$HOME/.config}/ygg/models.yaml" --dry-run
   ```

2. In the plan, find `the reviewer is a local model, so its reasoning is left out of the config`.
3. When no other role is on OpenRouter, find `no role is paid per token, so the config has no usd line`.
4. Run the same command without `--dry-run`.

For the real-agent smoke with a local implementer:

1. Do a dry run:

   ```zsh
   scripts/ygg-smoke-real.sh --dry-run --implementer opencode:local/qwen3.8-27b \
     --models "${XDG_CONFIG_HOME:-$HOME/.config}/ygg/models.yaml"
   ```

2. In the plan, find `smoke-real: the implementer: { agent: opencode, model: local/qwen3.8-27b }`.
3. Run the same command without `--dry-run`.

The smoke's reviewer stays on OpenRouter, so the smoke keeps its `usd` caps and needs `OPENROUTER_API_KEY`.

### Switch a stopped run's reviewer to the local model

The founder did this for run 1, which stopped with an OpenRouter reviewer and resumed with the local one. The run then
has two reviewers in its record.

Build `ygg` with `scripts/ygg-build.sh` only. A `ygg` built by hand has no build facts: the proof script refuses it,
and the run records the factory version as `odin unknown`.

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

5. In `$W/factory.yaml`, under `roles:`, change the reviewer line to this line, with its two spaces:

   ```yaml
     reviewer: { agent: opencode, model: local/qwen3.8-27b }
   ```

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

9. Do a dry run:

   ```zsh
   scripts/ygg-proof-run.sh --continue RUN --resume --dry-run
   ```

10. Find the `OK    models:` line from `ygg doctor` and `dry run: nothing was started`.
11. Resume the run:

    ```zsh
    scripts/ygg-proof-run.sh --continue RUN --resume
    ```

12. Write the switch down with the run's evidence.

To go back, copy the two `.before-local` files over the changed ones while the run is stopped.

### In OpenCode and Claude Code

`qwen-claude.sh init` needs a personal Claude Code config folder, `QWEN_PERSONAL_DIR` (default `~/.claude-personal`).
That folder must hold `skills/` and `hooks/merge-requires-green.sh`. Without them, the skills link points to nothing
and the hook command is missing. This is a known gap of `qwen-claude.sh`.

For OpenCode:

1. Make sure that no run uses the server.
2. Load the model:

   ```zsh
   scripts/ygg-models.sh load qwen3.8-27b
   ```

3. Start a session:

   ```zsh
   scripts/qwen-opencode.sh
   ```

For Claude Code:

1. Make sure that no run uses the server.
2. Load the model:

   ```zsh
   scripts/ygg-models.sh load qwen3.8-27b
   ```

3. Set up the config folder, once:

   ```zsh
   scripts/qwen-claude.sh init
   ```

4. Start a session:

   ```zsh
   scripts/qwen-claude.sh
   ```

For one prompt, use `scripts/qwen-opencode.sh run "..."` or `scripts/qwen-claude.sh -p "..."`.

What `qwen-claude.sh init` does:

- It writes the config folder `~/.claude-qwen` (`QWEN_CLAUDE_DIR`).
- It installs the plugins `superpowers`, `gopls-lsp` and `skill-creator` from the `claude-plugins-official`
  marketplace. This uses `claude` and the network.
- It links `skills` to `QWEN_PERSONAL_DIR/skills`.
- It writes a `PreToolUse` hook that runs `QWEN_PERSONAL_DIR/hooks/merge-requires-green.sh`.
- It reads no plugins from the personal folder, and never writes to it.

Both scripts find the server through `ygg-models.sh status`, and remove the cloud credentials from the session. Set
these variables when your setup is not the default:

| Variable | When | Value |
| --- | --- | --- |
| `QWEN_MODELS` | the list is not `${XDG_CONFIG_HOME:-$HOME/.config}/ygg/models.yaml` | the list's path |
| `QWEN_FOLDER` | the factory folder is not `~/ygg-it` | the factory folder |
| `QWEN_ALIAS` | the model is not `qwen3.8-27b` | the model's name in the list |
| `QWEN_CTX` | the model's `context` is not 102400 | the model's `context` |
| `QWEN_PERSONAL_DIR` | the personal Claude Code folder is not `~/.claude-personal` | that folder |

## Change or add a model

A model in the list has these keys:

| Key | What |
| --- | --- |
| `file` | the model file, under the weights folder |
| `context` | the context size in tokens |
| `output` | the most output tokens that a run's OpenCode asks for; `qwen-opencode.sh` always asks for 32768 |
| `args` | `llama-server` preset keys, written as given (see the rules below) |
| `download` | `repo` (`owner/name` on Hugging Face), `revision` (optional; default `main`) and `files` (paths in the repo; each lands at the same path under the weights folder) |
| `price` | `input` and `output` (required), `cache_read` and `cache_write` (optional): OpenRouter's price in dollars per million tokens |

The rules for `args`:

- Do not set `model`, `m`, `ctx-size`, `c`, `host`, `port`, `alias` or `a`. The preset writes them.
- A flag with no value takes `"true"` or `"false"`.
- An empty value is refused.
- A path names the container's view, such as `/models/...`.
- `llama-server` takes the sampling settings (`temp`, `top-k`, `top-p`) from the model file. Set them only to
  override the file. The example sets `min-p: "0"` because the Qwen file has no `min_p`.

`setup` makes one chat template only, at `/models/chat-template.jinja`, for the model it loads. That file holds one
model's template.

**Caution:** this procedure stops the server. Do it only when no run uses the server.

1. Edit the model list. Add the model under `models:`, or change the keys of a model.
2. Stop the server:

   ```zsh
   scripts/ygg-models.sh stop
   ```

3. Run the setup for that model:

   ```zsh
   scripts/ygg-models.sh setup --model NAME
   ```

4. Check that the model is loaded:

   ```zsh
   scripts/ygg-models.sh status
   ```

`setup` downloads the missing files, starts the server with the new preset and loads the model.

To switch between models that are in the list, run `scripts/ygg-models.sh load NAME`. A run loads the model that its
roles name.

A change to `price` needs only the edit. The next run reads it.

## After a Windows driver update or on a new Podman machine

A driver update can make the GPU unreachable for the engine. A new Podman machine has no NVIDIA toolkit.
`ygg-models.sh start` sets up a stale spec by itself.

1. Check the GPU:

   ```zsh
   scripts/ygg-gpu.sh check
   ```

   Expect `gpu: NVIDIA ...`, with the GPU's name and memory.

2. If it prints `missing: toolkit`, `missing: spec` or `missing: stale spec` (exit 3), set it up:

   ```zsh
   scripts/ygg-gpu.sh setup
   ```

3. On a new Podman machine, run the setup again:

   ```zsh
   scripts/ygg-models.sh setup
   ```

On a new Podman machine, `setup` builds the missing image and starts the server. Add `--machine NAME` to
`ygg-gpu.sh` when the machine is not the default one.

## Clean up

`clean` refuses, and changes nothing, while another container is on the model network. Except
`<weights>/.cache/huggingface`, `clean` never deletes a folder, the model list, `chat-template.jinja` or a file that
the list does not download.

**Caution:** each form of `clean` removes the server image. The next `setup` builds it again with CUDA, which takes a
long time.

**Caution:** `clean --weights` deletes 18 GB of downloads. The next `setup` downloads them again.

Run one of these commands:

| Command | What it removes |
| --- | --- |
| `scripts/ygg-models.sh clean` | the container, the network and the image |
| `scripts/ygg-models.sh clean --state` | the same, and the state files (`preset.ini`, `allowed` and their temporary files); the state folder stays |
| `scripts/ygg-models.sh clean --weights` | the same, and the files that the list's `download` names and `<weights>/.cache/huggingface`; it refuses when `.cache` or `.cache/huggingface` is a symlink |

`--state` and `--weights` go together too: `scripts/ygg-models.sh clean --state --weights`.

If `clean` names containers of runs that have ended, remove those first:

1. See what would be cleaned:

   ```zsh
   scripts/ygg-clean.sh --dry-run
   ```

2. Clean:

   ```zsh
   scripts/ygg-clean.sh
   ```

3. Run your `scripts/ygg-models.sh clean` command again.

## Troubleshooting

| Symptom | Cause | What to do |
| --- | --- | --- |
| `start` or `setup` fails with `unresolvable CDI devices nvidia.com/gpu=all`, or says `the engine cannot resolve the GPU` | The NVIDIA toolkit or its CDI spec is missing where the engine runs: in the Podman machine's own distro, not in the distro that runs `ygg` | `scripts/ygg-gpu.sh setup` |
| `ygg-gpu.sh check` prints `missing: stale spec` | A Windows driver update moved the driver folder that the spec names | `scripts/ygg-gpu.sh setup`. `start` also does it |
| `ygg-gpu.sh check` fails with `the CUDA container failed` (exit 1) | After a driver update, the spec names folders that still exist but no longer match. `setup` does not generate such a spec again | Run `scripts/ygg-gpu.sh setup`. If the check still fails, generate the spec in the machine's distro (see below) |
| `ygg-engine.sh` refuses `XDG_RUNTIME_DIR` | WSL restarted without a user session, so `/run/user/<uid>` is gone | Do one of the fixes in "Before you start" |
| `ygg-engine.sh` says `the bind mount /mnt/wsl/ygg-bind is missing` | WSL restarted | Mount it again, as [Proof runs, before the first run](proof-runs.md#before-the-first-run) says |
| `ygg models server` says that a folder `is under none of ...'s sandbox.mounts` | The weights or the state folder is outside every mounted folder | On a first setup, run `setup --weights DIR --state DIR` with folders under a mount, or add a mount to `factory.yaml`. For an existing list, move the folder under a mount and change the list. A symlink to a file outside the mounts does not resolve in the engine |
| Every Claude Code request fails with HTTP 500, `System message must be at the beginning` | The fixed chat template is missing, or the list does not name it | Make sure that the model has `chat-template-file: /models/chat-template.jinja` in `args`. When no run uses the server, run `scripts/ygg-models.sh stop`, then `scripts/ygg-models.sh setup` |
| The same HTTP 500 on another model of the list | `chat-template.jinja` holds the template of the model that `setup` loaded | When no run uses the server, stop the server, delete `<weights>/chat-template.jinja` and run `scripts/ygg-models.sh setup --model NAME`. The file then holds NAME's template |
| A resume fails with `missing localhost/ygg-work:<tag>` | `ygg` was rebuilt from other commits, so the sandbox image tags changed | `scripts/ygg-engine.sh run -- ygg sandbox build --all --config FACTORY_YAML`, then resume |
| `setup` or `clean` says `other containers are on the network ygg-models` | A run uses the server, or an ended run left containers | Let the run end. For an ended run, `scripts/ygg-clean.sh --dry-run`, then `scripts/ygg-clean.sh`. Run the command again |
| `setup` fails with `the download of ... failed` | The download stopped. `hf` keeps the partial file as `.incomplete` under `<weights>/.cache/huggingface/download` | Run `scripts/ygg-models.sh setup` again |
| A load fails (`the load failed, exit_code N`) with a model file that you put in the weights folder yourself | The file is truncated. `setup` never replaces a file that is there | Delete that file, then run `scripts/ygg-models.sh setup` |
| `start` fails to publish the port | Another program uses port 8088 | Stop that program, or change `server.host_port` in the list |
| `setup` fails on `ygg models sources`, or `ygg models` is unknown | The `ygg` on `PATH` is older than `ygg models` | `scripts/ygg-build.sh` |
| `ygg run` or `ygg doctor` says `the model server does not answer` | The server is not running | `scripts/ygg-models.sh start` |
| The first request, or a run's start, waits for about a minute | The model loads: about 40 seconds without the draft model, 80 seconds with it | Wait. `load` waits up to 300 seconds |
| The server goes away in a long session, and `dmesg` shows `Out of memory: Killed process (llama-server)` | WSL ran out of RAM | Lower `cache-ram` and `ctx-checkpoints` in `args`, then stop and start the server. Or give WSL more memory in `.wslconfig` |
| `setup` refuses with `a new list needs --price` | There is no list yet | Run `setup` with `--price IN:OUT` |

To generate the CDI spec by hand, in the machine's distro (`podman-machine-default` for the default machine):

```zsh
echo 'mkdir -p /etc/cdi && nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml' | wsl.exe -d podman-machine-default -u root -- sh -s
```

Then run `scripts/ygg-gpu.sh check` again.
