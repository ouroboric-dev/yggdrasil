---
title: Tasks for one command that creates, lints and protects a repo, for any org
status: proposed
date: 2026-10-18
related: [proposal.md, delta.md]
style: spec
---

# Repo bootstrap: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking. Tasks and steps marked **founder** are done by the founder,
> never by an agent.

**Goal:** one founder-run command, `new-repo.sh`, creates repos in any org, gives each a first commit
with its licences and a pre-commit base CI, and protects it with `lint` (and `test` where CI exists)
required, under one short-lived token.

**Architecture:** five bash scripts in `ouroboric/scripts`. Each does one step and runs on its own. A
sourced library, `repo-config.sh`, reads one JSON config per org (`scripts/orgs/<org>.json`).
`new-repo.sh` checks every input through each step's `--check` mode, then runs the steps in order for
each repo. The base CI is a `.pre-commit-config.yaml` built from pinned piece files, plus a `lint.yml`
workflow that runs pre-commit.

**Tech stack:** bash, `jq`, `git`, `gh api` (in `setup-repo.sh`), `curl` (in `create-repo.sh`), `uvx`
for `reuse==5.0.2` and `pre-commit==4.6.2`, and GitHub Actions.

**Spec:** [proposal](proposal.md) and [delta](delta.md). Read both. Where this plan and the proposal
differ, this plan wins. It corrects one fact: `scaffold-component.sh` doesn't skip an existing
`.pre-commit-config.yaml`; it stops with an error. Task T007 fixes that.

**Status:** accepted when the founder merges the pull request that adds this file. None of these
tasks is tied to a phase of the v0 plan.

**Code in this plan was not run.** Unlike the phase plans, this plan names files, interfaces, exact
values and tests, and leaves the bodies to the executor. If a pinned value turns out wrong (a hook
that won't install, an action SHA that doesn't match its tag), stop and report it.

## Decisions made by this plan

- **The script split.** `create-repo.sh` only creates empty repos. The first commit moves into
  `new-repo.sh`. `add-licences.sh` and `add-ci.sh` write files into a folder. `create-repo.sh`,
  `add-licences.sh` and `add-ci.sh` each have a `--check` mode, which checks the inputs and writes or
  creates nothing. `new-repo.sh` runs all three checks before it creates anything.
- **Every script names its org.** Each script takes `--org <name>` (it reads
  `scripts/orgs/<name>.json`) or `--config <path>` as its first argument. There is no default org.
- **gitleaks scans the history in CI.** The upstream hook runs `gitleaks git --pre-commit --staged`,
  so `pre-commit run --all-files` in CI scans nothing. The `gitleaks` piece adds a second hook,
  `gitleaks-history`, in the `manual` stage, and `lint.yml` runs it on a full-depth checkout.
- **A piece may bring config files.** A folder `pieces/<name>.files/`, if present, is copied into the
  repo root. `markdown` brings `.markdownlint.yaml`, and `yaml` brings `.yamllint.yaml`.
- **The hook and action pins** are below. Each was checked on 2026-10-18 to be at least two weeks old.
- **The token question is settled by the founder's real run** (H01). GitHub's permissions page lists
  `POST /orgs/{org}/repos` under both "Administration" and "Repository creation" (write). It doesn't
  say whether a token limited to selected repositories can then set up the new repo.

## Global constraints

- All scripts: `#!/usr/bin/env bash` and `set -euo pipefail`. A header comment says what the script
  does, who runs it, and its usage line, like the existing scripts.
- Input and usage errors exit with code 2 through `die() { echo "<script>: $*" >&2; exit 2; }`.
- `GH_TOKEN` is the only way a token comes in. No script prints it, puts it in a command line, or
  writes it to a file. Git gets it only through the inline credential helper that `create-repo.sh`
  uses today.
- No script overwrites a file. If any target exists, it writes nothing at all.
- Pins, exact:
  - gitleaks `v8.30.1`
  - fsfe/reuse-tool `v5.0.2`
  - DavidAnson/markdownlint-cli2 `v0.23.3`
  - shellcheck-py/shellcheck-py `v0.11.0.1`
  - rhysd/actionlint `v1.7.12`
  - adrienverge/yamllint `v1.38.0`
  - `pre-commit==4.6.2`
  - `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1`
  - `actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97 # v7.0.0`
  - Python `3.13`
  - `reuse==5.0.2` for `uvx`
- Required checks come from GitHub Actions (`integration_id` 15368) with
  `strict_required_status_checks_policy: true`. `lint.yml` maps to `lint`, and `ci.yml` maps to
  `test`.
- `scripts/orgs/ouroboric-dev.json` reproduces today's org, licences, `REUSE.toml`, issues rule and
  pr-bot messages, byte for byte where a test compares them.
- Tests follow `scripts/tests/*.test.sh`: a `mktemp -d` folder removed by `trap`, the
  `check "<description>" <command>` helper, and `exit $fail`. Run one with
  `bash scripts/tests/<name>.test.sh`. It passes when every line starts with `ok` and the exit code
  is 0.
- New and changed scripts pass `shellcheck -x -s bash`. Run it as
  `uvx -q --from 'shellcheck-py==0.11.0.1' shellcheck -x -s bash <file>`.

## Review focus

The tests below each pin one of these failure modes. They are added to the owning task:

1. **A copyright holder or a path containing `"` or `\`** would break `REUSE.toml`. The config must
   refuse it, and a non-ASCII name like "Valério" must come through byte for byte (T001, T003).
2. **The same repo named twice in one batch** passes the existence check, then fails on the second
   create, after the first repo exists. `--check` must refuse duplicates (T002).
3. **A failure after the repo is created** (a failed push or setup) leaves an unprotected repo. A
   re-run then refuses, because the repo exists. `new-repo.sh` must say which repo is unfinished and
   that it is not protected (T006).
4. **A config outside `scripts/orgs/`, in a path with spaces,** must find its `licence_dir` relative
   to the config file, not to the current folder (T001).
5. **`--ci` with an empty item** (`reuse,,markdown`) or a repeated piece must fail, or dedupe,
   explicitly. It must never produce a broken or duplicate `repos:` entry (T004).

## How each task lands

Work in `/home/brunogbv/brunogbv/ouroboric/ouroboric`, on one branch, `repo-bootstrap`, made from
`main` before T001. Commit after each task:

```bash
for t in scripts/tests/*.test.sh; do bash "$t" >/dev/null || echo "FAIL $t"; done   # prints nothing
git status --short                # then stage the task's files by path
git commit -m "<what changed> (repo-bootstrap-T00n)" -m "Co-Authored-By: Claude <model> <noreply@anthropic.com>"
```

After T007, push and open one pull request:

```bash
scripts/as-bot.sh ouroboric git push -u origin repo-bootstrap
scripts/as-bot.sh ouroboric gh pr create --repo ouroboric-dev/ouroboric --title "Repo bootstrap: new-repo.sh, org configs and a base CI" --body-file <file>
```

The PR body lists each task's acceptance criteria with the named tests' output. The pr-bot can push
`scripts/templates/ci/lint.yml`, because it is not under `.github/workflows/`.

---

### Task repo-bootstrap-T001: one config per org

**Files (in `ouroboric`):**

- Create: `scripts/repo-config.sh`, `scripts/orgs/ouroboric-dev.json`, `scripts/orgs/README.md`
- Test: `scripts/tests/repo-config.test.sh`

**Interfaces:**

- Produces, in `scripts/repo-config.sh` (sourced, never run; it defines functions only):
  - `repo_config_args ARGS...` reads a leading `--org <name>` or `--config <path>`. It sets
    `RC_FILE`, an absolute path, and the array `RC_REST`, which holds the other arguments. It sets
    `RC_FROM`, an array holding the two words to pass on to another script (`--config "$RC_FILE"`).
    `--org <name>` resolves to `${REPO_ORGS_DIR:-<dir of repo-config.sh>/orgs}/<name>.json`. The name
    must match `^[A-Za-z0-9][A-Za-z0-9-]*$`. Neither flag gives:
    `name an org: --org <name> or --config <path>`.
  - `repo_config_load` reads `RC_FILE`, checks it, and sets the variables below. On any problem it
    prints `repo-config: <file>: <problem>` and exits 2.
    - `RC_ORG`, `RC_LICENCE`, `RC_DOCS_LICENCE` (empty if none), `RC_COPYRIGHT`.
    - `RC_DOCS_PATHS`: the TOML list body, such as `"docs/**", "README.md", "AGENTS.md"`.
    - `RC_LICENCE_DIR`: absolute, resolved relative to the config file's folder, or empty.
    - `RC_ISSUES_ON`: space-padded, such as `" yggdrasil asgard "`.
    - `RC_CI`: comma-separated, such as `reuse,markdown,actions`.
  - `repo_after_create public|private <repo>` prints the matching `after_create` message, with every
    `{repo}` replaced by the name. It prints nothing if no message is set.
- The config keys are exactly these:
  - `org` (required);
  - `licence` (required);
  - `docs_licence` and `docs_paths` (both or neither);
  - `copyright` (required);
  - `licence_dir`, `issues_on`, `ci` and `after_create` (`public`, `private`), all optional.

  Any other key is refused, so a typo can't pass unnoticed. With `--org <name>`, `.org` must equal
  `<name>`.
- Value rules:
  - `org` and the names in `issues_on`: `^[A-Za-z0-9][A-Za-z0-9._-]*$`.
  - `licence` and `docs_licence`: `^[A-Za-z0-9][A-Za-z0-9.+-]*$`.
  - `docs_paths`: a non-empty array of strings.
  - `ci`: an array of `^[a-z0-9-]+$` names.
  - `copyright` and each docs path: non-empty, with no `"`, `\` or newline.

**Acceptance criteria:**

- [ ] `--org ouroboric-dev` loads the shipped config. It gives `AGPL-3.0-only`, `CC-BY-4.0`, the three
      docs paths, the copyright holder "Bruno Guilhermo de Barros Valério", issues on for `yggdrasil`
      and `asgard`, and the default pieces `reuse,markdown,actions`.
- [ ] Each of these is refused with exit 2:
  - a missing required key or an unknown key;
  - `docs_licence` without `docs_paths`;
  - a `"` in `copyright`;
  - a bad org name;
  - an `org` that differs from `--org`;
  - no `--org` or `--config`.
- [ ] A `--config` in a folder with a space resolves `licence_dir` from that folder.
- [ ] `scripts/orgs/README.md` explains each key and says to copy `ouroboric-dev.json` as the example.

**Named test:** `bash scripts/tests/repo-config.test.sh`. **Layer:** `ouroboric`. **Size:** M.
**Depends on:** this change merged.

- [ ] **Step 1: Write the failing test.** `scripts/tests/repo-config.test.sh`. Each case runs in a
  subshell (`( . "$HERE/../repo-config.sh"; repo_config_args …; repo_config_load; echo "$RC_X" )`).
  The cases:
  - `"ouroboric-dev loads"`: `RC_ORG=ouroboric-dev`, `RC_LICENCE=AGPL-3.0-only`,
    `RC_DOCS_LICENCE=CC-BY-4.0`, `RC_DOCS_PATHS='"docs/**", "README.md", "AGENTS.md"'`,
    `RC_ISSUES_ON=' yggdrasil asgard '` and `RC_CI=reuse,markdown,actions`.
  - `"licence_dir is the umbrella's LICENSES"`: `[ "$RC_LICENCE_DIR" = "$(cd "$HERE/../../LICENSES" && pwd)" ]`.
  - `"the holder keeps its accent"`: `[ "$RC_COPYRIGHT" = 'Bruno Guilhermo de Barros Valério' ]`.
  - `"after_create fills the repo"`: `repo_after_create public alpha` prints exactly
    `Add alpha to the pr-bot: https://github.com/organizations/ouroboric-dev/settings/installations, ouroboric-pr-bot, Configure, Repository access.`.
  - The refusals listed in the acceptance criteria. Each runs on a fixture config in `$T`, and
    passes only when the exit code is 2 and stderr starts with `repo-config:`.
  - `"a config in a folder with a space"`: `"$T/my org/acme.json"` with `"licence_dir": "lic"` gives
    `RC_LICENCE_DIR="$T/my org/lic"`.
- [ ] **Step 2: Run it.** `bash scripts/tests/repo-config.test.sh`. Expected: FAIL lines, because
  `repo-config.sh` doesn't exist.
- [ ] **Step 3: Write `scripts/orgs/ouroboric-dev.json`** exactly:

```json
{
  "org": "ouroboric-dev",
  "licence": "AGPL-3.0-only",
  "docs_licence": "CC-BY-4.0",
  "docs_paths": ["docs/**", "README.md", "AGENTS.md"],
  "copyright": "Bruno Guilhermo de Barros Valério",
  "licence_dir": "../../LICENSES",
  "issues_on": ["yggdrasil", "asgard"],
  "ci": ["reuse", "markdown", "actions"],
  "after_create": {
    "public": "Add {repo} to the pr-bot: https://github.com/organizations/ouroboric-dev/settings/installations, ouroboric-pr-bot, Configure, Repository access.",
    "private": "Never add {repo} to the pr-bot: agents must not see this repo."
  }
}
```

- [ ] **Step 4: Implement `scripts/repo-config.sh`.** Do the checks in one `jq` program that prints
  the first problem, or nothing. Read the values with `jq -r`. `RC_DOCS_PATHS` is
  `[.docs_paths[]|tojson]|join(", ")`. Then write `scripts/orgs/README.md`.
- [ ] **Step 5: Run it.** `bash scripts/tests/repo-config.test.sh`. Expected: every line `ok`, exit 0.
  Then run shellcheck on `scripts/repo-config.sh`.
- [ ] **Step 6: Commit.** Stage `scripts/repo-config.sh`, `scripts/orgs/ouroboric-dev.json`,
  `scripts/orgs/README.md` and `scripts/tests/repo-config.test.sh`. Message: "repo scripts: one
  config per org (repo-bootstrap-T001)".

### Task repo-bootstrap-T002: create-repo.sh only creates, for any org

**Files (in `ouroboric`):**

- Modify: `scripts/create-repo.sh`, `scripts/tests/fake-github.py`
- Test: `scripts/tests/create-repo.test.sh`

**Interfaces:**

- Consumes: `repo_config_args`, `repo_config_load`, `RC_ORG` (T001).
- Produces: `GH_TOKEN=... create-repo.sh (--org <name>|--config <path>) [--private] [--check] <repo> "<description>" [<repo> "<description>"]...`
  - It checks the token, each name and description, duplicates in the batch, and that no repo
    exists (`GET /repos/$RC_ORG/<repo>` gives 404). If any check fails, it exits 2 and creates
    nothing.
  - `--check` stops there and prints nothing.
  - Otherwise it runs `POST /orgs/$RC_ORG/repos` for each repo, with today's body, and prints
    `created <repo>`.
  - It no longer makes a first commit, calls `setup-repo.sh` or prints the pr-bot message.
  - `CREATE_REPO_SETUP` goes away. `CREATE_REPO_API` and `CREATE_REPO_GIT` stay; T006 uses
    `CREATE_REPO_GIT`.
- Produces: `fake-github.py` serves any org:
  - `GET /repos/<org>/<name>` gives 200 for `taken` and for repos it created, else 404.
  - `POST /orgs/<org>/repos` makes the bare repo `$FAKE_GIT_ROOT/<org>/<name>.git`.

**Acceptance criteria:**

- [ ] With `--config` for org `acme`, the POST goes to `/orgs/acme/repos` with the same body as
      today.
- [ ] `--check` creates nothing (the fake logs no POST), even when every repo is new.
- [ ] `alpha` named twice in one batch is refused before any request.
- [ ] Today's refusals still hold: no `GH_TOKEN`, no description, a bad name, and one existing repo
      in a batch. The token is never printed.
- [ ] `as-bot.test.sh` and `create-pr-bot.test.sh`, which share `fake-github.py`, still pass.

**Named test:** `bash scripts/tests/create-repo.test.sh`. **Layer:** `ouroboric`. **Size:** S.
**Depends on:** T001.

- [ ] **Step 1: Change the test.**
  - Write a fixture config, `$T/acme.json`, for org `acme` (licence `MIT`, copyright `Acme`).
  - Make `$T/git/acme` as well.
  - Remove the checks for the first commit, `setup.log`, `LICENSE` and `REUSE.toml`, and the pr-bot
    messages. T006 tests them now.
  - Add checks:
    - `"the repo is created in the config's org"`: the POST path is `/orgs/acme/repos`.
    - `"--check creates nothing"`: `posts` is unchanged after
      `create-repo.sh --config "$T/acme.json" --check delta "D."`.
    - `"a repo named twice is refused before any request"`: exit 2, and the log line count is
      unchanged.
    - `"no --org or --config is refused"`: exit 2.
  - Keep `"each repo is created public and empty…"` and `"every request carries the admin token"`.
- [ ] **Step 2: Run it.** Expected: the new checks FAIL, because the fake knows only `ouroboric-dev`
  and the script ignores `--config`.
- [ ] **Step 3: Implement.**
  - In `fake-github.py`, match `^/repos/([^/]+)/([^/]+)$` and `^/orgs/([^/]+)/repos$`, and keep
    `repos` as a set of `(org, name)`. `taken` exists in every org.
  - In `create-repo.sh`, source `repo-config.sh`, take the org from `RC_ORG`, add `--check` and the
    duplicate check, and remove the first commit, the `SETUP` call and the messages. Update the
    header: it creates empty repos, and `new-repo.sh` is the normal way to run it.
- [ ] **Step 4: Run** `create-repo.test.sh`, `as-bot.test.sh` and `create-pr-bot.test.sh`. Expected:
  every line `ok`.
- [ ] **Step 5: Commit.** Stage the three files. Message: "create-repo.sh: create only, in the
  config's org (repo-bootstrap-T002)".

### Task repo-bootstrap-T003: add-licences.sh writes the licence files

**Files (in `ouroboric`):**

- Create: `scripts/add-licences.sh`
- Test: `scripts/tests/add-licences.test.sh`

**Interfaces:**

- Consumes: T001's `RC_LICENCE`, `RC_DOCS_LICENCE`, `RC_DOCS_PATHS`, `RC_COPYRIGHT`,
  `RC_LICENCE_DIR`.
- Produces: `add-licences.sh (--org <name>|--config <path>) [--year <yyyy>] (--check | <dir>)`.
  - It writes `LICENSES/<licence>.txt`, `LICENSES/<docs_licence>.txt` (if set), `LICENSE` (a copy
    of the code licence's text) and `REUSE.toml` into `<dir>`. `<dir>` must exist.
  - If any of these exists, it exits 2 and writes nothing.
  - With `licence_dir`, it copies `<licence_dir>/<id>.txt`. A missing text exits 2.
  - Without `licence_dir`, it runs `$REUSE download <id>` inside `<dir>`. `REUSE` is
    `${ADD_LICENCES_REUSE:-uvx -q --from reuse==5.0.2 reuse}`, split on spaces.
  - `--check` checks that each text can be found (`licence_dir` has it, or `uvx` is on `PATH`) and
    writes nothing.
  - `--year` defaults to `date +%Y` and must be four digits.
- `REUSE.toml` is today's text, with the values filled in:

```toml
version = 1

[[annotations]]
path = ["**"]
precedence = "closest"
SPDX-FileCopyrightText = "<year> <copyright>"
SPDX-License-Identifier = "<licence>"

[[annotations]]
path = [<docs paths>]
precedence = "closest"
SPDX-FileCopyrightText = "<year> <copyright>"
SPDX-License-Identifier = "<docs_licence>"
```

  Without `docs_licence`, the file ends after the first annotation, with no blank line after it.

**Acceptance criteria:**

- [ ] With `--org ouroboric-dev --year 2026`, the folder holds exactly `LICENSE`,
      `LICENSES/AGPL-3.0-only.txt`, `LICENSES/CC-BY-4.0.txt` and `REUSE.toml`. `REUSE.toml` is byte
      for byte the heredoc in today's `create-repo.sh`. `LICENSE` equals the AGPL text.
- [ ] A one-licence config gives one annotation and one text.
- [ ] Without `licence_dir`, the texts come from the `reuse download` command (a stub in the test).
- [ ] An existing `REUSE.toml`, or a text missing from `licence_dir`, exits 2 with nothing written.
- [ ] The ouroboric-dev result passes `uvx -q --from 'reuse==5.0.2' reuse lint`, after `git init`.

**Named test:** `bash scripts/tests/add-licences.test.sh`. **Layer:** `ouroboric`. **Size:** M.
**Depends on:** T001.

- [ ] **Step 1: Write the failing test.**
  - The golden `REUSE.toml` is a heredoc, copied from `create-repo.sh` at `main`, compared with
    `cmp -s`.
  - The stub `reuse` is a script in `$T/bin` that writes `TEXT <id>` to `LICENSES/<id>.txt`. It is
    used with `ADD_LICENCES_REUSE="$T/bin/reuse"`.
  - Cases, as in the acceptance criteria:
    - `"ouroboric-dev: the four files"`;
    - `"REUSE.toml is today's, byte for byte"`;
    - `"LICENSE is the AGPL text"`;
    - `"one licence: one annotation"`;
    - `"no licence_dir: reuse download"`;
    - `"an existing REUSE.toml: nothing is written"`;
    - `"a missing text: nothing is written"`;
    - `"--check writes nothing"`;
    - `"reuse lint passes"`.
- [ ] **Step 2: Run it.** Expected: FAIL, because there is no script yet.
- [ ] **Step 3: Implement `scripts/add-licences.sh`.** Write `REUSE.toml` with `printf` from the
  `RC_*` values. Before writing, check every target path (`LICENSE`, `REUSE.toml`, each
  `LICENSES/<id>.txt`).
- [ ] **Step 4: Run it.** Expected: every line `ok`. Then run shellcheck.
- [ ] **Step 5: Commit.** Stage `scripts/add-licences.sh` and `scripts/tests/add-licences.test.sh`.
  Message: "add-licences.sh: the licence files from the org config (repo-bootstrap-T003)".

### Task repo-bootstrap-T004: add-ci.sh and the base CI pieces

**Files (in `ouroboric`):**

- Create: `scripts/add-ci.sh` and `scripts/templates/ci/README.md`
- Create: `scripts/templates/ci/lint.yml`
- Create, in `scripts/templates/ci/pieces/`: `gitleaks.yaml`, `reuse.yaml`, `markdown.yaml`,
  `shell.yaml`, `actions.yaml` and `yaml.yaml`
- Create: `scripts/templates/ci/pieces/markdown.files/.markdownlint.yaml` and
  `scripts/templates/ci/pieces/yaml.files/.yamllint.yaml`
- Test: `scripts/tests/add-ci.test.sh`

**Interfaces:**

- Consumes: T001's `RC_CI`.
- Produces: `add-ci.sh (--org <name>|--config <path>) [--ci <piece>,...] (--check | <dir>)`.
  - **The pieces.** They come from `--ci`, or else from `RC_CI`. The list is split on commas, and an
    empty item exits 2. Repeated names are kept once, in first-seen order. `gitleaks` goes first if
    it is not listed.
  - **The pieces folder** is `${ADD_CI_PIECES:-<dir of add-ci.sh>/templates/ci/pieces}`.
  - **Validation.** Each piece's file `<name>.yaml` must exist and follow the contract below. If not,
    it exits 2 and names the piece and the rule it breaks.
  - **What it writes:**
    - `<dir>/.pre-commit-config.yaml`: the line `repos:`, then each piece file in list order;
    - `<dir>/.github/workflows/lint.yml`: a copy of `templates/ci/lint.yml`;
    - the contents of each `<name>.files/` folder, copied into `<dir>`.

    If any target exists, it exits 2 and writes nothing.
  - **`--check`** validates and writes nothing.
- **The piece contract**, which `templates/ci/README.md` documents and `add-ci.sh` enforces:
  - one file per piece; its name without `.yaml` is the piece's name (`^[a-z0-9-]+$`);
  - exactly one line matching `^  - repo: https://`;
  - exactly one line matching `^    rev:` followed by one space, whose value matches
    `^v?[0-9]+(\.[0-9]+)+([.-][0-9A-Za-z]+)*$`;
  - a line `^    hooks:`;
  - no tabs.

  A piece may have a `<name>.files/` folder. Its files must not clash with another piece's. The
  README also says realms will ship their own pieces in this format later (the proposal's future
  work, item 3).

**Acceptance criteria:**

- [ ] `--org ouroboric-dev` writes three files: `.pre-commit-config.yaml`, with the repos gitleaks,
      reuse-tool, markdownlint-cli2 and actionlint, in that order; `lint.yml`; and `.markdownlint.yaml`.
- [ ] `--ci shell` gives gitleaks then shellcheck-py. `--ci gitleaks,gitleaks` gives one gitleaks
      entry.
- [ ] Each of these exits 2 with nothing written:
  - an unknown piece;
  - an empty item;
  - an existing `.pre-commit-config.yaml`;
  - a fixture piece with two `repo:` lines;
  - a fixture piece with `rev: main`.
- [ ] Every shipped piece passes the contract.
- [ ] **The real run.** These run on a git repo that holds `add-licences.sh`'s ouroboric-dev files
      plus `add-ci.sh --ci reuse,markdown,shell,actions,yaml`, in one commit:
  - `uvx -q --from 'pre-commit==4.6.2' pre-commit validate-config` passes;
  - `pre-commit run --all-files` passes;
  - `pre-commit run --hook-stage manual gitleaks-history --all-files` passes;
  - after a second commit adds a generated GitHub-token-shaped string, the history run fails.

**Named test:** `bash scripts/tests/add-ci.test.sh`. The real run needs the network and Go the
first time, as the gitleaks hook already does. **Layer:** `ouroboric`. **Size:** M.
**Depends on:** T001, T003 (the real run uses `add-licences.sh`).

- [ ] **Step 1: Write the failing test.** Follow the acceptance criteria.
  - Read the repos order with `grep '^  - repo:' .pre-commit-config.yaml`.
  - Make the fake secret at run time, so this repo's own gitleaks hook never sees it:
    `printf 'token = "ghp_%s"\n' "$(head -c 18 /dev/urandom | od -An -tx1 | tr -d ' \n')"`.
- [ ] **Step 2: Run it.** Expected: FAIL, because there is no script yet.
- [ ] **Step 3: Write the pieces.** Write exactly these.

`gitleaks.yaml`:

```yaml
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.30.1
    hooks:
      - id: gitleaks
      - id: gitleaks
        alias: gitleaks-history
        name: Detect hardcoded secrets in the whole history
        entry: gitleaks git --redact --verbose
        stages: [manual]
```

`reuse.yaml`:

```yaml
  - repo: https://github.com/fsfe/reuse-tool
    rev: v5.0.2
    hooks:
      - id: reuse
```

`markdown.yaml`:

```yaml
  - repo: https://github.com/DavidAnson/markdownlint-cli2
    rev: v0.23.3
    hooks:
      - id: markdownlint-cli2
```

`shell.yaml`:

```yaml
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: v0.11.0.1
    hooks:
      - id: shellcheck
```

`actions.yaml`:

```yaml
  - repo: https://github.com/rhysd/actionlint
    rev: v1.7.12
    hooks:
      - id: actionlint
```

`yaml.yaml`:

```yaml
  - repo: https://github.com/adrienverge/yamllint
    rev: v1.38.0
    hooks:
      - id: yamllint
```

`markdown.files/.markdownlint.yaml` (house style: long lines and tables, repeated headings such as
"Added" under different parents):

```yaml
default: true
MD013: false
MD024:
  siblings_only: true
```

`yaml.files/.yamllint.yaml`:

```yaml
extends: default
rules:
  line-length:
    max: 120
  document-start: disable
  truthy:
    check-keys: false
```

- [ ] **Step 4: Write `scripts/templates/ci/lint.yml`** exactly:

```yaml
# The base CI: the required check "lint". It runs the repo's pre-commit hooks on every file, then
# gitleaks over the whole history. Written by ouroboric/scripts/add-ci.sh; change the hooks in
# .pre-commit-config.yaml, not here.
name: lint
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  lint:
    runs-on: ubuntu-24.04
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
        with:
          persist-credentials: false
          fetch-depth: 0
      - uses: actions/setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97  # v7.0.0
        with:
          python-version: "3.13"
      - name: install pre-commit
        run: pip install pre-commit==4.6.2
      - name: hooks
        run: pre-commit run --all-files --show-diff-on-failure
      - name: gitleaks over the history
        run: pre-commit run --hook-stage manual gitleaks-history --all-files
```

- [ ] **Step 5: Implement `scripts/add-ci.sh`** and write `scripts/templates/ci/README.md`. The
  README covers the contract, the piece list with one line each, `--ci`, and how to bump a pin (a
  reviewed PR; the release must be at least two weeks old).
- [ ] **Step 6: Run it.** Expected: every line `ok`. If `pre-commit validate-config` refuses the
  `entry` override on `gitleaks-history`, stop and report it. The design depends on it. Then run
  shellcheck on `scripts/add-ci.sh`.
- [ ] **Step 7: Commit.** Stage every file listed above by path. Message: "add-ci.sh: a pre-commit
  base CI from pinned pieces (repo-bootstrap-T004)".

### Task repo-bootstrap-T005: setup-repo.sh requires lint and test, for any org

**Files (in `ouroboric`):**

- Modify: `scripts/setup-repo.sh` and `scripts/check-repos.sh` (`check_ruleset` only)
- Test: `scripts/tests/setup-repo.test.sh` and `scripts/tests/check-repos.test.sh`

**Interfaces:**

- Consumes: T001's `RC_ORG` and `RC_ISSUES_ON`.
- Produces: `GH_TOKEN=... setup-repo.sh (--org <name>|--config <path>) <repo>`. It does the same as
  today, with three changes:
  - `R` is `repos/$RC_ORG/<repo>`.
  - Issues are on when `<repo>` is in `RC_ISSUES_ON`.
  - For each pair in the fixed map `lint.yml:lint ci.yml:test`, it looks up
    `contents/.github/workflows/<file>`:
    - found: it requires the job;
    - HTTP 404: it skips the job;
    - any other failure: it exits 1, with the ruleset unchanged.

    The found jobs make one `required_status_checks` rule, in map order, with
    `integration_id` 15368 and `strict` true. No found job means no such rule.
- Produces: `check-repos.sh`'s `check_ruleset` builds its expected rules from the same map. It sorts
  the contexts before comparing (`[…]|sort|join("+")`), so the order the API returns doesn't matter.
  `check-repos.sh` stays Ouroboric's own, with `ORG=ouroboric-dev`.

**Acceptance criteria:**

- [ ] `setup-repo.sh` requires:
  - nothing, with no workflow;
  - `lint` only, with `lint.yml` only;
  - `test` only, with `ci.yml` only;
  - `lint` and `test`, with both.

  Each check comes from app 15368, on a strict branch.
- [ ] A 500 on either lookup stops the script, and no ruleset is written.
- [ ] `--config` with org `acme` writes to `repos/acme/...`. `--org ouroboric-dev` still turns
      issues on for `yggdrasil` and `asgard` only.
- [ ] `check-repos.sh --check ruleset` passes `lint` and `lint+test` when they are required, and fails
      when `lint.yml` exists but `lint` is not required, or `lint` is required with no `lint.yml`.
      Today's cases still pass.

**Named test:** `bash scripts/tests/setup-repo.test.sh` and `bash scripts/tests/check-repos.test.sh`.
**Layer:** `ouroboric`. **Size:** M. **Depends on:** T001.

- [ ] **Step 1: Change the tests.**
  - In `setup-repo.test.sh`:
    - Pass `--org ouroboric-dev` to the existing calls.
    - Add an `acme` fixture config, the cases `lint only`, `ci only`, `both` and `lint lookup fails`,
      and an org check on the PATCH path.
    - Generalise `has_check` to `has_checks <context>...`, which compares the sorted contexts of the
      one `required_status_checks` rule.
  - In `check-repos.test.sh`:
    - Extend `repo()` to `repo <name> <workflows: none|lint|ci|both> <rules>`.
    - Add `LINT` and `BOTH` rule JSON, and the four new cases.
- [ ] **Step 2: Run both.** Expected: the new cases FAIL.
- [ ] **Step 3: Implement** the changes in the two scripts. Update `setup-repo.sh`'s header: the
  usage line, and the map's rule.
- [ ] **Step 4: Run both.** Expected: every line `ok`. Then run shellcheck on `setup-repo.sh`.
- [ ] **Step 5: Commit.** Stage the four files. Message: "setup-repo.sh: require lint and test, in the
  config's org (repo-bootstrap-T005)".

### Task repo-bootstrap-T006: new-repo.sh, the one command, and its docs

**Files (in `ouroboric`):**

- Create: `scripts/new-repo.sh`
- Modify: `docs/4-ways-of-working/docs-standard.md` (the bullets on creating and setting up repos)
  and `AGENTS.md` (the scripts table and the founder-only line)
- Test: `scripts/tests/new-repo.test.sh`

**Interfaces:**

- Consumes: `create-repo.sh` (T002), `add-licences.sh` (T003) and `add-ci.sh` (T004), each with its
  `--check`; `setup-repo.sh` (T005); and `repo_config_args`, `repo_config_load`,
  `repo_after_create` and `RC_FROM` (T001).
- Produces: `GH_TOKEN=... new-repo.sh (--org <name>|--config <path>) [--private] [--ci <piece>,...] <repo> "<description>" [<repo> "<description>"]...`
  1. `exec </dev/null`. Export `GIT_TERMINAL_PROMPT=0`. Check that `GH_TOKEN` is set, or exit 2.
  2. Load the config. Run `create-repo.sh "${RC_FROM[@]}" [--private] --check <pairs>`, then
     `add-licences.sh "${RC_FROM[@]}" --check` and `add-ci.sh "${RC_FROM[@]}" [--ci …] --check`. If
     any fails, exit with its code and create nothing.
  3. For each repo, in order:
     1. Run `create-repo.sh` for that repo alone.
     2. In a fresh `mktemp -d` folder: `git init -q -b main`, then `add-licences.sh`, then
        `add-ci.sh`.
     3. Add all files, then `git commit -q -m "Licences and base CI"`.
     4. Push `main` to `${CREATE_REPO_GIT:-https://github.com}/$RC_ORG/<repo>.git`, with today's
        credential helper.
     5. Run `${NEW_REPO_SETUP:-<dir>/setup-repo.sh} "${RC_FROM[@]}" <repo>`.
  4. **Output.** After each step it prints `new-repo: <repo>: created`, `… first commit pushed` and
     `… protected`. After the repo is protected, it prints `repo_after_create public|private <repo>`.
  5. **Failure.** If a step fails after the create, it prints this to stderr, then exits with that
     step's code (non-zero):
     `new-repo: <repo> was created, but <step> failed. It is not protected and agents must not get it yet. Delete it, or push a first commit and run setup-repo.sh.`

**Acceptance criteria:**

- [ ] With `--org ouroboric-dev` against the fakes, two repos are created. Each `main` holds one
      commit with exactly these files:
  - `.github/workflows/lint.yml`, `.markdownlint.yaml` and `.pre-commit-config.yaml`;
  - `LICENSE`, `LICENSES/AGPL-3.0-only.txt`, `LICENSES/CC-BY-4.0.txt` and `REUSE.toml`.

  The setup stub runs once per repo, after its commit. The pr-bot message appears for a public repo,
  and the "Never add" message for `--private`.
- [ ] An existing repo, an unknown `--ci` piece, a bad config or no `GH_TOKEN` exits non-zero. The
      fake logs no POST.
- [ ] A failed push exits non-zero. The setup stub never runs, and stderr names the repo and says
      "not protected".
- [ ] Input on stdin never reaches a step: the setup stub reads an empty stdin.
- [ ] The token never appears in stdout or stderr.
- [ ] The docs standard says:
  - the founder runs `new-repo.sh --org <org>`, with one token: fine-grained, short-lived, owned by
    the org, with Administration, Contents and Workflows read and write;
  - the base CI and its pieces;
  - the convention: `lint.yml` has the required job `lint`, and `ci.yml` has the required job
    `test`;
  - another org copies `scripts/orgs/ouroboric-dev.json`.

  `AGENTS.md` lists `new-repo.sh`, `add-licences.sh` and `add-ci.sh` as founder-run.

**Named test:** `bash scripts/tests/new-repo.test.sh`. **Layer:** `ouroboric`. **Size:** M.
**Depends on:** T002, T003, T004, T005.

- [ ] **Step 1: Write the failing test.**
  - Start `fake-github.py` and the bare-repo root as `create-repo.test.sh` does.
  - The setup stub appends `"$repo $(git rev-list --count main) $(cat | wc -c)"` to
    `$T/setup.log`. The last field proves stdin was empty.
  - Run `new-repo.sh` with `<<<"typed input"`, so the stdin check means something.
  - The checks follow the acceptance criteria. The file list is compared with
    `git ls-tree -r --name-only main`.
  - For the failed push, set `CREATE_REPO_GIT` to a `file://` path with no bare repo.
- [ ] **Step 2: Run it.** Expected: FAIL, because there is no script yet.
- [ ] **Step 3: Implement `scripts/new-repo.sh`.** Move the credential-helper push from today's
  `create-repo.sh` here unchanged.
- [ ] **Step 4: Run it**, then the whole suite. Expected: every line `ok`. Then run shellcheck.
- [ ] **Step 5: Update the docs.**
  - In `docs-standard.md`, replace the "founder creates repos" and "founder sets up existing repos"
    bullets with three: `new-repo.sh`, the separate steps (each runnable alone), and the base CI and
    its convention.
  - In `AGENTS.md`, add the rows and the founder-only names.
- [ ] **Step 6: Commit.** Stage `scripts/new-repo.sh`, `scripts/tests/new-repo.test.sh`,
  `docs/4-ways-of-working/docs-standard.md` and `AGENTS.md`. Message: "new-repo.sh: create, lint and
  protect a repo in one command (repo-bootstrap-T006)".

### Task repo-bootstrap-T007: the scaffold builds on new-repo.sh's first commit

**Files (in `ouroboric`):**

- Modify: `scripts/scaffold-component.sh`
- Delete: `scripts/templates/go-component/pre-commit-config.yaml.tmpl`
- Test: `scripts/tests/scaffold-component.test.sh`

**Interfaces:**

- Consumes: T006's first commit, which already holds `.pre-commit-config.yaml` with gitleaks.
- Produces: `scaffold-component.sh` no longer writes `.pre-commit-config.yaml`. Its first-commit
  check also requires `.pre-commit-config.yaml` holding `repo: https://github.com/gitleaks/gitleaks`.
  Its error says "doesn't hold new-repo.sh's first commit". The header names `new-repo.sh`.

**Acceptance criteria:**

- [ ] On a folder laid out like new-repo.sh's first commit, the scaffold writes its files, apart from
      `.pre-commit-config.yaml`, which stays as it was.
- [ ] A folder with no `.pre-commit-config.yaml` is refused with exit 2.
- [ ] The README still says to run `uvx pre-commit install`.

**Named test:** `bash scripts/tests/scaffold-component.test.sh`. **Layer:** `ouroboric`. **Size:** S.
**Depends on:** T006.

- [ ] **Step 1: Change the test.**
  - `newrepo()` also writes `.pre-commit-config.yaml` from `scripts/templates/ci/pieces/gitleaks.yaml`,
    with a leading `repos:` line, and commits it.
  - The expected untracked list drops `?? .pre-commit-config.yaml`.
  - Add `"a folder without .pre-commit-config.yaml is refused"`.
  - Rename the create-repo wording to new-repo.
- [ ] **Step 2: Run it.** Expected: FAIL, because the scaffold stops on the existing file.
- [ ] **Step 3: Implement.** Drop the template from `FILES`, extend the first-commit check, update
  the header, and remove the template with `git rm`.
- [ ] **Step 4: Run it**, then the whole suite. Expected: every line `ok`.
- [ ] **Step 5: Commit** the three paths. Message: "scaffold-component.sh: build on new-repo.sh's
  first commit (repo-bootstrap-T007)". Then push and open the PR, as in "How each task lands".

### Task repo-bootstrap-H01 (founder): one real run, and the token question settled

**Acceptance criteria:**

- [ ] A throwaway public repo, `bootstrap-trial`, is created with
      `GH_TOKEN=... scripts/new-repo.sh --org ouroboric-dev bootstrap-trial "Trial of new-repo.sh."`.
      The run is non-interactive and exits 0.
- [ ] On GitHub, `lint` passed on `main`. A pull request shows `lint` as required, and can't merge
      until it passes.
- [ ] `GH_TOKEN=... scripts/check-repos.sh --check settings --check security --check ruleset bootstrap-trial`
      passes, run with the founder's token, because the pr-bot is not installed there.
- [ ] The docs standard records which repository access the token needed.
- [ ] `bootstrap-trial` is deleted, and was never added to the pr-bot.

**Named test:** the checks above, with their output pasted into the PR that records the result.
**Layer:** GitHub. **Size:** S. **Depends on:** T007 merged.

- [ ] **Step 1 (founder): Make a fine-grained token.**
  - Owner: `ouroboric-dev`. Expiry: one day.
  - Repository access: "Only select repositories", picking any one existing repo.
  - Permissions: Administration, Contents and Workflows read and write.
- [ ] **Step 2 (founder): Run `new-repo.sh`** with that token. If it fails, make a second token with
  "All repositories" and the same permissions, and note which step failed with the first. Any repo
  the failed run created is unprotected, so delete it before you go on.
- [ ] **Step 3 (founder): Check the result.** Open a pull request on `bootstrap-trial` from the web UI
  (edit `REUSE.toml`'s comment, say). Confirm that `lint` is required, then close it. Run
  `check-repos.sh`.
- [ ] **Step 4 (founder): Delete `bootstrap-trial`** and revoke the token.
- [ ] **Step 5 (agent):** from the founder's notes, update the token sentence in `docs-standard.md`
  and `new-repo.sh`'s header ("All repositories" or "selected repositories"). Open a PR.
