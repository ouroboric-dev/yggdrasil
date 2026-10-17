---
title: Delta for the realms' content
status: accepted
date: 2026-10-17
related: [proposal.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §4.2, §6.1, §9.2, §9.4, §9.5

## Added

- §6.1: a realm's stack MUST be an image pinned by digest or an image Odin builds from a build context in the
  realm. A build MUST start only from images pinned by digest and its own stages, MUST pull them with the
  isolated registry auth, MUST NOT pull or build during a run, and the image's tag MUST be a hash of the
  context and the stage built. The ladder's scripts MUST be baked into the image where the agent cannot write.
- §6.1: acceptance checks with a sandbox MUST run in a sandbox that holds a snapshot of the project (the
  committed files of the umbrella and each leaf, no git directory) on the lead realm's acceptance stack, with
  the services of every leaf's realm. A realm with acceptance checks and no acceptance stack MUST be refused
  before the run starts.
- §6.1: a service MAY name its command as an argument vector. It MUST have no shell, no `$`, at most 16
  arguments of at most 256 bytes.
- §4.2: the design-conformance reviewer's verdict MUST be one JSON document, `deviation` and, when it is true,
  an `amendment`. The `spec` gate MUST read it; a deviation MUST stop the gate in every mode; a verdict that
  cannot be read MUST be asked for once more and MUST then stop the run.
- §9.5 rung 2: the TDD check MUST run the test files a change adds or changes on a copy of the commit the
  task started from, and they MUST fail there. Code without a new or changed test MUST be refused.
- §9.5 rung 5: a web leaf's Playwright specs MUST run against the built app with a mock of the leaf's copy of
  the API contract behind it; the acceptance run MUST run them against the real API built from the snapshot.
  The API MUST NOT break what the copy promises (`oasdiff`).

## Modified

- §9.2: "Odin builds `api` at the SHA pinned in L1 and runs it as a read-only service in `web`'s sandbox"
  becomes: the acceptance run builds the API from the snapshot and starts it beside the web app; a task's loop
  uses a mock.
- §9.4: the pack layout's `devcontainer/` is the stack's build context and holds the ladder's scripts
  (`devcontainer/checks/`), not a `checks/` folder beside it.
- Phase 3 decision 11 (acceptance checks cannot run with a sandbox on) and Phase 5a decision 12 (a service runs
  the image's own command) are replaced as above.

## Removed

None.
