---
title: Tasks for the realms' content
status: accepted
date: 2026-10-17
related: [proposal.md, delta.md, ../../plans/2026-10-17-yggdrasil-v0-phase-5b/tasks.md]
style: spec
---

# Tasks

## realm-content-T001: the choices of this change, built (v0, Phase 5b)

- **Acceptance criteria:**
  - [ ] A realm's stack built from its context has a tag that follows the context and the stage, and a
        Containerfile that starts from an unpinned base, copies from an image or adds a URL is refused
        before the engine is called.
  - [ ] A pointer move's acceptance checks run in a sandbox over a snapshot with no git directory and no
        ignored files, on the lead realm's acceptance stack.
  - [ ] A deviation in the design-conformance verdict stops the `spec` gate in every mode; a verdict nobody
        can read stops the run.
  - [ ] The TDD check refuses code without a test and tests that pass on the commit the task started from.
  - [ ] The real `midgard-react` and `helheim-go` build a product from a brief with scripted agents.
- **Named test:** Phase 5b's `tasks.md`: v0-T211 `TestBuildStackRefusesAContextItCouldNotBuildFromPinnedInputsOnly`;
  v0-T240 `TestAcceptanceChecksRunInASandboxThatHoldsASnapshotOfTheProject`; v0-T237
  `TestADeviationStopsTheSpecGateInEveryModeWithTheAmendment`; the TDD tests of both realms; and
  `TestTheRealRealmsBuildAProductFromABriefWithScriptedAgents`.
- **Layer:** `gungnir`, `gleipnir`, `havamal`, `helheim-go`, `midgard-react` and `odin`.
- **Size:** the sum of Phase 5b's tasks.
- **Depends on:** Phase 5a.
