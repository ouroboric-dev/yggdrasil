---
title: Delta for the realm engine
status: accepted
date: 2026-10-17
related: [proposal.md, ../../specs/2026-10-11-yggdrasil-v0-spec.md]
style: spec
---

# Delta: v0 spec §2.1, §3.1, §3.3, §4.1, §4.2, §4.5, §6.1, §7.3, §9.2, §10.1

## Added

- §3.1: a project MUST pin its lead realm and each leaf's realm in `umbrella.yaml` as a name and a version.
  A leaf with no pin MUST be the lead realm's. Two pins of one realm at different versions, a lead pin that
  names another realm than the run's, a realm the store lacks, and a store at another version than the pin
  MUST stop the run before anything is created. Realms MUST be found in the store named by
  `factory.yaml` `realms.dir`; Odin MUST NOT fetch them.
- §3.1: a run MUST record each realm it loaded with a hash of every file a run could read, and a resume MUST
  refuse a realm whose hash or version changed.
- §3.3: a scratch agent MUST work in a workspace made again for every attempt, holding the brief, copies of
  the paths it names (never a symlink, never `.git`) and an empty `out/`. `publish` MUST copy only
  documents (regular files with plain names and a document's ending, bounded in number and size) through
  no symlink, MUST stop the run at `real-secrets-or-user-data` when a secret is found, and MUST commit by
  explicit paths with hooks off.
- §4.1: `leaves.yaml` MUST name each leaf's path, realm, version and consumers. `init` MUST refuse it,
  before creating anything, when the realms disagree with the project's pins, a realm offers no leaf
  recipe, an existing leaf is pinned otherwise, or a consumed leaf does not exist. It MUST create the
  leaves a leaf consumes first, with the pin in the commit that creates each, and a leaf with history MUST
  keep what it has.
- §4.2: `tasks.md` MUST be read exactly (bounded at 1 MiB and 200 tasks, fences ignored). The Definition of
  Ready MUST be checked in code and every problem listed; a plan that is not ready MUST go back to the
  planner. `features.json` MUST be written by Odin alone.
- §4.2: the task shape MUST be a `foreach` node expanded for each task in build order, in the task's leaf
  and realm. A task MUST be `todo`, `doing`, `done` or `blocked`.
- §4.5: a merge gate or pointer move that refuses because the work's checks fail MAY go back into the
  loop that made the work, at most `returns` times (1 to 5, 2 when unset). A conflict, a target another
  process holds and Odin's own failures MUST fail the node.
- §7.3: in unattended mode a task whose loop gave up MUST be blocked with the loop's reason, the leaf MUST
  go back to its main with the work kept on `refs/ygg/<run>/blocked/<task>`, the tasks that depend on it
  MUST be blocked, and the run MUST end `done` with exit code 5.
- §6.1, §9.2: each leaf's sandbox MUST start on its realm's stack with the services of its realm and of the
  leaves it consumes. A service MUST run on a digest-pinned image with no mount, no added capability, no
  published port and no credential in its environment. The firewall MUST open a service's listed ports
  to the work container and no others. A scratch sandbox MUST mount one folder and no git dir.
- §10.1: the events `realm_loaded`, `repo_created`, `docs_published`, `tasks_ready`, `node_returned`,
  `task_started`, `task_done` and `task_blocked`.

## Modified

- §7.3, unattended mode: replaces the Phase 4 change's stop for the case of a loop inside a task shape; a
  loop outside one still stops the run.
- §3.1: realms are found in a local store, not fetched by tag; fetching waits for iteration 2's `github`
  remote (§15.1).

## Removed

None.
