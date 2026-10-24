---
title: The MCP probe's answers (typed-T07)
status: accepted
date: 2026-10-24
related: [tasks.md, design.md, probe/README.md]
style: spec
---

# The MCP probe's answers (typed-T07)

Run by the founder on 2026-10-24 at 22:40, with `probe/run.sh` from this folder, in the work image
`localhost/ygg-work:bfb89f401b90`. The image held Claude Code 2.1.284 (model `sonnet`) and opencode 1.18.32
(model `openrouter/deepseek/deepseek-v4.1-flash`). The probe's managed settings allowed Odin's server by its
command (ruling R22).

```sh
../ouroboric/scripts/ygg-engine.sh run -- \
  bash .worktrees/yggdrasil-probe/docs/2-engineering/changes/2026-10-24-typed-boundaries/probe/run.sh \
  --opencode-model deepseek/deepseek-v4.1-flash
```

## The answers

| | Claude Code | opencode |
| --- | --- | --- |
| **Q1:** the CLI starts `ygg` and the model calls `submit` | yes | yes |
| **Q2:** the stream carries the call's whole input | yes, 24,954 characters, same SHA-256 | yes, 12,035 characters, same SHA-256 |
| **Q3:** a leaf's own server starts | no | no |

None of the three answers changes the plan: neither adapter falls back to the strict whole answer, and the
guardrail holds.

### Q1

Both CLIs started the server, and each session's model called `submit` once. Claude Code's first stream event
lists the server and the tool:

```text
{"type":"system","subtype":"init", … "mcp_servers":[{"name":"ygg","status":"connected","source":"dynamic"}], … "tools":[…,"mcp__ygg__submit"] …}
```

This also settles T09's open question: Claude Code's `--tools` accepts the MCP tool name. Without the probe's
managed settings, the image's own policy refused the server: `Warning: MCP server blocked by enterprise policy: ygg`.

### Q2

For each session, the probe compared the server's log of the call (length and SHA-256 of what it received) with
the call's input as the stream holds it.

- **opencode** carries the input in its `tool_use` event, as T09's adapter reads it. It is
  `part.tool: "ygg_submit"`, `part.state.status: "completed"`, `part.state.input: {"output": …}`, and the tool's
  answer is in `part.state.output`.
- **Claude Code** carries it in the assistant message's `tool_use` block (`name: "mcp__ygg__submit"`). The probe's
  summary first said "no" for the 16 KB session. Its reader looked for `output.text` in an object, and in that
  session the model passed `output` as a JSON **string** holding the object. Measured as the server measured it,
  the stream's input is the server's input byte for byte:

  ```text
  server: {"event":"call","tool":"submit","length":24954,"sha256":"8df5bd61e64f051e7615f0c6247b350f748dc925c04c49aee549c6d497590ed6"}
  stream: tool_use mcp__ygg__submit, input of 24954 characters, sha256 8df5bd61e64f051e7615f0c6247b350f748dc925c04c49aee549c6d497590ed6
  ```

The "300 KB" sessions did not test size. Each model wrote only about 2.3 KB (2,250 and 2,327 characters), and both
of those calls are in the stream whole. So the largest input proven whole is 25 KB. Large outputs, such as a plan
of about 200 KB, go through a draft file and `submit` naming it (R17), so the stream never has to carry them.

### Q3

No marker in any leaf. Neither `evil` nor the impostor `ygg` named in the leaf's own `.mcp.json` and
`opencode.json` started, in any of the four sessions.

## What the probe found besides

- **A model may pass `output` as a JSON string.** Claude Code did so once in two calls, against the tool's
  `output: object` schema. Today's `ygg-submit` refuses that ("output must be a JSON object"), which costs the
  session a retry or more. Ruling R38: `ygg-submit` and both adapters' stream readers accept a string `output`
  that holds exactly one JSON object, and treat it as that object. This is a small gleipnir change.
- **A long repetitive argument trips a classifier.** The 16 KB Claude Code call was "Interrupted: … stopped by a
  safety classifier while the call was running". The probe's prompt asks for one word repeated thousands of
  times, so this is an artifact of the probe, not of the channel. The server still got and answered the call.
- **The probe needed two fixes before it ran.**
  - `head -n 1` under `pipefail` ended the script silently (SIGPIPE).
  - `timeout` cannot start a shell function, so every session exited with 127 before a container started.
  - Both are fixed in this pull request. Neither cost a session.
- **The probe's opencode model was `deepseek/deepseek-v4.1-flash`,** not the `deepseek/deepseek-v4-flash` that
  `factory.yaml` names for the reviewer. The answers are about the CLI, not the model, so they stand.
