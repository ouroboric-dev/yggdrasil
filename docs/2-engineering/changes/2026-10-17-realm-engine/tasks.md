---
title: Tasks for the realm engine
status: accepted
date: 2026-10-17
related: [proposal.md, delta.md, ../../plans/2026-10-17-yggdrasil-v0-phase-5a/tasks.md]
style: spec
---

# Tasks

## realm-engine-T001: the choices of this change, built (v0, Phase 5a)

- **Acceptance criteria:**
  - [ ] Two pins of one realm at different versions, a store at another version than the pin, and a realm
        the store lacks stop the run before anything is created; a resume refuses a realm that changed.
  - [ ] `init` creates the leaves of an approved `leaves.yaml` from their realms' templates with the pin
        in the commit that creates each, and refuses a bad file before it creates anything.
  - [ ] A publish copies only documents, through no symlink, and a secret in one is a hard stop.
  - [ ] A plan that is not ready goes back to the planner with every problem; a refusal at a merge gate
        goes back into the loop at most `returns` times.
  - [ ] An unattended run gives up a task whose loop gave up, goes on with the tasks that do not depend
        on it, and exits with 5.
  - [ ] A sandbox starts on its realm's stack with its services, opens their ports and no others, and a
        scratch sandbox holds one folder.
- **Named test:** Phase 5a's `tasks.md`: v0-T169 `TestTwoPinsOfOneRealmThatDisagreeStopTheRun`; v0-T170
  `TestRunJSONRecordsEveryRealmAndAResumeRefusesOneThatChanged`; v0-T187
  `TestInitRefusesBeforeItCreatesAnything`; v0-T183 `TestPublishRefusesWhatIsNotADocument`,
  `TestSecretsInTheDocumentsAreAHardStopAndNothingIsPublished`; v0-T177
  `TestARefusalGoesBackOnlyAsOftenAsTheNodeAllows`; v0-T181
  `TestAnUnattendedRunGivesUpATaskWhoseLoopGaveUpAndGoesOnWithTheRest`; v0-T159
  `TestEgressOpensAServicesPortsAndNoOthers`; and the end-to-end `TestARunOfTheToyRealmsBuildsAProductFromTwoRealms`.
- **Layer:** `gungnir`, `gleipnir`, `jormungandr` and `odin`.
- **Size:** the sum of Phase 5a's tasks.
- **Depends on:** Phase 4.
