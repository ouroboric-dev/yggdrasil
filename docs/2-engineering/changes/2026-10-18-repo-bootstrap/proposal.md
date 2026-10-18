---
title: One command creates, lints and protects a repo, for any org
status: proposed
date: 2026-10-18
related: [../2026-10-12-remote-creates-repos/proposal.md, ../2026-10-15-factory-issues/proposal.md, ../../backlog.md]
style: spec
---

# One command creates, lints and protects a repo, for any org

**Proposed 2026-10-18 (founder, from a brainstorming session with Claude Code):** the repo scripts in
`ouroboric/scripts` stay modular. A new wrapper calls them in order, so a person creates, lints and
protects a repo with one command and one short-lived token. A small config file per org holds the org,
the licences and the defaults, so anyone using Yggdrasil can run the scripts on their own org. A new
modular script gives every new repo a base CI, built from pre-commit hooks that the user picks.

## Why

- **Two tokens felt like two steps.** `create-repo.sh` has called `setup-repo.sh` since
  `ouroboric` #22, so creating and protecting a repo is already one run. The founder still made a
  separate short-lived token for each step. The likely cause: a fine-grained token limited to
  selected repositories can't name a repo that doesn't exist yet, so it can't set up the repo it
  just created. This is unverified; see [What's left to the builder](#whats-left-to-the-builder).
- **No repo has a base CI.** Only five Go leaves have CI (`gleipnir`, `gungnir`, `havamal`,
  `jormungandr`, `odin`), each with a hand-written `ci.yml`. Nothing runs gitleaks, `reuse lint` or a
  Markdown linter on a pull request. Today these run only on the founder's machine, through pre-commit
  and `check-repos.sh`.
- **A new repo starts without a required check.** `setup-repo.sh` requires the `test` job only when
  `ci.yml` exists. A new repo has no CI, so its ruleset requires nothing. Someone must push CI by hand
  (the pr-bot has no Workflows permission) and run `setup-repo.sh` again.
- **The scripts work for one org only.** `ouroboric-dev`, the founder's name, the AGPL and CC-BY
  licences, the factory repos that get issues, and the pr-bot reminder are all hard-coded. The end
  user is anyone using Yggdrasil, so these must become inputs.
- **Modular scripts are easy to maintain but tedious to run one by one.** A wrapper keeps both
  benefits.

## Goals

1. One command creates one or more repos, gives each a first commit with its licences and base CI,
   then protects it.
2. That command needs one short-lived token, with the permissions stated in its header.
3. Each step stays a separate script that a person can also run on its own.
4. Any org can use the scripts. A config file per org holds what is hard-coded today.
5. `ouroboric-dev`'s config ships with the scripts. It is the founder's daily config and the example
   for other users.
6. The base CI fits any repo, including a repo with only docs. The user picks its pieces.
7. A new repo requires its CI checks from the first moment agents can see it.

## Non-goals

- **Language CI.** A Go or React service gets its CI (for example the Go `test` job) from its realm's
  templates. The founder is adding CI to the existing realms in another session.
- **Rolling the base CI out to existing repos.** The founder is handling this in another session.
  [Future work](#future-work-documented-not-built) says how the scripts could support it.
- **Making `check-repos.sh` org-agnostic.** It stays Ouroboric's own check. It changes only to match
  the new ruleset.
- **The GitHub App credential and the phone workflow** (backlog B-040).
- **Porting into Yggdrasil's `github` remote** (change `remote-creates-repos`, task T002).
- Hosts other than GitHub, and renaming or deleting repos.

## Anti-goals

The work fails, even if every test passes, when any of these is true:

- An agent can see a new repo before it is protected, or before its checks are required.
- A token appears in a command line, a log, an error message or a config file.
- The pr-bot gains Administration or Workflows permission.
- A script overwrites a file that a person or another script wrote.
- The base CI fails on the first commit of a new repo.
- A hook revision or an action is not pinned.
- Running the wrapper is harder than running `create-repo.sh` today.

## What changes

### The scripts

All scripts stay in `ouroboric/scripts`, with tests in `scripts/tests/`, until they move into the
`github` remote. The split below is the proposal's call; the builder may change it if the goals still
hold.

| Script | Job | Status |
|---|---|---|
| `new-repo.sh` | The one command. Reads the org config, checks every input, then runs the steps below for each repo. | new |
| `create-repo.sh` | Creates empty repos on GitHub. Creates none if any named repo exists. | changed: it no longer makes the first commit or calls `setup-repo.sh` |
| `add-licences.sh` | Writes `LICENSE`, `LICENSES/` and `REUSE.toml` into a directory, from the config. | new, taken out of `create-repo.sh` |
| `add-ci.sh` | Writes `.pre-commit-config.yaml` and `.github/workflows/lint.yml` into a directory, from the chosen pieces. | new |
| `setup-repo.sh` | Applies the settings and the `protect-main` ruleset, fixing drift. | changed: reads the org config, and requires the checks of every known workflow |

`new-repo.sh` runs, for each repo:

1. `create-repo.sh` creates the empty repo.
2. `add-licences.sh` and `add-ci.sh` write into a fresh temporary directory.
3. The wrapper makes the first commit and pushes it. The token reaches git through the credential
   helper only, as it does today.
4. `setup-repo.sh` protects the repo and requires its checks.
5. The wrapper prints the config's after-create message (for `ouroboric-dev`, the pr-bot reminder).

`new-repo.sh` checks every repo name and the whole config before it creates anything, as
`create-repo.sh` does today. It takes the same repo arguments as `create-repo.sh` does today:

```
GH_TOKEN=... new-repo.sh --org ouroboric-dev [--private] [--ci <piece>,...] <repo> "<description>" [<repo> "<description>"]...
```

If a step fails after `create-repo.sh` succeeds, the repo exists but is empty or unprotected. This
is the same as today. In `ouroboric-dev` agents can't reach it, because the pr-bot is installed on
selected repos only and the founder adds a repo after it is protected. The after-create message
SHOULD tell other orgs to give their bots access only after `new-repo.sh` succeeds. The scripts keep
their `CREATE_REPO_*` overrides (API, git host, setup script) so the tests can use the fakes.

### The org config

- One JSON file per org, in `scripts/orgs/<org>.json`, read with `jq`. (JSON is the proposal's call:
  `jq` is already a dependency, and `pr-bot.json` sets the precedent.)
- `--org <name>` loads `scripts/orgs/<name>.json`. `--config <path>` loads a file from elsewhere.
- Flags on any script override the config's values for that run.
- The config holds:
  - `org`: the GitHub owner.
  - `licence`: the code licence, as an SPDX id. It is also copied to `LICENSE`.
  - `docs_licence` and `docs_paths` (optional): a second licence for the docs, and the paths it covers.
    Today these are CC-BY-4.0 and `docs/**`, `README.md` and `AGENTS.md`.
  - `copyright`: the holder written to `REUSE.toml`. The year defaults to the current year.
  - `issues`: off by default, with a list of repos that have issues on. `ouroboric-dev` lists
    `yggdrasil` and `asgard`.
  - `ci`: the default base-CI pieces.
  - `after_create`: optional messages for public and private repos.
- `scripts/orgs/ouroboric-dev.json` reproduces today's behaviour exactly.

### Licence texts

- `add-licences.sh` gets each licence text by SPDX id with `reuse download`, through the pinned
  `uvx --from 'reuse==5.0.2'` that `check-repos.sh` already uses.
- A `--licence-dir` flag (or config key) reads the texts from a local folder instead. The tests use
  it so they run offline. `ouroboric-dev` points it at `ouroboric/LICENSES`, so its first commits
  stay byte-for-byte the same as today.

### The base CI

- Every repo's base CI runs through pre-commit, so a local commit and CI check the same things.
- `add-ci.sh` builds `.pre-commit-config.yaml` from pieces. Each piece is a small YAML fragment in
  `scripts/templates/ci/`. The pieces are:

  | Piece | Hook | Default for `ouroboric-dev` |
  |---|---|---|
  | `gitleaks` | gitleaks, `rev: v8.30.1` (as today) | always on; the user can't remove it |
  | `reuse` | `reuse lint` | on |
  | `markdown` | markdownlint | on |
  | `shell` | shellcheck | off |
  | `actions` | actionlint | on |
  | `yaml` | yamllint | off |

  The default column is the proposal's call. `--ci reuse,markdown,shell` replaces the config's
  defaults for one repo.
- `add-ci.sh` writes `.github/workflows/lint.yml` with one job, `lint`. The job runs
  `pre-commit run --all-files --show-diff-on-failure` on `pull_request` and on `push` to `main`. Its
  actions are pinned by SHA, with a version comment, the same way the Go leaves pin theirs. It has
  `permissions: contents: read`, and checks out with `persist-credentials: false`.
- `add-ci.sh` never overwrites a file. If a target file exists, it stops with an error.

### Requirements

- `new-repo.sh` MUST check all inputs before it creates a repo.
- `new-repo.sh` MUST stop at the first error.
- A new repo's first commit MUST hold the licence files and the base CI files.
- `setup-repo.sh` MUST run after the first push and before the wrapper reports success.
- The ruleset MUST require `lint` when `.github/workflows/lint.yml` exists.
- The ruleset MUST require `test` when `.github/workflows/ci.yml` exists.
- Each required check MUST come from GitHub Actions (app 15368), on an up-to-date branch.
- `setup-repo.sh` MUST stop if a workflow lookup fails with any status but 404.
- The scripts MUST read the token from `GH_TOKEN` only.
- The scripts MUST NOT put the token in a command line, a log or a file.
- `add-ci.sh` MUST NOT overwrite a file.
- The base CI MUST pass on a new repo's first commit.
- `gitleaks` MUST be in every base CI.
- Each hook and action MUST be pinned to an exact version.
- `scripts/orgs/ouroboric-dev.json` MUST reproduce today's settings, licences and ruleset.

### Required checks

`setup-repo.sh` maps known workflow files to the job it requires: `lint.yml` to `lint`, and `ci.yml`
to `test`. (A fixed map is the proposal's call. Reading job names out of arbitrary YAML in bash is
fragile.) It keeps #31's rule: only a 404 means "no such workflow", and any other failure stops the
script with the ruleset unchanged. `check-repos.sh`'s `ruleset` check builds its expected rules the
same way.

### The token

One fine-grained token, short-lived, owned by the org, with access to **all repositories**:

- Administration: read and write (create the repo, settings, ruleset);
- Contents: read and write (the first push);
- Workflows: read and write (the first push holds `.github/workflows/lint.yml`);
- Metadata: read.

`new-repo.sh`'s header states this. The docs standard's repo section says the same.

### Docs to update

- `ouroboric/docs/4-ways-of-working/docs-standard.md`, the repo section: the founder runs
  `new-repo.sh`, the token's permissions, and the base CI.
- `ouroboric/AGENTS.md`, the scripts table: `new-repo.sh`, `add-ci.sh` and `add-licences.sh`
  (founder-run, like `create-repo.sh`).
- Each script's header.
- Backlog B-040: the planned `workflow_dispatch` workflow calls `new-repo.sh`, not `create-repo.sh`
  then `setup-repo.sh`.
- Change `remote-creates-repos`: when the `github` remote ports the scripts, it also ports the org
  config and the base CI.

## Tests

Follow the tree's rule: write each test first and watch it fail. Use the existing fakes,
`scripts/tests/fake-github.py` and `scripts/tests/fake-gh`.

- `new-repo.sh`: the steps run in order; the first commit holds the licence and CI files;
  `setup-repo.sh` sees that commit; an existing repo or a bad config creates nothing; the token never
  appears in arguments or output.
- `create-repo.sh`: the current tests still pass, less the first-commit and setup parts that move.
- `add-licences.sh`: one licence, and two licences with docs paths; `--licence-dir` works offline; the
  result passes `reuse lint`; the `ouroboric-dev` config gives today's files byte for byte.
- `add-ci.sh`: each piece alone and in combination; an unknown piece fails; `gitleaks` can't be
  removed; an existing file stops it; the result passes `pre-commit validate-config`; the workflow
  passes actionlint.
- `setup-repo.sh`: no workflow, `lint.yml` only, `ci.yml` only, and both; a non-404 failure leaves the
  ruleset unchanged; issues follow the config.
- One real run (founder, by hand): create a throwaway public repo with `new-repo.sh`, confirm its
  first pull request runs `lint` and can't merge until it passes, then delete the repo.

## What's left to the builder

- **Confirm the token.** Check GitHub's "Permissions required for fine-grained personal access
  tokens" page, then the real run. A selected-repositories token may not be able to set up a new repo.
  If all-repositories access is not needed, use the narrower one. If one token can't do every step,
  stop and tell the founder before going on.
- **Pick each hook.** Prefer hooks that install without an extra toolchain (Go or Docker), so the
  `lint` job needs only Python. Pin each to a release at least two weeks old.
- **The markdownlint rules.** Pick a config that the house style passes (long tables, front matter).
  A new repo has no Markdown, so this matters only when a repo adds docs, or for the future rollout.
- **Script names and the split**, if a better one keeps the goals and the separate scripts.
- **Private repos.** Secret scanning and private vulnerability reporting may not apply to a private
  repo on every plan. Keep today's behaviour for `huldra`-style repos, and fail clearly elsewhere.

## Interactions

- **`scaffold-component.sh`** writes a `.pre-commit-config.yaml` holding only gitleaks, and never
  overwrites. After `new-repo.sh`, that file already exists, so the scaffold skips it. The other
  session's realm templates should add their language hooks to the existing file, or drop it from the
  scaffold.
- **Realm CI** stays in `ci.yml` with its `test` job. The base CI's `lint.yml` sits beside it. Each is
  a separate required check.

## Future work (documented, not built)

These follow from the design. None is in scope. When one is wanted, add it to the backlog for a
future session. `delta.md` and `tasks.md` for this change come with its implementation plan.

1. **Base CI on existing repos.** Run `add-ci.sh` in a clone, on a branch. The founder pushes it and
   opens the PR, because the pr-bot can't push workflows. After it merges, run `setup-repo.sh` to
   require `lint`. Existing repos already have a `.pre-commit-config.yaml`, so `add-ci.sh` needs a
   `--merge` mode that adds missing hooks and keeps the rest. Existing docs may fail markdownlint at
   first, so roll out one piece at a time.
2. **Picking pieces from a repo's contents.** For existing repos, `add-ci.sh --detect` could turn on
   `shell` when `*.sh` files exist, `yaml` when YAML exists, and so on. A new repo is empty, so it
   needs explicit pieces.
3. **Pieces from realms.** A realm could ship its own pieces (for example `gofmt` or `eslint`) in its
   templates folder, and `add-ci.sh` could search there too. Language checks would then also run in
   pre-commit.
4. **The phone workflow (B-040)** runs `new-repo.sh` with the GitHub App's token.
5. **The `github` remote** ports `new-repo.sh`, the org config and the CI pieces. The org config
   becomes part of the operator's instance config.
6. **`check-repos.sh` for any org.** It reads the org config, and gains a `lint` check that the base
   CI exists.

## Impact

- **Scripts:** `ouroboric/scripts`, as listed above. New `scripts/orgs/` and `scripts/templates/ci/`.
- **Founder:** one command and one token per batch of new repos. The pr-bot step stays manual.
- **Other users:** copy `scripts/orgs/ouroboric-dev.json`, change it, and run `new-repo.sh`.
- **Security:** no change to the bots' permissions. The token gains Workflows write, for the first
  push only. New repos require `lint` from the first moment agents can see them.
- **Yggdrasil spec:** no change now. The `github` remote's port (change `remote-creates-repos`) grows
  to include the config and the base CI.
