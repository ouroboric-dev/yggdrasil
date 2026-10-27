---
title: Delta for the local models setup
status: implemented
date: 2026-10-26
related: [proposal.md, tasks.md, ../../specs/2026-10-25-local-models.md]
style: spec
---

# Delta: local models spec §3.2, §3.9, §3.10

## Added

- §3.2: a model MAY set `download: { repo, revision, files }`. `repo` MUST match `^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$`.
  Each file MUST be a clean relative path that matches `^[A-Za-z0-9._/+-]+$`. `ParseModels` MUST refuse anything
  else.
- §3.9: `ygg models sources FILE` prints `<model> <repo> <revision> <path>` for each file of each `download`, with
  `main` when no revision is set.
- §3.10: `ygg-models.sh setup` and `ygg-models.sh clean`, as the proposal describes.
  - `clean --weights` MUST NOT delete a file that the list's `download` does not name, except
    `<weights>/.cache/huggingface` (the download's state). It MUST refuse, deleting nothing, when
    `<weights>/.cache` or `<weights>/.cache/huggingface` is a symlink.
  - `clean --state` removes `preset.ini`, `allowed` and their temporary files. It MUST NOT remove the state folder.
  - `clean` MUST refuse, changing nothing, while a container other than the server is on the model network.
  - `setup` MUST NOT stop the server while a container other than the server is on the model network. When it
    must make the chat template (which restarts the server), it MUST refuse before any step while such a
    container is there. If one joins during the setup, `setup` MUST stop before the restart and say that the
    server runs without the template.

## Modified

- §3.2, the example: the model names its files directly (`Qwen3.8-27B-UD-Q4_K_M.gguf`,
  `/models/MTP/mtp-Qwen3.8-27B-Q4_0.gguf`) and their `download`.

## Removed

None.
