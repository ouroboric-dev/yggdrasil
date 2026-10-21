---
title: Tasks for the contract folder escalation
status: draft
date: 2026-10-21
related: [proposal.md, delta.md]
style: spec
---

# Contract folder escalation: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Write the failing
> test first. One pull request per repo; the founder merges.

**Goal:** the `pointer-contract` gate escalates on a changed YAML or JSON file, and on a symlink, under the folder of
a contract that the shipped index lists.

**Status:** accepted when the founder merges the pull request that adds this file.

## Tasks

- [ ] **T1 `odin`:** read the mode of each changed file (for example `git diff --raw -z --no-renames`, in place of
  `--name-only`) and carry it in `routing.Change`. Derive the folders from the shipped index's contract paths. In
  `routing.Judge`, escalate (`Escalate`, evidence `inferred`, a reason that names the file and the rule) on a changed
  `.yaml`, `.yml` or `.json` file under such a folder, and on a mode-`120000` file there. Keep a file named
  `openapi.y*ml` on its present path. The cap of 64 files counts the new selections. Tests first, in
  `internal/routing/contract_test.go` and `internal/engine/contract_test.go`:
  - a new YAML file under the contract's folder escalates, and the gate stops in step-by-step, key-points and
    unattended modes, also when `ContractInSpec` is true;
  - a changed JSON file there escalates;
  - a symlink (mode `120000`) there escalates, with a name that is not `openapi.yaml` and with a target outside the
    leaf;
  - a changed `.md` file there does not escalate (verdict `pass`);
  - a changed YAML file outside the folder does not escalate;
  - a YAML file in a subfolder of the contract's folder escalates when the contract sits in a subfolder, and does not
    when the contract sits at the leaf's root;
  - a move that changes only `openapi.yaml` gives the verdicts it gives today (the existing tests stay green).
- [ ] **T2 `yggdrasil`:** fold the delta into spec §3.4, §8.2 and the §18 row; add the one-line note to the Phase 5c
  plan's errata (and to the 2026-10-12 plan, if the founder wants the correction there); mark the second bullet of
  B-084 done; move the `odin` pointer; archive this folder.

## Open for the builder

- **A deleted file.** `routing.Change` has `New == nil` for a delete. The proposal does not say whether a deleted
  YAML or JSON file under the folder escalates. A deleted `schemas/user.yaml` can break the contract as much as an
  edit, so the safe reading is yes. State the choice and test it.
- **A mode change.** A file that was a symlink and is now a regular file, or the reverse, with the same content. Select
  it if either side has mode `120000`. State the choice.
- **How the folders are listed.** The shipped index holds paths from the project root, and the diff is in the leaf's
  own git, so a path is `child + "/" + file`. A contract at a leaf's root counts only the files directly in the root
  (the founder's decision of 2026-10-21): a YAML file in a subfolder of the leaf does not select. A contract in a
  subfolder counts the folder and everything below it. Test both. If a measured run shows the root rule is too noisy
  or lets a split contract through, report it.
- **An index that is absent or does not parse.** Today an absent index means no listed contract, and an index that is
  too big or does not parse escalates the whole move already. Keep both, and say so in a test.
- **Names that git quotes.** `-z` output is raw. Check that a file name with a space or a non-ASCII byte reaches the
  rule unchanged.
- **Where the extension check lives.** The rule works on the name. Say whether it is case-sensitive (`.YAML`). The
  proposal does not decide; choose the stricter reading (case-insensitive) unless a test says otherwise.
