---
title: A dependency bump needs a sandbox, or --host
status: draft
date: 2026-10-21
related: [delta.md, tasks.md, ../../backlog.md]
style: spec
---

# A dependency bump needs a sandbox, or `--host`

**Proposed 2026-10-21.** It carries out the first decision of backlog [B-084](../../backlog.md), taken by the
founder on 2026-10-20.

## Why

- `ygg deps bump` runs in the sandbox of each product when `factory.yaml` has a `sandbox:` section. Without one it
  runs on the host. Nothing says so to the operator, and the spec (§9.6) does not mention it.
- A host run has the full network and the operator's uid. Its environment is only `PATH`, a throwaway `HOME` and
  `LANG`, but the process still reads every file the operator can read, and it can send them anywhere.
- A bump runs the product's package manager (`go`, `npm`) and its scripts, then the realm's `deps` and `unit`
  checks, which run the product's own tests. All of it is code from the product and from the packages it pulls
  in. The version being bumped to is new code that nobody has read yet.
- A run's agents never touch the host this way (spec §6). A bump is the one path that does, and it is silent.

## What changes

- **`ygg deps bump` refuses when `factory.yaml` has no `sandbox:` section and `--host` is not given.** It exits 2,
  before it takes the runs lock, creates a folder or writes a ledger line. The message is one line on stderr
  (wrapped here):

  ```text
  ygg: deps bump has no sandbox: factory.yaml has no sandbox section, so the package manager and its
  scripts would run on the host with the full network and your user id. Add a sandbox section, or pass
  --host to accept that
  ```

- **`--host` is a flag of `deps bump`.** It means: run on the host, as today, with no sandbox. With a `sandbox:`
  section the flag has no effect and the bump runs in the sandbox.
- **The use of `--host` is recorded.** A bump that runs on the host writes one extra line at the start of its
  ledger, so that an audit of `.factory/deps/<id>/ledger.jsonl` shows it. The line is the first line of the ledger,
  before any product is touched.

## Not changing

- **A bump with a `sandbox:` section.** It runs as today, and needs no flag.
- **The host runner.** `hostExec` keeps its environment (`PATH`, `HOME`, `LANG`) and its process group.
- **The canary rule, the checks, the rollback and the uncommitted result** (spec §9.6).
- **Other commands.** `ygg run` and `ygg grade` already need a sandbox for what they run. This change is only
  about `deps bump`.

## Impact

- **Repos:** `odin` (the flag, the refusal, the ledger line, the docs) and `yggdrasil` (spec, backlog, pointers).
  No change in `gungnir` is proposed (see the open item in the tasks about the ledger line).
- **Tests:** most `deps bump` tests in `odin/internal/cli` run without a sandbox section. They get `--host`.
- **Approval points:** none new.
- **Order:** `odin` merges first, then `yggdrasil` moves the pointer.

## Risk

- A project that bumps without a sandbox today gets a refusal after this change. The message names the fix, and
  nothing has run when it appears.
- `--host` is a way round the refusal. The ledger line makes its use visible; it does not stop it. That is the
  decision: the operator may choose the host, and the choice is on record.
