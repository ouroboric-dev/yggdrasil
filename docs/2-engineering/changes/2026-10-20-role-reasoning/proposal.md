---
title: A role can set its reasoning effort
status: draft
date: 2026-10-20
related: [delta.md, tasks.md, ../../backlog.md]
style: spec
---

# A role can set its reasoning effort

**Proposed 2026-10-20.** It fixes backlog [B-106](../../backlog.md). The shape below is a proposal; the founder
has not decided it.

## Why

- `ConfigJSON` in `gleipnir/opencode/opencode.go` names `reasoning.effort: high` on every request (gleipnir#16).
  `deepseek-v4-flash` took its prompt for an empty message when no effort was named, so the value cannot just go.
- The value is the same for every model and every role. A model that thinks a lot (GLM 5.3 Flash wrote up to 18.5k
  tokens in a session) may do better with less. A model that rejects the setting has no way out.
- An operator already tunes a role's adapter through `factory.yaml` (`price`). The effort is the same kind of
  setting and has no place there yet.

## What changes

- A role MAY set `reasoning:` to `low`, `medium`, `high` or `off`. Without it, the value is `high`, so every
  existing `factory.yaml` behaves as today.
- It travels the path `price` travels: `factory.schema.json` (an enum on the role) and `schema.Role` in `gungnir`,
  then `agents.New` in `odin`, then a new field on `opencode.Config`, then `ConfigJSON`, which writes it in place of
  the fixed `"high"`.
- A value outside the four is refused when `factory.yaml` loads, by the schema, before any run starts.
- `off` means that `ConfigJSON` writes no `reasoning` option for the model. See the builder's questions in
  `tasks.md` for what that does on OpenRouter.

## Not in this change

- A different value per node or per attempt.
- A setting for `claude-code`. What that adapter does with the key is a question for the builder (`tasks.md`).
- Choosing a value for any model. The default stays `high`; the bake-off scripts (B-108) are the way to find a
  better one.

## Impact

- **Repos:** `gungnir` (schema, `Role`), `odin` (`agents.New`), `gleipnir` (`opencode.Config`, `ConfigJSON`),
  `yggdrasil` (spec, backlog, pointers).
- **Approval points:** none.
- **Risk:** `off` on a model that needs an effort brings back the empty-message answer. The setting is the
  operator's choice, and `high` stays the default.
