---
title: Delta for the local models setup
status: draft
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
- §3.10: `ygg-models.sh setup` and `ygg-models.sh clean`, as the proposal describes. `clean` MUST NOT delete a
  file that the list's `download` does not name.

## Modified

- §3.2, the example: the model names its files directly (`Qwen3.8-27B-UD-Q4_K_M.gguf`,
  `/models/MTP/mtp-Qwen3.8-27B-Q4_0.gguf`) and their `download`.

## Removed

None.
