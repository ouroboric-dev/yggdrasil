---
title: Local models setup in one command, and its guide
status: draft
date: 2026-10-26
related: [delta.md, tasks.md, ../../specs/2026-10-25-local-models.md, ../../../1-product/design/2026-10-25-local-models-design.md]
style: spec
---

# Local models setup in one command, and its guide

**Proposed 2026-10-26** at the founder's request, after the first setup on the founder's machine took a dense
block of commands. The founder chose: setup downloads the weights, and the guide lives in the operations docs.

## Why

- The first setup took about fifteen commands: the GPU toolkit, linking the weights under a mounted folder,
  writing the model list with `sed`, a separate `ygg`, start, load and the template. Another operator could not
  follow it from the docs.
- The download of the weights is a manual `hf download` in a research how-to, with the file names typed by hand.
- Cleaning up (container, network, image, state) has no command.
- How to use the server from a run, the proof scripts, OpenCode and Claude Code is spread across a spec, a
  research how-to and script headers.

## What changes

- A model in the model list MAY name where its files come from: `download: { repo: <owner>/<name>, revision:
  <commit>, files: [<path in the repo>, ...] }`. `revision` is optional. Each file lands at the same relative path
  under `weights`.
- `ygg models sources FILE` prints one line per file to download: `<model> <repo> <revision or main> <path>`,
  checked like the other output (no spaces or shell characters).
- `scripts/ygg-models.sh setup` does the whole first-time setup, and is safe to run again: the GPU check (and
  `ygg-gpu.sh setup` when needed); the model list from the example when it is missing, with `--weights`,
  `--state` and `--price IN:OUT[:CACHE_READ]`; the download of the missing files (`hf download`, through `uvx`
  when `hf` is not installed); the image when it is missing; start; load; and the chat template when the list
  names one that is missing.
- `scripts/ygg-models.sh clean` stops and removes the container, then the network and the image. `--state`
  also empties the state folder. `--weights` also deletes the downloaded files. Without those flags the weights,
  the state and the list stay.
- A guide, `docs/3-using/operations/local-models.md` (procedure style): first-time setup; start, stop and
  status; switching or adding a model; using it from runs, the proof and smoke scripts, OpenCode and Claude
  Code; after a driver update; cleanup; troubleshooting. The umbrella's research how-to points to it.
- The example list names the files the founder uses, with their source: `unsloth/Qwen3.8-27B-GGUF`,
  `Qwen3.8-27B-UD-Q4_K_M.gguf` and `MTP/mtp-Qwen3.8-27B-Q4_0.gguf`.

## Not in this change

- Looking up OpenRouter's price automatically. The guide says where to read it.
- Downloads from anywhere but Hugging Face.
- A second GPU or a second server.

## Impact

- **Repos:** `gungnir` (the model list), `odin` (`ygg models sources`), `ouroboric` (`setup`, `clean`, the
  example), `yggdrasil` (the guide, this change).
- **Approval points:** none. No guardrail changes: the container, the network and the gate are as before.
- **Risk:** `clean --weights` deletes up to 18 GB. It deletes only the files the list's `download` names, never
  the folder.
