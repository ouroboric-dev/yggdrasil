---
title: Local models tasks
status: implemented
date: 2026-10-25
related: [plan.md, ../../specs/2026-10-25-local-models.md, ../../../1-product/design/2026-10-25-local-models-design.md]
style: spec
---

# Local models tasks

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for
> tracking. Steps marked **founder** are done by the founder, never by an agent.

**Goal:** an `opencode` role runs on a model from the operator's model list, served by one shared `llama-server`
on the local GPU. **Architecture:** spec §2. **Tech stack:** Go (gungnir, gleipnir, odin), Bash (ouroboric
scripts), Podman with CDI, llama.cpp router mode, OpenCode's `@ai-sdk/openai-compatible` provider. **Spec:**
[2026-10-25-local-models.md](../../specs/2026-10-25-local-models.md). Global constraints and review focus:
[plan.md](plan.md).

Every task starts from its leaf's `origin/main`, on a branch, test first, and ends with a pull request opened by
`scripts/pr-open.sh`.

## Tasks

### Task LM-T01: the spike on the founder's engine

Confirms spec §9 before anything is built. No product code.

**Files (in `ouroboric`):** Create `docs/5-research/2026-10-25-local-models-spike.md` (style `research`).

**Acceptance criteria:**

- [ ] Each of the five items in spec §9 has a result, the command that showed it and its output.
- [ ] Each item that differs from the spec names the spec section to amend, and the amendment is in a commit to
      the spec in `yggdrasil` before LM-T03 starts.

**Named test:** none (a spike). **Layer:** `ouroboric`. **Size:** S. **Depends on:** the design doc merged.

- [ ] **Step 1 (founder):** install the NVIDIA container toolkit in WSL2, run `sudo nvidia-ctk cdi generate
      --output=/etc/cdi/nvidia.yaml`, and say when it is done.
- [ ] **Step 2:** item 1. Run `scripts/ygg-engine.sh run -- podman run --rm --device nvidia.com/gpu=all
      docker.io/nvidia/cuda:<12.x>-base-ubuntu22.04 nvidia-smi` (look up a current tag; pin by digest in the
      note). Expected: the 4090 is listed.
- [ ] **Step 3:** item 2. Create `podman network create --internal ygg-spike`, run a container on it with
      `-p 127.0.0.1:18088:80` serving any HTTP answer, and `curl 127.0.0.1:18088` from the host. Record whether
      it answers. If not, repeat with a second, non-internal network added, and record that.
- [ ] **Step 4:** item 3. Start the founder's host `llama-server` with `--models-preset` on a two-section INI
      (Qwen, and the same file under a second name) and `--models-max 1`. Record: the endpoint that lists models
      and the status field; the request that loads one; the key format the INI accepts (long names without
      `--`, and how a flag with no value is written).
- [ ] **Step 5:** item 4. In a scratch sandbox (`ygg sandbox` on a throwaway project), run `opencode run` with
      `OPENCODE_CONFIG_CONTENT` naming an `@ai-sdk/openai-compatible` provider at an unreachable URL. Record
      whether it fails on the URL (bundled) or on fetching the npm package.
- [ ] **Step 6:** item 5. In the spike's network, start a firewall sidecar from the factory image with a
      services file naming a container on `ygg-spike`, and record whether its dnsmasq resolves the name.
- [ ] **Step 7:** write the note, amend the spec where a result differs, open both pull requests.

---

### Task LM-T02: model references, `PaidAPI` by model, and the `models` section

**Files (in `gungnir`):** Modify `schema/factory.go`, `schema/factory.schema.json`, `docs/architecture.md`.
Test: `schema/factory_local_test.go` (new).

**Interfaces:**

- Produces: `schema.LocalModel(model string) (name string, ok bool)`: `ok` when `model` is `local/<name>` and the
  name matches `^[a-z0-9][a-z0-9._-]{0,63}$`.
- Produces: `schema.PaidModel(agent, model string) bool` beside an unchanged `PaidAPI(agent)` (review ruling): false for `claude-code`,
  `scripted`, and any local model. Every caller passes the role's model.
- Produces: `schema.Factory.Models *Models` with `type Models struct{ File string \`yaml:"file"\` }`.
- Produces: `(*Factory).LocalModels() []string`: the sorted distinct names the roles use.

**Acceptance criteria (spec §5.1 items 1 to 4):**

- [ ] `local/x` on a `claude-code` role is refused, naming the role.
- [ ] A local role with `reasoning: low` is refused: "set the effort in the model list".
- [ ] A local role without `models.file`, or with a relative one, is refused.
- [ ] Caps `{tokens, turns}` without `usd` load when the only `opencode` roles are local; adding an
      `openrouter/...` role makes `usd` required again.
- [ ] `PaidAPI("opencode", "local/q")` is false; `PaidAPI("opencode", "openrouter/x")` is true.

**Named test:** `go test ./schema -run 'TestLocal'` in `gungnir`: `TestLocalModelOnlyOnOpencode`,
`TestLocalRoleRefusesReasoning`, `TestLocalRoleNeedsAnAbsoluteModelsFile`, `TestLocalRolesNeedNoUSDCap`,
`TestLocalModelIsNotAPaidAPI`. **Layer:** `gungnir`. **Size:** M. **Depends on:** the design doc merged.

- [ ] **Step 1:** write the five tests with `ParseFactory` on inline YAML; assert the error text names the role.
- [ ] **Step 2:** run them; expect compile failures on `PaidAPI`'s arity and missing `Models`.
- [ ] **Step 3:** implement. `checkCaps` reads `role["model"]` beside `role["agent"]`. The schema gets
      `models: {file}` and keeps `model` a string; the Go checks do the rest.
- [ ] **Step 4:** run `go test ./...`; expect PASS. Update `docs/architecture.md`'s billing line to say a local
      model bills nothing.
- [ ] **Step 5:** commit.

---

### Task LM-T03: the model list and its preset

**Files (in `gungnir`):** Create `schema/models.go`, `schema/models.schema.json`. Test: `schema/models_test.go`.

**Interfaces:**

- Produces: `schema.ParseModels(file string, data []byte) (*ModelList, error)`.
- Produces: `type ModelList struct{ Server ModelServerConfig; Models map[string]LocalModelConfig }`,
  `type ModelServerConfig struct{ Name, Network string; Port, HostPort int; Weights, State string }`
  (YAML `name`, `network`, `port`, `host_port`, `weights`, `state`), `type LocalModelConfig struct{ File string;
  Context, Output int; Args map[string]string; Price Price }`.
- Produces: `(*ModelList).Preset() []byte`: the INI of spec §3.3, sections in sorted order, keys in sorted order,
  in the key format LM-T01 recorded.
- Produces: `(*ModelList).HostURL() string`: `http://127.0.0.1:<host_port>`.

**Acceptance criteria (spec §5.1 items 5 and 6):**

- [ ] A model without `price.input` or `price.output` is refused, naming the model.
- [ ] `args` with `model`, `ctx-size`, `c`, `host`, `port` or `alias` is refused, naming the key.
- [ ] A relative `weights` or `state`, a name or network that fails spec §3.6's pattern, or a port outside 1 to
      65535 is refused.
- [ ] The preset of a two-model list equals the golden file `schema/testdata/models/preset.ini`.

**Named test:** `go test ./schema -run 'TestModels'` in `gungnir`: `TestModelsNeedAPrice`,
`TestModelsRefuseArgsThePresetWrites`, `TestModelsRefuseABadServer`, `TestModelsPresetMatchesTheGoldenFile`.
**Layer:** `gungnir`. **Size:** M. **Depends on:** LM-T01, LM-T02.

- [ ] **Step 1:** write the tests and the golden file by hand from the spike's key format.
- [ ] **Step 2:** run; expect FAIL (undefined).
- [ ] **Step 3:** implement with the same JSON schema then Go checks pattern `ParseFactory` uses.
- [ ] **Step 4:** run `go test ./...`; expect PASS.
- [ ] **Step 5:** commit.

---

### Task LM-T04: `SandboxSpec.Models`

**Files (in `gungnir`):** Modify `sandbox.go`. Test: `sandbox_models_test.go` (new).

**Interfaces:** Produces `gungnir.ModelServer{Network, Name string; Port int}` and `SandboxSpec.Models
*ModelServer`, checked by `SandboxSpec.Validate` (spec §3.6).

**Acceptance criteria:**

- [ ] `Validate` passes a nil `Models` and a valid one, and refuses a bad name, a bad network and port 0.

**Named test:** `go test . -run TestSandboxSpecModels` in `gungnir`. **Layer:** `gungnir`. **Size:** S.
**Depends on:** the design doc merged.

- [ ] **Step 1:** write a table test of the four cases. **Step 2:** run; expect FAIL. **Step 3:** implement.
      **Step 4:** run `go test ./...`; expect PASS. **Step 5:** commit; open the `gungnir` PR with LM-T02 to
      LM-T04.

---

### Task LM-T05: OpenCode on a local model

**Files (in `gleipnir`):** Modify `opencode/opencode.go`, `go.mod` (bump `gungnir`). Test:
`opencode/local_test.go` (new).

**Interfaces:**

- Consumes: `schema.LocalModel` (LM-T02).
- Produces: `opencode.Config.Local *Local` with `type Local struct{ BaseURL string; Context, Output int }`.
- Changes: `New` accepts `local/<name>` when `cfg.Local` and `cfg.Price` are set, and refuses it otherwise.
  `ConfigJSON` writes spec §3.8's provider. `Args` and the model check in `Run` use the provider prefix the agent
  was built with. `Run` asks for `KeyVar` only for OpenRouter. `Result.Provider` is `local` for a local agent.
- Produces: `opencode.LocalProvider = "local"`.

**Acceptance criteria:**

- [ ] The configuration of a local agent names provider `local`, npm `@ai-sdk/openai-compatible`, the base URL,
      the model's `limit {context, output}`, `small_model: local/<name>`, no `apiKey`, no `reasoning`.
- [ ] A local session in the fake sandbox runs with no `OPENROUTER_API_KEY` in the environment.
- [ ] Its usage has the price's cost, `CostEstimated` true, and `Provider` `local`.
- [ ] An OpenRouter agent's configuration and arguments are byte for byte as before (existing tests pass
      untouched).
- [ ] If LM-T01 found that the provider is fetched from npm, the factory Containerfile installs it, and a test in
      `sandbox/images_test.go` says so.

**Named test:** `go test ./opencode -run 'TestLocal'`: `TestLocalConfigNamesTheLocalProvider`,
`TestLocalSessionNeedsNoOpenRouterKey`, `TestLocalSessionCostsTheListPrice`, `TestLocalNeedsAPriceAndAServer`.
**Layer:** `gleipnir`. **Size:** M. **Depends on:** LM-T02, LM-T03.

- [ ] **Step 1:** write the four tests with the package's existing fake runner and a recorded `step_finish`
      stream.
- [ ] **Step 2:** run; expect FAIL. **Step 3:** implement. **Step 4:** run `go test ./...`; expect PASS.
- [ ] **Step 5:** commit.

---

### Task LM-T06: the sandbox joins the model network

A `guardrail-change`: the founder approves this PR.

**Files (in `gleipnir`):** Modify `sandbox/config.go`, `sandbox/validate.go`, `sandbox/driver.go`. Test:
`sandbox/models_test.go` (new), `sandbox/integration_models_test.go` (new, `//go:build sandbox`).

**Interfaces:**

- Consumes: `gungnir.SandboxSpec.Models` (LM-T04).
- Changes: `network` gets `External bool` (`external`) and `Name string` (`name`). `Generate` adds the network
  `models` and the services line of spec §3.7. `Validate` accepts exactly that external network and nothing else
  external.
- Produces: `(*Driver) checkModelNetwork(ctx context.Context, name string) error`, called by `Up` when
  `spec.Models` is set: runs `podman network inspect --format '{{.Internal}}' <name>` and refuses anything but
  `true`.

**Acceptance criteria (spec §5.3 items 1, 4, 5; §5.2 item 4 at this layer):**

- [ ] A spec with `Models` generates the external network, the firewall on it, and the line `<Name> <Port>` in
      the services file; the work container's settings are unchanged.
- [ ] A spec without `Models` generates exactly what it did before (golden comparison with `main`).
- [ ] `Validate` refuses a compose file with any other external network.
- [ ] `Up` refuses a network whose inspect says `false`, before compose runs.
- [ ] Integration: with a stub server container on an internal network, the work container reaches `<Name>:<Port>`
      and does not reach `<Name>:8080` or `example.com`.

**Named test:** `go test ./sandbox -run 'TestModels'`: `TestModelsNetworkIsGenerated`,
`TestNoModelsGeneratesWhatItDidBefore`, `TestValidateRefusesAnotherExternalNetwork`,
`TestUpRefusesANetworkThatIsNotInternal`; and `go test -tags sandbox ./sandbox -run
TestIntegrationModelNetwork` on the real engine. **Layer:** `gleipnir`. **Size:** M. **Depends on:** LM-T04.

- [ ] **Step 1:** write the unit tests (the driver's `run` is faked as in `driver_test.go`) and the integration test.
- [ ] **Step 2:** run the unit tests; expect FAIL. **Step 3:** implement.
- [ ] **Step 4:** run `go test ./...`; expect PASS. Run the integration test through `scripts/ygg-engine.sh run
      --folder <dir> -- go test -tags sandbox ./sandbox -run TestIntegrationModelNetwork`; expect PASS.
- [ ] **Step 5:** commit.

---

### Task LM-T07: the model gate and the server image

A `guardrail-change`: the founder approves this PR.

**Files (in `gleipnir`):** Create `sandbox/assets/modelgate/main.go` (package `main`, standard library only),
`sandbox/assets/Containerfile.models`, `sandbox/assets/models-entrypoint.sh`, `sandbox/models.go`. Modify
`sandbox/assets.go`. Test: `sandbox/modelgate_test.go`, `sandbox/models_image_test.go`.

**Interfaces:**

- Produces: the program `ygg-modelgate -listen ADDR -upstream URL -allow FILE` (spec §3.5), streaming with
  `httputil.ReverseProxy` and `FlushInterval: -1`.
- Produces: `sandbox.ModelsImage() string`: `localhost/ygg-models:<hash>`, the hash of the Containerfile, the
  entrypoint and the gate's source.
- Produces: `(*Driver) BuildModels(ctx context.Context, cudaArch string) (string, error)`: builds the image from the
  embedded files and returns its tag.

**Acceptance criteria (spec §3.4, §3.5, §5.3 items 2 and 3 at this layer):**

- [ ] The gate passes `POST /v1/chat/completions` for the allowed model to the upstream, and streams it: the test's
      upstream writes two chunks with a pause, and the client reads the first before the second is written.
- [ ] It answers 403 for another model, for `POST /models/load`, `GET /slots`, `GET /metrics` and `GET /props`; 413
      above 32 MiB; 400 for a body that is not JSON; 503 when the allow file is missing.
- [ ] It reads the allow file on each request, so a new run's model needs no restart.
- [ ] The Containerfile pins every base image by digest, checks out llama.cpp at `4c3c581`, and takes
      `CUDA_ARCH` (default `89`).
- [ ] `ModelsImage` changes when any of the three embedded files changes.

**Named test:** `go test ./sandbox -run 'TestModelGate|TestModelsImage'`: `TestModelGatePassesTheAllowedModel`,
`TestModelGateStreams`, `TestModelGateRefuses` (table), `TestModelGateRereadsTheAllowFile`,
`TestModelsImageTagFollowsItsFiles`, `TestModelsContainerfilePinsItsBases`. The gate tests build the asset with
`go build` into `t.TempDir()`. **Layer:** `gleipnir`. **Size:** M. **Depends on:** LM-T01.

- [ ] **Step 1:** write the tests. **Step 2:** run; expect FAIL.
- [ ] **Step 3:** implement the gate, the entrypoint (start both programs; exit when either exits), the
      Containerfile and `BuildModels`, after the pattern of `BuildFactory` in `images.go`.
- [ ] **Step 4:** run `go test ./...`; expect PASS. **Step 5:** commit; open the `gleipnir` PR with LM-T05 to LM-T07.

---

### Task LM-T08: agents, billing and metrics in Odin

**Files (in `odin`):** Modify `go.mod` (bump `gungnir`, `gleipnir`), `internal/agents/agents.go`,
`internal/engine/session.go`, `internal/metrics/collect.go`, `internal/metrics/render.go`,
`internal/metrics/types.go`. Test: `internal/agents/agents_local_test.go`, `internal/metrics/local_test.go`,
the existing billing test in `internal/engine`.

**Interfaces:**

- Consumes: `schema.PaidModel(agent, model)`, `opencode.Config.Local`, `schema.ModelList` (LM-T02, LM-T03, LM-T05).
- Changes: `agents.New(role schema.Role, configDir string, o Options)` with `Options.Models *schema.ModelList`:
  for a local role it fills `opencode.Config.Local` from the list (`BaseURL` `http://<name>:<port>/v1`) and
  `Price` from the role's `price`, else the list's.
- Changes: `agents.Hosts(agent, model string) []string`: nil for a local model.
- Changes: `billed(adapter, model string, u gungnir.Usage)` and `sessionUsage` call `PaidModel` with the model.
- Produces: `metrics.Usage.LocalSessions int` (JSON `local_sessions`), counted where the event's provider is
  `local`; `render` prints `N sessions on local models` when N > 0.

**Acceptance criteria (spec §5.2 item 5):**

- [ ] A local role's adapter gets the list's price, and a role's `price` overrides it.
- [ ] A local session's spend has `BilledUSD` 0 and its full `CostUSD`; an OpenRouter session in the same run
      bills.
- [ ] Metrics of a recorded ledger with one local and one OpenRouter session: billed is the OpenRouter cost only;
      `LocalSessions` is 1; the rendered text has the line.

**Named test:** `go test ./internal/agents ./internal/engine ./internal/metrics -run 'Local'`:
`TestNewLocalRoleTakesTheListPrice`, `TestLocalHostsAreNone`, `TestLocalSessionBillsNothing`,
`TestMetricsCountLocalSessions`. **Layer:** `odin`. **Size:** M. **Depends on:** LM-T02, LM-T05.

- [ ] **Step 1:** write the tests; for metrics, a ledger fixture under `internal/metrics/testdata/local/`.
- [ ] **Step 2:** run; expect FAIL. **Step 3:** implement; update every caller of `PaidAPI` and `Hosts`
      (`git grep -n 'PaidAPI(\|agents.Hosts('`; callers move to `PaidModel`).
- [ ] **Step 4:** run `go test ./...`; expect PASS. **Step 5:** commit.

---

### Task LM-T09: the model server client

**Files (in `odin`):** Create `internal/models/models.go`. Test: `internal/models/models_test.go`.

**Interfaces:**

- Produces: `type Server interface{ Ready(ctx context.Context, name string) error }` and
  `models.New(list *schema.ModelList, client *http.Client) Server`.
- `Ready`: GET the list endpoint at `list.HostURL()` (endpoint from LM-T01); refuse when it does not answer
  ("start it: scripts/ygg-models.sh start") or lacks `name`; write `<state>/allowed` atomically (temp file and
  rename); POST the load request; poll every second until the status is loaded, up to 300 seconds.

**Acceptance criteria (spec §3.9):**

- [ ] Against an `httptest` server: a server that is down, a list without the model, and a load that never
      finishes each give an error that names the model and the cause.
- [ ] The allow file holds the name and a newline before the load request is sent.
- [ ] An already loaded model returns at once, without a load request.

**Named test:** `go test ./internal/models`: `TestReadyRefusesAServerThatIsDown`, `TestReadyRefusesAMissingModel`,
`TestReadyWritesTheAllowFileFirst`, `TestReadySkipsALoadedModel`, `TestReadyTimesOut` (a short timeout set by the
test). **Layer:** `odin`. **Size:** S. **Depends on:** LM-T03.

- [ ] **Step 1:** write the tests. **Step 2:** run; expect FAIL. **Step 3:** implement; the timeout is a field the
      test lowers. **Step 4:** run; expect PASS. **Step 5:** commit.

---

### Task LM-T10: the run's checks and the sandboxes' model network

A `guardrail-change`: the founder approves this PR.

**Files (in `odin`):** Modify `internal/run/prepare.go`, `internal/run/run.go`, `internal/run/sandbox.go`. Test:
`internal/run/models_test.go` (new).

**Interfaces:**

- Consumes: `models.Server` (LM-T09), `gungnir.ModelServer` (LM-T04), `agents.Options.Models` (LM-T08).
- Changes: `Prepare` loads the list when the config has `models.file`, passes it to `agents.New`, refuses a graph
  whose roles name two local models or one the list lacks, and sets `SandboxSetup.Models *gungnir.ModelServer`
  when a graph role is local.
- Changes: `Start` calls `Ready` after `Prepare` and before `record`, so a refusal leaves no run folder. `OpenWith`
  calls it after its own checks. Tests replace the server with a hook, like `newSandbox`.
- Changes: `Runner` and `ScratchRunner` set `SandboxSpec.Models` from `SandboxSetup.Models`. `snapshotRunner`,
  the grader and `cli/deps.go` do not.

**Acceptance criteria (spec §5.2 items 1 to 4):**

- [ ] A graph with a local planner and a local reviewer on different models is refused, naming both.
- [ ] A start with a server that is down returns the error and leaves no `.ygg/runs/<id>` folder.
- [ ] A resume calls `Ready` with the run's model before the first session.
- [ ] A resume whose model is gone from the list is refused, naming the model.
- [ ] A leaf and a scratch sandbox spec of a local run hold `Models`; a snapshot spec does not; a run with no local
      role holds it nowhere and never calls `Ready`.

**Named test:** `go test ./internal/run -run 'TestLocal'`: `TestLocalRunRefusesTwoModels`,
`TestLocalStartLeavesNothingWhenTheServerIsDown`, `TestLocalResumeLoadsTheModel`, `TestLocalResumeRefusesAModelGoneFromTheList`,
`TestLocalSandboxesHoldTheModelNetwork`, `TestRunWithoutLocalRolesIsUnchanged`. **Layer:** `odin`. **Size:** M.
**Depends on:** LM-T06, LM-T08, LM-T09.

- [ ] **Step 1:** write the tests with the package's fake sandbox and a fake `models.Server`.
- [ ] **Step 2:** run; expect FAIL. **Step 3:** implement. **Step 4:** run `go test ./...`; expect PASS.
- [ ] **Step 5:** commit.

---

### Task LM-T11: `ygg models` and `ygg doctor`

**Files (in `odin`):** Create `internal/cli/models.go`. Modify `internal/cli/cli.go`, `internal/cli/doctor.go`,
`docs/architecture.md`. Test: `internal/cli/models_test.go`, `internal/cli/doctor_models_test.go`.

**Interfaces:**

- Produces: `ygg models preset FILE` (the preset on stdout), `ygg models server FILE` (`KEY=value` lines:
  `NAME`, `NETWORK`, `PORT`, `HOST_PORT`, `WEIGHTS`, `STATE`, each value checked by `ParseModels`, so the lines
  are safe for a shell to read), `ygg models build [--cuda-arch N]` (`Driver.BuildModels`; prints the tag).
- Changes: `ygg doctor` adds `checkModels`: for each local role, FAIL when the list lacks the model; WARN when the
  server does not answer or the network is not internal.

**Acceptance criteria:**

- [ ] `ygg models server` of the example list prints the six lines in that order.
- [ ] `ygg models preset` prints the golden preset of LM-T03.
- [ ] `ygg doctor` on a config with a local role and no server prints the WARN with the start command.

**Named test:** `go test ./internal/cli -run 'TestModels|TestDoctorModels'`: `TestModelsServerPrintsShellLines`,
`TestModelsPresetPrintsTheIni`, `TestDoctorModelsWarnsWhenTheServerIsDown`, `TestDoctorModelsFailsOnAMissingModel`.
**Layer:** `odin`. **Size:** M. **Depends on:** LM-T07, LM-T09, LM-T10.

- [ ] **Step 1:** write the tests. **Step 2:** run; expect FAIL. **Step 3:** implement.
- [ ] **Step 4:** run `go test ./...`; expect PASS. **Step 5:** commit; open the `odin` PR with LM-T08 to LM-T11.

---

### Task LM-T12: `ygg-models.sh` and the qwen scripts

**Files (in `ouroboric`):** Create `scripts/ygg-models.sh`, `scripts/testdata/models/models.example.yaml`,
`scripts/tests/ygg-models.test.sh`. Modify `scripts/qwen-lib.sh`, `scripts/tests/qwen-*.test.sh`, `AGENTS.md`
(the scripts table). Delete `scripts/qwen-local.sh`, `scripts/tests/qwen-local.test.sh`.

**Interfaces:**

- Produces: `scripts/ygg-models.sh [--models FILE] start|stop|status|load NAME` (spec §3.10). `start` builds the
  image when `ygg models build`'s tag is missing, creates the internal network when it is absent, writes the
  preset into `state`, and runs the container (spec §3.4, with LM-T01's answer on the published port). `status`
  prints `running on http://127.0.0.1:<host_port>, loaded: <name|none>` and exits 0, or exits 3. It uses
  `scripts/ygg-engine.sh` for the engine and never sets `CONTAINER_HOST`.
- Changes: `qwen-lib.sh`'s `qwen_url` and `qwen_require_server` read `ygg-models.sh status`.

**Acceptance criteria:**

- [ ] With fake `podman` and `ygg` on `PATH`, `start` runs `podman run` with the GPU device, both read-only mounts,
      the network and `127.0.0.1:<host_port>`, and no other published port.
- [ ] `start` with a model list that names no existing weights folder fails before any `podman` call.
- [ ] `status` exits 3 when the container is absent.
- [ ] The qwen tests pass against a fake `ygg-models.sh`.
- [ ] The example list names no local path and passes `ygg models server`.

**Named test:** `scripts/tests/ygg-models.test.sh`, `scripts/tests/qwen-opencode.test.sh`,
`scripts/tests/qwen-claude.test.sh`, `scripts/tests/qwen-measure.test.sh`. **Layer:** `ouroboric`. **Size:** M.
**Depends on:** LM-T11, LM-T15. `start` runs `ygg-gpu.sh check` first (spec §3.10).

- [ ] **Step 1:** write `ygg-models.test.sh` in the style of `qwen-local.test.sh` (fakes on `PATH`, a temp HOME).
- [ ] **Step 2:** run; expect FAIL. **Step 3:** implement; port the header's style from `qwen-local.sh`.
- [ ] **Step 4:** run all four tests and `shellcheck scripts/ygg-models.sh scripts/qwen-lib.sh`; expect PASS.
- [ ] **Step 5:** commit.

---

### Task LM-T15: `ygg-gpu.sh`, so the GPU setup survives a driver update or a new machine

Added 2026-10-25 at the founder's request, after the spike (item 1) found that the toolkit and the CDI spec must
be in the Podman machine's distro, which has no systemd.

**Files (in `ouroboric`):** Create `scripts/ygg-gpu.sh`, `scripts/tests/ygg-gpu.test.sh`. Modify `AGENTS.md` (the
scripts table).

**Interfaces:** `scripts/ygg-gpu.sh setup|check [--machine NAME]` (spec §3.10). NAME defaults to the machine
`podman machine inspect` names as the default one. `check` exits 0 and prints `gpu: <name> <memory>`, exits 3 with
`missing: toolkit|spec|stale spec` and the command that fixes it, or exits 2 when the engine does not answer.
`setup` is idempotent and pins the toolkit to `1.20.1` and the CUDA image to
`docker.io/nvidia/cuda@sha256:59436e8ac61921052d8f420be8b8cb8b117f1d7cc643397a289e37aaa0b83ea1`.

**Acceptance criteria:**

- [ ] With fake `wsl.exe`, `podman` and `ygg-engine.sh` on `PATH`: `check` reports each of the three missing
      states, and `setup` installs only what is missing (no `dnf` call when the toolkit is there; no `cdi generate`
      when the spec is current).
- [ ] A spec that names a driver store folder that no longer exists is stale, and `setup` generates it again.
- [ ] `setup` on an engine that is not a Podman machine on WSL2 refuses with a message, and changes nothing.
- [ ] The script never runs `sudo`, and never starts, stops or re-creates the machine.
- [ ] **Founder:** on the real machine, `scripts/ygg-gpu.sh check` prints the RTX 4090.

**Named test:** `scripts/tests/ygg-gpu.test.sh`. **Layer:** `ouroboric`. **Size:** S. **Depends on:** none.

- [ ] **Step 1:** write the test with the fakes, in the style of `scripts/tests/qwen-local.test.sh`.
- [ ] **Step 2:** run; expect FAIL. **Step 3:** implement; the header follows the other scripts' style.
- [ ] **Step 4:** run the test and `shellcheck scripts/ygg-gpu.sh`; expect PASS. **Step 5:** commit.

---

### Task LM-T13: local roles in the proof and smoke scripts

**Files (in `ouroboric`):** Modify `scripts/ygg-proof-run.sh`, `scripts/ygg-smoke-real.sh`,
`scripts/testdata/proof/factory.proof.example.yaml`, `AGENTS.md`. Test: `scripts/tests/ygg-proof-run.test.sh`,
`scripts/tests/ygg-smoke-real.test.sh`.

**Interfaces:** `--planner|--implementer|--reviewer opencode:local/<name>` and `--models FILE`; the config gets
`models: {file}`; `OPENROUTER_API_KEY` and the `usd` lines only when a role is on OpenRouter. Defaults unchanged.

**Acceptance criteria:**

- [ ] `--reviewer opencode:local/qwen3.8-27b --models F --dry-run` writes a config with the local reviewer and
      `models.file`, asks for no OpenRouter key, and has no `usd` line when the other roles are `claude-code`.
- [ ] A local role without `--models` is refused before anything runs.
- [ ] The default roles produce the same config as before (existing tests pass untouched).

**Named test:** `scripts/tests/ygg-proof-run.test.sh`, `scripts/tests/ygg-smoke-real.test.sh`. **Layer:**
`ouroboric`. **Size:** S. **Depends on:** LM-T12.

- [ ] **Step 1:** add the three cases to each test. **Step 2:** run; expect FAIL. **Step 3:** implement.
- [ ] **Step 4:** run both tests and `shellcheck`; expect PASS. **Step 5:** commit; open the `ouroboric` PR with
      LM-T12 and LM-T13.

---

### Task LM-T14: the proof run, pointers and the living spec

**Files (in `yggdrasil`):** Modify the submodule pointers, `docs/2-engineering/system/` (the living spec), this
plan's status. **Layer:** `yggdrasil`. **Size:** S. **Depends on:** LM-T13 merged.

**Acceptance criteria (design §3.4):**

- [ ] **Founder:** a proof run with `--reviewer opencode:local/qwen3.8-27b` completes; its report shows the
      reviewer's sessions as local with a notional cost; the dollar caps hold what the OpenRouter and Claude Code
      roles billed only.
- [ ] With no run going, `scripts/qwen-opencode.sh` answers through the same server.
- [ ] A second model added to the founder's list loads for a run that names it, and the next Qwen run loads Qwen
      back, with no code or image change.
- [ ] The living spec describes local models; the pointers name the merged commits.

**Named test:** the proof run's `report.txt` and `ygg metrics` output, kept with the run. **Depends on:** LM-T13.

- [ ] **Step 1 (founder):** `scripts/ygg-models.sh start`, then `scripts/ygg-proof-run.sh --name local-1 --reviewer
      opencode:local/qwen3.8-27b --models ~/.config/ygg/models.yaml --dry-run`, then without `--dry-run`.
- [ ] **Step 2:** move the pointers, write the living spec's section, set this plan to `implemented`, open the PR.
