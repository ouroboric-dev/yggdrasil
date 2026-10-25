---
title: Local models spec
status: draft
date: 2026-10-25
related: [../../1-product/design/2026-10-25-local-models-design.md, 2026-10-11-yggdrasil-v0-spec.md, ../plans/2026-10-25-local-models/plan.md]
style: spec
---

# Local models spec

## 1. Summary

This spec says how the factory delivers the [local models design](../../1-product/design/2026-10-25-local-models-design.md).
A role names a model from the operator's **model list** as `local/<name>`. One container, the **model server**,
runs `llama-server` in router mode with one model loaded, and a small filter, the **model gate**, in front of it.
Leaf and scratch sandboxes reach the gate over an internal network. The host reaches `llama-server` on a port of
`127.0.0.1`. A local session has a cost figure at the model's OpenRouter price and bills nothing, the way a Claude
Code session on a subscription does today (`gungnir.Usage.BilledUSD`).

Section 9 lists what the first task's spike must confirm on the real engine before the rest is built.

## 2. Architecture and components

```text
host
├── ygg (odin) ── reads factory.yaml → models.file → the model list
│     ├── run start and resume: check the server, write the allow file, load the model
│     └── leaf and scratch sandboxes: Models{network, name, port} in their SandboxSpec
├── scripts/ygg-models.sh ── start | stop | status | load NAME   (ouroboric umbrella)
└── interactive OpenCode / Claude Code ── http://127.0.0.1:<host_port>/v1

podman network <server.network>  (internal: no route out)
├── model server container <server.name>     GPU through CDI; weights at /models, read-only
│     ├── llama-server  router mode, --models-max 1, port 8080
│     └── ygg-modelgate :<server.port> → 127.0.0.1:8080, chat requests for the allowed model only
└── fw sidecar of each leaf or scratch sandbox (the work container shares its network namespace)
```

| Component | Repo | Change |
| --- | --- | --- |
| Model references, `PaidAPI`, the `models` section of `factory.yaml` | `gungnir` | `schema/factory.go`, `factory.schema.json` |
| The model list and its preset | `gungnir` | new `schema/models.go`, `models.schema.json` |
| `SandboxSpec.Models` | `gungnir` | `sandbox.go` |
| The OpenCode adapter on a local model | `gleipnir` | `opencode/opencode.go` |
| The sandbox joins the model network | `gleipnir` | `sandbox/config.go`, `validate.go`, `driver.go` |
| The model server image and the gate | `gleipnir` | new `sandbox/assets/Containerfile.models`, `sandbox/assets/modelgate/`, `sandbox/models.go` |
| Agents, billing, metrics | `odin` | `internal/agents`, `internal/engine/session.go`, `internal/metrics` |
| The server client and the run's checks | `odin` | new `internal/models`, `internal/run/prepare.go`, `run.go`, `sandbox.go` |
| `ygg models`, `ygg doctor` | `odin` | `internal/cli` |
| The server script, the example list, the role flags | `ouroboric` | `scripts/ygg-models.sh`, `scripts/qwen-*.sh`, `scripts/ygg-proof-run.sh`, `scripts/ygg-smoke-real.sh` |

## 3. Interfaces and contracts

### 3.1 `factory.yaml`

```yaml
models:
  file: /abs/path/models.yaml   # the model list; required when a role names local/<name>
roles:
  reviewer: { agent: opencode, model: local/qwen3.8-27b }
```

- A model reference `local/<name>` is valid only for `agent: opencode`.
- `<name>` MUST match `^[a-z0-9][a-z0-9._-]{0,63}$`.
- A role that names a local model MUST NOT set `reasoning:`. The model list sets the effort for the model.
- `models.file` MUST be an absolute path.

### 3.2 The model list

The model list is the operator's file. It is never committed. The committed example is
`ouroboric/scripts/testdata/models/models.example.yaml`.

```yaml
server:
  name: ygg-models        # the container's name and its name on the network
  network: ygg-models     # an internal podman network
  port: 8089              # the gate's port on that network
  host_port: 8088         # llama-server on 127.0.0.1 of the host
  weights: /abs/dir       # mounted read-only at /models
  state: /abs/dir         # the preset and the allow file; mounted read-only at /etc/ygg-models
models:
  qwen3.8-27b:
    file: model.gguf      # under weights
    context: 102400       # the context size; becomes ctx-size in the preset
    output: 32768         # the most output tokens OpenCode asks for
    args:                 # llama-server preset keys, written as given
      n-gpu-layers: "999"
      reasoning-effort: low
    price: { input: 0.10, output: 0.40 }   # example values: OpenRouter's price, dollars per million tokens
```

- `price.input` and `price.output` are required. `cache_read` and `cache_write` are optional and default to 0.
- `args` MUST NOT hold `model`, `ctx-size`, `c`, `host`, `port` or `alias`. The preset writes those.
- A path in `args` names the container's view, such as `/models/mtp.gguf`. The preset does not resolve a relative
  path.
- A flag with no value is given as `"true"` or `"false"`. Keys are long option names: `ParseModels` refuses a key
  that starts with `-`, and an empty value.

### 3.3 The preset

`ygg models preset FILE` writes llama-server's preset INI to stdout. Each model is a section named by the model's
name, with `model = /models/<file>`, `ctx-size = <context>`, then the `args` keys in sorted order. The key format
is the spike's (§9): the file starts with `version = 1`; keys are llama-server's long option names without `--`,
written `key = value`; a flag with no value is written `key = true` (`false` gives its `--no-` form). A key without
`=`, or a key the pinned build does not know, stops the router at start, so `ygg-models.sh start` prints the end of
the server's log when the container exits while starting.

### 3.4 The model server

- The image is built by `ygg models build`. Its Containerfile builds `llama-server` from `ggml-org/llama.cpp` at
  commit `4c3c581` with `GGML_CUDA=ON` and `CMAKE_CUDA_ARCHITECTURES=89` (a build argument). The tag is a hash
  of the Containerfile and the gate's source, like the sandbox images.
- The container runs `llama-server --models-preset /etc/ygg-models/preset.ini --models-max 1 --host 0.0.0.0
  --port 8080`, and `ygg-modelgate -listen :<port> -upstream http://127.0.0.1:8080 -allow
  /etc/ygg-models/allowed`. When either process exits, the container exits.
- `scripts/ygg-models.sh` starts it with the GPU (`--device nvidia.com/gpu=all`), the two read-only mounts,
  the network, and the published port on `127.0.0.1:<host_port>`.
- The engine resolves the CDI device, so the NVIDIA container toolkit and its spec (`nvidia-ctk cdi generate
  --output=/etc/cdi/nvidia.yaml`) are installed where the engine runs: on a Podman machine under WSL2, inside the
  machine's distro (`podman-machine-default`), not in the distro that runs `ygg`. A driver update or a new machine
  needs the spec generated again. When the engine answers `unresolvable CDI devices`, `start` says so and names
  this step.

### 3.5 The model gate

The gate passes a request to `llama-server` only when all of these hold:

1. The method is `POST` and the path is `/v1/chat/completions`.
2. The body is at most 32 MiB of JSON with a string `model`.
3. `model` equals the trimmed content of the allow file.

A request with a query string is refused (403): the router reads `?autoload=` from it. Otherwise it answers 403
(path or model), 413 (size), 400 (not JSON) or 503 (no allow file). It streams the
response as `llama-server` writes it.

### 3.6 `gungnir.SandboxSpec.Models`

```go
// ModelServer is the shared model server a sandbox reaches: by Name, on Port, over Network.
type ModelServer struct {
	Network string
	Name    string
	Port    int
}
```

`SandboxSpec.Models *ModelServer`. `Validate` refuses a name or network that does not match
`^[a-z0-9][a-z0-9_.-]{0,62}$`, and a port outside 1 to 65535.

### 3.7 Gleipnir's sandbox

When `spec.Models` is set:

- The compose file declares the network `models` as `external: true` with `name: <Network>`, and the
  firewall joins it beside its other networks.
- The firewall's services file gets the line `<Name> <Port>`, so the work container reaches the gate by name on
  that port and no other.
- `Up` refuses the sandbox when `podman network inspect` does not say the network is internal.

### 3.8 The OpenCode adapter

- `opencode.New("local/<name>", cfg)` needs `cfg.Local` (`BaseURL`, `Context`, `Output`) and `cfg.Price`.
- The session's configuration names one provider, `local`, with npm package `@ai-sdk/openai-compatible`,
  `options.baseURL` set to `http://<Name>:<Port>/v1`, and the model with `tool_call: true`, `reasoning: true`
  and its `limit`. `small_model` is the same model. It names no API key and no reasoning option.
- A local session needs no `OPENROUTER_API_KEY`. Its `Result.Provider` is `local`.
- Its cost is computed from the price and marked estimated.

### 3.9 Odin

- `schema.PaidAPI(agent, model string) bool` is false for a local model.
- `run.Prepare` refuses a run whose graph's local roles name more than one model, or a model that is not in the
  list. It sets `SandboxSetup.Models` when a local role is in the graph.
- `run.Start` and `run.OpenWith` call `models.Ready` before any sandbox starts. Ready checks that the server
  answers on `http://127.0.0.1:<host_port>` and that its list (`GET /models`, `data[].id`) holds the model, and
  writes the allow file. It then asks the server to load the model (`POST /models/load` with
  `{"model":"<name>"}`). The server answers 200 `{"success":true}` before the load is done, and 400 `model is
  already running` when the model is loaded, which Ready takes as success. Ready polls `GET /models` until the
  model's `status.value` is `loaded`, up to 300 seconds. A status with `"failed": true` ends the wait with an error
  that names its `exit_code`. The list's body holds raw newlines in `status.preset`, which Go's `encoding/json`
  refuses, so the client escapes control characters before it decodes the fields it needs.
- Leaf and scratch sandboxes get `Models`. Snapshot, grader and `ygg deps` sandboxes never do.
- `ygg doctor` reports, for each local role: the list holds the model; the server answers; the network is
  internal.
- `ygg metrics` counts the sessions whose provider is `local`.

### 3.10 Scripts

- `scripts/ygg-models.sh --models FILE start|stop|status|load NAME`. FILE defaults to
  `$XDG_CONFIG_HOME/ygg/models.yaml` (`~/.config/ygg/models.yaml`). It reads the list through `ygg models
  server FILE` and `ygg models preset FILE`, and never parses YAML itself.
- `qwen-lib.sh` finds the server through `ygg-models.sh status`, so `qwen-opencode.sh`, `qwen-claude.sh`,
  `qwen-compare.sh` and `qwen-measure.sh` use the shared server. `qwen-local.sh` is removed.
- `scripts/ygg-gpu.sh setup|check` keeps the GPU usable by the engine, so no step is done by hand twice. `setup`
  installs the NVIDIA container toolkit at a pinned version where the engine runs (on a Podman machine under
  WSL2, inside the machine's distro, as root through `wsl.exe -d <machine> -u root`), generates the CDI spec, and
  runs `check`. It changes nothing that is already in place. `check` runs a CUDA container pinned by digest with
  `--device nvidia.com/gpu=all` through `ygg-engine.sh` and prints the GPU's name, or says which step is missing:
  no toolkit, no spec, or a stale spec (a driver store folder the spec names is gone after a driver update). The
  machine has no systemd, so the toolkit's own refresh units never run; `ygg-models.sh start` runs `check` first,
  generates the spec again when it is stale, and names `setup` for anything else. A container image cannot carry
  this: the engine resolves the CDI device before the container exists.
- `ygg-proof-run.sh` and `ygg-smoke-real.sh` accept `opencode:local/<name>` with `--models FILE`. They ask for
  `OPENROUTER_API_KEY` and a `usd` line only when a role is on OpenRouter.

## 4. Data model

- Ledger: a local session's event has `gen_ai.provider.name: local`, `gen_ai.request.model: local/<name>`, a
  `cost_usd` at the list's price with `cost_estimated: true`, and bills nothing (`billed_usd` is left out).
- Run folder: no new file. The allow file lives in the list's `state` folder, outside every run.

## 5. Acceptance criteria

### 5.1 Configuration

1. ParseFactory MUST refuse `local/<name>` on a role whose agent is not `opencode`.
2. ParseFactory MUST refuse a local role that sets `reasoning`.
3. ParseFactory MUST refuse a local role when `models.file` is missing or not absolute.
4. A config whose only paid-looking roles are local MUST load without `budget.*.usd`.
5. ParseModels MUST refuse a model without `price.input` or `price.output`.
6. ParseModels MUST refuse `args` that hold a key the preset writes.

### 5.2 Run

1. Prepare MUST refuse a graph whose local roles name two models.
2. Start MUST refuse the run, and leave no run folder, when the server does not answer.
3. Start MUST write the run's model to the allow file before the first session.
4. A leaf sandbox of a run with a local role MUST hold the model network. A snapshot sandbox MUST NOT.
5. A local session MUST count toward the token and turn caps and MUST NOT count toward the dollar caps.

### 5.3 Sandbox and gate

1. Up MUST refuse a model network that is not internal.
2. From a work container, the gate MUST answer a chat request for the run's model.
3. From a work container, the gate MUST refuse a request for another model, `/models/load` and `/slots`.
4. From a work container, port 8080 of the server MUST NOT answer.
5. From a work container, every outside host that the run does not open MUST stay closed.

## 6. Security considerations

- **Boundary for the port: the firewall.** The server listens on 8080 and on the gate's port on the internal
  network. Every client on that network is a firewall sidecar, and each one opens only `<Name> <Port>` to its work
  container. The work container cannot reach 8080.
- **Boundary for paths and models: the gate.** It is the only path from a sandbox to `llama-server`. It passes
  chat requests for the allowed model only, so a work container cannot load, unload or read slots.
- **The allow file** is written by Odin on the host and mounted read-only into the server. Nothing in a
  sandbox can write it.
- **No route out.** The model network is internal, and Up checks it. The server sits on the internal network
  alone: a container on an internal network publishes its port on `127.0.0.1` of the host and keeps no route out
  (spike, item 2). Each model process the router starts listens on `127.0.0.1` of the server's container only.
- **The GPU and the weights** are in the server container only.
- **One run at a time on local models.** A second run with another model overwrites the allow file and loads its
  model. The operator runs one at a time (design §5.5).

## 7. Testing approach

- Unit tests in each leaf, test-first, as the tasks name them.
- The gate is tested by building its source with the Go toolchain and running it against an `httptest`
  upstream.
- The sandbox criteria in §5.3 run as integration tests on the real engine, behind the existing `sandbox`
  build tag, with a fake model server (no GPU): the gate in front of a stub that answers on 8080.
- The founder's proof run with a local reviewer is the end-to-end check (design §3.4).

## 8. Decisions

**Decided 2026-10-25:** A model reference is `local/<name>`, and only `opencode` roles take it.

**Decided 2026-10-25:** The model list's `price` is required, so every local session has a cost figure and the
adapter's refusal of tokens with no cost needs no exception.

**Decided 2026-10-25:** A local role does not set `reasoning`; the model list sets the model's effort. One server
model has one effort.

**Decided 2026-10-25:** The gate is a small Go program in the server image, not part of `ygg`, so rebuilding `ygg`
does not rebuild the image.

**Decided 2026-10-25:** `ygg` is the only reader of the model list. The scripts ask it for the server's settings and
the preset.

## 9. Spike: facts confirmed before the build

LM-T01 checked these on the founder's engine and recorded them in the
[spike note](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/5-research/2026-10-25-local-models-spike.md)
(2026-10-25). The sections named were amended to match.

1. Rootless Podman under WSL2 runs a CUDA container with `--device nvidia.com/gpu=all` after the toolkit is
   installed and `nvidia-ctk cdi generate` is run in the Podman machine's distro (§3.4). **Differed:** the spec
   had been generated in the distro that runs `ygg`; pending the founder's step in the machine.
2. A container on an internal network publishes a port on `127.0.0.1` of the host. **Confirmed** (§6).
3. The router's endpoints to list models with their status and to load one, and the preset's key format (§3.2,
   §3.3, §3.5, §3.9). **Confirmed, with details added.**
4. OpenCode, at the version gleipnir pins (1.18.32), uses `@ai-sdk/openai-compatible` in the sandbox without
   fetching it from npm (§3.8). **Confirmed.**
5. A firewall sidecar that joins an external network resolves the server's name through the resolver of that
   network (§3.7). **Confirmed**, also by LM-T06's integration test.

## 10. Deviations from the design doc

None.
