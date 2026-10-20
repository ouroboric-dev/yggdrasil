---
title: A report may have prose before it
status: draft
date: 2026-10-20
related: [delta.md, tasks.md, ../2026-10-20-disputed-findings/proposal.md, ../../backlog.md]
style: spec
---

# A report may have prose before it

**Proposed 2026-10-20.** It fixes backlog [B-105](../../backlog.md). The founder decided the shape on 2026-10-20.

## Why

- `ParseReport` takes a bare JSON document or one document in one code fence, and refuses anything else. In the
  real-agent smoke, `deepseek-v4-flash` wrote a sentence before the fence (and in 2 of 8 bake-off sessions). The
  engine treated it as unreadable. Every unreadable answer costs a try, and two in a row stop the run.
- The prose carries no information the engine needs. The report is the part that counts.

## Decisions (the founder, 2026-10-20)

- **Accept prose before the report, nothing after it.** The report is the last thing in the answer.
- **Keep the rest strict.** The schema, unknown fields, a finding's location, proof for `fixed`, and unique ids
  stay as they are.

## What changes

- `ParseReport` accepts an answer whose end is one JSON document, bare or in one code fence, and ignores the text
  before it.
- It still refuses:
  - text after the document or the closing fence;
  - two or more fences, or a second document;
  - an unclosed fence;
  - a document that fails the schema.
- An answer that holds no document is still an error. It never becomes an empty report, which would read as a
  pass.
- The reviewer prompt (`ReportFormat`) changes from "nothing else, not even a sentence before or after it" to
  "end your answer with the document; nothing after it".

## Not in this change

- Accepting prose after the report.
- Accepting more than one document and choosing between them.

## Impact

- **Repos:** `gungnir` (`ParseReport`), `jormungandr` (the prompt text), `yggdrasil` (spec, backlog, pointers).
- **Approval points:** none.
- **Risk:** a reviewer quotes a JSON example in its prose. Only the last document counts, and an example after the
  report is refused, so the answer is unreadable as today, never misread.
