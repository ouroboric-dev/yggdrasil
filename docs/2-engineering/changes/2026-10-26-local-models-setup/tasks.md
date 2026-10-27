---
title: Local models setup tasks
status: implemented
date: 2026-10-26
related: [proposal.md, delta.md]
style: spec
---

# Local models setup tasks

## Tasks

### Task LS-T1: the model list names where its files come from

**Files (in `gungnir`):** `schema/models.go`, `schema/models.schema.json`, `schema/models_test.go`.

**Acceptance criteria:**

- [ ] A model with `download: {repo, revision, files}` parses; `revision` is optional.
- [ ] A bad repo, an absolute or `..` file path, or a file with a space or shell character is refused, naming the
      model and the field.

**Named test:** `GOWORK=off go test ./schema -run TestModelsDownload`. **Layer:** `gungnir`. **Size:** S.
**Depends on:** none.

### Task LS-T2: `ygg models sources`

**Files (in `odin`):** `internal/cli/models.go`, its test, `docs/architecture.md`, `README.md`.

**Acceptance criteria:**

- [ ] `ygg models sources FILE` prints `<model> <repo> <revision|main> <path>` per file, sorted by model, then in
      the list's order; nothing for a model with no `download`.

**Named test:** `go test ./internal/cli -run TestModelsSources`. **Layer:** `odin`. **Size:** S.
**Depends on:** LS-T1 merged.

### Task LS-T3: `ygg-models.sh setup` and `clean`

**Files (in `ouroboric`):** `scripts/ygg-models.sh`, `scripts/tests/ygg-models.test.sh`,
`scripts/testdata/models/models.example.yaml`, `AGENTS.md`.

**Acceptance criteria:**

- [ ] `setup` on a machine with nothing set up runs, in order: GPU check (and setup), the list from the example
      with the given folders and price, the download of the missing files, the image, start, load, the template
      when the list names a missing one. Run again, it changes nothing that is in place.
- [ ] `setup` without `--price` on a new list refuses, naming the flag.
- [ ] `clean` removes the container, the network and the image; `--state` and `--weights` remove only what they
      name.

**Named test:** `scripts/tests/ygg-models.test.sh`. **Layer:** `ouroboric`. **Size:** M. **Depends on:** LS-T2
merged.

### Task LS-T4: the operations guide

**Files (in `yggdrasil`):** `docs/3-using/operations/local-models.md`, `docs/3-using/operations/README.md`; in
`ouroboric`, `docs/5-research/2026-10-19-local-qwen-howto.md` points to it.

**Acceptance criteria:**

- [ ] The guide covers first-time setup, start/stop/status, switching or adding a model, runs and the proof
      scripts, OpenCode and Claude Code, a driver update, cleanup and troubleshooting, in procedure style.
- [ ] Every command in it matches the scripts' usage text; the outputs it quotes are the founder's real ones. (Ruling:
      no script was run while proof run 1 used the server.)

**Named test:** markdownlint. **Layer:** `yggdrasil`. **Size:** M. **Depends on:** LS-T3.
