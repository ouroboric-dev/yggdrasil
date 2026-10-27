---
title: Delta for the local models changes
status: draft
date: 2026-10-27
related: [proposal.md, tasks.md, ../../specs/2026-10-25-local-models.md]
style: spec
---

# Delta: local models spec §3.2, §3.4 and §3.5

## Added

None.

## Modified

- §3.2, the last sentence of the `args` item. Was: "Values with `#`, `;`, quotes, a line break, or space at either
  end are refused: the pinned parser would end, trim or split them." Becomes: "Values with `#`, `;`, a line break,
  or space at either end are refused: the pinned parser would end or trim them. Quotes are plain characters to
  it, and are allowed in `args` values."
- §3.4, the tag sentence. Was: "The tag is a hash of the Containerfile and the gate's source, like the sandbox
  images." Becomes: "The tag is a hash of the Containerfile, the entrypoint and the gate's source, and of the CUDA
  architecture when it is not the default `89`. `ygg models image --cuda-arch N` prints the tag that
  `ygg models build --cuda-arch N` builds."
- §3.5, the answers. Was: "Otherwise it answers 403 (path or model), 413 (size), 400 (not JSON) or 503 (no allow
  file)." Becomes: "Otherwise it answers 403 (path or model), 413 (size), 400 (not JSON), 503 (no allow file, or 8
  requests already in flight) or 408 (a body not read within 60 seconds of the headers)."

## Removed

None.
