---
title: A changed YAML or JSON file in a contract's folder escalates the pointer-contract gate
status: draft
date: 2026-10-21
related: [delta.md, tasks.md, ../../backlog.md]
style: spec
---

# A changed YAML or JSON file in a contract's folder escalates the pointer-contract gate

**Proposed 2026-10-21.** It is the second decision of backlog [B-084](../../backlog.md), taken by the founder on
2026-10-20. It changes the "acceptance tests catch the rest" rule of the spec's decision log (the backlog calls it the
plan's decision 15; see "What changes").

## Why

The `pointer-contract` gate (spec §3.4) judges a pointer move by the files it changes. Today it looks at one kind of
file: one whose name ends in `openapi.yaml` or `openapi.yml`. This is how a contract passes unseen.

- **The gate reads names, not folders.** `contractJudgement` (`odin/internal/engine/contract.go`) lists the changed
  files of the move with `git diff --name-only`. It keeps a file only if `routing.IsContractName` accepts it. Every
  other file is dropped before `routing.Judge` runs.
- **A split contract is not seen.** An OpenAPI document can hold `$ref` to a sibling file, for example
  `schemas/user.yaml`. The move changes only the sibling. `openapi.yaml` is not in the diff, so there is nothing to
  judge and the verdict is `pass`: "no contract file changed". oasdiff would not help. Odin runs it with
  `--allow-external-refs=false`, so it never reads the sibling.
- **A link is not seen.** The diff names a symlink like any file, with its mode. The gate does not read the mode.
  A symlink with another name than `openapi.yaml` is dropped. One named `openapi.yaml` has the link's target path
  as its content, which is not a contract. The wiring generator also skips links: it walks the leaf, finds a
  link, notes "a link, not followed" and lists no contract for it. A contract behind a link is never in the impact
  index.
- **The only net is later.** Spec §8.2 and the decision log say that every pointer move runs the umbrella's
  acceptance tests, "so a break that only an `inferred` edge noticed is still caught". That is true for a break the
  tests exercise. It does not cover a contract change that no test reads yet (a new field, a removed route nobody
  calls). Those are the changes the gate is there for.

The founder decided on 2026-10-20 that the gate does not leave this to the tests.

## What changes

- **A new rule in the gate.** The gate finds the folder of each contract that the shipped impact index lists. The
  index is the one at `HEAD` of the project, and each entry has a path from the project root. The folder is the
  directory of that path, with one narrowing: for a contract at a leaf's root, only the files directly in the root
  count, not those below it. A move that changes a file under such a folder is judged by two new rules, whatever the
  file is called:
  - a changed YAML or JSON file (extension `.yaml`, `.yml` or `.json`) escalates;
  - a file whose git mode is `120000` (a symlink) escalates, whatever its extension.
- **"Escalate" is the existing mechanism, not a new one.** The verdict is `routing.Escalate` with the evidence
  `inferred`. `contractFacts` turns it into `Facts.Escalate`, and `gate.Decide` returns `Stop` for it before it
  looks at the mode or at `ContractInSpec`. So the gate stops in every mode, as it does today for a contract that
  only a guess reaches. An approved spec that holds the change does not open it. The ledger records
  `pointer_contract_checked` with the verdict `escalate`. The gate file lists the files and the reason in its
  "Contract evidence" section. A person reads the files and decides.
- **The decision log changes.** The row "Contract-change stops (2026-10-12)" says that only `extracted` or `oasdiff`
  evidence triggers `pointer-contract`, and that acceptance tests catch the rest. After this change that holds for
  the files outside these two new rules. Inside a contract's folder, a changed YAML or JSON file and a symlink stop
  the gate without `extracted` evidence. The delta changes the row and §8.2.
- **The reason names the rule.** For example: `schemas/user.yaml: a YAML file under the folder of a listed contract
  changed; the contract may be split across files`.

## Decisions taken here (change them in review)

- **"Under" means the folder and every folder below it.** A split contract can sit in `schemas/` or deeper. A
  non-recursive rule would miss it. The cost of this reading is in "The cost".
- **The folder comes from the shipped index.** A contract that the index does not list has no folder to watch. That is
  not new: such a file is judged by its name alone and already escalates (`judgeOne`, "the index does not list it").
- **The two new rules do not call oasdiff.** A split file is not an OpenAPI document, so oasdiff has nothing to
  compare. The rule is a stop for a person, not a diff.

## What stays

- **A changed file of another kind under the folder** (for example `README.md`, `.go`, `.sql`) does not escalate.
  It is dropped as today.
- **A file outside every listed contract's folder** does not escalate, whatever its type.
- **A file named `openapi.yaml` or `openapi.yml`** is judged as before: the index, oasdiff, `pass`, `fail` or
  `escalate`. The new rules add to that. When a file meets both, the more severe verdict wins, as in `Judge` today.
- **The `fail` verdict and its table row.** A move that changes a contract by an extracted edge or oasdiff still
  stops for a person, or opens when the approved spec holds the change, or blocks the task in unattended mode.
- **The cap of 64 contract files** stays. Files the new rules select count toward it.
- **The acceptance tests on every pointer move** stay. They are still the check for everything the gate does not
  select.

## The cost

The new rule escalates on edits that do not touch the contract. A person reads each one.

- **`helheim-go` (the `api` template).** `openapi.yaml` sits at the leaf's root. The founder decided on
  2026-10-21 that a contract at a leaf's root counts only the files directly in the root, not those below it.
  That selects `.golangci.yml` and `sqlc.yaml`, which a person should often see anyway, and leaves out
  `.github/workflows/ci.yml` and `.devcontainer/devcontainer.json`, which sit in subfolders. A split contract
  placed in a subfolder of the leaf is not seen: that is the price of the narrow rule.
- **`midgard-react` (the `web` template).** The contract is `contracts/api.openapi.yaml`, so the folder is
  `contracts/`. The template holds no other file there. This case costs nothing today.
- **How often.** I expect it to be rare for web leaves and common for Go leaves: a feature that changes the API
  usually changes `sqlc.yaml` or the CI file at some point, and the contract change itself would escalate anyway
  when the index does not list readers. I did not measure it. The proof runs will show the real rate.

## Not in this change

- **Reading the split files.** The gate does not follow `$ref` or compare the sibling with oasdiff. It stops and a
  person reads.
- **Registering a split contract's files in the impact index.** The wiring generator keeps skipping links and
  keeps listing only the files named `openapi.y*ml`. A contract that exists only as a link is therefore listed in no
  folder, and this rule does not watch it, unless a listed contract shares the folder.
- **Other formats.** TOML, XML, Protobuf and the like are not selected.

## Impact

- **Repos:** `odin` (the diff with modes, the two rules, the tests) and `yggdrasil` (spec, backlog, pointers).
  `routing.Change` gains a mode, and `routing.Judge` gains the folders. `gungnir` does not change: the ledger event
  and the verdict names exist.
- **Order:** `odin` merges first, then the pointer move.
- **Approval points:** none new. `pointer-contract` stops in more cases.
- **Risk:** false escalations, as in "The cost". The stop is visible and names the file and the rule. The other risk
  is the one the rule does not close: a contract that is a link and has no listed neighbour. Closing it needs the
  generator to list links, which is a separate change.
