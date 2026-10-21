---
title: Every build realm's template ships a run script
status: draft
date: 2026-10-21
related: [delta.md, tasks.md, ../../realm-readiness.md, ../../backlog.md]
style: spec
---

# Every build realm's template ships a run script

**Proposed 2026-10-21.** It fixes backlog [B-078](../../backlog.md) as far as the realms go. The founder decided the shape
on 2026-10-21.

## Why

- The grader starts a product with `/app/start.sh`. A product made from a realm template has no such file, so
  `ygg grade` on it cannot start the app (B-078).
- A product has several leaves, one per realm (frontend, backend, infra, and so on), built in parallel. No leaf can
  write the root `start.sh`: each knows only its own stack. Something has to start the leaves, and it needs one
  way to start each of them.
- Build outputs are not versioned and stay out of git. So a leaf cannot ship a built binary. It ships the means to
  build and start itself.

## Decisions (the founder, 2026-10-21)

- **A product is several leaves of several realms, built in parallel.** One realm builds one stack.
- **No binaries in git.** A leaf builds what it needs when it starts.
- **The infra realm is not needed now.** It will own the root `start.sh` later. This change does not create it and
  does not write a root `start.sh`.
- **The requirement goes into the realm readiness checks.** A realm is ready only when its template ships the
  script and a test proves it starts.
- **Grading is a separate question** (see "Not in this change").

## What changes

- **The leaf run contract.** A build realm's template MUST hold an executable `run.sh` at the leaf's root. Run in
  the leaf, with `PORT` set to a free port, it:
  - builds what the leaf needs, if anything, without fetching packages (a grader has no network);
  - starts the leaf's service in the foreground, listening on `PORT`;
  - accepts a TCP connection on `PORT` within 60 seconds of starting;
  - exits non-zero, with a message, if it cannot start;
  - reads no secret and writes nothing outside the leaf and the temporary folders.
- **A readiness item, RR-23 (build realms):** the template's `run.sh` exists, is executable, and a test starts it
  from a copy of the template and waits for the port. The test is automatic, with the same
  `YGG_REQUIRE_TEMPLATES=1` switch as RR-17.
- **Each build realm's test** does that: it copies the template, runs `run.sh` with a free `PORT`, waits for the
  port, and stops the process. A realm without a toolchain on the machine skips it, and `YGG_REQUIRE_TEMPLATES=1`
  makes the skip a failure.
- **The implementer prompts** of both realms name `run.sh` and the contract: keep it working.
- **The protected files:** `run.sh` is not protected. A task changes it when the product needs another way to
  start, and RR-23's test guards it.

## Not in this change

- **The root `start.sh` and the infra realm.** A later realm, a later change.
- **Installing dependencies at grading time.** A grader has no network. How a leaf's dependencies reach the grader
  (a baked image, a vendored folder) is a question for the task's image and for Phase 6. `run.sh` must not
  assume the network.
- **Grading.** The founder wants a grade for each piece of software (the frontend can be sharp and responsive
  while the backend is slow and wrong) and a project grade built from them. That is new design for the Phase 6
  plan, recorded as B-116.

## Impact

- **Repos:** `helheim-go` and `midgard-react` (each template's `run.sh`, the test, the prompt, the
  architecture page); `yggdrasil` (readiness checklist, spec, backlog, pointers).
- **Approval points:** none.
- **Risk:** a `run.sh` that starts but does not serve. RR-23's test checks only that the port answers. A
  per-leaf check of behaviour is the product's own tests.
