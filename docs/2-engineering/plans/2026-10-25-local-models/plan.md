---
title: Local models plan
status: proposed
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
LM-T11 ─► LM-T12 ouroboric: ygg-models.sh and the qwen scripts
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
