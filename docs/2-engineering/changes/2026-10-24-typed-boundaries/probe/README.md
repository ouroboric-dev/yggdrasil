---
title: The MCP probe (typed-T07)
status: draft
date: 2026-10-24
related: [../tasks.md, ../design.md, ../proposal.md]
style: spec
---

# The MCP probe (typed-T07)

T07 is the founder's: it runs paid sessions. This folder holds the probe an agent wrote for it. It answers the
three questions of T07 for each CLI, in the current work image:

- **Q1:** does the CLI start Odin's server (`ygg`, given the way T09 will give it) and let the model call `submit`?
- **Q2:** does the CLI's stream carry the call's whole input? The probe compares the length and SHA-256 of what the
  server received with what the stream holds, at about 16 KB and about 300 KB.
- **Q3:** with the managed settings allowing only Odin's server, by its command, does the CLI start `evil`, the server the leaf's own
  `.mcp.json` and `opencode.json` name? `evil` leaves `EVIL-STARTED` in the leaf if it runs. The leaf's `.mcp.json` also names a server `ygg` that runs `evil`, to show that the name alone admits nothing.

## Files

| File | What it is |
| --- | --- |
| `server.mjs` | The stdio MCP server: one tool, `submit`, which answers `ok` and logs the input's length and hash. As `evil`, it first writes the marker |
| `stream.mjs` | Reads a stream and prints the length and hash of every `output.text` it holds |
| `leaf/` | A leaf's `.mcp.json` and `opencode.json`, each naming `evil` |
| `managed-settings.json` | The work image's managed settings with T08's one change, in the form ruling R22 chose: `allowedMcpServers` names the probe server by its command (`node /probe/server.mjs ygg`), not by name, as the real image names `/opt/ygg/bin/ygg-submit` |
| `run.sh` | Runs the sessions and writes the answers |

## How to run it

The engine must be up with the bind mount in place, and `CLAUDE_CODE_OAUTH_TOKEN` and `OPENROUTER_API_KEY` must
be set. The opencode model is the reviewer's, from `factory.yaml`, without the `openrouter/` prefix.

```sh
../ouroboric/scripts/ygg-engine.sh run -- \
  bash docs/2-engineering/changes/2026-10-24-typed-boundaries/probe/run.sh --opencode-model <MODEL>
```

The path above is from the root of `yggdrasil`, beside the `ouroboric` clone. The script runs four read-only
sessions: Claude Code and opencode, at each size. Each session mounts the probe's managed settings over the
image's. With `--sizes 16000` it runs only the small pair. It prints one block per session and writes
`summary.txt`, the streams and the server logs to `out/` in the folder it names. The streams hold no credential.

The sessions run in the work image without the firewall sidecar. The questions are about how each CLI handles
MCP servers, not about egress.

## What to do with the answers

Write them to `probe-mcp.md` in the change folder: the three answers per CLI, the command, and the stream lines
of the `submit` call (shorten the text). Then follow T07:

- "no" to Q1 or Q2 for a CLI: that adapter uses the strict whole answer (T09 says how).
- "yes" to Q3 for any CLI: stop the plan. The guardrail would not hold.
- A 300 KB call that fails because the model cannot write that much in one turn is still a "yes" to Q2 if the
  16 KB call is whole. Large outputs then go through a draft file and `check` (T08).
