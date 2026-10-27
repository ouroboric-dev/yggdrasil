---
title: Two corrections to the local models spec
status: draft
date: 2026-10-27
related: [delta.md, tasks.md, ../../backlog.md, ../../specs/2026-10-25-local-models.md]
style: spec
---

# Two corrections to the local models spec

**Proposed 2026-10-27.** It fixes backlog [B-211](../../backlog.md) and the image tag part of
[B-215](../../backlog.md). The shape below is a proposal; the founder has not decided it.

## Why

- **Quotes in a preset value.** Local models spec §3.2 refuses quotes in an `args` value because "the pinned parser
  would end, trim or split them". The pinned parser does not. In llama.cpp `4c3c581`, `common/preset.cpp`
  (`parse_ini_from_file`) reads a value as every character up to whitespace followed by `#` or `;`, a line break or
  the end of the file, and keeps it as it is; `to_args` passes it as one argument. A quote is a plain character. The
  refusal blocks a JSON value such as `chat-template-kwargs = {"enable_thinking":false}`.
- **The image tag and the CUDA architecture.** §3.4 makes the tag a hash of the Containerfile, the entrypoint and
  the gate's source. `ygg models build --cuda-arch 86` builds for another architecture under the same tag, so the
  next `ygg models image` names an image built for a GPU the operator may not have, and `ygg-models.sh start`
  finds the tag and does not build.

## What changes

1. `ParseModels` allows `"` and `'` inside an `args` value. It still refuses `#`, `;`, a line break, space at
   either end and an empty value. `file` keeps refusing quotes: a file name never needs one.
2. The tag hashes the CUDA architecture too, when it is not the Containerfile's default (`89`). The default build
   keeps today's tag, so the image on the founder's engine stays valid and needs no rebuild. `ygg models image`
   takes `--cuda-arch` as `ygg models build` does, and both print the same tag for the same value.

## Not in this change

- Running the model server as a user other than root (the rest of B-215 stays a backlog item): under rootless
  Podman, root in the container is the operator's user, the container runs with `--cap-drop=ALL` and
  `no-new-privileges`, and another user may not read the weights or the GPU devices. It needs a proof on the real
  engine with the GPU first.
- An architecture setting in the model list or `ygg-models.sh`. The script builds the default.

## Impact

- **Repos:** `gungnir` (`plainValue` for `args`), `gleipnir` (`ModelsImage` takes the architecture), `odin`
  (`ygg models image --cuda-arch`), `yggdrasil` (spec, backlog, pointers).
- **Approval points:** none.
- **Risk:** none for the default build. A value with a quote reaches llama-server as written, as any other value
  does.
