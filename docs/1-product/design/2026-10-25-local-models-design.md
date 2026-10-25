---
title: Local models design doc
status: accepted
date: 2026-10-25
related: [../charter.md, 2026-10-11-yggdrasil-v0-design.md, ../../2-engineering/specs/2026-10-11-yggdrasil-v0-spec.md, ../../2-engineering/changes/2026-10-20-role-reasoning/proposal.md, https://github.com/ouroboric-dev/ouroboric/blob/main/docs/5-research/2026-10-19-local-qwen-design.md]
style: direction
---

# Local models design doc

| | |
| --- | --- |
| **Author** | the founder, with Claude Code (Opus 5.5), from a brainstorming session held 2026-10-25. Accepted by the founder 2026-10-25 |
| **Within** | the v0 design's sandbox and budget rules. The sandbox part is a `guardrail-change` (§6) |
| **Engineering specs** | one change proposal, or a spec if the builder finds it bigger (§8) |
| **Process** | tier 3, [spec-driven development](https://github.com/ouroboric-dev/ouroboric/blob/main/docs/4-ways-of-working/spec-driven-development.md) |

## 1. Summary

A role in `factory.yaml` can name a **local model**: a model that runs on the operator's own GPU
instead of a paid API. Today every `opencode` role runs on OpenRouter, and each development run costs
money. The founder already runs Qwen 3.8 27B on the local RTX 4090 for interactive work, but no run
can use it.

This design adds three things:

1. **One shared model server.** A long-lived container runs `llama-server` with the GPU. It serves
   every model on the operator's **model list**, keeps one loaded at a time, and swaps on request.
2. **A path from the sandbox to that server, and to nothing else.** Each leaf's sandbox reaches the
   server's inference endpoints over an internal network. The firewall opens no new outside host.
3. **The same server for interactive use.** The founder's OpenCode and Claude Code sessions on the
   host use it through a port on `127.0.0.1`, in place of today's `scripts/qwen-local.sh` server.

A model is an entry in the list. Adding a model needs no code change.

## 2. Why

- **Development runs cost money for nothing.** The factory is still in development. Most runs end in
  a setup fault, and each one pays OpenRouter. Hosted Qwen 3.8 27B costs money; the same model runs
  free on the 4090.
- **Odin only reaches OpenRouter.** `gleipnir/opencode/opencode.go` refuses any model that is not
  `openrouter/<model>`, and the sandbox firewall opens `openrouter.ai` alone. A local model needs a
  change to the adapter and to the sandbox.
- **The local setup is a second, separate setup.** `scripts/qwen-local.sh` runs a host binary on
  `127.0.0.1:8088`. A sandbox can't reach it, and its tuning (reasoning effort, multi-token
  prediction, cache limits, chat template) lives only in that script. The founder wants **one setup
  for every use**.
- **Models will change.** Qwen is the first local model, not the last. The design must make a new
  model a matter of configuration.
- **OpenRouter can't route to a local model.** It routes only to the providers it has signed up. A
  proxy that pretends to be `openrouter.ai` would need a certificate authority inside the sandbox,
  which defeats the sandbox.

## 3. Goals, non-goals and anti-goals

### 3.1 Goals

1. A role with `agent: opencode` can name a local model in `factory.yaml`. Other roles stay as they
   are, so one run can mix local and OpenRouter roles.
2. The operator chooses which roles are local by editing `factory.yaml` alone. The first use is the
   roles that run on OpenRouter today.
3. One model server serves the sandboxes and the host's interactive sessions.
4. The operator adds, removes or changes a model by editing the model list. No code changes.
5. A run that uses a local model fails before its first session when the server is down or does not
   offer the model.
6. Every existing `factory.yaml` behaves as it does today.
7. A run on local models still shows what it would have cost on OpenRouter, so runs stay comparable.
   The ledger marks each local session as local, and the dollar caps do not count it.

### 3.2 Non-goals

- **Two models loaded at once.** The 4090 has 24 GB, and Qwen 3.8 27B takes most of it. The server
  keeps one model loaded. Swapping between runs is fine; swapping within a run is not supported.
- **A server per sandbox.** It would load the model once per leaf and needs one copy in VRAM per
  sandbox.
- **Local models for `claude-code` roles.** `scripts/qwen-claude.sh` shows it can work. It is a
  later change.
- **Agents inside the server's container.** Each leaf's agent stays in its own work container.
- **Odin starting or stopping the server.** The operator runs it, as with the container engine.
- **Arbitration between a run and interactive use.** One model at a time is a rule the operator
  follows, not one the server enforces (§5.5).
- **Remote GPUs or hosted inference other than OpenRouter.**

### 3.3 Anti-goals

These would make the design a failure even if a run works:

- **A wider sandbox.** The work container must reach no new outside host, and no endpoint of the
  server other than inference.
- **The GPU or the weights in a work container.** Only the server's container has them.
- **A local path or account name in a committed file.** The model list holds paths to weights. It is
  operator config and goes in a gitignored place, with a generic example committed (umbrella
  invariant 9).
- **A run that swaps models halfway and burns its time reloading.**
- **A second copy of the tuning.** The server's settings for a model live in one place.

### 3.4 Success criteria

1. A proof run with `--reviewer opencode:local/qwen3.8-27b` (the syntax is the builder's) completes,
   and OpenRouter shows no spend for the reviewer's sessions.
2. With no run going, `scripts/qwen-opencode.sh`, or its successor, talks to the same server.
3. With a second model added to the list, a run whose roles name it loads it, and the next run on
   Qwen loads Qwen back, with no code or image change.
4. The sandbox escape tests pass, plus new ones: from a work container, the server's load, unload
   and slot endpoints fail, and every other address on the shared network fails.
5. Every `factory.yaml` in `odin/testdata` loads and runs as before.
6. The run's report shows each local role's tokens, its notional OpenRouter cost, and that it ran
   locally. The per-run and per-day dollar caps hold the same amounts as before the run.

## 4. Context and constraints

- **Hardware.** One RTX 4090 with 24 GB, under WSL2. Qwen 3.8 27B at its current quantization loads
  about 17 GB of weights. A load takes tens of seconds from the page cache and longer from disk
  (`qwen-local.sh` allows 300 seconds).
- **GPU in Podman is not set up.** The host has no CDI specification (`/etc/cdi` is absent) and no
  `nvidia-ctk`. Setting up the NVIDIA container toolkit is a prerequisite and a step for the operator.
- **llama.cpp already swaps models.** `llama-server` started without `--model` runs as a **router**.
  `--models-preset` takes an INI file with one section per model, and `--models-max 1` keeps one
  loaded and evicts it when another is asked for. The founder's build (`0.7.0-dev`, commit `4c3c581`)
  has these flags.
- **The sandbox already has services.** A leaf's realm can start containers beside the work
  container (`gungnir.Service`). They sit on an internal compose network, and the firewall opens
  their listed ports by name (`gleipnir/sandbox/config.go`, `assets/egress.sh`). Today each sandbox
  starts its own; nothing is shared between sandboxes.
- **Hosts come from the roles.** `odin/internal/run/prepare.go` collects the model APIs of the run's
  roles, and every sandbox of the run opens them (`agents.Hosts`).
- **Budget caps.** A run must set token and turn caps. `gungnir`'s schema counts every `opencode`
  role as paid, so `budget.*.usd` is required whenever one is present, and the adapter refuses a
  session that reports tokens with zero cost, so that the dollar cap is never blind. A role's `price`
  already lets the operator set a price for a tool that reports none.
- **Role reasoning has landed** (gleipnir#17): a role can set `reasoning:`. A local model's
  server-side effort and that setting must not fight.
- **The leaves on the founder's machine are behind.** `gleipnir`, `gungnir` and `odin` are 9 to 22
  commits behind `origin/main` (2026-10-25). The plan starts from `origin/main`.

## 5. How it works

### 5.1 The model list

The operator keeps a **model list** in their own config, outside every committed file. Each entry
has:

- a **name**, such as `qwen3.8-27b`, which roles and interactive tools use;
- the **weights** file, and any draft model for multi-token prediction;
- the **server settings**: context size, reasoning effort, cache limits, chat template and the other
  flags `qwen-local.sh` sets today;
- its **OpenRouter equivalent**: the price in dollars per million tokens of the same model on
  OpenRouter, so a run can say what it would have cost (§5.6).

One file holds the list. The server's preset file is made from it. A committed example lists Qwen
3.8 27B with the settings `qwen-local.sh` uses, and no local path.

### 5.2 The model server

- One container, from a pinned image, runs `llama-server` as a router with `--models-max 1`.
- It has the GPU and a **read-only** mount of the folder that holds the weights.
- It joins one internal network that the sandboxes join, and publishes a port on `127.0.0.1` for the
  host. It needs no route to the internet.
- A script in `ouroboric/scripts/` starts it, stops it, says which model is loaded, and loads a
  model on request. It replaces the server half of `qwen-local.sh`. `qwen-opencode.sh` and
  `qwen-claude.sh` point at it.

### 5.3 In a run

- A role names a local model, for example `model: local/qwen3.8-27b`. The `opencode` adapter writes an
  OpenCode provider that points at the server by its name on the internal network, with no API key.
- When a run has a local role, Odin checks before any sandbox starts:
  1. all its local roles name **the same** model, or it refuses the run;
  2. the server answers, and its list holds that model, or it refuses the run with a message that
     names the script to start it;
  3. it asks the server to load the model and waits, so no session's time limit pays for the load.
- Each sandbox of the run joins the shared network. The firewall opens the server's inference port,
  as it opens a service's port today. A run with no local role does not join the network.
- A local role's sessions count toward the token and turn caps as usual, and never toward the dollar
  caps (§5.6).
- Paused runs: when a run resumes, Odin repeats the checks and loads the model again.
- The grader's and the snapshot's sandboxes do not join the shared network. Only a sandbox that runs
  an agent session needs a model, and no agent runs in either: they get no model host today either.
  The grader holds the hidden suite and the score key, and a shared server that later agent sessions
  use would be a path from it to them. If a node ever runs an agent in a snapshot, that sandbox joins
  the network as it would get `openrouter.ai`.
- `ygg doctor` reports a local role whose server is down, or whose model is not on the list.

### 5.4 Interactive use

The founder's OpenCode and Claude Code sessions use the published port, as they use `127.0.0.1:8088`
today. A request for a model that is not loaded swaps it in.

### 5.5 One model at a time

The server holds one model and takes one request at a time. The founder does not work interactively
while a run is going. The server and its settings assume that: one slot, the whole context for it.

If an interactive session asks for model B during a run on model A anyway, the server swaps, and the
run's next request swaps back. The run still works, but slowly, and a session may run out of time.
Odin does not watch for this. The script's status says which model is loaded.

### 5.6 Cost

A run on local models must stay comparable with a run on OpenRouter, and must not spend the dollar
budget.

- The ledger records each local session as **local**, with its tokens and turns as usual.
- Each local session also gets a **notional cost**: its tokens at the model's OpenRouter equivalent
  price (§5.1). A role's `price` overrides it. The notional cost is marked as notional everywhere it
  appears.
- The dollar caps, per run and per day, never count a notional cost. The token and turn caps count
  local sessions like any other.
- The run's report and `ygg metrics --compare` show the notional cost beside real costs, so a local
  run and an OpenRouter run compare on the same terms.
- A run whose only `opencode` roles are local needs no `budget.*.usd`. A run with a paid role still
  needs it.
- The adapter's refusal of a session with tokens and zero cost stays for OpenRouter roles. A local
  session is exempt, because its cost comes from the notional price, not from the tool.

## 6. Security

This design changes the sandbox, so it is a `guardrail-change`, and the founder approves it here.

- **No new outside host.** The firewall opens one port on one name on an internal network. The
  `openrouter.ai` rule is unchanged for OpenRouter roles.
- **Inference only.** A work container must not load or unload models, read the server's slots
  (which can hold another leaf's prompts), or reach its metrics or properties. Disabling these in
  `llama-server` is not enough for load and unload, which the router needs. Something between the
  sandbox and the server must allow only the inference endpoints. How is the builder's (§8).
- **The run's model only.** In router mode an inference request loads the model it names. A request
  from a sandbox may name only the run's model, so code in a work container cannot swap the GPU to
  another model. Odin tells the filter which model the run uses when it loads it (§5.3).
- **Leaves stay apart.** Several sandboxes share the network. Each firewall drops input that is not
  a reply, so one leaf cannot reach another. The escape tests must prove it.
- **The server holds no secret.** It has no API key and no route out. The weights are read-only.
- **The GPU stays in one container.** No work container gets a device.
- **Prompt privacy.** A local model sends nothing outside the machine, so it meets `privacy: strict`.

## 7. Decisions

**Decided 2026-10-25:** Local models run in one shared `llama-server` container, not one per sandbox
and not behind a proxy that pretends to be OpenRouter.

**Decided 2026-10-25:** The server keeps one model loaded. Swapping between runs is fine; a run uses
one local model.

**Decided 2026-10-25:** Models are entries in a model list in the operator's config. A new model needs
no code change.

**Decided 2026-10-25:** The first local roles are the ones on OpenRouter today, and `factory.yaml`
decides which roles are local.

**Decided 2026-10-25:** The host's interactive sessions use the same server through a port on
`127.0.0.1`, but not while a run is going. Agents never run in the server's container.

**Decided 2026-10-25:** A local session counts toward the token and turn caps, never toward the dollar
caps. The ledger marks it as local, and its notional OpenRouter cost is recorded so runs stay
comparable.

**Decided 2026-10-25 (Claude's call, for the founder to check):** A sandbox may ask the server only for
the run's model. The proof and smoke scripts keep their OpenRouter defaults, and a local model is
chosen with their role flags, so existing baselines stay comparable. The server runs on the same
rootless Podman engine as the sandboxes, so they can share a network.

## 8. Left to the builder

The engineering spec decides these:

- The model name syntax in `factory.yaml` (`local/<name>` is a suggestion), and whether the server's
  address goes in `factory.yaml` or has a fixed default.
- The model list's format and where it lives, and how the preset file is made from it.
- The server image: built from a pinned llama.cpp commit, or a pinned upstream image. The founder's
  tuning (multi-token prediction among it) must work in it.
- How the sandbox reaches only the inference endpoints: a small filter in front of `llama-server`,
  or another way.
- How a sandbox joins the shared network: an external compose network, and how the firewall learns
  the server's name and port.
- Whether the server can publish a port on the host while it sits only on an internal network, or
  needs a second network. It needs no route out either way.
- What happens to `qwen-local.sh`, `qwen-opencode.sh` and `qwen-claude.sh`.
- How `--reviewer`, `--implementer` and `--planner` in `ygg-proof-run.sh` and the smoke scripts accept
  a local model, and stop asking for `OPENROUTER_API_KEY` when no role needs it.
- How a role's `reasoning:` and a model's server-side effort fit together.
- Where the notional cost lives in the ledger and the report, and whether `ygg metrics --compare`
  needs a change to show it.
- How the model list's price is kept current: set by hand from OpenRouter's page, or read from
  OpenRouter's model list by the script.

## 9. Open questions

None.
