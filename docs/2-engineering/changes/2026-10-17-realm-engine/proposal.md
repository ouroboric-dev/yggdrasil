---
title: The realm engine: pins, leaves from a file, a graph per task
status: accepted
date: 2026-10-17
related: [../../specs/2026-10-11-yggdrasil-v0-spec.md, ../2026-10-17-realm-leaf-naming/proposal.md, ../2026-10-16-loop-escalation-and-spend/proposal.md, delta.md, ../../plans/2026-10-17-yggdrasil-v0-phase-5a/tasks.md]
style: spec
---

# The realm engine: pins, leaves from a file, a graph per task

**Decided 2026-10-17:** Phase 5a builds the engine half of Phase 5: realms loaded and pinned, leaves named
by the project, a plan read as tasks, and the task shape repeated for each task. The spec says what a
realm is and what the graph does for "each ready task", but is silent on how a project names the realm of
each leaf, where realms are found, how the stages before the code write documents, and what happens when
a merge gate refuses. This change records the choices the phase had to make, so that the spec and the
code do not drift apart.

## Why

The spec describes a graph that is the same for every project of a realm, and a plan whose tasks the
graph repeats. Three things were left to the implementer: the source of the realms (a git tag was named,
and the `github` remote that would serve it is iteration 2's), the way a project with two flavors of one
realm (a React web and a Go api) says which leaf is which, and what a task whose loop gave up does to an
unattended run (Phase 4 stopped the run, since a linear graph had no other task to go on with). Left to
guess, an implementer would guess differently from the next.

## What changes

- Realms are found in a local store (`factory.yaml` `realms.dir`) by name, and a project pins the lead realm
  and each leaf's realm and version in `umbrella.yaml`. A run loads each realm once, records all of them
  with a hash in `run.json`, and a resume refuses one that changed. The first run of a project pins its
  lead realm.
- The spec stage writes `leaves.yaml` (path, realm, version, description, consumers); the operator approves
  it; `init` creates the leaves from their realms' templates, with the pin in the commit that creates each.
- A scratch agent works in a workspace of its own and `publish` commits its documents, after Odin checked
  they are documents with no secret (spec §3.3 rule 1).
- `tasks.md` is read exactly, the Definition of Ready is checked in code, and a plan that is not ready
  goes back to the planner with every problem.
- The task shape is a `foreach` node expanded for each task, in the task's leaf and realm; a refusal at a
  merge gate or a pointer move goes back into the loop that made the work, a bounded number of times.
- An unattended run gives up a task whose loop gave up and goes on with the tasks that do not depend on
  it; the run ends `done` with exit code 5.
- A sandbox starts on its leaf realm's stack, with the services of its realm and of the leaves it consumes;
  the firewall opens a service's ports and no others; a scratch sandbox holds one folder and no git dir.
- The ledger gets `realm_loaded`, `repo_created`, `docs_published`, `tasks_ready`, `node_returned`,
  `task_started`, `task_done` and `task_blocked`.

## Impact

- **Components:** Gungnir (schemas, graph nodes, ledger events), Gleipnir (the sandbox driver), Jormungandr
  (a loop can be reopened), Odin (the engine, the CLI, the run).
- **Approval points:** none added or changed. `real-secrets-or-user-data` gains a new way to be reached
  (a secret in a document to publish).
- **Operators:** `factory.yaml` may name `realms.dir`; `umbrella.yaml` carries pins; `ygg run --realm`
  takes a name; `ygg sandbox build` takes `--realm` (repeatable) or `--all` and pulls service images;
  `ygg` exits with 5 when an unattended run gave up a task.
- **Backlog:** B-010, B-015, B-035 and B-036 are fixed; B-005, B-006, B-037 and B-039 stay open.
- **v0 plan:** Phase 5a's `tasks.md` implements it; 5b and 5c follow.
