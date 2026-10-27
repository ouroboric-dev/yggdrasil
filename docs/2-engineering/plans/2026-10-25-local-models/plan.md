---
title: Local models plan
status: implemented
date: 2026-10-25
related: [tasks.md, ../../specs/2026-10-25-local-models.md, ../../../1-product/design/2026-10-25-local-models-design.md]
style: spec
---

# Local models plan

**Goal:** an `opencode` role can run on a model from the operator's model list, served by one shared
`llama-server` on the local GPU, with the same server used by the founder's interactive sessions.

**Spec:** [2026-10-25-local-models.md](../../specs/2026-10-25-local-models.md). **Design:**
[2026-10-25-local-models-design.md](../../../1-product/design/2026-10-25-local-models-design.md).

## Order

```text
LM-T02 gungnir: model refs, PaidAPI, factory models section   (no dependency)
LM-T04 gungnir: SandboxSpec.Models                              (no dependency)
LM-T01 spike (founder + agent), LM-T02 ─► LM-T03 gungnir: the model list and its preset
LM-T02, LM-T03 ─► LM-T05 gleipnir: OpenCode on a local model
LM-T04 ─────────► LM-T06 gleipnir: the sandbox joins the model network
LM-T01 ─────────► LM-T07 gleipnir: the gate and the server image
LM-T02, LM-T05 ─► LM-T08 odin: agents, billing and metrics
LM-T03 ─────────► LM-T09 odin: the model server client
LM-T06, LM-T08, LM-T09 ─► LM-T10 odin: the run's checks and the sandboxes' model network
LM-T07, LM-T09, LM-T10 ─► LM-T11 odin: ygg models and ygg doctor
LM-T15 ouroboric: ygg-gpu.sh setup|check                      (no dependency)
LM-T11, LM-T15 ─► LM-T12 ouroboric: ygg-models.sh and the qwen scripts
LM-T12 ─► LM-T13 ouroboric: local roles in the proof and smoke scripts
LM-T13 ─► LM-T14 founder: the proof run, pointers and the living spec
```

The three `gungnir` tasks go in one pull request, and each later leaf bumps `gungnir` in its first task. Odin's
tasks land after the `gleipnir` tasks they consume, and bump it.

## Global constraints

- Plans start from each leaf's `origin/main`, not the founder's local checkouts, which are behind (design §4).
- Every existing `factory.yaml` in `odin/testdata` and `ouroboric/scripts/testdata` loads and behaves as before.
- The model list and any path to weights stay out of every committed file (umbrella invariant 9).
- No task changes the firewall's rules for OpenRouter or Anthropic hosts.
- The sandbox part is a `guardrail-change`. The founder approves the PRs of LM-T06, LM-T07 and LM-T10.

## Risks

| Risk | What happens | Answer |
| --- | --- | --- |
| A spike fact is false (spec §9) | A section of the spec is wrong | LM-T01 runs first, beside LM-T02 and LM-T04, which need none of its facts; its findings amend the spec before LM-T03 and the later tasks start |
| OpenCode fetches the provider package from npm | A local session fails in the sandbox | Spike item 4; if so, LM-T05 bakes the package into the factory image |
| The CUDA build of llama.cpp in the image differs from the host build | Slower, or MTP missing | The image pins the host build's commit `4c3c581` and architecture 89 |
| A run and an interactive session use different models | The server swaps, a session times out | The founder's rule (design §5.5); `ygg-models.sh status` names the loaded model |

## Review focus

1. A config with a local role and an OpenRouter role still needs `usd` caps, and only the OpenRouter sessions bill.
2. A resumed run whose server was restarted, or now has another model loaded, loads the run's model again before
   its first session.
3. A model list edited between runs, so that a run's model is gone: the resume refuses with the model's name.
4. A streamed chat response through the gate arrives in pieces, not all at the end.
5. A run with no local role is unchanged: no model network, no check of the server, no `models` section needed.

## Result

**Implemented 2026-10-27.** All 15 tasks are merged: gungnir #29, #30; gleipnir #26; odin #48; ouroboric #88
(the spike), #89; the spec amendments yggdrasil #118 to #121. The one-command setup and its guide followed as the
change [2026-10-26-local-models-setup](../../changes/2026-10-26-local-models-setup/proposal.md): gungnir #32,
odin #49, ouroboric #90, #91, yggdrasil #123. CI moved to Go 1.26.10 for GO-2026-6809: gungnir #31, gleipnir #27,
odin #47.

LM-T14, on the founder's machine:

- **Proof run 1** (`20261025-113131-8e9cb7`, `client-gallery-lite`) switched its reviewer to `local/qwen3.8-27b` at
  a pause from T012, at effort low, then medium from T013. It ended `done`.
  - 139 local reviewer sessions.
  - Their notional cost is $8.95, at the list's OpenRouter price.
  - $7.99 was billed, all of it by the 84 OpenRouter reviewer sessions of T001 to T011.
  - The local sessions counted toward the token and turn caps and not toward the dollar caps.
- **Interactive use:** with no run going, `qwen-opencode.sh run "Say OK."` and `qwen-claude.sh -p "Say OK."`
  answered through the same server.
- **A second model:** a second list entry was loaded and the server swapped back, with no code or image change.
  The second entry had the same weights under another name. A whole run on a second model was not done.
- **The living spec:** `docs/2-engineering/system/` stays empty until v0 lands (its README). Until then this spec
  and the change's delta describe local models.

Follow-ups found on the way (backlog):

- At medium effort the reviewer hit the reviewer nodes' 20-turn cap 3 times, while still reading. Tell the reviewer
  its budget or keep a last turn for the submit, and log "turn cap reached" rather than `output_refused`.
- OpenCode's openai-compatible provider neither shows nor counts llama-server's `reasoning_content`, so a local
  session reports `reasoning: 0`.
- A sandbox with a running service container fails `Down` (`pod rm` refuses), on main before this work. In run 1
  it failed the grade once.
- The firewall takes the first nameserver as its resolver. It works because aardvark-dns forwards outside names on
  an internal network.
- A `ygg` built by hand stamps `odin unknown`; build with `scripts/ygg-build.sh`.
