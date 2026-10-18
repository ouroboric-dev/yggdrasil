---
title: Tasks for the base CI on every existing non-realm repo
status: proposed
date: 2026-10-18
related: [proposal.md, delta.md]
style: spec
---

# Base CI rollout: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking. Tasks and steps marked **founder** are done by the founder,
> never by an agent.

**Goal:** the ten existing public non-realm repos get the full base CI, with every file passing it
and `lint` required. The founder's part is two commands, each covering every repo, plus reviews and
merges.

**Architecture:**

- **Tooling** lands first, in one `ouroboric` PR. It holds the shared markdownlint bends, an
  `--upgrade` path in `add-ci.sh`, a formatting-only checker (`md-same-text.sh`) and the founder's
  script (`rollout-ci.sh`, with `push` and `protect` modes).
- **Each repo** is then prepared by an agent on a `base-ci` branch, in a fresh clone under
  `ROLLOUT_ROOT`. The founder pushes those branches and protects the merged repos.
- **The umbrellas** get their formatting fixes first, in pr-bot PRs.

**Tech stack:**

- bash, `jq`, `git`, `gh api`, and `as-bot.sh` for the pr-bot;
- `uvx` for `pre-commit==4.6.2`, `shellcheck-py==0.11.0.1` and `markdown-it-py==3.0.0`;
- `markdownlint-cli2` v0.23.3 and yamllint v1.38.0, through their pre-commit hooks.

**Spec:** [proposal](proposal.md) and [delta](delta.md). Read both. The recon counts below were
measured on 2026-10-18 and are what this plan was sized against.

## Decisions made by this plan

These settle what the proposal left to the builder. Each follows the founder's rule: bend the linter
when the house style has a real reason, otherwise change the files to the default.

| Finding | Decision | Reason |
|---|---|---|
| MD010 tabs in code blocks | bend: `MD010: {code_blocks: false}` | gofmt requires tabs; the plan tools copy plan code verbatim |
| MD033 `<picture>`, `<source>`, `<img>` | bend: `allowed_elements` | the docs standard prescribes `<picture>` for themed images; the org profile opens with `<img>` |
| MD041 first line not an H1 | bend: `MD041: false` | the formats that open without an H1 are deliberate: journal entries (front matter, then `##` sections), PR templates, Claude skill files, the org profile banner. Every other doc's title is already checked by the docs standard's front matter rule |
| MD022, MD032, MD034, MD060 | default (`--fix`) | `--fix` clears nearly all of them; the habit carries no value |
| MD036 bold lines used as headings (yggdrasil research) | default: real headings | a heading is what they are; the text stays the same |
| MD040 code fence without a language | default: add one (`text` when nothing fits) | cheap, and it renders better |
| MD059 link text "link" | default | one case |
| `<issue>`-style placeholders in `.github`'s PR template | default: wrap them in backticks | they are placeholders, not HTML |
| odin `testdata/` (YAML fixtures, prompt `.md`) | bend: excluded from markdownlint and yamllint | test inputs read by code |
| ouroboric `scripts/templates/ci/pieces/*.yaml` | bend: excluded from yamllint | fragments indented for `repos:` by the piece contract, not YAML documents |
| gleipnir `scan/scan.sh` (shellcheck can't parse it) | default: make the template parse | the `@CONFIG@` placeholder sits on the heredoc's opening line; see T007 |
| shellcheck info notes (SC2329, SC2015, SC2016) | per file or per line `disable`, each with its reason, as the repo-bootstrap tests do | the house idioms (functions called by name, `cond && ok \|\| bad` reporting, literal single quotes) are deliberate; a global disable would hide real cases elsewhere |
| SC1091, SC2155, SC2012, SC2086, SC2116 | default: fix the code (`source-path=SCRIPTDIR` directive, split `local`, glob or `find`, quote, drop `echo`) | real fixes, all small |
| yamllint `comments` and `line-length` in leaves' `ci.yml`, `.github`'s issue form | default | two spaces before a comment; fold the long lines |

More decisions:

- **The exclusion mechanism.** An exclusion goes in a repo-owned file, never in the shared copies.
  - markdownlint: `.markdownlint-cli2.yaml` holding only `ignores:`. markdownlint-cli2 still reads
    the rules from `.markdownlint.yaml`. T001's test proves this.
  - yamllint: `.yamllint`, holding `extends: .yamllint.yaml` and `ignore:`. yamllint reads `.yamllint`
    before `.yamllint.yaml`. T001's test proves this.
  - If either mechanism fails its test, stop and report.
- **The upgrade trigger is a flag, `--upgrade`.** It is explicit, so a normal run never replaces a
  file. The known file is shipped as `scripts/templates/ci/upgrade/gitleaks-only.yaml`. It equals the
  old scaffold template, `git show a6be975:scripts/templates/go-component/pre-commit-config.yaml.tmpl`
  (sha256 `7119399c9a531c4a…`), which is what all ten repos and the three realms hold.
- **The script is `rollout-ci.sh`.** Its modes are `push` and `protect`. The branch is `base-ci`.
  The clones live in `${ROLLOUT_ROOT:-<dir of rollout-ci.sh>/../../rollout}/<repo>`, which is
  `/home/brunogbv/brunogbv/ouroboric/rollout/<repo>` here. These are fresh clones, never a checkout
  another session uses.
- **The formatting-only proof is `md-same-text.sh`.** It is reusable, so it goes in
  `ouroboric/scripts` with a test. For every Markdown file that changed between two refs:
  - the rendered text must be equal once whitespace is collapsed;
  - every fenced code block's contents must be byte-identical.

  The second rule is the plan-code guarantee. It is stronger than running `plan-blocks.py`, which
  needs a workspace per plan.
- **The small repos ship their fixes in the same PR as `lint.yml`.** Their fixes are a few lines. The
  umbrellas ship theirs first.
- **`check-repos.sh` gets one line.** Its 17 shellcheck notes (SC2015, SC2329) would fail
  `ouroboric`'s `lint`. The realm-readiness session (`ouroboric-6e`) is changing that file, so T008
  adds one file-level `# shellcheck disable=SC2015,SC2329` line with its reason, after that session's
  change merges. Its rules are not touched. This is the one departure from the proposal's "leaves it
  alone", and it is coordinated by message first.

## Global constraints

- Scripts:
  - start with `#!/usr/bin/env bash` and `set -euo pipefail`;
  - have a header that says what the script does, who runs it, and its usage line;
  - exit 2 through `die()` on input errors;
  - have `# shellcheck source-path=SCRIPTDIR` when they source `repo-config.sh`.
- `GH_TOKEN` is the only way a token comes in. No script prints it, puts it in a command line, or
  writes it to a file. Git gets it only through the inline credential helper that `new-repo.sh` uses.
- Pins, exact:
  - the hooks: as in `scripts/templates/ci/pieces/`;
  - `pre-commit==4.6.2`, `shellcheck-py==0.11.0.1` and `reuse==5.0.2`;
  - `markdown-it-py==3.0.0`, run as `uvx -q --with 'markdown-it-py==3.0.0' python3 -I`.
- The pieces: `reuse,markdown,shell,actions,yaml` for every repo. gitleaks is always first.
- **Fixes are formatting only.** Rewording is not a fix. `md-same-text.sh` must pass on every
  Markdown change.
- Nothing is excluded from gitleaks or reuse. Exclusions are only the three in the decisions table.
- Tests follow `scripts/tests/*.test.sh`: a `mktemp -d` folder removed by `trap`, the `check` helper,
  and `exit $fail`. New and changed scripts and tests pass the pinned shellcheck from the repo root.
- Agents push only through `scripts/as-bot.sh`, never to `main`, and never anything under
  `.github/workflows/`. Only the founder runs `rollout-ci.sh`.
- Stage by explicit path. No `rm` in compound commands. Never read or search `../ouroboric-private/`.

## Review focus

1. **A repo's `.pre-commit-config.yaml` differs from the known file by one byte.** For example, a
   person added a hook. `--upgrade` must refuse it, with exit 2, and write nothing (T002).
2. **`protect` runs on a repo whose PR isn't merged yet.** It must skip that repo and name it, and
   never call `setup-repo.sh` (T004).
3. **`push` runs a second time after a rebase.** It must update the remote branch with a lease and
   reuse the open PR. It must never open a second PR, and never overwrite a remote branch someone
   else moved (T004).
4. **`--fix` changes the code inside a fence.** For example, tabs in a plan, or a list inside a code
   block. `md-same-text.sh` must fail on any code-block byte change, even one that is whitespace only
   (T003).
5. **A repo-local exclusion silently stops the shared rules from applying**, so the folder that should
   be linted isn't. T001's test must show that a non-excluded file is still flagged when a
   `.markdownlint-cli2.yaml` or `.yamllint` is present.

## How each task lands

- **T001–T004** are in `ouroboric`, on branch `base-ci-tooling`, in a worktree
  (`git -C ouroboric worktree add ../ouroboric-base-ci -b base-ci-tooling origin/main`). There is one
  commit per task. After T004, push with `as-bot.sh` and open one PR. The pr-bot can push it, because
  nothing in it is under `.github/workflows/`. **T005 onwards need that PR merged**, because the
  repos must get the final configs.
- **T005–T009** each prepare `base-ci` branches in `$ROLLOUT_ROOT/<repo>`:
  `git clone https://github.com/ouroboric-dev/<repo>.git` then `git switch -c base-ci`. Each repo
  ends with this, run in its clone:

  ```bash
  uvx -q --from 'pre-commit==4.6.2' pre-commit run --all-files
  uvx -q --from 'pre-commit==4.6.2' pre-commit run --hook-stage manual gitleaks-history --all-files
  /home/brunogbv/brunogbv/ouroboric/ouroboric/scripts/md-same-text.sh origin/main HEAD
  ```

  All three must exit 0.
- The ledger records each repo's branch head.

---

### Task base-ci-T001: the shared markdownlint bends, and proof that exclusions keep the rules

**Files (in `ouroboric`):**
- Modify: `scripts/templates/ci/pieces/markdown.files/.markdownlint.yaml`,
  `scripts/templates/ci/README.md`
- Test: `scripts/tests/lint-config.test.sh` (new)

**Interfaces:**
- Produces: the final shared `.markdownlint.yaml`, which every later task relies on:

  ```yaml
  default: true
  MD013: false
  MD024:
    siblings_only: true
  MD025:
    front_matter_title: ""
  ```

  It gains three settings, each with a one-line `#` comment that gives the reason from the decisions
  table:
  - `MD010` with `code_blocks: false`;
  - `MD033` with `allowed_elements: [picture, source, img]`;
  - `MD041: false`.
- Produces: the two exclusion mechanisms, as tested file shapes (see the decisions).

**Acceptance criteria:**
- [ ] A tab inside a fenced Go block passes. A tab in prose fails.
- [ ] `<picture>` passes. `<div>` fails.
- [ ] A file that opens with `## Challenge` after front matter passes.
- [ ] A repo with `.markdownlint-cli2.yaml` (`ignores: ["testdata/**"]`) skips `testdata/x.md`, which
      breaks a rule. A broken `docs/y.md` in the same repo still fails. This proves the shared rules
      still load.
- [ ] A repo with `.yamllint` (`extends: .yamllint.yaml`, `ignore: testdata/`) skips
      `testdata/x.yaml`. A broken `y.yaml` still fails, on a rule from the shared `.yamllint.yaml`
      (`line-length` over 120).
- [ ] The README's markdown row lists each bend and its reason.

**Named test:** `bash scripts/tests/lint-config.test.sh`. It is a real run: it needs the network the
first time, as `add-ci.test.sh` does. **Size:** S.

- [ ] **Step 1: Write the failing test.**
  - Each case builds a git repo in `$T`: `add-ci.sh --org ouroboric-dev --ci markdown,yaml`, the
    fixture files, `git add`, then `pre-commit run --all-files`. It checks the exit code, and greps
    the output for the rule id where a case must fail.
  - Cases:
    - `"a tab in a Go code block passes"`;
    - `"a tab in prose fails"`;
    - `"<picture> passes"`;
    - `"<div> fails"`;
    - `"a journal-style file without an H1 passes"`;
    - `"markdownlint-cli2 ignores skip testdata and keep the shared rules"`;
    - `"a .yamllint that extends the shared config skips testdata and keeps its rules"`.
- [ ] **Step 2: Run it.** Expected: the three bend cases fail. The two exclusion cases pass already
  or fail, and either result is information. If an exclusion case can't be made to pass in Step 4,
  stop and report.
- [ ] **Step 3: Implement** the three settings with their comments, and the README lines.
- [ ] **Step 4: Run it**, then `add-ci.test.sh` and `scaffold-component.test.sh`, which use the same
  config. Expected: every line `ok`.
- [ ] **Step 5: Commit.** "Base CI: markdownlint bends for the house style, with reasons
  (base-ci-T001)".

### Task base-ci-T002: add-ci.sh --upgrade replaces the known gitleaks-only config

**Files (in `ouroboric`):**
- Create: `scripts/templates/ci/upgrade/gitleaks-only.yaml`, byte for byte
  `git show a6be975:scripts/templates/go-component/pre-commit-config.yaml.tmpl`
- Modify: `scripts/add-ci.sh`, `scripts/templates/ci/README.md`
- Test: `scripts/tests/add-ci.test.sh`

**Interfaces:**
- Produces: `add-ci.sh (--org|--config) [--ci <piece>,...] [--upgrade] (--check | <dir>)`.
  - With `--upgrade`, an existing `<dir>/.pre-commit-config.yaml` is allowed only if
    `cmp -s` finds it equal to `templates/ci/upgrade/gitleaks-only.yaml`. It is then replaced.
  - Every other target must still not exist. A different existing config exits 2 and writes nothing:
    `add-ci: <dir>/.pre-commit-config.yaml is not the known gitleaks-only file; nothing was written`.
  - `--check --upgrade` checks the same thing without writing.
  - Without `--upgrade`, behaviour is unchanged.

**Acceptance criteria:**
- [ ] With `--upgrade`, a folder holding the known file ends up with the full config, `lint.yml` and
      the piece files.
- [ ] With `--upgrade`, a known file plus one extra hook line exits 2. So does the known file with a
      trailing blank line added. Both write nothing.
- [ ] Without `--upgrade`, the known file still exits 2.
- [ ] `sha256sum templates/ci/upgrade/gitleaks-only.yaml` starts with `7119399c9a531c4a`.

**Named test:** `bash scripts/tests/add-ci.test.sh`. **Size:** S.

- [ ] **Step 1: Write the failing cases** in `add-ci.test.sh`: `"--upgrade replaces the known
  gitleaks-only config"`, `"--upgrade refuses a changed config"`, `"--upgrade refuses a trailing
  blank line"`, `"without --upgrade the known config is refused"` and `"the known file is the old
  scaffold's"`. The last one compares the sha256 prefix.
- [ ] **Step 2: Run.** Expected: the new cases fail.
- [ ] **Step 3: Implement.** The flag goes in the option loop beside `--ci`. The target check makes its
  one exception for `.pre-commit-config.yaml` under `--upgrade`. Update the header and the README's
  "existing repos" note.
- [ ] **Step 4: Run** `add-ci.test.sh`, `new-repo.test.sh` and shellcheck. Expected: every line `ok`.
- [ ] **Step 5: Commit.** "add-ci.sh: --upgrade replaces the known gitleaks-only config
  (base-ci-T002)".

### Task base-ci-T003: md-same-text.sh proves a Markdown change is formatting only

**Files (in `ouroboric`):**
- Create: `scripts/md-same-text.sh`, `scripts/md-same-text.py` (the renderer, run with
  `python3 -I` through `uvx`)
- Test: `scripts/tests/md-same-text.test.sh`

**Interfaces:**
- Produces: `md-same-text.sh <base-ref> <head-ref>`, run inside a git repo.
  - It takes every `.md` file changed between the refs: `git diff --name-only --diff-filter=M`.
  - For each file, it compares the two versions:
    - **text:** markdown-it-py's rendered HTML, with tags stripped, entities decoded and whitespace
      collapsed to single spaces, must be equal;
    - **code:** the list of fenced code blocks' contents, as given by markdown-it tokens of type
      `fence` (contents only, not the info string), must be byte-identical.
  - It prints `same <file>` or `DIFFERS <file>: text|code`, and exits 1 if any file differs.
  - An added or deleted `.md` file is reported as `DIFFERS <file>: added|deleted`.
  - Agent-run, with no token.

**Acceptance criteria:**
- [ ] These count as the same:
  - a heading with blank lines added around it;
  - `|---|` changed to `| --- |`;
  - `**X**` changed to `#### X`;
  - a fence given an info string (`text`).
- [ ] These count as different:
  - a word changed;
  - a tab changed to spaces inside a fence (code);
  - a line added inside a fence.
- [ ] A file only in head reports `added`.
- [ ] Every case exits as stated.

**Named test:** `bash scripts/tests/md-same-text.test.sh`. **Size:** S.

- [ ] **Step 1: Write the failing test.** Each case is a two-commit repo in `$T`. Name the cases as in
  the acceptance criteria.
- [ ] **Step 2: Run.** Expected: FAIL, because there is no script yet.
- [ ] **Step 3: Implement.** The shell script lists the files and gets both versions with
  `git show <ref>:<file>`. The Python side renders and extracts. Keep it under 80 lines.
- [ ] **Step 4: Run it and shellcheck.** Expected: every line `ok`.
- [ ] **Step 5: Commit.** "md-same-text.sh: prove a Markdown change is formatting only
  (base-ci-T003)".

### Task base-ci-T004: rollout-ci.sh, the founder's two commands, and the docs

**Files (in `ouroboric`):**
- Create: `scripts/rollout-ci.sh`
- Modify: `docs/4-ways-of-working/docs-standard.md` (§9), `AGENTS.md` (the scripts table and the
  founder-only line), `scripts/templates/ci/README.md` (the existing-repos section)
- Test: `scripts/tests/rollout-ci.test.sh`

**Interfaces:**
- Consumes: `repo-config.sh`'s `repo_config_args`, `repo_config_load` and `RC_ORG`; `setup-repo.sh`;
  `check-repos.sh --check ruleset <repo>`; `as-bot.sh <repo> gh …`.
- Produces: `GH_TOKEN=... rollout-ci.sh (--org <name>|--config <path>) push|protect <repo>...`
  - **`push`, for each repo:**
    1. `$ROOT/<repo>` must be a git repo with a local `base-ci` branch. Otherwise it prints
       `rollout-ci: <repo>: no base-ci branch in <path>; skipped`.
    2. It reads the remote `base-ci` SHA with `git ls-remote` (empty if absent). If that equals the
       local branch, it prints `up to date`. Otherwise it pushes with
       `--force-with-lease=refs/heads/base-ci:<remote sha>`, which means "must not exist" when the SHA
       is empty. It uses `new-repo.sh`'s credential helper, against
       `${ROLLOUT_GIT:-https://github.com}/$RC_ORG/<repo>.git`.
    3. It looks for an open PR with `$BOT <repo> gh pr list --repo $RC_ORG/<repo> --head base-ci
       --state open --json url -q '.[0].url'`. If there is none, it opens one with `$BOT <repo> gh pr
       create --repo $RC_ORG/<repo> --base main --head base-ci --title "Base CI: lint required" --body
       "<one paragraph naming the base-CI rollout proposal and saying the founder runs rollout-ci.sh
       protect after merge>"`. It prints `rollout-ci: <repo>: <url>`.
       `BOT` is `${ROLLOUT_BOT:-<dir>/as-bot.sh}`.
  - **`protect`, for each repo:**
    - It runs `gh api repos/$RC_ORG/<repo>/contents/.github/workflows/lint.yml` (main is the default
      ref).
      - **Found:** it runs `${ROLLOUT_SETUP:-<dir>/setup-repo.sh} "${RC_FROM[@]}" <repo>`. Then, when
        `RC_ORG` is `ouroboric-dev`, it runs `${ROLLOUT_CHECK:-<dir>/check-repos.sh} --check ruleset
        <repo>`, and prints the result.
      - **HTTP 404:** it prints `rollout-ci: <repo>: lint.yml is not on main yet; not protected`, and
        that is not an error.
      - **Any other failure:** it prints the error and moves on, with the exit code 1 at the end.
  - **Exit codes:** 0 when every repo succeeded or was "not yet". 1 when any repo was skipped, failed,
    or failed its check. 2 for usage.
  - `ROOT` is `${ROLLOUT_ROOT:-<dir>/../../rollout}`. `exec </dev/null`. It never prompts.

**Acceptance criteria:**
- [ ] `push` on two prepared repos pushes both `base-ci` branches to the fake remotes, opens two PRs
      through the bot stub, and prints both URLs.
- [ ] `push` run again with nothing changed prints `up to date`, and opens no second PR.
- [ ] After a local rebase, `push` updates the remote. If the remote branch was moved by someone else,
      the lease refuses it, and the script exits 1 for that repo.
- [ ] A repo without a local `base-ci` branch is skipped, named, and gets exit 1. Nothing is pushed
      for it.
- [ ] `protect`:
  - runs the setup stub only for a repo whose fake `lint.yml` lookup returns 200;
  - prints "not yet" for one that returns 404;
  - exits 1 for one that returns 500, without running setup for it.
- [ ] The token never appears in stdout or stderr. stdin never reaches a step.
- [ ] The docs:
  - docs-standard §9 says existing repos get the base CI through `rollout-ci.sh push`, then `protect`
    after the merge, and states the bend-or-default rule for the lint configs;
  - `AGENTS.md` lists `rollout-ci.sh` as founder-only, and `md-same-text.sh` as an agent tool.

**Named test:** `bash scripts/tests/rollout-ci.test.sh`. **Size:** M.

- [ ] **Step 1: Write the failing test.**
  - The remotes: bare repos under `$T/git/<org>/`, with `ROLLOUT_GIT=file://$T/git`.
  - The bot stub: a script that logs its arguments and answers `gh pr list` from a state file.
  - `gh`: `fake-gh`, with `GET` fixtures for the lint lookups.
  - Setup and check: stubs that log.
  - Name each case after an acceptance criterion.
- [ ] **Step 2: Run.** Expected: FAIL, because there is no script yet.
- [ ] **Step 3: Implement `scripts/rollout-ci.sh`.**
- [ ] **Step 4: Run it**, the whole suite, and shellcheck. Expected: every line `ok`, and the suite
  prints nothing.
- [ ] **Step 5: Update the docs**, then commit: "rollout-ci.sh: push and protect the base CI on existing
  repos (base-ci-T004)".
- [ ] **Step 6: Land the tooling.**
  1. Push `base-ci-tooling` with `as-bot.sh` and open the PR. Its body lists T001–T004's acceptance
     criteria with the named tests' output.
  2. Message the realm-readiness session (`ouroboric-6e`). Give it the PR link and `rollout-ci.sh`'s
     usage, and say it can copy the method once the PR merges.
  3. Ask that session to fold the `check-repos.sh` line (see the decisions) into its own change, or
     to say when its change merges.

### Task base-ci-T005: the pilot, gungnir

**Files:** in `$ROLLOUT_ROOT/gungnir`, on branch `base-ci`.

**Interfaces:**
- Consumes: T001's configs and T002's `add-ci.sh --upgrade`, from `ouroboric` `main` after the
  tooling PR merges.

**Acceptance criteria:**
- [ ] The branch holds:
  - the full config: `add-ci.sh --org ouroboric-dev --ci reuse,markdown,shell,actions,yaml --upgrade .`;
  - the `AGENTS.md` bare-URL fix (`<…>`);
  - the `.github/workflows/ci.yml` comment-spacing and line-length fixes.
- [ ] The three landing commands pass in the clone.
- [ ] `ci.yml`'s behaviour is unchanged: only spacing, a comment, or a folded string changed. The
      diff shows this.

**Size:** S.

- [ ] **Step 1:** clone, branch, and run `add-ci.sh … --upgrade .`.
- [ ] **Step 2:** run the hooks to see the failures. Expected: the two known findings.
- [ ] **Step 3:** fix them. Run the three landing commands. Expected: all exit 0.
- [ ] **Step 4:** commit by path. Record the branch head in the ledger.
- [ ] **Step 5 (founder):** `GH_TOKEN=... scripts/rollout-ci.sh --org ouroboric-dev push gungnir`.
  Review the PR. `lint` and `test` must pass. Merge it. Then run
  `GH_TOKEN=... scripts/rollout-ci.sh --org ouroboric-dev protect gungnir`. Expected:
  `PASS gungnir ruleset`.
- [ ] **Step 6:** if the pilot showed any problem in the script or the configs, fix it in an `ouroboric`
  PR before T006.

### Task base-ci-T006: the other Go leaves, odin, gleipnir, jormungandr, havamal

**Files:** in `$ROLLOUT_ROOT/<repo>`, each on branch `base-ci`.

**Acceptance criteria:**
- [ ] Each repo has the full config through `--upgrade`, and passes the three landing commands.
- [ ] **odin:** `.markdownlint-cli2.yaml` with `ignores: ["testdata/**"]`, and `.yamllint` with
      `extends: .yamllint.yaml` and `ignore: testdata/`. These are its only exclusions.
- [ ] **gleipnir:** `scan/scan.sh` parses under shellcheck.
  - Change the template so that the heredoc's terminator is always on its own line after rendering.
    One way is to put the `@CONFIG@` placeholder on its own line.
  - `go test ./...` in gleipnir must pass, and must show that the rendered script is unchanged for
    the same config. If gleipnir has no test that renders `scan.sh`, add one first, on the old
    template, and keep it passing.
  - If the template can't parse without changing what it renders, stop and report.
- [ ] **havamal:** its one leftover MD041 is cleared by T001's bend. Its other findings are fixed by
      `--fix`.
- [ ] Every `.md` change passes `md-same-text.sh`.

**Size:** M (gleipnir's template is the only real code change).

- [ ] **Step 1:** for each repo, do T005's Steps 1–4, plus the repo-specific items above.
- [ ] **Step 2 (founder):** `GH_TOKEN=... scripts/rollout-ci.sh --org ouroboric-dev push odin gleipnir
  jormungandr havamal`. Review and merge each PR, then run `… protect odin gleipnir jormungandr
  havamal`.

### Task base-ci-T007: mimir, ouroboric-packages and .github

**Files:** in `$ROLLOUT_ROOT/<repo>`, each on branch `base-ci`.

**Acceptance criteria:**
- [ ] Each has the full config through `--upgrade`, and passes the three landing commands.
- [ ] **mimir and ouroboric-packages:** the MD060 tables (6 and 14 findings) are made consistent by
      hand (`--fix` leaves them). ouroboric-packages's one MD040 fence gets a language.
- [ ] **.github:**
  - the PR template's placeholders go in backticks;
  - the issue form's long line is folded;
  - `profile/README.md`'s opening `<img>` stays, because T001 allows it;
  - the skill file and the PR template keep their openings, because MD041 is off.
- [ ] Every `.md` change passes `md-same-text.sh`.

**Size:** S.

- [ ] **Step 1:** as T006's Step 1.
- [ ] **Step 2 (founder):** `… push mimir ouroboric-packages .github`. Review and merge each PR, then
  `… protect mimir ouroboric-packages .github`.

### Task base-ci-T008: ouroboric

**Files:**
- In `ouroboric`:
  - the formatting fixes, via pr-bot PRs on branches `base-ci-fix-<area>`;
  - then `$ROLLOUT_ROOT/ouroboric` on branch `base-ci`.

**Acceptance criteria:**
- [ ] **The fix PRs come first,** opened and pushed with `as-bot.sh`, each passing `md-same-text.sh
      origin/main HEAD`:
  1. `docs/` without the journal, then `docs/6-journal/`. These are the `--fix` output, plus the four
     MD040 fences.
  2. `scripts/`: the shellcheck fixes from the decisions table. The SC1091 notes in the `plan-*.sh`
     scripts get `source-path=SCRIPTDIR` directives. The SC2155 notes get split declarations. The
     SC2012 notes use a glob or `find`. Each SC2329, SC2015 or SC2016 note gets a file-level or
     line-level `disable` with its reason. `check-repos.sh` is not in this PR.
- [ ] **`check-repos.sh`:** after the realm-readiness session's `check-repos.sh` change merges, one
      line, `# shellcheck disable=SC2015,SC2329  # <reason>`, goes in a separate small pr-bot PR,
      unless that session already added it.
- [ ] **The `base-ci` branch**, cut after those PRs merge, holds:
  - the full config through `--upgrade`;
  - `.yamllint` with `extends: .yamllint.yaml` and `ignore: scripts/templates/ci/pieces/`, its only
    exclusion.

  It passes the three landing commands.
- [ ] The whole `scripts/tests` suite still passes on each fix branch.

**Size:** M.

- [ ] **Step 1:** make the fix branches from `origin/main`, in a worktree of the local `ouroboric`
  clone. Run `--fix`, then the by-hand fixes. Check each branch with `md-same-text.sh` and the suite.
  Push it and open its PR.
- [ ] **Step 2 (founder):** review and merge the fix PRs.
- [ ] **Step 3:** after the merges, prepare `base-ci` as in T005, then run the three landing commands.
- [ ] **Step 4 (founder):** `… push ouroboric`. Review and merge the PR, then `… protect ouroboric`.

### Task base-ci-T009: yggdrasil

**Files:**
- In `yggdrasil`:
  - the formatting fixes, via pr-bot PRs on branches `base-ci-fix-<area>`;
  - then `$ROLLOUT_ROOT/yggdrasil` on branch `base-ci`.

**Acceptance criteria:**
- [ ] **The fix PRs come first,** each passing `md-same-text.sh`:
  1. `docs/2-engineering/`, including the phase plans. The code-block rule in `md-same-text.sh` is
     the guarantee that the plan code is untouched.
  2. `docs/5-research/`: MD036 lines become headings at the level below their section, and the MD059
     link text is fixed.
  3. Every other folder that has findings, including `bench/harbor/`'s shell fixes per the decisions
     table.
- [ ] **The `base-ci` branch** has the full config through `--upgrade`, with no exclusions, and passes
      the three landing commands. A clone without `--recurse-submodules` is right: the leaves are
      linted in their own repos.
- [ ] `bench/harbor`'s own tests still pass after its shell fixes.

**Size:** M.

- [ ] **Step 1:** as T008's Step 1. The yggdrasil clone has uncommitted changes that are not ours
  (`go.work.sum` and the submodule pointers). Work in a worktree from `origin/main` or a fresh clone,
  never in that checkout.
- [ ] **Step 2 (founder):** review and merge the fix PRs.
- [ ] **Step 3:** prepare `base-ci` as in T005.
- [ ] **Step 4 (founder):** `… push yggdrasil`. Review and merge the PR, then `… protect yggdrasil`.

### Task base-ci-H01 (founder): done for all ten

**Acceptance criteria:**
- [ ] This run prints only `PASS` lines:

  ```zsh
  GH_TOKEN=... scripts/check-repos.sh --check ruleset --check gitleaks --check reuse \
    .github ouroboric yggdrasil ouroboric-packages mimir gungnir odin gleipnir jormungandr havamal
  ```

  `reuse` and `gitleaks` read the local clones side by side, so pull them first. `.github` has no
  local clone today: clone it beside the others first, or check it from `$ROLLOUT_ROOT/.github` after
  pulling `main` there.
- [ ] Each of the ten repos has a green `lint` run on `main`.
- [ ] `$ROLLOUT_ROOT` is deleted.
